// Integrated terminal sessions.
//
// Tab metadata lives in a small Zustand store; the xterm.js instances and their host
// <div>s live outside React in `runtimes`, so they survive tab switches AND hiding the
// whole Terminal panel (the panel only re-parents the host elements). The PTY itself
// lives in the Electron main process (electron/src/terminal.ts).

import { create } from 'zustand';
import { Terminal, type ITheme } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { WebLinksAddon } from '@xterm/addon-web-links';
import { Unicode11Addon } from '@xterm/addon-unicode11';
import '@xterm/xterm/css/xterm.css';
import { useProjectStore } from '../state/projectStore';

export interface TerminalTab {
  key: string;
  title: string;
  /** PTY id in the main process; null until the shell has been spawned. */
  ptyId: number | null;
  exited: boolean;
  exitCode?: number;
  error?: string;
}

interface TerminalStoreState {
  tabs: TerminalTab[];
  activeKey: string | null;
  setActive: (key: string) => void;
  rename: (key: string, title: string) => void;
}

export const useTerminalStore = create<TerminalStoreState>((set) => ({
  tabs: [],
  activeKey: null,
  setActive: (key) => set({ activeKey: key }),
  rename: (key, title) => set((s) => ({
    tabs: s.tabs.map((t) => (t.key === key ? { ...t, title: title.trim() || t.title } : t)),
  })),
}));

interface Runtime {
  term: Terminal;
  fit: FitAddon;
  host: HTMLDivElement;
  opened: boolean;
  starting: boolean;
  ptyId: number | null;
  cwd?: string;
  command?: string;
  disposed: boolean;
}

const runtimes = new Map<string, Runtime>();
const keyByPty = new Map<number, string>();
/** Output that arrived for a PTY id before its tab was registered. */
const earlyData = new Map<number, string>();
let seq = 0;
let listenersInstalled = false;

const THEME: ITheme = {
  background: '#1e1e1e',
  foreground: '#cccccc',
  cursor: '#aeafad',
  cursorAccent: '#1e1e1e',
  selectionBackground: '#264f78',
  black: '#000000',
  red: '#cd3131',
  green: '#0dbc79',
  yellow: '#e5e510',
  blue: '#2472c8',
  magenta: '#bc3fbc',
  cyan: '#11a8cd',
  white: '#e5e5e5',
  brightBlack: '#666666',
  brightRed: '#f14c4c',
  brightGreen: '#23d18b',
  brightYellow: '#f5f543',
  brightBlue: '#3b8eea',
  brightMagenta: '#d670d6',
  brightCyan: '#29b8db',
  brightWhite: '#e5e5e5',
};

// Menlo / SF Mono / Cascadia / DejaVu all carry full box-drawing + block glyphs.
const FONT_FAMILY = 'Menlo, "SF Mono", Monaco, "Cascadia Mono", Consolas, "DejaVu Sans Mono", "Liberation Mono", monospace';

function api(): TerminalAPI | undefined {
  return window.terminal;
}

export function isTerminalAvailable(): boolean {
  return !!api();
}

export function terminalPlatform(): string {
  return api()?.platform || 'unknown';
}

function patchTab(key: string, patch: Partial<TerminalTab>) {
  useTerminalStore.setState((s) => ({ tabs: s.tabs.map((t) => (t.key === key ? { ...t, ...patch } : t)) }));
}

function installListeners() {
  if (listenersInstalled) return;
  const a = api();
  if (!a) return;
  listenersInstalled = true;
  a.onData((id, data) => {
    const key = keyByPty.get(id);
    const rt = key ? runtimes.get(key) : undefined;
    if (rt) rt.term.write(data);
    else earlyData.set(id, (earlyData.get(id) || '') + data);
  });
  a.onExit((id, code) => {
    const key = keyByPty.get(id);
    keyByPty.delete(id);
    if (!key) return;
    const rt = runtimes.get(key);
    if (rt) {
      rt.ptyId = null;
      rt.term.write(`\r\n\x1b[90m[process exited with code ${code}]\x1b[0m\r\n`);
    }
    patchTab(key, { exited: true, exitCode: code, ptyId: null });
  });
}

