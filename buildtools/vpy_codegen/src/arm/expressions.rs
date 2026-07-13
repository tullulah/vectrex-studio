//! ARM Thumb2 expression compiler.
//!
//! Evaluates VPy expressions into Thumb2 assembly.
//! Result always ends up in r0.

use vpy_parser::{Expr, BinOp, CmpOp, LogicOp, CallInfo};
use std::sync::atomic::{AtomicUsize, Ordering};

static COND_LABEL_CTR: AtomicUsize = AtomicUsize::new(0);

/// Emit code that sets r0=1 if condition is true, r0=0 otherwise.
/// `branch_if_false` is the branch mnemonic taken when the condition is FALSE
/// (the complement), e.g. for LT use "bge".  Uses forward branches instead of
/// IT blocks so that 16-bit `movs` never runs inside an IT slot and cannot
/// corrupt the flags used by the ELSE evaluation.
fn bool_from_flags(branch_if_false: &str) -> String {
    let id = COND_LABEL_CTR.fetch_add(1, Ordering::Relaxed);
    format!(
        "    {branch_if_false}    .Lcf{id}\n\
         \x20   movs    r0, #1\n\
         \x20   b       .Lcf{id}e\n\
         .Lcf{id}:\n\
         \x20   movs    r0, #0\n\
         .Lcf{id}e:\n"
    )
}

