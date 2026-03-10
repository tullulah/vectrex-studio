//! VPy Music Resource format (.vmus)
//!
//! Music resources stored as JSON that can be compiled
//! into efficient ASM/binary data for Vectrex PSG.

use std::path::Path;
use serde::{Deserialize, Serialize};
use anyhow::Result;

/// Music resource file extension
pub const VMUS_EXTENSION: &str = "vmus";

/// Root structure of a .vmus file
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MusicResource {
    /// File format version
    #[serde(default = "default_version")]
    pub version: String,
    /// Music name (used for symbol generation)
    pub name: String,
    /// Author information
    #[serde(default)]
    pub author: String,
    /// Tempo in BPM
    #[serde(default = "default_tempo")]
    pub tempo: u16,
    /// Ticks per beat (24 = quarter note, 12 = eighth note)
    #[serde(default = "default_ticks_per_beat")]
    #[serde(rename = "ticksPerBeat")]
    pub ticks_per_beat: u16,
    /// Total ticks in the track
    #[serde(default)]
    #[serde(rename = "totalTicks")]
    pub total_ticks: u32,
    /// Note events
    #[serde(default)]
    pub notes: Vec<NoteEvent>,
    /// Noise events
    #[serde(default)]
    pub noise: Vec<NoiseEvent>,
    /// Loop start tick
    #[serde(default)]
    #[serde(rename = "loopStart")]
    pub loop_start: u32,
    /// Loop end tick
    #[serde(default)]
    #[serde(rename = "loopEnd")]
    pub loop_end: u32,
}

fn default_version() -> String {
    "1.0".to_string()
}

fn default_tempo() -> u16 {
    120
}

fn default_ticks_per_beat() -> u16 {
    24
}

/// A note event (tone on PSG channels A/B/C)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoteEvent {
    /// Unique identifier
    pub id: String,
    /// MIDI note number (0-127, 60=C4)
    pub note: u8,
    /// Start tick
    pub start: u32,
    /// Duration in ticks
    pub duration: u32,
    /// Velocity/volume (0-15)
    pub velocity: u8,
    /// PSG channel (0=A, 1=B, 2=C)
    pub channel: u8,
}

/// A noise event (for percussion/effects)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoiseEvent {
    /// Unique identifier
    pub id: String,
    /// Start tick
    pub start: u32,
    /// Duration in ticks
    pub duration: u32,
    /// Noise period (0-31, lower=higher pitch)
    pub period: u8,
    /// Channel mask (bit flags: 1=A, 2=B, 4=C)
    pub channels: u8,
    /// Volume/velocity (0-15, PSG volume)
    #[serde(default = "default_noise_velocity")]
    pub velocity: u8,
}

fn default_noise_velocity() -> u8 { 12 }

impl MusicResource {
    /// Load a .vmus resource from a file
    pub fn load(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let resource: MusicResource = serde_json::from_str(&content)?;
        Ok(resource)
    }
    
    /// Save the resource to a file
    pub fn save(&self, path: &Path) -> Result<()> {
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(path, content)?;
        Ok(())
    }
    
    /// Create a new empty music resource
    pub fn new(name: &str) -> Self {
        Self {
            version: "1.0".to_string(),
            name: name.to_string(),
            author: String::new(),
            tempo: 120,
            ticks_per_beat: 24,
            total_ticks: 384, // 4 beats default
            notes: Vec::new(),
            noise: Vec::new(),
            loop_start: 0,
            loop_end: 384,
        }
    }
    
