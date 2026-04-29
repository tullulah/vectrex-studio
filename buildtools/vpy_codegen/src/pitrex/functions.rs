//! PiTrex ARM32 function and game-loop code generation.
//!
//! Key differences from the ARM/RP2350 backend:
//!   - No .thumb_func directives (ARM32 mode, not Thumb)
//!   - No SDIV: bl __aeabi_idiv (r0=dividend, r1=divisor → r0=quotient)
//!   - Variables: same RamAllocator pattern but Pi Zero RAM at 0x00100000+
//!   - Startup: calls vectrexinit(1), v_init(), v_setRefresh(50)
//!   - Loop: calls v_WaitRecal(), v_readButtons(), v_readJoystick1Analog()
//!   - No explicit music/audio update call (stubbed for now)

use vpy_parser::{Module, Item, Stmt, Expr, AssignTarget, BinOp};
use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicU32, Ordering};
use crate::AssetInfo;
use super::expressions::{emit_expr, register_string_arrays};

static LABEL_CTR: AtomicU32 = AtomicU32::new(0);
fn next_id() -> u32 { LABEL_CTR.fetch_add(1, Ordering::Relaxed) }

/// Pi Zero user-variable RAM base. We start above 1MB to avoid colliding with
/// any SDK data structures that live in the lower address range.
const PI_RAM_BASE: u32 = 0x0010_0000;

// ── RAM allocator ─────────────────────────────────────────────────────────

struct RamAllocator { next: u32 }

impl RamAllocator {
    fn new() -> Self { Self { next: PI_RAM_BASE } }
    fn alloc(&mut self, bytes: u32) -> u32 {
        let addr = (self.next + 3) & !3;
        self.next = addr + bytes;
        addr
    }
}

// ── Public entry points ───────────────────────────────────────────────────

