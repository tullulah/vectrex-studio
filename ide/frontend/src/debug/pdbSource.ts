/**
 * Source <-> address lookups in a compiled program's .pdb (vpy_cli generate_pdb).
 *
 * A program is several .vpy files whose line numbers overlap (main.vpy:10 and
 * util.vpy:10 are different code), so every lookup goes by FILE and line:
 *   fileLineMap  "util.vpy" -> {"10": "0x00DE"}   (each file's statements)
 *   vpyLineMap   "222" (decimal PC) -> {file, line} (the way back)
 *   lineMap      the entry file's lines only (older PDBs: the only map)
 *   asmAddressMap  ASM line -> "ADDR" (single-bank .asm breakpoints)
 * Files are named by base name ("util.vpy"), as the compiler writes them.
 *
 * Pure: no stores, no window. tools/pdb-source-test.ts runs it on real PDBs.
 */

export interface PdbLines {
  source?: string;
  lineMap?: Record<string, string>;
  fileLineMap?: Record<string, Record<string, string>>;
  vpyLineMap?: Record<string, { file: string; line: number; column?: number }>;
  asmAddressMap?: Record<string, string>;
  functions?: Record<string, { startLine: number; endLine: number; address: string; file?: string }>;
}

export const baseName = (p: string) => p.replace(/^file:\/\//, '').split(/[\\/]/).pop() || p;

const parseAddr = (a: string) => parseInt(a, 16); // "0x009A" and "009A" alike

/** The entry file's base name ("main.vpy"). */
export function entryFile(pdb: PdbLines): string {
  return baseName(pdb.source || 'main.vpy');
}

/** line -> address of every statement of `file` the PDB knows. */
export function fileLines(pdb: PdbLines, file: string): Map<number, number> {
  const out = new Map<number, number>();
  const name = baseName(file);
  const own = pdb.fileLineMap?.[name];
  if (own) {
    for (const [l, a] of Object.entries(own)) out.set(+l, parseAddr(a));
    return out;
  }
  if (pdb.vpyLineMap) {
    // the lowest address of each line (a line can own several instructions' starts)
    for (const [pc, info] of Object.entries(pdb.vpyLineMap)) {
      if (baseName(info.file) !== name) continue;
      const a = parseInt(pc, 10);
      if (!out.has(info.line) || a < out.get(info.line)!) out.set(info.line, a);
    }
    if (out.size) return out;
  }
  if (name === entryFile(pdb) && pdb.lineMap) {
    for (const [l, a] of Object.entries(pdb.lineMap)) out.set(+l, parseAddr(a));
  }
  return out;
}

/**
 * Where a breakpoint on `file`:`line` stops: that line's address, or — for a line
 * with no code of its own (a comment, `def`, `else:`) — the next statement of the
 * same function, so the breakpoint stops before that line's code runs. Outside any
 * function (or past its last statement) the previous statement. null: no code.
 */
export function breakpointAddress(pdb: PdbLines, file: string, line: number): number | null {
  if (/\.asm$/i.test(file)) {
    const a = pdb.asmAddressMap?.[String(line)];
    return a ? parseInt(a, 16) : null;
  }
  const lines = fileLines(pdb, file);
  if (lines.has(line)) return lines.get(line)!;
  // The function around `line`: from its def to the next def of the same file (the
  // PDB's endLine of a file's last function is only its def line + 1).
  const name = baseName(file);
  const starts = Object.values(pdb.functions || {})
    .filter((f) => (f.file ? baseName(f.file) === name : name === entryFile(pdb)))
    .map((f) => f.startLine).sort((a, b) => a - b);
  const i = starts.findIndex((s, k) => s <= line && (k + 1 === starts.length || starts[k + 1] > line));
  const fn = i < 0 ? null : { start: starts[i], end: i + 1 < starts.length ? starts[i + 1] - 1 : Infinity };
  const sorted = [...lines.keys()].sort((a, b) => a - b);
  const next = sorted.find((l) => l > line && (!fn || l <= fn.end));
  if (next !== undefined) return lines.get(next)!;
  const prev = [...sorted].reverse().find((l) => l < line && (!fn || l >= fn.start));
  return prev !== undefined ? lines.get(prev)! : null;
}

/** The statement that starts at `pc`, if one does. */
export function sourceAt(pdb: PdbLines, pc: number): { file: string; line: number } | null {
  const hit = pdb.vpyLineMap?.[String(pc & 0xffff)];
  if (hit) return { file: baseName(hit.file), line: hit.line };
  if (pdb.fileLineMap) {
    for (const [file, map] of Object.entries(pdb.fileLineMap)) {
      for (const [l, a] of Object.entries(map)) if (parseAddr(a) === pc) return { file, line: +l };
    }
  }
  for (const [l, a] of Object.entries(pdb.lineMap || {})) if (parseAddr(a) === pc) return { file: entryFile(pdb), line: +l };
  return null;
}

/** Every breakpoint's address: `breakpoints` is uri -> lines (the editor store's shape). */
export function breakpointAddresses(pdb: PdbLines, breakpoints: Record<string, Iterable<number>>): Set<number> {
  const out = new Set<number>();
  for (const [uri, lines] of Object.entries(breakpoints)) {
    if (!/\.(vpy|asm)$/i.test(uri)) continue;
    for (const line of lines) {
      const a = breakpointAddress(pdb, uri, line);
      if (a !== null) out.add(a);
    }
  }
  return out;
}

/** Every statement's first address, of every file (where a step may stop). */
export function statementAddresses(pdb: PdbLines): Set<number> {
  const out = new Set<number>();
  for (const pc of Object.keys(pdb.vpyLineMap || {})) out.add(parseInt(pc, 10));
  for (const map of Object.values(pdb.fileLineMap || {})) for (const a of Object.values(map)) out.add(parseAddr(a));
  for (const a of Object.values(pdb.lineMap || {})) out.add(parseAddr(a));
  return out;
}

/**
 * The 6809 call stack of a paused program, rebuilt from its hardware stack.
 *
 * m6809 VPy keeps no frame pointer (parameters and locals live in static frames), so
 * the only trace of the callers is the return addresses JSR/BSR/LBSR pushed on S. The
 * stack is scanned from S up to its top (stackTop); a word counts as a return
 * address only when the bytes before it are a call instruction, and — when the call's
 * target can be decoded — that target is not past the code it supposedly called (a
 * value a PSHS left there rarely passes both).
 *
 * Limits: a call through JSR indexed has no decodable target (its frame is kept, its
 * callee named by address); a return address into another 16 KB bank than the one
 * mapped now is read from the wrong bank and is skipped.
 *
 * Memory comes in as `read8`.
 */

export interface StackPdb extends PdbLines {
  symbols?: Record<string, string>;
  bios_symbols?: Record<string, string>;
}

export interface StackFrame {
  function: string;
  file: string | null;
  line: number | null;
  /** The frame's PC: where it is paused (frame 0) or where it returns to. */
  address: string;
  type: 'vpy' | 'native' | 'bios';
}

/**
 * The end of the stack S is on: a VPy program runs with S from $CFFF (codegen's
 * `LDS #$CFFF`, the top of the 1 KB RAM's high mirror); the BIOS's own stack starts
 * at $CBEA, below its interrupt vectors.
 */
export const stackTop = (s: number) => ((s & 0xffff) >= 0xcc00 ? 0xd000 : 0xcbea);
const MAX_FRAMES = 64;

const hex4 = (n: number) => '0x' + (n & 0xffff).toString(16).toUpperCase().padStart(4, '0');
const isBios = (a: number) => a >= 0xe000;

/** The call that returns to `ret`: its target (null when indexed) or no call at all. */
function callBefore(ret: number, read8: (a: number) => number): { target: number | null } | null {
  const b = (a: number) => read8(a & 0xffff) & 0xff;
  const w = (a: number) => (b(a) << 8) | b(a + 1);
  if (b(ret - 3) === 0xbd) return { target: w(ret - 2) }; // JSR extended
  if (b(ret - 3) === 0x17) return { target: (ret + ((w(ret - 2) << 16) >> 16)) & 0xffff }; // LBSR
  if (b(ret - 2) === 0x8d) return { target: (ret + ((b(ret - 1) << 24) >> 24)) & 0xffff }; // BSR
  if (b(ret - 2) === 0xad) return { target: null }; // JSR ,R / JSR [,R]
  return null;
}

interface Fn { name: string; address: number; type: StackFrame['type']; file: string | null }

/** Every routine the PDB names, by address: user functions first, then runtime, then BIOS. */
function routines(pdb: StackPdb): { byAddr: Map<number, Fn>; user: Fn[] } {
  const byAddr = new Map<number, Fn>();
  const user: Fn[] = [];
  for (const [name, f] of Object.entries(pdb.functions || {})) {
    const fn: Fn = { name, address: parseAddr(f.address), type: 'vpy', file: f.file ? baseName(f.file) : entryFile(pdb) };
    user.push(fn);
    byAddr.set(fn.address, fn);
  }
  for (const [name, a] of Object.entries(pdb.symbols || {})) {
    const addr = parseAddr(a);
    if (!name.includes('.') && !byAddr.has(addr)) byAddr.set(addr, { name, address: addr, type: 'native', file: null });
  }
  for (const [name, a] of Object.entries(pdb.bios_symbols || {})) {
    const addr = parseAddr(a);
    if (!byAddr.has(addr)) byAddr.set(addr, { name, address: addr, type: 'bios', file: null });
  }
  user.sort((x, y) => x.address - y.address);
  return { byAddr, user };
}

/** A user function's name as the source spells it: UTIL_BUMP in util.vpy -> util.bump. */
function displayName(fn: Fn, entry: string): string {
  if (fn.type !== 'vpy') return fn.name;
  const stem = (fn.file || '').replace(/\.vpy$/i, '').toUpperCase();
  if (fn.file && fn.file !== entry && fn.name.startsWith(stem + '_')) {
    return `${stem.toLowerCase()}.${fn.name.slice(stem.length + 1).toLowerCase()}`;
  }
  return fn.name.toLowerCase();
}

export function buildCallStack(pdb: StackPdb, pc: number, s: number, read8: (a: number) => number): StackFrame[] {
  const { byAddr, user } = routines(pdb);
  const entry = entryFile(pdb);
  // Each file's statements by address, to name the line a frame is on
  const statements = new Map<string, Array<[number, number]>>(); // file -> [addr, line] ascending
  for (const fn of user) {
    if (!fn.file || statements.has(fn.file)) continue;
    statements.set(fn.file, [...fileLines(pdb, fn.file)].map(([l, a]) => [a, l] as [number, number]).sort((x, y) => x[0] - y[0]));
  }
  const enclosingUser = (a: number) => {
    let hit: Fn | null = null;
    for (const fn of user) if (fn.address <= a) hit = fn;
    return hit;
  };

  // The frames' PCs, innermost first, and the routine each call went to
  const pcs: number[] = [pc & 0xffff];
  const callees: Array<number | null> = [];
  const top = stackTop(s);
  for (let a = s & 0xffff; a + 1 < top && pcs.length < MAX_FRAMES; a++) {
    const ret = (read8(a) << 8) | read8(a + 1);
    if (ret < 3 || (ret >= 0x8000 && !isBios(ret))) continue; // not ROM
    const call = callBefore(ret, read8);
    if (!call) continue;
    // The call must have gone to (or before) the code of the frame it made
    if (call.target !== null && !isBios(call.target) && call.target > pcs[pcs.length - 1]) continue;
    callees.push(call.target);
    pcs.push(ret);
    a++; // the word's second byte
  }

  return pcs.map((framePc, i) => {
    // A frame's routine: what its caller's call went to, else the user function around it
    const target = callees[i] ?? null;
    let fn = target !== null ? byAddr.get(target) ?? null : null;
    if (!fn && !isBios(framePc)) fn = enclosingUser(framePc);
    const name = fn ? displayName(fn, entry) : target !== null ? hex4(target) : isBios(framePc) ? 'BIOS' : hex4(framePc);
    const type: StackFrame['type'] = fn?.type ?? (isBios(framePc) ? 'bios' : 'native');

    // Its line: the last statement of its function at or before the PC (a return
    // address points past the call, so the call itself is at PC-1). main()'s frame
    // below loop() is the compiler's own frame loop: it has no line.
    let line: number | null = null;
    if (fn?.type === 'vpy' && fn.file) {
      const at = i === 0 ? framePc : framePc - 1;
      const calledLoop = i > 0 && fn.name === 'MAIN' && callees[i - 1] !== null && byAddr.get(callees[i - 1]!)?.name === 'LOOP';
      if (!calledLoop) {
        for (const [addr, l] of statements.get(fn.file) || []) {
          if (addr < fn.address) continue;
          if (addr > at) break;
          line = l;
        }
      }
    }
    return { function: name, file: fn?.type === 'vpy' ? fn.file : null, line, address: hex4(framePc), type };
  });
}
