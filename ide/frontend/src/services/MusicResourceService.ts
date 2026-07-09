// ============================================
// Music Resource Service - Handles music resource management
// ============================================

export interface NoteEvent {
  id: string;
  note: number;      // MIDI note (0-127)
  start: number;     // Start time in ticks
  duration: number;  // Duration in ticks
  velocity: number;  // Volume 0-15
  channel: number;   // 0=A, 1=B, 2=C
}

export interface NoiseEvent {
  id: string;
  start: number;
  duration: number;
  period: number;    // 0-31
  channels: number;  // Bitmask: which channels use noise
  velocity?: number; // 0-15, PSG volume (optional, default 12)
}

export interface MusicResource {
  version: string;
  name: string;
  author: string;
  tempo: number;
  ticksPerBeat: number;
  totalTicks: number;
  notes: NoteEvent[];
  noise: NoiseEvent[];
  loopStart: number;
  loopEnd: number;
  loop?: boolean; // Whether the track loops (true) or plays once (false). Default true for backward compatibility.
  channel_instruments?: Record<string, string>; // e.g. { "0": "pluck", "1": "bell", "2": "bass" }
}

const TICKS_PER_BEAT = 24;
const DEFAULT_TICKS = 384;

export class MusicResourceService {
  static createDefaultResource(): MusicResource {
    return {
      version: '1.0',
      name: 'Untitled',
      author: '',
      tempo: 120,
      ticksPerBeat: TICKS_PER_BEAT,
      totalTicks: DEFAULT_TICKS,
      notes: [],
      noise: [],
      loopStart: 0,
      loopEnd: DEFAULT_TICKS,
      loop: true,
    };
  }

  static ensureValidResource(r?: Partial<MusicResource>): MusicResource {
    const defaults = this.createDefaultResource();
    if (!r) return defaults;
    const result: MusicResource = {
      version: r.version || defaults.version,
      name: r.name || defaults.name,
      author: r.author || defaults.author,
      tempo: r.tempo || defaults.tempo,
      ticksPerBeat: r.ticksPerBeat || defaults.ticksPerBeat,
      totalTicks: r.totalTicks || defaults.totalTicks,
      notes: Array.isArray(r.notes) ? r.notes : defaults.notes,
      noise: Array.isArray(r.noise) ? r.noise : defaults.noise,
      loopStart: r.loopStart ?? defaults.loopStart,
      loopEnd: r.loopEnd ?? defaults.loopEnd,
      // Default to true when undefined so old files and new blank tracks stay loopable.
      loop: r.loop ?? true,
    };
    if (r.channel_instruments) {
      result.channel_instruments = r.channel_instruments;
    }
    return result;
  }

  static generateId(): string {
    return Math.random().toString(36).substr(2, 9);
  }

  static createNote(note: number, start: number, duration: number, velocity: number, channel: number): NoteEvent {
    return {
      id: this.generateId(),
      note,
      start,
      duration: Math.max(1, duration),
      velocity: Math.min(15, Math.max(0, velocity)),
      channel,
    };
  }

  static validateResource(resource: MusicResource): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (!resource.version) errors.push('Version is required');
    if (!resource.name) errors.push('Name is required');
    if (resource.tempo <= 0) errors.push('Tempo must be positive');
    if (resource.ticksPerBeat <= 0) errors.push('Ticks per beat must be positive');
    if (resource.totalTicks <= 0) errors.push('Total ticks must be positive');
    if (resource.loopStart < 0) errors.push('Loop start must be non-negative');
    if (resource.loopEnd <= resource.loopStart) errors.push('Loop end must be greater than loop start');
    if (resource.loopEnd > resource.totalTicks) errors.push('Loop end cannot exceed total ticks');

    // Validate notes
    resource.notes.forEach((note, index) => {
      if (note.note < 0 || note.note > 127) errors.push(`Note ${index}: invalid MIDI note ${note.note}`);
      if (note.start < 0) errors.push(`Note ${index}: negative start time`);
      if (note.duration <= 0) errors.push(`Note ${index}: non-positive duration`);
      if (note.velocity < 0 || note.velocity > 15) errors.push(`Note ${index}: invalid velocity ${note.velocity}`);
      if (note.channel < 0 || note.channel > 2) errors.push(`Note ${index}: invalid channel ${note.channel}`);
    });

    return { valid: errors.length === 0, errors };
  }

  static cloneResource(resource: MusicResource): MusicResource {
    return {
      ...resource,
      notes: resource.notes.map(note => ({ ...note, id: this.generateId() })),
      noise: resource.noise.map(noise => ({ ...noise, id: this.generateId() })),
    };
  }

  static getChannelNotes(resource: MusicResource, channel: number): NoteEvent[] {
    return resource.notes.filter(note => note.channel === channel);
  }

  static getTotalDuration(resource: MusicResource): number {
    if (resource.notes.length === 0) return 0;
    return Math.max(...resource.notes.map(note => note.start + note.duration));
  }

  static trimToContent(resource: MusicResource): MusicResource {
    const totalDuration = this.getTotalDuration(resource);
    return {
      ...resource,
      totalTicks: Math.max(resource.totalTicks, totalDuration),
      loopEnd: Math.min(resource.loopEnd, Math.max(resource.totalTicks, totalDuration)),
    };
  }
}