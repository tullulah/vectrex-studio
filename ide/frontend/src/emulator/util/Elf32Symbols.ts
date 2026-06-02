/**
 * Elf32Symbols — extract symbol name→address map from an ARM ELF32 binary.
 *
 * ELF32 layout reference:
 *   Header (52 bytes):
 *     e_ident[16], e_type(2), e_machine(2), e_version(4), e_entry(4),
 *     e_phoff(4), e_shoff(4), e_flags(4), e_ehsize(2), e_phentsize(2),
 *     e_phnum(2), e_shentsize(2), e_shnum(2), e_shstrndx(2)
 *
 *   Section header (40 bytes):
 *     sh_name(4), sh_type(4), sh_flags(4), sh_addr(4), sh_offset(4),
 *     sh_size(4), sh_link(4), sh_info(4), sh_addralign(4), sh_entsize(4)
 *
 *   Symbol entry (16 bytes):
 *     st_name(4), st_value(4), st_size(4), st_info(1), st_other(1), st_shndx(2)
 *
 *   sh_type: SHT_NULL=0, SHT_PROGBITS=1, SHT_SYMTAB=2, SHT_STRTAB=3
 *   st_info & 0xf: STT_NOTYPE=0, STT_OBJECT=1, STT_FUNC=2
 *
 * ARM Thumb function symbols have bit 0 set in st_value (the Thumb bit).
 * We strip it with `& ~1` to produce the actual code address.
 */

const ELF_MAGIC = 0x464c457f; // 0x7F 'E' 'L' 'F'

const SHT_SYMTAB = 2;
const SHT_STRTAB = 3;

const STT_OBJECT = 1;
const STT_FUNC   = 2;

// ---------------------------------------------------------------------------
// Little-endian helpers
// ---------------------------------------------------------------------------

function readU32LE(buf: Uint8Array, off: number): number {
  return ((buf[off] | (buf[off + 1] << 8) | (buf[off + 2] << 16) | (buf[off + 3] << 24)) >>> 0);
}

function readU16LE(buf: Uint8Array, off: number): number {
  return ((buf[off] | (buf[off + 1] << 8)) >>> 0);
}

