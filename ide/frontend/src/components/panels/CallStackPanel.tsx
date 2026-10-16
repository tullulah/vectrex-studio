import React from 'react';
import { useTranslation } from 'react-i18next';
import { useDebugStore } from '../../state/debugStore';
import { showProjectSource } from '../../debug/showSource';

/**
 * The paused program's call stack, innermost first (m6809: debug/pdbSource.ts; rp2350
 * and uvm2: debug/armCallStack.ts). A VPy frame opens its line on click; the runtime's
 * and the firmware's frames show where they are.
 */
export const CallStackPanel: React.FC = () => {
  const { t } = useTranslation(['common']);
  const callStack = useDebugStore((s) => s.callStack);
  const state = useDebugStore((s) => s.state);

  if (!callStack.length) {
    return (
      <div style={{ padding: 8, color: '#888', fontSize: 12 }}>
        {state === 'paused'
          ? t('callstack.none', 'No call stack here (no debug info for this code).')
          : t('callstack.empty', 'Shown while the program is paused at a breakpoint or a step.')}
      </div>
    );
  }
  return (
    <div style={{ padding: 4, overflowY: 'auto', height: '100%' }}>
      {callStack.map((f, i) => {
        const clickable = f.type === 'vpy' && !!f.file && !!f.line;
        return (
          <div
            key={i}
            onClick={() => { if (clickable) showProjectSource(f.file!, f.line!); }}
            title={f.address}
            style={{
              padding: '3px 8px',
              borderBottom: '1px solid #333',
              fontFamily: 'monospace',
              fontSize: '13px',
              display: 'flex',
              justifyContent: 'space-between',
              gap: 12,
              cursor: clickable ? 'pointer' : 'default',
              color: f.type === 'vpy' ? '#DCDCAA' : '#888',
              background: i === 0 ? 'rgba(255,255,0,0.06)' : undefined,
            }}
          >
            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.function}</span>
            <span style={{ color: '#888', whiteSpace: 'nowrap' }}>{f.file && f.line ? `${f.file}:${f.line}` : f.address}</span>
          </div>
        );
      })}
    </div>
  );
};

export default CallStackPanel;
