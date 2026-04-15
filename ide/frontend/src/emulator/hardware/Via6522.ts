/**
 * Via6522 — MOS 6522 Versatile Interface Adapter.
 *
 * Mirrors the VIA state and read/write/tick logic from the vecx.js section of
 * vecx_full.js (lines 4067–4807).  The VIA is the central hub of the Vectrex:
 * it drives the timers that trigger the Wait_Recal IRQ, the shift register that
 * controls the beam-blank signal (CB2), the sound-chip bus (ORA / ORB), and
 * the joystick/comparator inputs.
 *
 * Calls into Beam and Psg are delivered through callbacks rather than hard
 * imports to avoid circular dependencies and to keep the coupling explicit.
 */

export type AlgUpdateCallback = (
  via_ora: number,
  via_orb: number,
  via_acr: number,
  via_pcr: number,
  via_cb2h: number,
  via_cb2s: number,
) => void;

export type SndUpdateCallback = (via_orb: number, via_ora: number) => void;

export class Via6522 {
  // ------------------------------------------------------------------ //
  // Port registers
  // ------------------------------------------------------------------ //
  /** Output Register B */
  via_orb: number = 0;
  /** Output Register A */
  via_ora: number = 0;
  /**
   * Joystick button input mask for Port B bits 4-7 (active-low).
   * Default 0xF0 = all buttons released (1 = not pressed).
   * Set by the host system to reflect real button state.
   */
  joyButtons: number = 0xF0;
  /** Data Direction Register A */
  via_ddra: number = 0;
  /** Data Direction Register B */
  via_ddrb: number = 0;

  // ------------------------------------------------------------------ //
  // Timer 1
  // ------------------------------------------------------------------ //
  /** Timer 1 running flag */
  via_t1on: number = 0;
  /** Timer 1 interrupt-enable flag */
  via_t1int: number = 0;
  /** Timer 1 counter (16-bit) */
  via_t1c: number = 0;
  /** Timer 1 low latch */
  via_t1ll: number = 0;
  /** Timer 1 high latch */
  via_t1lh: number = 0;
  /** Timer 1 PB7 control bit */
  via_t1pb7: number = 0x80;

  // ------------------------------------------------------------------ //
  // Timer 2
  // ------------------------------------------------------------------ //
  /** Timer 2 running flag */
  via_t2on: number = 0;
  /** Timer 2 interrupt-enable flag */
  via_t2int: number = 0;
  /** Timer 2 counter (16-bit) */
  via_t2c: number = 0;
  /** Timer 2 low latch */
  via_t2ll: number = 0;

  // ------------------------------------------------------------------ //
  // Shift Register
  // ------------------------------------------------------------------ //
  /** Shift register data */
  via_sr: number = 0;
  /** Number of bits shifted so far */
  via_srb: number = 8;
  /** Shift counter */
  via_src: number = 0;
  /** Shift clock phase */
  via_srclk: number = 0;

  // ------------------------------------------------------------------ //
  // Control / interrupt registers
  // ------------------------------------------------------------------ //
  /** Auxiliary Control Register */
  via_acr: number = 0;
  /** Peripheral Control Register */
  via_pcr: number = 0;
  /** Interrupt Flag Register */
  via_ifr: number = 0;
  /** Interrupt Enable Register */
  via_ier: number = 0;

  // ------------------------------------------------------------------ //
  // CA2 / CB2 handshake lines
  // ------------------------------------------------------------------ //
  /** CA2 handshake output (0 = low, 1 = high) */
  via_ca2: number = 1;
  /** CB2 basic handshake version */
  via_cb2h: number = 1;
  /** CB2 version controlled by shift register */
  via_cb2s: number = 0;

  // ------------------------------------------------------------------ //
  // Internal
  // ------------------------------------------------------------------ //
  private t2shift: number = 0;

  private readonly onAlgUpdate: AlgUpdateCallback;
  private readonly onSndUpdate: SndUpdateCallback;

