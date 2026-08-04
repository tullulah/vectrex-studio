/*
 * uvm2_bus.c — halt-mode bus transport for the Ultimate Vectrex Multicart 2.
 *
 * Three jobs:
 *   1. uvm2_bus_init()  — take the machine over from the UVM2 firmware and halt
 *                         the 6809 once, for good.
 *   2. uvm2_exec()      — replay a recorded command stream, one VIA write per
 *                         Vectrex bus cycle.  This is the hot loop.
 *   3. single accesses  — one-off writes and the read cycle used for input.
 *
 * Bus phase (VectrexCart::WriteVia, proven on hardware):
 *      wait CLK HIGH → drive address+data+R/W → wait CLK LOW
 * i.e. the bus is updated just after the rising edge and held across the falling
 * edge, where the VIA latches.  Doing it the other way round — driving during
 * the low phase and releasing on the rising edge — changes the bus exactly at
 * the latch point and writes garbage.
 */

#include "uvm2_bus.h"

uvm2_stats_t uvm2_stats;

/* Linker-provided; C code needs its .bss cleared and nothing else does it. */
extern uint32_t _bss_start, _bss_end;

/* ── Edge waits ───────────────────────────────────────────────────────────────
 * Deliberately not a shared helper with a function call in the middle: the
 * executor has ~333 ns (about 50 CPU cycles at 150 MHz) between the rising edge
 * and the latch to get the new value onto the pins. */
#define UVM2_WAIT_CLK_HIGH()  while ((UVM2_GPIO_IN & UVM2_CLK_MASK) == 0) { }
#define UVM2_WAIT_CLK_LOW()   while ((UVM2_GPIO_IN & UVM2_CLK_MASK) != 0) { }

/* Glitch-free masked update: one store, no intermediate state.  A CLR+SET pair
 * would take the address through $0000 with R/W already low. */
static inline void uvm2_put_masked(uint32_t value, uint32_t mask)
{
    UVM2_GPIO_OUT_XOR = (UVM2_GPIO_OUT ^ value) & mask;
}

/* ── Init ─────────────────────────────────────────────────────────────────── */

#define SCB_VTOR        UVM2_MMIO(0xE000ED08u)
#define SYST_CSR        UVM2_MMIO(0xE000E010u)
#define NVIC_ICER(i)    UVM2_MMIO(0xE000E180u + 4u * (i))
#define NVIC_ICPR(i)    UVM2_MMIO(0xE000E280u + 4u * (i))
#define PADS_BANK0(n)   UVM2_MMIO(0x40038000u + 4u + 4u * (n))
#define IO_BANK0_CTRL(n) UVM2_MMIO(0x40028000u + 8u * (n) + 4u)

/* GPIO0-27, 29, 31 — 28 and 30 belong to the cartridge (30 = WS2812 LED). */
#define UVM2_CART_PINS      0xAFFFFFFFu
/* PB6, /IRQ, /HALT, /NMI, CLK get pull-ups, as the reference does. */
#define UVM2_PULLUP_PINS    0xA8C00000u
/* SCHMITT | DRIVE=8mA | IE.  OD and ISO clear — RP2350 pads power up isolated,
 * so writing the whole register is what actually connects the pad. */
#define UVM2_PAD_BASE       0x62u
#define UVM2_PAD_PUE        0x08u
#define UVM2_FUNC_SIO       5u

/* Step 1 — must run before ANY other C in the image: .bss still holds whatever
 * was in SRAM (the .um2 carries no zero-fill and the firmware copies the file
 * verbatim), so every static below is garbage until this returns. */
void uvm2_cpu_init(void)
{
#ifdef UVM2_PICO_RUNTIME
    /* Under the pico-sdk build the crt0 has already cleared .bss and pointed
     * VTOR at its own table (which carries our SVC handler, since isr_svcall is
     * weak). Doing either again here would be wrong twice over: `_bss_start`
     * and `_bss_end` are symbols from OUR linker script and do not exist, and
     * hardcoding VTOR = 0x20000000 assumes a vector table we no longer emit. */
#else
    for (uint32_t *p = &_bss_start; p < &_bss_end; p++) *p = 0;

    /* Our vector table, or SVC and faults still land in the firmware's. */
    SCB_VTOR = 0x20000000u;
    __asm__ volatile ("dsb \n isb" ::: "memory");
#endif

    /* Silence whatever the firmware left enabled; anything still armed would
     * vector into our stub handlers.  PRIMASK stays CLEAR on purpose — every
     * VPy builtin is an SVC, and masking it escalates SVC to a HardFault. */
    SYST_CSR = 0;
    for (int i = 0; i < 4; i++) { NVIC_ICER(i) = 0xFFFFFFFFu; NVIC_ICPR(i) = 0xFFFFFFFFu; }
}