/// Allocate globals into the BSS-equivalent .equ map.
/// Returns (var_addr_map, empty_string) — the BSS declarations are emitted
/// separately via emit_bss_decls() because they must go in .bss section.
pub fn allocate_globals_bss(module: &Module) -> (HashMap<String, u32>, String) {
    let mut alloc = RamAllocator::new();
    let mut addrs: HashMap<String, u32> = HashMap::new();
    let mut decls = String::new();

    // Reserve runtime slots (mirrors RP2350 layout for compatibility)
    let _tmpval   = alloc.alloc(4); // TMPVAL
    let _tmpptr   = alloc.alloc(4); // TMPPTR
    let _tmpptr2  = alloc.alloc(4); // TMPPTR2
    for i in 0..5u32 { let a = alloc.alloc(4); decls.push_str(&format!(".equ VAR_ARG{i}, 0x{a:08X}\n")); }
    let result    = alloc.alloc(4); decls.push_str(&format!(".equ RESULT, 0x{result:08X}\n"));
    let beep      = alloc.alloc(4); decls.push_str(&format!(".equ BEEP_FRAMES_LEFT, 0x{beep:08X}\n"));
    let rng       = alloc.alloc(4); decls.push_str(&format!(".equ RAND_SEED, 0x{rng:08X}\n"));
    let cam_x     = alloc.alloc(4); decls.push_str(&format!(".equ CAMERA_X, 0x{cam_x:08X}\n"));
    let cam_y     = alloc.alloc(4); decls.push_str(&format!(".equ CAMERA_Y, 0x{cam_y:08X}\n"));
    let txt_sz    = alloc.alloc(4); decls.push_str(&format!(".equ TEXT_SIZE, 0x{txt_sz:08X}\n"));
    decls.push_str(&format!(".equ PITREX_TEXT_SIZE, 0x{txt_sz:08X}\n")); // alias
    // PSG music sequencer
    let psg_ptr   = alloc.alloc(4); decls.push_str(&format!(".equ PSG_MUSIC_PTR, 0x{psg_ptr:08X}\n"));
    let psg_start = alloc.alloc(4); decls.push_str(&format!(".equ PSG_MUSIC_START, 0x{psg_start:08X}\n"));
    let psg_play  = alloc.alloc(4); decls.push_str(&format!(".equ PSG_IS_PLAYING, 0x{psg_play:08X}\n"));
    let psg_delay = alloc.alloc(4); decls.push_str(&format!(".equ PSG_DELAY_FRAMES, 0x{psg_delay:08X}\n"));
    // SFX
    let sfx_ptr   = alloc.alloc(4); decls.push_str(&format!(".equ PSG_SFX_PTR, 0x{sfx_ptr:08X}\n"));
    let sfx_act   = alloc.alloc(4); decls.push_str(&format!(".equ PSG_SFX_ACTIVE, 0x{sfx_act:08X}\n"));
    let sfx_dly   = alloc.alloc(4); decls.push_str(&format!(".equ PSG_SFX_DELAY, 0x{sfx_dly:08X}\n"));
    // Level system
    let lvl_ptr   = alloc.alloc(4); decls.push_str(&format!(".equ LEVEL_DATA_PTR, 0x{lvl_ptr:08X}\n"));
    let lvl_gpc   = alloc.alloc(4); decls.push_str(&format!(".equ LEVEL_GP_COUNT, 0x{lvl_gpc:08X}\n"));
    // LEVEL_GP_BUF: 32 GP objects × 8 bytes each (x i16, y i16, vx i16, vy i16)
    let lvl_buf   = alloc.alloc(256); decls.push_str(&format!(".equ LEVEL_GP_BUF, 0x{lvl_buf:08X}\n"));
    decls.push('\n');

    // User globals & locals
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
                        decls.push_str(&format!(".equ ARRAY_{varname}_DATA, 0x{data_addr:08X}\n"));
                        decls.push_str(&format!(".equ ARRAY_{varname}_LEN, {len}\n"));
                        decls.push_str(&format!(".equ VAR_{varname}, 0x{ptr_addr:08X}  @ array ptr\n"));
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
                        decls.push_str(&format!(".equ ARRAY_{varname}_LEN, {len}\n"));
                        decls.push_str(&format!(".equ VAR_{varname}, 0x{ptr_addr:08X}  @ const array ptr\n"));
                        addrs.insert(varname, ptr_addr);
                    }
                    _ => {
                        let addr = alloc.alloc(4);
                        decls.push_str(&format!(".equ VAR_{varname}, 0x{addr:08X}  @ const scalar\n"));
                        addrs.insert(varname, addr);
                    }
                }
            }
            _ => {}
        }
    }

    for item in &module.items {
        if let Item::Function(func) = item {
            for param in &func.params {
                ensure_var(param, &mut alloc, &mut addrs, &mut decls, "param");
            }
            collect_locals(&func.body, &mut alloc, &mut addrs, &mut decls);
        }
    }

    (addrs, decls)
}

