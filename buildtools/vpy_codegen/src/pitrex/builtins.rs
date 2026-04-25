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

    s
}

// ── Frame sync ────────────────────────────────────────────────────────────

fn emit_pitrex_wait_recal() -> String {
    let mut s = String::new();
    s.push_str("@ pitrex_wait_recal() — frame sync via v_WaitRecal()\n");
    s.push_str(".global pitrex_wait_recal\n.type pitrex_wait_recal, %function\npitrex_wait_recal:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    bl      v_WaitRecal\n");
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
    // pitrex_draw_vector(r0 = asset_ptr)
    // asset_ptr → .vec binary: [path_count u16, per_path: [seg_count u16, segs...]]
    // Each segment: [dx i8, dy i8]  — but .vec uses int16 pairs in a flat hword table
    // Actually in ARM backend .vec is stored as: u16 num_paths, then per path:
    //   u16 num_segs, then num_segs pairs of i16 (dx, dy)
    // We iterate paths and segments, calling pitrex_draw_line for each segment.
    // Between paths we move without drawing (brightness=0).
    //
    // Register usage (callee-save):
    //   r4 = asset_ptr (cursor advancing through data)
    //   r5 = path index
    //   r6 = path count
    //   r7 = seg count
    // Plus nested calls use r0-r3.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_vector(r0=asset_ptr)\n");
    s.push_str(".global pitrex_draw_vector\n.type pitrex_draw_vector, %function\npitrex_draw_vector:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, r0              @ r4 = asset ptr\n");
    // read num_paths = *r4++ (u16)
    s.push_str("    ldrh    r6, [r4], #2        @ r6 = num_paths\n");
    s.push_str("    mov     r5, #0              @ path index = 0\n");
    s.push_str("dv_path_loop:\n");
    s.push_str("    cmp     r5, r6\n");
    s.push_str("    bge     dv_done\n");
    // read num_segs = *r4++ (u16)
    s.push_str("    ldrh    r7, [r4], #2        @ r7 = num_segs\n");
    // first "segment" is actually the move-to (start position of path)
    // Actually in VPy .vec format the first entry is the absolute start point.
    // We treat it as a MOVE (brightness=0).
    s.push_str("    ldrsh   r0, [r4], #2        @ dx (first entry = start_x relative)\n");
    s.push_str("    ldrsh   r1, [r4], #2        @ dy (first entry = start_y relative)\n");
    s.push_str("    mov     r2, #0              @ brightness=0 for move\n");
    // Scale and move
    s.push_str("    push    {r4, r5, r6, r7}\n");
    s.push_str("    bl      pitrex_draw_line_rel @ move to start of path\n");
    s.push_str("    pop     {r4, r5, r6, r7}\n");
    // remaining segments are draw operations
    s.push_str("    mov     r12, #1\n         @ seg index = 1\n");
    s.push_str("dv_seg_loop:\n");
    s.push_str("    cmp     r12, r7\n");
    s.push_str("    bge     dv_seg_done\n");
    s.push_str("    ldrsh   r0, [r4], #2        @ dx\n");
    s.push_str("    ldrsh   r1, [r4], #2        @ dy\n");
    s.push_str("    mov     r2, #127            @ full brightness\n");
    s.push_str("    push    {r4, r5, r6, r7, r12}\n");
    s.push_str("    bl      pitrex_draw_line_rel\n");
    s.push_str("    pop     {r4, r5, r6, r7, r12}\n");
    s.push_str("    add     r12, r12, #1\n");
    s.push_str("    b       dv_seg_loop\n");
    s.push_str("dv_seg_done:\n");
    s.push_str("    add     r5, r5, #1\n");
    s.push_str("    b       dv_path_loop\n");
    s.push_str("dv_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Draw vector EX (offset + mirror + intensity) ──────────────────────────

fn emit_pitrex_draw_vector_ex() -> String {
    // pitrex_draw_vector_ex(r0=asset_ptr, r1=ox, r2=oy, r3=mirror, [sp]=intensity)
    // Like pitrex_draw_vector but with offset (ox,oy) added and optional X mirror.
    // Intensity from stack replaces the hardcoded 127 in draw segments.
    //
    // On function entry (ARM AAPCS):
    //   [sp+0] = intensity  (pushed by caller, before our PUSH {r4..lr} which adds 24 bytes)
    //   So after "push {r4,r5,r6,r7,r8,lr}" (6 regs × 4 = 24 bytes):
    //   [sp+24] = intensity
    let mut s = String::new();
    s.push_str("@ pitrex_draw_vector_ex(r0=asset_ptr, r1=ox, r2=oy, r3=mirror, [sp]=intensity)\n");
    s.push_str(".global pitrex_draw_vector_ex\n.type pitrex_draw_vector_ex, %function\npitrex_draw_vector_ex:\n");
    // Save r4-r8, lr (6 regs = 24 bytes pushed)
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}\n");
    s.push_str("    mov     r4, r0              @ r4 = asset ptr\n");
    s.push_str("    mov     r5, r1              @ r5 = ox\n");
    s.push_str("    mov     r6, r2              @ r6 = oy\n");
    s.push_str("    mov     r7, r3              @ r7 = mirror flag\n");
    s.push_str("    ldr     r8, [sp, #24]       @ r8 = intensity (5th arg)\n");
    // read num_paths
    s.push_str("    ldrh    r3, [r4], #2        @ r3 = num_paths\n");
    s.push_str("    push    {r3}               @ save num_paths\n");
    s.push_str("    mov     r3, #0              @ path index\n");
    s.push_str("    push    {r3}               @ save path index\n");
    // path loop: [sp+0]=path_idx, [sp+4]=num_paths
    s.push_str("dvex_path_loop:\n");
    s.push_str("    ldr     r0, [sp]            @ path_idx\n");
    s.push_str("    ldr     r1, [sp, #4]        @ num_paths\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bge     dvex_done\n");
    // read num_segs
    s.push_str("    ldrh    r3, [r4], #2        @ r3 = num_segs\n");
    s.push_str("    push    {r3}               @ save num_segs\n");
    // first seg = move-to (brightness 0)
    s.push_str("    ldrsh   r0, [r4], #2        @ raw dx\n");
    s.push_str("    ldrsh   r1, [r4], #2        @ raw dy\n");
    // apply mirror: if mirror==1, negate dx
    s.push_str("    cmp     r7, #1\n");
    s.push_str("    it      eq\n");
    s.push_str("    rsbeq   r0, r0, #0          @ dx = -dx if mirror\n");
    // add offset
    s.push_str("    add     r0, r0, r5          @ dx += ox\n");
    s.push_str("    add     r1, r1, r6          @ dy += oy\n");
    // call pitrex_draw_line_rel with brightness=0 (move)
    s.push_str("    mov     r2, #0\n");
    s.push_str("    push    {r4, r5, r6, r7, r8}\n");
    s.push_str("    bl      pitrex_draw_line_rel\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8}\n");
    // segment draw loop: seg_idx starts at 1
    s.push_str("    mov     r3, #1\n");
    s.push_str("    push    {r3}               @ seg_idx\n");
    s.push_str("dvex_seg_loop:\n");
    // [sp+0]=seg_idx [sp+4]=num_segs [sp+8]=path_idx [sp+12]=num_paths
    s.push_str("    ldr     r0, [sp]            @ seg_idx\n");
    s.push_str("    ldr     r1, [sp, #4]        @ num_segs\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bge     dvex_seg_done\n");
    s.push_str("    ldrsh   r0, [r4], #2        @ raw dx\n");
    s.push_str("    ldrsh   r1, [r4], #2        @ raw dy\n");
    s.push_str("    cmp     r7, #1\n");
    s.push_str("    it      eq\n");
    s.push_str("    rsbeq   r0, r0, #0\n");
    s.push_str("    add     r0, r0, r5\n");
    s.push_str("    add     r1, r1, r6\n");
    s.push_str("    mov     r2, r8              @ use stored intensity\n");
    s.push_str("    push    {r4, r5, r6, r7, r8}\n");
    s.push_str("    bl      pitrex_draw_line_rel\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8}\n");
    s.push_str("    ldr     r0, [sp]\n");
    s.push_str("    add     r0, r0, #1\n");
    s.push_str("    str     r0, [sp]            @ seg_idx++\n");
    s.push_str("    b       dvex_seg_loop\n");
    s.push_str("dvex_seg_done:\n");
    s.push_str("    add     sp, sp, #4          @ pop seg_idx\n");
    s.push_str("    add     sp, sp, #4          @ pop num_segs\n");
    // increment path_idx
    s.push_str("    ldr     r0, [sp]\n");
    s.push_str("    add     r0, r0, #1\n");
    s.push_str("    str     r0, [sp]            @ path_idx++\n");
    s.push_str("    b       dvex_path_loop\n");
    s.push_str("dvex_done:\n");
    s.push_str("    add     sp, sp, #8          @ pop path_idx + num_paths\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Joystick / Buttons ────────────────────────────────────────────────────

fn emit_pitrex_j1_x() -> String {
    // Returns -1, 0, +1 from currentJoy1X (raw ±32767)
    // Threshold: ±8192 (≈25% deflection)
    let mut s = String::new();
    s.push_str("@ pitrex_j1_x() → r0 = -1, 0, or +1\n");
    s.push_str(".global pitrex_j1_x\n.type pitrex_j1_x, %function\npitrex_j1_x:\n");
    s.push_str("    ldr     r1, =currentJoy1X\n");
    s.push_str("    ldr     r0, [r1]\n");
    s.push_str("    ldr     r1, =8192\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bgt     1f              @ > threshold → +1\n");
    s.push_str("    neg     r1, r1\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    blt     2f              @ < -threshold → -1\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    bx      lr\n");
    s.push_str("1:  mov     r0, #1\n");
    s.push_str("    bx      lr\n");
    s.push_str("2:  mvn     r0, #0\n         @ r0 = -1\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    s
}

fn emit_pitrex_j1_y() -> String {
    let mut s = String::new();
    s.push_str("@ pitrex_j1_y() → r0 = -1, 0, or +1\n");
    s.push_str(".global pitrex_j1_y\n.type pitrex_j1_y, %function\npitrex_j1_y:\n");
    s.push_str("    ldr     r1, =currentJoy1Y\n");
    s.push_str("    ldr     r0, [r1]\n");
    s.push_str("    ldr     r1, =8192\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bgt     1f\n");
    s.push_str("    neg     r1, r1\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    blt     2f\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    bx      lr\n");
    s.push_str("1:  mov     r0, #1\n");
    s.push_str("    bx      lr\n");
    s.push_str("2:  mvn     r0, #0\n");
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
    // v_printStringRaster takes int8_t x, int8_t y — pass VPy coords unscaled.
    // v_printStringRaster(x, y, str, size=5, angle=-7, terminator='\0')
    // ARM32 AAPCS: r0-r3 first 4 args, additional on stack
    let mut s = String::new();
    s.push_str("@ pitrex_print_text(r0=x, r1=y, r2=str_ptr)\n");
    s.push_str(".global pitrex_print_text\n.type pitrex_print_text, %function\npitrex_print_text:\n");
    s.push_str("    push    {lr}\n");
    // r0=x, r1=y, r2=str — passed directly (int8_t, no scaling)
    // r3=size=5 (matches helloworld size for legibility)
    s.push_str("    mov     r3, #5              @ size\n");
    // push remaining args: angle=-7, terminator=0
    s.push_str("    mov     r12, #0             @ terminator\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    mvn     r12, #6             @ angle = -7 (mvn #6 = ~6 = -7)\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_printStringRaster\n");
    s.push_str("    add     sp, sp, #8          @ pop angle + terminator\n");
    s.push_str("    pop     {pc}\n");
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
    // Draws a rectangle as 4 lines using v_directDraw32.
    // Coordinate scaling: VPy units → pitrex units (*192)
    let mut s = String::new();
    s.push_str("@ pitrex_draw_rect(r0=x, r1=y, r2=w, r3=h) 5th=[sp]=brightness\n");
    s.push_str(".global pitrex_draw_rect\n.type pitrex_draw_rect, %function\npitrex_draw_rect:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    // Save x,y,w,h and load brightness from stack above saved regs (5*4=20 bytes pushed)
    s.push_str("    mov     r4, r0          @ x\n");
    s.push_str("    mov     r5, r1          @ y\n");
    s.push_str("    mov     r6, r2          @ w\n");
    s.push_str("    mov     r7, r3          @ h\n");
    s.push_str("    ldr     r3, [sp, #20]   @ brightness\n");
    // Scale all by 192
    s.push_str("    mov     r0, #100\n");
    s.push_str("    mul     r4, r4, r0      @ x *= 192\n");
    s.push_str("    mul     r5, r5, r0      @ y *= 192\n");
    s.push_str("    mul     r6, r6, r0      @ w *= 192\n");
    s.push_str("    mul     r7, r7, r0      @ h *= 192\n");
    // Compute corners: top-left(r4,r5), top-right(r4+r6,r5), bot-right(r4+r6,r5-r7), bot-left(r4,r5-r7)
    // Top edge: (x,y) -> (x+w,y)
    s.push_str("    mov     r0, r4\n");
    s.push_str("    mov     r1, r5\n");
    s.push_str("    add     r2, r4, r6\n");
    s.push_str("    mov     r3, r5\n");
    s.push_str("    ldr     r12, [sp, #20]\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    // Right edge: (x+w,y) -> (x+w,y-h)
    s.push_str("    add     r0, r4, r6\n");
    s.push_str("    mov     r1, r5\n");
    s.push_str("    add     r2, r4, r6\n");
    s.push_str("    sub     r3, r5, r7\n");
    s.push_str("    ldr     r12, [sp, #20]\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    // Bottom edge: (x+w,y-h) -> (x,y-h)
    s.push_str("    add     r0, r4, r6\n");
    s.push_str("    sub     r1, r5, r7\n");
    s.push_str("    mov     r2, r4\n");
    s.push_str("    sub     r3, r5, r7\n");
    s.push_str("    ldr     r12, [sp, #20]\n");
    s.push_str("    push    {r12}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    // Left edge: (x,y-h) -> (x,y)
    s.push_str("    mov     r0, r4\n");
    s.push_str("    sub     r1, r5, r7\n");
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
    // pitrex_draw_circle(r0=x, r1=y, r2=radius, r3=brightness)
    // 8-segment approximation. Coords scaled ×192. Constants 1024/724 > 255
    // so use ldr =N (literal pool) instead of mov #N.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_circle(r0=x, r1=y, r2=radius, r3=brightness)\n");
    s.push_str(".global pitrex_draw_circle\n.type pitrex_draw_circle, %function\npitrex_draw_circle:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, r0          @ cx\n");
    s.push_str("    mov     r5, r1          @ cy\n");
    s.push_str("    mov     r6, r2          @ radius\n");
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

    let segments: [(i32,i32,i32,i32); 8] = [
        (1024,0,    724,724),
        (724,724,   0,1024),
        (0,1024,    -724,724),
        (-724,724,  -1024,0),
        (-1024,0,   -724,-724),
        (-724,-724, 0,-1024),
        (0,-1024,   724,-724),
        (724,-724,  1024,0),
    ];
    for (x0s,y0s,x1s,y1s) in segments {
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
    // Draws outline + horizontal scan lines every 3 VPy units.
    // Reuses pitrex_draw_rect for the outline, then fills.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_filled_rect(r0=x, r1=y, r2=w, r3=h, [sp+0]=brightness)\n");
    s.push_str(".global pitrex_draw_filled_rect\n.type pitrex_draw_filled_rect, %function\npitrex_draw_filled_rect:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n");
    // save args
    s.push_str("    mov     r4, r0          @ x\n");
    s.push_str("    mov     r5, r1          @ y\n");
    s.push_str("    mov     r6, r2          @ w\n");
    s.push_str("    mov     r7, r3          @ h\n");
    s.push_str("    ldr     r8, [sp, #28]   @ brightness ([sp+7regs*4])\n");
    // draw outline: delegate to pitrex_draw_rect (same signature)
    s.push_str("    push    {r8}            @ brightness as 5th arg\n");
    s.push_str("    bl      pitrex_draw_rect\n");
    s.push_str("    add     sp, sp, #4\n");
    // scale coords by 192
    s.push_str("    mov     r9, #100\n");
    s.push_str("    mul     r4, r4, r9      @ x_s\n");
    s.push_str("    mul     r5, r5, r9      @ y_s\n");
    s.push_str("    mul     r6, r6, r9      @ w_s\n");
    s.push_str("    mul     r7, r7, r9      @ h_s\n");
    // scan line step = 3*192 = 576
    s.push_str("    mov     r9, #300        @ scan step (3 * 100)\n");
    // r0 = scan_y starts at y_s - step, going down to y_s - h_s
    s.push_str("    sub     r0, r5, r9      @ scan_y = y - step\n");
    s.push_str(".Lfill_loop:\n");
    s.push_str("    sub     r1, r5, r7      @ bottom = y_s - h_s\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    ble     .Lfill_done\n");
    // draw horizontal line at scan_y: from (x_s, scan_y) to (x_s+w_s, scan_y)
    s.push_str("    mov     r1, r0          @ y0 = scan_y\n");
    s.push_str("    add     r2, r4, r6      @ x1 = x_s + w_s\n");
    s.push_str("    mov     r3, r0          @ y1 = scan_y\n");
    s.push_str("    push    {r0, r8}        @ save scan_y; brightness as 5th arg\n");
    s.push_str("    mov     r0, r4          @ x0 = x_s\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    pop     {r0, r8}\n");
    s.push_str("    add     sp, sp, #0      @ no extra pop (brightness was in push pair)\n");
    s.push_str("    sub     r0, r0, r9      @ scan_y -= step\n");
    s.push_str("    b       .Lfill_loop\n");
    s.push_str(".Lfill_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Polygon ───────────────────────────────────────────────────────────────

fn emit_pitrex_draw_polygon() -> String {
    // pitrex_draw_polygon(r0=n, r1=x0, r2=y0, r3=x1, [sp+0]=y1, [sp+4]=x2, ..., [sp+(2n-3)*4]=brightness)
    // Connects n vertices in order and closes back to v0.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_polygon(r0=n, r1=x0, r2=y0, r3=x1, stack=y1,x2,y2,...,brightness)\n");
    s.push_str(".global pitrex_draw_polygon\n.type pitrex_draw_polygon, %function\npitrex_draw_polygon:\n");
    // save original sp before push (for reading stack args)
    s.push_str("    mov     r12, sp\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    // r4=n, r5=scale, r6=brightness, r7=x0_s, r8=y0_s, r9=cur_x_s, r10=cur_y_s, r11=loop counter
    s.push_str("    mov     r4, r0          @ n\n");
    s.push_str("    mov     r5, #100        @ scale\n");
    // brightness = [r12 + (2n-3)*4]
    s.push_str("    mov     r6, r4, lsl #1  @ 2n\n");
    s.push_str("    sub     r6, r6, #3      @ 2n-3\n");
    s.push_str("    lsl     r6, r6, #2      @ (2n-3)*4\n");
    s.push_str("    ldr     r6, [r12, r6]   @ brightness\n");
    // scale v0
    s.push_str("    mul     r7, r1, r5      @ x0_s\n");
    s.push_str("    mul     r8, r2, r5      @ y0_s\n");
    // scale v1 (x1=r3, y1=[r12+0])
    s.push_str("    mul     r9, r3, r5      @ x1_s\n");
    s.push_str("    ldr     r0, [r12, #0]   @ y1 raw\n");
    s.push_str("    mul     r10, r0, r5     @ y1_s\n");
    // draw edge 0→1: v_directDraw32(x0_s, y0_s, x1_s, y1_s, brightness)
    s.push_str("    push    {r9, r10}       @ save x1_s, y1_s (xk_next, yk_next)\n");
    s.push_str("    mov     r2, r9\n    mov     r3, r10\n");
    s.push_str("    mov     r0, r7\n    mov     r1, r8\n");
    s.push_str("    push    {r6}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r9, r10}       @ r9=cur_x=x1_s, r10=cur_y=y1_s\n");
    // loop k=2..n-1
    s.push_str("    mov     r11, #2\n");
    s.push_str(".Lpoly_loop:\n");
    s.push_str("    cmp     r11, r4\n");
    s.push_str("    bge     .Lpoly_close\n");
    // xk = [r12 + (2k-3)*4], yk = [r12 + (2k-2)*4]
    s.push_str("    mov     r0, r11, lsl #1 @ 2k\n");
    s.push_str("    sub     r0, r0, #3      @ 2k-3\n");
    s.push_str("    lsl     r0, r0, #2\n");
    s.push_str("    ldr     r0, [r12, r0]   @ xk raw\n");
    s.push_str("    mul     r0, r0, r5      @ xk_s\n");
    s.push_str("    mov     r1, r11, lsl #1 @ 2k\n");
    s.push_str("    sub     r1, r1, #2      @ 2k-2\n");
    s.push_str("    lsl     r1, r1, #2\n");
    s.push_str("    ldr     r1, [r12, r1]   @ yk raw\n");
    s.push_str("    mul     r1, r1, r5      @ yk_s\n");
    // save xk_s, yk_s; set up draw args
    s.push_str("    push    {r0, r1}        @ save new xk_s, yk_s\n");
    s.push_str("    mov     r2, r0\n    mov     r3, r1\n");
    s.push_str("    mov     r0, r9\n    mov     r1, r10\n");
    s.push_str("    push    {r6}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r9, r10}       @ r9=xk_s, r10=yk_s\n");
    s.push_str("    add     r11, r11, #1\n");
    s.push_str("    b       .Lpoly_loop\n");
    // close polygon: draw last→v0
    s.push_str(".Lpoly_close:\n");
    s.push_str("    mov     r0, r9\n    mov     r1, r10\n");
    s.push_str("    mov     r2, r7\n    mov     r3, r8\n");
    s.push_str("    push    {r6}\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Ellipse ───────────────────────────────────────────────────────────────

fn emit_pitrex_draw_ellipse() -> String {
    // pitrex_draw_ellipse(r0=cx, r1=cy, r2=rx, r3=ry, [sp+0]=brightness)
    // 8-segment approximation, same angles as draw_circle but separate x/y radii.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_ellipse(r0=cx, r1=cy, r2=rx, r3=ry, [sp+0]=brightness)\n");
    s.push_str(".global pitrex_draw_ellipse\n.type pitrex_draw_ellipse, %function\npitrex_draw_ellipse:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n");
    s.push_str("    mov     r4, r0          @ cx\n");
    s.push_str("    mov     r5, r1          @ cy\n");
    s.push_str("    mov     r6, r2          @ rx\n");
    s.push_str("    mov     r7, r3          @ ry\n");
    s.push_str("    ldr     r8, [sp, #28]   @ brightness\n");
    // scale cx,cy,rx,ry by 192
    s.push_str("    mov     r9, #100\n");
    s.push_str("    mul     r4, r4, r9\n");
    s.push_str("    mul     r5, r5, r9\n");
    s.push_str("    mul     r6, r6, r9\n");
    s.push_str("    mul     r7, r7, r9\n");
    // 8 segments with unit circle values *1024
    let segs: [(i32,i32,i32,i32); 8] = [
        (1024,0,    724,724),
        (724,724,   0,1024),
        (0,1024,    -724,724),
        (-724,724,  -1024,0),
        (-1024,0,   -724,-724),
        (-724,-724, 0,-1024),
        (0,-1024,   724,-724),
        (724,-724,  1024,0),
    ];
    for (xs0,ys0,xs1,ys1) in segs {
        // x coords use rx (r6), y coords use ry (r7)
        let emit_coord = |s: &mut String, reg: &str, scale_reg: &str, val: i32, base: &str| {
            s.push_str(&format!("    mov     {reg}, #{}\n", val.unsigned_abs()));
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
    // For each of the 8 segments (45° each), check if its start angle is within [start, start+sweep].
    // Segment i covers angle i*45..(i+1)*45. We check if i*45 >= start and i*45 < start+sweep.
    // Emit 8 conditional-draw blocks unrolled.
    let segs: [(i32,i32,i32,i32,i32); 8] = [
        (1024,0,    724,724,  0),    // 0°
        (724,724,   0,1024,   45),   // 45°
        (0,1024,    -724,724, 90),   // 90°
        (-724,724,  -1024,0,  135),  // 135°
        (-1024,0,   -724,-724,180),  // 180°
        (-724,-724, 0,-1024,  225),  // 225°
        (0,-1024,   724,-724, 270),  // 270°
        (724,-724,  1024,0,   315),  // 315°
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
    s.push_str("@ pitrex_level_collision_y(r0=x, r1=y, r2=h) -> r0=adjusted_y\n");
    s.push_str(".global pitrex_level_collision_y\n.type pitrex_level_collision_y, %function\npitrex_level_collision_y:\n");
    s.push_str("    mov     r0, r1\n");
    s.push_str("    bx      lr\n\n");
    s.push_str("@ pitrex_level_collision_x(r0=x, r1=y, r2=w) -> r0=adjusted_x\n");
    s.push_str(".global pitrex_level_collision_x\n.type pitrex_level_collision_x, %function\npitrex_level_collision_x:\n");
    s.push_str("    bx      lr\n\n");
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

    // pitrex_play_music(r0=music_ptr)
    s.push_str("@ pitrex_play_music(r0=music_ptr) — start music playback\n");
    s.push_str(".global pitrex_play_music\n.type pitrex_play_music, %function\npitrex_play_music:\n");
    s.push_str("    ldr     r1, =PSG_MUSIC_PTR\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_MUSIC_START\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_IS_PLAYING\n");
    s.push_str("    mov     r0, #1\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_DELAY_FRAMES\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    bx      lr\n\n");

    // pitrex_stop_music()
    s.push_str("@ pitrex_stop_music()\n");
    s.push_str(".global pitrex_stop_music\n.type pitrex_stop_music, %function\npitrex_stop_music:\n");
    s.push_str("    ldr     r1, =PSG_IS_PLAYING\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    bx      lr\n\n");

    // pitrex_music_update() — called every frame from game loop
    // Same event-table format as ARM backend but at 50fps.
    // TODO: wire up PSG events to PiTrex audio (v_setSoundFrequency etc.)
    // For now this is a stub that advances the event pointer when delay expires.
    s.push_str("@ pitrex_music_update() — advance music sequencer (50fps)\n");
    s.push_str(".global pitrex_music_update\n.type pitrex_music_update, %function\npitrex_music_update:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    // if !PSG_IS_PLAYING, return
    s.push_str("    ldr     r0, =PSG_IS_PLAYING\n");
    s.push_str("    ldr     r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     pmu_done\n");
    // if PSG_DELAY_FRAMES > 0, decrement and return
    s.push_str("    ldr     r4, =PSG_DELAY_FRAMES\n");
    s.push_str("    ldr     r0, [r4]\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     pmu_process\n");
    s.push_str("    sub     r0, r0, #1\n");
    s.push_str("    str     r0, [r4]\n");
    s.push_str("    b       pmu_done\n");
    s.push_str("pmu_process:\n");
    // Read event from PSG_MUSIC_PTR
    s.push_str("    ldr     r5, =PSG_MUSIC_PTR\n");
    s.push_str("    ldr     r4, [r5]            @ r4 = event ptr\n");
    // Event format (same as ARM): 1 byte type, followed by args
    // type=0xFF: loop (jump back to PSG_MUSIC_START)
    // type=0xFE: stop
    // type=delay_count (1 byte) + channel data (3 bytes): just advance delay
    s.push_str("    ldrb    r0, [r4], #1        @ read event type\n");
    s.push_str("    cmp     r0, #0xFF\n");
    s.push_str("    beq     pmu_loop\n");
    s.push_str("    cmp     r0, #0xFE\n");
    s.push_str("    beq     pmu_stop\n");
    // Normal event: low byte = delay_frames; skip 3 bytes of channel data (stub)
    s.push_str("    mov     r1, r0              @ delay\n");
    s.push_str("    add     r4, r4, #3          @ skip channel data\n");
    s.push_str("    str     r4, [r5]            @ update PSG_MUSIC_PTR\n");
    s.push_str("    ldr     r4, =PSG_DELAY_FRAMES\n");
    s.push_str("    str     r1, [r4]\n");
    s.push_str("    b       pmu_done\n");
    s.push_str("pmu_loop:\n");
    s.push_str("    ldr     r0, =PSG_MUSIC_START\n");
    s.push_str("    ldr     r0, [r0]\n");
    s.push_str("    ldr     r1, =PSG_MUSIC_PTR\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    b       pmu_done\n");
    s.push_str("pmu_stop:\n");
    s.push_str("    ldr     r0, =PSG_IS_PLAYING\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    str     r1, [r0]\n");
    s.push_str("pmu_done:\n");
    s.push_str("    pop     {r4, r5, pc}\n");
    s.push_str("    .ltorg\n\n");

    // pitrex_play_sfx(r0=sfx_ptr) — start SFX sequencer
    s.push_str("@ pitrex_play_sfx(r0=sfx_ptr) — start SFX playback\n");
    s.push_str(".global pitrex_play_sfx\n.type pitrex_play_sfx, %function\npitrex_play_sfx:\n");
    s.push_str("    add     r0, r0, #4          @ skip .word num_events header\n");
    s.push_str("    ldr     r1, =PSG_SFX_PTR\n");
    s.push_str("    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_SFX_ACTIVE\n");
    s.push_str("    mov     r0, #1\n    str     r0, [r1]\n");
    s.push_str("    ldr     r1, =PSG_SFX_DELAY\n");
    s.push_str("    mov     r0, #0\n    str     r0, [r1]\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");

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
    // Event format: [delay_byte, num_writes, (reg u8, val u8)×N]
    //   num_writes==0 → end of SFX.
    // PSG_SFX_DELAY counts down each frame; when it hits 0 consume the next event.
    // PSG register writes are stubbed (no direct PSG access on PiTrex SDK yet).
    let mut s = String::new();
    s.push_str("@ pitrex_sfx_update() — advance SFX sequencer\n");
    s.push_str(".global pitrex_sfx_update\n.type pitrex_sfx_update, %function\npitrex_sfx_update:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    // If not active, return immediately
    s.push_str("    ldr     r4, =PSG_SFX_ACTIVE\n");
    s.push_str("    ldr     r0, [r4]\n");
    s.push_str("    cmp     r0, #0\n    beq     .Lsfxu_done\n");
    // Decrement delay counter
    s.push_str("    ldr     r5, =PSG_SFX_DELAY\n");
    s.push_str("    ldr     r0, [r5]\n");
    s.push_str("    cmp     r0, #0\n    bne     .Lsfxu_decdelay\n");
    // Delay expired — process next event
    s.push_str("    ldr     r4, =PSG_SFX_PTR\n");
    s.push_str("    ldr     r4, [r4]            @ r4 = current event ptr\n");
    s.push_str("    ldrb    r0, [r4]            @ byte0 = delay\n");
    s.push_str("    ldrb    r1, [r4, #1]        @ byte1 = num_writes\n");
    // num_writes==0 → SFX finished
    s.push_str("    cmp     r1, #0\n    beq     .Lsfxu_stop\n");
    // Skip over event bytes: 2 (delay+num_writes) + 2*num_writes (reg,val pairs)
    s.push_str("    lsl     r2, r1, #1          @ r2 = num_writes * 2\n");
    s.push_str("    add     r2, r2, #2          @ + 2 header bytes\n");
    s.push_str("    add     r4, r4, r2          @ advance ptr past this event\n");
    // Update PSG_SFX_PTR
    s.push_str("    ldr     r1, =PSG_SFX_PTR\n");
    s.push_str("    str     r4, [r1]\n");
    // Load delay for next event (peek at next event's byte0)
    s.push_str("    ldrb    r0, [r4]            @ next event delay\n");
    s.push_str("    str     r0, [r5]            @ PSG_SFX_DELAY = next delay\n");
    s.push_str("    b       .Lsfxu_done\n");
    s.push_str(".Lsfxu_decdelay:\n");
    s.push_str("    sub     r0, r0, #1\n");
    s.push_str("    str     r0, [r5]            @ PSG_SFX_DELAY--\n");
    s.push_str("    b       .Lsfxu_done\n");
    s.push_str(".Lsfxu_stop:\n");
    s.push_str("    ldr     r0, =PSG_SFX_ACTIVE\n");
    s.push_str("    mov     r1, #0\n    str     r1, [r0]    @ deactivate\n");
    s.push_str(".Lsfxu_done:\n");
    s.push_str("    pop     {r4, r5, pc}\n");
    s.push_str("    .ltorg\n\n");
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

    // J2 X — from currentJoy2X (filled by v_readJoystick2Analog)
    s.push_str("@ pitrex_j2_x() → r0 = -1, 0, or +1\n");
    s.push_str(".global pitrex_j2_x\n.type pitrex_j2_x, %function\npitrex_j2_x:\n");
    s.push_str("    ldr     r1, =currentJoy2X\n");
    s.push_str("    ldr     r0, [r1]\n");
    s.push_str("    ldr     r1, =8192\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bgt     1f\n");
    s.push_str("    neg     r1, r1\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    blt     2f\n");
    s.push_str("    mov     r0, #0\n    bx      lr\n");
    s.push_str("1:  mov     r0, #1\n    bx      lr\n");
    s.push_str("2:  mvn     r0, #0\n    bx      lr\n");
    s.push_str("    .ltorg\n\n");

    // J2 Y — from currentJoy2Y
    s.push_str("@ pitrex_j2_y() → r0 = -1, 0, or +1\n");
    s.push_str(".global pitrex_j2_y\n.type pitrex_j2_y, %function\npitrex_j2_y:\n");
    s.push_str("    ldr     r1, =currentJoy2Y\n");
    s.push_str("    ldr     r0, [r1]\n");
    s.push_str("    ldr     r1, =8192\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bgt     1f\n");
    s.push_str("    neg     r1, r1\n");
    s.push_str("    cmp     r0, r1\n");
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
    // Uses a 6-byte stack buffer. Handles 0-9999 (matches M6809 backend range).
    let mut s = String::new();
    s.push_str("@ pitrex_print_number(r0=x, r1=y, r2=value) — print decimal integer\n");
    s.push_str(".global pitrex_print_number\n.type pitrex_print_number, %function\npitrex_print_number:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}\n");
    // save args
    s.push_str("    mov     r4, r0          @ x\n");
    s.push_str("    mov     r5, r1          @ y\n");
    s.push_str("    mov     r6, r2          @ value\n");
    // allocate 8-byte stack buffer (aligned)
    s.push_str("    sub     sp, sp, #8\n");
    s.push_str("    mov     r7, sp          @ buf ptr\n");
    // ensure value >= 0 (abs)
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r6, r6, #0\n");
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
    // call v_printStringRaster(x, y, buf, size, angle, terminator)
    s.push_str("    mov     r0, r4          @ x\n");
    s.push_str("    mov     r1, r5          @ y\n");
    s.push_str("    mov     r2, sp          @ buf ptr\n");
    s.push_str("    ldr     r3, =PITREX_TEXT_SIZE\n");
    s.push_str("    ldr     r3, [r3]\n");
    s.push_str("    cmp     r3, #0\n    it eq\n    moveq   r3, #5\n    @ default size\n");
    s.push_str("    mov     r12, #0\n    push    {r12}\n    @ terminator\n");
    s.push_str("    mvn     r12, #6\n    push    {r12}\n    @ angle=-7\n");
    s.push_str("    bl      v_printStringRaster\n");
    s.push_str("    add     sp, sp, #8      @ pop angle+terminator\n");
    // free buffer
    s.push_str("    add     sp, sp, #8\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}
