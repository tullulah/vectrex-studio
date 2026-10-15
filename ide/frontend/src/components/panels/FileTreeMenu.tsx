import React, { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';

export type MenuItem =
  | { label: string; shortcut?: string; disabled?: boolean; danger?: boolean; onClick: () => void }
  | 'separator';

/**
 * A right-click menu at (x, y), rendered in document.body so a dock panel's transform
 * cannot shift it. Closes on a click outside, Escape, scroll, blur or a resize; kept inside
 * the window by flipping it left/up when it would overflow.
 */
export const FileTreeMenu: React.FC<{ x: number; y: number; items: MenuItem[]; onClose: () => void }> =
  ({ x, y, items, onClose }) => {
  const ref = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState({ left: x, top: y });

  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const { width, height } = el.getBoundingClientRect();
    const left = x + width > window.innerWidth - 4 ? Math.max(4, x - width) : x;
    const top = y + height > window.innerHeight - 4 ? Math.max(4, window.innerHeight - height - 4) : y;
    setPos({ left, top });
  }, [x, y]);

  useEffect(() => {
    const down = (e: MouseEvent) => { if (!ref.current?.contains(e.target as Node)) onClose(); };
    const key = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.preventDefault(); onClose(); } };
    window.addEventListener('mousedown', down, true);
    window.addEventListener('keydown', key, true);
    window.addEventListener('scroll', onClose, true);
    window.addEventListener('blur', onClose);
    window.addEventListener('resize', onClose);
    return () => {
      window.removeEventListener('mousedown', down, true);
      window.removeEventListener('keydown', key, true);
      window.removeEventListener('scroll', onClose, true);
      window.removeEventListener('blur', onClose);
      window.removeEventListener('resize', onClose);
    };
  }, [onClose]);

  return createPortal(
    <div
      ref={ref}
      role="menu"
      onContextMenu={(e) => e.preventDefault()}
      style={{
        position: 'fixed', left: pos.left, top: pos.top, zIndex: 10000,
        minWidth: 220, padding: '4px 0',
        background: '#252526', border: '1px solid #454545', borderRadius: 4,
        boxShadow: '0 4px 16px rgba(0,0,0,0.5)', fontSize: 13, color: '#cccccc',
        userSelect: 'none',
      }}
    >
      {items.map((it, i) => it === 'separator'
        ? <div key={i} style={{ height: 1, margin: '4px 0', background: '#454545' }} />
        : (
          <div
            key={i}
            role="menuitem"
            aria-disabled={it.disabled}
            onClick={() => { if (it.disabled) return; onClose(); it.onClick(); }}
            onMouseEnter={(e) => { if (!it.disabled) e.currentTarget.style.background = '#04395e'; }}
            onMouseLeave={(e) => { e.currentTarget.style.background = 'transparent'; }}
            style={{
              display: 'flex', alignItems: 'center', gap: 24, padding: '4px 16px',
              cursor: it.disabled ? 'default' : 'pointer',
              color: it.disabled ? '#6b6b6b' : it.danger ? '#f48771' : undefined,
            }}
          >
            <span style={{ flex: 1 }}>{it.label}</span>
            {it.shortcut && <span style={{ color: '#888', fontSize: 12 }}>{it.shortcut}</span>}
          </div>
        ))}
    </div>,
    document.body,
  );
};
