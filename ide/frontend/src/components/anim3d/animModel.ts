/**
 * Model of the 3D Animation editor: `.vskel` skeletons and `.vclip` pose/clip libraries
 * (docs/ASSETS.md). Pure functions, no imports, so `tools/anim3d-model-test.ts` runs it
 * under node.
 *
 * - Validation of both formats (what the editor flags; the compiler does not read them yet).
 * - A skeleton resolved for one variant (its meshes, offsets, extra bones, scale).
 * - Forward kinematics with the format's axes: a positive x turn swings a limb hanging
 *   down (-y) towards +z, y turns +z towards +x, z turns +x towards +y. A bone's turns
 *   compose in the order listed (the first outermost), each `joint * mul / div + add` in
 *   integer arithmetic truncating toward zero, as a C program computes it.
 * - Clips sampled between keys (straight lines: how a game eases is its own business).
 * - Edit operations that keep references whole: renaming a pose or a clip renames it
 *   wherever it is used; deleting one that is still used is refused.
 */

export type Vec3 = [number, number, number];
export type Axis = 'x' | 'y' | 'z';
/** Row-major 3x3. */
export type Mat3 = [number, number, number, number, number, number, number, number, number];

export interface TurnRaw { axis: Axis; joint?: string; mul?: number; div?: number; add?: number }
export interface BoneRaw { name: string; parent: string | null; offset: Vec3; mesh: string | null; rotate?: TurnRaw[]; [k: string]: unknown }
export interface SocketRaw { name: string; bone: string; from: Vec3; to: Vec3 }
export interface JointRaw { name: string; min?: number; max?: number; [k: string]: unknown }
export interface VariantRaw {
  scale?: number;
  meshes?: Record<string, string | null>;
  offsets?: Record<string, Vec3>;
  bones?: BoneRaw[];
  rotate?: Record<string, TurnRaw[]>;
  sockets?: SocketRaw[];
  [k: string]: unknown;
}
export interface VskelRaw {
  version: number;
  angle_unit: number;
  joints: JointRaw[];
  bones: BoneRaw[];
  sockets?: SocketRaw[];
  variants?: Record<string, VariantRaw>;
  [k: string]: unknown;
}

export type Pose = Record<string, number>;
export interface KeyRaw { frame: number; pose: string; [k: string]: unknown }
export interface MarkRaw { frame: number; name: string; value?: number; [k: string]: unknown }
export interface ClipRaw { keys: KeyRaw[]; loop?: boolean; props?: Record<string, number>; marks?: MarkRaw[]; [k: string]: unknown }
export interface SetRaw { poses?: Record<string, string>; clips?: Record<string, string>; props?: Record<string, number>; [k: string]: unknown }
export interface VclipRaw {
  version: number;
  skeleton: string;
  poses: Record<string, Pose>;
  clips: Record<string, ClipRaw>;
  sets: Record<string, SetRaw>;
  [k: string]: unknown;
}

export interface Issue {
  message: string;
  bone?: string;
  joint?: string;
  variant?: string;
  pose?: string;
  clip?: string;
  set?: string;
}

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);
const isInt = (v: unknown): v is number => typeof v === 'number' && Number.isInteger(v);
const isVec3 = (v: unknown): v is Vec3 => Array.isArray(v) && v.length === 3 && v.every(isInt);
const NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;

/** C's `/`: truncates toward zero. */
export function cdiv(a: number, b: number): number {
  const q = Math.trunc(a / b);
  return Object.is(q, -0) ? 0 : q;
}

// ── skeleton: validation ──────────────────────────────────────────────────────

