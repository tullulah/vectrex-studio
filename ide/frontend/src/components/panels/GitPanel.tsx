import React, { useState, useEffect, useCallback, useMemo, memo } from 'react';
import './GitPanel.css';
import { useProjectStore } from '../../state/projectStore';
import { DiffViewer } from '../modals/DiffViewer';
import { CommitHistory } from './CommitHistory';
import { CreateBranchDialog } from '../dialogs/CreateBranchDialog';
import { StashList } from './StashList';
import { TagsList } from './TagsList';
import { RemotesList } from './RemotesList';
import { ConflictResolver } from './ConflictResolver';

// Custom hook for debouncing
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => clearTimeout(handler);
  }, [value, delay]);

  return debouncedValue;
}

interface GitChange {
  path: string;
  status: 'M' | 'A' | 'D' | '?';
  staged: boolean;
}

interface GitBranch {
  name: string;
  current: boolean;
  isRemote: boolean;
}

interface GitCommit {
  hash: string;
  shortHash: string;
  message: string;
  author: string;
  date: string;
}

// Memoized component for search result items
const SearchResultItem = memo<{ commit: GitCommit }>(({ commit }) => (
  <div className="git-search-result-item">
    <div className="git-result-hash" title={commit.hash}>{commit.shortHash}</div>
    <div className="git-result-message">{commit.message}</div>
    <div className="git-result-meta">
      <span className="git-result-author">{commit.author}</span>
      <span className="git-result-date">{new Date(commit.date).toLocaleDateString()}</span>
    </div>
  </div>
));

SearchResultItem.displayName = 'SearchResultItem';

// Memoized component for file history items
const HistoryItem = memo<{ commit: GitCommit }>(({ commit }) => (
  <div className="git-file-history-item">
    <div className="git-history-hash" title={commit.hash}>{commit.shortHash}</div>
    <div className="git-history-message">{commit.message}</div>
    <div className="git-history-meta">
      <span className="git-history-author">{commit.author}</span>
      <span className="git-history-date">{new Date(commit.date).toLocaleDateString()}</span>
    </div>
  </div>
));

HistoryItem.displayName = 'HistoryItem';

