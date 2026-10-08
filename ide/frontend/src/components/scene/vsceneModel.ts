/**
 * `.vscene` model: validation, placement and edit operations for the Scene
 * Editor. Pure functions, no imports, so `tools/vscene-model-test.ts` runs it
 * straight under node.
 *
 * The format (docs/ASSETS.md, buildtools/vpy_codegen/src/vsceneres.rs):
 *   {"name"?, "fog"?:{"full","gone"}, "groups"?:[names], "items":[{
 *     "name"?, "mesh":"rib" | ["a","b"], "at"?:{"x","y","z"}, "follow"?:{"x","y","z"},
 *     "repeat"?:{"axis"?:"x"|"y"|"z","step","count"}, "window"?:{"min"?,"max"?},
 *     "br"?:1..100, "fog"?:true|false|"whole", "group"?:"name"|"!name"}]}
 * A scene places `.vmesh` pieces (assets/meshes/<name>.vmesh, next to the
 * scene's own folder) from one game position `pos` the game passes each frame.
 *
 * Validation mirrors what the compiler refuses (serde types + compile_vscene):
 * the editor has an error exactly when `vpy_cli check-asset` fails. Placement
 * (`placeScene`) is vpy3d_draw_scene's arithmetic (uvmc2-sdk vpy-c/vpy3d.c):
 * follow in Q16, `>> 16` floors, copies wrap with floor division.
 */

// ── limits (vsceneres.rs) ──────────────────────────────────────────────────

export const SCENE_LIMIT = 1_000_000;
export const MAX_MESHES = 16;
export const MAX_GROUPS = 32;
export const MAX_ITEMS = 65535;
export const FOLLOW_LIMIT = 64;
export const I32_MIN = -2147483648;
export const I32_MAX = 2147483647;
export const AXES = ['x', 'y', 'z'] as const;
export type Axis = typeof AXES[number];

// ── types ──────────────────────────────────────────────────────────────────

/** The document as JSON: every field the editor does not know rides along. */
export type VsceneRaw = Record<string, unknown>;
export type ItemRaw = Record<string, unknown>;

export interface Issue {
  level: 'error' | 'warning';
  message: string;
  /** The item it is about. */
  item?: number;
  /** The group it is about. */
  group?: number;
}

/** One copy of an item where the scene puts it for a given `pos`. */
export interface Placed {
  item: number;
  /** k: 0..count-1 along the repeat. */
  copy: number;
  /** The copy's number along the whole run (n0 + k): picks the mesh. */
  n: number;
  mesh: string;
  /** World position (no `place` transform: identity). */
  at: [number, number, number];
  /** Percent of the draw brightness (the item's br). */
  br: number;
  /** Item fog mode. */
  fog: 'segment' | 'none' | 'whole';
}

export interface Placement {
  /** Copies drawn. */
  copies: Placed[];
  /** Copies dropped by their window, per item. */
  windowed: number[];
  /** Items switched off by the groups mask. */
  groupedOut: boolean[];
}

const isObj = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v);
/** A whole number serde reads as i64 (JSON numbers with a fraction are refused). */
const isI64 = (v: unknown): v is number => typeof v === 'number' && Number.isSafeInteger(v);
const isF64 = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);
/** f64::round: halves away from zero (Math.round sends -0.5 up). */
export const roundHalfAway = (v: number) => Math.sign(v) * Math.round(Math.abs(v));
/** The Q16 the compiler stores for a follow factor. */
export const followQ16 = (v: number) => roundHalfAway(v * 65536);
/** floor(a / b), b > 0, whatever a's sign (vpy3d.c floor_div). */
export const floorDiv = (a: number, b: number) => Math.floor(a / b);
export const floorMod = (a: number, b: number) => a - floorDiv(a, b) * b;

// ── reading the JSON (with defaults) ───────────────────────────────────────

