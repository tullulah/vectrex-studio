//! VPy Level Resource format (.vplay)
//!
//! Level data resources stored as JSON that can be compiled
//! into efficient ASM/binary data for Vectrex.

use std::collections::HashMap;
use std::path::Path;
use serde::{Deserialize, Serialize};
use anyhow::Result;

/// Level resource file extension
pub const VPLAY_EXTENSION: &str = "vplay";

/// Root structure of a .vplay file (v2.0)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayLevel {
    /// File format version ("2.0")
    pub version: String,
    /// Level type identifier
    #[serde(rename = "type")]
    pub level_type: String,
    /// Level metadata
    pub metadata: VPlayMetadata,
    /// World bounds
    #[serde(rename = "worldBounds")]
    pub world_bounds: VPlayWorldBounds,
    /// Objects organized by layers
    pub layers: VPlayLayers,
    /// Scroll limits (optional; defaults to worldBounds when absent)
    #[serde(default, rename = "scrollLimits")]
    pub scroll_limits: VPlayScrollLimits,
    /// Editor metadata (groundBottomOffset, screen backgrounds, etc.)
    #[serde(default, rename = "_editorMeta")]
    pub editor_meta: VPlayEditorMeta,
    /// Level-wide walkable areas. Enemies whose own `walkable_areas`
    /// is None inherit this list at codegen time.
    #[serde(default)]
    pub walkable_areas: Option<Vec<WalkableArea>>,
    /// Level-wide transitions between walkable areas. Same inheritance
    /// semantics as `walkable_areas`.
    #[serde(default)]
    pub transitions: Option<Vec<AreaTransition>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct VPlayEditorMeta {
    /// Units from the bottom of each screen to the floor ground line.
    /// floor_surface_world_y = camera_y - 128 + ground_bottom_offset
    #[serde(default, rename = "groundBottomOffset")]
    pub ground_bottom_offset: i16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayMetadata {
    pub name: String,
    #[serde(default)]
    pub author: String,
    #[serde(default)]
    pub difficulty: String,
    #[serde(default, rename = "timeLimit")]
    pub time_limit: u32,
    #[serde(default, rename = "targetScore")]
    pub target_score: u32,
    #[serde(default)]
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayWorldBounds {
    #[serde(rename = "xMin")]
    pub x_min: i16,
    #[serde(rename = "xMax")]
    pub x_max: i16,
    #[serde(rename = "yMin")]
    pub y_min: i16,
    #[serde(rename = "yMax")]
    pub y_max: i16,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct VPlayScrollLimits {
    pub left: Option<i16>,
    pub right: Option<i16>,
    pub top: Option<i16>,
    pub bottom: Option<i16>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayLayers {
    #[serde(default)]
    pub background: Vec<VPlayObject>,
    #[serde(default)]
    pub gameplay: Vec<VPlayObject>,
    #[serde(default)]
    pub foreground: Vec<VPlayObject>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayObject {
    pub id: String,
    #[serde(rename = "type")]
    pub obj_type: String,
    #[serde(default, rename = "vectorName")]
    pub vector_name: String,
    pub x: i16,
    pub y: i16,
    pub scale: f32,
    pub rotation: i16,
    #[serde(default)]
    pub intensity: Option<u8>,
    #[serde(default)]
    pub layer: String,
    #[serde(default)]
    pub visible: bool,
    #[serde(default)]
    pub velocity: Vec2,
    #[serde(default)]
    pub physics: Option<VPlayPhysics>,
    #[serde(default)]
    pub collision: Option<VPlayCollision>,
    #[serde(default)]
    pub properties: Option<serde_json::Value>,
    #[serde(default, rename = "spawnDelay")]
    pub spawn_delay: u16,
    #[serde(default, rename = "destroyOffscreen")]
    pub destroy_offscreen: bool,
    
    // Playground format compatibility (flat structure)
    #[serde(default, rename = "physicsEnabled")]
    pub physics_enabled: bool,
    #[serde(default, rename = "physicsType")]
    pub physics_type: Option<String>,
    #[serde(default)]
    pub collidable: bool,
    #[serde(default)]
    pub gravity: f32,
    #[serde(default, rename = "bounceDamping")]
    pub bounce_damping: f32,

    // Enemy instance fields (from playground enemy tool)
    #[serde(default, rename = "enemyType")]
    pub enemy_type: Option<String>,
    #[serde(default, rename = "aiType")]
    pub ai_type: Option<String>,
    #[serde(default, rename = "patrolWaypoints")]
    pub patrol_waypoints: Option<Vec<EnemyWaypoint>>,
    #[serde(default)]
    pub wave: u8,
    #[serde(default)]
    pub respawn: bool,
    /// Mirror sprite horizontally when moving against defaultFacing direction.
    #[serde(default, rename = "mirrorOnPatrol")]
    pub mirror_on_patrol: bool,
    /// Which direction the sprite art faces by default: "right" (default) or "left".
    #[serde(default, rename = "defaultFacing")]
    pub default_facing: String,
    /// Optional explicit walkable areas (Phase 2 wander AI). If absent and the
    /// enemy has waypoints, a single area is derived from the waypoint X-range
    /// at the spawn Y. If both present, walkable_areas wins.
    #[serde(default)]
    pub walkable_areas: Option<Vec<WalkableArea>>,
    /// Optional transitions between walkable areas (Phase 2).
    #[serde(default)]
    pub transitions: Option<Vec<AreaTransition>>,
}

/// A horizontal walkable area for wander enemies.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WalkableArea {
    pub y: i16,
    pub x_min: i16,
    pub x_max: i16,
}

/// A transition between two walkable areas (by index in `walkable_areas`).
/// Optional from_x / to_x pin the takeoff and landing X within the source
/// and target areas; defaults are area centers.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AreaTransition {
    pub from: u8,
    pub to: u8,
    #[serde(rename = "type")]
    pub ttype: String,  // "jump_up" or "drop"
    #[serde(default)]
    pub from_x: Option<i16>,
    #[serde(default)]
    pub to_x: Option<i16>,
}

/// A single waypoint for an enemy patrol route (local level coordinates)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnemyWaypoint {
    pub x: i16,
    pub y: i16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Vec2 {
    pub x: f32,
    pub y: f32,
}

impl Default for Vec2 {
    fn default() -> Self {
        Self { x: 0.0, y: 0.0 }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayPhysics {
    #[serde(rename = "type")]
    pub physics_type: String,
    #[serde(default)]
    pub gravity: f32,
    #[serde(default)]
    pub friction: f32,
    #[serde(default, rename = "bounceDamping")]
    pub bounce_damping: f32,
    #[serde(default, rename = "maxSpeed")]
    pub max_speed: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayCollision {
    pub enabled: bool,
    #[serde(default)]
    pub layer: Option<String>,
    #[serde(default)]
    pub radius: Option<u16>,
    #[serde(default)]
    pub width: Option<u16>,
    #[serde(default)]
    pub height: Option<u16>,
    #[serde(default)]
    pub shape: Option<String>,
    #[serde(default, rename = "bounceWalls")]
    pub bounce_walls: bool,
    #[serde(default, rename = "destroyOnCollision")]
    pub destroy_on_collision: bool,
    /// Explicit collision segments in local (.vec) coordinates.
    /// When present, replaces AABB half_h for Y-collision (mesh ray-cast).
    #[serde(default)]
    pub segments: Option<Vec<CollisionSegment>>,
}

/// A single collidable line segment in local (.vec) coordinate space.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CollisionSegment {
    pub x1: i16,
    pub y1: i16,
    pub x2: i16,
    pub y2: i16,
}

/// Map an optional AI-type string to the byte encoding used in the ROM.
///
/// Encoding:
///   0 = static
///   1 = patrol   (X+Y movement toward each waypoint in sequence, default)
///   2 = chase
///   3 = flee
///   4 = wander   (X-only patrol + idle pause between waypoint legs)
fn ai_type_byte(ai: &Option<String>) -> u8 {
    match ai.as_deref() {
        Some("static") => 0,
        Some("patrol") => 1,
        Some("chase")  => 2,
        Some("flee")   => 3,
        Some("wander") => 4,
        _              => 1, // patrol is the sensible default
    }
}

impl VPlayLevel {
    /// Load a .vplay file from disk
    pub fn load(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let level: VPlayLevel = serde_json::from_str(&content)?;
        
        // Validate version
        if level.version != "2.0" {
            anyhow::bail!("Unsupported .vplay version: {}. Expected 2.0", level.version);
        }
        
        Ok(level)
    }

    /// Compile level data to M6809 assembly
    pub fn compile_to_asm(&self) -> String {
        self.compile_to_asm_with_vec_dims(&HashMap::new())
    }

    /// Compile level to M6809 ASM, using pre-computed vec dimensions to emit literal
    /// byte values for half_width/half_height instead of cross-bank symbol references.
    /// `dims` maps lowercase vec asset name → (half_width, half_height).
    pub fn compile_to_asm_with_vec_dims(&self, dims: &HashMap<String, (u32, u32)>) -> String {
        let mut out = String::new();

        // Compute enemy objects BEFORE emitting the level header so we can embed the count/ptr
        let all_objects: Vec<&VPlayObject> = self.layers.background.iter()
            .chain(self.layers.gameplay.iter())
            .chain(self.layers.foreground.iter())
            .collect();
        let enemy_objects: Vec<&VPlayObject> = all_objects.iter()
            .filter(|o| o.enemy_type.as_ref().map_or(false, |t| !t.is_empty()))
            .copied()
            .collect();

        let name = self.metadata.name.to_uppercase().replace('-', "_").replace(' ', "_");

        out.push_str(&format!("; ==== Level: {} ====\n", name));
        out.push_str(&format!("; Author: {}\n", self.metadata.author));
        out.push_str(&format!("; Difficulty: {}\n", self.metadata.difficulty));
        out.push_str("\n");

        // Level header
        out.push_str(&format!("_{}_LEVEL:\n", name));
        out.push_str(&format!("    FDB {}  ; World bounds: xMin (16-bit signed)\n", self.world_bounds.x_min));
        out.push_str(&format!("    FDB {}  ; xMax (16-bit signed)\n", self.world_bounds.x_max));
        out.push_str(&format!("    FDB {}  ; yMin (16-bit signed)\n", self.world_bounds.y_min));
        out.push_str(&format!("    FDB {}  ; yMax (16-bit signed)\n", self.world_bounds.y_max));
        out.push_str(&format!("    FDB {}  ; Time limit (seconds)\n", self.metadata.time_limit));
        out.push_str(&format!("    FDB {}  ; Target score\n", self.metadata.target_score));

        // Count objects in each layer
        let bg_count = self.layers.background.len();
        let gameplay_count = self.layers.gameplay.len();
        let fg_count = self.layers.foreground.len();

        out.push_str(&format!("    FCB {}  ; Background object count\n", bg_count));
        out.push_str(&format!("    FCB {}  ; Gameplay object count\n", gameplay_count));
        out.push_str(&format!("    FCB {}  ; Foreground object count\n", fg_count));

        // Pointers to layer data
        out.push_str(&format!("    FDB _{}_BG_OBJECTS\n", name));
        out.push_str(&format!("    FDB _{}_GAMEPLAY_OBJECTS\n", name));
        out.push_str(&format!("    FDB _{}_FG_OBJECTS\n", name));

        // Scroll limits (+21..+28): default to worldBounds when not set
        let sl_left   = self.scroll_limits.left.unwrap_or(self.world_bounds.x_min);
        let sl_right  = self.scroll_limits.right.unwrap_or(self.world_bounds.x_max);
        let sl_top    = self.scroll_limits.top.unwrap_or(self.world_bounds.y_max);
        let sl_bottom = self.scroll_limits.bottom.unwrap_or(self.world_bounds.y_min);
        out.push_str(&format!("    FDB {}  ; scrollLimit left (camera left cannot go below this)\n", sl_left));
        out.push_str(&format!("    FDB {}  ; scrollLimit right (camera right cannot exceed this)\n", sl_right));
        out.push_str(&format!("    FDB {}  ; scrollLimit top\n", sl_top));
        out.push_str(&format!("    FDB {}  ; scrollLimit bottom\n", sl_bottom));

        // Enemy data in header (+29 = enemy_count, +30..+31 = instances_ptr)
        let enemy_header_count = enemy_objects.len();
        let instances_header_label = if enemy_header_count > 0 {
            format!("_{}_ENEMY_INSTANCES", name)
        } else {
            "0".to_string()
        };
        out.push_str(&format!("    FCB {}  ; enemy_count\n", enemy_header_count));
        out.push_str(&format!("    FDB {}  ; enemy_instances_ptr (0 if none)\n", instances_header_label));
        out.push_str("\n");

        // Emit background objects
        out.push_str(&format!("_{}_BG_OBJECTS:\n", name));
        for obj in &self.layers.background {
            out.push_str(&self.compile_object_with_dims(obj, dims));
        }
        out.push_str("\n");

        // Emit gameplay objects
        out.push_str(&format!("_{}_GAMEPLAY_OBJECTS:\n", name));
        for obj in &self.layers.gameplay {
            out.push_str(&self.compile_object_with_dims(obj, dims));
        }
        out.push_str("\n");

        // Emit foreground objects
        out.push_str(&format!("_{}_FG_OBJECTS:\n", name));
        for obj in &self.layers.foreground {
            out.push_str(&self.compile_object_with_dims(obj, dims));
        }
        out.push_str("\n");

        // Emit enemy instances (separate section — enemy_objects computed at top of fn)

        if enemy_objects.is_empty() {
            out.push_str(&format!("_{}_ENEMY_COUNT EQU 0\n\n", name));
        } else {
            out.push_str(&format!("_{}_ENEMY_COUNT EQU {}\n\n", name, enemy_objects.len()));
            out.push_str(&format!("; ---- Enemy instances for level {} ----\n", name));
            out.push_str(&format!("_{}_ENEMY_INSTANCES:\n", name));

            for (i, obj) in enemy_objects.iter().enumerate() {
                let et = obj.enemy_type.as_deref().unwrap_or("");
                let et_up = et.to_uppercase().replace(' ', "_").replace('-', "_");
                let ai_byte = ai_type_byte(&obj.ai_type);
                let wave = obj.wave;
                let respawn_byte = if obj.respawn { 1u8 } else { 0u8 };

                let wps = obj.patrol_waypoints.as_deref().unwrap_or(&[]);
                let wp_count = wps.len();
                let wp_label = if wp_count > 0 {
                    format!("_{}_ENEMY{}_WPS", name, i)
                } else {
                    "0".to_string()
                };

                out.push_str(&format!("    ; instance {}\n", i));
                out.push_str(&format!("    FDB _{}_ENEMY   ; enemy type ptr\n", et_up));
                out.push_str(&format!("    FDB {}                   ; spawn x\n", obj.x));
                out.push_str(&format!("    FDB {}                   ; spawn y\n", obj.y));
                out.push_str(&format!("    FCB {}                    ; ai_type: 0=static,1=patrol,2=chase,3=flee\n", ai_byte));
                out.push_str(&format!("    FCB {}                    ; wave (0=always present)\n", wave));
                out.push_str(&format!("    FCB {}                    ; respawn: 0=no, 1=yes\n", respawn_byte));
                out.push_str(&format!("    FCB {}                    ; waypoint_count\n", wp_count));
                out.push_str(&format!("    FDB {}   ; ptr to waypoints (0 if none)\n", wp_label));
                out.push_str("\n");
            }

            // Emit waypoint tables
            for (i, obj) in enemy_objects.iter().enumerate() {
                let wps = obj.patrol_waypoints.as_deref().unwrap_or(&[]);
                if !wps.is_empty() {
                    out.push_str(&format!("_{}_ENEMY{}_WPS:\n", name, i));
                    for wp in wps {
                        out.push_str(&format!("    FDB {}  ; wp x\n", wp.x));
                        out.push_str(&format!("    FDB {}  ; wp y\n", wp.y));
                    }
                    out.push_str("\n");
                }
            }
        }

        out
    }

    /// Compile level data to ARM Thumb2 assembly.
    ///
    /// ARM object layout (20 bytes, little-endian):
    ///   +0  x (i16 LE)
    ///   +2  y (i16 LE)
    ///   +4  scale (u8, scale*8; 8=1:1)
    ///   +5  intensity (u8)
    ///   +6  flags (u8): bit0=physics, bit1=gravity, bit4=collidable, bit5=bounce
    ///   +7  type (u8)
    ///   +8  vector_ptr (u32 LE absolute address)
    ///   +12 half_w (u8, broadphase x-range)
    ///   +13 half_h (u8, AABB fallback when coll_mesh_ptr==0)
    ///   +14 vel_x_init (i8)
    ///   +15 vel_y_init (i8)
    ///   +16 coll_mesh_ptr (u32, 0 = use AABB fallback)
    ///
    /// Collision mesh format at coll_mesh_ptr:
    ///   .word  floor_count
    ///   .hword x1, y1, x2, y2   @ floor segment 0 (horizontal top-edges, local coords)
    ///   ...                      @ floor segment N-1
    ///   .word  wall_count
    ///   .hword x, y_min, x, y_max  @ wall segment 0 (vertical, local coords)
    ///   ...                         @ wall segment M-1
    ///
    /// Header layout (24 bytes):
    ///   +0  xMin (i16)
    ///   +2  xMax (i16)
    ///   +4  yMin (i16)
    ///   +6  yMax (i16)
    ///   +8  bgCount (u8)
    ///   +9  gpCount (u8)
    ///   +10 fgCount (u8)
    ///   +11 pad (u8)
    ///   +12 bgObjectsPtr (u32)
    ///   +16 gpObjectsPtr (u32)
    ///   +20 fgObjectsPtr (u32)
    /// Look up the patrol action's sprite symbol for an enemy type.
    /// Returns `(symbol, is_anim)` e.g. `("_WALK_VECTORS", false)` or `("_ANIM_WALK", true)`.
    /// Falls back to `None` when the file is missing, the field is unset, or the action has no sprite.
    fn lookup_venemy_patrol_sprite(enemy_type: &str, venemy_dir: Option<&Path>) -> Option<(String, bool)> {
        let dir = venemy_dir?;
        let path = dir.join(format!("{}.venemy", enemy_type));
        let text = std::fs::read_to_string(&path).ok()?;
        let val: serde_json::Value = serde_json::from_str(&text).ok()?;

        let patrol_action = val["behavior"]["patrol"]["patrolAction"].as_str().unwrap_or("");
        let actions = val["actions"].as_array()?;
        // If patrolAction is set, use that action; otherwise fall back to "idle", then first action
        let action = if !patrol_action.is_empty() {
            actions.iter().find(|a| a["name"].as_str() == Some(patrol_action))?
        } else {
            actions.iter().find(|a| a["name"].as_str() == Some("idle"))
                .or_else(|| actions.first())?
        };
        let sprite_path = action["sprite"].as_str().unwrap_or("");
        if sprite_path.is_empty() {
            return None;
        }
        let filename = sprite_path.split('/').last().unwrap_or(sprite_path);
        if filename.ends_with(".vanim") {
            let stem = filename.trim_end_matches(".vanim").to_uppercase();
            Some((format!("_ANIM_{}", stem), true))
        } else if filename.ends_with(".vec") {
            let stem = filename.trim_end_matches(".vec").to_uppercase();
            Some((format!("_{}_VECTORS", stem), false))
        } else {
            None
        }
    }

    /// Look up mirror_on_patrol and default_facing for an enemy type.
    /// Searches for `{venemy_dir}/{enemy_type}.venemy`. Returns (mirror, facing_byte).
    fn lookup_venemy_mirror(enemy_type: &str, venemy_dir: Option<&Path>) -> (u8, u8) {
        let Some(dir) = venemy_dir else { return (0, 0); };
        let path = dir.join(format!("{}.venemy", enemy_type));
        let Ok(text) = std::fs::read_to_string(&path) else { return (0, 0); };
        let Ok(val) = serde_json::from_str::<serde_json::Value>(&text) else { return (0, 0); };
        let mirror = val["behavior"]["patrol"]["mirrorOnPatrol"].as_bool().unwrap_or(false);
        let facing = val["behavior"]["patrol"]["defaultFacing"].as_str().unwrap_or("right");
        (if mirror { 1 } else { 0 }, if facing == "left" { 1 } else { 0 })
    }

    pub fn compile_to_arm_asm(&self, dims: &HashMap<String, (i32, i32)>) -> String {
        self.compile_to_arm_asm_with_venemy(dims, None)
    }

    pub fn compile_to_arm_asm_with_venemy(&self, dims: &HashMap<String, (i32, i32)>, venemy_dir: Option<&Path>) -> String {
        self.compile_to_arm_asm_with_venemy_and_meshes(dims, venemy_dir, &HashMap::new())
    }

    pub fn compile_to_arm_asm_with_venemy_and_meshes(
        &self,
        dims: &HashMap<String, (i32, i32)>,
        venemy_dir: Option<&Path>,
        vec_meshes: &HashMap<String, Vec<crate::vecres::VecMeshSegment>>,
    ) -> String {
        let mut out = String::new();
        let name = self.metadata.name.to_uppercase().replace('-', "_").replace(' ', "_");

        out.push_str(&format!("@ ==== ARM Level: {} ====\n", name));
        // Level header is read with `ldr [r4, #16]` (gpObjectsPtr at offset 16) and
        // similar 32-bit loads. ARM requires the base address to be 4-byte aligned;
        // without an explicit balign the symbol can land on an odd address and the
        // loads return shifted bytes, corrupting every pointer in the chain.
        out.push_str("    .balign 4\n");
        out.push_str(&format!(".global _{name}_LEVEL\n_{name}_LEVEL:\n"));
        // World bounds
        out.push_str(&format!("    .hword {}  @ xMin\n", self.world_bounds.x_min));
        out.push_str(&format!("    .hword {}  @ xMax\n", self.world_bounds.x_max));
        out.push_str(&format!("    .hword {}  @ yMin\n", self.world_bounds.y_min));
        out.push_str(&format!("    .hword {}  @ yMax\n", self.world_bounds.y_max));
        out.push_str(&format!("    .byte {}   @ bgCount\n", self.layers.background.len()));
        out.push_str(&format!("    .byte {}   @ gpCount\n", self.layers.gameplay.len()));
        out.push_str(&format!("    .byte {}   @ fgCount\n", self.layers.foreground.len()));
        out.push_str("    .byte 0    @ pad\n");
        out.push_str(&format!("    .word _{name}_BG_OBJECTS\n"));
        out.push_str(&format!("    .word _{name}_GP_OBJECTS\n"));
        out.push_str(&format!("    .word _{name}_FG_OBJECTS\n"));

        // Scroll limits: default to worldBounds when not set
        let sl_left   = self.scroll_limits.left.unwrap_or(self.world_bounds.x_min);
        let sl_right  = self.scroll_limits.right.unwrap_or(self.world_bounds.x_max);
        let sl_top    = self.scroll_limits.top.unwrap_or(self.world_bounds.y_max);
        let sl_bottom = self.scroll_limits.bottom.unwrap_or(self.world_bounds.y_min);
        out.push_str(&format!("    .hword {}  @ scrollLimit left\n", sl_left));
        out.push_str(&format!("    .hword {}  @ scrollLimit right\n", sl_right));
        out.push_str(&format!("    .hword {}  @ scrollLimit top\n", sl_top));
        out.push_str(&format!("    .hword {}  @ scrollLimit bottom\n", sl_bottom));
        // +32: groundBottomOffset — units from bottom of each screen to the floor ground line.
        //   floor_surface_world_y = camera_y - 128 + groundBottomOffset
        out.push_str(&format!("    .hword {}  @ groundBottomOffset\n", self.editor_meta.ground_bottom_offset));
        out.push_str("    .hword 0  @ pad\n");
        out.push_str("\n");

        // Two-pass: first collect all mesh data (so it precedes struct arrays in the binary),
        // then emit contiguous 20-byte struct arrays per layer.
        let mut bg_meshes = String::new(); let mut bg_structs = String::new();
        for obj in &self.layers.background {
            let (m, s) = self.compile_arm_object(obj, dims, &name, vec_meshes);
            bg_meshes.push_str(&m); bg_structs.push_str(&s);
        }
        let mut gp_meshes = String::new(); let mut gp_structs = String::new();
        for obj in &self.layers.gameplay {
            let (m, s) = self.compile_arm_object(obj, dims, &name, vec_meshes);
            gp_meshes.push_str(&m); gp_structs.push_str(&s);
        }
        let mut fg_meshes = String::new(); let mut fg_structs = String::new();
        for obj in &self.layers.foreground {
            let (m, s) = self.compile_arm_object(obj, dims, &name, vec_meshes);
            fg_meshes.push_str(&m); fg_structs.push_str(&s);
        }

        // Emit all collision meshes first
        if !bg_meshes.is_empty() || !gp_meshes.is_empty() || !fg_meshes.is_empty() {
            out.push_str("@ --- Collision meshes ---\n");
            out.push_str(&bg_meshes); out.push_str(&gp_meshes); out.push_str(&fg_meshes);
            out.push_str("\n");
        }

        // Each ROM object is read with .word loads at offsets +8 (vector_ptr) and
        // +16 (coll_mesh_ptr). Object stride is 20 bytes — odd start makes every
        // object misaligned. Force 4-byte alignment before each array.
        out.push_str("    .balign 4\n");
        out.push_str(&format!("_{name}_BG_OBJECTS:\n"));
        out.push_str(&bg_structs);
        out.push_str("\n");

        out.push_str("    .balign 4\n");
        out.push_str(&format!("_{name}_GP_OBJECTS:\n"));
        out.push_str(&gp_structs);
        out.push_str("\n");

        out.push_str("    .balign 4\n");
        out.push_str(&format!("_{name}_FG_OBJECTS:\n"));
        out.push_str(&fg_structs);
        out.push_str("\n");

        // ARM enemy spawn table — collected from all layers (any object with enemyType set)
        // Layout per entry (24 bytes, .align 2):
        //   +0  sprite_ptr (u32) — address of _{ENEMY_TYPE}_VECTORS
        //   +4  spawn_x    (i16)
        //   +6  spawn_y    (i16)
        //   +8  ai_type    (u8)  — 0=static 1=patrol 2=chase
        //   +9  wp_count   (u8)  — number of patrol waypoints (0–2)
        //   +10 pad        (u16)
        //   +12 wp0_x      (i16)
        //   +14 wp0_y      (i16)
        //   +16 wp1_x      (i16)
        //   +18 wp1_y      (i16)
        //   +20 pad        (u32)
        let all_objs: Vec<&VPlayObject> = self.layers.background.iter()
            .chain(self.layers.gameplay.iter())
            .chain(self.layers.foreground.iter())
            .collect();
        let enemy_objs: Vec<&VPlayObject> = all_objs.iter()
            .filter(|o| o.enemy_type.as_ref().map_or(false, |t| !t.is_empty()))
            .copied()
            .collect();
        let ec = enemy_objs.len();
        out.push_str(&format!("@ ARM enemy spawn table for {name}\n"));
        out.push_str(".align 2\n");
        out.push_str(&format!(".global _{name}_PITREX_ENEMY_COUNT\n_{name}_PITREX_ENEMY_COUNT:\n"));
        out.push_str(&format!("    .word {ec}  @ enemy count\n\n"));
        // Always emit the table label so SPAWN_ENEMIES can link even when ec==0.
        out.push_str(&format!(".global _{name}_PITREX_ENEMIES\n_{name}_PITREX_ENEMIES:\n"));
        if ec > 0 {
            // Per-enemy walkable-area tables are appended after the enemies array.
            let mut areas_tables = String::new();

            for (idx, obj) in enemy_objs.iter().enumerate() {
                let et = obj.enemy_type.as_deref().unwrap_or("").to_uppercase();
                let ai = ai_type_byte(&obj.ai_type);
                let wps = obj.patrol_waypoints.as_deref().unwrap_or(&[]);
                let wpc = wps.len() as u8;
                out.push_str(&format!("    @ enemy type={et}, ai={ai}, wp_count={wpc}\n"));
                let (sprite_sym, is_anim_bool) = Self::lookup_venemy_patrol_sprite(&et.to_lowercase(), venemy_dir)
                    .unwrap_or_else(|| (format!("_{et}_VECTORS"), false));
                let is_anim_byte = if is_anim_bool { 1u8 } else { 0u8 };
                out.push_str(&format!("    .word {}  @ sprite_ptr\n", sprite_sym));
                out.push_str(&format!("    .hword {}  @ spawn_x\n", obj.x));
                out.push_str(&format!("    .hword {}  @ spawn_y\n", obj.y));
                // Mirror settings: .venemy type file is authoritative (per-instance fallback)
                let (mirror_byte, facing_byte) = {
                    let (vm, vf) = Self::lookup_venemy_mirror(&et.to_lowercase(), venemy_dir);
                    if vm != 0 || vf != 0 {
                        (vm, vf)
                    } else {
                        let m = if obj.mirror_on_patrol { 1u8 } else { 0u8 };
                        let f = if obj.default_facing == "left" { 1u8 } else { 0u8 };
                        (m, f)
                    }
                };
                out.push_str(&format!("    .byte {}   @ ai_type\n", ai));
                out.push_str(&format!("    .byte {}   @ wp_count\n", wpc));
                out.push_str(&format!("    .byte {}   @ mirror_on_patrol\n", mirror_byte));
                out.push_str(&format!("    .byte {}   @ default_facing (0=right 1=left)\n", facing_byte));
                // Emit all waypoints (variable count — stride = 12 + wp_count*4 + 4)
                for (i, wp) in wps.iter().enumerate() {
                    out.push_str(&format!("    .hword {}  @ wp{}_x\n", wp.x, i));
                    out.push_str(&format!("    .hword {}  @ wp{}_y\n", wp.y, i));
                }
                out.push_str(&format!("    .byte {}   @ is_anim (0=vec 1=vanim)\n", is_anim_byte));
                out.push_str("    .byte 0    @ pad\n");
                out.push_str("    .byte 0    @ pad\n");
                out.push_str("    .byte 0    @ pad\n");
                // type_data_ptr: 4-byte ROM pointer to per-type SM data table
                // (state→sprite_ptr table + state→is_anim flags). Read by spawn
                // into pool+20; used by update/draw_enemies to pick frozen sprite.
                out.push_str(&format!("    .word _{et}_DATA   @ type_data_ptr\n"));

                // areas_ptr (Phase 2): pointer to per-enemy walkable-areas table,
                // or 0 if no areas defined.
                // Inheritance: if the enemy has its own `walkable_areas` field
                // present, use it. Otherwise fall back to the level's. The
                // same applies to `transitions`. Either field being a non-None
                // (even empty) on the enemy is treated as an explicit override.
                let areas = Self::derive_walkable_areas(obj, self.walkable_areas.as_deref());
                let trans: &[AreaTransition] = if let Some(ref t) = obj.transitions {
                    t.as_slice()
                } else {
                    self.transitions.as_deref().unwrap_or(&[])
                };
                if !areas.is_empty() {
                    let alabel = format!("_{name}_ENEMY{idx}_AREAS");
                    out.push_str(&format!("    .word {alabel}   @ areas_ptr\n"));
                    // Build the areas table; appended after this loop.
                    areas_tables.push_str("    .balign 4\n");
                    areas_tables.push_str(&format!("{alabel}:\n"));
                    areas_tables.push_str(&format!("    .word {}  @ area_count\n", areas.len()));
                    areas_tables.push_str(&format!("    .word {}  @ trans_count\n", trans.len()));
                    for (ai_idx, a) in areas.iter().enumerate() {
                        areas_tables.push_str(&format!(
                            "    .hword {}, {}, {}, 0  @ area {}: y, x_min, x_max\n",
                            a.y, a.x_min, a.x_max, ai_idx));
                    }
                    for (ti_idx, t) in trans.iter().enumerate() {
                        let ttype = match t.ttype.as_str() {
                            "jump_up" => 1u8,
                            "drop"    => 2u8,
                            _         => 0u8,
                        };
                        // Compute defaults: if from_x / to_x absent, use the
                        // center of the corresponding area (matches editor's
                        // default rendering).
                        let center_of = |idx: u8| -> i16 {
                            let a = areas.get(idx as usize)
                                .unwrap_or(&WalkableArea { y: 0, x_min: 0, x_max: 0 });
                            ((a.x_min as i32 + a.x_max as i32) / 2) as i16
                        };
                        let fx = t.from_x.unwrap_or_else(|| center_of(t.from));
                        let tx = t.to_x.unwrap_or_else(|| center_of(t.to));
                        areas_tables.push_str(&format!(
                            "    .byte {}, {}, {}, 0  @ trans {}: from, to, type({})\n",
                            t.from, t.to, ttype, ti_idx, t.ttype));
                        areas_tables.push_str(&format!(
                            "    .hword {}, {}        @ from_x, to_x\n", fx, tx));
                    }
                } else {
                    out.push_str("    .word 0          @ areas_ptr (none)\n");
                }
            }
            out.push_str("\n");
            if !areas_tables.is_empty() {
                out.push_str("@ Per-enemy walkable-area tables (Phase 2 wander AI)\n");
                out.push_str(&areas_tables);
                out.push_str("\n");
            }
        }

        out
    }

    /// Compute the walkable areas for an enemy with this precedence:
    ///   1. Enemy's own `walkable_areas` (if present, even if empty list).
    ///   2. Level-wide `walkable_areas` (when the enemy field is None).
    ///   3. Single area derived from the patrol waypoints' X-range at spawn Y.
    fn derive_walkable_areas(
        obj: &VPlayObject,
        level_areas: Option<&[WalkableArea]>,
    ) -> Vec<WalkableArea> {
        if let Some(ref explicit) = obj.walkable_areas {
            // Even an empty list is an explicit override (means "no areas").
            return explicit.clone();
        }
        if let Some(level) = level_areas {
            if !level.is_empty() {
                return level.to_vec();
            }
        }
        let wps = obj.patrol_waypoints.as_deref().unwrap_or(&[]);
        if wps.len() >= 2 {
            let x_min = wps.iter().map(|w| w.x).min().unwrap();
            let x_max = wps.iter().map(|w| w.x).max().unwrap();
            vec![WalkableArea { y: obj.y as i16, x_min, x_max }]
        } else {
            vec![]
        }
    }

    /// Compile a single object for the ARM binary format (20 bytes).
    /// Returns (mesh_data, struct_data). mesh_data contains the _COLMESH_* label + segments
    /// (empty string if no segments defined). struct_data is the 20-byte object struct.
    fn compile_arm_object(&self, obj: &VPlayObject, dims: &HashMap<String, (i32, i32)>, level_name: &str, vec_meshes: &HashMap<String, Vec<crate::vecres::VecMeshSegment>>) -> (String, String) {
        let mut mesh = String::new();
        let mut out = String::new();
        out.push_str(&format!("    @ {} ({})\n", obj.id, obj.obj_type));

        // +0,+2: position
        out.push_str(&format!("    .hword {}  @ x\n", obj.x));
        out.push_str(&format!("    .hword {}  @ y\n", obj.y));

        // +4: scale (scale*8, clamped 1-255; 8=1:1)
        let scale_u8 = (obj.scale * 8.0).round().clamp(1.0, 255.0) as u8;
        out.push_str(&format!("    .byte {}   @ scale (x8)\n", scale_u8));

        // +5: intensity
        let intensity = obj.intensity.unwrap_or(127);
        out.push_str(&format!("    .byte {}   @ intensity\n", intensity));

        // +6: flags
        // Collidable is independent of physics_enabled — static platforms have collidable=true
        // but physicsEnabled=false. Physics motion flags are only set when physicsEnabled=true.
        let mut flags: u8 = 0;
        let collidable = obj.collidable || obj.collision.as_ref().map_or(false, |c| c.enabled);
        if collidable { flags |= 0x10; }
        if obj.physics_enabled {
            let has_physics = obj.physics.as_ref().map_or(true, |p| p.physics_type == "dynamic");
            if has_physics { flags |= 0x01; }
            let has_gravity = obj.gravity != 0.0
                || obj.physics.as_ref().map_or(false, |p| p.gravity != 0.0)
                || obj.physics_type.as_ref().map_or(false, |t| t == "gravity" || t == "projectile");
            if has_gravity { flags |= 0x02; }
            let bounce = obj.bounce_damping != 0.0
                || obj.physics_type.as_ref().map_or(false, |t| t == "bounce" || t == "gravity")
                || obj.collision.as_ref().map_or(false, |c| c.bounce_walls);
            if bounce { flags |= 0x20; }
        }
        out.push_str(&format!("    .byte 0x{:02X}  @ flags\n", flags));

        // +7: type
        let type_byte = match obj.obj_type.as_str() {
            "player_start" => 0u8,
            "enemy"        => 1,
            "obstacle"     => 2,
            "collectible"  => 3,
            "background"   => 4,
            "trigger"      => 5,
            _              => 255,
        };
        out.push_str(&format!("    .byte {}   @ type\n", type_byte));

        // +8: vector_ptr (32-bit absolute address, resolved at link time)
        // Enemy-type objects: visual is managed by the enemy system, not the level renderer.
        let is_enemy_arm = obj.enemy_type.as_ref().map_or(false, |t| !t.is_empty());
        if obj.vector_name.is_empty() || is_enemy_arm {
            out.push_str("    .word 0  @ vector_ptr (none — enemy marker)\n");
        } else {
            let vec_label = format!("_{}_VECTORS", obj.vector_name.to_uppercase().replace('-', "_").replace(' ', "_"));
            out.push_str(&format!("    .word {vec_label}  @ vector_ptr\n"));
        }

        // +12,+13: half_w, half_h
        // NOTE: pitrex_show_level does NOT apply the scale byte when drawing — all objects
        // render at native .vec coordinates. So collision dims must also be unscaled (native).
        // Explicit collision.width/height in .vplay takes priority; falls back to vec bounds.
        let key = obj.vector_name.to_lowercase();
        let (nat_hw, nat_hh) = dims.get(&key).copied().unwrap_or((16, 16));
        let coll_override_w = obj.collision.as_ref().and_then(|c| c.width);
        let coll_override_h = obj.collision.as_ref().and_then(|c| c.height);
        let nat_hw_final = coll_override_w.map(|v| v as i32).unwrap_or(nat_hw);
        let nat_hh_final = coll_override_h.map(|v| v as i32).unwrap_or(nat_hh);
        // No scale applied — renderer draws at native size, so collision must match.
        let half_w = nat_hw_final.clamp(1, 127) as u8;
        let half_h = nat_hh_final.clamp(1, 127) as u8;
        let w_src = if coll_override_w.is_some() { "explicit" } else { "vec" };
        let h_src = if coll_override_h.is_some() { "explicit" } else { "vec" };
        out.push_str(&format!("    .byte {}   @ half_w ({}:{})\n", half_w, w_src, nat_hw_final));
        out.push_str(&format!("    .byte {}   @ half_h ({}:{})\n", half_h, h_src, nat_hh_final));

        // +14,+15: initial velocity (i8)
        let vx = obj.velocity.x.clamp(-128.0, 127.0) as i8;
        let vy = obj.velocity.y.clamp(-128.0, 127.0) as i8;
        out.push_str(&format!("    .byte {}   @ vel_x_init\n", vx as u8));
        out.push_str(&format!("    .byte {}   @ vel_y_init\n", vy as u8));

        // +16..+20: collision mesh pointer
        // Build mesh label from sanitized object ID
        let mesh_label = format!("_COLMESH_{}_{}", level_name, obj.id.replace('-', "_").replace(' ', "_"));
        let segs_opt = obj.collision.as_ref()
            .and_then(|c| c.segments.as_ref())
            .filter(|v| !v.is_empty());

        // Fallback: if no level-side segments, use the .vec file's own collision mesh
        let vec_segs_converted: Vec<CollisionSegment>;
        let segs_opt = if segs_opt.is_some() {
            segs_opt
        } else if let Some(vm) = vec_meshes.get(&obj.vector_name.to_lowercase()) {
            if !vm.is_empty() {
                vec_segs_converted = vm.iter().map(|s| CollisionSegment { x1: s.x1, y1: s.y1, x2: s.x2, y2: s.y2 }).collect();
                Some(&vec_segs_converted)
            } else {
                None
            }
        } else {
            None
        };

        if let Some(segs) = segs_opt {
            // Optimization: only emit "top edge" horizontal segments — those whose
            // X-range has no other horizontal segment with a strictly greater Y above
            // them. The collision runtime only cares about what the player can stand
            // on; interior or bottom edges of the mesh are never relevant for floor
            // detection. Reduces seg_count from ~46 (full mesh) to ~1-3 for typical
            // platforms, dramatically lowering per-frame cycles in vpy_level_collision_y.
            let mut horiz: Vec<(i16, i16, i16)> = Vec::new();
            for seg in segs {
                if seg.y1 == seg.y2 {
                    let xa = seg.x1.min(seg.x2);
                    let xb = seg.x1.max(seg.x2);
                    horiz.push((xa, xb, seg.y1));
                }
            }
            // Keep only top edges: for each segment S, drop it if any other horizontal
            // segment T has T.y > S.y and T's X-range overlaps S's X-range (T sits above S).
            let top_edges: Vec<(i16, i16, i16)> = horiz
                .iter()
                .filter(|&&(xa, xb, y)| {
                    !horiz.iter().any(|&(txa, txb, ty)| {
                        ty > y && txa < xb && txb > xa
                    })
                })
                .cloned()
                .collect();
            let emitted: Vec<(i16, i16, i16)> = if top_edges.is_empty() {
                // Mesh has no horizontal segments at all — keep original for safety
                segs.iter().map(|s| (s.x1.min(s.x2), s.x1.max(s.x2), s.y1)).collect()
            } else {
                top_edges
            };
            // .word requires 4-byte alignment on ARM. Without an explicit balign,
            // the symbol can land on an odd address (e.g. right after a .byte or
            // .hword section), making `ldr r12, [r11], #4` read garbage — the
            // first byte gets combined with adjacent data, producing a "seg_count"
            // in the billions and turning the raycast loop into an infinite spin.
            mesh.push_str("    .balign 4\n");
            mesh.push_str(&format!("{}:  @ {} top-edge collision segments (filtered from {} original)\n",
                mesh_label, emitted.len(), segs.len()));
            mesh.push_str(&format!("    .word {}  @ floor segment count\n", emitted.len()));
            for (xa, xb, y) in &emitted {
                mesh.push_str(&format!("    .hword {}, {}, {}, {}  @ x1={} y1={} x2={} y2={}\n",
                    xa, y, xb, y, xa, y, xb, y));
            }
            // Extract vertical wall segments (x1==x2, y1!=y2) for horizontal collision
            let mut wall_segs: Vec<(i16, i16, i16)> = Vec::new(); // (x, y_min, y_max)
            for seg in segs {
                if seg.x1 == seg.x2 && seg.y1 != seg.y2 {
                    wall_segs.push((seg.x1, seg.y1.min(seg.y2), seg.y1.max(seg.y2)));
                }
            }
            mesh.push_str(&format!("    .word {}  @ wall segment count\n", wall_segs.len()));
            for (x, ya, yb) in &wall_segs {
                mesh.push_str(&format!("    .hword {}, {}, {}, {}  @ x={} ymin={} ymax={}\n", x, ya, x, yb, x, ya, yb));
            }
            out.push_str(&format!("    .word {}  @ coll_mesh_ptr\n\n", mesh_label));
        } else {
            out.push_str("    .word 0  @ coll_mesh_ptr (AABB fallback)\n\n");
        }

        (mesh, out)
    }

    /// Compile a single object to assembly (M6809 format)
    fn compile_object_with_dims(&self, obj: &VPlayObject, dims: &HashMap<String, (u32, u32)>) -> String {
        let mut out = String::new();
        
        out.push_str(&format!("; Object: {} ({})\n", obj.id, obj.obj_type));
        
        // Object type as byte (enum mapping)
        let type_byte = match obj.obj_type.as_str() {
            "player_start" => 0,
            "enemy" => 1,
            "obstacle" => 2,
            "collectible" => 3,
            "background" => 4,
            "trigger" => 5,
            _ => 255, // Unknown
        };
        out.push_str(&format!("    FCB {}  ; type\n", type_byte));
        
        // Position (signed 16-bit)
        out.push_str(&format!("    FDB {}  ; x\n", obj.x));
        out.push_str(&format!("    FDB {}  ; y\n", obj.y));
        
        // Scale stored as direct T1 value in the low byte of FDB (high byte = 0).
        // T1 = scale * M6809_DRAW_SCALE. At runtime, this byte is read and used
        // directly as VIA T1 latch without any multiplication.
        // MUST match DRAW_SCALE default in functions.rs ($7F=127).
        // scale=1.0 → 127 ($7F), scale=0.5 → 64 ($40), scale=2.0 → 254 ($FE).
        // $7F is full BIOS scale — hardware-calibrated reference.
        const M6809_DRAW_SCALE: f32 = 127.0;
        let scale_t1 = (obj.scale * M6809_DRAW_SCALE).round().clamp(1.0, 255.0) as u8;
        out.push_str(&format!("    FDB {}  ; scale (T1 direct; {:.2}x)\n", scale_t1, obj.scale));
        
        // Rotation (degrees as signed byte)
        out.push_str(&format!("    FCB {}  ; rotation\n", (obj.rotation % 360) as u8));
        
        // Intensity (0 = use vector's intensity, >0 = override)
        let intensity_value = obj.intensity.unwrap_or(0);
        out.push_str(&format!("    FCB {}  ; intensity (0=use vec, >0=override)\n", intensity_value));
        
        // Velocity (convert f32 to signed 8-bit)
        let vel_x = obj.velocity.x.clamp(-127.0, 127.0) as i8;
        let vel_y = obj.velocity.y.clamp(-127.0, 127.0) as i8;
        out.push_str(&format!("    FCB {}  ; velocity_x\n", vel_x as u8));
        out.push_str(&format!("    FCB {}  ; velocity_y\n", vel_y as u8));
        
        // Physics flags byte
        let mut physics_flags = 0u8;
        
        // Check nested physics structure first, then flat Playground format
        if let Some(ref physics) = obj.physics {
            if physics.physics_type == "dynamic" {
                physics_flags |= 0x01; // Bit 0: dynamic physics enabled
            }
            if physics.gravity != 0.0 {
                physics_flags |= 0x02; // Bit 1: gravity enabled
            }
        }
        
        // CRITICAL: Check flat Playground format ALWAYS (even if nested physics exists)
        // This allows collision field to coexist with physicsEnabled/physicsType
        if obj.physics_enabled {
            // Playground flat format
            if let Some(ref physics_type) = obj.physics_type {
                // All physicsType options enable physics (bit 0)
                physics_flags |= 0x01; // Bit 0: physics enabled
                
                // Check if gravity is enabled via physicsType or gravity field
                if physics_type == "gravity" || physics_type == "projectile" || obj.gravity != 0.0 {
                    physics_flags |= 0x02; // Bit 1: gravity enabled
                }
            }
        }
        out.push_str(&format!("    FCB {}  ; physics_flags\n", physics_flags));
        
        // Collision flags byte
        let mut collision_flags = 0u8;
        
        // Check nested collision structure first
        if let Some(ref collision) = obj.collision {
            if collision.enabled {
                collision_flags |= 0x01; // Bit 0: collision enabled
            }
            if collision.bounce_walls {
                collision_flags |= 0x02; // Bit 1: bounce on Y walls (top/bottom)
            }
            if let Some(ref shape) = collision.shape {
                if shape == "circle" {
                    collision_flags |= 0x04; // Bit 2: circle shape (0=rect)
                }
            }
        }
        
        // CRITICAL: Also check flat Playground format (can coexist with nested collision)
        // NOTE: collidable=true applies even when physics_enabled=false (static collision walls/platforms)
        if obj.collidable {
            collision_flags |= 0x01; // Bit 0: collision enabled
        }
        if obj.physics_enabled {
            // Check physicsType for bounce behavior
            if let Some(ref physics_type) = obj.physics_type {
                if physics_type == "bounce" || physics_type == "gravity" || physics_type == "projectile" {
                    collision_flags |= 0x02; // Bit 1: bounce on Y walls (top/bottom)
                }
            }
        }
        out.push_str(&format!("    FCB {}  ; collision_flags\n", collision_flags));
        
        // Collision radius/size (use radius for circle, width for rect)
        let collision_size = if let Some(ref collision) = obj.collision {
            collision.radius.unwrap_or(collision.width.unwrap_or(10))
        } else {
            10
        };
        out.push_str(&format!("    FCB {}  ; collision_size\n", collision_size));
        
        // Spawn delay (16-bit)
        out.push_str(&format!("    FDB {}  ; spawn_delay\n", obj.spawn_delay));
        
        // Pointer to vector data (will be resolved by linker)
        // Enemy-type objects: visual is managed by the enemy system, not the level renderer.
        // Use null vector_ptr (level renderer checks CMPU #0 and skips drawing if null).
        let is_enemy_obj = obj.enemy_type.as_ref().map_or(false, |t| !t.is_empty());
        if obj.vector_name.is_empty() || is_enemy_obj {
            out.push_str("    FDB 0  ; vector_ptr (no visual for this object)\n");
            out.push_str("    FCB 8  ; half_width (default, ROM+18)\n");
            out.push_str("    FCB 8  ; half_height (default, ROM+19)\n");
        } else {
            let vector_label = format!("_{}_VECTORS", obj.vector_name.to_uppercase());
            out.push_str(&format!("    FDB {}  ; vector_ptr\n", vector_label));

            // Bytes +18-19: half_width (cull margin) + half_height (collision AABB)
            // When copied to RAM via LDD ,X++; STD ,U++:
            //   RAM+13 = half_width (A), RAM+14 = half_height (B)
            // Explicit collision.width/height in .vplay takes priority over vec bounding box.
            let coll_override_w_m6809 = obj.collision.as_ref().and_then(|c| c.width);
            let coll_override_h_m6809 = obj.collision.as_ref().and_then(|c| c.height);
            let vec_key = obj.vector_name.to_lowercase();

            // half_width — always emit a literal (avoids cross-bank EQU references and vanim gaps)
            // Priority: explicit override → dims map → dims map of first frame (vanim) → default 8
            let frame1_key = format!("{}1", vec_key);
            if let Some(nat_w) = coll_override_w_m6809 {
                let hw = ((nat_w as f32 * obj.scale).round() as u32).clamp(1, 127);
                out.push_str(&format!("    FCB {}  ; half_width (explicit override, ROM+18)\n", hw));
            } else if let Some(&(hw, _)) = dims.get(&vec_key).or_else(|| dims.get(&frame1_key)) {
                let scaled = ((hw as f32 * obj.scale).round() as u32).clamp(1, 127);
                out.push_str(&format!("    FCB {}  ; half_width ({:.2}x, ROM+18)\n", scaled, obj.scale));
            } else {
                out.push_str("    FCB 8  ; half_width (default, ROM+18)\n");
            }

            // half_height — always emit a literal (avoids cross-bank EQU references and vanim gaps)
            if let Some(nat_h) = coll_override_h_m6809 {
                let hh = ((nat_h as f32 * obj.scale).round() as u32).clamp(1, 127);
                out.push_str(&format!("    FCB {}  ; half_height (explicit override, ROM+19)\n", hh));
            } else if let Some(&(_, hh)) = dims.get(&vec_key).or_else(|| dims.get(&frame1_key)) {
                let scaled = ((hh as f32 * obj.scale).round() as u32).clamp(1, 127);
                out.push_str(&format!("    FCB {}  ; half_height ({:.2}x, ROM+19)\n", scaled, obj.scale));
            } else {
                out.push_str("    FCB 8  ; half_height (default, ROM+19)\n");
            }
        }
        
        out.push_str("\n");
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_load_vplay() {
        // This test would need an actual .vplay file
        // For now, just test struct creation
        let level = VPlayLevel {
            version: "2.0".to_string(),
            level_type: "level".to_string(),
            metadata: VPlayMetadata {
                name: "test_level".to_string(),
                author: "Test Author".to_string(),
                difficulty: "medium".to_string(),
                time_limit: 120,
                target_score: 1000,
                description: "Test description".to_string(),
            },
            world_bounds: VPlayWorldBounds {
                x_min: -96,
                x_max: 95,
                y_min: -128,
                y_max: 127,
            },
            layers: VPlayLayers {
                background: vec![],
                gameplay: vec![],
                foreground: vec![],
            },
            scroll_limits: VPlayScrollLimits::default(),
            editor_meta: VPlayEditorMeta::default(),
        };

        assert_eq!(level.version, "2.0");
        assert_eq!(level.metadata.name, "test_level");
    }

    #[test]
    fn test_compile_empty_level() {
        let level = VPlayLevel {
            version: "2.0".to_string(),
            level_type: "level".to_string(),
            metadata: VPlayMetadata {
                name: "empty".to_string(),
                author: "".to_string(),
                difficulty: "easy".to_string(),
                time_limit: 0,
                target_score: 0,
                description: "".to_string(),
            },
            world_bounds: VPlayWorldBounds {
                x_min: -96,
                x_max: 95,
                y_min: -128,
                y_max: 127,
            },
            layers: VPlayLayers {
                background: vec![],
                gameplay: vec![],
                foreground: vec![],
            },
            scroll_limits: VPlayScrollLimits::default(),
            editor_meta: VPlayEditorMeta::default(),
        };

        let asm = level.compile_to_asm();
        assert!(asm.contains("_EMPTY_LEVEL:"));
        assert!(asm.contains("; Background object count"));
    }
}
