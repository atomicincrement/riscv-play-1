use goblin::elf::program_header::PT_LOAD;
use goblin::elf::Elf;
use std::error::Error;

/// Stack reserved above the segment area (4 MiB).
const STACK_SIZE: usize = 4 * 1024 * 1024;

/// A RISC-V ELF binary loaded into a flat virtual address space.
pub struct LoadedElf {
    /// Flat byte buffer spanning address 0 to the highest virtual address
    /// covered by any PT_LOAD segment, plus a STACK_SIZE guard region.
    pub mem: Vec<u8>,
    /// The ELF entry point virtual address.
    pub entry: u64,
    /// Start of the executable code region (≤ entry).
    pub text_base: u64,
    /// Virtual address one past the last byte of the executable (.text) segment.
    pub text_end: u64,
    /// Initial stack pointer: top of the stack region (exclusive upper bound).
    /// The emulator should set x2 (sp) to this value before executing.
    pub stack_top: u64,
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

    // Allocate the flat virtual memory, zero-initialised.  Append STACK_SIZE bytes
    // so that the guest's stack pointer starts at (max_addr + STACK_SIZE).
    let mem_size = max_addr + STACK_SIZE;
    let mut mem = vec![0u8; mem_size];

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

    // Find the end of the executable code.  Prefer the `.text` section's
    // extent when section headers are available.  Fall back to the end of
    // the executable PT_LOAD segment if they are stripped.
    use goblin::elf::program_header::PF_X;
    let (text_base, text_end) = {
        // Try section headers first.
        let section_range = elf
            .section_headers
            .iter()
            .filter(|sh| {
                elf.shdr_strtab
                    .get_at(sh.sh_name)
                    .map(|n| n == ".text")
                    .unwrap_or(false)
            })
            .map(|sh| (sh.sh_addr, sh.sh_addr + sh.sh_size))
            .next();

        // Fall back to the executable PT_LOAD segment.
        let segment_range = elf
            .program_headers
            .iter()
            .filter(|ph| ph.p_type == PT_LOAD && ph.p_flags & PF_X != 0)
            .map(|ph| (ph.p_vaddr, ph.p_vaddr + ph.p_memsz))
            .next();

        section_range
            .or(segment_range)
            .unwrap_or((elf.entry, elf.entry + 4))
    };
    let (text_base, text_end) = (text_base as u64, text_end as u64);

    Ok(LoadedElf {
        mem,
        entry: elf.entry,
        text_base,
        text_end,
        stack_top: mem_size as u64,
    })
}
