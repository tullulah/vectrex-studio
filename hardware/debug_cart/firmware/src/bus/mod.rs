#![allow(dead_code)] // Bus master API — write path needs PCB v2

/// Bus master primitives — Phase 3
///
/// These functions assume:
///   - nHALT has been asserted (6809 halted, bus tri-stated)
///   - Address buffer direction has been switched to RP2350→Vectrex
///     (GP24 = ABUS_DIR = HIGH on PCB v1+)
///
/// PCB v1 limitation:
///   The Vectrex CART_RW line is not driven by the RP2350. When the 6809
///   HALTs it tri-states R/W; with R7/R8 removed there is no GPIO path
///   from the RP2350 to CART_RW. Result: only reads are reliable in bus
///   master mode (you must add a pullup on CART_RW to +5V so R/W floats
///   HIGH = read). VIA writes from the RP2350 require PCB v2 with a
///   74LVC1G04 inverter from GP29 (data DIR_CTRL) to CART_RW.
///
/// Toggle BUS_MASTER_AVAILABLE to true once the v2 PCB lands.

use rp235x_hal::pac;
use cortex_m::delay::Delay;
use crate::pins::*;

/// Set to true once PCB v2 (with R/W drive) is confirmed.
pub const BUS_MASTER_AVAILABLE: bool = false;

/// Minimum stable time (µs) for a bus cycle.
/// The VIA 6522 latches on the E clock rising edge (~667 ns period at 1.5 MHz).
/// Holding signals stable for 2 µs guarantees at least 1 full E cycle capture.
const BUS_CYCLE_US: u32 = 2;

/// Write a single byte to a Vectrex bus address.
/// Requires PCB v2 (R/W drive). No-op on v1.
pub fn write(delay: &mut Delay, addr: u16, data: u8) {
    if !BUS_MASTER_AVAILABLE { return; }

    let sio = unsafe { &*pac::SIO::ptr() };

    // Address bus: RP2350→Vectrex (GP24 = ABUS_DIR = HIGH; set by caller)
    sio.gpio_oe_set().write(|w| unsafe { w.bits(ADDR_MASK) });
    // Data bus: RP2350→Vectrex (GP29 = DIR_CTRL HIGH; this also drives the
    // v2 inverter that pulls CART_RW LOW = write cycle)
    sio.gpio_oe_set().write(|w| unsafe { w.bits(DATA_MASK) });
    sio.gpio_out_set().write(|w| unsafe { w.bits(1 << PIN_DIR_CTRL) });

    // Drive address and data
    let gpio_val = addr_to_gpio(addr) | data_to_gpio(data);
    sio.gpio_out_set().write(|w| unsafe { w.bits(gpio_val & (ADDR_MASK | DATA_MASK)) });
    sio.gpio_out_clr().write(|w| unsafe {
        w.bits((!gpio_val) & (ADDR_MASK | DATA_MASK))
    });

    delay.delay_us(BUS_CYCLE_US);

    // Release: data bus back to inputs, DIR_CTRL LOW (read default)
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(DATA_MASK) });
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_DIR_CTRL) });
}

/// Read a single byte from a Vectrex bus address.
/// Requires bus master mode. Returns 0xFF on v1.
pub fn read(delay: &mut Delay, addr: u16) -> u8 {
    if !BUS_MASTER_AVAILABLE { return 0xFF; }

    let sio = unsafe { &*pac::SIO::ptr() };

    // Address lines as outputs, data lines as inputs
    sio.gpio_oe_set().write(|w| unsafe { w.bits(ADDR_MASK) });
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(DATA_MASK) });
    // DIR_CTRL LOW → U4 direction Vectrex→RP2350 (read)
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_DIR_CTRL) });

    // Drive address
    let gpio_val = addr_to_gpio(addr);
    sio.gpio_out_set().write(|w| unsafe { w.bits(gpio_val & ADDR_MASK) });
    sio.gpio_out_clr().write(|w| unsafe { w.bits((!gpio_val) & ADDR_MASK) });

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
