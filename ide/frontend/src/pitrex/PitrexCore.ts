/**
 * PitrexCore.ts — High-level wrapper around the PiTrex ARM32 interpreter.
 *
 * Usage:
 *   const core = new PitrexCore();
 *   core.loadAssembly(sFileText);
 *   core.startAudio();            // call after first user gesture
 *   const segments = core.runFrame();   // call each animation frame
 *   core.stopAudio();
 */

import { parseAsm }                         from './PitrexAsmParser.js';
import { createState, runFrame as _runFrame } from './PitrexArm32.js';
import type { PitrexArm32State }              from './PitrexArm32.js';
import type { PitrexSegment, PitrexFrameResult } from './PitrexArm32.js';
import { Psg }                                from '../emulator/hardware/Psg.js';

export type { PitrexSegment, PitrexFrameResult };

export class PitrexCore {
  private state: PitrexArm32State | null = null;
  private _ready = false;

  // Audio
  private readonly psg: Psg = new Psg();
  private audioCtx:  AudioContext | null        = null;
  private audioNode: ScriptProcessorNode | null = null;
  static readonly AUDIO_SAMPLE_RATE = 44100;
  static readonly AUDIO_BUFFER_SIZE = 512;

  /** Parse and load the generated .s file text. */
  loadAssembly(sFileText: string): void {
    try {
      const parsed = parseAsm(sFileText);
      this.state   = createState(parsed);
      // Wire PSG callback: v_writePSG calls this so audio synthesis gets the data
      this.state.psgWrite = (reg: number, val: number) => {
        // Directly update Psg register state (bypass VIA bus encoding — pitrex
        // calls v_writePSG(reg, val) directly, not through the VIA bit-bang protocol)
        this.psg.Regs[reg & 0x0F] = val & 0xFF;
        // Replicate the writeRegister side-effects by calling psg.write() with
        // the VIA bit-bang encoding that writeRegister expects:
        //   step 1: latch address  (orb=0x18, ora=reg)
        //   step 2: write data     (orb=0x10, ora=val)
        this.psg.write(0x18, reg & 0x0F);
        this.psg.write(0x10, val & 0xFF);
      };
      this.state.psgRead = (reg: number) => this.psg.Regs[reg & 0x0F] & 0xFF;
      this.psg.reset();
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
   */
  runFrame(): PitrexFrameResult {
    if (!this.state || !this._ready) return { segments: [], texts: [], timeout: false };
    return _runFrame(this.state);
  }

  /**
   * Start PSG audio synthesis via a ScriptProcessor node.
   * Must be called after a user gesture so the AudioContext can start.
   * Idempotent — safe to call multiple times.
   */
  startAudio(): void {
    if (this.audioCtx) return;
    try {
      const ctx = new AudioContext({ sampleRate: PitrexCore.AUDIO_SAMPLE_RATE });
      // eslint-disable-next-line @typescript-eslint/no-deprecated
      const node = ctx.createScriptProcessor(PitrexCore.AUDIO_BUFFER_SIZE, 0, 1);
      node.onaudioprocess = (ev) => {
        this.psg.fillBuffer(
          ev.outputBuffer.getChannelData(0),
          PitrexCore.AUDIO_BUFFER_SIZE,
        );
      };
      node.connect(ctx.destination);
      this.audioCtx  = ctx;
      this.audioNode = node;
      if (ctx.state !== 'running') ctx.resume().catch(() => {});
    } catch (e) {
      console.warn('[PitrexCore] Audio init failed:', e);
    }
  }

  /** Stop and destroy the audio context. */
  stopAudio(): void {
    try {
      this.audioNode?.disconnect();
      this.audioCtx?.close().catch(() => {});
    } catch {}
    this.audioNode = null;
    this.audioCtx  = null;
  }
}
