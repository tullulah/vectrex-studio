import React, { useState, useEffect, useCallback, useRef } from 'react';
import Editor, { OnMount, BeforeMount } from '@monaco-editor/react';
import type * as MonacoNS from 'monaco-editor';
import { ensureLanguage } from '../MonacoEditorWrapper';

// ── Parser ────────────────────────────────────────────────────────────────────

interface Hunk {
  id: number;
  ours: string[];
  theirs: string[];
  choice: 'ours' | 'theirs' | 'both' | null;
  // 1-based line ranges in oursContent / theirsContent
  oursRange:   { start: number; end: number };
  theirsRange: { start: number; end: number };
}

interface Parsed {
  oursContent:   string;   // full file with ours in conflict slots
  theirsContent: string;   // full file with theirs in conflict slots
  hunks: Hunk[];
  buildResult(hunks: Hunk[]): { content: string; ranges: { start: number; end: number }[] };
}

function parseFile(raw: string): Parsed {
  const lines = raw.split('\n');
  type Chunk = { kind: 'text'; lines: string[] } | { kind: 'hunk'; id: number };
  const chunks: Chunk[] = [];
  const hunks: Hunk[] = [];

  let i = 0, id = 0;
  let textBuf: string[] = [];

  while (i < lines.length) {
    if (lines[i].startsWith('<<<<<<<')) {
      if (textBuf.length) chunks.push({ kind: 'text', lines: [...textBuf] });
      textBuf = [];
      i++;
      const ours: string[] = [];
      while (i < lines.length && !lines[i].startsWith('=======')) ours.push(lines[i++]);
      i++; // skip =======
      const theirs: string[] = [];
      while (i < lines.length && !lines[i].startsWith('>>>>>>>')) theirs.push(lines[i++]);
      i++; // skip >>>>>>>
      const hid = id++;
      hunks.push({ id: hid, ours, theirs, choice: null, oursRange: { start: 0, end: 0 }, theirsRange: { start: 0, end: 0 } });
      chunks.push({ kind: 'hunk', id: hid });
    } else {
      textBuf.push(lines[i++]);
    }
  }
  if (textBuf.length) chunks.push({ kind: 'text', lines: textBuf });

  // Build oursContent + theirsContent and compute line ranges
  const oursLines:   string[] = [];
  const theirsLines: string[] = [];

  for (const chunk of chunks) {
    if (chunk.kind === 'text') {
      oursLines.push(...chunk.lines);
      theirsLines.push(...chunk.lines);
    } else {
      const h = hunks[chunk.id];
      h.oursRange   = { start: oursLines.length   + 1, end: oursLines.length   + Math.max(h.ours.length,   1) };
      h.theirsRange = { start: theirsLines.length + 1, end: theirsLines.length + Math.max(h.theirs.length, 1) };
      oursLines.push(...(h.ours.length   ? h.ours   : ['']));
      theirsLines.push(...(h.theirs.length ? h.theirs : ['']));
    }
  }

  const oursContent   = oursLines.join('\n');
  const theirsContent = theirsLines.join('\n');

  const buildResult = (resolvedHunks: Hunk[]): { content: string; ranges: { start: number; end: number }[] } => {
    const out: string[] = [];
    const ranges: { start: number; end: number }[] = new Array(resolvedHunks.length).fill(null).map(() => ({ start: 0, end: 0 }));
    for (const chunk of chunks) {
      if (chunk.kind === 'text') {
        out.push(...chunk.lines);
      } else {
        const h = resolvedHunks[chunk.id];
        const start = out.length + 1;
        if (!h || h.choice === null) {
          out.push(`<<<<<<< (unresolved)`, ...(h?.ours ?? ['']), '=======', ...(h?.theirs ?? ['']), '>>>>>>>');
        } else if (h.choice === 'ours') {
          out.push(...(h.ours.length ? h.ours : ['']));
        } else if (h.choice === 'theirs') {
          out.push(...(h.theirs.length ? h.theirs : ['']));
        } else {
          out.push(...(h.ours.length ? h.ours : ['']), ...(h.theirs.length ? h.theirs : ['']));
        }
        ranges[h.id] = { start, end: out.length };
      }
    }
    return { content: out.join('\n'), ranges };
  };

  return { oursContent, theirsContent, hunks, buildResult };
}

// ── Types ─────────────────────────────────────────────────────────────────────

interface ConflictFile { filePath: string; resolved: boolean }

interface Props {
  projectDir: string;
  onConflictResolved?: () => void;
  onMergeComplete?: () => void;
}

type EditorRef = MonacoNS.editor.IStandaloneCodeEditor | null;

