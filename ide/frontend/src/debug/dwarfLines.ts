/**
 * The line table of an ARM program's ELF (DWARF .debug_line, versions 2 to 5): which
 * source line each address belongs to, and where each line's statements start.
 *
 * The ARM builds write it for the .vpy files themselves — `.loc` from the asm backend,
 * `#line` from the C backend (buildtools vpy_codegen/src/arm/debug_lines.rs) — and the
 * SDK's C has its own. The IDE's ARM debugger (armSourceDebug.ts) maps editor
 * breakpoints and steps through it.
 *
 * Pure: bytes in, tables out. tools/dwarf-lines-test.ts checks it against objdump.
 */

export interface LineRow {
  address: number;
  file: string;
  line: number;
  isStmt: boolean;
}

/** A source line's code: [start, end) of one row. */
interface Range { start: number; end: number; file: string; line: number }

export interface LineTable {
  /** Where each line's statements start: "path:line" -> addresses. */
  starts: Map<string, number[]>;
  /** Every statement start, of every file. */
  startSet: Set<number>;
  /** The source line `pc` is in; null outside the table or on a line-0 row. */
  lineAt(pc: number): { file: string; line: number } | null;
  /** Every file named in the table. */
  files: Set<string>;
  /** Where each function of the ELF starts (its symbol table's FUNC symbols). */
  functionStarts: Set<number>;
  /** The function `pc` is in (a FUNC symbol and its size); null outside them. */
  functionAt(pc: number): { name: string; start: number } | null;
  /** Any symbol's address (a label too); undefined when the ELF has none of that name. */
  symbolAddress(name: string): number | undefined;
}

// ---- ELF32 little-endian sections ----

function sections(elf: Uint8Array): Map<string, Uint8Array> {
  const dv = new DataView(elf.buffer, elf.byteOffset, elf.byteLength);
  const out = new Map<string, Uint8Array>();
  if (dv.getUint32(0, false) !== 0x7f454c46 || elf[4] !== 1) return out; // ELF32 only
  const shoff = dv.getUint32(0x20, true);
  const shentsize = dv.getUint16(0x2e, true);
  const shnum = dv.getUint16(0x30, true);
  const shstrndx = dv.getUint16(0x32, true);
  const sh = (i: number) => {
    const o = shoff + i * shentsize;
    return { name: dv.getUint32(o, true), offset: dv.getUint32(o + 0x10, true), size: dv.getUint32(o + 0x14, true) };
  };
  const strtab = sh(shstrndx);
  const name = (off: number) => {
    let s = '';
    for (let i = strtab.offset + off; elf[i]; i++) s += String.fromCharCode(elf[i]);
    return s;
  };
  for (let i = 0; i < shnum; i++) {
    const s = sh(i);
    out.set(name(s.name), elf.subarray(s.offset, s.offset + s.size));
  }
  return out;
}

// ---- a byte reader ----

class Reader {
  pos = 0;
  private readonly b: Uint8Array;
  private readonly dv: DataView;
  constructor(b: Uint8Array) { this.b = b; this.dv = new DataView(b.buffer, b.byteOffset, b.byteLength); }
  u8() { return this.b[this.pos++]; }
  i8() { const v = this.dv.getInt8(this.pos); this.pos += 1; return v; }
  u16() { const v = this.dv.getUint16(this.pos, true); this.pos += 2; return v; }
  u32() { const v = this.dv.getUint32(this.pos, true); this.pos += 4; return v; }
  uleb() {
    let r = 0, shift = 0, byte: number;
    do { byte = this.b[this.pos++]; r += (byte & 0x7f) * 2 ** shift; shift += 7; } while (byte & 0x80);
    return r;
  }
  sleb() {
    let r = 0, shift = 0, byte: number;
    do { byte = this.b[this.pos++]; r += (byte & 0x7f) * 2 ** shift; shift += 7; } while (byte & 0x80);
    if (byte & 0x40) r -= 2 ** shift;
    return r;
  }
  cstr() {
    let s = '';
    while (this.b[this.pos]) s += String.fromCharCode(this.b[this.pos++]);
    this.pos++;
    return s;
  }
}

const cstrAt = (b: Uint8Array | undefined, off: number) => {
  if (!b) return '';
  let s = '';
  for (let i = off; i < b.length && b[i]; i++) s += String.fromCharCode(b[i]);
  return s;
};

const join = (dir: string, name: string) => (!dir || name.startsWith('/') ? name : `${dir.replace(/\/$/, '')}/${name}`);

