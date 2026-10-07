/**
 * `.vmesh` model: parsing, validation, geometry and edit operations for the
 * Mesh Editor. Pure functions, no imports, so `tools/vmesh-model-test.ts` runs
 * it straight under node.
 *
 * The format (docs/ASSETS.md, buildtools/vpy_codegen/src/vmeshres.rs):
 *   explicit: {"name","hard":45,"open"?,"vertices":[{"x","y","z"?}],"faces":[[i,...]]}
 *   lofted:   {"name","hard":45,"caps"?:true,"sections":[{"z","points":[{"x","y","z"?}]}
 *                                                   | {"z","vec":"../vectors/x.vec","path"?}]}
 *   optional "hard_cos" (Q14) overrides "hard" (degrees).
 * The format has NO edge list: vpy3d derives the edges from the faces, so in the
 * editor "connect" splits a face and "disconnect" merges the two faces across an
 * edge.
 *
 * Validation has two levels:
 *   error   — the compiler (`vpy_cli check-asset` / `compile-asset`) refuses it.
 *             These mirror vmeshres.rs + serde exactly.
 *   warning — it compiles, but vpy3d (vpy3d.h defaults) will refuse it at load
 *             time, or it will draw wrong (open edges on a solid, inconsistent
 *             winding, degenerate faces, unused vertices).
 */

// ── limits ─────────────────────────────────────────────────────────────────

export const I16_MIN = -32768;
export const I16_MAX = 32767;
/** vpy3d.h defaults (a game can raise them with -D, so these are warnings). */
export const VPY3D_MESH_MAXV = 256;
export const VPY3D_MESH_MAXF = 256;
export const VPY3D_POOL_V = 512;
export const VPY3D_POOL_F = 512;
export const VPY3D_POOL_FV = 2048;
export const VPY3D_POOL_E = 1024;
export const Q14_ONE = 16384;

// ── types ──────────────────────────────────────────────────────────────────

/** A vertex; unknown per-vertex fields ride along untouched. */
export interface MeshVertex {
  x: number;
  y: number;
  z: number;
  [extra: string]: unknown;
}
export type MeshFace = number[];

/** The editable (explicit) form of a mesh. */
export interface MeshData {
  vertices: MeshVertex[];
  faces: MeshFace[];
}

export type VmeshRaw = Record<string, unknown>;

export interface Issue {
  level: 'error' | 'warning';
  message: string;
  vertex?: number;
  face?: number;
  section?: number;
}

/** A ring loaded from a `.vec`, for lofted sections: (x, y, z|undefined) points. */
export interface VecRing { points: { x: number; y: number; z?: number }[] }
/**
 * Resolves `{vec, path}` of a section. `undefined` = not loaded (yet / no file
 * API); `string` = why it could not be resolved (the compiler would fail too).
 */
export type VecResolver = (vec: string, path: string | undefined) => VecRing | string | undefined;

export interface Edge {
  a: number; // a < b
  b: number;
  /** First face that uses it. */
  f0: number;
  /** Second face, or -1 for a rim. vpy3d ignores a third face. */
  f1: number;
  /** How many faces use it (>2 = non-manifold). */
  uses: number;
  /** A crease (or a rim): vpy3d keeps it as a line. */
  hard: boolean;
}

export interface Geometry {
  /** Unit face normals, Newell's method, flipped outward like vpy3d. */
  normals: [number, number, number][];
  /** Whether the raw winding had to be flipped to point outward. */
  flipped: boolean[];
  edges: Edge[];
  centroid: [number, number, number];
}

// ── raw JSON → editable data ───────────────────────────────────────────────

const isObj = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v);
const num = (v: unknown, d = 0): number => (typeof v === 'number' && Number.isFinite(v) ? v : d);

export function isLofted(raw: VmeshRaw): boolean {
  return Array.isArray(raw.sections) && raw.sections.length > 0;
}

/** The explicit vertices/faces of a raw `.vmesh`, coerced to numbers. */
export function meshFromRaw(raw: VmeshRaw): MeshData {
  const vertices: MeshVertex[] = Array.isArray(raw.vertices)
    ? raw.vertices.map((v) => (isObj(v) ? { ...v, x: num(v.x), y: num(v.y), z: num(v.z) } : { x: 0, y: 0, z: 0 }))
    : [];
  const faces: MeshFace[] = Array.isArray(raw.faces)
    ? raw.faces.map((f) => (Array.isArray(f) ? f.map((i) => num(i, -1)) : []))
    : [];
  return { vertices, faces };
}

