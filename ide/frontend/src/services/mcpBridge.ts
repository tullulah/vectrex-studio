/**
 * Renderer side of the MCP bridge.
 *
 * The Electron main process (ide/electron/src/mcp/server.ts) drives the UI for
 * MCP tools through this ONE explicit object instead of poking store internals
 * from string-built JavaScript. Main calls
 *
 *   window.__mcpBridge__.invoke(<name>, <JSON args>)
 *
 * and always gets `{ ok: true, value }` or `{ ok: false, error }` back — never a
 * rejected promise, so error messages survive executeJavaScript.
 *
 * Keep these functions small and state-shaped: file I/O, path containment and
 * text editing live in main; this layer only reads/writes renderer state and
 * triggers the same commands the UI uses.
 */

import { useEditorStore } from '../state/editorStore.js';
import { useProjectStore } from '../state/projectStore.js';
import { useDebugStore } from '../state/debugStore.js';
import { useSettings, type BuildTarget } from '../state/settingsStore.js';
import { useEmulatorStore } from '../state/emulatorStore.js';
import { ensureComponent } from '../state/dockBus.js';
import type { DocumentModel } from '../types/models.js';
import type { BuildMode, BuildOutcome } from './buildOutcome.js';

type BridgeResult = { ok: true; value: unknown } | { ok: false; error: string };
type Fn = (args: any) => unknown | Promise<unknown>;

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
const vecx = (): any => (window as any).vecx;

function regValue(r: unknown): number {
  if (r && typeof r === 'object' && 'value' in (r as any)) return Number((r as any).value) || 0;
  return Number(r) || 0;
}

function readRegisters() {
  const cpu = vecx()?.e6809;
  if (!cpu) throw new Error('Emulator CPU not available (is the Emulator panel open?)');
  const a = regValue(cpu.reg_a) & 0xff;
  const b = regValue(cpu.reg_b) & 0xff;
  return {
    A: a, B: b, D: (a << 8) | b,
    X: regValue(cpu.reg_x) & 0xffff,
    Y: regValue(cpu.reg_y) & 0xffff,
    U: regValue(cpu.reg_u) & 0xffff,
    S: regValue(cpu.reg_s) & 0xffff,
    PC: regValue(cpu.reg_pc) & 0xffff,
    DP: regValue(cpu.reg_dp) & 0xff,
    CC: regValue(cpu.reg_cc) & 0xff,
  };
}

function docSummary(d: DocumentModel, active?: string) {
  return { uri: d.uri, language: d.language, dirty: d.dirty, diskPath: d.diskPath ?? null, active: d.uri === active };
}

async function openFileDoc(uri: string, diskPath: string, language: DocumentModel['language']) {
  const files = (window as any).files;
  const r = await files?.readFile?.(diskPath);
  if (!r || r.error) return false;
  useEditorStore.getState().openDocument({
    uri, language, content: r.content, dirty: false, diagnostics: [],
    diskPath, mtime: r.mtime, lastSavedContent: r.content,
  });
  return true;
}

function languageOf(p: string): DocumentModel['language'] {
  const ext = (p.split('.').pop() || '').toLowerCase();
  if (ext === 'vpy') return 'vpy';
  if (ext === 'c' || ext === 'h') return 'c';
  if (ext === 'cpp' || ext === 'cc' || ext === 'cxx' || ext === 'hpp') return 'cpp';
  if (['json', 'vec', 'vmus', 'vsfx', 'vanim', 'vplay'].includes(ext)) return 'json';
  if (ext === 'asm' || ext === 's') return 'asm';
  if (ext === 'md') return 'markdown';
  return 'plaintext';
}

