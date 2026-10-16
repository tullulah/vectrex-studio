/**
 * The editor's debugger on the cartridge itself: the RP2350 cartridge over SWD, or the UVMC2
 * over USB through the game's debug monitor (uvmc2-sdk monitor/debug.c). The session below is
 * the same for both; what differs is its Transport (memory, registers, one instruction,
 * continue, pause): SwdTransport (probe-rs's DAP) or MonitorTransport (the monitor's lines).
 * The rest of this comment is the RP2350's; the UVMC2's game is already running (an upload
 * started it) and the session attaches to it (startUvmc2Debug).
 *
 * The IDE builds the game as for the SD card (a RAM image with the 'VPy2' header), resets
 * the cartridge to its menu, writes the image where the firmware loads games from the card
 * (the PSRAM at GAME_LOAD_ADDR) and asks the menu to launch it through a mailbox the
 * firmware reads every frame (bios.rs, SWD_LAUNCH). From then on the game runs on core 1
 * and the editor debugs it there, through a probe-rs DAP session attached to core 1 alone
 * (electron/src/hwdebug/session.ts says why only that core).
 *
 * To the editor's debugger (armSourceDebug.ts) the cartridge looks like an emulator: a run
 * control, registers and memory. The registers and the memory it reads are fetched when the
 * game stops, since a read through the probe takes tens of milliseconds and the debugger
 * reads synchronously; the code comes from the ELF, it does not change.
 *
 * BREAKPOINTS ARE SOFTWARE: a BKPT written over the instruction, the original put back
 * after. The core has a handful of hardware ones and a step needs one at every statement
 * of the function it is in; and a single-step through the probe takes ~100 ms, so a step
 * cannot walk instruction by instruction either. A step therefore marks where it may stop
 * (armSourceDebug.stepStops, plus the return address to leave the function), runs to the
 * first of them, and goes on until the step's own rule (the `until` of armStep) accepts
 * where it stopped. Every BKPT is taken out before the session ends: a BKPT met with no
 * debugger attached is a HardFault.
 */
import { useDebugStore } from '../state/debugStore';
import { useProjectStore } from '../state/projectStore';
import { armCallStack, armStep, setHardwareArmSystem, stepStops, type ArmRunControl, type ArmSystem } from './armSourceDebug';
import type { ArmStopReason } from '../emulator/cpu/armDebug';
import { symbolAddresses } from './dwarfLines';

/** The firmware's launch mailbox (bios.rs): magic, size, answer. */
const SWD_LAUNCH = 0x20080004;
const SWD_LAUNCH_MAGIC = 0x53574C4E;
const SWD_LAUNCH_OK = 0x4F4B4F4B;
const SWD_LAUNCH_BAD = 0x42414421;
/** The firmware's "a game is going up" mailbox (bios.rs, UPLOAD): magic, total, done, name. */
const UPLOAD = 0x20080010;
const UPLOAD_MAGIC = 0x444C5055;
/** The firmware's "paused by the debugger" flag (bios.rs, PAUSE_FLAG): while set, core 0
 *  draws the pause sign over its redraw of the last frame. */
const PAUSE_FLAG = 0x20080040;
const PAUSE_MAGIC = 0x53554150;
/** The game's name on the card (16 bytes): the firmware finds its romset and samples by it. */
const SWD_STEM = 0x20080044;
/** Where the firmware loads a game (sd.rs GAME_LOAD_ADDR) and where it copies one linked for SRAM. */
const GAME_LOAD_ADDR = 0x11000000;
const GAME_SRAM_ADDR = 0x20040000;
const BKPT = [0x00, 0xBE];
/**
 * The RP2350's timers stop while a core is halted by the debugger (DBGPAUSE: bit 0 = core 0,
 * bit 1 = core 1; both set at reset). Core 0 paces its redraw of the last command list with
 * TIMER0, so with core 1 paused the whole cartridge stopped drawing, though core 0 itself
 * was running. The session clears the core-1 bit (core 0 is never halted) and puts the
 * register back as it found it.
 */
const TIMER_DBGPAUSE = [0x400B002C, 0x400B802C];   // TIMER0, TIMER1
/** Memory the debugger may read: SRAM and its scratch banks, and the PSRAM a game's data
 *  lives in when it is linked there (a C-backend game's .bss) -- never a peripheral. */
const SRAM: [number, number] = [0x20000000, 0x20082000];
const PSRAM: [number, number] = [0x11000000, 0x11800000];
const PAGE = 256;
const THREAD = 1;

interface HwApi {
  start(args: { elfPath: string }): Promise<{ ok: true } | { error: string }>;
  request(command: string, args?: unknown): Promise<any>;
  end(): Promise<unknown>;
  onEvent(cb: (ev: any) => void): () => void;
  onEnded(cb: (why: string) => void): () => void;
}
const api = (): HwApi | undefined => (window as any).hwDebug;

/** The ELF's loaded sections: the code and constants (read from here), the data (from the cartridge). */
interface Section { start: number; end: number; bytes: Uint8Array | null; writable: boolean }

