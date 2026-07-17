/**
 * PitrexArm32.ts — ARM32 (ARMv6) interpreter for the PiTrex emulator.
 *
 * Executes the subset of ARM32 assembly emitted by vpy_codegen's pitrex
 * backend. Uses instruction indices (not byte addresses) as the PC so we
 * can work directly with the parsed text representation.
 *
 * Design goals:
 *   - Correctness for the instruction subset actually generated
 *   - Simple sparse memory model (Map<alignedAddr, word32>)
 *   - SDK stub table for PiTrex-specific functions
 *   - Terminates each frame when v_WaitRecal is called
 */

import type { ParsedAsm } from './PitrexAsmParser.js';
import { resolveSymbol }  from './PitrexAsmParser.js';

// ---------------------------------------------------------------------------
// Segment output (same shape used by the IDE renderer)
// ---------------------------------------------------------------------------

export interface PitrexSegment {
  x0: number; y0: number;
  x1: number; y1: number;
  intensity: number;
}

export interface PitrexTextSegment {
  x: number; y: number;   // VPy coords
  text: string;
  size: number;           // from r3 (text scale factor)
}

export interface PitrexFrameResult {
  segments: PitrexSegment[];
  texts: PitrexTextSegment[];
  timeout: boolean;
}

// ---------------------------------------------------------------------------
// Emulator state
// ---------------------------------------------------------------------------

export interface PitrexArm32State {
  /** General-purpose registers r0..r14. r15 (PC) is managed separately. */
  regs: Int32Array;
  /** Current instruction index (= PC). */
  pc: number;
  /** CPSR flags */
  N: number; Z: number; C: number; V: number;
  /** Sparse memory: 4-byte-aligned address → signed 32-bit word. */
  mem: Map<number, number>;
  /** Parsed assembly. */
  parsed: ParsedAsm;
  /** Segments collected this frame. */
  segments: PitrexSegment[];
  /** Text segments collected this frame (from v_printStringRaster). */
  texts: PitrexTextSegment[];
  /** Set to true when v_WaitRecal is called. */
  waitRecalCalled: boolean;
  /** Joystick 1 / button inputs. */
  joyX: number; joyY: number; joyButtons: number;
  /** Joystick 2 inputs. */
  joyX2: number; joyY2: number; joyButtons2: number;
  /** Step counter (safety guard against infinite loops). */
  steps: number;
  /** Simulated BCM CLO base in µs — advanced by exactly 20000 each runFrame()
   *  call so pitrex_music_update sees stable 50 Hz deltas. Reading the CLO
   *  returns base + a small intra-frame counter (so work_us measurements are
   *  still non-zero and monotonic) but never crosses into the next tick. */
  bcmCloBaseUs: number;
  bcmCloIntraUs: number;
  /** PSG register write callback — set by PitrexCore to drive audio synthesis. */
  psgWrite: (reg: number, val: number) => void;
  /** PSG register read callback — set by PitrexCore so SFX can RMW the mixer. */
  psgRead: (reg: number) => number;
  /** PLAY_SAMPLE trap — set by PitrexCore. Plays a .vsmp voice asset (video
   *  movie soundtrack) whose _<NAME>_SMP header lives in emulator memory.
   *  `read8` reads a byte at an absolute address. HW is a no-op; this gives the
   *  IDE emulator sound. */
  playSample?: (assetPtr: number, read8: (addr: number) => number) => void;
  /** Buffered UART output — accumulates text until newline, then flushes. */
  uartBuffer: string;
}

// ---------------------------------------------------------------------------
// Memory helpers
// ---------------------------------------------------------------------------

// BCM system timer struct (Pi Zero hardware register, simulated)
// bcm2835_st points to this struct; offset +4 is the CLO (free-running µs counter).
const BCM_TIMER_ADDR = 0x20003000;

function memRead32(s: PitrexArm32State, addr: number): number {
  const aligned = addr & ~3;
  // Intercept BCM CLO register read — return a *fake* monotonic µs counter that
  // advances by exactly 20000 per runFrame() call. The real `performance.now()`
  // value would create irregular deltas because the IDE rAF loop runs at 60 Hz
  // gated to a 50 Hz target (one 33 ms call, four 16.67 ms calls, one skip),
  // so the music sequencer's tick accumulator periodically picks up >40 ms and
  // fires two PSG events back-to-back — audible as dirt/clicks. With a fixed
  // 20 ms step per frame, pitrex_music_update sees a clean 1-tick delta every
  // call. The intra-frame counter keeps pitrex_wait_recal's work_us calculation
  // monotonic and non-zero so its overflow logging still works.
  if (aligned === BCM_TIMER_ADDR + 4) {
    s.bcmCloIntraUs = (s.bcmCloIntraUs + 1) | 0;     // tiny tick on every read
    return ((s.bcmCloBaseUs + s.bcmCloIntraUs) >>> 0);
  }
  return s.mem.get(aligned) ?? 0;
}
function memWrite32(s: PitrexArm32State, addr: number, val: number): void {
  s.mem.set(addr & ~3, val | 0);
}
function memRead16(s: PitrexArm32State, addr: number): number {
  const word  = memRead32(s, addr);
  const shift = (addr & 2) * 8;
  return (word >>> shift) & 0xFFFF;
}
function memWrite16(s: PitrexArm32State, addr: number, val: number): void {
  const aligned = addr & ~3;
  const shift   = (addr & 2) * 8;
  const word    = memRead32(s, aligned);
  memWrite32(s, aligned, (word & ~(0xFFFF << shift)) | ((val & 0xFFFF) << shift));
}
function memRead8(s: PitrexArm32State, addr: number): number {
  const word  = memRead32(s, addr);
  const shift = (addr & 3) * 8;
  return (word >>> shift) & 0xFF;
}
function memWrite8(s: PitrexArm32State, addr: number, val: number): void {
  const aligned = addr & ~3;
  const shift   = (addr & 3) * 8;
  const word    = memRead32(s, aligned);
  memWrite32(s, aligned, (word & ~(0xFF << shift)) | ((val & 0xFF) << shift));
}

// ---------------------------------------------------------------------------
// Register helpers
// ---------------------------------------------------------------------------

/** SP = r13, LR = r14. */
const SP = 13, LR = 14;

function getReg(s: PitrexArm32State, n: number): number { return s.regs[n]; }
function setReg(s: PitrexArm32State, n: number, v: number): void { s.regs[n] = v | 0; }

// Stack helpers
function stackPush(s: PitrexArm32State, val: number): void {
  s.regs[SP] = (s.regs[SP] - 4) | 0;
  memWrite32(s, s.regs[SP], val);
}
function stackPop(s: PitrexArm32State): number {
  const v = memRead32(s, s.regs[SP]);
  s.regs[SP] = (s.regs[SP] + 4) | 0;
  return v;
}

// ---------------------------------------------------------------------------
// CMP / flag setting
// ---------------------------------------------------------------------------

function setNZFlags(s: PitrexArm32State, val: number): void {
  s.N = val < 0 ? 1 : 0;
  s.Z = val === 0 ? 1 : 0;
}

function setCmpFlags(s: PitrexArm32State, a: number, b: number): void {
  const a32  = a | 0;
  const b32  = b | 0;
  const res  = (a32 - b32) | 0;
  s.N = res < 0 ? 1 : 0;
  s.Z = res === 0 ? 1 : 0;
  // Carry = no borrow (unsigned a >= unsigned b)
  s.C = ((a32 >>> 0) >= (b32 >>> 0)) ? 1 : 0;
  // Overflow: inputs have different signs AND result sign differs from a
  s.V = (((a32 ^ b32) & (a32 ^ res)) >>> 31) & 1;
}

function setAddFlags(s: PitrexArm32State, a: number, b: number): void {
  const a32 = a | 0, b32 = b | 0;
  const res = (a32 + b32) | 0;
  s.N = res < 0 ? 1 : 0;
  s.Z = res === 0 ? 1 : 0;
  // Carry on addition: unsigned overflow
  s.C = ((a32 >>> 0) + (b32 >>> 0)) > 0xFFFFFFFF ? 1 : 0;
  // Overflow: same-sign inputs, different-sign result
  s.V = ((~(a32 ^ b32) & (a32 ^ res)) >>> 31) & 1;
}

// ---------------------------------------------------------------------------
// Condition evaluation
// ---------------------------------------------------------------------------

