@ rp2350_start.s — RAM-loaded RP2350 game header + C entry stub.
@
@ SYS_LAUNCH reads the game .bin into GAME_RAM (0x20040000), checks the 'VPy2'
@ magic at offset 0, then bx'es to the entry pointer at game_header+4. The BIOS
@ has already done clocks/pins/VIA init and set a valid stack pointer, so the
@ game runs on the BIOS stack — game_main only has to give C a zeroed .bss and
@ call main(). (Mirrors the VPy arm backend's game_main: no SP setup, zero RAM,
@ run.) The .bin (objcopy) contains .text/.rodata/.data but NOT .bss, so .bss is
@ SRAM power-on garbage until we clear it.
    .syntax unified
    .cpu cortex-m33
    .thumb

@ --- image header at offset 0 (linker KEEPs .game_rom first at 0x20040000) ---
    .section .game_rom, "a", %progbits
    .global game_header
    .type game_header, %object
@ reserved[0] = DUAL-CORE flag. 0 = single-core (default; the BIOS runs the game
@ on core 0, drawing inline via svc — unchanged for VPy games). 0x44430001
@ ("DC" v1) = the game records its draws to the shared RAM buffer (svc-free) and
@ the BIOS launches it on core 1 while core 0 materialises the beam in parallel.
@ A game opts in at build time: -Wa,--defsym,DUAL_CORE_FLAG=0x44430001 (and it
@ must be built with -DVPY_DUAL_CORE so sdk_rp2350.c uses the RAM-record path).
    .ifndef DUAL_CORE_FLAG
    .set DUAL_CORE_FLAG, 0
    .endif
game_header:
    .word 0x32795056        @ GAME_MAGIC 'VPy2' (little-endian)
    .word game_main         @ entry point (linker sets the thumb bit)
    .word DUAL_CORE_FLAG    @ reserved[0] = dual-core flag (see above)
    .word 0x00000000        @ reserved
    .size game_header, . - game_header

@ --- C entry point the BIOS jumps to ---
    .text
    .align 2
    .global game_main
    .type game_main, %function
    .thumb_func
game_main:
    @ zero .bss [_bss_start, _bss_end) — RP2350 SRAM is not zero-initialised
    ldr     r0, =_bss_start
    ldr     r1, =_bss_end
    movs    r2, #0
gm_bss_loop:
    cmp     r0, r1
    bhs     gm_bss_done
    str     r2, [r0], #4
    b       gm_bss_loop
gm_bss_done:
    bl      main
gm_spin:                    @ main() loops forever; spin if it ever returns
    b       gm_spin
    .size game_main, . - game_main
