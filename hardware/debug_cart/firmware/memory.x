/* RP2350 memory layout (Raspberry Pi Pico 2)
 * Flash: 4 MB W25Q32 @ 0x10000000 (XIP)
 *   - First 256 bytes: boot block / image definition
 *   - Remainder: firmware + game ROM image
 * RAM: 520 KB (512 KB main SRAM + 4 KB each for 2 scratch banks)
 *
 * NOTE: The custom debug_cart PCB uses a 2 MB W25Q16JV.
 *       This memory.x targets the Pico 2 prototype (4 MB flash).
 *       Adjust FLASH LENGTH to 2048K when building for the custom PCB.
 */
MEMORY {
    FLASH  : ORIGIN = 0x10000000, LENGTH = 4096K
    RAM    : ORIGIN = 0x20000000, LENGTH = 512K
    SCRATCH_X : ORIGIN = 0x20080000, LENGTH = 4K
    SCRATCH_Y : ORIGIN = 0x20081000, LENGTH = 4K
}

/* Game ROM image: last 32 KB of flash
 * vpy_cli --target rp2350 writes here during programming
 */
_game_rom_start = ORIGIN(FLASH) + LENGTH(FLASH) - 32K;
_game_rom_size  = 32K;
