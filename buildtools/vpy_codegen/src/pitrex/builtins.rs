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
//! Coordinate scaling: VPy ±96/±128 → PiTrex ±12192/±16129
//!   Scale factor = 127 (matches rp2350 VIA T1=127: VPy×127 = same physical deflection)
//!
//! Beam tracking: PITREX_CUR_X, PITREX_CUR_Y in .bss (set by draw fns)

/// Emit PiTrex builtin helper functions as ARM32 assembly. Each `if any!`
/// gate is checked against `needed` (the set of upper-cased VPy builtin
/// names actually called by the program). Helpers whose names don't appear
/// are skipped, so an unused / broken helper can't break a project that
/// doesn't call it.
///
/// A handful of "scaffolding" helpers (newlib stubs, msg/debug, the small
/// math/random utility set) are emitted unconditionally — they're tiny and
/// many other emitted helpers reach into them transitively.
pub fn emit_builtins(needed: &std::collections::HashSet<String>) -> String {
    let mut s = String::new();

    s.push_str("@ ================================================================\n");
    s.push_str("@ PiTrex ARM32 builtins\n");
    s.push_str("@ ================================================================\n\n");

    // Shorthand: emit if any of these builtin names is in the needed set.
    let any = |names: &[&str]| names.iter().any(|n| needed.contains(*n));

    // Always-on baseline. Everything that's reached transitively from the
    // per-frame loop prologue (functions.rs) or from another always-on
    // helper has to live here, otherwise the link fails. The tree-shake
    // currently targets only the *clearly optional* big helpers below.
    s.push_str(&emit_pitrex_shared_bss());
    s.push_str(&emit_pitrex_wait_recal());
    s.push_str(&emit_pitrex_newlib_stubs());
    s.push_str(&emit_pitrex_math_helpers());
    s.push_str(&emit_pitrex_random());
    s.push_str(&emit_pitrex_msg_system());
    s.push_str(&emit_pitrex_debug_print());
    s.push_str(&emit_pitrex_camera());
    s.push_str(&emit_pitrex_get_frame_us());
    s.push_str(&emit_pitrex_set_intensity());
    s.push_str(&emit_pitrex_move());
    s.push_str(&emit_pitrex_draw_line());
    s.push_str(&emit_pitrex_draw_line_rel());
    s.push_str(&emit_pitrex_draw_vector());
    s.push_str(&emit_pitrex_draw_vector_ex());
    s.push_str(&emit_pitrex_draw_rect());
    s.push_str(&emit_pitrex_draw_filled_rect());
    s.push_str(&emit_pitrex_draw_polygon());
    s.push_str(&emit_pitrex_draw_circle());
    s.push_str(&emit_pitrex_draw_ellipse());
    s.push_str(&emit_pitrex_draw_arc());
    s.push_str(&emit_pitrex_update_buttons());
    s.push_str(&emit_pitrex_j1_x());
    s.push_str(&emit_pitrex_j1_y());
    s.push_str(&emit_pitrex_j1_btn1());
    s.push_str(&emit_pitrex_j1_btn2());
    s.push_str(&emit_pitrex_j1_btn3());
    s.push_str(&emit_pitrex_j1_btn4());
    s.push_str(&emit_pitrex_j2());
    s.push_str(&emit_pitrex_print_text());
    s.push_str(&emit_pitrex_print_number());
    s.push_str(&emit_pitrex_print_number_impl());
    s.push_str(&emit_pitrex_music_helpers());
    s.push_str(&emit_pitrex_sfx_update());
    s.push_str(&emit_pitrex_trig());
    s.push_str(&emit_pitrex_tan_clean());
    s.push_str(&emit_pitrex_rand_fns());
    s.push_str(&emit_pitrex_system());
    s.push_str(&emit_pitrex_draw_anim());

    // ── Tree-shaken (clearly optional, larger / riskier helpers) ────────
    if any(&["SET_TEXT_SIZE", "SET_TEXT_COLOR"]) { s.push_str(&emit_pitrex_text_extras()); }
    if any(&["LEVEL_COLLISION_X", "LEVEL_COLLISION_Y", "LEVEL_VERTICAL_WALL_HIT"]) {
        s.push_str(&emit_pitrex_level_collision());
    }
    if any(&[
        "GET_CAMERA_X", "GET_CAMERA_Y", "GET_LEVEL_FLOOR_Y",
        "GET_SCROLL_LIMIT_LEFT", "GET_SCROLL_LIMIT_RIGHT",
        "GET_SCROLL_LIMIT_TOP", "GET_SCROLL_LIMIT_BOTTOM",
    ]) {
        s.push_str(&emit_pitrex_camera_getters());
    }
    // emit_pitrex_misc_stubs also provides UPDATE_LEVEL + DRAW_VECTOR_3D.
    if any(&["UPDATE_LEVEL", "DRAW_VECTOR_3D"]) { s.push_str(&emit_pitrex_misc_stubs()); }
    if any(&["PLAY_NOTE", "NOTE_UPDATE"]) { s.push_str(&emit_pitrex_note_engine()); }
    if any(&["UPDATE_ENEMIES", "SPAWN_ENEMIES", "DRAW_ENEMIES"]) {
        // wander_set_sprite is reached transitively from UPDATE_ENEMIES.
        s.push_str(&emit_pitrex_wander_set_sprite());
    }
    // .vrec vector-recording playback ("vector movie" video track). Emitted
    // only when a DRAW_RECORDING("name", ...) call appears in the AST.
    if any(&["DRAW_RECORDING"])    { s.push_str(&emit_pitrex_draw_recording()); }
    if any(&["SPAWN_ENEMIES"])     { s.push_str(&emit_pitrex_spawn_enemies()); }
    if any(&["UPDATE_ENEMIES"])    { s.push_str(&emit_pitrex_update_enemies()); }
    if any(&["DRAW_ENEMIES"])      { s.push_str(&emit_pitrex_draw_enemies()); }
    if any(&["KILL_ENEMY"])        { s.push_str(&emit_pitrex_kill_enemy()); }
    if any(&["ENEMY_FIRE_EVENT"])  { s.push_str(&emit_pitrex_enemy_fire_event()); }

    s
}

// ── Shared BSS globals (always emitted) ──────────────────────────────────
// Vars referenced from multiple unrelated helpers. Extracting them here
// means a single helper can be tree-shaken without breaking the link for
// other helpers that read its globals.
fn emit_pitrex_shared_bss() -> String {
    let mut s = String::new();
    s.push_str("@ Shared BSS globals (used by multiple helpers)\n");
    s.push_str(".bss\n");
    s.push_str(".balign 4\n");
    s.push_str("PITREX_BRIGHTNESS_OVERRIDE: .space 1  @ 0=use .vec intensity, >0=override\n");
    s.push_str(".text\n\n");
    s
}

// ── Frame sync ────────────────────────────────────────────────────────────

