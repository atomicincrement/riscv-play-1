mod elf_loader;

fn main() {
    let path = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "asm/hello".to_string());

    let loaded = elf_loader::load(&path).unwrap_or_else(|e| {
        eprintln!("error: {e}");
        std::process::exit(1);
    });

    println!("Loaded '{path}'");
    println!("  virtual memory : {} bytes ({} KB)", loaded.mem.len(), loaded.mem.len() / 1024);
    println!("  entry point    : {:#x}", loaded.entry);

    // Sanity-check: show the 4 bytes at the entry point — should be the
    // encoding of the first instruction (li a7, 64 → 0x04000893).
    let ep = loaded.entry as usize;
    let word = u32::from_le_bytes(loaded.mem[ep..ep + 4].try_into().unwrap());
    println!("  first insn     : {:#010x}", word);
}