  constructor(onAlgUpdate: AlgUpdateCallback, onSndUpdate: SndUpdateCallback) {
    this.onAlgUpdate = onAlgUpdate;
    this.onSndUpdate = onSndUpdate;
  }

  // ------------------------------------------------------------------ //
  // Helpers
  // ------------------------------------------------------------------ //

  private intUpdate(): void {
    if ((this.via_ifr & 0x7f) & (this.via_ier & 0x7f)) {
      this.via_ifr |= 0x80;
    } else {
      this.via_ifr &= 0x7f;
    }
  }

  private algUpdate(): void {
    this.onAlgUpdate(
      this.via_ora,
      this.via_orb,
      this.via_acr,
      this.via_pcr,
      this.via_cb2h,
      this.via_cb2s,
    );
  }

  private sndUpdate(): void {
    this.onSndUpdate(this.via_orb, this.via_ora);
  }

  // ------------------------------------------------------------------ //
  // Public API
  // ------------------------------------------------------------------ //

  reset(): void {
    this.via_ora   = 0;
    this.via_orb   = 0;
    this.via_ddra  = 0;
    this.via_ddrb  = 0;
    this.joyButtons = 0xF0;
    this.via_t1on  = 0;
    this.via_t1int = 0;
    this.via_t1c   = 0;
    this.via_t1ll  = 0;
    this.via_t1lh  = 0;
    this.via_t1pb7 = 0x80;
    this.via_t2on  = 0;
    this.via_t2int = 0;
    this.via_t2c   = 0;
    this.via_t2ll  = 0;
    this.via_sr    = 0;
    this.via_srb   = 8;
    this.via_src   = 0;
    this.via_srclk = 0;
    this.via_acr   = 0;
    this.via_pcr   = 0;
    this.via_ifr   = 0;
    this.via_ier   = 0;
    this.via_ca2   = 1;
    this.via_cb2h  = 1;
    this.via_cb2s  = 0;
  }

  /**
   * Read a VIA register.
   * `reg` is bits [3:0] of the address (0x0–0xe), matching vecx.js case labels.
   * The caller passes additional state needed for ORB reads (alg_compare, via_t1pb7).
   */
  read(
    reg: number,
    alg_compare: number,
    snd_regs: number[],
    snd_select: number,
  ): number {
    switch (reg & 0xf) {
      case 0x0:
        // ORB — bit 7 may be driven by Timer 1; bit 5 is comparator input.
        // Bits 4-7 are J1 button inputs (active-low, 1=released). They come from
        // joyButtons rather than via_orb (which only drives output bits).
        if (this.via_acr & 0x80) {
          return ((this.via_orb & 0x5f) | this.via_t1pb7 | alg_compare | (this.joyButtons & 0xF0)) & 0xff;
        }
        return ((this.via_orb & 0xdf) | alg_compare | (this.joyButtons & 0xF0)) & 0xff;

      case 0x1:
        // ORA with CA2 handshake
        if ((this.via_pcr & 0x0e) === 0x08) {
          this.via_ca2 = 0;
        }
        // fall through to 0xf
        /* falls through */
      case 0xf:
        if ((this.via_orb & 0x18) === 0x08) {
          // PSG driving port A
          return snd_regs[snd_select] & 0xff;
        }
        return this.via_ora & 0xff;

      case 0x2:
        return this.via_ddrb & 0xff;

      case 0x3:
        return this.via_ddra & 0xff;

      case 0x4: {
        // T1 low counter — clears T1 interrupt flag, stops timer
        const data = this.via_t1c;
        this.via_ifr &= 0xbf;
        this.via_t1on  = 0;
        this.via_t1int = 0;
        this.via_t1pb7 = 0x80;
        this.intUpdate();
        return data & 0xff;
      }

      case 0x5:
        return (this.via_t1c >> 8) & 0xff;

      case 0x6:
        return this.via_t1ll & 0xff;

      case 0x7:
        return this.via_t1lh & 0xff;

      case 0x8: {
        // T2 low counter — clears T2 interrupt flag, stops timer
        const data = this.via_t2c;
        this.via_ifr &= 0xdf;
        this.via_t2on  = 0;
        this.via_t2int = 0;
        this.intUpdate();
        return data & 0xff;
      }

      case 0x9:
        return (this.via_t2c >> 8) & 0xff;

      case 0xa: {
        // Shift Register — clears SR interrupt flag, resets bit counter
        const data = this.via_sr;
        this.via_ifr  &= 0xfb;
        this.via_srb   = 0;
        this.via_srclk = 1;
        this.intUpdate();
        return data & 0xff;
      }

      case 0xb:
        return this.via_acr & 0xff;

      case 0xc:
        return this.via_pcr & 0xff;

      case 0xd:
        return this.via_ifr & 0xff;

      case 0xe:
        return (this.via_ier | 0x80) & 0xff;

      default:
        return 0xff;
    }
  }

