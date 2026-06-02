/**
 * SFXEditor - AY-3-8910 PSG Sound Effects Editor
 * SFXR/BFXR-style parametric sound generator for Vectrex
 *
 * Features:
 * - Visual envelope editor (ADSR)
 * - Pitch sweep visualization
 * - Noise mixing controls
 * - Preset sounds (Laser, Explosion, Powerup, Hit, Jump, Blip)
 * - Real-time preview using Web Audio API
 */

import React, { useRef, useEffect, useState, useCallback, useMemo } from 'react';

// ============================================
// Types
// ============================================

export interface SfxResource {
  version: string;
  name: string;
  category: SfxCategory;
  duration_ms: number;
  oscillator: Oscillator;
  envelope: Envelope;
  pitch: PitchEnvelope;
  noise: NoiseSettings;
  modulation: Modulation;
}

export type SfxCategory = 'custom' | 'laser' | 'explosion' | 'powerup' | 'hit' | 'jump' | 'blip' | 'coin';

export interface Oscillator {
  frequency: number;
  channel: number;
  duty: number;
}

export interface Envelope {
  attack: number;
  decay: number;
  sustain: number;
  release: number;
  peak: number;
}

export interface PitchEnvelope {
  enabled: boolean;
  start_mult: number;
  end_mult: number;
  curve: number;
}

export interface NoiseSettings {
  enabled: boolean;
  period: number;
  volume: number;
  decay_ms: number;
}

export interface Modulation {
  arpeggio: boolean;
  arpeggio_notes: number[];
  arpeggio_speed: number;
  vibrato: boolean;
  vibrato_depth: number;
  vibrato_speed: number;
}

interface SFXEditorProps {
  resource?: SfxResource;
  onChange?: (resource: SfxResource) => void;
  width?: number;
  height?: number;
}

// ============================================
// Constants
// ============================================

const CATEGORY_COLORS: Record<SfxCategory, string> = {
  custom: '#888',
  laser: '#ff6b6b',
  explosion: '#ff9f43',
  powerup: '#2ed573',
  hit: '#ff4757',
  jump: '#1e90ff',
  blip: '#a55eea',
  coin: '#ffd700',
};

// ============================================
// Presets
// ============================================

function createDefaultSfx(): SfxResource {
  return {
    version: '1.0',
    name: 'untitled',
    category: 'custom',
    duration_ms: 200,
    oscillator: { frequency: 440, channel: 0, duty: 50 },
    envelope: { attack: 0, decay: 50, sustain: 8, release: 100, peak: 15 },
    pitch: { enabled: false, start_mult: 1.0, end_mult: 1.0, curve: 0 },
    noise: { enabled: false, period: 15, volume: 12, decay_ms: 100 },
    modulation: { arpeggio: false, arpeggio_notes: [], arpeggio_speed: 50, vibrato: false, vibrato_depth: 0, vibrato_speed: 8 },
  };
}

function presetLaser(): SfxResource {
  return {
    ...createDefaultSfx(),
    name: 'laser',
    category: 'laser',
    duration_ms: 150,
    oscillator: { frequency: 880, channel: 0, duty: 50 },
    envelope: { attack: 0, decay: 0, sustain: 12, release: 100, peak: 15 },
    pitch: { enabled: true, start_mult: 2.0, end_mult: 0.5, curve: -2 },
  };
}

function presetExplosion(): SfxResource {
  return {
    ...createDefaultSfx(),
    name: 'explosion',
    category: 'explosion',
    duration_ms: 400,
    oscillator: { frequency: 110, channel: 0, duty: 50 },
    envelope: { attack: 5, decay: 50, sustain: 4, release: 300, peak: 15 },
    pitch: { enabled: true, start_mult: 1.5, end_mult: 0.3, curve: -3 },
    noise: { enabled: true, period: 8, volume: 15, decay_ms: 350 },
  };
}

function presetPowerup(): SfxResource {
  return {
    ...createDefaultSfx(),
    name: 'powerup',
    category: 'powerup',
    duration_ms: 200,
    oscillator: { frequency: 440, channel: 0, duty: 50 },
    envelope: { attack: 0, decay: 20, sustain: 10, release: 100, peak: 15 },
    pitch: { enabled: true, start_mult: 0.8, end_mult: 1.5, curve: 2 },
    modulation: { arpeggio: true, arpeggio_notes: [0, 4, 7, 12], arpeggio_speed: 40, vibrato: false, vibrato_depth: 0, vibrato_speed: 8 },
  };
}