/// Emit Thumb2 code to evaluate `expr`, leaving result in r0.
pub fn emit_expr(
    expr: &Expr,
    var_addrs: &std::collections::HashMap<String, u32>,
) -> Result<String, String> {
    match expr {
        Expr::Number(n) => {
            // For values that fit in a 16-bit immediate, use MOV; else LDR literal
            if *n >= 0 && *n <= 65535 {
                Ok(format!("    mov     r0, #{n}\n"))
            } else {
                Ok(format!("    ldr     r0, ={n}\n"))
            }
        }

        Expr::Ident(info) => {
            let name_up = info.name.to_uppercase();
            if let Some(&addr) = var_addrs.get(&name_up) {
                Ok(format!(
                    "    ldr     r1, =0x{addr:08X}    @ {}\n    ldr     r0, [r1]\n",
                    info.name
                ))
            } else {
                Err(format!("Unknown variable: {}", info.name))
            }
        }

        Expr::Binary { op, left, right } => {
            let mut s = String::new();
            s.push_str(&emit_expr(left, var_addrs)?);
            s.push_str("    push    {r0}\n");
            s.push_str(&emit_expr(right, var_addrs)?);
            s.push_str("    mov     r1, r0\n");
            s.push_str("    pop     {r0}\n");
            match op {
                BinOp::Add     => s.push_str("    add     r0, r0, r1\n"),
                BinOp::Sub     => s.push_str("    sub     r0, r0, r1\n"),
                BinOp::Mul     => s.push_str("    mul     r0, r0, r1\n"),
                BinOp::Div |
                BinOp::FloorDiv=> s.push_str("    sdiv    r0, r0, r1\n"),
                BinOp::Mod     => {
                    s.push_str("    sdiv    r2, r0, r1\n");
                    s.push_str("    mul     r2, r2, r1\n");
                    s.push_str("    sub     r0, r0, r2\n");
                }
                BinOp::Shl    => s.push_str("    lsl     r0, r0, r1\n"),
                BinOp::Shr    => s.push_str("    asr     r0, r0, r1\n"),
                BinOp::BitAnd => s.push_str("    and     r0, r0, r1\n"),
                BinOp::BitOr  => s.push_str("    orr     r0, r0, r1\n"),
                BinOp::BitXor => s.push_str("    eor     r0, r0, r1\n"),
            }
            Ok(s)
        }

        Expr::Compare { op, left, right } => {
            let mut s = String::new();
            s.push_str(&emit_expr(left, var_addrs)?);
            s.push_str("    push    {r0}\n");
            s.push_str(&emit_expr(right, var_addrs)?);
            s.push_str("    mov     r1, r0\n");
            s.push_str("    pop     {r0}\n");
            s.push_str("    cmp     r0, r1\n");
            // Use conditional branch pattern — IT blocks are avoided because
            // 16-bit `movs` inside them sets N/Z, corrupting ELSE slot evaluation.
            match op {
                CmpOp::Eq => s.push_str(&bool_from_flags("bne")),
                CmpOp::Ne => s.push_str(&bool_from_flags("beq")),
                CmpOp::Lt => s.push_str(&bool_from_flags("bge")),
                CmpOp::Le => s.push_str(&bool_from_flags("bgt")),
                CmpOp::Gt => s.push_str(&bool_from_flags("ble")),
                CmpOp::Ge => s.push_str(&bool_from_flags("blt")),
            }
            Ok(s)
        }

        Expr::Logic { op, left, right } => {
            let mut s = String::new();
            match op {
                LogicOp::And => {
                    // Short-circuit: if left is 0, result is 0
                    s.push_str(&emit_expr(left, var_addrs)?);
                    s.push_str("    cmp     r0, #0\n");
                    s.push_str("    beq     1f\n");
                    s.push_str(&emit_expr(right, var_addrs)?);
                    s.push_str("    cmp     r0, #0\n");
                    s.push_str(&bool_from_flags("beq"));
                    s.push_str("    b       2f\n");
                    s.push_str("1:  mov     r0, #0\n");
                    s.push_str("2:\n");
                }
                LogicOp::Or => {
                    s.push_str(&emit_expr(left, var_addrs)?);
                    s.push_str("    cmp     r0, #0\n");
                    s.push_str("    bne     1f\n");
                    s.push_str(&emit_expr(right, var_addrs)?);
                    s.push_str("    b       2f\n");
                    s.push_str("1:  mov     r0, #1\n");
                    s.push_str("2:\n");
                }
            }
            Ok(s)
        }

        Expr::Not(operand) => {
            let mut s = emit_expr(operand, var_addrs)?;
            s.push_str("    cmp     r0, #0\n");
            s.push_str(&bool_from_flags("bne"));
            Ok(s)
        }

        Expr::BitNot(operand) => {
            let mut s = emit_expr(operand, var_addrs)?;
            s.push_str("    mvn     r0, r0\n");
            Ok(s)
        }

        Expr::Call(info) => emit_call(info, var_addrs),

        Expr::Index { target, index } => {
            let mut s = String::new();
            s.push_str(&emit_expr(target, var_addrs)?);
            s.push_str("    push    {r0}\n");
            s.push_str(&emit_expr(index, var_addrs)?);
            s.push_str("    mov     r1, r0\n");
            s.push_str("    pop     {r0}           @ base ptr\n");
            s.push_str("    lsl     r1, r1, #1     @ index * 2 (i16 stride)\n");
            s.push_str("    add     r0, r0, r1\n");
            s.push_str("    ldrsh   r0, [r0]       @ sign-extend 16-bit load\n");
            Ok(s)
        }

        Expr::StringLit(s) => {
            // String literals used as asset names — not a runtime value
            Err(format!("String literal '{}' not supported as expression in ARM backend", s))
        }

        Expr::MethodCall(info) => {
            match info.method_name.as_str() {
                "abs" => {
                    let mut s = emit_expr(&info.target, var_addrs)?;
                    s.push_str("    cmp     r0, #0\n");
                    s.push_str("    it      mi\n    negmi   r0, r0    @ abs\n");
                    Ok(s)
                }
                "clamp" => {
                    let lo = info.args.get(0).ok_or_else(|| "clamp: missing lo".to_string())?;
                    let hi = info.args.get(1).ok_or_else(|| "clamp: missing hi".to_string())?;
                    let mut s = emit_expr(&info.target, var_addrs)?;
                    // clamp lo: val = max(val, lo)
                    s.push_str("    push    {r0}           @ val\n");
                    s.push_str(&emit_expr(lo, var_addrs)?);
                    s.push_str("    mov     r1, r0\n    pop     {r0}\n");
                    s.push_str("    cmp     r0, r1\n    it      lt\n    movlt   r0, r1    @ max(val, lo)\n");
                    // clamp hi: val = min(val, hi)
                    s.push_str("    push    {r0}           @ val (after lo clamp)\n");
                    s.push_str(&emit_expr(hi, var_addrs)?);
                    s.push_str("    mov     r1, r0\n    pop     {r0}\n");
                    s.push_str("    cmp     r0, r1\n    it      gt\n    movgt   r0, r1    @ min(val, hi)\n");
                    Ok(s)
                }
                "min" => {
                    let arg = info.args.get(0).ok_or_else(|| "min: missing arg".to_string())?;
                    let mut s = emit_expr(&info.target, var_addrs)?;
                    s.push_str("    push    {r0}\n");
                    s.push_str(&emit_expr(arg, var_addrs)?);
                    s.push_str("    mov     r1, r0\n    pop     {r0}\n");
                    s.push_str("    cmp     r0, r1\n    it      gt\n    movgt   r0, r1    @ min(a, b)\n");
                    Ok(s)
                }
                "max" => {
                    let arg = info.args.get(0).ok_or_else(|| "max: missing arg".to_string())?;
                    let mut s = emit_expr(&info.target, var_addrs)?;
                    s.push_str("    push    {r0}\n");
                    s.push_str(&emit_expr(arg, var_addrs)?);
                    s.push_str("    mov     r1, r0\n    pop     {r0}\n");
                    s.push_str("    cmp     r0, r1\n    it      lt\n    movlt   r0, r1    @ max(a, b)\n");
                    Ok(s)
                }
                other => Err(format!("Unsupported method call: .{other}()")),
            }
        }

        other => Err(format!("Unsupported expression in ARM backend: {:?}", other)),
    }
}

/// Builtins whose first argument is an asset name (string literal → ROM symbol address).
const ASSET_BUILTINS: &[&str] = &[
    "DRAW_VECTOR", "DRAW_VECTOR_EX", "DRAW_VECTOR_3D", "PLAY_MUSIC", "PLAY_SFX",
    "LOAD_LEVEL", "SHOW_LEVEL", "PLAY_NOTE",
];

/// Builtins that contain string literals in any position — handled by stripping them
/// and emitting a `.asciz` reference instead (position tracked separately).
const TEXT_BUILTINS: &[&str] = &["PRINT_TEXT"];