function elfSections(elf: Uint8Array): Section[] {
  const dv = new DataView(elf.buffer, elf.byteOffset, elf.byteLength);
  if (dv.getUint32(0, false) !== 0x7f454c46 || elf[4] !== 1) return [];
  const shoff = dv.getUint32(0x20, true), shentsize = dv.getUint16(0x2e, true), shnum = dv.getUint16(0x30, true);
  const out: Section[] = [];
  for (let i = 0; i < shnum; i++) {
    const o = shoff + i * shentsize;
    const type = dv.getUint32(o + 4, true), flags = dv.getUint32(o + 8, true);
    const addr = dv.getUint32(o + 0x0c, true), off = dv.getUint32(o + 0x10, true), size = dv.getUint32(o + 0x14, true);
    if (!(flags & 2) || !size) continue;                      // SHF_ALLOC
    out.push({
      start: addr, end: addr + size,
      bytes: type === 8 ? null : elf.subarray(off, off + size), // SHT_NOBITS (.bss) has none
      writable: !!(flags & 1),                                  // SHF_WRITE
    });
  }
  return out;
}

/** What the session needs of the cartridge. Stops come back through handleEvent, as DAP
 *  'stopped' events: reason 'step' (one instruction done), 'breakpoint' or 'pause'. */
interface Transport {
  readonly kind: 'swd' | 'monitor';
  readMem(addr: number, count: number): Promise<Uint8Array>;
  writeMem(addr: number, bytes: Uint8Array): Promise<void>;
  /** r0-r15 of the stopped program. */
  registers(): Promise<number[]>;
  writeRegister?(n: number, value: number): Promise<void>;
  stepInstruction(): Promise<void>;
  cont(): Promise<void>;
  pause(): Promise<void>;
  configure?(): Promise<void>;
  end(): Promise<unknown>;
  /** Breakpoints kept by the cartridge itself (the monitor): it holds the original code and
   *  steps off a breakpoint on its own when it goes on. Without it they are BKPTs written
   *  over the code (writeMem), and the session steps off them. */
  patch?(add: number[], remove: number[]): Promise<void>;
}

const b64 = (bytes: Uint8Array) => { let s = ''; for (const b of bytes) s += String.fromCharCode(b); return btoa(s); };
const unb64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const hex = (n: number) => '0x' + (n >>> 0).toString(16);

/** probe-rs's DAP server on the RP2350 cartridge (electron/src/hwdebug/session.ts). */
class SwdTransport implements Transport {
  readonly kind = 'swd' as const;

  private async dap(command: string, args: unknown = {}): Promise<any> {
    const r = await api()!.request(command, args);
    if (!r?.success) throw new Error(`${command}: ${r?.message ?? 'failed'}`);
    return r;
  }

  async readMem(addr: number, count: number): Promise<Uint8Array> {
    const r = await this.dap('readMemory', { memoryReference: hex(addr), count });
    return unb64(r.body?.data ?? '');
  }

  async writeMem(addr: number, bytes: Uint8Array): Promise<void> {
    await this.dap('writeMemory', { memoryReference: hex(addr), data: b64(bytes) });
  }

  /** From the registers' scope at this stop. (No writeRegister: probe-rs 0.31's DAP server
   *  cannot set a register -- setVariable answers "cancelled", its REPL has no `set`, and
   *  DCRSR/DCRDR need word writes it does not make.) */
  async registers(): Promise<number[]> {
    const tr = await this.dap('stackTrace', { threadId: THREAD, levels: 1 });
    const frameId = tr.body?.stackFrames?.[0]?.id;
    const sc = await this.dap('scopes', { frameId });
    const ref = sc.body?.scopes?.find((s: any) => /register/i.test(s.name))?.variablesReference;
    const vars = await this.dap('variables', { variablesReference: ref });
    const regs = new Array(16).fill(0);
    for (const v of vars.body?.variables ?? []) {
      const m = /^R(\d+)\b/.exec(v.name);
      if (m && +m[1] < 16) regs[+m[1]] = parseInt(v.value, 16) >>> 0;
    }
    return regs;
  }

  async stepInstruction(): Promise<void> { await this.dap('stepIn', { threadId: THREAD, granularity: 'instruction' }); }
  async cont(): Promise<void> { await this.dap('continue', { threadId: THREAD }); }
  async pause(): Promise<void> { await this.dap('pause', { threadId: THREAD }); }
  async configure(): Promise<void> { await this.dap('configurationDone'); }
  end(): Promise<unknown> { return api()?.end() ?? Promise.resolve(); }
}

interface MonitorApi {
  start(): Promise<{ ok: true; version: string } | { error: string }>;
  request(line: string): Promise<{ line: string } | { error: string }>;
  end(): Promise<unknown>;
  onEvent(cb: (ev: { reason: string; pc: number }) => void): () => void;
  onText(cb: (text: string) => void): () => void;
  onEnded(cb: (why: string) => void): () => void;
}
const monitorApi = (): MonitorApi | undefined => (window as any).uvmc2Debug;

/** The UVMC2 game's debug monitor, over USB (electron/src/hwdebug/uvmc2Serial.ts, DebugConn). */
class MonitorTransport implements Transport {
  readonly kind = 'monitor' as const;

  private async ask(line: string): Promise<string> {
    const r = await monitorApi()!.request(line);
    if ('error' in r) throw new Error(r.error);
    if (r.line.startsWith('ERR')) throw new Error(`${line.split(' ')[0]}: the monitor said ${r.line}`);
    return r.line;
  }

  async readMem(addr: number, count: number): Promise<Uint8Array> {
    const out = new Uint8Array(count);
    for (let o = 0; o < count; o += 256) {
      const n = Math.min(256, count - o);
      const h = await this.ask(`r ${(addr + o).toString(16)} ${n}`);
      for (let i = 0; i < n; i++) out[o + i] = parseInt(h.substr(i * 2, 2), 16);
    }
    return out;
  }

