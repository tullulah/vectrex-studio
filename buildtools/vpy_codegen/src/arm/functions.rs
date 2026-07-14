//! ARM Thumb2 function code generation.

use vpy_parser::{Module, Item, Stmt, Expr, AssignTarget, BinOp};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use super::ram_layout::RamAllocator;
use super::expressions::emit_expr;
use super::analysis::Usage;
use crate::AssetInfo;

static LABEL_CTR: AtomicU32 = AtomicU32::new(0);
fn next_id() -> u32 { LABEL_CTR.fetch_add(1, Ordering::Relaxed) }

pub fn emit_functions(
    module: &Module,
    _assets: &[AssetInfo],
    usage: &Usage,
) -> Result<String, String> {
    let mut s = String::new();

    let (var_addrs, var_decls) = allocate_globals(module);

    s.push_str("@ --- User variables (RAM) ---\n");
    s.push_str(&var_decls);
    s.push('\n');

    // Emit const array ROM data tables (before user functions so they land in bank 0).
    // These are labelled .hword tables pointed to by VAR_{name} at startup.
    s.push_str("@ --- Const array ROM data ---\n");
    for item in &module.items {
        if let Item::Const { name, value, .. } = item {
            if let Expr::List(elems) = value {
                let varname = name.to_uppercase();
                s.push_str(".align 2\n");
                s.push_str(&format!("ARRAY_{varname}_DATA:\n"));
                for elem in elems {
                    if let Expr::Number(n) = elem {
                        s.push_str(&format!("    .hword {n}\n"));
                    }
                }
            }
        }
    }
    s.push('\n');

    // Emit user-defined functions (skip main/loop — inlined by emit_game_main).
    // After unification all names are uppercase, so compare against "MAIN"/"LOOP".
    for item in &module.items {
        if let Item::Function(func) = item {
            let n = func.name.to_uppercase();
            if n == "MAIN" || n == "LOOP" {
                continue;
            }
            s.push_str(&emit_function(&func.name, &func.params, &func.body, &var_addrs)?);
        }
    }

    s.push_str(&emit_game_main(module, &var_addrs, usage)?);

    Ok(s)
}

fn allocate_globals(module: &Module) -> (HashMap<String, u32>, String) {
    let mut alloc = RamAllocator::new();
    let mut addrs: HashMap<String, u32> = HashMap::new();
    let mut decls = String::new();

    for item in &module.items {
        match item {
            Item::GlobalLet { name, value, .. } => {
                let varname = name.to_uppercase();
                match value {
                    Expr::List(elems) => {
                        let len = elems.len();
                        let data_size = ((len * 2) as u32 + 3) & !3;
                        let data_addr = alloc.alloc(data_size);
                        let ptr_addr  = alloc.alloc(4);
                        decls.push_str(&format!(
                            ".equ ARRAY_{varname}_DATA, 0x{data_addr:08X}\n"
                        ));
                        decls.push_str(&format!(
                            ".equ ARRAY_{varname}_LEN, {len}\n"
                        ));
                        decls.push_str(&format!(
                            ".equ VAR_{varname}, 0x{ptr_addr:08X}  @ array pointer\n"
                        ));
                        addrs.insert(varname, ptr_addr);
                    }
                    _ => {
                        let addr = alloc.alloc(4);
                        decls.push_str(&format!(".equ VAR_{varname}, 0x{addr:08X}\n"));
                        addrs.insert(varname, addr);
                    }
                }
            }
            Item::Const { name, value, .. } => {
                let varname = name.to_uppercase();
                match value {
                    Expr::List(elems) => {
                        let len = elems.len();
                        let ptr_addr = alloc.alloc(4);
                        decls.push_str(&format!(
                            ".equ ARRAY_{varname}_LEN, {len}\n"
                        ));
                        decls.push_str(&format!(
                            ".equ VAR_{varname}, 0x{ptr_addr:08X}  @ const array pointer\n"
                        ));
                        addrs.insert(varname, ptr_addr);
                    }
                    _ => {
                        // Scalar const: allocate RAM so reads work via var_addrs.
                        // Value is initialized in game_main startup.
                        let addr = alloc.alloc(4);
                        decls.push_str(&format!(
                            ".equ VAR_{varname}, 0x{addr:08X}  @ const scalar\n"
                        ));
                        addrs.insert(varname, addr);
                    }
                }
            }
            _ => {}
        }
    }

    // Scan all function bodies (including main/loop) for parameters and local variables.
    // Allocate RAM for each unique name not already in addrs.
    for item in &module.items {
        if let Item::Function(func) = item {
            // Parameters: saved from r0-r3 at function entry
            for param in &func.params {
                ensure_var(param, &mut alloc, &mut addrs, &mut decls, "param");
            }
            collect_locals(&func.body, &mut alloc, &mut addrs, &mut decls);
        }
    }

    (addrs, decls)
}

