import type { IBus } from './IBus.js';

/**
 * ICpu — MC6809 (or compatible) CPU interface.
 *
 * The implementation is still provided by the existing e6809 object inside
 * vecx_full.js during Phase 1.  Phase 2 will wrap it in a typed class.
 */
export interface ICpu {
  /** Hard reset: load reset vector, initialise all registers. */
  reset(): void;

  /**
   * Execute exactly one instruction.
   * @param bus  Memory bus used for all reads/writes during the instruction.
   * @returns    Number of clock cycles consumed (always >= 1).
   */
  step(bus: IBus): number;

  /** Current Program Counter value (0–0xFFFF). */
  get pc(): number;

  /** Total cycle count since last reset. */
  get cycles(): number;

  /**
   * Assert an interrupt line.
   * @param line  0 = IRQ, 1 = FIRQ, 2 = NMI (matching 6809 convention).
   */
  irq(line: number): void;
}