  async writeMem(addr: number, bytes: Uint8Array): Promise<void> {
    for (let o = 0; o < bytes.length; o += 64) {
      let h = '';
      for (const b of bytes.subarray(o, o + 64)) h += b.toString(16).padStart(2, '0');
      await this.ask(`w ${(addr + o).toString(16)} ${h}`);
    }
  }

  /** "R r0 .. r12 sp lr pc xpsr". */
  async registers(): Promise<number[]> {
    const parts = (await this.ask('R')).split(' ').slice(1).map((x) => parseInt(x, 16) >>> 0);
    return parts.slice(0, 16);
  }

  async writeRegister(n: number, value: number): Promise<void> {
    await this.ask(`P ${n.toString(16)} ${(value >>> 0).toString(16)}`);
  }

  async patch(add: number[], remove: number[]): Promise<void> {
    for (const [cmd, list] of [['z', remove], ['Z', add]] as const) {
      for (let i = 0; i < list.length; i += 12) {   // a line holds 12 addresses
        await this.ask(`${cmd} ${list.slice(i, i + 12).map((a) => a.toString(16)).join(' ')}`);
      }
    }
  }

  async stepInstruction(): Promise<void> { await this.ask('s 0 0 0'); }   // an empty range: one instruction
  async cont(): Promise<void> { await this.ask('c'); }
  async pause(): Promise<void> { await this.ask('H'); }
  end(): Promise<unknown> { return monitorApi()?.end() ?? Promise.resolve(); }
}

class CartridgeSession implements ArmRunControl, ArmSystem {
  readonly breakpoints = new Set<number>();      // gdb's: none on the cartridge
  readonly ideBreakpoints = new Set<number>();
  stopped: ArmStopReason | null = null;
  readonly debug = this;
  readonly core0 = { getReg: (i: number) => this.regs[i] ?? 0 };

  private regs: number[] = new Array(16).fill(0);
  private pages = new Map<number, Uint8Array>();
  private readonly code: Section[];
  private readonly data: Section[];
  /** The addresses that hold a BKPT in the cartridge now. */
  private patched = new Set<number>();
  /** Until the image is in place, breakpoints only go into the image. */
  private launched = false;
  private listeners = new Set<(reason: ArmStopReason, pc: number) => void>();
  private queue: Promise<unknown> = Promise.resolve();
  /** Who waits for the next stop, and which stops it takes (the others are not its own). */
  private stopWaiter: { accept: (reason: string) => boolean; resolve: (ev: any) => void } | null = null;
  private running = false;
  /** probe-rs reports every instruction step twice: 'step', then a 'pause' nobody asked for. */
  private pauseRequested = false;
  /** A statement step is under way (it runs from stop to stop until its rule accepts one). */
  private stepping = false;
  private unsubs: Array<() => void> = [];
  closed = false;

  /** Change Value on a variable kept in a register: only through the monitor. */
  readonly writeRegister?: (n: number, value: number) => Promise<void>;

  constructor(private readonly elf: Uint8Array, private readonly t: Transport) {
    if (t.writeRegister) {
      this.writeRegister = (n, value) => this.serial(async () => {
        await t.writeRegister!(n, value);
        this.regs[n] = value >>> 0;
      });
    }
    const secs = elfSections(elf);
    this.code = secs.filter((s) => s.bytes && !s.writable);
    this.data = secs.filter((s) => s.writable);
    this.rttAddr = symbolAddresses(elf).get('_SEGGER_RTT') ?? null;
  }

  // ── RTT: the game's text (sdk_rp2350.c, vpy_log / DEBUG_PRINT) ─────────────────────────
  //
  // Read here and not by probe-rs: its DAP server looks for the control block once, when it
  // attaches -- before the game is in the PSRAM -- and gives up. The ring is polled while the
  // session lasts: up[0] (at +24) is { name, buf, size, wr, rd, flags }; what is between rd
  // and wr is new, and rd is moved on so the game has the room again.

  private readonly rttAddr: number | null;
  private rttTimer: ReturnType<typeof setInterval> | null = null;
  private rttBusy = false;
  private rttLine = '';

  private startRtt(): void {
    if (this.rttAddr === null || this.rttTimer) return;
    this.rttTimer = setInterval(() => {
      if (this.rttBusy || this.closed || this.stepping) return;
      this.rttBusy = true;
      void this.serial(() => this.pollRtt()).finally(() => { this.rttBusy = false; });
    }, 200);
  }

  private async pollRtt(): Promise<void> {
    const at = this.rttAddr! + 24;
    const d = await this.readMem(at, 20);
    const w = (o: number) => (d[o] | (d[o + 1] << 8) | (d[o + 2] << 16) | (d[o + 3] << 24)) >>> 0;
    const buf = w(4), size = w(8), wr = w(12), rd = w(16);
    if (!size || size > 65536 || wr >= size || rd >= size || wr === rd) return;
    const parts = wr > rd ? [[rd, wr - rd]] : [[rd, size - rd], [0, wr]];
    let text = '';
    for (const [o, n] of parts) if (n) text += new TextDecoder().decode(await this.readMem(buf + o, n));
    await this.write32(at + 16, wr);
    this.rttLine += text;
    const lines = this.rttLine.split('\n');
    this.rttLine = lines.pop() ?? '';
    for (const l of lines) window.dispatchEvent(new CustomEvent('hwdebug:status', { detail: { text: l.replace(/\r$/, ''), rtt: true } }));
  }

  // ── ArmSystem ────────────────────────────────────────────────────────────────────────