/// Recursively scan `stmts` for local variable declarations/assignments,
/// allocating RAM for any name not already present in `addrs`.
/// Handles: Stmt::Let, Stmt::For loop vars, Stmt::Assign to new names.
fn collect_locals(
    stmts: &[Stmt],
    alloc: &mut RamAllocator,
    addrs: &mut HashMap<String, u32>,
    decls: &mut String,
) {
    for stmt in stmts {
        match stmt {
            Stmt::Let { name, .. } => {
                ensure_var(name, alloc, addrs, decls, "local");
            }
            Stmt::Assign { target, .. } => {
                // Implicit locals: assignment to an undeclared name
                if let AssignTarget::Ident { name, .. } = target {
                    ensure_var(name, alloc, addrs, decls, "implicit");
                }
            }
            Stmt::CompoundAssign { target, .. } => {
                if let AssignTarget::Ident { name, .. } = target {
                    ensure_var(name, alloc, addrs, decls, "implicit");
                }
            }
            Stmt::For { var, body, .. } => {
                ensure_var(var, alloc, addrs, decls, "for var");
                collect_locals(body, alloc, addrs, decls);
            }
            Stmt::If { body, elifs, else_body, .. } => {
                collect_locals(body, alloc, addrs, decls);
                for (_, elif_body) in elifs {
                    collect_locals(elif_body, alloc, addrs, decls);
                }
                if let Some(else_stmts) = else_body {
                    collect_locals(else_stmts, alloc, addrs, decls);
                }
            }
            Stmt::While { body, .. } => {
                collect_locals(body, alloc, addrs, decls);
            }
            Stmt::ForIn { var, body, source_line, .. } => {
                ensure_var(var, alloc, addrs, decls, "forin elem");
                ensure_var(&format!("_fi_{source_line}"), alloc, addrs, decls, "forin counter");
                ensure_var(&format!("_fi_{source_line}_base"), alloc, addrs, decls, "forin base ptr");
                ensure_var(&format!("_fi_{source_line}_len"), alloc, addrs, decls, "forin len");
                collect_locals(body, alloc, addrs, decls);
            }
            Stmt::Switch { cases, default, .. } => {
                for (_, case_body) in cases {
                    collect_locals(case_body, alloc, addrs, decls);
                }
                if let Some(def) = default {
                    collect_locals(def, alloc, addrs, decls);
                }
            }
            _ => {}
        }
    }
}

/// Allocate RAM for `name` if it is not already in `addrs`.
fn ensure_var(
    name: &str,
    alloc: &mut RamAllocator,
    addrs: &mut HashMap<String, u32>,
    decls: &mut String,
    kind: &str,
) {
    let varname = name.to_uppercase();
    if !addrs.contains_key(&varname) {
        let addr = alloc.alloc(4);
        decls.push_str(&format!(".equ VAR_{varname}, 0x{addr:08X}  @ {kind}\n"));
        addrs.insert(varname, addr);
    }
}

fn emit_function(
    name: &str,
    params: &[String],
    body: &[Stmt],
    var_addrs: &HashMap<String, u32>,
) -> Result<String, String> {
    // Use original-case name as the ARM label (ARM assembly is case-sensitive).
    // Call sites emit `bl name` and the definition emits `name:` — they must match.
    let mut s = String::new();
    s.push_str(&format!("@ --- function {name} ---\n"));
    s.push_str(".align 2\n");  // ensure 2-byte alignment after preceding .ltorg padding
    s.push_str(&format!(".global {name}\n.type {name}, %function\n.thumb_func\n{name}:\n"));
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");

    // Save incoming arguments to their RAM slots. Args 0-3 arrive in r0-r3
    // (ARM EABI); args 4+ live on the caller's stack — after our own push
    // they sit at sp+20+4*(i-4) (5 regs = 20 bytes pushed). Caller pushes
    // extras in reverse so the first stack arg (i=4) is at the lowest
    // offset above the saved frame.
    for (i, param) in params.iter().enumerate() {
        let varname = param.to_uppercase();
        let Some(&addr) = var_addrs.get(&varname) else { continue };
        if i < 4 {
            s.push_str(&format!(
                "    ldr     r4, =0x{addr:08X}    @ save param {param}\n    str     r{i}, [r4]\n"
            ));
        } else {
            let stack_off = 20 + (i - 4) * 4;
            s.push_str(&format!(
                "    ldr     r5, [sp, #{stack_off}]   @ load stack arg {param}\n\
                 \x20   ldr     r4, =0x{addr:08X}    @ save param {param}\n\
                 \x20   str     r5, [r4]\n"
            ));
        }
    }

    let loop_labels: Vec<(String, String)> = Vec::new();
    for stmt in body {
        // return_label=None: `return` in a helper function emits the real function epilogue
        s.push_str(&emit_stmt(stmt, var_addrs, &loop_labels, None)?);
    }
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");
    Ok(s)
}