/**
 * Write `mesh` back into `raw`, keeping every other field (and the key order).
 * Writing an explicit mesh into a lofted file drops `sections` and `caps`: a
 * file holds one form or the other.
 */
export function meshToRaw(raw: VmeshRaw, mesh: MeshData): VmeshRaw {
  const out: VmeshRaw = { ...raw };
  out.vertices = mesh.vertices.map((v) => ({ ...v, x: v.x, y: v.y, z: v.z }));
  out.faces = mesh.faces.map((f) => [...f]);
  delete out.sections;
  delete out.caps;
  return out;
}

/** The Q14 crease threshold the compiler will store (vmeshres.rs hard_cos_q14). */
export function hardCosQ14(raw: VmeshRaw): number {
  if (typeof raw.hard_cos === 'number' && Number.isInteger(raw.hard_cos)) {
    return Math.max(-Q14_ONE, Math.min(Q14_ONE, raw.hard_cos));
  }
  const deg = typeof raw.hard === 'number' ? raw.hard : 45;
  return Math.max(-Q14_ONE, Math.min(Q14_ONE, Math.round(Math.cos((deg * Math.PI) / 180) * Q14_ONE)));
}

// ── lofting (vmeshres.rs `loft`) ───────────────────────────────────────────

export interface LoftResult {
  mesh?: MeshData;
  issues: Issue[];
  /** Some `.vec` sections are not loaded yet: the preview is incomplete. */
  pending: boolean;
}

export function loftRaw(raw: VmeshRaw, resolveVec?: VecResolver): LoftResult {
  const issues: Issue[] = [];
  const sections = Array.isArray(raw.sections) ? raw.sections : [];
  const caps = raw.caps === undefined ? true : raw.caps === true;
  const rings: [number, number, number][][] = [];
  let pending = false;
  sections.forEach((s, si) => {
    if (!isObj(s)) return;
    const z = num(s.z);
    if (typeof s.vec === 'string') {
      const r = resolveVec ? resolveVec(s.vec, typeof s.path === 'string' ? s.path : undefined) : undefined;
      if (r === undefined) { pending = true; return; }
      if (typeof r === 'string') {
        issues.push({ level: 'error', section: si, message: `section ${si}: ${r}` });
        return;
      }
      if (r.points.length < 3) {
        issues.push({ level: 'error', section: si, message: `section ${si}: path in ${s.vec} has ${r.points.length} points, a ring needs 3` });
        return;
      }
      rings[si] = r.points.map((p) => [Math.trunc(p.x), Math.trunc(p.y), p.z !== undefined ? Math.trunc(p.z) : z]);
      return;
    }
    const pts = Array.isArray(s.points) ? s.points : [];
    if (pts.length < 3) {
      issues.push({ level: 'error', section: si, message: `section ${si}: a section needs at least 3 points (got ${pts.length})` });
      return;
    }
    rings[si] = pts.map((p) => (isObj(p) ? [num(p.x), num(p.y), typeof p.z === 'number' ? p.z : z] : [0, 0, z]));
  });
  if (sections.length < 2) {
    issues.push({ level: 'error', message: `lofting needs at least 2 sections (got ${sections.length})` });
  }
  const known = rings.map((r, i) => ({ r, i })).filter((x) => x.r);
  if (known.length) {
    const n0 = known[0].r.length;
    for (const { r, i } of known) {
      if (r.length !== n0) {
        issues.push({ level: 'error', section: i, message: `section ${i} has ${r.length} points but section ${known[0].i} has ${n0}: every section must have the same count` });
      }
    }
  }
  if (issues.some((x) => x.level === 'error') || pending || sections.length < 2) {
    return { issues, pending };
  }
  const n = rings[0].length;
  const vertices: MeshVertex[] = [];
  for (const ring of rings) for (const [x, y, z] of ring) vertices.push({ x, y, z });
  const faces: MeshFace[] = [];
  for (let s = 0; s < rings.length - 1; s++) {
    const a = s * n, b = (s + 1) * n;
    for (let k = 0; k < n; k++) {
      const k2 = (k + 1) % n;
      faces.push([a + k, a + k2, b + k2, b + k]);
    }
  }
  if (caps) {
    const last = (rings.length - 1) * n;
    const near: number[] = [];
    for (let k = n - 1; k >= 0; k--) near.push(k);
    faces.push(near);
    const far: number[] = [];
    for (let k = 0; k < n; k++) far.push(last + k);
    faces.push(far);
  }
  return { mesh: { vertices, faces }, issues, pending: false };
}

