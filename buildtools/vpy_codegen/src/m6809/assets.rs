//! Asset discovery and generation
//! Handles .vec, .vmus, .vlevel, and .vsfx resources

use std::path::{Path, PathBuf};
use std::fs;
use std::collections::HashSet;
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

    // Filter assets to only those referenced in code (or used by levels)
    assets.iter()
        .filter(|asset| used_names.contains(&asset.name))
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
            if up == "DRAW_VECTOR" || up == "DRAW_VECTOR_EX" || 
               up == "PLAY_MUSIC" || up == "PLAY_SFX" || up == "LOAD_LEVEL" {
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

/// Calculate sizes and generate ASM for all assets
pub fn prepare_assets_with_sizes(assets: &[AssetInfo]) -> Vec<SizedAsset> {
    let mut sized_assets = Vec::new();
    
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Vector)) {
        match crate::vecres::VecResource::load(Path::new(&asset.path)) {
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
    
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Level)) {
        match crate::levelres::VPlayLevel::load(Path::new(&asset.path)) {
            Ok(resource) => {
                let asm_code = resource.compile_to_asm();
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
) -> AssetDistribution {
    use std::collections::HashMap;
    
    let sized_assets = prepare_assets_with_sizes(assets);
    let mut bank_assignments: HashMap<u8, Vec<SizedAsset>> = HashMap::new();
    let mut bank_sizes: HashMap<u8, usize> = HashMap::new();
    
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
    
    // First-Fit Decreasing bin packing: larger assets first
    let mut sorted_assets = sized_assets;
    sorted_assets.sort_by(|a, b| b.binary_size.cmp(&a.binary_size));
    
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
    
    // Generate vector assets
    for asset in assets.iter().filter(|a| matches!(a.asset_type, AssetType::Vector)) {
        match crate::vecres::VecResource::load(Path::new(&asset.path)) {
            Ok(resource) => {
                out.push_str(&resource.compile_to_asm_with_name(Some(&asset.name)));
            },
            Err(e) => {
                eprintln!("[WARNING] Failed to load vector asset '{}': {}", asset.name, e);
            }
        }
    }
    
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
                out.push_str(&resource.compile_to_asm());
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
    
    Ok(out)
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
) -> Result<(std::collections::HashMap<u8, String>, String), String> {
    use std::collections::HashMap;
    
    // Distribute assets across banks 1..(helpers_bank-1)
    // Bank 0 has main code, helpers_bank has runtime
    let distribution = distribute_assets(assets, bank_size, 1, helpers_bank.saturating_sub(1));
    
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
            // Use pre-generated ASM code
            asm.push_str(&asset.asm_code);
            asm.push_str("\n");
            
            // Track for lookup table with correct label suffix based on type
            let symbol_name = asset.info.name.to_uppercase().replace("-", "_").replace(" ", "_");
            let label = match asset.info.asset_type {
                AssetType::Vector => format!("_{}_VECTORS", symbol_name),
                AssetType::Music => format!("_{}_MUSIC", symbol_name),
                AssetType::Sfx => format!("_{}_SFX", symbol_name),
                AssetType::Level => format!("_{}_LEVEL", symbol_name),
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

    // Sort each list alphabetically by name for index consistency
    let mut vector_entries = vector_entries;
    let mut music_entries = music_entries;
    let mut sfx_entries = sfx_entries;
    let mut level_entries = level_entries;
    vector_entries.sort_by(|a, b| a.0.cmp(&b.0));
    music_entries.sort_by(|a, b| a.0.cmp(&b.0));
    sfx_entries.sort_by(|a, b| a.0.cmp(&b.0));
    level_entries.sort_by(|a, b| a.0.cmp(&b.0));
    
    // Generate lookup tables for helpers bank
    let mut lookup_asm = String::new();
    lookup_asm.push_str(";***************************************************************************\n");
    lookup_asm.push_str("; ASSET LOOKUP TABLES (for banked asset access)\n");
    lookup_asm.push_str(&format!("; Total: {} vectors, {} music, {} sfx, {} levels\n", 
        vector_entries.len(), music_entries.len(), sfx_entries.len(), level_entries.len()));
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
    
    Ok((bank_asm, lookup_asm))
}

/// Generate the DRAW_VECTOR_BANKED runtime wrapper for helpers bank
fn generate_draw_vector_banked_wrapper() -> String {
    let mut asm = String::new();
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; DRAW_VECTOR_BANKED - Draw vector asset with automatic bank switching\n");
    asm.push_str("; Input: X = asset index (0-based), DRAW_VEC_X/Y set for position\n");
    asm.push_str("; Uses: A, B, X, Y\n");
    asm.push_str("; Preserves: CURRENT_ROM_BANK (restored after drawing)\n");
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
    asm.push_str("    ; Set up for drawing\n");
    asm.push_str("    CLR MIRROR_X\n");
    asm.push_str("    CLR MIRROR_Y\n");
    asm.push_str("    CLR DRAW_VEC_INTENSITY\n");
    asm.push_str("    JSR $F1AA            ; DP_to_D0\n");
    asm.push_str("\n");
    asm.push_str("    ; Loop over all paths (header byte 0 = path_count, +1.. = FDB table)\n");
    asm.push_str("    LDB ,X               ; B = path_count\n");
    asm.push_str("    LBEQ DVB_DONE        ; No paths\n");
    asm.push_str("    LEAY 1,X             ; Y = pointer to first FDB entry\n");
    asm.push_str("DVB_PATH_LOOP:\n");
    asm.push_str("    PSHS B               ; Save remaining path count\n");
    asm.push_str("    LDX ,Y               ; X = path data address (FDB entry)\n");
    asm.push_str("    JSR Draw_Sync_List_At_With_Mirrors\n");
    asm.push_str("    LEAY 2,Y             ; Advance to next FDB entry\n");
    asm.push_str("    PULS B               ; Restore count\n");
    asm.push_str("    DECB\n");
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

/// Generate the PLAY_MUSIC_BANKED runtime wrapper for helpers bank
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