  /**
   * Write a VIA register.
   * `reg` is bits [3:0] of the address.
   * alg_xsh is passed so that ORA writes can update the DAC sample-and-hold.
   */
  write(
    reg: number,
    data: number,
    onAlgXsh: (xsh: number) => void,
  ): void {
    data &= 0xff;
    switch (reg & 0xf) {
      case 0x0:
        this.via_orb = data;
        this.sndUpdate();
        this.algUpdate();
        if ((this.via_pcr & 0xe0) === 0x80) {
          // CB2 pulse/handshake mode: goes low on ORB write
          this.via_cb2h = 0;
        }
        break;

      case 0x1:
        // CA2 pulse/handshake: goes low on ORA write
        if ((this.via_pcr & 0x0e) === 0x08) {
          this.via_ca2 = 0;
        }
        /* falls through */
      case 0xf:
        this.via_ora = data;
        this.sndUpdate();
        // ORA feeds the DAC → X sample-and-hold (XOR 0x80 to convert unsigned→signed)
        onAlgXsh(data ^ 0x80);
        this.algUpdate();
        break;

      case 0x2:
        this.via_ddrb = data;
        break;

      case 0x3:
        this.via_ddra = data;
        break;

      case 0x4:
        // T1 low latch only
        this.via_t1ll = data;
        break;

      case 0x5:
        // T1 high latch + start timer
        this.via_t1lh = data;
        this.via_t1c  = (this.via_t1lh << 8) | this.via_t1ll;
        this.via_ifr &= 0xbf;
        this.via_t1on  = 1;
        this.via_t1int = 1;
        this.via_t1pb7 = 0;
        this.intUpdate();
        break;

      case 0x6:
        this.via_t1ll = data;
        break;

      case 0x7:
        this.via_t1lh = data;
        break;

      case 0x8:
        this.via_t2ll = data;
        break;

      case 0x9:
        // T2 high + start timer
        this.via_t2c  = (data << 8) | this.via_t2ll;
        this.via_ifr &= 0xdf;
        this.via_t2on  = 1;
        this.via_t2int = 1;
        this.intUpdate();
        break;

      case 0xa:
        // Shift Register write
        this.via_sr    = data;
        this.via_ifr  &= 0xfb;
        this.via_srb   = 0;
        this.via_srclk = 1;
        this.intUpdate();
        break;

      case 0xb:
        this.via_acr = data;
        break;

      case 0xc:
        this.via_pcr = data;
        // CA2 output
        this.via_ca2  = ((this.via_pcr & 0x0e) === 0x0c) ? 0 : 1;
        // CB2 output
        this.via_cb2h = ((this.via_pcr & 0xe0) === 0xc0) ? 0 : 1;
        break;

      case 0xd:
        // IFR — writing 1 clears the corresponding flag
        this.via_ifr &= ~(data & 0x7f);
        this.intUpdate();
        break;

      case 0xe:
        // IER — bit 7 determines set (1) or clear (0)
        if (data & 0x80) {
          this.via_ier |= data & 0x7f;
        } else {
          this.via_ier &= ~(data & 0x7f);
        }
        this.intUpdate();
        break;
    }
  }

