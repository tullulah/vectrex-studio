// ============================================
// GM Presets - General MIDI program → .vinstr preset mapping
// ============================================

export interface InstrPreset {
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

export function gmProgramToPreset(program: number): { categoryName: string; preset: InstrPreset } {
  if (program <= 7)   return { categoryName: 'piano',    preset: { duration_frames: 10, volume: 14, arpeggio_count: 0, arpeggio_speed_frames: 2, arpeggio_intervals: [0, 0, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: -1, pitch_sweep_duration_frames: 8 } };
  if (program <= 15)  return { categoryName: 'mallet',   preset: { duration_frames: 16, volume: 13, arpeggio_count: 2, arpeggio_speed_frames: 3, arpeggio_intervals: [0, 12, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 23)  return { categoryName: 'organ',    preset: { duration_frames: 20, volume: 13, arpeggio_count: 3, arpeggio_speed_frames: 2, arpeggio_intervals: [0, 4, 7, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 31)  return { categoryName: 'guitar',   preset: { duration_frames: 12, volume: 14, arpeggio_count: 0, arpeggio_speed_frames: 2, arpeggio_intervals: [0, 0, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: -2, pitch_sweep_duration_frames: 6 } };
  if (program <= 39)  return { categoryName: 'bass',     preset: { duration_frames: 18, volume: 15, arpeggio_count: 0, arpeggio_speed_frames: 2, arpeggio_intervals: [0, 0, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 47)  return { categoryName: 'strings',  preset: { duration_frames: 22, volume: 11, arpeggio_count: 2, arpeggio_speed_frames: 4, arpeggio_intervals: [0, 1, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 55)  return { categoryName: 'ensemble', preset: { duration_frames: 24, volume: 10, arpeggio_count: 2, arpeggio_speed_frames: 3, arpeggio_intervals: [0, 7, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 63)  return { categoryName: 'brass',    preset: { duration_frames: 14, volume: 14, arpeggio_count: 2, arpeggio_speed_frames: 3, arpeggio_intervals: [0, 4, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 71)  return { categoryName: 'reed',     preset: { duration_frames: 18, volume: 12, arpeggio_count: 2, arpeggio_speed_frames: 5, arpeggio_intervals: [0, 2, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 79)  return { categoryName: 'pipe',     preset: { duration_frames: 20, volume: 11, arpeggio_count: 2, arpeggio_speed_frames: 6, arpeggio_intervals: [0, 2, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 87)  return { categoryName: 'lead',     preset: { duration_frames: 16, volume: 13, arpeggio_count: 3, arpeggio_speed_frames: 2, arpeggio_intervals: [0, 4, 7, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 95)  return { categoryName: 'pad',      preset: { duration_frames: 28, volume: 9,  arpeggio_count: 2, arpeggio_speed_frames: 4, arpeggio_intervals: [0, 7, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 103) return { categoryName: 'synth',    preset: { duration_frames: 14, volume: 12, arpeggio_count: 3, arpeggio_speed_frames: 2, arpeggio_intervals: [0, 3, 7, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: -1, pitch_sweep_duration_frames: 6 } };
  if (program <= 111) return { categoryName: 'ethnic',   preset: { duration_frames: 14, volume: 13, arpeggio_count: 2, arpeggio_speed_frames: 2, arpeggio_intervals: [0, 5, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  if (program <= 119) return { categoryName: 'perc',     preset: { duration_frames: 8,  volume: 15, arpeggio_count: 0, arpeggio_speed_frames: 2, arpeggio_intervals: [0, 0, 0, 0], noise_enabled: true,  noise_period: 10, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0 } };
  return                     { categoryName: 'sfx',      preset: { duration_frames: 12, volume: 12, arpeggio_count: 0, arpeggio_speed_frames: 2, arpeggio_intervals: [0, 0, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: -3, pitch_sweep_duration_frames: 10 } };
}

// GM category display names (per-range lookup)
export const GM_PROGRAM_NAMES: Record<number, string> = (() => {
  const m: Record<number, string> = {};
  for (let i = 0;   i <= 7;   i++) m[i] = 'Piano';
  for (let i = 8;   i <= 15;  i++) m[i] = 'Mallet';
  for (let i = 16;  i <= 23;  i++) m[i] = 'Organ';
  for (let i = 24;  i <= 31;  i++) m[i] = 'Guitar';
  for (let i = 32;  i <= 39;  i++) m[i] = 'Bass';
  for (let i = 40;  i <= 47;  i++) m[i] = 'Strings';
  for (let i = 48;  i <= 55;  i++) m[i] = 'Ensemble';
  for (let i = 56;  i <= 63;  i++) m[i] = 'Brass';
  for (let i = 64;  i <= 71;  i++) m[i] = 'Reed';
  for (let i = 72;  i <= 79;  i++) m[i] = 'Pipe';
  for (let i = 80;  i <= 87;  i++) m[i] = 'Lead';
  for (let i = 88;  i <= 95;  i++) m[i] = 'Pad';
  for (let i = 96;  i <= 127; i++) m[i] = 'Synth/FX';
  return m;
})();
