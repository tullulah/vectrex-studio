// MCP Server - IDE-side tool registry and handlers.
//
// Two callers reach handleRequest():
//   * PyPilot (in-process, ipcMain 'mcp:request'), which lists tools with
//     'tools/list' (IDE method names such as "editor/read_document") and calls
//     them by method or by underscore name;
//   * the stdio MCP server (ide/mcp-server/server.js) over the authenticated TCP
//     bridge (tcpServer.ts), which lists tools with 'ide/list_tools' (MCP-safe
//     names + the exact IDE method to call) so the two lists can never drift.
//
// Every tool either does what it says and returns a result, or throws. Thrown
// errors become JSON-RPC errors here and `isError` tool results in server.js.
//
// Renderer state is reached ONLY through window.__mcpBridge__
// (ide/frontend/src/services/mcpBridge.ts); arguments are passed as JSON, never
// interpolated into script text.

import { BrowserWindow } from 'electron';
import * as fs from 'fs/promises';
import * as path from 'path';
import { MCPRequest, MCPResponse, MCPTool, ErrorCodes } from './types.js';
import {
  fileUriToPath, findProjectFile, pathToFileUri, resolveInsideRoot, walkProjectTree,
} from './paths.js';
import { IDE_INSTRUCTIONS } from './instructions.js';
import {
  ASSET_SPECS, AssetSpec, compileCheck, makefileCompilesAssets, makefileCompilesExt, missingReferences, newAssetName,
  normaliseName, projectLang, resolveVpyCli, scanProjectAssets, specFor, structuralErrors, summarizeAsset,
} from './assets.js';
import { ApiReference, compactApi, cReference, filterEntries, howTo, topicsOf, vpyReference } from './apiReference.js';

type MCPToolHandler = (params: any) => Promise<any>;

