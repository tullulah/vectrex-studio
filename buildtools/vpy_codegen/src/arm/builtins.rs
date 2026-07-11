//! ARM Thumb2 implementations of VPy builtins.
//!
//! All display/audio/input builtins talk to the Vectrex hardware via
//! bus_write / bus_read (GPIO bit-bang to VIA 6522).
//!
//! PSG (AY-3-8912) bit assignments on VIA Port B (from M6809 WRITE_PSG sequence):
//!   bit 3 (0x08) = BC1  (bus control 1)
//!   bit 4 (0x10) = BDIR (bus direction)
//!   bit 0 (0x01) = base / mux (kept 1 during PSG access)
//!
//!   LATCH  ADDRESS = 0x19  (BDIR=1, BC1=1, base=1)
//!   INACTIVE       = 0x01  (BDIR=0, BC1=0, base=1)
//!   WRITE  DATA    = 0x11  (BDIR=1, BC1=0, base=1)
//!   READ   DATA    = 0x09  (BDIR=0, BC1=1, base=1)
//!
//! J2 buttons: PSG register 14 (Port A of AY-3-8912), bits 0-3, active LOW.
//! J2 analog: Vectrex has analog hardware for J2 (4052 mux, same circuit as J1).
//!   4052 mux channel selection via VIA Port B bits 1:0:
//!     0b00 (0x00) = J2 X,  0b01 (0x01) = J1 X
//!     0b10 (0x02) = J2 Y,  0b11 (0x03) = J1 Y
//!   Full implementation requires successive approximation (ZPULSE + IFR comparator).
//!   Pending until bus master mode (PCB v2, BUS_MASTER_AVAILABLE=true) is available.

use super::analysis::Usage;

/// Size in bytes of a single ARM-format level object in ROM.
/// Layout: x(2) + y(2) + scale(1) + intensity(1) + flags(1) + type(1)
///         + vector_ptr(4) + half_w(1) + half_h(1) + vel_x(1) + vel_y(1)
///         + coll_mesh_ptr(4) = 20 bytes.
const ARM_ROM_OBJ_STRIDE: usize = 20;

/// A compile-time message definition: MSG_DEF(id, x, y, "text")
pub struct MsgEntry {
    pub id:   u8,
    pub x:    i8,
    pub y:    i8,
    pub text: String,
}

/// Collect all MSG_DEF(id, x, y, "text") calls from any function in the module.
pub fn collect_msg_entries(module: &vpy_parser::Module) -> Vec<MsgEntry> {
    let mut entries = Vec::new();
    for item in &module.items {
        if let vpy_parser::Item::Function(func) = item {
            collect_from_stmts(&func.body, &mut entries);
        }
    }
    entries.sort_by_key(|e| e.id);
    entries
}

fn collect_from_stmts(stmts: &[vpy_parser::Stmt], out: &mut Vec<MsgEntry>) {
    for stmt in stmts {
        match stmt {
            vpy_parser::Stmt::Expr(vpy_parser::Expr::Call(c), _)
                if c.name.to_uppercase() == "MSG_DEF" && c.args.len() == 4 =>
            {
                let id = if let vpy_parser::Expr::Number(n) = &c.args[0] { *n as u8 } else { 0 };
                let x  = if let vpy_parser::Expr::Number(n) = &c.args[1] { *n as i8 } else { 0 };
                let y  = if let vpy_parser::Expr::Number(n) = &c.args[2] { *n as i8 } else { 0 };
                if let vpy_parser::Expr::StringLit(s) = &c.args[3] {
                    out.push(MsgEntry { id, x, y, text: s.clone() });
                }
            }
            vpy_parser::Stmt::If { body, elifs, else_body, .. } => {
                collect_from_stmts(body, out);
                for (_, b) in elifs { collect_from_stmts(b, out); }
                if let Some(eb) = else_body { collect_from_stmts(eb, out); }
            }
            vpy_parser::Stmt::While { body, .. } => collect_from_stmts(body, out),
            vpy_parser::Stmt::For   { body, .. } => collect_from_stmts(body, out),
            _ => {}
        }
    }
}

pub fn emit_builtins(msg_entries: &[MsgEntry], usage: &Usage) -> String {
    let mut s = String::new();
    s.push_str("@ ============================================================\n");
    s.push_str("@ VPy Builtins — ARM Thumb2 / RP2350\n");
    s.push_str("@ ============================================================\n\n");

    // drawing.rs emits: vpy_draw_vector, vpy_draw_vector_3d, smul_lut,
    // dv_reset, dv_move_to, dv_draw_delta, _SIN_TABLE (usage-gated there).
    // Here, each runtime group is emitted only when the program uses it
    // (see arm/analysis.rs for the group/dependency table).
    if usage.has("TEXT") {
        s.push_str(&emit_font_data());
    }
    // vpy_wait_recal + vpy_set_intensity: always-emit core (SVC stubs; the
    // game loop calls wait_recal and every draw routine calls set_intensity).
    s.push_str(&emit_wait_recal());
    s.push_str(&emit_set_intensity());
    if usage.has("MOVE") {
        s.push_str(&emit_move());
    }
    if usage.has("DRAW_LINE") {
        s.push_str(&emit_draw_line());
    }
    if usage.has("DRAW_VECTOR_EX") {
        s.push_str(&emit_draw_vector_ex());
    }
    // Shapes: each gates its own routine.
    if usage.has("CIRCLE")      { s.push_str(&emit_draw_circle()); }
    if usage.has("RECT")        { s.push_str(&emit_draw_rect()); }
    if usage.has("FILLED_RECT") { s.push_str(&emit_draw_filled_rect()); }
    if usage.has("POLYGON")     { s.push_str(&emit_draw_polygon()); }
    if usage.has("ELLIPSE")     { s.push_str(&emit_draw_ellipse()); }
    if usage.has("ARC")         { s.push_str(&emit_draw_arc()); }
    if usage.has("BEZIER")      { s.push_str(&emit_draw_bezier_cubic()); }
    if usage.has("BEZIER_QUAD") { s.push_str(&emit_draw_bezier_quad()); }
    if usage.has("TEXT") {
        s.push_str(&emit_print_text());
    }
    if usage.has("PRINT_NUMBER") {
        s.push_str(&emit_print_number());
    }
    if usage.has("JOYSTICK") {
        s.push_str(&emit_joystick());
        s.push_str(&emit_update_buttons());
    }
    if usage.has("PSG") {
        s.push_str(&emit_psg_helpers());
    }
    // Math (each group gated separately).
    if usage.has("MATH_BASIC") { s.push_str(&emit_math_basic()); }
    if usage.has("TRIG")       { s.push_str(&emit_trig()); }
    if usage.has("SQRT")       { s.push_str(&emit_sqrt()); }
    if usage.has("RAND")       { s.push_str(&emit_rand()); }
    // Utilities.
    if usage.has("PEEK_POKE")  { s.push_str(&emit_peek_poke()); }
    if usage.has("WAIT")       { s.push_str(&emit_wait_builtin()); }
    if usage.has("BEEP")       { s.push_str(&emit_beep()); }
    if usage.has("LEN")        { s.push_str(&emit_len()); }
    // Audio engines.
    if usage.has("MUSIC")      { s.push_str(&emit_music_engine()); }
    if usage.has("SFX")        { s.push_str(&emit_sfx_engine()); }
    if usage.has("NOTE")       { s.push_str(&emit_note_engine()); }
    // State accessors.
    if usage.has("CAMERA")     { s.push_str(&emit_camera_builtins()); }
    if usage.has("FRAME_US")   { s.push_str(&emit_frame_us()); }
    if usage.has("TEXT")       { s.push_str(&emit_text_state()); }
    if usage.has("DEBUG")      { s.push_str(&emit_debug_builtins()); }
    // Level system.
    if usage.has("LEVEL")           { s.push_str(&emit_level_builtins()); }
    if usage.has("LEVEL_COLLISION") { s.push_str(&emit_level_collision()); }
    if usage.has("MSG") {
        s.push_str(&emit_msg_builtins(msg_entries));
    }
    if usage.has("ANIM") {
        s.push_str(&emit_draw_anim());
    }
    if usage.has("PLAY_SAMPLE") {
        s.push_str(&emit_play_sample());
    }
    s
}

// ─── PLAY_SAMPLE ────────────────────────────────────────────────────────────

fn emit_play_sample() -> String {
    // BIOS trap — hands the .vsmp ROM table (r0 = _NAME_SMP) to the core1 audio
    // streamer, which clocks 4-bit samples out to the PSG volume register as a
    // crude DAC. SYS_PLAY_SAMPLE = 9 (next free syscall after SYS_BUS_WRITE = 8).
    let mut s = String::new();
    s.push_str("@ vpy_play_sample(r0=sample_data_ptr) — BIOS trap: SYS_PLAY_SAMPLE\n");
    s.push_str(".global vpy_play_sample\n.type vpy_play_sample, %function\n.thumb_func\nvpy_play_sample:\n");
    s.push_str("    svc     #9                      @ SYS_PLAY_SAMPLE\n");
    s.push_str("    bx      lr\n\n");
    s
}

// ─── WAIT_RECAL ────────────────────────────────────────────────────────────

fn emit_wait_recal() -> String {
    // BIOS trap — the BIOS paces the frame (absolute 20 ms deadlines from its
    // hardware timer) and holds the integrator zero during the wait.
    let mut s = String::new();
    s.push_str("@ vpy_wait_recal() — BIOS trap: SYS_WAIT_RECAL\n");
    s.push_str(".global vpy_wait_recal\n.type vpy_wait_recal, %function\n.thumb_func\nvpy_wait_recal:\n");
    s.push_str("    svc     #1                      @ SYS_WAIT_RECAL\n");
    s.push_str("    bx      lr\n\n");
    s
}

// ─── SET_INTENSITY ─────────────────────────────────────────────────────────

fn emit_set_intensity() -> String {
    // BIOS trap — the BIOS runs the full Intensity_a sequence (Z mux channel),
    // not just a DAC write (the old inline body was emulator-only behaviour).
    let mut s = String::new();
    s.push_str("@ vpy_set_intensity(r0=intensity 0-127) — BIOS trap: SYS_SET_INTENSITY\n");
    s.push_str(".global vpy_set_intensity\n.type vpy_set_intensity, %function\n.thumb_func\nvpy_set_intensity:\n");
    s.push_str("    svc     #2                      @ SYS_SET_INTENSITY\n");
    s.push_str("    bx      lr\n\n");
    s
}

// ─── MOVE ─────────────────────────────────────────────────────────────────

fn emit_move() -> String {
    let mut s = String::new();
    s.push_str("@ vpy_move(r0=x, r1=y) — position beam (absolute from current)\n");
    s.push_str(".global vpy_move\n.type vpy_move, %function\n.thumb_func\nvpy_move:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    mov     r4, r0\n    mov     r5, r1\n");
    // Save MOVE position so vpy_draw_line can apply it as an offset
    s.push_str("    ldr     r0, =VPY_MOVE_X\n");
    s.push_str("    str     r4, [r0]            @ VPY_MOVE_X = x\n");
    s.push_str("    str     r5, [r0, #4]        @ VPY_MOVE_Y = y  (VPY_MOVE_Y = VPY_MOVE_X + 4)\n");
    s.push_str("    mov     r0, #0xD001\n    mov     r1, r5\n    bl      bus_write\n"); // PORT_A=y
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x00\n    bl      bus_write\n"); // PB=0 (Y mux)
    s.push_str("    mov     r0, #0xD001\n    mov     r1, r4\n    bl      bus_write\n"); // PORT_A=x
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x01\n    bl      bus_write\n"); // PB=1 (X mux)
    s.push_str("    pop     {r4, r5, pc}\n    .ltorg\n\n");
    s
}

// ─── DRAW_LINE ─────────────────────────────────────────────────────────────

fn emit_draw_line() -> String {
    let mut s = String::new();
    s.push_str("@ vpy_draw_line(r0=x0, r1=y0, r2=x1, r3=y1, [sp+0]=intensity)\n");
    s.push_str("@ Splits segments longer than 127 units using SDIV for proportional steps\n");
    s.push_str(".global vpy_draw_line\n.type vpy_draw_line, %function\n.thumb_func\nvpy_draw_line:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}\n"); // 6 regs = 24 bytes
    // r4=x0, r5=y0, r6=x1, r7=y1
    s.push_str("    mov     r4, r0\n    mov     r5, r1\n    mov     r6, r2\n    mov     r7, r3\n");
    // Add MOVE offset (VPY_MOVE_X, VPY_MOVE_Y) to both start and end positions
    // so dx = (x1+MOVE_X) - (x0+MOVE_X) = x1-x0 correctly cancels
    // r2 and r3 are free now (already saved in r6, r7)
    s.push_str("    ldr     r2, =VPY_MOVE_X\n");
    s.push_str("    ldr     r3, [r2]            @ r3 = VPY_MOVE_X\n");
    s.push_str("    ldr     r2, [r2, #4]        @ r2 = VPY_MOVE_Y\n");
    s.push_str("    add     r4, r4, r3          @ x0 += MOVE_X\n");
    s.push_str("    add     r5, r5, r2          @ y0 += MOVE_Y\n");
    s.push_str("    add     r6, r6, r3          @ x1 += MOVE_X\n");
    s.push_str("    add     r7, r7, r2          @ y1 += MOVE_Y\n");
    s.push_str("    ldr     r8, [sp, #24]           @ intensity (5th arg, past 6 saved regs)\n");
    s.push_str("    bl      dv_reset\n");
    s.push_str("    mov     r0, r8\n    bl      vpy_set_intensity\n");
    s.push_str("    mov     r0, r4\n    mov     r1, r5\n    bl      dv_move_to\n");
    // Compute dx = x1-x0, dy = y1-y0 (end coords are NOT offset by MOVE — they are absolute already)
    // x1 and y1 in DRAW_LINE_ARGS are absolute screen coordinates (same convention as x0,y0)
    // dx = (MOVE_X + x1) - (MOVE_X + x0) = x1 - x0 (MOVE offsets cancel)
    s.push_str("    sub     r4, r6, r4\n    sub     r5, r7, r5\n"); // r4=dx=x1-x0, r5=dy=y1-y0 (MOVE cancels)
    // abs(dx) → r6
    s.push_str("    movs    r6, r4\n");
    s.push_str("    bpl     vdl_dx_pos\n");
    s.push_str("    neg     r6, r4\n");       // r6 = |dx|
    s.push_str("vdl_dx_pos:\n");
    // abs(dy) → r7
    s.push_str("    movs    r7, r5\n");
    s.push_str("    bpl     vdl_dy_pos\n");
    s.push_str("    neg     r7, r5\n");       // r7 = |dy|
    s.push_str("vdl_dy_pos:\n");
    // max_dim = max(|dx|, |dy|) → r7
    s.push_str("    cmp     r6, r7\n");
    s.push_str("    it      ge\n");
    s.push_str("    movge   r7, r6\n");       // if |dx| >= |dy|: r7 = |dx|
    // if max_dim == 0, nothing to draw
    s.push_str("    cmp     r7, #0\n    beq     vdl_done\n");
    // n = ceil(max_dim / 127) = (max_dim + 126) / 127
    s.push_str("    add     r7, r7, #126\n");
    s.push_str("    mov     r6, #127\n");
    s.push_str("    sdiv    r8, r7, r6\n");   // r8 = steps (n)
    // r4=remaining_dx, r5=remaining_dy, r8=steps_left
    s.push_str("vdl_loop:\n");
    s.push_str("    cmp     r8, #0\n    beq     vdl_done\n");
    s.push_str("    sdiv    r0, r4, r8\n");   // sub_dx = remaining_dx / steps_left
    s.push_str("    sdiv    r1, r5, r8\n");   // sub_dy = remaining_dy / steps_left
    s.push_str("    sub     r4, r4, r0\n");   // remaining_dx -= sub_dx
    s.push_str("    sub     r5, r5, r1\n");   // remaining_dy -= sub_dy
    s.push_str("    sub     r8, r8, #1\n");   // steps_left--
    s.push_str("    bl      dv_draw_delta\n");
    s.push_str("    b       vdl_loop\n");
    s.push_str("vdl_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n    .ltorg\n\n");
    s
}

// ─── DRAW_VECTOR_EX ────────────────────────────────────────────────────────

fn emit_draw_vector_ex() -> String {
    let mut s = String::new();
    // Register layout (constant across the path loop):
    //   r4 = asset_ptr
    //   r5 = path_count
    //   r6 = path_idx
    //   r7 = mirror
    //   r8 = intensity arg
    //   r9 = ox
    //   r10 = oy
    // Push r10 so it is callee-saved.  8 regs × 4 = 32 bytes → sp+32 = intensity arg.
    s.push_str("@ vpy_draw_vector_ex(r0=asset, r1=ox, r2=oy, r3=mirror, [sp+0]=intensity)\n");
    s.push_str("@ Draws asset centered at (ox,oy); mirror: bit0=flipX, bit1=flipY\n");
    s.push_str("@ dv_reset called before EVERY path so each path starts from screen centre.\n");
    s.push_str(".global vpy_draw_vector_ex\n.type vpy_draw_vector_ex, %function\n.thumb_func\nvpy_draw_vector_ex:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}\n"); // 8 regs = 32 bytes
    s.push_str("    mov     r4, r0              @ asset_ptr\n");
    s.push_str("    mov     r9, r1              @ ox  (kept for whole function)\n");
    s.push_str("    mov     r10, r2             @ oy  (kept for whole function)\n");
    s.push_str("    mov     r7, r3              @ mirror\n");
    s.push_str("    ldr     r8, [sp, #32]       @ intensity arg (8 saved regs = 32 bytes)\n");
    s.push_str("    ldr     r5, [r4]            @ path_count\n");
    s.push_str("    mov     r6, #0              @ path_idx\n");
    s.push_str("dvex_pl:\n");
    s.push_str("    cmp     r6, r5\n    bge     dvex_done\n");
    // r3 = path_ptr
    s.push_str("    lsl     r3, r6, #2\n    add     r3, r3, #4\n    ldr     r3, [r4, r3]\n");
    // Reset beam to screen centre before each path — prevents accumulation of
    // beam drift from the previous path's final position.
    s.push_str("    bl      dv_reset\n");
    // Set intensity: if passed arg (r8) == 0, fall back to per-path .vec intensity
    // at [r3, #0] — same semantics as DRAW_VECTOR (plain) and 6809 DRAW_VEC_INTENSITY=0.
    s.push_str("    ldrb    r0, [r3]            @ .vec per-path intensity\n");
    s.push_str("    cmp     r8, #0\n");
    s.push_str("    it      ne\n");
    s.push_str("    movne   r0, r8             @ if intensity arg != 0, use it\n");
    s.push_str("    bl      vpy_set_intensity\n");
    // compute absolute move: x_start + ox, y_start + oy
    s.push_str("    ldrsb   r0, [r3, #2]        @ x_start\n");
    s.push_str("    ldrsb   r1, [r3, #1]        @ y_start\n");
    // apply mirror
    s.push_str("    tst     r7, #1\n    beq     dvex_nfx\n    neg     r0, r0\n");
    s.push_str("dvex_nfx:\n");
    s.push_str("    tst     r7, #2\n    beq     dvex_nfy\n    neg     r1, r1\n");
    s.push_str("dvex_nfy:\n");
    s.push_str("    add     r0, r0, r9          @ x_start + ox\n");
    s.push_str("    add     r1, r1, r10         @ y_start + oy\n");
    s.push_str("    bl      dv_move_to\n");
    // r2 = cmd_ptr (r3 still holds path_ptr; r2 is caller-free across dv_* traps)
    s.push_str("    add     r2, r3, #5          @ command ptr\n");
    s.push_str("dvex_cl:\n");
    s.push_str("    ldrb    r0, [r2]\n");
    s.push_str("    cmp     r0, #0x02\n    beq     dvex_cend\n");
    s.push_str("    cmp     r0, #0xFF\n    bne     dvex_cskip\n");
    s.push_str("    ldrsb   r0, [r2, #2]        @ dx\n");
    s.push_str("    ldrsb   r1, [r2, #1]        @ dy\n");
    s.push_str("    tst     r7, #1\n    beq     dvex_nfx2\n    neg     r0, r0\n");
    s.push_str("dvex_nfx2:\n");
    s.push_str("    tst     r7, #2\n    beq     dvex_nfy2\n    neg     r1, r1\n");
    s.push_str("dvex_nfy2:\n");
    s.push_str("    bl      dv_draw_delta\n");
    s.push_str("    add     r2, r2, #3\n    b       dvex_cl\n");
    s.push_str("dvex_cskip:\n    add     r2, r2, #1\n    b       dvex_cl\n");
    s.push_str("dvex_cend:\n    add     r6, r6, #1\n    b       dvex_pl\n");
    s.push_str("dvex_done:\n    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n    .ltorg\n\n");
    s
}

// ─── DRAW_CIRCLE / DRAW_RECT / DRAW_FILLED_RECT / DRAW_POLYGON ────────────
// Each shape routine is emitted independently (gated by its own usage group).

fn emit_draw_circle() -> String {
    let mut s = String::new();

    // ── vpy_draw_circle(r0=cx, r1=cy, r2=radius, r3=intensity) ──────────────
    // 16-segment polygon approximation using the sin/cos LUT.
    // Stack layout inside function:
    //   push {r4..r11,lr} = 36 bytes, sub sp,#8 = 8 bytes → sp+0=first_x, sp+4=first_y
    s.push_str("@ vpy_draw_circle(r0=cx, r1=cy, r2=radius, r3=intensity)\n");
    s.push_str("@ 16-segment circle via sin/cos LUT\n");
    s.push_str(".global vpy_draw_circle\n.type vpy_draw_circle, %function\n.thumb_func\nvpy_draw_circle:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    sub     sp, sp, #8              @ [sp+0]=first_x [sp+4]=first_y\n");
    s.push_str("    mov     r4, r0                  @ cx\n");
    s.push_str("    mov     r5, r1                  @ cy\n");
    s.push_str("    asr     r6, r2, #1              @ r6 = diam/2 = radius (matches M6809 convention)\n");
    s.push_str("    mov     r7, r3                  @ intensity\n");
    s.push_str("    bl      dv_reset\n");
    s.push_str("    mov     r0, r7\n    bl      vpy_set_intensity\n");
    // first point at angle=0: cos(0)=127, sin(0)=0
    s.push_str("    mov     r0, #0\n    bl      vpy_cos\n");
    s.push_str("    mul     r0, r0, r6\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r9, r4, r0              @ prev_x = cx + cos(0)*r/127\n");
    s.push_str("    mov     r0, #0\n    bl      vpy_sin\n");
    s.push_str("    mul     r0, r0, r6\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r10, r5, r0             @ prev_y = cy + sin(0)*r/127\n");
    s.push_str("    str     r9, [sp]\n    str     r10, [sp, #4] @ save first point\n");
    s.push_str("    mov     r0, r9\n    mov     r1, r10\n    bl      dv_move_to\n");
    s.push_str("    mov     r8, #1\n");
    s.push_str("vpy_dc_loop:\n");
    s.push_str("    cmp     r8, #16\n    bge     vpy_dc_close\n");
    s.push_str("    lsl     r0, r8, #3\n    bl      vpy_cos\n");
    s.push_str("    mul     r0, r0, r6\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r11, r4, r0             @ new_x\n");
    s.push_str("    lsl     r0, r8, #3\n    bl      vpy_sin\n");
    s.push_str("    mul     r0, r0, r6\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r0, r5, r0              @ new_y in r0\n");
    s.push_str("    sub     r2, r11, r9             @ dx = new_x - prev_x\n");
    s.push_str("    sub     r3, r0, r10             @ dy = new_y - prev_y\n");
    s.push_str("    mov     r9, r11                 @ prev_x = new_x\n");
    s.push_str("    mov     r10, r0                 @ prev_y = new_y\n");
    s.push_str("    mov     r0, r2\n    mov     r1, r3\n    bl      dv_draw_delta\n");
    s.push_str("    add     r8, r8, #1\n    b       vpy_dc_loop\n");
    s.push_str("vpy_dc_close:\n");
    s.push_str("    ldr     r0, [sp]                @ first_x\n");
    s.push_str("    ldr     r1, [sp, #4]            @ first_y\n");
    s.push_str("    sub     r0, r0, r9              @ dx = first_x - prev_x\n");
    s.push_str("    sub     r1, r1, r10             @ dy = first_y - prev_y\n");
    s.push_str("    bl      dv_draw_delta\n");
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    s
}

