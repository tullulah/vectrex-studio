//! ARM Thumb2 drawing engine for the RP2350 bus-master firmware.
//!
//! ## API
//!   smul_lut(r0=val i8, r1=angle 0-127) → r0=(val*sin(angle))>>7
//!   dv_reset()                 — reset integrators, set ACR=$18
//!   dv_move_to(r0=dx, r1=dy)   — move beam (no draw), T1-timed
//!   dv_draw_delta(r0=dx, r1=dy)— draw segment, T1-timed
//!   vpy_draw_vector(r0=ptr)    — walk _NAME_VECTORS draw list
//!   vpy_draw_vector_3d(r0,r1=ax,r2=ay,r3=az,[sp+36]=ox,[sp+40]=oy)
//!
//! ## VIA drawing sequence (M6809 DV3D_MOVETO/DV3D_DRAWLINE)
//!   PORT_A←dy, PORT_B←0 (Y), settle, PORT_B←1 (X), PORT_A←dx,
//!   SR←($FF draw / $00 move), T1L_L←$7F, T1C_H←0, poll IFR[6],
//!   SR←$00 (draw only), read T1C_L (clear IFR)
//!
//! ## 3D rotation: Euler X→Y→Z, cos(a)=sin((a+32)&0x7F)
//!   y1=smul(ry,cX)-smul(rz,sX)   z1=smul(ry,sX)+smul(rz,cX)
//!   x2=smul(rx,cY)+smul(z1,sY)
//!   sx=smul(x2,cZ)-smul(y1,sZ)+ox   sy=smul(x2,sZ)+smul(y1,cZ)+oy

use super::analysis::Usage;

pub fn emit_drawing(usage: &Usage) -> String {
    let mut s = String::new();
    s.push_str("@ ============================================================\n");
    s.push_str("@ Drawing engine — ARM Thumb2 / RP2350 bus master\n");
    s.push_str("@ ============================================================\n\n");
    // _SIN_TABLE + smul_lut: needed by vpy_sin/vpy_cos (TRIG) and
    // vpy_draw_vector_3d — both enable the SIN_TABLE group.
    if usage.has("SIN_TABLE") {
        s.push_str(&emit_sin_table());
        s.push_str(&emit_smul_lut());
    }
    // Core beam primitives: ALWAYS emitted (tiny SVC stubs; the IDE emulator
    // traps these symbols and every drawing routine calls them).
    s.push_str(&emit_dv_reset());
    s.push_str(&emit_dv_move_to());
    s.push_str(&emit_dv_draw_delta());
    if usage.has("DRAW_VECTOR") {
        s.push_str(&emit_draw_vector());
    }
    if usage.has("DRAW_VECTOR_3D") {
        s.push_str(&emit_draw_vector_3d());
    }
    if usage.has("DRAW_RECORDING") {
        s.push_str(&emit_draw_recording());
    }
    s
}

// ─── SIN_TABLE ────────────────────────────────────────────────────────────

pub fn emit_sin_table() -> String {
    let entries: Vec<i8> = (0usize..128)
        .map(|i| {
            let r = (i as f64) * 2.0 * std::f64::consts::PI / 128.0;
            (r.sin() * 127.0).round() as i8
        })
        .collect();
    let mut s = String::new();
    s.push_str("@ SIN_TABLE[128]: sin(i*2π/128)*127 as i8\n");
    s.push_str(".global _SIN_TABLE\n_SIN_TABLE:\n");
    for row in entries.chunks(16) {
        let v: Vec<String> = row.iter().map(|&b| format!("0x{:02X}", b as u8)).collect();
        s.push_str(&format!("    .byte   {}\n", v.join(", ")));
    }
    s.push('\n');
    s
}

// ─── smul_lut ─────────────────────────────────────────────────────────────

fn emit_smul_lut() -> String {
    // r0=val(i8), r1=angle(0-127) → r0=(val*sin)>>7. Clobbers r2.
    let mut s = String::new();
    s.push_str("@ smul_lut(r0=val i8, r1=angle 0-127) → r0=(val*sin)>>7\n");
    s.push_str(".global smul_lut\n.type smul_lut, %function\n.thumb_func\nsmul_lut:\n");
    s.push_str("    ldr     r2, =_SIN_TABLE\n");
    s.push_str("    and     r1, r1, #0x7F\n");
    s.push_str("    ldrb    r2, [r2, r1]\n");
    s.push_str("    sxtb    r2, r2\n");
    s.push_str("    sxtb    r0, r0\n");
    s.push_str("    mul     r0, r0, r2\n");
    s.push_str("    asr     r0, r0, #7\n");
    s.push_str("    bx      lr\n\n");
    s
}

