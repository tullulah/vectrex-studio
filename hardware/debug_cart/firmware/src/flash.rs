/// Game ROM self-flash over USB CDC.
///
/// Flash layout (W25Q64JV — 8MB chip, only lower 4MB used by v1 firmware):
///   0x10000000 – 0x103F7FFF  firmware (grows upward)
///   0x103F8000 – 0x103FFFFF  game ROM (32KB, fixed; offset relative to 4MB)
///   0x10400000 – 0x107FFFFF  unused 4MB upper half (future asset cache)
///
/// This module only writes the game ROM area — the firmware area is
/// never touched, so a failed game upload cannot corrupt the firmware.
/// Recovery from a bad firmware flash requires BOOTSEL + UF2.
///
/// Protocol (USB CDC, binary):
///   Host → Cart:  'F'  (already consumed by command loop)
///   Cart → Host:  "SEND SIZE\r\n"
///   Host → Cart:  4 bytes, little-endian, payload size (max 32768)
///   Cart → Host:  "SEND DATA\r\n"
///   Host → Cart:  <size> bytes of binary game ROM
///   Cart → Host:  "OK\r\n"   on success
///                 "ERR <reason>\r\n" on failure
///   Cart:         software reset after "OK"

use rp235x_hal as hal;
use cortex_m::interrupt;
use usb_device::{bus::UsbBus, device::UsbDevice};
use usbd_serial::SerialPort;

use crate::usb_print;

/// Offset of game ROM from flash base (= 4MB - 32KB)
const GAME_ROM_OFFSET: u32 = 4 * 1024 * 1024 - 32 * 1024; // 0x3F8000
const GAME_ROM_SIZE:   u32 = 32 * 1024;

/// W25Q64JV erase geometry (same as W25Q16/32/128 — all 4KB sectors)
const SECTOR_SIZE: u32 = 4 * 1024;        // 4KB — smallest erasable unit
const SECTOR_CMD:  u8  = 0x20;            // Sector Erase command

/// Static receive buffer — 32KB, in RAM.
/// Static to avoid blowing the stack; only one flash operation at a time.
static mut RX_BUF: [u8; GAME_ROM_SIZE as usize] = [0xFF; GAME_ROM_SIZE as usize];

/// State machine for receiving and writing the game ROM.
/// Call this once the 'F' byte has been consumed.
/// Returns when done (success or error). Caller should reset after OK.
pub fn receive_and_flash<B: UsbBus>(
    usb_dev: &mut UsbDevice<'_, B>,
    serial: &mut SerialPort<'_, B>,
) {
    usb_print(serial, b"SEND SIZE\r\n");

    // Receive 4-byte little-endian size
    let mut size_buf = [0u8; 4];
    receive_exact(usb_dev, serial, &mut size_buf);
    let size = u32::from_le_bytes(size_buf);

    if size == 0 || size > GAME_ROM_SIZE {
        usb_print(serial, b"ERR size out of range\r\n");
        return;
    }

    usb_print(serial, b"SEND DATA\r\n");

    // Receive binary payload into static buffer
    let buf = unsafe { &mut RX_BUF[..size as usize] };
    receive_exact(usb_dev, serial, buf);

    // Write to flash (interrupts disabled, executed from RAM via ROM functions)
    let result = write_game_rom(buf);

    match result {
        Ok(()) => {
            usb_print(serial, b"OK\r\n");
            // Short delay so the host can read "OK" before we reset
            cortex_m::asm::delay(12_000_000); // ~100ms @ 120MHz
            cortex_m::peripheral::SCB::sys_reset();
        }
        Err(msg) => {
            usb_print(serial, b"ERR ");
            usb_print(serial, msg.as_bytes());
            usb_print(serial, b"\r\n");
        }
    }
}

/// Block until exactly `buf.len()` bytes are received from the USB CDC.
fn receive_exact<B: UsbBus>(
    usb_dev: &mut UsbDevice<'_, B>,
    serial: &mut SerialPort<'_, B>,
    buf: &mut [u8],
) {
    let mut received = 0;
    while received < buf.len() {
        if usb_dev.poll(&mut [serial]) {
            if let Ok(n) = serial.read(&mut buf[received..]) {
                received += n;
            }
        }
    }
}

/// Erase + program game ROM area. Must run with interrupts disabled.
fn write_game_rom(data: &[u8]) -> Result<(), &'static str> {
    let sector_count = (data.len() as u32).div_ceil(SECTOR_SIZE);

    // Disable interrupts and write — flash is not accessible during programming
    interrupt::free(|_| unsafe {
        // Erase sectors
        for i in 0..sector_count {
            let offset = GAME_ROM_OFFSET + i * SECTOR_SIZE;
            hal::rom_data::flash_range_erase(offset, SECTOR_SIZE as usize, SECTOR_SIZE, SECTOR_CMD);
        }

        // Program in 256-byte pages (flash page size)
        const PAGE: usize = 256;
        let mut written = 0usize;
        while written < data.len() {
            let end = (written + PAGE).min(data.len());
            let chunk = &data[written..end];
            // Pad last chunk to full page with 0xFF if needed
            if chunk.len() == PAGE {
                hal::rom_data::flash_range_program(
                    GAME_ROM_OFFSET + written as u32,
                    chunk.as_ptr(),
                    PAGE,
                );
            } else {
                let mut page = [0xFF_u8; PAGE];
                page[..chunk.len()].copy_from_slice(chunk);
                hal::rom_data::flash_range_program(
                    GAME_ROM_OFFSET + written as u32,
                    page.as_ptr(),
                    PAGE,
                );
            }
            written += chunk.len();
        }
    });

    Ok(())
}
