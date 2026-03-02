import { contextBridge, ipcRenderer, IpcRendererEvent } from 'electron';

contextBridge.exposeInMainWorld('electronAPI', {
  lspStart: () => ipcRenderer.invoke('lsp_start'),
  lspSend: (payload: string) => ipcRenderer.invoke('lsp_send', payload),
  onLspMessage: (cb: (json: string) => void) => ipcRenderer.on('lsp://message', (_e: IpcRendererEvent, data: string) => cb(data)),
  onLspStdout: (cb: (line: string) => void) => ipcRenderer.on('lsp://stdout', (_e: IpcRendererEvent, data: string) => cb(data)),
  onLspStderr: (cb: (line: string) => void) => ipcRenderer.on('lsp://stderr', (_e: IpcRendererEvent, data: string) => cb(data)),
  onCommand: (cb: (cmd: string, payload?: any) => void) => {
    const handler = (_e: IpcRendererEvent, cmd: string, payload?: any) => cb(cmd, payload);
    ipcRenderer.on('command', handler);
    // Return cleanup function to remove listener
    return () => ipcRenderer.removeListener('command', handler);
  },
  updateRecentProjects: (recents: Array<{name: string; path: string}>) => ipcRenderer.invoke('menu:updateRecentProjects', recents),
  // Legacy emulator IPC removed. All runtime control now via WASM service in renderer.
  emuAssemble: (args: { asmPath: string; outPath?: string; extra?: string[] }) => ipcRenderer.invoke('emu:assemble', args) as Promise<{ ok?: boolean; error?: string; binPath?: string; size?: number; base64?: string; stdout?: string; stderr?: string }>,
  runCompile: (args: { path: string; saveIfDirty?: { content: string; expectedMTime?: number }; autoStart?: boolean; compilerBackend?: 'buildtools' | 'core' }) => ipcRenderer.invoke('run:compile', args) as Promise<{ ok?: boolean; error?: string; binPath?: string; size?: number; stdout?: string; stderr?: string; conflict?: boolean; currentMTime?: number }>,
  onRunStdout: (cb: (chunk: string) => void) => ipcRenderer.on('run://stdout', (_e: IpcRendererEvent, data: string) => cb(data)),
  onRunStderr: (cb: (chunk: string) => void) => ipcRenderer.on('run://stderr', (_e: IpcRendererEvent, data: string) => cb(data)),
  onRunDiagnostics: (cb: (diags: Array<{ file: string; line: number; col: number; message: string }>) => void) => ipcRenderer.on('run://diagnostics', (_e: IpcRendererEvent, diags) => cb(diags)),
  onRunStatus: (cb: (line: string) => void) => ipcRenderer.on('run://status', (_e: IpcRendererEvent, data: string) => cb(data)),
  onEmuLoaded: (cb: (info: { size: number }) => void) => ipcRenderer.on('emu://loaded', (_e: IpcRendererEvent, data) => cb(data)), // kept for backward compatibility (may be unused)
  onCompiledBin: (cb: (payload: { base64: string; size: number; binPath: string }) => void) => ipcRenderer.on('emu://compiledBin', (_e: IpcRendererEvent, data) => cb(data)),
  // setVectorMode legacy removed
  listSources: (args?: { limit?: number }) => ipcRenderer.invoke('list:sources', args) as Promise<{ ok?:boolean; sources?: Array<{ path:string; kind:'vpy'|'asm'; size:number; mtime:number }> }> ,
  // Disassemble a ROM snapshot (base64) using buildtools/vpy_disasm
  disassembleSnapshot: (args: { base64: string; startHex?: string; binPath?: string }) => ipcRenderer.invoke('tools:disassembleSnapshot', args) as Promise<{ ok: boolean; output?: string; error?: string; snapshotPath?: string; dissPath?: string; message?: string; stderr?: string }>,

  // Expose ipcRenderer for generic channel listening
  ipcRenderer: {
    on: (channel: string, callback: (...args: any[]) => void) => {
      const handler = (_e: IpcRendererEvent, ...args: any[]) => callback(...args);
      ipcRenderer.on(channel, handler);
      return handler;
    },
    removeListener: (channel: string, handler: any) => {
      ipcRenderer.removeListener(channel, handler);
    }
  }
});

