/**
 * Uploading to the UVMC2 (Ralf's multicart) over USB. Two programs answer on the cartridge's
 * USB with the same protocol and ids (VID 0x2E8A PID 0x10DB), both from uvmc2-sdk:
 *   - the debug monitor, in the PSRAM of a game built with UVM2_USB_MONITOR (uvm2-sdk/monitor)
 *   - the SD bridge, a RAM-only program for when the cartridge sits in its menu
 *     (uvm2-sdk/sdbridge): the menu's firmware has the pico-sdk's USB "Reset" interface, so
 *     picotool sends the chip to the bootrom's BOOTSEL mode and runs the bridge from SRAM.
 *     The flash, the multicart's own firmware, is never written.
 * Both are bundled in resources/uvmc2 (sdbridge.elf, MONITOR.BIN).
 *
 * Their protocol is text lines, answers ending in CR LF:
 *   v                  -> "UVMC2-MON <n>" / "UVMC2-BRIDGE <n>"
 *   u <size> <path>    -> "OK", then <size> raw bytes, then "DONE <size> <crc32 hex>"
 *   x                  -> "OK", then the chip goes to BOOTSEL; the game's ELF is loaded into SRAM
 *                         and run (picotool load -x): the upload ends with the game running
 *   b                  -> "OK"; the monitor resets the chip into the multicart's firmware, the
 *                         bridge shows DONE and does that when the console's RESET is pressed
 * The `u` line ends in LF alone: an older monitor took the LF after a CR for the file's first
 * byte.
 *
 * THE PORT IS OPENED HERE, as a plain file (macOS /dev/cu.*, Linux /dev/ttyACM*) set to raw
 * with stty. Chromium's Web Serial was tried first and refused to open the very port Python
 * opened at once ("Failed to open serial port", no detail), and a native serial module would
 * need rebuilding for Electron. Windows is not done yet.
 */
import { app, ipcMain } from 'electron';
import { spawn, spawnSync } from 'child_process';
import { closeSync, constants, existsSync, openSync, readFileSync, readSync, readdirSync, writeSync } from 'fs';
import { basename, dirname, join } from 'path';

const VID = 0x2e8a;
const PID = 0x10db;

function resourceDir(): string {
  return join(app.isPackaged ? process.resourcesPath : join(__dirname, '..', '..', 'resources'), 'uvmc2');
}

function picotoolPath(): string {
  for (const p of ['/opt/homebrew/bin/picotool', '/usr/local/bin/picotool']) if (existsSync(p)) return p;
  return 'picotool';
}

/**
 * Run picotool. A command that reboots the chip is DONE when picotool says so: on macOS its
 * libusb can deadlock in libusb_exit while the device it just reset detaches (seen: `reboot -u`
 * hanging for good after the chip was already in BOOTSEL). So its own words end it, and it is
 * killed; anything else gets 20 s.
 */
function picotool(args: string[]): Promise<{ code: number; out: string }> {
  return new Promise((resolve) => {
    let out = '';
    let settled = false;
    const child = spawn(picotoolPath(), args, { stdio: ['ignore', 'pipe', 'pipe'] });
    const finish = (code: number) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (child.exitCode === null) { try { child.kill('SIGKILL'); } catch { /* gone */ } }
      resolve({ code, out });
    };
    const timer = setTimeout(() => finish(-2), 20000);
    const take = (d: Buffer) => {
      out += d.toString();
      if (/asked to reboot|rebooted to start/i.test(out)) setTimeout(() => finish(0), 200);
    };
    child.stdout?.on('data', take);
    child.stderr?.on('data', take);
    child.on('error', (e) => { out += e.message; finish(-1); });
    child.on('close', (code) => finish(code ?? -2));
  });
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** The multicart's menu (its firmware shows up as the pico-sdk's "Pico", PID 0x0009) to
 *  BOOTSEL, then the SD bridge into SRAM and running. Only that device is asked: another
 *  Pico-family board on the same USB (a Debugprobe) is left alone. */
async function startBridge(): Promise<string | null> {
  const elf = join(resourceDir(), 'sdbridge.elf');
  if (!existsSync(elf)) return `the SD bridge is missing: ${elf}`;
  const reboot = await picotool(['reboot', '-u', '-f', '--vid', '0x2e8a', '--pid', '0x0009']);
  if (reboot.code === -1) return 'picotool not found: install it (brew install picotool)';
  // A failed reboot is not the end: the chip may be in BOOTSEL already (an attempt cut short).
  // The bootrom enumerates a moment after the reset.
  let last = '';
  for (let i = 0; i < (reboot.code === 0 ? 20 : 2); i++) {
    await sleep(300);
    const load = await picotool(['load', '-x', elf, '--vid', '0x2e8a', '--pid', '0x000f']);
    if (load.code === 0) return null;
    last = load.out.trim().split('\n').pop() ?? '';
  }
  if (reboot.code !== 0) {
    return `the cartridge did not answer on USB: put it in the multicart's menu with its USB plugged in (${reboot.out.trim().split('\n').pop()})`;
  }
  return `could not load the SD bridge in BOOTSEL: ${last}`;
}