  read8(addr: number): number {
    const v = this.peek(addr);
    return v ?? 0;
  }

  /** A byte of the stopped program: its code from the ELF, its RAM from what was read at the
   *  stop -- or null, noted, for fetchMissed to bring in (a hover reads it on demand). */
  peek(addr: number): number | null {
    addr >>>= 0;
    for (const s of this.code) if (addr >= s.start && addr < s.end) return s.bytes![addr - s.start];
    const page = this.pages.get(Math.floor(addr / PAGE));
    if (page) return page[addr % PAGE];
    if (!this.running && [SRAM, PSRAM].some(([lo, hi]) => addr >= lo && addr < hi)) this.missed.add(Math.floor(addr / PAGE));
    return null;
  }

  private missed = new Set<number>();

  fetchMissed(): Promise<boolean> {
    const pages = [...this.missed].slice(0, 64);
    this.missed.clear();
    if (!pages.length || this.running || this.closed) return Promise.resolve(false);
    return this.serial(async () => {
      if (this.running) return false;
      for (const p of pages) await this.fetchRange(p * PAGE, (p + 1) * PAGE);
      return true;
    });
  }

  private codeHalf(addr: number): number | null {
    for (const s of this.code) {
      if (addr >= s.start && addr + 2 <= s.end) return s.bytes![addr - s.start] | (s.bytes![addr - s.start + 1] << 8);
    }
    return null;
  }

  /** The debugger setting a variable: written through the probe, and into what the stop
   *  read, so the editor shows the new value at once. */
  writeMemory(addr: number, bytes: Uint8Array): Promise<void> {
    return this.serial(async () => {
      await this.writeMem(addr, bytes);
      bytes.forEach((b, i) => {
        const page = this.pages.get(Math.floor((addr + i) / PAGE));
        if (page) page[(addr + i) % PAGE] = b;
      });
    });
  }

  // ── ArmRunControl ────────────────────────────────────────────────────────────────────

  onStop(fn: (reason: ArmStopReason, pc: number) => void): void { this.listeners.add(fn); }

  breakpointsChanged(): void {
    if (!this.launched || this.closed) return;
    void this.serial(async () => {
      const want = new Set(this.ideBreakpoints);
      const added = [...want].filter((a) => !this.patched.has(a));
      const removed = [...this.patched].filter((a) => !want.has(a));
      await this.applyPatches(want);
      const missed = added.filter((a) => !this.patched.has(a));
      if (added.length || removed.length) {
        say(`breakpoints on the cartridge: ${this.patched.size} (${added.length ? '+' + added.map(hex).join(' +') : ''}${removed.length ? ' -' + removed.map(hex).join(' -') : ''})` +
            (missed.length ? `; not in the game's code: ${missed.map(hex).join(' ')}` : ''));
      }
    });
  }

  resume(step: boolean, until: ((pc: number, sp: number) => boolean) | null = null, kind?: 'over' | 'into' | 'out'): void {
    if (this.closed) return;
    // Continue during a step that has not ended: the step gives up where it is, running
    if (this.stepping && !until) {
      const w = this.stopWaiter;
      this.stopWaiter = null;
      w?.resolve({ abort: true });
      return;
    }
    this.stopped = null;
    if (until && kind) void this.serial(() => this.stepRun(until, kind));
    else void this.serial(() => this.continueRun());
  }

  pause(): void {
    if (!this.running || this.closed) return;
    this.pauseRequested = true;
    void this.t.pause().catch((e) => say(`cartridge: ${e?.message ?? e}`, true));
  }

  // ── The session ──────────────────────────────────────────────────────────────────────

  /** One operation on the cartridge at a time (a step must not interleave with a patch). */
  private serial<T>(fn: () => Promise<T>): Promise<T> {
    const run = this.queue.then(fn, fn);
    this.queue = run.catch((e) => { if (!this.closed) say(`cartridge: ${e?.message ?? e}`, true); });
    return run;
  }

  private readMem(addr: number, count: number): Promise<Uint8Array> { return this.t.readMem(addr, count); }

  private writeMem(addr: number, bytes: Uint8Array): Promise<void> { return this.t.writeMem(addr, bytes); }