/** Pick the ring a lofted section would take from a parsed `.vec` (vecres.rs visible_paths). */
export function ringFromVec(vecJson: unknown, path: string | undefined, file: string): VecRing | string {
  if (!isObj(vecJson) || !Array.isArray(vecJson.layers)) return `${file}: not a .vec file`;
  const paths: { name: string; points: unknown[] }[] = [];
  for (const l of vecJson.layers) {
    if (!isObj(l) || l.visible === false || !Array.isArray(l.paths)) continue;
    for (const p of l.paths) {
      if (isObj(p)) paths.push({ name: typeof p.name === 'string' ? p.name : '', points: Array.isArray(p.points) ? p.points : [] });
    }
  }
  const chosen = path !== undefined ? paths.find((p) => p.name === path) : paths[0];
  if (!chosen) return `${file}: no path named ${path === undefined ? '(any)' : JSON.stringify(path)}`;
  return {
    points: chosen.points.map((p) => (isObj(p)
      ? { x: num(p.x), y: num(p.y), z: typeof p.z === 'number' ? p.z : undefined }
      : { x: 0, y: 0 })),
  };
}

// ── validation ─────────────────────────────────────────────────────────────

const isInt = (v: unknown): v is number => typeof v === 'number' && Number.isInteger(v);

/**
 * Every issue with a raw `.vmesh`. Errors mirror what the compiler refuses
 * (serde types + vmeshres.rs); warnings are what vpy3d refuses at load time or
 * draws wrong.
 */
export function validateVmesh(raw: unknown, resolveVec?: VecResolver): Issue[] {
  const out: Issue[] = [];
  const err = (message: string, extra: Partial<Issue> = {}) => out.push({ level: 'error', message, ...extra });
  const warn = (message: string, extra: Partial<Issue> = {}) => out.push({ level: 'warning', message, ...extra });

  if (!isObj(raw)) { err('the file must be a JSON object'); return out; }

  // serde field types
  if (raw.name !== undefined && typeof raw.name !== 'string') err('"name" must be a string');
  if (raw.hard !== undefined && raw.hard !== null && typeof raw.hard !== 'number') err('"hard" must be a number (crease angle in degrees)');
  if (raw.hard_cos !== undefined && raw.hard_cos !== null && !isInt(raw.hard_cos)) err('"hard_cos" must be an integer (Q14 cosine)');
  if (raw.open !== undefined && typeof raw.open !== 'boolean') err('"open" must be true or false');
  if (raw.caps !== undefined && typeof raw.caps !== 'boolean') err('"caps" must be true or false');
  for (const k of ['vertices', 'faces', 'sections'] as const) {
    if (raw[k] !== undefined && !Array.isArray(raw[k])) err(`"${k}" must be an array`);
  }
  if (out.length) return out;

  const vertsRaw = (raw.vertices as unknown[] | undefined) ?? [];
  const facesRaw = (raw.faces as unknown[] | undefined) ?? [];
  const sections = (raw.sections as unknown[] | undefined) ?? [];

  const checkPoint = (p: unknown, where: string, needZ: boolean, extra: Partial<Issue>) => {
    if (!isObj(p)) { err(`${where} must be an object {"x","y","z"}`, extra); return; }
    for (const axis of ['x', 'y'] as const) {
      if (p[axis] === undefined) err(`${where} has no "${axis}"`, extra);
      else if (!isInt(p[axis])) err(`${where}: "${axis}" must be a whole number (got ${JSON.stringify(p[axis])})`, extra);
    }
    if (p.z !== undefined && p.z !== null && !isInt(p.z)) err(`${where}: "z" must be a whole number (got ${JSON.stringify(p.z)})`, extra);
    else if (needZ && p.z === undefined) warn(`${where} has no "z": the compiler uses 0`, extra);
  };

  vertsRaw.forEach((v, i) => checkPoint(v, `vertex ${i}`, true, { vertex: i }));
  facesRaw.forEach((f, i) => {
    if (!Array.isArray(f)) { err(`face ${i} must be an array of vertex indices`, { face: i }); return; }
    f.forEach((idx) => {
      if (!isInt(idx) || idx < 0 || idx > 65535) err(`face ${i}: ${JSON.stringify(idx)} is not a vertex index (0..65535)`, { face: i });
    });
  });
  sections.forEach((s, si) => {
    if (!isObj(s)) { err(`section ${si} must be an object`, { section: si }); return; }
    if (s.z !== undefined && !isInt(s.z)) err(`section ${si}: "z" must be a whole number`, { section: si });
    if (s.points !== undefined && !Array.isArray(s.points)) err(`section ${si}: "points" must be an array`, { section: si });
    if (s.vec !== undefined && s.vec !== null && typeof s.vec !== 'string') err(`section ${si}: "vec" must be a path string`, { section: si });
    if (s.path !== undefined && s.path !== null && typeof s.path !== 'string') err(`section ${si}: "path" must be a string`, { section: si });
    // serde parses `points` even when `vec` replaces them.
    if (Array.isArray(s.points)) {
      s.points.forEach((p, pi) => checkPoint(p, `section ${si} point ${pi}`, false, { section: si }));
    }
  });
  if (out.some((x) => x.level === 'error')) return out;

  // vmeshres.rs compile_vmesh_file_to_bytes
  let mesh: MeshData;
  if (sections.length) {
    if (vertsRaw.length || facesRaw.length) {
      err('a .vmesh gives either "sections" OR "vertices"+"faces", not both');
      return out;
    }
    const lofted = loftRaw(raw, resolveVec);
    out.push(...lofted.issues);
    if (!lofted.mesh) {
      if (lofted.pending) warn('a section takes its ring from a .vec that is not loaded: those checks wait for it');
      return out;
    }
    mesh = lofted.mesh;
  } else {
    if (!vertsRaw.length || !facesRaw.length) {
      err('a .vmesh needs "sections", or "vertices" and "faces"');
      return out;
    }
    mesh = meshFromRaw(raw);
  }

  const nv = mesh.vertices.length;
  if (nv > 65535) err(`${nv} vertices is too many`);
  mesh.faces.forEach((f, fi) => {
    if (f.length < 3) err(`face ${fi} has ${f.length} vertices, needs 3`, { face: fi });
    if (f.length > 255) err(`face ${fi} has ${f.length} vertices, the count is a byte`, { face: fi });
    for (const i of f) {
      if (i >= nv) { err(`face ${fi} refers to vertex ${i} but there are only ${nv}`, { face: fi }); break; }
    }
  });
  mesh.vertices.forEach((v, vi) => {
    for (const axis of ['x', 'y', 'z'] as const) {
      const c = v[axis];
      if (c < I16_MIN || c > I16_MAX) err(`vertex ${vi} has ${axis}=${c}, outside the i16 the format stores (${I16_MIN}..${I16_MAX})`, { vertex: vi });
    }
  });
  if (out.some((x) => x.level === 'error')) return out;

  out.push(...meshWarnings(mesh, raw.open === true));
  return out;
}

