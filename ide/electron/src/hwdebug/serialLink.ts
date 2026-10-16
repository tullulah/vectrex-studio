// The UVMC2 monitor's / SD bridge's serial port (VID 0x2E8A PID 0x10DB): finding it and
// reading and writing it without blocking the main process, on macOS, Linux and Windows. No
// electron import: the Windows check (scripts/win-build-smoke.js) loads it under plain Node.
// The protocol on top is uvmc2Serial.ts's.

import { spawn, spawnSync } from 'child_process';
import { closeSync, constants, openSync, readFileSync, readSync, readdirSync, writeSync } from 'fs';

const VID = 0x2e8a;
const PID = 0x10db;

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** The serial devices of the monitor / bridge (VID 0x2E8A PID 0x10DB), its own port first. */
export async function monitorPorts(): Promise<string[]> {
  const out: string[] = [];
  if (process.platform === 'win32') return windowsMonitorPorts();
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
  // The monitor has two ports: its own (interface 0) and gdb's (interface 2). Interface order
  // is name order on both systems (macOS ...1 / ...3, Linux ttyACM<n>): its own first, so the
  // `v` that finds it does not wait out gdb's port first.
  return out.sort();
}

/** Windows: the COM ports of the monitor / bridge, its own (interface 0) first. */
async function windowsMonitorPorts(): Promise<string[]> {
  const ps = `Get-CimInstance Win32_PnPEntity -Filter "PNPDeviceID LIKE 'USB\\\\VID_2E8A&PID_10DB%'" | ` +
    `ForEach-Object { $_.PNPDeviceID + '|' + $_.Name }`;
  const r = await new Promise<string>((resolve) => {
    let out = '';
    const child = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', ps], { stdio: ['ignore', 'pipe', 'ignore'], windowsHide: true });
    child.stdout?.on('data', (c: Buffer) => { out += c.toString(); });
    child.on('error', () => resolve(''));
    child.on('close', () => resolve(out));
  });
  const ports: Array<{ mi: string; com: string }> = [];
  for (const line of r.split(/\r?\n/)) {
    const com = /\((COM\d+)\)/.exec(line)?.[1];
    if (com) ports.push({ mi: /MI_(\d+)/i.exec(line)?.[1] ?? '', com });
  }
  return ports.sort((a, b) => a.mi.localeCompare(b.mi)).map((p) => p.com);
}

/** What a Link reads and writes through: the port as a file (macOS, Linux) or the PowerShell
 *  child that holds it (Windows). */
export interface Port {
  /** Bytes that arrived, '' for none yet; null once the port is gone. */
  take(): string | null;
  write(b: Buffer): Promise<void>;
  /** A last line on the way out (no waiting). */
  writeNow(s: string): void;
  close(): void;
}

class FilePort implements Port {
  private readonly tmp = Buffer.alloc(4096);
  constructor(private readonly fd: number) {}

  /** Opened non-blocking, then raw: no echo, no line editing, no CR/LF rewriting both ways
   *  (an upload is binary). The settings hold while the port stays open. */
  static open(path: string): FilePort {
    const fd = openSync(path, constants.O_RDWR | constants.O_NOCTTY | constants.O_NONBLOCK);
    const r = spawnSync('stty', [process.platform === 'darwin' ? '-f' : '-F', path, 'raw', '-echo', '115200']);
    if (r.status !== 0) { closeSync(fd); throw new Error(`stty failed on ${path}: ${String(r.stderr || '').trim()}`); }
    return new FilePort(fd);
  }

  take(): string | null {
    let got = '';
    for (;;) {
      let n = 0;
      try { n = readSync(this.fd, this.tmp, 0, this.tmp.length, null); } catch (e: any) {
        if (e?.code === 'EAGAIN') return got;
        return got || null;
      }
      if (n <= 0) return got;
      got += this.tmp.subarray(0, n).toString('latin1');
    }
  }

