/**
 * InstrumentEditor - AY-3-8910 PSG Instrument Editor
 * Parameter-based instrument definition editor for Vectrex (.vinstr files)
 *
 * Features:
 * - Basic instrument parameters (volume, duration)
 * - Arpeggio editor (up to 4 intervals)
 * - Pitch sweep controls
 * - Noise mixing
 * - Piano keyboard preview (2 octaves, Web Audio API square-wave simulation)
 * - Audio Analyzer tab (drop .wav/.mp3, detect fundamental frequency)
 * - Preset library (pluck, bell, bass, lead)
 */

import React, { useRef, useEffect, useState, useCallback, useMemo } from 'react';

// ============================================
// Types
// ============================================

export interface InstrResource {
  version: string;
  name: string;
  duration_frames: number;
  volume: number;
  arpeggio_count: number;
  arpeggio_speed_frames: number;
  arpeggio_intervals: number[];
  noise_enabled: boolean;
  noise_period: number;
  pitch_sweep_delta: number;
  pitch_sweep_duration_frames: number;
}

interface InstrumentEditorProps {
  resource?: InstrResource;
  onChange?: (resource: InstrResource) => void;
}

type EditorTab = 'edit' | 'analyze';

interface AnalysisResult {
  fundamentalHz: number;
  midiNote: number;
  durationFrames: number;
  suggestedVolume: number;
  // Timbre analysis
  arpeggio_count: number;
  arpeggio_speed_frames: number;
  arpeggio_intervals: number[];
  noise_enabled: boolean;
  noise_period: number;
  pitch_sweep_delta: number;
  pitch_sweep_duration_frames: number;
  // Debug info
  harmonicsFound: number[];
  spectralFlatness: number;
  pitchDriftSemitones: number;
}

// ============================================
// Default factory
// ============================================

export function defaultInstr(name = 'untitled'): InstrResource {
  return {
    version: '1.0',
    name,
    duration_frames: 10,
    volume: 14,
    arpeggio_count: 0,
    arpeggio_speed_frames: 2,
    arpeggio_intervals: [0, 0, 0, 0],
    noise_enabled: false,
    noise_period: 15,
    pitch_sweep_delta: 0,
    pitch_sweep_duration_frames: 0,
  };
}

// ============================================
// Presets
// ============================================

type PresetName = 'pluck' | 'bell' | 'bass' | 'lead';

const PRESETS: Record<PresetName, Partial<InstrResource>> = {
  pluck: {
    duration_frames: 10, volume: 14, arpeggio_count: 0, arpeggio_speed_frames: 2,
    arpeggio_intervals: [0, 0, 0, 0], noise_enabled: false, noise_period: 15,
    pitch_sweep_delta: -1, pitch_sweep_duration_frames: 8,
  },
  bell: {
    duration_frames: 20, volume: 12, arpeggio_count: 3, arpeggio_speed_frames: 3,
    arpeggio_intervals: [0, 7, 12, 0], noise_enabled: false, noise_period: 15,
    pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0,
  },
  bass: {
    duration_frames: 15, volume: 15, arpeggio_count: 0, arpeggio_speed_frames: 2,
    arpeggio_intervals: [0, 0, 0, 0], noise_enabled: false, noise_period: 15,
    pitch_sweep_delta: 1, pitch_sweep_duration_frames: 10,
  },
  lead: {
    duration_frames: 18, volume: 13, arpeggio_count: 2, arpeggio_speed_frames: 4,
    arpeggio_intervals: [0, 4, 0, 0], noise_enabled: false, noise_period: 15,
    pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0,
  },
};

// ============================================
// Piano keyboard constants
// ============================================

// 2 octaves: C3 (MIDI 48) through B4 (MIDI 71)
const MIDI_START = 48;
const MIDI_END = 71;

// Semitone offset within octave: 0=C,1=C#,2=D,3=D#,4=E,5=F,6=F#,7=G,8=G#,9=A,10=A#,11=B
const BLACK_SEMITONES = new Set([1, 3, 6, 8, 10]);
const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

function midiToName(midi: number): string {
  const octave = Math.floor(midi / 12) - 1;
  const name = NOTE_NAMES[midi % 12];
  return `${name}${octave}`;
}

function midiToFreq(midi: number): number {
  return 440 * Math.pow(2, (midi - 69) / 12);
}

// ============================================
// Audio preview
// ============================================

function playNotePreview(note: number, instr: InstrResource) {
  const AudioCtxClass: typeof AudioContext =
    window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
  const ctx = new AudioCtxClass();

  const baseFreq = midiToFreq(note);
  const frameDuration = 1 / 50; // 50 fps
  const totalFrames = instr.duration_frames;
  const arpCount = instr.arpeggio_count;

  const events: Array<{ freq: number; startTime: number }> = [];

  for (let f = 0; f < totalFrames; f++) {
    let freq = baseFreq;

    if (arpCount > 0) {
      const stepSize = instr.arpeggio_speed_frames;
      const arpPos = Math.floor(f / stepSize) % arpCount;
      const semitoneOffset = instr.arpeggio_intervals[arpPos] ?? 0;
      freq = baseFreq * Math.pow(2, semitoneOffset / 12);
    }

    if (instr.pitch_sweep_duration_frames > 0 && f < instr.pitch_sweep_duration_frames) {
      const initPeriod = Math.round(88200 / freq);
      const currentPeriod = Math.max(1, initPeriod + instr.pitch_sweep_delta * f);
      freq = 88200 / currentPeriod;
    }

    events.push({ freq, startTime: f * frameDuration });
  }

  const osc = ctx.createOscillator();
  osc.type = 'square';

  const gain = ctx.createGain();
  gain.gain.setValueAtTime(instr.volume / 15 * 0.3, ctx.currentTime);
  gain.gain.setValueAtTime(0, ctx.currentTime + totalFrames * frameDuration);

  osc.connect(gain);
  gain.connect(ctx.destination);

  let lastFreq = -1;
  for (const ev of events) {
    if (ev.freq !== lastFreq) {
      osc.frequency.setValueAtTime(ev.freq, ctx.currentTime + ev.startTime);
      lastFreq = ev.freq;
    }
  }

  osc.start(ctx.currentTime);
  osc.stop(ctx.currentTime + totalFrames * frameDuration + 0.05);

  setTimeout(() => ctx.close(), (totalFrames * frameDuration + 0.2) * 1000);
}

