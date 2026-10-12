/**
 * A `.vmesh` as strokes for the 3D Animation editor's preview: its faces' edges (hard and
 * smooth) and its scenery lines, in the mesh's own coordinates. Read with the Mesh Editor's
 * model (../mesh/vmeshModel.ts), as the Scene Editor does.
 */
import * as M from '../mesh/vmeshModel';
import type { Vec3 } from './animModel';

/** An edge, and the outward normals of the faces either side (n1 null: an open edge or a line). */
export interface MeshSeg { a: Vec3; b: Vec3; hard: boolean; n0: Vec3 | null; n1: Vec3 | null }
export type MeshStrokes = { segs: MeshSeg[]; note?: string } | { error: string };

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

export function meshStrokes(json: unknown): MeshStrokes {
  if (!isObj(json)) return { error: 'not a JSON object' };
  const raw = json as M.VmeshRaw;
  let mesh = M.meshFromRaw(raw);
  let note: string | undefined;
  if (M.isLofted(raw)) {
    const l = M.loftRaw(raw);
    if (l.mesh && !l.pending) mesh = l.mesh;
    else note = 'lofted from .vec sections: not previewed here (open it in the Mesh Editor)';
  }
  const v = mesh.vertices;
  const geo = M.meshGeometry(mesh, M.hardCosQ14(raw));
  const segs: MeshSeg[] = [];
  for (const e of geo.edges) {
    const a = v[e.a], b = v[e.b];
    if (a && b) segs.push({ a: [a.x, a.y, a.z], b: [b.x, b.y, b.z], hard: e.hard, n0: geo.normals[e.f0] ?? null, n1: e.f1 >= 0 ? geo.normals[e.f1] ?? null : null });
  }
  for (const l of M.sceneryFromRaw(raw).lines) {
    const pts = l.points;
    const n = M.lineClosed(l) && pts.length > 2 ? pts.length : pts.length - 1;
    for (let k = 0; k < n; k++) {
      const a = pts[k], b = pts[(k + 1) % pts.length];
      segs.push({ a: [a.x, a.y, a.z], b: [b.x, b.y, b.z], hard: true, n0: null, n1: null });
    }
  }
  return { segs, note };
}

export type DirEntry = { name: string; path?: string; isDir: boolean; children?: DirEntry[] };

/** Every file with `ext` under a listing, by name → its path relative to the listed folder. */
export function collectByExt(entries: DirEntry[], ext: string, prefix = '', out: Record<string, string> = {}): Record<string, string> {
  const re = new RegExp(`\\.${ext}$`, 'i');
  for (const f of entries) {
    const rel = prefix ? `${prefix}/${f.name}` : f.name;
    if (f.isDir) collectByExt(f.children ?? [], ext, rel, out);
    else if (re.test(f.name)) {
      const n = f.name.replace(re, '');
      if (!(n in out)) out[n] = rel;
    }
  }
  return out;
}

export function uriToFsPath(uri: string): string {
  if (/^file:\/\/\/[A-Za-z]:\//.test(uri)) return uri.slice('file:///'.length);
  return uri.replace(/^file:\/\//, '');
}
export function dirOf(p: string): string {
  const n = p.replace(/\\/g, '/');
  const i = n.lastIndexOf('/');
  return i >= 0 ? n.slice(0, i) : '';
}
export function joinPath(dir: string, rel: string): string {
  const parts = `${dir}/${rel}`.replace(/\\/g, '/').split('/');
  const out: string[] = [];
  for (const p of parts) {
    if (p === '..' && out.length && out[out.length - 1] !== '..' && out[out.length - 1] !== '') out.pop();
    else if (p !== '.') out.push(p);
  }
  return out.join('/').replace(/\/+/g, '/');
}