/* Step 2 — pads and function select.  Separate from the halt because CLK has to
 * be readable before we commit to anything: everything downstream blocks on its
 * edges, so a console that is switched off must be detectable first. */
void uvm2_bus_pads(void)
{
    for (uint32_t n = 0; n < 32; n++) {
        uint32_t bit = 1u << n;
        if ((UVM2_CART_PINS & bit) == 0) continue;
        PADS_BANK0(n)    = UVM2_PAD_BASE | ((UVM2_PULLUP_PINS & bit) ? UVM2_PAD_PUE : 0u);
        IO_BANK0_CTRL(n) = UVM2_FUNC_SIO;
    }
}

/* Step 3 — take the bus and keep it.  /HALT stays asserted for the life of the
 * program: releasing it between accesses lets the 6809 resume BIOS execution
 * and fight us for the bus. */
void uvm2_bus_halt(void)
{
    /* Values go into GPIO_OUT *before* the drivers are enabled, so the pins
     * never glitch through a random state on their way up. */
    UVM2_GPIO_OUT_SET = UVM2_PARK_BITS;
    UVM2_GPIO_OUT_CLR = UVM2_OUT_MASK & ~UVM2_PARK_BITS;   /* includes /HALT low */
    UVM2_GPIO_OE_SET  = UVM2_OUT_MASK;

    /* Let the 6809 finish its instruction and tri-state.  The reference sleeps
     * 20 ms; counting bus cycles instead keeps this independent of whatever
     * core clock the firmware left configured — 30000 cycles is 20 ms exactly. */
    uvm2_bus_delay(UVM2_CYCLES_PER_FRAME);
}

void uvm2_bus_init(void)
{
    uvm2_cpu_init();
    uvm2_bus_pads();
    uvm2_bus_halt();
}

/* ── Command stream executor ──────────────────────────────────────────────────
 * Mirrors VectrexCart::ExecuteHaltCommands: R/W is dropped once for the whole
 * batch and the address' high bits stay at $D000 throughout, so each command is
 * a single 12-bit update landing on GPIO0-11.  One command = one bus cycle. */

