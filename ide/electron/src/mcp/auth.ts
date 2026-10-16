// MCP bridge credentials and launch spec.
//
// The IDE listens for the stdio MCP server (ide/mcp-server/server.js) on a
// localhost TCP port. Every connection must authenticate with a random token
// generated here at IDE startup; it never leaves memory except through
// getMcpLaunchSpec(), which hands it to the process the IDE itself launches
// (e.g. Claude Code in the integrated terminal) via environment variables.

import { randomBytes } from 'crypto';
import { join } from 'path';

export const MCP_DEFAULT_PORT = 9123;
/** Ports tried in order when the default one is taken: 9123..9133. */
export const MCP_PORT_CANDIDATES: number[] = Array.from({ length: 11 }, (_, i) => MCP_DEFAULT_PORT + i);

export const MCP_ENV_PORT = 'VECTREX_STUDIO_MCP_PORT';
export const MCP_ENV_TOKEN = 'VECTREX_STUDIO_MCP_TOKEN';

const token: string = randomBytes(32).toString('hex');
let boundPort: number | null = null;

/** The 64-hex-char token a TCP client must send in its first `auth` line. */
export function getMcpToken(): string {
  return token;
}

/** The port the MCP TCP server is actually listening on (null until it is listening). */
export function getMcpPort(): number | null {
  return boundPort;
}

/** @internal set by the TCP server once listen() succeeds. */
export function setMcpPort(port: number | null): void {
  boundPort = port;
}

/** Constant-time token comparison. */
export function isValidMcpToken(candidate: unknown): boolean {
  if (typeof candidate !== 'string' || candidate.length !== token.length) return false;
  let diff = 0;
  for (let i = 0; i < token.length; i++) diff |= token.charCodeAt(i) ^ candidate.charCodeAt(i);
  return diff === 0;
}

function isPackagedApp(): boolean {
  try {
    // Lazy require so this module can also be loaded outside Electron (tests).
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { app } = require('electron');
    return !!app?.isPackaged;
  } catch {
    return false;
  }
}

/**
 * Absolute path of the stdio MCP server script for this install.
 * Packaged: `<resources>/mcp-server/server.js` (electron-builder extraResources).
 * Dev: `ide/mcp-server/server.js` (this file compiles to ide/electron/dist/mcp/auth.js).
 */
export function getMcpServerScriptPath(): string {
  if (isPackagedApp()) return join(process.resourcesPath, 'mcp-server', 'server.js');
  return join(__dirname, '..', '..', '..', 'mcp-server', 'server.js');
}

/**
 * How to start the stdio MCP server so it talks to THIS running IDE.
 *
 * The command is the Electron binary itself run as plain Node
 * (ELECTRON_RUN_AS_NODE=1), so no system Node install is needed — packaged or dev.
 * `env` must be merged into the child's environment.
 */
export function getMcpLaunchSpec(): { command: string; args: string[]; env: Record<string, string> } {
  return {
    command: process.execPath,
    args: [getMcpServerScriptPath()],
    env: {
      ELECTRON_RUN_AS_NODE: '1',
      [MCP_ENV_PORT]: String(boundPort ?? MCP_DEFAULT_PORT),
      [MCP_ENV_TOKEN]: token,
    },
  };
}
