/**
 * The block translator (src/emulator/cpu/Thumb2Jit.ts) against the interpreter it stands
 * in for (src/emulator/cpu/Thumb2.ts), instruction by instruction.
 *
 *   node tools/thumb2-jit-test.ts [samples-per-encoding]
 *
 * Every 16-bit encoding and a spread of 32-bit ones, from random states (registers often
 * pointing into the SRAM, random flags), alone and as the conditioned instruction of an IT
 * block (condition true and false). Both sides must end with the same registers, flags,
 * IT state, cycle and step counts, store counters and memory, and must have made the same
 * bus accesses, each seeing the same r15, core clock and core-1 step count — what the
 * system looks at during an access. An instruction the interpreter throws on must throw
 * in the block too.
 */
import assert from 'node:assert/strict';
import { Thumb2 } from '../src/emulator/cpu/Thumb2.ts';
import { Thumb2Jit } from '../src/emulator/cpu/Thumb2Jit.ts';

const BASE = 0x20000000;
const SIZE = 0x10000;
const CODE = BASE + 0x100;

let seed = 12345;
const rnd = () => { seed = (seed * 1103515245 + 12345) >>> 0; return seed; };

/** A system as the CPU and a block see it: SRAM served from `mem`, anything else logged. */
function system(mem: Uint8Array, core: number) {
  const S: any = {
    relojCore0: 0, relojCore1: 0, muestra1: 0, jitIo: false, jitSpent: 0,
    enCore1: core === 1, escriturasCore1: 0, log: [] as string[], cpu: null as any, jit: null as Thumb2Jit | null,
    read8(a: number): number {
      a >>>= 0;
      if (a >= BASE && a < BASE + SIZE) return mem[a - BASE];
      S.jitIo = true;
      const v = (Math.imul(a, 2654435761) >>> 24) & 0xff;
      S.log.push(`r8 ${a.toString(16)} ${v} pc=${S.cpu.getReg(15)} clk=${core ? S.relojCore1 : S.relojCore0} m=${S.muestra1}`);
      return v;
    },
    write8(a: number, d: number): void {
      a >>>= 0; d &= 0xff;
      if (S.enCore1) S.escriturasCore1++;
      if (a >= BASE && a < BASE + SIZE) {
        mem[a - BASE] = d;
        if (S.jit && S.jit.watch[(a - BASE) >>> 8]) S.jit.onWrite(a - BASE, 1);
        return;
      }
      S.jitIo = true;
      S.log.push(`w8 ${a.toString(16)} ${d} pc=${S.cpu.getReg(15)} clk=${core ? S.relojCore1 : S.relojCore0} m=${S.muestra1}`);
    },
  };
  return S;
}

function randomState() {
  const regs: number[] = [];
  for (let i = 0; i < 16; i++) {
    const k = rnd() & 3;
    regs.push(k === 0 ? rnd() >>> 0 : k === 1 ? (BASE + 0x8000 + (rnd() & 0x7ff0)) >>> 0 : k === 2 ? rnd() & 0xff : (rnd() & 0x1f));
  }
  regs[13] = (BASE + 0xc000 + (rnd() & 0x1ff0)) >>> 0;   // a stack in SRAM
  return { regs, cpsr: (rnd() & 0xf0000000) | 0, mem: Uint8Array.from({ length: SIZE }, () => rnd() & 0xff) };
}

type Side = { cpu: any; S: any; mem: Uint8Array; threw: string | null; clk: number; steps: number; spent: number };

function setup(st: ReturnType<typeof randomState>, code: number[], core: number): Side {
  const mem = st.mem.slice();
  let p = CODE - BASE;
  for (const h of code) { mem[p] = h & 0xff; mem[p + 1] = h >>> 8; p += 2; }
  const cpu: any = new Thumb2();
  cpu.reset();
  cpu.setFetchRegion(mem, BASE);
  cpu.setDataRegion(mem, BASE);
  for (let i = 0; i < 15; i++) cpu.setReg(i, st.regs[i]);
  cpu.setReg(15, CODE);
  cpu.cpsr = st.cpsr;
  const S = system(mem, core);
  S.cpu = cpu;
  S.relojCore0 = S.relojCore1 = 1000;
  S.muestra1 = 77;
  return { cpu, S, mem, threw: null, clk: 1000, steps: 0, spent: 0 };
}

/** The interpreter, as the system's step loop drives it, over `n` instructions in a row. */
function runInterp(side: Side, n: number, core: number) {
  const { cpu, S } = side;
  let expect = CODE;
  try {
    for (let i = 0; i < n; i++) {
      if ((cpu.getReg(15) >>> 0) !== expect) break;       // a branch left the run
      if (core === 1) S.muestra1++;
      if (core === 0) S.relojCore0 = side.clk; else S.relojCore1 = side.clk;
      const hw = side.mem[expect - BASE] | (side.mem[expect - BASE + 1] << 8);
      const c = cpu.step(S);
      side.clk += core === 1 ? (c > 0 ? c : 1) : c;
      side.spent += c;
      side.steps++;
      expect += (hw >>> 11) >= 0x1d ? 4 : 2;
      if (S.jitIo) break;
    }
  } catch (e: any) { side.threw = String(e?.message || e).replace(/ at PC=.*/, ''); }
  if (core === 0) S.relojCore0 = side.clk; else S.relojCore1 = side.clk;
}

