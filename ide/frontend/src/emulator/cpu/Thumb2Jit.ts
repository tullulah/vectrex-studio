/**
 * Thumb2Jit — straight runs of Thumb-2 code translated into JS functions, for a system
 * whose step loop costs more than the instructions it steps (Uvm2System: the interpreter
 * alone ran ~90 M instructions a second, the system around it 33).
 *
 * A BLOCK is a run of instructions from one address of the code region (SRAM), translated
 * once and cached by address. The common instructions are emitted inline — registers as
 * constants, flags computed in place, SRAM loads and stores straight on the array — and the
 * rest call the interpreter's own exec16/exec32 with the instruction already fetched. The
 * inline code is a transcription of the interpreter's, including what it does that the
 * architecture would not (ASR #32 takes C from bit 30; a register read of r15 gives the
 * address of the next instruction): the reference is the interpreter, not the ARM ARM, and
 * tools/thumb2-jit-test.ts checks every emitted form against it.
 *
 * Around each instruction the block does what Thumb2.step and the system's loop do:
 *   - IT blocks: the instruction runs only when its condition holds (else 1 cycle), and
 *     itState follows step()'s advance;
 *   - a load or store outside SRAM goes through the same bus calls as the interpreter,
 *     and before it the block publishes what those can look at: r15 = the next
 *     instruction (as step() leaves it), the core's clock before this instruction
 *     (S.relojCore0 / S.relojCore1 — a peripheral access syncs the bus to it) and core 1's
 *     step count (S.muestra1, which its polling skip measures loops by).
 * A block returns after an instruction that changed the PC, touched a peripheral (the
 * system sets S.jitIo: it must re-check its loop — the frame's end, a polling skip), stored
 * into translated code, or brought the clock to `L`, the first value at which the system's
 * scheduler would no longer pick this core. So the order and the timing of everything the
 * two cores do is the interpreter's, instruction for instruction.
 *
 * Translation stops before an address the system traps (isMarked), after an unconditional
 * transfer, and after MAX_INSNS. A store to a page holding translated code drops that
 * page's blocks (onWrite).
 */
import type { Thumb2 } from './Thumb2.js';
import type { IBus } from '../interfaces/IBus.js';

/** (registers, cpu, bus, system, clock limit): runs the block, leaves the state as the
 *  interpreter would after its last executed instruction. */
export type JitBlock = (r: Uint32Array, cpu: Thumb2, bus: IBus, S: any, L: number) => void;

const MAX_INSNS = 64;
const PAGE_SHIFT = 8;

/** advanceIt() of Thumb2. */
function advanceIt(st: number): number {
  return (st & 0x07) === 0 ? 0 : (st & 0xe0) | ((st << 1) & 0x1f);
}

/** Instructions after which nothing in the block can run (the PC always changes). */
function ends16(hw: number): boolean {
  if ((hw & 0xf800) === 0xe000) return true;                 // B
  if ((hw & 0xfe00) === 0xde00) return true;                 // UDF, SVC
  if ((hw & 0xff00) === 0x4700) return true;                 // BX, BLX
  if ((hw & 0xff00) === 0xbd00) return true;                 // POP {.., pc}
  if ((hw & 0xfc00) === 0x4400 && (hw & 0x87) === 0x87 && ((hw >>> 8) & 3) !== 1) return true;   // ADD/MOV pc
  return false;
}
function ends32(hw0: number, hw1: number): boolean {
  if ((hw0 & 0xf800) === 0xf000 && (hw1 & 0x8000)) {
    const kind = (hw1 >>> 14) & 3;
    if (kind === 3) return true;                                    // BL
    if (kind === 2 && (hw1 & 0x1000)) return true;                  // B.W
    if (kind === 2 && ((hw0 >>> 6) & 0xf) < 0xe) return false;      // Bcc.W: falls through
    return true;                                                    // MSR/MRS & co: let the step loop see it
  }
  if ((hw0 & 0xfff0) === 0xe8d0 && (hw1 & 0xffe0) === 0xf000) return true;   // TBB, TBH
  return false;
}

/** decodeThumb2Imm of Thumb2. */
function thumbImm(imm12: number): number {
  const imm8 = imm12 & 0xff;
  const rot8 = (imm12 >>> 8) & 0xf;
  if (rot8 === 0) return imm8;
  if (rot8 === 1) return ((imm8 << 16) | imm8) >>> 0;
  if (rot8 === 2) return ((imm8 << 24) | (imm8 << 8)) >>> 0;
  if (rot8 === 3) return ((imm8 << 24) | (imm8 << 16) | (imm8 << 8) | imm8) >>> 0;
  const rot = (imm12 >>> 7) & 0x1f;
  const val = 0x80 | (imm12 & 0x7f);
  return rot === 0 ? val : ((val >>> rot) | (val << (32 - rot))) >>> 0;
}

// ---- flag code (cpu.cpsr: N 31, Z 30, C 29, V 28) ----

/** setNZ(x) of a u32 expression held in variable `x`. Inside a block the flags live in the
 *  local F (cpu.cpsr is loaded at entry, stored back at exit and around an exec call). */
const NZ = (x: string) => `F = (F & 0x3fffffff) | (${x} & 0x80000000) | (${x} === 0 ? 0x40000000 : 0);`;
/** setC(bit expression 0/1). */
const SETC = (bit: string) => `F = (F & 0xdfffffff) | ((${bit}) << 29);`;
/** setNZCV_add(a, b) with a, b u32 locals: uses x (sum), y (result). */
const ADDF = (a: string, b: string) =>
  `x = ${a} + ${b}; y = x >>> 0; F = (F & 0x0fffffff) | (y & 0x80000000) | (y === 0 ? 0x40000000 : 0) | (x > 4294967295 ? 0x20000000 : 0) | (((((${a}) ^ y) & ((${b}) ^ y)) >>> 31) << 28);`;
/** setNZCV_sub(a, b): a + ~b + 1. */
const SUBF = (a: string, b: string) =>
  `x = ${a} + ((~(${b})) >>> 0) + 1; y = x >>> 0; F = (F & 0x0fffffff) | (y & 0x80000000) | (y === 0 ? 0x40000000 : 0) | (x > 4294967295 ? 0x20000000 : 0) | (((((${a}) ^ (${b})) & ((${a}) ^ y)) >>> 31) << 28);`;

