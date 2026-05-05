// ============================================
// Music Conversion Service - Handles MIDI to VMUS conversion
// ============================================

import { MidiService } from './MidiService.js';
import type { MidiImportData } from './MidiService.js';

interface NoteEvent {
  id: string;
  note: number;      // MIDI note (0-127)
  start: number;     // Start time in ticks
  duration: number;  // Duration in ticks
  velocity: number;  // Volume 0-15
  channel: number;   // 0=A, 1=B, 2=C
}

interface MusicResource {
  version: string;
  name: string;
  author: string;
  tempo: number;
  ticksPerBeat: number;
  totalTicks: number;
  notes: NoteEvent[];
  noise: any[]; // We'll keep this simple for now
  loopStart: number;
  loopEnd: number;
}

const TICKS_PER_BEAT = 24;  // Higher resolution for better MIDI import
const DEFAULT_TICKS = 384;  // 16 bars * 24 ticks/beat * 4 beats/bar / 4

function generateId(): string {
  return Math.random().toString(36).substr(2, 9);
}

function shiftNotesToZero<T extends { start: number; end?: number }>(notes: T[]): number {
  if (!notes.length) return 0;
  const minStart = Math.min(...notes.map(n => n.start));
  if (minStart > 0) {
    for (const n of notes) {
      n.start -= minStart;
      if (typeof n.end === 'number') n.end -= minStart;
    }
  }
  return minStart;
}

export class MusicConversionService {
  // Convert selected tracks to vmus format (separate channels)
  static selectedTracksToVmus(
    importData: MidiImportData,
    selectedTracks: string[],
    trackModes?: Map<string, string>
  ): MusicResource {
    const vmusNotes: NoteEvent[] = [];
    const vmusNoise: any[] = [];
    const tickScale = TICKS_PER_BEAT / importData.ticksPerBeat;
    
    selectedTracks.slice(0, 3).forEach((trackKey, psgChannel) => {
      const trackInfo = importData.tracks.find((t: any) => t.key === trackKey);
      if (!trackInfo) return;
      const isNoise = trackModes?.get(trackKey) === 'noise';
      
      for (const note of trackInfo.notes) {
        const start = Math.round(note.start * tickScale);
        const duration = Math.max(1, Math.round(note.duration * tickScale));
        
        if (isNoise) {
          const period = Math.max(0, Math.min(31, Math.round(31 - (note.note - 24) / 2)));
          vmusNoise.push({
            id: generateId(),
            start,
            duration,
            period,
            channels: 0x07,
          });
        } else {
          vmusNotes.push({
            id: generateId(),
            note: note.note,
            start,
            duration,
            velocity: Math.min(15, Math.max(1, note.velocity)),
            channel: psgChannel,
          });
        }
      }
    });
    
    // Eliminar espacio en blanco inicial
    shiftNotesToZero(vmusNotes);
    shiftNotesToZero(vmusNoise);
    
    // El totalTicks debe ser el máximo entre el final de la última nota y el totalTicks original
    const lastNoteEnd = vmusNotes.length ? Math.max(...vmusNotes.map(n => n.start + n.duration)) : 0;
    const lastNoiseEnd = vmusNoise.length ? Math.max(...vmusNoise.map((n: any) => n.start + n.duration)) : 0;
    const totalTicks = Math.max(DEFAULT_TICKS, Math.round(importData.totalTicks * tickScale) + 16, lastNoteEnd + 8, lastNoiseEnd + 8);
    
    return {
      version: '1.0',
      name: 'Imported MIDI',
      author: '',
      tempo: importData.tempo,
      ticksPerBeat: TICKS_PER_BEAT,
      totalTicks,
      notes: vmusNotes,
      noise: vmusNoise,
      loopStart: 0,
      loopEnd: totalTicks,
    };
  }

