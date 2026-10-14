/**
 * The variables of an ARM program's ELF (DWARF .debug_info, versions 2 to 5): each
 * global's address and type, and, at a code address, the variables in scope — of the
 * function there and of the functions gcc inlined into it — with where each one is at
 * that address (a register, the stack, memory, a known constant, or nowhere: an
 * optimised-out value).
 *
 * gcc writes it for every C file built with -g: the C backend's program (globals
 * `G_*`, locals and parameters `l_*`), libvpy and the SDK. The VPy asm backend writes
 * none.
 *
 * Pure: the ELF's sections in (dwarfLines.ts `sections`). tools/dwarf-info-test.ts checks
 * it against real builds.
 */

export type CType =
  | { kind: 'int'; size: number; signed: boolean; name: string }
  | { kind: 'float'; size: number; name: string }
  | { kind: 'pointer'; size: number }
  | { kind: 'array'; elem: CType; count: number }
  | { kind: 'struct'; size: number; members: Array<{ name: string; offset: number; type: CType }> }
  | { kind: 'unknown'; size: number };

/** Where a variable is at one address. */
export type VarPlace =
  | { kind: 'memory'; addr: number }
  | { kind: 'register'; reg: number }
  | { kind: 'value'; value: number }
  | { kind: 'unavailable' };

/** What a location expression needs from the paused program. */
export interface Machine {
  regs: number[];
  /** The canonical frame address at pc (dwarfFrames.ts), when known. */
  cfa: number | null;
  read32(addr: number): number | null;
}

export interface ScopeVar {
  name: string;
  type: CType;
  /** Where it is at `pc` in this machine. */
  place(pc: number, m: Machine): VarPlace;
}

/** One function active at pc: the one there, or one inlined into it. */
export interface FunctionScope {
  function: string;
  vars: ScopeVar[];
}

export interface DebugInfo {
  global(name: string): { addr: number; type: CType } | null;
  /** The functions active at `pc`, innermost (the last inlined one) first. */
  scopesAt(pc: number): FunctionScope[];
  readonly units: number;
}

// ---- reading ----

class Reader {
  pos: number;
  readonly b: Uint8Array;
  private readonly dv: DataView;
  constructor(b: Uint8Array, pos = 0) { this.b = b; this.pos = pos; this.dv = new DataView(b.buffer, b.byteOffset, b.byteLength); }
  u8() { return this.b[this.pos++]; }
  i8() { const v = this.dv.getInt8(this.pos); this.pos += 1; return v; }
  u16() { const v = this.dv.getUint16(this.pos, true); this.pos += 2; return v; }
  i16() { const v = this.dv.getInt16(this.pos, true); this.pos += 2; return v; }
  u24() { const v = this.b[this.pos] | (this.b[this.pos + 1] << 8) | (this.b[this.pos + 2] << 16); this.pos += 3; return v; }
  u32() { const v = this.dv.getUint32(this.pos, true); this.pos += 4; return v; }
  i32() { const v = this.dv.getInt32(this.pos, true); this.pos += 4; return v; }
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
  bytes(n: number) { const v = this.b.subarray(this.pos, this.pos + n); this.pos += n; return v; }
  cstr() { let s = ''; while (this.b[this.pos]) s += String.fromCharCode(this.b[this.pos++]); this.pos++; return s; }
}

const cstrAt = (b: Uint8Array | undefined, off: number) => {
  if (!b) return '';
  let s = '';
  for (let i = off; i < b.length && b[i]; i++) s += String.fromCharCode(b[i]);
  return s;
};

// tags
const T_ARRAY = 0x01, T_ENUM = 0x04, T_PARAM = 0x05, T_LEXICAL = 0x0b, T_MEMBER = 0x0d, T_POINTER = 0x0f,
  T_CU = 0x11, T_STRUCT = 0x13, T_TYPEDEF = 0x16, T_UNION = 0x17, T_INLINED = 0x1d, T_SUBRANGE = 0x21,
  T_BASE = 0x24, T_CONST = 0x26, T_SUBPROGRAM = 0x2e, T_VARIABLE = 0x34, T_VOLATILE = 0x35, T_ATOMIC = 0x47;