/** What compiles but vpy3d will refuse or draw wrong. Assumes no errors. */
export function meshWarnings(mesh: MeshData, open: boolean): Issue[] {
  const out: Issue[] = [];
  const warn = (message: string, extra: Partial<Issue> = {}) => out.push({ level: 'warning', message, ...extra });
  const nv = mesh.vertices.length;
  const nf = mesh.faces.length;
  const idxTotal = mesh.faces.reduce((a, f) => a + f.length, 0);

  if (nv > VPY3D_MESH_MAXV) warn(`${nv} vertices: vpy3d refuses more than ${VPY3D_MESH_MAXV} per mesh (VPY3D_MESH_MAXV)`);
  if (nf > VPY3D_MESH_MAXF) warn(`${nf} faces: vpy3d refuses more than ${VPY3D_MESH_MAXF} per mesh (VPY3D_MESH_MAXF)`);
  if (nv > VPY3D_POOL_V) warn(`${nv} vertices fill vpy3d's shared vertex pool (${VPY3D_POOL_V}, VPY3D_POOL_V)`);
  if (nf > VPY3D_POOL_F) warn(`${nf} faces fill vpy3d's shared face pool (${VPY3D_POOL_F}, VPY3D_POOL_F)`);
  if (idxTotal > VPY3D_POOL_FV) warn(`${idxTotal} face indices fill vpy3d's shared pool (${VPY3D_POOL_FV}, VPY3D_POOL_FV)`);
  if (idxTotal > 65535) warn(`${idxTotal} face indices: the header stores the total as 16 bits`);

  const used = new Uint8Array(nv);
  mesh.faces.forEach((f, fi) => {
    const seen = new Set<number>();
    for (const i of f) {
      if (seen.has(i)) { warn(`face ${fi} uses vertex ${i} twice`, { face: fi }); break; }
      seen.add(i);
    }
    for (const i of f) used[i] = 1;
    const n = newell(mesh.vertices, f);
    if (Math.hypot(n[0], n[1], n[2]) < 1e-6) warn(`face ${fi} has no area (its corners are in line)`, { face: fi });
  });
  for (let i = 0; i < nv; i++) if (!used[i]) warn(`vertex ${i} is in no face (it is never drawn)`, { vertex: i });

  // edges: count + manifold + winding consistency
  const dirCount = new Map<string, number>();
  const edges = new Map<string, number>();
  mesh.faces.forEach((f) => {
    for (let k = 0; k < f.length; k++) {
      const a = f[k], b = f[(k + 1) % f.length];
      if (a === b) continue;
      const key = a < b ? `${a},${b}` : `${b},${a}`;
      edges.set(key, (edges.get(key) ?? 0) + 1);
      dirCount.set(`${a}>${b}`, (dirCount.get(`${a}>${b}`) ?? 0) + 1);
    }
  });
  if (edges.size > VPY3D_POOL_E) warn(`${edges.size} edges fill vpy3d's shared edge pool (${VPY3D_POOL_E}, VPY3D_POOL_E)`);
  let rims = 0, nonManifold = 0, sameDir = 0;
  for (const [key, uses] of edges) {
    if (uses === 1) rims++;
    else if (uses > 2) nonManifold++;
    const [a, b] = key.split(',');
    if ((dirCount.get(`${a}>${b}`) ?? 0) > 1 || (dirCount.get(`${b}>${a}`) ?? 0) > 1) sameDir++;
  }
  if (rims && !open) warn(`${rims} edge(s) belong to one face only: a solid should be closed (set "open": true for a plate)`);
  if (nonManifold) warn(`${nonManifold} edge(s) are shared by more than 2 faces: vpy3d only sees the first two`);
  if (sameDir) warn(`${sameDir} edge(s) run the same way in both faces: the winding is inconsistent (use "Wind outward")`);
  return out;
}

