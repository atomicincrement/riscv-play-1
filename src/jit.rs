use std::io::Write;

use inkwell::AddressSpace;
use inkwell::IntPredicate;
use inkwell::OptimizationLevel;
use inkwell::context::Context;
use inkwell::module::Linkage;
use inkwell::targets::{InitializationConfig, Target};

use crate::elf_loader::LoadedElf;

// ---------------------------------------------------------------------------
// Extern "C" callback invoked by JIT code on every ecall instruction.
//
// Arguments (mirroring what the JIT emits):
//   regs    – pointer to the guest's [i64; 32] register file (mutable)
//   mem     – pointer to the flat virtual memory (read-only)
//   mem_len – length of mem in bytes
//
// Returns:
//   >= 0   → halt with this exit code
//   -1     → continue executing
// ---------------------------------------------------------------------------
#[unsafe(no_mangle)]
pub extern "C" fn jit_ecall(regs: *mut i64, mem: *const u8, mem_len: u64) -> i32 {
    // SAFETY: the JIT allocates the register file on its stack and passes a
    // valid pointer.  `mem` is the Rust Vec<u8> buffer we created.
    let regs = unsafe { std::slice::from_raw_parts_mut(regs, 32) };
    let mem = unsafe { std::slice::from_raw_parts(mem, mem_len as usize) };

    let a7 = regs[17] as u64; // syscall number
    match a7 {
        // sys_write(fd, buf, count)
        64 => {
            let fd = regs[10] as u64;
            let buf = regs[11] as usize;
            let count = regs[12] as usize;
            let data = &mem[buf..buf + count];
            let written: i64 = match fd {
                1 => {
                    std::io::stdout().write_all(data).unwrap();
                    count as i64
                }
                2 => {
                    std::io::stderr().write_all(data).unwrap();
                    count as i64
                }
                _ => -1,
            };
            regs[10] = written;
            -1 // continue
        }
        // sys_exit(code)
        93 => regs[10] as i32,
        other => {
            eprintln!("jit_ecall: unimplemented syscall a7={other}");
            1
        }
    }
}

// ---------------------------------------------------------------------------
// JIT entry point
// ---------------------------------------------------------------------------

type JitMainFn = unsafe extern "C" fn(mem: *const u8, mem_len: u64) -> i32;

