// MCP Types - Model Context Protocol type definitions
// Based on MCP specification for tool-based protocol

export interface MCPRequest {
  jsonrpc: '2.0';
  id: string | number | null;
  method: string;
  params?: Record<string, any>;
}

export interface MCPResponse {
  jsonrpc: '2.0';
  id: string | number | null;
  result?: any;
  error?: MCPError;
}

export interface MCPError {
  code: number;
  message: string;
  data?: any;
}

export interface MCPNotification {
  jsonrpc: '2.0';
  method: string;
  params?: Record<string, any>;
}

// Tool definition. `name` is the IDE method ("editor/read_document"); the
// MCP-safe name exposed to external clients ("editor_read_document") is derived
// from it by toolNameForMethod() in server.ts.
export interface MCPTool {
  name: string;
  description: string;
  inputSchema: {
    type: 'object';
    properties: Record<string, any>;
    required?: string[];
  };
}

// Tool categories we'll implement
export namespace EditorTools {
  export interface ListDocumentsParams {}
  export interface ListDocumentsResult {
    documents: Array<{
      uri: string;
      language: string;
      dirty: boolean;
      content?: string; // Only if requested
    }>;
  }

  export interface ReadDocumentParams {
    uri: string;
  }
  export interface ReadDocumentResult {
    uri: string;
    content: string;
    language: string;
    dirty: boolean;
  }

  export interface WriteDocumentParams {
    uri: string;
    content: string;
  }
  export interface WriteDocumentResult {
    success: boolean;
  }

  export interface GetDiagnosticsParams {
    uri?: string; // If omitted, return all diagnostics
  }
  export interface GetDiagnosticsResult {
    diagnostics: Array<{
      uri: string;
      line: number;
      column: number;
      severity: 'error' | 'warning' | 'info' | 'hint';
      message: string;
      source?: string;
    }>;
  }

  export interface GotoLocationParams {
    uri: string;
    line: number;
    column: number;
  }
  export interface GotoLocationResult {
    success: boolean;
  }
}

export namespace CompilerTools {
  export interface BuildParams {
    entryFile: string;
  }
  export interface BuildResult {
    success: boolean;
    outputPath?: string;
    pdbPath?: string;
    asmPath?: string;
    errors?: Array<{
      file: string;
      line: number;
      column: number;
      message: string;
    }>;
  }

  export interface GetErrorsParams {}
  export interface GetErrorsResult {
    errors: Array<{
      file: string;
      line: number;
      column: number;
      message: string;
    }>;
  }

  export interface GetAsmParams {
    vpyFile: string;
  }
  export interface GetAsmResult {
    asmPath: string;
    asmContent: string;
  }

  export interface GetPdbParams {
    vpyFile: string;
  }
  export interface GetPdbResult {
    pdbPath: string;
    pdb: {
      version: string;
      source: string;
      binary: string;
      symbols: Record<string, string>;
      lineMap: Record<string, string>;
      functions?: Record<string, any>;
    };
  }
}

export namespace EmulatorTools {
  export interface RunParams {
    romPath: string;
    breakOnEntry?: boolean;
  }
  export interface RunResult {
    success: boolean;
    state: 'running' | 'paused' | 'stopped';
  }

  export interface StopParams {}
  export interface StopResult {
    success: boolean;
  }

  export interface GetStateParams {}
  export interface GetStateResult {
    state: 'running' | 'paused' | 'stopped';
    pc: number;
    cycles: number;
    fps?: number;
    registers: Record<string, number>;
  }

  export interface ReadMemoryParams {
    address: number;
    length: number;
  }
  export interface ReadMemoryResult {
    address: number;
    data: number[]; // Bytes
  }

  export interface GetMetricsParams {}
  export interface GetMetricsResult {
    cycles: number;
    fps: number;
    frameCount: number;
    biosCallsCount: number;
  }
}

export namespace DebuggerTools {
  export interface AddBreakpointParams {
    uri: string;
    line: number;
  }
  export interface AddBreakpointResult {
    success: boolean;
  }

  export interface RemoveBreakpointParams {
    uri: string;
    line: number;
  }
  export interface RemoveBreakpointResult {
    success: boolean;
  }

  export interface StepParams {
    type: 'over' | 'into' | 'out';
  }
  export interface StepResult {
    success: boolean;
    pc: number;
    line?: number;
  }

  export interface GetCallstackParams {}
  export interface GetCallstackResult {
    frames: Array<{
      function: string;
      line: number | null;
      address: string;
      type: 'vpy' | 'native' | 'bios';
    }>;
  }

  export interface InspectVariableParams {
    name: string;
  }
  export interface InspectVariableResult {
    name: string;
    value: any;
    type: string;
    address?: string;
  }
}

export namespace ProjectTools {
  export interface GetStructureParams {}
  export interface GetStructureResult {
    root: string;
    name: string;
    files: Array<{
      path: string;
      type: 'file' | 'directory';
      language?: string;
    }>;
  }

  export interface ListFilesParams {
    pattern?: string; // Glob pattern
  }
  export interface ListFilesResult {
    files: string[];
  }

  export interface ReadFileParams {
    path: string;
  }
  export interface ReadFileResult {
    path: string;
    content: string;
  }

  export interface WriteFileParams {
    path: string;
    content: string;
  }
  export interface WriteFileResult {
    success: boolean;
  }
}

export namespace ResourceTools {
  export interface ListParams {
    type?: 'vec' | 'vmus'; // Filter by type
  }
  export interface ListResult {
    resources: Array<{
      path: string;
      type: 'vec' | 'vmus';
      name: string;
    }>;
  }

  export interface ReadVecParams {
    path: string;
  }
  export interface ReadVecResult {
    path: string;
    resource: any; // VecResource structure
  }

  export interface WriteVecParams {
    path: string;
    resource: any;
  }
  export interface WriteVecResult {
    success: boolean;
  }

  export interface ReadVmusParams {
    path: string;
  }
  export interface ReadVmusResult {
    path: string;
    resource: any; // MusicResource structure
  }

  export interface WriteVmusParams {
    path: string;
    resource: any;
  }
  export interface WriteVmusResult {
    success: boolean;
  }
}

// Standard error codes
export const ErrorCodes = {
  ParseError: -32700,
  InvalidRequest: -32600,
  MethodNotFound: -32601,
  InvalidParams: -32602,
  InternalError: -32603,
  // Custom errors
  FileNotFound: -32001,
  CompilationFailed: -32002,
  EmulatorNotRunning: -32003,
  BreakpointFailed: -32004,
  Unauthorized: -32010,
  ToolFailed: -32011,
} as const;