/** The serial devices of the monitor / bridge (VID 0x2E8A PID 0x10DB). */
function monitorPorts(): string[] {
  const out: string[] = [];
  if (process.platform === 'darwin') {
    // The USB tree, depth first: a device's ids come before its serial node.
    const r = spawnSync('ioreg', ['-l', '-w0', '-r', '-c', 'IOUSBHostDevice'], { encoding: 'utf8', maxBuffer: 64 << 20 });
    let vid = 0, pid = 0;
    for (const line of String(r.stdout || '').split('\n')) {
      let m: RegExpExecArray | null;
      if ((m = /"idVendor" = (\d+)/.exec(line))) vid = +m[1];
      else if ((m = /"idProduct" = (\d+)/.exec(line))) pid = +m[1];
      else if ((m = /"IOCalloutDevice" = "([^"]+)"/.exec(line)) && vid === VID && pid === PID) out.push(m[1]);
    }
  } else if (process.platform === 'linux') {
    let ttys: string[] = [];
    try { ttys = readdirSync('/sys/class/tty').filter((n) => n.startsWith('ttyACM')); } catch { /* none */ }
    for (const n of ttys) {
      try {
        const dev = `/sys/class/tty/${n}/device/..`;
        const v = parseInt(readFileSync(`${dev}/idVendor`, 'utf8'), 16);
        const p = parseInt(readFileSync(`${dev}/idProduct`, 'utf8'), 16);
        if (v === VID && p === PID) out.push(`/dev/${n}`);
      } catch { /* not a USB one */ }
    }
  }
  return out;
}

class Link {
  private buf = '';
  private constructor(private fd: number) {}

  /** Opened non-blocking, then raw: no echo, no line editing, no CR/LF rewriting both ways
   *  (an upload is binary). The settings hold while the port stays open. */
  static open(path: string): Link {
    const fd = openSync(path, constants.O_RDWR | constants.O_NOCTTY | constants.O_NONBLOCK);
    const r = spawnSync('stty', [process.platform === 'darwin' ? '-f' : '-F', path, 'raw', '-echo', '115200']);
    if (r.status !== 0) { closeSync(fd); throw new Error(`stty failed on ${path}: ${String(r.stderr || '').trim()}`); }
    return new Link(fd);
  }

  close(): void { try { closeSync(this.fd); } catch { /* gone (a reset drops the port) */ } }

  async write(data: Buffer | string): Promise<void> {
    const b = typeof data === 'string' ? Buffer.from(data) : data;
    let off = 0, idle = Date.now();
    while (off < b.length) {
      try {
        const n = writeSync(this.fd, b, off, Math.min(4096, b.length - off));
        off += n;
        if (n) idle = Date.now();
      } catch (e: any) {
        if (e?.code !== 'EAGAIN') throw e;
        if (Date.now() - idle > 30000) throw new Error('the cartridge stopped taking data');
        await sleep(1);
      }
    }
  }

  /** The next non-empty line, or null after `ms`. */
  async line(ms: number): Promise<string | null> {
    const end = Date.now() + ms;
    const tmp = Buffer.alloc(4096);
    for (;;) {
      const nl = this.buf.indexOf('\n');
      if (nl >= 0) {
        const l = this.buf.slice(0, nl).trim();
        this.buf = this.buf.slice(nl + 1);
        if (l) return l;
        continue;
      }
      if (Date.now() > end) return null;
      try {
        const n = readSync(this.fd, tmp, 0, tmp.length, null);
        if (n > 0) { this.buf += tmp.subarray(0, n).toString('latin1'); continue; }
      } catch (e: any) {
        if (e?.code !== 'EAGAIN') throw e;
      }
      await sleep(5);
    }
  }
}

/** The ELF the .um2 was made from: beside it (a VPy build: build/<name>_uvm2.elf), or in
 *  the pico-sdk build under it (a C project: build_uvm2/pico/<name>.elf). */
function gameElf(um2Path: string): string | null {
  const dir = dirname(um2Path), stem = basename(um2Path).replace(/\.um2$/i, '');
  for (const p of [join(dir, `${stem}.elf`), join(dir, 'pico', `${stem}.elf`), join(dir, 'uvm2', `${stem}.elf`)]) {
    if (existsSync(p)) return p;
  }
  return null;
}