export const GitPanel: React.FC = () => {
  const [commitMessage, setCommitMessage] = useState('');
  const [changes, setChanges] = useState<GitChange[]>([]);
  const [loading, setLoading] = useState(false);
  const [currentProjectDir, setCurrentProjectDir] = useState<string | null>(null);
  const [branches, setBranches] = useState<GitBranch[]>([]);
  const [currentBranch, setCurrentBranch] = useState<string | null>(null);
  const [showBranchDropdown, setShowBranchDropdown] = useState(false);
  const [selectedDiffFile, setSelectedDiffFile] = useState<string | null>(null);
  const [showCommitHistory, setShowCommitHistory] = useState(false);
  const [showCreateBranch, setShowCreateBranch] = useState(false);
  const [showStashList, setShowStashList] = useState(false);
  const [stashMessage, setStashMessage] = useState('');
  const [showTagsList, setShowTagsList] = useState(false);
  const [showRemotesList, setShowRemotesList] = useState(false);
  const [showConflictResolver, setShowConflictResolver] = useState(false);
  const [hasConflicts, setHasConflicts] = useState(false);
  const [aheadCount, setAheadCount] = useState(0);
  const [behindCount, setBehindCount] = useState(0);
  const [hasRemote, setHasRemote] = useState(false);
  const [showSearchCommits, setShowSearchCommits] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<Array<{ hash: string; shortHash: string; message: string; author: string; date: string }>>([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const debouncedSearchQuery = useDebounce(searchQuery, 300); // 300ms debounce
  const [isBranchProtected, setIsBranchProtected] = useState(false);
  const [protectionWarning, setProtectionWarning] = useState<string | null>(null);
  const [showFileHistory, setShowFileHistory] = useState(false);
  const [fileHistoryPath, setFileHistoryPath] = useState<string | null>(null);
  const [fileHistoryCommits, setFileHistoryCommits] = useState<Array<{ hash: string; shortHash: string; message: string; author: string; date: string; body: string }>>([]);
  const [fileHistoryLoading, setFileHistoryLoading] = useState(false);
  const [fileHistoryOffset, setFileHistoryOffset] = useState(0);
  const [hasMoreHistory, setHasMoreHistory] = useState(false);
  const [showGitConfig, setShowGitConfig] = useState(false);
  const [configUserName, setConfigUserName] = useState('');
  const [configUserEmail, setConfigUserEmail] = useState('');
  const [configLoading, setConfigLoading] = useState(false);
  const { vpyProject } = useProjectStore();

  // Function to refresh git status
  const refreshGitStatus = async (projectDir: string) => {
    try {
      setLoading(true);
      const git = (window as any).git;
      if (!git?.status) return;

      // Check for conflicts first
      const conflictResult = await git.checkConflicts(projectDir);
      setHasConflicts(conflictResult.ok && conflictResult.hasConflicts === true);

      const result = await git.status(projectDir);
      if (result.ok && result.files) {
        setChanges(result.files);
      }
    } catch (error) {
      console.error('Failed to refresh git status:', error);
    } finally {
      setLoading(false);
    }
  };

  // Function to refresh branches
  const refreshBranches = async (projectDir: string) => {
    try {
      const git = (window as any).git;
      if (!git?.branches) return;

      const result = await git.branches(projectDir);
      if (result.ok && result.branches) {
        setBranches(result.branches);
        setCurrentBranch(result.current);
      }

      // Also get sync status with branches
      if (git?.syncStatus) {
        const syncResult = await git.syncStatus({ projectDir });
        if (syncResult.ok) {
          setAheadCount(syncResult.aheadCount || 0);
          setBehindCount(syncResult.behindCount || 0);
          setHasRemote(syncResult.hasRemote || false);
        }
      }
    } catch (error) {
      console.error('Failed to refresh branches:', error);
    }
  };

  // Function to check if current branch is protected
  const checkBranchProtection = async (projectDir: string, branch: string) => {
    try {
      const git = (window as any).git;
      if (!git?.checkBranchProtection || !branch) return;

      const result = await git.checkBranchProtection({ projectDir, branch });
      if (result.ok) {
        setIsBranchProtected(result.isProtected || false);
        setProtectionWarning(result.reason || null);
      }
    } catch (error) {
      console.error('Failed to check branch protection:', error);
    }
  };

  // Auto-search when debounced query changes
  useEffect(() => {
    if (debouncedSearchQuery && currentProjectDir) {
      handleSearchCommits(debouncedSearchQuery);
    } else if (!debouncedSearchQuery) {
      setSearchResults([]);
    }
  }, [debouncedSearchQuery, currentProjectDir]);

  // Load git status when component mounts or project changes
  useEffect(() => {
    // Clear changes when no project
    if (!vpyProject?.rootDir) {
      setChanges([]);
      setCurrentProjectDir(null);
      setCommitMessage('');
      setBranches([]);
      setCurrentBranch(null);
      setLoading(false);
      console.log('[GitPanel] Project closed, clearing changes');
      return;
    }

    // Only reload if project actually changed
    if (currentProjectDir === vpyProject.rootDir) {
      return;
    }

    // Clear and load new project
    console.log('[GitPanel] Project changed, loading:', vpyProject.rootDir);
    setCurrentProjectDir(vpyProject.rootDir);
    setChanges([]);
    setCommitMessage('');
    setBranches([]);
    setCurrentBranch(null);
    
    const loadGitData = async () => {
      setLoading(true);
      await refreshGitStatus(vpyProject.rootDir);
      await refreshBranches(vpyProject.rootDir);
      // Check branch protection after getting current branch
      const git = (window as any).git;
      if (git?.checkBranchProtection) {
        const branchResult = await git.branches(vpyProject.rootDir);
        if (branchResult.ok && branchResult.current) {
          await checkBranchProtection(vpyProject.rootDir, branchResult.current);
        }
      }
      setLoading(false);
    };

    loadGitData();
  }, [vpyProject?.rootDir, currentProjectDir]);

  // Auto-refresh git status on file changes + polling fallback
  useEffect(() => {
    if (!currentProjectDir) return;

    let debounceTimer: ReturnType<typeof setTimeout> | null = null;

    const scheduleRefresh = () => {
      if (debounceTimer) clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        refreshGitStatus(currentProjectDir);
      }, 600);
    };

    // File watcher — any file change triggers a refresh
    const files = (window as any).files;
    const unsubscribe = files?.onFileChanged ? files.onFileChanged(scheduleRefresh) : null;

    // Polling fallback every 5 s (covers external edits, terminal changes, etc.)
    const poll = setInterval(() => refreshGitStatus(currentProjectDir), 5000);

    return () => {
      if (debounceTimer) clearTimeout(debounceTimer);
      if (unsubscribe) unsubscribe();
      clearInterval(poll);
    };
  }, [currentProjectDir]);

  const stagedChanges = changes.filter(c => c.staged);
  const unstagedChanges = changes.filter(c => !c.staged);

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'M': return 'M';
      case 'A': return 'A';
      case 'D': return 'D';
      case '?': return '?';
      default: return '•';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'M': return 'modified';
      case 'A': return 'added';
      case 'D': return 'deleted';
      case '?': return 'modified';
      default: return 'modified';
    }
  };

  const handleCheckoutBranch = async (branchName: string) => {
    if (!currentProjectDir || branchName === currentBranch) return;

    setShowBranchDropdown(false);
    
    try {
      const git = (window as any).git;
      if (!git?.checkout) return;

      const result = await git.checkout({ projectDir: currentProjectDir, branch: branchName });
      
      if (result.ok) {
        setIsBranchProtected(false);
        setProtectionWarning(null);
        await refreshBranches(currentProjectDir);
        await refreshGitStatus(currentProjectDir);
        await checkBranchProtection(currentProjectDir, branchName);
      } else {
        alert(`Failed to checkout branch: ${result.error}`);
      }
    } catch (error) {
      console.error('Failed to checkout branch:', error);
      alert(`Error switching branch: ${error}`);
    }
  };


  const handleDeleteBranch = async (branchName: string) => {
    if (!currentProjectDir) return;
    if (branchName === currentBranch) {
      alert('Cannot delete the currently checked out branch');
      return;
    }
    if (!window.confirm(`Delete branch "${branchName}"? This cannot be undone.`)) {
      return;
    }
    try {
      const git = (window as any).git;
      if (!git?.deleteBranch) return;
      const result = await git.deleteBranch({
        projectDir: currentProjectDir,
        branch: branchName,
        force: false,
      });
      if (result.ok) {
        setShowBranchDropdown(false);
        await refreshBranches(currentProjectDir);
      } else {
        alert(`Failed to delete branch: ${result.error}`);
      }
    } catch (error) {
      console.error('Failed to delete branch:', error);
      alert(`Error deleting branch: ${error}`);
    }
  };

  // Expose git keyboard handlers to window and listen for events
  // FIXED: branch deletion handler properly closed  
  useEffect(() => {
    // Expose functions to window for keyboard shortcuts
    (window as any).gitShowBranchSelector = () => setShowBranchDropdown(true);
    (window as any).gitShowHistory = () => setShowCommitHistory(true);
    (window as any).gitShowDiff = (filePath: string) => setSelectedDiffFile(filePath);
    (window as any).gitShowSearch = () => setShowSearchCommits(true);
    (window as any).gitFocusCommit = () => {
      // Scroll to commit section and focus textarea
      const textarea = document.querySelector('.git-commit-message') as HTMLTextAreaElement;
      if (textarea) {
        setTimeout(() => {
          textarea.focus();
          textarea.scrollIntoView({ behavior: 'smooth' });
        }, 100);
      }
    };
    (window as any).gitRefresh = () => {
      if (currentProjectDir) {
        refreshGitStatus(currentProjectDir);
        refreshBranches(currentProjectDir);
      }
    };

    // Listen for custom events from keyboard handlers
    const handleShowBranchSelector = () => setShowBranchDropdown(true);
    const handleShowHistory = () => setShowCommitHistory(true);
    const handleShowDiff = (e: any) => setSelectedDiffFile(e.detail?.filePath || null);
    const handleShowSearch = () => setShowSearchCommits(true);
    const handleFocusCommit = () => {
      const textarea = document.querySelector('.git-commit-message') as HTMLTextAreaElement;
      if (textarea) {
        setTimeout(() => {
          textarea.focus();
          textarea.scrollIntoView({ behavior: 'smooth' });
        }, 100);
      }
    };
    const handleRefresh = () => {
      if (currentProjectDir) {
        refreshGitStatus(currentProjectDir);
        refreshBranches(currentProjectDir);
      }
    };

    window.addEventListener('git:showBranchSelector', handleShowBranchSelector);
    window.addEventListener('git:showHistory', handleShowHistory);
    window.addEventListener('git:showDiff', handleShowDiff);
    window.addEventListener('git:showSearch', handleShowSearch);
    window.addEventListener('git:focusCommit', handleFocusCommit);
    window.addEventListener('git:refresh', handleRefresh);

    return () => {
      window.removeEventListener('git:showBranchSelector', handleShowBranchSelector);
      window.removeEventListener('git:showHistory', handleShowHistory);
      window.removeEventListener('git:showDiff', handleShowDiff);
      window.removeEventListener('git:showSearch', handleShowSearch);
      window.removeEventListener('git:focusCommit', handleFocusCommit);
      window.removeEventListener('git:refresh', handleRefresh);
    };
  }, [currentProjectDir]);

  const handlePush = useCallback(async () => {
    if (!currentProjectDir || !currentBranch) return;

    try {
      const git = (window as any).git;
      if (!git?.push) return;

      setLoading(true);
      const result = await git.push({ projectDir: currentProjectDir, branch: currentBranch });
      
      if (result.ok) {
        alert('Changes pushed successfully');
        await refreshGitStatus(currentProjectDir);
      } else {
        const isBehind = result.error && (
          result.error.includes('fetch first') ||
          result.error.includes('Updates were rejected') ||
          result.error.includes('tip of your current branch is behind')
        );
        if (isBehind) {
          const doPull = window.confirm(
            'Push rejected: the remote has commits you do not have locally.\n\nPull now to integrate the remote changes, then push again?'
          );
          if (doPull) {
            const pullResult = await git.pull({ projectDir: currentProjectDir, branch: currentBranch });
            if (pullResult.ok) {
              await refreshGitStatus(currentProjectDir);
              await refreshBranches(currentProjectDir);
            } else if (pullResult.hasConflicts) {
              await refreshGitStatus(currentProjectDir);
              setHasConflicts(true);
              setShowConflictResolver(true);
            } else {
              alert(`Pull failed: ${pullResult.error}`);
            }
          }
        } else {
          alert(`Failed to push: ${result.error}`);
        }
      }
    } catch (error) {
      console.error('Failed to push:', error);
      alert(`Error pushing changes: ${error}`);
    } finally {
      setLoading(false);
    }
  }, [currentProjectDir, currentBranch]);

  const handlePull = useCallback(async () => {
    if (!currentProjectDir || !currentBranch) return;

    try {
      const git = (window as any).git;
      if (!git?.pull) return;

      setLoading(true);
      const result = await git.pull({ projectDir: currentProjectDir, branch: currentBranch });
      
      if (result.ok) {
        alert('Changes pulled successfully');
        await refreshGitStatus(currentProjectDir);
        await refreshBranches(currentProjectDir);
      } else if (result.hasConflicts) {
        await refreshGitStatus(currentProjectDir);
        setHasConflicts(true);
        setShowConflictResolver(true);
      } else {
        alert(`Failed to pull: ${result.error}`);
      }
    } catch (error) {
      console.error('Failed to pull:', error);
      alert(`Error pulling changes: ${error}`);
    } finally {
      setLoading(false);
    }
  }, [currentProjectDir, currentBranch]);

  const handleStash = async () => {
    if (!currentProjectDir) return;

    try {
      const git = (window as any).git;
      if (!git?.stash) return;

      setLoading(true);
      const result = await git.stash({
        projectDir: currentProjectDir,
        message: stashMessage || undefined,
      });

      if (result.ok) {
        alert('Changes stashed successfully');
        setStashMessage('');
        await refreshGitStatus(currentProjectDir);
      } else {
        alert(`Failed to stash: ${result.error}`);
      }
    } catch (error) {
      console.error('Failed to stash:', error);
      alert(`Error stashing changes: ${error}`);
    } finally {
      setLoading(false);
    }
  };

  const handleSearchCommits = useCallback(async (query: string) => {
    if (!currentProjectDir || !query) {
      setSearchResults([]);
      return;
    }

    try {
      const git = (window as any).git;
      if (!git?.searchCommits) return;

      setSearchLoading(true);
      const result = await git.searchCommits({
        projectDir: currentProjectDir,
        query,
        limit: 50
      });

      if (result.ok && result.commits) {
        setSearchResults(result.commits);
      } else {
        setSearchResults([]);
      }
    } catch (error) {
      console.error('Failed to search commits:', error);
      setSearchResults([]);
    } finally {
      setSearchLoading(false);
    }
  }, [currentProjectDir]);

  const handleGetFileHistory = useCallback(async (filePath: string, append: boolean = false) => {
    if (!currentProjectDir) return;

    try {
      const git = (window as any).git;
      if (!git?.fileHistory) return;

      setFileHistoryLoading(true);
      if (!append) {
        setFileHistoryPath(filePath);
        setFileHistoryOffset(0);
      }

      const limit = 20;
      const offset = append ? fileHistoryOffset : 0;

      const result = await git.fileHistory({
        projectDir: currentProjectDir,
        filePath,
        limit,
        offset
      });

      if (result.ok && result.commits) {
        if (append) {
          // Agregar más commits al historial existente
          setFileHistoryCommits([...fileHistoryCommits, ...result.commits]);
        } else {
          // Reemplazar historial completo (búsqueda nueva)
          setFileHistoryCommits(result.commits);
        }

        // Actualizar estado de pagination
        setFileHistoryOffset(offset + limit);
        setHasMoreHistory(result.commits.length === limit);
        
        if (!append) {
          setShowFileHistory(true);
        }
      }
    } catch (error) {
      console.error('Failed to get file history:', error);
      if (!append) {
        setFileHistoryCommits([]);
      }
    } finally {
      setFileHistoryLoading(false);
    }
  }, [currentProjectDir, fileHistoryOffset, fileHistoryCommits]);

  const handleLoadConfig = async () => {
    if (!currentProjectDir) return;

    try {
      const git = (window as any).git;
      if (!git?.getConfig) return;

      setConfigLoading(true);
      const result = await git.getConfig({ projectDir: currentProjectDir });

      if (result.ok && result.config) {
        setConfigUserName(result.config.userName);
        setConfigUserEmail(result.config.userEmail);
      }
    } catch (error) {
      console.error('Failed to load config:', error);
    } finally {
      setConfigLoading(false);
    }
  };

  const handleSaveConfig = async () => {
    if (!currentProjectDir) return;

    try {
      const git = (window as any).git;
      if (!git?.setConfig) return;

      setConfigLoading(true);

      if (configUserName) {
        await git.setConfig({
          projectDir: currentProjectDir,
          key: 'user.name',
          value: configUserName
        });
      }

      if (configUserEmail) {
        await git.setConfig({
          projectDir: currentProjectDir,
          key: 'user.email',
          value: configUserEmail
        });
      }

      alert('Git config saved successfully');
      setShowGitConfig(false);
    } catch (error) {
      console.error('Failed to save config:', error);
      alert(`Error saving config: ${error}`);
    } finally {
      setConfigLoading(false);
    }
  };

  const handleStageFile = useCallback(async (path: string) => {
    if (!currentProjectDir) return;
    
    try {
      const git = (window as any).git;
      if (!git?.stage) return;
      
      const result = await git.stage({ projectDir: currentProjectDir, filePath: path });
      
      if (result.ok) {
        await refreshGitStatus(currentProjectDir);
      }
    } catch (error) {
      console.error('Failed to stage file:', error);
    }
  }, [currentProjectDir]);

  const handleUnstageFile = useCallback(async (path: string) => {
    if (!currentProjectDir) return;
    
    try {
      const git = (window as any).git;
      if (!git?.unstage) return;
      
      const result = await git.unstage({ projectDir: currentProjectDir, filePath: path });
      
      if (result.ok) {
        await refreshGitStatus(currentProjectDir);
      }
    } catch (error) {
      console.error('Failed to unstage file:', error);
    }
  }, [currentProjectDir]);

  const handleDiscardFile = async (path: string) => {
    if (!currentProjectDir) return;
    
    // Confirm before discarding
    const confirmed = window.confirm(`Are you sure you want to discard changes to ${path.split('/').pop()}?\n\nThis cannot be undone.`);
    if (!confirmed) return;

    try {
      const git = (window as any).git;
      if (!git?.discard) return;
      
      const result = await git.discard({ projectDir: currentProjectDir, filePath: path });
      
      if (result.ok) {
        await refreshGitStatus(currentProjectDir);
        // Force-reload the file in the editor even if dirty — the disk is now the truth
        const fullPath = `${currentProjectDir}/${path}`.replace(/\/\//g, '/');
        const editorStore = (window as any).__editorStore__;
        const apiFiles = (window as any).files;
        if (editorStore && apiFiles?.readFile) {
          const state = editorStore.getState();
          const doc = state.documents.find((d: any) => d.diskPath === fullPath);
          if (doc) {
            const fileResult = await apiFiles.readFile(fullPath);
            if (!fileResult.error && fileResult.content !== undefined) {
              state.updateContent(doc.uri, fileResult.content);
              editorStore.setState((s: any) => ({
                documents: s.documents.map((d: any) =>
                  d.uri === doc.uri
                    ? { ...d, dirty: false, lastSavedContent: fileResult.content }
                    : d
                ),
              }));
            }
          }
        }
      } else {
        alert(`Failed to discard changes: ${result.error}`);
      }
    } catch (error) {
      console.error('Failed to discard file:', error);
      alert(`Error discarding changes: ${error}`);
    }
  };

  const handleCommit = useCallback(async () => {
    if (!currentProjectDir) return;
    if (!commitMessage.trim() || stagedChanges.length === 0) return;

    try {
      const git = (window as any).git;
      if (!git?.commit) return;
      
      const result = await git.commit({ projectDir: currentProjectDir, message: commitMessage });
      
      if (result.ok) {
        setCommitMessage('');
        await refreshGitStatus(currentProjectDir);
      } else {
        alert(`Commit failed: ${result.error}`);
      }
    } catch (error) {
      console.error('Failed to commit:', error);
      alert(`Commit error: ${error}`);
    }
  }, [currentProjectDir, commitMessage, stagedChanges.length]);

  return (
    <div className="git-panel">
      {/* Header */}
      <div className="git-panel-header">
        <h3>Source Control</h3>
      </div>

      {/* Action Buttons */}
      <div className="git-panel-actions-bar">
        <button
          className="git-panel-action-btn"
          onClick={handlePush}
          disabled={!currentBranch || loading || isBranchProtected}
          title={isBranchProtected ? '🔒 Protected branch — push disabled' : 'Push changes to remote'}
        >
          ⬆️
        </button>
        <button
          className="git-panel-action-btn"
          onClick={handlePull}
          disabled={!currentBranch || loading}
          title="Pull changes from remote"
        >
          ⬇️
        </button>
        <button
          className="git-panel-action-btn"
          onClick={() => setShowCommitHistory(!showCommitHistory)}
          title="View commit history"
        >
          🕐
        </button>
        <button
          className="git-panel-action-btn"
          onClick={() => setShowCreateBranch(true)}
          disabled={!currentBranch}
          title="Create new branch"
        >
          🌿
        </button>
        <button
          className="git-panel-action-btn"
          onClick={() => setShowStashList(!showStashList)}
          title="View stashes"
        >
          📦
        </button>
        <button
          className="git-panel-action-btn"
          onClick={() => setShowTagsList(!showTagsList)}
          title="Manage tags"
        >
          🏷️
        </button>
        <button
          className="git-panel-action-btn"
          onClick={() => setShowRemotesList(!showRemotesList)}
          title="Manage remotes"
        >
          🔗
        </button>
        <button
          className="git-panel-action-btn"
          onClick={() => {
            setShowGitConfig(true);
            handleLoadConfig();
          }}
          title="Git configuration"
        >
          ⚙️
        </button>
        {hasConflicts && (
          <button
            className="git-panel-action-btn conflict-warning"
            onClick={() => setShowConflictResolver(true)}
            title="Resolve merge conflicts"
            style={{ color: '#ff6b6b' }}
          >
            ⚠️
          </button>
        )}
      </div>

      {/* Git Config Modal */}
      {showGitConfig && (
        <div className="git-modal-overlay" onClick={() => setShowGitConfig(false)}>
          <div className="git-modal" onClick={(e) => e.stopPropagation()}>
            <div className="git-modal-header">
              <span>Git Configuration</span>
              <button 
                className="git-modal-close"
                onClick={() => setShowGitConfig(false)}
              >
                ✕
              </button>
            </div>
            <div className="git-config-content">
              <div className="git-config-field">
                <label htmlFor="git-config-name">User Name:</label>
                <input
                  id="git-config-name"
                  type="text"
                  className="git-config-input"
                  value={configUserName}
                  onChange={(e) => setConfigUserName(e.target.value)}
                  disabled={configLoading}
                  placeholder="Your name"
                />
              </div>
              <div className="git-config-field">
                <label htmlFor="git-config-email">User Email:</label>
                <input
                  id="git-config-email"
                  type="email"
                  className="git-config-input"
                  value={configUserEmail}
                  onChange={(e) => setConfigUserEmail(e.target.value)}
                  disabled={configLoading}
                  placeholder="your.email@example.com"
                />
              </div>
              <div className="git-config-actions">
                <button
                  className="git-commit-button"
                  onClick={handleSaveConfig}
                  disabled={configLoading}
                  style={{ flex: 1 }}
                >
                  {configLoading ? 'Saving...' : '💾 Save'}
                </button>
                <button
                  className="git-panel-action-btn"
                  onClick={() => setShowGitConfig(false)}
                  disabled={configLoading}
                  style={{ flex: 1 }}
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Search Commits Panel */}
      {showSearchCommits && (
        <div className="git-search-panel">
          <div className="git-search-header">
            <input
              type="text"
              className="git-search-input"
              placeholder="Search by message, author..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                // Debounce handles actual search via useEffect
              }}
              autoFocus
            />
            <button
              className="git-search-close"
              onClick={() => {
                setShowSearchCommits(false);
                setSearchQuery('');
                setSearchResults([]);
              }}
            >
              ✕
            </button>
          </div>
          {searchLoading && <div className="git-search-loading">Searching...</div>}
          {!searchLoading && searchResults.length === 0 && searchQuery && (
            <div className="git-search-empty">No commits found</div>
          )}
          {!searchLoading && searchResults.length > 0 && (
            <div className="git-search-results">
              {searchResults.map((commit) => (
                <SearchResultItem key={commit.hash} commit={commit} />
              ))}
            </div>
          )}
        </div>
      )}

      {/* Main Content Area */}
      <div className="git-panel-content">
        <div className="git-commit-section">
          <textarea
            className="git-commit-message"
            placeholder="Message (Ctrl+Enter to commit)"
            value={commitMessage}
            onChange={(e) => setCommitMessage(e.target.value)}
            onKeyDown={(e) => {
              if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                handleCommit();
              }
            }}
            rows={3}
          />
          <button 
            className="git-commit-button" 
            disabled={!commitMessage.trim() || stagedChanges.length === 0}
            onClick={handleCommit}
            title={isBranchProtected ? `⚠️ ${protectionWarning || 'Protected branch'}` : 'Commit changes'}
          >
            ✓ Commit ({stagedChanges.length})
          </button>

          {/* Branch Protection Warning */}
          {isBranchProtected && protectionWarning && (
            <div className="git-protection-warning">
              <span className="git-warning-icon">⚠️</span>
              <span className="git-warning-text">{protectionWarning}</span>
            </div>
          )}

          {/* Stash Section */}
          {unstagedChanges.length > 0 && (
            <div style={{ marginTop: '8px' }}>
              <input
                type="text"
                className="git-commit-message"
                placeholder="Stash message (optional)"
                value={stashMessage}
                onChange={(e) => setStashMessage(e.target.value)}
                style={{ minHeight: 'auto', padding: '6px 8px', fontSize: '12px', marginBottom: '4px' }}
              />
              <button 
                className="git-commit-button"
                disabled={loading || unstagedChanges.length === 0}
                onClick={handleStash}
                style={{ backgroundColor: '#8B4513', borderColor: '#8B4513' }}
              >
                📦 Stash ({unstagedChanges.length})
              </button>
            </div>
          )}
        </div>

        {/* Staged Changes */}
        {stagedChanges.length > 0 && (
          <div className="git-changes-section">
            <div className="git-changes-header">
              <span>Staged Changes</span>
              <span className="git-changes-count">{stagedChanges.length}</span>
            </div>
            <div className="git-changes-list">
              {stagedChanges.map((file) => (
                <div 
                  key={file.path} 
                  className="git-change-item"
                  title={file.path}
                >
                  <span className={`git-change-status ${getStatusColor(file.status)}`}>
                    {getStatusLabel(file.status)}
                  </span>
                  <span className="git-change-path">{file.path.split('/').pop()}</span>
                  <div className="git-change-actions">
                    <button
                      className="git-change-action diff-btn"
                      onClick={() => setSelectedDiffFile(file.path)}
                      title="View diff"
                    >
                      ⧉
                    </button>
                    <button
                      className="git-change-action"
                      onClick={() => handleUnstageFile(file.path)}
                      title="Unstage"
                    >
                      −
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Unstaged Changes */}
        {unstagedChanges.length > 0 && (
          <div className="git-changes-section">
            <div className="git-changes-header">
              <span>Changes</span>
              <span className="git-changes-count">{unstagedChanges.length}</span>
            </div>
            <div className="git-changes-list">
              {unstagedChanges.map((file) => (
                <div 
                  key={file.path} 
                  className="git-change-item"
                  title={file.path}
                >
                  <span className={`git-change-status ${getStatusColor(file.status)}`}>
                    {getStatusLabel(file.status)}
                  </span>
                  <span className="git-change-path">{file.path.split('/').pop()}</span>
                  <div className="git-change-actions">
                    <button
                      className="git-change-action diff-btn"
                      onClick={() => setSelectedDiffFile(file.path)}
                      title="View diff"
                    >
                      ⧉
                    </button>
                    <button
                      className="git-change-action diff-btn"
                      onClick={() => handleGetFileHistory(file.path)}
                      title="File history"
                    >
                      🕐
                    </button>
                    <button
                      className="git-change-action git-stage-btn"
                      onClick={() => handleStageFile(file.path)}
                      title="Stage"
                    >
                      +
                    </button>
                    <button
                      className="git-change-action git-discard-btn"
                      onClick={() => handleDiscardFile(file.path)}
                      title="Discard changes"
                    >
                      ↺
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* No changes */}
        {changes.length === 0 && !loading && (
          <div className="git-no-changes">No changes</div>
        )}

        {loading && (
          <div className="git-no-changes">Loading...</div>
        )}
      </div>

      {/* Bottom Branch Bar (like VS Code) */}
      {currentBranch && (
        <div className="git-panel-footer">
          <button
            className="git-branch-button-footer"
            onClick={() => setShowBranchDropdown(!showBranchDropdown)}
            title="Switch branch"
          >
            <span className="git-branch-icon">⎇</span>
            <span className="git-branch-name">{currentBranch}</span>
            {hasRemote && (aheadCount > 0 || behindCount > 0) && (
              <span className="git-sync-indicator" title={`${aheadCount} ahead, ${behindCount} behind`}>
                {aheadCount > 0 && <span className="git-sync-ahead">↑{aheadCount}</span>}
                {behindCount > 0 && <span className="git-sync-behind">↓{behindCount}</span>}
              </span>
            )}
          </button>

          {showBranchDropdown && branches.length > 0 && (
            <div className="git-branch-dropdown-footer">
              {/* Local Branches */}
              {branches.filter(b => !b.isRemote).length > 0 && (
                <div className="git-branch-section">
                  {branches.filter(b => !b.isRemote).map((branch) => (
                    <div key={branch.name} className="git-branch-option-container">
                      <button
                        className={`git-branch-option ${branch.current ? 'active' : ''}`}
                        onClick={() => handleCheckoutBranch(branch.name)}
                      >
                        {branch.current && '✓ '}
                        {branch.name}
                      </button>
                      {!branch.current && (
                        <button
                          className="git-branch-delete-btn"
                          onClick={() => handleDeleteBranch(branch.name)}
                          title="Delete branch"
                        >
                          🗑️
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              )}

              {/* Remote Branches */}
              {branches.filter(b => b.isRemote).length > 0 && (
                <div className="git-branch-section">
                  <div className="git-branch-section-title">Remote</div>
                  {branches.filter(b => b.isRemote).map((branch) => (
                    <div key={branch.name} className="git-branch-option-container">
                      <button
                        className={`git-branch-option remote ${branch.current ? 'active' : ''}`}
                        onClick={() => handleCheckoutBranch(branch.name)}
                      >
                        {branch.current && '✓ '}
                        {branch.name}
                      </button>
                      {!branch.current && (
                        <button
                          className="git-branch-delete-btn"
                          onClick={() => handleDeleteBranch(branch.name)}
                          title="Delete branch"
                        >
                          🗑️
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* Diff Viewer Modal */}
      {selectedDiffFile && currentProjectDir && (
        <DiffViewer
          filePath={selectedDiffFile}
          projectDir={currentProjectDir}
          onClose={() => setSelectedDiffFile(null)}
        />
      )}

      {/* Commit History Modal */}
      {showCommitHistory && currentProjectDir && (
        <CommitHistory
          projectDir={currentProjectDir}
          onClose={() => setShowCommitHistory(false)}
          onRevert={() => {
            refreshGitStatus(currentProjectDir);
          }}
        />
      )}

      {/* Create Branch Dialog */}
      {showCreateBranch && currentProjectDir && currentBranch && (
        <CreateBranchDialog
          projectDir={currentProjectDir}
          currentBranch={currentBranch}
          onClose={() => setShowCreateBranch(false)}
          onBranchCreated={() => {
            refreshBranches(currentProjectDir);
            refreshGitStatus(currentProjectDir);
          }}
        />
      )}

      {/* Stash List Modal */}
      {showStashList && currentProjectDir && (
        <div className="git-modal-overlay" onClick={() => setShowStashList(false)}>
          <div className="git-modal" onClick={(e) => e.stopPropagation()}>
            <div className="git-modal-header">
              <span>Stashes</span>
              <button 
                className="git-modal-close"
                onClick={() => setShowStashList(false)}
              >
                ✕
              </button>
            </div>
            <StashList
              projectDir={currentProjectDir}
              onStashPopped={() => {
                refreshGitStatus(currentProjectDir);
              }}
            />
          </div>
        </div>
      )}

      {/* Tags List Modal */}
      {showTagsList && currentProjectDir && (
        <div className="git-modal-overlay" onClick={() => setShowTagsList(false)}>
          <div className="git-modal" onClick={(e) => e.stopPropagation()}>
            <div className="git-modal-header">
              <span>Tags</span>
              <button 
                className="git-modal-close"
                onClick={() => setShowTagsList(false)}
              >
                ✕
              </button>
            </div>
            <TagsList
              projectDir={currentProjectDir}
              onTagDeleted={() => {
                refreshGitStatus(currentProjectDir);
              }}
            />
          </div>
        </div>
      )}

      {/* Remotes List Modal */}
      {showRemotesList && currentProjectDir && (
        <div className="git-modal-overlay" onClick={() => setShowRemotesList(false)}>
          <div className="git-modal" onClick={(e) => e.stopPropagation()}>
            <div className="git-modal-header">
              <span>Remotes</span>
              <button 
                className="git-modal-close"
                onClick={() => setShowRemotesList(false)}
              >
                ✕
              </button>
            </div>
            <RemotesList
              projectDir={currentProjectDir}
              onRemoteAdded={() => {
                refreshGitStatus(currentProjectDir);
              }}
            />
          </div>
        </div>
      )}

      {/* Conflict Resolver Modal */}
      {showConflictResolver && currentProjectDir && (
        <div className="git-modal-overlay" onClick={() => setShowConflictResolver(false)}>
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              background: '#1e1e1e',
              border: '1px solid #3e3e42',
              borderRadius: 4,
              display: 'flex',
              flexDirection: 'column',
              width: '92vw',
              height: '88vh',
              overflow: 'hidden',
              boxShadow: '0 8px 32px rgba(0,0,0,0.6)',
            }}
          >
            <div className="git-modal-header">
              <span>Resolve Merge Conflicts</span>
              <button className="git-modal-close" onClick={() => setShowConflictResolver(false)}>✕</button>
            </div>
            <div style={{ flex: 1, overflow: 'hidden', minHeight: 0 }}>
              <ConflictResolver
                projectDir={currentProjectDir}
                onMergeComplete={() => {
                  setShowConflictResolver(false);
                  refreshGitStatus(currentProjectDir);
                }}
              />
            </div>
          </div>
        </div>
      )}

      {/* File History Modal */}
      {showFileHistory && fileHistoryPath && (
        <div className="git-modal-overlay" onClick={() => setShowFileHistory(false)}>
          <div className="git-modal git-file-history-modal" onClick={(e) => e.stopPropagation()}>
            <div className="git-modal-header">
              <span>History: {fileHistoryPath.split('/').pop()}</span>
              <button 
                className="git-modal-close"
                onClick={() => setShowFileHistory(false)}
              >
                ✕
              </button>
            </div>
            <div className="git-file-history-content">
              {fileHistoryLoading && !fileHistoryCommits.length && <div className="git-search-loading">Loading history...</div>}
              {!fileHistoryLoading && fileHistoryCommits.length === 0 && (
                <div className="git-search-empty">No history found</div>
              )}
              {fileHistoryCommits.length > 0 && (
                <div className="git-file-history-list">
                  {fileHistoryCommits.map((commit) => (
                    <HistoryItem key={commit.hash} commit={commit} />
                  ))}
                  {hasMoreHistory && (
                    <div className="git-history-load-more">
                      <button 
                        onClick={() => handleGetFileHistory(fileHistoryPath, true)}
                        disabled={fileHistoryLoading}
                        className="git-btn-secondary"
                      >
                        {fileHistoryLoading ? 'Loading...' : 'Load More'}
                      </button>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

// Export keyboard shortcut handlers to window for use by main.tsx
export function exposeGitKeyboardHandlers() {
  return {
    gitShowBranchSelector: () => {
      // This will be implemented by GitPanel setting a ref
      const event = new CustomEvent('git:showBranchSelector');
      window.dispatchEvent(event);
    },
    gitShowHistory: () => {
      const event = new CustomEvent('git:showHistory');
      window.dispatchEvent(event);
    },
    gitShowDiff: (filePath: string) => {
      const event = new CustomEvent('git:showDiff', { detail: { filePath } });
      window.dispatchEvent(event);
    },
    gitFocusCommit: () => {
      const event = new CustomEvent('git:focusCommit');
      window.dispatchEvent(event);
    },
    gitRefresh: () => {
      const event = new CustomEvent('git:refresh');
      window.dispatchEvent(event);
    }
  };
}