/// Emit a function call, placing args in r0–r3 (ARM EABI).
pub fn emit_call(
    info: &CallInfo,
    var_addrs: &std::collections::HashMap<String, u32>,
) -> Result<String, String> {
    // Special case: len(arr) — resolved at compile time via ARRAY_NAME_LEN equate.
    // Only works for simple variable-name arguments (the common case).
    if (info.name == "len" || info.name == "LEN") && info.args.len() == 1 {
        if let Some(vpy_parser::Expr::Ident(id)) = info.args.first() {
            let varname = id.name.to_uppercase();
            // Emit the compile-time constant directly — the assembler resolves it.
            return Ok(format!("    ldr     r0, =ARRAY_{varname}_LEN\n"));
        }
        // Fallthrough for non-Var args → returns 0 via vpy_len
    }

    // Enemy system builtins — implemented on rp2350 via vpy_spawn/update/draw_enemies.
    {
        let name_up = info.name.to_uppercase();
        if name_up == "SPAWN_ENEMIES" {
            // SPAWN_ENEMIES("level_name") → load count + instances from ROM, populate pool
            if let Some(Expr::StringLit(level)) = info.args.first() {
                let sym = level.to_uppercase().replace('-', "_").replace(' ', "_");
                let mut s = format!("    ldr     r0, =_{}_{}\n", sym, "PITREX_ENEMY_COUNT");
                s.push_str(&format!("    ldr     r1, =_{}_{}\n", sym, "PITREX_ENEMIES"));
                s.push_str("    bl      vpy_spawn_enemies\n");
                return Ok(s);
            }
            return Ok(format!("    @ SPAWN_ENEMIES — no-op (no level arg)\n"));
        }
        if name_up == "UPDATE_ENEMIES" {
            return Ok("    bl      vpy_update_enemies\n".to_string());
        }
        if name_up == "DRAW_ENEMIES" {
            return Ok("    bl      vpy_draw_enemies\n".to_string());
        }
    }

    // SET_INTENSITY(v): record a per-frame brightness override (read by
    // DRAW_VECTOR / DRAW_VECTOR_3D so brightness animates, mirroring PiTrex) AND
    // write the DAC. The override is written ONLY here — never inside the draw
    // routines — so per-path .vec intensities remain intact when SET_INTENSITY
    // is not used. Reset to 0 once per frame in functions.rs.
    if info.name == "SET_INTENSITY" && info.args.len() == 1 {
        let mut s = String::new();
        s.push_str(&emit_expr(&info.args[0], var_addrs)?); // r0 = intensity
        s.push_str("    and     r0, r0, #0x7F\n");
        s.push_str("    ldr     r1, =VPY_BRIGHTNESS_OVERRIDE\n");
        s.push_str("    strb    r0, [r1]            @ record override for DRAW_VECTOR*\n");
        s.push_str("    bl      vpy_set_intensity   @ writes the DAC (r0 preserved)\n");
        return Ok(s);
    }

    let fn_name = match info.name.as_str() {
        "WAIT_RECAL"      => "vpy_wait_recal",
        "SET_INTENSITY"   => "vpy_set_intensity",
        "DRAW_LINE"       => "vpy_draw_line",
        "DRAW_CIRCLE"     => "vpy_draw_circle",
        "DRAW_RECT"       => "vpy_draw_rect",
        "DRAW_FILLED_RECT" => "vpy_draw_filled_rect",
        "DRAW_POLYGON"    => "vpy_draw_polygon",
        "DRAW_ARC"        => "vpy_draw_arc",
        "DRAW_ELLIPSE"    => "vpy_draw_ellipse",
        "DRAW_BEZIER"     => "vpy_draw_bezier",
        "DRAW_BEZIER_QUAD"=> "vpy_draw_bezier_quad",
        "MOVE"            => "vpy_move",
        "DRAW_VECTOR"     => "vpy_draw_vector",
        "DRAW_VECTOR_EX"  => "vpy_draw_vector_ex",
        "DRAW_VECTOR_3D"  => "vpy_draw_vector_3d",
        "DRAW_RECORDING"  => "vpy_draw_recording",
        "PRINT_TEXT"      => "vpy_print_text",
        "PRINT_NUMBER"    => "vpy_print_number",
        "PLAY_MUSIC"      => "vpy_play_music",
        "STOP_MUSIC"      => "vpy_stop_music",
        "PLAY_SFX"        => "vpy_play_sfx",
        "PLAY_NOTE"       => "vpy_play_note",
        "LOAD_LEVEL"      => "vpy_load_level",
        "SHOW_LEVEL"      => "vpy_show_level",
        "SAMPLE_POS"      => "vpy_sample_pos",
        "J1_X"            => "vpy_j1_x",
        "J1_Y"            => "vpy_j1_y",
        "J1_BTN1" | "J1_BUTTON_1" => "vpy_j1_btn1",
        "J1_BTN2" | "J1_BUTTON_2" => "vpy_j1_btn2",
        "J1_BTN3" | "J1_BUTTON_3" => "vpy_j1_btn3",
        "J1_BTN4" | "J1_BUTTON_4" => "vpy_j1_btn4",
        "J2_X"            => "vpy_j2_x",
        "J2_Y"            => "vpy_j2_y",
        "J2_BTN1" | "J2_BUTTON_1" => "vpy_j2_btn1",
        "J2_BTN2" | "J2_BUTTON_2" => "vpy_j2_btn2",
        "J2_BTN3" | "J2_BUTTON_3" => "vpy_j2_btn3",
        "J2_BTN4" | "J2_BUTTON_4" => "vpy_j2_btn4",
        "UPDATE_BUTTONS"  => "vpy_update_buttons",
        // Math builtins (both cases)
        "abs" | "ABS"     => "vpy_abs",
        "min" | "MIN"     => "vpy_min",
        "max" | "MAX"     => "vpy_max",
        "clamp" | "CLAMP" => "vpy_clamp",
        "sin" | "SIN"     => "vpy_sin",
        "cos" | "COS"     => "vpy_cos",
        "sqrt" | "SQRT"   => "vpy_sqrt",
        "rand" | "RAND"   => "vpy_rand",
        "rand_range" | "RAND_RANGE" => "vpy_rand_range",
        // Debug builtins
        "debug_print" | "DEBUG_PRINT" => "vpy_debug_print",
        "debug_print_labeled" | "DEBUG_PRINT_LABELED" => "vpy_debug_print_labeled",
        "DEBUG_PRINT_STR"   => "vpy_debug_print_str",
        // Level system
        "LEVEL_COLLISION_Y" => "vpy_level_collision_y",
        "LEVEL_COLLISION_X" => "vpy_level_collision_x",
        "SET_CAMERA_X"      => "vpy_set_camera_x",
        "SET_CAMERA_Y"      => "vpy_set_camera_y",
        "GET_CAMERA_X"           => "vpy_get_camera_x",
        "GET_CAMERA_Y"           => "vpy_get_camera_y",
        "GET_SCROLL_LIMIT_LEFT"  => "vpy_get_scroll_limit_left",
        "GET_SCROLL_LIMIT_RIGHT" => "vpy_get_scroll_limit_right",
        "GET_SCROLL_LIMIT_TOP"   => "vpy_get_scroll_limit_top",
        "GET_SCROLL_LIMIT_BOTTOM"=> "vpy_get_scroll_limit_bottom",
        "GET_LEVEL_FLOOR_Y"      => "vpy_get_level_floor_y",
        "GET_FRAME_US"           => "vpy_get_frame_us",
        // Message system
        "MSG_DEF"         => "vpy_msg_def",
        "PRINT_MSG"       => "vpy_print_msg",
        // Text/display extras
        "SET_TEXT_SIZE"   => "vpy_set_text_size",
        // SET_TEXT_COLOR removed — YAGNI on a monochrome console; use SET_INTENSITY.
        "UPDATE_LEVEL"    => "vpy_update_level",
        // Misc
        "beep" | "BEEP"   => "vpy_beep",
        "wait" | "WAIT"   => "vpy_wait",
        "peek" | "PEEK"   => "vpy_peek",
        "poke" | "POKE"   => "vpy_poke",
        "len" | "LEN"     => "vpy_len",
        // Animation
        "DRAW_ANIM"       => "vpy_draw_anim",
        // Enemy pool operations — ARM implementations
        "GET_ENEMY_ACTIVE"    => "vpy_get_enemy_active",
        "GET_ENEMY_X"         => "vpy_get_enemy_x",
        "GET_ENEMY_Y"         => "vpy_get_enemy_y",
        "GET_ENEMY_STATE"     => "vpy_get_enemy_state",
        "GET_ENEMY_AREA_IDX"  => "vpy_get_enemy_area_idx",
        "SET_ENEMY_X"         => "vpy_set_enemy_x",
        "SET_ENEMY_Y"         => "vpy_set_enemy_y",
        "SET_ENEMY_DIR"       => "vpy_set_enemy_dir",
        "SET_ENEMY_STATE"     => "vpy_set_enemy_state",
        "KILL_ENEMY"          => "vpy_kill_enemy",
        "ENEMY_FIRE_EVENT"    => "vpy_enemy_fire_event",
        other             => other,
    };

    let mut s = String::new();
    let args = &info.args;

    // Special handling for PRINT_TEXT(x, y, "string") — string is 3rd arg
    if TEXT_BUILTINS.contains(&info.name.as_str()) {
        // Find string literal and emit as .asciz in place
        let mut processed: Vec<String> = Vec::new();
        for (i, arg) in args.iter().enumerate() {
            if let Expr::StringLit(text) = arg {
                // Generate unique label for this string
                static STR_CTR: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
                let id = STR_CTR.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let label = format!("_str_{id}");
                // Emit string in rodata section, then return to text
                processed.push(format!(
                    "    b       {label}_end\n{label}:\n    .asciz  \"{text}\\x80\"\n    .align  2\n{label}_end:\n    ldr     r{i}, ={label}\n"
                ));
            } else {
                let expr_s = emit_expr(arg, var_addrs)?;
                processed.push(format!("{expr_s}    push    {{r0}}\n"));
            }
        }
        // Simple approach: eval all, put results in r0..rN
        for (i, p) in processed.iter().enumerate() {
            if !p.contains("ldr     r") {
                s.push_str(p);
                if i < args.len() - 1 {
                    s.push_str(&format!("    mov     r{i}, r0\n"));
                }
            }
        }
        // Re-emit cleanly: push each arg then pop
        s.clear();
        for arg in args.iter() {
            match arg {
                Expr::StringLit(text) => {
                    static STR_CTR2: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
                    let id = STR_CTR2.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                    let label = format!("_str_{id}");
                    s.push_str(&format!("    ldr     r0, ={label}\n"));
                    s.push_str("    push    {r0}\n");
                    // Emit the string data after the call via a literal pool reference
                    s.push_str(&format!("@ string data for label {label} emitted in rodata\n"));
                    // Store for later emission — for now inline with b/label trick
                    s = format!(
                        "{s_prev}    b       {label}_after\n{label}:\n    .asciz  \"{text}\\x80\"\n    .align  2\n{label}_after:\n    ldr     r0, ={label}\n    push    {{r0}}\n",
                        s_prev = {
                            // Remove the last two lines we just added
                            let mut tmp = s.clone();
                            // strip the ldr + push we added above
                            let pos = tmp.rfind(&format!("    ldr     r0, ={label}\n")).unwrap_or(tmp.len());
                            tmp.truncate(pos);
                            tmp
                        }
                    );
                }
                other => {
                    s.push_str(&emit_expr(other, var_addrs)?);
                    s.push_str("    push    {r0}\n");
                }
            }
        }
        let nreg = args.len().min(4);
        for i in (0..nreg).rev() {
            s.push_str(&format!("    pop     {{r{i}}}\n"));
        }
        s.push_str(&format!("    bl      {fn_name}\n"));
        let nextra = args.len().saturating_sub(4);
        if nextra > 0 {
            s.push_str(&format!("    add     sp, sp, #{}\n", nextra * 4));
        }
        return Ok(s);
    }

    // Special case: DRAW_VECTOR("name", ox, oy [, mirror]) — always emit r0=asset, r1=ox, r2=oy.
    // ox/oy default to 0 when not supplied so the vector draws at screen centre.
    // If a 4th arg (mirror) is present, route through vpy_draw_vector_ex so the mirror is applied.
    if info.name == "DRAW_VECTOR" {
        if let Some(Expr::StringLit(asset_name)) = args.first() {
            let sym_base = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol   = format!("_{sym_base}_VECTORS");
            let runtime: Vec<&Expr> = args.iter().skip(1).collect();
            if let Some(mirror) = runtime.get(2) {
                // 4-arg form: DRAW_VECTOR(name, ox, oy, mirror) → vpy_draw_vector_ex
                // Push intensity=0 first (function reads [sp+32] after push of 8 regs)
                s.push_str("    mov     r0, #0\n");
                s.push_str("    push    {r0}\n");
                // r0 = asset ptr
                s.push_str(&format!("    ldr     r0, ={symbol}    @ asset '{asset_name}'\n"));
                s.push_str("    push    {r0}\n");
                // r1 = ox
                if let Some(ox) = runtime.first() {
                    s.push_str(&emit_arg(ox, var_addrs)?);
                } else {
                    s.push_str("    mov     r0, #0\n");
                }
                s.push_str("    push    {r0}\n");
                // r2 = oy
                if let Some(oy) = runtime.get(1) {
                    s.push_str(&emit_arg(oy, var_addrs)?);
                } else {
                    s.push_str("    mov     r0, #0\n");
                }
                s.push_str("    push    {r0}\n");
                // r3 = mirror
                s.push_str(&emit_arg(mirror, var_addrs)?);
                s.push_str("    push    {r0}\n");
                // pop r3=mirror, r2=oy, r1=ox, r0=asset; intensity stays at [sp]
                s.push_str("    pop     {r3}\n    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
                s.push_str("    bl      vpy_draw_vector_ex\n");
                s.push_str("    add     sp, sp, #4\n"); // discard intensity
            } else {
                // 3-arg form: DRAW_VECTOR(name, ox, oy) → vpy_draw_vector (no mirror)
                s.push_str(&format!("    ldr     r0, ={symbol}    @ asset '{asset_name}'\n"));
                s.push_str("    push    {r0}\n");
                if let Some(ox) = runtime.first() {
                    s.push_str(&emit_arg(ox, var_addrs)?);
                } else {
                    s.push_str("    mov     r0, #0\n");
                }
                s.push_str("    push    {r0}\n");
                if let Some(oy) = runtime.get(1) {
                    s.push_str(&emit_arg(oy, var_addrs)?);
                } else {
                    s.push_str("    mov     r0, #0\n");
                }
                s.push_str("    push    {r0}\n");
                s.push_str("    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
                s.push_str("    bl      vpy_draw_vector\n");
            }
            return Ok(s);
        }
    }

    // Special case: DRAW_VECTOR_EX(asset, ox, oy, mirror, intensity)
    // ABI: r0=asset_ptr, r1=ox, r2=oy, r3=mirror, [sp+0]=intensity
    // intensity MUST be on the stack BEFORE the call (and cleaned up after).
    if info.name == "DRAW_VECTOR_EX" {
        if let Some(Expr::StringLit(asset_name)) = args.first() {
            let sym_base = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_{sym_base}_VECTORS");
            let runtime: Vec<&Expr> = args.iter().skip(1).collect();
            // Push intensity first so it sits at [sp] when the function reads [sp+32]
            // (after the function pushes 8 regs = 32 bytes).
            if let Some(intensity) = runtime.get(3) {
                s.push_str(&emit_arg(intensity, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #127\n");
            }
            s.push_str("    push    {r0}\n");
            // r0 = asset_ptr
            s.push_str(&format!("    ldr     r0, ={symbol}    @ asset '{asset_name}'\n"));
            s.push_str("    push    {r0}\n");
            // r1 = ox
            if let Some(ox) = runtime.first() {
                s.push_str(&emit_arg(ox, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // r2 = oy
            if let Some(oy) = runtime.get(1) {
                s.push_str(&emit_arg(oy, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // r3 = mirror
            if let Some(mirror) = runtime.get(2) {
                s.push_str(&emit_arg(mirror, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // pop r3=mirror, r2=oy, r1=ox, r0=asset_ptr; intensity stays at [sp]
            s.push_str("    pop     {r3}\n    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
            s.push_str("    bl      vpy_draw_vector_ex\n");
            s.push_str("    add     sp, sp, #4\n"); // discard intensity from stack
            return Ok(s);
        }
    }

    // Special case: DRAW_RECORDING("name", x, y, scale, frame) — .vrec playback.
    // ABI: r0=_NAME_VREC, r1=x, r2=y, r3=scale (0-128, 128=100%), [sp+0]=frame.
    // frame is a free-running counter — vpy_draw_recording takes frame %
    // frame_count internally. Same stack-arg pattern as DRAW_VECTOR_EX.
    if info.name == "DRAW_RECORDING" {
        if let Some(Expr::StringLit(rec_name)) = args.first() {
            let sym_base = rec_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_{sym_base}_VREC");
            let runtime: Vec<&Expr> = args.iter().skip(1).collect();
            // Push frame first so it sits at [sp] when the routine reads [sp+32]
            // (after its push of 8 regs = 32 bytes).
            if let Some(frame) = runtime.get(3) {
                s.push_str(&emit_arg(frame, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // r0 = recording ptr
            s.push_str(&format!("    ldr     r0, ={symbol}    @ recording '{rec_name}'\n"));
            s.push_str("    push    {r0}\n");
            // r1 = x
            if let Some(x) = runtime.first() {
                s.push_str(&emit_arg(x, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // r2 = y
            if let Some(y) = runtime.get(1) {
                s.push_str(&emit_arg(y, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // r3 = scale (default 128 = 100%)
            if let Some(scale) = runtime.get(2) {
                s.push_str(&emit_arg(scale, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #128\n");
            }
            s.push_str("    push    {r0}\n");
            // pop r3=scale, r2=y, r1=x, r0=recording ptr; frame stays at [sp]
            s.push_str("    pop     {r3}\n    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
            s.push_str("    bl      vpy_draw_recording\n");
            s.push_str("    add     sp, sp, #4\n"); // discard frame from stack
            return Ok(s);
        }
    }

    // Special case: PLAY_SAMPLE("name") — .vsmp audio-sample playback.
    // ABI: r0 = _NAME_SMP (ROM table ptr). vpy_play_sample is an SVC trap that
    // hands the sample off to the core1 audio streamer. Resolves the
    // string-literal name to the `_<NAME>_SMP` symbol, same as DRAW_RECORDING.
    if info.name == "PLAY_SAMPLE" {
        if let Some(Expr::StringLit(smp_name)) = args.first() {
            let sym_base = smp_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_{sym_base}_SMP");
            let mut s = String::new();
            s.push_str(&format!("    ldr     r0, ={symbol}    @ sample '{smp_name}'\n"));
            s.push_str("    bl      vpy_play_sample\n");
            return Ok(s);
        }
    }

    // Special case: DRAW_ANIM("name", ox, oy) — animation asset, symbol is _ANIM_NAME
    if info.name == "DRAW_ANIM" {
        if let Some(Expr::StringLit(anim_name)) = args.first() {
            let sym = anim_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_ANIM_{sym}");
            // push anim ptr, push ox, push oy; then pop r2=oy, r1=ox, r0=anim ptr
            s.push_str(&format!("    ldr     r0, ={symbol}    @ animation '{anim_name}'\n"));
            s.push_str("    push    {r0}\n");
            if args.len() >= 3 {
                s.push_str(&emit_arg(&args[1], var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            if args.len() >= 3 {
                s.push_str(&emit_arg(&args[2], var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // Evaluate mirror (4th arg) now, while r0 holds oy (already pushed), before r0=anim_ptr
            // Push mirror so it sits below oy/ox/anim_ptr; pop order: mirror→r4, oy→r2, ox→r1, anim→r0
            if args.len() >= 4 {
                s.push_str(&emit_arg(&args[3], var_addrs)?);
                s.push_str("    push    {r0}                     @ push mirror\n");
                s.push_str("    pop     {r4}                     @ r4 = mirror\n");
            } else {
                s.push_str("    mov     r4, #0                     @ mirror = 0\n");
            }
            s.push_str("    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
            s.push_str("    ldr     r3, =VPY_PLAYER_ANIM_STATE  @ per-entity anim state\n");
            s.push_str("    bl      vpy_draw_anim\n");
            return Ok(s);
        }
    }

    // Special case: DRAW_VECTOR_3D("name", rot_x, rot_y, rot_z, pos_x, pos_y)
    // vpy_draw_vector_3d(r0=_NAME_3D_DATA, r1=ax, r2=ay, r3=az, [sp]=ox, [sp+4]=oy).
    // Takes the vertex-indexed _3D_DATA asset (not _VECTORS — that's the 2D
    // path-list format).
    if info.name == "DRAW_VECTOR_3D" {
        if let Some(Expr::StringLit(asset_name)) = args.first() {
            let sym_base = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_{sym_base}_3D_DATA");

            let emit_or_zero = |idx: usize, s: &mut String| -> Result<(), String> {
                if let Some(a) = args.get(idx) {
                    s.push_str(&emit_arg(a, var_addrs)?);
                } else {
                    s.push_str("    mov     r0, #0\n");
                }
                Ok(())
            };

            // Push order: oy, ox, az, ay, ax, asset.
            // After popping r0..r3, the stack still has [ox, oy] with ox on
            // top, matching the function's expected [sp]=ox, [sp+4]=oy frame.
            emit_or_zero(5, &mut s)?; // oy → [sp+4]
            s.push_str("    push    {r0}\n");
            emit_or_zero(4, &mut s)?; // ox → [sp]
            s.push_str("    push    {r0}\n");
            emit_or_zero(3, &mut s)?; // az
            s.push_str("    push    {r0}\n");
            emit_or_zero(2, &mut s)?; // ay
            s.push_str("    push    {r0}\n");
            emit_or_zero(1, &mut s)?; // ax
            s.push_str("    push    {r0}\n");
            s.push_str(&format!("    ldr     r0, ={symbol}    @ 3D data for '{asset_name}'\n"));
            s.push_str("    push    {r0}\n");

            s.push_str("    pop     {r0}\n    pop     {r1}\n    pop     {r2}\n    pop     {r3}\n");
            s.push_str("    bl      vpy_draw_vector_3d\n");
            s.push_str("    add     sp, sp, #8          @ discard ox, oy\n");
            return Ok(s);
        }
    }

    // Special case: PLAY_NOTE("name", channel, note)
    // r0=_NAME_INSTR address, r1=channel(0-2), r2=note(MIDI 24-107)
    if info.name == "PLAY_NOTE" {
        if let Some(Expr::StringLit(instr_name)) = args.first() {
            let sym_base = instr_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_{sym_base}_INSTR");
            // r0 = instrument ROM block address
            s.push_str(&format!("    ldr     r0, ={symbol}    @ instrument '{instr_name}'\n"));
            s.push_str("    push    {r0}\n");
            // r1 = channel
            if let Some(ch_expr) = args.get(1) {
                s.push_str(&emit_arg(ch_expr, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // r2 = note
            if let Some(note_expr) = args.get(2) {
                s.push_str(&emit_arg(note_expr, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #60\n");
            }
            s.push_str("    push    {r0}\n");
            s.push_str("    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
            s.push_str("    bl      vpy_play_note\n");
            return Ok(s);
        }
    }

    // For asset builtins, the first arg is a string literal → ROM symbol address.
    // Only treat as asset builtin if first arg is actually a string literal.
    let is_asset_builtin = ASSET_BUILTINS.contains(&info.name.as_str())
        && matches!(args.first(), Some(Expr::StringLit(_)));
    let runtime_args: Vec<(usize, &Expr)> = args.iter().enumerate()
        .filter(|(i, arg)| {
            !(is_asset_builtin && *i == 0 && matches!(arg, Expr::StringLit(_)))
        })
        .collect();

    // Emit asset name as first register (r0 = address of asset data in ROM)
    if is_asset_builtin {
        if let Some(Expr::StringLit(asset_name)) = args.first() {
            let sym_base = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
            // Choose symbol suffix based on builtin type
            let suffix = match info.name.as_str() {
                "PLAY_MUSIC"               => "MUSIC",
                "PLAY_SFX"                 => "SFX",
                "PLAY_NOTE"                => "INSTR",
                "LOAD_LEVEL" | "SHOW_LEVEL" => "LEVEL",
                _                          => "VECTORS",
            };
            let symbol = format!("_{sym_base}_{suffix}");
            s.push_str(&format!("    ldr     r0, ={symbol}    @ asset '{asset_name}'\n"));
            s.push_str("    push    {r0}\n");
        }
    }

    let n_asset = if is_asset_builtin { 1 } else { 0 };
    let total_reg_args = runtime_args.len() + n_asset;
    let n_extra = total_reg_args.saturating_sub(4);
    let n_skip = (4usize).saturating_sub(n_asset);

    // Extra args right-to-left
    for (_, arg) in runtime_args.iter().skip(n_skip).rev() {
        s.push_str(&emit_arg(arg, var_addrs)?);
        s.push_str("    push    {r0}\n");
    }
    // First register args
    for (_, arg) in runtime_args.iter().take(n_skip) {
        s.push_str(&emit_arg(arg, var_addrs)?);
        s.push_str("    push    {r0}\n");
    }

    let nreg = total_reg_args.min(4);
    for i in (0..nreg).rev() {
        s.push_str(&format!("    pop     {{r{i}}}\n"));
    }

    s.push_str(&format!("    bl      {fn_name}\n"));

    let nextra = n_extra;
    if nextra > 0 {
        s.push_str(&format!("    add     sp, sp, #{}\n", nextra * 4));
    }

    Ok(s)
}

/// Emit one function argument into r0.
/// Handles string literals as inline PC-relative data (branch-over trick).
fn emit_arg(
    expr: &Expr,
    var_addrs: &std::collections::HashMap<String, u32>,
) -> Result<String, String> {
    if let Expr::StringLit(text) = expr {
        static STR_CTR: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
        let id = STR_CTR.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        let label = format!("_arg_str_{id}");
        // Branch over the string data, load its address into r0
        let s = format!(
            "    b       {label}_end\n\
             {label}:\n\
             .asciz  \"{text}\"\n\
             .align  2\n\
             {label}_end:\n\
             .ltorg\n\
             ldr     r0, ={label}\n"
        );
        Ok(s)
    } else {
        emit_expr(expr, var_addrs)
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use vpy_parser::CallInfo;

    fn make_call(name: &str) -> CallInfo {
        CallInfo { name: name.to_string(), source_line: 0, col: 0, args: vec![] }
    }

    fn make_call_with_arg(name: &str, arg: i32) -> CallInfo {
        CallInfo {
            name: name.to_string(),
            source_line: 0,
            col: 0,
            args: vec![vpy_parser::Expr::Number(arg)],
        }
    }

    /// Regression test for Bug 1: M6809-only enemy builtins must be no-ops on
    /// rp2350 and must NOT emit an unresolved external `bl` symbol.
    /// Previously GET_ENEMY_ACTIVE / GET_ENEMY_X / GET_ENEMY_Y / GET_ENEMY_STATE /
    /// KILL_ENEMY / ENEMY_FIRE_EVENT fell through to `other => other` and emitted
    /// `bl GET_ENEMY_ACTIVE` (and similar), which would fail at link time with
    /// "undefined symbol".
    #[test]
    fn test_arm_enemy_pool_builtins() {
        let var_addrs = std::collections::HashMap::new();

        // UPDATE_ENEMIES / DRAW_ENEMIES — real rp2350 implementations via vpy_* helpers.
        let ue_asm = emit_call(&make_call("UPDATE_ENEMIES"), &var_addrs).unwrap();
        assert!(ue_asm.contains("bl      vpy_update_enemies"),
            "UPDATE_ENEMIES must emit `bl vpy_update_enemies` (got: {ue_asm:?})");

        let de_asm = emit_call(&make_call("DRAW_ENEMIES"), &var_addrs).unwrap();
        assert!(de_asm.contains("bl      vpy_draw_enemies"),
            "DRAW_ENEMIES must emit `bl vpy_draw_enemies` (got: {de_asm:?})");

        // Query builtins — must call vpy_* ARM helpers (not return hardcoded 0).
        for (name, expected_fn) in &[
            ("GET_ENEMY_ACTIVE",   "vpy_get_enemy_active"),
            ("GET_ENEMY_X",        "vpy_get_enemy_x"),
            ("GET_ENEMY_Y",        "vpy_get_enemy_y"),
            ("GET_ENEMY_STATE",    "vpy_get_enemy_state"),
            ("GET_ENEMY_AREA_IDX", "vpy_get_enemy_area_idx"),
        ] {
            let info = make_call_with_arg(name, 0);
            let asm = emit_call(&info, &var_addrs).expect(name);
            assert!(asm.contains(&format!("bl      {expected_fn}")),
                "{name}: must emit `bl {expected_fn}` (got: {asm:?})");
        }

        // Mutate builtins — must call vpy_* ARM helpers.
        for (name, expected_fn) in &[
            ("KILL_ENEMY",      "vpy_kill_enemy"),
            ("ENEMY_FIRE_EVENT","vpy_enemy_fire_event"),
        ] {
            let info = make_call_with_arg(name, 0);
            let asm = emit_call(&info, &var_addrs).expect(name);
            assert!(asm.contains(&format!("bl      {expected_fn}")),
                "{name}: must emit `bl {expected_fn}` (got: {asm:?})");
        }

        // SPAWN_ENEMIES with no level arg is a no-op.
        let sa_asm = emit_call(&make_call("SPAWN_ENEMIES"), &var_addrs).unwrap();
        assert!(sa_asm.contains("no-op"), "SPAWN_ENEMIES (no arg) should be no-op");
    }

    /// DRAW_RECORDING("name", x, y, scale, frame) — .vrec playback call site.
    /// r0=_NAME_VREC, r1=x, r2=y, r3=scale, [sp]=frame (cleaned up after call).
    #[test]
    fn test_arm_draw_recording_call() {
        let var_addrs = std::collections::HashMap::new();
        let info = CallInfo {
            name: "DRAW_RECORDING".to_string(),
            source_line: 0,
            col: 0,
            args: vec![
                vpy_parser::Expr::StringLit("snow-bros preview".to_string()),
                vpy_parser::Expr::Number(0),
                vpy_parser::Expr::Number(10),
                vpy_parser::Expr::Number(45),
                vpy_parser::Expr::Number(7),
            ],
        };
        let asm = emit_call(&info, &var_addrs).unwrap();
        assert!(asm.contains("ldr     r0, =_SNOW_BROS_PREVIEW_VREC"),
            "must resolve recording name to _NAME_VREC symbol (got: {asm:?})");
        assert!(asm.contains("bl      vpy_draw_recording"),
            "must call vpy_draw_recording (got: {asm:?})");
        assert!(asm.contains("add     sp, sp, #4"),
            "must clean up the frame stack arg (got: {asm:?})");
    }

    /// SPAWN_ENEMIES / UPDATE_ENEMIES / DRAW_ENEMIES were already no-ops before
    /// the fix. This test ensures they remain no-ops after the refactor.
    #[test]
    fn test_arm_original_m6809_noops_still_noop() {
        let var_addrs = std::collections::HashMap::new();
        for name in &["SPAWN_ENEMIES", "UPDATE_ENEMIES", "DRAW_ENEMIES"] {
            let info = make_call(name);
            let asm = emit_call(&info, &var_addrs).expect(name);
            assert!(
                !asm.contains(&format!("bl      {name}")),
                "{name}: must remain a no-op on rp2350"
            );
        }
    }
}