function condPasses(s: PitrexArm32State, cond: string | undefined): boolean {
  if (!cond || cond === 'al') return true;
  switch (cond) {
    case 'eq': return s.Z === 1;
    case 'ne': return s.Z === 0;
    case 'cs': case 'hs': return s.C === 1;
    case 'cc': case 'lo': return s.C === 0;
    case 'mi': return s.N === 1;
    case 'pl': return s.N === 0;
    case 'vs': return s.V === 1;
    case 'vc': return s.V === 0;
    case 'hi': return s.C === 1 && s.Z === 0;
    case 'ls': return s.C === 0 || s.Z === 1;
    case 'ge': return s.N === s.V;
    case 'lt': return s.N !== s.V;
    case 'gt': return s.Z === 0 && s.N === s.V;
    case 'le': return s.Z === 1 || s.N !== s.V;
    default:   return true;
  }
}

// ---------------------------------------------------------------------------
// Operand parsing helpers
// ---------------------------------------------------------------------------

/** Parse a register name to its index (0-15). */
function regIdx(s: string): number {
  const t = s.trim().toLowerCase();
  if (t === 'sp')  return 13;
  if (t === 'lr')  return 14;
  if (t === 'pc')  return 15;
  if (t === 'r12' || t === 'ip') return 12; // r12 = intra-procedure scratch (ip)
  if (t === 'r11' || t === 'fp') return 11; // r11 = frame pointer (fp) in gcc output
  if (t === 'r10' || t === 'sl') return 10; // r10 = stack limit (sl)
  if (t.startsWith('r')) {
    const n = parseInt(t.slice(1), 10);
    if (!isNaN(n)) return n;
  }
  return -1;
}

