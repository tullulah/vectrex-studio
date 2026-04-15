import type { Segment } from '../../emulatorCore.js';

/**
 * ISystem — top-level emulated machine interface.
 *
 * A system owns one CPU, one memory bus, and all hardware peripherals.
 * `VectrexSystem` is the concrete implementation; additional systems
 * (e.g. a headless test harness) can implement this interface without
 * depending on the DOM.
 */
export interface ISystem {
  /**
   * Initialise the system with ROM images.
   * @param rom   Vectrex BIOS (8 KB, mapped at 0xE000–0xFFFF).
   * @param bios  Alias for rom — accepted for compatibility; ignored when rom is provided.
   */
  init(rom: Uint8Array, bios?: Uint8Array): void;

  /**
   * Advance emulation by one display frame (≈ 1/50 s at 1.5 MHz).
   * Returns all vector segments that were drawn during the frame.
   */
  runFrame(): Segment[];

  /** Reset the system to power-on state (equivalent to pressing RESET on the console). */
  reset(): void;

  /** Human-readable CPU identifier, e.g. "MC6809". */
  readonly cpuName: string;
}
