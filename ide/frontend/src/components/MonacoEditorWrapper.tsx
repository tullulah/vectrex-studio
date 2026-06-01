import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useEditorStore } from '../state/editorStore';
import { useDebugStore } from '../state/debugStore';
import Editor, { OnChange, Monaco, BeforeMount } from '@monaco-editor/react';
// Import full ESM Monaco API and expose it globally so the react wrapper skips AMD loader.js
import * as monacoApi from 'monaco-editor/esm/vs/editor/editor.api';
// Include all standard editor contributions (hover, markers, etc.) so that
// diagnostic underlines show native tooltips and language features work.
// Without this, only the bare API loads and marker hovers won't appear.
import 'monaco-editor/esm/vs/editor/editor.all';
import { logger } from '../utils/logger';
// Bundle the core editor worker via Vite (?worker) so we don't craft blob strings manually.
// If later we add languages needing their own workers we can import them similarly.
// import TsWorker from 'monaco-editor/esm/vs/language/typescript/ts.worker?worker'; (example)
import EditorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker';

// Ensure global monaco is present before @monaco-editor/react evaluates its loader path.
// This prevents the fallback that attempts to inject https://cdn.jsdelivr.../loader.js
if (!(window as any).monaco) {
  (window as any).monaco = monacoApi;
}
import { dockBus } from '../state/dockBus';
import { lspClient } from '../lspClient';
// TODO(i18n): Adapt Monaco UI strings (context menu, messages) when supporting dynamic locale changes.

