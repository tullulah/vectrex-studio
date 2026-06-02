/**
 * Psg — AY-3-8910 Programmable Sound Generator.
 *
 * Mirrors the e8910.js section of vecx_full.js (lines 3249–3647).
 * The PSG is driven by the VIA: ORB bits 4:3 select BDIR/BC1, ORA carries
 * the data/address.  The VIA calls `write(bdir, bc1, data)` when ORB or ORA
 * changes, and `getRegister()` when the CPU reads back a register value
 * (e.g. register 14 for controller buttons).
 *
 * Audio output path: Phase 1 preserves the structure but leaves `tick()`
 * as a no-op.  Phase 2 will wire this to the Web Audio ScriptProcessor.
 */

// ------------------------------------------------------------------ //
// Register indices (matching AY_* constants in vecx_full.js)
// ------------------------------------------------------------------ //
const AY_AFINE   = 0;
const AY_ACOARSE = 1;
const AY_BFINE   = 2;
const AY_BCOARSE = 3;
const AY_CFINE   = 4;
const AY_CCOARSE = 5;
const AY_NOISEPER = 6;
const AY_ENABLE  = 7;
const AY_AVOL    = 8;
const AY_BVOL    = 9;
const AY_CVOL    = 10;
const AY_EFINE   = 11;
const AY_ECOARSE = 12;
const AY_ESHAPE  = 13;
// Registers 14 and 15 are I/O ports (14 = controller buttons)

const STEP3 = 1; // matches vecx_full.js

const MAX_OUTPUT = 0x0fff;

export class Psg {
  // ------------------------------------------------------------------ //
  // Internal PSG state (mirrors `psg` object in e8910())
  // ------------------------------------------------------------------ //
  private index: number      = 0; // currently selected register
  private ready: number      = 0;
  private lastEnable: number = 0;

  private PeriodA: number = 0;
  private PeriodB: number = 0;
  private PeriodC: number = 0;
  private PeriodN: number = 0;
  private PeriodE: number = 0;
  private CountA: number  = 0;
  private CountB: number  = 0;
  private CountC: number  = 0;
  private CountN: number  = 0;
  private CountE: number  = 0;
  private VolA: number    = 0;
  private VolB: number    = 0;
  private VolC: number    = 0;
  private VolE: number    = 0;
  private EnvelopeA: number = 0;
  private EnvelopeB: number = 0;
  private EnvelopeC: number = 0;
  private OutputA: number  = 0;
  private OutputB: number  = 0;
  private OutputC: number  = 0;
  private OutputN: number  = 0xff;
  private CountEnv: number = 0;
  private Hold: number     = 0;
  private Alternate: number = 0;
  private Attack: number   = 0;
  private Holding: number  = 0;
  private RNG: number      = 1;
  private VolTable: number[] = new Array<number>(32).fill(0);

  /** The 16 AY registers (publicly accessible so VIA can share the array). */
  readonly Regs: number[] = new Array<number>(16).fill(0);

  constructor() {
    this.buildMixerTable();
  }

  // ------------------------------------------------------------------ //
  // Mixer table (matches e8910_build_mixer_table in vecx_full.js)
  // ------------------------------------------------------------------ //
  private buildMixerTable(): void {
    let out = MAX_OUTPUT;
    for (let i = 31; i > 0; i--) {
      this.VolTable[i] = (out + 0.5) | 0;
      out /= 1.188502227; // 1.5 dB step
    }
    this.VolTable[0] = 0;
  }

  // ------------------------------------------------------------------ //
  // reset — mirrors e8910.init() in vecx_full.js
  // ------------------------------------------------------------------ //
  reset(): void {
    this.RNG      = 1;
    this.OutputA  = 0;
    this.OutputB  = 0;
    this.OutputC  = 0;
    this.OutputN  = 0xff;
    this.ready    = 0;
    this.index    = 0;
    this.Regs.fill(0);
    // Controller buttons default to all-released (active-low, so 0xFF)
    this.Regs[14] = 0xff;
    this.writeRegister(14, 0xff);
    // Initialise all periods to STEP3 (=1) so fillBuffer() never divides by
    // zero or spins in an infinite while-loop before any PSG writes arrive.
    this.PeriodA = STEP3;
    this.PeriodB = STEP3;
    this.PeriodC = STEP3;
    this.PeriodN = STEP3;
    this.PeriodE = STEP3;
    this.CountA  = STEP3;
    this.CountB  = STEP3;
    this.CountC  = STEP3;
    this.CountN  = STEP3;
    this.CountE  = STEP3;
    this.ready   = 1;  // safe to call fillBuffer() from now on
  }