fn emit_game_main(
    module: &Module,
    var_addrs: &HashMap<String, u32>,
    usage: &Usage,
) -> Result<String, String> {
    let mut s = String::new();

    // After unification all function names are uppercase.
    let main_fn = module.items.iter().find_map(|i| {
        if let Item::Function(f) = i {
            if f.name.to_uppercase() == "MAIN" { return Some(f); }
        }
        None
    });
    let loop_fn = module.items.iter().find_map(|i| {
        if let Item::Function(f) = i {
            if f.name.to_uppercase() == "LOOP" { return Some(f); }
        }
        None
    });

    s.push_str("@ --- game_main (firmware entry point) ---\n");
    s.push_str(".align 2\n");  // ensure 2-byte alignment after preceding .ltorg padding
    s.push_str(".global game_main\n.type game_main, %function\n.thumb_func\ngame_main:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");

    // Zero the VPy runtime RAM region [TMPVAL .. USER_RAM_START). RP2350 SRAM holds
    // power-on garbage; the emulator runs with zeroed SRAM, so all system state
    // (CAMERA_X/Y, LEVEL_DATA_PTR, LEVEL_GP_COUNT, ENEMY_COUNT_ARM, PSG/NOTE engine,
    // scroll limits, …) is implicitly 0 there. On HW it must be cleared explicitly,
    // otherwise: garbage CAMERA_Y makes show_level cull every object (black screen),
    // and a garbage ENEMY_COUNT_ARM / uninitialised pointer spins the enemy and
    // collision loops on a bogus count until they fault. This is a bss-clear that
    // gives HW the same zeroed initial state the emulator gets for free. User
    // globals live at/after USER_RAM_START and are initialised explicitly below.
    s.push_str("    @ zero runtime RAM (RP2350 SRAM is not zero-initialised)\n");
    s.push_str("    ldr     r0, =TMPVAL              @ runtime RAM base\n");
    s.push_str("    ldr     r1, =USER_RAM_START      @ end of system RAM (exclusive)\n");
    s.push_str("    mov     r2, #0\n");
    s.push_str("gm_zero_loop:\n");
    s.push_str("    str     r2, [r0], #4\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    blo     gm_zero_loop\n");

    // Default drawing state. RP2350 SRAM is NOT zero-initialised, so these RAM
    // slots hold power-on garbage unless set. A program that never calls
    // SET_INTENSITY / SET_TEXT_SIZE would then draw text/numbers with a garbage
    // size/colour (invisible or wrong) — the runtime "if 0 → default" fallbacks
    // never fire because the value isn't 0, it's garbage. Give them sane defaults.
    s.push_str("    @ default drawing state (SRAM is not zero-initialised)\n");
    s.push_str("    ldr     r1, =VPY_BRIGHTNESS_OVERRIDE\n    mov     r0, #0\n    strb    r0, [r1]\n"); // 0 = use .vec/per-path intensity
    s.push_str("    ldr     r1, =TEXT_SIZE\n    mov     r0, #3\n    str     r0, [r1]\n"); // scale ×1.5

    // Initialize globals
    s.push_str("    @ initialize globals\n");
    for item in &module.items {
        match item {
            Item::GlobalLet { name, value, .. } => {
                let varname = name.to_uppercase();
                if let Some(&addr) = var_addrs.get(&varname) {
                    match value {
                        Expr::Number(n) => {
                            let mov = if *n >= 0 && *n <= 65535 {
                                format!("    mov     r0, #{n}\n")
                            } else {
                                format!("    ldr     r0, ={n}\n")
                            };
                            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n{mov}    str     r0, [r1]\n"));
                        }
                        Expr::List(elems) => {
                            let data_varname = format!("ARRAY_{varname}_DATA");
                            s.push_str(&format!("    @ init array {name}\n"));
                            s.push_str(&format!("    ldr     r2, ={data_varname}\n"));
                            // ARMv6 STRH immediate offset max = 255 bytes.
                            // For arrays > 128 halfwords, rechunk into r3 every 256 bytes.
                            let mut chunk_base: usize = 0;
                            for (i, elem) in elems.iter().enumerate() {
                                if let Expr::Number(n) = elem {
                                    let byte_off = i * 2;
                                    if byte_off > 0 && byte_off >= chunk_base + 256 {
                                        chunk_base = (byte_off / 256) * 256;
                                        s.push_str(&format!(
                                            "    ldr     r3, =({data_varname} + {chunk_base})\n"
                                        ));
                                    }
                                    let local_off = byte_off - chunk_base;
                                    let base_reg = if chunk_base > 0 { "r3" } else { "r2" };
                                    let mov = if *n >= 0 && *n <= 65535 {
                                        format!("    mov     r0, #{n}\n")
                                    } else {
                                        format!("    ldr     r0, ={n}\n")
                                    };
                                    s.push_str(&format!(
                                        "{mov}    strh    r0, [{base_reg}, #{local_off}]\n"
                                    ));
                                }
                            }
                            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    str     r2, [r1]\n"));
                        }
                        _ => {}
                    }
                }
            }
            Item::Const { name, value, .. } => {
                let varname = name.to_uppercase();
                if let Some(&addr) = var_addrs.get(&varname) {
                    match value {
                        Expr::Number(n) => {
                            let mov = if *n >= 0 && *n <= 65535 {
                                format!("    mov     r0, #{n}\n")
                            } else {
                                format!("    ldr     r0, ={n}\n")
                            };
                            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n{mov}    str     r0, [r1]\n"));
                        }
                        Expr::List(_) => {
                            // const arrays: set VAR_{varname} → ARRAY_{varname}_DATA in ROM
                            let data_label = format!("ARRAY_{varname}_DATA");
                            s.push_str(&format!("    ldr     r0, ={data_label}\n"));
                            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n"));
                            s.push_str(&format!("    str     r0, [r1]  @ const array {name} -> ROM\n"));
                        }
                        _ => {}
                    }
                }
            }
            _ => {}
        }
    }

    // Initialise PSG_MIXER_SHADOW to 0x3F (all tone+noise channels disabled)
    s.push_str("    @ init PSG_MIXER_SHADOW (all channels disabled)\n");
    s.push_str("    ldr     r1, =PSG_MIXER_SHADOW\n");
    s.push_str("    mov     r0, #0x3F\n");
    s.push_str("    str     r0, [r1]\n");

    // Zero ENEMY_COUNT_ARM — stale SRAM from a warm reset would otherwise cause
    // vpy_draw_enemies to loop over garbage pool slots before SPAWN_ENEMIES runs.
    s.push_str("    @ zero ENEMY_COUNT_ARM (guard against warm-reset SRAM)\n");
    s.push_str("    ldr     r1, =ENEMY_COUNT_ARM\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    str     r0, [r1]\n");

    let loop_labels: Vec<(String, String)> = Vec::new();

    // main() body
    if let Some(f) = main_fn {
        s.push_str("    @ main() body\n");
        for stmt in &f.body {
            // return_label="game_main_loop": `return` in main() skips to game loop
            s.push_str(&emit_stmt(stmt, var_addrs, &loop_labels, Some("game_main_loop"))?);
        }
    }

    // Game loop. Per-frame runtime updates are auto-injected ONLY for the
    // engines the program actually uses (same gating as the routine emission
    // in builtins.rs — see arm/analysis.rs).
    s.push_str("game_main_loop:\n");
    s.push_str("    bl      vpy_wait_recal\n");
    if usage.has("JOYSTICK") {
        s.push_str("    bl      vpy_update_buttons\n");
    }
    if usage.has("BEEP") {
        s.push_str("    bl      vpy_beep_update\n");
    }
    if usage.has("MUSIC") {
        s.push_str("    bl      vpy_music_update\n");
    }
    if usage.has("SFX") {
        s.push_str("    bl      vpy_audio_update\n");
    }
    if usage.has("NOTE") {
        s.push_str("    bl      vpy_note_update\n");
    }
    // Reset the brightness override each frame so draws without a SET_INTENSITY
    // fall back to their .vec per-path intensities. SET_INTENSITY re-applies it
    // and it only persists for the frame it is issued (mirrors PiTrex).
    s.push_str("    ldr     r0, =VPY_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    strb    r1, [r0]\n");
    if let Some(f) = loop_fn {
        for stmt in &f.body {
            // return_label="game_main_loop": `return` in loop() jumps to next frame
            s.push_str(&emit_stmt(stmt, var_addrs, &loop_labels, Some("game_main_loop"))?);
        }
    }
    s.push_str("    b       game_main_loop\n");
    s.push_str("    .ltorg\n\n");

    Ok(s)
}

