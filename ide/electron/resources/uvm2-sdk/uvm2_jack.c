/* uvm2_jack.c — the UVMC2's audio jack: a PT8211 16-bit stereo DAC.
 *
 * Moved here from uvmc2-games/quarter, where it was written and first made a
 * sound. It is a driver for a chip on the cartridge, which is what uvm2_sd.c
 * and uvm2_psram.c next to it are, and a second copy of it in the next game
 * that wants audio is a second copy that can disagree with this one.
 *
 * WIRING (from the UVMC2 schematic)
 *   PT.DIN  GPIO43   serial data, MSB first
 *   PT.WS   GPIO44   word select: which channel the 16 bits are for
 *   PT.BCK  GPIO45   bit clock
 *
 * THE FORMAT. The PT8211 takes 16 bits per channel, LSB-justified: with exactly
 * 16 clocks per channel that means the MSB goes out as WS changes, and the LSB
 * is the last bit before the next change. Data changes on BCK's falling edge
 * and is sampled on its rising edge. The engine is mono, so both channels carry
 * the same sample and which WS level means "left" does not matter.
 *
 * THE MACHINERY — none of it touches the Vectrex bus:
 *   PIO2   the bus lives on PIO0 (vectrex-bus writes PIO0's registers
 *          directly), so audio takes the third block. Its GPIO window is moved
 *          up to 16-47 to reach pins 43-45.
 *   DMA    one channel, never channel 0 (the bus stream's), looping forever
 *          over a 2048-word ring buffer: each word is one stereo frame, left
 *          in the high half, right in the low half.
 *   CPU    once per game frame, `uvm2_jack_space` says how far ahead of the DMA
 *          the buffer is filled and the game synthesizes enough to stay ~50 ms
 *          ahead. A slow frame just eats into that margin; it never clicks
 *          unless a single frame takes longer than ~60 ms.
 *
 * If any resource is unavailable, uvm2_jack_init() returns 0 and the game falls
 * back to the Vectrex's own sound chip. */
#include "uvm2_jack.h"

#define RING_WORDS   2048u                  /* 8 KB, 64 ms at 32 kHz        */
#define RING_BITS    13u                    /* log2(bytes), for the DMA wrap */
#define AHEAD        1600u                  /* keep ~50 ms queued            */

#ifdef VPY_RP2350
#include "hardware/pio.h"
#include "hardware/pio_instructions.h"
#include "hardware/dma.h"
#include "hardware/clocks.h"
#include "hardware/gpio.h"

/* THE SYSTEM CLOCK, MEASURED — WHERE THERE IS A MEASUREMENT.
 *
 * uvm2_bus.c times the console's own 1.5 MHz E against the CPU at boot and
 * leaves it here. It is the number to use: the game is launched by the cart's
 * loader, so what the pico-sdk recorded about clk_sys is not something to lean
 * on, and a clock that is out by a percent is music that is out by a percent.
 *
 * IT IS WEAKLY DEFINED HERE BECAUSE THERE ARE TWO uvm2-sdk TREES on this
 * machine and they have diverged: the UVMC2 starter kit's has the measurement,
 * the one the VPy games build against does not. A weak DEFINITION links either
 * way — where uvm2_bus.c defines it, its strong one wins; where it does not,
 * this zero stands and the fallback below takes clk_sys.
 *
 * A WEAK *DECLARATION* WAS WRONG AND IT COST AN EVENING. An extern marked
 * weak, with nobody defining it, does not read as zero: it resolves to
 * ADDRESS ZERO, and address zero on this chip is the boot ROM. So the driver
 * read the first word of the bootrom, believed the system clock was four
 * gigahertz, and set a divider to match. The jack ran — right pins, right DMA,
 * a state machine happily clocking — at a rate with no relation to anything,
 * which out of a DAC is exactly what it sounds like: noise. */
__attribute__((weak)) uint32_t uvm2_cycles_per_e_q8;

#define PIN_DIN 43u
#define PIN_WS  44u
#define PIN_BCK 45u

static uint32_t s_ring[RING_WORDS] __attribute__((aligned(RING_WORDS * 4)));
static int      s_ok, s_dma = -1, s_sm = -1;
static uint32_t s_clk, s_div_q8;   /* what it believed and what it set: uvm2_jack.h */
static uint32_t s_w;                        /* next word the CPU will write   */

/* side-set: bit 0 = WS (GPIO44), bit 1 = BCK (GPIO45). Two instructions per bit:
 * BCK low while the data bit changes, BCK high to latch it. 16 bits with WS=0,
 * then 16 with WS=1; X counts 15 bits in each loop, the 16th is unrolled. */