export function validateVskel(raw: unknown, meshExists?: (n: string) => boolean | undefined): Issue[] {
  const out: Issue[] = [];
  if (!isObj(raw)) return [{ message: 'not a JSON object' }];
  if (raw.version !== 1) out.push({ message: 'version must be 1' });
  if (!isInt(raw.angle_unit) || (raw.angle_unit as number) <= 0) out.push({ message: 'angle_unit must be a whole number above 0 (4096 is libvpy\'s turn)' });
  const joints = Array.isArray(raw.joints) ? raw.joints : [];
  if (!Array.isArray(raw.joints)) out.push({ message: 'joints must be a list' });
  const jointNames = new Set<string>();
  joints.forEach((j, k) => {
    if (!isObj(j) || typeof j.name !== 'string' || !NAME.test(j.name)) { out.push({ message: `joint ${k}: needs a name (letters, digits, _)` }); return; }
    if (jointNames.has(j.name)) out.push({ message: `joint "${j.name}" is defined twice`, joint: j.name });
    jointNames.add(j.name);
    for (const f of ['min', 'max'] as const) if (j[f] !== undefined && !isInt(j[f])) out.push({ message: `joint "${j.name}": ${f} must be a whole number`, joint: j.name });
    if (isInt(j.min) && isInt(j.max) && (j.min as number) > (j.max as number)) out.push({ message: `joint "${j.name}": min is above max`, joint: j.name });
  });
  if (!Array.isArray(raw.bones) || !raw.bones.length) out.push({ message: 'bones must be a list with at least one bone' });
  const shared = Array.isArray(raw.bones) ? raw.bones : [];
  const known = new Set<string>();
  checkBones(shared, known, jointNames, meshExists, out, undefined);
  checkSockets(raw.sockets, known, out, undefined);
  if (raw.variants !== undefined) {
    if (!isObj(raw.variants)) out.push({ message: 'variants must be an object' });
    else for (const [name, v] of Object.entries(raw.variants)) {
      if (!isObj(v)) { out.push({ message: `variant "${name}" must be an object`, variant: name }); continue; }
      if (v.scale !== undefined && (!isInt(v.scale) || (v.scale as number) <= 0)) out.push({ message: `variant "${name}": scale must be a whole number above 0 (256 = as modelled)`, variant: name });
      const vb = new Set(known);
      if (v.bones !== undefined) {
        if (!Array.isArray(v.bones)) out.push({ message: `variant "${name}": bones must be a list`, variant: name });
        else checkBones(v.bones, vb, jointNames, meshExists, out, name);
      }
      if (v.meshes !== undefined) {
        if (!isObj(v.meshes)) out.push({ message: `variant "${name}": meshes must be an object`, variant: name });
        else for (const [b, m] of Object.entries(v.meshes)) {
          if (!vb.has(b)) out.push({ message: `variant "${name}": no bone "${b}" to give a mesh`, variant: name, bone: b });
          if (m !== null && typeof m !== 'string') out.push({ message: `variant "${name}": the mesh of "${b}" must be a name or null`, variant: name, bone: b });
          else if (typeof m === 'string' && meshExists?.(m) === false) out.push({ message: `variant "${name}": no mesh "${m}" (assets/meshes)`, variant: name, bone: b });
        }
      }
      if (v.offsets !== undefined) {
        if (!isObj(v.offsets)) out.push({ message: `variant "${name}": offsets must be an object`, variant: name });
        else for (const [b, o] of Object.entries(v.offsets)) {
          if (!vb.has(b)) out.push({ message: `variant "${name}": no bone "${b}" to move`, variant: name, bone: b });
          if (!isVec3(o)) out.push({ message: `variant "${name}": the offset of "${b}" must be three whole numbers`, variant: name, bone: b });
        }
      }
      if (v.rotate !== undefined) {
        if (!isObj(v.rotate)) out.push({ message: `variant "${name}": rotate must be an object`, variant: name });
        else for (const [b, r] of Object.entries(v.rotate)) {
          if (!vb.has(b)) out.push({ message: `variant "${name}": no bone "${b}" to turn`, variant: name, bone: b });
          checkTurns(r, jointNames, out, `variant "${name}", bone "${b}"`, { variant: name, bone: b });
        }
      }
      checkSockets(v.sockets, vb, out, name);
    }
  }
  return out;
}

function checkBones(list: unknown[], known: Set<string>, joints: Set<string>, meshExists: ((n: string) => boolean | undefined) | undefined, out: Issue[], variant: string | undefined): void {
  const where = variant ? `variant "${variant}": ` : '';
  list.forEach((b, k) => {
    if (!isObj(b) || typeof b.name !== 'string' || !NAME.test(b.name)) { out.push({ message: `${where}bone ${k}: needs a name (letters, digits, _)`, variant }); return; }
    const name = b.name;
    if (known.has(name)) out.push({ message: `${where}bone "${name}" is defined twice`, bone: name, variant });
    if (b.parent === null) {
      if (variant || known.size) out.push({ message: `${where}bone "${name}": only the first bone may be the root (parent null)`, bone: name, variant });
    } else if (typeof b.parent !== 'string' || !known.has(b.parent)) {
      out.push({ message: `${where}bone "${name}": its parent "${String(b.parent)}" must be a bone listed before it`, bone: name, variant });
    }
    if (!isVec3(b.offset)) out.push({ message: `${where}bone "${name}": offset must be three whole numbers`, bone: name, variant });
    if (b.mesh !== null && typeof b.mesh !== 'string') out.push({ message: `${where}bone "${name}": mesh must be a name or null`, bone: name, variant });
    else if (typeof b.mesh === 'string' && meshExists?.(b.mesh) === false) out.push({ message: `${where}bone "${name}": no mesh "${b.mesh}" (assets/meshes)`, bone: name, variant });
    if (b.rotate !== undefined) checkTurns(b.rotate, joints, out, `${where}bone "${name}"`, { bone: name, variant });
    known.add(name);
  });
}

