// Builtins - Implementation of built-in functions for M6809 backend
use crate::ast::{Expr, Stmt};
use crate::codegen::CodegenOptions;
use super::{FuncCtx, emit_expr, fresh_label};

pub fn resolve_function_name(name: &str) -> Option<String> {
    let map = [
        ("PRINT_TEXT", "VECTREX_PRINT_TEXT"),
        ("DEBUG_PRINT", "VECTREX_DEBUG_PRINT"),
        ("DEBUG_PRINT_LABELED", "VECTREX_DEBUG_PRINT_LABELED"),
        ("POKE", "VECTREX_POKE"),
        ("PEEK", "VECTREX_PEEK"),
        ("PRINT_NUMBER", "VECTREX_PRINT_NUMBER"),
        ("MOVE_TO", "VECTREX_MOVE_TO"),
        ("DRAW_TO", "VECTREX_DRAW_TO"),
        ("DRAW_VL", "VECTREX_DRAW_VL"),
        ("FRAME_BEGIN", "VECTREX_FRAME_BEGIN"),
        ("VECTOR_PHASE_BEGIN", "VECTREX_VECTOR_PHASE_BEGIN"),
        ("SET_ORIGIN", "VECTREX_SET_ORIGIN"),
        ("SET_INTENSITY", "VECTREX_SET_INTENSITY"),
        ("WAIT_RECAL", "VECTREX_WAIT_RECAL"),
        ("PLAY_MUSIC1", "VECTREX_PLAY_MUSIC1"),
    ];
    map.iter()
        .find(|(k, _)| k == &name)
        .map(|(_, v)| v.to_string())
}