fn emit_binop_on_regs(op: &BinOp, s: &mut String) -> Result<(), String> {
    // r0 = left, r1 = right → r0 = result
    match op {
        BinOp::Add => s.push_str("    add     r0, r0, r1\n"),
        BinOp::Sub => s.push_str("    sub     r0, r0, r1\n"),
        BinOp::Mul => s.push_str("    mul     r0, r0, r1\n"),
        BinOp::Div | BinOp::FloorDiv => s.push_str("    sdiv    r0, r0, r1\n"),
        BinOp::Mod => {
            s.push_str("    sdiv    r2, r0, r1\n");
            s.push_str("    mul     r2, r2, r1\n");
            s.push_str("    sub     r0, r0, r2\n");
        }
        BinOp::BitAnd => s.push_str("    and     r0, r0, r1\n"),
        BinOp::BitOr  => s.push_str("    orr     r0, r0, r1\n"),
        BinOp::BitXor => s.push_str("    eor     r0, r0, r1\n"),
        BinOp::Shl => s.push_str("    lsl     r0, r0, r1\n"),
        BinOp::Shr => s.push_str("    asr     r0, r0, r1\n"),
    }
    Ok(())
}

/// Emit code to load element at arr[index] into r0 (sign-extended 16-bit).
/// Leaves element address in r1 as a side-effect (used by compound index assign).
fn emit_index_load(target: &Expr, index: &Expr, var_addrs: &HashMap<String, u32>, s: &mut String) -> Result<(), String> {
    s.push_str(&emit_expr(target, var_addrs)?);  // base ptr in r0
    s.push_str("    push    {r0}           @ save base ptr\n");
    s.push_str(&emit_expr(index, var_addrs)?);   // index in r0
    s.push_str("    lsl     r0, r0, #1     @ index * 2 (16-bit elements)\n");
    s.push_str("    pop     {r1}           @ base ptr\n");
    s.push_str("    add     r1, r1, r0     @ element addr\n");
    s.push_str("    ldrh    r0, [r1]       @ load 16-bit element\n");
    s.push_str("    sxth    r0, r0         @ sign-extend\n");
    Ok(())
}

