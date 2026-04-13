use std::collections::BTreeSet;
use std::io::Write;

use inkwell::AddressSpace;
use inkwell::IntPredicate;
use inkwell::OptimizationLevel;
use inkwell::context::Context;
use inkwell::module::Linkage;
use inkwell::targets::{CodeModel, FileType, InitializationConfig, RelocMode, Target, TargetMachine};

use crate::elf_loader::LoadedElf;
use crate::emulator::Emulator;

// ---------------------------------------------------------------------------
// Host callbacks invoked from JIT code
// ---------------------------------------------------------------------------

/// Called for every `ecall` instruction in JIT code.
/// Returns >= 0 to halt with that exit code, -1 to continue.
#[unsafe(no_mangle)]
pub extern "C" fn jit_ecall(regs: *mut i64, mem: *const u8, mem_len: u64) -> i32 {
    let regs = unsafe { std::slice::from_raw_parts_mut(regs, 32) };
    let mem_slice = unsafe { std::slice::from_raw_parts(mem, mem_len as usize) };

    match regs[17] as u64 {
        64 => {
            // sys_write(fd, buf, count)
            let fd    = regs[10] as u64;
            let buf   = regs[11] as usize;
            let count = regs[12] as usize;
            if buf.saturating_add(count) > mem_slice.len() {
                eprintln!("jit_ecall: write buffer OOB"); regs[10] = -1i64; return -1;
            }
            let data = &mem_slice[buf..buf + count];
            let written: i64 = match fd {
                1 => { std::io::stdout().write_all(data).unwrap(); count as i64 }
                2 => { std::io::stderr().write_all(data).unwrap(); count as i64 }
                _ => -1,
            };
            regs[10] = written;
            -1 // continue
        }
        93 => regs[10] as i32, // sys_exit
        other => { eprintln!("jit_ecall: unimplemented a7={other}"); 1 }
    }
}

/// Called for `jalr` — indirect jump whose target is only known at runtime.
/// Restores the full register file into an interpreter and runs to completion.
#[unsafe(no_mangle)]
pub extern "C" fn jit_jalr_interp(
    regs: *mut i64,
    mem:  *const u8,
    mem_len: u64,
    target: u64,
) -> i32 {
    let regs_slice = unsafe { std::slice::from_raw_parts(regs, 32) };
    let mem_copy: Vec<u8> =
        unsafe { std::slice::from_raw_parts(mem, mem_len as usize) }.to_vec();

    let mut emu = Emulator::new(mem_copy, target);
    for i in 1..32 { emu.regs[i] = regs_slice[i] as u64; }
    emu.run()
}

// ---------------------------------------------------------------------------
// JIT entry point
// ---------------------------------------------------------------------------

type JitMainFn = unsafe extern "C" fn(mem: *const u8, mem_len: u64, stack_top: u64) -> i32;

