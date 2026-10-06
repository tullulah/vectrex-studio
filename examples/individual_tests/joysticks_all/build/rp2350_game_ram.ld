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

    /DISCARD/ : {
        *(.ARM.exidx*)
        *(.ARM.extab*)
    }
}
