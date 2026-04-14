//! ARM Thumb2 expression compiler.
//!
//! Evaluates VPy expressions into Thumb2 assembly.
//! Result always ends up in r0.

use vpy_parser::{Expr, BinOp, CmpOp, LogicOp, CallInfo};

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
            match op {
                CmpOp::Eq => { s.push_str("    ite     eq\n    moveq   r0, #1\n    movne   r0, #0\n"); }
                CmpOp::Ne => { s.push_str("    ite     ne\n    movne   r0, #1\n    moveq   r0, #0\n"); }
                CmpOp::Lt => { s.push_str("    ite     lt\n    movlt   r0, #1\n    movge   r0, #0\n"); }
                CmpOp::Le => { s.push_str("    ite     le\n    movle   r0, #1\n    movgt   r0, #0\n"); }
                CmpOp::Gt => { s.push_str("    ite     gt\n    movgt   r0, #1\n    movle   r0, #0\n"); }
                CmpOp::Ge => { s.push_str("    ite     ge\n    movge   r0, #1\n    movlt   r0, #0\n"); }
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
                    s.push_str("    ite     ne\n    movne   r0, #1\n    moveq   r0, #0\n");
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
            s.push_str("    ite     eq\n    moveq   r0, #1\n    movne   r0, #0\n");
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

        other => Err(format!("Unsupported expression in ARM backend: {:?}", other)),
    }
}

/// Builtins whose first argument is an asset name (string literal → ROM symbol address).
const ASSET_BUILTINS: &[&str] = &[
    "DRAW_VECTOR", "DRAW_VECTOR_EX", "DRAW_VECTOR_3D", "PLAY_MUSIC", "PLAY_SFX",
    "LOAD_LEVEL", "SHOW_LEVEL",
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

    let fn_name = match info.name.as_str() {
        "WAIT_RECAL"      => "vpy_wait_recal",
        "SET_INTENSITY"   => "vpy_set_intensity",
        "DRAW_LINE"       => "vpy_draw_line",
        "MOVE"            => "vpy_move",
        "DRAW_VECTOR"     => "vpy_draw_vector",
        "DRAW_VECTOR_EX"  => "vpy_draw_vector_ex",
        "DRAW_VECTOR_3D"  => "vpy_draw_vector_3d",
        "PRINT_TEXT"      => "vpy_print_text",
        "PRINT_NUMBER"    => "vpy_print_number",
        "PLAY_MUSIC"      => "vpy_play_music",
        "PLAY_SFX"        => "vpy_play_sfx",
        "LOAD_LEVEL"      => "vpy_load_level",
        "SHOW_LEVEL"      => "vpy_show_level",
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
        "GET_CAMERA_X"      => "vpy_get_camera_x",
        "GET_CAMERA_Y"      => "vpy_get_camera_y",
        // Message system
        "MSG_DEF"         => "vpy_msg_def",
        "PRINT_MSG"       => "vpy_print_msg",
        // Text/display extras
        "SET_TEXT_SIZE"   => "vpy_set_text_size",
        "SET_TEXT_COLOR"  => "vpy_set_text_color",
        "UPDATE_LEVEL"    => "vpy_update_level",
        // Misc
        "beep" | "BEEP"   => "vpy_beep",
        "wait" | "WAIT"   => "vpy_wait",
        "peek" | "PEEK"   => "vpy_peek",
        "poke" | "POKE"   => "vpy_poke",
        "len" | "LEN"     => "vpy_len",
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
