//! Vectrex Debug Cart firmware — Phase 1: bringup
//!
//! On startup:
//!   1. Asserts /HALT → 6809 halts and tri-states the bus
//!   2. Initialises USB CDC (serial console at 115200 baud via USB)
//!   3. Tests PSRAM (APS6404L, 8 MB via QSPI) — write/read pattern
//!   4. Prints status to USB serial
//!   5. Enters command loop (echo input, future: 'm' memory dump, 'w' VIA write)
//!
//! Phase 2 (ROM emulation) and Phase 3 (bus master) are guarded behind
//! feature flags until the respective hardware is verified.

#![no_std]
#![no_main]

use panic_halt as _;

use rp235x_hal as hal;
use hal::{
    clocks::Clock,
    pac,
};
use cortex_m_rt::entry;
use embedded_hal::digital::OutputPin;

use usb_device::{class_prelude::*, prelude::*};
use usbd_serial::SerialPort;

mod pins;
mod vectrex_hal;
mod bus;
mod psram;
mod flash;

// RP2350 boot block — replaces RP2040's boot2.
// Tells the bootrom this is a valid secure executable image.
#[link_section = ".start_block"]
#[used]
pub static IMAGE_DEF: hal::block::ImageDef = hal::block::ImageDef::secure_exe();

const XTAL_FREQ_HZ: u32 = 12_000_000;

/// Simple write to USB serial, ignores errors (host may not be connected yet)
pub(crate) fn usb_print<B: usb_device::bus::UsbBus>(
    serial: &mut SerialPort<'_, B>,
    s: &[u8],
) {
    // USB CDC may need multiple writes if buffer is full
    let mut written = 0;
    while written < s.len() {
        match serial.write(&s[written..]) {
            Ok(n) => written += n,
            Err(_) => break,
        }
    }
}

/// Format u32 as decimal into a fixed buffer. Returns slice of used bytes.
#[allow(dead_code)] // used by Phase 2+ command responses
fn fmt_u32(val: u32, buf: &mut [u8; 10]) -> &[u8] {
    let mut n = val;
    let mut i = buf.len();
    if n == 0 {
        buf[9] = b'0';
        return &buf[9..];
    }
    while n > 0 && i > 0 {
        i -= 1;
        buf[i] = b'0' + (n % 10) as u8;
        n /= 10;
    }
    &buf[i..]
}

