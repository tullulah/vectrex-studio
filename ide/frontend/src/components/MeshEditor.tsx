/**
 * MeshEditor — editor for `.vmesh`, the 3D surface meshes of the SDK's vpy3d C
 * library (docs/ASSETS.md). The model (parsing, validation, geometry, edit
 * operations) lives in ./mesh/vmeshModel.ts; the view math is shared with the
 * VectorEditor (utils/view3d.ts).
 *
 * - Views: front (XY), top (XZ), side (YZ) and an orbiting 3D view. Middle
 *   button pans, middle button + Shift (or Alt + left) orbits, the wheel zooms
 *   to the cursor — the VectorEditor's 3D controls.
 * - "vpy3d" display draws only what vpy3d_draw_mesh draws from this angle
 *   (creases, silhouettes, rims, same crease threshold), the rest faint.
 * - Vertices: select (click, Shift-click, box), drag, nudge, add, delete,
 *   numeric X/Y/Z. Faces: make from selected vertices in order, delete, flip,
 *   wind outward. The format has no edge list, so CONNECT splits a face along
 *   two of its corners and DISCONNECT merges the two faces across an edge.
 * - Lofted files (`sections`) are previewed, and can be converted to vertices
 *   + faces to edit them.
 * - Saves the same JSON: fields the editor does not know are kept.
 */

