import React, { useState, useEffect } from 'react';
import '../../styles/Dialog.css';

/** Common EPROM chips for Vectrex cartridges */
const CHIP_PRESETS = [
  { label: '27C256 (32 KB)', value: 'AT27C256R@DIP28' },
  { label: '27C512 (64 KB)', value: 'AT27C512R@DIP28' },
  { label: '27C128 (16 KB)', value: 'AT27C128@DIP28' },
  { label: '27C010 (128 KB)', value: 'W27C010@DIP32' },
  { label: '27C020 (256 KB)', value: 'W27C020@DIP32' },
  { label: '27C040 (512 KB)', value: 'W27C040@DIP32' },
  { label: 'SST39SF010A (128 KB)', value: 'SST39SF010A@DIP32' },
  { label: 'SST39SF020A (256 KB)', value: 'SST39SF020A@DIP32' },
  { label: 'SST39SF040 (512 KB)', value: 'SST39SF040@DIP32' },
];

const PROGRAMMERS = [
  { label: 'TL866II Plus', value: 'TL866II+' },
  { label: 'TL866A', value: 'TL866A' },
  { label: 'TL866CS', value: 'TL866CS' },
  { label: 'T48', value: 'T48' },
  { label: 'T56', value: 'T56' },
];

type ProgramStatus = 'idle' | 'detecting' | 'writing' | 'verifying' | 'success' | 'error';

interface EpromProgrammerDialogProps {
  binPath: string | null;
  onClose: () => void;
}

