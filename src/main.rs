mod elf_loader;
mod emulator;
mod jit;

fn main() {
    let mut args: Vec<String> = std::env::args().skip(1).collect();

    let use_jit = if args.first().map(|s| s.as_str()) == Some("--jit") {
        args.remove(0);
        true
    } else {
        false
    };

    let path = args.into_iter().next().unwrap_or_else(|| "asm/hello".to_string());

    let loaded = elf_loader::load(&path).unwrap_or_else(|e| {
        eprintln!("error: {e}");
        std::process::exit(1);
    });

    let code = if use_jit {
        jit::run(&loaded)
    } else {
        let mut emu = emulator::Emulator::new(loaded.mem, loaded.entry);
        emu.run()
    };

    std::process::exit(code);
}
