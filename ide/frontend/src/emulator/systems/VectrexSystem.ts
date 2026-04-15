/**
 * VectrexSystem — Phase 2 implementation.
 *
 * Composes Via6522, Beam, Psg, Canvas, and the M6809 CPU adapter into a
 * complete emulated Vectrex.  This class implements both ISystem and IBus,
 * so the CPU adapter can use `this` directly as the memory bus.
 *
 * Phase 1 established the hardware modules and proved they compile cleanly.
 * Phase 2 adds:
 *   - M6809 CPU wrapper (cpu/M6809.ts)
 *   - A fully operational runFrame() loop
 *   - Integration with jsvecxCore.ts via the useVectrexSystem flag
 */

import type { Segment } from '../../emulatorCore.js';
import type { ISystem } from '../interfaces/ISystem.js';
import type { IBus }    from '../interfaces/IBus.js';
import { Via6522 } from '../hardware/Via6522.js';
import { Beam }    from '../hardware/Beam.js';
import { Psg }     from '../hardware/Psg.js';
import { Canvas }  from '../hardware/Canvas.js';
import { M6809 }   from '../cpu/M6809.js';

// ------------------------------------------------------------------ //
// Vectrex timing constants (matching Globals in vecx_full.js)
// ------------------------------------------------------------------ //
const VECTREX_MHZ    = 1_500_000; // CPU clock rate in Hz
const VECTREX_PDECAY = 30;        // Phosphor decay rate (frames per display refresh)

/**
 * CPU cycles per display frame.
 * Matches FCYCLES_INIT in vecx_full.js (Globals.FCYCLES_INIT = 50000).
 */
const FCYCLES_INIT = (VECTREX_MHZ / VECTREX_PDECAY) | 0; // 50000

// ------------------------------------------------------------------ //
// Segment conversion helper
// ------------------------------------------------------------------ //

/**
 * Convert the Beam draw list into the Segment[] format consumed by the IDE.
 *
 * Beam coordinates are in raw integrator units (0–ALG_MAX_X, 0–ALG_MAX_Y).
 * The Segment type uses the same coordinate space — callers (EmulatorPanel)
 * handle the final screen scaling.
 */
function vectorsToSegments(
  draw: readonly { x0: number; y0: number; x1: number; y1: number; color: number }[],
  drawCnt: number,
  frameCounter: number,
): Segment[] {
  const segments: Segment[] = [];
  for (let i = 0; i < drawCnt; i++) {
    const v = draw[i];
    segments.push({
      x0:        v.x0,
      y0:        v.y0,
      x1:        v.x1,
      y1:        v.y1,
      intensity: v.color,
      frame:     frameCounter,
    });
  }
  return segments;
}

// ------------------------------------------------------------------ //
// VectrexSystem
// ------------------------------------------------------------------ //

/**
 * Complete Vectrex emulation system.
 *
 * The class also implements IBus so the CPU adapter can call
 * `this.read8` / `this.write8` directly without an extra wrapper.
 */
export class VectrexSystem implements ISystem, IBus {
  readonly cpuName = 'MC6809';

  // Hardware modules
  private readonly beam:   Beam;
  private readonly psg:    Psg;
  private readonly via:    Via6522;
  private readonly canvas: Canvas;
  private readonly cpu:    M6809;

  // Memory
  private rom:  Uint8Array = new Uint8Array(0x2000);   // 8 KB BIOS  (0xE000–0xFFFF)
  private ram:  Uint8Array = new Uint8Array(0x400);    // 1 KB RAM   (0xC800–0xCBFF)
  private cart: Uint8Array = new Uint8Array(0x400000); // Up to 4 MB cartridge

  // Emulation state
  private fcycles:       number = FCYCLES_INIT;
  private currentBank:   number = 0;
  private loadedRomSize: number = 0x8000;
  private frameCounter:  number = 0;

  /**
   * @param e6809Instance  The raw `e6809` JS object from `(window as any).vecx.e6809`.
   * @param canvasElement  Optional canvas for rendering.  Can be set later via setCanvas().
   */
  constructor(e6809Instance: any, canvasElement?: HTMLCanvasElement) {
    this.beam = new Beam();
    this.psg  = new Psg();

    // VIA callbacks delegate into Beam.update() and Psg.write()
    this.via = new Via6522(
      (via_ora, via_orb, via_acr, via_pcr, via_cb2h, via_cb2s) => {
        this.beam.update(via_ora, via_orb, via_acr, via_pcr, via_cb2h, via_cb2s);
      },
      (via_orb, via_ora) => {
        this.psg.write(via_orb, via_ora);
      },
    );

    this.canvas = new Canvas(canvasElement);
    this.cpu    = new M6809(e6809Instance);
  }

  // ------------------------------------------------------------------ //
  // ISystem
  // ------------------------------------------------------------------ //

  init(rom: Uint8Array, _bios?: Uint8Array): void {
    const len = Math.min(rom.length, this.rom.length);
    this.rom.set(rom.subarray(0, len), 0);
    this.reset();
  }

  reset(): void {
    // RAM: initialise with address pattern (matches vecx_reset in vecx_full.js)
    for (let r = 0; r < this.ram.length; r++) {
      this.ram[r] = r & 0xff;
    }
    this.currentBank  = 0;
    this.fcycles      = FCYCLES_INIT;
    this.frameCounter = 0;

    this.via.reset();
    this.beam.reset();
    this.psg.reset();
    this.cpu.reset();
  }

