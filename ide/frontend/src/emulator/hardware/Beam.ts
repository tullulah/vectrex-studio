/**
 * Beam — Vectrex analog vector generator.
 *
 * Models the sample-and-hold circuits, integrators, and beam-blank signal
 * that together produce the vector display.  Mirrors the alg_* state and
 * inline alg_sstep logic from vecx_full.js (lines 4120–4331, 5134–5198,
 * 5545–5676).
 *
 * The Beam does not own a canvas.  It accumulates line segments in its draw
 * list; the Canvas renderer reads them at frame boundaries.
 */

/** Constants matching Globals in vecx_full.js */
const ALG_MAX_X      = 33000;
const ALG_MAX_Y      = 41000;
const VECTREX_COLORS = 128;
const VECTOR_HASH    = 65521;
const VECTOR_CNT     = (1500000 / 30) | 0; // VECTREX_MHZ / VECTREX_PDECAY

/**
 * A single rendered vector segment.
 * `color` is in [0, VECTREX_COLORS-1] (grayscale intensity index).
 * A color value equal to VECTREX_COLORS marks an invalidated entry in the
 * erase buffer.
 */
export interface VectorEntry {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
  color: number;
}

/** Mutable vector slot (matches vector_t in vecx_full.js). */
class VectorSlot implements VectorEntry {
  x0 = 0; y0 = 0; x1 = 0; y1 = 0; color = 0;
  reset(): void { this.x0 = this.y0 = this.x1 = this.y1 = this.color = 0; }
}

export class Beam {
  // ------------------------------------------------------------------ //
  // Sample-and-hold values (set by alg_update via VIA writes)
  // ------------------------------------------------------------------ //
  /** Zero reference sample-and-hold */
  alg_rsh: number = 128;
  /** X sample-and-hold (fed from DAC / ORA) */
  alg_xsh: number = 128;
  /** Y sample-and-hold */
  alg_ysh: number = 128;
  /** Z (intensity) sample-and-hold */
  alg_zsh: number = 0;
  /** Joystick channel 0 */
  alg_jch0: number = 128;
  /** Joystick channel 1 */
  alg_jch1: number = 128;
  /** Joystick channel 2 */
  alg_jch2: number = 128;
  /** Joystick channel 3 */
  alg_jch3: number = 128;
  /** Joystick sample-and-hold (selected channel) */
  alg_jsh: number = 128;

  /** Comparator output bit (bit 5 of ORB read) */
  alg_compare: number = 0;

  /** Integrator deltas (computed by alg_update) */
  alg_dx: number = 0;
  alg_dy: number = 0;

  /** Current beam position */
  alg_curr_x: number = ALG_MAX_X >> 1;
  alg_curr_y: number = ALG_MAX_Y >> 1;

  /** Half-range values for origin forcing */
  private alg_max_x: number = ALG_MAX_X >> 1;
  private alg_max_y: number = ALG_MAX_Y >> 1;

  // ------------------------------------------------------------------ //
  // Active vector tracking
  // ------------------------------------------------------------------ //
  /** 1 if a vector is currently being drawn */
  alg_vectoring: number = 0;
  alg_vector_x0: number = 0;
  alg_vector_y0: number = 0;
  alg_vector_x1: number = 0;
  alg_vector_y1: number = 0;
  alg_vector_dx: number = 0;
  alg_vector_dy: number = 0;
  alg_vector_color: number = 0;

  // ------------------------------------------------------------------ //
  // Double-buffered vector lists (draw / erase, swapped per frame)
  // ------------------------------------------------------------------ //
  private _vectors_draw: VectorSlot[];
  private _vectors_erse: VectorSlot[];
  private _vector_hash: number[];

  vector_draw_cnt: number = 0;
  vector_erse_cnt: number = 0;

  constructor() {
    this._vectors_draw = Array.from({ length: VECTOR_CNT }, () => new VectorSlot());
    this._vectors_erse = Array.from({ length: VECTOR_CNT }, () => new VectorSlot());
    this._vector_hash  = new Array<number>(VECTOR_HASH).fill(0);
  }

