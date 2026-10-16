/**
 * The call stack of a paused ARM program, unwound with the ELF's call-frame
 * information (dwarfFrames.ts) and named with its symbols and line table
 * (dwarfLines.ts): innermost first, VPy functions by their .vpy names, then the
 * runtime and the firmware below them.
 *
 * A function gcc inlined has no frame of its own: its line shows in the frame of the
 * function it was inlined into (with -O3, main() and loop() are inside vpy_setup and
 * vpy_loop, and named after them).
 *
 * Pure: registers and memory come in. tools/dwarf-frames-test.ts runs it.
 */
import type { FrameTable } from './dwarfFrames';
import type { LineTable } from './dwarfLines';

export interface ArmFrame {
  function: string;
  /** The .vpy (or C) file's base name, and its line; null without line info. */
  file: string | null;
  line: number | null;
  /** The frame's pc: where it is (frame 0) or the return address (callers). */
  address: string;
  type: 'vpy' | 'native';
}

const MAX_FRAMES = 48;
const hex = (n: number) => '0x' + (n >>> 0).toString(16).toUpperCase().padStart(8, '0');
const baseName = (p: string) => p.split('/').pop() || p;

/**
 * A symbol as the source names it. The runtime's frame functions are main() and
 * loop(); a VPy function's label is its module and its name (asm backend `UTIL_bump`,
 * C backend `F_UTIL_BUMP`, which gcc may suffix with `.isra.0`): `util.bump`.
 */
/** A mangled C++/Rust name (`_ZN12vectrex_draw4ramp…17h<hash>E`) as `vectrex_draw::ramp::…`. */
export function demangle(symbol: string): string {
  const m = /^_ZN((?:\d+[A-Za-z0-9_$.]+)+)E/.exec(symbol);
  if (!m) return symbol;
  const parts: string[] = [];
  for (let s = m[1]; s.length;) {
    const len = /^\d+/.exec(s)![0];
    parts.push(s.slice(len.length, len.length + +len));
    s = s.slice(len.length + +len);
  }
  if (/^h[0-9a-f]{16}$/.test(parts[parts.length - 1])) parts.pop(); // Rust's hash
  return parts.join('::');
}

export function vpyName(symbol: string, modules: string[]): string {
  if (symbol.startsWith('_ZN')) return demangle(symbol);
  const n = symbol.replace(/\..*$/, '');
  if (n === 'vpy_setup' || n === 'game_main' || n === 'uvm2_game_main') return 'main';
  if (n === 'vpy_loop' || n === 'game_main_loop') return 'loop';
  const label = n.startsWith('F_') ? n.slice(2) : null;
  if (label === null && !/^[A-Z0-9]+_/.test(n)) return n; // not a VPy label: C as it is
  const body = label ?? n;
  if (body === 'MAIN' || body === 'LOOP') return body.toLowerCase();
  const up = body.toUpperCase();
  // the longest module name that prefixes it (module names can hold underscores)
  const mod = modules.filter((m) => up.startsWith(m.toUpperCase() + '_')).sort((a, b) => b.length - a.length)[0];
  if (mod) return `${mod}.${body.slice(mod.length + 1).toLowerCase()}`;
  return label !== null ? body.toLowerCase() : n;
}

/**
 * The frame rule of a function without unwind data, read from its prologue (as gdb
 * does): from its start up to `pc`, each `push {…}` and `sub sp, #n` moves the CFA, and
 * a pushed register sits where the push put it. Thumb-1 `push`, Thumb-2 `push.w`
 * (stmdb sp!) and `sub sp, sp, #imm`; anything else is passed over.
 */
export function prologueRow(start: number, pc: number, read16: (addr: number) => number | null) {
  let offset = 0;
  const saved = new Map<number, number>(); // reg -> position below the entry sp
  const push = (list: number) => {
    const regs = Array.from({ length: 16 }, (_, r) => r).filter((r) => list & (1 << r));
    // the lowest register at the lowest address
    regs.forEach((r, k) => saved.set(r, offset + 4 * (regs.length - k)));
    offset += 4 * regs.length;
  };
  for (let a = start; a < pc && a < start + 64;) {
    const hw = read16(a);
    if (hw === null) break;
    if ((hw & 0xfe00) === 0xb400) { push((hw & 0xff) | (hw & 0x100 ? 1 << 14 : 0)); a += 2; continue; } // push {…, lr}
    if ((hw & 0xff80) === 0xb080) { offset += (hw & 0x7f) * 4; a += 2; continue; } // sub sp, #imm7*4
    if (hw === 0xe92d) { const l = read16(a + 2); if (l === null) break; push(l); a += 4; continue; } // push.w
    a += (hw >>> 11) >= 0x1d ? 4 : 2; // any other instruction
  }
  return { cfaReg: 13, cfaOffset: offset, saved: new Map([...saved].map(([r, below]) => [r, -below])) };
}

export function unwind(
  regs0: number[],
  frames: FrameTable,
  lines: LineTable,
  read32: (addr: number) => number | null,
  sourceAt: (pc: number) => { file: string; line: number } | null,
  read16?: (addr: number) => number | null,
): ArmFrame[] {
  const modules = [...lines.files].filter((f) => /\.vpy$/i.test(f)).map((f) => baseName(f).replace(/\.vpy$/i, ''));
  // The asm backend's game_main holds main() and, from the game_main_loop label on, loop()
  const loopLabel = lines.symbolAddress('game_main_loop');
  const name = (symbol: string, start: number, pc: number) =>
    (symbol === 'game_main' || symbol === 'uvm2_game_main') && loopLabel !== undefined && loopLabel > start && pc >= loopLabel ? 'loop' : vpyName(symbol, modules);
  const regs = regs0.map((r) => r >>> 0);
  const out: ArmFrame[] = [];
  for (let i = 0; i < MAX_FRAMES; i++) {
    const pc = (regs[15] & ~1) >>> 0;
    // A caller's pc is its return address: the call is just before it
    const at = i === 0 ? sourceAt(pc) : lines.lineAt(pc - 2);
    const fn = lines.functionAt(i === 0 ? pc : pc - 2);
    const isVpy = !!at && /\.vpy$/i.test(at.file);
    out.push({
      function: fn ? name(fn.name, fn.start, i === 0 ? pc : pc - 2) : hex(pc),
      file: at ? baseName(at.file) : null,
      line: at ? at.line : null,
      address: hex(pc),
      type: isVpy ? 'vpy' : 'native',
    });

    // The caller: CFA by this function's rule, its registers from where this one saved them
    // No unwind data (hand-written asm, a library built without it): the function's
    // prologue says where lr went; with no push it is a leaf, the return address in lr
    const site = i === 0 ? pc : pc - 2;
    const row = frames.rowAt(site) ?? (fn && read16 ? prologueRow(fn.start, site, read16) : null);
    if (!row) break;
    const cfa = (regs[row.cfaReg] + row.cfaOffset) >>> 0;
    const lrAt = row.saved.get(14);
    let ret: number | null;
    if (lrAt !== undefined) ret = read32((cfa + lrAt) >>> 0);
    else if (i === 0) ret = regs[14]; // a leaf (or not pushed yet): lr still holds it
    else break; // a caller that kept lr in a register: unknowable from here
    if (ret === null) break;
    for (const [reg, off] of row.saved) {
      const v = read32((cfa + off) >>> 0);
      if (v !== null) regs[reg] = v;
    }
    const next = (ret & ~1) >>> 0;
    if (!next || next >= 0xfffffff0 || (next === pc && cfa === regs[13])) break; // exception return, or no progress
    regs[13] = cfa;
    regs[15] = next;
  }
  return out;
}
