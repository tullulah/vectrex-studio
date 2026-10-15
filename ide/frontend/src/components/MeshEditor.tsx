/**
 * MeshEditor — editor for `.vmesh`, the 3D surface meshes of the SDK's vpy3d C
 * library (docs/ASSETS.md). The model (parsing, validation, geometry, edit
 * operations) lives in ./mesh/vmeshModel.ts; the view math is shared with the
 * VectorEditor (utils/view3d.ts).
 *
 * - Views: front (XY), top (XZ), side (YZ) and an orbiting 3D view. Middle
 *   button pans, middle button + Shift (or Alt + left, or the right button)
 *   orbits, the wheel zooms to the cursor — the VectorEditor's 3D controls.
 * - Solid (D): faces filled, far ones first, lit from the viewer, in their own
 *   colour when the file has "face_colors" (imported models carry the original
 *   game's), each outlined; in the vpy3d view the edges vpy3d draws go on top.
 * - "vpy3d" display draws only what vpy3d_draw_mesh draws from this angle
 *   (creases, silhouettes, rims, same crease threshold), the rest faint.
 * - Vertices: select (click, Shift-click, box), drag, nudge, add, delete,
 *   numeric X/Y/Z. Faces: make from selected vertices in order, delete, flip,
 *   wind outward. The format has no edge list, so CONNECT splits a face along
 *   two of its corners and DISCONNECT merges the two faces across an edge.
 * - Lofted files (`sections`) are previewed, and can be converted to vertices
 *   + faces to edit them.
 * - Scenery: "lines" (polylines, drawn at "br"% brightness) and "occluders"
 *   (convex solids, never drawn, shown as a faint orange hull). The Line tool
 *   clicks points on the view plane (Enter / double-click ends, Esc cancels);
 *   the Occluder tool drags a box on a front/top/side view, or "Box occluder"
 *   wraps the selection. Their points select, drag, nudge and delete like
 *   vertices; clicking a line or an occluder outline selects all of it. They
 *   are editable in lofted files too (they do not touch the sections).
 * - Saves the same JSON: fields the editor does not know are kept.
 */

import React, { useCallback, useEffect, useMemo, useReducer, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import * as M from './mesh/vmeshModel';
import { useViewBg, viewBgCss } from '../utils/viewBg';
import {
  DEFAULT_ROTATION_3D, orbitRotation, projectView, viewForward,
  type Rotation3D, type ViewMode,
} from '../utils/view3d';

interface MeshEditorProps {
  /** Parsed JSON of the document (undefined if it does not parse). */
  resource?: unknown;
  /** file:// URI of the document: resolves `.vec` sections and names new meshes. */
  docUri?: string;
  onChange?: (raw: M.VmeshRaw) => void;
}

type Tool = 'select' | 'add' | 'line' | 'occluder';
type Display = 'wire' | 'vpy3d';

type Drag =
  | { kind: 'pan'; x: number; y: number; panX: number; panY: number }
  | { kind: 'orbit'; x: number; y: number }
  | { kind: 'move'; x: number; y: number; base: M.MeshData; baseScene: M.Scenery; primary: { v: number } | { s: M.ScenePointRef }; moved: boolean }
  | { kind: 'box'; x0: number; y0: number; x: number; y: number; additive: boolean }
  | { kind: 'occ'; x0: number; y0: number; x: number; y: number };

interface Proj { x: number; y: number; depth: number }

const EMPTY: M.MeshData = { vertices: [], faces: [] };

/** "#rrggbb" times a light level (0..1), as a CSS colour. */
function shadeHex(hex: string, k: number): string {
  const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex);
  const [r, g, b] = m ? [parseInt(m[1], 16), parseInt(m[2], 16), parseInt(m[3], 16)] : [138, 147, 168];
  const c = (v: number) => Math.max(0, Math.min(255, Math.round(v * k)));
  return `rgb(${c(r)},${c(g)},${c(b)})`;
}
const EMPTY_SCENE: M.Scenery = { lines: [], occluders: [] };
const refKey = (r: M.ScenePointRef) => `${r.kind}:${r.item}:${r.point}`;
/** Is every point of one line / occluder selected (and only those)? Then that item is "the selection". */
function wholeItem(sc: M.Scenery, refs: M.ScenePointRef[]): { kind: M.ScenePointRef['kind']; item: number } | null {
  if (!refs.length) return null;
  const { kind, item } = refs[0];
  if (refs.some((r) => r.kind !== kind || r.item !== item)) return null;
  const o = M.sceneList(sc, kind)[item];
  if (!o) return null;
  return new Set(refs.map((r) => r.point)).size === o.points.length ? { kind, item } : null;
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
/** The colour of a scenery line at `br` percent. */
function lineColour(br: number): string {
  const k = 0.25 + 0.75 * Math.max(1, Math.min(100, br)) / 100;
  return `rgb(${Math.round(150 * k)},${Math.round(225 * k)},${Math.round(255 * k)})`;
}
const HISTORY_MAX = 200;

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
  if (/^([A-Za-z]:)?\//.test(rel)) return rel;
  const parts = `${dir}/${rel}`.replace(/\\/g, '/').split('/');
  const out: string[] = [];
  for (const p of parts) {
    if (p === '..' && out.length && out[out.length - 1] !== '..' && out[out.length - 1] !== '') out.pop();
    else if (p !== '.') out.push(p);
  }
  return out.join('/').replace(/\/+/g, '/');
}
function stemOf(uri?: string): string {
  if (!uri) return 'mesh';
  const base = uri.replace(/\\/g, '/').split('/').pop() || 'mesh';
  return base.replace(/\.vmesh$/i, '') || 'mesh';
}
const sub = (a: number[], b: number[]) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];

/** A tidy grid step (1, 2, 5 x 10^n) at least `min`. */
function niceStep(min: number): number {
  const p = Math.pow(10, Math.floor(Math.log10(Math.max(min, 1e-6))));
  for (const m of [1, 2, 5, 10]) if (m * p >= min) return m * p;
  return 10 * p;
}

function pointInPoly(x: number, y: number, poly: { x: number; y: number }[]): boolean {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const a = poly[i], b = poly[j];
    if ((a.y > y) !== (b.y > y) && x < ((b.x - a.x) * (y - a.y)) / (b.y - a.y) + a.x) inside = !inside;
  }
  return inside;
}
function distToSeg(px: number, py: number, a: { x: number; y: number }, b: { x: number; y: number }): number {
  const dx = b.x - a.x, dy = b.y - a.y;
  const l2 = dx * dx + dy * dy;
  const t = l2 ? Math.max(0, Math.min(1, ((px - a.x) * dx + (py - a.y) * dy) / l2)) : 0;
  return Math.hypot(px - (a.x + t * dx), py - (a.y + t * dy));
}

// ── component ──────────────────────────────────────────────────────────────

