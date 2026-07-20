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

// Electron API types
interface Window {
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