// ── geometry (vpy3d.c mesh_end + mesh_geometry) ────────────────────────────

/** Newell's normal (unnormalised) of a face. */
export function newell(verts: MeshVertex[], f: MeshFace): [number, number, number] {
  let nx = 0, ny = 0, nz = 0;
  for (let i = 0; i < f.length; i++) {
    const p = verts[f[i]], q = verts[f[(i + 1) % f.length]];
    if (!p || !q) continue;
    nx += (p.y - q.y) * (p.z + q.z);
    ny += (p.z - q.z) * (p.x + q.x);
    nz += (p.x - q.x) * (p.y + q.y);
  }
  return [nx, ny, nz];
}

export function centroidOf(verts: MeshVertex[], idx?: number[]): [number, number, number] {
  const list = idx ?? verts.map((_, i) => i);
  if (!list.length) return [0, 0, 0];
  let x = 0, y = 0, z = 0;
  for (const i of list) { x += verts[i].x; y += verts[i].y; z += verts[i].z; }
  return [x / list.length, y / list.length, z / list.length];
}

/**
 * Normals, the edge table and the crease flags exactly as vpy3d builds them
 * (to floating point instead of Q14). Faces with out-of-range indices are
 * skipped, so it is safe on a mesh with errors.
 */
export function meshGeometry(mesh: MeshData, hardCos: number): Geometry {
  const { vertices: v, faces } = mesh;
  const c = centroidOf(v);
  const normals: [number, number, number][] = [];
  const flipped: boolean[] = [];
  const valid = (f: MeshFace) => f.length >= 3 && f.every((i) => i >= 0 && i < v.length);
  faces.forEach((f) => {
    if (!valid(f)) { normals.push([0, 0, 1]); flipped.push(false); return; }
    const n = newell(v, f);
    const len = Math.hypot(n[0], n[1], n[2]);
    let u: [number, number, number] = len > 1e-9 ? [n[0] / len, n[1] / len, n[2] / len] : [0, 0, 1];
    const g = centroidOf(v, f);
    const outward = u[0] * (g[0] - c[0]) + u[1] * (g[1] - c[1]) + u[2] * (g[2] - c[2]);
    const flip = outward < 0;
    if (flip) u = [-u[0], -u[1], -u[2]];
    normals.push(u);
    flipped.push(flip);
  });
  const byKey = new Map<string, Edge>();
  const edges: Edge[] = [];
  faces.forEach((f, fi) => {
    if (!valid(f)) return;
    for (let k = 0; k < f.length; k++) {
      const p = f[k], q = f[(k + 1) % f.length];
      const a = Math.min(p, q), b = Math.max(p, q);
      const key = `${a},${b}`;
      const e = byKey.get(key);
      if (e) { e.uses++; if (e.f1 < 0 && e.f0 !== fi) e.f1 = fi; continue; }
      const ne: Edge = { a, b, f0: fi, f1: -1, uses: 1, hard: false };
      byKey.set(key, ne);
      edges.push(ne);
    }
  });
  const thr = hardCos / Q14_ONE;
  for (const e of edges) {
    if (e.f1 < 0) { e.hard = true; continue; }
    const p = normals[e.f0], q = normals[e.f1];
    e.hard = p[0] * q[0] + p[1] * q[1] + p[2] * q[2] < thr;
  }
  return { normals, flipped, edges, centroid: c };
}

