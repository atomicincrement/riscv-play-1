# RiscV emulator POC 1

This is a quick test of RiscV architecture to build an emulator that can run "hello world".

## Goals

Prove out the basic pipeline of: load a RISC-V ELF binary → interpret it → JIT compile it → benchmark.
The binary is deliberately minimal (a single `write` syscall) so the focus is on the emulator infrastructure,
not on implementing a complete ISA.

---

## Prerequisites

### RISC-V cross-compilation toolchain (`binutils-riscv64-linux-gnu`)

The cross-assembler (`riscv64-linux-gnu-as`) and cross-linker (`riscv64-linux-gnu-ld`) are needed
to build the hello-world ELF from `asm/hello.s`. They are also invoked automatically by `build.rs`
during `cargo build`.

**Debian / Ubuntu (including WSL)**
```bash
sudo apt update
sudo apt install binutils-riscv64-linux-gnu qemu-user
```

**Fedora / RHEL / CentOS Stream**
```bash
sudo dnf install binutils-riscv64-linux-gnu qemu-user
# or on older RHEL-based systems:
sudo yum install binutils-riscv64-linux-gnu qemu-user
```

**Arch Linux**
```bash
sudo pacman -S riscv64-linux-gnu-binutils qemu-user-static
```

**macOS (Homebrew)**
```bash
brew tap riscv-software-src/riscv
brew install riscv-tools
# binaries are prefixed riscv64-unknown-elf-as / riscv64-unknown-elf-ld
# update build.rs to use those names instead
# Note: qemu-user is Linux-only; on macOS use a Linux VM to run step 2
```

**Verify the install:**
```bash
riscv64-linux-gnu-as --version
riscv64-linux-gnu-ld --version
qemu-riscv64 --version
```

Both commands should print version info without errors.

---

## Steps

### 1) Build a Linux hello world program in RISC-V asm and assemble it

Write a minimal RV64I assembly file (`asm/hello.s`) that:
- Places the string `"Hello, world!\n"` in the `.data` section (or inline via `la`).
- Uses the Linux RISC-V syscall convention:
  - `a7` = syscall number (`64` = `write`)
  - `a0` = file descriptor (`1` = stdout)
  - `a1` = pointer to buffer
  - `a2` = byte count
  - `ecall` to invoke the kernel
- Then calls `exit` (`a7 = 93`, `a0 = 0`, `ecall`).

The resulting ELF will be a statically linked RV64I binary with two `ecall` instructions.

Relevant instruction subset needed: `lui`, `addi`, `li` (pseudo), `la` (pseudo), `ecall`.

#### Automating the build with `build.rs`

> **Why not the `cc` crate?** The `cc` crate compiles C/C++ (and sometimes `.s` files) into
> *static libraries that are linked into the Rust binary at compile time*. Here we need a
> *standalone ELF executable* that the emulator loads at runtime — a different output entirely.
> `std::process::Command` in `build.rs` gives us direct control over the RISC-V toolchain.

Add a `build.rs` at the crate root that assembles and links the binary automatically whenever
`asm/hello.s` changes:

```rust
// build.rs
use std::process::Command;
use std::path::Path;

fn main() {
    println!("cargo:rerun-if-changed=asm/hello.s");

    let out = Path::new("asm");  // emit next to source for simplicity; use OUT_DIR for cleanliness

    let as_status = Command::new("riscv64-linux-gnu-as")
        .args(["-march=rv64i", "-mabi=lp64", "-o", "asm/hello.o", "asm/hello.s"])
        .status()
        .expect("riscv64-linux-gnu-as not found; install binutils-riscv64-linux-gnu");

    assert!(as_status.success(), "assembler failed");

    let ld_status = Command::new("riscv64-linux-gnu-ld")
        .args(["-o", "asm/hello", "asm/hello.o"])
        .status()
        .expect("riscv64-linux-gnu-ld not found");

    assert!(ld_status.success(), "linker failed");
}
```

