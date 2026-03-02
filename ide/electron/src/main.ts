import { app, BrowserWindow, ipcMain, Menu, session, dialog } from 'electron';
import { spawn } from 'child_process';
// Legacy TypeScript emulator removed: all references to './emu6809' have been deleted.
// NOTE: Remaining emulator-related IPC endpoints that depended on globalCpu have been pruned.
// Future work: if Electron main needs limited emulator introspection, expose it explicitly
// via the existing WASM front-end (renderer) bridge or add a new secure preload API.
import { createInterface } from 'readline';
import { join, basename, dirname } from 'path';
import { existsSync } from 'fs';
import * as fs from 'fs/promises';
import { watch } from 'fs';
import * as crypto from 'crypto';
import * as net from 'net';
import { getMCPServer } from './mcp/server.js';
import type { MCPRequest } from './mcp/types.js';
import { registerAIProxyHandlers } from './ai-proxy.js';
import { storageGet, storageSet, storageDelete, storageKeys, storageClear, getStoragePath, StorageKeys } from './storage.js';
import { 
  initPyPilotDb, 
  createSession, 
  getSessions, 
  getActiveSession,
  switchSession, 
  renameSession,
  deleteSession,
  saveMessage, 
  getMessages,
  clearMessages,
  getMessageCount,
  closePyPilotDb,
  addBreakpoint,
  removeBreakpoint,
  getBreakpoints,
  getFileBreakpoints,
  clearBreakpoints
} from './pypilotDb.js';

let mainWindow: BrowserWindow | null = null;
let mcpIpcServer: net.Server | null = null;
const MCP_IPC_PORT = 9123;
const verbose = process.env.VPY_IDE_VERBOSE_LSP === '1';

// Track current project for MCP server
let currentProject: { entryFile: string; rootDir: string } | null = null;

export function getCurrentProject() {
  return currentProject;
}

export function setCurrentProject(project: { entryFile: string; rootDir: string } | null) {
  currentProject = project;
}

// --- Emulator load helpers (shared by emu:load and run:compile) -----------------
// Removed cpuColdReset/loadBinaryBase64IntoEmu: renderer now responsible for loading programs
// through WASM interface. If a future headless compile+run flow is required from main process,
// implement a minimal message pass to renderer to request load.

// Attempt BIOS load early; search multiple locations and emit rich diagnostics.
// Search order (first existing directory wins candidate ordering, but we aggregate unique files):
//   1. core/bios/
//   2. bios/ (at repo root)
//   3. repo root (process.cwd())
// Preferred filenames: bios.bin, vectrex.bin (each directory), then any other *.bin
// BIOS auto-loading removed from main process (legacy TS emulator). Responsibility can move to renderer
// using WASM memory inspection. Placeholder retained for minimal compatibility if IPC callers exist.
async function tryLoadBiosOnce(){
  mainWindow?.webContents.send('emu://status', 'BIOS auto-load (legacy) skipped: TS emulator removed.');
  return false;
}

interface LspChild {
  proc: ReturnType<typeof spawn>;
  stdin: NodeJS.WritableStream;
}
let lsp: LspChild | null = null;

