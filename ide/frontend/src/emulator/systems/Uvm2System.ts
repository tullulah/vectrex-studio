/**
 * Uvm2System — simulates a VPy image running on the Ultimate Vectrex Multicart 2.
 *
 * This is deliberately NOT the RP2350 system with a different loader. That one
 * traps every `svc` in JavaScript and injects vectors straight into the beam,
 * which is right for our own cartridge — the syscalls really are implemented by
 * firmware there. On the UVM2 there is no firmware: the syscall handler, the
 * halt-mode bus protocol and the beam timing all live INSIDE the image, and
 * they are precisely the code that has never run on hardware.
 *
 * So this system emulates the wire instead:
 *   - SIO GPIO registers at 0xD0000000, with the Vectrex CLK on bit 31
 *   - a 1.5 MHz bus clock derived from CPU cycles
 *   - the address/data/R-W lines decoded on each falling edge into a real
 *     Via6522 write, exactly as the hardware latches them
 *   - Via6522 + Beam ticked once per bus cycle, so the analog integrators
 *     produce vectors from our own ramp timings
 *   - `svc` performing a real Cortex-M exception entry into the image's own
 *     handler, rather than being intercepted
 *
 * The payoff is that a wrong CLK phase, a mis-encoded command, a ramp that is
 * too short or a frame over budget all show up here the same way they would on
 * a real console.
 */

import type { Segment } from '../../emulatorCore.js';
import type { ISystem } from '../interfaces/ISystem.js';
import type { IBus } from '../interfaces/IBus.js';
import { Via6522 } from '../hardware/Via6522.js';
import { Beam }    from '../hardware/Beam.js';
import { Psg }     from '../hardware/Psg.js';
import { Canvas }  from '../hardware/Canvas.js';
import { Thumb2 }  from '../cpu/Thumb2.js';

/** Beam vector list → the IDE's Segment shape (same mapping the other systems use). */
function vectorsToSegments(
  draw: readonly { x0: number; y0: number; x1: number; y1: number; color: number }[],
  drawCnt: number,
  frameCounter: number,
): Segment[] {
  const segments: Segment[] = [];
  for (let i = 0; i < drawCnt; i++) {
    const v = draw[i];
    segments.push({ x0: v.x0, y0: v.y0, x1: v.x1, y1: v.y1,
                    intensity: v.color, frame: frameCounter });
  }
  return segments;
}

// ── Memory map ──────────────────────────────────────────────────────────────
const SRAM_BASE = 0x20000000;
const SRAM_SIZE = 0x00082000;          // 520 KB, as on the real RP2350
const SIO_BASE  = 0xD0000000;

// ── Timing ──────────────────────────────────────────────────────────────────
/** RP2350 core cycles per Vectrex bus cycle (150 MHz / 1.5 MHz). */
const CPU_PER_BUS   = 100;
/** A 50 Hz Vectrex frame. Matches UVM2_CYCLES_PER_FRAME in the SDK. */
const BUS_PER_FRAME = 30000;
/** Escape hatch: an image that never advances the bus must not hang the IDE. */
const MAX_CPU_CYCLES_PER_FRAME = 40_000_000;

// ── GPIO bit assignments (must match uvm2_bus.h) ────────────────────────────
const DATA_MASK = 0x000000FF;
const ADDR_MASK = 0x003FFF00;          // A0-A13 on GPIO8-21
const A14_MASK  = 0x01000000;
const A15_MASK  = 0x02000000;
const RW_MASK   = 0x04000000;          // 1 = read, 0 = write
const HALT_MASK = 0x08000000;
const CLK_MASK  = 0x80000000;
/** Pins the cartridge pulls up and never drives: PB6, /IRQ, /NMI. */
const PULLUP_IN = 0x20C00000;

/** EXC_RETURN we hand the handler: thread mode, main stack, no FP context. */
const EXC_RETURN = 0xFFFFFFF9;

export class Uvm2System implements ISystem, IBus {
  readonly cpuName = 'Cortex-M33 (UVM2 halt mode)';

  private sram = new Uint8Array(SRAM_SIZE);
  private cpu  = new Thumb2();
  private via: Via6522;
  private beam = new Beam();
  private psg  = new Psg();
  private canvas: Canvas;