function checkTurns(r: unknown, joints: Set<string>, out: Issue[], where: string, at: Partial<Issue>): void {
  if (!Array.isArray(r)) { out.push({ message: `${where}: rotate must be a list`, ...at }); return; }
  r.forEach((t, k) => {
    if (!isObj(t)) { out.push({ message: `${where}: turn ${k} must be an object`, ...at }); return; }
    if (t.axis !== 'x' && t.axis !== 'y' && t.axis !== 'z') out.push({ message: `${where}: turn ${k} needs an axis x, y or z`, ...at });
    if (t.joint !== undefined && (typeof t.joint !== 'string' || !joints.has(t.joint))) out.push({ message: `${where}: turn ${k}: no joint "${String(t.joint)}"`, ...at });
    for (const f of ['mul', 'div', 'add'] as const) if (t[f] !== undefined && !isInt(t[f])) out.push({ message: `${where}: turn ${k}: ${f} must be a whole number`, ...at });
    if (t.div === 0) out.push({ message: `${where}: turn ${k}: div cannot be 0`, ...at });
    if (t.joint === undefined && !t.add) out.push({ message: `${where}: turn ${k} has neither a joint nor an add: it does nothing`, ...at });
  });
}

function checkSockets(s: unknown, bones: Set<string>, out: Issue[], variant: string | undefined): void {
  if (s === undefined) return;
  const where = variant ? `variant "${variant}": ` : '';
  if (!Array.isArray(s)) { out.push({ message: `${where}sockets must be a list`, variant }); return; }
  const seen = new Set<string>();
  s.forEach((x, k) => {
    if (!isObj(x) || typeof x.name !== 'string' || !NAME.test(x.name)) { out.push({ message: `${where}socket ${k}: needs a name (letters, digits, _)`, variant }); return; }
    if (seen.has(x.name)) out.push({ message: `${where}socket "${x.name}" is defined twice`, variant });
    seen.add(x.name);
    if (typeof x.bone !== 'string' || !bones.has(x.bone)) out.push({ message: `${where}socket "${x.name}": no bone "${String(x.bone)}"`, variant });
    if (!isVec3(x.from) || !isVec3(x.to)) out.push({ message: `${where}socket "${x.name}": from and to must be three whole numbers each`, variant });
  });
}

// ── skeleton: a variant resolved, and posed ──────────────────────────────────

export interface ResolvedBone {
  name: string;
  parent: number;          // -1: the root
  offset: Vec3;            // already scaled, as the game computes it
  mesh: string | null;
  rotate: TurnRaw[];
}
export interface Resolved { bones: ResolvedBone[]; sockets: SocketRaw[]; scale: number; unit: number; joints: string[] }

export function variantNames(raw: VskelRaw): string[] {
  return isObj(raw.variants) ? Object.keys(raw.variants) : [];
}

/** The skeleton as `variant` (null: the shared skeleton as modelled). Assumes it validated. */
export function resolve(raw: VskelRaw, variant: string | null): Resolved {
  const v: VariantRaw = (variant && raw.variants?.[variant]) || {};
  const scale = isInt(v.scale) ? v.scale : 256;
  const list = [...raw.bones, ...(v.bones ?? [])];
  const index = new Map<string, number>();
  const bones: ResolvedBone[] = list.map((b, i) => {
    index.set(b.name, i);
    const off = v.offsets?.[b.name] ?? b.offset;
    return {
      name: b.name,
      parent: b.parent === null ? -1 : (index.get(b.parent) ?? -1),
      offset: off.map((c) => cdiv(c * scale, 256)) as Vec3,
      mesh: v.meshes && b.name in v.meshes ? v.meshes[b.name] : b.mesh,
      rotate: v.rotate?.[b.name] ?? b.rotate ?? [],
    };
  });
  return { bones, sockets: v.sockets ?? raw.sockets ?? [], scale, unit: raw.angle_unit, joints: raw.joints.map((j) => j.name) };
}

/** A turn's angle for these joint angles, in integer arithmetic as C does it. */
export function turnAngle(t: TurnRaw, angles: Pose): number {
  const a = t.joint !== undefined ? (angles[t.joint] ?? 0) : 0;
  return cdiv(a * (t.mul ?? 1), t.div ?? 1) + (t.add ?? 0);
}

