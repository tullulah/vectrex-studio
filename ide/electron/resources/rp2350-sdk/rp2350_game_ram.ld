/* rp2350_game_ram.ld — link a VPy game to run from internal SRAM (RAM-loaded).
 *
 * Used for games loaded off the SD card by the cart launcher: the firmware
 * reads the .bin into 0x20010000 and jumps to its entry (game_header + 4), so
 * ALL absolute addresses — including the entry pointer — resolve for 0x20010000.
 * (Contrast rp2350_game.ld, which links for XIP at flash 0x10200000.)
 *
 * Memory map (coordinated with the firmware sd.rs GAME_LOAD_ADDR + emulator):
 *   0x20000000 - 0x2000FFFF   BIOS static RAM (.bss is only 4 B) + game stack
 *   0x20010000 - 0x2007EFFF   GAME_RAM — this game's code+rodata+data (444 KB)
 *   0x2007F000 - 0x2007FFFF   VPy runtime RAM (game variables; ram_layout.rs)
 *
 * The BIOS's real static footprint is ~4 bytes (__ebss = 0x20000004) — its stack
 * lives at the top (0x2007F000, transient). So the old 256 KB "BIOS reserve" was
 * almost all free; GAME_RAM was lowered to 0x20010000 to fit large C ports (Major
 * Havoc's dual-6502 images are 200 KB). Loaded games run with SP at the origin,
 * so the 64 KB below (0x20000000-0x2000FFFF) is the game stack.
 */

MEMORY {
    GAME_RAM (rwx) : ORIGIN = 0x20010000, LENGTH = 444K
}

ENTRY(game_main)

SECTIONS {
    .game_rom 0x20010000 : {
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