  /**
   * Advance VIA emulation by one clock cycle.
   *
   * This is the inlined via_sstep0 + via_sstep1 logic from vecx_emu()
   * (vecx_full.js lines 5356–5701).  Called once per CPU cycle inside the
   * main emulation loop.
   */
  tick(): void {
    // --- via_sstep0 ---

    this.t2shift = 0;

    // Timer 1
    if (this.via_t1on) {
      this.via_t1c = this.via_t1c > 0 ? this.via_t1c - 1 : 0xffff;
      if ((this.via_t1c & 0xffff) === 0xffff) {
        if (this.via_acr & 0x40) {
          // Continuous mode: reload and toggle PB7
          this.via_ifr |= 0x40;
          this.intUpdate();
          this.via_t1pb7 = 0x80 - this.via_t1pb7;
          this.via_t1c = (this.via_t1lh << 8) | this.via_t1ll;
        } else {
          // One-shot mode
          if (this.via_t1int) {
            this.via_ifr |= 0x40;
            this.intUpdate();
            this.via_t1pb7 = 0x80;
            this.via_t1int = 0;
          }
        }
      }
    }

    // Timer 2 (pulse-counting disabled when ACR bit 5 is set)
    if (this.via_t2on && (this.via_acr & 0x20) === 0x00) {
      this.via_t2c = this.via_t2c > 0 ? this.via_t2c - 1 : 0xffff;
      if ((this.via_t2c & 0xffff) === 0xffff) {
        if (this.via_t2int) {
          this.via_ifr |= 0x20;
          this.intUpdate();
          this.via_t2int = 0;
        }
      }
    }

    // Shift register clock
    this.via_src = this.via_src > 0 ? this.via_src - 1 : 0xff;
    if ((this.via_src & 0xff) === 0xff) {
      this.via_src = this.via_t2ll;
      if (this.via_srclk) {
        this.t2shift   = 1;
        this.via_srclk = 0;
      } else {
        this.t2shift   = 0;
        this.via_srclk = 1;
      }
    } else {
      this.t2shift = 0;
    }

    // Shift register operation
    if (this.via_srb < 8) {
      switch (this.via_acr & 0x1c) {
        case 0x00:
          // Disabled
          break;
        case 0x04:
          // Shift in under T2 control
          if (this.t2shift) {
            this.via_sr <<= 1;
            this.via_srb++;
          }
          break;
        case 0x08:
          // Shift in under system clock
          this.via_sr <<= 1;
          this.via_srb++;
          break;
        case 0x0c:
          // Shift in under CB1 control (not emulated)
          break;
        case 0x10:
          // Shift out under T2 free-run
          if (this.t2shift) {
            this.via_cb2s = (this.via_sr >> 7) & 1;
            this.via_sr   = ((this.via_sr << 1) | this.via_cb2s) & 0xff;
          }
          break;
        case 0x14:
          // Shift out under T2
          if (this.t2shift) {
            this.via_cb2s = (this.via_sr >> 7) & 1;
            this.via_sr   = ((this.via_sr << 1) | this.via_cb2s) & 0xff;
            this.via_srb++;
          }
          break;
        case 0x18:
          // Shift out under system clock
          this.via_cb2s = (this.via_sr >> 7) & 1;
          this.via_sr   = ((this.via_sr << 1) | this.via_cb2s) & 0xff;
          this.via_srb++;
          break;
        case 0x1c:
          // Shift out under CB1 (not emulated)
          break;
      }

      if (this.via_srb === 8) {
        this.via_ifr |= 0x04;
        this.intUpdate();
      }
    }

    // --- via_sstep1 ---

    // CA2 pulse mode: restore high after one cycle
    if ((this.via_pcr & 0x0e) === 0x0a) {
      this.via_ca2 = 1;
    }

    // CB2 pulse mode: restore high after one cycle
    if ((this.via_pcr & 0xe0) === 0xa0) {
      this.via_cb2h = 1;
    }
  }

  /** True when IRQ line should be asserted to the CPU (IFR bit 7). */
  get irqActive(): boolean {
    return (this.via_ifr & 0x80) !== 0;
  }
}
