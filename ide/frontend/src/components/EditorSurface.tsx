import React, { useCallback, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useEditorStore } from '../state/editorStore';
import { useProjectStore } from '../state/projectStore';
import { WelcomeView } from './WelcomeView';
import { MonacoEditorWrapper } from './MonacoEditorWrapper';
import { VectorEditor } from './VectorEditor';
import { MusicEditor } from './MusicEditor';
import { SFXEditor } from './SFXEditor';
import { AnimationEditor } from './AnimationEditor';
import { InstrumentEditor } from './InstrumentEditor';
import { EnemyEditor } from './EnemyEditor';
import { VrecViewer } from './VrecViewer';
import { VsmpPlayer } from './VsmpPlayer';
import { VectorMovieEditor } from './VectorMovieEditor';
import { MeshEditor } from './MeshEditor';
import { SceneEditor } from './SceneEditor';
import { Anim3DEditor } from './Anim3DEditor';
import { FileTreeMenu, type MenuItem } from './panels/FileTreeMenu';

const IS_MAC = typeof navigator !== 'undefined' && /mac/i.test(navigator.platform);
const IS_WIN = typeof navigator !== 'undefined' && /win/i.test(navigator.platform);

// Basic custom tab bar replacing flexlayout doc:* logic.
// Phase 1: single group, order = documents array order.

