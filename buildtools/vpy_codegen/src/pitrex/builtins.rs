//! PiTrex ARM32 builtin helper functions.
//!
//! These are the runtime helpers that VPy builtins compile to on the PiTrex
//! target. They wrap the PiTrex SDK (libvectrexInterface.a).
//!
//! Calling convention: ARM AAPCS
//!   Arguments:  r0–r3 (first 4 args), additional args on stack
//!   Return:     r0
//!   Callee-save: r4–r11, sp, lr (we save/restore r4+)
//!
//! Key SDK functions (all ARM32):
//!   v_WaitRecal()                                     — frame sync
//!   v_setBrightness(int b)                            — r0=brightness 0-127
//!   v_directDraw32(int x0,y0,int x1,y1,int bright)   — draw vector segment
//!   v_readButtons()                                   — fills currentButtonState
//!   v_readJoystick1Analog()                           — fills currentJoy1X/Y
//!
//! Globals (from SDK):
//!   currentJoy1X, currentJoy1Y  — int32, raw joystick values ±32767
//!   currentButtonState          — uint32, buttons as bits
//!
//! Coordinate scaling: VPy ±96/±128 → PiTrex ±18000/±24000
//!   Scale factor = 180 (VPy 96×180 = 17280, VPy 128×180 = 23040)
//!
//! Beam tracking: PITREX_CUR_X, PITREX_CUR_Y in .bss (set by draw fns)

/// Emit all PiTrex builtin helper functions as ARM32 assembly.
pub fn emit_builtins() -> String {
    let mut s = String::new();

    s.push_str("@ ================================================================\n");
    s.push_str("@ PiTrex ARM32 builtins\n");
    s.push_str("@ ================================================================\n\n");

    s.push_str(&emit_pitrex_wait_recal());
    s.push_str(&emit_pitrex_set_intensity());
    s.push_str(&emit_pitrex_move());
    s.push_str(&emit_pitrex_draw_line());
    s.push_str(&emit_pitrex_draw_line_rel());
    s.push_str(&emit_pitrex_draw_vector());
    s.push_str(&emit_pitrex_draw_vector_ex());
    s.push_str(&emit_pitrex_j1_x());
    s.push_str(&emit_pitrex_j1_y());
    s.push_str(&emit_pitrex_j1_btn1());
    s.push_str(&emit_pitrex_j1_btn2());
    s.push_str(&emit_pitrex_j1_btn3());
    s.push_str(&emit_pitrex_j1_btn4());
    s.push_str(&emit_pitrex_print_text());
    s.push_str(&emit_pitrex_print_number());
    s.push_str(&emit_pitrex_draw_rect());
    s.push_str(&emit_pitrex_draw_filled_rect());
    s.push_str(&emit_pitrex_draw_polygon());
    s.push_str(&emit_pitrex_draw_circle());
    s.push_str(&emit_pitrex_draw_ellipse());
    s.push_str(&emit_pitrex_draw_arc());
    s.push_str(&emit_pitrex_update_buttons());
    s.push_str(&emit_pitrex_debug_print());
    s.push_str(&emit_pitrex_level_collision());
    s.push_str(&emit_pitrex_camera());
    s.push_str(&emit_pitrex_newlib_stubs());
    s.push_str(&emit_pitrex_music_helpers());
    s.push_str(&emit_pitrex_sfx_update());
    s.push_str(&emit_pitrex_math_helpers());
    s.push_str(&emit_pitrex_random());
    s.push_str(&emit_pitrex_j2());
    s.push_str(&emit_pitrex_trig());
    s.push_str(&emit_pitrex_tan_clean());
    s.push_str(&emit_pitrex_rand_fns());
    s.push_str(&emit_pitrex_system());
    s.push_str(&emit_pitrex_camera_getters());
    s.push_str(&emit_pitrex_text_extras());
    s.push_str(&emit_pitrex_msg_system());
    s.push_str(&emit_pitrex_misc_stubs());
    s.push_str(&emit_pitrex_print_number_impl());
    s.push_str(&emit_pitrex_draw_anim());

    s
}

// ── Frame sync ────────────────────────────────────────────────────────────