/** Read a null-terminated C string from a byte array. */
function readCString(buf: Uint8Array, offset: number): string {
  let end = offset;
  while (end < buf.length && buf[end] !== 0) end++;
  return String.fromCharCode(...buf.subarray(offset, end));
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Parse an ARM ELF32 binary and return a map of symbol name → address.
 *
 * Only STT_FUNC and STT_OBJECT symbols are included.  The Thumb bit (bit 0)
 * is stripped from function addresses so callers can use the values directly
 * as code addresses.
 *
 * Returns an empty map if the binary is not a valid ELF32 or has no symbol
 * table.
 */
export function extractElf32Symbols(elf: Uint8Array): Map<string, number> {
  const result = new Map<string, number>();

  // Validate ELF magic
  if (elf.length < 52) return result;
  if (readU32LE(elf, 0) !== ELF_MAGIC) return result;

  // ELF class must be 1 (32-bit)
  if (elf[4] !== 1) return result;

  // Data encoding must be 1 (little-endian)
  if (elf[5] !== 1) return result;

  // Read ELF header fields
  const e_shoff    = readU32LE(elf, 32); // section header table offset
  const e_shnum    = readU16LE(elf, 48); // number of section headers
  const e_shstrndx = readU16LE(elf, 50); // index of section name string table

  if (e_shoff === 0 || e_shnum === 0) return result;

  // Section header size is always 40 for ELF32
  const SH_SIZE = 40;

  /** Read one section header by index. */
  function readShdr(idx: number): { sh_name: number; sh_type: number; sh_offset: number; sh_size: number; sh_link: number; sh_entsize: number } | null {
    if (idx >= e_shnum) return null;
    const base = e_shoff + idx * SH_SIZE;
    if (base + SH_SIZE > elf.length) return null;
    return {
      sh_name:    readU32LE(elf, base +  0),
      sh_type:    readU32LE(elf, base +  4),
      sh_offset:  readU32LE(elf, base + 16),
      sh_size:    readU32LE(elf, base + 20),
      sh_link:    readU32LE(elf, base + 24),
      sh_entsize: readU32LE(elf, base + 36),
    };
  }

  // Load the section-name string table (.shstrtab) for section name lookups
  const shstrShdr = readShdr(e_shstrndx);
  const shstrtab: Uint8Array = shstrShdr
    ? elf.subarray(shstrShdr.sh_offset, shstrShdr.sh_offset + shstrShdr.sh_size)
    : new Uint8Array(0);

  // Find the .symtab section
  let symtabShdr: ReturnType<typeof readShdr> = null;
  for (let i = 0; i < e_shnum; i++) {
    const sh = readShdr(i);
    if (sh && sh.sh_type === SHT_SYMTAB) {
      symtabShdr = sh;
      break;
    }
  }

  if (!symtabShdr) return result;

  // The .strtab linked from symtab (sh_link gives section index)
  const strtabShdr = readShdr(symtabShdr.sh_link);
  if (!strtabShdr || strtabShdr.sh_type !== SHT_STRTAB) return result;

  const strtab = elf.subarray(strtabShdr.sh_offset, strtabShdr.sh_offset + strtabShdr.sh_size);

  // Symbol entry size: ELF32 sym = 16 bytes
  const entSize = symtabShdr.sh_entsize > 0 ? symtabShdr.sh_entsize : 16;
  const numSyms = symtabShdr.sh_size / entSize;

  for (let i = 0; i < numSyms; i++) {
    const base = symtabShdr.sh_offset + i * entSize;
    if (base + entSize > elf.length) break;

    const st_name  = readU32LE(elf, base + 0);
    const st_value = readU32LE(elf, base + 4);
    const st_info  = elf[base + 12];

    const stt = st_info & 0xf; // symbol type

    if (stt !== STT_FUNC && stt !== STT_OBJECT) continue;
    if (st_value === 0) continue; // undefined symbol

    const name = readCString(strtab, st_name);
    if (!name) continue;

    // Strip ARM Thumb bit from function addresses
    const addr = stt === STT_FUNC ? (st_value & ~1) >>> 0 : st_value >>> 0;

    result.set(name, addr);
  }

  return result;
}

/**
 * Read the ELF32 entry point address.
 * Returns 0 if the binary is not a valid ELF32.
 */
export function readElf32Entry(elf: Uint8Array): number {
  if (elf.length < 52) return 0;
  if (readU32LE(elf, 0) !== ELF_MAGIC) return 0;
  return readU32LE(elf, 24) & ~1; // e_entry, Thumb bit stripped
}

/**
 * Load all PT_LOAD segments from an ELF32 binary into a flash buffer.
 *
 * For each LOAD segment whose VMA falls within [flashBase, flashBase+flash.length),
 * the segment file data is copied into flash at offset (vaddr - flashBase).
 *
 * This is preferred over using a raw .bin file because the raw binary can be
 * contaminated by a different compilation target (e.g. M6809 128KB ROM
 * overwriting the same SnowBros.bin path as the 163KB ARM binary).
 *
 * @param elf       Raw ELF32 bytes.
 * @param flash     Destination buffer (pre-filled with 0xFF).
 * @param flashBase Base address of flash in the target's address space.
 * @returns         Number of segments loaded, or 0 on failure.
 */
export function loadElf32IntoFlash(elf: Uint8Array, flash: Uint8Array, flashBase: number): number {
  if (elf.length < 52) return 0;
  if (readU32LE(elf, 0) !== ELF_MAGIC) return 0;
  if (elf[4] !== 1) return 0; // must be ELF32
  if (elf[5] !== 1) return 0; // must be little-endian

  const PT_LOAD   = 1;
  const PHDR_SIZE = 32; // ELF32 program header entry is 32 bytes

  const e_phoff    = readU32LE(elf, 28); // offset of program header table
  const e_phnum    = readU16LE(elf, 44); // number of program headers

  if (e_phoff === 0 || e_phnum === 0) return 0;

  let loaded = 0;
  for (let i = 0; i < e_phnum; i++) {
    const base = e_phoff + i * PHDR_SIZE;
    if (base + PHDR_SIZE > elf.length) break;

    const p_type   = readU32LE(elf, base +  0);
    const p_offset = readU32LE(elf, base +  4);
    const p_vaddr  = readU32LE(elf, base +  8);
    const p_filesz = readU32LE(elf, base + 16);

    if (p_type !== PT_LOAD) continue;
    if (p_filesz === 0) continue;

    // Map VMA to flash offset
    const flashOffset = (p_vaddr - flashBase) >>> 0;
    if (flashOffset >= flash.length) continue; // outside flash range

    const copyLen = Math.min(p_filesz, flash.length - flashOffset);
    flash.set(elf.subarray(p_offset, p_offset + copyLen), flashOffset);
    loaded++;
  }

  return loaded;
}