function presetHit(): SfxResource {
  return {
    ...createDefaultSfx(),
    name: 'hit',
    category: 'hit',
    duration_ms: 100,
    oscillator: { frequency: 220, channel: 0, duty: 50 },
    envelope: { attack: 0, decay: 10, sustain: 6, release: 50, peak: 15 },
    noise: { enabled: true, period: 12, volume: 14, decay_ms: 80 },
  };
}

function presetJump(): SfxResource {
  return {
    ...createDefaultSfx(),
    name: 'jump',
    category: 'jump',
    duration_ms: 180,
    oscillator: { frequency: 330, channel: 0, duty: 50 },
    envelope: { attack: 0, decay: 30, sustain: 8, release: 100, peak: 14 },
    pitch: { enabled: true, start_mult: 0.6, end_mult: 1.3, curve: 1 },
  };
}

function presetBlip(): SfxResource {
  return {
    ...createDefaultSfx(),
    name: 'blip',
    category: 'blip',
    duration_ms: 50,
    oscillator: { frequency: 660, channel: 0, duty: 50 },
    envelope: { attack: 0, decay: 5, sustain: 10, release: 30, peak: 12 },
  };
}

function presetCoin(): SfxResource {
  return {
    ...createDefaultSfx(),
    name: 'coin',
    category: 'coin',
    duration_ms: 120,
    oscillator: { frequency: 880, channel: 0, duty: 50 },
    envelope: { attack: 0, decay: 10, sustain: 12, release: 80, peak: 15 },
    modulation: { arpeggio: true, arpeggio_notes: [0, 12], arpeggio_speed: 60, vibrato: false, vibrato_depth: 0, vibrato_speed: 8 },
  };
}

// ============================================
// Audio Preview (Web Audio API)
// ============================================

class SfxPlayer {
  private audioContext: AudioContext | null = null;
  private currentOscillator: OscillatorNode | null = null;
  private currentGain: GainNode | null = null;
  private noiseSource: AudioBufferSourceNode | null = null;
  private noiseGain: GainNode | null = null;

  private getAudioContext(): AudioContext {
    if (!this.audioContext) {
      this.audioContext = new AudioContext();
    }
    return this.audioContext;
  }

  stop() {
    if (this.currentOscillator) {
      try { this.currentOscillator.stop(); } catch {}
      this.currentOscillator = null;
    }
    if (this.noiseSource) {
      try { this.noiseSource.stop(); } catch {}
      this.noiseSource = null;
    }
  }

  play(sfx: SfxResource) {
    this.stop();
    const ctx = this.getAudioContext();
    const now = ctx.currentTime;
    const duration = sfx.duration_ms / 1000;

    // Main oscillator (square wave to simulate PSG)
    const osc = ctx.createOscillator();
    osc.type = 'square';
    
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);

    // Frequency with pitch envelope
    const baseFreq = sfx.oscillator.frequency;
    if (sfx.pitch.enabled) {
      const startFreq = baseFreq * sfx.pitch.start_mult;
      const endFreq = baseFreq * sfx.pitch.end_mult;
      osc.frequency.setValueAtTime(startFreq, now);
      osc.frequency.exponentialRampToValueAtTime(Math.max(endFreq, 20), now + duration);
    } else {
      osc.frequency.setValueAtTime(baseFreq, now);
    }

    // Amplitude envelope (ADSR)
    const peakVol = sfx.envelope.peak / 15;
    const sustainVol = (sfx.envelope.sustain / 15) * peakVol;
    const attackTime = sfx.envelope.attack / 1000;
    const decayTime = sfx.envelope.decay / 1000;
    const releaseTime = sfx.envelope.release / 1000;
    const sustainTime = Math.max(0, duration - attackTime - decayTime - releaseTime);

    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(peakVol, now + attackTime);
    gain.gain.linearRampToValueAtTime(sustainVol, now + attackTime + decayTime);
    gain.gain.setValueAtTime(sustainVol, now + attackTime + decayTime + sustainTime);
    gain.gain.linearRampToValueAtTime(0, now + duration);

    // Arpeggio (rapid frequency changes)
    if (sfx.modulation.arpeggio && sfx.modulation.arpeggio_notes.length > 0) {
      const arpSpeed = sfx.modulation.arpeggio_speed / 1000;
      let time = now;
      let noteIndex = 0;
      while (time < now + duration) {
        const semitone = sfx.modulation.arpeggio_notes[noteIndex % sfx.modulation.arpeggio_notes.length];
        const freq = baseFreq * Math.pow(2, semitone / 12);
        osc.frequency.setValueAtTime(freq, time);
        time += arpSpeed;
        noteIndex++;
      }
    }

