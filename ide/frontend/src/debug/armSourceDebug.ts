/**
 * The editor's debugger on the ARM targets (rp2350, uvm2): the editor's breakpoints
 * in the running program, the stopped line shown in the editor, and steps by
 * statement of the project's own source — the m6809 debugger's behaviour, over the
 * ELF's line table (dwarfLines.ts) instead of the .pdb. The project's source is its
 * .vpy files in a VPy project, and in a C project its C files (not the SDK's, not the
 * build's).
 *
 * Steps run the program until the first instruction that starts a statement of one of
 * the project's source files, on another line than the one stepped from:
 *   over  — not deeper in the stack (sp not below where it started)
 *   into  — anywhere
 *   out   — shallower (back in the caller)
 * Running and pausing go through the debug store, which the ARM frame loop follows.
 */
import { emuCore } from '../emulatorCoreSingleton';
import { useDebugStore } from '../state/debugStore';
import { useEditorStore } from '../state/editorStore';
import { useProjectStore } from '../state/projectStore';
import { lineTable, sections, type LineTable } from './dwarfLines';
import { frameTable, type FrameTable } from './dwarfFrames';
import { debugInfo, type DebugInfo, type CType, type ScopeVar, type VarPlace } from './dwarfInfo';
import { prologueRow, unwind, vpyName } from './armCallStack';
import { showProjectSource } from './showSource';
import { openFileAt } from '../utils/openFile';
import type { ArmDebug } from '../emulator/cpu/armDebug';
import type { Thumb2 } from '../emulator/cpu/Thumb2';

/** What the debugger drives: the run control (ArmDebug, or the cartridge's, hwDebug.ts). */
export interface ArmRunControl {
  readonly breakpoints: Set<number>;
  readonly ideBreakpoints: Set<number>;
  stopped: ArmDebug['stopped'];
  onStop(fn: (reason: NonNullable<ArmDebug['stopped']>, pc: number) => void): void;
  resume(step: boolean, until?: ((pc: number, sp: number) => boolean) | null, kind?: 'over' | 'into' | 'out'): void;
  /** Called after the editor's breakpoints were copied into ideBreakpoints. */
  breakpointsChanged?(): void;
}

/** An ARM program being debugged: an emulator's, or the one on the cartridge (hwDebug.ts). */
export interface ArmSystem {
  debug: ArmRunControl;
  core0: Pick<Thumb2, 'getReg'>;
  read8(addr: number): number;
  /** A byte, or null when the target has not got it to hand (the cartridge reads its RAM
   *  through the probe after a stop); without it, read8. */
  peek?(addr: number): number | null;
  /** Change memory (the debugger setting a variable): the emulators write it at once, the
   *  cartridge through the probe. */
  write8?(addr: number, value: number): void;
  writeMemory?(addr: number, bytes: Uint8Array): Promise<void>;
  /** Fetch what peek() was asked for and did not have; true if anything came in. */
  fetchMissed?(): Promise<boolean>;
  /** Set a register of the paused core (the cartridge, through the probe). */
  writeRegister?(n: number, value: number): Promise<void>;
}

/** Can the target set a register (the emulators; not the cartridge through probe-rs)? */
export function armCanWriteRegisters(): boolean {
  const s = system();
  return !!(s && (s.writeRegister || (s.core0 as { setReg?: unknown }).setReg));
}

/** Set register `n` of the paused program (a variable the compiler keeps in a register). */
export async function armWriteRegister(n: number, value: number): Promise<void> {
  const s = system();
  if (!s) throw new Error('no ARM program');
  if (n < 0 || n > 12) throw new Error(`r${n} is not a register a variable can live in`);
  if (s.writeRegister) { await s.writeRegister(n, value >>> 0); return; }
  const cpu = s.core0 as { setReg?: (n: number, v: number) => void };
  if (!cpu.setReg) throw new Error('this target cannot change registers');
  cpu.setReg(n, value >>> 0);
}

/** After a value was shown as unknown: fetch the memory it needed (the cartridge reads its
 *  RAM on demand) and say whether it is worth computing again. */
export async function armFetchMissed(): Promise<boolean> {
  const s = system();
  return s?.fetchMissed ? s.fetchMissed() : false;
}

