//! VPy Enemy Resource format (.venemy)
//!
//! Enemy type definitions stored as JSON that get compiled into ROM data tables.
//! Used by the runtime enemy system.  Models actions (sprites + loop flags),
//! stats (hp/speed/duration), and behavior (patrol/chase AI).

use std::collections::HashMap;
use std::path::Path;
use serde::{Deserialize, Serialize};
use anyhow::Result;

/// Enemy resource file extension
pub const VENEMY_EXTENSION: &str = "venemy";

// ---------------------------------------------------------------------------
// JSON deserialization types
// ---------------------------------------------------------------------------

/// Root structure of a .venemy file
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EnemyResource {
    /// File format version
    #[serde(default = "default_version")]
    pub version: String,

    /// Enemy type name (used for symbol generation)
    pub name: String,

    /// List of actions (each has a sprite + loop flag)
    #[serde(default)]
    pub actions: Vec<EnemyAction>,

    /// Combat / movement stats
    #[serde(default)]
    pub stats: EnemyStats,

    /// AI behaviour definition
    #[serde(default)]
    pub behavior: EnemyBehavior,

    /// Optional state machine (snow/freeze mechanic etc.)
    #[serde(default, rename = "state_machine")]
    pub state_machine: Option<EnemyStateMachine>,
}

/// A single enemy action (animation state)
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EnemyAction {
    /// Action name, e.g. "idle", "walk", "frozen"
    pub name: String,

    /// Full filesystem path to the sprite asset (.vec or .vanim).
    /// Empty string means "no sprite assigned yet".
    #[serde(default)]
    pub sprite: String,

    /// Whether the action loops continuously
    #[serde(default, rename = "loop")]
    pub loop_anim: bool,

    /// Action type: "animation" (default) or "shoot"
    #[serde(default, rename = "type")]
    pub action_type: Option<String>,

    /// Shoot direction: "side" (default) or "down"
    #[serde(default)]
    pub direction: Option<String>,

    /// Shoot side only: mirror projectile based on enemy facing
    #[serde(default)]
    pub mirror: Option<bool>,
}

/// Enemy stats block
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EnemyStats {
    /// Hit-points
    #[serde(default = "default_hp")]
    pub hp: u8,

    /// Movement speed in VPy units per second
    #[serde(default)]
    pub speed: u8,

    /// How long (in frames) to stay in each action before re-evaluating
    #[serde(default = "default_action_duration")]
    pub action_duration: u16,
}

/// AI behaviour definition
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EnemyBehavior {
    /// Primary behaviour type: "patrol", "chase", "flee", "static"
    #[serde(default = "default_behavior_type", rename = "type")]
    pub behavior_type: String,

    /// Patrol sub-config (only used when type == "patrol")
    #[serde(default)]
    pub patrol: Option<PatrolConfig>,

    /// Distance at which the enemy starts chasing the player (0 = disabled)
    #[serde(default)]
    pub chase_range: u8,

    /// Whether the enemy respawns after being defeated
    #[serde(default)]
    pub respawn: bool,

    /// Wave number (0 = always present, >0 = spawns on that wave)
    #[serde(default)]
    pub wave: u8,
}

/// Patrol behaviour configuration
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PatrolConfig {
    #[serde(default)]
    pub waypoints: Vec<serde_json::Value>, // raw — not compiled directly
    #[serde(default = "default_loop_true", rename = "loop")]
    pub loop_patrol: bool,
}

// ── State Machine ────────────────────────────────────────────────────────────

/// A single event-driven transition: when `event` fires → move to state `to`
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EnemyStateTransition {
    /// Event name, e.g. "onSnowHit", "onKick"
    pub event: String,
    /// Name of the target state
    pub to: String,
}

/// One state in the enemy FSM
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EnemyState {
    /// Unique state identifier, e.g. "normal", "snow1", "ball"
    pub name: String,
    /// Which action (from actions[]) plays while in this state
    #[serde(default)]
    pub action: String,
    /// After this many frames, auto-transition to `decay_to` (0 = no decay)
    #[serde(default)]
    pub decay_frames: u16,
    /// State name to transition to on decay (empty = stay)
    #[serde(default)]
    pub decay_to: String,
    /// Event-driven transitions
    #[serde(default)]
    pub on_event: Vec<EnemyStateTransition>,
}