  // Merge all MIDI tracks into PSG channels based on polyphony
  static mergedTracksToVmus(importData: MidiImportData, selectedTracks: string[], trackModes?: Map<string, string>): MusicResource {
    const tickScale = TICKS_PER_BEAT / importData.ticksPerBeat;
    const allNotes: any[] = [];
    const noiseNotes: any[] = [];
    
    for (const trackKey of selectedTracks) {
      const trackInfo = importData.tracks.find((t: any) => t.key === trackKey);
      if (!trackInfo) continue;
      const isNoise = trackModes?.get(trackKey) === 'noise';
      
      for (const note of trackInfo.notes) {
        const start = Math.round(note.start * tickScale);
        const duration = Math.max(1, Math.round(note.duration * tickScale));
        const noteData = {
          note: note.note,
          start,
          end: start + duration,
          duration,
          velocity: Math.min(15, Math.max(1, note.velocity)),
          originalTrack: trackKey,
        };
        
        if (isNoise) {
          noiseNotes.push(noteData);
        } else {
          allNotes.push(noteData);
        }
      }
    }
    // Eliminar espacio en blanco inicial
    shiftNotesToZero(allNotes);
    // Sort by start time, then by pitch (higher notes have priority for melody)
    allNotes.sort((a: any, b: any) => a.start - b.start || b.note - a.note);
    // Assign notes to PSG channels dinámicamente
    const channelEndTime: number[] = [0, 0, 0];
    const vmusNotes: NoteEvent[] = [];
    let discardedNotes = 0;
    for (const note of allNotes) {
      let assignedChannel = -1;
      for (let ch = 0; ch < 3; ch++) {
        if (channelEndTime[ch] <= note.start) {
          assignedChannel = ch;
          break;
        }
      }
      if (assignedChannel === -1) {
        discardedNotes++;
        continue;
      }
      channelEndTime[assignedChannel] = note.end;
      vmusNotes.push({
        id: generateId(),
        note: note.note,
        start: note.start,
        duration: note.duration,
        velocity: note.velocity,
        channel: assignedChannel,
      });
    }
    if (discardedNotes > 0) {
      console.log(`Merged import: ${discardedNotes} notes discarded (>3 simultaneous)`);
    }
    
    // Generate noise events from noiseNotes
    const vmusNoise: any[] = [];
    for (const note of noiseNotes) {
      // Convert MIDI note to noise period (0-31, lower = higher pitch)
      // MIDI note 36 (C2) -> period ~16, scale accordingly
      const period = Math.max(0, Math.min(31, Math.round(31 - (note.note - 24) / 2)));
      vmusNoise.push({
        id: generateId(),
        start: note.start,
        duration: note.duration,
        period,
        channels: 0x07, // All channels (bitmask: A=1, B=2, C=4, all=7)
      });
    }
    
    // El totalTicks debe ser el máximo entre el final de la última nota y el totalTicks original
    const lastNoteEnd = vmusNotes.length ? Math.max(...vmusNotes.map(n => n.start + n.duration)) : 0;
    const lastNoiseEnd = vmusNoise.length ? Math.max(...vmusNoise.map((n: any) => n.start + n.duration)) : 0;
    const totalTicks = Math.max(DEFAULT_TICKS, Math.round(importData.totalTicks * tickScale) + 16, lastNoteEnd + 8, lastNoiseEnd + 8);
    
    if (vmusNoise.length > 0) {
      console.log(`Generated ${vmusNoise.length} noise events`);
    }
    
    return {
      version: '1.0',
      name: 'Imported MIDI',
      author: '',
      tempo: importData.tempo,
      ticksPerBeat: TICKS_PER_BEAT,
      totalTicks,
      notes: vmusNotes,
      noise: vmusNoise,
      loopStart: 0,
      loopEnd: totalTicks,
    };
  }

  // Tim Follin multiplex: hasta 6 canales virtuales intercalados en 3 físicos
  static multiplexedTracksToVmus(importData: MidiImportData, selectedTracks: string[], trackModes?: Map<string, string>): MusicResource {
    // Agrupa todas las notas de los tracks seleccionados
    const tickScale = TICKS_PER_BEAT / importData.ticksPerBeat;
    const allNotes: any[] = [];
    const noiseNotes: any[] = [];
    
    for (const trackKey of selectedTracks.slice(0, 6)) {
      const trackInfo = importData.tracks.find((t: any) => t.key === trackKey);
      if (!trackInfo) continue;
      const isNoise = trackModes?.get(trackKey) === 'noise';
      
      for (const note of trackInfo.notes) {
        const start = Math.round(note.start * tickScale);
        const duration = Math.max(1, Math.round(note.duration * tickScale));
        const noteData = {
          note: note.note,
          start,
          end: start + duration,
          duration,
          velocity: Math.min(15, Math.max(1, note.velocity)),
          originalTrack: trackKey,
        };
        
        if (isNoise) {
          noiseNotes.push(noteData);
        } else {
          allNotes.push(noteData);
        }
      }
    }
    shiftNotesToZero(allNotes);
    shiftNotesToZero(noiseNotes);
    // Ordena por inicio y por pitch
    allNotes.sort((a: any, b: any) => a.start - b.start || b.note - a.note);
    
    // Multiplexado inteligente: detecta regiones con >3 notas y solo multiplexa ahí
    const vmusNotes: NoteEvent[] = [];
    const totalTicks = Math.max(DEFAULT_TICKS, Math.round(importData.totalTicks * tickScale) + 16);
    
    // Mapa de notas ya emitidas (para evitar duplicar en modo normal)
    const emittedNotes = new Map<any, number>(); // nota -> tick de inicio emitido
    
    for (let tick = 0; tick < totalTicks; tick++) {
      // Encuentra todas las notas activas en este tick
      const active = allNotes.filter((n: any) => n.start <= tick && n.end > tick);
      
      // Decide si necesitamos multiplex en este tick
      const needsMultiplex = active.length > 3;
      
      if (needsMultiplex) {
        // MODO MULTIPLEX: más de 3 notas activas, alternamos grupos
        const multiplex = active.slice(0, 6);
        const useGroupB = tick % 2 === 1;
        
        for (let ch = 0; ch < 3; ch++) {
          const virtualIdx = useGroupB ? (ch + 3) : ch;
          const vnote = multiplex[virtualIdx];
          
          if (vnote) {
            vmusNotes.push({
              id: generateId(),
              note: vnote.note,
              start: tick,
              duration: 1, // 1 tick en multiplex
              velocity: vnote.velocity,
              channel: ch,
            });
          }
        }
      } else {
        // MODO NORMAL: 3 o menos notas, emitir con duración completa (solo una vez por nota)
        const toEmit = active.slice(0, 3);
        for (let i = 0; i < toEmit.length; i++) {
          const note = toEmit[i];
          // Solo emitir si no la hemos emitido antes
          if (!emittedNotes.has(note)) {
            vmusNotes.push({
              id: generateId(),
              note: note.note,
              start: note.start,
              duration: note.duration, // duración completa
              velocity: note.velocity,
              channel: i,
            });
            emittedNotes.set(note, note.start);
          }
        }
      }
    }
    
    // Generate noise events from noiseNotes
    const vmusNoise: any[] = [];
    for (const note of noiseNotes) {
      const period = Math.max(0, Math.min(31, Math.round(31 - (note.note - 24) / 2)));
      vmusNoise.push({
        id: generateId(),
        start: note.start,
        duration: note.duration,
        period,
        channels: 0x07,
      });
    }
    
    const lastNoiseEnd = vmusNoise.length ? Math.max(...vmusNoise.map((n: any) => n.start + n.duration)) : 0;
    const finalTotalTicks = Math.max(totalTicks, lastNoiseEnd + 8);
    
    return {
      version: '1.0',
      name: 'Imported MIDI (Multiplex)',
      author: '',
      tempo: importData.tempo,
      ticksPerBeat: TICKS_PER_BEAT,
      totalTicks: finalTotalTicks,
      notes: vmusNotes,
      noise: vmusNoise,
      loopStart: 0,
      loopEnd: finalTotalTicks,
    };
  }