/// Translate the RISC-V instructions in `loaded` into LLVM IR and run via MCJIT.
/// If `dump_prefix` is `Some(p)`, write the optimised IR to `<p>.ll` and x86-64
/// assembly to `<p>.x86_64.s` before executing.
pub fn run(loaded: &LoadedElf, dump_prefix: Option<&str>) -> i32 {
    Target::initialize_native(&InitializationConfig::default())
        .expect("failed to initialise native LLVM target");

    let context = Context::create();
    let module  = context.create_module("riscv_jit");
    let builder = context.create_builder();

    let i1_type  = context.bool_type();
    let i8_type  = context.i8_type();
    let i16_type = context.i16_type();
    let i32_type = context.i32_type();
    let i64_type = context.i64_type();
    let ptr_type = context.ptr_type(AddressSpace::default());
    let _ = i1_type; // suppress unused warning

    // ---- Declare extern callbacks ----------------------------------------

    let ecall_fn_type = i32_type.fn_type(
        &[ptr_type.into(), ptr_type.into(), i64_type.into()], false);
    let ecall_decl =
        module.add_function("jit_ecall", ecall_fn_type, Some(Linkage::External));

    // jit_jalr_interp(ptr regs, ptr mem, i64 mem_len, i64 target) -> i32
    let jalr_fn_type = i32_type.fn_type(
        &[ptr_type.into(), ptr_type.into(), i64_type.into(), i64_type.into()], false);
    let jalr_decl =
        module.add_function("jit_jalr_interp", jalr_fn_type, Some(Linkage::External));

    // ---- Define jit_main(ptr %mem, i64 %mem_len, i64 %stack_top) -> i32 --

    let main_fn_type = i32_type.fn_type(
        &[ptr_type.into(), i64_type.into(), i64_type.into()], false);
    let main_fn = module.add_function("jit_main", main_fn_type, None);

    let mem_param       = main_fn.get_nth_param(0).unwrap().into_pointer_value();
    let mem_len_param   = main_fn.get_nth_param(1).unwrap().into_int_value();
    let stack_top_param = main_fn.get_nth_param(2).unwrap().into_int_value();

    // ---- Pass 1: collect basic-block entry addresses ----------------------

    let entry_addr = loaded.entry;
    let text_base  = loaded.text_base as usize;
    let text_end   = loaded.text_end as usize;

    let mut bb_entries: BTreeSet<u64> = BTreeSet::new();
    bb_entries.insert(entry_addr);

    let mut scan_pc = text_base; // scan all of .text, not just from entry
    while scan_pc + 4 <= text_end {
        let insn   = u32::from_le_bytes(loaded.mem[scan_pc..scan_pc+4].try_into().unwrap());
        let opcode = insn & 0x7F;
        match opcode {
            // jal: unconditional direct branch
            0x6F => {
                let b20    = ((insn >> 31) & 1) as u64;
                let b19_12 = ((insn >> 12) & 0xFF) as u64;
                let b11    = ((insn >> 20) & 1) as u64;
                let b10_1  = ((insn >> 21) & 0x3FF) as u64;
                let raw = (b20 << 20) | (b19_12 << 12) | (b11 << 11) | (b10_1 << 1);
                let imm_j  = if b20 != 0 { raw | !0x1F_FFFFu64 } else { raw };
                let target = (scan_pc as u64).wrapping_add(imm_j);
                bb_entries.insert(target);
                bb_entries.insert((scan_pc + 4) as u64); // fallthrough (after return)
            }
            // jalr: indirect — only fallthrough is a separate BB
            0x67 => {
                bb_entries.insert((scan_pc + 4) as u64);
            }
            // conditional branches
            0x63 => {
                let b12   = ((insn >> 31) & 1) as u64;
                let b11   = ((insn >>  7) & 1) as u64;
                let b10_5 = ((insn >> 25) & 0x3F) as u64;
                let b4_1  = ((insn >>  8) & 0x0F) as u64;
                let raw   = (b12 << 12) | (b11 << 11) | (b10_5 << 5) | (b4_1 << 1);
                let imm_b = if b12 != 0 { raw | !0x1FFFu64 } else { raw };
                let target = (scan_pc as u64).wrapping_add(imm_b);
                if target >= entry_addr && (target as usize) < text_end {
                    bb_entries.insert(target);
                }
                bb_entries.insert((scan_pc + 4) as u64);
            }
            _ => {}
        }
        scan_pc += 4;
    }

    // ---- Create an LLVM BB for every entry address ------------------------

    use std::collections::HashMap;
    let mut bb_map: HashMap<u64, inkwell::basic_block::BasicBlock> = HashMap::new();

    // The very first BB is the alloca/memset BB; translation starts in a fresh BB.
    let alloca_bb  = context.append_basic_block(main_fn, "alloca");
    let first_bb   = context.append_basic_block(main_fn, &format!("bb_{:#x}", entry_addr));
    bb_map.insert(entry_addr, first_bb);

    for &addr in &bb_entries {
        if addr != entry_addr {
            let name = format!("bb_{addr:#x}");
            let bb = context.append_basic_block(main_fn, &name);
            bb_map.insert(addr, bb);
        }
    }

    // Shared OOB trap block — returns 1 for any out-of-bounds access.
    let oob_bb = context.append_basic_block(main_fn, "oob_trap");
    builder.position_at_end(oob_bb);
    builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();

    // ---- Alloca BB: set up register file, jump to first BB ---------------

    builder.position_at_end(alloca_bb);
    let regs_arr_type = i64_type.array_type(32);
    let regs_alloca = builder.build_alloca(regs_arr_type, "regs").unwrap();
    builder.build_memset(
        regs_alloca, 8, i8_type.const_zero(),
        i64_type.const_int(32 * 8, false),
    ).unwrap();
    // Initialise x2 (sp) to stack_top so C code has a working stack.
    {
        let sp_ptr = unsafe {
            builder.build_gep(i64_type, regs_alloca,
                &[i64_type.const_int(2, false)], "sp_ptr").unwrap()
        };
        builder.build_store(sp_ptr, stack_top_param).unwrap();
    }
    builder.build_unconditional_branch(first_bb).unwrap();

    // ---- Helper macros ---------------------------------------------------

    macro_rules! reg_ptr {
        ($idx:expr) => {{
            let idx_val = i64_type.const_int($idx as u64, false);
            unsafe {
                builder.build_gep(i64_type, regs_alloca, &[idx_val], "reg_ptr").unwrap()
            }
        }};
    }
    macro_rules! load_reg {
        ($idx:expr) => {{
            builder.build_load(i64_type, reg_ptr!($idx), "rv").unwrap().into_int_value()
        }};
    }
    macro_rules! store_reg {
        ($idx:expr, $val:expr) => {{
            if $idx != 0 { builder.build_store(reg_ptr!($idx), $val).unwrap(); }
        }};
    }

    // Bounds-checked GEP into guest memory: addr..addr+size must lie within mem.
    // Emits an OOB branch if violated.  Returns a pointer into %mem on success.
    macro_rules! mem_ptr_checked {
        ($addr_val:expr, $size:expr) => {{
            // end = addr + size (using u64 arithmetic in IR)
            let size_v   = i64_type.const_int($size, false);
            let end_v    = builder.build_int_add($addr_val, size_v, "mem_end").unwrap();
            let in_range = builder.build_int_compare(
                IntPredicate::ULE, end_v, mem_len_param, "in_range").unwrap();
            let ok_bb = context.append_basic_block(main_fn, "mem_ok");
            builder.build_conditional_branch(in_range, ok_bb, oob_bb).unwrap();
            builder.position_at_end(ok_bb);
            // GEP into %mem at addr bytes offset.
            unsafe {
                builder.build_gep(i8_type, mem_param, &[$addr_val], "mem_ptr").unwrap()
            }
        }};
    }

    // ---- Pass 2: Translate instructions ----------------------------------

    // Position at the entry BB.
    builder.position_at_end(first_bb);
    let mut needs_terminator = true; // does the current BB still need a terminator?
    let mut skip = false;            // true when in dead code (backward branch to already-translated BB)

    let mut pc = text_base;

    while pc + 4 <= text_end {
        // If this PC is a BB entry, handle the transition.
        let pc_addr = pc as u64;
        if let Some(&target_bb) = bb_map.get(&pc_addr) {
            // Check whether we're already positioned at target_bb.
            let cur_bb = builder.get_insert_block().unwrap();
            if cur_bb != target_bb {
                if needs_terminator && !skip {
                    builder.build_unconditional_branch(target_bb).unwrap();
                }
                if target_bb.get_terminator().is_none() {
                    // Fresh (untranslated) BB — start emitting into it.
                    builder.position_at_end(target_bb);
                    needs_terminator = true;
                    skip = false;
                } else {
                    // Already-translated BB (backward branch target) — do not re-emit.
                    needs_terminator = false;
                    skip = true;
                }
            }
        }

        // Skip instruction emission when in dead code (after a backward-branch region).
        if skip {
            pc += 4;
            continue;
        }

        let insn   = u32::from_le_bytes(loaded.mem[pc..pc+4].try_into().unwrap());
        let opcode = insn & 0x7F;
        let rd     = ((insn >>  7) & 0x1F) as usize;
        let funct3 =  (insn >> 12) & 0x07;
        let rs1    = ((insn >> 15) & 0x1F) as usize;
        let rs2    = ((insn >> 20) & 0x1F) as usize;
        let funct7 =   insn >> 25;

        let imm_i  = ((insn as i32) >> 20) as i64 as u64;
        let imm_u  = (insn & 0xFFFF_F000) as i32 as i64 as u64;
        let imm_s  = (((insn & 0xFE00_0000) as i32 >> 20) as u64)
                     | ((insn >> 7) & 0x1F) as u64;
        let imm_b  = {
            let b12   = ((insn >> 31) & 1) as u64;
            let b11   = ((insn >>  7) & 1) as u64;
            let b10_5 = ((insn >> 25) & 0x3F) as u64;
            let b4_1  = ((insn >>  8) & 0x0F) as u64;
            let raw = (b12 << 12) | (b11 << 11) | (b10_5 << 5) | (b4_1 << 1);
            if b12 != 0 { raw | !0x1FFFu64 } else { raw }
        };
        let imm_j  = {
            let b20    = ((insn >> 31) & 1) as u64;
            let b19_12 = ((insn >> 12) & 0xFF) as u64;
            let b11    = ((insn >> 20) & 1) as u64;
            let b10_1  = ((insn >> 21) & 0x3FF) as u64;
            let raw = (b20 << 20) | (b19_12 << 12) | (b11 << 11) | (b10_1 << 1);
            if b20 != 0 { raw | !0x1F_FFFFu64 } else { raw }
        };

        match opcode {

            // ---- LUI -------------------------------------------------------
            0x37 => {
                store_reg!(rd, i64_type.const_int(imm_u, false));
            }

            // ---- AUIPC -----------------------------------------------------
            0x17 => {
                let val = (pc as u64).wrapping_add(imm_u);
                store_reg!(rd, i64_type.const_int(val, false));
            }

            // ---- JAL -------------------------------------------------------
            0x6F => {
                let ret = (pc as u64).wrapping_add(4);
                store_reg!(rd, i64_type.const_int(ret, false));
                let target = (pc as u64).wrapping_add(imm_j);
                if let Some(&target_bb) = bb_map.get(&target) {
                    builder.build_unconditional_branch(target_bb).unwrap();
                } else {
                    // Out-of-range jal — return 1 (unsupported).
                    builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                }
                needs_terminator = false;
            }

            // ---- JALR ------------------------------------------------------
            0x67 => {
                // Compute target = (rs1 + imm) & ~1 in IR.
                let rs1_v  = load_reg!(rs1);
                let imm_v  = i64_type.const_int(imm_i, false);
                let sum    = builder.build_int_add(rs1_v, imm_v, "jalr_sum").unwrap();
                let mask   = i64_type.const_int(!1u64, false);
                let target = builder.build_and(sum, mask, "jalr_target").unwrap();
                // Store rd = PC + 4.
                store_reg!(rd, i64_type.const_int((pc as u64).wrapping_add(4), false));
                // Fall back to interpreter for the remainder.
                let call = builder.build_call(
                    jalr_decl,
                    &[regs_alloca.into(), mem_param.into(), mem_len_param.into(), target.into()],
                    "jalr_ret",
                ).unwrap();
                let ret_val = call.try_as_basic_value().left().unwrap().into_int_value();
                builder.build_return(Some(&ret_val)).unwrap();
                needs_terminator = false;
            }

            // ---- Branches --------------------------------------------------
            0x63 => {
                let v1 = load_reg!(rs1);
                let v2 = load_reg!(rs2);
                let cond = match funct3 {
                    0x0 => builder.build_int_compare(IntPredicate::EQ,  v1, v2, "beq").unwrap(),
                    0x1 => builder.build_int_compare(IntPredicate::NE,  v1, v2, "bne").unwrap(),
                    0x4 => builder.build_int_compare(IntPredicate::SLT, v1, v2, "blt").unwrap(),
                    0x5 => builder.build_int_compare(IntPredicate::SGE, v1, v2, "bge").unwrap(),
                    0x6 => builder.build_int_compare(IntPredicate::ULT, v1, v2, "bltu").unwrap(),
                    0x7 => builder.build_int_compare(IntPredicate::UGE, v1, v2, "bgeu").unwrap(),
                    _   => {
                        builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                        needs_terminator = false;
                        pc += 4; continue;
                    }
                };
                let taken_addr  = (pc as u64).wrapping_add(imm_b);
                let fall_addr   = (pc as u64).wrapping_add(4);
                let taken_bb = bb_map.get(&taken_addr).copied()
                    .unwrap_or(oob_bb);
                let fall_bb  = bb_map.get(&fall_addr).copied()
                    .unwrap_or(oob_bb);
                builder.build_conditional_branch(cond, taken_bb, fall_bb).unwrap();
                needs_terminator = false;
            }

            // ---- Loads -----------------------------------------------------
            0x03 => {
                let base = load_reg!(rs1);
                let off  = i64_type.const_int(imm_i, false);
                let addr = builder.build_int_add(base, off, "laddr").unwrap();

                let val_i64 = match funct3 {
                    0x0 | 0x4 => {
                        let ptr = mem_ptr_checked!(addr, 1);
                        let raw = builder.build_load(i8_type, ptr, "lv8").unwrap().into_int_value();
                        if funct3 == 0x0 {
                            builder.build_int_s_extend(raw, i64_type, "lb").unwrap()
                        } else {
                            builder.build_int_z_extend(raw, i64_type, "lbu").unwrap()
                        }
                    }
                    0x1 | 0x5 => {
                        let ptr = mem_ptr_checked!(addr, 2);
                        let raw = builder.build_load(i16_type, ptr, "lv16").unwrap().into_int_value();
                        if funct3 == 0x1 {
                            builder.build_int_s_extend(raw, i64_type, "lh").unwrap()
                        } else {
                            builder.build_int_z_extend(raw, i64_type, "lhu").unwrap()
                        }
                    }
                    0x2 | 0x6 => {
                        let ptr = mem_ptr_checked!(addr, 4);
                        let raw = builder.build_load(i32_type, ptr, "lv32").unwrap().into_int_value();
                        if funct3 == 0x2 {
                            builder.build_int_s_extend(raw, i64_type, "lw").unwrap()
                        } else {
                            builder.build_int_z_extend(raw, i64_type, "lwu").unwrap()
                        }
                    }
                    0x3 => {
                        let ptr = mem_ptr_checked!(addr, 8);
                        builder.build_load(i64_type, ptr, "ld").unwrap().into_int_value()
                    }
                    _ => {
                        builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                        needs_terminator = false;
                        pc += 4; continue;
                    }
                };
                store_reg!(rd, val_i64);
            }

            // ---- Stores ----------------------------------------------------
            0x23 => {
                let base = load_reg!(rs1);
                let off  = i64_type.const_int(imm_s, false);
                let addr = builder.build_int_add(base, off, "saddr").unwrap();
                let src  = load_reg!(rs2);

                match funct3 {
                    0x0 => {
                        let ptr = mem_ptr_checked!(addr, 1);
                        let v8  = builder.build_int_truncate(src, i8_type, "sv8").unwrap();
                        builder.build_store(ptr, v8).unwrap();
                    }
                    0x1 => {
                        let ptr = mem_ptr_checked!(addr, 2);
                        let v16 = builder.build_int_truncate(src, i16_type, "sv16").unwrap();
                        builder.build_store(ptr, v16).unwrap();
                    }
                    0x2 => {
                        let ptr = mem_ptr_checked!(addr, 4);
                        let v32 = builder.build_int_truncate(src, i32_type, "sv32").unwrap();
                        builder.build_store(ptr, v32).unwrap();
                    }
                    0x3 => {
                        let ptr = mem_ptr_checked!(addr, 8);
                        builder.build_store(ptr, src).unwrap();
                    }
                    _ => {
                        builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                        needs_terminator = false;
                        pc += 4; continue;
                    }
                }
            }

            // ---- OP-IMM (addi/slti/xori/ori/andi/slli/srli/srai) ----------
            0x13 => {
                let src   = load_reg!(rs1);
                let imm_v = i64_type.const_int(imm_i, false);
                let shamt = (imm_i & 0x3F) as u32;
                let result = match funct3 {
                    0x0 => builder.build_int_add(src, imm_v, "addi").unwrap(),
                    0x2 => {
                        let cmp = builder.build_int_compare(IntPredicate::SLT, src, imm_v, "slti").unwrap();
                        builder.build_int_z_extend(cmp, i64_type, "slti_z").unwrap()
                    }
                    0x3 => {
                        let cmp = builder.build_int_compare(IntPredicate::ULT, src, imm_v, "sltiu").unwrap();
                        builder.build_int_z_extend(cmp, i64_type, "sltiu_z").unwrap()
                    }
                    0x4 => builder.build_xor(src, imm_v, "xori").unwrap(),
                    0x6 => builder.build_or(src, imm_v, "ori").unwrap(),
                    0x7 => builder.build_and(src, imm_v, "andi").unwrap(),
                    0x1 => {
                        let sh = i64_type.const_int(shamt as u64, false);
                        builder.build_left_shift(src, sh, "slli").unwrap()
                    }
                    0x5 => {
                        let sh = i64_type.const_int(shamt as u64, false);
                        if funct7 == 0x20 {
                            builder.build_right_shift(src, sh, true, "srai").unwrap()
                        } else {
                            builder.build_right_shift(src, sh, false, "srli").unwrap()
                        }
                    }
                    _ => {
                        builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                        needs_terminator = false;
                        pc += 4; continue;
                    }
                };
                store_reg!(rd, result);
            }

            // ---- OP-IMM-32 (addiw/slliw/srliw/sraiw) ----------------------
            0x1B => {
                let src32 = {
                    let v = load_reg!(rs1);
                    builder.build_int_truncate(v, i32_type, "src32").unwrap()
                };
                let imm32 = i32_type.const_int(imm_i as u32 as u64, false);
                let shamt = (imm_i & 0x1F) as u32;
                let result32: inkwell::values::IntValue = match funct3 {
                    0x0 => builder.build_int_add(src32, imm32, "addiw").unwrap(),
                    0x1 => {
                        let sh = i32_type.const_int(shamt as u64, false);
                        builder.build_left_shift(src32, sh, "slliw").unwrap()
                    }
                    0x5 => {
                        let sh = i32_type.const_int(shamt as u64, false);
                        if funct7 == 0x20 {
                            builder.build_right_shift(src32, sh, true, "sraiw").unwrap()
                        } else {
                            builder.build_right_shift(src32, sh, false, "srliw").unwrap()
                        }
                    }
                    _ => {
                        builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                        needs_terminator = false;
                        pc += 4; continue;
                    }
                };
                let sext = builder.build_int_s_extend(result32, i64_type, "addiw_sx").unwrap();
                store_reg!(rd, sext);
            }

            // ---- OP-REG (add/sub/sll/slt/sltu/xor/srl/sra/or/and) --------
            0x33 => {
                let v1 = load_reg!(rs1);
                let v2 = load_reg!(rs2);
                // shift amount = low 6 bits of rs2
                let sh6 = builder.build_and(v2, i64_type.const_int(63, false), "sh6").unwrap();
                let result = match (funct7, funct3) {
                    (0x00, 0x0) => builder.build_int_add(v1, v2, "add").unwrap(),
                    (0x20, 0x0) => builder.build_int_sub(v1, v2, "sub").unwrap(),
                    (0x00, 0x1) => builder.build_left_shift(v1, sh6, "sll").unwrap(),
                    (0x00, 0x2) => {
                        let c = builder.build_int_compare(IntPredicate::SLT, v1, v2, "slt").unwrap();
                        builder.build_int_z_extend(c, i64_type, "slt_z").unwrap()
                    }
                    (0x00, 0x3) => {
                        let c = builder.build_int_compare(IntPredicate::ULT, v1, v2, "sltu").unwrap();
                        builder.build_int_z_extend(c, i64_type, "sltu_z").unwrap()
                    }
                    (0x00, 0x4) => builder.build_xor(v1, v2, "xor").unwrap(),
                    (0x00, 0x5) => builder.build_right_shift(v1, sh6, false, "srl").unwrap(),
                    (0x20, 0x5) => builder.build_right_shift(v1, sh6, true, "sra").unwrap(),
                    (0x00, 0x6) => builder.build_or(v1, v2, "or").unwrap(),
                    (0x00, 0x7) => builder.build_and(v1, v2, "and").unwrap(),
                    _ => {
                        builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                        needs_terminator = false;
                        pc += 4; continue;
                    }
                };
                store_reg!(rd, result);
            }

            // ---- OP-32 (addw/subw/sllw/srlw/sraw) -------------------------
            0x3B => {
                let v1_32 = {
                    let v = load_reg!(rs1);
                    builder.build_int_truncate(v, i32_type, "v1_32").unwrap()
                };
                let v2_32 = {
                    let v = load_reg!(rs2);
                    builder.build_int_truncate(v, i32_type, "v2_32").unwrap()
                };
                let sh5 = builder.build_and(
                    v2_32, i32_type.const_int(31, false), "sh5").unwrap();
                let result32: inkwell::values::IntValue = match (funct7, funct3) {
                    (0x00, 0x0) => builder.build_int_add(v1_32, v2_32, "addw").unwrap(),
                    (0x20, 0x0) => builder.build_int_sub(v1_32, v2_32, "subw").unwrap(),
                    (0x00, 0x1) => builder.build_left_shift(v1_32, sh5, "sllw").unwrap(),
                    (0x00, 0x5) => builder.build_right_shift(v1_32, sh5, false, "srlw").unwrap(),
                    (0x20, 0x5) => builder.build_right_shift(v1_32, sh5, true, "sraw").unwrap(),
                    _ => {
                        builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                        needs_terminator = false;
                        pc += 4; continue;
                    }
                };
                let sext = builder.build_int_s_extend(result32, i64_type, "op32_sx").unwrap();
                store_reg!(rd, sext);
            }

            // ---- SYSTEM (ecall/ebreak) --------------------------------------
            0x73 => {
                match insn >> 20 {
                    0 => {
                        // ecall: call the host callback
                        let call = builder.build_call(
                            ecall_decl,
                            &[regs_alloca.into(), mem_param.into(), mem_len_param.into()],
                            "ecall_ret",
                        ).unwrap();
                        let ret_val = call.try_as_basic_value().left().unwrap().into_int_value();
                        let zero_i32 = i32_type.const_zero();
                        let is_exit = builder.build_int_compare(
                            IntPredicate::SGE, ret_val, zero_i32, "is_exit").unwrap();
                        let exit_bb = context.append_basic_block(main_fn, "ecall_exit");
                        let cont_bb = context.append_basic_block(main_fn, "ecall_cont");
                        builder.build_conditional_branch(is_exit, exit_bb, cont_bb).unwrap();
                        builder.position_at_end(exit_bb);
                        builder.build_return(Some(&ret_val)).unwrap();
                        builder.position_at_end(cont_bb);
                        needs_terminator = true;
                    }
                    1 => {
                        // ebreak
                        builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                        needs_terminator = false;
                    }
                    _ => {
                        builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                        needs_terminator = false;
                    }
                }
            }

            // ---- MISC-MEM (fence — nop) ------------------------------------
            0x0F => { /* single-threaded nop */ }

            _ => {
                eprintln!("jit: unimplemented opcode {opcode:#x} at {pc:#x}");
                builder.build_return(Some(&i32_type.const_int(1, false))).unwrap();
                needs_terminator = false;
            }
        }

        pc += 4;
    }

    // Terminate the last BB if still open.
    if needs_terminator {
        builder.build_return(Some(&i32_type.const_int(0, false))).unwrap();
    }

    // Patch any BBs that were created in Pass 1 but never reached in Pass 2
    // (e.g. return-site BBs whose address == text_end).
    for (_addr, bb) in &bb_map {
        if bb.get_terminator().is_none() {
            builder.position_at_end(*bb);
            builder.build_unreachable().unwrap();
        }
    }

    // ---- Verify IR -------------------------------------------------------
    if let Err(e) = module.verify() {
        eprintln!("JIT IR verification failed:\n{}", e.to_string());
        return 1;
    }

    // ---- Optional IR / asm dump ----------------------------------------
    // Dump IR (pre-optimization) and optimised x86-64 assembly before the
    // module is consumed by the JIT execution engine.
    // Note: we do NOT run run_passes() here — mem2reg / O2 would promote the
    // regs alloca to SSA scalars, breaking the raw-pointer host callbacks.
    // The TargetMachine applies its own optimisations during code-gen without
    // mutating the IR module, so the .s output is optimised x86-64.
    if let Some(prefix) = dump_prefix {
        let triple   = TargetMachine::get_default_triple();
        let cpu      = TargetMachine::get_host_cpu_name();
        let features = TargetMachine::get_host_cpu_features();
        let tm = Target::from_triple(&triple)
            .expect("dump: from_triple")
            .create_target_machine(
                &triple, cpu.to_str().unwrap(), features.to_str().unwrap(),
                OptimizationLevel::Default,
                RelocMode::Default,
                CodeModel::Default,
            )
            .expect("dump: create_target_machine");

        // Write the translator-generated LLVM IR (pre-optimisation).
        let ll_path = format!("{prefix}.ll");
        module.print_to_file(std::path::Path::new(&ll_path))
            .expect("dump: print_to_file");
        eprintln!("jit: IR written to {ll_path}");

        // Write optimised x86-64 assembly (TM optimises during code-gen).
        let asm_path = format!("{prefix}.x86_64.s");
        tm.write_to_file(&module, FileType::Assembly, std::path::Path::new(&asm_path))
            .expect("dump: write_to_file");
        eprintln!("jit: asm written to {asm_path}");
    }

    // ---- JIT compile and execute ----------------------------------------
    let ee = module
        .create_jit_execution_engine(OptimizationLevel::Default)
        .expect("failed to create JIT execution engine");

    // Bind host callbacks.
    ee.add_global_mapping(&ecall_decl, jit_ecall as *const () as usize);
    ee.add_global_mapping(&jalr_decl,  jit_jalr_interp as *const () as usize);

    // Position builder at alloca_bb before the first BB for LLVM to accept
    // the module structure — the alloca BB is the true entry.
    // (We need to re-define main_fn's entry as alloca_bb.)
    // inkwell generates the entry BB as the first appended BB.
    // Our `alloca_bb` is indeed first, so this is fine.

    let exit_code = unsafe {
        let jit_main: inkwell::execution_engine::JitFunction<JitMainFn> =
            ee.get_function("jit_main").expect("jit_main not found");
        jit_main.call(loaded.mem.as_ptr(), loaded.mem.len() as u64, loaded.stack_top)
    };

    exit_code
}