  // Halt-mode bus state
  private gpioOut  = 0;
  private gpioOe   = 0;
  private clkHigh  = false;
  private dataIn   = 0xFF;             // what the VIA drives back at us
  private busCycle = 0;
  private cpuAcc   = 0;
  private cycleCount = 0;              // DWT_CYCCNT
  private lastPollPc = -1;             // spin detection, see maybeCollapseSpin
  private gpioInLatch = 0;             // 32-bit GPIO_IN snapshot, see read8

  private vtor = SRAM_BASE;
  private frameCounter = 0;
  private halted = false;

  /** Bus cycles the last frame actually consumed — the SDK's own budget. */
  public lastFrameBusCycles = 0;

  private audioCtx: AudioContext | null = null;
  private audioNode: ScriptProcessorNode | null = null;

  constructor(canvasElement?: HTMLCanvasElement) {
    this.via = new Via6522(
      (ora, orb, acr, pcr, cb2h, cb2s) => this.beam.update(ora, orb, acr, pcr, cb2h, cb2s),
      (orb, ora) => this.psg.write(orb, ora),
    );
    this.canvas = new Canvas(canvasElement);
  }

  // ─── Loading ──────────────────────────────────────────────────────────────

  /**
   * Load a `.um2` file: a 20-byte header followed by a flat RAM image whose
   * first two words are the initial SP and the entry point. The length field
   * is a WORD count, not a byte count.
   */
  init(um2: Uint8Array): void {
    const rd32 = (o: number) =>
      (um2[o] | (um2[o + 1] << 8) | (um2[o + 2] << 16) | (um2[o + 3] << 24)) >>> 0;

    let payload = um2, loadAddr = SRAM_BASE;
    const magic = String.fromCharCode(um2[0], um2[1], um2[2], um2[3]);
    if (magic === '2CMU') {
      loadAddr = rd32(12);
      const words = rd32(16);
      payload = um2.subarray(20, 20 + words * 4);
    }

    this.sram.fill(0);
    this.sram.set(payload, (loadAddr - SRAM_BASE) >>> 0);
    this.reset();
  }

  reset(): void {
    this.frameCounter = 0;
    this.busCycle = 0;
    this.cpuAcc = 0;
    this.cycleCount = 0;
    this.clkHigh = false;
    this.gpioOut = 0;
    this.gpioOe = 0;
    this.halted = false;
    this.vtor = SRAM_BASE;
    this.lastPollPc = -1;

    this.via.reset();
    this.beam.reset();
    this.psg.reset();
    // Port B bit 5 is the comparator input; joyButtons ORs bits 4-7 into an ORB
    // read and would hold it high. Buttons reach the image via the PSG instead.
    this.via.joyButtons = 0x00;
    this.cpu.reset();
    this.cpu.setFetchRegion(this.sram, SRAM_BASE);

    // The firmware loads MSP and the entry point from the image's own vector
    // table — word 0 and word 1 — exactly as a Cortex-M reset would.
    this.cpu.setReg(13, this.read32(SRAM_BASE));
    this.cpu.setReg(15, this.read32(SRAM_BASE + 4) & ~1);
    this.cpu.setReg(14, 0xFFFFFFFE);   // sentinel: game_main must never return
  }

  // ─── Bus clock ────────────────────────────────────────────────────────────

  /**
   * Advance the Vectrex bus by however many bus cycles `cpuCycles` covers.
   *
   * Everything that makes the beam move happens here: the VIA latches a write
   * on each falling edge, presents read data on each rising edge, and the
   * integrators are ticked once per bus cycle so a ramp of N cycles moves the
   * beam the distance N cycles of ramp actually would.
   */
  private advanceBus(cpuCycles: number): void {
    this.cycleCount = (this.cycleCount + cpuCycles) >>> 0;
    this.cpuAcc += cpuCycles;

    while (this.cpuAcc >= CPU_PER_BUS / 2) {
      this.cpuAcc -= CPU_PER_BUS / 2;
      this.halfStep();
    }
  }

  /** One clock phase: the edge, and — on the falling one — a bus cycle of beam. */
  private halfStep(): void {
    if (this.clkHigh) {
      this.clkHigh = false;
      this.onFallingEdge();
      this.busCycle++;
      // Integrate one bus cycle's worth of beam movement.
      this.via.tick();
      this.beam.tick(
        this.via.via_acr, this.via.via_pcr, this.via.via_ca2,
        this.via.via_cb2h, this.via.via_cb2s, this.via.via_t1pb7,
        this.via.via_orb,
      );
    } else {
      this.clkHigh = true;
      this.onRisingEdge();
    }
  }

