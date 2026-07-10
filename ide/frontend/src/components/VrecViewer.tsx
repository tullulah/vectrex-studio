/**
 * VrecViewer — read-only playback panel for .vrec vector recordings.
 *
 * A .vrec file (recorded by the emulator's vector recorder, see
 * emulator/recorder/VectorRecorder.ts) contains per-frame vector segment
 * lists in Vectrex space:
 *   { version, name, fps, frames: [ { segments: [ {x0,y0,x1,y1,i}, ... ] }, ... ] }
 * Coordinates are integers in -127..127 (Y up positive, origin = screen
 * centre); intensity `i` is 0-127.
 *
 * The viewer renders each frame on a dark phosphor-style canvas (matching
 * the emulator display look) and provides simple transport controls:
 * play/pause looping at the file's fps, plus a frame scrubber.
 */

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';

// ---------------------------------------------------------------------------
// Types + validation
// ---------------------------------------------------------------------------

interface VrecSegment { x0: number; y0: number; x1: number; y1: number; i: number }
interface VrecFrame   { segments: VrecSegment[] }
interface VrecData    { version: string; name: string; fps: number; frames: VrecFrame[] }

/**
 * Validate and normalise a parsed .vrec resource.
 * Returns null when the structure is unusable (caller shows an error message).
 * Tolerant of minor issues: non-numeric fields default to 0, missing segment
 * arrays become empty frames.
 */
function normalizeVrec(resource: any): VrecData | null {
  if (!resource || typeof resource !== 'object') return null;
  if (!Array.isArray(resource.frames)) return null;

  const num = (v: any): number => (typeof v === 'number' && Number.isFinite(v) ? v : 0);

  const frames: VrecFrame[] = resource.frames.map((f: any): VrecFrame => {
    const segs = Array.isArray(f?.segments) ? f.segments : [];
    return {
      segments: segs
        .filter((s: any) => s && typeof s === 'object')
        .map((s: any): VrecSegment => ({
          x0: num(s.x0), y0: num(s.y0), x1: num(s.x1), y1: num(s.y1), i: num(s.i),
        })),
    };
  });

  const fps = num(resource.fps);
  return {
    version: typeof resource.version === 'string' ? resource.version : '1.0',
    name:    typeof resource.name === 'string' ? resource.name : 'recording',
    fps:     fps > 0 && fps <= 120 ? fps : 15,
    frames,
  };
}

// ---------------------------------------------------------------------------
// Canvas rendering
// ---------------------------------------------------------------------------

// Internal canvas resolution — 2× the emulator's 330×410 (Vectrex 3:4-ish
// portrait aspect) for crisp lines when CSS-scaled.
const CANVAS_W = 660;
const CANVAS_H = 820;

/**
 * Draw one frame in the Vectrex phosphor style: black background, segments
 * as pale green-white lines whose brightness/alpha follows intensity, with
 * a soft glow. Vectrex space (-127..127, Y up) maps to the canvas centred
 * and isotropically scaled so the ±127 box fits the width.
 */
