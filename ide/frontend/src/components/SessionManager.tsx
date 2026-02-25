import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';

// Use the backend session type from global window definitions
type Session = PyPilotSession;

interface SessionManagerProps {
  projectPath: string;
  currentSessionId: number | null;
  onSessionChange: (sessionId: number) => void;
  onNewSession: () => void;
}

export const SessionManager: React.FC<SessionManagerProps> = ({
  projectPath,
  currentSessionId,
  onSessionChange,
  onNewSession
}) => {
  const { t } = useTranslation(['common']);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [showDropdown, setShowDropdown] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editName, setEditName] = useState('');

  useEffect(() => {
    loadSessions();
  }, [projectPath]);

  const loadSessions = async () => {
    if (!projectPath || !window.pypilot) return;
    
    const result = await window.pypilot.getSessions(projectPath);
    if (result.success && result.sessions) {
      setSessions(result.sessions);
    }
  };

  const handleSwitchSession = async (sessionId: number) => {
    if (!window.pypilot) return;
    
    const result = await window.pypilot.switchSession(sessionId);
    if (result.success) {
      onSessionChange(sessionId);
      setShowDropdown(false);
      await loadSessions();
    }
  };

  const handleRename = async (sessionId: number) => {
    if (!window.pypilot || !editName.trim()) return;
    
    const result = await window.pypilot.renameSession(sessionId, editName.trim());
    if (result.success) {
      setEditingId(null);
      setEditName('');
      await loadSessions();
    }
  };

  const handleDelete = async (sessionId: number) => {
    if (!window.pypilot) return;

    if (!confirm(t('session.deleteConfirm', 'Delete this session? All history will be lost.'))) {
      return;
    }

    const result = await window.pypilot.deleteSession(sessionId);
    if (result.success) {
      // If we deleted the active session, create a new one
      if (sessionId === currentSessionId) {
        onNewSession();
      }
      await loadSessions();
    }
  };

  const currentSession = sessions.find(s => s.id === currentSessionId);
  const messageCount = sessions.find(s => s.id === currentSessionId)?.id;

  return (
    <div className="session-manager" style={{ position: 'relative', display: 'flex', gap: '8px', alignItems: 'center' }}>
      {/* Current Session Display */}
      <div 
        className="current-session"
        onClick={() => setShowDropdown(!showDropdown)}
        style={{
          padding: '6px 12px',
          background: 'var(--vscode-input-background)',
          border: '1px solid var(--vscode-input-border)',
          borderRadius: '4px',
          cursor: 'pointer',
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          minWidth: '200px'
        }}
      >
        <span style={{ fontSize: '12px', opacity: 0.7 }}>💬</span>
        <span style={{ flex: 1, fontSize: '13px' }}>
          {currentSession?.name || t('session.noActive', 'No session')}
        </span>
        <span style={{ fontSize: '10px', opacity: 0.5 }}>▼</span>
      </div>

      {/* New Session Button */}
      <button
        onClick={onNewSession}
        title={t('session.newSession', 'New session')}
        style={{
          padding: '6px 12px',
          background: 'var(--vscode-button-background)',
          color: 'var(--vscode-button-foreground)',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
          fontSize: '13px'
        }}
      >
        {t('session.newLabel', '+ New')}
      </button>

      {/* Dropdown */}
      {showDropdown && (
        <>
          <div 
            style={{
              position: 'fixed',
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              zIndex: 998
            }}
            onClick={() => setShowDropdown(false)}
          />
          <div
            className="session-dropdown"
            style={{
              position: 'absolute',
              top: '100%',
              left: 0,
              marginTop: '4px',
              background: 'var(--vscode-dropdown-background, #252526)',
              border: '1px solid var(--vscode-dropdown-border, #3c3c3c)',
              borderRadius: '4px',
              boxShadow: '0 4px 8px rgba(0,0,0,0.3)',
              minWidth: '300px',
              maxHeight: '400px',
              overflowY: 'auto',
              zIndex: 999,
              color: 'var(--vscode-dropdown-foreground, #cccccc)'
            }}
          >
            <div style={{ padding: '8px', borderBottom: '1px solid var(--vscode-input-border)' }}>
              <div style={{ fontSize: '11px', opacity: 0.7, marginBottom: '4px' }}>
                {t('session.section', 'PROJECT SESSIONS')}
              </div>
            </div>

            {sessions.length === 0 ? (
              <div style={{ padding: '16px', textAlign: 'center', opacity: 0.5, fontSize: '12px' }}>
                {t('session.empty', 'No sessions')}
              </div>
            ) : (
              sessions.map(session => (
                <div
                  key={session.id}
                  style={{
                    padding: '8px 12px',
                    borderBottom: '1px solid var(--vscode-input-border)',
                    background: session.id === currentSessionId ? 'var(--vscode-list-activeSelectionBackground)' : 'transparent',
                    cursor: 'pointer'
                  }}
                >
                  {editingId === session.id ? (
                    <div style={{ display: 'flex', gap: '4px' }}>
                      <input
                        type="text"
                        value={editName}
                        onChange={(e) => setEditName(e.target.value)}
                        onKeyPress={(e) => e.key === 'Enter' && handleRename(session.id)}
                        autoFocus
                        style={{
                          flex: 1,
                          padding: '4px',
                          background: 'var(--vscode-input-background)',
                          border: '1px solid var(--vscode-input-border)',
                          color: 'var(--vscode-input-foreground)',
                          fontSize: '12px'
                        }}
                      />
                      <button onClick={() => handleRename(session.id)} style={{ padding: '4px 8px', fontSize: '11px' }}>✓</button>
                      <button onClick={() => setEditingId(null)} style={{ padding: '4px 8px', fontSize: '11px' }}>✕</button>
                    </div>
                  ) : (
                    <div onClick={() => handleSwitchSession(session.id)}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                        <span style={{ fontSize: '13px', fontWeight: session.id === currentSessionId ? 'bold' : 'normal' }}>
                          {session.name}
                        </span>
                        {session.isActive && (
                          <span style={{ fontSize: '10px', background: 'var(--vscode-badge-background)', padding: '2px 6px', borderRadius: '8px' }}>
                            {t('session.active', 'Active')}
                          </span>
                        )}
                      </div>
                      <div style={{ fontSize: '11px', opacity: 0.6 }}>
                        {new Date(session.lastActivity).toLocaleString()}
                      </div>
                      <div style={{ marginTop: '4px', display: 'flex', gap: '8px' }}>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setEditingId(session.id);
                            setEditName(session.name);
                          }}
                          style={{ fontSize: '11px', padding: '2px 8px' }}
                        >
                          {t('session.rename', 'Rename')}
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDelete(session.id);
                          }}
                          style={{ fontSize: '11px', padding: '2px 8px', color: 'var(--vscode-errorForeground)' }}
                        >
                          {t('session.delete', 'Delete')}
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ))
            )}
          </div>
        </>
      )}
    </div>
  );
};
