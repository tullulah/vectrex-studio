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

    s
}