/// Enemy finite-state machine definition
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EnemyStateMachine {
    /// Name of the initial state
    pub initial_state: String,
    /// All states in this FSM
    pub states: Vec<EnemyState>,
}

fn default_version()         -> String { "1.0".to_string() }
fn default_hp()              -> u8     { 1 }
fn default_action_duration() -> u16    { 60 }
fn default_behavior_type()   -> String { "patrol".to_string() }
fn default_loop_true()       -> bool   { true }

// ---------------------------------------------------------------------------
// Symbol helpers
// ---------------------------------------------------------------------------

/// Return sprite_type byte: 0 for .vec (or unknown), 1 for .vanim
fn sprite_type_byte(sprite_path: &str) -> u8 {
    let path = Path::new(sprite_path);
    match path.extension().and_then(|e| e.to_str()) {
        Some("vanim") => 1,
        _ => 0,
    }
}

/// Derive the ASM sprite symbol from a full filesystem path stored in the
/// `sprite` field.
///
/// - `.vec`   → `_{STEM_UPPER}_VECTORS`
/// - `.vanim` → `_ANIM_{STEM_UPPER}`
/// - empty    → `0`   (null pointer)
fn sprite_to_symbol(sprite_path: &str) -> String {
    if sprite_path.is_empty() {
        return "0".to_string();
    }
    let path = Path::new(sprite_path);
    let ext   = path.extension().and_then(|e| e.to_str()).unwrap_or("");
    let stem  = path.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_uppercase()
        .replace('-', "_")
        .replace(' ', "_");

    match ext {
        "vec"   => format!("_{}_VECTORS", stem),
        "vanim" => format!("_ANIM_{}", stem),
        _       => "0".to_string(),
    }
}

// ---------------------------------------------------------------------------
// EnemyResource impl
// ---------------------------------------------------------------------------

impl EnemyResource {
    /// Load a .venemy resource from a file.
    pub fn load(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let resource: EnemyResource = serde_json::from_str(&content)?;
        Ok(resource)
    }

    /// Estimated binary footprint for bin-packing.
    ///
    /// Layout:
    ///   5 bytes header  (hp, speed, action_duration×2, action_count)
    ///   4 bytes per action  (sprite FDB×2, sprite_type FCB×1, loop_anim FCB×1)
    pub fn estimate_binary_size(&self) -> usize {
        5 + self.actions.len() * 4
    }

    /// Compile to M6809 assembly.
    ///
    /// When `override_name` is `Some`, use that name for the generated labels
    /// instead of `self.name` (allows the file-stem to win over the JSON `name`
    /// field, matching the behaviour of every other resource type).
    pub fn compile_to_asm_with_name(&self, override_name: Option<&str>) -> String {
        let raw_name = override_name.unwrap_or(&self.name);
        let name_up = raw_name
            .to_uppercase()
            .replace(' ', "_")
            .replace('-', "_");

        let mut out = String::new();

        // ---- action index EQUs ----
        out.push_str(&format!("; ---- Enemy type: {} ----\n", name_up));
        for (i, action) in self.actions.iter().enumerate() {
            let action_up = action.name
                .to_uppercase()
                .replace(' ', "_")
                .replace('-', "_");
            out.push_str(&format!(
                "_{}_ACTION_{} EQU {}\n",
                name_up, action_up, i
            ));
        }
        out.push_str("\n");

        // ---- stat header ----
        let hp             = self.stats.hp;
        let speed          = self.stats.speed;
        let action_dur_hi  = (self.stats.action_duration >> 8) as u8;
        let action_dur_lo  = (self.stats.action_duration & 0xFF) as u8;
        let action_count   = self.actions.len() as u8;

        out.push_str(&format!("_{}_ENEMY:\n", name_up));
        out.push_str(&format!("    FCB {}          ; [0] hp\n", hp));
        out.push_str(&format!("    FCB {}          ; [1] speed (units/sec)\n", speed));
        out.push_str(&format!(
            "    FDB {}          ; [2-3] action_duration (frames, 16-bit)\n",
            self.stats.action_duration
        ));
        out.push_str(&format!("    FCB {}          ; [4] action_count\n", action_count));
        // Keep the individual bytes accessible as documentation
        let _ = (action_dur_hi, action_dur_lo); // suppress unused warnings
        // State machine pointer ([5-6], 0000 = no SM)
        if self.state_machine.is_some() {
            out.push_str(&format!("    FDB _{}_SM      ; [5-6] state machine ptr\n", name_up));
        } else {
            out.push_str("    FDB 0           ; [5-6] no state machine\n");
        }
        out.push_str("\n");

        // ---- action table ----
        // Layout per entry (4 bytes): FDB sprite_ptr, FCB sprite_type, FCB loop
        out.push_str(&format!("_{}_ENEMY_ACTIONS:\n", name_up));
        for (i, action) in self.actions.iter().enumerate() {
            let symbol      = sprite_to_symbol(&action.sprite);
            let sprite_type = sprite_type_byte(&action.sprite);
            let loop_val    = if action.loop_anim { 1u8 } else { 0u8 };
            out.push_str(&format!(
                "    FDB {}    ; action {} ({}) sprite ptr\n",
                symbol, i, action.name
            ));
            out.push_str(&format!(
                "    FCB {}                   ; sprite_type: 0=vec, 1=vanim\n",
                sprite_type
            ));
            out.push_str(&format!(
                "    FCB {}                   ; loop={}\n",
                loop_val, action.loop_anim
            ));
        }
        out.push_str("\n");

        // ---- state machine ----
        if let Some(sm) = &self.state_machine {
            out.push_str(&emit_state_machine_asm(&name_up, sm, &self.actions));
        }

        out
    }

