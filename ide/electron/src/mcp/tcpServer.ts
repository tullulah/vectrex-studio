// Localhost TCP endpoint for the stdio MCP server (ide/mcp-server/server.js).
//
// Wire format: newline-delimited JSON-RPC 2.0, one message per line, both ways.
// The FIRST line a client sends must be
//   {"jsonrpc":"2.0","id":0,"method":"auth","params":{"token":"<getMcpToken()>"}}
// It gets {"result":{"ok":true,...}} back; anything else gets an error reply and the
// socket is closed. Nothing else is processed on an unauthenticated socket.

import * as net from 'net';
import { MCP_PORT_CANDIDATES, isValidMcpToken, setMcpPort } from './auth.js';
import type { MCPRequest, MCPResponse } from './types.js';
import { ErrorCodes } from './types.js';

export type McpRequestHandler = (request: MCPRequest) => Promise<MCPResponse>;

const MAX_LINE_BYTES = 32 * 1024 * 1024; // generous: write_document carries whole files
const AUTH_TIMEOUT_MS = 5000;

let server: net.Server | null = null;
let starting: Promise<number | null> | null = null;
const clients = new Set<net.Socket>();

/** Best-effort id recovery from a line that failed to parse, so the client can match the error. */
function salvageId(line: string): string | number | null {
  const m = /"id"\s*:\s*(-?\d+|"(?:[^"\\]|\\.)*")/.exec(line);
  if (!m) return null;
  try { return JSON.parse(m[1]); } catch { return null; }
}

function errorReply(id: string | number | null, code: number, message: string): MCPResponse {
  return { jsonrpc: '2.0', id, error: { code, message } };
}

function attachClient(socket: net.Socket, handle: McpRequestHandler, verbose: boolean) {
  let authed = false;
  let buffer = '';
  const send = (msg: MCPResponse) => {
    if (!socket.destroyed) socket.write(JSON.stringify(msg) + '\n');
  };
  const reject = (id: string | number | null, message: string) => {
    send(errorReply(id, ErrorCodes.Unauthorized, message));
    socket.end();
    // Make sure a misbehaving client cannot keep the socket half-open.
    setTimeout(() => socket.destroy(), 200).unref();
  };

  const authTimer = setTimeout(() => {
    if (!authed) reject(null, 'Authentication timeout: the first message must be an "auth" request');
  }, AUTH_TIMEOUT_MS);
  authTimer.unref();

  const processLine = (line: string) => {
    let req: any;
    try {
      req = JSON.parse(line);
    } catch (e: any) {
      if (!authed) return reject(null, 'Unauthorized: first message is not valid JSON');
      return send(errorReply(salvageId(line), ErrorCodes.ParseError, `Parse error: ${e.message}`));
    }
    const id: string | number | null =
      req && (typeof req.id === 'string' || typeof req.id === 'number') ? req.id : null;

    if (!authed) {
      if (req?.method !== 'auth' || !isValidMcpToken(req?.params?.token)) {
        if (verbose) console.warn('[MCP TCP] rejected client: bad or missing auth');
        return reject(id, 'Unauthorized: invalid or missing token');
      }
      authed = true;
      clearTimeout(authTimer);
      send({ jsonrpc: '2.0', id, result: { ok: true, server: 'vectrex-studio' } });
      return;
    }

    if (!req || typeof req !== 'object' || typeof req.method !== 'string') {
      return send(errorReply(id, ErrorCodes.InvalidRequest, 'Invalid request: missing "method"'));
    }
    if (req.method === 'auth') {
      return send({ jsonrpc: '2.0', id, result: { ok: true, server: 'vectrex-studio' } });
    }

    handle({ jsonrpc: '2.0', id, method: req.method, params: req.params ?? {} })
      .then(send)
      .catch((e: any) => send(errorReply(id, ErrorCodes.InternalError, e?.message || String(e))));
  };

  socket.setEncoding('utf8');
  socket.on('data', (chunk: string) => {
    buffer += chunk;
    if (buffer.length > MAX_LINE_BYTES) {
      send(errorReply(null, ErrorCodes.InvalidRequest, 'Message too large'));
      socket.destroy();
      return;
    }
    let nl: number;
    while ((nl = buffer.indexOf('\n')) !== -1) {
      const line = buffer.slice(0, nl).trim();
      buffer = buffer.slice(nl + 1);
      if (line) processLine(line);
      if (socket.destroyed) return;
    }
  });
  socket.on('error', (err) => { if (verbose) console.warn('[MCP TCP] socket error:', err.message); });
  socket.on('close', () => clearTimeout(authTimer));
}

function listenOn(srv: net.Server, port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const onError = (err: any) => {
      srv.removeListener('listening', onListening);
      if (err?.code !== 'EADDRINUSE' && err?.code !== 'EACCES') {
        console.error(`[MCP TCP] listen on ${port} failed:`, err?.message || err);
      }
      resolve(false);
    };
    const onListening = () => {
      srv.removeListener('error', onError);
      resolve(true);
    };
    srv.once('error', onError);
    srv.once('listening', onListening);
    srv.listen(port, '127.0.0.1');
  });
}

/**
 * Start the MCP TCP server on 127.0.0.1, on the first free port of 9123..9133.
 * Resolves to the bound port (also available via getMcpPort()), or null if none was free.
 * Idempotent.
 */
export function startMcpTcpServer(handle: McpRequestHandler, ports: number[] = MCP_PORT_CANDIDATES): Promise<number | null> {
  if (starting) return starting;
  const verbose = process.env.VPY_IDE_VERBOSE_LSP === '1' || process.env.MCP_VERBOSE === '1';
  starting = (async () => {
    const srv = net.createServer((socket) => {
      clients.add(socket);
      socket.on('close', () => clients.delete(socket));
      attachClient(socket, handle, verbose);
    });
    for (const port of ports) {
      if (await listenOn(srv, port)) {
        server = srv;
        setMcpPort(port);
        srv.on('error', (err) => console.error('[MCP TCP] server error:', err.message));
        console.log(`[MCP TCP] listening on 127.0.0.1:${port}`);
        return port;
      }
    }
    console.error(`[MCP TCP] no free port in ${ports[0]}..${ports[ports.length - 1]}; MCP bridge disabled`);
    setMcpPort(null);
    starting = null;
    return null;
  })();
  return starting;
}

/** Close the listener and every connected client. */
export function stopMcpTcpServer(): void {
  if (server) {
    server.close();
    server = null;
  }
  for (const s of clients) s.destroy();
  clients.clear();
  starting = null;
  setMcpPort(null);
}