// ============================================
// Spectral analysis helpers
// ============================================

function hannWindow(samples: Float32Array): Float32Array {
  const out = new Float32Array(samples.length);
  for (let i = 0; i < samples.length; i++) {
    out[i] = samples[i] * 0.5 * (1 - Math.cos(2 * Math.PI * i / (samples.length - 1)));
  }
  return out;
}

function dft(samples: Float32Array, sampleRate: number): { freq: number; magnitude: number }[] {
  const N = samples.length;
  const results: { freq: number; magnitude: number }[] = [];
  for (let k = 0; k < N / 2; k++) {
    let re = 0, im = 0;
    for (let n = 0; n < N; n++) {
      const angle = (2 * Math.PI * k * n) / N;
      re += samples[n] * Math.cos(angle);
      im -= samples[n] * Math.sin(angle);
    }
    results.push({ freq: k * sampleRate / N, magnitude: Math.sqrt(re * re + im * im) });
  }
  return results;
}

function findFundamental(region: Float32Array, sr: number) {
  const N = Math.min(region.length, 2048);
  const windowed = hannWindow(region.slice(0, N));
  const bins = dft(windowed, sr);
  // Find peak in 40–5000 Hz range (ignore DC and ultrasound)
  let maxIdx = 1;
  for (let i = 1; i < bins.length; i++) {
    if (bins[i].freq < 40 || bins[i].freq > 5000) continue;
    if (bins[i].magnitude > bins[maxIdx].magnitude) maxIdx = i;
  }
  return { hz: bins[maxIdx].freq, mag: bins[maxIdx].magnitude, bins };
}

async function analyzeRegion(
  audioBuffer: AudioBuffer,
  startSec: number,
  endSec: number
): Promise<AnalysisResult> {
  const sr = audioBuffer.sampleRate;
  const data = audioBuffer.getChannelData(0);
  const region = data.slice(Math.floor(startSec * sr), Math.floor(endSec * sr));

  // ── 1. Fundamental pitch ──────────────────────────────────────────────────
  const { hz: fundamentalHz, mag: fundamentalMag, bins } = findFundamental(region, sr);
  const midiNote = Math.round(69 + 12 * Math.log2(Math.max(fundamentalHz, 1) / 440));

  // ── 2. Amplitude envelope (10 ms RMS windows) ────────────────────────────
  const winSz = Math.max(1, Math.floor(sr * 0.01));
  const rms: number[] = [];
  for (let s = 0; s + winSz <= region.length; s += winSz) {
    let sq = 0;
    for (let i = s; i < s + winSz; i++) sq += region[i] * region[i];
    rms.push(Math.sqrt(sq / winSz));
  }
  const peakRms = Math.max(...rms, 0.0001);
  // Decay time: first window that drops below 20 % of peak
  let decayIdx = rms.length;
  for (let i = 0; i < rms.length; i++) {
    if (rms[i] < peakRms * 0.2) { decayIdx = i; break; }
  }
  const durationFrames = Math.max(2, Math.min(255, Math.round(decayIdx * 0.01 * 50)));
  const suggestedVolume = Math.min(15, Math.max(1, Math.round(peakRms * 80)));

  // ── 3. Harmonic analysis → arpeggio ──────────────────────────────────────
  // Look for harmonics at 2×, 3×, 4×, 5× fundamental with magnitude > 20 % of fundamental
  const harmonicsFound: number[] = [];
  for (const mult of [2, 3, 4, 5]) {
    const targetHz = fundamentalHz * mult;
    if (targetHz > sr / 2) break;
    const nearBin = bins.reduce((b, c) =>
      Math.abs(c.freq - targetHz) < Math.abs(b.freq - targetHz) ? c : b);
    if (nearBin.magnitude > fundamentalMag * 0.2) {
      const semitones = Math.round(12 * Math.log2(targetHz / fundamentalHz));
      if (semitones > 0 && semitones <= 12) harmonicsFound.push(semitones);
    }
  }
  const unique = [...new Set(harmonicsFound)].sort((a, b) => a - b).slice(0, 3);
  const arpeggio_intervals = [0, ...unique, 0, 0, 0].slice(0, 4);
  const arpeggio_count = unique.length > 0 ? Math.min(4, 1 + unique.length) : 0;
  const arpeggio_speed_frames = arpeggio_count <= 1 ? 2 : 3;

  // ── 4. Spectral flatness → noise ─────────────────────────────────────────
  // Flatness = geometric_mean / arithmetic_mean; ~1 = white noise, ~0 = tonal
  const midBins = bins.filter(b => b.freq > fundamentalHz * 1.5 && b.freq < 8000);
  let spectralFlatness = 0;
  let noise_enabled = false;
  let noise_period = 15;
  if (midBins.length > 4) {
    const mags = midBins.map(b => b.magnitude + 1e-10);
    const logSum = mags.reduce((s, m) => s + Math.log(m), 0);
    const geomMean = Math.exp(logSum / mags.length);
    const arithMean = mags.reduce((s, m) => s + m, 0) / mags.length;
    spectralFlatness = geomMean / arithMean;
    if (spectralFlatness > 0.12) {
      noise_enabled = true;
      // Spectral centroid of mid-high range → noise period (0=bright, 31=dark)
      const centroid = midBins.reduce((s, b) => s + b.freq * b.magnitude, 0) /
                       midBins.reduce((s, b) => s + b.magnitude, 0);
      noise_period = Math.max(0, Math.min(31, Math.round(31 - (centroid - 200) / (12000 - 200) * 31)));
    }
  }

  // ── 5. Pitch drift → sweep ───────────────────────────────────────────────
  let pitch_sweep_delta = 0;
  let pitch_sweep_duration_frames = 0;
  let pitchDriftSemitones = 0;
  if (region.length >= 512) {
    const q = Math.floor(region.length / 4);
    const N = Math.min(q, 2048);
    const { hz: hzStart } = findFundamental(region.slice(0, N), sr);
    const { hz: hzEnd } = findFundamental(region.slice(region.length - N), sr);
    pitchDriftSemitones = 12 * Math.log2(hzEnd / Math.max(hzStart, 1));
    if (Math.abs(pitchDriftSemitones) > 0.3) {
      // Convert to AY period delta per frame
      const p0 = Math.round(88200 / Math.max(hzStart, 1));
      const p1 = Math.round(88200 / Math.max(hzEnd, 1));
      pitch_sweep_delta = Math.max(-127, Math.min(127, Math.round((p1 - p0) / Math.max(1, durationFrames))));
      pitch_sweep_duration_frames = durationFrames;
    }
  }

  return {
    fundamentalHz, midiNote, durationFrames, suggestedVolume,
    arpeggio_count, arpeggio_speed_frames, arpeggio_intervals,
    noise_enabled, noise_period,
    pitch_sweep_delta, pitch_sweep_duration_frames,
    harmonicsFound, spectralFlatness, pitchDriftSemitones,
  };
}

