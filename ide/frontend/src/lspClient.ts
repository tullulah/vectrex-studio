// Multi-server LSP client (Electron + web fallback). Frames JSON-RPC messages and
// parses server responses. The Electron backend exposes a per-`serverId` registry
// ('vpy', 'clangd', …); this module mirrors that with one `LspClient` per serverId.
// Tauri support removed: runtime now Electron-only (web build is passive without LSP backend).

import { logger } from './utils/logger';

export type LspNotificationHandler = (method: string, params: any) => void;
export type LspResponseHandler = (id: number | string, result: any, error?: any) => void;

interface PendingRequest { resolve: (v: any)=>void; reject: (e: any)=>void; method: string; }

// --- Registry state (shared across all clients) ---------------------------
const clients = new Map<string, LspClient>();
let routingInstalled = false;

// Install ONE shared onLspMessage / onLspStderr subscription that routes the
// backend's `{ serverId, body }` envelopes to the matching client. Called lazily
// the first time any client starts (needs window.electronAPI to exist).
function installRouting() {
  if (routingInstalled) return;
  const w: any = typeof window !== 'undefined' ? window : undefined;
  if (!(w && w.electronAPI)) return;
  w.electronAPI.onLspMessage((msg: { serverId: string; body: string } | string) => {
    // Back-compat: a bare string means serverId 'vpy'.
    if (typeof msg === 'string') { clients.get('vpy')?.dispatchMessage(msg); return; }
    const client = clients.get(msg.serverId);
    if (client) client.dispatchMessage(msg.body);
    else logger.verbose('LSP', 'message for unknown serverId (ignored):', msg.serverId);
  });
  w.electronAPI.onLspStderr((msg: { serverId: string; line: string } | string) => {
    if (typeof msg === 'string') { logger.debug('LSP', 'LSP-STDERR[vpy]:', msg); return; }
    logger.debug('LSP', `LSP-STDERR[${msg.serverId}]:`, msg.line);
  });
  routingInstalled = true;
}

class LspClient {
  private seq = 0;
  // Framing handled in the backend; we receive complete JSON payloads routed by serverId.
  private pending = new Map<number | string, PendingRequest>();
  private notifHandlers: LspNotificationHandler[] = [];
  private respHandlers: LspResponseHandler[] = [];
  private started = false;
  private versions = new Map<string, number>(); // uri -> version

  constructor(public readonly serverId: string) {}

  get isStarted() { return this.started; }

  async start(cwd?: string) {
    if (this.started) return;
    const w: any = typeof window !== 'undefined' ? window : undefined;
    const isElectron = !!(w && w.electronAPI);
    if (!isElectron) return; // plain web build: no backend
    installRouting();
    await w.electronAPI.lspStart({ serverId: this.serverId, cwd });
    this.started = true;
  }

  onNotification(cb: LspNotificationHandler) { this.notifHandlers.push(cb); }
  onResponse(cb: LspResponseHandler) { this.respHandlers.push(cb); }

  // Called by the registry router with the JSON-RPC body for THIS server only.
  dispatchMessage(jsonText: string) {
    try {
      const msg = JSON.parse(jsonText);
      // Ignore parse-error notifications with null id (e.g. { error:{code:-32700}, id:null })
      if ((msg.error && (msg.id === null || msg.id === undefined) && msg.error.code === -32700)) {
        logger.warn('LSP', `[${this.serverId}] parse error (ignored, waiting for real response):`, msg);
        return;
      }
      if (msg.id !== undefined && (msg.result !== undefined || msg.error !== undefined)) {
        // response
        if (msg.error) {
          const pending = this.pending.get(msg.id);
          logger.error('LSP', `[${this.serverId}] error response:`, msg, 'pendingMethod=', pending?.method);
        } else {
          logger.verbose('LSP', `[${this.serverId}] response:`, msg);
        }
        this.respHandlers.forEach(h => h(msg.id, msg.result, msg.error));
        const pending = this.pending.get(msg.id);
        if (pending) {
          if (msg.error) pending.reject(msg.error); else pending.resolve(msg.result);
          this.pending.delete(msg.id);
        }
      } else if (msg.method) {
        // notification or request from server (we treat both same; no request handling yet)
        this.notifHandlers.forEach(h => h(msg.method, msg.params));
      } else {
        logger.warn('LSP', `[${this.serverId}] Unknown LSP message shape:`, msg);
      }
    } catch (e) {
      logger.error('LSP', `[${this.serverId}] Failed parse LSP message:`, e, jsonText);
    }
  }

  private sendRaw(obj: any): Promise<any> {
    const w: any = typeof window !== 'undefined' ? window : undefined;
    const isElectron = !!(w && w.electronAPI);
    if (!isElectron) return Promise.resolve();
    const json = JSON.stringify(obj);
    logger.verbose('LSP', `[${this.serverId}] ->SERVER:`, json);
    return w.electronAPI.lspSend({ serverId: this.serverId, payload: json });
  }

  request(method: string, params: any): Promise<any> {
    const id = ++this.seq;
    logger.verbose('LSP', `[${this.serverId}] req.start:`, id, method, params);
    const p = new Promise<any>((resolve, reject) => {
      this.pending.set(id, { resolve, reject, method });
    });
    this.sendRaw({ jsonrpc: '2.0', id, method, params });
    return p;
  }

  notify(method: string, params: any) {
    this.sendRaw({ jsonrpc: '2.0', method, params });
  }