export function items(raw: VsceneRaw | null | undefined): ItemRaw[] {
  return raw && Array.isArray(raw.items) ? (raw.items as unknown[]).map((x) => (isObj(x) ? x : {})) : [];
}
export function groups(raw: VsceneRaw | null | undefined): string[] {
  return raw && Array.isArray(raw.groups) ? (raw.groups as unknown[]).map((g) => (typeof g === 'string' ? g : String(g))) : [];
}
/** The mesh names of an item ("mesh" a string or a list). */
export function itemMeshes(it: ItemRaw): string[] {
  const m = it.mesh;
  if (typeof m === 'string') return [m];
  if (Array.isArray(m)) return m.map((x) => (typeof x === 'string' ? x : ''));
  return [];
}
export function vecOf(it: ItemRaw, key: 'at' | 'follow'): [number, number, number] {
  const v = it[key];
  if (!isObj(v)) return [0, 0, 0];
  return AXES.map((a) => (isF64(v[a]) ? (v[a] as number) : 0)) as [number, number, number];
}
export interface RepeatInfo { axis: Axis; step: number; count: number }
export function repeatOf(it: ItemRaw): RepeatInfo | null {
  const r = it.repeat;
  if (!isObj(r)) return null;
  const axis = (AXES as readonly string[]).includes(r.axis as string) ? (r.axis as Axis) : 'z';
  return { axis, step: isF64(r.step) ? (r.step as number) : 0, count: isF64(r.count) ? (r.count as number) : 0 };
}
export function windowOf(it: ItemRaw): { min: number | null; max: number | null } | null {
  const w = it.window;
  if (!isObj(w)) return null;
  return { min: isF64(w.min) ? (w.min as number) : null, max: isF64(w.max) ? (w.max as number) : null };
}
export function brOf(it: ItemRaw): number {
  return isF64(it.br) ? (it.br as number) : 100;
}
export type FogMode = true | false | 'whole';
export function fogOf(it: ItemRaw): FogMode {
  return it.fog === false ? false : it.fog === 'whole' ? 'whole' : true;
}
/** The group an item names: {name, negated}, or null when it is always drawn. */
export function groupOf(it: ItemRaw): { name: string; negated: boolean } | null {
  if (typeof it.group !== 'string') return null;
  return it.group.startsWith('!') ? { name: it.group.slice(1), negated: true } : { name: it.group, negated: false };
}
/** The scene's distinct meshes in first-use order: the header's mesh table. */
export function meshTable(raw: VsceneRaw | null | undefined): string[] {
  const out: string[] = [];
  for (const it of items(raw)) for (const m of itemMeshes(it)) if (m && !out.includes(m)) out.push(m);
  return out;
}
export function itemLabel(it: ItemRaw, i: number): string {
  return typeof it.name === 'string' && it.name ? `item ${i} (${it.name})` : `item ${i}`;
}

// ── validation (serde + compile_vscene) ────────────────────────────────────

/**
 * Every error the compiler would refuse the file for (it stops at the first;
 * this lists them all). `meshExists(name)`: true / false, or undefined when
 * the editor does not know (no project listing): then nothing is said.
 */
