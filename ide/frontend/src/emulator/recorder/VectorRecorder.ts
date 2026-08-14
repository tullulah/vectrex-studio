/**
 * VectorRecorder — captures per-frame vector segment lists from the running
 * emulator and packages them as a .vrec asset (JSON) for game-preview
 * playback (menu attract mode).
 *
 * .vrec format (contract shared with the compiler side):
 *   {
 *     "version": "1.0",
 *     "name": "snowbros_preview",
 *     "fps": 15,
 *     "frames": [ { "segments": [ { "x0": -50, "y0": 10, "x1": 30, "y1": 20, "i": 95 }, ... ] }, ... ]
 *   }
 *
 * Coordinates are in Vectrex space: integers clamped to -127..127, Y up
 * positive, (0,0) = screen centre.  Intensity `i` is 0-127.
 *
 * Capture model:
 *   All emulator backends (legacy JSVecX 6809, VectrexSystem, Rp2350System)
 *   produce their per-frame draw lists in the same ALG integrator space
 *   (x 0..33000, y 0..41000, Y down).  The recorder samples the current
 *   completed frame at CAPTURE_FPS via its own interval timer — this
 *   downsamples the 50 Hz emulation to ~15 fps with zero overhead on the
 *   emulator's own frame loop (nothing runs when not recording).
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** One captured segment in Vectrex space (-127..127, Y up, i 0-127). */
export interface VrecSegment {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
  i: number;
}

/** One captured frame. */
export interface VrecFrame {
  segments: VrecSegment[];
}

/** The full .vrec file contents. */
export interface VrecFile {
  version: '1.0';
  name: string;
  fps: number;
  frames: VrecFrame[];
}

/**
 * Raw segment as produced by the emulator draw lists (ALG space).
 * Matches the shape of Segment (emulatorCore.ts) and vector_t (vecx_full.js,
 * with `color` mapped to `intensity` by the caller).
 */
export interface RawSegment {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
  intensity: number;
}

// ---------------------------------------------------------------------------
// Coordinate conversion — ALG integrator space → Vectrex space
// ---------------------------------------------------------------------------
//
// ALG space (shared by Beam.ts, vecx_full.js and Rp2350System's direct-inject
// path): x ∈ [0, 33000), y ∈ [0, 41000), Y down, centre = (16500, 20500).
//
// The standard drawing scale is 127 ALG units per Vectrex coordinate unit:
// the BIOS scale factor $7F (= T1 latch 127 ticks) and the ARM path's
// ARM_ALG_SCALE both map a delta of ±127 to ±16129 ALG units (≈ half the
// screen width).  Inverting that transform recovers the -127..127 Vectrex
// coordinates the game itself drew with.

const ALG_CENTER_X = 16500; // ALG_MAX_X / 2
const ALG_CENTER_Y = 20500; // ALG_MAX_Y / 2
const ALG_UNITS_PER_COORD = 127;

/** Capture rate written to the .vrec `fps` field. */
export const CAPTURE_FPS = 15;
/** Safety cap on recording length (seconds). This is NOT the normal stop —
 *  recordings are variable-length: you stop when you want with the record
 *  toggle. It's only a runaway/OOM guard. (Firmware preview buffer is 128 KB ≈
 *  ~25 s of dense content; longer previews truncate on real hardware.) */
export const MAX_RECORD_SECONDS = 60;
const MAX_FRAMES = CAPTURE_FPS * MAX_RECORD_SECONDS; // 900

function clampCoord(v: number): number {
  const r = Math.round(v);
  return r < -127 ? -127 : r > 127 ? 127 : r;
}

/**
 * Convert one frame's raw ALG-space segments to Vectrex space.
 * Segments with intensity <= 0 (invisible moves) are filtered out.
 * Intensity is clamped to 0-127 (legacy JSVecX marks redrawn erase-list
 * entries with color = 128, which is still a visible line).
 */
