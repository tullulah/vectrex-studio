// Domain model interfaces for the VPy IDE

export interface FileNode {
  path: string;
  name: string;
  isDir: boolean;
  children?: FileNode[];
}

export interface Project {
  rootPath: string;
  files: FileNode[];
}

export interface DocumentModel {
  uri: string;
  language: 'vpy' | 'c' | 'cpp' | 'json' | 'plaintext' | 'asm' | 'javascript' | 'typescript' | 'markdown';
  content: string;
  dirty: boolean;
  diagnostics: DiagnosticModel[];
  // Absolute path on disk if backed by a real file. Undefined for in-memory docs.
  diskPath?: string;
  // Last known modification time (ms epoch) from filesystem when loaded/saved.
  mtime?: number;
  // (Optional) snapshot of content at last save/load for advanced dirty detection.
  lastSavedContent?: string;
  // A pinned tab sits at the front of the tab bar, and Close Others / Close All leave it open.
  pinned?: boolean;
}

export interface DiagnosticModel {
  message: string;
  severity: 'error' | 'warning' | 'info';
  line: number;
  column: number;
  source?: string; // 'lsp', 'compiler', etc.
}

export interface DebugState {
  registers: Record<string,string>;
  pc: number;
  cycles: number;
  variables: Array<{ name: string; value: string }>;
  constants: Array<{ name: string; value: string }>;
}

export interface EmulatorState {
  status: 'running' | 'stopped' | 'paused';
  lastFrameTimestamp?: number;
}
