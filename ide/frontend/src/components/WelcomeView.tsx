import React, { useEffect, useState } from 'react';
import { useEditorStore } from '../state/editorStore.js';
import { useProjectStore } from '../state/projectStore.js';
import type { FileNode } from '../types/models.js';

interface RecentEntry { path: string; mtime?: number; }

export const WelcomeView: React.FC = () => {
  return (
    <div className="vpy-welcome-root">
      <Branding />
      <QuickActions />
      <RecentList />
    </div>
  );
};

const Branding: React.FC = () => {
  return (
    <div className="vpy-welcome-branding">
      <div className="title">Vectrex Studio</div>
      <div className="subtitle">Bienvenido al IDE. Abre un workspace, carpeta o crea un archivo nuevo.</div>
    </div>
  );
};

// Workspace helper functions using Electron APIs
const openWorkspaceWithElectron = async (setProject: any) => {
  try {
    // Use Electron's native folder picker
    const result = await (window as any).files?.openFolder?.();
    if (!result || !result.path) {
      console.log('No folder selected');
      return;
    }
    
    const folderPath = result.path;
    const folderName = folderPath.split(/[/\\]/).pop() || 'Workspace';
    
    console.log('Opening workspace:', folderPath);
    
    // Read directory structure using Electron API
    const dirResult = await (window as any).files?.readDirectory?.(folderPath);
    if (dirResult?.error) {
      console.error('Error reading directory:', dirResult.error);
      return;
    }
    
    if (!dirResult?.files) {
      console.warn('No files returned from directory read');
      return;
    }
    
    console.log('Directory read result:', dirResult.files.length, 'items');
    
    // Set the workspace with the file structure
    setProject(folderPath, dirResult.files, folderName);
    
  } catch (error) {
    console.error('Error opening workspace:', error);
  }
};

const openWorkspaceDialog = async (setProject: any) => {
  // Check if we're in Electron
  const isElectron = !!(window as any).electronAPI;
  
  if (isElectron) {
    // Use native Electron APIs
    await openWorkspaceWithElectron(setProject);
  } else {
    // Fallback to browser APIs (for development)
    console.warn('Running in browser mode - using fallback file picker');
    try {
      const input = document.createElement('input');
      input.type = 'file';
      input.webkitdirectory = true;
      input.multiple = true;
      input.style.display = 'none';
      
      const selectedFiles = await new Promise<FileList | null>((resolve) => {
        input.onchange = (e: any) => resolve(e.target.files);
        input.oncancel = () => resolve(null);
        document.body.appendChild(input);
        input.click();
        setTimeout(() => {
          if (document.body.contains(input)) {
            document.body.removeChild(input);
          }
        }, 100);
      });
      
      if (selectedFiles && selectedFiles.length > 0) {
        // Simple browser fallback - just show file names
        const fileList = Array.from(selectedFiles).map(f => ({
          name: f.name,
          path: f.webkitRelativePath,
          isDir: false
        }));
        const folderName = selectedFiles[0].webkitRelativePath.split('/')[0];
        setProject(`/${folderName}`, fileList, folderName);
      }
    } catch (error) {
      console.warn('Error opening workspace:', error);
    }
  }
};

