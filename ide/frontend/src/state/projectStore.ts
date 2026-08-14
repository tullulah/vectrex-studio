import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Project, FileNode } from '../types/models.js';
import { logger } from '../utils/logger.js';

// Lazy import to avoid circular dependency
let editorStoreRef: any = null;
const getEditorStore = () => {
  if (!editorStoreRef) {
    // Dynamic import would be better but for sync access we use a setter
  }
  return editorStoreRef;
};
export const setEditorStoreRef = (store: any) => { editorStoreRef = store; };
interface WorkspaceEntry {
  path: string;
  name: string;
  lastOpened: number;
  isProject?: boolean; // true if .vpyproj, false if just folder
  openFiles?: string[]; // List of open file URIs for this project
  activeFile?: string; // Last active file URI
}

/**
 * Project configuration structure (matches .vpyproj TOML)
 */
export interface ProjectConfig {
  project: {
    name: string;
    version: string;
    author?: string;
    description?: string;
    entry: string;
    // Discriminates an external C/C++ project (.cvproj) from a VPy project.
    // Absent / "game" / "library" => VPy project (default behaviour).
    type?: string;
    target?: string;
  };
  build: {
    output: string;
    target?: string;
    optimization?: number;
    debug_symbols?: boolean;
    // External C/C++ (.cvproj) build fields.
    command?: string;
    args?: string[];
    artifact?: string;
    deploy_extra?: string[];
  };
  sources?: {
    vpy?: string[];
    c?: string[];
    asm?: string[];
  };
  resources?: {
    vectors?: string[];
    music?: string[];
    sfx?: string[];
    data?: string[];
  };
  dependencies?: Record<string, string | { path?: string; version?: string }>;
}

/**
 * Loaded .vpyproj project
 */
export interface LoadedVpyProject {
  projectFile: string;
  rootDir: string;
  config: ProjectConfig;
  // True when this is an external C/C++ project (config.project.type === 'c-external').
  // VPy projects leave this falsy and behave exactly as before.
  isExternal?: boolean;
  // For external projects, the path to the .cvproj manifest (same as projectFile).
  manifestPath?: string;
  // Resolved build target (e.g. "pitrex") for external projects.
  target?: string;
}

interface ProjectState {
  // Current workspace (folder-based, legacy)
  project?: Project;
  selected?: string; // path
  workspaceName?: string;
  
  // Current .vpyproj project (new system)
  vpyProject?: LoadedVpyProject;
  
  // Recent workspaces/projects
  recentWorkspaces: WorkspaceEntry[];
  lastWorkspacePath?: string; // Remember last opened workspace
  
  // Actions
  setProject: (rootPath: string, files: FileNode[], name?: string) => void;
  selectFile: (path: string) => void;
  addRecentWorkspace: (path: string, name: string, isProject?: boolean) => void;
  clearWorkspace: () => void;
  clearRecentWorkspaces: () => void;
  hasWorkspace: () => boolean;
  refreshWorkspace: () => Promise<void>;
  restoreLastWorkspace: () => Promise<void>;
  
  // New project actions
  setVpyProject: (project: LoadedVpyProject | undefined) => void;
  openVpyProject: (projectFile: string) => Promise<boolean>;
  closeVpyProject: () => void;
  hasVpyProject: () => boolean;
  getEntryPath: () => string | null;
  getOutputPath: () => string | null;
  
  // Project state persistence
  saveProjectState: (projectPath: string, openFiles: string[], activeFile?: string) => void;
  getProjectState: (projectPath: string) => { openFiles: string[]; activeFile?: string } | null;
}

