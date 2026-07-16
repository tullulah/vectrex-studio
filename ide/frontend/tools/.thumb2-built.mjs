// ide/frontend/src/emulator/cpu/Thumb2.ts
function u32(n) {
  return n >>> 0;
}
function s32(n) {
  return n | 0;
}
function ror32(val, shift) {
  shift &= 31;
  if (shift === 0) return u32(val);
  return u32(val >>> shift | val << 32 - shift);
}
function decodeThumb2Imm(imm12) {
  const imm8 = imm12 & 255;
  const rot8 = imm12 >>> 8 & 15;
  if (rot8 === 0) return imm8;
  if (rot8 === 1) return u32(imm8 << 16 | imm8);
  if (rot8 === 2) return u32(imm8 << 24 | imm8 << 8);
  if (rot8 === 3) return u32(imm8 << 24 | imm8 << 16 | imm8 << 8 | imm8);
  const rotAmt = imm12 >>> 7 & 31;
  const val = 128 | imm12 & 127;
  return ror32(val, rotAmt);
}
var Thumb2 = class {
  // r0-r15 stored as unsigned 32-bit (Uint32Array enforces it automatically)
  regs = new Uint32Array(16);
  /** CPSR: only N(31) Z(30) C(29) V(28) bits are maintained. */
  cpsr = 0;
  /** IT-block state. 0 = not in an IT block. */
  itState = 0;
  /**
   * True while exec16 is dispatching a Thumb-1 instruction that is sitting
   * inside an IT block. Per the ARM ARM, the "MOVS-by-default" 16-bit
   * data-processing instructions (MOV imm, ADD imm, SUB imm, the
   * exec16_alu register-form ops, etc.) must NOT update N/Z/C/V when
   * they execute conditionally inside IT — their S bit is implicitly 0
   * in that context. CMP/CMN/TST always set flags regardless of IT
   * because they have no destination register; they are unaffected by
   * this flag.
   *
   * Without this gate, `movcs r6, #1` inside `it cs` clobbers Z=1 left
   * by the preceding CMP, which is exactly the path the rustc-emitted
   * 6502 `compare()` runs through ($10202A78..$10202A8A in the llander
   * firmware). The Lunar Lander NMI handler's checksum BEQ at $7AE9
   * then fails and the 6502 self-loops at $7AEB → 0 segments rendered.
   */
  inIT16Block = false;
  /** Accumulated cycle counter since reset(). */
  _cycles = 0;
  /**
   * Set by exec of a WFI instruction; cleared by the outer run-loop at the
   * start of each frame.  The Rp2350System uses this as the frame-sync gate.
   */
  hitWfi = false;
  // ─── Register aliases ──────────────────────────────────────────────────
  get SP() {
    return this.regs[13];
  }
  set SP(v) {
    this.regs[13] = v;
  }
  get LR() {
    return this.regs[14];
  }
  set LR(v) {
    this.regs[14] = v;
  }
  // PC points to current insn + 4 during execution (Thumb convention +4)
  get PC() {
    return this.regs[15];
  }
  set PC(v) {
    this.regs[15] = v & ~1;
  }
  // force Thumb bit off
  // ─── ICpu ─────────────────────────────────────────────────────────────
  reset() {
    this.regs.fill(0);
    this.cpsr = 0;
    this.itState = 0;
    this._cycles = 0;
    this.hitWfi = false;
  }
  get pc() {
    return this.regs[15];
  }
  get cycles() {
    return this._cycles;
  }
  // ─── Register accessors (used by Rp2350System for trap handling) ──────
  /** Read general-purpose register n (0–15) as unsigned 32-bit. */
  getReg(n) {
    return this.regs[n] >>> 0;
  }
  /** Write general-purpose register n (0–15). */
  setReg(n, v) {
    this.regs[n] = v >>> 0;
  }
  irq(_line) {
  }
  /** Instruction counter for trace logging (first N instructions only). */
  _stepCount = 0;
  /**
   * Per-opcode profile counters — indexed by the high byte of hw0
   * (so each entry covers a 256-instruction block). Only populated when
   * `(globalThis as any).THUMB2_PROFILE === true` so the steady-state
   * step() path pays only one untaken-branch check.
   * Read via `(window as any).vecx._rp2350System.cpu.opcodeProfile` or
   * the dumpProfile() helper below.
   */
  opcodeProfile = new Uint32Array(256);
  /** Reset the opcode profile counters. */
  resetProfile() {
    this.opcodeProfile.fill(0);
  }
  /**
   * Print the top-N hottest opcode buckets to console. Each bucket is
   * keyed by hw0[15:8], so 0xF8 means "0xF800-0xF8FF range" which
   * covers all 32-bit LDR/STR variants.
   */
  dumpProfile(topN = 16) {
    const entries = [];
    for (let i = 0; i < 256; i++) {
      if (this.opcodeProfile[i] > 0) entries.push({ key: i, count: this.opcodeProfile[i] });
    }
    entries.sort((a, b) => b.count - a.count);
    let total = 0;
    for (const e of entries) total += e.count;
    console.log(`[thumb2 profile] total=${total} (top ${topN}):`);
    for (let i = 0; i < Math.min(topN, entries.length); i++) {
      const e = entries[i];
      const pct = (e.count * 100 / total).toFixed(1);
      console.log(`  hw0[15:8]=0x${e.key.toString(16).padStart(2, "0")}  ${e.count}  ${pct}%`);
    }
  }
  step(bus) {
    const regs = this.regs;
    const pc = regs[15];
    const hw0 = bus.read16(pc);
    let cycles;
    if (hw0 >>> 11 >= 29) {
      const hw1 = bus.read16(pc + 2);
      regs[15] = pc + 4;
      cycles = this.exec32(hw0, hw1, bus, pc);
    } else {
      regs[15] = pc + 2;
      cycles = this.exec16(hw0, bus, pc);
    }
    return cycles;
  }
  // ─── IT-block helpers ─────────────────────────────────────────────────
  inItBlock() {
    return (this.itState & 15) !== 0;
  }
  /**
   * Returns true when the current IT-conditioned instruction should execute.
   *
   * The advanceIt() shift encodes THEN/ELSE in the LSB of the condition code:
   *   - THEN slots keep the base condition (e.g. GT = 0xC, LSB=0)
   *   - ELSE slots shift to the inverse condition (e.g. LE = 0xD, LSB=1)
   *
   * condPasses(cond) correctly handles the odd/even pair:
   *   condPasses(0xC) = evalCond(GT)   → execute if GT is true (THEN)
   *   condPasses(0xD) = !evalCond(GT)  → execute if GT is false = LE (ELSE)
   *
   * evalCond(cond) alone uses (cond & 0xe) which strips the inversion bit,
   * so it would evaluate BOTH GT and LE as the same underlying GT condition —
   * causing ELSE slots to execute when GT is true instead of when it is false.
   */
  itCondTrue() {
    const cond = this.itState >>> 4 & 15;
    return this.condPasses(cond);
  }
  advanceIt() {
    if ((this.itState & 7) === 0) {
      this.itState = 0;
    } else {
      this.itState = this.itState & 224 | this.itState << 1 & 31;
    }
  }
  // ─── Flag helpers ─────────────────────────────────────────────────────
  get flagN() {
    return this.cpsr >>> 31 & 1;
  }
  get flagZ() {
    return this.cpsr >>> 30 & 1;
  }
  get flagC() {
    return this.cpsr >>> 29 & 1;
  }
  get flagV() {
    return this.cpsr >>> 28 & 1;
  }
  setFlag(bit, val) {
    if (val) this.cpsr |= 1 << bit;
    else this.cpsr &= ~(1 << bit);
  }
  setN(val) {
    this.setFlag(31, val);
  }
  setZ(val) {
    this.setFlag(30, val);
  }
  setC(val) {
    this.setFlag(29, val);
  }
  setV(val) {
    this.setFlag(28, val);
  }
  setNZ(result) {
    const r = u32(result);
    this.setN(r >>> 31 === 1);
    this.setZ(r === 0);
  }
  /** Set all four flags after an addition: result32 = a + b (no carry-in). */
  setNZCV_add(a, b) {
    const a32 = u32(a);
    const b32 = u32(b);
    const r64 = a32 + b32;
    const r32 = u32(r64);
    this.setN(r32 >>> 31 === 1);
    this.setZ(r32 === 0);
    this.setC(r64 > 4294967295);
    const signA = a32 >>> 31 & 1;
    const signB = b32 >>> 31 & 1;
    const signR = r32 >>> 31 & 1;
    this.setV(signA === signB && signR !== signA);
  }
  /** Set all four flags after a subtraction: result32 = a - b. */
  setNZCV_sub(a, b) {
    const a32 = u32(a);
    const b32 = u32(b);
    const nb32 = u32(~b32);
    const r64 = a32 + nb32 + 1;
    const r32 = u32(r64);
    this.setN(r32 >>> 31 === 1);
    this.setZ(r32 === 0);
    this.setC(r64 > 4294967295);
    const signA = a32 >>> 31 & 1;
    const signB = b32 >>> 31 & 1;
    const signR = r32 >>> 31 & 1;
    this.setV(signA !== signB && signR !== signA);
  }
  // ─── Condition evaluation ─────────────────────────────────────────────
  evalCond(cond) {
    const N = this.flagN;
    const Z = this.flagZ;
    const C = this.flagC;
    const V = this.flagV;
    switch (cond & 14) {
      case 0:
        return Z === 1;
      // EQ(0)/NE(1)
      case 2:
        return C === 1;
      // CS(2)/CC(3)
      case 4:
        return N === 1;
      // MI(4)/PL(5)
      case 6:
        return V === 1;
      // VS(6)/VC(7)
      case 8:
        return C === 1 && Z === 0;
      // HI(8)/LS(9)
      case 10:
        return N === V;
      // GE(A)/LT(B)
      case 12:
        return N === V && Z === 0;
      // GT(C)/LE(D)
      case 14:
        return true;
    }
    return false;
  }
  /** Return true if condition passes, accounting for the odd-numbered inverse. */
  condPasses(cond) {
    const base = this.evalCond(cond);
    return cond & 1 ? !base : base;
  }
  // ─── Shift helpers ────────────────────────────────────────────────────
  lsl(val, amount, updateC) {
    if (amount === 0) return u32(val);
    if (amount >= 32) {
      if (updateC) this.setC(amount === 32 ? (val & 1) !== 0 : false);
      return 0;
    }
    if (updateC) this.setC((val >>> 32 - amount & 1) !== 0);
    return u32(val << amount);
  }
  lsr(val, amount, updateC) {
    const v = u32(val);
    if (amount === 0) return v;
    if (amount >= 32) {
      if (updateC) this.setC(amount === 32 ? v >>> 31 !== 0 : false);
      return 0;
    }
    if (updateC) this.setC((v >>> amount - 1 & 1) !== 0);
    return v >>> amount;
  }
  asr(val, amount, updateC) {
    const v = s32(val);
    if (amount === 0) return u32(v);
    const shift = amount >= 32 ? 31 : amount;
    if (updateC) this.setC((v >> shift - 1 & 1) !== 0);
    return u32(v >> shift);
  }
  ror(val, amount, updateC) {
    const v = u32(val);
    amount &= 31;
    if (amount === 0) {
      return v;
    }
    const result = ror32(v, amount);
    if (updateC) this.setC(result >>> 31 !== 0);
    return result;
  }
  // ─── Memory helpers ───────────────────────────────────────────────────
  // Every IBus that the Thumb2 interpreter is used with (Rp2350System +
  // the headless harness) implements read16/read32/write16/write32, so the
  // helpers drop straight through. The `as any` calls remove the per-call
  // optional-method branch — at >3M calls per frame this is measurable.
  read16(bus, addr) {
    return bus.read16(addr);
  }
  read32(bus, addr) {
    return bus.read32(addr);
  }
  write16(bus, addr, val) {
    bus.write16(addr, val);
  }
  write32(bus, addr, val) {
    bus.write32(addr, u32(val));
  }
  // ─── PUSH / POP helpers ───────────────────────────────────────────────
  // These (and any other hot path code) read/write SP and LR via direct
  // regs[13]/regs[14] indexing instead of going through the SP/LR
  // getter/setter pair. The getters are still defined above for non-hot
  // consumers (tests, debug tools).
  push32(bus, val) {
    const newSp = u32(this.regs[13] - 4);
    this.regs[13] = newSp;
    this.write32(bus, newSp, val);
  }
  pop32(bus) {
    const sp = this.regs[13];
    const v = this.read32(bus, sp);
    this.regs[13] = u32(sp + 4);
    return v;
  }
  // =========================================================================
  // 16-bit instruction execution
  // =========================================================================
  exec16(hw, bus, pc) {
    this.inIT16Block = false;
    if ((this.itState & 15) !== 0) {
      const execute = this.itCondTrue();
      this.advanceIt();
      if (!execute) return 1;
      this.inIT16Block = true;
    }
    switch (hw >>> 12) {
      case 0:
      case 1:
      case 2:
      case 3:
        return this.exec16_shift_add(hw, pc);
      case 4: {
        const op = hw >>> 10 & 63;
        if (op === 16) return this.exec16_alu(hw, pc);
        if (op === 17) return this.exec16_hireg(hw, bus, pc);
        const rt = hw >>> 8 & 7;
        const base = pc + 4 & ~3;
        const addr = base + ((hw & 255) << 2);
        this.regs[rt] = this.read32(bus, addr);
        return 2;
      }
      case 5:
        return this.exec16_ldst_reg(hw, bus);
      case 6:
      case 7:
        return this.exec16_ldst_imm(hw, bus);
      case 8: {
        const l = hw >>> 11 & 1;
        const imm5 = hw >>> 6 & 31;
        const rn = hw >>> 3 & 7;
        const rt = hw & 7;
        const addr = u32(this.regs[rn] + (imm5 << 1));
        if (l) this.regs[rt] = this.read16(bus, addr);
        else this.write16(bus, addr, this.regs[rt]);
        return 2;
      }
      case 9: {
        const l = hw >>> 11 & 1;
        const rt = hw >>> 8 & 7;
        const addr = u32(this.regs[13] + ((hw & 255) << 2));
        if (l) this.regs[rt] = this.read32(bus, addr);
        else this.write32(bus, addr, this.regs[rt]);
        return 2;
      }
      case 10: {
        const rd = hw >>> 8 & 7;
        if ((hw & 2048) === 0) {
          const base = pc + 4 & ~3;
          this.regs[rd] = u32(base + ((hw & 255) << 2));
        } else {
          this.regs[rd] = u32(this.regs[13] + ((hw & 255) << 2));
        }
        return 1;
      }
      case 11:
        return this.exec16_misc(hw, bus, pc);
      case 12: {
        const l = hw >>> 11 & 1;
        const rn = hw >>> 8 & 7;
        const rlist = hw & 255;
        let addr = this.regs[rn];
        let cycles = 1;
        for (let i = 0; i <= 7; i++) {
          if (rlist & 1 << i) {
            if (l) this.regs[i] = this.read32(bus, addr);
            else this.write32(bus, addr, this.regs[i]);
            addr = u32(addr + 4);
            cycles++;
          }
        }
        this.regs[rn] = addr;
        return cycles;
      }
      case 13: {
        const cond = hw >>> 8 & 15;
        if (cond === 14) throw new Error(`UDF at PC=0x${pc.toString(16)}`);
        if (cond === 15) return 1;
        if (this.condPasses(cond)) {
          const offset = (hw & 255) << 24 >> 24;
          this.regs[15] = u32(pc + 4 + (offset << 1));
        }
        return 1;
      }
      case 14: {
        const offset = (hw & 2047) << 21 >> 21;
        this.regs[15] = u32(pc + 4 + (offset << 1));
        return 1;
      }
    }
    throw new Error(`Unimplemented 16-bit Thumb2: 0x${hw.toString(16).padStart(4, "0")} at PC=0x${pc.toString(16)}`);
  }
  // ─── 16-bit: Shifts, Add/Sub, Mov/Cmp ────────────────────────────────────
  exec16_shift_add(hw, _pc) {
    const b15_13 = hw >>> 13 & 7;
    if (b15_13 === 1) {
      const op2 = hw >>> 11 & 3;
      const rdn = hw >>> 8 & 7;
      const imm8 = hw & 255;
      switch (op2) {
        case 0: {
          const r = u32(imm8);
          this.regs[rdn] = r;
          if (!this.inIT16Block) this.setNZ(r);
          break;
        }
        case 1: {
          this.setNZCV_sub(this.regs[rdn], imm8);
          break;
        }
        case 2: {
          const a = this.regs[rdn];
          if (!this.inIT16Block) this.setNZCV_add(a, imm8);
          this.regs[rdn] = u32(a + imm8);
          break;
        }
        case 3: {
          const a = this.regs[rdn];
          if (!this.inIT16Block) this.setNZCV_sub(a, imm8);
          this.regs[rdn] = u32(a - imm8);
          break;
        }
      }
      return 1;
    }
    const b12_10 = hw >>> 10 & 7;
    if (b12_10 <= 5) {
      const shiftType = hw >>> 11 & 3;
      const imm5 = hw >>> 6 & 31;
      const rm = hw >>> 3 & 7;
      const rd2 = hw & 7;
      let result;
      if (shiftType === 0) {
        result = this.lsl(this.regs[rm], imm5 === 0 ? 0 : imm5, imm5 !== 0);
      } else if (shiftType === 1) {
        result = this.lsr(this.regs[rm], imm5 === 0 ? 32 : imm5, true);
      } else {
        result = this.asr(this.regs[rm], imm5 === 0 ? 32 : imm5, true);
      }
      this.regs[rd2] = result;
      if (!this.inIT16Block) this.setNZ(result);
      return 1;
    }
    const b12_9 = hw >>> 9 & 15;
    const rd = hw & 7;
    const rn = hw >>> 3 & 7;
    if (b12_9 === 12) {
      const rm = hw >>> 6 & 7;
      const a = this.regs[rn];
      const b = this.regs[rm];
      if (!this.inIT16Block) this.setNZCV_add(a, b);
      this.regs[rd] = u32(a + b);
    } else if (b12_9 === 13) {
      const rm = hw >>> 6 & 7;
      const a = this.regs[rn];
      const b = this.regs[rm];
      if (!this.inIT16Block) this.setNZCV_sub(a, b);
      this.regs[rd] = u32(a - b);
    } else if (b12_9 === 14) {
      const imm3 = hw >>> 6 & 7;
      const a = this.regs[rn];
      if (!this.inIT16Block) this.setNZCV_add(a, imm3);
      this.regs[rd] = u32(a + imm3);
    } else if (b12_9 === 15) {
      const imm3 = hw >>> 6 & 7;
      const a = this.regs[rn];
      if (!this.inIT16Block) this.setNZCV_sub(a, imm3);
      this.regs[rd] = u32(a - imm3);
    } else {
      throw new Error(`Unimplemented shift_add group: 0x${hw.toString(16).padStart(4, "0")}`);
    }
    return 1;
  }
  // ─── 16-bit: ALU operations (bits[15:10] = 010000) ───────────────────────
  exec16_alu(hw, _pc) {
    const aluOp = hw >>> 6 & 15;
    const rm = hw >>> 3 & 7;
    const rdn = hw & 7;
    const a = this.regs[rdn];
    const b = this.regs[rm];
    const setFlags = !this.inIT16Block;
    switch (aluOp) {
      case 0: {
        const r = u32(a & b);
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
      case 1: {
        const r = u32(a ^ b);
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
      case 2: {
        const shift = b & 255;
        const r = this.lsl(a, shift, setFlags);
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
      case 3: {
        const shift = b & 255;
        const r = this.lsr(a, shift === 0 ? 0 : shift, setFlags && shift !== 0);
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
      case 4: {
        const shift = b & 255;
        const r = this.asr(a, shift, setFlags && shift !== 0);
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
      case 5: {
        const carry = this.flagC;
        const r64 = u32(a) + u32(b) + carry;
        const r32 = u32(r64);
        this.regs[rdn] = r32;
        if (setFlags) {
          this.setN(r32 >>> 31 === 1);
          this.setZ(r32 === 0);
          this.setC(r64 > 4294967295);
          const sA = a >>> 31 & 1;
          const sB = b >>> 31 & 1;
          const sR = r32 >>> 31 & 1;
          this.setV(sA === sB && sR !== sA);
        }
        break;
      }
      case 6: {
        const borrow = 1 - this.flagC;
        const r64 = u32(a) - u32(b) - borrow;
        const r32 = u32(r64);
        if (setFlags) {
          this.setNZCV_sub(a, b + borrow);
        }
        this.regs[rdn] = r32;
        break;
      }
      case 7: {
        const shift = b & 255;
        const r = this.ror(a, shift, setFlags && shift !== 0);
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
      case 8: {
        const r = u32(a & b);
        this.setNZ(r);
        break;
      }
      case 9: {
        const r = u32(0 - b);
        this.regs[rdn] = r;
        if (setFlags) this.setNZCV_sub(0, b);
        break;
      }
      case 10: {
        this.setNZCV_sub(a, b);
        break;
      }
      case 11: {
        this.setNZCV_add(a, b);
        break;
      }
      case 12: {
        const r = u32(a | b);
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
      case 13: {
        const r = u32(Math.imul(a, b));
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
      case 14: {
        const r = u32(a & ~b);
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
      case 15: {
        const r = u32(~b);
        this.regs[rdn] = r;
        if (setFlags) this.setNZ(r);
        break;
      }
    }
    return 1;
  }
  // ─── 16-bit: Hi-register ops / BX (bits[15:10] = 010001) ─────────────────
  exec16_hireg(hw, _bus, _pc) {
    const op2 = hw >>> 8 & 3;
    const dn = hw >>> 7 & 1;
    const rm = hw >>> 3 & 15;
    const rdn = hw & 7 | dn << 3;
    switch (op2) {
      case 0: {
        this.regs[rdn] = u32(this.regs[rdn] + this.regs[rm]);
        break;
      }
      case 1: {
        this.setNZCV_sub(this.regs[rdn], this.regs[rm]);
        break;
      }
      case 2: {
        const val = this.regs[rm];
        if (rdn === 15) {
          this.regs[15] = val & ~1;
        } else {
          this.regs[rdn] = val;
        }
        break;
      }
      case 3: {
        if (dn === 0) {
          this.regs[15] = this.regs[rm] & ~1;
        } else {
          this.regs[14] = this.regs[15] | 1;
          this.regs[15] = this.regs[rm] & ~1;
        }
        break;
      }
    }
    return 1;
  }
  // ─── 16-bit: Load/Store register offset (bits[15:12] = 0101) ─────────────
  exec16_ldst_reg(hw, bus) {
    const op = hw >>> 9 & 7;
    const rm = hw >>> 6 & 7;
    const rn = hw >>> 3 & 7;
    const rt = hw & 7;
    const addr = u32(this.regs[rn] + this.regs[rm]);
    switch (op) {
      case 0:
        this.write32(bus, addr, this.regs[rt]);
        break;
      case 1:
        this.write16(bus, addr, this.regs[rt] & 65535);
        break;
      case 2:
        bus.write8(addr, this.regs[rt] & 255);
        break;
      case 3:
        this.regs[rt] = u32(bus.read8(addr) << 24 >> 24);
        break;
      case 4:
        this.regs[rt] = this.read32(bus, addr);
        break;
      case 5:
        this.regs[rt] = this.read16(bus, addr);
        break;
      case 6:
        this.regs[rt] = bus.read8(addr);
        break;
      case 7:
        this.regs[rt] = u32(this.read16(bus, addr) << 16 >> 16);
        break;
    }
    return 2;
  }
  // ─── 16-bit: Load/Store immediate (bits[15:13] = 011) ────────────────────
  exec16_ldst_imm(hw, bus) {
    const b12 = hw >>> 12 & 1;
    const l = hw >>> 11 & 1;
    const imm5 = hw >>> 6 & 31;
    const rn = hw >>> 3 & 7;
    const rt = hw & 7;
    if (b12 === 0) {
      const addr = u32(this.regs[rn] + (imm5 << 2));
      if (l) {
        this.regs[rt] = this.read32(bus, addr);
      } else {
        this.write32(bus, addr, this.regs[rt]);
      }
    } else {
      const addr = u32(this.regs[rn] + imm5);
      if (l) {
        this.regs[rt] = bus.read8(addr);
      } else {
        bus.write8(addr, this.regs[rt] & 255);
      }
    }
    return 2;
  }
  // ─── 16-bit: Miscellaneous (bits[15:12] = 1011) ──────────────────────────
  exec16_misc(hw, bus, _pc) {
    const b11_8 = hw >>> 8 & 15;
    if (b11_8 === 5 || b11_8 === 4) {
      const pbit = hw >>> 8 & 1;
      const rlist = hw & 255;
      if (pbit) this.push32(bus, this.regs[14]);
      for (let i = 7; i >= 0; i--) {
        if (rlist & 1 << i) this.push32(bus, this.regs[i]);
      }
      return 1 + (rlist ? this.bitCount(rlist) : 0) + pbit;
    }
    if (b11_8 === 13 || b11_8 === 12) {
      const pbit = hw >>> 8 & 1;
      const rlist = hw & 255;
      for (let i = 0; i <= 7; i++) {
        if (rlist & 1 << i) this.regs[i] = this.pop32(bus);
      }
      if (pbit) {
        const target = this.pop32(bus);
        this.regs[15] = target & ~1;
      }
      return 1 + (rlist ? this.bitCount(rlist) : 0) + pbit;
    }
    if (b11_8 === 0) {
      const sign = hw >>> 7 & 1;
      const imm = (hw & 127) << 2;
      if (sign === 0) {
        this.regs[13] = u32(this.regs[13] + imm);
      } else {
        this.regs[13] = u32(this.regs[13] - imm);
      }
      return 1;
    }
    if (b11_8 === 2) {
      const op2 = hw >>> 6 & 3;
      const rm = hw >>> 3 & 7;
      const rd = hw & 7;
      switch (op2) {
        case 0:
          this.regs[rd] = u32(this.regs[rm] << 16 >> 16);
          break;
        case 1:
          this.regs[rd] = u32(this.regs[rm] << 24 >> 24);
          break;
        case 2:
          this.regs[rd] = this.regs[rm] & 65535;
          break;
        case 3:
          this.regs[rd] = this.regs[rm] & 255;
          break;
      }
      return 1;
    }
    if (b11_8 === 10) {
      const op2 = hw >>> 6 & 3;
      const rm = hw >>> 3 & 7;
      const rd = hw & 7;
      const v = this.regs[rm];
      switch (op2) {
        case 0: {
          this.regs[rd] = u32(
            (v & 255) << 24 | (v >>> 8 & 255) << 16 | (v >>> 16 & 255) << 8 | v >>> 24 & 255
          );
          break;
        }
        case 1: {
          this.regs[rd] = u32(
            v >>> 8 & 255 | (v & 255) << 8 | (v >>> 24 & 255) << 16 | (v >>> 16 & 255) << 24
          );
          break;
        }
        case 3: {
          const lo = (v & 255) << 8 | v >>> 8 & 255;
          this.regs[rd] = u32(lo << 16 >> 16);
          break;
        }
      }
      return 1;
    }
    if (b11_8 === 15) {
      const firstCond = hw >>> 4 & 15;
      const mask = hw & 15;
      if (mask === 0) {
        const hint = hw >>> 4 & 15;
        if (hint === 3) {
          this.hitWfi = true;
        }
        return 1;
      }
      this.itState = (firstCond & 15) << 4 | mask & 31;
      return 1;
    }
    if ((hw & 62720) === 45312 || (hw & 62720) === 47360) {
      const nz = hw >>> 11 & 1;
      const rn = hw & 7;
      const imm = (hw >>> 3 & 31) << 1 | (hw >>> 9 & 1) << 6;
      const test = this.regs[rn];
      if (nz ? test !== 0 : test === 0) {
        this.regs[15] = u32(_pc + 4 + imm);
      }
      return 1;
    }
    throw new Error(`Unimplemented 16-bit misc: 0x${hw.toString(16).padStart(4, "0")}`);
  }
  // =========================================================================
  // 32-bit instruction execution
  // =========================================================================
  exec32(hw0, hw1, bus, pc) {
    if ((this.itState & 15) !== 0) {
      const execute = this.itCondTrue();
      this.advanceIt();
      if (!execute) return 1;
    }
    const op5 = hw0 >>> 11 & 31;
    if (op5 === 30) {
      if ((hw1 & 32768) !== 0) {
        return this.exec32_branch(hw0, hw1, pc);
      } else {
        return this.exec32_data(hw0, hw1, bus, pc);
      }
    }
    if (op5 === 29 || op5 === 31) {
      return this.exec32_data(hw0, hw1, bus, pc);
    }
    throw new Error(`Unimplemented 32-bit Thumb2: hw0=0x${hw0.toString(16).padStart(4, "0")} hw1=0x${hw1.toString(16).padStart(4, "0")} at PC=0x${pc.toString(16)}`);
  }
  // ─── 32-bit: Branches ─────────────────────────────────────────────────────
  exec32_branch(hw0, hw1, pc) {
    const J1 = hw1 >>> 13 & 1;
    const J2 = hw1 >>> 11 & 1;
    const S = hw0 >>> 10 & 1;
    const I1 = ~(J1 ^ S) & 1;
    const I2 = ~(J2 ^ S) & 1;
    const hw1_15_14 = hw1 >>> 14 & 3;
    const hw1_12 = hw1 >>> 12 & 1;
    if (hw1_15_14 === 3) {
      const offset_hi = hw0 & 1023;
      const offset_lo = hw1 & 2047;
      const raw = S << 24 | I1 << 23 | I2 << 22 | offset_hi << 12 | offset_lo << 1;
      const offset = raw << 7 >> 7;
      this.regs[14] = u32(pc + 4) | 1;
      this.regs[15] = u32(pc + 4 + offset);
      return 3;
    }
    if (hw1_15_14 === 2) {
      if (hw1_12 === 1) {
        const offset_hi = hw0 & 1023;
        const offset_lo = hw1 & 2047;
        const raw = S << 24 | I1 << 23 | I2 << 22 | offset_hi << 12 | offset_lo << 1;
        const offset = raw << 7 >> 7;
        this.regs[15] = u32(pc + 4 + offset);
        return 3;
      } else {
        const cond = hw0 >>> 6 & 15;
        const S2 = hw0 >>> 10 & 1;
        const imm6 = hw0 & 63;
        const imm11 = hw1 & 2047;
        const J1c = hw1 >>> 13 & 1;
        const J2c = hw1 >>> 11 & 1;
        const raw2 = S2 << 20 | J2c << 19 | J1c << 18 | imm6 << 12 | imm11 << 1;
        const offset = raw2 << 11 >> 11;
        if (this.condPasses(cond)) {
          this.regs[15] = u32(pc + 4 + offset);
        }
        return 3;
      }
    }
    throw new Error(`Unimplemented 32-bit branch: hw0=0x${hw0.toString(16)} hw1=0x${hw1.toString(16)} at PC=0x${pc.toString(16)}`);
  }
  // ─── 32-bit: Data processing and memory ──────────────────────────────────
  exec32_data(hw0, hw1, bus, pc) {
    if ((hw0 & 65024) === 63488 || (hw0 & 65024) === 63744) {
      return this.exec32_ldst(hw0, hw1, bus, pc);
    }
    if ((hw0 & 63488) === 61440) {
      if ((hw0 & 64496) === 62016) {
        const imm4 = hw0 & 15;
        const i = hw0 >>> 10 & 1;
        const imm3 = hw1 >>> 12 & 7;
        const rd = hw1 >>> 8 & 15;
        const imm8 = hw1 & 255;
        this.regs[rd] = imm4 << 12 | i << 11 | imm3 << 8 | imm8;
        return 2;
      }
      if ((hw0 & 64496) === 62144) {
        const imm4 = hw0 & 15;
        const i = hw0 >>> 10 & 1;
        const imm3 = hw1 >>> 12 & 7;
        const rd = hw1 >>> 8 & 15;
        const imm8 = hw1 & 255;
        const imm16 = imm4 << 12 | i << 11 | imm3 << 8 | imm8;
        this.regs[rd] = this.regs[rd] & 65535 | imm16 << 16;
        return 2;
      }
      return this.exec32_dp_imm(hw0, hw1, pc);
    }
    if ((hw0 & 65024) === 59904) {
      return this.exec32_dp_reg(hw0, hw1);
    }
    if ((hw0 & 65408) === 64e3) {
      return this.exec32_extend(hw0, hw1);
    }
    if ((hw0 & 64496) === 62016) {
      const imm4 = hw0 & 15;
      const i = hw0 >>> 10 & 1;
      const imm3 = hw1 >>> 12 & 7;
      const rd = hw1 >>> 8 & 15;
      const imm8 = hw1 & 255;
      const imm16 = imm4 << 12 | i << 11 | imm3 << 8 | imm8;
      this.regs[rd] = imm16;
      return 2;
    }
    if ((hw0 & 64496) === 62144) {
      const imm4 = hw0 & 15;
      const i = hw0 >>> 10 & 1;
      const imm3 = hw1 >>> 12 & 7;
      const rd = hw1 >>> 8 & 15;
      const imm8 = hw1 & 255;
      const imm16 = imm4 << 12 | i << 11 | imm3 << 8 | imm8;
      this.regs[rd] = this.regs[rd] & 65535 | imm16 << 16;
      return 2;
    }
    if ((hw0 & 65520) === 64176 && (hw1 & 61680) === 61568) {
      const rm = hw1 & 15;
      const rd = hw1 >>> 8 & 15;
      const v = this.regs[rm] >>> 0;
      this.regs[rd] = Math.clz32(v);
      return 2;
    }
    if ((hw0 & 65520) === 64400 && (hw1 & 61680) === 61680) {
      const rn = hw0 & 15;
      const rd = hw1 >>> 8 & 15;
      const rm = hw1 & 15;
      const dividend = s32(this.regs[rn]);
      const divisor = s32(this.regs[rm]);
      if (divisor === 0) {
        this.regs[rd] = 0;
      } else {
        this.regs[rd] = u32(Math.trunc(dividend / divisor));
      }
      return 8;
    }
    if ((hw0 & 65520) === 64432 && (hw1 & 61680) === 61680) {
      const rn = hw0 & 15;
      const rd = hw1 >>> 8 & 15;
      const rm = hw1 & 15;
      const dividend = u32(this.regs[rn]);
      const divisor = u32(this.regs[rm]);
      if (divisor === 0) {
        this.regs[rd] = 0;
      } else {
        this.regs[rd] = u32(Math.floor(dividend / divisor));
      }
      return 8;
    }
    if ((hw0 & 65520) === 64256) {
      const rn = hw0 & 15;
      const ra = hw1 >>> 12 & 15;
      const rd = hw1 >>> 8 & 15;
      const op = hw1 >>> 4 & 15;
      const rm = hw1 & 15;
      const prod = u32(Math.imul(this.regs[rn], this.regs[rm]));
      if (op === 0) {
        if (ra === 15) {
          this.regs[rd] = prod;
        } else {
          this.regs[rd] = u32(this.regs[ra] + prod);
        }
        return 3;
      }
      if (op === 1) {
        this.regs[rd] = u32(this.regs[ra] - prod);
        return 3;
      }
    }
    if ((hw0 & 65408) === 64384 && (hw1 & 240) === 0) {
      const rn = hw0 & 15;
      const op = hw0 >>> 5 & 3;
      const rdlo = hw1 >>> 12 & 15;
      const rdhi = hw1 >>> 8 & 15;
      const rm = hw1 & 15;
      const a = this.regs[rn];
      const b = this.regs[rm];
      let lo, hi;
      if (op === 0 || op === 2) {
        const prod = BigInt(a | 0) * BigInt(b | 0);
        const mask = (1n << 64n) - 1n;
        const u = prod & mask;
        lo = Number(u & 0xFFFFFFFFn) >>> 0;
        hi = Number(u >> 32n & 0xFFFFFFFFn) >>> 0;
      } else {
        const prod = BigInt(a >>> 0) * BigInt(b >>> 0);
        lo = Number(prod & 0xFFFFFFFFn) >>> 0;
        hi = Number(prod >> 32n & 0xFFFFFFFFn) >>> 0;
      }
      if (op === 2 || op === 3) {
        const accLo = BigInt(this.regs[rdlo] >>> 0);
        const accHi = BigInt(this.regs[rdhi] >>> 0);
        const acc = accHi << 32n | accLo;
        const sum = BigInt(hi) << 32n | BigInt(lo);
        const total = acc + sum & (1n << 64n) - 1n;
        lo = Number(total & 0xFFFFFFFFn) >>> 0;
        hi = Number(total >> 32n & 0xFFFFFFFFn) >>> 0;
      }
      this.regs[rdlo] = lo;
      this.regs[rdhi] = hi;
      return 5;
    }
    return this.exec32_ldst(hw0, hw1, bus, pc);
  }
  // ─── 32-bit: Load/Store ───────────────────────────────────────────────────
  exec32_ldst(hw0, hw1, bus, pc) {
    if (hw0 === 59693) {
      const list = hw1;
      let count = 0;
      for (let r = 0; r <= 14; r++) {
        if (list & 1 << r) count++;
      }
      this.regs[13] = u32(this.regs[13] - count * 4);
      let addr = this.regs[13];
      for (let r = 0; r <= 14; r++) {
        if (list & 1 << r) {
          this.write32(bus, addr, this.regs[r]);
          addr += 4;
        }
      }
      return count + 1;
    }
    if (hw0 === 59581) {
      const list = hw1;
      let addr = this.regs[13];
      let count = 0;
      for (let r = 0; r <= 15; r++) {
        if (list & 1 << r) {
          const val = this.read32(bus, addr);
          if (r === 15) {
            this.regs[15] = val & ~1;
          } else if (r !== 13) {
            this.regs[r] = val;
          }
          addr += 4;
          count++;
        }
      }
      this.regs[13] = u32(addr);
      return count + 1;
    }
    if ((hw0 & 65520) === 59536 || (hw0 & 65520) === 59568) {
      const rn2 = hw0 & 15;
      const writeback = (hw0 & 32) !== 0;
      let addr = u32(this.regs[rn2]);
      for (let r = 0; r <= 15; r++) {
        if (hw1 & 1 << r) {
          const val = this.read32(bus, addr);
          if (r === 15) this.regs[15] = val & ~1;
          else if (r !== 13) this.regs[r] = val;
          addr = u32(addr + 4);
        }
      }
      if (writeback) this.regs[rn2] = addr;
      return 2;
    }
    if ((hw0 & 65520) === 59520 || (hw0 & 65520) === 59552) {
      const rn2 = hw0 & 15;
      const writeback = (hw0 & 32) !== 0;
      let addr = u32(this.regs[rn2]);
      for (let r = 0; r <= 14; r++) {
        if (hw1 & 1 << r) {
          this.write32(bus, addr, this.regs[r]);
          addr = u32(addr + 4);
        }
      }
      if (writeback) this.regs[rn2] = addr;
      return 2;
    }
    const rn = hw0 & 15;
    const rt = hw1 >>> 12 & 15;
    if (hw0 === 63711) {
      const imm12 = hw1 & 4095;
      const base = this.regs[15] & ~3;
      this.regs[rt] = this.read32(bus, u32(base + imm12));
      return 2;
    }
    if (hw0 === 63583) {
      const imm12 = hw1 & 4095;
      const base = this.regs[15] & ~3;
      this.regs[rt] = this.read32(bus, u32(base - imm12));
      return 2;
    }
    if ((hw0 & 65488) === 63568 || (hw0 & 65488) === 63696) {
      const isLoad = (hw0 >>> 4 & 1) === 1 || (hw0 & 16) !== 0;
      const hw1_11 = hw1 >>> 11 & 1;
      let addr;
      let writeback = false;
      let wbValue = 0;
      const base = this.regs[rn];
      if ((hw0 & 65024) === 63488 && hw1_11 === 0 && hw1 >>> 8 === 0) {
        const imm12 = hw1 & 4095;
        addr = u32(base + imm12);
      } else if (hw1_11 === 1) {
        const P = hw1 >>> 10 & 1;
        const U = hw1 >>> 9 & 1;
        const W = hw1 >>> 8 & 1;
        const imm8 = hw1 & 255;
        const offset = U ? imm8 : -imm8;
        addr = P ? u32(base + offset) : u32(base);
        if (W) {
          writeback = true;
          wbValue = u32(base + offset);
        }
      } else if ((hw0 & 128) !== 0) {
        const imm12 = hw1 & 4095;
        addr = u32(base + imm12);
      } else {
        const rm = hw1 & 15;
        const imm2 = hw1 >>> 4 & 3;
        addr = u32(base + (this.regs[rm] << imm2));
      }
      const actualLoad = (hw0 >>> 4 & 1) !== 0;
      if (actualLoad) {
        this.regs[rt] = this.read32(bus, addr);
      } else {
        this.write32(bus, addr, this.regs[rt]);
      }
      if (writeback) this.regs[rn] = wbValue;
      return 2;
    }
    if ((hw0 & 65520) === 63696) {
      const imm12 = hw1 & 4095;
      this.regs[rt] = this.read32(bus, u32(this.regs[rn] + imm12));
      return 2;
    }
    if ((hw0 & 65520) === 63680) {
      const imm12 = hw1 & 4095;
      this.write32(bus, u32(this.regs[rn] + imm12), this.regs[rt]);
      return 2;
    }
    if ((hw0 & 65520) === 63632) {
      const imm12 = hw1 & 4095;
      this.regs[rt] = bus.read8(u32(this.regs[rn] + imm12));
      return 2;
    }
    if ((hw0 & 65520) === 63616) {
      const imm12 = hw1 & 4095;
      bus.write8(u32(this.regs[rn] + imm12), this.regs[rt] & 255);
      return 2;
    }
    if ((hw0 & 65520) === 63664) {
      const imm12 = hw1 & 4095;
      this.regs[rt] = this.read16(bus, u32(this.regs[rn] + imm12));
      return 2;
    }
    if ((hw0 & 65520) === 63648) {
      const imm12 = hw1 & 4095;
      this.write16(bus, u32(this.regs[rn] + imm12), this.regs[rt] & 65535);
      return 2;
    }
    if ((hw0 & 65520) === 63888) {
      const imm12 = hw1 & 4095;
      this.regs[rt] = u32(bus.read8(u32(this.regs[rn] + imm12)) << 24 >> 24);
      return 2;
    }
    if ((hw0 & 65520) === 63920) {
      const imm12 = hw1 & 4095;
      this.regs[rt] = u32(this.read16(bus, u32(this.regs[rn] + imm12)) << 16 >> 16);
      return 2;
    }
    if ((hw0 & 65520) === 63760) {
      if (hw1 >>> 11 & 1) {
        const P = hw1 >>> 10 & 1;
        const U = hw1 >>> 9 & 1;
        const W = hw1 >>> 8 & 1;
        const imm8 = hw1 & 255;
        const base = this.regs[rn];
        const offset = U ? imm8 : -imm8;
        const addr = P ? u32(base + offset) : u32(base);
        this.regs[rt] = u32(bus.read8(addr) << 24 >> 24);
        if (W) this.regs[rn] = u32(base + offset);
      } else {
        const rm = hw1 & 15;
        const imm2 = hw1 >>> 4 & 3;
        const addr = u32(this.regs[rn] + (this.regs[rm] << imm2));
        this.regs[rt] = u32(bus.read8(addr) << 24 >> 24);
      }
      return 2;
    }
    if ((hw0 & 65520) === 63568) {
      if (hw1 >>> 11 & 1) {
        const P = hw1 >>> 10 & 1;
        const U = hw1 >>> 9 & 1;
        const W = hw1 >>> 8 & 1;
        const imm8 = hw1 & 255;
        const base = this.regs[rn];
        const offset = U ? imm8 : -imm8;
        const addr = P ? u32(base + offset) : u32(base);
        this.regs[rt] = this.read32(bus, addr);
        if (W) this.regs[rn] = u32(base + offset);
      } else {
        const rm = hw1 & 15;
        const imm2 = hw1 >>> 4 & 3;
        const addr = u32(this.regs[rn] + (this.regs[rm] << imm2));
        this.regs[rt] = this.read32(bus, addr);
      }
      return 2;
    }
    if ((hw0 & 65520) === 63552) {
      if (hw1 >>> 11 & 1) {
        const P = hw1 >>> 10 & 1;
        const U = hw1 >>> 9 & 1;
        const W = hw1 >>> 8 & 1;
        const imm8 = hw1 & 255;
        const base = this.regs[rn];
        const offset = U ? imm8 : -imm8;
        const addr = P ? u32(base + offset) : u32(base);
        this.write32(bus, addr, this.regs[rt]);
        if (W) this.regs[rn] = u32(base + offset);
      } else {
        const rm = hw1 & 15;
        const imm2 = hw1 >>> 4 & 3;
        const addr = u32(this.regs[rn] + (this.regs[rm] << imm2));
        this.write32(bus, addr, this.regs[rt]);
      }
      return 2;
    }
    if ((hw0 & 65520) === 63504) {
      if (hw1 >>> 11 & 1) {
        const P = hw1 >>> 10 & 1;
        const U = hw1 >>> 9 & 1;
        const W = hw1 >>> 8 & 1;
        const imm8 = hw1 & 255;
        const base = this.regs[rn];
        const offset = U ? imm8 : -imm8;
        const addr = P ? u32(base + offset) : u32(base);
        this.regs[rt] = bus.read8(addr);
        if (W) this.regs[rn] = u32(base + offset);
      } else {
        const rm = hw1 & 15;
        const imm2 = hw1 >>> 4 & 3;
        const addr = u32(this.regs[rn] + (this.regs[rm] << imm2));
        this.regs[rt] = bus.read8(addr);
      }
      return 2;
    }
    if ((hw0 & 65520) === 63488) {
      if (hw1 >>> 11 & 1) {
        const P = hw1 >>> 10 & 1;
        const U = hw1 >>> 9 & 1;
        const W = hw1 >>> 8 & 1;
        const imm8 = hw1 & 255;
        const base = this.regs[rn];
        const offset = U ? imm8 : -imm8;
        const addr = P ? u32(base + offset) : u32(base);
        bus.write8(addr, this.regs[rt] & 255);
        if (W) this.regs[rn] = u32(base + offset);
      } else {
        const rm = hw1 & 15;
        const imm2 = hw1 >>> 4 & 3;
        const addr = u32(this.regs[rn] + (this.regs[rm] << imm2));
        bus.write8(addr, this.regs[rt] & 255);
      }
      return 2;
    }
    if ((hw0 & 65520) === 63536) {
      if (hw1 >>> 11 & 1) {
        const P = hw1 >>> 10 & 1;
        const U = hw1 >>> 9 & 1;
        const W = hw1 >>> 8 & 1;
        const imm8 = hw1 & 255;
        const base = this.regs[rn];
        const offset = U ? imm8 : -imm8;
        const addr = P ? u32(base + offset) : u32(base);
        this.regs[rt] = this.read16(bus, addr);
        if (W) this.regs[rn] = u32(base + offset);
      } else {
        const rm = hw1 & 15;
        const imm2 = hw1 >>> 4 & 3;
        const addr = u32(this.regs[rn] + (this.regs[rm] << imm2));
        this.regs[rt] = this.read16(bus, addr);
      }
      return 2;
    }
    if ((hw0 & 65520) === 63520) {
      if (hw1 >>> 11 & 1) {
        const P = hw1 >>> 10 & 1;
        const U = hw1 >>> 9 & 1;
        const W = hw1 >>> 8 & 1;
        const imm8 = hw1 & 255;
        const base = this.regs[rn];
        const offset = U ? imm8 : -imm8;
        const addr = P ? u32(base + offset) : u32(base);
        this.write16(bus, addr, this.regs[rt] & 65535);
        if (W) this.regs[rn] = u32(base + offset);
      } else {
        const rm = hw1 & 15;
        const imm2 = hw1 >>> 4 & 3;
        const addr = u32(this.regs[rn] + (this.regs[rm] << imm2));
        this.write16(bus, addr, this.regs[rt] & 65535);
      }
      return 2;
    }
    if ((hw0 & 65520) === 63792) {
      const rm = hw1 & 15;
      const imm2 = hw1 >>> 4 & 3;
      const addr = u32(this.regs[rn] + (this.regs[rm] << imm2));
      this.regs[rt] = u32(this.read16(bus, addr) << 16 >> 16);
      return 2;
    }
    if ((hw0 & 65520) === 59472 && (hw1 >>> 8 & 15) === 15) {
      const rt2 = hw1 >>> 12 & 15;
      const imm8 = hw1 & 255;
      const addr = u32(this.regs[rn] + (imm8 << 2));
      this.regs[rt2] = this.read32(bus, addr);
      return 2;
    }
    if ((hw0 & 65520) === 59456) {
      const rt2 = hw1 >>> 12 & 15;
      const rd = hw1 >>> 8 & 15;
      const imm8 = hw1 & 255;
      const addr = u32(this.regs[rn] + (imm8 << 2));
      this.write32(bus, addr, this.regs[rt2]);
      this.regs[rd] = 0;
      return 2;
    }
    if ((hw0 & 65520) === 59600 && (hw1 & 4095) === 4079) {
      const rt2 = hw1 >>> 12 & 15;
      this.regs[rt2] = this.read32(bus, this.regs[rn]);
      return 2;
    }
    if ((hw0 & 65520) === 59584 && (hw1 & 255) === 239) {
      const rt2 = hw1 >>> 12 & 15;
      const rd = hw1 >>> 8 & 15;
      this.write32(bus, this.regs[rn], this.regs[rt2]);
      this.regs[rd] = 0;
      return 2;
    }
    if ((hw0 & 65520) === 59600 && (hw1 >>> 5 & 2047) === 1920) {
      const H = hw1 >>> 4 & 1;
      const rm = hw1 & 15;
      const base = rn === 15 ? u32(pc + 4) : this.regs[rn];
      const index = this.regs[rm];
      const offset = H ? this.read16(bus, u32(base + index * 2)) : bus.read8(u32(base + index));
      this.regs[15] = u32(pc + 4 + 2 * offset);
      return 2;
    }
    if ((hw0 & 64576) === 59456 && (hw0 & 288) !== 0) {
      const P = hw0 >>> 8 & 1;
      const U = hw0 >>> 7 & 1;
      const W = hw0 >>> 5 & 1;
      const L = hw0 >>> 4 & 1;
      const rt2 = hw1 >>> 12 & 15;
      const rt22 = hw1 >>> 8 & 15;
      const imm8 = hw1 & 255;
      const offset = (U ? imm8 : -imm8) << 2;
      const base = this.regs[rn];
      const addr = P ? u32(base + offset) : u32(base);
      if (L) {
        this.regs[rt2] = this.read32(bus, addr);
        this.regs[rt22] = this.read32(bus, u32(addr + 4));
      } else {
        this.write32(bus, addr, this.regs[rt2]);
        this.write32(bus, u32(addr + 4), this.regs[rt22]);
      }
      if (W) {
        this.regs[rn] = u32(base + offset);
      }
      return 4;
    }
    throw new Error(`Unimplemented 32-bit LD/ST: hw0=0x${hw0.toString(16).padStart(4, "0")} hw1=0x${hw1.toString(16).padStart(4, "0")} at PC=0x${pc.toString(16)}`);
  }
  // ─── 32-bit: Data-processing immediate ───────────────────────────────────
  exec32_dp_imm(hw0, hw1, _pc) {
    const op = hw0 >>> 5 & 15;
    const rn = hw0 & 15;
    const rd = hw1 >>> 8 & 15;
    const s = hw0 >>> 4 & 1;
    const i = hw0 >>> 10 & 1;
    if ((hw0 >>> 9 & 1) === 1) {
      const imm12 = i << 11 | (hw1 >>> 12 & 7) << 8 | hw1 & 255;
      const isSsatUsat = s === 0 && (op === 8 || op === 9 || op === 12 || op === 13);
      if (isSsatUsat) {
        const imm32 = hw1 >>> 12 & 7;
        const imm2 = hw1 >>> 6 & 3;
        const sat_imm = hw1 & 31;
        const isUsat = op >= 12;
        const satN = isUsat ? sat_imm : sat_imm + 1;
        const sh_type = op & 1;
        const shift = imm32 << 2 | imm2;
        let val = this.regs[rn];
        if (shift > 0) {
          val = sh_type ? this.asr(val, shift, false) : this.lsl(val, shift, false);
        }
        let result;
        if (isUsat) {
          const maxU = satN >= 32 ? 4294967295 : (1 << satN) - 1 >>> 0;
          const sv = s32(val);
          result = sv < 0 ? 0 : sv > maxU ? maxU : sv;
        } else {
          const maxS = satN >= 32 ? 2147483647 : (1 << satN - 1) - 1;
          const minS = satN >= 32 ? -2147483648 : -(1 << satN - 1);
          const sv = s32(val);
          result = sv > maxS ? maxS : sv < minS ? minS : sv;
        }
        this.regs[rd] = u32(result);
      } else if ((op & 13) === 0) {
        const a = rn === 15 ? u32(_pc + 4) : this.regs[rn];
        const r = u32(a + imm12);
        this.regs[rd] = r;
        if (s) this.setNZCV_add(a, imm12);
      } else if ((op & 13) === 4) {
        const a = rn === 15 ? u32(_pc + 4) : this.regs[rn];
        const r = u32(a - imm12);
        this.regs[rd] = r;
        if (s) this.setNZCV_sub(a, imm12);
      } else if (op === 14) {
        const imm32 = hw1 >>> 12 & 7;
        const imm2 = hw1 >>> 6 & 3;
        const lsb = imm32 << 2 | imm2;
        const widthm1 = hw1 & 31;
        const width = widthm1 + 1;
        const mask = width >= 32 ? 4294967295 : (1 << width) - 1;
        this.regs[rd] = u32(this.regs[rn] >>> lsb & mask);
      } else if (op === 10) {
        const imm32 = hw1 >>> 12 & 7;
        const imm2 = hw1 >>> 6 & 3;
        const lsb = imm32 << 2 | imm2;
        const widthm1 = hw1 & 31;
        const width = widthm1 + 1;
        const mask = width >= 32 ? 4294967295 : (1 << width) - 1;
        const raw = this.regs[rn] >>> lsb & mask;
        const shift = 32 - width;
        this.regs[rd] = u32(raw << shift >> shift);
      } else if (op === 11) {
        const imm32 = hw1 >>> 12 & 7;
        const imm2 = hw1 >>> 6 & 3;
        const lsb = imm32 << 2 | imm2;
        const msb = hw1 & 31;
        if (msb >= lsb) {
          const width = msb - lsb + 1;
          const widthMask = width >= 32 ? 4294967295 : (1 << width) - 1 >>> 0;
          const fieldMask = u32(widthMask << lsb);
          const cleared = u32(this.regs[rd] & ~fieldMask);
          if (rn === 15) {
            this.regs[rd] = cleared;
          } else {
            const src = u32((this.regs[rn] & widthMask) << lsb);
            this.regs[rd] = u32(cleared | src);
          }
        }
      }
      return 2;
    }
    const imm3 = hw1 >>> 12 & 7;
    const imm8 = hw1 & 255;
    const imm = decodeThumb2Imm(i << 11 | imm3 << 8 | imm8);
    switch (op) {
      case 0: {
        const r = u32(this.regs[rn] & imm);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZ(r);
        break;
      }
      case 1: {
        const r = u32(this.regs[rn] & ~imm);
        this.regs[rd] = r;
        if (s) this.setNZ(r);
        break;
      }
      case 2: {
        const r = rn === 15 ? imm : u32(this.regs[rn] | imm);
        this.regs[rd] = r;
        if (s) this.setNZ(r);
        break;
      }
      case 3: {
        const r = rn === 15 ? u32(~imm) : u32(this.regs[rn] | ~imm);
        this.regs[rd] = r;
        if (s) this.setNZ(r);
        break;
      }
      case 4: {
        const r = u32(this.regs[rn] ^ imm);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZ(r);
        break;
      }
      case 8: {
        const a = this.regs[rn];
        const r = u32(a + imm);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZCV_add(a, imm);
        break;
      }
      case 10: {
        const a = this.regs[rn];
        const c = this.flagC;
        const r = u32(a + imm + c);
        this.regs[rd] = r;
        if (s) {
          const r64 = (a >>> 0) + (imm >>> 0) + c;
          this.setN(r >>> 31 !== 0);
          this.setZ(r === 0);
          this.setC(r64 > 4294967295);
          this.setV((~(a ^ imm) & (a ^ r)) >>> 31 !== 0);
        }
        break;
      }
      case 11: {
        const a = this.regs[rn];
        const c = this.flagC;
        const r = u32(a - imm - (1 - c));
        this.regs[rd] = r;
        if (s) this.setNZCV_sub(a, imm);
        break;
      }
      case 13: {
        const a = this.regs[rn];
        const r = u32(a - imm);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZCV_sub(a, imm);
        break;
      }
      case 14: {
        const a = this.regs[rn];
        const r = u32(imm - a);
        this.regs[rd] = r;
        if (s) this.setNZCV_sub(imm, a);
        break;
      }
      default:
        break;
    }
    return 2;
  }
  // ─── 32-bit: Data-processing register (shifts, etc.) ─────────────────────
  exec32_dp_reg(hw0, hw1) {
    const op = hw0 >>> 5 & 15;
    const s = hw0 >>> 4 & 1;
    const rn = hw0 & 15;
    const rd = hw1 >>> 8 & 15;
    const rm = hw1 & 15;
    const imm3 = hw1 >>> 12 & 7;
    const imm2 = hw1 >>> 6 & 3;
    const shiftType = hw1 >>> 4 & 3;
    const shiftAmt = imm3 << 2 | imm2;
    let rmVal = this.regs[rm];
    if (shiftAmt > 0) {
      switch (shiftType) {
        case 0:
          rmVal = this.lsl(rmVal, shiftAmt, false);
          break;
        case 1:
          rmVal = this.lsr(rmVal, shiftAmt, false);
          break;
        case 2:
          rmVal = this.asr(rmVal, shiftAmt, false);
          break;
        case 3:
          rmVal = this.ror(rmVal, shiftAmt, false);
          break;
      }
    }
    switch (op) {
      case 0: {
        const r = u32(this.regs[rn] & rmVal);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZ(r);
        break;
      }
      case 1: {
        const r = u32(this.regs[rn] & ~rmVal);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZ(r);
        break;
      }
      case 2: {
        if (rn === 15) {
          if (rd !== 15) this.regs[rd] = rmVal;
          if (s) this.setNZ(rmVal);
        } else {
          const r = u32(this.regs[rn] | rmVal);
          if (rd !== 15) this.regs[rd] = r;
          if (s) this.setNZ(r);
        }
        break;
      }
      case 3: {
        if (rn === 15) {
          const r = u32(~rmVal);
          if (rd !== 15) this.regs[rd] = r;
          if (s) this.setNZ(r);
        } else {
          const r = u32(this.regs[rn] | ~rmVal);
          if (rd !== 15) this.regs[rd] = r;
          if (s) this.setNZ(r);
        }
        break;
      }
      case 4: {
        const r = u32(this.regs[rn] ^ rmVal);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZ(r);
        break;
      }
      case 6: {
        const r = this.lsl(rmVal, this.regs[rn] & 255, s !== 0);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZ(r);
        break;
      }
      case 8: {
        const a = this.regs[rn];
        const r = u32(a + rmVal);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZCV_add(a, rmVal);
        break;
      }
      case 10: {
        const a = this.regs[rn];
        const c = this.flagC;
        const r = u32(a + rmVal + c);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZCV_add(a, rmVal + c);
        break;
      }
      case 13: {
        const a = this.regs[rn];
        const r = u32(a - rmVal);
        if (rd !== 15) this.regs[rd] = r;
        if (s) this.setNZCV_sub(a, rmVal);
        break;
      }
      case 14: {
        const a = this.regs[rn];
        const r = u32(rmVal - a);
        this.regs[rd] = r;
        if (s) this.setNZCV_sub(rmVal, a);
        break;
      }
      // TST / TEQ / CMP / CMN (no Rd)
      default:
        break;
    }
    return 1;
  }
  // ─── 32-bit: Extend instructions ─────────────────────────────────────────
  //
  // Encoding space 0xFA00-0xFA7F holds TWO families distinguished by hw1[7]:
  //   hw1[7]=0: LSL/LSR/ASR/ROR (register) T2 — shift Rm by amount in low byte of Rn
  //   hw1[7]=1: SXTH/UXTH/SXTB/UXTB.W (with optional Rn=add-source)
  //
  // We used to dispatch the whole space to the extend handler, which silently
  // dropped LSL/LSR/ASR/ROR — those shifts were a no-op in firmware, which
  // made any `value >> bit_index` produce wrong results.
  exec32_extend(hw0, hw1) {
    if ((hw1 >>> 4 & 15) === 0) {
      return this.exec32_shift_reg(hw0, hw1);
    }
    const rd = hw1 >>> 8 & 15;
    const rm = hw1 & 15;
    const op2 = hw0 >>> 4 & 7;
    const rotate = (hw1 >>> 4 & 3) << 3;
    let src = this.regs[rm];
    if (rotate) src = ror32(src, rotate);
    const rn = hw0 & 15;
    switch (op2) {
      case 0: {
        const ext = u32(src << 16 >> 16);
        this.regs[rd] = rn === 15 ? ext : u32(this.regs[rn] + ext);
        break;
      }
      case 1: {
        const ext = src & 65535;
        this.regs[rd] = rn === 15 ? ext : u32(this.regs[rn] + ext);
        break;
      }
      case 4: {
        const ext = u32(src << 24 >> 24);
        this.regs[rd] = rn === 15 ? ext : u32(this.regs[rn] + ext);
        break;
      }
      case 5: {
        const ext = src & 255;
        this.regs[rd] = rn === 15 ? ext : u32(this.regs[rn] + ext);
        break;
      }
    }
    return 1;
  }
  // ── Shift-by-register T2 (LSL/LSR/ASR/ROR) ─────────────────────────────
  // Encoding (ARMv7-M ARM A6.7.65 LSR, similar for LSL/ASR/ROR):
  //   hw0 = 1111_1010_TT_S_Rm_n   (low nibble = "Rn" = value source)
  //   hw1 = 1111_Rd_0000_Rm_s     (low nibble = "Rm" = shift register)
  //
  // ARM's field naming is unintuitive here: the disassembly
  //   `LSR.W Rd, <value>, <shift>` corresponds to encoded
  //   Rn = <value>, Rm = <shift>.
  //
  // We had these reversed once and it made `(in0 >> bit_number)` return the
  // wrong byte, producing $80 instead of $7F for the self-test IN0 bit and
  // wedging the firmware in the $680f BMI-self-loop.
  exec32_shift_reg(hw0, hw1) {
    const tt = hw0 >>> 5 & 3;
    const s = hw0 >>> 4 & 1;
    const rn_value = hw0 & 15;
    const rd = hw1 >>> 8 & 15;
    const rm_shift = hw1 & 15;
    const shift = this.regs[rm_shift] & 255;
    const val = this.regs[rn_value];
    let result;
    if (shift === 0) {
      result = val;
    } else {
      switch (tt) {
        case 0:
          result = this.lsl(val, shift, true);
          break;
        case 1:
          result = this.lsr(val, shift, true);
          break;
        case 2:
          result = this.asr(val, shift, true);
          break;
        case 3:
          result = ror32(val, shift & 31);
          break;
        default:
          result = val;
      }
    }
    this.regs[rd] = result;
    if (s) this.setNZ(result);
    return 1;
  }
  // ─── Utility ──────────────────────────────────────────────────────────────
  bitCount(n) {
    let count = 0;
    n = n | 0;
    while (n) {
      count += n & 1;
      n >>>= 1;
    }
    return count;
  }
};
export {
  Thumb2
};
