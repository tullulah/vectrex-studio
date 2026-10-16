/**
 * Call-frame information of an ARM program's ELF (DWARF .debug_frame): for any code
 * address, where the caller's frame is (the CFA) and where the registers it saved are.
 * That is what unwinds the stack (armCallStack.ts): optimised C keeps no frame
 * pointer and may keep lr in a register, so walking the stack for return addresses
 * would guess.
 *
 * The asm backend writes its own (vpy_codegen arm/debug_lines.rs: push, sub, mov r7);
 * gcc writes it for every C file built with -g (libvpy, the uvm2 SDK, the firmware).
 *
 * Pure: bytes in. tools/dwarf-frames-test.ts checks it against real builds.
 */

/** The rule at one address: CFA = reg + offset; each saved register at CFA + offset. */
export interface FrameRow {
  cfaReg: number;
  cfaOffset: number;
  saved: Map<number, number>;
}

interface Cie { codeAlign: number; dataAlign: number; raReg: number; initial: Uint8Array }
interface Fde { start: number; end: number; cie: Cie; program: Uint8Array }

export interface FrameTable {
  /** The rule in force at `pc`; null where no FDE covers it. */
  rowAt(pc: number): FrameRow | null;
  readonly fdes: number;
}

function debugFrame(elf: Uint8Array): Uint8Array | null {
  const dv = new DataView(elf.buffer, elf.byteOffset, elf.byteLength);
  if (dv.getUint32(0, false) !== 0x7f454c46 || elf[4] !== 1) return null;
  const shoff = dv.getUint32(0x20, true), shentsize = dv.getUint16(0x2e, true);
  const shnum = dv.getUint16(0x30, true), shstrndx = dv.getUint16(0x32, true);
  const sh = (i: number) => {
    const o = shoff + i * shentsize;
    return { name: dv.getUint32(o, true), offset: dv.getUint32(o + 0x10, true), size: dv.getUint32(o + 0x14, true) };
  };
  const strtab = sh(shstrndx);
  for (let i = 0; i < shnum; i++) {
    const s = sh(i);
    let name = '';
    for (let k = strtab.offset + s.name; elf[k]; k++) name += String.fromCharCode(elf[k]);
    if (name === '.debug_frame') return elf.subarray(s.offset, s.offset + s.size);
  }
  return null;
}

class Reader {
  pos: number;
  private readonly b: Uint8Array;
  private readonly dv: DataView;
  constructor(b: Uint8Array, pos = 0) { this.b = b; this.pos = pos; this.dv = new DataView(b.buffer, b.byteOffset, b.byteLength); }
  get done() { return this.pos >= this.b.length; }
  u8() { return this.b[this.pos++]; }
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
  cstr() { let s = ''; while (this.b[this.pos]) s += String.fromCharCode(this.b[this.pos++]); this.pos++; return s; }
}