/** evalCond/condPasses of Thumb2 on cpu.cpsr, as an expression. */
function condExpr(cond: number): string {
  const f = 'F';
  let base: string;
  switch (cond & 0xe) {
    case 0x0: base = `((${f} >>> 30) & 1) === 1`; break;
    case 0x2: base = `((${f} >>> 29) & 1) === 1`; break;
    case 0x4: base = `((${f} >>> 31) & 1) === 1`; break;
    case 0x6: base = `((${f} >>> 28) & 1) === 1`; break;
    case 0x8: base = `(((${f} >>> 29) & 1) === 1 && ((${f} >>> 30) & 1) === 0)`; break;
    case 0xa: base = `(((${f} >>> 31) & 1) === ((${f} >>> 28) & 1))`; break;
    case 0xc: base = `(((${f} >>> 31) & 1) === ((${f} >>> 28) & 1) && ((${f} >>> 30) & 1) === 0)`; break;
    default: base = 'true';
  }
  return (cond & 1) ? `!(${base})` : `(${base})`;
}

/** What one instruction compiles to. */
interface Emit {
  /** The code; FLUSH stands for "publish r15, clock, step count" (before a bus access). */
  code: string;
  /** Its cycles: a constant, or 'c' when the code leaves them in c. */
  cyc: number | 'c';
  /** May reach the bus (a load or store outside SRAM, or an exec call). */
  mem: boolean;
  /** After the cycles are counted: exits taken on a branch (uses tk / sets r[15]). */
  post?: string;
  /** An exec call: exit when the PC moved. */
  exec?: boolean;
}

export class Thumb2Jit {
  /** Per core, per halfword of the region: the block starting there; null = nothing to
   *  translate there, undefined = not tried. */
  private readonly blocks: Array<Array<JitBlock | null | undefined>>;
  /** Pages holding translated code, and which block starts each holds (per core). */
  private readonly codePages: Uint8Array;
  private readonly pageStarts: Array<Map<number, Set<number>>>;
  private readonly regionEnd: number;
  blocksBuilt = 0;
  invalidations = 0;
  /** Emit only exec calls (no inline forms): the reference the inline forms are checked by. */
  inline = true;
  /** Set when the page forbids `new Function` (a CSP without 'unsafe-eval'): everything
   *  then runs on the interpreter, as without a translator. */
  disabled = false;

  private readonly mem: Uint8Array;
  private readonly base: number;
  private readonly isMarked: (addr: number) => boolean;

  constructor(mem: Uint8Array, base: number, cores: number, isMarked: (addr: number) => boolean) {
    this.mem = mem;
    this.base = base;
    this.isMarked = isMarked;
    this.blocks = Array.from({ length: cores }, () => new Array(mem.length >>> 1));
    this.codePages = new Uint8Array((mem.length >>> PAGE_SHIFT) + 1);
    this.pageStarts = Array.from({ length: cores }, () => new Map());
    this.regionEnd = base + mem.length;
  }

  /** The page map the CPUs' store fast path checks (Thumb2.setCodeWatch). */
  get watch(): Uint8Array { return this.codePages; }

  /** The block at `pc` for `core`, translating it the first time; null when there is none. */
  block(core: number, pc: number): JitBlock | null {
    const o = pc - this.base;
    if (o < 0 || pc >= this.regionEnd - 4) return null;
    const tab = this.blocks[core];
    const b = tab[o >>> 1];
    if (b !== undefined) return b;
    if (this.disabled) return null;
    let built: JitBlock | null;
    try {
      built = this.translate(core, pc);
    } catch (e) {
      if (!(e instanceof EvalError)) throw e;
      console.warn('[Thumb2Jit] new Function is not allowed here (CSP): running on the interpreter', e);
      this.disabled = true;
      return null;
    }
    tab[o >>> 1] = built;
    return built;
  }

  /** A store at region offset `o` (bytes [o, o+len)): drop the blocks of its pages. */
  onWrite(o: number, len: number): void {
    const p0 = o >>> PAGE_SHIFT, p1 = (o + len - 1) >>> PAGE_SHIFT;
    for (let p = p0; p <= p1; p++) {
      if (!this.codePages[p]) continue;
      this.codePages[p] = 0;
      this.invalidations++;
      for (let core = 0; core < this.blocks.length; core++) {
        const starts = this.pageStarts[core].get(p);
        if (!starts) continue;
        for (const s of starts) this.blocks[core][s] = undefined;
        this.pageStarts[core].delete(p);
      }
    }
  }

  /** Drop everything (a new image, or the traps changed). */
  flush(): void {
    for (const tab of this.blocks) tab.fill(undefined);
    for (const m of this.pageStarts) m.clear();
    this.codePages.fill(0);
  }

  // ---- translation ----

