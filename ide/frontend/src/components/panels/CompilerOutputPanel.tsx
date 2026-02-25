import React, { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { logger } from '../../utils/logger.js';

export const CompilerOutputPanel: React.FC = () => {
  const { t } = useTranslation(['common']);
  const [output, setOutput] = useState<string>('');
  const scrollRef = useRef<HTMLDivElement>(null);
  const [autoScroll, setAutoScroll] = useState(true);

  useEffect(() => {
    const electronAPI = (window as any).electronAPI;
    if (!electronAPI) return;

    // Listen for stdout (compilation phases, progress)
    const stdoutHandler = (text: string) => {
      setOutput(prev => prev + text);
      if (autoScroll && scrollRef.current) {
        setTimeout(() => {
          if (scrollRef.current) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
          }
        }, 0);
      }
    };

    // Listen for stderr (errors, warnings)
    const stderrHandler = (text: string) => {
      setOutput(prev => prev + text);
      if (autoScroll && scrollRef.current) {
        setTimeout(() => {
          if (scrollRef.current) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
          }
        }, 0);
      }
    };

    // Listen for status updates
    const statusHandler = (text: string) => {
      setOutput(prev => prev + `[STATUS] ${text}\n`);
      if (autoScroll && scrollRef.current) {
        setTimeout(() => {
          if (scrollRef.current) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
          }
        }, 0);
      }
    };

    // Register listeners
    if (electronAPI.onRunStdout) {
      electronAPI.onRunStdout(stdoutHandler);
      logger.debug('Build', 'Registered onRunStdout listener');
    }
    if (electronAPI.onRunStderr) {
      electronAPI.onRunStderr(stderrHandler);
      logger.debug('Build', 'Registered onRunStderr listener');
    }
    if (electronAPI.onRunStatus) {
      electronAPI.onRunStatus(statusHandler);
      logger.debug('Build', 'Registered onRunStatus listener');
    }

    // Cleanup is tricky since we don't have unregister functions
    // Electron handlers are persistent - we rely on component unmount
    return () => {
      logger.debug('Build', 'Panel unmounting');
    };
  }, [autoScroll]);

  const handleClear = () => {
    setOutput('');
    logger.info('Build', 'Output cleared');
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(output).then(() => {
      logger.info('Build', 'Output copied to clipboard');
    }).catch(err => {
      logger.error('Build', 'Failed to copy:', err);
    });
  };

  return (
    <div style={{ 
      height: '100%', 
      display: 'flex', 
      flexDirection: 'column',
      background: '#1e1e1e'
    }}>
      {/* Toolbar */}
      <div style={{
        padding: '4px 8px',
        borderBottom: '1px solid #333',
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        background: '#252526'
      }}>
        <span style={{ fontWeight: 600, color: '#cccccc', fontSize: 12 }}>
          {t('panel.compilerOutput', 'Compiler Output')}
        </span>
        <button
          onClick={handleClear}
          style={{
            marginLeft: 'auto',
            padding: '2px 8px',
            fontSize: 11,
            background: '#0e639c',
            color: 'white',
            border: 'none',
            borderRadius: 2,
            cursor: 'pointer'
          }}
          title={t('message.noBuildOutput', 'Clear output')}
        >
          {t('action.clear', 'Clear')}
        </button>
        <button
          onClick={handleCopy}
          style={{
            padding: '2px 8px',
            fontSize: 11,
            background: '#0e639c',
            color: 'white',
            border: 'none',
            borderRadius: 2,
            cursor: 'pointer'
          }}
          title={t('action.copy', 'Copy to clipboard')}
        >
          {t('action.copy', 'Copy')}
        </button>
        <label style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, color: '#cccccc' }}>
          <input
            type="checkbox"
            checked={autoScroll}
            onChange={e => setAutoScroll(e.target.checked)}
          />
          {t('status.autoScroll', 'Auto-scroll')}
        </label>
      </div>

      {/* Output content */}
      <div
        ref={scrollRef}
        style={{
          flex: 1,
          overflow: 'auto',
          padding: '8px',
          fontFamily: 'Consolas, "Courier New", monospace',
          fontSize: 12,
          lineHeight: 1.4,
          color: '#cccccc',
          whiteSpace: 'pre-wrap',
          wordBreak: 'break-word'
        }}
      >
        {output || <span style={{ color: '#666' }}>{t('message.noCompilerOutput', 'No output yet. Build a project to see compilation logs here.')}</span>}
      </div>
    </div>
  );
};
