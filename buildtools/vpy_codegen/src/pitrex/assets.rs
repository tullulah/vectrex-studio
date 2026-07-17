//! PiTrex asset data emission.
//!
//! Same format as ARM backend but music compiled at 50fps (PiTrex refreshes at 50Hz).
//!
//! Reads .vec / .vmus / .vsfx files and emits their data as ARM assembly.

use crate::{AssetInfo, AssetType};
use crate::vecres::VecResource;
use crate::animres::VanimResource;
use crate::instrres::InstrResource;
use crate::venemy::EnemyResource;
use std::path::Path;
use std::collections::{BTreeMap, HashMap, HashSet};
use std::fs;
use serde::Deserialize;
use vpy_parser::{Module, Item, Stmt, Expr};

/// Filter assets to only those actually used in the code
pub fn filter_used_assets(assets: &[AssetInfo], module: &Module) -> Vec<AssetInfo> {
    let mut used_names = HashSet::new();

    // Scan all statements for asset references
    collect_asset_names(&module.items, &mut used_names);

    // Also scan any used level files to include the vectors they reference
    let level_names: Vec<String> = used_names.iter().cloned().collect();
    for level_name in &level_names {
        if let Some(level_asset) = assets.iter().find(|a| {
            matches!(a.asset_type, AssetType::Level) && &a.name == level_name
        }) {
            collect_level_vector_names(&level_asset.path, &mut used_names);
        }
    }

    // Also scan used .vanim files to include their vec_refs
    let anim_names: Vec<String> = used_names.iter().cloned().collect();
    for anim_name in &anim_names {
        if let Some(anim_asset) = assets.iter().find(|a| {
            matches!(a.asset_type, AssetType::Animation) && &a.name == anim_name
        }) {
            collect_vanim_vec_refs(&anim_asset.path, &mut used_names);
        }
    }

    // Collect enemy types and vectors referenced in used .vplay level files
    for level_name in &level_names {
        if let Some(level_asset) = assets.iter().find(|a| {
            matches!(a.asset_type, AssetType::Level) && &a.name == level_name
        }) {
            if let Ok(content) = std::fs::read_to_string(&level_asset.path) {
                if let Ok(level) = serde_json::from_str::<serde_json::Value>(&content) {
                    for layer in &["background", "gameplay", "foreground"] {
                        if let Some(objects) = level
                            .get("layers")
                            .and_then(|l| l.get(layer))
                            .and_then(|l| l.as_array())
                        {
                            for obj in objects {
                                if let Some(et) = obj.get("enemyType").and_then(|v| v.as_str()) {
                                    if !et.is_empty() {
                                        used_names.insert(et.to_string());
                                        // Resolve venemy → actual sprite vec/vanim names
                                        let venemy_dir = std::path::Path::new(&level_asset.path)
                                            .parent()
                                            .and_then(|p| p.parent())
                                            .map(|p| p.join("enemies"));
                                        if let Some(ref dir) = venemy_dir {
                                            collect_venemy_sprite_names(et, dir, &mut used_names);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Filter assets to only those referenced in code or used by levels/anims
    assets.iter()
        .filter(|asset| used_names.contains(&asset.name))
        .cloned()
        .collect()
}

/// Scan a .vplay JSON file and add the vector_name of every object to used_names.
fn collect_level_vector_names(level_path: &str, used_names: &mut HashSet<String>) {
    let Ok(content) = fs::read_to_string(level_path) else { return };
    let Ok(level) = serde_json::from_str::<crate::levelres::VPlayLevel>(&content) else { return };
    for obj in level.layers.background.iter()
        .chain(level.layers.gameplay.iter())
        .chain(level.layers.foreground.iter())
    {
        used_names.insert(obj.vector_name.clone());
    }
}

/// Resolve a .venemy file and add all sprite (.vec / .vanim stems) to used_names.
/// For .vanim sprites, also recursively collects the vec_refs inside the vanim.
fn collect_venemy_sprite_names(enemy_type: &str, venemy_dir: &std::path::Path, used_names: &mut HashSet<String>) {
    let path = venemy_dir.join(format!("{}.venemy", enemy_type));
    let Ok(text) = fs::read_to_string(&path) else { return };
    let Ok(val) = serde_json::from_str::<serde_json::Value>(&text) else { return };

    // Collect sprite names from both actions[] and state_machine.states[]
    let mut sprite_paths: Vec<String> = Vec::new();

    if let Some(actions) = val["actions"].as_array() {
        for action in actions {
            if let Some(s) = action["sprite"].as_str() {
                sprite_paths.push(s.to_string());
            }
        }
    }
    // Also collect sprites referenced in state_machine states
    if let Some(states) = val["state_machine"]["states"].as_array() {
        // States only hold action *names*, not paths — so this is a no-op here;
        // the actual paths come from the actions[] list above.  But if a future
        // venemy format ever includes sprite overrides per-state, we handle them:
        for state in states {
            if let Some(s) = state["sprite"].as_str() {
                sprite_paths.push(s.to_string());
            }
        }
    }

    for sprite in &sprite_paths {
        if sprite.is_empty() { continue; }
        let filename = sprite.split('/').last().unwrap_or(sprite.as_str());
        if filename.ends_with(".vec") {
            let stem = filename.trim_end_matches(".vec");
            used_names.insert(stem.to_string());
        } else if filename.ends_with(".vanim") {
            let stem = filename.trim_end_matches(".vanim");
            used_names.insert(stem.to_string());
            // Also collect the individual .vec frames referenced inside the vanim
            let vanim_path = venemy_dir.parent()
                .map(|p| p.join("animations").join(filename))
                .filter(|p| p.exists());
            if let Some(vanim_path) = vanim_path {
                collect_vanim_vec_refs(vanim_path.to_str().unwrap_or(""), used_names);
            }
        }
    }
}

/// Scan a .vanim JSON file and add all vec_refs (base_refs + per-frame) to used_names.
fn collect_vanim_vec_refs(vanim_path: &str, used_names: &mut HashSet<String>) {
    use std::path::Path;
    let Ok(resource) = crate::animres::VanimResource::load(Path::new(vanim_path)) else { return };
    for vec_name in &resource.base_refs {
        used_names.insert(vec_name.clone());
    }
    for frame in &resource.frames {
        for vec_name in &frame.vec_refs {
            used_names.insert(vec_name.clone());
        }
    }
}

/// Recursively collect asset names from statements
fn collect_asset_names(items: &[Item], used_names: &mut HashSet<String>) {
    for item in items {
        match item {
            Item::Function(func) => {
                for stmt in &func.body {
                    collect_asset_names_from_stmt(stmt, used_names);
                }
            }
            _ => {}
        }
    }
}

/// Collect asset names from a single statement
fn collect_asset_names_from_stmt(stmt: &Stmt, used_names: &mut HashSet<String>) {
    match stmt {
        Stmt::Expr(e, _) => collect_asset_names_from_expr(e, used_names),
        Stmt::If { cond, body, elifs, else_body, .. } => {
            collect_asset_names_from_expr(cond, used_names);
            for s in body {
                collect_asset_names_from_stmt(s, used_names);
            }
            for (elif_cond, elif_body) in elifs {
                collect_asset_names_from_expr(elif_cond, used_names);
                for s in elif_body {
                    collect_asset_names_from_stmt(s, used_names);
                }
            }
            if let Some(else_stmts) = else_body {
                for s in else_stmts {
                    collect_asset_names_from_stmt(s, used_names);
                }
            }
        }
        Stmt::While { cond, body, .. } => {
            collect_asset_names_from_expr(cond, used_names);
            for s in body {
                collect_asset_names_from_stmt(s, used_names);
            }
        }
        Stmt::For { start, end, step, body, .. } => {
            collect_asset_names_from_expr(start, used_names);
            collect_asset_names_from_expr(end, used_names);
            if let Some(s) = step {
                collect_asset_names_from_expr(s, used_names);
            }
            for stmt in body {
                collect_asset_names_from_stmt(stmt, used_names);
            }
        }
        Stmt::ForIn { iterable, body, .. } => {
            collect_asset_names_from_expr(iterable, used_names);
            for s in body {
                collect_asset_names_from_stmt(s, used_names);
            }
        }
        Stmt::Return(Some(e), _) => collect_asset_names_from_expr(e, used_names),
        _ => {}
    }
}

/// Collect asset names from expressions
fn collect_asset_names_from_expr(expr: &Expr, used_names: &mut HashSet<String>) {
    match expr {
        Expr::Call(vpy_parser::CallInfo { name, args, .. }) => {
            // Check if it's an asset-loading builtin
            let up = name.to_uppercase();
            if up == "DRAW_VECTOR" || up == "DRAW_VECTOR_EX" || up == "DRAW_VECTOR_3D" ||
               up == "PLAY_MUSIC" || up == "PLAY_SFX" || up == "LOAD_LEVEL" ||
               up == "DRAW_ANIM" || up == "PLAY_NOTE" || up == "DRAW_RECORDING" ||
               up == "PLAY_SAMPLE" {
                // First argument should be asset name (string literal)
                if let Some(Expr::StringLit(asset_name)) = args.first() {
                    used_names.insert(asset_name.clone());
                }
            }
            // Recursively check arguments
            for arg in args {
                collect_asset_names_from_expr(arg, used_names);
            }
        }
        Expr::Binary { left, right, .. } |
        Expr::Compare { left, right, .. } |
        Expr::Logic { left, right, .. } => {
            collect_asset_names_from_expr(left, used_names);
            collect_asset_names_from_expr(right, used_names);
        }
        Expr::Not(operand) | Expr::BitNot(operand) => {
            collect_asset_names_from_expr(operand, used_names);
        }
        Expr::Index { target, index } => {
            collect_asset_names_from_expr(target, used_names);
            collect_asset_names_from_expr(index, used_names);
        }
        Expr::List(elements) => {
            for e in elements {
                collect_asset_names_from_expr(e, used_names);
            }
        }
        Expr::FieldAccess { target, .. } => {
            collect_asset_names_from_expr(target, used_names);
        }
        Expr::MethodCall(vpy_parser::MethodCallInfo { target, args, .. }) => {
            collect_asset_names_from_expr(target, used_names);
            for arg in args {
                collect_asset_names_from_expr(arg, used_names);
            }
        }
        _ => {}
    }
}

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
    /// Whether the track loops (true) or plays once (false).
    /// Defaults to true for backward compatibility.
    #[serde(default = "default_loop_true")]
    r#loop: bool,
}

fn default_loop_true() -> bool { true }

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
// .vrec vector-recording format (multi-frame segment capture)
// ============================================================
//
// Playback runtime: pitrex_draw_recording (builtins.rs). Reused byte layout
// from the rp2350 (arm) backend — TARGET-AGNOSTIC data, only the runtime that
// reads it differs. See compile_vrec below for the emitted binary layout.

#[derive(Deserialize)]
struct VrecResource {
    #[serde(default)]
    #[allow(dead_code)]
    version: String,
    #[serde(default)]
    #[allow(dead_code)]
    name: String,
    /// Capture rate — informational only; playback pacing is driven by the
    /// caller's frame counter (DRAW_RECORDING takes frame % frame_count).
    #[serde(default)]
    fps: f64,
    #[serde(default)]
    frames: Vec<VrecFrame>,
}

#[derive(Deserialize)]
struct VrecFrame {
    #[serde(default)]
    segments: Vec<VrecSegment>,
}

#[derive(Deserialize)]
struct VrecSegment {
    x0: i32,
    y0: i32,
    x1: i32,
    y1: i32,
    /// Intensity 0-127 (recorder only stores visible segments, i > 0)
    i: i32,
}

#[derive(Deserialize)]
struct VsmpResource {
    #[serde(default, rename = "sampleRate")]
    sample_rate: u32,
    #[serde(default, rename = "numSamples")]
    num_samples: u32,
    /// base64 of the packed 4-bit PCM (2 samples/byte, low nibble = even sample).
    #[serde(default)]
    data: String,
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
pub fn emit_pitrex_assets(assets: &[AssetInfo]) -> String {
    let mut s = String::new();

    if assets.is_empty() {
        return s;
    }

    s.push_str("@ ============================================================\n");
    s.push_str("@ Asset data\n");
    s.push_str("@ ============================================================\n\n");

    // Build a dims map: lowercase vector name → (natural_half_width, natural_half_height)
    // Used by level compilation to emit correct scaled collision AABBs.
    // Also build a parsed-vec cache so the center-override pre-pass can reuse them.
    let mut dims_map: HashMap<String, (i32, i32)> = HashMap::new();
    let mut vec_cache: HashMap<String, VecResource> = HashMap::new();
    for asset in assets {
        if !matches!(asset.asset_type, AssetType::Vector) { continue; }
        if let Ok(text) = fs::read_to_string(&asset.path) {
            if let Ok(res) = serde_json::from_str::<VecResource>(&text) {
                let (min_x, max_x) = res.calculate_x_bounds();
                let (_min_y, max_y) = res.calculate_y_bounds();
                let hw = ((max_x - min_x) as i32) / 2;
                // hh = max_y: distance from local origin (0,0) to the top surface.
                // The renderer draws at native scale (no per-object scale applied),
                // so max_y is the correct unscaled top extent for collision.
                let hh = (max_y as i32).max(1);
                dims_map.insert(asset.name.to_lowercase(), (hw, hh));
                vec_cache.insert(asset.name.to_lowercase(), res);
            }
        }
    }

    // Build vec_meshes: lowercase vector name → collision mesh segments from .vec file
    let mut vec_meshes: HashMap<String, Vec<crate::vecres::VecMeshSegment>> = HashMap::new();
    for (name, res) in &vec_cache {
        if let Some(mesh) = &res.collision_mesh {
            if !mesh.segments.is_empty() {
                vec_meshes.insert(name.clone(), mesh.segments.clone());
            }
        }
    }

    // Build vec_walk_areas: lowercase vector name → walkable_areas from .vec file.
    // Inheritance chain at codegen time: .vec → .vplay → .venemy.
    let mut vec_walk_areas: HashMap<String, Vec<crate::vecres::VecWalkableArea>> = HashMap::new();
    for (name, res) in &vec_cache {
        if !res.walkable_areas.is_empty() {
            vec_walk_areas.insert(name.clone(), res.walkable_areas.clone());
        }
    }

    // Build vec_min_y: lowercase name → min Y across all paths. Used by the
    // level emitter to bake a per-enemy feet_offset so area.y can mean the
    // platform's top surface and any enemy sprite snaps to it.
    let mut vec_min_y: HashMap<String, i16> = HashMap::new();
    for (name, res) in &vec_cache {
        let (my, _) = res.calculate_y_bounds();
        vec_min_y.insert(name.clone(), my);
    }

    // ── Center-override pre-pass ────────────────────────────────────────────
    // Sprites that belong to a vanim group OR a venemy group share a single
    // bounding-box center, so per-frame / per-state geometry shifts no longer
    // produce a visible vertical jiggle. Venemy groups override vanim groups
    // because they're the larger context.
    let vec_to_override_center: HashMap<String, (i16, i16)> =
        build_center_overrides(assets, &vec_cache);

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
                let override_center = vec_to_override_center
                    .get(&asset.name.to_lowercase())
                    .copied();
                s.push_str(&emit_vec_resource(&resource, &asset.name, override_center));
                // libvpy position-independent .vec image for the bridged
                // DRAW_VECTOR path (tree-shaken away when DRAW_VECTOR is unused).
                s.push_str(&emit_vec_resource_c_bytes(&resource, &asset.name, override_center));
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
                // Derive venemy directory: {level_dir}/../enemies/
                let venemy_dir = std::path::Path::new(&asset.path)
                    .parent()
                    .and_then(|p| p.parent())
                    .map(|p| p.join("enemies"));
                s.push_str(&level.compile_to_arm_asm_with_venemy_and_meshes(&dims_map, venemy_dir.as_deref(), &vec_meshes, &vec_walk_areas));
                // libvpy position-independent level image + sprite-pointer table
                // for the bridged LOAD/SHOW/UPDATE_LEVEL path (Phase 1 of the
                // LEVELS bridge — NEW, tree-shaken until the group is wired).
                s.push_str(&emit_level_c_bytes(&level, &asset.name));
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
                        s.push_str(&format!(".global _{sym}_DATA\n.balign 4\n_{sym}_DATA:\n    .word 0, 0, 0, 0\n    .byte 0, 0, 0, 0\n    .byte 0, 0, 0, 0\n\n"));
                        continue;
                    }
                };
                let resource: EnemyResource = match serde_json::from_str(&text) {
                    Ok(r) => r,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not parse {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_DATA\n.balign 4\n_{sym}_DATA:\n    .word 0, 0, 0, 0\n    .byte 0, 0, 0, 0\n    .byte 0, 0, 0, 0\n\n"));
                        continue;
                    }
                };
                s.push_str(&emit_enemy_data_for_pitrex(&resource, &sym, &vec_min_y));
            }
            AssetType::Recording => {
                let text = match fs::read_to_string(&asset.path) {
                    Ok(t) => t,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not read {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_VREC\n_{sym}_VREC:\n    .word 0\n\n"));
                        continue;
                    }
                };
                let vrec: VrecResource = match serde_json::from_str(&text) {
                    Ok(r) => r,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not parse {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_VREC\n_{sym}_VREC:\n    .word 0\n\n"));
                        continue;
                    }
                };
                s.push_str(&compile_vrec(&vrec, &asset.name));
            }
            AssetType::Sample => {
                let text = match fs::read_to_string(&asset.path) {
                    Ok(t) => t,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not read {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_SMP\n_{sym}_SMP:\n    .word 0, 0\n\n"));
                        continue;
                    }
                };
                let vsmp: VsmpResource = match serde_json::from_str(&text) {
                    Ok(r) => r,
                    Err(e) => {
                        s.push_str(&format!("@ WARNING: could not parse {}: {}\n", asset.path, e));
                        s.push_str(&format!(".global _{sym}_SMP\n_{sym}_SMP:\n    .word 0, 0\n\n"));
                        continue;
                    }
                };
                s.push_str(&compile_vsmp(&vsmp, &asset.name));
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
// Recording compiler (.vrec → frame/chain table)
// ============================================================
//
// POLYLINE CHAINING (2026-07): consecutive segments that share an endpoint AND
// intensity are folded into a single chain (start point once + one delta per
// line) by the target-agnostic `crate::vrec_chain::chain_frame`. Traced
// contours are closed polylines, so each interior vertex was stored twice
// (~55% redundant); chaining ~halves the flash size. The .vrec FILE format is
// UNCHANGED — chaining is a compile-time transform.
//
// TARGET-AGNOSTIC binary layout — byte-for-byte identical to the rp2350 (arm)
// backend's compile_vrec, read here by pitrex_draw_recording (builtins.rs):
//   _<NAME>_VREC:                       (4-byte aligned)
//     .word  frame_count
//     .word  offset_frame0, offset_frame1, ...  @ byte offsets from _<NAME>_VREC
//   frame N:                            (2-byte aligned)
//     .hword chain_count
//     per chain:
//       .byte start_x, start_y, intensity, seg_count  (i8,i8,u8,u8 — 4 bytes)
//       .byte dx, dy × seg_count                      (i8 deltas — 2*seg_count)
//
// HONEST NOTE: on pitrex the DRAW win is small — v_directDraw32 is an absolute
// two-endpoint line, so the runtime's call count is unchanged whether or not
// segments are chained. The win here is mostly DATA size (flash) + consistency
// with the other backends; the big hardware-draw win (relative draw-delta that
// avoids the per-segment beam reset/reposition) is on rp2350/m6809.
//
// Frame offsets are emitted as assembler label-difference expressions
// (_<NAME>_VREC_Fn - _<NAME>_VREC) so gas computes them — no address math
// in the codegen, consistent with the "linker owns addresses" rule.
const VREC_MAX_DELTAS_PER_CHAIN: usize = 255;

fn compile_vrec(vrec: &VrecResource, override_name: &str) -> String {
    use crate::vrec_chain::{chain_frame, Segment};
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let frame_count = vrec.frames.len();

    let clamp8 = |v: i32| v.clamp(-127, 127) as i8;

    let mut s = String::new();
    s.push_str(&format!(
        "@ --- {} RECORDING ({} frame(s), fps={}, polyline-chained) ---\n",
        override_name, frame_count, vrec.fps
    ));
    s.push_str("    .balign 4\n");
    s.push_str(&format!(".global _{sym}_VREC\n_{sym}_VREC:\n"));
    s.push_str(&format!("    .word   {}               @ frame_count\n", frame_count));
    for i in 0..frame_count {
        s.push_str(&format!(
            "    .word   _{sym}_VREC_F{i} - _{sym}_VREC  @ offset frame {i}\n"
        ));
    }
    for (i, frame) in vrec.frames.iter().enumerate() {
        // Fold this frame's ordered segments into polyline chains.
        let segs: Vec<Segment> = frame.segments.iter()
            .map(|seg| Segment { x0: seg.x0, y0: seg.y0, x1: seg.x1, y1: seg.y1, i: seg.i })
            .collect();
        let chains = chain_frame(&segs);

        // Emit each chain, splitting any chain with > 255 deltas so seg_count
        // fits in one byte. A split re-anchors at the raw pen position.
        let mut emitted: Vec<(i32, i32, i32, Vec<(i32, i32)>)> = Vec::new();
        for c in &chains {
            if c.deltas.len() <= VREC_MAX_DELTAS_PER_CHAIN {
                emitted.push((c.start.0, c.start.1, c.intensity, c.deltas.clone()));
            } else {
                let (mut px, mut py) = c.start;
                for part in c.deltas.chunks(VREC_MAX_DELTAS_PER_CHAIN) {
                    emitted.push((px, py, c.intensity, part.to_vec()));
                    for (dx, dy) in part {
                        px += dx;
                        py += dy;
                    }
                }
            }
        }

        s.push_str("    .balign 2\n");
        s.push_str(&format!("_{sym}_VREC_F{i}:\n"));
        s.push_str(&format!(
            "    .hword  {}               @ chain_count\n",
            emitted.len()
        ));
        for (sx, sy, inten, deltas) in &emitted {
            let start_x = clamp8(*sx);
            let start_y = clamp8(*sy);
            let intensity = (*inten).clamp(0, 127) as u8;
            s.push_str(&format!(
                "    .byte   0x{:02X}, 0x{:02X}, 0x{:02X}, 0x{:02X}  @ start=({},{}) i={} segs={}\n",
                start_x as u8, start_y as u8, intensity, deltas.len() as u8,
                start_x, start_y, intensity, deltas.len()
            ));
            for (dx, dy) in deltas {
                let cdx = clamp8(*dx);
                let cdy = clamp8(*dy);
                s.push_str(&format!(
                    "    .byte   0x{:02X}, 0x{:02X}  @ d=({},{})\n",
                    cdx as u8, cdy as u8, cdx, cdy
                ));
            }
        }
    }
    s.push('\n');
    s
}

// ============================================================
// Sample compiler (.vsmp → 4-bit PCM table)
// ============================================================
//
// TARGET-AGNOSTIC layout — identical to the rp2350 (arm) compile_vsmp. Read in
// the emulator by the pitrex_play_sample trap (video-only on hardware for now):
//   _<NAME>_SMP:                 (4-byte aligned)
//     .word  sample_rate         @ Hz (e.g. 8000)
//     .word  num_samples         @ number of 4-bit samples
//     .byte  <packed 4-bit ...>  @ 2 samples/byte, low nibble = even sample
fn compile_vsmp(vsmp: &VsmpResource, override_name: &str) -> String {
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let bytes = base64_decode(&vsmp.data);
    let mut s = String::new();
    s.push_str(&format!(
        "@ --- {} SAMPLE ({} samples @ {} Hz, {} packed bytes) ---\n",
        override_name, vsmp.num_samples, vsmp.sample_rate, bytes.len()
    ));
    s.push_str("    .balign 4\n");
    s.push_str(&format!(".global _{sym}_SMP\n_{sym}_SMP:\n"));
    s.push_str(&format!("    .word   {}               @ sample_rate (Hz)\n", vsmp.sample_rate));
    s.push_str(&format!("    .word   {}               @ num_samples\n", vsmp.num_samples));
    for chunk in bytes.chunks(16) {
        let row: Vec<String> = chunk.iter().map(|b| format!("0x{:02X}", b)).collect();
        s.push_str(&format!("    .byte   {}\n", row.join(", ")));
    }
    if bytes.is_empty() {
        s.push_str("    .byte   0x00            @ empty payload\n");
    }
    s.push('\n');
    s
}

/// Minimal standard base64 decoder (ignores whitespace/newlines).
fn base64_decode(input: &str) -> Vec<u8> {
    fn val(c: u8) -> Option<u8> {
        match c {
            b'A'..=b'Z' => Some(c - b'A'),
            b'a'..=b'z' => Some(c - b'a' + 26),
            b'0'..=b'9' => Some(c - b'0' + 52),
            b'+' => Some(62),
            b'/' => Some(63),
            _ => None,
        }
    }
    let mut out = Vec::new();
    let mut acc = 0u32;
    let mut nbits = 0u32;
    for &c in input.as_bytes() {
        if c == b'=' { break; }
        let Some(v) = val(c) else { continue };
        acc = (acc << 6) | v as u32;
        nbits += 6;
        if nbits >= 8 {
            nbits -= 8;
            out.push((acc >> nbits) as u8);
        }
    }
    out
}

// ============================================================
// Center-override pre-pass (group-shared bbox centers)
// ============================================================
//
// Goal: when multiple .vec sprites are rendered as frames of an animation
// (.vanim) or as states of an enemy (.venemy), each per-vec center can differ
// by a few pixels (legs move between walk frames, snowball is round vs the
// walking guy, etc).  Per-vec centering produces a visible vertical jiggle on
// every frame swap or state transition.
//
// Fix: compute the COMBINED bounding box of every vec in the group, and use
// THAT center for all vecs in the group.  Venemy groups override vanim groups
// because they're the larger context (a venemy may reference both a .vanim and
// stand-alone .vec actions; all of them should share one anchor).
fn build_center_overrides(
    assets: &[AssetInfo],
    vec_cache: &HashMap<String, VecResource>,
) -> HashMap<String, (i16, i16)> {
    let mut out: HashMap<String, (i16, i16)> = HashMap::new();

    // Lookup: lowercased asset name → AssetInfo  (we resolve sprite paths via stem)
    let asset_by_name: HashMap<String, &AssetInfo> = assets
        .iter()
        .map(|a| (a.name.to_lowercase(), a))
        .collect();

    // Helper: combine the bbox of a set of vec names into a single center.
    let combined_center = |vec_names: &HashSet<String>| -> Option<(i16, i16)> {
        let mut min_x = i16::MAX;
        let mut max_x = i16::MIN;
        let mut min_y = i16::MAX;
        let mut max_y = i16::MIN;
        let mut found_any = false;
        for name in vec_names {
            let Some(res) = vec_cache.get(&name.to_lowercase()) else { continue };
            for layer in &res.layers {
                for path in &layer.paths {
                    for pt in &path.points {
                        if pt.x < min_x { min_x = pt.x; }
                        if pt.x > max_x { max_x = pt.x; }
                        if pt.y < min_y { min_y = pt.y; }
                        if pt.y > max_y { max_y = pt.y; }
                        found_any = true;
                    }
                }
            }
        }
        if !found_any { return None; }
        Some(((max_x + min_x) / 2, (max_y + min_y) / 2))
    };

    // Helper: given a vanim asset, return all vec stems it references.
    let vanim_vec_refs = |anim_path: &str| -> HashSet<String> {
        let mut set = HashSet::new();
        if let Ok(res) = VanimResource::load(Path::new(anim_path)) {
            for n in &res.base_refs { set.insert(n.clone()); }
            for f in &res.frames {
                for n in &f.vec_refs { set.insert(n.clone()); }
            }
        }
        set
    };

    // ── PASS 1: vanim groups ────────────────────────────────────────────────
    for asset in assets {
        if !matches!(asset.asset_type, AssetType::Animation) { continue; }
        let vec_refs = vanim_vec_refs(&asset.path);
        if vec_refs.is_empty() { continue; }
        let Some(center) = combined_center(&vec_refs) else { continue };
        for name in &vec_refs {
            out.insert(name.to_lowercase(), center);
        }
    }

    // ── PASS 2: venemy groups (override pass 1) ─────────────────────────────
    for asset in assets {
        if !matches!(asset.asset_type, AssetType::Enemy) { continue; }
        let Ok(text) = fs::read_to_string(&asset.path) else { continue };
        let Ok(enemy) = serde_json::from_str::<EnemyResource>(&text) else { continue };

        // Collect all vec names this enemy references (directly or via vanim).
        let mut vec_names: HashSet<String> = HashSet::new();
        for action in &enemy.actions {
            if action.sprite.is_empty() { continue; }
            let p = Path::new(&action.sprite);
            let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
            let stem = match p.file_stem().and_then(|s| s.to_str()) {
                Some(s) => s.to_string(),
                None => continue,
            };
            match ext.as_str() {
                "vec" => {
                    vec_names.insert(stem);
                }
                "vanim" => {
                    // Look up the vanim AssetInfo by stem to get its real path,
                    // then collect every vec_ref inside it.
                    if let Some(anim_asset) = asset_by_name.get(&stem.to_lowercase()) {
                        if matches!(anim_asset.asset_type, AssetType::Animation) {
                            for n in vanim_vec_refs(&anim_asset.path) {
                                vec_names.insert(n);
                            }
                        }
                    }
                }
                _ => {}
            }
        }

        if vec_names.is_empty() { continue; }
        let Some(center) = combined_center(&vec_names) else { continue };
        for name in &vec_names {
            // Venemy overrides vanim mapping (insert always wins).
            out.insert(name.to_lowercase(), center);
        }
    }

    out
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

/// One event (or terminator) in a compiled PSG stream.
struct CompiledEvent {
    delay: u8,
    num_writes_byte: u8,      // real event = writes.len(); 0xFF = loop marker; 0 = end
    writes: Vec<(u8, u8)>,    // empty for terminators
    comment: String,
}

/// A compiled PSG event stream (music or SFX). This is the SINGLE shared
/// artifact behind BOTH the ARM/PiTrex `.byte`/`.word` asm emission AND the
/// C-header / raw-byte emission used by the C (vpy.h) runtime. `header_words`
/// are little-endian `.word`s (4 bytes each); events are `.byte`s. `to_bytes()`
/// and `to_asm()` are two views of the exact same data.
struct CompiledStream {
    header_words: Vec<(u32, String)>,   // (value, comment)
    events: Vec<CompiledEvent>,
}

impl CompiledStream {
    /// Little-endian byte image (header words expanded LE), exactly what the
    /// runtime sequencer reads at run time.
    fn to_bytes(&self) -> Vec<u8> {
        let mut b = Vec::new();
        for (w, _) in &self.header_words {
            b.extend_from_slice(&w.to_le_bytes());
        }
        for e in &self.events {
            b.push(e.delay);
            b.push(e.num_writes_byte);
            for (r, v) in &e.writes {
                b.push(*r);
                b.push(*v);
            }
        }
        b
    }

    /// ARM/PiTrex assembly view (`.word` header + `.byte` events). Byte-identical
    /// to `to_bytes()` once assembled.
    fn to_asm(&self, global_label: &str) -> String {
        let mut s = String::new();
        s.push_str(&format!(".global {global_label}\n{global_label}:\n"));
        for (w, comment) in &self.header_words {
            s.push_str(&format!("    .word   {}           @ {}\n", w, comment));
        }
        for e in &self.events {
            s.push_str(&format!("    .byte   {}, {}  @ {}\n", e.delay, e.num_writes_byte, e.comment));
            for (reg, val) in &e.writes {
                s.push_str(&format!("    .byte   {}, {}  @ PSG r{}\n", reg, val, reg));
            }
        }
        s.push('\n');
        s
    }
}

/// Parse a `.vmus` file and return its compiled little-endian PSG byte stream.
/// Reuses the exact notes→PSG compiler used for the ARM/PiTrex asm backend, so
/// the C runtime plays byte-for-byte the same music the hardware does.
pub fn compile_vmus_file_to_bytes(path: &std::path::Path) -> Result<Vec<u8>, String> {
    let text = fs::read_to_string(path).map_err(|e| format!("read {}: {e}", path.display()))?;
    let vmus: VmusResource = serde_json::from_str(&text)
        .map_err(|e| format!("parse {}: {e}", path.display()))?;
    Ok(vmus_stream(&vmus).to_bytes())
}

fn compile_vmus(vmus: &VmusResource, override_name: &str) -> String {
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let stream = vmus_stream(vmus);
    let num_events = stream.header_words.first().map(|(w, _)| *w).unwrap_or(0);
    let mut s = String::new();
    s.push_str(&format!("@ --- {} MUSIC ({} events) ---\n", override_name, num_events));
    s.push_str(&stream.to_asm(&format!("_{sym}_MUSIC")));
    s
}

/// Compile a parsed `.vmus` into a `CompiledStream` (notes → PSG event bytes).
fn vmus_stream(vmus: &VmusResource) -> CompiledStream {
    // Timing conversion: ticks → frames @ 50 fps
    // PiTrex hardware refreshes at 50 Hz (v_setRefresh(50)).
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
                let tone_active_at_on = tone_intervals_early.iter()
                    .any(|&(tc, ton, toff)| tc == ch_idx && ton < on_f && on_f < toff);
                if !tone_active_at_on {
                    frame_writes.entry(on_f).or_default().push((8 + ch, amp));
                }
                // Noise-off: only write vol=0 if no tone note is still playing past this frame.
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

    // ── Build CompiledStream (shared asm + byte serialization) ───────────────
    let mut cevents: Vec<CompiledEvent> = Vec::new();
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
        cevents.push(CompiledEvent {
            delay: delay_byte,
            num_writes_byte: writes.len() as u8,
            writes: writes.clone(),
            comment: format!("frame={} delay={} writes={}", frame, delay_byte, writes.len()),
        });
        prev_frame = *frame;
    }

    // Terminator: loop marker (0xFF) if the track loops, else end marker (num_writes=0).
    // The end marker mirrors the SFX terminator; the runtime stops playback on
    // num_writes=0, leaving the PSG silent (note-off frames already wrote
    // volume=0 before the terminator).
    if vmus.r#loop {
        // Loop marker: fires at loopEnd, jumps back to loop_event_byte_offset
        let last_event_frame = events.last().map(|(f, _)| *f).unwrap_or(0);
        let loop_marker_delay = loop_end_frame.saturating_sub(last_event_frame).saturating_sub(1).min(255) as u8;
        cevents.push(CompiledEvent {
            delay: loop_marker_delay,
            num_writes_byte: 0xFF,
            writes: Vec::new(),
            comment: format!("loop back (fires frame ~{})", loop_end_frame),
        });
    } else {
        cevents.push(CompiledEvent {
            delay: 0,
            num_writes_byte: 0,
            writes: Vec::new(),
            comment: "end (no loop)".to_string(),
        });
    }

    let _ = loop_start_frame;
    CompiledStream {
        header_words: vec![
            (events.len() as u32, "num_events".to_string()),
            (loop_byte_offset, "loop_event_byte_offset from base".to_string()),
        ],
        events: cevents,
    }
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

/// Parse a `.vsfx` file and return its compiled little-endian PSG byte stream.
/// Reuses the exact ADSR/arpeggio→PSG compiler used for the ARM/PiTrex backend.
pub fn compile_vsfx_file_to_bytes(path: &std::path::Path) -> Result<Vec<u8>, String> {
    let text = fs::read_to_string(path).map_err(|e| format!("read {}: {e}", path.display()))?;
    let vsfx: VsfxResource = serde_json::from_str(&text)
        .map_err(|e| format!("parse {}: {e}", path.display()))?;
    Ok(vsfx_stream(&vsfx).to_bytes())
}

fn compile_vsfx(vsfx: &VsfxResource, override_name: &str) -> String {
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let stream = vsfx_stream(vsfx);
    let num_events = stream.header_words.first().map(|(w, _)| *w).unwrap_or(0);
    let mut s = String::new();
    s.push_str(&format!("@ --- {} SFX ({} events) ---\n", override_name, num_events));
    s.push_str(&stream.to_asm(&format!("_{sym}_SFX")));
    s
}

/// Compile a parsed `.vsfx` into a `CompiledStream` (ADSR/arpeggio → PSG bytes).
fn vsfx_stream(vsfx: &VsfxResource) -> CompiledStream {
    // Force SFX onto channel C (regs 4/5 period, 10 volume) so it cannot
    // overwrite music playing on channels A/B. Matches M6809 sfx_doframe.
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

    // ── Build CompiledStream (shared asm + byte serialization) ───────────────
    let mut cevents: Vec<CompiledEvent> = Vec::new();
    let mut prev_frame: u32 = 0;
    for (i, (frame, writes)) in frame_events.iter().enumerate() {
        let delay_byte: u8 = if i == 0 {
            0 // first event: delay not read on initial fire
        } else {
            (*frame - prev_frame).saturating_sub(1).min(255) as u8
        };
        cevents.push(CompiledEvent {
            delay: delay_byte,
            num_writes_byte: writes.len() as u8,
            writes: writes.clone(),
            comment: format!("frame={}", frame),
        });
        prev_frame = *frame;
    }
    // End marker
    cevents.push(CompiledEvent {
        delay: 0,
        num_writes_byte: 0,
        writes: Vec::new(),
        comment: "end".to_string(),
    });

    let _ = total_frames;
    CompiledStream {
        header_words: vec![(frame_events.len() as u32, "num_events".to_string())],
        events: cevents,
    }
}

// ============================================================
// Vector asset emitters (unchanged)
// ============================================================

fn emit_vec_resource(
    res: &VecResource,
    override_name: &str,
    override_center: Option<(i16, i16)>,
) -> String {
    let mut s = String::new();
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");
    // Subtract bounding-box center from all start/bezier coords so that
    // pitrex_draw_vector_ex with ox=oy=0 renders at screen center — matching
    // the m6809 and arm backends which also center assets.
    //
    // If this vec belongs to a vanim or venemy group, use the GROUP combined
    // bounding-box center (passed in) instead of the per-vec center. This keeps
    // animation frames and state-machine sprites anchored to the same screen
    // position, preventing visible jiggle/teleport on transition.
    let (center_x, center_y) = override_center.unwrap_or_else(|| res.calculate_center());

    // Filter out degenerate paths (< 2 points = 0 segments) — they still cost
    // a v_directMove32 + v_setScale call on PiTrex hardware with nothing drawn.
    let paths: Vec<_> = res.visible_paths()
        .into_iter()
        .filter(|p| p.points.len() >= 2)
        .collect();

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

        // Bezier paths: store raw control points as 0xFE runtime-bezier segments.
        // The draw loop calls v_drawBezierCubic per segment (full float precision, no baking).
        if path.path_type.as_deref() == Some("bezier") {
            let pts = &path.points;
            if pts.len() < 4 {
                s.push_str("    .byte   0x02            @ end marker (degenerate bezier)\n\n");
                continue;
            }
            let intensity = path.intensity;
            let x0 = (pts[0].x - center_x).clamp(-127, 127) as i8;
            let y0 = (pts[0].y - center_y).clamp(-127, 127) as i8;
            s.push_str(&format!("    .byte   {}               @ intensity\n", intensity));
            s.push_str(&format!(
                "    .byte   0x{:02X}, 0x{:02X}, 0x00, 0x00  @ y={y0}, x={x0}, hdr\n",
                y0 as u8, x0 as u8
            ));
            let mut i = 0;
            while i + 3 < pts.len() {
                // Bezier control points used as absolute coords by dvex_bezier_seg
                // (adds ox directly), so they must be center-relative like the header.
                let ax  = (pts[i  ].x - center_x).clamp(-127, 127) as i8;
                let ay  = (pts[i  ].y - center_y).clamp(-127, 127) as i8;
                let c0x = (pts[i+1].x - center_x).clamp(-127, 127) as i8;
                let c0y = (pts[i+1].y - center_y).clamp(-127, 127) as i8;
                let c1x = (pts[i+2].x - center_x).clamp(-127, 127) as i8;
                let c1y = (pts[i+2].y - center_y).clamp(-127, 127) as i8;
                let bx  = (pts[i+3].x - center_x).clamp(-127, 127) as i8;
                let by  = (pts[i+3].y - center_y).clamp(-127, 127) as i8;
                s.push_str(&format!(
                    "    .byte   0xFE, 0x{:02X},0x{:02X}, 0x{:02X},0x{:02X}, 0x{:02X},0x{:02X}, 0x{:02X},0x{:02X}  \
                     @ bezier a=({ax},{ay}) cp1=({c0x},{c0y}) cp2=({c1x},{c1y}) b=({bx},{by})\n",
                    ax as u8, ay as u8, c0x as u8, c0y as u8,
                    c1x as u8, c1y as u8, bx as u8, by as u8
                ));
                i += 3;
            }
            s.push_str("    .byte   0x02            @ end marker\n\n");
            continue;
        }

        // Polyline path: bake points to FCB delta segments.
        let baked: Vec<(i16, i16)> = path.points.iter().map(|p| (p.x, p.y)).collect();

        if baked.is_empty() {
            s.push_str("    .byte   0x02            @ end marker (empty path)\n\n");
            continue;
        }

        let intensity = path.intensity;
        let (x0_raw, y0_raw) = baked[0];
        // Center-relative coords (match m6809/arm backends: subtract bounding-box center).
        let y0 = (y0_raw - center_y).clamp(-127, 127) as i8;
        let x0 = (x0_raw - center_x).clamp(-127, 127) as i8;

        s.push_str(&format!(
            "    .byte   {}               @ intensity\n",
            intensity
        ));
        s.push_str(&format!(
            "    .byte   0x{:02X}, 0x{:02X}, 0x00, 0x00  @ y={}, x={}, hdr\n",
            y0 as u8, x0 as u8, y0, x0
        ));

        for j in 0..baked.len() - 1 {
            let (fx, fy) = baked[j];
            let (tx, ty) = baked[j + 1];
            let dx = tx - fx;
            let dy = ty - fy;
            emit_split_segment_arm(&mut s, dx, dy);
        }

        if path.closed && baked.len() > 2 {
            let (fx, fy) = baked[baked.len() - 1];
            let (tx, ty) = baked[0];
            let dx = tx - fx;
            let dy = ty - fy;
            emit_split_segment_arm(&mut s, dx, dy);
        }

        s.push_str("    .byte   0x02            @ end marker\n\n");
    }

    s
}

/// Parse a `.vec` file and return a self-contained little-endian byte image of
/// its paths, for the C (vpy.h) runtime.
///
/// This reuses the EXACT geometry compiler behind the ARM/PiTrex asm backend
/// (`VecResource::visible_paths` / `calculate_center` for centering, and
/// `split_segment_pairs` for <=127-unit segment splitting), so the C runtime
/// draws the same sprite the hardware does.
///
/// Unlike the ARM `emit_vec_resource` — whose header holds link-time absolute
/// `.word` path pointers — the C image is fully position-independent: paths are
/// laid out back-to-back and the interpreter walks them sequentially, each
/// terminated by `0x02`. Layout:
/// ```text
///   [0..2]  path_count            (u16 LE)
///   per path (repeated path_count times):
///     intensity   (u8)
///     y0, x0      (i8, i8)        center-relative move-to header
///     0x00, 0x00                  2 padding bytes (parity with the ARM header)
///     segments:
///       0xFF, dy, dx              line delta (i8, i8)
///       0xFE, ax,ay,c1x,c1y,c2x,c2y,bx,by   cubic bezier (8×i8), center-relative
///     0x02                        end-of-path marker
/// ```
pub fn compile_vec_file_to_bytes(path: &std::path::Path) -> Result<Vec<u8>, String> {
    let text = fs::read_to_string(path).map_err(|e| format!("read {}: {e}", path.display()))?;
    let res: VecResource = serde_json::from_str(&text)
        .map_err(|e| format!("parse {}: {e}", path.display()))?;
    Ok(vec_resource_to_bytes(&res, None))
}

/// Emit the position-independent C `.vec` byte image (`vec_resource_to_bytes`)
/// as an ARM `.byte` blob under the symbol `_NAME_VEC`, for libvpy's
/// `vpy_draw_vector`/`vpy_draw_vector_ex` (the bridged DRAW_VECTOR path).
///
/// This is the DRAW_VECTOR analogue of how the music/SFX bytes stayed shared:
/// the SAME `vec_resource_to_bytes` behind the C `compile-asset` produces these
/// bytes, so the bridged libvpy sprite is byte-identical to what hardware draws.
/// It coexists with the inline `_NAME_VECTORS` (link-time pointer-table format)
/// which the still-inline level/enemy/anim/DRAW_VECTOR_EX runtimes need.
///
/// `.balign 4` (ARMv6 `ldr` of the u16 header via byte loads is fine, but keep
/// parity with the 3D/level blobs — cf. rp2350 unaligned-embed hazard). Emitted
/// in its OWN `.rodata._NAME_VEC` section so `--gc-sections` drops it when
/// DRAW_VECTOR isn't used for this asset; restores `.text` afterwards because
/// the surrounding asset loop emits into `.text`.
fn emit_vec_resource_c_bytes(
    res: &VecResource,
    override_name: &str,
    override_center: Option<(i16, i16)>,
) -> String {
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let bytes = vec_resource_to_bytes(res, override_center);
    let mut s = String::new();
    s.push_str(&format!("@ --- {sym}_VEC (libvpy position-independent .vec image) ---\n"));
    s.push_str(&format!(".section .rodata._{sym}_VEC,\"a\",%progbits\n"));
    s.push_str("    .balign 4\n");
    s.push_str(&format!(".global _{sym}_VEC\n_{sym}_VEC:\n"));
    for chunk in bytes.chunks(16) {
        let vals: Vec<String> = chunk.iter().map(|b| format!("0x{b:02X}")).collect();
        s.push_str(&format!("    .byte   {}\n", vals.join(", ")));
    }
    s.push_str(".section .text\n\n");
    s
}

/// Emit the position-independent C level image (`VPlayLevel::compile_to_c_bytes`)
/// as `_NAME_LEVEL_C`, plus the companion `{NAME}_level_sprites` pointer table
/// that libvpy's `vpy_load_level(level, sprites)` indexes. Each sprite slot is
/// the sprite's libvpy-format `_{SPRITE}_VEC` image (drawn by `vpy_draw_vector_ex`
/// in `vpy_show_level`), so the sprite table + level image are wholly
/// position-independent. Own `.rodata` sections + `.balign 4` + `--gc-sections`
/// so both drop out when the level group isn't bridged (the `_NAME_VEC` pattern).
///
/// Phase 1: NEW, unused symbols — the LOAD/SHOW/UPDATE_LEVEL call sites still
/// route inline until the whole level+enemy group flips atomically.
fn emit_level_c_bytes(level: &crate::levelres::VPlayLevel, name: &str) -> String {
    let sym = name.to_uppercase().replace('-', "_").replace(' ', "_");
    let (bytes, sprite_names) = level.compile_to_c_bytes();
    let mut s = String::new();
    // Sprite-pointer table (index → _{SPRITE}_VEC). Emitted first, in its own
    // section; the level image references it only via vpy_load_level's 2nd arg.
    s.push_str(&format!("@ --- {sym}_level_sprites (libvpy sprite-index table) ---\n"));
    s.push_str(&format!(".section .rodata._{sym}_LEVEL_SPRITES,\"a\",%progbits\n"));
    s.push_str("    .balign 4\n");
    s.push_str(&format!(".global _{sym}_level_sprites\n_{sym}_level_sprites:\n"));
    if sprite_names.is_empty() {
        s.push_str("    .word 0\n");
    } else {
        for sp in &sprite_names {
            let ssym = sp.to_uppercase().replace('-', "_").replace(' ', "_");
            s.push_str(&format!("    .word _{ssym}_VEC\n"));
        }
    }
    // Position-independent level byte image.
    s.push_str(&format!("@ --- {sym}_LEVEL_C (libvpy position-independent level image) ---\n"));
    s.push_str(&format!(".section .rodata._{sym}_LEVEL_C,\"a\",%progbits\n"));
    s.push_str("    .balign 4\n");
    s.push_str(&format!(".global _{sym}_LEVEL_C\n_{sym}_LEVEL_C:\n"));
    for chunk in bytes.chunks(16) {
        let vals: Vec<String> = chunk.iter().map(|b| format!("0x{b:02X}")).collect();
        s.push_str(&format!("    .byte   {}\n", vals.join(", ")));
    }
    s.push_str(".section .text\n\n");
    s
}

/// Serialize a `VecResource` into the position-independent C byte image
/// documented on `compile_vec_file_to_bytes`. `override_center` mirrors
/// `emit_vec_resource`: vanim/venemy group members share a group center so the
/// `_NAME_VEC` image centers identically to the inline `_NAME_VECTORS` (else a
/// grouped sprite drawn via DRAW_VECTOR would shift vs the inline path).
fn vec_resource_to_bytes(res: &VecResource, override_center: Option<(i16, i16)>) -> Vec<u8> {
    let (center_x, center_y) = override_center.unwrap_or_else(|| res.calculate_center());

    let paths: Vec<_> = res.visible_paths()
        .into_iter()
        .filter(|p| p.points.len() >= 2)
        .collect();

    let mut out: Vec<u8> = Vec::new();
    out.extend_from_slice(&(paths.len() as u16).to_le_bytes());

    if paths.is_empty() {
        out.push(0x02); // end marker (empty asset)
        return out;
    }

    let clamp8 = |v: i16| v.clamp(-127, 127) as i8 as u8;

    for path in &paths {
        // Bezier paths: emit 0xFE cubic segments (center-relative control pts),
        // mirroring emit_vec_resource. The C runtime tessellates them.
        if path.path_type.as_deref() == Some("bezier") {
            let pts = &path.points;
            if pts.len() < 4 {
                out.push(0x02); // degenerate bezier
                continue;
            }
            out.push(path.intensity);
            out.push(clamp8(pts[0].y - center_y)); // y0
            out.push(clamp8(pts[0].x - center_x)); // x0
            out.push(0x00);
            out.push(0x00);
            let mut i = 0;
            while i + 3 < pts.len() {
                out.push(0xFE);
                out.push(clamp8(pts[i    ].x - center_x)); // ax
                out.push(clamp8(pts[i    ].y - center_y)); // ay
                out.push(clamp8(pts[i + 1].x - center_x)); // c1x
                out.push(clamp8(pts[i + 1].y - center_y)); // c1y
                out.push(clamp8(pts[i + 2].x - center_x)); // c2x
                out.push(clamp8(pts[i + 2].y - center_y)); // c2y
                out.push(clamp8(pts[i + 3].x - center_x)); // bx
                out.push(clamp8(pts[i + 3].y - center_y)); // by
                i += 3;
            }
            out.push(0x02);
            continue;
        }

        // Polyline path: bake points to 0xFF delta segments.
        let baked: Vec<(i16, i16)> = path.points.iter().map(|p| (p.x, p.y)).collect();
        let (x0_raw, y0_raw) = baked[0];
        out.push(path.intensity);
        out.push(clamp8(y0_raw - center_y)); // y0
        out.push(clamp8(x0_raw - center_x)); // x0
        out.push(0x00);
        out.push(0x00);

        for j in 0..baked.len() - 1 {
            let (fx, fy) = baked[j];
            let (tx, ty) = baked[j + 1];
            for (sub_dy, sub_dx) in split_segment_pairs(tx - fx, ty - fy) {
                out.push(0xFF);
                out.push(sub_dy as u8);
                out.push(sub_dx as u8);
            }
        }

        if path.closed && baked.len() > 2 {
            let (fx, fy) = baked[baked.len() - 1];
            let (tx, ty) = baked[0];
            for (sub_dy, sub_dx) in split_segment_pairs(tx - fx, ty - fy) {
                out.push(0xFF);
                out.push(sub_dy as u8);
                out.push(sub_dx as u8);
            }
        }

        out.push(0x02);
    }

    out
}

fn emit_3d_resource(res: &VecResource, override_name: &str) -> String {
    let mut s = String::new();
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");

    let visible = res.visible_paths();
    s.push_str(&format!("@ --- {sym}_3D_DATA ({} path(s)) ---\n", visible.len()));
    // The runtime reads vertex_count and path_count with `ldr` (4-byte load),
    // so the symbol must be 4-byte aligned. Without this the symbol lands at
    // whatever offset the previous .byte stream finished at — unaligned ldr
    // on ARMv6 (Pi Zero) traps or returns rotated bytes.
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

    // Align before .word path_count — see arm/assets.rs for the same rationale.
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

/// Split a delta segment into <=127-unit steps, returning the (dy, dx) i8 pairs
/// that follow each `0xFF` line marker. This is the SINGLE geometry source used
/// by BOTH the ARM `.byte` emitter (`emit_split_segment_arm`) and the raw
/// byte-image emitter (`vec_resource_to_bytes`) behind the C runtime, so the two
/// views stay byte-identical.
fn split_segment_pairs(dx: i16, dy: i16) -> Vec<(i8, i8)> {
    let n = {
        let max_d = dx.abs().max(dy.abs()) as usize;
        if max_d == 0 { return Vec::new(); }
        (max_d + 126) / 127
    };

    let mut rem_dx = dx;
    let mut rem_dy = dy;
    let mut out = Vec::with_capacity(n);
    for step in 0..n {
        let steps_left = (n - step) as i16;
        let sub_dx = rem_dx / steps_left;
        let sub_dy = rem_dy / steps_left;
        rem_dx -= sub_dx;
        rem_dy -= sub_dy;
        out.push((sub_dy as i8, sub_dx as i8));
    }
    out
}

fn emit_split_segment_arm(s: &mut String, dx: i16, dy: i16) {
    for (sub_dy, sub_dx) in split_segment_pairs(dx, dy) {
        s.push_str(&format!(
            "    .byte   0xFF, 0x{:02X}, 0x{:02X}  @ line dy={}, dx={}\n",
            sub_dy as u8, sub_dx as u8, sub_dy, sub_dx
        ));
    }
}

// ============================================================
// Animation asset emitter (ARM-specific format)
// ============================================================
//
// ARM vanim format uses 4-byte word pointers (not M6809 FDB 16-bit).
// Header layout:
//   byte 0: frame_count
//   byte 1: loop_flag
//   byte 2: base_ref_count
//   byte 3: frame_table_offset = 4 + base_ref_count*4
//   words [4 .. 4+base_ref_count*4]: ARM ptrs to base_ref vec data
//   words [frame_table_offset ..]: ARM ptrs to per-frame data
// Frame layout:
//   byte 0: duration_ticks
//   byte 1: vec_ref_count
//   words [2 .. 2+vec_ref_count*4]: ARM ptrs to vec data
//   byte after vec_refs: inline_path_count (0 = no inline paths on pitrex)

fn compile_vanim_for_arm(resource: &VanimResource, asset_name: &str) -> String {
    let sym = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let mut s = String::new();

    // Convert inline paths to synthetic vec assets so they go through the
    // standard vec_refs render path (same code as named .vec references).
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
    // Each base_ref pointer is 4 bytes on ARM
    let frame_table_offset = 4 + base_ref_count * 4;

    s.push_str(&format!("@ --- Animation: {} ({} frames, {} base_refs) ---\n",
        asset_name, frame_count, base_ref_count));
    s.push_str(".balign 4\n");
    s.push_str(&format!(".global _ANIM_{sym}\n"));
    s.push_str(&format!("_ANIM_{sym}:\n"));
    s.push_str(&format!("    .byte {}, {}, {}, {}  @ frame_count, loop, base_ref_count, frame_table_offset\n",
        frame_count, loop_flag, base_ref_count, frame_table_offset));

    // Base_ref ARM pointers
    for base_ref in &resource.base_refs {
        let bsym = base_ref.to_uppercase().replace('-', "_").replace(' ', "_");
        s.push_str(&format!("    .word _{bsym}_VECTORS  @ base_ref '{base_ref}'\n"));
    }

    // Frame table ARM pointers
    for frame in &resource.frames {
        s.push_str(&format!("    .word _ANIM_{sym}_F{}  @ frame {}\n", frame.index, frame.index));
    }

    // Frame data blocks
    for frame in &resource.frames {
        let vec_ref_count = frame.vec_refs.len();
        s.push_str(&format!(".balign 4\n"));
        s.push_str(&format!("_ANIM_{sym}_F{}:\n", frame.index));
        s.push_str(&format!("    .byte {}, {}  @ duration_ticks, vec_ref_count\n",
            frame.duration_ticks, vec_ref_count));
        // Padding to align word pointers (2 bytes header → 2 bytes pad)
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

// ============================================================
// Enemy per-type DATA table (.venemy → ARM)
// ============================================================
//
// FNV-1a hash truncated to 8 bits — must match the hash in pitrex/expressions.rs
fn fnv1a_u8(s: &str) -> u8 {
    let mut h: u32 = 2166136261;
    for b in s.bytes() { h = h.wrapping_mul(16777619) ^ (b as u32); }
    (h & 0xFF) as u8
}

/// Compute the per-enemy-type feet_offset baked into _DATA[209]. Scans the
/// global vec min_y map for entries matching the enemy's name (either the
/// plain lowercase name, e.g. "titchi", or anything with the "{name}_"
/// prefix like "titchi_idle", "titchi_walk1", "titchi_ball"). The smallest
/// min_y across those sprites becomes the conservative feet anchor:
///   feet_offset = -min_y
/// pool.y = area.y + feet_offset places the sprite's lowest pixel exactly on
/// area.y — so area.y can mean the platform top regardless of which sprite
/// the enemy is currently showing. Matches the ARM/rp2350 convention.
fn compute_enemy_feet_offset(res: &EnemyResource, vec_min_y: &HashMap<String, i16>) -> i8 {
    let plain = res.name.to_lowercase();
    let prefix = format!("{}_", plain);
    let mut acc: Option<i16> = None;
    for (name, &my) in vec_min_y {
        if name == &plain || name.starts_with(&prefix) {
            acc = Some(acc.map_or(my, |a| a.min(my)));
        }
    }
    match acc {
        Some(my) => (-my).clamp(-127, 127) as i8,
        None => 0,
    }
}

// Emits `_<NAME>_DATA` — variable-size table read by the runtime enemy system.
//
// Layout (.balign 4):
//   [0 ..31]  8 × .word  — sprite_ptr for state 0..7 (0 if no such state)
//   [32..39]  8 × .byte  — is_anim flag for state 0..7 (0=vec 1=vanim)
//   [40]      .byte      — state_count
//   [41..43]  .byte[3]   — pad
//   [44..203] Event table: 8 × 20-byte per-state blocks
//               Per block: .byte event_count, .byte[3] pad
//                          up to 4 × (.byte hash, .byte target_state, .byte[2] pad)
//             Runtime: ENEMY_FIRE_EVENT reads block at offset 44 + sm_state*20
//   [204..207] .word     — idle_sprite_ptr (wander IDLE swap target; 0 if none)
//   [208]      .byte     — idle_is_anim
//   [209]      .byte     — feet_offset (signed: pool.y = area.y + feet_offset)
//   [210..211] .byte[2]  — pad
fn emit_enemy_data_for_pitrex(
    res: &EnemyResource,
    name_up: &str,
    vec_min_y: &HashMap<String, i16>,
) -> String {
    const MAX_STATES: usize = 8;
    const MAX_EVENTS: usize = 4;

    let mut sprite_ptrs: Vec<String> = vec!["0".to_string(); MAX_STATES];
    let mut is_anims: Vec<u8> = vec![0u8; MAX_STATES];
    let mut state_count: u8 = 0;
    // event_table[state_idx] = Vec of (hash, target_state)
    let mut event_table: Vec<Vec<(u8, u8)>> = vec![vec![]; MAX_STATES];

    // Resolve a sprite path to its emitted label + is_anim flag.
    let resolve_sprite = |sprite_path: &str| -> Option<(String, u8)> {
        if sprite_path.is_empty() { return None; }
        let path = Path::new(sprite_path);
        let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
        let stem = path.file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_uppercase()
            .replace('-', "_")
            .replace(' ', "_");
        match ext {
            "vec"   => Some((format!("_{}_VECTORS", stem), 0u8)),
            "vanim" => Some((format!("_ANIM_{}", stem), 1u8)),
            _       => None,
        }
    };

    if let Some(sm) = &res.state_machine {
        state_count = sm.states.len().min(MAX_STATES) as u8;

        for (i, state) in sm.states.iter().take(MAX_STATES).enumerate() {
            // Resolve sprite for this state
            let action = res.actions.iter().find(|a| a.name == state.action);
            if let Some(action) = action {
                if let Some((label, is_anim)) = resolve_sprite(&action.sprite) {
                    sprite_ptrs[i] = label;
                    is_anims[i] = is_anim;
                }
            }
            // Resolve event transitions
            for trans in state.on_event.iter().take(MAX_EVENTS) {
                let hash = fnv1a_u8(&trans.event);
                let target = sm.states.iter().position(|s| s.name == trans.to)
                    .map(|p| p as u8).unwrap_or(0);
                event_table[i].push((hash, target));
            }
        }
    }

    // Resolve the "idle" action's sprite (used by wander IDLE sub-state to
    // visually halt motion). 0 if no action named "idle" exists.
    let (idle_sprite, idle_is_anim) = res.actions.iter()
        .find(|a| a.name == "idle")
        .and_then(|a| resolve_sprite(&a.sprite))
        .unwrap_or_else(|| ("0".to_string(), 0u8));

    let mut s = String::new();
    s.push_str(&format!("@ ---- Enemy DATA (state→sprite+event table): {} ----\n", name_up));
    s.push_str(&format!(".global _{name_up}_DATA\n"));
    s.push_str(".balign 4\n");
    s.push_str(&format!("_{name_up}_DATA:\n"));

    // 8 × sprite_ptr
    for i in 0..MAX_STATES {
        s.push_str(&format!("    .word {}    @ state {} sprite_ptr\n", sprite_ptrs[i], i));
    }
    // 8 × is_anim
    for i in 0..MAX_STATES {
        s.push_str(&format!("    .byte {}    @ state {} is_anim\n", is_anims[i], i));
    }
    // state_count + 3 pad  (offset 40..43)
    s.push_str(&format!("    .byte {}    @ state_count\n", state_count));
    s.push_str("    .byte 0, 0, 0    @ pad\n");

    // Event table: MAX_STATES × 20 bytes each (offset 44..203)
    for i in 0..MAX_STATES {
        let events = &event_table[i];
        s.push_str(&format!("    @ state {} events ({} transitions)\n", i, events.len()));
        s.push_str(&format!("    .byte {}    @ event_count\n", events.len()));
        s.push_str("    .byte 0, 0, 0    @ pad\n");
        for &(hash, target) in events.iter() {
            s.push_str(&format!("    .byte 0x{hash:02X}  @ event hash (FNV-1a)\n"));
            s.push_str(&format!("    .byte {}         @ target_state\n", target));
            s.push_str("    .byte 0, 0     @ pad\n");
        }
        // Pad remaining event slots to MAX_EVENTS
        for _ in events.len()..MAX_EVENTS {
            s.push_str("    .byte 0, 0, 0, 0   @ empty event slot\n");
        }
    }

    // Wander IDLE sprite (offset 204..211)
    s.push_str(&format!("    .word {}    @ idle_sprite_ptr (wander IDLE swap)\n", idle_sprite));
    s.push_str(&format!("    .byte {}    @ idle_is_anim\n", idle_is_anim));
    // feet_offset = -min_y across every .vec sprite referenced by this enemy
    // (idle / walk / state variants — for vanim, pull the first frame's
    // vec_ref). Applied at spawn and at wander airborne-landing so area.y
    // can represent the platform top surface. Matches ARM/rp2350 convention.
    let feet_off = compute_enemy_feet_offset(res, vec_min_y);
    s.push_str(&format!("    .byte {}    @ feet_offset (signed)\n", feet_off));
    s.push_str("    .byte 0, 0    @ pad\n");

    s.push('\n');
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    const VREC_JSON: &str = r#"{
        "version": "1.0",
        "name": "preview",
        "fps": 12,
        "frames": [
            { "segments": [
                { "x0": -50, "y0": 10, "x1": 30, "y1": 20, "i": 95 },
                { "x0": 200, "y0": -200, "x1": 0, "y1": 0, "i": 300 },
                { "x0": 1, "y0": 2, "x1": 3, "y1": 4, "i": 50 }
            ] },
            { "segments": [
                { "x0": 0, "y0": 0, "x1": 10, "y1": 10, "i": 1 },
                { "x0": 5, "y0": 5, "x1": -5, "y1": -5, "i": 1 }
            ] }
        ]
    }"#;

    /// The PiTrex .vrec table must be byte-for-byte identical to the rp2350
    /// backend's layout (frame_count word, label-difference offsets, 5-byte
    /// segments) so the same tools/video2vrec output works across targets.
    #[test]
    fn test_compile_vrec_table_layout() {
        let vrec: VrecResource = serde_json::from_str(VREC_JSON).unwrap();
        let asm = compile_vrec(&vrec, "preview");

        assert!(asm.contains(".global _PREVIEW_VREC"), "missing global symbol:\n{asm}");
        assert!(asm.contains("_PREVIEW_VREC:\n    .word   2               @ frame_count"),
            "missing frame_count word:\n{asm}");
        assert!(asm.contains(".word   _PREVIEW_VREC_F0 - _PREVIEW_VREC"),
            "missing frame 0 offset:\n{asm}");
        assert!(asm.contains(".word   _PREVIEW_VREC_F1 - _PREVIEW_VREC"),
            "missing frame 1 offset:\n{asm}");
        // Chained: frame 0's 3 disjoint segments → 3 chains; frame 1's 2 → 2 chains.
        assert!(asm.contains("_PREVIEW_VREC_F0:\n    .hword  3"),
            "frame 0 must have 3 chains:\n{asm}");
        assert!(asm.contains("_PREVIEW_VREC_F1:\n    .hword  2"),
            "frame 1 must have 2 chains:\n{asm}");
        // Chain 0 header: start=(-50,10)=(0xCE,0x0A), i=95=0x5F, seg_count=1.
        assert!(asm.contains(".byte   0xCE, 0x0A, 0x5F, 0x01"),
            "chain 0 header bytes wrong:\n{asm}");
        // Chain 0 delta: (30-(-50), 20-10) = (80,10) = (0x50,0x0A).
        assert!(asm.contains(".byte   0x50, 0x0A"),
            "chain 0 delta wrong:\n{asm}");
        // Chain 1 header clamped: 200→127(0x7F), -200→-127(0x81), i 300→127(0x7F), seg_count 1.
        assert!(asm.contains(".byte   0x7F, 0x81, 0x7F, 0x01"),
            "chain 1 clamped header wrong:\n{asm}");
        // Chain 1 delta clamped: (0-200, 0-(-200)) = (-200,200) → (-127,127) = (0x81,0x7F).
        assert!(asm.contains(".byte   0x81, 0x7F"),
            "chain 1 clamped delta wrong:\n{asm}");
    }
}
