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
    /// When true, auto-derived transitions never cross a screen boundary
    /// (256-unit Y band aligned to worldBounds.yMax). For per-screen games
    /// like SnowBros where each "floor" is its own level — enemies should
    /// not auto-jump between floors.
    #[serde(default, rename = "isolateScreens")]
    pub isolate_screens: bool,
    /// Auto-transition tuning. None = use built-in defaults (4 / 8 / 60).
    ///   transitionMinXOverlap: smallest X overlap (units) for a jump_up /
    ///       drop pair between vertically adjacent areas.
    ///   transitionLateralY:    maximum |dy| (units) to treat two areas as
    ///       "same row" for jump_across.
    ///   transitionLateralGap:  maximum horizontal gap (units) between two
    ///       same-row areas for a jump_across to be emitted.
    #[serde(default, rename = "transitionMinXOverlap")]
    pub transition_min_x_overlap: Option<i16>,
    #[serde(default, rename = "transitionLateralY")]
    pub transition_lateral_y: Option<i16>,
    #[serde(default, rename = "transitionLateralGap")]
    pub transition_lateral_gap: Option<i16>,
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

/// A walkable area for wander enemies. `y` is the surface height at `x_min`;
/// `y2` is the height at `x_max`. When `y2` is absent (or equal to `y`) the area
/// is FLAT (the historical behaviour). When they differ the surface is a SLOPE,
/// and the runtime interpolates the enemy's Y from its X across [x_min, x_max].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WalkableArea {
    pub y: i16,
    pub x_min: i16,
    pub x_max: i16,
    /// Surface height at x_max. Absent = flat (y2 == y). See `y_at_max`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub y2: Option<i16>,
}