  private async read32(addr: number): Promise<number> {
    const b = await this.readMem(addr, 4);
    return (b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24)) >>> 0;
  }

  private write32(addr: number, v: number): Promise<void> {
    return this.writeMem(addr, new Uint8Array(new Uint32Array([v >>> 0]).buffer));
  }

  handleEvent(ev: any): void {
    if (ev.event !== 'stopped') return;
    const reason = String(ev.body?.reason ?? '');
    const asked = reason !== 'pause' || this.pauseRequested;
    if (reason === 'pause' && this.pauseRequested) this.pauseRequested = false;
    const w = this.stopWaiter;
    if (w) {
      if (!asked || !w.accept(reason)) return;
      this.stopWaiter = null;
      this.running = false;
      w.resolve(ev);
      return;
    }
    if (!asked) return;
    this.running = false;
    // Not waited for: a breakpoint while running freely, or a pause.
    void this.serial(async () => {
      await this.fetchStop();
      const reason: ArmStopReason = ev.body?.reason === 'breakpoint' ? 'breakpoint' : 'step';
      this.announce(reason);
    });
  }

  /** The next stop whose reason `accept` takes: 'step' after an instruction step; a breakpoint or a pause after a continue. */
  private waitStop(accept: (reason: string) => boolean): Promise<any> {
    return new Promise((resolve) => { this.stopWaiter = { accept, resolve }; });
  }

  /** Upload the game, its breakpoints already in it, and have the menu launch it. */
  launch(image: Uint8Array, name: string, stem: string): Promise<void> {
    return this.serial(() => this.launchNow(image, name, stem));
  }

  /** DBGPAUSE as the session found it, to put back at the end. */
  private dbgPause: number[] | null = null;

  /** The UVMC2: the game is running already (an upload started it); its breakpoints go in now. */
  attachRunning(): Promise<void> {
    return this.serial(async () => {
      this.launched = true;
      this.running = true;
      await this.applyPatches(new Set(this.ideBreakpoints));
    });
  }

  private async launchNow(image: Uint8Array, name: string, stem: string): Promise<void> {
    await this.t.configure?.();
    // the game paused on core 1 must not stop the clock core 0 draws by
    const saved: number[] = [];
    for (const r of TIMER_DBGPAUSE) {
      const v = await this.read32(r);
      saved.push(v);
      await this.write32(r, v & ~2);
    }
    this.dbgPause = saved;
    const entry = (image[4] | (image[5] << 8) | (image[6] << 16) | (image[7] << 24)) >>> 0;
    const linkBase = ((entry & ~1) >>> 0) >= GAME_SRAM_ADDR && ((entry & ~1) >>> 0) < SRAM[1] ? GAME_SRAM_ADDR : GAME_LOAD_ADDR;
    const bytes = image.slice();
    for (const a of this.ideBreakpoints) {
      const o = a - linkBase;
      if (o >= 0 && o + 2 <= bytes.length) { bytes[o] = BKPT[0]; bytes[o + 1] = BKPT[1]; this.patched.add(a); }
    }
    // the cartridge's screen while it goes up: the project's name and a bar (bios.rs, UPLOAD)
    const label = new Uint8Array(33);
    for (let i = 0; i < Math.min(32, name.length); i++) label[i] = name.charCodeAt(i) & 0x7F;
    await this.writeMem(UPLOAD + 12, label);
    await this.write32(UPLOAD + 4, bytes.length);
    await this.write32(UPLOAD + 8, 0);
    await this.write32(UPLOAD, UPLOAD_MAGIC);
    const CHUNK = 16384;
    try {
      for (let o = 0; o < bytes.length; o += CHUNK) {
        await this.writeMem(GAME_LOAD_ADDR + o, bytes.subarray(o, o + CHUNK));
        await this.write32(UPLOAD + 8, Math.min(o + CHUNK, bytes.length));
      }
    } catch (e) {
      await this.write32(UPLOAD, 0).catch(() => {});   // back to the menu
      throw e;
    }
    // the name it would have on the card: its romset (ROMS/<x>.ZIP) and samples (<x>.VSM)
    const st = new Uint8Array(16);
    for (let i = 0; i < Math.min(15, stem.length); i++) st[i] = stem.charCodeAt(i) & 0x7F;
    await this.writeMem(SWD_STEM, st);
    await this.write32(SWD_LAUNCH + 8, 0);
    await this.write32(SWD_LAUNCH + 4, image.length);
    await this.write32(SWD_LAUNCH, SWD_LAUNCH_MAGIC);
    this.running = true;
    let answer = 0;
    for (let i = 0; i < 80 && !answer; i++) {
      await new Promise((r) => setTimeout(r, 50));
      if (!this.running) break;   // already stopped at a breakpoint
      answer = await this.read32(SWD_LAUNCH + 8);
    }
    if (answer !== SWD_LAUNCH_OK) await this.write32(UPLOAD, 0).catch(() => {});
    if (answer === SWD_LAUNCH_BAD) throw new Error('the cartridge refused the image (not a VPy2 game, or no PSRAM)');
    if (answer !== SWD_LAUNCH_OK && this.running) {
      throw new Error('the cartridge menu did not answer: is the firmware with the SWD launch mailbox flashed, and is the menu on screen?');
    }
    this.launched = true;
    // breakpoints set while the image was going up
    await this.applyPatches(new Set(this.ideBreakpoints));
    this.startRtt();
  }

  /** Make the cartridge's BKPTs exactly `want` (within the game's code), in as few writes as it takes. */
  private async applyPatches(want: Set<number>): Promise<void> {
    const inCode = (a: number) => this.codeHalf(a) !== null;
    const target = new Set([...want].filter(inCode));
    if (this.t.patch) {
      await this.t.patch([...target].filter((a) => !this.patched.has(a)), [...this.patched].filter((a) => !target.has(a)));
      this.patched = target;
      return;
    }
    const changed = [...new Set([...target].filter((a) => !this.patched.has(a)).concat([...this.patched].filter((a) => !target.has(a))))].sort((a, b) => a - b);
    // neighbouring changes go in one write: the original code with the BKPTs that stay
    for (let i = 0; i < changed.length;) {
      let j = i;
      while (j + 1 < changed.length && changed[j + 1] - changed[j] <= 64) j++;
      const lo = changed[i], hi = changed[j] + 2;
      const bytes = new Uint8Array(hi - lo);
      for (let a = lo; a < hi; a += 2) {
        const h = target.has(a) ? (BKPT[0] | (BKPT[1] << 8)) : this.codeHalf(a)!;
        bytes[a - lo] = h & 0xFF; bytes[a - lo + 1] = h >> 8;
      }
      await this.writeMem(lo, bytes);
      i = j + 1;
    }
    this.patched = target;
  }

  /**
   * Run on from where it stopped: off a BKPT first (the original instruction, one step).
   * With `wait`, the next stop is returned to the caller instead of being announced.
   */
  private async leaveStop(wait: boolean): Promise<Promise<any> | null> {
    const pc = (this.regs[15] & ~1) >>> 0;
    if (this.patched.has(pc) && !this.t.patch) {   // the monitor steps off its own
      const h = this.codeHalf(pc)!;
      await this.writeMem(pc, new Uint8Array([h & 0xFF, h >> 8]));
      const stepped = this.waitStop((r) => r === 'step');
      await this.t.stepInstruction();
      await stepped;
      await this.writeMem(pc, new Uint8Array(BKPT));
    }
    const stop = wait ? this.waitStop((r) => r !== 'step') : null;
    if (this.pauseShown) { this.pauseShown = false; await this.write32(PAUSE_FLAG, 0); }
    this.running = true;
    await this.t.cont();
    return stop;
  }

  private async continueRun(): Promise<void> {
    await this.applyPatches(new Set(this.ideBreakpoints));
    useDebugStore.getState().setCurrentVpyLine(null);
    await this.leaveStop(false);
  }

  /** A statement step: to the next stop the step's rule accepts (see the file's comment). */
  private async stepRun(until: (pc: number, sp: number) => boolean, kind: 'over' | 'into' | 'out'): Promise<void> {
    this.stepping = true;
    try {
      await this.stepLoop(until, kind);
    } finally {
      this.stepping = false;
    }
  }

  private async stepLoop(until: (pc: number, sp: number) => boolean, kind: 'over' | 'into' | 'out'): Promise<void> {
    const sp0 = this.regs[13] >>> 0;
    let reason: ArmStopReason = 'step';
    for (let n = 0; n < 2000; n++) {
      const pc = (this.regs[15] & ~1) >>> 0, sp = this.regs[13] >>> 0;
      if (n > 0 && until(pc, sp)) break;
      if (n > 0 && this.ideBreakpoints.has(pc)) { reason = 'breakpoint'; break; }
      const stops = new Set(this.ideBreakpoints);
      // `out` has nothing to stop at until it is out: only the return address
      const plan = kind === 'out' && sp <= sp0 ? { stops: [], needReturn: true } : stepStops(kind, pc, (x) => this.codeHalf(x));
      for (const a of plan.stops) stops.add(a);
      if (plan.needReturn) {
        const ret = await this.returnAddress();
        if (ret !== null) stops.add(ret);
      }
      await this.applyPatches(stops);
      const ev = await (await this.leaveStop(true));
      if (ev?.abort) {   // Continue pressed meanwhile: the step's stops out, the game runs on
        await this.applyPatches(new Set(this.ideBreakpoints));
        return;
      }
      await this.fetchRegisters();
      if (ev?.body?.reason === 'pause') { reason = 'step'; break; }
    }
    await this.applyPatches(new Set(this.ideBreakpoints));
    await this.fetchMemory();
    this.announce(reason);
  }

  /** Where the function at pc returns to: frame 1 of the unwound stack. */
  private async returnAddress(): Promise<number | null> {
    await this.fetchStack();
    const frames = armCallStack();
    const a = frames[1]?.address;
    return a ? (parseInt(a, 16) & ~1) >>> 0 : null;
  }

  private async fetchRegisters(): Promise<void> {
    this.regs = await this.t.registers();
    this.pages.clear();
    this.stopGen++;   // a background read of the previous stop must not land in this one
  }

  /** Counts the stops: a background read belongs to the stop it was started at. */
  private stopGen = 0;

  private async fetchRange(lo: number, hi: number, gen = this.stopGen, chunk = 4096): Promise<void> {
    const win = [SRAM, PSRAM].find(([a, b]) => lo < b && hi > a);
    if (!win) return;
    lo = Math.max(lo, win[0]); hi = Math.min(hi, win[1]);
    lo = Math.floor(lo / PAGE) * PAGE;
    for (let a = lo; a < hi;) {
      if (this.pages.has(a / PAGE)) { a += PAGE; continue; }
      let end = a;
      while (end < hi && !this.pages.has(end / PAGE) && end - a < chunk) end += PAGE;
      const bytes = await this.readMem(a, end - a);
      if (gen !== this.stopGen || this.running) return;   // it ran on meanwhile: stale
      for (let p = a; p < end; p += PAGE) this.pages.set(p / PAGE, bytes.slice(p - a, p - a + PAGE));
      a = end;
    }
  }

  /** The stack above sp: what the unwinder reads. */
  private fetchStack(): Promise<void> {
    const sp = this.regs[13] >>> 0;
    return this.fetchRange(sp, sp + 2048);
  }

  /** What a stop needs before it is shown: the registers (fetched already) and the stack the
   *  call stack is unwound from. */
  private async fetchMemory(): Promise<void> {
    await this.fetchStack();
  }

  /**
   * The rest of what the editor may show, AFTER the stop is shown and outside the queue: the
   * VPy runtime RAM and the program's data, up to 64 KB (a C game's .bss in PSRAM is ~110 KB;
   * at ~20 KB/s that is seconds). Abandoned as soon as the program runs on, so it never slows
   * a step; until a page is in, a value on it reads as unavailable.
   */
  private async prefetchData(): Promise<void> {
    const gen = this.stopGen;
    const ranges: Array<[number, number]> = [[0x2007F000, 0x20080000]];
    let budget = 64 * 1024;
    for (const s of this.data) {
      const n = Math.min(s.end - s.start, budget);
      if (n <= 0) break;
      ranges.push([s.start, s.start + n]);
      budget -= n;
    }
    try {
      for (const [lo, hi] of ranges) {
        if (gen !== this.stopGen || this.running || this.closed) return;
        // 1 KB at a time: a step asked for meanwhile waits for one of these at most (~60 ms)
        await this.fetchRange(lo, hi, gen, 1024);
      }
    } catch { /* the probe went away, or the program ran on: nothing to show */ }
  }

  private async fetchStop(): Promise<void> {
    await this.fetchRegisters();
    await this.fetchMemory();
  }

  /** The pause sign is on the cartridge's screen. */
  private pauseShown = false;

  private announce(reason: ArmStopReason): void {
    this.stopped = reason;
    // the pause sign in the corner while the game waits for the debugger (our cartridge's
    // firmware draws it; on the UVMC2 the picture just stays)
    if (this.t.kind === 'swd') {
      this.pauseShown = true;
      void this.write32(PAUSE_FLAG, PAUSE_MAGIC).catch(() => {});
    }
    const pc = this.regs[15] >>> 0;
    for (const fn of this.listeners) fn(reason, pc);
    // the program's data, behind the stop: hovers then need no read of their own
    void this.prefetchData();
  }

  /** Leave the game running, every BKPT out, and the probe free. */
  async close(): Promise<void> {
    if (this.closed) return;
    try {
      // running or stopped, the code goes back to the original (end then lets it run)
      await this.serial(async () => {
        await this.applyPatches(new Set());
        if (this.t.kind === 'swd') {
          await this.write32(PAUSE_FLAG, 0);
          if (this.dbgPause) TIMER_DBGPAUSE.forEach((r, i) => void this.write32(r, this.dbgPause![i]));
        } else if (this.stopped) {
          await this.t.cont();   // held at a stop: let it go
        }
      });
    } catch (e) {
      console.warn('[hwDebug] could not take the breakpoints out:', e);
    }
    this.closed = true;
    if (this.rttTimer) clearInterval(this.rttTimer);
    for (const u of this.unsubs) u();
    await this.t.end();
  }

  attach(unsub: () => void): void { this.unsubs.push(unsub); }

  /** The probe is gone: whatever waits for a stop gets none. */
  abort(): void {
    const w = this.stopWaiter;
    this.stopWaiter = null;
    w?.resolve(null);
  }
}

