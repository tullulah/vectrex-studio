/**
 * Breakpoints and steps for an ARM system's core 0, checked by the system's frame
 * loop before each instruction it runs (`shouldStop(pc, sp)`): when it says stop,
 * the loop leaves the frame where it is and the caller stops asking for frames.
 *
 * Two users: gdb (debug/gdbStub.ts: its breakpoints, single instructions) and the
 * IDE's editor (debug/armSourceDebug.ts: the editor's breakpoints, and steps by
 * source statement through `until`). Each keeps its own breakpoints, so a gdb detach
 * does not drop the editor's.
 *
 * The first check after a resume never stops on a breakpoint, so continuing from one
 * does not stop on it again; an instruction step stops at the second check (a trapped
 * SDK routine counts as one instruction: it returns at once).
 */
export type ArmStopReason = 'breakpoint' | 'step';

export class ArmDebug {
  /** gdb's breakpoints. */
  readonly breakpoints = new Set<number>();
  /** The editor's breakpoints. */
  readonly ideBreakpoints = new Set<number>();
  /** Why the last frame stopped short; null while nothing stopped it. */
  stopped: ArmStopReason | null = null;
  private stepping = false;
  /** A source step: stop at the first instruction this accepts (after the current one). */
  private until: ((pc: number, sp: number) => boolean) | null = null;
  private first = false;
  private readonly listeners = new Set<(reason: ArmStopReason, pc: number) => void>();

  /** Called the moment a stop happens (the IDE pauses; gdb gets its stop reply). */
  onStop(fn: (reason: ArmStopReason, pc: number) => void): void { this.listeners.add(fn); }

  /** Run on: to the next breakpoint, for one instruction (step), or until `until` says. */
  resume(step: boolean, until: ((pc: number, sp: number) => boolean) | null = null): void {
    this.stopped = null;
    this.stepping = step;
    this.until = until;
    this.first = true;
  }

  /** Is there anything to check? Lets a frame loop skip the call in the common case. */
  get armed(): boolean {
    return this.stepping || this.until !== null || this.breakpoints.size > 0 || this.ideBreakpoints.size > 0;
  }

  /** A step is under way (an instruction or a source step): every instruction must be
   *  checked. With breakpoints alone, only their addresses need to be. */
  get stepActive(): boolean {
    return this.stepping || this.until !== null;
  }

  /** Every breakpoint address (gdb's and the editor's), bit 0 clear. */
  breakpointAddresses(): number[] {
    return [...this.breakpoints, ...this.ideBreakpoints].map(a => (a & ~1) >>> 0);
  }

  shouldStop(pc: number, sp: number): boolean {
    pc = (pc & ~1) >>> 0;
    const first = this.first;
    this.first = false;
    let reason: ArmStopReason | null = null;
    if (this.stepping) { if (!first) reason = 'step'; }
    else if (!first && this.until && this.until(pc, sp >>> 0)) reason = 'step';
    else if (!first && (this.breakpoints.has(pc) || this.ideBreakpoints.has(pc))) reason = 'breakpoint';
    if (!reason) return false;
    this.stepping = false;
    this.until = null;
    this.stopped = reason;
    for (const fn of this.listeners) fn(reason, pc);
    return true;
  }
}
