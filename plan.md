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

### 7) Benchmark the interpreted and JIT-compiled versions

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

