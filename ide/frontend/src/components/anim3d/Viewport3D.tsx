/**
 * The 3D Animation editor's view: a posed skeleton with its meshes, its bones (joint to
 * joint) and its sockets, over a floor grid. Orthographic, with the shared view math
 * (utils/view3d.ts) as an orbit, with front, side and top presets. Clicking near a joint picks
 * its bone; dragging orbits, Shift or middle drag pans, the wheel zooms.
 */
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { orbitRotation, projectView, viewForward, type Rotation3D, type ViewMode } from '../../utils/view3d';
import * as A from './animModel';
import type { MeshStrokes } from './meshStrokes';

export interface ViewOptions { meshes: boolean; bones: boolean; sockets: boolean; soft: boolean }

interface Props {
  resolved: A.Resolved | null;
  posed: A.Posed | null;
  /** A second pose drawn faintly behind (the previous key, for comparison). */
  ghost?: A.Posed | null;
  meshes: Record<string, MeshStrokes | undefined>;
  options: ViewOptions;
  selBone: number | null;
  onPickBone?: (i: number) => void;
  overlay?: React.ReactNode;
  status?: React.ReactNode;
  /** Translated names of the view buttons (3D, Front, Side, Top). */
  viewLabels?: Record<string, string>;
}

type V3 = A.Vec3;
/** Views of a character facing +z: all orbits (the shared orthographic views put y sideways). */
const VIEWS: [string, Rotation3D][] = [['3D', { pitch: -15, yaw: 200 }], ['Front', { pitch: 0, yaw: 180 }], ['Side', { pitch: 0, yaw: 90 }], ['Top', { pitch: -89, yaw: 180 }]];
const view: ViewMode = '3d';