    osc.start(now);
    osc.stop(now + duration + 0.1);
    this.currentOscillator = osc;
    this.currentGain = gain;

    // Noise layer
    if (sfx.noise.enabled) {
      const bufferSize = ctx.sampleRate * duration;
      const noiseBuffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
      const output = noiseBuffer.getChannelData(0);
      
      // Generate white noise filtered by period (lower period = higher freq content)
      const filterStrength = 1 - (sfx.noise.period / 31);
      for (let i = 0; i < bufferSize; i++) {
        output[i] = (Math.random() * 2 - 1) * filterStrength;
      }

      const noiseSource = ctx.createBufferSource();
      noiseSource.buffer = noiseBuffer;
      
      const noiseGain = ctx.createGain();
      const noiseVol = sfx.noise.volume / 15;
      const noiseDecay = sfx.noise.decay_ms / 1000;
      
      noiseGain.gain.setValueAtTime(noiseVol, now);
      noiseGain.gain.linearRampToValueAtTime(0, now + noiseDecay);

      noiseSource.connect(noiseGain);
      noiseGain.connect(ctx.destination);
      noiseSource.start(now);
      noiseSource.stop(now + duration);
      
      this.noiseSource = noiseSource;
      this.noiseGain = noiseGain;
    }
  }
}

const sfxPlayer = new SfxPlayer();

// ============================================
// Component
// ============================================

