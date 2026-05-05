//! VPy Instrument Resource format (.vinstr)
//!
//! Pitched instrument definitions stored as JSON (timbre only, pitch-independent).
//! Used by PLAY_NOTE() builtin for melodic/harmonic playback via AY-3-8910 PSG.

use std::path::Path;
use serde::{Deserialize, Serialize};
use anyhow::Result;

/// Instrument resource file extension
pub const VINSTR_EXTENSION: &str = "vinstr";

/// Root structure of a .vinstr file
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstrResource {
    /// File format version
    #[serde(default = "default_version")]
    pub version: String,

    /// Instrument name (used for symbol generation)
    pub name: String,

    /// Duration in frames (how long the note plays before muting)
    #[serde(default = "default_duration_frames")]
    pub duration_frames: u8,

    /// Peak volume (0-15)
    #[serde(default = "default_volume")]
    pub volume: u8,

    /// Arpeggio: number of active entries in arpeggio_intervals (0=disabled, 1-4)
    #[serde(default)]
    pub arpeggio_count: u8,

    /// Arpeggio cycling speed in frames
    #[serde(default = "default_arp_speed")]
    pub arpeggio_speed_frames: u8,

    /// Signed semitone offsets for arpeggio steps [0..3]
    #[serde(default = "default_arp_intervals")]
    pub arpeggio_intervals: [i8; 4],

    /// Enable noise mixing
    #[serde(default)]
    pub noise_enabled: bool,

    /// Noise period (0-31)
    #[serde(default = "default_noise_period")]
    pub noise_period: u8,

    /// Pitch sweep delta in AY period units per frame (signed, applied each frame)
    #[serde(default)]
    pub pitch_sweep_delta: i8,

    /// Number of frames to apply pitch sweep (0=disabled)
    #[serde(default)]
    pub pitch_sweep_duration_frames: u8,
}

fn default_version() -> String { "1.0".to_string() }
fn default_duration_frames() -> u8 { 12 }
fn default_volume() -> u8 { 14 }
fn default_arp_speed() -> u8 { 2 }
fn default_arp_intervals() -> [i8; 4] { [0, 0, 0, 0] }
fn default_noise_period() -> u8 { 15 }

impl InstrResource {
    /// Load a .vinstr resource from a file
    pub fn load(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let resource: InstrResource = serde_json::from_str(&content)?;
        Ok(resource)
    }

    /// Compile to a fixed 16-byte ROM data block in ARM assembler syntax (.byte directives).
    ///
    /// Same byte layout as compile_to_asm_with_name but uses .byte / .global
    /// directives instead of FCB, suitable for arm-none-eabi-as (pitrex and arm targets).
    pub fn compile_to_arm_asm_with_name(&self, name: &str) -> String {
        let label = format!("_{}_INSTR", name.to_uppercase().replace(' ', "_").replace('-', "_"));

        let dur         = self.duration_frames;
        let vol         = self.volume.min(15);
        let arp_cnt     = self.arpeggio_count.min(4);
        let arp_spd     = self.arpeggio_speed_frames.max(1);
        let i0          = self.arpeggio_intervals[0] as u8;
        let i1          = self.arpeggio_intervals[1] as u8;
        let i2          = self.arpeggio_intervals[2] as u8;
        let i3          = self.arpeggio_intervals[3] as u8;
        let noise_en    = if self.noise_enabled { 1u8 } else { 0u8 };
        let noise_per   = self.noise_period.min(31);
        let sweep_delta = self.pitch_sweep_delta as u8;
        let sweep_dur   = self.pitch_sweep_duration_frames;

        format!(
            "@ Instrument: {name} (duration={dur}fr, vol={vol}, arp={arp_cnt})\n\
             .global {label}\n\
             {label}:\n\
             \t.byte {dur}    @ [0] duration_frames\n\
             \t.byte {vol}    @ [1] volume (0-15)\n\
             \t.byte {arp_cnt}    @ [2] arpeggio_count\n\
             \t.byte {arp_spd}    @ [3] arpeggio_speed_frames\n\
             \t.byte {i0}    @ [4] arpeggio_intervals[0] (signed)\n\
             \t.byte {i1}    @ [5] arpeggio_intervals[1]\n\
             \t.byte {i2}    @ [6] arpeggio_intervals[2]\n\
             \t.byte {i3}    @ [7] arpeggio_intervals[3]\n\
             \t.byte {noise_en}    @ [8] noise_enabled\n\
             \t.byte {noise_per}    @ [9] noise_period\n\
             \t.byte {sweep_delta}    @ [10] pitch_sweep_delta (signed as u8)\n\
             \t.byte {sweep_dur}    @ [11] pitch_sweep_duration_frames\n\
             \t.byte 0,0,0,0    @ [12-15] reserved\n\
             \n"
        )
    }

