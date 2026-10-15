/**
 * The value of the variable under the mouse while the program is paused, for the
 * editor's hover: what the Memory panel shows, without looking for it there.
 *
 * The name resolves as the compiler resolves it (vpy_codegen m6809/frames.rs): in a
 * function, a parameter first, then a module-level name, then a local. Then:
 *   m6809 — the .pdb's variables: `speed`, `util_level` (another module's global),
 *           `loop.count` / `util_bump.k` (locals and parameters), `table_data` (arrays,
 *           `ARRAY_<NAME>_LEN` elements), `ships__hp_data` (a struct array's field);
 *   ARM   — the ELF: the C backend's `G_<NAME>` / `G_<MODULE>_<NAME>` globals (struct
 *           arrays `G_<NAME>[i].f_<field>`) and `l_<name>` locals, typed by its debug
 *           info, where they are at the paused pc; the asm backend's `VAR_<NAME>`.
 * In a C project's own files (cDebugValue) the names are the C ones: a local of the
 * function the hovered line is in, else a global; `s.field` and `arr[i].field` too.
 */
import { useDebugStore } from '../state/debugStore';
import { useProjectStore } from '../state/projectStore';
import { armCVariable, armGlobal, armLocal, armProgramActive, armWriteMemory, type ArmVariable } from './armSourceDebug';
import type { CType } from './dwarfInfo';

const MAX_ELEMENTS = 16;

const stem = (p: string) => (p.split(/[\\/]/).pop() || p).replace(/\.vpy$/i, '');

/** What is under the mouse, as VPy code names it. */
export interface HoverTarget {
  word: string;
  /** `module.word` or `value.word`: the name before the dot. */
  qualifier: string | null;
  /** `base[i].word`: a field of a struct array's element. */
  fieldOf: string | null;
  /** The function the line is in (its name and parameters); null at module level. */
  fn: { name: string; params: string[] } | null;
  /** The file's module name (its file name without .vpy). */
  module: string;
}

const DEF = /^\s*def\s+([A-Za-z_]\w*)\s*\(([^)]*)\)/;
const indentOf = (s: string) => s.length - s.trimStart().length;

/** The function around 1-based `line` (its `def` line and indented block). */
export function enclosingFunction(lines: string[], line: number): HoverTarget['fn'] {
  const parse = (m: RegExpExecArray) => ({ name: m[1], params: m[2].split(',').map((p) => p.trim().split(/[\s:=]/)[0]).filter(Boolean) });
  const cur = lines[line - 1] ?? '';
  const own = DEF.exec(cur);
  if (own) return parse(own);
  let below = cur.trim() ? indentOf(cur) : Infinity;
  if (below === 0) return null;
  for (let i = line - 2; i >= 0; i--) {
    const l = lines[i];
    const t = l.trim();
    if (!t || t.startsWith('#')) continue;
    const d = indentOf(l);
    if (d >= below) continue;
    const m = DEF.exec(l);
    if (m) return parse(m);
    if (d === 0) return null;
    below = d;
  }
  return null;
}