contextBridge.exposeInMainWorld('files', {
  openFile: () => ipcRenderer.invoke('file:open') as Promise<{ path: string; content: string; mtime: number; size: number; name: string } | { error: string } | null>,
  openFilePath: (path: string) => ipcRenderer.invoke('file:openPath', path) as Promise<{ path: string; content: string; mtime: number; size: number; name: string } | { error: string } | null>,
  saveFile: (args: { path: string; content: string; expectedMTime?: number }) => ipcRenderer.invoke('file:save', args) as Promise<{ path: string; mtime: number; size: number } | { conflict: true; currentMTime: number } | { error: string }>,

  appendFile: (args: { path: string; content: string }) => ipcRenderer.invoke('file:append', args) as Promise<{ ok: boolean; path: string; size?: number } | { error: string }>,

  appendFileBin: (args: { path: string; data: Uint8Array }) => ipcRenderer.invoke('file:appendBin', args) as Promise<{ ok: boolean; path: string; size?: number } | { error: string }>,

  saveFileAs: (args: { suggestedName?: string; content: string }) => ipcRenderer.invoke('file:saveAs', args) as Promise<{ path: string; mtime: number; size: number; name: string } | { canceled: true } | { error: string }>,

  openFolder: () => ipcRenderer.invoke('file:openFolder') as Promise<{ path: string } | null>,
  readDirectory: (path: string) => ipcRenderer.invoke('file:readDirectory', path) as Promise<{ files: Array<{ name: string; path: string; isDir: boolean; children?: any[] }> } | { error: string }>,
  readFile: (path: string) => ipcRenderer.invoke('file:read', path) as Promise<{ path: string; content: string; mtime: number; size: number; name: string } | { error: string }>,
  getFileInfo: (path: string) => ipcRenderer.invoke('file:getInfo', path) as Promise<{ ok: boolean; path: string; mtime: number; size: number; name: string } | { ok: false; error: string }>,
  readFileBin: (path: string) => ipcRenderer.invoke('file:readBin', path) as Promise<{ path: string; base64: string; size: number; name: string } | { error: string }>,
  openBin: () => ipcRenderer.invoke('bin:open') as Promise<{ path: string; base64: string; size: number } | { error: string } | null>,
  deleteFile: (path: string) => ipcRenderer.invoke('file:delete', path) as Promise<{ success: boolean; path: string } | { error: string }>,
  moveFile: (args: { sourcePath: string; targetDir: string }) => ipcRenderer.invoke('file:move', args) as Promise<{ success: boolean; sourcePath: string; targetPath: string } | { error: string; targetPath?: string }>,
  watchDirectory: (path: string) => ipcRenderer.invoke('file:watchDirectory', path) as Promise<{ ok: boolean; error?: string }>,
  unwatchDirectory: (path: string) => ipcRenderer.invoke('file:unwatchDirectory', path) as Promise<{ ok: boolean }>,
  onFileChanged: (cb: (event: { type: 'added' | 'removed' | 'changed'; path: string; isDir: boolean }) => void) => {
    const handler = (_e: IpcRendererEvent, data: any) => cb(data);
    ipcRenderer.on('file://changed', handler);
    // Return cleanup function to remove listener
    return () => ipcRenderer.removeListener('file://changed', handler);
  },
});

contextBridge.exposeInMainWorld('recents', {
  load: () => ipcRenderer.invoke('recents:load') as Promise<Array<{ path: string; lastOpened: number; kind: 'file' | 'folder' }>>,
  write: (list: Array<{ path: string; lastOpened: number; kind: 'file' | 'folder' }>) => ipcRenderer.invoke('recents:write', list) as Promise<{ ok: boolean }>,
});

// Project management API
contextBridge.exposeInMainWorld('project', {
  // Open project file dialog
  open: () => ipcRenderer.invoke('project:open') as Promise<{
    path: string;
    config: any;
    rootDir: string;
  } | { error: string } | null>,
  
  // Read project file directly
  read: (path: string) => ipcRenderer.invoke('project:read', path) as Promise<{
    path: string;
    config: any;
    rootDir: string;
  } | { error: string }>,
  
  // Create new project
  create: (args: { name: string; location?: string }) => ipcRenderer.invoke('project:create', args) as Promise<{
    ok: boolean;
    projectFile: string;
    projectDir: string;
    name: string;
  } | { canceled: true } | { error: string }>,
  
  // Find project file in directory or parents
  find: (startDir: string) => ipcRenderer.invoke('project:find', startDir) as Promise<{ path: string | null }>,
});

