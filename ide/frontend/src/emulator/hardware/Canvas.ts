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
    const sclx = (ALG_MAX_X / this.screen_x) | 0;
    const scly = (ALG_MAX_Y / this.screen_y) | 0;
    this.scl_factor = sclx > scly ? sclx : scly;
  }

  // ------------------------------------------------------------------ //
  // Colour table — mirrors osint_gencolors in vecx_full.js
  // ------------------------------------------------------------------ //
  private buildColorTable(): void {
    this.color_set = [];
    for (let c = 0; c < VECTREX_COLORS; c++) {
      const v = ((c * 256 / VECTREX_COLORS) | 0) as number;
      this.color_set.push([v, v, v]);
    }
  }

  // ------------------------------------------------------------------ //
  // Bresenham line drawing — mirrors osint_line* in vecx_full.js
  // ------------------------------------------------------------------ //

  private pixelIndex(x: number, y: number): number {
    return y * this.lPitch + x * BYTES_PER_PIXEL;
  }

  /** Slope [0,1]: x drives, y0 < y1, x0 < x1 */
  private linep01(x0: number, y0: number, x1: number, y1: number, color: number): void {
    if (!this.data) return;
    const { data, scl_factor, lPitch, color_set } = this;
    const [cr, cg, cb] = color_set[color] ?? [0, 0, 0];
    const dx = x1 - x0;
    const dy = y1 - y0;
    let i0   = (x0 / scl_factor) | 0;
    const i1 = (x1 / scl_factor) | 0;
    let j    = (y0 / scl_factor) | 0;
    let e    = dy * (scl_factor - (x0 % scl_factor)) - dx * (scl_factor - (y0 % scl_factor));
    const dxs = dx * scl_factor;
    const dys = dy * scl_factor;
    let idx  = this.pixelIndex(i0, j);
    for (; i0 <= i1; i0++) {
      data[idx] = cr; data[idx + 1] = cg; data[idx + 2] = cb;
      if (e >= 0) { idx += lPitch; e -= dxs; }
      e += dys;
      idx += BYTES_PER_PIXEL;
    }
  }

  /** Slope [1,∞): y drives, y0 < y1, x0 < x1 */
  private linep1n(x0: number, y0: number, x1: number, y1: number, color: number): void {
    if (!this.data) return;
    const { data, scl_factor, lPitch, color_set } = this;
    const [cr, cg, cb] = color_set[color] ?? [0, 0, 0];
    const dx = x1 - x0;
    const dy = y1 - y0;
    let i0   = (y0 / scl_factor) | 0;
    const i1 = (y1 / scl_factor) | 0;
    let j    = (x0 / scl_factor) | 0;
    let e    = dx * (scl_factor - (y0 % scl_factor)) - dy * (scl_factor - (x0 % scl_factor));
    const dxs = dx * scl_factor;
    const dys = dy * scl_factor;
    let idx  = this.pixelIndex(j, i0);
    for (; i0 <= i1; i0++) {
      data[idx] = cr; data[idx + 1] = cg; data[idx + 2] = cb;
      if (e >= 0) { idx += BYTES_PER_PIXEL; e -= dys; }
      e += dxs;
      idx += lPitch;
    }
  }

  /** Slope [0,-1]: x drives, y1 < y0, x0 < x1 */
  private linen01(x0: number, y0: number, x1: number, y1: number, color: number): void {
    if (!this.data) return;
    const { data, scl_factor, lPitch, color_set } = this;
    const [cr, cg, cb] = color_set[color] ?? [0, 0, 0];
    const dx = x1 - x0;
    const dy = y0 - y1;
    let i0   = (x0 / scl_factor) | 0;
    const i1 = (x1 / scl_factor) | 0;
    let j    = (y0 / scl_factor) | 0;
    let e    = dy * (scl_factor - (x0 % scl_factor)) - dx * (y0 % scl_factor);
    const dxs = dx * scl_factor;
    const dys = dy * scl_factor;
    let idx  = this.pixelIndex(i0, j);
    for (; i0 <= i1; i0++) {
      data[idx] = cr; data[idx + 1] = cg; data[idx + 2] = cb;
      if (e >= 0) { idx -= lPitch; e -= dxs; }
      e += dys;
      idx += BYTES_PER_PIXEL;
    }
  }

  /** Slope (-∞,-1]: y drives, y0 < y1, x1 < x0 */
  private linen1n(x0: number, y0: number, x1: number, y1: number, color: number): void {
    if (!this.data) return;
    const { data, scl_factor, lPitch, color_set } = this;
    const [cr, cg, cb] = color_set[color] ?? [0, 0, 0];
    const dx = x0 - x1;
    const dy = y1 - y0;
    let i0   = (y0 / scl_factor) | 0;
    const i1 = (y1 / scl_factor) | 0;
    let j    = (x0 / scl_factor) | 0;
    let e    = dx * (scl_factor - (y0 % scl_factor)) - dy * (x0 % scl_factor);
    const dxs = dx * scl_factor;
    const dys = dy * scl_factor;
    let idx  = this.pixelIndex(j, i0);
    for (; i0 <= i1; i0++) {
      data[idx] = cr; data[idx + 1] = cg; data[idx + 2] = cb;
      if (e >= 0) { idx -= BYTES_PER_PIXEL; e -= dys; }
      e += dxs;
      idx += lPitch;
    }
  }

  /** General line dispatcher — mirrors osint_line in vecx_full.js */
  private drawLine(x0: number, y0: number, x1: number, y1: number, color: number): void {
    if (x1 > x0) {
      if (y1 > y0) {
        if ((x1 - x0) > (y1 - y0)) this.linep01(x0, y0, x1, y1, color);
        else                         this.linep1n(x0, y0, x1, y1, color);
      } else {
        if ((x1 - x0) > (y0 - y1)) this.linen01(x0, y0, x1, y1, color);
        else                         this.linen1n(x1, y1, x0, y0, color);
      }
    } else {
      if (y1 > y0) {
        if ((x0 - x1) > (y1 - y0)) this.linen01(x1, y1, x0, y0, color);
        else                         this.linen1n(x0, y0, x1, y1, color);
      } else {
        if ((x0 - x1) > (y0 - y1)) this.linep01(x1, y1, x0, y0, color);
        else                         this.linep1n(x1, y1, x0, y0, color);
      }
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
