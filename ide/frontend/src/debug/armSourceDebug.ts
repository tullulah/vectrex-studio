/**
 * The editor's debugger on the ARM targets (rp2350, uvm2): the editor's breakpoints
 * in the running program, the stopped line shown in the editor, and steps by .vpy
 * statement — the m6809 debugger's behaviour, over the ELF's line table
 * (dwarfLines.ts) instead of the .pdb.
 *
 * Steps run the program until the first instruction that starts a statement of one of
 * the project's .vpy files, on another line than the one stepped from:
 *   over  — not deeper in the stack (sp not below where it started)
 *   into  — anywhere
 *   out   — shallower (back in the caller)
 * Running and pausing go through the debug store, which the ARM frame loop follows.
 */
import { emuCore } from '../emulatorCoreSingleton';
import { useDebugStore } from '../state/debugStore';
import { useEditorStore } from '../state/editorStore';
import { useProjectStore } from '../state/projectStore';
import { lineTable, type LineTable } from './dwarfLines';
import { showProjectSource } from './showSource';
import type { ArmDebug } from '../emulator/cpu/armDebug';
import type { Thumb2 } from '../emulator/cpu/Thumb2';

interface ArmSystem { debug: ArmDebug; core0: Thumb2 }

const fsPath = (uri: string) => decodeURI(uri.replace(/^file:\/\//, '')).replace(/\\/g, '/');
const baseName = (p: string) => p.split('/').pop() || p;

let table: LineTable | null = null;
/** Statement starts in the project's own .vpy files: where a step may stop. */
let projectStarts = new Set<number>();
/** The .vpy statements starting at each of those addresses (several when gcc inlines). */
let vpyStartAt = new Map<number, Array<{ file: string; line: number }>>();
/** Editor breakpoints by address: the line the user put each one on. */
let breakpointLines = new Map<number, { file: string; line: number }>();

/**
 * The source line at `pc`: the .vpy statement that starts there, else the line table's
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

/**
 * The table's name for a project file: the same path once both are relative to the
 * project (the ELF has the build's absolute path, which may differ in its prefix —
 * /tmp vs /private/tmp — from the editor's).
 */
function tablePath(file: string): string | null {
  const root = projectRoot();
  if (!table || !root || !file.startsWith(root + '/')) return null;
  const rel = file.slice(root.length); // "/src/main.vpy"
  for (const p of table.files) if (p.endsWith(rel)) return p;
  return null;
}

/** Is `p` (a table path) one of the program's .vpy files? (The SDK has none.) */
const isProjectVpy = (p: string) => /\.vpy$/i.test(p);

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
    if (!/\.vpy$/i.test(uri)) continue;
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

/** Show where the program is paused, when it is in the project's .vpy code. */
export function showArmStop(): void {
  const s = system();
  if (!s || !table) return;
  const at = sourceAt(s.core0.getReg(15));
  if (!at || !isProjectVpy(at.file)) {
    useDebugStore.getState().setCurrentVpyLine(null);
    return;
  }
  const name = baseName(at.file);
  useDebugStore.getState().setCurrentVpyLineWithFile(at.line, name);
  showProjectSource(name, at.line);
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
  projectStarts = new Set();
  vpyStartAt = new Map();
  if (elf) {
    try {
      table = lineTable(elf);
    } catch (e) {
      console.warn('[armSourceDebug] could not read the ELF line table:', e);
    }
  }
  if (table) {
    for (const [key, addrs] of table.starts) {
      const path = key.slice(0, key.lastIndexOf(':'));
      if (!isProjectVpy(path)) continue;
      const line = +key.slice(key.lastIndexOf(':') + 1);
      for (const a of addrs) {
        projectStarts.add(a);
        const list = vpyStartAt.get(a);
        if (list) list.push({ file: path, line }); else vpyStartAt.set(a, [{ file: path, line }]);
      }
    }
    console.log(`[armSourceDebug] ${table.files.size} source files, ${projectStarts.size} .vpy statements of this project`);
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
    lineTable: table ? { files: table.files.size, vpyStatements: projectStarts.size } : null,
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