uint32_t uvm2_exec(const uint32_t *cmds, uint32_t count)
{
    uint32_t cycles = 0;

    /* Select $D000 on a clean edge, with R/W HIGH — a READ, not a write.
     *
     * This used to leave R/W low, and UVM2_BUS_MASK covers R/W as well as the
     * address and data lines, so the pre-select WAS a write: register 0 (Port B)
     * = 0x00. That clears PB0 (mux ENABLED, channel 0 = the Y sample-and-hold)
     * and PB7 (/RAMP RUNNING), so every frame began by releasing the integrators
     * with the DAC wired to the Y hold. It is the stray bright vector that
     * survived removing the drawing, the input, the audio and the zero-clamp
     * release — because it happened before any of them, even with an empty
     * command stream (s_count = 0, verified over SWD 2026-08-04).
     *
     * Ralf's executor does `... | c_ReadWriteMask` here for exactly this reason,
     * which is why his game never showed it. */
    UVM2_WAIT_CLK_HIGH();
    UVM2_WAIT_CLK_LOW();
    uvm2_put_masked(UVM2_VIA_BASE_BITS | UVM2_RW_MASK, UVM2_BUS_MASK);

    while (count--) {
        uint32_t c     = *cmds++;
        uint32_t out   = (c >> 8) & UVM2_CMD_GPIO_MASK;   /* reg + data, pre-shifted */
        uint32_t delay = c >> 20;

        UVM2_WAIT_CLK_HIGH();
        uvm2_put_masked(out, UVM2_CMD_GPIO_MASK);
        UVM2_GPIO_OUT_CLR = UVM2_RW_MASK;   /* assert WRITE */
        UVM2_WAIT_CLK_LOW();
        cycles++;

        /* R/W STAYS LOW through the delay cycles.
         *
         * It used to go high here, "so the idle cycles do not re-execute the same
         * write". They do not need protecting from that: every register we write
         * (PORTA, PORTB, PCR, ACR, DDRx) takes the same value idempotently, which
         * is why Ralf's executor holds R/W low for the whole command and only
         * raises it once, after the last one.
         *
         * Raising it costs us something real. In halt mode the data bus is an
         * OUTPUT (UVM2_OUT_MASK), and the address still selects $D000 — so R/W
         * high is a READ of the VIA, and the VIA drives the data lines straight
         * back into our drivers. Contention, on every delay cycle, which is most
         * of them: a vector spends 125 + 16 + 3 cycles in delays and 4 driving.
         *
         * Diffing the two command streams on the host (2026-08-04) showed ours is
         * IDENTICAL to his, command for command, data for data, delay for delay —
         * 45 words each for the same square. So the stray vector was never in what
         * we send; it is in how we hold the bus while sending it. */
        while (delay--) {
            UVM2_WAIT_CLK_HIGH();
            UVM2_WAIT_CLK_LOW();
            cycles++;
        }
    }

    /* Park at $0000, R/W high — his `gpio_put_masked(c_HaltModeOutputs,
     * c_ReadWriteMask)`, which drives every halt-mode output low except R/W.
     * We parked at $8000; both are unmapped and neither drives the data bus
     * back at us, but there is no reason to differ from the reference here. */
    UVM2_WAIT_CLK_HIGH();
    UVM2_GPIO_OUT_SET = UVM2_RW_MASK;
    uvm2_put_masked(UVM2_RW_MASK, UVM2_BUS_MASK);
    return cycles;
}

void uvm2_bus_delay(uint32_t cycles)
{
    while (cycles--) {
        UVM2_WAIT_CLK_HIGH();
        UVM2_WAIT_CLK_LOW();
    }
}

/* ── Single accesses ──────────────────────────────────────────────────────── */

void uvm2_via_write(uint32_t reg, uint32_t data)
{
    uint32_t out = UVM2_VIA_BASE_BITS
                 | ((reg & 0x0Fu) << 8)          /* register → A0-A3 */
                 | (data & 0xFFu);               /* data     → D0-D7 */

    UVM2_WAIT_CLK_HIGH();
    uvm2_put_masked(out, UVM2_BUS_MASK);          /* R/W low = write */
    UVM2_WAIT_CLK_LOW();
    uvm2_put_masked(UVM2_PARK_BITS, UVM2_BUS_MASK & ~UVM2_DATA_MASK);
}

uint8_t uvm2_via_read(uint32_t reg)
{
    uint32_t out = UVM2_VIA_BASE_BITS | UVM2_RW_MASK | ((reg & 0x0Fu) << 8);
    uint32_t addr_mask = UVM2_BUS_MASK & ~UVM2_DATA_MASK;
    uint32_t state;

    UVM2_GPIO_OE_CLR = UVM2_DATA_MASK;            /* let the VIA drive D0-D7 */

    UVM2_WAIT_CLK_HIGH();
    uvm2_put_masked(out, addr_mask);
    UVM2_WAIT_CLK_LOW();

    /* Sample on the next rising edge — the address has had a whole cycle by
     * then.  Edge-for-edge the same as VectrexCart::ReadVia. */
    do { state = UVM2_GPIO_IN; } while ((state & UVM2_CLK_MASK) == 0);

    uvm2_put_masked(UVM2_PARK_BITS, addr_mask);
    UVM2_GPIO_OE_SET = UVM2_DATA_MASK;

    /* Leave the clock LOW before returning.  Sampling happens on a rising edge,
     * so without this the caller's next access finds its "wait for CLK high"
     * already satisfied and drives the bus in the dying part of that same high
     * phase — too late for the falling edge that latches it, and the write is
     * simply lost.  Costs half a bus cycle and makes every access start from
     * the same known phase. */
    UVM2_WAIT_CLK_LOW();
    return (uint8_t)(state & 0xFFu);
}
