//! Runtime Helper Functions
//!
//! Mathematical and utility functions

use vpy_parser::{Module, Item, Stmt, Expr, BinOp};
use std::collections::HashSet;
use super::ram_layout::RamLayout;

/// Analyze module to detect which runtime helpers are needed
/// Returns set of helper names that should be emitted
pub fn analyze_module_helpers(module: &Module) -> HashSet<String> {
    let mut needed = HashSet::new();

    // Scan all functions in module
    for item in &module.items {
        if let Item::Function(func) = item {
            for stmt in &func.body {
                analyze_stmt_for_helpers(stmt, &mut needed);
            }
        }
    }

    needed
}

/// Generate RAM definitions and array data (called BEFORE user functions)
/// Returns tuple: (ASM string, RamLayout for later use by generate_helpers)
pub fn generate_ram_and_arrays(module: &Module, assets: &[crate::AssetInfo]) -> Result<String, String> {
    let mut asm = String::new();
    
    // Analyze module to detect which helpers are needed (for RAM allocation)
    let needed = analyze_module_helpers(module);
    
    // Create RamLayout for RAM variable allocation
    let mut ram = RamLayout::new(0xC880); // Start at $C880 (Vectrex RAM: $C800-$CBFF)
    
    // Core scratch variables (always needed)
    ram.allocate("RESULT", 2, "Main result temporary");
    // NOTE: TMPVAL is an alias for RESULT - both use the same memory location for efficiency
    ram.allocate("TMPVAL", 2, "Temporary value storage (alias for RESULT)");
    ram.allocate("TMPPTR", 2, "Temporary pointer");
    ram.allocate("TMPPTR2", 2, "Temporary pointer 2");
    ram.allocate("VPY_MOVE_X", 1, "MOVE() current X offset (signed byte, 0 by default)");
    ram.allocate("VPY_MOVE_Y", 1, "MOVE() current Y offset (signed byte, 0 by default)");
    ram.allocate("TEMP_YX", 2, "Temporary Y/X coordinate storage");
    ram.allocate("BTN_PREV_STATE", 1, "Button edge-detection: holds bit 7,6,5,4 = prev press state for btn 1,2,3,4");
    ram.allocate("BTN_RAW", 1, "Raw PSG reg 14 (active-LOW: 0=pressed, 1=released) - Vectorblade pattern");
    
    // Conditional variables based on usage
    if needed.contains("PRINT_NUMBER") {
        ram.allocate("NUM_STR", 6, "Buffer for PRINT_NUMBER decimal output (5 digits + terminator)");
    }
    if needed.contains("RAND") || needed.contains("RAND_HELPER") {
        ram.allocate("RAND_SEED", 2, "Random seed for RAND()");
    }
    
    // Drawing helper variables
    // NOTE: Check both DRAW_CIRCLE and DRAW_CIRCLE_RUNTIME because the analysis may add either
    if needed.contains("DRAW_CIRCLE") || needed.contains("DRAW_CIRCLE_RUNTIME") {
        ram.allocate("DRAW_CIRCLE_XC", 1, "Circle center X");
        ram.allocate("DRAW_CIRCLE_YC", 1, "Circle center Y");
        ram.allocate("DRAW_CIRCLE_DIAM", 1, "Circle diameter");
        ram.allocate("DRAW_CIRCLE_INTENSITY", 1, "Circle intensity");
        ram.allocate("DRAW_CIRCLE_RADIUS", 1, "Circle radius (diam/2) - used in segment drawing");
        ram.allocate("DRAW_CIRCLE_TEMP", 8, "Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r");
    }
    
    // NOTE: Check both DRAW_RECT and DRAW_RECT_RUNTIME
    if needed.contains("DRAW_RECT") || needed.contains("DRAW_RECT_RUNTIME") {
        ram.allocate("DRAW_RECT_X", 1, "Rectangle X");
        ram.allocate("DRAW_RECT_Y", 1, "Rectangle Y");
        ram.allocate("DRAW_RECT_WIDTH", 1, "Rectangle width");
        ram.allocate("DRAW_RECT_HEIGHT", 1, "Rectangle height");
        ram.allocate("DRAW_RECT_INTENSITY", 1, "Rectangle intensity");
    }
    
    // DRAW_VEC_INTENSITY always needed: SET_INTENSITY writes to it unconditionally
    ram.allocate("DRAW_VEC_INTENSITY", 1, "Vector intensity override (0=use vector data)");

    // DRAW_VECTOR / DRAW_VECTOR_EX variables (CRITICAL - MISSING!)
    if needed.contains("DRAW_VECTOR") || needed.contains("DRAW_VECTOR_EX") {
        ram.allocate("DRAW_VEC_X_HI", 1, "Vector draw X high byte (16-bit screen_x)");
        ram.allocate("DRAW_VEC_X", 1, "Vector draw X offset");
        ram.allocate("DRAW_VEC_Y", 1, "Vector draw Y offset");

        // CRITICAL FIX: Add padding to prevent collision with TEMP_YX (usually allocated at offset 6)
        ram.allocate("MIRROR_PAD", 16, "Safety padding to prevent MIRROR flag corruption");

        ram.allocate("MIRROR_X", 1, "X mirror flag (0=normal, 1=flip)");
        ram.allocate("MIRROR_Y", 1, "Y mirror flag (0=normal, 1=flip)");
        // SLR_DRAW_CLIPPED_PATH state — used by both SHOW_LEVEL and DRAW_VECTOR_BANKED
        // for 16-bit X clipping. Allocate here too in case SHOW_LEVEL isn't used.
        if !needed.contains("SHOW_LEVEL_RUNTIME") {
            ram.allocate("SLR_CUR_X", 1, "DRAW_VECTOR: clamped (visible) beam X for clipping");
            ram.allocate("SLR_TRUE_X", 2, "DRAW_VECTOR: 16-bit unclamped abs_x for line clipping");
            ram.allocate("DRAW_T1_SCALED", 1, "DRAW_VECTOR: T1 scale ($7F default for non-SHOW_LEVEL)");
            ram.allocate("SDCP_ABS_Y", 1, "DRAW_VECTOR: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt SHOW_LEVEL's top_screen between layers)");
        }
    }
    
    // DRAW_VECTOR_3D rotation scratch variables
    if needed.contains("DRAW_VECTOR_3D") {
        ram.allocate("ROT3D_AX", 1, "3D raw angle X (0-127)");
        ram.allocate("ROT3D_AY", 1, "3D raw angle Y (0-127)");
        ram.allocate("ROT3D_AZ", 1, "3D raw angle Z (0-127)");
        // ROT3D_COS_X/Y/Z repurposed: now store (angle+32)&0x7F for cos-offset LUT lookup
        // (sin angle is ROT3D_AX/AY/AZ directly; cos = sin(angle+32))
        ram.allocate("ROT3D_COS_X", 1, "3D cos angle offset for X axis: (AX+32)&0x7F");
        ram.allocate("ROT3D_COS_Y", 1, "3D cos angle offset for Y axis: (AY+32)&0x7F");
        ram.allocate("ROT3D_COS_Z", 1, "3D cos angle offset for Z axis: (AZ+32)&0x7F");
        ram.allocate("ROT3D_OX", 1, "3D draw X offset");
        ram.allocate("ROT3D_OY", 1, "3D draw Y offset");
        ram.allocate("ROT3D_PC", 1, "3D path/vertex count remaining");
        ram.allocate("ROT3D_PT_REM", 1, "3D remaining points in current path");
        ram.allocate("ROT3D_CLOSED", 1, "3D path closed flag");
        ram.allocate("ROT3D_RX", 1, "3D raw x");
        ram.allocate("ROT3D_RY", 1, "3D raw y");
        ram.allocate("ROT3D_RZ", 1, "3D raw z");
        ram.allocate("ROT3D_Y1", 1, "3D intermediate y after X-axis rotation");
        ram.allocate("ROT3D_Z1", 1, "3D intermediate z after X-axis rotation");
        ram.allocate("ROT3D_X2", 1, "3D intermediate x after Y-axis rotation");
        ram.allocate("ROT3D_SCR_X", 1, "3D final screen x");
        ram.allocate("ROT3D_SCR_Y", 1, "3D final screen y");
        ram.allocate("ROT3D_PREV_X", 1, "3D previous screen x");
        ram.allocate("ROT3D_PREV_Y", 1, "3D previous screen y");
        ram.allocate("ROT3D_FIRST_X", 1, "3D first screen x (for closed path)");
        ram.allocate("ROT3D_FIRST_Y", 1, "3D first screen y (for closed path)");
        ram.allocate("ROT3D_TEMP", 1, "3D rotation temp 1");
        ram.allocate("ROT3D_TEMP2", 1, "3D rotation temp 2");
        // Rotated vertex cache: up to 127 unique vertices × 2 bytes (x', y')
        ram.allocate("ROT3D_VBUF", 254, "3D rotated vertex cache (127 verts × 2 bytes: x',y')");
    }

    // DRAW_LINE argument buffer (10 bytes: x0, y0, x1, y1, intensity)
    ram.allocate("DRAW_LINE_ARGS", 10, "DRAW_LINE argument buffer (x0,y0,x1,y1,intensity)");
    
    // DRAW_LINE segmentation variables (always needed if DRAW_LINE exists)
    // FIX (2026-01-18): Both remaining variables need 2 bytes (16-bit) for segment 2
    ram.allocate("VLINE_DX_16", 2, "DRAW_LINE dx (16-bit)");
    ram.allocate("VLINE_DY_16", 2, "DRAW_LINE dy (16-bit)");
    ram.allocate("VLINE_DX", 1, "DRAW_LINE dx clamped (8-bit)");
    ram.allocate("VLINE_DY", 1, "DRAW_LINE dy clamped (8-bit)");
    ram.allocate("VLINE_DY_REMAINING", 2, "DRAW_LINE remaining dy for segment 2 (16-bit)");
    ram.allocate("VLINE_DX_REMAINING", 2, "DRAW_LINE remaining dx for segment 2 (16-bit)");
    
    // Level system variables (vplay-aware)
    if needed.contains("SHOW_LEVEL") || needed.contains("SHOW_LEVEL_RUNTIME")
        || needed.contains("LOAD_LEVEL") || needed.contains("LOAD_LEVEL_RUNTIME")
        || needed.contains("UPDATE_LEVEL_RUNTIME")
        || needed.contains("LEVEL_COLLISION_Y_RUNTIME")
        || needed.contains("LEVEL_COLLISION_X_RUNTIME")
    {
        ram.allocate("LEVEL_PTR", 2, "Pointer to currently loaded level header");
        ram.allocate("LEVEL_LOADED", 1, "Level loaded flag (0=not loaded, 1=loaded)");
        // Legacy tile-based vars (kept for backward compat / GET_LEVEL_WIDTH etc.)
        ram.allocate("LEVEL_WIDTH", 1, "Level width (legacy tile API)");
        ram.allocate("LEVEL_HEIGHT", 1, "Level height (legacy tile API)");
        ram.allocate("LEVEL_TILE_SIZE", 1, "Tile size (legacy tile API)");
        ram.allocate("LEVEL_Y_IDX", 1, "SHOW_LEVEL row counter (legacy)");
        ram.allocate("LEVEL_X_IDX", 1, "SHOW_LEVEL column counter (legacy)");
        ram.allocate("LEVEL_TEMP", 1, "SHOW_LEVEL temporary byte (legacy)");
        // vplay layer counts and ROM pointers
        ram.allocate("LEVEL_BG_COUNT", 1, "BG object count");
        ram.allocate("LEVEL_GP_COUNT", 1, "GP object count");
        ram.allocate("LEVEL_FG_COUNT", 1, "FG object count");
        ram.allocate("CAMERA_X", 2, "Camera X scroll offset (16-bit signed world units)");
        ram.allocate("CAMERA_Y", 2, "Camera Y scroll offset (16-bit signed world units)");
        ram.allocate("SCROLL_LIMIT_LEFT",   2, "Camera scroll limit: left world X");
        ram.allocate("SCROLL_LIMIT_RIGHT",  2, "Camera scroll limit: right world X");
        ram.allocate("SCROLL_LIMIT_TOP",    2, "Camera scroll limit: top world Y");
        ram.allocate("SCROLL_LIMIT_BOTTOM", 2, "Camera scroll limit: bottom world Y");
        ram.allocate("LEVEL_BG_ROM_PTR", 2, "BG layer ROM pointer");
        ram.allocate("LEVEL_GP_ROM_PTR", 2, "GP layer ROM pointer");
        ram.allocate("LEVEL_FG_ROM_PTR", 2, "FG layer ROM pointer");
        ram.allocate("LEVEL_GP_PTR", 2, "GP active pointer (RAM buffer after LOAD_LEVEL)");
        ram.allocate("LEVEL_BANK", 1, "Bank ID for current level (for multibank)");
        ram.allocate("LEVEL_ENEMY_COUNT", 1, "Enemy count from current level header");
        ram.allocate("LEVEL_ENEMY_INSTANCES_PTR", 2, "Ptr to enemy instances table in level bank");
        // Per-screen object index (SHOW_LEVEL perf): from level header +34..+40
        ram.allocate("LEVEL_SCREEN_COUNT", 1, "Total Y screens partitioning the level");
        ram.allocate("LEVEL_BG_SCREENS_PTR", 2, "Per-screen BG index ptr (3 bytes per screen)");
        ram.allocate("LEVEL_GP_SCREENS_PTR", 2, "Per-screen GP index ptr");
        ram.allocate("LEVEL_FG_SCREENS_PTR", 2, "Per-screen FG index ptr");
        // SHOW_LEVEL_RUNTIME draw temps (shared with DRAW_VECTOR if not already allocated)
        if !needed.contains("DRAW_VECTOR") && !needed.contains("DRAW_VECTOR_EX") {
            ram.allocate("DRAW_VEC_X_HI", 1, "SHOW_LEVEL: vector draw X high byte (16-bit)");
            ram.allocate("DRAW_VEC_X", 1, "SHOW_LEVEL: vector draw X");
            ram.allocate("DRAW_VEC_Y", 1, "SHOW_LEVEL: vector draw Y");
            ram.allocate("MIRROR_X", 1, "SHOW_LEVEL: mirror X flag");
            ram.allocate("MIRROR_Y", 1, "SHOW_LEVEL: mirror Y flag");
            ram.allocate("DRAW_VEC_INTENSITY", 1, "SHOW_LEVEL: intensity override");
        }
        // Clipped-path draw loop tracker
        ram.allocate("SLR_CUR_X", 1, "SHOW_LEVEL: clamped (visible) beam X — actually written to integrator");
        ram.allocate("SLR_TRUE_X", 2, "SHOW_LEVEL: 16-bit unclamped abs_x for per-segment line clipping");
        ram.allocate("DRAW_T1_SCALED", 1, "SHOW_LEVEL: effective T1 for current object (DRAW_SCALE * object_scale)");
        ram.allocate("SDCP_ABS_Y", 1, "SHOW_LEVEL: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt top_screen between layers)");
        ram.allocate("SLR_TOP_SCREEN", 1, "SHOW_LEVEL: top Y screen idx (lives across all 3 layers — must not be in TMPVAL)");
        ram.allocate("SLR_BOT_SCREEN", 1, "SHOW_LEVEL: bot Y screen idx (lives across all 3 layers)");
        // GP objects RAM buffer + GP-GP/GP-FG physics scratch — only used by
        // UPDATE_LEVEL_RUNTIME. Gated so games that don't call UPDATE_LEVEL don't
        // pay 480+ bytes of RAM (critical on the 1KB M6809 target).
        if needed.contains("UPDATE_LEVEL_RUNTIME") {
            ram.allocate("LEVEL_GP_BUFFER", 32 * 15, "GP objects RAM buffer (max 32 objects × 15 bytes)");
        }
        // LEVEL_COLLISION_Y input/scratch variables
        ram.allocate("LCOL_PX", 2, "LEVEL_COLLISION player world_x input (16-bit)");
        ram.allocate("LCOL_BEST_Y", 2, "LEVEL_COLLISION_Y best floor y found (16-bit signed)");
        ram.allocate("LCOL_PY", 2, "LEVEL_COLLISION player_top (16-bit signed)");
        ram.allocate("LCOL_PHH", 1, "LEVEL_COLLISION player half_height");
        ram.allocate("LCOL_PHW", 1, "LEVEL_COLLISION_X player half_width");
        ram.allocate("LCOL_THW", 1, "LEVEL_COLLISION_X total half_width (player_hw + obj_hw scratch)");
        // LEVEL_COLLISION_Y mesh ray-cast scratch
        ram.allocate("LCOL_OBJ_Y", 2, "LEVEL_COLLISION_Y current object world_y (16-bit)");
        ram.allocate("LCOL_LOCAL_PX", 2, "LEVEL_COLLISION_Y player_x in object-local coords (16-bit)");
        ram.allocate("LCOL_OBJ_CNT", 1, "LEVEL_COLLISION_Y GP objects remaining");
        ram.allocate("LCOL_SEG_CNT", 1, "LEVEL_COLLISION_Y mesh floor segments remaining");
        // Physics / collision temporaries (GP-GP and GP-FG) — only used by
        // UPDATE_LEVEL_RUNTIME, gated to save RAM on the M6809 target.
        if needed.contains("UPDATE_LEVEL_RUNTIME") {
            ram.allocate("UGPC_OUTER_IDX", 1, "GP-GP outer loop index");
            ram.allocate("UGPC_OUTER_MAX", 1, "GP-GP outer loop max (count-1)");
            ram.allocate("UGPC_INNER_IDX", 1, "GP-GP inner loop index");
            ram.allocate("UGPC_DX", 2, "GP-GP |dx| (16-bit)");
            ram.allocate("UGPC_DIST", 2, "GP-GP Manhattan distance (16-bit)");
            ram.allocate("UGFC_GP_IDX", 1, "GP-FG outer loop GP index");
            ram.allocate("UGFC_FG_COUNT", 1, "GP-FG inner loop FG count");
            ram.allocate("UGFC_DX", 1, "GP-FG |dx|");
            ram.allocate("UGFC_DY", 1, "GP-FG |dy|");
        }
    }

    // Enemy system variables
    if needed.contains("ENEMY_SYSTEM") || needed.contains("SPAWN_ENEMIES")
        || needed.contains("UPDATE_ENEMIES") || needed.contains("DRAW_ENEMIES")
    {
        let max_enemies: usize = module.meta.max_enemies.unwrap_or(8) as usize;
        // M6809 has only 1KB of RAM (mirrored across $C800-$CFFF). The enemy pool
        // lives high in RAM and must not overflow past the $CBFF mirror boundary,
        // so the M6809 target caps MAX_ENEMIES at 10 (10 * 17 = 170 bytes).
        if max_enemies > 10 {
            return Err(format!(
                "META MAX_ENEMIES = {max_enemies} exceeds the M6809 limit of 10 \
                 (1KB RAM constraint). Lower MAX_ENEMIES to 10 or less for the Vectrex/6809 target."
            ));
        }
        const ENEMY_STRIDE: usize = 28;
        ram.allocate("ENEMY_POOL", max_enemies * ENEMY_STRIDE,
            "Enemy instances pool (Phase 2 wander: +18 sub_state, +19 cur_area_idx, +20 idle_timer, +21 trans_type, +22..23 target_x, +24..25 vy/from_x, +26 feet_offset × N)");
        ram.allocate("ENEMY_LOOP_IDX", 1, "Enemy loop counter");
        ram.allocate("ENEMY_COUNT", 1, "Active enemy count");
        ram.allocate("ENEMY_SCRATCH_PTR", 2, "Scratch pointer for enemy iteration");
        ram.allocate("ENEMY_SCRATCH_X", 2, "Enemy scratch X");
        ram.allocate("ENEMY_SCRATCH_Y", 2, "Enemy scratch Y");

        // Allocate 2-byte animation state RAM for each vanim action across all enemy types.
        // Named ANIM_ENEMY_{TYPE}_{ACTION}_STATE and referenced by FDB in the action table.
        for asset in assets.iter().filter(|a| matches!(a.asset_type, crate::AssetType::Enemy)) {
            if let Ok(resource) = crate::venemy::EnemyResource::load(std::path::Path::new(&asset.path)) {
                for action in &resource.actions {
                    let ext = std::path::Path::new(&action.sprite)
                        .extension()
                        .and_then(|e| e.to_str())
                        .unwrap_or("");
                    if ext == "vanim" && !action.sprite.is_empty() {
                        let type_up = asset.name
                            .to_uppercase()
                            .replace(' ', "_")
                            .replace('-', "_");
                        let action_up = action.name
                            .to_uppercase()
                            .replace(' ', "_")
                            .replace('-', "_");
                        let var_name = format!("ANIM_ENEMY_{}_{}_STATE", type_up, action_up);
                        ram.allocate(
                            &var_name,
                            2,
                            &format!("Enemy '{}' action '{}' animation state (frame_idx, ticks_left)", asset.name, action.name),
                        );
                    }
                }
            }
        }
    }

    // Text scale (2 bytes): written by SET_TEXT_SIZE, read by VECTREX_PRINT_TEXT/NUMBER
    // Vec_Text_Height ($C82A): signed byte, -n (default $F8 = -8 = normal)
    // Vec_Text_Width ($C82B): unsigned byte, n*9 (default 72 = $48 = normal)
    if needed.contains("PRINT_TEXT") || needed.contains("PRINT_NUMBER") {
        ram.allocate("TEXT_SCALE_H", 1, "Character height for Print_Str_d (default $F8 = -8, normal)");
        ram.allocate("TEXT_SCALE_W", 1, "Character width for Print_Str_d (default $48 = 72, normal)");
    }
    // PRINT_NUMBER caching: last-rendered value + flag so repeated calls with
    // same value skip DIVMOD + Print_Str setup.
    if needed.contains("PRINT_NUMBER") {
        ram.allocate("PN_LAST_VAL", 2, "PRINT_NUMBER: last rendered numeric value (cache key)");
        ram.allocate("PN_LAST_VALID", 1, "PRINT_NUMBER: 1 if PN_LAST_VAL holds a valid render");
        ram.allocate("PN_LAST_X", 1, "PRINT_NUMBER: last rendered X (cache key)");
        ram.allocate("PN_LAST_Y", 1, "PRINT_NUMBER: last rendered Y (cache key)");
    }

    // NOTE: VAR_ARG0-4 and CURRENT_ROM_BANK are now allocated AFTER user variables
    // (see below, after generate_user_variables). This prevents collision when
    // user variable arrays grow past $CB80 (BUG FIX 2026-05-11).

    // NOTE: Audio system variables are allocated AFTER user variables (see below)
    // to prevent overlap with mutable array data buffers.
    use crate::m6809::functions::has_audio_calls;

    if needed.contains("BEEP") {
        ram.allocate("BEEP_FRAMES_LEFT", 1, "Beep countdown timer (frames remaining)");
    }

    // NOTE_STATE: per-channel state for PLAY_NOTE / NOTE_UPDATE_RUNTIME
    // 10 bytes × 3 channels = 30 bytes
    if crate::m6809::functions::has_note_calls(module) {
        ram.allocate("NOTE_STATE", 30, "Pitched note state (10 bytes x 3 channels)");
        ram.allocate("NOTE_ARG_INSTR", 2, "PLAY_NOTE argument: instrument ROM block address");
        ram.allocate("NOTE_ARG_CHANNEL", 1, "PLAY_NOTE argument: channel (0/1/2)");
        ram.allocate("NOTE_ARG_NOTE", 1, "PLAY_NOTE argument: MIDI note (24-107)");
    }

    // Animation state: 2 bytes per unique animation name used via DRAW_ANIM()
    // byte 0 = current frame_idx, byte 1 = ticks_remaining
    for key in needed.iter() {
        if let Some(anim_sym) = key.strip_prefix("DRAW_ANIM_STATE_") {
            ram.allocate(
                &format!("ANIM_{}_STATE", anim_sym),
                2,
                &format!("DRAW_ANIM state for {} (frame_idx, ticks_left)", anim_sym),
            );
        }
    }

    if needed.contains("DRAW_ANIM_RUNTIME") {
        ram.allocate("DRAW_ANIM_MIRROR_X", 1, "DRAW_ANIM mirror X flag (0=normal, 1=flip)");
        ram.allocate("DRAW_ANIM_SCALE", 1, "DRAW_ANIM T1 scale ($7F=normal)");
        ram.allocate("DRAW_ANIM_SPEED_MUL", 1, "DRAW_ANIM tick multiplier (1=normal)");
    }
    // DRAW_SCALE needed whenever Draw_Sync_List_At_With_Mirrors is used
    if needed.contains("DRAW_ANIM_RUNTIME") || needed.contains("SHOW_LEVEL_RUNTIME")
        || needed.contains("DRAW_VECTOR") || needed.contains("DRAW_VECTOR_EX") {
        ram.allocate("DRAW_SCALE", 1, "Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal)");
    }

    if module.meta.interleaved_frames.is_some() {
        ram.allocate("FRAME_PARITY", 1, "Interleaved frame group counter");
    }

    // =========================================================================
    // FUNCTION ARGUMENT SLOTS — allocated EARLY so they always live inside the
    // 1KB Vectrex RAM window ($C800-$CBFF). When allocated last in a program
    // with many globals (e.g. SnowBros), VAR_ARG0-4 fell into $CC00+, which
    // aliases to $C800+ (BIOS music workspace). Each PLAY_MUSIC would then
    // corrupt VAR_ARG between every frame, breaking PRINT_NUMBER, function
    // calls, etc.
    // CURRENT_ROM_BANK has the same problem in multibank ROMs.
    // =========================================================================
    ram.allocate("VAR_ARG0", 2, "Function argument 0 (16-bit)");
    ram.allocate("VAR_ARG1", 2, "Function argument 1 (16-bit)");
    ram.allocate("VAR_ARG2", 2, "Function argument 2 (16-bit)");
    ram.allocate("VAR_ARG3", 2, "Function argument 3 (16-bit)");
    ram.allocate("VAR_ARG4", 2, "Function argument 4 (16-bit)");
    ram.allocate("VAR_ARG5", 2, "Function argument 5 (16-bit)");
    ram.allocate("VAR_ARG6", 2, "Function argument 6 (16-bit)");
    ram.allocate("VAR_ARG7", 2, "Function argument 7 (16-bit)");
    ram.allocate("CURRENT_ROM_BANK", 1, "Current ROM bank ID (multibank tracking)");

    // =========================================================================
    // USER VARIABLES (continue allocation after system vars)
    // =========================================================================

    // Generate user variables using the same RamLayout instance
    let user_vars_result = crate::m6809::variables::generate_user_variables(module, &mut ram)?;

    // =========================================================================
    // AUDIO SYSTEM VARIABLES (allocated AFTER all user vars to prevent overlap)
    // BUG FIX (2026-05-11): Previously hardcoded at $CBEB which overlapped with
    // mutable array data buffers (e.g. joystick1_state[6] at $CBE4-$CBEF).
    // Now dynamically allocated after user vars to guarantee no collision.
    // =========================================================================
    if has_audio_calls(module) {
        ram.allocate("PSG_MUSIC_PTR", 2, "PSG music data pointer");
        ram.allocate("PSG_MUSIC_START", 2, "PSG music start pointer (for loops)");
        ram.allocate("PSG_MUSIC_ACTIVE", 1, "PSG music active flag");
        ram.allocate("PSG_IS_PLAYING", 1, "PSG playing flag");
        ram.allocate("PSG_DELAY_FRAMES", 1, "PSG frame delay counter");
        ram.allocate("PSG_MUSIC_BANK", 1, "PSG music bank ID (for multibank)");
        ram.allocate("SFX_PTR", 2, "SFX data pointer");
        ram.allocate("SFX_ACTIVE", 1, "SFX active flag");
        ram.allocate("SFX_BANK", 1, "SFX bank ID (for multibank)");
    }

    // (VAR_ARG0-4 + CURRENT_ROM_BANK already allocated above, before user vars.)

    // =========================================================================
    // EMIT EQU DEFINITIONS
    // =========================================================================
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; === RAM VARIABLE DEFINITIONS ===\n");
    asm.push_str(";***************************************************************************\n");
    asm.push_str(&ram.emit_equ_definitions());
    asm.push_str(&crate::m6809::variables::emit_array_len_equates(module));

    // CRITICAL FIX (2026-01-18): Emit array data BEFORE code
    // Arrays must be defined before first use to avoid forward references in single-pass assembler
    asm.push_str(&crate::m6809::variables::emit_array_data(module));
    
    // NOTE (2026-01-19): emit_array_aliases() is no longer needed
    // We now use context::is_mutable_array() to determine the correct label at emit time
    // This avoids EQU forward reference issues with the assembler
    
    // Emit user variable internal definitions (builtin aliases)
    asm.push_str(&user_vars_result);
    asm.push_str("\n");
    
    Ok(asm)
}