export function convertFrame(raw: readonly RawSegment[]): VrecSegment[] {
  const out: VrecSegment[] = [];
  for (const s of raw) {
    if (!s || s.intensity <= 0) continue; // only visible segments are stored
    out.push({
      x0: clampCoord((s.x0 - ALG_CENTER_X) / ALG_UNITS_PER_COORD),
      y0: clampCoord((ALG_CENTER_Y - s.y0) / ALG_UNITS_PER_COORD), // Y up positive
      x1: clampCoord((s.x1 - ALG_CENTER_X) / ALG_UNITS_PER_COORD),
      y1: clampCoord((ALG_CENTER_Y - s.y1) / ALG_UNITS_PER_COORD),
      i:  Math.min(127, Math.max(0, Math.round(s.intensity))),
    });
  }
  return out;
}

// ---------------------------------------------------------------------------
// VectorRecorder
// ---------------------------------------------------------------------------

export class VectorRecorder {
  private frames: VrecFrame[] = [];
  private timer: number | null = null;
  private recording = false;

  /** Fired when the MAX_RECORD_SECONDS cap auto-stops the capture. */
  onAutoStop: (() => void) | null = null;
  /** Fired on every capture tick (for the UI elapsed-time indicator). */
  onTick: ((elapsedSeconds: number, frameCount: number) => void) | null = null;

  get isRecording(): boolean { return this.recording; }
  get frameCount(): number   { return this.frames.length; }
  get elapsedSeconds(): number { return this.frames.length / CAPTURE_FPS; }

  /**
   * Begin capturing.  `getSegments` is sampled at CAPTURE_FPS and must return
   * the most recent completed frame's draw list in ALG space (or null when
   * no frame is available — an empty frame is recorded in that case).
   */
  start(getSegments: () => readonly RawSegment[] | null): void {
    if (this.recording) return;
    this.frames    = [];
    this.recording = true;

    this.timer = window.setInterval(() => {
      let raw: readonly RawSegment[] | null = null;
      try { raw = getSegments(); } catch { raw = null; }
      this.frames.push({ segments: raw ? convertFrame(raw) : [] });
      this.onTick?.(this.elapsedSeconds, this.frames.length);
      if (this.frames.length >= MAX_FRAMES) {
        this.stopCapture();
        this.onAutoStop?.();
      }
    }, 1000 / CAPTURE_FPS);
  }

  /** Stop capturing and return the finished .vrec contents. */
  stop(name: string): VrecFile {
    this.stopCapture();
    return { version: '1.0', name, fps: CAPTURE_FPS, frames: this.frames };
  }

  /** Stop capturing and throw away the frames (user cancelled the save). */
  discard(): void {
    this.stopCapture();
    this.frames = [];
  }

  private stopCapture(): void {
    if (this.timer !== null) {
      window.clearInterval(this.timer);
      this.timer = null;
    }
    this.recording = false;
  }
}

/**
 * Serialise a VrecFile to JSON: readable header fields, one line per frame
 * (compact segments) so 150-frame files stay reasonably sized and diffable.
 */
export function serializeVrec(vrec: VrecFile): string {
  const frameLines = vrec.frames
    .map(f => '    ' + JSON.stringify(f))
    .join(',\n');
  return `{
  "version": "${vrec.version}",
  "name": ${JSON.stringify(vrec.name)},
  "fps": ${vrec.fps},
  "frames": [
${frameLines}
  ]
}
`;
}

/** Derive a default recording name: recording_YYYYMMDD_HHMMSS. */
export function defaultRecordingName(now: Date = new Date()): string {
  const p = (n: number, w = 2) => String(n).padStart(w, '0');
  return `recording_${now.getFullYear()}${p(now.getMonth() + 1)}${p(now.getDate())}` +
         `_${p(now.getHours())}${p(now.getMinutes())}${p(now.getSeconds())}`;
}