/** The hover target at `word` (starting at 1-based `startColumn` of `line`). */
export function hoverTarget(text: string, fileName: string, line: number, word: string, startColumn: number): HoverTarget | null {
  const lines = text.split(/\r?\n/);
  const l = lines[line - 1] ?? '';
  const before = l.slice(0, startColumn - 1);
  const after = l.slice(startColumn - 1 + word.length);
  if (/^\s*\(/.test(after) || /\bdef\s+$/.test(before) || /^[0-9]/.test(word)) return null; // a call, a def, a number
  if (/#/.test(before.replace(/"[^"]*"|'[^']*'/g, ''))) return null; // a comment
  const field = /([A-Za-z_]\w*)\s*\[[^\]]*\]\s*\.\s*$/.exec(before);
  const qual = field ? null : /([A-Za-z_]\w*)\s*\.\s*$/.exec(before);
  return {
    word,
    qualifier: qual ? qual[1] : null,
    fieldOf: field ? field[1] : null,
    fn: enclosingFunction(lines, line),
    module: stem(fileName),
  };
}

function entryModule(): string {
  const entry = useProjectStore.getState().vpyProject?.config?.project?.entry;
  return entry ? stem(entry) : 'main';
}

// ---- formatting ----

const hex = (v: number, bytes: number) => '0x' + (v >>> 0).toString(16).toUpperCase().padStart(bytes * 2, '0');

function intText(raw: number, size: number, signed: boolean): string {
  const bits = size * 8;
  const u = bits >= 32 ? raw >>> 0 : raw & ((1 << bits) - 1);
  const v = signed && bits < 32 && u >= 2 ** (bits - 1) ? u - 2 ** bits : signed && bits >= 32 ? u | 0 : u;
  return Math.abs(v) < 10 ? String(v) : `${v} (${hex(u, Math.min(size, 4))})`;
}

/** Bytes little-endian (ARM) or big-endian (6809) as one integer. */
function readInt(read8: (a: number) => number | null, addr: number, size: number, bigEndian: boolean): number | null {
  let v = 0;
  for (let i = 0; i < Math.min(size, 4); i++) {
    const b = read8(addr + (bigEndian ? i : Math.min(size, 4) - 1 - i));
    if (b === null) return null;
    v = v * 256 + b;
  }
  return v;
}

function cValue(t: CType, read8: (a: number) => number | null, addr: number, depth = 0): string {
  switch (t.kind) {
    case 'int': { const v = readInt(read8, addr, t.size, false); return v === null ? '?' : intText(v, t.size, t.signed); }
    case 'pointer': { const v = readInt(read8, addr, 4, false); return v === null ? '?' : hex(v, 4); }
    case 'float': return '(float)';
    case 'array': {
      const step = sizeOf(t.elem);
      const n = Math.min(t.count, MAX_ELEMENTS);
      const items = Array.from({ length: n }, (_, i) => cValue(t.elem, read8, addr + i * step, depth + 1));
      return `[${items.join(', ')}${t.count > n ? `, … (${t.count})` : ''}]`;
    }
    case 'struct':
      if (depth > 1) return '{…}';
      return `{ ${t.members.map((m) => `${m.name.replace(/^f_/, '')}: ${cValue(m.type, read8, addr + m.offset, depth + 1)}`).join(', ')} }`;
    default: return '?';
  }
}

function sizeOf(t: CType): number {
  switch (t.kind) {
    case 'array': return sizeOf(t.elem) * t.count;
    case 'struct': return t.size;
    default: return t.size;
  }
}

function armValue(v: ArmVariable): string {
  const p = v.place;
  if (p.kind === 'unavailable') return 'optimised out here';
  if (p.kind === 'memory') return cValue(v.type, v.read8, p.addr);
  const raw = p.kind === 'value' ? p.value : v.reg(p.reg);
  if (v.type.kind === 'int') return intText(raw, v.type.size, v.type.signed);
  return intText(raw, 4, true);
}

// ---- m6809 ----

function m6809Value(t: HoverTarget): string | null {
  const pdb: any = useDebugStore.getState().pdbData;
  const vecx = (window as any).vecx;
  if (!pdb?.variables || !vecx?.read8) return null;
  const vars = new Map<string, any>();
  for (const [k, v] of Object.entries(pdb.variables)) vars.set(k.toLowerCase(), v);
  const labels: Record<string, number> = pdb.labels || {};
  const entry = stem(pdb.source || entryModule()).toLowerCase();
  const mod = t.module.toLowerCase();
  const global = (name: string, inModule = mod) => (inModule === entry ? name : `${inModule}_${name}`).toLowerCase();
  const fnLabel = t.fn ? global(t.fn.name) : null;
  const w = t.word.toLowerCase();

  let key: string | null = null;
  const has = (k: string) => (vars.has(k) ? k : null);
  if (t.fieldOf) key = has(`${global(t.fieldOf)}__${w}_data`);
  else if (t.qualifier) {
    const q = t.qualifier.toLowerCase();
    key = has(`${q}_${w}`) ?? has(`${q}_${w}_data`) ?? has(`${global(q)}__${w}`); // a module's global, or a struct's field
  }
  else {
    if (fnLabel && t.fn!.params.some((p) => p.toLowerCase() === w)) key = has(`${fnLabel}.${w}`);
    key ??= has(global(w)) ?? has(`${global(w)}_data`) ?? (fnLabel ? has(`${fnLabel}.${w}`) : null);
  }
  if (!key) return null;
  // Frames are overlaid by call graph: a function that is not running may share its
  // slots with one that is
  if (key.includes('.') && t.fn) {
    const name = (mod === entry ? t.fn.name : `${t.module}.${t.fn.name}`).toLowerCase();
    const stack = useDebugStore.getState().callStack || [];
    if (stack.length && !stack.some((f) => f.function.toLowerCase() === name)) return 'not running (its frame may hold another function\'s values)';
  }
  const v = vars.get(key);
  const addr = parseInt(String(v.address), 16);
  const read8 = (a: number) => vecx.read8(a & 0xffff) & 0xff;
  if (v.type === 'array') {
    const len = labels[`ARRAY_${key.replace(/_data$/, '').toUpperCase()}_LEN`] || 0;
    const stride = len ? Math.max(1, Math.round(v.size / len)) : 2;
    const n = Math.min(len || Math.floor(v.size / stride), MAX_ELEMENTS);
    const items = Array.from({ length: n }, (_, i) => intText(readInt(read8, addr + i * stride, stride, true) ?? 0, stride, stride === 2));
    return `[${items.join(', ')}${len > n ? `, … (${len})` : ''}]`;
  }
  return intText(readInt(read8, addr, v.size, true) ?? 0, v.size, v.size === 2);
}

// ---- ARM ----

function armHoverValue(t: HoverTarget): string | null {
  const entry = entryModule().toUpperCase();
  const mod = t.module.toUpperCase();
  const w = t.word.toUpperCase();
  const g = (name: string, inModule = mod) => (inModule === entry ? name : `${inModule}_${name}`);
  const global = (name: string): ArmVariable | null => armGlobal(`G_${name}`) ?? armGlobal(`VAR_${name}`);

  if (t.fieldOf) {
    const base = armGlobal(`G_${g(t.fieldOf.toUpperCase())}`);
    if (!base || base.type.kind !== 'array' || base.type.elem.kind !== 'struct' || base.place.kind !== 'memory') return null;
    const member = base.type.elem.members.find((m) => m.name === `f_${t.word.toLowerCase()}`);
    if (!member) return null;
    const { count, elem } = base.type;
    const n = Math.min(count, MAX_ELEMENTS);
    const addr = base.place.addr;
    const items = Array.from({ length: n }, (_, i) => cValue(member.type, base.read8, addr + i * elem.size + member.offset, 1));
    return `[${items.join(', ')}${count > n ? `, … (${count})` : ''}]`;
  }
  let v: ArmVariable | null = null;
  if (t.qualifier) {
    v = global(`${t.qualifier.toUpperCase()}_${w}`);
    // `boss.hp`: a field of one struct
    const one = v ? null : armGlobal(`G_${g(t.qualifier.toUpperCase())}`);
    if (one?.type.kind === 'struct' && one.place.kind === 'memory') {
      const member = one.type.members.find((m) => m.name === `f_${t.word.toLowerCase()}`);
      if (member) return cValue(member.type, one.read8, one.place.addr + member.offset);
    }
  }
  else {
    const fn = t.fn ? (t.module.toUpperCase() === entry ? t.fn.name : `${t.module}.${t.fn.name}`) : null;
    const local = () => (fn ? armLocal(fn, `l_${t.word.toLowerCase()}`) : null);
    if (t.fn?.params.some((p) => p.toUpperCase() === w)) v = local();
    v ??= global(g(w)) ?? local();
  }
  return v ? armValue(v) : null;
}

/** The value to show for the hover target, or null (not paused, not a variable). */
export function debugValue(t: HoverTarget): string | null {
  if (useDebugStore.getState().state !== 'paused') return null;
  try {
    return armProgramActive() ? armHoverValue(t) : m6809Value(t);
  } catch (e) {
    console.warn('[debugHover] could not read a value:', e);
    return null;
  }
}

// ---- C ----

const NOT_RUNNING = 'not running (the program is paused in another function)';

/** A struct member: the struct's own value, or across the elements of an array of them. */
function memberValue(base: ArmVariable, field: string, ofElements: boolean): string | null {
  if (base.place.kind !== 'memory') return base.place.kind === 'unavailable' ? 'optimised out here' : null;
  const addr = base.place.addr;
  if (ofElements) {
    if (base.type.kind !== 'array' || base.type.elem.kind !== 'struct') return null;
    const member = base.type.elem.members.find((m) => m.name === field);
    if (!member) return null;
    const { count, elem } = base.type;
    const n = Math.min(count, MAX_ELEMENTS);
    const items = Array.from({ length: n }, (_, i) => cValue(member.type, base.read8, addr + i * elem.size + member.offset, 1));
    return `[${items.join(', ')}${count > n ? `, … (${count})` : ''}]`;
  }
  if (base.type.kind !== 'struct') return null;
  const member = base.type.members.find((m) => m.name === field);
  return member ? cValue(member.type, base.read8, addr + member.offset) : null;
}

/**
 * The value of the C variable at `word` (from 1-based `startColumn` of `line`) in the
 * C file at `filePath`, while an ARM program is paused; null otherwise.
 */
export function cDebugValue(text: string, filePath: string, line: number, word: string, startColumn: number): string | null {
  if (useDebugStore.getState().state !== 'paused' || !armProgramActive()) return null;
  const l = text.split(/\r?\n/)[line - 1] ?? '';
  const before = l.slice(0, startColumn - 1);
  const after = l.slice(startColumn - 1 + word.length);
  if (/^\s*\(/.test(after) || /^[0-9]/.test(word) || /\/\/|\/\*/.test(before)) return null; // a call, a number, a comment
  try {
    const field = /([A-Za-z_]\w*)\s*\[[^\]]*\]\s*\.\s*$/.exec(before);
    const qual = field ? null : /([A-Za-z_]\w*)\s*\.\s*$/.exec(before);
    const baseName = field?.[1] ?? qual?.[1];
    if (baseName) {
      const base = armCVariable(filePath, line, baseName);
      if (base === 'not running') return NOT_RUNNING;
      return base ? memberValue(base, word, !!field) : null;
    }
    if (/->\s*$/.test(before)) return null; // through a pointer: the pointee's type is not kept
    const v = armCVariable(filePath, line, word);
    if (v === 'not running') return NOT_RUNNING;
    return v ? armValue(v) : null;
  } catch (e) {
    console.warn('[debugHover] could not read a C value:', e);
    return null;
  }
}

// ---- changing a value ----

/** A variable whose value the debugger can set: one integer in memory. */
export interface Lvalue { label: string; addr: number; size: number; signed: boolean; current: string }

/** The editable place of a variable (an int or a pointer in memory), or why it is not one. */
function lvalueOf(label: string, v: ArmVariable | null, member?: { type: CType; offset: number }): Lvalue | string | null {
  if (!v) return null;
  const p = v.place;
  if (p.kind === 'unavailable') return `${label} is optimised out here`;
  if (p.kind !== 'memory') return `${label} lives in a register here: changing it is not supported yet`;
  const type = member?.type ?? v.type;
  const addr = p.addr + (member?.offset ?? 0);
  if (type.kind !== 'int' && type.kind !== 'pointer') return `${label} is ${type.kind === 'array' ? 'an array' : type.kind === 'struct' ? 'a struct' : 'not an integer'}: change one of its values`;
  const size = type.kind === 'pointer' ? 4 : type.size;
  const signed = type.kind === 'int' && type.signed;
  return { label, addr, size, signed, current: cValue(type, v.read8, addr) };
}

/** The variable under the mouse in a .vpy file, to change (ARM targets). */
export function vpyLvalue(t: HoverTarget): Lvalue | string | null {
  if (useDebugStore.getState().state !== 'paused') return 'the program is not paused';
  if (!armProgramActive()) return 'changing a value works on the ARM targets (rp2350, uvm2) for now';
  if (t.fieldOf) return `${t.fieldOf}[…].${t.word} is a list: change one element (not supported yet)`;
  const entry = entryModule().toUpperCase();
  const mod = t.module.toUpperCase();
  const w = t.word.toUpperCase();
  const g = (name: string, inModule = mod) => (inModule === entry ? name : `${inModule}_${name}`);
  const global = (name: string): ArmVariable | null => armGlobal(`G_${name}`) ?? armGlobal(`VAR_${name}`);
  if (t.qualifier) {
    const label = `${t.qualifier}.${t.word}`;
    const v = global(`${t.qualifier.toUpperCase()}_${w}`);
    if (v) return lvalueOf(label, v);
    const one = armGlobal(`G_${g(t.qualifier.toUpperCase())}`);
    if (one?.type.kind === 'struct') {
      const member = one.type.members.find((m) => m.name === `f_${t.word.toLowerCase()}`);
      if (member) return lvalueOf(label, one, member);
    }
    return null;
  }
  const fn = t.fn ? (t.module.toUpperCase() === entry ? t.fn.name : `${t.module}.${t.fn.name}`) : null;
  const local = () => (fn ? armLocal(fn, `l_${t.word.toLowerCase()}`) : null);
  let v: ArmVariable | null = null;
  if (t.fn?.params.some((p) => p.toUpperCase() === w)) v = local();
  v ??= global(g(w)) ?? local();
  return lvalueOf(t.word, v);
}

/** The C variable under the mouse, to change. */
export function cLvalue(text: string, filePath: string, line: number, word: string, startColumn: number): Lvalue | string | null {
  if (useDebugStore.getState().state !== 'paused') return 'the program is not paused';
  if (!armProgramActive()) return null;
  const l = text.split(/\r?\n/)[line - 1] ?? '';
  const before = l.slice(0, startColumn - 1);
  if (/[0-9]/.test(word[0] ?? '')) return null;
  if (/\[[^\]]*\]\s*\.\s*$/.test(before)) return `${word}: a field of an array element (not supported yet)`;
  if (/->\s*$/.test(before)) return `${word}: through a pointer (not supported yet)`;
  const qual = /([A-Za-z_]\w*)\s*\.\s*$/.exec(before);
  if (qual) {
    const base = armCVariable(filePath, line, qual[1]);
    if (base === 'not running') return NOT_RUNNING;
    if (!base || base.type.kind !== 'struct') return null;
    const member = base.type.members.find((m) => m.name === word);
    return member ? lvalueOf(`${qual[1]}.${word}`, base, member) : null;
  }
  const v = armCVariable(filePath, line, word);
  if (v === 'not running') return NOT_RUNNING;
  return lvalueOf(word, v);
}