export const IDENTITY: Mat3 = [1, 0, 0, 0, 1, 0, 0, 0, 1];
export function mul3(a: Mat3, b: Mat3): Mat3 {
  const r = new Array(9).fill(0) as Mat3;
  for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) r[i * 3 + j] = a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j];
  return r;
}
export function apply3(m: Mat3, v: Vec3): Vec3 {
  return [m[0] * v[0] + m[1] * v[1] + m[2] * v[2], m[3] * v[0] + m[4] * v[1] + m[5] * v[2], m[6] * v[0] + m[7] * v[1] + m[8] * v[2]];
}
/** One turn of the format: `angle` in `unit`s per turn about `axis` (see the header for the signs). */
export function axisTurn(axis: Axis, angle: number, unit: number): Mat3 {
  const th = (angle / unit) * 2 * Math.PI;
  const c = Math.cos(th), s = Math.sin(th);
  switch (axis) {
    case 'x': return [1, 0, 0, 0, c, s, 0, -s, c];        // -y towards +z (right-handed by -th)
    case 'y': return [c, 0, s, 0, 1, 0, -s, 0, c];        // +z towards +x
    default: return [c, -s, 0, s, c, 0, 0, 0, 1];         // +x towards +y
  }
}

export interface PosedBone { pos: Vec3; rot: Mat3 }
export interface Posed { bones: PosedBone[]; scale: number }

/** Every bone's joint position and frame: the skeleton at `at`, turned `yaw` (units) about y. */
export function pose(r: Resolved, angles: Pose, at: Vec3 = [0, 0, 0], yaw = 0): Posed {
  const root = axisTurn('y', yaw, r.unit);
  const out: PosedBone[] = [];
  for (const b of r.bones) {
    let local = IDENTITY;
    for (const t of b.rotate) local = mul3(local, axisTurn(t.axis, turnAngle(t, angles), r.unit));
    if (b.parent < 0) {
      const p = apply3(root, b.offset);
      out.push({ pos: [at[0] + p[0], at[1] + p[1], at[2] + p[2]], rot: mul3(root, local) });
    } else {
      const P = out[b.parent];
      const o = apply3(P.rot, b.offset);
      out.push({ pos: [P.pos[0] + o[0], P.pos[1] + o[1], P.pos[2] + o[2]], rot: mul3(P.rot, local) });
    }
  }
  return { bones: out, scale: r.scale };
}

/** A point given in a bone's own frame, in the world (the character's scale applied, as for its meshes). */
export function boneToWorld(p: Posed, bone: number, v: Vec3): Vec3 {
  const b = p.bones[bone];
  const k = p.scale / 256;
  const w = apply3(b.rot, [v[0] * k, v[1] * k, v[2] * k]);
  return [b.pos[0] + w[0], b.pos[1] + w[1], b.pos[2] + w[2]];
}

/** A pose at rest: every joint at 0. */
export function restPose(joints: string[]): Pose {
  return Object.fromEntries(joints.map((j) => [j, 0]));
}

// ── clips: validation ─────────────────────────────────────────────────────────