function uriToDiskPath(uri: string): string {
  let p = uri.replace('file:///', '').replace('file://', '');
  if (!/^[A-Za-z]:\//.test(p) && !p.startsWith('/')) p = '/' + p;
  return p;
}

// ── Build runner (registered by main.tsx: the same handleBuild the keys call) ──
type BuildRunner = (mode: BuildMode) => Promise<BuildOutcome>;
let buildRunner: BuildRunner | null = null;

/** main.tsx registers handleBuild here; returns the unregister function (for useEffect). */
export function registerBuildRunner(fn: BuildRunner): () => void {
  buildRunner = fn;
  return () => { if (buildRunner === fn) buildRunner = null; };
}

// ── Build output capture (run://stdout, run://stderr, run://status) ──────────
// Kept in a bounded buffer with a sequence number so runBuild can return exactly the
// output of ITS build. Registered once, at module load.
const OUTPUT_CAP_CHARS = 200_000;
let outputSeq = 0;
let outputChars = 0;
const outputChunks: Array<{ seq: number; text: string }> = [];

function captureOutput(prefix: string) {
  return (chunk: unknown) => {
    const text = typeof chunk === 'string' ? chunk : String(chunk ?? '');
    if (!text) return;
    const line = prefix ? `${prefix}${text}${text.endsWith('\n') ? '' : '\n'}` : text;
    outputChunks.push({ seq: ++outputSeq, text: line });
    outputChars += line.length;
    while (outputChars > OUTPUT_CAP_CHARS && outputChunks.length > 1) outputChars -= outputChunks.shift()!.text.length;
  };
}

if (typeof window !== 'undefined') {
  const eapi: any = (window as any).electronAPI;
  try {
    eapi?.onRunStdout?.(captureOutput(''));
    eapi?.onRunStderr?.(captureOutput(''));
    eapi?.onRunStatus?.(captureOutput('[status] '));
  } catch { /* no preload (tests) */ }
}

function outputSince(seq: number, maxChars: number): string {
  const text = outputChunks.filter((c) => c.seq > seq).map((c) => c.text).join('');
  return text.length > maxChars ? '…' + text.slice(-maxChars) : text;
}

// ── Emulator summary ──────────────────────────────────────────────────────
const BACKEND_LABEL: Record<string, string> = {
  m6809: 'JSVecX — the 6809 Vectrex emulator (original cartridge)',
  rp2350: 'RP2350 cartridge emulator (ARM Thumb-2, the real machine code)',
  uvm2: 'UVM2 multicart emulator (ARM Thumb-2, the .um2 image)',
  pitrex: 'PiTrex interpreter (ARM32)',
  sim: 'WASM simulator (the C program compiled with emscripten against the host SDK shim)',
};

function emulatorSummary() {
  const em = useEmulatorStore.getState();
  const dbg = useDebugStore.getState();
  const core: any = (window as any).emuCore;
  const v = vecx();
  const simActive = !!em.simModulePath;
  const backend: string | null = simActive ? 'sim' : em.lastLoad?.backend ?? null;
  let running = false;
  if (backend === 'sim') running = em.simStatus?.nonce === em.simModuleNonce && em.simStatus?.state === 'running';
  else if (backend === 'm6809') running = !!v?.running;
  else if (backend === 'rp2350' || backend === 'uvm2') running = dbg.state === 'running' && core?._activeTarget === backend;
  else if (backend === 'pitrex') running = dbg.state === 'running';
  return {
    panelOpen: em.panelMounted,
    backend,
    backendLabel: backend ? BACKEND_LABEL[backend] : null,
    running,
    debugState: dbg.state,
    loadedProgram: simActive ? em.simModulePath : em.lastLoad?.binPath ?? null,
    lastLoad: em.lastLoad ? { backend: em.lastLoad.backend, binPath: em.lastLoad.binPath, ok: em.lastLoad.ok, error: em.lastLoad.error ?? null } : null,
    simulator: simActive ? { module: em.simModulePath, state: em.simStatus?.nonce === em.simModuleNonce ? em.simStatus.state : 'loading', error: em.simStatus?.nonce === em.simModuleNonce ? em.simStatus.error ?? null : null } : null,
  };
}

async function waitFor(cond: () => boolean, timeoutMs: number): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (cond()) return true;
    await sleep(50);
  }
  return cond();
}

const BUILD_TARGETS: BuildTarget[] = ['m6809', 'rp2350', 'pitrex', 'uvm2'];