  /**
   * Advance emulation by one display frame and return all drawn vectors.
   *
   * The loop mirrors vecx_emu() in vecx_full.js:
   *   1. Run one CPU instruction via M6809.stepWithIrq().
   *   2. Tick Via6522 once per CPU cycle.
   *   3. Tick Beam once per CPU cycle.
   *   4. When fcycles expires, swap buffers and render to canvas.
   *
   * A single call to runFrame() runs exactly FCYCLES_INIT CPU cycles worth
   * of instructions (plus any carry-over from a partial last instruction).
   */
  runFrame(): Segment[] {
    let spent = 0;

    while (spent < FCYCLES_INIT) {
      // Assert IRQ if VIA is requesting one
      if (this.via.irqActive) {
        this.cpu.irq(0); // IRQ line
      }

      const icycles = this.cpu.stepWithIrq(this);

      // Tick VIA and Beam once for each CPU cycle consumed
      for (let c = 0; c < icycles; c++) {
        this.via.tick();
        this.beam.tick(
          this.via.via_acr,
          this.via.via_pcr,
          this.via.via_ca2,
          this.via.via_cb2h,
          this.via.via_cb2s,
          this.via.via_t1pb7,
          this.via.via_orb,
        );
      }

      spent      += icycles;
      this.fcycles -= icycles;

      // Frame boundary
      if (this.fcycles <= 0) {
        this.fcycles += FCYCLES_INIT;
        this.renderAndSwap();
      }
    }

    // Build Segment list from whatever was drawn this frame
    const { draw, drawCnt } = this.beam.swapBuffers();
    const segments = vectorsToSegments(draw, drawCnt, this.frameCounter);
    this.frameCounter++;
    return segments;
  }

  // ------------------------------------------------------------------ //
  // Memory bus (IBus) — mirrors read8/write8 in vecx_full.js
  // ------------------------------------------------------------------ //

  read8(address: number): number {
    address &= 0xffff;

    // BIOS ROM: 0xE000–0xFFFF
    if ((address & 0xe000) === 0xe000) {
      return this.rom[address & 0x1fff] & 0xff;
    }

    // VIA / RAM region: 0xC000–0xDFFF
    if ((address & 0xe000) === 0xc000) {
      if (address & 0x800) {
        // RAM: 0xC800–0xCBFF (1 KB, mirrored across the range)
        return this.ram[address & 0x3ff] & 0xff;
      }
      if (address & 0x1000) {
        // VIA registers: 0xD000–0xD00F
        return this.via.read(
          address & 0xf,
          this.beam.alg_compare,
          this.psg.Regs,
          this.psg.selectedRegister,
        );
      }
    }

    // Cartridge ROM: 0x0000–0x7FFF
    if (address < 0x8000) {
      let physAddr: number;
      if (address < 0x4000) {
        // Banked window (switched via write to 0xDF00)
        physAddr = this.currentBank * 0x4000 + address;
      } else {
        // Fixed last bank (always mapped to 0x4000–0x7FFF)
        const fixedBankOffset = (Math.floor(this.loadedRomSize / 0x4000) - 1) * 0x4000;
        physAddr = fixedBankOffset + (address - 0x4000);
      }
      if (physAddr >= 0 && physAddr < this.cart.length) {
        return this.cart[physAddr] & 0xff;
      }
      return 0xff;
    }

    return 0xff;
  }

  write8(address: number, data: number): void {
    address &= 0xffff;
    data    &= 0xff;

    // BIOS ROM — ignore writes
    if ((address & 0xe000) === 0xe000) return;

    // VIA / RAM region: 0xC000–0xDFFF
    if ((address & 0xe000) === 0xc000) {
      // RAM and VIA can be written simultaneously (hardware quirk)
      if (address & 0x800) {
        this.ram[address & 0x3ff] = data;
      }
      if (address & 0x1000) {
        this.via.write(address & 0xf, data, (xsh) => {
          this.beam.alg_xsh = xsh;
        });
      }
      return;
    }

    // Bank-switching register at 0xDF00
    if (address === 0xdf00) {
      this.currentBank = data;
      return;
    }

    // Cartridge ROM area — read-only
  }

  // ------------------------------------------------------------------ //
  // Cartridge loading
  // ------------------------------------------------------------------ //

  loadCartridge(bytes: Uint8Array): void {
    const len = Math.min(bytes.length, this.cart.length);
    this.cart.set(bytes.subarray(0, len), 0);
    this.loadedRomSize = bytes.length;
  }

  // ------------------------------------------------------------------ //
  // Canvas wiring (call after DOM is ready)
  // ------------------------------------------------------------------ //

  setCanvas(el: HTMLCanvasElement): void {
    this.canvas.setCanvas(el);
  }

  // ------------------------------------------------------------------ //
  // Debug: direct RAM peek (used by jsvecxCore.ts memory polling)
  // ------------------------------------------------------------------ //

  /** Read a byte from internal RAM (address is the full 16-bit Vectrex address). */
  peekRam(address: number): number {
    return this.ram[address & 0x3ff] & 0xff;
  }

  // ------------------------------------------------------------------ //
  // Internal: render and swap buffers at frame boundary
  // ------------------------------------------------------------------ //

  private renderAndSwap(): void {
    const { draw, drawCnt, erse, erseCnt } = this.beam.swapBuffers();
    this.canvas.renderFrame(draw, drawCnt, erse, erseCnt);
  }
}
