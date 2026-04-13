use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=asm/hello.s");

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let asm_dir = manifest_dir.join("asm");
    let src = asm_dir.join("hello.s");
    let obj = asm_dir.join("hello.o");
    let elf = asm_dir.join("hello");

    let as_status = Command::new("riscv64-linux-gnu-as")
        .args(["-march=rv64i", "-mabi=lp64", "-o"])
        .arg(&obj)
        .arg(&src)
        .status()
        .expect("riscv64-linux-gnu-as not found; install binutils-riscv64-linux-gnu");

    assert!(as_status.success(), "assembler failed");

    let ld_status = Command::new("riscv64-linux-gnu-ld")
        .arg("-o")
        .arg(&elf)
        .arg(&obj)
        .status()
        .expect("riscv64-linux-gnu-ld not found");

    assert!(ld_status.success(), "linker failed");
}