    /// MIDI note to PSG frequency (calibrated for JSVecX emulator)
    /// Formula: Period = 44100 / freq_hz
    pub fn midi_to_psg_period(midi: u8) -> u16 {
        // MIDI note to Hz: 440 * 2^((note - 69) / 12)
        let note = midi as f64;
        let freq_hz = 440.0 * 2.0_f64.powf((note - 69.0) / 12.0);

        // AY-3-8910 PSG formula: Freq_out = Clock / (16 * Period)
        // JSVecX emulator: buffer=512 samples, length<<1=1024 outer iterations, left=2 ticks each,
        //   but output written only every other iteration → 4 PSG ticks per output sample
        //   tick_rate = 4 * 44100 = 176400 Hz
        //   freq = tick_rate / (2 * period)  =>  period = 88200 / freq
        //   Virtual PSG clock = 16 * 88200 = 1411200 Hz
        let period = (1_411_200.0 / (16.0 * freq_hz)) as u16;
        period.clamp(1, 4095) // 12-bit period, min 1
    }
    
    /// Compile to direct PSG format (inspired by Christman2024/malbanGit)
    /// Frame-based: each frame lists PSG register writes
    /// Compiles to ASM using the asset name (filename without extension), NOT the JSON name
    pub fn compile_to_asm(&self, asset_name: &str) -> String {
        let mut asm = String::new();
        let symbol_name = asset_name.to_uppercase().replace("-", "_").replace(" ", "_");
        
        asm.push_str(&format!("; Generated from {}.vmus (internal name: {})\n", asset_name, self.name));
        asm.push_str(&format!("; Tempo: {} BPM, Total events: {} (PSG Direct format)\n", 
            self.tempo, self.notes.len() + self.noise.len()));
        asm.push_str("; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)\n");
        asm.push_str("\n");
        
        asm.push_str(&format!("_{}_MUSIC:\n", symbol_name));
        
        // PSG Direct format (inspired by Christman2024):
        // Each frame: FCB count (number of reg writes), then pairs of FCB reg, FCB val
        // End: FCB 0 (count=0, allows $FF values in register data)
        
        asm.push_str("    ; Frame-based PSG register writes\n");
        
        // Convert ticks to frames
        // Vectrex runs at 50Hz (PAL standard, not 60Hz NTSC)
        // ticks_per_second = tempo * ticks_per_beat / 60 (tempo is BPM)
        // frames_per_tick = frames_per_second / ticks_per_second
        let ticks_per_second = (self.tempo as f32) * (self.ticks_per_beat as f32) / 60.0;
        let frames_per_second = 50.0; // Vectrex PAL refresh rate
        let frames_per_tick = frames_per_second / ticks_per_second;
        
        let tick_to_frame = |tick: u32| -> u32 {
            (tick as f32 * frames_per_tick) as u32
        };
        
        // Group notes and noise by frame and build frame-based output
        use std::collections::BTreeMap;
        let mut notes_by_frame: BTreeMap<u32, Vec<&NoteEvent>> = BTreeMap::new();
        let mut noise_by_frame: BTreeMap<u32, Vec<&NoiseEvent>> = BTreeMap::new();
        
        for note in &self.notes {
            let start_frame = tick_to_frame(note.start);
            notes_by_frame.entry(start_frame).or_insert_with(Vec::new).push(note);
        }
        
        for noise in &self.noise {
            let start_frame = tick_to_frame(noise.start);
            noise_by_frame.entry(start_frame).or_insert_with(Vec::new).push(noise);
        }
        
        // Track active notes and noise events and their end frames
        let mut active_notes: Vec<(u32, &NoteEvent)> = Vec::new(); // (end_frame, note)
        let mut active_noise: Vec<(u32, &NoiseEvent)> = Vec::new(); // (end_frame, noise)
        let mut current_frame = 0u32;
        let max_frame = tick_to_frame(self.total_ticks) + 10; // Add some padding
        
        // Track last emitted state to detect changes
        let mut last_reg_writes: Vec<(u8, u8)> = Vec::new();
        let mut last_emitted_frame = 0u32; // Track when we last emitted data
        
        // Process frames - emit only when something changes, add delay counter for unchanged frames
        while current_frame <= max_frame {
            let mut _something_changed = false;
            
            // Remove expired notes
            let prev_count = active_notes.len();
            active_notes.retain(|(end_frame, _)| *end_frame > current_frame);
            if active_notes.len() != prev_count {
                _something_changed = true;
            }
            
            // Remove expired noise
            let prev_noise_count = active_noise.len();
            active_noise.retain(|(end_frame, _)| *end_frame > current_frame);
            if active_noise.len() != prev_noise_count {
                _something_changed = true;
            }
            
            // Add new notes starting this frame
            if let Some(new_notes) = notes_by_frame.get(&current_frame) {
                for note in new_notes {
                    let duration_frames = tick_to_frame(note.start + note.duration) - current_frame;
                    active_notes.push((current_frame + duration_frames, note));
                    _something_changed = true;
                }
            }
            
            // Add new noise starting this frame
            if let Some(new_noise) = noise_by_frame.get(&current_frame) {
                for noise in new_noise {
                    let duration_frames = tick_to_frame(noise.start + noise.duration) - current_frame;
                    active_noise.push((current_frame + duration_frames, noise));
                    _something_changed = true;
                }
            }
            
            // FIXED: Don't break if there are future events pending
            // Check if we should continue - stop only if nothing active AND no future events
            let has_future_notes = notes_by_frame.keys().any(|&k| k > current_frame);
            let has_future_noise = noise_by_frame.keys().any(|&k| k > current_frame);
            
            if active_notes.is_empty() && active_noise.is_empty() && !has_future_notes && !has_future_noise {
                break;
            }
            
            // NOTE: Do NOT skip empty frames here.
            // When noise expires with no active notes, we must still emit a silence frame
            // (mixer=0x3F, vol=0) so the PSG stops the noise immediately.
            // The state_changed check below prevents redundant emissions on subsequent frames.
            
            // Build current channel state and generate register writes
            let mut reg_writes = Vec::new();
            
            // Build current channel state
            let mut chan_data: [Option<&NoteEvent>; 3] = [None, None, None];
            for (_end, note) in &active_notes {
                let ch = note.channel.min(2) as usize;
                chan_data[ch] = Some(note);
            }
            
            // Handle noise events FIRST to know which channels have active noise
            let mut noise_period = 0u8;
            let mut noise_channels = 0u8; // Bitfield: 1=A, 2=B, 4=C
            let mut noise_volume = 0u8;
            for (_end, noise) in &active_noise {
                noise_period = noise.period.min(31);
                noise_channels = noise.channels;
                // Use noise velocity (0-15) for PSG volume
                noise_volume = noise.velocity.min(15);
            }
            
            // Generate register writes for active NOTE channels
            for (ch_idx, maybe_note) in chan_data.iter().enumerate() {
                if let Some(note) = maybe_note {
                    let period = Self::midi_to_psg_period(note.note);
                    let volume = note.velocity.min(15);
                    
                    // Frequency registers (2 per channel: low 8 bits, high 4 bits)
                    let reg_lo = (ch_idx * 2) as u8;
                    let reg_hi = (ch_idx * 2 + 1) as u8;
                    reg_writes.push((reg_lo, (period & 0xFF) as u8));
                    reg_writes.push((reg_hi, ((period >> 8) & 0x0F) as u8));
                    
                    // Volume register
                    let reg_vol = (8 + ch_idx) as u8;
                    reg_writes.push((reg_vol, volume));
                } else {
                    // Only silence this channel if it doesn't have active noise
                    let has_noise = (noise_channels & (1 << ch_idx)) != 0;
                    if !has_noise {
                        let reg_vol = (8 + ch_idx) as u8;
                        reg_writes.push((reg_vol, 0));
                    }
                }
            }
            
            // Mixer register (enable/disable channels)
            // Bits 0-2: tone enable (0=on, 1=off) for channels A,B,C
            // Bits 3-5: noise enable (0=on, 1=off) for channels A,B,C
            let mut mixer = 0x3F; // Start with all disabled (bits 0-5 only; bits 6-7=IOA/IOB MUST be 0=input)
            
            // Enable tones for active note channels
            for (ch_idx, maybe_note) in chan_data.iter().enumerate() {
                if maybe_note.is_some() {
                    mixer &= !(1 << ch_idx); // Enable tone for this channel (clear bit 0-2)
                }
            }
            
            // Enable noise for active noise channels AND set volume
            if noise_channels > 0 {
                if (noise_channels & 1) != 0 { 
                    mixer &= !0x08; // Enable noise on channel A (clear bit 3)
                    // Set volume for channel A if it doesn't have a note
                    if chan_data[0].is_none() {
                        reg_writes.push((8, noise_volume)); // Vol A
                    }
                }
                if (noise_channels & 2) != 0 { 
                    mixer &= !0x10; // Enable noise on channel B (clear bit 4)
                    // Set volume for channel B if it doesn't have a note
                    if chan_data[1].is_none() {
                        reg_writes.push((9, noise_volume)); // Vol B
                    }
                }
                if (noise_channels & 4) != 0 { 
                    mixer &= !0x20; // Enable noise on channel C (clear bit 5)
                    // Set volume for channel C if it doesn't have a note
                    if chan_data[2].is_none() {
                        reg_writes.push((10, noise_volume)); // Vol C
                    }
                }
                
                // Only write noise period register if there are active noise events
                reg_writes.push((6, noise_period)); // Reg 6: Noise period
            }
            
            // Write mixer register
            reg_writes.push((7, mixer));
            
            // Check if state changed compared to last frame
            let state_changed = reg_writes != last_reg_writes;
            
            if state_changed {
                // Calculate how many frames to wait before applying this change
                let frames_since_last = current_frame - last_emitted_frame;
                
                // ALWAYS emit delay counter first (0 for first frame, >0 for subsequent)
                // This makes format consistent: FCB delay, FCB count, pairs...
                asm.push_str(&format!("    FCB     {}              ; Delay {} frames (maintain previous state)\n",
                    frames_since_last, frames_since_last));
                
                // Emit frame data (number of register writes)
                asm.push_str(&format!("    FCB     {}              ; Frame {} - {} register writes\n", 
                    reg_writes.len(), current_frame, reg_writes.len()));
                for (reg, val) in &reg_writes {
                    // CRITICAL FIX: Generate TWO separate FCB statements per register write
                    // Old format "FCB 0,$59" generates [00, 59] but UPDATE_MUSIC_PSG reads pairs
                    // New format generates separate bytes for register number and value
                    asm.push_str(&format!("    FCB     {}               ; Reg {} number\n", reg, reg));
                    asm.push_str(&format!("    FCB     ${:02X}             ; Reg {} value\n", val, reg));
                }
                
                // Update last state
                last_reg_writes = reg_writes;
                last_emitted_frame = current_frame;
            }
            
            // Check if we should continue BEFORE incrementing frame
            // Stop when no more events will be active in the NEXT frame
            let will_have_active_notes_next = !active_notes.is_empty() || notes_by_frame.keys().any(|&k| k > current_frame);
            let will_have_active_noise_next = !active_noise.is_empty() || noise_by_frame.keys().any(|&k| k > current_frame);
            
            current_frame += 1;
            
            if !will_have_active_notes_next && !will_have_active_noise_next {
                break;
            }
        }
        
        // Loop or end marker
        let loop_start_frame = tick_to_frame(self.loop_start);
        let loop_end_frame = tick_to_frame(self.loop_end);
        
        if loop_start_frame < loop_end_frame && loop_end_frame > 0 {
            // Calculate delay until loop point (how many frames to wait after last change)
            let frames_until_loop = loop_end_frame.saturating_sub(last_emitted_frame);
            
            if frames_until_loop > 0 {
                // Emit delay before loop marker to maintain last note duration
                asm.push_str(&format!("    FCB     {}              ; Delay {} frames before loop\n",
                    frames_until_loop, frames_until_loop));
            }
            
            // Loop marker: FCB $FF (special value that can't be a frame count), FDB address
            // Using absolute address instead of relying on PSG_MUSIC_START memory variable
            asm.push_str(&format!("    FCB     $FF             ; Loop command ($FF never valid as count)\n"));
            asm.push_str(&format!("    FDB     _{}_MUSIC       ; Jump to start (absolute address)\n\n", symbol_name));
        } else {
            // End marker (count=0, no more frames)
            asm.push_str("    FCB     0               ; End of music (no loop)\n\n");
        }
        
        asm
    }
    
