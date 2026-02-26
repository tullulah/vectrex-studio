//! VPy Sound Effects Resource format (.vsfx)
//!
//! Sound effects stored as JSON with envelope and oscillator parameters.
//! Designed for simple arcade-style sounds (explosions, lasers, pickups).
//! Based on SFXR/BFXR parameter model, adapted for AY-3-8910 PSG.

use std::path::Path;
use serde::{Deserialize, Serialize};
use anyhow::Result;

/// Sound effects resource file extension
pub const VSFX_EXTENSION: &str = "vsfx";

/// Root structure of a .vsfx file
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SfxResource {
    /// File format version
    #[serde(default = "default_version")]
    pub version: String,
    
    /// Effect name (used for symbol generation)
    pub name: String,
    
    /// Effect category/preset type
    #[serde(default)]
    pub category: SfxCategory,
    
    /// Duration in milliseconds (50-2000ms typical)
    #[serde(default = "default_duration")]
    pub duration_ms: u16,
    
    /// Waveform/oscillator settings
    #[serde(default)]
    pub oscillator: Oscillator,
    
    /// Amplitude envelope (ADSR-like)
    #[serde(default)]
    pub envelope: Envelope,
    
    /// Pitch envelope (for sweeps)
    #[serde(default)]
    pub pitch: PitchEnvelope,
    
    /// Noise settings
    #[serde(default)]
    pub noise: NoiseSettings,
    
    /// Arpeggio/vibrato effects
    #[serde(default)]
    pub modulation: Modulation,
}

fn default_version() -> String { "1.0".to_string() }
fn default_duration() -> u16 { 200 }

/// Preset categories for quick sound generation
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum SfxCategory {
    #[default]
    Custom,
    Laser,
    Explosion,
    Powerup,
    Hit,
    Jump,
    Blip,
    Coin,
}

/// Oscillator/waveform settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Oscillator {
    /// Base frequency in Hz (110-880 typical, maps to PSG period)
    #[serde(default = "default_frequency")]
    pub frequency: u16,
    
    /// PSG channel to use (0=A, 1=B, 2=C)
    #[serde(default)]
    pub channel: u8,
    
    /// Duty cycle simulation via rapid on/off (0-100%)
    /// PSG only does square waves, but we can fake PWM
    #[serde(default = "default_duty")]
    pub duty: u8,
}

fn default_frequency() -> u16 { 440 }
fn default_duty() -> u8 { 50 }

impl Default for Oscillator {
    fn default() -> Self {
        Self {
            frequency: 440,
            channel: 0,
            duty: 50,
        }
    }
}

/// Amplitude envelope
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Envelope {
    /// Attack time in ms (0-500)
    #[serde(default)]
    pub attack: u16,
    
    /// Decay time in ms (0-500)
    #[serde(default = "default_decay")]
    pub decay: u16,
    
    /// Sustain level (0-15, PSG volume)
    #[serde(default = "default_sustain")]
    pub sustain: u8,
    
    /// Release time in ms (0-1000)
    #[serde(default = "default_release")]
    pub release: u16,
    
    /// Peak volume (0-15)
    #[serde(default = "default_peak")]
    pub peak: u8,
}

fn default_decay() -> u16 { 50 }
fn default_sustain() -> u8 { 8 }
fn default_release() -> u16 { 100 }
fn default_peak() -> u8 { 15 }

impl Default for Envelope {
    fn default() -> Self {
        Self {
            attack: 0,
            decay: 50,
            sustain: 8,
            release: 100,
            peak: 15,
        }
    }
}

/// Pitch envelope for frequency sweeps
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PitchEnvelope {
    /// Enable pitch sweep
    #[serde(default)]
    pub enabled: bool,
    
    /// Start frequency multiplier (0.5 = half, 2.0 = double)
    #[serde(default = "default_start_mult")]
    pub start_mult: f32,
    
    /// End frequency multiplier
    #[serde(default = "default_end_mult")]
    pub end_mult: f32,
    
    /// Sweep curve (0=linear, positive=exponential up, negative=exponential down)
    #[serde(default)]
    pub curve: i8,
}

