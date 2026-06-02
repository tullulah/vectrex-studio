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

pub fn emit_drawing() -> String {
    let mut s = String::new();
    s.push_str("@ ============================================================\n");
    s.push_str("@ Drawing engine — ARM Thumb2 / RP2350 bus master\n");
    s.push_str("@ ============================================================\n\n");
    s.push_str(&emit_sin_table());
    s.push_str(&emit_smul_lut());
    s.push_str(&emit_dv_reset());
    s.push_str(&emit_dv_move_to());
    s.push_str(&emit_dv_draw_delta());
    s.push_str(&emit_draw_vector());
    s.push_str(&emit_draw_vector_3d());
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

fn emit_dv_reset() -> String {
    // Reset integrators (DSWM-style PB sequence); ACR=$18 (SR→CB2 beam ctrl).
    let mut s = String::new();
    s.push_str("@ dv_reset() — reset Vectrex integrators, set ACR=$18\n");
    s.push_str(".global dv_reset\n.type dv_reset, %function\n.thumb_func\ndv_reset:\n");
    s.push_str("    push    {lr}\n");
    s.push_str("    mov     r0, #0xD00A\n    mov     r1, #0x00\n    bl      bus_write\n"); // SR=0
    s.push_str("    mov     r0, #0xD00B\n    mov     r1, #0x18\n    bl      bus_write\n"); // ACR=$18
    s.push_str("    mov     r0, #0xD00C\n    mov     r1, #0xCC\n    bl      bus_write\n"); // PCR=$CC
    s.push_str("    mov     r0, #0xD001\n    mov     r1, #0x00\n    bl      bus_write\n"); // PORT_A=0
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x03\n    bl      bus_write\n"); // PB=3
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x02\n    bl      bus_write\n"); // PB=2
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x02\n    bl      bus_write\n"); // PB=2
    s.push_str("    pop     {pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ─── dv_move_to ───────────────────────────────────────────────────────────

fn emit_dv_move_to() -> String {
    // r0=dx, r1=dy (signed deltas). Beam off during ramp.
    let mut s = String::new();
    s.push_str("@ dv_move_to(r0=dx, r1=dy) — position beam, no draw\n");
    s.push_str(".global dv_move_to\n.type dv_move_to, %function\n.thumb_func\ndv_move_to:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    mov     r4, r0\n    mov     r5, r1\n");       // r4=dx, r5=dy
    s.push_str("    mov     r0, #0xD001\n    mov     r1, r5\n    bl      bus_write\n"); // PORT_A=dy
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x00\n    bl      bus_write\n"); // PB=0 (Y)
    s.push_str("    mov     r0, #60\ndv_mt_s: subs r0,r0,#1\n    bne dv_mt_s\n");     // settle
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x01\n    bl      bus_write\n"); // PB=1 (X)
    s.push_str("    mov     r0, #0xD001\n    mov     r1, r4\n    bl      bus_write\n"); // PORT_A=dx
    s.push_str("    mov     r0, #0xD00A\n    mov     r1, #0x00\n    bl      bus_write\n"); // SR=0 (off)
    s.push_str("    mov     r0, #0xD006\n    mov     r1, #0x7F\n    bl      bus_write\n"); // T1L_L=$7F
    s.push_str("    mov     r0, #0xD005\n    mov     r1, #0x00\n    bl      bus_write\n"); // T1C_H=0 (start)
    s.push_str("dv_mt_p: mov r0,#0xD00D\n    bl bus_read\n    tst r0,#0x40\n    beq dv_mt_p\n");
    s.push_str("    mov     r0, #0xD004\n    bl      bus_read\n");  // clear IFR (read T1C_L)
    s.push_str("    pop     {r4, r5, pc}\n");
    s.push_str("    .ltorg\n\n");
    s
}

// ─── dv_draw_delta ────────────────────────────────────────────────────────

fn emit_dv_draw_delta() -> String {
    // r0=dx, r1=dy. Beam on during ramp.
    let mut s = String::new();
    s.push_str("@ dv_draw_delta(r0=dx, r1=dy) — draw one vector segment\n");
    s.push_str(".global dv_draw_delta\n.type dv_draw_delta, %function\n.thumb_func\ndv_draw_delta:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    s.push_str("    mov     r4, r0\n    mov     r5, r1\n");
    s.push_str("    mov     r0, #0xD001\n    mov     r1, r5\n    bl      bus_write\n"); // PORT_A=dy
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x00\n    bl      bus_write\n"); // PB=0
    s.push_str("    mov     r0, #60\ndv_dd_s: subs r0,r0,#1\n    bne dv_dd_s\n");
    s.push_str("    mov     r0, #0xD000\n    mov     r1, #0x01\n    bl      bus_write\n"); // PB=1
    s.push_str("    mov     r0, #0xD001\n    mov     r1, r4\n    bl      bus_write\n"); // PORT_A=dx
    s.push_str("    mov     r0, #0xD00A\n    mov     r1, #0xFF\n    bl      bus_write\n"); // SR=$FF (beam on)
    s.push_str("    mov     r0, #0xD006\n    mov     r1, #0x7F\n    bl      bus_write\n"); // T1L_L=$7F
    s.push_str("    mov     r0, #0xD005\n    mov     r1, #0x00\n    bl      bus_write\n"); // T1C_H=0
    s.push_str("dv_dd_p: mov r0,#0xD00D\n    bl bus_read\n    tst r0,#0x40\n    beq dv_dd_p\n");
    s.push_str("    mov     r0, #0xD00A\n    mov     r1, #0x00\n    bl      bus_write\n"); // SR=0 (off)
    s.push_str("    mov     r0, #0xD004\n    bl      bus_read\n");  // clear IFR
    s.push_str("    pop     {r4, r5, pc}\n");
    s.push_str("    .ltorg\n\n");
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
    s.push_str("    ldrb    r0, [r7]\n    bl      vpy_set_intensity\n");          // intensity
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
    smul_call_sm_az(&mut s, 1, "r7");                       // r0 = y1*sin_az
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

    // Phase 2: draw paths
    s.push_str("    bl      dv_reset\n");
    s.push_str("    ldr     r10,[r4]\n    add r4,r4,#4\n"); // path_count
    s.push_str("    ldr     r11,=_dv3d_vbuf\n");           // vbuf base for lookup

    // _dv3d_cur = (0,0) — after dv_reset integrators are at origin
    s.push_str("    ldr     r0,=_dv3d_cur\n    mov r1,#0\n    strh r1,[r0]\n");

    s.push_str("dv3_pl:\n    cmp r10,#0\n    beq dv3_pd\n    sub r10,r10,#1\n");
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