/// Recursively analyze statement for helper usage
fn analyze_stmt_for_helpers(stmt: &Stmt, needed: &mut HashSet<String>) {
    match stmt {
        Stmt::Expr(expr, _) => analyze_expr_for_helpers(expr, needed),
        Stmt::Assign { value, .. } => analyze_expr_for_helpers(value, needed),
        Stmt::If { cond, body, elifs, else_body, .. } => {
            analyze_expr_for_helpers(cond, needed);
            for s in body {
                analyze_stmt_for_helpers(s, needed);
            }
            for (elif_cond, elif_body) in elifs {
                analyze_expr_for_helpers(elif_cond, needed);
                for s in elif_body {
                    analyze_stmt_for_helpers(s, needed);
                }
            }
            if let Some(else_stmts) = else_body {
                for s in else_stmts {
                    analyze_stmt_for_helpers(s, needed);
                }
            }
        }
        Stmt::While { cond, body, .. } => {
            analyze_expr_for_helpers(cond, needed);
            for s in body {
                analyze_stmt_for_helpers(s, needed);
            }
        }
        Stmt::Return(Some(expr), _) => analyze_expr_for_helpers(expr, needed),
        _ => {}
    }
}

/// Recursively analyze expression for helper usage
fn analyze_expr_for_helpers(expr: &Expr, needed: &mut HashSet<String>) {
    match expr {
        // Builtin calls that may need runtime helpers
        Expr::Call(call_info) => {
            let name_upper = call_info.name.to_uppercase();
            let args = &call_info.args;
            
            // Text/Number printing
            if name_upper == "PRINT_TEXT" {
                needed.insert("PRINT_TEXT".to_string());
            }
            if name_upper == "PRINT_NUMBER" {
                needed.insert("PRINT_NUMBER".to_string());
            }
            
            // Drawing helpers: Always needed when called (even with constant args)
            if name_upper == "DRAW_CIRCLE" {
                needed.insert("DRAW_CIRCLE".to_string());
                needed.insert("DRAW_CIRCLE_RUNTIME".to_string());
            }
            if name_upper == "DRAW_RECT" {
                needed.insert("DRAW_RECT".to_string());
                needed.insert("DRAW_RECT_RUNTIME".to_string());
            }
            if name_upper == "DRAW_LINE" {
                needed.insert("DRAW_LINE_WRAPPER".to_string());
            }
            if name_upper == "DRAW_VECTOR" {
                needed.insert("DRAW_VECTOR".to_string());
            }
            if name_upper == "DRAW_VECTOR_EX" {
                needed.insert("DRAW_VECTOR_EX".to_string());
            }
            if name_upper == "DRAW_VECTOR_3D" {
                needed.insert("DRAW_VECTOR_3D".to_string());
                needed.insert("DRAW_VECTOR".to_string()); // for DRAW_VEC_X/Y RAM vars
            }
            
            // Joystick helpers: Always needed when called
            if name_upper == "J1_X" {
                needed.insert("J1X_BUILTIN".to_string());
            }
            if name_upper == "J1_Y" {
                needed.insert("J1Y_BUILTIN".to_string());
            }
            if name_upper == "J2_X" {
                needed.insert("J2X_BUILTIN".to_string());
            }
            if name_upper == "J2_Y" {
                needed.insert("J2Y_BUILTIN".to_string());
            }
            
            // Level system helpers
            if name_upper == "SHOW_LEVEL" {
                needed.insert("SHOW_LEVEL_RUNTIME".to_string());
                // SHOW_LEVEL_RUNTIME calls Draw_Sync_List_At_With_Mirrors,
                // which is emitted in drawing.rs when DRAW_VECTOR is in needed.
                needed.insert("DRAW_VECTOR".to_string());
            }
            if name_upper == "LOAD_LEVEL" {
                needed.insert("LOAD_LEVEL".to_string());
                needed.insert("LOAD_LEVEL_RUNTIME".to_string());
            }
            if name_upper == "UPDATE_LEVEL" {
                needed.insert("UPDATE_LEVEL_RUNTIME".to_string());
            }
            if name_upper == "LEVEL_COLLISION_Y" {
                needed.insert("LEVEL_COLLISION_Y_RUNTIME".to_string());
            }
            if name_upper == "LEVEL_COLLISION_X" {
                needed.insert("LEVEL_COLLISION_X_RUNTIME".to_string());
            }
            if name_upper == "GET_LEVEL_FLOOR_Y" {
                // Multibank emits a JSR to this helper instead of inlining the
                // bank-switch (which would self-corrupt PC from switchable banks).
                // Single-bank inline path doesn't need it. See emit_get_level_floor_y.
                needed.insert("GET_LEVEL_FLOOR_Y_RUNTIME".to_string());
            }
            
// Math helpers: Need runtime if operands contain variables
            if name_upper == "SQRT" && has_variable_args(args) {
                needed.insert("SQRT_HELPER".to_string());
                needed.insert("DIV16".to_string()); // SQRT uses DIV16
            }
            if name_upper == "POW" && has_variable_args(args) {
                needed.insert("POW_HELPER".to_string());
            }
            if name_upper == "ATAN2" && has_variable_args(args) {
                needed.insert("ATAN2_HELPER".to_string());
            }
            if name_upper == "RAND" {
                needed.insert("RAND_HELPER".to_string());
            }
            if name_upper == "RAND_RANGE" {
                needed.insert("RAND_RANGE_HELPER".to_string());
                needed.insert("RAND_HELPER".to_string()); // RAND_RANGE uses RAND
            }
            if name_upper == "BEEP" {
                needed.insert("BEEP".to_string());
            }

            if name_upper == "DRAW_ANIM" {
                needed.insert("DRAW_ANIM_RUNTIME".to_string());
                needed.insert("DRAW_VECTOR".to_string()); // for DRAW_VEC_X/Y RAM vars
                // Record which animation names are used (for state RAM allocation)
                if let Some(Expr::StringLit(anim_name)) = args.first() {
                    needed.insert(format!("DRAW_ANIM_STATE_{}", anim_name.to_uppercase().replace('-', "_").replace(' ', "_")));
                }
            }

            // Enemy system helpers
            if name_upper == "SPAWN_ENEMIES" || name_upper == "UPDATE_ENEMIES" || name_upper == "DRAW_ENEMIES" {
                needed.insert("SPAWN_ENEMIES".to_string());
                needed.insert("UPDATE_ENEMIES".to_string());
                needed.insert("DRAW_ENEMIES".to_string());
                needed.insert("DRAW_VECTOR".to_string()); // for DRAW_VEC_X/Y RAM vars
                // Enemies may have vanim actions → always include DRAW_ANIM_RUNTIME so its
                // RAM variables (DRAW_ANIM_MIRROR_X, DRAW_ANIM_SCALE, DRAW_SCALE, …) are allocated
                // and the DRAW_ANIM_RUNTIME subroutine is emitted into the helpers bank.
                needed.insert("DRAW_ANIM_RUNTIME".to_string());
                // Wander enemies use RAND_HELPER for randomized idle pauses
                needed.insert("RAND_HELPER".to_string());
            }

            // Recursively analyze arguments
            for arg in args {
                analyze_expr_for_helpers(arg, needed);
            }
        }
        
        // Binary operations that may need math helpers
        Expr::Binary { left, op, right } => {
            // Check if operands are variables (not constants)
            let left_is_const = matches!(**left, Expr::Number(_));
            let right_is_const = matches!(**right, Expr::Number(_));
            
            if !left_is_const || !right_is_const {
                match op {
                    BinOp::Mul => { needed.insert("MUL16".to_string()); }
                    BinOp::Div | BinOp::FloorDiv => { needed.insert("DIV16".to_string()); }
                    BinOp::Mod => { needed.insert("MOD16".to_string()); }
                    _ => {}
                }
            }
            
            analyze_expr_for_helpers(left, needed);
            analyze_expr_for_helpers(right, needed);
        }
        
        // Other expression types (Not and BitNot are unary operations)
        Expr::Not(operand) | Expr::BitNot(operand) => analyze_expr_for_helpers(operand, needed),
        Expr::Index { target, index } => {
            analyze_expr_for_helpers(target, needed);
            analyze_expr_for_helpers(index, needed);
        }
        Expr::List(items) => {
            for item in items {
                analyze_expr_for_helpers(item, needed);
            }
        }
        _ => {}
    }
}

/// Check if any argument is not a constant (i.e., contains variables)
fn has_variable_args(args: &[Expr]) -> bool {
    args.iter().any(|arg| !matches!(arg, Expr::Number(_) | Expr::StringLit(_)))
}