export function validateVclip(raw: unknown, joints?: string[]): Issue[] {
  const out: Issue[] = [];
  if (!isObj(raw)) return [{ message: 'not a JSON object' }];
  if (raw.version !== 1) out.push({ message: 'version must be 1' });
  if (typeof raw.skeleton !== 'string' || !raw.skeleton) out.push({ message: 'skeleton must name a .vskel' });
  const poses = isObj(raw.poses) ? raw.poses : {};
  if (!isObj(raw.poses)) out.push({ message: 'poses must be an object' });
  const jset = joints ? new Set(joints) : null;
  for (const [name, p] of Object.entries(poses)) {
    if (!NAME.test(name)) out.push({ message: `pose "${name}": a name is letters, digits and _`, pose: name });
    if (!isObj(p)) { out.push({ message: `pose "${name}" must be an object of joint angles`, pose: name }); continue; }
    for (const [j, a] of Object.entries(p)) {
      if (!isInt(a)) out.push({ message: `pose "${name}": ${j} must be a whole number`, pose: name, joint: j });
      if (jset && !jset.has(j)) out.push({ message: `pose "${name}": the skeleton has no joint "${j}"`, pose: name, joint: j });
    }
    if (joints) for (const j of joints) if (!(j in p)) out.push({ message: `pose "${name}" has no angle for "${j}"`, pose: name, joint: j });
  }
  const clips = isObj(raw.clips) ? raw.clips : {};
  if (!isObj(raw.clips)) out.push({ message: 'clips must be an object' });
  for (const [name, c] of Object.entries(clips)) {
    if (!NAME.test(name)) out.push({ message: `clip "${name}": a name is letters, digits and _`, clip: name });
    if (!isObj(c)) { out.push({ message: `clip "${name}" must be an object`, clip: name }); continue; }
    if (!Array.isArray(c.keys) || !c.keys.length) { out.push({ message: `clip "${name}" needs at least one key`, clip: name }); continue; }
    let last = -1;
    c.keys.forEach((k, i) => {
      if (!isObj(k)) { out.push({ message: `clip "${name}": key ${i} must be an object`, clip: name }); return; }
      if (!isInt(k.frame) || (k.frame as number) < 0) out.push({ message: `clip "${name}": key ${i}: frame must be a whole number from 0`, clip: name });
      else {
        if ((k.frame as number) <= last) out.push({ message: `clip "${name}": key ${i} (frame ${k.frame}) must come after frame ${last}`, clip: name });
        last = k.frame as number;
      }
      if (typeof k.pose !== 'string' || !(k.pose in poses)) out.push({ message: `clip "${name}": key ${i}: no pose "${String(k.pose)}"`, clip: name });
    });
    if (c.loop !== undefined && typeof c.loop !== 'boolean') out.push({ message: `clip "${name}": loop must be true or false`, clip: name });
    checkProps(c.props, out, `clip "${name}"`, { clip: name });
    if (c.marks !== undefined) {
      if (!Array.isArray(c.marks)) out.push({ message: `clip "${name}": marks must be a list`, clip: name });
      else c.marks.forEach((m, i) => {
        if (!isObj(m) || typeof m.name !== 'string' || !m.name) { out.push({ message: `clip "${name}": mark ${i} needs a name`, clip: name }); return; }
        if (!isInt(m.frame) || (m.frame as number) < 0 || (m.frame as number) > last) out.push({ message: `clip "${name}": mark "${m.name}" must fall on the clip (frame 0 to ${last})`, clip: name });
        if (m.value !== undefined && !isInt(m.value)) out.push({ message: `clip "${name}": mark "${m.name}": value must be a whole number`, clip: name });
      });
    }
  }
  const sets = isObj(raw.sets) ? raw.sets : {};
  if (!isObj(raw.sets)) out.push({ message: 'sets must be an object' });
  for (const [name, s] of Object.entries(sets)) {
    if (!isObj(s)) { out.push({ message: `set "${name}" must be an object`, set: name }); continue; }
    if (s.poses !== undefined) {
      if (!isObj(s.poses)) out.push({ message: `set "${name}": poses must be an object`, set: name });
      else for (const [role, p] of Object.entries(s.poses)) if (typeof p !== 'string' || !(p in poses)) out.push({ message: `set "${name}": ${role}: no pose "${String(p)}"`, set: name });
    }
    if (s.clips !== undefined) {
      if (!isObj(s.clips)) out.push({ message: `set "${name}": clips must be an object`, set: name });
      else for (const [role, c] of Object.entries(s.clips)) if (typeof c !== 'string' || !(c in clips)) out.push({ message: `set "${name}": ${role}: no clip "${String(c)}"`, set: name });
    }
    checkProps(s.props, out, `set "${name}"`, { set: name });
  }
  return out;
}

function checkProps(p: unknown, out: Issue[], where: string, at: Partial<Issue>): void {
  if (p === undefined) return;
  if (!isObj(p)) { out.push({ message: `${where}: props must be an object`, ...at }); return; }
  for (const [k, v] of Object.entries(p)) if (!isInt(v)) out.push({ message: `${where}: ${k} must be a whole number`, ...at });
}

// ── clips: sampling ───────────────────────────────────────────────────────────

export function clipLength(c: ClipRaw): number {
  return c.keys.length ? c.keys[c.keys.length - 1].frame : 0;
}

/** The joint angles of `clip` at frame `t` (fractional), straight between keys. */
export function sampleClip(raw: VclipRaw, clip: ClipRaw, t: number, joints: string[]): Pose {
  const keys = clip.keys;
  const get = (k: KeyRaw): Pose => raw.poses[k.pose] ?? {};
  if (!keys.length) return restPose(joints);
  const len = clipLength(clip);
  if (clip.loop && len > 0) t = ((t % len) + len) % len;
  if (t <= keys[0].frame) return { ...restPose(joints), ...get(keys[0]) };
  for (let i = 1; i < keys.length; i++) {
    if (t <= keys[i].frame) {
      const a = get(keys[i - 1]), b = get(keys[i]);
      const f = (t - keys[i - 1].frame) / (keys[i].frame - keys[i - 1].frame);
      const out: Pose = {};
      for (const j of joints) out[j] = (a[j] ?? 0) + ((b[j] ?? 0) - (a[j] ?? 0)) * f;
      return out;
    }
  }
  return { ...restPose(joints), ...get(keys[keys.length - 1]) };
}