  static midiToVmus(midiData: any): MusicResource {
    // Group notes by track+channel combination
    const trackChannelNotes: Map<string, any[]> = new Map();

    for (const note of midiData.notes) {
      const key = `${note.track}-${note.channel}`;
      if (!trackChannelNotes.has(key)) trackChannelNotes.set(key, []);
      trackChannelNotes.get(key)!.push(note);
    }

    // Create signature for each track (first 20 notes) to detect duplicates
    const trackSignatures: Map<string, string> = new Map();
    const signatureToTracks: Map<string, string[]> = new Map();

    for (const [key, notes] of trackChannelNotes) {
      // Create signature from first 20 notes (start time + note number)
      const sig = notes.slice(0, 20).map((n: any) => `${n.start}-${n.note}`).join(',');
      trackSignatures.set(key, sig);

      if (!signatureToTracks.has(sig)) signatureToTracks.set(sig, []);
      signatureToTracks.get(sig)!.push(key);
    }

    // Filter out duplicate tracks (keep only one per unique signature)
    const uniqueTracks: Array<[string, any[]]> = [];
    const usedSignatures = new Set<string>();

    // Sort by note count first, so we keep the "best" version of each pattern
    const sortedTracks = Array.from(trackChannelNotes.entries())
      .sort((a, b) => b[1].length - a[1].length);

    for (const [key, notes] of sortedTracks) {
      const sig = trackSignatures.get(key)!;
      if (!usedSignatures.has(sig)) {
        usedSignatures.add(sig);
        uniqueTracks.push([key, notes]);
      } else {
        console.log(`MIDI: Skipping duplicate track ${key} (same pattern as another)`);
      }
    }

    // Take top 3 unique tracks
    const selectedChannels = uniqueTracks.slice(0, 3);

    console.log('Selected unique channels:', selectedChannels.map(([k, n]) => `${k}: ${n.length} notes`));

    // Create mapping from track-channel to PSG channel (0, 1, 2)
    const channelMap = new Map<string, number>();
    selectedChannels.forEach(([key], index) => channelMap.set(key, index));

    const vmusNotes: NoteEvent[] = [];

    // Scale ticks to our resolution (TICKS_PER_BEAT = 4)
    const tickScale = TICKS_PER_BEAT / midiData.ticksPerBeat;

    // Only include notes from the top 3 channels
    for (const note of midiData.notes) {
      const key = `${note.track}-${note.channel}`;
      const psgChannel = channelMap.get(key);
      if (psgChannel === undefined) continue; // Skip notes from other channels

      vmusNotes.push({
        id: generateId(),
        note: note.note,
        start: Math.round(note.start * tickScale),
        duration: Math.max(1, Math.round(note.duration * tickScale)),
        velocity: Math.min(15, Math.max(1, note.velocity)),
        channel: psgChannel,
      });
    }

    const totalTicks = Math.max(DEFAULT_TICKS, Math.round(midiData.totalTicks * tickScale) + 16);

    return {
      version: '1.0',
      name: 'Imported MIDI',
      author: '',
      tempo: midiData.tempo,
      ticksPerBeat: TICKS_PER_BEAT,
      totalTicks,
      notes: vmusNotes,
      noise: [],
      loopStart: 0,
      loopEnd: totalTicks,
    };
  }
}