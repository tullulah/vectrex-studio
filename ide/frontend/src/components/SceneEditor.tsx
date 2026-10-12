/**
 * SceneEditor — editor for `.vscene`, a 3D set put together from `.vmesh`
 * pieces for the SDK's vpy3d C library (docs/ASSETS.md). The model
 * (validation, placement, edit operations) lives in ./scene/vsceneModel.ts;
 * the meshes are read with the Mesh Editor's model (./mesh/vmeshModel.ts) and
 * the view math is shared with it (utils/view3d.ts).
 *
 * - Left: the items in draw order (add, duplicate, delete, move up/down: near
 *   pieces first), the groups (add, rename, delete; the checkbox is the
 *   preview's groups mask) and the scene fog.
 * - Right: the selected item's fields, its errors, and the scene's checks.
 * - Preview: every copy placed with vpy3d_draw_scene's arithmetic for the
 *   preview `pos` (x/y/z fields and sliders; Play advances pos.z so a repeat
 *   can be watched scrolling). Views: the eye (perspective, looking along +z
 *   from an editable point), front, top, side and an orbiting 3D view.
 *   Faces' edges (smooth ones faint), scenery lines at their brightness and
 *   occluders as a faint hull. Clicking a piece selects its item. The fog
 *   preview dims by depth from the eye along z: an approximation of the game
 *   camera's depth.
 * - Validation mirrors the compiler (compile_vscene); undo/redo for every
 *   edit; saves the same JSON, keeping the fields the editor does not know.
 */

import React, { useCallback, useEffect, useMemo, useReducer, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import * as S3 from './scene/vsceneModel';
import * as M from './mesh/vmeshModel';
import { DEFAULT_ROTATION_3D, orbitRotation, projectView, type Rotation3D, type ViewMode } from '../utils/view3d';

interface SceneEditorProps {
  /** Parsed JSON of the document (undefined if it does not parse). */
  resource?: unknown;
  /** file:// URI of the document: its meshes are in ../meshes. */
  docUri?: string;
  onChange?: (raw: S3.VsceneRaw) => void;
}

type View = ViewMode | 'eye';
type Vec3 = [number, number, number];

/** One stroke of a mesh, in the mesh's own coordinates. */
interface Seg { a: Vec3; b: Vec3; kind: 'hard' | 'soft' | 'line'; br: number; fog: boolean }
type PreviewMesh = { segs: Seg[]; occluders: Vec3[][]; note?: string } | { error: string };

/** A projected stroke ready to draw (and to click). */
interface Stroke { x1: number; y1: number; x2: number; y2: number; item: number; colour: string; width: number; dash: boolean }

const HISTORY_MAX = 200;
const NEAR = 20;
const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

function uriToFsPath(uri: string): string {
  if (/^file:\/\/\/[A-Za-z]:\//.test(uri)) return uri.slice('file:///'.length);
  return uri.replace(/^file:\/\//, '');
}
function dirOf(p: string): string {
  const n = p.replace(/\\/g, '/');
  const i = n.lastIndexOf('/');
  return i >= 0 ? n.slice(0, i) : '';
}
function joinPath(dir: string, rel: string): string {
  const parts = `${dir}/${rel}`.replace(/\\/g, '/').split('/');
  const out: string[] = [];
  for (const p of parts) {
    if (p === '..' && out.length && out[out.length - 1] !== '..' && out[out.length - 1] !== '') out.pop();
    else if (p !== '.') out.push(p);
  }
  return out.join('/').replace(/\/+/g, '/');
}
/** A tidy step (1, 2, 5 x 10^n) at least `min`. */
function niceStep(min: number): number {
  const p = Math.pow(10, Math.floor(Math.log10(Math.max(min, 1e-6))));
  for (const m of [1, 2, 5, 10]) if (m * p >= min) return m * p;
  return 10 * p;
}
function distToSeg(px: number, py: number, s: Stroke): number {
  const dx = s.x2 - s.x1, dy = s.y2 - s.y1;
  const l2 = dx * dx + dy * dy;
  const t = l2 ? Math.max(0, Math.min(1, ((px - s.x1) * dx + (py - s.y1) * dy) / l2)) : 0;
  return Math.hypot(px - (s.x1 + t * dx), py - (s.y1 + t * dy));
}
/** Convex hull of screen points (Andrew's monotone chain). */
function hull2d(pts: { x: number; y: number }[]): { x: number; y: number }[] {
  const p = [...pts].sort((a, b) => a.x - b.x || a.y - b.y);
  if (p.length < 3) return p;
  const cross = (o: { x: number; y: number }, a: { x: number; y: number }, b: { x: number; y: number }) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  const lower: { x: number; y: number }[] = [];
  for (const q of p) { while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], q) <= 0) lower.pop(); lower.push(q); }
  const upper: { x: number; y: number }[] = [];
  for (let i = p.length - 1; i >= 0; i--) { const q = p[i]; while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], q) <= 0) upper.pop(); upper.push(q); }
  return lower.slice(0, -1).concat(upper.slice(0, -1));
}

/** The strokes and occluders of a `.vmesh` (Mesh Editor model). */
function buildPreview(json: unknown): PreviewMesh {
  if (!isObj(json)) return { error: 'not a JSON object' };
  const raw = json as M.VmeshRaw;
  let mesh = M.meshFromRaw(raw);
  let note: string | undefined;
  if (M.isLofted(raw)) {
    const l = M.loftRaw(raw);
    if (l.mesh && !l.pending) mesh = l.mesh;
    else note = 'lofted from .vec sections: its faces are not previewed here (open it in the Mesh Editor)';
  }
  const v = mesh.vertices;
  const geo = M.meshGeometry(mesh, M.hardCosQ14(raw));
  const segs: Seg[] = [];
  for (const e of geo.edges) {
    const a = v[e.a], b = v[e.b];
    if (!a || !b) continue;
    segs.push({ a: [a.x, a.y, a.z], b: [b.x, b.y, b.z], kind: e.hard ? 'hard' : 'soft', br: 100, fog: false });
  }
  const sc = M.sceneryFromRaw(raw);
  for (const l of sc.lines) {
    const pts = l.points;
    const n = M.lineClosed(l) && pts.length > 2 ? pts.length : pts.length - 1;
    for (let k = 0; k < n; k++) {
      const a = pts[k], b = pts[(k + 1) % pts.length];
      segs.push({ a: [a.x, a.y, a.z], b: [b.x, b.y, b.z], kind: 'line', br: M.lineBr(l), fog: M.lineFog(l) });
    }
  }
  const occluders = sc.occluders.map((o) => o.points.map((p) => [p.x, p.y, p.z] as Vec3));
  return { segs, occluders, note };
}

// ── component ──────────────────────────────────────────────────────────────

type DirEntry = { name: string; path?: string; isDir: boolean; children?: DirEntry[] };

/** Every .vmesh under the listing, by name → its path relative to the listed folder. */
function collectMeshes(entries: DirEntry[], prefix = '', out: Record<string, string> = {}): Record<string, string> {
  for (const f of entries) {
    const rel = prefix ? `${prefix}/${f.name}` : f.name;
    if (f.isDir) collectMeshes(f.children ?? [], rel, out);
    else if (/\.vmesh$/i.test(f.name)) {
      const n = f.name.replace(/\.vmesh$/i, '');
      if (!(n in out)) out[n] = rel;
    }
  }
  return out;
}

