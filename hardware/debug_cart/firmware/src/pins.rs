#![allow(dead_code)] // Hardware constants — used by Phase 2+ modules

/// GPIO pin assignments for the Vectrex Debug Cart (RP2350 / PCB v2)
/// Matches hardware/debug_cart/COMPONENTS.md exactly.

// --- Address bus (A0–A14) via 74LVC245A U2/U3, 5V→3.3V level shift ---
// U2: A0–A7  → GP0–GP7
// U3: A8–A14 → GP8–GP14; /CE on GP23
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

// Bitmasks for address bus GPIO operations (SIO set/clr)
pub const ADDR_LOW_MASK:  u32 = 0x00FF;  // GP0–GP7  (A0–A7)
pub const ADDR_HIGH_MASK: u32 = 0x7F00;  // GP8–GP14 (A8–A14)
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

pub const DATA_SHIFT: u8  = 15;                   // D0 starts at GP15
pub const DATA_MASK:  u32 = 0xFF << DATA_SHIFT;   // GP15–GP22

// --- Control signals from Vectrex (inputs) ---
// /CE comes through 74LVC245A U3 (already at 3.3V).
// /OE goes through a 10k+18k voltage divider (5V→3.21V).
pub const PIN_NCE: u8 = 23;  // /CE      (U3 B8)
pub const PIN_NOE: u8 = 25;  // /OE      (divisor 10k+18k)

// --- Address bus buffer direction (U2/U3 DIR) ---
// GP24 → U2 pin 1 + U3 pin 1 (DIR_A).
// LOW  = Vectrex→RP2350 (ROM emulation / read mode)
// HIGH = RP2350→Vectrex (bus master mode, Phase 3+)
// /OE of U2/U3 is hardwired to GND (always enabled — toggles via direction only).
pub const PIN_ABUS_DIR: u8 = 24;

// --- Open-drain control outputs (BSS138 FETs) ---
// GPIO HIGH → FET on → Vectrex line pulled to GND (signal asserted)
// GPIO LOW  → FET off → line pulled to +5V via 10k (signal deasserted)
pub const PIN_NNMI:  u8 = 26;  // /NMI  (Q1)
pub const PIN_NHALT: u8 = 27;  // /HALT (Q2)
pub const PIN_NRST:  u8 = 28;  // /RST  (Q3)

// --- Data bus buffer direction control ---
// GP29 → U4 pin 1 (DIR).
// LOW  = Vectrex→RP2350 (read)
// HIGH = RP2350→Vectrex (write)
pub const PIN_DIR_CTRL: u8 = 29;

// --- CART_RW drive (via U8 74LVC1G07 + R13 10k pullup to +5V) ---
// LOW  = U8 high-Z → R13 pulls CART_RW HIGH → read cycle (or idle)
// HIGH = U8 drives LOW → CART_RW LOW → write cycle
pub const PIN_CART_RW: u8 = 30;

// --- PSRAM CS (GP31 → U6 APS6404L pin 1) ---
pub const PIN_PSRAM_CS: u8 = 31;

// --- UART0 hardware on J_UART header ---
pub const PIN_UART_TX: u8 = 32;
pub const PIN_UART_RX: u8 = 33;

// --- microSD on SPI0 (Hirose DM3AT-SF push-push) ---
pub const PIN_SD_SCK:  u8 = 34;
pub const PIN_SD_MOSI: u8 = 35;
pub const PIN_SD_MISO: u8 = 36;
pub const PIN_SD_CS:   u8 = 37;
/// Card-detect: input with internal pullup. LOW = card present.
pub const PIN_SD_CD:   u8 = 38;

// --- PSRAM ---
// APS6404L CS# is driven by RP2350 QSPI_SS1_N (QMI CS1 hardware pin).
// No GPIO constant needed — firmware uses pac::QMI direct mode.

/// Helper: build full 32-bit GPIO word for address A (A0–A14 → GP0–GP14)
#[inline(always)]
pub fn addr_to_gpio(addr: u16) -> u32 {
    (addr as u32) & ADDR_MASK
}

/// Helper: extract A0–A14 address from GPIO input word
#[inline(always)]
pub fn gpio_to_addr(gpio: u32) -> u16 {
    (gpio & ADDR_MASK) as u16
}

/// Helper: build GPIO word for data byte D0–D7 mapped to GP15–GP22
#[inline(always)]
pub fn data_to_gpio(byte: u8) -> u32 {
    (byte as u32) << DATA_SHIFT
}

/// Helper: extract data byte from GPIO input word
#[inline(always)]
pub fn gpio_to_data(gpio: u32) -> u8 {
    ((gpio >> DATA_SHIFT) & 0xFF) as u8
}
