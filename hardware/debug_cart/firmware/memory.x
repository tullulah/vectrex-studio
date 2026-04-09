/* RP2040 memory layout
 * Flash: 2 MB W25Q16JV @ 0x10000000 (XIP)
 *   - First 256 bytes: boot2 second-stage bootloader
 *   - Remainder: firmware + game ROM image
 * RAM: 264 KB (256 KB main + 4 KB each for 2 scratch banks)
 */
MEMORY {
    BOOT2 : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH : ORIGIN = 0x10000100, LENGTH = 2048K - 0x100
    RAM   : ORIGIN = 0x20000000, LENGTH = 256K
    SCRATCH_X : ORIGIN = 0x20040000, LENGTH = 4K
    SCRATCH_Y : ORIGIN = 0x20041000, LENGTH = 4K
}

SECTIONS {
    .boot2 ORIGIN(BOOT2) : {
        KEEP(*(.boot2));
    } > BOOT2
} INSERT BEFORE .text;

/* Game ROM image stored at end of flash (last 32 KB of 2 MB flash)
 * vpy_cli --target rp2040 writes here during flash programming
 */
_game_rom_start = ORIGIN(FLASH) + LENGTH(FLASH) - 32K;
_game_rom_size  = 32K;