/** Write `bytes` at `addr` in the paused program's memory (SRAM, or PSRAM data). */
export async function armWriteMemory(addr: number, bytes: Uint8Array): Promise<void> {
  const s = system();
  if (!s) throw new Error('no ARM program');
  // RAM only: the SRAM and the PSRAM a game's data may live in (never flash, never a peripheral)
  const RAM: Array<[number, number]> = [[0x11000000, 0x11800000], [0x20000000, 0x20082000]];
  if (!RAM.some(([lo, hi]) => addr >= lo && addr + bytes.length <= hi)) throw new Error(`0x${addr.toString(16)} is not RAM the debugger may write`);
  if (s.writeMemory) { await s.writeMemory(addr, bytes); return; }
  if (!s.write8) throw new Error('this target cannot change memory');
  bytes.forEach((b, i) => s.write8!(addr + i, b));
}

const fsPath = (uri: string) => decodeURI(uri.replace(/^file:\/\//, '')).replace(/\\/g, '/');
const baseName = (p: string) => p.split('/').pop() || p;

let table: LineTable | null = null;
let frames: FrameTable | null = null;
/** The ELF the tables came from: its variables are read on the first hover. */
let elfBytes: Uint8Array | null = null;
let info: DebugInfo | null | undefined;
/** Statement starts in the project's own source files: where a step may stop. */
let projectStarts = new Set<number>();
/** The statements starting at each of those addresses (several when gcc inlines). */
let vpyStartAt = new Map<number, Array<{ file: string; line: number }>>();
/** Editor breakpoints by address: the line the user put each one on. */
let breakpointLines = new Map<number, { file: string; line: number }>();

/**
 * The source line at `pc`: the project statement that starts there, else the line table's
 * row. Optimised C puts several rows at one address (a .vpy statement of no length and
 * the C around it, or a call and the first statement of the function inlined there);
 * a breakpoint's own line wins, then the innermost statement (the last row).
 */
function sourceAt(pc: number): { file: string; line: number } | null {
  pc = (pc & ~1) >>> 0;
  const here = vpyStartAt.get(pc);
  if (here) return breakpointLines.get(pc) ?? here[here.length - 1];
  return table?.lineAt(pc) ?? null;
}

/** The cartridge being debugged over SWD (hwDebug.ts): it takes over from the emulator. */
let hardware: ArmSystem | null = null;

function system(): ArmSystem | null {
  return hardware ?? ((emuCore as any).activeArmSystem as ArmSystem | null) ?? null;
}

/** Debug the program on the cartridge (null: back to the emulator's). */
export function setHardwareArmSystem(sys: ArmSystem | null, elf: Uint8Array | null): void {
  hardware = sys;
  if (sys) load(elf);
}

/** What one Thumb instruction does to the flow: where a branch may go, a call, a return, or
 *  a jump this cannot work out (a register, a table it cannot read). */
interface Flow { len: 2 | 4; branch?: number[]; call?: number; ret?: boolean; indirect?: boolean }

export function flowAt(a: number, read16: (a: number) => number | null): Flow | null {
  const h1 = read16(a);
  if (h1 === null) return null;
  if ((h1 >>> 11) < 0b11101) {
    if ((h1 & 0xF000) === 0xD000) {                                     // B<c> T1, svc, udf
      const c = (h1 >> 8) & 0xF;
      if (c === 0xF) return { len: 2 };                                 // svc: back to the next instruction
      if (c === 0xE) return { len: 2, indirect: true };
      return { len: 2, branch: [(a + 4 + (((h1 & 0xFF) << 24) >> 23)) >>> 0] };
    }
    if ((h1 & 0xF800) === 0xE000) return { len: 2, branch: [(a + 4 + (((h1 & 0x7FF) << 21) >> 20)) >>> 0] };   // B T2
    if ((h1 & 0xF500) === 0xB100) return { len: 2, branch: [(a + 4 + ((((h1 >> 9) & 1) << 6) | (((h1 >> 3) & 0x1F) << 1))) >>> 0] };   // CBZ/CBNZ
    if ((h1 & 0xFF87) === 0x4700) return ((h1 >> 3) & 0xF) === 14 ? { len: 2, ret: true } : { len: 2, indirect: true };   // BX
    if ((h1 & 0xFF87) === 0x4780) return { len: 2 };                    // BLX reg: a call, back to the next one
    if ((h1 & 0xFF00) === 0xBD00) return { len: 2, ret: true };         // POP {.., pc}
    if ((h1 & 0xFF87) === 0x4687 || (h1 & 0xFF87) === 0x4487) return { len: 2, indirect: true };   // MOV/ADD pc
    return { len: 2 };
  }
  const h2 = read16(a + 2);
  if (h2 === null) return null;
  if ((h1 & 0xF800) === 0xF000 && (h2 & 0x8000)) {
    const s = (h1 >> 10) & 1, j1 = (h2 >> 13) & 1, j2 = (h2 >> 11) & 1;
    const op = h2 & 0x5000;
    if (op === 0x0000) {                                                 // B<c> T3 (cond 111x: msr, hints...)
      if ((((h1 >> 6) & 0xF) & 0xE) === 0xE) return { len: 4 };
      const imm = (s << 20) | (j2 << 19) | (j1 << 18) | ((h1 & 0x3F) << 12) | ((h2 & 0x7FF) << 1);
      return { len: 4, branch: [(a + 4 + ((imm << 11) >> 11)) >>> 0] };
    }
    const imm = (s << 24) | ((~(j1 ^ s) & 1) << 23) | ((~(j2 ^ s) & 1) << 22) | ((h1 & 0x3FF) << 12) | ((h2 & 0x7FF) << 1);
    const t = (a + 4 + ((imm << 7) >> 7)) >>> 0;
    return op === 0x1000 ? { len: 4, branch: [t] } : { len: 4, call: t };   // B T4 ; BL / BLX imm
  }
  if ((h1 & 0xFFF0) === 0xE8D0 && (h2 & 0xFFE0) === 0xF000) {           // TBB / TBH: a switch's table
    if ((h1 & 0xF) !== 0xF) return { len: 4, indirect: true };          // the table is not right after it
    const half = (h2 & 0x10) !== 0;
    const base = a + 4;
    const byte = (x: number) => { const w = read16(x & ~1); return w === null ? null : (x & 1 ? w >> 8 : w & 0xFF); };
    const targets: number[] = [];
    let tableEnd = Infinity;                                             // the cases' code starts where the table ends
    for (let i = 0; i < 1024; i++) {
      const at = base + (half ? 2 * i : i);
      if (at >= tableEnd) break;
      const e = half ? read16(at) : byte(at);
      if (e === null) break;
      const t = base + 2 * e;
      targets.push(t);
      tableEnd = Math.min(tableEnd, t);
    }
    return { len: 4, branch: targets };
  }
  if (((h1 & 0xFFD0) === 0xE890 || (h1 & 0xFFD0) === 0xE910) && (h2 & 0x8000)) {   // LDM with pc
    return (h1 & 0xF) === 13 ? { len: 4, ret: true } : { len: 4, indirect: true };
  }
  if (((h1 & 0xFFF0) === 0xF8D0 || (h1 & 0xFFF0) === 0xF850) && (h2 >> 12) === 0xF) {   // LDR pc
    return (h1 & 0xF) === 13 ? { len: 4, ret: true } : { len: 4, indirect: true };
  }
  return { len: 4 };
}

/**
 * Where a step from `pc` may stop, for a target that cannot check every instruction (the
 * cartridge stops only at breakpoints, and every one it writes costs a transfer): where the
 * statement at pc can go -- the next statement, its branches' targets (a switch's table
 * included) -- and for `into` the first statement of what it calls. `needReturn` when it
 * can leave the function (the caller sets the return address too). A jump this cannot follow
 * makes it every statement of the function, as before.
 */
export function stepStops(kind: 'over' | 'into' | 'out', pc: number, read16: (a: number) => number | null): { stops: number[]; needReturn: boolean } {
  if (!table) return { stops: [], needReturn: true };
  pc = (pc & ~1) >>> 0;
  const fn = table.functionAt(pc);
  if (!fn) return { stops: [], needReturn: true };
  const here = sourceAt(pc);
  const stoppable = stoppableFor(kind, here);
  // the statement's code: from pc to the next statement start of the function
  let end = fn.end;
  for (const a of table.startSet) if (a > pc && a < end) end = a;
  const stops = new Set<number>();
  const callees: number[] = [];
  let needReturn = false, unknown = false;
  for (let a = pc; a < end;) {
    const f = flowAt(a, read16);
    if (!f) { unknown = true; break; }
    for (const t of f.branch ?? []) if (t < pc || t >= end) stops.add(t);   // inside it is still this statement
    if (f.call !== undefined) callees.push(f.call);
    if (f.ret) needReturn = true;
    if (f.indirect) unknown = true;
    a += f.len;
  }
  if (end < fn.end) stops.add(end); else needReturn = true;   // falls through, or off the end
  if (unknown) {
    needReturn = true;
    for (const a of stoppable) {
      if (a < fn.start || a >= fn.end) continue;
      const at = sourceAt(a);
      if (!(here && at && at.line === here.line && at.file === here.file)) stops.add(a);
    }
  }
  if (kind === 'into') {
    for (const c of callees) {
      const callee = table.functionAt(c);
      if (!callee) continue;
      let first = -1;
      for (const p of stoppable) if (p >= callee.start && p < callee.end && (first < 0 || p < first)) first = p;
      if (first >= 0) stops.add(first);
    }
  }
  return { stops: [...stops], needReturn };
}

function projectRoot(): string | null {
  return useProjectStore.getState().vpyProject?.rootDir?.replace(/\\/g, '/').replace(/\/$/, '') ?? null;
}

/** macOS names /tmp and /private/tmp the same directory: compare paths without it. */
const canonical = (p: string) => p.replace(/^\/private(?=\/)/, '');

/** `p` relative to the project root ("/src/main.c"), or null when outside it. */
function inProject(p: string): string | null {
  const root = projectRoot();
  if (!root) return null;
  const a = canonical(p), r = canonical(root);
  return a.startsWith(r + '/') ? a.slice(r.length) : null;
}

/**
 * The table's name for a project file: the same path once both are relative to the
 * project (the ELF has the build's absolute path, which may differ in its prefix —
 * /tmp vs /private/tmp — from the editor's).
 */
function tablePath(file: string): string | null {
  if (!table) return null;
  const rel = inProject(file); // "/src/main.vpy"
  if (rel === null) return table.files.has(file) ? file : null; // an SDK file, by its own path
  for (const p of table.files) if (p.endsWith(rel)) return p;
  return null;
}

/**
 * Is `p` (a table path) the project's own source? A VPy project's .vpy files (the C its
 * C backend generates is not); a C project's C/asm files under the project, but not
 * under a build directory (the pico-sdk the uvm2 build fetches lives there).
 */
function isProjectSource(p: string): boolean {
  if (/\.vpy$/i.test(p)) return true;
  if (!useProjectStore.getState().vpyProject?.isExternal) return false;
  const rel = inProject(p);
  return rel !== null && /\.(c|h|cc|cpp|cxx|hpp|hh|s)$/i.test(rel) && !/^\/build/i.test(rel);
}

/** A source file the editor can set breakpoints in. */
const SOURCE_FILE = /\.(vpy|c|h|cc|cpp|cxx|hpp|hh|s)$/i;

/** Where a breakpoint on `line` stops: that line's statements, or the next line with code. */
function addressesFor(path: string, line: number): { line: number; addrs: number[] } {
  for (let l = line; l < line + 50; l++) {
    const a = table!.starts.get(`${path}:${l}`);
    if (a) return { line: l, addrs: a };
  }
  return { line, addrs: [] };
}

export function syncArmBreakpoints(): void {
  const s = system();
  if (!s) return;
  s.debug.ideBreakpoints.clear();
  breakpointLines = new Map();
  if (!table) { s.debug.breakpointsChanged?.(); return; }
  for (const [uri, lines] of Object.entries(useEditorStore.getState().breakpoints || {})) {
    if (!SOURCE_FILE.test(uri)) continue;
    const path = tablePath(fsPath(uri));
    if (!path) continue;
    for (const line of lines as Iterable<number>) {
      const at = addressesFor(path, line);
      for (const a of at.addrs) {
        s.debug.ideBreakpoints.add(a);
        if (!breakpointLines.has(a)) breakpointLines.set(a, { file: path, line: at.line });
      }
    }
  }
  s.debug.breakpointsChanged?.();
}

/** Where a debugger may read: memory, never a peripheral (reads have side effects). */
const MEMORY: Array<[number, number]> = [[0x10000000, 0x14000000], [0x20000000, 0x20082000]];

/** The paused program's call stack (innermost first); empty without the ELF's tables. */
export function armCallStack() {
  const s = system();
  if (!s || !table || !frames) return [];
  const read32 = (a: number) => (MEMORY.some(([lo, hi]) => a >= lo && a + 4 <= hi)
    ? ((s.read8(a) | (s.read8(a + 1) << 8) | (s.read8(a + 2) << 16) | (s.read8(a + 3) << 24)) >>> 0)
    : null);
  const read16 = (a: number) => (MEMORY.some(([lo, hi]) => a >= lo && a + 2 <= hi) ? (s.read8(a) | (s.read8(a + 1) << 8)) : null);
  const regs = Array.from({ length: 16 }, (_, i) => s.core0.getReg(i));
  return unwind(regs, frames, table, read32, sourceAt, read16);
}

/** A variable of the paused ARM program: its type and where it is, and how to read it. */
export interface ArmVariable {
  type: CType;
  place: VarPlace;
  read8(addr: number): number | null;
  reg(n: number): number;
}

function variables(): DebugInfo | null {
  if (info === undefined) {
    try {
      info = elfBytes ? debugInfo(sections(elfBytes)) : null;
    } catch (e) {
      console.warn('[armSourceDebug] could not read the ELF variables:', e);
      info = null;
    }
  }
  return info;
}

const memRead8 = (s: ArmSystem) => (a: number) => (MEMORY.some(([lo, hi]) => a >= lo && a < hi) ? (s.peek ? s.peek(a) : s.read8(a)) : null);

/** A global by its symbol: typed with the ELF's debug info, else (the asm backend) a 32-bit integer. */
export function armGlobal(symbol: string): ArmVariable | null {
  const s = system();
  if (!s) return null;
  const read8 = memRead8(s);
  const reg = (n: number) => s.core0.getReg(n) >>> 0;
  const g = variables()?.global(symbol);
  if (g) return { type: g.type, place: { kind: 'memory', addr: g.addr }, read8, reg };
  const addr = table?.symbolAddress(symbol);
  if (addr === undefined) return null;
  // (a function's symbol is not a variable: no value, and never written over)
  if (table?.functionAt(addr)?.start === addr) return null;
  return { type: { kind: 'int', size: 4, signed: true, name: 'int32' }, place: { kind: 'memory', addr }, read8, reg };
}

/**
 * A local or parameter of `vpyFunction` (`loop`, `util.bump`) where the program is
 * paused: of the function at pc or one gcc inlined there. null when that function is
 * not running at pc, or has no such variable; `unavailable` when optimised out there.
 */
export function armLocal(vpyFunction: string, cName: string): ArmVariable | null {
  const s = system();
  const di = variables();
  if (!s || !di || !table) return null;
  const pc = (s.core0.getReg(15) & ~1) >>> 0;
  const modules = [...table.files].filter((f) => /\.vpy$/i.test(f)).map((f) => baseName(f).replace(/\.vpy$/i, ''));
  const scopes = di.scopesAt(pc);
  const at = scopes.findIndex((sc) => vpyName(sc.function, modules).toLowerCase() === vpyFunction.toLowerCase());
  if (at < 0) return null;
  // its own variables, then those of the blocks gcc kept around it (inlined scopes come first)
  const v = scopes[at].vars.find((x) => x.name === cName);
  return v ? placed(s, pc, v) : null;
}

/**
 * The C variable `name` as code at `file`:`line` sees it, where the program is paused:
 * a local or parameter of a function that line is in (when it is running at pc, or
 * inlined there), else a global (file statics included). A line's code can belong to
 * several functions — the start of a `for` in a function gcc inlined is often counted
 * as the caller's — so every function at every address of the line is a candidate, and
 * the innermost one active at pc that has the name wins. `'not running'` when the name
 * is a local of the line's function but that function is not where the program is.
 */
export function armCVariable(file: string, line: number, name: string): ArmVariable | 'not running' | null {
  const s = system();
  const di = variables();
  if (!s || !table) return null;
  const path = tablePath(file);
  const addrs = path ? addressesFor(path, line).addrs : [];
  if (di && addrs.length) {
    const lineScopes = addrs.flatMap((a) => di.scopesAt(a));
    const candidates = new Set(lineScopes.map((sc) => sc.function));
    const pc = (s.core0.getReg(15) & ~1) >>> 0;
    for (const sc of di.scopesAt(pc)) {
      if (!candidates.has(sc.function)) continue;
      const v = sc.vars.find((x) => x.name === name);
      if (v) return placed(s, pc, v);
    }
    if (lineScopes.some((sc) => sc.vars.some((x) => x.name === name))) return 'not running';
  }
  return armGlobal(name);
}

function placed(s: ArmSystem, pc: number, v: ScopeVar): ArmVariable {
  const regs = Array.from({ length: 16 }, (_, i) => s.core0.getReg(i) >>> 0);
  const row = frames?.rowAt(pc);
  const read8 = memRead8(s);
  const read32 = (a: number) => {
    const b = [0, 1, 2, 3].map((i) => read8(a + i));
    return b.some((x) => x === null) ? null : ((b[0]! | (b[1]! << 8) | (b[2]! << 16) | (b[3]! << 24)) >>> 0);
  };
  const cfa = row ? (regs[row.cfaReg] + row.cfaOffset) >>> 0 : null;
  return { type: v.type, place: v.place(pc, { regs, cfa, read32 }), read8, reg: (n) => regs[n] };
}

/** Is an ARM program loaded (its variables are read from the ELF, not the .pdb)? */
export function armProgramActive(): boolean {
  return !!system() && !!table;
}

/** Show where the program is paused, when it is in the project's source, and its stack. */
export function showArmStop(): void {
  const s = system();
  if (!s || !table) return;
  try {
    useDebugStore.getState().updateCallStack(armCallStack());
  } catch (e) {
    console.warn('[armSourceDebug] could not unwind the stack:', e);
  }
  const at = sourceAt(s.core0.getReg(15));
  // the project's source, or (a step went into it) any other file the line table names by
  // its full path: the SDK's C
  if (!at || (!isProjectSource(at.file) && !at.file.startsWith('/'))) {
    useDebugStore.getState().setCurrentVpyLine(null);
    return;
  }
  const name = baseName(at.file);
  useDebugStore.getState().setCurrentVpyLineWithFile(at.line, name);
  if (/\.vpy$/i.test(at.file)) showProjectSource(name, at.line);
  else if (inProject(at.file) !== null) void openFileAt(projectRoot() + inProject(at.file)!, at.line - 1); // its path in the editor's form
  else void openFileAt(at.file, at.line - 1);
}

/**
 * Where a step may stop: `into` goes all the way down, into any source with a line table
 * (the SDK's C, libvpy, the runtime); `over` and `out` from the project's own source stop only
 * in it (a call into the SDK is stepped over), and once inside the SDK they go line by line
 * there too.
 */
function stoppableFor(kind: 'over' | 'into' | 'out', here: { file: string; line: number } | null): Set<number> {
  if (!table) return new Set();
  if (kind === 'into' || !here || !isProjectSource(here.file)) return table.startSet;
  return projectStarts;
}

export function armStep(kind: 'over' | 'into' | 'out'): void {
  const s = system();
  if (!s || !table) { console.warn('[armSourceDebug] no ARM program with line info to step'); return; }
  const t = table;
  const sp0 = s.core0.getReg(13) >>> 0;
  const here = sourceAt(s.core0.getReg(15));
  const sameFile = (pc: number) => !here || sourceAt(pc)?.file === here.file;
  const otherLine = (pc: number) => {
    const l = sourceAt(pc);
    return !here || !l || l.line !== here.line || l.file !== here.file;
  };
  // At a function's first instruction (its `def` line, or with the C backend its first
  // statement) the frame is not pushed yet: sp is still the caller's. There `over` takes
  // the next statement of this file (the body's, at whatever depth the prologue leaves)
  // or anything once back in the caller; `out` is back at the caller's sp, not above it.
  const pc0 = (s.core0.getReg(15) & ~1) >>> 0;
  const atEntry = t.functionStarts.has(pc0);
  const step = kind;
  const stops = stoppableFor(kind, here);
  // OUT OF THE FUNCTION: sp above where it was, or -- a function that pushes nothing (a leaf
  // like `void f(void) { x = 0; }`) returns with the sp it had -- at the sp it was entered
  // with (its CFA) and in another function. Judged by sp alone, a step from a leaf saw the
  // caller "at the same depth, in another file" and went on through the whole frame.
  const fn0 = t.functionAt(pc0);
  let cfa0 = sp0;
  const row = frames?.rowAt(pc0) ?? (fn0 ? prologueRow(fn0.start, pc0, (a) => s.read8(a) | (s.read8(a + 1) << 8)) : null);
  if (row) cfa0 = (s.core0.getReg(row.cfaReg) + row.cfaOffset) >>> 0;
  const left = (pc: number, sp: number) => sp > sp0 || (sp >= cfa0 && t.functionAt(pc)?.start !== fn0?.start);
  const until =
    step === 'into' ? (pc: number) => stops.has(pc) && otherLine(pc)
    // over: back in the caller, or the next line of this function -- at the same depth and
    // only in this file (gcc inlines calls to other modules: no bl, no frame, and their
    // statements are not "the next line"); at a function's first instruction the frame is
    // not pushed yet, so the body's statements are deeper
    : step === 'over' ? (pc: number, sp: number) => stops.has(pc) && otherLine(pc)
        && (left(pc, sp) || ((sp === sp0 || atEntry) && sameFile(pc)))
    // out: back in the caller (from the SDK, `stops` is every statement: whoever called)
    : (pc: number, sp: number) => stops.has(pc) && left(pc, sp);
  useDebugStore.getState().setCurrentVpyLine(null);
  s.debug.resume(false, until, kind); // before 'running': the store's watcher only resumes a stopped one
  useDebugStore.getState().setState('running');
}

const watched = new WeakSet<ArmRunControl>();

function load(elf: Uint8Array | null): void {
  table = null;
  frames = null;
  elfBytes = elf;
  info = undefined;
  projectStarts = new Set();
  vpyStartAt = new Map();
  if (elf) {
    try {
      table = lineTable(elf);
      frames = frameTable(elf);
    } catch (e) {
      console.warn('[armSourceDebug] could not read the ELF line table:', e);
    }
  }
  if (table) {
    for (const [key, addrs] of table.starts) {
      const path = key.slice(0, key.lastIndexOf(':'));
      if (!isProjectSource(path)) continue;
      const line = +key.slice(key.lastIndexOf(':') + 1);
      for (const a of addrs) {
        projectStarts.add(a);
        const list = vpyStartAt.get(a);
        if (list) list.push({ file: path, line }); else vpyStartAt.set(a, [{ file: path, line }]);
      }
    }
    console.log(`[armSourceDebug] ${table.files.size} source files, ${projectStarts.size} statements of this project's source`);
  }
  const s = system();
  if (s && !watched.has(s.debug)) {
    watched.add(s.debug);
    s.debug.onStop(() => {
      useDebugStore.getState().setState('paused');
      showArmStop();
    });
  }
  syncArmBreakpoints();
}

/** What the ARM debugger knows now (the MCP's emulator_get_state shows it). */
export function armDebugInfo(): Record<string, unknown> | null {
  const s = system();
  if (!s) return null;
  const pc = s.core0.getReg(15) >>> 0;
  const hex = (n: number) => '0x' + (n >>> 0).toString(16).toUpperCase().padStart(8, '0');
  return {
    pcHex: hex(pc),
    spHex: hex(s.core0.getReg(13)),
    source: sourceAt(pc),
    lineTable: table ? { files: table.files.size, projectStatements: projectStarts.size, unwindEntries: frames?.fdes ?? 0 } : null,
    editorBreakpoints: [...s.debug.ideBreakpoints].map(hex),
    gdbBreakpoints: [...s.debug.breakpoints].map(hex),
    stopped: s.debug.stopped,
  };
}

let installed = false;

export function installArmSourceDebug(): void {
  if (installed) return;
  installed = true;
  (emuCore as any).onArmProgramLoaded?.(load);
  useEditorStore.subscribe((st, prev) => { if (st.breakpoints !== prev.breakpoints) syncArmBreakpoints(); });
  useProjectStore.subscribe((st, prev) => { if (st.vpyProject !== prev.vpyProject) syncArmBreakpoints(); });
}
