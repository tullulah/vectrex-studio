import { create } from 'zustand';
import type { DocumentModel, DiagnosticModel } from '../types/models.js';
import { lspClient } from '../lspClient.js';
import { logger } from '../utils/logger.js';
import { useDebugStore } from './debugStore.js';

interface FlatDiag { uri: string; file: string; line: number; column: number; severity: DiagnosticModel['severity']; message: string; source?: string; }

interface EditorState {
  documents: DocumentModel[];
  active?: string; // uri
  allDiagnostics: FlatDiag[]; // kept sorted & stable reference unless content changes
  scrollPositions: Record<string, number>; // vertical scrollTop per document
  hadFocus: Record<string, boolean>; // whether doc was focused last interaction
  breakpoints: Record<string, Set<number>>; // uri -> set of line numbers (1-indexed)
  vecClipboard: any[] | null; // global clipboard for VectorEditor copy/paste
  openDocument: (doc: DocumentModel) => void;
  setActive: (uri: string) => void;
  updateContent: (uri: string, content: string) => void;
  markSaved: (uri: string, newMtime?: number) => void;
  setDiagnostics: (uri: string, diags: DiagnosticModel[]) => void;
  setDiagnosticsBySource: (uri: string, source: string, diags: DiagnosticModel[]) => void;
  closeDocument: (uri: string) => void;
  gotoLocation: (uri: string, line: number, column: number) => void;
  setScrollPosition: (uri: string, top: number) => void;
  setHadFocus: (uri: string, focused: boolean) => void;
  setVecClipboard: (paths: any[] | null) => void;
  toggleBreakpoint: (uri: string, lineNumber: number) => void;
  clearAllBreakpoints: (uri?: string) => void;
  loadBreakpointsFromDb: (projectPath: string) => Promise<void>;
}

// Detect language from file extension
function detectLanguageFromUri(uri: string): string {
  const lower = uri.toLowerCase();
  if (lower.endsWith('.vpy')) return 'vpy';
  if (lower.endsWith('.vec') || lower.endsWith('.vmus') || lower.endsWith('.json')) return 'json';
  if (lower.endsWith('.asm') || lower.endsWith('.s')) return 'asm';
  if (lower.endsWith('.md')) return 'markdown';
  if (lower.endsWith('.ts') || lower.endsWith('.tsx')) return 'typescript';
  if (lower.endsWith('.js') || lower.endsWith('.jsx')) return 'javascript';
  return 'vpy'; // default fallback
}

function recomputeAllDiagnostics(documents: DocumentModel[]): FlatDiag[] {
  const rows: FlatDiag[] = [];
  logger.verbose('LSP', 'recomputeAllDiagnostics - processing documents:', documents.length);
  for (const d of documents) {
    logger.verbose('LSP', 'Document URI:', d.uri, 'diagnostics count:', (d.diagnostics || []).length);
    for (const diag of d.diagnostics || []) {
      rows.push({
        uri: d.uri,
        file: d.uri.split('/').pop() || d.uri,
        line: diag.line,
        column: diag.column,
        severity: diag.severity,
        message: diag.message,
        source: diag.source
      });
    }
  }
  logger.verbose('LSP', 'Total diagnostic rows before sort:', rows.length);
  const sevOrder: Record<string, number> = { error: 0, warning: 1, info: 2 } as any;
  rows.sort((a,b) => {
    const so = (sevOrder[a.severity]??9) - (sevOrder[b.severity]??9); if (so!==0) return so;
    const f = a.file.localeCompare(b.file); if (f!==0) return f;
    return a.line - b.line || a.column - b.column;
  });
  logger.verbose('LSP', 'Final sorted diagnostic rows:', rows);
  return rows;
}

