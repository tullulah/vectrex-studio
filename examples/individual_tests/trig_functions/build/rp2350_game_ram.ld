/* rp2350_game_ram.ld — link a VPy game to run from internal SRAM (RAM-loaded).
 *
 * Used for games loaded off the SD card by the cart launcher: the firmware
 * reads the .bin into 0x20040000 and jumps to its entry (game_header + 4), so
 * ALL absolute addresses — including the entry pointer — resolve for 0x20040000.
 * (Contrast rp2350_game.ld, which links for XIP at flash 0x10200000.)
 *
 * Memory map (coordinated with the firmware memory.x):
 *   0x20000000 - 0x2003FFFF   Firmware RAM (.bss/.data/heap) + BIOS stack
 *   0x20040000 - 0x2007EFFF   GAME_RAM — this game's code+rodata+data (252 KB)
 *   0x2007F000 - 0x2007FFFF   VPy runtime RAM (game variables; ram_layout.rs)
 */

MEMORY {
    GAME_RAM (rwx) : ORIGIN = 0x20040000, LENGTH = 252K
}

ENTRY(game_main)

SECTIONS {
    .game_rom 0x20040000 : {
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