export const SceneEditor: React.FC<SceneEditorProps> = ({ resource, docUri, onChange }) => {
  const { t } = useTranslation(['editor']);
  const tr = (k: string, d: string, o?: Record<string, unknown>) => t(`scene.${k}`, { defaultValue: d, ...(o || {}) }) as string;

  // ── document + history ──
  const [raw, setRaw] = useState<S3.VsceneRaw | null>(() => (isObj(resource) ? resource : null));
  const lastJsonRef = useRef<string>(JSON.stringify(resource ?? null));
  const histRef = useRef<{ stack: S3.VsceneRaw[]; index: number }>({ stack: raw ? [raw] : [], index: raw ? 0 : -1 });
  const [, rerender] = useReducer((x: number) => x + 1, 0);
  const [selItem, setSelItem] = useState<number | null>(() => (isObj(resource) && S3.items(resource).length ? 0 : null));
  const [message, setMessage] = useState<{ text: string; error: boolean } | null>(null);

  const emit = useCallback((next: S3.VsceneRaw) => {
    lastJsonRef.current = JSON.stringify(next);
    onChange?.(next);
  }, [onChange]);

  const commit = useCallback((next: S3.VsceneRaw) => {
    const h = histRef.current;
    h.stack = h.stack.slice(0, h.index + 1);
    h.stack.push(next);
    if (h.stack.length > HISTORY_MAX) h.stack.shift();
    h.index = h.stack.length - 1;
    setRaw(next);
    emit(next);
    rerender();
  }, [emit]);

  // A new document from outside (opened, reverted, edited as text elsewhere).
  useEffect(() => {
    const j = JSON.stringify(resource ?? null);
    if (j === lastJsonRef.current) return;
    lastJsonRef.current = j;
    const r = isObj(resource) ? resource : null;
    setRaw(r);
    histRef.current = { stack: r ? [r] : [], index: r ? 0 : -1 };
    rerender();
  }, [resource]);

  const undo = useCallback(() => {
    const h = histRef.current;
    if (h.index <= 0) return;
    h.index--;
    const r = h.stack[h.index];
    setRaw(r); emit(r); rerender();
  }, [emit]);
  const redo = useCallback(() => {
    const h = histRef.current;
    if (h.index >= h.stack.length - 1) return;
    h.index++;
    const r = h.stack[h.index];
    setRaw(r); emit(r); rerender();
  }, [emit]);

  const flash = useCallback((text: string, error = false) => setMessage({ text, error }), []);
  useEffect(() => {
    if (!message) return;
    const id = window.setTimeout(() => setMessage(null), 4000);
    return () => window.clearTimeout(id);
  }, [message]);

  const itemList = useMemo(() => S3.items(raw), [raw]);
  const groupList = useMemo(() => S3.groups(raw), [raw]);
  useEffect(() => {
    setSelItem((s) => (s === null ? (itemList.length ? 0 : null) : s >= itemList.length ? (itemList.length ? itemList.length - 1 : null) : s));
  }, [itemList.length]);

  // ── the project's meshes: <scene dir>/../meshes/**/*.vmesh, by name, as the compiler looks ──
  const meshesDir = useMemo(() => (docUri && docUri.startsWith('file://') ? joinPath(dirOf(uriToFsPath(docUri)), '../meshes') : ''), [docUri]);
  const filesApi = (window as unknown as {
    files?: {
      readFile?: (p: string) => Promise<{ content: string } | { error: string }>;
      readDirectory?: (p: string) => Promise<{ files: DirEntry[] } | { error: string }>;
    };
  }).files;
  const [meshNames, setMeshNames] = useState<string[] | null>(null);
  /** name → path inside assets/meshes (meshes may sit in folders; a scene names them only). */
  const meshPaths = useRef<Record<string, string>>({});
  const [meshData, setMeshData] = useState<Record<string, PreviewMesh>>({});
  const inFlight = useRef(new Set<string>());
  const [reloadTick, setReloadTick] = useState(0);
  useEffect(() => {
    if (!meshesDir || !filesApi?.readDirectory) { setMeshNames(null); return; }
    let live = true;
    filesApi.readDirectory(meshesDir).then((r) => {
      if (!live) return;
      if ('error' in r) { meshPaths.current = {}; setMeshNames([]); return; }
      const found = collectMeshes(r.files);
      meshPaths.current = found;
      setMeshNames(Object.keys(found).sort());
    }).catch(() => { if (live) setMeshNames(null); });
    return () => { live = false; };
  }, [meshesDir, reloadTick]);
  const table = useMemo(() => S3.meshTable(raw), [raw]);
  useEffect(() => {
    if (!meshesDir || !filesApi?.readFile) return;
    for (const name of table) {
      if (!name || /[/\\]/.test(name) || name in meshData || inFlight.current.has(name)) continue;
      if (meshNames && !meshNames.includes(name)) continue;
      inFlight.current.add(name);
      filesApi.readFile(joinPath(meshesDir, meshPaths.current[name] ?? `${name}.vmesh`)).then((res) => {
        inFlight.current.delete(name);
        let entry: PreviewMesh;
        if ('error' in res) entry = { error: res.error };
        else {
          try { entry = buildPreview(JSON.parse(res.content)); } catch { entry = { error: 'not valid JSON' }; }
        }
        setMeshData((m) => ({ ...m, [name]: entry }));
      }).catch(() => inFlight.current.delete(name));
    }
  }, [meshesDir, table, meshData, meshNames]);
  const reloadMeshes = () => { setMeshData({}); setReloadTick((n) => n + 1); };
  const meshExists = useCallback((n: string) => (meshNames ? meshNames.includes(n) : undefined), [meshNames]);

  // ── validation ──
  const issues = useMemo(() => (raw ? S3.validateVscene(raw, meshExists) : []), [raw, meshExists]);
  const meshWarnings = useMemo(() => {
    const out: string[] = [];
    for (const n of table) {
      const d = meshData[n];
      if (!d) continue;
      if ('error' in d) out.push(`${n}.vmesh: ${d.error}`);
      else if (d.note) out.push(`${n}.vmesh: ${d.note}`);
    }
    return out;
  }, [table, meshData]);
  const errorCount = issues.length;
  const badItems = useMemo(() => new Set(issues.filter((i) => i.item !== undefined).map((i) => i.item!)), [issues]);
  const badGroups = useMemo(() => new Set(issues.filter((i) => i.group !== undefined).map((i) => i.group!)), [issues]);

  // ── preview state (not part of the document) ──
  const [pos, setPos] = useState<Vec3>([0, 0, 0]);
  const [mask, setMask] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(2000);
  const [eye, setEye] = useState<Vec3>([0, 0, 0]);
  const [view, setView] = useState<View>('eye');
  const [rot, setRot] = useState<Rotation3D>(DEFAULT_ROTATION_3D);
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [frameC, setFrameC] = useState<Vec3>([0, 0, 5000]);
  const [frameR, setFrameR] = useState(6000);
  const [showSoft, setShowSoft] = useState(true);
  const [showOccluders, setShowOccluders] = useState(true);
  const [fogPreview, setFogPreview] = useState(true);

  // Play: pos.z advances at `speed` units per second.
  useEffect(() => {
    if (!playing) return;
    let last = performance.now();
    let id = 0;
    const tick = (now: number) => {
      const dt = Math.min(0.1, (now - last) / 1000);
      last = now;
      setPos((p) => [p[0], p[1], Math.round(p[2] + speed * dt)]);
      id = requestAnimationFrame(tick);
    };
    id = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(id);
  }, [playing, speed]);

  const placement = useMemo(() => S3.placeScene(raw, pos, mask), [raw, pos, mask]);
  const fog = useMemo(() => S3.sceneFog(raw), [raw]);

  /** The world strokes of every copy (mesh-local + the copy's position). */
  const world = useMemo(() => {
    const strokes: { a: Vec3; b: Vec3; item: number; kind: Seg['kind']; bright: number }[] = [];
    const occ: { pts: Vec3[]; item: number }[] = [];
    for (const c of placement.copies) {
      const d = meshData[c.mesh];
      if (!d || 'error' in d) continue;
      const it = itemList[c.item];
      if (!it) continue;
      // brightness out of 127, as the game draws it at br 127
      const base = (127 * c.br) / 100;
      let whole = base;
      if (fog && fogPreview && c.fog === 'whole') {
        whole = S3.fogBrightness(base, c.at[2] - eye[2], fog.full, fog.gone);
        if (whole < 4) continue;
      }
      for (const s of d.segs) {
        const a: Vec3 = [s.a[0] + c.at[0], s.a[1] + c.at[1], s.a[2] + c.at[2]];
        const b: Vec3 = [s.b[0] + c.at[0], s.b[1] + c.at[1], s.b[2] + c.at[2]];
        let bright = c.fog === 'whole' ? whole : base;
        if (s.kind === 'line') {
          bright = Math.trunc((bright * s.br) / 100);
          if (fog && fogPreview && c.fog === 'segment' && s.fog) {
            bright = S3.fogBrightness(bright, (a[2] + b[2]) / 2 - eye[2], fog.full, fog.gone);
            if (bright < 4) continue;
          }
        }
        strokes.push({ a, b, item: c.item, kind: s.kind, bright });
      }
      for (const o of d.occluders) occ.push({ pts: o.map((p) => [p[0] + c.at[0], p[1] + c.at[1], p[2] + c.at[2]] as Vec3), item: c.item });
    }
    return { strokes, occ };
  }, [placement, meshData, itemList, fog, fogPreview, eye]);

  // ── view ──
  const containerRef = useRef<HTMLDivElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [size, setSize] = useState({ w: 600, h: 400 });
  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setSize({ w: Math.max(50, el.clientWidth), h: Math.max(50, el.clientHeight) }));
    ro.observe(el);
    setSize({ w: Math.max(50, el.clientWidth), h: Math.max(50, el.clientHeight) });
    return () => ro.disconnect();
  }, []);

  const frameAll = useCallback(() => {
    const pts = world.strokes.flatMap((s) => [s.a, s.b]);
    if (!pts.length) { setFrameC([0, 0, 5000]); setFrameR(6000); }
    else {
      const lo = [0, 1, 2].map((k) => Math.min(...pts.map((p) => p[k])));
      const hi = [0, 1, 2].map((k) => Math.max(...pts.map((p) => p[k])));
      setFrameC([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2]);
      setFrameR(Math.max(200, Math.hypot(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]) / 2));
    }
    setZoom(1);
    setPan({ x: 0, y: 0 });
  }, [world]);
  // Frame the set once its meshes are in.
  const framed = useRef(false);
  useEffect(() => {
    if (framed.current || !world.strokes.length) return;
    framed.current = true;
    frameAll();
  }, [world, frameAll]);

  const scale = (Math.min(size.w, size.h) * 0.42 / frameR) * zoom;
  const focal = Math.min(size.w, size.h) * 0.9 * zoom;
  /** World point → screen; null behind the eye. */
  const toScreen = useCallback((p: Vec3): { x: number; y: number; depth: number } | null => {
    if (view === 'eye') {
      const d = p[2] - eye[2];
      if (d < NEAR) return null;
      return { x: size.w / 2 + ((p[0] - eye[0]) / d) * focal + pan.x, y: size.h / 2 - ((p[1] - eye[1]) / d) * focal + pan.y, depth: d };
    }
    const q = projectView(p[0] - frameC[0], p[1] - frameC[1], p[2] - frameC[2], view, rot);
    return { x: size.w / 2 + q.x * scale + pan.x, y: size.h / 2 - q.y * scale + pan.y, depth: q.depth };
  }, [view, eye, size, focal, pan, frameC, rot, scale]);
  /** A world segment on screen, cut at the eye's near plane. */
  const segToScreen = useCallback((a: Vec3, b: Vec3): [number, number, number, number] | null => {
    if (view === 'eye') {
      const da = a[2] - eye[2], db = b[2] - eye[2];
      if (da < NEAR && db < NEAR) return null;
      if (da < NEAR || db < NEAR) {
        const t = (NEAR - da) / (db - da);
        const m: Vec3 = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, eye[2] + NEAR];
        if (da < NEAR) a = m; else b = m;
      }
    }
    const p = toScreen(a), q = toScreen(b);
    return p && q ? [p.x, p.y, q.x, q.y] : null;
  }, [view, eye, toScreen]);

  const strokes = useMemo<Stroke[]>(() => {
    const out: Stroke[] = [];
    for (const s of world.strokes) {
      if (s.kind === 'soft' && !showSoft) continue;
      const r = segToScreen(s.a, s.b);
      if (!r) continue;
      const on = s.item === selItem;
      const k = 0.2 + 0.8 * Math.max(0, Math.min(127, s.bright)) / 127;
      const colour = on ? (s.kind === 'soft' ? 'rgba(255,170,40,0.45)' : '#ffaa28')
        : s.kind === 'line' ? `rgb(${Math.round(150 * k)},${Math.round(225 * k)},${Math.round(255 * k)})`
          : s.kind === 'hard' ? `rgb(${Math.round(95 * k)},${Math.round(211 * k)},${Math.round(95 * k)})`
            : 'rgba(60,120,80,0.55)';
      out.push({ x1: r[0], y1: r[1], x2: r[2], y2: r[3], item: s.item, colour, width: on ? 1.8 : s.kind === 'soft' ? 1 : 1.3, dash: s.kind === 'soft' });
    }
    return out;
  }, [world, segToScreen, showSoft, selItem]);

  // ── drawing ──
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

    // outside the eye view: a floor grid (y = 0) and the eye's line of sight, for orientation
    const ext = niceStep(frameR * 1.5), step = niceStep(ext / 6);
    ctx.strokeStyle = '#161a26';
    ctx.lineWidth = 1;
    const cz = frameC[2], cx = frameC[0];
    const line = (a: Vec3, b: Vec3) => { const r = segToScreen(a, b); if (r) { ctx.beginPath(); ctx.moveTo(r[0], r[1]); ctx.lineTo(r[2], r[3]); ctx.stroke(); } };
    if (view !== 'eye') {
      for (let g = -ext; g <= ext + 1e-9; g += step) {
        line([cx + g, 0, cz - ext], [cx + g, 0, cz + ext]);
        line([cx - ext, 0, cz + g], [cx + ext, 0, cz + g]);
      }
      ctx.strokeStyle = '#46c';
      line(eye, [eye[0], eye[1], eye[2] + ext * 1.5]);
      const e = toScreen(eye);
      if (e) {
        ctx.strokeStyle = '#9ab';
        ctx.beginPath(); ctx.arc(e.x, e.y, 5, 0, Math.PI * 2); ctx.stroke();
        ctx.fillStyle = '#9ab'; ctx.font = '10px monospace'; ctx.fillText(tr('eyeMark', 'eye'), e.x + 8, e.y - 6);
      }
    }

    if (showOccluders) {
      for (const o of world.occ) {
        const pts = o.pts.map(toScreen).filter((p): p is { x: number; y: number; depth: number } => !!p);
        if (pts.length < 3) continue;
        const h = hull2d(pts);
        const on = o.item === selItem;
        ctx.beginPath();
        h.forEach((q, i) => (i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y)));
        ctx.closePath();
        ctx.fillStyle = on ? 'rgba(255,150,50,0.12)' : 'rgba(230,130,40,0.05)';
        ctx.fill();
        ctx.strokeStyle = on ? 'rgba(255,170,40,0.8)' : 'rgba(220,130,50,0.35)';
        ctx.setLineDash([5, 3]);
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }

    // the selected item last, on top
    const draw = (sel: boolean) => {
      for (const s of strokes) {
        if ((s.item === selItem) !== sel) continue;
        ctx.strokeStyle = s.colour; ctx.lineWidth = s.width;
        ctx.setLineDash(s.dash ? [4, 3] : []);
        ctx.beginPath(); ctx.moveTo(s.x1, s.y1); ctx.lineTo(s.x2, s.y2); ctx.stroke();
      }
      ctx.setLineDash([]);
    };
    draw(false);
    draw(true);

    if (view !== 'eye') {
      const gx = 34, gy = size.h - 34;
      ctx.font = '10px monospace';
      for (const [d, col, name] of [[[1, 0, 0], '#e66', 'X'], [[0, 1, 0], '#6d6', 'Y'], [[0, 0, 1], '#69f', 'Z']] as const) {
        const q = projectView(d[0], d[1], d[2], view, rot);
        if (Math.hypot(q.x, q.y) < 0.05) continue;
        ctx.strokeStyle = col; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(gx, gy); ctx.lineTo(gx + q.x * 22, gy - q.y * 22); ctx.stroke();
        ctx.fillStyle = col; ctx.fillText(name, gx + q.x * 28 - 3, gy - q.y * 28 + 3);
      }
    }
  }, [size, strokes, world, view, eye, frameC, frameR, rot, toScreen, segToScreen, showOccluders, selItem]);

  // ── mouse: click selects the piece under it; middle pans; Shift+middle / Alt / left drag in 3D orbits ──
  const dragRef = useRef<{ kind: 'pan' | 'orbit'; x: number; y: number; panX: number; panY: number; moved: boolean } | null>(null);
  const pointer = (e: { clientX: number; clientY: number }) => {
    const r = canvasRef.current!.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };
  const hitItem = (x: number, y: number): number | null => {
    let best: number | null = null, bestD = 6;
    for (const s of strokes) {
      const d = distToSeg(x, y, s);
      if (d < bestD) { best = s.item; bestD = d; }
    }
    return best;
  };
  const onMouseDown = (e: React.MouseEvent<HTMLCanvasElement>) => {
    containerRef.current?.focus();
    const p = pointer(e);
    if (e.button === 1 || (e.button === 0 && e.altKey)) {
      e.preventDefault();
      const orbit = e.shiftKey || e.altKey;
      if (orbit && view !== '3d') setView('3d');
      dragRef.current = { kind: orbit ? 'orbit' : 'pan', x: p.x, y: p.y, panX: pan.x, panY: pan.y, moved: false };
      return;
    }
    if (e.button !== 0) return;
    const hit = hitItem(p.x, p.y);
    if (hit !== null) { setSelItem(hit); return; }
    dragRef.current = { kind: view === '3d' ? 'orbit' : 'pan', x: p.x, y: p.y, panX: pan.x, panY: pan.y, moved: false };
  };
  useEffect(() => {
    const move = (e: MouseEvent) => {
      const d = dragRef.current;
      if (!d || !canvasRef.current) return;
      const p = pointer(e);
      d.moved = true;
      if (d.kind === 'pan') setPan({ x: d.panX + p.x - d.x, y: d.panY + p.y - d.y });
      else { setRot((r) => orbitRotation(r, p.x - d.x, p.y - d.y)); d.x = p.x; d.y = p.y; }
    };
    const up = () => { dragRef.current = null; };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
    return () => { window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up); };
  }, []);
  // Wheel: zoom to the cursor (native listener, so preventDefault works).
  const wheelLive = useRef({ zoom, pan, size });
  wheelLive.current = { zoom, pan, size };
  useEffect(() => {
    const c = canvasRef.current;
    if (!c) return;
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      const { zoom: z, pan: pn, size: s } = wheelLive.current;
      const r = c.getBoundingClientRect();
      const mx = e.clientX - r.left - s.w / 2, my = e.clientY - r.top - s.h / 2;
      const nz = Math.max(0.05, Math.min(200, z * (e.deltaY < 0 ? 1.1 : 1 / 1.1)));
      const k = nz / z;
      setZoom(nz);
      setPan({ x: mx - (mx - pn.x) * k, y: my - (my - pn.y) * k });
    };
    c.addEventListener('wheel', onWheel, { passive: false });
    return () => c.removeEventListener('wheel', onWheel);
  }, []);

  // ── edits ──
  const apply = (f: (r: S3.VsceneRaw) => S3.VsceneRaw) => { if (raw) commit(f(raw)); };
  const sel = selItem !== null ? itemList[selItem] : undefined;
  const setField = (key: string, value: unknown) => { if (selItem !== null) apply((r) => S3.setItemField(r, selItem, key, value)); };
  const defaultMesh = () => meshNames?.[0] ?? '';
  const doAddItem = () => {
    if (!raw) return;
    const r = S3.addItem(raw, { name: `piece${itemList.length}`, mesh: (sel && S3.itemMeshes(sel)[0]) || defaultMesh(), at: { z: 2000 } }, selItem === null ? undefined : selItem + 1);
    commit(r.raw);
    setSelItem(r.index);
  };
  const doDuplicate = () => {
    if (!raw || selItem === null) return;
    const r = S3.duplicateItem(raw, selItem);
    commit(r.raw);
    setSelItem(r.index);
  };
  const doDelete = () => {
    if (!raw || selItem === null) return;
    commit(S3.deleteItem(raw, selItem));
  };
  const doMove = (delta: number) => {
    if (!raw || selItem === null) return;
    const r = S3.moveItem(raw, selItem, delta);
    if (r.raw === raw) return;
    commit(r.raw);
    setSelItem(r.index);
  };
  const [newGroup, setNewGroup] = useState('');
  const doAddGroup = () => {
    const n = newGroup.trim();
    if (!raw || !n) return;
    if (n.startsWith('!') || groupList.includes(n)) { flash(tr('badGroupName', 'A group name must be new and not start with "!"'), true); return; }
    commit(S3.addGroup(raw, n));
    setNewGroup('');
  };
  const doRenameGroup = (gi: number, name: string) => {
    const n = name.trim();
    if (!raw || !n || n === groupList[gi]) return;
    if (n.startsWith('!') || groupList.includes(n)) { flash(tr('badGroupName', 'A group name must be new and not start with "!"'), true); return; }
    commit(S3.renameGroup(raw, gi, n));
  };
  const doDeleteGroup = (gi: number) => {
    if (!raw) return;
    commit(S3.deleteGroup(raw, gi));
    // the bits above it move down by one
    setMask((m) => (m & ((1 << gi) - 1)) | ((m >>> (gi + 1)) << gi));
  };
  const startNew = () => {
    commit(S3.newScene(docUri ? (uriToFsPath(docUri).split('/').pop() || 'scene').replace(/\.vscene$/i, '') : 'scene', defaultMesh()));
    setSelItem(0);
  };

  // ── keyboard ──
  const onKeyDown = (e: React.KeyboardEvent) => {
    const tag = (e.target as HTMLElement).tagName;
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
    const mod = e.ctrlKey || e.metaKey;
    const k = e.key;
    const done = () => { e.preventDefault(); e.stopPropagation(); };
    if (mod && (k === 'z' || k === 'Z')) { done(); if (e.shiftKey) redo(); else undo(); return; }
    if (mod && (k === 'y' || k === 'Y')) { done(); redo(); return; }
    if (mod && (k === 'd' || k === 'D')) { done(); doDuplicate(); return; }
    if (mod) return;
    if (e.altKey && k === 'ArrowUp') { done(); doMove(-1); return; }
    if (e.altKey && k === 'ArrowDown') { done(); doMove(1); return; }
    switch (k) {
      case ' ': done(); setPlaying((p) => !p); return;
      case '0': done(); setView('eye'); return;
      case '1': done(); setView('xy'); return;
      case '2': done(); setView('xz'); return;
      case '3': done(); setView('yz'); return;
      case '4': done(); setView('3d'); return;
      case 'Delete': case 'Backspace': done(); doDelete(); return;
      case 'Home': case 'h': case 'H': done(); frameAll(); return;
      case 'ArrowUp': done(); setSelItem((s) => (s === null ? 0 : Math.max(0, s - 1))); return;
      case 'ArrowDown': done(); setSelItem((s) => (s === null ? 0 : Math.min(itemList.length - 1, s + 1))); return;
    }
  };

  // ── inputs ──
  const numInput = (value: number, onCommit: (n: number) => void, opts: { disabled?: boolean; width?: number; step?: number; min?: number; max?: number } = {}) => (
    <input
      type="number"
      key={`${value}`}
      defaultValue={Number.isFinite(value) ? value : 0}
      disabled={opts.disabled}
      step={opts.step ?? 1}
      min={opts.min}
      max={opts.max}
      style={{ ...ST.input, width: opts.width ?? 64 }}
      onWheel={(e) => e.currentTarget.blur()}
      onBlur={(e) => {
        const n = Number(e.currentTarget.value);
        if (e.currentTarget.value.trim() === '' || !Number.isFinite(n)) { e.currentTarget.value = String(value); return; }
        if (n !== value) onCommit(n);
      }}
      onKeyDown={(e) => {
        if (e.key === 'Enter') e.currentTarget.blur();
        if (e.key === 'Escape') { e.currentTarget.value = String(value); e.currentTarget.blur(); }
      }}
    />
  );
  /** A number that may be absent: blank = absent. */
  const optInput = (value: number | null, onCommit: (n: number | undefined) => void, opts: { width?: number; placeholder?: string } = {}) => (
    <input
      type="number"
      key={`${value}`}
      defaultValue={value ?? ''}
      placeholder={opts.placeholder}
      style={{ ...ST.input, width: opts.width ?? 72 }}
      onWheel={(e) => e.currentTarget.blur()}
      onBlur={(e) => {
        const s = e.currentTarget.value.trim();
        if (s === '') { if (value !== null) onCommit(undefined); return; }
        const n = Number(s);
        if (!Number.isFinite(n)) { e.currentTarget.value = value === null ? '' : String(value); return; }
        if (n !== value) onCommit(n);
      }}
      onKeyDown={(e) => {
        if (e.key === 'Enter') e.currentTarget.blur();
        if (e.key === 'Escape') { e.currentTarget.value = value === null ? '' : String(value); e.currentTarget.blur(); }
      }}
    />
  );
  const textInput = (value: string, onCommit: (s: string) => void, opts: { width?: number; placeholder?: string } = {}) => (
    <input
      key={value}
      defaultValue={value}
      placeholder={opts.placeholder}
      style={{ ...ST.input, width: opts.width ?? 150 }}
      onBlur={(e) => { if (e.currentTarget.value !== value) onCommit(e.currentTarget.value); }}
      onKeyDown={(e) => {
        if (e.key === 'Enter') e.currentTarget.blur();
        if (e.key === 'Escape') { e.currentTarget.value = value; e.currentTarget.blur(); }
      }}
    />
  );
  const meshSelect = (value: string, onPick: (n: string) => void) => {
    const names = meshNames ?? [];
    return (
      <select value={value} onChange={(e) => onPick(e.target.value)} style={{ ...ST.input, maxWidth: 150 }}>
        {!names.includes(value) && <option value={value}>{value ? `${value} (${tr('missing', 'missing')})` : tr('pickMesh', '(pick a mesh)')}</option>}
        {names.map((n) => <option key={n} value={n}>{n}</option>)}
      </select>
    );
  };

  // ── panels ──
  const h = histRef.current;
  const canUndo = h.index > 0, canRedo = h.index < h.stack.length - 1;
  const selIssues = selItem !== null ? issues.filter((i) => i.item === selItem) : [];
  const sceneIssues = issues.filter((i) => i.item === undefined);
  const itemSummary = (it: S3.ItemRaw): string => {
    const ms = S3.itemMeshes(it);
    const rep = S3.repeatOf(it);
    const g = S3.groupOf(it);
    return [ms.join('/') || '?', rep ? `×${rep.count}/${rep.axis}` : '', g ? `[${g.negated ? '!' : ''}${g.name}]` : ''].filter(Boolean).join(' ');
  };

  const sceneFogRaw = isObj(raw?.fog) ? raw!.fog as Record<string, unknown> : null;
  const setSceneFog = (key: 'full' | 'gone', n: number) => apply((r) => ({ ...r, fog: { ...(isObj(r.fog) ? r.fog : { full: 3000, gone: 17500 }), [key]: Math.round(n) } }));

  const viewButtons: [View, string, string][] = [
    ['eye', tr('viewEye', 'Eye'), tr('viewEyeTip', 'Perspective from the eye point, looking along +z: roughly what a game with the camera there sees (key 0)')],
    ['xy', tr('viewFront', 'Front'), tr('viewFrontTip', 'Front view (X-Y), key 1')],
    ['xz', tr('viewTop', 'Top'), tr('viewTopTip', 'Top view (X-Z), key 2')],
    ['yz', tr('viewSide', 'Side'), tr('viewSideTip', 'Side view (Y-Z), key 3')],
    ['3d', '3D', tr('view3dTip', '3D view, key 4. Orbit: left drag, or middle button + Shift')],
  ];
  const posSpan = Math.max(20000, ...pos.map((v) => Math.abs(v)));
  const rep = sel ? S3.repeatOf(sel) : null;
  const win = sel ? S3.windowOf(sel) : null;
  const grp = sel ? S3.groupOf(sel) : null;
  const selMeshes = sel ? S3.itemMeshes(sel) : [];
  const drawnCopies = selItem !== null ? placement.copies.filter((c) => c.item === selItem).length : 0;

  return (
    <div ref={containerRef} tabIndex={0} onKeyDown={onKeyDown} style={ST.root}>
      {/* toolbar */}
      <div style={ST.toolbar}>
        {viewButtons.map(([m, label, tip]) => (
          <button key={m} title={tip} onClick={() => setView(m)} style={view === m ? ST.btnOn : ST.btn}>{label}</button>
        ))}
        <span style={ST.sep} />
        <label style={ST.check} title={tr('softTip', 'Show the smooth edges of faces (vpy3d draws them only on the silhouette)')}><input type="checkbox" checked={showSoft} onChange={(e) => setShowSoft(e.target.checked)} />{tr('soft', 'smooth edges')}</label>
        <label style={ST.check} title={tr('showOccTip', 'Show the occluders (never drawn by the game) as a faint orange hull')}><input type="checkbox" checked={showOccluders} onChange={(e) => setShowOccluders(e.target.checked)} />{tr('showOcc', 'occluders')}</label>
        <label style={ST.check} title={tr('fogPreviewTip', 'Dim by the scene fog, taking the depth as z minus the eye\'s z (the game uses its camera\'s depth)')}><input type="checkbox" checked={fogPreview} onChange={(e) => setFogPreview(e.target.checked)} disabled={!fog} />{tr('fogPreview', 'fog')}</label>
        <span style={ST.sep} />
        <span style={ST.dim} title={tr('eyeTip', 'Where the eye view looks from (along +z)')}>{tr('eye', 'Eye')}</span>
        {[0, 1, 2].map((a) => <React.Fragment key={a}>{numInput(eye[a], (n) => setEye((e) => { const c = [...e] as Vec3; c[a] = Math.round(n); return c; }), { width: 58 })}</React.Fragment>)}
        <span style={ST.sep} />
        <button title={tr('frameTip', 'Frame the whole set (Home / H)')} onClick={frameAll} style={ST.btn}>{tr('frame', 'Frame')}</button>
        <button title={tr('reloadTip', 'Read the meshes again from assets/meshes and its folders')} onClick={reloadMeshes} style={ST.btn}>{tr('reload', 'Reload meshes')}</button>
        <button title={tr('undoTip', 'Undo (Ctrl+Z)')} onClick={undo} disabled={!canUndo} style={ST.btn}>↶</button>
        <button title={tr('redoTip', 'Redo (Ctrl+Shift+Z / Ctrl+Y)')} onClick={redo} disabled={!canRedo} style={ST.btn}>↷</button>
      </div>

      <div style={ST.body}>
        {/* left: items, groups, fog */}
        <div style={{ ...ST.panel, borderLeft: 'none', borderRight: '1px solid #2a2a3e' }}>
          <Section title={tr('items', 'Items ({{n}})', { n: itemList.length })}>
            <div style={ST.note}>{tr('orderNote', 'Drawn top to bottom: an item\'s occluders hide only the items below it, so list the near pieces first.')}</div>
            <div style={{ ...ST.list, maxHeight: 240 }}>
              {itemList.map((it, i) => (
                <div key={i} onClick={() => setSelItem(i)} title={itemSummary(it)}
                  style={{ ...ST.listItem, background: i === selItem ? '#3a2e18' : undefined, color: badItems.has(i) ? '#ff8080' : placement.groupedOut[i] ? '#667' : '#ccd' }}>
                  {i}. {typeof it.name === 'string' && it.name ? it.name : <i style={{ color: '#889' }}>{tr('unnamed', 'unnamed')}</i>} <span style={ST.dim}>{itemSummary(it)}</span>
                </div>
              ))}
            </div>
            <div style={ST.btnGrid}>
              <button style={ST.btn} onClick={doAddItem} disabled={!raw} title={tr('addItemTip', 'Add an item after the selected one')}>{tr('addItem', 'Add')}</button>
              <button style={ST.btn} onClick={doDuplicate} disabled={selItem === null} title={tr('duplicateTip', 'Duplicate the selected item (Ctrl+D)')}>{tr('duplicate', 'Duplicate')}</button>
              <button style={ST.btn} onClick={doDelete} disabled={selItem === null} title={tr('deleteTip', 'Delete the selected item (Del)')}>{tr('delete', 'Delete')}</button>
              <button style={ST.btn} onClick={() => doMove(-1)} disabled={selItem === null || selItem === 0} title={tr('upTip', 'Draw it earlier (Alt+Up)')}>↑</button>
              <button style={ST.btn} onClick={() => doMove(1)} disabled={selItem === null || selItem >= itemList.length - 1} title={tr('downTip', 'Draw it later (Alt+Down)')}>↓</button>
            </div>
          </Section>

          <Section title={tr('groups', 'Groups ({{n}})', { n: groupList.length })}>
            <div style={ST.note}>{tr('groupsNote', 'The game passes a groups mask to vpy3d_draw_scene: bit n is the n-th group. The checkboxes are the preview\'s mask.')}</div>
            {groupList.map((g, gi) => (
              <div key={`${gi}:${g}`} style={ST.row}>
                <label style={ST.check} title={tr('maskTip', 'Preview with this group\'s bit set')}>
                  <input type="checkbox" checked={((mask >>> gi) & 1) === 1} onChange={(e) => setMask((m) => (e.target.checked ? m | (1 << gi) : m & ~(1 << gi)))} />
                  <span style={{ ...ST.dim, width: 26 }}>b{gi}</span>
                </label>
                <span style={{ flex: 1, color: badGroups.has(gi) ? '#ff8080' : undefined }}>{textInput(g, (s) => doRenameGroup(gi, s), { width: 110 })}</span>
                <button style={ST.btnSmall} onClick={() => doDeleteGroup(gi)} title={tr('deleteGroupTip', 'Delete the group; its items are drawn always again')}>✕</button>
              </div>
            ))}
            <div style={ST.row}>
              <input value={newGroup} onChange={(e) => setNewGroup(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') doAddGroup(); }} placeholder={tr('groupName', 'group name')} style={{ ...ST.input, width: 130 }} disabled={!raw} />
              <button style={ST.btnSmall} onClick={doAddGroup} disabled={!raw || !newGroup.trim() || groupList.length >= S3.MAX_GROUPS}>{tr('addGroup', 'Add group')}</button>
            </div>
          </Section>

          <Section title={tr('sceneFog', 'Scene fog')}>
            <Row label={tr('fogOn', 'Fog')} tip={tr('fogOnTip', 'Fade the pieces with depth: full brightness up to "full", gone at "gone" (how, per item: its Fog)')}>
              <input type="checkbox" checked={!!sceneFogRaw} disabled={!raw} onChange={(e) => apply((r) => { const n = { ...r }; if (e.target.checked) n.fog = { full: 3000, gone: 17500 }; else delete n.fog; return n; })} />
            </Row>
            {sceneFogRaw && (
              <>
                <Row label={tr('fogFull', 'Full until')}>{numInput(typeof sceneFogRaw.full === 'number' ? sceneFogRaw.full : 0, (n) => setSceneFog('full', n), { width: 80 })}</Row>
                <Row label={tr('fogGone', 'Gone at')}>{numInput(typeof sceneFogRaw.gone === 'number' ? sceneFogRaw.gone : 0, (n) => setSceneFog('gone', n), { width: 80 })}</Row>
              </>
            )}
            <Row label={tr('name', 'Name')}>{textInput(typeof raw?.name === 'string' ? raw.name : '', (s) => apply((r) => { const n = { ...r }; if (s) n.name = s; else delete n.name; return n; }), { width: 130 })}</Row>
          </Section>

          <Section title={errorCount ? tr('issuesErr', 'Problems: {{n}} error(s)', { n: errorCount }) : tr('issuesOk', 'Checks')}>
            {!raw ? null : !issues.length && !meshWarnings.length ? (
              <div style={{ color: '#9fd89f' }}>{meshNames ? tr('valid', 'Compiles.') : tr('validNoList', 'No errors (the meshes could not be listed, so they were not checked).')}</div>
            ) : (
              <div style={ST.list}>
                {sceneIssues.concat(issues.filter((i) => i.item !== undefined)).slice(0, 200).map((is, k) => (
                  <div key={k} style={{ ...ST.listItem, color: '#ff8080' }} onClick={() => { if (is.item !== undefined) setSelItem(is.item); }} title={is.message}>✖ {is.message}</div>
                ))}
                {meshWarnings.map((w, k) => <div key={`w${k}`} style={{ ...ST.listItem, color: '#e6c07a' }} title={w}>⚠ {w}</div>)}
              </div>
            )}
          </Section>
        </div>

        {/* viewport */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <div ref={wrapRef} style={ST.viewport}>
            <canvas
              ref={canvasRef}
              style={{ width: size.w, height: size.h, display: 'block', cursor: 'default' }}
              onMouseDown={onMouseDown}
              onContextMenu={(e) => e.preventDefault()}
            />
            {!raw && (
              <div style={ST.overlay}>
                {tr('notJson', 'This document is not a .vscene JSON object.')}{' '}
                <button style={{ ...ST.btn, pointerEvents: 'auto' }} onClick={startNew}>{tr('startNew', 'Start a new scene (replaces the text)')}</button>
              </div>
            )}
            <div style={ST.status}>
              <span>{view === '3d' ? `3D  ${Math.round(rot.pitch)}° / ${Math.round(rot.yaw)}°` : viewButtons.find((b) => b[0] === view)?.[1]}</span>
              <span>{tr('copies', '{{n}} copies drawn', { n: placement.copies.length })}</span>
              <span>{tr('zoom', 'zoom')} {zoom.toFixed(2)}×</span>
              {message && <span style={{ color: message.error ? '#ff8080' : '#9fd89f' }}>{message.text}</span>}
            </div>
          </div>
          {/* pos */}
          <div style={ST.posBar}>
            <button style={playing ? ST.btnOn : ST.btn} onClick={() => setPlaying((p) => !p)} title={tr('playTip', 'Advance pos.z continuously (Space)')}>{playing ? '❚❚' : '▶'}</button>
            <span style={ST.dim} title={tr('speedTip', 'pos.z units per second while playing (negative goes back)')}>{tr('speed', 'speed')}</span>
            {numInput(speed, (n) => setSpeed(Math.round(n)), { width: 64, step: 100 })}
            <button style={ST.btn} onClick={() => { setPlaying(false); setPos([0, 0, 0]); }} title={tr('resetPosTip', 'Back to pos 0, 0, 0')}>{tr('resetPos', 'pos 0')}</button>
            {(['x', 'y', 'z'] as const).map((a, k) => (
              <span key={a} style={{ display: 'flex', alignItems: 'center', gap: 3, flex: k === 2 ? 2 : 1, minWidth: 0 }} title={tr('posTip', 'The game\'s pos[3]: how far it has gone along each axis')}>
                <span style={ST.dim}>pos.{a}</span>
                <input type="range" min={-posSpan} max={posSpan} step={10} value={pos[k]} style={{ flex: 1, minWidth: 40 }}
                  onChange={(e) => { const v = Number(e.target.value); setPos((p) => { const c = [...p] as Vec3; c[k] = v; return c; }); }} />
                {numInput(pos[k], (n) => setPos((p) => { const c = [...p] as Vec3; c[k] = Math.round(n); return c; }), { width: 70 })}
              </span>
            ))}
          </div>
        </div>

        {/* right: the selected item */}
        <div style={ST.panel}>
          {!sel || selItem === null ? (
            <div style={ST.dim}>{tr('noItem', 'Select an item, or add one.')}</div>
          ) : (
            <>
              <Section title={tr('itemN', 'Item {{i}}', { i: selItem })}>
                {selIssues.map((is, k) => <div key={k} style={{ color: '#ff8080', fontSize: 11, margin: '2px 0' }}>✖ {is.message}</div>)}
                <Row label={tr('itemName', 'Name')} tip={tr('itemNameTip', 'A label for you; the game does not see it')}>
                  {textInput(typeof sel.name === 'string' ? sel.name : '', (s) => setField('name', s || undefined), { width: 140 })}
                </Row>
                <div style={ST.subTitle} title={tr('meshTip', 'The .vmesh pieces (assets/meshes). Several meshes take turns along a repeat: copy n uses mesh n mod their count.')}>
                  {selMeshes.length > 1 ? tr('meshesTurns', 'Meshes (take turns)') : tr('mesh', 'Mesh')}
                </div>
                {(selMeshes.length ? selMeshes : ['']).map((m, k) => (
                  <div key={k} style={ST.row}>
                    {meshSelect(m, (n) => { const next = [...selMeshes]; next[k] = n; apply((r) => S3.setItemMeshes(r, selItem, next.length ? next : [n], Array.isArray(sel.mesh))); })}
                    {selMeshes.length > 1 && (
                      <span style={{ display: 'flex', gap: 2 }}>
                        <button style={ST.btnSmall} disabled={k === 0} onClick={() => { const next = [...selMeshes]; [next[k - 1], next[k]] = [next[k], next[k - 1]]; apply((r) => S3.setItemMeshes(r, selItem, next, true)); }}>↑</button>
                        <button style={ST.btnSmall} disabled={k === selMeshes.length - 1} onClick={() => { const next = [...selMeshes]; [next[k + 1], next[k]] = [next[k], next[k + 1]]; apply((r) => S3.setItemMeshes(r, selItem, next, true)); }}>↓</button>
                        <button style={ST.btnSmall} onClick={() => apply((r) => S3.setItemMeshes(r, selItem, selMeshes.filter((_, j) => j !== k)))}>✕</button>
                      </span>
                    )}
                  </div>
                ))}
                <button style={ST.btnSmall} onClick={() => apply((r) => S3.setItemMeshes(r, selItem, [...selMeshes, selMeshes[selMeshes.length - 1] || defaultMesh()]))}
                  title={tr('addMeshTip', 'Add a mesh to take turns with (needs a repeat)')}>{tr('addMesh', '+ mesh')}</button>
                {meshNames && !meshNames.length && <div style={ST.note}>{tr('noMeshes', 'No .vmesh in assets/meshes (or its folders) yet: create one first (File > New > 3D Mesh).')}</div>}

                <div style={ST.subTitle} title={tr('atTip', 'Where the piece stands: whole numbers, a missing axis is 0')}>{tr('at', 'At')}</div>
                <Row label="X Y Z">
                  {S3.AXES.map((a, k) => <React.Fragment key={a}>{numInput(S3.vecOf(sel, 'at')[k], (n) => apply((r) => S3.setItemAxis(r, selItem, 'at', a, n)), { width: 66 })}</React.Fragment>)}
                </Row>
                <div style={ST.subTitle} title={tr('followTip', 'How far the piece moves per unit of pos, per axis: -1 on z comes at you as pos.z grows; 0.9167 on x slides by almost as fast as you turn. Kept to 1/65536.')}>{tr('follow', 'Follow (× pos)')}</div>
                <Row label="X Y Z">
                  {S3.AXES.map((a, k) => <React.Fragment key={a}>{numInput(S3.vecOf(sel, 'follow')[k], (n) => apply((r) => S3.setItemAxis(r, selItem, 'follow', a, n)), { width: 66, step: 0.0001 })}</React.Fragment>)}
                </Row>
              </Section>

              <Section title={tr('repeat', 'Repeat')}>
                <Row label={tr('repeatOn', 'Copies')} tip={tr('repeatTip', '"count" copies "step" apart along "axis"; they wrap with the movement, so the first is always within one step of "at"')}>
                  <input type="checkbox" checked={!!rep} onChange={(e) => setField('repeat', e.target.checked ? { axis: 'z', step: 2000, count: 8 } : undefined)} />
                </Row>
                {rep && (
                  <>
                    <Row label={tr('axis', 'Axis')}>
                      <select value={isObj(sel.repeat) && typeof sel.repeat.axis === 'string' ? sel.repeat.axis : 'z'} style={ST.input}
                        onChange={(e) => apply((r) => S3.setItemSub(r, selItem, 'repeat', 'axis', e.target.value))}>
                        {S3.AXES.map((a) => <option key={a} value={a}>{a}</option>)}
                      </select>
                    </Row>
                    <Row label={tr('step', 'Step')}>{numInput(rep.step, (n) => apply((r) => S3.setItemSub(r, selItem, 'repeat', 'step', Math.round(n))), { width: 80, min: 1 })}</Row>
                    <Row label={tr('count', 'Count')}>{numInput(rep.count, (n) => apply((r) => S3.setItemSub(r, selItem, 'repeat', 'count', Math.round(n))), { width: 60, min: 1, max: 255 })}</Row>
                  </>
                )}
                <Row label={tr('window', 'Window (world z)')} tip={tr('windowTip', 'Draw a copy only while its z in the world is within min..max (each bound optional): the near bays only, nothing behind the camera')}>
                  <input type="checkbox" checked={!!win} onChange={(e) => setField('window', e.target.checked ? {} : undefined)} />
                </Row>
                {win && (
                  <Row label={tr('minMax', 'min / max')}>
                    {optInput(win.min, (n) => apply((r) => S3.setItemSub(r, selItem, 'window', 'min', n === undefined ? undefined : Math.round(n))), { placeholder: tr('none', 'none') })}
                    {optInput(win.max, (n) => apply((r) => S3.setItemSub(r, selItem, 'window', 'max', n === undefined ? undefined : Math.round(n))), { placeholder: tr('none', 'none') })}
                  </Row>
                )}
                <div style={ST.dim}>
                  {tr('drawnNow', '{{n}} copies drawn at this pos', { n: drawnCopies })}
                  {placement.windowed[selItem] ? `, ${tr('windowedN', '{{n}} outside the window', { n: placement.windowed[selItem] })}` : ''}
                  {placement.groupedOut[selItem] ? `, ${tr('groupedOut', 'switched off by the groups mask')}` : ''}
                </div>
              </Section>

              <Section title={tr('look', 'Brightness, fog, group')}>
                <Row label={tr('br', 'Brightness %')} tip={tr('brTip', 'Percent of the brightness the scene is drawn at (1-100; blank = 100)')}>
                  {optInput(typeof sel.br === 'number' ? sel.br : null, (n) => setField('br', n === undefined ? undefined : Math.round(n)), { width: 60, placeholder: '100' })}
                </Row>
                <Row label={tr('fogMode', 'Fog')} tip={tr('fogModeTip', 'true: each scenery line segment by its depth (faces keep their brightness); "whole": each copy as one, faces included, by the depth of its origin (skipped when too dim); false: never faded')}>
                  <select value={sel.fog === false ? 'false' : sel.fog === 'whole' ? 'whole' : 'true'} style={ST.input}
                    onChange={(e) => setField('fog', e.target.value === 'true' ? undefined : e.target.value === 'false' ? false : 'whole')}>
                    <option value="true">{tr('fogSegment', 'per segment (true)')}</option>
                    <option value="whole">{tr('fogWhole', 'whole copy ("whole")')}</option>
                    <option value="false">{tr('fogNone', 'none (false)')}</option>
                  </select>
                </Row>
                <Row label={tr('group', 'Group')} tip={tr('groupTip', 'Drawn only while that group\'s bit is set; "!name": only while it is clear')}>
                  <select value={grp ? `${grp.negated ? '!' : ''}${grp.name}` : ''} style={{ ...ST.input, maxWidth: 140 }}
                    onChange={(e) => setField('group', e.target.value || undefined)}>
                    <option value="">{tr('always', '(always drawn)')}</option>
                    {grp && !groupList.includes(grp.name) && <option value={`${grp.negated ? '!' : ''}${grp.name}`}>{`${grp.negated ? '!' : ''}${grp.name} (${tr('missing', 'missing')})`}</option>}
                    {groupList.flatMap((g) => [
                      <option key={g} value={g}>{g}</option>,
                      <option key={`!${g}`} value={`!${g}`}>{tr('notGroup', 'not {{g}}', { g })} (!{g})</option>,
                    ])}
                  </select>
                </Row>
              </Section>
            </>
          )}
          <div style={ST.help}>
            {tr('help', 'Click a piece to select its item · left drag: pan (orbit in 3D) · middle drag: pan · Shift+middle or Alt+drag: orbit · wheel: zoom · 0-4: views · Space: play · Up/Down: item · Alt+Up/Down: move item · Ctrl+D duplicate · Del delete · Ctrl+Z / Ctrl+Y')}
          </div>
        </div>
      </div>
    </div>
  );
};

// ── small presentational pieces ─────────────────────────────────────────────

const Section: React.FC<{ title: string; children?: React.ReactNode }> = ({ title, children }) => (
  <div style={ST.section}>
    <div style={ST.sectionTitle}>{title}</div>
    {children}
  </div>
);
const Row: React.FC<{ label: string; tip?: string; children?: React.ReactNode }> = ({ label, tip, children }) => (
  <div style={ST.row} title={tip}>
    <span style={ST.label}>{label}</span>
    <span style={{ display: 'flex', gap: 4, alignItems: 'center' }}>{children}</span>
  </div>
);

const btnBase: React.CSSProperties = {
  background: '#2c2c44', color: '#ccd', border: '1px solid #3d3d5c', borderRadius: 3,
  padding: '3px 8px', fontSize: 12, cursor: 'pointer',
};
const ST: Record<string, React.CSSProperties> = {
  root: { display: 'flex', flexDirection: 'column', height: '100%', width: '100%', background: '#12121c', color: '#ccd', fontSize: 12, outline: 'none' },
  toolbar: { display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 4, padding: '4px 6px', borderBottom: '1px solid #2a2a3e', background: '#181826' },
  posBar: { display: 'flex', alignItems: 'center', gap: 6, padding: '4px 6px', borderTop: '1px solid #2a2a3e', background: '#181826' },
  sep: { width: 1, height: 18, background: '#33334d', margin: '0 4px' },
  btn: btnBase,
  btnOn: { ...btnBase, background: '#4a4a8e', color: '#fff', border: '1px solid #7a7abf' },
  btnSmall: { ...btnBase, padding: '1px 6px', fontSize: 11 },
  check: { display: 'flex', alignItems: 'center', gap: 3, color: '#aab', cursor: 'pointer' },
  body: { flex: 1, display: 'flex', minHeight: 0 },
  viewport: { flex: 1, position: 'relative', minWidth: 0, minHeight: 0, overflow: 'hidden' },
  overlay: { position: 'absolute', top: 40, left: 20, right: 20, color: '#e6c07a', textAlign: 'center', pointerEvents: 'none' },
  status: { position: 'absolute', bottom: 0, left: 0, right: 0, display: 'flex', gap: 14, padding: '2px 8px 2px 72px', background: 'rgba(16,16,26,0.85)', color: '#889', fontFamily: 'monospace', fontSize: 11, pointerEvents: 'none' },
  panel: { width: 270, flexShrink: 0, overflowY: 'auto', borderLeft: '1px solid #2a2a3e', background: '#151522', padding: 6 },
  section: { marginBottom: 10, paddingBottom: 6, borderBottom: '1px solid #24243a' },
  sectionTitle: { fontWeight: 600, color: '#dde', marginBottom: 4 },
  subTitle: { color: '#aab', marginTop: 6 },
  row: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 6, margin: '3px 0' },
  label: { color: '#99a' },
  input: { background: '#0f0f18', color: '#dde', border: '1px solid #3d3d5c', borderRadius: 3, padding: '2px 4px', fontSize: 12 },
  dim: { color: '#889' },
  note: { color: '#b9a', fontSize: 11, margin: '4px 0' },
  btnGrid: { display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 6 },
  list: { maxHeight: 160, overflowY: 'auto', fontFamily: 'monospace', fontSize: 11 },
  listItem: { padding: '1px 3px', cursor: 'pointer', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' },
  help: { color: '#667', fontSize: 10.5, lineHeight: 1.4 },
};