// Git operations API
contextBridge.exposeInMainWorld('git', {
  // Get git status (staged/unstaged changes)
  status: (projectDir: string) => ipcRenderer.invoke('git:status', projectDir) as Promise<{
    ok: boolean;
    files?: Array<{ path: string; status: 'M' | 'A' | 'D' | '?'; staged: boolean }>;
    error?: string;
  }>,
  
  // Stage a file
  stage: (args: { projectDir: string; filePath: string }) => ipcRenderer.invoke('git:stage', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Unstage a file
  unstage: (args: { projectDir: string; filePath: string }) => ipcRenderer.invoke('git:unstage', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Create a commit
  commit: (args: { projectDir: string; message: string }) => ipcRenderer.invoke('git:commit', args) as Promise<{
    ok: boolean;
    commit?: any;
    error?: string;
  }>,
  
  // Get file diff
  diff: (args: { projectDir: string; filePath?: string; staged?: boolean }) => ipcRenderer.invoke('git:diff', args) as Promise<{
    ok: boolean;
    diff?: string;
    error?: string;
  }>,
  
  // List branches
  branches: (projectDir: string) => ipcRenderer.invoke('git:branches', projectDir) as Promise<{
    ok: boolean;
    current?: string;
    branches?: Array<{ name: string; current: boolean; isRemote: boolean }>;
    error?: string;
  }>,
  
  // Checkout branch
  checkout: (args: { projectDir: string; branch: string }) => ipcRenderer.invoke('git:checkout', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Discard changes in a file
  discard: (args: { projectDir: string; filePath: string }) => ipcRenderer.invoke('git:discard', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Get commit log
  log: (args: { projectDir: string; limit?: number }) => ipcRenderer.invoke('git:log', args) as Promise<{
    ok: boolean;
    commits?: Array<{
      hash: string;
      fullHash: string;
      message: string;
      author: string;
      email: string;
      date: string;
      body: string;
    }>;
    error?: string;
  }>,
  
  // Push changes to remote
  push: (args: { projectDir: string; remote?: string; branch?: string }) => ipcRenderer.invoke('git:push', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Pull changes from remote
  pull: (args: { projectDir: string; remote?: string; branch?: string }) => ipcRenderer.invoke('git:pull', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Create new branch
  createBranch: (args: { projectDir: string; branch: string; fromBranch?: string }) => ipcRenderer.invoke('git:createBranch', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Delete branch
  deleteBranch: (args: { projectDir: string; branch: string; force?: boolean }) => ipcRenderer.invoke('git:deleteBranch', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Get sync status (ahead/behind remote)
  syncStatus: (args: { projectDir: string }) => ipcRenderer.invoke('git:syncStatus', args) as Promise<{
    ok: boolean;
    aheadCount?: number;
    behindCount?: number;
    branch?: string;
    hasRemote?: boolean;
    error?: string;
  }>,
  
  // Search commits
  searchCommits: (args: { projectDir: string; query: string; limit?: number }) => ipcRenderer.invoke('git:searchCommits', args) as Promise<{
    ok: boolean;
    commits?: Array<{
      hash: string;
      shortHash: string;
      message: string;
      author: string;
      date: string;
    }>;
    error?: string;
  }>,
  
  // Check branch protection
  checkBranchProtection: (args: { projectDir: string; branch: string }) => ipcRenderer.invoke('git:checkBranchProtection', args) as Promise<{
    ok: boolean;
    isProtected?: boolean;
    branch?: string;
    reason?: string;
    error?: string;
  }>,
  
  // Get file history
  fileHistory: (args: { projectDir: string; filePath: string; limit?: number }) => ipcRenderer.invoke('git:fileHistory', args) as Promise<{
    ok: boolean;
    commits?: Array<{
      hash: string;
      shortHash: string;
      message: string;
      author: string;
      date: string;
      email: string;
      body: string;
    }>;
    filePath?: string;
    error?: string;
  }>,
  
  // Get git config
  getConfig: (args: { projectDir: string }) => ipcRenderer.invoke('git:getConfig', args) as Promise<{
    ok: boolean;
    config?: {
      userName: string;
      userEmail: string;
    };
    error?: string;
  }>,
  
  // Set git config
  setConfig: (args: { projectDir: string; key: string; value: string; global?: boolean }) => ipcRenderer.invoke('git:setConfig', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Stash changes
  stash: (args: { projectDir: string; message?: string }) => ipcRenderer.invoke('git:stash', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // List stashes
  stashList: (projectDir: string) => ipcRenderer.invoke('git:stashList', projectDir) as Promise<{
    ok: boolean;
    stashes?: Array<{
      index: number;
      hash: string;
      fullHash: string;
      message: string;
      date: string;
    }>;
    error?: string;
  }>,
  
  // Pop stash
  stashPop: (args: { projectDir: string; index?: number }) => ipcRenderer.invoke('git:stashPop', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Revert commit
  revert: (args: { projectDir: string; commitHash: string }) => ipcRenderer.invoke('git:revert', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // List tags
  tagList: (projectDir: string) => ipcRenderer.invoke('git:tagList', { projectDir }) as Promise<{
    ok: boolean;
    tags?: { name: string }[];
    error?: string;
  }>,
  
  // Create tag
  tag: (args: { projectDir: string; tagName: string; message?: string }) => ipcRenderer.invoke('git:tag', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Delete tag
  deleteTag: (args: { projectDir: string; tagName: string }) => ipcRenderer.invoke('git:deleteTag', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // List remotes
  remoteList: (projectDir: string) => ipcRenderer.invoke('git:remoteList', { projectDir }) as Promise<{
    ok: boolean;
    remotes?: { name: string; url: string; type: string }[];
    error?: string;
  }>,
  
  // Add remote
  addRemote: (args: { projectDir: string; name: string; url: string }) => ipcRenderer.invoke('git:addRemote', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Remove remote
  removeRemote: (args: { projectDir: string; name: string }) => ipcRenderer.invoke('git:removeRemote', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Check for merge conflicts
  checkConflicts: (projectDir: string) => ipcRenderer.invoke('git:checkConflicts', { projectDir }) as Promise<{
    ok: boolean;
    hasConflicts?: boolean;
    conflicts?: string[];
    error?: string;
  }>,
  
  // Get conflict details
  getConflictDetails: (args: { projectDir: string; filePath: string }) => ipcRenderer.invoke('git:getConflictDetails', args) as Promise<{
    ok: boolean;
    content?: string;
    error?: string;
  }>,
  
  // Mark file as resolved
  markResolved: (args: { projectDir: string; filePath: string }) => ipcRenderer.invoke('git:markResolved', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
  
  // Complete merge
  completeMerge: (args: { projectDir: string; message?: string }) => ipcRenderer.invoke('git:completeMerge', args) as Promise<{
    ok: boolean;
    error?: string;
  }>,
});

// MCP Server API for AI agents
contextBridge.exposeInMainWorld('mcp', {
  // Send JSON-RPC request to MCP server
  request: (request: any) => ipcRenderer.invoke('mcp:request', request),
});

// Shell command execution (for Ollama installation)
contextBridge.exposeInMainWorld('electron', {
  runCommand: (command: string) => ipcRenderer.invoke('shell:runCommand', command) as Promise<{
    success: boolean;
    output: string;
    exitCode: number;
  }>,
});

// AI Provider Proxy (for CORS-blocked APIs like Anthropic, DeepSeek)
contextBridge.exposeInMainWorld('aiProxy', {
  request: (request: {
    provider: 'anthropic' | 'deepseek';
    apiKey: string;
    endpoint: string;
    method: string;
    body: any;
    headers?: Record<string, string>;
  }) => ipcRenderer.invoke('ai-proxy-request', request) as Promise<{
    success: boolean;
    data?: any;
    error?: string;
    status?: number;
  }>,
});

// Persistent Storage API (replaces localStorage)
contextBridge.exposeInMainWorld('storage', {
  get: (key: string) => ipcRenderer.invoke('storage:get', key),
  set: (key: string, value: any) => ipcRenderer.invoke('storage:set', key, value),
  delete: (key: string) => ipcRenderer.invoke('storage:delete', key),
  keys: () => ipcRenderer.invoke('storage:keys') as Promise<string[]>,
  clear: () => ipcRenderer.invoke('storage:clear') as Promise<boolean>,
  getPath: () => ipcRenderer.invoke('storage:path') as Promise<string>,
  getKeys: () => ipcRenderer.invoke('storage:getKeys') as Promise<Record<string, string>>,
});

// PyPilot Sessions API
contextBridge.exposeInMainWorld('pypilot', {
  createSession: (projectPath: string, name?: string) => ipcRenderer.invoke('pypilot:createSession', projectPath, name),
  getSessions: (projectPath: string) => ipcRenderer.invoke('pypilot:getSessions', projectPath),
  getActiveSession: (projectPath: string) => ipcRenderer.invoke('pypilot:getActiveSession', projectPath),
  switchSession: (sessionId: number) => ipcRenderer.invoke('pypilot:switchSession', sessionId),
  renameSession: (sessionId: number, newName: string) => ipcRenderer.invoke('pypilot:renameSession', sessionId, newName),
  deleteSession: (sessionId: number) => ipcRenderer.invoke('pypilot:deleteSession', sessionId),
  saveMessage: (sessionId: number, role: string, content: string, metadata?: any) => ipcRenderer.invoke('pypilot:saveMessage', sessionId, role, content, metadata),
  getMessages: (sessionId: number) => ipcRenderer.invoke('pypilot:getMessages', sessionId),
  clearMessages: (sessionId: number) => ipcRenderer.invoke('pypilot:clearMessages', sessionId),
  getMessageCount: (sessionId: number) => ipcRenderer.invoke('pypilot:getMessageCount', sessionId),
});

// Breakpoints API
contextBridge.exposeInMainWorld('breakpoints', {
  add: (projectPath: string, fileUri: string, lineNumber: number) => ipcRenderer.invoke('breakpoints:add', projectPath, fileUri, lineNumber),
  remove: (projectPath: string, fileUri: string, lineNumber: number) => ipcRenderer.invoke('breakpoints:remove', projectPath, fileUri, lineNumber),
  getAll: (projectPath: string) => ipcRenderer.invoke('breakpoints:getAll', projectPath),
  getFile: (projectPath: string, fileUri: string) => ipcRenderer.invoke('breakpoints:getFile', projectPath, fileUri),
  clear: (projectPath: string) => ipcRenderer.invoke('breakpoints:clear', projectPath),
});

// Debug API
contextBridge.exposeInMainWorld('debug', {
  loadPdb: (sourcePath: string) => ipcRenderer.invoke('debug:loadPdb', sourcePath),
});

// EPROM Programmer API (minipro CLI wrapper)
contextBridge.exposeInMainWorld('eprom', {
  detect: () => ipcRenderer.invoke('eprom:detect') as Promise<{ ok: boolean; version?: string; error?: string }>,
  write: (args: { binPath: string; chip: string; programmer: string; skipIdCheck?: boolean; skipVerify?: boolean; eraseFirst?: boolean }) =>
    ipcRenderer.invoke('eprom:write', args) as Promise<{ ok: boolean; stdout?: string; stderr?: string; error?: string }>,
  verify: (args: { binPath: string; chip: string; programmer: string; skipIdCheck?: boolean }) =>
    ipcRenderer.invoke('eprom:verify', args) as Promise<{ ok: boolean; stdout?: string; stderr?: string; error?: string }>,
  blankCheck: (args: { chip: string; programmer: string; skipIdCheck?: boolean }) =>
    ipcRenderer.invoke('eprom:blankCheck', args) as Promise<{ ok: boolean; stdout?: string; stderr?: string; error?: string }>,
  platform: () => ipcRenderer.invoke('eprom:platform') as Promise<{ platform: string }>,
  install: () => ipcRenderer.invoke('eprom:install') as Promise<{ ok: boolean; stdout?: string; stderr?: string; error?: string }>,
  onInstallProgress: (cb: (chunk: string) => void) => {
    const handler = (_e: IpcRendererEvent, data: string) => cb(data);
    ipcRenderer.on('eprom://installProgress', handler);
    return () => ipcRenderer.removeListener('eprom://installProgress', handler);
  },
});

export {};