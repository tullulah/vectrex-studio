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

// Electron API types
interface Window {
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