// ── ConflictResolver ──────────────────────────────────────────────────────────

export const ConflictResolver: React.FC<Props> = ({ projectDir, onConflictResolved, onMergeComplete }) => {
  const [files,        setFiles]        = useState<ConflictFile[]>([]);
  const [loading,      setLoading]      = useState(true);
  const [selectedFile, setSelectedFile] = useState<string | null>(null);
  const [parsed,       setParsed]       = useState<Parsed | null>(null);
  const [hunks,        setHunks]        = useState<Hunk[]>([]);
  const [resultText,   setResultText]   = useState('');
  const [resultRanges, setResultRanges] = useState<{ start: number; end: number }[]>([]);
  const [activeHunk,   setActiveHunk]   = useState(0);
  const [mergeMessage, setMergeMessage] = useState('Merge resolved');
  const [saving,       setSaving]       = useState(false);
  const [completing,   setCompleting]   = useState(false);

  const oursEditorRef:   React.MutableRefObject<EditorRef> = useRef(null);
  const theirsEditorRef: React.MutableRefObject<EditorRef> = useRef(null);
  const resultEditorRef: React.MutableRefObject<EditorRef> = useRef(null);
  const syncingRef = useRef(false);

  const oursDecorRef   = useRef<string[]>([]);
  const theirsDecorRef = useRef<string[]>([]);
  const resultDecorRef = useRef<string[]>([]);

  // ── Load files ──────────────────────────────────────────────────────────────

  useEffect(() => {
    (async () => {
      setLoading(true);
      const git = (window as any).git;
      const r = await git.checkConflicts(projectDir);
      if (r.ok && r.conflicts?.length) {
        const list: ConflictFile[] = r.conflicts.map((f: string) => ({ filePath: f, resolved: false }));
        setFiles(list);
        await openFile(list[0].filePath);
      }
      setLoading(false);
    })();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [projectDir]);

  // ── Open file ───────────────────────────────────────────────────────────────

  const openFile = async (filePath: string) => {
    const git = (window as any).git;
    const r = await git.getConflictDetails({ projectDir, filePath });
    if (!r.ok) return;
    const p = parseFile(r.content);
    const { content, ranges } = p.buildResult(p.hunks);
    setSelectedFile(filePath);
    setParsed(p);
    setHunks(p.hunks);
    setResultText(content);
    setResultRanges(ranges);
    setActiveHunk(0);
  };

  // ── Update decorations ──────────────────────────────────────────────────────

  const updateDecorations = useCallback((
    resolvedHunks: Hunk[],
    activeId: number,
    ranges: { start: number; end: number }[],
    p: Parsed,
  ) => {
    const monacoInstance = (window as any).monaco as typeof MonacoNS | undefined;
    if (!monacoInstance) return;

    const makeDecors = (
      editor: EditorRef,
      decorRef: React.MutableRefObject<string[]>,
      getRangeForHunk: (h: Hunk) => { start: number; end: number } | null,
    ) => {
      if (!editor) return;
      const newDecors: MonacoNS.editor.IModelDeltaDecoration[] = resolvedHunks.map(h => {
        const range = getRangeForHunk(h);
        if (!range) return null;
        const isActive  = h.id === activeId;
        const isResolved = h.choice !== null;
        const className = isResolved
          ? 'conflict-resolved'
          : isActive ? 'conflict-active' : 'conflict-unresolved';
        return {
          range: new monacoInstance.Range(range.start, 1, range.end, 9999),
          options: {
            isWholeLine: true,
            className,
            overviewRuler: {
              color: isResolved ? '#28a745' : isActive ? '#e07b39' : '#c84',
              position: monacoInstance.editor.OverviewRulerLane.Right,
            },
          },
        };
      }).filter(Boolean) as MonacoNS.editor.IModelDeltaDecoration[];
      decorRef.current = editor.deltaDecorations(decorRef.current, newDecors);
    };

    makeDecors(oursEditorRef.current,   oursDecorRef,   h => h.oursRange);
    makeDecors(theirsEditorRef.current, theirsDecorRef, h => h.theirsRange);
    makeDecors(resultEditorRef.current, resultDecorRef, h => ranges[h.id] ?? null);
  }, []);

  // ── Re-decorate when hunks or active change ─────────────────────────────────

  useEffect(() => {
    if (!parsed) return;
    updateDecorations(hunks, activeHunk, resultRanges, parsed);
  }, [hunks, activeHunk, resultRanges, parsed, updateDecorations]);

  // ── Scroll sync ─────────────────────────────────────────────────────────────

  const syncScroll = useCallback((source: 'ours' | 'theirs' | 'result', scrollTop: number) => {
    if (syncingRef.current) return;
    syncingRef.current = true;
    const peers: Array<[string, EditorRef]> = [
      ['ours',   oursEditorRef.current],
      ['theirs', theirsEditorRef.current],
      ['result', resultEditorRef.current],
    ];
    for (const [name, ed] of peers) {
      if (name !== source && ed) ed.setScrollTop(scrollTop);
    }
    setTimeout(() => { syncingRef.current = false; }, 50);
  }, []);

  const makeScrollHandler = (name: 'ours' | 'theirs' | 'result') =>
    (e: MonacoNS.IScrollEvent) => syncScroll(name, e.scrollTop);

  const onMountOurs: OnMount = (editor) => {
    oursEditorRef.current = editor;
    editor.onDidScrollChange(makeScrollHandler('ours'));
    if (parsed) updateDecorations(hunks, activeHunk, resultRanges, parsed);
  };
  const onMountTheirs: OnMount = (editor) => {
    theirsEditorRef.current = editor;
    editor.onDidScrollChange(makeScrollHandler('theirs'));
  };
  const onMountResult: OnMount = (editor) => {
    resultEditorRef.current = editor;
    editor.onDidScrollChange(makeScrollHandler('result'));
  };

  // ── Navigate to hunk ────────────────────────────────────────────────────────

  const revealHunk = useCallback((hunkId: number, p: Parsed | null) => {
    if (!p) return;
    const h = p.hunks[hunkId];
    if (!h) return;
    oursEditorRef.current?.revealLineInCenter(h.oursRange.start);
    theirsEditorRef.current?.revealLineInCenter(h.theirsRange.start);
    resultEditorRef.current?.revealLineInCenter(resultRanges[hunkId]?.start ?? 1);
  }, [resultRanges]);

  const goToHunk = useCallback((idx: number) => {
    const clamped = Math.max(0, Math.min((parsed?.hunks.length ?? 1) - 1, idx));
    setActiveHunk(clamped);
    revealHunk(clamped, parsed);
  }, [parsed, revealHunk]);

  // ── Choose ──────────────────────────────────────────────────────────────────

  const setChoice = useCallback((id: number, choice: 'ours' | 'theirs' | 'both') => {
    if (!parsed) return;
    setHunks(prev => {
      const next = prev.map(h => h.id === id ? { ...h, choice } : h);
      const { content, ranges } = parsed.buildResult(next);
      setResultText(content);
      setResultRanges(ranges);
      updateDecorations(next, activeHunk, ranges, parsed);
      return next;
    });
  }, [parsed, activeHunk, updateDecorations]);

  // ── Save & resolve ──────────────────────────────────────────────────────────

  const handleSave = async () => {
    if (!selectedFile) return;
    const unresolved = hunks.filter(h => h.choice === null).length;
    if (unresolved) { alert(`${unresolved} hunk(s) still unresolved.`); return; }
    setSaving(true);
    try {
      const fullPath = `${projectDir}/${selectedFile}`;
      const apiFiles = (window as any).files;
      await apiFiles.saveFile({ path: fullPath, content: resultText });
      const git = (window as any).git;
      await git.markResolved({ projectDir, filePath: selectedFile });

      // Reload the file in the open editor if it's currently open
      const editorStore = (window as any).__editorStore__;
      if (editorStore) {
        const state = editorStore.getState();
        const doc = state.documents.find((d: any) => d.diskPath === fullPath);
        if (doc) {
          state.updateContent(doc.uri, resultText);
          editorStore.setState((s: any) => ({
            documents: s.documents.map((d: any) =>
              d.uri === doc.uri
                ? { ...d, dirty: false, lastSavedContent: resultText }
                : d
            ),
          }));
        }
      }

      setFiles(prev => prev.map(f => f.filePath === selectedFile ? { ...f, resolved: true } : f));
      setSelectedFile(null); setParsed(null); setHunks([]); setResultText('');
      onConflictResolved?.();
    } finally { setSaving(false); }
  };

  const handleCompleteMerge = async () => {
    if (!files.every(f => f.resolved)) { alert('Resolve all files first.'); return; }
    setCompleting(true);
    try {
      const r = await (window as any).git.completeMerge({ projectDir, message: mergeMessage });
      if (r.ok) onMergeComplete?.();
      else alert(`Failed to complete merge: ${r.error}`);
    } finally { setCompleting(false); }
  };

  // ── Derived ─────────────────────────────────────────────────────────────────

  const unresolvedCount = hunks.filter(h => h.choice === null).length;
  const allResolved     = files.length > 0 && files.every(f => f.resolved);
  const language        = selectedFile?.endsWith('.vpy') ? 'vpy'
                        : selectedFile?.endsWith('.json') ? 'json' : 'plaintext';

  const handleBeforeMount: BeforeMount = (monaco) => ensureLanguage(monaco);

  // Inject decoration CSS once
  useEffect(() => {
    const id = 'conflict-resolver-styles';
    if (document.getElementById(id)) return;
    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      .conflict-active     { background: rgba(224,123, 57,0.18) !important; }
      .conflict-unresolved { background: rgba(200,136, 68,0.10) !important; }
      .conflict-resolved   { background: rgba( 40,167, 69,0.12) !important; }
    `;
    document.head.appendChild(style);
  }, []);

  const editorOpts: MonacoNS.editor.IStandaloneEditorConstructionOptions = {
    minimap: { enabled: false },
    scrollBeyondLastLine: false,
    fontSize: 12,
    lineNumbers: 'on',
    wordWrap: 'off',
    glyphMargin: false,
    folding: false,
    lineDecorationsWidth: 4,
    lineNumbersMinChars: 3,
    renderLineHighlight: 'line',
    scrollbar: { vertical: 'visible', horizontal: 'visible', verticalScrollbarSize: 8 },
    overviewRulerBorder: false,
    overviewRulerLanes: 1,
  };

  // ── Render ───────────────────────────────────────────────────────────────────

  if (loading) return <div style={{ padding: 16, color: '#aaa', fontFamily: 'monospace' }}>Loading conflicts…</div>;
  if (!files.length) return <div style={{ padding: 16, color: '#aaa', fontFamily: 'monospace' }}>No conflicts found.</div>;

  const activeH = hunks[activeHunk] ?? null;

  return (
    <div style={{ display: 'flex', height: '100%', background: '#1e1e1e', color: '#ccc', fontFamily: 'monospace', fontSize: 12, overflow: 'hidden' }}>

      {/* Sidebar */}
      <div style={{ width: 190, flexShrink: 0, borderRight: '1px solid #3e3e42', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '8px 10px', fontSize: 10, fontWeight: 700, color: '#aaa', borderBottom: '1px solid #3e3e42' }}>
          CONFLICTS ({files.filter(f => !f.resolved).length} unresolved)
        </div>
        <div style={{ flex: 1, overflowY: 'auto' }}>
          {files.map(f => (
            <div
              key={f.filePath}
              onClick={() => !f.resolved && openFile(f.filePath)}
              style={{
                padding: '6px 10px', cursor: f.resolved ? 'default' : 'pointer',
                background: selectedFile === f.filePath ? '#2d2d30' : 'transparent',
                color: f.resolved ? '#555' : '#ccc', fontSize: 11,
                display: 'flex', alignItems: 'center', gap: 6,
              }}
            >
              <span>{f.resolved ? '✓' : '⚠'}</span>
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {f.filePath.split('/').pop()}
              </span>
            </div>
          ))}
        </div>
        {allResolved && (
          <div style={{ padding: 8, borderTop: '1px solid #3e3e42' }}>
            <input
              value={mergeMessage} onChange={e => setMergeMessage(e.target.value)}
              style={{ width: '100%', marginBottom: 6, background: '#2d2d30', border: '1px solid #555', color: '#ccc', padding: '3px 6px', borderRadius: 3, fontSize: 11, boxSizing: 'border-box' }}
            />
            <button disabled={completing} onClick={handleCompleteMerge}
              style={{ width: '100%', padding: '4px 0', background: '#28a745', border: 'none', color: '#fff', borderRadius: 3, cursor: 'pointer', fontSize: 11 }}>
              ✓ Complete Merge
            </button>
          </div>
        )}
      </div>

      {/* Main */}
      {selectedFile && parsed ? (
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', minWidth: 0 }}>

          {/* Toolbar */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 10px', background: '#252526', borderBottom: '1px solid #3e3e42', flexShrink: 0 }}>
            <button onClick={() => goToHunk(activeHunk - 1)} disabled={activeHunk === 0}
              style={navBtnStyle(activeHunk === 0)}>‹ Prev</button>
            <span style={{ fontSize: 11, color: '#aaa' }}>
              Hunk {activeHunk + 1} / {hunks.length}
              {activeH && activeH.choice !== null
                ? <span style={{ color: '#6a6', marginLeft: 6 }}>✓ {activeH.choice}</span>
                : <span style={{ color: '#c84', marginLeft: 6 }}>⚠ unresolved</span>}
            </span>
            <button onClick={() => goToHunk(activeHunk + 1)} disabled={activeHunk >= hunks.length - 1}
              style={navBtnStyle(activeHunk >= hunks.length - 1)}>Next ›</button>

            <div style={{ flex: 1 }} />

            {/* Per-hunk choice buttons */}
            {activeH && (
              <>
                <button onClick={() => setChoice(activeH.id, 'ours')}
                  style={choiceBtnStyle(activeH.choice === 'ours', '#28a745')}>← Use Ours</button>
                <button onClick={() => setChoice(activeH.id, 'both')}
                  style={choiceBtnStyle(activeH.choice === 'both', '#555')}>↕ Use Both</button>
                <button onClick={() => setChoice(activeH.id, 'theirs')}
                  style={choiceBtnStyle(activeH.choice === 'theirs', '#e07b39')}>Use Theirs →</button>
              </>
            )}
          </div>

          {/* Top row: Ours + Theirs */}
          <div style={{ display: 'flex', flex: 1, overflow: 'hidden', minHeight: 0 }}>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', minWidth: 0 }}>
              <div style={panelHeader('#4c9')}>← OURS (HEAD)</div>
              <div style={{ flex: 1 }}>
                <Editor
                  value={parsed.oursContent}
                  language={language}
                  theme="vs-dark"
                  beforeMount={handleBeforeMount}
                  options={{ ...editorOpts, readOnly: true }}
                  onMount={onMountOurs}
                />
              </div>
            </div>
            <div style={{ width: 3, background: '#3e3e42', flexShrink: 0 }} />
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', minWidth: 0 }}>
              <div style={panelHeader('#c94')}>THEIRS (incoming) →</div>
              <div style={{ flex: 1 }}>
                <Editor
                  value={parsed.theirsContent}
                  language={language}
                  theme="vs-dark"
                  beforeMount={handleBeforeMount}
                  options={{ ...editorOpts, readOnly: true }}
                  onMount={onMountTheirs}
                />
              </div>
            </div>
          </div>

          {/* Result */}
          <div style={{ height: 220, flexShrink: 0, display: 'flex', flexDirection: 'column', borderTop: '2px solid #3e3e42' }}>
            <div style={panelHeader('#7af')}>
              RESULT — {selectedFile.split('/').pop()}
              {unresolvedCount > 0
                ? <span style={{ color: '#c84', marginLeft: 8, fontWeight: 400 }}>({unresolvedCount} unresolved)</span>
                : <span style={{ color: '#6a6', marginLeft: 8, fontWeight: 400 }}>(all resolved)</span>}
            </div>
            <div style={{ flex: 1, minHeight: 0 }}>
              <Editor
                value={resultText}
                language={language}
                theme="vs-dark"
                beforeMount={handleBeforeMount}
                options={{ ...editorOpts, readOnly: false }}
                onChange={v => setResultText(v ?? '')}
                onMount={onMountResult}
              />
            </div>
          </div>

          {/* Footer */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', background: '#252526', borderTop: '1px solid #3e3e42', flexShrink: 0 }}>
            <button
              disabled={saving || unresolvedCount > 0}
              onClick={handleSave}
              style={{ padding: '4px 14px', background: unresolvedCount ? '#333' : '#28a745', border: 'none', color: unresolvedCount ? '#666' : '#fff', borderRadius: 3, cursor: unresolvedCount ? 'not-allowed' : 'pointer', fontSize: 11 }}>
              {saving ? 'Saving…' : '✓ Save & Mark Resolved'}
            </button>
            {unresolvedCount > 0 && <span style={{ fontSize: 11, color: '#c84' }}>{unresolvedCount} hunk(s) need a choice</span>}
          </div>
        </div>
      ) : (
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#555' }}>
          Select a conflicted file
        </div>
      )}
    </div>
  );
};

// ── Style helpers ─────────────────────────────────────────────────────────────

const panelHeader = (color: string): React.CSSProperties => ({
  padding: '3px 10px', fontSize: 10, fontWeight: 700, color,
  background: '#252526', borderBottom: '1px solid #3e3e42', flexShrink: 0,
});

const navBtnStyle = (disabled: boolean): React.CSSProperties => ({
  padding: '2px 10px', fontSize: 11,
  background: disabled ? '#252526' : '#2d2d30',
  border: '1px solid #555', color: disabled ? '#555' : '#ccc',
  borderRadius: 3, cursor: disabled ? 'not-allowed' : 'pointer',
});

const choiceBtnStyle = (active: boolean, color: string): React.CSSProperties => ({
  padding: '3px 10px', fontSize: 11,
  background: active ? color : '#2d2d30',
  border: `1px solid ${active ? color : '#555'}`,
  color: active ? '#fff' : '#aaa',
  borderRadius: 3, cursor: 'pointer',
});
