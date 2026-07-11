/**
 * VectorMovieEditor — visual editor + synced player for ".vmov" vector movies.
 *
 * A vector movie is a small JSON manifest tying together:
 *   - a vectorized video track (".vrec": per-frame Vectrex segment lists), and
 *   - an optional 4-bit voice track (".vsmp": packed low-rate PCM for the PSG
 *     volume-register "DAC").
 *
 * The .vmov manifest:
 *   { version, name, fps, vrec, vsmp? }
 * where `vrec` / `vsmp` are paths RELATIVE to the .vmov file's own directory
 * (the project's assets dir). A missing `vsmp` = a silent movie.
 *
 * This editor:
 *   - loads the referenced .vrec (+ .vsmp) sibling files,
 *   - plays them SYNCED — audio is the master clock (matches the hardware
 *     runtime); the displayed frame = floor(audioElapsed * fps) % frameCount.
 *     With no audio it falls back to a real-time clock at `fps`,
 *   - offers a transport bar (play/pause, restart, loop) + a frame scrubber,
 *   - imports media by spawning the on-disk Python converters (video → .vrec,
 *     audio → .vsmp) through the `movie:convert` IPC, then rewrites the .vmov.
 *
 * Rendering mirrors VrecViewer's Vectrex-phosphor look (black background,
 * green-white lines, intensity → brightness, Y-up flip, isotropic aspect-fit).
 */

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface VmovManifest {
  version?: string;
  name?: string;
  fps?: number;
  vrec?: string;
  vsmp?: string;
  /** Optional: last source media path, enables "Re-convert". */
  source?: string;
}

interface VrecSegment { x0: number; y0: number; x1: number; y1: number; i: number }
interface VrecFrame   { segments: VrecSegment[] }
interface VrecData    { version: string; name: string; fps: number; frames: VrecFrame[] }

interface VsmpAudio { sampleRate: number; buffer: AudioBuffer; numSamples: number }

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

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

/** Decode base64 (browser-safe) into a Uint8Array. */
function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/**
 * Decode a parsed .vsmp resource into a mono AudioBuffer.
 * Format: packed 4-bit PCM, 2 samples/byte, low nibble = even sample.
 * Each 0-15 nibble maps to [-1, 1] via (v / 15 * 2 - 1).
 */
function decodeVsmp(resource: any, ctx: AudioContext): VsmpAudio | null {
  if (!resource || typeof resource !== 'object') return null;
  const sampleRate = Number(resource.sampleRate) || 8000;
  const numSamples = Number(resource.numSamples) || 0;
  if (typeof resource.data !== 'string' || numSamples <= 0) return null;
  let bytes: Uint8Array;
  try { bytes = base64ToBytes(resource.data); } catch { return null; }

  const buffer = ctx.createBuffer(1, numSamples, sampleRate);
  const ch = buffer.getChannelData(0);
  for (let i = 0; i < numSamples; i++) {
    const byte = bytes[i >> 1] ?? 0;
    const nib = (i & 1) === 0 ? (byte & 0x0f) : ((byte >> 4) & 0x0f);
    ch[i] = (nib / 15) * 2 - 1;
  }
  return { sampleRate, buffer, numSamples };
}

// ---------------------------------------------------------------------------
// Canvas rendering (Vectrex phosphor look — mirrors VrecViewer)
// ---------------------------------------------------------------------------

const CANVAS_W = 660;
const CANVAS_H = 820;

