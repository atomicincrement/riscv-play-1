use goblin::elf::program_header::PT_LOAD;
use goblin::elf::Elf;
use std::error::Error;

/// A RISC-V ELF binary loaded into a flat virtual address space.
pub struct LoadedElf {
    /// Flat byte buffer spanning address 0 to the highest virtualaddress
    /// covered by any PT_LOAD segment.  Bytes not covered by any segment
    /// are zero-initialised.
    pub mem: Vec<u8>,
    /// The ELF entry point virtual address.
    pub entry: u64,
    /// Virtual address one past the last byte of the executable (.text) segment.
    pub text_end: u64,
}

/// Parse an ELF64 RISC-V binary from `path`, map every `PT_LOAD` segment
/// into a flat `Vec<u8>`, and return the region together with the entry
/// point address.
pub fn load(path: &str) -> Result<LoadedElf, Box<dyn Error>> {
    let bytes = std::fs::read(path)?;
    let elf = Elf::parse(&bytes)?;

    // Verify the file is actually a RISC-V ELF64.
    if elf.header.e_machine != goblin::elf::header::EM_RISCV {
        return Err(format!(
            "{}: not a RISC-V ELF (e_machine = {:#x})",
            path, elf.header.e_machine
        )
        .into());
    }

    // Determine the extent of the virtual address space we need.
    let max_addr = elf
        .program_headers
        .iter()
        .filter(|ph| ph.p_type == PT_LOAD)
        .map(|ph| ph.p_vaddr + ph.p_memsz)
        .max()
        .ok_or_else(|| format!("{}: no PT_LOAD segments", path))? as usize;

    // Allocate the flat virtual memory, zero-initialised.
    let mut mem = vec![0u8; max_addr];

    // Copy each PT_LOAD segment's file bytes into the correct virtual address.
    for ph in &elf.program_headers {
        if ph.p_type != PT_LOAD {
            continue;
        }

        let file_offset = ph.p_offset as usize;
        let file_size = ph.p_filesz as usize;
        let vaddr = ph.p_vaddr as usize;

        mem[vaddr..vaddr + file_size]
            .copy_from_slice(&bytes[file_offset..file_offset + file_size]);

        // The remainder of the segment (p_memsz - p_filesz) is the BSS
        // region, which is already zero from vec! initialisation.
    }

    // Find the end of the executable (.text) segment.
    use goblin::elf::program_header::PF_X;
    let text_end = elf
        .program_headers
        .iter()
        .filter(|ph| ph.p_type == PT_LOAD && ph.p_flags & PF_X != 0)
        .map(|ph| ph.p_vaddr + ph.p_memsz)
        .max()
        .unwrap_or(elf.entry + 4) as u64;

    Ok(LoadedElf {
        mem,
        entry: elf.entry,
        text_end,
    })
}