`cargo build` will now assemble and link `asm/hello` before compiling any Rust code.
The `cargo:rerun-if-changed` directive ensures the step is skipped on subsequent builds
unless `asm/hello.s` is modified.

See the **Prerequisites** section above for toolchain installation instructions.

---

### 2) Test the hello binary with QEMU

Before writing our own emulator, run the assembled binary through **QEMU user-mode emulation** to
confirm that `asm/hello.s` is correct and that `build.rs` produced a valid ELF.

#### Install QEMU RISC-V user-mode emulator

**Debian / Ubuntu**
```bash
sudo apt install qemu-user
```

**Fedora / RHEL**
```bash
sudo dnf install qemu-user
```

**Arch Linux**
```bash
sudo pacman -S qemu-user-static
```

**Verify:**
```bash
qemu-riscv64 --version
```

#### Run the binary

```bash
qemu-riscv64 asm/hello
```

Expected output:
```
Hello, world!
```

`qemu-riscv64` runs RV64 Linux ELFs natively on the host by intercepting `ecall` instructions and
translating them to host syscalls — the same job our emulator will do. If this step fails, the
problem is in the assembly source or the toolchain, not in the Rust code.

#### Automate with a helper script

Cargo aliases only invoke Cargo subcommands, not arbitrary shell commands, so a small
script is the simplest approach:

```bash
#!/usr/bin/env bash
# scripts/qemu-test.sh
set -e
qemu-riscv64 asm/hello
```

Run it with:
```bash
bash scripts/qemu-test.sh
```

---

### 3) Write a Rust program to load the binary

Parse the ELF file and set up a flat virtual address space in a `Vec<u8>`.

