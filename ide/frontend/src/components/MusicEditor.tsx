// Helpers dummy para evitar errores de compilación
function isBlackKey(note: number): boolean {
  // C, D, E, F, G, A, B (C=0)
  return [1, 3, 6, 8, 10].includes(note % 12);
}

function noteToString(note: number): string {
  const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  const octave = Math.floor(note / 12) - 1;
  return `${names[note % 12]}${octave}`;
}

function generateId(): string {
  return Math.random().toString(36).substr(2, 9);
}
// Interface para notas escaladas usadas en mergedTracksToVmus
interface ScaledNote {
  note: number;
  start: number;
  end: number;
  duration: number;
  velocity: number;
  originalTrack: string;
}
/**
 * MusicEditor - AY-3-8910 PSG Music Editor for Vectrex
 * Piano Roll style editor with timeline view
 *
 * AY-3-8910 capabilities:
 * - 3 tone channels (A, B, C) - square waves
 * - 1 noise generator (can be mixed with any channel)
 * - 1 envelope generator (shared)
 */

import React, { useRef, useEffect, useState, useCallback, useMemo } from 'react';
import {
  MidiService,
  MusicConversionService,
  PSGAudioService,
  MusicResourceService,
  type NoteEvent,
  type MusicResource
} from '../services';

// Tipos locales para evitar errores de importación
interface MidiNote {
  note: number;
  start: number;
  duration: number;
  velocity: number;
  channel: number;
  track: number;
}

interface MidiTrackInfo {
  key: string;
  track: number;
  channel: number;
  noteCount: number;
  notes: MidiNote[];
  signature: string;
  minNote: number;
  maxNote: number;
  startBeat: number;
  isDuplicate: boolean;
}

interface MidiImportData {
  tracks: MidiTrackInfo[];
  tempo: number;
  ticksPerBeat: number;
  totalTicks: number;
}

interface MusicEditorProps {
  resource?: MusicResource;
  onChange?: (resource: MusicResource) => void;
  width?: number;
  height?: number;
}

// ============================================
// Constants
// ============================================

const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
// Full piano range: A0 (MIDI 21) to C8 (MIDI 108) = 88 keys
// AY-3-8910 supports ~22 Hz to 93 kHz, so this is well within range
const START_NOTE = 21;  // A0
const END_NOTE = 108;   // C8
const NOTES_COUNT = END_NOTE - START_NOTE + 1;  // 88 notes

const PIANO_KEY_HEIGHT = 14;
const PIANO_KEY_WIDTH = 60;
const TICK_WIDTH = 4;  // Smaller since we have more ticks now
const DEFAULT_TICKS = 384;  // 16 bars * 24 ticks/beat * 4 beats/bar / 4
const TICKS_PER_BEAT = 24;  // Higher resolution for better MIDI import (24 = common MIDI resolution)

const CHANNEL_COLORS = ['#ff6b6b', '#51cf66', '#339af0']; // A=red, B=green, C=blue

// ============================================
// MIDI Import Dialog Component
// ============================================

interface MidiImportDialogProps {
  importData: MidiImportData;
  onImport: (selectedTracks: string[], mergeMode: boolean, multiplexMode: boolean, trackModes: Map<string, 'tone' | 'noise'>) => void;
  onCancel: () => void;
}