/// Translate the RISC-V instructions in `loaded` into LLVM IR and run them
/// via LLVM's MCJIT.  Returns the guest exit code.
pub fn run(loaded: &LoadedElf) -> i32 {
    // ---- 1. Initialise the native target (needed by MCJIT) ----------------
    Target::initialize_native(&InitializationConfig::default())
        .expect("failed to initialise native LLVM target");

    // ---- 2. Create LLVM context, module, and builder ----------------------
    let context = Context::create();
    let module = context.create_module("riscv_jit");
    let builder = context.create_builder();

    let i8_type = context.i8_type();
    let i32_type = context.i32_type();
    let i64_type = context.i64_type();
    // In LLVM 18 all pointers are opaque (just `ptr`).
    let ptr_type = context.ptr_type(AddressSpace::default());

    // ---- 3. Declare the extern callback: i32 @jit_ecall(ptr, ptr, i64) ---
    let ecall_fn_type = i32_type.fn_type(
        &[ptr_type.into(), ptr_type.into(), i64_type.into()],
        false,
    );
    let ecall_decl =
        module.add_function("jit_ecall", ecall_fn_type, Some(Linkage::External));

    // ---- 4. Define: i32 @jit_main(ptr %mem, i64 %mem_len) ----------------
    let main_fn_type = i32_type.fn_type(&[ptr_type.into(), i64_type.into()], false);
    let main_fn = module.add_function("jit_main", main_fn_type, None);

    let entry_bb = context.append_basic_block(main_fn, "entry");
    builder.position_at_end(entry_bb);

    let mem_param = main_fn.get_nth_param(0).unwrap().into_pointer_value();
    let mem_len_param = main_fn.get_nth_param(1).unwrap().into_int_value();

    // ---- 5. Allocate and zero-initialise the [32 x i64] register file ----
    let regs_arr_type = i64_type.array_type(32);
    let regs_alloca = builder.build_alloca(regs_arr_type, "regs").unwrap();

    // memset(regs, 0, 32 * 8)
    let zero_i8 = i8_type.const_zero();
    let size_bytes = i64_type.const_int(32 * 8, false);
    builder
        .build_memset(regs_alloca, 8, zero_i8, size_bytes)
        .unwrap();

    // ---- 6. Translate instructions ----------------------------------------
    // Macro that builds a GEP to the i-th register in the alloca.
    // GEP element type is i64; the alloca is treated as i64*.
    macro_rules! reg_ptr {
        ($idx:expr) => {{
            let idx_val = i64_type.const_int($idx as u64, false);
            unsafe {
                builder
                    .build_gep(i64_type, regs_alloca, &[idx_val], "reg_ptr")
                    .unwrap()
            }
        }};
    }

    macro_rules! load_reg {
        ($idx:expr) => {{
            builder
                .build_load(i64_type, reg_ptr!($idx), "reg_val")
                .unwrap()
                .into_int_value()
        }};
    }

    macro_rules! store_reg {
        ($idx:expr, $val:expr) => {{
            if $idx != 0 {
                builder.build_store(reg_ptr!($idx), $val).unwrap();
            }
        }};
    }

    // Track whether the current BB already has a terminator (return /
    // conditional branch).  If the translation loop ends without one, we
    // emit a fallthrough return 0.
    let mut has_terminator = false;

    let mut pc = loaded.entry as usize;
    let text_end = loaded.text_end as usize;

    loop {
        if pc + 4 > text_end {
            break;
        }
        let insn = u32::from_le_bytes(loaded.mem[pc..pc + 4].try_into().unwrap());
        let opcode = insn & 0x7F;

        match opcode {
            // -- U-type: auipc -------------------------------------------
            0x17 => {
                let rd = ((insn >> 7) & 0x1F) as usize;
                let imm = (insn & 0xFFFF_F000) as i32 as i64 as u64;
                let val = (pc as u64).wrapping_add(imm);
                store_reg!(rd, i64_type.const_int(val, false));
            }

            // -- I-type ALU ops ------------------------------------------
            0x13 => {
                let rd = ((insn >> 7) & 0x1F) as usize;
                let funct3 = (insn >> 12) & 0x7;
                let rs1 = ((insn >> 15) & 0x1F) as usize;
                let imm = ((insn as i32) >> 20) as i64 as u64;

                match funct3 {
                    0x0 => {
                        // addi
                        let rs1_val = load_reg!(rs1);
                        let imm_val = i64_type.const_int(imm, false);
                        let result = builder
                            .build_int_add(rs1_val, imm_val, "addi")
                            .unwrap();
                        store_reg!(rd, result);
                    }
                    _ => {
                        eprintln!("jit: unimplemented OP-IMM funct3={funct3:#x} at {pc:#x}");
                        builder
                            .build_return(Some(&i32_type.const_int(1, false)))
                            .unwrap();
                        has_terminator = true;
                        break;
                    }
                }
            }

            // -- ecall / ebreak ------------------------------------------
            0x73 => {
                let funct12 = insn >> 20;
                if funct12 != 0 {
                    eprintln!("jit: unimplemented SYSTEM funct12={funct12:#x} at {pc:#x}");
                    builder
                        .build_return(Some(&i32_type.const_int(1, false)))
                        .unwrap();
                    has_terminator = true;
                    break;
                }

                // Call jit_ecall(regs_alloca, mem_ptr, mem_len)
                let call = builder
                    .build_call(
                        ecall_decl,
                        &[
                            regs_alloca.into(),
                            mem_param.into(),
                            mem_len_param.into(),
                        ],
                        "ecall_ret",
                    )
                    .unwrap();
                let ret_val = call
                    .try_as_basic_value()
                    .left()
                    .unwrap()
                    .into_int_value();

                // if ret >= 0 → branch to exit block, else continue
                let zero_i32 = i32_type.const_zero();
                let is_exit = builder
                    .build_int_compare(IntPredicate::SGE, ret_val, zero_i32, "is_exit")
                    .unwrap();

                let exit_bb =
                    context.append_basic_block(main_fn, "ecall_exit");
                let cont_bb =
                    context.append_basic_block(main_fn, "ecall_cont");

                builder
                    .build_conditional_branch(is_exit, exit_bb, cont_bb)
                    .unwrap();

                // exit path
                builder.position_at_end(exit_bb);
                builder.build_return(Some(&ret_val)).unwrap();

                // continue path
                builder.position_at_end(cont_bb);
            }

            _ => {
                eprintln!("jit: unimplemented opcode {opcode:#x} at {pc:#x}");
                builder
                    .build_return(Some(&i32_type.const_int(1, false)))
                    .unwrap();
                has_terminator = true;
                break;
            }
        }

        pc += 4;
    }

    if !has_terminator {
        builder
            .build_return(Some(&i32_type.const_int(0, false)))
            .unwrap();
    }

    // ---- 7. Verify the IR ------------------------------------------------
    if let Err(e) = module.verify() {
        eprintln!("JIT IR verification failed:\n{}", e.to_string());
        return 1;
    }

    // ---- 8. JIT-compile and execute ------------------------------------
    let ee = module
        .create_jit_execution_engine(OptimizationLevel::Default)
        .expect("failed to create JIT execution engine");

    // Explicitly map the ecall callback so MCJIT can resolve it.
    // Without this the JIT linker may not find the symbol in the
    // host process and would call a null pointer.
    ee.add_global_mapping(&ecall_decl, jit_ecall as *const () as usize);

    let exit_code = unsafe {
        let jit_main: inkwell::execution_engine::JitFunction<JitMainFn> =
            ee.get_function("jit_main")
                .expect("jit_main symbol not found");
        jit_main.call(loaded.mem.as_ptr(), loaded.mem.len() as u64)
    };

    exit_code
}