export const MeshEditor: React.FC<MeshEditorProps> = ({ resource, docUri, onChange }) => {
  const { t } = useTranslation(['editor']);
  const tr = (k: string, d: string, o?: Record<string, unknown>) => t(`mesh.${k}`, { defaultValue: d, ...(o || {}) }) as string;

  // ── document + history ──
  const [raw, setRaw] = useState<M.VmeshRaw | null>(() => (isObj(resource) ? resource : null));
  const lastJsonRef = useRef<string>(JSON.stringify(resource ?? null));
  const histRef = useRef<{ stack: M.VmeshRaw[]; index: number }>({ stack: raw ? [raw] : [], index: raw ? 0 : -1 });
  const [, rerender] = useReducer((x: number) => x + 1, 0);

  const [sel, setSel] = useState<number[]>([]);
  /** Edges picked by clicking them (Shift adds): Delete dissolves these, merging their faces. */
  const [edgeSel, setEdgeSel] = useState<[number, number][]>([]);
  useEffect(() => {
    setEdgeSel((e) => (e.some(([a, b]) => !sel.includes(a) || !sel.includes(b)) ? e.filter(([a, b]) => sel.includes(a) && sel.includes(b)) : e));
  }, [sel]);
  const [face, setFace] = useState<number | null>(null);
  /** Selected line / occluder points (in click order). */
  const [ssel, setSsel] = useState<M.ScenePointRef[]>([]);
  const [message, setMessage] = useState<{ text: string; error: boolean } | null>(null);

  const emit = useCallback((next: M.VmeshRaw) => {
    lastJsonRef.current = JSON.stringify(next);
    onChange?.(next);
  }, [onChange]);

  const commit = useCallback((next: M.VmeshRaw) => {
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
    setSel([]);
    setFace(null);
    setSsel([]);
    setLinePts([]);
    rerender();
  }, [resource]);

  const flash = useCallback((text: string, error = false) => {
    setMessage({ text, error });
  }, []);
  useEffect(() => {
    if (!message) return;
    const id = window.setTimeout(() => setMessage(null), 4000);
    return () => window.clearTimeout(id);
  }, [message]);

  // ── .vec files referenced by lofted sections ──
  const docDir = useMemo(() => (docUri && docUri.startsWith('file://') ? dirOf(uriToFsPath(docUri)) : ''), [docUri]);
  const [vecFiles, setVecFiles] = useState<Record<string, unknown>>({});
  const vecInFlight = useRef(new Set<string>());
  const vecRefs = useMemo(() => {
    const s = raw && Array.isArray(raw.sections) ? raw.sections : [];
    return Array.from(new Set(s.filter(isObj).map((x) => x.vec).filter((v): v is string => typeof v === 'string')));
  }, [raw]);
  useEffect(() => {
    if (!docDir || !vecRefs.length) return;
    const api = (window as unknown as { files?: { readFile?: (p: string) => Promise<{ content: string } | { error: string }> } }).files;
    if (!api?.readFile) return;
    for (const rel of vecRefs) {
      const abs = joinPath(docDir, rel);
      if (abs in vecFiles || vecInFlight.current.has(abs)) continue;
      vecInFlight.current.add(abs);
      api.readFile(abs).then((res) => {
        vecInFlight.current.delete(abs);
        let entry: unknown;
        if ('error' in res) entry = { __error: `cannot read ${rel} (${res.error})` };
        else {
          try { entry = JSON.parse(res.content); } catch { entry = { __error: `${rel} is not valid JSON` }; }
        }
        setVecFiles((m) => ({ ...m, [abs]: entry }));
      }).catch(() => { vecInFlight.current.delete(abs); /* leave it pending */ });
    }
  }, [docDir, vecRefs, vecFiles]);
  const resolver = useCallback<M.VecResolver>((vec, path) => {
    if (!docDir) return undefined;
    const entry = vecFiles[joinPath(docDir, vec)];
    if (entry === undefined) return undefined;
    if (isObj(entry) && typeof entry.__error === 'string') return entry.__error;
    return M.ringFromVec(entry, path, vec);
  }, [docDir, vecFiles]);

  // ── derived mesh ──
  const lofted = !!raw && M.isLofted(raw);
  const loft = useMemo(() => (raw && lofted ? M.loftRaw(raw, resolver) : null), [raw, lofted, resolver]);
  const mesh = useMemo<M.MeshData>(() => {
    if (!raw) return EMPTY;
    if (lofted) return loft?.mesh ?? EMPTY;
    return M.meshFromRaw(raw);
  }, [raw, lofted, loft]);
  const editable = !!raw && !lofted;
  const [dragMesh, setDragMesh] = useState<M.MeshData | null>(null);
  const shown = dragMesh ?? mesh;
  const scenery = useMemo<M.Scenery>(() => (raw ? M.sceneryFromRaw(raw) : EMPTY_SCENE), [raw]);
  const [dragScene, setDragScene] = useState<M.Scenery | null>(null);
  const shownScene = dragScene ?? scenery;
  const issues = useMemo(() => (raw ? M.validateVmesh(raw, resolver) : []), [raw, resolver]);
  const errorCount = issues.filter((i) => i.level === 'error').length;
  const hardCos = raw ? M.hardCosQ14(raw) : 11585;
  const isOpen = raw?.open === true;
  const geo = useMemo(() => M.meshGeometry(shown, hardCos), [shown, hardCos]);
  const badVerts = useMemo(() => new Set(issues.filter((i) => i.level === 'error' && i.vertex !== undefined).map((i) => i.vertex!)), [issues]);
  const badFaces = useMemo(() => new Set(issues.filter((i) => i.vertex === undefined && i.face !== undefined).map((i) => i.face!)), [issues]);
  const badLines = useMemo(() => new Set(issues.filter((i) => i.level === 'error' && i.line !== undefined).map((i) => i.line!)), [issues]);
  const badOccs = useMemo(() => new Set(issues.filter((i) => i.level === 'error' && i.occluder !== undefined).map((i) => i.occluder!)), [issues]);

  // Keep the selection inside the mesh after undo/delete/reload.
  useEffect(() => {
    const nv = mesh.vertices.length, nf = mesh.faces.length;
    setSel((s) => (s.some((i) => i >= nv) ? s.filter((i) => i < nv) : s));
    setFace((f) => (f !== null && f >= nf ? null : f));
  }, [mesh]);
  useEffect(() => {
    setSsel((s) => (s.some((r) => !M.scenePointAt(scenery, r)) ? s.filter((r) => M.scenePointAt(scenery, r)) : s));
  }, [scenery]);

  // ── view ──
  const [viewMode, setViewMode] = useState<ViewMode>('3d');
  const [rot, setRot] = useState<Rotation3D>(DEFAULT_ROTATION_3D);
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [frameC, setFrameC] = useState<[number, number, number]>([0, 0, 0]);
  const [frameR, setFrameR] = useState(1000);
  const [tool, setTool] = useState<Tool>('select');
  /** The line being drawn with the Line tool (model points). */
  const [linePts, setLinePts] = useState<number[][]>([]);
  const [newLineClosed, setNewLineClosed] = useState(false);
  const [showOccluders, setShowOccluders] = useState(true);
  /** Thickness, along the view direction, of an occluder dragged on the view plane (0 = a flat wall). */
  const [occDepth, setOccDepth] = useState(0);
  const [occRect, setOccRect] = useState<{ x0: number; y0: number; x: number; y: number } | null>(null);
  useEffect(() => { if (tool !== 'line') setLinePts([]); }, [tool]);
  const [display, setDisplay] = useState<Display>('wire');
  const [showHidden, setShowHidden] = useState(true);
  const [solid, setSolid] = useState(true);
  const [bgGrey, setBgGrey] = useViewBg();
  const [showIndices, setShowIndices] = useState(false);
  const [showNormals, setShowNormals] = useState(false);
  const [snap, setSnap] = useState(true);
  const [snapStep, setSnapStep] = useState(50);
  const [box, setBox] = useState<{ x0: number; y0: number; x: number; y: number } | null>(null);
  const [hover, setHover] = useState<number | null>(null);
  const [hoverS, setHoverS] = useState<M.ScenePointRef | null>(null);
  /** The mouse, for the rubber band of the line being drawn. */
  const [mousePx, setMousePx] = useState<{ x: number; y: number } | null>(null);
  const [cursor, setCursor] = useState<{ x: number; y: number } | null>(null);
  const [cursorModel, setCursorModel] = useState<number[] | null>(null);

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

  const frameAll = useCallback((m: M.MeshData = mesh, sc: M.Scenery = scenery) => {
    const b = M.boundsOf(m, sc);
    if (!b) { setFrameC([0, 0, 0]); setFrameR(1000); }
    else {
      const { lo, hi } = b;
      const c: [number, number, number] = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2];
      const r = Math.max(50, Math.hypot(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]) / 2);
      setFrameC(c);
      setFrameR(r);
    }
    setZoom(1);
    setPan({ x: 0, y: 0 });
  }, [mesh, scenery]);

  // Frame the mesh when a document is opened.
  const framedFor = useRef<string | null>(null);
  useEffect(() => {
    const key = docUri ?? '';
    if (framedFor.current === key || !raw) return;
    if (!mesh.vertices.length && lofted && loft?.pending) return; // wait for the .vec rings
    framedFor.current = key;
    frameAll(mesh, scenery);
  }, [docUri, raw, mesh, scenery, lofted, loft, frameAll]);

  const scale = (Math.min(size.w, size.h) * 0.42 / frameR) * zoom;
  // Screen axes as model-space unit vectors (the inverse of the view rotation).
  const axes = useMemo(() => {
    const e = [[1, 0, 0], [0, 1, 0], [0, 0, 1]].map((a) => projectView(a[0], a[1], a[2], viewMode, rot));
    return {
      right: [e[0].x, e[1].x, e[2].x] as [number, number, number],
      up: [e[0].y, e[1].y, e[2].y] as [number, number, number],
      fwd: viewForward(viewMode, rot),
    };
  }, [viewMode, rot]);

  const toScreen = useCallback((x: number, y: number, z: number): Proj => {
    const p = projectView(x - frameC[0], y - frameC[1], z - frameC[2], viewMode, rot);
    return { x: size.w / 2 + p.x * scale + pan.x, y: size.h / 2 - p.y * scale + pan.y, depth: p.depth };
  }, [frameC, viewMode, rot, size, scale, pan]);

  /** Screen point → model point on the plane through `depthFrom` facing the viewer. */
  const toModel = useCallback((sx: number, sy: number, depthFrom: number[]): [number, number, number] => {
    const a = (sx - size.w / 2 - pan.x) / scale;
    const b = -(sy - size.h / 2 - pan.y) / scale;
    const { right, up, fwd } = axes;
    const p = [0, 1, 2].map((k) => frameC[k] + a * right[k] + b * up[k]);
    const d = (depthFrom[0] - p[0]) * fwd[0] + (depthFrom[1] - p[1]) * fwd[1] + (depthFrom[2] - p[2]) * fwd[2];
    return [p[0] + d * fwd[0], p[1] + d * fwd[1], p[2] + d * fwd[2]];
  }, [size, pan, scale, axes, frameC]);

  const proj = useMemo(() => shown.vertices.map((v) => toScreen(v.x, v.y, v.z)), [shown, toScreen]);
  const lineProj = useMemo(() => shownScene.lines.map((l) => l.points.map((v) => toScreen(v.x, v.y, v.z))), [shownScene, toScreen]);
  const occProj = useMemo(() => shownScene.occluders.map((o) => o.points.map((v) => toScreen(v.x, v.y, v.z))), [shownScene, toScreen]);

  /** In an orthographic view, snap the two plane axes of a model point. */
  const snapPoint = useCallback((p: number[]): number[] => {
    if (!snap || viewMode === '3d' || snapStep <= 0) return p.map(Math.round);
    const fwd = axes.fwd;
    return p.map((c, k) => (Math.abs(fwd[k]) > 0.5 ? Math.round(c) : Math.round(c / snapStep) * snapStep));
  }, [snap, snapStep, viewMode, axes]);

  // ── hit testing ──
  const hitVertex = useCallback((x: number, y: number): number | null => {
    // The nearest within 8 px; between (nearly) coincident ones, the nearer the viewer.
    let best: number | null = null, bestD = 8, bestDepth = Infinity;
    proj.forEach((p, i) => {
      const d = Math.hypot(p.x - x, p.y - y);
      if (d > 8) return;
      if (best === null || d < bestD - 1 || (Math.abs(d - bestD) <= 1 && p.depth < bestDepth)) { best = i; bestD = d; bestDepth = p.depth; }
    });
    return best;
  }, [proj]);
  const hitEdge = useCallback((x: number, y: number): M.Edge | null => {
    let best: M.Edge | null = null, bestD = 5;
    for (const e of geo.edges) {
      const a = proj[e.a], b = proj[e.b];
      if (!a || !b) continue;
      const d = distToSeg(x, y, a, b);
      if (d < bestD) { best = e; bestD = d; }
    }
    return best;
  }, [geo, proj]);
  /** The nearest line / occluder point within 8 px (occluders only while shown). */
  const hitScenePoint = useCallback((x: number, y: number): M.ScenePointRef | null => {
    let best: M.ScenePointRef | null = null, bestD = 8, bestDepth = Infinity;
    const scan = (kind: M.ScenePointRef['kind'], list: Proj[][]) => list.forEach((pts, item) => pts.forEach((p, point) => {
      const d = Math.hypot(p.x - x, p.y - y);
      if (d > 8) return;
      if (best === null || d < bestD - 1 || (Math.abs(d - bestD) <= 1 && p.depth < bestDepth)) { best = { kind, item, point }; bestD = d; bestDepth = p.depth; }
    }));
    scan('line', lineProj);
    if (showOccluders) scan('occ', occProj);
    return best;
  }, [lineProj, occProj, showOccluders]);
  /** A line within 5 px of a segment, else an occluder within 5 px of its outline. */
  const hitSceneItem = useCallback((x: number, y: number): { kind: M.ScenePointRef['kind']; item: number } | null => {
    let best: { kind: M.ScenePointRef['kind']; item: number } | null = null, bestD = 5;
    lineProj.forEach((pts, item) => {
      const closed = M.lineClosed(shownScene.lines[item]);
      for (let k = 0; k + 1 < pts.length || (closed && k < pts.length && pts.length > 2); k++) {
        const d = distToSeg(x, y, pts[k], pts[(k + 1) % pts.length]);
        if (d < bestD) { best = { kind: 'line', item }; bestD = d; }
      }
    });
    if (best || !showOccluders) return best;
    occProj.forEach((pts, item) => {
      const h = hull2d(pts);
      for (let k = 0; k < h.length; k++) {
        const d = distToSeg(x, y, h[k], h[(k + 1) % h.length]);
        if (d < bestD) { best = { kind: 'occ', item }; bestD = d; }
      }
    });
    return best;
  }, [lineProj, occProj, shownScene, showOccluders]);
  const hitFace = useCallback((x: number, y: number): number | null => {
    let best: number | null = null, bestDepth = Infinity;
    shown.faces.forEach((f, fi) => {
      if (f.length < 3 || f.some((i) => !proj[i])) return;
      const poly = f.map((i) => proj[i]);
      if (!pointInPoly(x, y, poly)) return;
      const depth = poly.reduce((a, p) => a + p.depth, 0) / poly.length;
      if (depth < bestDepth) { best = fi; bestDepth = depth; }
    });
    return best;
  }, [shown, proj]);

  // ── operations ──
  const baseRaw = useCallback((): M.VmeshRaw => raw ?? { name: stemOf(docUri), hard: 45 }, [raw, docUri]);
  const applyMesh = useCallback((m: M.MeshData, extra?: (r: M.VmeshRaw) => M.VmeshRaw) => {
    let next = M.meshToRaw(baseRaw(), m);
    if (extra) next = extra(next);
    commit(next);
  }, [baseRaw, commit]);
  /** One undo step that changes the mesh, the scenery or both (null = untouched). */
  const applyBoth = useCallback((m: M.MeshData | null, sc: M.Scenery | null) => {
    let next = baseRaw();
    if (m) next = M.meshToRaw(next, m);
    if (sc) next = M.sceneryToRaw(next, sc);
    commit(next);
  }, [baseRaw, commit]);
  const applyScene = useCallback((sc: M.Scenery) => applyBoth(null, sc), [applyBoth]);
  const runOp = useCallback((r: { mesh: M.MeshData } | { error: string }, after?: (m: M.MeshData) => void) => {
    if ('error' in r) { flash(r.error, true); return; }
    applyMesh(r.mesh);
    after?.(r.mesh);
  }, [applyMesh, flash]);

  const needEditable = useCallback(() => {
    if (editable) return true;
    flash(lofted ? tr('loftedReadOnly', 'A lofted mesh is read-only here: convert it to vertices + faces first') : tr('noMesh', 'Start from a primitive'), true);
    return false;
  }, [editable, lofted, flash]);

  const doDelete = useCallback(() => {
    if (ssel.length) {
      const whole = wholeItem(scenery, ssel);
      const m = sel.length && editable ? M.deleteVertices(mesh, sel) : null;
      applyBoth(m, M.deleteScenePoints(scenery, ssel));
      setSsel([]);
      if (m) { setSel([]); setFace(null); }
      flash(whole
        ? (whole.kind === 'line' ? tr('deletedLine', 'Deleted line {{i}}', { i: whole.item }) : tr('deletedOccluder', 'Deleted occluder {{i}}', { i: whole.item }))
        : tr('deletedPoints', 'Deleted {{n}} point(s); a line left with 1 point or an occluder with 2 goes too', { n: ssel.length }));
      return;
    }
    if (!needEditable()) return;
    if (edgeSel.length) {
      /* edges picked: dissolve them, the faces either side become one */
      const r = M.dissolveEdges(mesh, edgeSel);
      if (r.merged) applyMesh(r.mesh);
      setSel([]); setEdgeSel([]); setFace(null);
      flash(r.skipped
        ? tr('dissolvedSome', 'Dissolved {{n}} edge(s); {{k}} could not be (a rim, or already gone)', { n: r.merged, k: r.skipped })
        : tr('dissolved', 'Dissolved {{n}} edge(s): their faces merged', { n: r.merged }), !r.merged);
      return;
    }
    if (sel.length) {
      const n = sel.length;
      applyMesh(M.deleteVertices(mesh, sel));
      setSel([]); setFace(null);
      flash(tr('deletedVertices', 'Deleted {{n}} vertex(es) and their faces', { n }));
    } else if (face !== null) {
      applyMesh(M.deleteFaces(mesh, [face]));
      setFace(null);
    }
  }, [needEditable, sel, edgeSel, ssel, face, mesh, scenery, editable, applyMesh, applyBoth, flash]);
  const doMakeFace = useCallback(() => {
    if (!needEditable()) return;
    runOp(M.makeFace(mesh, sel), (m) => { setFace(m.faces.length - 1); setSel([]); });
  }, [needEditable, mesh, sel, runOp]);
  const doConnect = useCallback(() => {
    if (!needEditable()) return;
    if (sel.length !== 2) { flash(tr('needTwo', 'Select exactly two vertices'), true); return; }
    runOp(M.connectVertices(mesh, sel[0], sel[1]));
  }, [needEditable, mesh, sel, runOp, flash]);
  const doDisconnect = useCallback(() => {
    if (!needEditable()) return;
    if (sel.length !== 2) { flash(tr('needTwo', 'Select exactly two vertices'), true); return; }
    runOp(M.disconnectVertices(mesh, sel[0], sel[1]), () => setFace(null));
  }, [needEditable, mesh, sel, runOp, flash]);
  const doFlip = useCallback(() => {
    if (!needEditable()) return;
    if (face === null) { flash(tr('needFace', 'Select a face first'), true); return; }
    applyMesh(M.flipFaces(mesh, [face]));
  }, [needEditable, face, mesh, applyMesh, flash]);
  const doWindOutward = useCallback(() => {
    if (!needEditable()) return;
    applyMesh(M.windOutward(mesh));
  }, [needEditable, mesh, applyMesh]);
  const doRemoveUnused = useCallback(() => {
    if (!needEditable()) return;
    const before = mesh.vertices.length;
    const m = M.removeUnusedVertices(mesh);
    if (m.vertices.length === before) { flash(tr('noneUnused', 'Every vertex is in a face')); return; }
    applyMesh(m);
    setSel([]);
    flash(tr('removedUnused', 'Removed {{n}} unused vertex(es)', { n: before - m.vertices.length }));
  }, [needEditable, mesh, applyMesh, flash]);
  const doConvertLoft = useCallback(() => {
    if (!raw || !loft?.mesh) return;
    commit(M.meshToRaw(raw, loft.mesh));
    flash(tr('converted', 'Converted to vertices + faces'));
  }, [raw, loft, commit, flash]);

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

  const nudge = useCallback((dx: number, dy: number) => {
    const moveVerts = editable && sel.length > 0;
    if (!moveVerts && !ssel.length) return;
    const step = snap && snapStep > 0 ? snapStep : 1;
    const { right, up } = axes;
    const d = { x: Math.round((dx * right[0] + dy * up[0]) * step), y: Math.round((dx * right[1] + dy * up[1]) * step), z: Math.round((dx * right[2] + dy * up[2]) * step) };
    applyBoth(moveVerts ? M.moveVertices(mesh, sel, d) : null, ssel.length ? M.moveScenePoints(scenery, ssel, d) : null);
  }, [editable, sel, ssel, snap, snapStep, axes, mesh, scenery, applyBoth]);

  // ── scenery: lines and occluders ──
  const finishLine = useCallback(() => {
    if (linePts.length < 2) {
      if (linePts.length) flash(tr('lineNeedsTwo', 'A line needs at least 2 points'), true);
      setLinePts([]);
      return;
    }
    const r = M.addLine(scenery, linePts.map((p) => ({ x: p[0], y: p[1], z: p[2] })), newLineClosed);
    setLinePts([]);
    if ('error' in r) { flash(r.error, true); return; }
    applyScene(r.scenery);
    const item = r.scenery.lines.length - 1;
    setSsel(M.itemRefs(r.scenery, 'line', item));
    setSel([]); setFace(null);
    flash(tr('lineAdded', 'Line {{i}}: {{n}} points', { i: item, n: r.scenery.lines[item].points.length }));
  }, [linePts, scenery, newLineClosed, applyScene, flash]);

  const selectItem = useCallback((kind: M.ScenePointRef['kind'], item: number, add = false) => {
    const refs = M.itemRefs(scenery, kind, item);
    setSsel((s) => (add ? [...s, ...refs.filter((r) => !s.some((q) => refKey(q) === refKey(r)))] : refs));
    if (!add) { setSel([]); setFace(null); }
  }, [scenery]);

  /** The model points of the selection: vertices and line/occluder points. */
  const selPoints = useCallback((): M.MeshVertex[] => [
    ...sel.map((i) => shown.vertices[i]).filter(Boolean),
    ...ssel.map((r) => M.scenePointAt(shownScene, r)).filter((p): p is M.MeshVertex => !!p),
  ], [sel, ssel, shown, shownScene]);

  const doBoxOccluder = useCallback(() => {
    const pts = selPoints();
    if (!pts.length) { flash(tr('needSelection', 'Select vertices or line points first'), true); return; }
    const b = M.boundsOf({ vertices: pts, faces: [] })!;
    const occ = M.boxOccluder(b.lo, b.hi);
    if (!occ) { flash(tr('occFlat', 'The selection spans a line or a point: an occluder needs an area'), true); return; }
    const next = M.addOccluder(scenery, occ);
    applyScene(next);
    setShowOccluders(true);
    const item = next.occluders.length - 1;
    setSsel(M.itemRefs(next, 'occ', item));
    setSel([]); setFace(null);
    flash(tr('occAdded', 'Occluder {{i}}: {{n}} corners', { i: item, n: occ.points.length }));
  }, [selPoints, scenery, applyScene, flash]);

  const setLineBr = useCallback((item: number, br: number) => {
    applyScene(M.setLineProps(scenery, item, { br: br >= 100 && scenery.lines[item]?.br === undefined ? null : br }));
  }, [scenery, applyScene]);
  const setLineClosedProp = useCallback((item: number, closed: boolean) => {
    applyScene(M.setLineProps(scenery, item, { closed }));
  }, [scenery, applyScene]);
  const setLineFogProp = useCallback((item: number, fog: boolean) => {
    applyScene(M.setLineProps(scenery, item, { fog }));
  }, [scenery, applyScene]);

  // primitives
  const [primKind, setPrimKind] = useState<M.PrimitiveKind>('cube');
  const [primSize, setPrimSize] = useState(1000);
  const [primSeg, setPrimSeg] = useState(8);
  const addPrimitive = useCallback((replace: boolean) => {
    if (lofted) { needEditable(); return; }
    const prim = M.makePrimitive(primKind, Math.max(2, Math.min(60000, primSize)), primSeg);
    if (replace && mesh.vertices.length && !window.confirm(tr('confirmReplace', 'Replace the whole mesh with the primitive?'))) return;
    const m = replace || !mesh.vertices.length ? prim : M.appendMesh(mesh, prim);
    const plate = primKind === 'grid' && (replace || !mesh.vertices.length);
    applyMesh(m, (r) => {
      const o = { ...r };
      if (plate) o.open = true;
      else if (replace && o.open === true) delete o.open;
      return o;
    });
    setSel([]); setFace(null);
    frameAll(m);
  }, [lofted, needEditable, primKind, primSize, primSeg, mesh, applyMesh, frameAll]);

  // ── mouse ──
  const live = useRef({ hitVertex, hitEdge, hitFace, toModel, snapPoint, proj, lineProj, occProj, showOccluders, sel, ssel, scale, axes, editable, viewMode, frameC, occDepth, scenery });
  live.current = { hitVertex, hitEdge, hitFace, toModel, snapPoint, proj, lineProj, occProj, showOccluders, sel, ssel, scale, axes, editable, viewMode, frameC, occDepth, scenery };
  const dragSceneRef = useRef<M.Scenery | null>(null);
  const dragRef = useRef<Drag | null>(null);
  const dragMeshRef = useRef<M.MeshData | null>(null);

  const pos = (e: { clientX: number; clientY: number }) => {
    const r = canvasRef.current!.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };

  const endDrag = useCallback(() => {
    const d = dragRef.current;
    dragRef.current = null;
    if (!d) return;
    if (d.kind === 'move') {
      const m = dragMeshRef.current, sc = dragSceneRef.current;
      dragMeshRef.current = null;
      dragSceneRef.current = null;
      setDragMesh(null);
      setDragScene(null);
      if (d.moved && (m || sc)) applyBoth(m, sc);
    } else if (d.kind === 'box') {
      setBox(null);
      const x0 = Math.min(d.x0, d.x), x1 = Math.max(d.x0, d.x), y0 = Math.min(d.y0, d.y), y1 = Math.max(d.y0, d.y);
      if (x1 - x0 < 3 && y1 - y0 < 3) return;
      const L = live.current;
      const isIn = (p: Proj) => p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1;
      const inside: number[] = [];
      L.proj.forEach((p, i) => { if (isIn(p)) inside.push(i); });
      const sIn: M.ScenePointRef[] = [];
      L.lineProj.forEach((pts, item) => pts.forEach((p, point) => { if (isIn(p)) sIn.push({ kind: 'line', item, point }); }));
      if (L.showOccluders) L.occProj.forEach((pts, item) => pts.forEach((p, point) => { if (isIn(p)) sIn.push({ kind: 'occ', item, point }); }));
      setSel((s) => (d.additive ? [...s, ...inside.filter((i) => !s.includes(i))] : inside));
      setSsel((s) => (d.additive ? [...s, ...sIn.filter((r) => !s.some((q) => refKey(q) === refKey(r)))] : sIn));
    } else if (d.kind === 'occ') {
      setOccRect(null);
      const L = live.current;
      if (Math.abs(d.x - d.x0) < 3 || Math.abs(d.y - d.y0) < 3) return;
      const a = L.snapPoint(L.toModel(d.x0, d.y0, L.frameC)), b = L.snapPoint(L.toModel(d.x, d.y, L.frameC));
      const lo = [0, 1, 2].map((k) => Math.min(a[k], b[k])), hi = [0, 1, 2].map((k) => Math.max(a[k], b[k]));
      // the axis along the view: centred on the plane, occDepth thick
      const k = L.axes.fwd.findIndex((x) => Math.abs(x) > 0.5);
      if (k >= 0) { lo[k] = Math.round(a[k] - L.occDepth / 2); hi[k] = lo[k] + Math.max(0, Math.round(L.occDepth)); }
      const occ = M.boxOccluder(lo, hi);
      if (!occ) return;
      const next = M.addOccluder(L.scenery, occ);
      applyBoth(null, next);
      setShowOccluders(true);
      setSsel(M.itemRefs(next, 'occ', next.occluders.length - 1));
      setSel([]); setFace(null);
    }
  }, [applyBoth]);

  const onWindowMove = useCallback((e: MouseEvent) => {
    const d = dragRef.current;
    if (!d || !canvasRef.current) return;
    const p = pos(e);
    if (d.kind === 'pan') {
      setPan({ x: d.panX + p.x - d.x, y: d.panY + p.y - d.y });
    } else if (d.kind === 'orbit') {
      const dx = p.x - d.x, dy = p.y - d.y;
      d.x = p.x; d.y = p.y;
      setRot((r) => orbitRotation(r, dx, dy));
    } else if (d.kind === 'move') {
      const L = live.current;
      if (!d.moved && Math.hypot(p.x - d.x, p.y - d.y) < 3) return;
      d.moved = true;
      const a = (p.x - d.x) / L.scale, b = -(p.y - d.y) / L.scale;
      const { right, up } = L.axes;
      const v0 = 'v' in d.primary ? d.base.vertices[d.primary.v] : M.scenePointAt(d.baseScene, d.primary.s);
      if (!v0) return;
      const target = L.snapPoint([v0.x + a * right[0] + b * up[0], v0.y + a * right[1] + b * up[1], v0.z + a * right[2] + b * up[2]]);
      const delta = { x: target[0] - v0.x, y: target[1] - v0.y, z: target[2] - v0.z };
      if (L.editable && L.sel.length) {
        const moved = M.moveVertices(d.base, L.sel, delta);
        dragMeshRef.current = moved;
        setDragMesh(moved);
      }
      if (L.ssel.length) {
        const movedScene = M.moveScenePoints(d.baseScene, L.ssel, delta);
        dragSceneRef.current = movedScene;
        setDragScene(movedScene);
      }
    } else if (d.kind === 'box') {
      d.x = p.x; d.y = p.y;
      setBox({ x0: d.x0, y0: d.y0, x: p.x, y: p.y });
    } else if (d.kind === 'occ') {
      d.x = p.x; d.y = p.y;
      setOccRect({ x0: d.x0, y0: d.y0, x: p.x, y: p.y });
    }
  }, []);
  const onWindowUp = useCallback(() => {
    window.removeEventListener('mousemove', onWindowMove);
    window.removeEventListener('mouseup', onWindowUp);
    endDrag();
  }, [onWindowMove, endDrag]);
  const startDrag = useCallback((d: Drag) => {
    dragRef.current = d;
    window.addEventListener('mousemove', onWindowMove);
    window.addEventListener('mouseup', onWindowUp);
  }, [onWindowMove, onWindowUp]);
  useEffect(() => () => {
    window.removeEventListener('mousemove', onWindowMove);
    window.removeEventListener('mouseup', onWindowUp);
  }, [onWindowMove, onWindowUp]);

  const onMouseDown = (e: React.MouseEvent<HTMLCanvasElement>) => {
    containerRef.current?.focus();
    const p = pos(e);
    if (e.button === 1 || e.button === 2 || (e.button === 0 && e.altKey)) {
      e.preventDefault();
      const orbit = e.button === 2 || e.shiftKey || e.altKey;
      if (orbit) {
        if (viewMode !== '3d') setViewMode('3d');
        startDrag({ kind: 'orbit', x: p.x, y: p.y });
      } else {
        startDrag({ kind: 'pan', x: p.x, y: p.y, panX: pan.x, panY: pan.y });
      }
      return;
    }
    if (e.button !== 0) return;
    const multi = e.shiftKey || e.ctrlKey || e.metaKey;
    const v = hitVertex(p.x, p.y);

    if (tool === 'line') {
      // the second press of a double-click ends the line
      if (e.detail >= 2) { finishLine(); return; }
      const sp = v === null ? hitScenePoint(p.x, p.y) : null;
      const onto = v !== null ? shown.vertices[v] : sp ? M.scenePointAt(shownScene, sp) : undefined;
      const last = linePts[linePts.length - 1];
      const at = onto ? [onto.x, onto.y, onto.z] : snapPoint(toModel(p.x, p.y, last ?? frameC));
      setLinePts((l) => [...l, at]);
      return;
    }
    if (tool === 'occluder') {
      if (viewMode === '3d') { flash(tr('occNeedsOrtho', 'Drag an occluder box in the front, top or side view (keys 1-3)'), true); return; }
      startDrag({ kind: 'occ', x0: p.x, y0: p.y, x: p.x, y: p.y });
      return;
    }
    const startMove = (primary: { v: number } | { s: M.ScenePointRef }, nextSel: number[], nextS: M.ScenePointRef[]) => {
      live.current.sel = nextSel;
      live.current.ssel = nextS;
      if (!(editable && nextSel.length) && !nextS.length) return;
      startDrag({ kind: 'move', x: p.x, y: p.y, base: mesh, baseScene: scenery, primary, moved: false });
    };

    if (tool === 'add' && v === null) {
      if (!needEditable()) return;
      const last = sel.length ? mesh.vertices[sel[sel.length - 1]] : null;
      const at = snapPoint(toModel(p.x, p.y, last ? [last.x, last.y, last.z] : frameC));
      const r = M.addVertex(mesh, { x: at[0], y: at[1], z: at[2] });
      applyMesh(r.mesh);
      setSel((s) => [...s, r.index]);
      setFace(null);
      return;
    }
    if (v !== null) {
      let nextSel = sel;
      if (multi || tool === 'add') nextSel = sel.includes(v) ? (tool === 'add' ? sel : sel.filter((i) => i !== v)) : [...sel, v];
      else if (!sel.includes(v)) nextSel = [v];
      const nextS = multi || sel.includes(v) ? ssel : [];
      setSel(nextSel);
      setSsel(nextS);
      setFace(null);
      if (editable && nextSel.includes(v)) startMove({ v }, nextSel, nextS);
      return;
    }
    const sp = hitScenePoint(p.x, p.y);
    if (sp) {
      const has = ssel.some((r) => refKey(r) === refKey(sp));
      let nextS = ssel;
      if (multi) nextS = has ? ssel.filter((r) => refKey(r) !== refKey(sp)) : [...ssel, sp];
      else if (!has) nextS = [sp];
      const nextSel = multi || has ? sel : [];
      setSsel(nextS);
      setSel(nextSel);
      setFace(null);
      if (nextS.some((r) => refKey(r) === refKey(sp))) startMove({ s: sp }, nextSel, nextS);
      return;
    }
    const ed = hitEdge(p.x, p.y);
    if (ed) {
      setSel((s) => (multi ? [...s, ...[ed.a, ed.b].filter((i) => !s.includes(i))] : [ed.a, ed.b]));
      setEdgeSel((e) => {
        const pair: [number, number] = [ed.a, ed.b];
        if (!multi) return [pair];
        return e.some(([a, b]) => (a === ed.a && b === ed.b) || (a === ed.b && b === ed.a)) ? e : [...e, pair];
      });
      if (!multi) setSsel([]);
      setFace(null);
      return;
    }
    const it = hitSceneItem(p.x, p.y);
    if (it) {
      const refs = M.itemRefs(scenery, it.kind, it.item);
      const nextS = multi ? [...ssel, ...refs.filter((r) => !ssel.some((q) => refKey(q) === refKey(r)))] : refs;
      const nextSel = multi ? sel : [];
      setSsel(nextS);
      setSel(nextSel);
      setFace(null);
      if (refs.length) startMove({ s: refs[0] }, nextSel, nextS);
      return;
    }
    const f = hitFace(p.x, p.y);
    if (f !== null && !multi) {
      setFace(f);
      setSel([]);
      setSsel([]);
      return;
    }
    if (!multi) { setSel([]); setSsel([]); setFace(null); }
    startDrag({ kind: 'box', x0: p.x, y0: p.y, x: p.x, y: p.y, additive: multi });
  };

  const onCanvasMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (dragRef.current) return;
    const p = pos(e);
    setHover(hitVertex(p.x, p.y));
    setHoverS(hitScenePoint(p.x, p.y));
    setMousePx(tool === 'line' ? p : null);
    if (viewMode !== '3d') {
      const m = snapPoint(toModel(p.x, p.y, frameC));
      setCursor({ x: p.x, y: p.y });
      setCursorModel(m);
    } else {
      setCursor(null);
      setCursorModel(null);
    }
  };
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

  // ── keyboard ──
  const onKeyDown = (e: React.KeyboardEvent) => {
    const tag = (e.target as HTMLElement).tagName;
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
    const mod = e.ctrlKey || e.metaKey;
    const k = e.key;
    const done = () => { e.preventDefault(); e.stopPropagation(); };
    if (mod && (k === 'z' || k === 'Z')) { done(); if (e.shiftKey) redo(); else undo(); return; }
    if (mod && (k === 'y' || k === 'Y')) { done(); redo(); return; }
    if (mod && (k === 'a' || k === 'A')) {
      done();
      setSel(mesh.vertices.map((_, i) => i));
      setSsel([
        ...scenery.lines.flatMap((_, i) => M.itemRefs(scenery, 'line', i)),
        ...(showOccluders ? scenery.occluders.flatMap((_, i) => M.itemRefs(scenery, 'occ', i)) : []),
      ]);
      setFace(null);
      return;
    }
    if (mod) return;
    switch (k) {
      case '1': done(); setViewMode('xy'); return;
      case '2': done(); setViewMode('xz'); return;
      case '3': done(); setViewMode('yz'); return;
      case '4': done(); setViewMode('3d'); return;
      case 'Delete': case 'Backspace': done(); doDelete(); return;
      case 'f': case 'F': done(); doMakeFace(); return;
      case 'j': case 'J': done(); doConnect(); return;
      case 'k': case 'K': done(); doDisconnect(); return;
      case 'n': case 'N': done(); doFlip(); return;
      case 's': case 'S': done(); setTool('select'); setLinePts([]); return;
      case 'a': case 'A': done(); setTool('add'); return;
      case 'l': case 'L': done(); setTool('line'); return;
      case 'o': case 'O': done(); setTool('occluder'); return;
      case 'b': case 'B': done(); doBoxOccluder(); return;
      case 'Enter': if (tool === 'line') { done(); finishLine(); } return;
      case 'w': case 'W': done(); setDisplay((d) => (d === 'wire' ? 'vpy3d' : 'wire')); return;
      case 'd': case 'D': done(); setSolid((v) => !v); return;
      case 'Home': case 'h': case 'H': done(); frameAll(); return;
      case 'Escape':
        done();
        if (linePts.length) { setLinePts([]); return; }
        setSel([]); setSsel([]); setFace(null);
        return;
      case 'ArrowLeft': done(); nudge(e.shiftKey ? -10 : -1, 0); return;
      case 'ArrowRight': done(); nudge(e.shiftKey ? 10 : 1, 0); return;
      case 'ArrowUp': done(); nudge(0, e.shiftKey ? 10 : 1); return;
      case 'ArrowDown': done(); nudge(0, e.shiftKey ? -10 : -1); return;
    }
  };

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
    ctx.fillStyle = viewBgCss(bgGrey);
    ctx.fillRect(0, 0, size.w, size.h);

    // grid
    const minorStep = niceStep(14 / scale);
    if (viewMode !== '3d') {
      const tl = toModel(0, 0, frameC), br = toModel(size.w, size.h, frameC);
      const { right, up } = axes;
      const hAxis = right.findIndex((x) => Math.abs(x) > 0.5), vAxis = up.findIndex((x) => Math.abs(x) > 0.5);
      const h0 = Math.min(tl[hAxis], br[hAxis]), h1 = Math.max(tl[hAxis], br[hAxis]);
      const v0 = Math.min(tl[vAxis], br[vAxis]), v1 = Math.max(tl[vAxis], br[vAxis]);
      const lineAt = (axis: number, val: number) => {
        const a = [0, 0, 0], b = [0, 0, 0];
        a[axis] = val; b[axis] = val;
        const other = axis === hAxis ? vAxis : hAxis;
        const lo = axis === hAxis ? v0 : h0, hi = axis === hAxis ? v1 : h1;
        a[other] = lo; b[other] = hi;
        const pa = toScreen(a[0], a[1], a[2]), pb = toScreen(b[0], b[1], b[2]);
        ctx.beginPath(); ctx.moveTo(pa.x, pa.y); ctx.lineTo(pb.x, pb.y); ctx.stroke();
      };
      ctx.lineWidth = 1;
      for (const [axis, lo, hi] of [[hAxis, h0, h1], [vAxis, v0, v1]] as const) {
        for (let g = Math.ceil(lo / minorStep) * minorStep; g <= hi; g += minorStep) {
          ctx.strokeStyle = Math.abs(g) < 1e-9 ? '#3a4a6a' : (Math.round(g / minorStep) % 5 === 0 ? '#1e2233' : '#14161f');
          lineAt(axis, g);
        }
      }
    } else {
      // a ground grid through the origin (XZ), sized to the frame
      const ext = niceStep(frameR * 1.5);
      const step = niceStep(ext / 6);
      ctx.strokeStyle = '#161a26';
      ctx.lineWidth = 1;
      for (let g = -ext; g <= ext + 1e-9; g += step) {
        let a = toScreen(g, 0, -ext), b = toScreen(g, 0, ext);
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
        a = toScreen(-ext, 0, g); b = toScreen(ext, 0, g);
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      }
      // world axes through the origin
      const L = ext;
      for (const [d, col] of [[[1, 0, 0], '#a44'], [[0, 1, 0], '#4a4'], [[0, 0, 1], '#46c']] as const) {
        const o = toScreen(0, 0, 0), q = toScreen(d[0] * L, d[1] * L, d[2] * L);
        ctx.strokeStyle = col; ctx.beginPath(); ctx.moveTo(o.x, o.y); ctx.lineTo(q.x, q.y); ctx.stroke();
      }
    }

    const sselKeys = new Set(ssel.map(refKey));
    const itemSelected = (kind: M.ScenePointRef['kind'], item: number, n: number) => {
      if (!n) return false;
      for (let k = 0; k < n; k++) if (!sselKeys.has(`${kind}:${item}:${k}`)) return false;
      return true;
    };

    // occluders: a faint hull, behind everything
    if (showOccluders) {
      occProj.forEach((pts, oi) => {
        const h = hull2d(pts);
        if (!h.length) return;
        const on = itemSelected('occ', oi, pts.length);
        ctx.beginPath();
        h.forEach((q, i) => (i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y)));
        ctx.closePath();
        ctx.fillStyle = on ? 'rgba(255,150,50,0.16)' : 'rgba(230,130,40,0.07)';
        ctx.fill();
        ctx.strokeStyle = badOccs.has(oi) ? '#ff4d4d' : on ? '#ffaa28' : 'rgba(220,130,50,0.55)';
        ctx.lineWidth = on ? 1.6 : 1;
        ctx.setLineDash(on ? [] : [5, 3]);
        ctx.stroke();
        ctx.setLineDash([]);
      });
    }

    // solid: every face filled, far ones first (painter's), lit from the viewer, in its
    // own colour if the file has them; each outlined so the polygons read
    if (solid) {
      const fw = axes.fwd;
      const order: { fi: number; d: number }[] = [];
      shown.faces.forEach((f, fi) => {
        if (f.length < 3 || f.some((i) => !proj[i])) return;
        let d = 0;
        for (const i of f) d += proj[i].depth;
        order.push({ fi, d: d / f.length });
      });
      order.sort((a, b) => b.d - a.d);
      ctx.lineWidth = 1;
      for (const { fi } of order) {
        const f = shown.faces[fi], n = geo.normals[fi];
        const facing = n ? Math.abs(n[0] * fw[0] + n[1] * fw[1] + n[2] * fw[2]) : 0.5;
        const base = M.faceColor(shown, fi) ?? '#8a93a8';
        ctx.fillStyle = shadeHex(base, 0.35 + 0.65 * facing);
        ctx.strokeStyle = 'rgba(0,0,0,0.45)';
        ctx.beginPath();
        f.forEach((i, k) => (k ? ctx.lineTo(proj[i].x, proj[i].y) : ctx.moveTo(proj[i].x, proj[i].y)));
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
      }
    }

    // selected face fill
    if (face !== null && shown.faces[face] && shown.faces[face].every((i) => proj[i])) {
      const poly = shown.faces[face].map((i) => proj[i]);
      ctx.fillStyle = 'rgba(255,170,40,0.16)';
      ctx.beginPath();
      poly.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
      ctx.closePath();
      ctx.fill();
    }

    // edges
    const fwd = axes.fwd;
    const hidden: M.Edge[] = [], soft: M.Edge[] = [], lines: M.Edge[] = [];
    for (const e of geo.edges) {
      if (!proj[e.a] || !proj[e.b]) continue;
      if (display === 'vpy3d') (M.edgeVisible(geo, e, fwd, isOpen) ? lines : hidden).push(e);
      else (e.hard ? lines : soft).push(e);
    }
    const stroke = (list: M.Edge[], style: string, width: number, dash: number[] = []) => {
      if (!list.length) return;
      ctx.strokeStyle = style; ctx.lineWidth = width; ctx.setLineDash(dash);
      ctx.beginPath();
      for (const e of list) { const a = proj[e.a], b = proj[e.b]; ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); }
      ctx.stroke();
      ctx.setLineDash([]);
    };
    // Solid: the fills already show the shape; only what vpy3d draws goes on top.
    if (display === 'vpy3d' && showHidden && !solid) stroke(hidden, '#24304a', 1, [3, 4]);
    if (!solid) stroke(soft, '#2b5a3a', 1, [4, 3]);
    if (!solid || display === 'vpy3d') stroke(lines, display === 'vpy3d' ? '#b8ffb8' : '#5fd35f', display === 'vpy3d' ? 1.6 : 1.3);
    // picked edges (Delete dissolves them)
    if (edgeSel.length) {
      ctx.strokeStyle = '#ffaa28'; ctx.lineWidth = 3; ctx.beginPath();
      for (const [a, b] of edgeSel) {
        const pa = proj[a], pb = proj[b];
        if (pa && pb) { ctx.moveTo(pa.x, pa.y); ctx.lineTo(pb.x, pb.y); }
      }
      ctx.stroke();
    }

    // faces with errors
    ctx.strokeStyle = '#ff4d4d'; ctx.lineWidth = 2;
    for (const fi of badFaces) {
      const f = shown.faces[fi];
      if (!f || f.length < 2 || f.some((i) => !proj[i])) continue;
      ctx.beginPath();
      f.forEach((i, k) => (k ? ctx.lineTo(proj[i].x, proj[i].y) : ctx.moveTo(proj[i].x, proj[i].y)));
      ctx.closePath(); ctx.stroke();
    }

    // scenery lines, at their brightness
    lineProj.forEach((pts, li) => {
      if (pts.length < 2) return;
      const l = shownScene.lines[li];
      const on = itemSelected('line', li, pts.length);
      ctx.strokeStyle = badLines.has(li) ? '#ff4d4d' : on ? '#ffaa28' : lineColour(M.lineBr(l));
      ctx.lineWidth = on ? 2.2 : 1.5;
      ctx.beginPath();
      pts.forEach((q, i) => (i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y)));
      if (M.lineClosed(l) && pts.length > 2) ctx.closePath();
      ctx.stroke();
    });

    // selected face outline + normal
    const normalLen = frameR * 0.3;
    const drawNormal = (fi: number, col: string) => {
      const f = shown.faces[fi];
      if (!f || f.length < 3 || f.some((i) => !shown.vertices[i])) return;
      const c = M.centroidOf(shown.vertices, f), n = geo.normals[fi];
      const a = toScreen(c[0], c[1], c[2]), b = toScreen(c[0] + n[0] * normalLen, c[1] + n[1] * normalLen, c[2] + n[2] * normalLen);
      ctx.strokeStyle = col; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      ctx.fillStyle = col; ctx.fillRect(b.x - 2, b.y - 2, 4, 4);
    };
    if (showNormals) shown.faces.forEach((_, fi) => drawNormal(fi, '#3b8fa8'));
    if (face !== null && shown.faces[face] && shown.faces[face].every((i) => proj[i])) {
      const poly = shown.faces[face].map((i) => proj[i]);
      ctx.strokeStyle = '#ffaa28'; ctx.lineWidth = 2;
      ctx.beginPath();
      poly.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
      ctx.closePath(); ctx.stroke();
      // the winding: an arrow from the first corner toward the second
      const a = poly[0], b = poly[1];
      ctx.fillStyle = '#ffaa28';
      ctx.beginPath(); ctx.arc(a.x, a.y, 4, 0, Math.PI * 2); ctx.fill();
      const mx = a.x + (b.x - a.x) * 0.5, my = a.y + (b.y - a.y) * 0.5;
      const ang = Math.atan2(b.y - a.y, b.x - a.x);
      ctx.beginPath();
      ctx.moveTo(mx + Math.cos(ang) * 6, my + Math.sin(ang) * 6);
      ctx.lineTo(mx + Math.cos(ang + 2.5) * 6, my + Math.sin(ang + 2.5) * 6);
      ctx.lineTo(mx + Math.cos(ang - 2.5) * 6, my + Math.sin(ang - 2.5) * 6);
      ctx.closePath(); ctx.fill();
      drawNormal(face, '#5ff');
    }

    // vertices
    const selSet = new Map(sel.map((v, i) => [v, i]));
    ctx.font = '10px monospace';
    proj.forEach((p, i) => {
      const s = selSet.get(i);
      const bad = badVerts.has(i);
      const r = s !== undefined || hover === i ? 4 : 2.5;
      ctx.fillStyle = bad ? '#ff4d4d' : s !== undefined ? '#ffaa28' : hover === i ? '#fff' : '#8ab4ff';
      ctx.fillRect(p.x - r, p.y - r, r * 2, r * 2);
      if (s !== undefined && sel.length > 1) { ctx.fillStyle = '#ffcc80'; ctx.fillText(String(s + 1), p.x + 6, p.y - 6); }
    });
    // line and occluder points
    const scenePts = (kind: M.ScenePointRef['kind'], list: Proj[][], col: string) => list.forEach((pts, item) => pts.forEach((q, point) => {
      const key = `${kind}:${item}:${point}`;
      const on = sselKeys.has(key);
      const hov = hoverS !== null && refKey(hoverS) === key;
      const r = on || hov ? 3.5 : 2;
      ctx.fillStyle = on ? '#ffaa28' : hov ? '#fff' : col;
      ctx.beginPath(); ctx.arc(q.x, q.y, r, 0, Math.PI * 2); ctx.fill();
    }));
    scenePts('line', lineProj, '#9fd8ff');
    if (showOccluders) scenePts('occ', occProj, '#c98a4a');

    // the line being drawn
    if (linePts.length) {
      const pts = linePts.map((q) => toScreen(q[0], q[1], q[2]));
      ctx.strokeStyle = '#d8f4ff'; ctx.lineWidth = 1.5; ctx.setLineDash([5, 3]);
      ctx.beginPath();
      pts.forEach((q, i) => (i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y)));
      if (mousePx) ctx.lineTo(mousePx.x, mousePx.y);
      if (newLineClosed && pts.length > 1) ctx.lineTo(pts[0].x, pts[0].y);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#d8f4ff';
      for (const q of pts) { ctx.beginPath(); ctx.arc(q.x, q.y, 3, 0, Math.PI * 2); ctx.fill(); }
    }
    if (occRect) {
      ctx.strokeStyle = '#ffaa28'; ctx.fillStyle = 'rgba(255,150,50,0.10)'; ctx.setLineDash([4, 3]); ctx.lineWidth = 1;
      const x = Math.min(occRect.x0, occRect.x), y = Math.min(occRect.y0, occRect.y), w = Math.abs(occRect.x - occRect.x0), hh = Math.abs(occRect.y - occRect.y0);
      ctx.fillRect(x, y, w, hh); ctx.strokeRect(x, y, w, hh);
      ctx.setLineDash([]);
    }

    if (showIndices && proj.length <= 400) {
      ctx.fillStyle = '#8a8fa8';
      proj.forEach((p, i) => ctx.fillText(String(i), p.x + 5, p.y + 11));
      ctx.fillStyle = '#6a7a5a';
      shown.faces.forEach((f, fi) => {
        if (f.some((i) => !proj[i]) || !f.length) return;
        const x = f.reduce((a, i) => a + proj[i].x, 0) / f.length, y = f.reduce((a, i) => a + proj[i].y, 0) / f.length;
        ctx.fillText(`f${fi}`, x - 6, y + 3);
      });
    }

    if (box) {
      ctx.strokeStyle = '#ffaa28'; ctx.setLineDash([4, 3]); ctx.lineWidth = 1;
      ctx.strokeRect(Math.min(box.x0, box.x), Math.min(box.y0, box.y), Math.abs(box.x - box.x0), Math.abs(box.y - box.y0));
      ctx.setLineDash([]);
    }

    // orientation gizmo
    const gx = 34, gy = size.h - 34;
    for (const [d, col, name] of [[[1, 0, 0], '#e66', 'X'], [[0, 1, 0], '#6d6', 'Y'], [[0, 0, 1], '#69f', 'Z']] as const) {
      const q = projectView(d[0], d[1], d[2], viewMode, rot);
      if (Math.hypot(q.x, q.y) < 0.05) continue;
      ctx.strokeStyle = col; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(gx, gy); ctx.lineTo(gx + q.x * 22, gy - q.y * 22); ctx.stroke();
      ctx.fillStyle = col; ctx.fillText(name, gx + q.x * 28 - 3, gy - q.y * 28 + 3);
    }
  }, [size, scale, viewMode, rot, axes, frameC, frameR, toScreen, toModel, proj, geo, shown, display, solid, bgGrey, edgeSel, showHidden, showIndices, showNormals, isOpen, face, sel, hover, box, badVerts, badFaces,
    lineProj, occProj, shownScene, ssel, hoverS, showOccluders, linePts, mousePx, newLineClosed, occRect, badLines, badOccs]);

  // ── side panel helpers ──
  const commitField = (key: string, value: unknown) => {
    if (!raw) return;
    const next = { ...raw };
    if (value === undefined) delete next[key]; else next[key] = value;
    commit(next);
  };
  const numInput = (value: number, onCommit: (n: number) => void, opts: { disabled?: boolean; width?: number; min?: number; max?: number; step?: number } = {}) => (
    <input
      type="number"
      key={`${value}`}
      defaultValue={Number.isFinite(value) ? Math.round(value * 1000) / 1000 : 0}
      disabled={opts.disabled}
      step={opts.step ?? 1}
      min={opts.min}
      max={opts.max}
      style={{ ...S.input, width: opts.width ?? 70 }}
      onWheel={(e) => e.currentTarget.blur()}
      onBlur={(e) => {
        const n = Number(e.currentTarget.value);
        if (e.currentTarget.value.trim() === '' || !Number.isFinite(n)) { e.currentTarget.value = String(value); return; }
        if (n !== value) onCommit(n);
      }}
      onKeyDown={(e) => {
        if (e.key === 'Enter') (e.currentTarget as HTMLInputElement).blur();
        if (e.key === 'Escape') { (e.currentTarget as HTMLInputElement).value = String(value); (e.currentTarget as HTMLInputElement).blur(); }
      }}
    />
  );

  const selPts = selPoints();
  const selCentroid = selPts.length ? M.centroidOf(selPts) : null;
  const canMoveSel = (editable && sel.length > 0) || ssel.length > 0;
  const setSelAxis = (axis: 0 | 1 | 2, value: number) => {
    if (!canMoveSel || !selCentroid) return;
    const key = (['x', 'y', 'z'] as const)[axis];
    const p: Partial<Pick<M.MeshVertex, 'x' | 'y' | 'z'>> = {};
    p[key] = value;
    if (sel.length === 1 && !ssel.length) { applyMesh(M.setVertex(mesh, sel[0], p)); return; }
    if (ssel.length === 1 && !sel.length) { applyScene(M.setScenePoint(scenery, ssel[0], p)); return; }
    const d = { x: 0, y: 0, z: 0 };
    d[key] = Math.round(value - selCentroid[axis]);
    applyBoth(editable && sel.length ? M.moveVertices(mesh, sel, d) : null, ssel.length ? M.moveScenePoints(scenery, ssel, d) : null);
  };
  const selItem = wholeItem(scenery, ssel);
  /** The line whose points are all or partly selected, when they are in one line. */
  const selLine = ssel.length && ssel.every((r) => r.kind === 'line' && r.item === ssel[0].item) ? ssel[0].item : null;
  const coordRange = ssel.length && !sel.length ? [M.SCENE_MIN, M.SCENE_MAX] : [M.I16_MIN, M.I16_MAX];
  const nLinePts = shownScene.lines.reduce((a, l) => a + l.points.length, 0);
  const selTitle = (): string => {
    if (selItem && !sel.length) {
      return selItem.kind === 'line' ? tr('lineN', 'Line {{i}}', { i: selItem.item }) : tr('occluderN', 'Occluder {{i}}', { i: selItem.item });
    }
    const n = sel.length + ssel.length;
    if (n > 1) return sel.length && !ssel.length ? tr('selectionN', '{{n}} vertices (centre)', { n }) : tr('pointsN', '{{n}} points (centre)', { n });
    if (sel.length === 1) return tr('vertexN', 'Vertex {{i}}', { i: sel[0] });
    if (ssel.length === 1) {
      const r = ssel[0];
      return r.kind === 'line'
        ? tr('linePointN', 'Line {{i}}, point {{p}}', { i: r.item, p: r.point })
        : tr('occPointN', 'Occluder {{i}}, corner {{p}}', { i: r.item, p: r.point });
    }
    return tr('selection', 'Selection');
  };

  const h = histRef.current;
  const canUndo = h.index > 0, canRedo = h.index < h.stack.length - 1;
  const nEdges = geo.edges.length, nCrease = geo.edges.filter((e) => e.hard).length;
  const idxTotal = shown.faces.reduce((a, f) => a + f.length, 0);
  const sections = raw && Array.isArray(raw.sections) ? raw.sections.length : 0;

  const viewButtons: [ViewMode, string, string][] = [
    ['xy', tr('viewFront', 'Front'), tr('viewFrontTip', 'Front view (X-Y), key 1')],
    ['xz', tr('viewTop', 'Top'), tr('viewTopTip', 'Top view (X-Z), key 2')],
    ['yz', tr('viewSide', 'Side'), tr('viewSideTip', 'Side view (Y-Z), key 3')],
    ['3d', '3D', tr('view3dTip', '3D view, key 4. Orbit: middle button + Shift (or Alt + drag)')],
  ];

  return (
    <div ref={containerRef} tabIndex={0} onKeyDown={onKeyDown} style={S.root}>
      {/* toolbar */}
      <div style={S.toolbar}>
        {viewButtons.map(([m, label, tip]) => (
          <button key={m} title={tip} onClick={() => setViewMode(m)} style={viewMode === m ? S.btnOn : S.btn}>{label}</button>
        ))}
        <span style={S.sep} />
        <button title={tr('toolSelectTip', 'Select and move vertices (S). Click an edge to pick it (Shift adds more; Delete then merges the faces either side), inside a face to select the face; drag on empty space for a box.')} onClick={() => setTool('select')} style={tool === 'select' ? S.btnOn : S.btn}>{tr('toolSelect', 'Select')}</button>
        <button title={tr('toolAddTip', 'Add vertices (A): click on the view plane; new vertices join the selection in order, ready for Make face')} onClick={() => setTool('add')} style={tool === 'add' ? S.btnOn : S.btn} disabled={!editable && !!raw}>{tr('toolAdd', 'Add vertex')}</button>
        <button title={tr('toolLineTip', 'Draw a line (L): click points on the view plane (or onto a vertex / point), Enter or double-click ends it, Esc cancels')} onClick={() => setTool('line')} style={tool === 'line' ? S.btnOn : S.btn}>{tr('toolLine', 'Line')}</button>
        <button title={tr('toolOccTip', 'Drag a box occluder on the front, top or side view (O)')} onClick={() => setTool('occluder')} style={tool === 'occluder' ? S.btnOn : S.btn}>{tr('toolOcc', 'Occluder')}</button>
        <span style={S.sep} />
        <button title={tr('displayTip', 'Wireframe shows every edge (smooth edges dashed); vpy3d shows only what vpy3d_draw_mesh draws from this angle (W)')} onClick={() => setDisplay((d) => (d === 'wire' ? 'vpy3d' : 'wire'))} style={display === 'vpy3d' ? S.btnOn : S.btn}>
          {display === 'vpy3d' ? tr('displayVpy3d', 'vpy3d view') : tr('displayWire', 'Wireframe')}
        </button>
        <button title={tr('solidTip', 'Fill the faces, far ones first, in their own colour when the file has face_colors (D)')} onClick={() => setSolid((v) => !v)} style={solid ? S.btnOn : S.btn}>{tr('solid', 'Solid')}</button>
        <label style={S.check} title={tr('bgTip', 'Background grey, black to white (every 3D view)')}>{tr('background', 'Background')}<input type="range" min={0} max={255} value={bgGrey} onChange={(e) => setBgGrey(Number(e.target.value))} style={{ width: 80 }} /></label>
        {display === 'vpy3d' && (
          <label style={S.check}><input type="checkbox" checked={showHidden} onChange={(e) => setShowHidden(e.target.checked)} />{tr('hidden', 'hidden')}</label>
        )}
        <label style={S.check}><input type="checkbox" checked={showIndices} onChange={(e) => setShowIndices(e.target.checked)} />{tr('indices', 'indices')}</label>
        <label style={S.check}><input type="checkbox" checked={showNormals} onChange={(e) => setShowNormals(e.target.checked)} />{tr('normals', 'normals')}</label>
        <label style={S.check} title={tr('showOccTip', 'Show the occluders (never drawn by the game) as a faint orange hull')}><input type="checkbox" checked={showOccluders} onChange={(e) => setShowOccluders(e.target.checked)} />{tr('showOcc', 'occluders')}</label>
        <span style={S.sep} />
        <label style={S.check} title={tr('snapTip', 'Snap moved and added vertices to the grid in the front/top/side views')}>
          <input type="checkbox" checked={snap} onChange={(e) => setSnap(e.target.checked)} />{tr('snap', 'snap')}
        </label>
        <input type="number" value={snapStep} min={1} max={10000} style={{ ...S.input, width: 56 }} onChange={(e) => setSnapStep(Math.max(1, Math.min(10000, Number(e.target.value) || 1)))} />
        <span style={S.sep} />
        <button title={tr('frameTip', 'Frame the whole mesh (Home / H)')} onClick={() => frameAll()} style={S.btn}>{tr('frame', 'Frame')}</button>
        <button title={tr('undoTip', 'Undo (Ctrl+Z)')} onClick={undo} disabled={!canUndo} style={S.btn}>↶</button>
        <button title={tr('redoTip', 'Redo (Ctrl+Shift+Z / Ctrl+Y)')} onClick={redo} disabled={!canRedo} style={S.btn}>↷</button>
      </div>

      <div style={S.body}>
        {/* viewport */}
        <div ref={wrapRef} style={S.viewport}>
          <canvas
            ref={canvasRef}
            style={{ width: size.w, height: size.h, display: 'block', cursor: tool !== 'select' ? 'crosshair' : hover !== null || hoverS !== null ? 'pointer' : 'default' }}
            onMouseDown={onMouseDown}
            onMouseMove={onCanvasMove}
            onMouseLeave={() => { setHover(null); setHoverS(null); setMousePx(null); setCursorModel(null); setCursor(null); }}
            onContextMenu={(e) => e.preventDefault()}
          />
          {!raw && (
            <div style={S.overlay}>{tr('notJson', 'This document is not a .vmesh JSON object. Add a primitive to start a new mesh (it replaces the text).')}</div>
          )}
          {lofted && (
            <div style={S.banner}>
              {tr('loftedBanner', 'Lofted from {{n}} sections: a read-only preview.', { n: sections })}{' '}
              <button style={S.btn} disabled={!loft?.mesh} onClick={doConvertLoft} title={tr('convertTip', 'Replace the sections with the vertices and faces they loft into, so they can be edited')}>
                {tr('convert', 'Convert to vertices + faces')}
              </button>
              {loft?.pending && <span style={{ color: '#c9a' }}> {tr('loadingVec', 'loading .vec sections…')}</span>}
            </div>
          )}
          <div style={S.status}>
            <span>{viewMode === '3d' ? `3D  ${Math.round(rot.pitch)}° / ${Math.round(rot.yaw)}°` : viewButtons.find((b) => b[0] === viewMode)?.[1]}</span>
            <span>{tr('zoom', 'zoom')} {zoom.toFixed(2)}×</span>
            {cursor && cursorModel && <span>x {cursorModel[0]}  y {cursorModel[1]}  z {cursorModel[2]}</span>}
            {message && <span style={{ color: message.error ? '#ff8080' : '#9fd89f' }}>{message.text}</span>}
          </div>
        </div>

        {/* side panel */}
        <div style={S.panel}>
          <Section title={tr('mesh', 'Mesh')}>
            <Row label={tr('name', 'Name')}>
              <input
                key={String(raw?.name ?? '')}
                defaultValue={typeof raw?.name === 'string' ? raw.name : ''}
                disabled={!raw}
                style={{ ...S.input, width: 150 }}
                onBlur={(e) => { if (raw && e.currentTarget.value !== (raw.name ?? '')) commitField('name', e.currentTarget.value); }}
                onKeyDown={(e) => { if (e.key === 'Enter') e.currentTarget.blur(); }}
              />
            </Row>
            <Row label={tr('hard', 'Crease °')} tip={tr('hardTip', 'Two faces meeting more sharply than this keep their shared edge as a line (vpy3d "hard"). 45 is the default; 0 = every edge is a line.')}>
              {numInput(typeof raw?.hard === 'number' ? raw.hard : 45, (n) => commitField('hard', Math.max(0, Math.min(180, n))), { disabled: !raw, min: 0, max: 180 })}
              <span style={S.dim}>Q14 {hardCos}</span>
            </Row>
            {raw && raw.hard_cos !== undefined && (
              <div style={S.note}>
                {tr('hardCosNote', '"hard_cos" is set and overrides the angle.')}{' '}
                <button style={S.btnSmall} onClick={() => commitField('hard_cos', undefined)}>{tr('useAngle', 'Use the angle')}</button>
              </div>
            )}
            <Row label={tr('open', 'Plate (open)')} tip={tr('openTip', 'A plate rather than a solid: its rim is drawn from either side')}>
              <input type="checkbox" checked={isOpen} disabled={!raw} onChange={(e) => commitField('open', e.target.checked ? true : undefined)} />
            </Row>
            {lofted && (
              <Row label={tr('caps', 'End caps')} tip={tr('capsTip', 'Close the two ends of the loft')}>
                <input type="checkbox" checked={raw?.caps !== false} onChange={(e) => commitField('caps', e.target.checked)} />
              </Row>
            )}
            <div style={S.stats}>
              <Stat label={tr('vertices', 'vertices')} value={shown.vertices.length} max={M.VPY3D_MESH_MAXV} />
              <Stat label={tr('faces', 'faces')} value={shown.faces.length} max={M.VPY3D_MESH_MAXF} />
              <Stat label={tr('edges', 'edges')} value={nEdges} extra={`${nCrease} ${tr('creases', 'creases')}`} />
              <Stat label={tr('indexEntries', 'face indices')} value={idxTotal} />
              <Stat label={tr('lines', 'lines')} value={shownScene.lines.length} />
              <Stat label={tr('linePoints', 'line points')} value={nLinePts} />
              <Stat label={tr('occluders', 'occluders')} value={shownScene.occluders.length} />
            </div>
          </Section>

          <Section title={selTitle()}>
            {selCentroid ? (
              <Row label="X Y Z">
                {numInput(selCentroid[0], (n) => setSelAxis(0, n), { disabled: !canMoveSel, width: 62, min: coordRange[0], max: coordRange[1] })}
                {numInput(selCentroid[1], (n) => setSelAxis(1, n), { disabled: !canMoveSel, width: 62, min: coordRange[0], max: coordRange[1] })}
                {numInput(selCentroid[2], (n) => setSelAxis(2, n), { disabled: !canMoveSel, width: 62, min: coordRange[0], max: coordRange[1] })}
              </Row>
            ) : face !== null && shown.faces[face] ? (
              <div style={S.dim}>
                {tr('faceN', 'Face {{i}}', { i: face })}: [{shown.faces[face].join(', ')}]
              </div>
            ) : (
              <div style={S.dim}>{tr('selectHint', 'Click a vertex, an edge or a face. Shift adds; drag a box on empty space.')}</div>
            )}
            {selLine !== null && shownScene.lines[selLine] && (
              <>
                <Row label={tr('lineBr', 'Brightness %')} tip={tr('lineBrTip', 'Percent of the brightness the mesh is drawn with (1-100, "br"; 100 is the default)')}>
                  {numInput(M.lineBr(shownScene.lines[selLine]), (n) => setLineBr(selLine, Math.max(1, Math.min(100, n))), { min: 1, max: 100, width: 56 })}
                </Row>
                <Row label={tr('lineClosed', 'Closed')} tip={tr('lineClosedTip', 'Join the last point back to the first ("closed")')}>
                  <input type="checkbox" checked={M.lineClosed(shownScene.lines[selLine])} onChange={(e) => setLineClosedProp(selLine, e.target.checked)} />
                  <span style={S.dim}>{tr('nPoints', '{{n}} points', { n: shownScene.lines[selLine].points.length })}</span>
                </Row>
                <Row label={tr('lineFog', 'Fog')} tip={tr('lineFogTip', 'Off: the line ignores the scenery fog (vpy3d_set_scenery_fog), "fog": false')}>
                  <input type="checkbox" checked={M.lineFog(shownScene.lines[selLine])} onChange={(e) => setLineFogProp(selLine, e.target.checked)} />
                </Row>
              </>
            )}
            {selItem?.kind === 'occ' && shownScene.occluders[selItem.item] && (
              <div style={S.dim}>{tr('nCorners', '{{n}} corners', { n: shownScene.occluders[selItem.item].points.length })}</div>
            )}
            <div style={S.btnGrid}>
              <button style={S.btn} onClick={doMakeFace} disabled={!editable || sel.length < 3} title={tr('makeFaceTip', 'Make a face from the selected vertices, in the order you selected them (F)')}>{tr('makeFace', 'Make face')}</button>
              <button style={S.btn} onClick={doConnect} disabled={!editable || sel.length !== 2} title={tr('connectTip', 'Connect two corners of the same face: splits the face along a new edge (J)')}>{tr('connect', 'Connect')}</button>
              <button style={S.btn} onClick={doDisconnect} disabled={!editable || sel.length !== 2} title={tr('disconnectTip', 'Remove the edge between two vertices by merging the two faces either side (K)')}>{tr('disconnect', 'Disconnect')}</button>
              <button style={S.btn} onClick={doFlip} disabled={!editable || face === null} title={tr('flipTip', 'Reverse the winding of the selected face (N)')}>{tr('flip', 'Flip face')}</button>
              <button style={S.btn} onClick={doDelete} disabled={!ssel.length && (!editable || (!sel.length && face === null))} title={tr('deleteTip', 'Delete the selected vertices (and their faces), line/occluder points, or the selected face (Del)')}>{tr('delete', 'Delete')}</button>
              <button style={S.btn} onClick={doWindOutward} disabled={!editable || !shown.faces.length} title={tr('windTip', 'Re-wind every face anticlockwise seen from outside (normal away from the centre)')}>{tr('wind', 'Wind outward')}</button>
              <button style={S.btn} onClick={doRemoveUnused} disabled={!editable} title={tr('unusedTip', 'Delete vertices that no face uses')}>{tr('unused', 'Remove unused')}</button>
            </div>
          </Section>

          <Section title={tr('primitives', 'Primitives')}>
            <Row label={tr('shape', 'Shape')}>
              <select value={primKind} onChange={(e) => setPrimKind(e.target.value as M.PrimitiveKind)} style={S.input}>
                <option value="cube">{tr('cube', 'Cube')}</option>
                <option value="pyramid">{tr('pyramid', 'Pyramid')}</option>
                <option value="grid">{tr('grid', 'Plane / grid')}</option>
                <option value="cylinder">{tr('cylinder', 'Cylinder')}</option>
              </select>
            </Row>
            <Row label={tr('size', 'Size')}>
              <input type="number" value={primSize} min={2} max={60000} step={50} style={{ ...S.input, width: 70 }} onChange={(e) => setPrimSize(Number(e.target.value) || 1000)} />
            </Row>
            {(primKind === 'grid' || primKind === 'cylinder') && (
              <Row label={primKind === 'grid' ? tr('cells', 'Cells') : tr('sides', 'Sides')}>
                <input type="number" value={primSeg} min={primKind === 'grid' ? 1 : 3} max={primKind === 'grid' ? 15 : 32} style={{ ...S.input, width: 56 }} onChange={(e) => setPrimSeg(Number(e.target.value) || 1)} />
              </Row>
            )}
            <div style={S.btnGrid}>
              <button style={S.btn} onClick={() => addPrimitive(false)} disabled={lofted} title={tr('addPrimTip', 'Add the primitive at the origin, next to what is there')}>{tr('addPrim', 'Add')}</button>
              <button style={S.btn} onClick={() => addPrimitive(true)} disabled={lofted} title={tr('replacePrimTip', 'Replace the whole mesh with the primitive')}>{tr('replacePrim', 'Replace')}</button>
            </div>
          </Section>

          <Section title={tr('scenery', 'Scenery: lines and occluders')}>
            <div style={S.note}>{tr('sceneryNote', 'Lines are drawn as they are, cut by the occluders the game added before this mesh. Occluders are never drawn: added after the mesh, they hide what is drawn later behind them.')}</div>
            <Row label={tr('newLineClosed', 'New line closed')} tip={tr('newLineClosedTip', 'Lines drawn with the Line tool join their last point to the first')}>
              <input type="checkbox" checked={newLineClosed} onChange={(e) => setNewLineClosed(e.target.checked)} />
            </Row>
            <Row label={tr('occDepth', 'Occluder depth')} tip={tr('occDepthTip', 'Thickness along the view direction of an occluder dragged with the Occluder tool; 0 = a flat wall on the view plane')}>
              {numInput(occDepth, (n) => setOccDepth(Math.max(0, Math.min(M.SCENE_MAX, Math.round(n)))), { min: 0, width: 70 })}
            </Row>
            <div style={S.btnGrid}>
              <button style={tool === 'line' ? S.btnOn : S.btn} onClick={() => setTool(tool === 'line' ? 'select' : 'line')} title={tr('toolLineTip', 'Draw a line (L): click points on the view plane (or onto a vertex / point), Enter or double-click ends it, Esc cancels')}>{tr('toolLine', 'Line')}</button>
              <button style={S.btn} onClick={finishLine} disabled={linePts.length < 2} title={tr('finishLineTip', 'End the line being drawn (Enter)')}>{tr('finishLine', 'End line')}</button>
              <button style={tool === 'occluder' ? S.btnOn : S.btn} onClick={() => setTool(tool === 'occluder' ? 'select' : 'occluder')} title={tr('toolOccTip', 'Drag a box occluder on the front, top or side view (O)')}>{tr('toolOcc', 'Occluder')}</button>
              <button style={S.btn} onClick={doBoxOccluder} disabled={!sel.length && !ssel.length} title={tr('boxOccTip', 'An occluder that is the bounding box of the selected vertices and points (B)')}>{tr('boxOcc', 'Box occluder from selection')}</button>
            </div>
            <div style={S.list}>
              {shownScene.lines.slice(0, 512).map((l, li) => (
                <div key={`l${li}`} onClick={() => selectItem('line', li)} style={{ ...S.listItem, background: selItem?.kind === 'line' && selItem.item === li ? '#3a2e18' : undefined, color: badLines.has(li) ? '#ff8080' : '#9fd8ff' }}>
                  l{li}: {tr('nPoints', '{{n}} points', { n: l.points.length })}{M.lineClosed(l) ? `, ${tr('closedShort', 'closed')}` : ''}, br {M.lineBr(l)}%{M.lineFog(l) ? '' : `, ${tr('noFogShort', 'no fog')}`}
                </div>
              ))}
              {shownScene.occluders.slice(0, 512).map((o, oi) => (
                <div key={`o${oi}`} onClick={() => { setShowOccluders(true); selectItem('occ', oi); }} style={{ ...S.listItem, background: selItem?.kind === 'occ' && selItem.item === oi ? '#3a2e18' : undefined, color: badOccs.has(oi) ? '#ff8080' : '#d9a066' }}>
                  o{oi}: {tr('nCorners', '{{n}} corners', { n: o.points.length })}
                </div>
              ))}
            </div>
          </Section>

          <Section title={`${tr('faceList', 'Faces')} (${shown.faces.length})`}>
            <div style={S.list}>
              {shown.faces.slice(0, 512).map((f, fi) => (
                <div key={fi} onClick={() => { setFace(fi); setSel([]); }} style={{ ...S.listItem, background: fi === face ? '#3a2e18' : undefined, color: badFaces.has(fi) ? '#ff8080' : geo.flipped[fi] ? '#e6c07a' : '#bbb' }}
                  title={geo.flipped[fi] ? tr('flippedTip', 'Wound inward: vpy3d flips its normal at load, but it is better wound outward') : undefined}>
                  f{fi}: [{f.join(', ')}]
                </div>
              ))}
            </div>
          </Section>

          <Section title={errorCount ? tr('issuesErr', 'Problems: {{n}} error(s)', { n: errorCount }) : issues.length ? tr('issuesWarn', 'Warnings') : tr('issuesOk', 'Checks')}>
            {!raw ? null : issues.length === 0 ? (
              <div style={{ color: '#9fd89f' }}>{tr('valid', 'Compiles, and vpy3d can load it.')}</div>
            ) : (
              <div style={S.list}>
                {issues.slice(0, 200).map((is, k) => (
                  <div key={k} style={{ ...S.listItem, color: is.level === 'error' ? '#ff8080' : '#e6c07a', cursor: is.vertex !== undefined || is.face !== undefined || is.line !== undefined || is.occluder !== undefined ? 'pointer' : 'default' }}
                    onClick={() => {
                      if (is.vertex !== undefined) { setSel([is.vertex]); setSsel([]); setFace(null); }
                      else if (is.face !== undefined) { setFace(is.face); setSel([]); setSsel([]); }
                      else if (is.line !== undefined) selectItem('line', is.line);
                      else if (is.occluder !== undefined) { setShowOccluders(true); selectItem('occ', is.occluder); }
                    }}>
                    {is.level === 'error' ? '✖' : '⚠'} {is.message}
                  </div>
                ))}
              </div>
            )}
            {errorCount > 0 && <div style={S.note}>{tr('errorsNote', 'Errors: vpy_cli refuses the file (the build fails). Warnings: it builds, but vpy3d may refuse or misdraw it.')}</div>}
          </Section>

          <div style={S.help}>
            {tr('help', 'Middle drag: pan · Shift+middle or Alt+drag: orbit · wheel: zoom · 1-4: views · F face · J connect · K disconnect · N flip · L line (Enter ends, Esc cancels) · O occluder · B box occluder · Del delete (picked edges: merge their faces) · arrows nudge (Shift ×10) · Ctrl+Z / Ctrl+Y')}
          </div>
        </div>
      </div>
    </div>
  );
};

