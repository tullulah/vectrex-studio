#!/usr/bin/env node
/**
 * End-to-end test of the MCP bridge without the GUI:
 *
 *   this test ⇄ stdio ⇄ server.js ⇄ TCP ⇄ the IDE's real tcpServer + MCPServer
 *                                          (compiled from ide/electron/src/mcp, with a
 *                                           fake BrowserWindow whose executeJavaScript
 *                                           runs the script in a vm sandbox)
 *
 * Prerequisite: `cd ide/electron && npm run build` (uses ide/electron/dist/mcp/*.js).
 * Run: node ide/mcp-server/test/run-tests.js
 */
'use strict';

const assert = require('assert');
const net = require('net');
const path = require('path');
const fs = require('fs');
const vm = require('vm');
const { spawn } = require('child_process');

const DIST = path.join(__dirname, '..', '..', 'electron', 'dist', 'mcp');
const SERVER_JS = path.join(__dirname, '..', 'server.js');
for (const f of ['auth.js', 'tcpServer.js', 'server.js']) {
  if (!fs.existsSync(path.join(DIST, f))) {
    console.error(`Missing ${path.join(DIST, f)} — run "cd ide/electron && npm run build" first.`);
    process.exit(2);
  }
}
const auth = require(path.join(DIST, 'auth.js'));
const tcp = require(path.join(DIST, 'tcpServer.js'));
const { MCPServer } = require(path.join(DIST, 'server.js'));

