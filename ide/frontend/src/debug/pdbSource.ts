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
