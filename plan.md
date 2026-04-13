# RiscV emulator POC 1

This is a quick test of RiscV architecture to build an emulator that can run "hello world".

## Goals

Prove out the basic pipeline of: load a RISC-V ELF binary → interpret it → JIT compile it → benchmark.
The binary is deliberately minimal (a single `write` syscall) so the focus is on the emulator infrastructure,
not on implementing a complete ISA.

---

## Steps

### 1) Build a Linux hello world program in RISC-V asm and assemble it

Write a minimal RV64I assembly file (`hello.s`) that:
- Places the string `"Hello, world!\n"` in the `.data` section (or inline via `la`).
- Uses the Linux RISC-V syscall convention:
  - `a7` = syscall number (`64` = `write`)
  - `a0` = file descriptor (`1` = stdout)
  - `a1` = pointer to buffer
  - `a2` = byte count
  - `ecall` to invoke the kernel
- Then calls `exit` (`a7 = 93`, `a0 = 0`, `ecall`).

Assemble with the `riscv64-linux-gnu` toolchain:
```
riscv64-linux-gnu-as -march=rv64i -mabi=lp64 -o hello.o hello.s
riscv64-linux-gnu-ld -o hello hello.o
```

The resulting ELF will be a statically linked RV64I binary with two `ecall` instructions.

Relevant instruction subset needed: `lui`, `addi`, `li` (pseudo), `la` (pseudo), `ecall`.

---

### 2) Write a Rust program to load the binary

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

### 3) Write a simple interpreter for RISC-V emulating the `write` Linux syscall

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

### 4) Verify that hello world runs and outputs to stdout

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

### 5) JIT compile the binary using Inkwell

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

### 6) Benchmark the interpreted and JIT-compiled versions

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
src/
  main.rs          # CLI entry point: load binary, run emulator or JIT
  emulator.rs      # Emulator struct, interpret loop, syscall handler
  jit.rs           # Inkwell-based JIT translator
  elf_loader.rs    # ELF parsing and memory layout
asm/
  hello.s          # RV64I hello-world source
benches/
  emulator.rs      # Criterion benchmarks
```