const QuickActions: React.FC = () => {
  const { setProject } = useProjectStore();
  
  const newVpyFile = () => {
    try {
      const st = (useEditorStore as any).getState();
      let idx = 1; let uri: string;
      while (true) { uri = `inmemory://untitled-${idx}.vpy`; if (!st.documents.some((d:any)=>d.uri===uri)) break; idx++; }
      st.openDocument({ uri, language:'vpy', content:'META MUSIC = music1\n\n# New VPy file\n\ndef main():\n    # Initialization\n    Set_Intensity(127)\n\ndef loop():\n    # Game loop\n    Wait_Recal()\n', dirty:true, diagnostics:[], lastSavedContent:'' });
    } catch {}
  };

  const newVecFile = () => {
    try {
      const st = (useEditorStore as any).getState();
      let idx = 1; let uri: string;
      while (true) { uri = `inmemory://untitled-${idx}.vec`; if (!st.documents.some((d:any)=>d.uri===uri)) break; idx++; }
      const defaultVec = {
        version: '1.0',
        name: 'untitled',
        author: '',
        created: new Date().toISOString(),
        canvas: { width: 256, height: 256, origin: 'center' },
        layers: [{ name: 'drawing', visible: true, paths: [] }],
        animations: [],
        metadata: { hitbox: null, origin: null, tags: [] },
      };
      st.openDocument({ uri, language:'json', content: JSON.stringify(defaultVec, null, 2), dirty:true, diagnostics:[], lastSavedContent:'' });
    } catch {}
  };

  const newMusicFile = () => {
    try {
      const st = (useEditorStore as any).getState();
      let idx = 1; let uri: string;
      while (true) { uri = `inmemory://untitled-${idx}.vmus`; if (!st.documents.some((d:any)=>d.uri===uri)) break; idx++; }
      const defaultMusic = {
        version: '1.0',
        name: 'Untitled',
        author: '',
        tempo: 120,
        ticksPerBeat: 24,
        totalTicks: 384,
        notes: [],
        noise: [],
        loopStart: 0,
        loopEnd: 384,
      };
      st.openDocument({ uri, language:'json', content: JSON.stringify(defaultMusic, null, 2), dirty:true, diagnostics:[], lastSavedContent:'' });
    } catch {}
  };

  const openWorkspace = () => openWorkspaceDialog(setProject);
  
  const newProject = () => {
    // Dispatch command to open new project dialog
    window.dispatchEvent(new CustomEvent('vpy-command', { detail: { command: 'project.new' } }));
  };
  
  const openProject = () => {
    window.dispatchEvent(new CustomEvent('vpy-command', { detail: { command: 'project.open' } }));
  };

  return (
    <div className="vpy-welcome-actions">
      <div className="vpy-action-group">
        <div className="group-title">Proyecto</div>
        <button className="vpy-btn primary" onClick={newProject}>🎮 Nuevo Proyecto...</button>
        <button className="vpy-btn" onClick={openProject}>📂 Abrir Proyecto...</button>
      </div>
      <div className="vpy-action-group">
        <div className="group-title">Workspace</div>
        <button className="vpy-btn" onClick={openWorkspace}>📁 Abrir Carpeta...</button>
      </div>
      <div className="vpy-action-group">
        <div className="group-title">Archivo</div>
        <button className="vpy-btn" onClick={() => { try { (window as any).files?.openFile?.(); } catch {} }}>📄 Abrir archivo...</button>
        <button className="vpy-btn" onClick={newVpyFile}>✨ Nuevo archivo VPy</button>
        <button className="vpy-btn" onClick={newVecFile}>🎨 Nuevo archivo Vector</button>
        <button className="vpy-btn" onClick={newMusicFile}>🎵 Nuevo archivo Música</button>
      </div>
    </div>
  );
};

