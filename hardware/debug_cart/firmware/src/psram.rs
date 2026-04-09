/// APS6404L PSRAM driver — 8 MB, QSPI, shared bus with W25Q16JV flash.
///
/// The RP2040's XIP (Execute-In-Place) controller owns the QSPI bus for
/// flash access. To talk to the PSRAM (CS = GP29), we must:
///   1. Disable the XIP cache / direct mode briefly
///   2. Use the SSI (XIP_SSI peripheral) in manual mode
///   3. Assert PSRAM_CS (GP29 low), transfer, deassert
///   4. Re-enable XIP
///
/// This is safe as long as all code and data needed during the transfer
/// live in RAM (no flash fetches). The functions here are marked
/// #[link_section = ".data"] to ensure they run from RAM.
///
/// Reference: RP2040 datasheet §4.10.3, APS6404L datasheet.

use rp2040_hal::pac;
use cortex_m::delay::Delay;

// APS6404L commands
const CMD_RESET_ENABLE: u8 = 0x66;
const CMD_RESET:        u8 = 0x99;
const CMD_READ_ID:      u8 = 0x9F;
const CMD_FAST_READ:    u8 = 0x0B;
const CMD_WRITE:        u8 = 0x02;
const CMD_ENTER_QPI:    u8 = 0x35;
const CMD_QUAD_READ:    u8 = 0xEB;
const CMD_QUAD_WRITE:   u8 = 0x38;

// GP29 = PSRAM_CS — controlled via SIO directly (faster than GPIO API)
const PSRAM_CS_MASK: u32 = 1 << 29;

/// Assert PSRAM CS (GP29 low)
#[inline(always)]
unsafe fn cs_low() {
    let sio = &*pac::SIO::ptr();
    sio.gpio_out_clr().write(|w| w.bits(PSRAM_CS_MASK));
}

/// Deassert PSRAM CS (GP29 high)
#[inline(always)]
unsafe fn cs_high() {
    let sio = &*pac::SIO::ptr();
    sio.gpio_out_set().write(|w| w.bits(PSRAM_CS_MASK));
}

/// Transfer one byte via SSI (SPI mode, clock gated by XIP_SSI peripheral).
/// Caller must have disabled XIP and set SSI to manual mode before calling.
#[inline(always)]
unsafe fn ssi_transfer(byte: u8) -> u8 {
    let ssi = &*pac::XIP_SSI::ptr();
    // Wait for TX FIFO not full
    while ssi.sr().read().tfnf().bit_is_clear() {}
    ssi.dr0().write(|w| w.dr().bits(byte as u32));
    // Wait for RX FIFO not empty
    while ssi.sr().read().rfne().bit_is_clear() {}
    ssi.dr0().read().dr().bits() as u8
}

/// Disable XIP cache and switch SSI to manual SPI mode.
/// Returns the previous BAUDR value so it can be restored.
/// Must run from RAM — no flash access between disable and restore.
#[link_section = ".data.psram"]
unsafe fn xip_disable() -> u32 {
    let xip_ctrl = &*pac::XIP_CTRL::ptr();
    let ssi = &*pac::XIP_SSI::ptr();

    // Flush and disable the XIP cache
    xip_ctrl.flush().write(|w| w.flush().set_bit());
    while xip_ctrl.flush().read().flush().bit_is_set() {}
    xip_ctrl.ctrl().modify(|_, w| w.en().clear_bit());

    // Disable SSI to reconfigure
    ssi.ssienr().write(|w| w.ssi_en().clear_bit());

    // Save and set baud rate (133 MHz / 4 = 33.25 MHz — fast enough for PSRAM)
    let saved_baudr = ssi.baudr().read().bits();
    ssi.baudr().write(|w| w.bits(4));

    // SPI frame format: standard SPI, 8-bit, EEPROM read (FRF=0, DFS=7, TMOD=3)
    ssi.ctrlr0().write(|w| unsafe {
        w.spi_frf().bits(0)     // Standard SPI
         .dfs_32().bits(7)      // 8-bit frames
         .tmod().bits(0b11)     // TX and RX (EEPROM mode)
    });

    // Re-enable SSI
    ssi.ssienr().write(|w| w.ssi_en().set_bit());

    saved_baudr
}