let current: CartridgeSession | null = null;

export function cartridgeDebugActive(): boolean {
  return !!current && !current.closed;
}

/** Report a session's progress where the build output goes (BuildOutputPanel). */
export function say(text: string, error = false): void {
  (error ? console.warn : console.log)('[hwDebug]', text);
  window.dispatchEvent(new CustomEvent('hwdebug:status', { detail: { text, error } }));
}

/** The debug toolbar and keys (debugStore posts them) while a session is on. */
function onDebugMessage(e: MessageEvent): void {
  if (e.source !== window || !current || current.closed) return;
  const type = e.data?.type;
  if (type === 'debug-step-over' || type === 'debug-step-into' || type === 'debug-step-out') {
    armStep(type === 'debug-step-over' ? 'over' : type === 'debug-step-into' ? 'into' : 'out');
  } else if (typeof type === 'string') {
    cartridgeRunControl(type);
  }
}

/**
 * Debug `binPath` (a 'VPy2' RAM image, the SD build) on the cartridge, with `elfPath`'s
 * line table. Resolves once the game is running there (or stopped at a breakpoint).
 */
export async function startCartridgeDebug(binPath: string, elfPath: string): Promise<void> {
  const hw = api();
  const files = (window as any).files;
  if (!hw || !files?.readFileBin) throw new Error('on-cartridge debugging needs the desktop IDE');
  await stopCartridgeDebug();
  const read = async (p: string) => {
    const r = await files.readFileBin(p);
    if (!r || r.error || !r.base64) throw new Error(`cannot read ${p}: ${r?.error ?? 'missing'}`);
    return unb64(r.base64);
  };
  const [image, elf] = await Promise.all([read(binPath), read(elfPath)]);
  say('resetting the cartridge and attaching to core 1…');
  const started = await hw.start({ elfPath });
  if ('error' in started) throw new Error(started.error);
  const s = new CartridgeSession(elf, new SwdTransport());
  current = s;
  s.attach(hw.onEvent((ev) => { if (current === s) s.handleEvent(ev); }));
  s.attach(hw.onEnded((why) => {
    if (current !== s) return;
    current = null;
    s.abort();
    void s.close();   // only unsubscribes: the probe is gone
    setHardwareArmSystem(null, null);
    useDebugStore.getState().setState('stopped');
    if (why !== 'ended') say(`session ended: ${why}`, true);
  }));
  window.addEventListener('message', onDebugMessage);
  s.attach(() => window.removeEventListener('message', onDebugMessage));
  setHardwareArmSystem(s, elf);   // the editor's breakpoints land in s.ideBreakpoints
  useDebugStore.getState().setState('running');
  say(`uploading ${image.length} bytes and launching…`);
  const project = useProjectStore.getState().vpyProject?.config?.project?.name
    ?? (binPath.split(/[\\/]/).pop() ?? 'GAME').replace(/(_sd)?\.bin$/i, '');
  try {
    // the name the IDE copies it to the card with (SNOWBROS_sd.bin -> SNOWBROS.BIN)
    const stem = (binPath.split(/[\\/]/).pop() ?? '').replace(/(_sd)?\.bin$/i, '').toUpperCase();
    await s.launch(image, project.replace(/_/g, ' '), stem);
  } catch (e) {
    await stopCartridgeDebug();
    throw e;
  }
  say('the game is running on the cartridge');
}