const MidiImportDialog: React.FC<MidiImportDialogProps> = ({ importData, onImport, onCancel }) => {
  const [selectedTracks, setSelectedTracks] = useState<string[]>([]);
  const [previewTrack, setPreviewTrack] = useState<string | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [mergeMode, setMergeMode] = useState(true); // merge all tracks by default
  const [multiplexMode, setMultiplexMode] = useState(false); // Tim Follin multiplex
  const [trackModes, setTrackModes] = useState<Map<string, 'tone' | 'noise'>>(new Map()); // tone or noise per track
  const psgRef = useRef<PSGAudioService | null>(null);
  const playIntervalRef = useRef<number | null>(null);
  // Debug solo si necesario
  // console.log('🎵 MidiImportDialog rendering with:', { 
  //   hasImportData: !!importData, 
  //   tracksCount: importData?.tracks?.length,
  //   mode: multiplexMode ? 'multiplex' : mergeMode ? 'merge' : 'separate'
  // });
  
  useEffect(() => {
    const initAudio = async () => {
      const audioService = new PSGAudioService();
      await audioService.init();
      psgRef.current = audioService;
    };
    initAudio();
    
    // Auto-select top 3 non-duplicate tracks (or more in merge mode)
    const autoSelected = importData.tracks
      .filter(t => !t.isDuplicate)
      .slice(0, mergeMode ? 10 : 3) // In merge mode, allow more tracks
      .map(t => t.key);
    setSelectedTracks(autoSelected);
    
    // Auto-detect percussion tracks (channel 10 or low notes < MIDI 36)
    const modes = new Map<string, 'tone' | 'noise'>();
    importData.tracks.forEach(t => {
      const isPercussion = t.channel === 10 || (t.minNote < 36 && t.maxNote < 48);
      modes.set(t.key, isPercussion ? 'noise' : 'tone');
    });
    setTrackModes(modes);
    
    return () => {
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
      psgRef.current?.destroy();
    };
  }, [importData]);
  
  // Multiplex mode disables merge/separate selection (always merge all)
  useEffect(() => {
    if (multiplexMode) {
      const allTracks = importData.tracks.filter(t => !t.isDuplicate).map(t => t.key);
      setSelectedTracks(allTracks);
    }
  }, [multiplexMode, importData]);
  
  // Update selection when merge mode changes
  const handleMergeModeChange = (newMergeMode: boolean) => {
    setMergeMode(newMergeMode);
    if (newMergeMode) {
      // In merge mode, select all non-duplicate tracks
      const allTracks = importData.tracks.filter(t => !t.isDuplicate).map(t => t.key);
      setSelectedTracks(allTracks);
    } else {
      // In separate mode, limit to 3
      setSelectedTracks(prev => prev.slice(0, 3));
    }
  };
  
  const toggleTrack = (key: string) => {
    setSelectedTracks(prev => {
      if (prev.includes(key)) {
        // Don't allow deselection in multiplex mode
        if (multiplexMode) return prev;
        return prev.filter(k => k !== key);
      } else if (multiplexMode || mergeMode || prev.length < 3) {
        return [...prev, key];
      }
      return prev; // Max 3 in separate mode
    });
  };
  
  const previewPlay = (trackInfo: MidiTrackInfo) => {
    if (isPlaying && previewTrack === trackInfo.key) {
      // Stop
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
      psgRef.current?.stopAll();
      setIsPlaying(false);
      setPreviewTrack(null);
      return;
    }
    
    // Stop any current playback
    if (playIntervalRef.current) clearInterval(playIntervalRef.current);
    psgRef.current?.stopAll();
    
    setIsPlaying(true);
    setPreviewTrack(trackInfo.key);
    
    const tickScale = TICKS_PER_BEAT / importData.ticksPerBeat;
    const msPerTick = (60000 / importData.tempo) / TICKS_PER_BEAT;
    
    // Check if this track should be played as noise
    const isNoiseTrack = trackModes.get(trackInfo.key) === 'noise';
    
    // Start from where the notes actually begin
    const firstNoteStart = trackInfo.notes.length > 0 ? 
      Math.round(trackInfo.notes[0].start * tickScale) : 0;
    let pos = firstNoteStart;
    
    const playing = new Map<string, MidiNote>();
    const lastNoteEnd = trackInfo.notes.length > 0 ? 
      Math.round((trackInfo.notes[trackInfo.notes.length - 1].start + 
                  trackInfo.notes[trackInfo.notes.length - 1].duration) * tickScale) : 200;
    // Play for max 300 ticks from first note (about 3 seconds at 120bpm)
    const maxTicks = Math.min(firstNoteStart + 300, lastNoteEnd + 10);
    
    playIntervalRef.current = window.setInterval(() => {
      for (const note of trackInfo.notes) {
        const scaledStart = Math.round(note.start * tickScale);
        if (scaledStart === pos && !playing.has(`${note.start}-${note.note}`)) {
          if (isNoiseTrack) {
            // Play as noise
            const period = Math.max(0, Math.min(31, Math.round(31 - (note.note - 24) / 2)));
            psgRef.current?.playNoise(period, note.velocity);
          } else {
            // Play as tone
            psgRef.current?.playNote(0, note.note, note.velocity);
          }
          playing.set(`${note.start}-${note.note}`, note);
        }
      }
      for (const [id, note] of playing) {
        const scaledEnd = Math.round((note.start + note.duration) * tickScale);
        if (pos >= scaledEnd) {
          if (isNoiseTrack) {
            psgRef.current?.stopNoise();
          } else {
            psgRef.current?.stopChannel(0);
          }
          playing.delete(id);
        }
      }
      pos++;
      if (pos >= maxTicks) {
        if (playIntervalRef.current) clearInterval(playIntervalRef.current);
        psgRef.current?.stopAll();
        setIsPlaying(false);
        setPreviewTrack(null);
      }
    }, msPerTick);
  };
  
  const getAssignment = (key: string): string => {
    const idx = selectedTracks.indexOf(key);
    if (idx === -1) return '';
    return ['A', 'B', 'C'][idx];
  };
  
  const noteToName = (note: number): string => {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const octave = Math.floor(note / 12) - 1;
    return `${names[note % 12]}${octave}`;
  };
  
  const dialogStyle: React.CSSProperties = {
    position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
    background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center',
    zIndex: 9999,
  };
  
  const panelStyle: React.CSSProperties = {
    background: '#1e1e2e', borderRadius: '8px', padding: '20px', minWidth: '500px', maxWidth: '700px',
    maxHeight: '80vh', overflow: 'auto', color: '#fff', border: '1px solid #444',
  };
  
  const rowStyle = (isSelected: boolean, isDuplicate: boolean): React.CSSProperties => ({
    display: 'flex', alignItems: 'center', gap: '10px', padding: '8px 12px', margin: '4px 0',
    background: isSelected ? '#3a4a6e' : isDuplicate ? '#2a2a3e' : '#252535',
    borderRadius: '4px', cursor: 'pointer', opacity: isDuplicate ? 0.6 : 1,
    border: isSelected ? '2px solid #6a8abe' : '2px solid transparent',
  });
  
  const btnStyle: React.CSSProperties = {
    padding: '8px 16px', background: '#4a5a8e', color: '#fff', border: 'none',
    borderRadius: '4px', cursor: 'pointer', fontSize: '14px',
  };
  
  return (
    <>
      {console.log('🎵 MidiImportDialog JSX rendering')}
      <div style={dialogStyle} onClick={onCancel}>
        <div style={panelStyle} onClick={e => e.stopPropagation()}>
          <h2 style={{ margin: '0 0 16px 0', fontSize: '18px' }}>🎵 Import MIDI - Select Channels</h2>
        
        {/* Mode selector */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '16px', padding: '16px', background: '#ff6b35', borderRadius: '8px', border: '3px solid #fff' }}>
          <div style={{ fontSize: '16px', fontWeight: 'bold', color: '#000', textAlign: 'center', marginBottom: '8px' }}>
            🎵 SELECT IMPORT MODE
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', flexWrap: 'wrap' }}>
            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', background: '#fff', padding: '8px', borderRadius: '6px', flex: 1, minWidth: '200px' }}>
                <input 
                  type="radio" 
                  checked={mergeMode && !multiplexMode} 
                  onChange={() => {
                    setMergeMode(true);
                    setMultiplexMode(false);
                    handleMergeModeChange(true);
                    console.log('🔀 Mode changed to: MERGE');
                  }}
                  style={{ accentColor: '#4a4', width: '20px', height: '20px' }}
                />
                <div>
                  <div style={{ fontWeight: 'bold', color: '#000' }}>🔀 Merge Mode</div>
                  <div style={{ fontSize: '11px', color: '#666' }}>Dynamic A/B/C assignment</div>
                </div>
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', background: '#fff', padding: '8px', borderRadius: '6px', flex: 1, minWidth: '200px' }}>
                <input 
                  type="radio" 
                  checked={!mergeMode && !multiplexMode} 
                  onChange={() => {
                    setMergeMode(false);
                    setMultiplexMode(false);
                    handleMergeModeChange(false);
                    console.log('📊 Mode changed to: SEPARATE');
                  }}
                  style={{ accentColor: '#4a4', width: '20px', height: '20px' }}
                />
                <div>
                  <div style={{ fontWeight: 'bold', color: '#000' }}>📊 Separate Mode pepe</div>
                  <div style={{ fontSize: '11px', color: '#666' }}>Fixed channels (max 3)</div>
                </div>
              </label>
            </div>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', background: '#fff', padding: '8px', borderRadius: '6px', flex: 1, minWidth: '200px', marginTop: '12px' }}>
              <input 
                type="radio" 
                checked={multiplexMode} 
                onChange={() => {
                  setMultiplexMode(true);
                  setMergeMode(true); // Multiplex always uses merge internally
                  console.log('🎚 Mode changed to: MULTIPLEX');
                }}
                style={{ accentColor: '#4a4', width: '20px', height: '20px' }}
              />
              <div>
                <div style={{ fontWeight: 'bold', color: '#000' }}>🎚 Multiplex Mode</div>
                <div style={{ fontSize: '11px', color: '#666' }}>Tim Follin: 6 virtual channels</div>
              </div>
            </label>
          </div>
        </div>        <p style={{ color: '#888', fontSize: '13px', margin: '0 0 8px 0' }}>
          {multiplexMode
            ? 'Multiplex: hasta 6 canales virtuales, sin descartar notas.'
            : mergeMode 
              ? 'Select tracks to merge. Notes will be dynamically assigned to A/B/C.' 
              : 'Select up to 3 tracks. Each becomes a fixed channel.'}
        </p>
        <p style={{ color: '#6a8', fontSize: '12px', margin: '0 0 12px 0' }}>
          Tempo: {importData.tempo} BPM | Tracks: {importData.tracks.length} | 
          Selected: {selectedTracks.length}
        </p>
        
        <div style={{ maxHeight: '350px', overflow: 'auto' }}>
          {importData.tracks.map(track => {
            const assignment = mergeMode ? (selectedTracks.includes(track.key) ? '✓' : '') : getAssignment(track.key);
            const isSelected = selectedTracks.includes(track.key);
            return (
              <div key={track.key} style={rowStyle(isSelected, track.isDuplicate)} onClick={() => toggleTrack(track.key)}>
                <div style={{ 
                  width: '28px', height: '28px', borderRadius: '4px', 
                  background: mergeMode 
                    ? (isSelected ? '#4a4' : '#444')
                    : (assignment ? CHANNEL_COLORS[['A','B','C'].indexOf(assignment)] : '#444'),
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontWeight: 'bold', fontSize: '14px'
                }}>
                  {assignment || '—'}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: '500' }}>
                    Track {track.track}, Ch {track.channel}
                    {track.isDuplicate && <span style={{ color: '#a88', marginLeft: '8px', fontSize: '11px' }}>(duplicate)</span>}
                  </div>
                  <div style={{ fontSize: '11px', color: '#888' }}>
                    {track.noteCount} notes | Range: {noteToName(track.minNote)} - {noteToName(track.maxNote)}
                    {track.startBeat > 0 && <span style={{ color: '#a8a', marginLeft: '6px' }}>| Starts at beat {Math.round(track.startBeat)}</span>}
                  </div>
                </div>
                <select
                  value={trackModes.get(track.key) || 'tone'}
                  onChange={(e) => {
                    e.stopPropagation();
                    const newModes = new Map(trackModes);
                    newModes.set(track.key, e.target.value as 'tone' | 'noise');
                    setTrackModes(newModes);
                  }}
                  style={{
                    padding: '4px 8px',
                    borderRadius: '4px',
                    border: '1px solid #666',
                    background: trackModes.get(track.key) === 'noise' ? '#d84' : '#48c',
                    color: '#fff',
                    fontSize: '11px',
                    fontWeight: 'bold',
                    cursor: 'pointer',
                    marginRight: '8px'
                  }}
                >
                  <option value="tone">🎵 Tone</option>
                  <option value="noise">🥁 Noise</option>
                </select>
                <button 
                  onClick={(e) => { e.stopPropagation(); previewPlay(track); }}
                  style={{ ...btnStyle, background: previewTrack === track.key ? '#c44' : '#4a4', minWidth: '50px' }}
                >
                  {previewTrack === track.key ? '⏹' : '▶'}
                </button>
              </div>
            );
          })}
        </div>
        
        <div style={{ display: 'flex', gap: '12px', marginTop: '20px', justifyContent: 'flex-end' }}>
          <button onClick={onCancel} style={{ ...btnStyle, background: '#555' }}>Cancel</button>
          <button 
            onClick={() => onImport(selectedTracks, mergeMode, multiplexMode, trackModes)} 
            disabled={selectedTracks.length === 0}
            style={{ ...btnStyle, background: selectedTracks.length > 0 ? '#4a4' : '#333' }}
          >
            {multiplexMode
              ? `🎚 Multiplex (${selectedTracks.length} canales)`
              : mergeMode 
                ? `🔀 Merge ${selectedTracks.length} Track${selectedTracks.length !== 1 ? 's' : ''}`
                : `Import ${selectedTracks.length} Channel${selectedTracks.length !== 1 ? 's' : ''}`
            }
          </button>
        </div>
      </div>
    </div>
    </>
  );
};