// Simple language placeholder registration for 'vpy'
export function ensureLanguage(monaco: Monaco) {
  const already = (monaco.languages.getLanguages() || []).some(l => l.id === 'vpy');
  if (!already) {
    monaco.languages.register({ id: 'vpy' });
    monaco.languages.setMonarchTokensProvider('vpy', {
      // Improved tokenizer to highlight declarations and common constructs
      tokenizer: {
        root: [
          // Comments
          [/#[^$]*/, 'comment'],
          // Struct declaration: struct <name>
          [/(struct)(\s+)([A-Za-z_][A-Za-z0-9_]*)/, ['keyword','white','type.declaration']],
          // Function declaration: def <name>
          [/(def)(\s+)([A-Za-z_][A-Za-z0-9_]*)/, ['keyword','white','function.declaration']],
          // Const declaration: const <NAME>
          [/(const)(\s+)([A-Za-z_][A-Za-z0-9_]*)/, ['keyword','white','constant']],
          // Variable declaration: var <name>
          [/(var)(\s+)([A-Za-z_][A-Za-z0-9_]*)/, ['keyword','white','variable']],
          // Python keywords (lowercase)
          [/\b(if|else|elif|while|for|return|break|continue|pass|try|except|finally|with|as|import|from|global|nonlocal|class|lambda|yield|assert|del|in|is|not|and|or)\b/, 'keyword'],
          // VPy keywords (uppercase) - now including META
          [/\b(META|struct|RETURN|IF|ELSE|WHILE|FOR)\b/i, 'keyword'],
          // Built-in drawing / std library like calls
          [/\b(DRAW_(POLYGON|CIRCLE_SEG|CIRCLE|ARC|SPIRAL)|PRINT_TEXT)\b/, 'function'],
          // Intensity / constant style (I_FOO) & ALL_CAPS identifiers
          [/\bI_[A-Z0-9_]+\b/, 'constant'],
          [/\b[A-Z_]{2,}\b/, 'constant'],
          // Hex & decimal numbers
          [/0x[0-9A-Fa-f]+\b/, 'number'],
          [/[0-9]+/, 'number'],
          // Strings
          [/".*?"|'.*?'/, 'string'],
          // Operators
          [/[-+/*=<>!]+/, 'operator'],
          // Identifiers (fallback) – 'main' will be colored by declaration rule if defined
          [/\b[A-Za-z_][A-Za-z0-9_]*\b/, 'identifier']
        ]
      }
    });
    monaco.languages.setLanguageConfiguration('vpy', {
      comments: { lineComment: '#' },
      autoClosingPairs: [
        { open: '"', close: '"' },
        { open: "'", close: "'" },
        { open: '(', close: ')' },
        { open: '[', close: ']' }
      ],
      brackets: [ ['{','}'], ['[',']'], ['(',')'] ]
    });
  }
  // Always (re)define theme so we can tweak later without reload
  monaco.editor.defineTheme('vpy-dark', {
    base: 'vs-dark',
    inherit: true,
    // NOTE: rules cover both classic Monarch tokens and semantic token types.
    // When semantic highlighting is enabled, semantic token ranges override lexical ones,
    // so we explicitly style enumMember + modifiers to color I_* constants.
    rules: [
      // Lexical/Monarch tokens
      { token: 'comment', foreground: '6A9955' },
      { token: 'keyword', foreground: 'C586C0' },
      { token: 'function', foreground: 'DCDCAA' },
      { token: 'type', foreground: '4EC9B0' },
      { token: 'type.declaration', foreground: '4EC9B0' },
      { token: 'constant', foreground: '4FC1FF' },
      { token: 'number', foreground: 'B5CEA8' },
      { token: 'string', foreground: 'CE9178' },
      { token: 'operator', foreground: 'D4D4D4' },
      { token: 'identifier', foreground: 'D4D4D4' },
      // Semantic token specific (enumMember is what server emits for I_* constants)
      { token: 'enumMember', foreground: '4FC1FF' },
      { token: 'enumMember.readonly', foreground: '4FC1FF' },
      // Optional semantic refinements (keep same base color for now)
      { token: 'function.declaration', foreground: 'DCDCAA' },
      { token: 'function.defaultLibrary', foreground: 'DCDCAA' }
    ],
    colors: {
      'editor.background': '#1E1E1E'
    }
  });
}

// Configure self-hosted Monaco paths (no CDN) to satisfy strict CSP 'script-src self'
// We rely on Vite serving node_modules/monaco-editor/min under /monaco via alias injection in dev server config (future improvement: plugin).
// For now we point to default 'vs' expected inside bundle; @monaco-editor/react will inline ESM without loader.js when possible.
export const MonacoEditorWrapper: React.FC<{ uri?: string }> = ({ uri }) => {
  const { t } = useTranslation(['editor','common']);
  // Use individual selectors to avoid creating a fresh object each render (React 19 getSnapshot loop guard)
  const documents = useEditorStore(s => s.documents);
  const active = useEditorStore(s => s.active);
  const setActive = useEditorStore(s => s.setActive);
  const updateContent = useEditorStore(s => s.updateContent);
  const setScrollPosition = useEditorStore(s => s.setScrollPosition);
  const scrollPositions = useEditorStore(s => s.scrollPositions);
  const setHadFocus = useEditorStore(s => s.setHadFocus);
  const hadFocus = useEditorStore(s => s.hadFocus);
  const breakpoints = useEditorStore(s => s.breakpoints);
  const toggleBreakpoint = useEditorStore(s => s.toggleBreakpoint);
  const clearAllBreakpoints = useEditorStore(s => s.clearAllBreakpoints);
  const pdbData = useDebugStore(s => s.pdbData);
  const currentVpyLine = useDebugStore(s => s.currentVpyLine); // Phase 6.1: Track current line
  const currentVpyFile = pdbData?.source?.split('/').pop() ?? null; // CRITICAL: Track which VPy file the breakpoint is in
  const debugState = useDebugStore(s => s.state); // Phase 6.1: Track debug state

  const targetUri = uri || active;
  const doc = documents.find(d => d.uri === targetUri);
  const lastModelRef = useRef<string | undefined>(undefined);
  // Keep track of hover provider so we can dispose on remount (avoid duplicate hover tooltips)
  const hoverDisposableRef = useRef<any>(null);

  const editorRef = useRef<any>(null);
  const monacoRef = useRef<Monaco | null>(null);
  const breakpointDecorationsRef = useRef<string[]>([]); // Track breakpoint decoration IDs
  const currentLineDecorationsRef = useRef<string[]>([]); // Track current line highlight (Phase 6.1)
  const [editorReady, setEditorReady] = useState(false); // Track when editor is mounted and ready
  
  const beforeMount: BeforeMount = (_monaco) => {
    (window as any).MonacoEnvironment = {
      getWorker: function (_moduleId: string, _label: string) {
        // Return a new bundled worker instance; Vite inlines the URL with proper CSP compliance
        return new (EditorWorker as any)();
      },
      baseUrl: '/' // not strictly needed with ESM import but kept for completeness
    };
  };

  // Track which URIs already sent didOpen to LSP
  const openedRef = useRef<Set<string>>(new Set());

  const handleMount = useCallback((editor: any, monaco: Monaco) => {
    logger.debug('App', 'Monaco Editor mounted');
    ensureLanguage(monaco);
    editorRef.current = editor;
    monacoRef.current = monaco;
    setEditorReady(true); // Signal that editor is ready for F9 registration
    monaco.editor.setTheme('vpy-dark');
    
    // Debug: Check if editor is read-only
    logger.debug('App', 'Monaco Editor readOnly setting:', editor.getOption(monaco.editor.EditorOption.readOnly));
    logger.debug('App', 'Monaco Editor configuration check:', {
      readOnly: editor.getOption(monaco.editor.EditorOption.readOnly),
      domReadOnly: editor.getOption(monaco.editor.EditorOption.domReadOnly)
    });
    // Semantic tokens provider bridging LSP tokens (on-demand full refresh)
    monaco.languages.registerDocumentSemanticTokensProvider('vpy', {
      getLegend: () => ({ tokenTypes: ['keyword','function','variable','parameter','number','string','operator','enumMember'], tokenModifiers: ['readonly','declaration','defaultLibrary'] }),
      provideDocumentSemanticTokens: async (model) => {
        try {
          const uri = model.uri.toString();
          const params = { textDocument: { uri } };
          const res = await (lspClient as any).request('textDocument/semanticTokens/full', params);
          if (!res || !res.data) return { data: new Uint32Array() } as any;
          return { data: new Uint32Array(res.data) } as any;
        } catch (e) {
          // Evitar inundar logs: primer fallo puede ocurrir antes de didOpen sincronizado.
          if (!(window as any)._vpySemanticWarned) {
            logger.warn('LSP', 'semantic tokens error (silenced after first):', e);
            (window as any)._vpySemanticWarned = true;
          }
          return { data: new Uint32Array() } as any;
        }
      },
      releaseDocumentSemanticTokens: () => {}
    });
    // LSP-backed completion provider
    monaco.languages.registerCompletionItemProvider('vpy', {
      triggerCharacters: ['_', '(', ',', ' ', '.', ':'],
      provideCompletionItems: async (model, position) => {
        try {
          const uri = model.uri.toString();
          const text = model.getValue();
          // Send didChange before requesting completion to keep server in sync
          lspClient.didChange(uri, text);
          const params = {
            textDocument: { uri },
            position: { line: position.lineNumber - 1, character: position.column - 1 },
            context: { triggerKind: 1 }
          };
          const res = await (lspClient as any).request('textDocument/completion', params);
          if (!res) {
            // fallback: simple word scan
            const words = Array.from(new Set(text.match(/[A-Za-z_][A-Za-z0-9_]{2,}/g) || []));
            const suggestions = words.slice(0,100).map(w => ({ label:w, kind: monaco.languages.CompletionItemKind.Text, insertText:w }));
            return { suggestions };
          }
          const items = Array.isArray(res.items) ? res.items : (Array.isArray(res) ? res : []);
          const suggestions = items.map((it: any) => ({
            label: it.label,
            kind: monaco.languages.CompletionItemKind.Function,
            insertText: it.insertText || it.label,
            range: undefined
          }));
          // console.debug('[LSP] completion items', suggestions.length);
          return { suggestions };
        } catch (e) {
          logger.warn('LSP', 'completion error:', e);
          return { suggestions: [] };
        }
      }
    });
    // Rename provider
    monaco.languages.registerRenameProvider('vpy', {
      provideRenameEdits: async (model, position, newName) => {
        try {
          const uri = model.uri.toString();
          const res = await (lspClient as any).rename(uri, position.lineNumber - 1, position.column - 1, newName);
          if (!res) return { edits: [] } as any;
          const edits: any[] = [];
          if (res.changes) {
            Object.keys(res.changes).forEach(docUri => {
              const targetModel = monaco.editor.getModel(monaco.Uri.parse(docUri));
              if (!targetModel) return;
              res.changes[docUri].forEach((e:any) => {
                edits.push({
                  resource: targetModel.uri,
                  edit: {
                    range: new monaco.Range(
                      e.range.start.line + 1,
                      e.range.start.character + 1,
                      e.range.end.line + 1,
                      e.range.end.character + 1
                    ),
                    text: e.new_text
                  }
                });
              });
            });
          }
          return { edits } as any;
        } catch (e) { logger.warn('LSP', 'rename error:', e); return { edits: [] } as any; }
      },
      resolveRenameLocation: async (model, position) => {
        // Optimistic: allow rename of any identifier; server will veto if not a symbol
        const word = model.getWordAtPosition(position);
        if (!word) return { range: new monaco.Range(position.lineNumber, position.column, position.lineNumber, position.column), text: '' } as any;
        const range = new monaco.Range(position.lineNumber, word.startColumn, position.lineNumber, word.endColumn);
        return { range, text: model.getValueInRange(range) } as any;
      }
    });
    
    // Code Action Provider (Quick Fixes for diagnostics)
    monaco.languages.registerCodeActionProvider('vpy', {
      provideCodeActions: (model, range, context) => {
        const actions: any[] = [];
        
        // Process each diagnostic marker in the context
        for (const marker of context.markers) {
          const message = marker.message;
          
          // Quick Fix 1: Convert to const (for "never changes" hint)
          if (message.includes('never changes') || message.includes('nunca cambia')) {
            const line = model.getLineContent(marker.startLineNumber);
            
            // Extract variable name from message (format: "Variable 'name' never changes...")
            const match = message.match(/Variable ['"](.+?)['"]/);
            if (match) {
              const varName = match[1];
              
              // Replace "varName =" with "const varName ="
              const newText = line.replace(
                new RegExp(`(\\s*)${varName}(\\s*)=`),
                `$1const ${varName}$2=`
              );
              
              actions.push({
                title: `Convert '${varName}' to const`,
                diagnostics: [marker],
                kind: 'quickfix',
                edit: {
                  edits: [{
                    resource: model.uri,
                    versionId: model.getVersionId(),
                    textEdit: {
                      range: new monaco.Range(
                        marker.startLineNumber, 1,
                        marker.startLineNumber, line.length + 1
                      ),
                      text: newText
                    }
                  }]
                },
                isPreferred: true
              });
            }
          }
          
          // Quick Fix 2: Remove unused variable (for "never used" warning)
          if (message.includes('never used') || message.includes('nunca se usa')) {
            const match = message.match(/Variable ['"](.+?)['"]/);
            if (match) {
              const varName = match[1];
              
              actions.push({
                title: `Remove unused variable '${varName}'`,
                diagnostics: [marker],
                kind: 'quickfix',
                edit: {
                  edits: [{
                    resource: model.uri,
                    versionId: model.getVersionId(),
                    textEdit: {
                      range: new monaco.Range(
                        marker.startLineNumber, 1,
                        marker.startLineNumber + 1, 1  // Delete entire line including newline
                      ),
                      text: ''
                    }
                  }]
                }
              });
            }
          }
        }
        
        return {
          actions,
          dispose: () => {}
        };
      }
    });
    
    // Signature help provider
    monaco.languages.registerSignatureHelpProvider('vpy', {
      signatureHelpTriggerCharacters: ['(', ','],
      provideSignatureHelp: async (model, position) => {
        try {
          const uri = model.uri.toString();
          const res = await (lspClient as any).signatureHelp(uri, position.lineNumber - 1, position.column - 1);
          if (!res) return { value: { signatures: [], activeParameter: 0, activeSignature: 0 }, dispose: () => {} };
          return { value: res, dispose: () => {} } as any;
        } catch (e) { logger.warn('LSP', 'signatureHelp error:', e); return { value: { signatures: [], activeParameter: 0, activeSignature: 0 }, dispose: () => {} }; }
      }
    });
    // Hover provider (dispose any previous instance first to avoid stacking)
    if (hoverDisposableRef.current) {
      try { hoverDisposableRef.current.dispose(); } catch {}
      hoverDisposableRef.current = null;
    }
    hoverDisposableRef.current = monaco.languages.registerHoverProvider('vpy', {
      provideHover: async (model, position) => {
        logger.verbose('LSP', 'hover trigger:', model.uri.toString(), position.lineNumber, position.column);
        try {
          const uri = model.uri.toString();
          const params = { textDocument: { uri }, position: { line: position.lineNumber - 1, character: position.column - 1 } };
          const res = await (lspClient as any).request('textDocument/hover', params);
          if (res && res.contents) {
            const contents = typeof res.contents === 'string' ? res.contents : (res.contents.value || '');
            logger.verbose('LSP', 'hover response:', contents);
            return { contents: [{ value: contents }], range: undefined } as any;
          }
        } catch (e) { logger.warn('LSP', 'hover error:', e); }
        logger.verbose('LSP', 'hover empty');
        return null as any;
      }
    });
    logger.verbose('LSP', 'hover provider registered');
    // Extra instrumentation: log mouse move & model language to diagnose missing hover triggers
    try {
      const lang = editor.getModel()?.getLanguageId();
      logger.verbose('App', 'Monaco model languageId=', lang, 'uri=', editor.getModel()?.uri.toString());
      let lastLog = 0;
      editor.onMouseMove((e: any) => {
        const now = performance.now();
        if (now - lastLog < 250) return; // throttle
        lastLog = now;
        const pos = e.target?.position ? `${e.target.position.lineNumber}:${e.target.position.column}` : 'n/a';
        logger.verbose('App', 'Monaco mouseMove target=', e.target?.type, 'pos=', pos, 'detail=', e.target?.detail || '');
      });
      // Force re-apply hover enabled in case wrapper options lost
      editor.updateOptions({ hover: { enabled: true, delay: 150 } });
      // Fallback hover removed (native Monaco hover now active). If needed, reintroduce with a feature flag.
    } catch (e) { logger.warn('App', 'Monaco instrumentation error:', e); }
    // Definition provider
    monaco.languages.registerDefinitionProvider('vpy', {
      provideDefinition: async (model, position) => {
        try {
          const uri = model.uri.toString();
          const params = { textDocument: { uri }, position: { line: position.lineNumber - 1, character: position.column - 1 } };
          const res = await (lspClient as any).request('textDocument/definition', params);
          if (!res) return [];
          const locs = Array.isArray(res) ? res : (res ? [res] : []);
          return locs.map((loc: any) => ({
            uri: monaco.Uri.parse(loc.uri || (loc.targetUri && loc.targetUri.uri) || uri),
            range: new monaco.Range(
              loc.range.start.line + 1,
              loc.range.start.character + 1,
              loc.range.end.line + 1,
              loc.range.end.character + 1
            )
          }));
        } catch (e) { logger.warn('LSP', 'definition error:', e); }
        return [];
      }
    });
    if (doc) {
      const mUri = monaco.Uri.parse(doc.uri);
      let model = monaco.editor.getModel(mUri);
      if (!model) {
        model = monaco.editor.createModel(doc.content, 'vpy', mUri);
      }
      editor.setModel(model);
      lastModelRef.current = doc.uri;
      // Restore previous scroll position if known
      try {
        const top = scrollPositions[doc.uri];
        if (typeof top === 'number') {
          editor.setScrollTop(top);
        }
        // Restore focus only if previously focused & container visible
        if (hadFocus[doc.uri]) {
          requestAnimationFrame(() => editor.focus());
        }
      } catch {}
      // Trigger an initial didChange to encourage semanticTokens/full soon after mount
      if (!openedRef.current.has(doc.uri)) {
        try { lspClient.didOpen(doc.uri, 'vpy', model.getValue()); openedRef.current.add(doc.uri); } catch {}
      } else {
        lspClient.didChange(doc.uri, model.getValue());
      }
      // Listen for scroll to persist position (debounced lightly)
      try {
        let lastScrollEv = 0;
        editor.onDidScrollChange((e: any) => {
          const now = performance.now();
          if (now - lastScrollEv > 50) {
            lastScrollEv = now;
            try { setScrollPosition(doc.uri, editor.getScrollTop()); } catch {}
          }
        });
        editor.onDidBlurEditorWidget(() => { try { setHadFocus(doc.uri, false); } catch {} });
        editor.onDidFocusEditorWidget(() => { try { setHadFocus(doc.uri, true); } catch {} });
      } catch {}
    }
    return () => {
      if (hoverDisposableRef.current) {
        try { hoverDisposableRef.current.dispose(); } catch {}
        hoverDisposableRef.current = null;
      }
    };
  }, [doc, scrollPositions, hadFocus, setScrollPosition, setHadFocus]);

  const handleChange: OnChange = useCallback((value) => {
    logger.debug('App', 'Monaco onChange called, value length:', value?.length, 'doc:', doc?.uri);
    if (doc && typeof value === 'string') {
      logger.debug('App', 'Monaco Updating content for:', doc.uri);
      // Check if editor has focus before update
      const hadFocusBeforeUpdate = editorRef.current?.hasTextFocus();
      logger.debug('App', 'Monaco hadFocusBeforeUpdate:', hadFocusBeforeUpdate);
      
      updateContent(doc.uri, value);
      // Don't duplicate lspClient.didChange - it's already called in updateContent
      
      // Restore focus if it was lost during update
      if (hadFocusBeforeUpdate) {
        requestAnimationFrame(() => {
          const stillHasFocus = editorRef.current?.hasTextFocus();
          logger.debug('App', 'Monaco stillHasFocus after update:', stillHasFocus);
          if (!stillHasFocus && editorRef.current) {
            logger.debug('App', 'Monaco restoring focus after content update');
            editorRef.current.focus();
          }
        });
      }
    }
  }, [doc, updateContent]);

  // When switching documents, ensure model with correct URI is bound
  useEffect(() => {
    if (monacoRef.current && editorRef.current && doc) {
      const monaco = monacoRef.current;
      const mUri = monaco.Uri.parse(doc.uri);
      let model = monaco.editor.getModel(mUri);
      if (!model) {
        model = monaco.editor.createModel(doc.content, 'vpy', mUri);
      } else if (model.getValue() !== doc.content) {
        model.setValue(doc.content);
      }
      if (lastModelRef.current !== doc.uri) {
        editorRef.current.setModel(model);
        lastModelRef.current = doc.uri;
        // Restore scroll & focus after switching
        try {
          const top = scrollPositions[doc.uri];
          if (typeof top === 'number') {
            requestAnimationFrame(() => editorRef.current?.setScrollTop(top));
          }
          if (hadFocus[doc.uri]) {
            requestAnimationFrame(() => editorRef.current?.focus());
          }
        } catch {}
      }
    }
  }, [doc?.uri, doc?.content, scrollPositions, hadFocus]);

  useEffect(() => {
    const unsub = dockBus.on(ev => {
      if (ev.type === 'changed') {
        if (editorRef.current) {
          // slight delay to allow layout container to settle
          requestAnimationFrame(() => editorRef.current.layout());
        }
      }
    });
    return () => { unsub(); };
  }, []);

  // Subscribe to publishDiagnostics once
  useEffect(() => {
    const handler = (method: string, params: any) => {
      if (method === 'textDocument/publishDiagnostics' && monacoRef.current) {
        const { uri, diagnostics } = params || {};
        const rawUri: string = uri || '';
        const cleaned = rawUri.replace(/\\/g,'/');
        // Normalize: ensure triple slash after scheme for Windows paths, lowercase drive letter for matching
        let norm = cleaned;
        // file:///C:/ -> drive letter uppercase in Monaco normally; we will compare case-insensitive
        if (/^file:\/\/[A-Za-z]:\//.test(norm)) {
          // Add extra slash to make file:/// if only two
          norm = norm.replace(/^file:\/\//,'file:///');
        } else if (/^file:\/\/[A-Za-z]:\//.test(norm) === false && /^file:\/\/[A-Za-z]:/.test(norm) === false) {
          // leave others
        }
        const lcNorm = norm.toLowerCase();
        const models = monacoRef.current.editor.getModels();
        let model = models.find(m => m.uri.toString().toLowerCase() === lcNorm);
        if (!model) {
          // Fallback: try collapsing multiple slashes or adding one
            const variants = [
              lcNorm.replace('file:////','file:///'),
              lcNorm.replace('file:///','file://'),
              lcNorm.replace(/^file:\/\//,'file:///')
            ];
            model = models.find(m => variants.includes(m.uri.toString().toLowerCase()));
        }
          if (!model) {
            // Path-based loose match: compare file path tail ignoring case
            try {
              const rawPath = lcNorm.replace('file:///','').replace('file://','');
              const tail = rawPath.split('/') .slice(-3).join('/'); // last 3 segments heuristic
              model = models.find(m => m.uri.toString().toLowerCase().endsWith(tail));
            } catch {}
          }
          if (!model) {
            // As last resort, if this doc is currently active in store with same rawUri (ignoring case), recreate model so we can show markers.
            try {
              const st: any = (useEditorStore as any).getState();
              const docMatch = st.documents.find((d: any) => d.uri.toLowerCase() === lcNorm);
              if (docMatch && monacoRef.current) {
                const mUri = monacoRef.current.Uri.parse(docMatch.uri);
                model = monacoRef.current.editor.createModel(docMatch.content, 'vpy', mUri);
                logger.verbose('LSP', 'recreated missing model for:', docMatch.uri);
              }
            } catch {}
          }
        logger.verbose('LSP', 'diagnostics received uri=', rawUri, 'norm=', lcNorm, 'count=', (diagnostics||[]).length, 'matchedModel=', !!model, 'models=', models.map(m=>m.uri.toString()));
        // Note: Store update is handled by global handler in main.tsx to avoid duplication
        // This handler only applies visual markers to Monaco editor
        if (!model) return; // markers only for open model
        const markers = (diagnostics || []).map((d: any) => ({
          severity: severityToMonaco(d.severity, monacoRef.current!),
            message: d.message,
            startLineNumber: d.range.start.line + 1,
            startColumn: d.range.start.character + 1,
            endLineNumber: d.range.end.line + 1,
            endColumn: d.range.end.character + 1,
            source: d.source || 'vpy'
        }));
        monacoRef.current.editor.setModelMarkers(model, 'vpy', markers);
        logger.debug('LSP', 'applied markers:', markers.length);
      }
    };
    lspClient.onNotification(handler);
  }, []);

  // Listen for compilation diagnostics from Electron to clear Monaco markers
  useEffect(() => {
    const w: any = window as any;
    if (!w?.electronAPI?.onRunDiagnostics) return;
    
    const handler = (diags: Array<{ file: string; line: number; col: number; message: string }>) => {
      if (!monacoRef.current) return;
      
      if (diags.length === 0) {
        // Clear all compilation markers from all Monaco models
        const models = monacoRef.current.editor.getModels();
        models.forEach(model => {
          monacoRef.current!.editor.setModelMarkers(model, 'vpy-compiler', []);
        });
        logger.info('Monaco', 'Cleared all compilation markers from all models');
      } else {
        // Set markers for files with errors
        const markersByUri: Record<string, any[]> = {};
        
        diags.forEach(diag => {
          const { file, line, col, message } = diag;
          
          // Convert file path to URI
          let uri = file;
          if (file && !file.startsWith('file://')) {
            const normPath = file.replace(/\\/g, '/');
            uri = normPath.match(/^[A-Za-z]:\//) ? `file:///${normPath}` : `file://${normPath}`;
          }
          
          if (!markersByUri[uri]) {
            markersByUri[uri] = [];
          }
          
          markersByUri[uri].push({
            severity: monacoRef.current!.MarkerSeverity.Error,
            message: message,
            startLineNumber: line + 1,
            startColumn: col + 1,
            endLineNumber: line + 1,
            endColumn: col + 100,
            source: 'vpy-compiler'
          });
        });
        
        // Apply markers to corresponding models
        Object.entries(markersByUri).forEach(([uri, markers]) => {
          const lcUri = uri.toLowerCase();
          const models = monacoRef.current!.editor.getModels();
          const model = models.find(m => m.uri.toString().toLowerCase().includes(lcUri) || lcUri.includes(m.uri.toString().toLowerCase()));
          
          if (model) {
            monacoRef.current!.editor.setModelMarkers(model, 'vpy-compiler', markers);
            logger.info('Monaco', `Set ${markers.length} compilation markers for ${model.uri.toString()}`);
          }
        });
      }
    };
    
    w.electronAPI.onRunDiagnostics(handler);
  }, []);

  // Listen for goto events to move cursor
  useEffect(() => {
    const listener = (e: any) => {
      if (!editorRef.current || !monacoRef.current) return;
      const { uri, line, column } = e.detail || {};
      if (!uri || line===undefined || column===undefined) return;
      const monaco = monacoRef.current;
      const model = monaco.editor.getModel(monaco.Uri.parse(uri));
      if (model) {
        editorRef.current.setModel(model);
        lastModelRef.current = uri;
        const position = { lineNumber: line + 1, column: column + 1 };
        editorRef.current.revealLineInCenter(position.lineNumber);
        editorRef.current.setPosition(position);
        editorRef.current.focus();
      }
    };
    window.addEventListener('vpy.goto', listener as any);
    return () => window.removeEventListener('vpy.goto', listener as any);
  }, []);

  // Update breakpoint decorations when breakpoints change
  useEffect(() => {
    console.log('[Monaco] 🔄 Breakpoint sync useEffect RUNNING');
    if (!editorRef.current || !monacoRef.current || !doc) {
      console.log('[Monaco] ⚠️ Early return - missing editor/monaco/doc');
      return;
    }
    
    const bps = breakpoints[doc.uri] || new Set<number>();
    logger.debug('Debug', `[Monaco] Breakpoint sync useEffect triggered - bps.size=${bps.size}, pdbData=${!!pdbData}`);
    
    const decorations = Array.from(bps).map(lineNumber => ({
      range: new monacoRef.current!.Range(lineNumber, 1, lineNumber, 1),
      options: {
        isWholeLine: false,
        glyphMarginClassName: 'breakpoint-glyph',
        glyphMarginHoverMessage: { value: 'Breakpoint' }
      }
    }));
    
    breakpointDecorationsRef.current = editorRef.current.deltaDecorations(
      breakpointDecorationsRef.current,
      decorations
    );
    
    // Phase 4: Sync breakpoints with emulator
    const emulatorDebug = (window as any).emulatorDebug;
    
    // DEBUG: Log sync attempt
    console.log('[Monaco] 🔍 Sync check:', {
      emulatorDebug: !!emulatorDebug,
      pdbData: !!pdbData,
      bpsSize: bps.size,
      bpsArray: Array.from(bps)
    });
    
    if (pdbData) {
      console.log('[Monaco] 📋 PDB lineMap contents:', pdbData.lineMap);
    }
    
    if (emulatorDebug && pdbData) {
      console.log('[Monaco] ✅ Both emulatorDebug and pdbData available - proceeding with sync');
      
      // Get current emulator breakpoints
      const currentEmulatorBps = new Set<number>(emulatorDebug.getBreakpoints() as number[]);
      console.log('[Monaco] Current emulator breakpoints:', Array.from(currentEmulatorBps));
      
      // CRITICAL: Detect if current file is ASM or VPy
      const isAsmFile = doc.uri.toLowerCase().endsWith('.asm');
      console.log(`[Monaco] 📄 Current file type: ${isAsmFile ? 'ASM' : 'VPy'}`);
      
      // Convert VPy lines to ASM addresses (only if VPy file)
      const targetAddresses = new Set<number>();
      if (isAsmFile) {
        // ASM file: breakpoints are already in ASM format, use asmAddressMap directly
        console.log('[Monaco] 🔧 ASM file - using asmAddressMap for address lookup');
        for (const line of bps) {
          const address = pdbData.asmAddressMap?.[line.toString()];
          console.log(`[Monaco] 🔍 ASM line ${line} → asmAddressMap result: ${address}`);
          if (address) {
            const addr = parseInt(address, 16);
            if (!isNaN(addr)) {
              targetAddresses.add(addr);
              console.log(`[Monaco] ✓ Added breakpoint target at 0x${addr.toString(16).toUpperCase()}`);
            }
          } else {
            console.warn(`[Monaco] ⚠️ No address mapping for ASM line ${line} in asmAddressMap`);
          }
        }
      } else {
        // VPy file: convert VPy lines to ASM addresses using lineMap or vpyLineMap
        console.log('[Monaco] 🔧 VPy file - using lineMap/vpyLineMap for address lookup');
        
        // Support both single-bank (lineMap) and multibank (vpyLineMap) formats
        const hasVpyLineMap = pdbData.vpyLineMap !== undefined;
        console.log(`[Monaco] 📊 PDB format: ${hasVpyLineMap ? 'multibank (vpyLineMap)' : 'single-bank (lineMap)'}`);
        
        for (const line of bps) {
          let address: string | undefined;
          
          if (hasVpyLineMap && pdbData.vpyLineMap) {
            // Multibank format: vpyLineMap is address → {file, line, column}
            // Find the address where the VPy line maps to
            address = Object.entries(pdbData.vpyLineMap)
              .find(([_, info]) => info.line === line)?.[0];
            
              // If exact line not found, try to find nearest mapped line (prefer previous, fallback to next)
            if (!address) {
              const mappedLines = Object.entries(pdbData.vpyLineMap)
                .map(([addr, info]) => ({ addr, line: info.line }))
                .sort((a, b) => a.line - b.line);
              
                // First try: find the closest line BEFORE (better UX - execute first, then break)
                const previousMappedLine = mappedLines
                  .filter(m => m.line < line)
                  .sort((a, b) => b.line - a.line)[0]; // Get the closest one
              
                // Fallback: if no previous, use the next line
                const nextMappedLine = mappedLines.find(m => m.line > line);
              
                const selectedLine = previousMappedLine || nextMappedLine;
                if (selectedLine) {
                  address = selectedLine.addr;
                  const direction = previousMappedLine ? 'previous' : 'next';
                  console.log(`[Monaco] 🔍 VPy line ${line} has no direct mapping - using ${direction} mapped line ${selectedLine.line} at 0x${address}`);
              } else {
                  console.warn(`[Monaco] ⚠️ No ASM mapping for VPy line ${line} (no nearby lines with mapping)`);
              }
            } else {
              console.log(`[Monaco] 🔍 VPy line ${line} → vpyLineMap result: 0x${address}`);
            }
          } else {
            // Single-bank format: lineMap is line → address
            address = pdbData.lineMap?.[line.toString()];
            console.log(`[Monaco] 🔍 VPy line ${line} → lineMap result: ${address}`);
          }

          if (address) {
            // vpyLineMap keys are DECIMAL address strings (e.g. "776"); lineMap values
            // are hex ("0x0308"). Parse by form so both paths resolve correctly.
            const addr = address.toLowerCase().startsWith('0x')
              ? parseInt(address, 16)
              : parseInt(address, 10);
            if (!isNaN(addr)) {
              targetAddresses.add(addr);
              console.log(`[Monaco] ✓ Added breakpoint target at 0x${addr.toString(16).toUpperCase()}`);
            }
          } else {
            console.warn(`[Monaco] ⚠️ No ASM mapping for VPy line ${line}`);
          }
        }
      }
      
      console.log('[Monaco] Target addresses to sync:', Array.from(targetAddresses).map(a => '0x' + a.toString(16).toUpperCase()));

      // Apply the diff to the emulator. (Earlier this used pdbData.lineMap, which is
      // empty for multibank ROMs, so no breakpoint was ever actually added.)
      for (const addr of currentEmulatorBps) {
        if (!targetAddresses.has(addr)) {
          emulatorDebug.removeBreakpoint(addr);
        }
      }
      for (const addr of targetAddresses) {
        if (!currentEmulatorBps.has(addr)) {
          console.log(`[Monaco] 🔧 emulatorDebug.addBreakpoint(0x${addr.toString(16).toUpperCase()})`);
          emulatorDebug.addBreakpoint(addr);
        }
      }

      // If a debug session is paused waiting for breakpoints, resume now that they're set.
      const dbgState = useDebugStore.getState().state;
      if (dbgState === 'paused' && targetAddresses.size > 0) {
        emulatorDebug.start?.();
        useDebugStore.getState().setState('running');
        console.log('[Monaco] 🚀 Breakpoints synced - emulator running in debug mode');
      }
    } else {
      if (!emulatorDebug) console.warn('[Monaco] ⚠️ emulatorDebug not available');
      if (!pdbData) console.warn('[Monaco] ⚠️ pdbData not available - compile first (Ctrl+F5)');
    }
  }, [breakpoints, doc?.uri, pdbData]);

  // Keyboard shortcuts for breakpoints
  useEffect(() => {
    if (!editorRef.current || !monacoRef.current || !doc) {
      logger.debug('App', 'F9 useEffect: Waiting for editor/monaco/doc');
      return;
    }
    
    const editor = editorRef.current;
    const monaco = monacoRef.current;
    
    // Store the current doc URI in closure to avoid stale references
    const currentUri = doc.uri;
    
    // F9: Toggle breakpoint using addAction (more reliable than addCommand)
    const f9Action = editor.addAction({
      id: 'vpy-toggle-breakpoint',
      label: 'Toggle Breakpoint',
      keybindings: [monaco.KeyCode.F9],
      run: (ed: any) => {
        const position = ed.getPosition();
        if (position) {
          toggleBreakpoint(currentUri, position.lineNumber);
          logger.debug('App', `F9 pressed - toggled breakpoint at line ${position.lineNumber}`);
        }
      }
    });
    
    // Ctrl+Shift+F9: Clear all breakpoints
    const clearAllAction = editor.addAction({
      id: 'vpy-clear-all-breakpoints',
      label: 'Clear All Breakpoints',
      keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyMod.Shift | monaco.KeyCode.F9],
      run: (ed: any) => {
        // Get breakpoints from store directly (avoid closure staleness)
        const currentBps = (useEditorStore.getState().breakpoints[currentUri]) || new Set<number>();
        const count = currentBps.size;
        
        if (count === 0) {
          logger.debug('App', 'Ctrl+Shift+F9 pressed - no breakpoints to clear');
          return;
        } else if (count === 1) {
          clearAllBreakpoints(currentUri);
          logger.debug('App', 'Ctrl+Shift+F9 pressed - cleared 1 breakpoint');
        } else {
          const confirmed = confirm(`Delete all ${count} breakpoints in this file?`);
          if (confirmed) {
            clearAllBreakpoints(currentUri);
            logger.debug('App', `Ctrl+Shift+F9 pressed - cleared ${count} breakpoints`);
          }
        }
      }
    });
    
    logger.debug('App', `F9 shortcuts registered as actions for ${currentUri}`);
    
    return () => {
      // Dispose actions on cleanup
      f9Action?.dispose();
      clearAllAction?.dispose();
      logger.debug('App', `F9 shortcuts cleanup for ${currentUri}`);
    };
  }, [doc?.uri, toggleBreakpoint, clearAllBreakpoints, editorReady]); // Added editorReady to ensure registration on mount

  // Gutter (margin) click handler for breakpoints
  useEffect(() => {
    if (!editorRef.current || !doc) return;
    
    const editor = editorRef.current;
    const disposable = editor.onMouseDown((e: any) => {
      // Check if click is in ANY margin (glyph or line numbers)
      // Type 2 = GUTTER_GLYPH_MARGIN, Type 3 = GUTTER_LINE_NUMBERS, Type 4 = GUTTER_LINE_DECORATIONS
      const isGutterClick = e.target?.type === 2 || e.target?.type === 3 || e.target?.type === 4;
      if (isGutterClick) {
        const lineNumber = e.target.position?.lineNumber;
        if (lineNumber) {
          console.log(`[MonacoEditorWrapper] 🖱️  Gutter click at line ${lineNumber}, type=${e.target.type}`);
          toggleBreakpoint(doc.uri, lineNumber);
        }
      }
    });
    
    return () => disposable?.dispose();
  }, [doc?.uri, toggleBreakpoint]);

  useEffect(() => {
    const w: any = window as any;
    if (!w.electronAPI || !editorRef.current || !monacoRef.current) return;
    const handler = (cmd: string, payload?: any) => {
      const editor = editorRef.current;
      const monaco = monacoRef.current!;
      switch (cmd) {
        case 'indent': editor.trigger('menu','editor.action.indentLines',null); break;
        case 'outdent': editor.trigger('menu','editor.action.outdentLines',null); break;
        case 'toggle-line-comment': editor.trigger('menu','editor.action.commentLine',null); break;
        case 'toggle-block-comment': editor.trigger('menu','editor.action.blockComment',null); break;
        case 'new-file': {
          // Basic new unsaved buffer
          const uri = monaco.Uri.parse(`inmemory://untitled-${Date.now()}.vpy`);
          const model = monaco.editor.createModel('# New File\n', 'vpy', uri);
          editor.setModel(model); break;
        }
        default: break;
      }
    };
    const unsubscribe = w.electronAPI.onCommand(handler);
    return () => {
      if (typeof unsubscribe === 'function') unsubscribe();
    };
  }, []);

  if (!doc) {
    return <div style={{ padding:16, color:'#666' }}>{t('editor:noFile')}</div>;
  }

  // When this wrapper is tied to a specific uri prop and the tab gains focus, ensure active doc updates
  useEffect(() => {
    if (uri && doc && active !== doc.uri) {
      // Passive: do not forcibly override global active unless this tab's model is shown (heuristic: small timeout after mount)
      const t = setTimeout(() => {
        try { setActive(doc.uri); } catch {}
      }, 0);
      return () => clearTimeout(t);
    }
  }, [uri, doc?.uri]);

  // Lazy load content if this is a restored placeholder (empty content, has diskPath)
  useEffect(() => {
    if (doc && doc.diskPath && doc.content === '' && doc.lastSavedContent === '') {
      console.log(`[MonacoEditorWrapper] 📂 Lazy loading from diskPath: ${doc.diskPath}`);
      const api: any = (window as any).files;
      if (!api || !api.readFile) {
        console.log(`[MonacoEditorWrapper] ⚠️ No files API available`);
        return;
      }
      api.readFile(doc.diskPath).then((res: any) => {
        console.log(`[MonacoEditorWrapper] 📄 Read file result:`, res);
        if (!res || res.error) {
          console.log(`[MonacoEditorWrapper] ❌ Error reading file:`, res?.error);
          return;
        }
        const text = res.content || '';
        console.log(`[MonacoEditorWrapper] ✅ Loaded ${text.length} bytes from ${doc.diskPath}`);
        // Update content in store without marking dirty
        try {
          const st = (useEditorStore as any).getState();
          st.updateContent(doc.uri, text);
          st.markSaved(doc.uri, res.mtime);
          console.log(`[MonacoEditorWrapper] ✅ Content updated in store`);
        } catch (err) {
          console.log(`[MonacoEditorWrapper] ⚠️ Error updating store:`, err);
        }
      }).catch((err: any) => {
        console.log(`[MonacoEditorWrapper] ❌ Error in readFile promise:`, err);
      });
    } else if (doc) {
      console.log(`[MonacoEditorWrapper] 🔍 Lazy load check: diskPath=${doc.diskPath}, content.length=${doc.content.length}, lastSavedContent.length=${(doc.lastSavedContent || '').length}`);
    }
  }, [doc?.diskPath]);

  // Phase 6.1: Highlight current line when paused in debugger
  useEffect(() => {
    if (!editorRef.current || !monacoRef.current || !doc) return;
    
    // CRITICAL: Only show highlight if:
    // 1. This is the active document
    // 2. It matches the current file (either .vpy or .asm)
    // 3. We're paused in the debugger
    const activeDoc = useEditorStore.getState().active;
    const isActiveDoc = doc.uri === activeDoc;
    const isVpyFile = doc.uri.endsWith('.vpy');
    const isAsmFile = doc.uri.endsWith('.asm');
    
    // Extract just the filename from the URI (e.g., "main.vpy" from "file:///path/to/main.vpy")
    const currentFileName = doc.uri.split('/').pop() || '';
    
    // Check if this is the correct VPy file
    const isCorrectVpyFile = currentVpyFile && currentFileName === currentVpyFile;
    
    // Check if we're in ASM debugging mode and this is the ASM file
    const isAsmDebuggingMode = (window as any).asmDebuggingMode === true;
    const asmDebuggingFile = (window as any).asmDebuggingFile;
    const isCorrectAsmFile = isAsmDebuggingMode && doc.uri === asmDebuggingFile;
    
    console.log(`[Monaco] 🔍 Highlight check: debugState=${debugState}, currentVpyLine=${currentVpyLine}, currentVpyFile=${currentVpyFile}, currentFileName=${currentFileName}, isCorrectVpyFile=${isCorrectVpyFile}, isCorrectAsmFile=${isCorrectAsmFile}, isActiveDoc=${isActiveDoc}, isVpyFile=${isVpyFile}, isAsmFile=${isAsmFile}`);
    
    // Apply highlight if:
    // - We're paused AND have a valid line number AND
    // - (this is the correct VPy file in VPy debugging mode) OR (this is the correct ASM file in ASM debugging mode)
    const shouldHighlight = debugState === 'paused' && currentVpyLine !== null && isActiveDoc && 
                           (isCorrectVpyFile || isCorrectAsmFile);
    
    if (shouldHighlight) {
      const targetFile = isCorrectAsmFile ? 'ASM' : 'VPy';
      console.log(`[Monaco] ✅ Applying highlight to line ${currentVpyLine} in ${targetFile} file (${currentFileName})`);
      const decorations = [{
        range: new monacoRef.current!.Range(currentVpyLine, 1, currentVpyLine, 1),
        options: {
          isWholeLine: true,
          className: 'current-line-highlight', // Yellow background
          glyphMarginClassName: 'current-line-arrow' // Optional: arrow in gutter
        }
      }];
      
      currentLineDecorationsRef.current = editorRef.current.deltaDecorations(
        currentLineDecorationsRef.current,
        decorations
      );
      
      // Scroll to the current line (reveal in center of viewport)
      // Use setTimeout to ensure editor is ready (especially for ASM files just opened)
      setTimeout(() => {
        if (editorRef.current) {
          editorRef.current.revealLineInCenter(currentVpyLine);
          console.log(`[Monaco] 📍 Scrolled to line ${currentVpyLine}`);
        }
      }, 100);
      
      logger.debug('Debug', `Highlighted current line: ${currentVpyLine}`);
    } else {
      // Clear decorations when not paused or no line or not active doc
      currentLineDecorationsRef.current = editorRef.current.deltaDecorations(
        currentLineDecorationsRef.current,
        []
      );
    }
  }, [debugState, currentVpyLine, pdbData, doc, active]);

  return (
    <Editor
      height="100%"
      defaultLanguage="vpy"
      language="vpy"
  theme="vpy-dark"
  // Model is managed manually; prevent internal re-create by not binding value each render
  value={undefined}
      onChange={handleChange}
      onMount={handleMount}
      beforeMount={beforeMount}
      options={{
        automaticLayout: true,
        minimap: { enabled: false },
        fontSize: 14,
        scrollBeyondLastLine: false,
        wordWrap: 'on',
        wordBasedSuggestions: 'off',
        hover: { enabled: true, delay: 150 },
        'semanticHighlighting.enabled': true,
        quickSuggestions: { other: true, strings: false, comments: false },
        suggestOnTriggerCharacters: true,
        renderValidationDecorations: 'on',
        glyphMargin: true, // Enable glyph margin for breakpoints
        lineNumbersMinChars: 3 // Make room for line numbers + glyph margin
      }}
    />
  );
};

function severityToMonaco(lspSeverity: number | undefined, monaco: Monaco) {
  const S = monaco.MarkerSeverity;
  switch (lspSeverity) {
    case 1: return S.Error;
    case 2: return S.Warning;
    case 3: return S.Info;
    case 4: return S.Hint;
    default: return S.Info;
  }
}

function lspSeverityToText(sev: number | undefined): 'error' | 'warning' | 'info' {
  switch (sev) {
    case 1: return 'error';
    case 2: return 'warning';
    default: return 'info';
  }
}