export const useProjectStore = create<ProjectState>()(
  persist(
    (set, get) => ({
      // Initial state
      project: undefined,
      selected: undefined,
      workspaceName: undefined,
      vpyProject: undefined,
      recentWorkspaces: [],
      lastWorkspacePath: undefined,
      
      // Actions
      setProject: (rootPath, files, name) => {
        const workspaceName = name || rootPath.split(/[/\\]/).pop() || 'Workspace';
        logger.debug('Project', 'Setting project', { rootPath, workspaceName, filesCount: files.length });
        logger.debug('Project', 'Files structure:', files);
        set({ 
          project: { rootPath, files }, 
          workspaceName,
          selected: undefined,
          lastWorkspacePath: rootPath // Save as last workspace
        });
        get().addRecentWorkspace(rootPath, workspaceName, false);
      },
      
      selectFile: (path) => set({ selected: path }),
      
      addRecentWorkspace: (path, name, isProject = false) => {
        const recent = get().recentWorkspaces;
        const filtered = recent.filter(w => w.path !== path);
        const newEntry: WorkspaceEntry = { path, name, lastOpened: Date.now(), isProject };
        logger.debug('Project', 'Adding recent workspace', newEntry);
        set({ 
          recentWorkspaces: [newEntry, ...filtered].slice(0, 10) // Keep last 10
        });
        logger.debug('Project', 'Recent workspaces now:', get().recentWorkspaces);
      },
      
      clearWorkspace: () => set({ 
        project: undefined, 
        selected: undefined, 
        workspaceName: undefined 
      }),
      
      clearRecentWorkspaces: () => {
        logger.debug('Project', 'Clearing recent workspaces');
        set({ recentWorkspaces: [] });
      },
      
      hasWorkspace: () => !!get().project,
      
      refreshWorkspace: async () => {
        const current = get().project;
        if (!current) return;
        
        try {
          const result = await (window as any).files?.readDirectory?.(current.rootPath);
          if (result?.files) {
            logger.debug('Project', 'Refreshing workspace files');
            set({ 
              project: { 
                rootPath: current.rootPath, 
                files: result.files 
              } 
            });
          }
        } catch (error) {
          logger.error('Project', 'Failed to refresh workspace:', error);
        }
      },
      
      restoreLastWorkspace: async () => {
        const lastPath = get().lastWorkspacePath;
        const recentWorkspaces = get().recentWorkspaces;
        
        // First, check if there's a recent .vpyproj project to restore
        const lastProject = recentWorkspaces.find(w => w.isProject);
        if (lastProject) {
          logger.debug('Project', 'Restoring last project:', lastProject.path);
          try {
            const success = await get().openVpyProject(lastProject.path);
            if (success) {
              logger.info('Project', 'Successfully restored project:', lastProject.name);
              
              // CRITICAL: Restore previously open files after project loads
              const savedState = get().getProjectState(lastProject.path);
              if (savedState && savedState.openFiles.length > 0 && editorStoreRef) {
                logger.info('Project', `Restoring ${savedState.openFiles.length} open files from last session`);
                
                const apiFiles = (window as any).files;
                if (apiFiles?.readFile) {
                  for (const uri of savedState.openFiles) {
                    // Extract disk path from URI
                    let diskPath = uri.replace('file:///', '').replace('file://', '');
                    if (diskPath.match(/^[A-Za-z]:\//)) {
                      // Windows path - keep as is
                    } else if (!diskPath.startsWith('/')) {
                      diskPath = '/' + diskPath;
                    }
                    
                    try {
                      const fileResult = await apiFiles.readFile(diskPath);
                      if (fileResult && !fileResult.error) {
                        editorStoreRef.getState().openDocument({
                          uri,
                          language: diskPath.endsWith('.vpy') ? 'vpy' : 'plaintext',
                          content: fileResult.content,
                          dirty: false,
                          diagnostics: [],
                          diskPath,
                          mtime: fileResult.mtime,
                          lastSavedContent: fileResult.content
                        });
                      }
                    } catch (e) {
                      logger.warn('Project', `Could not restore file: ${diskPath}`);
                    }
                  }
                  
                  // Set the last active file
                  if (savedState.activeFile) {
                    editorStoreRef.getState().setActive(savedState.activeFile);
                  }
                }
              }
              
              return;
            }
          } catch (error) {
            logger.warn('Project', 'Failed to restore project, trying workspace fallback');
          }
        }
        
        // Fallback to regular workspace
        if (!lastPath) return;
        
        try {
          logger.debug('Project', 'Restoring last workspace:', lastPath);
          const result = await (window as any).files?.readDirectory?.(lastPath);
          if (result?.files) {
            const workspaceName = lastPath.split(/[/\\]/).pop() || 'Workspace';
            set({ 
              project: { rootPath: lastPath, files: result.files }, 
              workspaceName,
              selected: undefined 
            });
            logger.info('Project', 'Successfully restored workspace:', workspaceName);
          } else {
            logger.warn('Project', 'Failed to restore workspace - directory not accessible');
            // Clear invalid last workspace
            set({ lastWorkspacePath: undefined });
          }
        } catch (error) {
          logger.error('Project', 'Error restoring last workspace:', error);
          // Clear invalid last workspace
          set({ lastWorkspacePath: undefined });
        }
      },
      
      // New .vpyproj project functions
      setVpyProject: (project) => {
        set({ vpyProject: project });
        if (project) {
          // Update window title
          document.title = `${project.config.project.name} - Vectrex Studio`;
          // Add to recents
          get().addRecentWorkspace(project.projectFile, project.config.project.name, true);
        } else {
          document.title = 'Vectrex Studio';
        }
      },
      
      openVpyProject: async (projectFile: string) => {
        const projectAPI = (window as any).project;
        if (!projectAPI) {
          logger.error('Project', 'Project API not available');
          return false;
        }
        
        try {
          const result = await projectAPI.read(projectFile);
          
          if ('error' in result) {
            logger.error('Project', 'Failed to open project:', result.error);
            return false;
          }
          
          const config = result.config as ProjectConfig;
          const isExternal = config.project?.type === 'c-external';
          const loaded: LoadedVpyProject = {
            projectFile: result.path,
            rootDir: result.rootDir,
            config,
            isExternal,
            manifestPath: isExternal ? result.path : undefined,
            target: isExternal ? config.project?.target : undefined,
          };

          get().setVpyProject(loaded);

          // Store project path globally for breakpoint persistence
          (window as any).__currentProjectPath__ = result.path;

          // External C/C++ projects have no VPy sources: skip breakpoints, PDB
          // and debug-symbol loading (Phase 1 is build & deploy only).
          if (isExternal) {
            // Set workspace/file explorer to the manifest's folder and return.
            const extFiles = await (window as any).files?.readDirectory?.(loaded.rootDir);
            if (extFiles?.files) {
              set({
                project: { rootPath: loaded.rootDir, files: extFiles.files },
                workspaceName: loaded.config.project.name,
                lastWorkspacePath: loaded.rootDir
              });
            }
            logger.info('Project', 'Opened external C/C++ project:', loaded.config.project.name);
            return true;
          }

          // Load breakpoints from database for this project
          if (typeof (window as any).__editorStore__ !== 'undefined') {
            const editorStore = (window as any).__editorStore__.getState();
            if (editorStore.loadBreakpointsFromDb) {
              editorStore.loadBreakpointsFromDb(result.path).catch((err: any) => {
                logger.error('Project', 'Failed to load breakpoints:', err);
              });
            }
          }

          // Load existing PDB file if available
          const debugAPI = (window as any).debug;
          if (debugAPI && result.config.project.entry) {
            const mainFile = `${result.rootDir}/src/${result.config.project.entry}`;
            debugAPI.loadPdb(mainFile).then((pdbResult: any) => {
              if (pdbResult.success && pdbResult.pdbData) {
                logger.info('Project', 'Auto-loaded debug symbols from existing .pdb file');
                const { useDebugStore } = require('./debugStore');
                useDebugStore.getState().loadPdbData(pdbResult.pdbData);
              } else {
                logger.debug('Project', 'No existing .pdb file found (compile to generate)');
              }
            }).catch((err: any) => {
              logger.debug('Project', 'Could not load PDB:', err);
            });
          }
          
          // Also set as workspace for file explorer
          const files = await (window as any).files?.readDirectory?.(loaded.rootDir);
          if (files?.files) {
            set({
              project: { rootPath: loaded.rootDir, files: files.files },
              workspaceName: loaded.config.project.name,
              lastWorkspacePath: loaded.rootDir
            });
          }
          
          logger.info('Project', 'Opened project:', loaded.config.project.name);
          return true;
        } catch (e: any) {
          logger.error('Project', 'Failed to open project:', e.message);
          return false;
        }
      },
      
      closeVpyProject: () => {
        const { vpyProject, saveProjectState } = get();
        
        // Save current open files before closing
        if (vpyProject && editorStoreRef) {
          const { documents, active } = editorStoreRef.getState();
          const openFiles = documents
            .filter((d: any) => d.diskPath) // Only files on disk
            .map((d: any) => d.uri);
          saveProjectState(vpyProject.projectFile, openFiles, active);
        }
        
        // Clear both vpyProject and the workspace/file tree
        set({ 
          vpyProject: undefined,
          project: { rootPath: '', files: [] },
          workspaceName: undefined,
          selected: undefined,
        });
        document.title = 'Vectrex Studio';
        logger.info('Project', 'Project and workspace closed');
      },
      
      hasVpyProject: () => !!get().vpyProject,
      
      getEntryPath: () => {
        const { vpyProject } = get();
        if (!vpyProject) return null;
        
        const entry = vpyProject.config.project.entry;
        const rootDir = vpyProject.rootDir.replace(/\\/g, '/');
        const entryPath = entry.replace(/\\/g, '/');
        
        if (entryPath.startsWith('/') || entryPath.match(/^[A-Z]:/i)) {
          return entryPath;
        }
        
        return `${rootDir}/${entryPath}`;
      },
      
      getOutputPath: () => {
        const { vpyProject } = get();
        if (!vpyProject) return null;
        
        if (!vpyProject.config.build?.output) return null;
        const output = vpyProject.config.build.output;
        const rootDir = vpyProject.rootDir.replace(/\\/g, '/');
        const outputPath = output.replace(/\\/g, '/');
        
        if (outputPath.startsWith('/') || outputPath.match(/^[A-Z]:/i)) {
          return outputPath;
        }
        
        return `${rootDir}/${outputPath}`;
      },
      
      // Save open files state for a project
      saveProjectState: (projectPath: string, openFiles: string[], activeFile?: string) => {
        const recents = get().recentWorkspaces;
        const updated = recents.map(w => 
          w.path === projectPath 
            ? { ...w, openFiles, activeFile, lastOpened: Date.now() }
            : w
        );
        set({ recentWorkspaces: updated });
        logger.debug('Project', 'Saved project state', { projectPath, openFiles: openFiles.length, activeFile });
      },
      
      // Get saved state for a project
      getProjectState: (projectPath: string) => {
        const recents = get().recentWorkspaces;
        const project = recents.find(w => w.path === projectPath);
        if (project?.openFiles) {
          return { 
            openFiles: project.openFiles, 
            activeFile: project.activeFile 
          };
        }
        return null;
      },
    }),
    {
      name: 'vpy-workspace-storage',
      partialize: (state) => ({ 
        recentWorkspaces: state.recentWorkspaces.map(w => ({
          path: w.path,
          name: w.name,
          lastOpened: w.lastOpened,
          isProject: w.isProject,
          openFiles: w.openFiles,
          activeFile: w.activeFile
        })),
        lastWorkspacePath: state.lastWorkspacePath
      })
    }
  )
);

// Expose store globally for MCP server access
if (typeof window !== 'undefined') {
  (window as any).__projectStore__ = useProjectStore;
}
