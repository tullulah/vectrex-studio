/**
 * View math shared by the 3D-capable asset editors (VectorEditor for `.vec` with
 * `z`, MeshEditor for `.vmesh`).
 *
 * Views:
 *   xy — front: x right, y up, looking along +z (vpy3d's default camera sits at
 *        -z looking at the origin, so this is what a game sees first)
 *   xz — top:   x right, z up
 *   yz — side:  y right, z up
 *   3d — orthographic orbit: yaw about Y, then pitch about X
 *
 * `projectView` returns screen-space x/y (y up) and `depth`, the distance INTO
 * the screen: a bigger depth is farther from the viewer. For every view the
 * mapping is a rotation, so `viewForward` (the model-space direction the viewer
 * looks along) is simply the depth of the unit axes.
 */

export type ViewMode = 'xy' | 'xz' | 'yz' | '3d';

export interface Rotation3D {
  /** Degrees, clamped to [-89, 89]. */
  pitch: number;
  /** Degrees, wrapped to (-360, 360). */
  yaw: number;
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
 * The orbit gesture both editors use (middle button + Shift, or the pan tool in
 * the 3D view): half a degree per pixel, pitch clamped so the view never flips.
 */
export function orbitRotation(rot: Rotation3D, dx: number, dy: number): Rotation3D {
  return {
    pitch: Math.max(-89, Math.min(89, rot.pitch - dy * 0.5)),
    yaw: (rot.yaw + dx * 0.5) % 360,
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
