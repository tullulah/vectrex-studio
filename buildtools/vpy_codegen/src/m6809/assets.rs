//! Asset discovery and generation
//! Handles .vec, .vmus, .vlevel, and .vsfx resources

use std::path::{Path, PathBuf};
use std::fs;
use std::collections::{HashSet, HashMap};
use crate::{AssetInfo, AssetType};
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

    // Collect enemy types referenced in used .vplay files
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
                                if let Some(et) = obj
                                    .get("enemyType")
                                    .and_then(|v| v.as_str())
                                {
                                    if !et.is_empty() {
                                        used_names.insert(et.to_string());
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Also scan .venemy files for their action sprite names so those sprites are included
    // in vector_entries and thus get a valid index in vec_idx_map.
    let enemy_asset_names: Vec<(String, String)> = assets.iter()
        .filter(|a| matches!(a.asset_type, AssetType::Enemy))
        .map(|a| (a.name.clone(), a.path.clone()))
        .collect();
    for (_, enemy_path) in &enemy_asset_names {
        if let Ok(resource) = crate::venemy::EnemyResource::load(std::path::Path::new(enemy_path)) {
            for action in &resource.actions {
                let stem = std::path::Path::new(&action.sprite)
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .unwrap_or("")
                    .to_string();
                if !stem.is_empty() {
                    used_names.insert(stem);
                }
            }
        }
    }
    // Second pass: scan any newly added .vanim files for their vec_refs
    let new_anim_names: Vec<String> = used_names.iter()
        .filter(|n| assets.iter().any(|a| matches!(a.asset_type, AssetType::Animation) && &a.name == *n))
        .cloned()
        .collect();
    for anim_name in &new_anim_names {
        if let Some(anim_asset) = assets.iter().find(|a| matches!(a.asset_type, AssetType::Animation) && &a.name == anim_name) {
            collect_vanim_vec_refs(&anim_asset.path, &mut used_names);
        }
    }

    // Filter assets to only those referenced in code (or used by levels)
    // Enemy assets are always included: they're loaded dynamically via SPAWN_ENEMIES
    // and referenced through level data at runtime, not by name in VPy source.
    assets.iter()
        .filter(|asset| {
            matches!(asset.asset_type, AssetType::Enemy) || used_names.contains(&asset.name)
        })
        .cloned()
        .collect()
}

/// Scan a .vplay JSON file and add the vectorName of every object to used_names.
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

/// Collect all vector names referenced by any Animation asset in `assets`.
/// These vectors are embedded inline in vanim data and are NOT in VECTOR_ADDR_TABLE.
/// Used by builtins.rs to mirror the exact VECTOR_ADDR_TABLE filter logic.
pub fn collect_anim_vec_refs(assets: &[crate::AssetInfo]) -> HashSet<String> {
    let mut refs = HashSet::new();
    for asset in assets.iter().filter(|a| matches!(a.asset_type, crate::AssetType::Animation)) {
        collect_vanim_vec_refs(&asset.path, &mut refs);
    }
    refs
}

/// Scan a .vanim JSON file and add all vec_refs (base_refs + per-frame) to used_names.
fn collect_vanim_vec_refs(vanim_path: &str, used_names: &mut HashSet<String>) {
    let Ok(resource) = crate::animres::VanimResource::load(Path::new(vanim_path)) else { return };
    // Static cel layer — referenced on every frame
    for vec_name in &resource.base_refs {
        used_names.insert(vec_name.clone());
    }
    // Per-frame additional refs
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
            if let Some(step_expr) = step {
                collect_asset_names_from_expr(step_expr, used_names);
            }
            for s in body {
                collect_asset_names_from_stmt(s, used_names);
            }
        }
        Stmt::ForIn { iterable, body, .. } => {
            collect_asset_names_from_expr(iterable, used_names);
            for s in body {
                collect_asset_names_from_stmt(s, used_names);
            }
        }
        Stmt::Assign { value, .. } | Stmt::Let { value, .. } => {
            collect_asset_names_from_expr(value, used_names);
        }
        _ => {}
    }
}

