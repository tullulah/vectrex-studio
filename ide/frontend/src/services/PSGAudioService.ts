// ============================================
// PSG Audio Service - Handles AY-3-8910 audio playback
// ============================================

export interface InstrResource {
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

export class PSGAudioService {
  private ctx: AudioContext | null = null;
  private oscillators: OscillatorNode[] = [];
  private gains: GainNode[] = [];
  private masterGain: GainNode | null = null;

  // Noise generator
  private noiseBuffer: AudioBuffer | null = null;
  private noiseSource: AudioBufferSourceNode | null = null;
  private noiseGain: GainNode | null = null;
  private noiseFilter: BiquadFilterNode | null = null;

  // Per-channel instrument data
  private channelInstrs: (InstrResource | null)[] = [null, null, null];
  private arpTimers: (ReturnType<typeof setInterval> | null)[] = [null, null, null];
  private arpPositions: number[] = [0, 0, 0];
  private arpBaseNotes: number[] = [0, 0, 0];

  async init(): Promise<void> {
    if (this.ctx) return;
    this.ctx = new AudioContext();

    this.masterGain = this.ctx.createGain();
    this.masterGain.gain.value = 0.2;
    this.masterGain.connect(this.ctx.destination);

    // Tone channels (A, B, C)
    for (let i = 0; i < 3; i++) {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'square';
      osc.frequency.value = 440;
      gain.gain.value = 0;
      osc.connect(gain);
      gain.connect(this.masterGain);
      osc.start();
      this.oscillators.push(osc);
      this.gains.push(gain);
    }

    // Noise generator
    this.noiseBuffer = this.createNoiseBuffer();
    this.noiseGain = this.ctx.createGain();
    this.noiseGain.gain.value = 0;
    this.noiseFilter = this.ctx.createBiquadFilter();
    this.noiseFilter.type = 'lowpass';
    this.noiseFilter.frequency.value = 5000;
    this.noiseGain.connect(this.noiseFilter);
    this.noiseFilter.connect(this.masterGain);
    this.startNoiseGenerator();
  }

  private createNoiseBuffer(): AudioBuffer {
    const bufferSize = this.ctx!.sampleRate * 2;
    const buffer = this.ctx!.createBuffer(1, bufferSize, this.ctx!.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = Math.random() * 2 - 1;
    }
    return buffer;
  }

  private startNoiseGenerator(): void {
    if (!this.ctx || !this.noiseBuffer || !this.noiseGain) return;

    // Stop previous source if exists
    if (this.noiseSource) {
      try { this.noiseSource.stop(); } catch {}
    }

    this.noiseSource = this.ctx.createBufferSource();
    this.noiseSource.buffer = this.noiseBuffer;
    this.noiseSource.loop = true;
    this.noiseSource.connect(this.noiseGain);
    this.noiseSource.start();
  }

  noteToFrequency(note: number): number {
    return 440 * Math.pow(2, (note - 69) / 12);
  }

  setChannelInstr(channel: number, instr: InstrResource | null): void {
    if (channel >= 0 && channel < 3) {
      this.channelInstrs[channel] = instr;
    }
  }

