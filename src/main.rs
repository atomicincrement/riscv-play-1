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

    // --dump: when passed with --jit, write optimised IR and x86-64 asm
    // alongside the guest binary (e.g. tests/arith → tests/arith.ll / tests/arith.x86_64.s).
    let dump = if args.first().map(|s| s.as_str()) == Some("--dump") {
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
        let dump_prefix = if dump { Some(path.as_str()) } else { None };
        jit::run(&loaded, dump_prefix)
    } else {
        let stack_top = loaded.stack_top;
        let mut emu = emulator::Emulator::new(loaded.mem, loaded.entry);
        emu.regs[2] = stack_top; // x2 (sp) – required by C ABI
        emu.run()
    };

    std::process::exit(code);
}