export function validateVscene(raw: unknown, meshExists?: (name: string) => boolean | undefined): Issue[] {
  const out: Issue[] = [];
  const err = (message: string, where: { item?: number; group?: number } = {}) => out.push({ level: 'error', message, ...where });
  if (!isObj(raw)) { err('a .vscene is a JSON object'); return out; }

  if (raw.name !== undefined && raw.name !== null && typeof raw.name !== 'string') err('"name" must be a string');

  // groups: Vec<String> (#[serde(default)]: missing is fine, null is not)
  let gl: string[] = [];
  if (raw.groups !== undefined) {
    if (!Array.isArray(raw.groups)) err('"groups" must be a list of names');
    else {
      gl = raw.groups.map((g) => (typeof g === 'string' ? g : ''));
      raw.groups.forEach((g, i) => {
        if (typeof g !== 'string') err(`group ${i}: must be a string`, { group: i });
        else if (!g || g.startsWith('!')) err(`group ${i}: a name, not empty and not starting with '!'`, { group: i });
        else if (gl.indexOf(g) !== i) err(`group "${g}" is listed twice`, { group: i });
      });
      if (raw.groups.length > MAX_GROUPS) err(`at most ${MAX_GROUPS} groups (${raw.groups.length} given)`);
    }
  }

  if (raw.fog !== undefined && raw.fog !== null) {
    const f = raw.fog;
    if (!isObj(f) || !isI64(f.full) || !isI64(f.gone)) err('fog: {"full","gone"}, both whole numbers');
    else if (f.full < 0 || f.gone <= f.full || f.gone > I32_MAX) err(`fog: need 0 <= full < gone (full ${f.full}, gone ${f.gone})`);
  }

  if (raw.items !== undefined && !Array.isArray(raw.items)) { err('"items" must be a list'); return out; }
  const list = Array.isArray(raw.items) ? raw.items : [];
  if (!list.length) err('a scene needs at least one item');
  if (list.length > MAX_ITEMS) err(`too many items (${list.length})`);

  list.forEach((itv, i) => {
    if (!isObj(itv)) { err(`item ${i}: must be an object`, { item: i }); return; }
    const it = itv;
    const what = itemLabel(it, i);
    const e = (m: string) => err(`${what}: ${m}`, { item: i });
    if (it.name !== undefined && it.name !== null && typeof it.name !== 'string') e('"name" must be a string');

    // mesh: String | Vec<String>, required
    let names: string[] | null = null;
    if (typeof it.mesh === 'string') names = [it.mesh];
    else if (Array.isArray(it.mesh) && it.mesh.every((m) => typeof m === 'string')) names = it.mesh as string[];
    else e(it.mesh === undefined ? '"mesh" is missing' : '"mesh" is a mesh name or a list of names');
    if (names) {
      if (!names.length || names.length > 255) e('mesh must name 1 to 255 meshes');
      if (names.length > 1 && (it.repeat === undefined || it.repeat === null)) {
        e('several meshes take turns along a repeat; without one, name a single mesh');
      }
      for (const n of names) {
        if (!n || /[/\\]/.test(n) || n.endsWith('.vmesh')) {
          e(`mesh "${n}" must be the name of a .vmesh in assets/meshes, without the extension`);
        } else if (meshExists && meshExists(n) === false) {
          e(`mesh "${n}" does not exist (assets/meshes/${n}.vmesh)`);
        }
      }
    }

    // at / follow: VSceneVec {x,y,z: f64, default 0}
    for (const key of ['at', 'follow'] as const) {
      const v = it[key];
      if (v === undefined) continue;
      if (!isObj(v)) { e(`"${key}" must be {"x","y","z"}`); continue; }
      for (const a of AXES) {
        if (v[a] === undefined) continue;
        if (!isF64(v[a])) { e(`${key}.${a} must be a number`); continue; }
        const n = v[a] as number;
        if (key === 'at') {
          if (!Number.isInteger(n) || Math.abs(n) > SCENE_LIMIT) e(`at.${a}: ${n} must be a whole number within +-${SCENE_LIMIT}`);
        } else if (Math.abs(followQ16(n)) > FOLLOW_LIMIT * 65536) {
          e(`follow.${a}: ${n} is out of range (-${FOLLOW_LIMIT}..${FOLLOW_LIMIT})`);
        }
      }
    }

    // repeat: Option<{axis = "z", step: i64, count: i64}>
    if (it.repeat !== undefined && it.repeat !== null) {
      const r = it.repeat;
      if (!isObj(r)) e('"repeat" must be {"axis","step","count"}');
      else {
        if (r.axis !== undefined && typeof r.axis !== 'string') e('repeat axis must be "x", "y" or "z"');
        else if (r.axis !== undefined && !(AXES as readonly string[]).includes(r.axis as string)) e(`repeat axis "${r.axis}" (x, y or z)`);
        if (!isI64(r.step)) e('repeat step must be a whole number');
        else if (r.step <= 0 || r.step > SCENE_LIMIT) e(`repeat step must be 1..${SCENE_LIMIT}`);
        if (!isI64(r.count)) e('repeat count must be a whole number');
        else if (r.count < 1 || r.count > 255) e('repeat count must be 1..255');
      }
    }

    // fog: true | false | "whole" (default true; null is neither)
    if (it.fog !== undefined && it.fog !== true && it.fog !== false) {
      if (typeof it.fog === 'string') { if (it.fog !== 'whole') e(`fog is true, false or "whole" (not "${it.fog}")`); }
      else e('fog is true, false or "whole"');
    }

    // window: Option<{min?: i64, max?: i64}>
    if (it.window !== undefined && it.window !== null) {
      const w = it.window;
      if (!isObj(w)) e('"window" must be {"min","max"}');
      else {
        let ok = true;
        for (const k of ['min', 'max'] as const) {
          if (w[k] !== undefined && w[k] !== null && !isI64(w[k])) { e(`window ${k} must be a whole number`); ok = false; }
        }
        if (ok) {
          const lo = isI64(w.min) ? w.min : I32_MIN, hi = isI64(w.max) ? w.max : I32_MAX;
          if (lo > hi || lo < I32_MIN || hi > I32_MAX) e('window needs min <= max');
        }
      }
    }

    // group: Option<String>, "!name" negated, must be listed
    if (it.group !== undefined && it.group !== null) {
      if (typeof it.group !== 'string') e('"group" must be a group name');
      else {
        const name = it.group.startsWith('!') ? it.group.slice(1) : it.group;
        if (!gl.includes(name)) e(`group "${name}" is not in the scene's groups`);
      }
    }

    // br: Option<i64>, 1..100
    if (it.br !== undefined && it.br !== null) {
      if (!isI64(it.br) || it.br < 1 || it.br > 100) e('br is a percent, 1..100');
    }
  });

  const table = meshTable(raw);
  if (table.length > MAX_MESHES) err(`a scene may use at most ${MAX_MESHES} different meshes (${table.length} used)`);
  return out;
}