// attributes
const A_LOCATION = 0x02, A_NAME = 0x03, A_BYTE_SIZE = 0x0b, A_LOW_PC = 0x11, A_HIGH_PC = 0x12,
  A_CONST_VALUE = 0x1c, A_UPPER_BOUND = 0x2f, A_ABSTRACT_ORIGIN = 0x31, A_COUNT = 0x37, A_MEMBER_LOCATION = 0x38,
  A_DECLARATION = 0x3c, A_ENCODING = 0x3e, A_FRAME_BASE = 0x40, A_SPECIFICATION = 0x47, A_TYPE = 0x49, A_RANGES = 0x55;

type Value = number | Uint8Array | string | { form: 'sec_offset'; offset: number };

interface Die {
  offset: number;
  tag: number;
  attrs: Map<number, Value>;
  children: Die[];
  parent: Die | null;
  cu: Unit;
}

interface Unit { version: number; base: number; addrSize: number }

interface Abbrev { tag: number; children: boolean; specs: Array<[number, number, number]> } // attr, form, implicit const

function abbrevTable(sec: Uint8Array, offset: number): Map<number, Abbrev> {
  const r = new Reader(sec, offset);
  const out = new Map<number, Abbrev>();
  for (;;) {
    const code = r.uleb();
    if (!code) break;
    const tag = r.uleb();
    const children = r.u8() === 1;
    const specs: Array<[number, number, number]> = [];
    for (;;) {
      const attr = r.uleb(), form = r.uleb();
      const implicit = form === 0x21 ? r.sleb() : 0;
      if (!attr && !form) break;
      specs.push([attr, form, implicit]);
    }
    out.set(code, { tag, children, specs });
  }
  return out;
}

interface Sections { str?: Uint8Array; lineStr?: Uint8Array }

/** One attribute value; references come back as .debug_info offsets. */
function readForm(r: Reader, form: number, implicit: number, unit: { start: number; version: number; addrSize: number; offSize: number }, s: Sections): Value {
  switch (form) {
    case 0x01: return unit.addrSize === 8 ? (r.u32(), r.u32()) : r.u32();               // addr
    case 0x03: return r.bytes(r.u16());                                                    // block2
    case 0x04: return r.bytes(r.u32());                                                    // block4
    case 0x05: return r.u16();                                                             // data2
    case 0x06: return r.u32();                                                             // data4
    case 0x07: { const lo = r.u32(); r.u32(); return lo; }                                 // data8
    case 0x08: return r.cstr();                                                            // string
    case 0x09: return r.bytes(r.uleb());                                                   // block
    case 0x0a: return r.bytes(r.u8());                                                     // block1
    case 0x0b: return r.u8();                                                              // data1
    case 0x0c: return r.u8();                                                              // flag
    case 0x0d: return r.sleb();                                                            // sdata
    case 0x0e: return cstrAt(s.str, r.u32());                                              // strp
    case 0x0f: return r.uleb();                                                            // udata
    case 0x10: return unit.version <= 2 ? r.u32() : r.u32();                               // ref_addr
    case 0x11: return unit.start + r.u8();                                                 // ref1
    case 0x12: return unit.start + r.u16();                                                // ref2
    case 0x13: return unit.start + r.u32();                                                // ref4
    case 0x14: { const lo = r.u32(); r.u32(); return unit.start + lo; }                    // ref8
    case 0x15: return unit.start + r.uleb();                                               // ref_udata
    case 0x16: return readForm(r, r.uleb(), implicit, unit, s);                            // indirect
    case 0x17: return { form: 'sec_offset', offset: r.u32() };                             // sec_offset
    case 0x18: return r.bytes(r.uleb());                                                   // exprloc
    case 0x19: return 1;                                                                   // flag_present
    case 0x1a: case 0x1b: case 0x22: case 0x23: return { form: 'sec_offset', offset: -1 - r.uleb() }; // strx, addrx, loclistx, rnglistx: unsupported
    case 0x1c: return r.u32();                                                             // ref_sup4
    case 0x1d: return r.u32();                                                             // strp_sup
    case 0x1e: return r.bytes(16);                                                         // data16
    case 0x1f: return cstrAt(s.lineStr, r.u32());                                          // line_strp
    case 0x20: { r.u32(); r.u32(); return 0; }                                             // ref_sig8
    case 0x21: return implicit;                                                            // implicit_const
    case 0x24: { r.u32(); r.u32(); return 0; }                                             // ref_sup8
    case 0x25: case 0x29: r.u8(); return -1;                                               // strx1, addrx1
    case 0x26: case 0x2a: r.u16(); return -1;                                              // strx2, addrx2
    case 0x27: case 0x2b: r.u24(); return -1;                                              // strx3, addrx3
    case 0x28: case 0x2c: r.u32(); return -1;                                              // strx4, addrx4
    default: throw new Error(`DWARF form 0x${form.toString(16)} not supported`);
  }
}

