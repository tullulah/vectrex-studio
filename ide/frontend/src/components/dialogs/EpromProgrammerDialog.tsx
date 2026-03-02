import React, { useState, useEffect, useRef } from 'react';
import '../../styles/Dialog.css';
import { storageGet, storageSet, StorageKey } from '../../services/persistentStorage';

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
  const [installing, setInstalling] = useState(false);
  const [installLog, setInstallLog] = useState<string[]>([]);
  const [platform, setPlatform] = useState<string>('');
  // Options
  const [skipIdCheck, setSkipIdCheck] = useState(false);
  const [skipVerify, setSkipVerify] = useState(false);
  const [eraseFirst, setEraseFirst] = useState(false);
  // Advanced: voltage & timing overrides (write mode only)
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [vpp, setVpp] = useState('');
  const [vdd, setVdd] = useState('');
  const [vcc, setVcc] = useState('');
  const [pulse, setPulse] = useState('');

  // Load saved settings when chip changes
  useEffect(() => {
    storageGet<Record<string, any>>(StorageKey.EPROM_CHIP_CONFIGS).then(all => {
      const cfg = all?.[chip];
      if (cfg) {
        if (cfg.vpp   !== undefined) setVpp(cfg.vpp);
        if (cfg.vdd   !== undefined) setVdd(cfg.vdd);
        if (cfg.vcc   !== undefined) setVcc(cfg.vcc);
        if (cfg.pulse !== undefined) setPulse(cfg.pulse);
        if (cfg.skipIdCheck !== undefined) setSkipIdCheck(cfg.skipIdCheck);
        if (cfg.skipVerify  !== undefined) setSkipVerify(cfg.skipVerify);
        if (cfg.eraseFirst  !== undefined) setEraseFirst(cfg.eraseFirst);
      } else {
        // Reset to defaults when switching to a chip with no saved config
        setVpp(''); setVdd(''); setVcc(''); setPulse('');
        setSkipIdCheck(false); setSkipVerify(false); setEraseFirst(false);
      }
    });
  }, [chip]);

  // Save settings for the current chip whenever any option changes
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(async () => {
      const all = (await storageGet<Record<string, any>>(StorageKey.EPROM_CHIP_CONFIGS)) ?? {};
      all[chip] = { vpp, vdd, vcc, pulse, skipIdCheck, skipVerify, eraseFirst };
      storageSet(StorageKey.EPROM_CHIP_CONFIGS, all);
    }, 400);
  }, [chip, vpp, vdd, vcc, pulse, skipIdCheck, skipVerify, eraseFirst]);

  useEffect(() => {
    const checkMinipro = async () => {
      const eprom = (window as any).eprom;
      if (!eprom) {
        setMiniproFound(false);
        setError('EPROM API not available');
        return;
      }
      // Get platform
      const platResult = await eprom.platform?.();
      if (platResult?.platform) setPlatform(platResult.platform);

      const result = await eprom.detect();
      if (result?.ok) {
        setMiniproFound(true);
        setMiniproVersion(result.version || '');
      } else {
        setMiniproFound(false);
        setError(result?.error || 'minipro not found');
      }
    };
    checkMinipro();
  }, []);

  // Listen for install progress
  useEffect(() => {
    const eprom = (window as any).eprom;
    if (!eprom?.onInstallProgress) return;
    const cleanup = eprom.onInstallProgress((chunk: string) => {
      const lines = chunk.split('\n').filter((l: string) => l.trim());
      setInstallLog(prev => [...prev, ...lines]);
    });
    return cleanup;
  }, []);

  const addLog = (msg: string) => {
    setLog(prev => [...prev, msg]);
  };

  const handleInstall = async () => {
    const eprom = (window as any).eprom;
    if (!eprom?.install) return;

    setInstalling(true);
    setInstallLog([]);
    setError(null);

    const installCmd = platform === 'darwin' ? 'brew install minipro' 
      : platform === 'linux' ? 'sudo apt-get install -y minipro'
      : 'winget / choco install';
    setInstallLog([`Running: ${installCmd}`, '']);

    const result = await eprom.install();

    if (result?.ok) {
      setInstallLog(prev => [...prev, '', '✓ minipro installed successfully!']);
      // Re-detect
      const detect = await eprom.detect();
      if (detect?.ok) {
        setMiniproFound(true);
        setMiniproVersion(detect.version || '');
        setError(null);
      }
    } else {
      setInstallLog(prev => [...prev, '', `✗ Install failed: ${result?.error || 'Unknown error'}`]);
      if (result?.error) setError(result.error);
    }
    setInstalling(false);
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
      skipIdCheck,
      skipVerify,
      eraseFirst,
      vpp: vpp || undefined,
      vdd: vdd || undefined,
      vcc: vcc || undefined,
      pulse: pulse || undefined,
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
      skipIdCheck,
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

    const result = await eprom.blankCheck({ chip, programmer, skipIdCheck });

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

  const isWorking = status === 'writing' || status === 'verifying' || status === 'detecting' || installing;

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
          {miniproFound === false && !installing && (
            <div className="dialog-error" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div>
                <strong>minipro not found.</strong><br/>
                <span style={{ fontSize: 12 }}>
                  {platform === 'darwin' && 'Install via Homebrew with one click, or manually from source.'}
                  {platform === 'linux' && 'Install via apt or build from source.'}
                  {platform === 'win32' && 'Install via winget/choco or download from the releases page.'}
                  {!platform && 'Install from source or via your package manager.'}
                </span>
              </div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <button
                  onClick={handleInstall}
                  style={{
                    background: '#0098ff',
                    color: '#fff',
                    border: 'none',
                    borderRadius: 3,
                    padding: '6px 16px',
                    fontSize: 12,
                    fontWeight: 600,
                    cursor: 'pointer',
                  }}
                >
                  {platform === 'darwin' ? '⬇ Install (brew)' : platform === 'linux' ? '⬇ Install (apt)' : '⬇ Install'}
                </button>
                <a
                  href="https://gitlab.com/DavidGriffith/minipro"
                  target="_blank"
                  rel="noreferrer"
                  style={{ color: '#569cd6', fontSize: 11 }}
                >
                  Manual install →
                </a>
              </div>
            </div>
          )}

          {/* Install progress */}
          {installing && (
            <div style={{
              background: '#1a1a1a',
              border: '1px solid #2d2d30',
              borderRadius: 3,
              padding: '8px 12px',
              maxHeight: 180,
              overflowY: 'auto',
              fontFamily: "'Consolas', 'Monaco', 'Courier New', monospace",
              fontSize: 11,
              color: '#cccccc',
              lineHeight: '1.5',
            }}>
              <div style={{ marginBottom: 6, color: '#0098ff', fontWeight: 600 }}>Installing minipro...</div>
              {installLog.map((line, i) => (
                <div key={i} style={{ color: line.startsWith('✓') ? '#4ec9b0' : line.startsWith('✗') ? '#f48771' : '#cccccc' }}>
                  {line || '\u00A0'}
                </div>
              ))}
              {installing && <div style={{ color: '#858585' }}>⏳ Please wait...</div>}
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

          {/* Options */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, padding: '4px 0' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: '#cccccc', cursor: 'pointer' }}>
              <input type="checkbox" checked={skipIdCheck} onChange={e => setSkipIdCheck(e.target.checked)} disabled={isWorking}
                style={{ accentColor: '#0098ff' }} />
              Skip chip ID check <span style={{ color: '#858585', fontSize: 11 }}>(-y)</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: '#cccccc', cursor: 'pointer' }}>
              <input type="checkbox" checked={skipVerify} onChange={e => setSkipVerify(e.target.checked)} disabled={isWorking}
                style={{ accentColor: '#0098ff' }} />
              Skip verification after write <span style={{ color: '#858585', fontSize: 11 }}>(-v)</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: '#cccccc', cursor: 'pointer' }}>
              <input type="checkbox" checked={eraseFirst} onChange={e => setEraseFirst(e.target.checked)} disabled={isWorking}
                style={{ accentColor: '#0098ff' }} />
              Erase before write <span style={{ color: '#858585', fontSize: 11 }}>(flash chips only)</span>
            </label>
          </div>

          {/* Advanced — voltage & timing overrides (write mode only) */}
          <div>
            <button
              onClick={() => setShowAdvanced(v => !v)}
              style={{ background: 'none', border: 'none', color: '#858585', fontSize: 11, cursor: 'pointer', padding: 0, display: 'flex', alignItems: 'center', gap: 4 }}
            >
              {showAdvanced ? '▾' : '▸'} Advanced (VPP / VDD / VCC / Pulse)
            </button>
            {showAdvanced && (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '6px 12px', marginTop: 6 }}>
                <label style={{ fontSize: 11, color: '#cccccc' }}>
                  VPP (programming V)
                  <select value={vpp} onChange={e => setVpp(e.target.value)} disabled={isWorking}
                    style={{ display: 'block', width: '100%', marginTop: 2, background: '#2d2d2d', color: '#cccccc', border: '1px solid #454545', borderRadius: 3, padding: '2px 4px', fontSize: 11 }}>
                    <option value="">chip default</option>
                    {['9','9.5','10','11','11.5','12','12.5','13','13.5','14','14.5','15.5','16','16.5','17','18','21'].map(v => <option key={v} value={v}>{v} V</option>)}
                  </select>
                </label>
                <label style={{ fontSize: 11, color: '#cccccc' }}>
                  VDD (write V)
                  <select value={vdd} onChange={e => setVdd(e.target.value)} disabled={isWorking}
                    style={{ display: 'block', width: '100%', marginTop: 2, background: '#2d2d2d', color: '#cccccc', border: '1px solid #454545', borderRadius: 3, padding: '2px 4px', fontSize: 11 }}>
                    <option value="">chip default</option>
                    {['3.3','4','4.5','5','5.5','6.5'].map(v => <option key={v} value={v}>{v} V</option>)}
                  </select>
                </label>
                <label style={{ fontSize: 11, color: '#cccccc' }}>
                  VCC (verify V)
                  <select value={vcc} onChange={e => setVcc(e.target.value)} disabled={isWorking}
                    style={{ display: 'block', width: '100%', marginTop: 2, background: '#2d2d2d', color: '#cccccc', border: '1px solid #454545', borderRadius: 3, padding: '2px 4px', fontSize: 11 }}>
                    <option value="">chip default</option>
                    {['3.3','4','4.5','5','5.5','6.5'].map(v => <option key={v} value={v}>{v} V</option>)}
                  </select>
                </label>
                <label style={{ fontSize: 11, color: '#cccccc' }}>
                  Pulse delay (µs)
                  <input type="number" min={0} max={65535} value={pulse} onChange={e => setPulse(e.target.value)} disabled={isWorking}
                    placeholder="chip default"
                    style={{ display: 'block', width: '100%', marginTop: 2, background: '#2d2d2d', color: '#cccccc', border: '1px solid #454545', borderRadius: 3, padding: '2px 4px', fontSize: 11, boxSizing: 'border-box' }} />
                </label>
              </div>
            )}
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
