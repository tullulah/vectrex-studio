/// VIA 6522 register map as seen on the Vectrex bus.
/// Base address: $D000. All accesses go through bus::write() / bus::read().

pub const VIA_BASE: u16 = 0xD000;

// Register offsets from VIA_BASE
pub const VIA_PORT_B:  u16 = 0x00;  // Port B data register
pub const VIA_PORT_A:  u16 = 0x01;  // Port A data register (DAC output: Y or X)
pub const VIA_DDR_B:   u16 = 0x02;  // Data Direction Register B (1=output)
pub const VIA_DDR_A:   u16 = 0x03;  // Data Direction Register A
pub const VIA_T1_LO:   u16 = 0x04;  // Timer 1 latch/counter low
pub const VIA_T1_HI:   u16 = 0x05;  // Timer 1 counter high (write starts timer)
pub const VIA_T1L_LO:  u16 = 0x06;  // Timer 1 latch low
pub const VIA_T1L_HI:  u16 = 0x07;  // Timer 1 latch high
pub const VIA_T2_LO:   u16 = 0x08;  // Timer 2 low
pub const VIA_T2_HI:   u16 = 0x09;  // Timer 2 high
pub const VIA_SR:      u16 = 0x0A;  // Shift Register (beam on/off via CB2)
pub const VIA_ACR:     u16 = 0x0B;  // Auxiliary Control Register
pub const VIA_PCR:     u16 = 0x0C;  // Peripheral Control Register
pub const VIA_IFR:     u16 = 0x0D;  // Interrupt Flag Register
pub const VIA_IER:     u16 = 0x0E;  // Interrupt Enable Register
pub const VIA_PORT_A2: u16 = 0x0F;  // Port A (no handshake)

// Absolute addresses
pub const fn reg(offset: u16) -> u16 { VIA_BASE + offset }

// --- Port B bit assignments ---
// PB0: Y/X mux (0 = tracking Y, 1 = tracking X direction)
// PB1: integrator enable / beam blanking (DSWM uses this for /BLANK via SR)
// PB2: sound (CB2 controls AY BC1 via PCR, shifted via SR)
// PB3–PB7: joystick buttons (inputs), sound chip control (BC2, /SEL)
pub const PB_MUX:    u8 = 0b0000_0001;  // bit 0: Y/X mux
pub const PB_BEAM:   u8 = 0b0000_0010;  // bit 1: beam enable
pub const PB_ZPULSE: u8 = 0b0000_0100;  // bit 2: zero reference pulse

// --- ACR values ---
pub const ACR_SR_DISABLED:  u8 = 0x00;
pub const ACR_SR_SHIFT_OUT: u8 = 0x18;  // SR shift out under PHI2 — needed for DSWM

// --- PCR values ---
pub const PCR_BEAM_OFF: u8 = 0xCE;  // /ZERO high, CB2 = low (beam off)
pub const PCR_BEAM_ON:  u8 = 0xDE;  // /ZERO high, CB2 = high (beam on)

// --- IFR bit ---
pub const IFR_T1: u8 = 0x40;  // bit 6: Timer 1 timeout

// --- T1 value for standard vector scale (matches DSWM) ---
// At 1.5 MHz 6809: T1=$7F → 85 µs per segment
// Same T1 used here ensures identical vector length as original BIOS
pub const T1_STANDARD: u8 = 0x7F;

// --- Vectrex RAM region (useful for reading game state if 6809 was running) ---
pub const VECTREX_RAM_BASE:  u16 = 0xC800;
pub const VECTREX_RAM_SIZE:  u16 = 0x0400;  // 1 KB

// --- BIOS ROM region (character table, utility routines) ---
pub const BIOS_ROM_BASE: u16 = 0xE000;
pub const BIOS_ROM_SIZE: u16 = 0x2000;  // 8 KB