/** Parse an immediate value string ("#N" or "#0xN"). */
function parseImm(s: string): number {
  const t = s.trim().replace(/^#/, '');
  if (t.startsWith('0x') || t.startsWith('0X')) return parseInt(t.slice(2), 16);
  if (t.startsWith('-0x') || t.startsWith('-0X')) return -parseInt(t.slice(3), 16);
  return parseInt(t, 10);
}

/**
 * Resolve a "flexible second operand" which can be:
 *   rN
 *   rN, lsl #N
 *   rN, lsr #N
 *   rN, asr #N
 *   #N (immediate)
 */
function resolveFlexOp(s: PitrexArm32State, operands: string[], startIdx: number): number {
  const tok = operands[startIdx]?.trim() ?? '';
  if (!tok) return 0;

  // Immediate
  if (tok.startsWith('#')) return parseImm(tok);

  // Register — check if there is a shift suffix
  const rn = regIdx(tok);
  if (rn < 0) return 0;
  const val = getReg(s, rn);

  // Look for optional shift operand (next token might be "lsl #N" etc.)
  const shift = operands[startIdx + 1]?.trim().toLowerCase();
  if (shift) {
    const shiftVal = parseImm(shift.split(/\s+/)[1] ?? '#0');
    if (shift.startsWith('lsl')) return (val << shiftVal) | 0;
    if (shift.startsWith('lsr')) return (val >>> shiftVal) | 0;
    if (shift.startsWith('asr')) return (val >> shiftVal) | 0;
    if (shift.startsWith('ror')) return (((val >>> shiftVal) | (val << (32 - shiftVal))) | 0);
  }

  // Also handle "rN, lsl #N" encoded as a SINGLE operand like "r4, lsl #1"
  // (this happens when the original asm has "mov r6, r4, lsl #1")
  return val;
}

/**
 * Resolve the value of a single operand token:
 *   rN              → register value
 *   #N              → immediate
 *   rN, lsl #N      → NOT handled here — use resolveFlexOp instead
 */
function resolveOp(s: PitrexArm32State, tok: string): number {
  tok = tok.trim();
  if (!tok) return 0;
  if (tok.startsWith('#')) return parseImm(tok);
  const r = regIdx(tok);
  if (r >= 0) return getReg(s, r);
  return 0;
}

/**
 * Parse a memory operand like "[r1]", "[sp, #8]", "[r4], #2".
 *
 * splitOperands cuts on top-level commas, so post-increment forms come in as
 * TWO tokens: ["[r4]", "#2"]. Pass the remaining tail as `extra` so we can
 * detect the post-inc immediate.
 */
function parseMemOp(
  s: PitrexArm32State,
  tok: string,
  extra?: string,
): { addr: number; postIncReg: number; postIncVal: number } {
  tok = tok.trim();

  // Inline post-increment in a single token: "[r4], #2"
  const postMatch = tok.match(/^\[(\w+)\]\s*,\s*#(-?(?:0x[\da-fA-F]+|\d+))/);
  if (postMatch) {
    const rn  = regIdx(postMatch[1]);
    const incStr = postMatch[2];
    const inc = incStr.startsWith('0x') ? parseInt(incStr.slice(2), 16) : parseInt(incStr, 10);
    return { addr: getReg(s, rn), postIncReg: rn, postIncVal: inc };
  }
  // Offset: "[r1, #8]", with optional PRE-INDEX WRITEBACK "[r1, #8]!".
  // Writeback: effective address = rn+imm AND rn is updated to rn+imm. gcc emits
  // this for pointer-advance loops — libvpy's font renderer walks the glyph
  // stream with `ldrsb r3, [r4, #3]!` and the string with `ldrb r3, [r7, #1]!`,
  // and pushes with `str rX, [sp, #-4]!`. Reuse the post-inc machinery (applied
  // to the OLD rn) so rn ends at rn+imm. Without the writeback the pointers never
  // advance and font_draw_string spins forever (~2.4M segments/frame).
  const offMatch = tok.match(/^\[(\w+)\s*,\s*#(-?(?:0x[\da-fA-F]+|\d+))\](!?)/);
  if (offMatch) {
    const rn  = regIdx(offMatch[1]);
    const off = offMatch[2].startsWith('0x') ? parseInt(offMatch[2].slice(2), 16) : parseInt(offMatch[2], 10);
    const addr = (getReg(s, rn) + off) | 0;
    if (offMatch[3] === '!') return { addr, postIncReg: rn, postIncVal: off };
    return { addr, postIncReg: -1, postIncVal: 0 };
  }
  // Scaled register offset: "[r3, r2, lsl #1]" (also lsr/asr). gcc emits this
  // for indexed byte/word array access (e.g. libvpy's music sequencer next-delay
  // read `ldrb r3, [r3, r2, lsl #1]` and level/font table indexing). Must be
  // tried BEFORE the plain register-offset case, whose regex would otherwise
  // match the "[rn, rm" prefix and silently drop the shift.
  const scaledMatch = tok.match(/^\[(\w+)\s*,\s*(\w+)\s*,\s*(lsl|lsr|asr)\s*#(\d+)\]/i);
  if (scaledMatch) {
    const rn = regIdx(scaledMatch[1]);
    const rm = regIdx(scaledMatch[2]);
    const shOp = scaledMatch[3].toLowerCase();
    const shAmt = parseInt(scaledMatch[4], 10);
    const rmVal = getReg(s, rm);
    let idx: number;
    if (shOp === 'lsl') idx = (rmVal << shAmt) | 0;
    else if (shOp === 'lsr') idx = (rmVal >>> shAmt) | 0;
    else idx = (rmVal >> shAmt) | 0;   // asr
    return { addr: (getReg(s, rn) + idx) | 0, postIncReg: -1, postIncVal: 0 };
  }
  // Register offset: "[r4, r5]"
  const regOffMatch = tok.match(/^\[(\w+)\s*,\s*(\w+)\]/);
  if (regOffMatch) {
    const rn = regIdx(regOffMatch[1]);
    const rm = regIdx(regOffMatch[2]);
    return { addr: (getReg(s, rn) + getReg(s, rm)) | 0, postIncReg: -1, postIncVal: 0 };
  }
  // Simple: "[r1]" — possibly followed by a post-inc immediate split into the
  // next operand token (e.g. ldrb r0, [r4], #1 → ["[r4]", "#1"]).
  const simpleMatch = tok.match(/^\[(\w+)\]\s*$/);
  if (simpleMatch) {
    const rn = regIdx(simpleMatch[1]);
    if (extra) {
      const incTok = extra.trim();
      const m = incTok.match(/^#(-?(?:0x[\da-fA-F]+|\d+))$/);
      if (m) {
        const inc = m[1].startsWith('0x') ? parseInt(m[1].slice(2), 16) : parseInt(m[1], 10);
        return { addr: getReg(s, rn), postIncReg: rn, postIncVal: inc };
      }
    }
    return { addr: getReg(s, rn), postIncReg: -1, postIncVal: 0 };
  }
  return { addr: 0, postIncReg: -1, postIncVal: 0 };
}

/** Parse a register list "{r4, r5, r6, lr, pc}" or with ranges "{r4-r11, lr}"
 *  → sorted list of register indices. */
function parseRegList(tok: string): number[] {
  const inner = tok.replace(/[{}]/g, '').trim();
  const parts = inner.split(',').map(p => p.trim()).filter(Boolean);
  const list: number[] = [];
  for (const p of parts) {
    // Range form: "r4-r11" — expand to r4, r5, ..., r11
    const rangeMatch = p.match(/^([rR]\d+|sp|lr|pc|ip)\s*-\s*([rR]\d+|sp|lr|pc|ip)$/);
    if (rangeMatch) {
      const lo = regIdx(rangeMatch[1]);
      const hi = regIdx(rangeMatch[2]);
      if (lo >= 0 && hi >= 0 && lo <= hi) {
        for (let r = lo; r <= hi; r++) list.push(r);
        continue;
      }
    }
    const r = regIdx(p);
    if (r >= 0) list.push(r);
  }
  list.sort((a, b) => a - b);
  return list;
}

// ---------------------------------------------------------------------------
// Branch label resolution
// ---------------------------------------------------------------------------

/**
 * Resolve a branch target to an instruction index.
 * Handles:
 *   - Named labels (in parsed.labels)
 *   - Numeric forward references: "1f" (next occurrence of label 1 after pc)
 *   - Numeric backward references: "1b"
 */
function resolveBranchTarget(s: PitrexArm32State, target: string): number | null {
  target = target.trim();

  // Numeric forward reference: "1f", "2f", etc.
  const fwdMatch = target.match(/^(\d+)f$/);
  if (fwdMatch) {
    const n = parseInt(fwdMatch[1], 10);
    for (const nl of s.parsed.numericLabels) {
      if (nl.n === n && nl.idx > s.pc) return nl.idx;
    }
    return null;
  }

  // Numeric backward reference: "1b", "2b"
  const bwdMatch = target.match(/^(\d+)b$/);
  if (bwdMatch) {
    const n = parseInt(bwdMatch[1], 10);
    let best: number | null = null;
    for (const nl of s.parsed.numericLabels) {
      if (nl.n === n && nl.idx <= s.pc) {
        best = nl.idx;
      }
    }
    return best;
  }

  // Named label
  const idx = s.parsed.labels.get(target);
  return idx !== undefined ? idx : null;
}

// ---------------------------------------------------------------------------
// =SYMBOL resolution
// ---------------------------------------------------------------------------

function resolveLdrLiteral(s: PitrexArm32State, operand: string): number {
  // operand is like "=0xNNN", "=921600", "=-57", "=SYMBOL"
  const inner = operand.startsWith('=') ? operand.slice(1) : operand;

  // Pure number
  const v = (() => {
    if (inner.startsWith('0x') || inner.startsWith('0X'))
      return parseInt(inner.slice(2), 16);
    if (inner.startsWith('-0x') || inner.startsWith('-0X'))
      return -parseInt(inner.slice(3), 16);
    if (/^-?\d+$/.test(inner))
      return parseInt(inner, 10);
    return null;
  })();
  if (v !== null) return v;

  // Symbol lookup
  const r = resolveSymbol(inner, s.parsed);
  if (r !== null) return r;

  // Fallback: try code labels (for forward branches used as data labels)
  const idx = s.parsed.labels.get(inner);
  if (idx !== undefined) {
    // Return a fake "code address" in a high region
    // For string labels the parser already put them in symbols, so this is a fallback
    return 0xF8000000 + idx;
  }

  console.warn(`[PitrexArm32] unresolved ldr literal: ${inner}`);
  return 0;
}

/**
 * Resolve a movw/movt operand to its 16-bit half-word value.
 *
 * gcc builds 32-bit constants and symbol addresses with a movw/movt pair:
 *   movw rd, #imm16                 → low half is imm16
 *   movt rd, #imm16                 → high half is imm16 (note: no `#` sometimes)
 *   movw rd, #:lower16:SYMBOL       → low half is (addr(SYMBOL) & 0xFFFF)
 *   movt rd, #:upper16:SYMBOL       → high half is ((addr(SYMBOL) >> 16) & 0xFFFF)
 * This returns the already-extracted 16-bit half for whichever form is present,
 * so the caller just places it in the low (movw) or high (movt) half of rd.
 */
function resolveMovHalf(s: PitrexArm32State, tokRaw: string): number {
  const tok = tokRaw.trim().replace(/^#/, '');
  const lower = tok.match(/^:lower16:(.+)$/);
  if (lower) {
    const v = resolveSymbol(lower[1].trim(), s.parsed);
    return (v === null ? 0 : v) & 0xFFFF;
  }
  const upper = tok.match(/^:upper16:(.+)$/);
  if (upper) {
    const v = resolveSymbol(upper[1].trim(), s.parsed);
    return ((v === null ? 0 : v) >>> 16) & 0xFFFF;
  }
  // Plain immediate (gcc writes movw with `#`, movt sometimes without).
  return parseImm('#' + tok) & 0xFFFF;
}

// ---------------------------------------------------------------------------
// SDK Stubs — called when bl reaches an external/undefined symbol
// ---------------------------------------------------------------------------

type SdkStub = (s: PitrexArm32State) => void;

// ---------------------------------------------------------------------------
// Vectrex vector font — stroke data (matches RP2350 vpy_print_text font)
// Keys: ASCII code.  Values: flat [cmd, gx, gy, ...] where
//   cmd=1 → move to (gx,gy),  cmd=2 → draw to (gx,gy)
//   grid: gx∈[0..4], gy∈[0..6]  (gy=0=bottom, gy=6=top)
// ---------------------------------------------------------------------------
const VECTREX_FONT: Record<number, number[]> = {
  33:  [1,2,6, 2,2,2, 1,2,0, 2,2,1],       // !
  34:  [1,1,5, 2,1,6, 1,3,5, 2,3,6],        // "
  43:  [1,2,1, 2,2,5, 1,0,3, 2,4,3],        // +
  44:  [1,2,1, 2,1,0],                       // ,
  45:  [1,0,3, 2,4,3],                       // -
  46:  [1,1,0, 2,2,0],                       // .
  47:  [1,0,0, 2,4,6],                       // /
  48:  [1,0,0, 2,4,0, 2,4,6, 2,0,6, 2,0,0], // 0
  49:  [1,2,0, 2,2,6],                       // 1
  50:  [1,0,6, 2,4,6, 2,4,3, 2,0,3, 2,0,0, 2,4,0], // 2
  51:  [1,0,6, 2,4,6, 2,4,0, 2,0,0, 1,4,3, 2,1,3], // 3
  52:  [1,0,6, 2,0,3, 2,4,3, 1,4,6, 2,4,0], // 4
  53:  [1,4,6, 2,0,6, 2,0,3, 2,4,3, 2,4,0, 2,0,0], // 5
  54:  [1,4,6, 2,0,6, 2,0,0, 2,4,0, 2,4,3, 2,0,3], // 6
  55:  [1,0,6, 2,4,6, 2,2,0],               // 7
  56:  [1,0,0, 2,4,0, 2,4,6, 2,0,6, 2,0,0, 1,0,3, 2,4,3], // 8
  57:  [1,4,0, 2,4,6, 2,0,6, 2,0,3, 2,4,3], // 9
  58:  [1,2,1, 2,2,2, 1,2,4, 2,2,5],        // :
  59:  [1,2,4, 2,2,5, 1,2,1, 2,1,0],        // ;
  60:  [1,3,6, 2,0,3, 2,3,0],               // <
  61:  [1,0,4, 2,4,4, 1,0,2, 2,4,2],        // =
  62:  [1,1,6, 2,4,3, 2,1,0],               // >
  63:  [1,0,6, 2,4,6, 2,4,4, 2,2,3, 1,2,1, 2,2,2], // ?
  65:  [1,0,0, 2,2,6, 2,4,0, 1,0,3, 2,4,3], // A
  66:  [1,0,0, 2,0,6, 2,3,6, 2,3,3, 2,0,3, 2,3,3, 2,3,0, 2,0,0], // B
  67:  [1,4,6, 2,0,6, 2,0,0, 2,4,0],        // C
  68:  [1,0,0, 2,0,6, 2,3,6, 2,4,5, 2,4,1, 2,3,0, 2,0,0], // D
  69:  [1,4,0, 2,0,0, 2,0,6, 2,4,6, 1,0,3, 2,3,3], // E
  70:  [1,0,0, 2,0,6, 2,4,6, 1,0,3, 2,3,3], // F
  71:  [1,4,6, 2,0,6, 2,0,0, 2,4,0, 2,4,3, 2,2,3], // G
  72:  [1,0,0, 2,0,6, 1,4,0, 2,4,6, 1,0,3, 2,4,3], // H
  73:  [1,1,0, 2,3,0, 1,2,0, 2,2,6, 1,1,6, 2,3,6], // I
  74:  [1,0,1, 2,1,0, 2,4,0, 2,4,6, 1,1,6, 2,3,6], // J
  75:  [1,0,0, 2,0,6, 1,0,3, 2,4,6, 1,0,3, 2,4,0], // K
  76:  [1,0,6, 2,0,0, 2,4,0],               // L
  77:  [1,0,0, 2,0,6, 2,2,3, 2,4,6, 2,4,0], // M
  78:  [1,0,0, 2,0,6, 2,4,0, 2,4,6],        // N
  79:  [1,0,0, 2,4,0, 2,4,6, 2,0,6, 2,0,0], // O
  80:  [1,0,0, 2,0,6, 2,3,6, 2,4,5, 2,4,4, 2,3,3, 2,0,3], // P
  81:  [1,0,0, 2,4,0, 2,4,6, 2,0,6, 2,0,0, 1,3,1, 2,4,0], // Q
  82:  [1,0,0, 2,0,6, 2,3,6, 2,4,5, 2,4,4, 2,3,3, 2,0,3, 2,4,0], // R
  83:  [1,4,6, 2,0,6, 2,0,3, 2,4,3, 2,4,0, 2,0,0], // S
  84:  [1,0,6, 2,4,6, 1,2,6, 2,2,0],        // T
  85:  [1,0,6, 2,0,0, 2,4,0, 2,4,6],        // U
  86:  [1,0,6, 2,2,0, 2,4,6],               // V
  87:  [1,0,6, 2,1,0, 2,2,3, 2,3,0, 2,4,6], // W
  88:  [1,0,0, 2,4,6, 1,0,6, 2,4,0],        // X
  89:  [1,0,6, 2,2,3, 2,4,6, 1,2,3, 2,2,0], // Y
  90:  [1,0,6, 2,4,6, 2,0,0, 2,4,0],        // Z
};
// Lowercase a-z map to uppercase A-Z glyphs
for (let c = 97; c <= 122; c++) VECTREX_FONT[c] = VECTREX_FONT[c - 32];

/**
 * Render a text string as vector segments at VPy coordinates (x, y).
 * scale: emulator glyph scale (textSize * 0.6; default textSize=5 → scale=3.0).
 * glyph grid: gx∈[0..4], gy∈[0..6], scale gives size in VPy units.
 * Coordinates multiplied by PITREX_COORD_SCALE to match v_directDraw32.
 */
const PITREX_COORD_SCALE = 128;  // must match pitrex_draw_line ×100 multiplier

function drawTextAsSegments(
  s: PitrexArm32State, x: number, y: number, text: string, scale: number,
): void {
  if (scale <= 0) scale = 3;
  const intensity = 100;
  let curX = x * PITREX_COORD_SCALE;
  const baseY = y * PITREX_COORD_SCALE;
  // Use float division so scale=3.0 gives exact 10.5 VPy per char (matching M6809 BIOS advance).
  const charAdv = (7 * scale / 2) * PITREX_COORD_SCALE;
  // y is top of character (M6809 BIOS convention). Glyphs have y=6 at top, y=0 at bottom.
  const topOffset = (6 * scale / 2) * PITREX_COORD_SCALE;
  for (const rawCh of text) {
    const cc = rawCh.charCodeAt(0);
    if (cc === 0 || cc >= 0x80) break;
    const glyph = VECTREX_FONT[cc];
    if (glyph) {
      let penX = 0, penY = 0;
      for (let i = 0; i < glyph.length; i += 3) {
        const cmd = glyph[i];
        const ax  = curX + (glyph[i + 1] * scale / 2) * PITREX_COORD_SCALE;
        const ay  = baseY - topOffset + (glyph[i + 2] * scale / 2) * PITREX_COORD_SCALE;
        if (cmd === 2) {
          s.segments.push({ x0: penX, y0: penY, x1: ax, y1: ay, intensity });
        }
        penX = ax; penY = ay;
      }
    }
    curX += charAdv;
  }
}

const SDK_STUBS: Record<string, SdkStub> = {
  'v_WaitRecal': (s) => {
    s.waitRecalCalled = true;
  },

  // PLAY_SAMPLE("name") lowers to `pitrex_play_sample(r0=_NAME_SMP)`. On HW that
  // symbol is a no-op stub; here we hand the asset pointer to PitrexCore, which
  // reads the .vsmp header from emulator memory and plays it via Web Audio.
  'pitrex_play_sample': (s) => {
    s.playSample?.(s.regs[0] >>> 0, (addr) => memRead8(s, addr));
  },

  'v_directDraw32': (s) => {
    // r0=x0, r1=y0, r2=x1, r3=y1, [sp]=brightness
    // Coordinates are in Vectrex Y+ = up convention (x*127, y*127 + MOVE offset).
    // The IDE EmulatorPanel renders with `cy - seg.y * scaleY`, so Vectrex Y+up is
    // displayed correctly WITHOUT any negation here.
    const x0  = s.regs[0];
    const y0  = s.regs[1];
    const x1  = s.regs[2];
    const y1  = s.regs[3];
    const bri = memRead32(s, s.regs[SP]);
    s.segments.push({ x0, y0, x1, y1, intensity: bri & 0x7F });
  },

  'v_drawBezierCubic': (s) => {
    // r0=x0, r1=y0, r2=cx0, r3=cy0
    // [sp+0]=cx1, [sp+4]=cy1, [sp+8]=x1, [sp+12]=y1, [sp+16]=steps, [sp+20]=brightness
    const SCALE = 127;
    const sp = s.regs[SP];
    const x0  = (s.regs[0] | 0) * SCALE;
    const y0  = (s.regs[1] | 0) * SCALE;
    const cx0 = (s.regs[2] | 0) * SCALE;
    const cy0 = (s.regs[3] | 0) * SCALE;
    const cx1 = (memRead32(s, sp +  0) | 0) * SCALE;
    const cy1 = (memRead32(s, sp +  4) | 0) * SCALE;
    const x1  = (memRead32(s, sp +  8) | 0) * SCALE;
    const y1  = (memRead32(s, sp + 12) | 0) * SCALE;
    const n   = Math.min(Math.max(memRead32(s, sp + 16) | 0, 2), 64);
    const bri = memRead32(s, sp + 20) & 0x7F;
    if (bri === 0) return;
    const lerp = (a: number, b: number, i: number) => Math.trunc(((n - i) * a + i * b) / n);
    const cubic = (p0: number, p1: number, p2: number, p3: number, i: number) => {
      const q0 = lerp(p0, p1, i), q1 = lerp(p1, p2, i), q2 = lerp(p2, p3, i);
      return lerp(lerp(q0, q1, i), lerp(q1, q2, i), i);
    };
    let px = x0, py = y0;
    for (let i = 1; i <= n; i++) {
      const nx = cubic(x0, cx0, cx1, x1, i);
      const ny = cubic(y0, cy0, cy1, y1, i);
      s.segments.push({ x0: px, y0: py, x1: nx, y1: ny, intensity: bri });
      px = nx; py = ny;
    }
  },

  'v_drawBezierQuad': (s) => {
    // r0=x0, r1=y0, r2=cx, r3=cy
    // [sp+0]=x1, [sp+4]=y1, [sp+8]=steps, [sp+12]=brightness
    const SCALE = 127;
    const sp = s.regs[SP];
    const x0 = (s.regs[0] | 0) * SCALE;
    const y0 = (s.regs[1] | 0) * SCALE;
    const cx = (s.regs[2] | 0) * SCALE;
    const cy = (s.regs[3] | 0) * SCALE;
    const x1 = (memRead32(s, sp +  0) | 0) * SCALE;
    const y1 = (memRead32(s, sp +  4) | 0) * SCALE;
    const n  = Math.min(Math.max(memRead32(s, sp +  8) | 0, 2), 64);
    const bri = memRead32(s, sp + 12) & 0x7F;
    if (bri === 0) return;
    const lerp = (a: number, b: number, i: number) => Math.trunc(((n - i) * a + i * b) / n);
    const quad = (p0: number, p1: number, p2: number, i: number) =>
      lerp(lerp(p0, p1, i), lerp(p1, p2, i), i);
    let px = x0, py = y0;
    for (let i = 1; i <= n; i++) {
      const nx = quad(x0, cx, x1, i);
      const ny = quad(y0, cy, y1, i);
      s.segments.push({ x0: px, y0: py, x1: nx, y1: ny, intensity: bri });
      px = nx; py = ny;
    }
  },

  'v_setBrightness':         () => {},
  'v_setScale':              () => {}, // scale is irrelevant in emulator (coord mapping uses PITREX_MAX_X/Y)
  'v_directMove32':          () => {}, // beam reset — no-op in emulator (drawTextAsSegments is absolute)
  'v_init':                  () => {},
  'v_setRefresh':            () => {},
  'vectrexinit':             () => {},
  'v_readButtons':           (s) => {
    // currentButtonState packs both players: bits 0-3 = P1, bits 4-7 = P2
    // (active-high in our model). pitrex_j2_btn* uses bits 4-7.
    const btnSym = s.parsed.symbols.get('currentButtonState');
    if (btnSym) {
      const packed = (s.joyButtons & 0xF) | ((s.joyButtons2 & 0xF) << 4);
      memWrite32(s, btnSym.value, packed);
    }
  },
  'v_readJoystick1Analog':   (s) => {
    // currentJoy1X/Y are int8_t (±127). Write byte-sized values; ldrsb reads them correctly.
    const xSym = s.parsed.symbols.get('currentJoy1X');
    const ySym = s.parsed.symbols.get('currentJoy1Y');
    if (xSym) memWrite32(s, xSym.value, Math.round(s.joyX));
    if (ySym) memWrite32(s, ySym.value, Math.round(s.joyY));
  },
  'v_readJoystick2Analog':   (s) => {
    const xSym = s.parsed.symbols.get('currentJoy2X');
    const ySym = s.parsed.symbols.get('currentJoy2Y');
    if (xSym) memWrite32(s, xSym.value, Math.round(s.joyX2));
    if (ySym) memWrite32(s, ySym.value, Math.round(s.joyY2));
  },
  'v_printString': (s) => {
    // v_printString(x=r0, y=r1, str=r2, textSize=r3, brightness=[sp]) — vector font.
    // Codegen sends: r0 = VPy_x * 127/128 ≈ VPy_x,  r1 = (VPy_y - 8) * 127/128 ≈ VPy_y-8.
    // drawTextAsSegments expects y = top-of-character in VPy units, so add back 8.
    // No *1.28 unscaling — drawTextAsSegments multiplies by PITREX_COORD_SCALE(128)
    // giving curX ≈ VPy_x * 127, matching v_directDraw32 circle coordinates.
    // scale factor: VPy SIZE=8 (normal) → textSize=8 should match m6809 Vec_Text_Height=-8 (~10 VPy/char).
    // rp2350 SIZE=8 → TEXT_SIZE=3 → advance=(7*3)>>1=10 VPy/char (reference).
    // For pitrex: advance = 7 * scale / 2 = 10 → scale = 20/7 at textSize=8.
    // So: scale = textSize * (20/7) / 8 = textSize * 5/14 ≈ textSize * 0.357.
    // Glyph height = 3 * scale = 3 * (8 * 5/14) = 8.57 VPy ≈ m6809 Vec_Text_Height=8 ✓
    const strPtr = s.regs[2];
    let text = '';
    for (let i = 0; i < 128; i++) {
      const ch = memRead8(s, strPtr + i);
      if (ch === 0) break;
      text += String.fromCharCode(ch);
    }
    if (text.length > 0) {
      const scale = Math.max(0.3, s.regs[3] * 5 / 14);
      drawTextAsSegments(s, s.regs[0], (s.regs[1] | 0) + 8, text, scale);
    }
  },

  'v_printStringRaster':     (s) => {
    // pitrex_print_text / pitrex_print_number call with:
    //   r0=x (VPy units), r1=y (VPy units), r2=str_ptr, r3=size
    const strPtr = s.regs[2];
    let text = '';
    for (let i = 0; i < 64; i++) {
      const ch = memRead8(s, strPtr + i);
      if (ch === 0 || ch >= 0x80) break;
      text += String.fromCharCode(ch);
    }
    if (text.length > 0) {
      drawTextAsSegments(s, s.regs[0], s.regs[1], text, s.regs[3]);
    }
  },
  'RPI_AuxUartInit':         () => {},
  'RPI_AuxUartWrite':        () => {},

  'vpy_uart_puts': (s) => {
    // r0 = pointer to null-terminated string.
    // Text-section .Lstr_* labels have fake STRING_BASE (0xF0000000+) addresses —
    // reverse-look up in symbols to get the decoded string from parsed.strings.
    // Rodata/bss strings are read byte-by-byte from s.mem.
    const ptr = s.regs[0] >>> 0;  // reinterpret Int32Array value as unsigned
    let text = '';
    if (ptr >= 0xF0000000) {
      for (const [name, sym] of s.parsed.symbols) {
        if (sym.value === ptr) { text = s.parsed.strings.get(name) ?? ''; break; }
      }
    } else {
      for (let i = 0; i < 128; i++) {
        const ch = memRead8(s, ptr + i);
        if (ch === 0) break;
        text += String.fromCharCode(ch);
      }
    }
    s.uartBuffer += text;
    let nl: number;
    while ((nl = s.uartBuffer.indexOf('\n')) >= 0) {
      const uartLine = s.uartBuffer.slice(0, nl).replace(/\r$/, '');
      if (uartLine) console.log('[UART]', uartLine);
      s.uartBuffer = s.uartBuffer.slice(nl + 1);
    }
  },

  'vpy_uart_print_int': (s) => {
    s.uartBuffer += String(s.regs[0] | 0);
  },

  'v_writePSG': (s) => {
    const reg = s.regs[0] & 0xFF;
    const val = s.regs[1] & 0xFF;
    s.psgWrite(reg, val);
  },
  // pitrex_sfx_update needs to read the current PSG mixer value to merge
  // SFX-channel bits with music channels (otherwise SFX writes 0x3B/0x1B
  // and silences music tones A/B).
  'v_readPSG': (s) => {
    const reg = s.regs[0] & 0x0F;
    s.regs[0] = s.psgRead(reg) | 0;
  },
  'v_doSound': () => {},

  '__aeabi_idiv': (s) => {
    const dividend = s.regs[0];
    const divisor  = s.regs[1];
    s.regs[0] = divisor !== 0 ? (Math.trunc(dividend / divisor) | 0) : 0;
  },

  '__aeabi_uidiv': (s) => {
    // Unsigned divide — used by SAMPLE_POS (wall-clock frame index). Without
    // this stub the bl is a silent no-op and SAMPLE_POS returns garbage.
    const dividend = s.regs[0] >>> 0;
    const divisor  = s.regs[1] >>> 0;
    s.regs[0] = divisor !== 0 ? (Math.floor(dividend / divisor) | 0) : 0;
  },

  '__aeabi_uidivmod': (s) => {
    const dividend = s.regs[0] >>> 0;
    const divisor  = s.regs[1] >>> 0;
    if (divisor !== 0) {
      const q = Math.floor(dividend / divisor);
      s.regs[0] = q | 0;
      s.regs[1] = (dividend - q * divisor) | 0;
    } else {
      s.regs[0] = 0;
      s.regs[1] = 0;
    }
  },

  '__aeabi_idivmod': (s) => {
    const dividend = s.regs[0];
    const divisor  = s.regs[1];
    if (divisor !== 0) {
      const q = Math.trunc(dividend / divisor);
      const r = dividend - q * divisor;
      s.regs[0] = q | 0;
      s.regs[1] = r | 0;
    } else {
      s.regs[0] = 0;
      s.regs[1] = 0;
    }
  },
};

// ---------------------------------------------------------------------------
// Single-instruction executor
// ---------------------------------------------------------------------------

/**
 * Execute one instruction. Returns false if we should stop (waitRecal or
 * PC out of range).
 */
function executeOne(s: PitrexArm32State): boolean {
  if (s.pc < 0 || s.pc >= s.parsed.instructions.length) return false;

  const instr = s.parsed.instructions[s.pc];
  s.pc++;  // advance PC before execution (so branches override it)

  const { op, cond, operands } = instr;

  // Check condition
  if (!condPasses(s, cond)) return true;

  switch (op) {
    // ── No-op / IT block ────────────────────────────────────────────────
    case 'it': case 'ite': case 'itt': case 'ittee': case 'itete':
    case 'nop': case 'wfe':
      break;

    // ── WFI (frame sync for rp2350 — treated as wait-recal equivalent) ──
    case 'wfi':
      s.waitRecalCalled = true;
      break;

    // ── MOV ─────────────────────────────────────────────────────────────
    case 'mov': case 'movs': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      // Check for shifted-register form: "mov r6, r4, lsl #1"
      if (operands.length >= 3) {
        const rn = regIdx(operands[1] ?? '');
        if (rn >= 0) {
          const shiftOp = (operands[2] ?? '').trim().toLowerCase();
          const shiftAmt = parseImm(shiftOp.split(/\s+/)[1] ?? '#0');
          let val = getReg(s, rn);
          if (shiftOp.startsWith('lsl')) val = (val << shiftAmt) | 0;
          else if (shiftOp.startsWith('lsr')) val = (val >>> shiftAmt) | 0;
          else if (shiftOp.startsWith('asr')) val = (val >> shiftAmt) | 0;
          setReg(s, rd, val);
          if (op === 'movs') setNZFlags(s, val);
          break;
        }
      }
      const movVal = resolveOp(s, operands[1] ?? '#0');
      setReg(s, rd, movVal);
      if (op === 'movs') setNZFlags(s, movVal | 0);
      break;
    }

    // ── MVN ─────────────────────────────────────────────────────────────
    case 'mvn': case 'mvns': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      setReg(s, rd, (~resolveOp(s, operands[1] ?? '#0')) | 0);
      break;
    }

    // ── MOVW (load 16-bit immediate / :lower16: of a symbol) ─────────────
    case 'movw': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      // movw clears the top 16 bits (rd = imm16 or lower16 of a symbol addr).
      setReg(s, rd, resolveMovHalf(s, operands[1] ?? '#0'));
      break;
    }

    // ── MOVT (set top 16 bits / :upper16: of a symbol) ──────────────────
    case 'movt': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const hi = resolveMovHalf(s, operands[1] ?? '#0');
      setReg(s, rd, ((getReg(s, rd) & 0xFFFF) | (hi << 16)) | 0);
      break;
    }

    // ── SMULL / UMULL (32×32 → 64-bit multiply into RdLo:RdHi) ──────────
    case 'smull': case 'umull': {
      const rdLo = regIdx(operands[0] ?? '');
      const rdHi = regIdx(operands[1] ?? '');
      const rn   = regIdx(operands[2] ?? '');
      const rm   = regIdx(operands[3] ?? '');
      if (rdLo < 0 || rdHi < 0 || rn < 0 || rm < 0) break;
      // BigInt gives an exact 64-bit product; signed vs unsigned differ only in
      // how the 32-bit register values are reinterpreted before multiplying.
      const a = op === 'smull' ? BigInt(getReg(s, rn)) : BigInt(getReg(s, rn) >>> 0);
      const b = op === 'smull' ? BigInt(getReg(s, rm)) : BigInt(getReg(s, rm) >>> 0);
      const prod = a * b;
      setReg(s, rdLo, Number(prod & 0xFFFFFFFFn) | 0);
      setReg(s, rdHi, Number((prod >> 32n) & 0xFFFFFFFFn) | 0);
      break;
    }

    // ── MLS (multiply-subtract: rd = ra - rn*rm) ────────────────────────
    case 'mls': {
      const rd = regIdx(operands[0] ?? '');
      const rn = regIdx(operands[1] ?? '');
      const rm = regIdx(operands[2] ?? '');
      const ra = regIdx(operands[3] ?? '');
      if (rd < 0 || rn < 0 || rm < 0 || ra < 0) break;
      setReg(s, rd, (getReg(s, ra) - Math.imul(getReg(s, rn), getReg(s, rm))) | 0);
      break;
    }

    // ── UBFX (unsigned bitfield extract: rd = (rn >> lsb) & mask) ───────
    case 'ubfx': {
      const rd  = regIdx(operands[0] ?? '');
      const rn  = regIdx(operands[1] ?? '');
      if (rd < 0 || rn < 0) break;
      const lsb   = parseImm(operands[2] ?? '#0') & 0x1F;
      const width = parseImm(operands[3] ?? '#1') & 0x3F;
      const mask  = width >= 32 ? 0xFFFFFFFF : ((1 << width) - 1);
      setReg(s, rd, ((getReg(s, rn) >>> lsb) & mask) | 0);
      break;
    }

    // ── SDIV / UDIV (hardware integer divide, armv8) ────────────────────
    case 'sdiv': case 'udiv': {
      const rd = regIdx(operands[0] ?? '');
      const rn = regIdx(operands[1] ?? '');
      const rm = regIdx(operands[2] ?? '');
      if (rd < 0 || rn < 0 || rm < 0) break;
      const divisor = getReg(s, rm);
      if (divisor === 0) { setReg(s, rd, 0); break; }  // ARMv8: divide-by-zero → 0
      if (op === 'sdiv') {
        setReg(s, rd, Math.trunc(getReg(s, rn) / divisor) | 0);
      } else {
        setReg(s, rd, Math.floor((getReg(s, rn) >>> 0) / (divisor >>> 0)) | 0);
      }
      break;
    }

    // ── LDRD / STRD (load/store two consecutive registers) ──────────────
    // Syntax used by gcc: "ldrd r2, [r4, #8]" → r2 = [addr], r3 = [addr+4]
    // (the second register is implicitly Rt+1). The optional explicit-Rt2
    // form "ldrd r2, r3, [r4, #8]" is handled by detecting a bare register in
    // operands[1].
    case 'ldrd': case 'strd': {
      const rt = regIdx(operands[0] ?? '');
      if (rt < 0) break;
      let memTok = operands[1] ?? '';
      let extra  = operands[2];
      let rt2 = rt + 1;
      if (!memTok.trim().startsWith('[')) {
        // Explicit second register form.
        const r2 = regIdx(memTok);
        if (r2 >= 0) rt2 = r2;
        memTok = operands[2] ?? '';
        extra  = operands[3];
      }
      const { addr, postIncReg, postIncVal } = parseMemOp(s, memTok, extra);
      if (op === 'ldrd') {
        setReg(s, rt,  memRead32(s, addr));
        setReg(s, rt2, memRead32(s, (addr + 4) | 0));
      } else {
        memWrite32(s, addr,        getReg(s, rt));
        memWrite32(s, (addr + 4) | 0, getReg(s, rt2));
      }
      if (postIncReg >= 0) s.regs[postIncReg] = (s.regs[postIncReg] + postIncVal) | 0;
      break;
    }

    // ── LDR (various forms) ─────────────────────────────────────────────
    case 'ldr': case 'ldrs': {
      const rd   = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const src  = (operands[1] ?? '').trim();
      if (src.startsWith('=')) {
        // Literal pool load
        setReg(s, rd, resolveLdrLiteral(s, src));
      } else if (src.startsWith('[')) {
        const { addr, postIncReg, postIncVal } = parseMemOp(s, src, operands[2]);
        setReg(s, rd, memRead32(s, addr));
        if (postIncReg >= 0) s.regs[postIncReg] = (s.regs[postIncReg] + postIncVal) | 0;
      }
      break;
    }

    case 'ldrh': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const { addr, postIncReg, postIncVal } = parseMemOp(s, operands[1] ?? '', operands[2]);
      setReg(s, rd, memRead16(s, addr));  // zero-extended
      if (postIncReg >= 0) s.regs[postIncReg] = (s.regs[postIncReg] + postIncVal) | 0;
      break;
    }

    case 'ldrsh': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const { addr, postIncReg, postIncVal } = parseMemOp(s, operands[1] ?? '', operands[2]);
      const raw = memRead16(s, addr);
      setReg(s, rd, ((raw << 16) >> 16));  // sign-extend 16→32
      if (postIncReg >= 0) s.regs[postIncReg] = (s.regs[postIncReg] + postIncVal) | 0;
      break;
    }

    case 'ldrb': case 'ldrsb': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const { addr, postIncReg, postIncVal } = parseMemOp(s, operands[1] ?? '', operands[2]);
      let raw = memRead8(s, addr);
      if (op === 'ldrsb') raw = ((raw << 24) >> 24);  // sign-extend
      setReg(s, rd, raw);
      if (postIncReg >= 0) s.regs[postIncReg] = (s.regs[postIncReg] + postIncVal) | 0;
      break;
    }

    // ── STR ─────────────────────────────────────────────────────────────
    case 'str': case 'strs': {
      const rs  = regIdx(operands[0] ?? '');
      if (rs < 0) break;
      const { addr, postIncReg, postIncVal } = parseMemOp(s, operands[1] ?? '', operands[2]);
      memWrite32(s, addr, getReg(s, rs));
      if (postIncReg >= 0) s.regs[postIncReg] = (s.regs[postIncReg] + postIncVal) | 0;
      break;
    }

    case 'strh': {
      const rs = regIdx(operands[0] ?? '');
      if (rs < 0) break;
      const { addr, postIncReg, postIncVal } = parseMemOp(s, operands[1] ?? '', operands[2]);
      memWrite16(s, addr, getReg(s, rs) & 0xFFFF);
      if (postIncReg >= 0) s.regs[postIncReg] = (s.regs[postIncReg] + postIncVal) | 0;
      break;
    }

    case 'strb': {
      const rs = regIdx(operands[0] ?? '');
      if (rs < 0) break;
      const { addr, postIncReg, postIncVal } = parseMemOp(s, operands[1] ?? '', operands[2]);
      memWrite8(s, addr, getReg(s, rs) & 0xFF);
      if (postIncReg >= 0) s.regs[postIncReg] = (s.regs[postIncReg] + postIncVal) | 0;
      break;
    }

    // ── ADD ─────────────────────────────────────────────────────────────
    case 'add': case 'adds': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      // Check for shifted-register third operand: "add r0, r0, r4, lsl #2"
      if (operands.length >= 4) {
        const rm = regIdx(operands[2] ?? '');
        if (rm >= 0) {
          const shiftOp = (operands[3] ?? '').trim().toLowerCase();
          const shiftAmt = parseImm(shiftOp.split(/\s+/)[1] ?? '#0');
          let rmVal = getReg(s, rm);
          if (shiftOp.startsWith('lsl')) rmVal = (rmVal << shiftAmt) | 0;
          else if (shiftOp.startsWith('lsr')) rmVal = (rmVal >>> shiftAmt) | 0;
          else if (shiftOp.startsWith('asr')) rmVal = (rmVal >> shiftAmt) | 0;
          setReg(s, rd, (a + rmVal) | 0);
          if (op === 'adds') setAddFlags(s, a, rmVal);
          break;
        }
      }
      const b = resolveFlexOp(s, operands, 2);
      setReg(s, rd, (a + b) | 0);
      if (op === 'adds') setAddFlags(s, a, b);
      break;
    }

    // ── SUB ─────────────────────────────────────────────────────────────
    case 'sub': case 'subs': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 2);
      setReg(s, rd, (a - b) | 0);
      if (op === 'subs') setCmpFlags(s, a, b);
      break;
    }

    // ── RSB (reverse subtract) ───────────────────────────────────────────
    case 'rsb': case 'rsbs': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 2);
      setReg(s, rd, (b - a) | 0);  // rd = operand3 - rn
      if (op === 'rsbs') setCmpFlags(s, b, a);
      break;
    }

    // ── NEG (pseudo-op = RSB rd, rn, #0) ────────────────────────────────
    case 'neg': case 'negs': {
      const rd = regIdx(operands[0] ?? '');
      const rn = regIdx(operands[1] ?? '');
      if (rd < 0 || rn < 0) break;
      setReg(s, rd, (-getReg(s, rn)) | 0);
      break;
    }

    // ── MUL ─────────────────────────────────────────────────────────────
    case 'mul': case 'muls': {
      // ARM32: mul rd, rn, rm  (rd cannot be rn in older ISAs, but we don't care)
      const rd = regIdx(operands[0] ?? '');
      const rn = regIdx(operands[1] ?? '');
      const rm = regIdx(operands[2] ?? '');
      if (rd < 0 || rn < 0 || rm < 0) break;
      // Use Math.imul for correct 32-bit signed multiply
      const mulRes = Math.imul(getReg(s, rn), getReg(s, rm));
      setReg(s, rd, mulRes);
      if (op === 'muls') setNZFlags(s, mulRes | 0);
      break;
    }

    // ── MLA (multiply accumulate) ────────────────────────────────────────
    case 'mla': case 'mlas': {
      // ARM32: mla rd, rn, rm, ra  →  rd = rn * rm + ra
      const rd = regIdx(operands[0] ?? '');
      const rn = regIdx(operands[1] ?? '');
      const rm = regIdx(operands[2] ?? '');
      const ra = regIdx(operands[3] ?? '');
      if (rd < 0 || rn < 0 || rm < 0 || ra < 0) break;
      const mlaRes = (Math.imul(getReg(s, rn), getReg(s, rm)) + getReg(s, ra)) | 0;
      setReg(s, rd, mlaRes);
      if (op === 'mlas') setNZFlags(s, mlaRes);
      break;
    }

    // ── AND ─────────────────────────────────────────────────────────────
    case 'and': case 'ands': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 2);
      const andRes = (a & b) | 0;
      setReg(s, rd, andRes);
      if (op === 'ands') setNZFlags(s, andRes);
      break;
    }

    // ── ORR ─────────────────────────────────────────────────────────────
    case 'orr': case 'orrs': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 2);
      const orrRes = (a | b) | 0;
      setReg(s, rd, orrRes);
      if (op === 'orrs') setNZFlags(s, orrRes);
      break;
    }

    // ── EOR ─────────────────────────────────────────────────────────────
    case 'eor': case 'eors': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 2);
      const eorRes = (a ^ b) | 0;
      setReg(s, rd, eorRes);
      if (op === 'eors') setNZFlags(s, eorRes);
      break;
    }

    // ── BIC ─────────────────────────────────────────────────────────────
    case 'bic': case 'bics': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 2);
      const bicRes = (a & ~b) | 0;
      setReg(s, rd, bicRes);
      if (op === 'bics') setNZFlags(s, bicRes);
      break;
    }

    // ── Shifts ──────────────────────────────────────────────────────────
    case 'lsl': case 'lsls': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 2) & 0x1F;
      const lslRes = (a << b) | 0;
      setReg(s, rd, lslRes);
      if (op === 'lsls') setNZFlags(s, lslRes);
      break;
    }
    case 'lsr': case 'lsrs': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 2) & 0x1F;
      const lsrRes = (a >>> b) | 0;
      setReg(s, rd, lsrRes);
      if (op === 'lsrs') setNZFlags(s, lsrRes);
      break;
    }
    case 'asr': case 'asrs': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 2) & 0x1F;
      const asrRes = (a >> b) | 0;
      setReg(s, rd, asrRes);
      if (op === 'asrs') setNZFlags(s, asrRes);
      break;
    }
    case 'ror': case 'rors': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const rn = regIdx(operands[1] ?? '');
      const a  = (rn >= 0 ? getReg(s, rn) : 0) >>> 0;
      const b  = resolveFlexOp(s, operands, 2) & 0x1F;
      setReg(s, rd, (b === 0 ? a : ((a >>> b) | (a << (32 - b)))) | 0);
      break;
    }

    // ── CMP / CMN ───────────────────────────────────────────────────────
    case 'cmp': {
      const rn = regIdx(operands[0] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 1);
      setCmpFlags(s, a, b);
      break;
    }
    case 'cmn': {
      const rn = regIdx(operands[0] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 1);
      setAddFlags(s, a, b);
      break;
    }
    case 'tst': {
      const rn = regIdx(operands[0] ?? '');
      const a  = rn >= 0 ? getReg(s, rn) : 0;
      const b  = resolveFlexOp(s, operands, 1);
      const res = (a & b) | 0;
      s.N = res < 0 ? 1 : 0;
      s.Z = res === 0 ? 1 : 0;
      break;
    }

    // ── UXTH / UXTB / SXTH / SXTB ──────────────────────────────────────
    case 'uxth': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      setReg(s, rd, getReg(s, regIdx(operands[1] ?? '')) & 0xFFFF);
      break;
    }
    case 'uxtb': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      setReg(s, rd, getReg(s, regIdx(operands[1] ?? '')) & 0xFF);
      break;
    }
    case 'sxth': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const v = getReg(s, regIdx(operands[1] ?? ''));
      setReg(s, rd, ((v & 0xFFFF) << 16) >> 16);
      break;
    }
    case 'sxtb': {
      const rd = regIdx(operands[0] ?? '');
      if (rd < 0) break;
      const v = getReg(s, regIdx(operands[1] ?? ''));
      setReg(s, rd, ((v & 0xFF) << 24) >> 24);
      break;
    }

    // ── LDMIA (load multiple, increment after) ───────────────────────────
    case 'ldmia': {
      // Syntax: ldmia Rn, {regs}  or  ldmia Rn!, {regs}  (! = writeback)
      const base0 = operands[0] ?? '';
      const writeback = base0.endsWith('!');
      const bnStr = writeback ? base0.slice(0, -1) : base0;
      const bn = regIdx(bnStr);
      if (bn < 0) break;
      const regList = parseRegList(operands[1] ?? '');
      let addr = getReg(s, bn);
      for (const r of regList) {
        setReg(s, r, memRead32(s, addr));
        addr += 4;
      }
      if (writeback) setReg(s, bn, addr);
      break;
    }

    // ── STMIA (store multiple, increment after) ──────────────────────────
    case 'stmia': {
      // Syntax: stmia Rn, {regs}  or  stmia Rn!, {regs}  (! = writeback)
      const base0 = operands[0] ?? '';
      const writeback = base0.endsWith('!');
      const bnStr = writeback ? base0.slice(0, -1) : base0;
      const bn = regIdx(bnStr);
      if (bn < 0) break;
      const regList = parseRegList(operands[1] ?? '');
      let addr = getReg(s, bn);
      for (const r of regList) {
        memWrite32(s, addr, getReg(s, r));
        addr += 4;
      }
      if (writeback) setReg(s, bn, addr);
      break;
    }

    // ── PUSH ─────────────────────────────────────────────────────────────
    case 'push': case 'stmfd': {
      const regList = parseRegList(operands[0] ?? '');
      // Push in decreasing register order (highest first, so lowest is at top of stack)
      for (let i = regList.length - 1; i >= 0; i--) {
        const r = regList[i];
        const val = r === 15 ? s.pc : (r === 14 ? s.regs[LR] : s.regs[r]);
        stackPush(s, val);
      }
      break;
    }

    // ── POP ──────────────────────────────────────────────────────────────
    case 'pop': case 'ldmfd': {
      const regList = parseRegList(operands[0] ?? '');
      // Pop in increasing register order
      for (const r of regList) {
        const val = stackPop(s);
        if (r === 15) {
          // Pop to PC = return
          s.pc = val;
        } else {
          s.regs[r] = val | 0;
        }
      }
      break;
    }

    // ── BX ───────────────────────────────────────────────────────────────
    case 'bx': {
      const rn  = regIdx(operands[0] ?? '');
      const val = rn >= 0 ? getReg(s, rn) : 0;
      if (rn === LR || rn === 15) {
        // bx lr = return
        s.pc = s.regs[LR];
      } else {
        s.pc = val;
      }
      break;
    }

    // ── BL ───────────────────────────────────────────────────────────────
    case 'bl': case 'blx': {
      const target = (operands[0] ?? '').trim();
      const returnPc = s.pc;  // already advanced past the bl instruction

      // Check SDK stubs first
      const stub = SDK_STUBS[target];
      if (stub) {
        s.regs[LR] = returnPc;
        stub(s);
        // stub doesn't change PC; after stub we continue at returnPc (already set)
        break;
      }

      // Look for the label in parsed asm
      const targetIdx = resolveBranchTarget(s, target);
      if (targetIdx !== null) {
        s.regs[LR] = returnPc;
        s.pc = targetIdx;
      } else {
        // Unknown external function — treat as no-op (SDK or user-defined not in asm)
        s.regs[LR] = returnPc;
      }
      break;
    }

    // ── B (unconditional/conditional branch) ────────────────────────────
    case 'b': {
      const target = (operands[0] ?? '').trim();
      // Tail call to an SDK builtin: gcc's tail-call optimisation emits a plain
      // `b <fn>` (instead of `bl <fn>` + `bx lr`) for the last call in a leaf
      // function — e.g. libvpy's vpy_draw_rect ends with `b v_directDraw32`.
      // Run the stub, then return to the current LR: the callee's return is
      // this function's return. Without this the branch fell through into the
      // next function's code and corrupted execution (only the loop-based
      // vpy_draw_circle/ellipse, whose last raw_line is not a tail call, worked).
      const stub = SDK_STUBS[target];
      if (stub) {
        stub(s);
        s.pc = s.regs[LR];
        break;
      }
      const idx    = resolveBranchTarget(s, target);
      if (idx !== null) {
        s.pc = idx;
      } else {
        console.warn(`[PitrexArm32] unresolved branch target: ${target}`);
      }
      break;
    }

    default:
      // Unknown instruction — silently skip
      break;
  }

  return true;
}