export const EpromProgrammerDialog: React.FC<EpromProgrammerDialogProps> = ({
  binPath,
  onClose,
}) => {
  const [programmer, setProgrammer] = useState(PROGRAMMERS[0].value);
  const [chip, setChip] = useState(CHIP_PRESETS[0].value);
  const [status, setStatus] = useState<ProgramStatus>('idle');
  const [log, setLog] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [miniproFound, setMiniproFound] = useState<boolean | null>(null);
  const [miniproVersion, setMiniproVersion] = useState<string>('');

  // Check if minipro is available on mount
  useEffect(() => {
    const checkMinipro = async () => {
      const eprom = (window as any).eprom;
      if (!eprom) {
        setMiniproFound(false);
        setError('EPROM API not available');
        return;
      }
      const result = await eprom.detect();
      if (result?.ok) {
        setMiniproFound(true);
        setMiniproVersion(result.version || '');
      } else {
        setMiniproFound(false);
        setError(result?.error || 'minipro not found. Install it from https://gitlab.com/DavidGriffith/minipro');
      }
    };
    checkMinipro();
  }, []);

  const addLog = (msg: string) => {
    setLog(prev => [...prev, msg]);
  };

  const handleWrite = async () => {
    if (!binPath) {
      setError('No .bin file available. Compile your project first.');
      return;
    }

    const eprom = (window as any).eprom;
    if (!eprom) return;

    setStatus('writing');
    setError(null);
    setLog([]);
    addLog(`Programmer: ${programmer}`);
    addLog(`Chip: ${chip}`);
    addLog(`ROM file: ${binPath}`);
    addLog('');
    addLog('Writing...');

    const result = await eprom.write({
      binPath,
      chip,
      programmer,
    });

    if (result?.ok) {
      addLog('');
      addLog('✓ Write complete!');
      if (result.stdout) {
        result.stdout.split('\n').filter((l: string) => l.trim()).forEach((l: string) => addLog(l));
      }
      setStatus('success');
    } else {
      addLog('');
      addLog('✗ Write failed!');
      if (result?.stderr) {
        result.stderr.split('\n').filter((l: string) => l.trim()).forEach((l: string) => addLog(l));
      }
      setError(result?.error || 'Write failed');
      setStatus('error');
    }
  };

  const handleVerify = async () => {
    if (!binPath) {
      setError('No .bin file available. Compile your project first.');
      return;
    }

    const eprom = (window as any).eprom;
    if (!eprom) return;

    setStatus('verifying');
    setError(null);
    setLog([]);
    addLog(`Verifying chip against: ${binPath}`);
    addLog('');

    const result = await eprom.verify({
      binPath,
      chip,
      programmer,
    });

    if (result?.ok) {
      addLog('✓ Verification passed!');
      if (result.stdout) {
        result.stdout.split('\n').filter((l: string) => l.trim()).forEach((l: string) => addLog(l));
      }
      setStatus('success');
    } else {
      addLog('✗ Verification failed!');
      if (result?.stderr) {
        result.stderr.split('\n').filter((l: string) => l.trim()).forEach((l: string) => addLog(l));
      }
      setError(result?.error || 'Verification failed');
      setStatus('error');
    }
  };

  const handleBlankCheck = async () => {
    const eprom = (window as any).eprom;
    if (!eprom) return;

    setStatus('detecting');
    setError(null);
    setLog([]);
    addLog('Checking if chip is blank...');

    const result = await eprom.blankCheck({ chip, programmer });

    if (result?.ok) {
      addLog('✓ Chip is blank and ready to program.');
      setStatus('idle');
    } else {
      addLog('✗ Chip is NOT blank.');
      if (result?.stderr) {
        result.stderr.split('\n').filter((l: string) => l.trim()).forEach((l: string) => addLog(l));
      }
      setError(result?.error || 'Chip is not blank');
      setStatus('error');
    }
  };

  const isWorking = status === 'writing' || status === 'verifying' || status === 'detecting';

  return (
    <div className="dialog-overlay" onClick={onClose}>
      <div className="dialog-modal" style={{ maxWidth: 560 }} onClick={(e) => e.stopPropagation()}>
        <div className="dialog-header">
          <h2>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ verticalAlign: 'text-bottom', marginRight: 8 }}>
              <rect x="4" y="2" width="16" height="20" rx="1"/>
              <line x1="4" y1="6" x2="2" y2="6"/>
              <line x1="4" y1="10" x2="2" y2="10"/>
              <line x1="4" y1="14" x2="2" y2="14"/>
              <line x1="4" y1="18" x2="2" y2="18"/>
              <line x1="20" y1="6" x2="22" y2="6"/>
              <line x1="20" y1="10" x2="22" y2="10"/>
              <line x1="20" y1="14" x2="22" y2="14"/>
              <line x1="20" y1="18" x2="22" y2="18"/>
              <circle cx="12" cy="9" r="2"/>
              <path d="M10 18h4"/>
            </svg>
            EPROM Programmer
          </h2>
          <button className="dialog-close" onClick={onClose}>✕</button>
        </div>

        <div className="dialog-content">
          {/* minipro status */}
          {miniproFound === false && (
            <div className="dialog-error">
              <strong>minipro not found.</strong><br/>
              Install from: <a href="https://gitlab.com/DavidGriffith/minipro" target="_blank" rel="noreferrer" style={{ color: '#569cd6' }}>gitlab.com/DavidGriffith/minipro</a>
              <br/><br/>
              <span style={{ fontSize: 11, color: '#999' }}>
                macOS: <code>brew install minipro</code><br/>
                Linux: build from source or use package manager<br/>
                Windows: download from releases page
              </span>
            </div>
          )}

          {miniproFound && miniproVersion && (
            <div className="dialog-info" style={{ color: '#4ec9b0' }}>
              ✓ minipro detected: {miniproVersion}
            </div>
          )}

          {/* Programmer selection */}
          <div className="dialog-field">
            <label>Programmer</label>
            <select
              value={programmer}
              onChange={(e) => setProgrammer(e.target.value)}
              disabled={isWorking}
              style={{
                background: '#3c3c3c',
                border: '1px solid #3e3e42',
                color: '#cccccc',
                padding: '8px 12px',
                borderRadius: 3,
                fontSize: 12,
              }}
            >
              {PROGRAMMERS.map(p => (
                <option key={p.value} value={p.value}>{p.label}</option>
              ))}
            </select>
          </div>

          {/* Chip selection */}
          <div className="dialog-field">
            <label>EPROM Chip</label>
            <select
              value={chip}
              onChange={(e) => setChip(e.target.value)}
              disabled={isWorking}
              style={{
                background: '#3c3c3c',
                border: '1px solid #3e3e42',
                color: '#cccccc',
                padding: '8px 12px',
                borderRadius: 3,
                fontSize: 12,
              }}
            >
              {CHIP_PRESETS.map(c => (
                <option key={c.value} value={c.value}>{c.label}</option>
              ))}
            </select>
          </div>

          {/* ROM file info */}
          <div className="dialog-info">
            <span>ROM: {binPath ? <code>{binPath.split('/').pop()}</code> : <em style={{ color: '#f48771' }}>No .bin file — compile first</em>}</span>
          </div>

          {/* Log output */}
          {log.length > 0 && (
            <div style={{
              background: '#1a1a1a',
              border: '1px solid #2d2d30',
              borderRadius: 3,
              padding: '8px 12px',
              maxHeight: 150,
              overflowY: 'auto',
              fontFamily: "'Consolas', 'Monaco', 'Courier New', monospace",
              fontSize: 11,
              color: status === 'success' ? '#4ec9b0' : status === 'error' ? '#f48771' : '#cccccc',
              lineHeight: '1.5',
            }}>
              {log.map((line, i) => (
                <div key={i}>{line || '\u00A0'}</div>
              ))}
            </div>
          )}

          {error && status !== 'error' && <div className="dialog-error">{error}</div>}
        </div>

        <div className="dialog-actions" style={{ justifyContent: 'space-between' }}>
          <button
            className="dialog-cancel-btn"
            onClick={handleBlankCheck}
            disabled={isWorking || !miniproFound}
            style={{ marginRight: 'auto' }}
          >
            Blank Check
          </button>
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              className="dialog-cancel-btn"
              onClick={handleVerify}
              disabled={isWorking || !miniproFound || !binPath}
            >
              Verify
            </button>
            <button
              className="dialog-confirm-btn"
              onClick={handleWrite}
              disabled={isWorking || !miniproFound || !binPath}
            >
              {status === 'writing' ? 'Writing...' : 'Write EPROM'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