/**
 * Run a build's RAM image on the cartridge and debug it there (the "SWD debug" build mode
 * and Debug on Cartridge). Its ELF is beside it (`x_sd.elf`, a VPy build) or named without
 * the `_sd` (`build_rp2350/x.elf`, a C project's). Failures are reported, not thrown.
 */
export async function runOnCartridge(binPath: string): Promise<void> {
  const files = (window as any).files;
  const candidates = [binPath.replace(/\.bin$/i, '.elf'), binPath.replace(/_sd\.bin$/i, '.elf')];
  let elfPath: string | null = null;
  for (const c of candidates) {
    const info = await files?.getFileInfo?.(c).catch(() => null);
    if (info?.ok) { elfPath = c; break; }
  }
  if (!elfPath) { say(`no ELF beside ${binPath} (looked for ${[...new Set(candidates)].join(', ')})`, true); return; }
  try {
    await startCartridgeDebug(binPath, elfPath);
  } catch (e: any) {
    say(String(e?.message ?? e), true);
  }
}

/**
 * Debug the game running on the UVMC2 (Build > Debug on Cartridge, target uvm2: an upload
 * started it), through its debug monitor, with `elfPath`'s line table. Breakpoints work from
 * the game's first frame on: the monitor starts there, and a BKPT met before it would fault.
 */