function drawFrame(
  canvas: HTMLCanvasElement,
  frame: VrecFrame | undefined,
  selectedSeg: number,
): void {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.shadowBlur = 0;
  ctx.fillStyle = '#000000';
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  const cx = CANVAS_W / 2;
  const cy = CANVAS_H / 2;
  const pad = 20;
  const scale = (Math.min(CANVAS_W, CANVAS_H) / 2 - pad) / 127;

  ctx.strokeStyle = 'rgba(80, 120, 80, 0.25)';
  ctx.lineWidth = 1;
  ctx.strokeRect(cx - 127 * scale, cy - 127 * scale, 254 * scale, 254 * scale);

  if (!frame) return;

  const toX = (x: number) => cx + x * scale;
  const toY = (y: number) => cy - y * scale;

  frame.segments.forEach((s, idx) => {
    const alpha = Math.min(127, Math.max(0, s.i)) / 127;
    const selected = idx === selectedSeg;
    if (alpha <= 0 && !selected) return;

    if (selected) {
      ctx.strokeStyle = 'rgba(255, 210, 90, 0.95)';
      ctx.lineWidth = 3;
      ctx.shadowColor = 'rgba(255, 180, 40, 0.9)';
      ctx.shadowBlur = 10;
    } else {
      ctx.strokeStyle = `rgba(160, 255, 190, ${(0.25 + 0.75 * alpha).toFixed(3)})`;
      ctx.lineWidth = 2;
      ctx.shadowColor = 'rgba(80, 255, 140, 0.8)';
      ctx.shadowBlur = 4 + 6 * alpha;
    }

    ctx.beginPath();
    if (s.x0 === s.x1 && s.y0 === s.y1) {
      ctx.moveTo(toX(s.x0) - 0.5, toY(s.y0));
      ctx.lineTo(toX(s.x0) + 0.5, toY(s.y0));
    } else {
      ctx.moveTo(toX(s.x0), toY(s.y0));
      ctx.lineTo(toX(s.x1), toY(s.y1));
    }
    ctx.stroke();

    // Endpoint handles for the selected segment (for editing).
    if (selected) {
      ctx.shadowBlur = 0;
      ctx.fillStyle = 'rgba(255, 230, 120, 0.95)';
      for (const [px, py] of [[s.x0, s.y0], [s.x1, s.y1]] as const) {
        ctx.beginPath();
        ctx.arc(toX(px), toY(py), 5, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  });
  ctx.shadowBlur = 0;
}

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

/** file:// URI → filesystem path. */
function uriToFsPath(uri: string): string {
  return uri.replace('file:///', '/').replace('file://', '');
}

/** Directory of a filesystem path (POSIX-ish; the IDE normalises to '/'). */
function dirOf(p: string): string {
  const norm = p.replace(/\\/g, '/');
  const idx = norm.lastIndexOf('/');
  return idx >= 0 ? norm.slice(0, idx) : '';
}

function joinPath(dir: string, rel: string): string {
  if (!rel) return dir;
  if (rel.startsWith('/')) return rel;
  return `${dir}/${rel}`.replace(/\/+/g, '/');
}

function baseName(p: string): string {
  const norm = p.replace(/\\/g, '/');
  return norm.slice(norm.lastIndexOf('/') + 1);
}

function stripExt(name: string): string {
  const i = name.lastIndexOf('.');
  return i > 0 ? name.slice(0, i) : name;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

interface VectorMovieEditorProps {
  /** Parsed .vmov manifest JSON. */
  resource?: VmovManifest;
  /** file:// URI of the .vmov document (needed to resolve sibling assets). */
  docUri?: string;
  /** Persist manifest changes back to the editor document. */
  onChange?: (resource: VmovManifest) => void;
}

type ImportKind = 'video' | 'audio' | null;

export const VectorMovieEditor: React.FC<VectorMovieEditorProps> = ({ resource, docUri, onChange }) => {
  const manifest = resource || {};
  const fsPath = docUri ? uriToFsPath(docUri) : '';
  const assetsDir = fsPath ? dirOf(fsPath) : '';

  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  // Loaded track data ------------------------------------------------------
  const [vrec, setVrec] = useState<VrecData | null>(null);
  const [audio, setAudio] = useState<VsmpAudio | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [loadNonce, setLoadNonce] = useState(0); // bump to force reload

  // Transport --------------------------------------------------------------
  const [frameIdx, setFrameIdx] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [loop, setLoop] = useState(true);
  const [selectedSeg, setSelectedSeg] = useState(-1);
  const [dirtyVrec, setDirtyVrec] = useState(false);

  // Import UI --------------------------------------------------------------
  const [importKind, setImportKind] = useState<ImportKind>(null);
  const [converting, setConverting] = useState(false);
  const [progress, setProgress] = useState('');
  const [videoOpts, setVideoOpts] = useState({ mode: 'silhouette', fps: manifest.fps || 15, epsilon: 2, budget: 200 });
  const [audioOpts, setAudioOpts] = useState({ rate: 8000, normalize: true });

  const fps = vrec?.fps || manifest.fps || 15;
  const frameCount = vrec?.frames.length ?? 0;

  // AudioContext + master-clock refs. audioStartRef = ctx time (audio) or
  // performance.now()/1000 (fallback) at which frame 0 began playing.
  const audioCtxRef = useRef<AudioContext | null>(null);
  const sourceRef = useRef<AudioBufferSourceNode | null>(null);
  const clockStartRef = useRef(0); // seconds; zero point for elapsed
  const rafRef = useRef(0);

  // ── Load referenced tracks whenever the manifest / doc / nonce changes ──
  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoadError(null);
      setVrec(null);
      setAudio(null);
      setSelectedSeg(-1);
      setDirtyVrec(false);
      if (!assetsDir || !manifest.vrec) { setLoadError('No .vrec referenced in this .vmov.'); return; }

      const filesApi = (window as any).files;
      if (!filesApi?.readFile) { setLoadError('File API unavailable.'); return; }

      // vrec (required)
      const vrecPath = joinPath(assetsDir, manifest.vrec);
      const vrecRes = await filesApi.readFile(vrecPath);
      if (cancelled) return;
      if (!vrecRes || vrecRes.error) { setLoadError(`Could not read vrec: ${manifest.vrec}`); return; }
      let vrecData: VrecData | null = null;
      try { vrecData = normalizeVrec(JSON.parse(vrecRes.content)); } catch { /* handled below */ }
      if (!vrecData) { setLoadError(`Invalid .vrec file: ${manifest.vrec}`); return; }
      setVrec(vrecData);

      // vsmp (optional)
      if (manifest.vsmp) {
        const smpPath = joinPath(assetsDir, manifest.vsmp);
        const smpRes = await filesApi.readFile(smpPath);
        if (cancelled) return;
        if (smpRes && !smpRes.error) {
          try {
            const ctx = ensureAudioCtx();
            const parsed = JSON.parse(smpRes.content);
            const decoded = decodeVsmp(parsed, ctx);
            if (decoded) setAudio(decoded);
          } catch { /* silent movie fallback */ }
        }
      }
    })();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [assetsDir, manifest.vrec, manifest.vsmp, loadNonce]);

  // Reset transport when a new recording loads.
  useEffect(() => {
    stopPlayback();
    setFrameIdx(0);
    setPlaying(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [vrec]);

  function ensureAudioCtx(): AudioContext {
    if (!audioCtxRef.current) {
      const Ctor = (window.AudioContext || (window as any).webkitAudioContext);
      audioCtxRef.current = new Ctor();
    }
    return audioCtxRef.current!;
  }

  // ── Playback engine ─────────────────────────────────────────────────────

  const stopPlayback = useCallback(() => {
    if (rafRef.current) { cancelAnimationFrame(rafRef.current); rafRef.current = 0; }
    if (sourceRef.current) {
      try { sourceRef.current.stop(); } catch {}
      try { sourceRef.current.disconnect(); } catch {}
      sourceRef.current = null;
    }
  }, []);

  // Start (or restart) playback from a given frame offset.
  const startPlayback = useCallback((fromFrame: number) => {
    if (!vrec || frameCount === 0) return;
    stopPlayback();
    const offsetSec = fromFrame / fps;

    if (audio) {
      const ctx = ensureAudioCtx();
      if (ctx.state === 'suspended') ctx.resume().catch(() => {});
      const src = ctx.createBufferSource();
      src.buffer = audio.buffer;
      // Normal graph → destination so the audioGraphTracker (video recorder)
      // taps it just like the emulator's own output.
      src.connect(ctx.destination);
      const clampedOffset = Math.min(offsetSec, Math.max(0, audio.buffer.duration - 0.001));
      src.start(0, clampedOffset);
      sourceRef.current = src;
      clockStartRef.current = ctx.currentTime - clampedOffset;
      src.onended = () => {
        // Natural end of the audio buffer.
        if (sourceRef.current === src) {
          if (loop) { startPlayback(0); } else { setPlaying(false); }
        }
      };
    } else {
      clockStartRef.current = performance.now() / 1000 - offsetSec;
    }

    const tick = () => {
      const now = audio ? ensureAudioCtx().currentTime : performance.now() / 1000;
      const elapsed = now - clockStartRef.current;
      let f = Math.floor(elapsed * fps);
      if (audio) {
        // Audio is master; clamp to its length. Loop handled in onended.
        if (f >= frameCount) f = loop ? f % frameCount : frameCount - 1;
      } else {
        if (f >= frameCount) {
          if (loop) { f = f % frameCount; }
          else { setFrameIdx(frameCount - 1); setPlaying(false); return; }
        }
      }
      setFrameIdx(f);
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
  }, [vrec, frameCount, fps, audio, loop, stopPlayback]);

  const handlePlayPause = useCallback(() => {
    if (playing) {
      stopPlayback();
      setPlaying(false);
    } else {
      const from = frameIdx >= frameCount - 1 ? 0 : frameIdx;
      setPlaying(true);
      setSelectedSeg(-1);
      startPlayback(from);
    }
  }, [playing, frameIdx, frameCount, startPlayback, stopPlayback]);

  const handleRestart = useCallback(() => {
    setFrameIdx(0);
    if (playing) startPlayback(0);
  }, [playing, startPlayback]);

  const handleScrub = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const f = Number(e.target.value) | 0;
    setSelectedSeg(-1);
    if (playing) {
      // Dragging pauses (matches VrecViewer / typical scrub UX).
      stopPlayback();
      setPlaying(false);
    }
    setFrameIdx(f);
  }, [playing, stopPlayback]);

  // Stop everything on unmount.
  useEffect(() => () => { stopPlayback(); }, [stopPlayback]);

  // ── Render current frame ────────────────────────────────────────────────
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !vrec) return;
    const idx = Math.min(frameIdx, frameCount - 1);
    drawFrame(canvas, vrec.frames[idx], playing ? -1 : selectedSeg);
  }, [vrec, frameIdx, frameCount, selectedSeg, playing]);

  // ── Import: pick + convert ──────────────────────────────────────────────
  useEffect(() => {
    if (!(window as any).movie?.onProgress) return;
    const off = (window as any).movie.onProgress((line: string) => setProgress(line));
    return () => { try { off?.(); } catch {} };
  }, []);

  const runImport = useCallback(async (kind: 'video' | 'audio', inputPath: string, sourceName: string) => {
    const movieApi = (window as any).movie;
    if (!movieApi?.convert || !assetsDir) return;
    setConverting(true);
    setProgress('Starting…');

    const base = stripExt(baseName(sourceName)) || (manifest.name || 'movie');
    const subdir = kind === 'video' ? 'recordings' : 'samples';
    const ext = kind === 'video' ? 'vrec' : 'vsmp';
    const outPath = `${assetsDir}/${subdir}/${base}.${ext}`;

    const opts = kind === 'video'
      ? { mode: videoOpts.mode, fps: videoOpts.fps, epsilon: videoOpts.epsilon, budget: videoOpts.budget }
      : { rate: audioOpts.rate, normalize: audioOpts.normalize };

    const res = await movieApi.convert({ kind, inputPath, outPath, opts });
    setConverting(false);

    if (!res || res.error) {
      setProgress(`Error: ${res?.error || 'conversion failed'}`);
      return;
    }

    // Update the manifest with a relative path + source, then persist + reload.
    const rel = `${subdir}/${base}.${ext}`;
    const next: VmovManifest = { ...manifest };
    next.version = next.version || '1.0';
    next.name = next.name || base;
    if (kind === 'video') { next.vrec = rel; next.fps = videoOpts.fps; }
    else { next.vsmp = rel; }
    next.source = inputPath;
    onChange?.(next);
    setProgress(`Done: ${rel}`);
    setImportKind(null);
    // Give the editor store a tick to flush, then reload tracks.
    setTimeout(() => setLoadNonce(n => n + 1), 60);
  }, [assetsDir, manifest, videoOpts, audioOpts, onChange]);

  const pickAndImport = useCallback(async (kind: 'video' | 'audio') => {
    const movieApi = (window as any).movie;
    if (!movieApi?.pickFile) return;
    const picked = await movieApi.pickFile({ kind });
    if (!picked) return;
    await runImport(kind, picked.path, picked.name);
  }, [runImport]);

  const reconvert = useCallback(async (kind: 'video' | 'audio') => {
    if (!manifest.source) return;
    await runImport(kind, manifest.source, baseName(manifest.source));
  }, [manifest.source, runImport]);

  // ── Frame editing (paused) ──────────────────────────────────────────────

  const canvasToVec = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current!;
    const rect = canvas.getBoundingClientRect();
    const px = (e.clientX - rect.left) / rect.width * CANVAS_W;
    const py = (e.clientY - rect.top) / rect.height * CANVAS_H;
    const cx = CANVAS_W / 2, cy = CANVAS_H / 2;
    const scale = (Math.min(CANVAS_W, CANVAS_H) / 2 - 20) / 127;
    return { x: (px - cx) / scale, y: (cy - py) / scale };
  }, []);

  const dragRef = useRef<{ endpoint: 0 | 1 } | null>(null);

  const onCanvasMouseDown = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    if (playing || !vrec) return;
    const frame = vrec.frames[Math.min(frameIdx, frameCount - 1)];
    if (!frame) return;
    const { x, y } = canvasToVec(e);

    // If a segment is selected, check for an endpoint grab first.
    if (selectedSeg >= 0 && frame.segments[selectedSeg]) {
      const s = frame.segments[selectedSeg];
      const d0 = Math.hypot(s.x0 - x, s.y0 - y);
      const d1 = Math.hypot(s.x1 - x, s.y1 - y);
      const grab = 6; // vec units
      if (d0 <= grab && d0 <= d1) { dragRef.current = { endpoint: 0 }; return; }
      if (d1 <= grab) { dragRef.current = { endpoint: 1 }; return; }
    }

    // Otherwise hit-test all segments (distance point→line).
    let best = -1, bestDist = 5; // vec units threshold
    frame.segments.forEach((s, idx) => {
      const dist = pointToSegment(x, y, s.x0, s.y0, s.x1, s.y1);
      if (dist < bestDist) { bestDist = dist; best = idx; }
    });
    setSelectedSeg(best);
    dragRef.current = null;
  }, [playing, vrec, frameIdx, frameCount, selectedSeg, canvasToVec]);

  const onCanvasMouseMove = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    if (playing || !vrec || !dragRef.current || selectedSeg < 0) return;
    const frame = vrec.frames[Math.min(frameIdx, frameCount - 1)];
    const s = frame?.segments[selectedSeg];
    if (!s) return;
    const { x, y } = canvasToVec(e);
    const nx = Math.max(-127, Math.min(127, Math.round(x)));
    const ny = Math.max(-127, Math.min(127, Math.round(y)));
    if (dragRef.current.endpoint === 0) { s.x0 = nx; s.y0 = ny; } else { s.x1 = nx; s.y1 = ny; }
    setDirtyVrec(true);
    // Force a redraw by cloning frame reference minimally.
    drawFrame(canvasRef.current!, frame, selectedSeg);
  }, [playing, vrec, frameIdx, frameCount, selectedSeg, canvasToVec]);

  const onCanvasMouseUp = useCallback(() => { dragRef.current = null; }, []);

  // Delete key removes the selected segment.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (playing || selectedSeg < 0 || !vrec) return;
      if (e.key !== 'Delete' && e.key !== 'Backspace') return;
      const frame = vrec.frames[Math.min(frameIdx, frameCount - 1)];
      if (!frame) return;
      frame.segments.splice(selectedSeg, 1);
      setSelectedSeg(-1);
      setDirtyVrec(true);
      drawFrame(canvasRef.current!, frame, -1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [playing, selectedSeg, vrec, frameIdx, frameCount]);

  const saveVrec = useCallback(async () => {
    if (!vrec || !assetsDir || !manifest.vrec) return;
    const vrecPath = joinPath(assetsDir, manifest.vrec);
    const out = {
      version: vrec.version,
      name: vrec.name,
      fps: vrec.fps,
      frames: vrec.frames,
    };
    const res = await (window as any).files?.saveFile?.({ path: vrecPath, content: JSON.stringify(out) });
    if (res && !res.error) setDirtyVrec(false);
  }, [vrec, assetsDir, manifest.vrec]);

  // ── Render ──────────────────────────────────────────────────────────────

  const idx = Math.min(frameIdx, Math.max(0, frameCount - 1));
  const segCount = vrec?.frames[idx]?.segments.length ?? 0;
  const elapsedSec = frameCount > 0 ? (idx / fps) : 0;
  const totalSec = frameCount > 0 ? (frameCount / fps) : 0;

  return (
    <div style={S.root}>
      {/* Header */}
      <div style={S.header}>
        <span style={{ color: '#8f8', fontWeight: 'bold', fontSize: 14 }}>📽️ {manifest.name || 'vector movie'}</span>
        <span style={{ color: '#888' }}>{fps} fps</span>
        {audio && <span style={{ color: '#7bd' }}>🔊 {audio.sampleRate} Hz voice</span>}
        {!audio && manifest.vsmp && <span style={{ color: '#c96' }}>audio failed to load</span>}
        {!manifest.vsmp && <span style={{ color: '#777' }}>silent</span>}
        <div style={{ flex: 1 }} />
        <button style={S.btnSmall} onClick={() => setImportKind(importKind ? null : 'video')}>
          {importKind ? '✕ Close import' : '＋ Import…'}
        </button>
      </div>

      {/* Import panel */}
      {importKind && (
        <div style={S.importPanel}>
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <button style={importKind === 'video' ? S.tabActive : S.tab} onClick={() => setImportKind('video')}>Video → .vrec</button>
            <button style={importKind === 'audio' ? S.tabActive : S.tab} onClick={() => setImportKind('audio')}>Audio → .vsmp</button>
          </div>

          {importKind === 'video' ? (
            <div style={S.optRow}>
              <label style={S.optLabel}>mode
                <select value={videoOpts.mode} onChange={e => setVideoOpts(o => ({ ...o, mode: e.target.value }))} style={S.input}>
                  <option value="silhouette">silhouette</option>
                  <option value="edges">edges</option>
                </select>
              </label>
              <label style={S.optLabel}>fps
                <input type="number" min={1} max={60} value={videoOpts.fps} onChange={e => setVideoOpts(o => ({ ...o, fps: Number(e.target.value) }))} style={S.input} />
              </label>
              <label style={S.optLabel}>epsilon
                <input type="number" min={0} step={0.5} value={videoOpts.epsilon} onChange={e => setVideoOpts(o => ({ ...o, epsilon: Number(e.target.value) }))} style={S.input} />
              </label>
              <label style={S.optLabel}>budget
                <input type="number" min={10} max={2000} value={videoOpts.budget} onChange={e => setVideoOpts(o => ({ ...o, budget: Number(e.target.value) }))} style={S.input} />
              </label>
            </div>
          ) : (
            <div style={S.optRow}>
              <label style={S.optLabel}>rate (Hz)
                <input type="number" min={2000} max={22050} step={1000} value={audioOpts.rate} onChange={e => setAudioOpts(o => ({ ...o, rate: Number(e.target.value) }))} style={S.input} />
              </label>
              <label style={{ ...S.optLabel, flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                <input type="checkbox" checked={audioOpts.normalize} onChange={e => setAudioOpts(o => ({ ...o, normalize: e.target.checked }))} />
                normalize
              </label>
            </div>
          )}

          <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
            <button style={S.btnPrimary} disabled={converting} onClick={() => pickAndImport(importKind)}>
              {converting ? 'Converting…' : `Choose ${importKind} file…`}
            </button>
            {manifest.source && (
              <button style={S.btnSmall} disabled={converting} onClick={() => reconvert(importKind)} title={manifest.source}>
                ↻ Re-convert last source
              </button>
            )}
            <span style={{ color: '#9ab', fontSize: 11, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {progress}
            </span>
          </div>
          <div style={{ color: '#667', fontSize: 10, marginTop: 6 }}>
            Requires ffmpeg on PATH; video import uses tools/video2vrec/.venv (opencv).
          </div>
        </div>
      )}

      {/* Body */}
      {loadError ? (
        <div style={S.msgBox}>
          <span style={{ fontSize: 28 }}>📽️</span>
          <span>{loadError}</span>
          <span style={{ color: '#777', fontSize: 11 }}>Use “Import…” to add a video (.vrec) or audio (.vsmp) track.</span>
        </div>
      ) : !vrec ? (
        <div style={S.msgBox}><span>Loading movie…</span></div>
      ) : (
        <div style={S.body}>
          <canvas
            ref={canvasRef}
            width={CANVAS_W}
            height={CANVAS_H}
            onMouseDown={onCanvasMouseDown}
            onMouseMove={onCanvasMouseMove}
            onMouseUp={onCanvasMouseUp}
            onMouseLeave={onCanvasMouseUp}
            style={{ border: '1px solid #333', background: '#000', width: 330, height: 410, flexShrink: 0, cursor: playing ? 'default' : 'crosshair' }}
          />

          {/* Transport */}
          <div style={S.transport}>
            <button style={S.btn} title="Restart" onClick={handleRestart}>⏮</button>
            <button
              style={{ ...S.btn, background: playing ? '#4a2a2a' : '#2a4a2a', color: playing ? '#faa' : '#afa' }}
              title={playing ? 'Pause' : 'Play'}
              onClick={handlePlayPause}
            >{playing ? '⏸' : '▶'}</button>
            <button
              style={{ ...S.btn, background: loop ? '#2a3a4a' : '#222', color: loop ? '#adf' : '#888' }}
              title="Loop"
              onClick={() => setLoop(l => !l)}
            >🔁</button>

            <input
              type="range"
              min={0}
              max={Math.max(0, frameCount - 1)}
              step={1}
              value={idx}
              onChange={handleScrub}
              style={{ flex: 1 }}
              title="Scrub frames"
            />
          </div>

          {/* Readout */}
          <div style={S.readout}>
            frame {idx + 1}/{frameCount} · {elapsedSec.toFixed(1)}s / {totalSec.toFixed(1)}s · {segCount} segs
            {!playing && selectedSeg >= 0 && <span style={{ color: '#fd8', marginLeft: 10 }}>seg {selectedSeg} selected (drag endpoints · Delete to remove)</span>}
          </div>

          {/* Edit actions (paused) */}
          {!playing && (
            <div style={{ display: 'flex', gap: 8, marginTop: 6, alignItems: 'center' }}>
              <button style={S.btnSmall} disabled={!dirtyVrec} onClick={saveVrec}>
                {dirtyVrec ? '💾 Save frame edits (.vrec)' : 'No unsaved edits'}
              </button>
              <span style={{ color: '#667', fontSize: 10 }}>
                Pause + click a segment to edit its endpoints. Edits are per-frame.
              </span>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

/** Distance from point (px,py) to segment (x0,y0)-(x1,y1). */
function pointToSegment(px: number, py: number, x0: number, y0: number, x1: number, y1: number): number {
  const dx = x1 - x0, dy = y1 - y0;
  const len2 = dx * dx + dy * dy;
  if (len2 === 0) return Math.hypot(px - x0, py - y0);
  let t = ((px - x0) * dx + (py - y0) * dy) / len2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - (x0 + t * dx), py - (y0 + t * dy));
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const S: Record<string, React.CSSProperties> = {
  root: { display: 'flex', flexDirection: 'column', height: '100%', width: '100%', fontFamily: 'monospace', fontSize: 12, color: '#ccc', boxSizing: 'border-box', overflow: 'auto', padding: 12, gap: 8 },
  header: { display: 'flex', gap: 14, alignItems: 'baseline' },
  body: { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 },
  transport: { display: 'flex', alignItems: 'center', gap: 8, width: 380, maxWidth: '100%' },
  readout: { color: '#aaa', fontSize: 11 },
  msgBox: { display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 8, flex: 1, color: '#bbb' },
  importPanel: { background: '#12121c', border: '1px solid #2a2a3a', borderRadius: 6, padding: 10 },
  optRow: { display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'flex-end' },
  optLabel: { display: 'flex', flexDirection: 'column', gap: 3, fontSize: 11, color: '#9ab' },
  input: { background: '#1c1c28', color: '#ddd', border: '1px solid #333', borderRadius: 4, padding: '3px 6px', fontSize: 12, width: 100 },
  btn: { background: '#222', color: '#ddd', border: '1px solid #444', borderRadius: 4, padding: '6px 10px', fontSize: 16, cursor: 'pointer', minWidth: 42 },
  btnSmall: { background: '#222', color: '#cde', border: '1px solid #444', borderRadius: 4, padding: '4px 10px', fontSize: 12, cursor: 'pointer' },
  btnPrimary: { background: '#2a4a2a', color: '#afa', border: '1px solid #3a5a3a', borderRadius: 4, padding: '6px 14px', fontSize: 12, cursor: 'pointer' },
  tab: { background: '#1a1a26', color: '#99a', border: '1px solid #333', borderRadius: 4, padding: '4px 10px', fontSize: 12, cursor: 'pointer' },
  tabActive: { background: '#243', color: '#afa', border: '1px solid #3a5a3a', borderRadius: 4, padding: '4px 10px', fontSize: 12, cursor: 'pointer' },
};

export default VectorMovieEditor;