// ─── dv_reset ─────────────────────────────────────────────────────────────

// BIOS-linked emission: the system primitives are SVC stubs into the cartridge
// BIOS (see docs/RP2350_BIOS.md and the firmware's syscalls.rs — the canonical
// numbering; append-only). The BIOS owns the real hardware protocol (E-synced
// CS-gated bus writes, BIOS.ASM-exact VIA sequences). The emulator traps these
// SYMBOLS before executing their bodies, so it works unchanged (its Thumb2
// core also treats a reached SVC as NOP).

fn emit_dv_reset() -> String {
    let mut s = String::new();
    s.push_str("@ dv_reset() — BIOS trap: SYS_RESET0REF\n");
    s.push_str(".global dv_reset\n.type dv_reset, %function\n.thumb_func\ndv_reset:\n");
    s.push_str("    svc     #0                      @ SYS_RESET0REF\n");
    s.push_str("    bx      lr\n\n");
    s
}

// ─── dv_move_to ───────────────────────────────────────────────────────────

fn emit_dv_move_to() -> String {
    let mut s = String::new();
    s.push_str("@ dv_move_to(r0=dx, r1=dy) — BIOS trap: SYS_MOVE (a ramped delta after a\n");
    s.push_str("@ reset). Split into <=127-per-axis steps: a scrolled origin can land far\n");
    s.push_str("@ past the i8 DAC range, and SYS_MOVE casts to i8 → the whole shape WRAPS to\n");
    s.push_str("@ the wrong side of the screen (mario_poc floor tiles). SYS_MOVE ramps the\n");
    s.push_str("@ INTEGRATORS (velocity×time), not an absolute DAC, so stepping accumulates\n");
    s.push_str("@ to the true (off-screen) origin — the visible part draws in place and the\n");
    s.push_str("@ physical screen clips the rest. A move already within +/-127 does one step\n");
    s.push_str("@ (unchanged).\n");
    s.push_str(".global dv_move_to\n.type dv_move_to, %function\n.thumb_func\ndv_move_to:\n");
    s.push_str("    push    {r2, r3, r4, r5, r6, r7, lr}  @ callers assume traps preserve regs\n");
    s.push_str("    mov     r4, r0                  @ remaining dx\n");
    s.push_str("    mov     r5, r1                  @ remaining dy\n");
    s.push_str("    mov     r6, #127\n");
    s.push_str("    rsb     r7, r6, #0              @ r7 = -127\n");
    s.push_str("dvmt_loop:\n");
    s.push_str("    mov     r0, r4                  @ step_x = clamp(remaining_x, -127, 127)\n");
    s.push_str("    cmp     r0, r6\n    it      gt\n    movgt   r0, r6\n");
    s.push_str("    cmp     r0, r7\n    it      lt\n    movlt   r0, r7\n");
    s.push_str("    mov     r1, r5                  @ step_y = clamp(remaining_y, -127, 127)\n");
    s.push_str("    cmp     r1, r6\n    it      gt\n    movgt   r1, r6\n");
    s.push_str("    cmp     r1, r7\n    it      lt\n    movlt   r1, r7\n");
    s.push_str("    push    {r0, r1}                @ svc clobbers r0; keep the steps\n");
    s.push_str("    svc     #3                      @ SYS_MOVE (this step)\n");
    s.push_str("    pop     {r0, r1}\n");
    s.push_str("    subs    r4, r4, r0              @ remaining -= step\n");
    s.push_str("    subs    r5, r5, r1\n");
    s.push_str("    orrs    r2, r4, r5              @ both zero? → done\n");
    s.push_str("    bne     dvmt_loop\n");
    s.push_str("    pop     {r2, r3, r4, r5, r6, r7, pc}\n\n");
    s
}

// ─── dv_draw_delta ────────────────────────────────────────────────────────

fn emit_dv_draw_delta() -> String {
    let mut s = String::new();
    s.push_str("@ dv_draw_delta(r0=dx, r1=dy) — BIOS trap: SYS_DRAW_DELTA\n");
    s.push_str(".global dv_draw_delta\n.type dv_draw_delta, %function\n.thumb_func\ndv_draw_delta:\n");
    s.push_str("    svc     #4                      @ SYS_DRAW_DELTA\n");
    s.push_str("    bx      lr\n\n");
    s
}