  private translate(core: number, start: number): JitBlock | null {
    const m = this.mem, base = this.base;
    const clk = core === 0 ? 'S.relojCore0' : 'S.relojCore1';
    const out: string[] = [];
    let pc = start, n = 0, it = 0;
    for (; n < MAX_INSNS; n++) {
      if (n > 0 && this.isMarked(pc)) break;
      const o = pc - base;
      if (o < 0 || o + 4 > m.length) break;
      const hw0 = m[o] | (m[o + 1] << 8);
      const is32 = (hw0 >>> 11) >= 0x1d;
      const hw1 = is32 ? (m[o + 2] | (m[o + 3] << 8)) : 0;
      const next = pc + (is32 ? 4 : 2);
      const inIt = it !== 0;
      const flush = core === 0
        ? `${clk} = clk, r[15] = ${next}`
        : `${clk} = clk, r[15] = ${next}, S.muestra1 = m0 + kb + ${n}`;
      const k = `k = kb + ${n + 1};`;
      let e: Emit | null = this.inline ? (is32 ? this.emit32(hw0, hw1, pc, inIt) : this.emit16(hw0, pc, inIt)) : null;
      let code: string, cyc: string;
      if (e === null) {
        // the interpreter: it reads and writes the flags in cpu.cpsr, and r15 it has to see
        const call = is32 ? `cpu.exec32(${hw0}, ${hw1}, bus, ${pc})` : `cpu.exec16(${hw0}, bus, ${pc})`;
        code = `cpu.cpsr = F; ${flush}; c = ${call}; F = cpu.cpsr;`;
        cyc = core === 1 ? '(c > 0 ? c : (z += 1 - c, 1))' : 'c';
      } else {
        code = e.code.replace(/FLUSH/g, flush);
        cyc = String(e.cyc);
      }
      // the instruction, skipped (1 cycle) when an IT condition fails
      if (inIt) {
        const after = advanceIt(it);
        // an exec call checks r15 afterwards: it must hold the next address when skipped too
        out.push(`tk = 0; ${e === null ? `r[15] = ${next}; ` : ''}if (${condExpr((it >>> 4) & 0xf)}) { ${code} clk += ${cyc}; } else clk += 1; cpu.itState = ${after};`);
        it = after;
      } else {
        out.push(`${e !== null && e.post ? 'tk = 0; ' : ''}${code} clk += ${cyc};`);
        // IT: the conditioned instructions that follow carry its state
        if (!is32 && (hw0 & 0xff00) === 0xbf00 && (hw0 & 0xf) !== 0) it = ((hw0 >>> 4) & 0xf) << 4 | (hw0 & 0x1f);
      }
      if (e !== null && e.post) {
        // a branch back to the block's start (a loop) goes round inside the function, while
        // the scheduler would still pick this core (the clock against L)
        const t = /^if \(tk\) \{ r\[15\] = (\d+); break out; \}$/.exec(e.post);
        if (t && Number(t[1]) === start && !/r\[14\]/.test(e.code) && (!inIt || it === 0))
          out.push(`if (tk) { if (clk >= L) { r[15] = ${start}; ${k} break out; } kb += ${n + 1}; continue out; }`);
        else out.push(e.post.replace(/break out;/g, `${k} break out;`));
      }
      if (e === null) out.push(`if (r[15] !== ${next} || S.jitIo || J.invalidations !== iv0) { ${k} break out; }`);
      else if (e.mem) out.push(`if (sl | iv) { if (iv || S.jitIo) { r[15] = ${next}; ${k} break out; } sl = 0; }`);
      out.push(`if (clk >= L) { r[15] = ${next}; ${k} break out; }`);
      pc = next;
      if (is32 ? ends32(hw0, hw1) : ends16(hw0)) { n++; break; }
    }
    if (n === 0) return null;
    const exit = core === 0
      ? `${clk} = clk; cpu.cpsr = F; c = clk - clk0; cpu._cycles += c; cpu._stepCount += k; S.jitSpent = c;`
      : `${clk} = clk; cpu.cpsr = F; S.muestra1 = m0 + k - 1; c = clk - clk0 - z; cpu._cycles += c; cpu._stepCount += k; S.jitSpent = c;`;
    const src =
      `return function (r, cpu, bus, S, L) {\n` +
      `let clk = ${clk}, clk0 = clk, F = cpu.cpsr, m0 = S.muestra1, iv0 = J.invalidations, c = 0, tk = 0, k = 0, kb = 0, z = 0, sl = 0, iv = 0, a = 0, o = 0, v = 0, x = 0, y = 0;\n` +
      `out: for (;;) {\n${out.join('\n')}\nr[15] = ${pc}; k = kb + ${n}; break out;\n}\n${exit}\n};`;
    const fn = new Function('m', 'w', 'J', src)(m, this.codePages, this) as JitBlock;
    const s = (start - base) >>> 1;
    for (let p = (start - base) >>> PAGE_SHIFT; p <= ((pc - 1 - base) >>> PAGE_SHIFT); p++) {
      this.codePages[p] = 1;
      let set = this.pageStarts[core].get(p);
      if (!set) this.pageStarts[core].set(p, set = new Set());
      set.add(s);
    }
    this.blocksBuilt++;
    return fn;
  }

  // ---- memory: SRAM inline, anything else through the interpreter's own calls ----

  private get L4(): number { return this.mem.length - 3; }
  private get L2(): number { return this.mem.length - 1; }

  /** dst = read32(addr). */
  private ld32(addr: string, dst: string): string {
    return `a = ${addr}; o = (a - ${this.base}) >>> 0; ${dst} = o < ${this.L4} ? ((m[o] | (m[o + 1] << 8) | (m[o + 2] << 16) | (m[o + 3] << 24)) >>> 0) : (FLUSH, sl = 1, cpu.read32(bus, a));`;
  }
  /** dst = read16(addr) (zero-extended). */
  private ld16(addr: string, dst: string): string {
    return `a = ${addr}; o = (a - ${this.base}) >>> 0; ${dst} = o < ${this.L2} ? (m[o] | (m[o + 1] << 8)) : (FLUSH, sl = 1, cpu.read16(bus, a));`;
  }
  /** dst = bus.read8(addr) (the interpreter has no fast path for bytes: the system serves SRAM). */
  private ld8(addr: string, dst: string): string {
    return `a = ${addr}; o = (a - ${this.base}) >>> 0; ${dst} = o < ${this.mem.length} ? m[o] : (FLUSH, sl = 1, bus.read8(a));`;
  }
  /** write32(addr, val). */
  private st32(addr: string, val: string): string {
    return `a = ${addr}; v = ${val}; o = (a - ${this.base}) >>> 0; if (o < ${this.L4}) { m[o] = v; m[o + 1] = v >>> 8; m[o + 2] = v >>> 16; m[o + 3] = v >>> 24; cpu.escrituras++; if (w[o >>> 8] | w[(o + 3) >>> 8]) { J.onWrite(o, 4); iv = 1; } } else { FLUSH; sl = 1; cpu.write32(bus, a, v); }`;
  }
  /** write16(addr, val & 0xffff). */
  private st16(addr: string, val: string): string {
    return `a = ${addr}; v = (${val}) & 0xffff; o = (a - ${this.base}) >>> 0; if (o < ${this.L2}) { m[o] = v; m[o + 1] = v >>> 8; cpu.escrituras++; if (w[o >>> 8] | w[(o + 1) >>> 8]) { J.onWrite(o, 2); iv = 1; } } else { FLUSH; sl = 1; cpu.write16(bus, a, v); }`;
  }
  /** bus.write8(addr, val & 0xff): the system's SRAM store (it counts core 1's stores). */
  private st8(addr: string, val: string): string {
    return `a = ${addr}; v = (${val}) & 0xff; o = (a - ${this.base}) >>> 0; if (o < ${this.mem.length}) { if (S.enCore1) S.escriturasCore1++; m[o] = v; if (w[o >>> 8]) { J.onWrite(o, 1); iv = 1; } } else { FLUSH; sl = 1; bus.write8(a, v); }`;
  }

  // ---- 16-bit ----