const isMac = () => terminalPlatform() === 'darwin';

function copySelection(term: Terminal) {
  const sel = term.getSelection();
  if (sel) navigator.clipboard?.writeText(sel).catch(() => {});
}

/** A path as one shell word (Claude Code also reads it as an attachment). */
function shellPath(p: string): string {
  if (terminalPlatform() === 'win32') return /\s/.test(p) ? `"${p}"` : p;
  return p.replace(/([\s'"\\()&;|<>$`!*?[\]{}#~])/g, '\\$1');
}

/** Pastes clipboard text; with no text, a clipboard image is pasted as a temp PNG path. */
function pasteInto(term: Terminal) {
  const viaImage = () => api()?.pasteImage?.()
    .then((r) => { if (r?.path) term.paste(shellPath(r.path) + ' '); })
    .catch(() => {});
  if (!navigator.clipboard) { viaImage(); return; }
  navigator.clipboard.readText()
    .then((text) => { if (text) term.paste(text); else viaImage(); })
    .catch(() => viaImage());
}

/** Files dropped from the OS are pasted as their paths (images become Claude attachments). */
function installDrop(term: Terminal, host: HTMLElement) {
  host.addEventListener('dragover', (e) => {
    if (e.dataTransfer?.types.includes('Files')) { e.preventDefault(); e.dataTransfer.dropEffect = 'copy'; }
  });
  host.addEventListener('drop', (e) => {
    const files = Array.from(e.dataTransfer?.files ?? []);
    if (!files.length) return;
    e.preventDefault();
    e.stopPropagation();
    const paths = files.map((f) => api()?.pathForFile?.(f)).filter((p): p is string => !!p);
    if (paths.length) { term.paste(paths.map(shellPath).join(' ') + ' '); term.focus(); }
  });
}

/**
 * Clipboard keys. Returns false to stop xterm from handling the event.
 * macOS: Cmd+C / Cmd+V (Cmd never reaches the shell anyway).
 * Windows/Linux: Ctrl+Shift+C / Ctrl+Shift+V, Ctrl+C only copies when there is a
 * selection (otherwise it stays SIGINT), Ctrl+V pastes on Windows only.
 */
function clipboardKeyHandler(term: Terminal, e: KeyboardEvent): boolean {
  // IDE keys handled by the window-level shortcut handler (main.tsx): don't also send
  // them to the shell.
  if (e.ctrlKey && !e.metaKey && !e.altKey && e.code === 'Backquote') return false;
  if ((e.key === 'F5' || e.key === 'F7') && !e.ctrlKey && !e.metaKey && !e.altKey) return false;
  if (e.type !== 'keydown') return true;
  const k = e.key.toLowerCase();
  if (isMac()) {
    if (e.metaKey && !e.ctrlKey && !e.altKey) {
      if (k === 'c') { copySelection(term); e.preventDefault(); return false; }
      if (k === 'v') { pasteInto(term); e.preventDefault(); return false; }
      if (k === 'a') { term.selectAll(); e.preventDefault(); return false; }
      if (k === 'k') { term.clear(); e.preventDefault(); return false; }
      // Leave the other Cmd shortcuts to the IDE.
      return false;
    }
    return true;
  }
  if (e.ctrlKey && !e.altKey && !e.metaKey) {
    if (e.shiftKey && k === 'c') { copySelection(term); e.preventDefault(); return false; }
    if (e.shiftKey && k === 'v') { pasteInto(term); e.preventDefault(); return false; }
    if (!e.shiftKey && k === 'c' && term.hasSelection()) { copySelection(term); term.clearSelection(); e.preventDefault(); return false; }
    if (!e.shiftKey && k === 'v' && terminalPlatform() === 'win32') { pasteInto(term); e.preventDefault(); return false; }
  }
  return true;
}

function createRuntime(key: string, cwd?: string, command?: string): Runtime {
  const host = document.createElement('div');
  host.className = 'vpy-terminal-host';
  host.dataset.terminalKey = key;
  host.style.position = 'absolute';
  host.style.inset = '0';
  host.style.display = 'none';

  const term = new Terminal({
    allowProposedApi: true, // required by the unicode11 addon
    fontFamily: FONT_FAMILY,
    fontSize: 13,
    lineHeight: 1.0,
    cursorBlink: true,
    scrollback: 10000,
    theme: THEME,
    macOptionIsMeta: false,
    rightClickSelectsWord: false,
    drawBoldTextInBrightColors: true,
  });
  const fit = new FitAddon();
  term.loadAddon(fit);
  term.loadAddon(new WebLinksAddon((_ev, uri) => { api()?.openLink(uri); }));
  try {
    const u = new Unicode11Addon();
    term.loadAddon(u);
    term.unicode.activeVersion = '11';
  } catch { /* optional */ }

  const rt: Runtime = { term, fit, host, opened: false, starting: false, ptyId: null, cwd, command, disposed: false };
  term.attachCustomKeyEventHandler((e) => clipboardKeyHandler(term, e));
  installDrop(term, host);
  term.onData((d) => { if (rt.ptyId != null) api()?.write(rt.ptyId, d); });
  term.onResize(({ cols, rows }) => { if (rt.ptyId != null) api()?.resize(rt.ptyId, cols, rows); });
  return rt;
}

/** Opens a new terminal tab. The shell is spawned once the panel shows it. */
export function newTerminal(opts: { title?: string; cwd?: string; command?: string } = {}): string {
  installListeners();
  const key = `term-${++seq}`;
  runtimes.set(key, createRuntime(key, opts.cwd, opts.command));
  const n = useTerminalStore.getState().tabs.length + 1;
  const tab: TerminalTab = { key, title: opts.title || `${shellLabel()} ${n}`, ptyId: null, exited: false };
  useTerminalStore.setState((s) => ({ tabs: [...s.tabs, tab], activeKey: key }));
  return key;
}

function shellLabel(): string {
  return terminalPlatform() === 'win32' ? 'pwsh' : 'shell';
}

/** Closes a tab and kills its PTY. */
export function closeTerminal(key: string) {
  const rt = runtimes.get(key);
  if (rt) {
    rt.disposed = true;
    if (rt.ptyId != null) {
      keyByPty.delete(rt.ptyId);
      api()?.kill(rt.ptyId);
    }
    try { rt.term.dispose(); } catch { /* ignore */ }
    rt.host.remove();
    runtimes.delete(key);
  }
  useTerminalStore.setState((s) => {
    const idx = s.tabs.findIndex((t) => t.key === key);
    const tabs = s.tabs.filter((t) => t.key !== key);
    let activeKey = s.activeKey;
    if (activeKey === key) activeKey = tabs.length ? tabs[Math.min(idx, tabs.length - 1)].key : null;
    return { tabs, activeKey };
  });
}

/**
 * Attaches a tab's host element into `container` (idempotent), opening xterm and
 * spawning the shell the first time it becomes visible.
 */
export function attachTerminal(key: string, container: HTMLElement, visible: boolean) {
  const rt = runtimes.get(key);
  if (!rt || rt.disposed) return;
  if (rt.host.parentElement !== container) container.appendChild(rt.host);
  rt.host.style.display = visible ? 'block' : 'none';
  if (!visible) return;
  if (!rt.opened) {
    rt.term.open(rt.host);
    rt.opened = true;
  }
  fitTerminal(key);
  if (rt.ptyId == null && !rt.starting && !useTerminalStore.getState().tabs.find((t) => t.key === key)?.exited) {
    void startPty(key, rt);
  }
}

export function fitTerminal(key: string) {
  const rt = runtimes.get(key);
  if (!rt || !rt.opened || rt.disposed) return;
  if (rt.host.offsetWidth === 0 || rt.host.offsetHeight === 0) return; // hidden: keep size
  try { rt.fit.fit(); } catch { /* not measurable yet */ }
}

export function focusTerminal(key: string) {
  const rt = runtimes.get(key);
  if (rt?.opened) rt.term.focus();
}

function projectRoot(): string | undefined {
  const s = useProjectStore.getState();
  return s.vpyProject?.rootDir || s.project?.rootPath || undefined;
}

/** The folder a tab with no explicit cwd starts in: the open project. Claude Code keys its
 *  sessions by folder (`claude --resume` lists only the current folder's), so this must not
 *  depend on timing: the terminal the panel opens at startup is created before the IDE has
 *  reopened the last project, so wait for it a moment instead of starting in $HOME. With no
 *  project the main process uses the default workspace (~/VectrexStudio/projects). */
async function startCwd(rt: Runtime): Promise<string | undefined> {
  if (rt.cwd) return rt.cwd;
  const deadline = Date.now() + 3000;
  for (let root = projectRoot(); ; root = projectRoot()) {
    if (root || Date.now() > deadline || performance.now() > 15000) return root;
    await new Promise((r) => setTimeout(r, 100));
  }
}

async function startPty(key: string, rt: Runtime) {
  const a = api();
  if (!a) {
    rt.term.write('Terminal is only available in the desktop app.\r\n');
    patchTab(key, { error: 'unavailable' });
    return;
  }
  rt.starting = true;
  rt.cwd = await startCwd(rt);
  const res = await a.create({ cwd: rt.cwd, cols: rt.term.cols, rows: rt.term.rows, command: rt.command });
  rt.starting = false;
  if ('error' in res) {
    rt.term.write(`\x1b[31m${res.error}\x1b[0m\r\n`);
    patchTab(key, { error: res.error });
    return;
  }
  if (rt.disposed) { a.kill(res.id); return; }
  rt.ptyId = res.id;
  keyByPty.set(res.id, key);
  const early = earlyData.get(res.id);
  if (early) { earlyData.delete(res.id); rt.term.write(early); }
  patchTab(key, { ptyId: res.id });
  // The size may have changed while the shell was spawning.
  a.resize(res.id, rt.term.cols, rt.term.rows);
}

/** Restarts the shell of an exited tab in place (keeps the scrollback). */
export function restartTerminal(key: string) {
  const rt = runtimes.get(key);
  if (!rt || rt.ptyId != null || rt.starting) return;
  rt.command = undefined;
  patchTab(key, { exited: false, exitCode: undefined, error: undefined });
  void startPty(key, rt);
}

function sanitizeForShell(s: string): string {
  // Messages are embedded in single-quoted strings; typographic quotes avoid
  // per-shell escaping rules (POSIX sh, zsh, fish, PowerShell all differ).
  return s.replace(/'/g, '’').replace(/[\r\n]+/g, ' ');
}

/**
 * The line typed into a fresh shell by the "Claude" button: run `claude` if it is on
 * the (login) PATH, otherwise print how to install it. Detection happens in the shell
 * so it sees exactly the PATH the user would.
 */
export function buildClaudeLaunchLine(platform: string, msg: { notFound: string; thenType: string }): string {
  const notFound = sanitizeForShell(msg.notFound);
  const thenType = sanitizeForShell(msg.thenType);
  if (platform === 'win32') {
    const install = 'irm https://claude.ai/install.ps1 | iex';
    return `if (Get-Command claude -ErrorAction SilentlyContinue) { claude } else { Write-Host ''; Write-Host '${notFound}' -ForegroundColor Yellow; Write-Host '    ${install}' -ForegroundColor Cyan; Write-Host '${thenType}'; Write-Host '' }`;
  }
  const install = 'curl -fsSL https://claude.ai/install.sh | bash';
  // `A && claude || A || printf`: works in sh/bash/zsh and fish 3; a non-zero exit
  // from claude itself does not print the install hint (the second A succeeds).
  return `command -v claude >/dev/null 2>&1 && claude || command -v claude >/dev/null 2>&1 || printf '\\n\\033[33m%s\\033[0m\\n    \\033[36m%s\\033[0m\\n%s\\n\\n' '${notFound}' '${install}' '${thenType}'`;
}