  /**
   * Collapse a clock-edge spin.
   *
   * At 100 CPU cycles per bus cycle an honest emulation spends ~99% of its
   * instructions inside `while ((GPIO_IN & CLK) ...)`: a frame that draws a
   * single dot still costs 2.3M steps, and the simulator falls behind 50 Hz —
   * which shows up as music playing slow, because the sequencer is ticked once
   * per frame.
   *
   * Waiting is not work. When the SAME instruction reads the clock byte twice
   * in a row, it is a spin by definition, so the phase is advanced immediately
   * instead of after another 50 emulated cycles. Bus cycles are still counted
   * one for one, so every SDK delay keeps its exact duration; only the idle
   * polling gets cheaper. Real game logic never hits this path and keeps its
   * honest 100:1 ratio against the bus.
   */
  private maybeCollapseSpin(): void {
    const pc = this.cpu.getReg(15) >>> 0;
    if (pc === this.lastPollPc) {
      this.lastPollPc = -1;      // one collapse per pair of polls
      this.halfStep();
      // The collapse REPLACES the cycles the spin would have burned; leaving
      // them in the accumulator counts the same phase twice, which stretches
      // every ramp and blows up the geometry.
      this.cpuAcc = 0;
    } else {
      this.lastPollPc = pc;
    }
  }

  /** Address currently on the bus, assembled from the GPIO pins. */
  private busAddress(): number {
    return (((this.gpioOut & ADDR_MASK) >>> 8)
         | ((this.gpioOut & A14_MASK) ? 0x4000 : 0)
         | ((this.gpioOut & A15_MASK) ? 0x8000 : 0)) >>> 0;
  }

  private addressesVia(): boolean {
    return (this.busAddress() & 0xF000) === 0xD000;
  }

  /** The VIA latches a write here — the same edge the hardware uses. */
  private onFallingEdge(): void {
    if (this.gpioOut & HALT_MASK) return;      // 6809 still owns the bus
    if (this.gpioOut & RW_MASK)   return;      // read cycle
    if (!this.addressesVia())     return;      // parked, or not the VIA

    this.via.write(this.busAddress() & 0xF, this.gpioOut & DATA_MASK,
                   (xsh) => { this.beam.alg_xsh = xsh; });
  }

  /**
   * A read cycle presents its data while the clock is high. Latching it once
   * per rising edge (rather than on every GPIO_IN poll) matters: VIA reads have
   * side effects, and the image polls that register in a tight loop.
   */
  private onRisingEdge(): void {
    if (this.gpioOut & HALT_MASK) return;
    if (!(this.gpioOut & RW_MASK)) return;
    if (this.gpioOe & DATA_MASK)  return;      // we are still driving the bus
    if (!this.addressesVia())     return;

    this.dataIn = this.via.read(
      this.busAddress() & 0xF, this.beam.alg_compare,
      this.psg.Regs, this.psg.selectedRegister,
    ) & 0xFF;
  }

  /** GPIO_IN as the image sees it: driven pins read back, plus the real inputs. */
  private gpioIn(): number {
    let v = (this.gpioOut & this.gpioOe) | PULLUP_IN;
    if (this.clkHigh) v |= CLK_MASK;
    if (!(this.gpioOe & DATA_MASK)) {
      v = (v & ~DATA_MASK) | (this.dataIn & DATA_MASK);
    }
    return v >>> 0;
  }

  // ─── IBus ─────────────────────────────────────────────────────────────────

  private read32(addr: number): number {
    return (this.read8(addr) | (this.read8(addr + 1) << 8)
         | (this.read8(addr + 2) << 16) | (this.read8(addr + 3) << 24)) >>> 0;
  }