// ============================================
// PSG Audio Engine
// ============================================

// ============================================
// Main Component
// ============================================

export const MusicEditor: React.FC<MusicEditorProps> = ({
  resource: initialResource,
  onChange,
  width: propWidth,
  height: propHeight,
}) => {
  const [resource, setResource] = useState<MusicResource>(() => MusicResourceService.ensureValidResource(initialResource));
  const [currentChannel, setCurrentChannel] = useState(0);
  const [viewChannel, setViewChannel] = useState<number | 'all' | 'noise'>('all'); // Filter: 'all', 0/1/2, or 'noise'
  const [isPlaying, setIsPlaying] = useState(false);
  const [playheadPosition, setPlayheadPosition] = useState(0);
  const [scrollX, setScrollX] = useState(0);
  const [scrollY, setScrollY] = useState(NOTES_COUNT * PIANO_KEY_HEIGHT / 2 - 200);
  const [tool, setTool] = useState<'draw' | 'select' | 'erase' | 'pan'>('pan');
  const [containerSize, setContainerSize] = useState({ width: propWidth || 1000, height: propHeight || 600 });

  // Sync with external resource changes (e.g., file loaded from disk)
  useEffect(() => {
    if (initialResource) {
      const validated = MusicResourceService.ensureValidResource(initialResource);
      // Only update if notes array is different (avoid loops)
      if (JSON.stringify(validated.notes) !== JSON.stringify(resource.notes) ||
          validated.tempo !== resource.tempo ||
          validated.totalTicks !== resource.totalTicks) {
        setResource(validated);
      }
    }
  }, [initialResource]);
  const [selectedNotes, setSelectedNotes] = useState<Set<string>>(new Set());
  const [dragStart, setDragStart] = useState<{ tick: number; note: number } | null>(null);
  const [zoom, setZoom] = useState(1);
  const [midiImportData, setMidiImportData] = useState<MidiImportData | null>(null);
  const [playbackSpeed, setPlaybackSpeed] = useState(100); // Percentage: 100 = normal, 50 = half speed
  const [autoScroll, setAutoScroll] = useState(true);
  
  const maxReachedBarsRef = useRef(0); // Memorizar el máximo de compases alcanzado
  
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const psgRef = useRef<PSGAudioService | null>(null);
  const playIntervalRef = useRef<number | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Calcular rango de compases VISIBLES para renderizado eficiente
  const visibleBarRange = useMemo(() => {
    const lastNoteEnd = resource.notes.length ? Math.max(...resource.notes.map((n: NoteEvent) => n.start + n.duration)) : 0;
    const tickWidth = TICK_WIDTH * zoom;
    const currentVisibleWidth = containerSize.width - PIANO_KEY_WIDTH - 20;
    const ticksPerBar = TICKS_PER_BEAT * 4;
    const barWidth = ticksPerBar * tickWidth;
    
    // Calcular qué compases están visibles en pantalla
    const firstVisibleBar = Math.floor(scrollX / barWidth);
    const visibleBarsCount = Math.ceil(currentVisibleWidth / barWidth);
    const lastVisibleBar = firstVisibleBar + visibleBarsCount;
    
    // Buffer: renderizar 20 compases antes y 100 después
    const startBar = Math.max(0, firstVisibleBar - 20);
    const contentBars = Math.ceil(lastNoteEnd / ticksPerBar);
    const farthestNeeded = Math.max(
      lastVisibleBar + 100,
      contentBars,
      Math.ceil(playheadPosition / ticksPerBar) + 100
    );
    
    return { startBar, endBar: farthestNeeded };
  }, [scrollX, zoom, containerSize.width, resource.notes, playheadPosition]);

  // Initialize audio
  useEffect(() => {
    const initAudio = async () => {
      const audioService = new PSGAudioService();
      await audioService.init();
      psgRef.current = audioService;
    };
    initAudio();
    return () => psgRef.current?.destroy();
  }, []);

  // Resize observer to fill container
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    
    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const { width, height } = entry.contentRect;
        if (width > 0 && height > 0) {
          setContainerSize({ width, height });
        }
      }
    });
    
    resizeObserver.observe(container);
    return () => resizeObserver.disconnect();
  }, []);

  // Use container size or props
  const width = containerSize.width;
  const height = containerSize.height;

  // Update parent
  const updateResource = useCallback((newResource: MusicResource) => {
    setResource(newResource);
    onChange?.(newResource);
  }, [onChange]);

  // Calculate dimensions
  const gridHeight = NOTES_COUNT * PIANO_KEY_HEIGHT;
  const visibleWidth = width - PIANO_KEY_WIDTH - 20;
  const visibleHeight = height - 160;

  // Draw the piano roll
  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    const tickW = TICK_WIDTH * zoom;

    // Draw grid background
    for (let i = 0; i < NOTES_COUNT; i++) {
      const y = i * PIANO_KEY_HEIGHT - scrollY;
      if (y < -PIANO_KEY_HEIGHT || y > visibleHeight) continue;
      
      const note = START_NOTE + (NOTES_COUNT - 1 - i);
      const isBlack = isBlackKey(note);
      
      ctx.fillStyle = isBlack ? '#1a1a2e' : '#252535';
      ctx.fillRect(0, y, visibleWidth, PIANO_KEY_HEIGHT);
      
      ctx.strokeStyle = '#333';
      ctx.lineWidth = 0.5;
      ctx.beginPath();
      ctx.moveTo(0, y + PIANO_KEY_HEIGHT);
      ctx.lineTo(visibleWidth, y + PIANO_KEY_HEIGHT);
      ctx.stroke();
    }

    // Draw beat lines
    for (let tick = 0; tick < resource.totalTicks; tick++) {
      const x = tick * tickW - scrollX;
      if (x < -tickW || x > visibleWidth) continue;
      
      ctx.strokeStyle = tick % (TICKS_PER_BEAT * 4) === 0 ? '#555' : 
                        tick % TICKS_PER_BEAT === 0 ? '#3a3a4e' : '#2a2a3e';
      ctx.lineWidth = tick % (TICKS_PER_BEAT * 4) === 0 ? 2 : 1;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, visibleHeight);
      ctx.stroke();
    }

    // Draw notes (filtered by viewChannel)
    const visibleNotes = viewChannel === 'all' 
      ? resource.notes 
      : viewChannel === 'noise'
        ? [] // Don't show tone notes when viewing noise
        : resource.notes.filter((n: NoteEvent) => n.channel === viewChannel);
    
    for (const note of visibleNotes) {
      const noteIndex = NOTES_COUNT - 1 - (note.note - START_NOTE);
      const y = noteIndex * PIANO_KEY_HEIGHT - scrollY;
      const x = note.start * tickW - scrollX;
      const w = note.duration * tickW;
      
      if (y < -PIANO_KEY_HEIGHT || y > visibleHeight) continue;
      if (x + w < 0 || x > visibleWidth) continue;
      
      const isSelected = selectedNotes.has(note.id);
      const channelIdx = typeof note.channel === 'number' ? note.channel : 0;
      const color = CHANNEL_COLORS[channelIdx] || CHANNEL_COLORS[0];
      ctx.fillStyle = isSelected ? '#fff' : color;
      ctx.strokeStyle = isSelected ? '#ff0' : '#000';
      ctx.lineWidth = isSelected ? 2 : 1;
      
      const radius = 3;
      ctx.beginPath();
      ctx.roundRect(x + 1, y + 2, Math.max(w - 2, 4), PIANO_KEY_HEIGHT - 4, radius);
      ctx.fill();
      ctx.stroke();
      
      if (w > 25) {
        ctx.fillStyle = '#000';
        ctx.font = '9px monospace';
        ctx.fillText(noteToString(note.note), x + 4, y + PIANO_KEY_HEIGHT - 4);
      }
    }

    // Draw noise events (as a separate track at the bottom) - only if viewing 'all' or 'noise'
    const shouldShowNoise = viewChannel === 'all' || viewChannel === 'noise';
    if (shouldShowNoise && resource.noise && Array.isArray(resource.noise) && resource.noise.length > 0) {
      const noiseTrackY = visibleHeight - 40;
      const noiseTrackHeight = 30;
      
      // Draw noise track background
      ctx.fillStyle = 'rgba(255, 100, 50, 0.1)';
      ctx.fillRect(0, noiseTrackY, visibleWidth, noiseTrackHeight);
      
      // Draw noise label
      ctx.fillStyle = '#d84';
      ctx.font = 'bold 11px monospace';
      ctx.fillText('🥁 NOISE', 5, noiseTrackY + 20);
      
      // Draw noise events
      for (const noise of resource.noise) {
        const x = noise.start * tickW - scrollX;
        const w = noise.duration * tickW;
        
        if (x + w < 0 || x > visibleWidth) continue;
        
        // Color based on period (lower period = brighter)
        const brightness = 255 - (noise.period / 31) * 100;
        ctx.fillStyle = `rgb(${brightness}, ${brightness * 0.5}, ${brightness * 0.3})`;
        ctx.strokeStyle = '#000';
        ctx.lineWidth = 1;
        
        ctx.beginPath();
        ctx.roundRect(x + 1, noiseTrackY + 5, Math.max(w - 2, 4), noiseTrackHeight - 10, 2);
        ctx.fill();
        ctx.stroke();
        
        // Show period value if wide enough
        if (w > 20) {
          ctx.fillStyle = '#000';
          ctx.font = '9px monospace';
          ctx.fillText(`P${noise.period}`, x + 4, noiseTrackY + 20);
        }
      }
    }
    
    // Draw playhead
    const playX = playheadPosition * tickW - scrollX;
    if (playX >= 0 && playX <= visibleWidth) {
      ctx.strokeStyle = '#f00';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(playX, 0);
      ctx.lineTo(playX, visibleHeight);
      ctx.stroke();
    }

    // Draw loop region
    const loopStartX = resource.loopStart * tickW - scrollX;
    const loopEndX = resource.loopEnd * tickW - scrollX;
    ctx.fillStyle = 'rgba(100, 200, 100, 0.15)';
    ctx.fillRect(loopStartX, 0, loopEndX - loopStartX, visibleHeight);

  }, [resource, scrollX, scrollY, visibleWidth, visibleHeight, zoom, playheadPosition, selectedNotes, viewChannel]);

  useEffect(() => {
    draw();
  }, [draw]);

  // Mouse handlers
  const handleMouseDown = (e: React.MouseEvent) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return;
    
    if (tool === 'pan') {
      setDragStart({ tick: scrollX, note: scrollY }); // Reutilizar dragStart para guardar scroll inicial
      return;
    }
    
    const x = e.clientX - rect.left + scrollX;
    const y = e.clientY - rect.top + scrollY;
    const tickW = TICK_WIDTH * zoom;
    
    const tick = Math.floor(x / tickW);
    const noteIndex = Math.floor(y / PIANO_KEY_HEIGHT);
    const note = START_NOTE + (NOTES_COUNT - 1 - noteIndex);
    
    if (note < START_NOTE || note >= START_NOTE + NOTES_COUNT) return;
    
    if (tool === 'draw') {
      setDragStart({ tick, note });
      psgRef.current?.playNote(currentChannel, note, 15);
    } else if (tool === 'erase') {
      const newNotes = resource.notes.filter((n: NoteEvent) => 
        !(n.note === note && n.start <= tick && n.start + n.duration > tick)
      );
      updateResource({ ...resource, notes: newNotes });
    } else if (tool === 'select') {
      const clickedNote = resource.notes.find((n: NoteEvent) =>
        n.note === note && n.start <= tick && n.start + n.duration > tick
      );
      if (clickedNote) {
        if (e.shiftKey) {
          const newSelected = new Set(selectedNotes);
          newSelected.has(clickedNote.id) ? newSelected.delete(clickedNote.id) : newSelected.add(clickedNote.id);
          setSelectedNotes(newSelected);
        } else {
          setSelectedNotes(new Set([clickedNote.id]));
        }
      } else {
        setSelectedNotes(new Set());
      }
    }
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (dragStart && tool === 'pan') {
      const rect = canvasRef.current?.getBoundingClientRect();
      if (rect) {
        const deltaX = e.movementX;
        const deltaY = e.movementY;
        setScrollX(Math.max(0, scrollX - deltaX));
        setScrollY(Math.max(0, scrollY - deltaY));
      }
    }
  };

  const handleMouseUp = (e: React.MouseEvent) => {
    if (dragStart && tool === 'draw') {
      const rect = canvasRef.current?.getBoundingClientRect();
      if (rect) {
        const x = e.clientX - rect.left + scrollX;
        const tickW = TICK_WIDTH * zoom;
        const endTick = Math.max(dragStart.tick + 1, Math.floor(x / tickW) + 1);
        
        const newNote: NoteEvent = {
          id: generateId(),
          note: dragStart.note,
          start: dragStart.tick,
          duration: Math.max(1, endTick - dragStart.tick),
          velocity: 15,
          channel: currentChannel,
        };
        
        updateResource({ ...resource, notes: [...resource.notes, newNote] });
      }
      psgRef.current?.stopChannel(currentChannel);
    }
    setDragStart(null);
  };

  // Playback
  const togglePlay = useCallback(() => {
    if (isPlaying) {
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
      psgRef.current?.stopAll();
      setIsPlaying(false);
    } else {
      setIsPlaying(true);
      let pos = playheadPosition;
      // Adjust speed: 100% = normal, 50% = double time (slower), 200% = half time (faster)
      const speedFactor = 100 / playbackSpeed;
      const msPerTick = ((60000 / resource.tempo) / TICKS_PER_BEAT) * speedFactor;
      
      // Filter notes based on viewChannel
      const notesToPlay = viewChannel === 'all' 
        ? resource.notes 
        : viewChannel === 'noise'
          ? [] // Don't play tone notes when viewing noise only
          : resource.notes.filter((n: NoteEvent) => n.channel === viewChannel);
      
      const shouldPlayNoise = viewChannel === 'all' || viewChannel === 'noise';
      
      const tickWidth = TICK_WIDTH * zoom;
      
      // Track active notes per channel (only one note per channel at a time)
      const activeNotePerChannel: (NoteEvent | null)[] = [null, null, null];
      let activeNoiseEvent: any = null;
      
      playIntervalRef.current = window.setInterval(() => {
        // Find notes that start at current position
        for (const note of notesToPlay) {
          if (note.start === pos) {
            // Play this note on its channel (replaces any previous note on same channel)
            psgRef.current?.playNote(note.channel, note.note, note.velocity);
            activeNotePerChannel[note.channel] = note;
          }
        }
        
        // Process noise events (only if viewing noise or all channels)
        if (shouldPlayNoise && resource.noise && Array.isArray(resource.noise)) {
          for (const noise of resource.noise) {
            if (noise.start === pos) {
              psgRef.current?.playNoise(noise.period, 15);
              activeNoiseEvent = noise;
            }
          }
          
          // Check if active noise has ended
          if (activeNoiseEvent && pos >= activeNoiseEvent.start + activeNoiseEvent.duration) {
            const newNoise = resource.noise.find((n: any) => n.start === pos);
            if (!newNoise) {
              psgRef.current?.stopNoise();
              activeNoiseEvent = null;
            }
          }
        }
        
        // Check if any active notes have ended
        for (let ch = 0; ch < 3; ch++) {
          const activeNote = activeNotePerChannel[ch];
          if (activeNote && pos >= activeNote.start + activeNote.duration) {
            // Check if there's another note starting at this exact tick
            const newNote = notesToPlay.find((n: NoteEvent) => n.channel === ch && n.start === pos);
            if (!newNote) {
              psgRef.current?.stopChannel(ch);
              activeNotePerChannel[ch] = null;
            }
          }
        }
        
        pos++;
        if (pos >= resource.loopEnd) pos = resource.loopStart;
        setPlayheadPosition(pos);
        
        // Auto-scroll to keep playhead visible
        if (autoScroll) {
          const playheadX = pos * tickWidth;
          const margin = visibleWidth * 0.3; // Keep playhead in left 30%
          if (playheadX > scrollX + visibleWidth - margin) {
            setScrollX(Math.max(0, playheadX - margin));
          } else if (playheadX < scrollX + margin) {
            setScrollX(Math.max(0, playheadX - margin));
          }
        }
      }, msPerTick);
    }
  }, [isPlaying, playheadPosition, resource, viewChannel, playbackSpeed, autoScroll, zoom, scrollX, visibleWidth]);

  useEffect(() => () => { if (playIntervalRef.current) clearInterval(playIntervalRef.current); }, []);

  const deleteSelected = useCallback(() => {
    updateResource({ ...resource, notes: resource.notes.filter((n: NoteEvent) => !selectedNotes.has(n.id)) });
    setSelectedNotes(new Set());
  }, [resource, selectedNotes, updateResource]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === ' ') { e.preventDefault(); togglePlay(); }
    else if (e.key === 'Delete' || e.key === 'Backspace') deleteSelected();
    else if (e.key === '1') setCurrentChannel(0);
    else if (e.key === '2') setCurrentChannel(1);
    else if (e.key === '3') setCurrentChannel(2);
    else if (e.key === 'p') setTool('pan');
    else if (e.key === 'd') setTool('draw');
    else if (e.key === 's') setTool('select');
    else if (e.key === 'e') setTool('erase');
  }, [togglePlay, deleteSelected]);

  const handleWheel = (e: React.WheelEvent) => {
    e.shiftKey 
      ? setScrollX(Math.max(0, scrollX + e.deltaY))
      : setScrollY(Math.max(0, Math.min(gridHeight - visibleHeight, scrollY + e.deltaY)));
  };

  // Import MIDI file
  const importMidi = useCallback(() => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.mid,.midi';
    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      try {
        const arrayBuffer = await file.arrayBuffer();
        const importData = MidiService.analyzeMidi(arrayBuffer);
        console.log('MIDI analyzed:', importData.tracks.length, 'tracks');
        setMidiImportData(importData);
      } catch (err) {
        console.error('Failed to parse MIDI:', err);
        alert('Failed to parse MIDI file. Make sure it is a valid MIDI file.');
      }
    };
    input.click();
  }, []);

  // Handle import from dialog
  const handleMidiImport = useCallback((selectedTracks: string[], mergeMode: boolean, multiplexMode: boolean, trackModes: Map<string, 'tone' | 'noise'>) => {
    if (!midiImportData) return;

    let vmusData;
    if (multiplexMode) {
      vmusData = MusicConversionService.multiplexedTracksToVmus(midiImportData, selectedTracks, trackModes);
      console.log('Imported:', vmusData.notes.length, 'notes (multiplex)');
    } else if (mergeMode) {
      vmusData = MusicConversionService.mergedTracksToVmus(midiImportData, selectedTracks, trackModes);
      console.log('Imported:', vmusData.notes.length, 'notes (merged)');
    } else {
      vmusData = MusicConversionService.selectedTracksToVmus(midiImportData, selectedTracks, trackModes);
      console.log('Imported:', vmusData.notes.length, 'notes (separate)');
    }
    // Show summary
    const chA = vmusData.notes.filter((n: NoteEvent) => n.channel === 0).length;
    const chB = vmusData.notes.filter((n: NoteEvent) => n.channel === 1).length;
    const chC = vmusData.notes.filter((n: NoteEvent) => n.channel === 2).length;
    const noiseCount = vmusData.noise.length;
    console.log(`Channels: A=${chA}, B=${chB}, C=${chC}, Noise=${noiseCount}`);
    updateResource(vmusData);
    setScrollX(0);
    setScrollY(NOTES_COUNT * PIANO_KEY_HEIGHT / 2 - 200);
    setPlayheadPosition(0);
    setMidiImportData(null);
  }, [midiImportData, updateResource]);

  // Clear all notes
  const clearAll = useCallback(() => {
    if (confirm('Clear all notes?')) {
      updateResource({ ...resource, notes: [], noise: [] });
    }
  }, [resource, updateResource]);

  // Components
  const btnStyle: React.CSSProperties = { padding: '6px 12px', background: '#3a3a5e', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' };

  return (
    <div ref={containerRef} tabIndex={0} onKeyDown={handleKeyDown}
      style={{ display: 'flex', flexDirection: 'column', width: '100%', height: '100%', background: '#1e1e2e', outline: 'none', overflow: 'hidden' }}>
      
      {/* Toolbar */}
      <div style={{ display: 'flex', gap: '8px', padding: '8px', background: '#252530', borderBottom: '1px solid #3a3a4e', alignItems: 'center', flexWrap: 'wrap', flexShrink: 0 }}>
        <button onClick={togglePlay} style={{ ...btnStyle, background: isPlaying ? '#c44' : '#4a4', fontWeight: 'bold' }}>
          {isPlaying ? '⏹ Stop' : '▶ Play'}
        </button>
        <button onClick={() => setPlayheadPosition(0)} style={btnStyle}>⏮</button>
        
        {/* Speed control */}
        <select 
          value={playbackSpeed} 
          onChange={(e) => setPlaybackSpeed(parseInt(e.target.value))}
          style={{ padding: '4px 8px', background: '#3a3a5e', color: '#fff', border: 'none', borderRadius: '4px', fontSize: '11px' }}
        >
          <option value={25}>25% (4x slower)</option>
          <option value={50}>50% (2x slower)</option>
          <option value={75}>75%</option>
          <option value={100}>100% (Normal)</option>
          <option value={150}>150%</option>
          <option value={200}>200% (2x faster)</option>
        </select>
        
        {/* Auto-scroll toggle */}
        <button 
          onClick={() => setAutoScroll(!autoScroll)} 
          style={{ ...btnStyle, background: autoScroll ? '#5a5a8e' : '#3a3a5e', fontSize: '11px', padding: '4px 8px' }}
          title="Auto-scroll during playback"
        >
          {autoScroll ? '📍 Auto' : '📍 Off'}
        </button>
        
        <div style={{ width: '1px', height: '24px', background: '#4a4a6e' }} />
        
        <button onClick={() => setTool('pan')} style={{ ...btnStyle, background: tool === 'pan' ? '#5a5a8e' : '#3a3a5e' }}>✋ Pan</button>
        <button onClick={() => setTool('draw')} style={{ ...btnStyle, background: tool === 'draw' ? '#5a5a8e' : '#3a3a5e' }}>✏️ Draw</button>
        <button onClick={() => setTool('select')} style={{ ...btnStyle, background: tool === 'select' ? '#5a5a8e' : '#3a3a5e' }}>⬚ Select</button>
        <button onClick={() => setTool('erase')} style={{ ...btnStyle, background: tool === 'erase' ? '#5a5a8e' : '#3a3a5e' }}>🗑 Erase</button>
        
        <div style={{ width: '1px', height: '24px', background: '#4a4a6e' }} />
        
        <span style={{ color: '#888', fontSize: '12px' }}>Draw:</span>
        {['A', 'B', 'C'].map((ch, i) => (
          <button key={ch} onClick={() => setCurrentChannel(i)}
            style={{ ...btnStyle, background: currentChannel === i ? CHANNEL_COLORS[i] : '#3a3a5e', fontWeight: currentChannel === i ? 'bold' : 'normal', minWidth: '28px', padding: '6px 8px' }}>
            {ch}
          </button>
        ))}
        
        <div style={{ width: '1px', height: '24px', background: '#4a4a6e' }} />
        
        <span style={{ color: '#888', fontSize: '12px' }}>View:</span>
        <button onClick={() => setViewChannel('all')}
          style={{ ...btnStyle, background: viewChannel === 'all' ? '#6a6a9e' : '#3a3a5e', fontWeight: viewChannel === 'all' ? 'bold' : 'normal', minWidth: '36px' }}>
          ALL
        </button>
        {['A', 'B', 'C'].map((ch, i) => (
          <button key={`view-${ch}`} onClick={() => setViewChannel(i)}
            style={{ ...btnStyle, background: viewChannel === i ? CHANNEL_COLORS[i] : '#3a3a5e', fontWeight: viewChannel === i ? 'bold' : 'normal', minWidth: '28px', padding: '6px 8px' }}>
            {ch}
          </button>
        ))}
        <button onClick={() => setViewChannel('noise')}
          style={{ ...btnStyle, background: viewChannel === 'noise' ? '#d84' : '#3a3a5e', fontWeight: viewChannel === 'noise' ? 'bold' : 'normal', minWidth: '52px', padding: '6px 8px' }}>
          🥁 N
        </button>
        {resource.noise.length > 0 && <>
          <span style={{ color: '#888', fontSize: '12px' }}>🥁 Vol:</span>
          <input type="range" min="0" max="15" step="1"
            value={resource.noise[0]?.velocity ?? 8}
            onChange={(e) => {
              const v = parseInt(e.target.value);
              updateResource({ ...resource, noise: resource.noise.map(n => ({ ...n, velocity: v })) });
            }}
            style={{ width: '60px' }} />
          <span style={{ color: '#aaa', fontSize: '11px', minWidth: '16px' }}>
            {resource.noise[0]?.velocity ?? 8}
          </span>
        </>}

        <div style={{ width: '1px', height: '24px', background: '#4a4a6e' }} />
        
        <span style={{ color: '#888', fontSize: '12px' }}>BPM:</span>
        <input type="number" value={resource.tempo} onChange={(e) => updateResource({ ...resource, tempo: parseInt(e.target.value) || 120 })}
          style={{ width: '50px', background: '#1a1a2e', color: '#fff', border: '1px solid #4a4a6e', borderRadius: '4px', padding: '4px' }} />
        
        <span style={{ color: '#888', fontSize: '12px' }}>Zoom:</span>
        <input type="range" min="0.5" max="3" step="0.1" value={zoom} onChange={(e) => {
          const newZoom = parseFloat(e.target.value);
          setZoom(newZoom);
          // Auto-scroll para mantener playhead visible
          setTimeout(() => {
            const tickWidth = TICK_WIDTH * newZoom;
            const playheadX = playheadPosition * tickWidth;
            const margin = (containerSize.width - PIANO_KEY_WIDTH - 20) * 0.3;
            if (playheadX > scrollX + (containerSize.width - PIANO_KEY_WIDTH - 20) - margin || playheadX < scrollX + margin) {
              setScrollX(Math.max(0, playheadX - margin));
            }
          }, 0);
        }} style={{ width: '80px' }} />
        
        <div style={{ width: '1px', height: '24px', background: '#4a4a6e' }} />
        
        <button onClick={importMidi} style={{ ...btnStyle, background: '#5a4a6e' }} title="Import MIDI file">📥 Import MIDI</button>
        <button onClick={clearAll} style={{ ...btnStyle, background: '#6a4a4e' }} title="Clear all notes">🗑️ Clear</button>
        
        <div style={{ flex: 1 }} />
        <span style={{ color: '#666', fontSize: '11px' }}>Notes: {resource.notes.length} | Tick: {playheadPosition}</span>
      </div>

      {/* Timeline header */}
      <div style={{ height: '20px', marginLeft: PIANO_KEY_WIDTH, background: '#252530', borderBottom: '1px solid #444', overflow: 'hidden', flexShrink: 0 }}>
        <div style={{ transform: `translateX(${-scrollX}px)`, display: 'flex' }}>
          {/* Spacer para compensar compases no renderizados al inicio */}
          {visibleBarRange.startBar > 0 && (
            <div style={{ width: visibleBarRange.startBar * TICKS_PER_BEAT * 4 * TICK_WIDTH * zoom, flexShrink: 0 }} />
          )}
          {Array.from({ length: visibleBarRange.endBar - visibleBarRange.startBar }, (_, idx) => {
            const i = visibleBarRange.startBar + idx;
            const tick = i * TICKS_PER_BEAT * 4;
            return (
              <div
                key={i}
                style={{
                  width: TICKS_PER_BEAT * 4 * TICK_WIDTH * zoom,
                  color: '#888', fontSize: '10px', paddingLeft: '4px', borderLeft: '1px solid #555',
                  cursor: 'pointer', userSelect: 'none',
                  background: playheadPosition >= tick && playheadPosition < tick + TICKS_PER_BEAT * 4 ? '#2a2a3e' : undefined
                }}
                onClick={() => {
                  setPlayheadPosition(tick);
                  if (isPlaying) {
                    if (playIntervalRef.current) clearInterval(playIntervalRef.current);
                    setTimeout(() => togglePlay(), 0);
                  }
                }}
                title={`Bar ${i + 1} (tick ${tick})`}
              >
                {i + 1}
              </div>
            );
          })}
        </div>
      </div>      {/* Main area */}
      <div style={{ display: 'flex', flex: 1, overflow: 'hidden', minHeight: 0 }}>
        {/* Piano keys */}
        <div style={{ width: PIANO_KEY_WIDTH, flexShrink: 0, overflow: 'hidden', background: '#1a1a2e', borderRight: '2px solid #333' }}>
          <div style={{ transform: `translateY(${-scrollY}px)` }}>
            {Array.from({ length: NOTES_COUNT }, (_, i) => {
              const note = START_NOTE + (NOTES_COUNT - 1 - i);
              const isBlack = isBlackKey(note);
              const isC = note % 12 === 0;
              return (
                <div key={i}
                  onMouseDown={() => psgRef.current?.playNote(currentChannel, note, 15)}
                  onMouseUp={() => psgRef.current?.stopChannel(currentChannel)}
                  onMouseLeave={() => psgRef.current?.stopChannel(currentChannel)}
                  style={{
                    height: PIANO_KEY_HEIGHT, background: isBlack ? '#222' : (isC ? '#ddd' : '#fff'),
                    borderBottom: '1px solid #333', display: 'flex', alignItems: 'center',
                    paddingLeft: isBlack ? '4px' : '24px', fontSize: '9px', color: isBlack ? '#888' : '#333',
                    cursor: 'pointer', fontWeight: isC ? 'bold' : 'normal',
                  }}>
                  {noteToString(note)}
                </div>
              );
            })}
          </div>
        </div>

        {/* Canvas */}
        <canvas ref={canvasRef} width={visibleWidth} height={visibleHeight}
          onMouseDown={handleMouseDown} onMouseMove={handleMouseMove} onMouseUp={handleMouseUp} onWheel={handleWheel}
          style={{ flex: 1, cursor: tool === 'draw' ? 'crosshair' : tool === 'erase' ? 'not-allowed' : 'default' }} />
      </div>

      {/* Bottom piano - full range A0 to C8 */}
      <div style={{ height: '55px', background: '#1a1a2e', borderTop: '1px solid #3a3a4e', display: 'flex', alignItems: 'flex-end', padding: '4px 8px', overflow: 'auto', flexShrink: 0 }}>
        <div style={{ position: 'relative', display: 'flex' }}>
          {Array.from({ length: NOTES_COUNT }, (_, i) => {
            const note = START_NOTE + i; // A0 (21) to C8 (108)
            if (isBlackKey(note)) return null;
            return (
              <div key={note}
                onMouseDown={() => psgRef.current?.playNote(currentChannel, note, 15)}
                onMouseUp={() => psgRef.current?.stopChannel(currentChannel)}
                onMouseLeave={() => psgRef.current?.stopChannel(currentChannel)}
                style={{ width: '20px', height: '45px', background: '#fff', border: '1px solid #333', borderRadius: '0 0 3px 3px', cursor: 'pointer',
                  display: 'flex', alignItems: 'flex-end', justifyContent: 'center', paddingBottom: '2px', fontSize: '7px', color: '#666' }}>
                {note % 12 === 0 ? `C${Math.floor(note / 12) - 1}` : (note === START_NOTE ? 'A0' : '')}
              </div>
            );
          })}
          {Array.from({ length: NOTES_COUNT }, (_, i) => {
            const note = START_NOTE + i;
            if (!isBlackKey(note)) return null;
            const whites = Array.from({ length: i }, (_, j) => !isBlackKey(START_NOTE + j)).filter(Boolean).length;
            return (
              <div key={note}
                onMouseDown={() => psgRef.current?.playNote(currentChannel, note, 15)}
                onMouseUp={() => psgRef.current?.stopChannel(currentChannel)}
                onMouseLeave={() => psgRef.current?.stopChannel(currentChannel)}
                style={{ position: 'absolute', left: whites * 20 - 7, width: '14px', height: '28px', background: '#222', border: '1px solid #111', borderRadius: '0 0 2px 2px', cursor: 'pointer', zIndex: 1 }} />
            );
          })}
        </div>
      </div>

      {/* Help */}
      <div style={{ padding: '4px 8px', background: '#1a1a2e', borderTop: '1px solid #3a3a4e', fontSize: '10px', color: '#666', display: 'flex', gap: '16px', flexWrap: 'wrap', flexShrink: 0 }}>
        <span><b>Space</b>: Play/Stop</span>
        <span><b>1/2/3</b>: Channel A/B/C</span>
        <span><b>D</b>: Draw</span>
        <span><b>S</b>: Select</span>
        <span><b>E</b>: Erase</span>
        <span><b>Del</b>: Delete</span>
        <span><b>Scroll</b>: V | <b>Shift+Scroll</b>: H</span>
      </div>
      {midiImportData && (
        <>
          {console.log('🎵 Rendering MidiImportDialog with data:', midiImportData)}
          <MidiImportDialog importData={midiImportData} onImport={handleMidiImport} onCancel={() => setMidiImportData(null)} />
        </>
      )}
    </div>
  );
};
