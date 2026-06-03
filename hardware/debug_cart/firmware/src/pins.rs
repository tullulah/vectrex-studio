#![allow(dead_code)] // Hardware constants — used by Phase 2+ modules

/// GPIO pin assignments for the Vectrex Debug Cart (RP2350B / PCB v2)
///
/// Layout strategy:
/// RP2350B QFN-80 rotated so SIDE A (pins 1-20, containing GPIO4-20) faces
/// the cartridge edge. This keeps the bus signals (address + /CE + ABUS_DIR)
/// physically close to the buffers U2/U3 and the card-edge connector,
/// minimising trace crossings on a 2-layer PCB.
///
/// QFN-80 sides:
///   - Side A (pins  1-20) ← faces card edge: A0..A14, /CE, ABUS_DIR
///   - Side B (pins 21-40) ← faces data buffer: D0..D7, DIR_CTRL, CART_RW, /OE sense
///   - Side C (pins 41-60) ← faces SD/UART connectors: SD, UART, PB6, CART, IRQ drive
///   - Side D (pins 61-80) ← faces memories + USB: QSPI flash/PSRAM, USB-C, HALT/NMI/RST drives

// ============================================================
// SIDE A — Bus signals facing card edge (via U2, U3 buffers)
// ============================================================

/// Address bus (15 pins → buffers U2 [A0-A7] and U3 [A8-A14])
pub const PIN_A0:  u8 = 4;
pub const PIN_A1:  u8 = 5;
pub const PIN_A2:  u8 = 6;
pub const PIN_A3:  u8 = 7;
pub const PIN_A4:  u8 = 8;
pub const PIN_A5:  u8 = 9;
pub const PIN_A6:  u8 = 10;
pub const PIN_A7:  u8 = 11;
pub const PIN_A8:  u8 = 12;
pub const PIN_A9:  u8 = 13;
pub const PIN_A10: u8 = 14;
pub const PIN_A11: u8 = 15;
pub const PIN_A12: u8 = 16;
pub const PIN_A13: u8 = 17;
pub const PIN_A14: u8 = 18;

/// Cartridge chip enable from U3 B8 (3.3V, no divider needed — buffer level shifts)
pub const PIN_NCE: u8 = 19;

/// Address bus buffer direction (drives U2 pin 1 + U3 pin 1)
/// LOW = Vectrex→RP2350 (ROM read), HIGH = RP2350→Vectrex (bus master write)
pub const PIN_ABUS_DIR: u8 = 20;

/// Bitmasks for address bus GPIO operations
pub const ADDR_LOW_MASK:  u32 = 0x00000FF0;  // GP4–GP11  (A0–A7)
pub const ADDR_HIGH_MASK: u32 = 0x0007F000;  // GP12–GP18 (A8–A14)
pub const ADDR_MASK:      u32 = ADDR_LOW_MASK | ADDR_HIGH_MASK;

// ============================================================
// SIDE B — Data bus + bus control (via U4 buffer + U8 driver)
// ============================================================

/// Data bus (8 pins → buffer U4)
pub const PIN_D0: u8 = 21;
pub const PIN_D1: u8 = 22;
pub const PIN_D2: u8 = 23;
pub const PIN_D3: u8 = 24;
pub const PIN_D4: u8 = 25;
pub const PIN_D5: u8 = 26;
pub const PIN_D6: u8 = 27;
pub const PIN_D7: u8 = 28;

pub const DATA_SHIFT: u8  = 21;                   // D0 starts at GP21
pub const DATA_MASK:  u32 = 0xFF << DATA_SHIFT;   // GP21–GP28

/// Data buffer direction (drives U4 pin 1). LOW = read, HIGH = write.
pub const PIN_DIR_CTRL: u8 = 29;

/// CART_RW drive (drives input of U8 74LVC1G07 open-drain).
/// LOW = U8 high-Z → R6 pulls CART_RW HIGH (read).
/// HIGH = U8 pulls CART_RW LOW (write).
pub const PIN_CART_RW_DRV: u8 = 30;

/// /OE sense from card edge (5V → 3.21V via R4/R5 divider).
pub const PIN_NOE_SENSE: u8 = 31;

// ============================================================
// SIDE C — SD card + UART + vextreme extended signals + IRQ
// ============================================================

/// microSD on SPI0 (Hirose DM3AT-SF push-push)
pub const PIN_SD_SCK:  u8 = 34;
pub const PIN_SD_MOSI: u8 = 35;
pub const PIN_SD_MISO: u8 = 36;
pub const PIN_SD_CS:   u8 = 37;
/// Card-detect: input with internal pullup. LOW = card present.
pub const PIN_SD_CD:   u8 = 38;

/// UART0 hardware (J_UART1 header pinout)
pub const PIN_UART_TX: u8 = 39;
pub const PIN_UART_RX: u8 = 40;

/// VIA 6522 PB6 sense (CON1 pin 35 via R11/R12 divider 5V→3.21V).
/// Comparator output of DAC X — analog beam-cross-zero detection.
pub const PIN_PB6_SENSE: u8 = 41;

/// Vextreme CART signal sense (CON1 pin 32 via R13/R14 divider).
/// Status of Vectrex 74LS32 IC203A OR-gate (address decoder derived signal).
pub const PIN_CART_SENSE: u8 = 42;

// ============================================================
// SIDE D — 6809 input drives (Q1-Q4 BSS138 open-drain)
// ============================================================

/// GPIO HIGH → BSS138 conducts → 6809 line pulled to GND (signal asserted).
/// GPIO LOW  → BSS138 off → 10kΩ pullup to +5V → signal deasserted.
pub const PIN_NHALT_DRV: u8 = 0;
pub const PIN_NNMI_DRV:  u8 = 1;
pub const PIN_NRST_DRV:  u8 = 2;
pub const PIN_NIRQ_DRV:  u8 = 3;

// ============================================================
// PSRAM CS (location TBD — any spare GPIO on side D or C)
// ============================================================

/// PSRAM CS — drives U6 (APS6404L) pin 1 directly.
/// Note: not a QSPI hardware CS — uses QMI direct-mode via GPIO bit-bang.
pub const PIN_PSRAM_CS: u8 = 33;

// ============================================================
// Helpers
// ============================================================

/// Helper: build full 32-bit GPIO word for address A (A0–A14 → GP4–GP18)
#[inline(always)]
pub fn addr_to_gpio(addr: u16) -> u32 {
    ((addr as u32) << 4) & ADDR_MASK
}

/// Helper: extract A0–A14 address from GPIO input word
#[inline(always)]
pub fn gpio_to_addr(gpio: u32) -> u16 {
    ((gpio & ADDR_MASK) >> 4) as u16
}

/// Helper: build GPIO word for data byte D0–D7 mapped to GP21–GP28
#[inline(always)]
pub fn data_to_gpio(byte: u8) -> u32 {
    (byte as u32) << DATA_SHIFT
}

/// Helper: extract data byte from GPIO input word
#[inline(always)]
pub fn gpio_to_data(gpio: u32) -> u8 {
    ((gpio >> DATA_SHIFT) & 0xFF) as u8
}