export async function startUvmc2Debug(elfPath: string): Promise<void> {
  const mon = monitorApi();
  const files = (window as any).files;
  if (!mon || !files?.readFileBin) throw new Error('on-cartridge debugging needs the desktop IDE');
  await stopCartridgeDebug();
  const r = await files.readFileBin(elfPath);
  if (!r || r.error || !r.base64) throw new Error(`cannot read ${elfPath}: ${r?.error ?? 'missing'}`);
  const elf = unb64(r.base64);
  say('attaching to the game\'s monitor on USB…');
  const started = await mon.start();
  if ('error' in started) throw new Error(started.error);
  const s = new CartridgeSession(elf, new MonitorTransport());
  current = s;
  const why: Record<string, string> = { bp: 'breakpoint', bkpt: 'breakpoint', step: 'step', pause: 'pause' };
  s.attach(mon.onEvent((ev) => { if (current === s) s.handleEvent({ event: 'stopped', body: { reason: why[ev.reason] ?? 'pause' } }); }));
  let rttLine = '';
  s.attach(mon.onText((t) => {
    rttLine += t;
    const lines = rttLine.split('\n');
    rttLine = lines.pop() ?? '';
    for (const l of lines) window.dispatchEvent(new CustomEvent('hwdebug:status', { detail: { text: l.replace(/\r$/, ''), rtt: true } }));
  }));
  s.attach(mon.onEnded((why) => {
    if (current !== s) return;
    current = null;
    s.abort();
    void s.close();
    setHardwareArmSystem(null, null);
    useDebugStore.getState().setState('stopped');
    if (why !== 'ended') say(`session ended: ${why}`, true);
  }));
  window.addEventListener('message', onDebugMessage);
  s.attach(() => window.removeEventListener('message', onDebugMessage));
  setHardwareArmSystem(s, elf);
  await s.attachRunning();
  useDebugStore.getState().setState('running');
  say(`debugging on the cartridge (${started.version})`);
}

/** Debug the game an upload just started on the UVMC2 (`um2Path`), with its ELF: beside the
 *  .um2 (a VPy build) or in the pico-sdk build under it (a C project's build_uvm2/pico/).
 *  Failures are reported (and returned), not thrown. */
export async function debugOnUvmc2(um2Path: string): Promise<string | null> {
  const files = (window as any).files;
  const dir = um2Path.replace(/[\\/][^\\/]*$/, ''), stem = (um2Path.split(/[\\/]/).pop() ?? '').replace(/\.um2$/i, '');
  const candidates = [`${dir}/${stem}.elf`, `${dir}/pico/${stem}.elf`, `${dir}/uvm2/${stem}.elf`];
  let elfPath: string | null = null;
  for (const c of candidates) {
    const info = await files?.getFileInfo?.(c).catch(() => null);
    if (info?.ok) { elfPath = c; break; }
  }
  if (!elfPath) {
    const m = `no ELF beside ${um2Path} (looked for ${candidates.join(', ')})`;
    say(m, true);
    return m;
  }
  try {
    await startUvmc2Debug(elfPath);
    return null;
  } catch (e: any) {
    say(String(e?.message ?? e), true);
    return String(e?.message ?? e);
  }
}

export async function stopCartridgeDebug(): Promise<void> {
  const s = current;
  current = null;
  if (!s) return;
  setHardwareArmSystem(null, null);
  await s.close();
  const st = useDebugStore.getState();
  st.setCurrentVpyLine(null);
  st.updateCallStack([]);
  st.setState('stopped');
}

/** The debug toolbar while a cartridge session is on (EmulatorPanel routes it here). */
export function cartridgeRunControl(type: string): void {
  const s = current;
  if (!s) return;
  switch (type) {
    case 'debug-continue': s.resume(false); useDebugStore.getState().setState('running'); break;
    case 'debug-pause': s.pause(); break;
    case 'debug-stop': void stopCartridgeDebug(); break;
    default: break;   // steps go through armStep (armSourceDebug), which calls s.resume
  }
}