/// Get BIOS function address from VECTREX.I
/// Returns the address as a hex string (e.g., "$F1AA")
/// Falls back to hardcoded value if VECTREX.I cannot be read
fn get_bios_address(symbol_name: &str, fallback_address: &str) -> String {
    // Try to get from VECTREX.I
    let possible_paths = vec![
        "ide/frontend/public/include/VECTREX.I",
        "../ide/frontend/public/include/VECTREX.I",
        "../../ide/frontend/public/include/VECTREX.I",
        "./ide/frontend/public/include/VECTREX.I",
    ];
    
    for path in &possible_paths {
        if let Ok(content) = std::fs::read_to_string(path) {
            // Parse VECTREX.I to find the symbol
            for line in content.lines() {
                let line = line.trim();
                if line.is_empty() || line.starts_with(';') {
                    continue;
                }
                
                // Parse lines like: "Wait_Recal  EQU     $F192"
                if let Some(equ_pos) = line.find("EQU") {
                    let name_part = line[..equ_pos].trim();
                    let value_part = line[equ_pos + 3..].trim();
                    
                    if name_part.eq_ignore_ascii_case(symbol_name) {
                        // Extract just the address (e.g., "$F1AA" or "$F1AA   ; comment")
                        if let Some(addr) = value_part.split_whitespace().next() {
                            if addr.starts_with('$') || addr.starts_with("0x") {
                                return addr.to_string();
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Fallback to hardcoded value
    fallback_address.to_string()
}

pub fn generate_helpers(module: &Module, is_multibank: bool, assets: &[crate::AssetInfo]) -> Result<String, String> {
    let mut asm = String::new();

    // Import has_audio_calls for audio helper detection
    use crate::m6809::functions::has_audio_calls;

    // Analyze module to detect which helpers are needed
    let needed = analyze_module_helpers(module);
    
    // Get BIOS function addresses from VECTREX.I
    let dp_to_c8 = get_bios_address("DP_to_C8", "$F1AF");
    
    // NOTE: RAM allocation and EQU definitions are now handled by generate_ram_and_arrays()
    // which is called BEFORE user functions in mod.rs
    // This ensures arrays are defined before first use
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; RUNTIME HELPERS\n");
    asm.push_str(";***************************************************************************\n\n");
    
    // VECTREX_PRINT_TEXT — BIOS Print_Str_d (bitmap scan-line rendering via
    // VIA shift register; cannot be matched by vector-per-stroke approaches).
    if needed.contains("PRINT_TEXT") || needed.contains("PRINT_NUMBER") {
        asm.push_str("VECTREX_PRINT_TEXT:\n");
        asm.push_str("    ; VPy signature: PRINT_TEXT(x, y, string)\n");
        asm.push_str("    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)\n");
        asm.push_str("    LDA #$D0\n");
        asm.push_str("    TFR A,DP\n");
        asm.push_str("    JSR Intensity_5F\n");
        asm.push_str("    JSR Reset0Ref\n");
        asm.push_str("    LDU >VAR_ARG2\n");
        asm.push_str("    LDA >TEXT_SCALE_H\n");
        asm.push_str("    STA >$C82A          ; Vec_Text_Height\n");
        asm.push_str("    LDA >TEXT_SCALE_W\n");
        asm.push_str("    STA >$C82B          ; Vec_Text_Width\n");
        asm.push_str("    LDA >VAR_ARG1+1\n");
        asm.push_str("    LDB >VAR_ARG0+1\n");
        asm.push_str("    LDX >$C82C\n");
        asm.push_str("    PSHS X\n");
        asm.push_str("    JSR Print_Str_d\n");
        asm.push_str("    PULS X\n");
        asm.push_str("    STX >$C82C\n");
        asm.push_str("    LDA #$F8\n");
        asm.push_str("    STA >$C82A\n");
        asm.push_str("    LDA #$48\n");
        asm.push_str("    STA >$C82B\n");
        asm.push_str(&format!("    JSR {}\n", dp_to_c8));
        asm.push_str("    RTS\n\n");
    }

    
    // VECTREX_PRINT_NUMBER: Print number at position (CONDITIONAL)
    // Only emit if PRINT_NUMBER is actually used in code
    if needed.contains("PRINT_NUMBER") {
        asm.push_str("VECTREX_PRINT_NUMBER:\n");
        asm.push_str("    ; Print signed decimal number (-9999 to 9999)\n");
        asm.push_str("    ; ARG0=x, ARG1=y, ARG2=value\n");
        asm.push_str("    ;\n");
        asm.push_str("    ; CACHE CHECK: if (value,x,y) matches the previous render, skip the\n");
        asm.push_str("    ; entire DIVMOD pipeline (saves ~200 cycles) and reuse NUM_STR as-is.\n");
        asm.push_str("    ; Drawing must still happen every frame (phosphor decay) so we go\n");
        asm.push_str("    ; straight to PN_AFTER_CONVERT with NUM_STR already populated.\n");
        asm.push_str("    LDA >PN_LAST_VALID\n");
        asm.push_str("    BEQ .PN_NO_CACHE       ; first call → must convert\n");
        asm.push_str("    LDD >VAR_ARG2\n");
        asm.push_str("    CMPD >PN_LAST_VAL\n");
        asm.push_str("    BNE .PN_NO_CACHE\n");
        asm.push_str("    LDA >VAR_ARG0+1\n");
        asm.push_str("    CMPA >PN_LAST_X\n");
        asm.push_str("    BNE .PN_NO_CACHE\n");
        asm.push_str("    LDA >VAR_ARG1+1\n");
        asm.push_str("    CMPA >PN_LAST_Y\n");
        asm.push_str("    BNE .PN_NO_CACHE\n");
        asm.push_str("    LBRA .PN_AFTER_CONVERT  ; cache hit — NUM_STR still valid\n");
        asm.push_str(".PN_NO_CACHE:\n");
        asm.push_str("    ; Update cache key BEFORE conversion (value/x/y will be needed later)\n");
        asm.push_str("    LDD >VAR_ARG2\n");
        asm.push_str("    STD >PN_LAST_VAL\n");
        asm.push_str("    LDA >VAR_ARG0+1\n");
        asm.push_str("    STA >PN_LAST_X\n");
        asm.push_str("    LDA >VAR_ARG1+1\n");
        asm.push_str("    STA >PN_LAST_Y\n");
        asm.push_str("    LDA #1\n");
        asm.push_str("    STA >PN_LAST_VALID\n");
        asm.push_str("    ;\n");
        asm.push_str("    ; STEP 1: Convert number to decimal string (DP=$C8)\n");
        asm.push_str("    LDD >VAR_ARG2   ; Load 16-bit value (safe: DP=$C8)\n");
        asm.push_str("    STD >TMPVAL      ; Save to temp\n");
        asm.push_str("    LDX #NUM_STR    ; String buffer pointer\n");
        asm.push_str("    \n");
        asm.push_str("    ; Check sign: negative values get '-' prefix and are negated\n");
        asm.push_str("    CMPD #0\n");
        asm.push_str("    BPL .PN_DIV1000  ; D >= 0: go directly to digit conversion\n");
        asm.push_str("    LDA #'-'\n");
        asm.push_str("    STA ,X+          ; Store '-', advance buffer pointer\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    COMA\n");
        asm.push_str("    COMB\n");
        asm.push_str("    ADDD #1          ; Two's complement negation -> absolute value\n");
        asm.push_str("    STD >TMPVAL\n");
        asm.push_str("    \n");
        asm.push_str("    ; --- 1000s digit ---\n");
        asm.push_str(".PN_DIV1000:\n");
        asm.push_str("    CLR ,X           ; Counter = 0 (in buffer)\n");
        asm.push_str(".PN_L1000:\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    SUBD #1000\n");
        asm.push_str("    BMI .PN_D1000\n");
        asm.push_str("    STD >TMPVAL      ; Store reduced value\n");
        asm.push_str("    INC ,X           ; Increment digit counter\n");
        asm.push_str("    BRA .PN_L1000\n");
        asm.push_str(".PN_D1000:\n");
        asm.push_str("    LDA ,X           ; Get count\n");
        asm.push_str("    ADDA #'0'        ; Convert to ASCII\n");
        asm.push_str("    STA ,X+          ; Store and advance\n");
        asm.push_str("    \n");
        asm.push_str("    ; --- 100s digit ---\n");
        asm.push_str("    CLR ,X\n");
        asm.push_str(".PN_L100:\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    SUBD #100\n");
        asm.push_str("    BMI .PN_D100\n");
        asm.push_str("    STD >TMPVAL\n");
        asm.push_str("    INC ,X\n");
        asm.push_str("    BRA .PN_L100\n");
        asm.push_str(".PN_D100:\n");
        asm.push_str("    LDA ,X\n");
        asm.push_str("    ADDA #'0'\n");
        asm.push_str("    STA ,X+\n");
        asm.push_str("    \n");
        asm.push_str("    ; --- 10s digit ---\n");
        asm.push_str("    CLR ,X\n");
        asm.push_str(".PN_L10:\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    SUBD #10\n");
        asm.push_str("    BMI .PN_D10\n");
        asm.push_str("    STD >TMPVAL\n");
        asm.push_str("    INC ,X\n");
        asm.push_str("    BRA .PN_L10\n");
        asm.push_str(".PN_D10:\n");
        asm.push_str("    LDA ,X\n");
        asm.push_str("    ADDA #'0'\n");
        asm.push_str("    STA ,X+\n");
        asm.push_str("    \n");
        asm.push_str("    ; --- 1s digit (remainder) ---\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    ADDB #'0'        ; Low byte = ones digit\n");
        asm.push_str("    STB ,X+          ; Store digit\n");
        asm.push_str("    LDA #$80          ; Terminator (same format as FCC/FCB $80 strings)\n");
        asm.push_str("    STA ,X\n");
        asm.push_str("    \n");
        asm.push_str("    ; --- RIGHT-ALIGN: shift significant digits LEFT, pad right with spaces ---\n");
        asm.push_str("    ; Keeps the buffer at 4 chars (BIOS Print_Str needs minimum width) but\n");
        asm.push_str("    ; lets the number start at the call's X coordinate. Examples:\n");
        asm.push_str("    ;   PRINT_NUMBER(x, y, 6)    → \"6   \"  (6 at x, then 3 trailing spaces)\n");
        asm.push_str("    ;   PRINT_NUMBER(x, y, 12)   → \"12  \"\n");
        asm.push_str("    ;   PRINT_NUMBER(x, y, 1234) → \"1234\"\n");
        asm.push_str("    ;   PRINT_NUMBER(x, y, -5)   → \"-5  \"\n");
        asm.push_str("    LDX #NUM_STR\n");
        asm.push_str("    LDA ,X\n");
        asm.push_str("    CMPA #'-'           ; if negative, '-' stays at [0]; sig digits start at [1]\n");
        asm.push_str("    BNE .PN_RP_START\n");
        asm.push_str("    LEAX 1,X\n");
        asm.push_str(".PN_RP_START:\n");
        asm.push_str("    TFR X,U             ; U = dest (start of digit area, after optional '-')\n");
        asm.push_str("    LDB #0              ; B = leading-zero count\n");
        asm.push_str(".PN_RP_FIND:\n");
        asm.push_str("    LDA ,X\n");
        asm.push_str("    CMPA #'0'\n");
        asm.push_str("    BNE .PN_RP_FOUND    ; first non-'0' → start of sig digits\n");
        asm.push_str("    LDA 1,X             ; check next byte\n");
        asm.push_str("    CMPA #$80           ; if terminator, current '0' is the units digit — keep it\n");
        asm.push_str("    BEQ .PN_RP_FOUND\n");
        asm.push_str("    INCB\n");
        asm.push_str("    LEAX 1,X\n");
        asm.push_str("    BRA .PN_RP_FIND\n");
        asm.push_str(".PN_RP_FOUND:\n");
        asm.push_str("    TSTB\n");
        asm.push_str("    BEQ .PN_RP_DONE     ; no leading zeros → nothing to shift\n");
        asm.push_str("    ; Copy from X (first sig digit) to U (start), include $80 terminator\n");
        asm.push_str(".PN_RP_COPY:\n");
        asm.push_str("    LDA ,X+\n");
        asm.push_str("    STA ,U+\n");
        asm.push_str("    CMPA #$80\n");
        asm.push_str("    BNE .PN_RP_COPY\n");
        asm.push_str("    ; U is past the copied $80. Back up to that position and overwrite\n");
        asm.push_str("    ; with B spaces, then place new $80 terminator at end.\n");
        asm.push_str("    LEAU -1,U           ; U = where the $80 was just written\n");
        asm.push_str(".PN_RP_PAD:\n");
        asm.push_str("    LDA #' '\n");
        asm.push_str("    STA ,U+\n");
        asm.push_str("    DECB\n");
        asm.push_str("    BNE .PN_RP_PAD\n");
        asm.push_str("    LDA #$80\n");
        asm.push_str("    STA ,U              ; final terminator\n");
        asm.push_str(".PN_RP_DONE:\n");
        asm.push_str(".PN_AFTER_CONVERT:\n");
        asm.push_str("    ; STEP 2: hand the rendered NUM_STR to VECTREX_PRINT_TEXT, which uses\n");
        asm.push_str("    ; the custom vector font path (consistent visual with PiTrex/RP2350).\n");
        asm.push_str("    LDX #NUM_STR\n");
        asm.push_str("    STX >VAR_ARG2     ; PRINT_TEXT reads string ptr from VAR_ARG2\n");
        asm.push_str("    JSR VECTREX_PRINT_TEXT\n");
        asm.push_str("    RTS\n\n");
    }
    
    // Call module-specific runtime helpers with analyzed needed set
    super::math::emit_runtime_helpers(&mut asm, &needed);
    super::joystick::emit_runtime_helpers(&mut asm, &needed);
    super::drawing::emit_runtime_helpers(&mut asm, &needed);
    super::level::emit_runtime_helpers(&mut asm, &needed);
    super::utilities::emit_runtime_helpers(&mut asm, &needed);
    
    // PLAY_MUSIC_RUNTIME and STOP_MUSIC_RUNTIME: Always emit if audio calls exist
    // (has_audio_calls already imported at top of function)
    if has_audio_calls(module) {
        emit_play_music_runtime(&mut asm);
    }

    // AUDIO_UPDATE: Auto-inject if PLAY_MUSIC or PLAY_SFX detected
    if has_audio_calls(module) {
        emit_audio_update_helper(&mut asm, is_multibank);
        emit_play_sfx_runtime(&mut asm);
    }

    // BEEP_UPDATE_RUNTIME: Auto-inject if beep() is used
    if needed.contains("BEEP") {
        emit_beep_update_runtime(&mut asm);
    }

    // NOTE_UPDATE_RUNTIME + PLAY_NOTE_RUNTIME: Auto-inject if PLAY_NOTE is used
    if crate::m6809::functions::has_note_calls(module) {
        emit_note_period_table(&mut asm);
        emit_play_note_runtime(&mut asm);
        emit_note_update_runtime(&mut asm);
    }

    // DRAW_VECTOR_3D_RUNTIME: 3D rotation and drawing
    if needed.contains("DRAW_VECTOR_3D") {
        emit_draw_vector_3d_runtime(&mut asm);
    }

    // DRAW_ANIM_RUNTIME: animation player
    if needed.contains("DRAW_ANIM_RUNTIME") {
        emit_draw_anim_runtime(&mut asm);
    }

    // Enemy system runtime subroutines
    if needed.contains("SPAWN_ENEMIES") || needed.contains("UPDATE_ENEMIES") || needed.contains("DRAW_ENEMIES") {
        let max_enemies = module.meta.max_enemies.unwrap_or(8) as usize;
        // Check if any enemy type uses vanim actions (determines if DRAW_ANIM_BANKED is needed)
        let has_vanim_enemies = assets.iter()
            .filter(|a| matches!(a.asset_type, crate::AssetType::Enemy))
            .any(|a| crate::venemy::EnemyResource::load(std::path::Path::new(&a.path))
                .map(|r| r.actions.iter().any(|act| {
                    std::path::Path::new(&act.sprite).extension()
                        .and_then(|e| e.to_str()).unwrap_or("") == "vanim"
                }))
                .unwrap_or(false));
        emit_enemy_system_runtime(&mut asm, max_enemies, is_multibank, has_vanim_enemies);
    }

    Ok(asm)
}

/// Emit PLAY_MUSIC_RUNTIME and STOP_MUSIC_RUNTIME helpers
/// Called when PLAY_MUSIC() builtin is used in code
fn emit_play_music_runtime(asm: &mut String) {
    asm.push_str(
        "; ============================================================================\n\
        ; PSG DIRECT MUSIC PLAYER (inspired by Christman2024/malbanGit)\n\
        ; ============================================================================\n\
        ; Writes directly to PSG chip using WRITE_PSG sequence\n\
        ;\n\
        ; Music data format (frame-based):\n\
        ;   FCB count           ; Number of register writes this frame\n\
        ;   FCB reg, val        ; PSG register/value pairs\n\
        ;   ...                 ; Repeat for each register\n\
        ;   FCB $FF             ; End marker\n\
        ;\n\
        ; PSG Registers:\n\
        ;   0-1: Channel A frequency (12-bit)\n\
        ;   2-3: Channel B frequency\n\
        ;   4-5: Channel C frequency\n\
        ;   6:   Noise period\n\
        ;   7:   Mixer control (enable/disable channels)\n\
        ;   8-10: Channel A/B/C volume\n\
        ;   11-12: Envelope period\n\
        ;   13:  Envelope shape\n\
        ; ============================================================================\n\
        \n\
        ; RAM variables (defined in SYSTEM RAM VARIABLES section):\n\
        ; PSG_MUSIC_PTR, PSG_MUSIC_START, PSG_IS_PLAYING,\n\
        ; PSG_MUSIC_ACTIVE, PSG_DELAY_FRAMES\n\
        \n\
        ; PLAY_MUSIC_RUNTIME - Start PSG music playback\n\
        ; Input: X = pointer to PSG music data\n\
        PLAY_MUSIC_RUNTIME:\n\
        CMPX >PSG_MUSIC_START   ; Check if already playing this music\n\
        BNE PMr_start_new       ; If different, start fresh\n\
        LDA >PSG_IS_PLAYING     ; Check if currently playing\n\
        BNE PMr_done            ; If playing same song, ignore\n\
PMr_start_new:\n\
        ; Silence PSG before switching tracks (prevents noise bleed-through)\n\
        PSHS X,DP               ; Save music pointer and DP\n\
        LDA #$D0\n\
        TFR A,DP                ; Set DP=$D0 for Sound_Byte\n\
        LDA #7                  ; PSG reg 7 = Mixer\n\
        LDB #$3F                ; All channels disabled (bits 0-5 only; bits 6-7=0=IOA/IOB input!)\n\
        JSR Sound_Byte\n\
        LDA #8                  ; PSG reg 8 = Volume channel A\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #9                  ; PSG reg 9 = Volume channel B\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #10                 ; PSG reg 10 = Volume channel C\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        PULS X,DP               ; Restore music pointer and DP\n\
        STX >PSG_MUSIC_PTR      ; Store current music pointer (force extended)\n\
        STX >PSG_MUSIC_START    ; Store start pointer for loops (force extended)\n\
        CLR >PSG_DELAY_FRAMES   ; Clear delay counter\n\
        LDA #$01\n\
        STA >PSG_IS_PLAYING     ; Mark as playing (extended - var at 0xC8A0)\n\
PMr_done:\n\
        RTS\n\
        \n\
        ; ============================================================================\n\
        ; UPDATE_MUSIC_PSG - Update PSG (call every frame)\n\
        ; Data format per event: FCB delay, FCB count, (FCB reg, FCB val)*N\n\
        ; delay = frames since previous event (0 = apply immediately)\n\
        ; End marker: FCB 0 after last event's count\n\
        ; Loop marker: delay=$FF is treated as loop; OR count=$FF followed by FDB addr\n\
        ; PSG_DELAY_FRAMES counts down to the next event fire point.\n\
        ; PSG_MUSIC_PTR always points to delay byte of next pending event.\n\
        ; ============================================================================\n\
        UPDATE_MUSIC_PSG:\n\
        LDA #$01\n\
        STA >PSG_MUSIC_ACTIVE   ; Mark music system active\n\
        LDA >PSG_IS_PLAYING\n\
        LBEQ PSG_update_done    ; Not playing\n\
        \n\
        ; Check if delay counter is running\n\
        LDA >PSG_DELAY_FRAMES\n\
        BEQ PSG_read_delay      ; Counter=0: time to read next delay byte\n\
        DECA\n\
        STA >PSG_DELAY_FRAMES\n\
        LBNE PSG_update_done    ; Still waiting\n\
        BRA PSG_process_event   ; Counter just hit 0: apply the event\n\
        \n\
        PSG_read_delay:\n\
        LDX >PSG_MUSIC_PTR      ; PTR → delay byte of current event\n\
        LDB ,X+                 ; Consume delay byte, X → count byte\n\
        CMPB #$FF\n\
        LBEQ PSG_music_loop_d   ; $FF as delay = loop command\n\
        STB >PSG_DELAY_FRAMES   ; Store delay count\n\
        STX >PSG_MUSIC_PTR      ; Advance PTR past delay byte (now at count byte)\n\
        BEQ PSG_process_event   ; delay=0: apply immediately\n\
        DEC >PSG_DELAY_FRAMES   ; Decrement once (fires after delay-1 more frames)\n\
        LBRA PSG_update_done    ; Wait\n\
        \n\
        PSG_process_event:\n\
        LDX >PSG_MUSIC_PTR      ; PTR is at count byte\n\
        LDB ,X+\n\
        LBEQ PSG_music_ended    ; Count=0 means end\n\
        CMPB #$FF\n\
        LBEQ PSG_music_loop     ; Count=$FF means loop\n\
        \n\
        PSHS B                  ; Save count on stack\n\
        PSG_write_loop:\n\
        LDA ,X+                 ; Load register number\n\
        LDB ,X+                 ; Load register value\n\
        PSHS X                  ; Save pointer\n\
        \n\
        ; WRITE_PSG sequence (direct VIA access)\n\
        STA VIA_port_a          ; Store register number\n\
        LDA #$19                ; BDIR=1, BC1=1 (LATCH)\n\
        STA VIA_port_b\n\
        LDA #$01                ; BDIR=0, BC1=0 (INACTIVE)\n\
        STA VIA_port_b\n\
        LDA VIA_port_a          ; Read status\n\
        STB VIA_port_a          ; Store data\n\
        LDB #$11                ; BDIR=1, BC1=0 (WRITE)\n\
        STB VIA_port_b\n\
        LDB #$01                ; BDIR=0, BC1=0 (INACTIVE)\n\
        STB VIA_port_b\n\
        \n\
        PULS X                  ; Restore pointer\n\
        PULS B                  ; Get counter\n\
        DECB\n\
        BEQ PSG_event_done      ; Done with this event\n\
        PSHS B                  ; Save counter back\n\
        BRA PSG_write_loop\n\
        \n\
        PSG_event_done:\n\
        STX >PSG_MUSIC_PTR      ; PTR → delay byte of next event\n\
        CLR >PSG_DELAY_FRAMES   ; Trigger PSG_read_delay next frame\n\
        LBRA PSG_update_done\n\
        \n\
        PSG_music_ended:\n\
        CLR >PSG_IS_PLAYING\n\
        ; Silence all 3 PSG channels so the last note doesn't keep ringing\n\
        ; until the next PLAY_MUSIC. DP is already $D0 (set by AUDIO_UPDATE).\n\
        LDA #8                  ; PSG reg 8 = Volume Channel A\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #9                  ; PSG reg 9 = Volume Channel B\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #10                 ; PSG reg 10 = Volume Channel C\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LBRA PSG_update_done\n\
        \n\
        PSG_music_loop:\n\
        ; count=$FF: X points after $FF, at FDB loop address\n\
        LDD ,X\n\
        STD >PSG_MUSIC_PTR\n\
        CLR >PSG_DELAY_FRAMES\n\
        LBRA PSG_update_done\n\
        \n\
        PSG_music_loop_d:\n\
        ; delay=$FF: X points after $FF, at FDB loop address\n\
        LDD ,X\n\
        STD >PSG_MUSIC_PTR\n\
        CLR >PSG_DELAY_FRAMES\n\
        \n\
        PSG_update_done:\n\
        CLR >PSG_MUSIC_ACTIVE   ; Clear flag (music system done)\n\
        RTS\n\
        \n\
        ; ============================================================================\n\
        ; STOP_MUSIC_RUNTIME - Stop music playback\n\
        ; ============================================================================\n\
        STOP_MUSIC_RUNTIME:\n\
        CLR >PSG_IS_PLAYING     ; Clear playing flag\n\
        CLR >PSG_MUSIC_PTR      ; Clear pointer high byte\n\
        CLR >PSG_MUSIC_PTR+1    ; Clear pointer low byte\n\
        ; Mute all PSG channels so the last note doesn't keep sounding\n\
        PSHS DP\n\
        LDA #$D0\n\
        TFR A,DP                ; Set DP=$D0 for Sound_Byte\n\
        LDA #8                  ; PSG reg 8 = Volume Channel A\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #9                  ; PSG reg 9 = Volume Channel B\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #10                 ; PSG reg 10 = Volume Channel C\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        PULS DP\n\
        RTS\n\
        \n"
    );
}

/// Emit AUDIO_UPDATE helper for PSG music + SFX playback
/// Auto-called at end of LOOP_BODY when PLAY_MUSIC/PLAY_SFX detected
/// Uses Sound_Byte BIOS call for PSG writes (DP=$D0 required)
fn emit_audio_update_helper(asm: &mut String, is_multibank: bool) {
    // Common header (no bank-switch code for single-bank)
    asm.push_str(
        "; ============================================================================\n\
        ; AUDIO_UPDATE - Unified music + SFX update (auto-injected after WAIT_RECAL)\n\
        ; ============================================================================\n\
        ; Uses Sound_Byte (BIOS) for PSG writes - compatible with both systems\n\
        ; Sets DP=$D0 once at entry, restores at exit\n\
        \n\
        AUDIO_UPDATE:\n\
        PSHS DP                 ; Save current DP\n\
        LDA #$D0                ; Set DP=$D0 (Sound_Byte requirement)\n\
        TFR A,DP\n\
        \n"
    );

    // Bank-switch block only for multibank projects.
    // Single-bank: emitting PSHS A / STA $DF00 every frame causes spurious
    // bank-switch side-effects in the emulator due to uninitialized RAM data.
    if is_multibank {
        asm.push_str(
            "        ; MULTIBANK: Switch to music's bank before accessing data\n\
            LDA >CURRENT_ROM_BANK   ; Get current bank\n\
            PSHS A                  ; Save on stack\n\
            LDA >PSG_MUSIC_BANK     ; Get music's bank\n\
            CMPA ,S                 ; Compare with current bank\n\
            BEQ AU_BANK_OK          ; Skip switch if same\n\
            STA >CURRENT_ROM_BANK   ; Update RAM tracker\n\
            STA $DF00               ; Switch bank hardware register\n\
            AU_BANK_OK:\n\
            \n"
        );
    }

    // Music player body (common to both single and multibank)
    asm.push_str(
        "        ; UPDATE MUSIC\n\
        LDA >PSG_IS_PLAYING     ; Check if music is playing\n\
        BEQ AU_SKIP_MUSIC       ; Skip if not\n\
        \n\
        ; Check delay counter first\n\
        LDA >PSG_DELAY_FRAMES   ; Load delay counter\n\
        BEQ AU_MUSIC_READ       ; If zero, read next frame data\n\
        DECA                    ; Decrement delay\n\
        STA >PSG_DELAY_FRAMES   ; Store back\n\
        CMPA #0                 ; Check if it just reached zero\n\
        BNE AU_UPDATE_SFX       ; If not zero yet, skip this frame\n\
        \n\
        ; Delay just reached zero, X points to count byte already\n\
        LDX >PSG_MUSIC_PTR      ; Load music pointer (points to count)\n\
        BRA AU_MUSIC_READ_COUNT ; Skip delay read, go straight to count\n\
        \n\
        AU_MUSIC_READ:\n\
        LDX >PSG_MUSIC_PTR      ; Load music pointer\n\
        \n\
        ; Check if we need to read delay or we're ready for count\n\
        ; PSG_DELAY_FRAMES just reached 0, so we read delay byte first\n\
        LDB ,X+                 ; Read delay counter (X now points to count byte)\n\
        CMPB #$FF               ; Check for loop marker\n\
        BEQ AU_MUSIC_LOOP       ; Handle loop\n\
        CMPB #0                 ; Check if delay is 0\n\
        BNE AU_MUSIC_HAS_DELAY  ; If not 0, process delay\n\
        \n\
        ; Delay is 0, read count immediately\n\
        AU_MUSIC_NO_DELAY:\n\
        AU_MUSIC_READ_COUNT:\n\
        LDB ,X+                 ; Read count (number of register writes)\n\
        BEQ AU_MUSIC_ENDED      ; If 0, end of music\n\
        CMPB #$FF               ; Check for loop marker (can appear after delay)\n\
        BEQ AU_MUSIC_LOOP       ; Handle loop\n\
        BRA AU_MUSIC_PROCESS_WRITES\n\
        \n\
        AU_MUSIC_HAS_DELAY:\n\
        ; B has delay > 0, store it and skip to next frame\n\
        DECB                    ; Delay-1 (we consume this frame)\n\
        BEQ AU_MUSIC_READ_COUNT ; delay was 1: X already at count byte, process immediately\n\
        STB >PSG_DELAY_FRAMES   ; Save delay counter\n\
        STX >PSG_MUSIC_PTR      ; Save pointer (X points to count byte)\n\
        BRA AU_UPDATE_SFX       ; Skip reading data this frame\n\
        \n\
        AU_MUSIC_PROCESS_WRITES:\n\
        ; Per-event write loop. Inlined PSG protocol instead of JSR Sound_Byte\n\
        ; (~35 cycles vs ~92 incl JSR/RTS overhead — saves ~57 cycles per\n\
        ; register write). For theme-style music with 8-10 writes per event,\n\
        ; saves ~500-600 cycles per event frame → frees enough budget that the\n\
        ; music event no longer pushes the frame over vsync. Mirrors the BIOS\n\
        ; Sound_Byte protocol exactly (Vectrex VIA bits: BC1=bit3, BDIR=bit4).\n\
        PSHS B                  ; save register-write count on stack for in-place DEC\n\
        AU_MUSIC_WRITE_LOOP:\n\
        LDA ,X+                 ; A = register number\n\
        LDB ,X+                 ; B = register value\n\
        STA VIA_port_a          ; data bus = reg num\n\
        LDA #$19                ; BC1=1, BDIR=1 → LATCH ADDR\n\
        STA VIA_port_b\n\
        LDA #$01                ; back to INACTIVE (BC1=0, BDIR=0)\n\
        STA VIA_port_b\n\
        LDA VIA_port_a          ; READ STATUS — settling delay so PSG finishes\n\
                                ; latching the register address before we drive\n\
                                ; the value. Without this, the PSG occasionally\n\
                                ; writes the new value into the PREVIOUS register\n\
                                ; (audible as glitchy pitch / 'noisy' music,\n\
                                ; especially when other CPU activity perturbs\n\
                                ; the timing between this loop and adjacent code).\n\
        STB VIA_port_a          ; data bus = value\n\
        LDA #$11                ; BC1=0, BDIR=1 → WRITE DATA\n\
        STA VIA_port_b\n\
        LDA #$01                ; back to INACTIVE\n\
        STA VIA_port_b\n\
        DEC ,S                  ; decrement count on stack (in-place; no PSHS/PULS per iter)\n\
        BNE AU_MUSIC_WRITE_LOOP\n\
        LEAS 1,S                ; discard saved count\n\
        \n\
        AU_MUSIC_DONE:\n\
        STX >PSG_MUSIC_PTR      ; Update music pointer\n\
        BRA AU_UPDATE_SFX       ; Now update SFX\n\
        \n\
        AU_MUSIC_ENDED:\n\
        CLR >PSG_IS_PLAYING     ; Stop music\n\
        BRA AU_UPDATE_SFX       ; Continue to SFX\n\
        \n\
        AU_MUSIC_LOOP:\n\
        LDD ,X                  ; Load loop target\n\
        STD >PSG_MUSIC_PTR      ; Set music pointer to loop\n\
        CLR >PSG_DELAY_FRAMES   ; Clear delay on loop\n\
        BRA AU_UPDATE_SFX       ; Continue to SFX\n\
        \n\
        AU_SKIP_MUSIC:\n\
        BRA AU_UPDATE_SFX       ; Skip music, go to SFX\n\
        \n\
        ; UPDATE SFX (channel C: registers 4/5=tone, 6=noise, 10=volume, 7=mixer)\n\
        AU_UPDATE_SFX:\n\
        LDA >SFX_ACTIVE         ; Check if SFX is active\n\
        BEQ AU_DONE             ; Skip if not active\n\
        \n"
    );

    // Multibank SFX: switch to SFX bank before reading SFX data
    if is_multibank {
        asm.push_str(
            "        ; MULTIBANK: Switch to SFX bank before reading SFX data\n\
            LDA >SFX_BANK           ; Get SFX bank ID\n\
            STA >CURRENT_ROM_BANK   ; Update RAM tracker\n\
            STA $DF00               ; Switch bank hardware register\n\
            \n"
        );
    }

    asm.push_str(
        "        JSR sfx_doframe         ; Process one SFX frame (uses Sound_Byte internally)\n\
        \n\
        AU_DONE:\n"
    );

    // Bank-restore block only for multibank
    if is_multibank {
        asm.push_str(
            "        ; MULTIBANK: Restore original bank\n\
            PULS A                  ; Get saved bank from stack\n\
            STA >CURRENT_ROM_BANK   ; Update RAM tracker\n\
            STA $DF00               ; Restore bank hardware register\n"
        );
    }

    asm.push_str(
        "        PULS DP                 ; Restore original DP\n\
        RTS\n\
        \n"
    );
}

// emit_draw_sync_list_at_with_mirrors - Vector drawing with mirror support
pub fn emit_draw_sync_list_at_with_mirrors(out: &mut String) {
    out.push_str(
        "Draw_Sync_List_At_With_Mirrors:\n\
        ; Unified mirror support using flags: MIRROR_X and MIRROR_Y\n\
            ; Conditionally negates X and/or Y coordinates and deltas\n\
            ; NOTE: Caller has DP=$D0 for VIA access — RAM vars need '>' extended addressing\n\
            ; CRITICAL: Do NOT call JSR $F2AB (Intensity_a) here! Intensity_a manipulates\n\
            ; VIA Port B through states $05->$04->$01 which resets the analog hardware\n\
            ; (zero-reference sequence) and would disrupt the beam position mid-drawing.\n\
            ; Instead we replicate only the VIA Port A write + Port B Z-axis strobe inline.\n\
            LDA ,X+                 ; Read per-path intensity from vector data\n\
DSWM_SET_INTENSITY:\n\
            TST >DRAW_VEC_INTENSITY  ; 0 = no override, use FCB value\n\
            BEQ DSWM_USE_FCB_INT\n\
            LDA >DRAW_VEC_INTENSITY  ; non-zero override (from SET_INTENSITY)\n\
DSWM_USE_FCB_INT:\n\
            STA >$C832              ; Update BIOS variable (Vec_Misc_Count)\n\
            PSHS A                  ; save brightness\n\
            LDA #$05\n\
            STA >$D000              ; PB=$05: pre-condition Z-axis (mirrors BIOS Intensity_a)\n\
            LDA #$04\n\
            STA >$D000              ; PB=$04: select Z-axis channel\n\
            PULS A                  ; restore brightness\n\
            STA >$D001              ; PA=brightness while Z-axis selected -> charges S/H\n\
            LDA #$00\n\
            STA >$D000              ; PB=$00: deselect all channels\n\
            LDA #$01\n\
            STA >$D000              ; PB=$01: restore X-integrator channel\n\
            LDB ,X+                 ; y_start from .vec (already relative to center)\n\
            ; Check if Y mirroring is enabled\n\
            TST >MIRROR_Y\n\
            BEQ DSWM_NO_NEGATE_Y\n\
            NEGB                    ; ← Negate Y if flag set\n\
DSWM_NO_NEGATE_Y:\n\
            ADDB >DRAW_VEC_Y        ; Add Y offset\n\
            LDA ,X+                 ; x_start from .vec (already relative to center)\n\
            ; Check if X mirroring is enabled\n\
            TST >MIRROR_X\n\
            BEQ DSWM_NO_NEGATE_X\n\
            NEGA                    ; ← Negate X if flag set\n\
DSWM_NO_NEGATE_X:\n\
            ADDA >DRAW_VEC_X        ; Add X offset\n\
            STD >TEMP_YX            ; Save adjusted position\n\
            ; Reset completo\n\
            CLR VIA_shift_reg\n\
            LDA #$CC\n\
            STA VIA_cntl\n\
            CLR VIA_port_a\n\
            LDA #$03\n\
            STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)\n\
            LDA #$02\n\
            STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)\n\
            LDA #$02\n\
            STA VIA_port_b          ; repeat\n\
            LDA #$01\n\
            STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)\n\
            ; Moveto (BIOS Moveto_d: Y->PA, CLR PB, settle, #CE, CLR SR, INC PB, X->PA)\n\
            LDD >TEMP_YX\n\
            STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)\n\
            CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y\n\
            PSHS A                  ; ~4 cycle settling delay for Y\n\
            LDA #$CE\n\
            STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active\n\
            CLR VIA_shift_reg       ; SR=0: no draw during moveto\n\
            INC VIA_port_b          ; PB=1: disable mux, lock direction at Y\n\
            PULS A                  ; Restore X\n\
            STA VIA_port_a          ; X to DAC\n\
            ; Timing setup (match core: hardcoded $7F)\n\
            LDA #$7F\n\
            STA VIA_t1_cnt_lo\n\
            CLR VIA_t1_cnt_hi\n\
            LEAX 2,X                ; Skip next_y, next_x\n\
            ; Wait for move to complete (PB=1 on exit)\n\
            DSWM_W1:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W1\n\
            ; PB stays 1 — draw loop begins with PB=1\n\
            ; Loop de dibujo (conditional mirrors)\n\
            DSWM_LOOP:\n\
            LDA ,X+                 ; Read flag\n\
            CMPA #2                 ; Check end marker\n\
            LBEQ DSWM_DONE\n\
            CMPA #1                 ; Check next path marker\n\
            LBEQ DSWM_NEXT_PATH\n\
            ; Draw line with conditional negations\n\
            LDB ,X+                 ; dy\n\
            ; Check if Y mirroring is enabled\n\
            TST >MIRROR_Y\n\
            BEQ DSWM_NO_NEGATE_DY\n\
            NEGB                    ; ← Negate dy if flag set\n\
DSWM_NO_NEGATE_DY:\n\
            LDA ,X+                 ; dx\n\
            ; Check if X mirroring is enabled\n\
            TST >MIRROR_X\n\
            BEQ DSWM_NO_NEGATE_DX\n\
            NEGA                    ; ← Negate dx if flag set\n\
DSWM_NO_NEGATE_DX:\n\
            ; B=DY_final, A=DX_final, PB=1 on entry (from moveto or previous segment)\n\
            STB VIA_port_a          ; DY to DAC (PB=1: integrators hold position)\n\
            CLR VIA_port_b          ; PB=0: enable mux, beam tracks DY direction\n\
            NOP                     ; settling 1 (per BIOS Draw_Line_d: LEAX+NOP = ~7 cycles)\n\
            NOP                     ; settling 2\n\
            NOP                     ; settling 3\n\
            INC VIA_port_b          ; PB=1: disable mux, lock direction at DY\n\
            STA VIA_port_a          ; DX to DAC\n\
            LDA #$FF\n\
            STA VIA_shift_reg       ; beam ON first (ramp still off from T1PB7)\n\
            CLR VIA_t1_cnt_hi       ; THEN start T1 -> ramp ON (BIOS order)\n\
            ; Wait for line draw\n\
            DSWM_W2:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W2\n\
            CLR VIA_port_a          ; PA=0: stop X integrator FIRST (alg_xsh=128=rsh → dx=0)\n\
            CLR VIA_port_b          ; PB=0: Y mux enabled → ysh=0 (stop Y integrator)\n\
            INC VIA_port_b          ; PB=1: Y mux hold (lock Y at 0)\n\
            CLR VIA_shift_reg       ; beam off (rate=0 so no drift during these 3 insns)\n\
            LBRA DSWM_LOOP          ; Long branch\n\
            ; Next path: repeat mirror logic for new path header\n\
            DSWM_NEXT_PATH:\n\
            TFR X,D\n\
            PSHS D\n\
            ; Read per-path intensity from vector data (check DRAW_VEC_INTENSITY override)\n\
            LDA ,X+                 ; Read FCB intensity from vector data\n\
DSWM_NEXT_SET_INTENSITY:\n\
            TST >DRAW_VEC_INTENSITY  ; 0 = no override, use FCB\n\
            BEQ DSWM_NEXT_USE_FCB_INT\n\
            LDA >DRAW_VEC_INTENSITY  ; non-zero override\n\
DSWM_NEXT_USE_FCB_INT:\n\
            PSHS A                  ; save intensity for later\n\
            LDB ,X+                 ; y_start\n\
            TST >MIRROR_Y\n\
            BEQ DSWM_NEXT_NO_NEGATE_Y\n\
            NEGB\n\
DSWM_NEXT_NO_NEGATE_Y:\n\
            ADDB >DRAW_VEC_Y        ; Add Y offset\n\
            LDA ,X+                 ; x_start\n\
            TST >MIRROR_X\n\
            BEQ DSWM_NEXT_NO_NEGATE_X\n\
            NEGA\n\
DSWM_NEXT_NO_NEGATE_X:\n\
            ADDA >DRAW_VEC_X        ; Add X offset\n\
            STD >TEMP_YX\n\
            PULS A                  ; restore intensity\n\
            STA >$C832              ; Update BIOS variable (Vec_Misc_Count)\n\
            PSHS A                  ; save brightness for Z-axis write\n\
            LDA #$05\n\
            STA >$D000              ; PB=$05: pre-condition (BIOS Intensity_a step 1)\n\
            LDA #$04\n\
            STA >$D000              ; PB=$04: select Z-axis channel\n\
            PULS A                  ; restore brightness\n\
            STA >$D001              ; PA=brightness while Z-axis selected\n\
            LDA #$00\n\
            STA >$D000              ; PB=$00: deselect\n\
            LDA #$01\n\
            STA >$D000              ; PB=$01: restore X-integrator channel\n\
            PULS D\n\
            ADDD #3\n\
            TFR D,X\n\
            ; Reset to zero\n\
            CLR VIA_shift_reg\n\
            LDA #$CC\n\
            STA VIA_cntl\n\
            CLR VIA_port_a\n\
            LDA #$03\n\
            STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)\n\
            LDA #$02\n\
            STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)\n\
            LDA #$02\n\
            STA VIA_port_b          ; repeat\n\
            LDA #$01\n\
            STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)\n\
            ; Moveto new start position (BIOS Moveto_d order)\n\
            LDD >TEMP_YX\n\
            STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)\n\
            CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y\n\
            PSHS A                  ; ~4 cycle settling delay for Y\n\
            LDA #$CE\n\
            STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active\n\
            CLR VIA_shift_reg       ; SR=0: no draw during moveto\n\
            INC VIA_port_b          ; PB=1: disable mux, lock direction at Y\n\
            PULS A\n\
            STA VIA_port_a          ; X to DAC\n\
            ; Timing setup (match core: hardcoded $7F)\n\
            LDA #$7F\n\
            STA VIA_t1_cnt_lo\n\
            CLR VIA_t1_cnt_hi\n\
            LEAX 2,X\n\
            ; Wait for move (PB=1 on exit)\n\
            DSWM_W3:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W3\n\
            ; PB stays 1 — draw loop continues with PB=1\n\
            LBRA DSWM_LOOP          ; Long branch\n\
            DSWM_DONE:\n\
            RTS\n"
    );
}

/// Emit PLAY_SFX_RUNTIME and sfx_doframe helpers
/// AYFX sound effects player (Richard Chadd system - 1 channel, channel C)
fn emit_play_sfx_runtime(asm: &mut String) {
    asm.push_str(
        "; ============================================================================\n\
        ; AYFX SOUND EFFECTS PLAYER (Richard Chadd original system)\n\
        ; ============================================================================\n\
        ; Uses channel C (registers 4/5=tone, 6=noise, 10=volume, 7=mixer bit2/bit5)\n\
        ; RAM variables: SFX_PTR (16-bit), SFX_ACTIVE (8-bit)\n\
        ; AYFX format: flag byte + optional data per frame, end marker $D0 $20\n\
        ; Flag bits: 0-3=volume, 4=disable tone, 5=tone data present,\n\
        ;            6=noise data present, 7=disable noise\n\
        ; ============================================================================\n\
        \n\
        ; PLAY_SFX_RUNTIME - Start SFX playback\n\
        ; Input: X = pointer to AYFX data\n\
        PLAY_SFX_RUNTIME:\n\
            STX >SFX_PTR           ; Store pointer (force extended addressing)\n\
            LDA #$01\n\
            STA >SFX_ACTIVE        ; Mark as active\n\
            RTS\n\
        \n\
        ; SFX_UPDATE - Process one AYFX frame (call once per frame in loop)\n\
        SFX_UPDATE:\n\
            LDA >SFX_ACTIVE        ; Check if active\n\
            BEQ noay               ; Not active, skip\n\
            JSR sfx_doframe        ; Process one frame\n\
        noay:\n\
            RTS\n\
        \n\
        ; sfx_doframe - AYFX frame parser (Richard Chadd original)\n\
        sfx_doframe:\n\
            LDU >SFX_PTR           ; Get current frame pointer\n\
            LDB ,U                 ; Read flag byte (NO auto-increment)\n\
            CMPB #$D0              ; Check end marker (first byte)\n\
            BNE sfx_checktonefreq  ; Not end, continue\n\
            LDB 1,U                ; Check second byte at offset 1\n\
            CMPB #$20              ; End marker $D0 $20?\n\
            BEQ sfx_endofeffect    ; Yes, stop\n\
        \n\
        sfx_checktonefreq:\n\
            LEAY 1,U               ; Y = pointer to tone/noise data\n\
            LDB ,U                 ; Reload flag byte (Sound_Byte corrupts B)\n\
            BITB #$20              ; Bit 5: tone data present?\n\
            BEQ sfx_checknoisefreq ; No, skip tone\n\
            ; Set tone frequency (channel C = reg 4/5)\n\
            LDB 2,U                ; Get LOW byte (fine tune)\n\
            LDA #$04               ; Register 4\n\
            JSR Sound_Byte         ; Write to PSG\n\
            LDB 1,U                ; Get HIGH byte (coarse tune)\n\
            LDA #$05               ; Register 5\n\
            JSR Sound_Byte         ; Write to PSG\n\
            LEAY 2,Y               ; Skip 2 tone bytes\n\
        \n\
        sfx_checknoisefreq:\n\
            LDB ,U                 ; Reload flag byte\n\
            BITB #$40              ; Bit 6: noise data present?\n\
            BEQ sfx_checkvolume    ; No, skip noise\n\
            LDB ,Y                 ; Get noise period\n\
            LDA #$06               ; Register 6\n\
            JSR Sound_Byte         ; Write to PSG\n\
            LEAY 1,Y               ; Skip 1 noise byte\n\
        \n\
        sfx_checkvolume:\n\
            LDB ,U                 ; Reload flag byte\n\
            ANDB #$0F              ; Get volume from bits 0-3\n\
            LDA #$0A               ; Register 10 (volume C)\n\
            JSR Sound_Byte         ; Write to PSG\n\
        \n\
        ; Combined mixer update: read shadow once, apply tone+noise, write once\n\
        sfx_updatemixer:\n\
            LDB $C807              ; Read mixer shadow ONCE\n\
            LDA ,U                 ; Load flag byte into A\n\
            ; Handle tone (flag bit 4 → mixer bit 2)\n\
            BITA #$10              ; Bit 4: disable tone?\n\
            BNE sfx_m_tonedis\n\
            ANDB #$FB              ; Clear bit 2 (enable tone C)\n\
            BRA sfx_m_noise\n\
        sfx_m_tonedis:\n\
            ORB #$04               ; Set bit 2 (disable tone C)\n\
        sfx_m_noise:\n\
            ; Handle noise (flag bit 7 → mixer bit 5)\n\
            BITA #$80              ; Bit 7: disable noise?\n\
            BNE sfx_m_noisedis\n\
            ANDB #$DF              ; Clear bit 5 (enable noise C)\n\
            BRA sfx_m_write\n\
        sfx_m_noisedis:\n\
            ORB #$20               ; Set bit 5 (disable noise C)\n\
        sfx_m_write:\n\
            STB $C807              ; Update mixer shadow\n\
            LDA #$07               ; Register 7 (mixer)\n\
            JSR Sound_Byte         ; Single write to PSG\n\
        \n\
        sfx_nextframe:\n\
            STY >SFX_PTR            ; Update pointer for next frame\n\
            RTS\n\
        \n\
        sfx_endofeffect:\n\
            ; Stop SFX - silence channel C and restore mixer\n\
            CLR >SFX_ACTIVE         ; Mark as inactive\n\
            LDA #$0A                ; Register 10 (volume C)\n\
            LDB #$00                ; Volume = 0\n\
            JSR Sound_Byte\n\
            ; Restore mixer: disable tone+noise on channel C\n\
            LDB $C807              ; Read mixer shadow\n\
            ORB #$24               ; Set bits 2+5 (disable tone C + noise C)\n\
            STB $C807              ; Update shadow\n\
            LDA #$07               ; Register 7\n\
            JSR Sound_Byte         ; Write mixer\n\
            LDD #$0000\n\
            STD >SFX_PTR            ; Clear pointer\n\
            RTS\n\
        \n"
    );
}

/// Emit BEEP_UPDATE_RUNTIME - decrements beep timer and mutes PSG when done
/// Auto-injected at start of LOOP_BODY when beep() is used
fn emit_beep_update_runtime(asm: &mut String) {
    asm.push_str(
        "; ============================================================================\n\
        ; BEEP_UPDATE_RUNTIME - Tick beep countdown, mute PSG when expired\n\
        ; ============================================================================\n\
        ; Called once per frame (auto-injected). Non-blocking: drawing continues\n\
        ; while PSG plays the tone set by beep().\n\
        BEEP_UPDATE_RUNTIME:\n\
        LDA >BEEP_FRAMES_LEFT    ; Check beep timer\n\
        BEQ BEEP_UPDATE_DONE     ; Zero = nothing playing, skip\n\
        DECA\n\
        STA >BEEP_FRAMES_LEFT    ; Decrement and store\n\
        BNE BEEP_UPDATE_DONE     ; Still counting, keep playing\n\
        ; Timer just expired: mute PSG channel A\n\
        PSHS DP\n\
        LDA #$D0\n\
        TFR A,DP                ; DP=$D0 for Sound_Byte\n\
        LDA #8                  ; PSG reg 8 = Volume Channel A\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        PULS DP\n\
BEEP_UPDATE_DONE:\n\
        RTS\n\n"
    );
}

/// Emit NOTE_PERIOD_TABLE: 84 FDB entries for MIDI notes 24-107 → AY period
/// Formula (calibrated for JSVecX): period = round(88200 / (440 * 2^((n-69)/12)))
fn emit_note_period_table(asm: &mut String) {
    asm.push_str(
        "; ============================================================================\n\
        ; NOTE_PERIOD_TABLE — MIDI note 24 (C1) to 107 (B7) → AY-3-8910 period\n\
        ; Each entry is a 2-byte FDB (big-endian). Index = midi_note - 24.\n\
        ; Formula: period = round(88200 / (440 * 2^((midi_note - 69) / 12)))\n\
        ; ============================================================================\n\
        NOTE_PERIOD_TABLE:\n"
    );
    for midi in 24u8..=107u8 {
        let freq = 440.0_f32 * 2.0_f32.powf((midi as f32 - 69.0) / 12.0);
        let period = (88200.0_f32 / freq).round() as u16;
        let period = period.max(1).min(4095);
        // Emit note name as comment
        let note_names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];
        let octave = (midi as i32 - 12) / 12;
        let note_name = note_names[(midi as usize) % 12];
        asm.push_str(&format!("    FDB {}    ; MIDI {} ({}{}) freq={:.1}Hz\n",
            period, midi, note_name, octave, freq));
    }
    asm.push_str("\n");
}

/// Emit PSG channel register number lookup tables
fn emit_note_channel_tables(asm: &mut String) {
    asm.push_str(
        "NOTE_CH_TONE_LO_REGS:\n\
        \tFCB 0,2,4          ; R0(A), R2(B), R4(C) — tone period low\n\
        NOTE_CH_TONE_HI_REGS:\n\
        \tFCB 1,3,5          ; R1(A), R3(B), R5(C) — tone period high\n\
        NOTE_CH_VOL_REGS:\n\
        \tFCB 8,9,10         ; R8(A), R9(B), R10(C) — volume\n\
        NOTE_CH_MIX_TONE_BITS:\n\
        \tFCB 1,2,4          ; mixer bit for tone A, B, C\n\
        NOTE_CH_MIX_NOISE_BITS:\n\
        \tFCB 8,16,32        ; mixer bit for noise A, B, C\n\
        \n"
    );
}

/// Emit PLAY_NOTE_RUNTIME
/// Inputs come via NOTE_ARG_INSTR (2-byte ptr), NOTE_ARG_CHANNEL (1-byte), NOTE_ARG_NOTE (1-byte)
/// Uses TMPPTR (channel state ptr), TMPVAL+1 (channel_id scratch), TMPPTR2 (unused scratch).
/// Corrupts A, B, X, U. Preserves Y, S (balanced PSHS/PULS).
fn emit_play_note_runtime(asm: &mut String) {
    // Emit the channel register lookup tables first
    emit_note_channel_tables(asm);

    let lines = vec![
        "; ============================================================================",
        "; PLAY_NOTE_RUNTIME",
        "; Inputs (RAM): NOTE_ARG_INSTR (ptr), NOTE_ARG_CHANNEL (0/1/2), NOTE_ARG_NOTE (24-107)",
        "; Fills NOTE_STATE slot and writes tone/volume/mixer to PSG via Sound_Byte.",
        "; ============================================================================",
        "PLAY_NOTE_RUNTIME:",
        "    ; X = NOTE_STATE + channel*10",
        "    LDA >NOTE_ARG_CHANNEL",
        "    LDB #10",
        "    MUL",
        "    ADDD #NOTE_STATE",
        "    TFR D,X",
        "    STX >TMPPTR             ; save channel state ptr",
        "    ; Fill state slot",
        "    LDA >NOTE_ARG_CHANNEL",
        "    STA ,X                  ; [+0] channel_id",
        "    LDA #1",
        "    STA 1,X                 ; [+1] active=1",
        "    LDU >NOTE_ARG_INSTR     ; U = instrument block",
        "    LDA ,U                  ; [instr+0] duration_frames",
        "    STA 2,X                 ; [+2] frames_left",
        "    LDA >NOTE_ARG_NOTE",
        "    STA 3,X                 ; [+3] base_note",
        "    STU 4,X                 ; [+4,5] instr_ptr",
        "    CLR 6,X                 ; [+6] arp_pos=0",
        "    LDA 2,U                 ; [instr+2] arpeggio_count",
        "    BNE PNR_arp_on",
        "    LDA #$FF",
        "    BRA PNR_arp_store",
        "PNR_arp_on:",
        "    LDA 3,U                 ; [instr+3] arpeggio_speed_frames",
        "PNR_arp_store:",
        "    STA 7,X                 ; [+7] arp_timer",
        "    ; Compute period for base_note",
        "    LDA >NOTE_ARG_NOTE",
        "    JSR pnr_note_to_period  ; D = AY period",
        "    LDX >TMPPTR",
        "    STD 8,X                 ; [+8,9] period hi:lo",
        "    ; Write PSG (DP=$D0 required)",
        "    LDA ,X",
        "    STA >TMPVAL+1           ; save channel_id",
        "    PSHS DP",
        "    LDA #$D0",
        "    TFR A,DP",
        "    ; Tone period low",
        "    LDB >TMPVAL+1",
        "    LDU #NOTE_CH_TONE_LO_REGS",
        "    LDA B,U                 ; A = PSG reg for tone-lo",
        "    LDB 9,X                 ; B = period low byte",
        "    JSR Sound_Byte",
        "    ; Tone period high",
        "    LDB >TMPVAL+1",
        "    LDU #NOTE_CH_TONE_HI_REGS",
        "    LDA B,U",
        "    LDB 8,X                 ; B = period high (4 bits)",
        "    ANDB #$0F",
        "    JSR Sound_Byte",
        "    ; Volume",
        "    LDU >NOTE_ARG_INSTR",
        "    LDB >TMPVAL+1",
        "    PSHS X",
        "    LDX #NOTE_CH_VOL_REGS",
        "    LDA B,X",
        "    PULS X",
        "    LDB 1,U                 ; [instr+1] volume",
        "    ANDB #$0F",
        "    JSR Sound_Byte",
        "    ; Mixer R7: clear tone-enable bit (0=enabled)",
        "    LDB >TMPVAL+1",
        "    PSHS X",
        "    LDX #NOTE_CH_MIX_TONE_BITS",
        "    LDA B,X",
        "    PULS X",
        "    COMA                    ; invert: NAND mask to clear tone bit",
        "    ANDA >$C807             ; clear bit in mixer shadow",
        "    STA >$C807",
        "    LDA #7",
        "    LDB >$C807",
        "    JSR Sound_Byte",
        "    PULS DP",
        "    RTS",
        "",
        "; pnr_note_to_period: A = MIDI note (24-107) -> D = AY period",
        "pnr_note_to_period:",
        "    SUBA #24",
        "    LDB A",
        "    CLRA",
        "    ASLB                    ; *2 for FDB entries",
        "    ROLA",
        "    PSHS D",
        "    LDU #NOTE_PERIOD_TABLE",
        "    LDD D,U",
        "    PULS U                  ; discard offset",
        "    RTS",
        "",
    ];
    for line in &lines {
        asm.push_str(line);
        asm.push('\n');
    }
}

/// Emit NOTE_UPDATE_RUNTIME — called once per frame (auto-injected)
/// Handles: frame countdown + mute, arpeggio cycling and period re-apply.
fn emit_note_update_runtime(asm: &mut String) {
    let lines = vec![
        "; ============================================================================",
        "; NOTE_UPDATE_RUNTIME — tick note timers and arpeggio (called every frame)",
        "; ============================================================================",
        "NOTE_UPDATE_RUNTIME:",
        "    LDX #NOTE_STATE",
        "    JSR note_upd_ch",
        "    LDX #NOTE_STATE+10",
        "    JSR note_upd_ch",
        "    LDX #NOTE_STATE+20",
        "    JSR note_upd_ch",
        "    RTS",
        "",
        "; note_upd_ch: X = ptr to 10-byte channel slot",
        "note_upd_ch:",
        "    LDA 1,X                 ; active?",
        "    BEQ note_upd_done",
        "    DEC 2,X                 ; frames_left--",
        "    BNE note_upd_arp",
        "    ; Duration expired: mute volume register",
        "    CLR 1,X                 ; active=0",
        "    LDA ,X                  ; channel_id",
        "    STA >TMPVAL+1",
        "    PSHS DP",
        "    LDA #$D0",
        "    TFR A,DP",
        "    LDB >TMPVAL+1",
        "    LDX #NOTE_CH_VOL_REGS",
        "    LDA B,X",
        "    LDB #0",
        "    JSR Sound_Byte",
        "    PULS DP",
        "note_upd_done:",
        "    RTS",
        "",
        "note_upd_arp:",
        "    LDU 4,X                 ; U = instr_ptr",
        "    LDA 2,U                 ; [instr+2] arpeggio_count",
        "    BEQ note_upd_done",
        "    DEC 7,X                 ; arp_timer--",
        "    BNE note_upd_done",
        "    ; Reload timer",
        "    LDA 3,U",
        "    STA 7,X",
        "    ; Advance arp_pos",
        "    LDA 6,X",
        "    INCA",
        "    CMPA 2,U",
        "    BLO note_upd_arpok",
        "    CLRA",
        "note_upd_arpok:",
        "    STA 6,X",
        "    ; new_note = base_note + intervals[arp_pos]",
        "    STX >TMPPTR",
        "    LEAX 4,U                ; X = &intervals[0]",
        "    LDB A,X                 ; B = signed semitone offset",
        "    LDX >TMPPTR",
        "    LDA 3,X                 ; A = base_note",
        "    ABA                     ; A = base_note + offset",
        "    ; Clamp 24-107",
        "    CMPA #24",
        "    BHS note_upd_hi",
        "    LDA #24",
        "    BRA note_upd_period",
        "note_upd_hi:",
        "    CMPA #107",
        "    BLS note_upd_period",
        "    LDA #107",
        "note_upd_period:",
        "    STX >TMPPTR",
        "    JSR pnr_note_to_period  ; D = period",
        "    LDX >TMPPTR",
        "    STD 8,X",
        "    ; Write tone period to PSG",
        "    LDA ,X                  ; channel_id",
        "    STA >TMPVAL+1",
        "    PSHS DP",
        "    LDA #$D0",
        "    TFR A,DP",
        "    LDB >TMPVAL+1",
        "    LDU #NOTE_CH_TONE_LO_REGS",
        "    LDA B,U",
        "    LDB 9,X",
        "    JSR Sound_Byte",
        "    LDB >TMPVAL+1",
        "    LDU #NOTE_CH_TONE_HI_REGS",
        "    LDA B,U",
        "    LDB 8,X",
        "    ANDB #$0F",
        "    JSR Sound_Byte",
        "    PULS DP",
        "    RTS",
        "",
    ];
    for line in &lines {
        asm.push_str(line);
        asm.push('\n');
    }
}


/// Generate one inlined SMUL_LUT body with unique labels (index n = 0..9).
/// Saves 14c JSR/RTS overhead per call vs JSR SMUL_LUT.
/// Caller must pre-load Y = #SMUL_PROD before first call (shared across all).
/// Input: A = val (i8, |val|≤63), B = angle index (0-127), Y = SMUL_PROD base
/// Output: A = result (i8)  — same contract as SMUL_LUT subroutine
fn inline_smul_lut(n: usize) -> String {
    format!(
        "    TSTA\n\
         BPL SL_P_{n}\n\
         NEGA\n\
         LSRA\n\
         BCC SL_N1_{n}\n\
         ORB #$80\n\
SL_N1_{n}:\n\
         LDA D,Y\n\
         NEGA\n\
         BRA SL_END_{n}\n\
SL_P_{n}:\n\
         LSRA\n\
         BCC SL_P1_{n}\n\
         ORB #$80\n\
SL_P1_{n}:\n\
         LDA D,Y\n\
SL_END_{n}:\n",
        n = n
    )
}

/// Emit DV3D_ROTATE with all 10 SMUL_LUT calls inlined (no JSR/RTS overhead).
/// Saves 14c × 10 calls = 140c per vertex rotation.
fn emit_dv3d_rotate_inlined() -> String {
    let mut s = String::new();
    s.push_str(
"; ============================================================================\n\
; DV3D_ROTATE - Apply X/Y/Z Euler rotation to a single point (inlined LUT)\n\
; ============================================================================\n\
; Input:  ROT3D_RX, ROT3D_RY, ROT3D_RZ (i8 world coords, |val|≤63)\n\
;         ROT3D_AX/AY/AZ = raw sin angle indices (0-127)\n\
;         ROT3D_COS_X/Y/Z = cos angle offsets: (angle+32)&0x7F\n\
;         ROT3D_OX, ROT3D_OY (i8 screen offsets)\n\
; Output: ROT3D_SCR_X, ROT3D_SCR_Y\n\
; Destroys: A, B, X, Y, ROT3D_TEMP, ROT3D_TEMP2, ROT3D_Y1, ROT3D_Z1, ROT3D_X2\n\
DV3D_ROTATE:\n\
    LDY #SMUL_PROD      ; Y = table base — shared by all inlined SMUL_LUT calls\n\
    ; -- X-axis rotation: y1 = y*cX - z*sX,  z1 = y*sX + z*cX --\n\
    LDA >ROT3D_RY\n\
    LDB >ROT3D_COS_X\n");
    s.push_str(&inline_smul_lut(0));  // A = RY*cX
    s.push_str(
"    STA >ROT3D_TEMP\n\
    LDA >ROT3D_RZ\n\
    LDB >ROT3D_AX\n");
    s.push_str(&inline_smul_lut(1));  // A = RZ*sX
    s.push_str(
"    STA >ROT3D_TEMP2\n\
    LDA >ROT3D_TEMP\n\
    SUBA >ROT3D_TEMP2\n\
    STA >ROT3D_Y1\n\
\n\
    LDA >ROT3D_RY\n\
    LDB >ROT3D_AX\n");
    s.push_str(&inline_smul_lut(2));  // A = RY*sX
    s.push_str(
"    STA >ROT3D_TEMP\n\
    LDA >ROT3D_RZ\n\
    LDB >ROT3D_COS_X\n");
    s.push_str(&inline_smul_lut(3));  // A = RZ*cX
    s.push_str(
"    ADDA >ROT3D_TEMP\n\
    STA >ROT3D_Z1\n\
\n\
    ; -- Y-axis rotation: x2 = x*cY + z1*sY --\n\
    LDA >ROT3D_RX\n\
    LDB >ROT3D_COS_Y\n");
    s.push_str(&inline_smul_lut(4));  // A = RX*cY
    s.push_str(
"    STA >ROT3D_TEMP\n\
    LDA >ROT3D_Z1\n\
    LDB >ROT3D_AY\n");
    s.push_str(&inline_smul_lut(5));  // A = Z1*sY
    s.push_str(
"    ADDA >ROT3D_TEMP\n\
    STA >ROT3D_X2\n\
\n\
    ; -- Z-axis rotation: sx = x2*cZ - y1*sZ + OX,  sy = x2*sZ + y1*cZ + OY --\n\
    LDA >ROT3D_X2\n\
    LDB >ROT3D_COS_Z\n");
    s.push_str(&inline_smul_lut(6));  // A = X2*cZ
    s.push_str(
"    STA >ROT3D_TEMP\n\
    LDA >ROT3D_Y1\n\
    LDB >ROT3D_AZ\n");
    s.push_str(&inline_smul_lut(7));  // A = Y1*sZ
    s.push_str(
"    STA >ROT3D_TEMP2\n\
    LDA >ROT3D_TEMP\n\
    SUBA >ROT3D_TEMP2\n\
    ADDA >ROT3D_OX\n\
    STA >ROT3D_SCR_X\n\
\n\
    LDA >ROT3D_X2\n\
    LDB >ROT3D_AZ\n");
    s.push_str(&inline_smul_lut(8));  // A = X2*sZ
    s.push_str(
"    STA >ROT3D_TEMP\n\
    LDA >ROT3D_Y1\n\
    LDB >ROT3D_COS_Z\n");
    s.push_str(&inline_smul_lut(9));  // A = Y1*cZ
    s.push_str(
"    ADDA >ROT3D_TEMP\n\
    ADDA >ROT3D_OY\n\
    STA >ROT3D_SCR_Y\n\
    RTS\n\
\n");
    s
}

/// Emit SMUL8 (kept for backward compat), SMUL_LUT, SMUL_PROD table,
/// updated DV3D_ROTATE, and new vertex-dedup DRAW_VECTOR_3D_RUNTIME.
fn emit_draw_vector_3d_runtime(asm: &mut String) {
    // Emit SMUL_PROD table first (8192 bytes)
    asm.push_str(&emit_smul_prod_table());

    asm.push_str(
"; ============================================================================\n\
; SMUL8 - Signed 8x8 multiply, result = (A * B) / 128  (i8)  [kept for compat]\n\
; ============================================================================\n\
; Input:  A = op1 (i8), B = op2 (i8)\n\
; Output: A = result (i8)\n\
; Destroys: B  (no RAM touched — sign tracked with branches)\n\
SMUL8:\n\
    TSTA\n\
    BPL SMUL8_AP        ; A >= 0?\n\
    NEGA\n\
    TSTB\n\
    BPL SMUL8_NEGNEG    ; A<0, B: check sign\n\
    NEGB                ; A<0, B<0 -> result positive\n\
    MUL\n\
    ASLB\n\
    ROLA\n\
    RTS\n\
SMUL8_NEGNEG:           ; A<0, B>=0 -> result negative\n\
    MUL\n\
    ASLB\n\
    ROLA\n\
    NEGA\n\
    RTS\n\
SMUL8_AP:               ; A >= 0\n\
    TSTB\n\
    BPL SMUL8_POSPOS    ; A>=0, B>=0 -> result positive\n\
    NEGB                ; A>=0, B<0 -> result negative\n\
    MUL\n\
    ASLB\n\
    ROLA\n\
    NEGA\n\
    RTS\n\
SMUL8_POSPOS:\n\
    MUL\n\
    ASLB\n\
    ROLA\n\
    RTS\n\
\n\
; ============================================================================\n\
; SMUL_LUT - LUT-based signed 8×8 multiply, result = (A * sin(B*2π/128)) / 128\n\
; ============================================================================\n\
; Input:  A = val (i8, |val|≤63), B = angle index (0-127)\n\
;         Y = SMUL_PROD base address (caller pre-loads: LDY #SMUL_PROD)\n\
; Output: A = result (i8)\n\
; Strategy: LSRA trick — D = (|val|/2)*256 + (angle | (bit0*128)) → table offset\n\
;           LDA D,Y — 7 cycles vs LDX+LEAX+LDA = 12 cycles. Saves 5c per call.\n\
; Destroys: B  (Y preserved)\n\
SMUL_LUT:\n\
    TSTA\n\
    BPL SMUL_LUT_P      ; A >= 0 ?\n\
    ; --- negative val ---\n\
    NEGA                ; A = |val|\n\
    LSRA                ; A = |val|/2,  C = |val| bit0\n\
    BCC SMUL_LUT_N1\n\
    ORB #$80\n\
SMUL_LUT_N1:\n\
    LDA D,Y             ; table[|val|/2][angle]\n\
    NEGA\n\
    RTS\n\
SMUL_LUT_P:\n\
    LSRA                ; A = val/2,  C = val bit0\n\
    BCC SMUL_LUT_P1\n\
    ORB #$80\n\
SMUL_LUT_P1:\n\
    LDA D,Y\n\
    RTS\n\n");
    asm.push_str(&emit_dv3d_rotate_inlined());
    asm.push_str(
"; ============================================================================\n\
; DV3D_MOVETO - Move beam to absolute (X,Y) using direct VIA (same as DSWM)\n\
; ============================================================================\n\
; Input:  ROT3D_TEMP=dy, ROT3D_TEMP2=dx (delta from current beam pos)\n\
;         DP must be $D0 on entry\n\
; Destroys: A\n\
; On exit: PB=1 (ready for draw loop)\n\
DV3D_MOVETO:\n\
    LDA >ROT3D_TEMP     ; dy\n\
    STA VIA_port_a      ; Y to DAC\n\
    CLR VIA_port_b      ; PB=0: enable mux, beam tracks Y\n\
    NOP                 ; settling\n\
    LDA #$CE\n\
    STA VIA_cntl        ; PCR=$CE: /ZERO high, integrators active\n\
    CLR VIA_shift_reg   ; SR=0: beam off during move\n\
    INC VIA_port_b      ; PB=1: lock direction\n\
    LDA >ROT3D_TEMP2    ; dx\n\
    STA VIA_port_a      ; X to DAC\n\
    LDA #$7F\n\
    STA VIA_t1_cnt_lo   ; T1=$7F — same scale as DSWM\n\
    CLR VIA_t1_cnt_hi   ; start timer (ramp)\n\
DV3D_MOVETO_WAIT:\n\
    LDA VIA_int_flags\n\
    ANDA #$40\n\
    BEQ DV3D_MOVETO_WAIT\n\
    RTS\n\
\n\
; ============================================================================\n\
; DV3D_DRAWLINE - Draw line with delta (dy,dx) using direct VIA (same as DSWM)\n\
; ============================================================================\n\
; Input:  ROT3D_TEMP=dy, ROT3D_TEMP2=dx\n\
;         PB=1 on entry (left by previous moveto or drawline)\n\
;         DP must be $D0 on entry\n\
; Destroys: A\n\
; On exit: PB=1\n\
DV3D_DRAWLINE:\n\
    LDA >ROT3D_TEMP     ; dy\n\
    STA VIA_port_a      ; DY to DAC (PB=1: integrators hold)\n\
    CLR VIA_port_b      ; PB=0: enable mux, set direction\n\
    NOP\n\
    NOP\n\
    NOP                 ; settling (~same as DSWM)\n\
    INC VIA_port_b      ; PB=1: lock direction\n\
    LDA >ROT3D_TEMP2    ; dx\n\
    STA VIA_port_a      ; DX to DAC\n\
    LDA #$FF\n\
    STA VIA_shift_reg   ; SR=$FF: beam ON\n\
    CLR VIA_t1_cnt_hi   ; start T1 ramp (lo already $7F from moveto — reuse)\n\
DV3D_DRAWLINE_WAIT:\n\
    LDA VIA_int_flags\n\
    ANDA #$40\n\
    BEQ DV3D_DRAWLINE_WAIT\n\
    CLR VIA_shift_reg   ; beam OFF\n\
    RTS\n\
\n\
; ============================================================================\n\
; DRAW_VECTOR_3D_RUNTIME - Draw 3D-rotated vector (vertex-dedup + LUT version)\n\
; ============================================================================\n\
; Input:  X = pointer to _NAME_3D_DATA (vertex-indexed format)\n\
;         ROT3D_AX, ROT3D_AY, ROT3D_AZ = raw angles (0-127)\n\
;         ROT3D_OX, ROT3D_OY = screen offsets\n\
; Data format:\n\
;   FDB vertex_count         ; unique vertex count (high byte skipped)\n\
;   FCB x,y,z × count        ; vertex table (coords ±63)\n\
;   FDB path_count           ; path count (high byte skipped)\n\
;   per path: FCB pt_count, closed, idx0, idx1, ...\n\
; Uses direct VIA access (DP=$D0 required) — same scale as DRAW_VECTOR/DSWM.\n\
; Destroys: A, B, X, U, all ROT3D_* vars\n\
DRAW_VECTOR_3D_RUNTIME:\n\
    TFR X,U             ; U = ROM data pointer\n\
\n\
    ; --- Compute cos angle offsets: ROT3D_COS_X = (AX+32)&0x7F, etc. ---\n\
    LDA >ROT3D_AX\n\
    ADDA #32\n\
    ANDA #$7F\n\
    STA >ROT3D_COS_X\n\
    LDA >ROT3D_AY\n\
    ADDA #32\n\
    ANDA #$7F\n\
    STA >ROT3D_COS_Y\n\
    LDA >ROT3D_AZ\n\
    ADDA #32\n\
    ANDA #$7F\n\
    STA >ROT3D_COS_Z\n\
\n\
    ; --- Phase 1: rotate unique vertices → ROT3D_VBUF ---\n\
    LDA ,U+             ; skip high byte of FDB vertex_count\n\
    LDB ,U+             ; B = vertex count\n\
    STB >ROT3D_PC\n\
    LDX #ROT3D_VBUF     ; X = write ptr into RAM cache\n\
\n\
DV3D_VERT_LOOP:\n\
    TST >ROT3D_PC\n\
    BEQ DV3D_VERTS_DONE\n\
    DEC >ROT3D_PC\n\
    LDA ,U+\n\
    STA >ROT3D_RX\n\
    LDA ,U+\n\
    STA >ROT3D_RY\n\
    LDA ,U+\n\
    STA >ROT3D_RZ\n\
    PSHS X,U            ; save VBUF write ptr and ROM data ptr (DV3D_ROTATE uses X,Y)\n\
    JSR DV3D_ROTATE     ; -> ROT3D_SCR_X, ROT3D_SCR_Y\n\
    PULS X,U            ; Y was clobbered but not needed outside DV3D_ROTATE\n\
    LDA >ROT3D_SCR_X\n\
    STA ,X+\n\
    LDA >ROT3D_SCR_Y\n\
    STA ,X+\n\
    BRA DV3D_VERT_LOOP\n\
\n\
DV3D_VERTS_DONE:\n\
    ; U now points to FDB path_count in ROM\n\
    ; Switch to DP=$D0 for direct VIA access (same as DSWM)\n\
    LDA #$D0\n\
    TFR A,DP\n\
\n\
    ; --- Reset integrators (DSWM-style: PB sequence + PCR) ---\n\
    CLR VIA_shift_reg\n\
    LDA #$CC\n\
    STA VIA_cntl\n\
    CLR VIA_port_a\n\
    LDA #$03\n\
    STA VIA_port_b\n\
    LDA #$02\n\
    STA VIA_port_b\n\
    LDA #$02\n\
    STA VIA_port_b\n\
    LDA #$01\n\
    STA VIA_port_b\n\
\n\
    ; Set intensity ($7F) via Port A + Z-axis strobe (DSWM-style)\n\
    LDA #$7F\n\
    STA VIA_port_a\n\
    LDA #$04\n\
    STA VIA_port_b\n\
    LDA #$01\n\
    STA VIA_port_b\n\
\n\
    ; Beam at (0,0) after reset — PREV tracks beam position\n\
    CLR >ROT3D_PREV_X\n\
    CLR >ROT3D_PREV_Y\n\
    ; T1 lo pre-loaded — reused by DV3D_DRAWLINE\n\
    LDA #$7F\n\
    STA VIA_t1_cnt_lo\n\
\n\
    ; --- Phase 2: draw paths using VBUF lookup ---\n\
    LDA ,U+             ; skip high byte of FDB path_count\n\
    LDB ,U+             ; B = path count\n\
    STB >ROT3D_PC\n\
\n\
DV3D_PATH_LOOP:\n\
    TST >ROT3D_PC\n\
    LBEQ DV3D_ALL_DONE\n\
    DEC >ROT3D_PC\n\
\n\
    LDB ,U+             ; B = point count for this path\n\
    STB >ROT3D_PT_REM\n\
    LDA ,U+             ; A = closed flag\n\
    STA >ROT3D_CLOSED\n\
\n\
    ; Look up first vertex from VBUF\n\
    LDB ,U+             ; B = vertex index\n\
    ASLB                ; B = index*2 (VBUF stride = 2 bytes: x', y')\n\
    LDX #ROT3D_VBUF\n\
    ABX                 ; X = &VBUF[idx*2]\n\
    LDA ,X\n\
    STA >ROT3D_FIRST_X\n\
    LDA 1,X\n\
    STA >ROT3D_FIRST_Y\n\
\n\
    ; Moveto: delta from current beam position (PREV)\n\
    LDA >ROT3D_FIRST_Y\n\
    SUBA >ROT3D_PREV_Y\n\
    STA >ROT3D_TEMP     ; dy\n\
    LDA >ROT3D_FIRST_X\n\
    SUBA >ROT3D_PREV_X\n\
    STA >ROT3D_TEMP2    ; dx\n\
    JSR DV3D_MOVETO     ; direct VIA move (T1=$7F, same scale as DSWM)\n\
\n\
    LDA >ROT3D_FIRST_X\n\
    STA >ROT3D_PREV_X\n\
    LDA >ROT3D_FIRST_Y\n\
    STA >ROT3D_PREV_Y\n\
    DEC >ROT3D_PT_REM\n\
\n\
DV3D_SEG_LOOP:\n\
    TST >ROT3D_PT_REM\n\
    BEQ DV3D_CLOSE_CHECK\n\
    DEC >ROT3D_PT_REM\n\
\n\
    LDB ,U+             ; B = vertex index\n\
    ASLB\n\
    LDX #ROT3D_VBUF\n\
    ABX                 ; X = &VBUF[idx*2]\n\
    ; Compute dx, update PREV_X: new_X - PREV_X = dx; new_X = dx + PREV_X\n\
    LDA ,X              ; new_X\n\
    SUBA >ROT3D_PREV_X  ; A = dx\n\
    STA >ROT3D_TEMP2    ; save dx\n\
    ADDA >ROT3D_PREV_X  ; A = new_X again\n\
    STA >ROT3D_PREV_X\n\
    ; Compute dy, update PREV_Y\n\
    LDA 1,X             ; new_Y\n\
    SUBA >ROT3D_PREV_Y  ; A = dy\n\
    STA >ROT3D_TEMP     ; save dy\n\
    ADDA >ROT3D_PREV_Y  ; A = new_Y again\n\
    STA >ROT3D_PREV_Y\n\
    JSR DV3D_DRAWLINE\n\
    BRA DV3D_SEG_LOOP\n\
\n\
DV3D_CLOSE_CHECK:\n\
    TST >ROT3D_CLOSED\n\
    BEQ DV3D_NEXT_PATH\n\
\n\
    LDA >ROT3D_FIRST_Y\n\
    SUBA >ROT3D_PREV_Y\n\
    STA >ROT3D_TEMP\n\
    LDA >ROT3D_FIRST_X\n\
    SUBA >ROT3D_PREV_X\n\
    STA >ROT3D_TEMP2\n\
    JSR DV3D_DRAWLINE\n\
    LDA >ROT3D_FIRST_X\n\
    STA >ROT3D_PREV_X\n\
    LDA >ROT3D_FIRST_Y\n\
    STA >ROT3D_PREV_Y\n\
\n\
DV3D_NEXT_PATH:\n\
    LBRA DV3D_PATH_LOOP\n\
\n\
DV3D_ALL_DONE:\n\
    ; Restore DP=$C8 for normal RAM access\n\
    JSR $F1AF\n\
    RTS\n\n"
    );
}

/// Generate SMUL_PROD lookup table: 64 rows × 128 columns = 8192 bytes
/// SMUL_PROD[val][angle] = (val * sin(angle * 2π/128)) rounded and clamped to i8
/// val = 0..63 (row, stride=128), angle = 0..127 (column within each row)
/// LSRA trick: A=|val|/2, B=angle|(bit0*0x80) → D=|val|*128+angle ✓
/// Vertex coords must be clamped to ±63 before use.
fn emit_smul_prod_table() -> String {
    use std::f64::consts::PI;
    let mut asm = String::new();
    asm.push_str("; ============================================================================\n");
    asm.push_str("; SMUL_PROD - Product lookup table for SMUL_LUT\n");
    asm.push_str("; SMUL_PROD[val][angle] = (val * sin(angle*2π/128)) >> 7  (i8)\n");
    asm.push_str("; val=row (0-63, stride=128), angle=col (0-127) — 8KB total\n");
    asm.push_str("; For cos: use angle=(ax+32)&0x7F — same table, shifted column\n");
    asm.push_str("; Vertex coords must be ≤63 (clamped at data emit time)\n");
    asm.push_str("SMUL_PROD:\n");
    for val in 0i32..64 {
        let mut row_bytes = Vec::with_capacity(128);
        for angle in 0i32..128 {
            let sin_f = f64::sin(angle as f64 * 2.0 * PI / 128.0);
            let sin_i8 = (sin_f * 127.0).round() as i32;
            let raw = val * sin_i8;
            // Round-toward-nearest with +64 bias, then divide by 128
            let prod = if raw >= 0 {
                (raw + 64) / 128
            } else {
                -( (raw.abs() + 64) / 128 )
            };
            let prod = prod.clamp(-127, 127) as i8;
            row_bytes.push(prod);
        }
        // Emit as one FCB line per row (128 bytes)
        let bytes_str: Vec<String> = row_bytes.iter()
            .map(|&b| format!("${:02X}", b as u8))
            .collect();
        asm.push_str(&format!("    FCB {}  ; val={}\n", bytes_str.join(","), val));
    }
    asm.push_str("\n");
    asm
}

/// Emit the DRAW_ANIM_RUNTIME subroutine.
///
/// Input:
///   X = pointer to animation ROM header (_ANIM_XXX)
///   U = pointer to 2-byte RAM state (ANIM_XXX_STATE): frame_idx(u8) + ticks_left(u8)
///
/// Header layout (from animres.rs compile_vanim_to_asm):
///   +0  FCB frame_count
///   +1  FCB loop_flag  (1=loop, 0=freeze)
///   +2  FDB frame0_ptr
///   +4  FDB frame1_ptr  ... (2 bytes per frame)
///
/// Frame layout:
///   +0  FCB duration_ticks
///   +1  FCB vec_ref_count
///   +2  FDB vec_ref_ptr[0]  ...  (2 bytes each)
///   +2+vec_ref_count*2  FCB inline_path_count
///   followed by inline path binary blocks
///
/// Register conventions:
///   Y = scratch / frame data pointer
///   Preserves: everything except RESULT via PSHS/PULS D,X,Y,U
fn emit_draw_anim_runtime(asm: &mut String) {
    asm.push_str(
"; ============================================================================\n\
; DRAW_ANIM_RUNTIME\n\
; Input: X = animation ROM header (_ANIM_XXX)\n\
;        U = 2-byte RAM state (byte0=frame_idx, byte1=ticks_left)\n\
;\n\
; Header layout:\n\
;   byte 0: frame_count\n\
;   byte 1: loop_flag (1=loop, 0=freeze)\n\
;   byte 2: base_ref_count  (static cel layer — drawn before every frame)\n\
;   byte 3: frame_table_offset (= 4 + base_ref_count*2)\n\
;   bytes 4..: FDB ptrs to base_ref _VECNAME_VECTORS\n\
;   at frame_table_offset: FDB ptrs to per-frame data\n\
; ============================================================================\n\
DRAW_ANIM_RUNTIME:\n\
    ; NOTE: do NOT set ACR here. DRAW_VECTOR works without touching ACR;\n\
    ; setting ACR=$18 (T1 no PB7) breaks T1 timing inside DSWM and hangs.\n\
    PSHS D,X,Y,U\n\
    ; --- Refresh MIRROR_X from saved arg (re-assert before any BIOS call can corrupt A) ---\n\
    LDA >DRAW_ANIM_MIRROR_X\n\
    STA >MIRROR_X\n\
    ; --- Apply scale: copy DRAW_ANIM_SCALE to DRAW_SCALE for DSWM ---\n\
    LDA >DRAW_ANIM_SCALE\n\
    STA >DRAW_SCALE\n\
    ; --- Draw base_refs (static cel layer, drawn before every frame) ---\n\
    LDB 2,X             ; base_ref_count\n\
    BEQ DAR_TICK        ; none: skip to tick management\n\
    LEAY 4,X            ; Y = first base_ref FDB entry\n\
DAR_BASE_LOOP:\n\
    PSHS B,X,Y\n\
    LDX ,Y              ; X = _VECNAME_VECTORS header\n\
    CLR >MIRROR_Y\n\
    JSR $F1AA           ; DP_to_D0\n\
    LDD ,X              ; D = path_count (FDB, 2 bytes)\n\
    BEQ DAR_BASE_SKIP\n\
    LEAY 2,X            ; Y = first path FDB in vec table (skip 2-byte count)\n\
DAR_BASE_PATH_LOOP:\n\
    PSHS D,Y\n\
    LDX ,Y\n\
    JSR Draw_Sync_List_At_With_Mirrors\n\
    PULS D,Y\n\
    LEAY 2,Y\n\
    SUBD #1\n\
    BNE DAR_BASE_PATH_LOOP\n\
DAR_BASE_SKIP:\n\
    JSR $F1AF           ; DP_to_C8\n\
    PULS B,X,Y\n\
    LEAY 2,Y            ; next base_ref FDB\n\
    DECB\n\
    LBNE DAR_BASE_LOOP\n\
    ; --- Tick counter management ---\n\
DAR_TICK:\n\
    LDU 6,S             ; reload U from stack — BIOS may corrupt live U\n\
    LDA 1,U             ; ticks_left\n\
    BEQ DAR_INIT        ; 0 = first call: initialize frame 0\n\
    DECA\n\
    BNE DAR_DRAW        ; still on this frame: skip frame advance\n\
    ; ticks exhausted: advance frame index\n\
    LDB ,U              ; current frame_idx\n\
    INCB\n\
    CMPB ,X             ; frame_count (byte 0)\n\
    BLT DAR_NO_WRAP\n\
    LDA 1,X             ; loop flag (byte 1)\n\
    BEQ DAR_FREEZE      ; loop=0: freeze on last frame\n\
    CLRB                ; loop=1: back to frame 0\n\
DAR_NO_WRAP:\n\
    STB ,U              ; save new frame_idx\n\
    ; frame_ptr = X + frame_table_offset + frame_idx*2\n\
    LDB ,U              ; new frame_idx\n\
    CLRA\n\
    LSLB\n\
    ROLA                ; D = frame_idx*2\n\
    ADDB 3,X            ; D += frame_table_offset (byte 3)\n\
    ADCA #0\n\
    LEAY D,X            ; Y = &frame_table[frame_idx]\n\
    LDY ,Y              ; Y = frame data ptr\n\
    LDA ,Y              ; A = duration_ticks from vanim\n\
    LDB >DRAW_ANIM_SPEED_MUL\n\
    BEQ DAR_SPEED1      ; speed=0: use vanim's duration_ticks as-is\n\
    TFR B,A             ; speed>0: override with ticks_per_frame directly\n\
DAR_SPEED1:\n\
    CMPA #1\n\
    BHS DAR_SPEED1_OK\n\
    LDA #1\n\
DAR_SPEED1_OK:\n\
    STA 1,U             ; reset ticks_remaining\n\
    BRA DAR_EMIT\n\
DAR_FREEZE:\n\
    LDA #1\n\
    STA 1,U\n\
    LDB ,U              ; last frame_idx\n\
    CLRA\n\
    LSLB\n\
    ROLA\n\
    ADDB 3,X\n\
    ADCA #0\n\
    LEAY D,X\n\
    LDY ,Y\n\
    BRA DAR_EMIT\n\
DAR_INIT:\n\
    ; First call: frame_idx=0, load frame 0 duration and draw it\n\
    CLRB                ; frame_idx = 0\n\
    STB ,U\n\
    CLRA                ; D = 0 (frame_idx*2 = 0)\n\
    ADDB 3,X            ; B = frame_table_offset (frame 0 offset from header)\n\
    ADCA #0\n\
    LEAY D,X            ; Y = frame_table[0] entry\n\
    LDY ,Y              ; Y = frame 0 data ptr\n\
    LDA ,Y              ; A = duration_ticks from vanim\n\
    LDB >DRAW_ANIM_SPEED_MUL\n\
    BEQ DAR_SPEED2      ; speed=0: use vanim's duration_ticks as-is\n\
    TFR B,A             ; speed>0: override with ticks_per_frame directly\n\
DAR_SPEED2:\n\
    CMPA #1\n\
    BHS DAR_SPEED2_OK\n\
    LDA #1\n\
DAR_SPEED2_OK:\n\
    STA 1,U             ; ticks_left = ticks_per_frame\n\
    BRA DAR_EMIT\n\
DAR_DRAW:\n\
    STA 1,U             ; save decremented ticks\n\
    LDB ,U              ; frame_idx\n\
    CLRA\n\
    LSLB\n\
    ROLA\n\
    ADDB 3,X\n\
    ADCA #0\n\
    LEAY D,X\n\
    LDY ,Y              ; Y = frame data ptr\n\
DAR_EMIT:\n\
    ; frame data: byte 0=duration_ticks (skip), byte 1=vec_ref_count\n\
    LEAY 1,Y\n\
    LDB ,Y+             ; B = vec_ref_count, Y at first vec ptr\n\
    BEQ DAR_INLINE\n\
DAR_VEC_LOOP:\n\
    PSHS B,Y\n\
    LDX ,Y\n\
    JSR $F1AA           ; DP_to_D0\n\
    LDD ,X              ; D = path_count (FDB, 2 bytes)\n\
    BEQ DAR_VEC_DONE\n\
    LEAY 2,X            ; Y = first path FDB (skip 2-byte count)\n\
DAR_VEC_PATH_LOOP:\n\
    PSHS D,Y\n\
    LDX ,Y\n\
    JSR Draw_Sync_List_At_With_Mirrors\n\
    PULS D,Y\n\
    LEAY 2,Y\n\
    SUBD #1\n\
    BNE DAR_VEC_PATH_LOOP\n\
DAR_VEC_DONE:\n\
    JSR $F1AF           ; DP_to_C8\n\
    PULS B,Y\n\
    LEAY 2,Y\n\
    DECB\n\
    BNE DAR_VEC_LOOP\n\
DAR_INLINE:\n\
    LDB ,Y+             ; B = inline_path_count\n\
    BEQ DAR_DONE\n\
DAR_PATH_LOOP:\n\
    PSHS B\n\
    TFR Y,X\n\
    JSR $F1AA           ; DP_to_D0\n\
    JSR Draw_Sync_List_At_With_Mirrors\n\
    JSR $F1AF           ; DP_to_C8\n\
    LEAY 5,Y            ; skip intensity + 4-byte header\n\
DAR_SCAN:\n\
    LDA ,Y+\n\
    CMPA #2\n\
    BEQ DAR_PATH_DONE\n\
    CMPA #$FF\n\
    BNE DAR_SCAN\n\
    LEAY 2,Y\n\
    BRA DAR_SCAN\n\
DAR_PATH_DONE:\n\
    PULS B\n\
    DECB\n\
    BNE DAR_PATH_LOOP\n\
DAR_DONE:\n\
    ; Restore DRAW_SCALE to default ($7F) after animation draw\n\
    LDA #$7F\n\
    STA >DRAW_SCALE\n\
    PULS D,X,Y,U\n\
    RTS\n\n");
}

/// Emit SPAWN_ENEMIES_RUNTIME, UPDATE_ENEMIES_RUNTIME, DRAW_ENEMIES_RUNTIME.
///
/// Enemy pool record layout (ENEMY_POOL_STRIDE = 13 bytes):
///   +0   active      (1)  0=dead, 1=active
///   +1,2 x           (2)  signed 16-bit world x (hi, lo)
///   +3,4 y           (2)  signed 16-bit world y (hi, lo)
///   +5,6 type_ptr    (2)  pointer to _NAME_ENEMY header
///   +7   action      (1)  current action index
///   +8   ai_type     (1)  0=static,1=patrol,2=chase,3=flee
///   +9   hp          (1)  current HP
///   +10  wp_idx      (1)  current patrol waypoint index
///   +11,12 wp_ptr    (2)  pointer to waypoint table (0 = none)
///
/// Instance record layout (levelres.rs, 12 bytes):
///   +0,1  type_ptr (FDB)
///   +2,3  spawn_x  (FDB)
///   +4,5  spawn_y  (FDB)
///   +6    ai_type  (FCB)
///   +7    wave     (FCB)
///   +8    respawn  (FCB)
///   +9    wp_count (FCB)
///   +10,11 wp_ptr  (FDB)
fn emit_enemy_system_runtime(asm: &mut String, max_enemies: usize, is_multibank: bool, has_vanim_enemies: bool) {
    asm.push_str(&format!(
"; ============================================================================\n\
; ENEMY SYSTEM RUNTIME  (max {max_enemies} enemies, stride 28 bytes)\n\
; ============================================================================\n\
ENEMY_POOL_STRIDE EQU 28\n\
ENEMY_POOL_MAX    EQU {max_enemies}\n\
\n\
; Pool record offsets\n\
POOL_ACTIVE  EQU 0\n\
POOL_X_HI    EQU 1\n\
POOL_X_LO    EQU 2\n\
POOL_Y_HI    EQU 3\n\
POOL_Y_LO    EQU 4\n\
POOL_TYPE_HI EQU 5\n\
POOL_TYPE_LO EQU 6\n\
POOL_ACTION  EQU 7\n\
POOL_AI      EQU 8\n\
POOL_HP      EQU 9\n\
POOL_WPIDX   EQU 10\n\
POOL_WPPTR   EQU 11\n\
POOL_SM_STATE EQU 13\n\
POOL_SM_TMR_HI EQU 14\n\
POOL_SM_TMR_LO EQU 15\n\
POOL_WPCOUNT   EQU 16\n\
POOL_DIR        EQU 17\n\
POOL_SUB_STATE  EQU 18\n\
POOL_AREA_IDX   EQU 19\n\
POOL_IDLE_TIMER EQU 20\n\
POOL_TRANS_TYPE EQU 21\n\
POOL_TARGET_X_HI EQU 22\n\
POOL_TARGET_X_LO EQU 23\n\
POOL_FROMX_OR_VY_HI EQU 24\n\
POOL_FROMX_OR_VY_LO EQU 25\n\
POOL_FEET_OFFSET EQU 26\n\
POOL_VY0_STASH EQU 27\n\
;   POOL_FROMX_OR_VY (2) — WALK_TO_TAKEOFF: from_x (i16). AIRBORNE: vy (i16, low byte = i8 vy).\n\
;   POOL_FEET_OFFSET (1) — set at SPAWN to enemy's sprite half-height. Used to snap\n\
;     world_y = area.y + feet_offset on spawn and on land.\n\
;   POOL_VY0_STASH (1) — initial vy of the in-progress transition (set at commit,\n\
;     applied at takeoff). Comes from trans entry's vy0 byte (per-transition tuned).\n\
;   POOL_DIR (1) — 0=facing right, 1=facing left. Written by UPDATE_ENEMIES when\n\
;   patrol moves the enemy on X (LBGT path = right, LBLT/SUB path = left). Read by\n\
;   DRAW_ENEMIES into MIRROR_X so the sprite reflects the current direction.\n\
;   POOL_SUB_STATE (1) — wander only. 0=WALK, 1=IDLE, 2=AIRBORNE, 3=WALK_TO_TAKEOFF\n\
;   POOL_AREA_IDX (1) — wander only. Current area index into level's AREAS table.\n\
;   POOL_IDLE_TIMER (1) — wander only. Frames remaining in idle. Decremented each\n\
;   frame while sub_state=1; on expire either commits a transition or returns to WALK.\n\
;   POOL_TRANS_TYPE (1) — wander only. Type of in-progress transition: 1=jump_up, 2=drop, 3=jump_across.\n\
;   POOL_TARGET_X (2) — wander only. Target X stashed at transition commit (i16).\n\
;   POOL_VY (2) — wander only. AIRBORNE: signed vertical velocity (i16, only low byte typically used).\n\
;     WALK_TO_TAKEOFF: stores from_x in same slot since vy isn't used yet.\n\
; For wander enemies, wp_ptr (pool +11..12) is reused as areas_ptr (points to\n\
;   _LVL_AREAS_HEADER), and wp_count (pool +16) holds area_count.\n\
; SM state record layout (SM_STATE_STRIDE = 13 bytes, max 4 events)\n\
SM_STATE_STRIDE EQU 13\n\
SM_HDR_INIT   EQU 1\n\
SM_HDR_STATES EQU 2\n\
SM_ST_ACTION  EQU 0\n\
SM_ST_DCY_HI  EQU 1\n\
SM_ST_DCY_LO  EQU 2\n\
SM_ST_DCYTO   EQU 3\n\
SM_ST_NEVT    EQU 4\n\
SM_ST_EVT0H   EQU 5\n\
SM_ST_EVT0T   EQU 6\n\
SM_ST_EVT1H   EQU 7\n\
SM_ST_EVT1T   EQU 8\n\
SM_ST_EVT2H   EQU 9\n\
SM_ST_EVT2T   EQU 10\n\
SM_ST_EVT3H   EQU 11\n\
SM_ST_EVT3T   EQU 12\n\
\n\
; SPAWN_ENEMIES_RUNTIME\n\
; Entry: B = instance count, X = ptr to _LEVEL_ENEMY_INSTANCES table\n\
; Initialises ENEMY_POOL from the ROM instance table.\n\
SPAWN_ENEMIES_RUNTIME:\n\
    ; Entry: B = total ROM instance count, X = ptr to instances table.\n\
    ; Per-screen reuse (mirrors pitrex): only spawn enemies whose world Y is\n\
    ; within +/-150 of CAMERA_Y, capped at the pool size ({max_enemies}).\n\
    LBEQ SPAWN_ENE_DONE\n\
    STB >ENEMY_LOOP_IDX        ; scan counter = total ROM entries to examine\n\
    ; Zero-clear ALL pool slots so stale enemies from the previous screen vanish\n\
    LDY #ENEMY_POOL\n\
    LDB #{max_enemies}\n\
    CLRA\n\
SPAWN_CLR_LOOP:\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+\n\
    STA ,Y+                    ; +17 dir (clears to 0=right)\n\
    STA ,Y+                    ; +18 sub_state (clears to 0=WALK)\n\
    STA ,Y+                    ; +19 cur_area_idx (clears to 0)\n\
    STA ,Y+                    ; +20 idle_timer (clears to 0)\n\
    STA ,Y+                    ; +21 trans_type (clears to 0)\n\
    STA ,Y+                    ; +22 target_x hi\n\
    STA ,Y+                    ; +23 target_x lo\n\
    STA ,Y+                    ; +24 from_x/vy hi\n\
    STA ,Y+                    ; +25 from_x/vy lo\n\
    STA ,Y+                    ; +26 feet_offset (set by SPAWN_FILL for wander)\n\
    STA ,Y+                    ; +27 pad\n\
    DECB\n\
    BNE SPAWN_CLR_LOOP\n\
    CLR >ENEMY_COUNT           ; spawned (in-range) count = 0\n\
    LDX >LEVEL_ENEMY_INSTANCES_PTR\n\
    STX >ENEMY_SCRATCH_PTR\n\
    LDY #ENEMY_POOL\n\
SPAWN_SCAN_LOOP:\n\
    LDX >ENEMY_SCRATCH_PTR\n\
    LDD 4,X                    ; D = instance world Y (offset +4,+5)\n\
    SUBD >CAMERA_Y             ; D = spawn_y - camera_y\n\
    CMPD #150\n\
    LBGT SPAWN_SKIP            ; off-screen below (signed)\n\
    CMPD #$FF6A                ; -150: off-screen above (signed)\n\
    LBLT SPAWN_SKIP\n\
    LDA #1\n\
    STA ,Y              ; +0 active=1\n\
    LDA 2,X\n\
    STA 1,Y             ; +1 x hi\n\
    LDA 3,X\n\
    STA 2,Y             ; +2 x lo\n\
    LDA 4,X\n\
    STA 3,Y             ; +3 y hi\n\
    LDA 5,X\n\
    STA 4,Y             ; +4 y lo\n\
    LDA ,X\n\
    STA 5,Y             ; +5 type_ptr hi\n\
    LDA 1,X\n\
    STA 6,Y             ; +6 type_ptr lo\n\
    CLR 7,Y             ; +7 action=0 (idle)\n\
    LDA 6,X\n\
    STA 8,Y             ; +8 ai_type\n\
    ; hp = first byte of enemy type block\n\
    LDX >ENEMY_SCRATCH_PTR  ; reload instance ptr (X still valid here)\n\
    PSHS B,X,Y\n\
    LDA 5,Y\n\
    LDB 6,Y\n\
    TFR D,X             ; X = type_ptr = _NAME_ENEMY header\n\
    LDA ,X              ; hp byte\n\
    PULS B,X,Y\n\
    STA 9,Y             ; +9 hp\n\
    CLR 10,Y            ; +10 wp_idx=0\n\
    LDA 9,X\n\
    STA 16,Y            ; +16 wp_count\n\
    LDA 10,X\n\
    STA 11,Y            ; +11 wp_ptr hi\n\
    LDA 11,X\n\
    STA 12,Y            ; +12 wp_ptr lo\n\
    ; Init SM state (+13) from type header [5-6] = SM ptr\n\
    PSHS B              ; save loop counter (B clobbered by LDB below)\n\
    LDA 5,Y             ; type_ptr hi (pool)\n\
    LDB 6,Y             ; type_ptr lo (pool)\n\
    TFR D,X             ; X = _NAME_ENEMY header\n\
    LDA 5,X             ; SM ptr hi (header[5])\n\
    LDB 6,X             ; SM ptr lo (header[6])\n\
    CMPD #0\n\
    BEQ SPAWN_SM_NOSM   ; no state machine\n\
    TFR D,X             ; X = SM table header\n\
    PSHS X              ; save SM header ptr\n\
    LDA 1,X             ; initial_state_idx\n\
    STA 13,Y            ; pool.sm_state = initial\n\
    ; Look up initial state action\n\
    TFR A,B             ; B = initial_state_idx\n\
    PULS X              ; X = SM header\n\
    LEAX 2,X            ; X = &states[0]\n\
    LDA #13             ; stride = 13 bytes per state record\n\
    MUL                 ; D = initial_state_idx * 13\n\
    LEAX D,X            ; X = &states[initial]\n\
    LDA ,X              ; action_idx from state[0]\n\
    STA 7,Y             ; pool.action = initial action\n\
    BRA SPAWN_SM_DONE\n\
SPAWN_SM_NOSM:\n\
    LDA #$FF\n\
    STA 13,Y            ; pool.sm_state = $FF (no SM)\n\
SPAWN_SM_DONE:\n\
    PULS B              ; restore loop counter\n\
    CLR 14,Y            ; pool.sm_decay_timer hi = 0\n\
    CLR 15,Y            ; pool.sm_decay_timer lo = 0\n\
    ; Wander (ai_type=4) starts in walk action and copies feet_offset+area_idx.\n\
    ; CRITICAL: X is currently type_ptr or SM_state record (clobbered by SM init).\n\
    ; Must reload X = ENEMY_SCRATCH_PTR (instance ptr) before reading instance bytes.\n\
    LDA 8,Y             ; ai_type\n\
    CMPA #4\n\
    BNE SPAWN_ACT_DONE\n\
    LDA #1\n\
    STA 7,Y             ; action=1 (walk)\n\
    LDX >ENEMY_SCRATCH_PTR  ; X = instance ptr (was clobbered by SM init)\n\
    LDA 12,X            ; instance.feet_offset (instance +12)\n\
    STA 26,Y            ; pool.feet_offset\n\
    LDA 13,X            ; instance.initial_area_idx (instance +13)\n\
    STA 19,Y            ; pool.cur_area_idx\n\
SPAWN_ACT_DONE:\n\
    ; filled a slot: advance pool ptr, bump spawned count, stop if pool full\n\
    LEAY 28,Y\n\
    INC >ENEMY_COUNT\n\
    LDA >ENEMY_COUNT\n\
    CMPA #{max_enemies}\n\
    BHS SPAWN_ENE_DONE         ; pool full -> stop scanning\n\
SPAWN_SKIP:\n\
    ; advance to next ROM instance (stride 14) and keep scanning\n\
    LDX >ENEMY_SCRATCH_PTR\n\
    LEAX 14,X\n\
    STX >ENEMY_SCRATCH_PTR\n\
    DEC >ENEMY_LOOP_IDX\n\
    LBNE SPAWN_SCAN_LOOP\n\
SPAWN_ENE_DONE:\n\
    RTS\n\
\n"
    ));

    // UPDATE_ENEMIES_RUNTIME — fixes loop-counter bug (B clobbered by LDB 12,Y) and,
    // in multibank mode, switches to LEVEL_BANK before reading wp_ptr addresses.
    if is_multibank {
        asm.push_str(
"; UPDATE_ENEMIES_RUNTIME (multibank)\n\
; Patrol (ai_type=1): waypoint loop. Wander (ai_type=4): area-based state machine.\n\
; Areas table (per level, in level bank) format:\n\
;   +0  FCB area_count\n\
;   +1  FCB trans_count\n\
;   +2  area[0]: FDB y, FDB x_min, FDB x_max, FCB pad, FCB pad (8 bytes)\n\
;   +2+area_count*8: trans[0]: FCB from, FCB to, FCB type, FCB pad, FDB from_x, FDB to_x\n\
; Wander pool fields:\n\
;   +18 sub_state: 0=WALK 1=IDLE 2=AIRBORNE 3=WALK_TO_TAKEOFF\n\
;   +19 cur_area_idx (set to target at commit)\n\
;   +20 idle_timer (IDLE)\n\
;   +21 trans_type (1=jump_up 2=drop 3=jump_across)\n\
;   +22..23 target_x (to_x stashed at commit)\n\
;   +24    airborne_timer / pad\n\
;   +25    vy (i8, AIRBORNE)\n\
;   +26    feet_offset\n\
UPDATE_ENEMIES_RUNTIME:\n\
    LDB >ENEMY_COUNT\n\
    LBEQ UPD_ENE_DONE\n\
    LDA CURRENT_ROM_BANK\n\
    PSHS A              ; save current bank\n\
    LDA >LEVEL_BANK\n\
    STA CURRENT_ROM_BANK\n\
    STA $DF00           ; switch to level bank\n\
    LDY #ENEMY_POOL\n\
UPD_ENE_LOOP:\n\
    PSHS B              ; save loop counter\n\
    LDA ,Y              ; active?\n\
    LBEQ UPD_ENE_NEXT_POP\n\
    ; ── SM auto-decay tick: walks states back through their declared decay_to\n\
    ; chain at the cadence set by each state's decay_frames in the .venemy.\n\
    ; Runs BEFORE the frozen-action guard so reaching state 0 (normal) can\n\
    ; release the enemy in the same frame.\n\
    JSR UPD_DECAY_CHECK\n\
    ; ── Frozen-action guard: action 0=idle, 1=walk are 'live'.\n\
    ; Any action >= 2 (snow1, snow2, ball, ...) means the SM has frozen the\n\
    ; enemy in place (snowed/captured). Skip all movement so it stays put,\n\
    ; drawn with its current snowed sprite by DRAW_ENEMIES.\n\
    LDA 7,Y             ; pool.action\n\
    CMPA #2\n\
    LBHS UPD_ENE_NEXT_POP\n\
    LDA 8,Y             ; ai_type\n\
    CMPA #1\n\
    LBEQ UPD_PATROL\n\
    CMPA #4\n\
    LBEQ UPD_WANDER\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
; ============ PATROL (waypoint-based) ============\n\
UPD_PATROL:\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    CMPD #0\n\
    LBEQ UPD_ENE_NEXT_POP\n\
    TFR D,X             ; X = wp_ptr base\n\
    LDA 10,Y            ; wp_idx\n\
    ASLA\n\
    ASLA                ; * 4 bytes per waypoint\n\
    LEAX A,X            ; X = &wp[wp_idx]\n\
    LDD ,X              ; target_x\n\
    CMPD 1,Y\n\
    LBEQ UPD_P_MOVE_Y\n\
    LBGT UPD_P_INC_X\n\
    LDD 1,Y\n\
    SUBD #1\n\
    STD 1,Y\n\
    LDA #1\n\
    STA 17,Y\n\
    LBRA UPD_P_MOVE_Y\n\
UPD_P_INC_X:\n\
    LDD 1,Y\n\
    ADDD #1\n\
    STD 1,Y\n\
    CLR 17,Y\n\
UPD_P_MOVE_Y:\n\
    LDD 2,X             ; target_y\n\
    CMPD 3,Y\n\
    LBEQ UPD_P_CHECK_WP\n\
    LBGT UPD_P_INC_Y\n\
    LDD 3,Y\n\
    SUBD #1\n\
    STD 3,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_P_INC_Y:\n\
    LDD 3,Y\n\
    ADDD #1\n\
    STD 3,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_P_CHECK_WP:\n\
    LDD ,X\n\
    CMPD 1,Y\n\
    LBNE UPD_ENE_NEXT_POP\n\
    INC 10,Y\n\
    LDA 10,Y\n\
    CMPA 16,Y\n\
    LBLO UPD_ENE_NEXT_POP\n\
    CLR 10,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
; ============ WANDER (area-based state machine) ============\n\
UPD_WANDER:\n\
    LDA 18,Y            ; sub_state\n\
    LBEQ UPD_W_WALK\n\
    CMPA #1\n\
    LBEQ UPD_W_IDLE\n\
    CMPA #2\n\
    LBEQ UPD_W_AIR\n\
    CMPA #3\n\
    LBEQ UPD_W_TT\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_W_WALK:\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    CMPD #0\n\
    LBEQ UPD_ENE_NEXT_POP\n\
    TFR D,X             ; X = areas_header_ptr\n\
    LDB 19,Y            ; cur_area_idx\n\
    LDA #8\n\
    MUL                 ; D = idx*8\n\
    ADDD #2             ; +2 to skip header\n\
    LEAX D,X            ; X = &area[idx]\n\
    LDA 17,Y            ; POOL_DIR\n\
    LBNE UPD_W_WALK_L\n\
    ; dir=0 right: walk +1, clamp to x_max\n\
    LDD 1,Y\n\
    ADDD #1\n\
    PSHS D              ; save proposed x\n\
    LDD 4,X             ; x_max\n\
    CMPD ,S\n\
    LBLT UPD_W_EDGE_R   ; proposed > x_max → edge\n\
    PULS D\n\
    STD 1,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_EDGE_R:\n\
    LEAS 2,S\n\
    LDD 4,X             ; clamp to x_max\n\
    STD 1,Y\n\
    LBRA UPD_W_EDGE\n\
UPD_W_WALK_L:\n\
    LDD 1,Y\n\
    SUBD #1\n\
    PSHS D\n\
    LDD 2,X             ; x_min\n\
    CMPD ,S\n\
    LBGT UPD_W_EDGE_L\n\
    PULS D\n\
    STD 1,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_EDGE_L:\n\
    LEAS 2,S\n\
    LDD 2,X             ; clamp to x_min\n\
    STD 1,Y\n\
UPD_W_EDGE:\n\
    ; Reached an edge: flip dir, enter IDLE\n\
    LDA 17,Y\n\
    EORA #1\n\
    STA 17,Y\n\
    LDA #1\n\
    STA 18,Y            ; sub_state = IDLE\n\
    CLR 7,Y             ; action = idle\n\
    JSR RAND_HELPER\n\
    ANDB #$3F\n\
    ADDB #90\n\
    STB 20,Y            ; idle_timer\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_W_IDLE:\n\
    DEC 20,Y\n\
    LBNE UPD_ENE_NEXT_POP\n\
    ; Idle expired: try a transition (25% chance per matching entry)\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    TFR D,X             ; X = areas_header_ptr\n\
    LDB 1,X             ; trans_count\n\
    LBEQ UPD_W_TO_WALK\n\
    PSHS B              ; save trans_count\n\
    LDA ,X              ; area_count\n\
    LDB #8\n\
    MUL                 ; D = area_count*8\n\
    ADDD #2\n\
    LEAX D,X            ; X = trans_ptr (start of trans array)\n\
    PULS B              ; B = trans_count (loop counter)\n\
UPD_W_TRY_LOOP:\n\
    LDA 19,Y            ; cur_area_idx\n\
    CMPA ,X             ; trans.from\n\
    BNE UPD_W_NEXT_TRY\n\
    ; Match: roll 25% chance\n\
    PSHS B,X\n\
    JSR RAND_HELPER\n\
    ANDB #3\n\
    TSTB\n\
    PULS B,X\n\
    BNE UPD_W_NEXT_TRY\n\
    ; Commit transition: X = &trans[matched]\n\
    LDA 1,X\n\
    STA 19,Y            ; cur_area_idx = to\n\
    LDA 2,X\n\
    STA 21,Y            ; trans_type\n\
    LDA 3,X\n\
    STA 27,Y            ; vy0_stash (precomputed by compiler for this transition)\n\
    LDD 4,X\n\
    STD 24,Y            ; from_x stashed at pool+24..25\n\
    LDD 6,X\n\
    STD 22,Y            ; target_x at pool+22..23\n\
    LDA #3\n\
    STA 18,Y            ; sub_state = WALK_TO_TAKEOFF\n\
    LDA #1\n\
    STA 7,Y             ; action = walk\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_NEXT_TRY:\n\
    LEAX 8,X\n\
    DECB\n\
    BNE UPD_W_TRY_LOOP\n\
UPD_W_TO_WALK:\n\
    CLR 18,Y            ; sub_state = WALK\n\
    LDA #1\n\
    STA 7,Y             ; action = walk\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_W_TT:\n\
    ; WALK_TO_TAKEOFF: walk X-only toward from_x at pool+24..25\n\
    LDD 24,Y            ; from_x\n\
    CMPD 1,Y\n\
    LBEQ UPD_W_TT_REACHED\n\
    LBGT UPD_W_TT_RIGHT\n\
    ; cur_x > from_x: walk left\n\
    LDD 1,Y\n\
    SUBD #1\n\
    STD 1,Y\n\
    LDA #1\n\
    STA 17,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_TT_RIGHT:\n\
    LDD 1,Y\n\
    ADDD #1\n\
    STD 1,Y\n\
    CLR 17,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_TT_REACHED:\n\
    ; Arrived at from_x: load precomputed vy0 and enter AIRBORNE.\n\
    LDA 27,Y            ; vy0_stash (set at commit from trans entry)\n\
    STA 25,Y            ; vy (i8)\n\
    LDA #120\n\
    STA 24,Y            ; airborne timeout (frames)\n\
    ; Face toward target_x\n\
    LDD 22,Y\n\
    CMPD 1,Y\n\
    LBGT UPD_W_TT_FACE_R\n\
    LDA #1\n\
    STA 17,Y\n\
    LBRA UPD_W_TT_AIR\n\
UPD_W_TT_FACE_R:\n\
    CLR 17,Y\n\
UPD_W_TT_AIR:\n\
    LDA #2\n\
    STA 18,Y            ; sub_state = AIRBORNE\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_W_AIR:\n\
    ; Check timeout first\n\
    DEC 24,Y\n\
    LBEQ UPD_W_AIR_LAND\n\
    ; X interp toward target_x by 2 px/frame\n\
    LDD 22,Y\n\
    CMPD 1,Y\n\
    LBEQ UPD_W_AIR_Y    ; x at target\n\
    LBGT UPD_W_AIR_X_R\n\
    LDD 1,Y\n\
    SUBD #2\n\
    CMPD 22,Y\n\
    LBGT UPD_W_AIR_X_OKL\n\
    LDD 22,Y\n\
UPD_W_AIR_X_OKL:\n\
    STD 1,Y\n\
    LBRA UPD_W_AIR_Y\n\
UPD_W_AIR_X_R:\n\
    LDD 1,Y\n\
    ADDD #2\n\
    CMPD 22,Y\n\
    LBLT UPD_W_AIR_X_OKR\n\
    LDD 22,Y\n\
UPD_W_AIR_X_OKR:\n\
    STD 1,Y\n\
UPD_W_AIR_Y:\n\
    ; y += vy (sign-extended), vy -= 1, clamp vy >= -4\n\
    LDB 25,Y\n\
    SEX                 ; D = signed vy\n\
    ADDD 3,Y\n\
    STD 3,Y\n\
    LDB 25,Y\n\
    DECB\n\
    CMPB #$FC           ; -4\n\
    BGE UPD_W_AIR_VYOK\n\
    LDB #$FC\n\
UPD_W_AIR_VYOK:\n\
    STB 25,Y\n\
    ; Check land: compute target_y = areas[cur_area].y + feet_offset and compare\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    TFR D,X\n\
    LDB 19,Y\n\
    LDA #8\n\
    MUL\n\
    ADDD #2\n\
    LEAX D,X            ; X = &area[cur_area_idx] (target)\n\
    LDB 26,Y            ; B = feet_offset (low byte)\n\
    CLRA                ; A = 0 (high byte)\n\
    ADDD ,X             ; D = feet_offset + area.y (16-bit at X)\n\
    ; If trans_type=2 (drop) or vy<=0 (descending): land if cur_y <= target_y\n\
    ; Else (ascending jump_up): just keep going\n\
    PSHS D              ; stash target_y (we'll need it twice)\n\
    LDA 21,Y\n\
    CMPA #2\n\
    BEQ UPD_W_AIR_CHK_DOWN\n\
    LDB 25,Y\n\
    TSTB\n\
    BPL UPD_W_AIR_NOLAND\n\
UPD_W_AIR_CHK_DOWN:\n\
    LDD ,S              ; reload target_y\n\
    CMPD 3,Y            ; target_y vs cur_y\n\
    LBLT UPD_W_AIR_NOLAND  ; target_y < cur_y → still above\n\
    ; cur_y <= target_y: land — snap and switch to WALK\n\
    PULS D              ; D = target_y\n\
    STD 3,Y             ; snap world_y\n\
    CLR 18,Y            ; sub_state = WALK\n\
    LDA #1\n\
    STA 7,Y             ; action = walk\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_AIR_NOLAND:\n\
    LEAS 2,S            ; discard saved target_y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_AIR_LAND:\n\
    ; Timeout path: recompute target_y, snap, switch to WALK\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    TFR D,X\n\
    LDB 19,Y\n\
    LDA #8\n\
    MUL\n\
    ADDD #2\n\
    LEAX D,X\n\
    LDB 26,Y\n\
    CLRA\n\
    ADDD ,X             ; D = feet_offset + area.y\n\
    STD 3,Y\n\
    CLR 18,Y            ; sub_state = WALK\n\
    LDA #1\n\
    STA 7,Y             ; action = walk\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_ENE_NEXT_POP:\n\
    PULS B              ; restore loop counter\n\
    LEAY 28,Y           ; next pool record\n\
    DECB\n\
    LBNE UPD_ENE_LOOP\n\
    PULS A              ; restore original bank\n\
    STA CURRENT_ROM_BANK\n\
    STA $DF00\n\
UPD_ENE_DONE:\n\
    RTS\n\n"
        );
    } else {
        asm.push_str(
"; UPDATE_ENEMIES_RUNTIME (single-bank)\n\
; Same as multibank version without bank switching.\n\
UPDATE_ENEMIES_RUNTIME:\n\
    LDB >ENEMY_COUNT\n\
    LBEQ UPD_ENE_DONE\n\
    LDY #ENEMY_POOL\n\
UPD_ENE_LOOP:\n\
    PSHS B\n\
    LDA ,Y\n\
    LBEQ UPD_ENE_NEXT_POP\n\
    JSR UPD_DECAY_CHECK   ; SM auto-decay (matches per-state decay_frames)\n\
    ; Frozen-action guard: action >= 2 = SM-frozen (snow1/snow2/ball) → skip movement\n\
    LDA 7,Y\n\
    CMPA #2\n\
    LBHS UPD_ENE_NEXT_POP\n\
    LDA 8,Y\n\
    CMPA #1\n\
    LBEQ UPD_PATROL\n\
    CMPA #4\n\
    LBEQ UPD_WANDER\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_PATROL:\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    CMPD #0\n\
    LBEQ UPD_ENE_NEXT_POP\n\
    TFR D,X\n\
    LDA 10,Y\n\
    ASLA\n\
    ASLA\n\
    LEAX A,X\n\
    LDD ,X\n\
    CMPD 1,Y\n\
    LBEQ UPD_P_MOVE_Y\n\
    LBGT UPD_P_INC_X\n\
    LDD 1,Y\n\
    SUBD #1\n\
    STD 1,Y\n\
    LDA #1\n\
    STA 17,Y\n\
    LBRA UPD_P_MOVE_Y\n\
UPD_P_INC_X:\n\
    LDD 1,Y\n\
    ADDD #1\n\
    STD 1,Y\n\
    CLR 17,Y\n\
UPD_P_MOVE_Y:\n\
    LDD 2,X\n\
    CMPD 3,Y\n\
    LBEQ UPD_P_CHECK_WP\n\
    LBGT UPD_P_INC_Y\n\
    LDD 3,Y\n\
    SUBD #1\n\
    STD 3,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_P_INC_Y:\n\
    LDD 3,Y\n\
    ADDD #1\n\
    STD 3,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_P_CHECK_WP:\n\
    LDD ,X\n\
    CMPD 1,Y\n\
    LBNE UPD_ENE_NEXT_POP\n\
    INC 10,Y\n\
    LDA 10,Y\n\
    CMPA 16,Y\n\
    LBLO UPD_ENE_NEXT_POP\n\
    CLR 10,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_WANDER:\n\
    LDA 18,Y\n\
    LBEQ UPD_W_WALK\n\
    CMPA #1\n\
    LBEQ UPD_W_IDLE\n\
    CMPA #2\n\
    LBEQ UPD_W_AIR\n\
    CMPA #3\n\
    LBEQ UPD_W_TT\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_W_WALK:\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    CMPD #0\n\
    LBEQ UPD_ENE_NEXT_POP\n\
    TFR D,X\n\
    LDB 19,Y\n\
    LDA #8\n\
    MUL\n\
    ADDD #2\n\
    LEAX D,X\n\
    LDA 17,Y\n\
    LBNE UPD_W_WALK_L\n\
    LDD 1,Y\n\
    ADDD #1\n\
    PSHS D\n\
    LDD 4,X\n\
    CMPD ,S\n\
    LBLT UPD_W_EDGE_R\n\
    PULS D\n\
    STD 1,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_EDGE_R:\n\
    LEAS 2,S\n\
    LDD 4,X\n\
    STD 1,Y\n\
    LBRA UPD_W_EDGE\n\
UPD_W_WALK_L:\n\
    LDD 1,Y\n\
    SUBD #1\n\
    PSHS D\n\
    LDD 2,X\n\
    CMPD ,S\n\
    LBGT UPD_W_EDGE_L\n\
    PULS D\n\
    STD 1,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_EDGE_L:\n\
    LEAS 2,S\n\
    LDD 2,X\n\
    STD 1,Y\n\
UPD_W_EDGE:\n\
    LDA 17,Y\n\
    EORA #1\n\
    STA 17,Y\n\
    LDA #1\n\
    STA 18,Y\n\
    CLR 7,Y\n\
    JSR RAND_HELPER\n\
    ANDB #$3F\n\
    ADDB #90\n\
    STB 20,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_W_IDLE:\n\
    DEC 20,Y\n\
    LBNE UPD_ENE_NEXT_POP\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    TFR D,X\n\
    LDB 1,X\n\
    LBEQ UPD_W_TO_WALK\n\
    PSHS B\n\
    LDA ,X\n\
    LDB #8\n\
    MUL\n\
    ADDD #2\n\
    LEAX D,X\n\
    PULS B\n\
UPD_W_TRY_LOOP:\n\
    LDA 19,Y\n\
    CMPA ,X\n\
    BNE UPD_W_NEXT_TRY\n\
    PSHS B,X\n\
    JSR RAND_HELPER\n\
    ANDB #3\n\
    TSTB\n\
    PULS B,X\n\
    BNE UPD_W_NEXT_TRY\n\
    LDA 1,X\n\
    STA 19,Y\n\
    LDA 2,X\n\
    STA 21,Y\n\
    LDA 3,X\n\
    STA 27,Y            ; vy0_stash from trans entry\n\
    LDD 4,X\n\
    STD 24,Y\n\
    LDD 6,X\n\
    STD 22,Y\n\
    LDA #3\n\
    STA 18,Y\n\
    LDA #1\n\
    STA 7,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_NEXT_TRY:\n\
    LEAX 8,X\n\
    DECB\n\
    BNE UPD_W_TRY_LOOP\n\
UPD_W_TO_WALK:\n\
    CLR 18,Y\n\
    LDA #1\n\
    STA 7,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_W_TT:\n\
    LDD 24,Y\n\
    CMPD 1,Y\n\
    LBEQ UPD_W_TT_REACHED\n\
    LBGT UPD_W_TT_RIGHT\n\
    LDD 1,Y\n\
    SUBD #1\n\
    STD 1,Y\n\
    LDA #1\n\
    STA 17,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_TT_RIGHT:\n\
    LDD 1,Y\n\
    ADDD #1\n\
    STD 1,Y\n\
    CLR 17,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_TT_REACHED:\n\
    LDA 27,Y            ; vy0_stash from commit\n\
    STA 25,Y\n\
    LDA #120\n\
    STA 24,Y\n\
    LDD 22,Y\n\
    CMPD 1,Y\n\
    LBGT UPD_W_TT_FACE_R\n\
    LDA #1\n\
    STA 17,Y\n\
    LBRA UPD_W_TT_AIR\n\
UPD_W_TT_FACE_R:\n\
    CLR 17,Y\n\
UPD_W_TT_AIR:\n\
    LDA #2\n\
    STA 18,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_W_AIR:\n\
    DEC 24,Y\n\
    LBEQ UPD_W_AIR_LAND\n\
    LDD 22,Y\n\
    CMPD 1,Y\n\
    LBEQ UPD_W_AIR_Y\n\
    LBGT UPD_W_AIR_X_R\n\
    LDD 1,Y\n\
    SUBD #2\n\
    CMPD 22,Y\n\
    LBGT UPD_W_AIR_X_OKL\n\
    LDD 22,Y\n\
UPD_W_AIR_X_OKL:\n\
    STD 1,Y\n\
    LBRA UPD_W_AIR_Y\n\
UPD_W_AIR_X_R:\n\
    LDD 1,Y\n\
    ADDD #2\n\
    CMPD 22,Y\n\
    LBLT UPD_W_AIR_X_OKR\n\
    LDD 22,Y\n\
UPD_W_AIR_X_OKR:\n\
    STD 1,Y\n\
UPD_W_AIR_Y:\n\
    LDB 25,Y\n\
    SEX\n\
    ADDD 3,Y\n\
    STD 3,Y\n\
    LDB 25,Y\n\
    DECB\n\
    CMPB #$FC\n\
    BGE UPD_W_AIR_VYOK\n\
    LDB #$FC\n\
UPD_W_AIR_VYOK:\n\
    STB 25,Y\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    TFR D,X\n\
    LDB 19,Y\n\
    LDA #8\n\
    MUL\n\
    ADDD #2\n\
    LEAX D,X            ; X = &area[cur_area]\n\
    LDB 26,Y            ; B = feet_offset\n\
    CLRA\n\
    ADDD ,X             ; D = feet_offset + area.y\n\
    PSHS D              ; stash target_y\n\
    LDA 21,Y\n\
    CMPA #2\n\
    BEQ UPD_W_AIR_CHK_DOWN\n\
    LDB 25,Y\n\
    TSTB\n\
    BPL UPD_W_AIR_NOLAND\n\
UPD_W_AIR_CHK_DOWN:\n\
    LDD ,S\n\
    CMPD 3,Y\n\
    LBLT UPD_W_AIR_NOLAND\n\
    PULS D\n\
    STD 3,Y\n\
    CLR 18,Y\n\
    LDA #1\n\
    STA 7,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_AIR_NOLAND:\n\
    LEAS 2,S\n\
    LBRA UPD_ENE_NEXT_POP\n\
UPD_W_AIR_LAND:\n\
    LDA 11,Y\n\
    LDB 12,Y\n\
    TFR D,X\n\
    LDB 19,Y\n\
    LDA #8\n\
    MUL\n\
    ADDD #2\n\
    LEAX D,X\n\
    LDB 26,Y\n\
    CLRA\n\
    ADDD ,X             ; D = feet_offset + area.y\n\
    STD 3,Y\n\
    CLR 18,Y\n\
    LDA #1\n\
    STA 7,Y\n\
    LBRA UPD_ENE_NEXT_POP\n\
\n\
UPD_ENE_NEXT_POP:\n\
    PULS B\n\
    LEAY 28,Y\n\
    DECB\n\
    LBNE UPD_ENE_LOOP\n\
UPD_ENE_DONE:\n\
    RTS\n\n"
        );
    }

    asm.push_str(
"; DRAW_ENEMIES_RUNTIME\n\
; For each active enemy, draws its current-action sprite.\n\
; Enemy type header layout: FCB hp, FCB speed, FDB action_dur, FCB action_count\n\
;   followed by _NAME_ENEMY_ACTIONS table.\n\
; Multibank action entry (6 bytes):\n\
;   [0] FCB sprite_idx   — 0-based index into VECTOR_ADDR_TABLE (vec) or ANIM_ADDR_TABLE (vanim); $FF=none\n\
;   [1] FCB sprite_type  — 0=vec, 1=vanim\n\
;   [2] FCB loop         — 0=one-shot, 1=loop\n\
;   [3] FCB pad\n\
;   [4-5] FDB anim_state — 16-bit RAM address of 2-byte animation state; 0 for vec actions\n\
; Enemy type data resides in the helpers bank (always accessible).\n\
DRAW_ENEMIES_RUNTIME:\n\
    LDB >ENEMY_COUNT\n\
    LBEQ DRW_ENE_DONE\n\
    LDY #ENEMY_POOL\n\
DRW_ENE_LOOP:\n\
    PSHS B              ; save outer loop counter\n\
    LDA ,Y              ; active?\n\
    LBEQ DRW_ENE_NEXT_POP\n\
    ; Resolve type header and action table entry\n\
    LDA 5,Y             ; type_ptr hi\n\
    LDB 6,Y             ; type_ptr lo\n\
    TFR D,X             ; X = _NAME_ENEMY header\n\
    LEAX 7,X            ; skip 7-byte header → action table\n\
    LDA 7,Y             ; action index\n");

    if is_multibank {
        asm.push_str(
"    LDB #6              ; 6 bytes per action entry (multibank)\n\
    MUL                 ; D = action_idx * 6\n\
    LEAX D,X            ; X = &actions[action]\n\
; --- Multibank: FCB sprite_idx at action[+0], FCB sprite_type at action[+1] ---\n\
    LDA ,X              ; sprite_idx (byte [0])\n\
    CMPA #$FF           ; $FF = no sprite assigned\n\
    LBEQ DRW_ENE_NEXT_POP\n\
    STA >ENEMY_SCRATCH_PTR  ; save sprite_idx (hi byte of 2-byte scratch)\n\
    LDB 1,X             ; sprite_type (byte [1]): 0=vec, 1=vanim\n\
    STB >ENEMY_SCRATCH_Y    ; save sprite_type (lo byte of 2-byte scratch)\n\
    ; Read FDB anim_state ptr from bytes [4,5] while X still points to action entry\n\
    LDA 4,X             ; anim_state addr hi\n\
    STA >ENEMY_SCRATCH_X    ; save hi\n\
    LDA 5,X             ; anim_state addr lo\n\
    STA >ENEMY_SCRATCH_X+1  ; save lo\n\
    ; screen_x = world_x(16-bit) - camera_x(16-bit), y unchanged\n\
    LDA 1,Y             ; world_x hi (POOL_X_HI)\n\
    LDB 2,Y             ; world_x lo (POOL_X_LO)\n\
    SUBD >CAMERA_X      ; D = world_x - camera_x (16-bit)\n\
    STA >TMPPTR2        ; save high byte for range check\n\
    TFR B,A\n\
    SEX                 ; A = sign-extend of B (0x00 or 0xFF)\n\
    CMPA >TMPPTR2       ; compare with actual high byte\n\
    LBNE DRW_ENE_NEXT_POP  ; out of 8-bit range — skip draw\n\
    STB >DRAW_VEC_X\n\
    STA >DRAW_VEC_X_HI  ; A holds sign-extension of B (set by SEX above) — needed for 16-bit clipping in SLR_DRAW_CLIPPED_PATH\n\
    LDB 4,Y             ; world_y lo (POOL_Y_LO)\n\
    STB >DRAW_VEC_Y\n\
    ; Mirror: 0 = facing right (no mirror), 1 = facing left (flip X).\n\
    ; POOL_DIR is set by UPDATE_ENEMIES based on patrol movement.\n\
    ; Set BOTH MIRROR_X (vec path → DSWM) and DRAW_ANIM_MIRROR_X. DRAW_ANIM_BANKED\n\
    ; clears MIRROR_X at entry so animated sprites need the persistent ANIM flag\n\
    ; which DRAW_ANIM_RUNTIME re-applies to MIRROR_X for each frame's path loop.\n\
    LDA 17,Y            ; POOL_DIR (0=right, 1=left)\n\
    STA >MIRROR_X\n\
    STA >DRAW_ANIM_MIRROR_X\n\
    CLR >MIRROR_Y\n\
    ; Branch on sprite_type\n\
    LDB >ENEMY_SCRATCH_Y\n\
    CMPB #1\n\
    BEQ DRW_ENE_VANIM\n\
; --- Vec path: DRAW_VECTOR_BANKED (bank-switches to vector's bank) ---\n\
    PSHS Y              ; save pool pointer (DRAW_VECTOR_BANKED clobbers Y)\n\
    CLRA\n\
    LDB >ENEMY_SCRATCH_PTR  ; B = sprite_idx (vec index)\n\
    TFR D,X             ; X = sprite_idx (16-bit, A=0)\n\
    JSR DRAW_VECTOR_BANKED\n\
    PULS Y              ; restore pool pointer\n\
    LBRA DRW_ENE_NEXT_POP\n\
");
        // Vanim branch: only emitted when enemy types use .vanim sprites
        if has_vanim_enemies {
            asm.push_str(
"; --- Vanim path: DRAW_ANIM_BANKED ---\n\
DRW_ENE_VANIM:\n\
    LDA >ENEMY_SCRATCH_X    ; anim_state ptr hi\n\
    LDB >ENEMY_SCRATCH_X+1  ; anim_state ptr lo\n\
    CMPD #0\n\
    LBEQ DRW_ENE_NEXT_POP    ; no state allocated → skip\n\
    TFR D,U             ; U = anim_state ptr (frame_idx, ticks_left)\n\
    PSHS Y              ; save pool pointer\n\
    CLRA\n\
    LDB >ENEMY_SCRATCH_PTR  ; B = sprite_idx (anim index)\n\
    TFR D,X             ; X = anim_idx (16-bit, A=0)\n\
    JSR DRAW_ANIM_BANKED\n\
    PULS Y              ; restore pool pointer\n\
");
        } else {
            // No vanim enemies — DRW_ENE_VANIM just falls through to DRW_ENE_NEXT_POP
            asm.push_str("DRW_ENE_VANIM:\n");
        }
        asm.push_str(
"DRW_ENE_NEXT_POP:\n\
    PULS B              ; restore outer loop counter\n\
    LEAY 28,Y           ; next pool record\n\
    DECB\n\
    LBNE DRW_ENE_LOOP\n\
DRW_ENE_DONE:\n\
    RTS\n\n"
        );
    } else {
        // SINGLE-BANK: action table uses compile_to_asm_with_name() format:
        //   [0-1] FDB sprite_ptr  — direct address of _NAME_VECTORS (0=no sprite)
        //   [2]   FCB sprite_type — 0=vec, 1=vanim
        //   [3]   FCB loop
        // Total: 4 bytes per entry.
        // Path loop mirrors DRAW_VECTOR_BANKED (no bank switch needed).
        asm.push_str(
"    LDB #4              ; 4 bytes per action entry (FDB sprite_ptr+FCB type+FCB loop)\n\
    MUL                 ; D = action_idx * 4\n\
    LEAX D,X            ; X = &actions[action]\n\
    LDD ,X              ; sprite_ptr = FDB at action[0,1] (_NAME_VECTORS address)\n\
    CMPD #0             ; 0 = no sprite assigned\n\
    LBEQ DRW_ENE_NEXT_POP\n\
    TFR D,X             ; X = _NAME_VECTORS header address\n\
    ; screen_x = world_x(16-bit) - camera_x(16-bit), y unchanged\n\
    LDA 1,Y             ; world_x hi (POOL_X_HI)\n\
    LDB 2,Y             ; world_x lo (POOL_X_LO)\n\
    SUBD CAMERA_X       ; D = world_x - camera_x (16-bit, DP=$C8 relative)\n\
    STA TMPPTR2         ; save high byte for range check\n\
    TFR B,A\n\
    SEX                 ; A = sign-extend of B (0x00 or 0xFF)\n\
    CMPA TMPPTR2        ; compare with actual high byte\n\
    LBNE DRW_ENE_NEXT_POP  ; out of 8-bit range — skip draw\n\
    STB DRAW_VEC_X      ; screen_x lo byte\n\
    STA DRAW_VEC_X_HI   ; A holds sign-extension of B (set by SEX above)\n\
    LDB 4,Y             ; world_y lo (POOL_Y_LO)\n\
    STB DRAW_VEC_Y\n\
    CLR DRAW_VEC_INTENSITY  ; use vector's own intensity\n\
    ; Mirror from POOL_DIR (set by UPDATE_ENEMIES patrol move): 0=right, 1=left.\n\
    ; Set both MIRROR_X (path loop) and DRAW_ANIM_MIRROR_X (DAR re-applies it\n\
    ; per frame because DRAW_ANIM_BANKED clears MIRROR_X at entry).\n\
    LDA 17,Y\n\
    STA MIRROR_X\n\
    STA DRAW_ANIM_MIRROR_X\n\
    CLR MIRROR_Y\n\
    ; Draw paths — mirrors DRAW_VECTOR_BANKED path loop (no bank switch)\n\
    JSR $F1AA           ; DP_to_D0 (required before DSWM / VIA access)\n\
    LDD ,X              ; D = path_count (FDB at vector header start)\n\
    CMPD #0\n\
    LBEQ DRW_ENE_SB_DONE\n\
    PSHS Y              ; save pool ptr (Y used as path table ptr below)\n\
    LEAY 2,X            ; Y = first path FDB entry (skip 2-byte path_count)\n\
DRW_ENE_SB_PATH:\n\
    PSHS D              ; save remaining path count\n\
    LDX ,Y              ; X = path data address (FDB entry)\n\
    JSR Draw_Sync_List_At_With_Mirrors\n\
    LEAY 2,Y            ; advance to next FDB entry\n\
    PULS D              ; restore count\n\
    SUBD #1\n\
    BNE DRW_ENE_SB_PATH\n\
    PULS Y              ; restore pool ptr\n\
DRW_ENE_SB_DONE:\n\
    JSR $F1AF           ; DP_to_C8 (restore DP for RAM access)\n\
DRW_ENE_NEXT_POP:\n\
    PULS B              ; restore outer loop counter\n\
    LEAY 28,Y           ; next pool record\n\
    DECB\n\
    LBNE DRW_ENE_LOOP\n\
DRW_ENE_DONE:\n\
    RTS\n\n"
        );
    }

    // KILL_ENEMY_RUNTIME and ENEMY_FIRE_EVENT_RUNTIME subroutines
    asm.push_str(
"\n\
; KILL_ENEMY_RUNTIME\n\
; Entry: A = enemy index (0-based)\n\
; Effect: pool[A].active=0, ENEMY_COUNT--\n\
; Return: RESULT = new ENEMY_COUNT (D)\n\
KILL_ENEMY_RUNTIME:\n\
    LDB #28             ; ENEMY_POOL_STRIDE\n\
    MUL\n\
    LDX #ENEMY_POOL\n\
    LEAX D,X\n\
    CLR ,X              ; active = 0\n\
    DEC >ENEMY_COUNT\n\
    CLRA\n\
    LDB >ENEMY_COUNT\n\
    STD RESULT\n\
    RTS\n\
\n\
; ENEMY_FIRE_EVENT_RUNTIME\n\
; Entry: A = enemy index, B = event hash (FNV-1a u8)\n\
; Looks up the current SM state, scans on_event table, applies transition.\n\
; Uses ENEMY_SCRATCH_PTR (2 bytes) and ENEMY_SCRATCH_X (1 byte) as temporals.\n\
ENEMY_FIRE_EVENT_RUNTIME:\n\
    STB >ENEMY_SCRATCH_X    ; save event hash (1 byte)\n\
    LDB #17\n\
    MUL                     ; D = A * stride\n\
    LDX #ENEMY_POOL\n\
    LEAX D,X                ; X = &pool[A]\n\
    STX >ENEMY_SCRATCH_PTR  ; save pool ptr\n\
    LDA 13,X     ; sm_state\n\
    CMPA #$FF\n\
    BEQ FIRE_EVT_RTS        ; no SM\n\
    LDA 5,X\n\
    LDB 6,X\n\
    TFR D,X                 ; X = type header\n\
    LDA 5,X                 ; SM hi\n\
    LDB 6,X                 ; SM lo\n\
    CMPD #0\n\
    BEQ FIRE_EVT_RTS\n\
    TFR D,X                 ; X = SM header\n\
    LEAX 2,X    ; X = &states[0]\n\
    PSHS X                  ; save states[0] ptr on stack\n\
    LDX >ENEMY_SCRATCH_PTR  ; X = pool entry\n\
    LDA 13,X     ; current state\n\
    PULS X                  ; X = states[0] again\n\
    LDB #13\n\
    MUL\n\
    LEAX D,X                ; X = &states[current]\n\
    LDB 4,X        ; event count\n\
    BEQ FIRE_EVT_RTS\n\
    LEAX 5,X      ; X = first event pair\n\
    LDA >ENEMY_SCRATCH_X    ; event hash\n\
FIRE_EVT_SCAN:\n\
    CMPA ,X\n\
    BEQ FIRE_EVT_MATCH\n\
    LEAX 2,X\n\
    DECB\n\
    BNE FIRE_EVT_SCAN\n\
    BRA FIRE_EVT_RTS\n\
FIRE_EVT_MATCH:\n\
    LDB 1,X                 ; to_state_idx\n\
    STB >ENEMY_SCRATCH_X    ; save to_state_idx\n\
    LDX >ENEMY_SCRATCH_PTR  ; X = pool entry\n\
    STB 13,X     ; apply new state\n\
    ; Look up new state record for action/decay\n\
    LDA 5,X\n\
    LDB 6,X\n\
    TFR D,X                 ; X = type header\n\
    LDA 5,X\n\
    LDB 6,X\n\
    TFR D,X                 ; X = SM header\n\
    LEAX 2,X    ; X = &states[0]\n\
    LDA >ENEMY_SCRATCH_X    ; to_state_idx\n\
    LDB #13\n\
    MUL\n\
    LEAX D,X                ; X = &states[to]\n\
    ; Store action/decay into pool without LDY (VASM LDY extended mode bug workaround)\n\
    LDA 1,X\n\
    LDB 2,X\n\
    STD >ENEMY_SCRATCH_Y    ; save decay hi+lo in 2-byte scratch\n\
    LDA 0,X      ; action_idx\n\
    PSHS A                  ; save action on stack\n\
    LDX >ENEMY_SCRATCH_PTR  ; X = pool entry\n\
    PULS A\n\
    STA 7,X       ; update pool action\n\
    LDA >ENEMY_SCRATCH_Y\n\
    STA 14,X\n\
    LDA >ENEMY_SCRATCH_Y+1\n\
    STA 15,X\n\
FIRE_EVT_RTS:\n\
    RTS\n\
\n\
; SET_ENEMY_STATE_RUNTIME\n\
; Entry: A = enemy idx, B = target state_idx\n\
; Thin wrapper: compute pool ptr from idx, then dispatch to SES_APPLY which\n\
; does the actual state-record lookup and field writes. SES_APPLY is also\n\
; called from UPD_DECAY_CHECK (auto-decay) using Y-derived pool ptr.\n\
SET_ENEMY_STATE_RUNTIME:\n\
    STB >ENEMY_SCRATCH_X    ; save target state_idx\n\
    LDB #28                 ; ENEMY_POOL_STRIDE\n\
    MUL\n\
    LDX #ENEMY_POOL\n\
    LEAX D,X                ; X = &pool[idx]\n\
    STX >ENEMY_SCRATCH_PTR\n\
    JMP SES_APPLY\n\
\n\
; SES_APPLY: apply a state transition to a pool entry.\n\
; Entry: ENEMY_SCRATCH_PTR = pool entry ptr, ENEMY_SCRATCH_X = target_state_idx\n\
; Updates pool.sm_state (+13), pool.action (+7) [unless action_idx=$FF=keep],\n\
; and pool.sm_decay_timer (+14..15) from the type's SM state record.\n\
; Falls back to plain STB 13,X if no SM exists. Preserves Y.\n\
SES_APPLY:\n\
    LDX >ENEMY_SCRATCH_PTR\n\
    LDA 13,X                ; current sm_state\n\
    CMPA #$FF\n\
    BEQ SES_PLAIN           ; no SM → just store the byte\n\
    LDA 5,X                 ; type_ptr hi\n\
    LDB 6,X                 ; type_ptr lo\n\
    TFR D,X                 ; X = type header\n\
    LDA 5,X                 ; SM ptr hi\n\
    LDB 6,X                 ; SM ptr lo\n\
    CMPD #0\n\
    BEQ SES_PLAIN\n\
    TFR D,X                 ; X = SM header\n\
    LEAX 2,X                ; X = &states[0]\n\
    LDA >ENEMY_SCRATCH_X    ; target state_idx\n\
    LDB #13\n\
    MUL                     ; D = target * 13\n\
    LEAX D,X                ; X = &states[target]\n\
    LDA 1,X\n\
    LDB 2,X\n\
    STD >ENEMY_SCRATCH_Y    ; stash decay hi+lo\n\
    LDA ,X                  ; action_idx ($FF = keep)\n\
    PSHS A\n\
    LDX >ENEMY_SCRATCH_PTR  ; X = pool entry\n\
    LDB >ENEMY_SCRATCH_X    ; target state_idx\n\
    STB 13,X                ; pool.sm_state = target\n\
    PULS A\n\
    CMPA #$FF\n\
    BEQ SES_SKIP_ACTION\n\
    STA 7,X                 ; pool.action = state.action\n\
SES_SKIP_ACTION:\n\
    LDA >ENEMY_SCRATCH_Y\n\
    STA 14,X                ; sm_decay_timer hi\n\
    LDA >ENEMY_SCRATCH_Y+1\n\
    STA 15,X                ; sm_decay_timer lo\n\
    RTS\n\
SES_PLAIN:\n\
    LDX >ENEMY_SCRATCH_PTR\n\
    LDB >ENEMY_SCRATCH_X\n\
    STB 13,X\n\
    RTS\n\
\n\
; UPD_DECAY_CHECK: auto-decay tick for one pool entry.\n\
; Entry: Y = &pool[i] (preserved on exit)\n\
; If pool.sm_decay_timer > 0: decrement. On reaching 0, look up the current\n\
; state's decay_to_idx (state record offset +3) and apply that transition\n\
; via SES_APPLY. If decay_to is $FF (none) the state stays put.\n\
; Honours the per-state decay_frames declared in the .venemy SM, so SnowBros\n\
; thaw walks ball→snow2→snow1→normal automatically with their own timings.\n\
UPD_DECAY_CHECK:\n\
    LDD 14,Y                ; sm_decay_timer\n\
    LBEQ UDC_DONE           ; not decaying\n\
    SUBD #1\n\
    STD 14,Y\n\
    LBNE UDC_DONE           ; still counting\n\
    ; Timer hit 0 → resolve current state's decay_to\n\
    LDA 5,Y\n\
    LDB 6,Y\n\
    TFR D,X                 ; X = type header\n\
    LDA 5,X\n\
    LDB 6,X\n\
    CMPD #0\n\
    BEQ UDC_DONE            ; no SM (defensive)\n\
    TFR D,X                 ; X = SM header\n\
    LEAX 2,X                ; X = &states[0]\n\
    LDA 13,Y                ; current sm_state\n\
    LDB #13\n\
    MUL\n\
    LEAX D,X                ; X = &states[current]\n\
    LDA 3,X                 ; decay_to_idx\n\
    CMPA #$FF\n\
    BEQ UDC_DONE            ; no decay target\n\
    ; Apply transition via SES_APPLY (preserves Y)\n\
    STA >ENEMY_SCRATCH_X    ; target = decay_to_idx\n\
    STY >ENEMY_SCRATCH_PTR  ; pool ptr = current Y\n\
    JSR SES_APPLY\n\
UDC_DONE:\n\
    RTS\n\
\n\
"
    );
}