  playNote(channel: number, note: number, velocity: number): void {
    if (!this.ctx || channel < 0 || channel > 2) return;

    const instr = this.channelInstrs[channel];
    const now = this.ctx.currentTime;

    // Cancel any existing arp timer for this channel
    if (this.arpTimers[channel]) {
      clearInterval(this.arpTimers[channel]!);
      this.arpTimers[channel] = null;
    }

    this.arpBaseNotes[channel] = note;
    this.arpPositions[channel] = 0;

    const applyNote = (n: number, t: number = this.ctx!.currentTime) => {
      const freq = this.noteToFrequency(n);
      if (!isFinite(freq) || freq <= 0 || freq > 20000) return;
      this.oscillators[channel].frequency.cancelScheduledValues(t);
      this.oscillators[channel].frequency.setValueAtTime(freq, t);
    };

    // Determine starting note (apply arpeggio position 0 if needed)
    let effectiveNote = note;
    if (instr && instr.arpeggio_count > 0) {
      effectiveNote = note + (instr.arpeggio_intervals[0] ?? 0);
    }
    applyNote(effectiveNote, now);

    // Volume: scale by instrument volume (0-15) if set, else use velocity only
    const instrVol = instr ? instr.volume / 15 : 1.0;
    const gain = (velocity / 15) * instrVol * 0.3;
    const safeGain = isFinite(gain) && gain >= 0 ? gain : 0;

    this.gains[channel].gain.cancelScheduledValues(now);
    this.gains[channel].gain.setValueAtTime(safeGain, now);

    // Volume decay envelope (duration_frames × 20ms per frame)
    if (instr && instr.duration_frames > 0) {
      const decayTime = instr.duration_frames * 0.02;
      this.gains[channel].gain.linearRampToValueAtTime(0, now + decayTime);
    }

    // Pitch sweep
    if (instr && instr.pitch_sweep_delta !== 0 && instr.pitch_sweep_duration_frames > 0) {
      const sweepTime = instr.pitch_sweep_duration_frames * 0.02;
      const targetNote = effectiveNote + instr.pitch_sweep_delta * instr.pitch_sweep_duration_frames;
      const targetFreq = this.noteToFrequency(targetNote);
      if (isFinite(targetFreq) && targetFreq > 0 && targetFreq < 20000) {
        this.oscillators[channel].frequency.linearRampToValueAtTime(targetFreq, now + sweepTime);
      }
    }

    // Start arpeggio cycling if needed
    if (instr && instr.arpeggio_count > 1) {
      const intervalMs = Math.max(10, instr.arpeggio_speed_frames * 20);
      let pos = 0;
      this.arpTimers[channel] = setInterval(() => {
        pos = (pos + 1) % instr.arpeggio_count;
        this.arpPositions[channel] = pos;
        const newNote = this.arpBaseNotes[channel] + (instr.arpeggio_intervals[pos] ?? 0);
        applyNote(newNote);
      }, intervalMs) as unknown as ReturnType<typeof setInterval>;
    }
  }

  stopChannel(channel: number): void {
    if (this.arpTimers[channel]) {
      clearInterval(this.arpTimers[channel]!);
      this.arpTimers[channel] = null;
    }
    if (channel >= 0 && channel < 3 && this.gains[channel] && this.ctx) {
      this.gains[channel].gain.cancelScheduledValues(this.ctx.currentTime);
      this.gains[channel].gain.setValueAtTime(0, this.ctx.currentTime);
    }
  }

  // Noise control methods
  playNoise(period: number, velocity: number = 15): void {
    if (!this.ctx || !this.noiseGain || !this.noiseFilter) return;

    // Period 0-31: lower period = higher/brighter noise, higher period = lower/darker noise
    // AY-3-8910 noise generator frequency = Clock / (16 * period)
    // For more dramatic effect, use exponential scaling
    // Period 0 = ~16kHz (very high/bright), Period 31 = ~200Hz (very low/rumble)
    const minFreq = 200;   // Lowest frequency (period 31)
    const maxFreq = 16000; // Highest frequency (period 0)
    const freq = minFreq + (maxFreq - minFreq) * Math.pow((31 - period) / 31, 2);

    // Validate frequency is finite and in valid range
    if (!isFinite(freq) || freq <= 0 || freq > 20000) {
      console.warn('[PSG] Invalid noise frequency:', freq, 'for period:', period);
      return;
    }

    // Validate velocity is finite and in valid range
    const gain = velocity / 15 * 0.6;
    if (!isFinite(gain) || gain < 0 || gain > 1) {
      console.warn('[PSG] Invalid noise gain:', gain, 'for velocity:', velocity);
      return;
    }

    this.noiseFilter.frequency.setValueAtTime(freq, this.ctx.currentTime);
    this.noiseGain.gain.setValueAtTime(gain, this.ctx.currentTime);
  }

  stopNoise(): void {
    if (this.noiseGain) {
      this.noiseGain.gain.value = 0;
    }
  }

  stopAll(): void {
    this.gains.forEach((_g, i) => this.stopChannel(i));
    this.stopNoise();
  }

  destroy(): void {
    // Clear all arp timers
    for (let i = 0; i < 3; i++) {
      if (this.arpTimers[i]) {
        clearInterval(this.arpTimers[i]!);
        this.arpTimers[i] = null;
      }
    }
    this.oscillators.forEach(o => { try { o.stop(); } catch {} });
    if (this.noiseSource) {
      try { this.noiseSource.stop(); } catch {}
    }
    this.ctx?.close();
  }
}