// ============================================
// Sub-components
// ============================================

interface SliderProps {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  unit?: string;
  onChange: (v: number) => void;
}

const Slider: React.FC<SliderProps> = ({ label, value, min, max, step = 1, unit = '', onChange }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
    <label style={{ width: 90, fontSize: 12, color: '#aaa', flexShrink: 0 }}>{label}</label>
    <input
      type="range"
      min={min}
      max={max}
      step={step}
      value={value}
      onChange={e => onChange(Number(e.target.value))}
      style={{ flex: 1 }}
    />
    <span style={{ width: 55, fontSize: 11, color: '#666', textAlign: 'right', flexShrink: 0 }}>
      {value}{unit}
    </span>
  </div>
);

// ============================================
// Piano keyboard
// ============================================

interface PianoKeyboardProps {
  activeNote: number | null;
  onNotePlay: (midi: number) => void;
}

const PianoKeyboard: React.FC<PianoKeyboardProps> = ({ activeNote, onNotePlay }) => {
  const [pressedNote, setPressedNote] = useState<number | null>(null);

  // Build white key list
  const whiteKeys: number[] = [];
  for (let m = MIDI_START; m <= MIDI_END; m++) {
    if (!BLACK_SEMITONES.has(m % 12)) whiteKeys.push(m);
  }

  const whiteKeyWidth = 22;
  const whiteKeyHeight = 64;
  const blackKeyWidth = 14;
  const blackKeyHeight = 40;
  const totalWidth = whiteKeys.length * whiteKeyWidth;

  // Map each midi note to an x position
  const noteToX: Record<number, number> = {};
  let wIdx = 0;
  for (let m = MIDI_START; m <= MIDI_END; m++) {
    const semi = m % 12;
    if (!BLACK_SEMITONES.has(semi)) {
      noteToX[m] = wIdx * whiteKeyWidth;
      wIdx++;
    }
  }
  // Black key positions: offset relative to previous white key
  const blackOffsets: Record<number, number> = { 1: 0.6, 3: 0.7, 6: 0.6, 8: 0.65, 10: 0.7 };
  for (let m = MIDI_START; m <= MIDI_END; m++) {
    const semi = m % 12;
    if (BLACK_SEMITONES.has(semi)) {
      const prevWhite = m - 1; // always a white key below a black key
      const baseX = noteToX[prevWhite] ?? 0;
      const offset = blackOffsets[semi] ?? 0.6;
      noteToX[m] = baseX + whiteKeyWidth * offset;
    }
  }

  const handlePress = (midi: number) => {
    setPressedNote(midi);
    onNotePlay(midi);
  };
  const handleRelease = () => setPressedNote(null);

  return (
    <div style={{ position: 'relative', height: whiteKeyHeight + 4, width: totalWidth, userSelect: 'none' }}>
      {/* White keys */}
      {whiteKeys.map(m => {
        const isActive = m === activeNote || m === pressedNote;
        return (
          <div
            key={m}
            onMouseDown={() => handlePress(m)}
            onMouseUp={handleRelease}
            onMouseLeave={handleRelease}
            title={midiToName(m)}
            style={{
              position: 'absolute',
              left: noteToX[m],
              top: 0,
              width: whiteKeyWidth - 1,
              height: whiteKeyHeight,
              background: isActive ? '#b3d9ff' : '#f0f0f0',
              border: '1px solid #888',
              borderRadius: '0 0 3px 3px',
              cursor: 'pointer',
              boxSizing: 'border-box',
              zIndex: 1,
            }}
          />
        );
      })}
      {/* Black keys */}
      {Array.from({ length: MIDI_END - MIDI_START + 1 }, (_, i) => MIDI_START + i)
        .filter(m => BLACK_SEMITONES.has(m % 12))
        .map(m => {
          const isActive = m === activeNote || m === pressedNote;
          return (
            <div
              key={m}
              onMouseDown={() => handlePress(m)}
              onMouseUp={handleRelease}
              onMouseLeave={handleRelease}
              title={midiToName(m)}
              style={{
                position: 'absolute',
                left: noteToX[m],
                top: 0,
                width: blackKeyWidth,
                height: blackKeyHeight,
                background: isActive ? '#5599cc' : '#222',
                border: '1px solid #000',
                borderRadius: '0 0 3px 3px',
                cursor: 'pointer',
                boxSizing: 'border-box',
                zIndex: 2,
              }}
            />
          );
        })}
    </div>
  );
};

// ============================================
// Analyze tab
// ============================================

interface AnalyzeTabProps {
  onApply: (result: AnalysisResult) => void;
  instr: InstrResource;
}

type DragMode = 'select' | 'handle-start' | 'handle-end' | null;

