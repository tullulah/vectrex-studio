//! ARM asset data emission.
//!
//! Reads .vec / .vmus / .vsfx files and emits their data as ARM assembly.

use crate::{AssetInfo, AssetType};
use crate::vecres::VecResource;
use crate::animres::VanimResource;
use crate::instrres::InstrResource;
use crate::venemy::EnemyResource;
use crate::vecres::VecMeshSegment;
use std::collections::BTreeMap;
use std::collections::HashMap;
use std::fs;
use serde::Deserialize;

// ============================================================
// .vmus music format
// ============================================================

#[derive(Deserialize)]
struct VmusResource {
    tempo: f64,
    #[serde(rename = "ticksPerBeat")]
    ticks_per_beat: f64,
    #[serde(rename = "totalTicks")]
    total_ticks: f64,
    notes: Vec<VmusNote>,
    #[serde(default)]
    noise: Vec<VmusNoise>,
    #[serde(rename = "loopStart", default)]
    loop_start: f64,
    #[serde(rename = "loopEnd")]
    loop_end: Option<f64>,
}

#[derive(Deserialize)]
struct VmusNote {
    note: u8,
    start: f64,
    duration: f64,
    velocity: u8,
    channel: u8,
}

fn default_max_velocity() -> u8 { 127 }

#[derive(Deserialize)]
struct VmusNoise {
    start: f64,
    duration: f64,
    period: u8,
    channels: u8,
    #[serde(default = "default_max_velocity")]
    velocity: u8,
}

// ============================================================
// .vsfx sound-effect format
// ============================================================

#[derive(Deserialize, Default)]
struct VsfxResource {
    #[serde(default)]
    duration_ms: f64,
    #[serde(default)]
    oscillator: VsfxOscillator,
    #[serde(default)]
    envelope: VsfxEnvelope,
    #[serde(default)]
    pitch: VsfxPitch,
    #[serde(default)]
    noise: VsfxNoise,
    #[serde(default)]
    modulation: VsfxModulation,
}

#[derive(Deserialize, Default)]
struct VsfxModulation {
    #[serde(default)]
    arpeggio: bool,
    #[serde(default)]
    arpeggio_notes: Vec<i8>,
    #[serde(default = "default_arp_speed")]
    arpeggio_speed: u16,
}

fn default_arp_speed() -> u16 { 40 }

#[derive(Deserialize, Default)]
struct VsfxOscillator {
    #[serde(default)]
    frequency: f64,
    #[serde(default)]
    channel: u8,
}

#[derive(Deserialize, Default)]
struct VsfxEnvelope {
    #[serde(default)]
    attack: f64,   // ms
    #[serde(default)]
    decay: f64,    // ms
    #[serde(default)]
    sustain: u8,   // 0-15
    #[serde(default)]
    release: f64,  // ms
    #[serde(default)]
    peak: u8,      // 0-15
}

#[derive(Deserialize, Default)]
struct VsfxPitch {
    #[serde(default)]
    enabled: bool,
    #[serde(default)]
    start_mult: f64,
    #[serde(default)]
    end_mult: f64,
    #[serde(default)]
    #[allow(dead_code)]
    curve: i8,
}

#[derive(Deserialize, Default)]
struct VsfxNoise {
    #[serde(default)]
    enabled: bool,
    #[serde(default)]
    period: u8,
    #[serde(default)]
    volume: u8,
    #[serde(default)]
    decay_ms: f64,
}

// ============================================================
// Public entry point
// ============================================================

