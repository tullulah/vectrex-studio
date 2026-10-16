/**
 * Canvas — Vectrex vector-display renderer.
 *
 * Mirrors the osint.js section of vecx_full.js (lines 3649–4019) and the
 * per-frame render call in vecx_emu() (lines 5710–5727).
 *
 * The renderer maintains a 2D canvas and uses the Bresenham-style line
 * routines from the original to convert the integer beam coordinates
 * (0–ALG_MAX_X, 0–ALG_MAX_Y) into screen pixels.
 *
 * Double-buffering is managed by the Beam class; the Canvas only needs
 * access to the current draw list (to paint) and the erase list (to blank).
 */

import type { VectorEntry } from './Beam.js';
import { Beam } from './Beam.js';

const SCREEN_X_DEFAULT  = 330;
const SCREEN_Y_DEFAULT  = 410;
const VECTREX_COLORS    = 128;
// Vector-CRT brightness curve. A linear intensity→grayscale ramp reads dim on a
// gamma-2.2 monitor (mid intensities — the AAE ccpu games sit ~0x40 — looked
// washed-out vs real hardware, where the phosphor lights brightly at mid DAC).
// Gamma < 1 boosts the low/mid range; 0 stays black, max stays white. Tune here.
/* Exported so the WASM view uses the SAME curve. They had drifted: this applies the tube's
 * gamma and PitrexSimView mapped intensity to alpha linearly, so the same segment came out
 * at 119 here and 64 there and the two views disagreed about how visible a dimmed vector
 * is. One number, one place. */
export const VECTREX_GAMMA = 0.55;
const BYTES_PER_PIXEL   = 4;
const ALG_MAX_X         = 33000;
const ALG_MAX_Y         = 41000;

export class Canvas {
  private _canvas: HTMLCanvasElement | null = null;
  private ctx2d: CanvasRenderingContext2D | null = null;
  private imageData: ImageData | null = null;
  private data: Uint8ClampedArray | null = null;

  private screen_x: number = SCREEN_X_DEFAULT;
  private screen_y: number = SCREEN_Y_DEFAULT;
  private lPitch: number   = BYTES_PER_PIXEL * SCREEN_X_DEFAULT;
  private scl_factor: number = 1;
  /** The beam rectangle shown (alg units): the whole 0–ALG_MAX field unless setView says otherwise. */
  private view = { x0: 0, y0: 0, x1: ALG_MAX_X, y1: ALG_MAX_Y };
  private offX = 0;
  private offY = 0;

  /** Grayscale colour table: index → [R, G, B] */
  private color_set: [number, number, number][] = [];

  constructor(canvas?: HTMLCanvasElement) {
    this.buildColorTable();
    if (canvas) this.setCanvas(canvas);
  }

  // ------------------------------------------------------------------ //
  // Setup
  // ------------------------------------------------------------------ //

  setCanvas(el: HTMLCanvasElement): void {
    this._canvas    = el;
    this.screen_x   = el.width  || SCREEN_X_DEFAULT;
    this.screen_y   = el.height || SCREEN_Y_DEFAULT;
    this.lPitch     = BYTES_PER_PIXEL * this.screen_x;
    this.ctx2d      = el.getContext('2d');
    if (!this.ctx2d) return;

    // Create a fresh black buffer — do NOT read the existing canvas (getImageData
    // would capture whatever was drawn by JSVecX/Minestorm and keep it as background).
    this.imageData  = this.ctx2d.createImageData(this.screen_x, this.screen_y);
    this.data       = this.imageData.data;
    this.updateScale();

    // Set all alpha channels to opaque (R/G/B remain 0 = black)
    for (let i = 3; i < this.data.length; i += 4) {
      this.data[i] = 0xff;
    }

    this.ctx2d.putImageData(this.imageData, 0, 0);
  }