fn emit_draw_rect() -> String {
    let mut s = String::new();

    // ── vpy_draw_rect(r0=x, r1=y, r2=w, r3=h, [sp+0]=intensity) ─────────────
    // Stack: push {r4..r8,lr} = 24 bytes → intensity at sp+24
    s.push_str("@ vpy_draw_rect(r0=x, r1=y, r2=w, r3=h, [sp+0]=intensity)\n");
    s.push_str(".global vpy_draw_rect\n.type vpy_draw_rect, %function\n.thumb_func\nvpy_draw_rect:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}    @ 24 bytes\n");
    s.push_str("    mov     r4, r0\n    mov     r5, r1\n    mov     r6, r2\n    mov     r7, r3\n");
    s.push_str("    ldr     r8, [sp, #24]               @ intensity\n");
    s.push_str("    bl      dv_reset\n");
    s.push_str("    mov     r0, r8\n    bl      vpy_set_intensity\n");
    s.push_str("    mov     r0, r4\n    mov     r1, r5\n    bl      dv_move_to\n");
    s.push_str("    mov     r0, r6\n    mov     r1, #0\n    bl      dv_draw_delta\n"); // right
    s.push_str("    mov     r0, #0\n    mov     r1, r7\n    bl      dv_draw_delta\n"); // up
    s.push_str("    neg     r0, r6\n    mov     r1, #0\n    bl      dv_draw_delta\n"); // left
    s.push_str("    mov     r0, #0\n    neg     r1, r7\n    bl      dv_draw_delta\n"); // down
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n    .ltorg\n\n");

    s
}

fn emit_draw_filled_rect() -> String {
    let mut s = String::new();

    // ── vpy_draw_filled_rect(r0=x, r1=y, r2=w, r3=h, [sp+28]=intensity) ──────
    // Draws horizontal scan lines to simulate fill (step 3 units).
    // dv_move_to takes DELTA coordinates (not absolute). Strategy:
    //   - dv_move_to(x, y) once to reach the first scan line from center (0,0)
    //   - loop: dv_draw_delta(w, 0)  then  dv_move_to(-w, 3)  to go back+advance
    // push {r4..r9,lr} = 7 regs × 4 = 28 bytes → intensity at [sp+28].
    s.push_str("@ vpy_draw_filled_rect(r0=x, r1=y, r2=w, r3=h, [sp+28]=intensity)\n");
    s.push_str("@ Outer outline (vpy_draw_rect) + horizontal scan lines (step=3)\n");
    s.push_str(".global vpy_draw_filled_rect\n.type vpy_draw_filled_rect, %function\n.thumb_func\nvpy_draw_filled_rect:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}    @ 28 bytes\n");
    s.push_str("    mov     r4, r0              @ x\n");
    s.push_str("    mov     r5, r1              @ y\n");
    s.push_str("    mov     r6, r2              @ w\n");
    s.push_str("    mov     r7, r3              @ h\n");
    s.push_str("    ldr     r8, [sp, #28]       @ intensity\n");
    // Draw the outer outline first via vpy_draw_rect (reuses dv_reset/intensity).
    s.push_str("    push    {r8}                @ intensity as 5th arg\n");
    s.push_str("    mov     r0, r4\n    mov     r1, r5\n    mov     r2, r6\n    mov     r3, r7\n");
    s.push_str("    bl      vpy_draw_rect\n");
    s.push_str("    add     sp, sp, #4\n");
    // Reset for fill scan lines (vpy_draw_rect ended at the start corner, but
    // dv_reset gives us a clean origin and avoids relying on prior beam state).
    s.push_str("    bl      dv_reset\n");
    s.push_str("    mov     r0, r8\n    bl      vpy_set_intensity\n");
    // Move ONCE to (x, y) from center (delta = absolute for first call after reset)
    s.push_str("    mov     r0, r4\n    mov     r1, r5\n    bl      dv_move_to\n");
    s.push_str("    mov     r9, #0              @ scan offset\n");
    s.push_str("vdfr_loop:\n");
    s.push_str("    cmp     r9, r7\n    bge     vdfr_done\n");
    // Draw horizontal scan line (beam starts at x, y+offset)
    s.push_str("    mov     r0, r6\n    mov     r1, #0\n    bl      dv_draw_delta\n");
    s.push_str("    add     r9, r9, #3\n");
    // If more lines: return left by w, advance y by 3 (delta move)
    s.push_str("    cmp     r9, r7\n    bge     vdfr_done\n");
    s.push_str("    neg     r0, r6\n    mov     r1, #3\n    bl      dv_move_to\n");
    s.push_str("    b       vdfr_loop\n");
    s.push_str("vdfr_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n    .ltorg\n\n");

    s
}