// ── placement (vpy3d_draw_scene) ───────────────────────────────────────────

/**
 * Where every copy of every item is for this `pos` and groups mask, as the
 * runtime computes it with `place` = identity. Items with errors are placed
 * as best they can be (bad numbers read as their defaults).
 */
export function placeScene(raw: VsceneRaw | null | undefined, pos: [number, number, number], groupsMask: number): Placement {
  const gl = groups(raw);
  const copies: Placed[] = [];
  const list = items(raw);
  const windowed = list.map(() => 0);
  const groupedOut = list.map(() => false);
  const P = pos.map((v) => Math.trunc(v)) as [number, number, number];
  list.forEach((it, i) => {
    const g = groupOf(it);
    if (g) {
      const bit = gl.indexOf(g.name);
      if (bit >= 0) {
        const on = ((groupsMask >>> bit) & 1) === 1;
        if (on === g.negated) { groupedOut[i] = true; return; }
      }
    }
    const names = itemMeshes(it);
    if (!names.length) return;
    const at = vecOf(it, 'at').map((v) => Math.trunc(v));
    const fq = vecOf(it, 'follow').map(followQ16);
    // (follow_q16 * pos) >> 16: an arithmetic shift floors
    const p = [0, 1, 2].map((a) => at[a] + Math.floor((fq[a] * P[a]) / 65536));
    const rep = repeatOf(it);
    const valid = rep && Number.isInteger(rep.step) && rep.step > 0 && Number.isInteger(rep.count) && rep.count >= 1;
    const axis = valid ? AXES.indexOf(rep!.axis) : 2;
    const step = valid ? rep!.step : 0;
    const count = valid ? Math.min(255, rep!.count) : 1;
    let n0 = 0;
    if (valid) {
      const moved = p[axis] - at[axis];
      n0 = floorDiv(-moved, step);
      p[axis] += n0 * step;
    }
    const w = windowOf(it);
    const lo = w?.min ?? I32_MIN, hi = w?.max ?? I32_MAX;
    const fog = fogOf(it);
    for (let k = 0; k < count; k++, p[axis] += step) {
      if (w && (p[2] < lo || p[2] > hi)) { windowed[i]++; continue; }
      const n = n0 + k;
      const mesh = names[names.length > 1 ? floorMod(n, names.length) : 0];
      copies.push({ item: i, copy: k, n, mesh, at: [p[0], p[1], p[2]], br: brOf(it), fog: fog === true ? 'segment' : fog === false ? 'none' : 'whole' });
    }
  });
  return { copies, windowed, groupedOut };
}

/** vpy3d_fog with the depth given directly (the preview has no game camera). */
export function fogBrightness(br: number, depth: number, full: number, gone: number): number {
  if (depth <= full) return br;
  if (depth >= gone || gone <= full) return 0;
  return Math.trunc((br * (gone - depth)) / (gone - full));
}

/** The scene fog as {full, gone}, or null when off (or unusable). */
export function sceneFog(raw: VsceneRaw | null | undefined): { full: number; gone: number } | null {
  const f = raw?.fog;
  if (!isObj(f) || !isF64(f.full) || !isF64(f.gone) || (f.full === 0 && f.gone === 0)) return null;
  return { full: f.full as number, gone: f.gone as number };
}

// ── edit operations (pure: each returns a new raw) ─────────────────────────

function withItems(raw: VsceneRaw, list: ItemRaw[]): VsceneRaw {
  return { ...raw, items: list };
}
function rawItems(raw: VsceneRaw): ItemRaw[] {
  return Array.isArray(raw.items) ? (raw.items as unknown[]).map((x) => (isObj(x) ? x : {})) : [];
}