// ── clips: edit operations (each returns a new document, or an error) ────────

export type Edit = { raw: VclipRaw } | { error: string };

/** Who uses pose `p`: clip keys and set roles, for messages. */
export function poseUsers(raw: VclipRaw, p: string): string[] {
  const out: string[] = [];
  for (const [n, c] of Object.entries(raw.clips)) if (c.keys.some((k) => k.pose === p)) out.push(`clip ${n}`);
  for (const [n, s] of Object.entries(raw.sets)) for (const [role, v] of Object.entries(s.poses ?? {})) if (v === p) out.push(`set ${n} (${role})`);
  return out;
}
export function clipUsers(raw: VclipRaw, c: string): string[] {
  const out: string[] = [];
  for (const [n, s] of Object.entries(raw.sets)) for (const [role, v] of Object.entries(s.clips ?? {})) if (v === c) out.push(`set ${n} (${role})`);
  return out;
}

export function setPoseJoint(raw: VclipRaw, p: string, joint: string, angle: number): VclipRaw {
  return { ...raw, poses: { ...raw.poses, [p]: { ...raw.poses[p], [joint]: Math.round(angle) } } };
}

export function addPose(raw: VclipRaw, name: string, from: Pose): Edit {
  if (!NAME.test(name)) return { error: `"${name}": a name is letters, digits and _` };
  if (name in raw.poses) return { error: `there is a pose "${name}" already` };
  return { raw: { ...raw, poses: { ...raw.poses, [name]: { ...from } } } };
}

export function renamePose(raw: VclipRaw, from: string, to: string): Edit {
  if (from === to) return { raw };
  if (!NAME.test(to)) return { error: `"${to}": a name is letters, digits and _` };
  if (to in raw.poses) return { error: `there is a pose "${to}" already` };
  const poses: Record<string, Pose> = {};
  for (const [n, p] of Object.entries(raw.poses)) poses[n === from ? to : n] = p;   // keeps the order
  const clips: Record<string, ClipRaw> = {};
  for (const [n, c] of Object.entries(raw.clips)) clips[n] = { ...c, keys: c.keys.map((k) => (k.pose === from ? { ...k, pose: to } : k)) };
  const sets: Record<string, SetRaw> = {};
  for (const [n, s] of Object.entries(raw.sets)) {
    sets[n] = s.poses ? { ...s, poses: Object.fromEntries(Object.entries(s.poses).map(([r, v]) => [r, v === from ? to : v])) } : s;
  }
  return { raw: { ...raw, poses, clips, sets } };
}

export function deletePose(raw: VclipRaw, p: string): Edit {
  const users = poseUsers(raw, p);
  if (users.length) return { error: `"${p}" is used by ${users.slice(0, 4).join(', ')}${users.length > 4 ? '…' : ''}` };
  const poses = { ...raw.poses };
  delete poses[p];
  return { raw: { ...raw, poses } };
}

export function addClip(raw: VclipRaw, name: string, pose: string): Edit {
  if (!NAME.test(name)) return { error: `"${name}": a name is letters, digits and _` };
  if (name in raw.clips) return { error: `there is a clip "${name}" already` };
  if (!(pose in raw.poses)) return { error: 'a clip starts from a pose: add one first' };
  return { raw: { ...raw, clips: { ...raw.clips, [name]: { keys: [{ frame: 0, pose }, { frame: 10, pose }], loop: false } } } };
}

export function renameClip(raw: VclipRaw, from: string, to: string): Edit {
  if (from === to) return { raw };
  if (!NAME.test(to)) return { error: `"${to}": a name is letters, digits and _` };
  if (to in raw.clips) return { error: `there is a clip "${to}" already` };
  const clips: Record<string, ClipRaw> = {};
  for (const [n, c] of Object.entries(raw.clips)) clips[n === from ? to : n] = c;
  const sets: Record<string, SetRaw> = {};
  for (const [n, s] of Object.entries(raw.sets)) {
    sets[n] = s.clips ? { ...s, clips: Object.fromEntries(Object.entries(s.clips).map(([r, v]) => [r, v === from ? to : v])) } : s;
  }
  return { raw: { ...raw, clips, sets } };
}