- Use the [`goblin`](https://crates.io/crates/goblin) crate to parse ELF headers and program headers.
- Copy each `PT_LOAD` segment into the buffer at its `p_vaddr` offset.
- Record the entry point address (`e_entry`) as the initial program counter.
- Store the virtual memory buffer, a 32-element register file (`[u64; 32]`), and the PC in an `Emulator` struct.
  - `x0` is hardwired to zero; writes to it are silently discarded.

```rust
struct Emulator {
    mem: Vec<u8>,          // flat virtual memory
    regs: [u64; 32],       // x0..x31 (x0 always reads as 0)
    pc: u64,
}
```

---

### 4) Write a simple interpreter for RISC-V emulating the `write` Linux syscall

Implement a fetch-decode-execute loop over RV64I instructions (all 32-bit fixed width).

**Decode** the standard RISC-V base instruction formats: R, I, S, B, U, J.
Extract `opcode` (bits 6:0), `rd`, `rs1`, `rs2`, `funct3`, `funct7` as needed.

**Instructions to implement** (minimum set for the hello-world binary):

| Mnemonic | Format | Opcode | Notes |
|----------|--------|--------|-------|
| `lui`    | U      | 0x37   | Load upper immediate into `rd` |
| `auipc`  | U      | 0x17   | PC + upper immediate into `rd` |
| `addi`   | I      | 0x13 / funct3=0 | Add sign-extended immediate |
| `addiw`  | I      | 0x1B / funct3=0 | 32-bit add, sign-extend result |
| `ecall`  | I      | 0x73   | Environment call (syscall) |

**Syscall handling** (triggered by `ecall`, dispatch on `a7` = `regs[17]`):

| `a7` | Name    | Args                        | Action |
|------|---------|-----------------------------|--------|
| 64   | `write` | `a0`=fd, `a1`=buf, `a2`=len | Write `mem[a1..a1+a2]` to `std::io::stdout()` |
| 93   | `exit`  | `a0`=code                   | Return `a0` as exit code, stop the loop |

Return values are written back to `a0` (`regs[10]`).

---

### 5) Verify that hello world runs and outputs to stdout

Run the emulator with the assembled `hello` binary as input:

```
cargo run -- hello
```

Expected output:
```
Hello, world!
```

Add a test that captures stdout and asserts the output matches.

---

### 6) JIT compile the binary using Inkwell

Use [`inkwell`](https://crates.io/crates/inkwell) (safe Rust bindings to LLVM) to translate the
decoded RISC-V instruction stream into LLVM IR, then compile and execute it natively.

**Approach — Ahead-of-JIT (single-pass translation):**

1. Iterate over the instructions in the `.text` section (same decode logic as the interpreter).
2. For each instruction, emit LLVM IR that performs the equivalent operation on an `[i64; 32]`
   register array allocated as an `alloca` in the entry block.
3. Translate `ecall` into a call to a Rust extern function (the same syscall handler used by the interpreter).
4. Use `ExecutionEngine::get_function` to get a function pointer and call it.

Key Inkwell types: `Context`, `Module`, `Builder`, `ExecutionEngine` (use `create_jit_execution_engine`
with `OptimizationLevel::Default`).

**IR sketch for `addi rd, rs1, imm`:**

```llvm
%rs1_val = load i64, i64* %regs_rs1
%result  = add i64 %rs1_val, <sign_extended_imm>
store i64 %result, i64* %regs_rd
```

---

### 7) Extend the interpreter to the full RV64I integer instruction set

The hello-world binary only exercises a tiny subset of RV64I. To run real programs the interpreter
needs to cover all base integer instructions. This section enumerates every instruction in the
RV64I spec, grouped by encoding format, showing what must be added on top of the current
`addi` / `auipc` / `ecall` skeleton.

**Opcode map** (bits 6:0 of every 32-bit instruction):

| Opcode | Format | Mnemonic group |
|--------|--------|----------------|
| `0x37` | U      | `lui` |
| `0x17` | U      | `auipc` ✓ (implemented) |
| `0x6F` | J      | `jal` |
| `0x67` | I      | `jalr` |
| `0x63` | B      | `beq bne blt bge bltu bgeu` |
| `0x03` | I      | loads: `lb lh lw ld lbu lhu lwu` |
| `0x23` | S      | stores: `sb sh sw sd` |
| `0x13` | I      | integer-immediate: `addi` ✓ `slti sltiu xori ori andi slli srli srai` |
| `0x1B` | I      | 32-bit immediate: `addiw slliw srliw sraiw` |
| `0x33` | R      | integer-register: `add sub sll slt sltu xor srl sra or and` |
| `0x3B` | R      | 32-bit register: `addw subw sllw srlw sraw` |
| `0x73` | I      | `ecall` ✓ `ebreak` CSRs (optional) |
| `0x0F` | I      | `fence` (treat as no-op for single-threaded emulation) |

#### Encoding formats (reminder)

All instructions are 32 bits, little-endian.

```
R  [ funct7 | rs2 | rs1 | funct3 | rd  | opcode ]
   [31    25|24 20|19 15|14    12|11 7 |6      0]

I  [ imm[11:0]   | rs1 | funct3 | rd  | opcode ]
   [31         20|19 15|14    12|11 7 |6      0]

S  [ imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode ]
   [31       25|24 20|19 15|14    12|11       7|6      0]

B  [ imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode ]
   [31          25|24 20|19 15|14    12|11           7|6      0]

U  [ imm[31:12]            | rd  | opcode ]
   [31                   12|11 7 |6      0]

J  [ imm[20|10:1|11|19:12] | rd  | opcode ]
   [31                   12|11 7 |6      0]
```

#### Instruction-by-instruction implementation notes

**U-type**

| Mnemonic | Opcode | Operation |
|----------|--------|-----------|
| `lui`    | `0x37` | `rd = imm` (upper 20 bits, low 12 zeroed, sign-extended to 64) |
| `auipc`  | `0x17` | `rd = pc + imm` ✓ |

**J-type**

| Mnemonic | Operation |
|----------|-----------|
| `jal rd, offset` | `rd = pc + 4; pc += sign_extend(imm)`. Immediate is 21-bit byte offset assembled from bits 31, 19:12, 20, 10:1 (× 2 LSB implied). |

**I-type jumps / loads**

| Mnemonic | funct3 | Operation |
|----------|--------|-----------|
| `jalr rd, rs1, imm` | — | `tmp = (rs1 + imm) & !1; rd = pc+4; pc = tmp` |
| `lb`  | `0x0` | `rd = sign_extend_8(mem[rs1+imm])` |
| `lh`  | `0x1` | `rd = sign_extend_16(mem[rs1+imm])` |
| `lw`  | `0x2` | `rd = sign_extend_32(mem[rs1+imm])` |
| `ld`  | `0x3` | `rd = mem[rs1+imm]` (64-bit) |
| `lbu` | `0x4` | `rd = zero_extend_8(mem[rs1+imm])` |
| `lhu` | `0x5` | `rd = zero_extend_16(mem[rs1+imm])` |
| `lwu` | `0x6` | `rd = zero_extend_32(mem[rs1+imm])` |

**B-type branches** — immediate is 13-bit byte offset (LSB implied 0)

| Mnemonic | funct3 | Condition |
|----------|--------|-----------|
| `beq`  | `0x0` | `rs1 == rs2` |
| `bne`  | `0x1` | `rs1 != rs2` |
| `blt`  | `0x4` | `(rs1 as i64) < (rs2 as i64)` |
| `bge`  | `0x5` | `(rs1 as i64) >= (rs2 as i64)` |
| `bltu` | `0x6` | `rs1 < rs2` (unsigned) |
| `bgeu` | `0x7` | `rs1 >= rs2` (unsigned) |

If taken: `pc += sign_extend(imm)`.  If not taken: `pc += 4`.

**S-type stores**

| Mnemonic | funct3 | Operation |
|----------|--------|-----------|
| `sb` | `0x0` | `mem[rs1+imm][0]    = rs2 as u8` |
| `sh` | `0x1` | `mem[rs1+imm][0..2] = rs2 as u16 LE` |
| `sw` | `0x2` | `mem[rs1+imm][0..4] = rs2 as u32 LE` |
| `sd` | `0x3` | `mem[rs1+imm][0..8] = rs2 as u64 LE` |

S-type immediate: `imm = sign_extend({ insn[31:25], insn[11:7] })`.

**I-type integer-immediate** (opcode `0x13`)

| funct3 | Mnemonic | Operation |
|--------|----------|-----------|
| `0x0` | `addi`  | `rd = rs1 + imm` ✓ |
| `0x2` | `slti`  | `rd = ((rs1 as i64) < (imm as i64)) as u64` |
| `0x3` | `sltiu` | `rd = (rs1 < imm) as u64` (unsigned) |
| `0x4` | `xori`  | `rd = rs1 ^ imm` |
| `0x6` | `ori`   | `rd = rs1 \| imm` |
| `0x7` | `andi`  | `rd = rs1 & imm` |
| `0x1` | `slli`  | `rd = rs1 << shamt` (shamt = imm[5:0]) |
| `0x5` | `srli` / `srai` | funct7 bit 30: `0` → logical, `1` → arithmetic |

**I-type 32-bit immediate** (opcode `0x1B`) — result sign-extended to 64 bits

| funct3 | Mnemonic | Operation |
|--------|----------|-----------|
| `0x0` | `addiw` | `rd = sign_extend_32(rs1 as u32 + imm as u32)` |
| `0x1` | `slliw` | `rd = sign_extend_32((rs1 as u32) << shamt)` |
| `0x5` | `srliw` / `sraiw` | funct7 bit 30: `0` → logical, `1` → arithmetic |

**R-type integer-register** (opcode `0x33`)

| funct7 | funct3 | Mnemonic | Operation |
|--------|--------|----------|-----------|
| `0x00` | `0x0` | `add`  | `rd = rs1 + rs2` |
| `0x20` | `0x0` | `sub`  | `rd = rs1 - rs2` |
| `0x00` | `0x1` | `sll`  | `rd = rs1 << (rs2 & 63)` |
| `0x00` | `0x2` | `slt`  | `rd = ((rs1 as i64) < (rs2 as i64)) as u64` |
| `0x00` | `0x3` | `sltu` | `rd = (rs1 < rs2) as u64` |
| `0x00` | `0x4` | `xor`  | `rd = rs1 ^ rs2` |
| `0x00` | `0x5` | `srl`  | `rd = rs1 >> (rs2 & 63)` (logical) |
| `0x20` | `0x5` | `sra`  | `rd = ((rs1 as i64) >> (rs2 & 63)) as u64` |
| `0x00` | `0x6` | `or`   | `rd = rs1 \| rs2` |
| `0x00` | `0x7` | `and`  | `rd = rs1 & rs2` |

**R-type 32-bit register** (opcode `0x3B`) — result sign-extended to 64 bits

| funct7 | funct3 | Mnemonic | Operation |
|--------|--------|----------|-----------|
| `0x00` | `0x0` | `addw` | `sign_extend_32(rs1 as u32 + rs2 as u32)` |
| `0x20` | `0x0` | `subw` | `sign_extend_32(rs1 as u32 - rs2 as u32)` |
| `0x00` | `0x1` | `sllw` | `sign_extend_32((rs1 as u32) << (rs2 & 31))` |
| `0x00` | `0x5` | `srlw` | `sign_extend_32((rs1 as u32) >> (rs2 & 31))` |
| `0x20` | `0x5` | `sraw` | `sign_extend_32((rs1 as i32) >> (rs2 & 31))` |

#### Implementation strategy

1. Extend the `match opcode` in `emulator.rs` with a new arm for each missing opcode (`0x37`, `0x6F`, `0x67`, `0x63`, `0x03`, `0x23`, `0x33`, `0x3B`, `0x0F`).
2. Add inner `match funct3` (and where needed `funct7`) within each arm.
3. Treat `fence` (`0x0F`) as a no-op (single-threaded emulator has no memory ordering concerns).
4. Helper for sign-extension: `fn sign_extend(val: u64, bits: u32) -> u64`.

#### Validation

Write a small C program (`tests/arith.c`), cross-compile it with `riscv64-linux-gnu-gcc -static -march=rv64i -mabi=lp64`, and run it through both QEMU and our emulator, asserting identical stdout and exit codes.

---

### 8) Benchmark the interpreted and JIT-compiled versions

Use [`criterion`](https://crates.io/crates/criterion) for statistically sound micro-benchmarks.

Add to `Cargo.toml`:
```toml
[dev-dependencies]
criterion = { version = "0.5", features = ["html_reports"] }

[[bench]]
name = "emulator"
harness = false
```

Benchmark both:
- `bench_interpret`: run the interpreter loop N times on the same binary.
- `bench_jit`: compile once (outside the timed region) then call the JIT-compiled function N times.

Run with:
```
cargo bench
```

Expected result: the JIT version should be significantly faster per-call once amortised compile cost
is excluded, since it executes native x86-64 instructions instead of a dispatch loop.

---

## Dependencies (planned)

```toml
[dependencies]
goblin  = "0.9"    # ELF parsing
inkwell = { version = "0.4", features = ["llvm18-0"] }  # LLVM JIT

[dev-dependencies]
criterion = { version = "0.5", features = ["html_reports"] }
```

## File layout (planned)

```
build.rs           # assembles asm/hello.s → asm/hello via riscv64-linux-gnu toolchain
src/
  main.rs          # CLI entry point: load binary, run emulator or JIT
  emulator.rs      # Emulator struct, interpret loop, syscall handler
  jit.rs           # Inkwell-based JIT translator
  elf_loader.rs    # ELF parsing and memory layout
asm/
  hello.s          # RV64I hello-world source
  hello.o          # (generated by build.rs)
  hello            # (generated by build.rs, loaded at runtime by the emulator)
benches/
  emulator.rs      # Criterion benchmarks
```