// ---------------------------------------------------------------------------
// State factory
// ---------------------------------------------------------------------------

/**
 * Create a fresh interpreter state for the given parsed assembly.
 * PC is set to the 'main' label (entry point).
 */
export function createState(parsed: ParsedAsm): PitrexArm32State {
  const regs = new Int32Array(16);
  // SP starts at 0x00300000 (grows downward)
  regs[SP] = 0x00300000;

  const entryPc = parsed.labels.get('main') ?? parsed.labels.get('game_main') ?? 0;

  const s: PitrexArm32State = {
    regs,
    pc: entryPc,
    N: 0, Z: 0, C: 0, V: 0,
    mem: new Map(),
    parsed,
    segments: [],
    texts: [],
    waitRecalCalled: false,
    joyX: 0, joyY: 0, joyButtons: 0,
    joyX2: 0, joyY2: 0, joyButtons2: 0,
    steps: 0,
    bcmCloBaseUs: 0,
    bcmCloIntraUs: 0,
    psgWrite: () => {},
    psgRead: () => 0,
    uartBuffer: '',
  };

  // Copy rodata init memory into state memory
  for (const [addr, word] of parsed.initMemory) {
    s.mem.set(addr, word);
  }

  // Copy inline string literals into memory at their fake addresses
  // (parser assigns them 0xF0000xxx addresses but doesn't write bytes to initMemory)
  for (const [name, content] of parsed.strings.entries()) {
    const sym = parsed.symbols.get(name);
    if (!sym) continue;
    const base = sym.value;
    for (let i = 0; i < content.length; i++) {
      memWrite8(s, base + i, content.charCodeAt(i) & 0xFF);
    }
    memWrite8(s, base + content.length, 0); // null terminator
  }

  // Initialize extern symbol addresses in memory to 0 (neutral joystick etc.)
  // They will be updated by v_readButtons / v_readJoystick1Analog stubs

  // Set up BCM system timer: bcm2835_st is a pointer variable; write BCM_TIMER_ADDR into it.
  // pitrex_music_update does: ldr r,[bcm2835_st]; ldr r,[r,#4] to read CLO.
  // memRead32 intercepts [BCM_TIMER_ADDR+4] and returns a real µs timestamp.
  const bcmSym = parsed.symbols.get('bcm2835_st');
  if (bcmSym) {
    memWrite32(s, bcmSym.value, BCM_TIMER_ADDR);
  }

  return s;
}

