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
    s.push_str(&emit_pitrex_draw_circle());
    s.push_str(&emit_pitrex_update_buttons());
    s.push_str(&emit_pitrex_debug_print());
    s.push_str(&emit_pitrex_level_collision());
    s.push_str(&emit_pitrex_camera());
    s.push_str(&emit_pitrex_newlib_stubs());
    s.push_str(&emit_pitrex_music_helpers());
    s.push_str(&emit_pitrex_math_helpers());
    s.push_str(&emit_pitrex_random());

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
    s.push_str("    mov     r4, #180\n");
    s.push_str("    mul     r4, r0, r4          @ r4 = new_x * 180\n");
    s.push_str("    mov     r5, #180\n");
    s.push_str("    mul     r5, r1, r5          @ r5 = new_y * 180\n");
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

// ── Draw line (relative) ──────────────────────────────────────────────────

fn emit_pitrex_draw_line() -> String {
    // pitrex_draw_line(r0=dx, r1=dy, r2=brightness)
    // Computes new_x = cur_x + dx*180, new_y = cur_y + dy*180
    // Calls v_directDraw32(cur_x, cur_y, new_x, new_y, brightness)
    let mut s = String::new();
    s.push_str("@ pitrex_draw_line(r0=dx, r1=dy, r2=brightness)\n");
    s.push_str(".global pitrex_draw_line\n.type pitrex_draw_line, %function\npitrex_draw_line:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    // scale dx, dy
    s.push_str("    mov     r4, #180\n");
    s.push_str("    mul     r4, r0, r4          @ r4 = dx * 180\n");
    s.push_str("    mov     r5, #180\n");
    s.push_str("    mul     r5, r1, r5          @ r5 = dy * 180\n");
    s.push_str("    mov     r6, r2              @ r6 = brightness\n");
    // load current pos
    s.push_str("    ldr     r7, =PITREX_CUR_X\n");
    s.push_str("    ldr     r0, [r7]            @ r0 = cur_x (= x0)\n");
    s.push_str("    ldr     r12, =PITREX_CUR_Y\n");
    s.push_str("    push    {r12}               @ save PITREX_CUR_Y ptr on stack\n");
    s.push_str("    ldr     r1, [r12]           @ r1 = cur_y (= y0)\n");
    // new_x = cur_x + dx*180, new_y = cur_y + dy*180
    s.push_str("    add     r2, r0, r4          @ r2 = new_x = x1\n");
    s.push_str("    add     r3, r1, r5          @ r3 = new_y = y1\n");
    // push brightness as 5th arg
    s.push_str("    push    {r6}               @ brightness = 5th arg\n");
    s.push_str("    bl      v_directDraw32      @ (x0, y0, x1, y1, brightness)\n");
    s.push_str("    add     sp, sp, #4          @ pop 5th arg\n");
    // update PITREX_CUR_X/Y to new_x/new_y
    s.push_str("    ldr     r0, [sp]            @ restore PITREX_CUR_Y ptr\n");
    s.push_str("    add     sp, sp, #4          @ pop PITREX_CUR_Y ptr\n");
    s.push_str("    add     r1, r4, r4          @ re-derive: need new values\n");
    // Easier: just reload cur_x then add delta
    s.push_str("    ldr     r1, =PITREX_CUR_X\n");
    s.push_str("    ldr     r2, [r1]\n");
    s.push_str("    add     r2, r2, r4\n");
    s.push_str("    str     r2, [r1]            @ PITREX_CUR_X += dx*180\n");
    s.push_str("    ldr     r1, =PITREX_CUR_Y\n");
    s.push_str("    ldr     r2, [r1]\n");
    s.push_str("    add     r2, r2, r5\n");
    s.push_str("    str     r2, [r1]            @ PITREX_CUR_Y += dy*180\n");
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
    s.push_str("    bl      pitrex_draw_line    @ move to start of path\n");
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
    s.push_str("    bl      pitrex_draw_line\n");
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
    // call pitrex_draw_line with brightness=0 (move)
    s.push_str("    mov     r2, #0\n");
    s.push_str("    push    {r4, r5, r6, r7, r8}\n");
    s.push_str("    bl      pitrex_draw_line\n");
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
    s.push_str("    bl      pitrex_draw_line\n");
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
    // Calls v_printStringRaster(x, y, str, size=1, angle=-7, terminator='\0')
    // ARM32 AAPCS: r0-r3 first 4 args, additional on stack
    let mut s = String::new();
    s.push_str("@ pitrex_print_text(r0=x, r1=y, r2=str_ptr)\n");
    s.push_str(".global pitrex_print_text\n.type pitrex_print_text, %function\npitrex_print_text:\n");
    s.push_str("    push    {lr}\n");
    // Scale x/y by 180
    s.push_str("    push    {r0, r1, r2}\n");
    s.push_str("    mov     r3, #180\n");
    s.push_str("    pop     {r0, r1, r2}\n");
    s.push_str("    mul     r0, r0, r3          @ x * 180\n");
    s.push_str("    mul     r1, r1, r3          @ y * 180\n");
    // v_printStringRaster(x, y, str, size, angle, terminator)
    // r0=x, r1=y, r2=str, r3=size=1
    s.push_str("    mov     r3, #1              @ size\n");
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
    // pitrex_print_number(r0=x, r1=y, r2=number)
    // Stub: just return (would need integer-to-string conversion)
    let mut s = String::new();
    s.push_str("@ pitrex_print_number(r0=x, r1=y, r2=number) — stub\n");
    s.push_str(".global pitrex_print_number\n.type pitrex_print_number, %function\npitrex_print_number:\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    s
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
    s.push_str("    mov     r0, #192\n");
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
    // Approximates a circle with 8 line segments.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_circle(r0=x, r1=y, r2=radius, r3=brightness)\n");
    s.push_str(".global pitrex_draw_circle\n.type pitrex_draw_circle, %function\npitrex_draw_circle:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, r0          @ cx\n");
    s.push_str("    mov     r5, r1          @ cy\n");
    s.push_str("    mov     r6, r2          @ radius\n");
    s.push_str("    mov     r7, r3          @ brightness\n");
    // Scale coords and radius by 192
    s.push_str("    mov     r0, #192\n");
    s.push_str("    mul     r4, r4, r0\n");
    s.push_str("    mul     r5, r5, r0\n");
    s.push_str("    mul     r6, r6, r0\n");
    // Draw 8-segment polygon approximation using fixed sin/cos * radius
    // Points (scaled by 1024 then divided):
    //   0°(1024,0) 45°(724,724) 90°(0,1024) 135°(-724,724)
    //   180°(-1024,0) 225°(-724,-724) 270°(0,-1024) 315°(724,-724)
    // Use r0=x0,r1=y0,r2=x1,r3=y1 for each draw call
    // We'll compute on the fly using the 8 precomputed deltas * r6/1024
    // Macro: draw from (cx+dx0*r, cy+dy0*r) to (cx+dx1*r, cy+dy1*r)
    // For brevity, use v_directDraw32 directly with 8 segments
    // Segment 0→1: (r,0) → (r*724/1024, r*724/1024)
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
        // r0 = cx + dx0*r/1024  (division by 1024 = asr #10)
        s.push_str(&format!("    mov     r0, #{}\n", x0s.abs()));
        if x0s < 0 {
            s.push_str("    neg     r0, r0\n");
        }
        s.push_str("    mul     r0, r0, r6\n");
        s.push_str("    asr     r0, r0, #10\n");
        s.push_str("    add     r0, r0, r4\n");
        // r1 = cy + dy0*r/1024
        s.push_str(&format!("    mov     r1, #{}\n", y0s.abs()));
        if y0s < 0 {
            s.push_str("    neg     r1, r1\n");
        }
        s.push_str("    mul     r1, r1, r6\n");
        s.push_str("    asr     r1, r1, #10\n");
        s.push_str("    add     r1, r1, r5\n");
        // r2 = cx + dx1*r/1024
        s.push_str(&format!("    mov     r2, #{}\n", x1s.abs()));
        if x1s < 0 {
            s.push_str("    neg     r2, r2\n");
        }
        s.push_str("    mul     r2, r2, r6\n");
        s.push_str("    asr     r2, r2, #10\n");
        s.push_str("    add     r2, r2, r4\n");
        // r3 = cy + dy1*r/1024
        s.push_str(&format!("    mov     r3, #{}\n", y1s.abs()));
        if y1s < 0 {
            s.push_str("    neg     r3, r3\n");
        }
        s.push_str("    mul     r3, r3, r6\n");
        s.push_str("    asr     r3, r3, #10\n");
        s.push_str("    add     r3, r3, r5\n");
        // brightness on stack
        s.push_str("    push    {r7}\n");
        s.push_str("    bl      v_directDraw32\n");
        s.push_str("    add     sp, sp, #4\n");
    }
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n\n");
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

    // pitrex_play_sfx / pitrex_load_level / pitrex_show_level — stubs
    s.push_str("@ pitrex_play_sfx(r0=sfx_ptr) — stub\n");
    s.push_str(".global pitrex_play_sfx\n.type pitrex_play_sfx, %function\npitrex_play_sfx:\n");
    s.push_str("    bx      lr\n\n");
    s.push_str("@ pitrex_load_level(r0=level_ptr) — stub\n");
    s.push_str(".global pitrex_load_level\n.type pitrex_load_level, %function\npitrex_load_level:\n");
    s.push_str("    bx      lr\n\n");
    s.push_str("@ pitrex_show_level() — stub\n");
    s.push_str(".global pitrex_show_level\n.type pitrex_show_level, %function\npitrex_show_level:\n");
    s.push_str("    bx      lr\n\n");

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