/// Emit const array ROM data tables (to be placed in .rodata section).
/// String arrays emit a .word pointer table followed by .asciz string data.
/// Numeric arrays emit .hword entries (i16).
/// Also registers string array names for stride-4/ldr indexing in expressions.
pub fn emit_const_array_data(module: &Module) -> String {
    let mut s = String::new();
    let mut str_array_names: HashSet<String> = HashSet::new();

    for item in &module.items {
        if let Item::Const { name, value, .. } = item {
            if let Expr::List(elems) = value {
                let varname = name.to_uppercase();
                let is_string_array = elems.iter().any(|e| matches!(e, Expr::StringLit(_)));

                if is_string_array {
                    str_array_names.insert(varname.clone());

                    // Emit pointer table
                    s.push_str(".align 2\n");
                    s.push_str(&format!("ARRAY_{varname}_DATA:\n"));
                    for (i, _elem) in elems.iter().enumerate() {
                        s.push_str(&format!("    .word   .L{varname}_STR{i}\n"));
                    }
                    // Emit string data
                    for (i, elem) in elems.iter().enumerate() {
                        if let Expr::StringLit(text) = elem {
                            s.push_str(&format!(".L{varname}_STR{i}:\n"));
                            s.push_str(&format!("    .asciz  \"{text}\"\n"));
                        }
                    }
                } else {
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
    }

    register_string_arrays(str_array_names);
    s
}

/// Emit all user functions + the PiTrex main() entry point.
pub fn emit_functions(
    module: &Module,
    _assets: &[AssetInfo],
    var_addrs: &HashMap<String, u32>,
) -> Result<String, String> {
    let mut s = String::new();

    // User-defined functions (skip main/loop — inlined in game_main).
    for item in &module.items {
        if let Item::Function(func) = item {
            let n = func.name.to_uppercase();
            if n == "MAIN" || n == "LOOP" { continue; }
            s.push_str(&emit_function(&func.name, &func.params, &func.body, var_addrs)?);
        }
    }

    s.push_str(&emit_game_main(module, var_addrs)?);
    Ok(s)
}

// ── Private helpers ───────────────────────────────────────────────────────

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

fn collect_locals(
    stmts: &[Stmt],
    alloc: &mut RamAllocator,
    addrs: &mut HashMap<String, u32>,
    decls: &mut String,
) {
    for stmt in stmts {
        match stmt {
            Stmt::Let { name, value, .. } => {
                ensure_var(name, alloc, addrs, decls, "local");
                if let Expr::List(elems) = value {
                    let len = elems.len();
                    let data_size = ((len * 2) as u32 + 3) & !3;
                    let data_addr = alloc.alloc(data_size);
                    let varname = name.to_uppercase();
                    decls.push_str(&format!(".equ ARRAY_{varname}_DATA, 0x{data_addr:08X}\n"));
                    decls.push_str(&format!(".equ ARRAY_{varname}_LEN, {len}\n"));
                }
            }
            Stmt::Assign { target, .. } => {
                if let AssignTarget::Ident { name, .. } = target {
                    ensure_var(name, alloc, addrs, decls, "local assign");
                }
            }
            Stmt::For { var, body, .. } => {
                ensure_var(var, alloc, addrs, decls, "for var");
                collect_locals(body, alloc, addrs, decls);
            }
            Stmt::While { body, .. } => collect_locals(body, alloc, addrs, decls),
            Stmt::If { body, elifs, else_body, .. } => {
                collect_locals(body, alloc, addrs, decls);
                for (_, eb) in elifs { collect_locals(eb, alloc, addrs, decls); }
                if let Some(eb) = else_body { collect_locals(eb, alloc, addrs, decls); }
            }
            _ => {}
        }
    }
}

/// Emit a single user-defined function (ARM32, not Thumb).
fn emit_function(
    name: &str,
    params: &[String],
    body: &[Stmt],
    var_addrs: &HashMap<String, u32>,
) -> Result<String, String> {
    let mut s = String::new();
    s.push_str(&format!("@ --- function {name} ---\n"));
    s.push_str(".align 2\n");
    // ARM32: no .thumb_func directive
    s.push_str(&format!(".global {name}\n.type {name}, %function\n{name}:\n"));
    // Push 6 registers (24 bytes) to maintain 8-byte stack alignment
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}\n");

    for (i, param) in params.iter().enumerate().take(4) {
        let varname = param.to_uppercase();
        if let Some(&addr) = var_addrs.get(&varname) {
            s.push_str(&format!(
                "    ldr     r4, =0x{addr:08X}    @ save param {param}\n    str     r{i}, [r4]\n"
            ));
        }
    }

    let loop_labels: Vec<(String, String)> = Vec::new();
    for stmt in body {
        s.push_str(&emit_stmt(stmt, var_addrs, &loop_labels, None)?);
    }
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n");
    s.push_str("    .ltorg\n\n");
    Ok(s)
}

/// Emit the PiTrex main() — SDK init + game loop.
fn emit_game_main(module: &Module, var_addrs: &HashMap<String, u32>) -> Result<String, String> {
    let mut s = String::new();

    let main_fn = module.items.iter().find_map(|i| {
        if let Item::Function(f) = i { if f.name.to_uppercase() == "MAIN" { return Some(f); } }
        None
    });
    let loop_fn = module.items.iter().find_map(|i| {
        if let Item::Function(f) = i { if f.name.to_uppercase() == "LOOP" { return Some(f); } }
        None
    });

    s.push_str("@ --- main (PiTrex SDK entry point) ---\n");
    s.push_str(".align 2\n");
    s.push_str(".global main\n.type main, %function\nmain:\n");
    // Push 8 registers (32 bytes) to maintain 16-byte stack alignment required by NEON
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}\n");

    // UART debug init (PL011, 921600 baud, 250 MHz clock) — Malban SDK
    s.push_str("    @ UART debug init\n");
    s.push_str("    ldr     r0, =921600\n");
    s.push_str("    mov     r1, #8\n");
    s.push_str("    ldr     r2, =250000000\n");
    s.push_str("    bl      RPI_AuxUartInit\n");
    s.push_str("    ldr     r0, =.Lstr_start\n");
    s.push_str("    bl      vpy_uart_puts\n");

    // PiTrex SDK initialisation
    s.push_str("    @ PiTrex SDK init\n");
    s.push_str("    mov     r0, #1\n    bl      vectrexinit\n");
    s.push_str("    ldr     r0, =.Lstr_vinit\n    bl      vpy_uart_puts\n");
    s.push_str("    bl      v_init\n");
    s.push_str("    mov     r0, #50\n    bl      v_setRefresh\n\n");

    // Flush literal pool after SDK init so subsequent ldr= pool entries fit within 4KB
    let mut pool_idx = 0usize;
    let flush_pool = |s: &mut String, idx: &mut usize| {
        let lbl = format!(".Lgp_{}", *idx);
        s.push_str(&format!("    b       {lbl}\n    .ltorg\n{lbl}:\n"));
        *idx += 1;
    };
    flush_pool(&mut s, &mut pool_idx);

    // Initialise global variables (same pattern as ARM backend)
    s.push_str("    @ initialise globals\n");
    let mut init_count = 0usize;
    for item in &module.items {
        // Flush literal pool every 60 variables to stay within ARM ldr= range
        if init_count > 0 && init_count % 60 == 0 {
            flush_pool(&mut s, &mut pool_idx);
        }
        match item {
            Item::GlobalLet { name, value, .. } => {
                let varname = name.to_uppercase();
                if let Some(&addr) = var_addrs.get(&varname) {
                    match value {
                        Expr::Number(n) => {
                            let mov = if *n >= 0 && *n <= 255 {
                                format!("    mov     r0, #{n}\n")
                            } else {
                                format!("    ldr     r0, ={n}\n")
                            };
                            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n{mov}    str     r0, [r1]\n"));
                            init_count += 1;
                        }
                        Expr::List(elems) => {
                            let data_varname = format!("ARRAY_{varname}_DATA");
                            s.push_str(&format!("    @ init array {name}\n"));
                            s.push_str(&format!("    ldr     r2, ={data_varname}\n"));
                            for (i, elem) in elems.iter().enumerate() {
                                if let Expr::Number(n) = elem {
                                    let mov = if *n >= 0 && *n <= 255 {
                                        format!("    mov     r0, #{n}\n")
                                    } else {
                                        format!("    ldr     r0, ={n}\n")
                                    };
                                    s.push_str(&format!("{mov}    strh    r0, [r2, #{}]\n", i * 2));
                                }
                            }
                            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    str     r2, [r1]\n"));
                            init_count += 1;
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
                            let mov = if *n >= 0 && *n <= 255 {
                                format!("    mov     r0, #{n}\n")
                            } else {
                                format!("    ldr     r0, ={n}\n")
                            };
                            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n{mov}    str     r0, [r1]\n"));
                            init_count += 1;
                        }
                        Expr::List(_) => {
                            let data_label = format!("ARRAY_{varname}_DATA");
                            s.push_str(&format!(
                                "    ldr     r0, ={data_label}\n    ldr     r1, =0x{addr:08X}\n    str     r0, [r1]  @ const array {name} → rodata\n"
                            ));
                            init_count += 1;
                        }
                        _ => {}
                    }
                }
            }
            _ => {}
        }
    }
    // Flush after globals init
    flush_pool(&mut s, &mut pool_idx);

    // VPy main() body
    let loop_labels: Vec<(String, String)> = Vec::new();
    if let Some(f) = main_fn {
        s.push_str("    @ main() body\n");
        for stmt in &f.body {
            s.push_str(&emit_stmt(stmt, var_addrs, &loop_labels, Some("pitrex_game_loop"))?);
        }
        // Flush after main() body before entering game loop
        flush_pool(&mut s, &mut pool_idx);
    }

    // Game loop — PiTrex frame sync + input
    s.push_str("\npitrex_game_loop:\n");
    s.push_str("    bl      v_WaitRecal\n");
    s.push_str("    bl      v_readButtons\n");
    s.push_str("    bl      v_readJoystick1Analog\n");
    s.push_str("    bl      v_readJoystick2Analog\n");
    s.push_str("    bl      pitrex_music_update\n");
    s.push_str("    bl      pitrex_sfx_update\n");
    s.push_str("    bl      v_doSound          @ flush PSG buffer to hardware\n");

    if let Some(f) = loop_fn {
        // Emit loop body with periodic pool flushes every ~3 KB of generated text
        // ARM ldr= pool must be within 4KB; ~3000 chars ≈ 600 instructions ≈ 2.4 KB — safe margin
        let mut last_flush_len = s.len();
        for stmt in &f.body {
            let stmt_code = emit_stmt(stmt, var_addrs, &loop_labels, Some("pitrex_game_loop"))?;
            s.push_str(&stmt_code);
            if s.len() - last_flush_len > 3000 {
                flush_pool(&mut s, &mut pool_idx);
                last_flush_len = s.len();
            }
        }
    }
    s.push_str("    b       pitrex_game_loop\n\n");

    // UART helper: vpy_uart_puts(r0=str_ptr) — loops calling RPI_AuxUartWrite
    s.push_str("@ vpy_uart_puts(r0=str_ptr) — write null-terminated string via UART\n");
    s.push_str(".type vpy_uart_puts, %function\nvpy_uart_puts:\n");
    s.push_str("    push    {r4, lr}\n");
    s.push_str("    mov     r4, r0\n");
    s.push_str(".Lputs_loop:\n");
    s.push_str("    ldrb    r0, [r4], #1\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     .Lputs_done\n");
    s.push_str("    bl      RPI_AuxUartWrite\n");
    s.push_str("    b       .Lputs_loop\n");
    s.push_str(".Lputs_done:\n");
    s.push_str("    pop     {r4, pc}\n\n");

    // Debug strings
    s.push_str(".Lstr_start:  .asciz \"VPy PiTrex starting\\r\\n\"\n");
    s.push_str(".Lstr_vinit:  .asciz \"vectrexinit OK\\r\\n\"\n");
    s.push_str("    .ltorg\n\n");

    Ok(s)
}

// ── Statement emitter (identical pattern to ARM, hardware calls go through named fns) ──

fn emit_binop_on_regs(op: &BinOp, s: &mut String) -> Result<(), String> {
    match op {
        BinOp::Add     => s.push_str("    add     r0, r0, r1\n"),
        BinOp::Sub     => s.push_str("    sub     r0, r0, r1\n"),
        BinOp::Mul     => s.push_str("    mul     r0, r0, r1\n"),
        BinOp::Div |
        BinOp::FloorDiv => {
            // No SDIV on ARMv6 — call AEABI soft-div
            s.push_str("    push    {lr}\n    bl      __aeabi_idiv\n    pop     {lr}\n");
        }
        BinOp::Mod => {
            // idivmod: r0 = quot, r1 = rem (AEABI __aeabi_idivmod)
            s.push_str("    push    {lr}\n    bl      __aeabi_idivmod\n    mov     r0, r1\n    pop     {lr}\n");
        }
        BinOp::Shl    => s.push_str("    lsl     r0, r0, r1\n"),
        BinOp::Shr    => s.push_str("    asr     r0, r0, r1\n"),
        BinOp::BitAnd => s.push_str("    and     r0, r0, r1\n"),
        BinOp::BitOr  => s.push_str("    orr     r0, r0, r1\n"),
        BinOp::BitXor => s.push_str("    eor     r0, r0, r1\n"),
    }
    Ok(())
}

fn emit_index_load(
    target: &Expr,
    index: &Expr,
    var_addrs: &HashMap<String, u32>,
    s: &mut String,
) -> Result<(), String> {
    s.push_str(&emit_expr(target, var_addrs)?);  // r0 = base ptr
    s.push_str("    push    {r0}           @ save base ptr\n");
    s.push_str(&emit_expr(index, var_addrs)?);   // r0 = index
    s.push_str("    lsl     r0, r0, #1       @ index * 2\n");
    s.push_str("    pop     {r1}           @ base ptr\n");
    s.push_str("    add     r1, r1, r0       @ element addr\n");
    s.push_str("    ldrsh   r0, [r1]         @ signed 16-bit load\n");
    Ok(())
}

fn emit_stmt(
    stmt: &Stmt,
    var_addrs: &HashMap<String, u32>,
    loop_labels: &[(String, String)],
    return_label: Option<&str>,
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
                    s.push_str("    push    {r0}           @ save value\n");
                    s.push_str(&emit_expr(target, var_addrs)?);
                    s.push_str("    push    {r0}           @ save base ptr\n");
                    s.push_str(&emit_expr(index, var_addrs)?);
                    s.push_str("    lsl     r0, r0, #1       @ index * 2\n");
                    s.push_str("    pop     {r1}           @ base ptr\n");
                    s.push_str("    add     r1, r1, r0       @ element addr\n");
                    s.push_str("    pop     {r0}           @ value\n");
                    s.push_str("    strh    r0, [r1]         @ store 16-bit\n");
                }
                other => return Err(format!("Unsupported assign target: {:?}", other)),
            }
            Ok(s)
        }

        Stmt::Let { name, value, .. } => {
            let mut s = emit_expr(value, var_addrs)?;
            let varname = name.to_uppercase();
            if let Some(&addr) = var_addrs.get(&varname) {
                s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    str     r0, [r1]\n"));
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
                    emit_index_load(target, index, var_addrs, &mut s)?;
                    s.push_str("    push    {r1}       @ save element addr\n");
                    s.push_str("    push    {r0}       @ left operand\n");
                    s.push_str(&emit_expr(value, var_addrs)?);
                    s.push_str("    mov     r1, r0\n");
                    s.push_str("    pop     {r0}\n");
                    emit_binop_on_regs(op, &mut s)?;
                    s.push_str("    pop     {r1}       @ element addr\n");
                    s.push_str("    strh    r0, [r1]     @ store result\n");
                }
                other => return Err(format!("Unsupported compound assign target: {:?}", other)),
            }
            Ok(s)
        }

        Stmt::Expr(expr, _) => {
            if let Expr::Call(info) = expr {
                if info.name.to_uppercase() == "MSG_DEF" {
                    return Ok(String::new());
                }
            }
            emit_expr(expr, var_addrs)
        }

        Stmt::If { cond, body, elifs, else_body, .. } => {
            let id = next_id();
            let mut s = emit_expr(cond, var_addrs)?;
            s.push_str("    cmp     r0, #0\n");
            s.push_str(&format!("    beq     if_else_{id}\n"));
            for st in body { s.push_str(&emit_stmt(st, var_addrs, loop_labels, return_label)?); }
            s.push_str(&format!("    b       if_end_{id}\n"));
            s.push_str(&format!("if_else_{id}:\n"));
            let mut last_pool_flush_pos = s.len();
            for (elif_cond, elif_body) in elifs {
                let eid = next_id();
                s.push_str(&emit_expr(elif_cond, var_addrs)?);
                s.push_str("    cmp     r0, #0\n");
                s.push_str(&format!("    beq     elif_end_{eid}\n"));
                for st in elif_body { s.push_str(&emit_stmt(st, var_addrs, loop_labels, return_label)?); }
                s.push_str(&format!("    b       if_end_{id}\n"));
                s.push_str(&format!("elif_end_{eid}:\n"));
                // Flush literal pool after each large elif block to stay within ARM 4KB pool range
                // (~2000 chars ≈ 300-400 ARM instructions ≈ 1200-1600 bytes)
                if s.len() - last_pool_flush_pos > 2000 {
                    let pid = next_id();
                    s.push_str(&format!("    b       .Lgp_{pid}_skip\n    .ltorg\n.Lgp_{pid}_skip:\n"));
                    last_pool_flush_pos = s.len();
                }
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
            let mut inner = loop_labels.to_vec();
            inner.push((break_lbl.clone(), continue_lbl.clone()));
            let mut s = String::new();
            s.push_str(&format!("while_top_{id}:\n"));
            s.push_str(&emit_expr(cond, var_addrs)?);
            s.push_str("    cmp     r0, #0\n");
            s.push_str(&format!("    beq     while_end_{id}\n"));
            for st in body { s.push_str(&emit_stmt(st, var_addrs, &inner, return_label)?); }
            s.push_str(&format!("    b       while_top_{id}\nwhile_end_{id}:\n"));
            Ok(s)
        }

        Stmt::For { var, start, end, step, body, .. } => {
            let id = next_id();
            let varname = var.to_uppercase();
            let addr = var_addrs.get(&varname).copied().unwrap_or(0);
            let break_lbl    = format!("for_end_{id}");
            let continue_lbl = format!("for_inc_{id}");
            let mut inner = loop_labels.to_vec();
            inner.push((break_lbl.clone(), continue_lbl.clone()));
            let mut s = String::new();
            // init
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
            for st in body { s.push_str(&emit_stmt(st, var_addrs, &inner, return_label)?); }
            // increment
            s.push_str(&format!("for_inc_{id}:\n"));
            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    ldr     r0, [r1]\n"));
            if let Some(step_expr) = step {
                s.push_str("    push    {r0}\n");
                s.push_str(&emit_expr(step_expr, var_addrs)?);
                s.push_str("    mov     r1, r0\n    pop     {r0}\n    add     r0, r0, r1\n");
            } else {
                s.push_str("    add     r0, r0, #1\n");
            }
            s.push_str(&format!("    ldr     r1, =0x{addr:08X}\n    str     r0, [r1]\n"));
            s.push_str(&format!("    b       for_top_{id}\nfor_end_{id}:\n"));
            Ok(s)
        }

        Stmt::Return(Some(expr), _) => {
            let mut s = emit_expr(expr, var_addrs)?;
            if let Some(lbl) = return_label {
                s.push_str(&format!("    b       {lbl}\n"));
            } else {
                s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n");
            }
            Ok(s)
        }

        Stmt::Return(None, _) => {
            if let Some(lbl) = return_label {
                Ok(format!("    b       {lbl}\n"))
            } else {
                Ok("    pop     {r4, r5, r6, r7, r8, pc}\n".to_string())
            }
        }

        Stmt::Break { .. } => {
            if let Some((break_lbl, _)) = loop_labels.last() {
                Ok(format!("    b       {break_lbl}\n"))
            } else {
                Err("break outside loop".into())
            }
        }

        Stmt::Continue { .. } => {
            if let Some((_, continue_lbl)) = loop_labels.last() {
                Ok(format!("    b       {continue_lbl}\n"))
            } else {
                Err("continue outside loop".into())
            }
        }

        Stmt::Pass { .. } => Ok(String::new()),

        other => Err(format!("Unsupported statement in PiTrex backend: {:?}", other)),
    }
}