export function setItem(raw: VsceneRaw, i: number, next: ItemRaw): VsceneRaw {
  const list = rawItems(raw);
  if (i < 0 || i >= list.length) return raw;
  list[i] = next;
  return withItems(raw, list);
}
/** Set (value !== undefined) or remove one key of item i. */
export function setItemField(raw: VsceneRaw, i: number, key: string, value: unknown): VsceneRaw {
  const it = rawItems(raw)[i];
  if (!it) return raw;
  const next = { ...it };
  if (value === undefined) delete next[key]; else next[key] = value;
  return setItem(raw, i, next);
}
/** One axis of "at" / "follow": 0 drops the axis, an empty object drops the key. */
export function setItemAxis(raw: VsceneRaw, i: number, key: 'at' | 'follow', axis: Axis, value: number): VsceneRaw {
  const it = rawItems(raw)[i];
  if (!it) return raw;
  const v: Record<string, unknown> = isObj(it[key]) ? { ...(it[key] as Record<string, unknown>) } : {};
  if (value === 0) delete v[axis]; else v[axis] = value;
  return setItemField(raw, i, key, Object.keys(v).length ? v : undefined);
}
/** One field of "repeat" / "window" ("window" min/max: undefined removes it). */
export function setItemSub(raw: VsceneRaw, i: number, key: 'repeat' | 'window', field: string, value: unknown): VsceneRaw {
  const it = rawItems(raw)[i];
  if (!it) return raw;
  const v: Record<string, unknown> = isObj(it[key]) ? { ...(it[key] as Record<string, unknown>) } : {};
  if (value === undefined) delete v[field]; else v[field] = value;
  return setItemField(raw, i, key, v);
}
/** "mesh" from a list of names: one name is stored as a string unless `keepList`. */
export function setItemMeshes(raw: VsceneRaw, i: number, names: string[], keepList = false): VsceneRaw {
  return setItemField(raw, i, 'mesh', names.length === 1 && !keepList ? names[0] : [...names]);
}

export function addItem(raw: VsceneRaw, item: ItemRaw, at?: number): { raw: VsceneRaw; index: number } {
  const list = rawItems(raw);
  const index = at === undefined ? list.length : Math.max(0, Math.min(list.length, at));
  list.splice(index, 0, item);
  return { raw: withItems(raw, list), index };
}
export function duplicateItem(raw: VsceneRaw, i: number): { raw: VsceneRaw; index: number } {
  const it = rawItems(raw)[i];
  if (!it) return { raw, index: i };
  return addItem(raw, JSON.parse(JSON.stringify(it)), i + 1);
}
export function deleteItem(raw: VsceneRaw, i: number): VsceneRaw {
  const list = rawItems(raw);
  if (i < 0 || i >= list.length) return raw;
  list.splice(i, 1);
  return withItems(raw, list);
}
/** Move item i by delta (-1 up = drawn earlier, +1 down). */
export function moveItem(raw: VsceneRaw, i: number, delta: number): { raw: VsceneRaw; index: number } {
  const list = rawItems(raw);
  const j = i + delta;
  if (i < 0 || i >= list.length || j < 0 || j >= list.length) return { raw, index: i };
  const [it] = list.splice(i, 1);
  list.splice(j, 0, it);
  return { raw: withItems(raw, list), index: j };
}

export function addGroup(raw: VsceneRaw, name: string): VsceneRaw {
  return { ...raw, groups: [...groups(raw), name] };
}
/** Rename a group and every item that names it ("name" and "!name"). */
export function renameGroup(raw: VsceneRaw, gi: number, name: string): VsceneRaw {
  const gl = groups(raw);
  const old = gl[gi];
  if (old === undefined) return raw;
  gl[gi] = name;
  const list = rawItems(raw).map((it) => {
    if (it.group === old) return { ...it, group: name };
    if (it.group === `!${old}`) return { ...it, group: `!${name}` };
    return it;
  });
  return { ...raw, groups: gl, items: list };
}
/** Delete a group; the items that named it are drawn always again. */
export function deleteGroup(raw: VsceneRaw, gi: number): VsceneRaw {
  const gl = groups(raw);
  const old = gl[gi];
  if (old === undefined) return raw;
  gl.splice(gi, 1);
  const list = rawItems(raw).map((it) => {
    if (it.group !== old && it.group !== `!${old}`) return it;
    const next = { ...it };
    delete next.group;
    return next;
  });
  const out: VsceneRaw = { ...raw, items: list };
  if (gl.length) out.groups = gl; else delete out.groups;
  return out;
}

/** A starting scene: one item of the given mesh. */
export function newScene(name: string, mesh: string): VsceneRaw {
  return { name, items: [{ name: 'piece', mesh, at: { z: 2000 } }] };
}