/** Run CFA instructions from `row` up to `pc` (Infinity: all of them). */
function run(program: Uint8Array, cie: Cie, row: FrameRow, start: number, pc: number, initial: FrameRow | null): FrameRow {
  const r = new Reader(program);
  let loc = start;
  const stack: FrameRow[] = [];
  const copy = (x: FrameRow): FrameRow => ({ cfaReg: x.cfaReg, cfaOffset: x.cfaOffset, saved: new Map(x.saved) });
  while (!r.done) {
    const op = r.u8();
    const hi = op & 0xc0, low = op & 0x3f;
    const advance = (d: number) => { loc += d * cie.codeAlign; return loc > pc; };
    if (hi === 0x40) { if (advance(low)) break; continue; }
    if (hi === 0x80) { row.saved.set(low, r.uleb() * cie.dataAlign); continue; }
    if (hi === 0xc0) { const was = initial?.saved.get(low); if (was === undefined) row.saved.delete(low); else row.saved.set(low, was); continue; }
    switch (op) {
      case 0x00: break;                                                 // nop
      case 0x01: loc = r.u32(); if (loc > pc) return row; break;        // set_loc
      case 0x02: if (advance(r.u8())) return row; break;                // advance_loc1
      case 0x03: if (advance(r.u16())) return row; break;               // advance_loc2
      case 0x04: if (advance(r.u32())) return row; break;               // advance_loc4
      case 0x05: { const reg = r.uleb(); row.saved.set(reg, r.uleb() * cie.dataAlign); break; } // offset_extended
      case 0x06: case 0x07: case 0x08: row.saved.delete(r.uleb()); break; // restore_extended, undefined, same_value
      case 0x09: r.uleb(); r.uleb(); break;                             // register (not used by gcc on ARM)
      case 0x0a: stack.push(copy(row)); break;                          // remember_state
      case 0x0b: { const s = stack.pop(); if (s) { row.cfaReg = s.cfaReg; row.cfaOffset = s.cfaOffset; row.saved = s.saved; } break; } // restore_state
      case 0x0c: row.cfaReg = r.uleb(); row.cfaOffset = r.uleb(); break; // def_cfa
      case 0x0d: row.cfaReg = r.uleb(); break;                          // def_cfa_register
      case 0x0e: row.cfaOffset = r.uleb(); break;                       // def_cfa_offset
      case 0x11: { const reg = r.uleb(); row.saved.set(reg, r.sleb() * cie.dataAlign); break; } // offset_extended_sf
      case 0x12: row.cfaReg = r.uleb(); row.cfaOffset = r.sleb() * cie.dataAlign; break; // def_cfa_sf
      case 0x13: row.cfaOffset = r.sleb() * cie.dataAlign; break;       // def_cfa_offset_sf
      case 0x2e: r.uleb(); break;                                       // GNU_args_size
      default: return row;                                              // unknown: stop where we are
    }
  }
  return row;
}

export function frameTable(elf: Uint8Array): FrameTable {
  const sec = debugFrame(elf);
  const fdes: Fde[] = [];
  if (sec) {
    const cies = new Map<number, Cie>();
    const r = new Reader(sec);
    while (r.pos + 4 <= sec.length) {
      const at = r.pos;
      const length = r.u32();
      if (length === 0 || length === 0xffffffff) break;
      const end = r.pos + length;
      const id = r.u32();
      if (id === 0xffffffff) {
        const version = r.u8();
        const aug = r.cstr();
        if (version >= 4) { r.u8(); r.u8(); } // address size, segment size
        const codeAlign = r.uleb();
        const dataAlign = r.sleb();
        const raReg = version === 1 ? r.u8() : r.uleb();
        if (aug === '') cies.set(at, { codeAlign, dataAlign, raReg, initial: sec.subarray(r.pos, end) });
      } else {
        const cie = cies.get(id);
        const start = r.u32();
        const range = r.u32();
        // a dropped function's FDE sits at 0, like its line rows
        if (cie && start !== 0) fdes.push({ start, end: start + range, cie, program: sec.subarray(r.pos, end) });
      }
      r.pos = end;
    }
    fdes.sort((a, b) => a.start - b.start);
  }
  const rowAt = (pc: number): FrameRow | null => {
    pc = (pc & ~1) >>> 0;
    let lo = 0, hi = fdes.length - 1, hit = -1;
    while (lo <= hi) {
      const mid = (lo + hi) >> 1;
      if (fdes[mid].start <= pc) { hit = mid; lo = mid + 1; } else hi = mid - 1;
    }
    if (hit < 0 || pc >= fdes[hit].end) return null;
    const f = fdes[hit];
    const initial = run(f.cie.initial, f.cie, { cfaReg: 13, cfaOffset: 0, saved: new Map() }, f.start, Infinity, null);
    const snapshot: FrameRow = { cfaReg: initial.cfaReg, cfaOffset: initial.cfaOffset, saved: new Map(initial.saved) };
    return run(f.program, f.cie, initial, f.start, pc, snapshot);
  };
  return { rowAt, fdes: fdes.length };
}