impl WalkableArea {
    /// Surface height at x_max (defaults to `y` → flat).
    pub fn y_at_max(&self) -> i16 { self.y2.unwrap_or(self.y) }
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
        self.compile_m6809_inner(dims, &HashMap::new(), &HashMap::new(), &HashMap::new())
    }

    /// Compile level to M6809 ASM with both vector dims and bank assignment map.
    /// Used in multibank second-pass compilation after bank distribution is known.
    /// `vec_bank_map` maps lowercase vec asset name → bank number.
    /// `vec_meshes` maps lowercase vec name → its collision segments (for the
    /// LEVEL_COLLISION_Y mesh ray-cast; empty map → AABB fallback for all objects).
    pub fn compile_to_asm_with_bank_map(
        &self,
        dims: &HashMap<String, (u32, u32)>,
        vec_bank_map: &HashMap<String, u8>,
        vec_meshes: &HashMap<String, Vec<crate::vecres::VecMeshSegment>>,
    ) -> String {
        self.compile_m6809_inner(dims, vec_bank_map, vec_meshes, &HashMap::new())
    }

    pub fn compile_to_asm_with_bank_map_and_walk(
        &self,
        dims: &HashMap<String, (u32, u32)>,
        vec_bank_map: &HashMap<String, u8>,
        vec_meshes: &HashMap<String, Vec<crate::vecres::VecMeshSegment>>,
        vec_walk_areas: &HashMap<String, Vec<crate::vecres::VecWalkableArea>>,
    ) -> String {
        self.compile_m6809_inner(dims, vec_bank_map, vec_meshes, vec_walk_areas)
    }

    fn compile_m6809_inner(
        &self,
        dims: &HashMap<String, (u32, u32)>,
        vec_bank_map: &HashMap<String, u8>,
        vec_meshes: &HashMap<String, Vec<crate::vecres::VecMeshSegment>>,
        vec_walk_areas: &HashMap<String, Vec<crate::vecres::VecWalkableArea>>,
    ) -> String {
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
        out.push_str(&format!("    FDB {}  ; groundBottomOffset (floor surface offset from screen bottom)\n", self.editor_meta.ground_bottom_offset));

        // ── PER-SCREEN OBJECT INDEX (Phase: SHOW_LEVEL perf) ──────────────
        // Partition each layer's objects by 256-unit Y screen band so
        // SHOW_LEVEL only iterates the current camera's screen instead of
        // every object every frame. Header appends:
        //   +34   FCB screen_count
        //   +35   FDB _LVL_BG_SCREENS_PTR    (per-screen index for BG layer)
        //   +37   FDB _LVL_GP_SCREENS_PTR
        //   +39   FDB _LVL_FG_SCREENS_PTR
        // Each _LVL_X_SCREENS entry (3 bytes per screen): FCB count, FDB sublist_ptr.
        // The flat _LVL_X_OBJECTS lists are emitted in screen-sorted order so
        // each screen's sublist is a contiguous range within the flat list.
        let screen_count: usize = {
            let span = (self.world_bounds.y_max as i32 - self.world_bounds.y_min as i32).max(0);
            ((span / 256) + 1).max(1) as usize
        };
        out.push_str(&format!("    FCB {}    ; +34 screen_count\n", screen_count));
        out.push_str(&format!("    FDB _{}_BG_SCREENS  ; +35 BG screens index\n", name));
        out.push_str(&format!("    FDB _{}_GP_SCREENS  ; +37 GP screens index\n", name));
        out.push_str(&format!("    FDB _{}_FG_SCREENS  ; +39 FG screens index\n", name));
        out.push_str("\n");

        // Helper: group objects by screen index (single-screen assignment by center Y).
        // Edge cases (objects spanning boundaries) tolerated; runtime Y-cull is still done.
        let y_max = self.world_bounds.y_max;
        let group_by_screen = |objs: &[VPlayObject]| -> Vec<Vec<usize>> {
            let mut buckets: Vec<Vec<usize>> = vec![Vec::new(); screen_count];
            for (i, obj) in objs.iter().enumerate() {
                let s = ((y_max as i32 - obj.y as i32).max(0) / 256) as usize;
                let s = s.min(screen_count - 1);
                buckets[s].push(i);
            }
            buckets
        };

        let bg_buckets = group_by_screen(&self.layers.background);
        let gp_buckets = group_by_screen(&self.layers.gameplay);
        let fg_buckets = group_by_screen(&self.layers.foreground);

        // Helper to emit a layer's objects in screen-sorted order with per-screen sublabels.
        let mut meshes = String::new();
        let emit_layer = |out: &mut String,
                          meshes: &mut String,
                          flat_label: &str,
                          per_screen_label_prefix: &str,
                          objs: &[VPlayObject],
                          buckets: &[Vec<usize>]| {
            out.push_str(&format!("{}:\n", flat_label));
            for (s, bucket) in buckets.iter().enumerate() {
                out.push_str(&format!("{}_S{}:\n", per_screen_label_prefix, s));
                for &i in bucket {
                    let (m, rec) = self.compile_object_with_dims(&objs[i], dims, vec_bank_map, vec_meshes, &name);
                    out.push_str(&rec);
                    meshes.push_str(&m);
                }
            }
            out.push_str("\n");
        };

        emit_layer(
            &mut out, &mut meshes,
            &format!("_{}_BG_OBJECTS", name),
            &format!("_{}_BG_OBJECTS", name),
            &self.layers.background, &bg_buckets,
        );
        emit_layer(
            &mut out, &mut meshes,
            &format!("_{}_GAMEPLAY_OBJECTS", name),
            &format!("_{}_GAMEPLAY_OBJECTS", name),
            &self.layers.gameplay, &gp_buckets,
        );
        emit_layer(
            &mut out, &mut meshes,
            &format!("_{}_FG_OBJECTS", name),
            &format!("_{}_FG_OBJECTS", name),
            &self.layers.foreground, &fg_buckets,
        );

        // Emit per-screen index tables (3 bytes per screen: FCB count, FDB ptr).
        let emit_index = |out: &mut String, table_label: &str, sublist_prefix: &str, buckets: &[Vec<usize>]| {
            out.push_str(&format!("{}:\n", table_label));
            for (s, bucket) in buckets.iter().enumerate() {
                out.push_str(&format!("    FCB {}  ; screen {} count\n", bucket.len(), s));
                out.push_str(&format!("    FDB {}_S{}  ; screen {} ptr\n", sublist_prefix, s, s));
            }
            out.push_str("\n");
        };
        emit_index(&mut out, &format!("_{}_BG_SCREENS", name), &format!("_{}_BG_OBJECTS", name), &bg_buckets);
        emit_index(&mut out, &format!("_{}_GP_SCREENS", name), &format!("_{}_GAMEPLAY_OBJECTS", name), &gp_buckets);
        emit_index(&mut out, &format!("_{}_FG_SCREENS", name), &format!("_{}_FG_OBJECTS", name), &fg_buckets);

        // Emit collision mesh data blocks (referenced by coll_mesh_ptr at object +21).
        // Kept in the same bank as the level so LEVEL_COLLISION_Y (which switches to
        // the level bank) can dereference them in-bank.
        if !meshes.is_empty() {
            out.push_str("; ---- Collision meshes ----\n");
            out.push_str(&meshes);
            out.push_str("\n");
        }

        // Phase 2 wander: resolve each enemy's walkable AREAS + inter-area
        // TRANSITIONS using the SAME shared derivation the ARM/pitrex backend
        // uses (`derive_enemy_areas_and_transitions`), so the two targets emit
        // identical areas/transitions for a given level. Each wander enemy gets
        // its own `_{name}_ENEMY{i}_AREAS` header (mirroring ARM's per-enemy
        // table) that the M6809 runtime reads via wp_ptr (pool +11..12) /
        // wp_count (pool +16). Indexed parallel to `enemy_objects`.
        // M6809-only ROM-budget cap on the number of inter-area transitions a
        // single wander enemy's table may hold. The derivation itself is shared
        // with ARM/pitrex (identical areas + transition set + tuning), so for
        // any level within budget (e.g. wander_test's single transition) the
        // M6809 table is byte-identical to pitrex. Only pathological levels
        // (SnowBros derives 124 transitions across 59 platform areas) are
        // truncated so the level bank stays under the 16 KB multibank limit;
        // ARM/pitrex have no such limit and keep the full set. This preserves
        // the historical M6809 transition budget (previously MAX_TRANS in the
        // now-removed derive_transitions_m6809).
        const M6809_MAX_TRANS: usize = 24;
        let enemy_areas_trans: Vec<(Vec<WalkableArea>, Vec<AreaTransition>)> = enemy_objects
            .iter()
            .map(|obj| {
                if obj.ai_type.as_deref() == Some("wander") {
                    let (areas, mut trans) =
                        self.derive_enemy_areas_and_transitions(obj, vec_walk_areas);
                    trans.truncate(M6809_MAX_TRANS);
                    (areas, trans)
                } else {
                    (Vec::new(), Vec::new())
                }
            })
            .collect();

        // Build each wander enemy's AREAS-header body, then DEDUPLICATE by body
        // content: wander enemies that inherit the same level/vec areas (e.g.
        // every enemy in a level with no per-enemy walkable_areas) produce the
        // byte-identical table and share a single label, so we emit one table
        // for the level instead of one per enemy. This keeps the M6809 ROM the
        // same size as the pre-fix single shared table while still supporting
        // enemies that define their own distinct areas. `enemy_area_label[i]`
        // is the label wander enemy i points at (None → no table / area_count 0).
        let vy0_for_jump_up = |dy: i16| -> i8 {
            for v in 4i16..=16 {
                if v * (v + 1) / 2 >= dy { return v as i8; }
            }
            16
        };
        // Produce the deterministic table BODY (everything after the label line)
        // for one enemy's areas + transitions. Identical (areas, trans) → identical body.
        let build_area_body = |areas: &[WalkableArea], trans: &[AreaTransition]| -> String {
            let center_of = |idx: u8| -> i16 {
                areas
                    .get(idx as usize)
                    .map(|a| ((a.x_min as i32 + a.x_max as i32) / 2) as i16)
                    .unwrap_or(0)
            };
            let mut b = String::new();
            b.push_str(&format!("    FCB {}    ; area_count\n", areas.len()));
            b.push_str(&format!("    FCB {}    ; trans_count\n", trans.len()));
            b.push_str("; Areas (8 bytes each): FDB y, FDB x_min, FDB x_max, FDB y2 (y at x_max; ==y when flat)\n");
            for (idx, a) in areas.iter().enumerate() {
                b.push_str(&format!("    FDB {}  ; area[{}].y (@x_min)\n", a.y, idx));
                b.push_str(&format!("    FDB {}  ; area[{}].x_min\n", a.x_min, idx));
                b.push_str(&format!("    FDB {}  ; area[{}].x_max\n", a.x_max, idx));
                b.push_str(&format!("    FDB {}  ; area[{}].y2 (@x_max)\n", a.y_at_max(), idx));
            }
            if !trans.is_empty() {
                b.push_str("; Transitions (8 bytes each): FCB from, FCB to, FCB type, FCB vy0, FDB from_x, FDB to_x\n");
                b.push_str("; type: 1=jump_up, 2=drop, 3=jump_across; vy0 = signed initial velocity\n");
                for (idx, t) in trans.iter().enumerate() {
                    let ttype: u8 = match t.ttype.as_str() {
                        "jump_up" => 1,
                        "drop" => 2,
                        "jump_across" => 3,
                        _ => 0,
                    };
                    let to_y = areas.get(t.to as usize).map(|a| a.y).unwrap_or(0);
                    let from_y = areas.get(t.from as usize).map(|a| a.y).unwrap_or(0);
                    let dy = to_y - from_y;
                    let vy0: i8 = match ttype {
                        1 => vy0_for_jump_up(dy.max(0)),
                        2 => -1,
                        3 => 3,
                        _ => 0,
                    };
                    let from_x = t.from_x.unwrap_or_else(|| center_of(t.from));
                    let to_x = t.to_x.unwrap_or_else(|| center_of(t.to));
                    b.push_str(&format!("    FCB {},{},{},${:02X}  ; trans[{}] from,to,type,vy0\n",
                        t.from, t.to, ttype, vy0 as u8, idx));
                    b.push_str(&format!("    FDB {}     ; from_x\n", from_x));
                    b.push_str(&format!("    FDB {}     ; to_x\n", to_x));
                }
            }
            b
        };
        let mut enemy_area_label: Vec<Option<String>> = vec![None; enemy_objects.len()];
        let mut area_tables: Vec<(String, String)> = Vec::new(); // (label, body) in emit order
        let mut body_to_label: HashMap<String, String> = HashMap::new();
        for (i, obj) in enemy_objects.iter().enumerate() {
            let is_wander = obj.ai_type.as_deref() == Some("wander");
            let (areas, trans) = &enemy_areas_trans[i];
            if !is_wander || areas.is_empty() { continue; }
            let body = build_area_body(areas, trans);
            let label = if let Some(l) = body_to_label.get(&body) {
                l.clone()
            } else {
                let l = format!("_{}_ENEMY{}_AREAS", name, i);
                body_to_label.insert(body.clone(), l.clone());
                area_tables.push((l.clone(), body));
                l
            };
            enemy_area_label[i] = Some(label);
        }

        // Emit enemy instances (separate section — enemy_objects computed at top of fn)

        if enemy_objects.is_empty() {
            out.push_str(&format!("_{}_ENEMY_COUNT EQU 0\n\n", name));
        } else {
            out.push_str(&format!("_{}_ENEMY_COUNT EQU {}\n\n", name, enemy_objects.len()));
            out.push_str(&format!("; ---- Enemy instances for level {} ----\n", name));
            out.push_str(&format!("; Instance stride = 14 bytes: type_ptr(2) x(2) y(2) ai(1) wave(1) respawn(1) wp_count(1) wp_ptr(2) feet_off(1) init_area_idx(1)\n"));
            out.push_str(&format!("_{}_ENEMY_INSTANCES:\n", name));

            for (i, obj) in enemy_objects.iter().enumerate() {
                let et = obj.enemy_type.as_deref().unwrap_or("");
                let et_up = et.to_uppercase().replace(' ', "_").replace('-', "_");
                let wave = obj.wave;
                let respawn_byte = if obj.respawn { 1u8 } else { 0u8 };
                let wps = obj.patrol_waypoints.as_deref().unwrap_or(&[]);
                let is_wander = obj.ai_type.as_deref() == Some("wander");

                // Per-enemy feet_offset = half-height of the IDLE sprite (origin at
                // center, feet at -hh local → +hh world raises the center so feet
                // touch the walk-area y). Always 0 for non-wander.
                let feet_off = if is_wander {
                    // Try obj.vector_name first (may be a .vanim → not in dims).
                    // Fallback to "{enemy_type}_idle" which is always the static idle .vec.
                    let primary = obj.vector_name.to_lowercase();
                    let fallback = obj
                        .enemy_type
                        .as_deref()
                        .map(|t| format!("{}_idle", t.to_lowercase()))
                        .unwrap_or_default();
                    dims
                        .get(&primary)
                        .or_else(|| dims.get(&fallback))
                        .map(|(_, hh)| *hh as u8)
                        .unwrap_or(0)
                } else {
                    0
                };

                let enemy_areas = &enemy_areas_trans[i].0;

                // Initial area index: find best area for spawn (x,y). Min |dy| with X-in-range bias.
                let init_area_idx = if is_wander && !enemy_areas.is_empty() {
                    enemy_areas
                        .iter()
                        .enumerate()
                        .min_by_key(|(_, a)| {
                            let dy = (obj.y as i32 - a.y as i32).abs();
                            let x_in = obj.x >= a.x_min && obj.x <= a.x_max;
                            if x_in { dy } else { dy + 10000 }
                        })
                        .map(|(idx, _)| idx as u8)
                        .unwrap_or(0)
                } else {
                    0
                };

                // For wander enemies, wp_count becomes area_count and wp_ptr
                // becomes areas_header_ptr (this enemy's areas table, possibly
                // shared with other enemies via dedup).
                let (ai_byte, wp_count, wp_label) = if let Some(lbl) = &enemy_area_label[i] {
                    (4u8, enemy_areas.len(), lbl.clone())
                } else if is_wander {
                    // No areas at all — wander degenerates to no-op
                    (4u8, 0usize, "0".to_string())
                } else {
                    let ai = ai_type_byte(&obj.ai_type);
                    let wpc = wps.len();
                    let lbl = if wpc > 0 { format!("_{}_ENEMY{}_WPS", name, i) } else { "0".to_string() };
                    (ai, wpc, lbl)
                };

                out.push_str(&format!("    ; instance {}\n", i));
                out.push_str(&format!("    FDB _{}_ENEMY   ; enemy type ptr\n", et_up));
                out.push_str(&format!("    FDB {}                   ; spawn x\n", obj.x));
                out.push_str(&format!("    FDB {}                   ; spawn y\n", obj.y));
                out.push_str(&format!("    FCB {}                    ; ai_type: 0=static,1=patrol,2=chase,3=flee,4=wander\n", ai_byte));
                out.push_str(&format!("    FCB {}                    ; wave (0=always present)\n", wave));
                out.push_str(&format!("    FCB {}                    ; respawn: 0=no, 1=yes\n", respawn_byte));
                out.push_str(&format!("    FCB {}                    ; wp_count (or area_count for wander)\n", wp_count));
                out.push_str(&format!("    FDB {}   ; wp_ptr (or areas_header_ptr for wander; 0 if none)\n", wp_label));
                out.push_str(&format!("    FCB {}                    ; feet_offset (sprite half-height for wander, 0 otherwise)\n", feet_off));
                out.push_str(&format!("    FCB {}                    ; initial_area_idx (wander only)\n", init_area_idx));
                out.push_str("\n");
            }

            // Emit non-wander explicit waypoint tables (wander uses shared AREAS table)
            for (i, obj) in enemy_objects.iter().enumerate() {
                let wps = obj.patrol_waypoints.as_deref().unwrap_or(&[]);
                let is_wander = obj.ai_type.as_deref() == Some("wander");
                if !is_wander && !wps.is_empty() {
                    out.push_str(&format!("_{}_ENEMY{}_WPS:\n", name, i));
                    for wp in wps {
                        out.push_str(&format!("    FDB {}  ; wp x\n", wp.x));
                        out.push_str(&format!("    FDB {}  ; wp y\n", wp.y));
                    }
                    out.push_str("\n");
                }
            }

            // Emit the (deduplicated) Phase 2 wander AREAS + TRANS tables. Each
            // table mirrors ARM's `_{name}_ENEMY{i}_AREAS`; the M6809 runtime
            // reads it at areas_ptr (= wp_ptr, pool +11..12). Layout must match
            // helpers.rs (~3046):
            //   +0  FCB area_count
            //   +1  FCB trans_count
            //   +2  area[k]: FDB y, FDB x_min, FDB x_max, FCB 0, FCB 0 (8 bytes)
            //   trans[k]: FCB from, FCB to, FCB type, FCB vy0, FDB from_x, FDB to_x (8 bytes)
            // Unlike ARM (which computes vy0 at runtime), the M6809 runtime uses
            // a compiler-precomputed vy0 (vy0_stash), derived in build_area_body.
            for (label, body) in &area_tables {
                out.push_str(&format!("; ---- Phase 2 wander: areas table {} ----\n", label));
                out.push_str(&format!("{}:\n", label));
                out.push_str(body);
                out.push_str("\n");
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

    /// For an anim enemy: load the `.vanim` referenced by the enemy's patrol/idle
    /// action and return its frames as `(duration_ticks, first_vec_ref_name)`.
    /// Mirrors what the inline vanim draw ticks (frame duration + the frame's
    /// first vec_ref). The `.vanim` path in the action is project-root-relative
    /// (project root = `{venemy_dir}/../..`). None if the action sprite isn't a
    /// `.vanim` or the file can't be read.
    fn lookup_venemy_anim(enemy_type: &str, venemy_dir: Option<&Path>) -> Option<Vec<(u8, String)>> {
        let dir = venemy_dir?;
        let vtext = std::fs::read_to_string(dir.join(format!("{}.venemy", enemy_type))).ok()?;
        let vval: serde_json::Value = serde_json::from_str(&vtext).ok()?;
        let patrol_action = vval["behavior"]["patrol"]["patrolAction"].as_str().unwrap_or("");
        let actions = vval["actions"].as_array()?;
        let action = if !patrol_action.is_empty() {
            actions.iter().find(|a| a["name"].as_str() == Some(patrol_action))?
        } else {
            actions.iter().find(|a| a["name"].as_str() == Some("idle")).or_else(|| actions.first())?
        };
        let sprite_path = action["sprite"].as_str().unwrap_or("");
        if !sprite_path.ends_with(".vanim") { return None; }
        let proj_root = dir.parent()?.parent()?;
        let atext = std::fs::read_to_string(proj_root.join(sprite_path)).ok()?;
        let aval: serde_json::Value = serde_json::from_str(&atext).ok()?;
        let frames = aval["frames"].as_array()?;
        let mut out = Vec::new();
        for f in frames {
            let dur = f["duration_ticks"].as_u64().unwrap_or(1) as u8;
            let vec_ref = f["vec_refs"].as_array()
                .and_then(|v| v.first()).and_then(|s| s.as_str()).unwrap_or("");
            if !vec_ref.is_empty() { out.push((dur, vec_ref.to_string())); }
        }
        if out.is_empty() { None } else { Some(out) }
    }

    /// FNV-1a 8-bit hash of an event name — matches the inline
    /// `pitrex_enemy_fire_event` dispatch (expressions.rs computes the same hash
    /// at each ENEMY_FIRE_EVENT call site).
    fn fnv1a_u8(s: &str) -> u8 {
        let mut h: u32 = 2166136261;
        for b in s.bytes() { h = h.wrapping_mul(16777619) ^ (b as u32); }
        (h & 0xFF) as u8
    }

    /// Load an enemy type's state machine for the libvpy PI state-machine blob.
    /// Returns `(states, events)`:
    ///   states[i] = (is_anim, frames) where frames = [(dur_ticks, vec_ref)]
    ///     (a single (0, vec_stem) entry for a static .vec action; the .vanim
    ///     frame list for an animated action). Indexed by sm_state.
    ///   events[i] = [(fnv1a_hash, target_state_idx)] for state i's on_event list.
    /// Mirrors emit_enemy_data_for_pitrex (pitrex/assets.rs): the SAME
    /// state→sprite + event dispatch data, but position-independent (sprite
    /// refs become indices, event table is bytes). None if no state machine.
    fn lookup_venemy_smdata(
        enemy_type: &str,
        venemy_dir: Option<&Path>,
    ) -> Option<(Vec<(u8, Vec<(u8, String)>)>, Vec<Vec<(u8, u8)>>)> {
        let dir = venemy_dir?;
        let vtext = std::fs::read_to_string(dir.join(format!("{}.venemy", enemy_type))).ok()?;
        let vval: serde_json::Value = serde_json::from_str(&vtext).ok()?;
        let actions = vval["actions"].as_array()?;
        let states_json = vval["state_machine"]["states"].as_array()?;
        let state_names: Vec<String> = states_json.iter()
            .filter_map(|s| s["name"].as_str().map(|x| x.to_string())).collect();
        let proj_root = dir.parent()?.parent()?;
        let mut states: Vec<(u8, Vec<(u8, String)>)> = Vec::new();
        let mut events: Vec<Vec<(u8, u8)>> = Vec::new();
        for st in states_json.iter().take(8) {
            let action_name = st["action"].as_str().unwrap_or("");
            let action = actions.iter().find(|a| a["name"].as_str() == Some(action_name));
            let sprite_path = action.and_then(|a| a["sprite"].as_str()).unwrap_or("");
            let sprite = if sprite_path.ends_with(".vanim") {
                let mut fr = Vec::new();
                if let Ok(atext) = std::fs::read_to_string(proj_root.join(sprite_path)) {
                    if let Ok(aval) = serde_json::from_str::<serde_json::Value>(&atext) {
                        if let Some(frs) = aval["frames"].as_array() {
                            for f in frs {
                                let dur = f["duration_ticks"].as_u64().unwrap_or(1) as u8;
                                let vr = f["vec_refs"].as_array()
                                    .and_then(|v| v.first()).and_then(|s| s.as_str()).unwrap_or("");
                                if !vr.is_empty() { fr.push((dur, vr.to_string())); }
                            }
                        }
                    }
                }
                (1u8, fr)
            } else if sprite_path.ends_with(".vec") {
                let stem = Path::new(sprite_path).file_stem()
                    .and_then(|s| s.to_str()).unwrap_or("").to_string();
                (0u8, if stem.is_empty() { vec![] } else { vec![(0u8, stem)] })
            } else {
                (0u8, vec![])
            };
            states.push(sprite);
            let mut evs = Vec::new();
            if let Some(oe) = st["on_event"].as_array() {
                for e in oe.iter().take(4) {
                    let name = e["event"].as_str().unwrap_or("");
                    let to = e["to"].as_str().unwrap_or("");
                    let target = state_names.iter().position(|n| n == to).unwrap_or(0) as u8;
                    if !name.is_empty() { evs.push((Self::fnv1a_u8(name), target)); }
                }
            }
            events.push(evs);
        }
        Some((states, events))
    }

    /// Resolve the enemy's IDLE-sprite (wander IDLE sub-state swap target),
    /// returning `(is_anim, frames)` like a state sprite. Priority mirrors the
    /// inline emit_enemy_data_for_pitrex idle pick: action named "idle" > first
    /// static (.vec) action > first action. None if unresolvable.
    fn lookup_venemy_idle(
        enemy_type: &str,
        venemy_dir: Option<&Path>,
    ) -> Option<(u8, Vec<(u8, String)>)> {
        let dir = venemy_dir?;
        let vtext = std::fs::read_to_string(dir.join(format!("{}.venemy", enemy_type))).ok()?;
        let vval: serde_json::Value = serde_json::from_str(&vtext).ok()?;
        let actions = vval["actions"].as_array()?;
        let action = actions.iter().find(|a| a["name"].as_str() == Some("idle"))
            .or_else(|| actions.iter().find(|a| a["sprite"].as_str().map_or(false, |s| s.ends_with(".vec"))))
            .or_else(|| actions.first())?;
        let sprite_path = action["sprite"].as_str().unwrap_or("");
        if sprite_path.ends_with(".vec") {
            let stem = Path::new(sprite_path).file_stem().and_then(|s| s.to_str()).unwrap_or("").to_string();
            if stem.is_empty() { return None; }
            Some((0u8, vec![(0u8, stem)]))
        } else if sprite_path.ends_with(".vanim") {
            let proj_root = dir.parent()?.parent()?;
            let atext = std::fs::read_to_string(proj_root.join(sprite_path)).ok()?;
            let aval: serde_json::Value = serde_json::from_str(&atext).ok()?;
            let mut fr = Vec::new();
            for f in aval["frames"].as_array()? {
                let dur = f["duration_ticks"].as_u64().unwrap_or(1) as u8;
                let vr = f["vec_refs"].as_array().and_then(|v| v.first()).and_then(|s| s.as_str()).unwrap_or("");
                if !vr.is_empty() { fr.push((dur, vr.to_string())); }
            }
            if fr.is_empty() { None } else { Some((1u8, fr)) }
        } else { None }
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
        self.compile_to_arm_asm_with_venemy_and_meshes(dims, venemy_dir, &HashMap::new(), &HashMap::new(), &HashMap::new())
    }

    pub fn compile_to_arm_asm_with_venemy_and_meshes(
        &self,
        dims: &HashMap<String, (i32, i32)>,
        venemy_dir: Option<&Path>,
        vec_meshes: &HashMap<String, Vec<crate::vecres::VecMeshSegment>>,
        vec_walk_areas: &HashMap<String, Vec<crate::vecres::VecWalkableArea>>,
        vec_min_y: &HashMap<String, i16>,   // for the PI enemy feet_offset (= -min_y)
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

            // Position-independent enemy image for libvpy (Phase 2 of the LEVELS
            // bridge — NEW, tree-shaken until the group is wired). Built from the
            // SAME derived data as the inline table below; sprite refs become
            // INDICES into `_NAME_ENEMY_SPRITES` (-> `_{SPRITE}_VEC`), no absolute
            // pointers. Layout matches libvpy vpy_spawn_enemies (see vpy.c).
            let mut pi_bytes: Vec<u8> = Vec::new();
            pi_bytes.extend_from_slice(&(ec as u16).to_le_bytes());
            let mut enemy_sprite_syms: Vec<String> = Vec::new();
            // PI anim descriptors `_{ANIM}_ANIMC`-style blobs for anim enemies,
            // emitted after the sprite table. Each entry: (symbol, bytes).
            let mut anim_descriptors: Vec<(String, Vec<u8>)> = Vec::new();
            // PI state-machine blobs `_{NAME}_ENEMY_SM{idx}` (state→sprite + event
            // table) for enemies with a state machine (SnowBros freeze states).
            let mut smdata_blobs: Vec<(String, Vec<u8>)> = Vec::new();

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
                // Effective level areas precedence:
                //   1. .vec-derived areas (each placed platform contributes its
                //      own walkableAreas translated by object position)
                //   2. Level-wide walkable_areas (fallback when no .vec has any)
                // This lets platform .vec files define where enemies walk and
                // those areas are automatically inherited by enemies that don't
                // specify their own walkable_areas.
                // Resolve areas + transitions via the shared helper (same
                // precedence + auto-derivation used by the M6809 backend, so
                // both targets stay in lockstep).
                let (areas, trans_vec) = self.derive_enemy_areas_and_transitions(obj, vec_walk_areas);
                let trans: &[AreaTransition] = &trans_vec;
                // ── Position-independent enemy record for libvpy ─────────────
                // Same derived fields as the inline table; sprite ref -> index.
                {
                    let push_sprite = |syms: &mut Vec<String>, sym: String| -> u16 {
                        syms.iter().position(|s| s == &sym)
                            .unwrap_or_else(|| { syms.push(sym); syms.len() - 1 }) as u16
                    };
                    // sprite_index -> either a static `_{X}_VEC` or (for an anim
                    // enemy) a PI anim descriptor `_{NAME}_ENEMY_ANIM{idx}` that
                    // the libvpy reader decodes: [frame_count, per frame
                    // (dur u8, vec_index u16)] with vec_index into this same table.
                    let sprite_index: u16 = if is_anim_byte == 1 {
                        match Self::lookup_venemy_anim(&et.to_lowercase(), venemy_dir) {
                            Some(frames) if !frames.is_empty() => {
                                let mut desc: Vec<u8> = Vec::new();
                                desc.push(frames.len().min(255) as u8);
                                for (dur, vec_ref) in &frames {
                                    let vsym = format!("_{}_VEC",
                                        vec_ref.to_uppercase().replace('-', "_").replace(' ', "_"));
                                    let vidx = push_sprite(&mut enemy_sprite_syms, vsym);
                                    desc.push(*dur);
                                    desc.extend_from_slice(&vidx.to_le_bytes());
                                }
                                let dsym = format!("_{name}_ENEMY_ANIM{idx}");
                                anim_descriptors.push((dsym.clone(), desc));
                                push_sprite(&mut enemy_sprite_syms, dsym)
                            }
                            // No frames -> fall back to a static `_VEC` of the anim stem.
                            _ => {
                                let base = sprite_sym.trim_start_matches("_ANIM_");
                                push_sprite(&mut enemy_sprite_syms, format!("_{base}_VEC"))
                            }
                        }
                    } else {
                        let vec_sym = if sprite_sym.ends_with("_VECTORS") {
                            format!("{}_VEC", &sprite_sym[..sprite_sym.len() - 8])
                        } else {
                            sprite_sym.clone()
                        };
                        push_sprite(&mut enemy_sprite_syms, vec_sym)
                    };
                    pi_bytes.extend_from_slice(&sprite_index.to_le_bytes());
                    pi_bytes.extend_from_slice(&obj.x.to_le_bytes());
                    pi_bytes.extend_from_slice(&obj.y.to_le_bytes());
                    pi_bytes.push(ai);
                    pi_bytes.push(wpc);
                    pi_bytes.push(mirror_byte);
                    pi_bytes.push(facing_byte);
                    pi_bytes.push(is_anim_byte);
                    // feet_offset = -(min_y across EVERY sprite of this enemy type,
                    // i.e. `{type}` or `{type}_*`), matching the inline
                    // compute_enemy_feet_offset that fills _DATA[209]. Looking up
                    // only the exact-name vec diverged the spawn area-snap Y by the
                    // feet delta (e.g. SnowBros enemies drawn 8 units off).
                    let et_lc = et.to_lowercase();
                    let et_prefix = format!("{et_lc}_");
                    let mut acc_my: Option<i16> = None;
                    for (n, &my) in vec_min_y {
                        if n == &et_lc || n.starts_with(&et_prefix) {
                            acc_my = Some(acc_my.map_or(my, |a| a.min(my)));
                        }
                    }
                    let feet_pi: i8 = acc_my.map(|my| (-my).clamp(-127, 127) as i8).unwrap_or(0);
                    pi_bytes.push(feet_pi as u8);
                    // Wander sprite-swap slots (used by vpy_update_enemies'
                    // WANDER sub-state transitions via enemy_set_sprite):
                    //   walk sprite = the enemy's default/state-0 sprite (the
                    //     patrol/walk action — same as sprite_index),
                    //   idle sprite = the IDLE action sprite (inline type_data[204]).
                    // Matches the inline wander swap (WALK -> state-0 sprite,
                    // IDLE -> idle action). Emitting these correctly (vs the old
                    // walk=NONE/idle=default no-op) makes a wander enemy with a
                    // distinct idle sprite (e.g. SnowBros: walk vanim, idle .vec)
                    // draw the right sprite per sub-state.
                    let (idle_idx, idle_anim): (u16, u8) =
                        match Self::lookup_venemy_idle(&et.to_lowercase(), venemy_dir) {
                            Some((is_anim, frames)) if !frames.is_empty() => {
                                if is_anim == 1 {
                                    let mut desc: Vec<u8> = Vec::new();
                                    desc.push(frames.len().min(255) as u8);
                                    for (dur, vec_ref) in &frames {
                                        let vsym = format!("_{}_VEC",
                                            vec_ref.to_uppercase().replace('-', "_").replace(' ', "_"));
                                        let vidx = push_sprite(&mut enemy_sprite_syms, vsym);
                                        desc.push(*dur);
                                        desc.extend_from_slice(&vidx.to_le_bytes());
                                    }
                                    let dsym = format!("_{name}_ENEMY_IDLE{idx}");
                                    anim_descriptors.push((dsym.clone(), desc));
                                    (push_sprite(&mut enemy_sprite_syms, dsym), 1u8)
                                } else {
                                    let vsym = format!("_{}_VEC",
                                        frames[0].1.to_uppercase().replace('-', "_").replace(' ', "_"));
                                    (push_sprite(&mut enemy_sprite_syms, vsym), 0u8)
                                }
                            }
                            // No idle action -> idle == default (swap is a no-op).
                            _ => (sprite_index, is_anim_byte),
                        };
                    pi_bytes.extend_from_slice(&idle_idx.to_le_bytes());     // idle_sprite_index
                    pi_bytes.push(idle_anim);                                // idle_is_anim
                    pi_bytes.extend_from_slice(&sprite_index.to_le_bytes()); // walk_sprite_index = default
                    pi_bytes.push(is_anim_byte);                             // walk_is_anim
                    // ── PI state-machine blob index (offset +18) ─────────────
                    // sm_index -> a `_{name}_ENEMY_SM{idx}` blob in the sprite
                    // table (state→sprite + event table), or 0xFFFF if the enemy
                    // type has no state machine. Consumed by vpy_enemy_fire_event
                    // (event dispatch) and vpy_draw_enemies (state-sprite swap).
                    let sm_index: u16 = match Self::lookup_venemy_smdata(&et.to_lowercase(), venemy_dir) {
                        Some((states, events)) if !states.is_empty() => {
                            let mut blob: Vec<u8> = Vec::new();
                            blob.push(states.len().min(8) as u8);      // [0] state_count
                            blob.extend_from_slice(&[0u8; 3]);         // [1..4] pad
                            let mut sanim = [0u8; 8];
                            // [4..20] 8 x u16 state sprite_index (state 0 uses the
                            // enemy's default sprite in draw, so leave it NONE).
                            for i in 0..8 {
                                let sidx: u16 = if i == 0 {
                                    0xFFFFu16
                                } else if let Some((is_anim, frames)) = states.get(i) {
                                    sanim[i] = *is_anim;
                                    if frames.is_empty() {
                                        0xFFFFu16
                                    } else if *is_anim == 1 {
                                        let mut desc: Vec<u8> = Vec::new();
                                        desc.push(frames.len().min(255) as u8);
                                        for (dur, vec_ref) in frames {
                                            let vsym = format!("_{}_VEC",
                                                vec_ref.to_uppercase().replace('-', "_").replace(' ', "_"));
                                            let vidx = push_sprite(&mut enemy_sprite_syms, vsym);
                                            desc.push(*dur);
                                            desc.extend_from_slice(&vidx.to_le_bytes());
                                        }
                                        let dsym = format!("_{name}_ENEMY_SM{idx}_S{i}");
                                        anim_descriptors.push((dsym.clone(), desc));
                                        push_sprite(&mut enemy_sprite_syms, dsym)
                                    } else {
                                        let vsym = format!("_{}_VEC",
                                            frames[0].1.to_uppercase().replace('-', "_").replace(' ', "_"));
                                        push_sprite(&mut enemy_sprite_syms, vsym)
                                    }
                                } else { 0xFFFFu16 };
                                blob.extend_from_slice(&sidx.to_le_bytes());
                            }
                            // [20..28] 8 x u8 is_anim
                            blob.extend_from_slice(&sanim);
                            // [28 + state*20] event table: 8 blocks x 20 bytes.
                            // Per block: event_count(u8), 3 pad, 4 x (hash, target, 2 pad).
                            for i in 0..8 {
                                let evs = events.get(i).cloned().unwrap_or_default();
                                blob.push(evs.len().min(4) as u8);
                                blob.extend_from_slice(&[0u8; 3]);
                                for e in 0..4 {
                                    if let Some((hash, target)) = evs.get(e) {
                                        blob.push(*hash);
                                        blob.push(*target);
                                        blob.extend_from_slice(&[0u8; 2]);
                                    } else {
                                        blob.extend_from_slice(&[0u8; 4]);
                                    }
                                }
                            }
                            let smsym = format!("_{name}_ENEMY_SM{idx}");
                            smdata_blobs.push((smsym.clone(), blob));
                            push_sprite(&mut enemy_sprite_syms, smsym)
                        }
                        _ => 0xFFFFu16,
                    };
                    pi_bytes.extend_from_slice(&sm_index.to_le_bytes());     // [18] sm_index
                    for wp in wps {
                        pi_bytes.extend_from_slice(&wp.x.to_le_bytes());
                        pi_bytes.extend_from_slice(&wp.y.to_le_bytes());
                    }
                    pi_bytes.extend_from_slice(&(areas.len() as u16).to_le_bytes());
                    for a in &areas {
                        // 8-byte area record (matches the m6809/ARM asm layout):
                        // i16 y(@x_min), i16 x_min, i16 x_max, i16 y2(@x_max).
                        pi_bytes.extend_from_slice(&a.y.to_le_bytes());
                        pi_bytes.extend_from_slice(&a.x_min.to_le_bytes());
                        pi_bytes.extend_from_slice(&a.x_max.to_le_bytes());
                        pi_bytes.extend_from_slice(&a.y_at_max().to_le_bytes());
                    }
                    pi_bytes.extend_from_slice(&(trans.len() as u16).to_le_bytes());
                    let center_of = |ci: u8| -> i16 {
                        let a = areas.get(ci as usize).unwrap_or(&WalkableArea { y: 0, x_min: 0, x_max: 0, y2: None });
                        ((a.x_min as i32 + a.x_max as i32) / 2) as i16
                    };
                    for t in trans {
                        let ttype = match t.ttype.as_str() {
                            "jump_up" => 1u8, "drop" => 2u8, "jump_across" => 3u8, _ => 0u8,
                        };
                        let fx = t.from_x.unwrap_or_else(|| center_of(t.from));
                        let tx = t.to_x.unwrap_or_else(|| center_of(t.to));
                        pi_bytes.push(t.from);
                        pi_bytes.push(t.to);
                        pi_bytes.push(ttype);
                        pi_bytes.push(0u8);
                        pi_bytes.extend_from_slice(&fx.to_le_bytes());
                        pi_bytes.extend_from_slice(&tx.to_le_bytes());
                    }
                }

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
                            "    .hword {}, {}, {}, {}  @ area {}: y(@x_min), x_min, x_max, y2(@x_max)\n",
                            a.y, a.x_min, a.x_max, a.y_at_max(), ai_idx));
                    }
                    for (ti_idx, t) in trans.iter().enumerate() {
                        let ttype = match t.ttype.as_str() {
                            "jump_up"     => 1u8,
                            "drop"        => 2u8,
                            "jump_across" => 3u8,
                            _             => 0u8,
                        };
                        // Compute defaults: if from_x / to_x absent, use the
                        // center of the corresponding area (matches editor's
                        // default rendering).
                        let center_of = |idx: u8| -> i16 {
                            let a = areas.get(idx as usize)
                                .unwrap_or(&WalkableArea { y: 0, x_min: 0, x_max: 0, y2: None });
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

            // ── libvpy position-independent enemy image + sprite table ───────
            // NEW, tree-shaken until the LEVELS group is wired (own .rodata,
            // .balign 4, --gc-sections). Consumed by vpy_spawn_enemies.
            out.push_str(&format!("@ --- {name}_ENEMY_SPRITES (libvpy enemy sprite-index table) ---\n"));
            out.push_str(&format!(".section .rodata._{name}_ENEMY_SPRITES,\"a\",%progbits\n"));
            out.push_str("    .balign 4\n");
            out.push_str(&format!(".global _{name}_ENEMY_SPRITES\n_{name}_ENEMY_SPRITES:\n"));
            if enemy_sprite_syms.is_empty() {
                out.push_str("    .word 0\n");
            } else {
                for sp in &enemy_sprite_syms {
                    out.push_str(&format!("    .word {sp}\n"));
                }
            }
            // PI anim descriptors (referenced by `.word` in the sprite table above).
            for (dsym, bytes) in &anim_descriptors {
                out.push_str(&format!("@ --- {dsym} (libvpy PI anim descriptor) ---\n"));
                out.push_str(&format!(".section .rodata.{dsym},\"a\",%progbits\n"));
                out.push_str("    .balign 4\n");
                out.push_str(&format!(".global {dsym}\n{dsym}:\n"));
                for chunk in bytes.chunks(16) {
                    let vals: Vec<String> = chunk.iter().map(|b| format!("0x{b:02X}")).collect();
                    out.push_str(&format!("    .byte   {}\n", vals.join(", ")));
                }
            }
            // PI state-machine blobs (referenced by `.word` in the sprite table).
            for (smsym, bytes) in &smdata_blobs {
                out.push_str(&format!("@ --- {smsym} (libvpy PI state-machine: state sprites + event table) ---\n"));
                out.push_str(&format!(".section .rodata.{smsym},\"a\",%progbits\n"));
                out.push_str("    .balign 4\n");
                out.push_str(&format!(".global {smsym}\n{smsym}:\n"));
                for chunk in bytes.chunks(16) {
                    let vals: Vec<String> = chunk.iter().map(|b| format!("0x{b:02X}")).collect();
                    out.push_str(&format!("    .byte   {}\n", vals.join(", ")));
                }
            }
            out.push_str(&format!("@ --- {name}_ENEMIES_C (libvpy position-independent enemy image) ---\n"));
            out.push_str(&format!(".section .rodata._{name}_ENEMIES_C,\"a\",%progbits\n"));
            out.push_str("    .balign 4\n");
            out.push_str(&format!(".global _{name}_ENEMIES_C\n_{name}_ENEMIES_C:\n"));
            for chunk in pi_bytes.chunks(16) {
                let vals: Vec<String> = chunk.iter().map(|b| format!("0x{b:02X}")).collect();
                out.push_str(&format!("    .byte   {}\n", vals.join(", ")));
            }
            out.push_str(".section .text\n\n");
        }

        out
    }

    /// Auto-derive transitions between walkable areas from geometry. Three
    /// categories of immediate neighbors are emitted:
    ///   - jump_up   / drop  : vertical pair with X-overlap >= MIN_X_OVERLAP.
    ///                          Closest above/below to each area; from_x/to_x
    ///                          centered on the overlap.
    ///   - jump_across       : lateral pair with similar Y (|dy| <= LATERAL_Y),
    ///                          no X-overlap, X-gap <= LATERAL_GAP. Only the
    ///                          closest neighbor on each side is emitted, so
    ///                          enemies never skip-jump from #0 to #3.
    /// All transitions are emitted in both directions.
    fn derive_transitions(
        areas: &[WalkableArea],
        isolate_screens: bool,
        world_y_max: i16,
        min_x_overlap: i16,
        lateral_y: i16,
        lateral_gap: i16,
        sources: Option<&[usize]>,
    ) -> Vec<AreaTransition> {
        let min_x_overlap = min_x_overlap.max(0);
        let lateral_y = lateral_y.max(0);
        let lateral_gap = lateral_gap.max(0);
        // Same-source pairs (two walkable areas of the same placed .vec) are
        // intentional shelves on one physical asset and should always have a
        // direct jump_up / drop edge between them, even when another platform
        // happens to sit between them in Y. Without this, an enemy on
        // platform20's top shelf has to detour through some neighboring
        // platform's shelf to reach its own bottom shelf.
        let same_source = |i: usize, j: usize| -> bool {
            match sources {
                Some(s) if i < s.len() && j < s.len() => s[i] == s[j],
                _ => false,
            }
        };

        let mut out: Vec<AreaTransition> = Vec::new();
        let n = areas.len();

        let overlap_amount = |a: &WalkableArea, b: &WalkableArea| -> i16 {
            let lo = a.x_min.max(b.x_min);
            let hi = a.x_max.min(b.x_max);
            (hi as i32 - lo as i32).max(0) as i16
        };
        let overlap_mid = |a: &WalkableArea, b: &WalkableArea| -> i16 {
            let lo = a.x_min.max(b.x_min);
            let hi = a.x_max.min(b.x_max);
            ((lo as i32 + hi as i32) / 2) as i16
        };
        // Screen partition aligned to worldBounds.yMax (each screen is a
        // 256-unit Y band). Two areas with the same screen index are on the
        // same floor; transitions between different screens are filtered out
        // when `isolate_screens` is set.
        let screen_of = |y: i16| -> i32 {
            (world_y_max as i32 - y as i32).div_euclid(256)
        };
        let same_screen = |a: &WalkableArea, b: &WalkableArea| -> bool {
            !isolate_screens || screen_of(a.y) == screen_of(b.y)
        };

        for i in 0..n {
            // Closest area strictly above with X-overlap (immediate upper).
            let mut upper: Option<usize> = None;
            for j in 0..n {
                if j == i { continue; }
                if areas[j].y <= areas[i].y { continue; }
                if !same_screen(&areas[i], &areas[j]) { continue; }
                if overlap_amount(&areas[i], &areas[j]) < min_x_overlap { continue; }
                match upper {
                    None => upper = Some(j),
                    Some(u) if areas[j].y < areas[u].y => upper = Some(j),
                    _ => {}
                }
            }
            if let Some(u) = upper {
                let mid = overlap_mid(&areas[i], &areas[u]);
                out.push(AreaTransition {
                    from: i as u8, to: u as u8,
                    ttype: "jump_up".to_string(),
                    from_x: Some(mid), to_x: Some(mid),
                });
                out.push(AreaTransition {
                    from: u as u8, to: i as u8,
                    ttype: "drop".to_string(),
                    from_x: Some(mid), to_x: Some(mid),
                });
            }
            // Force a direct jump_up/drop edge to every same-source upper area
            // (i.e. every other walkable area of the same placed .vec that
            // sits above i in Y and has the required X-overlap). This makes
            // shelves of a multi-tier asset always reachable from each other,
            // even when a different platform's shelf is closer in Y.
            for j in 0..n {
                if j == i { continue; }
                if !same_source(i, j) { continue; }
                if areas[j].y <= areas[i].y { continue; }
                if upper == Some(j) { continue; } // already emitted above
                if overlap_amount(&areas[i], &areas[j]) < min_x_overlap { continue; }
                let mid = overlap_mid(&areas[i], &areas[j]);
                out.push(AreaTransition {
                    from: i as u8, to: j as u8,
                    ttype: "jump_up".to_string(),
                    from_x: Some(mid), to_x: Some(mid),
                });
                out.push(AreaTransition {
                    from: j as u8, to: i as u8,
                    ttype: "drop".to_string(),
                    from_x: Some(mid), to_x: Some(mid),
                });
            }

            // Lateral neighbors: closest on left and right at similar Y, with
            // no X-overlap and gap within reach.
            let mut left:  Option<usize> = None;
            let mut right: Option<usize> = None;
            for j in 0..n {
                if j == i { continue; }
                if !same_screen(&areas[i], &areas[j]) { continue; }
                let dy = (areas[i].y as i32 - areas[j].y as i32).abs() as i16;
                if dy > lateral_y { continue; }
                if overlap_amount(&areas[i], &areas[j]) > 0 { continue; }
                if areas[j].x_max < areas[i].x_min {
                    let gap = areas[i].x_min - areas[j].x_max;
                    if gap > lateral_gap { continue; }
                    match left {
                        None => left = Some(j),
                        Some(l) if (areas[i].x_min - areas[j].x_max) < (areas[i].x_min - areas[l].x_max) => left = Some(j),
                        _ => {}
                    }
                } else if areas[j].x_min > areas[i].x_max {
                    let gap = areas[j].x_min - areas[i].x_max;
                    if gap > lateral_gap { continue; }
                    match right {
                        None => right = Some(j),
                        Some(r) if (areas[j].x_min - areas[i].x_max) < (areas[r].x_min - areas[i].x_max) => right = Some(j),
                        _ => {}
                    }
                }
            }
            // Only emit when i < j to avoid duplicate emission from the j-side iteration.
            if let Some(l) = left {
                if i < l {
                    out.push(AreaTransition {
                        from: i as u8, to: l as u8,
                        ttype: "jump_across".to_string(),
                        from_x: Some(areas[i].x_min), to_x: Some(areas[l].x_max),
                    });
                    out.push(AreaTransition {
                        from: l as u8, to: i as u8,
                        ttype: "jump_across".to_string(),
                        from_x: Some(areas[l].x_max), to_x: Some(areas[i].x_min),
                    });
                }
            }
            if let Some(r) = right {
                if i < r {
                    out.push(AreaTransition {
                        from: i as u8, to: r as u8,
                        ttype: "jump_across".to_string(),
                        from_x: Some(areas[i].x_max), to_x: Some(areas[r].x_min),
                    });
                    out.push(AreaTransition {
                        from: r as u8, to: i as u8,
                        ttype: "jump_across".to_string(),
                        from_x: Some(areas[r].x_min), to_x: Some(areas[i].x_max),
                    });
                }
            }
        }

        out
    }

    /// Collect walkable areas from .vec assets placed in the level. Each
    /// matching object contributes its asset's `walkable_areas`, translated
    /// by the object's (x, y). Background and gameplay layers are scanned;
    /// foreground is excluded since it's typically HUD/overlay.
    /// Returns a parallel
    /// `source_idx` vector: source_idx[i] is the placed-object index that
    /// contributed area i. Used by derive_transitions to suppress auto
    /// jump_up/drop pairs between two parallel shelves of the same .vec
    /// (e.g. platform20's top + bottom — they're independent surfaces, not
    /// a vertical jump target).
    fn collect_vec_walkable_areas_with_sources(
        layers: &VPlayLayers,
        vec_walk_areas: &HashMap<String, Vec<crate::vecres::VecWalkableArea>>,
    ) -> (Vec<WalkableArea>, Vec<usize>) {
        let mut out = Vec::new();
        let mut sources = Vec::new();
        let mut obj_idx = 0usize;
        let scan = layers.background.iter().chain(layers.gameplay.iter());
        for obj in scan {
            let key = obj.vector_name.to_lowercase();
            if let Some(areas) = vec_walk_areas.get(&key) {
                for a in areas {
                    out.push(WalkableArea {
                        y: a.y.saturating_add(obj.y as i16),
                        x_min: a.x_min.saturating_add(obj.x as i16),
                        x_max: a.x_max.saturating_add(obj.x as i16),
                        y2: a.y2.map(|y2| y2.saturating_add(obj.y as i16)),
                    });
                    sources.push(obj_idx);
                }
            }
            obj_idx += 1;
        }
        (out, sources)
    }

    /// Pool ALL walkable areas in world coords: level-wide + every placed
    /// background/gameplay object's .vec walkable_areas translated by the
    /// object's (x, y). Returns a flat Vec usable as a candidate set for
    /// wander-enemy patrol-bound derivation on the M6809 target (matches
    /// ARM's `collect_vec_walkable_areas_with_sources` plus level pool).
    #[allow(dead_code)]
    fn collect_all_walk_areas_world(
        layers: &VPlayLayers,
        vec_walk_areas: &HashMap<String, Vec<crate::vecres::VecWalkableArea>>,
        level_areas: &[WalkableArea],
    ) -> Vec<WalkableArea> {
        let mut out: Vec<WalkableArea> = level_areas.to_vec();
        let scan = layers.background.iter().chain(layers.gameplay.iter());
        for obj in scan {
            let key = obj.vector_name.to_lowercase();
            if let Some(areas) = vec_walk_areas.get(&key) {
                for a in areas {
                    out.push(WalkableArea {
                        y: a.y.saturating_add(obj.y as i16),
                        x_min: a.x_min.saturating_add(obj.x as i16),
                        x_max: a.x_max.saturating_add(obj.x as i16),
                        y2: a.y2.map(|y2| y2.saturating_add(obj.y as i16)),
                    });
                }
            }
        }
        out
    }

    /// Pick the closest walkable area to an enemy: minimise |dy| with a heavy
    /// penalty if the enemy's X is outside the area's [x_min, x_max] range.
    /// Returns the chosen area (cloned), or None when no candidates exist.
    #[allow(dead_code)]
    fn find_best_walk_area<'a>(areas: &'a [WalkableArea], obj: &VPlayObject) -> Option<&'a WalkableArea> {
        areas.iter().min_by_key(|a| {
            let dy = (obj.y as i32 - a.y as i32).abs();
            let x_in = obj.x >= a.x_min && obj.x <= a.x_max;
            if x_in { dy } else { dy + 10000 }
        })
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
            if !explicit.is_empty() {
                return explicit.clone();
            }
            // Empty list: treat same as None — IDE saves [] by default even
            // when the designer never configured walkable_areas; fall through
            // to inherit from level/.vec areas (same as transitions handling).
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
            vec![WalkableArea { y: obj.y as i16, x_min, x_max, y2: None }]
        } else {
            vec![]
        }
    }

    /// Resolve the effective walkable AREAS and inter-area TRANSITIONS for a
    /// single enemy, applying the exact same precedence + auto-derivation the
    /// ARM/pitrex backend uses. Shared by both `compile_arm` (per-enemy areas
    /// table) and `compile_m6809_inner` (per-enemy m6809 areas header) so the
    /// two targets never drift.
    ///
    /// Areas precedence (via `derive_walkable_areas`):
    ///   1. enemy's own `walkable_areas`
    ///   2. .vec-derived areas (placed platforms) or level-wide `walkable_areas`
    ///   3. single area from patrol waypoints
    /// Transitions precedence:
    ///   1. enemy's own non-empty `transitions`
    ///   2. level-wide non-empty `transitions`
    ///   3. auto-derived from area geometry (`derive_transitions`)
    fn derive_enemy_areas_and_transitions(
        &self,
        obj: &VPlayObject,
        vec_walk_areas: &HashMap<String, Vec<crate::vecres::VecWalkableArea>>,
    ) -> (Vec<WalkableArea>, Vec<AreaTransition>) {
        let (vec_areas, vec_sources) =
            Self::collect_vec_walkable_areas_with_sources(&self.layers, vec_walk_areas);
        let (level_areas, level_sources): (Vec<WalkableArea>, Option<Vec<usize>>) =
            if !vec_areas.is_empty() {
                (vec_areas, Some(vec_sources))
            } else {
                match self.walkable_areas.as_deref() {
                    Some(a) if !a.is_empty() => (a.to_vec(), None),
                    _ => (Vec::new(), None),
                }
            };
        let areas = Self::derive_walkable_areas(obj, Some(level_areas.as_slice()));
        // Only pass sources when the resolved area list IS the level one (so
        // indices match). If derive picked enemy-own or waypoints, sources
        // don't apply.
        let sources_for_derive: Option<&[usize]> =
            if obj.walkable_areas.as_ref().map_or(true, |v| v.is_empty())
                && areas.len() == level_areas.len()
            {
                level_sources.as_deref()
            } else {
                None
            };
        let obj_trans = obj.transitions.as_deref().filter(|t| !t.is_empty());
        let self_trans = self.transitions.as_deref().filter(|t| !t.is_empty());
        let trans: Vec<AreaTransition> = if let Some(t) = obj_trans {
            t.to_vec()
        } else if let Some(t) = self_trans {
            t.to_vec()
        } else {
            Self::derive_transitions(
                &areas,
                self.isolate_screens,
                self.world_bounds.y_max as i16,
                self.transition_min_x_overlap.unwrap_or(4),
                self.transition_lateral_y.unwrap_or(8),
                self.transition_lateral_gap.unwrap_or(60),
                sources_for_derive,
            )
        };
        (areas, trans)
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

        // +4: escala en TREINTAYDOSAVOS — 32 = 1:1, y el techo son 255/32 = 7,97x.
        //
        // Era x8, y con ese paso un 0,7 del editor caia en 6/8 = 0,75: un 7% de error
        // que se ve en un sprite de 16 px. A x32 el mismo 0,7 da 22/32 = 0,6875, un
        // 1,8%. Se puede cambiar la unidad sin migrar nada porque hasta ahora NINGUN
        // dibujante leia este byte — el valor viajaba al binario y se tiraba. Quien
        // lo lee es vpy_draw_vector_ex (arm/builtins.rs), y 0 se sigue tratando como
        // 1:1 para que un nivel viejo dibuje igual.
        let scale_u8 = (obj.scale * 32.0).round().clamp(1.0, 255.0) as u8;
        out.push_str(&format!("    .byte {}   @ scale (x32; {:.2}x -> {:.4}x)\n",
                              scale_u8, obj.scale, scale_u8 as f32 / 32.0));

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

        // +16: collision mesh pointer. Segment extraction is shared with the
        // M6809 emitter (collision_segments); only the .word/.hword emission below
        // is ARM-specific. We emit every horizontal segment the .vec author chose
        // (no interior-horizontal filtering — that broke multi-tier platforms like
        // platform20 whose lower shelf is intentionally walkable).
        let mesh_label = format!("_COLMESH_{}_{}", level_name, obj.id.replace('-', "_").replace(' ', "_"));
        let (floors, walls) = self.collision_segments(obj, vec_meshes);
        if !floors.is_empty() || !walls.is_empty() {
            // .word requires 4-byte alignment on ARM. Without an explicit balign,
            // the symbol can land on an odd address, making `ldr r12, [r11], #4`
            // read garbage — a huge "seg_count" that spins the raycast forever.
            mesh.push_str("    .balign 4\n");
            mesh.push_str(&format!("{}:  @ {} floor + {} wall collision segments\n",
                mesh_label, floors.len(), walls.len()));
            mesh.push_str(&format!("    .word {}  @ floor segment count\n", floors.len()));
            for (xa, xb, y) in &floors {
                mesh.push_str(&format!("    .hword {}, {}, {}, {}  @ x1={} y1={} x2={} y2={}\n",
                    xa, y, xb, y, xa, y, xb, y));
            }
            mesh.push_str(&format!("    .word {}  @ wall segment count\n", walls.len()));
            for (x, ya, yb) in &walls {
                mesh.push_str(&format!("    .hword {}, {}, {}, {}  @ x={} ymin={} ymax={}\n", x, ya, x, yb, x, ya, yb));
            }
            out.push_str(&format!("    .word {}  @ coll_mesh_ptr\n\n", mesh_label));
        } else {
            out.push_str("    .word 0  @ coll_mesh_ptr (AABB fallback)\n\n");
        }

        (mesh, out)
    }

    /// Target-independent collision-segment extraction for an object.
    /// Returns (floors, walls) in local (.vec) coordinates:
    ///   floors: (xa, xb, y)     horizontal top-edges (y1==y2), xa <= xb
    ///   walls:  (x, ymin, ymax) vertical edges (x1==x2, y1!=y2)
    /// Source priority: explicit obj.collision.segments, else the .vec file's own
    /// mesh. Shared by the M6809 (FDB) and ARM (.word/.hword) emitters so the
    /// extraction logic lives in one place — only the byte emission diverges.
    fn collision_segments(
        &self,
        obj: &VPlayObject,
        vec_meshes: &HashMap<String, Vec<crate::vecres::VecMeshSegment>>,
    ) -> (Vec<(i16, i16, i16)>, Vec<(i16, i16, i16)>) {
        let segs: Vec<(i16, i16, i16, i16)> = if let Some(ls) =
            obj.collision.as_ref().and_then(|c| c.segments.as_ref()).filter(|v| !v.is_empty())
        {
            ls.iter().map(|s| (s.x1, s.y1, s.x2, s.y2)).collect()
        } else if let Some(vm) = vec_meshes.get(&obj.vector_name.to_lowercase()) {
            vm.iter().map(|s| (s.x1, s.y1, s.x2, s.y2)).collect()
        } else {
            Vec::new()
        };

        let mut floors = Vec::new();
        for &(x1, y1, x2, y2) in &segs {
            if y1 == y2 {
                floors.push((x1.min(x2), x1.max(x2), y1));
            }
        }
        // Mesh with no horizontal segments: fall back to raw segments so
        // vertical-only meshes still produce a usable floor list.
        if floors.is_empty() && !segs.is_empty() {
            for &(x1, y1, x2, _y2) in &segs {
                floors.push((x1.min(x2), x1.max(x2), y1));
            }
        }
        let mut walls = Vec::new();
        for &(x1, y1, x2, y2) in &segs {
            if x1 == x2 && y1 != y2 {
                walls.push((x1, y1.min(y2), y1.max(y2)));
            }
        }
        (floors, walls)
    }

    /// Compile a single object to assembly (M6809 format, stride-23).
    /// Returns (mesh_block, object_record). mesh_block is the collision-mesh data
    /// (emitted once per object with segments) and is empty when the object uses
    /// the AABB fallback (coll_mesh_ptr = 0).
    fn compile_object_with_dims(
        &self,
        obj: &VPlayObject,
        dims: &HashMap<String, (u32, u32)>,
        vec_bank_map: &HashMap<String, u8>,
        vec_meshes: &HashMap<String, Vec<crate::vecres::VecMeshSegment>>,
        level_name: &str,
    ) -> (String, String) {
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
        
        // Stride-21 ROM object layout for vector reference:
        //   ROM+16: vector_bank FCB ($FF = null / no visual)
        //   ROM+17-18: vector_ptr FDB
        //   ROM+19: half_width FCB
        //   ROM+20: half_height FCB
        //
        // SHOW_LEVEL_RUNTIME reads vector_bank at +16 first. $FF means no visual; any
        // other value is the bank to switch to before reading vector_ptr at +17.
        // This prevents reading stale data when SHOW_LEVEL_RUNTIME has the level bank
        // active and the vector asset lives in a different bank.
        let is_enemy_obj = obj.enemy_type.as_ref().map_or(false, |t| !t.is_empty());
        if obj.vector_name.is_empty() || is_enemy_obj {
            out.push_str("    FCB $FF  ; vector_bank = null (no visual, ROM+16)\n");
            out.push_str("    FDB 0    ; vector_ptr null (ROM+17)\n");
            out.push_str("    FCB 8    ; half_width (default, ROM+19)\n");
            out.push_str("    FCB 8    ; half_height (default, ROM+20)\n");
        } else {
            let vector_label = format!("_{}_VECTORS", obj.vector_name.to_uppercase());
            let vec_key = obj.vector_name.to_lowercase();
            // Bank where this vector lives; 0 = bank map not populated (single-bank / first pass)
            let bank_num = vec_bank_map.get(&vec_key).copied().unwrap_or(0);
            out.push_str(&format!("    FCB {}   ; vector_bank (ROM+16)\n", bank_num));
            out.push_str(&format!("    FDB {}  ; vector_ptr (ROM+17)\n", vector_label));

            // Bytes +19-20: half_width (cull margin) + half_height (collision AABB)
            // Explicit collision.width/height in .vplay takes priority over vec bounding box.
            let coll_override_w_m6809 = obj.collision.as_ref().and_then(|c| c.width);
            let coll_override_h_m6809 = obj.collision.as_ref().and_then(|c| c.height);
            let frame1_key = format!("{}1", vec_key);

            // half_width — always emit a literal (avoids cross-bank EQU references and vanim gaps)
            // Priority: explicit override → dims map → dims map of first frame (vanim) → default 8
            if let Some(nat_w) = coll_override_w_m6809 {
                let hw = ((nat_w as f32 * obj.scale).round() as u32).clamp(1, 127);
                out.push_str(&format!("    FCB {}  ; half_width (explicit override, ROM+19)\n", hw));
            } else if let Some(&(hw, _)) = dims.get(&vec_key).or_else(|| dims.get(&frame1_key)) {
                let scaled = ((hw as f32 * obj.scale).round() as u32).clamp(1, 127);
                out.push_str(&format!("    FCB {}  ; half_width ({:.2}x, ROM+19)\n", scaled, obj.scale));
            } else {
                out.push_str("    FCB 8  ; half_width (default, ROM+19)\n");
            }

            // half_height — always emit a literal (avoids cross-bank EQU references and vanim gaps)
            if let Some(nat_h) = coll_override_h_m6809 {
                let hh = ((nat_h as f32 * obj.scale).round() as u32).clamp(1, 127);
                out.push_str(&format!("    FCB {}  ; half_height (explicit override, ROM+20)\n", hh));
            } else if let Some(&(_, hh)) = dims.get(&vec_key).or_else(|| dims.get(&frame1_key)) {
                let scaled = ((hh as f32 * obj.scale).round() as u32).clamp(1, 127);
                out.push_str(&format!("    FCB {}  ; half_height ({:.2}x, ROM+20)\n", scaled, obj.scale));
            } else {
                out.push_str("    FCB 8  ; half_height (default, ROM+20)\n");
            }
        }

        // +21-22: collision mesh pointer. Segment extraction shared with the ARM
        // emitter (collision_segments); only the FDB emission below is M6809-specific.
        // Mesh format at coll_mesh_ptr (16-bit big-endian):
        //   FDB floor_count; per floor: FDB x1,y1,x2,y2 (local coords, y1==y2)
        //   FDB wall_count;  per wall:  FDB x,ymin,x,ymax
        let mut mesh = String::new();
        let (floors, walls) = self.collision_segments(obj, vec_meshes);
        if !floors.is_empty() {
            let mesh_label = format!("_COLMESH_{}_{}", level_name, obj.id.replace('-', "_").replace(' ', "_"));
            out.push_str(&format!("    FDB {}  ; coll_mesh_ptr (ROM+21)\n", mesh_label));
            mesh.push_str(&format!("{}:  ; {} floor + {} wall collision segments\n", mesh_label, floors.len(), walls.len()));
            mesh.push_str(&format!("    FDB {}  ; floor segment count\n", floors.len()));
            for (xa, xb, y) in &floors {
                mesh.push_str(&format!("    FDB {},{},{},{}  ; x1,y1,x2,y2\n", xa, y, xb, y));
            }
            mesh.push_str(&format!("    FDB {}  ; wall segment count\n", walls.len()));
            for (x, ya, yb) in &walls {
                mesh.push_str(&format!("    FDB {},{},{},{}  ; x,ymin,x,ymax\n", x, ya, x, yb));
            }
        } else {
            out.push_str("    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)\n");
        }

        out.push_str("\n");
        (mesh, out)
    }

    /// Serialize this level into the position-independent **C byte image**
    /// consumed by the vpy.h runtime (`vpy_load_level` / `vpy_show_level` /
    /// `vpy_update_level`).
    ///
    /// The layout deliberately mirrors the ARM/PiTrex level format
    /// (`compile_to_arm_asm_*`) byte-for-byte at the OBJECT level (20-byte
    /// stride, identical field offsets) so the C interpreter is a direct port
    /// of the ARM runtime. The two link-time-resolved pointers are the only
    /// thing that changes, because a static C array cannot hold absolute
    /// addresses:
    ///   * header layer pointers  → byte OFFSETS from the image base (u32 LE)
    ///   * object `vector_ptr`    → SPRITE INDEX (u32 LE) into a companion
    ///                              sprite-pointer table the C side supplies.
    ///     `0xFFFFFFFF` = no sprite (empty vectorName or enemy marker).
    ///   * object `coll_mesh_ptr` → always 0 (collision queries are deferred
    ///                              in the C runtime — see report).
    ///
    /// Returns `(bytes, sprite_names)` where `sprite_names[i]` is the lowercase
    /// `vectorName` bound to sprite index `i` (in first-reference order). The
    /// caller emits `#include "<name>.h"` + a `{NAME}_vec` entry per sprite.
    ///
    /// Header (36 bytes):
    ///   +0  xMin i16   +2 xMax i16   +4 yMin i16   +6 yMax i16
    ///   +8  bgCount u8 +9 gpCount u8 +10 fgCount u8 +11 pad
    ///   +12 bgObjectsOff u32  +16 gpObjectsOff u32  +20 fgObjectsOff u32
    ///   +24 scrollLeft i16 +26 scrollRight i16 +28 scrollTop i16 +30 scrollBottom i16
    ///   +32 groundBottomOffset i16  +34 pad u16
    pub fn compile_to_c_bytes(&self) -> (Vec<u8>, Vec<String>) {
        self.compile_to_c_bytes_with_meshes(&HashMap::new(), &HashMap::new())
    }

    /// As `compile_to_c_bytes`, but also emits per-object COLLISION MESHES
    /// position-independently: each object's `coll_mesh_ptr` (+16) becomes a byte
    /// OFFSET from the image base to a mesh block appended after the object
    /// arrays (0 = AABB fallback / no mesh). Mesh block (LE), identical layout to
    /// the inline `_COLMESH_*`:
    ///   u32 floor_count; per floor: i16 x1, y1, x2, y2  (y1==y2, horizontal)
    ///   u32 wall_count;  per wall:  i16 x, y_min, x, y_max
    /// `vpy_level_collision_x/y` read it via `s_level + coll_mesh_off`.
    pub fn compile_to_c_bytes_with_meshes(
        &self,
        vec_meshes: &HashMap<String, Vec<crate::vecres::VecMeshSegment>>,
        dims: &HashMap<String, (i32, i32)>,
    ) -> (Vec<u8>, Vec<String>) {
        let mut sprite_names: Vec<String> = Vec::new();
        let mut sprite_index = |name: &str| -> u32 {
            let key = name.to_lowercase();
            if let Some(i) = sprite_names.iter().position(|n| n == &key) {
                i as u32
            } else {
                sprite_names.push(key);
                (sprite_names.len() - 1) as u32
            }
        };

        // Serialize one 20-byte object record.
        let emit_obj = |out: &mut Vec<u8>, obj: &VPlayObject, idx_fn: &mut dyn FnMut(&str) -> u32| {
            out.extend_from_slice(&obj.x.to_le_bytes());
            out.extend_from_slice(&obj.y.to_le_bytes());

            let scale_u8 = (obj.scale * 8.0).round().clamp(1.0, 255.0) as u8;
            out.push(scale_u8);

            // intensity 0 => vpy_show_level's level_draw_obj passes override_b=0
            // so draw_vec_stream uses the .vec's own per-path brightness — matching
            // the inline pitrex_show_level (which clears PITREX_BRIGHTNESS_OVERRIDE
            // and lets pitrex_draw_vector_ex read per-path). (>0 would force a flat
            // override and diverge, e.g. SnowBros' 85-brightness level art.)
            out.push(obj.intensity.unwrap_or(0));

            // flags — identical semantics to compile_arm_object
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
            out.push(flags);

            let type_byte = match obj.obj_type.as_str() {
                "player_start" => 0u8,
                "enemy"        => 1,
                "obstacle"     => 2,
                "collectible"  => 3,
                "background"   => 4,
                "trigger"      => 5,
                _              => 255,
            };
            out.push(type_byte);

            // sprite index (replaces the ARM absolute vector_ptr)
            let is_enemy = obj.enemy_type.as_ref().map_or(false, |t| !t.is_empty());
            let sidx: u32 = if obj.vector_name.is_empty() || is_enemy {
                0xFFFF_FFFF
            } else {
                idx_fn(&obj.vector_name)
            };
            out.extend_from_slice(&sidx.to_le_bytes());

            // half_w / half_h — explicit collision.width/height, else the vec's
            // natural bounding-box half-size from `dims` (matching the inline ARM
            // object at compile_arm_object). half_w is the collision_y/x
            // X-broadphase gate: a 16 placeholder clipped wide platforms to a
            // 32-wide walkable strip (only the center was walkable); the vec
            // half-width covers the full authored platform, like inline.
            let dkey = obj.vector_name.to_lowercase();
            let (nat_hw, nat_hh) = dims.get(&dkey).copied().unwrap_or((16, 16));
            let hw = obj.collision.as_ref().and_then(|c| c.width).map(|v| v as i32)
                .unwrap_or(nat_hw).clamp(1, 127) as u8;
            let hh = obj.collision.as_ref().and_then(|c| c.height).map(|v| v as i32)
                .unwrap_or(nat_hh).clamp(1, 127) as u8;
            out.push(hw);
            out.push(hh);

            out.push(obj.velocity.x.clamp(-128.0, 127.0) as i8 as u8);
            out.push(obj.velocity.y.clamp(-128.0, 127.0) as i8 as u8);

            // coll_mesh_ptr — deferred, always 0 (AABB/no collision)
            out.extend_from_slice(&0u32.to_le_bytes());
        };

        // Header (36 bytes). Layer offsets are patched once we know where each
        // object array lands (BG right after the header, then GP, then FG).
        let mut bytes: Vec<u8> = Vec::new();
        bytes.extend_from_slice(&self.world_bounds.x_min.to_le_bytes());
        bytes.extend_from_slice(&self.world_bounds.x_max.to_le_bytes());
        bytes.extend_from_slice(&self.world_bounds.y_min.to_le_bytes());
        bytes.extend_from_slice(&self.world_bounds.y_max.to_le_bytes());
        bytes.push(self.layers.background.len().min(255) as u8);
        bytes.push(self.layers.gameplay.len().min(255) as u8);
        bytes.push(self.layers.foreground.len().min(255) as u8);
        bytes.push(0); // pad

        const HEADER_LEN: u32 = 36;
        let bg_len = self.layers.background.len() as u32 * 20;
        let gp_len = self.layers.gameplay.len() as u32 * 20;
        let bg_off = HEADER_LEN;
        let gp_off = bg_off + bg_len;
        let fg_off = gp_off + gp_len;
        bytes.extend_from_slice(&bg_off.to_le_bytes());
        bytes.extend_from_slice(&gp_off.to_le_bytes());
        bytes.extend_from_slice(&fg_off.to_le_bytes());

        let sl_left   = self.scroll_limits.left.unwrap_or(self.world_bounds.x_min);
        let sl_right  = self.scroll_limits.right.unwrap_or(self.world_bounds.x_max);
        let sl_top    = self.scroll_limits.top.unwrap_or(self.world_bounds.y_max);
        let sl_bottom = self.scroll_limits.bottom.unwrap_or(self.world_bounds.y_min);
        bytes.extend_from_slice(&sl_left.to_le_bytes());
        bytes.extend_from_slice(&sl_right.to_le_bytes());
        bytes.extend_from_slice(&sl_top.to_le_bytes());
        bytes.extend_from_slice(&sl_bottom.to_le_bytes());
        bytes.extend_from_slice(&self.editor_meta.ground_bottom_offset.to_le_bytes());
        bytes.extend_from_slice(&0u16.to_le_bytes()); // pad → 36 bytes total

        debug_assert_eq!(bytes.len() as u32, HEADER_LEN);

        for obj in &self.layers.background { emit_obj(&mut bytes, obj, &mut sprite_index); }
        for obj in &self.layers.gameplay   { emit_obj(&mut bytes, obj, &mut sprite_index); }
        for obj in &self.layers.foreground { emit_obj(&mut bytes, obj, &mut sprite_index); }

        // ── Collision meshes (position-independent) ─────────────────────────
        // Objects are 36-byte header + contiguous 20-byte records (bg, gp, fg),
        // so object i's +16 coll_mesh field is at 36 + i*20 + 16. Append each
        // non-empty mesh block and patch that field with its image-base offset.
        let all_objs = self.layers.background.iter()
            .chain(self.layers.gameplay.iter())
            .chain(self.layers.foreground.iter());
        for (i, obj) in all_objs.enumerate() {
            let (floors, walls) = self.collision_segments(obj, vec_meshes);
            if floors.is_empty() && walls.is_empty() { continue; }
            let mesh_off = bytes.len() as u32;
            bytes.extend_from_slice(&(floors.len() as u32).to_le_bytes());
            for &(x_min, x_max, y) in &floors {
                for v in [x_min, y, x_max, y] { bytes.extend_from_slice(&v.to_le_bytes()); }
            }
            bytes.extend_from_slice(&(walls.len() as u32).to_le_bytes());
            for &(x, y_min, y_max) in &walls {
                for v in [x, y_min, x, y_max] { bytes.extend_from_slice(&v.to_le_bytes()); }
            }
            let fld = HEADER_LEN as usize + i * 20 + 16;
            bytes[fld..fld + 4].copy_from_slice(&mesh_off.to_le_bytes());
        }

        (bytes, sprite_names)
    }
}