    /// Emit ARM Thumb-2 state sprite table (_NAME_DATA symbol).
    /// Format: .word state_count, .byte feet_offset, .byte[3] pad, then per state:
    ///   .word sprite_ptr, .byte is_anim, .byte 0, 0, 0  (8 bytes each)
    /// feet_offset (signed) = 5 - min_y across all sprites for this enemy type.
    /// Draw: screen_y += feet_offset so the sprite's lowest pixel lands on area.y.
    /// vpy_enemy_fire_event reads entry at base+8+state*8.
    pub fn compile_to_arm_state_table(
        &self,
        override_name: Option<&str>,
        vec_min_y: &std::collections::HashMap<String, i16>,
    ) -> String {
        let raw_name = override_name.unwrap_or(&self.name);
        let name_up = raw_name.to_uppercase().replace(' ', "_").replace('-', "_");
        let plain = raw_name.to_lowercase();
        let prefix = format!("{}_", plain);
        let mut out = String::new();
        out.push_str(&format!(".global _{name_up}_DATA\n.balign 4\n_{name_up}_DATA:\n"));

        let states: Vec<(&str, &str)> = if let Some(sm) = &self.state_machine {
            sm.states.iter().map(|s| (s.name.as_str(), s.action.as_str())).collect()
        } else if let Some(a) = self.actions.first() {
            vec![("default", a.name.as_str())]
        } else {
            vec![]
        };

        // Compute feet_offset = 5 - min_y (smallest Y coord across all sprites for this type).
        // Matches PiTrex formula. With this, draw at world_y + feet_offset puts the
        // lowest pixel exactly 5 units above area.y (a small clearance).
        let mut acc_min_y: Option<i16> = None;
        for (name, &my) in vec_min_y {
            if name == &plain || name.starts_with(&prefix) {
                acc_min_y = Some(acc_min_y.map_or(my, |a| a.min(my)));
            }
        }
        // ARM: no extra shift (unlike PiTrex which adds 5 for its renderer offset).
        // feet_offset = -min_y so the sprite's lowest pixel lands exactly on area.y.
        let feet_offset: i8 = match acc_min_y {
            Some(my) => (-my).clamp(-127, 127) as i8,
            None => 0,
        };

        // Collect event routing entries from state machine.
        // Each entry: (from_state_idx, to_state_idx, event_name_string)
        let mut events: Vec<(u8, u8, String)> = Vec::new();
        if let Some(sm) = &self.state_machine {
            for (from_idx, state) in sm.states.iter().enumerate() {
                for ev in &state.on_event {
                    if let Some(to_idx) = sm.states.iter().position(|s| s.name == ev.to) {
                        events.push((from_idx as u8, to_idx as u8, ev.event.clone()));
                    }
                }
            }
        }
        let event_count = events.len().min(255) as u8;

        let state_count = states.len().max(1);
        out.push_str(&format!("    .word {state_count}    @ state_count\n"));
        out.push_str(&format!("    .byte {}              @ feet_offset (signed: screen_y += offset)\n", feet_offset as u8));
        out.push_str(&format!("    .byte {}              @ event_count\n", event_count));
        out.push_str("    .hword 0             @ pad\n");

        for (si, (state_name, action_name)) in states.iter().enumerate() {
            let (sym, is_anim) = self.actions.iter()
                .find(|a| a.name == *action_name)
                .map(|a| (sprite_to_symbol(&a.sprite), sprite_type_byte(&a.sprite)))
                .unwrap_or_else(|| ("0".to_string(), 0u8));
            out.push_str(&format!("    @ state {si}: {state_name}\n"));
            out.push_str(&format!("    .word {sym}   @ sprite_ptr\n"));
            out.push_str(&format!("    .byte {is_anim}   @ is_anim\n"));
            out.push_str("    .byte 0, 0, 0    @ pad\n");
        }

        // Event routing table (12 bytes per entry):
        //   +0: from_state(u8) + to_state(u8) + pad(u16)
        //   +4: name bytes 0-3 as LE u32
        //   +8: name bytes 4-7 as LE u32 (zero-padded)
        for (from, to, name) in events.iter().take(event_count as usize) {
            let nb: Vec<u8> = name.bytes().chain(std::iter::repeat(0u8)).take(8).collect();
            let name_lo = u32::from_le_bytes([nb[0], nb[1], nb[2], nb[3]]);
            let name_hi = u32::from_le_bytes([nb[4], nb[5], nb[6], nb[7]]);
            out.push_str(&format!("    @ event: {name} ({from} → {to})\n"));
            out.push_str(&format!("    .byte {from}, {to}, 0, 0\n"));
            out.push_str(&format!("    .word 0x{name_lo:08X}  @ name[0..3]\n"));
            out.push_str(&format!("    .word 0x{name_hi:08X}  @ name[4..7]\n"));
        }
        out.push_str("\n");
        out
    }