fn default_start_mult() -> f32 { 1.0 }
fn default_end_mult() -> f32 { 1.0 }

impl Default for PitchEnvelope {
    fn default() -> Self {
        Self {
            enabled: false,
            start_mult: 1.0,
            end_mult: 1.0,
            curve: 0,
        }
    }
}

/// Noise generator settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoiseSettings {
    /// Enable noise mixing
    #[serde(default)]
    pub enabled: bool,
    
    /// Noise period (0-31, lower = higher pitch)
    #[serde(default = "default_noise_period")]
    pub period: u8,
    
    /// Noise volume (0-15)
    #[serde(default = "default_noise_volume")]
    pub volume: u8,
    
    /// Noise envelope (independent decay)
    #[serde(default)]
    pub decay_ms: u16,
}

fn default_noise_period() -> u8 { 15 }
fn default_noise_volume() -> u8 { 12 }

impl Default for NoiseSettings {
    fn default() -> Self {
        Self {
            enabled: false,
            period: 15,
            volume: 12,
            decay_ms: 100,
        }
    }
}

/// Modulation effects (arpeggio, vibrato)
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Modulation {
    /// Arpeggio enabled (rapid note changes)
    #[serde(default)]
    pub arpeggio: bool,
    
    /// Arpeggio semitones (e.g., [0, 4, 7] for major chord)
    #[serde(default)]
    pub arpeggio_notes: Vec<i8>,
    
    /// Arpeggio speed (ms per note)
    #[serde(default = "default_arp_speed")]
    pub arpeggio_speed: u16,
    
    /// Vibrato enabled
    #[serde(default)]
    pub vibrato: bool,
    
    /// Vibrato depth in semitones
    #[serde(default)]
    pub vibrato_depth: u8,
    
    /// Vibrato speed (Hz)
    #[serde(default = "default_vibrato_speed")]
    pub vibrato_speed: u8,
}

fn default_arp_speed() -> u16 { 50 }
fn default_vibrato_speed() -> u8 { 8 }

impl SfxResource {
    /// Load a .vsfx resource from a file
    pub fn load(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let resource: SfxResource = serde_json::from_str(&content)?;
        Ok(resource)
    }
    
    /// Save the resource to a file
    pub fn save(&self, path: &Path) -> Result<()> {
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(path, content)?;
        Ok(())
    }
    
    /// Create a new empty SFX resource
    pub fn new(name: &str) -> Self {
        Self {
            version: "1.0".to_string(),
            name: name.to_string(),
            category: SfxCategory::Custom,
            duration_ms: 200,
            oscillator: Oscillator::default(),
            envelope: Envelope::default(),
            pitch: PitchEnvelope::default(),
            noise: NoiseSettings::default(),
            modulation: Modulation::default(),
        }
    }
    
    /// Create preset: Laser shot
    pub fn preset_laser() -> Self {
        Self {
            name: "laser".to_string(),
            category: SfxCategory::Laser,
            duration_ms: 150,
            oscillator: Oscillator {
                frequency: 880,
                channel: 0,
                duty: 50,
            },
            envelope: Envelope {
                attack: 0,
                decay: 0,
                sustain: 12,
                release: 100,
                peak: 15,
            },
            pitch: PitchEnvelope {
                enabled: true,
                start_mult: 2.0,
                end_mult: 0.5,
                curve: -2,
            },
            noise: NoiseSettings::default(),
            modulation: Modulation::default(),
            ..Default::default()
        }
    }
    
