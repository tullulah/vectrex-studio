/**
 * The 3D views' background grey (Mesh Editor, 3D Animation editor): a slider from black to
 * white, so a mesh in dark colours does not vanish into the canvas. One value for every
 * view, kept in localStorage, and every open view follows a change at once.
 */
import { useCallback, useEffect, useState } from 'react';

const KEY = 'vs.view3d.bgGrey';
const EVENT = 'vs-view3d-bg';
export const VIEW_BG_DEFAULT = 11;   // the views' original #0b0b12, near enough

function read(): number {
  try {
    const v = Number(localStorage.getItem(KEY));
    return localStorage.getItem(KEY) !== null && Number.isFinite(v) ? Math.max(0, Math.min(255, Math.round(v))) : VIEW_BG_DEFAULT;
  } catch {
    return VIEW_BG_DEFAULT;
  }
}

/** [grey 0..255, set]: shared by every 3D view and remembered between sessions. */
export function useViewBg(): [number, (g: number) => void] {
  const [grey, setGrey] = useState(read);
  useEffect(() => {
    const on = (e: Event) => setGrey((e as CustomEvent<number>).detail);
    window.addEventListener(EVENT, on);
    return () => window.removeEventListener(EVENT, on);
  }, []);
  const set = useCallback((g: number) => {
    const v = Math.max(0, Math.min(255, Math.round(g)));
    try { localStorage.setItem(KEY, String(v)); } catch { /* private mode: this session only */ }
    window.dispatchEvent(new CustomEvent(EVENT, { detail: v }));
  }, []);
  return [grey, set];
}

/** The CSS colour of a grey level. */
export const viewBgCss = (grey: number) => `rgb(${grey},${grey},${grey})`;