/** The ELF's functions (STT_FUNC symbols, Thumb bit dropped), by address. */
export function functions(elf: Uint8Array): Array<{ name: string; start: number; end: number }> {
  const sec = sections(elf);
  const symtab = sec.get('.symtab');
  const strtab = sec.get('.strtab');
  const out: Array<{ name: string; start: number; end: number }> = [];
  if (!symtab) return out;
  const dv = new DataView(symtab.buffer, symtab.byteOffset, symtab.byteLength);
  for (let o = 0; o + 16 <= symtab.length; o += 16) {
    const value = dv.getUint32(o + 4, true);
    const size = dv.getUint32(o + 8, true);
    const info = symtab[o + 12];
    if ((info & 0xf) !== 2 || !value) continue; // STT_FUNC, not a dropped one
    const start = (value & ~1) >>> 0;
    out.push({ name: cstrAt(strtab, dv.getUint32(o, true)), start, end: size ? start + size : 0 });
  }
  out.sort((a, b) => a.start - b.start);
  // A symbol without a size (hand-written asm, the VPy asm backend's functions) runs to
  // the next function
  for (let i = 0; i < out.length; i++) {
    if (out[i].end) continue;
    const next = out.slice(i + 1).find((f) => f.start > out[i].start);
    out[i].end = next ? next.start : out[i].start + 0x1000;
  }
  return out;
}

/** Every named symbol's address (functions, labels, data), Thumb bit dropped. */
export function symbolAddresses(elf: Uint8Array): Map<string, number> {
  const sec = sections(elf);
  const symtab = sec.get('.symtab');
  const strtab = sec.get('.strtab');
  const out = new Map<string, number>();
  if (!symtab) return out;
  const dv = new DataView(symtab.buffer, symtab.byteOffset, symtab.byteLength);
  for (let o = 0; o + 16 <= symtab.length; o += 16) {
    const value = dv.getUint32(o + 4, true);
    if (!value) continue;
    const name = cstrAt(strtab, dv.getUint32(o, true));
    if (name && !out.has(name)) out.set(name, (value & ~1) >>> 0);
  }
  return out;
}

/** The addresses where the ELF's functions start. */
export function functionStarts(elf: Uint8Array): Set<number> {
  return new Set(functions(elf).map((f) => f.start));
}

/** Every row of every sequence; a sequence ends with an end row (line -1). */
export function parseLineRows(elf: Uint8Array): LineRow[] {
  const sec = sections(elf);
  const dl = sec.get('.debug_line');
  if (!dl) return [];
  const lineStr = sec.get('.debug_line_str');
  const str = sec.get('.debug_str');
  const rows: LineRow[] = [];
  const r = new Reader(dl);
  while (r.pos + 4 <= dl.length) {
    const unitStart = r.pos;
    const unitLength = r.u32();
    if (unitLength === 0xffffffff) break; // 64-bit DWARF: not in a 32-bit ELF
    const unitEnd = r.pos + unitLength;
    const version = r.u16();
    if (version >= 5) { r.u8(); r.u8(); } // address size, segment selector size
    const headerLength = r.u32();
    const programStart = r.pos + headerLength;
    const minInst = r.u8();
    if (version >= 4) r.u8(); // max ops per instruction (VLIW only)
    const defaultIsStmt = r.u8() !== 0;
    const lineBase = r.i8();
    const lineRange = r.u8();
    const opcodeBase = r.u8();
    const stdLengths: number[] = [];
    for (let i = 1; i < opcodeBase; i++) stdLengths.push(r.u8());

    const dirs: string[] = [];
    const files: string[] = [];
    if (version >= 5) {
      const entries = (out: string[], isFile: boolean) => {
        const formats: Array<[number, number]> = [];
        const nf = r.u8();
        for (let i = 0; i < nf; i++) formats.push([r.uleb(), r.uleb()]);
        const count = r.uleb();
        for (let i = 0; i < count; i++) {
          let path = '', dir = 0;
          for (const [type, form] of formats) {
            let v: string | number = 0;
            switch (form) {
              case 0x08: v = r.cstr(); break;                    // string
              case 0x1f: v = cstrAt(lineStr, r.u32()); break;    // line_strp
              case 0x0e: v = cstrAt(str, r.u32()); break;        // strp
              case 0x0f: v = r.uleb(); break;                    // udata
              case 0x0b: v = r.u8(); break;                      // data1
              case 0x05: v = r.u16(); break;                     // data2
              case 0x06: v = r.u32(); break;                     // data4
              case 0x07: r.pos += 8; break;                      // data8
              case 0x1e: r.pos += 16; break;                     // data16 (MD5)
              case 0x09: r.pos += r.uleb(); break;               // block
              default: r.pos = unitEnd; return;                  // unknown form: give up this unit
            }
            if (type === 1) path = String(v);      // DW_LNCT_path
            else if (type === 2) dir = Number(v);  // DW_LNCT_directory_index
          }
          out.push(isFile ? join(dirs[dir] ?? '', path) : path);
        }
      };
      entries(dirs, false);
      entries(files, true);
    } else {
      dirs.push(''); // index 0: the compilation directory (not in this table)
      for (let d = r.cstr(); d; d = r.cstr()) dirs.push(d);
      files.push(''); // file numbers start at 1
      for (let f = r.cstr(); f; f = r.cstr()) {
        const dir = r.uleb(); r.uleb(); r.uleb();
        files.push(join(dirs[dir] ?? '', f));
      }
    }

    // The line program
    r.pos = programStart;
    let address = 0, file = 1, line = 1, isStmt = defaultIsStmt;
    // A sequence at address 0 is a function the linker dropped (--gc-sections): skipped
    let seqFirst = true, seqDead = false;
    const reset = () => { address = 0; file = 1; line = 1; isStmt = defaultIsStmt; seqFirst = true; seqDead = false; };
    const emit = () => {
      if (seqFirst) { seqDead = address === 0; seqFirst = false; }
      if (!seqDead) rows.push({ address, file: files[file] ?? '', line, isStmt });
    };
    while (r.pos < unitEnd) {
      const op = r.u8();
      if (op >= opcodeBase) {
        const adj = op - opcodeBase;
        address += Math.floor(adj / lineRange) * minInst;
        line += lineBase + (adj % lineRange);
        emit();
      } else if (op === 0) {
        const len = r.uleb();
        const end = r.pos + len;
        const sub = r.u8();
        if (sub === 1) { if (!seqDead && !seqFirst) rows.push({ address, file: '', line: -1, isStmt: false }); reset(); }
        else if (sub === 2) address = r.u32();
        else if (sub === 3) { const f = r.cstr(); const d = r.uleb(); files.push(join(dirs[d] ?? '', f)); }
        r.pos = end;
      } else {
        switch (op) {
          case 1: emit(); break;                                            // copy
          case 2: address += r.uleb() * minInst; break;                     // advance_pc
          case 3: line += r.sleb(); break;                                  // advance_line
          case 4: file = r.uleb(); break;                                   // set_file
          case 5: r.uleb(); break;                                          // set_column
          case 6: isStmt = !isStmt; break;                                  // negate_stmt
          case 7: break;                                                    // set_basic_block
          case 8: address += Math.floor((255 - opcodeBase) / lineRange) * minInst; break; // const_add_pc
          case 9: address += r.u16(); break;                                // fixed_advance_pc
          case 10: case 11: break;                                          // prologue_end, epilogue_begin
          default: for (let i = 0; i < stdLengths[op - 1]; i++) r.uleb();   // set_isa and unknown ones
        }
      }
    }
    r.pos = unitEnd;
    if (r.pos <= unitStart) break;
  }
  return rows;
}