    /// Create preset: Explosion
    pub fn preset_explosion() -> Self {
        Self {
            name: "explosion".to_string(),
            category: SfxCategory::Explosion,
            duration_ms: 400,
            oscillator: Oscillator {
                frequency: 110,
                channel: 0,
                duty: 50,
            },
            envelope: Envelope {
                attack: 5,
                decay: 50,
                sustain: 4,
                release: 300,
                peak: 15,
            },
            pitch: PitchEnvelope {
                enabled: true,
                start_mult: 1.5,
                end_mult: 0.3,
                curve: -3,
            },
            noise: NoiseSettings {
                enabled: true,
                period: 8,
                volume: 15,
                decay_ms: 350,
            },
            modulation: Modulation::default(),
            ..Default::default()
        }
    }
    
    /// Create preset: Powerup/Coin
    pub fn preset_powerup() -> Self {
        Self {
            name: "powerup".to_string(),
            category: SfxCategory::Powerup,
            duration_ms: 200,
            oscillator: Oscillator {
                frequency: 440,
                channel: 0,
                duty: 50,
            },
            envelope: Envelope {
                attack: 0,
                decay: 20,
                sustain: 10,
                release: 100,
                peak: 15,
            },
            pitch: PitchEnvelope {
                enabled: true,
                start_mult: 0.8,
                end_mult: 1.5,
                curve: 2,
            },
            noise: NoiseSettings::default(),
            modulation: Modulation {
                arpeggio: true,
                arpeggio_notes: vec![0, 4, 7, 12],
                arpeggio_speed: 40,
                ..Default::default()
            },
            ..Default::default()
        }
    }
    
    /// Create preset: Hit/Damage
    pub fn preset_hit() -> Self {
        Self {
            name: "hit".to_string(),
            category: SfxCategory::Hit,
            duration_ms: 100,
            oscillator: Oscillator {
                frequency: 220,
                channel: 0,
                duty: 50,
            },
            envelope: Envelope {
                attack: 0,
                decay: 10,
                sustain: 6,
                release: 50,
                peak: 15,
            },
            pitch: PitchEnvelope::default(),
            noise: NoiseSettings {
                enabled: true,
                period: 12,
                volume: 14,
                decay_ms: 80,
            },
            modulation: Modulation::default(),
            ..Default::default()
        }
    }
    
    /// Create preset: Jump
    pub fn preset_jump() -> Self {
        Self {
            name: "jump".to_string(),
            category: SfxCategory::Jump,
            duration_ms: 180,
            oscillator: Oscillator {
                frequency: 330,
                channel: 0,
                duty: 50,
            },
            envelope: Envelope {
                attack: 0,
                decay: 30,
                sustain: 8,
                release: 100,
                peak: 14,
            },
            pitch: PitchEnvelope {
                enabled: true,
                start_mult: 0.6,
                end_mult: 1.3,
                curve: 1,
            },
            noise: NoiseSettings::default(),
            modulation: Modulation::default(),
            ..Default::default()
        }
    }
    
    /// Create preset: Blip (menu selection)
    pub fn preset_blip() -> Self {
        Self {
            name: "blip".to_string(),
            category: SfxCategory::Blip,
            duration_ms: 50,
            oscillator: Oscillator {
                frequency: 660,
                channel: 0,
                duty: 50,
            },
            envelope: Envelope {
                attack: 0,
                decay: 5,
                sustain: 10,
                release: 30,
                peak: 12,
            },
            pitch: PitchEnvelope::default(),
            noise: NoiseSettings::default(),
            modulation: Modulation::default(),
            ..Default::default()
        }
    }
    
    /// Compile to ASM data for embedding in ROM (uses internal name for label)
    pub fn compile_to_asm(&self) -> String {
        self.compile_to_asm_with_name(None)
    }

