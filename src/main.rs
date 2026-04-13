mod elf_loader;
mod emulator;

fn main() {
    let path = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "asm/hello".to_string());

    let loaded = elf_loader::load(&path).unwrap_or_else(|e| {
        eprintln!("error: {e}");
        std::process::exit(1);
    });

    let mut emu = emulator::Emulator::new(loaded.mem, loaded.entry);
    let code = emu.run();
    std::process::exit(code);
}
