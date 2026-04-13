use std::io::Write;

// ---------------------------------------------------------------------------
// Register ABI aliases (indices into the 32-element register file)
// ---------------------------------------------------------------------------
const A0: usize = 10; // return value / syscall arg 0
const A1: usize = 11; // syscall arg 1
const A2: usize = 12; // syscall arg 2
const A7: usize = 17; // syscall number

// ---------------------------------------------------------------------------
// Instruction opcodes (bits 6:0)
// ---------------------------------------------------------------------------
const OP_AUIPC: u32 = 0x17; // U-type: rd = PC + imm[31:12]
const OP_OP_IMM: u32 = 0x13; // I-type ALU: addi, etc.
const OP_SYSTEM: u32 = 0x73; // ecall, ebreak, CSR ops

// funct3 codes within OP_OP_IMM
const F3_ADD: u32 = 0x0; // addi

// Linux RISC-V syscall numbers
const SYS_WRITE: u64 = 64;
const SYS_EXIT: u64 = 93;

// ---------------------------------------------------------------------------
// Emulator
// ---------------------------------------------------------------------------

pub struct Emulator {
    /// Flat virtual address space.  Index 0 corresponds to virtual address 0.
    pub mem: Vec<u8>,
    /// General-purpose register file x0..x31.  x0 is hardwired to 0.
    pub regs: [u64; 32],
    /// Program counter (virtual address of the next instruction to fetch).
    pub pc: u64,
}

impl Emulator {
    pub fn new(mem: Vec<u8>, entry: u64) -> Self {
        Self {
            mem,
            regs: [0u64; 32],
            pc: entry,
        }
    }

    // ---- register accessors ------------------------------------------------

    #[inline]
    fn reg(&self, idx: usize) -> u64 {
        self.regs[idx] // x0 is always 0 because we never write to it
    }

    #[inline]
    fn set_reg(&mut self, idx: usize, val: u64) {
        if idx != 0 {
            self.regs[idx] = val;
        }
    }

    // ---- memory helpers ----------------------------------------------------

    fn fetch_u32(&self, addr: u64) -> u32 {
        let a = addr as usize;
        u32::from_le_bytes(self.mem[a..a + 4].try_into().unwrap())
    }

    // ---- syscall handler ---------------------------------------------------

    /// Execute the `ecall` at the current PC.
    /// Returns `Some(exit_code)` if the emulator should halt, `None` to continue.
    fn syscall(&mut self) -> Option<i32> {
        match self.reg(A7) {
            // write(fd, buf, count) -> bytes_written
            SYS_WRITE => {
                let fd = self.reg(A0);
                let buf_addr = self.reg(A1) as usize;
                let count = self.reg(A2) as usize;
                let data = &self.mem[buf_addr..buf_addr + count];

                let written: i64 = match fd {
                    1 => {
                        std::io::stdout().write_all(data).unwrap();
                        count as i64
                    }
                    2 => {
                        std::io::stderr().write_all(data).unwrap();
                        count as i64
                    }
                    _ => -1, // EBADF
                };

                self.set_reg(A0, written as u64);
                None
            }

            // exit(code)
            SYS_EXIT => Some(self.reg(A0) as i32),

            other => {
                eprintln!("unimplemented syscall a7={other}");
                Some(1)
            }
        }
    }

    // ---- fetch-decode-execute loop ----------------------------------------

    /// Run until an `exit` syscall (or an unrecognised instruction).
    /// Returns the exit code supplied by the guest.
    pub fn run(&mut self) -> i32 {
        loop {
            let insn = self.fetch_u32(self.pc);
            let opcode = insn & 0x7F;

            match opcode {
                // -- U-type: auipc -----------------------------------------
                OP_AUIPC => {
                    let rd = ((insn >> 7) & 0x1F) as usize;
                    // Upper-20 immediate: bits 31:12, zero the low 12.
                    // Sign-extend from 32 bits to 64.
                    let imm = (insn & 0xFFFFF000) as i32 as i64 as u64;
                    self.set_reg(rd, self.pc.wrapping_add(imm));
                    self.pc += 4;
                }

                // -- I-type ALU ops ----------------------------------------
                OP_OP_IMM => {
                    let rd = ((insn >> 7) & 0x1F) as usize;
                    let funct3 = (insn >> 12) & 0x7;
                    let rs1 = ((insn >> 15) & 0x1F) as usize;
                    // Sign-extend the 12-bit immediate from bit 31.
                    let imm = ((insn as i32) >> 20) as i64 as u64;

                    match funct3 {
                        F3_ADD => {
                            // addi rd, rs1, imm
                            self.set_reg(rd, self.reg(rs1).wrapping_add(imm));
                        }
                        _ => {
                            eprintln!(
                                "unimplemented OP_IMM funct3={funct3:#x} at pc={:#x}",
                                self.pc
                            );
                            return 1;
                        }
                    }
                    self.pc += 4;
                }

                // -- ecall / ebreak ----------------------------------------
                OP_SYSTEM => {
                    // funct12 (bits 31:20) == 0 → ecall, 1 → ebreak
                    let funct12 = insn >> 20;
                    match funct12 {
                        0 => {
                            // ecall
                            if let Some(code) = self.syscall() {
                                return code;
                            }
                        }
                        1 => {
                            eprintln!("ebreak at pc={:#x}", self.pc);
                            return 1;
                        }
                        _ => {
                            eprintln!(
                                "unimplemented SYSTEM funct12={funct12:#x} at pc={:#x}",
                                self.pc
                            );
                            return 1;
                        }
                    }
                    self.pc += 4;
                }

                _ => {
                    eprintln!(
                        "unimplemented opcode {opcode:#04x} (insn={insn:#010x}) at pc={:#x}",
                        self.pc
                    );
                    return 1;
                }
            }
        }
    }
}