/** CRC-32 (IEEE), as the monitor computes it over what it wrote to the card. */
function crc32(data: Buffer): number {
  let crc = 0xffffffff;
  for (let i = 0; i < data.length; i++) {
    crc ^= data[i];
    for (let k = 0; k < 8; k++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
}

/** The first of the monitor's / bridge's ports that opens and answers `v`. A port that has
 *  just appeared (the bridge, right after BOOTSEL) may refuse for a moment: `tries` rounds. */
async function connect(tries: number): Promise<{ link: Link; ver: string } | { error: string }> {
  let last = 'no port';
  for (let i = 0; i < tries; i++) {
    for (const path of monitorPorts()) {
      let link: Link | null = null;
      try {
        link = Link.open(path);
        await link.write('v\n');
        const ver = await link.line(2000);
        if (ver?.startsWith('UVMC2-')) return { link, ver };
        last = `${path} answered ${ver ?? 'nothing'}`;
      } catch (e: any) {
        last = `${path}: ${e?.message ?? e}`;
      }
      link?.close();
    }
    if (i + 1 < tries) await sleep(250);
  }
  return { error: last };
}

async function sendFile(link: Link, name: string, data: Buffer, say: (t: string) => void): Promise<string | null> {
  await link.write(`u ${data.length} ${name}\n`);
  const open = await link.line(5000);
  if (open !== 'OK') return `the card did not open ${name}: ${open ?? 'no answer'}`;
  const t0 = Date.now();
  const STEP = 65536;
  for (let off = 0; off < data.length; off += STEP) {
    await link.write(data.subarray(off, Math.min(off + STEP, data.length)));
    if (off + STEP < data.length) say(`  ${Math.round(((off + STEP) / data.length) * 100)}%`);
  }
  const done = await link.line(60000);
  const want = `DONE ${data.length} ${crc32(data).toString(16).padStart(8, '0')}`;
  if (done !== want) return `upload of ${name} failed: ${done ?? 'no answer'} (expected ${want})`;
  const secs = Math.max((Date.now() - t0) / 1000, 0.001);
  say(`  ${name}: ${data.length} bytes on the card, CRC checked (${Math.round(data.length / 1024 / secs)} KB/s)`);
  return null;
}

/**
 * Put `um2Path` on the cartridge's SD card, and the debug monitor (MONITOR.BIN) with it so a
 * game built with the monitor finds the current one; then run the game on the cartridge.
 * Through the monitor of a game running there or, with none, the SD bridge started from the
 * menu.
 */
async function upload(um2Path: string, say: (t: string) => void): Promise<{ ok: boolean; message: string }> {
  if (process.platform === 'win32') return { ok: false, message: 'Upload to Cartridge (UVMC2) is not available on Windows yet' };
  let data: Buffer;
  try { data = readFileSync(um2Path); } catch (e: any) { return { ok: false, message: `cannot read ${um2Path}: ${e?.message ?? e}` }; }
  const name = basename(um2Path);

  let c = await connect(1);
  if ('error' in c) {
    say('no game with the monitor on USB: starting the SD bridge from the multicart menu (BOOTSEL)');
    const err = await startBridge();
    if (err) return { ok: false, message: err };
    c = await connect(32);   // ~8 s for the bridge to enumerate and its port to open
    if ('error' in c) return { ok: false, message: `the SD bridge started but did not answer on USB (${c.error})` };
  }
  const { link, ver } = c;
  try {
    say(`${ver}: uploading ${name} (${data.length} bytes)`);
    let err = await sendFile(link, name, data, say);
    if (err) return { ok: false, message: err };
    const mon = join(resourceDir(), 'MONITOR.BIN');
    if (existsSync(mon)) {
      err = await sendFile(link, 'MONITOR.BIN', readFileSync(mon), say);
      if (err) return { ok: false, message: err };
    }
    // RUN IT: back to BOOTSEL (`x`), and the game's ELF into SRAM and started, as the bridge
    // was (the same image the multicart would load off the card, so it runs the same).
    const elf = gameElf(um2Path);
    if (elf) {
      await link.write('x\n');
      if ((await link.line(2000)) === 'OK') {
        link.close();
        say(`starting ${basename(elf)} on the cartridge`);
        for (let i = 0; i < 20; i++) {
          await sleep(300);
          const load = await picotool(['load', '-x', elf, '--vid', '0x2e8a', '--pid', '0x000f']);
          if (load.code === 0) return { ok: true, message: `${name} is on the card and running on the cartridge.` };
        }
        return { ok: false, message: `${name} is on the card, but it could not be started (the cartridge is in BOOTSEL: power it off and on, or RESET for the menu)` };
      }
    }
    // An older monitor has no `x`, or there is no ELF: the multicart's menu, by hand. The
    // monitor resets the chip, the bridge shows DONE and waits for the button; either way the
    // 6809 needs the console's RESET (the cartridge cannot reset it).
    await link.write('b\n');
    await link.line(2000);
    return { ok: true, message: `${name} is on the card. Press RESET on the console for the multicart's menu, then pick ${name}.` };
  } catch (e: any) {
    return { ok: false, message: `serial error: ${e?.message ?? e}` };
  } finally {
    link.close();
  }
}

let busy = false;

export function registerUvmc2Serial(): void {
  ipcMain.handle('uvmc2:upload', async (e, um2Path: string) => {
    if (busy) return { ok: false, message: 'an upload to the cartridge is already running' };
    busy = true;
    try {
      return await upload(um2Path, (t) => { if (!e.sender.isDestroyed()) e.sender.send('uvmc2:progress', t); });
    } finally {
      busy = false;
    }
  });
}