/**
 * vpy3d_draw_mesh's per-edge decision for a viewer looking along `forward`
 * (orthographic): a rim is drawn if the mesh is open or its face is turned to
 * us, a crease if either face is, a smooth edge only on the silhouette.
 */
export function edgeVisible(geo: Geometry, e: Edge, forward: [number, number, number], open: boolean): boolean {
  const front = (f: number) => {
    const n = geo.normals[f];
    return n[0] * forward[0] + n[1] * forward[1] + n[2] * forward[2] < 0;
  };
  if (e.f1 < 0) return open ? true : front(e.f0);
  if (e.hard) return front(e.f0) || front(e.f1);
  return front(e.f0) !== front(e.f1);
}

// ── edit operations (all pure; they return a new MeshData) ─────────────────

const clampI16 = (n: number) => Math.max(I16_MIN, Math.min(I16_MAX, Math.round(n)));

export function cloneMesh(m: MeshData): MeshData {
  return { vertices: m.vertices.map((v) => ({ ...v })), faces: m.faces.map((f) => [...f]) };
}

export function addVertex(m: MeshData, p: { x: number; y: number; z: number }): { mesh: MeshData; index: number } {
  const out = cloneMesh(m);
  out.vertices.push({ x: clampI16(p.x), y: clampI16(p.y), z: clampI16(p.z) });
  return { mesh: out, index: out.vertices.length - 1 };
}

export function setVertex(m: MeshData, i: number, p: Partial<Pick<MeshVertex, 'x' | 'y' | 'z'>>): MeshData {
  const out = cloneMesh(m);
  const v = out.vertices[i];
  if (!v) return out;
  for (const k of ['x', 'y', 'z'] as const) if (p[k] !== undefined && Number.isFinite(p[k])) v[k] = clampI16(p[k]!);
  return out;
}

/** Move vertices from their positions in `base` by a delta (used while dragging). */
export function moveVertices(base: MeshData, idx: Iterable<number>, d: { x: number; y: number; z: number }): MeshData {
  const out = cloneMesh(base);
  for (const i of idx) {
    const v = out.vertices[i];
    if (!v) continue;
    v.x = clampI16(v.x + d.x); v.y = clampI16(v.y + d.y); v.z = clampI16(v.z + d.z);
  }
  return out;
}

/** Delete vertices; faces that use any of them go too; the rest are re-indexed. */
export function deleteVertices(m: MeshData, del: Iterable<number>): MeshData {
  const gone = new Set(del);
  const remap = new Map<number, number>();
  const vertices: MeshVertex[] = [];
  m.vertices.forEach((v, i) => { if (!gone.has(i)) { remap.set(i, vertices.length); vertices.push({ ...v }); } });
  const faces = m.faces
    .filter((f) => f.every((i) => !gone.has(i)))
    .map((f) => f.map((i) => remap.get(i) ?? i));
  return { vertices, faces };
}

/** Drop vertices no face uses. */
export function removeUnusedVertices(m: MeshData): MeshData {
  const used = new Set<number>();
  for (const f of m.faces) for (const i of f) used.add(i);
  return deleteVertices(m, m.vertices.map((_, i) => i).filter((i) => !used.has(i)));
}

/** A face from vertices in the order given. Error string if it can't be made. */
export function makeFace(m: MeshData, order: number[]): { mesh: MeshData } | { error: string } {
  const uniq = order.filter((v, i) => order.indexOf(v) === i);
  if (uniq.length < 3) return { error: 'select at least 3 vertices, in order around the face' };
  if (uniq.length > 255) return { error: 'a face has at most 255 vertices' };
  if (uniq.some((i) => i < 0 || i >= m.vertices.length)) return { error: 'a selected vertex does not exist' };
  const key = [...uniq].sort((a, b) => a - b).join(',');
  if (m.faces.some((f) => [...f].sort((a, b) => a - b).join(',') === key)) return { error: 'that face already exists' };
  const out = cloneMesh(m);
  // Wind it outward if the mesh has a body to be outside of.
  let face = uniq;
  if (out.faces.length) {
    const n = newell(out.vertices, face);
    const g = centroidOf(out.vertices, face);
    const c = centroidOf(out.vertices);
    if (n[0] * (g[0] - c[0]) + n[1] * (g[1] - c[1]) + n[2] * (g[2] - c[2]) < 0) face = [...face].reverse();
  }
  out.faces.push(face);
  return { mesh: out };
}