  // ------------------------------------------------------------------ //
  // alg_update — mirrors vecx_full.js lines 4269–4331
  // ------------------------------------------------------------------ //
  /**
   * Called by VIA whenever ORA or ORB is written.
   * Updates sample-and-hold values and recalculates dx/dy.
   */
  update(
    via_ora: number,
    via_orb: number,
    _via_acr: number,
    _via_pcr: number,
    _via_cb2h: number,
    _via_cb2s: number,
  ): void {
    // Joystick channel selection (bits 2:1 of ORB)
    switch (via_orb & 0x06) {
      case 0x00:
        this.alg_jsh = this.alg_jch0;
        if ((via_orb & 0x01) === 0x00) {
          // Demultiplexor on: latch Y
          this.alg_ysh = this.alg_xsh;
        }
        break;
      case 0x02:
        this.alg_jsh = this.alg_jch1;
        if ((via_orb & 0x01) === 0x00) {
          // Demultiplexor on: latch R (zero ref)
          this.alg_rsh = this.alg_xsh;
        }
        break;
      case 0x04:
        this.alg_jsh = this.alg_jch2;
        if ((via_orb & 0x01) === 0x00) {
          // Demultiplexor on: latch Z (intensity)
          this.alg_zsh = this.alg_xsh > 0x80 ? this.alg_xsh - 0x80 : 0;
        }
        break;
      case 0x06:
        // Sound output line — joystick channel 3
        this.alg_jsh = this.alg_jch3;
        break;
    }

    // Comparator: joystick vs X reference
    this.alg_compare = this.alg_jsh > this.alg_xsh ? 0x20 : 0;

    // Compute integrator deltas from XSH / RSH / YSH
    this.alg_dx = this.alg_xsh - this.alg_rsh;
    this.alg_dy = this.alg_rsh - this.alg_ysh;

    // Suppress unused-parameter warnings (the full via state is passed for
    // future use / documentation; only ORA/ORB matter here)
    void via_ora;
  }

  // ------------------------------------------------------------------ //
  // alg_addline — mirrors vecx_full.js lines 5135–5198
  // ------------------------------------------------------------------ //
  private addLine(x0: number, y0: number, x1: number, y1: number, color: number): void {
    // Compute hash for deduplication
    let key = x0;
    key = key * 31 + y0;
    key = key * 31 + x1;
    key = key * 31 + y1;
    key = ((key % VECTOR_HASH) + VECTOR_HASH) % VECTOR_HASH;

    const index = this._vector_hash[key];

    // Check draw list first
    if (index >= 0 && index < this.vector_draw_cnt) {
      const v = this._vectors_draw[index];
      if (v.x0 === x0 && v.y0 === y0 && v.x1 === x1 && v.y1 === y1) {
        v.color = color;
        return;
      }
    }

    // Check erase list — invalidate if found there
    if (index >= 0 && index < this.vector_erse_cnt) {
      const v = this._vectors_erse[index];
      if (v.x0 === x0 && v.y0 === y0 && v.x1 === x1 && v.y1 === y1) {
        v.color = VECTREX_COLORS; // mark invalid
      }
    }

    // Add to draw list
    const slot = this._vectors_draw[this.vector_draw_cnt];
    slot.x0    = x0;
    slot.y0    = y0;
    slot.x1    = x1;
    slot.y1    = y1;
    slot.color = color;
    this._vector_hash[key] = this.vector_draw_cnt;
    this.vector_draw_cnt++;
  }

  // ------------------------------------------------------------------ //
  // alg_sstep — mirrors the inline loop in vecx_full.js lines 5545–5676
  // ------------------------------------------------------------------ //
  /**
   * Advance beam emulation by one clock cycle.
   * Called once per CPU cycle inside the main emulation loop.
   */
  tick(
    via_acr: number,
    via_pcr: number,
    via_ca2: number,
    via_cb2h: number,
    via_cb2s: number,
    via_t1pb7: number,
    via_orb: number,
  ): void {
    let sig_dx    = 0;
    let sig_dy    = 0;
    let sig_ramp  = 0;
    let sig_blank = 0;

    // Beam-blank signal: driven by shift register (ACR bit 4) or CB2 handshake
    if ((via_acr & 0x10) === 0x10) {
      sig_blank = via_cb2s;
    } else {
      sig_blank = via_cb2h;
    }

    if (via_ca2 === 0) {
      // Force beam toward origin
      sig_dx = this.alg_max_x - this.alg_curr_x;
      sig_dy = this.alg_max_y - this.alg_curr_y;
    } else {
      // Normal ramp control: bit 7 of ORB (or T1 PB7 in T1 output mode)
      if (via_acr & 0x80) {
        sig_ramp = via_t1pb7;
      } else {
        sig_ramp = via_orb & 0x80;
      }
      if (sig_ramp === 0) {
        sig_dx = this.alg_dx;
        sig_dy = this.alg_dy;
      }
      // else sig_dx/sig_dy remain 0 (ramp holds beam still)
    }

    if (this.alg_vectoring === 0) {
      // Not currently drawing — check if beam should start
      if (
        sig_blank === 1 &&
        this.alg_curr_x >= 0 && this.alg_curr_x < ALG_MAX_X &&
        this.alg_curr_y >= 0 && this.alg_curr_y < ALG_MAX_Y
      ) {
        this.alg_vectoring   = 1;
        this.alg_vector_x0   = this.alg_curr_x;
        this.alg_vector_y0   = this.alg_curr_y;
        this.alg_vector_x1   = this.alg_curr_x;
        this.alg_vector_y1   = this.alg_curr_y;
        this.alg_vector_dx   = sig_dx;
        this.alg_vector_dy   = sig_dy;
        this.alg_vector_color = this.alg_zsh & 0xff;
      }
    } else {
      // Currently drawing a vector
      if (sig_blank === 0) {
        // Blank went on → finish this segment
        this.alg_vectoring = 0;
        this.addLine(
          this.alg_vector_x0, this.alg_vector_y0,
          this.alg_vector_x1, this.alg_vector_y1,
          this.alg_vector_color,
        );
      } else if (
        sig_dx !== this.alg_vector_dx ||
        sig_dy !== this.alg_vector_dy ||
        (this.alg_zsh & 0xff) !== this.alg_vector_color
      ) {
        // Parameters changed mid-segment — close the current one
        this.addLine(
          this.alg_vector_x0, this.alg_vector_y0,
          this.alg_vector_x1, this.alg_vector_y1,
          this.alg_vector_color,
        );
        // Start new segment if still in bounds
        if (
          this.alg_curr_x >= 0 && this.alg_curr_x < ALG_MAX_X &&
          this.alg_curr_y >= 0 && this.alg_curr_y < ALG_MAX_Y
        ) {
          this.alg_vector_x0   = this.alg_curr_x;
          this.alg_vector_y0   = this.alg_curr_y;
          this.alg_vector_x1   = this.alg_curr_x;
          this.alg_vector_y1   = this.alg_curr_y;
          this.alg_vector_dx   = sig_dx;
          this.alg_vector_dy   = sig_dy;
          this.alg_vector_color = this.alg_zsh & 0xff;
        } else {
          this.alg_vectoring = 0;
        }
      }
    }

    // Advance beam position
    this.alg_curr_x += sig_dx;
    this.alg_curr_y += sig_dy;

    // Extend current vector if still in bounds
    if (
      this.alg_vectoring === 1 &&
      this.alg_curr_x >= 0 && this.alg_curr_x < ALG_MAX_X &&
      this.alg_curr_y >= 0 && this.alg_curr_y < ALG_MAX_Y
    ) {
      this.alg_vector_x1 = this.alg_curr_x;
      this.alg_vector_y1 = this.alg_curr_y;
    }

    void via_pcr; // currently unused; retained for symmetry with full via state
  }