fn emit_stmt(
    stmt: &Stmt,
    var_addrs: &HashMap<String, u32>,
    loop_labels: &[(String, String)],  // stack of (break_label, continue_label)
    return_label: Option<&str>,        // when Some(lbl), `return` branches to lbl instead of popping
) -> Result<String, String> {
    match stmt {
        Stmt::Assign { target, value, .. } => {
            let mut s = emit_expr(value, var_addrs)?;
            match target {
                AssignTarget::Ident { name, .. } => {
                    let varname = name.to_uppercase();
                    if let Some(&addr) = var_addrs.get(&varname) {
                        s.push_str(&format!(
                            "    ldr     r1, =0x{addr:08X}    @ {name}\n    str     r0, [r1]\n"
                        ));
                    } else {
                        return Err(format!("Unknown variable: {name}"));
                    }
                }
                AssignTarget::Index { target, index, .. } => {
                    // r0 = value; now compute element address
                    s.push_str("    push    {r0}           @ save value\n");
                    s.push_str(&emit_expr(target, var_addrs)?);
                    s.push_str("    push    {r0}           @ save base ptr\n");
                    s.push_str(&emit_expr(index, var_addrs)?);
                    s.push_str("    lsl     r0, r0, #1     @ index * 2 (16-bit elements)\n");
                    s.push_str("    pop     {r1}           @ base ptr\n");
                    s.push_str("    add     r1, r1, r0     @ element addr\n");
                    s.push_str("    pop     {r0}           @ value\n");
                    s.push_str("    strh    r0, [r1]       @ store 16-bit\n");
                }
                other => return Err(format!("Unsupported assign target: {:?}", other)),
            }
            Ok(s)
        }

        Stmt::Let { name, value, .. } => {
            let mut s = emit_expr(value, var_addrs)?;
            let varname = name.to_uppercase();
            if let Some(&addr) = var_addrs.get(&varname) {
                s.push_str(&format!(
                    "    ldr     r1, =0x{addr:08X}\n    str     r0, [r1]\n"
                ));
            }
            Ok(s)
        }

        Stmt::CompoundAssign { target, op, value, .. } => {
            let mut s = String::new();
            match target {
                AssignTarget::Ident { name, .. } => {
                    let varname = name.to_uppercase();
                    if let Some(&addr) = var_addrs.get(&varname) {
                        s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    ldr     r0, [r1]\n"));
                        s.push_str("    push    {r0}       @ left operand\n");
                        s.push_str(&emit_expr(value, var_addrs)?);
                        s.push_str("    mov     r1, r0\n");
                        s.push_str("    pop     {r0}\n");
                        emit_binop_on_regs(op, &mut s)?;
                        s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    str     r0, [r1]\n"));
                    } else {
                        return Err(format!("Unknown variable: {name}"));
                    }
                }
                AssignTarget::Index { target, index, .. } => {
                    // Load current element value
                    emit_index_load(target, index, var_addrs, &mut s)?;
                    // r0 = current value, r1 = element addr
                    s.push_str("    push    {r1}       @ save element addr\n");
                    s.push_str("    push    {r0}       @ left operand\n");
                    s.push_str(&emit_expr(value, var_addrs)?);
                    s.push_str("    mov     r1, r0\n");
                    s.push_str("    pop     {r0}\n");
                    emit_binop_on_regs(op, &mut s)?;
                    s.push_str("    pop     {r1}       @ element addr\n");
                    s.push_str("    strh    r0, [r1]   @ store result\n");
                }
                other => return Err(format!("Unsupported compound assign target: {:?}", other)),
            }
            Ok(s)
        }

        Stmt::Expr(expr, _) => {
            // MSG_DEF(id, x, y, "text") is a compile-time declaration — its data
            // is baked into PRINT_MSG_TABLE by collect_msg_entries / emit_msg_builtins.
            // At runtime it is a complete no-op: suppress ALL code generation for it.
            if let Expr::Call(info) = expr {
                if info.name.to_uppercase() == "MSG_DEF" {
                    return Ok(String::new());
                }
            }
            emit_expr(expr, var_addrs)
        }

        Stmt::If { cond, body, elifs, else_body, .. } => {
            let id = next_id();
            let mut s = String::new();
            s.push_str(&emit_expr(cond, var_addrs)?);
            s.push_str("    cmp     r0, #0\n");
            s.push_str(&format!("    beq     if_else_{id}\n"));
            for st in body { s.push_str(&emit_stmt(st, var_addrs, loop_labels, return_label)?); }
            s.push_str(&format!("    b       if_end_{id}\n"));
            s.push_str(&format!("if_else_{id}:\n"));

            for (elif_cond, elif_body) in elifs {
                let eid = next_id();
                s.push_str(&emit_expr(elif_cond, var_addrs)?);
                s.push_str("    cmp     r0, #0\n");
                s.push_str(&format!("    beq     elif_end_{eid}\n"));
                for st in elif_body { s.push_str(&emit_stmt(st, var_addrs, loop_labels, return_label)?); }
                s.push_str(&format!("    b       if_end_{id}\n"));
                s.push_str(&format!("elif_end_{eid}:\n"));
            }

            if let Some(else_stmts) = else_body {
                for st in else_stmts { s.push_str(&emit_stmt(st, var_addrs, loop_labels, return_label)?); }
            }
            s.push_str(&format!("if_end_{id}:\n"));
            Ok(s)
        }

        Stmt::While { cond, body, .. } => {
            let id = next_id();
            let break_lbl    = format!("while_end_{id}");
            let continue_lbl = format!("while_top_{id}");
            let mut inner_labels = loop_labels.to_vec();
            inner_labels.push((break_lbl.clone(), continue_lbl.clone()));

            let mut s = String::new();
            s.push_str(&format!("while_top_{id}:\n"));
            s.push_str(&emit_expr(cond, var_addrs)?);
            s.push_str("    cmp     r0, #0\n");
            s.push_str(&format!("    beq     while_end_{id}\n"));
            for st in body { s.push_str(&emit_stmt(st, var_addrs, &inner_labels, return_label)?); }
            s.push_str(&format!("    b       while_top_{id}\n"));
            s.push_str(&format!("while_end_{id}:\n"));
            Ok(s)
        }

        Stmt::For { var, start, end, step, body, .. } => {
            let id = next_id();
            let varname = var.to_uppercase();
            let addr = var_addrs.get(&varname).copied().unwrap_or(0);
            // continue jumps to the increment step, not the top (where the condition check is)
            let break_lbl    = format!("for_end_{id}");
            let continue_lbl = format!("for_inc_{id}");
            let mut inner_labels = loop_labels.to_vec();
            inner_labels.push((break_lbl.clone(), continue_lbl.clone()));
            let mut s = String::new();

            // init: var = start
            s.push_str(&emit_expr(start, var_addrs)?);
            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    str     r0, [r1]\n"));

            s.push_str(&format!("for_top_{id}:\n"));
            // condition: var < end
            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    ldr     r0, [r1]\n"));
            s.push_str("    push    {r0}\n");
            s.push_str(&emit_expr(end, var_addrs)?);
            s.push_str("    mov     r1, r0\n    pop     {r0}\n");
            s.push_str("    cmp     r0, r1\n");
            s.push_str(&format!("    bge     for_end_{id}\n"));

            for st in body { s.push_str(&emit_stmt(st, var_addrs, &inner_labels, return_label)?); }

            // increment — continue target
            s.push_str(&format!("for_inc_{id}:\n"));
            let step_val = step.as_ref().map(|e| {
                if let Expr::Number(n) = e { *n } else { 1 }
            }).unwrap_or(1);
            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    ldr     r0, [r1]\n"));
            s.push_str(&format!("    add     r0, r0, #{step_val}\n"));
            s.push_str(&format!("    str     r0, [r1]\n"));
            s.push_str(&format!("    b       for_top_{id}\n"));
            s.push_str(&format!("for_end_{id}:\n"));
            Ok(s)
        }

        Stmt::Return(Some(expr), _) => {
            let mut s = emit_expr(expr, var_addrs)?;
            if let Some(lbl) = return_label {
                s.push_str(&format!("    b       {lbl}\n"));
            } else {
                s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
            }
            Ok(s)
        }

        Stmt::Return(None, _) => {
            if let Some(lbl) = return_label {
                Ok(format!("    b       {lbl}\n"))
            } else {
                Ok("    pop     {r4, r5, r6, r7, pc}\n".to_string())
            }
        }

        Stmt::Break { .. } => {
            if let Some((break_lbl, _)) = loop_labels.last() {
                Ok(format!("    b       {break_lbl}\n"))
            } else {
                Err("break outside of loop".to_string())
            }
        }

        Stmt::Continue { .. } => {
            if let Some((_, continue_lbl)) = loop_labels.last() {
                Ok(format!("    b       {continue_lbl}\n"))
            } else {
                Err("continue outside of loop".to_string())
            }
        }

        Stmt::Pass { .. } => Ok(String::new()),

        Stmt::ForIn { var, iterable, body, source_line, .. } => {
            let id = next_id();
            let varname    = var.to_uppercase();
            let ctr_name   = format!("_fi_{source_line}").to_uppercase();
            let base_name  = format!("_fi_{source_line}_base").to_uppercase();
            let len_name   = format!("_fi_{source_line}_len").to_uppercase();

            let var_addr  = var_addrs.get(&varname).copied()
                .ok_or_else(|| format!("ForIn var {var} not allocated"))?;
            let ctr_addr  = var_addrs.get(&ctr_name).copied()
                .ok_or_else(|| format!("ForIn counter {ctr_name} not allocated"))?;
            let base_addr = var_addrs.get(&base_name).copied()
                .ok_or_else(|| format!("ForIn base {base_name} not allocated"))?;
            let len_addr  = var_addrs.get(&len_name).copied()
                .ok_or_else(|| format!("ForIn len {len_name} not allocated"))?;

            let break_lbl    = format!("forin_end_{id}");
            let continue_lbl = format!("forin_inc_{id}");
            let mut inner_labels = loop_labels.to_vec();
            inner_labels.push((break_lbl.clone(), continue_lbl.clone()));

            let mut s = String::new();

            // Evaluate array base pointer, save to RAM
            s.push_str(&emit_expr(iterable, var_addrs)?);
            s.push_str(&format!("    ldr     r1, =0x{base_addr:08X}\n    str     r0, [r1]    @ forin base ptr\n"));

            // Array length — compile-time constant via ARRAY_NAME_LEN equate
            let len_asm = if let Expr::Ident(id_info) = iterable {
                format!("    ldr     r0, =ARRAY_{}_LEN\n", id_info.name.to_uppercase())
            } else {
                "    mov     r0, #0             @ unknown array len\n".to_string()
            };
            s.push_str(&len_asm);
            s.push_str(&format!("    ldr     r1, =0x{len_addr:08X}\n    str     r0, [r1]    @ forin len\n"));

            // Init counter = 0
            s.push_str("    mov     r0, #0\n");
            s.push_str(&format!("    ldr     r1, =0x{ctr_addr:08X}\n    str     r0, [r1]\n"));

            s.push_str(&format!("forin_top_{id}:\n"));
            // Condition: ctr < len
            s.push_str(&format!("    ldr     r1, =0x{ctr_addr:08X}\n    ldr     r0, [r1]\n"));
            s.push_str(&format!("    ldr     r1, =0x{len_addr:08X}\n    ldr     r1, [r1]\n"));
            s.push_str("    cmp     r0, r1\n");
            s.push_str(&format!("    bge     forin_end_{id}\n"));

            // Load element: var = base_ptr[ctr * 2]  (i16 elements)
            s.push_str(&format!("    ldr     r1, =0x{base_addr:08X}\n    ldr     r1, [r1]\n"));
            s.push_str(&format!("    ldr     r2, =0x{ctr_addr:08X}\n    ldr     r2, [r2]\n"));
            s.push_str("    lsl     r2, r2, #1     @ ctr * 2\n");
            s.push_str("    add     r1, r1, r2\n");
            s.push_str("    ldrsh   r0, [r1]       @ load i16 element\n");
            s.push_str(&format!("    ldr     r1, =0x{var_addr:08X}\n    str     r0, [r1]    @ var = arr[ctr]\n"));

            for st in body { s.push_str(&emit_stmt(st, var_addrs, &inner_labels, return_label)?); }

            // Continue target: increment counter
            s.push_str(&format!("forin_inc_{id}:\n"));
            s.push_str(&format!("    ldr     r1, =0x{ctr_addr:08X}\n    ldr     r0, [r1]\n"));
            s.push_str("    add     r0, r0, #1\n");
            s.push_str("    str     r0, [r1]\n");
            s.push_str(&format!("    b       forin_top_{id}\n"));
            s.push_str(&format!("forin_end_{id}:\n"));
            Ok(s)
        }

        Stmt::Switch { expr, cases, default, .. } => {
            let id = next_id();
            let end_lbl = format!("switch_end_{id}");
            let mut s = String::new();

            // Evaluate switch expression once, save to RAM scratch via r4 (callee-saved)
            // We can't use stack due to break/continue stack-discipline issues.
            // Use a push-pop bracket since callee-saved r4 is already in use.
            // Instead, emit expr into r4 temporarily (save/restore around body is handled
            // by the function prologue/epilogue).  Use a stack push for simplicity — switch
            // does not contain loops so break/continue don't need to pop the stack here.
            // Actually: switch bodies CAN contain break (which jumps to switch_end).
            // So we can't rely on stack at switch_end unless we emit a cleanup there.
            // Solution: push {r0, r1} (8 bytes, aligned) at entry; emit cleanup at each
            // break target and at the end label.  Instead, simplest: save to r4 (available
            // since emit_function saves r4-r7 at entry and we're inside a function).
            //
            // r4 is callee-saved but may be in use by the outer function body. Use the
            // stack approach with an explicit cleanup label that break jumps to.
            // --- Use stack approach, add cleanup label before end_lbl ---
            let cleanup_lbl = format!("switch_cleanup_{id}");

            s.push_str(&emit_expr(expr, var_addrs)?);
            s.push_str("    push    {r0, r1}       @ switch value (r1=pad, 8-byte align)\n");

            for (ci, (case_val, case_body)) in cases.iter().enumerate() {
                let no_match_lbl = format!("switch_next_{ci}_{id}");
                s.push_str(&emit_expr(case_val, var_addrs)?);
                s.push_str("    mov     r1, r0\n");
                s.push_str("    ldr     r0, [sp, #0]   @ reload switch value\n");
                s.push_str("    cmp     r0, r1\n");
                s.push_str(&format!("    bne     {no_match_lbl}\n"));
                for st in case_body { s.push_str(&emit_stmt(st, var_addrs, loop_labels, return_label)?); }
                s.push_str(&format!("    b       {cleanup_lbl}\n"));
                s.push_str(&format!("{no_match_lbl}:\n"));
            }

            if let Some(default_body) = default {
                for st in default_body { s.push_str(&emit_stmt(st, var_addrs, loop_labels, return_label)?); }
            }

            s.push_str(&format!("{cleanup_lbl}:\n"));
            s.push_str("    add     sp, sp, #8     @ pop switch value\n");
            s.push_str(&format!("{end_lbl}:\n"));
            Ok(s)
        }

    }
}