/// Load a `.vplay` file and serialize it into the C byte image + its ordered
/// sprite-name list. Reuses the exact object layout of the ARM/PiTrex level
/// compiler (see `VPlayLevel::compile_to_c_bytes`).
pub fn compile_vplay_file_to_c_bytes(path: &Path) -> Result<(Vec<u8>, Vec<String>)> {
    let level = VPlayLevel::load(path)?;

    // Collect collision meshes + natural dims from the sibling assets/vectors/ dir,
    // exactly like the ARM/PiTrex full build (pitrex/assets.rs). Without this the
    // C level image carries EMPTY meshes, so every platform falls back to a solid
    // AABB box (mesh_off=0) — the player collides with a platform's whole box and
    // can't walk under it, whereas a mesh-backed platform is a thin one-way floor.
    // The .vplay lives at <proj>/assets/playground/<name>.vplay; vecs at
    // <proj>/assets/vectors/*.vec (keyed by file stem = the level's vectorName).
    let mut vec_meshes: std::collections::HashMap<String, Vec<crate::vecres::VecMeshSegment>> =
        std::collections::HashMap::new();
    let mut dims: std::collections::HashMap<String, (i32, i32)> = std::collections::HashMap::new();
    if let Some(vectors_dir) = path.parent().and_then(|p| p.parent()).map(|p| p.join("vectors")) {
        if let Ok(entries) = std::fs::read_dir(&vectors_dir) {
            for entry in entries.flatten() {
                let vp = entry.path();
                if vp.extension().and_then(|e| e.to_str()) != Some("vec") { continue; }
                let Ok(text) = std::fs::read_to_string(&vp) else { continue; };
                let Ok(res) = serde_json::from_str::<crate::vecres::VecResource>(&text) else { continue; };
                let name = vp.file_stem().and_then(|s| s.to_str()).unwrap_or("").to_lowercase();
                let (min_x, max_x) = res.calculate_x_bounds();
                let (_min_y, max_y) = res.calculate_y_bounds();
                let hw = ((max_x - min_x) as i32) / 2;
                let hh = (max_y as i32).max(1);
                dims.insert(name.clone(), (hw, hh));
                if let Some(mesh) = &res.collision_mesh {
                    if !mesh.segments.is_empty() {
                        vec_meshes.insert(name.clone(), mesh.segments.clone());
                    }
                }
            }
        }
    }
    Ok(level.compile_to_c_bytes_with_meshes(&vec_meshes, &dims))
}