export const SFXEditor: React.FC<SFXEditorProps> = ({
  resource,
  onChange,
  width = 600,
  height = 500,
}) => {
  const [sfx, setSfx] = useState<SfxResource>(resource || createDefaultSfx());
  const [isPlaying, setIsPlaying] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  // Sync with external resource
  useEffect(() => {
    if (resource) {
      setSfx(resource);
    }
  }, [resource]);

  // Notify parent of changes
  const updateSfx = useCallback((updates: Partial<SfxResource>) => {
    setSfx(prev => {
      const next = { ...prev, ...updates };
      onChange?.(next);
      return next;
    });
  }, [onChange]);

  const updateOscillator = useCallback((updates: Partial<Oscillator>) => {
    setSfx(prev => {
      const next = { ...prev, oscillator: { ...prev.oscillator, ...updates } };
      onChange?.(next);
      return next;
    });
  }, [onChange]);

  const updateEnvelope = useCallback((updates: Partial<Envelope>) => {
    setSfx(prev => {
      const next = { ...prev, envelope: { ...prev.envelope, ...updates } };
      onChange?.(next);
      return next;
    });
  }, [onChange]);

  const updatePitch = useCallback((updates: Partial<PitchEnvelope>) => {
    setSfx(prev => {
      const next = { ...prev, pitch: { ...prev.pitch, ...updates } };
      onChange?.(next);
      return next;
    });
  }, [onChange]);

  const updateNoise = useCallback((updates: Partial<NoiseSettings>) => {
    setSfx(prev => {
      const next = { ...prev, noise: { ...prev.noise, ...updates } };
      onChange?.(next);
      return next;
    });
  }, [onChange]);

  // Play preview
  const handlePlay = useCallback(() => {
    setIsPlaying(true);
    sfxPlayer.play(sfx);
    setTimeout(() => setIsPlaying(false), sfx.duration_ms + 100);
  }, [sfx]);

  // Load preset
  const loadPreset = useCallback((preset: SfxCategory) => {
    let newSfx: SfxResource;
    switch (preset) {
      case 'laser': newSfx = presetLaser(); break;
      case 'explosion': newSfx = presetExplosion(); break;
      case 'powerup': newSfx = presetPowerup(); break;
      case 'hit': newSfx = presetHit(); break;
      case 'jump': newSfx = presetJump(); break;
      case 'blip': newSfx = presetBlip(); break;
      case 'coin': newSfx = presetCoin(); break;
      default: newSfx = createDefaultSfx(); break;
    }
    setSfx(newSfx);
    onChange?.(newSfx);
  }, [onChange]);

  // Draw envelope visualization
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const w = canvas.width;
    const h = canvas.height;
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, w, h);

    // Grid
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 10; i++) {
      const x = (i / 10) * w;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();
    }
    for (let i = 0; i <= 5; i++) {
      const y = (i / 5) * h;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    // Calculate envelope points
    const duration = sfx.duration_ms;
    const attack = sfx.envelope.attack;
    const decay = sfx.envelope.decay;
    const release = sfx.envelope.release;
    const sustain = Math.max(0, duration - attack - decay - release);
    
    const peakY = (1 - sfx.envelope.peak / 15) * h;
    const sustainY = (1 - (sfx.envelope.sustain / 15) * (sfx.envelope.peak / 15)) * h;

    const x1 = 0; // Start
    const x2 = (attack / duration) * w; // End of attack
    const x3 = ((attack + decay) / duration) * w; // End of decay
    const x4 = ((attack + decay + sustain) / duration) * w; // End of sustain
    const x5 = w; // End

    // Draw envelope
    ctx.beginPath();
    ctx.strokeStyle = CATEGORY_COLORS[sfx.category];
    ctx.lineWidth = 3;
    ctx.moveTo(x1, h); // Start at 0
    ctx.lineTo(x2, peakY); // Attack to peak
    ctx.lineTo(x3, sustainY); // Decay to sustain
    ctx.lineTo(x4, sustainY); // Sustain hold
    ctx.lineTo(x5, h); // Release to 0
    ctx.stroke();

    // Fill under curve
    ctx.beginPath();
    ctx.fillStyle = CATEGORY_COLORS[sfx.category] + '30';
    ctx.moveTo(x1, h);
    ctx.lineTo(x2, peakY);
    ctx.lineTo(x3, sustainY);
    ctx.lineTo(x4, sustainY);
    ctx.lineTo(x5, h);
    ctx.closePath();
    ctx.fill();

    // Pitch envelope overlay
    if (sfx.pitch.enabled) {
      ctx.beginPath();
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 2;
      ctx.setLineDash([5, 5]);
      
      const pitchStartY = (1 - Math.min(sfx.pitch.start_mult, 2) / 2) * h;
      const pitchEndY = (1 - Math.min(sfx.pitch.end_mult, 2) / 2) * h;
      
      ctx.moveTo(0, pitchStartY);
      ctx.lineTo(w, pitchEndY);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Noise overlay
    if (sfx.noise.enabled) {
      const noiseDecayX = (sfx.noise.decay_ms / duration) * w;
      ctx.fillStyle = '#ffffff20';
      ctx.fillRect(0, 0, noiseDecayX, h);
    }

    // Labels
    ctx.fillStyle = '#888';
    ctx.font = '10px monospace';
    ctx.fillText('A', x2 - 5, h - 5);
    ctx.fillText('D', x3 - 5, h - 5);
    ctx.fillText('S', (x3 + x4) / 2 - 5, h - 5);
    ctx.fillText('R', x5 - 10, h - 5);

  }, [sfx]);

  // Slider component
  const Slider: React.FC<{
    label: string;
    value: number;
    min: number;
    max: number;
    step?: number;
    unit?: string;
    onChange: (v: number) => void;
  }> = ({ label, value, min, max, step = 1, unit = '', onChange }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
      <label style={{ width: 80, fontSize: 12, color: '#aaa' }}>{label}</label>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={e => onChange(Number(e.target.value))}
        style={{ flex: 1 }}
      />
      <span style={{ width: 50, fontSize: 11, color: '#666', textAlign: 'right' }}>
        {value}{unit}
      </span>
    </div>
  );

  return (
    <div style={{ 
      width, 
      height, 
      backgroundColor: '#16213e',
      color: '#fff',
      fontFamily: 'system-ui, sans-serif',
      display: 'flex',
      flexDirection: 'column',
      overflow: 'hidden',
    }}>
      {/* Header */}
      <div style={{ 
        padding: '8px 12px',
        borderBottom: '1px solid #333',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
      }}>
        <span style={{ fontWeight: 600, fontSize: 14 }}>🔊 SFX Editor</span>
        <input
          type="text"
          value={sfx.name}
          onChange={e => updateSfx({ name: e.target.value })}
          style={{
            flex: 1,
            backgroundColor: '#1a1a2e',
            border: '1px solid #333',
            borderRadius: 4,
            color: '#fff',
            padding: '4px 8px',
            fontSize: 12,
          }}
          placeholder="Effect name"
        />
        <button
          onClick={handlePlay}
          disabled={isPlaying}
          style={{
            padding: '6px 16px',
            backgroundColor: isPlaying ? '#333' : '#2ed573',
            color: isPlaying ? '#666' : '#000',
            border: 'none',
            borderRadius: 4,
            cursor: isPlaying ? 'default' : 'pointer',
            fontWeight: 600,
          }}
        >
          {isPlaying ? '▶ Playing...' : '▶ Play'}
        </button>
      </div>

      {/* Presets */}
      <div style={{ 
        padding: '8px 12px',
        borderBottom: '1px solid #333',
        display: 'flex',
        gap: 6,
        flexWrap: 'wrap',
      }}>
        <span style={{ fontSize: 11, color: '#666', marginRight: 4 }}>Presets:</span>
        {(['laser', 'explosion', 'powerup', 'hit', 'jump', 'blip', 'coin'] as SfxCategory[]).map(preset => (
          <button
            key={preset}
            onClick={() => loadPreset(preset)}
            style={{
              padding: '3px 8px',
              backgroundColor: sfx.category === preset ? CATEGORY_COLORS[preset] : '#1a1a2e',
              color: sfx.category === preset ? '#000' : CATEGORY_COLORS[preset],
              border: `1px solid ${CATEGORY_COLORS[preset]}`,
              borderRadius: 3,
              fontSize: 11,
              cursor: 'pointer',
              textTransform: 'capitalize',
            }}
          >
            {preset}
          </button>
        ))}
      </div>

      {/* Main content */}
      <div style={{ flex: 1, display: 'flex', overflow: 'hidden' }}>
        {/* Left: Visualization */}
        <div style={{ flex: 1, padding: 12, borderRight: '1px solid #333' }}>
          <div style={{ fontSize: 11, color: '#666', marginBottom: 8 }}>Envelope Visualization</div>
          <canvas
            ref={canvasRef}
            width={260}
            height={120}
            style={{ border: '1px solid #333', borderRadius: 4 }}
          />
          
          {/* Duration */}
          <div style={{ marginTop: 16 }}>
            <Slider
              label="Duration"
              value={sfx.duration_ms}
              min={20}
              max={2000}
              step={10}
              unit="ms"
              onChange={v => updateSfx({ duration_ms: v })}
            />
          </div>

          {/* Oscillator */}
          <div style={{ fontSize: 11, color: '#666', marginTop: 12, marginBottom: 8 }}>Oscillator</div>
          <Slider
            label="Frequency"
            value={sfx.oscillator.frequency}
            min={55}
            max={1760}
            step={1}
            unit="Hz"
            onChange={v => updateOscillator({ frequency: v })}
          />
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8 }}>
            <label style={{ fontSize: 11, color: '#aaa' }}>Channel:</label>
            {[0, 1, 2].map(ch => (
              <button
                key={ch}
                onClick={() => updateOscillator({ channel: ch })}
                style={{
                  padding: '2px 8px',
                  backgroundColor: sfx.oscillator.channel === ch ? ['#ff6b6b', '#51cf66', '#339af0'][ch] : '#333',
                  color: sfx.oscillator.channel === ch ? '#000' : '#888',
                  border: 'none',
                  borderRadius: 3,
                  fontSize: 11,
                  cursor: 'pointer',
                }}
              >
                {['A', 'B', 'C'][ch]}
              </button>
            ))}
          </div>
        </div>

        {/* Right: Controls */}
        <div style={{ width: 280, padding: 12 }}>
          {/* Envelope */}
          <div style={{ fontSize: 11, color: '#666', marginBottom: 8 }}>Amplitude Envelope</div>
          <Slider label="Attack" value={sfx.envelope.attack} min={0} max={500} unit="ms" onChange={v => updateEnvelope({ attack: v })} />
          <Slider label="Decay" value={sfx.envelope.decay} min={0} max={500} unit="ms" onChange={v => updateEnvelope({ decay: v })} />
          <Slider label="Sustain" value={sfx.envelope.sustain} min={0} max={15} onChange={v => updateEnvelope({ sustain: v })} />
          <Slider label="Release" value={sfx.envelope.release} min={0} max={1000} unit="ms" onChange={v => updateEnvelope({ release: v })} />
          <Slider label="Peak Vol" value={sfx.envelope.peak} min={1} max={15} onChange={v => updateEnvelope({ peak: v })} />

          {/* Pitch */}
          <div style={{ fontSize: 11, color: '#666', marginTop: 16, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            Pitch Sweep
            <input
              type="checkbox"
              checked={sfx.pitch.enabled}
              onChange={e => updatePitch({ enabled: e.target.checked })}
            />
          </div>
          {sfx.pitch.enabled && (
            <>
              <Slider label="Start ×" value={sfx.pitch.start_mult} min={0.1} max={4} step={0.1} onChange={v => updatePitch({ start_mult: v })} />
              <Slider label="End ×" value={sfx.pitch.end_mult} min={0.1} max={4} step={0.1} onChange={v => updatePitch({ end_mult: v })} />
            </>
          )}

          {/* Noise */}
          <div style={{ fontSize: 11, color: '#666', marginTop: 16, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            Noise Mix
            <input
              type="checkbox"
              checked={sfx.noise.enabled}
              onChange={e => updateNoise({ enabled: e.target.checked })}
            />
          </div>
          {sfx.noise.enabled && (
            <>
              <Slider label="Period" value={sfx.noise.period} min={0} max={31} onChange={v => updateNoise({ period: v })} />
              <Slider label="Volume" value={sfx.noise.volume} min={0} max={15} onChange={v => updateNoise({ volume: v })} />
              <Slider label="Decay" value={sfx.noise.decay_ms} min={10} max={1000} unit="ms" onChange={v => updateNoise({ decay_ms: v })} />
            </>
          )}

          {/* Arpeggio */}
          <div style={{ fontSize: 11, color: '#666', marginTop: 16, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            Arpeggio (Chord Mode)
            <input
              type="checkbox"
              checked={sfx.modulation.arpeggio}
              onChange={e => {
                const newMod = { ...sfx.modulation, arpeggio: e.target.checked };
                if (e.target.checked && newMod.arpeggio_notes.length === 0) {
                  newMod.arpeggio_notes = [0];
                }
                updateSfx({ modulation: newMod });
              }}
            />
          </div>
          {sfx.modulation.arpeggio && (
            <>
              <div style={{ fontSize: 10, color: '#888', marginBottom: 8 }}>
                Semitone offsets (0=base, 12=octave). Preset: [0,4,7]=major chord
              </div>
              <div style={{ 
                backgroundColor: '#1a1a2e', 
                border: '1px solid #333', 
                borderRadius: 4, 
                padding: 8, 
                marginBottom: 8,
                maxHeight: 120,
                overflowY: 'auto'
              }}>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                  {sfx.modulation.arpeggio_notes.map((note, idx) => (
                    <div key={idx} style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      <input
                        type="number"
                        value={note}
                        onChange={e => {
                          const newNotes = [...sfx.modulation.arpeggio_notes];
                          newNotes[idx] = Math.max(0, Math.min(24, Number(e.target.value)));
                          updateSfx({ modulation: { ...sfx.modulation, arpeggio_notes: newNotes } });
                        }}
                        style={{
                          width: 40,
                          backgroundColor: '#0f3460',
                          border: '1px solid #444',
                          color: '#fff',
                          borderRadius: 2,
                          padding: '2px 4px',
                          fontSize: 10,
                        }}
                        min="0"
                        max="24"
                      />
                      <button
                        onClick={() => {
                          const newNotes = sfx.modulation.arpeggio_notes.filter((_, i) => i !== idx);
                          updateSfx({ modulation: { ...sfx.modulation, arpeggio_notes: newNotes || [0] } });
                        }}
                        style={{
                          padding: '1px 6px',
                          backgroundColor: '#c92a2a',
                          color: '#fff',
                          border: 'none',
                          borderRadius: 2,
                          fontSize: 10,
                          cursor: 'pointer',
                        }}
                      >
                        ×
                      </button>
                    </div>
                  ))}
                </div>
              </div>
              <button
                onClick={() => {
                  const newNotes = [...sfx.modulation.arpeggio_notes];
                  if (newNotes.length < 8) {
                    newNotes.push(newNotes[newNotes.length - 1] + 1);
                  }
                  updateSfx({ modulation: { ...sfx.modulation, arpeggio_notes: newNotes } });
                }}
                style={{
                  width: '100%',
                  padding: '4px 8px',
                  backgroundColor: '#2ed573',
                  color: '#000',
                  border: 'none',
                  borderRadius: 3,
                  fontSize: 11,
                  fontWeight: 600,
                  cursor: 'pointer',
                  marginBottom: 8,
                }}
              >
                + Add Note
              </button>
              <Slider 
                label="Arp Speed" 
                value={sfx.modulation.arpeggio_speed} 
                min={10} 
                max={200} 
                unit="ms"
                onChange={v => updateSfx({ modulation: { ...sfx.modulation, arpeggio_speed: v } })} 
              />
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default SFXEditor;