    /// Convert MIDI note (0-127) to BIOS 6-bit frequency (0-63)
    /// BIOS frequency is an index into a note table, not actual PSG period
    #[allow(dead_code)]
    fn midi_to_bios_freq(midi_note: u8) -> u8 {
        // Map MIDI notes to BIOS 0-63 range
        // MIDI 24 (C1) = 0, MIDI 87 (D#6) = 63
        // This gives us ~5 octaves
        let clamped = midi_note.clamp(24, 87);
        ((clamped - 24) as f32 * 63.0 / 63.0).min(63.0) as u8
    }
    
    /// Compile to binary music format
    pub fn compile_to_binary(&self) -> Vec<u8> {
        let mut data = Vec::new();
        
        // Header
        data.extend_from_slice(&self.tempo.to_be_bytes());
        data.extend_from_slice(&self.ticks_per_beat.to_be_bytes());
        data.extend_from_slice(&self.total_ticks.to_be_bytes());
        
        let num_events = (self.notes.len() + self.noise.len()) as u16;
        data.extend_from_slice(&num_events.to_be_bytes());
        
        // Combine and sort events
        let mut events: Vec<(u32, EventType)> = Vec::new();
        
        for note in &self.notes {
            events.push((note.start, EventType::Note(note.clone())));
        }
        
        for noise in &self.noise {
            events.push((noise.start, EventType::Noise(noise.clone())));
        }
        
        events.sort_by_key(|(start, _)| *start);
        
        // Emit events
        for (_, event) in events {
            match event {
                EventType::Note(note) => {
                    data.push(0x01); // NOTE type
                    data.extend_from_slice(&note.start.to_be_bytes());
                    data.extend_from_slice(&note.duration.to_be_bytes());
                    data.push(note.channel);
                    
                    let period = Self::midi_to_psg_period(note.note);
                    data.extend_from_slice(&period.to_be_bytes());
                    data.push(note.velocity);
                },
                EventType::Noise(noise) => {
                    data.push(0x02); // NOISE type
                    data.extend_from_slice(&noise.start.to_be_bytes());
                    data.extend_from_slice(&noise.duration.to_be_bytes());
                    data.push(noise.period);
                    data.push(noise.channels);
                }
            }
        }
        
        // Loop points
        data.extend_from_slice(&self.loop_start.to_be_bytes());
        data.extend_from_slice(&self.loop_end.to_be_bytes());
        
        data
    }
}

#[derive(Debug, Clone)]
enum EventType {
    Note(NoteEvent),
    Noise(NoiseEvent),
}

/// Compile a .vmus file to ASM
pub fn compile_vmus_to_asm(input: &Path, output: &Path) -> Result<()> {
    let resource = MusicResource::load(input)?;
    // Use filename stem as asset name
    let asset_name = input.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("unnamed");
    let asm = resource.compile_to_asm(asset_name);
    std::fs::write(output, asm)?;
    Ok(())
}

/// Compile a .vmus file to binary
pub fn compile_vmus_to_binary(input: &Path, output: &Path) -> Result<()> {
    let resource = MusicResource::load(input)?;
    let binary = resource.compile_to_binary();
    std::fs::write(output, binary)?;
    Ok(())
}

// Tests moved to core/tests/musres_tests.rs to keep production code clean