import React, { useCallback, useEffect, useMemo, useReducer, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import * as M from './mesh/vmeshModel';
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

type Tool = 'select' | 'add';
type Display = 'wire' | 'vpy3d';

type Drag =
  | { kind: 'pan'; x: number; y: number; panX: number; panY: number }
  | { kind: 'orbit'; x: number; y: number }
  | { kind: 'move'; x: number; y: number; base: M.MeshData; primary: number; moved: boolean }
  | { kind: 'box'; x0: number; y0: number; x: number; y: number; additive: boolean };

interface Proj { x: number; y: number; depth: number }

const EMPTY: M.MeshData = { vertices: [], faces: [] };
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
  const [face, setFace] = useState<number | null>(null);
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
  const issues = useMemo(() => (raw ? M.validateVmesh(raw, resolver) : []), [raw, resolver]);
  const errorCount = issues.filter((i) => i.level === 'error').length;
  const hardCos = raw ? M.hardCosQ14(raw) : 11585;
  const isOpen = raw?.open === true;
  const geo = useMemo(() => M.meshGeometry(shown, hardCos), [shown, hardCos]);
  const badVerts = useMemo(() => new Set(issues.filter((i) => i.level === 'error' && i.vertex !== undefined).map((i) => i.vertex!)), [issues]);
  const badFaces = useMemo(() => new Set(issues.filter((i) => i.vertex === undefined && i.face !== undefined).map((i) => i.face!)), [issues]);

  // Keep the selection inside the mesh after undo/delete/reload.
  useEffect(() => {
    const nv = mesh.vertices.length, nf = mesh.faces.length;
    setSel((s) => (s.some((i) => i >= nv) ? s.filter((i) => i < nv) : s));
    setFace((f) => (f !== null && f >= nf ? null : f));
  }, [mesh]);

  // ── view ──
  const [viewMode, setViewMode] = useState<ViewMode>('3d');
  const [rot, setRot] = useState<Rotation3D>(DEFAULT_ROTATION_3D);
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [frameC, setFrameC] = useState<[number, number, number]>([0, 0, 0]);
  const [frameR, setFrameR] = useState(1000);
  const [tool, setTool] = useState<Tool>('select');
  const [display, setDisplay] = useState<Display>('wire');
  const [showHidden, setShowHidden] = useState(true);
  const [showIndices, setShowIndices] = useState(false);
  const [showNormals, setShowNormals] = useState(false);
  const [snap, setSnap] = useState(true);
  const [snapStep, setSnapStep] = useState(50);
  const [box, setBox] = useState<{ x0: number; y0: number; x: number; y: number } | null>(null);
  const [hover, setHover] = useState<number | null>(null);
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

  const frameAll = useCallback((m: M.MeshData = mesh) => {
    if (!m.vertices.length) { setFrameC([0, 0, 0]); setFrameR(1000); }
    else {
      const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
      for (const v of m.vertices) {
        const p = [v.x, v.y, v.z];
        for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k], p[k]); hi[k] = Math.max(hi[k], p[k]); }
      }
      const c: [number, number, number] = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2];
      const r = Math.max(50, Math.hypot(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]) / 2);
      setFrameC(c);
      setFrameR(r);
    }
    setZoom(1);
    setPan({ x: 0, y: 0 });
  }, [mesh]);

  // Frame the mesh when a document is opened.
  const framedFor = useRef<string | null>(null);
  useEffect(() => {
    const key = docUri ?? '';
    if (framedFor.current === key || !raw) return;
    if (!mesh.vertices.length && lofted && loft?.pending) return; // wait for the .vec rings
    framedFor.current = key;
    frameAll(mesh);
  }, [docUri, raw, mesh, lofted, loft, frameAll]);

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
    if (!needEditable()) return;
    if (sel.length) {
      const n = sel.length;
      applyMesh(M.deleteVertices(mesh, sel));
      setSel([]); setFace(null);
      flash(tr('deletedVertices', 'Deleted {{n}} vertex(es) and their faces', { n }));
    } else if (face !== null) {
      applyMesh(M.deleteFaces(mesh, [face]));
      setFace(null);
    }
  }, [needEditable, sel, face, mesh, applyMesh, flash]);
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
    if (!editable || !sel.length) return;
    const step = snap && snapStep > 0 ? snapStep : 1;
    const { right, up } = axes;
    const d = { x: Math.round((dx * right[0] + dy * up[0]) * step), y: Math.round((dx * right[1] + dy * up[1]) * step), z: Math.round((dx * right[2] + dy * up[2]) * step) };
    applyMesh(M.moveVertices(mesh, sel, d));
  }, [editable, sel, snap, snapStep, axes, mesh, applyMesh]);

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
  const live = useRef({ hitVertex, hitEdge, hitFace, toModel, snapPoint, proj, sel, scale, axes, editable, viewMode });
  live.current = { hitVertex, hitEdge, hitFace, toModel, snapPoint, proj, sel, scale, axes, editable, viewMode };
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
      const m = dragMeshRef.current;
      dragMeshRef.current = null;
      setDragMesh(null);
      if (m && d.moved) applyMesh(m);
    } else if (d.kind === 'box') {
      setBox(null);
      const x0 = Math.min(d.x0, d.x), x1 = Math.max(d.x0, d.x), y0 = Math.min(d.y0, d.y), y1 = Math.max(d.y0, d.y);
      if (x1 - x0 < 3 && y1 - y0 < 3) return;
      const inside: number[] = [];
      live.current.proj.forEach((p, i) => { if (p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1) inside.push(i); });
      setSel((s) => (d.additive ? [...s, ...inside.filter((i) => !s.includes(i))] : inside));
    }
  }, [applyMesh]);

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
      const v0 = d.base.vertices[d.primary];
      const target = L.snapPoint([v0.x + a * right[0] + b * up[0], v0.y + a * right[1] + b * up[1], v0.z + a * right[2] + b * up[2]]);
      const delta = { x: target[0] - v0.x, y: target[1] - v0.y, z: target[2] - v0.z };
      const moved = M.moveVertices(d.base, L.sel, delta);
      dragMeshRef.current = moved;
      setDragMesh(moved);
    } else if (d.kind === 'box') {
      d.x = p.x; d.y = p.y;
      setBox({ x0: d.x0, y0: d.y0, x: p.x, y: p.y });
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
    if (e.button === 1 || (e.button === 0 && e.altKey)) {
      e.preventDefault();
      const orbit = e.shiftKey || e.altKey;
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
      setSel(nextSel);
      setFace(null);
      if (editable && nextSel.includes(v)) {
        live.current.sel = nextSel;
        startDrag({ kind: 'move', x: p.x, y: p.y, base: mesh, primary: v, moved: false });
      }
      return;
    }
    const ed = hitEdge(p.x, p.y);
    if (ed) {
      setSel((s) => (multi ? [...s, ...[ed.a, ed.b].filter((i) => !s.includes(i))] : [ed.a, ed.b]));
      setFace(null);
      return;
    }
    const f = hitFace(p.x, p.y);
    if (f !== null && !multi) {
      setFace(f);
      setSel([]);
      return;
    }
    if (!multi) { setSel([]); setFace(null); }
    startDrag({ kind: 'box', x0: p.x, y0: p.y, x: p.x, y: p.y, additive: multi });
  };

  const onCanvasMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (dragRef.current) return;
    const p = pos(e);
    setHover(hitVertex(p.x, p.y));
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
    if (mod && (k === 'a' || k === 'A')) { done(); setSel(mesh.vertices.map((_, i) => i)); setFace(null); return; }
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
      case 's': case 'S': done(); setTool('select'); return;
      case 'a': case 'A': done(); setTool('add'); return;
      case 'w': case 'W': done(); setDisplay((d) => (d === 'wire' ? 'vpy3d' : 'wire')); return;
      case 'Home': case 'h': case 'H': done(); frameAll(); return;
      case 'Escape': done(); setSel([]); setFace(null); return;
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
    ctx.fillStyle = '#0b0b12';
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
    if (display === 'vpy3d' && showHidden) stroke(hidden, '#24304a', 1, [3, 4]);
    stroke(soft, '#2b5a3a', 1, [4, 3]);
    stroke(lines, display === 'vpy3d' ? '#b8ffb8' : '#5fd35f', display === 'vpy3d' ? 1.6 : 1.3);

    // faces with errors
    ctx.strokeStyle = '#ff4d4d'; ctx.lineWidth = 2;
    for (const fi of badFaces) {
      const f = shown.faces[fi];
      if (!f || f.length < 2 || f.some((i) => !proj[i])) continue;
      ctx.beginPath();
      f.forEach((i, k) => (k ? ctx.lineTo(proj[i].x, proj[i].y) : ctx.moveTo(proj[i].x, proj[i].y)));
      ctx.closePath(); ctx.stroke();
    }

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
  }, [size, scale, viewMode, rot, axes, frameC, frameR, toScreen, toModel, proj, geo, shown, display, showHidden, showIndices, showNormals, isOpen, face, sel, hover, box, badVerts, badFaces]);

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

  const selCentroid = sel.length ? M.centroidOf(shown.vertices, sel.filter((i) => shown.vertices[i])) : null;
  const setSelAxis = (axis: 0 | 1 | 2, value: number) => {
    if (!editable || !selCentroid) return;
    const key = (['x', 'y', 'z'] as const)[axis];
    if (sel.length === 1) {
      const p: Partial<Pick<M.MeshVertex, 'x' | 'y' | 'z'>> = {};
      p[key] = value;
      applyMesh(M.setVertex(mesh, sel[0], p));
      return;
    }
    const d = { x: 0, y: 0, z: 0 };
    d[key] = Math.round(value - selCentroid[axis]);
    applyMesh(M.moveVertices(mesh, sel, d));
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
        <button title={tr('toolSelectTip', 'Select and move vertices (S). Click an edge to select its two vertices, inside a face to select the face; drag on empty space for a box.')} onClick={() => setTool('select')} style={tool === 'select' ? S.btnOn : S.btn}>{tr('toolSelect', 'Select')}</button>
        <button title={tr('toolAddTip', 'Add vertices (A): click on the view plane; new vertices join the selection in order, ready for Make face')} onClick={() => setTool('add')} style={tool === 'add' ? S.btnOn : S.btn} disabled={!editable && !!raw}>{tr('toolAdd', 'Add vertex')}</button>
        <span style={S.sep} />
        <button title={tr('displayTip', 'Wireframe shows every edge (smooth edges dashed); vpy3d shows only what vpy3d_draw_mesh draws from this angle (W)')} onClick={() => setDisplay((d) => (d === 'wire' ? 'vpy3d' : 'wire'))} style={display === 'vpy3d' ? S.btnOn : S.btn}>
          {display === 'vpy3d' ? tr('displayVpy3d', 'vpy3d view') : tr('displayWire', 'Wireframe')}
        </button>
        {display === 'vpy3d' && (
          <label style={S.check}><input type="checkbox" checked={showHidden} onChange={(e) => setShowHidden(e.target.checked)} />{tr('hidden', 'hidden')}</label>
        )}
        <label style={S.check}><input type="checkbox" checked={showIndices} onChange={(e) => setShowIndices(e.target.checked)} />{tr('indices', 'indices')}</label>
        <label style={S.check}><input type="checkbox" checked={showNormals} onChange={(e) => setShowNormals(e.target.checked)} />{tr('normals', 'normals')}</label>
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
            style={{ width: size.w, height: size.h, display: 'block', cursor: tool === 'add' ? 'crosshair' : hover !== null ? 'pointer' : 'default' }}
            onMouseDown={onMouseDown}
            onMouseMove={onCanvasMove}
            onMouseLeave={() => { setHover(null); setCursorModel(null); setCursor(null); }}
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
            </div>
          </Section>

          <Section title={sel.length > 1 ? tr('selectionN', '{{n}} vertices (centre)', { n: sel.length }) : sel.length === 1 ? tr('vertexN', 'Vertex {{i}}', { i: sel[0] }) : tr('selection', 'Selection')}>
            {selCentroid ? (
              <Row label="X Y Z">
                {numInput(selCentroid[0], (n) => setSelAxis(0, n), { disabled: !editable, width: 62, min: M.I16_MIN, max: M.I16_MAX })}
                {numInput(selCentroid[1], (n) => setSelAxis(1, n), { disabled: !editable, width: 62, min: M.I16_MIN, max: M.I16_MAX })}
                {numInput(selCentroid[2], (n) => setSelAxis(2, n), { disabled: !editable, width: 62, min: M.I16_MIN, max: M.I16_MAX })}
              </Row>
            ) : face !== null && shown.faces[face] ? (
              <div style={S.dim}>
                {tr('faceN', 'Face {{i}}', { i: face })}: [{shown.faces[face].join(', ')}]
              </div>
            ) : (
              <div style={S.dim}>{tr('selectHint', 'Click a vertex, an edge or a face. Shift adds; drag a box on empty space.')}</div>
            )}
            <div style={S.btnGrid}>
              <button style={S.btn} onClick={doMakeFace} disabled={!editable || sel.length < 3} title={tr('makeFaceTip', 'Make a face from the selected vertices, in the order you selected them (F)')}>{tr('makeFace', 'Make face')}</button>
              <button style={S.btn} onClick={doConnect} disabled={!editable || sel.length !== 2} title={tr('connectTip', 'Connect two corners of the same face: splits the face along a new edge (J)')}>{tr('connect', 'Connect')}</button>
              <button style={S.btn} onClick={doDisconnect} disabled={!editable || sel.length !== 2} title={tr('disconnectTip', 'Remove the edge between two vertices by merging the two faces either side (K)')}>{tr('disconnect', 'Disconnect')}</button>
              <button style={S.btn} onClick={doFlip} disabled={!editable || face === null} title={tr('flipTip', 'Reverse the winding of the selected face (N)')}>{tr('flip', 'Flip face')}</button>
              <button style={S.btn} onClick={doDelete} disabled={!editable || (!sel.length && face === null)} title={tr('deleteTip', 'Delete the selected vertices (and their faces) or the selected face (Del)')}>{tr('delete', 'Delete')}</button>
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
                  <div key={k} style={{ ...S.listItem, color: is.level === 'error' ? '#ff8080' : '#e6c07a', cursor: is.vertex !== undefined || is.face !== undefined ? 'pointer' : 'default' }}
                    onClick={() => {
                      if (is.vertex !== undefined) { setSel([is.vertex]); setFace(null); }
                      else if (is.face !== undefined) { setFace(is.face); setSel([]); }
                    }}>
                    {is.level === 'error' ? '✖' : '⚠'} {is.message}
                  </div>
                ))}
              </div>
            )}
            {errorCount > 0 && <div style={S.note}>{tr('errorsNote', 'Errors: vpy_cli refuses the file (the build fails). Warnings: it builds, but vpy3d may refuse or misdraw it.')}</div>}
          </Section>

          <div style={S.help}>
            {tr('help', 'Middle drag: pan · Shift+middle or Alt+drag: orbit · wheel: zoom · 1-4: views · F face · J connect · K disconnect · N flip · Del delete · arrows nudge (Shift ×10) · Ctrl+Z / Ctrl+Y')}
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