  read8(addr: number): number {
    addr = addr >>> 0;

    if (addr >= SRAM_BASE && addr < SRAM_BASE + SRAM_SIZE) {
      return this.sram[addr - SRAM_BASE];
    }

    // SIO. Only GPIO_IN and GPIO_OUT are readable; the SET/CLR/XOR aliases are
    // write-only on real silicon too.
    // The `>>> 0` is load-bearing: JS bitwise ops yield a SIGNED 32-bit result,
    // so `addr & 0xFFFFF000` compares as negative and never matches 0xD0000000.
    if (((addr & 0xFFFFF000) >>> 0) === SIO_BASE) {
      const off = addr & 0xFFC, shift = (addr & 3) * 8;
      let word = 0;
      if (off === 0x004) {
        // The image reads GPIO_IN with a 32-bit load and treats CLK (bit 31)
        // and the data bus (bits 0-7) as one consistent sample. Since the bus
        // decomposes that into four byte reads, snapshot the whole word on the
        // first byte and serve the rest from it — otherwise a phase advance
        // between bytes hands the caller a fresh clock alongside stale data,
        // which is exactly how the joystick reads went wrong.
        if ((addr & 3) === 0) {
          this.maybeCollapseSpin();
          this.gpioInLatch = this.gpioIn();
        }
        word = this.gpioInLatch;
      }
      else if (off === 0x010) word = this.gpioOut;
      else if (off === 0x030) word = this.gpioOe;
      return (word >>> shift) & 0xFF;
    }

    // DWT cycle counter — the status LED bit-bangs WS2812 timing off it.
    if (addr >= 0xE0001004 && addr <= 0xE0001007) {
      return (this.cycleCount >>> ((addr & 3) * 8)) & 0xFF;
    }

    return 0;
  }

  write8(addr: number, data: number): void {
    addr = addr >>> 0;
    data &= 0xFF;

    if (addr >= SRAM_BASE && addr < SRAM_BASE + SRAM_SIZE) {
      this.sram[addr - SRAM_BASE] = data;
      return;
    }

    if (((addr & 0xFFFFF000) >>> 0) === SIO_BASE) {
      const off = addr & 0xFFC, shift = (addr & 3) * 8;
      const bits = data << shift;
      this.lastPollPc = -1;
      const keep = ~(0xFF << shift);
      switch (off) {
        case 0x010: this.gpioOut = ((this.gpioOut & keep) | bits) >>> 0; break;
        case 0x018: this.gpioOut = (this.gpioOut |  bits) >>> 0; break;
        case 0x020: this.gpioOut = (this.gpioOut & ~bits) >>> 0; break;
        case 0x028: this.gpioOut = (this.gpioOut ^  bits) >>> 0; break;
        case 0x030: this.gpioOe  = ((this.gpioOe & keep) | bits) >>> 0; break;
        case 0x038: this.gpioOe  = (this.gpioOe  |  bits) >>> 0; break;
        case 0x040: this.gpioOe  = (this.gpioOe  & ~bits) >>> 0; break;
        default: break;
      }
      return;
    }

    if (addr >= 0xE000ED08 && addr <= 0xE000ED0B) {          // SCB->VTOR
      const shift = (addr & 3) * 8;
      this.vtor = (((this.vtor & ~(0xFF << shift)) | (data << shift))) >>> 0;
      return;
    }

    // Pad/function-select, NVIC, SysTick, DWT control: accepted and ignored.
  }

  /**
   * `svc` performs a real exception entry rather than being intercepted: the
   * handler we vector to is the image's own, which is the whole point of
   * simulating this target at all.
   */
  onSvc(_imm: number, cpu: { getReg(i: number): number; setReg(i: number, v: number): void }): void {
    const sp = (cpu.getReg(13) - 32) >>> 0;
    const put = (i: number, v: number) => {
      const a = sp + i * 4;
      this.write8(a, v & 0xFF); this.write8(a + 1, (v >>> 8) & 0xFF);
      this.write8(a + 2, (v >>> 16) & 0xFF); this.write8(a + 3, (v >>> 24) & 0xFF);
    };
    // r0-r3, r12, lr, return address, xpsr — the standard Cortex-M frame. The
    // return address is already past the svc, which is what lets the handler
    // find its immediate at pc[-2].
    put(0, cpu.getReg(0)); put(1, cpu.getReg(1));
    put(2, cpu.getReg(2)); put(3, cpu.getReg(3));
    put(4, cpu.getReg(12)); put(5, cpu.getReg(14));
    put(6, cpu.getReg(15)); put(7, 0x01000000);

    cpu.setReg(13, sp);
    cpu.setReg(14, EXC_RETURN);
    cpu.setReg(15, this.read32(this.vtor + 11 * 4) & ~1);   // SVCall vector
  }

  /** Undo the above when the handler returns to EXC_RETURN. */
  private exceptionReturn(): void {
    const sp = this.cpu.getReg(13) >>> 0;
    const get = (i: number) => this.read32(sp + i * 4);
    this.cpu.setReg(0, get(0)); this.cpu.setReg(1, get(1));
    this.cpu.setReg(2, get(2)); this.cpu.setReg(3, get(3));
    this.cpu.setReg(12, get(4)); this.cpu.setReg(14, get(5));
    this.cpu.setReg(15, get(6) & ~1);
    this.cpu.setReg(13, (sp + 32) >>> 0);
  }

