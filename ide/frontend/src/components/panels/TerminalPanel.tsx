import React, { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useProjectStore } from '../../state/projectStore';
import {
  useTerminalStore,
  newTerminal,
  closeTerminal,
  attachTerminal,
  fitTerminal,
  focusTerminal,
  restartTerminal,
  buildClaudeLaunchLine,
  terminalPlatform,
  isTerminalAvailable,
} from '../../services/terminalSessions';

/** Root directory of the open project (or workspace); undefined → home dir. */
function currentProjectRoot(): string | undefined {
  const s = useProjectStore.getState();
  return s.vpyProject?.rootDir || s.project?.rootPath || undefined;
}

/** Opens a plain shell tab. Exported so commands (menu / shortcut) can use it. */
export function openShellTerminal(title: string) {
  return newTerminal({ title, cwd: currentProjectRoot() });
}

/** Opens a "Claude" tab that runs Claude Code (or explains how to install it). */
export function openClaudeTerminal(t: (k: string, d: string) => string) {
  const command = buildClaudeLaunchLine(terminalPlatform(), {
    notFound: t('terminal.claudeNotFound', 'Claude Code is not installed (or not on your PATH). Install it with:'),
    thenType: t('terminal.claudeThenType', 'then type: claude'),
  });
  return newTerminal({ title: 'Claude', cwd: currentProjectRoot(), command });
}

const btnStyle: React.CSSProperties = {
  padding: '2px 8px', fontSize: 11, background: 'transparent', color: '#cccccc',
  border: '1px solid #3c3c3c', borderRadius: 2, cursor: 'pointer', lineHeight: '16px',
};

