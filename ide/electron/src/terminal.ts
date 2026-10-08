// Integrated terminal: real PTYs (via @lydell/node-pty) bridged to xterm.js in the renderer.
//
// Each terminal is a login shell (macOS/Linux) so it gets the user's full PATH — a
// GUI-launched Electron app on macOS inherits a minimal PATH, and tools such as `claude`
// usually live in ~/.local/bin or similar, which only the login profile adds.
//
// IPC surface (see preload.ts `window.terminal`):
//   invoke  terminal:create  {cwd?, cols, rows, command?} -> {id, shell} | {error}
//   send    terminal:write   (id, data)
//   send    terminal:resize  (id, cols, rows)
//   invoke  terminal:kill    (id)
//   invoke  terminal:openLink (url)       http(s) links clicked in the terminal
//   events  terminal://data  (id, data)   batched output
//           terminal://exit  (id, code)

import { withShellIntegration } from './shellIntegration.js';
import { app, BrowserWindow, clipboard, ipcMain, shell, WebContents } from 'electron';
import { existsSync, mkdirSync, readdirSync, statSync, unlinkSync, writeFileSync } from 'fs';
import { join } from 'path';
import { defaultProjectsDir } from './projectTemplates.js';
import * as os from 'os';
import type { IPty } from '@lydell/node-pty';

type PtyModule = typeof import('@lydell/node-pty');

interface Session {
  id: number;
  pty: IPty;
  owner: WebContents;
  pending: string;
  flushTimer: NodeJS.Timeout | null;
  exited: boolean;
}

/** Output is coalesced for this long before one IPC message is sent. */
const FLUSH_INTERVAL_MS = 5;
/** ...unless this much has accumulated, then it is flushed immediately. */
const FLUSH_MAX_CHARS = 256 * 1024;

const sessions = new Map<number, Session>();
let nextId = 1;
let ptyModule: PtyModule | null = null;
let ptyLoadError: string | null = null;

function loadPty(): PtyModule | null {
  if (ptyModule || ptyLoadError) return ptyModule;
  try {
    // Loaded lazily so a missing/broken native module only disables the terminal,
    // instead of preventing the whole IDE from starting.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    ptyModule = require('@lydell/node-pty') as PtyModule;
  } catch (e: any) {
    ptyLoadError = e?.message || String(e);
    console.error('[Terminal] failed to load @lydell/node-pty:', ptyLoadError);
  }
  return ptyModule;
}

/**
 * Builds the environment of every terminal child process. This is the single place
 * where the terminal env is assembled; extend it here (e.g. MCP / Claude wiring).
 */
export function buildTerminalEnv(base: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = { ...base };
  // Inherited from Electron tooling; would turn any Electron app started from the
  // terminal (e.g. VS Code's `code`) into plain Node.
  delete env.ELECTRON_RUN_AS_NODE;
  env.TERM = 'xterm-256color';
  env.COLORTERM = 'truecolor';
  env.TERM_PROGRAM = 'VectrexStudio';
  try { env.TERM_PROGRAM_VERSION = app.getVersion(); } catch { /* not ready */ }
  if (process.platform !== 'win32' && !env.LANG && !env.LC_ALL && !env.LC_CTYPE) {
    // GUI apps on macOS start without a locale; TUIs need UTF-8 for box drawing.
    env.LANG = 'en_US.UTF-8';
  }
  return env;
}

/** Resolves the user's shell and its arguments (login shell on POSIX). */
export function resolveShell(): { file: string; args: string[] } {
  if (process.platform === 'win32') {
    const sysRoot = process.env.SystemRoot || process.env.windir || 'C:\\Windows';
    const ps = `${sysRoot}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe`;
    if (existsSync(ps)) return { file: ps, args: ['-NoLogo'] };
    return { file: process.env.COMSPEC || 'cmd.exe', args: [] };
  }
  const candidates = [
    process.env.SHELL,
    process.platform === 'darwin' ? '/bin/zsh' : '/bin/bash',
    process.platform === 'darwin' ? '/bin/bash' : '/bin/zsh',
    '/bin/sh',
  ];
  for (const c of candidates) {
    if (c && existsSync(c)) return { file: c, args: ['-l'] };
  }
  return { file: '/bin/sh', args: ['-l'] };
}

function resolveCwd(cwd?: string): string {
  if (cwd) {
    try { if (statSync(cwd).isDirectory()) return cwd; } catch { /* fall through */ }
  }
  // No project open: the default workspace, the same folder every time, so Claude Code
  // sessions started here can be resumed (they are keyed by folder).
  try { mkdirSync(defaultProjectsDir(), { recursive: true }); return defaultProjectsDir(); } catch { return os.homedir(); }
}

function flush(s: Session) {
  if (s.flushTimer) { clearTimeout(s.flushTimer); s.flushTimer = null; }
  if (!s.pending) return;
  const data = s.pending;
  s.pending = '';
  if (!s.owner.isDestroyed()) s.owner.send('terminal://data', s.id, data);
}

function killSession(s: Session) {
  if (s.flushTimer) { clearTimeout(s.flushTimer); s.flushTimer = null; }
  sessions.delete(s.id);
  if (!s.exited) {
    s.exited = true;
    try { s.pty.kill(); } catch { /* already gone */ }
  }
}

/** Kills every PTY (optionally only those owned by one renderer). */
export function killAllTerminals(owner?: WebContents) {
  for (const s of Array.from(sessions.values())) {
    if (!owner || s.owner === owner) killSession(s);
  }
}