  private emit16(hw: number, pc: number, inIt: boolean): Emit | null {
    const R = (n: number) => (n === 15 ? String(pc + 2) : `r[${n}]`);   // r15 reads as step() left it
    const nz = (x: string) => (inIt ? '' : NZ(x));

    // shifts by immediate, ADD/SUB reg/imm3
    if ((hw & 0xe000) === 0x0000) {
      const b12_10 = (hw >>> 10) & 7;
      if (b12_10 <= 5) {
        const type = (hw >>> 11) & 3, imm5 = (hw >>> 6) & 0x1f, rm = (hw >>> 3) & 7, rd = hw & 7;
        const setc = (bit: string) => (inIt ? '' : SETC(bit));   // inside IT a 16-bit shift sets no flags
        if (type === 0) {
          if (imm5 === 0) return { code: `y = ${R(rm)}; r[${rd}] = y; ${nz('y')}`, cyc: 1, mem: false };
          return { code: `a = ${R(rm)}; y = (a << ${imm5}) >>> 0; ${setc(`(a >>> ${32 - imm5}) & 1`)} r[${rd}] = y; ${nz('y')}`, cyc: 1, mem: false };
        }
        const amt = imm5 === 0 ? 32 : imm5;
        if (type === 1) {
          if (amt === 32) return { code: `a = ${R(rm)}; ${setc('a >>> 31')} y = 0; r[${rd}] = 0; ${nz('y')}`, cyc: 1, mem: false };
          return { code: `a = ${R(rm)}; ${setc(`(a >>> ${amt - 1}) & 1`)} y = a >>> ${amt}; r[${rd}] = y; ${nz('y')}`, cyc: 1, mem: false };
        }
        const sh = amt >= 32 ? 31 : amt;
        return { code: `a = ${R(rm)} | 0; ${setc(`(a >> ${sh - 1}) & 1`)} y = (a >> ${sh}) >>> 0; r[${rd}] = y; ${nz('y')}`, cyc: 1, mem: false };
      }
      const b12_9 = (hw >>> 9) & 0xf, rd = hw & 7, rn = (hw >>> 3) & 7, f = (hw >>> 6) & 7;
      const b = (b12_9 === 0xc || b12_9 === 0xd) ? `r[${f}]` : String(f);
      if (b12_9 === 0xc || b12_9 === 0xe)
        return { code: `a = ${R(rn)}; v = ${b}; ${inIt ? '' : ADDF('a', 'v')} r[${rd}] = (a + v) >>> 0;`, cyc: 1, mem: false };
      return { code: `a = ${R(rn)}; v = ${b}; ${inIt ? '' : SUBF('a', 'v')} r[${rd}] = (a - v) >>> 0;`, cyc: 1, mem: false };
    }
    if ((hw & 0xe000) === 0x2000) {                 // MOV/CMP/ADD/SUB #imm8
      const op2 = (hw >>> 11) & 3, rdn = (hw >>> 8) & 7, imm8 = hw & 0xff;
      switch (op2) {
        case 0: return { code: `r[${rdn}] = ${imm8}; ${inIt ? '' : `F = (F & 0x3fffffff) | ${imm8 === 0 ? 0x40000000 : 0};`}`, cyc: 1, mem: false };
        case 1: return { code: `a = r[${rdn}]; ${SUBF('a', String(imm8))}`, cyc: 1, mem: false };
        case 2: return { code: `a = r[${rdn}]; ${inIt ? '' : ADDF('a', String(imm8))} r[${rdn}] = (a + ${imm8}) >>> 0;`, cyc: 1, mem: false };
        default: return { code: `a = r[${rdn}]; ${inIt ? '' : SUBF('a', String(imm8))} r[${rdn}] = (a - ${imm8}) >>> 0;`, cyc: 1, mem: false };
      }
    }
    const op6 = (hw >>> 10) & 0x3f;
    if (op6 === 0x10) {                             // ALU
      const alu = (hw >>> 6) & 0xf, rm = (hw >>> 3) & 7, rdn = hw & 7;
      const ab = `a = r[${rdn}]; v = r[${rm}];`;
      switch (alu) {
        case 0x0: return { code: `${ab} y = (a & v) >>> 0; r[${rdn}] = y; ${nz('y')}`, cyc: 1, mem: false };
        case 0x1: return { code: `${ab} y = (a ^ v) >>> 0; r[${rdn}] = y; ${nz('y')}`, cyc: 1, mem: false };
        case 0x8: return { code: `${ab} y = (a & v) >>> 0; ${NZ('y')}`, cyc: 1, mem: false };
        case 0x9: return { code: `${ab} r[${rdn}] = (0 - v) >>> 0; ${inIt ? '' : SUBF('0', 'v')}`, cyc: 1, mem: false };
        case 0xa: return { code: `${ab} ${SUBF('a', 'v')}`, cyc: 1, mem: false };
        case 0xb: return { code: `${ab} ${ADDF('a', 'v')}`, cyc: 1, mem: false };
        case 0xc: return { code: `${ab} y = (a | v) >>> 0; r[${rdn}] = y; ${nz('y')}`, cyc: 1, mem: false };
        case 0xd: return { code: `${ab} y = Math.imul(a, v) >>> 0; r[${rdn}] = y; ${nz('y')}`, cyc: 1, mem: false };
        case 0xe: return { code: `${ab} y = (a & ~v) >>> 0; r[${rdn}] = y; ${nz('y')}`, cyc: 1, mem: false };
        case 0xf: return { code: `${ab} y = (~v) >>> 0; r[${rdn}] = y; ${nz('y')}`, cyc: 1, mem: false };
        default: return null;                       // shifts by register, ADC, SBC, ROR
      }
    }
    if (op6 === 0x11) {                             // hi registers
      const op2 = (hw >>> 8) & 3, rm = (hw >>> 3) & 0xf, rdn = (hw & 7) | (((hw >>> 7) & 1) << 3);
      if (op2 === 3 || rdn === 15) return null;     // BX/BLX, or a write to pc
      if (op2 === 0) return { code: `r[${rdn}] = (r[${rdn}] + ${R(rm)}) >>> 0;`, cyc: 1, mem: false };
      if (op2 === 1) return { code: `a = r[${rdn}]; v = ${R(rm)}; ${SUBF('a', 'v')}`, cyc: 1, mem: false };
      return { code: `r[${rdn}] = ${R(rm)};`, cyc: 1, mem: false };
    }
    if ((hw >>> 11) === 0x09) {                     // LDR literal
      const addr = ((pc + 4) & ~3) + ((hw & 0xff) << 2);
      return { code: this.ld32(String(addr), `r[${(hw >>> 8) & 7}]`), cyc: 2, mem: true };
    }
    if ((hw >>> 12) === 0x5) {                      // load/store register offset
      const op = (hw >>> 9) & 7, rm = (hw >>> 6) & 7, rn = (hw >>> 3) & 7, rt = hw & 7;
      const ad = `(r[${rn}] + r[${rm}]) >>> 0`;
      switch (op) {
        case 0: return { code: this.st32(ad, `r[${rt}]`), cyc: 2, mem: true };
        case 1: return { code: this.st16(ad, `r[${rt}]`), cyc: 2, mem: true };
        case 2: return { code: this.st8(ad, `r[${rt}]`), cyc: 2, mem: true };
        case 3: return { code: `${this.ld8(ad, 'v')} r[${rt}] = (v << 24) >> 24;`, cyc: 2, mem: true };
        case 4: return { code: this.ld32(ad, `r[${rt}]`), cyc: 2, mem: true };
        case 5: return { code: this.ld16(ad, `r[${rt}]`), cyc: 2, mem: true };
        case 6: return { code: this.ld8(ad, `r[${rt}]`), cyc: 2, mem: true };
        default: return { code: `${this.ld16(ad, 'v')} r[${rt}] = (v << 16) >> 16;`, cyc: 2, mem: true };
      }
    }
    if ((hw & 0xe000) === 0x6000) {                 // load/store immediate
      const b12 = (hw >>> 12) & 1, l = (hw >>> 11) & 1, imm5 = (hw >>> 6) & 0x1f, rn = (hw >>> 3) & 7, rt = hw & 7;
      const ad = `(r[${rn}] + ${b12 ? imm5 : imm5 << 2}) >>> 0`;
      if (b12 === 0) return { code: l ? this.ld32(ad, `r[${rt}]`) : this.st32(ad, `r[${rt}]`), cyc: 2, mem: true };
      return { code: l ? this.ld8(ad, `r[${rt}]`) : this.st8(ad, `r[${rt}]`), cyc: 2, mem: true };
    }
    if ((hw >>> 12) === 0x8) {                      // halfword immediate
      const l = (hw >>> 11) & 1, imm5 = (hw >>> 6) & 0x1f, rn = (hw >>> 3) & 7, rt = hw & 7;
      const ad = `(r[${rn}] + ${imm5 << 1}) >>> 0`;
      return { code: l ? this.ld16(ad, `r[${rt}]`) : this.st16(ad, `r[${rt}]`), cyc: 2, mem: true };
    }
    if ((hw >>> 12) === 0x9) {                      // SP-relative
      const l = (hw >>> 11) & 1, rt = (hw >>> 8) & 7;
      const ad = `(r[13] + ${(hw & 0xff) << 2}) >>> 0`;
      return { code: l ? this.ld32(ad, `r[${rt}]`) : this.st32(ad, `r[${rt}]`), cyc: 2, mem: true };
    }
    if ((hw >>> 11) === 0x14) return { code: `r[${(hw >>> 8) & 7}] = ${(((pc + 4) & ~3) + ((hw & 0xff) << 2)) >>> 0};`, cyc: 1, mem: false };
    if ((hw >>> 11) === 0x15) return { code: `r[${(hw >>> 8) & 7}] = (r[13] + ${(hw & 0xff) << 2}) >>> 0;`, cyc: 1, mem: false };
    if ((hw >>> 12) === 0xb) return this.emitMisc(hw, pc, inIt);
    if ((hw >>> 12) === 0xc) {                      // STM / LDM
      const l = (hw >>> 11) & 1, rn = (hw >>> 8) & 7, rlist = hw & 0xff;
      let code = `x = r[${rn}];`, cyc = 1;
      for (let i = 0; i <= 7; i++) {
        if (!(rlist & (1 << i))) continue;
        code += ' ' + (l ? this.ld32('x', `r[${i}]`) : this.st32('x', `r[${i}]`)) + ' x = (x + 4) >>> 0;';
        cyc++;
      }
      if (!(l && (rlist & (1 << rn)))) code += ` r[${rn}] = x;`;
      return { code, cyc, mem: true };
    }
    if ((hw >>> 12) === 0xd) {                      // Bcc (UDF, SVC: the interpreter)
      const cond = (hw >>> 8) & 0xf;
      if (cond >= 0xe) return null;
      const target = (pc + 4 + ((((hw & 0xff) << 24) >> 24) << 1)) >>> 0;
      return { code: `tk = ${condExpr(cond)} ? 1 : 0;`, cyc: 1, mem: false, post: `if (tk) { r[15] = ${target}; break out; }` };
    }
    if ((hw >>> 11) === 0x1c) {                     // B
      const target = (pc + 4 + ((((hw & 0x7ff) << 21) >> 21) << 1)) >>> 0;
      return { code: 'tk = 1;', cyc: 1, mem: false, post: `if (tk) { r[15] = ${target}; break out; }` };
    }
    return null;
  }

