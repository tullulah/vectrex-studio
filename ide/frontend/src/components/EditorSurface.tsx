import React, { useCallback, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { useEditorStore } from '../state/editorStore';
import { useProjectStore } from '../state/projectStore';
import { WelcomeView } from './WelcomeView';
import { MonacoEditorWrapper } from './MonacoEditorWrapper';
import { VectorEditor } from './VectorEditor';
import { MusicEditor } from './MusicEditor';
import { SFXEditor } from './SFXEditor';

// Basic custom tab bar replacing flexlayout doc:* logic.
// Phase 1: single group, order = documents array order.

export const EditorSurface: React.FC = () => {
  const { t } = useTranslation(['common']);
  const documents = useEditorStore(s=>s.documents);
  const active = useEditorStore(s=>s.active);
  const setActive = useEditorStore(s=>s.setActive);
  const closeDocument = useEditorStore(s=>s.closeDocument);
  const hasWorkspace = useProjectStore(s=>s.hasWorkspace());
  const visibleDocs = documents; // all docs now visible (no hide/pin)

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
    if (e.button === 1) {
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

  return (
    <div className="vpy-editor-surface">
      <div className="vpy-tab-bar">
        {visibleDocs.map(doc => {
          const title = deriveTitle(doc.uri);
          const isVec = doc.uri.endsWith('.vec');
          const isMus = doc.uri.endsWith('.vmus');
          const isSfx = doc.uri.endsWith('.vsfx');
          const icon = isSfx ? '🔊' : isMus ? '🎵' : isVec ? '🎨' : '📄';
          return (
            <div key={doc.uri}
              className={"vpy-tab" + (doc.uri===active?" active":"") + (doc.dirty?" dirty":"")}
              title={doc.uri}
              onClick={()=> setActive(doc.uri)}
              onMouseDown={(e)=> onTabMouseDown(e, doc.uri)}>
              <span className="icon">{icon}</span>
              <span className="title">{title}</span>
              <button className="close" onClick={(e)=>onClose(e, doc.uri)}>×</button>
            </div>
          );
        })}
      </div>
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
.vpy-editor-body { flex:1; position:relative; min-height:0; overflow:hidden; }
`;