function drawFrame(canvas: HTMLCanvasElement, frame: VrecFrame | undefined): void {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  // Background
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.shadowBlur = 0;
  ctx.fillStyle = '#000000';
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  const cx = CANVAS_W / 2;
  const cy = CANVAS_H / 2;
  const pad = 20;
  // Isotropic scale: fit the -127..127 box within the narrower axis (width)
  const scale = (Math.min(CANVAS_W, CANVAS_H) / 2 - pad) / 127;

  // Faint outline of the ±127 coordinate box for reference
  ctx.strokeStyle = 'rgba(80, 120, 80, 0.25)';
  ctx.lineWidth = 1;
  ctx.strokeRect(cx - 127 * scale, cy - 127 * scale, 254 * scale, 254 * scale);

  if (!frame) return;

  const toX = (x: number) => cx + x * scale;
  const toY = (y: number) => cy - y * scale; // Y up → canvas Y down

  for (const s of frame.segments) {
    const alpha = Math.min(127, Math.max(0, s.i)) / 127;
    if (alpha <= 0) continue;

    ctx.strokeStyle = `rgba(160, 255, 190, ${(0.25 + 0.75 * alpha).toFixed(3)})`;
    ctx.lineWidth = 2;
    ctx.shadowColor = 'rgba(80, 255, 140, 0.8)';
    ctx.shadowBlur = 4 + 6 * alpha;

    ctx.beginPath();
    if (s.x0 === s.x1 && s.y0 === s.y1) {
      // Zero-length segment = dot
      ctx.moveTo(toX(s.x0) - 0.5, toY(s.y0));
      ctx.lineTo(toX(s.x0) + 0.5, toY(s.y0));
    } else {
      ctx.moveTo(toX(s.x0), toY(s.y0));
      ctx.lineTo(toX(s.x1), toY(s.y1));
    }
    ctx.stroke();
  }
  ctx.shadowBlur = 0;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

interface VrecViewerProps {
  /** Parsed .vrec JSON (undefined when the file couldn't be parsed). */
  resource?: any;
}

export const VrecViewer: React.FC<VrecViewerProps> = ({ resource }) => {
  const data = useMemo(() => normalizeVrec(resource), [resource]);

  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [frameIdx, setFrameIdx] = useState(0);
  const [playing, setPlaying] = useState(false);

  const frameCount = data?.frames.length ?? 0;

  // Reset transport when a different recording is loaded
  useEffect(() => {
    setFrameIdx(0);
    setPlaying(frameCount > 1); // autoplay multi-frame recordings
  }, [data, frameCount]);

  // Playback loop at the file's fps (loops back to frame 0)
  useEffect(() => {
    if (!playing || !data || frameCount <= 1) return;
    const timer = window.setInterval(() => {
      setFrameIdx(prev => (prev + 1) % frameCount);
    }, 1000 / data.fps);
    return () => window.clearInterval(timer);
  }, [playing, data, frameCount]);

  // Render the current frame
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !data) return;
    drawFrame(canvas, data.frames[Math.min(frameIdx, frameCount - 1)]);
  }, [data, frameIdx, frameCount]);

  const onScrub = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setPlaying(false);
    setFrameIdx(Number(e.target.value) | 0);
  }, []);

  // ── Error / empty states ────────────────────────────────────────────────
  if (!data) {
    return (
      <div style={msgBoxStyle}>
        <span style={{ fontSize: 28 }}>📼</span>
        <span>Invalid .vrec file — could not parse the recording.</span>
        <span style={{ color: '#777', fontSize: 11 }}>
          Expected JSON with {'{ version, name, fps, frames: [{ segments: [...] }] }'}
        </span>
      </div>
    );
  }
  if (frameCount === 0) {
    return (
      <div style={msgBoxStyle}>
        <span style={{ fontSize: 28 }}>📼</span>
        <span>This recording contains no frames.</span>
      </div>
    );
  }

  const currentSegments = data.frames[Math.min(frameIdx, frameCount - 1)]?.segments.length ?? 0;

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      height: '100%',
      padding: 12,
      boxSizing: 'border-box',
      fontFamily: 'monospace',
      fontSize: 12,
      color: '#ccc',
      overflow: 'auto',
    }}>
      {/* Header: recording metadata */}
      <div style={{ display: 'flex', gap: 16, alignItems: 'baseline', marginBottom: 8 }}>
        <span style={{ color: '#8f8', fontWeight: 'bold', fontSize: 14 }}>📼 {data.name}</span>
        <span style={{ color: '#888' }}>{data.fps} fps</span>
        <span style={{ color: '#888' }}>{frameCount} frames ({(frameCount / data.fps).toFixed(1)} s)</span>
        <span style={{ color: '#888' }}>{currentSegments} segments in frame</span>
      </div>

      {/* Playback canvas */}
      <canvas
        ref={canvasRef}
        width={CANVAS_W}
        height={CANVAS_H}
        style={{
          border: '1px solid #333',
          background: '#000',
          width: 330,
          height: 410,
          flexShrink: 0,
        }}
      />

      {/* Transport controls */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        marginTop: 10,
        width: 380,
        maxWidth: '100%',
      }}>
        <button
          onClick={() => setPlaying(p => !p)}
          title={playing ? 'Pause playback' : 'Play (loops)'}
          style={{
            background: playing ? '#4a2a2a' : '#2a4a2a',
            color: playing ? '#faa' : '#afa',
            border: '1px solid #444',
            borderRadius: 4,
            padding: '6px 10px',
            fontSize: 16,
            cursor: 'pointer',
            minWidth: 42,
          }}
        >
          {playing ? '⏸' : '▶'}
        </button>

        <input
          type="range"
          min={0}
          max={frameCount - 1}
          step={1}
          value={Math.min(frameIdx, frameCount - 1)}
          onChange={onScrub}
          style={{ flex: 1 }}
          title="Scrub frames"
        />

        <span style={{ color: '#aaa', minWidth: 64, textAlign: 'right' }}>
          {Math.min(frameIdx, frameCount - 1) + 1}/{frameCount}
        </span>
      </div>
    </div>
  );
};

const msgBoxStyle: React.CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  gap: 8,
  height: '100%',
  color: '#bbb',
  fontFamily: 'monospace',
  fontSize: 13,
};

export default VrecViewer;