export function deleteFaces(m: MeshData, del: Iterable<number>): MeshData {
  const gone = new Set(del);
  return { vertices: m.vertices.map((v) => ({ ...v })), faces: m.faces.filter((_, i) => !gone.has(i)).map((f) => [...f]) };
}

export function flipFaces(m: MeshData, which: Iterable<number>): MeshData {
  const out = cloneMesh(m);
  for (const i of which) if (out.faces[i]) out.faces[i].reverse();
  return out;
}

/** Re-wind every face whose normal points at the mesh centroid (what vpy3d rescues at load). */
export function windOutward(m: MeshData): MeshData {
  const out = cloneMesh(m);
  const c = centroidOf(out.vertices);
  out.faces = out.faces.map((f) => {
    if (f.length < 3 || f.some((i) => i < 0 || i >= out.vertices.length)) return f;
    const n = newell(out.vertices, f);
    const g = centroidOf(out.vertices, f);
    return n[0] * (g[0] - c[0]) + n[1] * (g[1] - c[1]) + n[2] * (g[2] - c[2]) < 0 ? [...f].reverse() : f;
  });
  return out;
}

/** The faces that contain both a and b. */
function facesWith(m: MeshData, a: number, b: number): number[] {
  const r: number[] = [];
  m.faces.forEach((f, i) => { if (f.includes(a) && f.includes(b)) r.push(i); });
  return r;
}

const adjacentIn = (f: MeshFace, a: number, b: number) => {
  const i = f.indexOf(a), j = f.indexOf(b), n = f.length;
  return (i + 1) % n === j || (j + 1) % n === i;
};

/**
 * CONNECT: add an edge between two vertices of the same face by splitting that
 * face in two along a–b. Both halves keep the original winding.
 */
export function connectVertices(m: MeshData, a: number, b: number): { mesh: MeshData } | { error: string } {
  if (a === b) return { error: 'pick two different vertices' };
  const fi = facesWith(m, a, b).find((i) => !adjacentIn(m.faces[i], a, b));
  if (fi === undefined) {
    return { error: facesWith(m, a, b).length ? 'those two vertices are already joined by an edge' : 'the two vertices must be corners of the same face' };
  }
  const f = m.faces[fi];
  const i = f.indexOf(a), j = f.indexOf(b);
  const walk = (from: number, to: number) => {
    const r: number[] = [];
    for (let k = from; ; k = (k + 1) % f.length) { r.push(f[k]); if (k === to) break; }
    return r;
  };
  const out = cloneMesh(m);
  out.faces.splice(fi, 1, walk(i, j), walk(j, i));
  return { mesh: out };
}

/**
 * DISCONNECT: remove the edge a–b by merging the two faces either side of it
 * into one polygon. A rim edge (one face) can't be removed this way.
 */
export function disconnectVertices(m: MeshData, a: number, b: number): { mesh: MeshData } | { error: string } {
  const both = facesWith(m, a, b).filter((i) => adjacentIn(m.faces[i], a, b));
  if (both.length === 0) return { error: 'there is no edge between those two vertices' };
  if (both.length === 1) return { error: 'that edge is a rim (one face): delete the face instead' };
  if (both.length > 2) return { error: 'that edge is shared by more than two faces' };
  const [f1i, f2i] = both;
  const f1 = m.faces[f1i], f2 = m.faces[f2i];
  // Rotate f1 so it ends ...a→b? Make f1 run x..., p, q where p→q is the shared edge.
  const n1 = f1.length;
  let s = f1.indexOf(a);
  const [p, q] = f1[(s + 1) % n1] === b ? [a, b] : [b, a];
  s = f1.indexOf(q);
  const ring1: number[] = []; // from q round to p (the whole of f1, ending at p)
  for (let k = 0; k < n1; k++) ring1.push(f1[(s + k) % n1]);
  // f2 traverses the edge q→p if the winding is consistent; walk it from p round to q.
  const n2 = f2.length;
  const ip = f2.indexOf(p);
  let ring2: number[] = [];
  if (f2[(ip + 1) % n2] === q) {
    // same direction: inconsistent winding — walk f2 backwards instead.
    for (let k = 0; k < n2; k++) ring2.push(f2[(ip - k + n2) % n2]);
  } else {
    for (let k = 0; k < n2; k++) ring2.push(f2[(ip + k) % n2]);
  }
  // ring1 = q ... p ; ring2 = p ... q  → merged = q ... p (ring1) + ring2 interior
  const merged = [...ring1, ...ring2.slice(1, -1)];
  const uniq = merged.filter((v, i) => merged.indexOf(v) === i);
  if (uniq.length !== merged.length) return { error: 'the two faces share more than one edge: merge would make a degenerate face' };
  if (merged.length > 255) return { error: 'the merged face would have more than 255 vertices' };
  const out = cloneMesh(m);
  out.faces[f1i] = merged;
  out.faces.splice(f2i, 1);
  return { mesh: out };
}