  private emitMisc(hw: number, pc: number, inIt: boolean): Emit | null {
    const b11_8 = (hw >>> 8) & 0xf;
    if (b11_8 === 0x5 || b11_8 === 0x4) {           // PUSH
      const pbit = (hw >>> 8) & 1, rlist = hw & 0xff;
      let code = 'x = r[13];', n = 0;
      if (pbit) code += ' x = (x - 4) >>> 0; r[13] = x; ' + this.st32('x', 'r[14]');
      for (let i = 7; i >= 0; i--) if (rlist & (1 << i)) { code += ` x = (x - 4) >>> 0; r[13] = x; ` + this.st32('x', `r[${i}]`); n++; }
      return { code, cyc: 1 + n + pbit, mem: true };
    }
    if (b11_8 === 0xd || b11_8 === 0xc) {           // POP
      const pbit = (hw >>> 8) & 1, rlist = hw & 0xff;
      let code = 'x = r[13];', n = 0;
      for (let i = 0; i <= 7; i++) if (rlist & (1 << i)) { code += ' ' + this.ld32('x', 'v') + ` x = (x + 4) >>> 0; r[13] = x; r[${i}] = v;`; n++; }
      if (!pbit) return { code, cyc: 1 + n, mem: true };
      code += ' ' + this.ld32('x', 'v') + ' x = (x + 4) >>> 0; r[13] = x; tk = 1;';
      return { code, cyc: 2 + n, mem: true, post: 'if (tk) { r[15] = v & ~1; break out; }' };
    }
    if (b11_8 === 0x0) {                            // ADD/SUB SP, #imm
      const imm = (hw & 0x7f) << 2;
      return { code: `r[13] = (r[13] ${(hw >>> 7) & 1 ? '-' : '+'} ${imm}) >>> 0;`, cyc: 1, mem: false };
    }
    if (b11_8 === 0x2) {                            // SXTH SXTB UXTH UXTB
      const op2 = (hw >>> 6) & 3, rm = (hw >>> 3) & 7, rd = hw & 7;
      const e = ['(r[M] << 16) >> 16', '(r[M] << 24) >> 24', 'r[M] & 0xffff', 'r[M] & 0xff'][op2].replace('M', String(rm));
      return { code: `r[${rd}] = ${e};`, cyc: 1, mem: false };
    }
    if (b11_8 === 0xf) {                            // IT, NOP
      const mask = hw & 0xf;
      if (mask === 0) return ((hw >>> 4) & 0xf) === 0 ? { code: '', cyc: 1, mem: false } : null;
      if (inIt) return null;
      return { code: `cpu.itState = ${((((hw >>> 4) & 0xf) << 4) | (mask & 0x1f))};`, cyc: 1, mem: false };
    }
    if ((hw & 0xf500) === 0xb100 || (hw & 0xf500) === 0xb900) {   // CBZ, CBNZ
      const nzb = (hw >>> 11) & 1, rn = hw & 7;
      const imm = (((hw >>> 3) & 0x1f) << 1) | (((hw >>> 9) & 1) << 6);
      return { code: `tk = r[${rn}] ${nzb ? '!==' : '==='} 0 ? 1 : 0;`, cyc: 1, mem: false, post: `if (tk) { r[15] = ${(pc + 4 + imm) >>> 0}; break out; }` };
    }
    return null;
  }