  private updateScale(): void {
    const w = this.view.x1 - this.view.x0, h = this.view.y1 - this.view.y0;
    if (w === ALG_MAX_X && h === ALG_MAX_Y && this.view.x0 === 0 && this.view.y0 === 0) {
      // the field as vecx shows it (integer scale, top-left aligned)
      const sclx = (ALG_MAX_X / this.screen_x) | 0;
      const scly = (ALG_MAX_Y / this.screen_y) | 0;
      this.scl_factor = sclx > scly ? sclx : scly;
      this.offX = 0; this.offY = 0;
      return;
    }
    // a window: fit it whole, centred
    this.scl_factor = Math.max(w / this.screen_x, h / this.screen_y);
    this.offX = this.view.x0 - (this.screen_x * this.scl_factor - w) / 2;
    this.offY = this.view.y0 - (this.screen_y * this.scl_factor - h) / 2;
  }

  /** Show this rectangle of the beam field (alg units) instead of the whole 0–ALG_MAX one. */
  setView(x0: number, y0: number, x1: number, y1: number): void {
    this.view = { x0, y0, x1, y1 };
    this.updateScale();
    this.clearScreen();
  }

  // ------------------------------------------------------------------ //
  // Colour table — mirrors osint_gencolors in vecx_full.js
  // ------------------------------------------------------------------ //
  private buildColorTable(): void {
    this.color_set = [];
    for (let c = 0; c < VECTREX_COLORS; c++) {
      const v = Math.round(255 * Math.pow(c / (VECTREX_COLORS - 1), VECTREX_GAMMA));
      this.color_set.push([v, v, v]);
    }
  }

  // ------------------------------------------------------------------ //
  // Bresenham line drawing — mirrors osint_line* in vecx_full.js
  // ------------------------------------------------------------------ //

  private pixelIndex(x: number, y: number): number {
    return y * this.lPitch + x * BYTES_PER_PIXEL;
  }

  /**
   * One vector, with the BEAM GIVEN A WIDTH.
   *
   * It used to be four Bresenham variants writing single hard pixels, inherited from vecx.
   * A vector display has no pixels, and a real beam is about a millimetre across on a 20 cm
   * screen: it smooths anything finer than itself. This renderer did the opposite — a
   * zero-width beam on a 736-pixel canvas, where one device unit is nearly three pixels, so
   * a shallow diagonal came out as a visible staircase that the console does not show.
   * Daniel checked the same level on hardware: straight and clean.
   *
   * So the line is antialiased (Xiaolin Wu): each step lights the two pixels straddling the
   * true position, weighted by how far between them it falls. That IS the beam spot, at the
   * cheapest useful fidelity, and it applies to every system that draws here.
   *
   * The erase pass calls this with colour 0 and therefore blackens exactly the same pixels
   * it lit, which is what keeps a persistent canvas from silting up.
   */
  private drawLine(x0: number, y0: number, x1: number, y1: number, color: number): void {
    if (!this.data) return;
    const { data, scl_factor, lPitch, color_set } = this;
    const [cr, cg, cb] = color_set[color] ?? [0, 0, 0];

    const { offX, offY } = this;
    let ax = (x0 - offX) / scl_factor, ay = (y0 - offY) / scl_factor;
    let bx = (x1 - offX) / scl_factor, by = (y1 - offY) / scl_factor;
    const steep = Math.abs(by - ay) > Math.abs(bx - ax);
    if (steep) { let t = ax; ax = ay; ay = t; t = bx; bx = by; by = t; }
    if (ax > bx) { let t = ax; ax = bx; bx = t; t = ay; ay = by; by = t; }

    const dx = bx - ax, dy = by - ay;
    const grad = dx === 0 ? 0 : dy / dx;
    const iMax = (steep ? this.screen_y : this.screen_x) - 1;
    const jMax = (steep ? this.screen_x : this.screen_y) - 1;

    const plot = (i: number, j: number, w: number) => {
      if (i < 0 || j < 0 || i > iMax || j > jMax) return;
      const idx = steep ? this.pixelIndex(j, i) : this.pixelIndex(i, j);
      /* Take the brighter of what is there and what we are adding, so two vectors crossing
       * do not dim each other. Erasing (colour 0) still wins, because w scales to 0. */
      const r = (cr * w) | 0, g = (cg * w) | 0, b = (cb * w) | 0;
      if (color === 0) { data[idx] = 0; data[idx + 1] = 0; data[idx + 2] = 0; return; }
      if (r > data[idx])     data[idx]     = r;
      if (g > data[idx + 1]) data[idx + 1] = g;
      if (b > data[idx + 2]) data[idx + 2] = b;
    };

    const i0 = Math.round(ax), i1 = Math.round(bx);
    let y = ay + (i0 - ax) * grad;
    for (let i = i0; i <= i1; i++) {
      const j = Math.floor(y), f = y - j;
      plot(i, j, 1 - f);
      plot(i, j + 1, f);
      y += grad;
    }
  }