const api: Record<string, Fn> = {
  // ── Project ────────────────────────────────────────────────────────────
  projectInfo: () => {
    const st = useProjectStore.getState();
    const p = st.vpyProject;
    if (!p) return { open: false, workspaceRoot: st.project?.rootPath || null };
    return {
      open: true,
      projectFile: p.projectFile,
      rootDir: p.rootDir,
      name: p.config?.project?.name ?? null,
      isExternal: !!p.isExternal,
      entryPath: st.getEntryPath(),
      outputPath: st.getOutputPath(),
    };
  },

  /** Same sequence as File > Open Project / Open Recent: load, then restore tabs or open the entry file. */
  openProject: async ({ projectFile }: { projectFile: string }) => {
    const ps = useProjectStore.getState();
    const ok = await ps.openVpyProject(projectFile);
    if (!ok) throw new Error(`The IDE could not open ${projectFile} (see the IDE log for the parse error)`);
    const st = useProjectStore.getState();
    const loaded = st.vpyProject;
    let restored = 0;
    const saved = st.getProjectState(projectFile);
    if (saved && saved.openFiles.length > 0) {
      for (const uri of saved.openFiles) {
        if (await openFileDoc(uri, uriToDiskPath(uri), languageOf(uri))) restored++;
      }
      if (saved.activeFile) useEditorStore.getState().setActive(saved.activeFile);
    } else if (loaded?.config?.project?.entry) {
      // VPy entry, or the [project] entry of a C project (e.g. src/main.c); a C project
      // without one opens no file.
      const entry = st.getEntryPath();
      if (entry) {
        const norm = entry.replace(/\\/g, '/');
        const uri = /^[A-Za-z]:\//.test(norm) ? `file:///${norm}` : `file://${norm}`;
        if (await openFileDoc(uri, entry, languageOf(entry))) restored++;
      }
    }
    return {
      projectFile: loaded?.projectFile, rootDir: loaded?.rootDir,
      name: loaded?.config?.project?.name, isExternal: !!loaded?.isExternal,
      openedDocuments: restored,
    };
  },

  closeProject: ({ force }: { force?: boolean }) => {
    const ed = useEditorStore.getState();
    const dirty = ed.documents.filter((d) => d.dirty).map((d) => d.uri);
    if (dirty.length && !force) {
      throw new Error(`Unsaved documents: ${dirty.join(', ')}. Save them or call again with force=true to discard.`);
    }
    const ps = useProjectStore.getState();
    const name = ps.vpyProject?.config?.project?.name || ps.workspaceName || null;
    if (!ps.vpyProject && !ps.project?.rootPath) throw new Error('No project is open');
    (window as any).clearDebugMessages?.();
    ps.closeVpyProject();
    const all = [...ed.documents];
    for (const d of all) useEditorStore.getState().closeDocument(d.uri);
    return { closedProject: name, closedDocuments: all.length, discardedUnsaved: dirty };
  },

  // ── Editor ─────────────────────────────────────────────────────────────
  listDocuments: () => {
    const ed = useEditorStore.getState();
    return ed.documents.map((d) => docSummary(d, ed.active));
  },

  getDocument: ({ uri }: { uri: string }) => {
    const d = useEditorStore.getState().documents.find((x) => x.uri === uri);
    if (!d) return null;
    return { uri: d.uri, content: d.content, language: d.language, dirty: d.dirty, diskPath: d.diskPath ?? null, mtime: d.mtime ?? null };
  },

  /** Replace the buffer of an OPEN document (leaves it dirty, like typing). */
  setDocumentContent: ({ uri, content }: { uri: string; content: string }) => {
    const ed = useEditorStore.getState();
    if (!ed.documents.some((d) => d.uri === uri)) throw new Error(`Document not open: ${uri}`);
    ed.updateContent(uri, content);
    const d = useEditorStore.getState().documents.find((x) => x.uri === uri)!;
    return { uri, dirty: d.dirty, lines: content.split('\n').length };
  },

  /** Open (or refresh) a document as clean, backed by a file on disk. */
  openDocument: ({ uri, diskPath, content, language, mtime }: { uri: string; diskPath: string; content: string; language: DocumentModel['language']; mtime?: number }) => {
    useEditorStore.getState().openDocument({
      uri, diskPath, content, language, mtime, dirty: false, diagnostics: [], lastSavedContent: content,
    });
    return { uri };
  },

  /** If `uri` is open, replace its content and mark it clean (file was just written on disk). */
  refreshDocument: ({ uri, content, mtime }: { uri: string; content: string; mtime?: number }) => {
    const ed = useEditorStore.getState();
    if (!ed.documents.some((d) => d.uri === uri)) return { open: false };
    ed.updateContent(uri, content);
    useEditorStore.getState().markSaved(uri, mtime);
    return { open: true };
  },

  markSaved: ({ uri, mtime }: { uri: string; mtime?: number }) => {
    useEditorStore.getState().markSaved(uri, mtime);
    return { uri };
  },

  dirtyDocuments: () =>
    useEditorStore.getState().documents
      .filter((d) => d.dirty)
      .map((d) => ({ uri: d.uri, diskPath: d.diskPath ?? null, content: d.content })),

  diagnostics: ({ uri }: { uri?: string | null }) => {
    const all = useEditorStore.getState().allDiagnostics || [];
    return uri ? all.filter((d) => d.uri === uri) : all;
  },

  // ── Breakpoints (editorStore.breakpoints: Record<uri, Set<line>>) ──────
  breakpoints: () => {
    const bps = useEditorStore.getState().breakpoints || {};
    const out: Array<{ uri: string; line: number }> = [];
    for (const [uri, lines] of Object.entries(bps)) {
      for (const line of Array.from(lines || []).sort((a, b) => a - b)) out.push({ uri, line });
    }
    return out;
  },

  addBreakpoint: ({ uri, line }: { uri: string; line: number }) => {
    const ed = useEditorStore.getState();
    if (ed.breakpoints[uri]?.has(line)) return { added: false, alreadySet: true };
    ed.toggleBreakpoint(uri, line);
    return { added: true, alreadySet: false };
  },

  removeBreakpoint: ({ uri, line }: { uri: string; line: number }) => {
    const ed = useEditorStore.getState();
    if (!ed.breakpoints[uri]?.has(line)) return { removed: false };
    ed.toggleBreakpoint(uri, line);
    return { removed: true };
  },

  /** Toggle each one off (persists to the DB and unsyncs the emulator, unlike clearAllBreakpoints). */
  clearBreakpoints: () => {
    const bps = useEditorStore.getState().breakpoints || {};
    let removed = 0;
    for (const [uri, lines] of Object.entries(bps)) {
      for (const line of Array.from(lines || [])) {
        useEditorStore.getState().toggleBreakpoint(uri, line);
        removed++;
      }
    }
    return { removed };
  },

  // ── Emulator / debugger ────────────────────────────────────────────────
  emulatorState: () => {
    const v = vecx();
    const dbg = useDebugStore.getState();
    const base = {
      available: !!v,
      debugState: dbg.state,
      fps: dbg.currentFps,
      loadedRom: (window as any).CURRENT_ROM_PATH ?? null,
      currentVpyLine: dbg.currentVpyLine,
      currentVpyFile: dbg.currentVpyFile,
      backend: emulatorSummary(),
    };
    if (!v?.e6809) return { ...base, running: false, pc: null, registers: null, cycles: null };
    const registers = readRegisters();
    return { ...base, running: !!v.running, pc: registers.PC, registers, cycles: Number(v.totalCycles ?? 0) };
  },

  registers: () => readRegisters(),

  readMemory: ({ start, length }: { start: number; length: number }) => {
    const v = vecx();
    if (!v?.read8) throw new Error('Emulator not available (is the Emulator panel open?)');
    const out: number[] = [];
    for (let i = 0; i < length; i++) out.push(v.read8((start + i) & 0xffff) & 0xff);
    return out;
  },

  writeMemory: ({ address, bytes }: { address: number; bytes: number[] }) => {
    const v = vecx();
    if (!v?.write8 || !v?.read8) throw new Error('Emulator not available (is the Emulator panel open?)');
    bytes.forEach((b, i) => v.write8((address + i) & 0xffff, b & 0xff));
    return bytes.map((_, i) => v.read8((address + i) & 0xffff) & 0xff);
  },

  pdbVariables: () => useDebugStore.getState().pdbData?.variables ?? null,

  callStack: () => useDebugStore.getState().callStack || [],

  hasBreakpoints: () => Object.values(useEditorStore.getState().breakpoints || {}).some((s) => s && s.size > 0),

  setLoadingForDebug: ({ value }: { value: boolean }) => {
    useDebugStore.getState().setLoadingForDebug(!!value);
    return { loadingForDebug: !!value };
  },

  /** Forget which ROM is loaded so waitRomLoaded() only sees the NEXT load. */
  armRomLoad: () => {
    (window as any).CURRENT_ROM_PATH = null;
    return true;
  },

  /**
   * Wait until the Emulator panel has finished loading `binPath` (it sets CURRENT_ROM_PATH
   * last). `binPath: null` waits for ANY ROM to load after armRomLoad().
   */
  waitRomLoaded: async ({ binPath, timeoutMs }: { binPath: string | null; timeoutMs: number }) => {
    const deadline = Date.now() + Math.max(100, timeoutMs);
    while (Date.now() < deadline) {
      const cur = (window as any).CURRENT_ROM_PATH;
      if (binPath === null ? !!cur : cur === binPath) return { loaded: true, current: cur };
      await sleep(50);
    }
    return { loaded: false, current: (window as any).CURRENT_ROM_PATH ?? null };
  },

  /** Start/resume through the Emulator panel's own handler (same as the debugger's Continue). */
  startEmulator: async () => {
    const v = vecx();
    if (!v) throw new Error('Emulator not available (is the Emulator panel open?)');
    window.postMessage({ type: 'debug-continue' }, '*');
    for (let i = 0; i < 20 && !v.running; i++) await sleep(25);
    return { running: !!v.running, debugState: useDebugStore.getState().state };
  },

  stopEmulator: async () => {
    const v = vecx();
    if (!v) throw new Error('Emulator not available (is the Emulator panel open?)');
    useDebugStore.getState().stop(); // posts 'debug-stop': stop + reset in the Emulator panel
    for (let i = 0; i < 20 && v.running; i++) await sleep(25);
    if (v.running) v.stop?.();
    return { running: !!v.running, debugState: useDebugStore.getState().state };
  },

  pauseEmulator: async () => {
    const v = vecx();
    if (!v) throw new Error('Emulator not available (is the Emulator panel open?)');
    useDebugStore.getState().pause(); // posts 'debug-pause'
    for (let i = 0; i < 20 && v.running; i++) await sleep(25);
    return { running: !!v.running, debugState: useDebugStore.getState().state };
  },

  /** Run an IDE command exactly like a menu item / shortcut (commandExec via 'vpy-command'). */
  command: ({ id }: { id: string }) => {
    window.dispatchEvent(new CustomEvent('vpy-command', { detail: { command: id } }));
    return { dispatched: id };
  },

  // ── Settings / IDE context ──────────────────────────────────────────────
  /** Renderer half of ide_get_context: build settings + emulator. */
  ideState: () => {
    const st = useSettings.getState();
    const ps = useProjectStore.getState();
    return {
      buildTarget: st.buildTarget,
      rp2350BuildMode: st.rp2350BuildMode,
      rp2350FlashMethod: st.rp2350FlashMethod,
      pitrexCopyToSD: st.pitrexCopyToSD,
      uvm2CopyToSD: st.uvm2CopyToSD,
      projectTarget: ps.vpyProject?.target ?? null,
      emulator: emulatorSummary(),
      buildRunnerReady: !!buildRunner,
    };
  },

  /** Same store setter the Settings panel's target selector uses. */
  setBuildTarget: ({ target }: { target: string }) => {
    if (!BUILD_TARGETS.includes(target as BuildTarget)) {
      throw new Error(`Unknown build target "${target}" (expected one of ${BUILD_TARGETS.join(', ')})`);
    }
    const previous = useSettings.getState().buildTarget;
    useSettings.getState().setBuildTarget(target as BuildTarget);
    return { previous, buildTarget: useSettings.getState().buildTarget };
  },

  emulatorSummary: () => emulatorSummary(),

  /**
   * F7 / F5 / Shift+F5 / Shift+F7, awaited: runs main.tsx's handleBuild (exactly what the
   * key runs), then waits for the Emulator panel to load/start what it produced, and
   * returns the outcome, the emulator state and the build output of THIS build.
   */
  runBuild: async ({ mode }: { mode: BuildMode }) => {
    if (!['build', 'run', 'simulate', 'build_simulator'].includes(mode)) {
      throw new Error(`Unknown mode "${mode}" (expected build, run, simulate or build_simulator)`);
    }
    if (!buildRunner) throw new Error('The IDE window is not ready to build yet (no build runner registered); try again in a moment');
    const notes: string[] = [];
    const outStart = outputSeq;
    const em0 = useEmulatorStore.getState();
    const loadSeq0 = em0.lastLoad?.seq ?? 0;
    const simNonce0 = em0.simModuleNonce;

    // A run needs the Emulator panel: it is the only thing that loads the program.
    if ((mode === 'run' || mode === 'simulate') && !em0.panelMounted) {
      ensureComponent('emulator');
      if (await waitFor(() => useEmulatorStore.getState().panelMounted, 4000)) notes.push('Opened the Emulator panel.');
      else notes.push('The Emulator panel is not open and could not be opened: the program was built but nothing will run it.');
    }

    const started = Date.now();
    const outcome = await buildRunner(mode);
    const buildMs = Date.now() - started;

    let emulatorWait: { waitedFor: string; timedOut: boolean } | null = null;
    if (outcome.ok && outcome.launch === 'sim') {
      const ok = await waitFor(() => {
        const em = useEmulatorStore.getState();
        return em.simModuleNonce > simNonce0 && em.simStatus?.nonce === em.simModuleNonce && em.simStatus.state !== 'loading';
      }, 60000);
      emulatorWait = { waitedFor: 'the WASM simulator to load', timedOut: !ok };
    } else if (outcome.ok && outcome.launch === 'emulator') {
      const ok = await waitFor(() => (useEmulatorStore.getState().lastLoad?.seq ?? 0) > loadSeq0, 20000);
      emulatorWait = { waitedFor: 'the Emulator panel to load the program', timedOut: !ok };
      // JSVecX restarts 200 ms after a load (vecx.reset); give it a moment to report running.
      if (ok && useEmulatorStore.getState().lastLoad?.backend === 'm6809') await waitFor(() => !!vecx()?.running, 2000);
    }

    return {
      mode,
      ...outcome,
      notes: [...(outcome.notes || []), ...notes],
      buildMs,
      emulatorWait,
      emulator: emulatorSummary(),
      output: outputSince(outStart, 8000),
    };
  },

  /** The document `debug.start` would compile (active document). */
  activeDocument: () => {
    const ed = useEditorStore.getState();
    const d = ed.documents.find((x) => x.uri === ed.active);
    return d ? docSummary(d, ed.active) : null;
  },
};

async function invoke(name: string, args: unknown): Promise<BridgeResult> {
  const fn = Object.prototype.hasOwnProperty.call(api, name) ? api[name] : undefined;
  if (!fn) return { ok: false, error: `Unknown MCP bridge function: ${name}` };
  try {
    return { ok: true, value: await fn(args ?? {}) };
  } catch (e: any) {
    return { ok: false, error: e?.message || String(e) };
  }
}

if (typeof window !== 'undefined') {
  (window as any).__mcpBridge__ = Object.freeze({ version: 1, invoke });
}

export {};
