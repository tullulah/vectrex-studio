//! RP2350 image header for the game ROM section.
//!
//! Unlike the Vectrex M6809 cartridge (which needs a specific header at $0000),
//! the RP2350 game binary is a raw blob flashed to the last 32KB of flash.
//! The firmware reads it from flash and executes it — no boot block needed here.
//!
//! What we DO need:
//!   - A known entry point symbol (game_main) that the firmware can call
//!   - The Vectrex title string (stored in flash, used by firmware banner)
//!   - A magic word at offset 0 so the firmware can verify the slot is programmed

/// Magic word written at offset 0 of the game ROM.
/// Firmware checks for this before jumping to game_main.
/// "VPy2" in little-endian: 0x56 0x50 0x79 0x32
const GAME_MAGIC: u32 = 0x32795056;

pub fn emit_image_def() -> String {
    let mut s = String::new();

    s.push_str("@ --- Game ROM image header (offset 0 of game ROM slot) ---\n");
    s.push_str("@ Firmware checks GAME_MAGIC before calling game_main.\n\n");

    s.push_str(".global game_header\n");
    s.push_str(".type game_header, %object\n");
    s.push_str("game_header:\n");
    s.push_str(&format!("    .word 0x{:08X}      @ GAME_MAGIC 'VPy2'\n", GAME_MAGIC));
    s.push_str("    .word game_main         @ entry point (thumb bit set by linker)\n");
    s.push_str("    .word 0x00000000        @ reserved\n");
    s.push_str("    .word 0x00000000        @ reserved\n");
    s.push_str("\n");

    s
}
