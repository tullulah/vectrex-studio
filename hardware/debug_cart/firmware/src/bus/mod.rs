/// Bus master primitives — Phase 3
///
/// These functions assume:
///   - nHALT has been asserted (6809 halted, bus tri-stated)
///   - Address buffer direction has been switched to RP2040→Vectrex
///     (requires PCB v2 with controllable U2/U3 DIR pins)
///
/// On PCB v1 (DIR tied to GND): only ROM emulation mode is available.
/// Calling bus_write/bus_read on v1 hardware will silently do nothing
/// (guarded by BUS_MASTER_AVAILABLE).

use rp2040_hal::pac;
use cortex_m::delay::Delay;
use crate::pins::*;

/// Set to true once PCB v2 is confirmed and DIR control is wired.
/// Change to `true` when building for v2 hardware.
pub const BUS_MASTER_AVAILABLE: bool = false;

/// Minimum stable time (µs) for a bus cycle.
/// The VIA 6522 latches on the E clock rising edge (~667 ns period at 1.5 MHz).
/// Holding signals stable for 2 µs guarantees at least 1 full E cycle capture.
const BUS_CYCLE_US: u32 = 2;

/// Write a single byte to a Vectrex bus address.
/// Address 0x0000–0x7FFF: cartridge space (no VIA chip select)
/// Address 0xC800–0xCFFF: Vectrex RAM
/// Address 0xD000–0xD00F: VIA 6522 registers  ← most useful
///
/// Requires bus master mode (PCB v2). No-op on v1.
pub fn write(delay: &mut Delay, addr: u16, data: u8) {
    if !BUS_MASTER_AVAILABLE { return; }

    let sio = unsafe { &*pac::SIO::ptr() };

    // Set address lines as outputs (GP0-GP14)
    sio.gpio_oe_set().write(|w| unsafe { w.bits(ADDR_MASK) });
    // Set data lines as outputs (GP15-GP22), DIR_CTRL already HIGH
    sio.gpio_oe_set().write(|w| unsafe { w.bits(DATA_MASK) });

    // Drive address and data
    let gpio_val = addr_to_gpio(addr) | data_to_gpio(data);
    sio.gpio_out_set().write(|w| unsafe { w.bits(gpio_val & (ADDR_MASK | DATA_MASK)) });
    sio.gpio_out_clr().write(|w| unsafe {
        w.bits((!gpio_val) & (ADDR_MASK | DATA_MASK))
    });

    // R/W = write (LOW)
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_RW) });

    // Hold stable for at least 2 µs — VIA will latch on next E rising edge
    delay.delay_us(BUS_CYCLE_US);

    // Release R/W
    sio.gpio_out_set().write(|w| unsafe { w.bits(1 << PIN_RW) });
}

/// Read a single byte from a Vectrex bus address.
/// Requires bus master mode (PCB v2). Returns 0xFF on v1.
pub fn read(delay: &mut Delay, addr: u16) -> u8 {
    if !BUS_MASTER_AVAILABLE { return 0xFF; }

    let sio = unsafe { &*pac::SIO::ptr() };

    // Address lines as outputs, data lines as inputs
    sio.gpio_oe_set().write(|w| unsafe { w.bits(ADDR_MASK) });
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(DATA_MASK) });
    // DIR_CTRL LOW → U4 direction Vectrex→RP2040 (read)
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_RW) }); // not needed but clean

    // Drive address
    let gpio_val = addr_to_gpio(addr);
    sio.gpio_out_set().write(|w| unsafe { w.bits(gpio_val & ADDR_MASK) });
    sio.gpio_out_clr().write(|w| unsafe { w.bits((!gpio_val) & ADDR_MASK) });

    // R/W = read (HIGH)
    sio.gpio_out_set().write(|w| unsafe { w.bits(1 << PIN_RW) });

    // Wait for data to be valid
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
