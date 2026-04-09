/// GPIO pin assignments for the Vectrex Debug Cart
/// Matches hardware/debug_cart/COMPONENTS.md exactly.
/// All constants refer to RP2040 GPIO numbers.

// --- Address bus (A0–A14) via 74LVC245A U2/U3, 5V→3.3V level shift ---
// U2: A0-A7 → GP0-GP7
// U3: A8-A14 → GP8-GP14, /CE on GP23
pub const PIN_A0:  u8 = 0;
pub const PIN_A1:  u8 = 1;
pub const PIN_A2:  u8 = 2;
pub const PIN_A3:  u8 = 3;
pub const PIN_A4:  u8 = 4;
pub const PIN_A5:  u8 = 5;
pub const PIN_A6:  u8 = 6;
pub const PIN_A7:  u8 = 7;
pub const PIN_A8:  u8 = 8;
pub const PIN_A9:  u8 = 9;
pub const PIN_A10: u8 = 10;
pub const PIN_A11: u8 = 11;
pub const PIN_A12: u8 = 12;
pub const PIN_A13: u8 = 13;
pub const PIN_A14: u8 = 14;

// Bitmasks for address bus GPIO operations (SIO set/get)
pub const ADDR_LOW_MASK:  u32 = 0x00FF;  // GP0-GP7  (A0-A7)
pub const ADDR_HIGH_MASK: u32 = 0x7F00;  // GP8-GP14 (A8-A14)
pub const ADDR_MASK:      u32 = ADDR_LOW_MASK | ADDR_HIGH_MASK;

// --- Data bus (D0–D7) via 74LVC245A U4, bidirectional ---
pub const PIN_D0: u8 = 15;
pub const PIN_D1: u8 = 16;
pub const PIN_D2: u8 = 17;
pub const PIN_D3: u8 = 18;
pub const PIN_D4: u8 = 19;
pub const PIN_D5: u8 = 20;
pub const PIN_D6: u8 = 21;
pub const PIN_D7: u8 = 22;

pub const DATA_SHIFT: u8 = 15;                        // D0 starts at GP15
pub const DATA_MASK:  u32 = 0xFF << DATA_SHIFT;       // GP15-GP22

// --- Control signals from Vectrex (inputs in ROM mode) ---
pub const PIN_NCE:  u8 = 23;   // /CE  from Vectrex address decode (U3 B8)
pub const PIN_RW:   u8 = 24;   // R/W  (via 10k/18k voltage divider, ~3.21V)
pub const PIN_NOE:  u8 = 25;   // /OE  (via 10k/18k voltage divider)

// --- Open-drain control outputs (via BSS138 FETs) ---
// GPIO HIGH → FET conducts → Vectrex line pulled LOW (active)
// GPIO LOW  → FET off     → line pulled HIGH by 10k resistor (inactive)
pub const PIN_NNMI:  u8 = 26;  // /NMI  — non-maskable interrupt to 6809
pub const PIN_NHALT: u8 = 27;  // /HALT — halt the 6809, take bus control
pub const PIN_NRST:  u8 = 28;  // /RST  — reset the Vectrex (use with care)

// --- PSRAM chip select (APS6404L) ---
pub const PIN_PSRAM_CS: u8 = 29;  // GP29 → PSRAM CE#

// NOTE: address buffer direction control (U2/U3 DIR pins) is currently tied
// to GND in v1 schematic → fixed direction (Vectrex→RP2040 = ROM mode only).
// PCB revision needed before bus master mode is possible:
//   - U2 pin 1 (DIR) → new GPIO (e.g. reuse GP24 in bus master mode)
//   - U3 pin 1 (DIR) → same GPIO
// See FIRMWARE_PLAN.md Phase 0.
//
// Until then: bus master mode is NOT available on v1 hardware.
// ROM emulation mode (Phase 2) works as-is.

/// Helper: build full 32-bit GPIO word for address A (A0-A14 mapped to GP0-GP14)
#[inline(always)]
pub fn addr_to_gpio(addr: u16) -> u32 {
    (addr as u32) & ADDR_MASK
}

/// Helper: extract A0-A14 address from GPIO input word
#[inline(always)]
pub fn gpio_to_addr(gpio: u32) -> u16 {
    (gpio & ADDR_MASK) as u16
}

/// Helper: build GPIO word for data byte D0-D7 mapped to GP15-GP22
#[inline(always)]
pub fn data_to_gpio(byte: u8) -> u32 {
    (byte as u32) << DATA_SHIFT
}

/// Helper: extract data byte from GPIO input word
#[inline(always)]
pub fn gpio_to_data(gpio: u32) -> u8 {
    ((gpio >> DATA_SHIFT) & 0xFF) as u8
}