async function createWindow() {
  const verbose = process.env.VPY_IDE_VERBOSE_LSP === '1';
  if (verbose) console.log('[IDE] createWindow() start');
  
  // Setup native macOS menu (only on macOS)
  if (process.platform === 'darwin') {
    const template: Electron.MenuItemConstructorOptions[] = [
      {
        label: 'Vectrex Studio',
        submenu: [
          { role: 'about' },
          { type: 'separator' },
          { role: 'services' },
          { type: 'separator' },
          { role: 'hide' },
          { role: 'hideOthers' },
          { role: 'unhide' },
          { type: 'separator' },
          { role: 'quit' }
        ]
      },
      {
        label: 'File',
        submenu: [
          {
            label: 'New',
            submenu: [
              { label: 'Project...', click: () => mainWindow?.webContents.send('command', 'project.new') },
              { type: 'separator' },
              { label: 'VPy File', accelerator: 'CmdOrCtrl+N', click: () => mainWindow?.webContents.send('command', 'file.new.vpy') },
              { label: 'C/C++ File', click: () => mainWindow?.webContents.send('command', 'file.new.c') },
              { label: 'Vector List (.vec)', click: () => mainWindow?.webContents.send('command', 'file.new.vec') },
              { label: 'Music File (.vmus)', click: () => mainWindow?.webContents.send('command', 'file.new.vmus') },
              { label: 'Sound Effect (.vsfx)', click: () => mainWindow?.webContents.send('command', 'file.new.vsfx') }
            ]
          },
          {
            label: 'Open',
            submenu: [
              { label: 'Project...', accelerator: 'CmdOrCtrl+Shift+O', click: () => mainWindow?.webContents.send('command', 'project.open') },
              { label: 'File...', accelerator: 'CmdOrCtrl+O', click: () => mainWindow?.webContents.send('command', 'file.open') }
            ]
          },
          { type: 'separator' },
          { label: 'Save', accelerator: 'CmdOrCtrl+S', click: () => mainWindow?.webContents.send('command', 'file.save') },
          { label: 'Save As...', accelerator: 'CmdOrCtrl+Shift+S', click: () => mainWindow?.webContents.send('command', 'file.saveAs') },
          { type: 'separator' },
          { label: 'Close File', click: () => mainWindow?.webContents.send('command', 'file.close') },
          { label: 'Close Project', click: () => mainWindow?.webContents.send('command', 'project.close') },
          { type: 'separator' },
          {
            label: 'Recent Projects',
            submenu: [
              { label: 'No recent projects', enabled: false }
            ]
          },
          { type: 'separator' },
          { label: 'Reset Layout', click: () => mainWindow?.webContents.send('command', 'layout.reset') }
        ]
      },
      {
        label: 'Edit',
        submenu: [
          { 
            label: 'Undo', 
            accelerator: 'CmdOrCtrl+Z',
            registerAccelerator: false,  // Let Monaco handle it
            click: () => {
              const win = BrowserWindow.getFocusedWindow();
              if (win) win.webContents.undo();
            }
          },
          { 
            label: 'Redo', 
            accelerator: 'Shift+CmdOrCtrl+Z',
            registerAccelerator: false,  // Let Monaco handle it
            click: () => {
              const win = BrowserWindow.getFocusedWindow();
              if (win) win.webContents.redo();
            }
          },
          { type: 'separator' },
          { 
            label: 'Cut', 
            accelerator: 'CmdOrCtrl+X',
            registerAccelerator: false,  // Let Monaco handle it
            click: () => {
              const win = BrowserWindow.getFocusedWindow();
              if (win) win.webContents.cut();
            }
          },
          { 
            label: 'Copy', 
            accelerator: 'CmdOrCtrl+C',
            registerAccelerator: false,  // Let Monaco handle it
            click: () => {
              const win = BrowserWindow.getFocusedWindow();
              if (win) win.webContents.copy();
            }
          },
          { 
            label: 'Paste', 
            accelerator: 'CmdOrCtrl+V',
            registerAccelerator: false,  // Let Monaco handle it
            click: () => {
              const win = BrowserWindow.getFocusedWindow();
              if (win) win.webContents.paste();
            }
          },
          { type: 'separator' },
          { 
            label: 'Select All', 
            accelerator: 'CmdOrCtrl+A',
            registerAccelerator: false,  // Let Monaco handle it
            click: () => {
              const win = BrowserWindow.getFocusedWindow();
              if (win) win.webContents.selectAll();
            }
          },
          { type: 'separator' },
          { label: 'Toggle Comment', accelerator: 'CmdOrCtrl+/', enabled: false },
          { label: 'Format Document', accelerator: 'Shift+Alt+F', enabled: false }
        ]
      },
      {
        label: 'Build',
        submenu: [
          { label: 'Build', accelerator: 'CmdOrCtrl+F7', click: () => mainWindow?.webContents.send('command', 'build.build') },
          { label: 'Build & Run', accelerator: 'CmdOrCtrl+F5', click: () => mainWindow?.webContents.send('command', 'build.run') },
          { label: 'Clean', click: () => mainWindow?.webContents.send('command', 'build.clean') }
        ]
      },
      {
        label: 'Debug',
        submenu: [
          { label: 'Start Debugging', accelerator: 'CmdOrCtrl+F5', click: () => mainWindow?.webContents.send('command', 'debug.start') },
          { label: 'Stop Debugging', accelerator: 'Shift+F5', click: () => mainWindow?.webContents.send('command', 'debug.stop') },
          { type: 'separator' },
          { label: 'Step Over', accelerator: 'F10', click: () => mainWindow?.webContents.send('command', 'debug.stepOver') },
          { label: 'Step Into', accelerator: 'F11', click: () => mainWindow?.webContents.send('command', 'debug.stepInto') },
          { label: 'Step Out', accelerator: 'Shift+F11', click: () => mainWindow?.webContents.send('command', 'debug.stepOut') },
          { type: 'separator' },
          { label: 'Toggle Breakpoint', accelerator: 'F9', click: () => mainWindow?.webContents.send('command', 'debug.toggleBreakpoint') }
        ]
      },
      {
        label: 'View',
        submenu: [
          { label: 'Emulator', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.emulator') },
          { label: 'Dual Test', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.dual-emulator') },
          { label: 'Debug', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.debug') },
          { label: 'Errors', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.errors') },
          { label: 'Output', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.output') },
          { label: 'Build Output', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.build-output') },
          { label: 'Compiler Output', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.compiler-output') },
          { label: 'Memory', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.memory') },
          { label: 'Trace', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.trace') },
          { label: 'PSG Log', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.psglog') },
          { label: 'PyPilot', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.ai-assistant') },
          { type: 'separator' },
          { label: 'Hide Active Panel', click: () => mainWindow?.webContents.send('command', 'view.hideActivePanel') },
          { label: 'Pin/Unpin Active Panel', click: () => mainWindow?.webContents.send('command', 'view.togglePinActivePanel') },
          { type: 'separator' },
          { role: 'reload' },
          { role: 'forceReload' },
          { type: 'separator' },
          { role: 'resetZoom' },
          { role: 'zoomIn' },
          { role: 'zoomOut' },
          { type: 'separator' },
          { role: 'togglefullscreen' }
        ]
      },
      {
        label: 'Window',
        submenu: [
          { role: 'minimize' },
          { role: 'zoom' },
          { type: 'separator' },
          { role: 'front' },
          { role: 'close' }
        ]
      }
    ];
    
    const menu = Menu.buildFromTemplate(template);
    Menu.setApplicationMenu(menu);
  } else {
    // On other platforms, remove menu completely
    Menu.setApplicationMenu(null);
  }
  
  const isDev = !!process.env.VITE_DEV_SERVER_URL;
  const sandboxEnabled = process.env.VPY_IDE_SANDBOX !== '0'; // Permitir desactivar sólo si hay problema específico con preload
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      // Preload aislado: exporta API mínima vía contextBridge
      preload: join(__dirname, 'preload.js'),
      contextIsolation: true,
      // Sin integración Node directa en el renderer
      nodeIntegration: false,
      // Sandbox Chromium (reduce superficie de ataque). Puede desactivarse con VPY_IDE_SANDBOX=0 para depurar si algo rompe.
      sandbox: sandboxEnabled,
      // No permitir contenido inseguro mixto
      allowRunningInsecureContent: false,
      // Bloquear navegación arbitraria (seguimos validando manualmente de todos modos)
      webSecurity: true,
      // DevTools sólo si se habilita variable explícita; en prod quedan bloqueadas incluso si usuario presiona F12
      devTools: process.env.VPY_IDE_DEVTOOLS === '1',
      // Desactivar spellcheck (no lo necesitamos y reduce código cargado)
      spellcheck: false,
    },
    autoHideMenuBar: true,
    frame: true,
  });
  if (verbose) console.log('[IDE] sandbox=', sandboxEnabled, 'dev=', isDev);
  
  // CRITICAL: Remove window menu bar completely (required even on macOS to hide HTML menu)
  mainWindow.setMenu(null);
  mainWindow.setMenuBarVisibility(false);
  mainWindow.removeMenu();

  const devUrl = process.env.VITE_DEV_SERVER_URL;
  if (devUrl) {
    if (verbose) console.log('[IDE] loading dev URL', devUrl);
    await mainWindow.loadURL(devUrl);
  } else {
    // In packaged app, frontend is in resources/frontend/
    // In dev/unpackaged, it's at ../../frontend/dist/
    const isPackaged = app.isPackaged;
    let indexPath: string;
    if (isPackaged) {
      // Packaged: resources are in process.resourcesPath
      indexPath = join(process.resourcesPath, 'frontend', 'index.html');
    } else {
      // Development: relative to compiled main.js in dist/
      indexPath = join(__dirname, '../../frontend/dist/index.html');
    }
    if (verbose) console.log('[IDE] loading file', indexPath, 'isPackaged=', isPackaged);
    await mainWindow.loadFile(indexPath);
  }
  // Bloquear apertura automática salvo flag explícita
  if (process.env.VPY_IDE_DEVTOOLS === '1') {
    if (verbose) console.log('[IDE] opening devtools (flag set)');
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  } else {
    // Cerrar si ya se abrió por alguna razón
    if (mainWindow.webContents.isDevToolsOpened()) {
      try { mainWindow.webContents.closeDevTools(); } catch {}
    }
    // Listener para cerrar si un atajo externo la abre
    mainWindow.webContents.on('devtools-opened', () => {
      if (process.env.VPY_IDE_DEVTOOLS !== '1') {
        try { mainWindow?.webContents.closeDevTools(); } catch {}
        if (verbose) console.log('[IDE] devtools closed (not allowed)');
      }
    });
  }
  if (verbose) console.log('[IDE] createWindow() end');
  
  // Hide HTML menu bar on macOS (native menu is used instead)
  if (process.platform === 'darwin') {
    mainWindow.webContents.on('did-finish-load', () => {
      mainWindow?.webContents.insertCSS(`
        .menu-container, .menu-bar, [class*="MenuRoot"], [class*="menubar"] {
          display: none !important;
          visibility: hidden !important;
          height: 0 !important;
          opacity: 0 !important;
        }
      `);
    });
  }
  
  // Initialize MCP server with main window reference
  const mcpServer = getMCPServer();
  mcpServer.setMainWindow(mainWindow);
  if (verbose) console.log('[MCP] Server initialized and connected to main window');
  
  // Start MCP IPC server for external MCP stdio process
  startMCPIpcServer();
  
  // CRITICAL: Block accidental browser reloads that would clear localStorage
  mainWindow.webContents.on('before-input-event', (event, input) => {
    const ctrl = input.control || input.meta; // Ctrl on Windows/Linux, Cmd on macOS
    
    // F5 triggers debug-continue (not reload)
    if (input.type === 'keyDown' && input.key === 'F5' && !ctrl && !input.shift) {
      console.log('[IDE] 🟢 F5 pressed - sending debug-continue to frontend');
      if (mainWindow) {
        mainWindow.webContents.send('debug-continue-hotkey');
      }
      event.preventDefault();
      return;
    }
    
    // Block Ctrl+R / Cmd+R (normal refresh)
    if (input.type === 'keyDown' && input.key === 'r' && ctrl && !input.shift) {
      console.log('[IDE] ⚠️ Blocked Ctrl/Cmd+R reload - use IDE build commands instead');
      event.preventDefault();
      return;
    }
    
    // Block Ctrl+Shift+R / Cmd+Shift+R (hard refresh - CRITICAL!)
    if (input.type === 'keyDown' && input.key === 'R' && ctrl && input.shift) {
      console.error('[IDE] 🚨 BLOCKED HARD REFRESH (Cmd+Shift+R) - This would clear ALL localStorage!');
      console.error('[IDE] 💡 If you need to reload, close and reopen the IDE instead');
      event.preventDefault();
      // Show dialog to user
      if (mainWindow) {
        mainWindow.webContents.send('command', 'app.hardRefreshBlocked');
      }
      return;
    }
    
    // Block F12 (DevTools) if not enabled
    if (input.type === 'keyDown' && input.key === 'F12' && process.env.VPY_IDE_DEVTOOLS !== '1') {
      console.log('[IDE] 🔒 Blocked F12 DevTools (use VPY_IDE_DEVTOOLS=1 to enable)');
      event.preventDefault();
      return;
    }
  });
  
  // Also block navigation events (could be triggered by links or JavaScript)
  mainWindow.webContents.on('will-navigate', (event, url) => {
    const currentUrl = mainWindow?.webContents.getURL();
    if (url !== currentUrl) {
      console.warn('[IDE] ⚠️ Blocked navigation from', currentUrl, 'to', url);
      event.preventDefault();
    }
  });
  
  // Log when page actually reloads (debugging)
  mainWindow.webContents.on('did-start-loading', () => {
    console.log('[IDE] 🔄 Page started loading - localStorage may be affected');
  });
  
  mainWindow.webContents.on('did-finish-load', () => {
    console.log('[IDE] ✅ Page finished loading');
  });
}

// Start TCP server for MCP stdio process to communicate with IDE
function startMCPIpcServer() {
  if (mcpIpcServer) return;
  
  const verbose = process.env.VPY_IDE_VERBOSE_LSP === '1';
  
  mcpIpcServer = net.createServer((socket) => {
    console.log('[MCP IPC] Client connected');
    
    let buffer = '';
    
    socket.on('data', async (chunk) => {
      buffer += chunk.toString();
      
      // Split by newlines
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';
      
      for (const line of lines) {
        if (line.trim()) {
          try {
            const request: MCPRequest = JSON.parse(line);
            console.log('[MCP IPC] ▶ Request:', request.method, 'params:', request.params);
            
            const mcpServer = getMCPServer();
            console.log('[MCP IPC] ▶ Calling handleRequest...');
            const response = await mcpServer.handleRequest(request);
            console.log('[MCP IPC] ✓ Response received:', response);
            
            // Send response back
            socket.write(JSON.stringify(response) + '\n');
            console.log('[MCP IPC] ✓ Response sent');
          } catch (e: any) {
            console.error('[MCP IPC] Error:', e.message);
            socket.write(JSON.stringify({
              jsonrpc: '2.0',
              id: null,
              error: { code: -32603, message: e.message }
            }) + '\n');
          }
        }
      }
    });
    
    socket.on('error', (err) => {
      console.error('[MCP IPC] Socket error:', err.message);
    });
    
    socket.on('close', () => {
      console.log('[MCP IPC] Client disconnected');
    });
  });
  
  mcpIpcServer.listen(MCP_IPC_PORT, 'localhost', () => {
    console.log(`[MCP IPC] Server listening on port ${MCP_IPC_PORT}`);
  });
  
  mcpIpcServer.on('error', (err: any) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`[MCP IPC] Port ${MCP_IPC_PORT} already in use`);
    } else {
      console.error('[MCP IPC] Server error:', err);
    }
  });
}

let lspPathWarned = false;
function resolveLspPath(): string | null {
  const exeName = process.platform === 'win32' ? 'vpy_lsp.exe' : 'vpy_lsp';
  const cwd = process.cwd();
  // Posibles ubicaciones (orden de prioridad):
  const candidates = [
    // Packaged app: resources directory
    join(process.resourcesPath, exeName),
    // Ejecución desde root (run-ide.ps1 hace Set-Location root antes de lanzar)
    join(cwd, 'target', 'debug', exeName),
    join(cwd, 'target', 'release', exeName),
    // Bin copiado manualmente
    join(cwd, exeName),
    // Layout monorepo: bin dentro de crate core
    join(cwd, 'core', 'target', 'debug', exeName),
    join(cwd, 'core', 'target', 'release', exeName),
    // Si por alguna razón el cwd termina en ide/electron
    join(cwd, '..', '..', 'target', 'debug', exeName),
    join(cwd, '..', '..', 'target', 'release', exeName),
    join(cwd, '..', '..', 'core', 'target', 'debug', exeName),
    join(cwd, '..', '..', 'core', 'target', 'release', exeName),
  ];
  for (const p of candidates) {
    try { if (existsSync(p)) return p; } catch {}
  }
  if (!lspPathWarned) {
    lspPathWarned = true;
    mainWindow?.webContents.send('lsp://stderr', `[LSP] CWD=${cwd}`);
    mainWindow?.webContents.send('lsp://stderr', `LSP binary not found. Tried paths:\n${candidates.join('\n')}\nCompile with: cargo build -p vectrex_lang --bin vpy_lsp`);
  }
  return null;
}

// Enumerate .vpy and .asm under examples/ and working directory (non-recursive + shallow recursive examples)
ipcMain.handle('list:sources', async (_e, args: { limit?: number } = {}) => {
  const limit = args.limit ?? 200;
  const cwd = process.cwd();
  const exDir = join(cwd, 'examples');
  const results: Array<{ path:string; kind:'vpy'|'asm'; size:number; mtime:number }> = [];

// Update native menu with recent projects
ipcMain.handle('menu:updateRecentProjects', async (_e, recents: Array<{name: string; path: string}>) => {
  if (process.platform !== 'darwin' || !mainWindow) return;
  
  const template: Electron.MenuItemConstructorOptions[] = [
    {
      label: 'Vectrex Studio',
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        { role: 'services' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideOthers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit' }
      ]
    },
    {
      label: 'File',
      submenu: [
        {
          label: 'New',
          submenu: [
            { label: 'Project...', click: () => mainWindow?.webContents.send('command', 'project.new') },
            { type: 'separator' },
            { label: 'VPy File', accelerator: 'CmdOrCtrl+N', click: () => mainWindow?.webContents.send('command', 'file.new.vpy') },
            { label: 'C/C++ File', click: () => mainWindow?.webContents.send('command', 'file.new.c') },
            { label: 'Vector List (.vec)', click: () => mainWindow?.webContents.send('command', 'file.new.vec') },
            { label: 'Music File (.vmus)', click: () => mainWindow?.webContents.send('command', 'file.new.vmus') },
            { label: 'Sound Effect (.vsfx)', click: () => mainWindow?.webContents.send('command', 'file.new.vsfx') }
          ]
        },
        {
          label: 'Open',
          submenu: [
            { label: 'Project...', accelerator: 'CmdOrCtrl+Shift+O', click: () => mainWindow?.webContents.send('command', 'project.open') },
            { label: 'File...', accelerator: 'CmdOrCtrl+O', click: () => mainWindow?.webContents.send('command', 'file.open') }
          ]
        },
        { type: 'separator' },
        { label: 'Save', accelerator: 'CmdOrCtrl+S', click: () => mainWindow?.webContents.send('command', 'file.save') },
        { label: 'Save As...', accelerator: 'CmdOrCtrl+Shift+S', click: () => mainWindow?.webContents.send('command', 'file.saveAs') },
        { type: 'separator' },
        { label: 'Close File', click: () => mainWindow?.webContents.send('command', 'file.close') },
        { label: 'Close Project', click: () => mainWindow?.webContents.send('command', 'project.close') },
        { type: 'separator' },
        {
          label: 'Recent Projects',
          submenu: recents.length > 0 
            ? recents.map(r => ({
                label: r.name,
                click: () => mainWindow?.webContents.send('command', 'project.openPath', r.path)
              }))
            : [{ label: 'No recent projects', enabled: false }]
        },
        { type: 'separator' },
        { label: 'Reset Layout', click: () => mainWindow?.webContents.send('command', 'layout.reset') }
      ]
    },
    {
      label: 'Edit',
      submenu: [
        { label: 'Undo', accelerator: 'CmdOrCtrl+Z', role: 'undo' },
        { label: 'Redo', accelerator: 'CmdOrCtrl+Y', role: 'redo' },
        { type: 'separator' },
        { label: 'Cut', accelerator: 'CmdOrCtrl+X', role: 'cut' },
        { label: 'Copy', accelerator: 'CmdOrCtrl+C', role: 'copy' },
        { label: 'Paste', accelerator: 'CmdOrCtrl+V', role: 'paste' },
        { type: 'separator' },
        { label: 'Select All', accelerator: 'CmdOrCtrl+A', role: 'selectAll' },
        { type: 'separator' },
        { label: 'Toggle Comment', accelerator: 'CmdOrCtrl+/', enabled: false },
        { label: 'Format Document', accelerator: 'Shift+Alt+F', enabled: false }
      ]
    },
    {
      label: 'Build',
      submenu: [
        { label: 'Build', accelerator: 'F7', click: () => mainWindow?.webContents.send('command', 'build.build') },
        { label: 'Build & Run', accelerator: 'F5', click: () => mainWindow?.webContents.send('command', 'build.run') },
        { label: 'Clean', click: () => mainWindow?.webContents.send('command', 'build.clean') }
      ]
    },
    {
      label: 'Debug',
      submenu: [
        { label: 'Start Debugging', accelerator: 'CmdOrCtrl+F5', click: () => mainWindow?.webContents.send('command', 'debug.start') },
        { label: 'Stop Debugging', accelerator: 'Shift+F5', click: () => mainWindow?.webContents.send('command', 'debug.stop') },
        { type: 'separator' },
        { label: 'Step Over', accelerator: 'F10', click: () => mainWindow?.webContents.send('command', 'debug.stepOver') },
        { label: 'Step Into', accelerator: 'F11', click: () => mainWindow?.webContents.send('command', 'debug.stepInto') },
        { label: 'Step Out', accelerator: 'Shift+F11', click: () => mainWindow?.webContents.send('command', 'debug.stepOut') },
        { type: 'separator' },
        { label: 'Toggle Breakpoint', accelerator: 'F9', click: () => mainWindow?.webContents.send('command', 'debug.toggleBreakpoint') }
      ]
    },
    {
      label: 'View',
      submenu: [
        { label: 'Emulator', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.emulator') },
        { label: 'Dual Test', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.dual-emulator') },
        { label: 'Debug', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.debug') },
        { label: 'Errors', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.errors') },
        { label: 'Output', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.output') },
        { label: 'Build Output', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.build-output') },
        { label: 'Compiler Output', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.compiler-output') },
        { label: 'Memory', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.memory') },
        { label: 'Trace', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.trace') },
        { label: 'PSG Log', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.psglog') },
        { label: 'PyPilot', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.ai-assistant') },
        { type: 'separator' },
        { label: 'Hide Active Panel', click: () => mainWindow?.webContents.send('command', 'view.hideActivePanel') },
        { label: 'Pin/Unpin Active Panel', click: () => mainWindow?.webContents.send('command', 'view.togglePinActivePanel') },
        { type: 'separator' },
        { role: 'reload' },
        { role: 'forceReload' },
        { type: 'separator' },
        { role: 'resetZoom' },
        { role: 'zoomIn' },
        { role: 'zoomOut' },
        { type: 'separator' },
        { role: 'togglefullscreen' }
      ]
    },
    {
      label: 'Window',
      submenu: [
        { role: 'minimize' },
        { role: 'zoom' },
        { type: 'separator' },
        { role: 'front' },
        { role: 'close' }
      ]
    }
  ];
  
  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
});
  async function scanDir(dir:string, depth:number){
    if (results.length >= limit) return;
    try {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      for (const ent of entries){
        if (results.length >= limit) break;
        const full = join(dir, ent.name);
        if (ent.isDirectory()) { if (depth<1) await scanDir(full, depth+1); continue; }
        if (/\.(vpy|asm)$/i.test(ent.name)) {
          try {
            const st = await fs.stat(full);
            results.push({ path: full, kind: /\.vpy$/i.test(ent.name)?'vpy':'asm', size: st.size, mtime: st.mtimeMs });
          } catch {}
        }
      }
    } catch {}
  }
  await scanDir(cwd, 0);
  await scanDir(exDir, 0);
  // De-dupe by path
  const seen = new Set<string>();
  const uniq = results.filter(r => { if (seen.has(r.path)) return false; seen.add(r.path); return true; });
  uniq.sort((a,b)=> a.path.localeCompare(b.path));
  return { ok:true, sources: uniq.slice(0, limit) };
});

ipcMain.handle('lsp_start', async () => {
  const verbose = process.env.VPY_IDE_VERBOSE_LSP === '1';
  if (lsp) return;
  if (verbose) console.log('[LSP] start request');
  const path = resolveLspPath();
  if (!path) return; // mensaje detallado ya emitido en resolveLspPath (una sola vez)
  if (verbose) console.log('[LSP] spawning', path);
  const child = spawn(path, [], { stdio: ['pipe', 'pipe', 'pipe'] });
  lsp = { proc: child, stdin: child.stdin! };

  let buffer = '';
  let expected: number | null = null;
  child.stdout.on('data', (chunk: Buffer) => {
    buffer += chunk.toString('utf8');
    while (true) {
      if (expected === null) {
        const headerEnd = buffer.indexOf('\r\n\r\n');
        if (headerEnd === -1) break;
        const header = buffer.slice(0, headerEnd);
        const match = /Content-Length: *([0-9]+)/i.exec(header);
        if (!match) {
          buffer = buffer.slice(headerEnd + 4);
          continue;
        }
        expected = parseInt(match[1], 10);
        buffer = buffer.slice(headerEnd + 4);
      }
      if (expected !== null && buffer.length >= expected) {
        const body = buffer.slice(0, expected);
        buffer = buffer.slice(expected);
        expected = null;
        mainWindow?.webContents.send('lsp://message', body);
        mainWindow?.webContents.send('lsp://stdout', body);
        if (verbose) console.log('[LSP<-] message len', body.length);
        continue;
      }
      break;
    }
  });

  const rlErr = createInterface({ input: child.stderr });
  rlErr.on('line', line => mainWindow?.webContents.send('lsp://stderr', line));
  child.on('exit', code => {
    mainWindow?.webContents.send('lsp://stderr', `[LSP exited ${code}]`);
    if (verbose) console.log('[LSP] exited', code);
    lsp = null;
  });
});

ipcMain.handle('lsp_send', async (_e, payload: string) => {
  if (!lsp) return;
  const bytes = Buffer.from(payload, 'utf8');
  const header = `Content-Length: ${bytes.length}\r\n\r\n`;
  lsp.stdin.write(header);
  lsp.stdin.write(bytes);
});

// MCP Server handler - Handle JSON-RPC requests from AI agents
ipcMain.handle('mcp:request', async (_e, request: MCPRequest) => {
  const verbose = process.env.VPY_IDE_VERBOSE_LSP === '1';
  if (verbose) console.log('[MCP] Received request:', request.method);
  try {
    const mcpServer = getMCPServer();
    const response = await mcpServer.handleRequest(request);
    if (verbose) console.log('[MCP] Response:', response.result ? 'success' : 'error');
    return response;
  } catch (error: any) {
    console.error('[MCP] Error handling request:', error);
    return {
      jsonrpc: '2.0' as const,
      id: request.id,
      error: {
        code: -32603,
        message: error.message || 'Internal error',
        data: error,
      },
    };
  }
});

let recentsCache: Array<{ path: string; lastOpened: number; kind: 'file' | 'folder' }> | null = null;
function getRecentsPath() { return join(app.getPath('userData'), 'recent.json'); }
async function loadRecents(): Promise<typeof recentsCache> {
  if (recentsCache) return recentsCache;
  try {
    const txt = await fs.readFile(getRecentsPath(), 'utf8');
    recentsCache = JSON.parse(txt);
  } catch { recentsCache = []; }
  return recentsCache!;
}
async function persistRecents() {
  try { await fs.writeFile(getRecentsPath(), JSON.stringify(recentsCache||[], null, 2), 'utf8'); } catch {}
}
function touchRecent(path: string, kind: 'file'|'folder') {
  const now = Date.now();
  if (!recentsCache) recentsCache = [];
  recentsCache = recentsCache.filter(r => r.path !== path);
  recentsCache.unshift({ path, lastOpened: now, kind });
  if (recentsCache.length > 30) recentsCache.length = 30;
  persistRecents();
}

ipcMain.handle('file:open', async () => {
  const win = BrowserWindow.getFocusedWindow() || mainWindow;
  if (!win) return null;
  const { canceled, filePaths } = await dialog.showOpenDialog(win, { properties: ['openFile'], filters: [{ name: 'Source', extensions: ['vpy','pseudo','asm','txt'] }] });
  if (canceled || filePaths.length === 0) return null;
  const p = filePaths[0];
  try {
    const content = await fs.readFile(p, 'utf8');
    const stat = await fs.stat(p);
    await loadRecents();
    touchRecent(p, 'file');
    return { path: p, content, mtime: stat.mtimeMs, size: stat.size, name: basename(p) };
  } catch (e: any) {
    return { error: e?.message || 'read_failed' };
  }
});

// Binary open (returns base64)
ipcMain.handle('bin:open', async () => {
  const win = BrowserWindow.getFocusedWindow() || mainWindow;
  if (!win) return null;
  const { canceled, filePaths } = await dialog.showOpenDialog(win, { properties: ['openFile'], filters: [{ name: 'Binary', extensions: ['bin'] }] });
  if (canceled || filePaths.length === 0) return null;
  const p = filePaths[0];
  try {
    const buf = await fs.readFile(p);
    return { path: p, base64: buf.toString('base64'), size: buf.length };
  } catch (e:any) {
    return { error: e?.message || 'read_failed' };
  }
});

// Emulator: load BIN
// Removed ipcMain.handle('emu:load') legacy handler.

// Resolve compiler binary path. Supports env override VPY_COMPILER_BIN.
// Binaries live in ide/electron/resources/ (dev) or process.resourcesPath (packaged).
// @param backend: 'buildtools' (default, new modular compiler) or 'core' (legacy compiler)
function resolveCompilerPath(backend: 'buildtools' | 'core' = 'buildtools'): string | null {
  const override = process.env.VPY_COMPILER_BIN;
  if (override) {
    try { if (existsSync(override)) return override; } catch {}
    mainWindow?.webContents.send('run://stderr', `VPY_COMPILER_BIN set but file not found: ${override}`);
  }

  const isWin = process.platform === 'win32';
  const resourcesDir = app.isPackaged ? process.resourcesPath : join(__dirname, '..', 'resources');

  if (backend === 'core') {
    const exe = isWin ? 'vectrexc.exe' : 'vectrexc';
    const p = join(resourcesDir, exe);
    try { if (existsSync(p)) return p; } catch {}
    mainWindow?.webContents.send('run://stderr', `Core compiler not found: ${p}\nCopy binary to ide/electron/resources/ or build with: cargo build --bin vectrexc --release`);
    return null;
  }

  const exe = isWin ? 'vpy_cli.exe' : 'vpy_cli';
  const p = join(resourcesDir, exe);
  try { if (existsSync(p)) return p; } catch {}
  mainWindow?.webContents.send('run://stderr', `Compiler not found: ${p}\nCopy binary to ide/electron/resources/ or build with: cd buildtools && cargo build --bin vpy_cli --release`);
  return null;
}

// run:compile => compile a .vpy file, produce .asm + .bin, load into emulator
// Parse compiler diagnostics from output, including semantic errors without location info
function parseCompilerDiagnostics(output: string, sourceFile: string): Array<{ file: string; line: number; col: number; message: string }> {
  const diags: Array<{ file: string; line: number; col: number; message: string }> = [];
  
  for (const line of output.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    
    // Standard format: filename:line:col: message
    const standardMatch = /(.*?):(\d+):(\d+):\s*(.*)/.exec(trimmed);
    if (standardMatch) {
      diags.push({ 
        file: standardMatch[1], 
        line: parseInt(standardMatch[2], 10) - 1, 
        col: parseInt(standardMatch[3], 10) - 1, 
        message: standardMatch[4] 
      });
      continue;
    }
    
    // New semantic error format: "error 117:27 - SemanticsError: uso de variable no declarada 'enemy_x'."
    const newSemanticMatch = /error\s+(\d+):(\d+)\s*-\s*(.*)/.exec(trimmed);
    if (newSemanticMatch) {
      diags.push({
        file: sourceFile,
        line: parseInt(newSemanticMatch[1], 10) - 1, // Convert to 0-based
        col: parseInt(newSemanticMatch[2], 10),
        message: newSemanticMatch[3].trim()
      });
      continue;
    }
    
    // Old semantic errors: [error] SemanticsErrorArity: llamada a 'PRINT_TEXT' con 4 argumentos; se esperaban 3.
    const semanticMatch = /\[error\]\s*(\w+):\s*(.*)/.exec(trimmed);
    if (semanticMatch) {
      diags.push({
        file: sourceFile, // Use the source file being compiled
        line: 0, // Default to line 0 since location is not provided
        col: 0,
        message: `${semanticMatch[1]}: ${semanticMatch[2]}`
      });
      continue;
    }
    
    // Codegen errors: [codegen] Code generation failed due to 1 error(s)
    const codegenMatch = /\[codegen\]\s*(.*)/.exec(trimmed);
    if (codegenMatch && codegenMatch[1].includes('failed')) {
      diags.push({
        file: sourceFile,
        line: 0,
        col: 0,
        message: `Codegen: ${codegenMatch[1]}`
      });
      continue;
    }
    
    // General error patterns
    if (/error|Error|ERROR/.test(trimmed) && !trimmed.includes('ERROR:') && !trimmed.includes('checking')) {
      diags.push({
        file: sourceFile,
        line: 0,
        col: 0,
        message: trimmed
      });
    }
  }
  
  return diags;
}

// Exported function for direct invocation (e.g. from MCP server)
export async function executeCompilation(args: { path: string; saveIfDirty?: { content: string; expectedMTime?: number }; autoStart?: boolean; outputPath?: string; compilerBackend?: 'buildtools' | 'core' }) {
  // CRITICAL: Log received args to debug compiler selection
  console.log('[RUN] executeCompilation received args:', JSON.stringify({ ...args, saveIfDirty: args?.saveIfDirty ? '...' : undefined }));
  
  const { path, saveIfDirty, autoStart, outputPath, compilerBackend = 'buildtools' } = args || {} as any;
  
  console.log('[RUN] Extracted compilerBackend:', compilerBackend);
  
  // Check if we have a project open - if so, compile the project instead of individual file
  const project = getCurrentProject();
  
  // Determine what to compile
  let targetPath: string;
  let isProjectMode = false;
  
  if (project?.rootDir) {
    // Project is open - find .vpyproj file
    const projectName = basename(project.rootDir);
    const vpyprojPath = join(project.rootDir, `${projectName}.vpyproj`);
    
    try {
      await fs.access(vpyprojPath);
      targetPath = vpyprojPath;
      isProjectMode = true;
      mainWindow?.webContents.send('run://stdout', `[Compiler] Compiling project: ${vpyprojPath}\n`);
      
      // Read outputPath from .vpyproj if not provided
      if (!outputPath) {
        try {
          const vpyprojContent = await fs.readFile(vpyprojPath, 'utf-8');
          const outputMatch = vpyprojContent.match(/^output\s*=\s*"(.+)"$/m);
          if (outputMatch) {
            // outputPath is relative to project root
            args.outputPath = join(project.rootDir, outputMatch[1]);
            mainWindow?.webContents.send('run://stdout', `[Compiler] Output path from .vpyproj: ${args.outputPath}\n`);
          }
        } catch (e: any) {
          mainWindow?.webContents.send('run://stderr', `[Compiler] ⚠️ Failed to read output path from .vpyproj: ${e.message}\n`);
        }
      }
    } catch {
      // No .vpyproj found, fallback to file compilation
      if (!path) {
        mainWindow?.webContents.send('run://stderr', `[Compiler] ❌ No .vpyproj file found and no file specified\n`);
        return { error: 'no_project_and_no_file' };
      }
      targetPath = path;
    }
  } else {
    // No project open - use specified file
    if (!path) {
      mainWindow?.webContents.send('run://stderr', `[Compiler] ❌ No project open and no file specified\n`);
      return { error: 'no_project_and_no_file' };
    }
    targetPath = path;
  }
  
  // Normalize potential file:// URI to local filesystem path (especially on Windows)
  let fsPath = targetPath;
  if (/^file:\/\//i.test(fsPath)) {
    try {
      // new URL handles decoding; strip leading slash for Windows drive letter patterns like /C:/
      const u = new URL(fsPath);
      fsPath = u.pathname;
      if (process.platform === 'win32' && /^\/[A-Za-z]:/.test(fsPath)) fsPath = fsPath.slice(1);
      fsPath = fsPath.replace(/\//g, require('path').sep);
    } catch {}
  }
  
  const targetDisplay = fsPath !== targetPath ? `${targetPath} -> ${fsPath}` : fsPath;
  
  // Optionally save current buffer content before compiling (only if NOT project mode)
  let savedMTime: number | undefined;
  if (!isProjectMode && saveIfDirty && typeof saveIfDirty.content === 'string') {
    try {
      const statBefore = await fs.stat(fsPath).catch(()=>null);
      if (saveIfDirty.expectedMTime && statBefore && statBefore.mtimeMs !== saveIfDirty.expectedMTime) {
        return { conflict: true, currentMTime: statBefore.mtimeMs };
      }
      await fs.writeFile(fsPath, saveIfDirty.content, 'utf8');
      // Capture the new modification time after saving
      const statAfter = await fs.stat(fsPath);
      savedMTime = statAfter.mtimeMs;
    } catch (e:any) {
      return { error: 'save_failed_before_compile', detail: e?.message };
    }
  }
  
  // Re-extract outputPath after potentially reading from .vpyproj
  const finalOutputPath = args.outputPath || outputPath;
  
  const compiler = resolveCompilerPath(compilerBackend);
  if (!compiler) return { error: 'compiler_not_found' };
  
  // CRITICAL: Always log compiler path for debugging binary resolution
  console.log('[RUN] ✓ Resolved compiler:', compiler, '(backend:', compilerBackend, ')');
  mainWindow?.webContents.send('run://stdout', `[Compiler] Using: ${compiler} (${compilerBackend})\n`);
  
  const verbose = process.env.VPY_IDE_VERBOSE_RUN === '1';
  if (verbose) console.log('[RUN] spawning compiler', compiler, fsPath);
  mainWindow?.webContents.send('run://status', `Starting compilation: ${targetDisplay}`);
  return new Promise(async (resolvePromise) => {
    // Set working directory to project root (three levels up from ide/electron/dist/)
    const workspaceRoot = join(__dirname, '..', '..', '..');
    
    let outAsm = fsPath.replace(/\.[^.]+$/, '.asm');
    
    // NEW BUILDTOOLS COMPILER ARGUMENTS
    // OLD: ['build', fsPath, '--target', 'vectrex', '--title', basename(fsPath).replace(/\.[^.]+$/, '').toUpperCase(), '--bin', '--include-dir', workspaceRoot]
    // NEW: ['build', fsPath, '--output', binPath, '--rom-size', '32768', '--bank-size', '32768', '--debug']
    
    // If outputPath is provided (from project), use it
    let finalBinPath = outAsm.replace(/\.asm$/, '.bin');
    if (finalOutputPath) {
      // outputPath is the .bin path, derive .asm from it
      const outAsmFromProject = finalOutputPath.replace(/\.bin$/, '.asm');
      finalBinPath = finalOutputPath;
      outAsm = outAsmFromProject; // CRITICAL: Use project ASM path for all checks
      // Ensure output directory exists
      const outputDir = join(finalOutputPath, '..');
      try {
        await fs.mkdir(outputDir, { recursive: true });
      } catch {}
    }
    
    // Build compiler arguments based on backend
    let argsv: string[];
    
    if (compilerBackend === 'core') {
      // LEGACY CORE COMPILER (vectrexc) ARGUMENTS
      // Usage: vectrexc build <file.vpy> --target vectrex --title TITLE --bin [--include-dir DIR]
      argsv = ['build', fsPath, '--target', 'vectrex', '--title', basename(fsPath).replace(/\.[^.]+$/, '').toUpperCase(), '--bin', '--include-dir', workspaceRoot];
    } else {
      // NEW BUILDTOOLS COMPILER (vpy_cli) ARGUMENTS
      argsv = ['build', fsPath, '--output', finalBinPath];
      
      // Add ROM size configuration if in project mode (read from .vpyproj if needed)
      // Default: 32KB single-bank
      argsv.push('--rom-size', '32768');
      argsv.push('--bank-size', '32768');
      
      // Always generate debug symbols
      argsv.push('--debug');
      
      // If verbose mode, add --verbose flag
      if (verbose) {
        argsv.push('--verbose');
      }
    }
    
    // CRITICAL: Delete old .asm and .bin files before compilation to avoid stale files
    // This ensures the IDE always loads the freshly compiled binary
    try {
      await fs.unlink(outAsm).catch(() => {});
      await fs.unlink(finalBinPath).catch(() => {});
      if (verbose) console.log('[RUN] 🗑️ Cleaned old files:', outAsm, finalBinPath);
      mainWindow?.webContents.send('run://stdout', `[Compiler] Cleaned old output files\n`);
    } catch (e: any) {
      if (verbose) console.log('[RUN] ⚠️ Error cleaning files:', e.message);
    }
    
    // CRITICAL DEBUG: Log EXACT command being executed
    const fullCommand = `"${compiler}" ${argsv.join(' ')}`;
    console.log('[RUN] 🔧 FULL COMMAND:', fullCommand);
    console.log('[RUN] 📁 Working directory:', workspaceRoot);
    console.log('[RUN] 📝 Input file (absolute):', fsPath);
    console.log('[RUN] 📦 Mode:', isProjectMode ? 'PROJECT' : 'FILE');
    mainWindow?.webContents.send('run://stdout', `[Compiler] Full command: ${fullCommand}\n`);
    mainWindow?.webContents.send('run://stdout', `[Compiler] Working dir: ${workspaceRoot}\n`);
    mainWindow?.webContents.send('run://stdout', `[Compiler] Mode: ${isProjectMode ? 'PROJECT (.vpyproj)' : 'FILE (.vpy)'}\n`);
    
    const child = spawn(compiler, argsv, { stdio: ['ignore','pipe','pipe'], cwd: workspaceRoot });
    let stdoutBuf = '';
    let stderrBuf = '';
    child.stdout.on('data', (c: Buffer) => { const txt = c.toString('utf8'); stdoutBuf += txt; mainWindow?.webContents.send('run://stdout', txt); });
    child.stderr.on('data', (c: Buffer) => { const txt = c.toString('utf8'); stderrBuf += txt; mainWindow?.webContents.send('run://stderr', txt); });
    child.on('error', (err) => { resolvePromise({ error: 'spawn_failed', detail: err.message }); });
    child.on('exit', async (code) => {
      if (code !== 0) {
        mainWindow?.webContents.send('run://status', `Compilation FAILED (exit ${code})`);
        // Parse diagnostics from compiler output using improved parser
        const allOutput = stdoutBuf + '\n' + stderrBuf;
        const diags = parseCompilerDiagnostics(allOutput, fsPath);
        if (diags.length) {
          mainWindow?.webContents.send('run://diagnostics', diags);
        }
        return resolvePromise({ error: 'compile_failed', code, stdout: stdoutBuf, stderr: stderrBuf });
      }
      // Check compilation phases: ASM generation + binary assembly
      // Use finalBinPath which accounts for project output path
      const binPath = finalBinPath;
      
      // Phase 1: Check if ASM was generated
      mainWindow?.webContents.send('run://status', `✓ Compilation Phase 1: Checking ASM generation...`);
      try {
        const asmExists = await fs.access(outAsm).then(() => true).catch(() => false);
        if (!asmExists) {
          mainWindow?.webContents.send('run://stderr', `ERROR: ASM file not generated: ${outAsm}`);
          mainWindow?.webContents.send('run://status', `❌ Phase 1 FAILED: ASM generation failed`);
          
          // Parse semantic errors from stdout/stderr even when ASM is not generated
          const allOutput = stdoutBuf + '\n' + stderrBuf;
          const diags = parseCompilerDiagnostics(allOutput, fsPath);
          if (diags.length) {
            mainWindow?.webContents.send('run://diagnostics', diags);
          }
          
          return resolvePromise({ error: 'asm_not_generated', detail: `Expected ASM file: ${outAsm}` });
        }
        
        const asmStats = await fs.stat(outAsm);
        if (asmStats.size === 0) {
          mainWindow?.webContents.send('run://stderr', `ERROR: ASM file is empty: ${outAsm}`);
          mainWindow?.webContents.send('run://status', `❌ Phase 1 FAILED: Empty ASM file generated`);
          
          // Parse semantic errors from stdout/stderr even when compilation "succeeds" but generates empty ASM
          const allOutput = stdoutBuf + '\n' + stderrBuf;
          const diags = parseCompilerDiagnostics(allOutput, fsPath);
          if (diags.length) {
            mainWindow?.webContents.send('run://diagnostics', diags);
          }
          
          return resolvePromise({ error: 'empty_asm_file', detail: `ASM file exists but is empty: ${outAsm}` });
        }
        
        mainWindow?.webContents.send('run://status', `✓ Phase 1 SUCCESS: ASM generated (${asmStats.size} bytes)`);
      } catch (e: any) {
        mainWindow?.webContents.send('run://stderr', `ERROR checking ASM file: ${e.message}`);
        mainWindow?.webContents.send('run://status', `❌ Phase 1 FAILED: Error checking ASM file`);
        return resolvePromise({ error: 'asm_check_failed', detail: e.message });
      }
      
      // Phase 2: Check if binary was assembled
      mainWindow?.webContents.send('run://status', `✓ Compilation Phase 2: Checking binary assembly...`);
      
      // Add delay to ensure lwasm has completed
      await new Promise(resolve => setTimeout(resolve, 200));
      
      try {
        const binExists = await fs.access(binPath).then(() => true).catch(() => false);
        
        if (!binExists) {
          // Binary not found - check for lwasm errors in stderr
          const lwasmeErrors = stderrBuf.split('\n').filter(line => 
            line.includes('lwasm') || 
            line.includes('fallo') || 
            line.includes('failed') ||
            line.includes('error') ||
            line.includes('ERROR')
          );
          
          if (lwasmeErrors.length > 0) {
            mainWindow?.webContents.send('run://stderr', `❌ LWASM ASSEMBLY FAILED:`);
            lwasmeErrors.forEach(err => mainWindow?.webContents.send('run://stderr', `   ${err}`));
          } else {
            mainWindow?.webContents.send('run://stderr', `❌ BINARY NOT GENERATED: ${binPath}`);
            mainWindow?.webContents.send('run://stderr', `   This usually means lwasm (6809 assembler) is not installed or failed silently.`);
            mainWindow?.webContents.send('run://stderr', `   Install lwasm or check if the generated ASM has syntax errors.`);
          }
          
          // List available files for debugging
          const dir = require('path').dirname(binPath);
          const files = await fs.readdir(dir).catch(() => []);
          const relevantFiles = files.filter(f => f.includes(require('path').basename(binPath, '.bin')));
          mainWindow?.webContents.send('run://stderr', `   Files in directory: ${relevantFiles.join(', ') || 'none'}`);
          
          mainWindow?.webContents.send('run://status', `❌ Phase 2 FAILED: Binary assembly failed`);
          return resolvePromise({ error: 'binary_not_generated', detail: `Binary file not created: ${binPath}` });
        }
        
        // Binary exists - check if it's valid
        const buf = await fs.readFile(binPath);
        
        if (buf.length === 0) {
          mainWindow?.webContents.send('run://stderr', `❌ EMPTY BINARY: ${binPath} (0 bytes)`);
          mainWindow?.webContents.send('run://stderr', `   This indicates lwasm completed but produced no output.`);
          mainWindow?.webContents.send('run://stderr', `   Check the generated ASM file for missing ORG directive or syntax errors.`);
          mainWindow?.webContents.send('run://status', `❌ Phase 2 FAILED: Empty binary generated`);
          return resolvePromise({ error: 'empty_binary', detail: `Binary file is empty: ${binPath}` });
        }
        
        // Success!
        const base64 = Buffer.from(buf).toString('base64');
        mainWindow?.webContents.send('run://status', `✅ COMPILATION SUCCESS: ${binPath} (${buf.length} bytes)`);
        mainWindow?.webContents.send('run://stdout', `✅ Generated binary: ${buf.length} bytes`);
        
        // Clear previous compilation diagnostics (successful compilation = no errors)
        mainWindow?.webContents.send('run://diagnostics', []);
        
        // Phase 3: Load .pdb debug symbols if available
        const pdbPath = binPath.replace(/\.bin$/, '.pdb');
        let pdbData: any = null;
        
        try {
          const pdbExists = await fs.access(pdbPath).then(() => true).catch(() => false);
          
          if (pdbExists) {
            const pdbContent = await fs.readFile(pdbPath, 'utf-8');
            pdbData = JSON.parse(pdbContent);
            
            // COMPATIBILITY: Transform PDB v2.0 format to legacy format for frontend
            // PDB v2.0 has vpy_line_map (address → {file, line, column})
            // Frontend expects lineMap (line → address)
            if (pdbData.version === '2.0' && pdbData.vpy_line_map && !pdbData.lineMap) {
              pdbData.lineMap = {};
              for (const [addr, loc] of Object.entries(pdbData.vpy_line_map)) {
                const location = loc as { file: string; line: number; column: number | null };
                const lineKey = location.line.toString();
                pdbData.lineMap[lineKey] = addr;
              }
            }
            
            mainWindow?.webContents.send('run://status', `✓ Phase 3 SUCCESS: Debug symbols loaded (.pdb)`);
            mainWindow?.webContents.send('run://stdout', `✓ Debug symbols: ${pdbPath}`);
          } else {
            mainWindow?.webContents.send('run://status', `⚠ Phase 3 SKIPPED: No .pdb file found`);
          }
        } catch (e: any) {
          mainWindow?.webContents.send('run://stderr', `⚠ Warning: Failed to load .pdb: ${e.message}`);
        }
        
        // Notify renderer to load binary
        mainWindow?.webContents.send('emu://compiledBin', { base64, size: buf.length, binPath, pdbData });
        resolvePromise({ 
          ok: true, 
          binPath, 
          size: buf.length, 
          stdout: stdoutBuf, 
          stderr: stderrBuf,
          savedMTime: savedMTime, // Include the mtime if file was saved during compilation
          pdbData: pdbData // Include .pdb data if available
        });
        
      } catch (e: any) {
        mainWindow?.webContents.send('run://stderr', `❌ ERROR reading binary: ${e.message}`);
        mainWindow?.webContents.send('run://status', `❌ Phase 2 FAILED: Error reading binary file`);
        resolvePromise({ error: 'bin_read_failed', detail: e.message });
      }
    });
  });
}

// IPC handler wraps the exported function
ipcMain.handle('run:compile', async (_e, args) => {
  return executeCompilation(args);
});

// Emulator: run until next frame (or max steps)
// Removed ipcMain.handle('emu:runFrame') legacy handler.
// Removed all emulator-specific debug IPC handlers (legacy TS). Renderer-side WASM now owns emulator control.

// File helpers (restored after emulator legacy removal)
ipcMain.handle('file:openPath', async (_e, p: string) => {
  if (!p) return { error: 'no_path' };
  try {
    const content = await fs.readFile(p, 'utf8');
    const stat = await fs.stat(p);
    await loadRecents();
    touchRecent(p, 'file');
    return { path: p, content, mtime: stat.mtimeMs, size: stat.size, name: basename(p) };
  } catch (e:any) {
    return { error: e?.message || 'read_failed' };
  }
});

ipcMain.handle('file:read', async (_e, path: string) => {
  if (!path) return { error: 'no_path' };
  try {
    const content = await fs.readFile(path, 'utf8');
    const stat = await fs.stat(path);
    return { path, content, mtime: stat.mtimeMs, size: stat.size, name: basename(path) };
  } catch (e:any) {
    return { error: e?.message || 'read_failed' };
  }
});

// Get file info (mtime, size) without reading content
ipcMain.handle('file:getInfo', async (_e, path: string) => {
  if (!path) return { error: 'no_path' };
  try {
    const stat = await fs.stat(path);
    return { ok: true, path, mtime: stat.mtimeMs, size: stat.size, name: basename(path) };
  } catch (e:any) {
    return { ok: false, error: e?.message || 'stat_failed' };
  }
});

// Read arbitrary binary file and return base64 (for emulator program loading without file:// fetch)
ipcMain.handle('file:readBin', async (_e, path: string) => {
  if (!path) return { error: 'no_path' };
  try {
    const buf = await fs.readFile(path);
    return { path, base64: Buffer.from(buf).toString('base64'), size: buf.length, name: basename(path) };
  } catch (e:any) {
    return { error: e?.message || 'read_failed' };
  }
});

ipcMain.handle('file:save', async (_e, args: { path: string; content: string; expectedMTime?: number }) => {
  const { path, content, expectedMTime } = args || {} as any;
  if (!path) return { error: 'no_path' };
  try {
    const statBefore = await fs.stat(path).catch(()=>null);
    if (expectedMTime && statBefore && statBefore.mtimeMs !== expectedMTime) {
      return { conflict: true, currentMTime: statBefore.mtimeMs };
    }
    // Auto-create parent directory if it doesn't exist (for assets/vectors/, assets/music/, etc.)
    const parentDir = dirname(path);
    await fs.mkdir(parentDir, { recursive: true }).catch(() => {}); // Ignore errors if directory already exists
    await fs.writeFile(path, content, 'utf8');
    const statAfter = await fs.stat(path);
    await loadRecents();
    touchRecent(path, 'file');
    return { path, mtime: statAfter.mtimeMs, size: statAfter.size };
  } catch (e: any) {
    return { error: e?.message || 'save_failed' };
  }
});

// Append text content to a file (used for large streaming traces)
ipcMain.handle('file:append', async (_e, args: { path: string; content: string }) => {
  const { path, content } = args || {} as any;
  if (!path) return { error: 'no_path' };
  try {
    const parentDir = dirname(path);
    await fs.mkdir(parentDir, { recursive: true }).catch(() => {});
    await fs.appendFile(path, content ?? '', 'utf8');
    const statAfter = await fs.stat(path).catch(() => null);
    return { ok: true, path, size: statAfter?.size };
  } catch (e: any) {
    return { error: e?.message || 'append_failed' };
  }
});

// Append binary content to a file (used for high-throughput emulator traces)
ipcMain.handle('file:appendBin', async (_e, args: { path: string; data: Uint8Array }) => {
  const { path, data } = args || {} as any;
  if (!path) return { error: 'no_path' };
  try {
    const parentDir = dirname(path);
    await fs.mkdir(parentDir, { recursive: true }).catch(() => {});
    const buf = Buffer.from(data || new Uint8Array());
    await fs.appendFile(path, buf);
    const statAfter = await fs.stat(path).catch(() => null);
    return { ok: true, path, size: statAfter?.size };
  } catch (e: any) {
    return { error: e?.message || 'append_failed' };
  }
});

// Disassemble a ROM snapshot (base64) using buildtools/vpy_disasm
ipcMain.handle('tools:disassembleSnapshot', async (_e, args: { base64: string; startHex?: string; binPath?: string }) => {
  try {
    const { base64, startHex = '0', binPath } = args || { base64: '' };
    if (!base64 || typeof base64 !== 'string') {
      return { ok: false, error: 'Invalid snapshot payload (base64 required)' };
    }
    const data = Buffer.from(base64, 'base64');
    
    // Determinar carpeta destino: junto al .bin del proyecto actual
    let outputDir: string;
    let outputBaseName: string;
    
    if (binPath) {
      // Frontend envió ruta exacta del binario compilado
      // Usar esa ubicación y nombre para los archivos de salida
      outputDir = dirname(binPath);
      outputBaseName = basename(binPath, '.bin');
    } else {
      // Sin binPath: guardar en storage/snapshots
      const storageDir = getStoragePath();
      outputDir = join(storageDir, 'snapshots');
      try { await fs.mkdir(outputDir, { recursive: true }); } catch {}
      outputBaseName = `rom_snapshot_${Date.now()}`;
    }
    
    const snapshotPath = join(outputDir, `${outputBaseName}.snapshot.bin`);
    const dissPath = join(outputDir, `${outputBaseName}.diss.asm`);
    
    // Guardar snapshot binario
    await fs.writeFile(snapshotPath, data);

    // Desensamblar TODO el snapshot
    // IMPORTANTE: 'count' es el rango de BYTES a desensamblar, no número de instrucciones
    // Para cubrir todo el snapshot, pasamos el tamaño completo
    const snapshotSize = data.length;
    
    // Use vpy_disasm from buildtools (migrated from core)
    // In development: ide/electron -> ../../buildtools
    // In packaged: app dir -> buildtools (if bundled alongside)
    const appDir = app.isPackaged ? dirname(app.getPath('exe')) : join(process.cwd(), '..', '..');
    const disasmBin = join(appDir, 'buildtools', 'target', 'release', 
      process.platform === 'win32' ? 'vpy_disasm.exe' : 'vpy_disasm');
    
    // Check if binary exists
    try {
      await fs.access(disasmBin);
    } catch {
      return { 
        ok: false, 
        error: 'Disassembler not found. Please build it first:\ncd buildtools && cargo build --release --bin vpy_disasm',
        stderr: `Binary not found at: ${disasmBin}\nApp dir: ${appDir}\nCWD: ${process.cwd()}`
      };
    }
    
    return await new Promise((resolve) => {
      const proc = spawn(disasmBin, [snapshotPath, startHex, String(snapshotSize)]);
      let stdout = '';
      let stderr = '';
      
      proc.stdout.on('data', (d) => { stdout += d.toString(); });
      proc.stderr.on('data', (d) => { stderr += d.toString(); });
      
      proc.on('error', (err) => {
        resolve({ ok: false, error: `Failed to spawn disassembler: ${err.message}`, stderr });
      });
      
      proc.on('close', async (code) => {
        if (code === 0) {
          // Guardar salida desensamblada en .diss.asm
          try {
            await fs.writeFile(dissPath, stdout, 'utf8');
            resolve({ 
              ok: true, 
              output: stdout, 
              snapshotPath,
              dissPath,
              message: `Disassembly saved to:\n${dissPath}` 
            });
          } catch (writeErr: any) {
            resolve({ ok: false, error: `Failed to write .diss.asm: ${writeErr.message}`, output: stdout, stderr });
          }
        } else {
          resolve({ ok: false, error: `vpy_disasm exit ${code}`, output: stdout, stderr });
        }
      });
    });
  } catch (error: any) {
    return { ok: false, error: String(error?.message || error) };
  }
});

ipcMain.handle('file:saveAs', async (_e, args: { suggestedName?: string; content: string }) => {
  const win = BrowserWindow.getFocusedWindow() || mainWindow;
  if (!win) return { error: 'no_window' };
  const { suggestedName, content } = args || {} as any;
  const { canceled, filePath } = await dialog.showSaveDialog(win, {
    defaultPath: suggestedName || 'untitled.vpy',
    filters: [{ name: 'Source', extensions: ['vpy','pseudo','asm','txt'] }]
  });
  if (canceled || !filePath) return { canceled: true };
  try {
    // Auto-create parent directory if it doesn't exist (for assets/vectors/, assets/music/, etc.)
    const parentDir = dirname(filePath);
    await fs.mkdir(parentDir, { recursive: true }).catch(() => {}); // Ignore errors if directory already exists
    await fs.writeFile(filePath, content, 'utf8');
    const stat = await fs.stat(filePath);
    await loadRecents();
    touchRecent(filePath, 'file');
    return { path: filePath, mtime: stat.mtimeMs, size: stat.size, name: basename(filePath) };
  } catch (e: any) {
    return { error: e?.message || 'save_failed' };
  }
});

ipcMain.handle('file:openFolder', async () => {
  const win = BrowserWindow.getFocusedWindow() || mainWindow;
  if (!win) return null;
  const { canceled, filePaths } = await dialog.showOpenDialog(win, { properties: ['openDirectory'] });
  if (canceled || filePaths.length === 0) return null;
  const p = filePaths[0];
  await loadRecents();
  touchRecent(p, 'folder');
  return { path: p };
});

ipcMain.handle('file:readDirectory', async (_e, dirPath: string) => {
  try {
    const fs = require('fs').promises;
    const path = require('path');
    
    async function readDirRecursive(currentPath: string, relativePath: string = ''): Promise<any[]> {
      const entries = await fs.readdir(currentPath, { withFileTypes: true });
      const result = [];
      
      for (const entry of entries) {
        const fullPath = path.join(currentPath, entry.name);
        const relPath = relativePath ? path.join(relativePath, entry.name) : entry.name;
        
        if (entry.isDirectory()) {
          const children = await readDirRecursive(fullPath, relPath);
          result.push({
            name: entry.name,
            path: relPath,
            isDir: true,
            children: children
          });
        } else {
          result.push({
            name: entry.name,
            path: relPath,
            isDir: false
          });
        }
      }
      
      // Sort: directories first, then files, alphabetically
      return result.sort((a, b) => {
        if (a.isDir && !b.isDir) return -1;
        if (!a.isDir && b.isDir) return 1;
        return a.name.localeCompare(b.name);
      });
    }
    
    const files = await readDirRecursive(dirPath);
    return { files };
  } catch (error) {
    return { error: `Failed to read directory: ${error}` };
  }
});

// Delete file or directory
ipcMain.handle('file:delete', async (_e, filePath: string) => {
  if (!filePath) return { error: 'no_path' };
  
  try {
    const stat = await fs.stat(filePath);
    
    if (stat.isDirectory()) {
      // Delete directory recursively
      await fs.rm(filePath, { recursive: true, force: true });
    } else {
      // Delete single file
      await fs.unlink(filePath);
    }
    
    return { success: true, path: filePath };
  } catch (e: any) {
    return { error: e?.message || 'delete_failed' };
  }
});

// Move file or directory
ipcMain.handle('file:move', async (_e, args: { sourcePath: string; targetDir: string }) => {
  const { sourcePath, targetDir } = args;
  if (!sourcePath || !targetDir) return { error: 'missing_paths' };
  
  try {
    const sourceName = basename(sourcePath);
    const targetPath = join(targetDir, sourceName);
    
    // Check if target already exists
    try {
      await fs.stat(targetPath);
      return { error: 'target_exists', targetPath };
    } catch {
      // Target doesn't exist, good to proceed
    }
    
    // Move the file/directory
    await fs.rename(sourcePath, targetPath);
    
    return { success: true, sourcePath, targetPath };
  } catch (e: any) {
    return { error: e?.message || 'move_failed' };
  }
});

ipcMain.handle('recents:load', async () => {
  const list = await loadRecents();
  return list;
});
ipcMain.handle('recents:write', async (_e, list: any[]) => {
  recentsCache = Array.isArray(list) ? list : [];
  await persistRecents();
  return { ok: true };
});

// Update native macOS menu with recent projects
ipcMain.handle('menu:updateRecentProjects', async (_e, recents: Array<{name: string; path: string}>) => {
  if (process.platform !== 'darwin' || !mainWindow) return;
  
  const template: Electron.MenuItemConstructorOptions[] = [
    {
      label: 'Vectrex Studio',
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        { role: 'services' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideOthers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit' }
      ]
    },
    {
      label: 'File',
      submenu: [
        {
          label: 'New',
          submenu: [
            { label: 'Project...', click: () => mainWindow?.webContents.send('command', 'project.new') },
            { type: 'separator' },
            { label: 'VPy File', accelerator: 'CmdOrCtrl+N', click: () => mainWindow?.webContents.send('command', 'file.new.vpy') },
            { label: 'C/C++ File', click: () => mainWindow?.webContents.send('command', 'file.new.c') },
            { label: 'Vector List (.vec)', click: () => mainWindow?.webContents.send('command', 'file.new.vec') },
            { label: 'Music File (.vmus)', click: () => mainWindow?.webContents.send('command', 'file.new.vmus') },
            { label: 'Sound Effect (.vsfx)', click: () => mainWindow?.webContents.send('command', 'file.new.vsfx') }
          ]
        },
        {
          label: 'Open',
          submenu: [
            { label: 'Project...', accelerator: 'CmdOrCtrl+Shift+O', click: () => mainWindow?.webContents.send('command', 'project.open') },
            { label: 'File...', accelerator: 'CmdOrCtrl+O', click: () => mainWindow?.webContents.send('command', 'file.open') }
          ]
        },
        { type: 'separator' },
        { label: 'Save', accelerator: 'CmdOrCtrl+S', click: () => mainWindow?.webContents.send('command', 'file.save') },
        { label: 'Save As...', accelerator: 'CmdOrCtrl+Shift+S', click: () => mainWindow?.webContents.send('command', 'file.saveAs') },
        { type: 'separator' },
        { label: 'Close File', click: () => mainWindow?.webContents.send('command', 'file.close') },
        { label: 'Close Project', click: () => mainWindow?.webContents.send('command', 'project.close') },
        { type: 'separator' },
        {
          label: 'Recent Projects',
          submenu: recents.length > 0 
            ? recents.map(r => ({
                label: r.name,
                click: () => {
                  // Send project path as payload
                  mainWindow?.webContents.send('command', 'project.openRecent', r.path);
                }
              }))
            : [{ label: 'No recent projects', enabled: false }]
        },
        { type: 'separator' },
        { label: 'Reset Layout', click: () => mainWindow?.webContents.send('command', 'layout.reset') }
      ]
    },
    {
      label: 'Edit',
      submenu: [
        { label: 'Undo', accelerator: 'CmdOrCtrl+Z', role: 'undo' },
        { label: 'Redo', accelerator: 'CmdOrCtrl+Y', role: 'redo' },
        { type: 'separator' },
        { label: 'Cut', accelerator: 'CmdOrCtrl+X', role: 'cut' },
        { label: 'Copy', accelerator: 'CmdOrCtrl+C', role: 'copy' },
        { label: 'Paste', accelerator: 'CmdOrCtrl+V', role: 'paste' },
        { type: 'separator' },
        { label: 'Select All', accelerator: 'CmdOrCtrl+A', role: 'selectAll' },
        { type: 'separator' },
        { label: 'Toggle Comment', accelerator: 'CmdOrCtrl+/', enabled: false },
        { label: 'Format Document', accelerator: 'Shift+Alt+F', enabled: false }
      ]
    },
    {
      label: 'Build',
      submenu: [
        { label: 'Build', accelerator: 'F7', click: () => mainWindow?.webContents.send('command', 'build.build') },
        { label: 'Build & Run', accelerator: 'F5', click: () => mainWindow?.webContents.send('command', 'build.run') },
        { label: 'Clean', click: () => mainWindow?.webContents.send('command', 'build.clean') }
      ]
    },
    {
      label: 'Debug',
      submenu: [
        { label: 'Start Debugging', accelerator: 'CmdOrCtrl+F5', click: () => mainWindow?.webContents.send('command', 'debug.start') },
        { label: 'Stop Debugging', accelerator: 'Shift+F5', click: () => mainWindow?.webContents.send('command', 'debug.stop') },
        { type: 'separator' },
        { label: 'Step Over', accelerator: 'F10', click: () => mainWindow?.webContents.send('command', 'debug.stepOver') },
        { label: 'Step Into', accelerator: 'F11', click: () => mainWindow?.webContents.send('command', 'debug.stepInto') },
        { label: 'Step Out', accelerator: 'Shift+F11', click: () => mainWindow?.webContents.send('command', 'debug.stepOut') },
        { type: 'separator' },
        { label: 'Toggle Breakpoint', accelerator: 'F9', click: () => mainWindow?.webContents.send('command', 'debug.toggleBreakpoint') }
      ]
    },
    {
      label: 'View',
      submenu: [
        { label: 'Emulator', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.emulator') },
        { label: 'Dual Test', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.dual-emulator') },
        { label: 'Debug', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.debug') },
        { label: 'Errors', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.errors') },
        { label: 'Output', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.output') },
        { label: 'Build Output', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.build-output') },
        { label: 'Compiler Output', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.compiler-output') },
        { label: 'Memory', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.memory') },
        { label: 'Trace', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.trace') },
        { label: 'PSG Log', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.psglog') },
        { label: 'PyPilot', type: 'checkbox', click: () => mainWindow?.webContents.send('command', 'view.toggle.ai-assistant') },
        { type: 'separator' },
        { label: 'Hide Active Panel', click: () => mainWindow?.webContents.send('command', 'view.hideActivePanel') },
        { label: 'Pin/Unpin Active Panel', click: () => mainWindow?.webContents.send('command', 'view.togglePinActivePanel') },
        { type: 'separator' },
        { role: 'reload' },
        { role: 'forceReload' },
        { type: 'separator' },
        { role: 'resetZoom' },
        { role: 'zoomIn' },
        { role: 'zoomOut' },
        { type: 'separator' },
        { role: 'togglefullscreen' }
      ]
    },
    {
      label: 'Window',
      submenu: [
        { role: 'minimize' },
        { role: 'zoom' },
        { type: 'separator' },
        { role: 'front' },
        { role: 'close' }
      ]
    }
  ];
  
  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
});

// ============================================
// Shell Command Execution (for Ollama installation)
// ============================================

ipcMain.handle('shell:runCommand', async (_e, command: string) => {
  return new Promise((resolve) => {
    const { exec } = require('child_process');
    exec(command, { maxBuffer: 1024 * 1024 * 10 }, (error: any, stdout: string, stderr: string) => {
      if (error) {
        resolve({
          success: false,
          output: stderr || error.message,
          exitCode: error.code || 1
        });
      } else {
        resolve({
          success: true,
          output: stdout,
          exitCode: 0
        });
      }
    });
  });
});

// ============================================================================
// PERSISTENT STORAGE HANDLERS
// Replaces localStorage with filesystem-backed storage in userData directory
// ============================================================================

ipcMain.handle('storage:get', async (_e, key: string) => {
  if (verbose) console.log('[IPC] storage:get:', key);
  return await storageGet(key);
});

ipcMain.handle('storage:set', async (_e, key: string, value: any) => {
  if (verbose) console.log('[IPC] storage:set:', key);
  return await storageSet(key, value);
});

ipcMain.handle('storage:delete', async (_e, key: string) => {
  if (verbose) console.log('[IPC] storage:delete:', key);
  return await storageDelete(key);
});

ipcMain.handle('storage:keys', async () => {
  if (verbose) console.log('[IPC] storage:keys');
  return await storageKeys();
});

ipcMain.handle('storage:clear', async () => {
  if (verbose) console.log('[IPC] storage:clear');
  return await storageClear();
});

ipcMain.handle('storage:path', async () => {
  if (verbose) console.log('[IPC] storage:path');
  return getStoragePath();
});

// Expose storage keys enum to frontend
ipcMain.handle('storage:getKeys', async () => {
  return StorageKeys;
});

// ============================================
// Project Management
// ============================================

// Open project dialog - returns .vpyproj file path
ipcMain.handle('project:open', async () => {
  const result = await dialog.showOpenDialog(mainWindow!, {
    title: 'Open Project',
    filters: [
      { name: 'VPy Project', extensions: ['vpyproj'] },
      { name: 'All Files', extensions: ['*'] }
    ],
    properties: ['openFile']
  });
  if (result.canceled || result.filePaths.length === 0) {
    return null;
  }
  const projectPath = result.filePaths[0];
  try {
    const content = await fs.readFile(projectPath, 'utf-8');
    // Parse TOML to validate
    const toml = await import('toml');
    const parsed = toml.parse(content);
    return {
      path: projectPath,
      config: parsed,
      rootDir: join(projectPath, '..')
    };
  } catch (e: any) {
    return { error: e.message || 'Failed to parse project file' };
  }
});

// Read project file
ipcMain.handle('project:read', async (_e, projectPath: string) => {
  try {
    const content = await fs.readFile(projectPath, 'utf-8');
    const toml = await import('toml');
    const parsed = toml.parse(content);
    const rootDir = join(projectPath, '..');
    
    // Update current project tracker for MCP and compilation
    if (parsed.project?.entry) {
      const entryFile = join(rootDir, parsed.project.entry);
      setCurrentProject({ entryFile, rootDir });
      console.log('[PROJECT] ✓ Loaded project:', { entryFile, rootDir });
    }
    
    return {
      path: projectPath,
      config: parsed,
      rootDir
    };
  } catch (e: any) {
    return { error: e.message || 'Failed to read project file' };
  }
});

// Create new project
ipcMain.handle('project:create', async (_e, args: { name: string; location?: string }) => {
  try {
    let targetDir: string;
    
    if (args.location) {
      targetDir = args.location;
    } else {
      // Ask user for location
      const result = await dialog.showOpenDialog(mainWindow!, {
        title: 'Select Project Location',
        properties: ['openDirectory', 'createDirectory']
      });
      if (result.canceled || result.filePaths.length === 0) {
        return { canceled: true };
      }
      targetDir = result.filePaths[0];
    }
    
    const projectDir = join(targetDir, args.name);
    const srcDir = join(projectDir, 'src');
    const assetsDir = join(projectDir, 'assets');
    const buildDir = join(projectDir, 'build');
    
    // Create directories
    await fs.mkdir(srcDir, { recursive: true });
    await fs.mkdir(join(assetsDir, 'vectors'), { recursive: true });     // Vector graphics (.vec)
    await fs.mkdir(join(assetsDir, 'animations'), { recursive: true });  // Animated vector sequences
    await fs.mkdir(join(assetsDir, 'music'), { recursive: true });       // Music data
    await fs.mkdir(join(assetsDir, 'sfx'), { recursive: true });         // Sound effects
    await fs.mkdir(join(assetsDir, 'voices'), { recursive: true });      // Voice samples (AtariVox)
    await fs.mkdir(buildDir, { recursive: true });
    
    // Create project file (TOML)
    const projectContent = `[project]
name = "${args.name}"
version = "0.1.0"
entry = "src/main.vpy"

[build]
output = "build/${args.name}.bin"
optimization = 2
debug_symbols = true

[sources]
vpy = ["src/**/*.vpy"]

[resources]
vectors = ["assets/vectors/*.vec"]
animations = ["assets/animations/*.anim"]
music = ["assets/music/*.mus"]
sfx = ["assets/sfx/*.sfx"]
voices = ["assets/voices/*.vox"]
`;
    const projectFile = join(projectDir, `${args.name}.vpyproj`);
    await fs.writeFile(projectFile, projectContent, 'utf-8');
    
    // Create main.vpy with valid VPy syntax
    const mainContent = `# ${args.name} - Main entry point
# VPy game for Vectrex

META TITLE = "${args.name}"

def main():
    # Called once at startup
    Set_Intensity(127)

def loop():
    # Game loop - called every frame
    Wait_Recal()
    
    # Draw something to show it works
    Move(0, 0)
    Draw_To(50, 50)
    Draw_To(-50, 50)
    Draw_To(-50, -50)
    Draw_To(50, -50)
    Draw_To(50, 50)
`;
    await fs.writeFile(join(srcDir, 'main.vpy'), mainContent, 'utf-8');
    
    // Create .gitignore
    const gitignore = `# Build artifacts
/build/
*.bin
*.o

# IDE
.vscode/
*.swp
*~
`;
    await fs.writeFile(join(projectDir, '.gitignore'), gitignore, 'utf-8');
    
    return {
      ok: true,
      projectFile,
      projectDir,
      name: args.name
    };
  } catch (e: any) {
    return { error: e.message || 'Failed to create project' };
  }
});

// Find project file in directory or parents
ipcMain.handle('project:find', async (_e, startDir: string) => {
  let current = startDir;
  const maxDepth = 10; // Prevent infinite loop
  
  for (let i = 0; i < maxDepth; i++) {
    try {
      const entries = await fs.readdir(current, { withFileTypes: true });
      for (const entry of entries) {
        if (entry.isFile() && entry.name.endsWith('.vpyproj')) {
          return { path: join(current, entry.name) };
        }
      }
    } catch {
      // Directory not readable, stop
      break;
    }
    
    const parent = join(current, '..');
    if (parent === current) break; // Reached root
    current = parent;
  }
  
  return { path: null };
});

// File watcher system
const watchers = new Map<string, ReturnType<typeof watch>>();
const recentChanges = new Map<string, { timestamp: number; type: string }>(); // Debounce duplicate events

ipcMain.handle('file:watchDirectory', async (_e, dirPath: string) => {
  try {
    if (watchers.has(dirPath)) {
      // Already watching this directory
      return { ok: true };
    }

    const watcher = watch(dirPath, { recursive: true }, (eventType, filename) => {
      if (!filename) return;
      
      const fullPath = join(dirPath, filename);
      
      // Skip temporary files, hidden files, and generated build files
      if (filename.startsWith('.') || filename.includes('~') || filename.endsWith('.tmp')) {
        return;
      }
      
      // Skip generated files that trigger recompilation loops
      if (filename.endsWith('.asm') || filename.endsWith('.bin') || filename.endsWith('.pdb') || 
          filename.endsWith('.map') || filename.includes('build/')) {
        console.log(`[FileWatcher] Ignoring generated file: ${filename}`);
        return;
      }
      
      // Debounce: Skip if same file changed within last 500ms
      const now = Date.now();
      const recent = recentChanges.get(fullPath);
      if (recent && (now - recent.timestamp) < 500) {
        console.log(`[FileWatcher] DEBOUNCED (too soon): ${filename}`);
        return;
      }
      
      // Determine if it's a directory by trying to stat it
      let isDir = false;
      try {
        const stat = require('fs').statSync(fullPath);
        isDir = stat.isDirectory();
      } catch {
        // File might have been deleted, assume it's a file
        isDir = false;
      }
      
      let changeType: 'added' | 'removed' | 'changed' = 'changed';
      
      // Try to determine if file was added or removed
      try {
        require('fs').accessSync(fullPath);
        changeType = eventType === 'rename' ? 'added' : 'changed';
      } catch {
        changeType = 'removed';
      }
      
      // Record this change
      recentChanges.set(fullPath, { timestamp: now, type: changeType });
      
      console.log(`[FileWatcher] ${changeType}: ${filename} (dir: ${isDir})`);
      
      // Notify renderer
      mainWindow?.webContents.send('file://changed', {
        type: changeType,
        path: filename,
        isDir
      });
      
      // Cleanup old entries from debounce map (keep only last 100)
      if (recentChanges.size > 100) {
        const sorted = Array.from(recentChanges.entries())
          .sort((a, b) => b[1].timestamp - a[1].timestamp)
          .slice(100);
        for (const [key] of sorted) {
          recentChanges.delete(key);
        }
      }
    });
    
    watchers.set(dirPath, watcher);
    console.log(`[FileWatcher] Started watching: ${dirPath}`);
    return { ok: true };
  } catch (error) {
    console.error(`[FileWatcher] Error watching directory ${dirPath}:`, error);
    return { ok: false, error: `Failed to watch directory: ${error}` };
  }
});

ipcMain.handle('file:unwatchDirectory', async (_e, dirPath: string) => {
  const watcher = watchers.get(dirPath);
  if (watcher) {
    watcher.close();
    watchers.delete(dirPath);
    console.log(`[FileWatcher] Stopped watching: ${dirPath}`);
  }
  return { ok: true };
});

// Clean up watchers when app closes
app.on('before-quit', () => {
  for (const watcher of watchers.values()) {
    watcher.close();
  }
  watchers.clear();
  
  // Close PyPilot database
  closePyPilotDb();
});

// ==================== PyPilot Session Management ====================

// Initialize PyPilot database on app ready
app.whenReady().then(() => {
  initPyPilotDb();
  console.log('[PyPilot] Database initialized');
});

// Create new session
ipcMain.handle('pypilot:createSession', async (_e, projectPath: string, name?: string) => {
  try {
    const sessionName = name || `Session ${new Date().toLocaleString()}`;
    const session = createSession(projectPath, sessionName);
    console.log('[PyPilot] Created session:', session.id, 'for project:', projectPath);
    return { success: true, session };
  } catch (error: any) {
    console.error('[PyPilot] Error creating session:', error);
    return { success: false, error: error.message };
  }
});

// Get all sessions for a project
ipcMain.handle('pypilot:getSessions', async (_e, projectPath: string) => {
  try {
    const sessions = getSessions(projectPath);
    return { success: true, sessions };
  } catch (error: any) {
    console.error('[PyPilot] Error getting sessions:', error);
    return { success: false, error: error.message };
  }
});

// Get active session for a project
ipcMain.handle('pypilot:getActiveSession', async (_e, projectPath: string) => {
  try {
    const session = getActiveSession(projectPath);
    return { success: true, session };
  } catch (error: any) {
    console.error('[PyPilot] Error getting active session:', error);
    return { success: false, error: error.message };
  }
});

// Switch to different session
ipcMain.handle('pypilot:switchSession', async (_e, sessionId: number) => {
  try {
    const session = switchSession(sessionId);
    console.log('[PyPilot] Switched to session:', sessionId);
    return { success: true, session };
  } catch (error: any) {
    console.error('[PyPilot] Error switching session:', error);
    return { success: false, error: error.message };
  }
});

// Rename session
ipcMain.handle('pypilot:renameSession', async (_e, sessionId: number, newName: string) => {
  try {
    renameSession(sessionId, newName);
    console.log('[PyPilot] Renamed session:', sessionId, 'to:', newName);
    return { success: true };
  } catch (error: any) {
    console.error('[PyPilot] Error renaming session:', error);
    return { success: false, error: error.message };
  }
});

// Delete session
ipcMain.handle('pypilot:deleteSession', async (_e, sessionId: number) => {
  try {
    deleteSession(sessionId);
    console.log('[PyPilot] Deleted session:', sessionId);
    return { success: true };
  } catch (error: any) {
    console.error('[PyPilot] Error deleting session:', error);
    return { success: false, error: error.message };
  }
});

// Save message to session
ipcMain.handle('pypilot:saveMessage', async (_e, sessionId: number, role: string, content: string, metadata?: any) => {
  try {
    const message = saveMessage(sessionId, role as 'user' | 'assistant' | 'system', content, metadata);
    return { success: true, message };
  } catch (error: any) {
    console.error('[PyPilot] Error saving message:', error);
    return { success: false, error: error.message };
  }
});

// Get all messages for session
ipcMain.handle('pypilot:getMessages', async (_e, sessionId: number) => {
  try {
    const messages = getMessages(sessionId);
    return { success: true, messages };
  } catch (error: any) {
    console.error('[PyPilot] Error getting messages:', error);
    return { success: false, error: error.message };
  }
});

// Clear all messages from session
ipcMain.handle('pypilot:clearMessages', async (_e, sessionId: number) => {
  try {
    clearMessages(sessionId);
    console.log('[PyPilot] Cleared messages for session:', sessionId);
    return { success: true };
  } catch (error: any) {
    console.error('[PyPilot] Error clearing messages:', error);
    return { success: false, error: error.message };
  }
});

// Get message count for session
ipcMain.handle('pypilot:getMessageCount', async (_e, sessionId: number) => {
  try {
    const count = getMessageCount(sessionId);
    return { success: true, count };
  } catch (error: any) {
    console.error('[PyPilot] Error getting message count:', error);
    return { success: false, error: error.message };
  }
});

// ============================================
// Breakpoints (Debug Persistence)
// ============================================

// Add breakpoint
ipcMain.handle('breakpoints:add', async (_e, projectPath: string, fileUri: string, lineNumber: number) => {
  try {
    addBreakpoint(projectPath, fileUri, lineNumber);
    return { success: true };
  } catch (error: any) {
    console.error('[Breakpoints] Error adding breakpoint:', error);
    return { success: false, error: error.message };
  }
});

// Remove breakpoint
ipcMain.handle('breakpoints:remove', async (_e, projectPath: string, fileUri: string, lineNumber: number) => {
  try {
    removeBreakpoint(projectPath, fileUri, lineNumber);
    return { success: true };
  } catch (error: any) {
    console.error('[Breakpoints] Error removing breakpoint:', error);
    return { success: false, error: error.message };
  }
});

// Get all breakpoints for project
ipcMain.handle('breakpoints:getAll', async (_e, projectPath: string) => {
  try {
    const breakpoints = getBreakpoints(projectPath);
    return { success: true, breakpoints };
  } catch (error: any) {
    console.error('[Breakpoints] Error getting breakpoints:', error);
    return { success: false, error: error.message };
  }
});

// Get breakpoints for specific file
ipcMain.handle('breakpoints:getFile', async (_e, projectPath: string, fileUri: string) => {
  try {
    const lines = getFileBreakpoints(projectPath, fileUri);
    return { success: true, lines };
  } catch (error: any) {
    console.error('[Breakpoints] Error getting file breakpoints:', error);
    return { success: false, error: error.message };
  }
});

// Clear all breakpoints for project
ipcMain.handle('breakpoints:clear', async (_e, projectPath: string) => {
  try {
    clearBreakpoints(projectPath);
    return { success: true };
  } catch (error: any) {
    console.error('[Breakpoints] Error clearing breakpoints:', error);
    return { success: false, error: error.message };
  }
});

// ============================================
// Debug Symbols (PDB)
// ============================================

// Load existing PDB file for a project
ipcMain.handle('debug:loadPdb', async (_e, sourcePath: string) => {
  try {
    const pdbPath = sourcePath.replace(/\.vpy$/, '.pdb');
    const pdbExists = await fs.access(pdbPath).then(() => true).catch(() => false);
    
    if (!pdbExists) {
      return { success: false, error: 'PDB file not found' };
    }
    
    const pdbContent = await fs.readFile(pdbPath, 'utf-8');
    const pdbData = JSON.parse(pdbContent);
    console.log('[Debug] Loaded PDB:', pdbPath);
    return { success: true, pdbData };
  } catch (error: any) {
    console.error('[Debug] Error loading PDB:', error);
    return { success: false, error: error.message };
  }
});

// ============================================
// Git Operations (Version Control)
// ============================================

interface GitChange {
  path: string;
  status: 'M' | 'A' | 'D' | '?'; // Modified, Added, Deleted, Untracked
  staged: boolean;
}

ipcMain.handle('git:status', async (_e, projectDir: string) => {
  try {
    if (!projectDir) {
      return { ok: false, error: 'No project directory provided' };
    }

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Get git status
    const status = await git.status();
    
    if (!status) {
      return { ok: false, error: 'Failed to get git status' };
    }

    const changes: GitChange[] = [];

    // Map git status to our format
    // Staged files (in index)
    for (const file of status.staged) {
      changes.push({
        path: file,
        status: 'M', // Could be M, A, D depending on what git reports
        staged: true
      });
    }

    // Modified files (unstaged)
    for (const file of status.modified) {
      changes.push({
        path: file,
        status: 'M',
        staged: false
      });
    }

    // Created files (not staged)
    for (const file of status.created) {
      changes.push({
        path: file,
        status: 'A',
        staged: false
      });
    }

    // Deleted files (unstaged)
    for (const file of status.deleted) {
      changes.push({
        path: file,
        status: 'D',
        staged: false
      });
    }

    // Untracked files (use 'not_added' if 'untracked' doesn't exist)
    const untrackeds = (status as any).untracked || (status as any).not_added || [];
    for (const file of untrackeds) {
      changes.push({
        path: file,
        status: '?',
        staged: false
      });
    }

    return { ok: true, files: changes };
  } catch (error: any) {
    console.error('[GIT:status]', error);
    return { ok: false, error: error.message || 'Git status failed' };
  }
});

ipcMain.handle('git:stage', async (_e, args: { projectDir: string; filePath: string }) => {
  try {
    const { projectDir, filePath } = args;
    
    if (!projectDir || !filePath) {
      return { ok: false, error: 'Missing projectDir or filePath' };
    }

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    await git.add(filePath);
    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:stage]', error);
    return { ok: false, error: error.message || 'Failed to stage file' };
  }
});

ipcMain.handle('git:unstage', async (_e, args: { projectDir: string; filePath: string }) => {
  try {
    const { projectDir, filePath } = args;
    
    if (!projectDir || !filePath) {
      return { ok: false, error: 'Missing projectDir or filePath' };
    }

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    await git.reset([filePath]);
    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:unstage]', error);
    return { ok: false, error: error.message || 'Failed to unstage file' };
  }
});

ipcMain.handle('git:commit', async (_e, args: { projectDir: string; message: string }) => {
  try {
    const { projectDir, message } = args;
    
    if (!projectDir || !message) {
      return { ok: false, error: 'Missing projectDir or message' };
    }

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Check if there are staged changes
    const status = await git.status();
    if (!status || status.staged.length === 0) {
      return { ok: false, error: 'No staged changes to commit' };
    }

    // Commit
    const result = await git.commit(message);
    return { ok: true, commit: result };
  } catch (error: any) {
    console.error('[GIT:commit]', error);
    return { ok: false, error: error.message || 'Failed to commit' };
  }
});

ipcMain.handle('git:diff', async (_e, args: { projectDir: string; filePath?: string; staged?: boolean }) => {
  try {
    const { projectDir, filePath, staged } = args;
    
    if (!projectDir) {
      return { ok: false, error: 'Missing projectDir' };
    }

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    let diffOutput: string;
    
    if (filePath) {
      // Get diff for specific file
      const options = staged ? ['--cached'] : [];
      diffOutput = await git.diff([...options, filePath]);
    } else {
      // Get diff for all files
      const options = staged ? ['--cached'] : [];
      diffOutput = await git.diff(options);
    }

    return { ok: true, diff: diffOutput };
  } catch (error: any) {
    console.error('[GIT:diff]', error);
    return { ok: false, error: error.message || 'Failed to get diff' };
  }
});

ipcMain.handle('git:branches', async (_e, projectDir: string) => {
  try {
    if (!projectDir) {
      return { ok: false, error: 'No project directory provided' };
    }

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Get current branch
    const currentBranch = await git.revparse(['--abbrev-ref', 'HEAD']);
    
    // Get all branches (local and remote)
    const branchResult = await git.branch(['-a']);
    
    const branches = branchResult.all.map(branch => ({
      name: branch,
      current: branch === currentBranch.trim(),
      isRemote: branch.includes('remotes/')
    }));

    return { 
      ok: true, 
      current: currentBranch.trim(),
      branches 
    };
  } catch (error: any) {
    console.error('[GIT:branches]', error);
    return { ok: false, error: error.message || 'Failed to get branches' };
  }
});

ipcMain.handle('git:checkout', async (_e, args: { projectDir: string; branch: string }) => {
  try {
    const { projectDir, branch } = args;
    
    if (!projectDir || !branch) {
      return { ok: false, error: 'Missing projectDir or branch' };
    }

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Check for uncommitted changes
    const status = await git.status();
    if (status && (status.modified.length > 0 || status.created.length > 0 || status.deleted.length > 0)) {
      return { 
        ok: false, 
        error: 'Cannot checkout: you have uncommitted changes. Please commit or stash them first.' 
      };
    }

    // Checkout branch
    await git.checkout(branch);
    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:checkout]', error);
    return { ok: false, error: error.message || 'Failed to checkout branch' };
  }
});

ipcMain.handle('git:discard', async (_e, args: { projectDir: string; filePath: string }) => {
  try {
    const { projectDir, filePath } = args;
    
    if (!projectDir || !filePath) {
      return { ok: false, error: 'Missing projectDir or filePath' };
    }

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Discard changes for specific file
    await git.checkout([filePath]);
    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:discard]', error);
    return { ok: false, error: error.message || 'Failed to discard changes' };
  }
});

ipcMain.handle('git:log', async (_e, args: { projectDir: string; limit?: number }) => {
  try {
    const { projectDir, limit = 50 } = args || { projectDir: '' };
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);
    const log = await git.log({ maxCount: limit });

    const commits = log.all.map((commit: any) => ({
      hash: commit.hash?.substring(0, 7) || '',
      fullHash: commit.hash || '',
      message: commit.message || '',
      author: commit.author_name || 'Unknown',
      email: commit.author_email || '',
      date: commit.author_date || '',
      body: commit.body || '',
    }));

    return { ok: true, commits };
  } catch (error: any) {
    console.error('[GIT:log]', error);
    return { ok: false, error: error.message || 'Failed to get commit log' };
  }
});

ipcMain.handle('git:push', async (_e, args: { projectDir: string; remote?: string; branch?: string }) => {
  try {
    const { projectDir, remote = 'origin', branch = 'HEAD' } = args || { projectDir: '' };
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);
    await git.push(remote, branch);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:push]', error);
    return { ok: false, error: error.message || 'Failed to push changes' };
  }
});

ipcMain.handle('git:pull', async (_e, args: { projectDir: string; remote?: string; branch?: string }) => {
  try {
    const { projectDir, remote = 'origin', branch = 'HEAD' } = args || { projectDir: '' };
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);
    await git.pull(remote, branch);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:pull]', error);
    return { ok: false, error: error.message || 'Failed to pull changes' };
  }
});

ipcMain.handle('git:createBranch', async (_e, args: { projectDir: string; branch: string; fromBranch?: string }) => {
  try {
    const { projectDir, branch, fromBranch } = args || { projectDir: '', branch: '' };
    if (!projectDir || !branch) return { ok: false, error: 'Missing parameters' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);
    
    // If fromBranch is specified, check it out first
    if (fromBranch) {
      await git.checkout(fromBranch);
    }
    
    // Create new branch
    await git.checkoutLocalBranch(branch);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:createBranch]', error);
    return { ok: false, error: error.message || 'Failed to create branch' };
  }
});

ipcMain.handle('git:deleteBranch', async (_e, args: { projectDir: string; branch: string; force?: boolean }) => {
  try {
    const { projectDir, branch, force } = args || { projectDir: '', branch: '' };
    if (!projectDir || !branch) return { ok: false, error: 'Missing required parameters' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Delete branch (local)
    const deleteOptions = force ? ['-D'] : ['-d'];
    await git.raw(['branch', ...deleteOptions, branch]);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:deleteBranch]', error);
    return { ok: false, error: error.message || 'Failed to delete branch' };
  }
});

ipcMain.handle('git:syncStatus', async (_e, args: { projectDir: string }) => {
  try {
    const { projectDir } = args || { projectDir: '' };
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Get current branch - use raw command instead of revparse
    const currentBranch = (await git.raw('rev-parse', '--abbrev-ref', 'HEAD')).trim();
    const branch = currentBranch;

    if (branch === 'HEAD') {
      // Detached HEAD state
      return { ok: true, aheadCount: 0, behindCount: 0, branch: 'HEAD (detached)', hasRemote: false };
    }

    try {
      // Get tracking branch
      const trackingBranch = await git.raw(['rev-parse', '--abbrev-ref', `${branch}@{u}`]);
      const remote = trackingBranch.trim();

      if (!remote || remote === `${branch}@{u}`) {
        // No tracking branch set up
        return { ok: true, aheadCount: 0, behindCount: 0, branch, hasRemote: false };
      }

      // Get counts using git rev-list
      const [aheadOutput, behindOutput] = await Promise.all([
        git.raw(['rev-list', '--count', `${remote}..HEAD`]),
        git.raw(['rev-list', '--count', `HEAD..${remote}`])
      ]);

      const aheadCount = parseInt(aheadOutput.trim(), 10) || 0;
      const behindCount = parseInt(behindOutput.trim(), 10) || 0;

      return { ok: true, aheadCount, behindCount, branch, hasRemote: true };
    } catch (trackingError) {
      // No tracking branch - still valid state
      return { ok: true, aheadCount: 0, behindCount: 0, branch, hasRemote: false };
    }
  } catch (error: any) {
    console.error('[GIT:syncStatus]', error);
    return { ok: false, error: error.message || 'Failed to get sync status' };
  }
});

ipcMain.handle('git:searchCommits', async (_e, args: { projectDir: string; query: string; limit?: number }) => {
  try {
    const { projectDir, query, limit = 100 } = args || { projectDir: '', query: '' };
    if (!projectDir) return { ok: false, error: 'No project directory' };
    if (!query) return { ok: true, commits: [] };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Use raw command to search commits
    const rawOutput = await git.raw([
      'log',
      `--max-count=${limit}`,
      '--format=%H:%an:%ae:%ai:%s'
    ]);

    // Parse output
    const commits: Array<{hash: string; message: string; author: string; date: string; shortHash: string}> = [];
    
    rawOutput.split('\n').forEach(line => {
      if (!line.trim()) return;
      
      const parts = line.split(':');
      if (parts.length < 5) return;
      
      const [hash, author, email, date, ...msgParts] = parts;
      const message = msgParts.join(':');
      
      const searchableText = `${message} ${author} ${email}`.toLowerCase();
      if (searchableText.includes(query.toLowerCase())) {
        commits.push({
          hash: hash.trim(),
          message: message.trim(),
          author: author.trim(),
          date: date.trim(),
          shortHash: hash.substring(0, 7)
        });
      }
    });

    return { ok: true, commits: commits.slice(0, limit) };
  } catch (error: any) {
    console.error('[GIT:searchCommits]', error);
    return { ok: false, error: error.message || 'Failed to search commits' };
  }
});

ipcMain.handle('git:checkBranchProtection', async (_e, args: { projectDir: string; branch: string }) => {
  try {
    const { projectDir, branch } = args || { projectDir: '', branch: '' };
    if (!projectDir || !branch) return { ok: false, error: 'Missing parameters' };

    // Check if branch is a protected branch (common patterns: master, main)
    const protectedBranches = ['master', 'main', 'develop', 'production'];
    const isProtected = protectedBranches.includes(branch.toLowerCase());

    // Additional check: look for branch protection rules in git config if they exist
    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Try to get branch-specific config
    let hasPushRules = false;
    try {
      const config = await git.getConfig(`branch.${branch}.protection`);
      hasPushRules = config?.value === 'true';
    } catch (e) {
      // Config key doesn't exist, that's fine
    }

    return {
      ok: true,
      isProtected: isProtected || hasPushRules,
      branch,
      reason: isProtected ? `${branch} is a protected branch` : undefined
    };
  } catch (error: any) {
    console.error('[GIT:checkBranchProtection]', error);
    return { ok: false, error: error.message || 'Failed to check branch protection' };
  }
});

ipcMain.handle('git:fileHistory', async (_e, args: { projectDir: string; filePath: string; limit?: number; offset?: number }) => {
  try {
    const { projectDir, filePath, limit = 20, offset = 0 } = args || { projectDir: '', filePath: '' };
    if (!projectDir || !filePath) return { ok: false, error: 'Missing parameters' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Get log for specific file with pagination
    const rawOutput = await git.raw([
      'log',
      `--max-count=${limit + offset}`,
      '--format=%H:%an:%ae:%ai:%s:%b',
      '--',
      filePath
    ]);

    // Parse output and apply pagination
    const commits: Array<{hash: string; shortHash: string; message: string; author: string; date: string; email: string; body: string}> = [];
    
    const lines = rawOutput.split('\n');
    let currentCommit: any = null;
    let lineCount = 0;
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (!line.trim()) continue;
      
      // Check if this is a commit header (contains multiple colons with hash format)
      const parts = line.split(':');
      if (parts[0].length === 40) {  // SHA1 hash is 40 chars
        lineCount++;
        if (lineCount <= offset) continue;  // Skip offset entries
        if (lineCount > offset + limit) break;  // Stop after limit
        
        const [hash, author, email, date, message] = parts;
        commits.push({
          hash: hash.trim(),
          shortHash: hash.substring(0, 7),
          message: (message || '').trim(),
          author: author.trim(),
          date: date.trim(),
          email: email.trim(),
          body: ''
        });
      }
    }

    return { ok: true, commits, filePath };
  } catch (error: any) {
    console.error('[GIT:fileHistory]', error);
    return { ok: false, error: error.message || 'Failed to get file history' };
  }
});

ipcMain.handle('git:getConfig', async (_e, args: { projectDir: string }) => {
  try {
    const { projectDir } = args || { projectDir: '' };
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Get user config
    const userNameResult = await git.getConfig('user.name');
    const userEmailResult = await git.getConfig('user.email');

    const userName = userNameResult?.value || '';
    const userEmail = userEmailResult?.value || '';

    return {
      ok: true,
      config: {
        userName,
        userEmail
      }
    };
  } catch (error: any) {
    console.error('[GIT:getConfig]', error);
    return { ok: false, error: error.message || 'Failed to get config' };
  }
});

ipcMain.handle('git:setConfig', async (_e, args: { projectDir: string; key: string; value: string; global?: boolean }) => {
  try {
    const { projectDir, key, value, global = false } = args || { projectDir: '', key: '', value: '' };
    if (!projectDir || !key || !value) return { ok: false, error: 'Missing parameters' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    const configOptions = global ? ['--global'] : [];
    await git.raw(['config', ...configOptions, key, value]);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:setConfig]', error);
    return { ok: false, error: error.message || 'Failed to set config' };
  }
});

ipcMain.handle('git:stash', async (_e, args: { projectDir: string; message?: string }) => {
  try {
    const { projectDir, message } = args || { projectDir: '' };
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    const stashMessage = message ? `stash save "${message}"` : 'stash';
    await git.stash([stashMessage.split(' ')[0], ...(message ? ['save', message] : [])]);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:stash]', error);
    return { ok: false, error: error.message || 'Failed to stash changes' };
  }
});

ipcMain.handle('git:stashList', async (_e, projectDir: string) => {
  try {
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    const stashes = await git.stashList();
    const formattedStashes = stashes.all.map((stash: any, idx: number) => ({
      index: idx,
      hash: stash.hash?.substring(0, 7) || '',
      fullHash: stash.hash || '',
      message: stash.message || `Stash ${idx}`,
      date: stash.date || new Date().toISOString(),
    }));

    return { ok: true, stashes: formattedStashes };
  } catch (error: any) {
    console.error('[GIT:stashList]', error);
    return { ok: false, error: error.message || 'Failed to get stash list', stashes: [] };
  }
});

ipcMain.handle('git:stashPop', async (_e, args: { projectDir: string; index?: number }) => {
  try {
    const { projectDir, index = 0 } = args || { projectDir: '' };
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    await git.stash(['pop', `stash@{${index}}`]);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:stashPop]', error);
    return { ok: false, error: error.message || 'Failed to pop stash' };
  }
});

// Assemble a Vectrex 6809 raw binary from an .asm file via PowerShell lwasm wrapper
// args: { asmPath: string; outPath?: string; extra?: string[] }
ipcMain.handle('emu:assemble', async (_e, args: { asmPath: string; outPath?: string; extra?: string[] }) => {
  const { asmPath, outPath, extra } = args || {} as any;
  if (!asmPath) return { error: 'no_asm_path' };
  // Normalize possible file:/// URI
  let fsPath = asmPath;
  if (/^file:\/\//i.test(fsPath)) {
    try { const u = new URL(fsPath); fsPath = u.pathname; if (process.platform==='win32' && /^\/[A-Za-z]:/.test(fsPath)) fsPath = fsPath.slice(1); } catch {}
  }
  try { if (!existsSync(fsPath)) return { error: 'asm_not_found', path: fsPath }; } catch { return { error: 'asm_not_found', path: fsPath }; }
  const outBin = outPath || fsPath.replace(/\.[^.]+$/, '.bin');
  const script = join(process.cwd(), 'tools', 'lwasm.ps1');
  try { if (!existsSync(script)) return { error: 'script_not_found', script }; } catch { return { error: 'script_not_found', script }; }
  const baseArgs = ['-NoProfile','-ExecutionPolicy','Bypass','-File', script, '--6809','--format=raw', `--output=${outBin}`, fsPath];
  if (Array.isArray(extra) && extra.length) baseArgs.push(...extra);
  mainWindow?.webContents.send('run://status', `Assembling ${fsPath} -> ${outBin}`);
  return new Promise((resolve) => {
    const child = spawn('pwsh', baseArgs, { stdio:['ignore','pipe','pipe'] });
    let stdoutBuf=''; let stderrBuf='';
    child.stdout.on('data', (c:Buffer)=>{ const t=c.toString('utf8'); stdoutBuf+=t; mainWindow?.webContents.send('run://stdout', t); });
    child.stderr.on('data', (c:Buffer)=>{ const t=c.toString('utf8'); stderrBuf+=t; mainWindow?.webContents.send('run://stderr', t); });
    child.on('error', (err)=>{ mainWindow?.webContents.send('run://status', `Assembly spawn failed: ${err.message}`); resolve({ error:'spawn_failed', detail: err.message }); });
    child.on('exit', async (code)=>{
      if (code!==0){ mainWindow?.webContents.send('run://status', `Assembly FAILED (exit ${code})`); return resolve({ error:'assemble_failed', code, stdout:stdoutBuf, stderr:stderrBuf }); }
      try {
        const buf = await fs.readFile(outBin);
        const base64 = Buffer.from(buf).toString('base64');
        mainWindow?.webContents.send('run://status', `Assembly OK: ${outBin} (${buf.length} bytes)`);
        resolve({ ok:true, binPath: outBin, size: buf.length, base64, stdout:stdoutBuf, stderr:stderrBuf });
      } catch(e:any){ resolve({ error:'bin_read_failed', detail:e?.message }); }
    });
  });
});

// After window creation call buildMenus
app.whenReady().then(() => {
  const verbose = process.env.VPY_IDE_VERBOSE_LSP === '1';
  if (verbose) console.log('[IDE] app.whenReady');
  
  // Seguridad adicional: anular menú global
  try { Menu.setApplicationMenu(null); } catch {}
  // Inyectar Content-Security-Policy por cabecera (más fuerte que meta) en dev y prod
  const isDev = !!process.env.VITE_DEV_SERVER_URL;
  // CSP simplificado: por ahora permitimos unsafe-inline para desarrollo y producción
  // En el futuro, cuando creemos un paquete de instalación, implementaremos CSP estricto
  const scriptSrc = "script-src 'self' 'unsafe-inline' 'unsafe-eval'";
  const styleSrc = "style-src 'self' 'unsafe-inline'";
  const imgSrc = "img-src 'self' data:";
  const fontSrc = "font-src 'self' data:";
  const connectSrc = isDev ? "connect-src 'self' ws: http: https:" : "connect-src 'self'";
  const workerSrc = "worker-src 'self' blob:"; // para blob workers Monaco
  const csp = [
    "default-src 'self'",
    scriptSrc,
    styleSrc,
    imgSrc,
    fontSrc,
    connectSrc,
    workerSrc,
    "object-src 'none'",
    "base-uri 'self'",
    "frame-ancestors 'none'"
  ].join('; ');
  // Nota para futuros cambios:
  // Si se requiere ejecutar un script inline específico (no recomendado), usar nonce o hash en lugar de reintroducir 'unsafe-inline'.
  // Ejemplo nonce:
  //  1. Generar const nonce = crypto.randomBytes(16).toString('base64');
  //  2. Añadir a CSP: script-src 'self' 'nonce-${nonce}'
  //  3. Inyectar en la etiqueta: <script nonce="${nonce}">...</script>
  // Ejemplo hash (para contenido fijo): calcular SHA256 del contenido y añadir 'sha256-<base64digest>' a script-src.
  // Evitar ampliar connect-src u otras fuentes salvo necesidad clara.
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    const headers = details.responseHeaders || {};
    headers['Content-Security-Policy'] = [csp];
    callback({ cancel: false, responseHeaders: headers });
  });
  if (verbose) console.log('[IDE] CSP applied');
  
  // Register AI proxy handlers
  registerAIProxyHandlers();
  if (verbose) console.log('[IDE] AI Proxy registered');
  
  createWindow();
  // Defer BIOS load slightly until window exists to allow status message.
  setTimeout(()=>{ tryLoadBiosOnce(); }, 500);
});
app.on('render-process-gone', (_e, details) => {
  console.error('[IDE] render process gone', details);
});
app.on('child-process-gone', (_e, details) => {
  console.error('[IDE] child process gone', details);
});

// Revert commit handler
ipcMain.handle('git:revert', async (_e, args: { projectDir: string; commitHash: string }) => {
  try {
    const { projectDir, commitHash } = args;
    if (!projectDir || !commitHash) return { ok: false, error: 'Missing projectDir or commitHash' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    await git.raw(['revert', '--no-edit', commitHash]);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:revert]', error);
    return { ok: false, error: error.message };
  }
});

// List tags
ipcMain.handle('git:tagList', async (_e, args: { projectDir: string }) => {
  try {
    const { projectDir } = args;
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    const tagsOutput = await git.raw(['tag', '-l']);
    const tags = tagsOutput.split('\n').filter(t => t.trim()).map(tag => ({
      name: tag.trim(),
    }));

    return { ok: true, tags };
  } catch (error: any) {
    console.error('[GIT:tagList]', error);
    return { ok: false, error: error.message };
  }
});

// Create tag
ipcMain.handle('git:tag', async (_e, args: { projectDir: string; tagName: string; message?: string }) => {
  try {
    const { projectDir, tagName, message } = args;
    if (!projectDir || !tagName) return { ok: false, error: 'Missing projectDir or tagName' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    if (message) {
      await git.raw(['tag', '-a', tagName, '-m', message]);
    } else {
      await git.raw(['tag', tagName]);
    }

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:tag]', error);
    return { ok: false, error: error.message };
  }
});

// Delete tag
ipcMain.handle('git:deleteTag', async (_e, args: { projectDir: string; tagName: string }) => {
  try {
    const { projectDir, tagName } = args;
    if (!projectDir || !tagName) return { ok: false, error: 'Missing projectDir or tagName' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    await git.raw(['tag', '-d', tagName]);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:deleteTag]', error);
    return { ok: false, error: error.message };
  }
});

// List remotes
ipcMain.handle('git:remoteList', async (_e, args: { projectDir: string }) => {
  try {
    const { projectDir } = args;
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    const remotes = await git.raw(['remote', '-v']);
    const remoteArray = remotes
      .split('\n')
      .filter(line => line.trim())
      .map(line => {
        const parts = line.match(/^(\S+)\s+(\S+)\s+\((\w+)\)$/);
        return {
          name: parts?.[1] || line.split('\t')[0] || line,
          url: parts?.[2] || line.split('\t')[1] || '',
          type: parts?.[3] || 'fetch',
        };
      })
      .filter((v, i, a) => a.findIndex(t => t.name === v.name) === i); // Deduplicate by name

    return { ok: true, remotes: remoteArray };
  } catch (error: any) {
    console.error('[GIT:remoteList]', error);
    return { ok: false, error: error.message };
  }
});

// Add remote
ipcMain.handle('git:addRemote', async (_e, args: { projectDir: string; name: string; url: string }) => {
  try {
    const { projectDir, name, url } = args;
    if (!projectDir || !name || !url) return { ok: false, error: 'Missing projectDir, name, or url' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    await git.raw(['remote', 'add', name, url]);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:addRemote]', error);
    return { ok: false, error: error.message };
  }
});

// Remove remote
ipcMain.handle('git:removeRemote', async (_e, args: { projectDir: string; name: string }) => {
  try {
    const { projectDir, name } = args;
    if (!projectDir || !name) return { ok: false, error: 'Missing projectDir or name' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    await git.raw(['remote', 'remove', name]);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:removeRemote]', error);
    return { ok: false, error: error.message };
  }
});

// Check for merge conflicts
ipcMain.handle('git:checkConflicts', async (_e, args: { projectDir: string }) => {
  try {
    const { projectDir } = args;
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Get status to check for conflicts
    const status = await git.status();
    const conflicted = status.conflicted || [];

    return { ok: true, hasConflicts: conflicted.length > 0, conflicts: conflicted };
  } catch (error: any) {
    console.error('[GIT:checkConflicts]', error);
    return { ok: false, error: error.message };
  }
});

// Get conflict details for a file
ipcMain.handle('git:getConflictDetails', async (_e, args: { projectDir: string; filePath: string }) => {
  try {
    const { projectDir, filePath } = args;
    if (!projectDir || !filePath) return { ok: false, error: 'Missing projectDir or filePath' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Read file content to show conflict markers
    const fs = require('fs').promises;
    const fullPath = require('path').join(projectDir, filePath);
    const content = await fs.readFile(fullPath, 'utf-8');

    return { ok: true, content };
  } catch (error: any) {
    console.error('[GIT:getConflictDetails]', error);
    return { ok: false, error: error.message };
  }
});

// Mark conflict as resolved
ipcMain.handle('git:markResolved', async (_e, args: { projectDir: string; filePath: string }) => {
  try {
    const { projectDir, filePath } = args;
    if (!projectDir || !filePath) return { ok: false, error: 'Missing projectDir or filePath' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Stage the resolved file
    await git.add(filePath);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:markResolved]', error);
    return { ok: false, error: error.message };
  }
});

// Complete merge after conflicts resolved
ipcMain.handle('git:completeMerge', async (_e, args: { projectDir: string; message?: string }) => {
  try {
    const { projectDir, message } = args;
    if (!projectDir) return { ok: false, error: 'No project directory' };

    const simpleGit = (await import('simple-git')).default;
    const git = simpleGit(projectDir);

    // Commit the merge
    const mergeMessage = message || 'Merge resolved';
    await git.commit(mergeMessage);

    return { ok: true };
  } catch (error: any) {
    console.error('[GIT:completeMerge]', error);
    return { ok: false, error: error.message };
  }
});

process.on('uncaughtException', (err) => {
  console.error('[IDE] uncaughtException', err);
});
process.on('unhandledRejection', (reason) => {
  console.error('[IDE] unhandledRejection', reason);
});

// ─── EPROM Programmer (minipro CLI wrapper) ───────────────────────────────────

function runMinipro(args: string[]): Promise<{ ok: boolean; stdout: string; stderr: string; error?: string }> {
  return new Promise((resolve) => {
    const proc = spawn('minipro', args, { timeout: 120000 });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d: Buffer) => { stdout += d.toString(); });
    proc.stderr.on('data', (d: Buffer) => { stderr += d.toString(); });
    proc.on('error', (err: Error) => {
      resolve({ ok: false, stdout, stderr, error: err.message });
    });
    proc.on('close', (code: number | null) => {
      if (code === 0) {
        resolve({ ok: true, stdout, stderr });
      } else {
        resolve({ ok: false, stdout, stderr, error: `minipro exited with code ${code}` });
      }
    });
  });
}

ipcMain.handle('eprom:detect', async () => {
  try {
    const result = await runMinipro(['--version']);
    if (result.ok) {
      // Extract version from output: "minipro version 0.6  ..."
      const ver = (result.stdout + result.stderr).trim().split('\n')[0];
      return { ok: true, version: ver };
    }
    return { ok: false, error: result.error || 'minipro not found in PATH' };
  } catch (e: any) {
    return { ok: false, error: e?.message || 'Failed to detect minipro' };
  }
});

ipcMain.handle('eprom:write', async (_e, args: { binPath: string; chip: string; programmer: string }) => {
  const { binPath, chip } = args;
  if (!binPath || !existsSync(binPath)) {
    return { ok: false, error: `File not found: ${binPath}`, stdout: '', stderr: '' };
  }
  // minipro -p <chip> -w <file>
  return runMinipro(['-p', chip, '-w', binPath]);
});

ipcMain.handle('eprom:verify', async (_e, args: { binPath: string; chip: string; programmer: string }) => {
  const { binPath, chip } = args;
  if (!binPath || !existsSync(binPath)) {
    return { ok: false, error: `File not found: ${binPath}`, stdout: '', stderr: '' };
  }
  // minipro -p <chip> -m <file> (verify/check)
  return runMinipro(['-p', chip, '-m', binPath]);
});

ipcMain.handle('eprom:blankCheck', async (_e, args: { chip: string; programmer: string }) => {
  const { chip } = args;
  // minipro -p <chip> --blank_check
  return runMinipro(['-p', chip, '--blank_check']);
});

ipcMain.handle('eprom:platform', async () => {
  return { platform: process.platform }; // 'darwin' | 'linux' | 'win32'
});

ipcMain.handle('eprom:install', async (_e, _args: { platform?: string } = {}) => {
  const plat = process.platform;
  
  // Helper to run a shell command and stream output
  function runShell(cmd: string, args: string[]): Promise<{ ok: boolean; stdout: string; stderr: string; error?: string }> {
    return new Promise((resolve) => {
      const proc = spawn(cmd, args, { timeout: 300000, shell: true });
      let stdout = '';
      let stderr = '';
      proc.stdout.on('data', (d: Buffer) => {
        const chunk = d.toString();
        stdout += chunk;
        // Send progress to renderer
        if (mainWindow?.webContents) {
          mainWindow.webContents.send('eprom://installProgress', chunk);
        }
      });
      proc.stderr.on('data', (d: Buffer) => {
        const chunk = d.toString();
        stderr += chunk;
        if (mainWindow?.webContents) {
          mainWindow.webContents.send('eprom://installProgress', chunk);
        }
      });
      proc.on('error', (err: Error) => {
        resolve({ ok: false, stdout, stderr, error: err.message });
      });
      proc.on('close', (code: number | null) => {
        resolve(code === 0 ? { ok: true, stdout, stderr } : { ok: false, stdout, stderr, error: `Process exited with code ${code}` });
      });
    });
  }

  try {
    if (plat === 'darwin') {
      // macOS: use Homebrew
      return await runShell('brew', ['install', 'minipro']);
    } else if (plat === 'linux') {
      // Linux: try apt first, fallback to building from source
      const aptResult = await runShell('sudo', ['apt-get', 'install', '-y', 'minipro']);
      if (aptResult.ok) return aptResult;
      // If apt fails, try snap or provide instructions
      return { ok: false, stdout: aptResult.stdout, stderr: aptResult.stderr, error: 'apt install failed. Try building from source: https://gitlab.com/DavidGriffith/minipro' };
    } else if (plat === 'win32') {
      // Windows: try winget, choco, or scoop
      const wingetResult = await runShell('winget', ['install', 'minipro']);
      if (wingetResult.ok) return wingetResult;
      const chocoResult = await runShell('choco', ['install', 'minipro', '-y']);
      if (chocoResult.ok) return chocoResult;
      return { ok: false, stdout: '', stderr: '', error: 'Automatic install not available on Windows. Download from https://gitlab.com/DavidGriffith/minipro/-/releases' };
    }
    return { ok: false, stdout: '', stderr: '', error: `Unsupported platform: ${plat}` };
  } catch (e: any) {
    return { ok: false, stdout: '', stderr: '', error: e?.message || 'Install failed' };
  }
});

// ─── End EPROM ────────────────────────────────────────────────────────────────

app.on('window-all-closed', () => {
  console.warn('[IDE] all windows closed');
  if (process.platform !== 'darwin') app.quit();
});
app.on('browser-window-created', (_e, win) => {
  console.log('[IDE] browser-window-created id=', win.id);
  win.on('closed', () => console.log('[IDE] window closed id=', win.id));
  win.webContents.on('did-finish-load', () => console.log('[IDE] did-finish-load main window'));
  win.webContents.on('did-fail-load', (_e, errCode, errDesc) => console.error('[IDE] did-fail-load', errCode, errDesc));
  win.webContents.on('render-process-gone', (_e, details) => console.error('[IDE] wc render-process-gone', details));
  win.webContents.on('unresponsive', () => console.error('[IDE] window unresponsive'));
  win.webContents.on('responsive', () => console.log('[IDE] window responsive again'));
});
app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
