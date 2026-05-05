// ============================================
// MIDI Service - Handles MIDI parsing and conversion
// ============================================

interface ScaledNote {
  note: number;
  start: number;
  end: number;
  duration: number;
  velocity: number;
  originalTrack: string;
}

interface MidiNote {
  note: number;
  start: number;  // in MIDI ticks
  duration: number;
  velocity: number;
  channel: number; // MIDI channel (0-15)
  track: number;   // Track number
}

export interface MidiImportData {
  tracks: MidiTrackInfo[];
  tempo: number;
  ticksPerBeat: number;
  totalTicks: number;
}

export interface MidiTrackInfo {
  key: string;           // "track-channel" identifier
  track: number;
  channel: number;
  noteCount: number;
  notes: MidiNote[];
  signature: string;     // For duplicate detection
  minNote: number;       // Lowest note (for range display)
  maxNote: number;       // Highest note
  startBeat: number;     // When first note starts (in beats)
  isDuplicate: boolean;
  programNumber?: number; // GM program change (0-127)
}

export class MidiService {
  static parseMidi(arrayBuffer: ArrayBuffer): { notes: MidiNote[]; tempo: number; ticksPerBeat: number; totalTicks: number; programNumbers: Map<string, number> } {
    const data = new Uint8Array(arrayBuffer);
    let pos = 0;

    const readUint16 = () => { const v = (data[pos] << 8) | data[pos + 1]; pos += 2; return v; };
    const readUint32 = () => { const v = (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3]; pos += 4; return v; };
    const readVarLen = () => {
      let v = 0;
      let b;
      let count = 0;
      do {
        b = data[pos++];
        v = (v << 7) | (b & 0x7f);
        count++;
        if (count > 4) break; // Safety: max 4 bytes for variable length
      } while (b & 0x80);
      return v;
    };

    // Read header
    const headerChunk = String.fromCharCode(data[0], data[1], data[2], data[3]);
    if (headerChunk !== 'MThd') throw new Error('Not a valid MIDI file');
    pos = 4;
    const headerLength = readUint32();
    const format = readUint16();
    const numTracks = readUint16();
    const ticksPerBeat = readUint16();
    pos = 8 + headerLength;

    console.log(`MIDI: Format ${format}, ${numTracks} tracks, ${ticksPerBeat} ticks/beat`);

    const allNotes: MidiNote[] = [];
    let tempo = 120;
    let maxTick = 0;
    // Map of "track-channel" -> GM program number (from 0xC0 events)
    const programNumbers = new Map<string, number>();

    // Read all tracks
    for (let t = 0; t < numTracks; t++) {
      if (pos + 8 > data.length) break;

      const trackChunk = String.fromCharCode(data[pos], data[pos + 1], data[pos + 2], data[pos + 3]);
      if (trackChunk !== 'MTrk') {
        console.warn(`Track ${t}: Invalid header, skipping`);
        pos += 8;
        continue;
      }
      pos += 4;
      const trackLength = readUint32();
      const trackEnd = pos + trackLength;

      const activeNotes: Map<string, { note: number; start: number; velocity: number; channel: number }> = new Map();
      let tick = 0;
      let runningStatus = 0;
      let trackNoteCount = 0;

      while (pos < trackEnd && pos < data.length) {
        const delta = readVarLen();
        tick += delta;
        maxTick = Math.max(maxTick, tick);

        if (pos >= data.length) break;

        let status = data[pos];
        if (status < 0x80) {
          // Running status - use previous status
          status = runningStatus;
        } else {
          pos++;
          if (status >= 0x80 && status < 0xf0) {
            runningStatus = status;
          }
        }

        const type = status & 0xf0;
        const ch = status & 0x0f;

        if (type === 0x90) { // Note on
          const note = data[pos++];
          const velocity = data[pos++];
          const key = `${t}-${ch}-${note}`;

          if (velocity > 0) {
            activeNotes.set(key, { note, start: tick, velocity, channel: ch });
          } else {
            // Velocity 0 = note off
            const active = activeNotes.get(key);
            if (active) {
              allNotes.push({
                note: active.note,
                start: active.start,
                duration: Math.max(1, tick - active.start),
                velocity: Math.round(active.velocity / 8),
                channel: active.channel,
                track: t,
              });
              activeNotes.delete(key);
              trackNoteCount++;
            }
          }
        } else if (type === 0x80) { // Note off
          const note = data[pos++];
          pos++; // velocity (ignored for note off)
          const key = `${t}-${ch}-${note}`;

          const active = activeNotes.get(key);
          if (active) {
            allNotes.push({
              note: active.note,
              start: active.start,
              duration: Math.max(1, tick - active.start),
              velocity: Math.round(active.velocity / 8),
              channel: active.channel,
              track: t,
            });
            activeNotes.delete(key);
            trackNoteCount++;
          }
        } else if (type === 0xa0) { pos += 2; } // Aftertouch
        else if (type === 0xb0) { pos += 2; } // Control change
        else if (type === 0xc0) {
          const program = data[pos]; pos += 1; // Program change
          programNumbers.set(`${t}-${ch}`, program);
        }
        else if (type === 0xd0) { pos += 1; } // Channel pressure
        else if (type === 0xe0) { pos += 2; } // Pitch bend
        else if (status === 0xff) { // Meta event
          const metaType = data[pos++];
          const metaLen = readVarLen();
          if (metaType === 0x51 && metaLen === 3) { // Tempo
            const microsPerBeat = (data[pos] << 16) | (data[pos + 1] << 8) | data[pos + 2];
            tempo = Math.round(60000000 / microsPerBeat);
            console.log(`MIDI: Tempo ${tempo} BPM`);
          }
          pos += metaLen;
        } else if (status === 0xf0 || status === 0xf7) { // SysEx
          const len = readVarLen();
          pos += len;
        }
      }

      // Close any notes still active at end of track
      for (const [key, active] of activeNotes) {
        allNotes.push({
          note: active.note,
          start: active.start,
          duration: Math.max(1, tick - active.start),
          velocity: Math.round(active.velocity / 8),
          channel: active.channel,
          track: t,
        });
        trackNoteCount++;
      }

      console.log(`Track ${t}: ${trackNoteCount} notes`);
      pos = trackEnd;
    }

    console.log(`MIDI: Total ${allNotes.length} notes, max tick ${maxTick}`);
    return { notes: allNotes, tempo, ticksPerBeat, totalTicks: maxTick, programNumbers };
  }

