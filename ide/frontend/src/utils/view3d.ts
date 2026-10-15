/**
 * View math shared by the 3D-capable asset editors (VectorEditor for `.vec` with
 * `z`, MeshEditor for `.vmesh`).
 *
 * Views:
 *   xy — front: x right, y up, looking along +z (vpy3d's default camera sits at
 *        -z looking at the origin, so this is what a game sees first)
 *   xz — top:   x right, z up
 *   yz — side:  y right, z up
 *   3d — orthographic orbit: yaw about Y, then pitch about X; once orbited by hand
 *        it is a free rotation (`m`), turned about the SCREEN's axes, so every side
 *        of a model can be reached (a turntable stopped at the poles)
 *
 * `projectView` returns screen-space x/y (y up) and `depth`, the distance INTO
 * the screen: a bigger depth is farther from the viewer. For every view the
 * mapping is a rotation, so `viewForward` (the model-space direction the viewer
 * looks along) is simply the depth of the unit axes.
 */

export type ViewMode = 'xy' | 'xz' | 'yz' | '3d';

export interface Rotation3D {
  /** Degrees, clamped to [-89, 89]. With `m`, an approximation of it (no roll). */
  pitch: number;
  /** Degrees, wrapped to (-360, 360). With `m`, an approximation of it. */
  yaw: number;
  /**
   * The free orbit: the view's rotation as three rows (screen right, screen up, into the
   * screen) in model space, 9 numbers. When present it rules; a preset view drops it.
   */
  m?: number[];
}

/** The rotation a pitch/yaw pair stands for, as rows (right, up, depth). */
function matOf(rot: Rotation3D): number[] {
  const p = (rot.pitch * Math.PI) / 180, y = (rot.yaw * Math.PI) / 180;
  const cp = Math.cos(p), sp = Math.sin(p), cy = Math.cos(y), sy = Math.sin(y);
  return [cy, 0, -sy, -sp * sy, cp, -sp * cy, cp * sy, sp, cp * cy];
}

export interface Projected {
  x: number;
  y: number;
  /** Into the screen; bigger = farther away. */
  depth: number;
}

export const DEFAULT_ROTATION_3D: Rotation3D = { pitch: 30, yaw: 45 };

export function projectView(
  x: number, y: number, z: number,
  mode: ViewMode, rot: Rotation3D,
): Projected {
  switch (mode) {
    case 'xy': return { x, y, depth: z };
    case 'xz': return { x, y: z, depth: -y };
    case 'yz': return { x: y, y: z, depth: x };
    default: {
      if (rot.m) {
        const m = rot.m;
        return { x: m[0] * x + m[1] * y + m[2] * z, y: m[3] * x + m[4] * y + m[5] * z, depth: m[6] * x + m[7] * y + m[8] * z };
      }
      const pitch = (rot.pitch * Math.PI) / 180;
      const yaw = (rot.yaw * Math.PI) / 180;
      // Rotate around Y (yaw), then around X (pitch).
      const x1 = x * Math.cos(yaw) - z * Math.sin(yaw);
      const z1 = x * Math.sin(yaw) + z * Math.cos(yaw);
      const y2 = y * Math.cos(pitch) - z1 * Math.sin(pitch);
      const z2 = y * Math.sin(pitch) + z1 * Math.cos(pitch);
      return { x: x1, y: y2, depth: z2 };
    }
  }
}

/** The model-space unit vector the viewer looks along (into the screen). */
export function viewForward(mode: ViewMode, rot: Rotation3D): [number, number, number] {
  return [
    projectView(1, 0, 0, mode, rot).depth,
    projectView(0, 1, 0, mode, rot).depth,
    projectView(0, 0, 1, mode, rot).depth,
  ];
}

/**
 * The orbit gesture the editors use (middle button + Shift, the right button, or the
 * pan tool in the 3D view): half a degree per pixel, turning the view about the
 * SCREEN's axes — a horizontal drag about the screen's vertical, a vertical drag about
 * its horizontal — from wherever it is. Free: over the top and under the bottom too,
 * where the old turntable (pitch clamped to ±89°) stopped.
 */
export function orbitRotation(rot: Rotation3D, dx: number, dy: number): Rotation3D {
  const a = (dx * 0.5 * Math.PI) / 180;        // about the screen's vertical (as yaw did)
  const b = (-dy * 0.5 * Math.PI) / 180;       // about its horizontal (as pitch did)
  const ca = Math.cos(a), sa = Math.sin(a), cb = Math.cos(b), sb = Math.sin(b);
  // R = Rx(b) * Ry(a), in the view's own frame (rows right, up, depth)
  const R = [ca, 0, -sa, -sb * sa, cb, -sb * ca, cb * sa, sb, cb * ca];
  const M = rot.m ?? matOf(rot);
  const m = new Array<number>(9);
  for (let i = 0; i < 3; i++)
    for (let j = 0; j < 3; j++)
      m[i * 3 + j] = R[i * 3] * M[j] + R[i * 3 + 1] * M[3 + j] + R[i * 3 + 2] * M[6 + j];
  // keep it a rotation: Gram-Schmidt on the rows, the third the cross of the first two
  const norm = (v: number[]) => { const l = Math.hypot(v[0], v[1], v[2]) || 1; return v.map((c) => c / l); };
  const r0 = norm(m.slice(0, 3));
  let r1 = m.slice(3, 6);
  const d = r0[0] * r1[0] + r0[1] * r1[1] + r0[2] * r1[2];
  r1 = norm([r1[0] - d * r0[0], r1[1] - d * r0[1], r1[2] - d * r0[2]]);
  const r2 = [r0[1] * r1[2] - r0[2] * r1[1], r0[2] * r1[0] - r0[0] * r1[2], r0[0] * r1[1] - r0[1] * r1[0]];
  const mm = [...r0, ...r1, ...r2];
  return {
    pitch: (Math.asin(Math.max(-1, Math.min(1, mm[7]))) * 180) / Math.PI,
    yaw: (Math.atan2(mm[6], mm[8]) * 180) / Math.PI,
    m: mm,
  };
}

/**
 * Which model axis each screen axis edits in an orthographic view, or null in
 * the 3D view (where a screen point has no single model point). The third axis
 * is the one the view looks along.
 */
export function planeAxes(mode: ViewMode): { h: 'x' | 'y' | 'z'; v: 'x' | 'y' | 'z'; depth: 'x' | 'y' | 'z' } | null {
  switch (mode) {
    case 'xy': return { h: 'x', v: 'y', depth: 'z' };
    case 'xz': return { h: 'x', v: 'z', depth: 'y' };
    case 'yz': return { h: 'y', v: 'z', depth: 'x' };
    default: return null;
  }
}