// ─── vpy_draw_vector ──────────────────────────────────────────────────────
//
// _NAME_VECTORS format (arm/assets.rs):
//   .word  path_count
//   .word  ptr_path0, ptr_path1, ...
// _NAME_PATHn:
//   .byte  intensity, y_start (i8), x_start (i8), 0, 0
//   .byte  0xFF, dy, dx   (line)  |  .byte 0x02 (end)
//
// r0 = asset_ptr
// Register map: r4=asset, r5=path_count, r6=path_idx, r7=path_ptr, r8=cmd_ptr
// ---------------------------------------------------------------------------
fn emit_draw_vector() -> String {
    let mut s = String::new();
    s.push_str("@ vpy_draw_vector(r0=asset_ptr, r1=ox, r2=oy)\n");
    s.push_str("@ Draws asset at screen position (ox, oy). ox=0, oy=0 = screen centre.\n");
    s.push_str(".global vpy_draw_vector\n.type vpy_draw_vector, %function\n.thumb_func\nvpy_draw_vector:\n");
    // Save r9=ox, r10=oy alongside the previous callee-saves.
    // dv_reset / vpy_set_intensity / dv_move_to / dv_draw_delta are traps and
    // do NOT modify any CPU registers, so we don't need to push/pop around them.
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}\n");
    s.push_str("    mov     r4, r0              @ asset_ptr\n");
    s.push_str("    mov     r9, r1              @ ox\n");
    s.push_str("    mov     r10, r2             @ oy\n");
    s.push_str("    ldr     r5, [r4]            @ path_count\n");
    s.push_str("    mov     r6, #0              @ path index\n");

    s.push_str("dvv_pl:\n");
    s.push_str("    cmp     r6, r5\n    bge     dvv_done\n");
    s.push_str("    lsl     r7, r6, #2\n    add     r7, r7, #4\n    ldr     r7, [r4, r7]\n"); // path ptr
    // Reset beam before each path so every path starts from a known centre reference.
    s.push_str("    bl      dv_reset\n");
    // Per-path .vec intensity in r0; if SET_INTENSITY set an override this frame,
    // use it instead (r1 scratch, reloaded right after). vpy_set_intensity is DAC-
    // only and does NOT record the override, so per-path intensities stay intact.
    s.push_str("    ldrb    r0, [r7]            @ per-path .vec intensity\n");
    s.push_str("    ldr     r1, =VPY_BRIGHTNESS_OVERRIDE\n    ldrb    r1, [r1]\n");
    s.push_str("    cmp     r1, #0\n    it      ne\n    movne   r0, r1  @ SET_INTENSITY override wins\n");
    s.push_str("    bl      vpy_set_intensity\n");
    // Move to (x_start + ox, y_start + oy) — places path relative to object origin.
    s.push_str("    ldrsb   r0, [r7, #2]\n    add     r0, r0, r9\n");  // x = x_start + ox
    s.push_str("    ldrsb   r1, [r7, #1]\n    add     r1, r1, r10\n"); // y = y_start + oy
    s.push_str("    bl      dv_move_to\n");
    s.push_str("    add     r8, r7, #5\n");                            // command ptr

    s.push_str("dvv_cl:\n");
    s.push_str("    ldrb    r0, [r8]\n");
    s.push_str("    cmp     r0, #0x02\n    beq     dvv_cend\n");
    s.push_str("    cmp     r0, #0xFF\n    bne     dvv_cskip\n");
    s.push_str("    ldrsb   r0, [r8, #2]\n"); // dx
    s.push_str("    ldrsb   r1, [r8, #1]\n"); // dy
    s.push_str("    bl      dv_draw_delta\n");
    s.push_str("    add     r8, r8, #3\n    b       dvv_cl\n");
    s.push_str("dvv_cskip:\n    add     r8, r8, #1\n    b       dvv_cl\n");
    s.push_str("dvv_cend:\n    add     r6, r6, #1\n    b       dvv_pl\n");

    s.push_str("dvv_done:\n    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ─── vpy_draw_vector_3d ───────────────────────────────────────────────────
//
// _NAME_3D_DATA format (arm/assets.rs):
//   .word  vertex_count
//   .byte  vx,vy,vz × N   (clamped ±63)
//   .word  path_count
//   .byte  pt_count, closed, idx0, idx1, ...   (per path)
//
// Calling convention (9 regs saved = 36 bytes before stack args):
//   r0=asset, r1=ax, r2=ay, r3=az, [sp+36]=ox, [sp+40]=oy
//
// Phase 1 registers: r4=ROM_ptr, r5=ax, r6=ay, r7=az, r8=ox, r9=oy,
//                    r10=vert_count, r11=vbuf_write_ptr
// Phase 2 registers: r4=ROM_ptr, r5=pt_count, r6=closed, r7=idx_ptr,
//                    r8=first_x, r9=first_y, r10=path_count, r11=vbuf_base
//
// RAM (defined in ram_layout.rs):
//   _dv3d_cos[3]: cos_ax, cos_ay, cos_az
//   _dv3d_tmp[3]: rx, ry, rz  (current vertex raw coords)
//   _dv3d_sm[4]:  t0, y1, z1, x2  (rotation intermediates)
//   _dv3d_vbuf[254]: rotated (sx,sy) pairs
//   _dv3d_cur[2]: current beam position (cur_x, cur_y)
// ---------------------------------------------------------------------------
fn emit_draw_vector_3d() -> String {
    let mut s = String::new();
    s.push_str("@ vpy_draw_vector_3d(r0,r1=ax,r2=ay,r3=az,[sp+36]=ox,[sp+40]=oy)\n");
    s.push_str(".global vpy_draw_vector_3d\n.type vpy_draw_vector_3d, %function\n.thumb_func\nvpy_draw_vector_3d:\n");
    s.push_str("    push    {r4,r5,r6,r7,r8,r9,r10,r11,lr}\n");
    s.push_str("    mov     r4, r0\n");
    s.push_str("    mov     r5, r1               @ ax\n");
    s.push_str("    mov     r6, r2               @ ay\n");
    s.push_str("    mov     r7, r3               @ az\n");
    s.push_str("    ldrsb   r8, [sp, #36]        @ ox (sign-extend)\n");
    s.push_str("    ldrsb   r9, [sp, #40]        @ oy\n");

    // Precompute cos offsets → _dv3d_cos[3]
    s.push_str("    ldr     r0, =_dv3d_cos\n");
    s.push_str("    add     r1, r5, #32\n    and r1,r1,#0x7F\n    strb r1,[r0]\n");    // cos_ax
    s.push_str("    add     r1, r6, #32\n    and r1,r1,#0x7F\n    strb r1,[r0,#1]\n"); // cos_ay
    s.push_str("    add     r1, r7, #32\n    and r1,r1,#0x7F\n    strb r1,[r0,#2]\n"); // cos_az

    // Phase 1: rotate vertices
    s.push_str("    ldr     r10, [r4]\n    add r4,r4,#4\n"); // vertex_count; advance past it
    s.push_str("    ldr     r11, =_dv3d_vbuf\n");

    s.push_str("dv3_vl:\n    cmp r10,#0\n    beq dv3_vd\n    sub r10,r10,#1\n");

    // Save rx,ry,rz to _dv3d_tmp
    s.push_str("    ldr     r0, =_dv3d_tmp\n");
    s.push_str("    ldrsb   r1, [r4]\n    strb r1,[r0]\n");
    s.push_str("    ldrsb   r1, [r4,#1]\n  strb r1,[r0,#1]\n");
    s.push_str("    ldrsb   r1, [r4,#2]\n  strb r1,[r0,#2]\n");
    s.push_str("    add     r4, r4, #3\n");

    // Helper macro-like expansion: smul(val_ptr_offset, angle_reg) → result in r0
    // X-axis: y1 = ry*cos_ax - rz*sin_ax
    smul_call(&mut s, "_dv3d_tmp", 1, "_dv3d_cos", 0);  // r0 = ry*cos_ax
    s.push_str("    ldr     r2,=_dv3d_sm\n    strb r0,[r2]\n");  // sm[0]=t0
    smul_call_reg(&mut s, "_dv3d_tmp", 2, "r5");          // r0 = rz*sin_ax
    s.push_str("    ldr     r2,=_dv3d_sm\n    ldrsb r3,[r2]\n    sub r0,r3,r0\n    strb r0,[r2,#1]\n"); // y1

    // z1 = ry*sin_ax + rz*cos_ax
    smul_call_reg(&mut s, "_dv3d_tmp", 1, "r5");           // r0 = ry*sin_ax
    s.push_str("    ldr     r2,=_dv3d_sm\n    strb r0,[r2]\n");
    smul_call(&mut s, "_dv3d_tmp", 2, "_dv3d_cos", 0);    // r0 = rz*cos_ax
    s.push_str("    ldr     r2,=_dv3d_sm\n    ldrsb r3,[r2]\n    add r0,r0,r3\n    strb r0,[r2,#2]\n"); // z1

    // Y-axis: x2 = rx*cos_ay + z1*sin_ay
    smul_call(&mut s, "_dv3d_tmp", 0, "_dv3d_cos", 1);    // r0 = rx*cos_ay
    s.push_str("    ldr     r2,=_dv3d_sm\n    strb r0,[r2]\n");
    smul_call_sm(&mut s, 2, "r6");                          // r0 = z1*sin_ay
    s.push_str("    ldr     r2,=_dv3d_sm\n    ldrsb r3,[r2]\n    add r0,r0,r3\n    strb r0,[r2,#3]\n"); // x2

    // Z-axis: sx = x2*cos_az - y1*sin_az + ox
    smul_call_sm_az(&mut s, 3, "r7");                       // r0 = x2*cos_az
    s.push_str("    ldr     r2,=_dv3d_sm\n    strb r0,[r2]\n");
    smul_call_sm_az_r(&mut s, 1, "r7");                     // r0 = y1*sin_az (was sm_az → cos bug)
    s.push_str("    ldr     r2,=_dv3d_sm\n    ldrsb r3,[r2]\n    sub r0,r3,r0\n    add r0,r0,r8\n"); // +ox
    s.push_str("    strb    r0,[r11]\n");                   // vbuf[i].sx

    // sy = x2*sin_az + y1*cos_az + oy
    smul_call_sm_az_r(&mut s, 3, "r7");                    // r0 = x2*sin_az
    s.push_str("    ldr     r2,=_dv3d_sm\n    strb r0,[r2]\n");
    smul_call_sm_cos_az(&mut s, 1);                         // r0 = y1*cos_az
    s.push_str("    ldr     r2,=_dv3d_sm\n    ldrsb r3,[r2]\n    add r0,r0,r3\n    add r0,r0,r9\n"); // +oy
    s.push_str("    strb    r0,[r11,#1]\n");                // vbuf[i].sy
    s.push_str("    add     r11,r11,#2\n    b dv3_vl\n");

    s.push_str("dv3_vd:\n"); // vertices done
    // The vertex section is vertex_count*3 bytes and may leave r4 off a 4-byte
    // boundary; align r4 to match the `.balign 4` the asset emitter inserts
    // before the path_count word.
    s.push_str("    add     r4, r4, #3\n    bic r4, r4, #3\n");

    // Phase 2: draw paths. Load path_count and the vbuf base up front; the
    // per-path Reset0Ref lives INSIDE the loop (below).
    s.push_str("    ldr     r10,[r4]\n    add r4,r4,#4\n"); // path_count
    s.push_str("    ldr     r11,=_dv3d_vbuf\n");           // vbuf base for lookup

    s.push_str("dv3_pl:\n    cmp r10,#0\n    beq dv3_pd\n    sub r10,r10,#1\n");
    // RE-ZERO PER PATH: draw every path from a fresh Reset0Ref so integrator
    // error cannot accumulate ACROSS paths. On real HW the analog integrators
    // drift a little per relative move; with a single zero for the whole shape
    // the later paths inherited every prior path's drift and trembled worst
    // (path 4 ≫ path 1). Zeroing per path caps the accumulation to ONE path.
    // dv_reset zeroes the Z-DAC too, so re-assert intensity; then the path's
    // first vertex is reached as an ABSOLUTE move from the centred (0,0).
    s.push_str("    bl      dv_reset\n");
    s.push_str("    mov     r0, #127            @ default 3D intensity\n");
    s.push_str("    ldr     r1, =VPY_BRIGHTNESS_OVERRIDE\n    ldrb    r1, [r1]\n");
    s.push_str("    cmp     r1, #0\n    it      ne\n    movne   r0, r1  @ SET_INTENSITY override wins\n");
    s.push_str("    bl      vpy_set_intensity\n");
    s.push_str("    ldr     r0,=_dv3d_cur\n    mov r1,#0\n    strh r1,[r0]\n"); // cur=(0,0)
    s.push_str("    ldrb    r5,[r4]              @ pt_count\n");
    s.push_str("    ldrb    r6,[r4,#1]           @ closed\n");
    s.push_str("    add     r4,r4,#2\n");
    s.push_str("    cmp     r5,#0\n    beq dv3_pnext_emp\n");

    // r7 = index ptr (starts at r4)
    s.push_str("    mov     r7, r4\n");

    // First vertex: MOVE
    s.push_str("    ldrb    r0,[r7]\n    lsl r2,r0,#1\n");  // offset = idx*2
    s.push_str("    ldrsb   r0,[r11,r2]\n");                 // sx
    s.push_str("    add     r2,r2,#1\n    ldrsb r1,[r11,r2]\n"); // sy
    // Compute delta from _dv3d_cur; save (sx,sy) as new cur and as first_x/y
    s.push_str("    ldr     r2,=_dv3d_cur\n");
    s.push_str("    ldrsb   r3,[r2,#0]\n    sub r0,r0,r3\n"); // dx=sx-cur_x
    s.push_str("    ldrsb   r3,[r2,#1]\n    sub r1,r1,r3\n"); // dy=sy-cur_y
    // Restore absolute target to update cur + save first point
    // We need target_sx and target_sy before the sub — re-read from vbuf
    s.push_str("    push    {r0,r1}\n");                     // save dx,dy
    s.push_str("    ldrb    r0,[r7]\n    lsl r2,r0,#1\n");
    s.push_str("    ldrsb   r8,[r11,r2]\n");                 // r8=first_x=sx
    s.push_str("    add     r2,r2,#1\n    ldrsb r9,[r11,r2]\n"); // r9=first_y=sy
    s.push_str("    ldr     r2,=_dv3d_cur\n    strb r8,[r2]\n    strb r9,[r2,#1]\n");
    s.push_str("    pop     {r0,r1}\n");                     // restore dx,dy
    s.push_str("    bl      dv_move_to\n");
    s.push_str("    sub     r5,r5,#1\n    add r7,r7,#1\n");  // consumed first vertex

    s.push_str("dv3_vxtx:\n");
    s.push_str("    cmp     r5,#0\n    beq dv3_close\n    sub r5,r5,#1\n");
    s.push_str("    ldrb    r0,[r7]\n    lsl r2,r0,#1\n");
    s.push_str("    ldrsb   r0,[r11,r2]\n");                 // sx
    s.push_str("    add     r2,r2,#1\n    ldrsb r1,[r11,r2]\n"); // sy
    // Push absolute target; compute delta; call draw; restore target to cur
    s.push_str("    push    {r0,r1}\n");
    s.push_str("    ldr     r2,=_dv3d_cur\n");
    s.push_str("    ldrsb   r3,[r2,#0]\n    sub r0,r0,r3\n");
    s.push_str("    ldrsb   r3,[r2,#1]\n    sub r1,r1,r3\n");
    s.push_str("    bl      dv_draw_delta\n");
    s.push_str("    pop     {r0,r1}\n");                     // sx, sy
    s.push_str("    ldr     r2,=_dv3d_cur\n    strb r0,[r2]\n    strb r1,[r2,#1]\n");
    s.push_str("    add     r7,r7,#1\n    b dv3_vxtx\n");

    s.push_str("dv3_close:\n");
    s.push_str("    cmp     r6,#0\n    beq dv3_pnext\n");   // not closed
    // Draw back to first vertex
    s.push_str("    ldr     r2,=_dv3d_cur\n");
    s.push_str("    ldrsb   r3,[r2,#0]\n    sub r0,r8,r3\n"); // dx=first_x-cur_x
    s.push_str("    ldrsb   r3,[r2,#1]\n    sub r1,r9,r3\n"); // dy=first_y-cur_y
    s.push_str("    bl      dv_draw_delta\n");
    s.push_str("    ldr     r2,=_dv3d_cur\n    strb r8,[r2]\n    strb r9,[r2,#1]\n");

    s.push_str("dv3_pnext:\n");
    s.push_str("    mov     r4,r7\n    b dv3_pl\n");  // r7=past last idx = next path header

    s.push_str("dv3_pnext_emp:\n");
    // empty path: 0 index bytes consumed, r4 already points to next path
    s.push_str("    b       dv3_pl\n");

    s.push_str("dv3_pd:\n");
    s.push_str("    pop     {r4,r5,r6,r7,r8,r9,r10,r11,pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ─── vpy_draw_recording ───────────────────────────────────────────────────
//
// POLYLINE-CHAINED player. _NAME_VREC format (arm/assets.rs compile_vrec):
//   .word  frame_count
//   .word  offset_frame0, offset_frame1, ...   @ byte offsets from _NAME_VREC
// frame N (2-byte aligned):
//   .hword chain_count
//   per chain:
//     .byte start_x, start_y, intensity, seg_count   (i8,i8,u8,u8 — 4 bytes)
//     .byte dx, dy × seg_count                       (i8 deltas — 2*seg_count)
//
// vpy_draw_recording(r0=vrec_ptr, r1=x, r2=y, r3=scale, [sp+32]=frame)
//   scale: 0..128 where 128 = 100% — scaled = (v * scale) >> 7, sign preserved
//          (ldrsb sign-extends the i8 before the multiply).
//   frame: any non-negative counter; frame % frame_count is taken here so the
//          caller can pass an ever-increasing value.
//   Per CHAIN: dv_reset → vpy_set_intensity(i) → dv_move_to(x+sx0, y+sy0) ONCE,
//              then per delta: dv_draw_delta(scaled dx, scaled dy) with NO
//              reset/move between — the beam continues from the last endpoint.
//   Start point is scaled AND centered (coord*scale>>7 + offset); deltas are
//   scaled ONLY (relative — no center added), matching the m6809 player.
//   Recorded intensity is used, but a SET_INTENSITY override this frame wins
//   (same VPY_BRIGHTNESS_OVERRIDE convention as vpy_draw_vector).
//   Start targets and deltas are clamped to the i8 range [-127, 127].
//
// Register map: r4=cursor ptr, r5=chains remaining, r6=x, r7=y, r8=scale,
//               r9=deltas remaining in chain; r0-r3 scratch.
// dv_reset / vpy_set_intensity / dv_move_to / dv_draw_delta are SVC trap stubs
// and do NOT modify CPU registers (same assumption as vpy_draw_vector).
// ---------------------------------------------------------------------------
fn emit_draw_recording() -> String {
    // Clamp the value in `reg` to [-127, 127] using r2 as scratch.
    fn clamp_i8(s: &mut String, reg: &str) {
        s.push_str(&format!("    cmp     {reg}, #127\n    it      gt\n    movgt   {reg}, #127\n"));
        s.push_str("    mvn     r2, #126            @ r2 = -127\n");
        s.push_str(&format!("    cmp     {reg}, r2\n    it      lt\n    movlt   {reg}, r2\n"));
    }
    // r0 = (i8 at [r4, #off]) * scale >> 7  (sign preserved: ldrsb sign-extends)
    fn scale_byte(s: &mut String, off: u8) {
        s.push_str(&format!("    ldrsb   r0, [r4, #{off}]\n"));
        s.push_str("    mul     r0, r0, r8\n");
        s.push_str("    asr     r0, r0, #7\n");
    }

    let mut s = String::new();
    s.push_str("@ vpy_draw_recording(r0=vrec_ptr, r1=x, r2=y, r3=scale 0-128, [sp+32]=frame)\n");
    s.push_str(".global vpy_draw_recording\n.type vpy_draw_recording, %function\n.thumb_func\nvpy_draw_recording:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, lr}\n");
    s.push_str("    mov     r4, r0              @ vrec base\n");
    s.push_str("    mov     r6, r1              @ x offset\n");
    s.push_str("    mov     r7, r2              @ y offset\n");
    s.push_str("    mov     r8, r3              @ scale (0-128, 128 = 100%)\n");
    // frame_idx = frame % frame_count (sdiv+mul+sub — no mls, emulator-safe)
    s.push_str("    ldr     r1, [r4]            @ frame_count\n");
    s.push_str("    cmp     r1, #0\n    beq     dvrec_done          @ empty recording\n");
    s.push_str("    ldr     r0, [sp, #32]       @ frame counter (stack arg)\n");
    s.push_str("    sdiv    r2, r0, r1\n");
    s.push_str("    mul     r2, r2, r1\n");
    s.push_str("    sub     r0, r0, r2          @ frame % frame_count\n");
    // frame ptr = base + offset_table[idx]  (table starts at base+4)
    s.push_str("    add     r0, r0, #1\n");
    s.push_str("    lsl     r0, r0, #2          @ 4 + idx*4\n");
    s.push_str("    ldr     r0, [r4, r0]        @ byte offset from base\n");
    s.push_str("    add     r0, r4, r0          @ frame ptr\n");
    s.push_str("    ldrh    r5, [r0]            @ chain_count\n");
    s.push_str("    add     r4, r0, #2          @ r4 = first chain header\n");

    // ── per-chain loop ──
    s.push_str("dvrec_chain:\n");
    s.push_str("    cmp     r5, #0\n    beq     dvrec_done\n");
    // Beam to a known reference ONCE per chain (chain start is absolute).
    s.push_str("    bl      dv_reset\n");
    // Recorded intensity; SET_INTENSITY override wins (same rule as vpy_draw_vector).
    s.push_str("    ldrb    r0, [r4, #2]        @ recorded chain intensity\n");
    s.push_str("    ldr     r1, =VPY_BRIGHTNESS_OVERRIDE\n    ldrb    r1, [r1]\n");
    s.push_str("    cmp     r1, #0\n    it      ne\n    movne   r0, r1  @ SET_INTENSITY override wins\n");
    s.push_str("    bl      vpy_set_intensity\n");
    // seg_count (deltas in this chain) → r9
    s.push_str("    ldrb    r9, [r4, #3]        @ seg_count (deltas)\n");
    // dv_move_to(x + (start_x*scale>>7), y + (start_y*scale>>7)), clamped to i8
    scale_byte(&mut s, 0);
    s.push_str("    add     r0, r0, r6          @ x + scaled start_x\n");
    clamp_i8(&mut s, "r0");
    s.push_str("    mov     r10, r0             @ save clamped start x\n");
    scale_byte(&mut s, 1);
    s.push_str("    add     r1, r0, r7          @ y + scaled start_y\n");
    clamp_i8(&mut s, "r1");
    s.push_str("    mov     r0, r10\n");
    s.push_str("    bl      dv_move_to\n");
    // advance cursor past the 4-byte chain header to first delta pair
    s.push_str("    add     r4, r4, #4\n");

    // ── per-delta loop (relative draws, NO reset/move between) ──
    s.push_str("dvrec_delta:\n");
    s.push_str("    cmp     r9, #0\n    beq     dvrec_chain_next\n");
    // dx = scaled delta at [r4,#0]  (relative — NO center added)
    scale_byte(&mut s, 0);
    clamp_i8(&mut s, "r0");
    s.push_str("    mov     r10, r0             @ save clamped dx\n");
    // dy = scaled delta at [r4,#1]
    scale_byte(&mut s, 1);
    clamp_i8(&mut s, "r0");
    s.push_str("    mov     r1, r0              @ dy\n");
    s.push_str("    mov     r0, r10             @ dx\n");
    s.push_str("    bl      dv_draw_delta\n");
    // next delta pair
    s.push_str("    add     r4, r4, #2\n");
    s.push_str("    sub     r9, r9, #1\n");
    s.push_str("    b       dvrec_delta\n");

    s.push_str("dvrec_chain_next:\n");
    // r4 already points at the next chain header (past the last delta pair).
    s.push_str("    sub     r5, r5, #1\n");
    s.push_str("    b       dvrec_chain\n");

    s.push_str("dvrec_done:\n    pop     {r4, r5, r6, r7, r8, r9, r10, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ─── smul helper emitters ─────────────────────────────────────────────────

/// Load val from _dv3d_tmp[tmp_off], angle from _dv3d_cos[cos_off] → bl smul_lut
fn smul_call(s: &mut String, tmp_sym: &str, tmp_off: u8, cos_sym: &str, cos_off: u8) {
    s.push_str(&format!("    ldr     r0,={tmp_sym}\n    ldrsb   r0,[r0,#{tmp_off}]\n"));
    s.push_str(&format!("    ldr     r2,={cos_sym}\n    ldrb    r1,[r2,#{cos_off}]\n"));
    s.push_str("    bl      smul_lut\n");
}

/// Load val from _dv3d_tmp[tmp_off], angle from register → bl smul_lut
fn smul_call_reg(s: &mut String, tmp_sym: &str, tmp_off: u8, angle_reg: &str) {
    s.push_str(&format!("    ldr     r0,={tmp_sym}\n    ldrsb   r0,[r0,#{tmp_off}]\n"));
    s.push_str(&format!("    mov     r1,{angle_reg}\n"));
    s.push_str("    bl      smul_lut\n");
}

/// Load val from _dv3d_sm[sm_off], angle from register → bl smul_lut
fn smul_call_sm(s: &mut String, sm_off: u8, angle_reg: &str) {
    s.push_str(&format!("    ldr     r0,=_dv3d_sm\n    ldrsb   r0,[r0,#{sm_off}]\n"));
    s.push_str(&format!("    mov     r1,{angle_reg}\n"));
    s.push_str("    bl      smul_lut\n");
}

/// smul(_dv3d_sm[sm_off], cos_az) — reads cos_az from _dv3d_cos[2]
fn smul_call_sm_az(s: &mut String, sm_off: u8, _angle_reg: &str) {
    // angle_reg is az but we want sin_az; cos_az is in _dv3d_cos[2]
    // For sx: x2*cos_az → sm[3], cos_az = _dv3d_cos[2]
    s.push_str(&format!("    ldr     r0,=_dv3d_sm\n    ldrsb   r0,[r0,#{sm_off}]\n"));
    s.push_str("    ldr     r2,=_dv3d_cos\n    ldrb    r1,[r2,#2]\n"); // cos_az
    s.push_str("    bl      smul_lut\n");
}

/// smul(_dv3d_sm[sm_off], az)  — az is a register, used for sin_az
fn smul_call_sm_az_r(s: &mut String, sm_off: u8, angle_reg: &str) {
    s.push_str(&format!("    ldr     r0,=_dv3d_sm\n    ldrsb   r0,[r0,#{sm_off}]\n"));
    s.push_str(&format!("    mov     r1,{angle_reg}\n")); // sin_az = az
    s.push_str("    bl      smul_lut\n");
}

/// smul(_dv3d_sm[sm_off], cos_az) for y1*cos_az
fn smul_call_sm_cos_az(s: &mut String, sm_off: u8) {
    s.push_str(&format!("    ldr     r0,=_dv3d_sm\n    ldrsb   r0,[r0,#{sm_off}]\n"));
    s.push_str("    ldr     r2,=_dv3d_cos\n    ldrb    r1,[r2,#2]\n");
    s.push_str("    bl      smul_lut\n");
}