const num = (v: Value | undefined): number | undefined => (typeof v === 'number' ? v : undefined);

// ---- location expressions ----

/** Evaluate a location expression (the common subset gcc writes for ARM). */
function evaluate(ops: Uint8Array, m: Machine, frameBase: () => number | null): VarPlace {
  const r = new Reader(ops);
  const stack: number[] = [];
  let reg: number | null = null;
  const pop = () => stack.pop() ?? 0;
  while (r.pos < ops.length) {
    const op = r.u8();
    if (op >= 0x30 && op <= 0x4f) { stack.push(op - 0x30); continue; }                 // lit0..31
    if (op >= 0x50 && op <= 0x6f) { reg = op - 0x50; continue; }                       // reg0..31
    if (op >= 0x70 && op <= 0x8f) { const n = op - 0x70; const off = r.sleb(); if (m.regs[n] === undefined) return { kind: 'unavailable' }; stack.push(((m.regs[n] >>> 0) + off) >>> 0); continue; } // breg
    switch (op) {
      case 0x03: stack.push(r.u32()); break;                                           // addr
      case 0x06: { const v = m.read32(pop()); if (v === null) return { kind: 'unavailable' }; stack.push(v); break; } // deref
      case 0x08: stack.push(r.u8()); break;
      case 0x09: stack.push(r.i8()); break;
      case 0x0a: stack.push(r.u16()); break;
      case 0x0b: stack.push(r.i16()); break;
      case 0x0c: stack.push(r.u32()); break;
      case 0x0d: stack.push(r.i32()); break;
      case 0x10: stack.push(r.uleb()); break;
      case 0x11: stack.push(r.sleb()); break;
      case 0x12: stack.push(stack[stack.length - 1] ?? 0); break;                       // dup
      case 0x1c: { const b = pop(), a = pop(); stack.push(a - b); break; }              // minus
      case 0x22: { const b = pop(), a = pop(); stack.push(a + b); break; }              // plus
      case 0x23: stack.push(pop() + r.uleb()); break;                                  // plus_uconst
      case 0x1f: stack.push(-pop()); break;                                            // neg
      case 0x90: reg = r.uleb(); break;                                                // regx
      case 0x91: { const fb = frameBase(); if (fb === null) return { kind: 'unavailable' }; stack.push((fb + r.sleb()) >>> 0); break; } // fbreg
      case 0x92: { const n = r.uleb(); const off = r.sleb(); if (m.regs[n] === undefined) return { kind: 'unavailable' }; stack.push(((m.regs[n] >>> 0) + off) >>> 0); break; } // bregx
      case 0x93: r.uleb(); return reg !== null ? { kind: 'register', reg } : stack.length ? { kind: 'memory', addr: pop() >>> 0 } : { kind: 'unavailable' }; // piece: the first one
      case 0x96: break;                                                                // nop
      case 0x9c: if (m.cfa === null) return { kind: 'unavailable' }; stack.push(m.cfa); break; // call_frame_cfa
      case 0x9e: { const n = r.uleb(); const b = r.bytes(n); let v = 0; for (let i = Math.min(n, 4) - 1; i >= 0; i--) v = v * 256 + b[i]; return { kind: 'value', value: v }; } // implicit_value
      case 0x9f: return { kind: 'value', value: pop() };                               // stack_value
      default: return { kind: 'unavailable' };                                         // entry_value and the rest
    }
  }
  if (reg !== null) return { kind: 'register', reg };
  return stack.length ? { kind: 'memory', addr: pop() >>> 0 } : { kind: 'unavailable' };
}