    /// Compile to M6809 assembly for **multibank** mode.
    ///
    /// The action table uses `FCB sprite_idx` (a 0-based index into
    /// `VECTOR_ADDR_TABLE` for vec sprites, or `ANIM_ADDR_TABLE` for vanim
    /// sprites) instead of `FDB sprite_ptr`.  This allows `DRAW_ENEMIES_RUNTIME`
    /// to call `DRAW_VECTOR_BANKED` / `DRAW_ANIM_BANKED` without resolving full
    /// addresses in the helpers bank.
    ///
    /// Action table entry format (6 bytes per entry):
    ///   byte [0]: sprite_idx  FCB — index into VECTOR_ADDR_TABLE (vec) or ANIM_ADDR_TABLE (vanim); $FF = none
    ///   byte [1]: sprite_type FCB — 0=vec, 1=vanim
    ///   byte [2]: loop        FCB — 0=no loop, 1=loop
    ///   byte [3]: pad         FCB — reserved
    ///   bytes [4-5]: anim_state FDB — 16-bit RAM address of 2-byte animation state
    ///                               (byte0=frame_idx, byte1=ticks_left); FDB 0 for vec actions
    pub fn compile_to_asm_indexed(
        &self,
        override_name: Option<&str>,
        vec_idx_map: &HashMap<String, u8>,
        anim_idx_map: &HashMap<String, u8>,
    ) -> String {
        let raw_name = override_name.unwrap_or(&self.name);
        let name_up = raw_name
            .to_uppercase()
            .replace(' ', "_")
            .replace('-', "_");

        let mut out = String::new();

        // Action index EQUs (same as non-indexed)
        out.push_str(&format!("; ---- Enemy type: {} (multibank indexed) ----\n", name_up));
        for (i, action) in self.actions.iter().enumerate() {
            let action_up = action.name
                .to_uppercase()
                .replace(' ', "_")
                .replace('-', "_");
            out.push_str(&format!(
                "_{}_ACTION_{} EQU {}\n",
                name_up, action_up, i
            ));
        }
        out.push_str("\n");

        // Stat header (identical layout)
        let hp            = self.stats.hp;
        let speed         = self.stats.speed;
        let action_count  = self.actions.len() as u8;

        out.push_str(&format!("_{}_ENEMY:\n", name_up));
        out.push_str(&format!("    FCB {}          ; [0] hp\n", hp));
        out.push_str(&format!("    FCB {}          ; [1] speed\n", speed));
        out.push_str(&format!(
            "    FDB {}          ; [2-3] action_duration\n",
            self.stats.action_duration
        ));
        out.push_str(&format!("    FCB {}          ; [4] action_count\n", action_count));
        // State machine pointer ([5-6], 0000 = no SM)
        if self.state_machine.is_some() {
            out.push_str(&format!("    FDB _{}_SM      ; [5-6] state machine ptr\n", name_up));
        } else {
            out.push_str("    FDB 0           ; [5-6] no state machine\n");
        }
        out.push_str("\n");

        // Action table — 6-byte entries: FCB sprite_idx, FCB sprite_type, FCB loop, FCB pad, FDB anim_state_ptr
        out.push_str(&format!("_{}_ENEMY_ACTIONS:\n", name_up));
        for (i, action) in self.actions.iter().enumerate() {
            let ext = Path::new(&action.sprite)
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("");
            let is_vanim = ext == "vanim";

            let sprite_idx: u8 = if !action.sprite.is_empty() {
                let stem = Path::new(&action.sprite)
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .unwrap_or("")
                    .to_string();
                // Select the correct lookup table based on sprite type
                let map = if is_vanim { anim_idx_map } else { vec_idx_map };
                map.get(&stem)
                    .or_else(|| map.get(&stem.to_lowercase()))
                    .copied()
                    .unwrap_or_else(|| {
                        eprintln!(
                            "[WARNING] Enemy '{}' action '{}' sprite '{}' not found in {} index map",
                            name_up, action.name, action.sprite,
                            if is_vanim { "anim" } else { "vector" }
                        );
                        0xFF // $FF = no sprite
                    })
            } else {
                0xFF
            };

            let sprite_type = sprite_type_byte(&action.sprite);
            let loop_val    = if action.loop_anim { 1u8 } else { 0u8 };

            // action_flags byte [3]:
            //   bit 0 = is_shoot
            //   bit 1 = shoot_down (0=side, 1=down)
            //   bit 2 = mirror
            let is_shoot = action.action_type.as_deref() == Some("shoot");
            let shoot_down = action.direction.as_deref() == Some("down");
            let do_mirror  = action.mirror.unwrap_or(false);
            let action_flags: u8 =
                (if is_shoot   { 0x01 } else { 0 }) |
                (if shoot_down { 0x02 } else { 0 }) |
                (if do_mirror  { 0x04 } else { 0 });

            // Vanim actions reference a per-action 2-byte RAM state block
            let anim_state_sym: Option<String> = if is_vanim && !action.sprite.is_empty() {
                let action_up = action.name
                    .to_uppercase()
                    .replace(' ', "_")
                    .replace('-', "_");
                Some(format!("ANIM_ENEMY_{}_{}_STATE", name_up, action_up))
            } else {
                None
            };

            out.push_str(&format!(
                "    FCB ${:02X}   ; action {} ({}) sprite_idx ($FF=none)\n",
                sprite_idx, i, action.name
            ));
            out.push_str(&format!("    FCB {}                   ; sprite_type: 0=vec, 1=vanim\n", sprite_type));
            out.push_str(&format!("    FCB {}                   ; loop={}\n", loop_val, action.loop_anim));
            out.push_str(&format!(
                "    FCB ${:02X}                  ; action_flags (b0=shoot b1=down b2=mirror)\n",
                action_flags
            ));
            if let Some(sym) = &anim_state_sym {
                out.push_str(&format!(
                    "    FDB {}    ; [4-5] anim state RAM ptr (frame_idx, ticks_left)\n",
                    sym
                ));
            } else {
                out.push_str("    FDB 0                    ; [4-5] no anim state (vec action)\n");
            }
        }
        out.push_str("\n");

        // ---- state machine ----
        if let Some(sm) = &self.state_machine {
            out.push_str(&emit_state_machine_asm(&name_up, sm, &self.actions));
        }

        out
    }
}