/// Emit all vector assets as ARM assembly data in the current section.
pub fn emit_arm_assets(assets: &[AssetInfo]) -> String {
    let mut s = String::new();

    if assets.is_empty() {
        return s;
    }

    s.push_str("@ ============================================================\n");
    s.push_str("@ Asset data\n");
    s.push_str("@ ============================================================\n\n");

    // Build dims map: lowercase vector name → (natural_half_w, natural_half_h)
    // Also build vec_min_y: lowercase vector name → min_y (lowest Y coord in the sprite).
    let mut dims_map: HashMap<String, (i32, i32)> = HashMap::new();
    let mut vec_min_y: HashMap<String, i16> = HashMap::new();
    for asset in assets {
        if !matches!(asset.asset_type, AssetType::Vector) { continue; }
        if let Ok(text) = fs::read_to_string(&asset.path) {
            if let Ok(res) = serde_json::from_str::<VecResource>(&text) {
                let (min_x, max_x) = res.calculate_x_bounds();
                let (min_y, max_y) = res.calculate_y_bounds();
                let hw = ((max_x - min_x) as i32) / 2;
                let hh = (max_y as i32).max(1);
                dims_map.insert(asset.name.to_lowercase(), (hw, hh));
                vec_min_y.insert(asset.name.to_lowercase(), min_y);
            }
        }
}

    // Build vec_walk_areas: lowercase vector name → walkable_areas from .vec file.
    let mut vec_walk_areas: HashMap<String, Vec<crate::vecres::VecWalkableArea>> = HashMap::new();
    // Build vec_meshes: lowercase vector name → collision segments from .vec file.
    let mut vec_meshes: HashMap<String, Vec<VecMeshSegment>> = HashMap::new();
    for asset in assets {
        if !matches!(asset.asset_type, AssetType::Vector) { continue; }
        if let Ok(text) = fs::read_to_string(&asset.path) {
            if let Ok(res) = serde_json::from_str::<VecResource>(&text) {
                if !res.walkable_areas.is_empty() {
                    vec_walk_areas.insert(asset.name.to_lowercase(), res.walkable_areas.clone());
                }
                if let Some(mesh) = &res.collision_mesh {
                    if !mesh.segments.is_empty() {
                        vec_meshes.insert(asset.name.to_lowercase(), mesh.segments.clone());
                    }
                }
            }
        }
    }

    for asset in assets {
        let sym = asset.name.to_uppercase().replace('-', "_").replace(' ', "_");
        match asset.asset_type {
            AssetType::Vector => {
                let text = match fs::read_to_string(&asset.path) {
                    Ok(t) => t,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not read {}: {}\n", asset.path, e));
                        continue;
                    }
                };
                let resource: VecResource = match serde_json::from_str(&text) {
                    Ok(r) => r,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not parse {}: {}\n", asset.path, e));
                        continue;
                    }
                };
                s.push_str(&emit_vec_resource(&resource, &asset.name));
                s.push_str(&emit_3d_resource(&resource, &asset.name));
            }
            AssetType::Music => {
                let text = match fs::read_to_string(&asset.path) {
                    Ok(t) => t,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not read {}: {}\n", asset.path, e));
                        continue;
                    }
                };
                let vmus: VmusResource = match serde_json::from_str(&text) {
                    Ok(r) => r,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not parse {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_MUSIC\n_{sym}_MUSIC:\n    .word 0\n\n"));
                        continue;
                    }
                };
                s.push_str(&compile_vmus(&vmus, &asset.name));
            }
            AssetType::Sfx => {
                let text = match fs::read_to_string(&asset.path) {
                    Ok(t) => t,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not read {}: {}\n", asset.path, e));
                        continue;
                    }
                };
                let vsfx: VsfxResource = match serde_json::from_str(&text) {
                    Ok(r) => r,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not parse {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_SFX\n_{sym}_SFX:\n    .word 0\n\n"));
                        continue;
                    }
                };
                s.push_str(&compile_vsfx(&vsfx, &asset.name));
            }
            AssetType::Level => {
                let text = match std::fs::read_to_string(&asset.path) {
                    Ok(t) => t,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not read level {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_LEVEL\n_{sym}_LEVEL:\n    .word 0\n\n"));
                        continue;
                    }
                };
                let level: crate::levelres::VPlayLevel = match serde_json::from_str(&text) {
                    Ok(r) => r,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not parse level {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_LEVEL\n_{sym}_LEVEL:\n    .word 0\n\n"));
                        continue;
                    }
                };
                let venemy_dir = std::path::Path::new(&asset.path)
                    .parent()
                    .and_then(|p| p.parent())
                    .map(|p| p.join("enemies"));
                s.push_str(&level.compile_to_arm_asm_with_venemy_and_meshes(&dims_map, venemy_dir.as_deref(), &vec_meshes, &vec_walk_areas));
            }
            AssetType::Animation => {
                let text = match fs::read_to_string(&asset.path) {
                    Ok(t) => t,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not read {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _ANIM_{sym}\n_ANIM_{sym}:\n    .word 0\n\n"));
                        continue;
                    }
                };
                let resource: VanimResource = match serde_json::from_str(&text) {
                    Ok(r) => r,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not parse {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _ANIM_{sym}\n_ANIM_{sym}:\n    .word 0\n\n"));
                        continue;
                    }
                };
                s.push_str(&compile_vanim_for_arm(&resource, &asset.name));
            }
            AssetType::Instrument => {
                let text = match fs::read_to_string(&asset.path) {
                    Ok(t) => t,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not read {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_INSTR\n_{sym}_INSTR:\n    .space 16\n\n"));
                        continue;
                    }
                };
                match serde_json::from_str::<InstrResource>(&text) {
                    Ok(instr) => s.push_str(&instr.compile_to_arm_asm_with_name(&asset.name)),
                    Err(e) => {
                        eprintln!("[WARNING] Failed to parse vinstr '{}': {}", asset.name, e);
                        s.push_str(&format!(".global _{sym}_INSTR\n_{sym}_INSTR:\n    .space 16\n\n"));
                    }
                }
            }
            AssetType::Enemy => {
                let text = match fs::read_to_string(&asset.path) {
                    Ok(t) => t,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not read {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_DATA\n_{sym}_DATA:\n    .word 0\n\n"));
                        continue;
                    }
                };
                match serde_json::from_str::<EnemyResource>(&text) {
                    Ok(enemy) => s.push_str(&enemy.compile_to_arm_state_table(Some(&asset.name), &vec_min_y, &dims_map)),
                    Err(e) => {
                        eprintln!("[WARNING] Failed to parse venemy '{}': {}", asset.name, e);
                        s.push_str(&format!(".global _{sym}_DATA\n_{sym}_DATA:\n    .word 0\n\n"));
                    }
                }
            }
            #[allow(unreachable_patterns)]
            _ => {
                s.push_str(&format!("@ Asset stub: {} ({:?})\n", asset.name, asset.asset_type));
                s.push_str(&format!(".global _{sym}_DATA\n_{sym}_DATA:\n    .word 0\n\n"));
            }
        }
    }

    s
}

