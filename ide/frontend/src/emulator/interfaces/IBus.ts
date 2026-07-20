/**
 * IBus — memory bus interface.
 *
 * The CPU calls read8/write8 on every memory access.  Implementations (VectrexSystem)
 * route accesses to ROM, RAM, VIA registers, and the cartridge banking window.
 */
export interface IBus {
  read8(addr: number): number;
  write8(addr: number, data: number): void;
  /**
   * Optional ARM `svc #imm` (supervisor call) hook. A Cortex-M system (RP2350
   * BIOS) implements this to dispatch BIOS syscalls: the CPU passes the 8-bit
   * `svc` immediate; the handler reads args from r0-r3 and writes the return
   * value into r0 (AAPCS), same as a real SVCall exception. Systems without a
   * supervisor layer (e.g. the 6809 Vectrex) omit it and `svc` is a NOP.
   */
  onSvc?(imm: number, cpu: { getReg(i: number): number; setReg(i: number, v: number): void }): void;
}
