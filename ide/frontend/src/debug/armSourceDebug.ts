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
import { debugInfo, type DebugInfo, type CType, type VarPlace } from './dwarfInfo';
import { unwind, vpyName } from './armCallStack';
import { showProjectSource } from './showSource';
import { openFileAt } from '../utils/openFile';
import type { ArmDebug } from '../emulator/cpu/armDebug';
import type { Thumb2 } from '../emulator/cpu/Thumb2';

interface ArmSystem { debug: ArmDebug; core0: Thumb2; read8(addr: number): number }

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

function system(): ArmSystem | null {
  return ((emuCore as any).activeArmSystem as ArmSystem | null) ?? null;
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
  if (!table) return;
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

const memRead8 = (s: ArmSystem) => (a: number) => (MEMORY.some(([lo, hi]) => a >= lo && a < hi) ? s.read8(a) : null);

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
  if (!v) return null;
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
  if (!at || !isProjectSource(at.file)) {
    useDebugStore.getState().setCurrentVpyLine(null);
    return;
  }
  const name = baseName(at.file);
  useDebugStore.getState().setCurrentVpyLineWithFile(at.line, name);
  if (/\.vpy$/i.test(at.file)) showProjectSource(name, at.line);
  else void openFileAt(projectRoot() + inProject(at.file)!, at.line - 1); // its path in the editor's form
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
  const atEntry = t.functionStarts.has((s.core0.getReg(15) & ~1) >>> 0);
  const step = kind;
  const until =
    atEntry && step === 'over' ? (pc: number, sp: number) => projectStarts.has(pc) && otherLine(pc) && (sp > sp0 || sameFile(pc))
    : step === 'into' ? (pc: number) => projectStarts.has(pc) && otherLine(pc)
    // over: not deeper; at the same depth only in this file — gcc inlines calls to other
    // modules (no bl, no frame), and their statements are not "the next line"
    : step === 'over' ? (pc: number, sp: number) => projectStarts.has(pc) && otherLine(pc)
        && (sp > sp0 || (sp === sp0 && sameFile(pc)))
    : atEntry ? (pc: number, sp: number) => projectStarts.has(pc) && sp >= sp0 && otherLine(pc)
    : (pc: number, sp: number) => projectStarts.has(pc) && sp > sp0;
  useDebugStore.getState().setCurrentVpyLine(null);
  s.debug.resume(false, until); // before 'running': the store's watcher only resumes a stopped one
  useDebugStore.getState().setState('running');
}

const watched = new WeakSet<ArmDebug>();

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