/** The block for the same run (translation stopped right after it). */
function runBlock(side: Side, n: number, core: number, inline: boolean) {
  const { cpu, S, mem } = side;
  let end = CODE;
  for (let i = 0; i < n; i++) { const hw = mem[end - BASE] | (mem[end - BASE + 1] << 8); end += (hw >>> 11) >= 0x1d ? 4 : 2; }
  const jit = new Thumb2Jit(mem, BASE, 2, (a) => a >= end);
  jit.inline = inline;
  S.jit = jit;
  cpu.setCodeWatch(jit.watch, (o: number, l: number) => jit.onWrite(o, l));
  if (core === 1) S.muestra1++;                            // pasoCore1 counts the first one
  const blk = jit.block(core, CODE);
  assert.ok(blk, 'no block');
  try { blk!(cpu.regs, cpu, S, S, 1e15); } catch (e: any) { side.threw = String(e?.message || e).replace(/ at PC=.*/, ''); }
  side.spent = S.jitSpent;
}

let checked = 0, failed = 0;
function compare(label: string, a: Side, b: Side) {
  checked++;
  const diffs: string[] = [];
  if (a.threw !== b.threw) diffs.push(`throw: ${a.threw} vs ${b.threw}`);
  if (!a.threw) {
    for (let i = 0; i < 16; i++) if ((a.cpu.getReg(i) >>> 0) !== (b.cpu.getReg(i) >>> 0)) diffs.push(`r${i}: ${a.cpu.getReg(i).toString(16)} vs ${b.cpu.getReg(i).toString(16)}`);
    if ((a.cpu.cpsr >>> 0) !== (b.cpu.cpsr >>> 0)) diffs.push(`cpsr: ${(a.cpu.cpsr >>> 0).toString(16)} vs ${(b.cpu.cpsr >>> 0).toString(16)}`);
    if (a.cpu.itState !== b.cpu.itState) diffs.push(`itState ${a.cpu.itState} vs ${b.cpu.itState}`);
    if (a.cpu._cycles !== b.cpu._cycles) diffs.push(`cycles ${a.cpu._cycles} vs ${b.cpu._cycles}`);
    if (a.cpu._stepCount !== b.cpu._stepCount) diffs.push(`steps ${a.cpu._stepCount} vs ${b.cpu._stepCount}`);
    if (a.spent !== b.spent) diffs.push(`spent ${a.spent} vs ${b.spent}`);
    for (const f of ['relojCore0', 'relojCore1', 'muestra1', 'escriturasCore1', 'jitIo'])
      if (a.S[f] !== b.S[f]) diffs.push(`${f} ${a.S[f]} vs ${b.S[f]}`);
    if (a.cpu.escrituras !== b.cpu.escrituras) diffs.push(`escrituras ${a.cpu.escrituras} vs ${b.cpu.escrituras}`);
    for (let i = 0; i < SIZE; i++) if (a.mem[i] !== b.mem[i]) { diffs.push(`mem[${(BASE + i).toString(16)}] ${a.mem[i]} vs ${b.mem[i]}`); break; }
  }
  if (a.S.log.join('|') !== b.S.log.join('|')) diffs.push(`bus log:\n    ${a.S.log.join('\n    ')}\n  vs\n    ${b.S.log.join('\n    ')}`);
  if (diffs.length) {
    failed++;
    if (failed <= 25) console.log(`FAIL ${label}\n  ${diffs.join('\n  ')}`);
  }
}

function check(code: number[], n: number, label: string) {
  const st = randomState();
  for (const core of [0, 1]) {
    const a = setup(st, code, core), b = setup(st, code, core);
    runInterp(a, n, core);
    runBlock(b, n, core, true);
    compare(`${label} core${core}`, a, b);
  }
}

const per = Number(process.argv[2] || 3);
const it = (cond: number) => 0xbf08 | (cond << 4);        // IT <cond> (one instruction)

// every 16-bit encoding
for (let hw = 0; hw < 0xe800; hw++) {
  for (let s = 0; s < per; s++) check([hw], 1, `16:${hw.toString(16)}`);
  // conditioned by IT (the condition decides through the random flags)
  if ((hw & 0xff00) !== 0xbf00) check([it(rnd() % 14), hw], 2, `IT 16:${hw.toString(16)}`);
}
// 32-bit: each family's hw0 range with random hw1
const fam32 = [
  [0xf000, 0xf800],   // data-processing immediate / branches
  [0xea00, 0xec00],   // data-processing register
  [0xe800, 0xea00],   // load/store multiple, dual, exclusive, table branch
  [0xf800, 0xfa00],   // loads and stores
  [0xfb00, 0xfc00],   // multiplies
];
for (const [lo, hi] of fam32) {
  for (let hw0 = lo; hw0 < hi; hw0++) {
    for (let s = 0; s < per * 6; s++) {
      const hw1 = rnd() & 0xffff;
      check([hw0, hw1], 1, `32:${hw0.toString(16)} ${hw1.toString(16)}`);
      if (s === 0) check([it(rnd() % 14), hw0, hw1], 2, `IT 32:${hw0.toString(16)} ${hw1.toString(16)}`);
    }
  }
}
// a few runs of several instructions, as compiled code has them
for (let s = 0; s < 20000; s++) {
  const code: number[] = []; let n = 0;
  while (n < 6) {
    const r = rnd() & 7;
    if (r < 5) { let hw = rnd() & 0xffff; if ((hw >>> 11) >= 0x1d) hw &= 0x7fff; if ((hw & 0xf000) === 0xd000 || (hw & 0xf800) === 0xe000) hw &= 0x3fff; code.push(hw); }
    else { const f = fam32[rnd() % fam32.length]; code.push(f[0] + (rnd() % (f[1] - f[0])), rnd() & 0xffff); }
    n++;
  }
  check(code, n, `run ${code.map((h) => h.toString(16)).join(' ')}`);
}

console.log(`${checked} comparisons, ${failed} failed`);
if (failed) process.exit(1);