fn emit_pitrex_wait_recal() -> String {
    let mut s = String::new();
    s.push_str("@ pitrex_wait_recal() — frame sync via v_WaitRecal(), then fix scale=100\n");
    s.push_str(".global pitrex_wait_recal\n.type pitrex_wait_recal, %function\npitrex_wait_recal:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    bl      v_WaitRecal\n");
    // Force currentScale=100 so v_directDraw32(VPy*100) produces DAC=VPy,
    // aligning draw calls with v_printString which uses raw ±127 int8_t coords.
    s.push_str("    mov     r0, #100\n");
    s.push_str("    bl      v_setScale\n");
    s.push_str("    pop     {pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Brightness ────────────────────────────────────────────────────────────

fn emit_pitrex_set_intensity() -> String {
    let mut s = String::new();
    s.push_str("@ pitrex_set_intensity(r0=brightness 0-127)\n");
    s.push_str(".global pitrex_set_intensity\n.type pitrex_set_intensity, %function\npitrex_set_intensity:\n");
    s.push_str("    push    {lr}\n");
    // v_setBrightness expects brightness in r0
    s.push_str("    bl      v_setBrightness\n");
    s.push_str("    pop     {pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Move beam (no draw) ───────────────────────────────────────────────────

fn emit_pitrex_move() -> String {
    // pitrex_move(r0=x, r1=y) — move beam to absolute position, no draw
    // We call v_directDraw32 with brightness=0 from cur→new, update cur
    let mut s = String::new();
    s.push_str("@ pitrex_move(r0=x, r1=y) — move beam, no draw\n");
    s.push_str(".global pitrex_move\n.type pitrex_move, %function\npitrex_move:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    // r4 = new_x * 180, r5 = new_y * 180
    s.push_str("    mov     r4, #100\n");
    s.push_str("    mul     r4, r0, r4          @ r4 = new_x * 100\n");
    s.push_str("    mov     r5, #100\n");
    s.push_str("    mul     r5, r1, r5          @ r5 = new_y * 100\n");
    // load current pos
    s.push_str("    ldr     r6, =PITREX_CUR_X\n");
    s.push_str("    ldr     r0, [r6]            @ r0 = cur_x\n");
    s.push_str("    ldr     r7, =PITREX_CUR_Y\n");
    s.push_str("    ldr     r1, [r7]            @ r1 = cur_y\n");
    // call v_directDraw32(cur_x, cur_y, new_x, new_y, brightness=0)
    s.push_str("    mov     r2, r4              @ x1 = new_x\n");
    s.push_str("    mov     r3, r5              @ y1 = new_y\n");
    s.push_str("    mov     r12, #0\n");
    s.push_str("    push    {r12}               @ brightness=0 (5th arg)\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4          @ pop 5th arg\n");
    // update current position
    s.push_str("    str     r4, [r6]            @ PITREX_CUR_X = new_x\n");
    s.push_str("    str     r5, [r7]            @ PITREX_CUR_Y = new_y\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Draw line (absolute, 5-arg) ───────────────────────────────────────────

fn emit_pitrex_draw_line() -> String {
    // pitrex_draw_line(r0=x0, r1=y0, r2=x1, r3=y1, [sp+0]=brightness)
    // Scales all coordinates by 100: VPy ±100 → v_directDraw32 ±10000 (full screen).
    // This matches the call convention generated by expressions.rs for DRAW_LINE.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_line(r0=x0, r1=y0, r2=x1, r3=y1, [sp+0]=brightness)\n");
    s.push_str(".global pitrex_draw_line\n.type pitrex_draw_line, %function\npitrex_draw_line:\n");
    // push {r4, lr} = 8 bytes → brightness was at [sp+0], now at [sp+8]
    s.push_str("    push    {r4, lr}\n");
    s.push_str("    ldr     r4, [sp, #8]        @ brightness\n");
    s.push_str("    mov     r12, #100\n");
    s.push_str("    mul     r0, r0, r12         @ x0 * 100\n");
    s.push_str("    mul     r1, r1, r12         @ y0 * 100\n");
    s.push_str("    mul     r2, r2, r12         @ x1 * 100\n");
    s.push_str("    mul     r3, r3, r12         @ y1 * 100\n");
    s.push_str("    push    {r4}               @ brightness as 5th arg\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r4, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Draw line relative (3-arg, for internal vector drawing) ───────────────

fn emit_pitrex_draw_line_rel() -> String {
    // pitrex_draw_line_rel(r0=dx, r1=dy, r2=brightness)
    // Used internally by pitrex_draw_vector / pitrex_draw_vector_ex.
    // Computes new_x = cur_x + dx*100, new_y = cur_y + dy*100
    let mut s = String::new();
    s.push_str("@ pitrex_draw_line_rel(r0=dx, r1=dy, r2=brightness)\n");
    s.push_str(".global pitrex_draw_line_rel\n.type pitrex_draw_line_rel, %function\npitrex_draw_line_rel:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, #100\n");
    s.push_str("    mul     r4, r0, r4          @ r4 = dx * 100\n");
    s.push_str("    mov     r5, #100\n");
    s.push_str("    mul     r5, r1, r5          @ r5 = dy * 100\n");
    s.push_str("    mov     r6, r2              @ r6 = brightness\n");
    s.push_str("    ldr     r7, =PITREX_CUR_X\n");
    s.push_str("    ldr     r0, [r7]            @ r0 = cur_x\n");
    s.push_str("    ldr     r12, =PITREX_CUR_Y\n");
    s.push_str("    ldr     r1, [r12]           @ r1 = cur_y\n");
    s.push_str("    add     r2, r0, r4          @ r2 = new_x\n");
    s.push_str("    add     r3, r1, r5          @ r3 = new_y\n");
    s.push_str("    push    {r6}               @ brightness as 5th arg\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    ldr     r1, =PITREX_CUR_X\n");
    s.push_str("    ldr     r2, [r1]\n");
    s.push_str("    add     r2, r2, r4\n");
    s.push_str("    str     r2, [r1]            @ PITREX_CUR_X += dx*100\n");
    s.push_str("    ldr     r1, =PITREX_CUR_Y\n");
    s.push_str("    ldr     r2, [r1]\n");
    s.push_str("    add     r2, r2, r5\n");
    s.push_str("    str     r2, [r1]            @ PITREX_CUR_Y += dy*100\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Draw vector (simple, single asset, no offset/mirror) ─────────────────

fn emit_pitrex_draw_vector() -> String {
    // pitrex_draw_vector(r0 = asset_ptr, r1 = ox, r2 = oy)
    //
    // Asset layout emitted by vpy_codegen::pitrex::assets::emit_vec_resource:
    //   _NAME_VECTORS:
    //       .word  path_count
    //       .word  path0_addr, path1_addr, ...
    //   _NAME_PATHk:
    //       .byte  intensity
    //       .byte  y_start, x_start, 0x00, 0x00     @ move-to header
    //       .byte  0xFF, dy, dx                     @ N draw segments
    //       .byte  0x02                             @ end-of-path marker
    //
    // We walk the pointer table; for each path the beam is seeded at
    // (ox*100, oy*100) so the relative move-to + segments compose to absolute
    // screen coords centred on (ox, oy). Default brightness 127.
    //
    // Register usage (callee-save):
    //   r4 = asset cursor (header / pointer table)
    //   r5 = path_count
    //   r6 = ox*100  (precomputed)
    //   r7 = oy*100  (precomputed)
    //   r8 = path index
    //   r9 = path data cursor (per-path)
    let mut s = String::new();
    s.push_str("@ pitrex_draw_vector(r0=asset_ptr, r1=ox, r2=oy)\n");
    s.push_str(".global pitrex_draw_vector\n.type pitrex_draw_vector, %function\npitrex_draw_vector:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n");
    s.push_str("    mov     r4, r0              @ asset header ptr\n");
    s.push_str("    mov     r3, #100\n");
    s.push_str("    mul     r6, r1, r3          @ ox*100\n");
    s.push_str("    mul     r7, r2, r3          @ oy*100\n");
    s.push_str("    ldr     r5, [r4], #4        @ path_count\n");
    s.push_str("    mov     r8, #0\n");
    s.push_str("dv_path_loop:\n");
    s.push_str("    cmp     r8, r5\n");
    s.push_str("    bge     dv_done\n");
    s.push_str("    ldr     r9, [r4], #4        @ r9 = path data ptr\n");
    // Seed beam at offset for each path.
    s.push_str("    ldr     r0, =PITREX_CUR_X\n    str     r6, [r0]\n");
    s.push_str("    ldr     r0, =PITREX_CUR_Y\n    str     r7, [r0]\n");
    s.push_str("    add     r9, r9, #1          @ skip intensity byte\n");
    s.push_str("    ldrsb   r1, [r9], #1        @ dy = y_start\n");
    s.push_str("    ldrsb   r0, [r9], #1        @ dx = x_start\n");
    s.push_str("    add     r9, r9, #2          @ skip 2 hdr padding bytes\n");
    s.push_str("    mov     r2, #0              @ brightness 0 = move only\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9}\n");
    s.push_str("    bl      pitrex_draw_line_rel\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9}\n");
    s.push_str("dv_seg_loop:\n");
    s.push_str("    ldrb    r0, [r9], #1        @ marker (0xFF=draw, 0x02=end)\n");
    s.push_str("    cmp     r0, #2\n");
    s.push_str("    beq     dv_seg_done\n");
    s.push_str("    ldrsb   r1, [r9], #1        @ dy\n");
    s.push_str("    ldrsb   r0, [r9], #1        @ dx\n");
    s.push_str("    mov     r2, #127            @ full brightness\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9}\n");
    s.push_str("    bl      pitrex_draw_line_rel\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9}\n");
    s.push_str("    b       dv_seg_loop\n");
    s.push_str("dv_seg_done:\n");
    s.push_str("    add     r8, r8, #1\n");
    s.push_str("    b       dv_path_loop\n");
    s.push_str("dv_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Draw vector EX (offset + mirror + intensity) ──────────────────────────

fn emit_pitrex_draw_vector_ex() -> String {
    // pitrex_draw_vector_ex(r0=asset_ptr, r1=ox, r2=oy, r3=mirror, [sp]=intensity)
    //
    // Same asset layout as pitrex_draw_vector (path-pointer table → byte
    // stream paths terminated with 0x02). Differences from the simple
    // version:
    //   * The beam is reset to (ox*100, oy*100) at the start of each path
    //     so the relative move-to + segments end up centred on (ox, oy).
    //   * If `mirror` (r7) == 1, all dx values are negated.
    //   * Intensity comes from the stack instead of being hard-coded to 127.
    //
    // After `push {r4..r9, lr}` (28 bytes), the caller's [sp+0]=intensity
    // is at [sp+28]. We then push 8 more bytes (path_count, path_idx) so
    // throughout the loop intensity stays in r8 (preserved).
    //
    // Register usage (callee-save):
    //   r4 = asset header cursor, then per-path data cursor
    //   r5 = ox
    //   r6 = oy
    //   r7 = mirror flag
    //   r8 = intensity
    //   r9 = scratch
    let mut s = String::new();
    s.push_str("@ pitrex_draw_vector_ex(r0=asset_ptr, r1=ox, r2=oy, r3=mirror, [sp]=intensity)\n");
    s.push_str(".global pitrex_draw_vector_ex\n.type pitrex_draw_vector_ex, %function\npitrex_draw_vector_ex:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}    @ 28 bytes\n");
    s.push_str("    mov     r4, r0              @ asset header ptr\n");
    s.push_str("    mov     r5, r1              @ ox\n");
    s.push_str("    mov     r6, r2              @ oy\n");
    s.push_str("    mov     r7, r3              @ mirror flag\n");
    s.push_str("    ldr     r8, [sp, #28]       @ intensity (5th arg)\n");
    s.push_str("    ldr     r9, [r4], #4        @ path_count\n");
    s.push_str("    push    {r9}                @ [sp+0] = path_count\n");
    s.push_str("    mov     r9, #0\n");
    s.push_str("    push    {r9}                @ [sp+0] = path_idx, [sp+4] = path_count\n");
    s.push_str("dvex_path_loop:\n");
    s.push_str("    ldr     r0, [sp]            @ path_idx\n");
    s.push_str("    ldr     r1, [sp, #4]        @ path_count\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bge     dvex_done\n");
    s.push_str("    ldr     r9, [r4], #4        @ r9 = path data ptr\n");
    // Seed beam at (ox*100, oy*100) so the path-relative move-to and
    // segments compose to absolute screen coordinates centred on (ox, oy).
    s.push_str("    mov     r0, #100\n");
    s.push_str("    mul     r1, r5, r0          @ ox*100\n");
    s.push_str("    ldr     r2, =PITREX_CUR_X\n    str     r1, [r2]\n");
    s.push_str("    mul     r1, r6, r0          @ oy*100\n");
    s.push_str("    ldr     r2, =PITREX_CUR_Y\n    str     r1, [r2]\n");
    s.push_str("    add     r9, r9, #1          @ skip intensity byte\n");
    s.push_str("    ldrsb   r1, [r9], #1        @ dy = y_start\n");
    s.push_str("    ldrsb   r0, [r9], #1        @ dx = x_start\n");
    s.push_str("    add     r9, r9, #2          @ skip 2 hdr padding bytes\n");
    s.push_str("    cmp     r7, #1\n    it      eq\n    rsbeq   r0, r0, #0          @ mirror dx\n");
    s.push_str("    mov     r2, #0              @ move only\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9}\n");
    s.push_str("    bl      pitrex_draw_line_rel\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9}\n");
    s.push_str("dvex_seg_loop:\n");
    s.push_str("    ldrb    r0, [r9], #1\n");
    s.push_str("    cmp     r0, #2\n");
    s.push_str("    beq     dvex_seg_done\n");
    s.push_str("    ldrsb   r1, [r9], #1        @ dy\n");
    s.push_str("    ldrsb   r0, [r9], #1        @ dx\n");
    s.push_str("    cmp     r7, #1\n    it      eq\n    rsbeq   r0, r0, #0\n");
    s.push_str("    mov     r2, r8              @ intensity\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9}\n");
    s.push_str("    bl      pitrex_draw_line_rel\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9}\n");
    s.push_str("    b       dvex_seg_loop\n");
    s.push_str("dvex_seg_done:\n");
    s.push_str("    ldr     r0, [sp]\n");
    s.push_str("    add     r0, r0, #1\n");
    s.push_str("    str     r0, [sp]            @ path_idx++\n");
    s.push_str("    b       dvex_path_loop\n");
    s.push_str("dvex_done:\n");
    s.push_str("    add     sp, sp, #8          @ pop path_idx + path_count\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Joystick / Buttons ────────────────────────────────────────────────────

fn emit_pitrex_j1_x() -> String {
    // currentJoy1X is int8_t (1 byte, ±127). Use ldrsb for correct signed byte read.
    let mut s = String::new();
    s.push_str("@ pitrex_j1_x() → r0 = X axis (-127..127)\n");
    s.push_str(".global pitrex_j1_x\n.type pitrex_j1_x, %function\npitrex_j1_x:\n");
    s.push_str("    ldr     r1, =currentJoy1X\n");
    s.push_str("    ldrsb   r0, [r1]\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    s
}

fn emit_pitrex_j1_y() -> String {
    // currentJoy1Y is int8_t (1 byte, ±127). Use ldrsb for correct signed byte read.
    let mut s = String::new();
    s.push_str("@ pitrex_j1_y() → r0 = Y axis (-127..127)\n");
    s.push_str(".global pitrex_j1_y\n.type pitrex_j1_y, %function\npitrex_j1_y:\n");
    s.push_str("    ldr     r1, =currentJoy1Y\n");
    s.push_str("    ldrsb   r0, [r1]\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    s
}

fn emit_pitrex_j1_btn(name: &str, bit: u32) -> String {
    // currentButtonState bits: 0=btn1, 1=btn2, 2=btn3, 3=btn4
    let mut s = String::new();
    s.push_str(&format!("@ {name}() → r0=1 if pressed, 0 otherwise (bit {bit})\n"));
    s.push_str(&format!(".global {name}\n.type {name}, %function\n{name}:\n"));
    s.push_str("    ldr     r1, =currentButtonState\n");
    s.push_str("    ldr     r0, [r1]\n");
    s.push_str(&format!("    lsr     r0, r0, #{bit}\n"));
    s.push_str("    and     r0, r0, #1\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    s
}

fn emit_pitrex_j1_btn1() -> String { emit_pitrex_j1_btn("pitrex_j1_btn1", 0) }
fn emit_pitrex_j1_btn2() -> String { emit_pitrex_j1_btn("pitrex_j1_btn2", 1) }
fn emit_pitrex_j1_btn3() -> String { emit_pitrex_j1_btn("pitrex_j1_btn3", 2) }
fn emit_pitrex_j1_btn4() -> String { emit_pitrex_j1_btn("pitrex_j1_btn4", 3) }

// ── Text output ───────────────────────────────────────────────────────────

fn emit_pitrex_print_text() -> String {
    // pitrex_print_text(r0=x, r1=y, r2=str_ptr)
    // Calls v_printString(x, y, str, textSize, brightness) — SDK vector font.
    //
    // v_printString uses INTEGRATOR-RELATIVE coordinates (like M6809 BIOS Print_Str_d).
    // Without an explicit reset, text position depends on wherever the beam ended after
    // the previous draw call → cumulative drift across multiple PRINT_TEXT calls.
    // We call v_directMove32(0, 0) before v_printString to make positioning absolute.
    let mut s = String::new();
    s.push_str("@ pitrex_print_text(r0=x, r1=y, r2=str_ptr)\n");
    s.push_str(".global pitrex_print_text\n.type pitrex_print_text, %function\npitrex_print_text:\n");
    s.push_str("    push    {r4, r5, r6, lr}\n");
    // Save VPy_x, VPy_y, str_ptr across the v_directMove32 call
    s.push_str("    mov     r4, r0\n");
    s.push_str("    mov     r5, r1\n");
    s.push_str("    mov     r6, r2\n");
    // Reset beam to (0,0) so v_printString's int8_t coords are absolute, not relative.
    s.push_str("    mov     r0, #0\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    bl      v_directMove32\n");
    // Restore args
    s.push_str("    mov     r0, r4              @ VPy_x\n");
    s.push_str("    mov     r1, r5              @ VPy_y\n");
    s.push_str("    mov     r2, r6              @ str_ptr\n");
    // textSize from PITREX_TEXT_SIZE, default=5
    s.push_str("    ldr     r3, =PITREX_TEXT_SIZE\n");
    s.push_str("    ldr     r3, [r3]\n");
    s.push_str("    cmp     r3, #0\n    it eq\n    moveq   r3, #5\n");
    // y convention: VPy y = top of text. v_printString y = baseline. Subtract cap_height
    // FIRST (in VPy space), then apply the coordinate rescale below.
    s.push_str("    sub     r1, r1, #8          @ baseline = top - cap_height (VPy units)\n");
    // Coordinate rescale: DRAW_LINE/DRAW_RECT call v_directDraw32 with VPy*100 coordinates.
    // v_printString internally does startX = x * 128. To align both systems we pre-scale
    // the VPy coords by 100/128 = 25/32, so: x_passed * 128 = VPy * 25/32 * 128 = VPy * 100.
    //   x * 25/32  =  (x*16 + x*8 + x) >> 5  =  x*25 >> 5
    s.push_str("    lsl     r12, r0, #4         @ r12 = x*16\n");
    s.push_str("    add     r12, r12, r0, lsl #3 @ r12 = x*24\n");
    s.push_str("    add     r0, r12, r0          @ r0  = x*25\n");
    s.push_str("    asr     r0, r0, #5           @ r0  = x*25/32 (sign-preserving)\n");
    s.push_str("    lsl     r12, r1, #4         @ r12 = y*16\n");
    s.push_str("    add     r12, r12, r1, lsl #3 @ r12 = y*24\n");
    s.push_str("    add     r1, r12, r1          @ r1  = y*25\n");
    s.push_str("    asr     r1, r1, #5           @ r1  = y*25/32 (sign-preserving)\n");
    // brightness as 5th arg on stack
    s.push_str("    mov     r12, #0x50\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_printString\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r4, r5, r6, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

fn emit_pitrex_print_number() -> String {
    // Forward declaration only — the real implementation is emit_pitrex_print_number_impl()
    // emitted later (after PITREX_TEXT_SIZE and other deps are defined).
    // This stub is intentionally empty; the real .global is in the impl function.
    String::new()
}

// ── Draw rect / circle / update_buttons ──────────────────────────────────

fn emit_pitrex_draw_rect() -> String {
    // pitrex_draw_rect(r0=x, r1=y, r2=w, r3=h)  — 5th arg (brightness) on stack
    // Convention (matches M6809/rp2350): (x, y) is the BOTTOM-LEFT corner;
    // the rect extends UP by `h` and RIGHT by `w` so it spans
    // x..x+w on the X axis and y..y+h on the Y axis (Vectrex y = up).
    let mut s = String::new();
    s.push_str("@ pitrex_draw_rect(r0=x, r1=y, r2=w, r3=h) 5th=[sp]=brightness\n");
    s.push_str(".global pitrex_draw_rect\n.type pitrex_draw_rect, %function\npitrex_draw_rect:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    // Save x,y,w,h and load brightness from stack above saved regs (5*4=20 bytes pushed)
    s.push_str("    mov     r4, r0          @ x (left)\n");
    s.push_str("    mov     r5, r1          @ y (bottom)\n");
    s.push_str("    mov     r6, r2          @ w\n");
    s.push_str("    mov     r7, r3          @ h\n");
    // Scale by 100 (VPy → pitrex)
    s.push_str("    mov     r0, #100\n");
    s.push_str("    mul     r4, r4, r0\n");
    s.push_str("    mul     r5, r5, r0\n");
    s.push_str("    mul     r6, r6, r0\n");
    s.push_str("    mul     r7, r7, r0\n");
    // Bottom edge: (x, y) -> (x+w, y)
    s.push_str("    mov     r0, r4\n");
    s.push_str("    mov     r1, r5\n");
    s.push_str("    add     r2, r4, r6\n");
    s.push_str("    mov     r3, r5\n");
    s.push_str("    ldr     r12, [sp, #20]\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    // Right edge: (x+w, y) -> (x+w, y+h)
    s.push_str("    add     r0, r4, r6\n");
    s.push_str("    mov     r1, r5\n");
    s.push_str("    add     r2, r4, r6\n");
    s.push_str("    add     r3, r5, r7\n");
    s.push_str("    ldr     r12, [sp, #20]\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    // Top edge: (x+w, y+h) -> (x, y+h)
    s.push_str("    add     r0, r4, r6\n");
    s.push_str("    add     r1, r5, r7\n");
    s.push_str("    mov     r2, r4\n");
    s.push_str("    add     r3, r5, r7\n");
    s.push_str("    ldr     r12, [sp, #20]\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    // Left edge: (x, y+h) -> (x, y)
    s.push_str("    mov     r0, r4\n");
    s.push_str("    add     r1, r5, r7\n");
    s.push_str("    mov     r2, r4\n");
    s.push_str("    mov     r3, r5\n");
    s.push_str("    ldr     r12, [sp, #20]\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n\n");
    s
}

fn emit_pitrex_draw_circle() -> String {
    // pitrex_draw_circle(r0=cx, r1=cy, r2=diameter, r3=brightness)
    // The 3rd argument is the *diameter* (matches M6809/rp2350); we halve it
    // before scaling by 100 so the unit-circle constants (×1024) produce the
    // correct radius after the >>10. 16-segment approximation (22.5° each).
    let mut s = String::new();
    s.push_str("@ pitrex_draw_circle(r0=cx, r1=cy, r2=diameter, r3=brightness)\n");
    s.push_str(".global pitrex_draw_circle\n.type pitrex_draw_circle, %function\npitrex_draw_circle:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, r0          @ cx\n");
    s.push_str("    mov     r5, r1          @ cy\n");
    s.push_str("    asr     r6, r2, #1      @ radius = diameter/2\n");
    s.push_str("    mov     r7, r3          @ brightness\n");
    s.push_str("    mov     r0, #100\n");
    s.push_str("    mul     r4, r4, r0\n");
    s.push_str("    mul     r5, r5, r0\n");
    s.push_str("    mul     r6, r6, r0\n");

    // Helper: emit load of abs(val) into reg, then negate if val<0, then *r6>>10 + base
    fn arm_coord(s: &mut String, reg: &str, val: i32, base: &str) {
        let a = val.unsigned_abs();
        if a == 0 {
            s.push_str(&format!("    mov     {reg}, #0\n"));
        } else if a <= 255 {
            s.push_str(&format!("    mov     {reg}, #{a}\n"));
        } else {
            s.push_str(&format!("    ldr     {reg}, ={a}\n"));
        }
        if val < 0 { s.push_str(&format!("    neg     {reg}, {reg}\n")); }
        s.push_str(&format!("    mul     {reg}, {reg}, r6\n"));
        s.push_str(&format!("    asr     {reg}, {reg}, #10\n"));
        s.push_str(&format!("    add     {reg}, {reg}, {base}\n"));
    }

    // 16-segment unit-circle table × 1024 — vertex k = (cos(k*22.5°), sin(k*22.5°)).
    let pts: [(i32,i32); 17] = [
        (1024, 0),
        (946, 392),
        (724, 724),
        (392, 946),
        (0, 1024),
        (-392, 946),
        (-724, 724),
        (-946, 392),
        (-1024, 0),
        (-946, -392),
        (-724, -724),
        (-392, -946),
        (0, -1024),
        (392, -946),
        (724, -724),
        (946, -392),
        (1024, 0),
    ];
    for i in 0..16 {
        let (x0s, y0s) = pts[i];
        let (x1s, y1s) = pts[i + 1];
        arm_coord(&mut s, "r0", x0s, "r4");
        arm_coord(&mut s, "r1", y0s, "r5");
        arm_coord(&mut s, "r2", x1s, "r4");
        arm_coord(&mut s, "r3", y1s, "r5");
        s.push_str("    push    {r7}\n");
        s.push_str("    bl      v_directDraw32\n");
        s.push_str("    add     sp, sp, #4\n");
    }
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Filled rect ──────────────────────────────────────────────────────────

fn emit_pitrex_draw_filled_rect() -> String {
    // pitrex_draw_filled_rect(r0=x, r1=y, r2=w, r3=h, [sp+0]=brightness)
    // (x, y) is the BOTTOM-LEFT corner — rect spans y..y+h going UP, matching
    // the M6809/rp2350 convention.  Outline is delegated to pitrex_draw_rect;
    // fill is a stack of horizontal scan lines walking UP from y+step to y+h-step.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_filled_rect(r0=x, r1=y, r2=w, r3=h, [sp+0]=brightness)\n");
    s.push_str(".global pitrex_draw_filled_rect\n.type pitrex_draw_filled_rect, %function\npitrex_draw_filled_rect:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n");
    // save args
    s.push_str("    mov     r4, r0          @ x (left)\n");
    s.push_str("    mov     r5, r1          @ y (bottom)\n");
    s.push_str("    mov     r6, r2          @ w\n");
    s.push_str("    mov     r7, r3          @ h\n");
    s.push_str("    ldr     r8, [sp, #28]   @ brightness ([sp+7regs*4])\n");
    // draw outline: delegate to pitrex_draw_rect (same signature)
    s.push_str("    push    {r8}            @ brightness as 5th arg\n");
    s.push_str("    bl      pitrex_draw_rect\n");
    s.push_str("    add     sp, sp, #4\n");
    // scale coords by 100
    s.push_str("    mov     r9, #100\n");
    s.push_str("    mul     r4, r4, r9      @ x_s\n");
    s.push_str("    mul     r5, r5, r9      @ y_s (bottom)\n");
    s.push_str("    mul     r6, r6, r9      @ w_s\n");
    s.push_str("    mul     r7, r7, r9      @ h_s\n");
    // scan step = 3 VPy units (× 100)
    s.push_str("    mov     r9, #300        @ scan step (3 * 100)\n");
    // r0 = scan_y starts at y_s + step, going UP to y_s + h_s - step
    s.push_str("    add     r0, r5, r9      @ scan_y = y + step\n");
    s.push_str(".Lfill_loop:\n");
    s.push_str("    add     r1, r5, r7      @ top = y_s + h_s\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bge     .Lfill_done     @ exit when scan_y >= top\n");
    // draw horizontal line at scan_y: from (x_s, scan_y) to (x_s+w_s, scan_y).
    // ARM PUSH stores lowest-numbered register at lowest stack address, so we
    // must push scan_y FIRST and brightness SECOND to get [sp+0]=brightness
    // for v_directDraw32 (its 5th arg).
    s.push_str("    mov     r1, r0          @ y0 = scan_y\n");
    s.push_str("    add     r2, r4, r6      @ x1 = x_s + w_s\n");
    s.push_str("    mov     r3, r0          @ y1 = scan_y\n");
    s.push_str("    push    {r0}            @ save scan_y for after the call\n");
    s.push_str("    mov     r0, r4          @ x0 = x_s\n");
    s.push_str("    push    {r8}            @ brightness as 5th arg ([sp+0])\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4      @ pop brightness\n");
    s.push_str("    pop     {r0}            @ restore scan_y\n");
    s.push_str("    add     r0, r0, r9      @ scan_y += step\n");
    s.push_str("    b       .Lfill_loop\n");
    s.push_str(".Lfill_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Polygon ───────────────────────────────────────────────────────────────

fn emit_pitrex_draw_polygon() -> String {
    // pitrex_draw_polygon(r0=n, r1=intensity, r2=x0, r3=y0,
    //                    [sp+0]=x1, [sp+4]=y1, [sp+8]=x2, [sp+12]=y2, ...)
    // Connects n vertices in order and closes back to v0.
    // Form B (intensity-as-2nd-arg) — matches the user-facing signature
    // DRAW_POLYGON(n, intensity, x0, y0, x1, y1, ...). The codegen normalises
    // Form A (no intensity) into Form B before the call.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_polygon(r0=n, r1=intensity, r2=x0, r3=y0, stack=x1,y1,x2,y2,...)\n");
    s.push_str(".global pitrex_draw_polygon\n.type pitrex_draw_polygon, %function\npitrex_draw_polygon:\n");
    // save original sp before push (for reading stack args)
    s.push_str("    mov     r12, sp\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    // r4=n, r5=scale, r6=brightness, r7=x0_s, r8=y0_s, r9=cur_x_s, r10=cur_y_s, r11=loop counter
    s.push_str("    mov     r4, r0          @ n\n");
    s.push_str("    mov     r5, #100        @ scale\n");
    s.push_str("    mov     r6, r1          @ brightness\n");
    // scale v0 (x0=r2, y0=r3)
    s.push_str("    mul     r7, r2, r5      @ x0_s\n");
    s.push_str("    mul     r8, r3, r5      @ y0_s\n");
    // scale v1 — x1 at [r12+0], y1 at [r12+4]
    s.push_str("    ldr     r0, [r12, #0]   @ x1 raw\n");
    s.push_str("    mul     r9, r0, r5      @ x1_s\n");
    s.push_str("    ldr     r0, [r12, #4]   @ y1 raw\n");
    s.push_str("    mul     r10, r0, r5     @ y1_s\n");
    // draw edge 0→1: v_directDraw32(x0_s, y0_s, x1_s, y1_s, brightness)
    s.push_str("    push    {r9, r10}       @ save v1 endpoint (cur_x, cur_y)\n");
    s.push_str("    mov     r0, r7\n    mov     r1, r8\n");
    s.push_str("    mov     r2, r9\n    mov     r3, r10\n");
    s.push_str("    push    {r6}            @ brightness ([sp+0])\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r9, r10}       @ r9=cur_x=x1_s, r10=cur_y=y1_s\n");
    // loop k=2..n-1: vk on stack at [caller_sp+(2k-2)*4]=xk, [caller_sp+(2k-1)*4]=yk
    // r12 (IP) is a caller-saved register: v_directDraw32 may clobber it on each call.
    // Use sp-relative addressing instead: caller_sp = sp + 36 (9 callee-save regs × 4).
    // At the top of each loop iteration sp = entry_sp - 36 (no extra pushes outstanding).
    s.push_str("    mov     r11, #2\n");
    s.push_str(".Lpoly_loop:\n");
    s.push_str("    cmp     r11, r4\n");
    s.push_str("    bge     .Lpoly_close\n");
    // xk offset = (2k-2)*4;  full sp offset = 36 + (2k-2)*4
    s.push_str("    mov     r0, r11, lsl #1 @ 2k\n");
    s.push_str("    sub     r0, r0, #2      @ 2k-2\n");
    s.push_str("    lsl     r0, r0, #2      @ (2k-2)*4\n");
    s.push_str("    add     r0, r0, #36     @ + callee-save frame (9*4)\n");
    s.push_str("    ldr     r2, [sp, r0]    @ xk raw (sp-relative, avoids clobbered r12)\n");
    s.push_str("    mul     r0, r2, r5      @ xk_s → r0  (Rd=r0 != Rm=r2)\n");
    // yk offset = (2k-1)*4;  full sp offset = 36 + (2k-1)*4
    s.push_str("    mov     r1, r11, lsl #1 @ 2k\n");
    s.push_str("    sub     r1, r1, #1      @ 2k-1\n");
    s.push_str("    lsl     r1, r1, #2      @ (2k-1)*4\n");
    s.push_str("    add     r1, r1, #36     @ + callee-save frame\n");
    s.push_str("    ldr     r2, [sp, r1]    @ yk raw (sp-relative)\n");
    s.push_str("    mul     r1, r2, r5      @ yk_s → r1  (Rd=r1 != Rm=r2)\n");
    // save new endpoint, then draw cur→new
    s.push_str("    push    {r0, r1}        @ save new xk_s, yk_s\n");
    s.push_str("    mov     r2, r0\n    mov     r3, r1\n");
    s.push_str("    mov     r0, r9\n    mov     r1, r10\n");
    s.push_str("    push    {r6}            @ brightness\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r9, r10}       @ r9=xk_s, r10=yk_s\n");
    s.push_str("    add     r11, r11, #1\n");
    s.push_str("    b       .Lpoly_loop\n");
    // close polygon: draw last→v0
    s.push_str(".Lpoly_close:\n");
    s.push_str("    mov     r0, r9\n    mov     r1, r10\n");
    s.push_str("    mov     r2, r7\n    mov     r3, r8\n");
    s.push_str("    push    {r6}            @ brightness\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Ellipse ───────────────────────────────────────────────────────────────

fn emit_pitrex_draw_ellipse() -> String {
    // pitrex_draw_ellipse(r0=cx, r1=cy, r2=rx, r3=ry, [sp+0]=brightness)
    // 16-segment approximation (matches M6809/rp2350 ellipse resolution).
    let mut s = String::new();
    s.push_str("@ pitrex_draw_ellipse(r0=cx, r1=cy, r2=rx, r3=ry, [sp+0]=brightness)\n");
    s.push_str(".global pitrex_draw_ellipse\n.type pitrex_draw_ellipse, %function\npitrex_draw_ellipse:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n");
    s.push_str("    mov     r4, r0          @ cx\n");
    s.push_str("    mov     r5, r1          @ cy\n");
    s.push_str("    mov     r6, r2          @ rx\n");
    s.push_str("    mov     r7, r3          @ ry\n");
    s.push_str("    ldr     r8, [sp, #28]   @ brightness\n");
    s.push_str("    mov     r9, #100\n");
    s.push_str("    mul     r4, r4, r9\n");
    s.push_str("    mul     r5, r5, r9\n");
    s.push_str("    mul     r6, r6, r9\n");
    s.push_str("    mul     r7, r7, r9\n");
    // 16-segment unit-circle table * 1024 — vertex k = (cos(k*22.5°), sin(k*22.5°)).
    // Each tuple is (x_start, y_start, x_end, y_end) for one chord.
    let pts: [(i32,i32); 17] = [
        (1024, 0),
        (946, 392),
        (724, 724),
        (392, 946),
        (0, 1024),
        (-392, 946),
        (-724, 724),
        (-946, 392),
        (-1024, 0),
        (-946, -392),
        (-724, -724),
        (-392, -946),
        (0, -1024),
        (392, -946),
        (724, -724),
        (946, -392),
        (1024, 0),
    ];
    for i in 0..16 {
        let (xs0, ys0) = pts[i];
        let (xs1, ys1) = pts[i + 1];
        // x coords use rx (r6), y coords use ry (r7); use ldr for values > 255.
        let emit_coord = |s: &mut String, reg: &str, scale_reg: &str, val: i32, base: &str| {
            let abs = val.unsigned_abs();
            if abs <= 255 {
                s.push_str(&format!("    mov     {reg}, #{abs}\n"));
            } else {
                s.push_str(&format!("    ldr     {reg}, ={abs}\n"));
            }
            if val < 0 { s.push_str(&format!("    neg     {reg}, {reg}\n")); }
            s.push_str(&format!("    mul     {reg}, {reg}, {scale_reg}\n"));
            s.push_str(&format!("    asr     {reg}, {reg}, #10\n"));
            s.push_str(&format!("    add     {reg}, {reg}, {base}\n"));
        };
        emit_coord(&mut s, "r0", "r6", xs0, "r4");
        emit_coord(&mut s, "r1", "r7", ys0, "r5");
        emit_coord(&mut s, "r2", "r6", xs1, "r4");
        emit_coord(&mut s, "r3", "r7", ys1, "r5");
        s.push_str("    push    {r8}\n");
        s.push_str("    bl      v_directDraw32\n");
        s.push_str("    add     sp, sp, #4\n");
    }
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Arc ───────────────────────────────────────────────────────────────────

fn emit_pitrex_draw_arc() -> String {
    // pitrex_draw_arc(r0=segs, r1=cx, r2=cy, r3=r, [sp+0]=start_deg, [sp+4]=sweep_deg, [sp+8]=brightness)
    // Approximates the arc using up to 8 precomputed circle points.
    // Only draws segments whose midpoint angle falls within [start, start+sweep].
    // For simplicity, angles are snapped to the 8-segment 45° grid.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_arc(r0=segs, r1=cx, r2=cy, r3=r, [sp]=start,[sp+4]=sweep,[sp+8]=bright)\n");
    s.push_str(".global pitrex_draw_arc\n.type pitrex_draw_arc, %function\npitrex_draw_arc:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}\n");
    s.push_str("    mov     r4, r1          @ cx\n");
    s.push_str("    mov     r5, r2          @ cy\n");
    s.push_str("    mov     r6, r3          @ radius\n");
    s.push_str("    ldr     r7, [sp, #24]   @ start_deg\n");
    s.push_str("    ldr     r8, [sp, #28]   @ sweep_deg\n");
    // scale by 192
    s.push_str("    mov     r0, #100\n");
    s.push_str("    mul     r4, r4, r0\n");
    s.push_str("    mul     r5, r5, r0\n");
    s.push_str("    mul     r6, r6, r0\n");
    // brightness
    s.push_str("    ldr     r3, [sp, #32]   @ brightness\n");
    // For each of the 16 segments (22.5° each), check if its start angle is within [start, start+sweep].
    // Segment i covers angle i*22.5..(i+1)*22.5. We check if floor(i*22.5) >= start and floor(i*22.5) < start+sweep.
    // Use integer angles so the cmp uses integer math: 0,22,45,67,90,112,135,157,180,202,225,247,270,292,315,337.
    let segs: [(i32,i32,i32,i32,i32); 16] = [
        (1024, 0,     946, 392,    0),    // 0°
        (946, 392,    724, 724,   22),    // 22.5°
        (724, 724,    392, 946,   45),    // 45°
        (392, 946,    0, 1024,    67),    // 67.5°
        (0, 1024,     -392, 946,  90),    // 90°
        (-392, 946,   -724, 724, 112),    // 112.5°
        (-724, 724,   -946, 392, 135),    // 135°
        (-946, 392,   -1024, 0,  157),    // 157.5°
        (-1024, 0,    -946, -392, 180),   // 180°
        (-946, -392,  -724, -724, 202),   // 202.5°
        (-724, -724,  -392, -946, 225),   // 225°
        (-392, -946,  0, -1024,  247),    // 247.5°
        (0, -1024,    392, -946, 270),    // 270°
        (392, -946,   724, -724, 292),    // 292.5°
        (724, -724,   946, -392, 315),    // 315°
        (946, -392,   1024, 0,   337),    // 337.5°
    ];
    for (i, (xs0,ys0,xs1,ys1,start_angle)) in segs.iter().enumerate() {
        let label = format!(".Larc_skip{i}");
        // Check: seg_start >= r7 (start_deg) AND seg_start < r7+r8 (start+sweep)
        s.push_str(&format!("    @ segment {}° \n", start_angle));
        let load_angle = if *start_angle > 255 {
            format!("    ldr     r0, ={start_angle}\n")
        } else {
            format!("    mov     r0, #{start_angle}\n")
        };
        s.push_str(&load_angle);
        s.push_str(&format!("    cmp     r0, r7\n    blt     {label}\n"));
        s.push_str(&format!("    add     r1, r7, r8\n    cmp     r0, r1\n    bge     {label}\n"));
        // emit segment
        let emit_c = |s: &mut String, reg: &str, val: i32, base: &str| {
            let abs = val.unsigned_abs();
            if abs <= 255 {
                s.push_str(&format!("    mov     {reg}, #{abs}\n"));
            } else {
                s.push_str(&format!("    ldr     {reg}, ={abs}\n"));
            }
            if val < 0 { s.push_str(&format!("    neg     {reg}, {reg}\n")); }
            s.push_str(&format!("    mul     {reg}, {reg}, r6\n"));
            s.push_str(&format!("    asr     {reg}, {reg}, #10\n"));
            s.push_str(&format!("    add     {reg}, {reg}, {base}\n"));
        };
        emit_c(&mut s, "r0", *xs0, "r4");
        emit_c(&mut s, "r1", *ys0, "r5");
        emit_c(&mut s, "r2", *xs1, "r4");
        emit_c(&mut s, "r9", *ys1, "r5");  // avoid clobbering r3=brightness early
        s.push_str("    push    {r3, r9}    @ brightness, y1\n");
        s.push_str("    mov     r3, r9\n");
        s.push_str("    ldr     r9, [sp, #0]\n"); // r9=brightness
        s.push_str("    push    {r9}\n");
        s.push_str("    bl      v_directDraw32\n");
        s.push_str("    add     sp, sp, #4\n");
        s.push_str("    pop     {r3, r9}\n");
        s.push_str(&format!("{label}:\n"));
    }
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

fn emit_pitrex_update_buttons() -> String {
    // pitrex_update_buttons() — reads joystick and buttons into SDK globals
    let mut s = String::new();
    s.push_str("@ pitrex_update_buttons()\n");
    s.push_str(".global pitrex_update_buttons\n.type pitrex_update_buttons, %function\npitrex_update_buttons:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    bl      v_readButtons\n");
    s.push_str("    bl      v_readJoystick1Analog\n");
    s.push_str("    pop     {pc}\n\n");
    s
}

fn emit_pitrex_debug_print() -> String {
    let mut s = String::new();
    // pitrex_debug_print(r0=value) — delegates to pitrex_print_number
    s.push_str("@ pitrex_debug_print(r0=value)\n");
    s.push_str(".global pitrex_debug_print\n.type pitrex_debug_print, %function\npitrex_debug_print:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    bl      pitrex_print_number\n");
    s.push_str("    pop     {pc}\n\n");
    s.push_str("@ pitrex_debug_print_labeled(r0=label_ptr, r1=value)\n");
    s.push_str(".global pitrex_debug_print_labeled\n.type pitrex_debug_print_labeled, %function\npitrex_debug_print_labeled:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    mov     r0, r1\n");
    s.push_str("    bl      pitrex_print_number\n");
    s.push_str("    pop     {pc}\n\n");
    s.push_str("@ pitrex_debug_print_str(r0=str_ptr)\n");
    s.push_str(".global pitrex_debug_print_str\n.type pitrex_debug_print_str, %function\npitrex_debug_print_str:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    mov     r1, r0\n");
    s.push_str("    ldr     r0, =-100\n");
    s.push_str("    mov     r2, #100\n");
    s.push_str("    mov     r3, #1\n");
    s.push_str("    mov     r12, #127\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_printStringRaster\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {pc}\n\n");
    s
}

fn emit_pitrex_level_collision() -> String {
    let mut s = String::new();

    // ── pitrex_level_collision_y(r0=px, r1=py, r2=hh) → r0 = floor_center_y ──
    // Scans collidable GP objects (ROM flags bit4 = 0x10).
    // Returns best_obj_top + player_hh (where player center should sit).
    // Returns -200 if no floor found (caller uses max(result, game_floor)).
    //
    // LEVEL_GP_BUF layout (8 bytes/entry): x i16 @0, y i16 @2, vx i16 @4, vy i16 @6
    // ROM object layout (16 bytes): x @0, y @2, scale @4, intensity @5, flags @6,
    //   type @7, vector_ptr @8, half_w @12, half_h @13, vel_x @14, vel_y @15
    s.push_str("@ pitrex_level_collision_y(r0=px, r1=py, r2=hh) -> floor_center_y\n");
    s.push_str(".global pitrex_level_collision_y\n.type pitrex_level_collision_y, %function\npitrex_level_collision_y:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}\n");
    s.push_str("    mov     r4, r0              @ px\n");
    s.push_str("    mov     r5, r1              @ py\n");
    s.push_str("    mov     r6, r2              @ half_h (player)\n");
    s.push_str("    ldr     r7, =LEVEL_DATA_PTR\n");
    s.push_str("    ldr     r7, [r7]            @ r7 = level header ptr\n");
    s.push_str("    ldr     r10, =-32767        @ best_floor_top sentinel (below any valid Y)\n");
    s.push_str("    cmp     r7, #0\n    beq     plcy_finish\n");
    s.push_str("    ldr     r8, =LEVEL_GP_COUNT\n    ldr     r8, [r8]\n");
    s.push_str("    cmp     r8, #0\n    beq     plcy_finish\n");
    s.push_str("    ldr     r9, [r7, #16]       @ r9 = gpObjectsPtr (ROM)\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF\n");
    s.push_str("    sub     r0, r5, r6          @ player_feet = py - hh\n");
    s.push_str("plcy_loop:\n    cmp     r8, #0\n    beq     plcy_finish\n");
    // collidable flag (ROM[6] bit4)
    s.push_str("    ldrb    r1, [r9, #6]\n    tst     r1, #0x10\n    beq     plcy_next\n");
    // x-range check: |px - obj_x| < obj_hw + 8 (player hw = 8)
    s.push_str("    ldrb    r1, [r9, #12]       @ obj half_w\n");
    s.push_str("    ldrsh   r2, [r7, #0]        @ obj world_x (buf)\n");
    s.push_str("    sub     r2, r4, r2          @ dx = px - obj_x\n");
    s.push_str("    movs    r3, r2\n    bpl     plcy_dx_ok\n    neg     r3, r2\n");
    s.push_str("plcy_dx_ok:\n    add     r1, r1, #8\n    cmp     r3, r1\n    bge     plcy_next\n");
    // obj_top = world_y + half_h; only consider if obj_top <= player_feet
    s.push_str("    ldrsh   r2, [r7, #2]        @ obj world_y (buf)\n");
    s.push_str("    ldrb    r3, [r9, #13]       @ obj half_h\n");
    s.push_str("    add     r2, r2, r3          @ obj_top = world_y + half_h\n");
    s.push_str("    cmp     r2, r0\n    bgt     plcy_next   @ surface above player feet\n");
    // track highest floor_top (closest to player from below); sentinel -32767 < any valid top
    s.push_str("    cmp     r10, r2\n    bge     plcy_next\n    mov     r10, r2\n");
    s.push_str("plcy_next:\n    add     r7, r7, #8\n    add     r9, r9, #16\n");
    s.push_str("    subs    r8, r8, #1\n    b       plcy_loop\n");
    s.push_str("plcy_finish:\n");
    s.push_str("    ldr     r1, =-32767\n    cmp     r10, r1\n    beq     plcy_no_floor\n");
    s.push_str("    add     r0, r10, r6         @ floor_center = floor_top + player_hh\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n");
    s.push_str("plcy_no_floor:\n");
    s.push_str("    ldr     r0, =-200\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n");
    s.push_str("    .ltorg\n\n");

    // ── pitrex_level_collision_x(r0=px, r1=py, r2=hw, r3=hy) → r0 = push-out dx ──
    // Returns push-out dx to resolve horizontal overlap (0 if none).
    // r3=hy (player half-height) is used for the Y-overlap test — prevents lateral push
    // when hitting the bottom of a block from below (threshold = hy + obj_hh excludes that case).
    s.push_str("@ pitrex_level_collision_x(r0=px, r1=py, r2=hw, r3=hy) -> push-out dx\n");
    s.push_str(".global pitrex_level_collision_x\n.type pitrex_level_collision_x, %function\npitrex_level_collision_x:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    mov     r4, r0              @ px\n");
    s.push_str("    mov     r5, r1              @ py\n");
    s.push_str("    mov     r6, r2              @ half_w (player)\n");
    s.push_str("    mov     r11, r3             @ half_h (player) — for Y-overlap threshold\n");
    s.push_str("    ldr     r7, =LEVEL_DATA_PTR\n    ldr     r7, [r7]\n");
    s.push_str("    cmp     r7, #0\n    beq     plcx_done_zero\n");
    s.push_str("    ldr     r8, =LEVEL_GP_COUNT\n    ldr     r8, [r8]\n");
    s.push_str("    cmp     r8, #0\n    beq     plcx_done_zero\n");
    s.push_str("    ldr     r9, [r7, #16]       @ gpObjectsPtr (ROM)\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF\n");
    s.push_str("    mov     r10, #0             @ best push-out dx\n");
    s.push_str("plcx_loop:\n    cmp     r8, #0\n    beq     plcx_done\n");
    // collidable
    s.push_str("    ldrb    r0, [r9, #6]\n    tst     r0, #0x10\n    beq     plcx_next\n");
    // y-overlap: |py - obj_y| < player_hh + obj_half_h (uses actual player_hh, not hardcoded 8)
    s.push_str("    ldrb    r0, [r9, #13]       @ obj half_h\n");
    s.push_str("    ldrsh   r1, [r7, #2]        @ obj world_y\n");
    s.push_str("    sub     r1, r5, r1          @ dy = py - obj_y\n");
    s.push_str("    movs    r2, r1\n    bpl     plcx_dy_ok\n    neg     r2, r1\n");
    s.push_str("plcx_dy_ok:\n    add     r0, r0, r11\n    cmp     r2, r0\n    bge     plcx_next\n");
    // x-overlap: |px - obj_x| < player_hw + obj_hw
    s.push_str("    ldrb    r0, [r9, #12]       @ obj half_w\n");
    s.push_str("    ldrsh   r1, [r7, #0]        @ obj world_x\n");
    s.push_str("    sub     r1, r4, r1          @ dx_raw = px - obj_x\n");
    s.push_str("    add     r3, r6, r0          @ total_hw = player_hw + obj_hw\n");
    s.push_str("    movs    r2, r1\n    bpl     plcx_dx_abs\n    neg     r2, r1\n");
    s.push_str("plcx_dx_abs:\n    cmp     r2, r3\n    bge     plcx_next\n");
    // push-out = sign(dx_raw) * (total_hw - |dx_raw|)
    s.push_str("    sub     r3, r3, r2          @ overlap = total_hw - |dx|\n");
    s.push_str("    cmp     r1, #0\n    bge     plcx_push_pos\n    neg     r3, r3\n");
    s.push_str("plcx_push_pos:\n    mov     r10, r3\n");
    s.push_str("plcx_next:\n    add     r7, r7, #8\n    add     r9, r9, #16\n");
    s.push_str("    subs    r8, r8, #1\n    b       plcx_loop\n");
    s.push_str("plcx_done:\n    mov     r0, r10\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("plcx_done_zero:\n    mov     r0, #0\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("    .ltorg\n\n");

    s
}

fn emit_pitrex_camera() -> String {
    let mut s = String::new();
    s.push_str("@ pitrex_set_camera_x(r0=x)\n");
    s.push_str(".global pitrex_set_camera_x\n.type pitrex_set_camera_x, %function\npitrex_set_camera_x:\n");
    s.push_str("    ldr     r1, =CAMERA_X\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    bx      lr\n\n");
    s.push_str("@ pitrex_set_camera_y(r0=y)\n");
    s.push_str(".global pitrex_set_camera_y\n.type pitrex_set_camera_y, %function\npitrex_set_camera_y:\n");
    s.push_str("    ldr     r1, =CAMERA_Y\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    bx      lr\n\n");
    s
}

// ── Music helpers ─────────────────────────────────────────────────────────

fn emit_pitrex_newlib_stubs() -> String {
    // Newlib libc uses _kill/_getpid (underscore variants) for retargetable syscalls.
    // The SDK's cstubs.c only provides kill/getpid (no underscore), so we inject stubs here.
    let mut s = String::new();
    s.push_str("@ Newlib syscall stubs (_kill, _getpid)\n");
    s.push_str(".global _kill\n.type _kill, %function\n_kill:\n");
    s.push_str("    bx      lr\n\n");
    s.push_str(".global _getpid\n.type _getpid, %function\n_getpid:\n");
    s.push_str("    mov     r0, #1\n");
    s.push_str("    bx      lr\n\n");
    s
}

fn emit_pitrex_music_helpers() -> String {
    let mut s = String::new();

    // ── pitrex_play_music(r0=music_base) ──────────────────────────────────
    // Music asset header (assets.rs::compile_vmus):
    //   [base+0] .word num_events
    //   [base+4] .word loop_event_byte_offset (from base, NOT from base+8)
    //   [base+8] first event = (delay, num_writes, [reg,val]*N)
    // PSG_MUSIC_START stores the base; PSG_MUSIC_PTR is the cursor
    // pointing to the *current* event (initially base+8).
    s.push_str("@ pitrex_play_music(r0=music_base)\n");
    s.push_str(".global pitrex_play_music\n.type pitrex_play_music, %function\npitrex_play_music:\n");
    s.push_str("    ldr     r1, =PSG_MUSIC_START\n    str     r0, [r1]\n");
    s.push_str("    add     r2, r0, #8          @ first event = base + 8\n");
    s.push_str("    ldr     r1, =PSG_MUSIC_PTR\n    str     r2, [r1]\n");
    s.push_str("    ldr     r1, =PSG_IS_PLAYING\n    mov     r0, #1\n    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_DELAY_FRAMES\n    mov     r0, #0\n    str     r0, [r1]\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    // ── pitrex_stop_music() ────────────────────────────────────────────────
    // Mute all 3 channels and disable mixer, then mark not-playing.
    s.push_str("@ pitrex_stop_music()\n");
    s.push_str(".global pitrex_stop_music\n.type pitrex_stop_music, %function\npitrex_stop_music:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    ldr     r1, =PSG_IS_PLAYING\n    mov     r0, #0\n    str     r0, [r1]\n");
    s.push_str("    mov     r0, #8\n    mov     r1, #0\n    bl      v_writePSG\n");
    s.push_str("    mov     r0, #9\n    mov     r1, #0\n    bl      v_writePSG\n");
    s.push_str("    mov     r0, #10\n   mov     r1, #0\n    bl      v_writePSG\n");
    s.push_str("    mov     r0, #7\n    mov     r1, #0x3F\n bl      v_writePSG\n");
    s.push_str("    pop     {pc}\n    .ltorg\n\n");

    // ── pitrex_music_update() ──────────────────────────────────────────────
    // Advance music sequencer one frame:
    //   - decrement PSG_DELAY_FRAMES if > 0
    //   - else fire current event (apply N reg/val pairs via v_writePSG),
    //     then advance PSG_MUSIC_PTR past it, and load NEXT event's delay.
    //   - num_writes==0   → end of music: stop.
    //   - num_writes==0xFF → loop marker: jump to base + loop_event_byte_offset.
    s.push_str("@ pitrex_music_update() — advance music sequencer one frame\n");
    s.push_str(".global pitrex_music_update\n.type pitrex_music_update, %function\npitrex_music_update:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    ldr     r0, =PSG_IS_PLAYING\n    ldr     r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n    beq     pmu_done\n");
    // If PSG_DELAY_FRAMES > 0 → decrement, return
    s.push_str("    ldr     r4, =PSG_DELAY_FRAMES\n    ldr     r0, [r4]\n");
    s.push_str("    cmp     r0, #0\n    beq     pmu_process\n");
    s.push_str("    sub     r0, r0, #1\n    str     r0, [r4]\n    b       pmu_done\n");
    s.push_str("pmu_process:\n");
    s.push_str("    ldr     r5, =PSG_MUSIC_PTR\n    ldr     r5, [r5]    @ event ptr\n");
    s.push_str("    ldrb    r6, [r5, #1]                @ num_writes\n");
    s.push_str("    cmp     r6, #0\n    beq     pmu_end\n");
    s.push_str("    cmp     r6, #0xFF\n beq     pmu_loop\n");
    // Apply num_writes (reg, val) pairs starting at event+2
    s.push_str("    add     r7, r5, #2\n");
    s.push_str("pmu_wl:\n");
    s.push_str("    cmp     r6, #0\n    beq     pmu_after\n");
    s.push_str("    ldrb    r0, [r7]\n    ldrb    r1, [r7, #1]\n");
    s.push_str("    push    {r6, r7}\n    bl      v_writePSG\n    pop     {r6, r7}\n");
    s.push_str("    add     r7, r7, #2\n    sub     r6, r6, #1\n    b       pmu_wl\n");
    s.push_str("pmu_after:\n");
    // r7 now = next event ptr; store and load its delay
    s.push_str("    ldr     r0, =PSG_MUSIC_PTR\n    str     r7, [r0]\n");
    s.push_str("    ldrb    r0, [r7]                    @ next event delay\n");
    s.push_str("    str     r0, [r4]\n");
    s.push_str("    b       pmu_done\n");
    s.push_str("pmu_end:\n    bl      pitrex_stop_music\n    b       pmu_done\n");
    s.push_str("pmu_loop:\n");
    s.push_str("    ldr     r0, =PSG_MUSIC_START\n    ldr     r0, [r0]\n");
    s.push_str("    ldr     r1, [r0, #4]                @ loop_event_byte_offset\n");
    s.push_str("    add     r1, r0, r1\n");
    s.push_str("    ldr     r0, =PSG_MUSIC_PTR\n    str     r1, [r0]\n");
    s.push_str("    ldrb    r0, [r1]\n    str     r0, [r4]\n");
    s.push_str("pmu_done:\n    pop     {r4, r5, r6, r7, pc}\n    .ltorg\n\n");

    // ── pitrex_play_sfx(r0=sfx_base) ───────────────────────────────────────
    // SFX header is just a single .word num_events; first event at base+4.
    s.push_str("@ pitrex_play_sfx(r0=sfx_base)\n");
    s.push_str(".global pitrex_play_sfx\n.type pitrex_play_sfx, %function\npitrex_play_sfx:\n");
    s.push_str("    add     r0, r0, #4\n");
    s.push_str("    ldr     r1, =PSG_SFX_PTR\n    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_SFX_ACTIVE\n    mov     r0, #1\n    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_SFX_DELAY\n    mov     r0, #0\n    str     r0, [r1]\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    // pitrex_load_level(r0=level_ptr) — store header ptr, read counts, copy GP to mutable buf
    // Level header layout (24 bytes):
    //   [0..2]: xMin i16, [2..4]: xMax i16, [4..6]: yMin i16, [6..8]: yMax i16
    //   [8]: bgCount u8, [9]: gpCount u8, [10]: fgCount u8, [11]: pad u8
    //   [12..16]: bgObjectsPtr u32, [16..20]: gpObjectsPtr u32, [20..24]: fgObjectsPtr u32
    // Level object layout (16 bytes):
    //   [0..2]: x i16, [2..4]: y i16, [4]: scale u8, [5]: intensity u8,
    //   [6]: flags u8, [7]: type u8, [8..12]: vector_ptr u32,
    //   [12]: half_w u8, [13]: half_h u8, [14]: vel_x_init i8, [15]: vel_y_init i8
    // LEVEL_GP_BUF layout (8 bytes/entry): x i16, y i16, vx i16, vy i16
    s.push_str("@ pitrex_load_level(r0=level_ptr) — initialise level runtime state\n");
    s.push_str(".global pitrex_load_level\n.type pitrex_load_level, %function\npitrex_load_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, r0              @ r4 = level_ptr\n");
    // Store LEVEL_DATA_PTR
    s.push_str("    ldr     r1, =LEVEL_DATA_PTR\n");
    s.push_str("    str     r4, [r1]\n");
    // Read and store GP count (byte offset 9), clamped to 32
    s.push_str("    ldrb    r5, [r4, #9]        @ r5 = gpCount\n");
    s.push_str("    cmp     r5, #32\n");
    s.push_str("    movgt   r5, #32\n");
    s.push_str("    ldr     r1, =LEVEL_GP_COUNT\n");
    s.push_str("    str     r5, [r1]\n");
    // Copy GP objects to LEVEL_GP_BUF (x,y,vx,vy per entry)
    s.push_str("    ldr     r6, [r4, #16]       @ r6 = gpObjectsPtr\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF\n");
    s.push_str("    cmp     r5, #0\n    beq     .Lll_done\n");
    s.push_str(".Lll_copy:\n");
    s.push_str("    ldrsh   r0, [r6]            @ x (offset 0)\n");
    s.push_str("    ldrsh   r1, [r6, #2]        @ y (offset 2)\n");
    s.push_str("    ldrsb   r2, [r6, #14]       @ vel_x_init (offset 14)\n");
    s.push_str("    ldrsb   r3, [r6, #15]       @ vel_y_init (offset 15)\n");
    s.push_str("    strh    r0, [r7]            @ buf.x\n");
    s.push_str("    strh    r1, [r7, #2]        @ buf.y\n");
    s.push_str("    strh    r2, [r7, #4]        @ buf.vx\n");
    s.push_str("    strh    r3, [r7, #6]        @ buf.vy\n");
    s.push_str("    add     r6, r6, #16         @ advance ROM obj ptr\n");
    s.push_str("    add     r7, r7, #8          @ advance buf ptr\n");
    s.push_str("    subs    r5, r5, #1\n");
    s.push_str("    bne     .Lll_copy\n");
    s.push_str(".Lll_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");

    // pitrex_show_level() — draw all layer objects with camera offset
    // Draws BG (ROM positions) + GP (LEVEL_GP_BUF positions) + FG (ROM positions).
    // Each object drawn via pitrex_draw_vector_ex(asset_ptr, ox, oy, mirror=0, intensity).
    s.push_str("@ pitrex_show_level() — draw all level objects (BG+GP+FG)\n");
    s.push_str(".global pitrex_show_level\n.type pitrex_show_level, %function\npitrex_show_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    // Load level header ptr
    s.push_str("    ldr     r9, =LEVEL_DATA_PTR\n");
    s.push_str("    ldr     r9, [r9]            @ r9 = header ptr\n");
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    beq     .Lshl_done\n");
    // Cache camera offsets in r10, r11
    s.push_str("    ldr     r10, =CAMERA_X\n");
    s.push_str("    ldr     r10, [r10]          @ r10 = cam_x\n");
    s.push_str("    ldr     r11, =CAMERA_Y\n");
    s.push_str("    ldr     r11, [r11]          @ r11 = cam_y\n");

    // ---- BG layer ----
    s.push_str("    @ --- BG layer ---\n");
    s.push_str("    ldrb    r4, [r9, #8]        @ bgCount\n");
    s.push_str("    ldr     r5, [r9, #12]       @ bgObjectsPtr\n");
    s.push_str("    cmp     r4, #0\n    beq     .Lshl_gp\n");
    s.push_str(".Lshl_bg:\n");
    s.push_str("    ldrsh   r0, [r5]            @ obj.x\n");
    s.push_str("    ldrsh   r1, [r5, #2]        @ obj.y\n");
    s.push_str("    ldrb    r8, [r5, #5]        @ intensity\n");
    s.push_str("    ldr     r6, [r5, #8]        @ vector_ptr\n");
    s.push_str("    sub     r0, r0, r10         @ ox = x - cam_x\n");
    s.push_str("    sub     r1, r1, r11         @ oy = y - cam_y\n");
    s.push_str("    push    {r4, r5, r10, r11}  @ save loop state\n");
    s.push_str("    push    {r8}                @ 5th arg: intensity\n");
    s.push_str("    mov     r3, #0              @ mirror=0\n");
    s.push_str("    mov     r2, r1              @ oy\n");
    s.push_str("    mov     r1, r0              @ ox\n");
    s.push_str("    mov     r0, r6              @ asset_ptr\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4          @ pop intensity\n");
    s.push_str("    pop     {r4, r5, r10, r11}\n");
    s.push_str("    add     r5, r5, #16         @ next BG object\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     .Lshl_bg\n");

    // ---- GP layer (positions from LEVEL_GP_BUF) ----
    s.push_str(".Lshl_gp:\n");
    s.push_str("    @ --- GP layer (mutable positions) ---\n");
    s.push_str("    ldr     r4, =LEVEL_GP_COUNT\n");
    s.push_str("    ldr     r4, [r4]            @ gpCount\n");
    s.push_str("    ldr     r5, [r9, #16]       @ gpObjectsPtr (ROM, for vec_ptr+intensity)\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF   @ buf (current x,y)\n");
    s.push_str("    cmp     r4, #0\n    beq     .Lshl_fg\n");
    s.push_str(".Lshl_gp_loop:\n");
    s.push_str("    ldrsh   r0, [r7]            @ buf.x\n");
    s.push_str("    ldrsh   r1, [r7, #2]        @ buf.y\n");
    s.push_str("    ldrb    r8, [r5, #5]        @ intensity (from ROM obj)\n");
    s.push_str("    ldr     r6, [r5, #8]        @ vector_ptr (from ROM obj)\n");
    s.push_str("    sub     r0, r0, r10         @ ox = x - cam_x\n");
    s.push_str("    sub     r1, r1, r11         @ oy = y - cam_y\n");
    s.push_str("    push    {r4, r5, r7, r10, r11}  @ save loop state\n");
    s.push_str("    push    {r8}                @ 5th arg: intensity\n");
    s.push_str("    mov     r3, #0              @ mirror=0\n");
    s.push_str("    mov     r2, r1              @ oy\n");
    s.push_str("    mov     r1, r0              @ ox\n");
    s.push_str("    mov     r0, r6              @ asset_ptr\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4          @ pop intensity\n");
    s.push_str("    pop     {r4, r5, r7, r10, r11}\n");
    s.push_str("    add     r5, r5, #16         @ next ROM GP object\n");
    s.push_str("    add     r7, r7, #8          @ next buf entry\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     .Lshl_gp_loop\n");

    // ---- FG layer ----
    s.push_str(".Lshl_fg:\n");
    s.push_str("    @ --- FG layer ---\n");
    s.push_str("    ldrb    r4, [r9, #10]       @ fgCount\n");
    s.push_str("    ldr     r5, [r9, #20]       @ fgObjectsPtr\n");
    s.push_str("    cmp     r4, #0\n    beq     .Lshl_done\n");
    s.push_str(".Lshl_fg_loop:\n");
    s.push_str("    ldrsh   r0, [r5]            @ obj.x\n");
    s.push_str("    ldrsh   r1, [r5, #2]        @ obj.y\n");
    s.push_str("    ldrb    r8, [r5, #5]        @ intensity\n");
    s.push_str("    ldr     r6, [r5, #8]        @ vector_ptr\n");
    s.push_str("    sub     r0, r0, r10         @ ox = x - cam_x\n");
    s.push_str("    sub     r1, r1, r11         @ oy = y - cam_y\n");
    s.push_str("    push    {r4, r5, r10, r11}  @ save loop state\n");
    s.push_str("    push    {r8}                @ 5th arg: intensity\n");
    s.push_str("    mov     r3, #0              @ mirror=0\n");
    s.push_str("    mov     r2, r1              @ oy\n");
    s.push_str("    mov     r1, r0              @ ox\n");
    s.push_str("    mov     r0, r6              @ asset_ptr\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4          @ pop intensity\n");
    s.push_str("    pop     {r4, r5, r10, r11}\n");
    s.push_str("    add     r5, r5, #16         @ next FG object\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     .Lshl_fg_loop\n");

    s.push_str(".Lshl_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("    .ltorg\n\n");

    s
}

// ── SFX sequencer update ─────────────────────────────────────────────────

fn emit_pitrex_sfx_update() -> String {
    // pitrex_sfx_update() — advance SFX sequencer by one frame.
    //
    // Event format (matches assets.rs::compile_vsfx):
    //   [delay_byte, num_writes, (reg, val)*N]
    //   num_writes==0 → end of SFX.
    //
    // SFX is forced onto channel C (regs 4/5 period, 10 volume) by the
    // compiler, so it cannot overwrite music playing on channels A/B.
    let mut s = String::new();
    s.push_str("@ pitrex_sfx_update() — advance SFX sequencer one frame\n");
    s.push_str(".global pitrex_sfx_update\n.type pitrex_sfx_update, %function\npitrex_sfx_update:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    ldr     r0, =PSG_SFX_ACTIVE\n    ldr     r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n    beq     .Lsfxu_done\n");
    s.push_str("    ldr     r4, =PSG_SFX_DELAY\n    ldr     r0, [r4]\n");
    s.push_str("    cmp     r0, #0\n    beq     .Lsfxu_proc\n");
    s.push_str("    sub     r0, r0, #1\n    str     r0, [r4]\n    b       .Lsfxu_done\n");
    s.push_str(".Lsfxu_proc:\n");
    s.push_str("    ldr     r5, =PSG_SFX_PTR\n    ldr     r5, [r5]\n");
    s.push_str("    ldrb    r6, [r5, #1]                @ num_writes\n");
    s.push_str("    cmp     r6, #0\n    beq     .Lsfxu_stop\n");
    s.push_str("    add     r7, r5, #2\n");
    s.push_str(".Lsfxu_wl:\n");
    s.push_str("    cmp     r6, #0\n    beq     .Lsfxu_after\n");
    s.push_str("    ldrb    r0, [r7]\n    ldrb    r1, [r7, #1]\n");
    s.push_str("    push    {r6, r7}\n    bl      v_writePSG\n    pop     {r6, r7}\n");
    s.push_str("    add     r7, r7, #2\n    sub     r6, r6, #1\n    b       .Lsfxu_wl\n");
    s.push_str(".Lsfxu_after:\n");
    s.push_str("    ldr     r0, =PSG_SFX_PTR\n    str     r7, [r0]\n");
    s.push_str("    ldrb    r0, [r7]                    @ next event delay\n");
    s.push_str("    str     r0, [r4]\n");
    s.push_str("    b       .Lsfxu_done\n");
    s.push_str(".Lsfxu_stop:\n");
    // Mute channel C (the SFX channel) so it doesn't keep ringing.
    s.push_str("    mov     r0, #10\n    mov     r1, #0\n    bl      v_writePSG\n");
    s.push_str("    ldr     r0, =PSG_SFX_ACTIVE\n    mov     r1, #0\n    str     r1, [r0]\n");
    s.push_str(".Lsfxu_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n    .ltorg\n\n");
    s
}

// ── Math helpers ──────────────────────────────────────────────────────────

fn emit_pitrex_math_helpers() -> String {
    let mut s = String::new();

    // ABS(r0) → r0
    s.push_str("@ pitrex_abs(r0) → |r0|\n");
    s.push_str(".global pitrex_abs\n.type pitrex_abs, %function\npitrex_abs:\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r0, r0, #0\n");
    s.push_str("    bx      lr\n\n");

    // MIN(r0, r1) → r0
    s.push_str("@ pitrex_min(r0, r1) → min(r0,r1)\n");
    s.push_str(".global pitrex_min\n.type pitrex_min, %function\npitrex_min:\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r0, r1\n");
    s.push_str("    bx      lr\n\n");

    // MAX(r0, r1) → r0
    s.push_str("@ pitrex_max(r0, r1) → max(r0,r1)\n");
    s.push_str(".global pitrex_max\n.type pitrex_max, %function\npitrex_max:\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r0, r1\n");
    s.push_str("    bx      lr\n\n");

    // CLAMP(r0=val, r1=min, r2=max) → r0
    s.push_str("@ pitrex_clamp(r0=val, r1=min, r2=max) → clamped value\n");
    s.push_str(".global pitrex_clamp\n.type pitrex_clamp, %function\npitrex_clamp:\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r0, r1\n");
    s.push_str("    cmp     r0, r2\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r0, r2\n");
    s.push_str("    bx      lr\n\n");

    s
}

// ── Random ────────────────────────────────────────────────────────────────

fn emit_pitrex_random() -> String {
    let mut s = String::new();
    // LCG: seed = seed * 1664525 + 1013904223
    s.push_str("@ pitrex_random() → r0 = pseudo-random i16 in [0, 65535]\n");
    s.push_str(".global pitrex_random\n.type pitrex_random, %function\npitrex_random:\n");
    s.push_str("    ldr     r1, =RAND_SEED\n");
    s.push_str("    ldr     r0, [r1]\n");
    s.push_str("    ldr     r2, =1664525\n");
    s.push_str("    mul     r0, r0, r2\n");
    s.push_str("    ldr     r2, =1013904223\n");
    s.push_str("    add     r0, r0, r2\n");
    s.push_str("    str     r0, [r1]            @ update seed\n");
    s.push_str("    lsr     r0, r0, #16         @ use high 16 bits\n");
    s.push_str("    uxth    r0, r0\n");          // zero-extend to 16 bits (ARM32 safe, replaces #0xFFFF)
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── J2 Joystick ───────────────────────────────────────────────────────────

fn emit_pitrex_j2() -> String {
    let mut s = String::new();

    // Weak fallback for v_readJoystick2Analog — SDK version used if available, otherwise no-op
    s.push_str(".weak v_readJoystick2Analog\n");
    s.push_str(".type v_readJoystick2Analog, %function\n");
    s.push_str("v_readJoystick2Analog:\n");
    s.push_str("    bx      lr\n\n");

    // J2 X — currentJoy2X is int8_t (±127). Deadzone = ±32 (~25% of full range).
    s.push_str("@ pitrex_j2_x() → r0 = -1, 0, or +1\n");
    s.push_str(".global pitrex_j2_x\n.type pitrex_j2_x, %function\npitrex_j2_x:\n");
    s.push_str("    ldr     r1, =currentJoy2X\n");
    s.push_str("    ldrsb   r0, [r1]\n");
    s.push_str("    cmp     r0, #32\n");
    s.push_str("    bgt     1f\n");
    s.push_str("    cmn     r0, #32\n");
    s.push_str("    blt     2f\n");
    s.push_str("    mov     r0, #0\n    bx      lr\n");
    s.push_str("1:  mov     r0, #1\n    bx      lr\n");
    s.push_str("2:  mvn     r0, #0\n    bx      lr\n");
    s.push_str("    .ltorg\n\n");

    // J2 Y — currentJoy2Y is int8_t (±127). Deadzone = ±32.
    s.push_str("@ pitrex_j2_y() → r0 = -1, 0, or +1\n");
    s.push_str(".global pitrex_j2_y\n.type pitrex_j2_y, %function\npitrex_j2_y:\n");
    s.push_str("    ldr     r1, =currentJoy2Y\n");
    s.push_str("    ldrsb   r0, [r1]\n");
    s.push_str("    cmp     r0, #32\n");
    s.push_str("    bgt     1f\n");
    s.push_str("    cmn     r0, #32\n");
    s.push_str("    blt     2f\n");
    s.push_str("    mov     r0, #0\n    bx      lr\n");
    s.push_str("1:  mov     r0, #1\n    bx      lr\n");
    s.push_str("2:  mvn     r0, #0\n    bx      lr\n");
    s.push_str("    .ltorg\n\n");

    // J2 buttons — bits 4-7 of currentButtonState (active low, same as J1)
    for (name, bit) in [("pitrex_j2_btn1", 4u32), ("pitrex_j2_btn2", 5),
                        ("pitrex_j2_btn3", 6), ("pitrex_j2_btn4", 7)] {
        s.push_str(&format!("@ {name}() → r0=1 if pressed (bit {bit})\n"));
        s.push_str(&format!(".global {name}\n.type {name}, %function\n{name}:\n"));
        s.push_str("    ldr     r1, =currentButtonState\n");
        s.push_str("    ldr     r0, [r1]\n");
        s.push_str(&format!("    lsr     r0, r0, #{bit}\n"));
        s.push_str("    and     r0, r0, #1\n");
        s.push_str("    bx      lr\n\n");
    }

    s
}

// ── Trig (sin / cos / tan via 128-entry LUT) ──────────────────────────────

fn emit_pitrex_trig() -> String {
    let mut s = String::new();

    // 128-entry sine LUT: angle 0-127 → 0-360°, value -127..+127
    let sin_lut: Vec<i8> = (0..128u32)
        .map(|i| {
            let angle = i as f64 * std::f64::consts::TAU / 128.0;
            (angle.sin() * 127.0).round() as i8
        })
        .collect();

    // Emit LUT in .text (read-only data embedded before functions)
    s.push_str(".align 2\n");
    s.push_str("pitrex_sin_lut:\n    .byte ");
    let bytes: Vec<String> = sin_lut.iter().map(|b| format!("{}", b)).collect();
    s.push_str(&bytes.join(", "));
    s.push('\n');
    // cos LUT = sin shifted by 32 (90°)
    s.push_str("pitrex_cos_lut:\n    .byte ");
    let cos_bytes: Vec<String> = (0..128u32)
        .map(|i| {
            let angle = i as f64 * std::f64::consts::TAU / 128.0;
            format!("{}", (angle.cos() * 127.0).round() as i8)
        })
        .collect();
    s.push_str(&cos_bytes.join(", "));
    s.push_str("\n\n");

    // pitrex_sin(r0=angle) → r0 = sin_lut[angle & 127] (-127..127)
    s.push_str("@ pitrex_sin(r0=angle 0-127) → r0 = sine -127..127\n");
    s.push_str(".global pitrex_sin\n.type pitrex_sin, %function\npitrex_sin:\n");
    s.push_str("    and     r0, r0, #127\n");
    s.push_str("    ldr     r1, =pitrex_sin_lut\n");
    s.push_str("    ldrsb   r0, [r1, r0]\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");

    // pitrex_cos(r0=angle) → r0 = cos_lut[angle & 127]
    s.push_str("@ pitrex_cos(r0=angle 0-127) → r0 = cosine -127..127\n");
    s.push_str(".global pitrex_cos\n.type pitrex_cos, %function\npitrex_cos:\n");
    s.push_str("    and     r0, r0, #127\n");
    s.push_str("    ldr     r1, =pitrex_cos_lut\n");
    s.push_str("    ldrsb   r0, [r1, r0]\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");

    // pitrex_tan — forward to the clean pitrex_tan_impl (emitted by emit_pitrex_tan_clean)
    s.push_str("@ pitrex_tan(r0=angle) → forward to pitrex_tan_impl\n");
    s.push_str(".global pitrex_tan\n.type pitrex_tan, %function\npitrex_tan:\n");
    s.push_str("    b       pitrex_tan_impl\n\n");

    // pitrex_sqrt(r0=value) → r0 = integer sqrt via VFP
    s.push_str("@ pitrex_sqrt(r0=value) → r0 = integer square root\n");
    s.push_str(".global pitrex_sqrt\n.type pitrex_sqrt, %function\npitrex_sqrt:\n");
    s.push_str("    vmov    s0, r0\n");
    s.push_str("    vcvt.f32.s32 s0, s0\n");
    s.push_str("    vsqrt.f32 s0, s0\n");
    s.push_str("    vcvt.s32.f32 s0, s0\n");
    s.push_str("    vmov    r0, s0\n");
    s.push_str("    bx      lr\n\n");

    // pitrex_atan2(r0=y, r1=x) → angle 0-127 (integer, octant-based approximation)
    // Maps the full circle to 0-127 (like VPy's 0-127 angle convention).
    // Algorithm:
    //   1. Determine octant from signs of x,y and |x|>|y|
    //   2. Compute ratio t = (smaller / larger) * 32   [0-32 range → 0-16 quarter-circle]
    //   3. atan LUT (atan_lut[0..32]) maps t → 0-32 (quarter circle in 0-127 units)
    //   4. Adjust result for octant
    s.push_str("@ pitrex_atan2(r0=y, r1=x) → r0 = angle 0-127\n");
    s.push_str(".global pitrex_atan2\n.type pitrex_atan2, %function\npitrex_atan2:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, r0              @ r4 = y (signed)\n");
    s.push_str("    mov     r5, r1              @ r5 = x (signed)\n");
    // abs_y = |y|, abs_x = |x|
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    it      lt\n    rsblt   r6, r4, #0\n");
    s.push_str("    it      ge\n    movge   r6, r4\n");  // r6 = |y|
    s.push_str("    cmp     r5, #0\n");
    s.push_str("    it      lt\n    rsblt   r7, r5, #0\n");
    s.push_str("    it      ge\n    movge   r7, r5\n");  // r7 = |x|
    // Avoid div-by-zero
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    cmpeq   r7, #0\n");
    s.push_str("    beq     .Latan2_zero\n");
    // Determine if |y| > |x| (upper octant)
    s.push_str("    cmp     r6, r7\n");
    s.push_str("    bgt     .Latan2_steep\n");
    // Shallow: ratio = |y|*32 / |x|, base = 0 or 64
    s.push_str("    mov     r0, r6, asl #5      @ |y| * 32\n");
    s.push_str("    mov     r1, r7\n");
    s.push_str("    bl      __aeabi_idiv        @ r0 = ratio 0-32\n");
    s.push_str("    ldr     r1, =pitrex_atan_lut\n");
    s.push_str("    cmp     r0, #32\n    movgt   r0, #32\n");
    s.push_str("    ldrb    r0, [r1, r0]        @ atan angle\n");
    s.push_str("    b       .Latan2_quad\n");
    s.push_str(".Latan2_steep:\n");
    // Steep: ratio = |x|*32 / |y|, result = 32 - lut_val
    s.push_str("    mov     r0, r7, asl #5      @ |x| * 32\n");
    s.push_str("    mov     r1, r6\n");
    s.push_str("    bl      __aeabi_idiv        @ r0 = ratio 0-32\n");
    s.push_str("    ldr     r1, =pitrex_atan_lut\n");
    s.push_str("    cmp     r0, #32\n    movgt   r0, #32\n");
    s.push_str("    ldrb    r0, [r1, r0]\n");
    s.push_str("    rsb     r0, r0, #32         @ 32 - angle (complement)\n");
    // Adjust for quadrant: 0=angle(y≥0,x≥0), 1=32-angle+32(y≥0,x<0)... etc.
    // Full map (CCW from +x axis, 0-127):
    //   Q1 (x≥0,y≥0): angle directly           (0-32)
    //   Q2 (x<0,y≥0): 64-angle                 (32-64)
    //   Q3 (x<0,y<0): 64+angle                 (64-96)
    //   Q4 (x≥0,y<0): 128-angle (mod 128)      (96-127)
    s.push_str(".Latan2_quad:\n");
    // Save raw angle in r6
    s.push_str("    mov     r6, r0\n");
    s.push_str("    cmp     r5, #0\n    blt     .Latan2_xneg\n");
    // x >= 0
    s.push_str("    cmp     r4, #0\n    blt     .Latan2_q4\n");
    // Q1: result = angle
    s.push_str("    mov     r0, r6\n    b       .Latan2_done\n");
    s.push_str(".Latan2_q4:\n");
    // Q4: result = 128 - angle (y<0, x≥0)
    s.push_str("    rsb     r0, r6, #128\n");
    s.push_str("    and     r0, r0, #127\n");
    s.push_str("    b       .Latan2_done\n");
    s.push_str(".Latan2_xneg:\n");
    // x < 0
    s.push_str("    cmp     r4, #0\n    blt     .Latan2_q3\n");
    // Q2: result = 64 - angle  (y≥0, x<0)
    s.push_str("    rsb     r0, r6, #64\n    b       .Latan2_done\n");
    s.push_str(".Latan2_q3:\n");
    // Q3: result = 64 + angle  (y<0, x<0)
    s.push_str("    add     r0, r6, #64\n");
    s.push_str("    and     r0, r0, #127\n");
    s.push_str("    b       .Latan2_done\n");
    s.push_str(".Latan2_zero:\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str(".Latan2_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");
    // atan LUT: 33 entries, angle in 0-32 range (=0 to 45 deg mapped to 0-32 in 0-127 circle)
    // atan(t/32)*128/(2*pi) for t=0..32
    s.push_str("pitrex_atan_lut:\n");
    let lut: [u8; 33] = [0,1,2,3,4,5,6,7,8,8,9,10,11,12,12,13,14,14,15,15,16,17,17,18,18,19,19,20,20,20,21,21,22];
    let lut_str: Vec<String> = lut.iter().map(|v| format!("{v}")).collect();
    s.push_str(&format!("    .byte {}\n\n", lut_str.join(",")));

    // pitrex_pow(r0=base, r1=exp) → r0 = base^exp (integer, approximate via VFP)
    s.push_str("@ pitrex_pow(r0=base, r1=exp) → r0 = base^exp (integer)\n");
    s.push_str(".global pitrex_pow\n.type pitrex_pow, %function\npitrex_pow:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    mov     r4, r0      @ base\n");
    s.push_str("    mov     r5, r1      @ exp\n");
    s.push_str("    mov     r0, #1\n");
    s.push_str("    cmp     r5, #0\n");
    s.push_str("    beq     .Lpow_done\n");
    s.push_str(".Lpow_loop:\n");
    s.push_str("    mul     r0, r0, r4\n");
    s.push_str("    subs    r5, r5, #1\n");
    s.push_str("    bne     .Lpow_loop\n");
    s.push_str(".Lpow_done:\n");
    s.push_str("    pop     {r4, r5, pc}\n\n");

    s
}

// ── Tan: fix the broken implementation above with a clean one ─────────────

fn emit_pitrex_tan_clean() -> String {
    let mut s = String::new();
    // Override the broken tan with a clean implementation.
    // pitrex_tan(r0=angle) → sin[a]*128/cos[a], saturated ±127.
    // We emit a .global alias so the clean version wins over the earlier stub.
    s.push_str("@ pitrex_tan_impl(r0=angle 0-127) — correct tan via sin/cos LUT\n");
    s.push_str(".global pitrex_tan_impl\n.type pitrex_tan_impl, %function\npitrex_tan_impl:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    and     r4, r0, #127\n");
    // sin
    s.push_str("    ldr     r1, =pitrex_sin_lut\n");
    s.push_str("    ldrsb   r5, [r1, r4]   @ r5 = sin_val\n");
    // cos
    s.push_str("    ldr     r1, =pitrex_cos_lut\n");
    s.push_str("    ldrsb   r4, [r1, r4]   @ r4 = cos_val\n");
    // if cos==0 → saturate
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    bne     .Ltani_div\n");
    s.push_str("    cmp     r5, #0\n");
    s.push_str("    movge   r0, #127\n");
    s.push_str("    mvnlt   r0, #126\n");
    s.push_str("    pop     {r4, r5, pc}\n");
    s.push_str(".Ltani_div:\n");
    // r0 = (sin * 128) / cos — __aeabi_idiv(r0=num, r1=den)
    s.push_str("    mov     r0, r5, asl #7\n");
    s.push_str("    mov     r1, r4\n");
    s.push_str("    bl      __aeabi_idiv\n");
    // clamp to -127..127
    s.push_str("    cmp     r0, #127\n");
    s.push_str("    movgt   r0, #127\n");
    s.push_str("    mvn     r1, #126        @ r1 = -127\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    movlt   r0, r1\n");
    s.push_str("    pop     {r4, r5, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── rand / rand_range ─────────────────────────────────────────────────────

fn emit_pitrex_rand_fns() -> String {
    let mut s = String::new();

    // pitrex_rand — alias for pitrex_random (already emitted)
    s.push_str("@ pitrex_rand() → r0 = pseudo-random 0-32767\n");
    s.push_str(".global pitrex_rand\n.type pitrex_rand, %function\npitrex_rand:\n");
    s.push_str("    b       pitrex_random\n\n");

    // pitrex_rand_range(r0=lo, r1=hi) → lo + rand()%(hi-lo+1)
    // Uses __aeabi_idivmod(r0=dividend, r1=divisor) → r0=quotient, r1=remainder
    s.push_str("@ pitrex_rand_range(r0=lo, r1=hi) → r0 = random in [lo, hi]\n");
    s.push_str(".global pitrex_rand_range\n.type pitrex_rand_range, %function\npitrex_rand_range:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    mov     r4, r0              @ lo\n");
    s.push_str("    sub     r5, r1, r0\n");
    s.push_str("    add     r5, r5, #1          @ r5 = hi-lo+1 (range)\n");
    s.push_str("    bl      pitrex_random        @ r0 = random 0-65535\n");
    // r0 % r5 via __aeabi_idivmod
    s.push_str("    mov     r1, r5\n");
    s.push_str("    bl      __aeabi_idivmod      @ r1 = r0 % r5\n");
    s.push_str("    add     r0, r1, r4          @ + lo\n");
    s.push_str("    pop     {r4, r5, pc}\n");
    s.push_str("    .ltorg\n\n");

    s
}

// ── System: beep, wait, peek, poke, len ──────────────────────────────────

fn emit_pitrex_system() -> String {
    let mut s = String::new();

    // pitrex_beep(r0=period, r1=frames) — stub (no direct PSG access in PiTrex SDK)
    // The Vectrex PSG is controlled by the Vectrex CPU. PiTrex doesn't expose it directly.
    s.push_str("@ pitrex_beep(r0=period, r1=frames) — stub (no SDK PSG access)\n");
    s.push_str(".global pitrex_beep\n.type pitrex_beep, %function\npitrex_beep:\n");
    s.push_str("    bx      lr\n\n");

    // pitrex_wait(r0=frames) — wait N frames via v_WaitRecal
    s.push_str("@ pitrex_wait(r0=frames) — wait N frames\n");
    s.push_str(".global pitrex_wait\n.type pitrex_wait, %function\npitrex_wait:\n");
    s.push_str("    push    {r4, lr}\n");
    s.push_str("    mov     r4, r0\n");
    s.push_str(".Lwait_loop:\n");
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    beq     .Lwait_done\n");
    s.push_str("    bl      v_WaitRecal\n");
    s.push_str("    sub     r4, r4, #1\n");
    s.push_str("    b       .Lwait_loop\n");
    s.push_str(".Lwait_done:\n");
    s.push_str("    pop     {r4, pc}\n\n");

    // pitrex_peek(r0=addr) → r0 = byte at ARM address
    s.push_str("@ pitrex_peek(r0=addr) → r0 = byte at that ARM address\n");
    s.push_str(".global pitrex_peek\n.type pitrex_peek, %function\npitrex_peek:\n");
    s.push_str("    ldrb    r0, [r0]\n");
    s.push_str("    bx      lr\n\n");

    // pitrex_poke(r0=addr, r1=val) — write byte to ARM address
    s.push_str("@ pitrex_poke(r0=addr, r1=val) — write byte to ARM address\n");
    s.push_str(".global pitrex_poke\n.type pitrex_poke, %function\npitrex_poke:\n");
    s.push_str("    strb    r1, [r0]\n");
    s.push_str("    bx      lr\n\n");

    // pitrex_len(r0=array_ptr) → r0 = 0 (stub — length resolved at compile time)
    s.push_str("@ pitrex_len — stub (array length resolved at compile time via ARRAY_x_LEN)\n");
    s.push_str(".global pitrex_len\n.type pitrex_len, %function\npitrex_len:\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    bx      lr\n\n");

    s
}

// ── Camera getters ────────────────────────────────────────────────────────

fn emit_pitrex_camera_getters() -> String {
    let mut s = String::new();
    s.push_str("@ pitrex_get_camera_x() → r0 = CAMERA_X\n");
    s.push_str(".global pitrex_get_camera_x\n.type pitrex_get_camera_x, %function\npitrex_get_camera_x:\n");
    s.push_str("    ldr     r1, =CAMERA_X\n");
    s.push_str("    ldr     r0, [r1]\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    s.push_str("@ pitrex_get_camera_y() → r0 = CAMERA_Y\n");
    s.push_str(".global pitrex_get_camera_y\n.type pitrex_get_camera_y, %function\npitrex_get_camera_y:\n");
    s.push_str("    ldr     r1, =CAMERA_Y\n");
    s.push_str("    ldr     r0, [r1]\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Text extras ───────────────────────────────────────────────────────────

fn emit_pitrex_text_extras() -> String {
    let mut s = String::new();

    // pitrex_set_text_size(r0=size) — store for next print calls
    // v_printStringRaster takes size as 4th arg; we store it in TEXT_SIZE var
    s.push_str("@ pitrex_set_text_size(r0=size)\n");
    s.push_str(".global pitrex_set_text_size\n.type pitrex_set_text_size, %function\npitrex_set_text_size:\n");
    s.push_str("    ldr     r1, =PITREX_TEXT_SIZE\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");

    // pitrex_set_text_color(r0=color) — NOP, PiTrex is monochrome (brightness set globally)
    s.push_str("@ pitrex_set_text_color(r0=color) — NOP on monochrome PiTrex\n");
    s.push_str(".global pitrex_set_text_color\n.type pitrex_set_text_color, %function\npitrex_set_text_color:\n");
    s.push_str("    bx      lr\n\n");

    s
}

// ── Message system ────────────────────────────────────────────────────────

fn emit_pitrex_msg_system() -> String {
    let mut s = String::new();

    // pitrex_msg_def — registers a message string (stub — messages are compile-time strings)
    s.push_str("@ pitrex_msg_def(r0=id, r1=str_ptr) — registers message (compile-time only, NOP at runtime)\n");
    s.push_str(".global pitrex_msg_def\n.type pitrex_msg_def, %function\npitrex_msg_def:\n");
    s.push_str("    bx      lr\n\n");

    // pitrex_print_msg(r0=x, r1=y, r2=msg_id) — look up and print a registered message
    // For PiTrex: since msg strings are emitted as .asciz labels, the compiler passes a ptr directly.
    // Here r2 IS the string pointer.
    s.push_str("@ pitrex_print_msg(r0=x, r1=y, r2=str_ptr)\n");
    s.push_str(".global pitrex_print_msg\n.type pitrex_print_msg, %function\npitrex_print_msg:\n");
    s.push_str("    push    {lr}\n");
    // r0=x, r1=y, r2=str → forward to pitrex_print_text
    s.push_str("    bl      pitrex_print_text\n");
    s.push_str("    pop     {pc}\n\n");

    s
}

// ── update_level + draw_vector_3d ─────────────────────────────────────────

fn emit_pitrex_misc_stubs() -> String {
    let mut s = String::new();

    // pitrex_update_level() — advance GP object physics (velocity + gravity)
    // Reads world bounds from LEVEL_DATA_PTR header for clamping.
    // GP buf entry: x i16 (0), y i16 (2), vx i16 (4), vy i16 (6) — 8 bytes each.
    // ROM GP object flags byte (offset 6): bit0=physics, bit1=gravity.
    s.push_str("@ pitrex_update_level() — advance GP object physics\n");
    s.push_str(".global pitrex_update_level\n.type pitrex_update_level, %function\npitrex_update_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n");
    // Load level header ptr
    s.push_str("    ldr     r9, =LEVEL_DATA_PTR\n");
    s.push_str("    ldr     r9, [r9]\n");
    s.push_str("    cmp     r9, #0\n    beq     .Lul_done\n");
    // Load GP count
    s.push_str("    ldr     r4, =LEVEL_GP_COUNT\n");
    s.push_str("    ldr     r4, [r4]            @ r4 = gpCount\n");
    s.push_str("    cmp     r4, #0\n    beq     .Lul_done\n");
    // Load world bounds from header
    s.push_str("    ldrsh   r5, [r9, #4]        @ yMin\n");
    s.push_str("    ldrsh   r6, [r9, #6]        @ yMax\n");
    // ROM GP objects ptr (for flags) and buf ptr
    s.push_str("    ldr     r7, [r9, #16]       @ gpObjectsPtr (ROM)\n");
    s.push_str("    ldr     r8, =LEVEL_GP_BUF   @ mutable buf\n");
    s.push_str(".Lul_loop:\n");
    // Read flags from ROM object
    s.push_str("    ldrb    r0, [r7, #6]        @ flags byte\n");
    s.push_str("    tst     r0, #1              @ bit0 = physics enable\n");
    s.push_str("    beq     .Lul_next\n");
    // Read mutable state
    s.push_str("    ldrsh   r1, [r8]            @ buf.x\n");
    s.push_str("    ldrsh   r2, [r8, #2]        @ buf.y\n");
    s.push_str("    ldrsh   r3, [r8, #4]        @ buf.vx\n");
    s.push_str("    ldrsh   r12, [r8, #6]       @ buf.vy\n");
    // Apply gravity if bit1 set
    s.push_str("    tst     r0, #2              @ bit1 = gravity\n");
    s.push_str("    beq     .Lul_nograv\n");
    s.push_str("    sub     r12, r12, #1        @ vy -= 1 (downward gravity)\n");
    s.push_str("    cmp     r12, #-32\n");        // clamp velocity
    s.push_str("    movlt   r12, #-32\n");
    s.push_str(".Lul_nograv:\n");
    // Integrate position
    s.push_str("    add     r1, r1, r3          @ x += vx\n");
    s.push_str("    add     r2, r2, r12         @ y += vy\n");
    // Clamp y to world bounds (yMin..yMax)
    s.push_str("    cmp     r2, r5\n");
    s.push_str("    movlt   r2, r5\n    movlt   r12, #0\n");  // hit floor
    s.push_str("    cmp     r2, r6\n");
    s.push_str("    movgt   r2, r6\n    movgt   r12, #0\n");  // hit ceiling
    // Write back
    s.push_str("    strh    r1, [r8]            @ buf.x\n");
    s.push_str("    strh    r2, [r8, #2]        @ buf.y\n");
    s.push_str("    strh    r3, [r8, #4]        @ buf.vx (unchanged)\n");
    s.push_str("    strh    r12, [r8, #6]       @ buf.vy\n");
    s.push_str(".Lul_next:\n");
    s.push_str("    add     r7, r7, #16         @ next ROM object\n");
    s.push_str("    add     r8, r8, #8          @ next buf entry\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     .Lul_loop\n");
    s.push_str(".Lul_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n");
    s.push_str("    .ltorg\n\n");

    // pitrex_draw_vector_3d(r0=x, r1=y, r2=z, r3=asset_idx)
    // Simple perspective projection: screen_x = x * DIST / z, screen_y = y * DIST / z
    // DIST = 100 (fixed focal length). Calls pitrex_draw_vector_ex at projected position.
    // asset_idx is an index into VECTOR_ADDR_TABLE (same as draw_vector).
    // For z <= 0, skip drawing (behind camera).
    s.push_str("@ pitrex_draw_vector_3d(r0=x, r1=y, r2=z, r3=asset_ptr) — perspective\n");
    s.push_str(".global pitrex_draw_vector_3d\n.type pitrex_draw_vector_3d, %function\npitrex_draw_vector_3d:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, r0              @ x\n");
    s.push_str("    mov     r5, r1              @ y\n");
    s.push_str("    mov     r6, r2              @ z\n");
    s.push_str("    mov     r7, r3              @ asset_ptr\n");
    // Skip if z <= 0
    s.push_str("    cmp     r6, #0\n    ble     .Ldv3d_done\n");
    // screen_x = x * 100 / z
    s.push_str("    mov     r0, r4\n");
    s.push_str("    ldr     r1, =100\n");
    s.push_str("    mul     r0, r0, r1          @ x * 100\n");
    s.push_str("    mov     r1, r6\n");
    s.push_str("    bl      __aeabi_idiv        @ r0 = screen_x\n");
    s.push_str("    mov     r4, r0              @ save screen_x\n");
    // screen_y = y * 100 / z
    s.push_str("    mov     r0, r5\n");
    s.push_str("    ldr     r1, =100\n");
    s.push_str("    mul     r0, r0, r1          @ y * 100\n");
    s.push_str("    mov     r1, r6\n");
    s.push_str("    bl      __aeabi_idiv        @ r0 = screen_y\n");
    s.push_str("    mov     r5, r0              @ save screen_y\n");
    // Call pitrex_draw_vector_ex(asset_ptr, ox=screen_x, oy=screen_y, mirror=0, intensity=127)
    s.push_str("    push    {r4, r5}            @ save screen coords\n");
    s.push_str("    mov     r8, #127\n");
    s.push_str("    push    {r8}                @ 5th arg: intensity=127\n");
    s.push_str("    mov     r3, #0              @ mirror=0\n");
    s.push_str("    mov     r2, r5              @ oy = screen_y\n");
    s.push_str("    mov     r1, r4              @ ox = screen_x\n");
    s.push_str("    mov     r0, r7              @ asset_ptr\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4          @ pop intensity\n");
    s.push_str("    pop     {r4, r5}            @ pop screen coords (discard)\n");
    s.push_str(".Ldv3d_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");

    s
}

// ── print_number (proper implementation) ─────────────────────────────────

fn emit_pitrex_print_number_impl() -> String {
    // pitrex_print_number(r0=x, r1=y, r2=value) — converts int to decimal string, prints it.
    // Handles negative values: the '-' glyph is absent from the PiTrex SDK vector font
    // (it maps to ABC_27 = space), so we draw it manually with v_directDraw32 in PiTrex
    // coordinate units (same units as DRAW_LINE: VPy * 100).
    // r9 = is_negative flag (1 if value < 0).
    let mut s = String::new();
    s.push_str("@ pitrex_print_number(r0=x, r1=y, r2=value) — print decimal integer\n");
    s.push_str(".global pitrex_print_number\n.type pitrex_print_number, %function\npitrex_print_number:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n");
    // save args
    s.push_str("    mov     r4, r0          @ x\n");
    s.push_str("    mov     r5, r1          @ y\n");
    s.push_str("    mov     r6, r2          @ value\n");
    // allocate 8-byte stack buffer (aligned)
    s.push_str("    sub     sp, sp, #8\n");
    s.push_str("    mov     r7, sp          @ buf ptr\n");
    // check sign — set r9=is_negative, prepend '-' for the space-advance, abs value
    s.push_str("    mov     r9, #0          @ is_negative = false\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    bge     pn_positive\n");
    s.push_str("    mov     r9, #1          @ is_negative = true\n");
    s.push_str("    mov     r0, #45         @ '-' ASCII (font renders as space-advance)\n");
    s.push_str("    strb    r0, [r7]\n");
    s.push_str("    add     r7, r7, #1\n");
    s.push_str("    rsb     r6, r6, #0      @ abs(r6)\n");
    s.push_str("pn_positive:\n");
    // extract digits: 1000s, 100s, 10s, 1s
    for (i, divisor) in [1000u32, 100, 10, 1].iter().enumerate() {
        if *divisor > 1 {
            s.push_str(&format!("    @ digit {i}: /{divisor}\n"));
            s.push_str(&format!("    ldr     r8, ={divisor}\n"));
            s.push_str("    mov     r0, r6\n    mov     r1, r8\n");
            s.push_str("    bl      __aeabi_idivmod  @ r0=quot, r1=rem\n");
            s.push_str("    add     r0, r0, #48\n    strb    r0, [r7]\n");
            s.push_str("    add     r7, r7, #1\n");
            s.push_str("    mov     r6, r1\n");
        } else {
            s.push_str("    @ digit 3: ones\n");
            s.push_str("    add     r0, r6, #48\n    strb    r0, [r7]\n");
            s.push_str("    add     r7, r7, #1\n");
        }
    }
    // null terminator
    s.push_str("    mov     r0, #0\n    strb    r0, [r7]\n");
    // Reset beam to (0,0) so v_printString position is absolute
    s.push_str("    mov     r0, #0\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    bl      v_directMove32\n");
    // Load textSize (needed for both minus sign and v_printString)
    s.push_str("    ldr     r3, =PITREX_TEXT_SIZE\n");
    s.push_str("    ldr     r3, [r3]\n");
    s.push_str("    cmp     r3, #0\n    it eq\n    moveq   r3, #5\n");
    // If negative: draw minus sign as a horizontal line in PiTrex units.
    // v_printString uses startX = x_passed * 128; we pass VPy*25/32, so
    // startX = VPy * 100.  The '-' glyph advances 6*SCALEFONT = 9*textSize units.
    // Minus sign: x0=VPy_x*100, x1=x0+8*textSize, y0=y1=(VPy_y-8)*100+6*textSize.
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    beq     pn_print_str\n");
    s.push_str("    ldr     r12, =100\n");
    s.push_str("    mul     r0, r4, r12         @ x0_px = VPy_x * 100 (Rd≠Rm ✓)\n");
    s.push_str("    sub     r2, r5, #8          @ VPy_y - 8 (cap_height offset)\n");
    s.push_str("    mul     r1, r2, r12         @ y_baseline_px (Rd≠Rm ✓)\n");
    s.push_str("    add     r1, r1, r3, lsl #2  @ + 4*textSize\n");
    s.push_str("    add     r1, r1, r3, lsl #1  @ + 2*textSize → y_mid = baseline+6*ts\n");
    s.push_str("    add     r2, r0, r3, lsl #3  @ x1 = x0 + 8*textSize\n");
    s.push_str("    mov     r3, r1              @ y1 = y0 (horizontal line)\n");
    s.push_str("    mov     r12, #0x50\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    // Reload textSize (clobbered by v_directDraw32 as r3 is caller-saved)
    s.push_str("    ldr     r3, =PITREX_TEXT_SIZE\n");
    s.push_str("    ldr     r3, [r3]\n");
    s.push_str("    cmp     r3, #0\n    it eq\n    moveq   r3, #5\n");
    s.push_str("pn_print_str:\n");
    // call v_printString(x_scaled, y_scaled, buf, textSize, brightness)
    s.push_str("    mov     r0, r4          @ x\n");
    s.push_str("    mov     r1, r5          @ y\n");
    s.push_str("    mov     r2, sp          @ buf ptr\n");
    // Subtract cap_height first (in VPy space), then rescale 25/32.
    s.push_str("    sub     r1, r1, #8          @ baseline = top - cap_height (VPy units)\n");
    // Rescale VPy*25/32 so v_printString's x*128 = VPy*100 (matching draw funcs).
    s.push_str("    lsl     r12, r0, #4         @ r12 = x*16\n");
    s.push_str("    add     r12, r12, r0, lsl #3 @ r12 = x*24\n");
    s.push_str("    add     r0, r12, r0          @ r0  = x*25\n");
    s.push_str("    asr     r0, r0, #5           @ r0  = x*25/32\n");
    s.push_str("    lsl     r12, r1, #4         @ r12 = y*16\n");
    s.push_str("    add     r12, r12, r1, lsl #3 @ r12 = y*24\n");
    s.push_str("    add     r1, r12, r1          @ r1  = y*25\n");
    s.push_str("    asr     r1, r1, #5           @ r1  = y*25/32\n");
    s.push_str("    mov     r12, #0x50\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_printString\n");
    s.push_str("    add     sp, sp, #4\n");
    // free buffer
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── DRAW_ANIM ─────────────────────────────────────────────────────────────
//
// pitrex_draw_anim(r0 = ptr to _ANIM_NAME data block)
//
// ARM vanim data format (see pitrex/assets.rs compile_vanim_for_arm):
//   Header:
//     byte 0: frame_count
//     byte 1: loop_flag (1=loop, 0=freeze)
//     byte 2: base_ref_count
//     byte 3: frame_table_offset = 4 + base_ref_count*4
//     words [4 .. 4+base_ref_count*4]: ARM ptrs to base_ref vec data (_NAME_VECTORS)
//     words [frame_table_offset ..]:   ARM ptrs to frame data blocks
//   Frame block (_ANIM_NAME_Fn):
//     byte 0: duration_ticks
//     byte 1: vec_ref_count
//     byte 2-3: alignment padding (if vec_ref_count > 0)
//     words [4 ..]: ARM ptrs to vec data (_NAME_VECTORS)
//     byte after ptrs: inline_path_count (always 0 on pitrex)
//
// State: PITREX_ANIM_STATE_BUF[0] = frame_idx, [1] = ticks_left (0 = uninitialized)

fn emit_pitrex_draw_anim() -> String {
    let mut s = String::new();
    s.push_str("@ pitrex_draw_anim(r0 = ARM ptr to _ANIM_NAME data block, r1 = ox, r2 = oy)\n");
    s.push_str(".global pitrex_draw_anim\n.type pitrex_draw_anim, %function\npitrex_draw_anim:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    mov     r4, r0                      @ anim header ptr\n");
    s.push_str("    mov     r10, r1                     @ save ox\n");
    s.push_str("    mov     r11, r2                     @ save oy\n");
    s.push_str("    ldr     r5, =PITREX_ANIM_STATE_BUF\n");
    s.push_str("    ldrb    r6, [r5]                    @ frame_idx\n");
    s.push_str("    ldrb    r7, [r5, #1]                @ ticks_left (0=uninitialized)\n");

    // Draw base_refs (drawn every frame before tick management)
    s.push_str("    ldrb    r8, [r4, #2]                @ base_ref_count\n");
    s.push_str("    cmp     r8, #0\n");
    s.push_str("    beq     par_tick\n");
    s.push_str("    add     r9, r4, #4                  @ first base_ref word-ptr\n");
    s.push_str("par_base_loop:\n");
    s.push_str("    push    {r8, r9}\n");
    s.push_str("    ldr     r0, [r9]                    @ ARM ptr to vec data\n");
    s.push_str("    mov     r1, r10                     @ ox\n");
    s.push_str("    mov     r2, r11                     @ oy\n");
    s.push_str("    bl      pitrex_draw_vector\n");
    s.push_str("    pop     {r8, r9}\n");
    s.push_str("    add     r9, r9, #4                  @ next base_ref ptr\n");
    s.push_str("    subs    r8, r8, #1\n");
    s.push_str("    bne     par_base_loop\n");

    // Tick management
    s.push_str("par_tick:\n");
    s.push_str("    cmp     r7, #0\n");
    s.push_str("    beq     par_init_frame              @ first call: init frame 0\n");
    s.push_str("    subs    r7, r7, #1\n");
    s.push_str("    bgt     par_draw                    @ still ticking: draw current frame\n");

    // Ticks exhausted: advance frame
    s.push_str("    ldrb    r8, [r4]                    @ frame_count\n");
    s.push_str("    add     r6, r6, #1\n");
    s.push_str("    cmp     r6, r8\n");
    s.push_str("    blt     par_no_wrap\n");
    s.push_str("    ldrb    r9, [r4, #1]                @ loop flag\n");
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    beq     par_freeze\n");
    s.push_str("    mov     r6, #0                      @ loop: wrap to frame 0\n");
    s.push_str("par_no_wrap:\n");
    s.push_str("    strb    r6, [r5]                    @ save new frame_idx\n");
    // Fall through to par_init_frame to load new frame's duration

    // Load current frame data ptr and initialize ticks_left
    s.push_str("par_init_frame:\n");
    s.push_str("    ldrb    r8, [r4, #3]                @ frame_table_offset\n");
    s.push_str("    lsl     r9, r6, #2                  @ frame_idx * 4\n");
    s.push_str("    add     r9, r9, r8                  @ offset to frame table entry\n");
    s.push_str("    ldr     r9, [r4, r9]                @ ARM ptr to frame data\n");
    s.push_str("    ldrb    r7, [r9]                    @ duration_ticks\n");
    s.push_str("    cmp     r7, #0\n");
    s.push_str("    movle   r7, #1                      @ clamp to min 1\n");
    s.push_str("    strb    r7, [r5, #1]                @ save ticks_left\n");
    s.push_str("    b       par_draw_vecs\n");

    s.push_str("par_freeze:\n");
    s.push_str("    sub     r6, r6, #1                  @ stay on last frame\n");
    s.push_str("    strb    r6, [r5]\n");
    s.push_str("    mov     r7, #1\n");
    s.push_str("    strb    r7, [r5, #1]\n");
    s.push_str("    b       par_draw_frame\n");

    s.push_str("par_draw:\n");
    s.push_str("    strb    r7, [r5, #1]                @ save decremented ticks\n");
    // Fall through to par_draw_frame

    // Load frame ptr for current r6 and draw
    s.push_str("par_draw_frame:\n");
    s.push_str("    ldrb    r8, [r4, #3]                @ frame_table_offset\n");
    s.push_str("    lsl     r9, r6, #2                  @ frame_idx * 4\n");
    s.push_str("    add     r9, r9, r8\n");
    s.push_str("    ldr     r9, [r4, r9]                @ ARM ptr to frame data\n");

    // Draw vec_refs for current frame
    s.push_str("par_draw_vecs:\n");
    s.push_str("    ldrb    r8, [r9, #1]                @ vec_ref_count\n");
    s.push_str("    cmp     r8, #0\n");
    s.push_str("    beq     par_done\n");
    s.push_str("    add     r9, r9, #4                  @ skip duration+count+2-byte pad\n");
    s.push_str("    mov     r6, r8                      @ loop counter\n");
    s.push_str("par_vec_loop:\n");
    s.push_str("    push    {r6, r9}\n");
    s.push_str("    ldr     r0, [r9]                    @ ARM ptr to vec data\n");
    s.push_str("    mov     r1, r10                     @ ox\n");
    s.push_str("    mov     r2, r11                     @ oy\n");
    s.push_str("    bl      pitrex_draw_vector\n");
    s.push_str("    pop     {r6, r9}\n");
    s.push_str("    add     r9, r9, #4                  @ next vec ptr\n");
    s.push_str("    subs    r6, r6, #1\n");
    s.push_str("    bne     par_vec_loop\n");
    s.push_str("par_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("    .ltorg\n\n");

    // Static state buffer in BSS
    s.push_str(".bss\n");
    s.push_str(".balign 4\n");
    s.push_str("PITREX_ANIM_STATE_BUF: .space 2\n");
    s.push_str(".text\n\n");

    s
}
