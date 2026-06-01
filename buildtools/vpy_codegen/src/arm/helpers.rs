//! ARM Thumb2 runtime helpers.
//!
//! On Cortex-M33:
//!   - MUL  r0, r1     → 32-bit multiply, 1 cycle  (no helper needed)
//!   - SDIV r0, r0, r1 → signed divide, ~2–12 cycles (hardware, no helper needed)
//!   - UDIV r0, r0, r1 → unsigned divide (hardware)
//!
//! The only helper we need is bus_write / bus_read — GPIO bit-bang to
//! drive the Vectrex bus. These are called by every builtin.

/// Full bundle: debug-cart bus helpers + pinout-agnostic runtime helpers.
/// Called by the standalone `arm` target (which expects the debug-cart pinout).
/// UVM2 supplies its own bus_write/bus_read shims (see uvm2/mod.rs) and only
/// needs `emit_runtime_helpers()`.
pub fn emit_helpers() -> String {
    let mut s = emit_bus_helpers();
    s.push_str(&emit_runtime_helpers());
    s
}

/// Debug-cart pinout: bus_write + bus_read (RP2350 SIO GPIO bit-bang).
/// UVM2 does NOT use this — it has its own CLK-synced GPIO protocol.
pub fn emit_bus_helpers() -> String {
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

    s
}