  // ---- 32-bit ----

  private emit32(hw0: number, hw1: number, pc: number, _inIt: boolean): Emit | null {
    const next = pc + 4;
    const R = (n: number) => (n === 15 ? String(next) : `r[${n}]`);

    if ((hw0 & 0xf800) === 0xf000 && (hw1 & 0x8000)) {     // branches
      const J1 = (hw1 >>> 13) & 1, J2 = (hw1 >>> 11) & 1, S = (hw0 >>> 10) & 1;
      const I1 = (~(J1 ^ S)) & 1, I2 = (~(J2 ^ S)) & 1;
      const kind = (hw1 >>> 14) & 3;
      const far = () => {
        const raw = (S << 24) | (I1 << 23) | (I2 << 22) | ((hw0 & 0x3ff) << 12) | ((hw1 & 0x7ff) << 1);
        return (pc + 4 + ((raw << 7) >> 7)) >>> 0;
      };
      if (kind === 3) return { code: `r[14] = ${((pc + 4) >>> 0) | 1}; tk = 1;`, cyc: 3, mem: false, post: `if (tk) { r[15] = ${far()}; break out; }` };
      if (kind === 2 && (hw1 & 0x1000)) return { code: 'tk = 1;', cyc: 3, mem: false, post: `if (tk) { r[15] = ${far()}; break out; }` };
      if (kind === 2) {
        const cond = (hw0 >>> 6) & 0xf;
        if (cond >= 0xe) return null;
        const raw = (((hw0 >>> 10) & 1) << 20) | (((hw1 >>> 11) & 1) << 19) | (((hw1 >>> 13) & 1) << 18) | ((hw0 & 0x3f) << 12) | ((hw1 & 0x7ff) << 1);
        const target = (pc + 4 + ((raw << 11) >> 11)) >>> 0;
        return { code: `tk = ${condExpr(cond)} ? 1 : 0;`, cyc: 3, mem: false, post: `if (tk) { r[15] = ${target}; break out; }` };
      }
      return null;
    }
    const op5 = (hw0 >>> 11) & 0x1f;
    if (op5 !== 0x1d && op5 !== 0x1e && op5 !== 0x1f) return null;

    // exec32_data, in its order
    if ((hw0 & 0xfbf0) === 0xf240 || (hw0 & 0xfbf0) === 0xf2c0) {            // MOVW, MOVT
      const imm16 = ((hw0 & 0xf) << 12) | (((hw0 >>> 10) & 1) << 11) | (((hw1 >>> 12) & 7) << 8) | (hw1 & 0xff);
      const rd = (hw1 >>> 8) & 0xf;
      if (rd === 15) return null;
      if ((hw0 & 0xfbf0) === 0xf240) return { code: `r[${rd}] = ${imm16};`, cyc: 2, mem: false };
      return { code: `r[${rd}] = (r[${rd}] & 0xffff) | ${imm16 << 16};`, cyc: 2, mem: false };
    }
    if ((hw0 & 0xfff0) === 0xfb90 && (hw1 & 0xf0f0) === 0xf0f0) return null;   // SDIV
    if ((hw0 & 0xfff0) === 0xfbb0 && (hw1 & 0xf0f0) === 0xf0f0) return null;   // UDIV
    if ((hw0 & 0xfff0) === 0xfb00 && (hw1 & 0x00e0) === 0x0000) {            // MUL, MLA, MLS
      const rn = hw0 & 0xf, ra = (hw1 >>> 12) & 0xf, rd = (hw1 >>> 8) & 0xf, op = (hw1 >>> 4) & 1, rm = hw1 & 0xf;
      if (rd === 15 || rn === 15 || rm === 15) return null;
      const prod = `Math.imul(r[${rn}], r[${rm}])`;
      const e = ra === 15 ? `${prod} >>> 0` : op ? `(r[${ra}] - ${prod}) >>> 0` : `(r[${ra}] + ${prod}) >>> 0`;
      return { code: `r[${rd}] = ${e};`, cyc: 3, mem: false };
    }
    if ((hw0 & 0xfff0) === 0xfb10 && (hw1 & 0x00c0) === 0x0000) return null;  // SMULxy
    if ((hw0 & 0xff90) === 0xfb80 && (hw1 & 0x00f0) === 0x0000) return null;  // long multiplies
    if ((hw0 & 0xfff0) === 0xfab0 && (hw1 & 0xf0f0) === 0xf080) return null;  // CLZ
    if ((hw0 & 0xf800) === 0xf000) return this.emitDpImm(hw0, hw1, pc);
    if ((hw0 & 0xfe00) === 0xea00) return this.emitDpReg(hw0, hw1, R);
    if ((hw0 & 0xff80) === 0xfa00) return null;                              // shifts by register, extends
    return this.emitLdst32(hw0, hw1, pc);
  }