  static analyzeMidi(arrayBuffer: ArrayBuffer): MidiImportData {
    const midiData = this.parseMidi(arrayBuffer);

    // Group notes by track+channel
    const trackChannelNotes: Map<string, MidiNote[]> = new Map();
    for (const note of midiData.notes) {
      const key = `${note.track}-${note.channel}`;
      if (!trackChannelNotes.has(key)) trackChannelNotes.set(key, []);
      trackChannelNotes.get(key)!.push(note);
    }

    // Create signatures and detect duplicates
    const signatureToFirst: Map<string, string> = new Map();
    const tracks: MidiTrackInfo[] = [];

    for (const [key, notes] of trackChannelNotes) {
      if (notes.length === 0) continue;

      const [trackStr, channelStr] = key.split('-');
      const sig = notes.slice(0, 20).map(n => `${n.start}-${n.note}`).join(',');

      const isDuplicate = signatureToFirst.has(sig);
      if (!isDuplicate) signatureToFirst.set(sig, key);

      const noteValues = notes.map(n => n.note);
      const firstNoteStart = notes[0].start;

      tracks.push({
        key,
        track: parseInt(trackStr),
        channel: parseInt(channelStr),
        noteCount: notes.length,
        notes,
        signature: sig,
        minNote: Math.min(...noteValues),
        maxNote: Math.max(...noteValues),
        startBeat: firstNoteStart / midiData.ticksPerBeat,
        isDuplicate,
        programNumber: midiData.programNumbers.get(key),
      });
    }

    // Sort by note count (most notes first)
    tracks.sort((a, b) => b.noteCount - a.noteCount);

    return {
      tracks,
      tempo: midiData.tempo,
      ticksPerBeat: midiData.ticksPerBeat,
      totalTicks: midiData.totalTicks,
    };
  }
}