/// Re-enable XIP after PSRAM access.
#[link_section = ".data.psram"]
unsafe fn xip_restore(saved_baudr: u32) {
    let xip_ctrl = &*pac::XIP_CTRL::ptr();
    let ssi = &*pac::XIP_SSI::ptr();

    ssi.ssienr().write(|w| w.ssi_en().clear_bit());
    ssi.baudr().write(|w| w.bits(saved_baudr));
    // Restore SSI to XIP mode (configured by boot2, we just re-enable)
    ssi.ssienr().write(|w| w.ssi_en().set_bit());

    // Re-enable XIP cache
    xip_ctrl.ctrl().modify(|_, w| w.en().set_bit());
}

/// Initialise PSRAM and run a quick write/read self-test.
/// Returns true if PSRAM responds correctly.
pub fn init_and_test(delay: &mut Delay) -> bool {
    unsafe {
        // Configure GP29 as output (PSRAM CS), start deasserted
        let sio = &*pac::SIO::ptr();
        sio.gpio_oe_set().write(|w| w.bits(PSRAM_CS_MASK));
        cs_high();

        let saved = xip_disable();

        // Reset PSRAM
        cs_low();
        ssi_transfer(CMD_RESET_ENABLE);
        cs_high();

        cs_low();
        ssi_transfer(CMD_RESET);
        cs_high();

        // tRST = 100 µs minimum after reset
        xip_restore(saved);
        delay.delay_us(150);
        let saved = xip_disable();

        // Read ID — should return MF ID = 0x0D (AP Memory) in bytes 1–2
        cs_low();
        ssi_transfer(CMD_READ_ID);
        ssi_transfer(0x00); // dummy address bytes
        ssi_transfer(0x00);
        ssi_transfer(0x00);
        let mf_id  = ssi_transfer(0x00);
        let kgd    = ssi_transfer(0x00);
        cs_high();

        let id_ok = mf_id == 0x0D; // AP Memory manufacturer ID

        if !id_ok {
            xip_restore(saved);
            return false;
        }

        // Write test pattern to address 0x000000
        let pattern: [u8; 8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x12, 0x34, 0x56, 0x78];
        cs_low();
        ssi_transfer(CMD_WRITE);
        ssi_transfer(0x00); // address[23:16]
        ssi_transfer(0x00); // address[15:8]
        ssi_transfer(0x00); // address[7:0]
        for &b in &pattern {
            ssi_transfer(b);
        }
        cs_high();

        // Small delay for write to complete (PSRAM write is synchronous — no delay needed,
        // but a cycle gap between write and read is good practice)
        for _ in 0..10 { cortex_m::asm::nop(); }

        // Read back — Fast Read: 1 dummy byte after address
        cs_low();
        ssi_transfer(CMD_FAST_READ);
        ssi_transfer(0x00);
        ssi_transfer(0x00);
        ssi_transfer(0x00);
        ssi_transfer(0x00); // dummy byte
        let mut readback = [0u8; 8];
        for b in &mut readback {
            *b = ssi_transfer(0x00);
        }
        cs_high();

        xip_restore(saved);

        // Verify pattern
        pattern == readback
    }
}

/// Write a block of bytes to PSRAM (SPI mode, no XIP needed during transfer).
/// addr: 24-bit PSRAM address (0x000000–0x7FFFFF for 8 MB)
/// data: slice to write
pub fn write_block(delay: &mut Delay, addr: u32, data: &[u8]) {
    let _ = delay; // not needed for SPI writes but kept for API consistency
    unsafe {
        let saved = xip_disable();
        cs_low();
        ssi_transfer(CMD_WRITE);
        ssi_transfer(((addr >> 16) & 0xFF) as u8);
        ssi_transfer(((addr >>  8) & 0xFF) as u8);
        ssi_transfer(( addr        & 0xFF) as u8);
        for &b in data {
            ssi_transfer(b);
        }
        cs_high();
        xip_restore(saved);
    }
}

/// Read a block of bytes from PSRAM.
pub fn read_block(delay: &mut Delay, addr: u32, buf: &mut [u8]) {
    let _ = delay;
    unsafe {
        let saved = xip_disable();
        cs_low();
        ssi_transfer(CMD_FAST_READ);
        ssi_transfer(((addr >> 16) & 0xFF) as u8);
        ssi_transfer(((addr >>  8) & 0xFF) as u8);
        ssi_transfer(( addr        & 0xFF) as u8);
        ssi_transfer(0x00); // dummy byte
        for b in buf.iter_mut() {
            *b = ssi_transfer(0x00);
        }
        cs_high();
        xip_restore(saved);
    }
}
