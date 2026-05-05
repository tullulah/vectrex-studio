// Music Services Index
export { MidiService } from './MidiService.js';
export { MusicConversionService } from './MusicConversionService.js';
export { PSGAudioService } from './PSGAudioService.js';
export { MusicResourceService } from './MusicResourceService.js';
export { gmProgramToPreset, GM_PROGRAM_NAMES } from './GmPresets.js';

// Re-export types for convenience
export type { NoteEvent, MusicResource, NoiseEvent } from './MusicResourceService.js';
export type { InstrResource } from './PSGAudioService.js';
export type { MidiTrackInfo, MidiImportData } from './MidiService.js';
export type { InstrPreset } from './GmPresets.js';