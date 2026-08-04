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