export function deleteClip(raw: VclipRaw, c: string): Edit {
  const users = clipUsers(raw, c);
  if (users.length) return { error: `"${c}" is used by ${users.slice(0, 4).join(', ')}${users.length > 4 ? '…' : ''}` };
  const clips = { ...raw.clips };
  delete clips[c];
  return { raw: { ...raw, clips } };
}

export function setClip(raw: VclipRaw, name: string, clip: ClipRaw): VclipRaw {
  return { ...raw, clips: { ...raw.clips, [name]: clip } };
}

/** Move key `i` to `frame`, keeping the keys in order (refused if it would pass a neighbour). */
export function moveKey(clip: ClipRaw, i: number, frame: number): ClipRaw | { error: string } {
  frame = Math.round(frame);
  const prev = i > 0 ? clip.keys[i - 1].frame : -1;
  const next = i < clip.keys.length - 1 ? clip.keys[i + 1].frame : Infinity;
  if (frame <= prev || frame >= next || frame < 0) return { error: `key ${i} must stay between frame ${prev + 1} and ${next === Infinity ? '…' : next - 1}` };
  const delta = frame - clip.keys[i].frame;
  const keys = clip.keys.map((k, j) => (j === i ? { ...k, frame } : k));
  // marks on the last stretch keep their place relative to the end when the last key moves
  const marks = clip.marks?.map((m) => (i === clip.keys.length - 1 && m.frame > prev && m.frame >= clip.keys[i].frame ? { ...m, frame: m.frame + delta } : m));
  return { ...clip, keys, ...(marks ? { marks } : {}) };
}

/** A key at `frame` with `pose`, in order (replaces one already there). */
export function putKey(clip: ClipRaw, frame: number, pose: string): ClipRaw {
  frame = Math.max(0, Math.round(frame));
  const keys = clip.keys.filter((k) => k.frame !== frame).concat([{ frame, pose }]).sort((a, b) => a.frame - b.frame);
  return { ...clip, keys };
}

export function deleteKey(clip: ClipRaw, i: number): ClipRaw | { error: string } {
  if (clip.keys.length <= 1) return { error: 'a clip keeps at least one key' };
  const keys = clip.keys.filter((_, j) => j !== i);
  const len = keys[keys.length - 1].frame;
  const marks = clip.marks?.filter((m) => m.frame <= len);
  return { ...clip, keys, ...(marks ? { marks } : {}) };
}

// ── skeleton: edit operations ────────────────────────────────────────────────

export type SkelEdit = { raw: VskelRaw } | { error: string };

const mapTurns = (ts: TurnRaw[] | undefined, f: (t: TurnRaw) => TurnRaw) => (ts ? ts.map(f) : ts);
function mapVariants(raw: VskelRaw, f: (v: VariantRaw) => VariantRaw): Record<string, VariantRaw> | undefined {
  return raw.variants ? Object.fromEntries(Object.entries(raw.variants).map(([n, v]) => [n, f(v)])) : raw.variants;
}
const renameKeys = <T,>(o: Record<string, T> | undefined, from: string, to: string) =>
  (o ? Object.fromEntries(Object.entries(o).map(([k, v]) => [k === from ? to : k, v])) : o);

/** Every bone name, the variants' extra bones included. */
export function allBoneNames(raw: VskelRaw): Set<string> {
  const s = new Set(raw.bones.map((b) => b.name));
  for (const v of Object.values(raw.variants ?? {})) for (const b of v.bones ?? []) s.add(b.name);
  return s;
}

export function renameBone(raw: VskelRaw, from: string, to: string): SkelEdit {
  if (from === to) return { raw };
  if (!NAME.test(to)) return { error: `"${to}": a name is letters, digits and _` };
  if (allBoneNames(raw).has(to)) return { error: `there is a bone "${to}" already` };
  const fix = (b: BoneRaw): BoneRaw => ({ ...b, name: b.name === from ? to : b.name, parent: b.parent === from ? to : b.parent });
  const sock = (s: SocketRaw[] | undefined) => s?.map((x) => (x.bone === from ? { ...x, bone: to } : x));
  return {
    raw: {
      ...raw,
      bones: raw.bones.map(fix),
      ...(raw.sockets ? { sockets: sock(raw.sockets) } : {}),
      variants: mapVariants(raw, (v) => ({
        ...v,
        ...(v.bones ? { bones: v.bones.map(fix) } : {}),
        ...(v.meshes ? { meshes: renameKeys(v.meshes, from, to) } : {}),
        ...(v.offsets ? { offsets: renameKeys(v.offsets, from, to) } : {}),
        ...(v.rotate ? { rotate: renameKeys(v.rotate, from, to) } : {}),
        ...(v.sockets ? { sockets: sock(v.sockets) } : {}),
      })),
    },
  };
}