  // ------------------------------------------------------------------ //
  // Register write — mirrors e8910_write in vecx_full.js
  // ------------------------------------------------------------------ //
  private writeRegister(r: number, v: number): void {
    this.Regs[r] = v;
    switch (r) {
      case AY_AFINE:
      case AY_ACOARSE: {
        this.Regs[AY_ACOARSE] &= 0x0f;
        const old = this.PeriodA;
        this.PeriodA = (this.Regs[AY_AFINE] + 256 * this.Regs[AY_ACOARSE]) * STEP3;
        if (this.PeriodA === 0) this.PeriodA = STEP3;
        this.CountA += this.PeriodA - old;
        if (this.CountA <= 0) this.CountA = 1;
        break;
      }
      case AY_BFINE:
      case AY_BCOARSE: {
        this.Regs[AY_BCOARSE] &= 0x0f;
        const old = this.PeriodB;
        this.PeriodB = (this.Regs[AY_BFINE] + 256 * this.Regs[AY_BCOARSE]) * STEP3;
        if (this.PeriodB === 0) this.PeriodB = STEP3;
        this.CountB += this.PeriodB - old;
        if (this.CountB <= 0) this.CountB = 1;
        break;
      }
      case AY_CFINE:
      case AY_CCOARSE: {
        this.Regs[AY_CCOARSE] &= 0x0f;
        const old = this.PeriodC;
        this.PeriodC = (this.Regs[AY_CFINE] + 256 * this.Regs[AY_CCOARSE]) * STEP3;
        if (this.PeriodC === 0) this.PeriodC = STEP3;
        this.CountC += this.PeriodC - old;
        if (this.CountC <= 0) this.CountC = 1;
        break;
      }
      case AY_NOISEPER: {
        this.Regs[AY_NOISEPER] &= 0x1f;
        const old = this.PeriodN;
        this.PeriodN = this.Regs[AY_NOISEPER] * STEP3;
        if (this.PeriodN === 0) this.PeriodN = STEP3;
        this.CountN += this.PeriodN - old;
        if (this.CountN <= 0) this.CountN = 1;
        break;
      }
      case AY_ENABLE:
        this.lastEnable = this.Regs[AY_ENABLE];
        break;

      case AY_AVOL:
        this.Regs[AY_AVOL] &= 0x1f;
        this.EnvelopeA = this.Regs[AY_AVOL] & 0x10;
        this.VolA = this.EnvelopeA
          ? this.VolE
          : this.VolTable[this.Regs[AY_AVOL] ? this.Regs[AY_AVOL] * 2 + 1 : 0];
        break;

      case AY_BVOL:
        this.Regs[AY_BVOL] &= 0x1f;
        this.EnvelopeB = this.Regs[AY_BVOL] & 0x10;
        this.VolB = this.EnvelopeB
          ? this.VolE
          : this.VolTable[this.Regs[AY_BVOL] ? this.Regs[AY_BVOL] * 2 + 1 : 0];
        break;

      case AY_CVOL:
        this.Regs[AY_CVOL] &= 0x1f;
        this.EnvelopeC = this.Regs[AY_CVOL] & 0x10;
        this.VolC = this.EnvelopeC
          ? this.VolE
          : this.VolTable[this.Regs[AY_CVOL] ? this.Regs[AY_CVOL] * 2 + 1 : 0];
        break;

      case AY_EFINE:
      case AY_ECOARSE: {
        const old = this.PeriodE;
        this.PeriodE = (this.Regs[AY_EFINE] + 256 * this.Regs[AY_ECOARSE]) * STEP3;
        if (this.PeriodE === 0) this.PeriodE = STEP3;
        this.CountE += this.PeriodE - old;
        if (this.CountE <= 0) this.CountE = 1;
        break;
      }
      case AY_ESHAPE:
        this.Regs[AY_ESHAPE] &= 0x0f;
        this.Attack = (this.Regs[AY_ESHAPE] & 0x04) ? 0x1f : 0x00;
        if ((this.Regs[AY_ESHAPE] & 0x08) === 0) {
          this.Hold      = 1;
          this.Alternate = this.Attack;
        } else {
          this.Hold      = this.Regs[AY_ESHAPE] & 0x01;
          this.Alternate = this.Regs[AY_ESHAPE] & 0x02;
        }
        this.CountE    = this.PeriodE;
        this.CountEnv  = 0x1f;
        this.Holding   = 0;
        this.VolE      = this.VolTable[this.CountEnv ^ this.Attack];
        if (this.EnvelopeA) this.VolA = this.VolE;
        if (this.EnvelopeB) this.VolB = this.VolE;
        if (this.EnvelopeC) this.VolC = this.VolE;
        break;

      // Ports 14 and 15 — no extra logic; value already stored in Regs[]
      default:
        break;
    }
  }

