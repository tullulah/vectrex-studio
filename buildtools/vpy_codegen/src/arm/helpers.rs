//! ARM Thumb2 runtime helpers.
//!
//! On Cortex-M33:
//!   - MUL  r0, r1     → 32-bit multiply, 1 cycle  (no helper needed)
//!   - SDIV r0, r0, r1 → signed divide, ~2–12 cycles (hardware, no helper needed)
//!   - UDIV r0, r0, r1 → unsigned divide (hardware)
//!
//! The only helper we need is bus_write / bus_read — GPIO bit-bang to
//! drive the Vectrex bus. These are called by every builtin.

pub fn emit_helpers() -> String {
    let mut s = String::new();

    s.push_str("@ ============================================================\n");
    s.push_str("@ bus_write: write one byte to Vectrex bus address\n");
    s.push_str("@   r0 = address (16-bit Vectrex bus address, e.g. 0xD000)\n");
    s.push_str("@   r1 = data byte\n");
    s.push_str("@ Clobbers: r2, r3\n");
    s.push_str("@ ============================================================\n");
    s.push_str(".global bus_write\n");
    s.push_str(".type bus_write, %function\n");
    s.push_str(".thumb_func\n");
    s.push_str("bus_write:\n");
    s.push_str("    push    {r4, r5, lr}\n");

    // SIO base
    s.push_str("    ldr     r4, =0xD0000000         @ SIO_BASE\n");

    // Build GPIO word: address in GP0-GP14, data in GP15-GP22
    // addr bits 0-14 → GPIO bits 0-14 (no shift needed)
    // data bits 0-7  → GPIO bits 15-22 (shift left 15)
    // Note: #0x7FFF can't be a Thumb2 modified immediate — use MOVW
    s.push_str("    movw    r2, #0x7FFF\n");
    s.push_str("    and     r2, r0, r2               @ address → GP0-GP14\n");
    s.push_str("    and     r3, r1, #0xFF\n");
    s.push_str("    lsl     r3, r3, #15              @ data → GP15-GP22\n");
    s.push_str("    orr     r2, r2, r3               @ combined GPIO value\n");

    // Set address + data lines as output
    s.push_str("    ldr     r3, =0x007F7FFF          @ ADDR_MASK | DATA_MASK\n");
    s.push_str("    str     r3, [r4, #0x24]          @ SIO_GPIO_OE_SET\n");

    // Drive address + data
    s.push_str("    str     r2, [r4, #0x14]          @ SIO_GPIO_OUT_SET (set bits)\n");
    s.push_str("    mvn     r3, r2\n");
    s.push_str("    ldr     r5, =0x007F7FFF\n");
    s.push_str("    and     r3, r3, r5\n");
    s.push_str("    str     r3, [r4, #0x18]          @ SIO_GPIO_OUT_CLR (clear bits)\n");

    // R/W = LOW (write)
    s.push_str("    mov     r3, #1\n");
    s.push_str("    lsl     r3, r3, #24              @ 1 << PIN_RW (24)\n");
    s.push_str("    str     r3, [r4, #0x18]          @ GPIO_CLR: R/W low\n");

    // Hold stable ≥2µs @ 150MHz = 300 cycles
    s.push_str("    mov     r3, #300\n");
    s.push_str("1:  subs    r3, r3, #1\n");
    s.push_str("    bne     1b\n");

    // Release R/W = HIGH
    s.push_str("    mov     r3, #1\n");
    s.push_str("    lsl     r3, r3, #24\n");
    s.push_str("    str     r3, [r4, #0x14]          @ GPIO_SET: R/W high\n");

    s.push_str("    pop     {r4, r5, pc}\n");
    s.push_str("    .ltorg\n\n");

    // ------------------------------------------------------------------
    s.push_str("@ ============================================================\n");
    s.push_str("@ bus_read: read one byte from Vectrex bus address\n");
    s.push_str("@   r0 = address\n");
    s.push_str("@ Returns: r0 = data byte\n");
    s.push_str("@ Clobbers: r2, r3\n");
    s.push_str("@ ============================================================\n");
    s.push_str(".global bus_read\n");
    s.push_str(".type bus_read, %function\n");
    s.push_str(".thumb_func\n");
    s.push_str("bus_read:\n");
    s.push_str("    push    {r4, lr}\n");
    s.push_str("    ldr     r4, =0xD0000000\n");

    // Address lines as output
    s.push_str("    ldr     r2, =0x00007FFF          @ ADDR_MASK\n");
    s.push_str("    str     r2, [r4, #0x24]          @ OE_SET address lines\n");

    // Data lines as input
    s.push_str("    ldr     r2, =0x007F8000          @ DATA_MASK\n");
    s.push_str("    str     r2, [r4, #0x28]          @ OE_CLR data lines\n");

    // Drive address (note: #0x7FFF can't be Thumb2 modified immediate — use MOVW)
    s.push_str("    movw    r2, #0x7FFF\n");
    s.push_str("    and     r2, r0, r2\n");
    s.push_str("    str     r2, [r4, #0x14]          @ set addr bits\n");
    s.push_str("    mvn     r3, r2\n");
    s.push_str("    movw    r2, #0x7FFF\n");
    s.push_str("    and     r3, r3, r2\n");
    s.push_str("    str     r3, [r4, #0x18]          @ clear addr bits\n");

    // R/W = HIGH (read)
    s.push_str("    mov     r2, #1\n");
    s.push_str("    lsl     r2, r2, #24\n");
    s.push_str("    str     r2, [r4, #0x14]\n");

    // Wait ≥2µs
    s.push_str("    mov     r3, #300\n");
    s.push_str("1:  subs    r3, r3, #1\n");
    s.push_str("    bne     1b\n");

    // Sample data bus GP15-GP22 → bits 0-7
    s.push_str("    ldr     r0, [r4, #0x04]          @ SIO_GPIO_IN\n");
    s.push_str("    lsr     r0, r0, #15              @ shift data to bits 0-7\n");
    s.push_str("    and     r0, r0, #0xFF\n");

    s.push_str("    pop     {r4, pc}\n");
    s.push_str("    .ltorg\n\n");

    // ================================================================
    // Enemy system runtime for rp2350
    // ================================================================

    // vpy_spawn_enemies(r0=count_ptr, r1=enemies_ptr)
    // Populates ENEMY_POOL_ARM from the ROM enemy spawn table.
    // Pool slot (24 bytes): active(4) world_x(4) world_y(4) sprite_ptr(4)
    //   wp_base(4) wp_idx(u8)+wp_count(u8)+ai_type(u8)+pad(u8)
    s.push_str("@ vpy_spawn_enemies(r0=count_ptr, r1=enemies_ptr)\n");
    s.push_str(".global vpy_spawn_enemies\n.type vpy_spawn_enemies, %function\n.thumb_func\n");
    s.push_str("vpy_spawn_enemies:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, lr}\n");
    s.push_str("    ldr     r4, [r0]             @ count\n");
    s.push_str("    ldr     r5, =ENEMY_COUNT_ARM\n");
    s.push_str("    str     r4, [r5]             @ store count\n");
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    beq.w   vspe_done\n");
    s.push_str("    cmp     r4, #8               @ clamp to max 8\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r4, #8\n");
    s.push_str("    str     r4, [r5]             @ update clamped count\n");
    s.push_str("    mov     r6, r1               @ r6 = ROM entry ptr\n");
    s.push_str("    ldr     r7, =ENEMY_POOL_ARM  @ r7 = pool slot ptr\n");
    s.push_str("    mov     r8, #24              @ pool stride\n");
    s.push_str("vspe_loop:\n");
    // sprite_ptr at ROM+0
    s.push_str("    ldr     r9, [r6, #0]         @ sprite_ptr\n");
    // active = 1
    s.push_str("    mov     r0, #1\n");
    s.push_str("    str     r0, [r7, #0]         @ active\n");
    // world_x = sign-extend .hword at ROM+4
    s.push_str("    ldrsh   r0, [r6, #4]         @ spawn_x\n");
    s.push_str("    str     r0, [r7, #4]         @ world_x\n");
    // world_y
    s.push_str("    ldrsh   r0, [r6, #6]         @ spawn_y\n");
    s.push_str("    str     r0, [r7, #8]         @ world_y\n");
    // sprite_ptr
    s.push_str("    str     r9, [r7, #12]        @ sprite_ptr\n");
    // ai_type at ROM+8, wp_count at ROM+9
    s.push_str("    ldrb    r0, [r6, #8]         @ ai_type\n");
    s.push_str("    ldrb    r1, [r6, #9]         @ wp_count\n");
    // wp_base = &ROM+12 (first waypoint)
    s.push_str("    add     r2, r6, #12          @ wp_base = ROM+12\n");
    s.push_str("    str     r2, [r7, #16]        @ wp_base\n");
    // pack wp_idx=0, wp_count, ai_type into [r7+20]
    s.push_str("    mov     r2, #0               @ wp_idx\n");
    s.push_str("    strb    r2, [r7, #20]        @ wp_idx\n");
    s.push_str("    strb    r1, [r7, #21]        @ wp_count\n");
    s.push_str("    strb    r0, [r7, #22]        @ ai_type\n");
    s.push_str("    strb    r2, [r7, #23]        @ pad\n");
    // advance ROM ptr: base(12) + wp_count*4 + 4 (is_anim+pad)
    s.push_str("    ldrb    r1, [r6, #9]         @ wp_count again\n");
    s.push_str("    mov     r0, #4\n");
    s.push_str("    mul     r0, r1, r0           @ wp_count * 4\n");
    s.push_str("    add     r0, r0, #16          @ +12 base +4 is_anim+pad\n");
    s.push_str("    add     r6, r6, r0           @ next ROM entry\n");
    s.push_str("    add     r7, r7, r8           @ next pool slot\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     vspe_loop\n");
    s.push_str("vspe_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, pc}\n");
    s.push_str("    .ltorg\n\n");

    // vpy_update_enemies() — patrol movement (1 unit/frame toward current waypoint)
    s.push_str("@ vpy_update_enemies()\n");
    s.push_str(".global vpy_update_enemies\n.type vpy_update_enemies, %function\n.thumb_func\n");
    s.push_str("vpy_update_enemies:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");
    s.push_str("    ldr     r4, =ENEMY_COUNT_ARM\n");
    s.push_str("    ldr     r4, [r4]\n");
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    beq.w   vupe_done\n");
    s.push_str("    ldr     r5, =ENEMY_POOL_ARM  @ r5 = pool base\n");
    s.push_str("    mov     r8, #24              @ pool stride\n");
    s.push_str("vupe_loop:\n");
    // skip inactive
    s.push_str("    ldr     r0, [r5, #0]         @ active?\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq.w   vupe_next\n");
    // ai_type
    s.push_str("    ldrb    r0, [r5, #22]        @ ai_type\n");
    s.push_str("    cmp     r0, #1               @ patrol?\n");
    s.push_str("    bne.w   vupe_next\n");
    // wp_count
    s.push_str("    ldrb    r6, [r5, #21]        @ wp_count\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq.w   vupe_next\n");
    // wp_base
    s.push_str("    ldr     r7, [r5, #16]        @ wp_base\n");
    s.push_str("    ldrb    r9, [r5, #20]        @ wp_idx\n");
    // wp_ptr = wp_base + wp_idx*4
    s.push_str("    lsl     r0, r9, #2           @ idx * 4\n");
    s.push_str("    add     r7, r7, r0           @ r7 = &wp[idx]\n");
    // target_x, target_y
    s.push_str("    ldrsh   r10, [r7, #0]        @ target_x\n");
    s.push_str("    ldrsh   r11, [r7, #2]        @ target_y\n");
    // world_x, world_y
    s.push_str("    ldr     r0, [r5, #4]         @ world_x\n");
    s.push_str("    ldr     r1, [r5, #8]         @ world_y\n");
    // move x — snap to target if within PATROL_SPEED to avoid overshooting
    s.push_str("    cmp     r0, r10\n");
    s.push_str("    beq.w   vupe_move_y          @ already at target x\n");
    s.push_str("    sub     r2, r10, r0          @ dx = target_x - world_x\n");
    s.push_str("    blt.w   vupe_x_pos\n");           // world_x < target_x: dx>0, move right
    s.push_str("    rsb     r2, r2, #0           @ |dx|\n");
    s.push_str("    cmp     r2, #1               @ PATROL_SPEED\n");
    s.push_str("    ble.w   vupe_x_snap\n");
    s.push_str("    sub     r0, r0, #1\n");
    s.push_str("    b.w     vupe_x_store\n");
    s.push_str("vupe_x_pos:\n");
    s.push_str("    cmp     r2, #1               @ PATROL_SPEED\n");
    s.push_str("    ble.w   vupe_x_snap\n");
    s.push_str("    add     r0, r0, #1\n");
    s.push_str("    b.w     vupe_x_store\n");
    s.push_str("vupe_x_snap:\n");
    s.push_str("    mov     r0, r10              @ snap to target_x\n");
    s.push_str("vupe_x_store:\n");
    s.push_str("    str     r0, [r5, #4]         @ update world_x\n");
    s.push_str("vupe_move_y:\n");
    // move y — snap to target if within PATROL_SPEED to avoid overshooting
    s.push_str("    cmp     r1, r11\n");
    s.push_str("    beq.w   vupe_check_wp        @ already at target y\n");
    s.push_str("    sub     r2, r11, r1          @ dy = target_y - world_y\n");
    s.push_str("    blt.w   vupe_y_pos\n");
    s.push_str("    rsb     r2, r2, #0           @ |dy|\n");
    s.push_str("    cmp     r2, #1               @ PATROL_SPEED\n");
    s.push_str("    ble.w   vupe_y_snap\n");
    s.push_str("    sub     r1, r1, #1\n");
    s.push_str("    b.w     vupe_y_next\n");
    s.push_str("vupe_y_pos:\n");
    s.push_str("    cmp     r2, #1               @ PATROL_SPEED\n");
    s.push_str("    ble.w   vupe_y_snap\n");
    s.push_str("    add     r1, r1, #1\n");
    s.push_str("    b.w     vupe_y_next\n");
    s.push_str("vupe_y_snap:\n");
    s.push_str("    mov     r1, r11              @ snap to target_y\n");
    s.push_str("vupe_y_next:\n");
    s.push_str("    str     r1, [r5, #8]         @ update world_y\n");
    s.push_str("    b.w     vupe_next\n");
    s.push_str("vupe_check_wp:\n");
    // check if x also at target
    s.push_str("    ldr     r0, [r5, #4]         @ world_x (after move)\n");
    s.push_str("    cmp     r0, r10\n");
    s.push_str("    bne.w   vupe_next             @ x not yet at target\n");
    // advance wp_idx with wrap
    s.push_str("    add     r9, r9, #1\n");
    s.push_str("    cmp     r9, r6               @ >= wp_count?\n");
    s.push_str("    it      ge\n");
    s.push_str("    movge   r9, #0               @ wrap to 0\n");
    s.push_str("    strb    r9, [r5, #20]        @ update wp_idx\n");
    s.push_str("vupe_next:\n");
    s.push_str("    add     r5, r5, r8\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     vupe_loop\n");
    s.push_str("vupe_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
    s.push_str("    .ltorg\n\n");

    // vpy_draw_enemies() — draw each active enemy at its world position
    s.push_str("@ vpy_draw_enemies()\n");
    s.push_str(".global vpy_draw_enemies\n.type vpy_draw_enemies, %function\n.thumb_func\n");
    s.push_str("vpy_draw_enemies:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, lr}\n");
    s.push_str("    ldr     r4, =ENEMY_COUNT_ARM\n");
    s.push_str("    ldr     r4, [r4]\n");
    s.push_str("    cmp     r4, #0\n");
    s.push_str("    beq.w   vdre_done\n");
    s.push_str("    ldr     r5, =ENEMY_POOL_ARM\n");
    s.push_str("    mov     r8, #24\n");
    s.push_str("    ldr     r6, =CAMERA_X\n");
    s.push_str("    ldr     r7, =CAMERA_Y\n");
    s.push_str("    ldr     r6, [r6]             @ camera_x\n");
    s.push_str("    ldr     r7, [r7]             @ camera_y\n");
    s.push_str("vdre_loop:\n");
    s.push_str("    ldr     r0, [r5, #0]         @ active?\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq.w   vdre_next\n");
    s.push_str("    ldr     r0, [r5, #12]        @ sprite_ptr\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq.w   vdre_next\n");
    // screen_x = world_x - camera_x, screen_y = world_y - camera_y
    s.push_str("    ldr     r1, [r5, #4]         @ world_x\n");
    s.push_str("    sub     r1, r1, r6           @ screen_x\n");
    s.push_str("    ldr     r2, [r5, #8]         @ world_y\n");
    s.push_str("    sub     r2, r2, r7           @ screen_y\n");
    // vpy_draw_vector_ex(sprite_ptr, ox, oy, mirror=0, intensity=127)
    // Use sub/add sp by 8 (not push {r3}) to keep SP 8-byte aligned before bl
    s.push_str("    mov     r3, #0               @ mirror=0\n");
    s.push_str("    sub     sp, sp, #8           @ reserve 8 bytes (keeps 8-byte alignment)\n");
    s.push_str("    mov     r12, #127\n");
    s.push_str("    str     r12, [sp]            @ intensity=127 at [sp+0] (5th arg)\n");
    s.push_str("    bl      vpy_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #8           @ clean up stack reservation\n");
    s.push_str("vdre_next:\n");
    s.push_str("    add     r5, r5, r8\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     vdre_loop\n");
    s.push_str("vdre_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n");
    s.push_str("    .ltorg\n\n");

    s
}