export const Viewport3D: React.FC<Props> = ({ resolved, posed, ghost, meshes, options, selBone, onPickBone, overlay, status, viewLabels }) => {
  const wrapRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [size, setSize] = useState({ w: 600, h: 400 });
  const [rot, setRot] = useState<Rotation3D>(VIEWS[0][1]);
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setSize({ w: Math.max(50, el.clientWidth), h: Math.max(50, el.clientHeight) }));
    ro.observe(el);
    setSize({ w: Math.max(50, el.clientWidth), h: Math.max(50, el.clientHeight) });
    return () => ro.disconnect();
  }, []);

  const look = useMemo(() => viewForward(view, rot) as A.Vec3, [view, rot]);
  // the character, in world coordinates: its strokes, its joints, its sockets
  const scene = useMemo(() => {
    const segs: { a: V3; b: V3; kind: 'mesh' | 'soft' | 'bone' | 'socket' | 'ghost'; bone: number }[] = [];
    const joints: { p: V3; bone: number }[] = [];
    if (!resolved || !posed) return { segs, joints };
    resolved.bones.forEach((b, i) => {
      const P = posed.bones[i];
      if (!P) return;
      joints.push({ p: P.pos, bone: i });
      if (options.bones && b.parent >= 0) segs.push({ a: posed.bones[b.parent].pos, b: P.pos, kind: 'bone', bone: i });
      if (options.meshes && b.mesh) {
        const m = meshes[b.mesh];
        // as the console draws a mesh: hard edges with a face towards the eye, and on smooth
        // surfaces only the outline (one face towards the eye, the other away)
        const R = P.rot;
        const facing = (n: A.Vec3 | null) => (n ? A.apply3(R, n).reduce((acc, c, k) => acc + c * look[k], 0) < 0 : true);
        if (m && 'segs' in m) for (const s of m.segs) {
          const f0 = facing(s.n0), f1 = s.n1 ? facing(s.n1) : f0;
          let kind: 'mesh' | 'soft' | null;
          if (s.hard) kind = f0 || f1 ? 'mesh' : (options.soft ? 'soft' : null);
          else kind = f0 !== f1 ? 'mesh' : (options.soft ? 'soft' : null);
          if (kind) segs.push({ a: A.boneToWorld(posed, i, s.a), b: A.boneToWorld(posed, i, s.b), kind, bone: i });
        }
      }
    });
    if (options.sockets) {
      const index = new Map(resolved.bones.map((b, i) => [b.name, i]));
      for (const s of resolved.sockets) {
        const i = index.get(s.bone);
        if (i === undefined) continue;
        segs.push({ a: A.boneToWorld(posed, i, s.from), b: A.boneToWorld(posed, i, s.to), kind: 'socket', bone: i });
      }
    }
    if (ghost) resolved.bones.forEach((b, i) => {
      if (b.parent >= 0 && ghost.bones[i]) segs.push({ a: ghost.bones[b.parent].pos, b: ghost.bones[i].pos, kind: 'ghost', bone: i });
    });
    return { segs, joints };
  }, [resolved, posed, ghost, meshes, options, look]);

  // framed on the skeleton at rest height: the floor at the bottom, the head near the top
  const frame = useMemo(() => {
    const ys = scene.joints.map((j) => j.p[1]);
    const top = ys.length ? Math.max(...ys, 400) : 2000;
    return { c: [0, top / 2, 0] as V3, r: Math.max(600, top * 0.75) };
  }, [scene.joints.length > 0 && resolved?.bones.length, resolved?.scale]);   // eslint-disable-line react-hooks/exhaustive-deps
  const scale = (Math.min(size.w, size.h) * 0.45 / frame.r) * zoom;
  const toScreen = useCallback((p: V3) => {
    const q = projectView(p[0] - frame.c[0], p[1] - frame.c[1], p[2] - frame.c[2], view, rot);
    return { x: size.w / 2 + q.x * scale + pan.x, y: size.h / 2 - q.y * scale + pan.y };
  }, [frame, view, rot, size, scale, pan]);

  useEffect(() => {
    const c = canvasRef.current;
    if (!c) return;
    const dpr = window.devicePixelRatio || 1;
    if (c.width !== Math.round(size.w * dpr) || c.height !== Math.round(size.h * dpr)) {
      c.width = Math.round(size.w * dpr);
      c.height = Math.round(size.h * dpr);
    }
    const ctx = c.getContext('2d');
    if (!ctx) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = '#0b0b12';
    ctx.fillRect(0, 0, size.w, size.h);
    const line = (a: V3, b: V3) => { const p = toScreen(a), q = toScreen(b); ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(q.x, q.y); ctx.stroke(); };
    // the floor (y = 0)
    const ext = frame.r * 1.4, step = frame.r / 3;
    ctx.strokeStyle = '#181c2a';
    ctx.lineWidth = 1;
    for (let g = -ext; g <= ext + 1e-6; g += step) { line([g, 0, -ext], [g, 0, ext]); line([-ext, 0, g], [ext, 0, g]); }
    ctx.strokeStyle = '#2a3550';
    line([0, 0, 0], [0, 0, ext * 0.6]);                                   // which way +z is: ahead
    const z = toScreen([0, 0, ext * 0.6]);
    ctx.fillStyle = '#4a5878'; ctx.font = '10px monospace'; ctx.fillText('+z', z.x + 4, z.y);
    const style = (k: string, on: boolean) => {
      switch (k) {
        case 'mesh': return { c: on ? '#ffbe50' : '#5fd35f', w: on ? 1.5 : 1.1, d: [] as number[] };
        case 'soft': return { c: on ? 'rgba(255,190,80,0.5)' : 'rgba(60,120,80,0.5)', w: 1, d: [3, 3] };
        case 'bone': return { c: on ? '#ffd27a' : '#6f8fd8', w: on ? 3 : 2, d: [] };
        case 'socket': return { c: '#ff6b6b', w: 2.2, d: [] };
        default: return { c: 'rgba(160,160,220,0.28)', w: 2, d: [4, 3] };
      }
    };
    const order = ['ghost', 'soft', 'mesh', 'bone', 'socket'];
    for (const k of order) for (const s of scene.segs) {
      if (s.kind !== k) continue;
      const st = style(k, s.bone === selBone);
      ctx.strokeStyle = st.c; ctx.lineWidth = st.w; ctx.setLineDash(st.d);
      line(s.a, s.b);
    }
    ctx.setLineDash([]);
    if (options.bones) for (const j of scene.joints) {
      const p = toScreen(j.p);
      ctx.fillStyle = j.bone === selBone ? '#ffd27a' : '#9fb4ef';
      ctx.beginPath(); ctx.arc(p.x, p.y, j.bone === selBone ? 4.5 : 3, 0, Math.PI * 2); ctx.fill();
    }
    // the axes gizmo
    const gx = 30, gy = size.h - 30;
    for (const [d, col, n] of [[[1, 0, 0], '#e66', 'X'], [[0, 1, 0], '#6d6', 'Y'], [[0, 0, 1], '#69f', 'Z']] as const) {
      const q = projectView(d[0], d[1], d[2], view, rot);
      if (Math.hypot(q.x, q.y) < 0.05) continue;
      ctx.strokeStyle = col; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(gx, gy); ctx.lineTo(gx + q.x * 20, gy - q.y * 20); ctx.stroke();
      ctx.fillStyle = col; ctx.fillText(n, gx + q.x * 26 - 3, gy - q.y * 26 + 3);
    }
  }, [size, scene, toScreen, selBone, options.bones, frame, view, rot]);

  // mouse: click a joint to pick its bone; drag orbits (3D) or pans; middle drag pans; wheel zooms
  const drag = useRef<{ kind: 'orbit' | 'pan'; x: number; y: number; moved: boolean } | null>(null);
  const onMouseDown = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const r = canvasRef.current!.getBoundingClientRect();
    const x = e.clientX - r.left, y = e.clientY - r.top;
    if (e.button === 0 && !e.altKey && onPickBone) {
      let best: number | null = null, bd = 9;
      for (const j of scene.joints) { const p = toScreen(j.p); const d = Math.hypot(p.x - x, p.y - y); if (d < bd) { bd = d; best = j.bone; } }
      if (best !== null) { onPickBone(best); return; }
    }
    drag.current = { kind: e.button === 1 || e.shiftKey ? 'pan' : 'orbit', x: e.clientX, y: e.clientY, moved: false };
    e.preventDefault();
  };
  useEffect(() => {
    const move = (e: MouseEvent) => {
      const d = drag.current;
      if (!d) return;
      const dx = e.clientX - d.x, dy = e.clientY - d.y;
      d.x = e.clientX; d.y = e.clientY; d.moved = true;
      if (d.kind === 'orbit') setRot((r) => orbitRotation(r, dx, dy));
      else setPan((p) => ({ x: p.x + dx, y: p.y + dy }));
    };
    const up = () => { drag.current = null; };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
    return () => { window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up); };
  }, []);
  const onWheel = (e: React.WheelEvent) => setZoom((z) => Math.max(0.2, Math.min(12, z * (e.deltaY < 0 ? 1.12 : 1 / 1.12))));

  return (
    <div ref={wrapRef} style={{ flex: 1, position: 'relative', minWidth: 0, minHeight: 0, overflow: 'hidden' }}>
      <canvas ref={canvasRef} style={{ width: size.w, height: size.h, display: 'block' }}
        onMouseDown={onMouseDown} onWheel={onWheel} onContextMenu={(e) => e.preventDefault()} />
      <div style={{ position: 'absolute', top: 6, right: 6, display: 'flex', gap: 3 }}>
        {VIEWS.map(([label, r]) => (
          <button key={label} onClick={() => setRot(r)} style={{ ...btn, ...(rot.pitch === r.pitch && rot.yaw === r.yaw ? btnOn : {}) }}>{viewLabels?.[label] ?? label}</button>
        ))}
        <button style={btn} onClick={() => { setZoom(1); setPan({ x: 0, y: 0 }); setRot(VIEWS[0][1]); }}>⟲</button>
      </div>
      {overlay && <div style={{ position: 'absolute', top: 40, left: 20, right: 20, color: '#e6c07a', textAlign: 'center' }}>{overlay}</div>}
      {status && <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, display: 'flex', gap: 14, padding: '2px 8px 2px 64px', background: 'rgba(16,16,26,0.85)', color: '#889', fontFamily: 'monospace', fontSize: 11, pointerEvents: 'none' }}>{status}</div>}
    </div>
  );
};

const btn: React.CSSProperties = { background: '#2c2c44', color: '#ccd', border: '1px solid #3d3d5c', borderRadius: 3, padding: '2px 7px', fontSize: 11, cursor: 'pointer' };
const btnOn: React.CSSProperties = { background: '#4a4a8e', color: '#fff', border: '1px solid #7a7abf' };
