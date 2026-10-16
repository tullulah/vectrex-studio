/**
 * On-cartridge debugging: a probe-rs DAP server driving the RP2350 cartridge over SWD.
 *
 * The renderer (frontend/src/debug/hwDebug.ts) runs the debugger; this side only owns the
 * processes and the socket: it resets the cartridge, starts `probe-rs dap-server`, attaches
 * it to CORE 1 alone and relays DAP requests and events.
 *
 * Why core 1 alone: on this cartridge core 1 runs the program (the menu, then the game) and
 * core 0 drives the Vectrex bus and redraws the last command list. Halting core 0 freezes the
 * beam — with the beam lit that is a spot burning one point of the tube. A paused game keeps
 * its last picture on screen because core 0 goes on.
 *
 * Why DAP and not `probe-rs gdb`: the gdb server halts the cores it attaches to, and has no
 * way to pick one. And why not `probe-rs download` to load the game: it runs its flash
 * algorithm in the SRAM the firmware executes from, and the firmware locks up.
 */
import { spawn, type ChildProcess } from 'child_process';
import { existsSync } from 'fs';
import * as net from 'net';
import { join } from 'path';
import os from 'os';
import { app, ipcMain, type BrowserWindow } from 'electron';

const CHIP = 'RP235x';
const SPEED = '1000';   // kHz: faster SWD drops transfers on this board (see flashRp2350)

function probeRsPath(): string {
  const cargo = join(os.homedir(), '.cargo', 'bin', 'probe-rs');
  return existsSync(cargo) ? cargo : 'probe-rs';
}

function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.once('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const port = (srv.address() as net.AddressInfo).port;
      srv.close(() => resolve(port));
    });
  });
}

/** Run a probe-rs command to the end (the DAP server must not hold the probe meanwhile). */
function probeRs(args: string[]): Promise<{ code: number; out: string }> {
  return new Promise((resolve) => {
    let out = '';
    let child: ChildProcess;
    try {
      child = spawn(probeRsPath(), args);
    } catch (e: any) {
      resolve({ code: -1, out: String(e?.message ?? e) });
      return;
    }
    child.stdout?.on('data', (d) => { out += d.toString(); });
    child.stderr?.on('data', (d) => { out += d.toString(); });
    child.on('error', (e) => resolve({ code: -1, out: out + e.message }));
    child.on('close', (code) => resolve({ code: code ?? -1, out }));
  });
}

class DapSession {
  private server: ChildProcess | null = null;
  private sock: net.Socket | null = null;
  private seq = 1;
  private buf = Buffer.alloc(0);
  private pending = new Map<number, (m: any) => void>();
  private ended = false;

  constructor(private readonly onEvent: (ev: any) => void, private readonly onEnd: (why: string) => void) {}

  async start(): Promise<void> {
    const port = await freePort();
    const server = spawn(probeRsPath(), ['dap-server', '--port', String(port)]);
    this.server = server;
    servers.add(server);
    server.on('exit', () => servers.delete(server));
    let log = '';
    server.stdout?.on('data', (d) => { log += d.toString(); });
    server.stderr?.on('data', (d) => { log += d.toString(); });
    server.on('close', (code) => this.end(`probe-rs dap-server exited (${code})${log ? ': ' + log.trim().split('\n').pop() : ''}`));
    // It listens a moment after it starts: retry the connection for up to 5 s.
    const t0 = Date.now();
    for (;;) {
      try {
        this.sock = await new Promise<net.Socket>((resolve, reject) => {
          const s = net.connect(port, '127.0.0.1', () => resolve(s));
          s.once('error', reject);
        });
        break;
      } catch {
        if (this.ended || Date.now() - t0 > 5000) throw new Error('could not reach probe-rs dap-server' + (log ? ': ' + log.trim() : ''));
        await new Promise((r) => setTimeout(r, 150));
      }
    }
    this.sock.on('data', (d) => this.receive(d));
    this.sock.on('close', () => this.end('connection to probe-rs closed'));
    this.sock.on('error', () => { /* 'close' follows */ });
  }

  private receive(d: Buffer): void {
    this.buf = Buffer.concat([this.buf, d]);
    for (;;) {
      const h = this.buf.indexOf('\r\n\r\n');
      if (h < 0) return;
      const m = /Content-Length:\s*(\d+)/i.exec(this.buf.subarray(0, h).toString());
      if (!m) { this.buf = this.buf.subarray(h + 4); continue; }
      const len = +m[1];
      if (this.buf.length < h + 4 + len) return;
      const msg = JSON.parse(this.buf.subarray(h + 4, h + 4 + len).toString());
      this.buf = this.buf.subarray(h + 4 + len);
      if (msg.type === 'response') {
        const r = this.pending.get(msg.request_seq);
        this.pending.delete(msg.request_seq);
        r?.(msg);
      } else if (msg.type === 'event') {
        this.onEvent(msg);
      }
    }
  }