/// Compile a `.vplay` level's ENEMY runtime into position-independent C data.
///
/// Returns `(enemy_image_bytes, sprite_syms, extra_blobs)`:
///   * `enemy_image_bytes` — the `_NAME_ENEMIES_C` byte image consumed by
///     `vpy_spawn_enemies` (count u16, then per-enemy records).
///   * `sprite_syms` — the ordered assembly symbols the image indexes into
///     (`_NAME_ENEMY_SPRITES`), e.g. `_ENEMY_VEC` for a static `.vec`, or an
///     anim-descriptor / state-machine blob symbol.
///   * `extra_blobs` — `(symbol, bytes)` for any anim/SM blob the sprite table
///     references, so the C header can emit those inline arrays too.
///
/// This REUSES the real backend emitter
/// (`compile_to_arm_asm_with_venemy_and_meshes`) and text-extracts the enemy
/// section, so the bytes are byte-identical to the VPy pitrex build and to what
/// `vpy.c`'s `vpy_spawn_enemies` reads. The `.venemy` directory is derived from
/// the level path (`{level_dir}/../enemies`) exactly like the pitrex build.
pub fn compile_enemies_to_c_bytes(
    path: &Path,
) -> Result<(Vec<u8>, Vec<String>, Vec<(String, Vec<u8>)>)> {
    let level = VPlayLevel::load(path)?;
    let name = level.metadata.name.to_uppercase().replace('-', "_").replace(' ', "_");
    let assets_dir = path.parent().and_then(|p| p.parent());
    let venemy_dir = assets_dir.map(|p| p.join("enemies"));

    // Load the level's sibling `vectors/` directory so the C enemy image carries
    // the SAME auto-derived walkable AREAS + inter-area transitions the m6809/ARM
    // game build derives (emit_pitrex_assets builds these maps from the placed
    // platforms' .vec `walkableAreas`). Without them every wander enemy's
    // area_count is 0 and libvpy's UPDATE_ENEMIES leaves them stationary — the C
    // build would diverge from the VPy, whose enemies wander the platforms.
    let mut dims: HashMap<String, (i32, i32)> = HashMap::new();
    let mut vec_walk_areas: HashMap<String, Vec<crate::vecres::VecWalkableArea>> = HashMap::new();
    let mut vec_meshes: HashMap<String, Vec<crate::vecres::VecMeshSegment>> = HashMap::new();
    let mut vec_min_y: HashMap<String, i16> = HashMap::new();
    if let Some(vectors_dir) = assets_dir.map(|p| p.join("vectors")) {
        if let Ok(entries) = std::fs::read_dir(&vectors_dir) {
            for entry in entries.flatten() {
                let vp = entry.path();
                if vp.extension().and_then(|e| e.to_str()) != Some("vec") { continue; }
                let Ok(text) = std::fs::read_to_string(&vp) else { continue };
                let Ok(res) = serde_json::from_str::<crate::vecres::VecResource>(&text) else { continue };
                // Key by the FILE STEM, not the .vec's internal `name` field:
                // placed objects reference platforms by file name (their
                // `vectorName`), and some .vec files carry a stale/duplicate
                // `name` (e.g. platform1.vec + platform3.vec both name themselves
                // "platform2"). The m6809/ARM game build keys these maps by the
                // asset file stem for exactly this reason; mirror it so the C
                // enemy image derives the SAME per-platform walkable areas.
                let key = match vp.file_stem().and_then(|s| s.to_str()) {
                    Some(s) => s.to_lowercase(),
                    None => continue,
                };
                let (min_x, max_x) = res.calculate_x_bounds();
                let (my, max_y) = res.calculate_y_bounds();
                dims.insert(key.clone(), (((max_x - min_x) as i32) / 2, (max_y as i32).max(1)));
                vec_min_y.insert(key.clone(), my);
                if let Some(mesh) = &res.collision_mesh {
                    if !mesh.segments.is_empty() {
                        vec_meshes.insert(key.clone(), mesh.segments.clone());
                    }
                }
                if !res.walkable_areas.is_empty() {
                    vec_walk_areas.insert(key, res.walkable_areas.clone());
                }
            }
        }
    }

    let asm = level.compile_to_arm_asm_with_venemy_and_meshes(
        &dims,
        venemy_dir.as_deref(),
        &vec_meshes,
        &vec_walk_areas,
        &vec_min_y,
    );

    let bytes = extract_asm_byte_section(&asm, &format!("_{name}_ENEMIES_C:"));
    let sprite_syms = extract_asm_word_section(&asm, &format!("_{name}_ENEMY_SPRITES:"));
    // Any sprite-table entry that is not a `_..._VEC` is an anim/SM blob whose
    // bytes live in its own `.rodata.<sym>` section — pull those out too so the
    // C header is self-contained (anim/SM is out of scope for enemy_test but the
    // extraction is general for a future SnowBros-C).
    let mut extra_blobs = Vec::new();
    for sym in &sprite_syms {
        if !sym.ends_with("_VEC") {
            let b = extract_asm_byte_section(&asm, &format!("{sym}:"));
            if !b.is_empty() {
                extra_blobs.push((sym.clone(), b));
            }
        }
    }
    Ok((bytes, sprite_syms, extra_blobs))
}