// ---- the tree ----

export function debugInfo(sec: Map<string, Uint8Array>): DebugInfo {
  const info = sec.get('.debug_info');
  const abbrev = sec.get('.debug_abbrev');
  const s: Sections = { str: sec.get('.debug_str'), lineStr: sec.get('.debug_line_str') };
  const loclists = sec.get('.debug_loclists'), loc = sec.get('.debug_loc');
  const rnglists = sec.get('.debug_rnglists'), ranges = sec.get('.debug_ranges');

  const byOffset = new Map<number, Die>();
  const globals = new Map<string, Die>();
  const functions: Array<{ start: number; end: number; die: Die }> = [];
  let units = 0;

  if (info && abbrev) {
    const r = new Reader(info);
    while (r.pos + 11 <= info.length) {
      const start = r.pos;
      let length = r.u32();
      if (length === 0xffffffff) break; // 64-bit DWARF: not on ARM
      const end = r.pos + length;
      const version = r.u16();
      let abbrevOff: number, addrSize: number;
      if (version >= 5) {
        const unitType = r.u8();
        addrSize = r.u8();
        abbrevOff = r.u32();
        if (unitType !== 0x01) { r.pos = end; continue; } // only full compile units
      } else {
        abbrevOff = r.u32();
        addrSize = r.u8();
      }
      units++;
      const table = abbrevTable(abbrev, abbrevOff);
      const unitCtx = { start, version, addrSize, offSize: 4 };
      const unit: Unit = { version, base: 0, addrSize };
      const parents: Die[] = [];
      try {
        while (r.pos < end) {
          const offset = r.pos;
          const code = r.uleb();
          if (!code) { parents.pop(); continue; }
          const ab = table.get(code);
          if (!ab) break;
          const attrs = new Map<number, Value>();
          for (const [attr, form, implicit] of ab.specs) attrs.set(attr, readForm(r, form, implicit, unitCtx, s));
          const parent = parents[parents.length - 1] ?? null;
          const die: Die = { offset, tag: ab.tag, attrs, children: [], parent, cu: unit };
          byOffset.set(offset, die);
          if (parent) parent.children.push(die);
          if (ab.tag === T_CU) unit.base = num(attrs.get(A_LOW_PC)) ?? 0;
          if (ab.tag === T_VARIABLE && parent?.tag === T_CU && attrs.has(A_LOCATION)) {
            // a global with its storage (the declaration's name may be on its specification)
            globals.set(offset.toString(), die);
          }
          if (ab.children) parents.push(die);
        }
      } catch (e) {
        console.warn('[dwarfInfo] stopped reading a unit:', e);
      }
      r.pos = end;
    }
  }

  const origin = (d: Die): Die | null => {
    const o = num(d.attrs.get(A_ABSTRACT_ORIGIN)) ?? num(d.attrs.get(A_SPECIFICATION));
    return o !== undefined ? byOffset.get(o) ?? null : null;
  };
  const attr = (d: Die, a: number): Value | undefined => {
    for (let x: Die | null = d, i = 0; x && i < 8; x = origin(x), i++) if (x.attrs.has(a)) return x.attrs.get(a);
    return undefined;
  };
  const name = (d: Die) => { const n = attr(d, A_NAME); return typeof n === 'string' ? n : ''; };

  // globals by name
  const globalByName = new Map<string, Die>();
  for (const d of globals.values()) { const n = name(d); if (n && !globalByName.has(n)) globalByName.set(n, d); }

  // ranges
  const dieRanges = (d: Die): Array<[number, number]> => {
    const low = num(d.attrs.get(A_LOW_PC));
    const high = d.attrs.get(A_HIGH_PC);
    if (low !== undefined && typeof high === 'number') {
      // DW_FORM_addr gives the end; a constant, the length (v4+)
      const isAddr = d.cu.version < 4 || high > low;
      return [[low, isAddr && high > low ? high : low + high]];
    }
    const rg = d.attrs.get(A_RANGES);
    if (rg === undefined) return [];
    const off = typeof rg === 'number' ? rg : typeof rg === 'object' && 'offset' in rg ? rg.offset : -1;
    if (off < 0) return [];
    const out: Array<[number, number]> = [];
    let base = d.cu.base;
    if (d.cu.version >= 5 && rnglists) {
      const r = new Reader(rnglists, off);
      for (;;) {
        const kind = r.u8();
        if (kind === 0) break;
        if (kind === 4) { const a = r.uleb(), b = r.uleb(); out.push([base + a, base + b]); }
        else if (kind === 5) base = r.u32();
        else if (kind === 6) { const a = r.u32(), b = r.u32(); out.push([a, b]); }
        else if (kind === 7) { const a = r.u32(); out.push([a, a + r.uleb()]); }
        else break; // the indexed forms need .debug_addr
      }
    } else if (ranges) {
      const r = new Reader(ranges, off);
      while (r.pos + 8 <= ranges.length) {
        const a = r.u32(), b = r.u32();
        if (!a && !b) break;
        if (a === 0xffffffff) { base = b; continue; }
        out.push([base + a, base + b]);
      }
    }
    return out;
  };
  const contains = (d: Die, pc: number) => dieRanges(d).some(([a, b]) => pc >= a && pc < b);

  for (const d of byOffset.values()) {
    if (d.tag !== T_SUBPROGRAM) continue;
    for (const [a, b] of dieRanges(d)) if (a && b > a) functions.push({ start: a, end: b, die: d });
  }
  functions.sort((a, b) => a.start - b.start);

  // types
  const typeCache = new Map<number, CType>();
  const typeOf = (ref: number | undefined, depth = 0): CType => {
    if (ref === undefined || depth > 24) return { kind: 'unknown', size: 4 };
    const cached = typeCache.get(ref);
    if (cached) return cached;
    const d = byOffset.get(ref);
    if (!d) return { kind: 'unknown', size: 4 };
    const size = num(d.attrs.get(A_BYTE_SIZE)) ?? 0;
    let t: CType;
    switch (d.tag) {
      case T_BASE: {
        const enc = num(d.attrs.get(A_ENCODING)) ?? 0;
        t = enc === 0x04 ? { kind: 'float', size, name: name(d) }
          : { kind: 'int', size, signed: enc === 0x05 || enc === 0x06 || enc === 0x0d, name: name(d) };
        break;
      }
      case T_ENUM: t = { kind: 'int', size: size || 4, signed: true, name: name(d) || 'enum' }; break;
      case T_POINTER: t = { kind: 'pointer', size: size || 4 }; break;
      case T_TYPEDEF: case T_CONST: case T_VOLATILE: case T_ATOMIC:
        t = typeOf(num(d.attrs.get(A_TYPE)), depth + 1); break;
      case T_ARRAY: {
        const elem = typeOf(num(d.attrs.get(A_TYPE)), depth + 1);
        const dims = d.children.filter((c) => c.tag === T_SUBRANGE).map((c) => {
          const count = num(c.attrs.get(A_COUNT));
          const upper = num(c.attrs.get(A_UPPER_BOUND));
          return count ?? (upper !== undefined ? upper + 1 : 0);
        });
        t = elem;
        for (let i = dims.length - 1; i >= 0; i--) t = { kind: 'array', elem: t, count: dims[i] };
        if (!dims.length) t = { kind: 'array', elem, count: 0 };
        break;
      }
      case T_STRUCT: case T_UNION: {
        t = { kind: 'struct', size, members: [] };
        typeCache.set(ref, t); // a struct that points at itself
        for (const c of d.children) {
          if (c.tag !== T_MEMBER) continue;
          const ml = c.attrs.get(A_MEMBER_LOCATION);
          const offset = typeof ml === 'number' ? ml : ml instanceof Uint8Array && ml[0] === 0x23 ? new Reader(ml, 1).uleb() : 0;
          t.members.push({ name: name(c), offset, type: typeOf(num(c.attrs.get(A_TYPE)), depth + 1) });
        }
        return t;
      }
      default: t = { kind: 'unknown', size: size || 4 };
    }
    typeCache.set(ref, t);
    return t;
  };

  const placeOf = (v: Die, frameBaseDie: Die | null) => (pc: number, m: Machine): VarPlace => {
    const cv = attr(v, A_CONST_VALUE);
    if (typeof cv === 'number') return { kind: 'value', value: cv };
    const where = v.attrs.get(A_LOCATION);
    const frameBase = () => {
      const fb = frameBaseDie?.attrs.get(A_FRAME_BASE);
      if (!(fb instanceof Uint8Array)) return m.cfa;
      const p = evaluate(fb, m, () => null);
      return p.kind === 'memory' ? p.addr : p.kind === 'register' ? (m.regs[p.reg] >>> 0) : null;
    };
    if (where instanceof Uint8Array) return evaluate(where, m, frameBase);
    const off = typeof where === 'object' && where && 'offset' in where ? where.offset : typeof where === 'number' ? where : -1;
    if (off < 0) return { kind: 'unavailable' };
    // a location list: the entry whose range holds pc
    let base = v.cu.base;
    if (v.cu.version >= 5 && loclists) {
      const r = new Reader(loclists, off);
      for (;;) {
        const kind = r.u8();
        let range: [number, number] | null = null;
        if (kind === 0) break;
        else if (kind === 4) { const a = r.uleb(), b = r.uleb(); range = [base + a, base + b]; }
        else if (kind === 5) { const ops = r.bytes(r.uleb()); return evaluate(ops, m, frameBase); } // default
        else if (kind === 6) { base = r.u32(); continue; }
        else if (kind === 7) { const a = r.u32(), b = r.u32(); range = [a, b]; }
        else if (kind === 8) { const a = r.u32(); range = [a, a + r.uleb()]; }
        else break; // indexed forms
        const ops = r.bytes(r.uleb());
        if (pc >= range[0] && pc < range[1]) return evaluate(ops, m, frameBase);
      }
    } else if (loc) {
      const r = new Reader(loc, off);
      while (r.pos + 8 <= loc.length) {
        const a = r.u32(), b = r.u32();
        if (!a && !b) break;
        if (a === 0xffffffff) { base = b; continue; }
        const ops = r.bytes(r.u16());
        if (pc >= base + a && pc < base + b) return evaluate(ops, m, frameBase);
      }
    }
    return { kind: 'unavailable' };
  };

  const scopesAt = (pc: number): FunctionScope[] => {
    pc = (pc & ~1) >>> 0;
    // the innermost concrete function holding pc
    let fn: Die | null = null;
    for (const f of functions) {
      if (f.start > pc) break;
      if (pc < f.end) fn = f.die;
    }
    if (!fn) return [];
    const out: FunctionScope[] = [];
    const visit = (d: Die, scope: FunctionScope, frameBaseDie: Die) => {
      for (const c of d.children) {
        if (c.tag === T_VARIABLE || c.tag === T_PARAM) {
          const n = name(c);
          if (n) scope.vars.push({ name: n, type: typeOf(num(attr(c, A_TYPE))), place: placeOf(c, frameBaseDie) });
        } else if (c.tag === T_LEXICAL && (contains(c, pc) || !dieRanges(c).length)) {
          visit(c, scope, frameBaseDie);
        } else if (c.tag === T_INLINED && contains(c, pc)) {
          const inner: FunctionScope = { function: name(c), vars: [] };
          out.push(inner);
          visit(c, inner, frameBaseDie);
        }
      }
    };
    const top: FunctionScope = { function: name(fn), vars: [] };
    out.push(top);
    visit(fn, top, fn);
    return out.reverse();
  };

  return {
    global(n: string) {
      const d = globalByName.get(n);
      if (!d) return null;
      const where = d.attrs.get(A_LOCATION);
      if (!(where instanceof Uint8Array) || where[0] !== 0x03 || where.length < 5) return null;
      const addr = (where[1] | (where[2] << 8) | (where[3] << 16) | (where[4] << 24)) >>> 0;
      if (!addr) return null;
      return { addr, type: typeOf(num(attr(d, A_TYPE))) };
    },
    scopesAt,
    units,
  };
}
