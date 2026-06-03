#![allow(dead_code)] // Bus master API — entry points used by Phase 3+

/// Bus master primitives — Phase 3+
///
/// In bus master mode the RP2350 takes full control of the Vectrex hardware
/// (VIA 6522 at $D000–$D00F, AY-3-8912 via VIA shift register, BIOS ROM at
/// $E000–$FFFF for shared LUTs). The 6809 is held in HALT for the entire
/// session. This is the architecture for native RP2350 games on real Vectrex
/// hardware.
///
/// Hardware control signals (RP2350B v1):
///   - nHALT  (GP27 → Q2): asserted = 6809 stopped, bus tri-stated
///   - ABUS_DIR (GP24): U2/U3 buffer direction — HIGH = RP2350→Vectrex
///   - DIR_CTRL (GP29): U4 data buffer direction — HIGH = RP2350→Vectrex
///   - CART_RW  (GP30 → U8 → R13): R/W line on Vectrex — HIGH = write cycle
///                                  LOW (or idle) = read cycle (pullup HIGH)

use rp235x_hal::pac;
use cortex_m::delay::Delay;
use crate::pins::*;

/// Bus master is available on PCB v1 RP2350B (U8 + R13 populated).
pub const BUS_MASTER_AVAILABLE: bool = true;

/// Minimum stable time (µs) for a bus cycle.
/// VIA 6522 latches on E rising edge (~667 ns at 1.5 MHz). 2 µs guarantees
/// at least 1 full E cycle.
const BUS_CYCLE_US: u32 = 2;

/// Switch into bus master mode. /HALT must already be asserted by the caller
/// and the 6809 given ≥ 7 µs to tri-state its bus.
pub fn enter_bus_master() {
    let sio = unsafe { &*pac::SIO::ptr() };

    // Configure control GPIOs as outputs
    sio.gpio_oe_set().write(|w| unsafe {
        w.bits(
            (1 << PIN_ABUS_DIR)
                | (1 << PIN_DIR_CTRL)
                | (1 << PIN_CART_RW),
        )
    });
    // ABUS_DIR HIGH → U2/U3 drive Vectrex from GP0-14
    sio.gpio_out_set().write(|w| unsafe { w.bits(1 << PIN_ABUS_DIR) });
    // Start in READ direction: DIR_CTRL LOW, CART_RW LOW (pullup → HIGH)
    sio.gpio_out_clr().write(|w| unsafe {
        w.bits((1 << PIN_DIR_CTRL) | (1 << PIN_CART_RW))
    });
    // Address bus GP0-14 as outputs (RP2350 drives addresses)
    sio.gpio_oe_set().write(|w| unsafe { w.bits(ADDR_MASK) });
    // Data bus GP15-22 as inputs (read default)
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(DATA_MASK) });
}

/// Leave bus master mode: tri-state everything so the 6809 can take over
/// when /HALT is released.
pub fn exit_bus_master() {
    let sio = unsafe { &*pac::SIO::ptr() };

    // CART_RW LOW so U8 stays high-Z (6809 can drive R/W)
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_CART_RW) });
    // DIR_CTRL LOW so U4 faces Vectrex→RP2350 (input)
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_DIR_CTRL) });
    // ABUS_DIR LOW so U2/U3 face Vectrex→RP2350
    sio.gpio_out_clr().write(|w| unsafe { w.bits(1 << PIN_ABUS_DIR) });
    // Address + data GPIOs back to inputs
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(ADDR_MASK | DATA_MASK) });
}

/// Write a single byte to a Vectrex bus address.
/// Caller must have called enter_bus_master() first.
pub fn write(delay: &mut Delay, addr: u16, data: u8) {
    let sio = unsafe { &*pac::SIO::ptr() };

    // Data bus as outputs
    sio.gpio_oe_set().write(|w| unsafe { w.bits(DATA_MASK) });

    // Drive address + data simultaneously
    let gpio_val = addr_to_gpio(addr) | data_to_gpio(data);
    sio.gpio_out_set().write(|w| unsafe { w.bits(gpio_val & (ADDR_MASK | DATA_MASK)) });
    sio.gpio_out_clr().write(|w| unsafe {
        w.bits((!gpio_val) & (ADDR_MASK | DATA_MASK))
    });

    // DIR_CTRL HIGH → U4 drives Vectrex; CART_RW HIGH → U8 pulls Vectrex R/W LOW
    sio.gpio_out_set().write(|w| unsafe {
        w.bits((1 << PIN_DIR_CTRL) | (1 << PIN_CART_RW))
    });

    delay.delay_us(BUS_CYCLE_US);

    // Release: CART_RW LOW (R/W HIGH via pullup), DIR_CTRL LOW, data back to input
    sio.gpio_out_clr().write(|w| unsafe {
        w.bits((1 << PIN_DIR_CTRL) | (1 << PIN_CART_RW))
    });
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(DATA_MASK) });
}

/// Read a single byte from a Vectrex bus address.
/// Caller must have called enter_bus_master() first.
pub fn read(delay: &mut Delay, addr: u16) -> u8 {
    let sio = unsafe { &*pac::SIO::ptr() };

    // Data bus as inputs; CART_RW LOW (read), DIR_CTRL LOW (U4 Vectrex→RP2350)
    sio.gpio_oe_clr().write(|w| unsafe { w.bits(DATA_MASK) });
    sio.gpio_out_clr().write(|w| unsafe {
        w.bits((1 << PIN_DIR_CTRL) | (1 << PIN_CART_RW))
    });

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