  private emitDpImm(hw0: number, hw1: number, pc: number): Emit | null {
    const op = (hw0 >>> 5) & 0xf, rn = hw0 & 0xf, rd = (hw1 >>> 8) & 0xf, s = (hw0 >>> 4) & 1, i = (hw0 >>> 10) & 1;
    const Rn = rn === 15 ? String(pc + 4) : `r[${rn}]`;
    if (((hw0 >>> 9) & 1) === 1) {                  // plain immediate: ADDW, SUBW (bitfields, SAT: the interpreter)
      const imm12 = (i << 11) | (((hw1 >>> 12) & 7) << 8) | (hw1 & 0xff);
      if (rd === 15) return null;
      if ((op & 0xd) === 0x0) return { code: `a = ${Rn}; r[${rd}] = (a + ${imm12}) >>> 0; ${s ? ADDF('a', String(imm12)) : ''}`, cyc: 2, mem: false };
      if ((op & 0xd) === 0x5) return { code: `a = ${Rn}; r[${rd}] = (a - ${imm12}) >>> 0; ${s ? SUBF('a', String(imm12)) : ''}`, cyc: 2, mem: false };
      return null;
    }
    const imm = thumbImm((i << 11) | (((hw1 >>> 12) & 7) << 8) | (hw1 & 0xff));
    const RnM = `r[${rn}]`;          // the modified-immediate forms read regs[rn] as the interpreter does
    const R15 = rn === 15 ? String(pc + 4) : RnM;
    // ThumbExpandImm_C: a rotated immediate (imm12[11:10] != 0) gives the logical ops with S
    // their carry, bit 31 of the constant; the other forms leave C alone
    const rotated = ((i << 1) | (((hw1 >>> 12) & 7) >>> 2)) !== 0;
    const flag = (x: string) => (s ? NZ(x) + (rotated ? ` F = (F & 0xdfffffff) | ${(imm >>> 31) << 29};` : '') : '');
    const wr = (noWriteWhen15: boolean) => (rd === 15 ? (noWriteWhen15 ? '' : null) : `r[${rd}] = y;`);
    switch (op) {
      case 0x0: { const w = wr(true); return { code: `y = (${R15} & ${imm}) >>> 0; ${w} ${flag('y')}`, cyc: 2, mem: false }; }
      case 0x1: { const w = wr(false); if (w === null) return null; return { code: `y = (${R15} & ${(~imm) >>> 0}) >>> 0; ${w} ${flag('y')}`, cyc: 2, mem: false }; }
      case 0x2: { const w = wr(false); if (w === null) return null; return { code: `y = ${rn === 15 ? String(imm) : `(${RnM} | ${imm}) >>> 0`}; ${w} ${flag('y')}`, cyc: 2, mem: false }; }
      case 0x3: { const w = wr(false); if (w === null) return null; return { code: `y = ${rn === 15 ? String((~imm) >>> 0) : `(${RnM} | ${(~imm) >>> 0}) >>> 0`}; ${w} ${flag('y')}`, cyc: 2, mem: false }; }
      case 0x4: { const w = wr(true); return { code: `y = (${R15} ^ ${imm}) >>> 0; ${w} ${flag('y')}`, cyc: 2, mem: false }; }
      case 0x8: { const w = wr(true); return { code: `a = ${R15}; ${rd === 15 ? '' : `r[${rd}] = (a + ${imm}) >>> 0;`} ${s ? ADDF('a', String(imm)) : ''}`, cyc: 2, mem: false }; }
      case 0xd: { const w = wr(true); return { code: `a = ${R15}; ${rd === 15 ? '' : `r[${rd}] = (a - ${imm}) >>> 0;`} ${s ? SUBF('a', String(imm)) : ''}`, cyc: 2, mem: false }; }
      case 0xe: { if (rd === 15) return null; return { code: `a = ${R15}; r[${rd}] = (${imm} - a) >>> 0; ${s ? SUBF(String(imm), 'a') : ''}`, cyc: 2, mem: false }; }
      case 0xa: case 0xb: return null;              // ADC, SBC
      default: return { code: '', cyc: 2, mem: false };
    }
  }

  private emitDpReg(hw0: number, hw1: number, R: (n: number) => string): Emit | null {
    const op = (hw0 >>> 5) & 0xf, s = (hw0 >>> 4) & 1, rn = hw0 & 0xf, rd = (hw1 >>> 8) & 0xf, rm = hw1 & 0xf;
    const type = (hw1 >>> 4) & 3, amt = (((hw1 >>> 12) & 7) << 2) | ((hw1 >>> 6) & 3);
    // shiftImm(regs[rm], type, amt), no flags
    const v = R(rm);
    let sh: string;
    if (type === 0) sh = amt === 0 ? v : `(${v} << ${amt}) >>> 0`;
    else if (type === 1) sh = amt === 0 ? '0' : `${v} >>> ${amt}`;
    else if (type === 2) sh = `((${v} | 0) >> ${amt === 0 ? 31 : amt}) >>> 0`;
    else sh = amt === 0 ? `((${v} >>> 1) | (((F >>> 29) & 1) << 31)) >>> 0` : `((${v} >>> ${amt}) | (${v} << ${32 - amt})) >>> 0`;
    // a LOGICAL op with S sets C from the shifter (shiftImmCarry), from Rm before Rd is written:
    // x holds it (-1: LSL #0 leaves C alone)
    let car: string;
    if (type === 0) car = amt === 0 ? '-1' : `(${v} >>> ${32 - amt}) & 1`;
    else if (type === 3) car = amt === 0 ? `${v} & 1` : `(${v} >>> ${amt - 1}) & 1`;
    else car = amt === 0 ? `${v} >>> 31` : `(${v} >>> ${amt - 1}) & 1`;
    const lc = s && car !== '-1' ? `x = ${car}; ` : '';
    const setlc = s && car !== '-1' ? ' F = (F & 0xdfffffff) | (x << 29);' : '';
    const flag = (x: string) => (s ? NZ(x) + setlc : '');
    const Rn = R(rn);
    switch (op) {
      case 0x0: return { code: `${lc}v = ${sh}; y = (${Rn} & v) >>> 0; ${rd !== 15 ? `r[${rd}] = y;` : ''} ${flag('y')}`, cyc: 1, mem: false };
      case 0x1: if (rd === 15) return null; return { code: `${lc}v = ${sh}; y = (${Rn} & ~v) >>> 0; r[${rd}] = y; ${flag('y')}`, cyc: 1, mem: false };
      case 0x2: if (rd === 15) return null;
        return rn === 15 ? { code: `${lc}y = ${sh}; r[${rd}] = y; ${flag('y')}`, cyc: 1, mem: false }
                         : { code: `${lc}v = ${sh}; y = (${Rn} | v) >>> 0; r[${rd}] = y; ${flag('y')}`, cyc: 1, mem: false };
      case 0x3: if (rd === 15) return null;
        return rn === 15 ? { code: `${lc}v = ${sh}; y = (~v) >>> 0; r[${rd}] = y; ${flag('y')}`, cyc: 1, mem: false }
                         : { code: `${lc}v = ${sh}; y = (${Rn} | ~v) >>> 0; r[${rd}] = y; ${flag('y')}`, cyc: 1, mem: false };
      case 0x4: return { code: `${lc}v = ${sh}; y = (${Rn} ^ v) >>> 0; ${rd !== 15 ? `r[${rd}] = y;` : ''} ${flag('y')}`, cyc: 1, mem: false };
      case 0x8: return { code: `v = ${sh}; a = ${Rn}; ${rd !== 15 ? `r[${rd}] = (a + v) >>> 0;` : ''} ${s ? ADDF('a', 'v') : ''}`, cyc: 1, mem: false };
      case 0xd: return { code: `v = ${sh}; a = ${Rn}; ${rd !== 15 ? `r[${rd}] = (a - v) >>> 0;` : ''} ${s ? SUBF('a', 'v') : ''}`, cyc: 1, mem: false };
      case 0xe: if (rd === 15) return null; return { code: `v = ${sh}; a = ${Rn}; r[${rd}] = (v - a) >>> 0; ${s ? SUBF('v', 'a') : ''}`, cyc: 1, mem: false };
      case 0x6: case 0xa: case 0xb: return null;    // LSL wide, ADC, SBC
      default: return { code: '', cyc: 1, mem: false };
    }
  }

