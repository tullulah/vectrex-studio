import React, { useState, useEffect, useRef } from 'react';
import { useProjectStore } from '../../state/projectStore';
import { useEditorStore } from '../../state/editorStore';
import type { FileNode } from '../../types/models';

// Helper function to detect language from file extension
function getLanguageFromFilename(filename: string): 'vpy' | 'c' | 'cpp' | 'json' | 'plaintext' | 'asm' | 'javascript' | 'typescript' | 'markdown' {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  switch (ext) {
    case 'vpy': return 'vpy';
    case 'c': return 'c';
    case 'cpp': case 'cc': case 'cxx': return 'cpp';
    case 'h': case 'hpp': return 'cpp';
    case 'asm': case 's': return 'asm';
    case 'json': case 'vec': case 'vmus': case 'vmesh': case 'vscene': case 'vskel': case 'vclip': return 'json';
    case 'js': return 'javascript';
    case 'ts': return 'typescript';
    case 'md': return 'markdown';
    default: return 'plaintext';
  }
}

// Helper function to normalize file paths to proper file:// URIs (same logic as File > Open)
function normalizeFileUri(path: string): string {
  console.log('[TreeView] normalizeFileUri input path:', path);
  const normPath = path.replace(/\\/g, '/');
  console.log('[TreeView] normPath after replace:', normPath);
  let result: string;
  if (normPath.match(/^[A-Za-z]:\//)) {
    // Windows absolute path like C:/path/file.ext
    result = `file:///${normPath}`;
    console.log('[TreeView] Windows absolute path detected, result:', result);
  } else if (normPath.startsWith('/')) {
    // Unix absolute path like /path/file.ext  
    result = `file://${normPath}`;
    console.log('[TreeView] Unix absolute path detected, result:', result);
  } else {
    // Relative path - should not happen normally but handle it
    result = `file://${normPath}`;
    console.log('[TreeView] Relative path detected, result:', result);
  }
  return result;
}

export const FileTreePanel: React.FC = () => {
  const { project, workspaceName, selectFile, hasWorkspace, refreshWorkspace, vpyProject } = useProjectStore();
  const { openDocument, closeDocument, documents, active } = useEditorStore();
  const [expandedDirs, setExpandedDirs] = useState<Set<string>>(new Set());
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [selectedFiles, setSelectedFiles] = useState<Set<string>>(new Set());
  const [hoveredFile, setHoveredFile] = useState<string | null>(null);
  const [draggedFiles, setDraggedFiles] = useState<Set<string>>(new Set());
  const [lastClickedFile, setLastClickedFile] = useState<string | null>(null);

  // Determine display name - prefer .vpyproj project name
  const displayName = vpyProject?.config?.project?.name || workspaceName || 'Workspace';
  const isVpyProject = !!vpyProject;
  const projectVersion = vpyProject?.config?.project?.version;

  // Helper function to convert file:// URI back to relative path within workspace
  const uriToRelativePath = (uri: string, workspaceRoot: string): string => {
    // First convert URI to absolute filesystem path
    let absolutePath: string;
    if (uri.startsWith('file:///')) {
      // file:///C:/path/file.ext -> C:/path/file.ext (Windows)
      // file:///path/file.ext -> /path/file.ext (macOS/Linux)
      absolutePath = uri.slice(7); // Remove 'file://' keeping the leading /
      // On Windows, we have file:///C:/... so we need to remove one more /
      if (absolutePath.match(/^\/[A-Za-z]:\//)) {
        absolutePath = absolutePath.slice(1); // Remove leading / for Windows paths
      }
    } else if (uri.startsWith('file://')) {
      absolutePath = uri.slice(7); // Remove 'file://'
    } else {
      absolutePath = uri; // fallback
    }
    
    // Normalize all paths to forward slashes for comparison
    const normalizedWorkspace = workspaceRoot.replace(/\\/g, '/');
    const normalizedAbsolute = absolutePath.replace(/\\/g, '/');
    
    if (normalizedAbsolute.startsWith(normalizedWorkspace)) {
      // Remove workspace root and leading slash
      let relativePath = normalizedAbsolute.slice(normalizedWorkspace.length);
      if (relativePath.startsWith('/')) {
        relativePath = relativePath.slice(1);
      }
      return relativePath;
    }
    
    // If not within workspace, return the normalized absolute path
    return normalizedAbsolute;
  };

  // Sync TreeView selection with active document tab
  // Use a ref to access project without causing re-renders
  const projectRef = useRef(project);
  projectRef.current = project;
  
  useEffect(() => {
    const currentProject = projectRef.current;
    console.log('[FileTree Sync] active:', active, 'rootPath:', currentProject?.rootPath);
    
    if (!currentProject?.files || !currentProject?.rootPath) {
      console.log('[FileTree Sync] No project files or rootPath');
      return;
    }
    
    // If no active document, clear selection but keep expanded dirs
    if (!active) {
      setSelectedFiles(new Set());
      return;
    }
    
    const activePath = uriToRelativePath(active, currentProject.rootPath);
    console.log('[FileTree Sync] Converted path:', activePath);
    
    // Find the file node that matches the active document
    const findFileInTree = (files: any[], targetPath: string): any => {
      for (const file of files) {
        // Normalize paths for comparison
        const normalizedFilePath = file.path.replace(/\\/g, '/');
        const normalizedTarget = targetPath.replace(/\\/g, '/');
        if (normalizedFilePath === normalizedTarget) {
          return file;
        }
        if (file.children) {
          const found = findFileInTree(file.children, targetPath);
          if (found) return found;
        }
      }
      return null;
    };

    const activeFile = findFileInTree(currentProject.files, activePath);
    console.log('[FileTree Sync] Found file:', activeFile?.path);
    
    if (activeFile) {
      setSelectedFiles(new Set([activeFile.path]));
      
      // Auto-expand parent directories to make the selected file visible
      // Use functional update to preserve existing expanded dirs
      setExpandedDirs(prev => {
        const parts = activeFile.path.replace(/\\/g, '/').split('/');
        const newExpanded = new Set(prev);
        let currentPath = '';
        for (let i = 0; i < parts.length - 1; i++) {
          currentPath = currentPath ? `${currentPath}/${parts[i]}` : parts[i];
          newExpanded.add(currentPath);
        }
        return newExpanded;
      });
    } else {
      // File not in tree - might be an in-memory file, don't change selection
      console.log('[FileTree Sync] File not found in tree');
    }
  }, [active]); // Only depend on active to avoid resetting on refresh

  // Auto-expand root directory when workspace loads
  useEffect(() => {
    if (project?.rootPath && !expandedDirs.has(project.rootPath)) {
      setExpandedDirs(prev => new Set([...prev, project.rootPath]));
    }
  }, [project?.rootPath]);

  // Set up file watcher when workspace loads
  useEffect(() => {
    if (!project?.rootPath) return;
    
    let isSubscribed = true;
    
    let cleanupListener: (() => void) | null = null;
    let refreshTimer: ReturnType<typeof setTimeout> | null = null;
    
    const setupWatcher = async () => {
      try {
        const w = window as any;
        if (w.files?.watchDirectory && w.files?.onFileChanged) {
          // Start watching the directory
          await w.files.watchDirectory(project.rootPath);
          console.log('FileTreePanel: Started watching', project.rootPath);
          
          // Set up change listener
          const handleFileChange = (event: { type: 'added' | 'removed' | 'changed'; path: string; isDir: boolean }) => {
            if (!isSubscribed) return;
            console.log('FileTreePanel: File change detected:', event);
            
            // If a file changed, check if it's open in the editor and reload it
            if (event.type === 'changed' && !event.isDir) {
              const editorStore = (window as any).__editorStore__;
              if (editorStore) {
                const state = editorStore.getState();
                const changedDoc = state.documents.find((d: any) => d.diskPath?.endsWith(event.path));
                
                if (changedDoc && !changedDoc.dirty) {
                  console.log('FileTreePanel: Reloading changed file:', event.path);
                  const w = window as any;
                  if (w.files?.readFile) {
                    w.files.readFile(changedDoc.diskPath).then((result: any) => {
                      if (!result.error && result.content !== undefined) {
                        // Update content
                        state.updateContent(changedDoc.uri, result.content);
                        
                        // Mark as not dirty and update lastSavedContent since this is the disk version
                        editorStore.setState((s: any) => ({
                          documents: s.documents.map((doc: any) =>
                            doc.uri === changedDoc.uri
                              ? { ...doc, dirty: false, lastSavedContent: result.content, mtime: result.mtime }
                              : doc
                          )
                        }));
                        
                        console.log('FileTreePanel: ✓ Reloaded', changedDoc.uri);
                      }
                    }).catch((error: any) => {
                      console.error('FileTreePanel: Failed to reload', event.path, error);
                    });
                  }
                }
              }
            }
            
            // Refresh the workspace after a short delay to batch changes: ONE pending refresh,
            // pushed back by every event. It was one timer per event, so a burst of N changes
            // ran N full workspace refreshes.
            if (refreshTimer) clearTimeout(refreshTimer);
            refreshTimer = setTimeout(() => {
              refreshTimer = null;
              if (isSubscribed) {
                refreshWorkspace();
              }
            }, 200);
          };
          
          // onFileChanged now returns a cleanup function
          cleanupListener = w.files.onFileChanged(handleFileChange);
        }
      } catch (error) {
        console.error('FileTreePanel: Failed to set up file watcher:', error);
      }
    };
    
    setupWatcher();
    
    return () => {
      isSubscribed = false;
      if (refreshTimer) { clearTimeout(refreshTimer); refreshTimer = null; }
      
      // Remove event listener (check if it's a function)
      if (cleanupListener && typeof cleanupListener === 'function') {
        cleanupListener();
        cleanupListener = null;
      }
      
      // Clean up watcher when component unmounts or workspace changes
      const w = window as any;
      if (w.files?.unwatchDirectory && project?.rootPath) {
        w.files.unwatchDirectory(project.rootPath);
      }
    };
  }, [project?.rootPath, refreshWorkspace]);

  // Handle keyboard events for file deletion
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      // Never treat Delete typed into a text field / the terminal / the editor as "delete files".
      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)) return;
      if (event.key === 'Delete' && selectedFiles.size > 0) {
        event.preventDefault();
        
        // Find the selected nodes to get their names and types
        const findNodeByPath = (nodes: any[], path: string): any => {
          for (const node of nodes) {
            if (node.path === path) return node;
            if (node.children) {
              const found = findNodeByPath(node.children, path);
              if (found) return found;
            }
          }
          return null;
        };

        // Delete all selected files
        const firstSelectedPath = Array.from(selectedFiles)[0];
        const selectedNode = project?.files ? findNodeByPath(project.files, firstSelectedPath) : null;
        if (selectedNode && selectedFiles.size === 1) {
          handleDeleteFile(selectedNode.path, selectedNode.name, selectedNode.isDir);
        } else if (selectedFiles.size > 1) {
          const confirmed = window.confirm(
            `¿Estás seguro de que quieres eliminar ${selectedFiles.size} archivos seleccionados?\n\nEsta acción no se puede deshacer.`
          );
          if (confirmed) {
            selectedFiles.forEach(async (path) => {
              const node = project?.files ? findNodeByPath(project.files, path) : null;
              if (node) {
                await handleDeleteFile(node.path, node.name, node.isDir);
              }
            });
          }
        }
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [selectedFiles, project?.files]);

  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      await refreshWorkspace();
    } finally {
      setIsRefreshing(false);
    }
  };

  const handleDeleteFile = async (filePath: string, fileName: string, isDir: boolean) => {
    // Confirmar eliminación
    const fileType = isDir ? 'carpeta' : 'archivo';
    const confirmed = window.confirm(
      `¿Estás seguro de que quieres eliminar ${fileType} "${fileName}"?\n\n` +
      `${isDir ? 'Esta acción eliminará la carpeta y todo su contenido.' : 'Esta acción no se puede deshacer.'}`
    );
    
    if (!confirmed) return;

    try {
      // Construir ruta completa del archivo
      const fullPath = project?.rootPath ? 
        (project.rootPath.includes('\\') 
          ? `${project.rootPath}\\${filePath.replace(/\//g, '\\')}`
          : `${project.rootPath}/${filePath}`
        ) : filePath;

      console.log('Deleting file:', fullPath);
      
      // Llamar a la API de eliminación
      const result = await (window as any).files?.deleteFile?.(fullPath);
      
      if (result?.error) {
        alert(`Error al eliminar ${fileType}: ${result.error}`);
        return;
      }

      // Si el archivo está abierto en el editor, cerrarlo
      if (!isDir) {
        const fileUri = normalizeFileUri(fullPath);
        const openDoc = documents.find(doc => doc.uri === fileUri || doc.diskPath === fullPath);
        if (openDoc) {
          console.log('Closing open document:', openDoc.uri);
          closeDocument(openDoc.uri);
        }
      } else {
        // Si es una carpeta, cerrar todos los documentos que estén dentro
        documents.forEach(doc => {
          if (doc.diskPath?.startsWith(fullPath)) {
            console.log('Closing document in deleted folder:', doc.uri);
            closeDocument(doc.uri);
          }
        });
      }

      // Actualizar el workspace después de eliminar
      await refreshWorkspace();
      
      // Limpiar selección si el archivo eliminado estaba seleccionado
      if (selectedFiles.has(filePath)) {
        setSelectedFiles(prev => {
          const next = new Set(prev);
          next.delete(filePath);
          return next;
        });
      }

      console.log(`${fileType} eliminado exitosamente:`, filePath);
    } catch (error) {
      console.error('Error deleting file:', error);
      alert(`Error al eliminar ${fileType}: ${error}`);
    }
  };

  const toggleDir = (path: string) => {
    setExpandedDirs(prev => {
      const next = new Set(prev);
      if (next.has(path)) {
        next.delete(path);
      } else {
        next.add(path);
      }
      return next;
    });
  };

  // Helper to get all visible files in order (flattened tree respecting expanded state)
  const getVisibleFilesInOrder = (): string[] => {
    if (!project?.files) return [];
    
    const result: string[] = [];
    const traverse = (nodes: FileNode[]) => {
      for (const node of nodes) {
        result.push(node.path);
        if (node.isDir && expandedDirs.has(node.path) && node.children) {
          traverse(node.children);
        }
      }
    };
    traverse(project.files);
    return result;
  };

  const handleFileClick = async (node: FileNode, event?: React.MouseEvent) => {
    // Handle range selection with Shift key
    if (event?.shiftKey && lastClickedFile) {
      const visibleFiles = getVisibleFilesInOrder();
      const startIndex = visibleFiles.indexOf(lastClickedFile);
      const endIndex = visibleFiles.indexOf(node.path);
      
      if (startIndex !== -1 && endIndex !== -1) {
        const min = Math.min(startIndex, endIndex);
        const max = Math.max(startIndex, endIndex);
        const rangeFiles = visibleFiles.slice(min, max + 1);
        
        setSelectedFiles(new Set(rangeFiles));
      }
      return; // Don't open file on range selection
    }
    
    // Handle multi-selection with Ctrl/Cmd key
    if (event?.ctrlKey || event?.metaKey) {
      setSelectedFiles(prev => {
        const next = new Set(prev);
        if (next.has(node.path)) {
          next.delete(node.path);
        } else {
          next.add(node.path);
        }
        return next;
      });
      setLastClickedFile(node.path);
      return; // Don't open file on multi-select
    } else {
      // Single selection
      setSelectedFiles(new Set([node.path]));
      setLastClickedFile(node.path);
    }
    
    if (node.isDir) {
      toggleDir(node.path);
    } else {
      // Handle .vplay files specially - open playground in Activity Bar
      if (node.name.endsWith('.vplay')) {
        const sceneName = node.name.replace('.vplay', '');
        console.log('[FileTree] Opening playground scene:', sceneName);
        
        // Switch to playground view in Activity Bar
        const switchEvent = new CustomEvent('activity:switchToPlayground');
        window.dispatchEvent(switchEvent);
        
        // Wait a bit for the panel to mount, then dispatch load event
        setTimeout(() => {
          const loadEvent = new CustomEvent('playground:loadScene', { 
            detail: { sceneName } 
          });
          window.dispatchEvent(loadEvent);
        }, 100);
        
        return;
      }
      
      selectFile(node.path);
      
      // Get the full file path by combining workspace root with relative path
      const { project } = useProjectStore.getState();
      if (!project?.rootPath) {
        console.error('No workspace root path available');
        return;
      }
      
      let fullPath: string;
      
      if (project.rootPath.includes('\\')) {
        // Windows path
        fullPath = `${project.rootPath}\\${node.path.replace(/\//g, '\\')}`;
      } else {
        // Unix-like path
        fullPath = `${project.rootPath}/${node.path}`;
      }
      
      // Create a file URI for the document using the full path
      const fileUri = normalizeFileUri(fullPath);
      
      // Check if document is already open
      const { documents, active, setActive } = useEditorStore.getState();
      const existingDoc = documents.find(d => d.uri === fileUri);
      
      if (existingDoc) {
        // File is already open, just switch to it
        setActive(fileUri);
      } else {
        // File is not open, need to load and open it
        try {
          console.log('Loading file:', fullPath);
          console.log('Workspace root:', project.rootPath);
          console.log('Relative path:', node.path);
          
          // Load file content using Electron API
          const fileResult = await (window as any).files?.readFile?.(fullPath);
          
          if (fileResult?.error) {
            console.error('Error loading file:', fileResult.error);
            // Fallback to placeholder if file can't be loaded
            const newDoc = {
              uri: fileUri,
              language: getLanguageFromFilename(node.name),
              content: `// Error loading file: ${fileResult.error}\n// File: ${node.path}`,
              dirty: false,
              diagnostics: [],
              diskPath: fullPath,
              lastSavedContent: ''
            };
            openDocument(newDoc);
            return;
          }
          
          // Create document with real file content
          const newDoc = {
            uri: fileUri,
            language: getLanguageFromFilename(node.name),
            content: fileResult.content || '',
            dirty: false,
            diagnostics: [],
            diskPath: fullPath,
            mtime: fileResult.mtime,
            lastSavedContent: fileResult.content || ''
          };
          
          console.log('File loaded successfully:', node.name, 'Size:', fileResult.size);
          openDocument(newDoc);
        } catch (error) {
          console.warn('Error opening file:', error);
        }
      }
    }
  };

  const getFileIcon = (node: FileNode): string => {
    if (node.isDir) {
      return expandedDirs.has(node.path) ? '📂' : '📁';
    }
    
    const ext = node.name.split('.').pop()?.toLowerCase() || '';
    switch (ext) {
      case 'vpy': return '🐍';
      case 'py': return '🐍';
      case 'vec': return '🎨';
      case 'anim': return '🎬';
      case 'vplay': return '🎮';
      case 'vmesh': return '🧊';
      case 'vscene': return '🏞️';
      case 'vskel': case 'vclip': return '🦴';
      case 'c': case 'cpp': case 'h': case 'hpp': return '⚙️';
      case 'asm': case 's': return '📜';
      case 'js': case 'ts': return '📦';
      case 'json': return '📋';
      case 'toml': return '⚙️';
      case 'md': return '📝';
      case 'txt': return '📄';
      case 'css': case 'scss': return '🎨';
      case 'html': case 'htm': return '🌐';
      case 'bin': return '💾';
      case 'mus': return '🎵';
      case 'sfx': return '🔊';
      case 'vox': return '🗣️';
      default: return '📄';
    }
  };

  const renderFileNode = (node: FileNode, depth: number = 0): React.ReactNode => {
    const isExpanded = expandedDirs.has(node.path);
    const isSelected = selectedFiles.has(node.path);
    const isHovered = hoveredFile === node.path;
    const isDragged = draggedFiles.has(node.path);
    const indent = depth * 16;
    
    // Determine background color with proper priority
    let backgroundColor = 'transparent';
    if (isDragged) {
      backgroundColor = '#1e1e1e';
    } else if (isSelected) {
      backgroundColor = '#0e639c'; // Selection color (blue) has highest priority
    } else if (isHovered) {
      backgroundColor = '#2a2a2a'; // Hover color only if not selected
    }
    
    return (
      <div key={node.path} style={{ position: 'relative' }}>
        {/* Guide lines like VSCode */}
        {depth > 0 && (
          <div 
            style={{
              position: 'absolute',
              left: depth * 16 - 8,
              top: 0,
              bottom: 0,
              width: 1,
              backgroundColor: '#333',
              opacity: 0.4
            }}
          />
        )}
        
        <div 
          className="file-tree-item"
          style={{
            paddingLeft: indent + 4,
            paddingRight: 4,
            paddingTop: 2,
            paddingBottom: 2,
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: 4,
            fontSize: 13,
            lineHeight: '20px',
            backgroundColor,
            opacity: isDragged ? 0.5 : 1,
            userSelect: 'none',
            position: 'relative'
          }}
          onClick={(e) => handleFileClick(node, e)}
          onMouseEnter={() => {
            // Set hover state - the background color will be calculated in render
            setHoveredFile(node.path);
          }}
          onMouseLeave={() => {
            // Clear hover state
            setHoveredFile(null);
          }}
          draggable={!node.isDir}
          onDragStart={(e) => {
            setDraggedFiles(prev => new Set([...prev, node.path]));
            e.dataTransfer.setData('text/plain', JSON.stringify({ 
              type: 'file', 
              path: node.path, 
              name: node.name,
              isDir: node.isDir
            }));
            e.dataTransfer.effectAllowed = 'move';
          }}
          onDragEnd={() => {
            setDraggedFiles(prev => {
              const next = new Set(prev);
              next.delete(node.path);
              return next;
            });
          }}
          onDragOver={(e) => {
            if (node.isDir) {
              e.preventDefault();
              e.dataTransfer.dropEffect = 'move';
            }
          }}
          onDrop={async (e) => {
            if (node.isDir) {
              e.preventDefault();
              const data = JSON.parse(e.dataTransfer.getData('text/plain'));
              console.log('Drop:', data, 'onto:', node.path);
              
              if (data.type === 'file' && project?.rootPath) {
                try {
                  // Construct full paths
                  const sourcePath = project.rootPath.includes('\\') 
                    ? `${project.rootPath}\\${data.path.replace(/\//g, '\\')}`
                    : `${project.rootPath}/${data.path}`;
                  
                  const targetDir = project.rootPath.includes('\\') 
                    ? `${project.rootPath}\\${node.path.replace(/\//g, '\\')}`
                    : `${project.rootPath}/${node.path}`;
                  
                  console.log('Moving file from:', sourcePath, 'to:', targetDir);
                  
                  const result = await (window as any).files?.moveFile?.({ sourcePath, targetDir });
                  
                  if (result?.error) {
                    if (result.error === 'target_exists') {
                      alert(`No se puede mover el archivo: Ya existe un archivo con el mismo nombre en "${node.name}"`);
                    } else {
                      alert(`Error al mover archivo: ${result.error}`);
                    }
                    return;
                  }
                  
                  // Update editor documents if file was moved
                  const oldFileUri = normalizeFileUri(sourcePath);
                  const newFileUri = normalizeFileUri(result.targetPath);
                  const openDoc = documents.find(doc => doc.uri === oldFileUri || doc.diskPath === sourcePath);
                  
                  if (openDoc) {
                    console.log('Updating moved document URI:', oldFileUri, '→', newFileUri);
                    // Close old document and open new one with same content
                    closeDocument(openDoc.uri);
                    const newDoc = {
                      ...openDoc,
                      uri: newFileUri,
                      diskPath: result.targetPath
                    };
                    openDocument(newDoc);
                  }
                  
                  // Refresh workspace to show changes
                  await refreshWorkspace();
                  
                  console.log('File moved successfully:', data.path, '→', node.path);
                } catch (error) {
                  console.error('Error moving file:', error);
                  alert(`Error al mover archivo: ${error}`);
                }
              }
            }
          }}
        >
          {node.isDir && (
            <span 
              style={{ 
                width: 12, 
                height: 12, 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'center',
                transform: isExpanded ? 'rotate(90deg)' : 'rotate(0deg)',
                transition: 'transform 0.1s ease',
                fontSize: 10,
                color: '#cccccc'
              }}
            >
              ▶
            </span>
          )}
          {!node.isDir && <span style={{ width: 12 }}></span>}
          <span style={{ 
            width: 16, 
            height: 16, 
            display: 'flex', 
            alignItems: 'center', 
            justifyContent: 'center',
            fontSize: 14
          }}>
            {getFileIcon(node)}
          </span>
          <span style={{ 
            color: node.isDir ? '#569cd6' : '#cccccc',
            flex: 1,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap'
          }}>
            {node.name}
          </span>
        </div>
        
        {node.isDir && isExpanded && node.children && (
          <div>
            {node.children.map(child => renderFileNode(child, depth + 1))}
          </div>
        )}
      </div>
    );
  };

  if (!hasWorkspace()) {
    return (
      <div style={{ padding: 16, textAlign: 'center', color: '#666' }}>
        <div style={{ marginBottom: 12 }}>📁</div>
        <div style={{ fontSize: 12, lineHeight: 1.4 }}>
          No hay workspace abierto.<br />
          Abre una carpeta desde la página de bienvenida.
        </div>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', fontSize: 13 }}>
      {/* Workspace header */}
      <div style={{ 
        padding: '8px 12px', 
        borderBottom: '1px solid #333',
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        flexShrink: 0
      }}>
        <span>{isVpyProject ? '📦' : '📁'}</span>
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 600, color: isVpyProject ? '#4ec9b0' : '#569cd6', display: 'flex', alignItems: 'center', gap: 6 }}>
            {displayName}
            {projectVersion && (
              <span style={{ fontSize: 10, color: '#888', fontWeight: 400 }}>v{projectVersion}</span>
            )}
          </div>
          <div style={{ fontSize: 11, color: '#666', marginTop: 2 }}>
            {isVpyProject ? 'VPy Project' : project?.rootPath}
          </div>
        </div>
        <button
          onClick={handleRefresh}
          disabled={isRefreshing}
          style={{
            background: 'transparent',
            border: '1px solid #444',
            borderRadius: 4,
            color: isRefreshing ? '#666' : '#ccc',
            padding: '4px 8px',
            fontSize: 12,
            cursor: isRefreshing ? 'not-allowed' : 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: 4
          }}
          title="Actualizar archivos"
        >
          {isRefreshing ? '🔄' : '↻'}
        </button>
      </div>

      {/* File tree - scrollable content */}
      <div 
        style={{ 
          flex: 1, 
          overflow: 'auto', 
          padding: '8px 0',
          scrollbarWidth: 'thin',
          scrollbarColor: '#424242 #1e1e1e'
        }}
        className="file-tree-scroll"
      >
        {project?.files.map(node => renderFileNode(node))}
      </div>


    </div>
  );
};