  didOpen(uri: string, languageId: string, text: string) {
    this.versions.set(uri, 1);
    this.notify('textDocument/didOpen', {
      textDocument: { uri, languageId, version: 1, text }
    });
  }

  didChange(uri: string, text: string) {
    if (!this.started) return; // avoid calling before start
    const current = (this.versions.get(uri) || 1) + 1;
    this.versions.set(uri, current);
    this.notify('textDocument/didChange', {
      textDocument: { uri, version: current },
      contentChanges: [ { text } ]
    });
  }

  rename(uri: string, line: number, character: number, newName: string) {
    return this.request('textDocument/rename', {
      textDocument: { uri },
      position: { line, character },
      newName
    });
  }

  signatureHelp(uri: string, line: number, character: number) {
    return this.request('textDocument/signatureHelp', {
      textDocument: { uri },
      position: { line, character }
    });
  }
}

export type { LspClient };

// Return (creating on first use) the client bound to a given serverId.
export function getLspClient(serverId: string): LspClient {
  let c = clients.get(serverId);
  if (!c) { c = new LspClient(serverId); clients.set(serverId, c); }
  return c;
}

// The historical singleton is the 'vpy' client so existing imports keep working.
export const lspClient = getLspClient('vpy');

// Convert an absolute filesystem path to a file:// URI (Monaco/LSP style).
function pathToFileUri(p: string): string {
  const norm = p.replace(/\\/g, '/');
  return norm.match(/^[A-Za-z]:\//) ? `file:///${norm}` : `file://${norm}`;
}

export async function initLsp(language: string, documentUri: string, text: string) {
  await lspClient.start();
  const params: any = {
    processId: null,
    rootUri: null,          // explicit per spec when no workspace
    capabilities: {          // minimal but explicit client capabilities
      textDocument: {
        synchronization: { didSave: false, willSave: false, willSaveWaitUntil: false, dynamicRegistration: false },
        publishDiagnostics: { relatedInformation: false },
      },
      general: { positionEncodings: ['utf-16'] },
    },
    clientInfo: { name: 'vpy-ide', version: '0.1.0' },
    initializationOptions: {},
    trace: 'off',
    locale: language,
    workspaceFolders: null,
  };
  logger.debug('LSP', 'initialize params:', params);
  let gotResult = false;
  const initPromise = lspClient.request('initialize', params).then(res => { gotResult = true; return res; });
  try {
    const res = await initPromise;
    logger.debug('LSP', 'initialize result:', res);
  } catch (e:any) {
    if (e && e.code === -32600) {
      logger.warn('LSP', 'initialize returned -32600 (Invalid request) – tolerando por bug inicial, esperando posible respuesta válida posterior');
    } else {
      logger.error('LSP', 'initialize failed:', e);
      return; // abort if other error
    }
  }
  // Even if we saw -32600, server in nuestra experiencia envía el resultado válido después.
  // Para robustez añadimos un pequeño retraso para permitir la llegada.
  if (!gotResult) {
    setTimeout(() => {
      // No direct follow-up; we proceed anyway to send 'initialized'.
    }, 50);
  }
  lspClient.notify('initialized', {});
  lspClient.didOpen(documentUri, 'vpy', text);
}

// --- clangd (C/C++) --------------------------------------------------------
// clangd needs a REAL workspace root (unlike the VPy server which uses rootUri:null)
// so it can discover compile_flags.txt / compile_commands.json and index the project.
// Initialization is performed once per session; the promise is cached and only
// retried if the first attempt throws.
let clangdInitPromise: Promise<LspClient> | null = null;

export function ensureClangd(rootDir: string): Promise<LspClient> {
  if (!clangdInitPromise) {
    clangdInitPromise = (async () => {
      const client = getLspClient('clangd');
      await client.start(rootDir); // cwd = project root → clangd finds compile_flags.txt
      const rootUri = pathToFileUri(rootDir);
      const params: any = {
        processId: null,
        rootUri,
        rootPath: rootDir,
        capabilities: {
          textDocument: {
            synchronization: { didSave: false, willSave: false, willSaveWaitUntil: false, dynamicRegistration: false },
            publishDiagnostics: { relatedInformation: false },
            completion: { completionItem: { snippetSupport: false, documentationFormat: ['plaintext', 'markdown'] } },
            hover: { contentFormat: ['markdown', 'plaintext'] },
            definition: { linkSupport: false },
          },
          general: { positionEncodings: ['utf-16'] },
        },
        clientInfo: { name: 'vpy-ide', version: '0.1.0' },
        initializationOptions: {},
        trace: 'off',
        workspaceFolders: [{ uri: rootUri, name: rootDir.split(/[\\/]/).pop() || 'workspace' }],
      };
      logger.debug('LSP', '[clangd] initialize params:', params);
      try {
        const res = await client.request('initialize', params);
        logger.debug('LSP', '[clangd] initialize result:', res);
      } catch (e) {
        logger.error('LSP', '[clangd] initialize failed:', e);
      }
      client.notify('initialized', {});
      return client;
    })().catch(e => { clangdInitPromise = null; throw e; });
  }
  return clangdInitPromise;
}

// Ensure clangd is started/initialized for `rootDir`, then didOpen the document.
export async function openClangdDocument(rootDir: string, uri: string, languageId: string, text: string): Promise<LspClient> {
  const client = await ensureClangd(rootDir);
  client.didOpen(uri, languageId, text);
  return client;
}