#[entry]
fn main() -> ! {
    //
    // 1. Peripheral init
    //
    let mut pac  = pac::Peripherals::take().unwrap();
    let core = cortex_m::peripheral::Peripherals::take().unwrap();

    let mut watchdog = hal::Watchdog::new(pac.WATCHDOG);

    // Init PLL: system clock 133 MHz, USB clock 48 MHz
    let clocks = hal::clocks::init_clocks_and_plls(
        XTAL_FREQ_HZ,
        pac.XOSC,
        pac.CLOCKS,
        pac.PLL_SYS,
        pac.PLL_USB,
        &mut pac.RESETS,
        &mut watchdog,
    ).ok().unwrap();

    let mut delay = cortex_m::delay::Delay::new(
        core.SYST,
        clocks.system_clock.freq().to_Hz(),
    );

    let sio  = hal::Sio::new(pac.SIO);
    let gpio = hal::gpio::Pins::new(
        pac.IO_BANK0,
        pac.PADS_BANK0,
        sio.gpio_bank0,
        &mut pac.RESETS,
    );

    //
    // 2. Assert /HALT immediately — 6809 stops within ~7 µs
    //
    // BSS138 FET: GPIO HIGH → gate driven → drain pulled low → /HALT asserted
    let mut nhalt = gpio.gpio27.into_push_pull_output();
    nhalt.set_high().unwrap();

    // NMI and RST idle (not asserted)
    let mut nnmi = gpio.gpio26.into_push_pull_output();
    nnmi.set_low().unwrap();
    let mut nrst = gpio.gpio28.into_push_pull_output();
    nrst.set_low().unwrap();

    // DIR_CTRL for data bus buffer U4: GP29, LOW = Vectrex→RP2350 (read/ROM mode)
    // Start LOW — RP2350 observes bus. Phase 3 (bus master) will drive HIGH to write.
    let mut dir_ctrl = gpio.gpio29.into_push_pull_output();
    dir_ctrl.set_low().unwrap();

    delay.delay_ms(1); // 6809 halts within ~7 µs — 1 ms is generous

    //
    // 3. USB CDC
    //
    let usb_bus = UsbBusAllocator::new(hal::usb::UsbBus::new(
        pac.USB,
        pac.USB_DPRAM,
        clocks.usb_clock,
        true,
        &mut pac.RESETS,
    ));

    let mut serial = SerialPort::new(&usb_bus);

    let mut usb_dev = UsbDeviceBuilder::new(&usb_bus, UsbVidPid(0x2E8A, 0x000A))
        .strings(&[StringDescriptors::default()
            .manufacturer("Vectrex Studio")
            .product("Debug Cart v1")
            .serial_number("0001")])
        .unwrap()
        .device_class(2)   // CDC
        .build();

    // Wait for USB host to enumerate (up to 2 seconds)
    let mut connected = false;
    let mut wait_ms = 0u32;
    while !connected && wait_ms < 2000 {
        if usb_dev.poll(&mut [&mut serial]) {
            if serial.line_coding().data_rate() > 0 {
                connected = true;
            }
        }
        delay.delay_ms(1);
        wait_ms += 1;
    }

    //
    // 4. Banner
    //
    usb_print(&mut serial, b"\r\n");
    usb_print(&mut serial, b"=== Vectrex Debug Cart v1 ===\r\n");
    usb_print(&mut serial, b"RP2350 @ 150 MHz  |  8 MB flash  |  8 MB PSRAM  |  FPU\r\n");
    usb_print(&mut serial, b"/HALT asserted: 6809 stopped.\r\n");
    usb_print(&mut serial, b"\r\n");

    //
    // 5. PSRAM self-test
    //
    usb_print(&mut serial, b"PSRAM test... ");
    let psram_ok = psram::init_and_test(&mut delay);
    if psram_ok {
        usb_print(&mut serial, b"OK (8 MB)\r\n");
    } else {
        usb_print(&mut serial, b"FAIL\r\n");
    }

    //
    // 6. Bus master status
    //
    if bus::BUS_MASTER_AVAILABLE {
        usb_print(&mut serial, b"Bus master: available (CART_RW via U8/R13)\r\n");
    } else {
        usb_print(&mut serial, b"Bus master: NOT available\r\n");
    }

    usb_print(&mut serial, b"\r\nReady. Commands: [r]om-mode  [H]alt  [U]nhalt  [F]lash  [?]help\r\n> ");

    //
    // 7. Command loop
    //
    let mut rx_buf = [0u8; 64];

    loop {
        if usb_dev.poll(&mut [&mut serial]) {
            if let Ok(n) = serial.read(&mut rx_buf) {
                for &b in &rx_buf[..n] {
                    match b {
                        b'?' | b'h' => {
                            usb_print(&mut serial, b"\r\nCommands:\r\n");
                            usb_print(&mut serial, b"  r - enter ROM emulation mode (Phase 2)\r\n");
                            usb_print(&mut serial, b"  H - assert /HALT\r\n");
                            usb_print(&mut serial, b"  U - release /HALT\r\n");
                            usb_print(&mut serial, b"  N - pulse /NMI\r\n");
                            usb_print(&mut serial, b"  R - pulse /RST\r\n");
                            usb_print(&mut serial, b"  F - flash game ROM (32KB max, resets after)\r\n");
                            usb_print(&mut serial, b"> ");
                        }
                        b'H' => {
                            nhalt.set_high().unwrap();
                            usb_print(&mut serial, b"HALT asserted\r\n> ");
                        }
                        b'U' => {
                            nhalt.set_low().unwrap();
                            usb_print(&mut serial, b"HALT released - 6809 running\r\n> ");
                        }
                        b'N' => {
                            nnmi.set_high().unwrap();
                            delay.delay_us(10);
                            nnmi.set_low().unwrap();
                            usb_print(&mut serial, b"NMI pulsed\r\n> ");
                        }
                        b'R' => {
                            nrst.set_high().unwrap();
                            delay.delay_ms(10);
                            nrst.set_low().unwrap();
                            // Re-assert HALT so 6809 doesn't run after reset
                            nhalt.set_high().unwrap();
                            usb_print(&mut serial, b"RST pulsed, HALT re-asserted\r\n> ");
                        }
                        b'r' => {
                            usb_print(&mut serial, b"ROM mode not yet implemented (Phase 2)\r\n> ");
                        }
                        b'F' => {
                            // Flash game ROM over USB CDC.
                            // receive_and_flash resets on success; if we reach here it errored.
                            flash::receive_and_flash(&mut usb_dev, &mut serial);
                            usb_print(&mut serial, b"> ");
                        }
                        b'\r' | b'\n' => {
                            usb_print(&mut serial, b"\r\n> ");
                        }
                        _ => {
                            // Echo character
                            serial.write(&[b]).ok();
                        }
                    }
                }
            }
        }
    }
}