/// Collect the little-endian bytes of a `.byte`-run that follows `label`
/// (a line equal to e.g. `_LEVEL1_ENEMIES_C:`), stopping at the first line that
/// is not a `.byte` directive.
fn extract_asm_byte_section(asm: &str, label: &str) -> Vec<u8> {
    let mut out = Vec::new();
    let mut in_section = false;
    for line in asm.lines() {
        let t = line.trim();
        if !in_section {
            if t == label {
                in_section = true;
            }
            continue;
        }
        if let Some(rest) = t.strip_prefix(".byte") {
            // Drop any trailing `@ comment`, then parse the hex tokens.
            let data = rest.split('@').next().unwrap_or("");
            for tok in data.split(',') {
                let tok = tok.trim();
                if tok.is_empty() { continue; }
                let hex = tok.trim_start_matches("0x").trim_start_matches("0X");
                if let Ok(v) = u8::from_str_radix(hex, 16) {
                    out.push(v);
                } else if let Ok(v) = tok.parse::<i16>() {
                    out.push((v & 0xff) as u8);
                }
            }
        } else {
            break;
        }
    }
    out
}

/// Collect the `.word <symbol>` operands that follow `label`, stopping at the
/// first non-`.word` line. A lone `.word 0` (placeholder for "no sprites")
/// yields an empty list.
fn extract_asm_word_section(asm: &str, label: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut in_section = false;
    for line in asm.lines() {
        let t = line.trim();
        if !in_section {
            if t == label {
                in_section = true;
            }
            continue;
        }
        if let Some(rest) = t.strip_prefix(".word") {
            let sym = rest.split('@').next().unwrap_or("").trim().to_string();
            if sym == "0" { continue; }
            if !sym.is_empty() { out.push(sym); }
        } else {
            break;
        }
    }
    out
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
            walkable_areas: None,
            transitions: None,
            isolate_screens: false,
            transition_min_x_overlap: None,
            transition_lateral_y: None,
            transition_lateral_gap: None,
        };

        assert_eq!(level.version, "2.0");
        assert_eq!(level.metadata.name, "test_level");
    }

    #[test]
    fn test_extract_enemy_asm_sections() {
        // Mirrors the emitter shape: a `.word` sprite table and a `.byte` image,
        // each terminated by a non-directive line.
        let asm = concat!(
            ".global _L1_ENEMY_SPRITES\n",
            "_L1_ENEMY_SPRITES:\n",
            "    .word _ENEMY_VEC\n",
            "    .word _FOO_VEC   @ second sprite\n",
            "@ --- image ---\n",
            ".section .rodata._L1_ENEMIES_C,\"a\",%progbits\n",
            "_L1_ENEMIES_C:\n",
            "    .byte   0x01, 0x00, 0xFF  @ count, hi\n",
            "    .byte   0x10\n",
            ".section .text\n",
        );
        let bytes = extract_asm_byte_section(asm, "_L1_ENEMIES_C:");
        assert_eq!(bytes, vec![0x01, 0x00, 0xFF, 0x10]);
        let syms = extract_asm_word_section(asm, "_L1_ENEMY_SPRITES:");
        assert_eq!(syms, vec!["_ENEMY_VEC".to_string(), "_FOO_VEC".to_string()]);

        // A lone `.word 0` placeholder ("no sprites") yields an empty list.
        let empty = "_X_ENEMY_SPRITES:\n    .word 0\n.section .text\n";
        assert!(extract_asm_word_section(empty, "_X_ENEMY_SPRITES:").is_empty());
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
            walkable_areas: None,
            transitions: None,
            isolate_screens: false,
            transition_min_x_overlap: None,
            transition_lateral_y: None,
            transition_lateral_gap: None,
        };

        let asm = level.compile_to_asm();
        assert!(asm.contains("_EMPTY_LEVEL:"));
        assert!(asm.contains("; Background object count"));
    }

    #[test]
    fn test_walkable_area_y_at_max_defaults_to_y() {
        // Flat area (y2 absent) -> y_at_max() == y; slope (y2 present) -> == y2.
        assert_eq!(WalkableArea { y: 42, x_min: -10, x_max: 10, y2: None }.y_at_max(), 42);
        assert_eq!(WalkableArea { y: 42, x_min: -10, x_max: 10, y2: Some(-8) }.y_at_max(), -8);
    }

    #[test]
    fn test_sloped_walkable_area_emits_y2() {
        // Regression guard for sloped walkable areas: the 8-byte area record must
        // carry y2 (surface height at x_max) as its 4th field. A SLOPE emits
        // y2 != y; a FLAT area emits y2 == y (byte-identical to the old padding).
        let mut enemy = obj("enemy", -40, -20);
        enemy.obj_type = "enemy".to_string();
        enemy.layer = "gameplay".to_string();
        enemy.enemy_type = Some("enemy".to_string());
        enemy.ai_type = Some("wander".to_string());
        enemy.walkable_areas = Some(vec![
            WalkableArea { y: -20, x_min: -80, x_max: 0, y2: Some(20) }, // SLOPE
            WalkableArea { y: 30, x_min: 10, x_max: 80, y2: None },      // FLAT
        ]);

        let level = VPlayLevel {
            version: "2.0".to_string(),
            level_type: "level".to_string(),
            metadata: VPlayMetadata {
                name: "slopes".to_string(), author: String::new(),
                difficulty: "easy".to_string(), time_limit: 0, target_score: 0,
                description: String::new(),
            },
            world_bounds: VPlayWorldBounds { x_min: -96, x_max: 95, y_min: -128, y_max: 127 },
            layers: VPlayLayers { background: vec![], gameplay: vec![enemy], foreground: vec![] },
            scroll_limits: VPlayScrollLimits::default(),
            editor_meta: VPlayEditorMeta::default(),
            walkable_areas: None, transitions: None, isolate_screens: false,
            transition_min_x_overlap: None, transition_lateral_y: None, transition_lateral_gap: None,
        };

        // m6809: FDB y(@x_min), x_min, x_max, y2(@x_max).
        let m6809 = level.compile_to_asm();
        assert!(m6809.contains("FDB -20  ; area[0].y (@x_min)"), "m6809 area[0].y");
        assert!(m6809.contains("FDB 20  ; area[0].y2 (@x_max)"),
            "m6809 sloped area[0] must emit y2=20 (distinct from y=-20)");
        assert!(m6809.contains("FDB 30  ; area[1].y (@x_min)"), "m6809 flat area[1].y");
        assert!(m6809.contains("FDB 30  ; area[1].y2 (@x_max)"),
            "m6809 flat area[1] must emit y2==y (30)");

        // ARM: .hword y, x_min, x_max, y2.
        let arm = level.compile_to_arm_asm(&HashMap::new());
        assert!(arm.contains(".hword -20, -80, 0, 20"),
            "ARM sloped area must emit y2=20 as the 4th hword");
        assert!(arm.contains(".hword 30, 10, 80, 30"),
            "ARM flat area must emit y2==y (30)");
    }

    fn obj(vector_name: &str, x: i16, y: i16) -> VPlayObject {
        VPlayObject {
            id: format!("o_{vector_name}_{x}_{y}"),
            obj_type: "background".to_string(),
            vector_name: vector_name.to_string(),
            x, y, scale: 1.0, rotation: 0,
            intensity: None, layer: "gameplay".to_string(), visible: true,
            velocity: Vec2::default(), physics: None, collision: None, properties: None,
            spawn_delay: 0, destroy_offscreen: false,
            physics_enabled: false, physics_type: None, collidable: true,
            gravity: 0.0, bounce_damping: 0.0,
            enemy_type: None, ai_type: None, patrol_waypoints: None,
            wave: 0, respawn: false, mirror_on_patrol: false, default_facing: String::new(),
            walkable_areas: None, transitions: None,
        }
    }

    #[test]
    fn test_compile_c_bytes_layout() {
        let level = VPlayLevel {
            version: "2.0".to_string(),
            level_type: "level".to_string(),
            metadata: VPlayMetadata {
                name: "world".to_string(), author: String::new(), difficulty: String::new(),
                time_limit: 0, target_score: 0, description: String::new(),
            },
            world_bounds: VPlayWorldBounds { x_min: -96, x_max: 479, y_min: -384, y_max: 127 },
            layers: VPlayLayers {
                background: vec![],
                // ground reused → index 0 for both; marker → index 1
                gameplay: vec![obj("ground", -1, -65), obj("marker", 0, 75), obj("ground", 193, -65)],
                foreground: vec![],
            },
            scroll_limits: VPlayScrollLimits::default(),
            editor_meta: VPlayEditorMeta { ground_bottom_offset: 42 },
            walkable_areas: None, transitions: None, isolate_screens: false,
            transition_min_x_overlap: None, transition_lateral_y: None, transition_lateral_gap: None,
        };

        let (bytes, sprites) = level.compile_to_c_bytes();

        // Header (36) + 3 objects × 20 = 96 bytes.
        assert_eq!(bytes.len(), 36 + 3 * 20);
        // counts
        assert_eq!(bytes[8], 0);  // bgCount
        assert_eq!(bytes[9], 3);  // gpCount
        assert_eq!(bytes[10], 0); // fgCount
        // gpObjectsOff == 36 (right after header, bg empty)
        let gp_off = u32::from_le_bytes([bytes[16], bytes[17], bytes[18], bytes[19]]);
        assert_eq!(gp_off, 36);
        // groundBottomOffset at +32
        assert_eq!(i16::from_le_bytes([bytes[32], bytes[33]]), 42);

        // Sprite de-dup: ground+marker → 2 names, ground first.
        assert_eq!(sprites, vec!["ground".to_string(), "marker".to_string()]);

        // Object 0 (ground) sprite index at +8 == 0; object 1 (marker) == 1;
        // object 2 (ground) == 0 again.
        let sidx = |obj_i: usize| -> u32 {
            let base = 36 + obj_i * 20 + 8;
            u32::from_le_bytes([bytes[base], bytes[base+1], bytes[base+2], bytes[base+3]])
        };
        assert_eq!(sidx(0), 0);
        assert_eq!(sidx(1), 1);
        assert_eq!(sidx(2), 0);
    }
}