  request(command: string, args: unknown): Promise<any> {
    if (!this.sock || this.ended) return Promise.resolve({ success: false, message: 'no session', command });
    return new Promise((resolve) => {
      const seq = this.seq++;
      this.pending.set(seq, resolve);
      const body = JSON.stringify({ seq, type: 'request', command, arguments: args });
      this.sock!.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
    });
  }

  end(why: string): void {
    if (this.ended) return;
    this.ended = true;
    for (const r of this.pending.values()) r({ success: false, message: why });
    this.pending.clear();
    try { this.sock?.destroy(); } catch { /* gone */ }
    // probe-rs dap-server lets the probe go at the disconnect but outlives a SIGTERM: one
    // left behind per session piled up. SIGKILL if it is still there half a second later.
    const server = this.server;
    try { server?.kill(); } catch { /* gone */ }
    if (server) setTimeout(() => { if (server.exitCode === null && server.signalCode === null) { try { server.kill('SIGKILL'); } catch { /* gone */ } } }, 500);
    this.onEnd(why);
  }

  get alive(): boolean { return !this.ended; }
}

let session: DapSession | null = null;

/** Every DAP server this IDE started and has not seen exit: killed when the IDE goes, so an
 *  orphan never keeps the probe (Electron does not end its children). */
const servers = new Set<ChildProcess>();
process.on('exit', () => { for (const s of servers) { try { s.kill(); } catch { /* gone */ } } });

/** Stop the session leaving the program RUNNING: a game left halted would sit frozen. */
async function endSession(): Promise<void> {
  const s = session;
  session = null;
  if (!s?.alive) return;
  await s.request('continue', { threadId: 1 }).catch(() => {});
  await s.request('disconnect', { terminateDebuggee: false, suspendDebuggee: false }).catch(() => {});
  s.end('ended');
}

export function registerHwDebug(getWin: () => BrowserWindow | null): void {
  const send = (ch: string, payload: unknown) => getWin()?.webContents.send(ch, payload);

  /** Reset the cartridge (its menu comes up), start the DAP server and attach to core 1. */
  ipcMain.handle('hwdebug:start', async (_e, args: { elfPath: string }) => {
    await endSession();
    const reset = await probeRs(['reset', '--chip', CHIP, '--speed', SPEED]);
    if (reset.code !== 0) return { error: `probe-rs reset failed: ${reset.out.trim() || reset.code}. Is the SWD probe connected?` };
    // The firmware brings up the PSRAM and the menu before it reads the launch mailbox.
    await new Promise((r) => setTimeout(r, 2500));
    const s = new DapSession(
      (ev) => send('hwdebug:event', ev),
      (why) => { if (session === s) session = null; send('hwdebug:ended', why); },
    );
    try {
      await s.start();
    } catch (e: any) {
      s.end(String(e?.message ?? e));
      return { error: String(e?.message ?? e) };
    }
    session = s;
    const init = await s.request('initialize', {
      adapterID: 'probe-rs-debug', clientID: 'vectrex-studio', linesStartAt1: true, columnsStartAt1: true, pathFormat: 'path',
    });
    if (!init.success) { await endSession(); return { error: `initialize: ${init.message}` }; }
    const attach = await s.request('attach', {
      chip: CHIP, speed: Number(SPEED), wireProtocol: 'Swd',
      coreConfigs: [{ coreIndex: 1, programBinary: args.elfPath }],
    });
    if (!attach.success) { await endSession(); return { error: `attach: ${attach.message}` }; }
    return { ok: true };
  });

  ipcMain.handle('hwdebug:request', async (_e, command: string, args: unknown) => {
    if (!session) return { success: false, message: 'no session' };
    return session.request(command, args);
  });

  ipcMain.handle('hwdebug:end', async () => { await endSession(); return { ok: true }; });

  // Quitting with a session open waits for it to let the game run and free the probe: a
  // game left halted would sit frozen on the console, and the server would keep the probe.
  let released = false;
  app.on('before-quit', (e) => {
    if (released || !session?.alive) return;
    e.preventDefault();
    released = true;
    const done = () => app.quit();
    Promise.race([endSession(), new Promise((r) => setTimeout(r, 3000))]).then(done, done);
  });
}