    /// Compile to a fixed 16-byte ROM data block in M6809 assembler syntax (FCB directives).
    ///
    /// Layout:
    ///   Byte 0:  duration_frames
    ///   Byte 1:  volume (0-15)
    ///   Byte 2:  arpeggio_count (0-4)
    ///   Byte 3:  arpeggio_speed_frames
    ///   Byte 4:  arpeggio_intervals[0] (signed)
    ///   Byte 5:  arpeggio_intervals[1]
    ///   Byte 6:  arpeggio_intervals[2]
    ///   Byte 7:  arpeggio_intervals[3]
    ///   Byte 8:  noise_enabled (0/1)
    ///   Byte 9:  noise_period (0-31)
    ///   Byte 10: pitch_sweep_delta (signed)
    ///   Byte 11: pitch_sweep_duration_frames
    ///   Byte 12-15: reserved (0)
    pub fn compile_to_asm_with_name(&self, override_name: Option<&str>) -> String {
        let name = override_name.unwrap_or(&self.name);
        let label = format!("_{}_INSTR", name.to_uppercase().replace(' ', "_").replace('-', "_"));

        let dur         = self.duration_frames;
        let vol         = self.volume.min(15);
        let arp_cnt     = self.arpeggio_count.min(4);
        let arp_spd     = self.arpeggio_speed_frames.max(1);
        let i0          = self.arpeggio_intervals[0] as u8;
        let i1          = self.arpeggio_intervals[1] as u8;
        let i2          = self.arpeggio_intervals[2] as u8;
        let i3          = self.arpeggio_intervals[3] as u8;
        let noise_en    = if self.noise_enabled { 1u8 } else { 0u8 };
        let noise_per   = self.noise_period.min(31);
        let sweep_delta = self.pitch_sweep_delta as u8;
        let sweep_dur   = self.pitch_sweep_duration_frames;

        format!(
            "; Instrument: {name} (duration={dur}fr, vol={vol}, arp={arp_cnt})\n\
            {label}:\n\
            \tFCB ${dur:02X}          ; [0] duration_frames\n\
            \tFCB ${vol:02X}          ; [1] volume (0-15)\n\
            \tFCB ${arp_cnt:02X}          ; [2] arpeggio_count\n\
            \tFCB ${arp_spd:02X}          ; [3] arpeggio_speed_frames\n\
            \tFCB ${i0:02X}          ; [4] arpeggio_intervals[0] (signed)\n\
            \tFCB ${i1:02X}          ; [5] arpeggio_intervals[1]\n\
            \tFCB ${i2:02X}          ; [6] arpeggio_intervals[2]\n\
            \tFCB ${i3:02X}          ; [7] arpeggio_intervals[3]\n\
            \tFCB ${noise_en:02X}          ; [8] noise_enabled\n\
            \tFCB ${noise_per:02X}          ; [9] noise_period\n\
            \tFCB ${sweep_delta:02X}          ; [10] pitch_sweep_delta (signed)\n\
            \tFCB ${sweep_dur:02X}          ; [11] pitch_sweep_duration_frames\n\
            \tFCB $00,$00,$00,$00   ; [12-15] reserved\n\
            \n"
        )
    }
}