const AnalyzeTab: React.FC<AnalyzeTabProps> = ({ onApply, instr }) => {
  const [audioBuffer, setAudioBuffer] = useState<AudioBuffer | null>(null);
  const [fileName, setFileName] = useState<string>('');
  const [duration, setDuration] = useState<number>(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [loopMode, setLoopMode] = useState(false);
  const [regionStart, setRegionStart] = useState<number>(0);
  const [regionEnd, setRegionEnd] = useState<number>(0.5);
  const [analysisResult, setAnalysisResult] = useState<AnalysisResult | null>(null);
  const [isDragOver, setIsDragOver] = useState(false);

  // Zoom/pan state: viewStart + viewDuration define the visible window in seconds
  const [viewStart, setViewStart] = useState(0);
  const [viewDuration, setViewDuration] = useState(1);

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const playSourceRef = useRef<AudioBufferSourceNode | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const dragModeRef = useRef<DragMode>(null);
  const dragStartXRef = useRef(0);
  const dragStartTimeRef = useRef(0);

  const getAudioCtx = useCallback(() => {
    if (!audioCtxRef.current) {
      const AudioCtxClass: typeof AudioContext =
        window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      audioCtxRef.current = new AudioCtxClass();
    }
    return audioCtxRef.current;
  }, []);

  const loadFile = useCallback(async (file: File) => {
    const arrayBuffer = await file.arrayBuffer();
    const ctx = getAudioCtx();
    try {
      const buf = await ctx.decodeAudioData(arrayBuffer);
      setAudioBuffer(buf);
      setFileName(file.name);
      setDuration(buf.duration);
      setRegionStart(0);
      setRegionEnd(Math.min(0.5, buf.duration));
      setViewStart(0);
      setViewDuration(buf.duration);
      setAnalysisResult(null);
    } catch {
      alert('Could not decode audio file. Supported formats: .wav, .mp3, .ogg');
    }
  }, [getAudioCtx]);

  // Canvas pixel x → time in seconds (within current view)
  const xToTime = useCallback((x: number, canvasW: number): number => {
    return viewStart + (x / canvasW) * viewDuration;
  }, [viewStart, viewDuration]);

  // Time → canvas x
  const timeToX = useCallback((t: number, canvasW: number): number => {
    return ((t - viewStart) / viewDuration) * canvasW;
  }, [viewStart, viewDuration]);

  // Draw waveform
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !audioBuffer) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const w = canvas.width;
    const h = canvas.height;
    const sr = audioBuffer.sampleRate;
    const data = audioBuffer.getChannelData(0);
    const mid = h / 2;

    ctx.fillStyle = '#0a1628';
    ctx.fillRect(0, 0, w, h);

    // Draw waveform for current view window
    ctx.strokeStyle = '#4db8ff';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let px = 0; px < w; px++) {
      const t0 = viewStart + (px / w) * viewDuration;
      const t1 = viewStart + ((px + 1) / w) * viewDuration;
      const s0 = Math.max(0, Math.floor(t0 * sr));
      const s1 = Math.min(data.length, Math.ceil(t1 * sr));
      let min = 1, max = -1;
      for (let s = s0; s < s1; s++) {
        if (data[s] < min) min = data[s];
        if (data[s] > max) max = data[s];
      }
      if (s1 <= s0) { min = 0; max = 0; }
      ctx.moveTo(px, mid + min * mid * 0.95);
      ctx.lineTo(px, mid + max * mid * 0.95);
    }
    ctx.stroke();

    // Selection region overlay
    if (duration > 0) {
      const x1 = Math.max(0, timeToX(regionStart, w));
      const x2 = Math.min(w, timeToX(regionEnd, w));
      if (x2 > x1) {
        ctx.fillStyle = 'rgba(255, 200, 0, 0.15)';
        ctx.fillRect(x1, 0, x2 - x1, h);
      }
      // Start handle
      if (x1 >= 0 && x1 <= w) {
        ctx.strokeStyle = '#ffd700';
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(x1, 0); ctx.lineTo(x1, h); ctx.stroke();
        // Triangle handle
        ctx.fillStyle = '#ffd700';
        ctx.beginPath(); ctx.moveTo(x1, 0); ctx.lineTo(x1 + 8, 0); ctx.lineTo(x1, 12); ctx.closePath(); ctx.fill();
      }
      // End handle
      if (x2 >= 0 && x2 <= w) {
        ctx.strokeStyle = '#ffd700';
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(x2, 0); ctx.lineTo(x2, h); ctx.stroke();
        ctx.fillStyle = '#ffd700';
        ctx.beginPath(); ctx.moveTo(x2, 0); ctx.lineTo(x2 - 8, 0); ctx.lineTo(x2, 12); ctx.closePath(); ctx.fill();
      }
    }

    // Timecode ruler at bottom
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillRect(0, h - 14, w, 14);
    ctx.fillStyle = '#667';
    ctx.font = '9px monospace';
    ctx.textAlign = 'left';
    const tickCount = Math.max(2, Math.floor(w / 60));
    for (let i = 0; i <= tickCount; i++) {
      const t = viewStart + (i / tickCount) * viewDuration;
      const px = (i / tickCount) * w;
      ctx.fillText(t.toFixed(2) + 's', px + 2, h - 3);
    }
  }, [audioBuffer, regionStart, regionEnd, duration, viewStart, viewDuration, timeToX]);

  // Canvas mouse events
  const getCanvasX = (e: React.MouseEvent<HTMLCanvasElement>): number => {
    const canvas = canvasRef.current!;
    const rect = canvas.getBoundingClientRect();
    return (e.clientX - rect.left) * (canvas.width / rect.width);
  };

  const handleCanvasMouseDown = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!audioBuffer) return;
    e.preventDefault();
    const x = getCanvasX(e);
    const w = canvasRef.current!.width;
    const t = xToTime(x, w);

    // Check if near a handle (within 8px)
    const x1 = timeToX(regionStart, w);
    const x2 = timeToX(regionEnd, w);
    if (Math.abs(x - x1) < 8) {
      dragModeRef.current = 'handle-start';
    } else if (Math.abs(x - x2) < 8) {
      dragModeRef.current = 'handle-end';
    } else {
      dragModeRef.current = 'select';
      setRegionStart(Math.max(0, Math.min(t, duration)));
      setRegionEnd(Math.max(0, Math.min(t, duration)));
    }
    dragStartXRef.current = x;
    dragStartTimeRef.current = t;
  }, [audioBuffer, xToTime, timeToX, regionStart, regionEnd, duration]);

  const handleCanvasMouseMove = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!dragModeRef.current) return;
    const x = getCanvasX(e);
    const w = canvasRef.current!.width;
    const t = Math.max(0, Math.min(duration, xToTime(x, w)));

    if (dragModeRef.current === 'handle-start') {
      setRegionStart(Math.min(t, regionEnd - 0.001));
    } else if (dragModeRef.current === 'handle-end') {
      setRegionEnd(Math.max(t, regionStart + 0.001));
    } else {
      // select: anchor is dragStartTimeRef
      const anchor = dragStartTimeRef.current;
      if (t >= anchor) {
        setRegionStart(anchor);
        setRegionEnd(Math.max(t, anchor + 0.001));
      } else {
        setRegionStart(Math.max(0, t));
        setRegionEnd(anchor);
      }
    }
  }, [duration, xToTime, regionStart, regionEnd]);

  const handleCanvasMouseUp = useCallback(() => {
    dragModeRef.current = null;
  }, []);

  // Cursor style based on proximity to handles
  const [canvasCursor, setCanvasCursor] = useState<string>('crosshair');
  const handleCanvasMouseMoveForCursor = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    if (dragModeRef.current) {
      handleCanvasMouseMove(e);
      return;
    }
    const x = getCanvasX(e);
    const w = canvasRef.current!.width;
    const x1 = timeToX(regionStart, w);
    const x2 = timeToX(regionEnd, w);
    if (Math.abs(x - x1) < 8 || Math.abs(x - x2) < 8) {
      setCanvasCursor('ew-resize');
    } else {
      setCanvasCursor('crosshair');
    }
  }, [handleCanvasMouseMove, timeToX, regionStart, regionEnd]);

  // Zoom with mouse wheel; shift+wheel = pan
  const handleWheel = useCallback((e: React.WheelEvent<HTMLCanvasElement>) => {
    e.preventDefault();
    if (!audioBuffer) return;
    const x = getCanvasX(e);
    const w = canvasRef.current!.width;

    if (e.shiftKey) {
      // Pan
      const panDelta = (e.deltaY / w) * viewDuration * 3;
      const newStart = Math.max(0, Math.min(duration - viewDuration, viewStart + panDelta));
      setViewStart(newStart);
    } else {
      // Zoom centered on cursor
      const tAtCursor = xToTime(x, w);
      const xFrac = x / w;
      const factor = e.deltaY > 0 ? 1.5 : 1 / 1.5;
      const newDur = Math.max(0.02, Math.min(duration, viewDuration * factor));
      const newStart = Math.max(0, Math.min(duration - newDur, tAtCursor - xFrac * newDur));
      setViewDuration(newDur);
      setViewStart(newStart);
    }
  }, [audioBuffer, viewStart, viewDuration, duration, xToTime]);

  const resetZoom = useCallback(() => {
    setViewStart(0);
    setViewDuration(duration);
  }, [duration]);

  const zoomToSelection = useCallback(() => {
    const margin = (regionEnd - regionStart) * 0.1;
    const newStart = Math.max(0, regionStart - margin);
    const newEnd = Math.min(duration, regionEnd + margin);
    setViewStart(newStart);
    setViewDuration(newEnd - newStart);
  }, [regionStart, regionEnd, duration]);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragOver(false);
    const file = e.dataTransfer.files[0];
    if (file) loadFile(file);
  }, [loadFile]);

  const handlePlay = useCallback(() => {
    if (!audioBuffer) return;
    const ctx = getAudioCtx();
    if (playSourceRef.current) {
      try { playSourceRef.current.stop(); } catch {}
    }
    const src = ctx.createBufferSource();
    src.buffer = audioBuffer;
    src.connect(ctx.destination);
    if (loopMode) {
      src.loop = true;
      src.loopStart = regionStart;
      src.loopEnd = regionEnd;
      src.start(ctx.currentTime, regionStart);
    } else {
      src.start(ctx.currentTime, regionStart, regionEnd - regionStart);
      src.onended = () => setIsPlaying(false);
    }
    playSourceRef.current = src;
    setIsPlaying(true);
  }, [audioBuffer, getAudioCtx, regionStart, regionEnd, loopMode]);

  const handleStop = useCallback(() => {
    if (playSourceRef.current) {
      try { playSourceRef.current.stop(); } catch {}
      playSourceRef.current = null;
    }
    setIsPlaying(false);
  }, []);

  const handleAnalyze = useCallback(async () => {
    if (!audioBuffer) return;
    const result = await analyzeRegion(audioBuffer, regionStart, regionEnd);
    setAnalysisResult(result);
  }, [audioBuffer, regionStart, regionEnd]);

  const noteLabel = useMemo(() => {
    if (!analysisResult) return '';
    const { midiNote } = analysisResult;
    if (midiNote < 0 || midiNote > 127) return `MIDI ${midiNote}`;
    return `${midiToName(midiNote)} (MIDI ${midiNote})`;
  }, [analysisResult]);

  const zoomRatio = duration > 0 ? (viewDuration / duration) : 1;

  return (
    <div style={{ padding: 16, color: '#ccc', fontSize: 13, display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: '#888', letterSpacing: 1 }}>AUDIO ANALYZER</div>

      {/* Drop zone */}
      <div
        onDragOver={e => { e.preventDefault(); setIsDragOver(true); }}
        onDragLeave={() => setIsDragOver(false)}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current?.click()}
        style={{
          border: `2px dashed ${isDragOver ? '#4db8ff' : '#444'}`,
          borderRadius: 6,
          padding: '14px 12px',
          textAlign: 'center',
          cursor: 'pointer',
          background: isDragOver ? '#0a2040' : '#111827',
          transition: 'all 0.15s',
        }}
      >
        {fileName
          ? <span style={{ color: '#4db8ff' }}>{fileName} ({duration.toFixed(2)}s)</span>
          : <>
              <div style={{ marginBottom: 4 }}>Drop a .wav / .mp3 file here</div>
              <div style={{ fontSize: 11, color: '#555' }}>or click to Browse</div>
            </>
        }
        <input
          ref={fileInputRef}
          type="file"
          accept=".wav,.mp3,.ogg,.flac"
          style={{ display: 'none' }}
          onChange={e => { const f = e.target.files?.[0]; if (f) loadFile(f); }}
        />
      </div>

      {/* Waveform */}
      {audioBuffer && (
        <>
          {/* Zoom controls */}
          <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
            <span style={{ fontSize: 11, color: '#555' }}>Zoom:</span>
            <button onClick={() => { const f = 1/1.5; const c = viewStart + viewDuration/2; const d = Math.max(0.02, viewDuration*f); setViewDuration(d); setViewStart(Math.max(0, c - d/2)); }}
              style={{ padding: '2px 8px', background: '#1a2a3a', color: '#aaa', border: '1px solid #334', borderRadius: 3, cursor: 'pointer', fontSize: 12 }}>+</button>
            <button onClick={() => { const f = 1.5; const c = viewStart + viewDuration/2; const d = Math.min(duration, viewDuration*f); setViewDuration(d); setViewStart(Math.max(0, c - d/2)); }}
              style={{ padding: '2px 8px', background: '#1a2a3a', color: '#aaa', border: '1px solid #334', borderRadius: 3, cursor: 'pointer', fontSize: 12 }}>−</button>
            <button onClick={zoomToSelection}
              style={{ padding: '2px 8px', background: '#1a2a3a', color: '#aaa', border: '1px solid #334', borderRadius: 3, cursor: 'pointer', fontSize: 11 }}>Fit selection</button>
            <button onClick={resetZoom}
              style={{ padding: '2px 8px', background: '#1a2a3a', color: '#aaa', border: '1px solid #334', borderRadius: 3, cursor: 'pointer', fontSize: 11 }}>Full view</button>
            <span style={{ fontSize: 10, color: '#445', marginLeft: 4 }}>
              {(zoomRatio * 100).toFixed(0)}% · scroll=zoom · shift+scroll=pan
            </span>
          </div>

          <canvas
            ref={canvasRef}
            width={800}
            height={100}
            style={{ border: '1px solid #223', borderRadius: 4, width: '100%', height: 100, cursor: canvasCursor, userSelect: 'none' }}
            onMouseDown={handleCanvasMouseDown}
            onMouseMove={handleCanvasMouseMoveForCursor}
            onMouseUp={handleCanvasMouseUp}
            onMouseLeave={handleCanvasMouseUp}
            onWheel={handleWheel}
          />

          {/* Selection info */}
          <div style={{ fontSize: 11, color: '#556', display: 'flex', gap: 16 }}>
            <span>Selection: <b style={{ color: '#aaa' }}>{regionStart.toFixed(3)}s – {regionEnd.toFixed(3)}s</b></span>
            <span>Length: <b style={{ color: '#aaa' }}>{(regionEnd - regionStart).toFixed(3)}s</b></span>
            <span style={{ color: '#334' }}>Drag to select · drag yellow handles to resize</span>
          </div>

          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
            <button
              onClick={isPlaying ? handleStop : handlePlay}
              style={{
                padding: '5px 14px',
                background: isPlaying ? '#c44' : '#1d4ed8',
                color: '#fff',
                border: 'none', borderRadius: 4, cursor: 'pointer', fontSize: 12,
              }}
            >
              {isPlaying ? '⏹ Stop' : '▶ Play selection'}
            </button>
            <button
              onClick={() => {
                setLoopMode(l => {
                  if (isPlaying) {
                    if (playSourceRef.current) { try { playSourceRef.current.stop(); } catch {} }
                    setIsPlaying(false);
                  }
                  return !l;
                });
              }}
              style={{
                padding: '5px 14px',
                background: loopMode ? '#2d6a2d' : '#1a2a1a',
                color: loopMode ? '#7fff7f' : '#668',
                border: `1px solid ${loopMode ? '#2ed573' : '#334'}`,
                borderRadius: 4, cursor: 'pointer', fontSize: 12,
              }}
            >
              ↺ Loop {loopMode ? 'ON' : 'OFF'}
            </button>
            <button
              onClick={handleAnalyze}
              style={{
                padding: '5px 14px', background: '#2ed573', color: '#000',
                border: 'none', borderRadius: 4, cursor: 'pointer',
                fontWeight: 600, fontSize: 12,
              }}
            >
              Analyze selection
            </button>
            {analysisResult && (
              <button
                onClick={() => playNotePreview(analysisResult.midiNote, instr)}
                style={{
                  padding: '5px 14px',
                  background: '#1a3a2a',
                  color: '#2ed573',
                  border: '1px solid #2ed573',
                  borderRadius: 4, cursor: 'pointer', fontSize: 12,
                }}
                title={`Play .vinstr at detected note (${midiToName(analysisResult.midiNote)})`}
              >
                ▶ .vinstr ({midiToName(analysisResult.midiNote)})
              </button>
            )}
          </div>
        </>
      )}

      {/* Results */}
      {analysisResult && (
        <div style={{ background: '#0f1c2e', border: '1px solid #1d4ed8', borderRadius: 6, padding: 12, fontSize: 12 }}>
          <div style={{ fontWeight: 600, color: '#4db8ff', marginBottom: 10 }}>Analysis Results</div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px 16px', marginBottom: 10 }}>
            <div><span style={{ color: '#556' }}>Fundamental:</span> <b style={{ color: '#ccc' }}>{analysisResult.fundamentalHz.toFixed(1)} Hz · {noteLabel}</b></div>
            <div><span style={{ color: '#556' }}>Volume:</span> <b style={{ color: '#ccc' }}>{analysisResult.suggestedVolume} / 15</b></div>
            <div><span style={{ color: '#556' }}>Duration:</span> <b style={{ color: '#ccc' }}>{analysisResult.durationFrames} frames ({(analysisResult.durationFrames/50).toFixed(2)}s)</b></div>
            <div>
              <span style={{ color: '#556' }}>Noise:</span>{' '}
              <b style={{ color: analysisResult.noise_enabled ? '#f90' : '#556' }}>
                {analysisResult.noise_enabled ? `YES  period=${analysisResult.noise_period}  (flatness=${analysisResult.spectralFlatness.toFixed(2)})` : `no (flatness=${analysisResult.spectralFlatness.toFixed(2)})`}
              </b>
            </div>
            <div>
              <span style={{ color: '#556' }}>Harmonics found:</span>{' '}
              <b style={{ color: analysisResult.harmonicsFound.length ? '#2ed573' : '#556' }}>
                {analysisResult.harmonicsFound.length
                  ? analysisResult.harmonicsFound.map(s => `+${s}st`).join(', ')
                  : 'none'}
              </b>
            </div>
            <div>
              <span style={{ color: '#556' }}>Arpeggio:</span>{' '}
              <b style={{ color: '#ccc' }}>
                {analysisResult.arpeggio_count > 0
                  ? `${analysisResult.arpeggio_count} steps  [${analysisResult.arpeggio_intervals.slice(0, analysisResult.arpeggio_count).join(', ')}]`
                  : 'off'}
              </b>
            </div>
            <div>
              <span style={{ color: '#556' }}>Pitch drift:</span>{' '}
              <b style={{ color: Math.abs(analysisResult.pitchDriftSemitones) > 0.3 ? '#f90' : '#556' }}>
                {analysisResult.pitchDriftSemitones.toFixed(2)} st
                {analysisResult.pitch_sweep_delta !== 0 && ` → sweep Δ${analysisResult.pitch_sweep_delta}`}
              </b>
            </div>
          </div>

          <div style={{ fontSize: 10, color: '#334', marginBottom: 10, borderTop: '1px solid #1a2a3a', paddingTop: 8 }}>
            Note: AY-3-8910 can only produce square waves. Arpeggio simulates harmonics by cycling through semitone intervals rapidly.
            The result is an approximation — tune manually in the Edit tab for best results.
          </div>

          <button
            onClick={() => onApply(analysisResult)}
            style={{
              padding: '6px 16px', background: '#0f3460', color: '#4db8ff',
              border: '1px solid #1d4ed8', borderRadius: 4,
              cursor: 'pointer', fontSize: 12, fontWeight: 600,
            }}
          >
            Apply all to Instrument
          </button>
        </div>
      )}
    </div>
  );
};

