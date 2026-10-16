/// <reference types="node" />
import * as vscode from 'vscode';
import { LanguageClient, LanguageClientOptions, ServerOptions, TransportKind } from 'vscode-languageclient/node';
import { spawn, ChildProcess } from 'child_process';
import * as path from 'path';
import * as os from 'os';

let client: LanguageClient | undefined;

export function activate(context: vscode.ExtensionContext) {
  console.log('='.repeat(80));
  console.log('[VPy] 🚀 EXTENSION ACTIVATION STARTED');
  console.log('[VPy] Extension path:', context.extensionPath);
  console.log('[VPy] Extension mode:', context.extensionMode);
  console.log('='.repeat(80));
  
  // Get workspace root
  const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
  console.log('[VPy] Workspace root:', root || 'NONE');
  
  if (!root) {
    console.warn('[VPy] ⚠️  NO WORKSPACE ROOT - MCP server will NOT be registered');
    return;
  }
  
  // Register MCP Server Definition Provider
  const serverPath = path.join(root, 'ide', 'mcp-server', 'server.js');
  console.log('[VPy MCP] 📝 REGISTERING MCP Server Definition Provider...');
  console.log('[VPy MCP] Provider ID: "vpy-ide"');
  console.log('[VPy MCP] Server path:', serverPath);
  console.log('[VPy MCP] Server exists?', require('fs').existsSync(serverPath));
  
  try {
    const disposable = vscode.lm.registerMcpServerDefinitionProvider('vpy-ide', {
      onDidChangeMcpServerDefinitions: undefined,
      provideMcpServerDefinitions: async (token: vscode.CancellationToken) => {
        console.log('─'.repeat(80));
        console.log('[VPy MCP] 🔔 provideMcpServerDefinitions CALLED!');
        console.log('[VPy MCP] Cancellation token:', token);
        console.log('[VPy MCP] Token cancelled?', token.isCancellationRequested);
        
        const serverDef: any = {
          name: 'vpy-ide',
          label: 'VPy IDE',
          type: 'stdio',
          command: 'node',
          args: [serverPath, '--stdio'],
          env: {}  // CRITICAL: VS Code expects env to be an object, not undefined
        };
        
        console.log('[VPy MCP] 📤 Returning server definition:');
        console.log(JSON.stringify(serverDef, null, 2));
        console.log('[VPy MCP] Server definition array length: 1');
        console.log('─'.repeat(80));
        
        return [serverDef];
      }
    });
    
    context.subscriptions.push(disposable);
    console.log('[VPy MCP] ✅ Provider registered successfully');
    console.log('[VPy MCP] Disposable added to subscriptions');
    
  } catch (error) {
    console.error('[VPy MCP] ❌ ERROR registering provider:', error);
    if (error instanceof Error) {
      console.error('[VPy MCP] Error message:', error.message);
      console.error('[VPy MCP] Error stack:', error.stack);
    }
  }

  console.log('[VPy] ✅ Extension activated - MCP server registered with VS Code');
  console.log('[VPy] Root:', root);
  console.log('[VPy] VS Code will manage the MCP server lifecycle automatically');
  console.log('='.repeat(80));

  // Command: compile current .vpy using existing cargo binary
  const compileCmd = vscode.commands.registerCommand('vpy.compileCurrent', async () => {
    const doc = vscode.window.activeTextEditor?.document;
    if (!doc || doc.languageId !== 'vpy') { return; }
    await doc.save();
    const terminal = vscode.window.createTerminal({ name: 'VPy Build' });
    terminal.show(true);
    terminal.sendText(`cargo run --quiet --bin vpy_cli -- build "${doc.fileName}"`);
  });
  context.subscriptions.push(compileCmd);

  // Simple inline diagnostics via regex while full LSP server is WIP
  const diagCollection = vscode.languages.createDiagnosticCollection('vpy');
  context.subscriptions.push(diagCollection);

  // Debounce LSP analysis - avoid running on every keystroke
  let analysisTimeout: NodeJS.Timeout | undefined;
  const recomputeDiagnostics = (doc: vscode.TextDocument) => {
    if (doc.languageId !== 'vpy') return;
    const diags: vscode.Diagnostic[] = [];
    for (let i = 0; i < doc.lineCount; i++) {
      const line = doc.lineAt(i).text;
      if (/\bPOLYGON\s+2\b/.test(line)) {
        diags.push(new vscode.Diagnostic(new vscode.Range(i,0,i,line.length), 'POLYGON count 2 genera lista degenerada (usa >=3 o un RECT delgado).', vscode.DiagnosticSeverity.Warning));
      }
    }
    diagCollection.set(doc.uri, diags);
  };
  if (vscode.window.activeTextEditor) {
    recomputeDiagnostics(vscode.window.activeTextEditor.document);
  }
  
  // Debounce handler: only recompute after user stops typing for 500ms
  context.subscriptions.push(vscode.workspace.onDidChangeTextDocument(e => {
    if (analysisTimeout) clearTimeout(analysisTimeout);
    analysisTimeout = setTimeout(() => {
      recomputeDiagnostics(e.document);
    }, 500); // 500ms debounce delay
  }));
  
  context.subscriptions.push(vscode.workspace.onDidOpenTextDocument(doc => recomputeDiagnostics(doc)));

  // Real LSP server: spawn compiled Rust binary (expects cargo build executed previously)
  if (root) {
    const exeName = process.platform === 'win32' ? 'vpy_lsp.exe' : 'vpy_lsp';
    const exePath = vscode.Uri.joinPath(vscode.Uri.file(root), 'target', 'debug', exeName).fsPath;
    const serverOptions: ServerOptions = {
      run: { command: exePath, transport: TransportKind.stdio } as any,
      debug: { command: exePath, transport: TransportKind.stdio, options: { execArgv: [] } } as any
    };
    const clientOptions: LanguageClientOptions = { documentSelector: [{ language: 'vpy' }], synchronize: { fileEvents: vscode.workspace.createFileSystemWatcher('**/*.vpy') } };
    client = new LanguageClient('vpyLanguageServer','VPy Language Server', serverOptions, clientOptions);
    client.start();
  }
}

export function deactivate(): Thenable<void> | undefined {
  console.log('='.repeat(80));
  console.log('[VPy] 🛑 EXTENSION DEACTIVATION');
  console.log('[VPy] Stopping language client...');
  console.log('='.repeat(80));
  // VS Code manages MCP server lifecycle automatically when using McpServerDefinitionProvider
  return client?.stop();
}