/** The lookups the debugger needs, over the rows of `elf`. */
export function lineTable(elf: Uint8Array): LineTable {
  const rows = parseLineRows(elf);
  const starts = new Map<string, number[]>();
  const startSet = new Set<number>();
  const files = new Set<string>();
  const ranges: Range[] = [];
  let prev: LineRow | null = null;
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    if (row.line < 0) { prev = null; continue; } // end of a sequence
    const next = rows[i + 1];
    if (next && next.address > row.address) ranges.push({ start: row.address, end: next.address, file: row.file, line: row.line });
    if (row.line > 0) files.add(row.file);
    // A statement starts where a row of a new line begins (rows of the same line
    // follow one another when the compiler interleaves columns or views)
    if (row.isStmt && row.line > 0 && (!prev || prev.line !== row.line || prev.file !== row.file)) {
      const key = `${row.file}:${row.line}`;
      const list = starts.get(key);
      if (list) { if (!list.includes(row.address)) list.push(row.address); } else starts.set(key, [row.address]);
      startSet.add(row.address);
    }
    prev = row;
  }
  ranges.sort((a, b) => a.start - b.start);
  const lineAt = (pc: number) => {
    pc = (pc & ~1) >>> 0;
    let lo = 0, hi = ranges.length - 1, hit = -1;
    while (lo <= hi) {
      const mid = (lo + hi) >> 1;
      if (ranges[mid].start <= pc) { hit = mid; lo = mid + 1; } else hi = mid - 1;
    }
    if (hit < 0) return null;
    const rg = ranges[hit];
    return pc < rg.end && rg.line > 0 ? { file: rg.file, line: rg.line } : null;
  };
  const fns = functions(elf);
  const functionAt = (pc: number) => {
    pc = (pc & ~1) >>> 0;
    let lo = 0, hi = fns.length - 1, hit = -1;
    while (lo <= hi) {
      const mid = (lo + hi) >> 1;
      if (fns[mid].start <= pc) { hit = mid; lo = mid + 1; } else hi = mid - 1;
    }
    // several symbols can share a start (aliases): any whose size covers pc
    for (let i = hit; i >= 0 && fns[i].start === fns[hit]?.start; i--) if (pc < fns[i].end) return { name: fns[i].name, start: fns[i].start };
    return null;
  };
  let syms: Map<string, number> | null = null; // read on first use
  const symbolAddress = (name: string) => (syms ??= symbolAddresses(elf)).get(name);
  return { starts, startSet, lineAt, files, functionStarts: new Set(fns.map((f) => f.start)), functionAt, symbolAddress };
}
