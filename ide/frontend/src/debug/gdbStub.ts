/**
 * The gdb remote protocol's commands, answered for an ARM Cortex-M target.
 *
 * The Electron main process owns the TCP socket and the packet framing
 * (ide/electron/src/gdb/): it hands each packet's body to `handle`, sends back what
 * it returns, and — after a continue, which has no immediate answer — asks `poll`
 * until the target stops. A Ctrl+C from gdb arrives as `interrupt`.
 *
 * Registers are the M-profile set gdb expects from target.xml below: r0-r12, sp, lr,
 * pc (0-15) and xpsr (16). Breakpoints are the target's own (Z0 and Z1 alike), so gdb
 * never writes a BKPT into the program.
 *
 * Pure: everything about the emulator is behind `GdbTarget`.
 * tools/gdb-stub-test.ts runs it against a fake target.
 */

export type StopReason = 'breakpoint' | 'step' | 'halt';

export interface GdbTarget {
  /** 0-15: r0..pc, 16: xpsr. */
  readReg(n: number): number;
  writeReg(n: number, v: number): void;
  /** null: the range is not memory (a peripheral, or nothing there). */
  readMem(addr: number, len: number): Uint8Array | null;
  writeMem(addr: number, bytes: Uint8Array): boolean;
  addBreakpoint(addr: number): void;
  removeBreakpoint(addr: number): void;
  clearBreakpoints(): void;
  /** Run one instruction, now. */
  step(): void;
  /** Run until a breakpoint (or a halt); the stop shows up in takeStop. */
  cont(): void;
  /** Stop running (gdb's Ctrl+C), at once. */
  halt(): void;
  /** The stop since cont(), once; null while still running. */
  takeStop(): StopReason | null;
  /** Leave it running with no breakpoints of gdb's. */
  detach(): void;
}

const REGS = 17;
const MAX_PACKET = 0x4000;

export const TARGET_XML =
  '<?xml version="1.0"?><!DOCTYPE target SYSTEM "gdb-target.dtd"><target version="1.0">' +
  '<architecture>arm</architecture><feature name="org.gnu.gdb.arm.m-profile">' +
  Array.from({ length: 13 }, (_, i) => `<reg name="r${i}" bitsize="32" type="uint32"/>`).join('') +
  '<reg name="sp" bitsize="32" type="data_ptr"/><reg name="lr" bitsize="32" type="uint32"/>' +
  '<reg name="pc" bitsize="32" type="code_ptr"/><reg name="xpsr" bitsize="32" type="uint32"/>' +
  '</feature></target>';

const hex8 = (b: number) => (b & 0xff).toString(16).padStart(2, '0');
/** A 32-bit value in target (little-endian) byte order, as gdb wants registers. */
const le32 = (v: number) => hex8(v) + hex8(v >>> 8) + hex8(v >>> 16) + hex8(v >>> 24);
const fromLe32 = (h: string) => (parseInt(h.slice(6, 8) + h.slice(4, 6) + h.slice(2, 4) + h.slice(0, 2), 16) >>> 0);
const bytesFromHex = (h: string) => Uint8Array.from(h.match(/../g) || [], (x) => parseInt(x, 16));

const SIGNAL: Record<StopReason, string> = { breakpoint: '05', step: '05', halt: '02' };

export class GdbStub {
  private readonly target: GdbTarget;
  constructor(target: GdbTarget) { this.target = target; }

  /** The stop reply: signal, the pc, and the one thread there is. */
  private stopReply(reason: StopReason): string {
    return `T${SIGNAL[reason]}0f:${le32(this.target.readReg(15))};thread:1;`;
  }

  /** The answer to one packet; null when it comes later (a continue: see poll). */
  handle(pkt: string): string | null {
    const t = this.target;
    const c = pkt[0];
    switch (c) {
      case '?': return this.stopReply('halt');
      case 'g': return Array.from({ length: REGS }, (_, i) => le32(t.readReg(i))).join('');
      case 'G': {
        for (let i = 0; i < REGS && (i + 1) * 8 <= pkt.length - 1; i++) t.writeReg(i, fromLe32(pkt.slice(1 + i * 8, 9 + i * 8)));
        return 'OK';
      }
      case 'p': {
        const n = parseInt(pkt.slice(1), 16);
        return n < REGS ? le32(t.readReg(n)) : 'E01';
      }
      case 'P': {
        const [n, v] = pkt.slice(1).split('=');
        const r = parseInt(n, 16);
        if (r >= REGS || !v) return 'E01';
        t.writeReg(r, fromLe32(v));
        return 'OK';
      }
      case 'm': {
        const [a, l] = pkt.slice(1).split(',').map((x) => parseInt(x, 16));
        const bytes = t.readMem(a >>> 0, Math.min(l, MAX_PACKET / 2));
        return bytes ? Array.from(bytes, hex8).join('') : 'E14';
      }
      case 'M': {
        const [head, data] = pkt.slice(1).split(':');
        const [a] = head.split(',').map((x) => parseInt(x, 16));
        return t.writeMem(a >>> 0, bytesFromHex(data || '')) ? 'OK' : 'E14';
      }
      case 'Z':
      case 'z': {
        const [kind, a] = pkt.slice(1).split(',');
        if (kind !== '0' && kind !== '1') return ''; // watchpoints: not supported
        const addr = (parseInt(a, 16) & ~1) >>> 0;
        if (c === 'Z') t.addBreakpoint(addr); else t.removeBreakpoint(addr);
        return 'OK';
      }
      case 'c':
        if (pkt.length > 1) t.writeReg(15, parseInt(pkt.slice(1), 16) >>> 0);
        t.cont();
        return null;
      case 's':
        if (pkt.length > 1) t.writeReg(15, parseInt(pkt.slice(1), 16) >>> 0);
        t.step();
        return this.stopReply(t.takeStop() ?? 'step');
      case 'H':
      case 'T': return 'OK';
      case 'D':
        t.detach();
        return 'OK';
      case 'k':
        t.detach();
        return null;
      case 'q':
        return this.query(pkt);
      default:
        return ''; // unsupported (X, vCont, vMustReplyEmpty...): gdb falls back
    }
  }

  private query(pkt: string): string {
    if (pkt.startsWith('qSupported')) return `PacketSize=${MAX_PACKET.toString(16)};qXfer:features:read+;QStartNoAckMode+`;
    if (pkt.startsWith('qXfer:features:read:target.xml:')) {
      const [off, len] = pkt.split(':')[4].split(',').map((x) => parseInt(x, 16));
      const part = TARGET_XML.slice(off, off + len);
      return (off + len >= TARGET_XML.length ? 'l' : 'm') + part;
    }
    if (pkt === 'qAttached') return '1';
    if (pkt === 'qC') return 'QC1';
    if (pkt === 'qfThreadInfo') return 'm1';
    if (pkt === 'qsThreadInfo') return 'l';
    if (pkt.startsWith('qSymbol')) return 'OK';
    return '';
  }

  /** After a continue: the stop reply once the target stopped, else null. */
  poll(): string | null {
    const r = this.target.takeStop();
    return r ? this.stopReply(r) : null;
  }

  /** gdb's Ctrl+C. */
  interrupt(): string {
    this.target.halt();
    this.target.takeStop();
    return this.stopReply('halt');
  }
}