/// Collect asset names from expressions (DRAW_VECTOR("name"), PLAY_MUSIC("name"), etc.)
fn collect_asset_names_from_expr(expr: &Expr, used_names: &mut HashSet<String>) {
    match expr {
        Expr::Call(vpy_parser::CallInfo { name, args, .. }) => {
            // Check if it's an asset-loading builtin
            let up = name.to_uppercase();
            if up == "DRAW_VECTOR" || up == "DRAW_VECTOR_EX" || up == "DRAW_VECTOR_3D" ||
               up == "PLAY_MUSIC" || up == "PLAY_SFX" || up == "LOAD_LEVEL" ||
               up == "DRAW_ANIM" || up == "PLAY_NOTE" || up == "DRAW_RECORDING" {
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

/// Discover all assets in a project
/// 
/// Searches for:
/// - assets/vectors/*.vec (vector graphics)
/// - assets/music/*.vmus (music)
/// - assets/levels/*.vlevel (level data)
/// - assets/sfx/*.vsfx (sound effects)
pub fn discover_assets(source_path: &Path) -> Vec<AssetInfo> {
    let mut assets = Vec::new();
    
    // Determine project root - convert to absolute path first to avoid cwd confusion
    let abs_source = source_path.canonicalize().unwrap_or_else(|_| source_path.to_path_buf());
    
    let project_root: PathBuf = if let Some(parent) = abs_source.parent() {
        if parent.file_name().and_then(|n| n.to_str()) == Some("src") {
            // Source is in src/ directory, project root is parent
            parent.parent().unwrap_or(parent).to_path_buf()
        } else {
            // Source is not in src/, assume parent is project root
            parent.to_path_buf()
        }
    } else {
        // No parent (shouldn't happen with absolute path), use source itself
        abs_source.clone()
    };
    
    // Search for vector assets (assets/vectors/*.vec)
    let vectors_dir = project_root.join("assets").join("vectors");
    if vectors_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(&vectors_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) == Some("vec") {
                    if let Some(name) = path.file_stem().and_then(|n| n.to_str()) {
                        assets.push(AssetInfo {
                            name: name.to_string(),
                            path: path.display().to_string(),
                            asset_type: AssetType::Vector,
                        });
                    }
                }
            }
        }
    }
    
    // Search for music assets (assets/music/*.vmus)
    let music_dir = project_root.join("assets").join("music");
    if music_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(&music_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) == Some("vmus") {
                    if let Some(name) = path.file_stem().and_then(|n| n.to_str()) {
                        assets.push(AssetInfo {
                            name: name.to_string(),
                            path: path.display().to_string(),
                            asset_type: AssetType::Music,
                        });
                    }
                }
            }
        }
    }
    
    // Search for level assets (.vplay in any assets/ subdirectory, .vlevel in assets/levels/)
    let assets_dir = project_root.join("assets");
    let mut seen_levels: HashSet<String> = HashSet::new();
    if assets_dir.is_dir() {
        if let Ok(subdirs) = fs::read_dir(&assets_dir) {
            for subdir in subdirs.flatten() {
                let subdir_path = subdir.path();
                if !subdir_path.is_dir() { continue; }
                if let Ok(entries) = fs::read_dir(&subdir_path) {
                    for entry in entries.flatten() {
                        let path = entry.path();
                        let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
                        if ext == "vplay" || ext == "vlevel" {
                            if let Some(name) = path.file_stem().and_then(|n| n.to_str()) {
                                if seen_levels.insert(name.to_string()) {
                                    assets.push(AssetInfo {
                                        name: name.to_string(),
                                        path: path.display().to_string(),
                                        asset_type: AssetType::Level,
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Search for SFX assets (assets/sfx/*.vsfx)
    let sfx_dir = project_root.join("assets").join("sfx");
    if sfx_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(&sfx_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) == Some("vsfx") {
                    if let Some(name) = path.file_stem().and_then(|n| n.to_str()) {
                        assets.push(AssetInfo {
                            name: name.to_string(),
                            path: path.display().to_string(),
                            asset_type: AssetType::Sfx,
                        });
                    }
                }
            }
        }
    }

    // Search for animation assets (assets/animations/*.vanim)
    let anim_dir = project_root.join("assets").join("animations");
    if anim_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(&anim_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) == Some("vanim") {
                    if let Some(name) = path.file_stem().and_then(|n| n.to_str()) {
                        assets.push(AssetInfo {
                            name: name.to_string(),
                            path: path.display().to_string(),
                            asset_type: AssetType::Animation,
                        });
                    }
                }
            }
        }
    }

    // Search for instrument assets (assets/instruments/*.vinstr)
    let instr_dir = project_root.join("assets").join("instruments");
    if instr_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(&instr_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) == Some("vinstr") {
                    if let Some(name) = path.file_stem().and_then(|n| n.to_str()) {
                        assets.push(AssetInfo {
                            name: name.to_string(),
                            path: path.display().to_string(),
                            asset_type: AssetType::Instrument,
                        });
                    }
                }
            }
        }
    }

    // Search for recording assets (assets/recordings/*.vrec)
    // Playback is ARM-only (rp2350/uvm2); on m6809/pitrex these are discovered
    // but never referenced (DRAW_RECORDING is not collected there), so they are
    // dropped by filter_used_assets.
    let rec_dir = project_root.join("assets").join("recordings");
    if rec_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(&rec_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) == Some("vrec") {
                    if let Some(name) = path.file_stem().and_then(|n| n.to_str()) {
                        assets.push(AssetInfo {
                            name: name.to_string(),
                            path: path.display().to_string(),
                            asset_type: AssetType::Recording,
                        });
                    }
                }
            }
        }
    }

    // Search for audio-sample assets (assets/samples/*.vsmp)
    // Playback is ARM-only (rp2350/uvm2); on m6809/pitrex these are discovered
    // but never referenced (PLAY_SAMPLE is not collected there), so they are
    // dropped by filter_used_assets.
    let smp_dir = project_root.join("assets").join("samples");
    if smp_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(&smp_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) == Some("vsmp") {
                    if let Some(name) = path.file_stem().and_then(|n| n.to_str()) {
                        assets.push(AssetInfo {
                            name: name.to_string(),
                            path: path.display().to_string(),
                            asset_type: AssetType::Sample,
                        });
                    }
                }
            }
        }
    }

    // Search for enemy assets (assets/enemies/*.venemy)
    let enemies_dir = project_root.join("assets").join("enemies");
    if enemies_dir.is_dir() {
        for entry in fs::read_dir(&enemies_dir).into_iter().flatten().flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) == Some("venemy") {
                if let Some(name) = path.file_stem().and_then(|n| n.to_str()) {
                    assets.push(AssetInfo {
                        name: name.to_string(),
                        path: path.display().to_string(),
                        asset_type: AssetType::Enemy,
                    });
                }
            }
        }
    }

    // Sort assets alphabetically by name for consistency
    assets.sort_by(|a, b| a.name.cmp(&b.name));
    assets
}

/// Asset with calculated size for bin-packing
#[derive(Debug, Clone)]
pub struct SizedAsset {
    pub info: AssetInfo,
    pub binary_size: usize,
    pub asm_code: String,
}

/// Asset distribution result for multi-bank support
#[derive(Debug, Clone)]
pub struct AssetDistribution {
    /// Assets assigned to each bank (bank_id -> list of assets)
    pub bank_assignments: std::collections::HashMap<u8, Vec<SizedAsset>>,
    /// Total assets distributed
    pub total_assets: usize,
    /// Total bytes distributed
    pub total_bytes: usize,
}

/// Build a map of vec asset name → (half_width, half_height) from already-generated vec ASM.
/// Used to emit literal byte values in level objects instead of cross-bank EQU references.
fn build_vec_dims(vec_assets: &[SizedAsset]) -> HashMap<String, (u32, u32)> {
    let mut dims: HashMap<String, (u32, u32)> = HashMap::new();
    for sa in vec_assets {
        let name_up = sa.info.name.to_uppercase().replace('-', "_").replace(' ', "_");
        let hw_marker = format!("_{}_HALF_WIDTH EQU ", name_up);
        let hh_marker = format!("_{}_HALF_HEIGHT EQU ", name_up);
        let mut hw = 0u32;
        let mut hh = 0u32;
        for line in sa.asm_code.lines() {
            let t = line.trim();
            if let Some(rest) = t.strip_prefix(&hw_marker) {
                hw = rest.trim().parse().unwrap_or(0);
            } else if let Some(rest) = t.strip_prefix(&hh_marker) {
                hh = rest.trim().parse().unwrap_or(0);
            }
        }
        if hw > 0 || hh > 0 {
            dims.insert(sa.info.name.to_lowercase(), (hw, hh));
        }
    }
    dims
}

/// Calculate sizes and generate ASM for all assets
pub fn prepare_assets_with_sizes(assets: &[AssetInfo]) -> Vec<SizedAsset> {
    let mut sized_assets = Vec::new();
    
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Vector)) {
        match crate::vecres::VecResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                let asm_code = resource.compile_to_asm_with_name(Some(&asset.name));
                let binary_size = estimate_asm_size(&asm_code);
                sized_assets.push(SizedAsset {
                    info: asset.clone(),
                    binary_size,
                    asm_code,
                });
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load vector asset '{}': {}", asset.name, e);
            }
        }
    }
    
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Music)) {
        match crate::musres::MusicResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                let asm_code = resource.compile_to_asm(&asset.name);
                // Estimate music size: count FCB/FDB bytes in ASM (rough approximation)
                let binary_size = estimate_asm_size(&asm_code);
                sized_assets.push(SizedAsset {
                    info: asset.clone(),
                    binary_size,
                    asm_code,
                });
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load music asset '{}': {}", asset.name, e);
            }
        }
    }
    
    let vec_dims = build_vec_dims(&sized_assets.iter()
        .filter(|a| matches!(a.info.asset_type, AssetType::Vector))
        .cloned()
        .collect::<Vec<_>>());

    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Level)) {
        match crate::levelres::VPlayLevel::load(Path::new(&asset.path)) {
            Ok(resource) => {
                let asm_code = resource.compile_to_asm_with_vec_dims(&vec_dims);
                let binary_size = estimate_asm_size(&asm_code);
                sized_assets.push(SizedAsset {
                    info: asset.clone(),
                    binary_size,
                    asm_code,
                });
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load level asset '{}': {}", asset.name, e);
            }
        }
    }

    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Sfx)) {
        match crate::sfxres::SfxResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                let asm_code = resource.compile_to_asm_with_name(Some(&asset.name));
                let binary_size = estimate_asm_size(&asm_code);
                sized_assets.push(SizedAsset {
                    info: asset.clone(),
                    binary_size,
                    asm_code,
                });
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load SFX asset '{}': {}", asset.name, e);
            }
        }
    }

    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Animation)) {
        match crate::animres::VanimResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                let binary_size = resource.estimate_binary_size();
                let asm_code = crate::animres::compile_vanim_to_asm(&resource, &asset.name);
                sized_assets.push(SizedAsset {
                    info: asset.clone(),
                    binary_size,
                    asm_code,
                });
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load animation asset '{}': {}", asset.name, e);
            }
        }
    }

    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Instrument)) {
        match crate::instrres::InstrResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                let asm_code = resource.compile_to_asm_with_name(Some(&asset.name));
                let binary_size = 16; // Always 16 bytes (fixed-size block)
                sized_assets.push(SizedAsset {
                    info: asset.clone(),
                    binary_size,
                    asm_code,
                });
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load instrument asset '{}': {}", asset.name, e);
            }
        }
    }

    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Enemy)) {
        match crate::venemy::EnemyResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                let binary_size = resource.estimate_binary_size();
                let asm_code = resource.compile_to_asm_with_name(Some(&asset.name));
                sized_assets.push(SizedAsset {
                    info: asset.clone(),
                    binary_size,
                    asm_code,
                });
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load enemy asset '{}': {}", asset.name, e);
            }
        }
    }

    // Sort by size descending (best for bin-packing)
    sized_assets.sort_by(|a, b| b.binary_size.cmp(&a.binary_size));

    sized_assets
}

/// Estimate binary size from ASM code (rough approximation)
fn estimate_asm_size(asm: &str) -> usize {
    let mut size = 0;
    for line in asm.lines() {
        let trimmed = line.trim().to_uppercase();
        if trimmed.starts_with("FCB ") {
            // Count comma-separated values
            let values = trimmed[4..].split(',').count();
            size += values;
        } else if trimmed.starts_with("FDB ") {
            // Each FDB is 2 bytes per value
            let values = trimmed[4..].split(',').count();
            size += values * 2;
        } else if trimmed.starts_with("FCC ") {
            // String length (approximate)
            if let Some(start) = trimmed.find('"') {
                if let Some(end) = trimmed.rfind('"') {
                    size += end - start - 1;
                }
            }
        }
    }
    size
}

/// Distribute assets across banks using First-Fit Decreasing bin-packing
/// 
/// CRITICAL (2026-01-20): ALL assets MUST go to Bank #31 (fixed bank)
/// This ensures they're accessible from any bank without cross-bank references
/// Bank #31 is always visible at $4000-$7FFF (fixed window)
/// 
/// Parameters:
/// - assets: List of assets to distribute
/// - bank_size: Maximum bytes per bank (default 16384 = 16KB)
/// - start_bank: IGNORED - all assets go to Bank #31
/// - max_banks: IGNORED - all assets go to Bank #31
/// 
/// Returns AssetDistribution with all assets in Bank #31
pub fn distribute_assets(
    assets: &[AssetInfo],
    bank_size: usize,
    start_bank: u8,
    max_banks: u8,
    pre_used_bytes: &HashMap<u8, usize>,
) -> AssetDistribution {
    use std::collections::HashMap;
    
    let sized_assets = prepare_assets_with_sizes(assets);
    let mut bank_assignments: HashMap<u8, Vec<SizedAsset>> = HashMap::new();
    // Seed bank_sizes with function code already assigned to each bank.
    let mut bank_sizes: HashMap<u8, usize> = pre_used_bytes.clone();
    
    // CRITICAL FIX (2026-01-20): Assets go to Banks #1-#30 (switchable window)
    // Bank #0 = main code + LOOP
    // Banks #1-#30 = overflow code + ASSETS (16KB each, switchable at $0000-$3FFF)
    // Bank #31 = helpers + lookup tables ONLY (fixed at $4000-$7FFF, no assets!)
    //
    // Why NOT Bank #31:
    //   - Bank #31 only has 16KB but must fit all helpers (~3-5KB)
    //   - Assets can be 50KB+ total (need multiple banks)
    //   - Bank switching allows access to any asset from any code
    
    let helper_bank_id = max_banks.saturating_sub(1).max(31);
    let first_asset_bank = start_bank.max(1); // Start at Bank #1 minimum
    let last_asset_bank = helper_bank_id.saturating_sub(1); // End at Bank #30 (before helpers)
    
    let total_assets = sized_assets.len();
    let total_bytes: usize = sized_assets.iter().map(|a| a.binary_size).sum();
    
    // First-Fit Decreasing bin packing: larger assets first.
    // Secondary key: asset name for deterministic ordering when sizes are equal.
    let mut sorted_assets = sized_assets;
    sorted_assets.sort_by(|a, b| {
        b.binary_size.cmp(&a.binary_size)
            .then_with(|| a.info.name.cmp(&b.info.name))
    });
    
    for asset in sorted_assets {
        // Find a bank with enough space
        let mut assigned = false;
        
        for bank_id in first_asset_bank..=last_asset_bank {
            let current_size = *bank_sizes.get(&bank_id).unwrap_or(&0);
            if current_size + asset.binary_size <= bank_size {
                bank_assignments.entry(bank_id).or_insert_with(Vec::new).push(asset.clone());
                bank_sizes.insert(bank_id, current_size + asset.binary_size);
                assigned = true;
                break;
            }
        }
        
        if !assigned {
            // All banks full - this is a FATAL error
            panic!("FATAL: Cannot fit asset '{}' ({} bytes) - all banks #{}-#{} are full!", 
                asset.info.name, asset.binary_size, first_asset_bank, last_asset_bank);
        }
    }
    
    AssetDistribution {
        bank_assignments,
        total_assets,
        total_bytes,
    }
}

/// Generate assembly code for all assets (single-bank mode - all in one place)
pub fn generate_assets_asm(assets: &[AssetInfo]) -> Result<String, String> {
    let mut out = String::new();
    
    out.push_str(";***************************************************************************\n");
    out.push_str("; EMBEDDED ASSETS (vectors, music, levels, SFX)\n");
    out.push_str(";***************************************************************************\n\n");
    
    // Generate vector assets (also collect dims for level compilation)
    let mut sg_vec_assets: Vec<SizedAsset> = Vec::new();
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Vector)) {
        match crate::vecres::VecResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                let asm = resource.compile_to_asm_with_name(Some(&asset.name));
                out.push_str(&asm);
                sg_vec_assets.push(SizedAsset { info: asset.clone(), binary_size: 0, asm_code: asm });
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load vector asset '{}': {}", asset.name, e);
            }
        }
    }
    let sg_vec_dims = build_vec_dims(&sg_vec_assets);

    // Generate music assets
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Music)) {
        match crate::musres::MusicResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                out.push_str(&resource.compile_to_asm(&asset.name));
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load music asset '{}': {}", asset.name, e);
            }
        }
    }

    // Generate level assets
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Level)) {
        match crate::levelres::VPlayLevel::load(Path::new(&asset.path)) {
            Ok(resource) => {
                out.push_str(&resource.compile_to_asm_with_vec_dims(&sg_vec_dims));
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load level asset '{}': {}", asset.name, e);
            }
        }
    }
    
    // Generate SFX assets
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Sfx)) {
        match crate::sfxres::SfxResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                out.push_str(&resource.compile_to_asm_with_name(Some(&asset.name)));
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load SFX asset '{}': {}", asset.name, e);
            }
        }
    }

    // Generate animation assets
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Animation)) {
        match crate::animres::VanimResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                out.push_str(&crate::animres::compile_vanim_to_asm(&resource, &asset.name));
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load animation asset '{}': {}", asset.name, e);
            }
        }
    }

    // Generate instrument assets
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Instrument)) {
        match crate::instrres::InstrResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                out.push_str(&resource.compile_to_asm_with_name(Some(&asset.name)));
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load instrument asset '{}': {}", asset.name, e);
            }
        }
    }

    // Generate enemy assets
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Enemy)) {
        match crate::venemy::EnemyResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                out.push_str(&resource.compile_to_asm_with_name(Some(&asset.name)));
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load enemy asset '{}': {}", asset.name, e);
            }
        }
    }

    // Generate recording assets (.vrec vector-movie playback data).
    // VIDEO-ONLY, SINGLE-BANK: emitted as MC6809 FDB/FCB tables read by
    // DRAW_RECORDING_RUNTIME. See compile_vrec for the byte layout.
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Recording)) {
        match fs::read_to_string(&asset.path) {
            Ok(text) => match serde_json::from_str::<VrecResource>(&text) {
                Ok(vrec) => out.push_str(&compile_vrec(&vrec, &asset.name)),
                Err(e) => {
                    eprintln!("[WARNING] Failed to parse recording asset '{}': {}", asset.name, e);
                    let sym = asset.name.to_uppercase().replace('-', "_").replace(' ', "_");
                    out.push_str(&format!("_{sym}_VREC:\n    FDB 0    ; empty recording (parse error)\n\n"));
                }
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to read recording asset '{}': {}", asset.name, e);
            }
        }
    }

    Ok(out)
}

// ============================================================
// Recording compiler (.vrec → MC6809 frame/segment table)
// ============================================================
//
// The .vrec JSON is TARGET-AGNOSTIC (same file drives rp2350/pitrex/m6809).
// The offset table stores ABSOLUTE frame-label pointers (FDB _<SYM>_VREC_Fn),
// which the linker resolves — no address math in codegen; the runtime
// dereferences with LDX ,X just like DRAW_ANIM's frame table.
//
// POLYLINE CHAINING (2026-07): consecutive segments that share an endpoint AND
// intensity are folded into a single chain (start point once + one delta per
// line) by the target-agnostic `crate::vrec_chain::chain_frame`. This roughly
// halves ROM size for traced contours (each interior vertex was stored twice)
// and draws faster (one Reset0Ref + Moveto_d per chain, then continuous
// Draw_Line_d deltas). The .vrec FILE format is UNCHANGED — chaining is a
// compile-time transform. Per-frame layout emitted here:
//
//   _<SYM>_VREC:  FDB frame_count
//                 FDB _<SYM>_VREC_F0, _<SYM>_VREC_F1, ...   (abs frame pointers)
//   _<SYM>_VREC_Fn:
//                 FDB chain_count
//     per chain:  FCB start_x, start_y   ; i8 (compile-time clamped)
//                 FCB intensity          ; u8 (0-127)
//                 FCB seg_count          ; number of deltas (drawn lines), 1-255
//                 FCB dx,dy × seg_count  ; i8 deltas (compile-time clamped)
//
// A chain of N segments costs 4 + 2N bytes vs the old 5N (e.g. a 20-line closed
// contour: 44 bytes vs 100). Deltas are clamped to i8 at compile time exactly
// like the old runtime DREC_DIFF (no accuracy regression). A chain longer than
// 255 deltas (rare) is split into consecutive chains, re-anchored at the pen.
//
// NOTE: the vectors/frame count remains a DATA (flicker-budget) concern — the
// runtime draws every segment; it does not decimate.
const VREC_MAX_DELTAS_PER_CHAIN: usize = 255;

fn compile_vrec(vrec: &VrecResource, override_name: &str) -> String {
    use crate::vrec_chain::{chain_frame, Segment};
    let sym = override_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let frame_count = vrec.frames.len();

    let clamp8 = |v: i32| v.clamp(-127, 127) as i8;

    let mut s = String::new();
    s.push_str(&format!(
        "; --- {} RECORDING ({} frame(s), fps={}, polyline-chained) ---\n",
        override_name, frame_count, vrec.fps
    ));
    s.push_str(&format!("_{sym}_VREC:\n"));
    s.push_str(&format!("    FDB {}    ; frame_count\n", frame_count));
    for i in 0..frame_count {
        s.push_str(&format!("    FDB _{sym}_VREC_F{i}    ; frame {i} pointer\n"));
    }
    for (i, frame) in vrec.frames.iter().enumerate() {
        // Fold this frame's ordered segments into polyline chains.
        let segs: Vec<Segment> = frame.segments.iter()
            .map(|seg| Segment { x0: seg.x0, y0: seg.y0, x1: seg.x1, y1: seg.y1, i: seg.i })
            .collect();
        let chains = chain_frame(&segs);

        // Emit each chain, splitting any chain with > 255 deltas so seg_count
        // fits in one byte. A split re-anchors at the raw pen position.
        let mut emitted: Vec<(i32, i32, i32, Vec<(i32, i32)>)> = Vec::new(); // (sx, sy, inten, deltas)
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

        s.push_str(&format!("_{sym}_VREC_F{i}:\n"));
        s.push_str(&format!("    FDB {}    ; chain_count\n", emitted.len()));
        for (sx, sy, inten, deltas) in &emitted {
            let start_x = clamp8(*sx);
            let start_y = clamp8(*sy);
            let intensity = (*inten).clamp(0, 127) as u8;
            s.push_str(&format!(
                "    FCB ${:02X},${:02X},${:02X},${:02X}    ; start=({},{}) i={} segs={}\n",
                start_x as u8, start_y as u8, intensity, deltas.len() as u8,
                start_x, start_y, intensity, deltas.len()
            ));
            for (dx, dy) in deltas {
                let cdx = clamp8(*dx);
                let cdy = clamp8(*dy);
                s.push_str(&format!(
                    "    FCB ${:02X},${:02X}    ; d=({},{})\n",
                    cdx as u8, cdy as u8, cdx, cdy
                ));
            }
        }
    }
    s.push('\n');
    s
}

// .vrec JSON schema (identical to pitrex/arm VrecResource — target-agnostic).
#[derive(serde::Deserialize)]
struct VrecResource {
    #[serde(default)]
    fps: f64,
    #[serde(default)]
    frames: Vec<VrecFrame>,
}

#[derive(serde::Deserialize)]
struct VrecFrame {
    #[serde(default)]
    segments: Vec<VrecSegment>,
}

#[derive(serde::Deserialize)]
struct VrecSegment {
    x0: i32,
    y0: i32,
    x1: i32,
    y1: i32,
    /// Intensity 0-127 (recorder only stores visible segments, i > 0)
    i: i32,
}

/// Generate assembly code for assets distributed across multiple banks
/// 
/// Returns a tuple: (bank_asm_map, lookup_tables_asm)
/// - bank_asm_map: HashMap<bank_id, asm_code> for each bank's assets
/// - lookup_tables_asm: ASM code for ASSET_BANK_TABLE and ASSET_ADDR_TABLE (goes in helpers bank)
pub fn generate_distributed_assets_asm(
    assets: &[AssetInfo],
    bank_size: usize,
    helpers_bank: u8,
    pre_used_bytes: &std::collections::HashMap<u8, usize>,
) -> Result<(std::collections::HashMap<u8, String>, String), String> {
    use std::collections::HashMap;
    
    // Collect vec names referenced by animations — these must stay in the helpers bank
    // so DRAW_ANIM_RUNTIME can follow FDB pointers without bank switching.
    let mut anim_vec_refs: std::collections::HashSet<String> = std::collections::HashSet::new();
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Animation)) {
        collect_vanim_vec_refs(&asset.path, &mut anim_vec_refs);
    }

    // Distribute assets across banks 1..(helpers_bank-1)
    // Bank 0 has main code, helpers_bank has runtime
    // Exclude animations and animation-referenced vecs from distribution (they go to helpers bank)
    let distributable: Vec<AssetInfo> = assets.iter()
        .filter(|a| {
            !matches!(a.asset_type, AssetType::Enemy | AssetType::Animation)
                && !anim_vec_refs.contains(&a.name)
        })
        .cloned()
        .collect();
    let distribution = distribute_assets(&distributable, bank_size, 1, helpers_bank.saturating_sub(1), pre_used_bytes);

    // Build vec_bank_map: lowercase vec name → bank_id, from distribution results.
    // Used to regenerate level ASM with correct vector_bank bytes (stride-21 format).
    let mut vec_bank_map: HashMap<String, u8> = HashMap::new();
    for (bank_id, sized_assets) in &distribution.bank_assignments {
        for asset in sized_assets {
            if matches!(asset.info.asset_type, AssetType::Vector) {
                vec_bank_map.insert(asset.info.name.to_lowercase(), *bank_id);
            }
        }
    }

    // Build vec_dims from distribution: vec name → (half_width, half_height).
    // Needed to regenerate level ASM with correct AABB bytes.
    let all_vec_assets: Vec<SizedAsset> = distribution.bank_assignments.values()
        .flat_map(|assets| assets.iter())
        .filter(|a| matches!(a.info.asset_type, AssetType::Vector))
        .cloned()
        .collect();
    let vec_dims_for_levels = build_vec_dims(&all_vec_assets);

    // Build vec_meshes: lowercase vec name → collision segments from the .vec file,
    // for the LEVEL_COLLISION_Y mesh ray-cast (empty → AABB fallback for that object).
    let mut vec_meshes: HashMap<String, Vec<crate::vecres::VecMeshSegment>> = HashMap::new();
    // Per-vec walkable areas (vec-local coords). Used by levelres wander-enemy
    // patrol-bound derivation: each placed platform contributes its own walk
    // band so titchis end up patrolling the platform they spawn on, not just
    // the level-wide floor band.
    let mut vec_walk_areas: HashMap<String, Vec<crate::vecres::VecWalkableArea>> = HashMap::new();
    for asset in &all_vec_assets {
        if let Ok(text) = std::fs::read_to_string(&asset.info.path) {
            if let Ok(res) = serde_json::from_str::<crate::vecres::VecResource>(&text) {
                if let Some(mesh) = &res.collision_mesh {
                    if !mesh.segments.is_empty() {
                        vec_meshes.insert(asset.info.name.to_lowercase(), mesh.segments.clone());
                    }
                }
                if !res.walkable_areas.is_empty() {
                    vec_walk_areas.insert(asset.info.name.to_lowercase(), res.walkable_areas.clone());
                }
            }
        }
    }

    // Regenerate level ASM using the now-known vec_bank_map (stride-23 with bank bytes).
    // This second pass replaces the first-pass level ASM that was generated in
    // prepare_assets_with_sizes without knowing which bank each vector lives in.
    let mut level_asm_by_name: HashMap<String, String> = HashMap::new();
    for (_, sized_assets) in &distribution.bank_assignments {
        for asset in sized_assets {
            if matches!(asset.info.asset_type, AssetType::Level) {
                match crate::levelres::VPlayLevel::load(std::path::Path::new(&asset.info.path)) {
                    Ok(resource) => {
                        let asm_code = resource.compile_to_asm_with_bank_map_and_walk(&vec_dims_for_levels, &vec_bank_map, &vec_meshes, &vec_walk_areas);
                        level_asm_by_name.insert(asset.info.name.clone(), asm_code);
                    }
                    Err(e) => {
                        eprintln!("[WARNING] Failed to reload level asset '{}' for bank-map pass: {}", asset.info.name, e);
                    }
                }
            }
        }
    }

    let mut bank_asm: HashMap<u8, String> = HashMap::new();
    let _asset_index = 0u16;

    // Track asset info for lookup table generation
    let mut asset_entries: Vec<(String, u8, String, AssetType)> = Vec::new(); // (name, bank_id, label, type)

    // Generate ASM for each bank
    for (bank_id, sized_assets) in &distribution.bank_assignments {
        let mut asm = String::new();
        asm.push_str(&format!(";***************************************************************************\n"));
        asm.push_str(&format!("; ASSETS IN BANK #{} ({} assets)\n", bank_id, sized_assets.len()));
        asm.push_str(&format!(";***************************************************************************\n\n"));

        for asset in sized_assets {
            // Use pre-generated ASM code (level ASM replaced with bank-map version)
            let code = if matches!(asset.info.asset_type, AssetType::Level) {
                level_asm_by_name.get(&asset.info.name)
                    .map(|s| s.as_str())
                    .unwrap_or(&asset.asm_code)
            } else {
                &asset.asm_code
            };
            asm.push_str(code);
            asm.push_str("\n");

            // Track for lookup table with correct label suffix based on type
            let symbol_name = asset.info.name.to_uppercase().replace("-", "_").replace(" ", "_");
            let label = match asset.info.asset_type {
                AssetType::Vector => format!("_{}_VECTORS", symbol_name),
                AssetType::Music => format!("_{}_MUSIC", symbol_name),
                AssetType::Sfx => format!("_{}_SFX", symbol_name),
                AssetType::Level => format!("_{}_LEVEL", symbol_name),
                AssetType::Animation => format!("_ANIM_{}", symbol_name),
                AssetType::Instrument => format!("_{}_INSTR", symbol_name),
                AssetType::Enemy => format!("_{}_ENEMY", symbol_name),
                // .vrec playback is ARM-only; recordings never reach the m6809
                // bank packer (filter_used_assets drops them), but keep the
                // match exhaustive.
                AssetType::Recording => format!("_{}_VREC", symbol_name),
                // .vsmp playback is ARM-only; samples never reach the m6809
                // bank packer (filter_used_assets drops them), but keep the
                // match exhaustive.
                AssetType::Sample => format!("_{}_SMP", symbol_name),
            };
            asset_entries.push((asset.info.name.clone(), *bank_id, label, asset.info.asset_type.clone()));
        }

        bank_asm.insert(*bank_id, asm);
    }
    
    // Separate entries by type for type-specific lookup tables
    let vector_entries: Vec<_> = asset_entries.iter()
        .filter(|(_, _, _, t)| matches!(t, AssetType::Vector))
        .cloned()
        .collect();
    let music_entries: Vec<_> = asset_entries.iter()
        .filter(|(_, _, _, t)| matches!(t, AssetType::Music))
        .cloned()
        .collect();
    let sfx_entries: Vec<_> = asset_entries.iter()
        .filter(|(_, _, _, t)| matches!(t, AssetType::Sfx))
        .cloned()
        .collect();
    let level_entries: Vec<_> = asset_entries.iter()
        .filter(|(_, _, _, t)| matches!(t, AssetType::Level))
        .cloned()
        .collect();
    let anim_entries: Vec<(String, u8, String, AssetType)> = assets.iter()
        .filter(|a| matches!(a.asset_type, AssetType::Animation))
        .map(|a| {
            let sym = a.name.to_uppercase().replace('-', "_").replace(' ', "_");
            // Animations always reside in the helpers bank (emitted there for DRAW_ANIM_RUNTIME access)
            (a.name.clone(), helpers_bank, format!("_ANIM_{}", sym), AssetType::Animation)
        })
        .collect();
    let instr_entries: Vec<_> = asset_entries.iter()
        .filter(|(_, _, _, t)| matches!(t, AssetType::Instrument))
        .cloned()
        .collect();
    // Enemy assets are placed in the helpers bank (always accessible from DRAW_ENEMIES_RUNTIME).
    // They are NOT in asset_entries (skipped above), so rebuild from the raw AssetInfo list.
    // bank_id is set to helpers_bank so ENEMY_BANK_TABLE correctly reflects their location.
    let enemy_entries: Vec<(String, u8, String, AssetType)> = assets.iter()
        .filter(|a| matches!(a.asset_type, AssetType::Enemy))
        .map(|a| {
            let sym = a.name.to_uppercase().replace('-', "_").replace(' ', "_");
            (a.name.clone(), helpers_bank, format!("_{}_ENEMY", sym), AssetType::Enemy)
        })
        .collect();

    // Sort each list alphabetically by name for index consistency
    let mut vector_entries = vector_entries;
    let mut music_entries = music_entries;
    let mut sfx_entries = sfx_entries;
    let mut level_entries = level_entries;
    let mut anim_entries = anim_entries;
    let mut instr_entries = instr_entries;
    let mut enemy_entries = enemy_entries;
    vector_entries.sort_by(|a, b| a.0.cmp(&b.0));
    music_entries.sort_by(|a, b| a.0.cmp(&b.0));
    sfx_entries.sort_by(|a, b| a.0.cmp(&b.0));
    level_entries.sort_by(|a, b| a.0.cmp(&b.0));
    anim_entries.sort_by(|a, b| a.0.cmp(&b.0));
    instr_entries.sort_by(|a, b| a.0.cmp(&b.0));
    enemy_entries.sort_by(|a, b| a.0.cmp(&b.0));

    // Generate lookup tables for helpers bank
    let mut lookup_asm = String::new();
    lookup_asm.push_str(";***************************************************************************\n");
    lookup_asm.push_str("; ASSET LOOKUP TABLES (for banked asset access)\n");
    lookup_asm.push_str(&format!("; Total: {} vectors, {} music, {} sfx, {} levels, {} animations, {} instruments, {} enemies\n",
        vector_entries.len(), music_entries.len(), sfx_entries.len(),
        level_entries.len(), anim_entries.len(), instr_entries.len(), enemy_entries.len()));
    lookup_asm.push_str(";***************************************************************************\n\n");
    
    // ===== VECTOR TABLES =====
    if !vector_entries.is_empty() {
        lookup_asm.push_str("; Vector Asset Index Mapping:\n");
        for (idx, (name, bank_id, _label, _)) in vector_entries.iter().enumerate() {
            lookup_asm.push_str(&format!(";   {} = {} (Bank #{})\n", idx, name, bank_id));
        }
        lookup_asm.push_str("\n");
        
        lookup_asm.push_str("VECTOR_BANK_TABLE:\n");
        for (_, bank_id, _, _) in &vector_entries {
            lookup_asm.push_str(&format!("    FCB {}              ; Bank ID\n", bank_id));
        }
        lookup_asm.push_str("\n");
        
        lookup_asm.push_str("VECTOR_ADDR_TABLE:\n");
        for (name, _, label, _) in &vector_entries {
            // Use direct label reference - assembler will resolve when symbol is available
            lookup_asm.push_str(&format!("    FDB {}    ; {}\n", label, name));
        }
        lookup_asm.push_str("\n");
    }
    
    // ===== MUSIC TABLES =====
    if !music_entries.is_empty() {
        lookup_asm.push_str("; Music Asset Index Mapping:\n");
        for (idx, (name, bank_id, _label, _)) in music_entries.iter().enumerate() {
            lookup_asm.push_str(&format!(";   {} = {} (Bank #{})\n", idx, name, bank_id));
        }
        lookup_asm.push_str("\n");
        
        lookup_asm.push_str("MUSIC_BANK_TABLE:\n");
        for (_, bank_id, _, _) in &music_entries {
            lookup_asm.push_str(&format!("    FCB {}              ; Bank ID\n", bank_id));
        }
        lookup_asm.push_str("\n");
        
        lookup_asm.push_str("MUSIC_ADDR_TABLE:\n");
        for (name, _, label, _) in &music_entries {
            // Use direct label reference - assembler will resolve when symbol is available
            lookup_asm.push_str(&format!("    FDB {}    ; {}\n", label, name));
        }
        lookup_asm.push_str("\n");
    }
    
    // ===== SFX TABLES =====
    if !sfx_entries.is_empty() {
        lookup_asm.push_str("; SFX Asset Index Mapping:\n");
        for (idx, (name, bank_id, _label, _)) in sfx_entries.iter().enumerate() {
            lookup_asm.push_str(&format!(";   {} = {} (Bank #{})\n", idx, name, bank_id));
        }
        lookup_asm.push_str("\n");
        
        lookup_asm.push_str("SFX_BANK_TABLE:\n");
        for (_, bank_id, _, _) in &sfx_entries {
            lookup_asm.push_str(&format!("    FCB {}              ; Bank ID\n", bank_id));
        }
        lookup_asm.push_str("\n");
        
        lookup_asm.push_str("SFX_ADDR_TABLE:\n");
        for (name, _, label, _) in &sfx_entries {
            // Use direct label reference - assembler will resolve when symbol is available
            lookup_asm.push_str(&format!("    FDB {}    ; {}\n", label, name));
        }
        lookup_asm.push_str("\n");
    }
    
    // ===== LEVEL TABLES =====
    if !level_entries.is_empty() {
        lookup_asm.push_str("; Level Asset Index Mapping:\n");
        for (idx, (name, bank_id, _label, _)) in level_entries.iter().enumerate() {
            lookup_asm.push_str(&format!(";   {} = {} (Bank #{})\n", idx, name, bank_id));
        }
        lookup_asm.push_str("\n");
        
        lookup_asm.push_str("LEVEL_BANK_TABLE:\n");
        for (_, bank_id, _, _) in &level_entries {
            lookup_asm.push_str(&format!("    FCB {}              ; Bank ID\n", bank_id));
        }
        lookup_asm.push_str("\n");
        
        lookup_asm.push_str("LEVEL_ADDR_TABLE:\n");
        for (name, _, label, _) in &level_entries {
            // Use direct label reference - assembler will resolve when symbol is available
            lookup_asm.push_str(&format!("    FDB {}    ; {}\n", label, name));
        }
        lookup_asm.push_str("\n");
    }
    
    // ===== ANIMATION TABLES =====
    if !anim_entries.is_empty() {
        lookup_asm.push_str("; Animation Asset Index Mapping:\n");
        for (idx, (name, bank_id, _label, _)) in anim_entries.iter().enumerate() {
            lookup_asm.push_str(&format!(";   {} = {} (Bank #{})\n", idx, name, bank_id));
        }
        lookup_asm.push_str("\n");

        lookup_asm.push_str("ANIM_BANK_TABLE:\n");
        for (_, bank_id, _, _) in &anim_entries {
            lookup_asm.push_str(&format!("    FCB {}              ; Bank ID\n", bank_id));
        }
        lookup_asm.push_str("\n");

        lookup_asm.push_str("ANIM_ADDR_TABLE:\n");
        for (name, _, label, _) in &anim_entries {
            lookup_asm.push_str(&format!("    FDB {}    ; {}\n", label, name));
        }
        lookup_asm.push_str("\n");
    }

    // ===== INSTRUMENT TABLES =====
    if !instr_entries.is_empty() {
        lookup_asm.push_str("; Instrument Asset Index Mapping:\n");
        for (idx, (name, bank_id, _label, _)) in instr_entries.iter().enumerate() {
            lookup_asm.push_str(&format!(";   {} = {} (Bank #{})\n", idx, name, bank_id));
        }
        lookup_asm.push_str("\n");

        lookup_asm.push_str("INSTRUMENT_BANK_TABLE:\n");
        for (_, bank_id, _, _) in &instr_entries {
            lookup_asm.push_str(&format!("    FCB {}              ; Bank ID\n", bank_id));
        }
        lookup_asm.push_str("\n");

        lookup_asm.push_str("INSTRUMENT_ADDR_TABLE:\n");
        for (name, _, label, _) in &instr_entries {
            lookup_asm.push_str(&format!("    FDB {}    ; {}\n", label, name));
        }
        lookup_asm.push_str("\n");
    }

    // ===== ENEMY TABLES =====
    // Enemy type data is emitted directly into the helpers bank so DRAW_ENEMIES_RUNTIME
    // can always read type headers and action tables without bank switching.
    // The action table uses FCB sprite_idx (index into VECTOR_ADDR_TABLE) instead of
    // FDB sprite_ptr, enabling DRAW_VECTOR_BANKED for cross-bank sprite rendering.
    if !enemy_entries.is_empty() {
        // Build vector-name → index map for resolving sprite references in .venemy files
        let vec_idx_map: std::collections::HashMap<String, u8> = vector_entries.iter()
            .enumerate()
            .map(|(i, (name, _, _, _))| (name.clone(), i as u8))
            .collect();

        // Build anim-name → index map for resolving vanim sprite references in .venemy files
        let anim_idx_map: std::collections::HashMap<String, u8> = anim_entries.iter()
            .enumerate()
            .map(|(i, (name, _, _, _))| (name.clone(), i as u8))
            .collect();

        lookup_asm.push_str("; Enemy Asset Index Mapping (all in helpers bank for direct access):\n");
        for (idx, (name, bank_id, _label, _)) in enemy_entries.iter().enumerate() {
            lookup_asm.push_str(&format!(";   {} = {} (Bank #{})\n", idx, name, bank_id));
        }
        lookup_asm.push_str("\n");

        lookup_asm.push_str("ENEMY_BANK_TABLE:\n");
        for (_, bank_id, _, _) in &enemy_entries {
            lookup_asm.push_str(&format!("    FCB {}              ; Bank ID (helpers bank — always mapped)\n", bank_id));
        }
        lookup_asm.push_str("\n");

        lookup_asm.push_str("ENEMY_ADDR_TABLE:\n");
        for (name, _, label, _) in &enemy_entries {
            lookup_asm.push_str(&format!("    FDB {}    ; {}\n", label, name));
        }
        lookup_asm.push_str("\n");

        // Emit enemy type data (indexed format) directly into the helpers bank
        lookup_asm.push_str(";***************************************************************************\n");
        lookup_asm.push_str("; ENEMY TYPE DEFINITIONS (helpers bank — always accessible)\n");
        lookup_asm.push_str("; Action table uses FCB sprite_idx for DRAW_VECTOR_BANKED compatibility\n");
        lookup_asm.push_str(";***************************************************************************\n");
        for (name, _, _, _) in &enemy_entries {
            let enemy_asset = assets.iter()
                .find(|a| &a.name == name && matches!(a.asset_type, AssetType::Enemy));
            if let Some(sa) = enemy_asset {
                match crate::venemy::EnemyResource::load(std::path::Path::new(&sa.path)) {
                    Ok(resource) => {
                        lookup_asm.push_str(&resource.compile_to_asm_indexed(Some(name), &vec_idx_map, &anim_idx_map));
                    }
                    Err(e) => {
                        eprintln!("[WARNING] Failed to reload enemy '{}' for helpers bank: {}", name, e);
                    }
                }
            }
        }
        lookup_asm.push_str("\n");
    }

    // Legacy unified tables (deprecated, keep for compatibility)
    lookup_asm.push_str("; Legacy unified tables (all assets)\n");
    lookup_asm.push_str("ASSET_BANK_TABLE:\n");
    for (_, bank_id, _, _) in &asset_entries {
        lookup_asm.push_str(&format!("    FCB {}              ; Bank ID\n", bank_id));
    }
    lookup_asm.push_str("\n");
    
    lookup_asm.push_str("ASSET_ADDR_TABLE:\n");
    for (name, _, label, _) in &asset_entries {
        // Use direct label reference - assembler will resolve when symbol is available
        lookup_asm.push_str(&format!("    FDB {}    ; {}\n", label, name));
    }
    lookup_asm.push_str("\n");
    
    // Generate banked wrappers (only if corresponding assets exist)
    if !vector_entries.is_empty() {
        lookup_asm.push_str(&generate_draw_vector_banked_wrapper());
    }
    if !music_entries.is_empty() {
        lookup_asm.push_str(&generate_play_music_banked_wrapper());
    }
    if !sfx_entries.is_empty() {
        lookup_asm.push_str(&generate_play_sfx_banked_wrapper());
    }
    if !level_entries.is_empty() {
        lookup_asm.push_str(&generate_load_level_banked_wrapper());
    }
    if !enemy_entries.is_empty() {
        lookup_asm.push_str(&generate_spawn_enemies_banked_wrapper());
    }
    // Emit DRAW_ANIM_BANKED if there are both animations and enemies (vanim sprite support)
    if !anim_entries.is_empty() && !enemy_entries.is_empty() {
        lookup_asm.push_str(&generate_draw_anim_banked_wrapper());
    }

    // ===== ANIMATION DATA IN HELPERS BANK =====
    // Animation headers + frame data + their referenced vec files are emitted here so
    // DRAW_ANIM_RUNTIME can follow FDB pointers without bank switching.
    // All these labels will be at $4000+ (helpers bank ORG) and always accessible.
    {
        // Collect vec assets that are animation-referenced (need to be in helpers bank)
        let anim_assets: Vec<&AssetInfo> = assets.iter()
            .filter(|a| matches!(a.asset_type, AssetType::Animation))
            .collect();

        if !anim_assets.is_empty() {
            lookup_asm.push_str(";***************************************************************************\n");
            lookup_asm.push_str("; ANIMATION DATA (helpers bank — always accessible for DRAW_ANIM_RUNTIME)\n");
            lookup_asm.push_str(";***************************************************************************\n\n");

            // Emit animation headers + frame data
            for asset in &anim_assets {
                match crate::animres::VanimResource::load(std::path::Path::new(&asset.path)) {
                    Ok(resource) => {
                        lookup_asm.push_str(&crate::animres::compile_vanim_to_asm(&resource, &asset.name));
                        lookup_asm.push('\n');
                    }
                    Err(e) => {
                        eprintln!("[WARNING] Failed to load animation '{}' for helpers bank: {}", asset.name, e);
                    }
                }
            }

            // Emit vec files referenced by animations (also in helpers bank)
            lookup_asm.push_str("; Vec files referenced by animations (helpers bank for cross-bank safety)\n\n");
            for vec_name in &anim_vec_refs {
                if let Some(vec_asset) = assets.iter().find(|a| matches!(a.asset_type, AssetType::Vector) && &a.name == vec_name) {
                    match crate::vecres::VecResource::load(std::path::Path::new(&vec_asset.path)) {
                        Ok(resource) => {
                            lookup_asm.push_str(&resource.compile_to_asm_with_name(Some(vec_name)));
                            lookup_asm.push('\n');
                        }
                        Err(e) => {
                            eprintln!("[WARNING] Failed to load vec '{}' for helpers bank (animation ref): {}", vec_name, e);
                        }
                    }
                }
            }
        }
    }

    Ok((bank_asm, lookup_asm))
}

/// Generate the DRAW_VECTOR_BANKED runtime wrapper for helpers bank
fn generate_draw_vector_banked_wrapper() -> String {
    let mut asm = String::new();
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; DRAW_VECTOR_BANKED - Draw vector asset with automatic bank switching\n");
    asm.push_str("; Input: X = asset index (0-based), DRAW_VEC_X/Y set for position\n");
    asm.push_str(";        MIRROR_X, MIRROR_Y, DRAW_VEC_INTENSITY must be set by caller\n");
    asm.push_str("; Uses: A, B, D, X, Y, U\n");
    asm.push_str("; Preserves: CURRENT_ROM_BANK (restored after drawing)\n");
    asm.push_str("; Note: DSWM handles beam positioning internally via DRAW_VEC_X/Y\n");
    asm.push_str(";***************************************************************************\n");
    asm.push_str("DRAW_VECTOR_BANKED:\n");
    asm.push_str("    ; Save index to U register (avoid stack order issues)\n");
    asm.push_str("    TFR X,U              ; U = vector index\n");
    asm.push_str("    ; Save context: original bank on stack\n");
    asm.push_str("    LDA CURRENT_ROM_BANK\n");
    asm.push_str("    PSHS A               ; Stack: [A]\n");
    asm.push_str("\n");
    asm.push_str("    ; Get asset's bank from lookup table\n");
    asm.push_str("    TFR X,D              ; D = asset index\n");
    asm.push_str("    LDX #VECTOR_BANK_TABLE\n");
    asm.push_str("    LDA D,X              ; A = bank ID for this asset\n");
    asm.push_str("    STA CURRENT_ROM_BANK ; Update RAM tracker\n");
    asm.push_str("    STA $DF00            ; Switch bank hardware register\n");
    asm.push_str("\n");
    asm.push_str("    ; Get asset's address from lookup table (2 bytes per entry)\n");
    asm.push_str("    TFR U,D              ; D = asset index (saved in U at entry)\n");
    asm.push_str("    ASLB                 ; *2 for FDB entries\n");
    asm.push_str("    ROLA\n");
    asm.push_str("    LDX #VECTOR_ADDR_TABLE\n");
    asm.push_str("    LEAX D,X             ; X points to address entry\n");
    asm.push_str("    LDX ,X               ; X = _VEC_VECTORS header address in banked ROM\n");
    asm.push_str("\n");
    asm.push_str("    ; Set DP=$D0 for DSWM / VIA access (caller set MIRROR_X/Y/INTENSITY)\n");
    asm.push_str("    JSR $F1AA            ; DP_to_D0\n");
    asm.push_str("\n");
    asm.push_str("    ; Set DRAW_T1_SCALED to BIOS default ($7F) — SLR_DRAW_CLIPPED_PATH reads it\n");
    asm.push_str("    ; when the fallback path is taken.\n");
    asm.push_str("    LDA #$7F\n");
    asm.push_str("    STA >DRAW_T1_SCALED\n");
    asm.push_str("    ; Loop over all paths (header: FDB path_count, then FDB table)\n");
    asm.push_str("    LDD ,X               ; D = path_count (16-bit FDB at header start)\n");
    asm.push_str("    CMPD #0\n");
    asm.push_str("    LBEQ DVB_DONE        ; No paths\n");
    asm.push_str("    LEAY 2,X             ; Y = pointer to first FDB entry (after 2-byte header)\n");
    asm.push_str("DVB_PATH_LOOP:\n");
    asm.push_str("    PSHS D               ; Save remaining path count (2 bytes)\n");
    asm.push_str("    LDX ,Y               ; X = path data address (FDB entry)\n");
    asm.push_str("    ; Hybrid clip decision: fast DSWM if screen_x deep inside, slow SDCP near edges.\n");
    asm.push_str("    LDA >DRAW_VEC_X_HI\n");
    asm.push_str("    BEQ DVB_CHECK_POS\n");
    asm.push_str("    INCA\n");
    asm.push_str("    BNE DVB_USE_SDCP\n");
    asm.push_str("    LDA >DRAW_VEC_X\n");
    asm.push_str("    CMPA #$B0            ; -80\n");
    asm.push_str("    BHS DVB_USE_DSWM\n");
    asm.push_str("    BRA DVB_USE_SDCP\n");
    asm.push_str("DVB_CHECK_POS:\n");
    asm.push_str("    LDA >DRAW_VEC_X\n");
    asm.push_str("    CMPA #80\n");
    asm.push_str("    BLS DVB_USE_DSWM\n");
    asm.push_str("DVB_USE_SDCP:\n");
    asm.push_str("    JSR SLR_DRAW_CLIPPED_PATH\n");
    asm.push_str("    BRA DVB_PATH_AFTER\n");
    asm.push_str("DVB_USE_DSWM:\n");
    asm.push_str("    JSR Draw_Sync_List_At_With_Mirrors\n");
    asm.push_str("DVB_PATH_AFTER:\n");
    asm.push_str("    LEAY 2,Y             ; Advance to next FDB entry\n");
    asm.push_str("    PULS D               ; Restore count\n");
    asm.push_str("    SUBD #1\n");
    asm.push_str("    BNE DVB_PATH_LOOP\n");
    asm.push_str("DVB_DONE:\n");
    asm.push_str("\n");
    asm.push_str("    JSR $F1AF            ; DP_to_C8\n");
    asm.push_str("\n");
    asm.push_str("    ; Restore original bank from stack (only A was pushed with PSHS A)\n");
    asm.push_str("    PULS A               ; A = original bank\n");
    asm.push_str("    STA CURRENT_ROM_BANK\n");
    asm.push_str("    STA $DF00            ; Restore bank\n");
    asm.push_str("\n");
    asm.push_str("    RTS\n");
    asm.push_str("\n");
    
    asm
}

/// Generate the DRAW_ANIM_BANKED runtime wrapper for helpers bank.
///
/// Animations live in the helpers bank (always visible at $4000+), so no bank
/// switching is required.  The wrapper simply looks up the anim header address
/// from ANIM_ADDR_TABLE, sets up DRAW_ANIM parameters, positions the beam, and
/// calls DRAW_ANIM_RUNTIME.
///
/// Input:  X = animation index (0-based into ANIM_ADDR_TABLE)
///         U = pointer to 2-byte RAM animation state (frame_idx, ticks_left)
///             DRAW_VEC_X / DRAW_VEC_Y already set by caller
/// Clobbers: A, B, X (Y is preserved by DRAW_ANIM_RUNTIME via PSHS/PULS)
pub(crate) fn generate_draw_anim_banked_wrapper() -> String {
    let mut asm = String::new();

    asm.push_str(";***************************************************************************\n");
    asm.push_str("; DRAW_ANIM_BANKED - Draw vanim sprite for enemies\n");
    asm.push_str("; Animations are always in the helpers bank (fixed $4000+); no bank switch.\n");
    asm.push_str("; Input: X = anim index (0-based into ANIM_ADDR_TABLE)\n");
    asm.push_str(";        U = ptr to 2-byte RAM state (byte0=frame_idx, byte1=ticks_left)\n");
    asm.push_str(";        DRAW_VEC_X / DRAW_VEC_Y set for enemy screen position\n");
    asm.push_str("; Clobbers: A, B, X  (DRAW_ANIM_RUNTIME preserves D,X,Y,U via PSHS/PULS)\n");
    asm.push_str(";***************************************************************************\n");
    asm.push_str("DRAW_ANIM_BANKED:\n");
    asm.push_str("    ; Set up animation draw parameters (defaults: normal size, vanim timing).\n");
    asm.push_str("    ; NOTE: do NOT clear DRAW_ANIM_MIRROR_X or MIRROR_X here — DRAW_ENEMIES\n");
    asm.push_str("    ; sets them from POOL_DIR right before calling us, and clearing would wipe\n");
    asm.push_str("    ; the patrol-direction mirror. DRAW_ANIM_RUNTIME re-applies DRAW_ANIM_MIRROR_X\n");
    asm.push_str("    ; to MIRROR_X per frame, so just leave both alone.\n");
    asm.push_str("    CLR >MIRROR_Y\n");
    asm.push_str("    LDA #$7F\n");
    asm.push_str("    STA >DRAW_ANIM_SCALE\n");
    asm.push_str("    CLR >DRAW_ANIM_SPEED_MUL\n");
    asm.push_str("\n");
    asm.push_str("    ; Look up anim header from ANIM_ADDR_TABLE[index * 2]\n");
    asm.push_str("    TFR X,D              ; D = anim index\n");
    asm.push_str("    ASLB                 ; *2 for FDB entries\n");
    asm.push_str("    ROLA\n");
    asm.push_str("    LDX #ANIM_ADDR_TABLE\n");
    asm.push_str("    LEAX D,X             ; X points to FDB entry\n");
    asm.push_str("    LDX ,X               ; X = _ANIM_XXX header ptr\n");
    asm.push_str("    PSHS X               ; SAVE header ptr — Reset0Ref/Moveto_d may clobber X\n");
    asm.push_str("\n");
    asm.push_str("    ; Position beam at enemy screen coordinates (DRAW_VEC_X/Y set by caller)\n");
    asm.push_str("    JSR $F1AA            ; DP_to_D0 (required before BIOS positioning calls)\n");
    asm.push_str("    JSR Reset0Ref        ; Reset integrators to centre (0, 0)\n");
    asm.push_str("    LDA >DRAW_VEC_Y      ; A = Y position\n");
    asm.push_str("    LDB >DRAW_VEC_X      ; B = X position\n");
    asm.push_str("    JSR Moveto_d         ; Move beam to (Y, X)\n");
    asm.push_str("    JSR $F1AF            ; DP_to_C8 (restore DP before DRAW_ANIM_RUNTIME)\n");
    asm.push_str("    PULS X               ; RESTORE header ptr (Reset0Ref/Moveto_d may have clobbered X)\n");
    asm.push_str("\n");
    asm.push_str("    ; Call animation runtime: X=header, U=state ptr\n");
    asm.push_str("    JSR DRAW_ANIM_RUNTIME\n");
    asm.push_str("    RTS\n");
    asm.push_str("\n");

    asm
}
fn generate_play_music_banked_wrapper() -> String {
    let mut asm = String::new();
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; PLAY_MUSIC_BANKED - Play music asset with automatic bank switching\n");
    asm.push_str("; Input: X = music asset index (0-based)\n");
    asm.push_str("; Uses: A, B, X\n");
    asm.push_str("; Note: Music data is COPIED to RAM, so bank switch is temporary\n");
    asm.push_str(";***************************************************************************\n");
    asm.push_str("PLAY_MUSIC_BANKED:\n");
    asm.push_str("    ; Save index to U register (avoid stack order issues)\n");
    asm.push_str("    TFR X,U              ; U = music index\n");
    asm.push_str("    ; Save context: original bank on stack\n");
    asm.push_str("    LDA CURRENT_ROM_BANK\n");
    asm.push_str("    PSHS A               ; Stack: [A]\n");
    asm.push_str("\n");
    asm.push_str("    ; CRITICAL: Read BOTH lookup tables BEFORE switching banks!\n");
    asm.push_str("    ; (Tables are in Bank 31, which is always visible at $4000+)\n");
    asm.push_str("\n");
    asm.push_str("    ; Get music's bank from lookup table (BEFORE switch)\n");
    asm.push_str("    TFR U,D              ; D = music index (from U)\n");
    asm.push_str("    LDX #MUSIC_BANK_TABLE\n");
    asm.push_str("    LDA D,X              ; A = bank ID for this music\n");
    asm.push_str("    STA >PSG_MUSIC_BANK  ; Save bank for AUDIO_UPDATE (multibank)\n");
    asm.push_str("    PSHS A               ; Save bank ID on stack temporarily\n");
    asm.push_str("\n");
    asm.push_str("    ; Get music's address from lookup table (BEFORE switch)\n");
    asm.push_str("    TFR U,D              ; Reload music index from U\n");
    asm.push_str("    ASLB                 ; *2 for FDB entries\n");
    asm.push_str("    ROLA\n");
    asm.push_str("    LDX #MUSIC_ADDR_TABLE\n");
    asm.push_str("    LEAX D,X             ; X points to address entry\n");
    asm.push_str("    LDX ,X               ; X = actual music address in banked ROM\n");
    asm.push_str("    PSHS X               ; Save music address on stack\n");
    asm.push_str("\n");
    asm.push_str("    ; NOW switch to music's bank\n");
    asm.push_str("    LDA 2,S              ; Get bank ID from stack (behind X)\n");
    asm.push_str("    STA CURRENT_ROM_BANK ; Update RAM tracker\n");
    asm.push_str("    STA $DF00            ; Switch bank hardware register\n");
    asm.push_str("\n");
    asm.push_str("    ; Restore music address and call runtime\n");
    asm.push_str("    PULS X               ; X = music address (now valid in switched bank)\n");
    asm.push_str("    LEAS 1,S             ; Discard bank ID from stack\n");
    asm.push_str("\n");
    asm.push_str("    ; Call PLAY_MUSIC_RUNTIME with X pointing to music data\n");
    asm.push_str("    JSR PLAY_MUSIC_RUNTIME\n");
    asm.push_str("\n");
    asm.push_str("    ; Restore original bank from stack\n");
    asm.push_str("    PULS A               ; A = original bank\n");
    asm.push_str("    STA CURRENT_ROM_BANK\n");
    asm.push_str("    STA $DF00            ; Restore bank\n");
    asm.push_str("\n");
    asm.push_str("    RTS\n");
    asm.push_str("\n");
    
    asm
}

/// Generate the PLAY_SFX_BANKED runtime wrapper for helpers bank
fn generate_play_sfx_banked_wrapper() -> String {
    let mut asm = String::new();
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; PLAY_SFX_BANKED - Play SFX asset with automatic bank switching\n");
    asm.push_str("; Input: X = SFX asset index (0-based)\n");
    asm.push_str("; Uses: A, B, X\n");
    asm.push_str(";***************************************************************************\n");
    asm.push_str("PLAY_SFX_BANKED:\n");
    asm.push_str("    ; Save index to U register (avoid stack order issues)\n");
    asm.push_str("    TFR X,U              ; U = SFX index\n");
    asm.push_str("    ; Save context: original bank on stack\n");
    asm.push_str("    LDA CURRENT_ROM_BANK\n");
    asm.push_str("    PSHS A               ; Stack: [A]\n");
    asm.push_str("\n");
    asm.push_str("    ; Get SFX's bank from lookup table\n");
    asm.push_str("    TFR U,D              ; D = SFX index (from U)\n");
    asm.push_str("    LDX #SFX_BANK_TABLE\n");
    asm.push_str("    LDA D,X              ; A = bank ID for this SFX\n");
    asm.push_str("    STA CURRENT_ROM_BANK ; Update RAM tracker\n");
    asm.push_str("    STA >SFX_BANK        ; Save SFX bank for AUDIO_UPDATE\n");
    asm.push_str("    STA $DF00            ; Switch bank hardware register\n");
    asm.push_str("\n");
    asm.push_str("    ; Get SFX's address from lookup table (2 bytes per entry)\n");
    asm.push_str("    TFR U,D              ; Reload SFX index from U\n");
    asm.push_str("    ASLB                 ; *2 for FDB entries\n");
    asm.push_str("    ROLA\n");
    asm.push_str("    LDX #SFX_ADDR_TABLE\n");
    asm.push_str("    LEAX D,X             ; X points to address entry\n");
    asm.push_str("    LDX ,X               ; X = actual SFX address in banked ROM\n");
    asm.push_str("\n");
    asm.push_str("    ; Call PLAY_SFX_RUNTIME with X pointing to SFX data\n");
    asm.push_str("    JSR PLAY_SFX_RUNTIME\n");
    asm.push_str("\n");
    asm.push_str("    ; Restore original bank from stack\n");
    asm.push_str("    PULS A               ; A = original bank\n");
    asm.push_str("    STA CURRENT_ROM_BANK\n");
    asm.push_str("    STA $DF00            ; Restore bank\n");
    asm.push_str("\n");
    asm.push_str("    RTS\n");
    asm.push_str("\n");
    
    asm
}

/// Generate the LOAD_LEVEL_BANKED runtime wrapper for helpers bank
fn generate_load_level_banked_wrapper() -> String {
    let mut asm = String::new();
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; LOAD_LEVEL_BANKED - Load level asset with automatic bank switching\n");
    asm.push_str("; Input: X = Level asset index (0-based)\n");
    asm.push_str("; Output: LEVEL_PTR, LEVEL_WIDTH, LEVEL_HEIGHT set\n");
    asm.push_str("; Uses: A, B, X, Y\n");
    asm.push_str(";***************************************************************************\n");
    asm.push_str("LOAD_LEVEL_BANKED:\n");
    asm.push_str("    ; Save level index to U register, save context to stack\n");
    asm.push_str("    TFR X,U              ; U = level index\n");
    asm.push_str("    LDA CURRENT_ROM_BANK\n");
    asm.push_str("    PSHS A               ; Stack: [A] - Only save original bank\n");
    asm.push_str("\n");
    asm.push_str("    ; Get level's bank from lookup table\n");
    asm.push_str("    TFR U,D              ; D = level index (from U)\n");
    asm.push_str("    LDX #LEVEL_BANK_TABLE\n");
    asm.push_str("    LDA D,X              ; A = bank ID for this level\n");
    asm.push_str("    STA CURRENT_ROM_BANK ; Update RAM tracker\n");
    asm.push_str("    STA >LEVEL_BANK      ; Save level bank for SHOW/UPDATE_LEVEL_RUNTIME\n");
    asm.push_str("    STA $DF00            ; Switch bank hardware register\n");
    asm.push_str("\n");
    asm.push_str("    ; Get level's address from lookup table (2 bytes per entry)\n");
    asm.push_str("    TFR U,D              ; Reload level index from U\n");
    asm.push_str("    ASLB                 ; *2 for FDB entries\n");
    asm.push_str("    ROLA\n");
    asm.push_str("    LDX #LEVEL_ADDR_TABLE\n");
    asm.push_str("    LEAX D,X             ; X points to address entry\n");
    asm.push_str("    LDX ,X               ; X = actual level address in banked ROM\n");
    asm.push_str("\n");
    asm.push_str("    ; Full level init: call LOAD_LEVEL_RUNTIME with X = level address\n");
    asm.push_str("    ; (level bank is active, LOAD_LEVEL_RUNTIME code is in fixed helpers bank)\n");
    asm.push_str("    JSR LOAD_LEVEL_RUNTIME\n");
    asm.push_str("\n");
    asm.push_str("    ; Restore original bank from stack\n");
    asm.push_str("    PULS A               ; A = original bank\n");
    asm.push_str("    STA CURRENT_ROM_BANK\n");
    asm.push_str("    STA $DF00            ; Restore bank\n");
    asm.push_str("\n");
    asm.push_str("    LDD #1               ; Return success\n");
    asm.push_str("    STD RESULT\n");
    asm.push_str("\n");
    asm.push_str("    RTS\n");
    asm.push_str("\n");

    asm
}

/// Generate the SPAWN_ENEMIES_BANKED runtime wrapper for helpers bank
fn generate_spawn_enemies_banked_wrapper() -> String {
    let mut asm = String::new();

    asm.push_str(";***************************************************************************\n");
    asm.push_str("; SPAWN_ENEMIES_BANKED - Spawn enemies using level data with bank switching\n");
    asm.push_str("; Reads LEVEL_BANK, LEVEL_ENEMY_COUNT, LEVEL_ENEMY_INSTANCES_PTR from RAM\n");
    asm.push_str("; (all three set by LOAD_LEVEL_BANKED/LOAD_LEVEL_RUNTIME)\n");
    asm.push_str("; Uses: A, B, X, Y\n");
    asm.push_str(";***************************************************************************\n");
    asm.push_str("SPAWN_ENEMIES_BANKED:\n");
    asm.push_str("    LDB >LEVEL_ENEMY_COUNT\n");
    asm.push_str("    BEQ SEB_DONE             ; no enemies in this level\n");
    asm.push_str("    LDA CURRENT_ROM_BANK\n");
    asm.push_str("    PSHS A                   ; save current bank\n");
    asm.push_str("    LDA >LEVEL_BANK\n");
    asm.push_str("    STA CURRENT_ROM_BANK\n");
    asm.push_str("    STA $DF00                ; switch to level bank\n");
    asm.push_str("    LDX >LEVEL_ENEMY_INSTANCES_PTR\n");
    asm.push_str("    JSR SPAWN_ENEMIES_RUNTIME ; B=count, X=instances ptr\n");
    asm.push_str("    PULS A\n");
    asm.push_str("    STA CURRENT_ROM_BANK\n");
    asm.push_str("    STA $DF00                ; restore bank\n");
    asm.push_str("SEB_DONE:\n");
    asm.push_str("    RTS\n");
    asm.push_str("\n");

    asm
}

/// Generate compact 3D data tables for all vector assets used by DRAW_VECTOR_3D.
/// These are emitted in bank_00 so the fixed helpers bank runtime can always read them
/// (helpers bank runs with the calling bank still mapped at $0000-$3FFF).
pub fn generate_3d_data_asm(assets: &[AssetInfo]) -> String {
    let mut out = String::new();
    let vec_assets: Vec<_> = assets.iter().filter(|a| matches!(a.asset_type, AssetType::Vector)).collect();
    if vec_assets.is_empty() {
        return out;
    }
    out.push_str(";***************************************************************************\n");
    out.push_str("; 3D COMPACT DATA TABLES (for DRAW_VECTOR_3D)\n");
    out.push_str(";***************************************************************************\n\n");
    for asset in vec_assets {
        match crate::vecres::VecResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                out.push_str(&resource.compile_to_3d_asm_with_name(Some(&asset.name)));
                out.push_str("\n");
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load vector asset for 3D table '{}': {}", asset.name, e);
            }
        }
    }
    out
}

// ─── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::{compile_vrec, generate_draw_anim_banked_wrapper, VrecResource};

    const VREC_JSON: &str = r#"{
        "version": "1.0",
        "name": "clip",
        "fps": 12,
        "frames": [
            { "segments": [
                { "x0": -50, "y0": 10, "x1": 30, "y1": 20, "i": 95 },
                { "x0": 200, "y0": -200, "x1": 0, "y1": 0, "i": 300 }
            ] },
            { "segments": [
                { "x0": 0, "y0": 0, "x1": 10, "y1": 10, "i": 1 }
            ] }
        ]
    }"#;

    /// compile_vrec must emit the CHAINED MC6809 table: frame_count word,
    /// absolute frame pointers, per-frame chain_count word, and per-chain
    /// [start_x,start_y,intensity,seg_count] + i8 deltas, clamped to i8 / 0-127.
    #[test]
    fn test_compile_vrec_m6809_chained_layout() {
        let vrec: VrecResource = serde_json::from_str(VREC_JSON).unwrap();
        let asm = compile_vrec(&vrec, "clip");

        assert!(asm.contains("_CLIP_VREC:\n    FDB 2    ; frame_count"),
            "missing frame_count:\n{asm}");
        assert!(asm.contains("FDB _CLIP_VREC_F0"), "missing frame 0 pointer:\n{asm}");
        assert!(asm.contains("FDB _CLIP_VREC_F1"), "missing frame 1 pointer:\n{asm}");
        // Frame 0: two disjoint segments → 2 chains.
        assert!(asm.contains("_CLIP_VREC_F0:\n    FDB 2    ; chain_count"),
            "frame 0 must have 2 chains:\n{asm}");
        // Frame 1: one segment → 1 chain.
        assert!(asm.contains("_CLIP_VREC_F1:\n    FDB 1    ; chain_count"),
            "frame 1 must have 1 chain:\n{asm}");
        // Chain 0 header: start=(-50,10)=($CE,$0A), i=95=$5F, seg_count=1.
        assert!(asm.contains("FCB $CE,$0A,$5F,$01"),
            "chain 0 header bytes wrong:\n{asm}");
        // Chain 0 delta: (30-(-50), 20-10) = (80,10) = ($50,$0A).
        assert!(asm.contains("FCB $50,$0A    ; d=(80,10)"),
            "chain 0 delta wrong:\n{asm}");
        // Chain 1 header clamped: start 200→127($7F), -200→-127($81), i 300→127($7F), seg_count 1.
        assert!(asm.contains("FCB $7F,$81,$7F,$01"),
            "chain 1 clamped header wrong:\n{asm}");
        // Chain 1 delta clamped: (0-200, 0-(-200)) = (-200,200) → (-127,127) = ($81,$7F).
        assert!(asm.contains("FCB $81,$7F    ; d=(-127,127)"),
            "chain 1 clamped delta wrong:\n{asm}");
    }

    /// A closed square (4 chained segments) must emit ONE chain of 4 deltas.
    /// Body size: 4 (start_x,start_y,i,seg_count) + 4*2 deltas = 12 bytes,
    /// vs the old per-segment layout's 5*4 = 20 bytes. Extrapolated to a
    /// 20-line closed contour: 4 + 40 = 44 bytes (chained) vs 100 (old).
    #[test]
    fn test_compile_vrec_closed_square_single_chain() {
        let json = r#"{ "fps": 10, "frames": [ { "segments": [
            { "x0": -40, "y0": -40, "x1":  40, "y1": -40, "i": 90 },
            { "x0":  40, "y0": -40, "x1":  40, "y1":  40, "i": 90 },
            { "x0":  40, "y0":  40, "x1": -40, "y1":  40, "i": 90 },
            { "x0": -40, "y0":  40, "x1": -40, "y1": -40, "i": 90 }
        ] } ] }"#;
        let vrec: VrecResource = serde_json::from_str(json).unwrap();
        let asm = compile_vrec(&vrec, "sq");

        assert!(asm.contains("_SQ_VREC_F0:\n    FDB 1    ; chain_count"),
            "closed square must be a single chain:\n{asm}");
        // start=(-40,-40)=($D8,$D8), i=90=$5A, seg_count=4.
        assert!(asm.contains("FCB $D8,$D8,$5A,$04"), "chain header wrong:\n{asm}");
        // 4 deltas: (80,0),(0,80),(-80,0),(0,-80).
        assert!(asm.contains("FCB $50,$00    ; d=(80,0)"), "delta 0 wrong:\n{asm}");
        assert!(asm.contains("FCB $00,$50    ; d=(0,80)"), "delta 1 wrong:\n{asm}");
        assert!(asm.contains("FCB $B0,$00    ; d=(-80,0)"), "delta 2 wrong:\n{asm}");
        assert!(asm.contains("FCB $00,$B0    ; d=(0,-80)"), "delta 3 wrong:\n{asm}");
    }

    /// Regression test for Bug 2: DRAW_ANIM_BANKED must save X on the stack
    /// before the Vectrex BIOS calls (Reset0Ref, Moveto_d) that may clobber it,
    /// and restore it afterwards so that DRAW_ANIM_RUNTIME receives the correct
    /// animation header pointer.
    ///
    /// Previously, X was loaded with the animation header pointer and then the
    /// BIOS calls ran *before* X was saved.  If Reset0Ref or Moveto_d corrupted
    /// X, DRAW_ANIM_RUNTIME received a garbage header — causing it to loop for
    /// thousands of iterations, hanging the frame and making the level invisible.
    #[test]
    fn test_draw_anim_banked_saves_x_around_bios_calls() {
        let asm = generate_draw_anim_banked_wrapper();

        let pshs_x_pos   = asm.find("PSHS X").expect("PSHS X must be present in DRAW_ANIM_BANKED");
        let reset0_pos   = asm.find("Reset0Ref").expect("Reset0Ref must be present in DRAW_ANIM_BANKED");
        let puls_x_pos   = asm.find("PULS X").expect("PULS X must be present in DRAW_ANIM_BANKED");
        // Use the JSR instruction, not the symbol in comments/docs
        let dar_pos      = asm.find("JSR DRAW_ANIM_RUNTIME").expect("JSR DRAW_ANIM_RUNTIME must be present in DRAW_ANIM_BANKED");

        assert!(
            pshs_x_pos < reset0_pos,
            "Bug 2 regression: PSHS X must come before Reset0Ref (positions: {} vs {})",
            pshs_x_pos, reset0_pos
        );
        assert!(
            puls_x_pos > reset0_pos,
            "Bug 2 regression: PULS X must come after Reset0Ref (positions: {} vs {})",
            puls_x_pos, reset0_pos
        );
        assert!(
            puls_x_pos < dar_pos,
            "Bug 2 regression: PULS X must come before DRAW_ANIM_RUNTIME (positions: {} vs {})",
            puls_x_pos, dar_pos
        );
    }
}