export const useEditorStore = create<EditorState>((set, get) => ({
  documents: [],
  active: undefined,
  allDiagnostics: [],
  scrollPositions: {},
  hadFocus: {},
  breakpoints: {}, // Initialize breakpoints map
  vecClipboard: null,
  openDocument: (doc) => set((s) => {
    logger.debug('File', 'openDocument called with URI:', doc.uri);
    // If document already open (by uri) just activate & optionally refresh metadata
    const existing = s.documents.find(d => d.uri === doc.uri);
    let documents: DocumentModel[];
    if (existing) {
      documents = s.documents.map(d => d.uri === doc.uri ? { ...d, ...doc, dirty: false, lastSavedContent: doc.content } : d);
    } else {
      documents = [...s.documents, { ...doc, dirty: false, lastSavedContent: doc.content }];
    }
    logger.debug('File', 'openDocument - final documents URIs:', documents.map(d => d.uri));
    return { documents, active: doc.uri, allDiagnostics: recomputeAllDiagnostics(documents) };
  }),
  setActive: (uri) => {
    logger.debug('App', 'setActive called with URI:', uri);
    const currentStack = new Error().stack;
    logger.debug('App', 'setActive call stack:', currentStack?.split('\n').slice(1, 4).join('\n'));
    set({ active: uri });
  },
  updateContent: (uri, content) => {
    set((s) => {
      const documents = s.documents.map(d => d.uri === uri ? {
        ...d,
        content,
        dirty: d.lastSavedContent !== undefined ? (content !== d.lastSavedContent) : true
      } : d);
      return { 
        documents, 
        allDiagnostics: recomputeAllDiagnostics(documents),
        active: s.active // PRESERVE active value during content updates
      };
    });
    // Note: lspClient.didChange is called from MonacoEditorWrapper.handleChange to avoid duplication
  },
  markSaved: (uri, newMtime) => set((s) => {
    const documents = s.documents.map(d => d.uri === uri ? {
      ...d,
      dirty: false,
      lastSavedContent: d.content,
      mtime: newMtime ?? d.mtime
    } : d);
    return { 
      documents,
      active: s.active // PRESERVE active value during save operations
    };
  }),
  setDiagnostics: (uri, diags) => set((s) => {
    logger.verbose('LSP', 'setDiagnostics called with URI:', uri);
    logger.verbose('LSP', 'Available document URIs:', s.documents.map(d => d.uri));
    logger.verbose('LSP', 'Diagnostics to set:', diags);
    const documents = s.documents.map(d => d.uri === uri ? { ...d, diagnostics: diags } : d);
    const foundDoc = s.documents.find(d => d.uri === uri);
    logger.verbose('LSP', 'Found matching document:', !!foundDoc);
    if (!foundDoc) {
      logger.warn('LSP', 'No document found for URI:', uri, 'Available:', s.documents.map(d => d.uri));
    }
    const newAllDiagnostics = recomputeAllDiagnostics(documents);
    logger.verbose('LSP', 'Computed allDiagnostics:', newAllDiagnostics);
    return { 
      documents, 
      allDiagnostics: newAllDiagnostics,
      active: s.active // PRESERVE active value during diagnostics updates
    };
  }),
  setDiagnosticsBySource: (uri, source, diags) => set((s) => {
    logger.info('EditorStore', `setDiagnosticsBySource: uri=${uri}, source=${source}, count=${diags.length}`);
    
    const documents = s.documents.map(d => {
      if (d.uri !== uri) return d;
      
      const beforeCount = (d.diagnostics || []).length;
      logger.info('EditorStore', `  Document found: ${d.uri}`);
      logger.info('EditorStore', `  Before: ${beforeCount} diagnostics`);
      
      // Show breakdown by source
      const bySource: Record<string, number> = {};
      (d.diagnostics || []).forEach(diag => {
        const src = diag.source || 'no-source';
        bySource[src] = (bySource[src] || 0) + 1;
      });
      logger.info('EditorStore', `  Breakdown:`, bySource);
      
      // Filter out existing diagnostics from this source, then add new ones
      const existingDiags = (d.diagnostics || []).filter(diag => diag.source !== source);
      const newDiags = diags.map(diag => ({ ...diag, source }));
      const combinedDiags = [...existingDiags, ...newDiags];
      
      logger.info('EditorStore', `  Keeping ${existingDiags.length} diagnostics from other sources`);
      logger.info('EditorStore', `  Adding ${newDiags.length} diagnostics for source '${source}'`);
      logger.info('EditorStore', `  After: ${combinedDiags.length} diagnostics`);
      
      return { ...d, diagnostics: combinedDiags };
    });
    
    const newAllDiagnostics = recomputeAllDiagnostics(documents);
    logger.verbose('LSP', 'Final allDiagnostics count:', newAllDiagnostics.length);
    
    return { 
      documents, 
      allDiagnostics: newAllDiagnostics,
      active: s.active
    };
  }),
  closeDocument: (uri) => set((s) => {
    const documents = s.documents.filter(d => d.uri !== uri);
    return { documents, active: s.active === uri ? undefined : s.active, allDiagnostics: recomputeAllDiagnostics(documents) };
  }),
  gotoLocation: (uri, line, column) => {
    const s = get();
    if (!s.documents.some(d => d.uri === uri)) {
      const language = detectLanguageFromUri(uri); // Auto-detect language
      const documents: DocumentModel[] = [...s.documents, { uri, language, content: '', dirty: false, diagnostics: [], lastSavedContent: '' } as DocumentModel];
      set({ documents, active: uri, allDiagnostics: recomputeAllDiagnostics(documents) });
    } else {
      set({ active: uri });
    }
    const ev = new CustomEvent('vpy.goto', { detail: { uri, line, column } });
    window.dispatchEvent(ev);
  },
  setScrollPosition: (uri, top) => set(s => ({ scrollPositions: { ...s.scrollPositions, [uri]: top } })),
  setHadFocus: (uri, focused) => set(s => ({ hadFocus: { ...s.hadFocus, [uri]: focused } })),
  setVecClipboard: (paths) => set({ vecClipboard: paths }),
  toggleBreakpoint: (uri, lineNumber) => {
    const s = useEditorStore.getState();
    const bps = s.breakpoints[uri] || new Set<number>();
    const newBps = new Set(bps);
    const wasAdded = !newBps.has(lineNumber);
    
    if (newBps.has(lineNumber)) {
      newBps.delete(lineNumber);
      logger.debug('App', `Removed breakpoint at ${uri}:${lineNumber}`);
    } else {
      newBps.add(lineNumber);
      logger.debug('App', `Added breakpoint at ${uri}:${lineNumber}`);
    }
    
    useEditorStore.setState({ breakpoints: { ...s.breakpoints, [uri]: newBps } });
    
    // Persist to SQLite (async, fire-and-forget)
    const breakpointsAPI = (window as any).breakpoints;
    if (breakpointsAPI) {
      const projectPath = (window as any).__currentProjectPath__;
      if (projectPath) {
        if (wasAdded) {
          breakpointsAPI.add(projectPath, uri, lineNumber)
            .catch((err: any) => console.error('[EditorStore] Error persisting breakpoint add:', err));
        } else {
          breakpointsAPI.remove(projectPath, uri, lineNumber)
            .catch((err: any) => console.error('[EditorStore] Error persisting breakpoint remove:', err));
        }
      }
    }
    
    // Notify debugStore for dynamic breakpoint synchronization
    // This allows adding/removing breakpoints during active debugging session
    if (wasAdded) {
      useDebugStore.getState().onBreakpointAdded(uri, lineNumber);
    } else {
      useDebugStore.getState().onBreakpointRemoved(uri, lineNumber);
    }
  },
  clearAllBreakpoints: (uri) => set(s => {
    if (uri) {
      logger.debug('App', `Cleared all breakpoints for ${uri}`);
      return { breakpoints: { ...s.breakpoints, [uri]: new Set<number>() } };
    } else {
      logger.debug('App', 'Cleared all breakpoints in all files');
      return { breakpoints: {} };
    }
  }),
  
  loadBreakpointsFromDb: async (projectPath: string) => {
    const breakpointsAPI = (window as any).breakpoints;
    if (!breakpointsAPI) {
      logger.warn('EditorStore', 'Cannot load breakpoints: breakpoints API not available');
      return;
    }
    
    try {
      const result = await breakpointsAPI.getAll(projectPath);
      
      if (result.success && result.breakpoints) {
        // Convert flat array to Record<uri, Set<lineNumber>>
        const breakpointMap: Record<string, Set<number>> = {};
        
        for (const bp of result.breakpoints) {
          if (!breakpointMap[bp.fileUri]) {
            breakpointMap[bp.fileUri] = new Set<number>();
          }
          breakpointMap[bp.fileUri].add(bp.lineNumber);
        }
        
        useEditorStore.setState({ breakpoints: breakpointMap });
        logger.info('EditorStore', `Loaded ${result.breakpoints.length} breakpoint(s) from database`);
      }
    } catch (error) {
      logger.error('EditorStore', 'Error loading breakpoints from database:', error);
    }
  }
}));

// Expose store globally for MCP server access
if (typeof window !== 'undefined') {
  (window as any).__editorStore__ = useEditorStore;
}