  private emitLdst32(hw0: number, hw1: number, pc: number): Emit | null {
    const rn = hw0 & 0xf, rt = (hw1 >>> 12) & 0xf;
    if ((hw0 & 0xfe00) !== 0xf800 && (hw0 & 0xfe00) !== 0xf900) {
      // PUSH.W / POP.W without pc (STMDB SP! / LDMIA SP!)
      if (hw0 === 0xe92d) {
        let n = 0; for (let i = 0; i <= 14; i++) if (hw1 & (1 << i)) n++;
        let code = `x = (r[13] - ${n * 4}) >>> 0; r[13] = x;`;
        for (let i = 0; i <= 14; i++) if (hw1 & (1 << i)) code += ' ' + this.st32('x', `r[${i}]`) + ' x = x + 4;';
        return { code, cyc: n + 1, mem: true };
      }
      if (hw0 === 0xe8bd && !(hw1 & 0x8000)) {
        let n = 0, code = 'x = r[13];';
        for (let i = 0; i <= 14; i++) {
          if (!(hw1 & (1 << i))) continue;
          code += ' ' + this.ld32('x', 'v') + (i !== 13 ? ` r[${i}] = v;` : '') + ' x = x + 4;';
          n++;
        }
        return { code: code + ' r[13] = x >>> 0;', cyc: n + 1, mem: true };
      }
      return null;
    }
    if (rt === 15 || rn === 15) return null;        // literals, loads into pc: the interpreter
    const imm12 = hw1 & 0xfff;
    const puw = () => {
      const P = (hw1 >>> 10) & 1, U = (hw1 >>> 9) & 1, W = (hw1 >>> 8) & 1, imm8 = hw1 & 0xff;
      const off = U ? imm8 : -imm8;
      return { ad: P ? `(x + ${off}) >>> 0` : 'x', wb: W ? ` r[${rn}] = (x + ${off}) >>> 0;` : '' };
    };
    const reg = () => `(r[${rn}] + (r[${hw1 & 0xf}] << ${(hw1 >>> 4) & 3})) >>> 0`;
    // the word loads: hw0 & 0xffd0 is f850 / f8d0
    if ((hw0 & 0xffd0) === 0xf850 || (hw0 & 0xffd0) === 0xf8d0) {
      if (hw0 & 0x0080) return { code: this.ld32(`(r[${rn}] + ${imm12}) >>> 0`, `r[${rt}]`), cyc: 2, mem: true };
      if ((hw1 >>> 11) & 1) { const p = puw(); return { code: `x = r[${rn}]; ${this.ld32(p.ad, 'v')} r[${rt}] = v;${p.wb}`, cyc: 2, mem: true }; }
      return { code: this.ld32(reg(), `r[${rt}]`), cyc: 2, mem: true };
    }
    const k = hw0 & 0xfff0;
    const imm = `(r[${rn}] + ${imm12}) >>> 0`;
    switch (k) {
      case 0xf8c0: return { code: this.st32(imm, `r[${rt}]`), cyc: 2, mem: true };
      case 0xf890: return { code: this.ld8(imm, `r[${rt}]`), cyc: 2, mem: true };
      case 0xf880: return { code: this.st8(imm, `r[${rt}]`), cyc: 2, mem: true };
      case 0xf8b0: return { code: this.ld16(imm, `r[${rt}]`), cyc: 2, mem: true };
      case 0xf8a0: return { code: this.st16(imm, `r[${rt}]`), cyc: 2, mem: true };
      case 0xf990: return { code: `${this.ld8(imm, 'v')} r[${rt}] = (v << 24) >> 24;`, cyc: 2, mem: true };
      case 0xf9b0: return { code: `${this.ld16(imm, 'v')} r[${rt}] = (v << 16) >> 16;`, cyc: 2, mem: true };
    }
    // the T4 (pre/post-index) and register forms
    const forms: Record<number, (ad: string) => string> = {
      0xf840: (ad) => this.st32(ad, `r[${rt}]`),
      0xf810: (ad) => `${this.ld8(ad, 'v')} r[${rt}] = v;`,
      0xf800: (ad) => this.st8(ad, `r[${rt}]`),
      0xf830: (ad) => `${this.ld16(ad, 'v')} r[${rt}] = v;`,
      0xf820: (ad) => this.st16(ad, `r[${rt}]`),
      0xf910: (ad) => `${this.ld8(ad, 'v')} r[${rt}] = (v << 24) >> 24;`,
      0xf930: (ad) => `${this.ld16(ad, 'v')} r[${rt}] = (v << 16) >> 16;`,
    };
    const f = forms[k];
    if (!f) return null;
    if ((hw1 >>> 11) & 1) { const p = puw(); return { code: `x = r[${rn}]; ${f(p.ad)}${p.wb}`, cyc: 2, mem: true }; }
    return { code: f(reg()), cyc: 2, mem: true };
  }
}
