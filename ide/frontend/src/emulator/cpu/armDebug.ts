/**
 * Breakpoints and single steps for an ARM system's core 0, checked by the system's
 * frame loop before each instruction it runs (`shouldStop(pc)`): when it says stop,
 * the loop leaves the frame where it is and the caller stops asking for frames.
 *
 * The first check after a resume never stops on a breakpoint, so continuing from one
 * does not stop on it again; a step stops at the second check, after one instruction
 * (a trapped SDK routine counts as one: it returns at once).
 */
export type ArmStopReason = 'breakpoint' | 'step';

export class ArmDebug {
  readonly breakpoints = new Set<number>();
  /** Why the last frame stopped short; null while nothing stopped it. */
  stopped: ArmStopReason | null = null;
  private stepping = false;
  private first = false;
  /** Called the moment a stop happens (the IDE pauses and gdb gets its stop reply). */
  onStop: ((reason: ArmStopReason, pc: number) => void) | null = null;

  /** Run on: to the next breakpoint, or (step) for one instruction. */
  resume(step: boolean): void {
    this.stopped = null;
    this.stepping = step;
    this.first = true;
  }

  /** Is there anything to check? Lets a frame loop skip the call in the common case. */
  get armed(): boolean { return this.stepping || this.breakpoints.size > 0; }

  shouldStop(pc: number): boolean {
    pc = (pc & ~1) >>> 0;
    const first = this.first;
    this.first = false;
    let reason: ArmStopReason | null = null;
    if (this.stepping) { if (!first) reason = 'step'; }
    else if (!first && this.breakpoints.has(pc)) reason = 'breakpoint';
    if (!reason) return false;
    this.stepping = false;
    this.stopped = reason;
    this.onStop?.(reason, pc);
    return true;
  }
}
