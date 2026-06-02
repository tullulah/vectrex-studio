#![allow(dead_code)] // Bus master API — entry point varies by firmware phase

/// Bus master primitives — Phase 3+
///
/// In bus master mode the RP2350 takes full control of the Vectrex hardware
/// (VIA 6522 at $D000–$D00F, AY-3-8912 via VIA shift register, BIOS ROM at
/// $E000–$FFFF for shared LUTs). The 6809 is held in HALT for the entire
/// session. This is the architecture for native RP2350 games on real Vectrex
/// hardware.
///
/// Hardware requirements (PCB v1+):
///   - nHALT asserted (GP27 HIGH → Q2 → CART_HALT LOW)
///   - ABUS_DIR HIGH (GP24 HIGH → U2/U3 buffers go RP2350→Vectrex)
///   - DIR_CTRL = GP29 controls BOTH data direction and R/W:
///       LOW  → U4 buffer Vectrex→RP2350 + U8 high-Z + R13 pulls CART_RW high → READ cycle
///       HIGH → U4 buffer RP2350→Vectrex + U8 drives CART_RW low → WRITE cycle
///
/// Address bus stays RP2350→Vectrex throughout bus master mode (we always
/// drive the address; only data direction and R/W flip).

use rp235x_hal::pac;
use cortex_m::delay::Delay;
use crate::pins::*;

/// Bus master is available on PCB v1 once U8 + R13 are populated.
pub const BUS_MASTER_AVAILABLE: bool = true;

/// Minimum stable time (µs) for a bus cycle.
/// The VIA 6522 latches on the E clock rising edge (~667 ns period at 1.5 MHz).
/// Holding signals stable for 2 µs guarantees at least 1 full E cycle capture.
const BUS_CYCLE_US: u32 = 2;

/// Switch into bus master mode. /HALT must already be asserted by the caller.
///
/// Sets ABUS_DIR HIGH (address bus RP2350→Vectrex), configures GP0–GP14 as
/// outputs, and starts in READ direction (DIR_CTRL LOW). The 6809 is assumed
/// to have tri-stated its bus already (≥7 µs after /HALT was asserted).
pub fn enter_bus_master() {
    let sio = unsafe { &*pac::SIO::ptr() };

    // ABUS_DIR HIGH → U2/U3 drive Vectrex side from GP0-14
    sio.gpio_out_set().write(|w| unsafe { w.bits(1 << PIN_ABUS_DIR) });
    // GP24 (ABUS_DIR) and GP29 (DIR_CTRL) as outputs
    sio.gpio_oe_set().write(|w| unsafe { w.bits((1 << PIN_ABUS_DIR) | (1 << PIN_DIR_CTRL)) });
    // Address bus GP0-14 as outputs
    sio.gpio_oe_set().write(|w| unsafe { w.bits(ADDR_MASK) });
    // Data bus GP15-22 as inputs (read default); DIR_CTRL LOW
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(DATA_MASK) });
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_DIR_CTRL) });
}

/// Leave bus master mode: tri-state everything we were driving so the 6809
/// can take over when /HALT is released.
pub fn exit_bus_master() {
    let sio = unsafe { &*pac::SIO::ptr() };

    // Address + data GPIOs back to inputs
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(ADDR_MASK | DATA_MASK) });
    // DIR_CTRL LOW → U4 buffer faces Vectrex→RP2350 + U8 high-Z (no R/W contention)
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_DIR_CTRL) });
    // ABUS_DIR LOW → U2/U3 back to Vectrex→RP2350
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_ABUS_DIR) });
}

/// Write a single byte to a Vectrex bus address.
/// Caller must have called enter_bus_master() first.
pub fn write(delay: &mut Delay, addr: u16, data: u8) {
    let sio = unsafe { &*pac::SIO::ptr() };

    // Data bus as outputs
    sio.gpio_oe_set().write(|w| unsafe { w.bits(DATA_MASK) });

    // Drive address and data simultaneously
    let gpio_val = addr_to_gpio(addr) | data_to_gpio(data);
    sio.gpio_out_set().write(|w| unsafe { w.bits(gpio_val & (ADDR_MASK | DATA_MASK)) });
    sio.gpio_out_clr().write(|w| unsafe {
        w.bits((!gpio_val) & (ADDR_MASK | DATA_MASK))
    });

    // DIR_CTRL HIGH → U4 drives Vectrex side + U8 pulls CART_RW LOW (write cycle)
    sio.gpio_out_set().write(|w| unsafe { w.bits(1 << PIN_DIR_CTRL) });

    // Hold for at least 1 full E cycle (667 ns) so the VIA latches
    delay.delay_us(BUS_CYCLE_US);

    // Release: DIR_CTRL LOW (R/W back to HIGH via pullup), data bus back to input
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_DIR_CTRL) });
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(DATA_MASK) });
}

/// Read a single byte from a Vectrex bus address.
/// Caller must have called enter_bus_master() first.
pub fn read(delay: &mut Delay, addr: u16) -> u8 {
    let sio = unsafe { &*pac::SIO::ptr() };

    // Data bus as inputs (should already be from enter_bus_master)
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(DATA_MASK) });
    // DIR_CTRL LOW = R/W HIGH (pullup) = read cycle
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_DIR_CTRL) });

    // Drive address
    let gpio_val = addr_to_gpio(addr);
    sio.gpio_out_set().write(|w| unsafe { w.bits(gpio_val & ADDR_MASK) });
    sio.gpio_out_clr().write(|w| unsafe { w.bits((!gpio_val) & ADDR_MASK) });

    // Wait for data valid (VIA needs ≥1 E cycle to respond)
    delay.delay_us(BUS_CYCLE_US);

    // Sample data bus
    let gpio_in = sio.gpio_in().read().bits();
    gpio_to_data(gpio_in)
}

/// Convenience: write to a VIA register by offset (0x00–0x0F)
#[inline(always)]
pub fn via_write(delay: &mut Delay, reg_offset: u16, data: u8) {
    write(delay, crate::vectrex_hal::VIA_BASE + reg_offset, data);
}

/// Convenience: read a VIA register by offset
#[inline(always)]
pub fn via_read(delay: &mut Delay, reg_offset: u16) -> u8 {
    read(delay, crate::vectrex_hal::VIA_BASE + reg_offset)
}