fn emit_pitrex_wait_recal() -> String {
    // CPU usage measurement using BCM system timer (1µs, 32-bit free-running counter).
    // bcm2835_st = volatile uint32_t* set by SDK; CLO (counter low) is at offset +4.
    //
    // Flow every frame:
    //   [ENTRY] work_us = CLO - FRAME_WORK_START  (if not first frame)
    //           if --CPU_PRINT_CTR <= 0: print "W=NNNNNus\r\n", reset CTR=50
    //   [CALL]  bl v_WaitRecal        (blocks until next frame)
    //   [EXIT]  FRAME_WORK_START = CLO  (start of new work window)
    let mut s = String::new();
    s.push_str("@ pitrex_wait_recal() — frame sync + CPU usage measurement via BCM system timer\n");
    s.push_str(".global pitrex_wait_recal\n.type pitrex_wait_recal, %function\npitrex_wait_recal:\n");
    s.push_str("    push    {r4, r5, r6, lr}\n");

    // Read CLO (current µs)
    s.push_str("    ldr     r4, =bcm2835_st\n");
    s.push_str("    ldr     r4, [r4]            @ dereference: r4 = ST base ptr\n");
    s.push_str("    ldr     r5, [r4, #4]        @ r5 = CLO (µs counter, 32-bit)\n");

    // Compute work_us, skip on first frame (FRAME_WORK_START == 0)
    s.push_str("    ldr     r4, =FRAME_WORK_START\n");
    s.push_str("    ldr     r6, [r4]            @ r6 = start of last work window\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lwrcal_skip_measure\n");
    s.push_str("    sub     r6, r5, r6          @ r6 = work_us (handles 32-bit wrap)\n");

    // Overflow alarm: print "!OVR:W=NNNNus/20000us\r\n" every frame that exceeds budget
    // 20000 (0x4E20) doesn't fit in an ARM32 rotated-8-bit immediate — use literal pool load.
    s.push_str("    ldr     r4, =20000\n");
    s.push_str("    cmp     r6, r4\n");
    s.push_str("    blt     .Lwrcal_no_ovr\n");
    s.push_str("    ldr     r0, =.Lstr_cpu_ovr\n");
    s.push_str("    bl      vpy_uart_puts        @ \"!OVR:W=\"\n");
    s.push_str("    mov     r0, r6\n");
    s.push_str("    bl      vpy_uart_print_int   @ work µs\n");
    s.push_str("    ldr     r0, =.Lstr_cpu_of\n");
    s.push_str("    bl      vpy_uart_puts        @ \"/20000us\\r\\n\"\n");
    s.push_str(".Lwrcal_no_ovr:\n");

    // Decrement print counter; print every 10 frames (5×/sec at 50 Hz)
    s.push_str("    ldr     r4, =CPU_PRINT_CTR\n");
    s.push_str("    ldr     r0, [r4]\n");
    s.push_str("    subs    r0, r0, #1\n");
    s.push_str("    str     r0, [r4]\n");
    s.push_str("    bgt     .Lwrcal_skip_measure\n");
    s.push_str("    mov     r0, #10\n");
    s.push_str("    str     r0, [r4]            @ reset counter\n");
    s.push_str("    ldr     r0, =.Lstr_cpu_w\n");
    s.push_str("    bl      vpy_uart_puts        @ \"W=\"\n");
    s.push_str("    mov     r0, r6\n");
    s.push_str("    bl      vpy_uart_print_int   @ work µs\n");
    s.push_str("    ldr     r0, =.Lstr_cpu_of\n");
    s.push_str("    bl      vpy_uart_puts        @ \"/20000us\\r\\n\"\n");

    s.push_str(".Lwrcal_skip_measure:\n");

    // Call v_WaitRecal (blocks until next frame)
    s.push_str("    bl      v_WaitRecal\n");

    // Save new work-window start (CLO after recal)
    s.push_str("    ldr     r4, =bcm2835_st\n");
    s.push_str("    ldr     r4, [r4]\n");
    s.push_str("    ldr     r5, [r4, #4]        @ CLO after recal\n");
    s.push_str("    ldr     r4, =FRAME_WORK_START\n");
    s.push_str("    str     r5, [r4]\n");

    // Force currentScale=80 (matches Vectrex ROM-header Width byte $50).
    s.push_str("    mov     r0, #80\n");
    s.push_str("    bl      v_setScale\n");

    // UART trace frame header (gated by UART_TRACE_FRAMES_LEFT)
    s.push_str("    ldr     r0, =UART_TRACE_FRAMES_LEFT\n");
    s.push_str("    ldr     r1, [r0]\n");
    s.push_str("    cmp     r1, #0\n");
    s.push_str("    popeq   {r4, r5, r6, pc}\n");
    s.push_str("    sub     r1, r1, #1\n");
    s.push_str("    str     r1, [r0]\n");
    s.push_str("    ldr     r0, =UART_FRAME_NUM\n");
    s.push_str("    ldr     r2, [r0]\n");
    s.push_str("    add     r2, r2, #1\n");
    s.push_str("    str     r2, [r0]\n");
    s.push_str("    ldr     r0, =.Lstr_frame_hdr\n");
    s.push_str("    bl      vpy_uart_puts\n");
    s.push_str("    ldr     r0, =UART_FRAME_NUM\n");
    s.push_str("    ldr     r0, [r0]\n");
    s.push_str("    bl      vpy_uart_print_int\n");
    s.push_str("    ldr     r0, =.Lstr_frame_hdr_end\n");
    s.push_str("    bl      vpy_uart_puts\n");
    s.push_str("    pop     {r4, r5, r6, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Brightness ────────────────────────────────────────────────────────────

fn emit_pitrex_set_intensity() -> String {
    let mut s = String::new();
    s.push_str("@ pitrex_set_intensity(r0=brightness 0-127)\n");
    s.push_str(".global pitrex_set_intensity\n.type pitrex_set_intensity, %function\npitrex_set_intensity:\n");
    // r4 is callee-saved (preserved across bl calls); r0-r3 are scratch (caller-saved)
    s.push_str("    push    {r4, lr}\n");
    s.push_str("    mov     r4, r0              @ save brightness in callee-saved r4\n");
    // Store override so draw_vector/draw_vector_ex/draw_anim respect it
    s.push_str("    ldr     r1, =PITREX_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    strb    r0, [r1]\n");
    // UART trace: "SINT=N\r\n" — gated by UART_TRACE_FRAMES_LEFT to avoid blocking UART every frame
    s.push_str("    ldr     r0, =UART_TRACE_FRAMES_LEFT\n");
    s.push_str("    ldr     r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     .Lsint_no_trace\n");
    s.push_str("    ldr     r0, =.Lstr_sint\n");
    s.push_str("    bl      vpy_uart_puts\n");
    s.push_str("    mov     r0, r4\n");
    s.push_str("    bl      vpy_uart_print_int\n");
    s.push_str("    ldr     r0, =.Lstr_crlf\n");
    s.push_str("    bl      vpy_uart_puts\n");
    s.push_str(".Lsint_no_trace:\n");
    // Also call v_setBrightness so DRAW_LINE etc. see the new brightness
    s.push_str("    mov     r0, r4\n");
    s.push_str("    bl      v_setBrightness\n");
    s.push_str("    pop     {r4, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Move beam (no draw) ───────────────────────────────────────────────────

fn emit_pitrex_move() -> String {
    // pitrex_move(r0=x, r1=y) — move beam to absolute position, no draw.
    // v_directMove32 takes unscaled VPy/BIOS coords (same ±127 range as M6809).
    // PITREX_CUR_X/Y stores x*127 / y*127 so segment accumulation (pitrex_draw_line_rel)
    // works correctly (it adds dx*127 to PITREX_CUR for each segment).
    let mut s = String::new();
    s.push_str("@ pitrex_move(r0=x, r1=y) — move beam, no draw\n");
    s.push_str(".global pitrex_move\n.type pitrex_move, %function\npitrex_move:\n");
    s.push_str("    push    {r4, lr}\n");
    // Update PITREX_CUR_X/Y with scaled values (r0,r1 stay unscaled for v_directMove32)
    s.push_str("    mov     r4, #127\n");
    s.push_str("    mul     r2, r0, r4          @ r2 = x*127 (Rd≠Rm)\n");
    s.push_str("    ldr     r4, =PITREX_CUR_X\n");
    s.push_str("    str     r2, [r4]            @ PITREX_CUR_X = x*127\n");
    s.push_str("    ldr     r4, =PITREX_MOVE_X\n");
    s.push_str("    str     r2, [r4]            @ PITREX_MOVE_X = x*127\n");
    s.push_str("    mov     r4, #127\n");
    s.push_str("    mul     r2, r1, r4          @ r2 = y*127 (Rd≠Rm)\n");
    s.push_str("    ldr     r4, =PITREX_CUR_Y\n");
    s.push_str("    str     r2, [r4]            @ PITREX_CUR_Y = y*127\n");
    s.push_str("    ldr     r4, =PITREX_MOVE_Y\n");
    s.push_str("    str     r2, [r4]            @ PITREX_MOVE_Y = y*127\n");
    // Call v_directMove32(x, y) — unscaled coords; r0, r1 still intact
    s.push_str("    bl      v_directMove32\n");
    s.push_str("    pop     {r4, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Draw line (absolute, 5-arg) ───────────────────────────────────────────

fn emit_pitrex_draw_line() -> String {
    // pitrex_draw_line(r0=x0, r1=y0, r2=x1, r3=y1, [sp+0]=brightness)
    // Scales coordinates by 127 and adds PITREX_CUR_X/Y MOVE offset for absolute position.
    // Y convention: Vectrex Y+ = up, same as what v_directDraw32 expects on real hardware.
    // The JS emulator's v_directDraw32 handler is responsible for Y-flipping to canvas space.
    let mut s = String::new();
    s.push_str("@ pitrex_draw_line(r0=x0, r1=y0, r2=x1, r3=y1, [sp+0]=brightness)\n");
    s.push_str(".global pitrex_draw_line\n.type pitrex_draw_line, %function\npitrex_draw_line:\n");
    // push {r4, r5, r6, lr} = 16 bytes → brightness was at [sp+0], now at [sp+16]
    s.push_str("    push    {r4, r5, r6, lr}\n");
    s.push_str("    ldr     r4, [sp, #16]       @ brightness\n");
    s.push_str("    mov     r12, #127\n");
    s.push_str("    mul     r0, r0, r12         @ r0 = x0 * 127\n");
    s.push_str("    mul     r1, r1, r12         @ r1 = y0 * 127\n");
    s.push_str("    mul     r2, r2, r12         @ r2 = x1 * 127\n");
    s.push_str("    mul     r3, r3, r12         @ r3 = y1 * 127\n");
    // Load PITREX_MOVE_X and PITREX_MOVE_Y (set only by MOVE() builtin, Vectrex Y+ = up).
    // This is separate from PITREX_CUR_X/Y which tracks the beam inside DRAW_VECTOR.
    // Using PITREX_MOVE_X/Y means DRAW_VECTOR does NOT corrupt the MOVE offset.
    s.push_str("    ldr     r6, =PITREX_MOVE_X\n");
    s.push_str("    ldr     r5, [r6]            @ r5 = PITREX_MOVE_X\n");
    s.push_str("    ldr     r6, [r6, #4]        @ r6 = PITREX_MOVE_Y\n");
    // Add MOVE offset to convert relative DRAW_LINE coords to absolute screen coords
    s.push_str("    add     r0, r0, r5          @ abs_x0 = x0*127 + cur_x\n");
    s.push_str("    add     r1, r1, r6          @ abs_y0 = y0*127 + cur_y\n");
    s.push_str("    add     r2, r2, r5          @ abs_x1 = x1*127 + cur_x\n");
    s.push_str("    add     r3, r3, r6          @ abs_y1 = y1*127 + cur_y\n");
    s.push_str("    push    {r4}               @ brightness as 5th arg\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r4, r5, r6, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Draw line relative (3-arg, for internal vector drawing) ───────────────

fn emit_pitrex_draw_line_rel() -> String {
    // pitrex_draw_line_rel(r0=dx, r1=dy, r2=brightness)
    // Used internally by pitrex_draw_vector / pitrex_draw_vector_ex.
    // Computes new_x = cur_x + dx*127, new_y = cur_y + dy*127
    let mut s = String::new();
    s.push_str("@ pitrex_draw_line_rel(r0=dx, r1=dy, r2=brightness)\n");
    s.push_str(".global pitrex_draw_line_rel\n.type pitrex_draw_line_rel, %function\npitrex_draw_line_rel:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r4, #127\n");
    s.push_str("    mul     r4, r0, r4          @ r4 = dx * 127\n");
    s.push_str("    mov     r5, #127\n");
    s.push_str("    mul     r5, r1, r5          @ r5 = dy * 127\n");
    s.push_str("    mov     r6, r2              @ r6 = brightness\n");
    // OPTIMIZED: Use LDMIA to load CUR_X and CUR_Y in one burst load.
    // CUR_X and CUR_Y are declared consecutively in .bss (mod.rs lines 98-99).
    s.push_str("    ldr     r7, =PITREX_CUR_X\n");
    s.push_str("    ldmia   r7, {r0, r1}        @ r0=cur_x r1=cur_y (burst)\n");
    s.push_str("    add     r2, r0, r4          @ r2 = new_x\n");
    s.push_str("    add     r3, r1, r5          @ r3 = new_y\n");
    // OPTIMIZED: Gate entire UART trace block before push/pop overhead.
    // When UART_TRACE_FRAMES_LEFT==0 (normal play), skip 22+ memory ops per call.
    s.push_str("    ldr     r12, =UART_TRACE_FRAMES_LEFT\n");
    s.push_str("    ldr     r12, [r12]\n");
    s.push_str("    cmp     r12, #0\n");
    s.push_str("    beq     .Ldlr_no_trace\n");
    // ── trace block: only reached when traces are active ──
    s.push_str("    push    {r0, r1, r2, r3}    @ save call args across trace\n");
    s.push_str("    mov     r1, r2              @ trace x = new_x\n");
    s.push_str("    mov     r2, r3              @ trace y = new_y\n");
    s.push_str("    ldr     r0, =.Lstr_dr\n");
    s.push_str("    bl      uart_trace_xy\n");
    // Always log brightness when inside trace block (outer gate already checked)
    s.push_str("    ldr     r0, =.Lstr_br\n");
    s.push_str("    bl      vpy_uart_puts\n");
    s.push_str("    mov     r0, r6              @ brightness\n");
    s.push_str("    bl      vpy_uart_print_int\n");
    s.push_str("    ldr     r0, =.Lstr_crlf\n");
    s.push_str("    bl      vpy_uart_puts\n");
    s.push_str("    pop     {r0, r1, r2, r3}\n");
    s.push_str(".Ldlr_no_trace:\n");
    s.push_str("    push    {r6}               @ brightness as 5th arg\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    // Reload r7 and use explicit ldr/str: Thumb2 T1 ldmia always writes back
    // the base register, so r7 no longer points to PITREX_CUR_X after the
    // first ldmia above. ARM32 (pitrex) does not writeback without !, but
    // the explicit ldr/str is safe for both targets.
    s.push_str("    ldr     r7, =PITREX_CUR_X\n");
    s.push_str("    ldr     r2, [r7]            @ r2=cur_x\n");
    s.push_str("    ldr     r3, [r7, #4]        @ r3=cur_y\n");
    s.push_str("    add     r2, r2, r4          @ new cur_x\n");
    s.push_str("    add     r3, r3, r5          @ new cur_y\n");
    s.push_str("    str     r2, [r7]            @ store new cur_x\n");
    s.push_str("    str     r3, [r7, #4]        @ store new cur_y\n");
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
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}\n");
    // Save raw ox, oy (VPy units) for use in dv_bezier_seg.
    // v_drawBezierCubic expects VPy-unit coords and scales internally by 127.
    s.push_str("    push    {r1, r2}            @ [sp+0]=ox [sp+4]=oy (raw VPy units)\n");
    s.push_str("    mov     r4, r0              @ asset header ptr\n");
    s.push_str("    mov     r3, #127\n");
    s.push_str("    mul     r6, r1, r3          @ r6 = ox*127 (Rd=r6 ≠ Rm=r1)\n");
    s.push_str("    mul     r7, r2, r3          @ r7 = oy*127 (Rd=r7 ≠ Rm=r2)\n");
    s.push_str("    ldr     r5, [r4], #4        @ path_count\n");
    s.push_str("    mov     r8, #0\n");
    s.push_str("dv_path_loop:\n");
    s.push_str("    cmp     r8, r5\n");
    s.push_str("    bge     dv_done\n");
    s.push_str("    ldr     r9, [r4], #4        @ r9 = path data ptr\n");
    // Move beam to absolute path start using v_directMove32(x, y).
    // v_directMove32 repositions the beam without drawing (no brightness concern).
    // PITREX_CUR_X/Y is updated to match so pitrex_draw_line_rel uses correct from-coords.
    s.push_str("    ldrb    r10, [r9], #1       @ r10 = path intensity (from .vec)\n");
    // Check PITREX_BRIGHTNESS_OVERRIDE: non-zero means SET_INTENSITY was called
    s.push_str("    ldr     r0, =PITREX_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    ldrb    r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    movne   r10, r0             @ override from SET_INTENSITY\n");
    s.push_str("    ldrsb   r1, [r9], #1        @ r1 = y_start (i8)\n");
    s.push_str("    ldrsb   r0, [r9], #1        @ r0 = x_start (i8)\n");
    s.push_str("    add     r9, r9, #2          @ skip 2 hdr padding bytes\n");
    // target = (x_start + ox)*127, (y_start + oy)*127
    // Use r2 as MUL dest to satisfy ARM32 Rd≠Rm constraint
    s.push_str("    mov     r3, #127\n");
    s.push_str("    mul     r2, r0, r3          @ r2 = x_start*127 (Rd=r2 ≠ Rm=r0)\n");
    s.push_str("    add     r0, r2, r6          @ r0 = (x_start+ox)*127\n");
    s.push_str("    mul     r2, r1, r3          @ r2 = y_start*127 (Rd=r2 ≠ Rm=r1)\n");
    s.push_str("    add     r1, r2, r7          @ r1 = (y_start+oy)*127\n");
    s.push_str("    ldr     r2, =PITREX_CUR_X\n");
    s.push_str("    str     r0, [r2]            @ PITREX_CUR_X = target_x\n");
    s.push_str("    ldr     r2, =PITREX_CUR_Y\n");
    s.push_str("    str     r1, [r2]            @ PITREX_CUR_Y = target_y\n");
    // ── UART trace: log target_x, target_y before v_directMove32 ──
    s.push_str("    push    {r0, r1}            @ save call args\n");
    s.push_str("    mov     r2, r1              @ trace y\n");
    s.push_str("    mov     r1, r0              @ trace x\n");
    s.push_str("    ldr     r0, =.Lstr_mv\n");
    s.push_str("    bl      uart_trace_xy\n");
    s.push_str("    pop     {r0, r1}\n");
    s.push_str("    bl      v_directMove32\n");
    // v_directMove32 internally calls SET_OPTIMAL_SCALE which clobbers currentScale.
    // Restore our calibrated T1=80 so the next draws (with PL_BASE_FORCE_USE_FIX_SIZE)
    // use the correct timing.
    s.push_str("    mov     r0, #80\n");
    s.push_str("    bl      v_setScale\n");
    s.push_str("    b       dv_after_pool\n");
    s.push_str("    .ltorg\n");
    s.push_str("dv_after_pool:\n");
    s.push_str("dv_seg_loop:\n");
    s.push_str("    ldrb    r0, [r9], #1        @ marker (0xFE=bezier, 0xFF=line, 0x02=end)\n");
    s.push_str("    cmp     r0, #2\n");
    s.push_str("    beq     dv_seg_done\n");
    s.push_str("    cmp     r0, #0xFE\n");
    s.push_str("    beq     dv_bezier_seg\n");
    s.push_str("    ldrsb   r1, [r9], #1        @ dy\n");
    s.push_str("    ldrsb   r0, [r9], #1        @ dx\n");
    s.push_str("    mov     r2, r10             @ intensity from .vec\n");
    // OPTIMIZED: No push/pop needed — pitrex_draw_line_rel saves r4-r7 itself,
    // and does NOT modify r8, r9, r10 (verified by inspection).
    // Removing push/pop saves 14 memory operations per segment.
    s.push_str("    bl      pitrex_draw_line_rel\n");
    s.push_str("    b       dv_seg_loop\n");
    s.push_str("dv_seg_done:\n");
    s.push_str("    add     r8, r8, #1\n");
    s.push_str("    b       dv_path_loop\n");
    // ── 0xFE runtime-bezier handler ──────────────────────────────────────────
    // Reads 8 signed bytes (x0,y0,cp1x,cp1y,cp2x,cp2y,endx,endy) from [r9]++.
    // Adds raw VPy offset (ox,oy) so coordinates are sprite-origin-relative.
    // Passes result directly to v_drawBezierCubic which scales internally by 127.
    //
    // Function prologue pushes {r4..r10,lr} then {r1,r2} (raw ox,oy).
    // Stack layout inside dv_bezier_seg after  push {r4..r10} ; sub sp,#24:
    //   [sp+ 0..20] = 6 call args (cp2x,cp2y,endx,endy,steps,bri)
    //   [sp+24]=r4  [sp+28]=r5  [sp+32]=r6(ox*127)  [sp+36]=r7(oy*127)
    //   [sp+40]=r8  [sp+44]=r9(cursor)  [sp+48]=r10(intensity)
    //   [sp+52]=r1(raw_ox)  [sp+56]=r2(raw_oy)   ← saved in prologue
    s.push_str("dv_bezier_seg:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10}\n");
    s.push_str("    sub     sp, sp, #24\n");
    // OPTIMIZED: Use LDMIA to load ox, oy in one instruction instead of 2 LDR
    s.push_str("    add     r0, sp, #52         @ r0 = &ox (sp after push+sub)\n");
    s.push_str("    ldmia   r0, {r4, r5}        @ r4=ox, r5=oy (2 words loaded at once)\n");
    // x0 + ox → r0
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r0, r6, r4\n");
    // y0 + oy → r1
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r1, r6, r5\n");
    // cp1x + ox → r2
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r2, r6, r4\n");
    // cp1y + oy → r3
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r3, r6, r5\n");
    // cp2x + ox → [sp+0]
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r7, r6, r4\n");
    s.push_str("    str     r7, [sp, #0]\n");
    // cp2y + oy → [sp+4]
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r7, r6, r5\n");
    s.push_str("    str     r7, [sp, #4]\n");
    // endx + ox → [sp+8]
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r7, r6, r4\n");
    s.push_str("    str     r7, [sp, #8]\n");
    // endy + oy → [sp+12]
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r7, r6, r5\n");
    s.push_str("    str     r7, [sp, #12]\n");
    // steps=16 → [sp+16]
    s.push_str("    mov     r6, #16\n");
    s.push_str("    str     r6, [sp, #16]\n");
    // brightness → [sp+20]  (saved r10 at sp+48)
    s.push_str("    ldr     r6, [sp, #48]\n");
    s.push_str("    uxtb    r6, r6\n");
    s.push_str("    str     r6, [sp, #20]\n");
    // Update saved r9 so pop restores the advanced cursor
    s.push_str("    str     r9, [sp, #44]\n");
    s.push_str("    bl      v_drawBezierCubic\n");
    s.push_str("    add     sp, sp, #24\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10}\n");
    s.push_str("    b       dv_seg_loop\n");
    s.push_str("dv_done:\n");
    s.push_str("    add     sp, sp, #8          @ remove saved raw ox, oy\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n");
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
    //   * The beam is reset at the start of each path centred on (ox, oy).
    //   * If `mirror` (r7) == 1, all dx values are negated.
    //   * Per-path intensity is read from the .vec asset (same as the
    //     simple version). The [sp]=intensity caller arg is accepted for
    //     ABI compatibility but is not used.
    //
    // Register usage (callee-save):
    //   r4 = asset header cursor
    //   r5 = ox
    //   r6 = oy
    //   r7 = mirror flag
    //   r9 = path data cursor (per-path)
    //   r10 = per-path intensity (from .vec)
    let mut s = String::new();
    s.push_str("@ pitrex_draw_vector_ex(r0=asset_ptr, r1=ox, r2=oy, r3=mirror, [sp]=intensity_unused)\n");
    s.push_str(".global pitrex_draw_vector_ex\n.type pitrex_draw_vector_ex, %function\npitrex_draw_vector_ex:\n");
    // OPTIMIZED: Use r8=path_idx and r11=path_count in registers instead of stack.
    // Saves 2 push + 2 ldr + 1 str + 2 add_sp = 7+ memory operations per vector draw.
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}  @ 36 bytes\n");
    s.push_str("    mov     r4, r0              @ asset header ptr\n");
    s.push_str("    mov     r5, r1              @ ox\n");
    s.push_str("    mov     r6, r2              @ oy\n");
    s.push_str("    mov     r7, r3              @ mirror flag\n");
    s.push_str("    ldr     r11, [r4], #4       @ r11 = path_count\n");
    s.push_str("    mov     r8, #0              @ r8 = path_idx = 0\n");
    s.push_str("dvex_path_loop:\n");
    s.push_str("    cmp     r8, r11\n");
    s.push_str("    bge     dvex_done\n");
    s.push_str("    ldr     r9, [r4], #4        @ r9 = path data ptr\n");
    // Move beam to absolute path start using v_directMove32(x, y).
    // r5=ox, r6=oy, r7=mirror, r10=per-path intensity from .vec
    s.push_str("    ldrb    r10, [r9], #1       @ r10 = path intensity (from .vec)\n");
    // Check PITREX_BRIGHTNESS_OVERRIDE: non-zero means SET_INTENSITY was called
    s.push_str("    ldr     r0, =PITREX_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    ldrb    r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    movne   r10, r0             @ override from SET_INTENSITY\n");
    s.push_str("    ldrsb   r1, [r9], #1        @ r1 = y_start (i8)\n");
    s.push_str("    ldrsb   r0, [r9], #1        @ r0 = x_start (i8)\n");
    s.push_str("    add     r9, r9, #2          @ skip 2 hdr padding bytes\n");
    s.push_str("    cmp     r7, #1\n    it      eq\n    rsbeq   r0, r0, #0          @ mirror x_start\n");
    // target = (x_start + ox)*127, (y_start + oy)*127
    // Use r2/r3 as MUL temps to satisfy ARM32 Rd≠Rm constraint
    s.push_str("    mov     r12, #127\n");
    s.push_str("    mul     r2, r0, r12         @ r2 = x_start*127 (Rd=r2 ≠ Rm=r0)\n");
    s.push_str("    mul     r3, r5, r12         @ r3 = ox*127     (Rd=r3 ≠ Rm=r5)\n");
    s.push_str("    add     r0, r2, r3          @ r0 = (x_start+ox)*127\n");
    s.push_str("    mul     r2, r1, r12         @ r2 = y_start*127 (Rd=r2 ≠ Rm=r1)\n");
    s.push_str("    mul     r3, r6, r12         @ r3 = oy*127     (Rd=r3 ≠ Rm=r6)\n");
    s.push_str("    add     r1, r2, r3          @ r1 = (y_start+oy)*127\n");
    s.push_str("    ldr     r2, =PITREX_CUR_X\n");
    s.push_str("    str     r0, [r2]            @ PITREX_CUR_X = target_x\n");
    s.push_str("    ldr     r2, =PITREX_CUR_Y\n");
    s.push_str("    str     r1, [r2]            @ PITREX_CUR_Y = target_y\n");
    // ── UART trace: log target_x, target_y before v_directMove32 ──
    s.push_str("    push    {r0, r1}            @ save call args\n");
    s.push_str("    mov     r2, r1              @ trace y\n");
    s.push_str("    mov     r1, r0              @ trace x\n");
    s.push_str("    ldr     r0, =.Lstr_mv\n");
    s.push_str("    bl      uart_trace_xy\n");
    s.push_str("    pop     {r0, r1}\n");
    s.push_str("    bl      v_directMove32\n");
    // Restore calibrated T1=80 (v_directMove32 clobbers currentScale internally).
    s.push_str("    mov     r0, #80\n");
    s.push_str("    bl      v_setScale\n");
    s.push_str("dvex_seg_loop:\n");
    s.push_str("    ldrb    r0, [r9], #1\n");
    s.push_str("    cmp     r0, #2\n");
    s.push_str("    beq     dvex_seg_done\n");
    s.push_str("    cmp     r0, #0xFE\n");
    s.push_str("    beq     dvex_bezier_seg\n");
    s.push_str("    ldrsb   r1, [r9], #1        @ dy\n");
    s.push_str("    ldrsb   r0, [r9], #1        @ dx\n");
    s.push_str("    cmp     r7, #1\n    it      eq\n    rsbeq   r0, r0, #0\n");
    s.push_str("    mov     r2, r10             @ intensity from .vec\n");
    // OPTIMIZED: No push/pop needed — pitrex_draw_line_rel saves r4-r7 itself,
    // and does NOT modify r9, r10 (verified by inspection).
    // Removing push/pop saves 12 memory operations per segment.
    s.push_str("    bl      pitrex_draw_line_rel\n");
    s.push_str("    b       dvex_seg_loop\n");
    s.push_str("dvex_seg_done:\n");
    s.push_str("    add     r8, r8, #1          @ path_idx++\n");
    s.push_str("    b       dvex_path_loop\n");
    // ── 0xFE runtime-bezier handler (ex: supports mirror, r5=ox r6=oy r7=mirror) ──
    // dvex stores ox/oy as raw VPy units in r5, r6 (no pre-multiply).
    // Stack layout after  push {r4,r5,r6,r7,r9,r10} ; sub sp,#24:
    //   [sp+ 0..20] = 6 call args
    //   [sp+24]=r4  [sp+28]=r5(ox,raw)  [sp+32]=r6(oy,raw)  [sp+36]=r7(mirror)
    //   [sp+40]=r9(cursor)  [sp+44]=r10(intensity)
    // r8 (not in push list) and r12 used as scratch.
    s.push_str("dvex_bezier_seg:\n");
    s.push_str("    push    {r4, r5, r6, r7, r9, r10}\n");
    s.push_str("    sub     sp, sp, #24\n");
    // OPTIMIZED: Use LDMIA to load ox, oy, mirror in sequence (saves 1 instruction)
    s.push_str("    add     r0, sp, #28         @ r0 = &ox\n");
    s.push_str("    ldmia   r0, {r4, r5, r12}   @ r4=ox, r5=oy, r12=mirror (3 loads in 2 inst)\n");
    // x0 + ox → r0  (mirror x if needed)
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r0, r6, r4\n");
    s.push_str("    cmp     r12, #1\n    it      eq\n    rsbeq   r0, r0, #0\n");
    // y0 + oy → r1
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r1, r6, r5\n");
    // cp1x + ox → r2  (mirror)
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r2, r6, r4\n");
    s.push_str("    cmp     r12, #1\n    it      eq\n    rsbeq   r2, r2, #0\n");
    // cp1y + oy → r3
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r3, r6, r5\n");
    // cp2x + ox → [sp+0]  (mirror)
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r6, r6, r4\n");
    s.push_str("    cmp     r12, #1\n    it      eq\n    rsbeq   r6, r6, #0\n");
    s.push_str("    str     r6, [sp, #0]\n");
    // cp2y + oy → [sp+4]
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r6, r6, r5\n");
    s.push_str("    str     r6, [sp, #4]\n");
    // endx + ox → [sp+8]  (mirror)
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r6, r6, r4\n");
    s.push_str("    cmp     r12, #1\n    it      eq\n    rsbeq   r6, r6, #0\n");
    s.push_str("    str     r6, [sp, #8]\n");
    // endy + oy → [sp+12]
    s.push_str("    ldrsb   r6, [r9], #1\n");
    s.push_str("    add     r6, r6, r5\n");
    s.push_str("    str     r6, [sp, #12]\n");
    // steps=16 → [sp+16]
    s.push_str("    mov     r6, #16\n");
    s.push_str("    str     r6, [sp, #16]\n");
    // brightness → [sp+20]  (saved r10 at sp+44)
    s.push_str("    ldr     r6, [sp, #44]\n");
    s.push_str("    uxtb    r6, r6\n");
    s.push_str("    str     r6, [sp, #20]\n");
    // Update saved r9 with advanced cursor
    s.push_str("    str     r9, [sp, #40]\n");
    s.push_str("    bl      v_drawBezierCubic\n");
    s.push_str("    add     sp, sp, #24\n");
    s.push_str("    pop     {r4, r5, r6, r7, r9, r10}\n");
    s.push_str("    b       dvex_seg_loop\n");
    s.push_str("dvex_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Draw recording (.vrec "vector movie" playback) ─────────────────────────

fn emit_pitrex_draw_recording() -> String {
    // pitrex_draw_recording(r0=vrec_ptr, r1=x, r2=y, r3=scale 0-128, [sp]=frame)
    //
    // Plays one frame of a .vrec vector recording (multi-frame segment capture,
    // produced by tools/video2vrec). `frame` is a free-running counter — this
    // routine takes frame % frame_count internally so the caller just passes an
    // ever-increasing value. Ported from the rp2350 vpy_draw_recording (arm/
    // drawing.rs) but rewritten for the PiTrex SDK draw convention.
    //
    // Data layout (target-agnostic, emitted by compile_vrec in assets.rs):
    //   _<NAME>_VREC: .word frame_count
    //                 .word off0, off1, ...          @ byte offsets from base
    //   frame N:      .hword segment_count
    //                 per seg 5 bytes: x0,y0,x1,y1,intensity  (i8,i8,i8,i8,u8)
    //
    // Per segment we draw an ABSOLUTE endpoint-to-endpoint line via the SDK
    // v_directDraw32(x0,y0,x1,y1,bright). Each recorded i8 coord is treated as a
    // VPy DRAW_LINE coordinate: scale (0-128, 128=100%) is applied first as
    // (coord*scale)>>7 (asr, sign-preserved), then the x/y center is added, then
    // ×127 to reach PiTrex fixed-point units — EXACTLY matching pitrex_draw_line.
    //
    // CALIBRATION NOTE (TBD on hardware): the ×127 fixed-point factor mirrors
    // pitrex_draw_line/pitrex_draw_vector. The recorder maps a video frame into
    // ±127, so at scale=128 a full-screen recording spans ±127 VPy units → the
    // same physical deflection as a ±127 DRAW_LINE. The absolute on-screen SIZE
    // may still need per-display trimming on real PiTrex hardware; the ×127
    // assumption here is the documented convention, not a verified pixel match.
    // We deliberately do NOT add the PITREX_MOVE offset: DRAW_RECORDING carries
    // its own (x,y) center argument, just like DRAW_VECTOR.
    //
    // Register map:
    //   r4 = vrec base ptr        r8  = segment cursor
    //   r5 = x center (VPy)       r9  = segments remaining
    //   r6 = y center (VPy)       r10 = per-segment brightness
    //   r7 = scale (0-128)        r11 = 127 constant
    //   r12/r0-r3 = scratch / v_directDraw32 args
    // ARMv6 has no hardware divide → frame % frame_count via __aeabi_idivmod.
    // ARM32 mul Rd≠Rm constraint honoured: `mul rD, r7|r11, rM` keeps Rd out of
    // the first operand slot.
    let mut s = String::new();
    // coord(off, center_reg, target_reg):
    //   scaled = (i8[r8,#off] * scale) >> 7 ; then (scaled + center) * 127
    // Only r12 is used as scratch, so previously-computed args (r0..r3) survive.
    fn coord(s: &mut String, off: u8, center: &str, target: &str) {
        s.push_str(&format!("    ldrsb   r12, [r8, #{off}]   @ recorded coord (i8, sign-ext)\n"));
        s.push_str("    mul     r12, r7, r12        @ * scale        (Rd=r12 != Rm=r7)\n");
        s.push_str("    asr     r12, r12, #7        @ (coord*scale)>>7\n");
        s.push_str(&format!("    add     r12, r12, {center}       @ + center (VPy units)\n"));
        s.push_str(&format!("    mul     {target}, r11, r12      @ * 127  (Rd={target} != Rm=r11)\n"));
    }

    s.push_str("@ pitrex_draw_recording(r0=vrec_ptr, r1=x, r2=y, r3=scale 0-128, [sp]=frame)\n");
    s.push_str(".global pitrex_draw_recording\n.type pitrex_draw_recording, %function\npitrex_draw_recording:\n");
    // push 9 regs = 36 bytes → the frame stack arg is now at [sp+36].
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    mov     r4, r0              @ vrec base\n");
    s.push_str("    mov     r5, r1              @ x center\n");
    s.push_str("    mov     r6, r2              @ y center\n");
    s.push_str("    mov     r7, r3              @ scale (0-128, 128 = 100%)\n");
    s.push_str("    mov     r11, #127           @ VPy→PiTrex fixed-point factor\n");
    // frame_idx = frame % frame_count  (ARMv6: no sdiv → __aeabi_idivmod)
    s.push_str("    ldr     r2, [r4]            @ frame_count\n");
    s.push_str("    cmp     r2, #0\n");
    s.push_str("    beq     .Ldvrec_done        @ empty recording\n");
    s.push_str("    ldr     r0, [sp, #36]       @ frame counter (stack arg)\n");
    s.push_str("    mov     r1, r2              @ denominator = frame_count\n");
    s.push_str("    bl      __aeabi_idivmod     @ r1 = frame % frame_count\n");
    // frame ptr = base + offset_table[idx]  (table starts at base+4)
    s.push_str("    add     r1, r1, #1          @ skip frame_count word\n");
    s.push_str("    lsl     r1, r1, #2          @ (idx+1)*4 byte index\n");
    s.push_str("    ldr     r0, [r4, r1]        @ byte offset of frame from base\n");
    s.push_str("    add     r8, r4, r0          @ r8 = frame ptr\n");
    s.push_str("    ldrh    r9, [r8]            @ segment_count\n");
    s.push_str("    add     r8, r8, #2          @ r8 = first segment\n");

    s.push_str(".Ldvrec_seg:\n");
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    beq     .Ldvrec_done\n");
    // Per-segment brightness: recorded intensity, SET_INTENSITY override wins
    // (same PITREX_BRIGHTNESS_OVERRIDE rule as pitrex_draw_vector).
    s.push_str("    ldrb    r10, [r8, #4]       @ recorded intensity\n");
    s.push_str("    ldr     r0, =PITREX_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    ldrb    r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    movne   r10, r0             @ SET_INTENSITY override wins\n");
    // Compute absolute endpoints into r0..r3 (only r12 clobbered between them).
    coord(&mut s, 0, "r5", "r0");  // x0
    coord(&mut s, 1, "r6", "r1");  // y0
    coord(&mut s, 2, "r5", "r2");  // x1
    coord(&mut s, 3, "r6", "r3");  // y1
    s.push_str("    push    {r10}              @ brightness as 5th arg\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    add     r8, r8, #5          @ next segment (5 bytes)\n");
    s.push_str("    sub     r9, r9, #1\n");
    s.push_str("    b       .Ldvrec_seg\n");

    s.push_str(".Ldvrec_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
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
    // textSize from PITREX_TEXT_SIZE, default=8 (matches VPy SIZE=8 = m6809 normal).
    // Emulator maps textSize*5/14 → scale, so textSize=8 → scale=2.857 → 10 VPy/char
    // matching m6809 Vec_Text_Width=72 (default "normal").
    s.push_str("    ldr     r3, =PITREX_TEXT_SIZE\n");
    s.push_str("    ldr     r3, [r3]\n");
    s.push_str("    cmp     r3, #0\n    it eq\n    moveq   r3, #8\n");
    // y convention: VPy y = top of text. v_printString y = baseline. Subtract cap_height
    // FIRST (in VPy space), then apply the coordinate rescale below.
    s.push_str("    sub     r1, r1, #8          @ baseline = top - cap_height (VPy units)\n");
    // Coordinate rescale: draw funcs use VPy*127. v_printString uses x*128 internally.
    // Pre-scale by 127/128 so: x_passed * 128 = VPy * 127/128 * 128 = VPy * 127.
    s.push_str("    mov     r12, #127\n");
    s.push_str("    mul     r0, r0, r12          @ r0  = x*127\n");
    s.push_str("    asr     r0, r0, #7           @ r0  = x*127/128 (sign-preserving)\n");
    s.push_str("    mul     r1, r1, r12          @ r1  = y*127\n");
    s.push_str("    asr     r1, r1, #7           @ r1  = y*127/128 (sign-preserving)\n");
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
    // Scale by 127 (VPy → pitrex, matches rp2350 T1=127)
    s.push_str("    mov     r0, #127\n");
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
    // OPTIMIZED: Uses precomputed PITREX_CIRCLE_TABLE (17 vertices × 2 coords = 136 bytes)
    // with LDMIA (load multiple) to avoid per-segment mov/ldr/mul/asr overhead.
    // Speedup: ~5-8% per circle draw (320+ instructions → ~80 instructions).
    let mut s = String::new();
    s.push_str("@ pitrex_draw_circle(r0=cx, r1=cy, r2=diameter, r3=brightness)\n");
    s.push_str(".global pitrex_draw_circle\n.type pitrex_draw_circle, %function\npitrex_draw_circle:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    mov     r4, r0          @ cx\n");
    s.push_str("    mov     r5, r1          @ cy\n");
    s.push_str("    asr     r6, r2, #1      @ radius = diameter/2\n");
    s.push_str("    mov     r7, r3          @ brightness\n");
    // Scale center and radius by 127
    s.push_str("    mov     r0, #127\n");
    s.push_str("    mul     r4, r4, r0      @ cx_s\n");
    s.push_str("    mul     r5, r5, r0      @ cy_s\n");
    s.push_str("    mul     r6, r6, r0      @ radius_s\n");
    // Load circle table base pointer
    s.push_str("    ldr     r11, =PITREX_CIRCLE_TABLE\n");
    // Loop through 16 segments (each segment connects vertex i to i+1)
    s.push_str("    mov     r10, #0         @ segment index\n");
    s.push_str(".Lcircle_loop:\n");
    s.push_str("    cmp     r10, #16\n");
    s.push_str("    bge     .Lcircle_done\n");
    // Load vertex i: (x0, y0) from table at offset r10*8
    s.push_str("    lsl     r0, r10, #3     @ offset = i * 8 (2 words per vertex)\n");
    s.push_str("    add     r0, r11, r0\n");
    s.push_str("    ldmia   r0!, {r8, r9}   @ r8=x0_raw, r9=y0_raw (from table)\n");
    // Load vertex i+1: (x1, y1)
    s.push_str("    ldmia   r0, {r0, r1}    @ r0=x1_raw, r1=y1_raw\n");
    // Scale and offset: x = (raw * radius) >> 10 + cx_s
    // r8, r9, r0, r1 are signed values from table (e.g., -1024..1024)
    // ARM mul handles signed × signed correctly, asr is arithmetic shift (preserves sign)
    s.push_str("    mul     r8, r8, r6\n");
    s.push_str("    asr     r8, r8, #10\n");
    s.push_str("    add     r8, r8, r4      @ x0 = (x0_raw*r)>>10 + cx\n");
    s.push_str("    mul     r9, r9, r6\n");
    s.push_str("    asr     r9, r9, #10\n");
    s.push_str("    add     r9, r9, r5      @ y0\n");
    s.push_str("    mul     r0, r0, r6\n");
    s.push_str("    asr     r0, r0, #10\n");
    s.push_str("    add     r0, r0, r4      @ x1\n");
    s.push_str("    mul     r1, r1, r6\n");
    s.push_str("    asr     r1, r1, #10\n");
    s.push_str("    add     r1, r1, r5      @ y1\n");
    // Prepare args for v_directDraw32(x0, y0, x1, y1, brightness)
    s.push_str("    mov     r2, r0          @ x1 → r2\n");
    s.push_str("    mov     r3, r1          @ y1 → r3\n");
    s.push_str("    mov     r0, r8          @ x0 → r0\n");
    s.push_str("    mov     r1, r9          @ y0 → r1\n");
    s.push_str("    push    {r7}            @ brightness as 5th arg\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    add     r10, r10, #1    @ i++\n");
    s.push_str("    b       .Lcircle_loop\n");
    s.push_str(".Lcircle_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
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
    // scale coords by 127
    s.push_str("    mov     r9, #127\n");
    s.push_str("    mul     r4, r4, r9      @ x_s\n");
    s.push_str("    mul     r5, r5, r9      @ y_s (bottom)\n");
    s.push_str("    mul     r6, r6, r9      @ w_s\n");
    s.push_str("    mul     r7, r7, r9      @ h_s\n");
    // scan step = 3 VPy units (× 127 = 381)
    s.push_str("    add     r9, r9, r9, lsl #1   @ scan step = 3 * 127 = 381\n");
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
    s.push_str("    mov     r5, #127        @ scale\n");
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
    // OPTIMIZED: Uses precomputed PITREX_CIRCLE_TABLE with LDMIA.
    // For ellipses: x coords scaled by rx, y coords scaled by ry.
    // Speedup: ~5-8% per ellipse draw (400+ instructions → ~100 instructions).
    let mut s = String::new();
    s.push_str("@ pitrex_draw_ellipse(r0=cx, r1=cy, r2=rx, r3=ry, [sp+0]=brightness)\n");
    s.push_str(".global pitrex_draw_ellipse\n.type pitrex_draw_ellipse, %function\npitrex_draw_ellipse:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    mov     r4, r0          @ cx\n");
    s.push_str("    mov     r5, r1          @ cy\n");
    s.push_str("    mov     r6, r2          @ rx\n");
    s.push_str("    mov     r7, r3          @ ry\n");
    s.push_str("    ldr     r8, [sp, #36]   @ brightness ([sp+9regs*4])\n");
    // Scale center and radii by 127
    s.push_str("    mov     r9, #127\n");
    s.push_str("    mul     r4, r4, r9      @ cx_s\n");
    s.push_str("    mul     r5, r5, r9      @ cy_s\n");
    s.push_str("    mul     r6, r6, r9      @ rx_s\n");
    s.push_str("    mul     r7, r7, r9      @ ry_s\n");
    // Load circle table base
    s.push_str("    ldr     r11, =PITREX_CIRCLE_TABLE\n");
    s.push_str("    mov     r10, #0         @ segment index\n");
    s.push_str(".Lellipse_loop:\n");
    s.push_str("    cmp     r10, #16\n");
    s.push_str("    bge     .Lellipse_done\n");
    // Load vertex i: (x0_raw, y0_raw)
    s.push_str("    lsl     r0, r10, #3\n");
    s.push_str("    add     r0, r11, r0\n");
    s.push_str("    ldmia   r0!, {r9, r1}   @ r9=x0_raw, r1=y0_raw\n");
    // Load vertex i+1: (x1_raw, y1_raw)
    s.push_str("    ldmia   r0, {r2, r3}    @ r2=x1_raw, r3=y1_raw\n");
    // x coords use rx (r6), y coords use ry (r7)
    s.push_str("    mul     r9, r9, r6      @ x0 = x0_raw * rx\n");
    s.push_str("    asr     r9, r9, #10\n");
    s.push_str("    add     r9, r9, r4      @ x0 += cx\n");
    s.push_str("    mul     r1, r1, r7      @ y0 = y0_raw * ry\n");
    s.push_str("    asr     r1, r1, #10\n");
    s.push_str("    add     r1, r1, r5      @ y0 += cy\n");
    s.push_str("    mul     r2, r2, r6      @ x1\n");
    s.push_str("    asr     r2, r2, #10\n");
    s.push_str("    add     r2, r2, r4\n");
    s.push_str("    mul     r3, r3, r7      @ y1\n");
    s.push_str("    asr     r3, r3, #10\n");
    s.push_str("    add     r3, r3, r5\n");
    // Prepare args: v_directDraw32(x0, y0, x1, y1, brightness)
    s.push_str("    mov     r0, r9\n");
    s.push_str("    push    {r8}            @ brightness\n");
    s.push_str("    bl      v_directDraw32\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    add     r10, r10, #1\n");
    s.push_str("    b       .Lellipse_loop\n");
    s.push_str(".Lellipse_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
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
    // scale by 127 (VPy → pitrex, matches rp2350 T1=127)
    s.push_str("    mov     r0, #127\n");
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
    // pitrex_debug_print(r0=value) — sends integer to UART
    s.push_str("@ pitrex_debug_print(r0=value)\n");
    s.push_str(".global pitrex_debug_print\n.type pitrex_debug_print, %function\npitrex_debug_print:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    bl      vpy_uart_print_int\n");
    s.push_str("    mov     r0, #13\n");
    s.push_str("    bl      RPI_AuxUartWrite\n");
    s.push_str("    mov     r0, #10\n");
    s.push_str("    bl      RPI_AuxUartWrite\n");
    s.push_str("    pop     {pc}\n\n");
    s.push_str("@ pitrex_debug_print_labeled(r0=label_ptr, r1=value) — UART: label=value\n");
    s.push_str(".global pitrex_debug_print_labeled\n.type pitrex_debug_print_labeled, %function\npitrex_debug_print_labeled:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    mov     r4, r0          @ save label_ptr\n");
    s.push_str("    mov     r5, r1          @ save value\n");
    s.push_str("    mov     r0, r4\n");
    s.push_str("    bl      vpy_uart_print_int @ print label as int\n");
    s.push_str("    mov     r0, #61         @ '='\n");
    s.push_str("    bl      RPI_AuxUartWrite\n");
    s.push_str("    mov     r0, r5\n");
    s.push_str("    bl      vpy_uart_print_int @ print value\n");
    s.push_str("    mov     r0, #13         @ CR\n");
    s.push_str("    bl      RPI_AuxUartWrite\n");
    s.push_str("    mov     r0, #10         @ LF\n");
    s.push_str("    bl      RPI_AuxUartWrite\n");
    s.push_str("    pop     {r4, r5, pc}\n\n");
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
    // For objects with coll_mesh_ptr != 0: ray-casts against horizontal segments (local coords).
    //   Mesh format: .word seg_count; .hword x1,y1,x2,y2 per segment.
    //   Non-horizontal segments (y1 != y2) are skipped.
    // For objects without a mesh (coll_mesh_ptr == 0): AABB fallback (world_y + half_h).
    // Returns best_floor_top + player_hh. Returns -200 if no floor found.
    //
    // LEVEL_GP_BUF layout (8 bytes/entry): x i16 @0, y i16 @2, vx i16 @4, vy i16 @6
    // ROM object layout (20 bytes): @0 x, @2 y, @4 scale, @5 intensity, @6 flags, @7 type,
    //   @8 vector_ptr, @12 half_w, @13 half_h, @14 vel_x, @15 vel_y, @16 coll_mesh_ptr
    //
    // Registers:
    //   r4=px  r5=player_feet  r6=player_hh  r7=buf_ptr  r8=count  r9=rom_ptr
    //   r10=best_floor_top  r11=mesh_ptr (inner)  r12=seg_count (inner)  r14=scratch
    s.push_str("@ pitrex_level_collision_y(r0=px, r1=py, r2=hh) -> floor_center_y\n");
    s.push_str(".global pitrex_level_collision_y\n.type pitrex_level_collision_y, %function\npitrex_level_collision_y:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    mov     r4, r0              @ px\n");
    s.push_str("    mov     r6, r2              @ player_hh\n");
    s.push_str("    sub     r5, r1, r2          @ r5 = player_feet = py - hh\n");
    s.push_str("    ldr     r7, =LEVEL_DATA_PTR\n    ldr     r7, [r7]\n");
    s.push_str("    cmp     r7, #0\n    beq     plcy_no_floor\n");
    s.push_str("    ldr     r8, =LEVEL_GP_COUNT\n    ldr     r8, [r8]\n");
    s.push_str("    cmp     r8, #0\n    beq     plcy_no_floor\n");
    s.push_str("    ldr     r9, [r7, #16]       @ r9 = gpObjectsPtr (ROM)\n");
    s.push_str("    ldr     r7, =LEVEL_GP_BUF\n");
    s.push_str("    ldr     r10, =-32767        @ best_floor_top sentinel\n");
    s.push_str("plcy_loop:\n    cmp     r8, #0\n    beq     plcy_finish\n");
    // collidable flag (ROM[6] bit4)
    s.push_str("    ldrb    r0, [r9, #6]\n    tst     r0, #0x10\n    beq     plcy_next\n");
    // x broadphase: |px - obj_x| <= half_w
    s.push_str("    ldrb    r1, [r9, #12]       @ half_w\n");
    s.push_str("    ldrsh   r2, [r7, #0]        @ obj world_x (buf)\n");
    s.push_str("    sub     r0, r4, r2          @ dx = px - obj_x\n");
    s.push_str("    movs    r3, r0\n    bpl     plcy_xabs\n    neg     r3, r0\n");
    s.push_str("plcy_xabs:\n    cmp     r3, r1\n    bgt     plcy_next\n");
    // check mesh ptr (ROM obj +16)
    s.push_str("    ldr     r11, [r9, #16]      @ coll_mesh_ptr\n");
    s.push_str("    cmp     r11, #0\n    beq     plcy_aabb\n");
    // ---- segment mesh ray-cast ----
    // push local_px and obj_world_y for use in inner loop
    s.push_str("    ldrsh   r0, [r7, #0]        @ obj_world_x\n");
    s.push_str("    sub     r0, r4, r0          @ local_px = px - obj_world_x\n");
    s.push_str("    ldrsh   r1, [r7, #2]        @ obj_world_y\n");
    s.push_str("    push    {r0, r1}            @ [sp]=local_px  [sp+4]=obj_world_y\n");
    s.push_str("    ldr     r12, [r11], #4      @ seg_count; r11 now → first segment\n");
    s.push_str("plcy_seg_loop:\n    cmp     r12, #0\n    beq     plcy_seg_done\n");
    s.push_str("    ldrsh   r0, [r11]           @ x1\n");
    s.push_str("    ldrsh   r1, [r11, #2]       @ y1\n");
    s.push_str("    ldrsh   r2, [r11, #4]       @ x2\n");
    s.push_str("    ldrsh   r3, [r11, #6]       @ y2\n");
    s.push_str("    add     r11, r11, #8\n    subs    r12, r12, #1\n");
    s.push_str("    cmp     r1, r3\n    bne     plcy_seg_loop    @ skip non-horizontal (y1!=y2)\n");
    s.push_str("    ldr     r14, [sp]           @ local_px\n");
    // x-range check
    s.push_str("    cmp     r0, r2              @ x1 vs x2\n");
    s.push_str("    blt     plcy_seg_x1lt\n");
    s.push_str("    @ x1 >= x2: valid range [x2, x1]\n");
    s.push_str("    cmp     r14, r2\n    blt     plcy_seg_loop\n");
    s.push_str("    cmp     r14, r0\n    bgt     plcy_seg_loop\n");
    s.push_str("    b       plcy_seg_y\n");
    s.push_str("plcy_seg_x1lt:\n");
    s.push_str("    @ x1 < x2: valid range [x1, x2]\n");
    s.push_str("    cmp     r14, r0\n    blt     plcy_seg_loop\n");
    s.push_str("    cmp     r14, r2\n    bgt     plcy_seg_loop\n");
    s.push_str("plcy_seg_y:\n");
    s.push_str("    ldr     r14, [sp, #4]       @ obj_world_y\n");
    s.push_str("    add     r3, r1, r14         @ world_seg_y = y1(local) + obj_world_y\n");
    s.push_str("    cmp     r3, r5\n    bgt     plcy_seg_loop    @ above player_feet: skip\n");
    s.push_str("    cmp     r3, r10\n    ble     plcy_seg_loop    @ not better: skip\n");
    s.push_str("    mov     r10, r3\n    b       plcy_seg_loop\n");
    s.push_str("plcy_seg_done:\n    pop     {r0, r1}            @ restore stack balance\n");
    s.push_str("    b       plcy_next\n");
    // AABB fallback
    s.push_str("plcy_aabb:\n");
    s.push_str("    ldrsh   r2, [r7, #2]        @ obj world_y (buf)\n");
    s.push_str("    ldrb    r3, [r9, #13]       @ half_h\n");
    s.push_str("    add     r2, r2, r3          @ obj_top = world_y + half_h\n");
    s.push_str("    add     r3, r5, r6          @ r3 = player_center = player_feet + player_hh\n");
    s.push_str("    cmp     r2, r3\n    bgt     plcy_next   @ above player center: skip\n");
    s.push_str("    cmp     r2, r10\n    ble     plcy_next\n    mov     r10, r2\n");
    // advance to next object
    s.push_str("plcy_next:\n    add     r7, r7, #8\n    add     r9, r9, #20         @ ROM obj stride = 20 bytes\n");
    s.push_str("    subs    r8, r8, #1\n    b       plcy_loop\n");
    s.push_str("plcy_finish:\n");
    s.push_str("    ldr     r1, =-32767\n    cmp     r10, r1\n    beq     plcy_no_floor\n");
    s.push_str("    add     r0, r10, r6         @ floor_center = floor_top + player_hh\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("plcy_no_floor:\n");
    s.push_str("    ldr     r0, =-10000  @ sentinel: below any valid screen_bottom so VPy fallback triggers\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
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
    // if mesh present, use wall section; otherwise fall through to AABB
    s.push_str("    ldr     r0, [r9, #16]       @ coll_mesh_ptr\n");
    s.push_str("    cmp     r0, #0\n    bne     plcx_wall_mesh\n");
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
    s.push_str("plcx_next:\n    add     r7, r7, #8\n    add     r9, r9, #20         @ ROM obj stride = 20 bytes\n");
    s.push_str("    subs    r8, r8, #1\n    b       plcx_loop\n");
    // wall mesh path: skip floor section, iterate vertical segments
    s.push_str("plcx_wall_mesh:\n");
    s.push_str("    ldr     r1, [r0]            @ floor_count\n");
    s.push_str("    add     r0, r0, #4          @ skip floor_count word\n");
    s.push_str("    lsl     r1, r1, #3          @ floor_count * 8 bytes per seg\n");
    s.push_str("    add     r0, r0, r1          @ r0 = ptr to wall_count\n");
    s.push_str("    ldr     r1, [r0]            @ wall_count\n");
    s.push_str("    cmp     r1, #0\n    beq     plcx_next\n");
    s.push_str("    add     r0, r0, #4          @ r0 = ptr to first wall seg\n");
    s.push_str("plcx_wall_loop:\n");
    s.push_str("    cmp     r1, #0\n    beq     plcx_next\n");
    // load segment: .hword x, y_min, x, y_max (offsets 0,2,4,6)
    s.push_str("    ldrsh   r2, [r0]            @ wall local x\n");
    s.push_str("    ldrsh   r3, [r0, #2]        @ wall local y_min\n");
    s.push_str("    ldrsh   r12, [r0, #6]       @ wall local y_max\n");
    s.push_str("    add     r0, r0, #8\n");
    s.push_str("    subs    r1, r1, #1\n");
    // world coords
    s.push_str("    ldrsh   r14, [r7, #0]       @ obj world_x\n");
    s.push_str("    add     r2, r2, r14         @ world_wall_x\n");
    s.push_str("    ldrsh   r14, [r7, #2]       @ obj world_y\n");
    s.push_str("    add     r3, r3, r14         @ world_y_min\n");
    s.push_str("    add     r12, r12, r14       @ world_y_max\n");
    // Y-overlap (strict): py - player_hh < y_max AND py + player_hh > y_min
    // Using strict inequalities so a player whose feet are exactly at y_max
    // (standing on top of the wall's upper edge) is NOT blocked horizontally.
    s.push_str("    sub     r14, r3, r11        @ world_y_min - player_hh\n");
    s.push_str("    cmp     r5, r14\n    ble     plcx_wall_loop  @ py + hh <= y_min: below wall\n");
    s.push_str("    add     r14, r12, r11       @ world_y_max + player_hh\n");
    s.push_str("    cmp     r5, r14\n    bge     plcx_wall_loop  @ py - hh >= y_max: above wall\n");
    // X-overlap: |px - wall_x| < player_hw; compute dx_raw and abs
    s.push_str("    sub     r3, r4, r2          @ dx_raw = px - wall_x\n");
    s.push_str("    movs    r2, r3              @ r2 = dx_raw (sign preserved); also sets N flag\n");
    s.push_str("    bpl     plcx_wall_dx_ok\n    neg     r3, r3  @ r3 = |dx_raw|\n");
    s.push_str("plcx_wall_dx_ok:\n");
    s.push_str("    cmp     r3, r6\n    bge     plcx_wall_loop  @ |dx| >= player_hw, no overlap\n");
    // push-out = sign(dx_raw) * (player_hw - |dx|)
    s.push_str("    sub     r3, r6, r3          @ overlap = player_hw - |dx|\n");
    s.push_str("    cmp     r2, #0\n    bge     plcx_wall_sign_ok\n    neg     r3, r3\n");
    s.push_str("plcx_wall_sign_ok:\n    mov     r10, r3\n    b       plcx_next\n");
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
    s.push_str("@ Guard: if same music is already playing, do nothing (prevents per-frame restart).\n");
    s.push_str(".global pitrex_play_music\n.type pitrex_play_music, %function\npitrex_play_music:\n");
    s.push_str("    ldr     r1, =PSG_IS_PLAYING\n    ldr     r2, [r1]\n");
    s.push_str("    cmp     r2, #0\n    beq     .Lppm_start      @ not playing -> always start\n");
    s.push_str("    ldr     r1, =PSG_MUSIC_START\n    ldr     r2, [r1]\n");
    s.push_str("    cmp     r2, r0\n    bxeq    lr               @ same music already playing -> skip\n");
    s.push_str(".Lppm_start:\n");
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
    // Tempo-stable sequencer using BCM CLO real-time timer.
    // Accumulates elapsed µs into PSG_MUSIC_TICK_US; fires 50Hz ticks (20000µs each).
    // Loops inside the call to catch up when frames are slower than 50Hz.
    // Cap: max 60000µs accumulated = 3 ticks catchup per call.
    //
    // Register use:
    //   r4 = CLO now (at entry), then PSG_DELAY_FRAMES ptr (in tick loop)
    //   r5 = PSG_MUSIC_LAST_CLO ptr (at entry), then event ptr (in pmu_process)
    //   r6 = delta_us (at entry), then 20000 constant / num_writes (in loops)
    //   r7 = PSG_MUSIC_TICK_US ptr (in tick loop) — reloaded after pmu_after/pmu_loop
    s.push_str("@ pitrex_music_update() — BCM-CLO tempo-stable sequencer\n");
    s.push_str(".global pitrex_music_update\n.type pitrex_music_update, %function\npitrex_music_update:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    ldr     r0, =PSG_IS_PLAYING\n    ldr     r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n    beq     pmu_done\n");
    // Read CLO
    s.push_str("    ldr     r4, =bcm2835_st\n    ldr     r4, [r4]\n");
    s.push_str("    ldr     r4, [r4, #4]        @ r4 = CLO now\n");
    // Compute and accumulate delta
    s.push_str("    ldr     r5, =PSG_MUSIC_LAST_CLO\n");
    s.push_str("    ldr     r6, [r5]            @ r6 = last CLO (0 if not yet init)\n");
    s.push_str("    cmp     r6, #0\n    beq     pmu_init_clo\n");
    s.push_str("    sub     r6, r4, r6          @ delta_us (wraps correctly)\n");
    s.push_str("    ldr     r7, =PSG_MUSIC_TICK_US\n");
    s.push_str("    ldr     r0, [r7]\n    add     r0, r0, r6\n");
    // Cap at 60000µs (3 ticks) to prevent runaway catchup after pauses
    s.push_str("    ldr     r6, =60000\n    cmp     r0, r6\n");
    s.push_str("    movgt   r0, r6              @ cap\n");
    s.push_str("    str     r0, [r7]\n");
    s.push_str("    b       pmu_save_clo\n");
    s.push_str("pmu_init_clo:\n");
    s.push_str("    ldr     r7, =PSG_MUSIC_TICK_US\n    mov     r0, #0\n    str     r0, [r7]\n");
    s.push_str("pmu_save_clo:\n");
    s.push_str("    str     r4, [r5]            @ PSG_MUSIC_LAST_CLO = now\n");
    // Tick loop: fire one sequencer tick per 20000µs accumulated
    s.push_str("pmu_tick_loop:\n");
    s.push_str("    ldr     r0, [r7]            @ PSG_MUSIC_TICK_US\n");
    s.push_str("    ldr     r6, =20000\n    cmp     r0, r6\n");
    s.push_str("    blt     pmu_done            @ < 20ms accumulated, nothing to fire\n");
    s.push_str("    sub     r0, r0, r6\n    str     r0, [r7]  @ consume one tick\n");
    // Advance sequencer by one tick
    s.push_str("    ldr     r4, =PSG_DELAY_FRAMES\n    ldr     r0, [r4]\n");
    s.push_str("    cmp     r0, #0\n    beq     pmu_process\n");
    s.push_str("    sub     r0, r0, #1\n    str     r0, [r4]\n    b       pmu_tick_loop\n");
    // Fire a sequencer event
    s.push_str("pmu_process:\n");
    s.push_str("    ldr     r5, =PSG_MUSIC_PTR\n    ldr     r5, [r5]    @ event ptr\n");
    s.push_str("    ldrb    r6, [r5, #1]        @ num_writes\n");
    s.push_str("    cmp     r6, #0\n    beq     pmu_end\n");
    s.push_str("    cmp     r6, #0xFF\n    beq     pmu_loop\n");
    s.push_str("    add     r7, r5, #2          @ r7 = write pairs (overrides tick_us ptr)\n");
    s.push_str("pmu_wl:\n");
    s.push_str("    cmp     r6, #0\n    beq     pmu_after\n");
    s.push_str("    ldrb    r0, [r7]\n    ldrb    r1, [r7, #1]\n");
    s.push_str("    push    {r6, r7}\n    bl      v_writePSG\n    pop     {r6, r7}\n");
    s.push_str("    add     r7, r7, #2\n    sub     r6, r6, #1\n    b       pmu_wl\n");
    s.push_str("pmu_after:\n");
    s.push_str("    ldr     r0, =PSG_MUSIC_PTR\n    str     r7, [r0]\n");
    s.push_str("    ldr     r4, =PSG_DELAY_FRAMES\n");
    s.push_str("    ldrb    r0, [r7]            @ next event delay\n    str     r0, [r4]\n");
    s.push_str("    ldr     r7, =PSG_MUSIC_TICK_US  @ reload for next tick_loop\n");
    s.push_str("    b       pmu_tick_loop\n");
    s.push_str("pmu_end:\n    bl      pitrex_stop_music\n    b       pmu_done\n");
    s.push_str("pmu_loop:\n");
    s.push_str("    ldr     r0, =PSG_MUSIC_START\n    ldr     r0, [r0]\n");
    s.push_str("    ldr     r1, [r0, #4]        @ loop_event_byte_offset\n");
    s.push_str("    add     r1, r0, r1\n");
    s.push_str("    ldr     r0, =PSG_MUSIC_PTR\n    str     r1, [r0]\n");
    s.push_str("    ldr     r4, =PSG_DELAY_FRAMES\n");
    s.push_str("    ldrb    r0, [r1]\n    str     r0, [r4]\n");
    s.push_str("    ldr     r7, =PSG_MUSIC_TICK_US  @ reload for next tick_loop\n");
    s.push_str("    b       pmu_tick_loop\n");
    s.push_str("pmu_done:\n    pop     {r4, r5, r6, r7, pc}\n    .ltorg\n\n");

    // ── pitrex_play_sfx
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
    // Read and store GP count (byte offset 9), natural u8 max = 255
    s.push_str("    ldrb    r5, [r4, #9]        @ r5 = gpCount (no cap: 255 max)\n");
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
    s.push_str("    add     r6, r6, #20         @ advance ROM obj ptr (20 bytes)\n");
    s.push_str("    add     r7, r7, #8          @ advance buf ptr\n");
    s.push_str("    subs    r5, r5, #1\n");
    s.push_str("    bne     .Lll_copy\n");
    s.push_str(".Lll_done:\n");
    // Read scroll limits from header (+24..+31)
    s.push_str("    ldrsh   r0, [r4, #24]       @ scrollLimit left\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_LEFT\n    str     r0, [r1]\n");
    s.push_str("    ldrsh   r0, [r4, #26]       @ scrollLimit right\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_RIGHT\n    str     r0, [r1]\n");
    s.push_str("    ldrsh   r0, [r4, #28]       @ scrollLimit top\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_TOP\n    str     r0, [r1]\n");
    s.push_str("    ldrsh   r0, [r4, #30]       @ scrollLimit bottom\n");
    s.push_str("    ldr     r1, =SCROLL_LIMIT_BOTTOM\n    str     r0, [r1]\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");

    // pitrex_show_level() — draw all layer objects with camera offset
    // Draws BG (ROM positions) + GP (LEVEL_GP_BUF positions) + FG (ROM positions).
    // Each object drawn via pitrex_draw_vector_ex(asset_ptr, ox, oy, mirror=0, intensity).
    s.push_str("@ pitrex_show_level() — draw all level objects (BG+GP+FG)\n");
    s.push_str(".global pitrex_show_level\n.type pitrex_show_level, %function\npitrex_show_level:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    // Save and clear PITREX_BRIGHTNESS_OVERRIDE so level objects use their .vec intensities.
    // SET_INTENSITY() sets this global; if left non-zero it would override all .vec path
    // intensities and show everything at the same brightness (e.g. always 127).
    // 36 bytes already pushed (9 regs). sub sp,#4 → total 40 (8-aligned). Saved at [sp].
    s.push_str("    sub     sp, sp, #4\n");
    s.push_str("    ldr     r0, =PITREX_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    ldrb    r1, [r0]\n");
    s.push_str("    str     r1, [sp]            @ save PITREX_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    strb    r1, [r0]            @ clear override → use .vec per-path intensities\n");
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
    s.push_str("    @ Cull: skip if |ox| > 180 or |oy| > 140 (off-screen, 13-unit buffer past ±127 screen edge)\n");
    s.push_str("    mov     r12, r0\n");
    s.push_str("    cmp     r12, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r12, r12, #0        @ r12 = |ox|\n");
    s.push_str("    cmp     r12, #180\n");
    s.push_str("    bgt     .Lshl_bg_skip\n");
    s.push_str("    mov     r12, r1\n");
    s.push_str("    cmp     r12, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r12, r12, #0        @ r12 = |oy|\n");
    s.push_str("    cmp     r12, #140\n");
    s.push_str("    bgt     .Lshl_bg_skip\n");
    s.push_str("    push    {r4, r5, r10, r11}  @ save loop state\n");
    s.push_str("    push    {r8}                @ 5th arg: intensity\n");
    s.push_str("    mov     r3, #0              @ mirror=0\n");
    s.push_str("    mov     r2, r1              @ oy\n");
    s.push_str("    mov     r1, r0              @ ox\n");
    s.push_str("    mov     r0, r6              @ asset_ptr\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4          @ pop intensity\n");
    s.push_str("    pop     {r4, r5, r10, r11}\n");
    s.push_str(".Lshl_bg_skip:\n");
    s.push_str("    add     r5, r5, #20         @ next BG object (20 bytes)\n");
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
    s.push_str("    ldrb    r12, [r5, #7]       @ obj type (1=enemy)\n");
    s.push_str("    cmp     r12, #1\n");
    s.push_str("    beq     .Lshl_gp_skip       @ enemies drawn by DRAW_ENEMIES\n");
    s.push_str("    ldrsh   r0, [r7]            @ buf.x\n");
    s.push_str("    ldrsh   r1, [r7, #2]        @ buf.y\n");
    s.push_str("    ldrb    r8, [r5, #5]        @ intensity (from ROM obj)\n");
    s.push_str("    ldr     r6, [r5, #8]        @ vector_ptr (from ROM obj)\n");
    s.push_str("    sub     r0, r0, r10         @ ox = x - cam_x\n");
    s.push_str("    sub     r1, r1, r11         @ oy = y - cam_y\n");
    s.push_str("    @ Cull: skip if |ox| > 180 or |oy| > 140 (off-screen, 13-unit buffer past ±127 screen edge)\n");
    s.push_str("    mov     r12, r0\n");
    s.push_str("    cmp     r12, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r12, r12, #0        @ r12 = |ox|\n");
    s.push_str("    cmp     r12, #180\n");
    s.push_str("    bgt     .Lshl_gp_skip\n");
    s.push_str("    mov     r12, r1\n");
    s.push_str("    cmp     r12, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r12, r12, #0        @ r12 = |oy|\n");
    s.push_str("    cmp     r12, #140\n");
    s.push_str("    bgt     .Lshl_gp_skip\n");
    s.push_str("    push    {r4, r5, r7, r10, r11}  @ save loop state\n");
    s.push_str("    push    {r8}                @ 5th arg: intensity\n");
    s.push_str("    mov     r3, #0              @ mirror=0\n");
    s.push_str("    mov     r2, r1              @ oy\n");
    s.push_str("    mov     r1, r0              @ ox\n");
    s.push_str("    mov     r0, r6              @ asset_ptr\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4          @ pop intensity\n");
    s.push_str("    pop     {r4, r5, r7, r10, r11}\n");
    s.push_str(".Lshl_gp_skip:\n");
    s.push_str("    add     r5, r5, #20         @ next ROM GP object (20 bytes)\n");
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
    s.push_str("    @ Cull: skip if |ox| > 180 or |oy| > 140 (off-screen, 13-unit buffer past ±127 screen edge)\n");
    s.push_str("    mov     r12, r0\n");
    s.push_str("    cmp     r12, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r12, r12, #0        @ r12 = |ox|\n");
    s.push_str("    cmp     r12, #180\n");
    s.push_str("    bgt     .Lshl_fg_skip\n");
    s.push_str("    mov     r12, r1\n");
    s.push_str("    cmp     r12, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r12, r12, #0        @ r12 = |oy|\n");
    s.push_str("    cmp     r12, #140\n");
    s.push_str("    bgt     .Lshl_fg_skip\n");
    s.push_str("    push    {r4, r5, r10, r11}  @ save loop state\n");
    s.push_str("    push    {r8}                @ 5th arg: intensity\n");
    s.push_str("    mov     r3, #0              @ mirror=0\n");
    s.push_str("    mov     r2, r1              @ oy\n");
    s.push_str("    mov     r1, r0              @ ox\n");
    s.push_str("    mov     r0, r6              @ asset_ptr\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4          @ pop intensity\n");
    s.push_str("    pop     {r4, r5, r10, r11}\n");
    s.push_str(".Lshl_fg_skip:\n");
    s.push_str("    add     r5, r5, #20         @ next FG object (20 bytes)\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     .Lshl_fg_loop\n");

    s.push_str(".Lshl_done:\n");
    // Restore PITREX_BRIGHTNESS_OVERRIDE and clean up the saved word from stack
    s.push_str("    ldr     r0, [sp]            @ restore saved PITREX_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    ldr     r1, =PITREX_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    strb    r0, [r1]\n");
    s.push_str("    add     sp, sp, #4          @ pop saved override word\n");
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
    // Mixer reg 7: read-modify-write so SFX only affects channel C bits.
    // Without this, SFX writes 0x3B/0x1B (bits 0,1 set = tones A/B disabled)
    // and silences any music playing on A/B. CHANNEL_C_MASK = 0x24 (bit2=toneC,
    // bit5=noiseC); music's bits 0/1/3/4 come from the current PSG mixer state.
    s.push_str("    cmp     r0, #7\n    bne     .Lsfxu_do_write\n");
    s.push_str("    push    {r1, r6, r7}                @ save sfx_mixer + loop vars\n");
    s.push_str("    mov     r0, #7\n    bl      v_readPSG  @ r0 = current Regs[7]\n");
    s.push_str("    pop     {r1, r6, r7}                @ r1 = sfx_mixer, r0 = cur_mixer\n");
    s.push_str("    and     r0, r0, #0xDB               @ keep non-C bits from music (~0x24)\n");
    s.push_str("    and     r1, r1, #0x24               @ keep only C bits from SFX\n");
    s.push_str("    orr     r1, r0, r1                  @ merged mixer\n");
    s.push_str("    mov     r0, #7\n");
    s.push_str(".Lsfxu_do_write:\n");
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

    // J2 X / J2 Y — return the raw analog value in -127..127, matching
    // pitrex_j1_x/y and vpy_j2_x/y on rp2350. The old implementation
    // applied a ±32 deadzone and returned -1/0/+1, which silently broke
    // any game that scaled the axis (e.g. `sx = cx + jx / 4` yielded 0
    // forever because |jx| was always ≤ 1).
    s.push_str("@ pitrex_j2_x() → r0 = X axis (-127..127)\n");
    s.push_str(".global pitrex_j2_x\n.type pitrex_j2_x, %function\npitrex_j2_x:\n");
    s.push_str("    ldr     r1, =currentJoy2X\n");
    s.push_str("    ldrsb   r0, [r1]\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");

    s.push_str("@ pitrex_j2_y() → r0 = Y axis (-127..127)\n");
    s.push_str(".global pitrex_j2_y\n.type pitrex_j2_y, %function\npitrex_j2_y:\n");
    s.push_str("    ldr     r1, =currentJoy2Y\n");
    s.push_str("    ldrsb   r0, [r1]\n");
    s.push_str("    bx      lr\n");
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
    s.push_str("@ pitrex_get_level_floor_y() → r0 = floor surface world Y\n");
    s.push_str("@   = camera_y - 128 + groundBottomOffset  (from level header +32)\n");
    s.push_str(".global pitrex_get_level_floor_y\n.type pitrex_get_level_floor_y, %function\npitrex_get_level_floor_y:\n");
    s.push_str("    ldr     r0, =LEVEL_DATA_PTR\n    ldr     r0, [r0]\n");
    s.push_str("    cmp     r0, #0\n    beq     pglfy_none\n");
    s.push_str("    ldrsh   r1, [r0, #32]      @ groundBottomOffset at header +32\n");
    s.push_str("    ldr     r0, =CAMERA_Y\n    ldr     r0, [r0]\n");
    s.push_str("    sub     r0, r0, #128\n");
    s.push_str("    add     r0, r0, r1\n");
    s.push_str("    bx      lr\n");
    s.push_str("pglfy_none:\n    mov     r0, #0\n    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    for (fname, sym) in &[
        ("pitrex_get_scroll_limit_left",   "SCROLL_LIMIT_LEFT"),
        ("pitrex_get_scroll_limit_right",  "SCROLL_LIMIT_RIGHT"),
        ("pitrex_get_scroll_limit_top",    "SCROLL_LIMIT_TOP"),
        ("pitrex_get_scroll_limit_bottom", "SCROLL_LIMIT_BOTTOM"),
    ] {
        s.push_str(&format!("@ {}() → r0\n", fname));
        s.push_str(&format!(".global {fname}\n.type {fname}, %function\n{fname}:\n"));
        s.push_str(&format!("    ldr     r1, ={sym}\n"));
        s.push_str("    ldr     r0, [r1]\n");
        s.push_str("    bx      lr\n");
        s.push_str("    .ltorg\n\n");
    }
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
    s.push_str("    add     r7, r7, #20         @ next ROM object (20 bytes)\n");
    s.push_str("    add     r8, r8, #8          @ next buf entry\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     .Lul_loop\n");
    s.push_str(".Lul_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n");
    s.push_str("    .ltorg\n\n");

    // pitrex_draw_vector_3d: full X+Y+Z rotation, _3D_DATA format
    // Args: r0=asset_3D_DATA, r1=ax, r2=ay, r3=az, [sp]=ox, [sp+4]=oy
    // After push {r4-r11, lr} (36 bytes): [sp+36]=ox, [sp+40]=oy
    //
    // _3D_DATA layout (pitrex/assets.rs):
    //   .word  vertex_count
    //   .byte  vx, vy, vz × N            (clamped ±63)
    //   .word  path_count
    //   .byte  pt_count, closed, idx0, idx1, ...
    //
    // Rotation order: X then Y then Z. Sin/cos cached in _DV3D_TRIG (8 bytes):
    //   [0]=sin_x [1]=cos_x [2]=sin_y [3]=cos_y [4]=sin_z [5]=cos_z
    // Rotated screen coords (sx, sy) stored in _DV3D_BUF as i8 pairs.
    s.push_str("@ pitrex_draw_vector_3d(r0=asset_3D_DATA,r1=ax,r2=ay,r3=az,[sp]=ox,[sp+4]=oy)\n");
    s.push_str(".global pitrex_draw_vector_3d\n.type pitrex_draw_vector_3d, %function\npitrex_draw_vector_3d:\n");
    s.push_str("    push    {r4-r11, lr}\n");
    s.push_str("    mov     r4, r0\n");                // r4 = _3D_DATA ptr
    // Read ox/oy as 32-bit words (callers push them as i32, not i16). Using
    // ldrsh would truncate large negative values; ldr matches the i32 push.
    s.push_str("    ldr     r10, [sp, #36]\n");        // r10 = ox (i32)
    s.push_str("    ldr     r11, [sp, #40]\n");        // r11 = oy (i32)
    s.push_str("    ldr     r9, [r4]\n");              // r9 = vertex_count (.word)
    s.push_str("    add     r4, r4, #4\n");
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    beq     .Ldv3d_done\n");

    // Precompute sin/cos for X, Y, Z axes → _DV3D_TRIG[0..5].
    // pitrex_get_sin/cos preserve r2-r11 (only touch r0, r1). We use r5 as a
    // permanent pointer to the trig cache so we don't need to reload it.
    s.push_str("    ldr     r5, =_DV3D_TRIG\n");
    s.push_str("    push    {r1, r2, r3}\n");          // save ax, ay, az
    // sin/cos x
    s.push_str("    mov     r0, r1\n    bl pitrex_get_sin\n    strb r0, [r5, #0]\n");
    s.push_str("    ldr     r0, [sp, #0]\n    bl pitrex_get_cos\n    strb r0, [r5, #1]\n");
    // sin/cos y
    s.push_str("    ldr     r0, [sp, #4]\n    bl pitrex_get_sin\n    strb r0, [r5, #2]\n");
    s.push_str("    ldr     r0, [sp, #4]\n    bl pitrex_get_cos\n    strb r0, [r5, #3]\n");
    // sin/cos z
    s.push_str("    ldr     r0, [sp, #8]\n    bl pitrex_get_sin\n    strb r0, [r5, #4]\n");
    s.push_str("    ldr     r0, [sp, #8]\n    bl pitrex_get_cos\n    strb r0, [r5, #5]\n");
    s.push_str("    add     sp, sp, #12\n");           // discard saved ax/ay/az

    s.push_str("    ldr     r6, =_DV3D_BUF\n");        // r6 = vbuf base
    s.push_str("    mov     r8, #0\n");                // r8 = loop idx

    // Vertex loop. Per iteration, transform (x,y,z) through X→Y→Z rotation
    // and store rotated (sx, sy) into vbuf[r8*2].
    //
    // For each axis with sin S, cos C:
    //   X-axis: y1 = y*C - z*S;  z1 = y*S + z*C
    //   Y-axis: x2 = x*C + z1*S; z2 = -x*S + z1*C  (we drop z2 — not used)
    //   Z-axis: sx = x2*C - y1*S; sy = x2*S + y1*C
    //
    // Each intermediate fits in i16 (val ≤63 × sin ≤127 / 128 ≤ 63), so we
    // use simple `mul; asr #7` per multiplication.
    s.push_str(".Lv3d_loop:\n");
    s.push_str("    cmp     r8, r9\n");
    s.push_str("    beq     .Lv3d_done_rotate\n");

    s.push_str("    ldrsb   r0, [r4]\n");              // r0 = x
    s.push_str("    ldrsb   r1, [r4, #1]\n");          // r1 = y
    s.push_str("    ldrsb   r2, [r4, #2]\n");          // r2 = z
    s.push_str("    add     r4, r4, #3\n");

    // --- X-axis rotation: y1 = y*cos_x - z*sin_x ;  z1 = y*sin_x + z*cos_x
    s.push_str("    ldrsb   r3, [r5, #1]\n");          // cos_x
    s.push_str("    mul     r7, r1, r3\n    asr r7, r7, #7\n"); // y*cos_x
    s.push_str("    ldrsb   r3, [r5, #0]\n");          // sin_x
    s.push_str("    mul     r12, r2, r3\n    asr r12, r12, #7\n"); // z*sin_x
    s.push_str("    sub     r7, r7, r12\n");           // r7 = y1
    s.push_str("    ldrsb   r3, [r5, #0]\n");          // sin_x
    s.push_str("    mul     r12, r1, r3\n    asr r12, r12, #7\n"); // y*sin_x
    s.push_str("    ldrsb   r3, [r5, #1]\n");          // cos_x
    s.push_str("    mul     r1, r2, r3\n    asr r1, r1, #7\n");    // z*cos_x  (reuse r1)
    s.push_str("    add     r1, r1, r12\n");           // r1 = z1  (now x, y1, z1 live in r0, r7, r1)

    // --- Y-axis rotation: x2 = x*cos_y + z1*sin_y
    s.push_str("    ldrsb   r3, [r5, #3]\n");          // cos_y
    s.push_str("    mul     r12, r0, r3\n    asr r12, r12, #7\n"); // x*cos_y
    s.push_str("    ldrsb   r3, [r5, #2]\n");          // sin_y
    s.push_str("    mul     r0, r1, r3\n    asr r0, r0, #7\n");    // z1*sin_y
    s.push_str("    add     r0, r0, r12\n");           // r0 = x2  (x2, y1 live in r0, r7)

    // --- Z-axis rotation: sx = x2*cos_z - y1*sin_z ;  sy = x2*sin_z + y1*cos_z
    s.push_str("    ldrsb   r3, [r5, #5]\n");          // cos_z
    s.push_str("    mul     r12, r0, r3\n    asr r12, r12, #7\n"); // x2*cos_z
    s.push_str("    ldrsb   r3, [r5, #4]\n");          // sin_z
    s.push_str("    mul     r2, r7, r3\n    asr r2, r2, #7\n");    // y1*sin_z
    s.push_str("    sub     r12, r12, r2\n");          // r12 = sx

    s.push_str("    ldrsb   r3, [r5, #4]\n");          // sin_z
    s.push_str("    mul     r1, r0, r3\n    asr r1, r1, #7\n");    // x2*sin_z
    s.push_str("    ldrsb   r3, [r5, #5]\n");          // cos_z
    s.push_str("    mul     r2, r7, r3\n    asr r2, r2, #7\n");    // y1*cos_z
    s.push_str("    add     r2, r2, r1\n");            // r2 = sy

    // Clamp sx (r12) and sy (r2) to ±127. IT-prefixed conditional MOVs
    // (Thumb-2 requires them).
    s.push_str("    mov     r0, #127\n    cmp r12, r0\n    it gt\n    movgt r12, r0\n");
    s.push_str("    mvn     r0, #127\n    cmp r12, r0\n    it lt\n    movlt r12, r0\n");
    s.push_str("    mov     r0, #127\n    cmp r2, r0\n    it gt\n    movgt r2, r0\n");
    s.push_str("    mvn     r0, #127\n    cmp r2, r0\n    it lt\n    movlt r2, r0\n");

    // vbuf[r8*2 + 0] = sx, vbuf[r8*2 + 1] = sy
    s.push_str("    lsl     r0, r8, #1\n");
    s.push_str("    add     r0, r0, r6\n");
    s.push_str("    strb    r12, [r0]\n");
    s.push_str("    strb    r2, [r0, #1]\n");

    s.push_str("    add     r8, r8, #1\n");
    s.push_str("    b       .Lv3d_loop\n");
    s.push_str(".Lv3d_done_rotate:\n");

    // r4 now points just past the vertex section. Align to 4 bytes to match
    // the `.balign 4` the asset emitter inserts before .word path_count.
    s.push_str("    add     r4, r4, #3\n    bic r4, r4, #3\n");
    s.push_str("    ldr     r9, [r4]\n");              // r9 = path_count
    s.push_str("    add     r4, r4, #4\n");            // skip path_count word
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    beq     .Ldv3d_done\n");

    // Path loop. r4 walks the index stream, r5 = path index counter.
    s.push_str("    mov     r5, #0\n");
    s.push_str(".Lpath_loop:\n");
    s.push_str("    cmp     r5, r9\n");
    s.push_str("    bge     .Ldv3d_done\n");

    // Each path header: byte pt_count, byte closed, then pt_count index bytes
    s.push_str("    ldrb    r7, [r4]\n");              // r7 = pt_count
    s.push_str("    ldrb    r8, [r4, #1]\n");          // r8 = closed
    s.push_str("    add     r4, r4, #2\n");
    s.push_str("    cmp     r7, #0\n");
    s.push_str("    beq     .Lpath_next\n");

    // First vertex: absolute move (no draw)
    s.push_str("    ldrb    r0, [r4]\n");              // r0 = idx
    s.push_str("    lsl     r0, r0, #1\n");
    s.push_str("    add     r0, r0, r6\n");            // &vbuf[idx*2]
    s.push_str("    ldrsb   r1, [r0]\n");              // sx
    s.push_str("    ldrsb   r2, [r0, #1]\n");          // sy
    s.push_str("    add     r1, r1, r10\n");           // sx + ox  (absX in VPy)
    s.push_str("    add     r2, r2, r11\n");           // sy + oy  (absY in VPy)
    // PiTrex SDK takes coords scaled to VPy*127 (its internal beam units).
    // Thumb-2 `MUL Rd, Rn, Rm` requires Rd != Rm (UNPREDICTABLE otherwise),
    // so use r0 to hold the multiplier and write the products into r3 / r12.
    s.push_str("    mov     r0, #127\n");
    s.push_str("    mul     r3, r1, r0\n");            // r3 = absX*127
    s.push_str("    mul     r12, r2, r0\n");           // r12 = absY*127
    s.push_str("    ldr     r0, =PITREX_CUR_X\n");
    s.push_str("    str     r3, [r0]\n");              // CUR_X = absX*127
    s.push_str("    str     r12, [r0, #4]\n");         // CUR_Y = absY*127
    s.push_str("    push    {r3, r12}\n");             // [sp+0]=firstX*127 [sp+4]=firstY*127
    // v_directMove32(r0=x*127, r1=y*127)
    s.push_str("    mov     r0, r3\n");                // r0 = absX*127
    s.push_str("    mov     r1, r12\n");               // r1 = absY*127
    s.push_str("    bl      v_directMove32\n");
    s.push_str("    mov     r0, #80\n");
    s.push_str("    bl      v_setScale\n");

    s.push_str("    add     r4, r4, #1\n");            // consumed first idx
    s.push_str("    sub     r7, r7, #1\n");            // pt_count--

    // Draw remaining vertices: pitrex_draw_line_rel(dx, dy, intensity)
    s.push_str(".Lseg_loop:\n");
    s.push_str("    cmp     r7, #0\n");
    s.push_str("    beq     .Lseg_done\n");
    s.push_str("    ldrb    r0, [r4]\n");
    s.push_str("    lsl     r0, r0, #1\n");
    s.push_str("    add     r0, r0, r6\n");
    s.push_str("    ldrsb   r1, [r0]\n");              // next sx
    s.push_str("    ldrsb   r2, [r0, #1]\n");          // next sy
    s.push_str("    add     r1, r1, r10\n");           // +ox
    s.push_str("    add     r2, r2, r11\n");           // +oy
    // pitrex_draw_line_rel takes deltas in VPy units (not *127).
    // Current beam pos is in CUR_X/Y * 127, so derive delta as
    //   dx = (absX - prevAbsX_in_VPy)
    // and rely on pitrex_draw_line_rel updating CUR_*. We track prev in
    // r3,r12 (last absolute VPy coords) instead of doing the *127 math twice.
    // r3, r12 are clobbered below — use stack-resident prev. For simplicity:
    // recompute dx,dy by reading CUR_X/Y, dividing by 127.
    s.push_str("    ldr     r3, =PITREX_CUR_X\n");
    s.push_str("    ldr     r12, [r3]\n");             // prevX*127
    s.push_str("    ldr     r3, [r3, #4]\n");          // prevY*127 (overwrites ptr — OK)
    // Compute dx*127 / dy*127 using multiplier in a third register to keep
    // Rd != Rm on every mul (Thumb-2 32-bit MUL: Rd==Rm is UNPREDICTABLE).
    s.push_str("    mov     r0, #127\n");
    s.push_str("    push    {r0}\n");                  // stash multiplier
    s.push_str("    mul     r1, r1, r0\n");            // r1 = absX*127 (Rd!=Rm: r0!=r1)
    s.push_str("    pop     {r0}\n");
    s.push_str("    sub     r1, r1, r12\n");           // dx*127
    s.push_str("    asr     r1, r1, #7\n");            // r1 = dx
    s.push_str("    mul     r2, r2, r0\n");            // r2 = absY*127 (Rd!=Rm: r0!=r2)
    s.push_str("    sub     r2, r2, r3\n");
    s.push_str("    asr     r2, r2, #7\n");            // r2 = dy
    s.push_str("    mov     r0, r1\n");                // r0 = dx
    s.push_str("    mov     r1, r2\n");                // r1 = dy
    s.push_str("    mov     r2, #127\n");              // intensity
    s.push_str("    bl      pitrex_draw_line_rel\n");

    s.push_str("    add     r4, r4, #1\n");
    s.push_str("    sub     r7, r7, #1\n");
    s.push_str("    b       .Lseg_loop\n");

    s.push_str(".Lseg_done:\n");
    s.push_str("    pop     {r3, r12}\n");             // recover first-vertex *127 coords
    // If closed: draw back to first vertex
    s.push_str("    cmp     r8, #0\n");
    s.push_str("    beq     .Lpath_next\n");
    s.push_str("    ldr     r0, =PITREX_CUR_X\n");
    s.push_str("    ldr     r1, [r0]\n");              // prevX*127
    s.push_str("    ldr     r2, [r0, #4]\n");          // prevY*127
    s.push_str("    sub     r0, r3, r1\n");
    s.push_str("    asr     r0, r0, #7\n");            // dx
    s.push_str("    sub     r1, r12, r2\n");
    s.push_str("    asr     r1, r1, #7\n");            // dy
    s.push_str("    mov     r2, #127\n");
    s.push_str("    bl      pitrex_draw_line_rel\n");

    s.push_str(".Lpath_next:\n");
    s.push_str("    add     r5, r5, #1\n");
    s.push_str("    b       .Lpath_loop\n");

    s.push_str(".Ldv3d_done:\n");
    s.push_str("    pop     {r4-r11, pc}\n");
    s.push_str("    .ltorg\n\n");

    // Add 3D rotation tables and helper functions
    s.push_str(&emit_pitrex_3d_tables_and_helpers());

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
    s.push_str("    cmp     r3, #0\n    it eq\n    moveq   r3, #8\n");
    // If negative: draw minus sign as a horizontal line in PiTrex units.
    // v_printString uses startX = x_passed * 128; we pass VPy*127/128, so
    // startX = VPy * 127.  The '-' glyph advances 6*SCALEFONT = 9*textSize units.
    // Minus sign: x0=VPy_x*127, x1=x0+8*textSize, y0=y1=(VPy_y-8)*127+6*textSize.
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    beq     pn_print_str\n");
    s.push_str("    ldr     r12, =127\n");
    s.push_str("    mul     r0, r4, r12         @ x0_px = VPy_x * 127 (Rd≠Rm ✓)\n");
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
    s.push_str("    cmp     r3, #0\n    it eq\n    moveq   r3, #8\n");
    s.push_str("pn_print_str:\n");
    // Set r2 = buf start, then skip leading '0' chars (but always keep at least 1 digit).
    s.push_str("    mov     r2, sp          @ buf ptr\n");
    s.push_str("pn_lz_scan:\n");
    s.push_str("    ldrb    r12, [r2]       @ current char\n");
    s.push_str("    cmp     r12, #48        @ '0'?\n");
    s.push_str("    bne     pn_lz_done\n");
    s.push_str("    ldrb    r12, [r2, #1]   @ peek next char\n");
    s.push_str("    cmp     r12, #0         @ last digit — always keep\n");
    s.push_str("    beq     pn_lz_done\n");
    s.push_str("    add     r2, r2, #1      @ advance past leading '0'\n");
    s.push_str("    b       pn_lz_scan\n");
    s.push_str("pn_lz_done:\n");
    // call v_printString(x_scaled, y_scaled, buf, textSize, brightness)
    s.push_str("    mov     r0, r4          @ x\n");
    s.push_str("    mov     r1, r5          @ y\n");
    // Subtract cap_height first (in VPy space), then rescale 25/32.
    s.push_str("    sub     r1, r1, #8          @ baseline = top - cap_height (VPy units)\n");
    // Rescale VPy*127/128 so v_printString's x*128 = VPy*127 (matching draw funcs).
    s.push_str("    mov     r12, #127\n");
    s.push_str("    mul     r0, r0, r12          @ r0  = x*127\n");
    s.push_str("    asr     r0, r0, #7           @ r0  = x*127/128\n");
    s.push_str("    mul     r1, r1, r12          @ r1  = y*127\n");
    s.push_str("    asr     r1, r1, #7           @ r1  = y*127/128\n");
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
    s.push_str("@ pitrex_draw_anim(r0=anim_ptr, r1=ox, r2=oy, r3=mirror, [sp]=speed_mul)\n");
    s.push_str(".global pitrex_draw_anim\n.type pitrex_draw_anim, %function\npitrex_draw_anim:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}    @ 36 bytes\n");
    s.push_str("    mov     r4, r0                      @ anim header ptr\n");
    s.push_str("    mov     r10, r1                     @ save ox\n");
    s.push_str("    mov     r11, r2                     @ save oy\n");
    // Save mirror and speed_mul to BSS so they survive across inner calls
    s.push_str("    ldr     r8, =PITREX_ANIM_MIRROR\n");
    s.push_str("    strb    r3, [r8]                    @ save mirror flag\n");
    s.push_str("    ldr     r8, =PITREX_ANIM_SPEED\n");
    s.push_str("    ldr     r9, [sp, #36]               @ speed_mul (after 9 regs = 36 bytes)\n");
    s.push_str("    strb    r9, [r8]                    @ save speed_mul\n");
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
    s.push_str("    ldr     r3, =PITREX_ANIM_MIRROR\n");
    s.push_str("    ldrb    r3, [r3]                    @ mirror flag\n");
    s.push_str("    mov     r8, #127\n");
    s.push_str("    push    {r8}                        @ intensity=127\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4                  @ discard intensity\n");
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

    // Load current frame data ptr, apply speed multiplier, and initialize ticks_left
    s.push_str("par_init_frame:\n");
    s.push_str("    ldrb    r8, [r4, #3]                @ frame_table_offset\n");
    s.push_str("    lsl     r9, r6, #2                  @ frame_idx * 4\n");
    s.push_str("    add     r9, r9, r8                  @ offset to frame table entry\n");
    s.push_str("    ldr     r9, [r4, r9]                @ ARM ptr to frame data\n");
    s.push_str("    ldrb    r7, [r9]                    @ duration_ticks\n");
    // Apply speed multiplier: duration_ticks *= speed_mul (skip if speed_mul <= 1)
    s.push_str("    ldr     r8, =PITREX_ANIM_SPEED\n");
    s.push_str("    ldrb    r8, [r8]                    @ speed_mul\n");
    s.push_str("    cmp     r8, #1\n");
    s.push_str("    ble     par_speed_done\n");
    s.push_str("    mul     r7, r8, r7                  @ duration_ticks *= speed_mul\n");
    s.push_str("par_speed_done:\n");
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
    s.push_str("    ldr     r3, =PITREX_ANIM_MIRROR\n");
    s.push_str("    ldrb    r3, [r3]                    @ mirror flag\n");
    s.push_str("    mov     r8, #127\n");
    s.push_str("    push    {r8}                        @ intensity=127\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4                  @ discard intensity\n");
    s.push_str("    pop     {r6, r9}\n");
    s.push_str("    add     r9, r9, #4                  @ next vec ptr\n");
    s.push_str("    subs    r6, r6, #1\n");
    s.push_str("    bne     par_vec_loop\n");
    s.push_str("par_done:\n");
    // Clear brightness override: next DRAW_ANIM/DRAW_VECTOR uses .vec intensities
    s.push_str("    ldr     r0, =PITREX_BRIGHTNESS_OVERRIDE\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    strb    r1, [r0]\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("    .ltorg\n\n");

    // Static state buffer + mirror/speed bytes in BSS. The brightness
    // override lives in `emit_pitrex_shared_bss` because several other
    // helpers (set_intensity, draw_line, draw_vector*, music/show_level)
    // also read it.
    s.push_str(".bss\n");
    s.push_str(".balign 4\n");
    s.push_str("PITREX_ANIM_STATE_BUF: .space 2    @ [0]=frame_idx [1]=ticks_left\n");
    s.push_str("PITREX_ANIM_MIRROR: .space 1\n");
    s.push_str("PITREX_ANIM_SPEED: .space 1\n");
    s.push_str(".text\n\n");

    s
}

// ── NOTE engine: pitrex_play_note + pitrex_note_update ────────────────────

fn emit_pitrex_note_engine() -> String {
    let mut s = String::new();

    // ── NOTE_PERIOD_TABLE in .rodata ────────────────────────────────────────
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
    // Emit 8 per line for readability
    for chunk in periods.chunks(8) {
        let vals: Vec<String> = chunk.iter().map(|p| p.to_string()).collect();
        s.push_str(&format!("    .hword {}\n", vals.join(", ")));
    }
    s.push('\n');
    s.push_str(".section .text\n");
    s.push_str(".align 2\n\n");

    // ── pitrex_play_note(r0=instr_ptr, r1=channel, r2=note) ────────────────
    s.push_str("@ pitrex_play_note(r0=instr_ptr, r1=channel 0-2, r2=note MIDI 24-107)\n");
    s.push_str(".global pitrex_play_note\n.type pitrex_play_note, %function\npitrex_play_note:\n");
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
    s.push_str("    push    {r2, r5, r7}\n    bl      v_writePSG\n    pop     {r2, r5, r7}\n");
    s.push_str("    lsl     r0, r5, #1\n    add     r0, r0, #1      @ reg_hi\n");
    s.push_str("    mov     r1, r2\n    lsr     r1, r1, #8      @ period_hi\n");
    s.push_str("    push    {r5, r7}\n    bl      v_writePSG\n    pop     {r5, r7}\n");

    // Write volume: ch A→R8, ch B→R9, ch C→R10
    s.push_str("    @ write volume to PSG (vol reg = channel + 8)\n");
    s.push_str("    ldr     r4, [r7, #12]   @ reload instr_ptr\n");
    s.push_str("    ldrb    r1, [r4, #1]    @ volume\n");
    s.push_str("    add     r0, r5, #8      @ vol reg = channel + 8\n");
    s.push_str("    push    {r5, r7}\n    bl      v_writePSG\n    pop     {r5, r7}\n");

    // Update mixer shadow: enable tone for channel (clear bit), disable noise (set noise bit)
    s.push_str("    @ update PSG_MIXER_SHADOW: enable tone ch, disable noise ch\n");
    s.push_str("    ldr     r0, =PSG_MIXER_SHADOW\n");
    s.push_str("    ldr     r1, [r0]\n");
    s.push_str("    mov     r2, #1\n    lsl     r2, r2, r5      @ tone bit for channel\n");
    s.push_str("    bic     r1, r1, r2      @ clear = enable tone\n");
    s.push_str("    add     r3, r5, #3\n    mov     r2, #1\n    lsl     r2, r2, r3      @ noise bit\n");
    s.push_str("    orr     r1, r1, r2      @ set = disable noise\n");
    s.push_str("    str     r1, [r0]        @ update shadow\n");
    s.push_str("    mov     r0, #7\n");        // R7 = mixer
    s.push_str("    push    {r5, r7}\n    bl      v_writePSG\n    pop     {r5, r7}\n");

    s.push_str("    pop     {r4, r5, r6, r7, pc}\n");
    s.push_str("    .ltorg\n\n");

    // ── pitrex_note_update() ────────────────────────────────────────────────
    s.push_str("@ pitrex_note_update() — advance note engine one frame (3 channels)\n");
    s.push_str(".global pitrex_note_update\n.type pitrex_note_update, %function\npitrex_note_update:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}\n");
    s.push_str("    mov     r4, #0              @ r4 = channel index\n");
    s.push_str(".Lpnu_loop:\n");
    s.push_str("    cmp     r4, #3\n    bge     .Lpnu_done\n");

    // Get channel state ptr: &NOTE_STATE + channel*32
    s.push_str("    ldr     r5, =NOTE_STATE\n");
    s.push_str("    mov     r6, #32\n");
    s.push_str("    mul     r7, r4, r6\n");
    s.push_str("    add     r5, r5, r7      @ r5 = &NOTE_STATE[channel]\n");

    // Skip if not active
    s.push_str("    ldr     r6, [r5, #0]    @ active\n");
    s.push_str("    cmp     r6, #0\n    beq     .Lpnu_next\n");

    // Decrement frames_left
    s.push_str("    ldr     r6, [r5, #4]    @ frames_left\n");
    s.push_str("    subs    r6, r6, #1\n");
    s.push_str("    str     r6, [r5, #4]\n");
    s.push_str("    bne     .Lpnu_arp\n");

    // Duration expired — mute channel volume
    s.push_str("    @ note expired: mute channel\n");
    s.push_str("    mov     r0, #0\n    str     r0, [r5, #0]    @ active = 0\n");
    s.push_str("    ldr     r6, [r5, #28]   @ channel_id\n");
    s.push_str("    add     r0, r6, #8      @ vol reg = channel_id + 8\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    push    {r4, r5}\n    bl      v_writePSG\n    pop     {r4, r5}\n");
    s.push_str("    b       .Lpnu_next\n");

    s.push_str(".Lpnu_arp:\n");
    // Check arpeggio
    s.push_str("    ldr     r6, [r5, #12]   @ instr_ptr\n");
    s.push_str("    ldrb    r7, [r6, #2]    @ arpeggio_count\n");
    s.push_str("    cmp     r7, #0\n    beq     .Lpnu_next\n");

    // Decrement arp timer
    s.push_str("    ldr     r8, [r5, #20]   @ arp_timer\n");
    s.push_str("    subs    r8, r8, #1\n");
    s.push_str("    str     r8, [r5, #20]\n");
    s.push_str("    bne     .Lpnu_next\n");

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
    s.push_str("    push    {r2, r3, r4, r5}\n    bl      v_writePSG\n    pop     {r2, r3, r4, r5}\n");
    s.push_str("    lsl     r0, r3, #1\n    add     r0, r0, #1      @ reg_hi\n");
    s.push_str("    mov     r1, r2\n    lsr     r1, r1, #8\n");
    s.push_str("    push    {r3, r4, r5}\n    bl      v_writePSG\n    pop     {r3, r4, r5}\n");

    s.push_str(".Lpnu_next:\n");
    s.push_str("    add     r4, r4, #1\n");
    s.push_str("    b       .Lpnu_loop\n");

    s.push_str(".Lpnu_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n");
    s.push_str("    .ltorg\n\n");

    s
}

// ── Enemy system ─────────────────────────────────────────────────────────────

/// Tiny helper used by the wander AI when transitioning between WALK and IDLE
/// sub-states. Swaps pool.sprite_ptr / pool.is_anim and resets the per-pool
/// animation cursor (frame_idx = 0, ticks_left = frame0.duration).
///
/// Args:
///   r0 = pool entry ptr
///   r1 = sprite_ptr (0 → no-op, leaves pool untouched)
///   r2 = is_anim flag
/// Clobbers: r3
pub(crate) fn emit_pitrex_wander_set_sprite() -> String {
    let mut s = String::new();
    s.push_str("@ pitrex_wander_set_sprite(r0=pool, r1=sprite_ptr, r2=is_anim)\n");
    s.push_str(".global pitrex_wander_set_sprite\n");
    s.push_str(".type pitrex_wander_set_sprite, %function\n");
    s.push_str("pitrex_wander_set_sprite:\n");
    s.push_str("    cmp     r1, #0\n");
    s.push_str("    bne     .Lpwss_do\n");
    s.push_str("    bx      lr                  @ null sprite: no-op\n");
    s.push_str(".Lpwss_do:\n");
    s.push_str("    str     r1, [r0, #0]        @ pool.sprite_ptr = r1\n");
    s.push_str("    strb    r2, [r0, #27]       @ pool.is_anim = r2\n");
    s.push_str("    mov     r3, #0\n");
    s.push_str("    strb    r3, [r0, #16]       @ pool.anim_frame_idx = 0\n");
    s.push_str("    cmp     r2, #0\n");
    s.push_str("    bne     .Lpwss_anim\n");
    s.push_str("    bx      lr                  @ static vec: no anim ticks\n");
    s.push_str(".Lpwss_anim:\n");
    // For vanim: read frame_table_offset (anim header +3), then frame0 duration.
    s.push_str("    ldrb    r3, [r1, #3]        @ frame_table_offset\n");
    s.push_str("    ldr     r3, [r1, r3]        @ frame0_ptr\n");
    s.push_str("    ldrb    r3, [r3]            @ frame0.duration_ticks\n");
    s.push_str("    strb    r3, [r0, #17]       @ pool.anim_ticks_left\n");
    s.push_str("    bx      lr\n");
    s.push_str("    .ltorg\n\n");
    s
}

pub(crate) fn emit_pitrex_spawn_enemies() -> String {
    // pitrex_spawn_enemies(r0=data_ptr, r1=count)
    // ROM record layout (variable, stride = 24 + wp_count*4):
    //   +0  sprite_ptr (u32), +4 spawn_x (i16), +6 spawn_y (i16)
    //   +8  ai_type (u8), +9 wp_count (u8)
    //   +10 mirror_on_patrol (u8), +11 default_facing (u8: 0=right 1=left)
    //   +12 wp0_x..wp(N-1)_y (wp_count * 4 bytes)
    //   +12+wp_count*4   is_anim (u8) + 3 pad bytes
    //   +16+wp_count*4   type_data_ptr (u32: ROM pointer to per-type SM data)
    //   +20+wp_count*4   areas_ptr (u32: ROM pointer to walkable-areas table,
    //                                0 if none — see Phase 2 wander AI)
    // Pool entry layout (32 bytes):
    //   +0  sprite_ptr (u32), +4 x (i16), +6 y (i16)
    //   +8  thaw_timer (i16) — multiplexed for wander: idle_timer in IDLE,
    //       target_y in AIRBORNE
    //   +10 sub_state (u8, wander: 0=WALK, 1=IDLE, 2=AIRBORNE)
    //   +11 current_area_idx (u8, wander) — index into the areas table
    //   +12 active (u8), +13 ai_type (u8), +14 cur_target (u8, patrol only),
    //   +15 wp_count (u8, patrol only)
    //   +16 anim_frame_idx (u8), +17 anim_ticks_left (u8)
    //   +18 sm_state (u8, snow/ball state machine: 0=normal, 1+=snowed)
    //   +19 (used by draw_enemies as transient is_anim temp — NOT safe across frames)
    //   +20..+23 type_data_ptr (u32 ROM ptr to per-type SM data table)
    //   +24 mirror_on_patrol (u8), +25 default_facing (u8), +26 dir (u8), +27 is_anim (u8)
    //   +28..+31 multiplexed per ai_type:
    //              patrol (1): wp_base (ROM ptr to waypoints)
    //              wander (4): areas_ptr (ROM ptr to walkable-areas table)
    let mut s = String::new();
    // r4=ROM data_ptr  r5=ROM entry countdown  r6=pool write ptr  r7=spawned count
    // r8=y_min  r9=y_max  r10=scratch  r0=scratch (saved to r4 at entry)
    s.push_str("@ pitrex_spawn_enemies(r0=data_ptr, r1=total_count)\n");
    s.push_str("@ Clears pool, reads CAMERA_Y, spawns only enemies in current floor range.\n");
    s.push_str(".global pitrex_spawn_enemies\n.type pitrex_spawn_enemies, %function\npitrex_spawn_enemies:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}\n");
    s.push_str("    mov     r4, r0          @ ROM data_ptr\n");
    s.push_str("    mov     r5, r1          @ total ROM entry count\n");

    // Step 1: Clear active flag for all 32 pool slots so previous level's enemies disappear.
    s.push_str("    @ Clear pool: zero active byte for all 32 slots\n");
    s.push_str("    ldr     r6, =PITREX_ENEMY_POOL\n");
    s.push_str("    mov     r10, #32\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str(".Lspe_clear:\n");
    s.push_str("    strb    r0, [r6, #12]   @ pool.active = 0\n");
    s.push_str("    add     r6, r6, #32\n");
    s.push_str("    subs    r10, r10, #1\n");
    s.push_str("    bne     .Lspe_clear\n");

    // Step 2: Compute y_min/y_max from CAMERA_Y (±150 — slightly wider than one screen).
    s.push_str("    @ Compute spawn range from CAMERA_Y\n");
    s.push_str("    ldr     r0, =CAMERA_Y\n");
    s.push_str("    ldr     r0, [r0]        @ camera_y (signed 32-bit)\n");
    s.push_str("    sub     r8, r0, #150    @ y_min = camera_y - 150\n");
    s.push_str("    add     r9, r0, #150    @ y_max = camera_y + 150\n");

    // Step 3: Setup pool write pointer and spawned count.
    s.push_str("    ldr     r6, =PITREX_ENEMY_POOL  @ pool write ptr\n");
    s.push_str("    mov     r7, #0                   @ spawned count\n");
    s.push_str("    cmp     r5, #0\n");
    s.push_str("    beq     .Lspe_store_count\n");

    s.push_str(".Lspe_loop:\n");
    // Filter by spawn_y range.
    s.push_str("    ldrsh   r10, [r4, #6]   @ spawn_y\n");
    s.push_str("    cmp     r10, r8\n");
    s.push_str("    blt     .Lspe_next      @ below floor\n");
    s.push_str("    cmp     r10, r9\n");
    s.push_str("    bgt     .Lspe_next      @ above floor\n");

    // Copy entry into pool slot at r6.
    s.push_str("    ldr     r0, [r4]        @ sprite_ptr\n");
    s.push_str("    str     r0, [r6]        @ pool.sprite_ptr\n");
    s.push_str("    ldrsh   r0, [r4, #4]    @ spawn_x\n");
    s.push_str("    strh    r0, [r6, #4]    @ pool.x\n");
    s.push_str("    ldrsh   r0, [r4, #6]    @ spawn_y\n");
    s.push_str("    strh    r0, [r6, #6]    @ pool.y\n");
    s.push_str("    ldrb    r0, [r4, #8]    @ ai_type\n");
    s.push_str("    strb    r0, [r6, #13]   @ pool.ai_type\n");
    s.push_str("    ldrb    r0, [r4, #9]    @ wp_count\n");
    s.push_str("    strb    r0, [r6, #15]   @ pool.wp_count\n");
    s.push_str("    ldrb    r0, [r4, #10]   @ mirror_on_patrol\n");
    s.push_str("    strb    r0, [r6, #24]\n");
    s.push_str("    ldrb    r0, [r4, #11]   @ default_facing\n");
    s.push_str("    strb    r0, [r6, #25]\n");
    s.push_str("    mov     r0, #1\n");
    s.push_str("    strb    r0, [r6, #12]   @ pool.active = 1\n");
    s.push_str("    strb    r0, [r6, #26]   @ pool.dir = 1 (right)\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r6, #14]   @ pool.cur_target = 0\n");
    s.push_str("    strb    r0, [r6, #18]   @ pool.sm_state = 0\n");
    s.push_str("    strb    r0, [r6, #10]   @ pool.sub_state = 0 (WALK for wander AI)\n");
    s.push_str("    strb    r0, [r6, #11]   @ pool.current_area_idx = 0 (wander)\n");
    s.push_str("    strh    r0, [r6, #8]    @ pool.thaw_timer / idle_timer = 0\n");
    // pool+28 multiplexed: wp_base for patrol, areas_ptr for wander.
    // We unconditionally store wp_base here; for wander we'll overwrite it
    // with areas_ptr below (loaded from ROM +20+wp_count*4).
    s.push_str("    add     r0, r4, #12     @ ROM waypoints base\n");
    s.push_str("    str     r0, [r6, #28]   @ pool.wp_base (patrol)\n");
    // is_anim at ROM offset 12 + wp_count*4
    s.push_str("    ldrb    r10, [r4, #9]   @ wp_count\n");
    s.push_str("    lsl     r10, r10, #2\n");
    s.push_str("    add     r10, r10, #12\n");
    s.push_str("    ldrb    r0, [r4, r10]   @ is_anim\n");
    s.push_str("    strb    r0, [r6, #27]   @ pool.is_anim\n");
    // type_data_ptr at ROM offset 16 + wp_count*4
    s.push_str("    ldrb    r10, [r4, #9]   @ wp_count\n");
    s.push_str("    lsl     r10, r10, #2\n");
    s.push_str("    add     r10, r10, #16\n");
    s.push_str("    ldr     r0, [r4, r10]   @ type_data_ptr\n");
    s.push_str("    str     r0, [r6, #20]   @ pool.type_data_ptr\n");
    // areas_ptr at ROM offset 20 + wp_count*4 (Phase 2). Overwrite pool+28
    // (wp_base) with this pointer when the AI wants it there:
    //   - wander (ai_type=4): always
    //   - patrol (ai_type=1) with no waypoints AND areas_ptr != 0: lets the
    //     enemy use the walkable area as its patrol range.
    s.push_str("    ldrb    r1, [r4, #8]    @ ai_type\n");
    s.push_str("    ldrb    r2, [r4, #9]    @ wp_count\n");
    s.push_str("    lsl     r10, r2, #2\n");
    s.push_str("    add     r10, r10, #20\n");
    s.push_str("    ldr     r0, [r4, r10]   @ areas_ptr from ROM\n");
    s.push_str("    cmp     r1, #4\n");
    s.push_str("    beq     .Lspe_store_areas    @ wander → always\n");
    s.push_str("    cmp     r1, #1\n");
    s.push_str("    bne     .Lspe_skip_areas     @ neither patrol nor wander\n");
    s.push_str("    cmp     r2, #0\n");
    s.push_str("    bne     .Lspe_skip_areas     @ patrol with waypoints → keep wp_base\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     .Lspe_skip_areas     @ no areas\n");
    s.push_str(".Lspe_store_areas:\n");
    s.push_str("    str     r0, [r6, #28]   @ pool.areas_ptr (overlays wp_base)\n");
    s.push_str(".Lspe_skip_areas:\n");
    // Wander only: snap pool.y and current_area_idx to the area whose y is
    // closest to spawn_y. Without this, an enemy spawned slightly off the
    // exact area.y would walk forever at its spawn altitude instead of on a
    // platform (the WALK state only touches X). We also prefer this over
    // hard-requiring the level designer to align spawn_y with area.y.
    // NOTE: r8 = y_min and r9 = y_max are loop invariants of the outer spawn
    // loop (Y-range filter). We MUST NOT clobber them across this block. Use
    // only r0, r1, r2, r3, r10, r12 as scratch here.
    s.push_str("    ldrb    r0, [r6, #13]       @ ai_type\n");
    s.push_str("    cmp     r0, #4\n");
    s.push_str("    beq     .Lspe_area_snap_ok\n");
    s.push_str("    cmp     r0, #1\n");
    s.push_str("    bne     .Lspe_no_area_snap  @ neither patrol nor wander\n");
    s.push_str("    ldrb    r0, [r6, #15]       @ wp_count\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    bne     .Lspe_no_area_snap  @ patrol w/ waypoints: leave Y as spawn_y\n");
    s.push_str(".Lspe_area_snap_ok:\n");
    s.push_str("    ldr     r10, [r6, #28]      @ areas_ptr\n");
    s.push_str("    cmp     r10, #0\n");
    s.push_str("    beq     .Lspe_no_area_snap\n");
    s.push_str("    ldr     r12, [r10]          @ area_count (kept in r12 across loop)\n");
    s.push_str("    cmp     r12, #0\n");
    s.push_str("    beq     .Lspe_no_area_snap\n");
    s.push_str("    add     r10, r10, #8        @ &area[0]\n");
    s.push_str("    ldrsh   r1, [r6, #6]        @ spawn_y\n");
    s.push_str("    mov     r2, #0              @ best_idx\n");
    s.push_str("    mov     r3, #1\n");
    s.push_str("    lsl     r3, r3, #16         @ best_cost = 0x10000 (large sentinel)\n");
    s.push_str("    mov     r0, #0              @ i\n");
    // Push the regs we need to free. r4 is ROM data_ptr (outer-loop invariant)
    // and r11 we use as scratch for spawn_x.
    s.push_str("    push    {r4, r11}\n");
    s.push_str("    ldrsh   r11, [r6, #4]       @ spawn_x\n");
    s.push_str(".Lspe_area_loop:\n");
    s.push_str("    cmp     r0, r12\n");
    s.push_str("    bge     .Lspe_area_done\n");
    // |area.y - spawn_y|
    s.push_str("    ldrsh   r4, [r10]           @ area[i].y\n");
    s.push_str("    sub     r4, r4, r1\n");
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r4, r4, #0          @ |dy|\n");
    // Cost = |dy| with two penalties:
    //   +1024 if spawn_x is OUTSIDE [area.x_min, area.x_max]  → prefer areas
    //         that horizontally contain the enemy.
    //   +4096 if area.y > spawn_y                              → prefer areas
    //         at or below the enemy's feet. When two parallel shelves stack
    //         vertically and the user drops an enemy between them, this
    //         picks the LOWER shelf (gravity intuition) even when the upper
    //         shelf is slightly closer in |dy|.
    s.push_str("    push    {r0, r1}            @ save i and spawn_y temporarily\n");
    s.push_str("    ldrsh   r0, [r10, #2]       @ x_min\n");
    s.push_str("    ldrsh   r1, [r10, #4]       @ x_max\n");
    s.push_str("    cmp     r11, r0\n");
    s.push_str("    blt     .Lspe_area_outside\n");
    s.push_str("    cmp     r11, r1\n");
    s.push_str("    ble     .Lspe_area_inside\n");
    s.push_str(".Lspe_area_outside:\n");
    s.push_str("    add     r4, r4, #1024       @ X-outside penalty\n");
    s.push_str(".Lspe_area_inside:\n");
    // Above-feet penalty: area.y > spawn_y. spawn_y was pushed at sp+4
    // by `push {r0, r1}` above.
    s.push_str("    ldrsh   r0, [r10]           @ area.y\n");
    s.push_str("    ldr     r1, [sp, #4]        @ saved spawn_y\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    ble     .Lspe_area_not_above\n");
    s.push_str("    add     r4, r4, #4096       @ above-feet penalty\n");
    s.push_str(".Lspe_area_not_above:\n");
    s.push_str("    pop     {r0, r1}\n");
    // Compare cost to best
    s.push_str("    cmp     r4, r3\n");
    s.push_str("    bge     .Lspe_area_skip\n");
    s.push_str("    mov     r3, r4              @ new best_cost\n");
    s.push_str("    mov     r2, r0              @ new best_idx\n");
    s.push_str(".Lspe_area_skip:\n");
    s.push_str("    add     r10, r10, #8\n");
    s.push_str("    add     r0, r0, #1\n");
    s.push_str("    b       .Lspe_area_loop\n");
    s.push_str(".Lspe_area_done:\n");
    s.push_str("    pop     {r4, r11}\n");
    s.push_str("    strb    r2, [r6, #11]       @ current_area_idx = best\n");
    s.push_str("    ldr     r10, [r6, #28]\n");
    s.push_str("    add     r10, r10, #8\n");
    s.push_str("    lsl     r12, r2, #3\n");
    s.push_str("    add     r10, r10, r12\n");
    s.push_str("    ldrsh   r0, [r10]           @ area[best].y\n");
    // Apply per-enemy-type feet_offset baked into _DATA[209]. area.y is the
    // platform top; pool.y = area.y + feet_offset places the sprite's lowest
    // pixel on that top regardless of sprite size or current sm_state.
    s.push_str("    ldr     r12, [r6, #20]      @ type_data_ptr\n");
    s.push_str("    cmp     r12, #0\n");
    s.push_str("    beq     .Lspe_no_feet\n");
    s.push_str("    ldrsb   r12, [r12, #209]    @ feet_offset (signed byte)\n");
    s.push_str("    add     r0, r0, r12\n");
    s.push_str(".Lspe_no_feet:\n");
    s.push_str("    strh    r0, [r6, #6]        @ snap pool.y = area.y + feet_offset\n");
    s.push_str(".Lspe_no_area_snap:\n");
    // vanim init: set frame_idx=0, anim_ticks_left=frame0.duration
    s.push_str("    ldrb    r0, [r6, #27]   @ is_anim\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     .Lspe_novam\n");
    s.push_str("    ldr     r0, [r4]        @ sprite_ptr (anim header)\n");
    s.push_str("    ldrb    r10, [r0, #3]   @ frame_table_offset\n");
    s.push_str("    ldr     r10, [r0, r10]  @ frame0_ptr\n");
    s.push_str("    ldrb    r10, [r10]      @ frame0 duration_ticks\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r6, #16]   @ pool.anim_frame_idx = 0\n");
    s.push_str("    strb    r10, [r6, #17]  @ pool.anim_ticks_left\n");
    s.push_str(".Lspe_novam:\n");

    // Advance pool write ptr; stop if pool is full (32 slots).
    s.push_str("    add     r6, r6, #32\n");
    s.push_str("    add     r7, r7, #1\n");
    s.push_str("    cmp     r7, #32\n");
    s.push_str("    beq     .Lspe_store_count  @ pool full\n");

    // Advance ROM ptr to next entry (stride = 24 + wp_count*4).
    // 24 = sprite_ptr(4) + spawn_x(2) + spawn_y(2) + ai_type(1) + wp_count(1)
    //    + mirror(1) + facing(1) + is_anim(1) + 3pad + type_data_ptr(4)
    //    + areas_ptr(4)
    s.push_str(".Lspe_next:\n");
    s.push_str("    ldrb    r10, [r4, #9]   @ wp_count\n");
    s.push_str("    lsl     r10, r10, #2\n");
    s.push_str("    add     r10, r10, #24   @ stride = 24 + wp_count*4\n");
    s.push_str("    add     r4, r4, r10\n");
    s.push_str("    subs    r5, r5, #1\n");
    s.push_str("    bne     .Lspe_loop\n");

    s.push_str(".Lspe_store_count:\n");
    s.push_str("    ldr     r0, =PITREX_ENEMY_COUNT\n");
    s.push_str("    str     r7, [r0]\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

fn emit_pitrex_update_enemies() -> String {
    // pitrex_update_enemies() — advance enemy AI one frame.
    // Patrol AI (ai_type=1): moves enemy toward each waypoint in sequence (X+Y),
    // advancing wp_idx when both axes reach the target, then wrapping.
    // pool+28 = wp_base: pointer to the ROM waypoints array (stored by spawn).
    // Speed: PATROL_SPEED = 1 VPy unit/frame.
    let mut s = String::new();
    s.push_str("@ pitrex_update_enemies() — advance enemy AI (full X+Y patrol)\n");
    s.push_str(".global pitrex_update_enemies\n.type pitrex_update_enemies, %function\npitrex_update_enemies:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, r12, lr}\n");
    s.push_str("    ldr     r4, =PITREX_ENEMY_COUNT\n");
    s.push_str("    ldr     r4, [r4]\n");
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    beq     .Lpue_done\n");
    s.push_str("    ldr     r5, =PITREX_ENEMY_POOL\n");
    s.push_str("    mov     r12, #1             @ PATROL_SPEED\n");
    s.push_str(".Lpue_loop:\n");
    // skip inactive
    s.push_str("    ldrb    r6, [r5, #12]       @ active\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpue_skip\n");
    // Freeze in place when sm_state != 0 (snowed/balled). Patrol AI only runs in state 0.
    s.push_str("    ldrb    r6, [r5, #18]       @ sm_state\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    bne     .Lpue_skip          @ frozen: do not patrol\n");
    // dispatch on ai_type
    s.push_str("    ldrb    r6, [r5, #13]       @ ai_type\n");
    s.push_str("    cmp     r6, #4\n");
    s.push_str("    beq     .Lpue_wander\n");
    s.push_str("    cmp     r6, #1\n");
    s.push_str("    bne     .Lpue_skip          @ unsupported ai_type\n");
    // ── ai_type=1 (patrol). Two variants:
    //
    //   A) wp_count >= 2 → classic waypoint patrol (full X+Y interp below).
    //   B) wp_count == 0 → area-bounded patrol: bounce X within the walkable
    //      area at pool+11 (snapped at spawn). Y stays at area.y. Cheap and
    //      lets the level designer drop a patrol enemy onto a platform
    //      without having to wire up waypoints.
    //
    // For (B) pool+28 holds areas_ptr (set in spawn when patrol has no wps).
    s.push_str("    ldrb    r6, [r5, #15]       @ wp_count\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpue_p_area        @ wp_count == 0 → area patrol\n");
    s.push_str("    cmp     r6, #2\n");
    s.push_str("    blt     .Lpue_skip          @ wp_count == 1: invalid\n");
    // compute &wp[cur_target] from pool.wp_base (pool+28) and cur_target (pool+14)
    s.push_str("    ldrb    r6, [r5, #14]       @ cur_target\n");
    s.push_str("    ldr     r7, [r5, #28]       @ pool.wp_base (ROM waypoints ptr)\n");
    s.push_str("    lsl     r6, r6, #2          @ cur_target * 4\n");
    s.push_str("    add     r7, r7, r6          @ &wp[cur_target]\n");
    s.push_str("    ldrsh   r8, [r7]            @ target_x\n");
    s.push_str("    ldrsh   r9, [r7, #2]        @ target_y\n");
    // load current position
    s.push_str("    ldrsh   r10, [r5, #4]       @ x\n");
    s.push_str("    ldrsh   r11, [r5, #6]       @ y\n");
    // ── move x toward target_x ──
    s.push_str("    sub     r6, r8, r10         @ dx = target_x - x\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpue_movey         @ dx==0, skip x\n");
    // update dir from dx sign
    s.push_str("    mov     r7, #0              @ dir=left default\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r7, #1              @ dir=right if dx>0\n");
    s.push_str("    strb    r7, [r5, #26]       @ pool.dir\n");
    s.push_str("    blt     .Lpue_xneg\n");
    // dx > 0: move right
    s.push_str("    cmp     r6, r12             @ dx vs SPEED\n");
    s.push_str("    ble     .Lpue_xsnap\n");
    s.push_str("    add     r10, r10, r12       @ x += SPEED\n");
    s.push_str("    b       .Lpue_movey\n");
    s.push_str(".Lpue_xneg:\n");
    // dx < 0: move left
    s.push_str("    rsb     r6, r6, #0          @ |dx|\n");
    s.push_str("    cmp     r6, r12\n");
    s.push_str("    ble     .Lpue_xsnap\n");
    s.push_str("    sub     r10, r10, r12       @ x -= SPEED\n");
    s.push_str("    b       .Lpue_movey\n");
    s.push_str(".Lpue_xsnap:\n");
    s.push_str("    mov     r10, r8             @ x = target_x\n");
    // ── move y toward target_y ──
    s.push_str(".Lpue_movey:\n");
    s.push_str("    sub     r6, r9, r11         @ dy = target_y - y\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpue_store         @ dy==0, skip y\n");
    s.push_str("    blt     .Lpue_yneg\n");
    // dy > 0: move up
    s.push_str("    cmp     r6, r12\n");
    s.push_str("    ble     .Lpue_ysnap\n");
    s.push_str("    add     r11, r11, r12       @ y += SPEED\n");
    s.push_str("    b       .Lpue_store\n");
    s.push_str(".Lpue_yneg:\n");
    // dy < 0: move down
    s.push_str("    rsb     r6, r6, #0          @ |dy|\n");
    s.push_str("    cmp     r6, r12\n");
    s.push_str("    ble     .Lpue_ysnap\n");
    s.push_str("    sub     r11, r11, r12       @ y -= SPEED\n");
    s.push_str("    b       .Lpue_store\n");
    s.push_str(".Lpue_ysnap:\n");
    s.push_str("    mov     r11, r9             @ y = target_y\n");
    // ── write back position ──
    s.push_str(".Lpue_store:\n");
    s.push_str("    strh    r10, [r5, #4]       @ pool.x = x\n");
    s.push_str("    strh    r11, [r5, #6]       @ pool.y = y\n");
    // advance waypoint if both axes reached target
    s.push_str("    cmp     r10, r8             @ x == target_x?\n");
    s.push_str("    bne     .Lpue_skip\n");
    s.push_str("    cmp     r11, r9             @ y == target_y?\n");
    s.push_str("    bne     .Lpue_skip\n");
    s.push_str("    ldrb    r6, [r5, #14]       @ cur_target\n");
    s.push_str("    ldrb    r7, [r5, #15]       @ wp_count\n");
    s.push_str("    add     r6, r6, #1\n");
    s.push_str("    cmp     r6, r7\n");
    s.push_str("    it      ge\n");
    s.push_str("    movge   r6, #0              @ wrap\n");
    s.push_str("    strb    r6, [r5, #14]       @ pool.cur_target\n");
    s.push_str("    b       .Lpue_skip\n");

    // ── ai_type=1 / wp_count=0: area-bounded patrol ─────────────────────
    // pool+28 holds areas_ptr (spawn stored it there because no waypoints).
    // pool+11 is the area index, snapped at spawn to the area whose y is
    // closest to spawn_y. Walk X between area.x_min and area.x_max; on
    // reaching an edge, just flip dir (no IDLE — patrol is a continuous loop).
    s.push_str(".Lpue_p_area:\n");
    s.push_str("    ldr     r8, [r5, #28]       @ areas_ptr\n");
    s.push_str("    cmp     r8, #0\n");
    s.push_str("    beq     .Lpue_skip          @ no areas → idle\n");
    s.push_str("    ldrb    r6, [r5, #11]       @ current_area_idx\n");
    s.push_str("    lsl     r6, r6, #3\n");
    s.push_str("    add     r8, r8, r6\n");
    s.push_str("    add     r8, r8, #8          @ &area[idx]\n");
    s.push_str("    ldrsh   r9, [r8, #2]        @ x_min\n");
    s.push_str("    ldrsh   r10, [r8, #4]       @ x_max\n");
    s.push_str("    ldrsh   r11, [r5, #4]       @ x\n");
    s.push_str("    ldrb    r6, [r5, #26]       @ dir (0=left,1=right)\n");
    s.push_str("    cmp     r6, #1\n");
    s.push_str("    beq     .Lpue_p_area_right\n");
    // dir=LEFT: target x_min
    s.push_str("    cmp     r11, r9\n");
    s.push_str("    ble     .Lpue_p_area_edge\n");
    s.push_str("    sub     r11, r11, r12       @ x -= SPEED\n");
    s.push_str("    cmp     r11, r9\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r11, r9\n");
    s.push_str("    strh    r11, [r5, #4]\n");
    s.push_str("    cmp     r11, r9\n");
    s.push_str("    bne     .Lpue_skip\n");
    s.push_str("    b       .Lpue_p_area_edge\n");
    s.push_str(".Lpue_p_area_right:\n");
    s.push_str("    cmp     r11, r10\n");
    s.push_str("    bge     .Lpue_p_area_edge\n");
    s.push_str("    add     r11, r11, r12\n");
    s.push_str("    cmp     r11, r10\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r11, r10\n");
    s.push_str("    strh    r11, [r5, #4]\n");
    s.push_str("    cmp     r11, r10\n");
    s.push_str("    bne     .Lpue_skip\n");
    s.push_str(".Lpue_p_area_edge:\n");
    s.push_str("    ldrb    r6, [r5, #26]\n");
    s.push_str("    eor     r6, r6, #1\n");
    s.push_str("    strb    r6, [r5, #26]       @ flip dir\n");
    s.push_str("    b       .Lpue_skip\n");

    // ── ai_type=4: wander — area-based AI with optional transitions ────
    // Phase 2 design: enemy lives inside one of N walkable areas
    // (rectangles defined by y, x_min, x_max). It walks X-only between the
    // edges of its current area. On reaching an edge, IDLE pause, then
    // either reverse OR (if transitions are defined from this area) ballistic-
    // jump to a target area.
    //
    // Pool fields used:
    //   +8..9  i16  idle_timer in IDLE, target_y in AIRBORNE
    //   +10    u8   sub_state: 0=WALK, 1=IDLE, 2=AIRBORNE
    //   +11    u8   current_area_idx
    //   +26    u8   pool.dir (0=going to x_min, 1=going to x_max)
    //   +28..31 u32 areas_ptr (ROM table: [area_count|trans_count|areas|trans])
    //
    // Areas table layout (per enemy, in ROM):
    //   word 0: area_count   (e.g. 1 or more)
    //   word 1: trans_count  (e.g. 0 or more)
    //   then area_count * 8 bytes:  hword y, x_min, x_max, 0
    //   then trans_count * 4 bytes: byte from, to, type, 0   (type 1=jump_up 2=drop)
    s.push_str(".Lpue_wander:\n");
    s.push_str("    ldr     r6, [r5, #28]       @ areas_ptr (overlays wp_base)\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpue_skip          @ no areas defined\n");
    s.push_str("    ldr     r7, [r6]            @ area_count\n");
    s.push_str("    cmp     r7, #0\n");
    s.push_str("    beq     .Lpue_skip\n");
    s.push_str("    ldrb    r6, [r5, #10]       @ sub_state\n");
    s.push_str("    cmp     r6, #3\n");
    s.push_str("    beq     .Lpue_w_to_takeoff  @ walking toward from_x\n");
    s.push_str("    cmp     r6, #2\n");
    s.push_str("    beq     .Lpue_w_air\n");
    s.push_str("    cmp     r6, #1\n");
    s.push_str("    beq     .Lpue_w_idle\n");

    // ── WALK ────────────────────────────────────────────────────────────
    // Load current area's (y, x_min, x_max). r8=area_base_ptr.
    // area_offset = 8 + 8 * current_area_idx
    s.push_str("    ldr     r8, [r5, #28]       @ areas_ptr\n");
    s.push_str("    ldrb    r6, [r5, #11]       @ current_area_idx\n");
    s.push_str("    lsl     r6, r6, #3          @ idx * 8\n");
    s.push_str("    add     r8, r8, r6\n");
    s.push_str("    add     r8, r8, #8          @ &area[idx]\n");
    s.push_str("    ldrsh   r9, [r8, #2]        @ x_min\n");
    s.push_str("    ldrsh   r10, [r8, #4]       @ x_max\n");
    s.push_str("    ldrsh   r11, [r5, #4]       @ x\n");
    s.push_str("    ldrb    r6, [r5, #26]       @ dir (0=left,1=right)\n");
    s.push_str("    cmp     r6, #1\n");
    s.push_str("    beq     .Lpue_w_right\n");
    // dir = LEFT: target = x_min
    s.push_str("    cmp     r11, r9\n");
    s.push_str("    ble     .Lpue_w_edge        @ already at/past x_min\n");
    s.push_str("    sub     r11, r11, r12       @ x -= SPEED\n");
    s.push_str("    cmp     r11, r9\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r11, r9             @ clamp to x_min\n");
    s.push_str("    strh    r11, [r5, #4]\n");
    s.push_str("    cmp     r11, r9\n");
    s.push_str("    bne     .Lpue_skip\n");
    s.push_str("    b       .Lpue_w_edge\n");
    s.push_str(".Lpue_w_right:\n");
    // dir = RIGHT: target = x_max
    s.push_str("    cmp     r11, r10\n");
    s.push_str("    bge     .Lpue_w_edge\n");
    s.push_str("    add     r11, r11, r12\n");
    s.push_str("    cmp     r11, r10\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r11, r10\n");
    s.push_str("    strh    r11, [r5, #4]\n");
    s.push_str("    cmp     r11, r10\n");
    s.push_str("    bne     .Lpue_skip\n");

    // Reached an edge — reverse direction and enter IDLE
    s.push_str(".Lpue_w_edge:\n");
    s.push_str("    ldrb    r6, [r5, #26]       @ dir\n");
    s.push_str("    eor     r6, r6, #1          @ flip\n");
    s.push_str("    strb    r6, [r5, #26]\n");
    s.push_str("    bl      pitrex_random\n");
    s.push_str("    and     r0, r0, #0x3F\n");
    s.push_str("    add     r0, r0, #90         @ 90..153 frames (~2-3s)\n");
    s.push_str("    strh    r0, [r5, #8]        @ idle_timer\n");
    s.push_str("    mov     r0, #1\n");
    s.push_str("    strb    r0, [r5, #10]       @ sub_state = IDLE\n");
    // Swap to idle animation: load idle_sprite_ptr from _DATA+204
    s.push_str("    ldr     r3, [r5, #20]       @ type_data_ptr\n");
    s.push_str("    ldr     r1, [r3, #204]      @ idle_sprite_ptr\n");
    s.push_str("    ldrb    r2, [r3, #208]      @ idle_is_anim\n");
    s.push_str("    mov     r0, r5\n");
    s.push_str("    bl      pitrex_wander_set_sprite\n");
    s.push_str("    mov     r12, #1\n");
    s.push_str("    b       .Lpue_skip\n");

    // ── IDLE ────────────────────────────────────────────────────────────
    s.push_str(".Lpue_w_idle:\n");
    s.push_str("    ldrsh   r6, [r5, #8]        @ idle_timer\n");
    s.push_str("    sub     r6, r6, #1\n");
    s.push_str("    strh    r6, [r5, #8]\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    bgt     .Lpue_skip          @ still idle\n");
    // Idle expired: maybe transition. We use a simple deterministic policy
    // for the picker: walk the transitions list, and for each match of
    // `from == current_area_idx`, roll a coin. The first matching coin-up
    // commits to that transition. If nothing wins, fall back to WALK.
    // This gives roughly uniform per-frame chances across multiple matches
    // without needing modulo (no udiv on the ARMv6 target).
    s.push_str("    ldr     r8, [r5, #28]       @ areas_ptr\n");
    s.push_str("    ldr     r9, [r8]            @ area_count\n");
    s.push_str("    ldr     r10, [r8, #4]       @ trans_count\n");
    s.push_str("    cmp     r10, #0\n");
    s.push_str("    beq     .Lpue_w_to_walk     @ no transitions defined\n");
    // trans_ptr = areas_ptr + 8 + area_count*8
    s.push_str("    add     r11, r8, #8\n");
    s.push_str("    add     r6, r9, r9          @ ac*2\n");
    s.push_str("    add     r6, r6, r6          @ ac*4\n");
    s.push_str("    add     r6, r6, r6          @ ac*8\n");
    s.push_str("    add     r11, r11, r6        @ trans_ptr\n");
    // Keep cur_area in r6 (callee-saved across bl pitrex_random).
    // Transition records are 8 bytes: [from, to, type, pad, from_x:i16, to_x:i16].
    s.push_str("    ldrb    r6, [r5, #11]       @ cur_area\n");
    s.push_str("    mov     r7, #0              @ trans index\n");
    s.push_str(".Lpue_w_pick:\n");
    s.push_str("    cmp     r7, r10\n");
    s.push_str("    bge     .Lpue_w_to_walk     @ exhausted, no transition\n");
    s.push_str("    lsl     r1, r7, #3          @ idx * 8\n");
    s.push_str("    ldrb    r2, [r11, r1]       @ trans.from\n");
    s.push_str("    cmp     r2, r6\n");
    s.push_str("    bne     .Lpue_w_pick_next\n");
    // Matching from. Roll a coin: ~25% chance to commit (low 2 bits == 0).
    // pitrex_random preserves r4-r11, so r6/r7/r10/r11 survive the bl.
    s.push_str("    bl      pitrex_random\n");
    s.push_str("    and     r0, r0, #3\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     .Lpue_w_pick_hit\n");
    s.push_str(".Lpue_w_pick_next:\n");
    s.push_str("    add     r7, r7, #1\n");
    s.push_str("    b       .Lpue_w_pick\n");
    s.push_str(".Lpue_w_pick_hit:\n");
    // r7 = transition index. Load trans[r7] fields and commit. Don't snap
    // x yet — the enemy walks to from_x first (sub_state WALK_TO_TAKEOFF).
    s.push_str("    lsl     r1, r7, #3          @ trans[r7] offset (8 bytes)\n");
    s.push_str("    add     r3, r11, r1         @ &trans[r7]\n");
    s.push_str("    ldrb    r2, [r3, #1]        @ to (target area idx)\n");
    s.push_str("    strb    r2, [r5, #11]       @ current_area_idx = target\n");
    s.push_str("    ldrb    r2, [r3, #2]        @ type (1=jump_up, 2=drop, 3=jump_across)\n");
    s.push_str("    strb    r2, [r5, #15]       @ stash transition type at pool+15 (wp_count slot, free for wander)\n");
    s.push_str("    ldrsh   r1, [r3, #4]        @ from_x\n");
    s.push_str("    strh    r1, [r5, #8]        @ stash from_x in pool+8..9 (WALK_TO_TAKEOFF target)\n");
    s.push_str("    ldrsh   r1, [r3, #6]        @ to_x\n");
    s.push_str("    strh    r1, [r5, #14]       @ stash target_x in pool+14..15\n");
    s.push_str("    mov     r0, #3\n");
    s.push_str("    strb    r0, [r5, #10]       @ sub_state = WALK_TO_TAKEOFF\n");
    // Restore walk animation: enemy is leaving IDLE to walk to the takeoff point.
    s.push_str("    ldr     r3, [r5, #20]       @ type_data_ptr\n");
    s.push_str("    ldr     r1, [r3]            @ _DATA+0 = walk sprite_ptr\n");
    s.push_str("    ldrb    r2, [r3, #32]       @ _DATA+32 = walk is_anim\n");
    s.push_str("    mov     r0, r5\n");
    s.push_str("    bl      pitrex_wander_set_sprite\n");
    s.push_str("    mov     r12, #1\n");
    s.push_str("    b       .Lpue_skip\n");
    s.push_str(".Lpue_w_to_walk:\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r5, #10]       @ sub_state = WALK\n");
    // Restore walk animation: _DATA[0] is the sm_state=0 sprite (walk action).
    s.push_str("    ldr     r3, [r5, #20]       @ type_data_ptr\n");
    s.push_str("    ldr     r1, [r3]            @ _DATA+0 = walk sprite_ptr\n");
    s.push_str("    ldrb    r2, [r3, #32]       @ _DATA+32 = walk is_anim\n");
    s.push_str("    mov     r0, r5\n");
    s.push_str("    bl      pitrex_wander_set_sprite\n");
    s.push_str("    mov     r12, #1\n");
    s.push_str("    b       .Lpue_skip\n");

    // ── WALK_TO_TAKEOFF: walk X-only toward from_x (stashed at pool+8..9).
    // When enemy.x reaches from_x, transition into AIRBORNE: compute target_y
    // from areas[current_area_idx].y (current_area_idx was already set to the
    // transition's target at commit time) and overwrite pool+8..9 with it.
    s.push_str(".Lpue_w_to_takeoff:\n");
    s.push_str("    ldrsh   r8, [r5, #8]        @ from_x\n");
    s.push_str("    ldrsh   r10, [r5, #4]       @ x\n");
    s.push_str("    sub     r6, r8, r10\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpue_w_tt_reached\n");
    s.push_str("    bgt     .Lpue_w_tt_right\n");
    // dx < 0: walk left
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r5, #26]       @ dir = left\n");
    s.push_str("    sub     r10, r10, r12       @ x -= SPEED\n");
    s.push_str("    cmp     r10, r8\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r10, r8             @ clamp to from_x\n");
    s.push_str("    strh    r10, [r5, #4]\n");
    s.push_str("    cmp     r10, r8\n");
    s.push_str("    bne     .Lpue_skip\n");
    s.push_str("    b       .Lpue_w_tt_reached\n");
    s.push_str(".Lpue_w_tt_right:\n");
    s.push_str("    mov     r0, #1\n");
    s.push_str("    strb    r0, [r5, #26]       @ dir = right\n");
    s.push_str("    add     r10, r10, r12       @ x += SPEED\n");
    s.push_str("    cmp     r10, r8\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r10, r8             @ clamp to from_x\n");
    s.push_str("    strh    r10, [r5, #4]\n");
    s.push_str("    cmp     r10, r8\n");
    s.push_str("    bne     .Lpue_skip\n");
    // Arrived at from_x — switch to AIRBORNE. Pick initial vy by transition
    // type (pool+15, set at commit). jump_up scales vy0 to the actual dy so a
    // tall platform is reachable: solve vy0*(vy0+1)/2 >= dy iteratively, since
    // ARMv6 has no udiv/sqrt. drop and jump_across use fixed small impulses;
    // gravity (vy -= 1, clamped at -3) does the rest.
    s.push_str(".Lpue_w_tt_reached:\n");
    // Compute dy = target_y - current_y (target area's y has been set into
    // current_area_idx at commit time).
    s.push_str("    ldr     r8, [r5, #28]       @ areas_ptr\n");
    s.push_str("    ldrb    r6, [r5, #11]       @ current_area_idx (= target)\n");
    s.push_str("    lsl     r6, r6, #3\n");
    s.push_str("    add     r8, r8, r6\n");
    s.push_str("    add     r8, r8, #8          @ &area[target]\n");
    s.push_str("    ldrsh   r9, [r8]            @ target_y\n");
    s.push_str("    ldrsh   r1, [r5, #6]        @ current y\n");
    s.push_str("    sub     r9, r9, r1          @ dy = target_y - y\n");
    s.push_str("    ldrb    r6, [r5, #15]       @ transition type\n");
    s.push_str("    cmp     r6, #2\n");
    s.push_str("    beq     .Lpue_w_tt_drop\n");
    s.push_str("    cmp     r6, #3\n");
    s.push_str("    beq     .Lpue_w_tt_across\n");
    // type 1 (jump_up): scale vy0 to reach dy. Iterate vy from 4 until
    // vy*(vy+1)/2 >= dy. Cap at 16.
    s.push_str("    mov     r3, #4              @ vy0 start\n");
    s.push_str(".Lpue_w_tt_vy0_loop:\n");
    s.push_str("    add     r2, r3, #1\n");
    s.push_str("    mul     r2, r3, r2          @ vy0*(vy0+1)\n");
    s.push_str("    lsr     r2, r2, #1          @ peak = vy0*(vy0+1)/2\n");
    s.push_str("    cmp     r2, r9\n");
    s.push_str("    bge     .Lpue_w_tt_setvy_r3\n");
    s.push_str("    add     r3, r3, #1\n");
    s.push_str("    cmp     r3, #16\n");
    s.push_str("    blt     .Lpue_w_tt_vy0_loop\n");
    s.push_str(".Lpue_w_tt_setvy_r3:\n");
    s.push_str("    mov     r0, r3\n");
    s.push_str("    b       .Lpue_w_tt_setvy\n");
    s.push_str(".Lpue_w_tt_drop:\n");
    s.push_str("    mvn     r0, #0              @ vy0 = -1 (gravity does the work)\n");
    s.push_str("    b       .Lpue_w_tt_setvy\n");
    s.push_str(".Lpue_w_tt_across:\n");
    s.push_str("    mov     r0, #3\n");
    s.push_str(".Lpue_w_tt_setvy:\n");
    s.push_str("    strh    r0, [r5, #8]        @ pool+8..9 = vy (signed i16)\n");
    s.push_str("    mov     r0, #2\n");
    s.push_str("    strb    r0, [r5, #10]       @ sub_state = AIRBORNE\n");
    // Snap facing toward target_x so the sprite mirror is correct mid-arc.
    s.push_str("    ldrsh   r0, [r5, #14]       @ target_x\n");
    s.push_str("    ldrsh   r1, [r5, #4]        @ x\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bge     .Lpue_w_tt_face_r\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r5, #26]       @ dir = left\n");
    s.push_str("    b       .Lpue_skip\n");
    s.push_str(".Lpue_w_tt_face_r:\n");
    s.push_str("    mov     r0, #1\n");
    s.push_str("    strb    r0, [r5, #26]       @ dir = right\n");
    s.push_str("    b       .Lpue_skip\n");

    // ── AIRBORNE: two phases.
    //
    //   Phase A (X moving): step X toward target by AIR_SPEED=4 and run the
    //                       parabolic Y arc (y += vy; vy -= 1; vy clamped to
    //                       >= -3). This is the visible jump.
    //
    //   Phase B (X done):   lerp Y toward target_y at AIR_SPEED until reached,
    //                       then land. Guarantees the AIRBORNE state ends in
    //                       a bounded number of frames regardless of arc shape
    //                       — previously, long jump_across with vy capped at
    //                       -3 made Y diverge past target and the proximity
    //                       check never fired, leaving enemies floating and
    //                       the frame budget blown (visible as flicker and
    //                       brighter beam dwell).
    s.push_str(".Lpue_w_air:\n");
    s.push_str("    ldrsh   r10, [r5, #4]       @ current x\n");
    s.push_str("    ldrsh   r8, [r5, #14]       @ target_x\n");
    s.push_str("    sub     r6, r8, r10         @ dx\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpue_w_air_y_lerp  @ Phase B: lerp Y, then land\n");
    // Phase A: X step + parabolic Y.
    s.push_str("    bgt     .Lpue_w_air_xright\n");
    s.push_str("    sub     r10, r10, #4        @ x -= AIR_SPEED\n");
    s.push_str("    cmp     r10, r8\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r10, r8\n");
    s.push_str("    strh    r10, [r5, #4]\n");
    s.push_str("    b       .Lpue_w_air_y_arc\n");
    s.push_str(".Lpue_w_air_xright:\n");
    s.push_str("    add     r10, r10, #4        @ x += AIR_SPEED\n");
    s.push_str("    cmp     r10, r8\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r10, r8\n");
    s.push_str("    strh    r10, [r5, #4]\n");
    s.push_str(".Lpue_w_air_y_arc:\n");
    s.push_str("    ldrsh   r6, [r5, #6]\n");
    s.push_str("    ldrsh   r7, [r5, #8]        @ vy\n");
    s.push_str("    add     r6, r6, r7\n");
    s.push_str("    strh    r6, [r5, #6]        @ y += vy\n");
    s.push_str("    sub     r7, r7, #1\n");
    s.push_str("    mvn     r0, #2              @ -3 (terminal)\n");
    s.push_str("    cmp     r7, r0\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r7, r0              @ clamp vy >= -3\n");
    s.push_str("    strh    r7, [r5, #8]\n");
    s.push_str("    b       .Lpue_skip\n");

    // Phase B: X is at target_x. Step Y toward target_y at AIR_SPEED, land
    // when equal. r6 is reused as current y, r9 as target_y.
    s.push_str(".Lpue_w_air_y_lerp:\n");
    s.push_str("    ldr     r8, [r5, #28]       @ areas_ptr\n");
    s.push_str("    ldrb    r2, [r5, #11]       @ current_area_idx (= target)\n");
    s.push_str("    lsl     r2, r2, #3\n");
    s.push_str("    add     r8, r8, r2\n");
    s.push_str("    add     r8, r8, #8          @ &area[target]\n");
    s.push_str("    ldrsh   r9, [r8]            @ target_y\n");
    s.push_str("    ldrsh   r6, [r5, #6]\n");
    s.push_str("    sub     r0, r9, r6          @ target_y - y\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     .Lpue_w_air_land\n");
    s.push_str("    bgt     .Lpue_w_air_ylerp_up\n");
    // y > target: step down
    s.push_str("    sub     r6, r6, #4\n");
    s.push_str("    cmp     r6, r9\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r6, r9\n");
    s.push_str("    strh    r6, [r5, #6]\n");
    s.push_str("    cmp     r6, r9\n");
    s.push_str("    bne     .Lpue_skip\n");
    s.push_str("    b       .Lpue_w_air_land\n");
    s.push_str(".Lpue_w_air_ylerp_up:\n");
    s.push_str("    add     r6, r6, #4\n");
    s.push_str("    cmp     r6, r9\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r6, r9\n");
    s.push_str("    strh    r6, [r5, #6]\n");
    s.push_str("    cmp     r6, r9\n");
    s.push_str("    bne     .Lpue_skip\n");
    s.push_str(".Lpue_w_air_land:\n");
    // Apply feet_offset (from _DATA[209]) so the sprite lands feet-first on
    // the target platform, matching the spawn snap convention.
    s.push_str("    ldr     r0, [r5, #20]       @ type_data_ptr\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     .Lpue_w_air_land_no_off\n");
    s.push_str("    ldrsb   r0, [r0, #209]      @ feet_offset\n");
    s.push_str("    add     r9, r9, r0\n");
    s.push_str(".Lpue_w_air_land_no_off:\n");
    s.push_str("    strh    r9, [r5, #6]        @ snap y = target_y + feet_offset\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r5, #10]       @ sub_state = WALK\n");
    s.push_str("    @ fall through to skip\n");

    s.push_str(".Lpue_skip:\n");
    s.push_str("    add     r5, r5, #32         @ next pool entry\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     .Lpue_loop\n");
    s.push_str(".Lpue_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, r12, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

pub(crate) fn emit_pitrex_draw_enemies() -> String {
    // pitrex_draw_enemies() — draw all active enemies with camera offset.
    // Pool entry stride = 32 bytes.
    // Mirror logic: mirror = (mirror_on_patrol && (dir XNOR default_facing))
    //   dir=1(right), default_facing=0(right) → same → no mirror
    //   dir=0(left),  default_facing=0(right) → diff → mirror
    //   dir=1(right), default_facing=1(left)  → diff → mirror
    //   dir=0(left),  default_facing=1(left)  → same → no mirror
    // Formula: mirror = NOT (dir XOR default_facing) = (dir EOR default_facing) EOR 1
    // Calls pitrex_draw_vector_ex(r0=asset, r1=ox, r2=oy, r3=mirror, [sp]=intensity).
    let mut s = String::new();
    s.push_str("@ pitrex_draw_enemies() — draw all active entries in PITREX_ENEMY_POOL\n");
    s.push_str(".global pitrex_draw_enemies\n.type pitrex_draw_enemies, %function\npitrex_draw_enemies:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}\n");
    s.push_str("    ldr     r4, =PITREX_ENEMY_COUNT\n");
    s.push_str("    ldr     r4, [r4]\n");
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    beq     .Lpde_done\n");
    s.push_str("    ldr     r8, =CAMERA_X\n");
    s.push_str("    ldr     r8, [r8]            @ cam_x\n");
    s.push_str("    ldr     r9, =CAMERA_Y\n");
    s.push_str("    ldr     r9, [r9]            @ cam_y\n");
    s.push_str("    ldr     r5, =PITREX_ENEMY_POOL\n");
    s.push_str(".Lpde_loop:\n");
    s.push_str("    ldrb    r6, [r5, #12]       @ active\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpde_skip\n");
    // Pick sprite and is_anim flag based on sm_state.
    // state 0 (default) → pool.sprite_ptr (+0) and pool.is_anim (+27)
    // state > 0          → type_data_ptr[sm_state*4]    and type_data_ptr[16 + sm_state]
    // After this block: r6 = sprite_ptr, r0 = is_anim flag (saved later into r10).
    s.push_str("    ldrb    r0, [r5, #18]       @ sm_state\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq     .Lpde_default_sprite\n");
    s.push_str("    ldr     r1, [r5, #20]       @ type_data_ptr\n");
    s.push_str("    cmp     r1, #0\n");
    s.push_str("    beq     .Lpde_default_sprite @ no per-type data → fall back\n");
    s.push_str("    lsl     r2, r0, #2          @ sm_state * 4\n");
    s.push_str("    ldr     r6, [r1, r2]        @ state-specific sprite_ptr\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpde_default_sprite @ slot empty → fall back\n");
    s.push_str("    add     r2, r1, #32         @ &is_anim_table[0] (after 8 sprite ptrs)\n");
    s.push_str("    ldrb    r2, [r2, r0]        @ state-specific is_anim flag\n");
    s.push_str("    strb    r2, [r5, #19]       @ stash temp is_anim at pool+19 (free byte)\n");
    s.push_str("    b       .Lpde_check_sprite\n");
    s.push_str(".Lpde_default_sprite:\n");
    s.push_str("    ldr     r6, [r5]            @ default sprite_ptr (pool+0)\n");
    s.push_str("    ldrb    r2, [r5, #27]       @ default is_anim (pool+27)\n");
    s.push_str("    strb    r2, [r5, #19]       @ stash temp is_anim at pool+19\n");
    s.push_str(".Lpde_check_sprite:\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq     .Lpde_skip\n");
    // Compute screen ox, oy
    s.push_str("    ldrsh   r7, [r5, #4]        @ pool.x\n");
    s.push_str("    sub     r7, r7, r8          @ ox = x - cam_x\n");
    // Cull: skip if |ox| > 180 (off-screen horizontally)
    s.push_str("    mov     r10, r7\n");
    s.push_str("    cmp     r10, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r10, r10, #0        @ r10 = |ox|\n");
    s.push_str("    cmp     r10, #180\n");
    s.push_str("    bgt     .Lpde_skip\n");
    // Cull: skip if |oy| > 140 (off-screen, 13-unit buffer past +-127 screen edge)
    s.push_str("    ldrsh   r10, [r5, #6]       @ pool.y (temp for cull)\n");
    s.push_str("    sub     r10, r10, r9        @ oy = y - cam_y\n");
    s.push_str("    cmp     r10, #0\n");
    s.push_str("    it      lt\n");
    s.push_str("    rsblt   r10, r10, #0        @ r10 = |oy|\n");
    s.push_str("    cmp     r10, #140\n");
    s.push_str("    bgt     .Lpde_skip\n");
    // Compute mirror value
    s.push_str("    ldrb    r10, [r5, #24]      @ mirror_on_patrol\n");
    s.push_str("    cmp     r10, #0\n");
    s.push_str("    beq     .Lpde_no_mirror\n");
    s.push_str("    ldrb    r10, [r5, #25]      @ default_facing\n");
    s.push_str("    ldrb    r3,  [r5, #26]      @ dir\n");
    s.push_str("    eor     r3, r3, r10         @ XOR\n");
    s.push_str("    eor     r3, r3, #1          @ XNOR → mirror\n");
    s.push_str("    b       .Lpde_do_draw\n");
    s.push_str(".Lpde_no_mirror:\n");
    s.push_str("    mov     r3, #0              @ mirror=0\n");
    s.push_str(".Lpde_do_draw:\n");
    // Dispatch on temp is_anim flag (stashed at pool+19 above, derived from sm_state)
    s.push_str("    ldrb    r10, [r5, #19]      @ temp is_anim (state-aware)\n");
    s.push_str("    cmp     r10, #0\n");
    s.push_str("    bne     .Lpde_anim\n");
    // ── Vector sprite: pass sprite_ptr directly ──
    s.push_str("    push    {r4, r5, r8, r9}    @ save loop state\n");
    s.push_str("    ldrsh   r1, [r5, #6]        @ pool.y\n");
    s.push_str("    sub     r1, r1, r9          @ oy = y - cam_y\n");
    s.push_str("    mov     r2, r1              @ oy\n");
    s.push_str("    mov     r1, r7              @ ox\n");
    s.push_str("    mov     r0, r6              @ sprite_ptr\n");
    s.push_str("    mov     r12, #127\n");
    s.push_str("    push    {r12}               @ 5th arg: intensity=127\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4          @ pop intensity\n");
    s.push_str("    pop     {r4, r5, r8, r9}\n");
    s.push_str("    b       .Lpde_skip\n");
    // ── Vanim sprite: tick frame state, extract current frame's vec_ref ──
    s.push_str(".Lpde_anim:\n");
    // r6 = sprite_ptr = anim header ptr; r5 = pool entry
    s.push_str("    ldrb    r11, [r5, #16]      @ anim_frame_idx\n");
    s.push_str("    ldrb    r12, [r5, #17]      @ anim_ticks_left\n");
    s.push_str("    subs    r12, r12, #1        @ ticks--; set flags\n");
    s.push_str("    bgt     .Lpde_anim_sf       @ ticks > 0: keep frame\n");
    // Advance frame: frame_idx++ wrapping on frame_count
    s.push_str("    ldrb    r10, [r6]           @ frame_count (anim_header[0])\n");
    s.push_str("    add     r11, r11, #1\n");
    s.push_str("    cmp     r11, r10\n");
    s.push_str("    blt     .Lpde_no_wrap\n");
    s.push_str("    mov     r11, #0             @ wrap to 0\n");
    s.push_str(".Lpde_no_wrap:\n");
    s.push_str("    strb    r11, [r5, #16]      @ store frame_idx\n");
    // frame_ptr = anim_header[frame_table_offset + frame_idx*4]
    // Read frame_table_offset from header byte 3 (= 4 + base_ref_count*4).
    // Hardcoding #4 breaks animations that have base_refs (base_ref_count > 0).
    s.push_str("    ldrb    r10, [r6, #3]       @ frame_table_offset (hdr byte 3)\n");
    s.push_str("    lsl     r0, r11, #2         @ frame_idx * 4 (use r0; r9=cam_y preserved)\n");
    s.push_str("    add     r10, r10, r0        @ frame_table_offset + frame_idx*4\n");
    s.push_str("    ldr     r10, [r6, r10]      @ frame_ptr\n");
    // new ticks from frame_ptr[0] = duration_ticks
    s.push_str("    ldrb    r12, [r10]          @ new duration_ticks\n");
    s.push_str("    strb    r12, [r5, #17]      @ store ticks_left\n");
    // vec_ref at frame_ptr+4
    s.push_str("    ldr     r0, [r10, #4]       @ vec_ref\n");
    s.push_str("    b       .Lpde_anim_draw\n");
    // Same frame: just decrement ticks and get current vec_ref
    s.push_str(".Lpde_anim_sf:\n");
    s.push_str("    strb    r12, [r5, #17]      @ store decremented ticks\n");
    // frame_ptr = anim_header[frame_table_offset + frame_idx*4]
    s.push_str("    ldrb    r10, [r6, #3]       @ frame_table_offset (hdr byte 3)\n");
    s.push_str("    lsl     r0, r11, #2         @ frame_idx * 4 (use r0; r9=cam_y preserved)\n");
    s.push_str("    add     r10, r10, r0        @ frame_table_offset + frame_idx*4\n");
    s.push_str("    ldr     r10, [r6, r10]      @ frame_ptr\n");
    // vec_ref at frame_ptr+4
    s.push_str("    ldr     r0, [r10, #4]       @ vec_ref\n");
    // Draw with extracted vec_ref (r0), mirror already in r3, ox in r7
    s.push_str(".Lpde_anim_draw:\n");
    s.push_str("    push    {r4, r5, r8, r9}    @ save loop state\n");
    s.push_str("    ldrsh   r1, [r5, #6]        @ pool.y\n");
    s.push_str("    sub     r1, r1, r9          @ oy = y - cam_y\n");
    s.push_str("    mov     r2, r1              @ oy\n");
    s.push_str("    mov     r1, r7              @ ox\n");
    s.push_str("    mov     r12, #127\n");
    s.push_str("    push    {r12}               @ intensity\n");
    s.push_str("    bl      pitrex_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #4\n");
    s.push_str("    pop     {r4, r5, r8, r9}\n");
    s.push_str(".Lpde_skip:\n");
    s.push_str("    add     r5, r5, #32\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     .Lpde_loop\n");
    s.push_str(".Lpde_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── 3D rotation tables and helpers ────────────────────────────────────────────

fn emit_pitrex_3d_tables_and_helpers() -> String {
    let mut s = String::new();

    // _PITREX_SIN_TABLE: 128 signed bytes, sin(i*2π/128)*127
    s.push_str("@ _PITREX_SIN_TABLE[128]: sin(i*2π/128)*127 as signed byte\n");
    s.push_str(".section .rodata\n");
    s.push_str(".balign 1\n");
    s.push_str(".global _PITREX_SIN_TABLE\n");
    s.push_str("_PITREX_SIN_TABLE:\n");

    for i in 0usize..128 {
        let angle_rad = (i as f64) * 2.0 * std::f64::consts::PI / 128.0;
        let sin_val = (angle_rad.sin() * 127.0).round() as i8;
        s.push_str(&format!("    .byte {}\n", sin_val));
    }
    s.push_str("\n");

    // pitrex_get_sin(r0=angle) → r0=sin_table[angle&127]
    s.push_str("@ pitrex_get_sin(r0=angle) → r0=sin_table[angle&127] as signed byte\n");
    s.push_str(".text\n");
    s.push_str(".type pitrex_get_sin, %function\n");
    s.push_str("pitrex_get_sin:\n");
    s.push_str("    and     r0, r0, #127\n");
    s.push_str("    ldr     r1, =_PITREX_SIN_TABLE\n");
    s.push_str("    ldrsb   r0, [r1, r0]\n");
    s.push_str("    bx      lr\n");

    // pitrex_get_cos(r0=angle) → r0=sin_table[(angle+32)&127] as signed byte
    s.push_str("@ pitrex_get_cos(r0=angle) → r0=sin_table[(angle+32)&127] (cos approximation)\n");
    s.push_str(".type pitrex_get_cos, %function\n");
    s.push_str("pitrex_get_cos:\n");
    s.push_str("    add     r0, r0, #32\n");
    s.push_str("    and     r0, r0, #127\n");
    s.push_str("    ldr     r1, =_PITREX_SIN_TABLE\n");
    s.push_str("    ldrsb   r0, [r1, r0]\n");
    s.push_str("    bx      lr\n");

    // pitrex_smul_lut(r0=value, r1=angle) → r0=(value*sin(angle))>>7
    // Uses _PITREX_SIN_TABLE; angle in [0,127]
    s.push_str("@ pitrex_smul_lut(r0=value, r1=angle) → r0=(value*sin(angle))>>7\n");
    s.push_str(".type pitrex_smul_lut, %function\n");
    s.push_str("pitrex_smul_lut:\n");
    s.push_str("    push    {r2, lr}\n");
    s.push_str("    and     r1, r1, #127\n");
    s.push_str("    ldr     r2, =_PITREX_SIN_TABLE\n");
    s.push_str("    ldrsb   r2, [r2, r1]        @ r2 = sin_table[angle]\n");
    s.push_str("    mul     r0, r0, r2          @ r0 = value * sin(angle)\n");
    s.push_str("    asr     r0, r0, #7          @ r0 >>= 7\n");
    s.push_str("    pop     {r2, pc}\n");
    s.push_str("    .ltorg\n\n");

    s
}

fn emit_pitrex_kill_enemy() -> String {
    // pitrex_kill_enemy(r0=idx) — deactivate enemy at pool slot idx.
    // Sets pool[idx*32+12] (active) to 0.
    let mut s = String::new();
    s.push_str("@ pitrex_kill_enemy(r0=idx)\n");
    s.push_str(".global pitrex_kill_enemy\n.type pitrex_kill_enemy, %function\npitrex_kill_enemy:\n");
    s.push_str("    push    {r1, r2, lr}\n");
    s.push_str("    mov     r1, #32\n");
    s.push_str("    mul     r0, r0, r1\n");
    s.push_str("    ldr     r1, =PITREX_ENEMY_POOL\n");
    s.push_str("    add     r1, r1, r0\n");
    s.push_str("    mov     r2, #0\n");
    s.push_str("    strb    r2, [r1, #12]   @ active = 0\n");
    s.push_str("    pop     {r1, r2, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

fn emit_pitrex_enemy_fire_event() -> String {
    // pitrex_enemy_fire_event(r0=idx, r1=event_hash) — transition enemy SM state.
    //
    // Reads type_data_ptr from pool+20, then searches the per-state event table
    // embedded in _DATA at offset 44 + sm_state*20:
    //   +0: event_count (.byte), +1..3: pad
    //   +4 per event: .byte hash, .byte target_state, .byte[2] pad
    // On match, writes target_state to pool+18 (sm_state).
    let mut s = String::new();
    s.push_str("@ pitrex_enemy_fire_event(r0=idx, r1=event_hash) — dispatch SM event\n");
    s.push_str(".global pitrex_enemy_fire_event\n.type pitrex_enemy_fire_event, %function\npitrex_enemy_fire_event:\n");
    s.push_str("    push    {r2, r3, r4, r5, lr}\n");
    // r2 = pool entry for idx
    s.push_str("    mov     r2, #32\n");
    s.push_str("    mul     r2, r0, r2\n");
    s.push_str("    ldr     r3, =PITREX_ENEMY_POOL\n");
    s.push_str("    add     r2, r3, r2\n");
    // r3 = sm_state
    s.push_str("    ldrb    r3, [r2, #18]   @ sm_state\n");
    // r4 = type_data_ptr
    s.push_str("    ldr     r4, [r2, #20]   @ type_data_ptr\n");
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    beq     .Lpfe_done\n");
    // r4 = base of event block for this state: _DATA + 44 + sm_state*20
    s.push_str("    mov     r5, #20\n");
    s.push_str("    mla     r4, r3, r5, r4  @ base + sm_state*20\n");
    s.push_str("    add     r4, r4, #44     @ + event table offset\n");
    // r3 = event_count
    s.push_str("    ldrb    r3, [r4]        @ event_count\n");
    s.push_str("    add     r4, r4, #4      @ skip to first event entry\n");
    s.push_str(".Lpfe_loop:\n");
    s.push_str("    cmp     r3, #0\n");
    s.push_str("    beq     .Lpfe_done\n");
    s.push_str("    ldrb    r5, [r4]        @ table hash\n");
    s.push_str("    cmp     r5, r1          @ compare with input hash\n");
    s.push_str("    bne     .Lpfe_next\n");
    // match: write target_state
    s.push_str("    ldrb    r5, [r4, #1]    @ target_state\n");
    s.push_str("    strb    r5, [r2, #18]   @ pool.sm_state = target\n");
    s.push_str("    b       .Lpfe_done\n");
    s.push_str(".Lpfe_next:\n");
    s.push_str("    sub     r3, r3, #1\n");
    s.push_str("    add     r4, r4, #4\n");
    s.push_str("    b       .Lpfe_loop\n");
    s.push_str(".Lpfe_done:\n");
    s.push_str("    pop     {r2, r3, r4, r5, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

fn emit_pitrex_get_frame_us() -> String {
    // pitrex_get_frame_us() → r0 = µs elapsed since last v_WaitRecal returned.
    // Uses BCM system timer CLO (offset +4 from bcm2835_st base pointer).
    // Returns 0 on the first frame (FRAME_WORK_START == 0).
    let mut s = String::new();
    s.push_str("@ pitrex_get_frame_us() → r0 = µs since last WAIT_RECAL\n");
    s.push_str(".global pitrex_get_frame_us\n.type pitrex_get_frame_us, %function\npitrex_get_frame_us:\n");
    s.push_str("    push    {r1, r2, lr}\n");
    s.push_str("    ldr     r1, =bcm2835_st\n");
    s.push_str("    ldr     r1, [r1]            @ r1 = ST base ptr\n");
    s.push_str("    ldr     r1, [r1, #4]        @ r1 = CLO (current µs)\n");
    s.push_str("    ldr     r2, =FRAME_WORK_START\n");
    s.push_str("    ldr     r2, [r2]            @ r2 = work window start µs\n");
    s.push_str("    cmp     r2, #0\n");
    s.push_str("    moveq   r0, #0              @ first frame: return 0\n");
    s.push_str("    subne   r0, r1, r2          @ r0 = CLO - FRAME_WORK_START\n");
    s.push_str("    pop     {r1, r2, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ── Tests ─────────────────────────────────────────────────────────────────────
//
// These tests simulate the pitrex_draw_anim state machine in Rust, mirroring
// the ARM32 assembly logic exactly. If a test fails here, the corresponding
// ARM code has a logic bug. If tests pass but hardware shows wrong behaviour,
// the issue is environmental (BSS not zeroed, overlapping memory, etc.).

#[cfg(test)]
mod tests {
    /// Simulates one call to pitrex_draw_anim, replicating the ARM par_tick /
    /// par_init_frame / par_draw / par_draw_frame state machine.
    ///
    /// `state`: [frame_idx, ticks_left]  (mirrors PITREX_ANIM_STATE_BUF)
    /// `durations`: slice of duration_ticks for each frame
    /// `speed_mul`: multiplier (1 = no change)
    /// Returns: frame index that was drawn this call
    fn sim_draw_anim(state: &mut [u8; 2], durations: &[u8], speed_mul: u8) -> u8 {
        let frame_count = durations.len() as u8;
        let ticks_left = state[1];

        // par_tick
        if ticks_left == 0 {
            // par_init_frame path (first call or just-advanced)
            let ticks = {
                let t = durations[state[0] as usize];
                if speed_mul > 1 { t.saturating_mul(speed_mul) } else { t }.max(1)
            };
            state[1] = ticks;
            return state[0];
        }

        let new_ticks = ticks_left - 1;
        if new_ticks > 0 {
            // par_draw: still ticking
            state[1] = new_ticks;
            return state[0];
        }

        // ticks exhausted → advance frame
        let next = state[0] + 1;
        let next = if next >= frame_count { 0 } else { next }; // loop=true always in our tests
        state[0] = next;

        // par_init_frame for new frame
        let ticks = {
            let t = durations[next as usize];
            if speed_mul > 1 { t.saturating_mul(speed_mul) } else { t }.max(1)
        };
        state[1] = ticks;
        next
    }

    #[test]
    fn test_first_call_draws_frame_0() {
        let mut state = [0u8; 2]; // BSS-zeroed
        let durations = [8u8, 8, 8, 8]; // 4 frames × 8 ticks
        let frame = sim_draw_anim(&mut state, &durations, 1);
        assert_eq!(frame, 0, "first call must draw frame 0");
        assert_eq!(state, [0, 8], "after first call: frame_idx=0, ticks_left=8");
    }

    #[test]
    fn test_frame_holds_for_duration() {
        let mut state = [0u8; 2];
        let durations = [8u8, 8, 8, 8];
        // Calls 1-8 all draw frame 0
        for call in 1..=8 {
            let frame = sim_draw_anim(&mut state, &durations, 1);
            assert_eq!(frame, 0, "call {call}: should still be frame 0");
        }
        // Call 9 advances to frame 1
        let frame = sim_draw_anim(&mut state, &durations, 1);
        assert_eq!(frame, 1, "call 9 must advance to frame 1");
    }

    #[test]
    fn test_full_cycle_4_frames_8_ticks() {
        let mut state = [0u8; 2];
        let durations = [8u8, 8, 8, 8];
        let mut drawn = Vec::new();
        for _ in 0..32 {
            drawn.push(sim_draw_anim(&mut state, &durations, 1));
        }
        // Expected: 8×frame0, 8×frame1, 8×frame2, 8×frame3
        let expected: Vec<u8> = [0u8, 1, 2, 3].iter().flat_map(|&f| vec![f; 8]).collect();
        assert_eq!(drawn, expected, "32 calls should produce exactly one full cycle");
    }

    #[test]
    fn test_loop_wraps_to_frame_0() {
        let mut state = [0u8; 2];
        let durations = [8u8, 8, 8, 8];
        // Advance through one full cycle (32 calls)
        for _ in 0..32 {
            sim_draw_anim(&mut state, &durations, 1);
        }
        // Call 33 should be back to frame 0
        let frame = sim_draw_anim(&mut state, &durations, 1);
        assert_eq!(frame, 0, "after full cycle, must wrap back to frame 0");
    }

    #[test]
    fn test_speed_mul_2_doubles_duration() {
        let mut state = [0u8; 2];
        let durations = [4u8, 4, 4, 4]; // 4 ticks * speed_mul=2 = 8 ticks each
        // With speed_mul=2 each frame should last 8 calls
        for call in 1..=8 {
            let frame = sim_draw_anim(&mut state, &durations, 2);
            assert_eq!(frame, 0, "call {call}: speed_mul=2 should hold frame 0 for 8 calls");
        }
        let frame = sim_draw_anim(&mut state, &durations, 2);
        assert_eq!(frame, 1, "call 9: speed_mul=2 should advance to frame 1");
    }

    #[test]
    fn test_single_frame_anim_stays_on_frame_0() {
        let mut state = [0u8; 2];
        let durations = [5u8]; // 1 frame only (loop wraps to 0)
        for call in 1..=20 {
            let frame = sim_draw_anim(&mut state, &durations, 1);
            assert_eq!(frame, 0, "call {call}: single-frame anim must always draw frame 0");
        }
    }

    #[test]
    fn test_player_walk_4frames_8ticks_cycle_matches_anim_tick() {
        // This replicates the exact SnowBros player_walk animation:
        //   4 frames (walk1/2/3/4), duration_ticks=8, loop=true
        // VPy anim_tick increments by 1 each DRAW_ANIM call and wraps at 32.
        // anim_tick/8 should always equal the drawn frame index.
        let mut state = [0u8; 2];
        let durations = [8u8, 8, 8, 8];
        for anim_tick in 0u8..32 {
            let frame = sim_draw_anim(&mut state, &durations, 1);
            let expected_frame = anim_tick / 8;
            assert_eq!(
                frame, expected_frame,
                "anim_tick={anim_tick}: drawn frame {frame} != expected {expected_frame}"
            );
        }
    }

    // ── Bug 3 regression tests ────────────────────────────────────────────────

    /// Regression test for Bug 3 (part A): pitrex_spawn_enemies must set is_anim
    /// in the pool entry from the ROM record's is_anim byte.
    ///
    /// The is_anim byte lives at ROM offset `12 + wp_count*4` (variable, after
    /// all waypoints).  The generated code computes that offset into r6 and reads
    /// via `ldrb r8, [r4, r6]`, then stores to pool[+27].
    #[test]
    fn test_pitrex_spawn_sets_is_anim_from_rom() {
        let asm = super::emit_pitrex_spawn_enemies();

        // Must compute variable offset (12 + wp_count*4) and read via register-indexed load
        assert!(
            asm.contains("[r4, r10]"),
            "Bug 3A regression: pitrex_spawn must read ROM[12+wp_count*4] via [r4, r10] (got: ...)"
        );
        // Must store is_anim into pool offset +27
        assert!(
            asm.contains("[r6, #27]"),
            "Bug 3A regression: pitrex_spawn must write pool[+27] for is_anim (got: ...)"
        );
        // The read must come before the store
        let rom_read_pos  = asm.find("[r4, r10]").unwrap();
        let pool27_pos = asm.find("[r6, #27]").unwrap();
        assert!(
            rom_read_pos < pool27_pos,
            "Bug 3A regression: ROM is_anim must be read before pool[+27] is written"
        );
    }

    /// Regression test for Bug 3 (part B): pitrex_draw_enemies must read the
    /// frame_table_offset from the animation header byte 3 instead of
    /// hardcoding the value 4.
    ///
    /// Hardcoding `add r10, r10, #4` is wrong for animations that have base_refs
    /// (base_ref_count > 0), because the frame table starts at
    /// `4 + base_ref_count * 4`, not at 4.  The correct code reads byte 3 of
    /// the header (`ldrb r10, [r6, #3]`).
    ///
    /// Previously the generated code contained:
    ///   lsl  r10, r11, #2
    ///   add  r10, r10, #4   ← hardcoded offset 4
    ///   ldr  r10, [r6, r10]
    ///
    /// After the fix it must contain:
    ///   ldrb r10, [r6, #3]  ← read frame_table_offset from header
    ///   ...
    ///   add  r10, r10, r9   ← dynamic offset
    #[test]
    fn test_pitrex_draw_enemies_reads_frame_table_offset_from_header() {
        let asm = super::emit_pitrex_draw_enemies();

        // The fixed code must read frame_table_offset from anim header byte 3.
        assert!(
            asm.contains("[r6, #3]"),
            "Bug 3B regression: pitrex_draw_enemies must read frame_table_offset from \
             anim_header[3] (ldrb r10, [r6, #3])"
        );

        // The OLD hardcoded `add r10, r10, #4` must NOT appear in the anim path.
        // (Only the first occurrence matters; search within the .Lpde_anim block.)
        let anim_label_pos = asm.find(".Lpde_anim:").expect(".Lpde_anim label must exist");
        let anim_draw_pos  = asm.find(".Lpde_anim_draw:").expect(".Lpde_anim_draw label must exist");
        let anim_section   = &asm[anim_label_pos..anim_draw_pos];
        assert!(
            !anim_section.contains("add     r10, r10, #4"),
            "Bug 3B regression: hardcoded `add r10, r10, #4` found in .Lpde_anim block; \
             frame_table_offset must be read from header byte 3 instead"
        );
    }
}