export const TerminalPanel: React.FC = () => {
  const { t } = useTranslation(['common']);
  const tabs = useTerminalStore((s) => s.tabs);
  const activeKey = useTerminalStore((s) => s.activeKey);
  const setActive = useTerminalStore((s) => s.setActive);
  const rename = useTerminalStore((s) => s.rename);
  const bodyRef = useRef<HTMLDivElement>(null);
  const [editing, setEditing] = useState<string | null>(null);
  const [draft, setDraft] = useState('');

  const defaultTitle = useCallback(() => {
    const n = useTerminalStore.getState().tabs.length + 1;
    return `${t('terminal.defaultTitle', 'Terminal')} ${n}`;
  }, [t]);

  // First time the panel is shown with no terminals, open one (VS Code behaviour).
  useEffect(() => {
    if (isTerminalAvailable() && useTerminalStore.getState().tabs.length === 0) openShellTerminal(defaultTitle());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // (Re)attach every xterm host into this panel; only the active one is visible.
  useLayoutEffect(() => {
    const body = bodyRef.current;
    if (!body) return;
    for (const tab of tabs) attachTerminal(tab.key, body, tab.key === activeKey);
    if (activeKey) requestAnimationFrame(() => { fitTerminal(activeKey); focusTerminal(activeKey); });
  }, [tabs, activeKey]);

  // Refit on panel resize (dock splitter, window resize, tab becoming visible).
  useEffect(() => {
    const body = bodyRef.current;
    if (!body || typeof ResizeObserver === 'undefined') return;
    let raf = 0;
    const ro = new ResizeObserver(() => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const key = useTerminalStore.getState().activeKey;
        if (key) fitTerminal(key);
      });
    });
    ro.observe(body);
    return () => { cancelAnimationFrame(raf); ro.disconnect(); };
  }, []);

  const commitRename = () => {
    if (editing) rename(editing, draft);
    setEditing(null);
  };

  const activeTab = tabs.find((x) => x.key === activeKey);

  return (
    <div className="vpy-terminal" style={{ height: '100%', display: 'flex', flexDirection: 'column', background: '#1e1e1e' }}>
      <div style={{
        display: 'flex', alignItems: 'stretch', gap: 0, background: '#252526',
        borderBottom: '1px solid #333', minHeight: 26, overflow: 'hidden',
      }}>
        <div style={{ display: 'flex', alignItems: 'stretch', overflowX: 'auto', flex: 1, minWidth: 0 }}>
          {tabs.map((tab) => {
            const active = tab.key === activeKey;
            return (
              <div
                key={tab.key}
                onClick={() => setActive(tab.key)}
                onDoubleClick={() => { setEditing(tab.key); setDraft(tab.title); }}
                onMouseDown={(e) => { if (e.button === 1) { e.preventDefault(); closeTerminal(tab.key); } }}
                title={t('terminal.renameHint', 'Double-click to rename')}
                style={{
                  display: 'flex', alignItems: 'center', gap: 6, padding: '0 6px 0 10px',
                  fontSize: 12, cursor: 'pointer', whiteSpace: 'nowrap', userSelect: 'none',
                  color: active ? '#ffffff' : '#969696',
                  background: active ? '#1e1e1e' : 'transparent',
                  borderTop: active ? '1px solid #0e639c' : '1px solid transparent',
                  borderRight: '1px solid #333',
                  fontStyle: tab.exited ? 'italic' : 'normal',
                }}
              >
                {editing === tab.key ? (
                  <input
                    autoFocus
                    value={draft}
                    onChange={(e) => setDraft(e.target.value)}
                    onBlur={commitRename}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') commitRename();
                      else if (e.key === 'Escape') setEditing(null);
                      e.stopPropagation();
                    }}
                    onClick={(e) => e.stopPropagation()}
                    style={{ width: 110, fontSize: 12, background: '#3c3c3c', color: '#fff', border: '1px solid #0e639c', padding: '0 3px' }}
                  />
                ) : (
                  <span>{tab.title}{tab.exited ? ` (${t('terminal.exited', 'exited')})` : ''}</span>
                )}
                <button
                  onClick={(e) => { e.stopPropagation(); closeTerminal(tab.key); }}
                  title={t('terminal.close', 'Kill terminal')}
                  className="vpy-tab-close"
                  style={{
                    background: 'transparent', border: 'none', color: '#aaa', cursor: 'pointer', padding: 0,
                    fontSize: 13, lineHeight: 1, width: 16, height: 16, display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}
                >×</button>
              </div>
            );
          })}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '0 8px', flexShrink: 0 }}>
          {activeTab?.exited && (
            <button style={btnStyle} onClick={() => restartTerminal(activeTab.key)} title={t('terminal.restart', 'Restart shell')}>
              {t('terminal.restart', 'Restart shell')}
            </button>
          )}
          <button
            style={btnStyle}
            onClick={() => openShellTerminal(defaultTitle())}
            title={t('terminal.new', 'New terminal') + ' (Ctrl+Shift+`)'}
          >+</button>
          <button
            style={{ ...btnStyle, background: '#0e639c', color: '#fff', border: '1px solid #0e639c' }}
            onClick={() => openClaudeTerminal(t as any)}
            title={t('terminal.claudeHint', 'Open a terminal running Claude Code in the project folder')}
          >
            {t('terminal.claude', 'Claude')}
          </button>
        </div>
      </div>
      <div ref={bodyRef} style={{ position: 'relative', flex: 1, minHeight: 0, padding: 0, overflow: 'hidden' }}>
        {!isTerminalAvailable() && (
          <div style={{ padding: 12, color: '#999', fontSize: 12 }}>{t('terminal.unavailable', 'The terminal is only available in the desktop app.')}</div>
        )}
        {isTerminalAvailable() && tabs.length === 0 && (
          <div style={{ padding: 12, color: '#999', fontSize: 12 }}>
            {t('terminal.empty', 'No open terminals.')}{' '}
            <a href="#" style={{ color: '#3794ff' }} onClick={(e) => { e.preventDefault(); openShellTerminal(defaultTitle()); }}>
              {t('terminal.new', 'New terminal')}
            </a>
          </div>
        )}
      </div>
      <style>{`
        .vpy-terminal-host .xterm { padding: 4px 0 0 8px; }
        .vpy-terminal-host .xterm-viewport { background-color: #1e1e1e !important; }
      `}</style>
    </div>
  );
};