const trackedOwners = new WeakSet<WebContents>();
function trackOwner(wc: WebContents) {
  if (trackedOwners.has(wc)) return;
  trackedOwners.add(wc);
  // Window closed, renderer crashed or page reloaded: its PTYs have no UI left.
  wc.once('destroyed', () => killAllTerminals(wc));
  wc.on('render-process-gone', () => killAllTerminals(wc));
  wc.on('did-navigate', () => killAllTerminals(wc));
}

/**
 * Types `line` into the shell once it has started: waits for the first output (the
 * prompt) and then for output to go quiet, so login scripts don't swallow typeahead.
 */
function typeWhenReady(s: Session, line: string) {
  let idleTimer: NodeJS.Timeout | null = null;
  let done = false;
  const send = () => {
    if (done) return;
    done = true;
    if (idleTimer) clearTimeout(idleTimer);
    clearTimeout(hardTimer);
    sub.dispose();
    if (!s.exited) s.pty.write(line + '\r');
  };
  const hardTimer = setTimeout(send, 3000);
  const sub = s.pty.onData(() => {
    if (idleTimer) clearTimeout(idleTimer);
    idleTimer = setTimeout(send, 150);
  });
}

export function registerTerminalHandlers(getWindow: () => BrowserWindow | null) {
  const allowedSender = (wc: WebContents) => {
    const win = getWindow();
    if (win && !win.isDestroyed() && win.webContents === wc) return true;
    return BrowserWindow.fromWebContents(wc) !== null;
  };

  ipcMain.handle('terminal:create', (e, opts: { cwd?: string; cols?: number; rows?: number; command?: string } = {}) => {
    if (!allowedSender(e.sender)) return { error: 'Sender not allowed' };
    const ptyLib = loadPty();
    if (!ptyLib) return { error: `Terminal unavailable: ${ptyLoadError}` };
    // The shell with the IDE's integration loaded (`claude` gets the IDE's MCP tools).
    const shell = resolveShell();
    const { file, args, env } = withShellIntegration(shell.file, shell.args, buildTerminalEnv(process.env));
    const cols = Math.max(2, Math.floor(opts.cols || 80));
    const rows = Math.max(1, Math.floor(opts.rows || 24));
    let pty: IPty;
    try {
      pty = ptyLib.spawn(file, args, {
        name: 'xterm-256color',
        cols,
        rows,
        cwd: resolveCwd(opts.cwd),
        env: env as { [key: string]: string },
      });
    } catch (err: any) {
      return { error: `Failed to start ${file}: ${err?.message || err}` };
    }
    const s: Session = { id: nextId++, pty, owner: e.sender, pending: '', flushTimer: null, exited: false };
    sessions.set(s.id, s);
    trackOwner(e.sender);

    pty.onData((data) => {
      s.pending += data;
      if (s.pending.length >= FLUSH_MAX_CHARS) flush(s);
      else if (!s.flushTimer) s.flushTimer = setTimeout(() => flush(s), FLUSH_INTERVAL_MS);
    });
    pty.onExit(({ exitCode }) => {
      flush(s);
      const wasKilled = s.exited;
      s.exited = true;
      sessions.delete(s.id);
      if (!wasKilled && !s.owner.isDestroyed()) s.owner.send('terminal://exit', s.id, exitCode);
    });

    if (opts.command && opts.command.trim()) typeWhenReady(s, opts.command);
    return { id: s.id, shell: file };
  });

  ipcMain.on('terminal:write', (e, id: number, data: string) => {
    const s = sessions.get(id);
    if (!s || s.owner !== e.sender || s.exited || typeof data !== 'string') return;
    s.pty.write(data);
  });

  ipcMain.on('terminal:resize', (e, id: number, cols: number, rows: number) => {
    const s = sessions.get(id);
    if (!s || s.owner !== e.sender || s.exited) return;
    const c = Math.floor(cols), r = Math.floor(rows);
    if (!(c > 0 && r > 0)) return;
    try { s.pty.resize(c, r); } catch { /* raced with exit */ }
  });

  ipcMain.handle('terminal:kill', (e, id: number) => {
    const s = sessions.get(id);
    if (!s || s.owner !== e.sender) return { ok: false };
    killSession(s);
    return { ok: true };
  });

  ipcMain.handle('terminal:openLink', async (e, url: string) => {
    if (!allowedSender(e.sender) || typeof url !== 'string') return { ok: false };
    let parsed: URL;
    try { parsed = new URL(url); } catch { return { ok: false }; }
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return { ok: false };
    await shell.openExternal(parsed.toString());
    return { ok: true };
  });

  // Paste of a clipboard image (a screenshot): the PTY only carries text, so the image
  // is saved as a PNG and its path is pasted. Claude Code attaches a pasted image path.
  ipcMain.handle('terminal:pasteImage', (e) => {
    if (!allowedSender(e.sender)) return { path: null };
    const img = clipboard.readImage();
    if (img.isEmpty()) return { path: null };
    const dir = join(os.tmpdir(), 'vectrex-studio-paste');
    try {
      mkdirSync(dir, { recursive: true });
      // Keep the folder small: images older than a day are no longer needed.
      const dayAgo = Date.now() - 24 * 3600 * 1000;
      for (const f of readdirSync(dir)) {
        const fp = join(dir, f);
        try { if (statSync(fp).mtimeMs < dayAgo) unlinkSync(fp); } catch { /* ignore */ }
      }
      const file = join(dir, `image-${Date.now()}.png`);
      writeFileSync(file, img.toPNG());
      return { path: file };
    } catch (err) {
      console.warn('[TERMINAL] could not save the pasted image:', err);
      return { path: null };
    }
  });

  app.on('before-quit', () => killAllTerminals());
  process.on('exit', () => killAllTerminals());
}
