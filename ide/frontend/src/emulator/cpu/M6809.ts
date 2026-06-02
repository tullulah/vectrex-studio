/**
 * M6809 — ICpu adapter wrapping the e6809 object from vecx_full.js.
 *
 * The e6809 JavaScript object accesses memory exclusively through
 * `this.vecx.read8(addr)` and `this.vecx.write8(addr, data)`.  Before each
 * call to `e6809_sstep` we replace `cpu.vecx` with a thin proxy that routes
 * those calls through our `IBus`.  This lets the typed VectrexSystem own the
 * memory map while the original (unmodified) e6809 JS logic handles all CPU
 * decode/execute work.
 *
 * The `e6809` instance is obtained from the existing `VecX` global (created
 * by vecx_full.js) and passed in via the constructor so we never duplicate
 * CPU state.
 */

import type { ICpu } from '../interfaces/ICpu.js';
import type { IBus } from '../interfaces/IBus.js';

/** Minimal shape of the `this.vecx` proxy that e6809_sstep requires. */
interface VecxProxy {
  read8(addr: number): number;
  write8(addr: number, data: number): void;
}

/**
 * Wraps a raw `e6809` JavaScript object (from vecx_full.js) behind the typed
 * `ICpu` interface.
 *
 * Usage:
 * ```ts
 * const vecxInst = (window as any).vecx;       // global from vecx_full.js
 * const cpu = new M6809(vecxInst.e6809);
 * ```
 */
export class M6809 implements ICpu {
  /** The raw e6809 JS object from vecx_full.js. */
  private readonly _cpu: any;

  /** Accumulated cycle count since last reset(). */
  private _cycles: number = 0;

  /**
   * Reusable proxy object.  We mutate its callbacks each step to avoid
   * allocating a new object on every instruction.
   */
  private _proxy: VecxProxy;

  constructor(e6809Instance: any) {
    this._cpu = e6809Instance;

    // Initialise the proxy with no-op callbacks; they are replaced in step().
    this._proxy = {
      read8: (_addr: number) => 0xff,
      write8: (_addr: number, _data: number) => { /* noop */ },
    };
  }

  // ------------------------------------------------------------------ //
  // ICpu
  // ------------------------------------------------------------------ //

  reset(): void {
    this._cycles = 0;
    // The e6809 reset vector read happens through the bus — callers must
    // ensure ROM is loaded before calling reset(), then set reg_pc themselves
    // (matching the pattern already used by jsvecxCore.ts).
  }

  /**
   * Execute a single instruction.
   *
   * Before calling `e6809_sstep` we swap `cpu.vecx` to our IBus proxy so
   * that all memory accesses inside the instruction are routed through our
   * typed memory map.  After the call we restore the original reference so
   * that any other code that may call the CPU outside our loop still works.
   */
  step(bus: IBus): number {
    // Route all e6809 memory accesses through our bus for this instruction.
    this._proxy.read8  = (addr: number) => bus.read8(addr);
    this._proxy.write8 = (addr: number, data: number) => bus.write8(addr, data);

    const prevVecx = this._cpu.vecx;
    this._cpu.vecx = this._proxy;

    let icycles: number;
    try {
      // irq_i and irq_f: the VectrexSystem passes interrupt lines explicitly.
      // For now we pass 0 for both and let VectrexSystem assert them via irq().
      // e6809_sstep always returns a plain number (cycles.value from the fptr).
      icycles = (this._cpu.e6809_sstep(0, 0) as number) | 0;
      if (icycles < 1) icycles = 1;
    } finally {
      this._cpu.vecx = prevVecx;
    }

    this._cycles += icycles;
    return icycles;
  }

  get pc(): number {
    return this._cpu.reg_pc as number;
  }

  get cycles(): number {
    return this._cycles;
  }

  /**
   * Assert an interrupt line.
   * @param line  0 = IRQ, 1 = FIRQ.
   *
   * The next call to `step()` will pass the appropriate flag to
   * `e6809_sstep(irq_i, irq_f)`.  For simplicity we store pending lines and
   * pass them on the very next step, then clear them.
   */
  irq(line: number): void {
    // Store the pending IRQ so step() picks it up.
    if (line === 0) this._pendingIrqI = 1;
    if (line === 1) this._pendingIrqF = 1;
  }

  private _pendingIrqI: number = 0;
  private _pendingIrqF: number = 0;

  /**
   * Variant of step() that passes pending interrupt flags to e6809_sstep.
   * VectrexSystem calls this instead of step() so IRQ delivery is correct.
   */
  stepWithIrq(bus: IBus): number {
    this._proxy.read8  = (addr: number) => bus.read8(addr);
    this._proxy.write8 = (addr: number, data: number) => bus.write8(addr, data);

    const prevVecx = this._cpu.vecx;
    this._cpu.vecx = this._proxy;

    const irqI = this._pendingIrqI;
    const irqF = this._pendingIrqF;
    this._pendingIrqI = 0;
    this._pendingIrqF = 0;

    let icycles: number;
    try {
      icycles = (this._cpu.e6809_sstep(irqI, irqF) as number) | 0;
      if (icycles < 1) icycles = 1;
    } finally {
      this._cpu.vecx = prevVecx;
    }

    this._cycles += icycles;
    return icycles;
  }

  // ------------------------------------------------------------------ //
  // Expose raw register values (used by VectrexSystem.registers())
  // ------------------------------------------------------------------ //
  get regA(): number  { return this._cpu.reg_a  as number; }
  get regB(): number  { return this._cpu.reg_b  as number; }
  get regDP(): number { return this._cpu.reg_dp as number; }
  get regX(): number  { return (this._cpu.reg_x?.value  ?? 0) as number; }
  get regY(): number  { return (this._cpu.reg_y?.value  ?? 0) as number; }
  get regU(): number  { return (this._cpu.reg_u?.value  ?? 0) as number; }
  get regS(): number  { return (this._cpu.reg_s?.value  ?? 0) as number; }
}