fn emit_draw_polygon() -> String {
    let mut s = String::new();

    // ── vpy_draw_polygon(r0=n, r1=intensity, r2=x0, r3=y0, [sp+0]=x1,y1,...) ─
    // Closed polygon with n vertices. push {r4..r11,lr} = 36 bytes.
    // Extra vertex pairs at [sp+36], [sp+40], [sp+44], ...
    s.push_str("@ vpy_draw_polygon(r0=n, r1=intensity, r2=x0, r3=y0, [sp+0]=x1,y1,...)\n");
    s.push_str(".global vpy_draw_polygon\n.type vpy_draw_polygon, %function\n.thumb_func\nvpy_draw_polygon:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}  @ 36 bytes\n");
    s.push_str("    mov     r4, r0              @ n (total vertices)\n");
    s.push_str("    mov     r5, r1              @ intensity\n");
    s.push_str("    mov     r6, r2              @ first_x\n");
    s.push_str("    mov     r7, r3              @ first_y\n");
    s.push_str("    add     r8, sp, #36         @ ptr to x1 (first extra stack arg)\n");
    s.push_str("    mov     r9, r6              @ prev_x = first_x\n");
    s.push_str("    mov     r10, r7             @ prev_y = first_y\n");
    s.push_str("    bl      dv_reset\n");
    s.push_str("    mov     r0, r5\n    bl      vpy_set_intensity\n");
    s.push_str("    mov     r0, r6\n    mov     r1, r7\n    bl      dv_move_to\n");
    s.push_str("    mov     r11, #1             @ vertex idx = 1\n");
    s.push_str("vdpoly_loop:\n");
    s.push_str("    cmp     r11, r4\n    bge     vdpoly_close\n");
    s.push_str("    ldr     r0, [r8]            @ xi\n");
    s.push_str("    ldr     r1, [r8, #4]        @ yi\n");
    s.push_str("    add     r8, r8, #8\n");
    s.push_str("    sub     r2, r0, r9          @ dx = xi - prev_x\n");
    s.push_str("    sub     r3, r1, r10         @ dy = yi - prev_y\n");
    s.push_str("    mov     r9, r0\n    mov     r10, r1\n");
    s.push_str("    mov     r0, r2\n    mov     r1, r3\n    bl      dv_draw_delta\n");
    s.push_str("    add     r11, r11, #1\n    b       vdpoly_loop\n");
    s.push_str("vdpoly_close:\n");
    s.push_str("    sub     r0, r6, r9          @ dx = first_x - prev_x\n");
    s.push_str("    sub     r1, r7, r10         @ dy = first_y - prev_y\n");
    s.push_str("    bl      dv_draw_delta\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    s
}

fn emit_draw_ellipse() -> String {
    let mut s = String::new();

    // ── vpy_draw_ellipse(r0=cx, r1=cy, r2=rx, r3=ry, [sp+0]=intensity) ──────
    // 16-segment parametric ellipse: x = cx + rx*cos(i*8)/127, y = cy + ry*sin(i*8)/127
    // push {r4..r11,lr} = 36 bytes + sub sp,#8 (locals) = 44 total → intensity at [sp+44].
    // [sp+0]=first_x, [sp+4]=first_y (for closure).
    // Registers: r4=cx, r5=cy, r6=rx, r7=ry, r8=prev_x, r9=prev_y, r10=i, r11=new_x.
    s.push_str("@ vpy_draw_ellipse(r0=cx, r1=cy, r2=rx, r3=ry, [sp+0]=intensity)\n");
    s.push_str("@ 16-segment parametric ellipse via sin/cos LUT\n");
    s.push_str(".global vpy_draw_ellipse\n.type vpy_draw_ellipse, %function\n.thumb_func\nvpy_draw_ellipse:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}  @ 36 bytes\n");
    s.push_str("    sub     sp, sp, #8          @ [sp+0]=first_x [sp+4]=first_y\n");
    s.push_str("    mov     r4, r0              @ cx\n");
    s.push_str("    mov     r5, r1              @ cy\n");
    s.push_str("    mov     r6, r2              @ rx\n");
    s.push_str("    mov     r7, r3              @ ry\n");
    s.push_str("    ldr     r8, [sp, #44]       @ intensity (8+36=44)\n");
    s.push_str("    bl      dv_reset\n");
    s.push_str("    mov     r0, r8\n    bl      vpy_set_intensity\n");
    // First point i=0: cos(0)=127 → prev_x = cx + rx; sin(0)=0 → prev_y = cy
    s.push_str("    mov     r0, #0\n    bl      vpy_cos\n");
    s.push_str("    mul     r0, r0, r6\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r8, r4, r0          @ prev_x = cx + rx*cos(0)/127\n");
    s.push_str("    str     r8, [sp, #0]        @ first_x\n");
    s.push_str("    mov     r0, #0\n    bl      vpy_sin\n");
    s.push_str("    mul     r0, r0, r7\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r9, r5, r0          @ prev_y = cy + ry*sin(0)/127\n");
    s.push_str("    str     r9, [sp, #4]        @ first_y\n");
    s.push_str("    mov     r0, r8\n    mov     r1, r9\n    bl      dv_move_to\n");
    s.push_str("    mov     r10, #1             @ i = 1\n");
    s.push_str("vde_loop:\n");
    s.push_str("    cmp     r10, #16\n    bge     vde_close\n");
    s.push_str("    lsl     r0, r10, #3         @ angle = i*8\n");
    s.push_str("    bl      vpy_cos\n");
    s.push_str("    mul     r0, r0, r6\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r11, r4, r0         @ new_x = cx + rx*cos/127\n");
    s.push_str("    lsl     r0, r10, #3\n");
    s.push_str("    bl      vpy_sin\n");
    s.push_str("    mul     r0, r0, r7\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r0, r5, r0          @ new_y\n");
    // Compute deltas while new values are still in r11/r0, before overwriting prev
    s.push_str("    sub     r2, r11, r8         @ dx = new_x - prev_x\n");
    s.push_str("    sub     r3, r0, r9          @ dy = new_y - prev_y\n");
    s.push_str("    mov     r8, r11             @ prev_x = new_x\n");
    s.push_str("    mov     r9, r0              @ prev_y = new_y\n");
    s.push_str("    mov     r0, r2\n    mov     r1, r3\n    bl      dv_draw_delta\n");
    s.push_str("    add     r10, r10, #1\n    b       vde_loop\n");
    s.push_str("vde_close:\n");
    s.push_str("    ldr     r0, [sp, #0]        @ first_x\n");
    s.push_str("    ldr     r1, [sp, #4]        @ first_y\n");
    s.push_str("    sub     r0, r0, r8          @ dx = first_x - prev_x\n");
    s.push_str("    sub     r1, r1, r9          @ dy = first_y - prev_y\n");
    s.push_str("    bl      dv_draw_delta\n");
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    s
}

fn emit_draw_arc() -> String {
    let mut s = String::new();

    // ── vpy_draw_arc(r0=segs, r1=cx, r2=cy, r3=r, [sp+0]=start_deg, [sp+4]=sweep_deg, [sp+8]=intensity) ──
    // Open arc from start_deg, sweeping sweep_deg degrees (CCW), in segs segments.
    // Angles converted to LUT indices: lut = deg * 128 / 360.
    // push {r4..r11,lr} = 36 bytes → [sp+36]=start, [sp+40]=sweep, [sp+44]=intensity.
    // Registers: r4=segs(counter), r5=cx, r6=cy, r7=radius, r8=current_angle, r9=step_size,
    //            r10=prev_x, r11=prev_y.
    s.push_str("@ vpy_draw_arc(r0=segs, r1=cx, r2=cy, r3=r, [sp+0]=start_deg, [sp+4]=sweep_deg, [sp+8]=intensity)\n");
    s.push_str(".global vpy_draw_arc\n.type vpy_draw_arc, %function\n.thumb_func\nvpy_draw_arc:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}  @ 36 bytes\n");
    s.push_str("    mov     r4, r0              @ segs (loop counter)\n");
    s.push_str("    mov     r5, r1              @ cx\n");
    s.push_str("    mov     r6, r2              @ cy\n");
    s.push_str("    mov     r7, r3              @ radius\n");
    // Convert start_deg → LUT step (0-127 = 0-360°)
    s.push_str("    ldr     r0, [sp, #36]       @ start_deg\n");
    s.push_str("    lsl     r0, r0, #7          @ * 128\n");
    s.push_str("    mov     r1, #360\n");
    s.push_str("    sdiv    r8, r0, r1          @ r8 = start_step\n");
    // Convert sweep_deg → step_size per segment
    s.push_str("    ldr     r0, [sp, #40]       @ sweep_deg\n");
    s.push_str("    lsl     r0, r0, #7\n");
    s.push_str("    sdiv    r0, r0, r1          @ sweep_steps (r1 still 360)\n");
    s.push_str("    cmp     r4, #0\n    beq     vpy_arc_done\n");
    s.push_str("    sdiv    r9, r0, r4          @ r9 = step_size = sweep_steps / segs\n");
    // Intensity
    s.push_str("    ldr     r0, [sp, #44]       @ intensity\n");
    s.push_str("    bl      dv_reset\n");
    s.push_str("    bl      vpy_set_intensity\n");
    // First point at start_angle
    s.push_str("    and     r0, r8, #127\n");
    s.push_str("    bl      vpy_cos\n");
    s.push_str("    mul     r0, r0, r7\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r10, r5, r0         @ prev_x = cx + r*cos(start)/127\n");
    s.push_str("    and     r0, r8, #127\n");
    s.push_str("    bl      vpy_sin\n");
    s.push_str("    mul     r0, r0, r7\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r11, r6, r0         @ prev_y = cy + r*sin(start)/127\n");
    s.push_str("    mov     r0, r10\n    mov     r1, r11\n    bl      dv_move_to\n");
    s.push_str("vpy_arc_loop:\n");
    s.push_str("    cmp     r4, #0\n    beq     vpy_arc_done\n");
    s.push_str("    add     r8, r8, r9          @ current_angle += step_size\n");
    s.push_str("    and     r0, r8, #127\n");
    s.push_str("    bl      vpy_cos\n");
    s.push_str("    mul     r0, r0, r7\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r0, r5, r0          @ new_x\n");
    s.push_str("    push    {r0}                @ save new_x (r0 clobbered by next bl)\n");
    s.push_str("    and     r0, r8, #127\n");
    s.push_str("    bl      vpy_sin\n");
    s.push_str("    mul     r0, r0, r7\n    mov     r1, #127\n    sdiv    r0, r0, r1\n");
    s.push_str("    add     r1, r6, r0          @ new_y\n");
    s.push_str("    pop     {r0}                @ restore new_x\n");
    s.push_str("    sub     r2, r0, r10         @ dx = new_x - prev_x\n");
    s.push_str("    sub     r3, r1, r11         @ dy = new_y - prev_y\n");
    s.push_str("    mov     r10, r0             @ prev_x = new_x\n");
    s.push_str("    mov     r11, r1             @ prev_y = new_y\n");
    s.push_str("    mov     r0, r2\n    mov     r1, r3\n    bl      dv_draw_delta\n");
    s.push_str("    sub     r4, r4, #1\n    b       vpy_arc_loop\n");
    s.push_str("vpy_arc_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    s
}

/// Emit vpy_draw_bezier and vpy_draw_bezier_quad as ARM Thumb2 functions.
///
/// Cubic De Casteljau — no push/pop inside the loop.
/// Stack: push {r4..r11,lr} = 36 bytes + sub sp,#36 = 36 bytes → total 72 (8-byte aligned).
///
/// Locals (9 words, [sp+0..sp+32]):
///   [sp+0]  = steps_total      [sp+4]  = t_num
///   [sp+8]  = prev_x           [sp+12] = prev_y
///   [sp+16] = t256
///   [sp+20] = q0x → r0x       [sp+24] = q0y → r0y  (dual-use after Level-2)
///   [sp+28] = q1x → r1x       [sp+32] = q1y → r1y  (dual-use after Level-2)
///
/// Caller args (6 words) at sp+72:
///   [sp+72]=cp2x [sp+76]=cp2y [sp+80]=x1 [sp+84]=y1 [sp+88]=steps [sp+92]=intensity
fn emit_draw_bezier_cubic() -> String {
    let mut s = String::new();
    // ── cubic ──────────────────────────────────────────────────────────────────
    s.push_str("@ vpy_draw_bezier(x0,y0,cp1x,cp1y,[sp+0]=cp2x,cp2y,x1,y1,steps,intensity)\n");
    s.push_str(".global vpy_draw_bezier\n.type vpy_draw_bezier, %function\n.thumb_func\nvpy_draw_bezier:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");    // 36 bytes
    s.push_str("    sub     sp, sp, #36\n");                                 // 9 slots; total=72
    s.push_str("    mov     r4, r0\n    mov     r5, r1\n    mov     r6, r2\n    mov     r7, r3\n");
    s.push_str("    ldr     r8,  [sp, #72]      @ cp2x\n");
    s.push_str("    ldr     r9,  [sp, #76]      @ cp2y\n");
    s.push_str("    ldr     r10, [sp, #80]      @ x1\n");
    s.push_str("    ldr     r11, [sp, #84]      @ y1\n");
    s.push_str("    ldr     r1,  [sp, #88]      @ steps\n");
    s.push_str("    ldr     r0,  [sp, #92]      @ intensity\n");
    s.push_str("    cmp     r1, #1\n    blt     vbez_done\n");
    s.push_str("    str     r1, [sp]\n");                                    // steps_total
    s.push_str("    mov     r1, #1\n    str     r1, [sp, #4]\n");            // t_num = 1
    s.push_str("    bl      dv_reset\n    bl      vpy_set_intensity\n");
    s.push_str("    mov     r0, r4\n    mov     r1, r5\n    bl      dv_move_to\n");
    s.push_str("    str     r4, [sp, #8]\n    str     r5, [sp, #12]\n");     // prev = P0

    s.push_str("vbez_loop:\n");
    s.push_str("    ldr     r0, [sp, #4]\n    ldr     r1, [sp]\n");          // t_num, steps_total
    s.push_str("    cmp     r0, r1\n    bgt     vbez_done\n");
    s.push_str("    lsl     r2, r0, #8\n    sdiv    r2, r2, r1\n");          // t256 = t_num*256/steps
    // r2 = t256 preserved through all lerps (mul writes target, never r2)

    // Level-1: store q0x/q0y/q1x/q1y to [sp+20..32]; q2x→r1, q2y→r3
    s.push_str("    sub     r0, r6, r4\n    mul     r0, r0, r2\n    asr     r0, r0, #8\n    add     r0, r0, r4\n    str     r0, [sp, #20]\n"); // q0x
    s.push_str("    sub     r0, r7, r5\n    mul     r0, r0, r2\n    asr     r0, r0, #8\n    add     r0, r0, r5\n    str     r0, [sp, #24]\n"); // q0y
    s.push_str("    sub     r0, r8, r6\n    mul     r0, r0, r2\n    asr     r0, r0, #8\n    add     r0, r0, r6\n    str     r0, [sp, #28]\n"); // q1x
    s.push_str("    sub     r0, r9, r7\n    mul     r0, r0, r2\n    asr     r0, r0, #8\n    add     r0, r0, r7\n    str     r0, [sp, #32]\n"); // q1y
    s.push_str("    sub     r1, r10, r8\n    mul     r1, r1, r2\n    asr     r1, r1, #8\n    add     r1, r1, r8\n"); // q2x → r1
    s.push_str("    sub     r3, r11, r9\n    mul     r3, r3, r2\n    asr     r3, r3, #8\n    add     r3, r3, r9\n"); // q2y → r3

    // Level-2: overwrite [sp+20..32] with r0x,r0y,r1x,r1y (dual-use slots)
    // r0x = lerp(q0x=[sp+20], q1x=[sp+28], t) → store at [sp+20]
    s.push_str("    ldr     r12, [sp, #20]\n    ldr     r0, [sp, #28]\n");
    s.push_str("    sub     r0, r0, r12\n    mul     r0, r0, r2\n    asr     r0, r0, #8\n    add     r0, r0, r12\n    str     r0, [sp, #20]\n");
    // r0y = lerp(q0y=[sp+24], q1y=[sp+32], t) → store at [sp+24]
    s.push_str("    ldr     r12, [sp, #24]\n    ldr     r0, [sp, #32]\n");
    s.push_str("    sub     r0, r0, r12\n    mul     r0, r0, r2\n    asr     r0, r0, #8\n    add     r0, r0, r12\n    str     r0, [sp, #24]\n");
    // r1x = lerp(q1x=[sp+28], q2x=r1, t) → store at [sp+28]
    s.push_str("    ldr     r12, [sp, #28]\n");
    s.push_str("    sub     r1, r1, r12\n    mul     r1, r1, r2\n    asr     r1, r1, #8\n    add     r1, r1, r12\n    str     r1, [sp, #28]\n");
    // r1y = lerp(q1y=[sp+32], q2y=r3, t) → store at [sp+32]
    s.push_str("    ldr     r12, [sp, #32]\n");
    s.push_str("    sub     r3, r3, r12\n    mul     r3, r3, r2\n    asr     r3, r3, #8\n    add     r3, r3, r12\n    str     r3, [sp, #32]\n");

    // Level-3: bx = lerp(r0x=[sp+20], r1x=[sp+28], t); by = lerp(r0y=[sp+24], r1y=[sp+32], t)
    s.push_str("    ldr     r12, [sp, #20]\n    ldr     r0, [sp, #28]\n");
    s.push_str("    sub     r0, r0, r12\n    mul     r0, r0, r2\n    asr     r0, r0, #8\n    add     r0, r0, r12\n"); // bx → r0
    s.push_str("    ldr     r12, [sp, #24]\n    ldr     r1, [sp, #32]\n");
    s.push_str("    sub     r1, r1, r12\n    mul     r1, r1, r2\n    asr     r1, r1, #8\n    add     r1, r1, r12\n"); // by → r1

    // Compute delta from prev and call dv_draw_delta(dx, dy)
    s.push_str("    ldr     r2, [sp, #8]        @ prev_x\n");
    s.push_str("    ldr     r3, [sp, #12]       @ prev_y\n");
    s.push_str("    str     r0, [sp, #8]        @ prev_x = bx\n");
    s.push_str("    str     r1, [sp, #12]       @ prev_y = by\n");
    s.push_str("    sub     r0, r0, r2          @ dx = bx - prev_x\n");
    s.push_str("    sub     r1, r1, r3          @ dy = by - prev_y\n");
    s.push_str("    bl      dv_draw_delta\n");

    // t_num++
    s.push_str("    ldr     r0, [sp, #4]\n    add     r0, r0, #1\n    str     r0, [sp, #4]\n");
    s.push_str("    b       vbez_loop\n");

    s.push_str("vbez_done:\n");
    s.push_str("    add     sp, sp, #36\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    s
}

fn emit_draw_bezier_quad() -> String {
    let mut s = String::new();
    // ── quadratic ─────────────────────────────────────────────────────────────
    // vpy_draw_bezier_quad(r0=x0, r1=y0, r2=cpx, r3=cpy,
    //   [sp+0]=x1, [sp+4]=y1, [sp+8]=steps, [sp+12]=intensity)
    // push {r4..r9,lr} = 28 bytes; sub sp,#28 = 28 bytes → total 56 (8-byte aligned).
    // Locals: [sp+0]=steps [sp+4]=t_num [sp+8]=prev_x [sp+12]=prev_y [sp+16]=t256 [sp+20]=bx_tmp
    // Caller args at sp+56: [sp+56]=x1 [sp+60]=y1 [sp+64]=steps [sp+68]=intensity
    s.push_str("@ vpy_draw_bezier_quad(x0,y0,cpx,cpy,[sp+0]=x1,y1,steps,intensity)\n");
    s.push_str(".global vpy_draw_bezier_quad\n.type vpy_draw_bezier_quad, %function\n.thumb_func\nvpy_draw_bezier_quad:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n");    // 28 bytes
    s.push_str("    sub     sp, sp, #28\n");                       // 7 slots; total=56
    s.push_str("    mov     r4, r0\n    mov     r5, r1\n    mov     r6, r2\n    mov     r7, r3\n");
    s.push_str("    ldr     r8, [sp, #56]       @ x1\n");
    s.push_str("    ldr     r9, [sp, #60]       @ y1\n");
    s.push_str("    ldr     r1, [sp, #64]       @ steps\n");
    s.push_str("    ldr     r0, [sp, #68]       @ intensity\n");
    s.push_str("    cmp     r1, #1\n    blt     vbezq_done\n");
    s.push_str("    str     r1, [sp]\n");
    s.push_str("    mov     r1, #1\n    str     r1, [sp, #4]\n");
    s.push_str("    bl      dv_reset\n    bl      vpy_set_intensity\n");
    s.push_str("    mov     r0, r4\n    mov     r1, r5\n    bl      dv_move_to\n");
    s.push_str("    str     r4, [sp, #8]\n    str     r5, [sp, #12]\n");

    s.push_str("vbezq_loop:\n");
    s.push_str("    ldr     r0, [sp, #4]\n    ldr     r1, [sp]\n");
    s.push_str("    cmp     r0, r1\n    bgt     vbezq_done\n");
    s.push_str("    lsl     r2, r0, #8\n    sdiv    r2, r2, r1\n"); // t256

    // Quadratic De Casteljau: q0=lerp(P0,CP), q1=lerp(CP,P1), b=lerp(q0,q1)
    // x: r3=q0x, r0=q1x, then bx=lerp(q0x,q1x)
    s.push_str("    sub     r3, r6, r4\n    mul     r3, r3, r2\n    asr     r3, r3, #8\n    add     r3, r3, r4\n"); // q0x → r3
    s.push_str("    sub     r0, r8, r6\n    mul     r0, r0, r2\n    asr     r0, r0, #8\n    add     r0, r0, r6\n"); // q1x → r0
    s.push_str("    sub     r0, r0, r3\n    mul     r0, r0, r2\n    asr     r0, r0, #8\n    add     r0, r0, r3\n    str     r0, [sp, #20]\n"); // bx
    // y: r3=q0y, r1=q1y, then by=lerp(q0y,q1y)
    s.push_str("    sub     r3, r7, r5\n    mul     r3, r3, r2\n    asr     r3, r3, #8\n    add     r3, r3, r5\n"); // q0y → r3
    s.push_str("    sub     r1, r9, r7\n    mul     r1, r1, r2\n    asr     r1, r1, #8\n    add     r1, r1, r7\n"); // q1y → r1
    s.push_str("    sub     r1, r1, r3\n    mul     r1, r1, r2\n    asr     r1, r1, #8\n    add     r1, r1, r3\n"); // by → r1

    s.push_str("    ldr     r0, [sp, #20]       @ bx\n");
    s.push_str("    ldr     r2, [sp, #8]        @ prev_x\n");
    s.push_str("    ldr     r3, [sp, #12]       @ prev_y\n");
    s.push_str("    str     r0, [sp, #8]        @ prev_x = bx\n");
    s.push_str("    str     r1, [sp, #12]       @ prev_y = by\n");
    s.push_str("    sub     r0, r0, r2          @ dx\n");
    s.push_str("    sub     r1, r1, r3          @ dy\n");
    s.push_str("    bl      dv_draw_delta\n");
    s.push_str("    ldr     r0, [sp, #4]\n    add     r0, r0, #1\n    str     r0, [sp, #4]\n");
    s.push_str("    b       vbezq_loop\n");

    s.push_str("vbezq_done:\n");
    s.push_str("    add     sp, sp, #28\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n    .ltorg\n\n");

    s
}

// ─── PRINT_TEXT ────────────────────────────────────────────────────────────
//
// Font: stroke-based, 4×6 glyph box, ASCII 32-90.
// Each glyph: sequence of [cmd, x, y] triples (cmd=0x01 move, 0x02 draw, 0x00 end).
// _FONT_PTRS[char-32]: 32-bit absolute address of glyph data (0 = no strokes).
// Character advance: 5 × text_size units.
//
// print_text calls dv_reset() first, then positions beam at (x, y).
// Beam position tracked in PRINT_BEAM_X / PRINT_BEAM_Y.

/// Glyph data shared by ARM/PiTrex font emission and the M6809 custom
/// font path. Returns (ascii, Vec<(cmd, glyph_x, glyph_y)>) where cmd=1=MOVE
/// (beam off), cmd=2=DRAW (beam on); glyph_x in 0..4, glyph_y in 0..6 with
/// y=0 bottom, y=6 top.
fn font_glyphs() -> Vec<(u8, Vec<(u8, u8, u8)>)> {
    // (ascii, [(cmd=1 move | 2 draw, glyph_x 0..4, glyph_y 0..6)])
    // y=0 bottom, y=6 top; glyph box width=4
    let mut g: Vec<(u8, Vec<(u8, u8, u8)>)> = vec![
        (b' ', vec![]),  // space: no strokes, just advance
        (b'!', vec![(1,2,6),(2,2,2),(1,2,0),(2,2,1)]),
        (b'"', vec![(1,1,5),(2,1,6),(1,3,5),(2,3,6)]),
        (b'+', vec![(1,2,1),(2,2,5),(1,0,3),(2,4,3)]),
        (b',', vec![(1,2,1),(2,1,0)]),
        (b'-', vec![(1,0,3),(2,4,3)]),
        (b'.', vec![(1,1,0),(2,2,0)]),
        (b'/', vec![(1,0,0),(2,4,6)]),
        (b'0', vec![(1,0,0),(2,4,0),(2,4,6),(2,0,6),(2,0,0)]),
        (b'1', vec![(1,2,0),(2,2,6)]),
        (b'2', vec![(1,0,6),(2,4,6),(2,4,3),(2,0,3),(2,0,0),(2,4,0)]),
        (b'3', vec![(1,0,6),(2,4,6),(2,4,0),(2,0,0),(1,4,3),(2,1,3)]),
        (b'4', vec![(1,0,6),(2,0,3),(2,4,3),(1,4,6),(2,4,0)]),
        (b'5', vec![(1,4,6),(2,0,6),(2,0,3),(2,4,3),(2,4,0),(2,0,0)]),
        (b'6', vec![(1,4,6),(2,0,6),(2,0,0),(2,4,0),(2,4,3),(2,0,3)]),
        (b'7', vec![(1,0,6),(2,4,6),(2,2,0)]),
        (b'8', vec![(1,0,0),(2,4,0),(2,4,6),(2,0,6),(2,0,0),(1,0,3),(2,4,3)]),
        (b'9', vec![(1,4,0),(2,4,6),(2,0,6),(2,0,3),(2,4,3)]),
        (b':', vec![(1,2,1),(2,2,2),(1,2,4),(2,2,5)]),
        (b';', vec![(1,2,4),(2,2,5),(1,2,1),(2,1,0)]),
        (b'<', vec![(1,3,6),(2,0,3),(2,3,0)]),
        (b'=', vec![(1,0,4),(2,4,4),(1,0,2),(2,4,2)]),
        (b'>', vec![(1,1,6),(2,4,3),(2,1,0)]),
        (b'?', vec![(1,0,6),(2,4,6),(2,4,4),(2,2,3),(1,2,1),(2,2,2)]),
        (b'A', vec![(1,0,0),(2,2,6),(2,4,0),(1,0,3),(2,4,3)]),
        (b'B', vec![(1,0,0),(2,0,6),(2,3,6),(2,3,3),(2,0,3),(2,3,3),(2,3,0),(2,0,0)]),
        (b'C', vec![(1,4,6),(2,0,6),(2,0,0),(2,4,0)]),
        (b'D', vec![(1,0,0),(2,0,6),(2,3,6),(2,4,5),(2,4,1),(2,3,0),(2,0,0)]),
        (b'E', vec![(1,4,0),(2,0,0),(2,0,6),(2,4,6),(1,0,3),(2,3,3)]),
        (b'F', vec![(1,0,0),(2,0,6),(2,4,6),(1,0,3),(2,3,3)]),
        (b'G', vec![(1,4,6),(2,0,6),(2,0,0),(2,4,0),(2,4,3),(2,2,3)]),
        (b'H', vec![(1,0,0),(2,0,6),(1,4,0),(2,4,6),(1,0,3),(2,4,3)]),
        (b'I', vec![(1,1,0),(2,3,0),(1,2,0),(2,2,6),(1,1,6),(2,3,6)]),
        (b'J', vec![(1,0,1),(2,1,0),(2,4,0),(2,4,6),(1,1,6),(2,3,6)]),
        (b'K', vec![(1,0,0),(2,0,6),(1,0,3),(2,4,6),(1,0,3),(2,4,0)]),
        (b'L', vec![(1,0,6),(2,0,0),(2,4,0)]),
        (b'M', vec![(1,0,0),(2,0,6),(2,2,3),(2,4,6),(2,4,0)]),
        (b'N', vec![(1,0,0),(2,0,6),(2,4,0),(2,4,6)]),
        (b'O', vec![(1,0,0),(2,4,0),(2,4,6),(2,0,6),(2,0,0)]),
        (b'P', vec![(1,0,0),(2,0,6),(2,3,6),(2,4,5),(2,4,4),(2,3,3),(2,0,3)]),
        (b'Q', vec![(1,0,0),(2,4,0),(2,4,6),(2,0,6),(2,0,0),(1,3,1),(2,4,0)]),
        (b'R', vec![(1,0,0),(2,0,6),(2,3,6),(2,4,5),(2,4,4),(2,3,3),(2,0,3),(2,4,0)]),
        (b'S', vec![(1,4,6),(2,0,6),(2,0,3),(2,4,3),(2,4,0),(2,0,0)]),
        (b'T', vec![(1,0,6),(2,4,6),(1,2,6),(2,2,0)]),
        (b'U', vec![(1,0,6),(2,0,0),(2,4,0),(2,4,6)]),
        (b'V', vec![(1,0,6),(2,2,0),(2,4,6)]),
        (b'W', vec![(1,0,6),(2,1,0),(2,2,3),(2,3,0),(2,4,6)]),
        (b'X', vec![(1,0,0),(2,4,6),(1,0,6),(2,4,0)]),
        (b'Y', vec![(1,0,6),(2,2,3),(2,4,6),(1,2,3),(2,2,0)]),
        (b'Z', vec![(1,0,6),(2,4,6),(2,0,0),(2,4,0)]),
    ];
    // lowercase maps to uppercase
    for i in 0..26u8 {
        let uc = b'A' + i;
        if let Some(idx) = g.iter().position(|(c, _)| *c == uc) {
            let strokes = g[idx].1.clone();
            g.push((b'a' + i, strokes));
        }
    }
    g
}

fn emit_font_data() -> String {
    let glyphs = font_glyphs();
    let mut s = String::new();

    s.push_str("@ ============================================================\n");
    s.push_str("@ Vector font — ASCII 32-126 stroke data\n");
    s.push_str("@ Each glyph: [cmd(1=move,2=draw), x(0-4), y(0-6), ..., 0x00]\n");
    s.push_str("@ _FONT_PTRS[char-32] = absolute address of glyph (0 = no strokes)\n");
    s.push_str("@ ============================================================\n\n");

    // Build lookup: char → label
    let mut label_map: std::collections::HashMap<u8, String> = std::collections::HashMap::new();
    for (ch, strokes) in &glyphs {
        if !strokes.is_empty() {
            label_map.insert(*ch, format!("_glyph_{:03}", ch));
        }
    }

    // Emit pointer table for chars 32-126 (95 chars, 4 bytes each = 380 bytes)
    s.push_str(".global _FONT_PTRS\n_FONT_PTRS:\n");
    for c in 32u8..=126 {
        if let Some(lbl) = label_map.get(&c) {
            s.push_str(&format!("    .word   {}   @ '{}'\n", lbl, c as char));
        } else {
            s.push_str(&format!("    .word   0    @ '{}' no strokes\n", c as char));
        }
    }
    s.push('\n');

    // Emit glyph data
    s.push_str(".global _FONT_DATA\n_FONT_DATA:\n");
    let mut sorted = glyphs;
    sorted.sort_by_key(|(c, _)| *c);
    for (ch, strokes) in &sorted {
        if strokes.is_empty() { continue; }
        let lbl = label_map.get(ch).unwrap();
        s.push_str(&format!("{}:  @ '{}'\n", lbl, *ch as char));
        for (cmd, x, y) in strokes {
            s.push_str(&format!("    .byte   {}, {}, {}\n", cmd, x, y));
        }
        s.push_str("    .byte   0\n");  // end marker
    }
    s.push('\n');
    s
}

fn emit_print_text() -> String {
    let mut s = String::new();
    s.push_str("@ vpy_print_text(r0=x, r1=y, r2=str_ptr)\n");
    s.push_str("@ Draws null-terminated or $80-terminated ASCII string at (x, y).\n");
    s.push_str("@ Uses TEXT_SIZE for scale, TEXT_COLOR for intensity.\n");
    s.push_str(".global vpy_print_text\n.type vpy_print_text, %function\n.thumb_func\nvpy_print_text:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n"); // 9 regs = 36 bytes
    s.push_str("    mov     r4, r0              @ x\n");
    s.push_str("    mov     r5, r1              @ y\n");
    s.push_str("    mov     r6, r2              @ str_ptr\n");

    // Load text_size and text_color from RAM
    s.push_str("    ldr     r7, =TEXT_SIZE\n    ldr     r7, [r7]\n"); // r7 = scale
    s.push_str("    cmp     r7, #0\n    bne     vpt_scale_ok\n    mov     r7, #1\n");
    s.push_str("vpt_scale_ok:\n");
    s.push_str("    ldr     r8, =TEXT_COLOR\n    ldr     r8, [r8]\n"); // r8 = color
    s.push_str("    cmp     r8, #0\n    bne     vpt_color_ok\n    mov     r8, #100\n"); // default brightness
    s.push_str("vpt_color_ok:\n");

    // Reset and position beam
    s.push_str("    bl      dv_reset\n");
    s.push_str("    mov     r0, r8\n    bl      vpy_set_intensity\n");
    s.push_str("    mov     r0, r4\n    mov     r1, r5\n    bl      dv_move_to\n");
    s.push_str("    ldr     r9, =PRINT_BEAM_X\n    str     r4, [r9]\n");
    s.push_str("    ldr     r10, =PRINT_BEAM_Y\n    str     r5, [r10]\n");

    // r11 = cur_x (current character start x)
    s.push_str("    mov     r11, r4\n");

    // Main character loop
    s.push_str("vpt_loop:\n");
    s.push_str("    ldrb    r0, [r6]\n"); // load char
    s.push_str("    cmp     r0, #0\n    beq     vpt_done\n"); // null terminator
    s.push_str("    cmp     r0, #0x80\n    beq     vpt_done\n"); // Vectrex $80 terminator
    s.push_str("    add     r6, r6, #1\n"); // advance string ptr

    // Fold lowercase to uppercase
    s.push_str("    cmp     r0, #0x61\n    blt     vpt_not_lower\n");
    s.push_str("    cmp     r0, #0x7A\n    bgt     vpt_not_lower\n");
    s.push_str("    sub     r0, r0, #0x20\n"); // 'a'-'A'
    s.push_str("vpt_not_lower:\n");

    // Bounds check: char must be 32-126
    s.push_str("    cmp     r0, #32\n    blt     vpt_advance\n");
    s.push_str("    cmp     r0, #126\n    bgt     vpt_advance\n");

    // Load glyph pointer: _FONT_PTRS[(char-32)*4]
    s.push_str("    sub     r0, r0, #32\n");
    s.push_str("    ldr     r1, =_FONT_PTRS\n");
    s.push_str("    lsl     r0, r0, #2\n    ldr     r0, [r1, r0]\n"); // glyph_ptr
    s.push_str("    cmp     r0, #0\n    beq     vpt_advance\n"); // no strokes for this char

    // Move beam from current beam pos to char start (r11, r5)
    s.push_str("    ldr     r1, =PRINT_BEAM_X\n    ldr     r2, [r1]\n"); // r2 = beam_x
    s.push_str("    ldr     r3, =PRINT_BEAM_Y\n    ldr     r3, [r3]\n"); // r3 = beam_y
    s.push_str("    sub     r1, r11, r2\n"); // dx = char_x - beam_x
    s.push_str("    sub     r3, r5, r3\n"); // dy = char_y - beam_y
    s.push_str("    push    {r0, r3}\n"); // save glyph_ptr and dy
    s.push_str("    mov     r0, r1\n    pop     {r2}\n    push    {r2}\n"); // dx, dy
    // Actually let me restructure: save glyph_ptr, compute beam move
    // r0 = glyph_ptr saved above; r1=dx, r3=dy
    s.push_str("    push    {r0}\n"); // push glyph_ptr
    // We have dx in r1 (= r11 - beam_x), dy in r3 (= r5 - beam_y).  Wait, r3 was overwritten.
    // Let me redo this properly.
    // Actually I messed up the register flow. Let me restructure draw_glyph call.

    // OK, let's use a simpler flow: call a helper that handles everything.
    // r0 = glyph_ptr (saved), r11 = char_x, r5 = char_y, r7 = scale, r9/r10 = PRINT_BEAM_X/Y ptrs
    // Restore and call draw_glyph
    s.push_str("    pop     {r0}            @ glyph_ptr\n");
    s.push_str("    mov     r1, r11         @ char_x\n");
    s.push_str("    mov     r2, r5          @ char_y\n");
    s.push_str("    mov     r3, r7          @ scale\n");
    s.push_str("    bl      vpt_draw_glyph\n");

    s.push_str("vpt_advance:\n");
    // cur_x += 5 * scale
    s.push_str("    mov     r0, #5\n    mul     r0, r0, r7\n");
    s.push_str("    add     r11, r11, r0\n");
    s.push_str("    b       vpt_loop\n");

    s.push_str("vpt_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    // --- vpt_draw_glyph helper ---
    // r0=glyph_ptr, r1=char_x, r2=char_y, r3=scale
    // reads/writes PRINT_BEAM_X, PRINT_BEAM_Y
    s.push_str("@ vpt_draw_glyph(r0=glyph_ptr, r1=char_x, r2=char_y, r3=scale)\n");
    s.push_str(".type vpt_draw_glyph, %function\n.thumb_func\nvpt_draw_glyph:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n"); // 7×4=28 bytes
    s.push_str("    mov     r4, r0              @ glyph_ptr\n");
    s.push_str("    mov     r5, r1              @ char_x\n");
    s.push_str("    mov     r6, r2              @ char_y\n");
    s.push_str("    mov     r7, r3              @ scale\n");
    // r8 = beam_x (current), r9 = beam_y
    s.push_str("    ldr     r0, =PRINT_BEAM_X\n    ldr     r8, [r0]\n");
    s.push_str("    ldr     r0, =PRINT_BEAM_Y\n    ldr     r9, [r0]\n");

    s.push_str("vdg_loop:\n");
    s.push_str("    ldrb    r0, [r4]            @ cmd\n");
    s.push_str("    cmp     r0, #0\n    beq     vdg_done\n");
    s.push_str("    ldrb    r1, [r4, #1]        @ gx (0-4)\n");
    s.push_str("    ldrb    r2, [r4, #2]        @ gy (0-6)\n");
    s.push_str("    add     r4, r4, #3\n");
    // target_x = char_x + gx * scale
    s.push_str("    mul     r1, r1, r7\n    add     r1, r1, r5\n"); // target_x
    // target_y = char_y + gy * scale
    s.push_str("    mul     r2, r2, r7\n    add     r2, r2, r6\n"); // target_y
    // dx = target_x - beam_x; dy = target_y - beam_y
    s.push_str("    sub     r3, r1, r8          @ dx\n");
    s.push_str("    push    {r0, r1, r2}\n"); // save cmd, target_x, target_y
    s.push_str("    sub     r1, r2, r9          @ dy\n");
    s.push_str("    mov     r0, r3              @ dx\n");
    s.push_str("    pop     {r3}\n"); // r3 = cmd; target_x and target_y still on stack
    s.push_str("    push    {r3}\n"); // push cmd back
    // actually this register dance is getting complicated. Let me use a simpler approach.
    // Save new_beam_x/y in r8/r9 first, then call.
    s.pop(); // undo the last push
    s.pop(); // undo pop {r3}
    s.pop(); // undo push {r0,r1,r2}
    s.pop(); // undo sub r3,r1,r8
    // Let me just directly compute:
    s.push_str("    sub     r10, r1, r8         @ dx = target_x - beam_x\n");
    s.push_str("    sub     r11, r2, r9         @ dy = target_y - beam_y\n");
    s.push_str("    push    {r0, r1, r2}\n"); // save cmd, target_x, target_y
    s.push_str("    mov     r0, r10\n    mov     r1, r11\n"); // dx, dy for call
    s.push_str("    pop     {r3}\n"); // r3 = cmd
    s.push_str("    push    {r3}\n"); // still need target_x, target_y on stack
    // Hmm, this is getting messy with push/pop. Let me use a completely different approach.

    // The issue is we need both dx/dy for the call AND target_x/target_y to update beam_x/y.
    // Solution: compute dx/dy, then update beam_x/y before the call (since we know the targets).

    // Let me re-do from vdg_loop cleanly:
    // Scratch r10, r11 for temp:
    s.clear(); // Start over this function

    // Redo the whole print_text + draw_glyph cleanly
    emit_print_text_clean()
}

fn emit_print_text_clean() -> String {
    let mut s = String::new();

    // ─── vpy_print_text ───────────────────────────────────────────────────
    s.push_str("@ vpy_print_text(r0=x, r1=y, r2=str_ptr)\n");
    s.push_str(".global vpy_print_text\n.type vpy_print_text, %function\n.thumb_func\nvpy_print_text:\n");
    // Save: r4=x, r5=y, r6=str_ptr, r7=scale, r8=color, r9=cur_x, r10=BEAM_X ptr, r11=BEAM_Y ptr
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    mov     r4, r0\n    mov     r5, r1\n    mov     r6, r2\n");

    s.push_str("    ldr     r7, =TEXT_SIZE\n    ldr     r7, [r7]\n");
    // Scale is stored as 2× the effective multiplier so non-integer sizes are possible.
    // TEXT_SIZE=2 → effective ×1.0,  TEXT_SIZE=3 → effective ×1.5,  TEXT_SIZE=4 → effective ×2.0
    s.push_str("    cmp     r7, #0\n    bne     vpt_sc\n    mov     r7, #3\nvpt_sc:\n");
    s.push_str("    ldr     r8, =TEXT_COLOR\n    ldr     r8, [r8]\n");
    s.push_str("    cmp     r8, #0\n    bne     vpt_cc\n    mov     r8, #100\nvpt_cc:\n");

    s.push_str("    bl      dv_reset\n");
    s.push_str("    mov     r0, r8\n    bl      vpy_set_intensity\n");
    // ARM font: glyph_y=0 is bottom of glyph, glyph_y=6 is top.
    // VPy convention: y parameter = top of text. Convert to glyph-bottom so the
    // top of the glyph aligns with the requested y position.
    // glyph_height = (6 * scale) >> 1; adjusted_y = y - glyph_height
    s.push_str("    mov     r0, #6\n    mul     r0, r0, r7\n    asr     r0, r0, #1\n    sub     r5, r5, r0\n");
    s.push_str("    mov     r0, r4\n    mov     r1, r5\n    bl      dv_move_to\n");

    s.push_str("    ldr     r10, =PRINT_BEAM_X\n    str     r4, [r10]\n");
    s.push_str("    ldr     r11, =PRINT_BEAM_Y\n    str     r5, [r11]\n");
    s.push_str("    mov     r9, r4              @ cur_x = x\n");

    s.push_str("vpt_loop:\n");
    s.push_str("    ldrb    r0, [r6]\n    add     r6, r6, #1\n");
    s.push_str("    cmp     r0, #0\n    beq     vpt_done\n");
    s.push_str("    cmp     r0, #0x80\n    beq     vpt_done\n");
    // fold lowercase
    s.push_str("    cmp     r0, #0x61\n    blt     vpt_nl\n");
    s.push_str("    cmp     r0, #0x7A\n    bgt     vpt_nl\n");
    s.push_str("    sub     r0, r0, #0x20\nvpt_nl:\n");
    // bounds
    s.push_str("    cmp     r0, #32\n    blt     vpt_adv\n");
    s.push_str("    cmp     r0, #126\n    bgt     vpt_adv\n");
    // load glyph ptr
    s.push_str("    sub     r0, r0, #32\n");
    s.push_str("    ldr     r1, =_FONT_PTRS\n    lsl     r0, r0, #2\n    ldr     r0, [r1, r0]\n");
    s.push_str("    cmp     r0, #0\n    beq     vpt_adv\n");
    // call draw_glyph(glyph_ptr, cur_x, cur_y, scale, beam_x_ptr, beam_y_ptr)
    s.push_str("    mov     r1, r9\n    mov     r2, r5\n    mov     r3, r7\n");
    s.push_str("    push    {r10, r11}\n"); // pass BEAM_X/Y ptrs via stack
    s.push_str("    bl      vpt_draw_glyph\n");
    s.push_str("    add     sp, sp, #8\n"); // clean up the 2 extra stack args
    s.push_str("vpt_adv:\n");
    s.push_str("    mov     r0, #7\n    mul     r0, r0, r7\n    asr     r0, r0, #1\n    add     r9, r9, r0\n");
    s.push_str("    b       vpt_loop\n");
    s.push_str("vpt_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    // ─── vpt_draw_glyph(r0=ptr, r1=char_x, r2=char_y, r3=scale, [sp+0]=bx_ptr, [sp+4]=by_ptr)
    s.push_str("@ vpt_draw_glyph — internal: draw one glyph at (char_x, char_y) with scale\n");
    s.push_str(".type vpt_draw_glyph, %function\n.thumb_func\nvpt_draw_glyph:\n");
    // save r4-r11
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n"); // 9×4=36 bytes
    s.push_str("    mov     r4, r0              @ glyph_ptr\n");
    s.push_str("    mov     r5, r1              @ char_x\n");
    s.push_str("    mov     r6, r2              @ char_y\n");
    s.push_str("    mov     r7, r3              @ scale\n");
    // load beam ptrs from stack (past 9 saved regs = 36 bytes + 8 bytes for the push we did in caller)
    s.push_str("    ldr     r8, [sp, #36]       @ bx_ptr (PRINT_BEAM_X)\n");
    s.push_str("    ldr     r9, [sp, #40]       @ by_ptr (PRINT_BEAM_Y)\n");
    s.push_str("    ldr     r10, [r8]           @ beam_x\n");
    s.push_str("    ldr     r11, [r9]           @ beam_y\n");

    s.push_str("vdg_loop:\n");
    s.push_str("    ldrb    r0, [r4]\n");
    s.push_str("    cmp     r0, #0\n    beq     vdg_done\n");
    s.push_str("    ldrb    r1, [r4, #1]        @ gx\n");
    s.push_str("    ldrb    r2, [r4, #2]        @ gy\n");
    s.push_str("    add     r4, r4, #3\n");
    s.push_str("    push    {r0}               @ save cmd\n");
    // target_x = char_x + (gx * scale) >> 1  (scale is 2× effective multiplier)
    s.push_str("    mul     r1, r1, r7\n    asr     r1, r1, #1\n    add     r1, r1, r5\n"); // r1 = target_x
    // target_y = char_y + (gy * scale) >> 1
    s.push_str("    mul     r2, r2, r7\n    asr     r2, r2, #1\n    add     r2, r2, r6\n"); // r2 = target_y
    // dx = target_x - beam_x; dy = target_y - beam_y
    s.push_str("    sub     r0, r1, r10         @ dx\n");
    s.push_str("    sub     r3, r2, r11         @ dy\n");
    // update beam tracking before the call
    s.push_str("    mov     r10, r1\n    mov     r11, r2\n"); // beam moves to target
    // call dv_move_to or dv_draw_delta based on cmd
    s.push_str("    pop     {r1}               @ restore cmd\n");
    s.push_str("    push    {r0, r3}           @ save dx, dy\n");
    s.push_str("    cmp     r1, #1\n"); // cmd==1: move
    s.push_str("    bne     vdg_draw\n");
    s.push_str("    pop     {r0, r1}\n    bl      dv_move_to\n    b       vdg_loop\n");
    s.push_str("vdg_draw:\n");
    s.push_str("    pop     {r0, r1}\n    bl      dv_draw_delta\n    b       vdg_loop\n");

    s.push_str("vdg_done:\n");
    s.push_str("    str     r10, [r8]           @ update PRINT_BEAM_X\n");
    s.push_str("    str     r11, [r9]           @ update PRINT_BEAM_Y\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    s
}

// ─── PRINT_NUMBER ──────────────────────────────────────────────────────────

fn emit_print_number() -> String {
    let mut s = String::new();
    s.push_str("@ vpy_print_number(r0=x, r1=y, r2=value) — range -9999..9999, no leading zeros\n");
    s.push_str(".global vpy_print_number\n.type vpy_print_number, %function\n.thumb_func\nvpy_print_number:\n");
    // r4=x  r5=y  r6=|value|  r7=buf_start  r8=write_ptr  r9=has_significant_digit
    // 8 callee-saves + lr = 32 bytes pushed; +8 stack buffer = 40 total → 8-byte aligned
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}\n");
    s.push_str("    mov     r4, r0\n    mov     r5, r1\n    mov     r6, r2\n");
    s.push_str("    sub     sp, sp, #8\n    mov     r7, sp\n    mov     r8, r7\n");
    // Negative sign
    s.push_str("    cmp     r6, #0\n    bge     vpn_pos\n");
    s.push_str("    mov     r0, #45\n    strb    r0, [r8]\n    add     r8, r8, #1\n    neg     r6, r6\n");
    s.push_str("vpn_pos:\n");
    // Clamp 0..9999
    s.push_str("    ldr     r0, =9999\n    cmp     r6, r0\n    ble     vpn_clamp\n    mov     r6, r0\n");
    s.push_str("vpn_clamp:\n    mov     r9, #0\n");
    // Thousands
    s.push_str("    ldr     r0, =1000\n    sdiv    r1, r6, r0\n    mul     r0, r0, r1\n    sub     r6, r6, r0\n");
    s.push_str("    cmp     r1, #0\n    beq     vpn_skip_thou\n");
    s.push_str("    add     r1, r1, #48\n    strb    r1, [r8]\n    add     r8, r8, #1\n    mov     r9, #1\n");
    s.push_str("vpn_skip_thou:\n");
    // Hundreds
    s.push_str("    mov     r0, #100\n    sdiv    r1, r6, r0\n    mul     r0, r0, r1\n    sub     r6, r6, r0\n");
    s.push_str("    cmp     r9, #0\n    bne     vpn_write_hund\n    cmp     r1, #0\n    beq     vpn_skip_hund\n");
    s.push_str("vpn_write_hund:\n    add     r1, r1, #48\n    strb    r1, [r8]\n    add     r8, r8, #1\n    mov     r9, #1\n");
    s.push_str("vpn_skip_hund:\n");
    // Tens
    s.push_str("    mov     r0, #10\n    sdiv    r1, r6, r0\n    mul     r0, r0, r1\n    sub     r6, r6, r0\n");
    s.push_str("    cmp     r9, #0\n    bne     vpn_write_tens\n    cmp     r1, #0\n    beq     vpn_skip_tens\n");
    s.push_str("vpn_write_tens:\n    add     r1, r1, #48\n    strb    r1, [r8]\n    add     r8, r8, #1\n");
    s.push_str("vpn_skip_tens:\n");
    // Units — always written (even for value==0)
    s.push_str("    add     r1, r6, #48\n    strb    r1, [r8]\n    add     r8, r8, #1\n");
    // Null terminator
    s.push_str("    mov     r0, #0\n    strb    r0, [r8]\n");
    // vpy_print_text(x, y, buf_start)
    s.push_str("    mov     r0, r4\n    mov     r1, r5\n    mov     r2, r7\n");
    s.push_str("    bl      vpy_print_text\n");
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n    .ltorg\n\n");
    s
}

// ─── JOYSTICK ──────────────────────────────────────────────────────────────

fn emit_joystick() -> String {
    let mut s = String::new();

    // J1_X — reads from SRAM cache (populated each frame by vpy_update_buttons in WAIT_RECAL window)
    // No bus_write during game loop — avoids corrupting VIA PORT B / beam positioning
    s.push_str("@ vpy_j1_x() → r0 = cached J1 X axis (-127..127)\n");
    s.push_str(".global vpy_j1_x\n.type vpy_j1_x, %function\n.thumb_func\nvpy_j1_x:\n");
    s.push_str("    ldr     r0, =J1_AXIS_X\n    ldr     r0, [r0]\n    bx      lr\n\n");

    // J1_Y
    s.push_str("@ vpy_j1_y() → r0 = cached J1 Y axis (-127..127)\n");
    s.push_str(".global vpy_j1_y\n.type vpy_j1_y, %function\n.thumb_func\nvpy_j1_y:\n");
    s.push_str("    ldr     r0, =J1_AXIS_Y\n    ldr     r0, [r0]\n    bx      lr\n\n");

    // J1_BTN1..4 — read from cached BTN_STATE_J1
    for (name, bit) in [("btn1", 4u8), ("btn2", 5), ("btn3", 6), ("btn4", 7)] {
        s.push_str(&format!(".global vpy_j1_{name}\n.type vpy_j1_{name}, %function\n.thumb_func\nvpy_j1_{name}:\n"));
        s.push_str("    ldr     r0, =BTN_STATE_J1\n    ldr     r0, [r0]\n");
        s.push_str(&format!("    ubfx    r0, r0, #{bit}, #1\n"));
        s.push_str("    eor     r0, r0, #1\n    bx      lr\n\n");
    }

    // J2_X — reads from SRAM cache (no bus_write during game loop)
    s.push_str("@ vpy_j2_x() → r0 = cached J2 X axis (-127..127)\n");
    s.push_str(".global vpy_j2_x\n.type vpy_j2_x, %function\n.thumb_func\nvpy_j2_x:\n");
    s.push_str("    ldr     r0, =J2_AXIS_X\n    ldr     r0, [r0]\n    bx      lr\n\n");

    // J2_Y
    s.push_str("@ vpy_j2_y() → r0 = cached J2 Y axis (-127..127)\n");
    s.push_str(".global vpy_j2_y\n.type vpy_j2_y, %function\n.thumb_func\nvpy_j2_y:\n");
    s.push_str("    ldr     r0, =J2_AXIS_Y\n    ldr     r0, [r0]\n    bx      lr\n\n");

    // J2_BTN1..4 — read from cached BTN_STATE_J2 (PSG reg 14, active-low)
    for (name, bit) in [("btn1", 0u8), ("btn2", 1), ("btn3", 2), ("btn4", 3)] {
        s.push_str(&format!(".global vpy_j2_{name}\n.type vpy_j2_{name}, %function\n.thumb_func\nvpy_j2_{name}:\n"));
        s.push_str("    ldr     r0, =BTN_STATE_J2\n    ldr     r0, [r0]\n");
        s.push_str(&format!("    ubfx    r0, r0, #{bit}, #1\n"));
        s.push_str("    eor     r0, r0, #1\n    bx      lr\n\n"); // invert active-low
    }

    s
}

// ─── PSG HELPERS ───────────────────────────────────────────────────────────
//
// Bit assignments on VIA Port B (verified from M6809 WRITE_PSG sequence):
//   LATCH  = 0x19 (BC1=bit3, BDIR=bit4, base=bit0)
//   INACTIVE = 0x01
//   WRITE  = 0x11
//   READ   = 0x09

fn emit_psg_helpers() -> String {
    let mut s = String::new();

    // ─── psg_write(r0=reg, r1=data) ─────────────────────────────────────
    s.push_str("@ psg_write(r0=reg, r1=data) — write AY-3-8912 PSG register\n");
    s.push_str(".global psg_write\n.type psg_write, %function\n.thumb_func\npsg_write:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    mov     r4, r0              @ reg\n");
    s.push_str("    mov     r5, r1              @ data\n");
    // Port A = register number
    s.push_str("    mov     r0, #0xD001\n    mov     r1, r4\n    bl      bus_write\n");
    // Port B = LATCH (0x19 = BC1=1, BDIR=1, base=1)
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x19\n    bl      bus_write\n");
    // Port B = INACTIVE
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x01\n    bl      bus_write\n");
    // Port A = data
    s.push_str("    mov     r0, #0xD001\n    mov     r1, r5\n    bl      bus_write\n");
    // Port B = WRITE (0x11 = BDIR=1, BC1=0, base=1)
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x11\n    bl      bus_write\n");
    // Port B = INACTIVE
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x01\n    bl      bus_write\n");
    s.push_str("    pop     {r4, r5, pc}\n    .ltorg\n\n");

    // ─── psg_read(r0=reg) → r0=data ─────────────────────────────────────
    s.push_str("@ psg_read(r0=reg) → r0 = PSG register value\n");
    s.push_str(".global psg_read\n.type psg_read, %function\n.thumb_func\npsg_read:\n");
    s.push_str("    push    {r4, lr}\n");
    s.push_str("    mov     r4, r0              @ reg\n");
    // Port A = register number
    s.push_str("    mov     r0, #0xD001\n    mov     r1, r4\n    bl      bus_write\n");
    // Port B = LATCH
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x19\n    bl      bus_write\n");
    // Port B = INACTIVE
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x01\n    bl      bus_write\n");
    // Set Port A as input: write 0x00 to DDR_A ($D003)
    s.push_str("    mov     r0, #0xD003\n    mov     r1, #0x00\n    bl      bus_write\n");
    // Port B = READ (0x09 = BC1=1, BDIR=0, base=1)
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x09\n    bl      bus_write\n");
    // Read Port A
    s.push_str("    mov     r0, #0xD001\n    bl      bus_read\n");
    s.push_str("    push    {r0}               @ save result\n");
    // Port B = INACTIVE; restore Port A DDR to output
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x01\n    bl      bus_write\n");
    s.push_str("    mov     r0, #0xD003\n    mov     r1, #0xFF\n    bl      bus_write\n");
    s.push_str("    pop     {r0}               @ return value\n");
    s.push_str("    pop     {r4, pc}\n    .ltorg\n\n");

    s
}

/// vpy_update_buttons — part of the JOYSTICK group (calls psg_read → PSG group).
fn emit_update_buttons() -> String {
    let mut s = String::new();

    // ─── vpy_update_buttons() ────────────────────────────────────────────
    s.push_str("@ vpy_update_buttons() — cache buttons and joystick axes (safe: called in WAIT_RECAL window)\n");
    s.push_str(".global vpy_update_buttons\n.type vpy_update_buttons, %function\n.thumb_func\nvpy_update_buttons:\n");
    s.push_str("    push    {r4, lr}\n");
    // DDR_B = 0x0F: bits 4-7 become inputs so J1 button pins drive PORT_B[4-7].
    // The Vectrex BIOS leaves DDR_B = 0xFF (all-output); if we read PORT_B without
    // switching, we get the output latch (0x01 from dv_draw_delta) → bits 4-7 = 0 →
    // all J1 buttons appear pressed → try_shoot fires every frame → snowballs → frame
    // time exceeds phosphor persistence → blank display.
    s.push_str("    mov     r0, #0xD002\n    mov     r1, #0x0F\n    bl      bus_write\n");
    // Read J1 buttons (VIA Port B bits 4-7 = hardware button state)
    s.push_str("    mov     r0, #0xD000\n    bl      bus_read\n");
    s.push_str("    ldr     r1, =BTN_STATE_J1\n    str     r0, [r1]\n");
    // Restore DDR_B = 0xFF so drawing code can drive all PORT_B lines as output
    s.push_str("    mov     r0, #0xD002\n    mov     r1, #0xFF\n    bl      bus_write\n");
    // Read J2 buttons (PSG reg 14)
    s.push_str("    mov     r0, #14\n    bl      psg_read\n");
    s.push_str("    ldr     r1, =BTN_STATE_J2\n    str     r0, [r1]\n");
    // Cache J1 X axis: PORT_B = 0x01 (mux A0=1 = X channel)
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x01\n    bl      bus_write\n");
    s.push_str("    mov     r0, #0xD001\n    bl      bus_read\n");
    s.push_str("    sxtb    r4, r0\n");
    s.push_str("    ldr     r0, =J1_AXIS_X\n    str     r4, [r0]\n");
    // Cache J1 Y axis: PORT_B = 0x03 (mux A0=1, A1=1 = J1 Y channel)
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x03\n    bl      bus_write\n");
    s.push_str("    mov     r0, #0xD001\n    bl      bus_read\n");
    s.push_str("    sxtb    r4, r0\n");
    s.push_str("    ldr     r0, =J1_AXIS_Y\n    str     r4, [r0]\n");
    // Cache J2 X axis: PORT_B = 0x00 (mux A0=0, A1=0 = J2 X channel)
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x00\n    bl      bus_write\n");
    s.push_str("    mov     r0, #0xD001\n    bl      bus_read\n");
    s.push_str("    sxtb    r4, r0\n");
    s.push_str("    ldr     r0, =J2_AXIS_X\n    str     r4, [r0]\n");
    // Cache J2 Y axis: PORT_B = 0x02 (mux A0=0, A1=1 = J2 Y channel)
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x02\n    bl      bus_write\n");
    s.push_str("    mov     r0, #0xD001\n    bl      bus_read\n");
    s.push_str("    sxtb    r4, r0\n");
    s.push_str("    ldr     r0, =J2_AXIS_Y\n    str     r4, [r0]\n");
    // Restore PORT_B to neutral (0x01 = same as J1_X mux, safe for display)
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x01\n    bl      bus_write\n");
    s.push_str("    pop     {r4, pc}\n    .ltorg\n\n");

    s
}

// ─── MATH BUILTINS ─────────────────────────────────────────────────────────

/// vpy_abs / vpy_min / vpy_max / vpy_clamp — MATH_BASIC group.
fn emit_math_basic() -> String {
    let mut s = String::new();

    // vpy_abs
    s.push_str(".global vpy_abs\n.type vpy_abs, %function\n.thumb_func\nvpy_abs:\n");
    s.push_str("    cmp     r0, #0\n    it      lt\n    neglt   r0, r0\n    bx      lr\n\n");

    // vpy_min
    s.push_str(".global vpy_min\n.type vpy_min, %function\n.thumb_func\nvpy_min:\n");
    s.push_str("    cmp     r0, r1\n    it      gt\n    movgt   r0, r1\n    bx      lr\n\n");

    // vpy_max
    s.push_str(".global vpy_max\n.type vpy_max, %function\n.thumb_func\nvpy_max:\n");
    s.push_str("    cmp     r0, r1\n    it      lt\n    movlt   r0, r1\n    bx      lr\n\n");

    // vpy_clamp(r0=val, r1=min, r2=max)
    s.push_str(".global vpy_clamp\n.type vpy_clamp, %function\n.thumb_func\nvpy_clamp:\n");
    s.push_str("    cmp     r0, r1\n    it      lt\n    movlt   r0, r1\n");
    s.push_str("    cmp     r0, r2\n    it      gt\n    movgt   r0, r2\n    bx      lr\n\n");

    s
}

/// vpy_sin / vpy_cos — TRIG group (reads _SIN_TABLE → SIN_TABLE group).
fn emit_trig() -> String {
    let mut s = String::new();

    // vpy_sin(r0=angle 0-127) → r0 = SIN_TABLE[angle & 0x7F]
    s.push_str("@ vpy_sin(r0=angle) → r0 = sin(angle*2π/128)*127 as signed i8\n");
    s.push_str(".global vpy_sin\n.type vpy_sin, %function\n.thumb_func\nvpy_sin:\n");
    s.push_str("    and     r0, r0, #0x7F\n");
    s.push_str("    ldr     r1, =_SIN_TABLE\n");
    s.push_str("    ldrb    r0, [r1, r0]\n");
    s.push_str("    sxtb    r0, r0\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    // vpy_cos(r0=angle) → SIN_TABLE[(angle+32) & 0x7F]
    s.push_str("@ vpy_cos(r0=angle) → r0 = cos(angle*2π/128)*127 as signed i8\n");
    s.push_str(".global vpy_cos\n.type vpy_cos, %function\n.thumb_func\nvpy_cos:\n");
    s.push_str("    add     r0, r0, #32\n");
    s.push_str("    and     r0, r0, #0x7F\n");
    s.push_str("    ldr     r1, =_SIN_TABLE\n");
    s.push_str("    ldrb    r0, [r1, r0]\n");
    s.push_str("    sxtb    r0, r0\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    s
}

/// vpy_sqrt — SQRT group.
fn emit_sqrt() -> String {
    let mut s = String::new();

    // vpy_sqrt(r0=n) — integer square root via binary search
    s.push_str("@ vpy_sqrt(r0=n) → r0 = floor(sqrt(n))\n");
    s.push_str(".global vpy_sqrt\n.type vpy_sqrt, %function\n.thumb_func\nvpy_sqrt:\n");
    s.push_str("    cmp     r0, #0\n    beq     vsqrt_zero\n");
    s.push_str("    push    {r4, r5, r6}\n");
    s.push_str("    mov     r4, r0              @ n\n");
    s.push_str("    mov     r5, #0              @ lo\n");
    s.push_str("    ldr     r6, =46340         @ hi (floor(sqrt(2^31-1)))\n"); // 46340^2 = 2147395600 < 2^31
    s.push_str("    cmp     r4, r6\n    blt     vsqrt_loop\n    mov     r0, r6\n");
    s.push_str("    pop     {r4, r5, r6}\n    bx      lr\n");
    s.push_str("vsqrt_loop:\n");
    s.push_str("    add     r0, r5, r6\n    lsr     r0, r0, #1  @ mid = (lo+hi)/2\n");
    s.push_str("    mul     r2, r0, r0           @ mid*mid\n");
    s.push_str("    cmp     r2, r4\n    beq     vsqrt_exact\n");
    s.push_str("    bgt     vsqrt_high\n");
    s.push_str("    mov     r5, r0\n    add     r5, r5, #1\n"); // lo = mid+1
    s.push_str("    cmp     r5, r6\n    blt     vsqrt_loop\n");
    s.push_str("    b       vsqrt_done\n");
    s.push_str("vsqrt_high:\n    mov     r6, r0\n    cmp     r5, r6\n    blt     vsqrt_loop\n");
    s.push_str("vsqrt_done:\n    mov     r0, r5\n    sub     r0, r0, #1\n"); // floor: return lo-1
    s.push_str("    pop     {r4, r5, r6}\n    bx      lr\n");
    s.push_str("vsqrt_exact:\n    pop     {r4, r5, r6}\n    bx      lr\n");
    s.push_str("vsqrt_zero:\n    bx      lr\n    .ltorg\n\n");

    s
}

/// vpy_rand / vpy_rand_range — RAND group (also a dep of ENEMIES wander AI).
fn emit_rand() -> String {
    let mut s = String::new();

    // vpy_rand() → LCG: seed = seed*1664525 + 1013904223, return seed>>16 & 0x7FFF
    s.push_str("@ vpy_rand() → r0 = pseudo-random 0-32767 (LCG)\n");
    s.push_str(".global vpy_rand\n.type vpy_rand, %function\n.thumb_func\nvpy_rand:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    ldr     r4, =RAND_SEED\n    ldr     r0, [r4]\n");
    s.push_str("    ldr     r5, =1664525\n    mul     r0, r0, r5\n");
    s.push_str("    ldr     r5, =1013904223\n    add     r0, r0, r5\n");
    s.push_str("    str     r0, [r4]            @ save seed\n");
    s.push_str("    lsr     r0, r0, #16\n");
    s.push_str("    bic     r0, r0, #0x8000      @ clear bit15 (0x8000 is valid Thumb2 immediate)\n");
    s.push_str("    pop     {r4, r5, pc}\n    .ltorg\n\n");

    // vpy_rand_range(r0=lo, r1=hi) → lo + rand()%(hi-lo+1)
    s.push_str("@ vpy_rand_range(r0=lo, r1=hi) → r0 = random in [lo, hi]\n");
    s.push_str(".global vpy_rand_range\n.type vpy_rand_range, %function\n.thumb_func\nvpy_rand_range:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    mov     r4, r0              @ lo\n");
    s.push_str("    sub     r5, r1, r0\n    add     r5, r5, #1\n"); // r5 = hi-lo+1
    s.push_str("    bl      vpy_rand\n");
    s.push_str("    sdiv    r1, r0, r5\n    mul     r1, r1, r5\n    sub     r0, r0, r1\n"); // r0 % r5
    s.push_str("    add     r0, r0, r4          @ + lo\n");
    s.push_str("    pop     {r4, r5, pc}\n    .ltorg\n\n");

    s
}

// ─── UTILITY BUILTINS ──────────────────────────────────────────────────────

/// vpy_peek / vpy_poke — PEEK_POKE group (bus_read/bus_write are core).
fn emit_peek_poke() -> String {
    let mut s = String::new();

    // vpy_peek(r0=addr) → bus_read(addr)
    s.push_str("@ vpy_peek(r0=vectrex_addr) → r0 = byte at that address\n");
    s.push_str(".global vpy_peek\n.type vpy_peek, %function\n.thumb_func\nvpy_peek:\n");
    s.push_str("    push    {lr}\n    bl      bus_read\n    pop     {pc}\n    .ltorg\n\n");

    // vpy_poke(r0=addr, r1=val) → bus_write(addr, val)
    s.push_str("@ vpy_poke(r0=vectrex_addr, r1=val)\n");
    s.push_str(".global vpy_poke\n.type vpy_poke, %function\n.thumb_func\nvpy_poke:\n");
    s.push_str("    push    {lr}\n    bl      bus_write\n    pop     {pc}\n    .ltorg\n\n");

    s
}

/// vpy_wait — WAIT group (calls vpy_wait_recal, which is core).
fn emit_wait_builtin() -> String {
    let mut s = String::new();

    // vpy_wait(r0=frames) — call wait_recal r0 times
    s.push_str("@ vpy_wait(r0=frames) — busy-wait N frames via wait_recal\n");
    s.push_str(".global vpy_wait\n.type vpy_wait, %function\n.thumb_func\nvpy_wait:\n");
    s.push_str("    push    {r4, lr}\n");
    s.push_str("    mov     r4, r0\n");
    s.push_str("vwt_loop:\n");
    s.push_str("    cmp     r4, #0\n    beq     vwt_done\n");
    s.push_str("    bl      vpy_wait_recal\n");
    s.push_str("    sub     r4, r4, #1\n    b       vwt_loop\n");
    s.push_str("vwt_done:\n    pop     {r4, pc}\n    .ltorg\n\n");

    s
}

/// vpy_beep + vpy_beep_update — BEEP group (calls psg_write → PSG group).
/// The auto-injected `bl vpy_beep_update` in game_main is gated on this group.
fn emit_beep() -> String {
    let mut s = String::new();

    // vpy_beep(r0=freq_period, r1=duration_frames) — non-blocking PSG beep
    s.push_str("@ vpy_beep(r0=freq_period, r1=duration_frames) — non-blocking PSG tone on channel A\n");
    s.push_str(".global vpy_beep\n.type vpy_beep, %function\n.thumb_func\nvpy_beep:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    mov     r4, r0              @ freq period (reg 0)\n");
    s.push_str("    mov     r5, r1              @ duration\n");
    // PSG reg 0 = freq low byte
    s.push_str("    mov     r0, #0\n    mov     r1, r4\n    bl      psg_write\n");
    // PSG reg 1 = freq high = 0
    s.push_str("    mov     r0, #1\n    mov     r1, #0\n    bl      psg_write\n");
    // PSG reg 7 = mixer: enable tone A (bit0=0), disable others; bits3-5=noise off
    // 0x3E = 0b00111110 = noise A,B,C off; tone B,C off; tone A ON
    s.push_str("    mov     r0, #7\n    mov     r1, #0x3E\n    bl      psg_write\n");
    // PSG reg 8 = volume channel A = 15 (max)
    s.push_str("    mov     r0, #8\n    mov     r1, #15\n    bl      psg_write\n");
    // Store duration to BEEP_FRAMES_LEFT
    s.push_str("    ldr     r0, =BEEP_FRAMES_LEFT\n    str     r5, [r0]\n");
    s.push_str("    pop     {r4, r5, pc}\n    .ltorg\n\n");

    // vpy_beep_update() — auto-injected each frame; mutes PSG when timer expires
    s.push_str("@ vpy_beep_update() — decrement beep timer; mute channel A when done\n");
    s.push_str(".global vpy_beep_update\n.type vpy_beep_update, %function\n.thumb_func\nvpy_beep_update:\n");
    s.push_str("    push    {r4, lr}\n");
    s.push_str("    ldr     r4, =BEEP_FRAMES_LEFT\n    ldr     r0, [r4]\n");
    s.push_str("    cmp     r0, #0\n    beq     vbu_done\n");
    s.push_str("    sub     r0, r0, #1\n    str     r0, [r4]\n");
    s.push_str("    bne     vbu_done\n"); // still counting
    // Timer just expired: mute PSG channel A
    s.push_str("    mov     r0, #8\n    mov     r1, #0\n    bl      psg_write\n"); // vol=0
    s.push_str("    mov     r0, #7\n    mov     r1, #0x3F\n    bl      psg_write\n"); // mixer: all off
    s.push_str("vbu_done:\n    pop     {r4, pc}\n    .ltorg\n\n");

    s
}

/// vpy_len — LEN group (fallback stub for non-static len() arguments).
fn emit_len() -> String {
    let mut s = String::new();

    // vpy_len — fallback for non-Var len() arguments; emit_call handles len(arr_name) as a
    // compile-time constant (ldr r0, =ARRAY_NAME_LEN) without calling this function.
    s.push_str("@ vpy_len — fallback, returns 0 (len(arr) on static arrays resolved at compile time)\n");
    s.push_str(".global vpy_len\n.type vpy_len, %function\n.thumb_func\nvpy_len:\n");
    s.push_str("    mov     r0, #0\n    bx      lr\n\n");

    s
}

// ─── AUDIO BUILTINS ────────────────────────────────────────────────────────
//
// Music/SFX data format (compiled from .vmus / .vsfx by assets.rs):
//   .word  num_events
//   .word  loop_event_offset  (byte offset to loop-back event, or 0xFFFF=no loop)
//   per event:
//     .byte  delay_frames     (wait N frames before applying writes)
//     .byte  num_writes       (number of reg/val pairs; 0 = end of music)
//     .byte  reg0, val0
//     .byte  reg1, val1, ...

/// vpy_play_music / vpy_stop_music / vpy_music_update — MUSIC group.
/// The auto-injected `bl vpy_music_update` in game_main is gated on this group.
fn emit_music_engine() -> String {
    let mut s = String::new();

    // ─── vpy_play_music(r0=ptr) ─────────────────────────────────────────
    s.push_str("@ vpy_play_music(r0=music_data_ptr)\n");
    s.push_str(".global vpy_play_music\n.type vpy_play_music, %function\n.thumb_func\nvpy_play_music:\n");
    s.push_str("    push    {r4, lr}\n");
    s.push_str("    mov     r4, r0\n");
    // Check if already playing this track
    s.push_str("    ldr     r1, =PSG_MUSIC_START\n    ldr     r1, [r1]\n");
    s.push_str("    cmp     r4, r1\n    beq     vpm_already\n");
    // Silence current music before switching
    s.push_str("    bl      vpy_stop_music\n");
    // Store music pointer and loop-start
    s.push_str("    ldr     r1, =PSG_MUSIC_START\n    str     r4, [r1]\n");
    // First event starts at ptr+8 (skip: num_events word + loop_event_offset word = 8 bytes)
    s.push_str("    add     r0, r4, #8\n");
    s.push_str("    ldr     r1, =PSG_MUSIC_PTR\n    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_IS_PLAYING\n    mov     r0, #1\n    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_DELAY_FRAMES\n    mov     r0, #0\n    str     r0, [r1]\n");
    s.push_str("vpm_already:\n    pop     {r4, pc}\n    .ltorg\n\n");

    // ─── vpy_stop_music() ───────────────────────────────────────────────
    s.push_str("@ vpy_stop_music() — stop playback and silence all PSG channels\n");
    s.push_str(".global vpy_stop_music\n.type vpy_stop_music, %function\n.thumb_func\nvpy_stop_music:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    ldr     r0, =PSG_IS_PLAYING\n    mov     r1, #0\n    str     r1, [r0]\n");
    // Silence: vol A=B=C=0, mixer=0x3F (all tone/noise disabled)
    s.push_str("    mov     r0, #8\n    mov     r1, #0\n    bl      psg_write\n");
    s.push_str("    mov     r0, #9\n    mov     r1, #0\n    bl      psg_write\n");
    s.push_str("    mov     r0, #10\n   mov     r1, #0\n    bl      psg_write\n");
    s.push_str("    mov     r0, #7\n    mov     r1, #0x3F\n bl      psg_write\n");
    s.push_str("    pop     {pc}\n    .ltorg\n\n");

    // ─── vpy_music_update() — called each frame ──────────────────────────
    s.push_str("@ vpy_music_update() — advance PSG music sequencer by one frame\n");
    s.push_str(".global vpy_music_update\n.type vpy_music_update, %function\n.thumb_func\nvpy_music_update:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    // Check if playing
    s.push_str("    ldr     r0, =PSG_IS_PLAYING\n    ldr     r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n    beq     vmu_done\n");
    // Decrement delay counter
    s.push_str("    ldr     r4, =PSG_DELAY_FRAMES\n    ldr     r0, [r4]\n");
    s.push_str("    cmp     r0, #0\n    beq     vmu_process\n");
    s.push_str("    sub     r0, r0, #1\n    str     r0, [r4]\n    b       vmu_done\n");
    // Process event
    s.push_str("vmu_process:\n");
    s.push_str("    ldr     r5, =PSG_MUSIC_PTR\n    ldr     r5, [r5]\n"); // r5 = event ptr
    // Read num_writes (byte 1 of event)
    s.push_str("    ldrb    r6, [r5, #1]         @ num_writes\n");
    // Check end marker (num_writes = 0) or loop marker (num_writes = 0xFF)
    s.push_str("    cmp     r6, #0\n    beq     vmu_end\n");
    s.push_str("    cmp     r6, #0xFF\n    beq     vmu_loop\n");
    // Apply writes: r7 = data ptr (event base + 2)
    s.push_str("    add     r7, r5, #2\n");
    s.push_str("vmu_write_loop:\n");
    s.push_str("    cmp     r6, #0\n    beq     vmu_after_writes\n");
    s.push_str("    ldrb    r0, [r7]\n    ldrb    r1, [r7, #1]\n"); // reg, val
    s.push_str("    push    {r6, r7}\n    bl      psg_write\n    pop     {r6, r7}\n");
    s.push_str("    add     r7, r7, #2\n    sub     r6, r6, #1\n    b       vmu_write_loop\n");
    s.push_str("vmu_after_writes:\n");
    // Advance ptr to next event: r7 now points past the writes = next event
    s.push_str("    ldr     r0, =PSG_MUSIC_PTR\n    str     r7, [r0]\n");
    // Load next event's delay byte and store to PSG_DELAY_FRAMES
    s.push_str("    ldrb    r0, [r7]\n    str     r0, [r4]\n"); // r4 = PSG_DELAY_FRAMES ptr
    s.push_str("    b       vmu_done\n");
    // End of music
    s.push_str("vmu_end:\n    bl      vpy_stop_music\n    b       vmu_done\n");
    // Loop: seek back to loop_event_offset from music base
    s.push_str("vmu_loop:\n");
    s.push_str("    ldr     r0, =PSG_MUSIC_START\n    ldr     r0, [r0]\n"); // music base
    s.push_str("    ldr     r1, [r0, #4]         @ loop_event_offset\n");
    s.push_str("    add     r1, r0, r1\n"); // loop ptr
    s.push_str("    ldr     r0, =PSG_MUSIC_PTR\n    str     r1, [r0]\n");
    s.push_str("    ldrb    r0, [r1]\n    str     r0, [r4]\n"); // reset delay
    s.push_str("vmu_done:\n    pop     {r4, r5, r6, r7, pc}\n    .ltorg\n\n");

    s
}

/// vpy_play_sfx / vpy_audio_update — SFX group.
/// The auto-injected `bl vpy_audio_update` in game_main is gated on this group.
fn emit_sfx_engine() -> String {
    let mut s = String::new();

    // ─── vpy_play_sfx(r0=ptr) ────────────────────────────────────────────
    s.push_str("@ vpy_play_sfx(r0=sfx_data_ptr)\n");
    s.push_str(".global vpy_play_sfx\n.type vpy_play_sfx, %function\n.thumb_func\nvpy_play_sfx:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    ldr     r1, =PSG_SFX_PTR\n    add     r2, r0, #4\n    str     r2, [r1]\n"); // first event = base+4
    s.push_str("    ldr     r1, =PSG_SFX_ACTIVE\n    mov     r2, #1\n    str     r2, [r1]\n");
    s.push_str("    ldr     r1, =PSG_SFX_DELAY\n    mov     r2, #0\n    str     r2, [r1]\n");
    s.push_str("    pop     {pc}\n    .ltorg\n\n");

    // ─── vpy_audio_update() — SFX frame update ───────────────────────────
    s.push_str("@ vpy_audio_update() — advance SFX sequencer by one frame\n");
    s.push_str(".global vpy_audio_update\n.type vpy_audio_update, %function\n.thumb_func\nvpy_audio_update:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    ldr     r0, =PSG_SFX_ACTIVE\n    ldr     r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n    beq     vau_done\n");
    s.push_str("    ldr     r4, =PSG_SFX_DELAY\n    ldr     r0, [r4]\n");
    s.push_str("    cmp     r0, #0\n    beq     vau_proc\n");
    s.push_str("    sub     r0, r0, #1\n    str     r0, [r4]\n    b       vau_done\n");
    s.push_str("vau_proc:\n");
    s.push_str("    ldr     r5, =PSG_SFX_PTR\n    ldr     r5, [r5]\n");
    s.push_str("    ldrb    r6, [r5, #1]         @ num_writes\n");
    s.push_str("    cmp     r6, #0\n    beq     vau_end\n");
    s.push_str("    add     r7, r5, #2\n");
    s.push_str("vau_wl:\n    cmp     r6, #0\n    beq     vau_aw\n");
    s.push_str("    ldrb    r0, [r7]\n    ldrb    r1, [r7, #1]\n");
    // Mixer reg 7: read-modify-write to preserve music channels A/B.
    // CHANNEL_C_MASK = 0x24 (bit2=toneC, bit5=noiseC). Only bits 2/5 come from SFX;
    // bits 0/1/3/4 (channels A/B tone/noise) are taken from the current PSG state.
    s.push_str("    cmp     r0, #7\n    bne     vau_do_write\n");
    s.push_str("    push    {r1, r6, r7}    @ save sfx_mixer, loop vars\n");
    s.push_str("    bl      psg_read         @ r0=7 already → returns Regs[7]\n");
    s.push_str("    pop     {r1, r6, r7}    @ restore sfx_mixer to r1; r0=cur_mixer\n");
    s.push_str("    and     r0, r0, #0xDB   @ keep non-C bits from music (0xDB=~0x24)\n");
    s.push_str("    and     r1, r1, #0x24   @ keep only C bits from SFX\n");
    s.push_str("    orr     r1, r0, r1      @ r1 = merged mixer\n");
    s.push_str("    mov     r0, #7          @ reg = 7\n");
    s.push_str("vau_do_write:\n");
    s.push_str("    push    {r6, r7}\n    bl      psg_write\n    pop     {r6, r7}\n");
    s.push_str("    add     r7, r7, #2\n    sub     r6, r6, #1\n    b       vau_wl\n");
    s.push_str("vau_aw:\n    ldr     r0, =PSG_SFX_PTR\n    str     r7, [r0]\n");
    s.push_str("    ldrb    r0, [r7]\n    str     r0, [r4]\n    b       vau_done\n");
    s.push_str("vau_end:\n");
    s.push_str("    ldr     r0, =PSG_SFX_ACTIVE\n    mov     r1, #0\n    str     r1, [r0]\n");
    s.push_str("vau_done:\n    pop     {r4, r5, r6, r7, pc}\n    .ltorg\n\n");

    // vpy_music_update = alias for vpy_music_update (same symbol, already defined above)
    // Actually the M6809 backend emits both audio_update and music_update. Let's make
    // vpy_music_update already defined above; audio_update handles SFX. Keep both.

    s
}

// ── NOTE engine: vpy_play_note + vpy_note_update (Thumb-2, psg_write) ─────

fn emit_note_engine() -> String {
    let mut s = String::new();

    // ── NOTE_PERIOD_TABLE in .rodata ──────────────────────────────────────────
    // 84 entries (MIDI 24-107).  period = round(88200 / (440 * 2^((n-69)/12)))
    s.push_str("@ --- NOTE_PERIOD_TABLE: MIDI 24-107 → AY period (84 hwords) ---\n");
    s.push_str(".section .rodata\n");
    s.push_str(".balign 2\n");
    s.push_str(".global NOTE_PERIOD_TABLE\n");
    s.push_str("NOTE_PERIOD_TABLE:\n");
    let mut periods: Vec<u16> = Vec::new();
    for n in 24u32..=107 {
        let freq = 440.0 * 2f64.powf((n as f64 - 69.0) / 12.0);
        let period = (88200.0 / freq).round() as u16;
        let period = period.max(1).min(4095);
        periods.push(period);
    }
    for chunk in periods.chunks(8) {
        let vals: Vec<String> = chunk.iter().map(|p| p.to_string()).collect();
        s.push_str(&format!("    .hword {}\n", vals.join(", ")));
    }
    s.push('\n');
    s.push_str(".section .text\n");
    s.push_str(".align 2\n\n");

    // ── vpy_play_note(r0=instr_ptr, r1=channel, r2=note) ─────────────────────
    s.push_str("@ vpy_play_note(r0=instr_ptr, r1=channel 0-2, r2=note MIDI 24-107)\n");
    s.push_str(".global vpy_play_note\n.type vpy_play_note, %function\n.thumb_func\nvpy_play_note:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, r0          @ r4 = instr_ptr\n");
    s.push_str("    mov     r5, r1          @ r5 = channel\n");
    s.push_str("    mov     r6, r2          @ r6 = note\n");

    // Clamp note to 24-107
    s.push_str("    @ clamp note to 24-107\n");
    s.push_str("    cmp     r6, #24\n    it      lt\n    movlt   r6, #24\n");
    s.push_str("    cmp     r6, #107\n    it      gt\n    movgt   r6, #107\n");

    // Get channel state slot: &NOTE_STATE + channel*32
    s.push_str("    @ r7 = &NOTE_STATE[channel]\n");
    s.push_str("    ldr     r0, =NOTE_STATE\n");
    s.push_str("    mov     r1, #32\n");
    s.push_str("    mul     r7, r5, r1\n");
    s.push_str("    add     r7, r0, r7\n");

    // Fill state
    s.push_str("    @ fill channel state\n");
    s.push_str("    mov     r0, #1\n    str     r0, [r7, #0]    @ active = 1\n");
    s.push_str("    ldrb    r0, [r4, #0]\n    str     r0, [r7, #4]    @ frames_left = duration_frames\n");
    s.push_str("    str     r6, [r7, #8]    @ base_note\n");
    s.push_str("    str     r4, [r7, #12]   @ instr_ptr\n");
    s.push_str("    mov     r0, #0\n    str     r0, [r7, #16]   @ arp_pos = 0\n");
    s.push_str("    ldrb    r0, [r4, #3]\n    str     r0, [r7, #20]   @ arp_timer = arp_speed_frames\n");
    s.push_str("    str     r5, [r7, #28]   @ channel_id\n");

    // Compute period: look up NOTE_PERIOD_TABLE[note - 24]
    s.push_str("    @ compute period from note\n");
    s.push_str("    sub     r0, r6, #24     @ r0 = note - 24 (index)\n");
    s.push_str("    lsl     r0, r0, #1      @ r0 = index * 2 (hword offset)\n");
    s.push_str("    ldr     r1, =NOTE_PERIOD_TABLE\n");
    s.push_str("    ldrh    r2, [r1, r0]    @ r2 = period\n");
    s.push_str("    str     r2, [r7, #24]   @ save period in state\n");

    // Write tone period registers: ch A→R0/R1, ch B→R2/R3, ch C→R4/R5
    s.push_str("    @ write period to PSG (reg_lo = channel*2, reg_hi = channel*2+1)\n");
    s.push_str("    lsl     r0, r5, #1      @ reg_lo = channel * 2\n");
    s.push_str("    mov     r1, r2\n    and     r1, r1, #0xFF   @ period_lo\n");
    s.push_str("    push    {r2, r5, r7}\n    bl      psg_write\n    pop     {r2, r5, r7}\n");
    s.push_str("    lsl     r0, r5, #1\n    add     r0, r0, #1      @ reg_hi\n");
    s.push_str("    mov     r1, r2\n    lsr     r1, r1, #8      @ period_hi\n");
    s.push_str("    push    {r5, r7}\n    bl      psg_write\n    pop     {r5, r7}\n");

    // Write volume: ch A→R8, ch B→R9, ch C→R10
    s.push_str("    @ write volume to PSG (vol reg = channel + 8)\n");
    s.push_str("    ldr     r4, [r7, #12]   @ reload instr_ptr\n");
    s.push_str("    ldrb    r1, [r4, #1]    @ volume\n");
    s.push_str("    add     r0, r5, #8      @ vol reg = channel + 8\n");
    s.push_str("    push    {r5, r7}\n    bl      psg_write\n    pop     {r5, r7}\n");

    // Update mixer shadow: enable tone for channel (clear bit), disable noise (set noise bit)
    s.push_str("    @ update PSG_MIXER_SHADOW: enable tone ch, disable noise ch\n");
    s.push_str("    ldr     r0, =PSG_MIXER_SHADOW\n");
    s.push_str("    ldr     r1, [r0]\n");
    s.push_str("    mov     r2, #1\n    lsl     r2, r2, r5      @ tone bit for channel\n");
    s.push_str("    bic     r1, r1, r2      @ clear = enable tone\n");
    s.push_str("    add     r3, r5, #3\n    mov     r2, #1\n    lsl     r2, r2, r3      @ noise bit\n");
    s.push_str("    orr     r1, r1, r2      @ set = disable noise\n");
    s.push_str("    str     r1, [r0]        @ update shadow\n");
    s.push_str("    mov     r1, r1          @ r1 = shadow value already loaded above\n");
    s.push_str("    ldr     r1, =PSG_MIXER_SHADOW\n    ldr     r1, [r1]\n"); // reload for psg_write
    s.push_str("    mov     r0, #7\n");        // R7 = mixer
    s.push_str("    push    {r5, r7}\n    bl      psg_write\n    pop     {r5, r7}\n");

    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");

    // ── vpy_note_update() ──────────────────────────────────────────────────────
    s.push_str("@ vpy_note_update() — advance note engine one frame (3 channels)\n");
    s.push_str(".global vpy_note_update\n.type vpy_note_update, %function\n.thumb_func\nvpy_note_update:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}\n");
    s.push_str("    mov     r4, #0              @ r4 = channel index\n");
    s.push_str(".Lvnu_loop:\n");
    s.push_str("    cmp     r4, #3\n    bge     .Lvnu_done\n");

    // Get channel state ptr: &NOTE_STATE + channel*32
    s.push_str("    ldr     r5, =NOTE_STATE\n");
    s.push_str("    mov     r6, #32\n");
    s.push_str("    mul     r7, r4, r6\n");
    s.push_str("    add     r5, r5, r7      @ r5 = &NOTE_STATE[channel]\n");

    // Skip if not active
    s.push_str("    ldr     r6, [r5, #0]    @ active\n");
    s.push_str("    cmp     r6, #0\n    beq     .Lvnu_next\n");

    // Decrement frames_left
    s.push_str("    ldr     r6, [r5, #4]    @ frames_left\n");
    s.push_str("    subs    r6, r6, #1\n");
    s.push_str("    str     r6, [r5, #4]\n");
    s.push_str("    bne     .Lvnu_arp\n");

    // Duration expired — mute channel volume
    s.push_str("    @ note expired: mute channel\n");
    s.push_str("    mov     r0, #0\n    str     r0, [r5, #0]    @ active = 0\n");
    s.push_str("    ldr     r6, [r5, #28]   @ channel_id\n");
    s.push_str("    add     r0, r6, #8      @ vol reg = channel_id + 8\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    push    {r4, r5}\n    bl      psg_write\n    pop     {r4, r5}\n");
    s.push_str("    b       .Lvnu_next\n");

    s.push_str(".Lvnu_arp:\n");
    // Check arpeggio
    s.push_str("    ldr     r6, [r5, #12]   @ instr_ptr\n");
    s.push_str("    ldrb    r7, [r6, #2]    @ arpeggio_count\n");
    s.push_str("    cmp     r7, #0\n    beq     .Lvnu_next\n");

    // Decrement arp timer
    s.push_str("    ldr     r8, [r5, #20]   @ arp_timer\n");
    s.push_str("    subs    r8, r8, #1\n");
    s.push_str("    str     r8, [r5, #20]\n");
    s.push_str("    bne     .Lvnu_next\n");

    // Reload arp timer
    s.push_str("    ldrb    r8, [r6, #3]    @ arpeggio_speed_frames\n");
    s.push_str("    str     r8, [r5, #20]\n");

    // Advance arp_pos (wraps at arpeggio_count)
    s.push_str("    ldr     r8, [r5, #16]   @ arp_pos\n");
    s.push_str("    add     r8, r8, #1\n");
    s.push_str("    cmp     r8, r7\n");
    s.push_str("    it      ge\n    movge   r8, #0\n");
    s.push_str("    str     r8, [r5, #16]\n");

    // new_note = base_note + arpeggio_intervals[arp_pos], clamp 24-107
    s.push_str("    ldr     r0, [r5, #8]    @ base_note\n");
    s.push_str("    add     r1, r6, #4      @ ptr to arpeggio_intervals[0]\n");
    s.push_str("    ldrsb   r1, [r1, r8]    @ signed interval at arp_pos\n");
    s.push_str("    add     r0, r0, r1      @ new_note\n");
    s.push_str("    cmp     r0, #24\n    it      lt\n    movlt   r0, #24\n");
    s.push_str("    cmp     r0, #107\n    it      gt\n    movgt   r0, #107\n");

    // Look up period
    s.push_str("    sub     r0, r0, #24     @ index into table\n");
    s.push_str("    lsl     r0, r0, #1      @ hword offset\n");
    s.push_str("    ldr     r1, =NOTE_PERIOD_TABLE\n");
    s.push_str("    ldrh    r2, [r1, r0]    @ period\n");

    // Write period to PSG
    s.push_str("    ldr     r3, [r5, #28]   @ channel_id\n");
    s.push_str("    lsl     r0, r3, #1      @ reg_lo = channel_id * 2\n");
    s.push_str("    mov     r1, r2\n    and     r1, r1, #0xFF\n");
    s.push_str("    push    {r2, r3, r4, r5}\n    bl      psg_write\n    pop     {r2, r3, r4, r5}\n");
    s.push_str("    lsl     r0, r3, #1\n    add     r0, r0, #1      @ reg_hi\n");
    s.push_str("    mov     r1, r2\n    lsr     r1, r1, #8\n");
    s.push_str("    push    {r3, r4, r5}\n    bl      psg_write\n    pop     {r3, r4, r5}\n");

    s.push_str(".Lvnu_next:\n");
    s.push_str("    add     r4, r4, #1\n");
    s.push_str("    b       .Lvnu_loop\n");

    s.push_str(".Lvnu_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n");
    s.push_str("    .ltorg\n\n");

    s
}

// ─── STATE BUILTINS ────────────────────────────────────────────────────────

/// One-line setter: `NAME(r0)` stores r0 to a RAM symbol.
fn simple_set(name: &str, sym: &str) -> String {
    format!(
        ".global {name}\n.type {name}, %function\n.thumb_func\n{name}:\n\
         \x20   ldr     r1, ={sym}\n    str     r0, [r1]\n    bx      lr\n\n"
    )
}

/// One-line getter: `NAME()` loads a RAM symbol into r0.
fn simple_get(name: &str, sym: &str) -> String {
    format!(
        ".global {name}\n.type {name}, %function\n.thumb_func\n{name}:\n\
         \x20   ldr     r0, ={sym}\n    ldr     r0, [r0]\n    bx      lr\n\n"
    )
}

/// Camera / scroll-limit accessors + vpy_get_level_floor_y — CAMERA group.
fn emit_camera_builtins() -> String {
    let mut s = String::new();

    s.push_str(&simple_set("vpy_set_camera_x", "CAMERA_X"));
    s.push_str(&simple_set("vpy_set_camera_y", "CAMERA_Y"));
    s.push_str(&simple_get("vpy_get_camera_x", "CAMERA_X"));
    s.push_str(&simple_get("vpy_get_camera_y", "CAMERA_Y"));
    s.push_str(&simple_get("vpy_get_scroll_limit_left",   "SCROLL_LIMIT_LEFT"));
    s.push_str(&simple_get("vpy_get_scroll_limit_right",  "SCROLL_LIMIT_RIGHT"));
    s.push_str(&simple_get("vpy_get_scroll_limit_top",    "SCROLL_LIMIT_TOP"));
    s.push_str(&simple_get("vpy_get_scroll_limit_bottom", "SCROLL_LIMIT_BOTTOM"));

    // vpy_get_level_floor_y() → camera_y - 128 + groundBottomOffset (level header +32).
    // Mirrors pitrex_get_level_floor_y so cross-target code can share spawn-height math.
    s.push_str(".global vpy_get_level_floor_y\n.type vpy_get_level_floor_y, %function\n.thumb_func\nvpy_get_level_floor_y:\n");
    s.push_str("    ldr     r0, =LEVEL_DATA_PTR\n");
    s.push_str("    ldr     r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     vglfy_none\n");
    s.push_str("    ldrsh   r1, [r0, #32]      @ groundBottomOffset at header +32\n");
    s.push_str("    ldr     r0, =CAMERA_Y\n");
    s.push_str("    ldr     r0, [r0]\n");
    s.push_str("    sub     r0, r0, #128\n");
    s.push_str("    add     r0, r0, r1\n");
    s.push_str("    bx      lr\n");
    s.push_str("vglfy_none:\n    mov     r0, #0\n    bx      lr\n\n");

    s
}

/// vpy_get_frame_us — FRAME_US group.
fn emit_frame_us() -> String {
    let mut s = String::new();

    // vpy_get_frame_us() → stub. PiTrex uses the BCM CLO; rp2350 has no equivalent
    // hardware exposed yet, so return 0. Code paths that use this for adaptive
    // timing (e.g. SnowBros frame profiling) just see "no time elapsed" and skip
    // their slow-frame branches, which is harmless.
    s.push_str(".global vpy_get_frame_us\n.type vpy_get_frame_us, %function\n.thumb_func\nvpy_get_frame_us:\n");
    s.push_str("    mov     r0, #0\n    bx      lr\n\n");

    s
}

/// vpy_set_text_size / vpy_set_text_color — TEXT group (state for print_text).
fn emit_text_state() -> String {
    let mut s = String::new();

    // vpy_set_text_size: converts M6809 convention (n=1..8, n=8=normal) to ARM scale.
    // ARM TEXT_SIZE=3 ≈ normal Vectrex text (glyph 4×6 box, scale=3 → height=9 units).
    // Mapping: TEXT_SIZE = max(1, (n*3 + 4) >> 3)
    //   n=8 → 3, n=7 → 3, n=6 → 2, n=5 → 2, n=4 → 2, n=3 → 1, n=2 → 1, n=1 → 1
    s.push_str(".global vpy_set_text_size\n.type vpy_set_text_size, %function\n.thumb_func\nvpy_set_text_size:\n");
    s.push_str("    lsl     r1, r0, #1\n");   // r1 = n*2
    s.push_str("    add     r1, r1, r0\n");   // r1 = n*3
    s.push_str("    add     r1, r1, #4\n");   // r1 = n*3+4
    s.push_str("    lsr     r1, r1, #3\n");   // r1 = (n*3+4)>>3
    s.push_str("    cmp     r1, #1\n");
    s.push_str("    bhs     vsts_ok\n");
    s.push_str("    mov     r1, #1\n");
    s.push_str("vsts_ok:\n");
    s.push_str("    ldr     r0, =TEXT_SIZE\n    str     r1, [r0]\n    bx      lr\n\n");
    s.push_str(&simple_set("vpy_set_text_color", "TEXT_COLOR"));

    s
}

/// vpy_debug_print / vpy_debug_print_labeled / vpy_debug_print_str — DEBUG group.
fn emit_debug_builtins() -> String {
    let mut s = String::new();

    // debug_print: write value to DBGVAL (readable via debugger / bus_read)
    s.push_str(".global vpy_debug_print\n.type vpy_debug_print, %function\n.thumb_func\nvpy_debug_print:\n");
    s.push_str("    ldr     r1, =DBGVAL\n    str     r0, [r1]\n    bx      lr\n\n");
    // labeled and str variants: same behavior (ignore label/string, store r0 or r2)
    s.push_str(".global vpy_debug_print_labeled\n.type vpy_debug_print_labeled, %function\n.thumb_func\nvpy_debug_print_labeled:\n");
    s.push_str("    ldr     r1, =DBGVAL\n    str     r0, [r1]\n    bx      lr\n\n");
    s.push_str(".global vpy_debug_print_str\n.type vpy_debug_print_str, %function\n.thumb_func\nvpy_debug_print_str:\n");
    s.push_str("    bx      lr\n\n");

    s
}

// ─── MSG_DEF / PRINT_MSG ────────────────────────────────────────────────────
//
// MSG_DEF(id, x, y, "text") is a compile-time declaration — the runtime call
// is a no-op; data is baked into PRINT_MSG_TABLE in flash.
//
// PRINT_MSG_TABLE layout (8 bytes per entry, ids are 1-based):
//   entry[id-1]:
//     +0  x (i8)
//     +1  y (i8)
//     +2  pad (2 bytes)
//     +4  str_ptr (u32 absolute address of null-terminated string)
//
// vpy_print_msg(r0=id): look up table[id-1] → call vpy_print_text(x, y, str_ptr)

fn emit_msg_builtins(entries: &[MsgEntry]) -> String {
    let mut s = String::new();
    s.push_str("@ ─── MSG_DEF / PRINT_MSG ─────────────────────────────────────\n\n");

    // vpy_msg_def — no-op at runtime (data is in the table)
    s.push_str(".global vpy_msg_def\n.type vpy_msg_def, %function\n.thumb_func\nvpy_msg_def:\n");
    s.push_str("    bx      lr\n\n");

    // vpy_print_msg(r0=id)
    s.push_str("@ vpy_print_msg(r0=id): renders message at pre-defined (x,y)\n");
    s.push_str(".global vpy_print_msg\n.type vpy_print_msg, %function\n.thumb_func\nvpy_print_msg:\n");
    if entries.is_empty() {
        // No messages defined — nothing to do
        s.push_str("    bx      lr\n\n");
        return s;
    }
    s.push_str("    push    {r4, lr}              @ 2 regs = 8 bytes, 8-aligned\n");
    s.push_str("    cbz     r0, vpm_done\n");
    s.push_str("    sub     r0, r0, #1            @ 0-based index\n");
    s.push_str("    lsl     r4, r0, #3            @ byte offset = index * 8\n");
    s.push_str("    ldr     r0, =PRINT_MSG_TABLE\n");
    s.push_str("    add     r4, r4, r0            @ entry ptr\n");
    s.push_str("    ldrsb   r0, [r4, #0]          @ x\n");
    s.push_str("    ldrsb   r1, [r4, #1]          @ y\n");
    s.push_str("    ldr     r2, [r4, #4]          @ str_ptr\n");
    s.push_str("    bl      vpy_print_text\n");
    s.push_str("vpm_done:\n    pop     {r4, pc}\n    .ltorg\n\n");

    // Build id → entry map (sorted, 0-based dense table up to max_id)
    let max_id = entries.iter().map(|e| e.id).max().unwrap_or(0) as usize;
    let mut table: Vec<Option<&MsgEntry>> = vec![None; max_id];
    for e in entries {
        if e.id >= 1 && (e.id as usize) <= max_id {
            table[e.id as usize - 1] = Some(e);
        }
    }

    // Emit table and string data
    s.push_str("@ PRINT_MSG_TABLE — 8 bytes per entry (x, y, pad×2, str_ptr)\n");
    s.push_str("PRINT_MSG_TABLE:\n");
    for (i, slot) in table.iter().enumerate() {
        if let Some(e) = slot {
            s.push_str(&format!("    .byte {}, {}  @ id={} x,y\n", e.x as u8, e.y as u8, e.id));
            s.push_str("    .byte 0, 0\n");
            s.push_str(&format!("    .word _pmsg_str_{}\n", i));
        } else {
            s.push_str("    .byte 0, 0, 0, 0\n    .word 0\n");
        }
    }
    s.push_str("\n");
    for (i, slot) in table.iter().enumerate() {
        if let Some(e) = slot {
            s.push_str(&format!("_pmsg_str_{}:\n", i));
            // Emit ASCII bytes followed by null terminator
            let bytes: Vec<u8> = e.text.bytes().collect();
            if bytes.is_empty() {
                s.push_str("    .byte 0\n");
            } else {
                let byte_strs: Vec<String> = bytes.iter().map(|b| format!("{}", b)).collect();
                s.push_str(&format!("    .byte {}, 0\n", byte_strs.join(", ")));
            }
        }
    }
    s.push_str("\n");
    s
}

// ─── LEVEL BUILTINS ────────────────────────────────────────────────────────
//
// ARM .vplay binary format (see levelres.rs compile_to_arm_asm):
//
// Level header (24 bytes, little-endian):
//   +0  xMin(i16)  +2  xMax(i16)  +4  yMin(i16)  +6  yMax(i16)
//   +8  bgCount    +9  gpCount    +10 fgCount     +11 pad
//   +12 bgObjectsPtr(u32)  +16 gpObjectsPtr(u32)  +20 fgObjectsPtr(u32)
//
// Object (16 bytes each):
//   +0  x(i16)  +2  y(i16)
//   +4  scale   +5  intensity   +6  flags   +7  type
//   +8  vector_ptr(u32)
//   +12 half_w  +13 half_h  +14 vel_x_init  +15 vel_y_init
//
// flags: bit0=physics, bit1=gravity, bit4=collidable, bit5=bounce
//
// GP buffer in RAM (LEVEL_GP_BUF): 32 slots × 8 bytes
//   +0 world_x(i16)  +2 world_y(i16)  +4 vel_x(i8)  +5 vel_y(i8)
//   +6 alive(u8)     +7 pad

/// Level system: vpy_load_level / vpy_show_level (+ vsl_draw_static) /
/// vpy_update_level / vpy_get_level_width/height/tile — LEVEL group.
/// vpy_show_level / vsl_draw_static call vpy_draw_vector_ex (dependency).
/// Collision routines live in `emit_level_collision` (LEVEL_COLLISION group).
fn emit_level_builtins() -> String {
    let mut s = String::new();

    // ── vpy_load_level(r0=level_data_ptr) ───────────────────────────────────
    // Stores ptr to LEVEL_DATA_PTR, initializes GP buffer from ROM data.
    s.push_str("@ vpy_load_level(r0=level_data_ptr)\n");
    s.push_str(".global vpy_load_level\n.type vpy_load_level, %function\n.thumb_func\nvpy_load_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, r0                   @ save level ptr\n");
    // Store to LEVEL_DATA_PTR
    s.push_str("    ldr     r1, =LEVEL_DATA_PTR\n    str     r0, [r1]\n");
    // Reset camera
    s.push_str("    ldr     r1, =CAMERA_X\n    mov     r2, #0\n    str     r2, [r1]\n");
    s.push_str("    ldr     r1, =CAMERA_Y\n    str     r2, [r1]\n");
    // Read gpCount (header+9)
    s.push_str("    ldrb    r5, [r4, #9]             @ gpCount\n");
    s.push_str("    ldr     r1, =LEVEL_GP_COUNT\n    str     r5, [r1]\n");
    s.push_str("    cbz     r5, vll_done\n");
    // gpObjectsPtr (header+16)
    s.push_str("    ldr     r6, [r4, #16]            @ ROM gpObjectsPtr\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF        @ GP buffer base\n");
    s.push_str("vll_gp_loop:\n");
    // ROM obj layout (20 bytes): +0=x(i16), +2=y(i16), +4=scale, +5=intensity, +6=flags, +7=type,
    //   +8=vector_ptr(u32), +12=half_w, +13=half_h, +14=vel_x_init, +15=vel_y_init, +16..+19=coll_mesh_ptr
    s.push_str("    ldrsh   r0, [r6, #0]             @ world_x from ROM\n");
    s.push_str("    ldrsh   r1, [r6, #2]             @ world_y from ROM\n");
    s.push_str("    strh    r0, [r7, #0]             @ buf.world_x\n");
    s.push_str("    strh    r1, [r7, #2]             @ buf.world_y\n");
    s.push_str("    ldrsb   r0, [r6, #14]            @ vel_x_init\n");
    s.push_str("    ldrsb   r1, [r6, #15]            @ vel_y_init\n");
    s.push_str("    strb    r0, [r7, #4]             @ buf.vel_x\n");
    s.push_str("    strb    r1, [r7, #5]             @ buf.vel_y\n");
    s.push_str("    mov     r0, #1\n    strb    r0, [r7, #6]             @ buf.alive = 1\n");
    s.push_str("    mov     r0, #0\n    strb    r0, [r7, #7]             @ buf.pad = 0\n");
    s.push_str(&format!("    add     r6, r6, #{}              @ next ROM obj ({} bytes)\n", ARM_ROM_OBJ_STRIDE, ARM_ROM_OBJ_STRIDE));
    s.push_str("    add     r7, r7, #8               @ next buf slot\n");
    s.push_str("    subs    r5, r5, #1\n    bne     vll_gp_loop\n");
    s.push_str("vll_done:\n");
    // Read scroll limits from header (+24..+31): left(i16), right(i16), top(i16), bottom(i16)
    s.push_str("    ldrsh   r0, [r4, #24]            @ scrollLimit left\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_LEFT\n    str     r0, [r1]\n");
    s.push_str("    ldrsh   r0, [r4, #26]            @ scrollLimit right\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_RIGHT\n    str     r0, [r1]\n");
    s.push_str("    ldrsh   r0, [r4, #28]            @ scrollLimit top\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_TOP\n    str     r0, [r1]\n");
    s.push_str("    ldrsh   r0, [r4, #30]            @ scrollLimit bottom\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_BOTTOM\n    str     r0, [r1]\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n    .ltorg\n\n");

    // ── vpy_show_level() ────────────────────────────────────────────────────
    // Draws all objects in BG, GP, FG layers.
    // Static layers (BG/FG): positions from ROM objects.
    // GP layer: positions from GP buffer (mutable), vector_ptr from ROM.
    s.push_str("@ vpy_show_level()\n");
    s.push_str(".global vpy_show_level\n.type vpy_show_level, %function\n.thumb_func\nvpy_show_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}  @ 6 regs = 24 bytes; sp 8-aligned\n");
    s.push_str("    ldr     r4, =LEVEL_DATA_PTR\n    ldr     r4, [r4]    @ r4 = level header\n");
    s.push_str("    cbz     r4, vsl_done\n");
    // BG layer
    s.push_str("    ldrb    r5, [r4, #8]              @ bgCount\n");
    s.push_str("    cbz     r5, vsl_skip_bg\n");
    s.push_str("    ldr     r6, [r4, #12]             @ bgObjectsPtr\n");
    s.push_str("    bl      vsl_draw_static\n");
    s.push_str("vsl_skip_bg:\n");
    // GP layer (positions from buffer)
    s.push_str("    ldr     r5, =LEVEL_GP_COUNT\n    ldr     r5, [r5]    @ gpCount\n");
    s.push_str("    cbz     r5, vsl_skip_gp\n");
    s.push_str("    ldr     r6, [r4, #16]             @ gpObjectsPtr (ROM)\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF\n");
    // Load camera into r8 (CAMERA_X addr; CAMERA_Y = CAMERA_X+4 since they're adjacent)
    s.push_str("    ldr     r8, =CAMERA_X\n");
    s.push_str("vsl_gp_loop:\n");
    s.push_str("    ldrb    r3, [r6, #7]              @ obj type (1=enemy)\n");
    s.push_str("    cmp     r3, #1\n");
    s.push_str("    beq     vsl_gp_next               @ enemies drawn by DRAW_ENEMIES\n");
    s.push_str("    ldrb    r0, [r7, #6]              @ alive\n");
    s.push_str("    cbz     r0, vsl_gp_next\n");
    s.push_str("    ldrsh   r0, [r7, #0]              @ world_x\n");
    s.push_str("    ldrsh   r1, [r7, #2]              @ world_y\n");
    s.push_str("    ldr     r2, [r8]                  @ CAMERA_X value\n");
    s.push_str("    sub     r0, r0, r2                @ screen_x\n");
    s.push_str("    ldr     r2, [r8, #4]              @ CAMERA_Y value\n");
    s.push_str("    sub     r1, r1, r2                @ screen_y\n");
    // Cull |screen_x| > 160
    s.push_str("    movs    r2, r0\n    bpl     vsl_gp_cx_ok\n    neg     r2, r0\n");
    s.push_str("vsl_gp_cx_ok:\n    cmp     r2, #160\n    bgt     vsl_gp_next\n");
    // Cull |screen_y| > 160
    s.push_str("    movs    r2, r1\n    bpl     vsl_gp_cy_ok\n    neg     r2, r1\n");
    s.push_str("vsl_gp_cy_ok:\n    cmp     r2, #160\n    bgt     vsl_gp_next\n");
    // Draw: r0=screen_x, r1=screen_y; get vector_ptr+intensity from ROM obj
    s.push_str("    ldrb    r2, [r6, #5]              @ intensity\n");
    s.push_str("    cmp     r2, #0\n    bne     vsl_gp_havei\n    mov     r2, #127\n");
    s.push_str("vsl_gp_havei:\n");
    // push {intensity(r2), pad(r3=0)} → 8 bytes, maintains 8-alignment
    s.push_str("    mov     r3, #0\n    push    {r2, r3}            @ [sp+0]=intensity pad\n");
    // reorder: r0=vector_ptr, r1=screen_x, r2=screen_y, r3=mirror=0
    s.push_str("    mov     r2, r1                    @ screen_y\n");
    s.push_str("    mov     r1, r0                    @ screen_x\n");
    s.push_str("    ldr     r0, [r6, #8]              @ vector_ptr\n");
    s.push_str("    mov     r3, #0\n    bl      vpy_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #8                @ pop intensity+pad\n");
    s.push_str("vsl_gp_next:\n");
    s.push_str(&format!("    add     r6, r6, #{}               @ next ROM obj ({} bytes)\n", ARM_ROM_OBJ_STRIDE, ARM_ROM_OBJ_STRIDE));
    s.push_str("    add     r7, r7, #8                @ next buf slot\n");
    s.push_str("    subs    r5, r5, #1\n    bne     vsl_gp_loop\n");
    s.push_str("vsl_skip_gp:\n");
    // FG layer
    s.push_str("    ldrb    r5, [r4, #10]             @ fgCount\n");
    s.push_str("    cbz     r5, vsl_done\n");
    s.push_str("    ldr     r6, [r4, #20]             @ fgObjectsPtr\n");
    s.push_str("    bl      vsl_draw_static\n");
    s.push_str("vsl_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n    .ltorg\n\n");

    // ── vsl_draw_static — internal helper ───────────────────────────────────
    // Draws a static (BG or FG) layer: r5=count, r6=ROM ptr (16 bytes/obj)
    // Caller-saved: r4 (level hdr), r8 (camera addr). Must preserve r4, r8.
    // Uses r0-r3 (scratch), r5 (count, decremented), r6 (rom ptr, advanced).
    // Entry sp is (sp_caller - 24). After push {r4,r5,r6,r7,lr} = 20 bytes → sp-44: NOT 8-aligned.
    // To maintain alignment we push {r4,r5,r6,r7,r8,lr} = 24 bytes → sp-48: 8-aligned from sp_caller-24.
    // But we need r4 and r8 from the outer frame! Use local copies in r4,r5,r6,r7.
    // r4 = saved-r5(count), r5 = saved-r6(rom_ptr), r6 = cam_x value, r7 = cam_y value
    s.push_str("@ vsl_draw_static — internal, draws r5 objects from ROM at r6\n");
    s.push_str("vsl_draw_static:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}  @ 24 bytes → 8-aligned\n");
    s.push_str("    mov     r4, r5                    @ count\n");
    s.push_str("    mov     r5, r6                    @ ROM ptr\n");
    s.push_str("    ldr     r6, =CAMERA_X\n    ldr     r6, [r6]\n");
    s.push_str("    ldr     r7, =CAMERA_Y\n    ldr     r7, [r7]\n");
    s.push_str("vsd_loop:\n");
    s.push_str("    cbz     r4, vsd_done\n");
    // Read position from ROM obj (+0=x, +2=y)
    s.push_str("    ldrsh   r0, [r5, #0]              @ world_x\n");
    s.push_str("    ldrsh   r1, [r5, #2]              @ world_y\n");
    s.push_str("    sub     r0, r0, r6                @ screen_x\n");
    s.push_str("    sub     r1, r1, r7                @ screen_y\n");
    // Cull |screen_x| > 160
    s.push_str("    movs    r8, r0\n    bpl     vsd_cx_ok\n    neg     r8, r0\n");
    s.push_str("vsd_cx_ok:\n    cmp     r8, #160\n    bgt     vsd_next\n");
    // Cull |screen_y| > 160
    s.push_str("    movs    r8, r1\n    bpl     vsd_cy_ok\n    neg     r8, r1\n");
    s.push_str("vsd_cy_ok:\n    cmp     r8, #160\n    bgt     vsd_next\n");
    // intensity from ROM obj +5
    s.push_str("    ldrb    r2, [r5, #5]              @ intensity\n");
    s.push_str("    cmp     r2, #0\n    bne     vsd_havei\n    mov     r2, #127\n");
    s.push_str("vsd_havei:\n");
    // push {intensity(r2), pad(r3=0)} → 8 bytes, sp stays 8-aligned (48+8=56)
    s.push_str("    mov     r3, #0\n    push    {r2, r3}\n");
    // args: r0=vector_ptr, r1=screen_x, r2=screen_y, r3=mirror
    s.push_str("    mov     r2, r1                    @ screen_y\n");
    s.push_str("    mov     r1, r0                    @ screen_x\n");
    s.push_str("    ldr     r0, [r5, #8]              @ vector_ptr\n");
    s.push_str("    mov     r3, #0\n    bl      vpy_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("vsd_next:\n");
    s.push_str(&format!("    add     r5, r5, #{}               @ next ROM obj ({} bytes)\n", ARM_ROM_OBJ_STRIDE, ARM_ROM_OBJ_STRIDE));
    s.push_str("    subs    r4, r4, #1\n    b       vsd_loop\n");
    s.push_str("vsd_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n    .ltorg\n\n");

    // ── vpy_update_level() ──────────────────────────────────────────────────
    // Integrates velocity for each alive GP object.
    // Reads physics_flags from ROM (bit1=gravity) and applies gravity (vel_y -= 1).
    // Clamps to world bounds from level header.
    s.push_str("@ vpy_update_level()\n");
    s.push_str(".global vpy_update_level\n.type vpy_update_level, %function\n.thumb_func\nvpy_update_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}  @ 7 regs = 28 bytes; 28 mod 8 = 4 → NOT aligned\n");
    // Actually 7 regs = 28 bytes. If entry sp was 8-aligned, 28 mod 8 = 4, not aligned.
    // Use 8 regs to make it 32 bytes: push {r4,r5,r6,r7,r8,r9,r10,lr}
    // Let me fix: pop the last instruction and redo
    // Actually let me just use 8 regs:
    s.clear();
    // Restart the entire function
    s.push_str("@ vpy_load_level(r0=level_data_ptr)\n");
    s.push_str(".global vpy_load_level\n.type vpy_load_level, %function\n.thumb_func\nvpy_load_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}      @ 5 regs = 20 bytes; NOT 8-aligned from 8n entry\n");
    // Hmm, 5 regs = 20 bytes, 20 mod 8 = 4. Not 8-aligned.
    // 4 regs = 16 bytes → 8-aligned. Use r4-r7 (no lr trick needed if only bl-free).
    // vll_done uses bx lr, but I'm using push/pop with lr. Let me use 6 regs:
    // 6 regs = 24 bytes → 8-aligned. push {r4,r5,r6,r7,r8,lr}.
    s.clear();

    // Ok let me just write it cleanly from scratch, being careful about alignment.
    // ARM AAPCS: sp MUST be 8-byte aligned at all external function call boundaries.
    // Entry: sp is 8-aligned. push N regs → sp -= 4N. For 8-alignment: N must be even.
    // So always push an even number of regs (2, 4, 6, 8...).

    // vpy_load_level: needs r4,r5,r6,r7 + lr = 5 regs. Add r8 for 6 (even).
    s.push_str("@ vpy_load_level(r0=level_data_ptr)\n");
    s.push_str(".global vpy_load_level\n.type vpy_load_level, %function\n.thumb_func\nvpy_load_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}  @ 6 regs = 24 bytes, 8-aligned\n");
    s.push_str("    mov     r4, r0\n");
    s.push_str("    ldr     r1, =LEVEL_DATA_PTR\n    str     r0, [r1]\n");
    s.push_str("    ldrb    r5, [r4, #9]              @ gpCount\n");
    s.push_str("    ldr     r1, =LEVEL_GP_COUNT\n    str     r5, [r1]\n");
    s.push_str("    cbz     r5, vll_done\n");
    s.push_str("    ldr     r6, [r4, #16]             @ gpObjectsPtr\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF\n");
    s.push_str("vll_gp_loop:\n");
    s.push_str("    ldrsh   r0, [r6, #0]              @ world_x\n");
    s.push_str("    ldrsh   r1, [r6, #2]              @ world_y\n");
    s.push_str("    strh    r0, [r7, #0]\n    strh    r1, [r7, #2]\n");
    s.push_str("    ldrsb   r0, [r6, #14]             @ vel_x_init\n");
    s.push_str("    ldrsb   r1, [r6, #15]             @ vel_y_init\n");
    s.push_str("    strb    r0, [r7, #4]\n    strb    r1, [r7, #5]\n");
    s.push_str("    mov     r0, #1\n    strb    r0, [r7, #6]  @ alive=1\n");
    s.push_str("    mov     r0, #0\n    strb    r0, [r7, #7]  @ pad=0\n");
    s.push_str(&format!("    add     r6, r6, #{}    @ next ROM obj ({} bytes)\n    add     r7, r7, #8\n", ARM_ROM_OBJ_STRIDE, ARM_ROM_OBJ_STRIDE));
    s.push_str("    subs    r5, r5, #1\n    bne     vll_gp_loop\n");
    s.push_str("vll_done:\n");
    // Read scroll limits from header (+24..+31)
    s.push_str("    ldrsh   r0, [r4, #24]             @ scrollLimit left\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_LEFT\n    str     r0, [r1]\n");
    s.push_str("    ldrsh   r0, [r4, #26]             @ scrollLimit right\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_RIGHT\n    str     r0, [r1]\n");
    s.push_str("    ldrsh   r0, [r4, #28]             @ scrollLimit top\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_TOP\n    str     r0, [r1]\n");
    s.push_str("    ldrsh   r0, [r4, #30]             @ scrollLimit bottom\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_BOTTOM\n    str     r0, [r1]\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n    .ltorg\n\n");

    // ── vpy_show_level() ────────────────────────────────────────────────────
    s.push_str("@ vpy_show_level()\n");
    s.push_str(".global vpy_show_level\n.type vpy_show_level, %function\n.thumb_func\nvpy_show_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}  @ 6 regs = 24 bytes, 8-aligned\n");
    s.push_str("    ldr     r4, =LEVEL_DATA_PTR\n    ldr     r4, [r4]\n");
    s.push_str("    cbz     r4, vsl_done\n");
    // BG
    s.push_str("    ldrb    r5, [r4, #8]              @ bgCount\n");
    s.push_str("    cbz     r5, vsl_skip_bg\n");
    s.push_str("    ldr     r6, [r4, #12]             @ bgObjectsPtr\n");
    s.push_str("    bl      vsl_draw_static\n");
    s.push_str("vsl_skip_bg:\n");
    // GP
    s.push_str("    ldr     r5, =LEVEL_GP_COUNT\n    ldr     r5, [r5]\n");
    s.push_str("    cbz     r5, vsl_skip_gp\n");
    s.push_str("    ldr     r6, [r4, #16]             @ gpObjectsPtr (ROM)\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF\n");
    s.push_str("    ldr     r8, =CAMERA_X\n");
    s.push_str("vsl_gp_loop:\n");
    s.push_str("    ldrb    r3, [r6, #7]              @ obj type (1=enemy)\n");
    s.push_str("    cmp     r3, #1\n");
    s.push_str("    beq     vsl_gp_next               @ enemies drawn by DRAW_ENEMIES\n");
    s.push_str("    ldrb    r0, [r7, #6]              @ alive\n");
    s.push_str("    cbz     r0, vsl_gp_next\n");
    s.push_str("    ldrsh   r0, [r7, #0]              @ world_x\n");
    s.push_str("    ldrsh   r1, [r7, #2]              @ world_y\n");
    s.push_str("    ldr     r2, [r8]\n    sub     r0, r0, r2  @ screen_x\n");
    s.push_str("    ldr     r2, [r8, #4]\n    sub     r1, r1, r2  @ screen_y (CAMERA_Y=CAMERA_X+4)\n");
    s.push_str("    movs    r2, r0\n    bpl     vsl_gp_cx_ok\n    neg     r2, r0\n");
    s.push_str("vsl_gp_cx_ok:\n    cmp     r2, #160\n    bgt     vsl_gp_next\n");
    s.push_str("    movs    r2, r1\n    bpl     vsl_gp_cy_ok\n    neg     r2, r1\n");
    s.push_str("vsl_gp_cy_ok:\n    cmp     r2, #160\n    bgt     vsl_gp_next\n");
    s.push_str("    ldrb    r2, [r6, #5]              @ intensity\n");
    s.push_str("    cmp     r2, #0\n    bne     vsl_gp_havei\n    mov     r2, #127\n");
    s.push_str("vsl_gp_havei:\n");
    s.push_str("    mov     r3, #0\n    push    {r2, r3}            @ [sp]=intensity, align+8\n");
    s.push_str("    mov     r2, r1\n    mov     r1, r0\n    ldr     r0, [r6, #8]  @ vector_ptr\n");
    s.push_str("    mov     r3, #0\n    bl      vpy_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("vsl_gp_next:\n");
    s.push_str(&format!("    add     r6, r6, #{}    @ next ROM obj ({} bytes)\n    add     r7, r7, #8\n", ARM_ROM_OBJ_STRIDE, ARM_ROM_OBJ_STRIDE));
    s.push_str("    subs    r5, r5, #1\n    bne     vsl_gp_loop\n");
    s.push_str("vsl_skip_gp:\n");
    // FG
    s.push_str("    ldrb    r5, [r4, #10]             @ fgCount\n");
    s.push_str("    cbz     r5, vsl_done\n");
    s.push_str("    ldr     r6, [r4, #20]             @ fgObjectsPtr\n");
    s.push_str("    bl      vsl_draw_static\n");
    s.push_str("vsl_done:\n    pop     {r4, r5, r6, r7, r8, pc}\n    .ltorg\n\n");

    // ── vsl_draw_static — internal subroutine ───────────────────────────────
    // r5=count, r6=ROM obj ptr (16 bytes/obj). Caller has 24 bytes on stack (8-aligned).
    // We push 24 bytes here (6 regs) → total 48, still 8-aligned. ✓
    s.push_str("@ vsl_draw_static — internal\n");
    s.push_str("vsl_draw_static:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}  @ 24 bytes\n");
    s.push_str("    mov     r4, r5                    @ count\n");
    s.push_str("    mov     r5, r6                    @ ROM ptr\n");
    s.push_str("    ldr     r6, =CAMERA_X\n    ldr     r6, [r6]\n");
    s.push_str("    ldr     r7, =CAMERA_Y\n    ldr     r7, [r7]\n");
    s.push_str("vsd_loop:\n    cbz     r4, vsd_done\n");
    s.push_str("    ldrsh   r0, [r5, #0]\n    ldrsh   r1, [r5, #2]\n");
    s.push_str("    sub     r0, r0, r6\n    sub     r1, r1, r7\n");
    s.push_str("    movs    r8, r0\n    bpl     vsd_cx_ok\n    neg     r8, r0\n");
    s.push_str("vsd_cx_ok:\n    cmp     r8, #160\n    bgt     vsd_next\n");
    s.push_str("    movs    r8, r1\n    bpl     vsd_cy_ok\n    neg     r8, r1\n");
    s.push_str("vsd_cy_ok:\n    cmp     r8, #160\n    bgt     vsd_next\n");
    s.push_str("    ldrb    r2, [r5, #5]\n    cmp     r2, #0\n    bne     vsd_havei\n    mov     r2, #127\n");
    s.push_str("vsd_havei:\n");
    // push {intensity, pad} = 8 bytes → total (24+24+8=56), 8-aligned ✓
    s.push_str("    mov     r3, #0\n    push    {r2, r3}\n");
    s.push_str("    mov     r2, r1\n    mov     r1, r0\n    ldr     r0, [r5, #8]\n");
    s.push_str("    mov     r3, #0\n    bl      vpy_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("vsd_next:\n    ");
    s.push_str(&format!("add     r5, r5, #{}    @ next ROM obj ({} bytes)\n    subs    r4, r4, #1\n    b       vsd_loop\n", ARM_ROM_OBJ_STRIDE, ARM_ROM_OBJ_STRIDE));
    s.push_str("vsd_done:\n    pop     {r4, r5, r6, r7, r8, pc}\n    .ltorg\n\n");

    // ── vpy_update_level() ──────────────────────────────────────────────────
    // Physics: integrate velocity, apply gravity (if bit1 of ROM flags set), clamp to world bounds.
    s.push_str("@ vpy_update_level()\n");
    s.push_str(".global vpy_update_level\n.type vpy_update_level, %function\n.thumb_func\nvpy_update_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}  @ 8 regs = 32 bytes, 8-aligned\n");
    s.push_str("    ldr     r4, =LEVEL_DATA_PTR\n    ldr     r4, [r4]\n");
    s.push_str("    cbz     r4, vul_done\n");
    // World bounds: xMin(+0), xMax(+2), yMin(+4), yMax(+6)
    s.push_str("    ldrsh   r6, [r4, #0]              @ xMin\n");
    s.push_str("    ldrsh   r7, [r4, #2]              @ xMax\n");
    s.push_str("    ldrsh   r8, [r4, #4]              @ yMin\n");
    s.push_str("    ldrsh   r9, [r4, #6]              @ yMax\n");
    // gpCount and gpObjectsPtr
    s.push_str("    ldr     r5, =LEVEL_GP_COUNT\n    ldr     r5, [r5]\n");
    s.push_str("    cbz     r5, vul_done\n");
    s.push_str("    ldr     r10, [r4, #16]            @ gpObjectsPtr (ROM, for flags)\n");
    s.push_str("    ldr     r4, =LEVEL_GP_BUF\n");
    s.push_str("vul_loop:\n");
    s.push_str("    ldrb    r0, [r4, #6]              @ alive\n");
    s.push_str("    cbz     r0, vul_next\n");
    s.push_str("    ldrb    r0, [r10, #6]             @ ROM flags\n");
    // Gravity: if bit1 set, vel_y -= 1 (downward)
    s.push_str("    tst     r0, #0x02\n    beq     vul_nograv\n");
    s.push_str("    ldrsb   r1, [r4, #5]              @ vel_y\n");
    s.push_str("    sub     r1, r1, #1\n");
    s.push_str("    cmp     r1, #-127\n    bge     vul_vy_ok\n    mov     r1, #-127\n");
    s.push_str("vul_vy_ok:\n    strb    r1, [r4, #5]\n");
    s.push_str("vul_nograv:\n");
    // Integrate: world_x += vel_x, world_y += vel_y
    s.push_str("    ldrsh   r1, [r4, #0]              @ world_x\n");
    s.push_str("    ldrsb   r2, [r4, #4]              @ vel_x\n");
    s.push_str("    add     r1, r1, r2\n");
    // Clamp x
    s.push_str("    cmp     r1, r6\n    bge     vul_x_min_ok\n    mov     r1, r6\n    mov     r2, #0\n    strb    r2, [r4, #4]\n");
    s.push_str("vul_x_min_ok:\n    cmp     r1, r7\n    ble     vul_x_max_ok\n    mov     r1, r7\n    mov     r2, #0\n    strb    r2, [r4, #4]\n");
    s.push_str("vul_x_max_ok:\n    strh    r1, [r4, #0]\n");
    s.push_str("    ldrsh   r1, [r4, #2]              @ world_y\n");
    s.push_str("    ldrsb   r2, [r4, #5]              @ vel_y\n");
    s.push_str("    add     r1, r1, r2\n");
    // Clamp y
    s.push_str("    cmp     r1, r8\n    bge     vul_y_min_ok\n    mov     r1, r8\n    mov     r2, #0\n    strb    r2, [r4, #5]\n");
    s.push_str("vul_y_min_ok:\n    cmp     r1, r9\n    ble     vul_y_max_ok\n    mov     r1, r9\n    mov     r2, #0\n    strb    r2, [r4, #5]\n");
    s.push_str("vul_y_max_ok:\n    strh    r1, [r4, #2]\n");
    s.push_str("vul_next:\n");
    s.push_str("    add     r4, r4, #8\n");
    s.push_str(&format!("    add     r10, r10, #{}  @ next ROM obj ({} bytes)\n", ARM_ROM_OBJ_STRIDE, ARM_ROM_OBJ_STRIDE));
    s.push_str("    subs    r5, r5, #1\n    bne     vul_loop\n");
    s.push_str("vul_done:\n    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n    .ltorg\n\n");

    // ── vpy_get_level_width() → r0 = xMax - xMin ────────────────────────────
    s.push_str("@ vpy_get_level_width() -> r0\n");
    s.push_str(".global vpy_get_level_width\n.type vpy_get_level_width, %function\n.thumb_func\nvpy_get_level_width:\n");
    s.push_str("    ldr     r0, =LEVEL_DATA_PTR\n    ldr     r0, [r0]\n");
    s.push_str("    cbz     r0, vglw_null\n");
    s.push_str("    ldrsh   r1, [r0, #2]              @ xMax\n");
    s.push_str("    ldrsh   r0, [r0, #0]              @ xMin\n");
    s.push_str("    sub     r0, r1, r0\n    bx      lr\n");
    s.push_str("vglw_null:\n    mov     r0, #0\n    bx      lr\n    .ltorg\n\n");

    // ── vpy_get_level_height() → r0 = yMax - yMin ───────────────────────────
    s.push_str("@ vpy_get_level_height() -> r0\n");
    s.push_str(".global vpy_get_level_height\n.type vpy_get_level_height, %function\n.thumb_func\nvpy_get_level_height:\n");
    s.push_str("    ldr     r0, =LEVEL_DATA_PTR\n    ldr     r0, [r0]\n");
    s.push_str("    cbz     r0, vglh_null\n");
    s.push_str("    ldrsh   r1, [r0, #6]              @ yMax\n");
    s.push_str("    ldrsh   r0, [r0, #4]              @ yMin\n");
    s.push_str("    sub     r0, r1, r0\n    bx      lr\n");
    s.push_str("vglh_null:\n    mov     r0, #0\n    bx      lr\n    .ltorg\n\n");

    // ── vpy_get_level_tile(r0=x, r1=y) → r0 = GP object index, or -1 ────────
    // Finds first alive GP object whose world position is within 16 units of (x,y).
    s.push_str("@ vpy_get_level_tile(r0=x, r1=y) -> index or -1\n");
    s.push_str(".global vpy_get_level_tile\n.type vpy_get_level_tile, %function\n.thumb_func\nvpy_get_level_tile:\n");
    s.push_str("    push    {r4, r5, r6, lr}           @ 4 regs = 16 bytes, 8-aligned\n");
    s.push_str("    mov     r4, r0                    @ query_x\n");
    s.push_str("    mov     r5, r1                    @ query_y\n");
    s.push_str("    ldr     r6, =LEVEL_GP_COUNT\n    ldr     r6, [r6]\n");
    s.push_str("    ldr     r0, =LEVEL_GP_BUF\n");
    s.push_str("    mov     r1, #0                    @ index\n");
    s.push_str("vglt_loop:\n    cmp     r1, r6\n    bge     vglt_notfound\n");
    s.push_str("    ldrb    r2, [r0, #6]\n    cbz     r2, vglt_next\n");
    s.push_str("    ldrsh   r2, [r0, #0]              @ world_x\n");
    s.push_str("    sub     r2, r2, r4\n");
    s.push_str("    movs    r3, r2\n    bpl     vglt_dx_ok\n    neg     r2, r2\n");
    s.push_str("vglt_dx_ok:\n    cmp     r2, #16\n    bgt     vglt_next\n");
    s.push_str("    ldrsh   r2, [r0, #2]              @ world_y\n");
    s.push_str("    sub     r2, r2, r5\n");
    s.push_str("    movs    r3, r2\n    bpl     vglt_dy_ok\n    neg     r2, r2\n");
    s.push_str("vglt_dy_ok:\n    cmp     r2, #16\n    bgt     vglt_next\n");
    s.push_str("    mov     r0, r1                    @ return index\n");
    s.push_str("    pop     {r4, r5, r6, pc}\n");
    s.push_str("vglt_next:\n    add     r0, r0, #8\n    add     r1, r1, #1\n    b       vglt_loop\n");
    s.push_str("vglt_notfound:\n    mvn     r0, #0            @ return -1\n");
    s.push_str("    pop     {r4, r5, r6, pc}\n    .ltorg\n\n");

    s
}

/// vpy_level_collision_x / vpy_level_collision_y — LEVEL_COLLISION group.
/// Leaf routines (touch RAM equates only); also a dep of ENEMIES (wander AI
/// calls vpy_level_collision_x for wall push-out).
fn emit_level_collision() -> String {
    let mut s = String::new();

    // ── vpy_level_collision_x(r0=px, r1=py, r2=half_w, r3=half_h) → r0 = push-out dx ──
    // Scans collidable GP objects with wall mesh segments. Returns push-out dx (0 if none).
    // r3=half_h used for Y-overlap so player standing on top of a wall is not pushed sideways.
    s.push_str("@ vpy_level_collision_x(r0=px, r1=py, r2=hw, r3=hy) -> push-out dx\n");
    s.push_str(".global vpy_level_collision_x\n.type vpy_level_collision_x, %function\n.thumb_func\nvpy_level_collision_x:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    mov     r4, r0              @ px\n");
    s.push_str("    mov     r5, r1              @ py\n");
    s.push_str("    mov     r6, r2              @ half_w (player)\n");
    s.push_str("    mov     r11, r3             @ half_h (player)\n");
    s.push_str("    ldr     r7, =LEVEL_DATA_PTR\n    ldr     r7, [r7]\n");
    s.push_str("    cbz     r7, vlcx_done_zero\n");
    s.push_str("    ldr     r8, =LEVEL_GP_COUNT\n    ldr     r8, [r8]\n");
    s.push_str("    cbz     r8, vlcx_done_zero\n");
    s.push_str("    ldr     r9, [r7, #16]       @ gpObjectsPtr (ROM)\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF\n");
    s.push_str("    mov     r10, #0             @ best push-out dx\n");
    s.push_str("vlcx_loop:\n    cbz     r8, vlcx_done\n");
    s.push_str("    ldrb    r0, [r7, #6]\n    cbz     r0, vlcx_next\n");
    s.push_str("    ldrb    r0, [r9, #6]\n    tst     r0, #0x10\n    beq     vlcx_next\n");
    // only objects with a mesh can have wall segments
    s.push_str("    ldr     r0, [r9, #16]       @ coll_mesh_ptr\n");
    s.push_str("    cbz     r0, vlcx_next       @ no mesh = floor only\n");
    // skip floor section: advance past floor_count word + floor_count*8 bytes
    s.push_str("    ldr     r1, [r0]            @ floor_count\n");
    s.push_str("    add     r0, r0, #4          @ skip floor_count word\n");
    s.push_str("    lsl     r1, r1, #3          @ floor_count * 8 bytes per seg\n");
    s.push_str("    add     r0, r0, r1          @ r0 = ptr to wall_count\n");
    s.push_str("    ldr     r1, [r0]            @ wall_count\n");
    s.push_str("    cbz     r1, vlcx_next\n");
    s.push_str("    add     r0, r0, #4          @ r0 = ptr to first wall seg\n");
    s.push_str("vlcx_wall_loop:\n");
    s.push_str("    cbz     r1, vlcx_next\n");
    // load segment: .hword wall_x, y_min, wall_x, y_max
    s.push_str("    ldrsh   r2, [r0]            @ wall local x\n");
    s.push_str("    ldrsh   r3, [r0, #2]        @ wall local y_min\n");
    s.push_str("    ldrsh   r12, [r0, #6]       @ wall local y_max\n");
    s.push_str("    add     r0, r0, #8\n");
    s.push_str("    subs    r1, r1, #1\n");
    // convert to world coords using RAM obj position (r7)
    s.push_str("    ldrsh   r14, [r7, #0]       @ obj world_x\n");
    s.push_str("    add     r2, r2, r14         @ world_wall_x\n");
    s.push_str("    ldrsh   r14, [r7, #2]       @ obj world_y\n");
    s.push_str("    add     r3, r3, r14         @ world_y_min\n");
    s.push_str("    add     r12, r12, r14       @ world_y_max\n");
    // Y-overlap (strict): player is within wall height
    // Skip if py <= y_min - player_hh (player below wall) or py >= y_max + player_hh (above)
    s.push_str("    sub     r14, r3, r11        @ world_y_min - player_hh\n");
    s.push_str("    cmp     r5, r14\n    ble     vlcx_wall_loop  @ py below wall\n");
    s.push_str("    add     r14, r12, r11       @ world_y_max + player_hh\n");
    s.push_str("    cmp     r5, r14\n    bge     vlcx_wall_loop  @ py above wall\n");
    // X-overlap: |px - wall_x| < player_hw
    s.push_str("    sub     r3, r4, r2          @ dx_raw = px - wall_x\n");
    s.push_str("    movs    r2, r3              @ r2 = dx_raw; sets N flag\n");
    s.push_str("    bpl     vlcx_wall_dx_ok\n    neg     r3, r3  @ r3 = |dx_raw|\n");
    s.push_str("vlcx_wall_dx_ok:\n");
    s.push_str("    cmp     r3, r6\n    bge     vlcx_wall_loop  @ |dx| >= hw: no overlap\n");
    // push-out = sign(dx_raw) * (player_hw - |dx|)
    s.push_str("    sub     r3, r6, r3          @ overlap = hw - |dx|\n");
    s.push_str("    cmp     r2, #0\n    bge     vlcx_wall_sign_ok\n    neg     r3, r3\n");
    s.push_str("vlcx_wall_sign_ok:\n    mov     r10, r3\n    b.w     vlcx_next\n");
    s.push_str(&format!("vlcx_next:\n    add     r7, r7, #8\n    add     r9, r9, #{}    @ next ROM obj\n", ARM_ROM_OBJ_STRIDE));
    s.push_str("    subs    r8, r8, #1\n    b.w     vlcx_loop\n");
    s.push_str("vlcx_done:\n    mov     r0, r10\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n");
    s.push_str("vlcx_done_zero:\n    mov     r0, #0\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    // ── vpy_level_collision_y(r0=px, r1=py, r2=half_h) → r0 = floor_y ───────
    // Finds the highest floor at or below player's feet (py - half_h).
    // For objects with coll_mesh_ptr != 0: ray-casts against horizontal segments
    //   (mesh format: .word seg_count; .hword x1,y1,x2,y2 per segment, local coords).
    // For objects without a mesh: AABB fallback (world_y + half_h).
    // Returns best_floor_top + half_h (player center Y when standing).
    // Returns -128 + half_h if no floor found.
    s.push_str("@ vpy_level_collision_y(r0=px, r1=py, r2=hh) -> floor_center_y\n");
    s.push_str(".global vpy_level_collision_y\n.type vpy_level_collision_y, %function\n.thumb_func\nvpy_level_collision_y:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}  @ 9 regs\n");
    s.push_str("    mov     r4, r0                    @ px\n");
    s.push_str("    sub     r5, r1, r2                @ player_feet = py - hh\n");
    s.push_str("    mov     r6, r2                    @ half_h (player)\n");
    s.push_str("    ldr     r7, =LEVEL_DATA_PTR\n    ldr     r7, [r7]\n");
    s.push_str("    ldr     r10, =-32767              @ best_floor_top sentinel\n");
    s.push_str("    cbz     r7, vlcy_finish\n");
    s.push_str("    ldr     r8, =LEVEL_GP_COUNT\n    ldr     r8, [r8]\n");
    s.push_str("    cbz     r8, vlcy_finish\n");
    s.push_str("    ldr     r9, [r7, #16]             @ gpObjectsPtr (ROM)\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF\n");
    s.push_str("vlcy_loop:\n    cbz     r8, vlcy_finish\n");
    s.push_str("    ldrb    r1, [r7, #6]\n    cbz     r1, vlcy_next\n");
    s.push_str("    ldrb    r1, [r9, #6]\n    tst     r1, #0x10\n    beq     vlcy_next\n");
    s.push_str("    ldrb    r1, [r9, #12]             @ obj half_w\n");
    s.push_str("    ldrsh   r2, [r7, #0]              @ obj world_x\n");
    s.push_str("    sub     r2, r4, r2                @ dx = px - obj_x\n");
    s.push_str("    movs    r3, r2\n    bpl     vlcy_dxok\n    neg     r3, r2\n");
    s.push_str("vlcy_dxok:\n    cmp     r3, r1\n    bgt     vlcy_next\n");
    s.push_str("    ldr     r11, [r9, #16]            @ coll_mesh_ptr\n");
    s.push_str("    cmp     r11, #0\n    beq     vlcy_aabb\n");
    s.push_str("    ldrsh   r0, [r7, #0]              @ obj_world_x\n");
    s.push_str("    sub     r0, r4, r0                @ local_px = px - obj_world_x\n");
    s.push_str("    ldrsh   r1, [r7, #2]              @ obj_world_y\n");
    s.push_str("    push    {r0, r1}                  @ [sp]=local_px [sp+4]=obj_world_y\n");
    s.push_str("    ldr     r12, [r11], #4            @ seg_count; r11 → first segment\n");
    s.push_str("vlcy_seg_loop:\n    cmp     r12, #0\n    beq     vlcy_seg_done\n");
    s.push_str("    ldrsh   r0, [r11]                 @ x1\n");
    s.push_str("    ldrsh   r1, [r11, #2]             @ y1\n");
    s.push_str("    ldrsh   r2, [r11, #4]             @ x2\n");
    s.push_str("    ldrsh   r3, [r11, #6]             @ y2\n");
    s.push_str("    add     r11, r11, #8\n    subs    r12, r12, #1\n");
    s.push_str("    cmp     r1, r3\n    bne     vlcy_seg_loop @ skip non-horizontal\n");
    s.push_str("    ldr     r14, [sp]                 @ local_px\n");
    s.push_str("    cmp     r0, r2\n    blt     vlcy_seg_x1lt\n");
    s.push_str("    cmp     r14, r2\n    blt     vlcy_seg_loop\n");
    s.push_str("    cmp     r14, r0\n    bgt     vlcy_seg_loop\n");
    s.push_str("    b       vlcy_seg_y\n");
    s.push_str("vlcy_seg_x1lt:\n");
    s.push_str("    cmp     r14, r0\n    blt     vlcy_seg_loop\n");
    s.push_str("    cmp     r14, r2\n    bgt     vlcy_seg_loop\n");
    s.push_str("vlcy_seg_y:\n");
    s.push_str("    ldr     r14, [sp, #4]             @ obj_world_y\n");
    s.push_str("    add     r3, r1, r14               @ world_seg_y = y1 + obj_world_y\n");
    s.push_str("    cmp     r3, r5\n    bgt     vlcy_seg_loop\n");
    s.push_str("    cmp     r3, r10\n    ble     vlcy_seg_loop\n");
    s.push_str("    mov     r10, r3\n    b       vlcy_seg_loop\n");
    s.push_str("vlcy_seg_done:\n    pop     {r0, r1}\n    b       vlcy_next\n");
    s.push_str("vlcy_aabb:\n");
    s.push_str("    ldrsh   r2, [r7, #2]              @ obj world_y\n");
    s.push_str("    ldrb    r3, [r9, #13]             @ obj half_h\n");
    s.push_str("    add     r2, r2, r3                @ obj_top = world_y + half_h\n");
    s.push_str("    cmp     r2, r5\n    bgt     vlcy_next\n");
    s.push_str("    cmp     r10, r2\n    bge     vlcy_next\n    mov     r10, r2\n");
    s.push_str(&format!("vlcy_next:\n    add     r7, r7, #8\n    add     r9, r9, #{}    @ next ROM obj ({} bytes)\n", ARM_ROM_OBJ_STRIDE, ARM_ROM_OBJ_STRIDE));
    s.push_str("    subs    r8, r8, #1\n    b       vlcy_loop\n");
    s.push_str("vlcy_finish:\n");
    s.push_str("    ldr     r1, =-32767\n    cmp     r10, r1\n    beq     vlcy_no_floor\n");
    s.push_str("    add     r0, r10, r6               @ floor_top + half_h\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("vlcy_no_floor:\n");
    // r5 = player_feet (py - hh). Returning player_feet ensures floor_y < player_y so
    // the walkoff check triggers correctly. The old -128+hh constant is a Vectrex screen
    // coordinate and is far above the actual world Y on screens with large negative Y values,
    // causing the player to stay grounded even when standing over a gap.
    s.push_str("    mov     r0, r5                    @ no floor: return player_feet so floor_y < player_y\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n    .ltorg\n\n");

    s
}

// ─── DRAW_ANIM ──────────────────────────────────────────────────────────────
//
// vpy_draw_anim(r0 = ptr to _ANIM_NAME ARM data block)
//
// ARM vanim data format (see arm/assets.rs compile_vanim_for_arm):
//   Header:
//     byte 0: frame_count
//     byte 1: loop_flag
//     byte 2: base_ref_count
//     byte 3: frame_table_offset = 4 + base_ref_count*4
//     words [4..]: ARM ptrs to base_ref vec data
//     words [frame_table_offset..]: ARM ptrs to frame data
//   Frame block:
//     byte 0: duration_ticks
//     byte 1: vec_ref_count
//     (2-byte pad if vec_ref_count > 0)
//     words [4..]: ARM ptrs to vec data
//     byte: inline_path_count (0)

fn emit_draw_anim() -> String {
    let mut s = String::new();
    s.push_str("@ vpy_draw_anim(r0=anim_ptr, r1=ox, r2=oy, r3=state_ptr, r4=mirror)\n");
    s.push_str(".global vpy_draw_anim\n.type vpy_draw_anim, %function\n.thumb_func\nvpy_draw_anim:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, r12, lr}\n");
    s.push_str("    mov     r12, r4                     @ save mirror before r4 overwritten\n");
    s.push_str("    mov     r4, r0                      @ anim header ptr\n");
    s.push_str("    mov     r10, r1                     @ save ox\n");
    s.push_str("    mov     r11, r2                     @ save oy\n");
    s.push_str("    mov     r5, r3                      @ state_ptr from caller\n");
    s.push_str("    ldrb    r6, [r5]                    @ frame_idx\n");
    s.push_str("    ldrb    r7, [r5, #1]                @ ticks_left (0=uninitialized)\n");

    // Draw base_refs every frame
    s.push_str("    ldrb    r8, [r4, #2]                @ base_ref_count\n");
    s.push_str("    cmp     r8, #0\n");
    s.push_str("    beq     dar_tick\n");
    s.push_str("    add     r9, r4, #4                  @ first base_ref word-ptr\n");
    s.push_str("dar_base_loop:\n");
    s.push_str("    push    {r8, r9}\n");
    s.push_str("    sub     sp, sp, #8                  @ intensity slot + align\n");
    s.push_str("    mov     r0, #127\n");
    s.push_str("    str     r0, [sp]                    @ intensity = 127\n");
    s.push_str("    ldr     r0, [r9]                    @ ARM ptr to vec data\n");
    s.push_str("    mov     r1, r10                     @ ox\n");
    s.push_str("    mov     r2, r11                     @ oy\n");
    s.push_str("    mov     r3, r12                     @ mirror\n");
    s.push_str("    bl      vpy_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("    pop     {r8, r9}\n");
    s.push_str("    add     r9, r9, #4\n");
    s.push_str("    subs    r8, r8, #1\n");
    s.push_str("    bne     dar_base_loop\n");

    // Tick management
    s.push_str("dar_tick:\n");
    s.push_str("    cmp     r7, #0\n");
    s.push_str("    beq     dar_init_frame\n");
    s.push_str("    subs    r7, r7, #1\n");
    s.push_str("    bgt     dar_draw\n");

    // Ticks exhausted: advance frame
    s.push_str("    ldrb    r8, [r4]                    @ frame_count\n");
    s.push_str("    add     r6, r6, #1\n");
    s.push_str("    cmp     r6, r8\n");
    s.push_str("    blt     dar_no_wrap\n");
    s.push_str("    ldrb    r9, [r4, #1]                @ loop flag\n");
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    beq     dar_freeze\n");
    s.push_str("    mov     r6, #0\n");
    s.push_str("dar_no_wrap:\n");
    s.push_str("    strb    r6, [r5]\n");

    // Load frame ptr and init duration
    s.push_str("dar_init_frame:\n");
    s.push_str("    ldrb    r8, [r4, #3]                @ frame_table_offset\n");
    s.push_str("    lsl     r9, r6, #2                  @ frame_idx * 4\n");
    s.push_str("    add     r9, r9, r8\n");
    s.push_str("    ldr     r9, [r4, r9]                @ ARM ptr to frame data\n");
    s.push_str("    ldrb    r7, [r9]                    @ duration_ticks\n");
    s.push_str("    cmp     r7, #0\n");
    s.push_str("    it      le\n");
    s.push_str("    movle   r7, #1\n");
    s.push_str("    strb    r7, [r5, #1]\n");
    s.push_str("    b       dar_draw_vecs\n");

    s.push_str("dar_freeze:\n");
    s.push_str("    sub     r6, r6, #1\n");
    s.push_str("    strb    r6, [r5]\n");
    s.push_str("    mov     r7, #1\n");
    s.push_str("    strb    r7, [r5, #1]\n");
    s.push_str("    b       dar_draw_frame\n");

    s.push_str("dar_draw:\n");
    s.push_str("    strb    r7, [r5, #1]\n");

    s.push_str("dar_draw_frame:\n");
    s.push_str("    ldrb    r8, [r4, #3]                @ frame_table_offset\n");
    s.push_str("    lsl     r9, r6, #2\n");
    s.push_str("    add     r9, r9, r8\n");
    s.push_str("    ldr     r9, [r4, r9]                @ ARM ptr to frame data\n");

    s.push_str("dar_draw_vecs:\n");
    s.push_str("    ldrb    r8, [r9, #1]                @ vec_ref_count\n");
    s.push_str("    cmp     r8, #0\n");
    s.push_str("    beq     dar_done\n");
    s.push_str("    add     r9, r9, #4                  @ skip duration+count+2-byte pad\n");
    s.push_str("    mov     r6, r8\n");
    s.push_str("dar_vec_loop:\n");
    s.push_str("    push    {r6, r9}\n");
    s.push_str("    sub     sp, sp, #8                  @ intensity slot + align\n");
    s.push_str("    mov     r0, #127\n");
    s.push_str("    str     r0, [sp]                    @ intensity = 127\n");
    s.push_str("    ldr     r0, [r9]                    @ ARM ptr to vec data\n");
    s.push_str("    mov     r1, r10                     @ ox\n");
    s.push_str("    mov     r2, r11                     @ oy\n");
    s.push_str("    mov     r3, r12                     @ mirror\n");
    s.push_str("    bl      vpy_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("    pop     {r6, r9}\n");
    s.push_str("    add     r9, r9, #4\n");
    s.push_str("    subs    r6, r6, #1\n");
    s.push_str("    bne     dar_vec_loop\n");
    s.push_str("dar_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, r12, pc}\n");
    s.push_str("    .ltorg\n\n");

    s
}