let passed = 0;
let failed = 0;
async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ok   ${name}`);
  } catch (e) {
    failed++;
    console.log(`  FAIL ${name}\n       ${(e && e.stack || e).toString().split('\n').slice(0, 4).join('\n       ')}`);
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.once('error', reject);
    s.listen(0, '127.0.0.1', () => { const p = s.address().port; s.close(() => resolve(p)); });
  });
}

// ── Fake renderer: window.__mcpBridge__ inside a vm sandbox ────────────────
const EVIL = "evil.vpy');globalThis.pwned=1;(function(){// \"`${x}`";
const bridgeCalls = [];
// Mutable renderer state the fake bridge reads/writes (project, settings, next build outcome).
const fake = {
  project: null,          // ProjectInfo when a project is "open"
  buildTarget: 'm6809',
  nextRun: null,          // value runBuild returns
  opened: [],             // URIs openDocument was asked to open
};
const fakeEmulator = (running) => ({ panelOpen: true, backend: running ? 'sim' : null, backendLabel: null, running: !!running, debugState: 'stopped', loadedProgram: null, lastLoad: null, simulator: null });
const sandbox = {
  window: {
    __mcpBridge__: {
      invoke: async (fn, args) => {
        bridgeCalls.push({ fn, args });
        switch (fn) {
          case 'projectInfo': return { ok: true, value: fake.project ? { open: true, ...fake.project } : { open: false } };
          case 'openProject': {
            const pf = args.projectFile;
            const ext = /\.cvproj$/i.test(pf);
            const rootDir = path.dirname(pf);
            fake.project = {
              projectFile: pf, rootDir, name: path.basename(pf).replace(/\.(cvproj|vpyproj)$/i, ''), isExternal: ext,
              entryPath: path.join(rootDir, 'src', ext ? 'main.c' : 'main.vpy'), outputPath: null,
            };
            return { ok: true, value: { projectFile: pf, rootDir, name: fake.project.name, isExternal: ext, openedDocuments: 1 } };
          }
          case 'ideState': return { ok: true, value: {
            buildTarget: fake.buildTarget, rp2350BuildMode: 'flash', rp2350FlashMethod: 'none',
            pitrexCopyToSD: false, uvm2CopyToSD: false, projectTarget: null, emulator: fakeEmulator(false), buildRunnerReady: true,
          } };
          case 'setBuildTarget': {
            if (!['m6809', 'rp2350', 'pitrex', 'uvm2'].includes(args.target)) return { ok: false, error: `Unknown build target "${args.target}"` };
            const previous = fake.buildTarget;
            fake.buildTarget = args.target;
            return { ok: true, value: { previous, buildTarget: fake.buildTarget } };
          }
          case 'runBuild': return fake.nextRun ? { ok: true, value: { mode: args.mode, ...fake.nextRun } } : { ok: false, error: 'fake bridge: no build configured' };
          case 'listDocuments': return { ok: true, value: [
            { uri: 'file:///proj/src/main.vpy', language: 'vpy', dirty: false, diskPath: '/proj/src/main.vpy', active: true },
            { uri: EVIL, language: 'vpy', dirty: true, diskPath: null, active: false },
          ] };
          case 'getDocument': return { ok: true, value: { uri: args.uri, content: 'line1\nline2', language: 'vpy', dirty: false, diskPath: null, mtime: null } };
          case 'openDocument': fake.opened.push(args.uri); return { ok: true, value: true };
          case 'refreshDocument': return { ok: true, value: true };
          default: return { ok: false, error: `fake bridge: ${fn} not implemented` };
        }
      },
    },
  },
};
vm.createContext(sandbox);
const fakeWindow = {
  isDestroyed: () => false,
  webContents: { executeJavaScript: async (script) => vm.runInContext(script, sandbox) },
};

const ideServer = new MCPServer();
ideServer.setMainWindow(fakeWindow);
const handler = (req) => ideServer.handleRequest(req);

// ── stdio MCP client ───────────────────────────────────────────────────────
class StdioClient {
  constructor(env, command = process.execPath, extraEnv = {}) {
    this.proc = spawn(command, [SERVER_JS], { env: { ...process.env, ...extraEnv, ...env }, stdio: ['pipe', 'pipe', 'pipe'] });
    this.buf = '';
    this.waiters = new Map();
    this.notifications = [];
    this.raw = [];
    this.nextId = 1;
    this.stderr = '';
    this.proc.stderr.on('data', (d) => { this.stderr += d; });
    this.proc.stdout.setEncoding('utf8');
    this.proc.stdout.on('data', (chunk) => {
      this.buf += chunk;
      let nl;
      while ((nl = this.buf.indexOf('\n')) !== -1) {
        const line = this.buf.slice(0, nl);
        this.buf = this.buf.slice(nl + 1);
        if (!line.trim()) continue;
        const msg = JSON.parse(line); // server must only ever print JSON on stdout
        this.raw.push(msg);
        if (msg.id !== undefined && this.waiters.has(msg.id)) { this.waiters.get(msg.id)(msg); this.waiters.delete(msg.id); }
        else if (msg.method) this.notifications.push(msg);
      }
    });
  }
  sendRaw(text) { this.proc.stdin.write(text + '\n'); }
  notify(method, params) { this.sendRaw(JSON.stringify({ jsonrpc: '2.0', method, params })); }
  request(method, params, timeoutMs = 10000) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error(`timeout waiting for ${method}`)), timeoutMs);
      this.waiters.set(id, (m) => { clearTimeout(t); resolve(m); });
      this.sendRaw(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
    });
  }
  async callTool(name, args) {
    const r = await this.request('tools/call', { name, arguments: args || {} });
    assert.ok(r.result, `tools/call ${name} must return a result, got ${JSON.stringify(r)}`);
    return r.result;
  }
  async waitNotification(method, timeoutMs) {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      if (this.notifications.some((n) => n.method === method)) return true;
      await sleep(50);
    }
    return false;
  }
  alive() { return this.proc.exitCode === null && !this.proc.killed; }
  kill() { this.proc.kill(); }
}

// ── Raw TCP client (to test the IDE endpoint directly) ─────────────────────
function tcpSession(port) {
  const sock = net.createConnection({ host: '127.0.0.1', port });
  sock.setEncoding('utf8');
  let buf = '';
  const lines = [];
  let closed = false;
  sock.on('data', (d) => { buf += d; let nl; while ((nl = buf.indexOf('\n')) !== -1) { lines.push(JSON.parse(buf.slice(0, nl))); buf = buf.slice(nl + 1); } });
  sock.on('close', () => { closed = true; });
  sock.on('error', () => {});
  return {
    send: (obj) => sock.write((typeof obj === 'string' ? obj : JSON.stringify(obj)) + '\n'),
    next: async (timeoutMs = 3000) => {
      const deadline = Date.now() + timeoutMs;
      while (!lines.length && Date.now() < deadline) await sleep(10);
      if (!lines.length) throw new Error('no line received');
      return lines.shift();
    },
    waitClosed: async (timeoutMs = 3000) => {
      const deadline = Date.now() + timeoutMs;
      while (!closed && Date.now() < deadline) await sleep(10);
      return closed;
    },
    end: () => sock.destroy(),
  };
}

(async () => {
  const portA = await freePort();
  let portB = await freePort();
  while (portB === portA) portB = await freePort();
  const TOKEN = auth.getMcpToken();

  console.log('MCP bridge tests');

  await test('token is 32 random bytes (64 hex chars)', () => {
    assert.match(TOKEN, /^[0-9a-f]{64}$/);
  });

  // ── Pure helpers ─────────────────────────────────────────────────────────
  const paths = require(path.join(DIST, 'paths.js'));
  const os = require('os');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'vs-mcp-'));
  const root = path.join(tmp, 'Game');
  fs.mkdirSync(path.join(root, 'src'), { recursive: true });
  fs.writeFileSync(path.join(root, 'Other.vpyproj'), '[project]\nname="x"\nentry="src/main.vpy"\n');
  fs.writeFileSync(path.join(root, 'src', 'main.vpy'), 'def main():\n    pass\n');
  fs.mkdirSync(path.join(tmp, 'outside'));
  fs.symlinkSync(path.join(tmp, 'outside'), path.join(root, 'escape'));

  await test('resolveInsideRoot: relative paths inside are accepted', async () => {
    assert.strictEqual(await paths.resolveInsideRoot(root, 'src/new/x.vpy'), path.join(root, 'src/new/x.vpy'));
  });
  await test('resolveInsideRoot: ../ and absolute paths outside are rejected', async () => {
    await assert.rejects(paths.resolveInsideRoot(root, '../outside/x'), /outside the project root/);
    await assert.rejects(paths.resolveInsideRoot(root, '/etc/passwd'), /outside the project root/);
    await assert.rejects(paths.resolveInsideRoot(root, path.join(root, '..', 'Game2', 'x')), /outside the project root/);
  });
  await test('resolveInsideRoot: a symlink pointing outside is rejected', async () => {
    await assert.rejects(paths.resolveInsideRoot(root, 'escape/x.txt'), /outside the project root/);
  });
  await test('findProjectFile: directory with one project file (name differs from folder)', async () => {
    assert.strictEqual(await paths.findProjectFile(root), path.join(root, 'Other.vpyproj'));
    assert.strictEqual(await paths.findProjectFile(path.join(root, 'Other.vpyproj')), path.join(root, 'Other.vpyproj'));
    await assert.rejects(paths.findProjectFile(path.join(root, 'src', 'main.vpy')), /Not a project file/);
    await assert.rejects(paths.findProjectFile(path.join(tmp, 'outside')), /No \.vpyproj or \.cvproj/);
  });
  await test('walkProjectTree lists files and skips build/', async () => {
    fs.mkdirSync(path.join(root, 'build'));
    fs.writeFileSync(path.join(root, 'build', 'Game.bin'), 'x');
    const { entries } = await paths.walkProjectTree(root);
    const names = entries.map((e) => e.path);
    assert.ok(names.includes('src/main.vpy'));
    assert.ok(!names.some((n) => n.startsWith('build')));
  });
  await test('file URI round trip', () => {
    assert.strictEqual(paths.fileUriToPath(paths.pathToFileUri('/a b/c.vpy')), path.normalize('/a b/c.vpy'));
    assert.strictEqual(paths.fileUriToPath('file:///a%20b/c.vpy'), path.normalize('/a b/c.vpy'));
    assert.throws(() => paths.fileUriToPath('inmemory://untitled1.vpy'));
  });
  await test('line edits: replace / delete / multi-line', () => {
    const S = MCPServer.spliceText;
    assert.strictEqual(S('abc\ndef\nghi', 2, 2, 2, 3, 'X'), 'abc\ndXf\nghi');
    assert.strictEqual(S('abc\ndef\nghi', 1, null, 2, null, 'Z'), 'Z\nghi');
    assert.strictEqual(S('abc\ndef\nghi', 1, 3, 3, 2, ''), 'abhi');
    assert.strictEqual(S('abc', 1, 4, 1, 4, '\nnew'), 'abc\nnew');
    assert.throws(() => S('abc', 2, 1, 2, 1, 'x'), /out of range/);
    assert.throws(() => S('abc\ndef', 2, 1, 1, 1, 'x'), /before startLine/);
  });

  // ── Phase 1: IDE down ────────────────────────────────────────────────────
  const client = new StdioClient({ VECTREX_STUDIO_MCP_PORT: String(portB), VECTREX_STUDIO_MCP_TOKEN: TOKEN });

  await test('initialize echoes a supported client protocol version', async () => {
    const r = await client.request('initialize', { protocolVersion: '2025-03-26', capabilities: {}, clientInfo: { name: 't', version: '0' } });
    assert.strictEqual(r.result.protocolVersion, '2025-03-26');
    assert.ok(r.result.capabilities.tools);
    assert.strictEqual(r.result.serverInfo.name, 'vectrex-studio');
    // IDE down: the short static fallback, which still says where Claude is running.
    assert.strictEqual(r.result.instructions, require(SERVER_JS).FALLBACK_INSTRUCTIONS);
    assert.match(r.result.instructions, /inside Vectrex Studio/);
    client.notify('notifications/initialized');
  });

  await test('initialize with an unknown version answers the latest supported one', async () => {
    const c2 = new StdioClient({ VECTREX_STUDIO_MCP_PORT: String(portB), VECTREX_STUDIO_MCP_TOKEN: TOKEN });
    try {
      const r = await c2.request('initialize', { protocolVersion: '1999-01-01', capabilities: {} });
      assert.strictEqual(r.result.protocolVersion, '2025-06-18');
    } finally { c2.kill(); }
  });

  await test('ping -> {}', async () => {
    const r = await client.request('ping');
    assert.deepStrictEqual(r.result, {});
  });

  await test('IDE down: tools/list still answers, with get_project_docs only', async () => {
    const r = await client.request('tools/list');
    assert.deepStrictEqual(r.result.tools.map((t) => t.name), ['get_project_docs']);
  });

  await test('IDE down: tools/call -> isError result naming Vectrex Studio, process alive', async () => {
    const r = await client.callTool('editor_list_documents');
    assert.strictEqual(r.isError, true);
    assert.match(r.content[0].text, /Vectrex Studio is not running \/ not reachable/);
    assert.ok(client.alive());
  });

  await test('get_project_docs works offline', async () => {
    const r = await client.callTool('get_project_docs', { topic: 'meta' });
    assert.ok(!r.isError);
    assert.match(r.content[0].text, /META TITLE/);
  });

  await test('unknown method -> -32601', async () => {
    const r = await client.request('resources/list');
    assert.strictEqual(r.error.code, -32601);
  });

  await test('malformed JSON on stdin -> -32700 with id null, process alive', async () => {
    const before = client.raw.length;
    client.sendRaw('{not json');
    await sleep(200);
    const msg = client.raw.slice(before).find((m) => m.error);
    assert.ok(msg, 'expected an error reply');
    assert.strictEqual(msg.error.code, -32700);
    assert.strictEqual(msg.id, null);
    assert.ok(client.alive());
  });

  // ── Phase 2: IDE comes up (port A taken -> falls back to B) ──────────────
  const blocker = net.createServer().listen(portA, '127.0.0.1');
  await new Promise((r) => blocker.once('listening', r));

  await test('IDE TCP server skips a taken port and reports the bound one', async () => {
    const port = await tcp.startMcpTcpServer(handler, [portA, portB]);
    assert.strictEqual(port, portB);
    assert.strictEqual(auth.getMcpPort(), portB);
    const spec = auth.getMcpLaunchSpec();
    assert.strictEqual(spec.env.VECTREX_STUDIO_MCP_PORT, String(portB));
    assert.strictEqual(spec.env.VECTREX_STUDIO_MCP_TOKEN, TOKEN);
    assert.strictEqual(spec.env.ELECTRON_RUN_AS_NODE, '1');
    assert.strictEqual(spec.command, process.execPath);
    assert.ok(spec.args[0].endsWith(path.join('mcp-server', 'server.js')));
    assert.ok(fs.existsSync(spec.args[0]), `launch spec points at a missing file: ${spec.args[0]}`);
  });

  await test('stdio server reconnects in the background and sends tools/list_changed', async () => {
    const ok = await client.waitNotification('notifications/tools/list_changed', 20000);
    assert.ok(ok, 'no list_changed notification within 20 s');
  });

  let toolNames = [];
  await test('tools/list comes from the IDE: valid, unique names, includes create_sfx', async () => {
    const r = await client.request('tools/list');
    toolNames = r.result.tools.map((t) => t.name);
    assert.ok(toolNames.length > 30, `only ${toolNames.length} tools`);
    assert.strictEqual(new Set(toolNames).size, toolNames.length, 'duplicate tool names');
    for (const n of toolNames) assert.match(n, /^[a-zA-Z0-9_-]{1,64}$/);
    for (const n of ['project_create_sfx', 'project_open', 'memory_dump', 'memory_read_variable', 'get_project_docs']) {
      assert.ok(toolNames.includes(n), `missing ${n}`);
    }
    for (const t of r.result.tools) assert.strictEqual(t.inputSchema.type, 'object');
  });

  await test('tools/call success round-trip (editor_list_documents)', async () => {
    const r = await client.callTool('editor_list_documents');
    assert.ok(!r.isError, r.content[0].text);
    const body = JSON.parse(r.content[0].text);
    assert.strictEqual(body.documents[0].uri, 'file:///proj/src/main.vpy');
  });

  await test('parameters reach the renderer as data, not code (injection)', async () => {
    bridgeCalls.length = 0;
    const r = await client.callTool('editor_read_document', { uri: EVIL });
    assert.ok(!r.isError, r.content[0].text);
    const call = bridgeCalls.find((c) => c.fn === 'getDocument');
    assert.ok(call, 'getDocument not called');
    assert.strictEqual(call.args.uri, EVIL);
    assert.strictEqual(sandbox.pwned, undefined);
    assert.strictEqual(JSON.parse(r.content[0].text).content, 'line1\nline2');
  });

  await test('IDE-side tool failure -> isError result with the IDE message', async () => {
    const r = await client.callTool('memory_dump', { start: '0xC800', length: 16 });
    assert.strictEqual(r.isError, true);
    assert.match(r.content[0].text, /fake bridge: readMemory/);
  });

  await test('IDE-side validation error (VIA region not readable)', async () => {
    const r = await client.callTool('memory_dump', { start: '$D000', length: 4 });
    assert.strictEqual(r.isError, true);
    assert.match(r.content[0].text, /not readable/);
  });

  await test('project tools require an open project', async () => {
    const r = await client.callTool('project_read_file', { path: '../../etc/passwd' });
    assert.strictEqual(r.isError, true);
    assert.match(r.content[0].text, /No project is open/);
  });

  await test('unknown tool -> isError', async () => {
    const r = await client.callTool('no_such_tool');
    assert.strictEqual(r.isError, true);
    assert.match(r.content[0].text, /Unknown tool/);
  });

  // ── IDE context, build target, ide_run, project_create kind c ───────────
  const { IDE_INSTRUCTIONS } = require(path.join(DIST, 'instructions.js'));
  const templates = require(path.join(DIST, '..', 'projectTemplates.js'));

  await test('initialize with the IDE up returns the IDE instructions', async () => {
    const c3 = new StdioClient({ VECTREX_STUDIO_MCP_PORT: String(portB), VECTREX_STUDIO_MCP_TOKEN: TOKEN });
    try {
      const r = await c3.request('initialize', { protocolVersion: '2025-06-18', capabilities: {} });
      assert.strictEqual(r.result.instructions, IDE_INSTRUCTIONS);
    } finally { c3.kill(); }
  });

  await test('instructions: content and every tool they name exists', async () => {
    assert.match(IDE_INSTRUCTIONS, /^You are running inside Vectrex Studio/);
    for (const needle of ['ide_get_context', 'uvmc2-sdk', 'kind "c"', 'Shift+F5', 'm6809', 'rp2350', 'uvm2', 'pitrex', 'ask the user', 'WAIT_RECAL',
      'assets_list', 'asset_create', 'asset_get_format', 'DRAW_VECTOR("ship"', 'PLAY_MUSIC(THEME_music)',
      'api_reference', 'NEVER grep', 'DRAW_VECTOR_ROT', 'DRAW_VECTOR_3D with az']) {
      assert.ok(IDE_INSTRUCTIONS.includes(needle), `instructions lack "${needle}"`);
    }
    const lines = IDE_INSTRUCTIONS.split('\n').length;
    assert.ok(lines >= 30 && lines <= 120, `instructions are ${lines} lines`);
    // The mandatory checklist comes first (right after the one-paragraph intro), numbered 1-4.
    const head = IDE_INSTRUCTIONS.indexOf('BEFORE WRITING CODE');
    assert.ok(head > 0 && head < 400, `the checklist starts at ${head}`);
    const steps = ['1. Call ide_get_context', '2. Art, sound, levels and animation are ASSETS', '3. Anything "api" does not cover: api_reference', '4. Build and run with ide_run']
      .map((s) => IDE_INSTRUCTIONS.indexOf(s));
    assert.ok(steps.every((i, k) => i > head && (k === 0 || i > steps[k - 1])), `checklist steps missing or out of order: ${steps}`);
    assert.ok(steps[3] < IDE_INSTRUCTIONS.indexOf('HOW TO WORK'), 'the checklist precedes everything else');
    // Claude Code passes a model only the first ~2 KB of server instructions: the checklist and
    // the run-mode rule (simulator on the ARM targets) must end well inside that head.
    const runRule = IDE_INSTRUCTIONS.indexOf('ide_run {mode:"simulate"}');
    assert.ok(runRule > steps[3] && Buffer.byteLength(IDE_INSTRUCTIONS.slice(0, IDE_INSTRUCTIONS.indexOf('HOW TO WORK'))) <= 1800,
      'the checklist with the run-mode rule must fit in the first 1800 bytes');
    // The API is generated (ide_get_context / api_reference), not described here: the text must not grow.
    assert.ok(Buffer.byteLength(IDE_INSTRUCTIONS) <= 7000, `instructions are ${Buffer.byteLength(IDE_INSTRUCTIONS)} bytes`);
    assert.ok(fs.statSync(path.join(__dirname, '..', '..', 'electron', 'src', 'mcp', 'instructions.ts')).size <= 7800, 'instructions.ts > 7.8 KB');
    const named = new Set(IDE_INSTRUCTIONS.match(/\b(?:ide|project|editor|compiler|emulator|memory|debugger|settings|get|assets?|api)_[a-z_]+\b/g));
    for (const n of named) assert.ok(toolNames.includes(n), `instructions name a tool that does not exist: ${n}`);
  });

  await test('tools/list has ide_get_context, ide_run, settings_set_build_target and project_create kind', async () => {
    const r = await client.request('tools/list');
    const byName = Object.fromEntries(r.result.tools.map((t) => [t.name, t]));
    for (const n of ['ide_get_context', 'ide_run', 'settings_set_build_target']) assert.ok(byName[n], `missing ${n}`);
    assert.deepStrictEqual(byName.ide_run.inputSchema.properties.mode.enum, ['build', 'run', 'simulate', 'build_simulator']);
    assert.deepStrictEqual(byName.settings_set_build_target.inputSchema.properties.target.enum, ['m6809', 'rp2350', 'pitrex', 'uvm2']);
    assert.deepStrictEqual(byName.project_create.inputSchema.properties.kind.enum, ['vpy', 'c']);
  });

  await test('ide_get_context with no project: target, emulator, toolchain, IDE version', async () => {
    fake.project = null;
    const r = await client.callTool('ide_get_context');
    assert.ok(!r.isError, r.content[0].text);
    const ctx = JSON.parse(r.content[0].text);
    assert.strictEqual(ctx.ide.name, 'Vectrex Studio');
    assert.strictEqual(ctx.ide.version, require(path.join(DIST, '..', '..', 'package.json')).version);
    assert.strictEqual(ctx.project.open, false);
    assert.strictEqual(ctx.buildTarget, 'm6809');
    assert.strictEqual(typeof ctx.armToolchain.found, 'boolean');
    assert.ok(ctx.emulator && 'running' in ctx.emulator);
    assert.ok(Array.isArray(ctx.sdk.installed));
  });

  await test('settings_set_build_target: sets it, rejects unknown targets', async () => {
    fake.project = null;
    const ok = await client.callTool('settings_set_build_target', { target: 'rp2350' });
    assert.ok(!ok.isError, ok.content[0].text);
    assert.deepStrictEqual(JSON.parse(ok.content[0].text), { buildTarget: 'rp2350', previous: 'm6809' });
    const bad = await client.callTool('settings_set_build_target', { target: 'gameboy' });
    assert.strictEqual(bad.isError, true);
    assert.match(bad.content[0].text, /Unknown build target/);
  });

  const cParent = path.join(tmp, 'cprojects');
  fs.mkdirSync(cParent);
  await test('project_create kind "c": self-contained template, pinned SDK, opened', async () => {
    fake.project = null;
    const r = await client.callTool('project_create', { name: 'hello_c', location: cParent, kind: 'c' });
    assert.ok(!r.isError, r.content[0].text);
    const out = JSON.parse(r.content[0].text);
    assert.strictEqual(out.kind, 'c');
    assert.strictEqual(out.isExternal, true);
    const dir = path.join(cParent, 'hello_c');
    for (const f of ['hello_c.cvproj', 'Makefile', 'src/main.c', '.gitignore']) assert.ok(fs.existsSync(path.join(dir, f)), `missing ${f}`);
    const cvproj = fs.readFileSync(path.join(dir, 'hello_c.cvproj'), 'utf-8');
    const toml = require(path.join(__dirname, '..', '..', 'electron', 'node_modules', 'toml'));
    const m = toml.parse(cvproj);
    assert.strictEqual(m.project.type, 'c-external');
    assert.strictEqual(m.project.entry, 'src/main.c');
    assert.strictEqual(m.simulate.module, 'build_wasm/hello_c.js');
    assert.deepStrictEqual(Object.keys(m.targets).sort(), ['rp2350', 'uvm2']);
    assert.strictEqual(m.targets.rp2350.artifact, 'build_rp2350/hello_c_sd.bin');
    assert.strictEqual(m.targets.uvm2.artifact, 'build_uvm2/hello_c.um2');
    if (out.sdkVersion) assert.strictEqual(m.sdk.version, out.sdkVersion);
    const mk = fs.readFileSync(path.join(dir, 'Makefile'), 'utf-8');
    assert.ok(!/\.\.\//.test(mk), 'the Makefile must not reach outside the project');
    assert.match(mk, /include \$\(UVM2_SDK\)\/uvm2\.mk/);
    const main = fs.readFileSync(path.join(dir, 'src', 'main.c'), 'utf-8');
    assert.match(main, /#include <vpy\.h>/);
    assert.match(main, /vpy_run\(setup, loop\)/);
    assert.ok(bridgeCalls.some((c) => c.fn === 'openProject' && c.args.projectFile === path.join(dir, 'hello_c.cvproj')));
  });

  await test('project_create refuses an existing project and a bad kind', async () => {
    const again = await client.callTool('project_create', { name: 'hello_c', location: cParent, kind: 'c' });
    assert.strictEqual(again.isError, true);
    assert.match(again.content[0].text, /already exists/);
    const bad = await client.callTool('project_create', { name: 'x2', location: cParent, kind: 'rust' });
    assert.strictEqual(bad.isError, true);
    assert.match(bad.content[0].text, /"kind" must be "vpy" or "c"/);
  });

  await test('VPy template: project file + main.vpy without WAIT_RECAL', async () => {
    const created = await templates.createProjectFromTemplate({ kind: 'vpy', name: 'hello_vpy', parentDir: cParent, sdkVersion: 'v1.3.2' });
    const proj = fs.readFileSync(created.projectFile, 'utf-8');
    assert.match(proj, /entry = "src\/main\.vpy"/);
    assert.match(proj, /\[sdk\]\nversion = "v1\.3\.2"/);
    const src = fs.readFileSync(created.entryFile, 'utf-8');
    assert.match(src, /def loop\(\):/);
    assert.ok(!/^\s*(WAIT_RECAL|Wait_Recal|Draw_To)\(/m.test(src), 'the template must not call WAIT_RECAL / Draw_To');
    await assert.rejects(templates.createProjectFromTemplate({ kind: 'c', name: '9bad', parentDir: cParent, sdkVersion: null }), /Invalid project name/);
  });

  await test('ide_get_context with the C project open: kind, recipes, simulator, keys', async () => {
    fake.buildTarget = 'm6809';
    const r = await client.callTool('ide_get_context');
    assert.ok(!r.isError, r.content[0].text);
    const ctx = JSON.parse(r.content[0].text);
    assert.strictEqual(ctx.project.kind, 'c');
    assert.strictEqual(ctx.project.simulator, true);
    assert.deepStrictEqual(ctx.project.buildableTargets, ['rp2350', 'uvm2']);
    assert.strictEqual(ctx.project.entry, path.join(cParent, 'hello_c', 'src', 'main.c'));
    assert.match(ctx.keys.F5, /no 6809 build path/);
    assert.match(ctx.keys['Shift+F5'], /WASM simulator/);
    assert.ok(ctx.warnings.some((w) => /m6809 cannot build a C project/.test(w)));
  });

  await test('settings_set_build_target warns when the C project cannot build the target', async () => {
    const r = await client.callTool('settings_set_build_target', { target: 'pitrex' });
    assert.ok(!r.isError, r.content[0].text);
    assert.match(JSON.parse(r.content[0].text).warning, /no \[targets\.pitrex\]/);
  });

  await test('ide_run simulate: success with the simulator running', async () => {
    fake.nextRun = { ok: true, project: 'c', target: 'sim', artifact: '/x/build_wasm/hello_c.js', launch: 'sim', notes: [], buildMs: 5, emulatorWait: { waitedFor: 'sim', timedOut: false }, emulator: fakeEmulator(true), output: '=== Sim build OK ===\n' };
    bridgeCalls.length = 0;
    const r = await client.callTool('ide_run', { mode: 'simulate' });
    assert.ok(!r.isError, r.content[0].text);
    const out = JSON.parse(r.content[0].text);
    assert.strictEqual(out.ok, true);
    assert.strictEqual(out.launched, 'sim');
    assert.strictEqual(out.emulator.running, true);
    assert.strictEqual(bridgeCalls.find((c) => c.fn === 'runBuild').args.mode, 'simulate');
  });

  await test('ide_run: build failure -> isError with the errors and output', async () => {
    fake.nextRun = { ok: false, project: 'vpy', target: 'm6809', launch: 'none', error: 'compile_failed', stderr: 'error 12:5 - Unknown name foo\n', notes: [], emulator: fakeEmulator(false), output: '' };
    const r = await client.callTool('ide_run', { mode: 'run' });
    assert.strictEqual(r.isError, true);
    assert.match(r.content[0].text, /Build failed/);
    assert.match(r.content[0].text, /12:5 Unknown name foo/);
  });

  await test('ide_run run: built but the emulator is not running -> isError', async () => {
    fake.nextRun = { ok: true, project: 'c', target: 'rp2350', artifact: '/x/a_sd.bin', launch: 'emulator', notes: [], emulatorWait: { waitedFor: 'the Emulator panel to load the program', timedOut: true }, emulator: fakeEmulator(false), output: '' };
    const r = await client.callTool('ide_run', { mode: 'run' });
    assert.strictEqual(r.isError, true);
    assert.match(r.content[0].text, /not running: timed out waiting for the Emulator panel/);
  });

  await test('ide_run rejects an unknown mode', async () => {
    const r = await client.callTool('ide_run', { mode: 'flash' });
    assert.strictEqual(r.isError, true);
    assert.match(r.content[0].text, /"mode" must be/);
  });

  await test('compiler_build on a .cvproj delegates to the F7 path (runBuild mode build)', async () => {
    fake.nextRun = { ok: true, project: 'c', target: 'rp2350', artifact: '/x/a_sd.bin', launch: 'emulator', notes: [], emulator: fakeEmulator(true), output: '' };
    bridgeCalls.length = 0;
    const r = await client.callTool('compiler_build');
    assert.ok(!r.isError, r.content[0].text);
    assert.strictEqual(bridgeCalls.find((c) => c.fn === 'runBuild').args.mode, 'build');
    fake.project = null;
    fake.nextRun = null;
  });

  // ── Assets: assets_list / asset_get_format / asset_create ───────────────
  const assetsLib = require(path.join(DIST, 'assets.js'));
  const REPO = path.join(__dirname, '..', '..', '..');
  const vpyCli = assetsLib.resolveVpyCli();
  let cliHasCheck = false, cliHasScene = false;
  if (vpyCli) {
    const r = require('child_process').spawnSync(vpyCli, ['check-asset', '--help'], { encoding: 'utf-8' });
    cliHasCheck = r.status === 0;
    cliHasScene = cliHasCheck && /\.vscene/.test(r.stdout);
  }
  const withCli = cliHasCheck ? test : async (name) => console.log(`  skip ${name} (no vpy_cli with check-asset; build buildtools and run-ide.sh)`);
  const TYPES = assetsLib.ASSET_SPECS.map((a) => a.type);
  const openProjectFake = (projectFile) => {
    const rootDir = path.dirname(projectFile);
    const c = /\.cvproj$/i.test(projectFile);
    fake.project = { projectFile, rootDir, name: path.basename(rootDir), isExternal: c, entryPath: path.join(rootDir, 'src', c ? 'main.c' : 'main.vpy'), outputPath: null };
  };
  const vecJson = (pts, closed = true) => ({ version: '1.0', name: 'x', canvas: { width: 256, height: 256, origin: 'center' },
    layers: [{ name: 'default', visible: true, paths: [{ name: 'p', intensity: 127, closed, points: pts.map(([x, y]) => ({ x, y })) }] }] });
  const json = (r) => JSON.parse(r.content[0].text);

  await test('asset tools are listed with precise schemas', async () => {
    const r = await client.request('tools/list');
    const byName = Object.fromEntries(r.result.tools.map((t) => [t.name, t]));
    for (const n of ['assets_list', 'asset_get_format', 'asset_create', 'project_create_vector', 'project_create_music', 'project_create_sfx']) assert.ok(byName[n], `missing ${n}`);
    assert.deepStrictEqual(TYPES, ['vec', 'vmus', 'vsfx', 'vanim', 'vplay', 'venemy', 'vinstr', 'vrec', 'vsmp', 'vmesh', 'vscene']);
    assert.deepStrictEqual(byName.asset_create.inputSchema.properties.type.enum, TYPES);
    assert.deepStrictEqual(byName.asset_get_format.inputSchema.properties.type.enum, TYPES);
    assert.deepStrictEqual(byName.assets_list.inputSchema.properties.type.enum, TYPES);
    assert.deepStrictEqual(byName.asset_create.inputSchema.required, ['type', 'name', 'content']);
    assert.deepStrictEqual(byName.asset_get_format.inputSchema.required, ['type']);
  });

  await test('asset_get_format: format, example and usage for every type; unknown type -> isError', async () => {
    for (const t of TYPES) {
      const r = await client.callTool('asset_get_format', { type: t });
      assert.ok(!r.isError, r.content[0].text);
      const f = json(r);
      assert.strictEqual(f.ext, '.' + t);
      assert.ok(f.format.length > 80 && f.example && typeof f.example === 'object', `${t}: no format/example`);
      assert.ok(f.usage.vpy || f.usage.c, `${t}: no usage`);
      if (!f.usage.vpy) assert.ok(f.usage.vpyNote, `${t}: VPy-unusable without a note`);
      if (!f.usage.c) assert.ok(f.usage.cNote, `${t}: C-unusable without a note`);
    }
    const vec = json(await client.callTool('asset_get_format', { type: '.vec' }));
    assert.match(vec.usage.vpy, /^DRAW_VECTOR\("example", x, y\)/);
    assert.match(vec.usage.c, /#include "example\.h"\nDRAW_VECTOR\(EXAMPLE_vec, x, y\)/);
    const bad = await client.callTool('asset_get_format', { type: 'png' });
    assert.strictEqual(bad.isError, true);
    assert.match(bad.content[0].text, /Unknown asset type "png"; one of: vec, vmus/);
  });

  await test('docs/ASSETS.md and get_project_docs agree with the catalog', async () => {
    const doc = fs.readFileSync(path.join(REPO, 'docs', 'ASSETS.md'), 'utf-8');
    assert.match(fs.readFileSync(path.join(REPO, 'docs', 'INDEX.md'), 'utf-8'), /\(ASSETS\.md\)/);
    const topic = json({ content: [{ text: JSON.stringify((await client.callTool('get_project_docs', { topic: 'assets' })).content[0].text) }] });
    for (const sp of assetsLib.ASSET_SPECS) {
      assert.ok(doc.includes('`' + sp.ext + '`'), `ASSETS.md lacks ${sp.ext}`);
      assert.ok(doc.includes('`' + sp.dir + '/`'), `ASSETS.md lacks folder ${sp.dir}/`);
      assert.ok(topic.includes(sp.ext) && topic.includes(sp.dir), `get_project_docs assets lacks ${sp.ext} / ${sp.dir}`);
      if (sp.vpy.usable) {
        const call = sp.vpy.usage('n').match(/[A-Z_0-9]{4,}\(/g).filter((c) => c !== 'SPAWN_ENEMIES(' || sp.type !== 'venemy')[0];
        assert.ok(doc.includes(call), `ASSETS.md lacks ${call} (${sp.type})`);
      }
      if (sp.c.usable) {
        // the C call and the header symbol the catalog hands out (DEMO_instr -> `N_instr`)
        const usage = sp.c.usage('DEMO');
        const call = (usage.match(/[A-Z_0-9]{4,}\(/g) || [])[0];
        if (call) assert.ok(doc.includes(call), `ASSETS.md lacks the C call ${call} (${sp.type})`);
        const sym = /\bDEMO_([a-z_]+)\b/.exec(usage);
        if (sym) assert.ok(doc.includes(`N_${sym[1]}`), `ASSETS.md lacks the C symbol N_${sym[1]} (${sp.type})`);
      }
    }
    for (const ext of Object.keys(assetsLib.OTHER_ASSET_FILES)) assert.ok(doc.includes('`' + ext + '`'), `ASSETS.md lacks ${ext}`);
  });

  await withCli('every catalog example compiles with vpy_cli (VPy loaders + the C header step)', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'vs-assets-'));
    const put = (dir, file, j) => { fs.mkdirSync(path.join(root, dir), { recursive: true }); const p = path.join(root, dir, file); fs.writeFileSync(p, JSON.stringify(j)); return p; };
    for (const v of ['platform', 'example', 'example_1', 'example_2']) put('assets/vectors', `${v}.vec`, vecJson([[-8, 0], [8, 0], [0, 8]]));
    put('assets/meshes', 'example_piece.vmesh', assetsLib.specFor('vmesh').example('example_piece'));
    for (const sp of assetsLib.ASSET_SPECS) {
      const p = put(sp.dir, 'example' + sp.ext, sp.example('example'));
      assert.deepStrictEqual(assetsLib.missingReferences(sp, sp.example('example'), root, path.dirname(p)), [], `${sp.type} example has missing refs`);
      for (const lang of ['vpy', 'c']) {
        if (!(lang === 'c' ? sp.c.usable : sp.vpy.usable)) continue;
        const r = await assetsLib.compileCheck(vpyCli, p, sp, lang);
        assert.ok(r.ok, `${sp.type} (${lang}): ${r.error}`);
      }
    }
    fs.rmSync(root, { recursive: true, force: true });
  });

  await withCli('C headers carry the symbol each C usage snippet names', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'vs-csym-'));
    fs.mkdirSync(path.join(root, 'assets/meshes'), { recursive: true });
    fs.writeFileSync(path.join(root, 'assets/meshes/demo_piece.vmesh'), JSON.stringify(assetsLib.specFor('vmesh').example('demo_piece')));
    for (const sp of assetsLib.ASSET_SPECS.filter((a) => a.c.usable && ['vinstr', 'vrec', 'vsmp', 'vmus', 'vsfx', 'vmesh', 'vscene'].includes(a.type))) {
      if (sp.type === 'vscene' && !cliHasScene) { console.log('  (skip .vscene header: this vpy_cli predates .vscene; rebuild it with run-ide.sh)'); continue; }
      fs.mkdirSync(path.join(root, sp.dir), { recursive: true });
      const src = path.join(root, sp.dir, 'demo' + sp.ext);
      fs.writeFileSync(src, JSON.stringify(sp.example('demo')));
      const out = path.join(root, 'demo_' + sp.type + '.h');
      const r = require('child_process').spawnSync(vpyCli, ['compile-asset', src, '--format', 'c', '--out', out]);
      assert.strictEqual(r.status, 0, `${sp.type}: ${r.stderr}`);
      const sym = sp.c.usage('demo').match(/\b(DEMO_[a-z]+)\b/)[1];
      assert.match(fs.readFileSync(out, 'utf-8'), new RegExp(`static const unsigned char ${sym}\\[\\]`), `${sp.type}: header lacks ${sym}`);
      if (sp.type === 'vscene') {
        const h = fs.readFileSync(out, 'utf-8');
        assert.match(h, /#include "demo_piece\.h"/);
        assert.match(h, /static const unsigned char \*const DEMO_vscene_meshes\[\] = \{\n {4}DEMO_PIECE_vmesh,/);
        assert.match(sp.c.usage('demo'), /vpy3d_load_scene\(&s, DEMO_vscene, DEMO_vscene_meshes\)/);
      }
    }
    fs.rmSync(root, { recursive: true, force: true });
  });

  const aParent = path.join(tmp, 'assetprojects');
  fs.mkdirSync(aParent);
  const vproj = await templates.createProjectFromTemplate({ kind: 'vpy', name: 'av', parentDir: aParent, sdkVersion: 'v1.3.2' });
  const cproj = await templates.createProjectFromTemplate({ kind: 'c', name: 'ac', parentDir: aParent, sdkVersion: 'v1.3.2' });

  await test('templates: VPy [resources] names every VPy asset folder; C Makefile compiles assets into gen/', async () => {
    const proj = fs.readFileSync(vproj.projectFile, 'utf-8');
    for (const sp of assetsLib.ASSET_SPECS.filter((a) => a.vpy.usable)) {
      assert.ok(proj.includes(`"${sp.dir}/*${sp.ext}"`), `.vpyproj [resources] lacks ${sp.dir}/*${sp.ext}`);
      assert.ok(fs.existsSync(path.join(vproj.projectDir, sp.dir)), `missing folder ${sp.dir}`);
    }
    const mk = fs.readFileSync(path.join(cproj.projectDir, 'Makefile'), 'utf-8');
    assert.match(mk, /\$\(VPY_CLI\) compile-asset \$< --format c --out \$@/);
    assert.match(mk, /-Igen/);
    assert.match(mk, /^sim: \$\(ASSET_HDRS\)/m);
    assert.match(mk, /^UVM2_DEPS += \$\(ASSET_HDRS\)$|^UVM2_DEPS\s+= \$\(ASSET_HDRS\)$/m);
    for (const sp of assetsLib.ASSET_SPECS.filter((a) => a.c.usable && a.type !== 'venemy')) assert.ok(mk.includes(`${sp.dir}/*${sp.ext}`), `Makefile does not compile ${sp.dir}/*${sp.ext}`);
    assert.ok(await assetsLib.makefileCompilesAssets(cproj.projectDir));
  });

  await test('asset tools require an open project', async () => {
    fake.project = null;
    for (const [tool, args] of [['assets_list', {}], ['asset_create', { type: 'vec', name: 'a', content: '{}' }]]) {
      const r = await client.callTool(tool, args);
      assert.strictEqual(r.isError, true);
      assert.match(r.content[0].text, /No project is open/);
    }
  });

  await test('assets_list on an empty VPy project: no assets, every VPy type offered, .vmesh / .vscene not usable', async () => {
    openProjectFake(vproj.projectFile);
    const l = json(await client.callTool('assets_list', {}));
    assert.strictEqual(l.project.language, 'vpy');
    assert.deepStrictEqual(l.assets, {});
    assert.deepStrictEqual(l.usableTypesWithNoAssets.map((t) => t.type), TYPES.filter((t) => t !== 'vmesh' && t !== 'vscene'));
    assert.deepStrictEqual(l.typesNotUsableInThisLanguage.map((t) => t.type), ['vmesh', 'vscene']);
  });

  await withCli('asset_create (VPy): valid assets are written, compiled, opened, and come with their code', async () => {
    openProjectFake(vproj.projectFile);
    fake.opened.length = 0;
    const mk = async (type, name, content) => {
      const r = await client.callTool('asset_create', { type, name, content });
      assert.ok(!r.isError, `${type} ${name}: ${r.content[0].text}`);
      return json(r);
    };
    const ship = await mk('vec', 'ship', (await json(await client.callTool('asset_get_format', { type: 'vec' }))).example);
    assert.strictEqual(ship.path, 'assets/vectors/ship.vec');
    assert.match(ship.validatedBy, /check-asset/);
    assert.strictEqual(ship.usage.split('   ')[0], 'DRAW_VECTOR("ship", x, y)');
    assert.strictEqual(JSON.parse(fs.readFileSync(path.join(vproj.projectDir, ship.path), 'utf-8')).name, 'ship');
    assert.ok(fake.opened.some((u) => u.endsWith('/assets/vectors/ship.vec')), 'not opened in the editor');
    await mk('vec', 'platform', vecJson([[-60, 0], [60, 0]], false));
    await mk('vec', 'walk_1', vecJson([[-4, -8], [0, 0], [4, -8]], false));
    await mk('vec', 'walk_2', vecJson([[-2, -8], [0, 0], [2, -8]], false));
    const mus = await mk('vmus', 'theme', JSON.stringify(assetsLib.specFor('vmus').example('theme')));
    assert.match(mus.usage, /^PLAY_MUSIC\("theme"\)/);
    await mk('vsfx', 'laser', assetsLib.specFor('vsfx').example('x'));
    const anim = await mk('vanim', 'walk', { ...assetsLib.specFor('vanim').example('walk') });
    assert.match(anim.usage, /^DRAW_ANIM\("walk", x, y, mirror\)/);
    const lvl = await mk('vplay', 'level1', assetsLib.specFor('vplay').example('level1'));
    assert.match(lvl.usage, /^LOAD_LEVEL\("level1"\)/);
    assert.ok(!fake.opened.some((u) => u.endsWith('.vplay')), 'a level is opened from the Playground, not as text');
    const l = json(await client.callTool('assets_list', {}));
    assert.deepStrictEqual(Object.keys(l.assets), ['vec', 'vmus', 'vsfx', 'vanim', 'vplay']);
    assert.strictEqual(l.assets.vec.count, 4);
    assert.ok(l.assets.vec.items.find((i) => i.name === 'ship').summary.includes('3 point(s)'));
    assert.ok(!l.usableTypesWithNoAssets.some((t) => t.type === 'vec'));
    const only = json(await client.callTool('assets_list', { type: 'vmus' }));
    assert.deepStrictEqual(Object.keys(only.assets), ['vmus']);
  });

  await withCli('asset_create (VPy): compiler errors are returned and nothing is left behind', async () => {
    openProjectFake(vproj.projectFile);
    const bad = await client.callTool('asset_create', { type: 'vsfx', name: 'pickup', content: { ...assetsLib.specFor('vsfx').example('pickup'), category: 'pickup' } });
    assert.strictEqual(bad.isError, true);
    assert.match(bad.content[0].text, /does not compile \(vpy_cli check-asset\): unknown variant `pickup`.*nothing was written/s);
    assert.ok(!fs.existsSync(path.join(vproj.projectDir, 'assets/sfx/pickup.vsfx')));
    const notJson = await client.callTool('asset_create', { type: 'vec', name: 'x', content: '{"layers": [' });
    assert.strictEqual(notJson.isError, true);
    assert.match(notJson.content[0].text, /not valid JSON/);
    const refs = await client.callTool('asset_create', { type: 'vanim', name: 'run', content: { version: '1.0', name: 'run', frames: [{ index: 0, vec_refs: ['nope'] }] } });
    assert.strictEqual(refs.isError, true);
    assert.match(refs.content[0].text, /references assets that do not exist.*assets\/vectors\/nope\.vec/);
    const exists = await client.callTool('asset_create', { type: 'vec', name: 'ship', content: vecJson([[0, 0], [1, 1]]) });
    assert.strictEqual(exists.isError, true);
    assert.match(exists.content[0].text, /already exists \(pass overwrite=true/);
    // A failed overwrite restores the previous file.
    const shipPath = path.join(vproj.projectDir, 'assets/vectors/ship.vec');
    const before = fs.readFileSync(shipPath, 'utf-8');
    const broken = await client.callTool('asset_create', { type: 'vec', name: 'ship', overwrite: true, content: { version: '1.0', name: 'ship', layers: [{ name: 'l', paths: [] }] } });
    assert.strictEqual(broken.isError, true);
    assert.match(broken.content[0].text, /no paths.*previous file was restored/s);
    assert.strictEqual(fs.readFileSync(shipPath, 'utf-8'), before);
    const okOver = await client.callTool('asset_create', { type: 'vec', name: 'ship', overwrite: true, content: vecJson([[0, 10], [-8, -6], [8, -6]]) });
    assert.ok(!okOver.isError, okOver.content[0].text);
    assert.strictEqual(json(okOver).replaced, true);
    for (const [name, re] of [['../x', /Invalid asset name/], ['9lives', /Invalid asset name/], ['a.b', /Invalid asset name/]]) {
      const r = await client.callTool('asset_create', { type: 'vec', name, content: vecJson([[0, 0], [1, 1]]) });
      assert.strictEqual(r.isError, true);
      assert.match(r.content[0].text, re);
    }
    const mesh = await client.callTool('asset_create', { type: 'vmesh', name: 'cube', content: assetsLib.specFor('vmesh').example('cube') });
    assert.strictEqual(mesh.isError, true);
    assert.match(mesh.content[0].text, /cannot be used from a VPy project/);
  });

  await test('assets_list warns about an asset the build will not find and lists other asset files', async () => {
    openProjectFake(vproj.projectFile);
    fs.writeFileSync(path.join(vproj.projectDir, 'assets', 'stray.vec'), JSON.stringify(vecJson([[0, 0], [5, 5]])));
    fs.writeFileSync(path.join(vproj.projectDir, 'assets', 'movies', 'intro.vmov'), '{"version":"1.0","name":"intro","fps":15,"vrec":"","vsmp":""}');
    const l = json(await client.callTool('assets_list', { type: 'vec' }));
    const stray = l.assets.vec.items.find((i) => i.name === 'stray');
    assert.match(stray.warning, /not in assets\/vectors\/: the compiler will not find it/);
    assert.ok(l.other.some((o) => o.path === 'assets/movies/intro.vmov' && /Vector movie manifest/.test(o.what)));
    fs.rmSync(path.join(vproj.projectDir, 'assets', 'stray.vec'));
  });

  await withCli('legacy project_create_vector / _music / _sfx delegate to asset_create (validated)', async () => {
    openProjectFake(vproj.projectFile);
    const v = await client.callTool('project_create_vector', { name: 'legacy_vec' });
    assert.ok(!v.isError, v.content[0].text);
    assert.match(json(v).validatedBy, /check-asset/);
    const s = await client.callTool('project_create_sfx', { name: 'legacy_sfx' });
    assert.ok(!s.isError, s.content[0].text);
    assert.strictEqual(JSON.parse(fs.readFileSync(path.join(vproj.projectDir, 'assets/sfx/legacy_sfx.vsfx'), 'utf-8')).category, 'laser');
    const m = await client.callTool('project_create_music', { name: 'legacy_mus' });
    assert.ok(!m.isError, m.content[0].text);
    const big = await client.callTool('project_create_music', { name: 'big', content: JSON.stringify({ version: '1.0', name: 'big', tempo: 120, notes: Array.from({ length: 130 }, (_, i) => ({ id: 'n' + i, note: 60, start: i * 4, duration: 4, velocity: 10, channel: 0 })) }) });
    assert.strictEqual(big.isError, true);
    assert.match(big.content[0].text, /Too many events \(130\)/);
  });

  await withCli('asset_create (C project): C header step, #include usage, .vmesh / .vinstr / .vrec / .vsmp allowed', async () => {
    openProjectFake(cproj.projectFile);
    const mk = async (type, name, content) => {
      const r = await client.callTool('asset_create', { type, name, content });
      assert.ok(!r.isError, `${type} ${name}: ${r.content[0].text}`);
      return json(r);
    };
    const ship = await mk('vec', 'ship', assetsLib.specFor('vec').example('ship'));
    assert.match(ship.validatedBy, /compile-asset --format c/);
    assert.ok(ship.usage.startsWith('#include "ship.h"\nDRAW_VECTOR(SHIP_vec, x, y);   /* or DRAW_VECTOR_EX(SHIP_vec, x, y, mirror, intensity)'), ship.usage);
    assert.ok(!ship.warnings || !ship.warnings.some((w) => /Makefile/.test(w)), 'the template Makefile compiles assets');
    const mesh = await mk('vmesh', 'cube', assetsLib.specFor('vmesh').example('cube'));
    assert.strictEqual(mesh.path, 'assets/meshes/cube.vmesh');
    assert.match(mesh.usage, /vpy3d_load_mesh\(&m, CUBE_vmesh\)/);
    const noMesh = await client.callTool('asset_create', { type: 'vscene', name: 'hall', content: { items: [{ mesh: 'pillar' }] } });
    assert.strictEqual(noMesh.isError, true);
    assert.match(noMesh.content[0].text, /references assets that do not exist.*mesh "pillar" -> assets\/meshes\/pillar\.vmesh/s);
    const badScene = await client.callTool('asset_create', { type: 'vscene', name: 'hall', content: { items: [{ mesh: ['cube', 'cube'], group: 'alarm', br: 0 }] } });
    assert.strictEqual(badScene.isError, true);
    assert.match(badScene.content[0].text, /not a valid \.vscene.*take turns along a repeat.*br is a percent.*group "alarm" is not in the scene's groups/s);
    assert.ok(!fs.existsSync(path.join(cproj.projectDir, 'assets/scenes/hall.vscene')));
    const scene = await mk('vscene', 'hall', { items: [{ name: 'cubes', mesh: 'cube', at: { z: 600 }, follow: { z: -1 }, repeat: { step: 2000, count: 4 } }] });
    assert.strictEqual(scene.path, 'assets/scenes/hall.vscene');
    assert.match(scene.validatedBy, /check-asset|IDE checks only/);
    assert.match(scene.usage, /vpy3d_load_scene\(&s, HALL_vscene, HALL_vscene_meshes\)/);
    assert.ok(!scene.warnings || !scene.warnings.some((w) => /Makefile/.test(w)), 'the template Makefile compiles .vscene');
    for (const v of ['walk_1', 'walk_2']) await mk('vec', v, vecJson([[-4, -8], [0, 0], [4, -8]], false));
    const inline = await client.callTool('asset_create', { type: 'vanim', name: 'wave', content: { version: '1.0', name: 'wave', frames: [{ index: 0, paths: [{ points: [{ x: 0, y: 0 }, { x: 5, y: 5 }] }] }] } });
    assert.strictEqual(inline.isError, true);
    assert.match(inline.content[0].text, /compile-asset --format c.*inline paths .* not supported for the C target/s);
    const anim = await mk('vanim', 'walk', assetsLib.specFor('vanim').example('walk'));
    assert.match(anim.usage, /DRAW_ANIM\(WALK_anim, WALK_anim_sprites, x, y, mirror\)/);
    const instr = await mk('vinstr', 'piano', assetsLib.specFor('vinstr').example('piano'));
    assert.strictEqual(instr.path, 'assets/instruments/piano.vinstr');
    assert.match(instr.validatedBy, /compile-asset --format c/);
    assert.match(instr.usage, /^#include "piano\.h"\nPLAY_NOTE\(PIANO_instr, channel, midi_note\);/);
    const rec = await mk('vrec', 'clip', assetsLib.specFor('vrec').example('clip'));
    assert.match(rec.usage, /^#include "clip\.h"\nDRAW_RECORDING\(CLIP_vrec, x, y, scale, frame\);/);
    const smp = await mk('vsmp', 'voice', assetsLib.specFor('vsmp').example('voice'));
    assert.match(smp.usage, /^#include "voice\.h"\nPLAY_SAMPLE\(VOICE_smp\);/);
    for (const r of [instr, rec, smp]) assert.ok(!r.warnings || !r.warnings.some((w) => /Makefile/.test(w)), `${r.type}: the template Makefile compiles it`);
    const fmt = json(await client.callTool('asset_get_format', { type: 'vsmp' }));
    assert.match(fmt.usage.cNote, /uvm2 .*no-op/);
    const l = json(await client.callTool('assets_list', {}));
    assert.strictEqual(l.project.language, 'c');
    assert.strictEqual(l.makefileCompilesAssets, true);
    assert.deepStrictEqual(l.typesNotUsableInThisLanguage.map((t) => t.type), []);
    for (const t of ['vinstr', 'vrec', 'vsmp', 'vscene']) assert.ok(l.assets[t] && !l.assets[t].items[0].warning, `${t}: listed without a warning`);
    fake.project = null;
  });

  await withCli('C project with a Makefile from before .vinstr/.vrec/.vsmp: asset_create warns about the missing rule', async () => {
    const old = await templates.createProjectFromTemplate({ kind: 'c', name: 'oldmk', parentDir: aParent, sdkVersion: 'v1.3.2' });
    const mkPath = path.join(old.projectDir, 'Makefile');
    fs.writeFileSync(mkPath, fs.readFileSync(mkPath, 'utf-8').split('\n').filter((l) => !/vinstr|vrec|vsmp|REC_SRCS|assets\/samples/.test(l)).join('\n'));
    assert.ok(await assetsLib.makefileCompilesAssets(old.projectDir));
    assert.ok(!(await assetsLib.makefileCompilesExt(old.projectDir, '.vinstr')));
    assert.ok(await assetsLib.makefileCompilesExt(old.projectDir, '.vec'));
    openProjectFake(old.projectFile);
    const r = await client.callTool('asset_create', { type: 'vinstr', name: 'organ', content: assetsLib.specFor('vinstr').example('organ') });
    assert.ok(!r.isError, r.content[0].text);
    assert.ok(json(r).warnings.some((w) => /no rule for \.vinstr/.test(w)), JSON.stringify(json(r).warnings));
    fake.project = null;
  });

  // ── ide_get_context "assets" + "api"; api_reference ─────────────────────
  const apiLib = require(path.join(DIST, 'apiReference.js'));
  const sdkMgr = require(path.join(DIST, '..', 'sdkManager.js'));
  let cliHasBuiltins = false;
  if (vpyCli) cliHasBuiltins = require('child_process').spawnSync(vpyCli, ['builtins', '--help'], { encoding: 'utf-8' }).status === 0;
  const withBuiltins = cliHasBuiltins ? test : async (name) => console.log(`  skip ${name} (the bundled vpy_cli has no "builtins": rebuild it with run-ide.sh)`);
  const registry = () => {
    const r = require('child_process').spawnSync(vpyCli, ['builtins', '--json'], { encoding: 'utf-8', maxBuffer: 1 << 24 });
    return JSON.parse(r.stdout.trim().split('\n').reverse().find((l) => l.startsWith('{')));
  };
  // Size as it would be for a project in the default workspace: the harness's temp paths
  // (/var/folders/.../vs-mcp-XXXX/...) are longer than ~/VectrexStudio/projects/<name>.
  const ctxSize = (ctx) => {
    const typical = JSON.stringify(ctx).split(tmp).join(path.join(os.homedir(), 'VectrexStudio', 'projects'));
    return { compact: Buffer.byteLength(JSON.stringify(ctx)), typical: Buffer.byteLength(typical), asSent: Buffer.byteLength(JSON.stringify(ctx, null, 2)) };
  };

  await withBuiltins('ide_get_context (VPy project): assets with their code, the api of the selected target, how-to', async () => {
    openProjectFake(vproj.projectFile);
    fake.buildTarget = 'm6809';
    const ctx = json(await client.callTool('ide_get_context'));
    assert.ok(!ctx.assets.error && !ctx.api.error, JSON.stringify({ a: ctx.assets.error, b: ctx.api.error }));
    if (fs.existsSync(path.join(vproj.projectDir, 'assets/vectors/ship.vec'))) {
      assert.ok(ctx.assets.byType.vec.includes('ship: DRAW_VECTOR("ship", x, y)'), JSON.stringify(ctx.assets.byType.vec));
      assert.ok(ctx.assets.byType.vmus.some((l) => l.startsWith('theme: PLAY_MUSIC("theme")')));
      assert.ok(ctx.assets.byType.vplay.some((l) => l.startsWith('level1: LOAD_LEVEL("level1")')));
    }
    assert.match(ctx.assets.canCreate, /^asset_create .*vec vector sprite.*vplay level/);
    assert.ok(!/vmesh/.test(ctx.assets.canCreate), 'VPy cannot use .vmesh');
    const api = ctx.api;
    assert.strictEqual(ctx.project.kind, 'vpy');
    assert.match(api.source, /^vpy_cli .* builtins/);
    const lines = Object.values(api.functions).flat();
    for (const call of ['DRAW_LINE(', 'DRAW_VECTOR(', 'PLAY_MUSIC(', 'PLAY_SFX(', 'J1_X(', 'PRINT_TEXT(', 'PRINT_NUMBER(', 'rand_range(', 'sin(']) {
      assert.ok(lines.some((l) => l.startsWith(call)), `api lacks ${call}`);
    }
    assert.ok(lines.every((l) => / — \S/.test(l)), 'every VPy api line has a purpose');
    assert.ok(!lines.some((l) => /^(PLAY_SAMPLE|WAIT_RECAL|MUSIC_UPDATE|GET_TIME)\(/.test(l)), 'm6809 rejects PLAY_SAMPLE; injected / broken calls are not offered');
    for (const need of ['rotate a sprite', 'many objects', 'music and sound effects', 'joystick and buttons', 'text and score', 'random numbers', 'collisions', 'levels']) {
      assert.ok(api.howTo.some((h) => h.startsWith(need + ':')), `howTo lacks "${need}"`);
    }
    assert.ok(api.howTo.some((h) => /^rotate a sprite: DRAW_VECTOR_3D\("ship", 0, 0, angle, x, y\)/.test(h)));
    const reg = registry();
    if (reg.builtins.some((b) => b.name === 'DRAW_VECTOR_ROT' && b.targets.includes('m6809'))) {
      assert.ok(api.howTo.some((h) => /^rotate a sprite: DRAW_VECTOR_ROT\("ship", x, y, angle\) — .*0.127/.test(h)), 'a compiler with DRAW_VECTOR_ROT must offer it for rotation, with its angle unit');
    }
    assert.match(api.more, /api_reference/);
    const size = ctxSize(ctx);
    console.log(`       (VPy ide_get_context: ${size.compact} B compact JSON here, ${size.typical} B with a default-workspace path, ${size.asSent} B as sent, indented)`);
    // Budget: about 8 KB for a typical project (measured above); the guard leaves room for doc growth.
    assert.ok(size.typical < 8704, `ide_get_context is ${size.typical} bytes (budget ~8 KB)`);
    fake.buildTarget = 'rp2350';
    const arm = json(await client.callTool('ide_get_context')).api;
    assert.ok(Object.values(arm.functions).flat().some((l) => l.startsWith('PLAY_SAMPLE(')), 'rp2350 has PLAY_SAMPLE');
    fake.buildTarget = 'm6809';
    fake.project = null;
  });

  await withBuiltins('api_reference (VPy): every compiler builtin, per-target availability, topics and queries', async () => {
    openProjectFake(vproj.projectFile);
    fake.buildTarget = 'm6809';
    const ref = json(await client.callTool('api_reference', {}));
    assert.strictEqual(ref.language, 'vpy');
    const reg = registry();
    assert.deepStrictEqual(reg.undocumented, [], 'every builtin has a doc line in docs/MANUAL.md');
    assert.deepStrictEqual(ref.entries.map((e) => e.name), reg.builtins.map((b) => b.name), 'api_reference = the compiler catalog');
    for (const b of reg.builtins) {
      const e = ref.entries.find((x) => x.name === b.name);
      assert.deepStrictEqual(e.targets, b.targets, b.name);
      assert.strictEqual(e.onTarget, b.targets.includes('m6809'), b.name);
      assert.ok(e.doc, `${b.name} has no doc`);
    }
    // Cross-check with the m6809 codegen's own arity registry: each name is a builtin, or a
    // BIOS routine the call compiles to (VECTREX.I).
    const src = fs.readFileSync(path.join(REPO, 'buildtools/vpy_codegen/src/m6809/builtins.rs'), 'utf-8');
    const table = src.slice(src.indexOf('static BUILTIN_ARITIES'), src.indexOf('];', src.indexOf('static BUILTIN_ARITIES')));
    const arities = [...table.matchAll(/\("([A-Z0-9_]+)",\s*\d+\)/g)].map((m) => m[1]);
    assert.ok(arities.length > 40);
    const bios = new Set([...fs.readFileSync(path.join(REPO, 'ide/frontend/public/include/VECTREX.I'), 'utf-8').matchAll(/^\s*([A-Za-z_0-9]+)\s+EQU/gm)].map((m) => m[1].toUpperCase()));
    const names = new Set(ref.entries.map((e) => e.name.toUpperCase()));
    for (const n of arities) assert.ok(names.has(n) || bios.has(n), `BUILTIN_ARITIES has ${n} but api_reference does not`);
    for (const n of arities.filter((x) => names.has(x))) {
      assert.ok(ref.entries.find((e) => e.name.toUpperCase() === n).targets.includes('m6809'), `${n} is in the m6809 registry but not available on m6809`);
    }
    assert.ok(!ref.entries.find((e) => e.name === 'PLAY_SAMPLE').targets.includes('m6809'));
    assert.ok(ref.howTo.length >= 8);
    assert.ok(ref.topics.includes('howto') && ref.topics.includes('Drawing'));
    const q = json(await client.callTool('api_reference', { query: 'button' }));
    assert.ok(q.entries.some((e) => e.name === 'J1_BUTTON_1') && q.entries.every((e) => /button/i.test(JSON.stringify(e))));
    const t = json(await client.callTool('api_reference', { topic: 'audio', target: 'rp2350' }));
    assert.strictEqual(t.target, 'rp2350');
    assert.ok(t.entries.every((e) => e.category === 'Audio') && t.entries.find((e) => e.name === 'PLAY_SAMPLE').onTarget);
    const h = json(await client.callTool('api_reference', { topic: 'howto' }));
    assert.ok(Array.isArray(h.howTo) && !h.entries);
    const none = await client.callTool('api_reference', { topic: 'no-such-topic' });
    assert.strictEqual(none.isError, true);
    assert.match(none.content[0].text, /Nothing matches.*Topics: .*Drawing/);
    const badTarget = await client.callTool('api_reference', { target: 'gameboy' });
    assert.strictEqual(badTarget.isError, true);
    fake.project = null;
    const noProj = await client.callTool('api_reference', {});
    assert.strictEqual(noProj.isError, true);
    assert.match(noProj.content[0].text, /No project is open/);
  });

  // C: the reference comes from the headers of the project's PINNED SDK version. A private
  // SDK root holds a synthetic v9.9.9 (with a rotation call v1.3.2 does not have) and, when
  // it is installed on this machine, a copy of the real v1.3.2 headers.
  const sdkRoot = path.join(tmp, 'sdkroot');
  const mkSdk = (tag, files) => {
    const inc = path.join(sdkRoot, tag, 'vpy-c', 'include');
    fs.mkdirSync(inc, { recursive: true });
    for (const [f, text] of Object.entries(files)) fs.writeFileSync(path.join(inc, f), text);
    fs.writeFileSync(path.join(sdkRoot, tag, '.vectrex-studio-sdk.json'), JSON.stringify({ tag }));
  };
  const FAKE_VPY_H = `/*
 * vpy.h — test runtime.
 */