const RecentList: React.FC = () => {
  const { recentWorkspaces, setProject, clearRecentWorkspaces } = useProjectStore();
  const [recentFiles, setRecentFiles] = useState<RecentEntry[]>([]);
  
  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const arr = await (window as any).api?.recents?.load?.();
        if (mounted && Array.isArray(arr)) setRecentFiles(arr.slice(0, 5)); // Limit files to 5
      } catch {}
    })();
    return () => { mounted = false; };
  }, []);

  const openRecentWorkspace = async (workspaceEntry: { path: string; name: string }) => {
    try {
      console.log('Attempting to open recent workspace:', workspaceEntry);
      
      const isElectron = !!(window as any).electronAPI;
      
      if (isElectron) {
        // In Electron, we can directly reopen the folder!
        console.log('Opening recent workspace directly:', workspaceEntry.path);
        
        // Read directory structure using Electron API
        const dirResult = await (window as any).files?.readDirectory?.(workspaceEntry.path);
        if (dirResult?.error) {
          console.error('Error reading recent workspace directory:', dirResult.error);
          // Fallback to folder picker if path no longer exists
          await openWorkspaceDialog(setProject);
          return;
        }
        
        if (!dirResult?.files) {
          console.warn('No files returned from recent workspace');
          return;
        }
        
        console.log('Successfully reopened recent workspace with', dirResult.files.length, 'items');
        
        // Set the workspace with the file structure
        setProject(workspaceEntry.path, dirResult.files, workspaceEntry.name);
        
      } else {
        // Browser fallback - still need to ask user to select folder
        console.log('Browser mode - asking user to select folder again');
        await openWorkspaceDialog(setProject);
      }
    } catch (error) {
      console.warn('Error opening recent workspace:', error);
      // Fallback to folder picker
      await openWorkspaceDialog(setProject);
    }
  };

  const hasRecents = recentWorkspaces.length > 0 || recentFiles.length > 0;
  if (!hasRecents) return null;

  return (
    <div className="vpy-welcome-recents">
      {recentWorkspaces.length > 0 && (
        <div className="recent-section">
          <div className="heading">
            📁 Workspaces Recientes
            <button 
              className="clear-history-btn" 
              onClick={() => {
                if (confirm('¿Estás seguro de que quieres limpiar el historial de workspaces?')) {
                  clearRecentWorkspaces();
                }
              }}
              title="Limpiar historial"
            >
              🗑️
            </button>
          </div>
          <div className="list">
            {recentWorkspaces.slice(0, 5).map(w => (
              <button 
                key={w.path} 
                className="vpy-recent-item workspace" 
                title={w.path} 
                onClick={() => openRecentWorkspace(w)}
              >
                <span className="file">📁 {w.name}</span>
                <span className="parent">{w.path}</span>
              </button>
            ))}
          </div>
        </div>
      )}
      
      {recentFiles.length > 0 && (
        <div className="recent-section">
          <div className="heading">📄 Archivos Recientes</div>
          <div className="list">
            {recentFiles.map(r => {
              const parts = r.path.split(/[/\\]/);
              const file = parts.pop() || r.path;
              const parent = parts.slice(-1)[0] || '';
              return (
                <button 
                  key={r.path} 
                  className="vpy-recent-item file" 
                  title={r.path} 
                  onClick={() => {
                    try { (window as any).api?.files?.openFilePath?.(r.path); } catch {}
                  }}
                >
                  <span className="file">📄 {file}</span>
                  {parent && <span className="parent">{parent}</span>}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};

// Local styles (scoped via class names)
// You can migrate to a CSS/SCSS file later if preferred.
export const welcomeStyles = `
.vpy-welcome-root { display:flex; flex-direction:column; align-items:center; justify-content:center; height:100%; gap:32px; color:#bbb; font-size:14px; padding:20px; }
.vpy-welcome-branding { text-align:center; }
.vpy-welcome-branding .title { font-size:48px; font-weight:300; letter-spacing:1px; color:#4fc1ff; margin-bottom:6px;}
.vpy-welcome-branding .subtitle { font-size:16px; color:#aaa; }

.vpy-welcome-actions { display:flex; gap:24px; flex-wrap:wrap; justify-content:center; }
.vpy-action-group { display:flex; flex-direction:column; gap:8px; min-width:180px; }
.vpy-action-group .group-title { font-size:12px; font-weight:600; color:#666; text-transform:uppercase; letter-spacing:1px; margin-bottom:4px; text-align:center; }
.vpy-btn { background:#1e1e1e; border:1px solid #333; color:#d0d0d0; padding:10px 16px; border-radius:6px; cursor:pointer; font-size:13px; transition:all 0.2s; }
.vpy-btn:hover { background:#252525; border-color:#444; }
.vpy-btn.primary { background:#0e639c; border-color:#1177bb; color:#fff; }
.vpy-btn.primary:hover { background:#1177bb; border-color:#1e88cc; }

.vpy-welcome-recents { max-width:600px; width:100%; }
.vpy-welcome-recents .recent-section { margin-bottom:24px; }
.vpy-welcome-recents .heading { text-transform:uppercase; font-size:11px; letter-spacing:1px; color:#666; margin-bottom:8px; display:flex; justify-content:space-between; align-items:center; }
.clear-history-btn { background:transparent; border:1px solid #444; color:#666; padding:4px 8px; border-radius:4px; cursor:pointer; font-size:10px; transition:all 0.2s; }
.clear-history-btn:hover { background:#2a2a2a; color:#aaa; border-color:#666; }
.vpy-welcome-recents .list { display:flex; flex-direction:column; gap:4px; }
.vpy-recent-item { text-align:left; background:#171717; border:1px solid #262626; color:#d0d0d0; padding:10px 14px; border-radius:6px; cursor:pointer; font-size:13px; display:flex; justify-content:space-between; align-items:center; transition:all 0.2s; }
.vpy-recent-item:hover { background:#1f1f1f; border-color:#333; }
.vpy-recent-item.workspace:hover { border-color:#0e639c; }
.vpy-recent-item.file:hover { border-color:#4fc1ff; }
.vpy-recent-item .file { font-weight:500; }
.vpy-recent-item .parent { font-size:11px; color:#666; margin-left:12px; text-overflow:ellipsis; overflow:hidden; white-space:nowrap; max-width:300px; }
`;