// ── small presentational pieces ─────────────────────────────────────────────

const Section: React.FC<{ title: string; children?: React.ReactNode }> = ({ title, children }) => (
  <div style={S.section}>
    <div style={S.sectionTitle}>{title}</div>
    {children}
  </div>
);
const Row: React.FC<{ label: string; tip?: string; children?: React.ReactNode }> = ({ label, tip, children }) => (
  <div style={S.row} title={tip}>
    <span style={S.label}>{label}</span>
    <span style={{ display: 'flex', gap: 4, alignItems: 'center' }}>{children}</span>
  </div>
);
const Stat: React.FC<{ label: string; value: number; max?: number; extra?: string }> = ({ label, value, max, extra }) => (
  <div style={{ color: max !== undefined && value > max ? '#e6c07a' : '#aab' }}>
    <b style={{ color: '#dde' }}>{value}</b>{max !== undefined ? ` / ${max}` : ''} {label}{extra ? ` (${extra})` : ''}
  </div>
);

const btnBase: React.CSSProperties = {
  background: '#2c2c44', color: '#ccd', border: '1px solid #3d3d5c', borderRadius: 3,
  padding: '3px 8px', fontSize: 12, cursor: 'pointer',
};
const S: Record<string, React.CSSProperties> = {
  root: { display: 'flex', flexDirection: 'column', height: '100%', width: '100%', background: '#12121c', color: '#ccd', fontSize: 12, outline: 'none' },
  toolbar: { display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 4, padding: '4px 6px', borderBottom: '1px solid #2a2a3e', background: '#181826' },
  sep: { width: 1, height: 18, background: '#33334d', margin: '0 4px' },
  btn: btnBase,
  btnOn: { ...btnBase, background: '#4a4a8e', color: '#fff', border: '1px solid #7a7abf' },
  btnSmall: { ...btnBase, padding: '1px 6px', fontSize: 11 },
  check: { display: 'flex', alignItems: 'center', gap: 3, color: '#aab', cursor: 'pointer' },
  body: { flex: 1, display: 'flex', minHeight: 0 },
  viewport: { flex: 1, position: 'relative', minWidth: 0, overflow: 'hidden' },
  overlay: { position: 'absolute', top: 40, left: 20, right: 20, color: '#e6c07a', textAlign: 'center', pointerEvents: 'none' },
  banner: { position: 'absolute', top: 6, left: 6, right: 6, background: 'rgba(40,30,60,0.92)', border: '1px solid #5a4a7a', borderRadius: 4, padding: '4px 8px', color: '#d8c8f0' },
  status: { position: 'absolute', bottom: 0, left: 0, right: 0, display: 'flex', gap: 14, padding: '2px 8px 2px 72px', background: 'rgba(16,16,26,0.85)', color: '#889', fontFamily: 'monospace', fontSize: 11, pointerEvents: 'none' },
  panel: { width: 270, flexShrink: 0, overflowY: 'auto', borderLeft: '1px solid #2a2a3e', background: '#151522', padding: 6 },
  section: { marginBottom: 10, paddingBottom: 6, borderBottom: '1px solid #24243a' },
  sectionTitle: { fontWeight: 600, color: '#dde', marginBottom: 4 },
  row: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 6, margin: '3px 0' },
  label: { color: '#99a' },
  input: { background: '#0f0f18', color: '#dde', border: '1px solid #3d3d5c', borderRadius: 3, padding: '2px 4px', fontSize: 12 },
  dim: { color: '#889' },
  note: { color: '#b9a', fontSize: 11, margin: '4px 0' },
  stats: { marginTop: 6, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, fontSize: 11 },
  btnGrid: { display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 6 },
  list: { maxHeight: 160, overflowY: 'auto', fontFamily: 'monospace', fontSize: 11 },
  listItem: { padding: '1px 3px', cursor: 'pointer', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' },
  help: { color: '#667', fontSize: 10.5, lineHeight: 1.4 },
};

export default MeshEditor;