// ---------------------------------------------------------------------------
// State Machine ASM emitter
// ---------------------------------------------------------------------------

/// FNV-1a 8-bit hash — used to encode event names as a single byte for
/// fast runtime dispatch.  Collisions are harmless in practice (extremely
/// unlikely for the small event vocabularies used in .venemy files).
fn fnv1a_u8(s: &str) -> u8 {
    let mut h: u32 = 2166136261;
    for b in s.bytes() {
        h ^= b as u32;
        h = h.wrapping_mul(16777619);
    }
    (h & 0xFF) as u8
}

/// Emit the state machine ROM table for a single enemy type.
///
/// Layout:
/// ```text
/// _NAME_SM:
///     FCB state_count        ; number of states
///     FCB initial_state_idx  ; index of the initial state
/// _NAME_SM_STATES:
///     ; For each state (FIXED 13-byte record, max 4 events):
///     FCB action_idx         ; [0] index into _NAME_ENEMY_ACTIONS ($FF = keep current)
///     FDB decay_frames       ; [1-2] 0 = no automatic decay
///     FCB decay_to_idx       ; [3] target state for decay ($FF = none)
///     FCB on_event_count     ; [4] number of event transitions (capped at 4)
///     FCB event0_hash        ; [5] FNV-1a u8 of event name ($FF if unused)
///     FCB event0_to          ; [6] target state index ($FF if unused)
///     FCB event1_hash        ; [7]
///     FCB event1_to          ; [8]
///     FCB event2_hash        ; [9]
///     FCB event2_to          ; [10]
///     FCB event3_hash        ; [11]
///     FCB event3_to          ; [12]
/// ```
fn emit_state_machine_asm(
    name_up: &str,
    sm: &EnemyStateMachine,
    actions: &[EnemyAction],
) -> String {
    let mut out = String::new();
    let states = &sm.states;
    let state_count = states.len();

    // Helper: resolve state name → index ($FF if not found)
    let state_idx = |name: &str| -> u8 {
        states
            .iter()
            .position(|s| s.name == name)
            .map(|i| i as u8)
            .unwrap_or_else(|| {
                eprintln!("[WARNING] State machine '{}': unknown state '{}'", name_up, name);
                0xFF
            })
    };

    // Helper: resolve action name → index ($FF if not found)
    let action_idx_for = |name: &str| -> u8 {
        if name.is_empty() {
            return 0xFF;
        }
        actions
            .iter()
            .position(|a| a.name == name)
            .map(|i| i as u8)
            .unwrap_or_else(|| {
                eprintln!(
                    "[WARNING] State machine '{}': action '{}' not in actions list",
                    name_up, name
                );
                0xFF
            })
    };

    let initial_idx = state_idx(&sm.initial_state);

    out.push_str(&format!("; ---- State machine: {} ----\n", name_up));
    out.push_str(&format!("_{}_SM:\n", name_up));
    out.push_str(&format!("    FCB {}          ; state_count\n", state_count));
    out.push_str(&format!("    FCB {}          ; initial_state_idx\n", initial_idx));
    out.push_str(&format!("_{}_SM_STATES:\n", name_up));

    for (si, state) in states.iter().enumerate() {
        let act_idx      = action_idx_for(&state.action);
        let decay_frames = state.decay_frames;
        let decay_to_idx = if state.decay_to.is_empty() {
            0xFF
        } else {
            state_idx(&state.decay_to)
        };

        // Clamp events to max 4; warn if truncated
        let events = &state.on_event;
        if events.len() > 4 {
            eprintln!(
                "[WARNING] State machine '{}' state '{}': {} events > max 4; truncating",
                name_up, state.name, events.len()
            );
        }
        let event_count = events.len().min(4) as u8;

        out.push_str(&format!(
            "    ; state {} ({}) — fixed 13-byte record\n", si, state.name
        ));
        out.push_str(&format!(
            "    FCB ${:02X}   ; [0] action_idx ($FF=keep)\n", act_idx
        ));
        out.push_str(&format!(
            "    FDB {}       ; [1-2] decay_frames\n", decay_frames
        ));
        out.push_str(&format!(
            "    FCB ${:02X}   ; [3] decay_to ($FF=none)\n", decay_to_idx
        ));
        out.push_str(&format!(
            "    FCB {}       ; [4] on_event_count\n", event_count
        ));

        // Emit up to 4 event pairs (hash + to_idx), padding unused slots with $FF
        for slot in 0..4usize {
            if slot < events.len() {
                let evt    = &events[slot];
                let hash   = fnv1a_u8(&evt.event);
                let to_idx = state_idx(&evt.to);
                out.push_str(&format!(
                    "    FCB ${:02X}   ; [{}] event hash '{}'\n", hash, 5 + slot * 2, evt.event
                ));
                out.push_str(&format!(
                    "    FCB {}       ; [{}] -> state {}\n", to_idx, 6 + slot * 2, evt.to
                ));
            } else {
                out.push_str(&format!(
                    "    FCB $FF   ; [{}] unused event slot hash\n", 5 + slot * 2
                ));
                out.push_str(&format!(
                    "    FCB $FF   ; [{}] unused event slot to\n", 6 + slot * 2
                ));
            }
        }
    }
    out.push_str("\n");
    out
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn make_snowbrother() -> EnemyResource {
        EnemyResource {
            version: "1.0".to_string(),
            name: "snowbrother".to_string(),
            actions: vec![
                EnemyAction { name: "idle".to_string(), sprite: "/path/to/player_idle.vec".to_string(), loop_anim: true, ..Default::default() },
                EnemyAction { name: "walk".to_string(), sprite: "/path/to/player_walk.vanim".to_string(), loop_anim: true, ..Default::default() },
                EnemyAction { name: "frozen".to_string(), sprite: "/path/to/player_frozen.vec".to_string(), loop_anim: false, ..Default::default() },
            ],
            stats: EnemyStats { hp: 3, speed: 40, action_duration: 180 },
            behavior: EnemyBehavior {
                behavior_type: "patrol".to_string(),
                patrol: None,
                chase_range: 80,
                respawn: false,
                wave: 0,
            },
            state_machine: None,
        }
    }

    #[test]
    fn test_compile_snowbrother() {
        let enemy = make_snowbrother();
        let asm = enemy.compile_to_asm_with_name(None);

        assert!(asm.contains("_SNOWBROTHER_ENEMY:"));
        assert!(asm.contains("_SNOWBROTHER_ENEMY_ACTIONS:"));
        assert!(asm.contains("_SNOWBROTHER_ACTION_IDLE EQU 0"));
        assert!(asm.contains("_SNOWBROTHER_ACTION_WALK EQU 1"));
        assert!(asm.contains("_SNOWBROTHER_ACTION_FROZEN EQU 2"));
    }

    #[test]
    fn test_sprite_symbol_vec() {
        assert_eq!(
            sprite_to_symbol("/some/path/player_idle.vec"),
            "_PLAYER_IDLE_VECTORS"
        );
    }

    #[test]
    fn test_sprite_symbol_vanim() {
        assert_eq!(
            sprite_to_symbol("/some/path/player_walk.vanim"),
            "_ANIM_PLAYER_WALK"
        );
    }

    #[test]
    fn test_sprite_symbol_empty() {
        assert_eq!(sprite_to_symbol(""), "0");
    }

    #[test]
    fn test_loop_flag_encoding() {
        let enemy = make_snowbrother();
        let asm = enemy.compile_to_asm_with_name(None);
        // idle (loop=true) → FCB 1
        // frozen (loop=false) → FCB 0
        let lines: Vec<&str> = asm.lines().collect();
        let loop_lines: Vec<&&str> = lines.iter()
            .filter(|l| l.contains("loop="))
            .collect();
        assert_eq!(loop_lines.len(), 3);
        assert!(loop_lines[0].contains("FCB 1"));
        assert!(loop_lines[1].contains("FCB 1"));
        assert!(loop_lines[2].contains("FCB 0"));
    }

    #[test]
    fn test_sprite_type_encoding() {
        let enemy = make_snowbrother();
        let asm = enemy.compile_to_asm_with_name(None);
        // idle (.vec) → sprite_type=0, walk (.vanim) → sprite_type=1, frozen (.vec) → sprite_type=0
        let lines: Vec<&str> = asm.lines().collect();
        let type_lines: Vec<&&str> = lines.iter()
            .filter(|l| l.contains("sprite_type:"))
            .collect();
        assert_eq!(type_lines.len(), 3);
        assert!(type_lines[0].contains("FCB 0")); // idle: .vec → 0
        assert!(type_lines[1].contains("FCB 1")); // walk: .vanim → 1
        assert!(type_lines[2].contains("FCB 0")); // frozen: .vec → 0
    }

    #[test]
    fn test_estimate_binary_size() {
        let enemy = make_snowbrother();
        // 5 header + 3 actions * 4 = 17
        assert_eq!(enemy.estimate_binary_size(), 17);
    }

    #[test]
    fn test_override_name() {
        let enemy = make_snowbrother();
        let asm = enemy.compile_to_asm_with_name(Some("goblin"));
        assert!(asm.contains("_GOBLIN_ENEMY:"));
        assert!(asm.contains("_GOBLIN_ACTION_IDLE EQU 0"));
    }

    #[test]
    fn test_null_sprite_emits_zero() {
        let enemy = EnemyResource {
            name: "ghost".to_string(),
            actions: vec![EnemyAction { name: "float".to_string(), sprite: "".to_string(), loop_anim: true, ..Default::default() }],
            stats: EnemyStats { hp: 1, speed: 10, action_duration: 60 },
            ..Default::default()
        };
        let asm = enemy.compile_to_asm_with_name(None);
        assert!(asm.contains("FDB 0    ; action 0 (float) sprite ptr"));
    }

    #[test]
    fn test_json_roundtrip() {
        let original = make_snowbrother();
        let json = serde_json::to_string(&original).unwrap();
        let parsed: EnemyResource = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.name, original.name);
        assert_eq!(parsed.actions.len(), original.actions.len());
        assert_eq!(parsed.stats.hp, original.stats.hp);
    }

    #[test]
    fn test_load_from_disk() {
        // Uses the SnowBros enemy1.venemy that ships with the examples
        let path = std::path::Path::new(
            "/Users/daniel/projects/vectrex-pseudo-python/examples/SnowBros/assets/enemies/enemy1.venemy"
        );
        if !path.exists() { return; } // skip if not present in CI
        let resource = EnemyResource::load(path).expect("load failed");
        assert_eq!(resource.name, "enemy1");
        assert!(!resource.actions.is_empty());
    }

    #[test]
    fn test_state_machine_codegen() {
        let sm = EnemyStateMachine {
            initial_state: "normal".to_string(),
            states: vec![
                EnemyState {
                    name: "normal".to_string(),
                    action: "walk".to_string(),
                    decay_frames: 0,
                    decay_to: String::new(),
                    on_event: vec![EnemyStateTransition {
                        event: "onSnowHit".to_string(),
                        to: "snow1".to_string(),
                    }],
                },
                EnemyState {
                    name: "snow1".to_string(),
                    action: "snow1".to_string(),
                    decay_frames: 120,
                    decay_to: "normal".to_string(),
                    on_event: vec![EnemyStateTransition {
                        event: "onSnowHit".to_string(),
                        to: "ball".to_string(),
                    }],
                },
                EnemyState {
                    name: "ball".to_string(),
                    action: "idle".to_string(),
                    decay_frames: 0,
                    decay_to: String::new(),
                    on_event: vec![EnemyStateTransition {
                        event: "onKick".to_string(),
                        to: "normal".to_string(),
                    }],
                },
            ],
        };
        let mut enemy = make_snowbrother();
        // Add matching actions
        enemy.actions.push(EnemyAction { name: "snow1".to_string(), sprite: "".to_string(), loop_anim: true, ..Default::default() });
        enemy.actions.push(EnemyAction { name: "ball".to_string(), sprite: "".to_string(), loop_anim: false, ..Default::default() });
        enemy.state_machine = Some(sm);

        let asm = enemy.compile_to_asm_with_name(None);
        assert!(asm.contains("_SNOWBROTHER_SM:"));
        assert!(asm.contains("_SNOWBROTHER_SM_STATES:"));
        // state_count=3, initial=0
        assert!(asm.contains("FCB 3          ; state_count"));
        assert!(asm.contains("FCB 0          ; initial_state_idx"));
        // decay of snow1 = 120 frames → decay_to = state 0 (normal)
        assert!(asm.contains("FDB 120       ; [1-2] decay_frames"));
        // event hash for onSnowHit (first event in state, slot 0 → offset [5])
        let hash = fnv1a_u8("onSnowHit");
        assert!(asm.contains(&format!("FCB ${:02X}   ; [5] event hash 'onSnowHit'", hash)));
        // Header contains SM pointer
        assert!(asm.contains("FDB _SNOWBROTHER_SM      ; [5-6] state machine ptr"));
    }
}
