/* rp2350_game_ram.ld — link a VPy game to run from internal SRAM (RAM-loaded).
 *
 * Used for games loaded off the SD card by the cart launcher: the firmware
 * reads the .bin into 0x20008000 and jumps to its entry (game_header + 4), so
 * ALL absolute addresses — including the entry pointer — resolve for 0x20008000.
 * (Contrast rp2350_game.ld, which links for XIP at flash 0x10200000.)
 *
 * Memory map (coordinated with the firmware sd.rs GAME_LOAD_ADDR + emulator):
 *   0x20000000 - 0x20007FFF   BIOS protected static RAM — ~20 KB .bss (control
 *                             block, SD/menu tables, core stacks), ends
 *                             ~0x20005000. DO NOT LET THE GAME TOUCH THIS.
 *   0x20008000 - 0x2007EFFF   GAME_RAM — this game's code+rodata+data+bss (476 KB).
 *                             The BIOS's 128 KB menu PREVIEW_BUF lives at
 *                             0x20040000 inside this window (menu-only; a running
 *                             game freely overwrites it — see firmware memory.x).
 *   0x2007F000 - 0x2007FFFF   VPy runtime RAM (game variables; ram_layout.rs)
 *
 * IMPORTANT: GAME_RAM MUST start above the BIOS's PROTECTED .bss. It was once
 * 0x20010000 on the false belief the BIOS used ~4 B of RAM (__ebss=0x20000004);
 * in reality the cart BIOS .bss was ~141 KB, so a game >64 KB overwrote the BIOS
 * control block (LAUNCH_PENDING/DC_LAUNCH_PENDING) and core 1's stack →
 * svc_dispatch read stale bytes as DC_LAUNCH_PENDING=true and diverted core 0
 * into the dual-core materialiser (black screen, e.g. Donkey Kong 305 KB). The
 * 128 KB PREVIEW_BUF has since been pushed high (game-overlapping), shrinking the
 * protected footprint to ~20 KB, so GAME_RAM can start at 0x20008000. The game
 * runs with SP = 0x2007F000 (set by launch_trampoline), growing DOWN into
 * GAME_RAM — not below the origin.
 */

MEMORY {
    GAME_RAM (rwx) : ORIGIN = 0x20008000, LENGTH = 476K
}

ENTRY(game_main)

SECTIONS {
    .game_rom 0x20008000 : {
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