static uint16_t s_prog[8];
static const pio_program_t s_program = { .instructions = s_prog, .length = 8, .origin = -1 };

int uvm2_jack_init(void)
{
    PIO pio = pio2;
    if (pio_set_gpio_base(pio, 16) != 0) return 0;
    const uint ss = 2;
    s_prog[0] = (uint16_t)(pio_encode_out(pio_pins, 1)  | pio_encode_sideset(ss, 0));
    s_prog[1] = (uint16_t)(pio_encode_jmp_x_dec(0)      | pio_encode_sideset(ss, 2));
    s_prog[2] = (uint16_t)(pio_encode_out(pio_pins, 1)  | pio_encode_sideset(ss, 0));
    s_prog[3] = (uint16_t)(pio_encode_set(pio_x, 14)    | pio_encode_sideset(ss, 2));
    s_prog[4] = (uint16_t)(pio_encode_out(pio_pins, 1)  | pio_encode_sideset(ss, 1));
    s_prog[5] = (uint16_t)(pio_encode_jmp_x_dec(4)      | pio_encode_sideset(ss, 3));
    s_prog[6] = (uint16_t)(pio_encode_out(pio_pins, 1)  | pio_encode_sideset(ss, 1));
    s_prog[7] = (uint16_t)(pio_encode_set(pio_x, 14)    | pio_encode_sideset(ss, 3));
    if (!pio_can_add_program(pio, &s_program)) return 0;
    s_sm = pio_claim_unused_sm(pio, false);
    if (s_sm < 0) return 0;
    uint off = pio_add_program(pio, &s_program);          /* relocates the two jmps */

    pio_gpio_init(pio, PIN_DIN);
    pio_gpio_init(pio, PIN_WS);
    pio_gpio_init(pio, PIN_BCK);
    pio_sm_set_consecutive_pindirs(pio, (uint)s_sm, PIN_DIN, 3, true);

    pio_sm_config c = pio_get_default_sm_config();
    sm_config_set_wrap(&c, off, off + 7);
    sm_config_set_out_pins(&c, PIN_DIN, 1);
    sm_config_set_sideset(&c, ss, false, false);
    sm_config_set_sideset_pins(&c, PIN_WS);
    sm_config_set_out_shift(&c, false, true, 32);        /* MSB first, autopull 32  */
    sm_config_set_fifo_join(&c, PIO_FIFO_JOIN_TX);
    /* 2 instructions per bit, 32 bits per stereo frame. The system clock comes
     * from the SDK's own measurement against the Vectrex's 1.5 MHz E clock
     * (uvm2_measure_e, at boot): the game is started by the cart's loader, so
     * the pico-sdk's recorded frequency is not something to lean on. */
    float sys = uvm2_cycles_per_e_q8 ? (float)uvm2_cycles_per_e_q8 * (1500000.0f / 256.0f)
                                     : (float)clock_get_hz(clk_sys);
    /* AND IT IS BOUNDED AT BOTH ENDS. An RP2350 runs somewhere between the
     * crystal and a few hundred megahertz; anything outside that is not a slow
     * clock or a fast one, it is a number that did not come from a clock at
     * all, and the only honest thing to do with it is drop it. There was a
     * floor here and no ceiling, and it was through the ceiling that four
     * gigahertz walked in. */
    if (sys < 20e6f || sys > 400e6f) sys = 150e6f;
    float div = sys / ((float)UVM2_JACK_RATE * 64.0f);
    s_clk = (uint32_t)sys;
    s_div_q8 = (uint32_t)(div * 256.0f);
    sm_config_set_clkdiv(&c, div);
    pio_sm_init(pio, (uint)s_sm, off, &c);
    pio_sm_exec(pio, (uint)s_sm, pio_encode_set(pio_x, 14));

    /* DMA: pick a free channel from the top down; never 0 (the bus stream's),
     * which vectrex-bus drives without claiming it. */
    for (int ch = 15; ch >= 4; ch--)
        if (!dma_channel_is_claimed((uint)ch)) { dma_channel_claim((uint)ch); s_dma = ch; break; }
    if (s_dma < 0) return 0;

    for (uint32_t i = 0; i < RING_WORDS; i++) s_ring[i] = 0;
    dma_channel_config d = dma_channel_get_default_config((uint)s_dma);
    channel_config_set_transfer_data_size(&d, DMA_SIZE_32);
    channel_config_set_read_increment(&d, true);
    channel_config_set_write_increment(&d, false);
    channel_config_set_ring(&d, false, RING_BITS);       /* read address wraps */
    channel_config_set_dreq(&d, pio_get_dreq(pio, (uint)s_sm, true));
    dma_channel_configure((uint)s_dma, &d, &pio->txf[s_sm], s_ring,
                          dma_encode_endless_transfer_count(), true);
    pio_sm_set_enabled(pio, (uint)s_sm, true);
    s_w = AHEAD / 2;
    s_ok = 1;
    return 1;
}