    /// Compile to ASM data for embedding in ROM.
    /// If override_name is provided, use it for the label instead of self.name.
    pub fn compile_to_asm_with_name(&self, override_name: Option<&str>) -> String {
        let name = override_name.unwrap_or(&self.name);
        let label = format!("_{}_SFX", name.to_uppercase().replace(" ", "_").replace("-", "_"));

        // Calculate PSG period from frequency
        // AY-3-8910: f = clock / (16 * TP), so TP = clock / (16 * f)
        // Vectrex PSG clock = 1.5 MHz
        let base_period = if self.oscillator.frequency > 0 {
            (1_500_000u32 / (16 * self.oscillator.frequency as u32)).min(4095) as u16
        } else {
            213 // Default to A4 (440Hz) = period 213
        };

        // Duration in frames (50 FPS for Vectrex)
        let total_frames = (self.duration_ms as u32 * 50 / 1000).max(1) as usize;

        // Envelope timing (0ms = instant, no forced minimum)
        let attack_frames = if self.envelope.attack == 0 { 0 } else {
            ((self.envelope.attack as u32 * 50 / 1000).max(1) as f32).min(total_frames as f32 * 0.3) as usize
        };
        let decay_frames = if self.envelope.decay == 0 { 0 } else {
            ((self.envelope.decay as u32 * 50 / 1000).max(1) as f32).min(total_frames as f32 * 0.3) as usize
        };
        let release_frames = if self.envelope.release == 0 { 0 } else {
            ((self.envelope.release as u32 * 50 / 1000).max(1) as f32).min(total_frames as f32 * 0.3) as usize
        };
        let sustain_frames = total_frames.saturating_sub(attack_frames + decay_frames + release_frames);
        
        let mut asm = String::new();
        asm.push_str(&format!("{}:
", label));
        asm.push_str(&format!("    ; SFX: {} ({})
", self.name, 
            format!("{:?}", self.category).to_lowercase()));
        asm.push_str(&format!("    ; Duration: {}ms ({}fr), Freq: {}Hz, Channel: {}
",
            self.duration_ms, total_frames, self.oscillator.frequency, self.oscillator.channel));
        
        // Generate AYFX frame-by-frame
        let mut last_period: Option<u16> = None;
        let mut last_noise: Option<u8> = None;
        
        for frame in 0..total_frames {
            // Calculate envelope volume (ADSR)
            let volume = if frame < attack_frames {
                // Attack phase: 0 -> peak
                ((frame as f32 / attack_frames as f32) * self.envelope.peak as f32) as u8
            } else if frame < attack_frames + decay_frames {
                // Decay phase: peak -> sustain
                let decay_progress = (frame - attack_frames) as f32 / decay_frames as f32;
                let vol_diff = self.envelope.peak.saturating_sub(self.envelope.sustain) as f32;
                self.envelope.peak.saturating_sub((decay_progress * vol_diff) as u8)
            } else if frame < attack_frames + decay_frames + sustain_frames {
                // Sustain phase: constant
                self.envelope.sustain
            } else {
                // Release phase: sustain -> 0
                let release_progress = (frame - attack_frames - decay_frames - sustain_frames) as f32 / release_frames as f32;
                ((1.0 - release_progress) * self.envelope.sustain as f32) as u8
            };
            
            // Calculate pitch: arpeggio OR pitch sweep
            let mut current_period = base_period;
            
            if self.modulation.arpeggio && !self.modulation.arpeggio_notes.is_empty() {
                // ARPEGGIO: distribute notes across frame duration
                // arpeggio_speed determines ms per note
                let frame_time_ms = frame as f32 * 20.0; // 50 FPS = 20ms per frame
                let note_index = (frame_time_ms / self.modulation.arpeggio_speed as f32) as usize 
                    % self.modulation.arpeggio_notes.len();
                let note_offset = self.modulation.arpeggio_notes[note_index];
                
                // Convert frequency to base MIDI note
                // frequency = 440 * 2^((midi_note - 69) / 12)
                // Solve for midi_note: midi_note = 69 + 12 * log2(frequency / 440)
                let base_freq = self.oscillator.frequency as f32;
                let base_midi_note = 69.0 + 12.0 * (base_freq / 440.0).log2();
                // Apply note offset
                let current_midi = (base_midi_note + note_offset as f32).round() as i32;

                // Convert MIDI note to PSG period
                // freq = 440 * 2^((midi - 69) / 12)
                // TP = 1_500_000 / (16 * freq)
                let frequency = 440.0 * 2.0_f32.powf((current_midi - 69) as f32 / 12.0);
                current_period = (1_500_000.0 / (16.0 * frequency)).round() as u16;
                current_period = current_period.max(1).min(4095);
            } else if self.pitch.enabled && total_frames > 1 {
                // PITCH SWEEP: smooth frequency change
                let t = frame as f32 / (total_frames - 1) as f32;
                // Apply reverse only if start_mult > end_mult (descending sweep)
                let t_adjusted = if self.pitch.start_mult > self.pitch.end_mult {
                    1.0 - t  // Reverse for descending sweeps
                } else {
                    t  // Normal for ascending sweeps
                };
                let mult = self.pitch.start_mult + (self.pitch.end_mult - self.pitch.start_mult) * t_adjusted;

                current_period = ((base_period as f32) * mult) as u16;
                current_period = current_period.max(1).min(4095);
            }
            
            // Build flag byte
            let mut flag: u8 = volume & 0x0F; // Bits 0-3: volume
            
            // VRelease optimization: only include data when it changes
            // EXCEPTION: if arpeggio is active, ALWAYS emit tone (notes change every frame)
            // This prevents desync where player reads wrong bytes
            let include_tone = self.modulation.arpeggio || last_period != Some(current_period);
            // Include noise if: (1) period changed, OR (2) tone is being emitted now
            // This ensures noise stays active during tone+noise sections
            let include_noise = self.noise.enabled && (last_noise != Some(self.noise.period) || include_tone);
            
            if include_tone {
                flag |= 0x20; // Bit 5: tone data present
            }
            if include_noise {
                flag |= 0x40; // Bit 6: noise data present
            }
            
            // Bit 4: disable tone (never for simple SFX)
            // Bit 7: disable noise (set if noise not enabled)
            if !self.noise.enabled {
                flag |= 0x80;
            }
            
            // Emit frame data
            asm.push_str(&format!("    FCB ${:02X}         ; Frame {} - flags (vol={}, tone={}, noise={})
",
                flag, frame, volume,
                if include_tone { "Y" } else { "N" },
                if include_noise { "Y" } else { "N" }
            ));
            
            // Emit tone frequency if changed (big-endian for M6809 LDX)
            if include_tone {
                let high = (current_period >> 8) & 0xFF;
                let low = current_period & 0xFF;
                asm.push_str(&format!("    FCB ${:02X}, ${:02X}  ; Tone period = {} (big-endian)
",
                    high, low, current_period));
                last_period = Some(current_period);
            }
            
            // Emit noise period if changed
            if include_noise {
                asm.push_str(&format!("    FCB ${:02X}         ; Noise period
", self.noise.period));
                last_noise = Some(self.noise.period);
            }
        }
        
        // End marker
        asm.push_str("    FCB $D0, $20    ; End of effect marker
");
        asm.push_str("
");
        
        asm
    }
}

impl Default for SfxResource {
    fn default() -> Self {
        Self::new("untitled")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_preset_laser() {
        let sfx = SfxResource::preset_laser();
        assert_eq!(sfx.category, SfxCategory::Laser);
        assert!(sfx.pitch.enabled);
        assert!(!sfx.noise.enabled);
    }

    #[test]
    fn test_preset_explosion() {
        let sfx = SfxResource::preset_explosion();
        assert_eq!(sfx.category, SfxCategory::Explosion);
        assert!(sfx.noise.enabled);
    }

    #[test]
    fn test_compile_to_asm() {
        let sfx = SfxResource::preset_blip();
        let asm = sfx.compile_to_asm();
        assert!(asm.contains("_BLIP_SFX:"));
        assert!(asm.contains("FCB")); // Has byte data
    }

    #[test]
    fn test_json_roundtrip() {
        let original = SfxResource::preset_powerup();
        let json = serde_json::to_string(&original).unwrap();
        let parsed: SfxResource = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.name, original.name);
        assert_eq!(parsed.duration_ms, original.duration_ms);
    }
}