  // ------------------------------------------------------------------ //
  // VIA bus interface — mirrors snd_update() in vecx_full.js
  // ------------------------------------------------------------------ //
  /**
   * Called by VIA whenever ORB or ORA changes.
   * `bdir` corresponds to ORB bit 4; `bc1` to ORB bit 3.
   *
   * In Vectrex terms (from snd_update):
   *   via_orb & 0x18 == 0x00  → disabled
   *   via_orb & 0x18 == 0x08  → PSG sending (read mode — CPU reads Regs via ORA)
   *   via_orb & 0x18 == 0x10  → PSG receiving data (write Regs[index] = ORA)
   *   via_orb & 0x18 == 0x18  → latch address (index = ORA & 0x0f, if high nibble == 0)
   */
  write(via_orb: number, via_ora: number): void {
    switch (via_orb & 0x18) {
      case 0x00:
        // Disabled — nothing to do
        break;
      case 0x08:
        // PSG driving bus — reads handled through getRegister()
        break;
      case 0x10:
        // Write data to selected register
        if (this.index !== 14) {
          this.writeRegister(this.index, via_ora);
        }
        break;
      case 0x18:
        // Latch address
        if ((via_ora & 0xf0) === 0x00) {
          this.index = via_ora & 0x0f;
        }
        break;
    }
  }

  /**
   * Read the currently selected register value.
   * Used by VIA read() for case 0xf when the PSG is driving the bus.
   */
  getRegister(reg: number): number {
    return this.Regs[reg] & 0xff;
  }

  /** Currently latched register index. */
  get selectedRegister(): number { return this.index; }

  // ------------------------------------------------------------------ //
  // tick — no-op (audio synthesis happens in fillBuffer)
  // ------------------------------------------------------------------ //
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  tick(_cycles: number): void {}