#ifndef VPY_H
#define VPY_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

/* ---- lifecycle ---- */
void vpy_run(void (*setup)(void), void (*loop)(void)); /* init; setup(); loop forever */

#define VPY_PRI_KEEP   255   /* never shed */
typedef struct {
    uint32_t frames;    /* flushes */
} vpy_draw_stats_t;

/* ---- drawing (VPy space) ---- */
void vpy_draw_line(int x0, int y0, int x1, int y1, int b);
/* Draw a compiled .vec rotated by angle (0..255 = full turn)
 * around its centre. */
void vpy_draw_vector_rot(const unsigned char *data, int x, int y,
                         int angle);
void vpy_draw_vector(const unsigned char *data, int x, int y);

/* ---- input ---- */
int vpy_j1_x(void);                  /* -127..127 */
int vpy_j1_button(int n);            /* n = 1..4 -> 0/1 */

/* ---- math ---- */
int vpy_sin(int a);                  /* a: 0..127 = full circle */
int vpy_cos(int a);
int vpy_abs(int v);
int vpy_rand_range(int lo, int hi);

#ifdef VPY_SHORT_NAMES
#define DRAW_LINE       vpy_draw_line
#define DRAW_VECTOR     vpy_draw_vector
#define DRAW_VECTOR_ROT vpy_draw_vector_rot
#define J1_X            vpy_j1_x
#define J1_BUTTON_1()   vpy_j1_button(1)
#endif