/** Bones that hang from `name`, sockets on it, variants that name it. */
export function boneUsers(raw: VskelRaw, name: string): string[] {
  const out: string[] = [];
  for (const b of raw.bones) if (b.parent === name) out.push(`bone ${b.name}`);
  for (const s of raw.sockets ?? []) if (s.bone === name) out.push(`socket ${s.name}`);
  for (const [vn, v] of Object.entries(raw.variants ?? {})) {
    for (const b of v.bones ?? []) if (b.parent === name) out.push(`variant ${vn} (bone ${b.name})`);
    if ((v.meshes && name in v.meshes) || (v.offsets && name in v.offsets) || (v.rotate && name in v.rotate) || v.sockets?.some((s) => s.bone === name)) out.push(`variant ${vn}`);
  }
  return out;
}

export function deleteBone(raw: VskelRaw, name: string): SkelEdit {
  const i = raw.bones.findIndex((b) => b.name === name);
  if (i < 0) return { error: `no shared bone "${name}"` };
  if (i === 0) return { error: 'the root bone stays (the others hang from it)' };
  const users = boneUsers(raw, name);
  if (users.length) return { error: `"${name}" is used by ${users.slice(0, 4).join(', ')}${users.length > 4 ? '…' : ''}` };
  return { raw: { ...raw, bones: raw.bones.filter((_, j) => j !== i) } };
}

export function renameJoint(raw: VskelRaw, from: string, to: string): SkelEdit {
  if (from === to) return { raw };
  if (!NAME.test(to)) return { error: `"${to}": a name is letters, digits and _` };
  if (raw.joints.some((j) => j.name === to)) return { error: `there is a joint "${to}" already` };
  const t = (x: TurnRaw): TurnRaw => (x.joint === from ? { ...x, joint: to } : x);
  const fix = (b: BoneRaw): BoneRaw => ({ ...b, ...(b.rotate ? { rotate: mapTurns(b.rotate, t) } : {}) });
  return {
    raw: {
      ...raw,
      joints: raw.joints.map((j) => (j.name === from ? { ...j, name: to } : j)),
      bones: raw.bones.map(fix),
      variants: mapVariants(raw, (v) => ({
        ...v,
        ...(v.bones ? { bones: v.bones.map(fix) } : {}),
        ...(v.rotate ? { rotate: Object.fromEntries(Object.entries(v.rotate).map(([k, ts]) => [k, ts.map(t)])) } : {}),
      })),
    },
  };
}

/** Bones (shared or a variant's) turned by `joint`. */
export function jointUsers(raw: VskelRaw, joint: string): string[] {
  const out: string[] = [];
  for (const b of raw.bones) if (b.rotate?.some((t) => t.joint === joint)) out.push(`bone ${b.name}`);
  for (const [vn, v] of Object.entries(raw.variants ?? {})) {
    for (const b of v.bones ?? []) if (b.rotate?.some((t) => t.joint === joint)) out.push(`variant ${vn} (bone ${b.name})`);
    for (const [bn, ts] of Object.entries(v.rotate ?? {})) if (ts.some((t) => t.joint === joint)) out.push(`variant ${vn} (bone ${bn})`);
  }
  return out;
}

export function deleteJoint(raw: VskelRaw, joint: string): SkelEdit {
  const users = jointUsers(raw, joint);
  if (users.length) return { error: `"${joint}" turns ${users.slice(0, 4).join(', ')}${users.length > 4 ? '…' : ''}` };
  return { raw: { ...raw, joints: raw.joints.filter((j) => j.name !== joint) } };
}

/** A fresh name: `base`, `base_2`, … not in `taken`. */
export function freshName(base: string, taken: Iterable<string>): string {
  const s = new Set(taken);
  if (!s.has(base)) return base;
  for (let k = 2; ; k++) if (!s.has(`${base}_${k}`)) return `${base}_${k}`;
}

/** A new, empty library for `skeleton`, with one rest pose. */
export function newVclip(skeleton: string, joints: string[]): VclipRaw {
  return { version: 1, skeleton, poses: { rest: restPose(joints) }, clips: {}, sets: {} };
}

/** A new skeleton: one bone, no joints. */
export function newVskel(): VskelRaw {
  return { version: 1, angle_unit: 4096, joints: [], bones: [{ name: 'root', parent: null, offset: [0, 0, 0], mesh: null, rotate: [] }], variants: {} };
}

/** Degrees ↔ the file's angle units. */
export const toDeg = (a: number, unit: number) => (a * 360) / unit;
export const fromDeg = (d: number, unit: number) => Math.round((d * unit) / 360);
