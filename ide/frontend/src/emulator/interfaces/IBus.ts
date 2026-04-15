/**
 * IBus — memory bus interface.
 *
 * The CPU calls read8/write8 on every memory access.  Implementations (VectrexSystem)
 * route accesses to ROM, RAM, VIA registers, and the cartridge banking window.
 */
export interface IBus {
  read8(addr: number): number;
  write8(addr: number, data: number): void;
}