  async write(b: Buffer): Promise<void> {
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

  writeNow(s: string): void { try { writeSync(this.fd, s); } catch { /* gone */ } }
  close(): void { try { closeSync(this.fd); } catch { /* gone (a reset drops the port) */ } }
}

/** The PowerShell side of a WinPort: open the port with DTR up (the CDC side counts the host as
 *  connected by it), say OPEN on stderr, then copy port -> stdout in the background and
 *  stdin -> port until stdin closes. */
const WIN_PORT_PS = (com: string) => [
  "$ErrorActionPreference = 'Stop'",
  `$p = New-Object System.IO.Ports.SerialPort '${com}', 115200`,
  '$p.DtrEnable = $true; $p.RtsEnable = $true; $p.ReadTimeout = -1; $p.WriteTimeout = 30000',
  '$p.Open()',
  '$out = [Console]::OpenStandardOutput(); $in = [Console]::OpenStandardInput()',
  "[Console]::Error.WriteLine('OPEN')",
  '$null = $p.BaseStream.CopyToAsync($out)',
  'try { $in.CopyTo($p.BaseStream) } finally { $p.Close() }',
].join('\n');

class WinPort implements Port {
  private got = '';
  private gone = false;
  private constructor(private readonly child: ReturnType<typeof spawn>) {
    child.stdout?.on('data', (c: Buffer) => { this.got += c.toString('latin1'); });
    child.on('close', () => { this.gone = true; });
    child.stdin?.on('error', () => { this.gone = true; });
  }

  static open(com: string): Promise<WinPort> {
    const encoded = Buffer.from(WIN_PORT_PS(com), 'utf16le').toString('base64');
    const child = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
      { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
    return new Promise((resolve, reject) => {
      let err = '';
      const timer = setTimeout(() => { child.kill(); reject(new Error(`${com} did not open`)); }, 10000);
      child.stderr?.on('data', (c: Buffer) => {
        err += c.toString();
        if (/^OPEN\b/m.test(err)) { clearTimeout(timer); resolve(new WinPort(child)); }
      });
      child.on('error', (e) => { clearTimeout(timer); reject(e); });
      child.on('close', () => {
        clearTimeout(timer);
        const why = /Exception[^:]*: *"?([^"\r\n]+)/.exec(err)?.[1] ?? err.trim().split(/\r?\n/)[0] ?? 'closed';
        reject(new Error(`${com}: ${why}`));
      });
    });
  }

  take(): string | null {
    const g = this.got;
    this.got = '';
    return g || (this.gone ? null : '');
  }

  write(b: Buffer): Promise<void> {
    if (this.gone) return Promise.reject(new Error('the cartridge went off USB'));
    return new Promise((resolve, reject) => {
      const ok = this.child.stdin!.write(b, (e) => (e ? reject(e) : undefined));
      if (ok) resolve(); else this.child.stdin!.once('drain', () => resolve());
    });
  }

  writeNow(s: string): void { try { this.child.stdin?.write(s); } catch { /* gone */ } }
  close(): void { try { this.child.stdin?.end(); } catch { /* gone */ } setTimeout(() => { try { this.child.kill(); } catch { /* gone */ } }, 500); }
}

export class Link {
  private buf = '';
  private constructor(readonly port: Port) {}

  static async open(path: string): Promise<Link> {
    return new Link(process.platform === 'win32' ? await WinPort.open(path) : FilePort.open(path));
  }

  close(): void { this.port.close(); }

  write(data: Buffer | string): Promise<void> {
    return this.port.write(typeof data === 'string' ? Buffer.from(data) : data);
  }

  /** The next non-empty line, or null after `ms`. */
  async line(ms: number): Promise<string | null> {
    const end = Date.now() + ms;
    for (;;) {
      const nl = this.buf.indexOf('\n');
      if (nl >= 0) {
        const l = this.buf.slice(0, nl).trim();
        this.buf = this.buf.slice(nl + 1);
        if (l && !l.startsWith('!')) return l;   // '!' lines are the monitor's events (debugger, text)
        continue;
      }
      if (Date.now() > end) return null;
      const got = this.port.take();
      if (got === null) throw new Error('the cartridge went off USB');
      if (got) { this.buf += got; continue; }
      await sleep(5);
    }
  }
}
