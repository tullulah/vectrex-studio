/**
 * PitrexCore.ts — High-level wrapper around the PiTrex ARM32 interpreter.
 *
 * Usage:
 *   const core = new PitrexCore();
 *   core.loadAssembly(sFileText);
 *   const segments = core.runFrame();   // call each animation frame
 */

import { parseAsm }                         from './PitrexAsmParser.js';
import { createState, runFrame as _runFrame } from './PitrexArm32.js';
import type { PitrexArm32State }              from './PitrexArm32.js';
import type { PitrexSegment, PitrexFrameResult } from './PitrexArm32.js';

export type { PitrexSegment, PitrexFrameResult };

export class PitrexCore {
  private state: PitrexArm32State | null = null;
  private _ready = false;

  /** Parse and load the generated .s file text. */
  loadAssembly(sFileText: string): void {
    try {
      const parsed = parseAsm(sFileText);
      this.state   = createState(parsed);
      this._ready  = true;
      console.log(
        `[PitrexCore] Loaded: ${parsed.instructions.length} instructions, ` +
        `${parsed.labels.size} labels, ${parsed.equs.size} equs`,
      );
    } catch (e) {
      console.error('[PitrexCore] Failed to parse assembly:', e);
      this._ready = false;
    }
  }

  isReady(): boolean { return this._ready; }

  /**
   * Set joystick input (axes in -127..127, buttons as 4-bit mask).
   * Call before runFrame() to update the simulated hardware state.
   */
  setInput(
    joyX: number, joyY: number, buttons: number,
    joyX2 = 0, joyY2 = 0, buttons2 = 0,
  ): void {
    if (!this.state) return;
    this.state.joyX      = joyX;
    this.state.joyY      = joyY;
    this.state.joyButtons  = buttons;
    this.state.joyX2     = joyX2;
    this.state.joyY2     = joyY2;
    this.state.joyButtons2 = buttons2;
  }

  /**
   * Execute instructions until v_WaitRecal is called (one game frame).
   * Returns segments + text to render, and a timeout flag.
   *
   * Coordinates are in PiTrex units:
   *   x: ±9600  (VPy ±96 × 100)
   *   y: ±12800 (VPy ±128 × 100)
   * Intensity: 0–127
   */
  runFrame(): PitrexFrameResult {
    if (!this.state || !this._ready) return { segments: [], texts: [], timeout: false };
    return _runFrame(this.state);
  }
}
