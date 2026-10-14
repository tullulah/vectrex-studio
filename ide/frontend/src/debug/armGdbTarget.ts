/**
 * gdb's view of the ARM emulator that is running now (rp2350 or uvm2): core 0's
 * registers, the memory, and breakpoints/steps through the system's ArmDebug
 * (emulator/cpu/armDebug.ts). Installed as `window.__gdbStub__`, which the Electron
 * main process's gdb server (ide/electron/src/gdb/) calls for every packet.
 *
 * Running and pausing go through the debug store, as the IDE's own buttons do: the
 * ARM frame loop (EmulatorPanel) only runs frames while the state is 'running'.
 */
import { emuCore } from '../emulatorCoreSingleton';
import { useDebugStore } from '../state/debugStore';
import { GdbStub, type GdbTarget, type StopReason } from './gdbStub';
import type { ArmDebug } from '../emulator/cpu/armDebug';
import type { Thumb2 } from '../emulator/cpu/Thumb2';

interface ArmSystem {
  debug: ArmDebug;
  core0: Thumb2;
  read8(addr: number): number;
  write8(addr: number, v: number): void;
  runFrame(): unknown;
}

/** Where a debugger may read and write: memory only, never a peripheral register
 *  (reading the VIA or a FIFO has side effects). */
const MEMORY: Array<[number, number]> = [
  [0x00000000, 0x00008000], // boot ROM
  [0x10000000, 0x14000000], // flash and PSRAM (XIP)
  [0x20000000, 0x20082000], // SRAM
];
const isMemory = (a: number, len: number) => MEMORY.some(([lo, hi]) => a >= lo && a + len <= hi);

function system(): ArmSystem | null {
  return ((emuCore as any).activeArmSystem as ArmSystem | null) ?? null;
}

function need(): ArmSystem {
  const s = system();
  if (!s) throw new Error('No ARM program is loaded (build and run an rp2350 or uvm2 target)');
  return s;
}

let pendingStop: StopReason | null = null;

/** Every system's stops reach the IDE: it pauses, and gdb is told (poll). */
const watched = new WeakSet<ArmSystem>();
function watch(s: ArmSystem): void {
  if (watched.has(s)) return;
  watched.add(s);
  s.debug.onStop((reason) => {
    pendingStop = reason;
    useDebugStore.getState().setState('paused');
  });
}

const target: GdbTarget = {
  readReg: (n) => {
    const cpu = need().core0;
    return n === 16 ? cpu.getXpsr() : cpu.getReg(n);
  },
  writeReg: (n, v) => {
    const cpu = need().core0;
    if (n === 16) cpu.setXpsr(v); else cpu.setReg(n, v);
  },
  readMem: (addr, len) => {
    const s = system();
    if (!s || !isMemory(addr, len)) return null;
    return Uint8Array.from({ length: len }, (_, i) => s.read8(addr + i) & 0xff);
  },
  writeMem: (addr, bytes) => {
    const s = system();
    if (!s || !isMemory(addr, bytes.length)) return false;
    bytes.forEach((b, i) => s.write8(addr + i, b));
    return true;
  },
  addBreakpoint: (addr) => { const s = need(); watch(s); s.debug.breakpoints.add(addr); },
  removeBreakpoint: (addr) => { need().debug.breakpoints.delete(addr); },
  clearBreakpoints: () => { system()?.debug.breakpoints.clear(); },
  step: () => {
    const s = need();
    watch(s);
    useDebugStore.getState().setState('paused');
    s.debug.resume(true);
    s.runFrame(); // stops after one instruction (or at the frame's end, a WFI)
  },
  cont: () => {
    const s = need();
    watch(s);
    pendingStop = null;
    s.debug.resume(false);
    useDebugStore.getState().setState('running');
  },
  halt: () => {
    useDebugStore.getState().setState('paused');
    pendingStop = 'halt';
  },
  takeStop: () => {
    const r = pendingStop;
    pendingStop = null;
    return r;
  },
  detach: () => {
    const s = system();
    if (!s) return;
    s.debug.breakpoints.clear();
    pendingStop = null;
    s.debug.resume(false);
    useDebugStore.getState().setState('running');
  },
};

/** Wrap a stub call: the main process gets {ok, value} or {ok:false, error}. */
const guard = <T>(f: () => T) => {
  try { return { ok: true, value: f() }; } catch (e: any) { return { ok: false, error: String(e?.message || e) }; }
};

let installed = false;

export function installArmGdbTarget(): void {
  if (installed) return;
  installed = true;
  const stub = new GdbStub(target);
  (window as any).__gdbStub__ = {
    handle: (pkt: string) => guard(() => stub.handle(pkt)),
    poll: () => guard(() => stub.poll()),
    interrupt: () => guard(() => stub.interrupt()),
    /** gdb connected: it expects the program stopped. */
    attach: () => guard(() => { need(); target.halt(); target.takeStop(); return true; }),
  };
  // The IDE's own Continue after a stop: run on past the breakpoint it stopped on
  useDebugStore.subscribe((st, prev) => {
    if (st.state === 'running' && prev.state !== 'running') {
      const s = system();
      if (s?.debug.stopped) s.debug.resume(false);
    }
  });
}
