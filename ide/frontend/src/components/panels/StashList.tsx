import React, { useState, useEffect } from 'react';
import '../panels/GitPanel.css';

interface Stash {
  index: number;
  hash: string;
  fullHash: string;
  message: string;
  date: string;
}

interface StashListProps {
  projectDir: string;
  onStashPopped?: () => void;
}

export const StashList: React.FC<StashListProps> = ({ projectDir, onStashPopped }) => {
  const [stashes, setStashes] = useState<Stash[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadStashes = async () => {
      try {
        setLoading(true);
        const git = (window as any).git;
        const result = await git.stashList(projectDir);

        if (!result.ok) {
          setError(result.error || 'Failed to load stashes');
          return;
        }

        setStashes(result.stashes || []);
        setError(null);
      } catch (err) {
        setError(String(err));
      } finally {
        setLoading(false);
      }
    };

    if (projectDir) {
      loadStashes();
    }
  }, [projectDir]);

  const handlePopStash = async (index: number) => {
    try {
      const git = (window as any).git;
      const result = await git.stashPop({ projectDir, index });

      if (result.ok) {
        alert('Stash applied successfully');
        // Reload stash list
        const listResult = await git.stashList(projectDir);
        if (listResult.ok) {
          setStashes(listResult.stashes || []);
        }
        onStashPopped?.();
      } else {
        alert(`Failed to apply stash: ${result.error}`);
      }
    } catch (err) {
      alert(`Error applying stash: ${err}`);
    }
  };

  const formatDate = (dateStr: string): string => {
    try {
      const date = new Date(dateStr);
      return date.toLocaleDateString('es-ES', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return dateStr;
    }
  };

  const btnStyle: React.CSSProperties = {
    background: '#2d2d30',
    border: '1px solid #3e3e42',
    color: '#cccccc',
    padding: '3px 8px',
    borderRadius: 3,
    fontSize: 11,
    cursor: 'pointer',
    whiteSpace: 'nowrap',
    flexShrink: 0,
  };

  return (
    <div style={{ fontSize: 12, color: '#cccccc' }}>
      <div style={{ maxHeight: 400, overflow: 'auto' }}>
        {loading && <div style={{ padding: '8px', color: '#6a6a6a' }}>Loading stashes...</div>}
        {error && <div style={{ padding: '8px', color: '#f44' }}>Error: {error}</div>}

        {!loading && !error && stashes.length === 0 && (
          <div style={{ padding: '8px', color: '#6a6a6a', fontStyle: 'italic' }}>No stashes found</div>
        )}

        {!loading && !error && stashes.map((stash) => (
          <div
            key={stash.index}
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              background: '#2a2d2e',
              border: '1px solid #3e3e42',
              borderRadius: 2,
              padding: '6px 8px',
              marginBottom: 4,
              gap: 8,
            }}
          >
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: 'monospace', color: '#0098ff', fontWeight: 600, fontSize: 11 }}>{stash.hash}</div>
              <div style={{ color: '#cccccc', fontSize: 11, marginTop: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{stash.message}</div>
              <div style={{ color: '#6a6a6a', fontSize: 10, marginTop: 1 }}>{formatDate(stash.date)}</div>
            </div>
            <button style={btnStyle} onClick={() => handlePopStash(stash.index)}>
              Apply
            </button>
          </div>
        ))}
      </div>
    </div>
  );
};