  // ------------------------------------------------------------------ //
  // fillBuffer — AY-3-8910 PCM synthesis (port of e8910_callback from vecx_full.js)
  // ------------------------------------------------------------------ //
  /**
   * Fill `stream` with `length` mono Float32 audio samples [-1, 1].
   * Called directly by the ScriptProcessor's onaudioprocess handler.
   *
   * Algorithm mirrors e8910_callback in vecx_full.js (lines 3444–3608).
   * STEP3=1, STEP=2: each outer loop processes 2 sub-steps and produces
   * one sample every 2 outer iterations (checked via `--len & 1`).
   */
  fillBuffer(stream: Float32Array, length: number): void {
    const STEP  = 2;
    const STEP2 = STEP;

    let idx = 0;

    // Warm-up: ensure channel counters are large enough to avoid wrap at start
    if (this.Regs[AY_ENABLE] & 0x01) {
      if (this.CountA <= STEP2) this.CountA += STEP2;
      this.OutputA = 1;
    } else if (this.Regs[AY_AVOL] === 0) {
      if (this.CountA <= STEP2) this.CountA += STEP2;
    }
    if (this.Regs[AY_ENABLE] & 0x02) {
      if (this.CountB <= STEP2) this.CountB += STEP2;
      this.OutputB = 1;
    } else if (this.Regs[AY_BVOL] === 0) {
      if (this.CountB <= STEP2) this.CountB += STEP2;
    }
    if (this.Regs[AY_ENABLE] & 0x04) {
      if (this.CountC <= STEP2) this.CountC += STEP2;
      this.OutputC = 1;
    } else if (this.Regs[AY_CVOL] === 0) {
      if (this.CountC <= STEP2) this.CountC += STEP2;
    }
    if ((this.Regs[AY_ENABLE] & 0x38) === 0x38) {
      if (this.CountN <= STEP2) this.CountN += STEP2;
    }

    let outn = (this.OutputN | this.Regs[AY_ENABLE]);

    // Double the loop count: every other iteration emits a sample
    let len = length << 1;

    while (len > 0) {
      let vola = 0, volb = 0, volc = 0;
      let left = STEP;

      do {
        const nextevent = this.CountN < left ? this.CountN : left;

        // Channel A
        if (outn & 0x08) {
          if (this.OutputA) vola += this.CountA;
          this.CountA -= nextevent;
          while (this.CountA <= 0) {
            this.CountA += this.PeriodA;
            if (this.CountA > 0) {
              this.OutputA ^= 1;
              if (this.OutputA) vola += this.PeriodA;
              break;
            }
            this.CountA += this.PeriodA;
            vola += this.PeriodA;
          }
          if (this.OutputA) vola -= this.CountA;
        } else {
          this.CountA -= nextevent;
          while (this.CountA <= 0) {
            this.CountA += this.PeriodA;
            if (this.CountA > 0) { this.OutputA ^= 1; break; }
            this.CountA += this.PeriodA;
          }
        }

        // Channel B
        if (outn & 0x10) {
          if (this.OutputB) volb += this.CountB;
          this.CountB -= nextevent;
          while (this.CountB <= 0) {
            this.CountB += this.PeriodB;
            if (this.CountB > 0) {
              this.OutputB ^= 1;
              if (this.OutputB) volb += this.PeriodB;
              break;
            }
            this.CountB += this.PeriodB;
            volb += this.PeriodB;
          }
          if (this.OutputB) volb -= this.CountB;
        } else {
          this.CountB -= nextevent;
          while (this.CountB <= 0) {
            this.CountB += this.PeriodB;
            if (this.CountB > 0) { this.OutputB ^= 1; break; }
            this.CountB += this.PeriodB;
          }
        }

        // Channel C
        if (outn & 0x20) {
          if (this.OutputC) volc += this.CountC;
          this.CountC -= nextevent;
          while (this.CountC <= 0) {
            this.CountC += this.PeriodC;
            if (this.CountC > 0) {
              this.OutputC ^= 1;
              if (this.OutputC) volc += this.PeriodC;
              break;
            }
            this.CountC += this.PeriodC;
            volc += this.PeriodC;
          }
          if (this.OutputC) volc -= this.CountC;
        } else {
          this.CountC -= nextevent;
          while (this.CountC <= 0) {
            this.CountC += this.PeriodC;
            if (this.CountC > 0) { this.OutputC ^= 1; break; }
            this.CountC += this.PeriodC;
          }
        }

        // Noise
        this.CountN -= nextevent;
        if (this.CountN <= 0) {
          if ((this.RNG + 1) & 2) {
            this.OutputN = (~this.OutputN & 0xff);
            outn = (this.OutputN | this.Regs[AY_ENABLE]);
          }
          if (this.RNG & 1) this.RNG ^= 0x24000;
          this.RNG >>= 1;
          this.CountN += this.PeriodN;
        }

        left -= nextevent;
      } while (left > 0);

      // Envelope
      if (this.Holding === 0) {
        this.CountE -= STEP3;
        if (this.CountE <= 0) {
          do {
            this.CountEnv--;
            this.CountE += this.PeriodE;
          } while (this.CountE <= 0);

          if (this.CountEnv < 0) {
            if (this.Hold) {
              if (this.Alternate) this.Attack ^= 0x1f;
              this.Holding = 1;
              this.CountEnv = 0;
            } else {
              if (this.Alternate && (this.CountEnv & 0x20)) this.Attack ^= 0x1f;
              this.CountEnv &= 0x1f;
            }
          }

          this.VolE = this.VolTable[this.CountEnv ^ this.Attack];
          if (this.EnvelopeA) this.VolA = this.VolE;
          if (this.EnvelopeB) this.VolB = this.VolE;
          if (this.EnvelopeC) this.VolC = this.VolE;
        }
      }

      const vol = (vola * this.VolA + volb * this.VolB + volc * this.VolC) / (3 * STEP);
      if (--len & 1) {
        stream[idx++] = vol / MAX_OUTPUT;
      }
    }
  }
}
