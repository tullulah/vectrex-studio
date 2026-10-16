/**
 * The gdb server: `target remote :3333` in arm-none-eabi-gdb reaches the IDE's ARM
 * emulator (rp2350 / uvm2) through this socket.
 *
 * This side only frames packets (rsp.ts); the renderer's stub answers them
 * (ide/frontend/src/debug/gdbStub.ts, as `window.__gdbStub__`). A continue has no
 * immediate answer: the stub is polled until the program stops, or until gdb's Ctrl+C.
 *
 * Localhost only, one gdb at a time. Port 3333 (OpenOCD's, which gdb users type out of
 * habit), or the next free one up to 3343.
 */
import * as net from 'net';
import type { BrowserWindow } from 'electron';
import { RspParser, encode } from './rsp.js';

const PORTS = Array.from({ length: 11 }, (_, i) => 3333 + i);
const POLL_MS = 20;

let window: BrowserWindow | null = null;
let port: number | null = null;
let busy: net.Socket | null = null;
let starting: Promise<number | null> | null = null;

export function setGdbWindow(w: BrowserWindow | null): void { window = w; }
export function getGdbPort(): number | null { return port; }

/** Call the renderer's stub: {ok, value} back, or an error. */
async function stub(fn: 'handle' | 'poll' | 'interrupt' | 'attach', arg?: string): Promise<any> {
  if (!window || window.isDestroyed()) throw new Error('The IDE window is not open');
  const call = `(function(){var s=window.__gdbStub__;if(!s)return {ok:false,error:'gdb stub not loaded (rebuild ide/frontend)'};` +
    `return s.${fn}(${arg === undefined ? '' : JSON.stringify(arg)});})()`;
  const r = await window.webContents.executeJavaScript(call, true);
  if (!r?.ok) throw new Error(r?.error || `${fn} failed`);
  return r.value;
}

function attach(socket: net.Socket, verbose: boolean): void {
  const parser = new RspParser();
  let noAck = false;
  let running = false; // a continue is waiting for its stop
  let queue = Promise.resolve();
  const send = (body: string) => { if (!socket.destroyed) socket.write(encode(body), 'latin1'); };
  const log = (...a: any[]) => { if (verbose) console.log('[gdb]', ...a); };

  const waitForStop = async () => {
    while (running && !socket.destroyed) {
      const reply = await stub('poll').catch(() => null);
      if (reply && running) { running = false; send(reply); return; }
      await new Promise((r) => setTimeout(r, POLL_MS));
    }
  };

  const onPacket = async (body: string) => {
    log('<-', body.length > 80 ? body.slice(0, 80) + '...' : body);
    if (body === 'QStartNoAckMode') { send('OK'); noAck = true; return; }
    // '?' is gdb's first question after the greeting: stop the program for it, or say
    // why there is none (gdb prints an E.<text> reply as is)
    if (body === '?') {
      try { await stub('attach'); } catch (e: any) { send(`E.${e?.message || e}`); return; }
    }
    let reply: string | null;
    try {
      reply = await stub('handle', body);
    } catch (e: any) {
      log('error', e?.message || e);
      send('E01');
      return;
    }
    if (body[0] === 'k') { socket.end(); return; }
    if (reply === null) { running = true; void waitForStop(); return; }
    log('->', reply.length > 80 ? reply.slice(0, 80) + '...' : reply);
    send(reply);
  };

  socket.setEncoding('latin1');
  socket.on('data', (data: string) => {
    for (const ev of parser.feed(data)) {
      if (ev.kind === 'bad') { if (!noAck) socket.write('-'); continue; }
      if (ev.kind === 'interrupt') {
        // Answered even mid-queue: it is what stops a continue
        queue = queue.then(async () => {
          if (!running) return;
          running = false;
          send(await stub('interrupt').catch(() => 'T02'));
        });
        continue;
      }
      if (!noAck) socket.write('+');
      queue = queue.then(() => onPacket(ev.body));
    }
  });
  socket.on('close', () => {
    running = false;
    if (busy === socket) busy = null;
    // gdb gone without a detach: its breakpoints go, the program runs on
    stub('handle', 'D').catch(() => {});
    log('disconnected');
  });
  socket.on('error', () => {});
}

/** Listen (once: a second call gets the first one's port). */
export function startGdbServer(verbose = false): Promise<number | null> {
  if (starting) return starting;
  const server = net.createServer((socket) => {
    if (busy && !busy.destroyed) { socket.end(); return; } // one gdb at a time
    busy = socket;
    attach(socket, verbose);
  });
  const tryPort = (i: number): Promise<number | null> => new Promise((resolve) => {
    if (i >= PORTS.length) { resolve(null); return; }
    server.once('error', () => resolve(tryPort(i + 1)));
    server.listen(PORTS[i], '127.0.0.1', () => { port = PORTS[i]; resolve(port); });
  });
  starting = tryPort(0);
  return starting;
}
