/// <reference types="vite/client" />
// Allow importing Monaco worker bundles with ?worker query
declare module 'monaco-editor/esm/vs/editor/editor.worker?worker' {
  const WorkerFactory: { new(): Worker };
  export default WorkerFactory;
}

// PyPilot Session Management Types
interface PyPilotSession {
  id: number;
  projectPath: string;
  name: string;
  createdAt: string;
  lastActivity: string;
  isActive: boolean;
}

interface PyPilotMessage {
  id: number;
  sessionId: number;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: string;
}

// Backend response wrappers
interface PyPilotResponse<T> {
  success: boolean;
  error?: string;
  data?: T;
}

interface PyPilotAPI {
  createSession: (projectPath: string, name?: string) => Promise<{ success: boolean; session?: PyPilotSession; error?: string }>;
  getSessions: (projectPath: string) => Promise<{ success: boolean; sessions?: PyPilotSession[]; error?: string }>;
  getActiveSession: (projectPath: string) => Promise<{ success: boolean; session?: PyPilotSession | null; error?: string }>;
  switchSession: (sessionId: number) => Promise<{ success: boolean; session?: PyPilotSession; error?: string }>;
  renameSession: (sessionId: number, newName: string) => Promise<{ success: boolean; error?: string }>;
  deleteSession: (sessionId: number) => Promise<{ success: boolean; error?: string }>;
  saveMessage: (sessionId: number, role: 'user' | 'assistant' | 'system', content: string, metadata?: any) => Promise<{ success: boolean; message?: PyPilotMessage; error?: string }>;
  getMessages: (sessionId: number) => Promise<{ success: boolean; messages?: PyPilotMessage[]; error?: string }>;
  clearMessages: (sessionId: number) => Promise<{ success: boolean; error?: string }>;
  getMessageCount: (sessionId: number) => Promise<{ success: boolean; count?: number; error?: string }>;
}

// Electron main-process API bridge (exposed via preload as window.electronAPI).
// Only the members needed by strongly-typed call sites are declared here; the
// index signature keeps the many existing `(window as any).electronAPI` uses valid.
interface ElectronAPI {
  // Import an external C/C++ project: opens a folder picker (unless `dir` is
  // given), scaffolds a `<name>.cvproj` TOML manifest and returns its path.
  importCProject: (args?: { dir?: string }) => Promise<{
    ok?: boolean;
    manifestPath?: string;
    existed?: boolean;
    detectedTarget?: string | null;
    canceled?: boolean;
    error?: string;
  }>;
  // Run an external C/C++ project's own build command (output streams over the
  // existing run://stdout / run://stderr channels). When deploy=true it copies
  // the resulting artifact + extra files to the PiTrex SD card.
  runBuildExternal: (args: {
    manifestPath: string;
    deploy?: boolean;
    sdPath?: string;
    target?: 'pitrex' | 'rp2350';
    preview?: boolean;
  }) => Promise<{
    ok?: boolean;
    artifactPath?: string;
    error?: string;
    detail?: string;
  }>;
  [key: string]: any;
}

// SDK versions (uvmc2-sdk), exposed via preload as window.sdk. Versions are
// downloaded per tag into <root>/<tag>/; each project pins one ([sdk] version).
interface SdkProgress {
  tag: string;
  phase: 'download' | 'extract' | 'done';
  received: number;
  total: number | null;
}

interface SdkListResult {
  installed: string[];       // newest first
  remote: string[] | null;   // GitHub tags, newest first; null when offline
  latest: string | null;
  root: string;
}

interface SdkAPI {
  list: (args?: { refresh?: boolean }) => Promise<SdkListResult>;
  install: (tag: string) => Promise<{ ok: true; dir: string } | { ok: false; error: string }>;
  onProgress: (cb: (p: SdkProgress) => void) => () => void;
  // A project without a version is pinned to the latest tag by this call
  // (pinned: true means it just wrote the project file).
  getProjectVersion: (projectFile: string) => Promise<
    { ok: true; version: string; pinned: boolean; installed: boolean } | { ok: false; error: string }>;
  setProjectVersion: (projectFile: string, tag: string) => Promise<{ ok: true } | { ok: false; error: string }>;
  // Arm GNU Toolchain (uvm2 builds; never downloaded), found the same way the build finds it.
  toolchain: () => Promise<ToolchainStatus>;
  openToolchainDownload: () => Promise<void>;
}

interface ToolchainStatus {
  found: { dir: string; version: string | null; source: string } | null;
  candidates: Array<{ dir: string; source: string; problem: string | null }>;
}

// Integrated terminal (preload `window.terminal`, main-process side in electron/src/terminal.ts)
interface TerminalAPI {
  /** process.platform of the host ('darwin' | 'linux' | 'win32' ...). */
  platform: string;
  create: (opts: { cwd?: string; cols: number; rows: number; command?: string }) =>
    Promise<{ id: number; shell: string } | { error: string }>;
  write: (id: number, data: string) => void;
  resize: (id: number, cols: number, rows: number) => void;
  kill: (id: number) => Promise<{ ok: boolean }>;
  openLink: (url: string) => Promise<{ ok: boolean }>;
  /** Saves the clipboard image as a temporary PNG; path is null when there is no image. */
  pasteImage: () => Promise<{ path: string | null }>;
  /** Absolute path of a file dropped from the OS (null for in-memory files). */
  pathForFile: (file: File) => string | null;
  /** Batched PTY output. Returns an unsubscribe function. */
  onData: (cb: (id: number, data: string) => void) => () => void;
  /** The shell exited on its own. Returns an unsubscribe function. */
  onExit: (cb: (id: number, code: number) => void) => () => void;
}

// Electron API types
interface Window {
  sdk?: SdkAPI;
  terminal?: TerminalAPI;
  electronAPI?: ElectronAPI;
  electron: {
    runCommand: (command: string) => Promise<{
      success: boolean;
      output: string;
      exitCode: number;
    }>;
  };
  aiProxy: {
    request: (request: {
      provider: 'anthropic' | 'deepseek';
      apiKey: string;
      endpoint: string;
      method: string;
      body: any;
      headers?: Record<string, string>;
    }) => Promise<{
      success: boolean;
      data?: any;
      error?: string;
      status?: number;
    }>;
  };
  pypilot: PyPilotAPI;
  videoExport?: {
    saveMp4: (args: { webmBytes: ArrayBuffer | Uint8Array; name?: string }) =>
      Promise<{ path: string } | { canceled: true } | { error: string }>;
  };
  movie?: {
    convert: (args: { kind: 'video' | 'audio'; inputPath: string; outPath: string; opts?: Record<string, any> }) =>
      Promise<{ ok: true; outPath: string; stdout?: string; stderr?: string } | { error: string }>;
    pickFile: (args: { kind: 'video' | 'audio' }) =>
      Promise<{ path: string; name: string } | null>;
    previewFrame: (args: { videoPath: string; time: number; opts?: Record<string, any> }) =>
      Promise<
        { segments: Array<{ x0: number; y0: number; x1: number; y1: number; i: number }>; width: number; height: number; originalPng: string }
        | { error: string }
      >;
    onProgress: (cb: (line: string) => void) => () => void;
  };
}