pub fn emit_builtin_call(name: &str, args: &Vec<Expr>, out: &mut String, fctx: &FuncCtx, string_map: &std::collections::BTreeMap<String,String>, opts: &CodegenOptions, line_info: Option<usize>) -> bool {
    let up = name.to_ascii_uppercase();
    let is = matches!(up.as_str(),
        "VECTREX_PRINT_TEXT"|"VECTREX_DEBUG_PRINT"|"VECTREX_DEBUG_PRINT_LABELED"|"VECTREX_POKE"|"VECTREX_PEEK"|"VECTREX_PRINT_NUMBER"|"VECTREX_MOVE_TO"|"VECTREX_DRAW_TO"|"DRAW_LINE_WRAPPER"|"DRAW_LINE_FAST"|"SETUP_DRAW_COMMON"|"VECTREX_DRAW_VL"|"VECTREX_DRAW_VECTORLIST"|"VECTREX_FRAME_BEGIN"|"VECTREX_VECTOR_PHASE_BEGIN"|"VECTREX_SET_ORIGIN"|"VECTREX_SET_INTENSITY"|"VECTREX_WAIT_RECAL"|
    "VECTREX_PLAY_MUSIC1"|"DRAW_VECTOR"|"DRAW_VECTOR_EX"|"DRAW_VECTOR_LIST"|"DRAW_LINE"|"PLAY_MUSIC"|"PLAY_SFX"|"STOP_MUSIC"|"AUDIO_UPDATE"|"MUSIC_UPDATE"|"SFX_UPDATE"|"ASM"|
        "J1_X"|"J1_Y"|"UPDATE_BUTTONS"|"J1_BUTTON_1"|"J1_BUTTON_2"|"J1_BUTTON_3"|"J1_BUTTON_4"|
        "J2_X"|"J2_Y"|"J2_BUTTON_1"|"J2_BUTTON_2"|"J2_BUTTON_3"|"J2_BUTTON_4"|
        "LOAD_LEVEL"|"SHOW_LEVEL"|"UPDATE_LEVEL"|
        "SIN"|"COS"|"TAN"|"MATH_SIN"|"MATH_COS"|"MATH_TAN"|
    "ABS"|"MATH_ABS"|"MIN"|"MATH_MIN"|"MAX"|"MATH_MAX"|"CLAMP"|"MATH_CLAMP"|"LEN"|
    "MUL_A"|"DIV_A"|"MOD_A"|
    "DRAW_CIRCLE"|"DRAW_CIRCLE_SEG"|"DRAW_ARC"|"DRAW_SPIRAL"|"DRAW_VECTORLIST"|"DRAW_POLYGON"|
    "DRAW_RECT"|"DRAW_FILLED_RECT"|
    "DEBUG_PRINT"|"DEBUG_PRINT_LABELED"|"DEBUG_PRINT_STR"
    );
    
    // Helper para agregar comentario de tracking cuando es una llamada nativa real
    let add_native_call_comment = |out: &mut String, func_name: &str| {
        if let Some(line) = line_info {
            out.push_str(&format!("; NATIVE_CALL: {} at line {}\n", func_name, line));
        }
    };
    
    // DRAW_VECTOR: Draw vector asset at position
    // Usage: DRAW_VECTOR("player", x, y) -> draws vector at absolute position (x, y)
    if up == "DRAW_VECTOR" && args.len() == 3 {
        if let Expr::StringLit(asset_name) = &args[0] {
            // Check if asset exists in opts.assets
            let asset_exists = opts.assets.iter().any(|a| {
                a.name == *asset_name && matches!(a.asset_type, crate::codegen::AssetType::Vector)
            });
            
            if asset_exists {
                // Find the asset to get path count
                let asset_info = opts.assets.iter()
                    .find(|a| a.name == *asset_name && matches!(a.asset_type, crate::codegen::AssetType::Vector))
                    .unwrap();
                
                // Load the .vec file to count paths
                use crate::vecres::VecResource;
                let path_count = if let Ok(resource) = VecResource::load(std::path::Path::new(&asset_info.path)) {
                    resource.visible_paths().len()
                } else {
                    1 // Fallback to 1 if can't load
                };
                
                let symbol = format!("_{}", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
                
                out.push_str(&format!("; DRAW_VECTOR(\"{}\", x, y) - {} path(s) at position\n", asset_name, path_count));
                
                // Evaluate x position (arg 1) - save immediately to avoid overwrite
                emit_expr(&args[1], out, fctx, string_map, opts);
                out.push_str("    LDA RESULT+1  ; X position (low byte)\n");
                out.push_str("    STA TMPPTR    ; Save X to temporary storage\n");
                
                // Evaluate y position (arg 2) - now RESULT is overwritten, but X is saved
                emit_expr(&args[2], out, fctx, string_map, opts);
                out.push_str("    LDA RESULT+1  ; Y position (low byte)\n");
                out.push_str("    STA TMPPTR+1  ; Save Y to temporary storage\n");
                
                // Restore X and Y from temporary storage and set positions
                out.push_str("    LDA TMPPTR    ; X position\n");
                out.push_str("    STA DRAW_VEC_X\n");
                out.push_str("    LDA TMPPTR+1  ; Y position\n");
                out.push_str("    STA DRAW_VEC_Y\n");
                
                // Generate code to draw each path at offset position
                // Clear mirror flags (DRAW_VECTOR uses no mirroring)
                out.push_str("    CLR MIRROR_X\n");
                out.push_str("    CLR MIRROR_Y\n");
                out.push_str("    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data\n");
                out.push_str("    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)\n");
                for path_idx in 0..path_count {
                    out.push_str(&format!("    LDX #{}_PATH{}  ; Path {}\n", symbol, path_idx, path_idx));
                    out.push_str("    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function\n");
                }
                out.push_str("    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)\n");
                
                out.push_str("    LDD #0\n    STD RESULT\n");
                return true;
            } else {
                // Generate helpful compile-time error with list of available assets
                let available: Vec<&str> = opts.assets.iter()
                    .filter(|a| matches!(a.asset_type, crate::codegen::AssetType::Vector))
                    .map(|a| a.name.as_str())
                    .collect();
                
                out.push_str(&format!("; ╔════════════════════════════════════════════════════════════╗\n"));
                out.push_str(&format!("; ║  ❌ COMPILATION ERROR: Vector asset not found             ║\n"));
                out.push_str(&format!("; ╠════════════════════════════════════════════════════════════╣\n"));
                out.push_str(&format!("; ║  DRAW_VECTOR(\"{}\") - asset does not exist{:>width$}║\n", 
                    asset_name, "", width = 61 - asset_name.len() - 32));
                out.push_str(&format!("; ╠════════════════════════════════════════════════════════════╣\n"));
                if available.is_empty() {
                    out.push_str(&format!("; ║  No .vec files found in assets/vectors/                   ║\n"));
                    out.push_str(&format!("; ║  Please create vector assets in that directory.           ║\n"));
                } else {
                    out.push_str(&format!("; ║  Available vector assets ({} found):                     ║\n", available.len()));
                    for (i, name) in available.iter().enumerate() {
                        out.push_str(&format!("; ║    {}. \"{}\"{:>width$}║\n", 
                            i+1, name, "", width = 56 - name.len()));
                    }
                }
                out.push_str(&format!("; ╚════════════════════════════════════════════════════════════╝\n"));
                out.push_str("    ERROR_VECTOR_ASSET_NOT_FOUND  ; Assembly will fail here\n");
                return true;
            }
        }
    }
    
    // DRAW_VECTOR_EX: Draw vector asset with transformations (position + mirror + intensity)
    // Usage: DRAW_VECTOR_EX("player", x, y, mirror, intensity) -> draws vector at (x, y) with mirroring and custom intensity
    // mirror modes: 0 = normal (no flip), 1 = flip X-axis, 2 = flip Y-axis, 3 = flip both axes
    // intensity: 0-127 (overrides intensity in .vec file)
    if up == "DRAW_VECTOR_EX" && args.len() == 5 {
        if let Expr::StringLit(asset_name) = &args[0] {
            // Check if asset exists in opts.assets
            let asset_exists = opts.assets.iter().any(|a| {
                a.name == *asset_name && matches!(a.asset_type, crate::codegen::AssetType::Vector)
            });
            
            if asset_exists {
                // Find the asset to get path count
                let asset_info = opts.assets.iter()
                    .find(|a| a.name == *asset_name && matches!(a.asset_type, crate::codegen::AssetType::Vector))
                    .unwrap();
                
                // Load the .vec file to count paths, get width, and get center for mirror
                use crate::vecres::VecResource;
                let (path_count, asset_width, center_x) = if let Ok(resource) = VecResource::load(std::path::Path::new(&asset_info.path)) {
                    let (min_x, max_x) = resource.calculate_x_bounds();
                    let width = (max_x - min_x) as i32;
                    let (cx, _cy) = resource.calculate_center();
                    (resource.visible_paths().len(), width, cx)
                } else {
                    (1, 0, 0) // Fallback if can't load
                };
                
                let symbol = format!("_{}", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
                
                // Generate UNIQUE labels for this call (critical for multiple DRAW_VECTOR_EX calls)
                let chk_y_label = fresh_label("DSVEX_CHK_Y");
                let chk_xy_label = fresh_label("DSVEX_CHK_XY");
                let call_label = fresh_label("DSVEX_CALL");
                
                out.push_str(&format!("; DRAW_VECTOR_EX(\"{}\", x, y, mirror) - {} path(s), width={}, center_x={}\n", asset_name, path_count, asset_width, center_x));
                
                // Evaluate x position (arg 1)
                emit_expr(&args[1], out, fctx, string_map, opts);
                out.push_str("    LDA RESULT+1  ; X position (low byte)\n");
                out.push_str("    STA DRAW_VEC_X\n");
                
                // Evaluate y position (arg 2)
                emit_expr(&args[2], out, fctx, string_map, opts);
                out.push_str("    LDA RESULT+1  ; Y position (low byte)\n");
                out.push_str("    STA DRAW_VEC_Y\n");
                
                // Evaluate mirror flag (arg 3)
                emit_expr(&args[3], out, fctx, string_map, opts);
                out.push_str("    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)\n");
                
                // Decode mirror mode into separate MIRROR_X and MIRROR_Y flags
                out.push_str("    ; Decode mirror mode into separate flags:\n");
                out.push_str("    CLR MIRROR_X  ; Clear X flag\n");
                out.push_str("    CLR MIRROR_Y  ; Clear Y flag\n");
                out.push_str("    CMPB #1       ; Check if X-mirror (mode 1)\n");
                out.push_str(&format!("    BNE {}\n", chk_y_label));
                out.push_str("    LDA #1\n");
                out.push_str("    STA MIRROR_X\n");
                out.push_str(&format!("{}:\n", chk_y_label));
                out.push_str("    CMPB #2       ; Check if Y-mirror (mode 2)\n");
                out.push_str(&format!("    BNE {}\n", chk_xy_label));
                out.push_str("    LDA #1\n");
                out.push_str("    STA MIRROR_Y\n");
                out.push_str(&format!("{}:\n", chk_xy_label));
                out.push_str("    CMPB #3       ; Check if both-mirror (mode 3)\n");
                out.push_str(&format!("    BNE {}\n", call_label));
                out.push_str("    LDA #1\n");
                out.push_str("    STA MIRROR_X\n");
                out.push_str("    STA MIRROR_Y\n");
                out.push_str(&format!("{}:\n", call_label));
                
                // Evaluate and set intensity override (arg 4)
                out.push_str("    ; Set intensity override for drawing\n");
                emit_expr(&args[4], out, fctx, string_map, opts);
                out.push_str("    LDA RESULT+1  ; Intensity (0-127)\n");
                out.push_str("    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)\n");
                
                // Generate code to draw each path using unified mirrored function
                out.push_str("    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)\n");
                for path_idx in 0..path_count {
                    out.push_str(&format!("    LDX #{}_PATH{}  ; Path {}\n", symbol, path_idx, path_idx));
                    out.push_str("    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY\n");
                }
                out.push_str("    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)\n");
                
                out.push_str("    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw\n");
                out.push_str("    LDD #0\n    STD RESULT\n");
                return true;
            } else {
                // Generate helpful compile-time error with list of available assets
                let available: Vec<&str> = opts.assets.iter()
                    .filter(|a| matches!(a.asset_type, crate::codegen::AssetType::Vector))
                    .map(|a| a.name.as_str())
                    .collect();
                
                out.push_str(&format!("; ╔════════════════════════════════════════════════════════════╗\n"));
                out.push_str(&format!("; ║  ❌ COMPILATION ERROR: Vector asset not found             ║\n"));
                out.push_str(&format!("; ╠════════════════════════════════════════════════════════════╣\n"));
                out.push_str(&format!("; ║  DRAW_VECTOR_EX(\"{}\") - asset does not exist{:>width$}║\n", 
                    asset_name, "", width = 56 - asset_name.len()));
                out.push_str(&format!("; ╠════════════════════════════════════════════════════════════╣\n"));
                if available.is_empty() {
                    out.push_str(&format!("; ║  No .vec files found in assets/vectors/                   ║\n"));
                    out.push_str(&format!("; ║  Please create vector assets in that directory.           ║\n"));
                } else {
                    out.push_str(&format!("; ║  Available vector assets ({} found):                     ║\n", available.len()));
                    for (i, name) in available.iter().enumerate() {
                        out.push_str(&format!("; ║    {}. \"{}\"{:>width$}║\n", 
                            i+1, name, "", width = 56 - name.len()));
                    }
                }
                out.push_str(&format!("; ╚════════════════════════════════════════════════════════════╝\n"));
                out.push_str("    ERROR_VECTOR_ASSET_NOT_FOUND  ; Assembly will fail here\n");
                return true;
            }
        }
    }
    
    // PLAY_MUSIC: Play music asset by name
    // Usage: PLAY_MUSIC("theme") -> loads music data and starts playback
    if up == "PLAY_MUSIC" && args.len() == 1 {
        if let Expr::StringLit(asset_name) = &args[0] {
            // Check if asset exists in opts.assets
            let asset_exists = opts.assets.iter().any(|a| {
                a.name == *asset_name && matches!(a.asset_type, crate::codegen::AssetType::Music)
            });
            
            if asset_exists {
                let symbol = format!("_{}_MUSIC", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
                out.push_str(&format!("; PLAY_MUSIC(\"{}\") - play music asset\n", asset_name));
                out.push_str(&format!("    LDX #{}\n", symbol));
                out.push_str("    JSR PLAY_MUSIC_RUNTIME\n");
                out.push_str("    LDD #0\n    STD RESULT\n");
                return true;
            } else {
                out.push_str(&format!("; ERROR: Music asset '{}' not found\n", asset_name));
                return true;
            }
        }
    }
    
    if up == "AUDIO_UPDATE" && args.is_empty() {
        add_native_call_comment(out, "AUDIO_UPDATE");
        out.push_str("    JSR AUDIO_UPDATE\n");
        out.push_str("    CLRA\n    CLRB\n    STD RESULT\n");
        return true;
    }
    
    if up == "MUSIC_UPDATE" && args.is_empty() {
        add_native_call_comment(out, "UPDATE_MUSIC_PSG");
        out.push_str("    JSR UPDATE_MUSIC_PSG\n");
        out.push_str("    CLRA\n    CLRB\n    STD RESULT\n");
        return true;
    }
    
    // PLAY_SFX: Play sound effect asset by name (one-shot, non-looping)
    // Usage: PLAY_SFX("explosion") -> plays SFX once
    if up == "PLAY_SFX" && args.len() == 1 {
        if let Expr::StringLit(asset_name) = &args[0] {
            // Check if asset exists in opts.assets
            let asset_exists = opts.assets.iter().any(|a| {
                a.name == *asset_name && matches!(a.asset_type, crate::codegen::AssetType::Sfx)
            });
            
            if asset_exists {
                let symbol = format!("_{}_SFX", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
                out.push_str(&format!("; PLAY_SFX(\"{}\") - play sound effect (one-shot)\n", asset_name));
                out.push_str(&format!("    LDX #{}\n", symbol));
                out.push_str("    JSR PLAY_SFX_RUNTIME\n");
                out.push_str("    LDD #0\n    STD RESULT\n");
                return true;
            } else {
                // Generate helpful compile-time error with list of available SFX
                let available: Vec<&str> = opts.assets.iter()
                    .filter(|a| matches!(a.asset_type, crate::codegen::AssetType::Sfx))
                    .map(|a| a.name.as_str())
                    .collect();
                
                out.push_str(&format!("; ╔════════════════════════════════════════════════════════════╗\n"));
                out.push_str(&format!("; ║  ❌ COMPILATION ERROR: SFX asset not found                ║\n"));
                out.push_str(&format!("; ╠════════════════════════════════════════════════════════════╣\n"));
                out.push_str(&format!("; ║  PLAY_SFX(\"{}\") - asset does not exist{:>width$}║\n", 
                    asset_name, "", width = 64 - asset_name.len() - 29));
                out.push_str(&format!("; ╠════════════════════════════════════════════════════════════╣\n"));
                if available.is_empty() {
                    out.push_str(&format!("; ║  No .vmus files found in assets/sfx/                      ║\n"));
                    out.push_str(&format!("; ║  Please create sound effect assets in that directory.     ║\n"));
                } else {
                    out.push_str(&format!("; ║  Available SFX assets ({} found):                        ║\n", available.len()));
                    for (i, name) in available.iter().enumerate() {
                        out.push_str(&format!("; ║    {}. \"{}\"{:>width$}║\n", 
                            i+1, name, "", width = 56 - name.len()));
                    }
                }
                out.push_str(&format!("; ╚════════════════════════════════════════════════════════════╝\n"));
                out.push_str("    ERROR_SFX_ASSET_NOT_FOUND  ; Assembly will fail here\n");
                return true;
            }
        }
    }
    
    // STOP_MUSIC: Stop currently playing background music
    // Usage: STOP_MUSIC() -> stops music playback
    if up == "STOP_MUSIC" && args.is_empty() {
        add_native_call_comment(out, "STOP_MUSIC");
        out.push_str("; STOP_MUSIC() - stop background music\n");
        out.push_str("    JSR STOP_MUSIC_RUNTIME\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return true;
    }
    
    // SFX_UPDATE: Update SFX playback (call once per frame, typically at end of loop)
    // Usage: SFX_UPDATE() -> advances envelope/pitch for any playing SFX
    if up == "SFX_UPDATE" && args.is_empty() {
        add_native_call_comment(out, "SFX_UPDATE");
        out.push_str("; SFX_UPDATE() - update SFX envelope/pitch\n");
        out.push_str("    JSR SFX_UPDATE\n");
        out.push_str("    CLRA\n    CLRB\n    STD RESULT\n");
        return true;
    }
    
    // ========== JOYSTICK 1 FUNCTIONS (alg_jch0/jch1) ==========
    
    // J1_X: Default to digital (fast, suitable for 60fps)
    if up == "J1_X" && args.is_empty() {
        add_native_call_comment(out, "J1_X");
        out.push_str("    JSR J1X_BUILTIN\n");
        out.push_str("    STD RESULT\n");
        return true;
    }

    // J1_X_DIGITAL: Explicit digital version (-1/0/+1)
    if up == "J1_X_DIGITAL" && args.is_empty() {
        add_native_call_comment(out, "J1_X_DIGITAL");
        out.push_str("; J1_X_DIGITAL() - Read Joystick 1 X axis (BIOS Digital)\n");
        out.push_str("    LDA #1\n");
        out.push_str("    STA $C81F    ; Vec_Joy_Mux_1_X\n");
        out.push_str("    LDA #3\n");
        out.push_str("    STA $C820    ; Vec_Joy_Mux_1_Y\n");
        out.push_str("    LDA #$D0\n");
        out.push_str("    TFR A,DP     ; Set DP=$D0 (BIOS requirement)\n");
        out.push_str("    JSR $F1F8    ; Joy_Digital\n");
        out.push_str("    LDA #$C8\n");
        out.push_str("    TFR A,DP     ; Restore DP=$C8\n");
        out.push_str("    LDB $C81B    ; Vec_Joy_1_X (0-255, 128=center)\n");
        out.push_str("    SUBB #128    ; Center to signed range (-128 to +127)\n");
        out.push_str("    SEX          ; Sign-extend to 16-bit\n");
        out.push_str("    STD RESULT\n");
        return true;
    }

    // J1_X_ANALOG: Analog version (-127 to +127)
    if up == "J1_X_ANALOG" && args.is_empty() {
        add_native_call_comment(out, "J1_X_ANALOG");
        out.push_str("; J1_X_ANALOG() - Read Joystick 1 X axis (BIOS Analog)\n");
        out.push_str("    LDA #$80\n");
        out.push_str("    STA $C81A    ; Vec_Joy_Resltn (resolution: $80=fast)\n");
        out.push_str("    LDA #1\n");
        out.push_str("    STA $C81F    ; Vec_Joy_Mux_1_X\n");
        out.push_str("    CLR $C820    ; Vec_Joy_Mux_1_Y (disable Y for speed)\n");
        out.push_str("    LDA #$D0\n");
        out.push_str("    TFR A,DP     ; Set DP=$D0 (BIOS requirement)\n");
        out.push_str("    JSR $F1F5    ; Joy_Analog\n");
        out.push_str("    LDA #$C8\n");
        out.push_str("    TFR A,DP     ; Restore DP=$C8\n");
        out.push_str("    LDB $C81B    ; Vec_Joy_1_X (0-255, 128=center)\n");
        out.push_str("    SUBB #128    ; Center to signed range (-128 to +127)\n");
        out.push_str("    SEX          ; Sign-extend to 16-bit\n");
        out.push_str("    STD RESULT\n");
        return true;
    }

    // J1_Y: Read Joystick 1 Y axis via BIOS Joy_Digital
    // Returns signed 16-bit value: -1 (down), 0 (center), +1 (up)
    // NOTE: Joy_Digital is MUCH faster than Joy_Analog (suitable for 60fps)
    if up == "J1_Y" && args.is_empty() {
        add_native_call_comment(out, "J1_Y");
        out.push_str("    JSR J1Y_BUILTIN\n");
        out.push_str("    STD RESULT\n");
        return true;
    }

    // J1_Y_ANALOG: Analog version (-127 to +127)
    if up == "J1_Y_ANALOG" && args.is_empty() {
        add_native_call_comment(out, "J1_Y_ANALOG");
        out.push_str("; J1_Y_ANALOG() - Read Joystick 1 Y axis (BIOS Analog)\n");
        out.push_str("    LDA #$80\n");
        out.push_str("    STA $C81A    ; Vec_Joy_Resltn (resolution: $80=fast)\n");
        out.push_str("    CLR $C81F    ; Vec_Joy_Mux_1_X (disable X for speed)\n");
        out.push_str("    LDA #3\n");
        out.push_str("    STA $C820    ; Vec_Joy_Mux_1_Y\n");
        out.push_str("    LDA #$D0\n");
        out.push_str("    TFR A,DP     ; Set DP=$D0 (BIOS requirement)\n");
        out.push_str("    JSR $F1F5    ; Joy_Analog\n");
        out.push_str("    LDA #$C8\n");
        out.push_str("    TFR A,DP     ; Restore DP=$C8\n");
        out.push_str("    LDB $C81C    ; Vec_Joy_1_Y (BIOS writes ~$FE at center)\n");
        out.push_str("    SEX          ; Sign-extend to 16-bit\n");
        out.push_str("    ADDD #2      ; Calibrate center offset ($FE → $00)\n");
        out.push_str("    STD RESULT\n");
        return true;
    }

    // UPDATE_BUTTONS: Read all 4 buttons from BIOS ONCE per frame
    // Call this at the start of loop() to update button cache
    // BIOS handles debounce via transition detection
    if up == "UPDATE_BUTTONS" && args.is_empty() {
        add_native_call_comment(out, "UPDATE_BUTTONS");
        out.push_str("    JSR UPDATE_BUTTONS\n");
        return true;
    }

    // J1_BUTTON_1: Read cached button 1 state (fast, no BIOS call)
    // Returns 0 if released, 1 if pressed
    // NOTE: Call UPDATE_BUTTONS() first in your loop()
    if up == "J1_BUTTON_1" && args.is_empty() {
        add_native_call_comment(out, "J1_BUTTON_1");
        out.push_str("    JSR J1B1_BUILTIN\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // J1_BUTTON_2: Read cached button 2 state (fast, no BIOS call)
    // NOTE: Call UPDATE_BUTTONS() first in your loop()
    if up == "J1_BUTTON_2" && args.is_empty() {
        add_native_call_comment(out, "J1_BUTTON_2");
        out.push_str("    JSR J1B2_BUILTIN\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // J1_BUTTON_3: Read Joystick 1 button 3 via BIOS Read_Btns
    // NOTE: Clears Vec_Btn_State before reading to prevent stale button states on hardware
    if up == "J1_BUTTON_3" && args.is_empty() {
        add_native_call_comment(out, "J1_BUTTON_3");
        out.push_str("    JSR J1B3_BUILTIN\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // J1_BUTTON_4: Read Joystick 1 button 4 via BIOS Read_Btns
    // NOTE: Clears Vec_Btn_State before reading to prevent stale button states on hardware
    if up == "J1_BUTTON_4" && args.is_empty() {
        add_native_call_comment(out, "J1_BUTTON_4");
        out.push_str("    JSR J1B4_BUILTIN\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // ========== JOYSTICK 2 FUNCTIONS ==========
    
    // J2_X: Read Joystick 2 X axis via BIOS Joy_Digital
    // Returns signed 16-bit value: -1 (left), 0 (center), +1 (right)
    if up == "J2_X" && args.is_empty() {
        add_native_call_comment(out, "J2_X");
        out.push_str("; J2_X() - Read Joystick 2 X axis (BIOS)\n");
        out.push_str("    LDA #5\n");
        out.push_str("    STA $C821    ; Vec_Joy_Mux_2_X\n");
        out.push_str("    LDA #7\n");
        out.push_str("    STA $C822    ; Vec_Joy_Mux_2_Y\n");
        out.push_str("    JSR $F1F8    ; Joy_Digital\n");
        out.push_str("    LDB $C81D    ; Vec_Joy_2_X\n");
        out.push_str("    SEX\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // J2_Y: Read Joystick 2 Y axis via BIOS Joy_Digital
    // Returns signed 16-bit value: -1 (down), 0 (center), +1 (up)
    if up == "J2_Y" && args.is_empty() {
        add_native_call_comment(out, "J2_Y");
        out.push_str("; J2_Y() - Read Joystick 2 Y axis (BIOS)\n");
        out.push_str("    LDA #5\n");
        out.push_str("    STA $C821    ; Vec_Joy_Mux_2_X\n");
        out.push_str("    LDA #7\n");
        out.push_str("    STA $C822    ; Vec_Joy_Mux_2_Y\n");
        out.push_str("    JSR $F1F8    ; Joy_Digital\n");
        out.push_str("    LDB $C81E    ; Vec_Joy_2_Y\n");
        out.push_str("    SEX\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // J2_BUTTON_1: Read Joystick 2 button 1 via BIOS Read_Btns
    // Returns 0 if released, 1 if pressed
    if up == "J2_BUTTON_1" && args.is_empty() {
        add_native_call_comment(out, "J2_BUTTON_1");
        out.push_str("; J2_BUTTON_1() - Read Joystick 2 button 1 (BIOS)\n");
        out.push_str("    JSR $F1BA    ; Read_Btns\n");
        out.push_str("    LDA $C80F    ; Vec_Btn_State\n");
        out.push_str("    ANDA #$10    ; J2 button 1 (bit 4)\n");
        out.push_str("    BEQ .j2b1_not_pressed\n");
        out.push_str("    LDD #1\n");
        out.push_str("    BRA .j2b1_done\n");
        out.push_str(".j2b1_not_pressed:\n");
        out.push_str("    LDD #0\n");
        out.push_str(".j2b1_done:\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // J2_BUTTON_2: Read Joystick 2 button 2 via BIOS Read_Btns
    if up == "J2_BUTTON_2" && args.is_empty() {
        add_native_call_comment(out, "J2_BUTTON_2");
        out.push_str("; J2_BUTTON_2() - Read Joystick 2 button 2 (BIOS)\n");
        out.push_str("    JSR $F1BA    ; Read_Btns\n");
        out.push_str("    LDA $C80F    ; Vec_Btn_State\n");
        out.push_str("    ANDA #$20    ; J2 button 2 (bit 5)\n");
        out.push_str("    BEQ .j2b2_not_pressed\n");
        out.push_str("    LDD #1\n");
        out.push_str("    BRA .j2b2_done\n");
        out.push_str(".j2b2_not_pressed:\n");
        out.push_str("    LDD #0\n");
        out.push_str(".j2b2_done:\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // J2_BUTTON_3: Read Joystick 2 button 3 via BIOS Read_Btns
    if up == "J2_BUTTON_3" && args.is_empty() {
        add_native_call_comment(out, "J2_BUTTON_3");
        out.push_str("; J2_BUTTON_3() - Read Joystick 2 button 3 (BIOS)\n");
        out.push_str("    JSR $F1BA    ; Read_Btns\n");
        out.push_str("    LDA $C80F    ; Vec_Btn_State\n");
        out.push_str("    ANDA #$40    ; J2 button 3 (bit 6)\n");
        out.push_str("    BEQ .j2b3_not_pressed\n");
        out.push_str("    LDD #1\n");
        out.push_str("    BRA .j2b3_done\n");
        out.push_str(".j2b3_not_pressed:\n");
        out.push_str("    LDD #0\n");
        out.push_str(".j2b3_done:\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // J2_BUTTON_4: Read Joystick 2 button 4 via BIOS Read_Btns
    if up == "J2_BUTTON_4" && args.is_empty() {
        add_native_call_comment(out, "J2_BUTTON_4");
        out.push_str("; J2_BUTTON_4() - Read Joystick 2 button 4 (BIOS)\n");
        out.push_str("    JSR $F1BA    ; Read_Btns\n");
        out.push_str("    LDA $C80F    ; Vec_Btn_State\n");
        out.push_str("    ANDA #$80    ; J2 button 4 (bit 7)\n");
        out.push_str("    BEQ .j2b4_not_pressed\n");
        out.push_str("    LDD #1\n");
        out.push_str("    BRA .j2b4_done\n");
        out.push_str(".j2b4_not_pressed:\n");
        out.push_str("    LDD #0\n");
        out.push_str(".j2b4_done:\n");
        out.push_str("    STD RESULT\n");
        return true;
    }
    
    // LOAD_LEVEL: Load level data from ROM to RAM
    // Usage: LOAD_LEVEL("test_level")
    if up == "LOAD_LEVEL" && args.len() == 1 {
        if let Expr::StringLit(level_name) = &args[0] {
            // Check if level asset exists
            let level_exists = opts.assets.iter().any(|a| {
                a.name == *level_name && matches!(a.asset_type, crate::codegen::AssetType::Level)
            });
            
            if level_exists {
                let symbol = format!("_{}_LEVEL", level_name.to_uppercase().replace("-", "_").replace(" ", "_"));
                out.push_str(&format!("; LOAD_LEVEL(\"{}\") - load level data\n", level_name));
                out.push_str(&format!("    LDX #{}\n", symbol));
                out.push_str("    JSR LOAD_LEVEL_RUNTIME\n");
                out.push_str("    LDD RESULT  ; Returns level pointer\n");
                return true;
            } else {
                out.push_str(&format!("; ERROR: Level asset '{}' not found\n", level_name));
                out.push_str("    LDD #0\n    STD RESULT\n");
                return true;
            }
        }
    }
    
    // SHOW_LEVEL: Draw all level objects
    // Usage: SHOW_LEVEL()
    if up == "SHOW_LEVEL" && args.len() == 0 {
        out.push_str("; SHOW_LEVEL() - draw all level objects\n");
        out.push_str("    JSR SHOW_LEVEL_RUNTIME\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return true;
    }
    
    // UPDATE_LEVEL: Update level state (physics, animations, spawn delays)
    // Usage: UPDATE_LEVEL()
    if up == "UPDATE_LEVEL" && args.len() == 0 {
        add_native_call_comment(out, "UPDATE_LEVEL");
        out.push_str("    JSR UPDATE_LEVEL_RUNTIME\n");
        out.push_str("    CLRA\n    CLRB\n    STD RESULT\n");
        return true;
    }
    
    if up == "VECTREX_DRAW_VECTORLIST" { // alias to compact list runtime
        if args.len()==1 {
            if let Expr::StringLit(s) = &args[0] {
                out.push_str(&format!("    LDX #VL_{}\n    JSR Run_VectorList\n", s.to_ascii_uppercase()));
                return true;
            } else if let Expr::Ident(id) = &args[0] {
                out.push_str(&format!("    LDX #VL_{}\n    JSR Run_VectorList\n", id.name.to_ascii_uppercase()));
                return true;
            }
        }
    }
    if up == "DRAW_VECTORLIST" {
        if args.is_empty() { return true; }
        if let Expr::Ident(v) = &args[0] {
            out.push_str(&format!("    JSR VL_{}\n", v.name.to_ascii_uppercase()));
            return true;
        } else if let Expr::StringLit(s) = &args[0] {
            out.push_str(&format!("    JSR VL_{}\n", s.to_ascii_uppercase()));
            return true;
        }
    }
    
    // ASM: Inline assembly - emit raw string directly
    if up == "ASM" && args.len() == 1 {
        if let Expr::StringLit(asm_code) = &args[0] {
            out.push_str(&format!("    {}\n", asm_code));
            return true;
        }
    }
    
    // DRAW_VECTOR_LIST: Malban's complete algorithm for processing vector lists
    // Usage: DRAW_VECTOR_LIST(list_label, y, x, scale)
    // Generates the full frame init + vector list iteration code from VIDE
    if up == "DRAW_VECTOR_LIST" && args.len() == 4 {
        // Extract list label (string or ident)
        let list_label = match &args[0] {
            Expr::StringLit(s) => s.clone(),
            Expr::Ident(id) => id.name.clone(),
            _ => {
                out.push_str("; ERROR: DRAW_VECTOR_LIST requires label as first arg\n");
                return true;
            }
        };
        
        // Evaluate other arguments to RESULT/vars (single bytes)
        // y position
        emit_expr(&args[1], out, fctx, string_map, opts);
        out.push_str("    LDA RESULT+1\n    STA VL_Y\n");
        
        // x position  
        emit_expr(&args[2], out, fctx, string_map, opts);
        out.push_str("    LDA RESULT+1\n    STA VL_X\n");
        
        // scale
        emit_expr(&args[3], out, fctx, string_map, opts);
        out.push_str("    LDA RESULT+1\n    STA VL_SCALE\n");
        
        // Generate Malban algorithm inline (replicate VIDE output)
        let list_sym = format!("_{}", list_label.to_uppercase());
        out.push_str(&format!("; DRAW_VECTOR_LIST({}, y, x, scale) - Malban algorithm\n", list_label));
        out.push_str(&format!("    LDX #{}\n", list_sym));
        out.push_str("    STX VL_PTR\n");
        
        // DO-WHILE loop label
        out.push_str("VL_LOOP_START:\n");
        
        // Frame initialization sequence (Malban lines 13-43 from VIDE ASM)
        out.push_str("    CLR $D05A           ; VIA_shift_reg = 0 (blank beam)\n");
        out.push_str("    LDA #$CC\n");
        out.push_str("    STA $D00B           ; VIA_cntl = 0xCC (zero integrators)\n");
        out.push_str("    CLR $D000           ; VIA_port_a = 0 (reset offset)\n");
        out.push_str("    LDA #$82\n");
        out.push_str("    STA $D002           ; VIA_port_b = 0x82\n");
        out.push_str("    LDA VL_SCALE\n");
        out.push_str("    STA $D004           ; VIA_t1_cnt_lo = scale\n");
        
        // Delay loop (5 iterations for beam settling)
        out.push_str("    LDB #5              ; ZERO_DELAY\n");
        out.push_str("VL_DELAY:\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE VL_DELAY\n");
        
        out.push_str("    LDA #$83\n");
        out.push_str("    STA $D002           ; VIA_port_b = 0x83\n");
        
        // Move to initial position (y, x)
        out.push_str("    LDA VL_Y\n");
        out.push_str("    STA $D000           ; VIA_port_a = y\n");
        out.push_str("    LDA #$CE\n");
        out.push_str("    STA $D00B           ; VIA_cntl = 0xCE (integrator mode)\n");
        out.push_str("    CLR $D002           ; VIA_port_b = 0 (mux enable)\n");
        out.push_str("    LDA #1\n");
        out.push_str("    STA $D002           ; VIA_port_b = 1 (mux disable)\n");
        out.push_str("    LDA VL_X\n");
        out.push_str("    STA $D000           ; VIA_port_a = x\n");
        out.push_str("    CLR $D005           ; VIA_t1_cnt_hi = 0 (start timer)\n");
        
        // Set scale for vector drawing
        out.push_str("    LDA VL_SCALE\n");
        out.push_str("    STA $D004           ; VIA_t1_cnt_lo = scale\n");
        
        // Advance pointer past header (u += 3)
        out.push_str("    LDX VL_PTR\n");
        out.push_str("    LEAX 3,X\n");
        out.push_str("    STX VL_PTR\n");
        
        // Wait for move to complete
        out.push_str("VL_WAIT_MOVE:\n");
        out.push_str("    LDA $D00D           ; VIA_int_flags\n");
        out.push_str("    ANDA #$40\n");
        out.push_str("    BEQ VL_WAIT_MOVE\n");
        
        // Vector list processing loop (WHILE(1))
        out.push_str("VL_PROCESS_LOOP:\n");
        out.push_str("    LDX VL_PTR\n");
        out.push_str("    LDA ,X              ; Load flag byte (*u)\n");
        out.push_str("    TSTA\n");
        out.push_str("    BPL VL_CHECK_MOVE   ; If >= 0, not a draw\n");
        
        // DRAW LINE (*u < 0)
        out.push_str("VL_DRAW:\n");
        out.push_str("    LDA 1,X             ; dy\n");
        out.push_str("    STA $D000           ; VIA_port_a = dy\n");
        out.push_str("    CLR $D002           ; VIA_port_b = 0\n");
        out.push_str("    LDA #1\n");
        out.push_str("    STA $D002           ; VIA_port_b = 1\n");
        out.push_str("    LDA 2,X             ; dx\n");
        out.push_str("    STA $D000           ; VIA_port_a = dx\n");
        out.push_str("    CLR $D005           ; VIA_t1_cnt_hi = 0\n");
        out.push_str("    LDA #$FF\n");
        out.push_str("    STA $D05A           ; VIA_shift_reg = 0xFF (beam ON)\n");
        out.push_str("VL_WAIT_DRAW:\n");
        out.push_str("    LDA $D00D\n");
        out.push_str("    ANDA #$40\n");
        out.push_str("    BEQ VL_WAIT_DRAW\n");
        out.push_str("    CLR $D05A           ; VIA_shift_reg = 0 (beam OFF)\n");
        out.push_str("    BRA VL_CONTINUE\n");
        
        // MOVE TO (*u == 0)
        out.push_str("VL_CHECK_MOVE:\n");
        out.push_str("    TSTA\n");
        out.push_str("    BNE VL_CHECK_END    ; If != 0, check for end\n");
        out.push_str("    ; MoveTo logic (similar to draw but no beam)\n");
        out.push_str("    LDA 1,X             ; dy\n");
        out.push_str("    BEQ VL_CHECK_DX\n");
        out.push_str("VL_DO_MOVE:\n");
        out.push_str("    STA $D000           ; VIA_port_a = dy\n");
        out.push_str("    LDA #$CE\n");
        out.push_str("    STA $D00B           ; VIA_cntl = 0xCE\n");
        out.push_str("    CLR $D002\n");
        out.push_str("    LDA #1\n");
        out.push_str("    STA $D002\n");
        out.push_str("    LDA 2,X             ; dx\n");
        out.push_str("    STA $D000\n");
        out.push_str("    CLR $D005\n");
        out.push_str("VL_WAIT_MOVE2:\n");
        out.push_str("    LDA $D00D\n");
        out.push_str("    ANDA #$40\n");
        out.push_str("    BEQ VL_WAIT_MOVE2\n");
        out.push_str("    BRA VL_CONTINUE\n");
        out.push_str("VL_CHECK_DX:\n");
        out.push_str("    LDA 2,X\n");
        out.push_str("    BNE VL_DO_MOVE\n");
        out.push_str("    BRA VL_CONTINUE\n");
        
        // Check for end marker (2)
        out.push_str("VL_CHECK_END:\n");
        out.push_str("    CMPA #2\n");
        out.push_str("    BEQ VL_DONE         ; Exit if *u == 2\n");
        
        // Continue to next entry (u += 3)
        out.push_str("VL_CONTINUE:\n");
        out.push_str("    LDX VL_PTR\n");
        out.push_str("    LEAX 3,X\n");
        out.push_str("    STX VL_PTR\n");
        out.push_str("    BRA VL_PROCESS_LOOP\n");
        
        out.push_str("VL_DONE:\n");
        out.push_str("    ; DO-WHILE check: if more lists, loop to VL_LOOP_START\n");
        out.push_str("    ; For single list, we're done\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        
        return true;
    }
    
    // DRAW_LINE optimization: when all args are numeric constants, generate inline BIOS calls
    // Reset beam to center, move to (x0,y0), draw delta to (x1,y1)
    if up == "DRAW_LINE" && args.len() == 5 && args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(x0), Expr::Number(y0), Expr::Number(x1), Expr::Number(y1), Expr::Number(intensity))
            = (&args[0], &args[1], &args[2], &args[3], &args[4]) {
            // Calculate deltas from absolute coordinates
            let dx = (*x1 - *x0) as i32;
            let dy = (*y1 - *y0) as i32;

            // If deltas require segmentation (> ±127), use DRAW_LINE_WRAPPER instead
            if dy > 127 || dy < -128 || dx > 127 || dx < -128 {
                // Fall through to wrapper version
            } else {
                // Deltas fit in 8-bit, use inline BIOS call
                let dx8 = dx as i8;
                let dy8 = dy as i8;

                // Set DP=$D0 for BIOS calls, reset beam to center
                out.push_str("    LDA #$D0\n    TFR A,DP\n");
                out.push_str("    JSR Reset0Ref\n");
                out.push_str("    LDA #$80\n    STA <$04\n"); // VIA_t1_cnt_lo = $80
                // Set intensity
                if *intensity == 0x5F {
                    out.push_str("    JSR Intensity_5F\n");
                } else {
                    out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", *intensity as u8));
                }
                // Move to start position (x0, y0)
                out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n",
                    (*y0 as i8) as u8, (*x0 as i8) as u8));
                // Clear Vec_Misc_Count for proper timing
                out.push_str("    CLR Vec_Misc_Count\n");
                // Draw line using RELATIVE deltas (A=dy, B=dx)
                out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n",
                    dy8 as u8, dx8 as u8));
                // Restore DP after BIOS call
                out.push_str("    LDA #$C8\n    TFR A,DP\n");
                out.push_str("    LDD #0\n    STD RESULT\n");
                return true;
            }
        }
    }
    
    // DRAW_LINE fallback: if not all constants, use wrapper
    if up == "DRAW_LINE" && args.len() == 5 {
        // For arguments with variables/expressions, use wrapper
        // CRITICAL: Store arguments in TMPPTR area (not RESULT) to prevent
        // emit_expr from overwriting values during complex expression evaluation
        // 
        // Argument layout in TMPPTR:
        // TMPPTR+0 = x0, TMPPTR+2 = y0, TMPPTR+4 = x1, TMPPTR+6 = y1, TMPPTR+8 = intensity
        for (i, arg) in args.iter().enumerate() {
            let offset = i * 2;
            match arg {
                Expr::Number(n) => {
                    // Direct constant - load and store to TMPPTR area
                    out.push_str(&format!("    LDD #{}\n", *n & 0xFFFF));
                    out.push_str(&format!("    STD TMPPTR+{}\n", offset));
                }
                _ => {
                    // Complex expression: evaluate to RESULT, then copy to TMPPTR
                    // This prevents RESULT from being overwritten during next emit_expr
                    emit_expr(arg, out, fctx, string_map, opts);
                    // Value is in D, store to TMPPTR area
                    out.push_str(&format!("    STD TMPPTR+{}\n", offset));
                }
            }
        }
        // Copy from TMPPTR to RESULT for DRAW_LINE_WRAPPER
        // DRAW_LINE_WRAPPER expects arguments at RESULT+0-8
        out.push_str("    LDD TMPPTR+0\n    STD RESULT+0\n");
        out.push_str("    LDD TMPPTR+2\n    STD RESULT+2\n");
        out.push_str("    LDD TMPPTR+4\n    STD RESULT+4\n");
        out.push_str("    LDD TMPPTR+6\n    STD RESULT+6\n");
        out.push_str("    LDD TMPPTR+8\n    STD RESULT+8\n");
        out.push_str("    JSR DRAW_LINE_WRAPPER\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return true;
    }
    
    // Custom macro: DRAW_POLYGON(N, x0,y0,x1,y1,...,x_{N-1},y_{N-1}) all numeric constants -> inline lines with origin resets
    if up == "DRAW_POLYGON" && !args.is_empty() {
        if let Expr::Number(nv) = &args[0] {
                let n = *nv as usize;
                // Two accepted forms:
                //  Form A: DRAW_POLYGON(N, x0,y0, x1,y1, ..., xN-1,yN-1)
                //  Form B: DRAW_POLYGON(N, INTENS, x0,y0, ...)
                // All numeric constants. Optimized (single Reset0Ref + intensity) to reduce flicker.
                let form_a_len = 1 + 2*n;
                let form_b_len = 2 + 2*n;
                let mut intensity: i32 = 0x5F; // default
                let (start_index, total_len_ok) = if args.len() == form_a_len { (1usize, true) } else if args.len() == form_b_len { (2usize, true) } else { (0,false) };
                if total_len_ok {
                    if start_index == 2 { // intensity provided
                        if let Expr::Number(iv) = &args[1] { intensity = *iv; }
                    }
                    if args[start_index..].iter().all(|a| matches!(a, Expr::Number(_))) {
                        let mut verts: Vec<(i32,i32)> = Vec::new();
                        for i in 0..n { if let (Expr::Number(xv), Expr::Number(yv)) = (&args[start_index+2*i], &args[start_index+2*i+1]) { verts.push((*xv, *yv)); } }
                        if verts.len()==n {
                            // OPTIMIZED MODE: Set intensity and DP once, then draw all edges efficiently
                            // Set intensity once for all edges
                            if intensity == 0x5F { out.push_str("    JSR Intensity_5F\n"); } else { out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF)); }
                            // Set DP once for all VIA operations (inline for now)
                            out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
                            
                            for i in 0..n {
                                let (x0,y0)=verts[i];
                                let (x1,y1)=verts[(i+1)%n];
                                let dx_total = x1 - x0;
                                let dy_total = y1 - y0;
                                // Split only once if out of range (>127) into two halves.
                                let need_split = dx_total.abs().max(dy_total.abs()) > 127;
                                let (first_dx, first_dy, second_dx, second_dy, second) = if need_split {
                                    (dx_total/2, dy_total/2, dx_total - dx_total/2, dy_total - dy_total/2, true)
                                } else { (dx_total, dy_total, 0, 0, false) };
                                
                                // Only reset origin for first edge, others are connected
                                if i == 0 {
                                    out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", (y0 & 0xFF), (x0 & 0xFF)));
                                }
                                out.push_str("    CLR Vec_Misc_Count\n");
                                out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", (first_dy & 0xFF), (first_dx & 0xFF)));
                                if second {
                                    out.push_str("    CLR Vec_Misc_Count\n");
                                    out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", (second_dy & 0xFF), (second_dx & 0xFF)));
                                }
                            }
                            out.push_str("    LDD #0\n    STD RESULT\n");
                            return true;
                        }
                    }
                }
            }
        }
    // DRAW_CIRCLE(xc,yc,diam) or DRAW_CIRCLE(xc,yc,diam,intensity) all numeric constants -> approximate with 16-gon
    if up == "DRAW_CIRCLE" && (args.len()==3 || args.len()==4) && args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(xc),Expr::Number(yc),Expr::Number(diam)) = (&args[0],&args[1],&args[2]) {
                    let mut intensity: i32 = 0x5F;
                    if args.len()==4 { if let Expr::Number(i) = &args[3] { intensity = *i; } }
                    let segs = 16; // fixed approximation (use DRAW_CIRCLE_SEG for more)
                    let r = (*diam as f64)/2.0;
                    use std::f64::consts::PI;
                    let mut verts: Vec<(i32,i32)> = Vec::new();
                    for k in 0..segs {
                        let ang = 2.0*PI*(k as f64)/(segs as f64);
                        let x = (*xc as f64) + r*ang.cos();
                        let y = (*yc as f64) + r*ang.sin();
                        verts.push((x.round() as i32, y.round() as i32));
                    }
                    // Emit optimized similar to polygon - intensity FIRST, then Reset0Ref
                    if intensity == 0x5F { out.push_str("    JSR Intensity_5F\n"); } else { out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF)); }
                    out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
                    let (sx,sy)=verts[0];
                    out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", (sy & 0xFF), (sx & 0xFF)));
                    for i in 0..segs {
                        let (x0,y0)=verts[i];
                        let (x1,y1)=verts[(i+1)%segs];
                        let dx = (x1 - x0) & 0xFF;
                        let dy = (y1 - y0) & 0xFF;
                        out.push_str("    CLR Vec_Misc_Count\n");
                        out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", dy, dx));
                    }
                    out.push_str("    LDD #0\n    STD RESULT\n");
                    return true;
        }
    }
    
    // DRAW_CIRCLE with variables - runtime version (follows DRAW_VECTOR pattern)
    // DRAW_CIRCLE(xc, yc, diam) or DRAW_CIRCLE(xc, yc, diam, intensity)
    if up == "DRAW_CIRCLE" && (args.len() == 3 || args.len() == 4) {
        // Store all parameters BEFORE calling runtime (like DRAW_VECTOR does)
        
        // Evaluate xc and store low byte
        emit_expr(&args[0], out, fctx, string_map, opts);
        out.push_str("    LDB RESULT+1  ; xc (low byte, signed -128..127)\n");
        out.push_str("    STB DRAW_CIRCLE_XC\n");
        
        // Evaluate yc and store low byte
        emit_expr(&args[1], out, fctx, string_map, opts);
        out.push_str("    LDB RESULT+1  ; yc (low byte, signed -128..127)\n");
        out.push_str("    STB DRAW_CIRCLE_YC\n");
        
        // Evaluate diameter and store low byte
        emit_expr(&args[2], out, fctx, string_map, opts);
        out.push_str("    LDB RESULT+1  ; diameter (low byte, 0..255)\n");
        out.push_str("    STB DRAW_CIRCLE_DIAM\n");
        
        // Evaluate intensity
        if args.len() == 4 {
            emit_expr(&args[3], out, fctx, string_map, opts);
            out.push_str("    LDB RESULT+1  ; intensity (low byte, 0..127)\n");
            out.push_str("    STB DRAW_CIRCLE_INTENSITY\n");
        } else {
            out.push_str("    LDB #$5F\n");
            out.push_str("    STB DRAW_CIRCLE_INTENSITY\n");
        }
        
        // Call runtime helper (reads params from simple byte vars)
        out.push_str("    JSR DRAW_CIRCLE_RUNTIME\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return true;
    }
    
    // DRAW_CIRCLE_SEG(nseg, xc,yc,diam[,intensity]) variable segments
    if up == "DRAW_CIRCLE_SEG" && (args.len()==4 || args.len()==5) && args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(nseg),Expr::Number(xc),Expr::Number(yc),Expr::Number(diam)) = (&args[0],&args[1],&args[2],&args[3]) {
                    let mut intensity: i32 = 0x5F; if args.len()==5 { if let Expr::Number(i)=&args[4] { intensity = *i; }}
                    let segs = (*nseg).clamp(3, 64);
                    let r = (*diam as f64)/2.0;
                    use std::f64::consts::PI;
                    let mut verts: Vec<(i32,i32)> = Vec::new();
                    for k in 0..segs { let ang = 2.0*PI*(k as f64)/(segs as f64); let x = (*xc as f64)+r*ang.cos(); let y= (*yc as f64)+r*ang.sin(); verts.push((x.round() as i32,y.round() as i32)); }
                    out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
                    if intensity == 0x5F { out.push_str("    JSR Intensity_5F\n"); } else { out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF)); }
                    let (sx,sy)=verts[0]; out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", (sy & 0xFF),(sx & 0xFF)));
                    for i in 0..segs { let (x0,y0)=verts[i as usize]; let (x1,y1)=verts[((i+1)%segs) as usize]; let dx=(x1-x0)&0xFF; let dy=(y1-y0)&0xFF; out.push_str("    CLR Vec_Misc_Count\n"); out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", dy, dx)); }
                    out.push_str("    CLRA\n    CLRB\n    STD RESULT\n"); return true;
        }
    }
    // DRAW_ARC(nseg, xc,yc,radius,start_deg,sweep_deg[,intensity]) open arc
    if up == "DRAW_ARC" && (6..=7).contains(&args.len()) && args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(nseg),Expr::Number(xc),Expr::Number(yc),Expr::Number(rad),Expr::Number(startd),Expr::Number(sweepd)) = (&args[0],&args[1],&args[2],&args[3],&args[4],&args[5]) {
                let mut intensity: i32 = 0x5F; if args.len()==7 { if let Expr::Number(i)=&args[6] { intensity = *i; }}
                let segs = (*nseg).clamp(1, 96);
                let start = *startd as f64 * std::f64::consts::PI / 180.0; let sweep = *sweepd as f64 * std::f64::consts::PI / 180.0;
                // Clamp radius to keep inside safe display range (~ +-120)
                let r = (*rad as f64).clamp(4.0, 110.0);
                let steps = segs;
                let mut verts: Vec<(i32,i32)> = Vec::new();
                for k in 0..=steps { let t = k as f64 / steps as f64; let ang = start + sweep * t; let mut x= (*xc as f64)+ r*ang.cos(); let mut y= (*yc as f64)+ r*ang.sin(); x = x.clamp(-120.0,120.0); y = y.clamp(-120.0,120.0); verts.push((x.round() as i32,y.round() as i32)); }
                out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
                if intensity == 0x5F { out.push_str("    JSR Intensity_5F\n"); } else { out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF)); }
                let (sx,sy)=verts[0]; out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", (sy & 0xFF),(sx & 0xFF)));
                for i in 0..steps { let (x0,y0)=verts[i as usize]; let (x1,y1)=verts[(i+1) as usize]; let dx=(x1-x0)&0xFF; let dy=(y1-y0)&0xFF; out.push_str("    CLR Vec_Misc_Count\n"); out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", dy, dx)); }
                out.push_str("    CLRA\n    CLRB\n    STD RESULT\n"); return true;
        }
    }
    // DRAW_SPIRAL(nseg, xc,yc,r_start,r_end,turns[,intensity]) open spiral
    if up == "DRAW_SPIRAL" && (6..=8).contains(&args.len()) && args.iter().all(|a| matches!(a, Expr::Number(_))) {
            // Accept forms with optional explicit intensity; if more than 6 args, last is intensity.
            let last_idx = args.len()-1;
            let (has_intensity, inten_expr_idx) = if args.len() > 6 { (true, last_idx) } else { (false, 0) };
            if let (Expr::Number(nseg),Expr::Number(xc),Expr::Number(yc),Expr::Number(r0),Expr::Number(r1),Expr::Number(turns)) = (&args[0],&args[1],&args[2],&args[3],&args[4],&args[5]) {
                let mut intensity: i32 = 0x5F; if has_intensity { if let Expr::Number(iv)=&args[inten_expr_idx] { intensity = *iv; } }
                let segs = (*nseg).clamp(4, 120);
                // Clamp turns to avoid huge angle wrap distortions
                let turns_f = (*turns as f64).clamp(0.1, 4.0);
                let total_ang = turns_f * 2.0 * std::f64::consts::PI;
                let start_r = (*r0 as f64).clamp(1.0, 110.0); let end_r = (*r1 as f64).clamp(1.0, 110.0);
                let steps = segs;
                let mut verts: Vec<(i32,i32)> = Vec::new();
                for k in 0..=steps { let t = k as f64 / steps as f64; let ang = total_ang * t; let r = start_r + (end_r - start_r)*t; let mut x= (*xc as f64)+ r*ang.cos(); let mut y= (*yc as f64)+ r*ang.sin(); x = x.clamp(-120.0,120.0); y = y.clamp(-120.0,120.0); verts.push((x.round() as i32,y.round() as i32)); }
                out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
                if intensity == 0x5F { out.push_str("    JSR Intensity_5F\n"); } else { out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF)); }
                let (sx,sy)=verts[0]; out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", (sy & 0xFF),(sx & 0xFF)));
                for i in 0..steps { let (x0,y0)=verts[i as usize]; let (x1,y1)=verts[(i+1) as usize]; let dx=(x1-x0)&0xFF; let dy=(y1-y0)&0xFF; out.push_str("    CLR Vec_Misc_Count\n"); out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Draw_Line_d\n", dy, dx)); }
                out.push_str("    CLRA\n    CLRB\n    STD RESULT\n"); return true;
        }
    }

    // DRAW_RECT(x, y, width, height[, intensity]) - outlined rectangle (4 sides)
    if up == "DRAW_RECT" && (args.len() == 4 || args.len() == 5) && args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(x), Expr::Number(y), Expr::Number(w), Expr::Number(h)) = (&args[0], &args[1], &args[2], &args[3]) {
            let mut intensity: i32 = 0x5F;
            if args.len() == 5 { if let Expr::Number(i) = &args[4] { intensity = *i; } }
            let (x0, y0, w0, h0) = (*x, *y, *w, *h);
            if intensity == 0x5F { out.push_str("    JSR Intensity_5F\n"); } else { out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF)); }
            out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
            out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", (y0 & 0xFF), (x0 & 0xFF)));
            out.push_str("    CLR Vec_Misc_Count\n");
            out.push_str(&format!("    LDA #$00\n    LDB #${:02X}\n    JSR Draw_Line_d\n", (w0 & 0xFF)));   // right
            out.push_str("    CLR Vec_Misc_Count\n");
            out.push_str(&format!("    LDA #${:02X}\n    LDB #$00\n    JSR Draw_Line_d\n", (h0 & 0xFF)));   // up
            out.push_str("    CLR Vec_Misc_Count\n");
            let neg_w = (-(w0 as i32)) & 0xFF;
            out.push_str(&format!("    LDA #$00\n    LDB #${:02X}\n    JSR Draw_Line_d\n", neg_w));          // left
            out.push_str("    CLR Vec_Misc_Count\n");
            let neg_h = (-(h0 as i32)) & 0xFF;
            out.push_str(&format!("    LDA #${:02X}\n    LDB #$00\n    JSR Draw_Line_d\n", neg_h));          // down
            out.push_str("    LDA #$C8\n    TFR A,DP\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
            return true;
        }
    }
    if up == "DRAW_RECT" && (args.len() == 4 || args.len() == 5) {
        out.push_str("    ; DRAW_RECT with variables not yet implemented in core\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return true;
    }

    // DRAW_FILLED_RECT(x, y, width, height[, intensity]) - filled with horizontal scanlines
    // Uses relative Moveto_d between scanlines to avoid accumulation error
    if up == "DRAW_FILLED_RECT" && (args.len() == 4 || args.len() == 5) && args.iter().all(|a| matches!(a, Expr::Number(_))) {
        if let (Expr::Number(x), Expr::Number(y), Expr::Number(w), Expr::Number(h)) = (&args[0], &args[1], &args[2], &args[3]) {
            let mut intensity: i32 = 0x5F;
            if args.len() == 5 { if let Expr::Number(i) = &args[4] { intensity = *i; } }
            let (x0, y0, w0, h0) = (*x, *y, *w, *h);
            if intensity == 0x5F { out.push_str("    JSR Intensity_5F\n"); } else { out.push_str(&format!("    LDA #${:02X}\n    JSR Intensity_a\n", intensity & 0xFF)); }
            out.push_str("    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    LDA #$80\n    STA <$04\n");
            // First scanline: absolute position from (0,0)
            out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", (y0 & 0xFF), (x0 & 0xFF)));
            out.push_str("    CLR Vec_Misc_Count\n");
            out.push_str(&format!("    LDA #$00\n    LDB #${:02X}\n    JSR Draw_Line_d\n", (w0 & 0xFF)));
            // Subsequent scanlines: relative move from end-of-previous-line (dy=+1/-1, dx=-w)
            let num_lines = h0.abs().min(64);
            let dy_step: i32 = if h0 >= 0 { 1 } else { -1 };
            let neg_w = (-(w0 as i32)) & 0xFF;
            let dy_byte = (dy_step & 0xFF) as u8;
            for _ in 1..num_lines {
                out.push_str("    CLR Vec_Misc_Count\n");
                out.push_str(&format!("    LDA #${:02X}\n    LDB #${:02X}\n    JSR Moveto_d\n", dy_byte, neg_w as u8));
                out.push_str("    CLR Vec_Misc_Count\n");
                out.push_str(&format!("    LDA #$00\n    LDB #${:02X}\n    JSR Draw_Line_d\n", (w0 & 0xFF)));
            }
            out.push_str("    LDA #$C8\n    TFR A,DP\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
            return true;
        }
    }
    if up == "DRAW_FILLED_RECT" && (args.len() == 4 || args.len() == 5) {
        out.push_str("    ; DRAW_FILLED_RECT with variables not yet implemented in core\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return true;
    }

    // Check if it's a struct instantiation BEFORE checking builtins
    // Structs are detected by checking if name exists in struct registry
    if let Some(layout) = opts.structs.get(name) {
        out.push_str(&format!("; Struct instantiation: {} (size {} bytes)\n", name, layout.total_size));
        
        // Allocate space on stack for the struct
        let stack_size = layout.total_size;
        out.push_str(&format!("    LEAS -{},S  ; Allocate {} bytes for struct\n", stack_size, stack_size));
        
        // Initialize all fields to 0
        out.push_str("    LDD #0\n");
        for i in (0..stack_size).step_by(2) {
            out.push_str(&format!("    STD {},S  ; Zero field at offset {}\n", i, i));
        }
        
        // Check if struct has a constructor
        let constructor_name = format!("{}_INIT", up);
        // We can't easily check if constructor exists at this point,
        // but we can conditionally call it if args are provided
        if !args.is_empty() {
            out.push_str(&format!("; Call constructor with {} args\n", args.len()));
            
            // ARG0 = pointer to struct (address on stack)
            out.push_str("    LEAX 0,S  ; Get struct address\n");
            out.push_str("    STX VAR_ARG0  ; Pass as self\n");
            
            // Evaluate and pass constructor arguments (ARG1, ARG2, etc.)
            for (i, arg) in args.iter().enumerate() {
                if i >= 4 { break; } // Max 4 constructor args (ARG1-ARG4)
                emit_expr(arg, out, fctx, string_map, opts);
                out.push_str("    LDD RESULT\n");
                out.push_str(&format!("    STD VAR_ARG{}\n", i + 1));
            }
            
            // Call constructor
            if opts.force_extended_jsr {
                out.push_str(&format!("    JSR >{}\n", constructor_name));
            } else {
                out.push_str(&format!("    JSR {}\n", constructor_name));
            }
        }
        
        // Store stack pointer (struct address) in RESULT
        out.push_str("    LEAX 0,S\n");
        out.push_str("    TFR X,D\n");
        out.push_str("    STD RESULT  ; Return struct pointer\n");
        
        return true;
    }
    
    if !is {
        // Backward compatibility: map legacy short names to vectrex-prefixed versions
        let translated = resolve_function_name(&up);
        if let Some(new_up) = translated {
            // Re-dispatch using new name recursively (avoid infinite loop by guarding is set)
            return emit_builtin_call(&new_up, args, out, fctx, string_map, opts, line_info);
        }
        return false;
    }
    // ABS
    if matches!(up.as_str(), "ABS"|"MATH_ABS") {
    if let Some(arg) = args.first() { emit_expr(arg, out, fctx, string_map, opts); } else { out.push_str("    LDD #0\n    STD RESULT\n"); return true; }
        let done = fresh_label("ABS_DONE");
        out.push_str(&format!("    LDD RESULT\n    TSTA\n    BPL {}\n    COMA\n    COMB\n    ADDD #1\n{}: STD RESULT\n", done, done));
        return true;
    }
    
    // MUL_A(a, b): Multiply a * b (8-bit result)
    // Usage: result = MUL_A(x, y)
    if up == "MUL_A" {
        if args.len() >= 2 {
            // First arg
            emit_expr(&args[0], out, fctx, string_map, opts);
            out.push_str("    LDA RESULT+1\n");  // A = first arg (low byte)
            // Second arg
            emit_expr(&args[1], out, fctx, string_map, opts);
            out.push_str("    LDB RESULT+1\n");  // B = second arg (low byte)
            // MUL: A * B -> D (8x8 -> 16)
            out.push_str("    MUL\n");
            out.push_str("    STD RESULT\n");    // Store 16-bit result
        } else {
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
        return true;
    }
    
    // DIV_A(a, b): Divide a / b (integer division)
    // Usage: result = DIV_A(x, y)
    if up == "DIV_A" {
        if args.len() >= 2 {
            // First arg
            emit_expr(&args[0], out, fctx, string_map, opts);
            out.push_str("    LDD RESULT\n");   // D = dividend
            // Second arg
            emit_expr(&args[1], out, fctx, string_map, opts);
            out.push_str("    LDX RESULT\n");   // X = divisor (use as 16-bit)
            // DIV: D / X -> X (quotient), D (remainder)
            out.push_str("    IDIV\n");
            out.push_str("    TFR X,D\n");      // D = quotient
            out.push_str("    STD RESULT\n");
        } else {
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
        return true;
    }
    
    // MOD_A(a, b): Modulo a % b (remainder from division)
    // Usage: result = MOD_A(x, y)
    if up == "MOD_A" {
        if args.len() >= 2 {
            // First arg
            emit_expr(&args[0], out, fctx, string_map, opts);
            out.push_str("    LDD RESULT\n");   // D = dividend
            // Second arg
            emit_expr(&args[1], out, fctx, string_map, opts);
            out.push_str("    LDX RESULT\n");   // X = divisor
            // DIV: D / X -> X (quotient), D (remainder)
            out.push_str("    IDIV\n");
            // D already contains remainder, just store it
            out.push_str("    STD RESULT\n");
        } else {
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
        return true;
    }
    
    // len(array): Get array length
    // Array format: first word is size, followed by elements
    if up == "LEN" {
        if let Some(arg) = args.first() {
            emit_expr(arg, out, fctx, string_map, opts);
            // RESULT now contains pointer to array
            // Load first word (size) into RESULT
            out.push_str("    LDX RESULT\n");    // X = pointer to array
            out.push_str("    LDD 0,X\n");       // D = array[0] = size
            out.push_str("    STD RESULT\n");    // Store size in RESULT
        } else {
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
        return true;
    }
    
    // DEBUG_PRINT(value): Write to debug RAM area for IDE debug panel
    // Protocol: C000=value(low byte), C001=marker(0x42 simple / 0xFE labeled), C002-C003=label_ptr
    // Uses unmapped gap area (C000-C7FF) to avoid consuming user RAM
    if matches!(up.as_str(), "DEBUG_PRINT"|"VECTREX_DEBUG_PRINT") {
        if let Some(arg) = args.first() {
            // Check if argument is a variable (Ident) to generate labeled output
            let var_name = if let Expr::Ident(id) = arg {
                Some(id.name.clone())
            } else {
                None
            };
            
            emit_expr(arg, out, fctx, string_map, opts);
            
            if let Some(name) = var_name {
                // Labeled debug output (show variable name)
                add_native_call_comment(out, &format!("DEBUG_PRINT({})", name));
                let label_name = format!("DEBUG_LABEL_{}", name.to_uppercase());
                let skip_label = fresh_label("DEBUG_SKIP_DATA");
                
                out.push_str("    LDD RESULT\n");
                out.push_str("    STA $C002\n");      // Store high byte (A) to C002
                out.push_str("    STB $C000\n");      // Store low byte (B) to C000
                out.push_str("    LDA #$FE\n");       // Marker for LABELED debug output
                out.push_str("    STA $C001\n");      // Write marker
                out.push_str(&format!("    LDX #{}\n", label_name));
                out.push_str("    STX $C004\n");      // Store label pointer to C004-C005 (not C002-C003)
                out.push_str(&format!("    BRA {}\n", skip_label));
                
                // Emit label data inline (skipped by BRA)
                out.push_str(&format!("{}:\n", label_name));
                out.push_str(&format!("    FCC \"{}\"\n", name));
                out.push_str("    FCB $00\n");        // Null terminator
                out.push_str(&format!("{}:\n", skip_label));
            } else {
                // Simple debug output (no label)
                add_native_call_comment(out, "DEBUG_PRINT");
                out.push_str("    LDD RESULT\n");
                out.push_str("    STA $C002\n");      // Store high byte (A) to C002
                out.push_str("    STB $C000\n");      // Store low byte (B) to C000
                out.push_str("    LDA #$42\n");       // Marker for simple debug output
                out.push_str("    STA $C001\n");      // Write marker
                out.push_str("    CLR $C003\n");      // Clear label pointer
                out.push_str("    CLR $C005\n");      // Clear label pointer
            }
        }
        out.push_str("    LDD #0\n    STD RESULT\n");
        return true;
    }
    
    // DEBUG_PRINT_STR(string_var): Debug print string content
    // Protocol: C000=unused, C001=marker(0xFD=string), C002-C003=string_ptr, C004-C005=label_ptr
    if matches!(up.as_str(), "DEBUG_PRINT_STR") {
        if let Some(arg) = args.first() {
            // Check if it's a direct string literal
            if let Expr::StringLit(s) = arg {
                // Direct string literal: DEBUG_PRINT_STR("Hello")
                if let Some(label) = string_map.get(s) {
                    add_native_call_comment(out, &format!("DEBUG_PRINT_STR(\"{}\")", s));
                    let skip_label = fresh_label("DEBUG_SKIP_DATA");
                    
                    out.push_str(&format!("    LDX #{}    ; Load string literal pointer\n", label));
                    out.push_str("    STX $C002\n");      // Store string pointer
                    out.push_str("    LDA #$FD\n");       // Marker for STRING debug output
                    out.push_str("    STA $C001\n");      // Write marker
                    out.push_str("    CLR $C004\n");      // No label for literals
                    out.push_str("    CLR $C005\n");
                } else {
                    // String not in map - shouldn't happen
                    out.push_str("    ; DEBUG_PRINT_STR: string not found in map\n");
                    out.push_str("    CLR $C001\n");
                }
            } else {
                // Variable or expression
                let var_name = if let Expr::Ident(id) = arg {
                    Some(id.name.clone())
                } else {
                    None
                };
                
                emit_expr(arg, out, fctx, string_map, opts);
                
                if let Some(name) = var_name {
                    add_native_call_comment(out, &format!("DEBUG_PRINT_STR({})", name));
                    let label_name = format!("DEBUG_LABEL_{}", name.to_uppercase());
                    let skip_label = fresh_label("DEBUG_SKIP_DATA");
                    
                    out.push_str("    LDD RESULT\n");
                    out.push_str("    STD $C002\n");      // Store string pointer
                    out.push_str("    LDA #$FD\n");       // Marker for STRING debug output
                    out.push_str("    STA $C001\n");      // Write marker
                    out.push_str(&format!("    LDX #{}\n", label_name));
                    out.push_str("    STX $C004\n");      // Store label pointer at C004-C005
                    out.push_str(&format!("    BRA {}\n", skip_label));
                    
                    // Emit label data inline
                    out.push_str(&format!("{}:\n", label_name));
                    out.push_str(&format!("    FCC \"{}\"\n", name));
                    out.push_str("    FCB $00\n");
                    out.push_str(&format!("{}:\n", skip_label));
                } else {
                    // Expression without label
                    add_native_call_comment(out, "DEBUG_PRINT_STR");
                    out.push_str("    LDD RESULT\n");
                    out.push_str("    STD $C002\n");      // Store string pointer
                    out.push_str("    LDA #$FD\n");       // Marker for STRING debug output
                    out.push_str("    STA $C001\n");      // Write marker
                    out.push_str("    CLR $C004\n");      // Clear label pointer
                    out.push_str("    CLR $C005\n");
                }
            }
        }
        out.push_str("    LDD #0\n    STD RESULT\n");
        return true;
    }
    
    // MIN(a,b)
    if matches!(up.as_str(), "MIN"|"MATH_MIN") {
        if args.len() < 2 { out.push_str("    LDD #0\n    STD RESULT\n"); return true; }
    emit_expr(&args[0], out, fctx, string_map, opts);
        out.push_str("    LDD RESULT\n    STD TMPLEFT\n");
    emit_expr(&args[1], out, fctx, string_map, opts);
        out.push_str("    LDD RESULT\n    STD TMPRIGHT\n");
        let use_right = fresh_label("MIN_USE_R");
        let done = fresh_label("MIN_DONE");
        out.push_str(&format!("    LDD TMPLEFT\n    SUBD TMPRIGHT\n    BGT {}\n    LDD TMPLEFT\n    BRA {}\n{}: LDD TMPRIGHT\n{}: STD RESULT\n", use_right, done, use_right, done));
        return true;
    }
    // MAX(a,b)
    if matches!(up.as_str(), "MAX"|"MATH_MAX") {
        if args.len() < 2 { out.push_str("    LDD #0\n    STD RESULT\n"); return true; }
    emit_expr(&args[0], out, fctx, string_map, opts);
        out.push_str("    LDD RESULT\n    STD TMPLEFT\n");
    emit_expr(&args[1], out, fctx, string_map, opts);
        out.push_str("    LDD RESULT\n    STD TMPRIGHT\n");
        let use_right = fresh_label("MAX_USE_R");
        let done = fresh_label("MAX_DONE");
        out.push_str(&format!("    LDD TMPLEFT\n    SUBD TMPRIGHT\n    BLT {}\n    LDD TMPLEFT\n    BRA {}\n{}: LDD TMPRIGHT\n{}: STD RESULT\n", use_right, done, use_right, done));
        return true;
    }
    // CLAMP(v, lo, hi)
    if matches!(up.as_str(), "CLAMP"|"MATH_CLAMP") {
        if args.len() < 3 { out.push_str("    LDD #0\n    STD RESULT\n"); return true; }
        // v
    emit_expr(&args[0], out, fctx, string_map, opts);
        out.push_str("    LDD RESULT\n    STD TMPLEFT\n");
        // lo
    emit_expr(&args[1], out, fctx, string_map, opts);
        out.push_str("    LDD RESULT\n    STD TMPRIGHT\n");
        // hi -> reuse DIV_A
    emit_expr(&args[2], out, fctx, string_map, opts);
        out.push_str("    LDD RESULT\n    STD DIV_A\n");
        let use_lo = fresh_label("CLAMP_USE_LO");
        let check_hi = fresh_label("CLAMP_CHECK_HI");
        let use_hi = fresh_label("CLAMP_USE_HI");
        let done = fresh_label("CLAMP_DONE");
        out.push_str(&format!(
            "    LDD TMPLEFT\n    SUBD TMPRIGHT\n    BLT {}\n    BRA {}\n{}: LDD TMPRIGHT\n    BRA {}\n{}: LDD TMPLEFT\n    SUBD DIV_A\n    BGT {}\n    LDD TMPLEFT\n    BRA {}\n{}: LDD DIV_A\n{}: STD RESULT\n",
            use_lo, check_hi, use_lo, done, check_hi, use_hi, done, use_hi, done
        ));
        return true;
    }
    // PRINT_TEXT: Support 3 or 5 parameters
    // 3 params: PRINT_TEXT(x, y, text) - uses BIOS defaults
    // 5 params: PRINT_TEXT(x, y, text, height, width) - custom size + restore defaults after
    if matches!(up.as_str(), "PRINT_TEXT"|"VECTREX_PRINT_TEXT") {
        if args.len() == 5 {
            out.push_str("; PRINT_TEXT(x, y, text, height, width) - custom size\n");
            
            // Set height (arg[3]) to Vec_Text_Height ($C82A)
            emit_expr(&args[3], out, fctx, string_map, opts);
            out.push_str("    LDA RESULT+1  ; Height (negative value)\n");
            out.push_str("    STA $C82A     ; Vec_Text_Height\n");
            
            // Set width (arg[4]) to Vec_Text_Width ($C82B)
            emit_expr(&args[4], out, fctx, string_map, opts);
            out.push_str("    LDA RESULT+1  ; Width (positive value)\n");
            out.push_str("    STA $C82B     ; Vec_Text_Width\n");
            
            // Now handle x, y, text normally (args 0-2)
            for i in 0..3 {
                emit_expr(&args[i], out, fctx, string_map, opts);
                out.push_str("    LDD RESULT\n");
                out.push_str(&format!("    STD VAR_ARG{}\n", i));
            }
            
            add_native_call_comment(out, "VECTREX_PRINT_TEXT");
            if opts.force_extended_jsr {
                out.push_str("    JSR >VECTREX_PRINT_TEXT\n");
            } else {
                out.push_str("    JSR VECTREX_PRINT_TEXT\n");
            }
            
            // CRITICAL: Restore BIOS default values after rendering
            out.push_str("    LDA #$F8      ; Default height (-8 in two's complement)\n");
            out.push_str("    STA $C82A     ; Restore Vec_Text_Height\n");
            out.push_str("    LDA #72       ; Default width (72)\n");
            out.push_str("    STA $C82B     ; Restore Vec_Text_Width\n");
            
            out.push_str("    CLRA\n    CLRB\n    STD RESULT\n");
            return true;
        } else if args.len() == 3 {
            out.push_str("; PRINT_TEXT(x, y, text) - uses BIOS defaults\n");
            // Normal 3-parameter version - fall through to generic handling below
        } else {
            // Wrong number of arguments - generate error comment
            out.push_str(&format!("; ERROR: PRINT_TEXT expects 3 or 5 arguments, got {}\n", args.len()));
            out.push_str("    CLRA\n    CLRB\n    STD RESULT\n");
            return true;
        }
    }
    
    // Trig functions
    if matches!(up.as_str(), "SIN"|"COS"|"TAN"|"MATH_SIN"|"MATH_COS"|"MATH_TAN") {
        // Expect 1 arg
    if let Some(arg) = args.first() {
            emit_expr(arg, out, fctx, string_map, opts);
            out.push_str("    LDD RESULT\n    ANDB #$7F\n    CLRA\n    ASLB\n    ROLA\n    LDX #SIN_TABLE\n");
            if up.ends_with("COS") { out.push_str("    LDX #COS_TABLE\n"); }
            if up.ends_with("TAN") { out.push_str("    LDX #TAN_TABLE\n"); }
            out.push_str("    ABX\n    LDD ,X\n    STD RESULT\n");
            return true;
        }
        // No arg: return 0
        out.push_str("    CLRA\n    CLRB\n    STD RESULT\n");
        return true;
    }
    
    for (i, a) in args.iter().enumerate() {
        if i >= 5 { break; }
    emit_expr(a, out, fctx, string_map, opts);
        out.push_str("    LDD RESULT\n");
        out.push_str(&format!("    STD VAR_ARG{}\n", i));
    }
    
    // Resolve function name (e.g., DEBUG_PRINT_LABELED -> VECTREX_DEBUG_PRINT_LABELED)
    let resolved_name = resolve_function_name(&up).unwrap_or(up.clone());
    
    // Add native call tracking comment before JSR
    add_native_call_comment(out, &resolved_name);
    
    if opts.force_extended_jsr { out.push_str(&format!("    JSR >{}\n", resolved_name)); } else { out.push_str(&format!("    JSR {}\n", resolved_name)); }
    // Return 0
    out.push_str("    CLRA\n    CLRB\n    STD RESULT\n");
    true
}