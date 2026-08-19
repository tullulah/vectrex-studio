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
    .word 0x00000000        @ reserved[1]: el LANZADOR escribe aqui el descriptor del
                            @ romset ('RMZ1'), asi que el juego no puede usarlo.

@ --- de que romset viene este juego -----------------------------------------
@ El lanzador buscaba el zip por el nombre del .BIN, y eso solo acierta por
@ casualidad: aae_asteroids_sd.bin necesita asteroid.zip. Asi que el juego DICE
@ como se llama su romset, y el lanzador lee ese nombre.
@
@ Va detras de la cabecera y con MAGIA PROPIA para no romper las imagenes que no
@ lo declaran: quien no traiga 'RSET' aqui tendra codigo, y el lanzador vuelve a
@ deducirlo del nombre del fichero. Un juego lo declara definiendo el simbolo
@ game_romset_name; es DEBIL, asi que sin el vale cero.
    .word 0x54455352        @ 'RSET'
    .weak game_romset_name
    .word game_romset_name  @ -> cadena terminada en NUL, o 0 si no se declara
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
    @ Run the C++ static constructors — nothing else will (see the linker
    @ script). A C game's array is empty, so this costs it four instructions.
    ldr     r0, =__init_array_start
    ldr     r1, =__init_array_end
gm_ctor_loop:
    cmp     r0, r1
    bhs     gm_ctor_done
    ldr     r2, [r0], #4
    push    {r0, r1}
    blx     r2
    pop     {r0, r1}
    b       gm_ctor_loop
gm_ctor_done:
    bl      main
gm_spin:                    @ main() loops forever; spin if it ever returns
    b       gm_spin
    .size game_main, . - game_main
