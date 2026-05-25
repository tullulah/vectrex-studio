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
    // Pool slot (32 bytes): active(4) world_x(4) world_y(4) sprite_ptr(4)
    //   wp_base(4) wp_idx(u8)+wp_count(u8)+ai_type(u8)+is_anim(u8)
    //   anim_frame_idx(u8)+anim_ticks_left(u8)+pad(6)
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
    s.push_str("    mov     r8, #32              @ pool stride\n");
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
    // read is_anim from ROM at offset 12 + wp_count*4 (r1 = wp_count still valid)
    s.push_str("    lsl     r0, r1, #2           @ wp_count * 4\n");
    s.push_str("    add     r0, r0, #12          @ offset = 12 + wp_count*4\n");
    s.push_str("    ldrb    r0, [r6, r0]         @ is_anim byte\n");
    s.push_str("    strb    r0, [r7, #23]        @ pool[+23] = is_anim\n");
    // reset anim state so stale values from previous spawn cycles don't persist
    s.push_str("    mov     r2, #0\n");
    s.push_str("    strb    r2, [r7, #24]        @ reset anim_frame_idx\n");
    s.push_str("    strb    r2, [r7, #25]        @ reset anim_ticks_left\n");
    // dir (default_facing ROM+11) and mirror_on_patrol (ROM+10) → pool+26, +27
    s.push_str("    ldrb    r0, [r6, #11]        @ default_facing (0=right 1=left)\n");
    s.push_str("    strb    r0, [r7, #26]        @ pool+26 = dir\n");
    s.push_str("    ldrb    r0, [r6, #10]        @ mirror_on_patrol\n");
    s.push_str("    strb    r0, [r7, #27]        @ pool+27 = mirror_on_patrol\n");
    // type_data_ptr at ROM+12+wp_count*4+4 → pool+28
    s.push_str("    ldrb    r1, [r6, #9]         @ wp_count\n");
    s.push_str("    lsl     r0, r1, #2           @ wp_count * 4\n");
    s.push_str("    add     r0, r0, #16          @ 12 + wp_count*4 + 4 = type_data_ptr offset\n");
    s.push_str("    ldr     r0, [r6, r0]         @ type_data_ptr\n");
    s.push_str("    str     r0, [r7, #28]        @ pool+28 = type_data_ptr\n");
    // advance ROM ptr: base(12) + wp_count*4 + 4 (is_anim+pad)
    s.push_str("    ldrb    r1, [r6, #9]         @ wp_count again\n");
    s.push_str("    mov     r0, #4\n");
    s.push_str("    mul     r0, r1, r0           @ wp_count * 4\n");
    s.push_str("    add     r0, r0, #24          @ +12 base +4 is_anim+pad +4 type_data_ptr +4 areas_ptr\n");
    s.push_str("    add     r6, r6, r0           @ next ROM entry\n");
    s.push_str("    add     r7, r7, r8           @ next pool slot\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     vspe_loop\n");
    s.push_str("vspe_done:\n");
    // Zero ENEMY_STATE_ARM (8 × 4 bytes) so states reset on each SPAWN_ENEMIES call
    s.push_str("    ldr     r0, =ENEMY_STATE_ARM\n");
    s.push_str("    movs    r1, #0\n");
    s.push_str("    stm     r0!, {r1}             @ state[0..7] = 0\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
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
    s.push_str("    mov     r8, #32              @ pool stride\n");
    s.push_str("vupe_loop:\n");
    // skip inactive
    s.push_str("    ldr     r0, [r5, #0]         @ active?\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq.w   vupe_next\n");
    // ai_type
    s.push_str("    ldrb    r0, [r5, #22]        @ ai_type\n");
    s.push_str("    cmp     r0, #1               @ patrol?\n");
    s.push_str("    bne.w   vupe_not_patrol\n");
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
    s.push_str("    b.w     vupe_next            @ patrol path done\n");
    // Wander AI (ai_type == 4): bounce X within level bounds, use LEVEL_DATA_PTR xMin/xMax
    // Only moves when enemy is in normal state (ENEMY_STATE_ARM[idx] == 0)
    s.push_str("vupe_not_patrol:\n");
    s.push_str("    cmp     r0, #4               @ wander?\n");
    s.push_str("    bne.w   vupe_next\n");
    // Check enemy state — frozen enemies (state != 0) don't move
    s.push_str("    ldr     r11, =ENEMY_POOL_ARM\n");
    s.push_str("    sub     r11, r5, r11          @ slot_offset\n");
    s.push_str("    lsr     r11, r11, #5          @ slot_index\n");
    s.push_str("    ldr     r6, =ENEMY_STATE_ARM\n");
    s.push_str("    lsl     r11, r11, #2          @ index * 4\n");
    s.push_str("    ldr     r11, [r6, r11]        @ ENEMY_STATE_ARM[index]\n");
    s.push_str("    cmp     r11, #0\n");
    s.push_str("    bne.w   vupe_next             @ frozen/snow/ball: skip movement\n");
    s.push_str("    ldr     r6, =LEVEL_DATA_PTR\n");
    s.push_str("    ldr     r6, [r6]             @ level header ptr\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq.w   vupe_next\n");
    s.push_str("    ldrsh   r9,  [r6, #0]        @ xMin\n");
    s.push_str("    ldrsh   r10, [r6, #2]        @ xMax\n");
    s.push_str("    ldr     r0, [r5, #4]         @ world_x\n");
    s.push_str("    ldrb    r1, [r5, #26]        @ dir (0=right, 1=left)\n");
    s.push_str("    cmp     r1, #0\n");
    s.push_str("    bne.w   vupe_wander_left\n");
    s.push_str("    add     r0, r0, #1           @ move right\n");
    s.push_str("    cmp     r0, r10\n");
    s.push_str("    blt.w   vupe_wander_store\n");
    s.push_str("    mov     r0, r10\n");
    s.push_str("    mov     r1, #1               @ flip to left\n");
    s.push_str("    strb    r1, [r5, #26]\n");
    s.push_str("    b.w     vupe_wander_store\n");
    s.push_str("vupe_wander_left:\n");
    s.push_str("    sub     r0, r0, #1           @ move left\n");
    s.push_str("    cmp     r0, r9\n");
    s.push_str("    bgt.w   vupe_wander_store\n");
    s.push_str("    mov     r0, r9\n");
    s.push_str("    mov     r1, #0               @ flip to right\n");
    s.push_str("    strb    r1, [r5, #26]\n");
    s.push_str("vupe_wander_store:\n");
    s.push_str("    str     r0, [r5, #4]         @ update world_x\n");
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
    s.push_str("    mov     r8, #32\n");
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
    // branch on is_anim: VEC → vpy_draw_vector_ex, VANIM → vpy_draw_anim
    s.push_str("    ldrb    r3, [r5, #23]        @ is_anim\n");
    s.push_str("    cmp     r3, #0\n");
    s.push_str("    bne.w   vdre_use_anim\n");
    // static vector path
    s.push_str("    mov     r3, #0               @ mirror=0\n");
    s.push_str("    sub     sp, sp, #8           @ reserve 8 bytes (keeps 8-byte alignment)\n");
    s.push_str("    mov     r12, #127\n");
    s.push_str("    str     r12, [sp]            @ intensity=127 at [sp+0] (5th arg)\n");
    s.push_str("    bl      vpy_draw_vector_ex\n");
    s.push_str("    add     sp, sp, #8           @ clean up stack reservation\n");
    s.push_str("    b.w     vdre_next\n");
    // animation path: vpy_draw_anim(r0=anim_ptr, r1=ox, r2=oy, r3=state_ptr, r4=mirror)
    // r0=anim_ptr must be preserved; r4 is loop counter — use r9 for mirror scratch
    s.push_str("vdre_use_anim:\n");
    s.push_str("    ldrb    r9, [r5, #26]        @ dir (0=right, 1=left) into r9\n");
    s.push_str("    ldrb    r3, [r5, #27]        @ mirror_on_patrol\n");
    s.push_str("    and     r9, r9, r3           @ mirror in r9 (r0=anim_ptr unchanged)\n");
    s.push_str("    add     r3, r5, #24          @ per-enemy anim state\n");
    s.push_str("    push    {r4, r9}             @ save loop counter + mirror (8-byte align)\n");
    s.push_str("    mov     r4, r9               @ r4 = mirror for vpy_draw_anim\n");
    s.push_str("    @ r0=anim_ptr r1=screen_x r2=screen_y r3=state_ptr r4=mirror\n");
    s.push_str("    bl      vpy_draw_anim\n");
    s.push_str("    pop     {r4, r9}             @ restore loop counter\n");
    s.push_str("vdre_next:\n");
    s.push_str("    add     r5, r5, r8\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    bne     vdre_loop\n");
    s.push_str("vdre_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, pc}\n");
    s.push_str("    .ltorg\n\n");

    // Enemy pool query/mutate helpers — leaf functions (no push/pop needed). Pool stride=32.
    // ENEMY_STATE_ARM is a separate 8×i32 array for GET/SET_ENEMY_STATE.

    s.push_str("@ vpy_get_enemy_active(r0=idx) -> r0=active\n");
    s.push_str(".global vpy_get_enemy_active\n.type vpy_get_enemy_active, %function\n.thumb_func\n");
    s.push_str("vpy_get_enemy_active:\n");
    s.push_str("    lsl     r1, r0, #5              @ r1 = idx*32\n");
    s.push_str("    ldr     r0, =ENEMY_POOL_ARM\n");
    s.push_str("    ldr     r0, [r0, r1]            @ active field\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    s.push_str("@ vpy_get_enemy_x(r0=idx) -> r0=world_x\n");
    s.push_str(".global vpy_get_enemy_x\n.type vpy_get_enemy_x, %function\n.thumb_func\n");
    s.push_str("vpy_get_enemy_x:\n");
    s.push_str("    lsl     r1, r0, #5              @ r1 = idx*32\n");
    s.push_str("    ldr     r0, =ENEMY_POOL_ARM\n");
    s.push_str("    add     r0, r0, r1\n");
    s.push_str("    ldr     r0, [r0, #4]            @ world_x\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    s.push_str("@ vpy_get_enemy_y(r0=idx) -> r0=world_y\n");
    s.push_str(".global vpy_get_enemy_y\n.type vpy_get_enemy_y, %function\n.thumb_func\n");
    s.push_str("vpy_get_enemy_y:\n");
    s.push_str("    lsl     r1, r0, #5              @ r1 = idx*32\n");
    s.push_str("    ldr     r0, =ENEMY_POOL_ARM\n");
    s.push_str("    add     r0, r0, r1\n");
    s.push_str("    ldr     r0, [r0, #8]            @ world_y\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    s.push_str("@ vpy_set_enemy_x(r0=idx, r1=x)\n");
    s.push_str(".global vpy_set_enemy_x\n.type vpy_set_enemy_x, %function\n.thumb_func\n");
    s.push_str("vpy_set_enemy_x:\n");
    s.push_str("    lsl     r2, r0, #5              @ r2 = idx*32\n");
    s.push_str("    ldr     r0, =ENEMY_POOL_ARM\n");
    s.push_str("    add     r0, r0, r2\n");
    s.push_str("    str     r1, [r0, #4]            @ world_x = x\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    s.push_str("@ vpy_set_enemy_y(r0=idx, r1=y)\n");
    s.push_str(".global vpy_set_enemy_y\n.type vpy_set_enemy_y, %function\n.thumb_func\n");
    s.push_str("vpy_set_enemy_y:\n");
    s.push_str("    lsl     r2, r0, #5              @ r2 = idx*32\n");
    s.push_str("    ldr     r0, =ENEMY_POOL_ARM\n");
    s.push_str("    add     r0, r0, r2\n");
    s.push_str("    str     r1, [r0, #8]            @ world_y = y\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    s.push_str("@ vpy_kill_enemy(r0=idx)\n");
    s.push_str(".global vpy_kill_enemy\n.type vpy_kill_enemy, %function\n.thumb_func\n");
    s.push_str("vpy_kill_enemy:\n");
    s.push_str("    lsl     r1, r0, #5              @ r1 = idx*32\n");
    s.push_str("    ldr     r0, =ENEMY_POOL_ARM\n");
    s.push_str("    movs    r2, #0\n");
    s.push_str("    str     r2, [r0, r1]            @ active = 0\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    s.push_str("@ vpy_get_enemy_state(r0=idx) -> r0=state\n");
    s.push_str(".global vpy_get_enemy_state\n.type vpy_get_enemy_state, %function\n.thumb_func\n");
    s.push_str("vpy_get_enemy_state:\n");
    s.push_str("    ldr     r1, =ENEMY_STATE_ARM\n");
    s.push_str("    lsl     r0, r0, #2              @ idx*4 (word stride)\n");
    s.push_str("    ldr     r0, [r1, r0]\n");
    s.push_str("    bx      lr\n    .ltorg\n\n");

    s.push_str("@ vpy_set_enemy_state(r0=idx, r1=state) — set state and sync pool sprite/anim\n");
    s.push_str(".global vpy_set_enemy_state\n.type vpy_set_enemy_state, %function\n.thumb_func\n");
    s.push_str("vpy_set_enemy_state:\n");
    s.push_str("    push    {r4, r5, lr}\n");
    // Write new state to ENEMY_STATE_ARM[idx]
    s.push_str("    ldr     r2, =ENEMY_STATE_ARM\n");
    s.push_str("    lsl     r3, r0, #2           @ idx * 4\n");
    s.push_str("    str     r1, [r2, r3]         @ ENEMY_STATE_ARM[idx] = state\n");
    // Get pool slot
    s.push_str("    ldr     r4, =ENEMY_POOL_ARM\n");
    s.push_str("    lsl     r3, r0, #5           @ idx * 32\n");
    s.push_str("    add     r4, r4, r3           @ r4 = pool slot ptr\n");
    // Load type_data_ptr from pool+28
    s.push_str("    ldr     r5, [r4, #28]        @ type_data_ptr\n");
    s.push_str("    cmp     r5, #0\n");
    s.push_str("    beq.w   vsse_done\n");
    // Entry = type_data + 8 + new_state * 8
    s.push_str("    lsl     r0, r1, #3           @ new_state * 8\n");
    s.push_str("    add     r0, r0, #8           @ skip header\n");
    s.push_str("    add     r0, r5, r0           @ ptr to state entry\n");
    s.push_str("    ldr     r1, [r0, #0]         @ sprite_ptr\n");
    s.push_str("    ldrb    r2, [r0, #4]         @ is_anim\n");
    s.push_str("    str     r1, [r4, #12]        @ update pool sprite_ptr\n");
    s.push_str("    strb    r2, [r4, #23]        @ update pool is_anim\n");
    s.push_str("    movs    r0, #0\n");
    s.push_str("    strb    r0, [r4, #24]        @ reset anim_frame_idx\n");
    s.push_str("    strb    r0, [r4, #25]        @ reset anim_ticks_left\n");
    s.push_str("vsse_done:\n");
    s.push_str("    pop     {r4, r5, pc}\n    .ltorg\n\n");

    s.push_str("@ vpy_set_enemy_dir(r0=idx, r1=dir) — no-op (wander AI controls direction)\n");
    s.push_str(".global vpy_set_enemy_dir\n.type vpy_set_enemy_dir, %function\n.thumb_func\n");
    s.push_str("vpy_set_enemy_dir:\n");
    s.push_str("    bx      lr\n\n");

    s.push_str("@ vpy_enemy_fire_event(r0=idx, r1=event_name_ptr) — increment state, update sprite from type_data table\n");
    s.push_str(".global vpy_enemy_fire_event\n.type vpy_enemy_fire_event, %function\n.thumb_func\n");
    s.push_str("vpy_enemy_fire_event:\n");
    s.push_str("    push    {r4, r5, r6, r7, lr}\n");
    s.push_str("    mov     r7, r1               @ save event name ptr\n");
    // Pool slot ptr
    s.push_str("    lsl     r1, r0, #5           @ idx * 32\n");
    s.push_str("    ldr     r4, =ENEMY_POOL_ARM\n");
    s.push_str("    add     r4, r4, r1           @ pool slot\n");
    // Read/increment state
    s.push_str("    lsl     r1, r0, #2           @ idx * 4 (word array)\n");
    s.push_str("    ldr     r5, =ENEMY_STATE_ARM\n");
    s.push_str("    ldr     r2, [r5, r1]         @ current state\n");
    // Determine max state from type_data (or default 3)
    s.push_str("    ldr     r3, [r4, #28]        @ type_data_ptr\n");
    s.push_str("    cmp     r3, #0\n");
    s.push_str("    beq.w   vefe_cap3\n");
    s.push_str("    ldr     r6, [r3, #0]         @ state_count\n");
    s.push_str("    sub     r6, r6, #1           @ max = state_count - 1\n");
    s.push_str("    b.w     vefe_guard\n");
    s.push_str("vefe_cap3:\n");
    s.push_str("    mov     r6, #3\n");
    // Guard: skip 'onFire*' events for enemies with no fire states (max_state < 4).
    // update_frog_fire() fires onFire for ALL enemies; we must ignore it for non-frogs.
    // Frogs have state_count >= 5 (max_state >= 4). Titchi has state_count=4 (max_state=3).
    // CMP then POP preserves flags — branch after pop is safe on Thumb-2.
    s.push_str("vefe_guard:\n");
    s.push_str("    cmp     r6, #4               @ max_state >= 4 → has fire states\n");
    s.push_str("    bge.w   vefe_inc\n");
    s.push_str("    cmp     r7, #0               @ null event ptr\n");
    s.push_str("    beq.w   vefe_inc\n");
    s.push_str("    push    {r2, r3}\n");
    s.push_str("    ldr     r2, [r7]             @ first 4 bytes of event name\n");
    s.push_str("    ldr     r3, =0x69466E6F      @ 'onFi' little-endian\n");
    s.push_str("    cmp     r2, r3\n");
    s.push_str("    pop     {r2, r3}             @ restore state + type_data_ptr (flags preserved)\n");
    s.push_str("    beq.w   vefe_done            @ 'onFire*' on non-frog: skip\n");
    s.push_str("vefe_inc:\n");
    s.push_str("    add     r2, r2, #1\n");
    s.push_str("    cmp     r2, r6\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r2, r6\n");
    s.push_str("    str     r2, [r5, r1]         @ store new state\n");
    // Update sprite from type_data table: entry at base+8+state*8
    s.push_str("    cmp     r3, #0\n");
    s.push_str("    beq.w   vefe_done\n");
    s.push_str("    lsl     r0, r2, #3           @ state * 8\n");
    s.push_str("    add     r0, r0, #8           @ skip header (8 bytes)\n");
    s.push_str("    add     r0, r3, r0           @ ptr to state entry\n");
    s.push_str("    ldr     r1, [r0, #0]         @ sprite_ptr\n");
    s.push_str("    ldrb    r2, [r0, #4]         @ is_anim\n");
    s.push_str("    str     r1, [r4, #12]        @ update pool sprite_ptr\n");
    s.push_str("    strb    r2, [r4, #23]        @ update pool is_anim\n");
    s.push_str("    movs    r0, #0\n");
    s.push_str("    strb    r0, [r4, #24]        @ reset anim_frame_idx\n");
    s.push_str("    strb    r0, [r4, #25]        @ reset anim_ticks_left\n");
    s.push_str("vefe_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, pc}\n\n");

    s.push_str("@ vpy_get_enemy_area_idx(r0=idx) -> r0=0 (stub)\n");
    s.push_str(".global vpy_get_enemy_area_idx\n.type vpy_get_enemy_area_idx, %function\n.thumb_func\n");
    s.push_str("vpy_get_enemy_area_idx:\n");
    s.push_str("    movs    r0, #0\n");
    s.push_str("    bx      lr\n\n");

    s
}