// ============================================
// Main component
// ============================================

export const InstrumentEditor: React.FC<InstrumentEditorProps> = ({ resource, onChange }) => {
  const [instr, setInstr] = useState<InstrResource>(resource ?? defaultInstr());
  const [activeTab, setActiveTab] = useState<EditorTab>('edit');
  const [previewNote, setPreviewNote] = useState<number | null>(null);

  // Sync from external resource prop
  useEffect(() => {
    if (resource) setInstr(resource);
  }, [resource]);

  // Update helpers
  const update = useCallback((updates: Partial<InstrResource>) => {
    setInstr(prev => {
      const next = { ...prev, ...updates };
      onChange?.(next);
      return next;
    });
  }, [onChange]);

  const loadPreset = useCallback((name: PresetName) => {
    const merged: InstrResource = { ...instr, name: instr.name, ...PRESETS[name] };
    setInstr(merged);
    onChange?.(merged);
  }, [instr, onChange]);

  // Piano key handler
  const handleKeyPlay = useCallback((midi: number) => {
    setPreviewNote(midi);
    playNotePreview(midi, instr);
  }, [instr]);

  // Analyze tab apply handler — maps all detected spectral properties to AY-3-8910 params
  const handleAnalyzeApply = useCallback((result: AnalysisResult) => {
    update({
      volume: Math.min(15, Math.max(0, result.suggestedVolume)),
      duration_frames: Math.min(255, Math.max(1, result.durationFrames)),
      arpeggio_count: result.arpeggio_count,
      arpeggio_speed_frames: result.arpeggio_speed_frames,
      arpeggio_intervals: result.arpeggio_intervals,
      noise_enabled: result.noise_enabled,
      noise_period: result.noise_period,
      pitch_sweep_delta: result.pitch_sweep_delta,
      pitch_sweep_duration_frames: result.pitch_sweep_duration_frames,
    });
    setActiveTab('edit');
    setPreviewNote(result.midiNote);
  }, [update]);

  // Section header style helper
  const sectionHeader = (label: string) => (
    <div style={{
      fontSize: 10, fontWeight: 700, color: '#556',
      letterSpacing: 1.5, textTransform: 'uppercase',
      borderBottom: '1px solid #1e2a3a', paddingBottom: 4, marginBottom: 10, marginTop: 4,
    }}>
      {label}
    </div>
  );

  return (
    <div style={{
      backgroundColor: '#16213e',
      color: '#fff',
      fontFamily: 'system-ui, sans-serif',
      display: 'flex',
      flexDirection: 'column',
      width: '100%',
      minHeight: 0,
      height: '100%',
    }}>
      {/* Header bar */}
      <div style={{
        padding: '8px 12px',
        borderBottom: '1px solid #1e2a3a',
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        flexShrink: 0,
      }}>
        <span style={{ fontWeight: 700, fontSize: 14, color: '#4db8ff' }}>Instrument Editor</span>
        <input
          type="text"
          value={instr.name}
          onChange={e => update({ name: e.target.value })}
          style={{
            flex: 1,
            maxWidth: 200,
            backgroundColor: '#0f1c2e',
            border: '1px solid #2a3a5a',
            borderRadius: 4,
            color: '#fff',
            padding: '3px 8px',
            fontSize: 12,
          }}
          placeholder="Instrument name"
        />
        <div style={{ display: 'flex', gap: 4, marginLeft: 'auto' }}>
          {(['edit', 'analyze'] as EditorTab[]).map(tab => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              style={{
                padding: '4px 12px',
                background: activeTab === tab ? '#0f3460' : 'transparent',
                color: activeTab === tab ? '#4db8ff' : '#666',
                border: `1px solid ${activeTab === tab ? '#1d4ed8' : '#333'}`,
                borderRadius: 4,
                cursor: 'pointer',
                fontSize: 12,
                textTransform: 'capitalize',
              }}
            >
              {tab === 'edit' ? 'Edit' : 'Analyze'}
            </button>
          ))}
        </div>
      </div>

      {/* Content area */}
      <div style={{ flex: 1, overflowY: 'auto', minHeight: 0 }}>
        {activeTab === 'analyze' ? (
          <AnalyzeTab onApply={handleAnalyzeApply} instr={instr} />
        ) : (
          <>
            {/* Two-column layout */}
            <div style={{ display: 'flex', flex: 1, minHeight: 0 }}>

              {/* Left column — Basic + Presets + Piano */}
              <div style={{ flex: 1, padding: '12px 16px', borderRight: '1px solid #1e2a3a', display: 'flex', flexDirection: 'column', gap: 0 }}>
                {sectionHeader('Basic')}
                <Slider label="Duration" value={instr.duration_frames} min={1} max={255} unit=" fr" onChange={v => update({ duration_frames: v })} />
                <Slider label="Volume" value={instr.volume} min={0} max={15} onChange={v => update({ volume: v })} />

                {sectionHeader('Presets')}
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5, marginBottom: 20 }}>
                  {(Object.keys(PRESETS) as PresetName[]).map(name => (
                    <button
                      key={name}
                      onClick={() => loadPreset(name)}
                      style={{
                        padding: '3px 10px',
                        background: '#0f3460',
                        color: '#4db8ff',
                        border: '1px solid #1d4ed8',
                        borderRadius: 3,
                        fontSize: 11,
                        cursor: 'pointer',
                        textTransform: 'capitalize',
                      }}
                    >
                      {name}
                    </button>
                  ))}
                </div>

                {sectionHeader('Preview — click a key to play')}
                <div style={{ overflowX: 'auto' }}>
                  <PianoKeyboard activeNote={previewNote} onNotePlay={handleKeyPlay} />
                </div>
                {previewNote !== null && (
                  <div style={{ marginTop: 6, fontSize: 11, color: '#666' }}>
                    Playing: {midiToName(previewNote)}
                  </div>
                )}
              </div>

              {/* Right column — Arpeggio + Effects + Pitch Sweep */}
              <div style={{ flex: 1, padding: '12px 16px', display: 'flex', flexDirection: 'column' }}>
                {sectionHeader('Arpeggio')}
                <Slider label="Count" value={instr.arpeggio_count} min={0} max={4} onChange={v => update({ arpeggio_count: v })} />
                <Slider label="Speed" value={instr.arpeggio_speed_frames} min={1} max={16} unit=" fr" onChange={v => update({ arpeggio_speed_frames: v })} />

                {instr.arpeggio_count > 0 && (
                  <div style={{ marginTop: 4, marginBottom: 8 }}>
                    <div style={{ fontSize: 10, color: '#556', marginBottom: 6 }}>
                      INTERVALS (semitones, -12..+12)
                    </div>
                    {instr.arpeggio_intervals.slice(0, instr.arpeggio_count).map((val, idx) => (
                      <div key={idx} style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
                        <span style={{ fontSize: 11, color: '#888', width: 18 }}>+{idx}</span>
                        <input
                          type="range"
                          min={-12}
                          max={12}
                          step={1}
                          value={val}
                          onChange={e => {
                            const arr = [...instr.arpeggio_intervals];
                            arr[idx] = Number(e.target.value);
                            update({ arpeggio_intervals: arr });
                          }}
                          style={{ flex: 1 }}
                        />
                        <span style={{ width: 28, fontSize: 11, color: '#666', textAlign: 'right' }}>
                          {val > 0 ? `+${val}` : val}
                        </span>
                      </div>
                    ))}
                    {instr.arpeggio_intervals.slice(instr.arpeggio_count).map((val, idx) => (
                      <div key={idx + instr.arpeggio_count} style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6, opacity: 0.3 }}>
                        <span style={{ fontSize: 11, color: '#888', width: 18 }}>+{idx + instr.arpeggio_count}</span>
                        <input type="range" min={-12} max={12} value={val} disabled style={{ flex: 1 }} />
                        <span style={{ width: 28, fontSize: 11, color: '#444', textAlign: 'right' }}>
                          {val > 0 ? `+${val}` : val}
                        </span>
                      </div>
                    ))}
                  </div>
                )}

                {sectionHeader('Effects')}
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                  <label style={{ fontSize: 12, color: '#aaa' }}>Noise</label>
                  <button
                    onClick={() => update({ noise_enabled: !instr.noise_enabled })}
                    style={{
                      padding: '2px 10px',
                      background: instr.noise_enabled ? '#2ed573' : '#333',
                      color: instr.noise_enabled ? '#000' : '#666',
                      border: 'none', borderRadius: 3, cursor: 'pointer', fontSize: 11,
                    }}
                  >
                    {instr.noise_enabled ? 'ON' : 'off'}
                  </button>
                </div>
                {instr.noise_enabled && (
                  <Slider label="Noise period" value={instr.noise_period} min={0} max={31} onChange={v => update({ noise_period: v })} />
                )}

                {sectionHeader('Pitch Sweep')}
                <Slider label="Delta"    value={instr.pitch_sweep_delta}           min={-127} max={127} onChange={v => update({ pitch_sweep_delta: v })} />
                <Slider label="Duration" value={instr.pitch_sweep_duration_frames} min={0}    max={255} unit=" fr" onChange={v => update({ pitch_sweep_duration_frames: v })} />
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default InstrumentEditor;