  // ─── Frame ────────────────────────────────────────────────────────────────

  /**
   * Run until the image has consumed one Vectrex frame's worth of bus cycles.
   *
   * There is no WFI to wait for here: the image paces itself against the bus
   * clock, exactly as it will on hardware, so the frame boundary is simply
   * 30000 bus cycles of elapsed Vectrex time.
   */
  runFrame(): Segment[] {
    const until = this.busCycle + BUS_PER_FRAME;
    let spent = 0;

    while (!this.halted && this.busCycle < until && spent < MAX_CPU_CYCLES_PER_FRAME) {
      const pc = this.cpu.getReg(15) >>> 0;
      // `>>> 0` again: without it the masked value is negative and never
      // matches, so the handler "returns" by executing address 0xFFFFFFF9.
      if (((pc & 0xFFFFFFF0) >>> 0) === 0xFFFFFFF0) {
        if (pc === 0xFFFFFFFE) { this.halted = true; break; }   // game_main returned
        this.exceptionReturn();
        continue;
      }

      let c: number;
      try {
        c = this.cpu.step(this);
      } catch (e) {
        console.error(`[Uvm2System] CPU fault at 0x${pc.toString(16)}:`, e);
        this.halted = true;
        break;
      }
      spent += c;
      this.advanceBus(c);
    }

    this.lastFrameBusCycles = BUS_PER_FRAME;
    const { draw, drawCnt, erse, erseCnt } = this.beam.swapBuffers();
    this.canvas.renderFrame(draw, drawCnt, erse, erseCnt);
    const segments = vectorsToSegments(draw, drawCnt, this.frameCounter);
    this.frameCounter++;
    return segments;
  }

  // ─── Host wiring (canvas, input, audio) ───────────────────────────────────

  setCanvas(el: HTMLCanvasElement): void { this.canvas.setCanvas(el); }

  /**
   * Joystick axes. The image reads these the hard way — it drives the DAC and
   * compares against the pot through the VIA's comparator bit — so the values
   * go where the analog hardware expects them, not into a shortcut register.
   */
  setJoyAxis(x: number, y: number): void {
    this.beam.alg_jch0 = Math.max(0, Math.min(255, Math.round((x / 127 + 1) * 127.5)));
    this.beam.alg_jch1 = Math.max(0, Math.min(255, Math.round((y / 127 + 1) * 127.5)));
  }

  /**
   * Buttons. On a real Vectrex these are NOT on VIA Port B — they hang off the
   * PSG's register 14, and the image reads them through the AY handshake. Port
   * B bit 5 is the joystick COMPARATOR, so routing buttons through
   * `via.joyButtons` (whose read ORs bits 4-7 into ORB) pins the comparator
   * high and every axis reads as full deflection. VectrexSystem forces
   * joyButtons to 0 for the same reason.
   *
   * `portBMask` is the host's convention: bits 4-7, active-low, bit 4 = button 1.
   * PSG register 14 wants J1 in bits 0-3 and J2 in bits 4-7, also active-low.
   */
  setJoyButtons(portBMask: number): void {
    this.psg.Regs[14] = 0xF0 | ((portBMask >> 4) & 0x0F);
  }

  /** PSG audio out. Call after a user gesture, as the browser requires. */
  startAudio(): void {
    if (this.audioCtx) return;
    try {
      const ctx = new AudioContext({ sampleRate: 44100 });
      // eslint-disable-next-line @typescript-eslint/no-deprecated
      const node = ctx.createScriptProcessor(2048, 0, 1);
      node.onaudioprocess = (ev) => {
        this.psg.fillBuffer(ev.outputBuffer.getChannelData(0), 2048);
      };
      node.connect(ctx.destination);
      this.audioCtx = ctx;
      this.audioNode = node;
      if (ctx.state !== 'running') ctx.resume().catch(() => {});
    } catch (e) {
      console.warn('[Uvm2System] Audio init failed:', e);
    }
  }

  stopAudio(): void {
    try { this.audioNode?.disconnect(); this.audioCtx?.close().catch(() => {}); } catch {}
    this.audioNode = null;
    this.audioCtx = null;
  }

  getAudioContextAndOutputNode(): { ctx: AudioContext; outputNode: AudioNode } | null {
    return this.audioCtx && this.audioNode
      ? { ctx: this.audioCtx, outputNode: this.audioNode }
      : null;
  }
}
