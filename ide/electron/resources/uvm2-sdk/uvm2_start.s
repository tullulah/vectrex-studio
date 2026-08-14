@ uvm2_start.s — entry stub for a C/C++ game built for the UVM2.
@
@ The RP2350 cartridge is handed a game by a BIOS that has already brought the
@ machine up, so its games start at a bare `game_main`. The UVM2 has no BIOS:
@ the firmware copies the image to SRAM and jumps to the reset vector, and
@ everything after that — clocks, pads, the bus, the syscall handler — is ours.
@ So a UVM2 image begins with a REAL Cortex-M vector table, and vector 11
@ points at our own SVCall handler, which is what makes `svc #N` work at all.
@
@ This is the C counterpart of the table the VPy uvm2 backend emits inline
@ (vpy_codegen/src/uvm2/mod.rs); keep the two in step.

    .syntax unified
    .cpu cortex-m33
    .thumb

@ --- vector table, first bytes of the image ---
    .section .vectors, "ax"
    .align 2
    .word 0x20082000            @ initial SP = top of RP2350 SRAM (520 KB)
    .word game_main + 1         @ Reset_Handler (Thumb bit set)
    .word _uvm2_default_handler @ NMI
    .word _uvm2_default_handler @ HardFault
    .word _uvm2_default_handler @ MemManage
    .word _uvm2_default_handler @ BusFault
    .word _uvm2_default_handler @ UsageFault
    .word _uvm2_default_handler @ SecureFault
    .word _uvm2_default_handler @ reserved
    .word _uvm2_default_handler @ reserved
    .word _uvm2_default_handler @ reserved
    .word uvm2_svc_handler      @ SVCall — every libvpy builtin arrives here
    .word _uvm2_default_handler @ DebugMon
    .word _uvm2_default_handler @ reserved
    .word _uvm2_default_handler @ PendSV
    .word _uvm2_default_handler @ SysTick
    .rept 52                    @ external IRQs
    .word _uvm2_default_handler
    .endr

@ --- IMAGE_DEF, el bloque que el RP2350 exige para reconocer una imagen ---
@ Sin esto la imagen no es una imagen: es un monton de bytes que empiezan por algo
@ que se parece a una tabla de vectores. Es la SEGUNDA vez que este bloque nos
@ rompe la cadena UVM2 — la primera se tapo compilando aquel objetivo con el
@ pico-sdk, que lo emite solo, y este camino, escrito a mano, se quedo sin el.
@
@ MEDIDO, no supuesto: Asteroids_0_1a.um2 y Centipede_0_3a.um2 —las dos imagenes
@ de referencia que SI arrancan en el multicart— lo llevan en payload+0x15c, y las
@ siete palabras son identicas byte a byte en ambas. Ninguna imagen nuestra lo
@ tenia, ni la de 320 KB ni la de 5 KB, y ninguna arranco jamas.
@
@ Va dentro de .vectors para caer justo detras de la tabla, muy dentro de los
@ primeros 4 KB, que es donde hay que buscarlo.
    .word 0xffffded3            @ marca de inicio de bloque
    .word 0x10210142            @ IMAGE_DEF: ejecutable, ARM, RP2350
    .word 0x00000203            @ item VECTOR_TABLE, 2 palabras
    .word 0x20000000            @   -> la tabla esta en la base de la carga
    .word 0x000003ff            @ LAST_ITEM
    .word 0x00000000            @ sin bloque siguiente
    .word 0xab123579            @ marca de fin

    .text
    .align 2

@ Unexpected exceptions park here rather than running off into RAM.
    .global _uvm2_default_handler
    .thumb_func
_uvm2_default_handler:
    b       _uvm2_default_handler

@ --- entry ---
@ uvm2_runtime_init clears .bss itself (it must run before any C touches
@ static state), takes the vector table over, configures the pads and halts
@ the 6809. Only then is it safe to call into C.
    .global game_main
    .type game_main, %function
    .thumb_func
game_main:
    bl      uvm2_runtime_init

    @ Run the C++ static constructors. Nothing else will: this image has no C
    @ runtime, and a global object whose constructor never ran looks exactly
    @ like a logic bug at the far end of the program.
    ldr     r4, =__init_array_start
    ldr     r5, =__init_array_end
gm_ctor_loop:
    cmp     r4, r5
    bhs     gm_ctor_done
    ldr     r0, [r4], #4
    blx     r0
    b       gm_ctor_loop
gm_ctor_done:

    bl      main
gm_spin:                        @ main() loops forever; spin if it ever returns
    b       gm_spin
    .size game_main, . - game_main
