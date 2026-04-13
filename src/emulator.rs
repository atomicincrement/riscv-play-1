use std::io::Write;

// ---------------------------------------------------------------------------
// Register ABI aliases
// ---------------------------------------------------------------------------
const A0: usize = 10;
const A1: usize = 11;
const A2: usize = 12;
const A7: usize = 17;

// ---------------------------------------------------------------------------
// Linux RISC-V syscall numbers
// ---------------------------------------------------------------------------
const SYS_WRITE: u64 = 64;
const SYS_EXIT:  u64 = 93;

// ---------------------------------------------------------------------------
// Emulator
// ---------------------------------------------------------------------------

pub struct Emulator<'w> {
    /// Flat virtual address space.  Index 0 corresponds to virtual address 0.
    pub mem: Vec<u8>,
    /// General-purpose register file x0..x31.  x0 is hardwired to 0.
    pub regs: [u64; 32],
    /// Program counter (virtual address of the next instruction to fetch).
    pub pc: u64,
    /// Sink for guest fd 1 (stdout).
    stdout: Box<dyn Write + 'w>,
    /// Sink for guest fd 2 (stderr).
    stderr: Box<dyn Write + 'w>,
}

impl<'w> Emulator<'w> {
    /// Create an emulator that writes to the real process stdout/stderr.
    pub fn new(mem: Vec<u8>, entry: u64) -> Emulator<'static> {
        Emulator::with_writers(
            mem,
            entry,
            Box::new(std::io::stdout()),
            Box::new(std::io::stderr()),
        )
    }

    /// Create an emulator with custom writers — useful for testing.
    pub fn with_writers(
        mem: Vec<u8>,
        entry: u64,
        stdout: Box<dyn Write + 'w>,
        stderr: Box<dyn Write + 'w>,
    ) -> Self {
        Self { mem, regs: [0u64; 32], pc: entry, stdout, stderr }
    }

    // ---- register accessors ------------------------------------------------

    #[inline] fn reg(&self, i: usize) -> u64 { self.regs[i] }
    #[inline] fn set_reg(&mut self, i: usize, v: u64) { if i != 0 { self.regs[i] = v; } }

    // ---- bounds-checked memory helpers ------------------------------------

    fn check_bounds(&self, addr: u64, size: u64) -> Result<usize, String> {
        let end = addr.checked_add(size)
            .ok_or_else(|| format!("address overflow at {addr:#x}"))?;
        if end as usize > self.mem.len() {
            Err(format!(
                "memory access out of bounds: addr={addr:#x} size={size} memlen={:#x}",
                self.mem.len()
            ))
        } else {
            Ok(addr as usize)
        }
    }

    fn read8 (&self, addr: u64) -> Result<u8,  String> {
        let a = self.check_bounds(addr, 1)?;
        Ok(self.mem[a])
    }
    fn read16(&self, addr: u64) -> Result<u16, String> {
        let a = self.check_bounds(addr, 2)?;
        Ok(u16::from_le_bytes(self.mem[a..a+2].try_into().unwrap()))
    }
    fn read32(&self, addr: u64) -> Result<u32, String> {
        let a = self.check_bounds(addr, 4)?;
        Ok(u32::from_le_bytes(self.mem[a..a+4].try_into().unwrap()))
    }
    fn read64(&self, addr: u64) -> Result<u64, String> {
        let a = self.check_bounds(addr, 8)?;
        Ok(u64::from_le_bytes(self.mem[a..a+8].try_into().unwrap()))
    }
    fn write8 (&mut self, addr: u64, v: u8)  -> Result<(), String> {
        let a = self.check_bounds(addr, 1)?;
        self.mem[a] = v; Ok(())
    }
    fn write16(&mut self, addr: u64, v: u16) -> Result<(), String> {
        let a = self.check_bounds(addr, 2)?;
        self.mem[a..a+2].copy_from_slice(&v.to_le_bytes()); Ok(())
    }
    fn write32(&mut self, addr: u64, v: u32) -> Result<(), String> {
        let a = self.check_bounds(addr, 4)?;
        self.mem[a..a+4].copy_from_slice(&v.to_le_bytes()); Ok(())
    }
    fn write64(&mut self, addr: u64, v: u64) -> Result<(), String> {
        let a = self.check_bounds(addr, 8)?;
        self.mem[a..a+8].copy_from_slice(&v.to_le_bytes()); Ok(())
    }

    // ---- syscall handler ---------------------------------------------------

    fn syscall(&mut self) -> Option<i32> {
        match self.reg(A7) {
            SYS_WRITE => {
                let fd    = self.reg(A0);
                let buf   = self.reg(A1) as usize;
                let count = self.reg(A2) as usize;
                if buf.saturating_add(count) > self.mem.len() {
                    eprintln!("write: buffer out of bounds");
                    self.set_reg(A0, (-1i64) as u64);
                    return None;
                }
                let data = self.mem[buf..buf + count].to_vec();
                let written: i64 = match fd {
                    1 => { self.stdout.write_all(&data).unwrap(); count as i64 }
                    2 => { self.stderr.write_all(&data).unwrap(); count as i64 }
                    _ => -1,
                };
                self.set_reg(A0, written as u64);
                None
            }
            SYS_EXIT => Some(self.reg(A0) as i32),
            other => { eprintln!("unimplemented syscall a7={other}"); Some(1) }
        }
    }

    // ---- trap helper -------------------------------------------------------

    fn trap(&self, msg: impl std::fmt::Display) -> i32 {
        eprintln!("trap at pc={:#x}: {msg}", self.pc);
        1
    }

    // ---- fetch-decode-execute loop ----------------------------------------

    pub fn run(&mut self) -> i32 {
        loop {
            // Instruction fetch — bounds-checked.
            let insn = match self.read32(self.pc) {
                Ok(v) => v,
                Err(e) => return self.trap(format!("fetch: {e}")),
            };

            let opcode =  insn & 0x7F;
            let rd     = ((insn >>  7) & 0x1F) as usize;
            let funct3 =  (insn >> 12) & 0x07;
            let rs1    = ((insn >> 15) & 0x1F) as usize;
            let rs2    = ((insn >> 20) & 0x1F) as usize;
            let funct7 =   insn >> 25;

            // Immediates (sign-extended to u64).
            let imm_i = ((insn as i32) >> 20) as i64 as u64;
            let imm_u = (insn & 0xFFFF_F000) as i32 as i64 as u64;
            let imm_s = (((insn & 0xFE00_0000) as i32 >> 20) as u64)
                        | ((insn >> 7) & 0x1F) as u64;
            let imm_b = {
                let b12   = ((insn >> 31) & 1) as u64;
                let b11   = ((insn >>  7) & 1) as u64;
                let b10_5 = ((insn >> 25) & 0x3F) as u64;
                let b4_1  = ((insn >>  8) & 0x0F) as u64;
                let raw = (b12 << 12) | (b11 << 11) | (b10_5 << 5) | (b4_1 << 1);
                if b12 != 0 { raw | !0x1FFFu64 } else { raw }
            };
            let imm_j = {
                let b20    = ((insn >> 31) & 1) as u64;
                let b19_12 = ((insn >> 12) & 0xFF) as u64;
                let b11    = ((insn >> 20) & 1) as u64;
                let b10_1  = ((insn >> 21) & 0x3FF) as u64;
                let raw = (b20 << 20) | (b19_12 << 12) | (b11 << 11) | (b10_1 << 1);
                if b20 != 0 { raw | !0x1F_FFFFu64 } else { raw }
            };

            match opcode {

                // ---- LUI ---------------------------------------------------
                0x37 => {
                    self.set_reg(rd, imm_u);
                    self.pc += 4;
                }

                // ---- AUIPC -------------------------------------------------
                0x17 => {
                    self.set_reg(rd, self.pc.wrapping_add(imm_u));
                    self.pc += 4;
                }

                // ---- JAL ---------------------------------------------------
                0x6F => {
                    let ret = self.pc.wrapping_add(4);
                    self.set_reg(rd, ret);
                    self.pc = self.pc.wrapping_add(imm_j);
                }

                // ---- JALR --------------------------------------------------
                0x67 => {
                    let target = self.reg(rs1).wrapping_add(imm_i) & !1u64;
                    self.set_reg(rd, self.pc.wrapping_add(4));
                    self.pc = target;
                }

                // ---- Branches ----------------------------------------------
                0x63 => {
                    let v1 = self.reg(rs1);
                    let v2 = self.reg(rs2);
                    let taken = match funct3 {
                        0x0 => v1 == v2,                            // beq
                        0x1 => v1 != v2,                            // bne
                        0x4 => (v1 as i64) < (v2 as i64),          // blt
                        0x5 => (v1 as i64) >= (v2 as i64),         // bge
                        0x6 => v1 < v2,                             // bltu
                        0x7 => v1 >= v2,                            // bgeu
                        _   => return self.trap(format!("bad branch funct3={funct3:#x}")),
                    };
                    self.pc = if taken { self.pc.wrapping_add(imm_b) }
                              else      { self.pc.wrapping_add(4) };
                }

                // ---- Loads -------------------------------------------------
                0x03 => {
                    let addr = self.reg(rs1).wrapping_add(imm_i);
                    let val: Result<u64, String> = match funct3 {
                        0x0 => self.read8 (addr).map(|v| v as i8  as i64 as u64), // lb
                        0x1 => self.read16(addr).map(|v| v as i16 as i64 as u64), // lh
                        0x2 => self.read32(addr).map(|v| v as i32 as i64 as u64), // lw
                        0x3 => self.read64(addr),                                  // ld
                        0x4 => self.read8 (addr).map(|v| v as u64),               // lbu
                        0x5 => self.read16(addr).map(|v| v as u64),               // lhu
                        0x6 => self.read32(addr).map(|v| v as u64),               // lwu
                        _   => Err(format!("bad load funct3={funct3:#x}")),
                    };
                    match val {
                        Ok(v) => { self.set_reg(rd, v); self.pc += 4; }
                        Err(e) => return self.trap(e),
                    }
                }

                // ---- Stores ------------------------------------------------
                0x23 => {
                    let addr = self.reg(rs1).wrapping_add(imm_s);
                    let v    = self.reg(rs2);
                    let res = match funct3 {
                        0x0 => self.write8 (addr, v as u8),   // sb
                        0x1 => self.write16(addr, v as u16),  // sh
                        0x2 => self.write32(addr, v as u32),  // sw
                        0x3 => self.write64(addr, v),         // sd
                        _   => Err(format!("bad store funct3={funct3:#x}")),
                    };
                    match res {
                        Ok(()) => self.pc += 4,
                        Err(e) => return self.trap(e),
                    }
                }

                // ---- OP-IMM (addi / slti / xori / ori / andi / slli / srli / srai) ---
                0x13 => {
                    let src   = self.reg(rs1);
                    let shamt = (imm_i & 0x3F) as u32;
                    let val = match funct3 {
                        0x0 => src.wrapping_add(imm_i),                        // addi
                        0x2 => ((src as i64) < (imm_i as i64)) as u64,         // slti
                        0x3 => (src < imm_i) as u64,                           // sltiu
                        0x4 => src ^ imm_i,                                     // xori
                        0x6 => src | imm_i,                                     // ori
                        0x7 => src & imm_i,                                     // andi
                        0x1 => src << shamt,                                    // slli
                        0x5 => if funct7 == 0x20 {
                                   ((src as i64) >> shamt) as u64               // srai
                               } else {
                                   src >> shamt                                 // srli
                               },
                        _   => return self.trap(format!("bad OP-IMM funct3={funct3:#x}")),
                    };
                    self.set_reg(rd, val);
                    self.pc += 4;
                }

                // ---- OP-IMM-32 (addiw / slliw / srliw / sraiw) ------------
                0x1B => {
                    let src   = self.reg(rs1) as u32;
                    let shamt = (imm_i & 0x1F) as u32;
                    let val32: u32 = match funct3 {
                        0x0 => src.wrapping_add(imm_i as u32),                 // addiw
                        0x1 => src << shamt,                                    // slliw
                        0x5 => if funct7 == 0x20 {
                                   ((src as i32) >> shamt) as u32               // sraiw
                               } else {
                                   src >> shamt                                 // srliw
                               },
                        _   => return self.trap(format!("bad OP-IMM-32 funct3={funct3:#x}")),
                    };
                    self.set_reg(rd, val32 as i32 as i64 as u64);
                    self.pc += 4;
                }

                // ---- OP-REG (add/sub/sll/slt/sltu/xor/srl/sra/or/and) -----
                0x33 => {
                    let v1    = self.reg(rs1);
                    let v2    = self.reg(rs2);
                    let shamt = (v2 & 0x3F) as u32;
                    let val = match (funct7, funct3) {
                        (0x00, 0x0) => v1.wrapping_add(v2),                    // add
                        (0x20, 0x0) => v1.wrapping_sub(v2),                    // sub
                        (0x00, 0x1) => v1 << shamt,                            // sll
                        (0x00, 0x2) => ((v1 as i64) < (v2 as i64)) as u64,     // slt
                        (0x00, 0x3) => (v1 < v2) as u64,                       // sltu
                        (0x00, 0x4) => v1 ^ v2,                                // xor
                        (0x00, 0x5) => v1 >> shamt,                            // srl
                        (0x20, 0x5) => ((v1 as i64) >> shamt) as u64,          // sra
                        (0x00, 0x6) => v1 | v2,                                // or
                        (0x00, 0x7) => v1 & v2,                                // and
                        _           => return self.trap(
                                           format!("bad OP funct7={funct7:#x} funct3={funct3:#x}")),
                    };
                    self.set_reg(rd, val);
                    self.pc += 4;
                }

                // ---- OP-32 (addw/subw/sllw/srlw/sraw) ---------------------
                0x3B => {
                    let v1    = self.reg(rs1) as u32;
                    let v2    = self.reg(rs2) as u32;
                    let shamt = (v2 & 0x1F) as u32;
                    let val32: u32 = match (funct7, funct3) {
                        (0x00, 0x0) => v1.wrapping_add(v2),                    // addw
                        (0x20, 0x0) => v1.wrapping_sub(v2),                    // subw
                        (0x00, 0x1) => v1 << shamt,                            // sllw
                        (0x00, 0x5) => v1 >> shamt,                            // srlw
                        (0x20, 0x5) => ((v1 as i32) >> shamt) as u32,          // sraw
                        _           => return self.trap(
                                           format!("bad OP-32 funct7={funct7:#x} funct3={funct3:#x}")),
                    };
                    self.set_reg(rd, val32 as i32 as i64 as u64);
                    self.pc += 4;
                }

                // ---- SYSTEM (ecall / ebreak) --------------------------------
                0x73 => {
                    match insn >> 20 {
                        0 => { if let Some(code) = self.syscall() { return code; } }
                        1 => return self.trap("ebreak"),
                        _ => return self.trap(format!("bad SYSTEM insn {insn:#010x}")),
                    }
                    self.pc += 4;
                }

                // ---- MISC-MEM (fence — single-threaded nop) ----------------
                0x0F => { self.pc += 4; }

                _ => return self.trap(format!("unknown opcode {opcode:#04x} insn={insn:#010x}")),
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::elf_loader;

    fn run_hello() -> (i32, Vec<u8>) {
        let loaded = elf_loader::load("asm/hello")
            .expect("asm/hello not found — run cargo build first");
        let mut out: Vec<u8> = Vec::new();
        let code = {
            let mut emu = Emulator::with_writers(
                loaded.mem, loaded.entry,
                Box::new(&mut out), Box::new(std::io::sink()),
            );
            emu.run()
        };
        (code, out)
    }

    #[test]
    fn hello_world_output() {
        let (code, out) = run_hello();
        assert_eq!(out, b"Hello, world!\n", "unexpected stdout");
        assert_eq!(code, 0, "unexpected exit code");
    }

    #[test]
    fn x0_is_hardwired_zero() {
        // addi x0, x0, 42 must leave x0 == 0.
        // 0x02a00013 = addi x0, x0, 42
        // 0x05d00893 = addi a7, x0, 93
        // 0x00000073 = ecall
        let mut mem = vec![0u8; 0x1000];
        mem[0..4].copy_from_slice(&0x02a00013u32.to_le_bytes());
        mem[4..8].copy_from_slice(&0x05d00893u32.to_le_bytes());
        mem[8..12].copy_from_slice(&0x00000073u32.to_le_bytes());
        let mut emu = Emulator::with_writers(
            mem, 0, Box::new(std::io::sink()), Box::new(std::io::sink()),
        );
        let code = emu.run();
        assert_eq!(emu.regs[0], 0, "x0 must always be 0");
        assert_eq!(code, 0);
    }

    #[test]
    fn bounds_check_read() {
        // addi a0, x0, 12   (a0 = 12)
        // ld   a1, 0(a0)    (load 8 bytes at addr 12; memory is only 16 bytes → OOB at 20)
        // The emulator should trap and return exit code 1.
        let mut mem = vec![0u8; 16];
        mem[0..4].copy_from_slice(&0x00c00513u32.to_le_bytes()); // addi a0, x0, 12
        mem[4..8].copy_from_slice(&0x00053583u32.to_le_bytes()); // ld a1, 0(a0)
        // (no exit syscall needed — should never reach it)
        let mut emu = Emulator::with_writers(
            mem, 0, Box::new(std::io::sink()), Box::new(std::io::sink()),
        );
        let code = emu.run();
        assert_eq!(code, 1, "expected out-of-bounds trap");
    }

    #[test]
    fn arithmetic_ops() {
        // Encode addi and R-type instructions to test ALU ops.
        let addi = |rd: u32, rs1: u32, imm: i32| -> u32 {
            ((imm as u32 & 0xFFF) << 20) | (rs1 << 15) | (rd << 7) | 0x13
        };
        let rtype = |rd: u32, rs1: u32, rs2: u32, f3: u32, f7: u32| -> u32 {
            (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33
        };

        let mut mem = vec![0u8; 0x1000];
        let mut off = 0usize;
        let mut emit = |insn: u32| {
            mem[off..off+4].copy_from_slice(&insn.to_le_bytes()); off += 4;
        };

        emit(addi(10, 0, 7));              // addi a0, x0, 7
        emit(addi(11, 0, 3));              // addi a1, x0, 3
        emit(rtype(12, 10, 11, 0, 0x00)); // add  a2, a0, a1  → 10
        emit(rtype(13, 10, 11, 0, 0x20)); // sub  a3, a0, a1  → 4
        emit(rtype(14, 10, 11, 7, 0x00)); // and  a4, a0, a1  → 3
        emit(rtype(15, 10, 11, 6, 0x00)); // or   a5, a0, a1  → 7
        emit(rtype(16, 10, 11, 4, 0x00)); // xor  a6, a0, a1  → 4
        emit(0x05d00893);                  // li a7, 93
        emit(0x00000073);                  // ecall

        let mut emu = Emulator::with_writers(
            mem, 0, Box::new(std::io::sink()), Box::new(std::io::sink()),
        );
        emu.run();
        assert_eq!(emu.regs[12], 10, "add");
        assert_eq!(emu.regs[13],  4, "sub");
        assert_eq!(emu.regs[14],  3, "and");
        assert_eq!(emu.regs[15],  7, "or");
        assert_eq!(emu.regs[16],  4, "xor");
    }

    #[test]
    fn branch_load_store() {
        // Store 42 at mem[0x100], load it back, beq taken → clean exit(0).
        let sw = |rs1: u32, rs2: u32| -> u32 {
            // sw rs2, 0(rs1) → imm=0
            (rs2 << 20) | (rs1 << 15) | (0x2 << 12) | 0x23
        };
        let lw = |rd: u32, rs1: u32| -> u32 {
            // lw rd, 0(rs1) → imm=0
            (rs1 << 15) | (0x2 << 12) | (rd << 7) | 0x03
        };
        let addi = |rd: u32, rs1: u32, imm: i32| -> u32 {
            ((imm as u32 & 0xFFF) << 20) | (rs1 << 15) | (rd << 7) | 0x13
        };
        // beq rs1, rs2, +8 (skip next 4-byte insn)
        let beq_plus8 = |rs1: u32, rs2: u32| -> u32 {
            // offset=8: b11=0 b12=0 b10_5=0 b4_1=0b0100=4
            let b4_1: u32 = 4;
            (rs2 << 20) | (rs1 << 15) | (0x0 << 12) | (b4_1 << 8) | 0x63
        };

        let mut mem = vec![0u8; 0x200];
        let mut off = 0usize;
        let mut emit = |insn: u32| {
            mem[off..off+4].copy_from_slice(&insn.to_le_bytes()); off += 4;
        };

        emit(addi(10, 0, 42));         // addi a0, x0, 42
        emit(addi(11, 0, 0x100));      // addi a1, x0, 0x100
        emit(sw(11, 10));              // sw a0, 0(a1)   (store 42)
        emit(lw(12, 11));              // lw a2, 0(a1)   (load 42)
        emit(beq_plus8(12, 10));       // beq a2, a0, +8 (should be taken)
        emit(addi(17, 0, 1));          // li a7, 1   ← skipped if branch taken
        emit(addi(17, 0, 93));         // li a7, 93
        emit(addi(10, 0, 0));          // li a0, 0  (exit code)
        emit(0x00000073);              // ecall

        let mut emu = Emulator::with_writers(
            mem, 0, Box::new(std::io::sink()), Box::new(std::io::sink()),
        );
        let code = emu.run();
        assert_eq!(code, 0, "branch not taken or wrong exit code");
        assert_eq!(emu.regs[12], 42, "load/store round-trip failed");
    }
}