/** A typed value as text: decimal, -decimal, 0x hex, 0b binary or a 'c'haracter. Null if not one. */
export function parseValue(text: string): number | null {
  const t = text.trim().replace(/_/g, '');
  if (/^'.'$/.test(t)) return t.charCodeAt(1);
  if (/^-?(0x[0-9a-f]+|0b[01]+|\d+)$/i.test(t)) {
    const neg = t.startsWith('-');
    const body = neg ? t.slice(1) : t;
    const v = /^0x/i.test(body) ? parseInt(body.slice(2), 16) : /^0b/i.test(body) ? parseInt(body.slice(2), 2) : parseInt(body, 10);
    return neg ? -v : v;
  }
  return null;
}

/** Why `value` does not fit `lv`, or null when it does. */
export function checkValue(lv: Lvalue, text: string): string | null {
  const v = parseValue(text);
  if (v === null) return 'a number: 42, -3, 0x2A, 0b101 or \'A\'';
  const bits = lv.size * 8;
  const min = lv.signed ? -(2 ** (bits - 1)) : -(2 ** (bits - 1));   // a negative is taken as its two's complement
  const max = lv.signed ? 2 ** (bits - 1) - 1 : 2 ** bits - 1;
  if (v < min || v > max) return `out of range for ${lv.size} byte${lv.size > 1 ? 's' : ''}${lv.signed ? ' (signed)' : ''}: ${min}..${max}`;
  return null;
}

/** Write `text` into the variable (little-endian, the ARM targets). */
export async function setValue(lv: Lvalue, text: string): Promise<void> {
  const v = parseValue(text)!;
  const bytes = new Uint8Array(lv.size);
  let u = v < 0 ? 2 ** (lv.size * 8) + v : v;
  for (let i = 0; i < lv.size; i++) { bytes[i] = u % 256; u = Math.floor(u / 256); }
  await armWriteMemory(lv.addr, bytes);
}