static uint32_t read_pos(void)
{
    return ((uint32_t)dma_hw->ch[s_dma].read_addr - (uint32_t)(uintptr_t)s_ring) / 4u & (RING_WORDS - 1u);
}

int uvm2_jack_space(void)
{
    if (!s_ok) return 0;
    uint32_t rd = read_pos();
    uint32_t ahead = (s_w - rd) & (RING_WORDS - 1u);
    if (ahead > RING_WORDS - 256u) {                      /* fell behind: re-sync */
        s_w = (rd + 64u) & (RING_WORDS - 1u);
        ahead = 64u;
    }
    return ahead >= AHEAD ? 0 : (int)(AHEAD - ahead);
}

void uvm2_jack_write(const int16_t *s, int n)
{
    if (!s_ok) return;
    for (int i = 0; i < n; i++) {
        uint32_t v = (uint16_t)s[i];
        s_ring[s_w] = (v << 16) | v;                      /* same on L and R */
        s_w = (s_w + 1u) & (RING_WORDS - 1u);
    }
}

int uvm2_jack_ok(void) { return s_ok; }

int      uvm2_jack_sm(void)      { return s_sm; }
int      uvm2_jack_dma(void)     { return s_dma; }
uint32_t uvm2_jack_clk(void)     { return s_clk; }
uint32_t uvm2_jack_div_q8(void)  { return s_div_q8; }
uint32_t uvm2_jack_pinctrl(void) { return s_sm < 0 ? 0 : pio2->sm[s_sm].pinctrl; }
uint32_t uvm2_jack_base(void)    { return pio_get_gpio_base(pio2); }

/* Start or stop the whole machine: with it stopped, no PIO2 state machine runs
 * and no DMA channel moves beside the bus stream (a clean A/B test against the
 * Vectrex's own sound chip). Starting it the first time does the set-up. */
static int s_inited;
int uvm2_jack_set(int on)
{
    if (on) {
        if (!s_inited) { s_inited = 1; return uvm2_jack_init(); }
        if (!s_ok && s_dma >= 0 && s_sm >= 0) {
            dma_channel_set_read_addr((uint)s_dma, s_ring, false);
            dma_channel_set_trans_count((uint)s_dma, dma_encode_endless_transfer_count(), true);
            pio_sm_set_enabled(pio2, (uint)s_sm, true);
            s_w = AHEAD / 2;
            s_ok = 1;
        }
        return s_ok;
    }
    if (s_ok) {
        pio_sm_set_enabled(pio2, (uint)s_sm, false);
        dma_channel_abort((uint)s_dma);
        s_ok = 0;
    }
    return 0;
}

#else
/* ── desktop preview ───────────────────────────────────────────────────────
 * The "DAC" runs at exactly 50 frames a second of preview time, and with
 * JACK_LOG=file set every sample is written there (raw 16-bit mono, 32 kHz)
 * so tools/jack2wav.py can turn a run into the WAV the jack would play. */
#include <stdio.h>
#include <stdlib.h>
static FILE *s_log;
static int s_ok, s_owed;
int uvm2_jack_init(void)
{
    const char *n = getenv("JACK_LOG");
    if (n) s_log = fopen(n, "wb");
    s_ok = 1;
    return 1;
}
int uvm2_jack_space(void) { s_owed = UVM2_JACK_RATE / 50; return s_owed; }
void uvm2_jack_write(const int16_t *s, int n) { if (s_log) fwrite(s, 2, (size_t)n, s_log); }
int uvm2_jack_ok(void) { return s_ok; }

int      uvm2_jack_sm(void)      { return s_sm; }
int      uvm2_jack_dma(void)     { return s_dma; }
uint32_t uvm2_jack_clk(void)     { return s_clk; }
uint32_t uvm2_jack_div_q8(void)  { return s_div_q8; }
uint32_t uvm2_jack_pinctrl(void) { return s_sm < 0 ? 0 : pio2->sm[s_sm].pinctrl; }
uint32_t uvm2_jack_base(void)    { return pio_get_gpio_base(pio2); }
int uvm2_jack_set(int on) { if (on && !s_ok) uvm2_jack_init(); s_ok = on; return s_ok; }
#endif