/** MCP-safe tool name for an IDE method: "editor/read_document" -> "editor_read_document". */
export function toolNameForMethod(method: string): string {
  return method.replace(/\//g, '_');
}

const TOOL_NAME_RE = /^[a-zA-Z0-9_-]{1,64}$/;

// ── Small helpers ─────────────────────────────────────────────────────────

const RAM_START = 0xc800;
const RAM_END = 0xcfff;
const MAX_READ_FILE = 2 * 1024 * 1024;
const MAX_ROM = 8 * 1024 * 1024;

function hex(n: number, digits: number): string {
  return '0x' + (n >>> 0).toString(16).toUpperCase().padStart(digits, '0');
}

/** Accepts 49152, "49152", "0xC000", "$C000". */
function parseNumber(v: unknown, name: string): number {
  if (typeof v === 'number' && Number.isFinite(v) && Number.isInteger(v)) return v;
  if (typeof v === 'string') {
    const s = v.trim();
    if (/^0x[0-9a-f]+$/i.test(s)) return parseInt(s.slice(2), 16);
    if (/^\$[0-9a-f]+$/i.test(s)) return parseInt(s.slice(1), 16);
    if (/^-?\d+$/.test(s)) return parseInt(s, 10);
  }
  throw new Error(`"${name}" must be an integer (decimal, 0xHEX or $HEX), got ${JSON.stringify(v)}`);
}

function optNumber(v: unknown, name: string, dflt: number): number {
  return v === undefined || v === null || v === '' ? dflt : parseNumber(v, name);
}

function requireString(v: unknown, name: string): string {
  if (typeof v !== 'string' || !v.length) throw new Error(`"${name}" is required and must be a non-empty string`);
  return v;
}

function requirePositiveInt(v: unknown, name: string): number {
  const n = parseNumber(v, name);
  if (n < 1) throw new Error(`"${name}" must be >= 1 (1-indexed), got ${n}`);
  return n;
}

/** Readable without side effects: cartridge ROM, RAM, BIOS ROM. The VIA ($D000) is excluded on purpose. */
function isReadableAddress(a: number): boolean {
  return (a >= 0x0000 && a <= 0x7fff) || (a >= RAM_START && a <= RAM_END) || (a >= 0xe000 && a <= 0xffff);
}

function assertReadableRange(start: number, length: number) {
  for (const a of [start, start + length - 1]) {
    if (a < 0 || a > 0xffff) throw new Error(`Address ${hex(a, 4)} is outside the 16-bit address space`);
  }
  for (let a = start; a < start + length; a++) {
    if (!isReadableAddress(a)) {
      throw new Error(`Address ${hex(a, 4)} is not readable via MCP (allowed: $0000-$7FFF cartridge, $C800-$CFFF RAM, $E000-$FFFF BIOS; the VIA has read side effects)`);
    }
  }
}

function languageForPath(p: string): string {
  const ext = path.extname(p).slice(1).toLowerCase();
  switch (ext) {
    case 'vpy': return 'vpy';
    case 'c': return 'c';
    case 'cpp': case 'cc': case 'cxx': case 'h': case 'hpp': return 'cpp';
    case 'asm': case 's': return 'asm';
    case 'json': case 'vec': case 'vmus': case 'vsfx': case 'vanim': case 'vplay': case 'vinstr': case 'venemy': case 'vmov':
    case 'vrec': case 'vsmp': case 'vmesh': case 'vscene': return 'json';
    case 'js': return 'javascript';
    case 'ts': return 'typescript';
    case 'md': return 'markdown';
    default: return 'plaintext';
  }
}

function isFileUri(s: string) { return /^file:\/\//i.test(s); }
function hasOtherScheme(s: string) { return /^[a-z][a-z0-9+.-]*:/i.test(s) && !/^[a-z]:[\\/]/i.test(s) && !isFileUri(s); }

function samePath(a: string, b: string): boolean {
  const na = path.resolve(a), nb = path.resolve(b);
  return process.platform === 'win32' || process.platform === 'darwin'
    ? na.toLowerCase() === nb.toLowerCase()
    : na === nb;
}

interface ProjectInfo {
  open: boolean;
  projectFile: string;
  rootDir: string;
  name: string | null;
  isExternal: boolean;
  entryPath: string | null;
  outputPath: string | null;
}

interface DocInfo { uri: string; language: string; dirty: boolean; diskPath: string | null; active?: boolean }

// ── Server ────────────────────────────────────────────────────────────────

export class MCPServer {
  private tools: Map<string, MCPToolHandler> = new Map();
  private toolSchemas: Map<string, MCPTool> = new Map();
  private nameToMethod: Map<string, string> = new Map();
  private mainWindow: BrowserWindow | null = null;
  private buildInFlight = false;
  private lastBuild: { at: string; ok: boolean; binPath?: string; errors?: Array<{ line: number; column: number; message: string }>; stderrTail?: string } | null = null;

  constructor() {
    this.registerAllTools();
  }

  setMainWindow(window: BrowserWindow) {
    this.mainWindow = window;
  }

  private registerTool(name: string, handler: MCPToolHandler, schema: MCPTool) {
    const toolName = toolNameForMethod(name);
    if (!TOOL_NAME_RE.test(toolName)) throw new Error(`Invalid MCP tool name: ${toolName}`);
    if (this.tools.has(name) || this.nameToMethod.has(toolName)) throw new Error(`Duplicate MCP tool: ${name}`);
    this.tools.set(name, handler);
    this.toolSchemas.set(name, { ...schema, name });
    this.nameToMethod.set(toolName, name);
  }

  /** Registered tools with their MCP-safe name and the IDE method that implements them. */
  listExternalTools(): Array<{ name: string; method: string; description: string; inputSchema: MCPTool['inputSchema'] }> {
    return Array.from(this.toolSchemas.values()).map((t) => ({
      name: toolNameForMethod(t.name), method: t.name, description: t.description, inputSchema: t.inputSchema,
    }));
  }

  // Handle incoming JSON-RPC request
  async handleRequest(request: MCPRequest): Promise<MCPResponse> {
    const id = request?.id ?? null;
    try {
      if (!request || typeof request.method !== 'string') {
        return this.createError(id, ErrorCodes.InvalidRequest, 'Invalid request: missing "method"');
      }
      if (request.method === 'tools/list') {
        return this.createResponse(id, { tools: Array.from(this.toolSchemas.values()) });
      }
      if (request.method === 'ide/list_tools') {
        return this.createResponse(id, { tools: this.listExternalTools() });
      }
      if (request.method === 'ide/ping') {
        return this.createResponse(id, { ok: true, window: !!this.mainWindow && !this.mainWindow.isDestroyed() });
      }
      if (request.method === 'ide/get_instructions') {
        return this.createResponse(id, { instructions: IDE_INSTRUCTIONS });
      }

      // Exact IDE method ("editor/read_document") or MCP tool name ("editor_read_document").
      const method = this.tools.has(request.method) ? request.method : this.nameToMethod.get(request.method);
      const handler = method ? this.tools.get(method) : undefined;
      if (!handler) {
        return this.createError(id, ErrorCodes.MethodNotFound, `Method not found: ${request.method}`);
      }
      const params = request.params && typeof request.params === 'object' ? request.params : {};
      const result = await handler(params);
      return this.createResponse(id, result);
    } catch (error: any) {
      const message = error?.message || String(error);
      console.warn(`[MCP] ${request?.method} failed: ${message}`);
      return this.createError(id, ErrorCodes.ToolFailed, message);
    }
  }

  private createResponse(id: string | number | null, result: any): MCPResponse {
    return { jsonrpc: '2.0', id, result: result === undefined ? null : result };
  }

  private createError(id: string | number | null, code: number, message: string, data?: any): MCPResponse {
    return { jsonrpc: '2.0', id, error: data === undefined ? { code, message } : { code, message, data } };
  }

  // ── Renderer bridge ─────────────────────────────────────────────────────

  private requireWindow(): BrowserWindow {
    const w = this.mainWindow;
    if (!w || w.isDestroyed()) throw new Error('The Vectrex Studio window is not available');
    return w;
  }

  /** Call window.__mcpBridge__.invoke(fn, args). Args travel as JSON — never interpolated raw. */
  private async bridge<T = any>(fn: string, args: Record<string, unknown> = {}): Promise<T> {
    const win = this.requireWindow();
    const script =
      '(function(){var b=window.__mcpBridge__;' +
      "if(!b||typeof b.invoke!=='function')return {ok:false,error:'MCP bridge is not loaded in the renderer (rebuild ide/frontend)'};" +
      `return b.invoke(${JSON.stringify(fn)},${JSON.stringify(args)});})()`;
    const r: any = await win.webContents.executeJavaScript(script, true);
    if (!r || typeof r !== 'object') throw new Error(`Renderer returned no result for ${fn}`);
    if (!r.ok) throw new Error(r.error || `${fn} failed`);
    return r.value as T;
  }

  private async requireProject(): Promise<ProjectInfo> {
    const info = await this.bridge<ProjectInfo>('projectInfo');
    if (!info?.open) throw new Error('No project is open. Use project_open (or project_create) first.');
    return info;
  }

  private async listDocs(): Promise<DocInfo[]> {
    return this.bridge<DocInfo[]>('listDocuments');
  }

  /** Find an OPEN document by URI, absolute/relative path, or unique file name. */
  private async resolveOpenDoc(uriOrPath: unknown): Promise<DocInfo> {
    const target = requireString(uriOrPath, 'uri');
    const docs = await this.listDocs();
    const exact = docs.find((d) => d.uri === target);
    if (exact) return exact;

    let abs: string | null = null;
    if (isFileUri(target)) abs = fileUriToPath(target);
    else if (path.isAbsolute(target)) abs = target;
    else if (!hasOtherScheme(target)) {
      const info = await this.bridge<ProjectInfo>('projectInfo');
      if (info?.open && /[\\/]/.test(target)) abs = path.resolve(info.rootDir, target);
    }
    if (abs) {
      const byPath = docs.find((d) => {
        const p = d.diskPath || (isFileUri(d.uri) ? fileUriToPath(d.uri) : null);
        return p ? samePath(p, abs!) : false;
      });
      if (byPath) return byPath;
    }
    if (!isFileUri(target) && !hasOtherScheme(target)) {
      const suffix = '/' + target.replace(/\\/g, '/').replace(/^\.?\//, '');
      const matches = docs.filter((d) => d.uri.endsWith(suffix));
      if (matches.length === 1) return matches[0];
      if (matches.length > 1) throw new Error(`"${target}" is ambiguous; open documents matching it: ${matches.map((d) => d.uri).join(', ')}`);
    }
    throw new Error(
      `Document not open: ${target}. Open documents: ${JSON.stringify(docs.map((d) => d.uri))}. ` +
      'Use editor_write_document to create/open a file, or project_read_file to read one from disk.'
    );
  }

  private async getDoc(uri: string): Promise<{ uri: string; content: string; language: string; dirty: boolean; diskPath: string | null; mtime: number | null }> {
    const d = await this.bridge<any>('getDocument', { uri });
    if (!d) throw new Error(`Document not open: ${uri}`);
    return d;
  }

  /** After writing `absPath` on disk: refresh its tab if open, else optionally open it. */
  private async syncEditorWithFile(absPath: string, content: string, mtime: number, openIfClosed: boolean): Promise<{ uri: string; opened: boolean; refreshed: boolean }> {
    const docs = await this.listDocs();
    const open = docs.find((d) => {
      const p = d.diskPath || (isFileUri(d.uri) ? fileUriToPath(d.uri) : null);
      return p ? samePath(p, absPath) : false;
    });
    if (open) {
      await this.bridge('refreshDocument', { uri: open.uri, content, mtime });
      return { uri: open.uri, opened: false, refreshed: true };
    }
    const uri = pathToFileUri(absPath);
    if (openIfClosed) {
      await this.bridge('openDocument', { uri, diskPath: absPath, content, language: languageForPath(absPath), mtime });
      return { uri, opened: true, refreshed: false };
    }
    return { uri, opened: false, refreshed: false };
  }

  // ── Tool registry ───────────────────────────────────────────────────────

  private registerAllTools() {
    const noParams = { type: 'object' as const, properties: {} };

    // Editor tools
    this.registerTool('editor/list_documents', this.listDocuments.bind(this), {
      name: 'editor/list_documents',
      description: 'List the documents open in the editor (uri, language, dirty flag, path on disk, which one is active).',
      inputSchema: noParams,
    });

    this.registerTool('editor/read_document', this.readDocument.bind(this), {
      name: 'editor/read_document',
      description: 'Read the CURRENT editor buffer of an open document (including unsaved changes). The document must be open; to read any file from disk use project_read_file.',
      inputSchema: {
        type: 'object',
        properties: {
          uri: { type: 'string', description: 'file:// URI, path, or unique file name of an open document' },
        },
        required: ['uri'],
      },
    });

    this.registerTool('editor/write_document', this.writeDocument.bind(this), {
      name: 'editor/write_document',
      description: 'Create or overwrite a file inside the open project, write it to disk and open/refresh it in the editor (clean, not dirty). Accepts a file:// URI inside the project, a path relative to the project root ("src/game.vpy"), or a bare file name (".vpy" names go to src/, others to the project root). For .vec/.vmus/.vsfx prefer project_create_vector/music/sfx, which validate the JSON. VPy language rules: call get_project_docs.',
      inputSchema: {
        type: 'object',
        properties: {
          uri: { type: 'string', description: 'Target file: file:// URI inside the project, project-relative path, or file name' },
          content: { type: 'string', description: 'Complete file content' },
        },
        required: ['uri', 'content'],
      },
    });

    this.registerTool('editor/save_document', this.saveDocument.bind(this), {
      name: 'editor/save_document',
      description: 'Save an open document\'s buffer to disk and mark it clean. Use after editor_replace_range / insert_at / delete_range so the compiler sees the change (compiler_build also auto-saves dirty project sources). Only files inside the open project can be saved.',
      inputSchema: {
        type: 'object',
        properties: {
          uri: { type: 'string', description: 'file:// URI, path, or unique file name of an open document' },
        },
        required: ['uri'],
      },
    });

    this.registerTool('editor/get_diagnostics', this.getDiagnostics.bind(this), {
      name: 'editor/get_diagnostics',
      description: 'Get LSP/compiler diagnostics of open documents (all of them, or one document).',
      inputSchema: {
        type: 'object',
        properties: {
          uri: { type: 'string', description: 'Open document (optional; all documents if omitted)' },
        },
      },
    });

    this.registerTool('editor/replace_range', this.replaceRange.bind(this), {
      name: 'editor/replace_range',
      description: 'Replace a range of an OPEN document\'s buffer, by 1-indexed LINES and columns (end column exclusive). Omit startColumn to start at the beginning of startLine; omit endColumn to replace through the end of endLine. Leaves the document dirty — call editor_save_document afterwards. For whole-file replacement use editor_write_document.',
      inputSchema: {
        type: 'object',
        properties: {
          uri: { type: 'string', description: 'Open document' },
          startLine: { type: 'number', description: 'Start line (1-indexed)' },
          startColumn: { type: 'number', description: 'Start column (1-indexed, default 1)' },
          endLine: { type: 'number', description: 'End line (1-indexed, inclusive)' },
          endColumn: { type: 'number', description: 'End column (1-indexed, exclusive; default: end of endLine)' },
          newText: { type: 'string', description: 'Replacement text (may contain newlines)' },
        },
        required: ['uri', 'startLine', 'endLine', 'newText'],
      },
    });

    this.registerTool('editor/insert_at', this.insertAt.bind(this), {
      name: 'editor/insert_at',
      description: 'Insert text into an OPEN document\'s buffer at a 1-indexed line/column (line = lineCount+1 appends a new last line). Leaves the document dirty.',
      inputSchema: {
        type: 'object',
        properties: {
          uri: { type: 'string', description: 'Open document' },
          line: { type: 'number', description: 'Line number (1-indexed)' },
          column: { type: 'number', description: 'Column number (1-indexed, default 1)' },
          text: { type: 'string', description: 'Text to insert (may contain newlines)' },
        },
        required: ['uri', 'line', 'text'],
      },
    });

    this.registerTool('editor/delete_range', this.deleteRange.bind(this), {
      name: 'editor/delete_range',
      description: 'Delete a range of an OPEN document\'s buffer (1-indexed lines/columns, end column exclusive; omit endColumn to delete through the end of endLine). Leaves the document dirty.',
      inputSchema: {
        type: 'object',
        properties: {
          uri: { type: 'string', description: 'Open document' },
          startLine: { type: 'number', description: 'Start line (1-indexed)' },
          startColumn: { type: 'number', description: 'Start column (1-indexed, default 1)' },
          endLine: { type: 'number', description: 'End line (1-indexed, inclusive)' },
          endColumn: { type: 'number', description: 'End column (1-indexed, exclusive; default: end of endLine)' },
        },
        required: ['uri', 'startLine', 'endLine'],
      },
    });

    // IDE context / settings / build & run (the general tools)
    this.registerTool('ide/get_context', this.getIdeContext.bind(this), {
      name: 'ide/get_context',
      description: 'Call this FIRST. What the IDE has open and can do: the open project (path, name, kind vpy|c, entry file, pinned SDK version and whether it is installed), the selected build target, the targets this project can build (for a C project: its [targets.*], [build] and whether it has a [simulate] simulator), what F5/Shift+F5 would do right now, the emulator state, the Arm GNU Toolchain status and the IDE version. With a project open it also returns "assets" (the project\'s sprites, music, SFX, animations, levels... with the exact code that uses each one, and the asset types you can create) and "api" (the drawing/sound/input/math calls of the project\'s language on the selected target, one line each, plus how-to recipes for common game needs). Write code from these; api_reference has the full detail.',
      inputSchema: noParams,
    });

    this.registerTool('api/reference', this.apiReferenceTool.bind(this), {
      name: 'api/reference',
      description: 'The FULL API reference of the open project\'s language, generated from the real sources: for VPy the compiler\'s own builtin catalog (signature, doc line, and the targets whose backend accepts each builtin); for C the headers of the project\'s PINNED SDK version (vpy.h + vpy3d.h by default: prototypes, their doc comments, the VPY_SHORT_NAMES aliases; topic = another header such as "vpyphys" for that module). Use this instead of grepping the SDK or compiler sources. No arguments = everything; topic = a category (e.g. "Drawing", "Audio", "input") or "howto"; query = a substring or regex over names and docs (e.g. "rot", "button").',
      inputSchema: {
        type: 'object',
        properties: {
          topic: { type: 'string', description: 'A category, a C header name (vpy3d, vpyphys...), or "howto". The result lists the topics.' },
          query: { type: 'string', description: 'Substring or regex matched against names, signatures and docs' },
          target: { type: 'string', enum: ['m6809', 'rp2350', 'pitrex', 'uvm2'], description: 'VPy: the target to check availability against (default: the selected build target)' },
        },
      },
    });

    this.registerTool('settings/set_build_target', this.setBuildTarget.bind(this), {
      name: 'settings/set_build_target',
      description: 'Select the build target, exactly like the target selector in the Settings panel: m6809 (original Vectrex cartridge, JSVecX emulator; VPy only), rp2350 (RP2350 debug cartridge, emulated), uvm2 (UVMC2 multicart, emulated; needs the Arm toolchain), pitrex (PiTrex board). Applies to the next ide_run. Warns when the open project cannot build that target.',
      inputSchema: {
        type: 'object',
        properties: {
          target: { type: 'string', enum: ['m6809', 'rp2350', 'pitrex', 'uvm2'], description: 'Build target' },
        },
        required: ['target'],
      },
    });

    this.registerTool('ide/run', this.ideRun.bind(this), {
      name: 'ide/run',
      description: 'Build (and run) the open project exactly like the IDE keys, and WAIT for the result. WHICH MODE: on the rp2350, uvm2 and pitrex targets run the program with "simulate" (or omit mode, which picks it there); use "run" on those targets only when the user explicitly asks for the emulator (it runs the real ARM code and is slow). On m6809 use "run" (the default there). Modes: "build" = F7 (build for the selected target), "run" = F5 (build and run it on the selected target\'s emulator), "simulate" = Shift+F5 (C project with [simulate]: build and run the WASM simulator; otherwise same as F5), "build_simulator" = Shift+F7. Works for VPy and C (.cvproj) projects. Returns ok, the artifact, which emulator was started (6809 JSVecX, RP2350, UVM2, PiTrex, WASM simulator) and whether it is running, plus the build output tail; fails with the compiler errors and output otherwise. Opens the Emulator panel if needed.',
      inputSchema: {
        type: 'object',
        properties: {
          mode: { type: 'string', enum: ['build', 'run', 'simulate', 'build_simulator'], description: 'build = F7, run = F5 (target emulator), simulate = Shift+F5, build_simulator = Shift+F7. Omitted: simulate on rp2350/uvm2/pitrex, run on m6809.' },
        },
      },
    });

    // Compiler tools
    this.registerTool('compiler/build', this.compilerBuild.bind(this), {
      name: 'compiler/build',
      description: 'Build the open project. A VPy project is built for the Vectrex (m6809) whatever target is selected: saves dirty project sources/assets, compiles the project entry and loads the ROM into the emulator; returns binPath, or fails with the compiler errors. A C/C++ (.cvproj) project is built like F7 (= ide_run mode "build", selected target). ide_run is the general tool (any target, run, simulator).',
      inputSchema: noParams,
    });

    this.registerTool('compiler/get_errors', this.getCompilerErrors.bind(this), {
      name: 'compiler/get_errors',
      description: 'Get error diagnostics of open documents plus the result of the last compiler_build issued through MCP.',
      inputSchema: noParams,
    });

    this.registerTool('compiler/build_and_run', this.buildAndRun.bind(this), {
      name: 'compiler/build_and_run',
      description: 'compiler_build, then start the ROM in the emulator (Emulator panel must be open). With breakOnEntry=true the ROM is loaded but left stopped. VPy projects build m6809; a C/C++ (.cvproj) project runs like F5 (= ide_run mode "run"). Prefer ide_run.',
      inputSchema: {
        type: 'object',
        properties: {
          breakOnEntry: { type: 'boolean', description: 'Load but do not start (default false)' },
        },
      },
    });

    // Emulator tools
    this.registerTool('emulator/run', this.emulatorRun.bind(this), {
      name: 'emulator/run',
      description: 'Load a Vectrex .bin ROM into the emulator (with its .pdb debug symbols if present next to it) and start it. The Emulator panel must be open.',
      inputSchema: {
        type: 'object',
        properties: {
          romPath: { type: 'string', description: 'Absolute path, or path relative to the project root, of a .bin ROM' },
          breakOnEntry: { type: 'boolean', description: 'Load but do not start (default false)' },
        },
        required: ['romPath'],
      },
    });

    this.registerTool('emulator/get_state', this.getEmulatorState.bind(this), {
      name: 'emulator/get_state',
      description: 'Get emulator state: running flag, debugger state, PC, CPU registers, total cycles, FPS, loaded ROM, current VPy line.',
      inputSchema: noParams,
    });

    this.registerTool('emulator/stop', this.emulatorStop.bind(this), {
      name: 'emulator/stop',
      description: 'Stop the emulator (and end a debug session). The CPU is reset; the ROM stays loaded.',
      inputSchema: noParams,
    });

    // Memory tools
    this.registerTool('memory/dump', this.memoryDump.bind(this), {
      name: 'memory/dump',
      description: 'Hex (or decimal) dump of emulator memory. Default is all of RAM ($C800-$CFFF). Readable regions: $0000-$7FFF cartridge, $C800-$CFFF RAM, $E000-$FFFF BIOS (max 4096 bytes).',
      inputSchema: {
        type: 'object',
        properties: {
          start: { type: ['number', 'string'], description: 'Start address (decimal, 0xHEX or $HEX; default 0xC800)' },
          end: { type: ['number', 'string'], description: 'End address, inclusive (default 0xCFFF, or start+length-1)' },
          length: { type: 'number', description: 'Number of bytes (alternative to end)' },
          format: { type: 'string', enum: ['hex', 'decimal'], description: 'Byte format (default hex)' },
        },
      },
    });

    this.registerTool('memory/list_variables', this.listVariables.bind(this), {
      name: 'memory/list_variables',
      description: 'List program variables from the loaded debug symbols (.pdb): name, address, size, type — sorted by size, largest first, with RAM usage totals. Build or run a program first.',
      inputSchema: noParams,
    });

    this.registerTool('memory/read_variable', this.readVariable.bind(this), {
      name: 'memory/read_variable',
      description: 'Read the current value of a program variable from emulator RAM using the loaded .pdb (8-bit and 16-bit values big-endian, signed and unsigned; arrays as bytes/words).',
      inputSchema: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Variable name as in the PDB (e.g. "player_x"); case-insensitive, VAR_ prefix optional' },
        },
        required: ['name'],
      },
    });

    this.registerTool('memory/write', this.memoryWrite.bind(this), {
      name: 'memory/write',
      description: 'Write an 8- or 16-bit (big-endian) value to emulator RAM ($C800-$CFFF) and return the value read back.',
      inputSchema: {
        type: 'object',
        properties: {
          address: { type: ['number', 'string'], description: 'RAM address (decimal, 0xHEX or $HEX)' },
          value: { type: ['number', 'string'], description: '0-255 for size 1, 0-65535 for size 2' },
          size: { type: 'number', enum: [1, 2], description: 'Bytes to write (default 1)' },
        },
        required: ['address', 'value'],
      },
    });

    // Debugger tools
    this.registerTool('debugger/add_breakpoint', this.addBreakpoint.bind(this), {
      name: 'debugger/add_breakpoint',
      description: 'Set a breakpoint on a 1-indexed line of a project source (idempotent: setting an existing one is a no-op).',
      inputSchema: {
        type: 'object',
        properties: {
          uri: { type: 'string', description: 'Open document, file:// URI, or project-relative path' },
          line: { type: 'number', description: 'Line number (1-indexed)' },
        },
        required: ['uri', 'line'],
      },
    });

    this.registerTool('debugger/remove_breakpoint', this.removeBreakpoint.bind(this), {
      name: 'debugger/remove_breakpoint',
      description: 'Remove the breakpoint on a line. Fails if there is none.',
      inputSchema: {
        type: 'object',
        properties: {
          uri: { type: 'string', description: 'Document URI or project-relative path' },
          line: { type: 'number', description: 'Line number (1-indexed)' },
        },
        required: ['uri', 'line'],
      },
    });

    this.registerTool('debugger/list_breakpoints', this.listBreakpoints.bind(this), {
      name: 'debugger/list_breakpoints',
      description: 'List all breakpoints (uri, line).',
      inputSchema: noParams,
    });

    this.registerTool('debugger/clear_breakpoints', this.clearBreakpoints.bind(this), {
      name: 'debugger/clear_breakpoints',
      description: 'Remove every breakpoint in every file.',
      inputSchema: noParams,
    });

    this.registerTool('debugger/start', this.debugStart.bind(this), {
      name: 'debugger/start',
      description: 'Start a debug session like Ctrl+F5: compiles the ACTIVE .vpy document (the project when one is open), loads it with breakpoints and runs to the first breakpoint. Waits until the program is loaded.',
      inputSchema: noParams,
    });

    this.registerTool('debugger/continue', this.debugContinue.bind(this), {
      name: 'debugger/continue',
      description: 'Resume execution until the next breakpoint (or start the loaded ROM).',
      inputSchema: noParams,
    });

    this.registerTool('debugger/pause', this.debugPause.bind(this), {
      name: 'debugger/pause',
      description: 'Pause execution.',
      inputSchema: noParams,
    });

    this.registerTool('debugger/step_into', this.stepInto.bind(this), {
      name: 'debugger/step_into',
      description: 'Step into (F11). Execution must be paused.',
      inputSchema: noParams,
    });

    this.registerTool('debugger/step_over', this.stepOver.bind(this), {
      name: 'debugger/step_over',
      description: 'Step over (F10). Execution must be paused.',
      inputSchema: noParams,
    });

    this.registerTool('debugger/step_out', this.stepOut.bind(this), {
      name: 'debugger/step_out',
      description: 'Step out of the current function (Shift+F11). Execution must be paused.',
      inputSchema: noParams,
    });

    this.registerTool('debugger/get_callstack', this.getCallstack.bind(this), {
      name: 'debugger/get_callstack',
      description: 'Get the current call stack (meaningful while paused in a debug session).',
      inputSchema: noParams,
    });

    this.registerTool('debugger/get_registers', this.getRegisters.bind(this), {
      name: 'debugger/get_registers',
      description: 'Get the 6809 registers (A, B, D, X, Y, U, S, PC, DP, CC with decoded flags).',
      inputSchema: noParams,
    });

    // Project tools
    this.registerTool('project/get_structure', this.getProjectStructure.bind(this), {
      name: 'project/get_structure',
      description: 'File tree of the open project (relative paths with sizes; skips build/, node_modules/, .git/, target/). Bounded by maxDepth/maxEntries.',
      inputSchema: {
        type: 'object',
        properties: {
          maxDepth: { type: 'number', description: 'Directory depth (default 6, max 12)' },
          maxEntries: { type: 'number', description: 'Entry cap (default 2000, max 10000)' },
        },
      },
    });

    this.registerTool('project/read_file', this.readProjectFile.bind(this), {
      name: 'project/read_file',
      description: 'Read a UTF-8 file from disk inside the open project (max 2 MB). Unsaved editor changes are NOT included — use editor_read_document for those.',
      inputSchema: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Path relative to the project root (absolute paths must be inside it)' },
        },
        required: ['path'],
      },
    });

    this.registerTool('project/write_file', this.writeProjectFile.bind(this), {
      name: 'project/write_file',
      description: 'Write a UTF-8 file inside the open project (creating directories). If the file is open in the editor its tab is refreshed; set open=true to also open it.',
      inputSchema: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Path relative to the project root, e.g. "src/main.vpy"' },
          content: { type: 'string', description: 'Complete file content' },
          open: { type: 'boolean', description: 'Open the file in the editor (default false)' },
        },
        required: ['path', 'content'],
      },
    });

    this.registerTool('project/open', this.openProject.bind(this), {
      name: 'project/open',
      description: 'Open a project in the IDE exactly like File > Open Project: accepts a .vpyproj / .cvproj file or a directory containing one. Restores its open tabs (or opens the entry file).',
      inputSchema: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Absolute path of a .vpyproj/.cvproj file or of the project directory' },
        },
        required: ['path'],
      },
    });

    this.registerTool('project/close', this.closeProject.bind(this), {
      name: 'project/close',
      description: 'Close the open project and all its tabs. Fails if there are unsaved documents unless force=true.',
      inputSchema: {
        type: 'object',
        properties: {
          force: { type: 'boolean', description: 'Discard unsaved changes (default false)' },
        },
      },
    });

    this.registerTool('project/create', this.createProject.bind(this), {
      name: 'project/create',
      description: 'Create a new project folder <location>/<name> and open it. kind "vpy" (default): <name>.vpyproj + src/main.vpy + assets/ folders, a VPy game. kind "c": a C project on the SDK (uvmc2-sdk) libvpy runtime — <name>.cvproj + Makefile + src/main.c (#include <vpy.h>, vpy_run(setup, loop)) that draws HELLO WORLD and builds for the WASM simulator ([simulate], Shift+F5), rp2350 and uvm2 ([targets.*]). Both are pinned to the latest SDK release. Use kind "c" when the user asks for C or "the SDK".',
      inputSchema: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Project name: starts with a letter, then letters, digits, "_" or "-" (also the folder name)' },
          location: { type: 'string', description: 'Absolute path of the PARENT directory. Omit it to use the default workspace, ~/VectrexStudio/projects' },
          kind: { type: 'string', enum: ['vpy', 'c'], description: 'vpy (default) or c' },
        },
        required: ['name'],
      },
    });

    // Assets: the IDE's asset system (docs/ASSETS.md; catalog in ./assets.ts)
    const assetTypes = ASSET_SPECS.map((a) => a.type);

    this.registerTool('assets/list', this.assetsList.bind(this), {
      name: 'assets/list',
      description: 'List the assets of the open project (vector sprites, music, SFX, animations, levels, enemies, instruments, recordings, samples, 3D meshes, 3D scenes) grouped by type: name, path, a one-line summary and the EXACT code that uses each one in this project\'s language (VPy builtin call, or C #include + call). Also lists the asset types this project could use but has none of, the types its language cannot use, and other asset files. Call it before writing drawing, sound, level or animation code.',
      inputSchema: {
        type: 'object',
        properties: {
          type: { type: 'string', enum: assetTypes, description: 'Only this asset type (default: all)' },
          maxPerType: { type: 'number', description: 'Max assets listed per type (default 100, max 1000)' },
        },
      },
    });

    this.registerTool('asset/get_format', this.assetGetFormat.bind(this), {
      name: 'asset/get_format',
      description: 'Format of one asset type: the JSON fields, a minimal valid example, the folder it goes in, the IDE editor that opens it, the targets, and how VPy and C code use it. Read it before writing an asset with asset_create.',
      inputSchema: {
        type: 'object',
        properties: {
          type: { type: 'string', enum: assetTypes, description: 'Asset type (file extension without the dot)' },
        },
        required: ['type'],
      },
    });

    this.registerTool('asset/create', this.assetCreate.bind(this), {
      name: 'asset/create',
      description: 'Create (or with overwrite=true replace) an asset in the open project, in the folder its build reads (assets/vectors, assets/music, assets/sfx, assets/animations, assets/playground, assets/enemies, assets/instruments, assets/recordings, assets/samples, assets/meshes, assets/scenes), and VALIDATE it by compiling it with vpy_cli (plus the C header step for a C project). On a compile error nothing is left behind (a replaced file is restored) and the compiler\'s message is returned. Returns the summary and the exact code to use it. Referenced assets (frame .vec files, level sprites, enemy types, the .vmesh pieces of a scene) must exist first. Formats: asset_get_format.',
      inputSchema: {
        type: 'object',
        properties: {
          type: { type: 'string', enum: assetTypes, description: 'Asset type (file extension without the dot)' },
          name: { type: 'string', description: 'Asset name = file name without extension = the name code uses: a letter or "_", then letters, digits, "_" or "-". Prefer lower_case.' },
          content: { description: 'The asset: a JSON object, or its JSON text. See asset_get_format for the fields.', type: ['object', 'string'] },
          overwrite: { type: 'boolean', description: 'Replace an existing file (default false)' },
          open: { type: 'boolean', description: 'Open it in its IDE editor (default true; levels open from the file tree in the Playground)' },
        },
        required: ['type', 'name', 'content'],
      },
    });

    this.registerTool('project/create_vector', this.createVector.bind(this), {
      name: 'project/create_vector',
      description: 'Older shortcut for asset_create {type:"vec"}: creates assets/vectors/<name>.vec (validated by the compiler) and opens it in the Vector Editor. Empty content = a small template. Refuses to overwrite unless overwrite=true.',
      inputSchema: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Asset name (without .vec)' },
          content: { type: 'string', description: 'JSON text; omit for a template' },
          overwrite: { type: 'boolean', description: 'Replace an existing file (default false)' },
        },
        required: ['name'],
      },
    });

    this.registerTool('project/create_music', this.createMusic.bind(this), {
      name: 'project/create_music',
      description: 'Older shortcut for asset_create {type:"vmus"}: creates assets/music/<name>.vmus (validated by the compiler) and opens it in the Music Editor. Max 120 events / 16 KB here (asset_create has no such cap). Empty content = an empty track. Refuses to overwrite unless overwrite=true.',
      inputSchema: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Asset name (without .vmus)' },
          content: { type: 'string', description: 'JSON text; omit for an empty template' },
          overwrite: { type: 'boolean', description: 'Replace an existing file (default false)' },
        },
        required: ['name'],
      },
    });

    this.registerTool('project/create_sfx', this.createSfx.bind(this), {
      name: 'project/create_sfx',
      description: 'Older shortcut for asset_create {type:"vsfx"}: creates assets/sfx/<name>.vsfx (validated by the compiler) and opens it in the SFX Editor. Empty content = a laser preset. Refuses to overwrite unless overwrite=true.',
      inputSchema: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Asset name (without .vsfx)' },
          content: { type: 'string', description: 'JSON text; omit for the laser preset' },
          overwrite: { type: 'boolean', description: 'Replace an existing file (default false)' },
        },
        required: ['name'],
      },
    });
  }

  // ── Editor ──────────────────────────────────────────────────────────────

  private async listDocuments(_params: any): Promise<any> {
    return { documents: await this.listDocs() };
  }

  private async readDocument(params: any): Promise<any> {
    const doc = await this.resolveOpenDoc(params.uri ?? params.path);
    const d = await this.getDoc(doc.uri);
    return { uri: d.uri, language: d.language, dirty: d.dirty, diskPath: d.diskPath, lineCount: d.content.split('\n').length, content: d.content };
  }

  /** Where editor/write_document may write: a file inside the open project. */
  private async resolveWriteTarget(target: string): Promise<string> {
    const info = await this.requireProject();
    if (isFileUri(target)) return resolveInsideRoot(info.rootDir, fileUriToPath(target));
    if (hasOtherScheme(target)) throw new Error(`Only file:// URIs inside the project can be written (got ${target})`);
    if (path.isAbsolute(target)) return resolveInsideRoot(info.rootDir, target);
    if (!/[\\/]/.test(target)) {
      // Bare file name: an open project document of that name, else src/ for .vpy, root otherwise.
      const docs = await this.listDocs();
      const m = docs.filter((d) => d.diskPath && path.basename(d.diskPath) === target);
      if (m.length === 1 && m[0].diskPath) {
        try { return await resolveInsideRoot(info.rootDir, m[0].diskPath); } catch { /* fall through */ }
      }
      return resolveInsideRoot(info.rootDir, target.toLowerCase().endsWith('.vpy') ? path.join('src', target) : target);
    }
    return resolveInsideRoot(info.rootDir, target);
  }

  private async writeDocument(params: any): Promise<any> {
    const target = requireString(params.uri ?? params.path, 'uri');
    if (typeof params.content !== 'string') throw new Error('"content" is required and must be a string');
    const abs = await this.resolveWriteTarget(target);
    await fs.mkdir(path.dirname(abs), { recursive: true });
    await fs.writeFile(abs, params.content, 'utf-8');
    const st = await fs.stat(abs);
    const ed = await this.syncEditorWithFile(abs, params.content, st.mtimeMs, true);
    return { uri: ed.uri, path: abs, size: st.size, openedInEditor: ed.opened, refreshedInEditor: ed.refreshed };
  }

  private async saveDocument(params: any): Promise<any> {
    const doc = await this.resolveOpenDoc(params.uri ?? params.path);
    const d = await this.getDoc(doc.uri);
    const diskPath = d.diskPath || (isFileUri(d.uri) ? fileUriToPath(d.uri) : null);
    if (!diskPath) throw new Error(`${d.uri} is an in-memory document with no file on disk; use editor_write_document with a project path instead`);
    const info = await this.requireProject();
    await resolveInsideRoot(info.rootDir, diskPath);
    await fs.mkdir(path.dirname(diskPath), { recursive: true });
    await fs.writeFile(diskPath, d.content, 'utf-8');
    const st = await fs.stat(diskPath);
    await this.bridge('markSaved', { uri: d.uri, mtime: st.mtimeMs });
    return { uri: d.uri, path: diskPath, size: st.size, mtime: st.mtimeMs };
  }

  private async getDiagnostics(params: any): Promise<any> {
    let uri: string | null = null;
    if (params.uri !== undefined && params.uri !== null && params.uri !== '') {
      uri = (await this.resolveOpenDoc(params.uri)).uri;
    }
    const diagnostics = await this.bridge<any[]>('diagnostics', { uri });
    return { uri, count: diagnostics.length, diagnostics };
  }

  private static spliceText(content: string, sl: number, sc: number | null, el: number, ec: number | null, text: string) {
    const lines = content.split('\n');
    if (sl > lines.length) throw new Error(`startLine ${sl} is out of range (document has ${lines.length} lines)`);
    if (el > lines.length) throw new Error(`endLine ${el} is out of range (document has ${lines.length} lines)`);
    if (el < sl) throw new Error(`endLine (${el}) is before startLine (${sl})`);
    const first = lines[sl - 1];
    const last = lines[el - 1];
    const s = Math.min(Math.max(sc ?? 1, 1), first.length + 1);
    const e = Math.min(Math.max(ec ?? last.length + 1, 1), last.length + 1);
    if (sl === el && e < s) throw new Error(`endColumn (${e}) is before startColumn (${s}) on the same line`);
    const merged = first.slice(0, s - 1) + text + last.slice(e - 1);
    lines.splice(sl - 1, el - sl + 1, ...merged.split('\n'));
    return lines.join('\n');
  }

  private async applyEdit(uriParam: unknown, edit: (content: string) => string): Promise<any> {
    const doc = await this.resolveOpenDoc(uriParam);
    const d = await this.getDoc(doc.uri);
    const next = edit(d.content);
    const r = await this.bridge<any>('setDocumentContent', { uri: d.uri, content: next });
    return { uri: d.uri, dirty: r.dirty, lineCount: r.lines, previousLineCount: d.content.split('\n').length };
  }

  private async replaceRange(params: any): Promise<any> {
    const sl = requirePositiveInt(params.startLine ?? params.start_line, 'startLine');
    const el = requirePositiveInt(params.endLine ?? params.end_line, 'endLine');
    const scRaw = params.startColumn ?? params.start_column;
    const ecRaw = params.endColumn ?? params.end_column;
    const sc = scRaw === undefined || scRaw === null ? null : requirePositiveInt(scRaw, 'startColumn');
    const ec = ecRaw === undefined || ecRaw === null ? null : requirePositiveInt(ecRaw, 'endColumn');
    const text = params.newText ?? params.new_text;
    if (typeof text !== 'string') throw new Error('"newText" is required and must be a string');
    return this.applyEdit(params.uri ?? params.path, (c) => MCPServer.spliceText(c, sl, sc, el, ec, text));
  }

  private async insertAt(params: any): Promise<any> {
    const line = requirePositiveInt(params.line, 'line');
    const column = params.column === undefined || params.column === null ? 1 : requirePositiveInt(params.column, 'column');
    if (typeof params.text !== 'string') throw new Error('"text" is required and must be a string');
    return this.applyEdit(params.uri ?? params.path, (c) => {
      const lineCount = c.split('\n').length;
      if (line === lineCount + 1) return c + '\n' + params.text;
      return MCPServer.spliceText(c, line, column, line, column, params.text);
    });
  }

  private async deleteRange(params: any): Promise<any> {
    const sl = requirePositiveInt(params.startLine ?? params.start_line, 'startLine');
    const el = requirePositiveInt(params.endLine ?? params.end_line, 'endLine');
    const scRaw = params.startColumn ?? params.start_column;
    const ecRaw = params.endColumn ?? params.end_column;
    const sc = scRaw === undefined || scRaw === null ? null : requirePositiveInt(scRaw, 'startColumn');
    const ec = ecRaw === undefined || ecRaw === null ? null : requirePositiveInt(ecRaw, 'endColumn');
    return this.applyEdit(params.uri ?? params.path, (c) => MCPServer.spliceText(c, sl, sc, el, ec, ''));
  }

  // ── IDE context / settings / build & run ────────────────────────────────

  private async ideVersion(): Promise<string | null> {
    try {
      const electron: any = await import('electron');
      const app = electron?.app ?? electron?.default?.app;
      if (app?.getVersion) return app.getVersion();
    } catch { /* not running inside Electron (tests) */ }
    try {
      const pkg = JSON.parse(await fs.readFile(path.join(__dirname, '..', '..', 'package.json'), 'utf-8'));
      return typeof pkg.version === 'string' ? pkg.version : null;
    } catch { return null; }
  }

  /** The open project as the build sees it: kind, SDK pin, and (for C) the .cvproj recipes. */
  private async describeProject(info: ProjectInfo): Promise<any> {
    const sdkMgr = await import('../sdkManager.js');
    let sdkVersion: string | null = null;
    try { sdkVersion = await sdkMgr.readProjectSdkVersion(info.projectFile); } catch { /* unreadable */ }
    const sdk = sdkVersion
      ? { version: sdkVersion, installed: await sdkMgr.isSdkInstalled(sdkVersion), dir: sdkMgr.sdkDirFor(sdkVersion) }
      : { version: null, installed: false, dir: null, note: 'No [sdk] version: the IDE pins the latest release on the first build that needs the SDK.' };
    const base = {
      name: info.name, projectFile: info.projectFile, rootDir: info.rootDir,
      kind: info.isExternal ? 'c' : 'vpy', entry: info.entryPath, sdk,
    };
    if (!info.isExternal) {
      return {
        ...base, output: info.outputPath,
        buildableTargets: ['m6809', 'rp2350', 'pitrex', 'uvm2'],
        simulator: false,
      };
    }
    let manifest: any = null;
    try {
      const toml: any = await import('toml');
      manifest = (toml.parse ?? toml.default?.parse)(await fs.readFile(info.projectFile, 'utf-8'));
    } catch (e: any) {
      return { ...base, manifestError: `Could not parse ${info.projectFile}: ${e?.message || e}` };
    }
    const targets: Record<string, any> = manifest?.targets && typeof manifest.targets === 'object' ? manifest.targets : {};
    const recipe = (r: any) => (r ? { command: r.command ?? manifest?.build?.command ?? null, args: r.args ?? null, artifact: r.artifact ?? null } : null);
    const declared = Object.keys(targets);
    const hw = ['rp2350', 'uvm2', 'pitrex'];
    return {
      ...base,
      defaultTarget: manifest?.project?.target ?? null,
      build: recipe(manifest?.build),
      targets: Object.fromEntries(declared.map((t) => [t, recipe(targets[t])])),
      simulate: manifest?.simulate?.command ? { command: manifest.simulate.command, args: manifest.simulate.args ?? [], module: manifest.simulate.module ?? null } : null,
      simulator: !!manifest?.simulate?.command,
      // With [targets.*] tables, a hardware target without one is refused; with none, every
      // target runs the [build] recipe (executeExternalBuild in main.ts). m6809: never.
      buildableTargets: declared.length ? hw.filter((t) => declared.includes(t)) : hw,
      ...(declared.length ? {} : { note: 'No [targets.*] tables: every hardware target runs the [build] recipe.' }),
    };
  }

  /** One sentence per key for the current project + target, from handleBuild's rules. */
  private static keyEffects(project: any, target: string, rp2350BuildMode: string): Record<string, string> {
    if (!project) {
      return { F5: 'Builds the active .vpy document for the selected target and runs it (no project open).', note: 'Open or create a project first.' };
    }
    const emu: Record<string, string> = {
      m6809: 'the 6809 emulator (JSVecX)', rp2350: 'the RP2350 cartridge emulator', uvm2: 'the UVM2 multicart emulator', pitrex: 'the PiTrex interpreter',
    };
    const sd = target === 'rp2350' && rp2350BuildMode === 'sd';
    if (project.kind === 'vpy') {
      const run = sd ? 'builds the SD-card game for the RP2350 cartridge (Settings: rp2350 build mode "sd"); it is not emulated'
        : `builds for ${target} and runs it on ${emu[target]}`;
      return {
        F7: `builds for ${target}`, F5: run,
        'Shift+F5': `same as F5 (VPy has no separate simulator)`, 'Shift+F7': 'same as F7',
      };
    }
    const canBuild = (project.buildableTargets || []).includes(target);
    let f5: string;
    if (target === 'm6809') f5 = 'fails: a C project has no 6809 build path (select rp2350, uvm2 or pitrex)';
    else if (!canBuild) f5 = `fails: the .cvproj has no [targets.${target}] recipe`;
    else if (target === 'pitrex') f5 = 'builds the PiTrex kernel image (no emulator for it)';
    else f5 = `builds for ${target} and runs it on ${emu[target]}`;
    return {
      F7: target === 'm6809' ? 'fails: no 6809 build path for C' : `builds for ${target}`,
      F5: f5,
      'Shift+F5': project.simulator ? 'builds the WASM simulator and runs it in the Emulator panel' : `same as F5 (the .cvproj has no [simulate])`,
      'Shift+F7': project.simulator ? 'builds the WASM simulator (the panel loads it)' : 'same as F7',
    };
  }

  /** ide_run's mode when none is given: "simulate" on rp2350/uvm2/pitrex, "run" otherwise. */
  static defaultRunMode(target: string | undefined): 'run' | 'simulate' {
    return target === 'rp2350' || target === 'uvm2' || target === 'pitrex' ? 'simulate' : 'run';
  }

  private async getIdeContext(_params: any): Promise<any> {
    const [info, state] = await Promise.all([
      this.bridge<ProjectInfo & { workspaceRoot?: string | null }>('projectInfo'),
      this.bridge<any>('ideState'),
    ]);
    const project = info?.open ? await this.describeProject(info) : null;
    const sdkMgr = await import('../sdkManager.js');
    const [toolchain, installedSdks, version] = await Promise.all([
      sdkMgr.detectArmToolchain().catch(() => null),
      sdkMgr.listInstalledSdks().catch(() => [] as string[]),
      this.ideVersion(),
    ]);
    const target = state.buildTarget;
    const warnings: string[] = [];
    if (project?.kind === 'c' && project.buildableTargets && !project.buildableTargets.includes(target)) {
      warnings.push(target === 'm6809'
        ? 'The selected target m6809 cannot build a C project; select rp2350, uvm2 or pitrex (settings_set_build_target) or use the simulator.'
        : `The project has no recipe for the selected target ${target}; it declares: ${project.buildableTargets.join(', ') || 'none'}.`);
    }
    if ((target === 'uvm2') && !toolchain?.found) warnings.push('uvm2 builds need the Arm GNU Toolchain, which was not found.');
    if (project?.sdk && project.sdk.version && !project.sdk.installed) warnings.push(`SDK ${project.sdk.version} is not installed yet: the first build downloads it.`);
    // The project's assets and its language's API, so the first call already carries them.
    let assets: any;
    let api: any;
    if (info?.open && project) {
      const lang: 'vpy' | 'c' = project.kind === 'c' ? 'c' : 'vpy';
      [assets, api] = await Promise.all([
        this.contextAssets(info, lang, target).catch((e: any) => ({ error: e?.message || String(e) })),
        this.languageReference(info, project, { download: true })
          .then(({ ref, note }) => ({ ...compactApi(ref, lang === 'vpy' ? target : undefined), ...(note ? { note } : {}) }))
          .catch((e: any) => ({ error: e?.message || String(e), more: 'api_reference retries' })),
      ]);
    }
    return {
      ide: { name: 'Vectrex Studio', version },
      project: project ?? { open: false, workspaceRoot: info?.workspaceRoot ?? null },
      buildTarget: target,
      buildSettings: {
        rp2350BuildMode: state.rp2350BuildMode, rp2350FlashMethod: state.rp2350FlashMethod,
        pitrexCopyToSD: state.pitrexCopyToSD, uvm2CopyToSD: state.uvm2CopyToSD,
      },
      keys: MCPServer.keyEffects(project, target, state.rp2350BuildMode),
      runWith: MCPServer.defaultRunMode(target) === 'simulate'
        ? 'ide_run {mode:"simulate"} (the default on this target); "run" only when the user asks for the emulator'
        : 'ide_run {mode:"run"}',
      emulator: state.emulator,
      armToolchain: toolchain?.found
        ? { found: true, dir: toolchain.found.dir, version: toolchain.found.version, source: toolchain.found.source }
        : { found: false, tried: (toolchain?.candidates ?? []).map((c: any) => ({ dir: c.dir, problem: c.problem })) },
      sdk: { installed: installedSdks, root: sdkMgr.sdkRootDir() },
      warnings,
      ...(assets ? { assets } : {}),
      ...(api ? { api } : {}),
    };
  }

  /** ide_get_context's "assets": every asset with the code that uses it, capped, + what can be created. */
  private async contextAssets(info: ProjectInfo, lang: 'vpy' | 'c', target?: string): Promise<any> {
    const PER_TYPE = 12, TOTAL = 40;
    const scan = await scanProjectAssets(info.rootDir, lang, { maxPerType: PER_TYPE });
    // The first statement of a usage snippet (C: the #include and the call), no trailing comment.
    const brief = (usage: string) => usage.split('\n').map((l) => l.replace(/\s+(#|\/\*).*$/, '').trim()).filter(Boolean).slice(0, 2).join(' ');
    const byType: Record<string, string[]> = {};
    let shown = 0;
    for (const [type, group] of Object.entries(scan.assets)) {
      const room = Math.max(0, Math.min(group.items.length, TOTAL - shown));
      byType[type] = group.items.slice(0, room).map((i) => `${i.name}: ${i.usage ? brief(i.usage) : '(not usable here)'}${i.warning ? ` [${i.warning}]` : ''}`);
      shown += room;
      if (group.count > room) byType[type].push(`+${group.count - room} more: assets_list {type:"${type}"}`);
    }
    // VPy: the 3D types only on the targets that draw them (uvm2)
    const here = (sp: typeof ASSET_SPECS[number]) => !sp.vpyTargets || !target || sp.vpyTargets.includes(target);
    const usable = ASSET_SPECS.filter((sp) => (lang === 'c' ? sp.c.usable : sp.vpy.usable && here(sp)));
    const elsewhere = lang === 'vpy' ? ASSET_SPECS.filter((sp) => sp.vpy.usable && !here(sp)) : [];
    return {
      ...(shown ? { byType } : { byType: {}, none: 'This project has no assets yet.' }),
      canCreate: `asset_create (format: asset_get_format): ${usable.map((sp) => `${sp.type} ${sp.title.toLowerCase().replace(/\s*\(.*\)$/, '')}`).join(', ')}`
        + (elsewhere.length ? `; on ${[...new Set(elsewhere.flatMap((sp) => sp.vpyTargets!))].join('/')} only: ${elsewhere.map((sp) => sp.type).join(', ')}` : ''),
    };
  }

  /**
   * The reference for the open project's language: VPy = the bundled compiler's catalog;
   * C = the pinned SDK's headers (downloaded on demand like a build does; ide_get_context
   * waits for that a bounded time). `headers` picks C modules (default vpy.h + vpy3d.h).
   */
  private async languageReference(info: ProjectInfo, project: any, opts: { download: boolean; headers?: string[] }): Promise<{ ref: ApiReference; note?: string }> {
    if (project.kind !== 'c') {
      const cli = resolveVpyCli();
      if (!cli) throw new Error('vpy_cli was not found (build it with run-ide.sh): the VPy reference comes from the compiler');
      return { ref: await vpyReference(cli) };
    }
    const sdkMgr = await import('../sdkManager.js');
    let version: string | null = project.sdk?.version ?? null;
    let note: string | undefined;
    if (!version) {
      version = (await sdkMgr.listInstalledSdks().catch(() => [] as string[]))[0] ?? null;
      if (!version) throw new Error('The project pins no [sdk] version and no SDK is installed: build once (or api_reference) to get one');
      note = `The project pins no SDK version; this is the newest installed SDK, ${version}.`;
    }
    if (!(await sdkMgr.isSdkInstalled(version))) {
      if (!opts.download) throw new Error(`SDK ${version} is not installed yet`);
      const timeout = new Promise<never>((_, rej) => setTimeout(() => rej(new Error(`SDK ${version} is still downloading; call api_reference in a moment`)), 20000));
      await Promise.race([sdkMgr.ensureSdk(version), timeout]);
    }
    return { ref: await cReference(sdkMgr.sdkDirFor(version), version, opts.headers), note };
  }

  private async apiReferenceTool(params: any): Promise<any> {
    const info = await this.requireProject();
    const project = await this.describeProject(info);
    const lang: 'vpy' | 'c' = project.kind === 'c' ? 'c' : 'vpy';
    const targets = ['m6809', 'rp2350', 'pitrex', 'uvm2'];
    let target: string | undefined;
    if (lang === 'vpy') {
      target = params.target ?? (await this.bridge<any>('ideState')).buildTarget;
      if (!targets.includes(String(target))) throw new Error(`"target" must be one of ${targets.join(', ')}, got ${JSON.stringify(params.target)}`);
    }
    const topic = typeof params.topic === 'string' && params.topic.trim() ? params.topic.trim() : undefined;
    const query = typeof params.query === 'string' && params.query.trim() ? params.query.trim() : undefined;
    let headers: string[] | undefined;
    if (lang === 'c' && topic && /^vpy\w*(\.h)?$/i.test(topic)) {
      // vpy.h / vpy3d.h are in the default reference (the topic filters by header);
      // another module (vpyphys...) is parsed on request.
      const h = topic.toLowerCase().replace(/\.h$/, '') + '.h';
      if (h !== 'vpy.h' && h !== 'vpy3d.h') headers = [h];
    }
    const { ref, note } = await this.languageReference(info, project, { download: true, headers });
    const out: any = { language: lang, ...(target ? { target } : {}), source: ref.source, topics: topicsOf(ref) };
    if (note) out.note = note;
    if (topic && topic.toLowerCase() === 'howto' && !query) return { ...out, howTo: howTo(ref, target) };
    const list = filterEntries(ref, { topic: headers ? undefined : topic, query });
    if ((topic || query) && !list.length) {
      throw new Error(`Nothing matches ${JSON.stringify({ topic, query })} in the ${lang === 'c' ? 'C' : 'VPy'} reference. Topics: ${out.topics.join(', ')}`);
    }
    out.count = list.length;
    out.entries = list.map((e) => {
      const o: any = { name: e.name, signature: e.signature, doc: e.doc, category: e.category };
      if (e.short) o.short = e.short;
      if (e.header) o.header = e.header;
      if (e.kind && e.kind !== 'function') o.kind = e.kind;
      if (e.targets) { o.targets = e.targets; if (target) o.onTarget = e.targets.includes(target); }
      if (e.alternatives) o.alternatives = e.alternatives;
      if (e.aliasOf) o.aliasOf = e.aliasOf;
      return o;
    });
    if (!topic && !query) {
      out.howTo = howTo(ref, target);
      if (ref.notes.length) out.notes = ref.notes;
    }
    if (lang === 'c') {
      out.sections = (ref.sections || []).filter((sct) => !topic || sct.title.toLowerCase().includes(topic.toLowerCase()) || headers?.includes(sct.header))
        .map((sct) => ({ header: sct.header, title: sct.title, text: sct.text.slice(0, 600) }));
      out.modules = ref.modules;
    }
    return out;
  }

  private async setBuildTarget(params: any): Promise<any> {
    const target = requireString(params.target, 'target');
    const r = await this.bridge<{ previous: string; buildTarget: string }>('setBuildTarget', { target });
    const out: any = { buildTarget: r.buildTarget, previous: r.previous };
    const info = await this.bridge<ProjectInfo>('projectInfo');
    if (info?.open) {
      const p = await this.describeProject(info);
      if (p.kind === 'c' && p.buildableTargets && !p.buildableTargets.includes(target)) {
        out.warning = target === 'm6809'
          ? 'This C project cannot build m6809 (no 6809 build path); F5/ide_run will fail. Use rp2350, uvm2 or pitrex, or the simulator.'
          : `This project has no [targets.${target}] recipe (it declares: ${p.buildableTargets.join(', ') || 'none'}); a build for ${target} will be refused.`;
      }
    }
    return out;
  }

  /** ide/run: F7 / F5 / Shift+F5 / Shift+F7 through the renderer's own handleBuild, awaited. */
  private async ideRun(params: any, nested = false): Promise<any> {
    // No mode: what a model should start on the selected target (instructions rule 4) —
    // the simulator on the ARM targets, whose emulators run the real code and are slow.
    const mode = params?.mode === undefined || params?.mode === null || params?.mode === ''
      ? MCPServer.defaultRunMode((await this.bridge<any>('ideState'))?.buildTarget)
      : params.mode;
    if (!['build', 'run', 'simulate', 'build_simulator'].includes(mode)) {
      throw new Error(`"mode" must be build, run, simulate or build_simulator, got ${JSON.stringify(params.mode)}`);
    }
    if (!nested) {
      if (this.buildInFlight) throw new Error('A build started through MCP is already running');
      this.buildInFlight = true;
    }
    try {
      const r = await this.bridge<any>('runBuild', { mode });
      const errors: Array<{ line: number; column: number; message: string }> = [];
      for (const line of String(r.stderr || '').split('\n')) {
        const m = line.match(/error (\d+):(\d+) - (.+)/);
        if (m) errors.push({ line: parseInt(m[1], 10), column: parseInt(m[2], 10), message: m[3].trim() });
      }
      const at = new Date().toISOString();
      if (!r.ok) {
        this.lastBuild = { at, ok: false, errors, stderrTail: String(r.stderr || r.output || '').slice(-4000) };
        const lines = [`Build failed (${mode}, target ${r.target ?? 'n/a'}, ${r.project ?? 'no'} project): ${r.detail || r.error || 'unknown error'}`];
        if (r.error && r.detail) lines.push(`code: ${r.error}`);
        for (const e of errors) lines.push(`  ${e.line}:${e.column} ${e.message}`);
        for (const n of r.notes || []) lines.push(`note: ${n}`);
        const tail = String(r.stderr && !errors.length ? r.stderr : r.output || '').trim();
        if (tail) lines.push('--- build output (tail) ---', tail.slice(-6000));
        throw new Error(lines.join('\n'));
      }
      this.lastBuild = { at, ok: true, binPath: r.artifact ?? undefined };
      const em = r.emulator || {};
      const result: any = {
        ok: true, mode, project: r.project, target: r.target, artifact: r.artifact ?? null,
        ...(r.size ? { size: r.size } : {}),
        launched: r.launch, emulator: em, notes: r.notes || [], buildMs: r.buildMs,
        output: String(r.output || '').slice(-3000),
      };
      // "run"/"simulate" promise a running program: say so when it is not.
      if ((mode === 'run' || mode === 'simulate') && r.launch !== 'none' && !em.running) {
        const why = r.emulatorWait?.timedOut
          ? `timed out waiting for ${r.emulatorWait.waitedFor}`
          : em.simulator?.error || em.lastLoad?.error || (em.panelOpen ? 'the emulator is not running' : 'the Emulator panel is not open');
        throw new Error(
          `Built ${r.artifact ?? '(no artifact)'} for ${r.target}, but it is not running: ${why}.\n` +
          JSON.stringify({ ...result, ok: false }, null, 2));
      }
      if (mode === 'run' && r.launch === 'none') {
        result.notes = [...result.notes, 'Nothing was started: this target/build has no emulator in the IDE (see notes).'];
      }
      return result;
    } finally {
      if (!nested) this.buildInFlight = false;
    }
  }

  // ── Compiler ────────────────────────────────────────────────────────────

  /** Save dirty documents that live inside the project (same file types the UI saves before a build). */
  private async saveDirtyProjectDocs(rootDir: string): Promise<string[]> {
    const dirty = await this.bridge<Array<{ uri: string; diskPath: string | null; content: string }>>('dirtyDocuments');
    const saved: string[] = [];
    for (const d of dirty) {
      const p = d.diskPath || (isFileUri(d.uri) ? fileUriToPath(d.uri) : null);
      if (!p || !/\.(vpy|vmus|vec|vsfx|vplay|vanim)$/i.test(p)) continue;
      try { await resolveInsideRoot(rootDir, p); } catch { continue; }
      await fs.writeFile(p, d.content, 'utf-8');
      const st = await fs.stat(p);
      await this.bridge('markSaved', { uri: d.uri, mtime: st.mtimeMs });
      saved.push(p);
    }
    return saved;
  }

  private async compilerBuild(_params: any): Promise<any> {
    if (this.buildInFlight) throw new Error('A build started through MCP is already running');
    this.buildInFlight = true;
    try {
      const info = await this.requireProject();
      if (info.isExternal) {
        // A C/C++ project builds through the same path as F7 (ide_run mode "build").
        return await this.ideRun({ mode: 'build' }, true);
      }
      if (!info.entryPath) throw new Error(`The project file ${info.projectFile} has no [project] entry`);
      try { await fs.access(info.entryPath); } catch { throw new Error(`Project entry file not found: ${info.entryPath}`); }

      // Keep main's notion of the current project in sync with what the UI shows.
      const main = await import('../main.js');
      const cur = main.getCurrentProject();
      if (!cur || !samePath(cur.rootDir, info.rootDir) || !samePath(cur.entryFile, info.entryPath)) {
        main.setCurrentProject({ entryFile: info.entryPath, rootDir: info.rootDir });
      }

      const savedFiles = await this.saveDirtyProjectDocs(info.rootDir);

      // With breakpoints set, load the ROM in debug mode (paused, breakpoints synced).
      if (await this.bridge<boolean>('hasBreakpoints')) {
        await this.bridge('setLoadingForDebug', { value: true });
      }
      await this.bridge('armRomLoad');

      const result: any = await main.executeCompilation({
        path: info.entryPath,
        outputPath: info.outputPath || undefined,
        autoStart: false,
        target: 'm6809',
      });

      if (!result || result.error || result.conflict || !result.binPath) {
        const errors: Array<{ line: number; column: number; message: string }> = [];
        const stderr: string = result?.stderr || '';
        for (const line of stderr.split('\n')) {
          const m = line.match(/error (\d+):(\d+) - (.+)/);
          if (m) errors.push({ line: parseInt(m[1], 10), column: parseInt(m[2], 10), message: m[3].trim() });
        }
        const stderrTail = stderr.slice(-4000);
        this.lastBuild = { at: new Date().toISOString(), ok: false, errors, stderrTail };
        const reason = result?.conflict ? 'file changed on disk during build' : (result?.detail || result?.error || 'no binary produced');
        const lines = [`Build failed: ${reason}`];
        for (const e of errors) lines.push(`  ${e.line}:${e.column} ${e.message}`);
        if (!errors.length && stderrTail.trim()) lines.push('--- compiler stderr (tail) ---', stderrTail.trim());
        throw new Error(lines.join('\n'));
      }

      this.lastBuild = { at: new Date().toISOString(), ok: true, binPath: result.binPath };
      return {
        binPath: result.binPath,
        size: result.size,
        hasDebugSymbols: !!result.pdbData,
        savedFiles,
        project: info.projectFile,
      };
    } finally {
      this.buildInFlight = false;
    }
  }

  private async getCompilerErrors(_params: any): Promise<any> {
    const all = await this.bridge<any[]>('diagnostics', { uri: null });
    const errors = all.filter((d) => d.severity === 'error')
      .map((d) => ({ uri: d.uri, file: d.file, line: d.line, column: d.column, message: d.message, source: d.source }));
    return { errors, totalCount: errors.length, lastBuild: this.lastBuild };
  }

  /** Wait for the Emulator panel to load `binPath` (armRomLoad must have been called before it was sent). */
  private async waitForRom(binPath: string | null, timeoutMs: number): Promise<void> {
    const r = await this.bridge<{ loaded: boolean; current?: string | null }>('waitRomLoaded', { binPath, timeoutMs });
    if (!r.loaded) {
      throw new Error(`The Emulator panel did not load ${binPath ?? 'the program'} within ${Math.round(timeoutMs / 1000)} s — is the Emulator panel open?`);
    }
  }

  private async startAndVerify(): Promise<any> {
    const r = await this.bridge<{ running: boolean; debugState: string }>('startEmulator');
    if (!r.running) throw new Error(`The emulator did not start (debugger state: ${r.debugState}). Is the Emulator panel open?`);
    return r;
  }

  private async buildAndRun(params: any): Promise<any> {
    const info = await this.requireProject();
    if (info.isExternal && !params.breakOnEntry) return this.ideRun({ mode: 'run' });
    if (info.isExternal) throw new Error('breakOnEntry is only supported for VPy projects on m6809; use ide_run for a C project');
    const build = await this.compilerBuild({});
    await this.waitForRom(build.binPath, 15000);
    if (params.breakOnEntry) {
      return { ...build, started: false, state: await this.bridge('emulatorState') };
    }
    const r = await this.startAndVerify();
    return { ...build, started: true, running: r.running, debugState: r.debugState };
  }

  // ── Emulator ────────────────────────────────────────────────────────────

  private async emulatorRun(params: any): Promise<any> {
    const romParam = requireString(params.romPath ?? params.path, 'romPath');
    let romPath = romParam;
    if (!path.isAbsolute(romPath)) {
      const info = await this.requireProject();
      romPath = await resolveInsideRoot(info.rootDir, romPath);
    }
    if (!/\.bin$/i.test(romPath)) throw new Error(`Expected a Vectrex .bin ROM, got ${romPath}`);
    let st;
    try { st = await fs.stat(romPath); } catch { throw new Error(`ROM not found: ${romPath}`); }
    if (!st.isFile()) throw new Error(`Not a file: ${romPath}`);
    if (st.size === 0 || st.size > MAX_ROM) throw new Error(`Unexpected ROM size ${st.size} bytes: ${romPath}`);

    const data = await fs.readFile(romPath);
    let pdbData: any = null;
    try { pdbData = JSON.parse(await fs.readFile(romPath.replace(/\.bin$/i, '.pdb'), 'utf-8')); } catch { /* no symbols */ }

    await this.bridge('armRomLoad');
    // Same event the build pipeline uses to hand a ROM to the Emulator panel.
    this.requireWindow().webContents.send('emu://compiledBin', {
      base64: data.toString('base64'), size: data.length, binPath: romPath, pdbData, target: 'm6809',
    });
    await this.waitForRom(romPath, 10000);

    const out: any = { romPath, size: data.length, hasDebugSymbols: !!pdbData };
    if (params.breakOnEntry) return { ...out, started: false };
    const r = await this.startAndVerify();
    return { ...out, started: true, debugState: r.debugState };
  }

  private async getEmulatorState(_params: any): Promise<any> {
    const s = await this.bridge<any>('emulatorState');
    if (!s.available) throw new Error('Emulator not available (is the Emulator panel open?)');
    return { ...s, pcHex: s.pc === null ? null : hex(s.pc, 4) };
  }

  private async emulatorStop(_params: any): Promise<any> {
    const r = await this.bridge<{ running: boolean; debugState: string }>('stopEmulator');
    if (r.running) throw new Error('The emulator is still running after stop');
    return { running: false, debugState: r.debugState };
  }

  // ── Memory ──────────────────────────────────────────────────────────────

  private async memoryDump(params: any): Promise<any> {
    const start = optNumber(params.start ?? params.address, 'start', RAM_START);
    let end: number;
    if (params.end !== undefined && params.end !== null && params.end !== '') end = parseNumber(params.end, 'end');
    else if (params.length !== undefined || params.size !== undefined) end = start + optNumber(params.length ?? params.size, 'length', 256) - 1;
    else end = params.start === undefined && params.address === undefined ? RAM_END : start + 255;
    const length = end - start + 1;
    if (length < 1) throw new Error('end must be >= start');
    if (length > 4096) throw new Error(`At most 4096 bytes per dump (asked for ${length})`);
    const format = params.format === 'decimal' ? 'decimal' : 'hex';
    if (params.format !== undefined && params.format !== 'hex' && params.format !== 'decimal') {
      throw new Error('"format" must be "hex" or "decimal"');
    }
    assertReadableRange(start, length);
    const bytes = await this.bridge<number[]>('readMemory', { start, length });

    const rows: string[] = [];
    for (let i = 0; i < bytes.length; i += 16) {
      const row = bytes.slice(i, i + 16);
      const vals = row.map((b) => (format === 'hex' ? b.toString(16).toUpperCase().padStart(2, '0') : String(b).padStart(3, ' '))).join(' ');
      const ascii = row.map((b) => (b >= 32 && b <= 126 ? String.fromCharCode(b) : '.')).join('');
      rows.push(`${(start + i).toString(16).toUpperCase().padStart(4, '0')}: ${vals.padEnd(format === 'hex' ? 47 : 63, ' ')} | ${ascii}`);
    }
    return { start: hex(start, 4), end: hex(end, 4), length, format, dump: rows.join('\n') };
  }

  private async pdbVariables(): Promise<Record<string, { name?: string; address: string; size: number; type?: string }>> {
    const vars = await this.bridge<any>('pdbVariables');
    if (!vars || typeof vars !== 'object' || !Object.keys(vars).length) {
      throw new Error('No debug symbols with variables are loaded. Build (compiler_build) or run a program with a .pdb first.');
    }
    return vars;
  }

  private async listVariables(_params: any): Promise<any> {
    const vars = await this.pdbVariables();
    const list = Object.entries(vars)
      .map(([name, v]) => ({ name, address: v.address, size: v.size || 0, type: v.type ?? null }))
      .sort((a, b) => b.size - a.size);
    const usedBytes = list.reduce((s, v) => s + v.size, 0);
    const totalBytes = 1024;
    return {
      count: list.length, usedBytes, freeBytes: totalBytes - usedBytes, totalBytes,
      usagePercent: Number(((usedBytes / totalBytes) * 100).toFixed(1)),
      variables: list,
    };
  }

  private async readVariable(params: any): Promise<any> {
    const want = requireString(params.name, 'name');
    const vars = await this.pdbVariables();
    const strip = (s: string) => s.replace(/^VAR_/i, '').toLowerCase();
    const key = Object.prototype.hasOwnProperty.call(vars, want)
      ? want
      : Object.keys(vars).find((k) => strip(k) === strip(want));
    if (!key) {
      const close = Object.keys(vars).filter((k) => strip(k).includes(strip(want))).slice(0, 10);
      throw new Error(`Variable "${want}" not found in the PDB${close.length ? `. Similar: ${close.join(', ')}` : ''}`);
    }
    const info = vars[key];
    const address = typeof info.address === 'number' ? info.address : parseInt(String(info.address).replace(/^0x|^\$/i, ''), 16);
    if (!Number.isFinite(address)) throw new Error(`Variable ${key} has an unparseable address: ${info.address}`);
    const size = Math.max(1, Math.min(info.size || 2, 64));
    assertReadableRange(address, size);
    const bytes = await this.bridge<number[]>('readMemory', { start: address, length: size });
    const out: any = { name: key, address: hex(address, 4), size: info.size, type: info.type ?? null };
    if (size === 1) {
      const u = bytes[0];
      return { ...out, value: u, signed: u > 127 ? u - 256 : u, hex: hex(u, 2) };
    }
    if (size === 2) {
      const u = (bytes[0] << 8) | bytes[1];
      return { ...out, value: u, signed: u > 32767 ? u - 65536 : u, hex: hex(u, 4) };
    }
    const words: number[] = [];
    for (let i = 0; i + 1 < bytes.length; i += 2) words.push((bytes[i] << 8) | bytes[i + 1]);
    return { ...out, bytes, words, truncated: (info.size || 0) > size };
  }

  private async memoryWrite(params: any): Promise<any> {
    const address = parseNumber(params.address, 'address');
    const value = parseNumber(params.value, 'value');
    const size = optNumber(params.size, 'size', 1);
    if (size !== 1 && size !== 2) throw new Error('"size" must be 1 or 2');
    if (address < RAM_START || address + size - 1 > RAM_END) {
      throw new Error(`Address ${hex(address, 4)} (size ${size}) is outside RAM ($C800-$CFFF)`);
    }
    const max = size === 1 ? 0xff : 0xffff;
    if (value < 0 || value > max) throw new Error(`Value must be 0-${max} for a ${size * 8}-bit write`);
    const bytesIn = size === 1 ? [value] : [(value >> 8) & 0xff, value & 0xff];
    const back = await this.bridge<number[]>('writeMemory', { address, bytes: bytesIn });
    const readBack = size === 1 ? back[0] : (back[0] << 8) | back[1];
    if (readBack !== value) throw new Error(`Wrote ${hex(value, size * 2)} to ${hex(address, 4)} but read back ${hex(readBack, size * 2)}`);
    return { address: hex(address, 4), size, value: readBack, hex: hex(readBack, size * 2) };
  }

  // ── Debugger ────────────────────────────────────────────────────────────

  /** Breakpoint key: the editor URI of an open doc, else the file:// URI of a project path. */
  private async breakpointUri(uriParam: unknown): Promise<string> {
    const target = requireString(uriParam, 'uri');
    try {
      return (await this.resolveOpenDoc(target)).uri;
    } catch { /* not open */ }
    const info = await this.requireProject();
    const abs = isFileUri(target) ? fileUriToPath(target) : target;
    const resolved = await resolveInsideRoot(info.rootDir, abs);
    try { await fs.access(resolved); } catch { throw new Error(`File not found: ${resolved}`); }
    return pathToFileUri(resolved);
  }

  private async addBreakpoint(params: any): Promise<any> {
    const line = requirePositiveInt(params.line, 'line');
    const uri = await this.breakpointUri(params.uri ?? params.path);
    const r = await this.bridge<{ added: boolean; alreadySet: boolean }>('addBreakpoint', { uri, line });
    return { uri, line, ...r };
  }

  private async removeBreakpoint(params: any): Promise<any> {
    const line = requirePositiveInt(params.line, 'line');
    const raw = requireString(params.uri ?? params.path, 'uri');
    const existing = await this.bridge<Array<{ uri: string; line: number }>>('breakpoints');
    const uri = existing.some((b) => b.uri === raw) ? raw : await this.breakpointUri(raw);
    const r = await this.bridge<{ removed: boolean }>('removeBreakpoint', { uri, line });
    if (!r.removed) throw new Error(`No breakpoint at ${uri}:${line}`);
    return { uri, line, removed: true };
  }

  private async listBreakpoints(_params: any): Promise<any> {
    const breakpoints = await this.bridge<any[]>('breakpoints');
    return { count: breakpoints.length, breakpoints };
  }

  private async clearBreakpoints(_params: any): Promise<any> {
    return this.bridge('clearBreakpoints');
  }

  private async debugStart(_params: any): Promise<any> {
    const active = await this.bridge<DocInfo | null>('activeDocument');
    if (!active) throw new Error('No active document: debug start compiles the active .vpy document');
    if (!/\.vpy$/i.test(active.uri)) throw new Error(`The active document is not a .vpy file: ${active.uri}`);
    if (!active.diskPath) throw new Error(`The active document has no file on disk: ${active.uri}`);
    await this.bridge('armRomLoad');
    await this.bridge('command', { id: 'debug.start' });
    await this.waitForRom(null, 120000);
    const state = await this.bridge<any>('emulatorState');
    return { started: true, document: active.uri, romPath: state.loadedRom, debugState: state.debugState, running: state.running };
  }

  private async requirePaused(): Promise<void> {
    const s = await this.bridge<any>('emulatorState');
    if (!s.available) throw new Error('Emulator not available (is the Emulator panel open?)');
    if (s.debugState !== 'paused') throw new Error(`Execution is not paused (debugger state: ${s.debugState})`);
  }

  private async step(command: string): Promise<any> {
    await this.requirePaused();
    await this.bridge('command', { id: command });
    await new Promise((r) => setTimeout(r, 300));
    const s = await this.bridge<any>('emulatorState');
    return { command, debugState: s.debugState, pc: s.pc, pcHex: s.pc === null ? null : hex(s.pc, 4), currentVpyLine: s.currentVpyLine, currentVpyFile: s.currentVpyFile };
  }

  private async stepInto(_params: any): Promise<any> { return this.step('debug.stepInto'); }
  private async stepOver(_params: any): Promise<any> { return this.step('debug.stepOver'); }
  private async stepOut(_params: any): Promise<any> { return this.step('debug.stepOut'); }

  private async debugContinue(_params: any): Promise<any> {
    const r = await this.startAndVerify();
    return { running: true, debugState: r.debugState };
  }

  private async debugPause(_params: any): Promise<any> {
    const r = await this.bridge<{ running: boolean; debugState: string }>('pauseEmulator');
    if (r.running) throw new Error('The emulator is still running after pause');
    return r;
  }

  private async getCallstack(_params: any): Promise<any> {
    const frames = await this.bridge<any[]>('callStack');
    return { frames };
  }

  private async getRegisters(_params: any): Promise<any> {
    const r = await this.bridge<Record<string, number>>('registers');
    const fmt = (v: number, d: number) => ({ value: v, hex: hex(v, d) });
    const cc = r.CC;
    return {
      A: fmt(r.A, 2), B: fmt(r.B, 2), D: fmt(r.D, 4),
      X: fmt(r.X, 4), Y: fmt(r.Y, 4), U: fmt(r.U, 4), S: fmt(r.S, 4),
      PC: fmt(r.PC, 4), DP: fmt(r.DP, 2),
      CC: {
        ...fmt(cc, 2),
        flags: {
          E: (cc >> 7) & 1, F: (cc >> 6) & 1, H: (cc >> 5) & 1, I: (cc >> 4) & 1,
          N: (cc >> 3) & 1, Z: (cc >> 2) & 1, V: (cc >> 1) & 1, C: cc & 1,
        },
      },
    };
  }

  // ── Project ─────────────────────────────────────────────────────────────

  private async getProjectStructure(params: any): Promise<any> {
    const info = await this.requireProject();
    const { entries, truncated } = await walkProjectTree(info.rootDir, {
      maxDepth: optNumber(params.maxDepth, 'maxDepth', 6),
      maxEntries: optNumber(params.maxEntries, 'maxEntries', 2000),
    });
    return {
      name: info.name, root: info.rootDir, projectFile: info.projectFile,
      entry: info.entryPath, output: info.outputPath, isExternal: info.isExternal,
      count: entries.length, truncated, entries,
    };
  }

  private async readProjectFile(params: any): Promise<any> {
    const info = await this.requireProject();
    const rel = requireString(params.path, 'path');
    const abs = await resolveInsideRoot(info.rootDir, rel);
    let st;
    try { st = await fs.stat(abs); } catch { throw new Error(`File not found: ${rel}`); }
    if (!st.isFile()) throw new Error(`Not a file: ${rel}`);
    if (st.size > MAX_READ_FILE) throw new Error(`File too large (${st.size} bytes, max ${MAX_READ_FILE})`);
    const content = await fs.readFile(abs, 'utf-8');
    return { path: rel, fullPath: abs, size: st.size, content };
  }

  private async writeProjectFile(params: any): Promise<any> {
    const info = await this.requireProject();
    const rel = requireString(params.path, 'path');
    if (typeof params.content !== 'string') throw new Error('"content" is required and must be a string');
    const abs = await resolveInsideRoot(info.rootDir, rel);
    await fs.mkdir(path.dirname(abs), { recursive: true });
    await fs.writeFile(abs, params.content, 'utf-8');
    const st = await fs.stat(abs);
    const ed = await this.syncEditorWithFile(abs, params.content, st.mtimeMs, !!params.open);
    return { path: rel, fullPath: abs, size: st.size, uri: ed.uri, openedInEditor: ed.opened, refreshedInEditor: ed.refreshed };
  }

  private async openProject(params: any): Promise<any> {
    const target = requireString(params.path ?? params.projectPath, 'path');
    if (!path.isAbsolute(target)) throw new Error(`"path" must be absolute, got ${target}`);
    const projectFile = await findProjectFile(target);
    const opened = await this.bridge<any>('openProject', { projectFile });
    const info = await this.requireProject();
    if (!samePath(info.projectFile, projectFile)) {
      throw new Error(`The IDE reports ${info.projectFile} as open instead of ${projectFile}`);
    }
    if (!info.isExternal) {
      const main = await import('../main.js');
      const cur = main.getCurrentProject();
      if (!cur || !samePath(cur.rootDir, info.rootDir)) {
        throw new Error(`Project opened in the UI but the build system did not register it (does ${projectFile} have a [project] entry?)`);
      }
    }
    return { projectFile, rootDir: info.rootDir, name: info.name, isExternal: info.isExternal, entry: info.entryPath, openedDocuments: opened.openedDocuments };
  }

  private async closeProject(params: any): Promise<any> {
    const r = await this.bridge<any>('closeProject', { force: !!params.force });
    const main = await import('../main.js');
    main.setCurrentProject(null);
    return r;
  }

  private async createProject(params: any): Promise<any> {
    const name = requireString(params.name, 'name').trim();
    // No location: the default workspace (~/VectrexStudio/projects), created if missing.
    const { createProjectFromTemplate, ensureDefaultProjectsDir } = await import('../projectTemplates.js');
    const given = params.location ?? params.path;
    const location = given === undefined || given === '' ? await ensureDefaultProjectsDir() : requireString(given, 'location');
    if (!path.isAbsolute(location)) throw new Error(`"location" must be an absolute path, got ${location}`);
    const kind = params.kind === undefined || params.kind === null || params.kind === '' ? 'vpy' : params.kind;
    if (kind !== 'vpy' && kind !== 'c') throw new Error(`"kind" must be "vpy" or "c", got ${JSON.stringify(params.kind)}`);

    let sdkVersion: string | null = null;
    try {
      const { latestSdkTag } = await import('../sdkManager.js');
      sdkVersion = await latestSdkTag();
    } catch { /* offline and nothing installed: no pin; the first build pins one */ }

    const created = await createProjectFromTemplate({ kind, name, parentDir: location, sdkVersion });
    const opened = await this.openProject({ path: created.projectFile });
    return {
      ...opened, created: true, kind, projectDir: created.projectDir, entryFile: created.entryFile,
      sdkVersion, files: created.files.map((f) => path.relative(created.projectDir, f)),
      next: kind === 'c'
        ? 'ide_run {mode:"simulate"} runs it in the WASM simulator; settings_set_build_target rp2350|uvm2 + ide_run {mode:"run"} runs it on that cartridge\'s emulator.'
        : 'ide_run {mode:"run"} builds it for the selected target and runs it in the emulator.',
    };
  }

  // ── Assets ──────────────────────────────────────────────────────────────

  private async assetsList(params: any): Promise<any> {
    const info = await this.requireProject();
    const lang = projectLang(info.projectFile);
    const type = params.type === undefined || params.type === null || params.type === '' ? undefined : specFor(params.type).type;
    const scan = await scanProjectAssets(info.rootDir, lang, { type, maxPerType: optNumber(params.maxPerType, 'maxPerType', 100) });
    const out: any = { project: { name: info.name, language: lang, root: info.rootDir }, ...scan };
    if (lang === 'c') {
      out.makefileCompilesAssets = await makefileCompilesAssets(info.rootDir);
      out.howCUsesAssets = out.makefileCompilesAssets
        ? 'The Makefile compiles each asset to gen/<name>.h with `vpy_cli compile-asset`; #include it and pass its arrays to the vpy.h calls shown in "usage".'
        : 'This Makefile does not compile assets/ (no `vpy_cli compile-asset` rule): add one (see docs/ASSETS.md, or a new C project\'s Makefile) before using assets.';
    } else {
      out.howVpyUsesAssets = 'The compiler embeds every asset the code names (the string literal = file name without extension); assets are found by folder.';
    }
    out.next = 'Reuse these assets. For new art, sound, levels or animation create assets with asset_create (formats: asset_get_format) instead of hard-coding them.';
    return out;
  }

  private async assetGetFormat(params: any): Promise<any> {
    const spec = specFor(params.type);
    return {
      type: spec.type, ext: spec.ext, title: spec.title, folder: spec.dir + '/', editor: spec.editor, targets: spec.targets,
      format: spec.format,
      example: spec.example('example'),
      usage: {
        vpy: spec.vpy.usable ? spec.vpy.usage('example', { is3d: false, hasEnemies: spec.type === 'vplay' }) : null,
        vpyNote: spec.vpy.note ?? null,
        c: spec.c.usable ? spec.c.usage('example', { hasEnemies: spec.type === 'vplay' }) : null,
        cNote: spec.c.note ?? null,
      },
      reference: 'docs/ASSETS.md',
    };
  }

  private async assetCreate(params: any): Promise<any> {
    const spec = specFor(params.type);
    const open = params.open === undefined ? spec.type !== 'vplay' : !!params.open;
    return this.createAssetFile(spec, params.name, params.content, !!params.overwrite, open);
  }

  /** Write, compile-check and (on failure) roll back one asset. */
  private async createAssetFile(spec: AssetSpec, rawName: unknown, content: unknown, overwrite: boolean, open: boolean, warnings: string[] = []): Promise<any> {
    const info = await this.requireProject();
    const lang = projectLang(info.projectFile);
    const name = newAssetName(rawName, spec.ext);
    const side = lang === 'c' ? spec.c : spec.vpy;
    if (!side.usable) {
      throw new Error(`.${spec.type} assets cannot be used from a ${lang === 'c' ? 'C' : 'VPy'} project: ${side.note || ''}`.trim());
    }

    let json: any;
    if (typeof content === 'string') {
      if (!content.trim()) throw new Error('"content" is empty: pass the asset JSON (see asset_get_format)');
      try { json = JSON.parse(content); } catch (e: any) { throw new Error(`"content" is not valid JSON: ${e.message}`); }
    } else if (content && typeof content === 'object' && !Array.isArray(content)) {
      json = content;
    } else {
      throw new Error('"content" is required: the asset as a JSON object or JSON text (see asset_get_format)');
    }
    if (!json || typeof json !== 'object' || Array.isArray(json)) throw new Error('"content" must be a JSON object');
    json = JSON.parse(JSON.stringify(json));
    if (normaliseName(spec, json, name)) warnings.push(`set ${spec.nameField} to "${name}" (the file name; code refers to the asset by it)`);

    const rel = `${spec.dir}/${name}${spec.ext}`;
    const abs = await resolveInsideRoot(info.rootDir, rel);
    const bad = structuralErrors(spec, json);
    if (bad.length) throw new Error(`${rel} is not a valid ${spec.ext} (nothing was written): ${bad.join('; ')} (see asset_get_format)`);
    const missing = missingReferences(spec, json, info.rootDir, path.dirname(abs));
    if (missing.length) {
      throw new Error(`${rel} references assets that do not exist (create them first): ${missing.join('; ')}`);
    }

    let previous: string | null = null;
    try { previous = await fs.readFile(abs, 'utf-8'); } catch (e: any) { if (e?.code !== 'ENOENT') throw e; }
    if (previous !== null && !overwrite) throw new Error(`${rel} already exists (pass overwrite=true to replace it)`);

    const text = JSON.stringify(json, null, 2) + '\n';
    await fs.mkdir(path.dirname(abs), { recursive: true });
    await fs.writeFile(abs, text, 'utf-8');

    const cli = resolveVpyCli();
    let validatedBy = 'JSON only (vpy_cli not found)';
    let compilerSummary: string | undefined;
    if (cli) {
      const r = await compileCheck(cli, abs, spec, lang);
      if (!r.ok) {
        if (previous !== null) await fs.writeFile(abs, previous, 'utf-8');
        else await fs.rm(abs, { force: true });
        throw new Error(`${rel} does not compile (${r.validatedBy}): ${r.error}${previous !== null ? ' — the previous file was restored' : ' — nothing was written'}`);
      }
      validatedBy = r.validatedBy;
      compilerSummary = r.summary;
    } else {
      warnings.push('vpy_cli was not found, so the asset was not compile-checked');
    }

    const st = await fs.stat(abs);
    const ed = await this.syncEditorWithFile(abs, text, st.mtimeMs, open);
    const { summary, meta } = await summarizeAsset(spec, abs);
    if (lang === 'c' && !(await makefileCompilesAssets(info.rootDir))) {
      warnings.push('this project\'s Makefile has no `vpy_cli compile-asset` rule, so the C code cannot include this asset yet (see docs/ASSETS.md)');
    } else if (lang === 'c' && spec.type !== 'venemy' && !(await makefileCompilesExt(info.rootDir, spec.ext))) {
      // (.venemy has no rule of its own in C: a level's header carries its enemies)
      warnings.push(`this project's Makefile compiles assets but has no rule for ${spec.ext} (gen/%.h: %${spec.ext}), so the C code cannot include this asset yet: copy that rule and its ${spec.dir} wildcard from a new C project's Makefile (see docs/ASSETS.md)`);
    }
    return {
      created: previous === null, replaced: previous !== null, type: spec.type, name,
      path: rel, filePath: abs, relativePath: rel, size: st.size, uri: ed.uri, openedInEditor: ed.opened || ed.refreshed,
      editor: spec.editor,
      validatedBy, summary: compilerSummary || summary,
      usage: side.usage(name, meta),
      ...(warnings.length ? { warnings } : {}),
    };
  }

  private async createVector(params: any): Promise<any> {
    const spec = specFor('vec');
    const name = newAssetName(params.name, '.vec');
    const content = params.content || spec.example(name);
    return this.createAssetFile(spec, name, content, !!params.overwrite, true);
  }

  private async createMusic(params: any): Promise<any> {
    const spec = specFor('vmus');
    const name = newAssetName(params.name, '.vmus');
    let content: any = params.content;
    if (content) {
      const bytes = Buffer.byteLength(String(content), 'utf-8');
      if (bytes > 16384) throw new Error(`Music file too large (${Math.round(bytes / 1024)} KB, max 16 KB here). Use fewer notes and loopStart/loopEnd, or asset_create.`);
      let parsed: any;
      try { parsed = JSON.parse(content); } catch (e: any) { throw new Error(`.vmus content must be JSON: ${e.message}`); }
      const events = (parsed?.notes?.length || 0) + (parsed?.noise?.length || 0);
      if (events > 120) throw new Error(`Too many events (${events}); max 120 notes+noise here — loop a shorter phrase instead, or use asset_create.`);
    } else {
      content = { version: '1.0', name, author: '', tempo: 120, ticksPerBeat: 24, totalTicks: 384, notes: [], noise: [], loopStart: 0, loopEnd: 384 };
    }
    return this.createAssetFile(spec, name, content, !!params.overwrite, true);
  }

  private async createSfx(params: any): Promise<any> {
    const spec = specFor('vsfx');
    const name = newAssetName(params.name, '.vsfx');
    return this.createAssetFile(spec, name, params.content || spec.example(name), !!params.overwrite, true);
  }
}

// Singleton instance
let mcpServer: MCPServer | null = null;

export function getMCPServer(): MCPServer {
  if (!mcpServer) {
    mcpServer = new MCPServer();
  }
  return mcpServer;
}