#ifdef __cplusplus
}
#endif
#endif /* VPY_H */
`;
  mkSdk('v9.9.9', {
    'vpy.h': FAKE_VPY_H,
    'vpy3d.h': '/* vpy3d.h — test 3D. */\n#include "vpy.h"\n/* ---- transforms ---- */\nint vpy3d_rot_z(int ang);   /* rotation about z */\n',
    'vpyphys.h': '/*\n * vpyphys.h — rigid bodies for tests.\n */\n/* ---- bodies ---- */\nint vpyphys_step(int dt);   /* advance the world */\n',
  });
  const realInc = path.join(os.homedir(), 'VectrexStudio', 'sdk', 'v1.3.2', 'vpy-c', 'include');
  const haveReal = fs.existsSync(path.join(realInc, 'vpy.h'));
  if (haveReal) mkSdk('v1.3.2', Object.fromEntries(fs.readdirSync(realInc).filter((f) => f.endsWith('.h')).map((f) => [f, fs.readFileSync(path.join(realInc, f), 'utf-8')])));

  /** Independent scan of a header: top-level prototypes (name list) and VPY_SHORT_NAMES aliases. */
  const scanHeader = (text) => {
    const noCpp = text.replace(/#ifdef __cplusplus[\s\S]*?#endif/g, '');
    const short = {};
    const sm = /#ifdef VPY_SHORT_NAMES([\s\S]*?)\n#endif/.exec(noCpp);
    if (sm) for (const m of sm[1].matchAll(/^#define\s+([A-Za-z_]\w*)\s+(vpy\w*)\s*$/gm)) short[m[2]] = m[1];
    const code = noCpp.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/^#.*$/gm, '').replace(/typedef[\s\S]*?;/g, '').replace(/\{[^{}]*\}/g, '');
    const protos = [...code.matchAll(/([A-Za-z_]\w*)\s*\(([^;{}]*)\)\s*;/g)].map((m) => m[1]).filter((n) => /^vpy/.test(n));
    return { protos, short };
  };

  await test('ide_get_context + api_reference (C project): the pinned SDK\'s headers, short names, new calls picked up', async () => {
    const prevRoot = process.env.VECTREX_STUDIO_SDK_DIR;
    process.env.VECTREX_STUDIO_SDK_DIR = sdkRoot;
    const prevPin = await sdkMgr.readProjectSdkVersion(cproj.projectFile);
    try {
      await sdkMgr.writeProjectSdkVersion(cproj.projectFile, 'v9.9.9');
      openProjectFake(cproj.projectFile);
      fake.buildTarget = 'rp2350';
      const ctx = json(await client.callTool('ide_get_context'));
      assert.ok(!ctx.api.error, ctx.api.error);
      assert.strictEqual(ctx.project.sdk.version, 'v9.9.9');
      const api = ctx.api;
      assert.match(api.source, /uvmc2-sdk v9\.9\.9: vpy\.h, vpy3d\.h/);
      const lines = Object.values(api.functions).flat();
      assert.ok(lines.includes('DRAW_LINE(x0, y0, x1, y1, b)'), JSON.stringify(api.functions));
      assert.ok(lines.includes('DRAW_VECTOR_ROT(data, x, y, angle) — Draw a compiled .vec rotated by angle'), JSON.stringify(lines));
      assert.ok(lines.includes('J1_X() -> int — -127..127'));
      assert.ok(lines.includes('vpy_sin(a) -> int — a: 0..127 = full circle'));
      assert.ok(!lines.some((l) => /vpy_run|VPY_PRI/.test(l)), 'lifecycle and constants are not in the compact view');
      assert.ok(api.howTo.some((h) => /^rotate a sprite: DRAW_VECTOR_ROT\(SHIP_vec, x, y, angle\)/.test(h)), JSON.stringify(api.howTo));
      assert.ok(api.howTo.some((h) => /^joystick and buttons: J1_X\(\)/.test(h)));
      assert.match(api.modules, /vpy3d\.h \(1 functions.*also vpyphys/);
      if (fs.existsSync(path.join(cproj.projectDir, 'assets/vectors/ship.vec'))) {
        assert.ok(ctx.assets.byType.vec.includes('ship: #include "ship.h" DRAW_VECTOR(SHIP_vec, x, y);'), JSON.stringify(ctx.assets.byType.vec));
      }
      assert.match(ctx.assets.canCreate, /vmesh/);

      const ref = json(await client.callTool('api_reference', {}));
      assert.strictEqual(ref.language, 'c');
      const scanned = scanHeader(FAKE_VPY_H);
      assert.deepStrictEqual(ref.entries.filter((e) => e.header === 'vpy.h' && !e.kind).map((e) => e.name), scanned.protos);
      for (const [fn, sh] of Object.entries(scanned.short)) assert.strictEqual(ref.entries.find((e) => e.name === fn).short, sh);
      const rot = ref.entries.find((e) => e.name === 'vpy_draw_vector_rot');
      assert.strictEqual(rot.signature, 'void vpy_draw_vector_rot(const unsigned char *data, int x, int y, int angle)');
      assert.strictEqual(rot.doc, 'Draw a compiled .vec rotated by angle (0..255 = full turn) around its centre.');
      assert.strictEqual(rot.category, 'drawing (VPy space)');
      assert.strictEqual(ref.entries.find((e) => e.name === 'vpy_draw_vector').doc, '', 'a comment documents only the declaration below it');
      assert.ok(ref.entries.some((e) => e.name === 'J1_BUTTON_1' && e.kind === 'macro' && e.aliasOf === 'vpy_j1_button'));
      assert.ok(ref.entries.some((e) => e.name === 'VPY_PRI_KEEP' && e.kind === 'constant' && e.doc === 'never shed'));
      assert.ok(!ref.entries.some((e) => /frames|vpy_draw_stats_t/.test(e.name)), 'struct members are not API');
      assert.ok(ref.entries.some((e) => e.name === 'vpy3d_rot_z' && e.header === 'vpy3d.h'));
      assert.deepStrictEqual(ref.modules, [{ header: 'vpyphys.h', summary: 'rigid bodies for tests' }]);
      const phys = json(await client.callTool('api_reference', { topic: 'vpyphys' }));
      assert.deepStrictEqual(phys.entries.map((e) => e.name), ['vpyphys_step']);
      const q = json(await client.callTool('api_reference', { query: 'rot' }));
      assert.deepStrictEqual(q.entries.map((e) => e.name).sort(), ['vpy3d_rot_z', 'vpy_draw_vector_rot']);

      if (haveReal) {
        // The real v1.3.2: every prototype of its vpy.h and every short name, nothing else.
        await sdkMgr.writeProjectSdkVersion(cproj.projectFile, 'v1.3.2');
        const real = json(await client.callTool('api_reference', { topic: 'vpy.h' }));
        assert.match(real.source, /uvmc2-sdk v1\.3\.2/);
        const s = scanHeader(fs.readFileSync(path.join(realInc, 'vpy.h'), 'utf-8'));
        assert.deepStrictEqual(real.entries.filter((e) => !e.kind).map((e) => e.name), s.protos);
        for (const [fn, sh] of Object.entries(s.short)) assert.strictEqual(real.entries.find((e) => e.name === fn).short, sh, fn);
        const rctx = json(await client.callTool('ide_get_context'));
        const rot2 = rctx.api.howTo.find((h) => h.startsWith('rotate a sprite:'));
        assert.ok(rot2 && (/DRAW_VECTOR_ROT|vpy_draw_vector_rot/.test(rot2) === s.protos.includes('vpy_draw_vector_rot')), rot2);
        const size = ctxSize(rctx);
        console.log(`       (C ide_get_context on SDK v1.3.2: ${size.compact} B compact JSON here, ${size.typical} B with a default-workspace path, ${size.asSent} B as sent)`);
        assert.ok(size.typical < 8704, `ide_get_context is ${size.typical} bytes (budget ~8 KB)`);
      } else {
        console.log('       (SDK v1.3.2 is not installed here: the real-header cross-check was skipped)');
      }
    } finally {
      if (prevPin) await sdkMgr.writeProjectSdkVersion(cproj.projectFile, prevPin);
      if (prevRoot === undefined) delete process.env.VECTREX_STUDIO_SDK_DIR; else process.env.VECTREX_STUDIO_SDK_DIR = prevRoot;
      fake.project = null;
      fake.buildTarget = 'm6809';
    }
  });

  await test('apiReference helpers: shortDoc keeps parentheses whole; parseCHeader joins multi-line prototypes', async () => {
    assert.strictEqual(apiLib.shortDoc('Draw a 3D .vec asset rotated by (ax, ay, az)'), 'Draw a 3D .vec asset rotated by (ax, ay, az)');
    assert.strictEqual(apiLib.shortDoc('Text size for later PRINT_TEXT calls (ARM only; on m6809 it fails)'), 'Text size for later PRINT_TEXT calls');
    assert.strictEqual(apiLib.shortDoc('Sine. Argument 0..127 covers full circle'), 'Sine');
    assert.strictEqual(apiLib.shortDoc('a: 0..127 = full circle; returns -127..127'), 'a: 0..127 = full circle');
    assert.strictEqual(apiLib.shortDoc('Render the level at the current camera position of the loaded world map'), 'Render the level at the current camera position');
    const p = apiLib.parseCHeader('/* ---- a ---- */\nint vpy_f(int a,\n          int b);   /* sum */\n', 'x.h');
    assert.deepStrictEqual(p.entries.map((e) => [e.name, e.signature, e.doc, e.category]), [['vpy_f', 'int vpy_f(int a, int b)', 'sum', 'a']]);
  });

  // ── Raw TCP endpoint ─────────────────────────────────────────────────────
  await test('TCP: correct token -> ok, then requests are served', async () => {
    const s = tcpSession(portB);
    s.send({ jsonrpc: '2.0', id: 0, method: 'auth', params: { token: TOKEN } });
    const a = await s.next();
    assert.strictEqual(a.result.ok, true);
    s.send({ jsonrpc: '2.0', id: 7, method: 'ide/ping' });
    const p = await s.next();
    assert.strictEqual(p.id, 7);
    assert.strictEqual(p.result.ok, true);
    s.end();
  });

  await test('TCP: wrong token -> error reply and socket closed', async () => {
    const s = tcpSession(portB);
    s.send({ jsonrpc: '2.0', id: 0, method: 'auth', params: { token: 'f'.repeat(64) } });
    const a = await s.next();
    assert.ok(a.error);
    assert.match(a.error.message, /Unauthorized/);
    assert.ok(await s.waitClosed(), 'socket not closed');
  });

  await test('TCP: request before auth is not served', async () => {
    const s = tcpSession(portB);
    s.send({ jsonrpc: '2.0', id: 5, method: 'ide/list_tools' });
    const a = await s.next();
    assert.ok(a.error && !a.result);
    assert.ok(await s.waitClosed(), 'socket not closed');
  });

  await test('TCP: parse error after auth -> error carrying the salvaged id', async () => {
    const s = tcpSession(portB);
    s.send({ jsonrpc: '2.0', id: 0, method: 'auth', params: { token: TOKEN } });
    await s.next();
    s.send('{"jsonrpc":"2.0","id":42,"method":"ide/ping",oops}');
    const e = await s.next();
    assert.strictEqual(e.id, 42);
    assert.strictEqual(e.error.code, -32700);
    s.end();
  });

  await test('stdio server with a wrong token -> isError explaining the rejection', async () => {
    const bad = new StdioClient({ VECTREX_STUDIO_MCP_PORT: String(portB), VECTREX_STUDIO_MCP_TOKEN: 'deadbeef' });
    try {
      await bad.request('initialize', { protocolVersion: '2025-06-18', capabilities: {} });
      const r = await bad.callTool('editor_list_documents');
      assert.strictEqual(r.isError, true);
      assert.match(r.content[0].text, /rejected/);
    } finally { bad.kill(); }
  });

  // ── Phase 3: IDE goes away and comes back ────────────────────────────────
  await test('IDE stops -> isError; IDE restarts -> next call succeeds', async () => {
    tcp.stopMcpTcpServer();
    await sleep(200);
    const down = await client.callTool('editor_list_documents');
    assert.strictEqual(down.isError, true);
    assert.match(down.content[0].text, /Vectrex Studio/);
    const port = await tcp.startMcpTcpServer(handler, [portB]);
    assert.strictEqual(port, portB);
    const up = await client.callTool('editor_list_documents');
    assert.ok(!up.isError, up.content[0].text);
  });

  // ── Electron as Node ─────────────────────────────────────────────────────
  let electronBin = null;
  try { electronBin = require(path.join(__dirname, '..', '..', 'electron', 'node_modules', 'electron')); } catch { /* not installed */ }
  if (electronBin && fs.existsSync(electronBin)) {
    await test('runs under ELECTRON_RUN_AS_NODE=1 and reaches the IDE', async () => {
      const ec = new StdioClient({ VECTREX_STUDIO_MCP_PORT: String(portB), VECTREX_STUDIO_MCP_TOKEN: TOKEN }, electronBin, { ELECTRON_RUN_AS_NODE: '1' });
      try {
        const init = await ec.request('initialize', { protocolVersion: '2025-06-18', capabilities: {} }, 20000);
        assert.strictEqual(init.result.protocolVersion, '2025-06-18');
        const r = await ec.callTool('editor_list_documents');
        assert.ok(!r.isError, r.content[0].text);
      } finally { ec.kill(); }
    });
  } else {
    console.log('  skip ELECTRON_RUN_AS_NODE test (electron not installed in ide/electron)');
  }

  // ── Renderer half (mcpBridge.ts) in Node, bundled with the frontend's esbuild ──
  const esbuildBin = path.join(__dirname, '..', '..', 'frontend', 'node_modules', '.bin', 'esbuild');
  if (fs.existsSync(esbuildBin)) {
    await test('renderer bridge: setBuildTarget + runBuild (awaited F5/Shift+F5, emulator state, own output)', async () => {
      const { execFileSync } = require('child_process');
      const out = path.join(tmp, 'renderer-bridge.cjs');
      execFileSync(esbuildBin, [path.join(__dirname, 'renderer', 'bridge.test.ts'), '--bundle', '--platform=node',
        '--format=cjs', `--outfile=${out}`, '--log-level=error'], { stdio: 'pipe' });
      let text;
      try {
        text = execFileSync(process.execPath, [out], { encoding: 'utf-8', stdio: 'pipe', timeout: 60000 });
      } catch (e) {
        throw new Error(`renderer test failed:\n${(e.stdout || '') + (e.stderr || '')}`.split('\n').filter((l) => /^(ok|FAIL)|Error/.test(l)).join('\n'));
      }
      assert.match(text, /ALL OK/, text);
    });
  } else {
    console.log('  skip renderer bridge test (no esbuild in ide/frontend/node_modules)');
  }

  client.kill();
  tcp.stopMcpTcpServer();
  blocker.close();
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
