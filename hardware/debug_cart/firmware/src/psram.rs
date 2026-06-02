#![allow(dead_code)] // PSRAM block API — used by Phase 2+ (ROM streaming)

/// APS6404L PSRAM driver — 8 MB, QSPI, shared bus with W25Q32 flash.
///
/// RP2350 uses QMI (QSPI Memory Interface) instead of RP2040's XIP_SSI.
/// QMI has two independent chip-select channels:
///   - CS0: boot flash (W25Q32 on Pico 2 / W25Q16 on custom PCB)
///   - CS1: available for PSRAM (APS6404L, CS = GP29)
///
/// This allows simultaneous XIP from flash AND direct PSRAM access
/// without disabling the cache — a significant improvement over RP2040.
///
/// Reference: RP2350 datasheet §12.14, APS6404L datasheet.

use rp235x_hal::pac;
use cortex_m::delay::Delay;

// APS6404L commands (SPI mode)
const CMD_RESET_ENABLE: u8 = 0x66;
const CMD_RESET:        u8 = 0x99;
const CMD_READ_ID:      u8 = 0x9F;
const CMD_FAST_READ:    u8 = 0x0B;
const CMD_WRITE:        u8 = 0x02;
#[allow(dead_code)]
const CMD_ENTER_QPI:    u8 = 0x35;
#[allow(dead_code)]
const CMD_QUAD_READ:    u8 = 0xEB;
#[allow(dead_code)]
const CMD_QUAD_WRITE:   u8 = 0x38;

// AP Memory manufacturer ID (returned by READ_ID)
const AP_MF_ID: u8 = 0x0D;

/// Initialise PSRAM via QMI CS1 and run a write/read self-test.
/// Returns true if PSRAM responds correctly.
///
/// On the Pico 2, GP47 is QMI CS1 (connected to PSRAM on the board).
/// On the custom debug_cart PCB, PSRAM CS is GP29 — verify the net.
pub fn init_and_test(delay: &mut Delay) -> bool {
    unsafe {
        let qmi = &*pac::QMI::ptr();

        // Configure QMI CS1 for SPI PSRAM access
        // Direct mode: CS1 controlled manually via QMI_DIRECT_CSR
        qmi.direct_csr().write(|w| {
            w.en().set_bit()           // enable direct mode
             .assert_cs1n().set_bit()  // assert CS1 initially deasserted
        });

        // Reset PSRAM
        qmi_cs1_transfer(qmi, &[CMD_RESET_ENABLE], &mut []);
        qmi_cs1_transfer(qmi, &[CMD_RESET], &mut []);

        // tRST = 100 µs minimum
        qmi.direct_csr().modify(|_, w| w.en().clear_bit()); // release direct mode briefly
        delay.delay_us(150);
        qmi.direct_csr().modify(|_, w| w.en().set_bit());

        // Read ID: CMD + 3 dummy address bytes + 2 ID bytes
        let mut id_buf = [0u8; 2];
        qmi_cs1_transfer(qmi, &[CMD_READ_ID, 0x00, 0x00, 0x00], &mut id_buf);

        if id_buf[0] != AP_MF_ID {
            qmi.direct_csr().write(|w| w.en().clear_bit());
            return false;
        }

        // Write test pattern at address 0x000000
        let pattern = [0xDE_u8, 0xAD, 0xBE, 0xEF, 0x12, 0x34, 0x56, 0x78];
        let write_cmd = [CMD_WRITE, 0x00, 0x00, 0x00];
        qmi_cs1_write(qmi, &write_cmd, &pattern);

        // Read back — Fast Read: cmd + addr + 1 dummy byte
        let mut readback = [0u8; 8];
        let read_cmd = [CMD_FAST_READ, 0x00, 0x00, 0x00, 0x00]; // last byte = dummy
        qmi_cs1_transfer(qmi, &read_cmd, &mut readback);

        qmi.direct_csr().write(|w| w.en().clear_bit());

        pattern == readback
    }
}

/// QMI direct mode: assert CS1, send cmd bytes, receive into rx (same length as rx).
unsafe fn qmi_cs1_transfer(qmi: &pac::qmi::RegisterBlock, cmd: &[u8], rx: &mut [u8]) {
    // Assert CS1
    qmi.direct_csr().modify(|_, w| w.assert_cs1n().clear_bit());

    // Send command bytes (TX only)
    for &b in cmd {
        qmi_tx(qmi, b);
        qmi_rx_drain(qmi); // discard received byte during command phase
    }

    // Receive bytes
    for slot in rx.iter_mut() {
        qmi_tx(qmi, 0x00); // send dummy to clock in data
        *slot = qmi_rx(qmi);
    }

    // Deassert CS1
    qmi.direct_csr().modify(|_, w| w.assert_cs1n().set_bit());
}

/// QMI direct mode: assert CS1, send cmd + data (write only).
unsafe fn qmi_cs1_write(qmi: &pac::qmi::RegisterBlock, cmd: &[u8], data: &[u8]) {
    qmi.direct_csr().modify(|_, w| w.assert_cs1n().clear_bit());
    for &b in cmd.iter().chain(data.iter()) {
        qmi_tx(qmi, b);
        qmi_rx_drain(qmi);
    }
    qmi.direct_csr().modify(|_, w| w.assert_cs1n().set_bit());
}

#[inline(always)]
unsafe fn qmi_tx(qmi: &pac::qmi::RegisterBlock, byte: u8) {
    while qmi.direct_csr().read().txfull().bit_is_set() {}
    qmi.direct_tx().write(|w| w.data().bits(byte as u16));
}

#[inline(always)]
unsafe fn qmi_rx(qmi: &pac::qmi::RegisterBlock) -> u8 {
    while qmi.direct_csr().read().rxempty().bit_is_set() {}
    qmi.direct_rx().read().direct_rx().bits() as u8
}

#[inline(always)]
unsafe fn qmi_rx_drain(qmi: &pac::qmi::RegisterBlock) {
    // Wait for RX byte and discard
    while qmi.direct_csr().read().rxempty().bit_is_set() {}
    let _ = qmi.direct_rx().read().bits();
}

/// Write a block of bytes to PSRAM.
/// addr: 24-bit PSRAM address (0x000000–0x7FFFFF)
pub fn write_block(addr: u32, data: &[u8]) {
    unsafe {
        let qmi = &*pac::QMI::ptr();
        qmi.direct_csr().modify(|_, w| w.en().set_bit());
        let cmd = [CMD_WRITE,
            ((addr >> 16) & 0xFF) as u8,
            ((addr >>  8) & 0xFF) as u8,
            ( addr        & 0xFF) as u8];
        qmi_cs1_write(qmi, &cmd, data);
        qmi.direct_csr().modify(|_, w| w.en().clear_bit());
    }
}

/// Read a block of bytes from PSRAM.
pub fn read_block(addr: u32, buf: &mut [u8]) {
    unsafe {
        let qmi = &*pac::QMI::ptr();
        qmi.direct_csr().modify(|_, w| w.en().set_bit());
        let cmd = [CMD_FAST_READ,
            ((addr >> 16) & 0xFF) as u8,
            ((addr >>  8) & 0xFF) as u8,
            ( addr        & 0xFF) as u8,
            0x00]; // dummy
        qmi_cs1_transfer(qmi, &cmd, buf);
        qmi.direct_csr().modify(|_, w| w.en().clear_bit());
    }
}