// ---------------------------------------------------------------------------
// Frame runner
// ---------------------------------------------------------------------------

const DEFAULT_MAX_STEPS = 500_000;

/**
 * Run the emulator until v_WaitRecal is called or maxSteps is exceeded.
 * Returns segments drawn + text drawn + whether the step limit was hit.
 */
export function runFrame(
  s: PitrexArm32State,
  maxSteps: number = DEFAULT_MAX_STEPS,
): PitrexFrameResult {
  s.segments = [];
  s.texts = [];
  s.waitRecalCalled = false;
  let steps = 0;

  // Advance the simulated BCM CLO by exactly one 50 Hz tick. pitrex_music_update
  // reads the CLO to compute elapsed µs; using real wall time produces uneven
  // 16.67 / 33.34 ms deltas under the IDE's 60→50 Hz rAF gating, which makes
  // the music sequencer's catchup loop fire 2 PSG events back-to-back and sound
  // like dirt. A flat 20 ms step keeps tempo locked to 50 Hz.
  s.bcmCloBaseUs = (s.bcmCloBaseUs + 20000) | 0;
  s.bcmCloIntraUs = 0;

  while (!s.waitRecalCalled && steps < maxSteps) {
    if (!executeOne(s)) break;
    steps++;
  }

  return { segments: s.segments, texts: s.texts, timeout: !s.waitRecalCalled && steps >= maxSteps };
}