export const EditorSurface: React.FC = () => {
  const { t } = useTranslation(['common']);
  const documents = useEditorStore(s=>s.documents);
  const active = useEditorStore(s=>s.active);
  const setActive = useEditorStore(s=>s.setActive);
  const closeDocument = useEditorStore(s=>s.closeDocument);
  const hasWorkspace = useProjectStore(s=>s.hasWorkspace());
  const setPinned = useEditorStore(s=>s.setPinned);
  const projectRoot = useProjectStore(s=>s.project?.rootPath);
  const visibleDocs = documents; // pinned tabs first: setPinned keeps them at the front
  const [tabMenu, setTabMenu] = useState<{ x: number; y: number; uri: string } | null>(null);

  /** Close several tabs: one confirmation for all the unsaved ones among them. If the active
   *  tab goes, `keep` (the tab the menu was opened on) becomes active, or a neighbour. */
  const closeMany = useCallback((uris: string[], keep?: string) => {
    const docs = useEditorStore.getState().documents;
    const going = docs.filter(d => uris.includes(d.uri));
    if (!going.length) return;
    const unsaved = going.filter(d => d.dirty);
    if (unsaved.length === 1 && going.length === 1) {
      if (!window.confirm(t('dialog.unsavedChanges', 'File has unsaved changes. Close anyway?'))) return;
    } else if (unsaved.length > 0) {
      const names = unsaved.map(d => deriveTitle(d.uri)).join(', ');
      if (!window.confirm(t('tabs.confirmCloseUnsaved', { count: unsaved.length, names }))) return;
    }
    const st = useEditorStore.getState();
    const wasActive = st.active;
    const idx = docs.findIndex(d => d.uri === wasActive);
    for (const d of going) st.closeDocument(d.uri);
    if (wasActive && uris.includes(wasActive)) {
      const left = useEditorStore.getState().documents;
      const next = (keep && left.find(d => d.uri === keep)) || left[Math.min(Math.max(idx, 0), left.length - 1)];
      if (next) useEditorStore.getState().setActive(next.uri);
    }
  }, [t]);

  const tabMenuItems = (uri: string): MenuItem[] => {
    const docs = useEditorStore.getState().documents;
    const doc = docs.find(d => d.uri === uri);
    const i = docs.findIndex(d => d.uri === uri);
    const unpinned = (list: typeof docs) => list.filter(d => !d.pinned).map(d => d.uri);
    const others = unpinned(docs.filter(d => d.uri !== uri));
    const right = unpinned(docs.slice(i + 1));
    const saved = unpinned(docs.filter(d => !d.dirty));
    const disk = doc?.diskPath;
    const root = projectRoot?.replace(/\\/g, '/').replace(/\/+$/, '');
    const norm = disk?.replace(/\\/g, '/');
    const rel = norm && root && norm.startsWith(root + '/') ? norm.slice(root.length + 1) : undefined;
    const copy = (text?: string) => { if (text) navigator.clipboard?.writeText(text).catch(() => {}); };
    return [
      { label: t('tabs.close'), onClick: () => closeMany([uri]) },
      { label: t('tabs.closeOthers'), disabled: !others.length, onClick: () => closeMany(others, uri) },
      { label: t('tabs.closeRight'), disabled: !right.length, onClick: () => closeMany(right, uri) },
      { label: t('tabs.closeSaved'), disabled: !saved.length, onClick: () => closeMany(saved, uri) },
      { label: t('tabs.closeAll'), disabled: !unpinned(docs).length, onClick: () => closeMany(unpinned(docs)) },
      'separator',
      { label: t('tabs.copyPath'), disabled: !disk, onClick: () => copy(disk) },
      { label: t('tabs.copyRelativePath'), disabled: !rel, onClick: () => copy(rel) },
      { label: IS_MAC ? t('fileTree.revealFinder') : IS_WIN ? t('fileTree.revealExplorer') : t('fileTree.revealFolder'),
        disabled: !disk, onClick: () => (window as any).files?.reveal?.(disk) },
      'separator',
      doc?.pinned
        ? { label: t('tabs.unpin'), onClick: () => setPinned(uri, false) }
        : { label: t('tabs.pin'), onClick: () => setPinned(uri, true) },
    ];
  };

  const onClose = useCallback((e: React.MouseEvent, uri: string) => {
    e.stopPropagation();
    const doc = documents.find(d=>d.uri===uri);
    if (doc?.dirty) {
      if (!window.confirm(t('dialog.unsavedChanges', 'File has unsaved changes. Close anyway?'))) return;
    }
    closeDocument(uri);
  }, [documents, closeDocument, t]);

  const onTabMouseDown = useCallback((e: React.MouseEvent, uri: string) => {
    // Botón central del ratón (rueda) - cerrar pestaña
    // (a pinned tab does not close by accident: its menu or its pin)
    if (e.button === 1 && !useEditorStore.getState().documents.find(d => d.uri === uri)?.pinned) {
      e.preventDefault();
      e.stopPropagation();
      onClose(e, uri);
    }
  }, [onClose]);

  // Determine if active document is a vector file or music file
  const activeDoc = documents.find(d => d.uri === active);
  const isVectorFile = active?.endsWith('.vec') || false;
  const isMusicFile = active?.endsWith('.vmus') || false;
  const isSfxFile = active?.endsWith('.vsfx') || false;
  const isAnimFile = active?.endsWith('.vanim') || false;
  const isInstrFile = active?.endsWith('.vinstr') || false;
  const isEnemyFile = active?.endsWith('.venemy') || false;
  const isVrecFile = active?.endsWith('.vrec') || false;
  const isVsmpFile = active?.endsWith('.vsmp') || false;
  const isVmovFile = active?.endsWith('.vmov') || false;
  const isMeshFile = active?.endsWith('.vmesh') || false;
  const isSceneFile = active?.endsWith('.vscene') || false;
  const isAnim3dFile = (active?.endsWith('.vclip') || active?.endsWith('.vskel')) || false;

  // Parse vector resource from document content
  const vectorResource = useMemo(() => {
    if (!isVectorFile || !activeDoc?.content) return undefined;
    try {
      return JSON.parse(activeDoc.content);
    } catch {
      return undefined;
    }
  }, [isVectorFile, activeDoc?.content]);

  // Parse music resource from document content
  const musicResource = useMemo(() => {
    if (!isMusicFile || !activeDoc?.content) return undefined;
    try {
      return JSON.parse(activeDoc.content);
    } catch {
      return undefined;
    }
  }, [isMusicFile, activeDoc?.content]);

  // Parse SFX resource from document content
  const sfxResource = useMemo(() => {
    if (!isSfxFile || !activeDoc?.content) return undefined;
    try {
      return JSON.parse(activeDoc.content);
    } catch {
      return undefined;
    }
  }, [isSfxFile, activeDoc?.content]);

  // Parse animation resource from document content
  const animResource = useMemo(() => {
    if (!isAnimFile || !activeDoc?.content) return undefined;
    try {
      return JSON.parse(activeDoc.content);
    } catch {
      return undefined;
    }
  }, [isAnimFile, activeDoc?.content]);

  // Parse instrument resource from document content
  const instrResource = useMemo(() => {
    if (!isInstrFile || !activeDoc?.content) return undefined;
    try { return JSON.parse(activeDoc.content); } catch { return undefined; }
  }, [isInstrFile, activeDoc?.content]);

  // Parse enemy resource from document content
  const enemyResource = useMemo(() => {
    if (!isEnemyFile || !activeDoc?.content) return undefined;
    try { return JSON.parse(activeDoc.content); } catch { return undefined; }
  }, [isEnemyFile, activeDoc?.content]);

  // Parse vector recording (.vrec) from document content — read-only viewer
  const vrecResource = useMemo(() => {
    if (!isVrecFile || !activeDoc?.content) return undefined;
    try { return JSON.parse(activeDoc.content); } catch { return undefined; }
  }, [isVrecFile, activeDoc?.content]);

  // Parse audio sample (.vsmp) from document content — read-only player
  const vsmpResource = useMemo(() => {
    if (!isVsmpFile || !activeDoc?.content) return undefined;
    try { return JSON.parse(activeDoc.content); } catch { return undefined; }
  }, [isVsmpFile, activeDoc?.content]);

  // Parse vector movie (.vmov) manifest from document content
  const vmovResource = useMemo(() => {
    if (!isVmovFile || !activeDoc?.content) return undefined;
    try { return JSON.parse(activeDoc.content); } catch { return undefined; }
  }, [isVmovFile, activeDoc?.content]);

  // Parse 3D mesh (.vmesh) from document content
  const meshResource = useMemo(() => {
    if (!isMeshFile || !activeDoc?.content) return undefined;
    try { return JSON.parse(activeDoc.content); } catch { return undefined; }
  }, [isMeshFile, activeDoc?.content]);

  // Parse 3D scene (.vscene) from document content
  // 3D animation (.vclip / .vskel) from document content
  const anim3dResource = useMemo(() => {
    if (!isAnim3dFile || !activeDoc?.content) return undefined;
    try { return JSON.parse(activeDoc.content); } catch { return undefined; }
  }, [isAnim3dFile, activeDoc?.content]);

  const sceneResource = useMemo(() => {
    if (!isSceneFile || !activeDoc?.content) return undefined;
    try { return JSON.parse(activeDoc.content); } catch { return undefined; }
  }, [isSceneFile, activeDoc?.content]);

  const handleMeshChange = useCallback((resource: any) => {
    if (!active) return;
    useEditorStore.getState().updateContent(active, JSON.stringify(resource, null, 2));
  }, [active]);

  // Handle vector movie manifest changes
  const handleVmovChange = useCallback((resource: any) => {
    if (!active) return;
    useEditorStore.getState().updateContent(active, JSON.stringify(resource, null, 2));
  }, [active]);

  // Handle vector editor changes
  const handleVectorChange = useCallback((resource: any) => {
    if (!active) return;
    const newContent = JSON.stringify(resource, null, 2);
    useEditorStore.getState().updateContent(active, newContent);
  }, [active]);

  // Handle music editor changes
  const handleMusicChange = useCallback((resource: any) => {
    if (!active) return;
    const newContent = JSON.stringify(resource, null, 2);
    useEditorStore.getState().updateContent(active, newContent);
  }, [active]);

  // Handle SFX editor changes
  const handleSfxChange = useCallback((resource: any) => {
    if (!active) return;
    const newContent = JSON.stringify(resource, null, 2);
    useEditorStore.getState().updateContent(active, newContent);
  }, [active]);

  // Handle animation editor changes
  const handleAnimChange = useCallback((resource: any) => {
    if (!active) return;
    const newContent = JSON.stringify(resource, null, 2);
    useEditorStore.getState().updateContent(active, newContent);
  }, [active]);

  // Handle instrument editor changes
  const handleInstrChange = useCallback((resource: any) => {
    if (!active) return;
    useEditorStore.getState().updateContent(active, JSON.stringify(resource, null, 2));
  }, [active]);

  // Handle enemy editor changes
  const handleEnemyChange = useCallback((resource: any) => {
    if (!active) return;
    useEditorStore.getState().updateContent(active, JSON.stringify(resource, null, 2));
  }, [active]);

  return (
    <div className="vpy-editor-surface">
      <div className="vpy-tab-bar">
        {visibleDocs.map(doc => {
          const title = deriveTitle(doc.uri);
          const isVec = doc.uri.endsWith('.vec');
          const isMus = doc.uri.endsWith('.vmus');
          const isSfx = doc.uri.endsWith('.vsfx');
          const isAnim = doc.uri.endsWith('.vanim');
          const isInstr = doc.uri.endsWith('.vinstr');
          const isEnemy = doc.uri.endsWith('.venemy');
          const isVrec = doc.uri.endsWith('.vrec');
          const isVsmp = doc.uri.endsWith('.vsmp');
          const isVmov = doc.uri.endsWith('.vmov');
          const isMesh = doc.uri.endsWith('.vmesh');
          const isScene = doc.uri.endsWith('.vscene');
          const isAnim3d = doc.uri.endsWith('.vclip') || doc.uri.endsWith('.vskel');
          const icon = isAnim3d ? '🦴' : isScene ? '🏞️' : isMesh ? '🧊' : isVmov ? '📽️' : isVrec ? '📼' : isVsmp ? '🎙️' : isEnemy ? '👾' : isInstr ? '🎹' : isAnim ? '🎬' : isSfx ? '🔊' : isMus ? '🎵' : isVec ? '🎨' : '📄';
          return (
            <div key={doc.uri}
              className={"vpy-tab" + (doc.uri===active?" active":"") + (doc.dirty?" dirty":"") + (doc.pinned?" pinned":"")}
              title={doc.diskPath ?? doc.uri}
              onClick={()=> setActive(doc.uri)}
              onMouseDown={(e)=> onTabMouseDown(e, doc.uri)}
              onContextMenu={(e)=> { e.preventDefault(); setTabMenu({ x: e.clientX, y: e.clientY, uri: doc.uri }); }}>
              <span className="icon">{icon}</span>
              <span className="title">{title}</span>
              {doc.pinned
                ? <button className="close pin" title={t('tabs.unpin')} onClick={(e)=>{ e.stopPropagation(); setPinned(doc.uri, false); }}>📌</button>
                : <button className="close" onClick={(e)=>onClose(e, doc.uri)}>×</button>}
            </div>
          );
        })}
      </div>
      {tabMenu && <FileTreeMenu x={tabMenu.x} y={tabMenu.y} items={tabMenuItems(tabMenu.uri)} onClose={() => setTabMenu(null)} />}
      <div className="vpy-editor-body">
        {!active ? (
          <WelcomeView />
        ) : isSfxFile ? (
          <div style={{ background: '#16213e', width: '100%', height: '100%', display: 'flex', justifyContent: 'center', alignItems: 'flex-start', paddingTop: 16 }}>
            <SFXEditor 
              resource={sfxResource} 
              onChange={handleSfxChange}
              width={600}
              height={500}
            />
          </div>
        ) : isMusicFile ? (
          <div style={{ background: '#1e1e2e', width: '100%', height: '100%', display: 'flex', flexDirection: 'column' }}>
            <MusicEditor 
              resource={musicResource} 
              onChange={handleMusicChange}
            />
          </div>
        ) : isVectorFile ? (
          <div style={{ background: '#1e1e1e', height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <VectorEditor
              resource={vectorResource}
              onChange={handleVectorChange}
            />
          </div>
        ) : isInstrFile ? (
          <div style={{ background: '#16213e', width: '100%', height: '100%', overflowY: 'auto' }}>
            <InstrumentEditor resource={instrResource} onChange={handleInstrChange} />
          </div>
        ) : isAnimFile ? (
          <div style={{ background: '#1a1a2e', height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <AnimationEditor resource={animResource} onChange={handleAnimChange} />
          </div>
        ) : isEnemyFile ? (
          <div style={{ background: '#12121e', height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <EnemyEditor resource={enemyResource} onChange={handleEnemyChange} />
          </div>
        ) : isVrecFile ? (
          <div style={{ background: '#0d0d14', height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <VrecViewer resource={vrecResource} />
          </div>
        ) : isVsmpFile ? (
          <div style={{ background: '#0d0d14', height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <VsmpPlayer resource={vsmpResource} />
          </div>
        ) : isVmovFile ? (
          <div style={{ background: '#0d0d14', height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <VectorMovieEditor resource={vmovResource} docUri={active} onChange={handleVmovChange} />
          </div>
        ) : isMeshFile ? (
          <div style={{ background: '#12121c', height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <MeshEditor key={active} resource={meshResource} docUri={active} onChange={handleMeshChange} />
          </div>
        ) : isAnim3dFile ? (
          <div style={{ background: '#12121c', height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <Anim3DEditor key={active} resource={anim3dResource} docUri={active} onChange={handleMeshChange} />
          </div>
        ) : isSceneFile ? (
          <div style={{ background: '#12121c', height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <SceneEditor key={active} resource={sceneResource} docUri={active} onChange={handleMeshChange} />
          </div>
        ) : (
          <MonacoEditorWrapper uri={active} />
        )}
      </div>
      <style>{editorSurfaceStyles}</style>
    </div>
  );
};

function deriveTitle(uri: string): string {
  if (uri.startsWith('file://')) {
    const parts = uri.split('/');
    return parts[parts.length-1] || 'file';
  }
  if (uri.startsWith('inmemory://')) {
    return uri.split('/').pop() || 'untitled';
  }
  return uri;
}

const editorSurfaceStyles = `
.vpy-editor-surface { display:flex; flex-direction:column; height:100%; width:100%; }
.vpy-tab-bar { display:flex; align-items:stretch; background:#1f1f1f; border-bottom:1px solid #333; overflow-x:auto; scrollbar-width:none; position:relative; }
.vpy-tab-bar::-webkit-scrollbar { display:none; }
.vpy-tab { position:relative; display:flex; align-items:center; gap:4px; padding:4px 12px 4px 8px; font-size:12px; cursor:pointer; color:#bbb; user-select:none; border-right:1px solid #2a2a2a; }
.vpy-tab.active { background:#2b2b2b; color:#eee; }
.vpy-tab:hover { background:#262626; }
.vpy-tab.dirty .title::after { content:'*'; color:#d8846b; margin-left:2px; }
.vpy-tab .icon { font-size:14px; }
.vpy-tab .close { background:transparent; border:none; color:#888; font-size:12px; cursor:pointer; padding:0 2px; }
.vpy-tab .close:hover { color:#fff; }
.vpy-tab .close.pin { font-size:10px; }
.vpy-tab.pinned { padding-right:8px; }
.vpy-editor-body { flex:1; position:relative; min-height:0; overflow:hidden; }
`;