/// Pinout-agnostic runtime: enemy pool/state, anim/draw helpers, math, etc.
/// Used by both the debug-cart `arm` target and `uvm2` (which supplies its
/// own bus shims). Anything here only touches RAM/ROM symbols, never GPIO.
pub fn emit_runtime_helpers() -> String {
    let mut s = String::new();

    // ================================================================
    // Enemy system runtime for rp2350
    // ================================================================

    // vpy_spawn_enemies(r0=count_ptr, r1=enemies_ptr)
    // Clears the 8-slot pool, reads CAMERA_Y, then iterates ALL ROM entries
    // and fills slots only with enemies whose spawn_y is within camera_y ± 150.
    // This mirrors pitrex_spawn_enemies so level data spanning multiple screens
    // works correctly: each level transition re-spawns only the on-screen enemies.
    //
    // ROM entry layout (stride = 24 + wp_count*4):
    //   +0  sprite_ptr(u32)  +4 spawn_x(i16)  +6 spawn_y(i16)
    //   +8  ai_type(u8)  +9 wp_count(u8)  +10 mirror_on_patrol(u8)  +11 default_facing(u8)
    //   +12..+12+wp_count*4-1  waypoints
    //   +12+wp_count*4         is_anim(u8) + 3 pad
    //   +16+wp_count*4         type_data_ptr(u32)
    //   +20+wp_count*4         areas_ptr(u32)
    //
    // Pool slot (32 bytes, ENEMY_POOL_ARM):
    //   +0  active(u32)  +4 world_x(i32)  +8 world_y(i16)  +10 sub_state(u8)  +11 trans_type(u8)
    //   +12 sprite_ptr(u32)  +16 areas_ptr/wp_base(u32)
    //   +20 area_idx(u8)  +21 wp_count(u8)  +22 ai_type(u8)  +23 is_anim(u8)
    //   +24 anim_frame_idx(u8)  +25 anim_ticks_left(u8)  +26 dir(u8)  +27 mirror_on_patrol(u8)
    //   +28 type_data_ptr(u32)
    s.push_str("@ vpy_spawn_enemies(r0=count_ptr, r1=enemies_ptr)\n");
    s.push_str("@ Clears pool, reads CAMERA_Y±150, spawns only in-range enemies.\n");
    s.push_str(".global vpy_spawn_enemies\n.type vpy_spawn_enemies, %function\n.thumb_func\n");
    s.push_str("vpy_spawn_enemies:\n");
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}\n");

    // Step 1: clear all 8 pool slots (active = 0)
    s.push_str("    ldr     r6, =ENEMY_POOL_ARM\n");
    s.push_str("    mov     r10, #8\n");
    s.push_str("    mov     r11, #0\n");
    s.push_str("vspe_clear:\n");
    s.push_str("    str     r11, [r6, #0]            @ active = 0\n");
    s.push_str("    add     r6, r6, #32\n");
    s.push_str("    subs    r10, r10, #1\n");
    s.push_str("    bne     vspe_clear\n");

    // Step 2: load total ROM count and entries pointer
    s.push_str("    ldr     r4, [r0]                 @ total ROM enemy count\n");
    s.push_str("    mov     r5, r1                   @ r5 = ROM entries ptr\n");
    s.push_str("    cbz     r4, vspe_store_count\n");

    // Step 3: compute spawn Y range from CAMERA_Y ± 150
    s.push_str("    ldr     r0, =CAMERA_Y\n");
    s.push_str("    ldr     r0, [r0]                 @ camera_y\n");
    s.push_str("    sub     r8, r0, #150             @ y_min = camera_y - 150\n");
    s.push_str("    add     r9, r0, #150             @ y_max = camera_y + 150\n");

    // Step 4: fill pool with matching entries
    s.push_str("    ldr     r6, =ENEMY_POOL_ARM      @ pool write ptr\n");
    s.push_str("    mov     r7, #0                   @ spawned count\n");

    s.push_str("vspe_loop:\n");
    s.push_str("    cbz     r4, vspe_store_count     @ no more ROM entries\n");
    s.push_str("    cmp     r7, #8\n");
    s.push_str("    beq     vspe_store_count         @ pool full\n");
    // filter by spawn_y
    s.push_str("    ldrsh   r10, [r5, #6]            @ spawn_y\n");
    s.push_str("    cmp     r10, r8\n");
    s.push_str("    blt     vspe_next                @ below range\n");
    s.push_str("    cmp     r10, r9\n");
    s.push_str("    bgt     vspe_next                @ above range\n");

    // copy entry → pool slot
    s.push_str("    mov     r0, #1\n");
    s.push_str("    str     r0, [r6, #0]             @ active = 1\n");
    s.push_str("    ldrsh   r0, [r5, #4]             @ spawn_x\n");
    s.push_str("    str     r0, [r6, #4]             @ world_x\n");
    s.push_str("    ldrsh   r0, [r5, #6]             @ spawn_y\n");
    s.push_str("    strh    r0, [r6, #8]             @ world_y (i16)\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r6, #10]            @ sub_state = WALK\n");
    s.push_str("    strb    r0, [r6, #11]            @ trans_type = 0\n");
    s.push_str("    ldr     r0, [r5, #0]             @ sprite_ptr\n");
    s.push_str("    str     r0, [r6, #12]            @ sprite_ptr\n");
    s.push_str("    ldrb    r0, [r5, #8]             @ ai_type\n");
    s.push_str("    ldrb    r1, [r5, #9]             @ wp_count\n");
    s.push_str("    strb    r1, [r6, #21]            @ wp_count\n");
    s.push_str("    strb    r0, [r6, #22]            @ ai_type\n");
    // pool+16: wander(4) → areas_ptr; patrol → wp_base = ROM+12
    s.push_str("    cmp     r0, #4\n");
    s.push_str("    beq.w   vspe_wander_wp\n");
    s.push_str("    add     r2, r5, #12              @ patrol: wp_base = ROM+12\n");
    s.push_str("    str     r2, [r6, #16]            @ pool+16 = wp_base\n");
    s.push_str("    mov     r2, #0\n");
    s.push_str("    strb    r2, [r6, #20]            @ wp_idx = 0\n");
    s.push_str("    b.w     vspe_after_wp\n");
    s.push_str("vspe_wander_wp:\n");
    s.push_str("    lsl     r2, r1, #2               @ wp_count * 4\n");
    s.push_str("    add     r2, r2, #20              @ areas_ptr offset = 20 + wp_count*4\n");
    s.push_str("    ldr     r2, [r5, r2]             @ areas_ptr\n");
    s.push_str("    str     r2, [r6, #16]            @ pool+16 = areas_ptr\n");
    s.push_str("    mov     r2, #0xFF\n");
    s.push_str("    strb    r2, [r6, #20]            @ area_idx = 0xFF (not yet found)\n");
    s.push_str("vspe_after_wp:\n");
    // is_anim at ROM+12+wp_count*4
    s.push_str("    ldrb    r1, [r5, #9]             @ wp_count\n");
    s.push_str("    lsl     r0, r1, #2               @ wp_count * 4\n");
    s.push_str("    add     r0, r0, #12\n");
    s.push_str("    ldrb    r0, [r5, r0]             @ is_anim\n");
    s.push_str("    strb    r0, [r6, #23]            @ pool+23 = is_anim\n");
    // reset anim state
    s.push_str("    mov     r2, #0\n");
    s.push_str("    strb    r2, [r6, #24]            @ anim_frame_idx = 0\n");
    s.push_str("    strb    r2, [r6, #25]            @ anim_ticks_left = 0\n");
    // dir and mirror_on_patrol
    s.push_str("    ldrb    r0, [r5, #11]            @ default_facing\n");
    s.push_str("    strb    r0, [r6, #26]            @ dir\n");
    s.push_str("    ldrb    r0, [r5, #10]            @ mirror_on_patrol\n");
    s.push_str("    strb    r0, [r6, #27]            @ mirror_on_patrol\n");
    // type_data_ptr at ROM+16+wp_count*4
    s.push_str("    ldrb    r1, [r5, #9]             @ wp_count\n");
    s.push_str("    lsl     r0, r1, #2               @ wp_count * 4\n");
    s.push_str("    add     r0, r0, #16\n");
    s.push_str("    ldr     r0, [r5, r0]             @ type_data_ptr\n");
    s.push_str("    str     r0, [r6, #28]            @ pool+28 = type_data_ptr\n");
    // advance pool ptr
    s.push_str("    add     r6, r6, #32              @ next pool slot\n");
    s.push_str("    add     r7, r7, #1               @ spawned++\n");

    s.push_str("vspe_next:\n");
    // advance ROM ptr: 24 + wp_count*4
    s.push_str("    ldrb    r10, [r5, #9]            @ wp_count\n");
    s.push_str("    lsl     r11, r10, #2             @ wp_count * 4\n");
    s.push_str("    add     r11, r11, #24\n");
    s.push_str("    add     r5, r5, r11              @ next ROM entry\n");
    s.push_str("    subs    r4, r4, #1\n");
    s.push_str("    b       vspe_loop\n");

    s.push_str("vspe_store_count:\n");
    s.push_str("    ldr     r0, =ENEMY_COUNT_ARM\n");
    s.push_str("    str     r7, [r0]                 @ store spawned count\n");
    // Zero ENEMY_STATE_ARM (8 × 4 bytes) so states reset on each SPAWN_ENEMIES call
    s.push_str("    ldr     r0, =ENEMY_STATE_ARM\n");
    s.push_str("    movs    r1, #0\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    stm     r0!, {r1}\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}\n");
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
    s.push_str("    bne.w   vupe_patrol_has_wps\n");
    // wp_count==0: use idle sprite when game state==0 (normal)
    s.push_str("    ldr     r0, =ENEMY_POOL_ARM\n");
    s.push_str("    sub     r0, r5, r0\n");
    s.push_str("    lsr     r0, r0, #5           @ slot_idx\n");
    s.push_str("    ldr     r1, =ENEMY_STATE_ARM\n");
    s.push_str("    lsl     r0, r0, #2           @ slot_idx*4\n");
    s.push_str("    ldr     r0, [r1, r0]         @ game state\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    bne.w   vupe_next            @ not normal → keep current sprite\n");
    s.push_str("    ldr     r0, [r5, #28]        @ type_data_ptr\n");
    s.push_str("    cbz     r0, vupe_next\n");
    s.push_str("    ldr     r1, [r0, #8]         @ idle_sprite_ptr (TYPE_DATA+8)\n");
    s.push_str("    ldrb    r2, [r0, #12]        @ idle_is_anim (TYPE_DATA+12)\n");
    s.push_str("    str     r1, [r5, #12]        @ pool sprite_ptr\n");
    s.push_str("    strb    r2, [r5, #23]        @ pool is_anim\n");
    s.push_str("    b.w     vupe_next\n");
    s.push_str("vupe_patrol_has_wps:\n");
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
    s.push_str("    ldrsh   r1, [r5, #8]         @ world_y (i16)\n");
    // move x — snap to target if within PATROL_SPEED to avoid overshooting
    s.push_str("    cmp     r0, r10\n");
    s.push_str("    beq.w   vupe_move_y          @ already at target x\n");
    s.push_str("    sub     r2, r10, r0          @ dx = target_x - world_x\n");
    s.push_str("    blt.w   vupe_x_pos\n");           // world_x < target_x: dx>0, move right
    s.push_str("    rsb     r2, r2, #0           @ |dx|\n");
    s.push_str("    cmp     r2, #1               @ PATROL_SPEED\n");
    s.push_str("    ble.w   vupe_x_snap\n");
    s.push_str("    mov     r2, #1\n");
    s.push_str("    strb    r2, [r5, #26]        @ dir = left\n");
    s.push_str("    sub     r0, r0, #1\n");
    s.push_str("    b.w     vupe_x_store\n");
    s.push_str("vupe_x_pos:\n");
    s.push_str("    cmp     r2, #1               @ PATROL_SPEED\n");
    s.push_str("    ble.w   vupe_x_snap\n");
    s.push_str("    mov     r2, #0\n");
    s.push_str("    strb    r2, [r5, #26]        @ dir = right (moving toward higher x)\n");
    s.push_str("    add     r0, r0, #1\n");
    s.push_str("    b.w     vupe_x_store\n");
    s.push_str("vupe_x_snap:\n");
    s.push_str("    mov     r0, r10              @ snap to target_x\n");
    s.push_str("vupe_x_store:\n");
    s.push_str("    str     r0, [r5, #4]         @ update world_x\n");
    // Wall collision push-out for patrol enemy.
    // push {r6,r7,r12} aligns stack: 36(entry push) + 12 = 48 bytes (8-byte aligned).
    s.push_str("    push    {r6, r7, r12}\n");
    s.push_str("    ldr     r0, [r5, #4]         @ world_x\n");
    s.push_str("    ldrsh   r1, [r5, #8]         @ world_y\n");
    s.push_str("    ldr     r6, [r5, #28]        @ type_data_ptr\n");
    s.push_str("    ldrb    r2, [r6, #6]         @ collision hw from type_data\n");
    s.push_str("    ldrb    r3, [r6, #7]         @ collision hh from type_data\n");
    s.push_str("    bl      vpy_level_collision_x\n");
    s.push_str("    pop     {r6, r7, r12}\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq.w   vupe_move_y\n");
    s.push_str("    ldr     r1, [r5, #4]\n    add     r1, r1, r0\n    str     r1, [r5, #4]\n");
    s.push_str("vupe_move_y:\n");
    // Reload world_y: r1 may be clobbered by bl vpy_level_collision_x (caller-saved)
    // or overwritten with world_x in the push-out path.
    s.push_str("    ldrsh   r1, [r5, #8]         @ reload world_y\n");
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
    s.push_str("    strh    r1, [r5, #8]         @ update world_y (i16)\n");
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
    // Wander AI (ai_type == 4): full platform-transition state machine.
    // Pool fields: +8..9=world_y(i16), +10=sub_state(u8), +11=trans_type(u8),
    //   +16=areas_ptr, +20=area_idx(u8), +26=dir(0=right,1=left), +28=type_data_ptr
    // WANDER_SCRATCH_ARM[slot*4+0..1] = scratch_a (idle_timer/from_x/vy by state)
    // WANDER_SCRATCH_ARM[slot*4+2..3] = target_x (i16)
    // Sub-states: 0=WALK, 1=IDLE, 2=AIRBORNE, 3=WALK_TO_TAKEOFF
    // r4=count r5=slot r8=32(stride) — must not clobber these.
    s.push_str("vupe_not_patrol:\n");
    s.push_str("    cmp     r0, #4               @ wander?\n");
    s.push_str("    bne.w   vupe_next\n");
    // Check enemy state — frozen (state != 0) don't wander
    s.push_str("    ldr     r11, =ENEMY_POOL_ARM\n");
    s.push_str("    sub     r11, r5, r11\n");
    s.push_str("    lsr     r11, r11, #5          @ slot_idx\n");
    s.push_str("    ldr     r6, =ENEMY_STATE_ARM\n");
    s.push_str("    lsl     r0, r11, #2\n");
    s.push_str("    ldr     r0, [r6, r0]\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    bne.w   vupe_next\n");
    // Compute scratch ptr: r12 = &WANDER_SCRATCH_ARM[slot_idx*4]
    s.push_str("    ldr     r6, =WANDER_SCRATCH_ARM\n");
    s.push_str("    lsl     r12, r11, #2          @ slot_idx * 4\n");
    s.push_str("    add     r12, r6, r12           @ r12 = scratch ptr\n");
    // Load areas_ptr
    s.push_str("    ldr     r6, [r5, #16]          @ areas_ptr\n");
    s.push_str("    cmp     r6, #0\n");
    s.push_str("    beq.w   vupe_next\n");
    s.push_str("    ldr     r7, [r6, #0]           @ area_count\n");
    s.push_str("    cmp     r7, #0\n");
    s.push_str("    beq.w   vupe_next\n");
    // --- First tick: find starting area if area_idx == 0xFF ---
    s.push_str("    ldrb    r9, [r5, #20]          @ area_idx\n");
    s.push_str("    cmp     r9, #0xFF\n");
    s.push_str("    bne.w   vupe_w_have_area\n");
    // Find closest area by score = |world_y - area.y| + (x outside [x_min,x_max] ? 10000 : 0)
    s.push_str("    ldrsh   r0, [r5, #8]           @ world_y\n");
    s.push_str("    ldr     r3, [r5, #4]           @ world_x\n");
    s.push_str("    mov     r9, #0                 @ best_idx\n");
    s.push_str("    mvn     r10, #0                @ best_score = UINT_MAX\n");
    s.push_str("    mov     r11, #0                @ loop_idx\n");
    s.push_str("    add     r2, r6, #8             @ ptr to area[0]\n");
    s.push_str("vupe_fa_loop:\n");
    s.push_str("    cmp     r11, r7\n");
    s.push_str("    bge.w   vupe_fa_done\n");
    s.push_str("    ldrsh   r1, [r2, #0]           @ area.y\n");
    s.push_str("    sub     r1, r0, r1             @ world_y - area.y\n");
    s.push_str("    cmp     r1, #0\n");
    s.push_str("    it      mi\n");
    s.push_str("    negmi   r1, r1                 @ |dy|\n");
    s.push_str("    ldrsh   r0, [r2, #2]           @ area.x_min\n");  // reuse r0 temporarily
    s.push_str("    cmp     r3, r0\n");
    s.push_str("    blt.w   vupe_fa_xout\n");
    s.push_str("    ldrsh   r0, [r2, #4]           @ area.x_max\n");
    s.push_str("    cmp     r3, r0\n");
    s.push_str("    ble.w   vupe_fa_xin\n");
    s.push_str("vupe_fa_xout:\n");
    s.push_str("    movw    r0, #10000\n");
    s.push_str("    add     r1, r1, r0\n");
    s.push_str("vupe_fa_xin:\n");
    s.push_str("    ldrsh   r0, [r5, #8]           @ restore world_y for loop\n");
    s.push_str("    cmp     r1, r10\n");
    s.push_str("    bhs.w   vupe_fa_next\n");
    s.push_str("    mov     r10, r1\n");
    s.push_str("    mov     r9, r11\n");
    s.push_str("vupe_fa_next:\n");
    s.push_str("    add     r2, r2, #8\n");
    s.push_str("    add     r11, r11, #1\n");
    s.push_str("    b.w     vupe_fa_loop\n");
    s.push_str("vupe_fa_done:\n");
    s.push_str("    strb    r9, [r5, #20]          @ store area_idx\n");
    // Snap world_y to area.y + feet_offset on first placement
    s.push_str("    lsl     r0, r9, #3             @ idx*8\n");
    s.push_str("    add     r0, r0, #8\n");
    s.push_str("    add     r0, r6, r0             @ &area[idx]\n");
    s.push_str("    ldrsh   r3, [r0, #0]           @ area.y\n");
    s.push_str("    ldr     r1, [r5, #28]          @ type_data_ptr\n");
    s.push_str("    cmp     r1, #0\n");
    s.push_str("    beq     vupe_fa_snap_no_feet\n");
    s.push_str("    ldrsb   r1, [r1, #4]           @ feet_offset\n");
    s.push_str("    add     r3, r3, r1\n");
    s.push_str("vupe_fa_snap_no_feet:\n");
    s.push_str("    strh    r3, [r5, #8]           @ world_y = area.y + feet_offset\n");
    // Reload r7 = area_count (may have been clobbered in fa loop via r7=count which is r4 not r7 — safe)
    // Actually r7 is area_count loaded before fa_loop, still valid here.
    // Dispatch on sub_state
    s.push_str("vupe_w_have_area:\n");
    s.push_str("    ldrb    r0, [r5, #10]          @ sub_state\n");
    // Update pool sprite based on sub_state (only runs for game-state==0 enemies).
    // IDLE(1) → idle_sprite (TYPE_DATA+8); all other → state[0] walk sprite (TYPE_DATA+16).
    s.push_str("    ldr     r1, [r5, #28]          @ type_data_ptr\n");
    s.push_str("    cbz     r1, vupe_w_sprite_disp\n");
    s.push_str("    cmp     r0, #1                 @ IDLE sub-state?\n");
    s.push_str("    bne     vupe_w_sprite_walk\n");
    s.push_str("    ldr     r2, [r1, #8]           @ idle_sprite_ptr\n");
    s.push_str("    ldrb    r3, [r1, #12]          @ idle_is_anim\n");
    s.push_str("    b       vupe_w_sprite_set\n");
    s.push_str("vupe_w_sprite_walk:\n");
    s.push_str("    ldr     r2, [r1, #16]          @ state[0] sprite_ptr (walk)\n");
    s.push_str("    ldrb    r3, [r1, #20]          @ state[0] is_anim\n");
    s.push_str("vupe_w_sprite_set:\n");
    s.push_str("    str     r2, [r5, #12]          @ pool sprite_ptr\n");
    s.push_str("    strb    r3, [r5, #23]          @ pool is_anim\n");
    s.push_str("vupe_w_sprite_disp:\n");
    s.push_str("    cmp     r0, #3\n");
    s.push_str("    beq.w   vupe_w_to_takeoff\n");
    s.push_str("    cmp     r0, #2\n");
    s.push_str("    beq.w   vupe_w_air\n");
    s.push_str("    cmp     r0, #1\n");
    s.push_str("    beq.w   vupe_w_idle\n");

    // ── WALK: move ±1 toward current edge; when reached → IDLE ──────────
    // r6=areas_ptr, r7=area_count, r12=scratch_ptr
    s.push_str("    ldrb    r9, [r5, #20]          @ area_idx\n");
    s.push_str("    lsl     r0, r9, #3             @ idx*8\n");
    s.push_str("    add     r0, r0, #8\n");
    s.push_str("    add     r0, r6, r0             @ &area[idx]\n");
    s.push_str("    ldrsh   r9,  [r0, #2]          @ x_min\n");
    s.push_str("    ldrsh   r10, [r0, #4]          @ x_max\n");
    s.push_str("    ldr     r11, [r5, #4]          @ world_x (i32)\n");
    s.push_str("    ldrb    r0, [r5, #26]          @ dir (0=right, 1=left)\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    bne.w   vupe_w_walk_left\n");
    // dir=0: moving right toward x_max
    s.push_str("    add     r11, r11, #1\n");
    s.push_str("    cmp     r11, r10\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r11, r10\n");
    s.push_str("    str     r11, [r5, #4]          @ world_x\n");
    // Wall collision push-out (wander right). push {r6,r7,r12}: 36+12=48 aligned.
    s.push_str("    push    {r6, r7, r12}\n");
    s.push_str("    mov     r0, r11\n");
    s.push_str("    ldrsh   r1, [r5, #8]           @ world_y\n");
    s.push_str("    ldr     r6, [r5, #28]          @ type_data_ptr\n");
    s.push_str("    ldrb    r2, [r6, #6]           @ collision hw\n");
    s.push_str("    ldrb    r3, [r6, #7]           @ collision hh\n");
    s.push_str("    bl      vpy_level_collision_x\n");
    s.push_str("    pop     {r6, r7, r12}\n");
    s.push_str("    cmp     r0, #0\n    beq.w   vupe_wwr_wall_ok\n");
    s.push_str("    ldr     r1, [r5, #4]\n    add     r1, r1, r0\n    str     r1, [r5, #4]\n");
    s.push_str("    b.w     vupe_w_edge            @ wall hit → flip dir like reaching x_max\n");
    s.push_str("vupe_wwr_wall_ok:\n");
    s.push_str("    cmp     r11, r10\n");
    s.push_str("    bne.w   vupe_next\n");
    s.push_str("    b.w     vupe_w_edge\n");
    s.push_str("vupe_w_walk_left:\n");
    // dir=1: moving left toward x_min
    s.push_str("    sub     r11, r11, #1\n");
    s.push_str("    cmp     r11, r9\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r11, r9\n");
    s.push_str("    str     r11, [r5, #4]          @ world_x\n");
    // Wall collision push-out (wander left).
    s.push_str("    push    {r6, r7, r12}\n");
    s.push_str("    mov     r0, r11\n");
    s.push_str("    ldrsh   r1, [r5, #8]           @ world_y\n");
    s.push_str("    ldr     r6, [r5, #28]          @ type_data_ptr\n");
    s.push_str("    ldrb    r2, [r6, #6]           @ collision hw\n");
    s.push_str("    ldrb    r3, [r6, #7]           @ collision hh\n");
    s.push_str("    bl      vpy_level_collision_x\n");
    s.push_str("    pop     {r6, r7, r12}\n");
    s.push_str("    cmp     r0, #0\n    beq.w   vupe_wwl_wall_ok\n");
    s.push_str("    ldr     r1, [r5, #4]\n    add     r1, r1, r0\n    str     r1, [r5, #4]\n");
    s.push_str("    b.w     vupe_w_edge            @ wall hit → flip dir like reaching x_min\n");
    s.push_str("vupe_wwl_wall_ok:\n");
    s.push_str("    cmp     r11, r9\n");
    s.push_str("    bne.w   vupe_next\n");
    // Reached an edge → flip dir, pick random idle timer, enter IDLE
    s.push_str("vupe_w_edge:\n");
    s.push_str("    ldrb    r0, [r5, #26]          @ dir\n");
    s.push_str("    eor     r0, r0, #1             @ flip\n");
    s.push_str("    strb    r0, [r5, #26]\n");
    // call vpy_rand — preserves r4/r5 only; save r6,r7,r12 which we still need
    s.push_str("    push    {r6, r7, r12}\n");
    s.push_str("    bl      vpy_rand\n");
    s.push_str("    pop     {r6, r7, r12}\n");
    s.push_str("    and     r0, r0, #0x3F          @ 0..63\n");
    s.push_str("    add     r0, r0, #90            @ 90..153 frames (~2-3s)\n");
    s.push_str("    strh    r0, [r12, #0]          @ scratch_a = idle_timer\n");
    s.push_str("    mov     r0, #1\n");
    s.push_str("    strb    r0, [r5, #10]          @ sub_state = IDLE\n");
    s.push_str("    b.w     vupe_next\n");

    // ── IDLE: decrement timer; when done → pick transition or WALK ───────
    s.push_str("vupe_w_idle:\n");
    s.push_str("    ldrsh   r0, [r12, #0]          @ idle_timer\n");
    s.push_str("    sub     r0, r0, #1\n");
    s.push_str("    strh    r0, [r12, #0]\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    bgt.w   vupe_next\n");
    // Timer expired. Try to pick a transition.
    s.push_str("    ldr     r9,  [r6, #4]          @ trans_count\n");
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    beq.w   vupe_w_to_walk\n");
    // trans_ptr = areas_ptr + 8 + area_count*8
    s.push_str("    lsl     r0, r7, #3             @ area_count*8\n");
    s.push_str("    add     r10, r6, #8\n");
    s.push_str("    add     r10, r10, r0           @ r10 = trans_ptr\n");
    s.push_str("    ldrb    r11, [r5, #20]         @ cur_area_idx\n");
    s.push_str("    mov     r7, #0                 @ trans_loop_idx\n");
    s.push_str("vupe_w_pick:\n");
    s.push_str("    cmp     r7, r9\n");
    s.push_str("    bge.w   vupe_w_to_walk         @ exhausted\n");
    s.push_str("    lsl     r0, r7, #3             @ trans[i] offset (8 bytes each)\n");
    s.push_str("    add     r0, r10, r0\n");
    s.push_str("    ldrb    r1, [r0, #0]           @ trans.from\n");
    s.push_str("    cmp     r1, r11\n");
    s.push_str("    bne.w   vupe_w_pick_next\n");
    // Coin flip ~25%: call vpy_rand (clobbers r1-r3, r6-r11 except r4/r5)
    // Save: r6=areas_ptr, r7=loop_idx, r8=unused(pad for 8-byte align), r9=trans_count, r10=trans_ptr, r11=cur_area, r12=scratch
    s.push_str("    push    {r6, r7, r8, r9, r10, r11, r12}\n");
    s.push_str("    bl      vpy_rand\n");
    s.push_str("    pop     {r6, r7, r8, r9, r10, r11, r12}\n");
    s.push_str("    and     r0, r0, #3\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq.w   vupe_w_pick_hit\n");
    s.push_str("vupe_w_pick_next:\n");
    s.push_str("    add     r7, r7, #1\n");
    s.push_str("    b.w     vupe_w_pick\n");
    s.push_str("vupe_w_pick_hit:\n");
    // Commit transition: trans[r7] = {from,to,type,pad,from_x,to_x} (8 bytes)
    s.push_str("    lsl     r0, r7, #3\n");
    s.push_str("    add     r0, r10, r0            @ &trans[r7]\n");
    s.push_str("    ldrb    r1, [r0, #1]           @ to (target area idx)\n");
    s.push_str("    strb    r1, [r5, #20]          @ area_idx = target\n");
    s.push_str("    ldrb    r1, [r0, #2]           @ type\n");
    s.push_str("    strb    r1, [r5, #11]          @ pool+11 = trans_type\n");
    s.push_str("    ldrsh   r1, [r0, #4]           @ from_x\n");
    s.push_str("    strh    r1, [r12, #0]          @ scratch_a = from_x\n");
    s.push_str("    ldrsh   r1, [r0, #6]           @ to_x\n");
    s.push_str("    strh    r1, [r12, #2]          @ scratch_b = target_x\n");
    s.push_str("    mov     r0, #3\n");
    s.push_str("    strb    r0, [r5, #10]          @ sub_state = WALK_TO_TAKEOFF\n");
    s.push_str("    b.w     vupe_next\n");
    s.push_str("vupe_w_to_walk:\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r5, #10]          @ sub_state = WALK\n");
    s.push_str("    b.w     vupe_next\n");

    // ── WALK_TO_TAKEOFF: walk X toward from_x; when arrived → AIRBORNE ──
    // r6=areas_ptr, r7=area_count, r12=scratch_ptr
    s.push_str("vupe_w_to_takeoff:\n");
    s.push_str("    ldrsh   r9,  [r12, #0]         @ from_x (scratch_a)\n");
    s.push_str("    ldr     r10, [r5, #4]           @ world_x\n");
    s.push_str("    sub     r0, r9, r10             @ dx = from_x - x\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq.w   vupe_w_tt_reached\n");
    s.push_str("    bgt.w   vupe_w_tt_right\n");
    // dx < 0: walk left
    s.push_str("    mov     r1, #1\n");
    s.push_str("    strb    r1, [r5, #26]           @ dir = left\n");
    s.push_str("    sub     r10, r10, #1\n");
    s.push_str("    cmp     r10, r9\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r10, r9\n");
    s.push_str("    str     r10, [r5, #4]\n");
    s.push_str("    cmp     r10, r9\n");
    s.push_str("    bne.w   vupe_next\n");
    s.push_str("    b.w     vupe_w_tt_reached\n");
    s.push_str("vupe_w_tt_right:\n");
    s.push_str("    mov     r1, #0\n");
    s.push_str("    strb    r1, [r5, #26]           @ dir = right\n");
    s.push_str("    add     r10, r10, #1\n");
    s.push_str("    cmp     r10, r9\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r10, r9\n");
    s.push_str("    str     r10, [r5, #4]\n");
    s.push_str("    cmp     r10, r9\n");
    s.push_str("    bne.w   vupe_next\n");
    // Arrived at from_x → compute initial vy and switch to AIRBORNE
    s.push_str("vupe_w_tt_reached:\n");
    // Load target area y (area_idx was already updated to target at commit)
    s.push_str("    ldrb    r9,  [r5, #20]          @ target area_idx\n");
    s.push_str("    lsl     r0,  r9, #3             @ idx*8\n");
    s.push_str("    add     r0,  r0, #8\n");
    s.push_str("    add     r0,  r6, r0             @ &area[target]\n");
    s.push_str("    ldrsh   r9,  [r0, #0]           @ target_area.y (raw)\n");
    // dy = target_y - current_y (both raw area.y values, before feet_offset)
    // Use raw area.y for arc calc; feet_offset applied on landing
    s.push_str("    ldrsh   r10, [r5, #8]           @ current world_y (has feet_offset)\n");
    s.push_str("    ldr     r1,  [r5, #28]          @ type_data_ptr\n");
    s.push_str("    cmp     r1, #0\n");
    s.push_str("    beq     vupe_w_tt_no_feet\n");
    s.push_str("    ldrsb   r1, [r1, #4]            @ feet_offset\n");
    s.push_str("    sub     r10, r10, r1            @ remove feet_offset → raw current area.y\n");
    s.push_str("vupe_w_tt_no_feet:\n");
    s.push_str("    sub     r11, r9, r10            @ dy = target.y - current.y\n");
    s.push_str("    ldrb    r6, [r5, #11]           @ trans_type\n");
    s.push_str("    cmp     r6, #2\n");
    s.push_str("    beq.w   vupe_w_tt_drop\n");
    s.push_str("    cmp     r6, #3\n");
    s.push_str("    beq.w   vupe_w_tt_across\n");
    // type=1 jump_up: find vy0 so vy0*(vy0+1)/2 >= dy, starting at 4, capped at 16
    s.push_str("    mov     r3, #4\n");
    s.push_str("vupe_w_tt_vy0_loop:\n");
    s.push_str("    add     r2, r3, #1\n");
    s.push_str("    mul     r2, r3, r2\n");
    s.push_str("    lsr     r2, r2, #1             @ peak = vy0*(vy0+1)/2\n");
    s.push_str("    cmp     r2, r11\n");
    s.push_str("    bge.w   vupe_w_tt_setvy\n");
    s.push_str("    add     r3, r3, #1\n");
    s.push_str("    cmp     r3, #16\n");
    s.push_str("    blt     vupe_w_tt_vy0_loop\n");
    s.push_str("    b.w     vupe_w_tt_setvy\n");
    s.push_str("vupe_w_tt_drop:\n");
    s.push_str("    mvn     r3, #0                 @ vy0 = -1\n");
    s.push_str("    b.w     vupe_w_tt_setvy\n");
    s.push_str("vupe_w_tt_across:\n");
    s.push_str("    mov     r3, #3                 @ vy0 = 3\n");
    s.push_str("vupe_w_tt_setvy:\n");
    s.push_str("    strh    r3, [r12, #0]           @ scratch_a = vy\n");
    s.push_str("    mov     r0, #2\n");
    s.push_str("    strb    r0, [r5, #10]           @ sub_state = AIRBORNE\n");
    // Face toward target_x
    s.push_str("    ldrsh   r0, [r12, #2]           @ target_x\n");
    s.push_str("    ldr     r1, [r5, #4]            @ x\n");
    s.push_str("    cmp     r0, r1\n");
    s.push_str("    bge.w   vupe_w_tt_face_r\n");
    s.push_str("    mov     r0, #1\n");
    s.push_str("    strb    r0, [r5, #26]           @ dir = left\n");
    s.push_str("    b.w     vupe_next\n");
    s.push_str("vupe_w_tt_face_r:\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r5, #26]           @ dir = right\n");
    s.push_str("    b.w     vupe_next\n");

    // ── AIRBORNE ─────────────────────────────────────────────────────────
    // Phase A (target_x not yet reached): step X by ±4, arc Y by vy; vy -= 1 clamped >= -3
    // Phase B (X done): lerp Y toward target platform y, then land
    s.push_str("vupe_w_air:\n");
    s.push_str("    ldr     r10, [r5, #4]           @ x\n");
    s.push_str("    ldrsh   r9,  [r12, #2]          @ target_x\n");
    s.push_str("    sub     r0, r9, r10             @ dx\n");
    s.push_str("    cmp     r0, #0\n");
    s.push_str("    beq.w   vupe_w_air_y_lerp\n");
    // Phase A: step X
    s.push_str("    bgt.w   vupe_w_air_xright\n");
    s.push_str("    sub     r10, r10, #4\n");
    s.push_str("    cmp     r10, r9\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r10, r9\n");
    s.push_str("    str     r10, [r5, #4]\n");
    s.push_str("    b.w     vupe_w_air_y_arc\n");
    s.push_str("vupe_w_air_xright:\n");
    s.push_str("    add     r10, r10, #4\n");
    s.push_str("    cmp     r10, r9\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r10, r9\n");
    s.push_str("    str     r10, [r5, #4]\n");
    s.push_str("vupe_w_air_y_arc:\n");
    s.push_str("    ldrsh   r0, [r5, #8]            @ y\n");
    s.push_str("    ldrsh   r1, [r12, #0]           @ vy\n");
    s.push_str("    add     r0, r0, r1\n");
    s.push_str("    strh    r0, [r5, #8]            @ y += vy\n");
    s.push_str("    sub     r1, r1, #1\n");
    s.push_str("    mvn     r2, #2                  @ -3 terminal velocity\n");
    s.push_str("    cmp     r1, r2\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r1, r2\n");
    s.push_str("    strh    r1, [r12, #0]           @ vy updated\n");
    s.push_str("    b.w     vupe_next\n");
    // Phase B: lerp Y toward target platform y, land when equal
    s.push_str("vupe_w_air_y_lerp:\n");
    s.push_str("    ldrb    r9,  [r5, #20]          @ target area_idx\n");
    s.push_str("    lsl     r0,  r9, #3\n");
    s.push_str("    add     r0,  r0, #8\n");
    s.push_str("    add     r0,  r6, r0             @ &area[target]\n");
    s.push_str("    ldrsh   r9,  [r0, #0]           @ target area.y (raw)\n");
    // Compute landing y = target_area.y + feet_offset
    s.push_str("    mov     r10, r9                 @ landing_y = target.y\n");
    s.push_str("    ldr     r1, [r5, #28]           @ type_data_ptr\n");
    s.push_str("    cmp     r1, #0\n");
    s.push_str("    beq     vupe_w_air_no_feet\n");
    s.push_str("    ldrsb   r1, [r1, #4]            @ feet_offset\n");
    s.push_str("    add     r10, r10, r1            @ landing_y = area.y + feet_offset\n");
    s.push_str("vupe_w_air_no_feet:\n");
    s.push_str("    ldrsh   r0, [r5, #8]            @ current y\n");
    s.push_str("    sub     r1, r10, r0             @ delta = landing_y - y\n");
    s.push_str("    cmp     r1, #0\n");
    s.push_str("    beq.w   vupe_w_air_land\n");
    s.push_str("    bgt.w   vupe_w_air_yup\n");
    s.push_str("    sub     r0, r0, #4\n");
    s.push_str("    cmp     r0, r10\n");
    s.push_str("    it      lt\n");
    s.push_str("    movlt   r0, r10\n");
    s.push_str("    strh    r0, [r5, #8]\n");
    s.push_str("    cmp     r0, r10\n");
    s.push_str("    bne.w   vupe_next\n");
    s.push_str("    b.w     vupe_w_air_land\n");
    s.push_str("vupe_w_air_yup:\n");
    s.push_str("    add     r0, r0, #4\n");
    s.push_str("    cmp     r0, r10\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r0, r10\n");
    s.push_str("    strh    r0, [r5, #8]\n");
    s.push_str("    cmp     r0, r10\n");
    s.push_str("    bne.w   vupe_next\n");
    s.push_str("vupe_w_air_land:\n");
    s.push_str("    strh    r10, [r5, #8]           @ snap to landing_y\n");
    s.push_str("    mov     r0, #0\n");
    s.push_str("    strb    r0, [r5, #10]           @ sub_state = WALK\n");
    s.push_str("    b.w     vupe_next\n");

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
    s.push_str("    ldrsh   r2, [r5, #8]         @ world_y (i16)\n");
    s.push_str("    sub     r2, r2, r7           @ screen_y\n");
    // pool.world_y already includes feet_offset (baked in by wander snap).
    // branch on is_anim: VEC → vpy_draw_vector_ex, VANIM → vpy_draw_anim
    s.push_str("    ldrb    r3, [r5, #23]        @ is_anim\n");
    s.push_str("    cmp     r3, #0\n");
    s.push_str("    bne.w   vdre_use_anim\n");
    // static vector path — respect dir + mirror_on_patrol just like anim path
    s.push_str("    ldrb    r3, [r5, #26]        @ dir (0=right, 1=left)\n");
    s.push_str("    ldrb    r12, [r5, #27]       @ mirror_on_patrol\n");
    s.push_str("    and     r3, r3, r12          @ mirror = dir & mirror_on_patrol\n");
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
    s.push_str("    ldrsh   r0, [r0, #8]            @ world_y (i16 sign-extended)\n");
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
    s.push_str("    strh    r1, [r0, #8]            @ world_y (i16)\n");
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
    // Entry = type_data + 16 + new_state * 8 (header is 16 bytes: counts+feet+event+hw+hh+idle)
    s.push_str("    lsl     r0, r1, #3           @ new_state * 8\n");
    s.push_str("    add     r0, r0, #16          @ skip header\n");
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

    s.push_str("@ vpy_set_enemy_dir(r0=idx, r1=dir) — write dir into pool+26\n");
    s.push_str(".global vpy_set_enemy_dir\n.type vpy_set_enemy_dir, %function\n.thumb_func\n");
    s.push_str("vpy_set_enemy_dir:\n");
    s.push_str("    lsl     r2, r0, #5           @ idx * 32\n");
    s.push_str("    ldr     r0, =ENEMY_POOL_ARM\n");
    s.push_str("    add     r0, r0, r2           @ pool slot\n");
    s.push_str("    strb    r1, [r0, #26]        @ pool+26 = dir\n");
    s.push_str("    bx      lr\n\n");

    // vpy_enemy_fire_event(r0=idx, r1=event_name_ptr)
    // Looks up event routing table in type_data (header byte +5 = event_count).
    // For each entry: from_state(u8) + to_state(u8) + pad(2) + name[0..4](u32) + name[4..8](u32).
    // On match: transitions state and updates pool sprite from state table.
    // Falls back to increment logic when no event table present (backward compat).
    // Guards 'onFire*' events on non-frog enemies (event table absent OR event_count < 4).
    s.push_str("@ vpy_enemy_fire_event(r0=idx, r1=event_name_ptr) — event-routed state transition\n");
    s.push_str(".global vpy_enemy_fire_event\n.type vpy_enemy_fire_event, %function\n.thumb_func\n");
    s.push_str("vpy_enemy_fire_event:\n");
    // 10 regs = 40 bytes → SP stays 8-byte aligned
    s.push_str("    push    {r4, r5, r6, r7, r8, r9, r10, r11, r12, lr}\n");
    s.push_str("    mov     r7, r1               @ save event name ptr\n");
    // pool slot: r4
    s.push_str("    lsl     r12, r0, #5          @ idx * 32\n");
    s.push_str("    ldr     r4, =ENEMY_POOL_ARM\n");
    s.push_str("    add     r4, r4, r12          @ r4 = pool slot\n");
    // state array: r6 = ENEMY_STATE_ARM, r5 = idx*4
    s.push_str("    lsl     r5, r0, #2           @ idx * 4\n");
    s.push_str("    ldr     r6, =ENEMY_STATE_ARM\n");
    s.push_str("    ldr     r2, [r6, r5]         @ r2 = current state\n");
    // type_data: r3
    s.push_str("    ldr     r3, [r4, #28]        @ r3 = type_data_ptr\n");
    s.push_str("    cbz     r3, vefe_done        @ no type data\n");
    // state_count and max_state
    s.push_str("    ldr     r8, [r3, #0]         @ r8 = state_count\n");
    s.push_str("    sub     r11, r8, #1          @ r11 = max_state\n");
    // event_count from header byte +5
    s.push_str("    ldrb    r9, [r3, #5]         @ r9 = event_count\n");
    s.push_str("    cmp     r9, #0\n");
    s.push_str("    bne.w   vefe_have_events\n");
    // ── No event table: fall back to original guard + increment ──────────────
    // Guard: skip 'onFire*' on enemies without fire states (max_state < 4).
    s.push_str("    cbz     r7, vefe_inc\n");
    s.push_str("    cmp     r11, #4              @ max_state >= 4 has fire states\n");
    s.push_str("    bge.w   vefe_inc\n");
    s.push_str("    ldr     r0, [r7, #0]         @ first 4 bytes of event name\n");
    s.push_str("    movw    r12, #0x6E6F\n");
    s.push_str("    movt    r12, #0x6946         @ 0x69466E6F = 'onFi'\n");
    s.push_str("    cmp     r0, r12\n");
    s.push_str("    beq.w   vefe_done            @ 'onFire*' on non-frog: skip\n");
    s.push_str("vefe_inc:\n");
    s.push_str("    add     r2, r2, #1\n");
    s.push_str("    cmp     r2, r11\n");
    s.push_str("    it      gt\n");
    s.push_str("    movgt   r2, r11\n");
    s.push_str("    str     r2, [r6, r5]         @ store new state\n");
    s.push_str("    b.w     vefe_update_sprite\n");
    // ── Event table lookup ───────────────────────────────────────────────────
    s.push_str("vefe_have_events:\n");
    // event table base = type_data + 16 + state_count * 8
    s.push_str("    lsl     r0, r8, #3           @ state_count * 8\n");
    s.push_str("    add     r0, r0, #16\n");
    s.push_str("    add     r10, r3, r0          @ r10 = event table base\n");
    // load event name bytes for comparison (safe: .asciz + .align pads to >=4)
    s.push_str("    cbz     r7, vefe_done        @ null event ptr\n");
    s.push_str("    ldr     r8, [r7, #0]         @ name bytes 0-3\n");
    s.push_str("    ldr     r0, [r7, #4]         @ name bytes 4-7\n");
    // search loop: r11 = event idx
    s.push_str("    mov     r11, #0\n");
    s.push_str("vefe_ev_loop:\n");
    s.push_str("    cmp     r11, r9              @ idx < event_count?\n");
    s.push_str("    bge.w   vefe_done            @ not found → no-op\n");
    // entry offset = r11 * 12 (= r11<<3 + r11<<2)
    s.push_str("    lsl     r1, r11, #3\n");
    s.push_str("    lsl     r12, r11, #2\n");
    s.push_str("    add     r1, r1, r12\n");
    s.push_str("    add     r1, r10, r1          @ r1 = &entry\n");
    s.push_str("    ldrb    r12, [r1, #0]        @ from_state\n");
    s.push_str("    cmp     r12, r2\n");
    s.push_str("    bne     vefe_ev_next\n");
    s.push_str("    ldr     r12, [r1, #4]        @ name[0..3]\n");
    s.push_str("    cmp     r12, r8\n");
    s.push_str("    bne     vefe_ev_next\n");
    s.push_str("    ldr     r12, [r1, #8]        @ name[4..7]\n");
    s.push_str("    cmp     r12, r0\n");
    s.push_str("    bne     vefe_ev_next\n");
    // match: read to_state, commit
    s.push_str("    ldrb    r2, [r1, #1]         @ to_state\n");
    s.push_str("    str     r2, [r6, r5]         @ ENEMY_STATE_ARM[idx] = to_state\n");
    s.push_str("    b.w     vefe_update_sprite\n");
    s.push_str("vefe_ev_next:\n");
    s.push_str("    add     r11, r11, #1\n");
    s.push_str("    b.w     vefe_ev_loop\n");
    // ── Update pool sprite from state table ──────────────────────────────────
    s.push_str("vefe_update_sprite:\n");
    s.push_str("    lsl     r0, r2, #3           @ state * 8\n");
    s.push_str("    add     r0, r0, #16          @ skip header\n");
    s.push_str("    add     r0, r3, r0           @ ptr to state entry\n");
    s.push_str("    ldr     r1, [r0, #0]         @ sprite_ptr\n");
    s.push_str("    ldrb    r12, [r0, #4]        @ is_anim\n");
    s.push_str("    str     r1, [r4, #12]        @ pool sprite_ptr\n");
    s.push_str("    strb    r12, [r4, #23]       @ pool is_anim\n");
    s.push_str("    movs    r0, #0\n");
    s.push_str("    strb    r0, [r4, #24]        @ reset anim_frame_idx\n");
    s.push_str("    strb    r0, [r4, #25]        @ reset anim_ticks_left\n");
    s.push_str("vefe_done:\n");
    s.push_str("    pop     {r4, r5, r6, r7, r8, r9, r10, r11, r12, pc}\n\n");

    s.push_str("@ vpy_get_enemy_area_idx(r0=idx) -> r0=0 (stub)\n");
    s.push_str(".global vpy_get_enemy_area_idx\n.type vpy_get_enemy_area_idx, %function\n.thumb_func\n");
    s.push_str("vpy_get_enemy_area_idx:\n");
    s.push_str("    movs    r0, #0\n");
    s.push_str("    bx      lr\n\n");

    s
}