  // ------------------------------------------------------------------ //
  // Frame boundary — swap draw/erase buffers (called by VectrexSystem)
  // ------------------------------------------------------------------ //

  /**
   * Return the current draw list as a snapshot and swap buffers.
   * The previous draw list becomes the new erase list (to be drawn black
   * next frame by the Canvas renderer).
   */
  swapBuffers(): { draw: VectorSlot[]; drawCnt: number; erse: VectorSlot[]; erseCnt: number } {
    const result = {
      draw:    this._vectors_draw,
      drawCnt: this.vector_draw_cnt,
      erse:    this._vectors_erse,
      erseCnt: this.vector_erse_cnt,
    };
    // Swap
    this.vector_erse_cnt = this.vector_draw_cnt;
    this.vector_draw_cnt = 0;
    const tmp          = this._vectors_erse;
    this._vectors_erse = this._vectors_draw;
    this._vectors_draw = tmp;
    return result;
  }

  reset(): void {
    this.alg_rsh = 128;
    this.alg_xsh = 128;
    this.alg_ysh = 128;
    this.alg_zsh = 0;
    this.alg_jch0 = 128;
    this.alg_jch1 = 128;
    this.alg_jch2 = 128;
    this.alg_jch3 = 128;
    this.alg_jsh  = 128;
    this.alg_compare  = 0;
    this.alg_dx       = 0;
    this.alg_dy       = 0;
    this.alg_curr_x   = ALG_MAX_X >> 1;
    this.alg_curr_y   = ALG_MAX_Y >> 1;
    this.alg_vectoring = 0;
    this.vector_draw_cnt = 0;
    this.vector_erse_cnt = 0;

    for (let i = 0; i < this._vectors_draw.length; i++) this._vectors_draw[i].reset();
    for (let i = 0; i < this._vectors_erse.length; i++) this._vectors_erse[i].reset();
    this._vector_hash.fill(0);
  }

  /** Read-only view of the current draw list (for the Canvas renderer). */
  get vectorsDraw(): readonly VectorSlot[] { return this._vectors_draw; }
  /** Read-only view of the current erase list. */
  get vectorsErse(): readonly VectorSlot[] { return this._vectors_erse; }

  /**
   * Directly inject a vector segment into the draw list.
   * Used by the RP2350 emulator to bypass the VIA simulation for the ARM
   * drawing functions (dv_move_to / dv_draw_delta), where the signed-delta
   * coordinate system doesn't map cleanly through the VIA S&H model.
   */
  addSegmentDirect(x0: number, y0: number, x1: number, y1: number, color: number): void {
    if (x0 !== x1 || y0 !== y1) {
      this.addLine(x0, y0, x1, y1, color);
    }
  }

  /** VECTREX_COLORS constant exposed so Canvas can check sentinel value. */
  static readonly VECTREX_COLORS = VECTREX_COLORS;
}