/** Append `add` to `m` (vertex indices shifted). */
export function appendMesh(m: MeshData, add: MeshData): MeshData {
  const base = m.vertices.length;
  return {
    vertices: [...m.vertices.map((v) => ({ ...v })), ...add.vertices.map((v) => ({ ...v }))],
    faces: [...m.faces.map((f) => [...f]), ...add.faces.map((f) => f.map((i) => i + base))],
  };
}

// ── primitives (wound anticlockwise seen from outside: Newell normal outward) ─

const V = (x: number, y: number, z: number): MeshVertex => ({ x: clampI16(x), y: clampI16(y), z: clampI16(z) });

/** Axis-aligned box, `size` = edge length. */
export function primitiveCube(size = 1000): MeshData {
  const h = size / 2;
  return {
    vertices: [V(-h, -h, -h), V(h, -h, -h), V(h, h, -h), V(-h, h, -h), V(-h, -h, h), V(h, -h, h), V(h, h, h), V(-h, h, h)],
    faces: [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [0, 4, 7, 3]],
  };
}

/** Square-based pyramid, apex up (+y). */
export function primitivePyramid(size = 1000): MeshData {
  const h = size / 2;
  return {
    vertices: [V(-h, -h, -h), V(h, -h, -h), V(h, -h, h), V(-h, -h, h), V(0, h, 0)],
    faces: [[0, 1, 2, 3], [0, 4, 1], [1, 4, 2], [2, 4, 3], [3, 4, 0]],
  };
}

/** Flat grid in the XZ plane (y = 0), facing up; `cells` per side. A plate: set `open`. */
export function primitiveGrid(size = 1000, cells = 1): MeshData {
  const n = Math.max(1, Math.min(15, Math.round(cells)));
  const h = size / 2;
  const vertices: MeshVertex[] = [];
  for (let j = 0; j <= n; j++) for (let i = 0; i <= n; i++) vertices.push(V(-h + (size * i) / n, 0, -h + (size * j) / n));
  const faces: MeshFace[] = [];
  const at = (i: number, j: number) => j * (n + 1) + i;
  for (let j = 0; j < n; j++) for (let i = 0; i < n; i++) faces.push([at(i, j), at(i, j + 1), at(i + 1, j + 1), at(i + 1, j)]);
  return { vertices, faces };
}

/** Cylinder along Y with `sides` facets (3..32), capped. */
export function primitiveCylinder(radius = 500, height = 1000, sides = 8): MeshData {
  const n = Math.max(3, Math.min(32, Math.round(sides)));
  const vertices: MeshVertex[] = [];
  for (const y of [-height / 2, height / 2]) {
    for (let k = 0; k < n; k++) {
      const a = (2 * Math.PI * k) / n;
      vertices.push(V(radius * Math.cos(a), y, radius * Math.sin(a)));
    }
  }
  const faces: MeshFace[] = [];
  for (let k = 0; k < n; k++) {
    const k2 = (k + 1) % n;
    faces.push([k, n + k, n + k2, k2]);
  }
  const bottom: number[] = [];
  for (let k = 0; k < n; k++) bottom.push(k);
  const top: number[] = [];
  for (let k = n - 1; k >= 0; k--) top.push(n + k);
  faces.push(bottom, top);
  return windOutward({ vertices, faces });
}

export type PrimitiveKind = 'cube' | 'pyramid' | 'grid' | 'cylinder';

export function makePrimitive(kind: PrimitiveKind, size: number, segments: number): MeshData {
  switch (kind) {
    case 'cube': return primitiveCube(size);
    case 'pyramid': return primitivePyramid(size);
    case 'grid': return primitiveGrid(size, segments);
    case 'cylinder': return primitiveCylinder(size / 2, size, segments);
  }
}