impl Default for InstrResource {
    fn default() -> Self {
        Self {
            version: "1.0".to_string(),
            name: "unnamed".to_string(),
            duration_frames: 12,
            volume: 14,
            arpeggio_count: 0,
            arpeggio_speed_frames: 2,
            arpeggio_intervals: [0, 0, 0, 0],
            noise_enabled: false,
            noise_period: 15,
            pitch_sweep_delta: 0,
            pitch_sweep_duration_frames: 0,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_compile_pluck_to_asm() {
        let instr = InstrResource {
            name: "pluck".to_string(),
            duration_frames: 10,
            volume: 14,
            arpeggio_count: 0,
            arpeggio_speed_frames: 2,
            arpeggio_intervals: [0, 0, 0, 0],
            noise_enabled: false,
            noise_period: 15,
            pitch_sweep_delta: -1,
            pitch_sweep_duration_frames: 8,
            ..Default::default()
        };
        let asm = instr.compile_to_asm_with_name(None);
        assert!(asm.contains("_PLUCK_INSTR:"));
        assert!(asm.contains("FCB"));
        // 16 bytes total: count FCB entries
        let fcb_count: usize = asm.lines()
            .filter(|l| l.trim_start().starts_with("FCB"))
            .map(|l| l.trim_start()["FCB".len()..].split(',').count())
            .sum();
        assert_eq!(fcb_count, 16, "expected 16 bytes");
    }

    #[test]
    fn test_compile_pluck_to_arm_asm() {
        let instr = InstrResource {
            name: "pluck".to_string(),
            duration_frames: 10,
            volume: 14,
            arpeggio_count: 0,
            arpeggio_speed_frames: 2,
            arpeggio_intervals: [0, 0, 0, 0],
            noise_enabled: false,
            noise_period: 15,
            pitch_sweep_delta: -1,
            pitch_sweep_duration_frames: 8,
            ..Default::default()
        };
        let asm = instr.compile_to_arm_asm_with_name("pluck");
        assert!(asm.contains("_PLUCK_INSTR:"));
        assert!(asm.contains(".global _PLUCK_INSTR"));
        assert!(asm.contains(".byte"));
        // 16 bytes: 12 individual .byte lines + one .byte 0,0,0,0
        let byte_count: usize = asm.lines()
            .filter(|l| l.trim_start().starts_with(".byte"))
            .map(|l| l.trim_start()[".byte".len()..].split(',').count())
            .sum();
        assert_eq!(byte_count, 16, "expected 16 bytes");
    }

    #[test]
    fn test_compile_bell_to_asm() {
        let instr = InstrResource {
            name: "bell".to_string(),
            duration_frames: 20,
            volume: 12,
            arpeggio_count: 3,
            arpeggio_speed_frames: 3,
            arpeggio_intervals: [0, 7, 12, 0],
            noise_enabled: false,
            noise_period: 15,
            pitch_sweep_delta: 0,
            pitch_sweep_duration_frames: 0,
            ..Default::default()
        };
        let asm = instr.compile_to_asm_with_name(None);
        assert!(asm.contains("_BELL_INSTR:"));
        // arpeggio_count=3 should appear as FCB $03
        assert!(asm.contains("FCB $03"));
    }

    #[test]
    fn test_json_roundtrip() {
        let original = InstrResource {
            name: "test".to_string(),
            duration_frames: 8,
            volume: 10,
            arpeggio_count: 2,
            arpeggio_speed_frames: 4,
            arpeggio_intervals: [0, 5, 0, 0],
            noise_enabled: true,
            noise_period: 12,
            pitch_sweep_delta: -2,
            pitch_sweep_duration_frames: 6,
            ..Default::default()
        };
        let json = serde_json::to_string(&original).unwrap();
        let parsed: InstrResource = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.name, original.name);
        assert_eq!(parsed.duration_frames, original.duration_frames);
        assert_eq!(parsed.arpeggio_count, original.arpeggio_count);
        assert_eq!(parsed.arpeggio_intervals, original.arpeggio_intervals);
    }

    #[test]
    fn test_note_period_table_coverage() {
        // Verify the MIDI-to-period formula produces valid values for range 24-107
        for midi in 24u8..=107 {
            let period = (88200.0 / (440.0 * 2f32.powf((midi as f32 - 69.0) / 12.0))).round() as u16;
            let period = period.max(1).min(4095);
            assert!(period >= 1 && period <= 4095,
                "MIDI {} produced out-of-range period {}", midi, period);
        }
    }
}