  // ------------------------------------------------------------------ //
  // Public API
  // ------------------------------------------------------------------ //

  /**
   * Render a frame.
   *
   * Erases old vectors (draws in black) then draws new ones.
   * Mirrors osint_render() in vecx_full.js (lines 3958–3986).
   *
   * Call this after Beam.swapBuffers() has been called by VectrexSystem.
   */
  renderFrame(
    vectorsDraw: readonly VectorEntry[],
    vectorDrawCnt: number,
    vectorsErse: readonly VectorEntry[],
    vectorErseCnt: number,
  ): void {
    if (!this.ctx2d || !this.imageData) return;

    // Erase pass: draw old vectors in black (color = 0)
    for (let v = 0; v < vectorErseCnt; v++) {
      const e = vectorsErse[v];
      if (e.color !== VECTREX_COLORS) {
        this.drawLine(e.x0, e.y0, e.x1, e.y1, 0);
      }
    }

    // Draw pass: paint new vectors
    for (let v = 0; v < vectorDrawCnt; v++) {
      const d = vectorsDraw[v];
      this.drawLine(d.x0, d.y0, d.x1, d.y1, d.color);
    }

    this.ctx2d.putImageData(this.imageData, 0, 0);
  }

  /**
   * Render this frame AND the previous one, on a cleared canvas.
   *
   * A program whose command list takes longer than a frame to draw (the UVM2 SDK's: a list
   * runs in bus time, ~22 ms for ROTJ's title) has it cut in two by the frame boundary, and
   * rendering frame by frame showed one half, then the other — on a tube the phosphor and the
   * eye join them. Two frames are the eye's share. `prev` is the beam's erase list, i.e. the
   * previous frame's draw list; its entries the beam marked invalid (redrawn this frame) are
   * skipped.
   */
  renderPersistent(
    vectorsDraw: readonly VectorEntry[],
    vectorDrawCnt: number,
    vectorsPrev: readonly VectorEntry[],
    vectorPrevCnt: number,
  ): void {
    if (!this.ctx2d || !this.imageData || !this.data) return;
    const d = this.data;
    for (let i = 0; i < d.length; i += 4) { d[i] = 0; d[i + 1] = 0; d[i + 2] = 0; }
    for (let v = 0; v < vectorPrevCnt; v++) {
      const e = vectorsPrev[v];
      if (e.color !== VECTREX_COLORS && e.color > 0) this.drawLine(e.x0, e.y0, e.x1, e.y1, e.color);
    }
    for (let v = 0; v < vectorDrawCnt; v++) {
      const e = vectorsDraw[v];
      if (e.color > 0) this.drawLine(e.x0, e.y0, e.x1, e.y1, e.color);
    }
    this.ctx2d.putImageData(this.imageData, 0, 0);
  }

  /**
   * Clear the canvas to black.
   * Mirrors osint_clearscreen in vecx_full.js.
   */
  clearScreen(): void {
    if (!this.ctx2d || !this.imageData || !this.data) return;
    for (let x = 0; x < this.screen_y * this.lPitch; x++) {
      if ((x + 1) % 4) this.data[x] = 0;
    }
    this.ctx2d.putImageData(this.imageData, 0, 0);
  }

  /** Expose the sentinel value for callers who need to check it. */
  static readonly VECTREX_COLORS = Beam.VECTREX_COLORS;
}
