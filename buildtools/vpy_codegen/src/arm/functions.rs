//! ARM Thumb2 function code generation.

use vpy_parser::{Module, Item, Stmt, Expr, AssignTarget, BinOp};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use super::ram_layout::RamAllocator;
use super::expressions::emit_expr;
use super::frame::{self, Scope};
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

    // Parameters and locals of every function (m6809's name-resolution rules,
    // shared): they live in stack frames, globals at fixed addresses.
    let scopes = crate::m6809::frames::function_scopes(module)?;
    super::arrays::setup(module)?;
    let (var_addrs, var_decls, scalar_consts) = allocate_globals(module)?;

    // Register scalar consts so expression codegen folds their reads to
    // immediates (no RAM slot, no startup init emitted for them).
    super::expressions::set_scalar_consts(scalar_consts);

    s.push_str("@ --- User variables (RAM) ---\n");
    s.push_str(&var_decls);
    s.push('\n');

    // Emit const array ROM data tables (before user functions so they land in bank 0).
    // Tables of the declared element type (.byte/.hword/.word), pointed to by
    // VAR_{name} at startup.
    // The runtime above still has literals pending: flush them here, or a long table (string
    // tables are kilobytes) pushes them out of the runtime's `ldr =` reach.
    s.push_str("@ --- Const array ROM data ---\n");
    s.push_str(".ltorg\n");
    for item in &module.items {
        if let Item::Const { name, value, .. } = item {
            if let Expr::List(elems) = value {
                let varname = name.to_uppercase();
                let directive = super::arrays::directive(super::arrays::of_global(name));
                s.push_str(".align 2\n");
                s.push_str(&format!("ARRAY_{varname}_DATA:\n"));
                if elems.iter().all(|e| matches!(e, Expr::StringLit(_))) {
                    // a table of strings: their addresses, then the NUL-terminated texts
                    for i in 0..elems.len() {
                        s.push_str(&format!("    .word   .L{varname}_STR{i}\n"));
                    }
                    for (i, elem) in elems.iter().enumerate() {
                        if let Expr::StringLit(text) = elem {
                            s.push_str(&format!(".L{varname}_STR{i}:\n    .asciz  \"{text}\"\n"));
                        }
                    }
                    s.push_str(".align 2\n");
                    continue;
                }
                for elem in elems {
                    if let Expr::Number(n) = elem {
                        s.push_str(&format!("    {directive} {n}\n"));
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
            s.push_str(&emit_function(func, &Scope::of(func, &scopes), &var_addrs)
                .map_err(|e| crate::origins::locate_for(&func.name, &e))?);
        }
    }

    s.push_str(&emit_game_main(module, &scopes, &var_addrs, usage)
        .map_err(|e| crate::origins::locate_for("MAIN", &e))?);

    Ok(s)
}

fn allocate_globals(module: &Module) -> Result<(HashMap<String, u32>, String, HashMap<String, i32>), String> {
    let mut alloc = RamAllocator::new();
    let mut addrs: HashMap<String, u32> = HashMap::new();
    let mut decls = String::new();
    // Scalar int consts fold to immediates — collected here, not RAM-backed.
    let mut scalar_consts: HashMap<String, i32> = HashMap::new();

    for item in &module.items {
        match item {
            Item::GlobalLet { name, value, .. } => {
                let varname = name.to_uppercase();
                match value {
                    Expr::List(elems) => {
                        let len = elems.len();
                        let elem_bytes = super::arrays::of_global(name).bytes;
                        let data_size = ((len * elem_bytes) as u32 + 3) & !3;
                        let data_addr = alloc.alloc_data(data_size)?;
                        let ptr_addr  = alloc.alloc(4)?;
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
                        let addr = alloc.alloc(4)?;
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
                        let ptr_addr = alloc.alloc(4)?;
                        decls.push_str(&format!(
                            ".equ ARRAY_{varname}_LEN, {len}\n"
                        ));
                        decls.push_str(&format!(
                            ".equ VAR_{varname}, 0x{ptr_addr:08X}  @ const array pointer\n"
                        ));
                        addrs.insert(varname, ptr_addr);
                    }
                    Expr::Number(n) => {
                        // Scalar int const: fold reads to immediates. No RAM slot
                        // and no startup init — the value lives only in the fold table.
                        scalar_consts.insert(varname, *n);
                    }
                    _ => {
                        // Non-literal scalar const: allocate RAM so reads work via
                        // var_addrs. Value is initialized in game_main startup.
                        let addr = alloc.alloc(4)?;
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

    Ok((addrs, decls, scalar_consts))
}

/// Registers every user function and game_main push (20 bytes; the frame pads to 8).
const PUSH: &str = "push    {r4, r5, r6, r7, lr}";
const POP: &str = "pop     {r4, r5, r6, r7, pc}";
const PUSHED: u32 = 20;

fn emit_function(
    func: &vpy_parser::Function,
    scope: &Scope,
    var_addrs: &HashMap<String, u32>,
) -> Result<String, String> {
    // Use original-case name as the ARM label (ARM assembly is case-sensitive).
    // Call sites emit `bl name` and the definition emits `name:` — they must match.
    let name = &func.name;
    let layout = frame::layout(&[scope], PUSHED, name)?.remove(0);
    let ret_label = format!(".Lret_{name}");
    let mut s = String::new();
    s.push_str(&format!("@ --- function {name} ---\n"));
    s.push_str(".align 2\n");  // ensure 2-byte alignment after preceding .ltorg padding
    s.push_str(&format!(".global {name}\n.type {name}, %function\n.thumb_func\n{name}:\n"));
    s.push_str(&format!("    {PUSH}\n"));
    super::arrays::enter_function(name, &func.params);
    // Frame: parameters (r0-r3, then the caller's stack arguments) and locals.
    s.push_str(&frame::prologue(&layout, &func.params, PUSHED, false));

    frame::enter(&layout);
    super::pool::reset();
    let loop_labels: Vec<(String, String)> = Vec::new();
    let mut body = String::new();
    for stmt in &func.body {
        match emit_stmt(stmt, var_addrs, &loop_labels, &ret_label) {
            Ok(code) => body.push_str(&code),
            Err(e) => {
                frame::leave();
                return Err(e);
            }
        }
    }
    frame::leave();
    s.push_str(&body);
    s.push_str(&frame::epilogue(&ret_label, &layout, POP, false));
    s.push_str("    .ltorg\n\n");
    Ok(s)
}

fn emit_game_main(
    module: &Module,
    scopes: &std::collections::BTreeMap<String, crate::m6809::frames::Frame>,
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
    s.push_str(&format!("    {PUSH}\n"));
    // One frame holds the locals of main() and, in other slots, those of loop():
    // they persist across frames like every other variable of the game.
    let main_scope = main_fn.map(|f| Scope::of(f, scopes)).unwrap_or_default();
    let loop_scope = loop_fn.map(|f| Scope::of(f, scopes)).unwrap_or_default();
    let layouts = frame::layout(&[&main_scope, &loop_scope], PUSHED, "game_main")?;
    super::arrays::enter_function("", &[]);
    s.push_str(&frame::prologue(&layouts[0], &[], PUSHED, false));
    super::pool::reset();

    // Zero the VPy runtime RAM region [TMPVAL .. USER_RAM_START). RP2350 SRAM holds
    // power-on garbage; the emulator runs with zeroed SRAM, so all system state
    // (CAMERA_X/Y, LEVEL_DATA_PTR, LEVEL_GP_COUNT, ENEMY_COUNT_ARM, PSG/NOTE engine,
    // scroll limits, …) is implicitly 0 there. On HW it must be cleared explicitly,
    // otherwise: garbage CAMERA_Y makes show_level cull every object (black screen),
    // and a garbage ENEMY_COUNT_ARM / uninitialised pointer spins the enemy and
    // collision loops on a bogus count until they fault. This is a bss-clear that
    // gives HW the same zeroed initial state the emulator gets for free. User
    // globals live at/after USER_RAM_START and are initialised explicitly below.
    // r6 holds the globals' base for the whole program (callee-saved: every function keeps
    // it), so the peephole turns a global's `ldr r1, =ADDR; ldr r0, [r1]` into one load
    s.push_str(&format!("    ldr     r6, =0x{:08X}    {}\n", super::GLOBALS_BASE, super::GLOBALS_BASE_MARK));
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
    // Resolve numeric consts so a global initialized from one (e.g.
    // `state: i16 = STATE_TITLE`) gets initialized too — otherwise it was silently
    // skipped and left as uninitialized RAM (garbage on a cold boot → wrong state
    // → black screen; only "worked" after another game seeded that RAM address).
    let const_vals: std::collections::HashMap<String, i32> = module
        .items
        .iter()
        .filter_map(|it| match it {
            Item::Const { name, value: Expr::Number(n), .. } => Some((name.to_uppercase(), *n)),
            _ => None,
        })
        .collect();
    for item in &module.items {
        let before = s.len();
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
                            let elem = super::arrays::of_global(name);
                            let store = super::arrays::store(elem);
                            s.push_str(&format!("    @ init array {name}\n"));
                            s.push_str(&format!("    ldr     r2, ={data_varname}\n"));
                            // Every element the same (`[0] * 168`, `[-1, -1]`): a store loop,
                            // not a mov+str per element (8 bytes of code each).
                            let first = match elems.first() { Some(Expr::Number(n)) => Some(*n), _ => None };
                            if let Some(v) = first.filter(|v| elems.len() >= 4 && elems.iter().all(|e| matches!(e, Expr::Number(n) if n == v))) {
                                let mov = if (0..=255).contains(&v) { format!("    mov     r0, #{v}\n") } else { format!("    ldr     r0, ={v}\n") };
                                s.push_str(&mov);
                                s.push_str(&format!("    ldr     r3, =({data_varname} + {})\n", elems.len() * elem.bytes));
                                s.push_str(&format!(".Lainit_{varname}:\n"));
                                s.push_str(&format!("    {store}   r0, [r2], #{}\n", elem.bytes));
                                s.push_str("    cmp     r2, r3\n");
                                s.push_str(&format!("    blo     .Lainit_{varname}\n"));
                                s.push_str(&format!("    ldr     r2, ={data_varname}\n"));
                                s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    str     r2, [r1]\n"));
                                let mut chunk = s.split_off(before);
                                super::pool::after(&mut chunk);
                                s.push_str(&chunk);
                                continue;
                            }
                            // ARMv6 STRH immediate offset max = 255 bytes.
                            // For arrays > 255 bytes, rechunk into r3 every 256 bytes.
                            let mut chunk_base: usize = 0;
                            for (i, e) in elems.iter().enumerate() {
                                if let Expr::Number(n) = e {
                                    let byte_off = i * elem.bytes;
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
                                        "{mov}    {store}   r0, [{base_reg}, #{local_off}]\n"
                                    ));
                                }
                            }
                            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    str     r2, [r1]\n"));
                        }
                        Expr::Ident(info) => {
                            // Global initialized from a numeric const, e.g.
                            // `state: i16 = STATE_TITLE`. Resolve and emit it.
                            if let Some(&n) = const_vals.get(&info.name.to_uppercase()) {
                                let mov = if (0..=65535).contains(&n) {
                                    format!("    mov     r0, #{n}\n")
                                } else {
                                    format!("    ldr     r0, ={n}\n")
                                };
                                s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n{mov}    str     r0, [r1]\n"));
                            }
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
        let mut chunk = s.split_off(before);
        super::pool::after(&mut chunk);
        s.push_str(&chunk);
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
        frame::enter(&layouts[0]);
        // `return` in main() skips to the game loop
        let body = emit_body(&f.body, var_addrs, &loop_labels, "game_main_loop");
        frame::leave();
        s.push_str(&body?);
    }

    // Game loop. Per-frame runtime updates are auto-injected ONLY for the
    // engines the program actually uses (same gating as the routine emission
    // in builtins.rs — see arm/analysis.rs).
    s.push_str("game_main_loop:\n");
    // Drop anything a `return` from inside a switch left on the stack.
    s.push_str("    mov     sp, r7\n");
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
    // The jukebox (uvm2): a slice more of the card, and the jack topped up. sp = r7 here,
    // 8-byte aligned, as the C call needs.
    if super::three_d::uses_jukebox(module) {
        s.push_str("    bl      vpyj_frame\n");
    }
    // Reset the brightness override each frame so draws without a SET_INTENSITY
    // fall back to their .vec per-path intensities. SET_INTENSITY re-applies it
    // and it only persists for the frame it is issued (mirrors PiTrex).
    s.push_str("    ldr     r0, =VPY_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    strb    r1, [r0]\n");
    if let Some(f) = loop_fn {
        frame::enter(&layouts[1]);
        // `return` in loop() jumps to the next frame
        let body = emit_body(&f.body, var_addrs, &loop_labels, "game_main_loop");
        frame::leave();
        s.push_str(&body?);
    }
    s.push_str("    b       game_main_loop\n");
    s.push_str("    .ltorg\n\n");

    Ok(s)
}

/// The statements of a body, in order.
fn emit_body(
    stmts: &[Stmt],
    var_addrs: &HashMap<String, u32>,
    loop_labels: &[(String, String)],
    return_label: &str,
) -> Result<String, String> {
    let mut s = String::new();
    for stmt in stmts {
        s.push_str(&emit_stmt(stmt, var_addrs, loop_labels, return_label)?);
    }
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

/// Emit code to load element at arr[index] into r0 (extended by the element type).
/// Leaves element address in r1 as a side-effect (used by compound index assign).
fn emit_index_load(target: &Expr, index: &Expr, var_addrs: &HashMap<String, u32>, s: &mut String) -> Result<(), String> {
    let elem = super::arrays::of(target);
    s.push_str(&emit_expr(target, var_addrs)?);  // base ptr in r0
    s.push_str("    push    {r0}           @ save base ptr\n");
    s.push_str(&emit_expr(index, var_addrs)?);   // index in r0
    s.push_str(&super::arrays::scale("r0", elem));
    s.push_str("    pop     {r1}           @ base ptr\n");
    s.push_str("    add     r1, r1, r0     @ element addr\n");
    s.push_str(&format!("    {}   r0, [r1]       @ load {} element\n", super::arrays::load(elem), elem.type_name()));
    Ok(())
}

/// One statement's code, followed by a literal-pool island when one is due.
fn emit_stmt(
    stmt: &Stmt,
    var_addrs: &HashMap<String, u32>,
    loop_labels: &[(String, String)],
    return_label: &str,
) -> Result<String, String> {
    let mut code = emit_stmt_code(stmt, var_addrs, loop_labels, return_label)?;
    super::pool::after(&mut code);
    Ok(code)
}

fn emit_stmt_code(
    stmt: &Stmt,
    var_addrs: &HashMap<String, u32>,
    loop_labels: &[(String, String)],  // stack of (break_label, continue_label)
    return_label: &str,                // `return` branches here (function epilogue / next frame)
) -> Result<String, String> {
    match stmt {
        Stmt::Assign { target, value, .. } => {
            let mut s = emit_expr(value, var_addrs)?;
            match target {
                AssignTarget::Ident { name, .. } => {
                    s.push_str(&frame::store_r0(name, var_addrs)?);
                }
                AssignTarget::Index { target, index, .. } => {
                    // r0 = value; now compute element address
                    let elem = super::arrays::of(target);
                    s.push_str("    push    {r0}           @ save value\n");
                    s.push_str(&emit_expr(target, var_addrs)?);
                    s.push_str("    push    {r0}           @ save base ptr\n");
                    s.push_str(&emit_expr(index, var_addrs)?);
                    s.push_str(&super::arrays::scale("r0", elem));
                    s.push_str("    pop     {r1}           @ base ptr\n");
                    s.push_str("    add     r1, r1, r0     @ element addr\n");
                    s.push_str("    pop     {r0}           @ value\n");
                    s.push_str(&format!("    {}   r0, [r1]       @ store {}\n", super::arrays::store(elem), elem.type_name()));
                }
                other => return Err(format!("Unsupported assign target: {:?}", other)),
            }
            Ok(s)
        }

        Stmt::Let { name, value, .. } => {
            let mut s = emit_expr(value, var_addrs)?;
            s.push_str(&frame::store_r0(name, var_addrs)?);
            Ok(s)
        }

        Stmt::CompoundAssign { target, op, value, .. } => {
            let mut s = String::new();
            match target {
                AssignTarget::Ident { name, .. } => {
                    s.push_str(&frame::load_r0(name, var_addrs)?);
                    s.push_str("    push    {r0}       @ left operand\n");
                    s.push_str(&emit_expr(value, var_addrs)?);
                    s.push_str("    mov     r1, r0\n");
                    s.push_str("    pop     {r0}\n");
                    emit_binop_on_regs(op, &mut s)?;
                    s.push_str(&frame::store_r0(name, var_addrs)?);
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
                    s.push_str(&format!("    {}   r0, [r1]   @ store result\n", super::arrays::store(super::arrays::of(target))));
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
            // continue jumps to the increment step, not the top (where the condition check is)
            let break_lbl    = format!("for_end_{id}");
            let continue_lbl = format!("for_inc_{id}");
            let mut inner_labels = loop_labels.to_vec();
            inner_labels.push((break_lbl.clone(), continue_lbl.clone()));
            let mut s = String::new();

            // init: var = start
            s.push_str(&emit_expr(start, var_addrs)?);
            s.push_str(&frame::store_r0(var, var_addrs)?);

            s.push_str(&format!("for_top_{id}:\n"));
            // condition: var < end
            s.push_str(&frame::load_r0(var, var_addrs)?);
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
            s.push_str(&frame::load_r0(var, var_addrs)?);
            s.push_str(&format!("    add     r0, r0, #{step_val}\n"));
            s.push_str(&frame::store_r0(var, var_addrs)?);
            s.push_str(&format!("    b       for_top_{id}\n"));
            s.push_str(&format!("for_end_{id}:\n"));
            Ok(s)
        }

        Stmt::Return(Some(expr), _) => {
            let mut s = emit_expr(expr, var_addrs)?;
            s.push_str(&format!("    b       {return_label}\n"));
            Ok(s)
        }

        Stmt::Return(None, _) => Ok(format!("    b       {return_label}\n")),

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
            // Counter, base pointer and length are hidden locals of the frame.
            let hidden = |name: String| {
                frame::slot(&name).ok_or_else(|| format!("for-in slot {name} not in the frame"))
            };
            let ctr  = hidden(frame::for_in_counter(*source_line))?;
            let base = hidden(frame::for_in_base(*source_line))?;
            let len  = hidden(frame::for_in_len(*source_line))?;
            let fp = frame::FP;

            let break_lbl    = format!("forin_end_{id}");
            let continue_lbl = format!("forin_inc_{id}");
            let mut inner_labels = loop_labels.to_vec();
            inner_labels.push((break_lbl.clone(), continue_lbl.clone()));

            let mut s = String::new();

            // Evaluate array base pointer, save it in the frame
            s.push_str(&emit_expr(iterable, var_addrs)?);
            s.push_str(&format!("    str     r0, [{fp}, #{base}]    @ forin base ptr\n"));

            // Array length — compile-time constant via ARRAY_NAME_LEN equate
            let len_asm = if let Expr::Ident(id_info) = iterable {
                format!("    ldr     r0, =ARRAY_{}_LEN\n", id_info.name.to_uppercase())
            } else {
                "    mov     r0, #0             @ unknown array len\n".to_string()
            };
            s.push_str(&len_asm);
            s.push_str(&format!("    str     r0, [{fp}, #{len}]    @ forin len\n"));

            // Init counter = 0
            s.push_str("    mov     r0, #0\n");
            s.push_str(&format!("    str     r0, [{fp}, #{ctr}]    @ forin counter\n"));

            s.push_str(&format!("forin_top_{id}:\n"));
            // Condition: ctr < len
            s.push_str(&format!("    ldr     r0, [{fp}, #{ctr}]\n"));
            s.push_str(&format!("    ldr     r1, [{fp}, #{len}]\n"));
            s.push_str("    cmp     r0, r1\n");
            s.push_str(&format!("    bge     forin_end_{id}\n"));

            // Load element: var = base_ptr[ctr]  (the array's element type)
            let elem = super::arrays::of(iterable);
            s.push_str(&format!("    ldr     r1, [{fp}, #{base}]\n"));
            s.push_str(&format!("    ldr     r2, [{fp}, #{ctr}]\n"));
            s.push_str(&super::arrays::scale("r2", elem));
            s.push_str("    add     r1, r1, r2\n");
            s.push_str(&format!("    {}   r0, [r1]       @ load {} element\n", super::arrays::load(elem), elem.type_name()));
            s.push_str(&frame::store_r0(var, var_addrs)?);

            for st in body { s.push_str(&emit_stmt(st, var_addrs, &inner_labels, return_label)?); }

            // Continue target: increment counter
            s.push_str(&format!("forin_inc_{id}:\n"));
            s.push_str(&format!("    ldr     r0, [{fp}, #{ctr}]\n"));
            s.push_str("    add     r0, r0, #1\n");
            s.push_str(&format!("    str     r0, [{fp}, #{ctr}]\n"));
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
