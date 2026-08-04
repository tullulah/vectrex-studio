/* rp2350_game.ld — Linker script for VPy game ROM on RP2350
 *
 * The RP2350 debug cartridge firmware writes game data to the upper 2MB of
 * its 4MB flash at offset GAME_ROM_OFFSET = 0x200000.
 * Absolute XIP address: 0x10000000 + 0x200000 = 0x10200000.
 *
 * Game code is ARM Thumb2 and runs directly from flash (XIP — no copy to RAM).
 * The firmware calls game_main() after mapping the Vectrex bus.
 *
 * Flash layout:
 *   0x10000000 - 0x101FFFFF  Firmware (first 2MB)
 *   0x10200000 - 0x103FFFFF  Game ROM (last 2MB) ← this script
 *
 * RAM:
 *   0x20000000 - 0x2007FFFF  SRAM (512KB, shared with firmware)
 *   Game RAM starts at 0x2007F000 (top 4KB reserved for VPy runtime)
 */

MEMORY {
    GAME_ROM (rx)  : ORIGIN = 0x10200000, LENGTH = 2048K
    GAME_RAM (rwx) : ORIGIN = 0x20008000, LENGTH = 476K
}

ENTRY(game_main)

SECTIONS {
    /* Game code and read-only data placed directly in flash (XIP) */
    .game_rom 0x10200000 : {
        KEEP(*(.game_rom))
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
        _erom = .;
    } > GAME_ROM

    /* Initialized data: stored in flash, copied to RAM at startup */
    _data_load = LOADADDR(.data);
    .data : {
        _data_start = .;
        *(.data)
        *(.data.*)
        . = ALIGN(4);
        _data_end = .;
    } > GAME_RAM AT > GAME_ROM

    /* Zero-initialized data */
    .bss : {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > GAME_RAM

    /* Discard unwanted sections */
    /DISCARD/ : {
        *(.ARM.exidx*)
        *(.ARM.extab*)
    }
}