// ============================================================
// Music compiler (.vmus → PSG event table)
// ============================================================
//
// Binary layout (matches vpy_music_update reader in builtins.rs):
//   [base+0]: .word num_events
//   [base+4]: .word loop_event_byte_offset  (from base, NOT from base+8)
//   [base+8]: events start here (PSG_MUSIC_PTR = base+8 on play)
//
// Each event:
//   byte 0: delay_frames — read by PREVIOUS event handler into PSG_DELAY_FRAMES
//             = (this_frame - prev_frame - 1), clamped 0-255
//   byte 1: num_writes — 0=end, 0xFF=loop, else N writes follow
//   byte 2..2+2N: (reg, val) pairs
//
// Delay semantics: engine decrements PSG_DELAY_FRAMES each frame while > 0;
//   when 0 it fires the event at PSG_MUSIC_PTR, then reads delay from NEXT event.
//   So delay_byte D means "N+1 frames after current event, fire next event".

fn compile_vmus(vmus: &VmusResource, override_name: &str) -> String {
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");

    // Timing conversion: ticks → frames @ 50 fps.
    // Both the emulator RAF loop (TARGET_MS = 1000/50) and real rp2350 hardware
    // target 50 Hz to match Vectrex PAL timing.  PiTrex also uses 50 fps.
    let ticks_per_sec = vmus.tempo / 60.0 * vmus.ticks_per_beat;
    let tick_to_frame = |t: f64| -> u32 { (t * 50.0 / ticks_per_sec).round() as u32 };

    let loop_start_frame = tick_to_frame(vmus.loop_start);
    let loop_end_frame = tick_to_frame(vmus.loop_end.unwrap_or(vmus.total_ticks));

    // ── Build frame → Vec<(reg, val)> map ───────────────────────────────────
    // Note-off writes are pushed first so note-on writes for the same register
    // and same frame survive the dedup (keep-last logic below).
    let mut frame_writes: BTreeMap<u32, Vec<(u8, u8)>> = BTreeMap::new();

    // Track active tone/noise intervals to compute mixer at each change point
    struct ToneInterval { on: u32, off: u32, ch: usize }
    struct NoiseInterval { on: u32, off: u32, ch_mask: u8, #[allow(dead_code)] period: u8 }
    let mut tones: Vec<ToneInterval> = Vec::new();
    let mut noises: Vec<NoiseInterval> = Vec::new();

    // Pre-collect tone intervals so the noise loop can avoid clobbering tone volumes.
    // Noise and tone share the same PSG volume register when routed to the same channel;
    // a noise-off (vol=0) must not silence a tone that is still playing.
    let tone_intervals_early: Vec<(usize, u32, u32)> = vmus.notes.iter().map(|n| {
        let ch  = n.channel.min(2) as usize;
        let on  = tick_to_frame(n.start);
        let off = tick_to_frame(n.start + n.duration);
        (ch, on, off)
    }).collect();

    // --- Noise first (lower priority — tone amplitude will overwrite on same frame) ---
    for noise in &vmus.noise {
        let on_f  = tick_to_frame(noise.start);
        let off_f = tick_to_frame(noise.start + noise.duration);
        let amp = noise.velocity.min(15);

        frame_writes.entry(on_f).or_default().push((6, noise.period));
        for ch in 0..3u8 {
            if noise.channels & (1 << ch) != 0 {
                let ch_idx = ch as usize;
                // Only write noise amplitude when no tone is already playing on this channel.
                // If a tone starts on the same frame, dedup keeps the note-on (pushed later) — fine.
                // But if a tone started earlier (no note event this frame), the noise-on vol
                // would silently override the tone amplitude until the next note event.
                let tone_active_at_on = tone_intervals_early.iter()
                    .any(|&(tc, ton, toff)| tc == ch_idx && ton < on_f && on_f < toff);
                if !tone_active_at_on {
                    frame_writes.entry(on_f).or_default().push((8 + ch, amp));
                }
                // Noise-off: only write vol=0 if no tone note is still playing past this frame.
                // Otherwise the vol=0 would silence the note prematurely.
                let tone_extends_past_off = tone_intervals_early.iter()
                    .any(|&(tc, ton, toff)| tc == ch_idx && ton <= off_f && toff > off_f);
                if !tone_extends_past_off {
                    frame_writes.entry(off_f).or_default().push((8 + ch, 0));
                }
            }
        }
        noises.push(NoiseInterval { on: on_f, off: off_f, ch_mask: noise.channels, period: noise.period });
    }

    // --- Notes (higher priority — pushed after noise so amplitude survives dedup) ---
    for note in &vmus.notes {
        let ch = (note.channel.min(2)) as usize;
        let on_f  = tick_to_frame(note.start);
        let off_f = tick_to_frame(note.start + note.duration);

        let freq = 440.0 * 2f64.powf((note.note as f64 - 69.0) / 12.0);
        let period = (93750.0 / freq).round() as u16;
        let period = period.min(0xFFF);
        let amp = note.velocity.min(15);

        let reg_lo  = (ch * 2) as u8;
        let reg_hi  = (ch * 2 + 1) as u8;
        let reg_vol = (8 + ch) as u8;

        // Note-off (pushed before note-on so note-on amplitude wins on same frame)
        frame_writes.entry(off_f).or_default().extend_from_slice(&[(reg_vol, 0)]);
        // Note-on: period + amplitude (last write to reg_vol wins over noise amp)
        frame_writes.entry(on_f).or_default().extend_from_slice(&[
            (reg_lo,  (period & 0xFF) as u8),
            (reg_hi,  ((period >> 8) & 0x0F) as u8),
            (reg_vol, amp),
        ]);

        tones.push(ToneInterval { on: on_f, off: off_f, ch });
    }

    // ── Compute mixer at each frame where tone/noise state changes ───────────
    let mixer_frames: std::collections::BTreeSet<u32> = tones.iter()
        .flat_map(|t| [t.on, t.off])
        .chain(noises.iter().flat_map(|n| [n.on, n.off]))
        .collect();

    for frame in mixer_frames {
        let mut mixer = 0x3Fu8; // all disabled
        for t in &tones {
            if frame >= t.on && frame < t.off {
                mixer &= !(1u8 << t.ch);       // enable tone channel
            }
        }
        for n in &noises {
            if frame >= n.on && frame < n.off {
                for bit in 0..3u8 {
                    if n.ch_mask & (1 << bit) != 0 {
                        mixer &= !(1u8 << (3 + bit)); // enable noise channel
                    }
                }
            }
        }
        frame_writes.entry(frame).or_default().push((7, mixer));
    }

    // ── Dedup: for each frame, keep last write per register ─────────────────
    for writes in frame_writes.values_mut() {
        let mut seen: Vec<u8> = Vec::new();
        let mut deduped: Vec<(u8, u8)> = Vec::new();
        for &(reg, val) in writes.iter().rev() {
            if !seen.contains(&reg) {
                seen.push(reg);
                deduped.push((reg, val));
            }
        }
        deduped.reverse();
        *writes = deduped;
    }

    // ── Drop empty frames ────────────────────────────────────────────────────
    frame_writes.retain(|_, writes| !writes.is_empty());

    // ── Build sorted event list (frame, writes) ──────────────────────────────
    let events: Vec<(u32, Vec<(u8, u8)>)> = frame_writes.into_iter().collect();

    // ── Find loop_event_byte_offset ──────────────────────────────────────────
    // Byte offset from base (= from start of _NAME_MUSIC label) to the loop-start event.
    // Header = 8 bytes, then events sequentially.
    let loop_evt_idx = events.iter().position(|(f, _)| *f >= loop_start_frame).unwrap_or(0);
    let mut loop_byte_offset: u32 = 8; // skip header
    for (i, (_, writes)) in events.iter().enumerate() {
        if i == loop_evt_idx { break; }
        loop_byte_offset += 2 + 2 * writes.len() as u32; // delay + num_writes + N×(reg,val)
    }

    // ── Emit assembly ────────────────────────────────────────────────────────
    let mut s = String::new();
    s.push_str(&format!("@ --- {} MUSIC ({} events, loop@{}) ---\n",
        override_name, events.len(), loop_start_frame));
    s.push_str(&format!(".global _{sym}_MUSIC\n_{sym}_MUSIC:\n"));
    s.push_str(&format!("    .word   {}           @ num_events\n", events.len()));
    s.push_str(&format!("    .word   {}           @ loop_event_byte_offset from base\n", loop_byte_offset));

    let mut prev_frame: u32 = 0;
    for (i, (frame, writes)) in events.iter().enumerate() {
        // delay_byte: read by previous event handler to set PSG_DELAY_FRAMES.
        //   delay_byte=0 → next event fires 1 frame after current.
        //   first event's delay_byte: not read on first play; read on loop restart.
        //   For loop-start event, set to 0 so loop restarts 1 frame after loop trigger.
        let delay_byte: u8 = if i == 0 || i == loop_evt_idx {
            0 // immediate restart on loop; first event always fires immediately
        } else {
            (*frame - prev_frame).saturating_sub(1).min(255) as u8
        };
        s.push_str(&format!("    .byte   {}, {}  @ frame={} delay={} writes={}\n",
            delay_byte, writes.len(), frame, delay_byte, writes.len()));
        for (reg, val) in writes {
            s.push_str(&format!("    .byte   {}, {}  @ PSG r{}\n", reg, val, reg));
        }
        prev_frame = *frame;
    }

    // Loop marker: fires at loopEnd, jumps back to loop_event_byte_offset
    let last_event_frame = events.last().map(|(f, _)| *f).unwrap_or(0);
    let loop_marker_delay = loop_end_frame.saturating_sub(last_event_frame).saturating_sub(1).min(255) as u8;
    s.push_str(&format!("    .byte   {}, 0xFF   @ loop back (fires frame ~{})\n",
        loop_marker_delay, loop_end_frame));
    s.push('\n');
    s
}

// ============================================================
// SFX compiler (.vsfx → PSG event table)
// ============================================================
//
// Binary layout (matches vpy_audio_update in builtins.rs):
//   [base+0]: .word num_events
//   [base+4]: events start (PSG_SFX_PTR = base+4 on play)
//
// Same per-event format as music. No loop marker; ends with num_writes=0.
// Per-frame events: delay=0 between consecutive frames.

fn compile_vsfx(vsfx: &VsfxResource, override_name: &str) -> String {
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");

    // Force SFX onto channel C (regs 4/5 period, 10 volume) so it cannot
    // overwrite music playing on channels A/B. Matches M6809 sfx_doframe,
    // which hard-codes channel C for the SFX engine. Authors can still
    // pick a channel in the .vsfx editor for preview, but at compile time
    // we always retarget to C.
    let _ = vsfx.oscillator.channel;
    let ch = 2usize;
    let reg_lo  = (ch * 2) as u8;
    let reg_hi  = (ch * 2 + 1) as u8;
    let reg_vol = (8 + ch) as u8;

    let total_frames = ((vsfx.duration_ms / 20.0).round() as u32).max(1);
    let attack_f  = (vsfx.envelope.attack  / 20.0).round() as u32;
    let decay_f   = (vsfx.envelope.decay   / 20.0).round() as u32;
    let release_f = (vsfx.envelope.release / 20.0).round() as u32;
    let peak    = vsfx.envelope.peak.min(15);
    let sustain = vsfx.envelope.sustain.min(15);

    // Effective start_mult / end_mult (default 1.0 if pitch disabled or zero)
    let s_mult = if vsfx.pitch.enabled && vsfx.pitch.start_mult > 0.0 { vsfx.pitch.start_mult } else { 1.0 };
    let e_mult = if vsfx.pitch.enabled && vsfx.pitch.end_mult > 0.0   { vsfx.pitch.end_mult   } else { 1.0 };
    let base_freq = if vsfx.oscillator.frequency > 0.0 { vsfx.oscillator.frequency } else { 440.0 };

    // Noise decay: noise.volume decays to 0 over noise.decay_ms
    let noise_total_frames = if vsfx.noise.enabled && vsfx.noise.decay_ms > 0.0 {
        (vsfx.noise.decay_ms as f64 / 20.0).round().max(1.0)
    } else {
        total_frames as f64
    };

    // Build per-frame events (only emit when values actually change)
    let mut frame_events: Vec<(u32, Vec<(u8, u8)>)> = Vec::new();
    let mut prev_period: u16 = 0xFFFF;
    let mut prev_vol: u8 = 0xFF;
    let mut prev_mixer: u8 = 0xFF;

    // Proper ADSR phase allocation — matches sfxres.rs M6809 logic.
    // Without an explicit sustain_f slot the original code skipped sustain
    // entirely (sound ended after attack+decay+release frames), and arpeggio
    // SFX (jump.vsfx, etc.) just played the linear pitch sweep without note
    // jumps because the arpeggio branch was missing.
    let attack_f  = attack_f.min(total_frames);
    let decay_f   = decay_f.min(total_frames.saturating_sub(attack_f));
    let release_f = release_f.min(total_frames.saturating_sub(attack_f + decay_f));
    let sustain_f = total_frames.saturating_sub(attack_f + decay_f + release_f);

    let arp_enabled = vsfx.modulation.arpeggio && !vsfx.modulation.arpeggio_notes.is_empty();
    let arp_speed_ms = vsfx.modulation.arpeggio_speed.max(1) as f64;
    let base_midi = if base_freq > 0.0 { 69.0 + 12.0 * (base_freq / 440.0).log2() } else { 69.0 };

    for frame in 0..total_frames {
        let mut writes: Vec<(u8, u8)> = Vec::new();

        // ADSR volume (A → D → S → R)
        let tone_vol: u8 = if frame < attack_f {
            ((peak as u32 * frame / attack_f.max(1)) as u8).min(15)
        } else if frame < attack_f + decay_f {
            let f = frame - attack_f;
            let drop = (peak as i32 - sustain as i32) * f as i32 / decay_f.max(1) as i32;
            (peak as i32 - drop).max(0).min(15) as u8
        } else if frame < attack_f + decay_f + sustain_f {
            sustain
        } else if release_f > 0 {
            let f = frame - attack_f - decay_f - sustain_f;
            (sustain as u32 * (release_f - f.min(release_f)) / release_f).min(15) as u8
        } else {
            0
        };

        // Noise volume: decays over noise.decay_ms, independent of tone envelope
        let noise_vol: u8 = if vsfx.noise.enabled {
            let progress = (frame as f64 / noise_total_frames).min(1.0);
            ((1.0 - progress) * vsfx.noise.volume as f64).round() as u8
        } else {
            0
        };

        // Channel volume = louder of tone ADSR or noise decay
        let vol = tone_vol.max(noise_vol).min(15);

        // Pitch: arpeggio steps through arpeggio_notes (semitone offsets); else
        // a linear pitch sweep between start_mult and end_mult. M6809 sfxres.rs
        // prioritises arpeggio over pitch sweep — match that so the same SFX
        // sounds the same across targets.
        let period: u16 = if arp_enabled {
            let frame_time_ms = (frame as f64) * 20.0; // 50 fps → 20 ms/frame
            let n = vsfx.modulation.arpeggio_notes.len();
            let idx = ((frame_time_ms / arp_speed_ms) as usize) % n;
            let offset = vsfx.modulation.arpeggio_notes[idx] as f64;
            let freq = 440.0 * 2f64.powf((base_midi + offset - 69.0) / 12.0);
            if freq > 0.0 { (88200.0 / freq).round() as u16 } else { 0xFFF }
        } else {
            let t = if total_frames > 1 { frame as f64 / (total_frames - 1) as f64 } else { 0.0 };
            let mult = s_mult + (e_mult - s_mult) * t;
            let freq = base_freq * mult;
            if freq > 0.0 { (88200.0 / freq).round() as u16 } else { 0xFFF }
        };
        let period = period.max(1).min(0xFFF);

        let noise_active = vsfx.noise.enabled && noise_vol > 0;

        // Mixer
        let mut mixer = 0x3Fu8;
        if vol > 0 { mixer &= !(1u8 << ch); }
        if noise_active { mixer &= !(1u8 << (3 + ch)); }

        // Only emit noise period write on frame 0
        if frame == 0 && vsfx.noise.enabled {
            writes.push((6, vsfx.noise.period));
        }

        // Period (only if changed)
        if period != prev_period {
            writes.push((reg_lo, (period & 0xFF) as u8));
            writes.push((reg_hi, ((period >> 8) & 0x0F) as u8));
            prev_period = period;
        }

        // Volume (only if changed)
        if vol != prev_vol {
            writes.push((reg_vol, vol));
            prev_vol = vol;
        }

        // Mixer (only if changed)
        if mixer != prev_mixer {
            writes.push((7, mixer));
            prev_mixer = mixer;
        }

        if !writes.is_empty() {
            frame_events.push((frame, writes));
        }
    }

    // Mute-all event after SFX ends (one frame after last write)
    {
        let mute_frame = total_frames;
        // Silence amplitude + disable all mixer channels (reg7=0x3F).
        // reg_vol already covers the channel amplitude; noise uses same reg.
        let mute = vec![(reg_vol, 0u8), (7u8, 0x3Fu8)];
        frame_events.push((mute_frame, mute));
    }

    // ── Emit ─────────────────────────────────────────────────────────────────
    let mut s = String::new();
    s.push_str(&format!("@ --- {} SFX ({} frames, {} events) ---\n",
        override_name, total_frames, frame_events.len()));
    s.push_str(&format!(".global _{sym}_SFX\n_{sym}_SFX:\n"));
    s.push_str(&format!("    .word   {}  @ num_events\n", frame_events.len()));

    let mut prev_frame: u32 = 0;
    for (i, (frame, writes)) in frame_events.iter().enumerate() {
        let delay_byte: u8 = if i == 0 {
            0 // first event: delay not read on initial fire
        } else {
            (*frame - prev_frame).saturating_sub(1).min(255) as u8
        };
        s.push_str(&format!("    .byte   {}, {}  @ frame={}\n",
            delay_byte, writes.len(), frame));
        for (reg, val) in writes {
            s.push_str(&format!("    .byte   {}, {}  @ PSG r{}\n", reg, val, reg));
        }
        prev_frame = *frame;
    }
    // End marker
    s.push_str("    .byte   0, 0  @ end\n\n");
    s
}

// ============================================================
// Vector asset emitters (unchanged)
// ============================================================

fn emit_vec_resource(res: &VecResource, override_name: &str) -> String {
    let mut s = String::new();
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let (center_x, center_y) = res.calculate_center();

    let paths = res.visible_paths();

    s.push_str(&format!("@ --- {} ({} path(s)) ---\n", override_name, paths.len()));
    s.push_str(&format!(".global _{sym}_VECTORS\n"));
    s.push_str(&format!("_{sym}_VECTORS:\n"));

    if paths.is_empty() {
        s.push_str("    .word   0               @ empty: path_count\n");
        s.push_str("    .byte   0x02            @ end marker\n\n");
        return s;
    }

    s.push_str(&format!("    .word   {}               @ path_count\n", paths.len()));
    for i in 0..paths.len() {
        s.push_str(&format!("    .word   _{sym}_PATH{i}      @ ptr path {i}\n"));
    }
    s.push_str("\n");

    for (idx, path) in paths.iter().enumerate() {
        s.push_str(&format!("_{sym}_PATH{idx}:\n"));

        if path.points.is_empty() {
            s.push_str("    .byte   0x02            @ end marker (empty path)\n\n");
            continue;
        }

        let intensity = path.intensity;
        let p0 = &path.points[0];
        let y0 = (p0.y - center_y).clamp(-127, 127) as i8;
        let x0 = (p0.x - center_x).clamp(-127, 127) as i8;

        s.push_str(&format!(
            "    .byte   {}               @ intensity\n",
            intensity
        ));
        s.push_str(&format!(
            "    .byte   0x{:02X}, 0x{:02X}, 0x00, 0x00  @ y={}, x={}, hdr\n",
            y0 as u8, x0 as u8, y0, x0
        ));

        for j in 0..path.points.len() - 1 {
            let pf = &path.points[j];
            let pt = &path.points[j + 1];
            let dx = pt.x - pf.x;
            let dy = pt.y - pf.y;
            emit_split_segment_arm(&mut s, dx, dy);
        }

        if path.closed && path.points.len() > 2 {
            let pf = &path.points[path.points.len() - 1];
            let pt = &path.points[0];
            let dx = pt.x - pf.x;
            let dy = pt.y - pf.y;
            emit_split_segment_arm(&mut s, dx, dy);
        }

        s.push_str("    .byte   0x02            @ end marker\n\n");
    }

    s
}

fn emit_3d_resource(res: &VecResource, override_name: &str) -> String {
    let mut s = String::new();
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");

    let visible = res.visible_paths();
    s.push_str(&format!("@ --- {sym}_3D_DATA ({} path(s)) ---\n", visible.len()));
    // The runtime reads vertex_count and path_count with `ldr` (4-byte load),
    // so the symbol must be 4-byte aligned. Without this the symbol lands at
    // whatever offset the previous .byte stream finished at — unaligned ldr
    // returns rotated bytes on Cortex-M33 / ARMv6.
    s.push_str("    .balign 4\n");
    s.push_str(&format!(".global _{sym}_3D_DATA\n_{sym}_3D_DATA:\n"));

    if visible.is_empty() {
        s.push_str("    .word   0               @ vertex_count\n");
        s.push_str("    .word   0               @ path_count\n\n");
        return s;
    }

    let mut vertex_map: std::collections::HashMap<(i8, i8, i8), u8> = std::collections::HashMap::new();
    let mut vertices: Vec<(i8, i8, i8)> = Vec::new();

    struct PathRec { closed: bool, indices: Vec<u8> }
    let mut paths: Vec<PathRec> = Vec::new();

    for path in &visible {
        if path.points.is_empty() { continue; }
        let mut indices = Vec::new();
        for pt in &path.points {
            let x = pt.x.clamp(-63, 63) as i8;
            let y = pt.y.clamp(-63, 63) as i8;
            let z = pt.z.unwrap_or(0).clamp(-63, 63) as i8;
            let key = (x, y, z);
            let idx = if let Some(&i) = vertex_map.get(&key) {
                i
            } else {
                let i = vertices.len() as u8;
                vertices.push(key);
                vertex_map.insert(key, i);
                i
            };
            indices.push(idx);
        }
        paths.push(PathRec { closed: path.closed, indices });
    }

    s.push_str(&format!("    .word   {}               @ vertex_count\n", vertices.len()));
    for (i, &(x, y, z)) in vertices.iter().enumerate() {
        s.push_str(&format!(
            "    .byte   0x{:02X}, 0x{:02X}, 0x{:02X}  @ vert {}: x={},y={},z={}\n",
            x as u8, y as u8, z as u8, i, x, y, z
        ));
    }

    // Align before .word path_count — vertex_count*3 bytes of vertex data may
    // not leave us on a 4-byte boundary. The runtime mirrors this with a
    // `bic r4, r4, #3` step (after `add r4, r4, #3`) so the ldr is aligned.
    s.push_str("    .balign 4\n");
    s.push_str(&format!("    .word   {}               @ path_count\n", paths.len()));
    for (pi, pd) in paths.iter().enumerate() {
        s.push_str(&format!("    .byte   {}               @ path {}: pt_count\n", pd.indices.len(), pi));
        s.push_str(&format!("    .byte   {}               @ path {}: closed\n", if pd.closed {1} else {0}, pi));
        for &idx in &pd.indices {
            s.push_str(&format!("    .byte   {idx}\n"));
        }
    }
    s.push('\n');
    s
}

fn emit_split_segment_arm(s: &mut String, dx: i16, dy: i16) {
    let n = {
        let max_d = dx.abs().max(dy.abs()) as usize;
        if max_d == 0 { return; }
        (max_d + 126) / 127
    };

    let mut rem_dx = dx;
    let mut rem_dy = dy;
    for step in 0..n {
        let steps_left = (n - step) as i16;
        let sub_dx = rem_dx / steps_left;
        let sub_dy = rem_dy / steps_left;
        rem_dx -= sub_dx;
        rem_dy -= sub_dy;
        s.push_str(&format!(
            "    .byte   0xFF, 0x{:02X}, 0x{:02X}  @ line dy={}, dx={}\n",
            sub_dy as u8, sub_dx as u8, sub_dy, sub_dx
        ));
    }
}

// ============================================================
// Animation asset emitter (ARM 32-bit .word pointers)
// ============================================================
// Same format as pitrex/assets.rs compile_vanim_for_arm.
// Header uses .byte for fixed fields and .word for ARM absolute ptrs.

fn compile_vanim_for_arm(resource: &VanimResource, asset_name: &str) -> String {
    let sym = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let mut s = String::new();

    // Convert inline paths to synthetic vec assets first — emitted as full ARM
    // _LABEL_VECTORS blocks so they go through the same render path as named
    // vec_refs. Each inline path becomes a one-path anonymous vec asset.
    let mut resource_mut = resource.clone();
    let synthetic = crate::animres::extract_inline_paths_to_vec_refs(&mut resource_mut, asset_name);
    for (label, path) in &synthetic {
        let lsym = label.to_uppercase().replace('-', "_").replace(' ', "_");
        s.push_str(&format!("@ synthetic vec asset for inline path: {}\n", label));
        s.push_str(".balign 4\n");
        s.push_str(&format!(".global _{lsym}_VECTORS\n"));
        s.push_str(&format!("_{lsym}_VECTORS:\n"));
        s.push_str("    .word   1               @ path_count\n");
        s.push_str(&format!("    .word   _{lsym}_PATH0      @ ptr path 0\n"));
        s.push_str(&format!("_{lsym}_PATH0:\n"));
        if path.points.is_empty() {
            s.push_str("    .byte   0x02            @ end marker (empty path)\n\n");
        } else {
            let p0 = &path.points[0];
            let y0 = p0.y.clamp(-127, 127) as i8;
            let x0 = p0.x.clamp(-127, 127) as i8;
            s.push_str(&format!("    .byte   {}               @ intensity\n", path.intensity));
            s.push_str(&format!(
                "    .byte   0x{:02X}, 0x{:02X}, 0x00, 0x00  @ y={}, x={}, hdr\n",
                y0 as u8, x0 as u8, y0, x0
            ));
            for j in 0..path.points.len() - 1 {
                let pf = &path.points[j];
                let pt = &path.points[j + 1];
                let dx = pt.x - pf.x;
                let dy = pt.y - pf.y;
                emit_split_segment_arm(&mut s, dx, dy);
            }
            s.push_str("    .byte   0x02            @ end marker\n\n");
        }
    }
    let resource = &resource_mut;

    let base_ref_count = resource.base_refs.len();
    let frame_count = resource.frames.len();
    let loop_flag: u8 = if resource.r#loop { 1 } else { 0 };
    let frame_table_offset = 4 + base_ref_count * 4;

    s.push_str(&format!("@ --- Animation: {} ({} frames, {} base_refs) ---\n",
        asset_name, frame_count, base_ref_count));
    s.push_str(".balign 4\n");
    s.push_str(&format!(".global _ANIM_{sym}\n"));
    s.push_str(&format!("_ANIM_{sym}:\n"));
    s.push_str(&format!("    .byte {}, {}, {}, {}  @ frame_count, loop, base_ref_count, frame_table_offset\n",
        frame_count, loop_flag, base_ref_count, frame_table_offset));

    for base_ref in &resource.base_refs {
        let bsym = base_ref.to_uppercase().replace('-', "_").replace(' ', "_");
        s.push_str(&format!("    .word _{bsym}_VECTORS  @ base_ref '{base_ref}'\n"));
    }

    for frame in &resource.frames {
        s.push_str(&format!("    .word _ANIM_{sym}_F{}  @ frame {}\n", frame.index, frame.index));
    }

    for frame in &resource.frames {
        let vec_ref_count = frame.vec_refs.len();
        s.push_str(".balign 4\n");
        s.push_str(&format!("_ANIM_{sym}_F{}:\n", frame.index));
        s.push_str(&format!("    .byte {}, {}  @ duration_ticks, vec_ref_count\n",
            frame.duration_ticks, vec_ref_count));
        if vec_ref_count > 0 {
            s.push_str("    .byte 0, 0  @ alignment padding\n");
        }
        for vec_ref in &frame.vec_refs {
            let vsym = vec_ref.to_uppercase().replace('-', "_").replace(' ', "_");
            s.push_str(&format!("    .word _{vsym}_VECTORS  @ vec_ref '{vec_ref}'\n"));
        }
        s.push_str("    .byte 0  @ inline_path_count (paths converted to synthetic vec_refs)\n");
    }
    s.push('\n');
    s
}
