/* rp2350_game_ram.ld — link a VPy game to run from the cartridge's 8 MB PSRAM.
 *
 * 2026-08-02: GAME_RAM moved from internal SRAM to the **PSRAM XIP window at
 * 0x11000000**. Every game gets the full 8 MB; nothing is limited at compile time
 * because of where the cart happens to put it. The old 476 KB SRAM window is gone,
 * and rp2350_game_ram_8m.ld (which claimed 8 MB at 0x20010000 — a fiction, since
 * only 512 KB of SRAM exists there) is now identical to this file.
 *
 * The split that makes this work:
 *   0x11000000 - 0x117FFFFF   GAME_RAM — code + rodata + data + bss, in PSRAM.
 *   0x2007F000                SP, set by launch_trampoline — the stack stays in
 *                             internal SRAM and grows DOWN, so it is fast and is
 *                             never in the QSPI window.
 *   0x2007F000 - 0x2007FFFF   VPy runtime RAM (game variables; ram_layout.rs),
 *                             also internal SRAM.
 *
 * The BIOS keeps ALL of internal SRAM to itself now, so the old warnings about
 * overwriting its .bss / control block / core-1 stack no longer apply.
 *
 * REQUIREMENTS, both firmware-side: the PSRAM must be initialised and its XIP
 * window armed (psram::init) BEFORE a game is loaded, and XIP_CTRL.WRITABLE_M1
 * must be set or the loader's writes are silently discarded.
 *
 * IMPORTANT: the origin appears TWICE — in MEMORY and hardcoded on .game_rom.
 * Changing one and not the other is what made every VPy game FAULT once before.
 */

MEMORY {
    GAME_RAM (rwx) : ORIGIN = 0x11000000, LENGTH = 8192K
}

ENTRY(game_main)

SECTIONS {
    .game_rom 0x11000000 : {
        KEEP(*(.game_rom))
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)

        /* C++ static constructors. A freestanding image has no C runtime to run
         * these, so rp2350_start.s walks the array before main(). Without it a
         * C++ game whose globals have constructors starts with them unbuilt —
         * it links and boots, then misbehaves far from the cause. KEEP, or
         * --gc-sections drops the array entirely. */
        . = ALIGN(4);
        __init_array_start = .;
        KEEP(*(SORT_BY_INIT_PRIORITY(.init_array.*)))
        KEEP(*(.init_array))
        __init_array_end = .;
        . = ALIGN(4);
    } > GAME_RAM

    .data : {
        *(.data)
        *(.data.*)
        . = ALIGN(4);
    } > GAME_RAM

    .bss : {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > GAME_RAM

    /* Tabla de unwind VACIA, pero con sus simbolos.
     *
     * Las secciones se descartan (abajo) porque un programa freestanding no desenrolla
     * nada, pero el unwinder de libgcc referencia __exidx_start/__exidx_end igualmente si
     * algo lo arrastra. Los juegos que enlazan con -nostdlib nunca lo ven; dkong usa
     * --specs=nosys.specs y ahi si aparece: "undefined reference to __exidx_start" al
     * añadirle el cargador de ROM. Declararlos vacios es la solucion estandar: el
     * unwinder encuentra una tabla de cero entradas y no desenrolla, que es lo correcto.
     * PROVIDE para no pisar a nadie que los defina por su cuenta. */
    PROVIDE(__exidx_start = .);
    PROVIDE(__exidx_end   = .);

    /DISCARD/ : {
        *(.ARM.exidx*)
        *(.ARM.extab*)
    }
}
