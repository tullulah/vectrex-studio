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

        out
    }

    /// Compile to M6809 assembly for **multibank** mode.
    ///
    /// The action table uses `FCB sprite_idx` (a 0-based index into
    /// `VECTOR_ADDR_TABLE`) instead of `FDB sprite_ptr`.  This allows
    /// `DRAW_ENEMIES_RUNTIME` to call `DRAW_VECTOR_BANKED` directly, avoiding
    /// the need to switch to the vector's switchable bank from helpers code.
    ///
    /// Action table entry format (4 bytes, same total size as the FDB version):
    ///   FCB sprite_idx  ; 0-based index into VECTOR_ADDR_TABLE ($FF = none)
    ///   FCB sprite_type ; 0=vec, 1=vanim
    ///   FCB loop        ; 0=no loop, 1=loop
    ///   FCB 0           ; pad
    pub fn compile_to_asm_indexed(
        &self,
        override_name: Option<&str>,
        vec_idx_map: &HashMap<String, u8>,
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
        out.push_str("\n");

        // Action table — FCB sprite_idx instead of FDB sprite_ptr
        out.push_str(&format!("_{}_ENEMY_ACTIONS:\n", name_up));
        for (i, action) in self.actions.iter().enumerate() {
            let sprite_idx: u8 = if !action.sprite.is_empty() {
                let stem = Path::new(&action.sprite)
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .unwrap_or("")
                    .to_string();
                // Try exact match, then lowercase
                vec_idx_map
                    .get(&stem)
                    .or_else(|| vec_idx_map.get(&stem.to_lowercase()))
                    .copied()
                    .unwrap_or_else(|| {
                        eprintln!(
                            "[WARNING] Enemy '{}' action '{}' sprite '{}' not found in vector index map",
                            name_up, action.name, action.sprite
                        );
                        0xFF // $FF = no sprite
                    })
            } else {
                0xFF
            };
            let sprite_type = sprite_type_byte(&action.sprite);
            let loop_val    = if action.loop_anim { 1u8 } else { 0u8 };
            out.push_str(&format!(
                "    FCB ${:02X}   ; action {} ({}) sprite_idx ($FF=none)\n",
                sprite_idx, i, action.name
            ));
            out.push_str(&format!("    FCB {}                   ; sprite_type: 0=vec, 1=vanim\n", sprite_type));
            out.push_str(&format!("    FCB {}                   ; loop={}\n", loop_val, action.loop_anim));
            out.push_str("    FCB 0                    ; pad (keeps 4-byte entry stride)\n");
        }
        out.push_str("\n");

        out
    }
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
                EnemyAction {
                    name: "idle".to_string(),
                    sprite: "/path/to/player_idle.vec".to_string(),
                    loop_anim: true,
                },
                EnemyAction {
                    name: "walk".to_string(),
                    sprite: "/path/to/player_walk.vanim".to_string(),
                    loop_anim: true,
                },
                EnemyAction {
                    name: "frozen".to_string(),
                    sprite: "/path/to/player_frozen.vec".to_string(),
                    loop_anim: false,
                },
            ],
            stats: EnemyStats { hp: 3, speed: 40, action_duration: 180 },
            behavior: EnemyBehavior {
                behavior_type: "patrol".to_string(),
                patrol: None,
                chase_range: 80,
                respawn: false,
                wave: 0,
            },
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
            actions: vec![EnemyAction {
                name: "float".to_string(),
                sprite: "".to_string(),
                loop_anim: true,
            }],
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
}
