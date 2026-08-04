/*
 * uvm2_bus.h — Ultimate Vectrex Multicart 2: halt-mode Vectrex bus contract.
 *
 * The UVM2 has no HAL and no BIOS: the RP2350's GPIOs are wired straight to the
 * Vectrex cartridge bus, and a game either answers the 6809's ROM fetches or it
 * halts the 6809 and drives the VIA itself.  We always do the latter — the
 * generated code is native RP2350, so the 6809 has nothing to execute.
 *
 * Drawing therefore means "write the VIA registers the 6809 would have written",
 * phase-locked to the 1.5 MHz CLK that the 6809 keeps generating even while it
 * is halted.  Rather than writing them one at a time (which stalls the CPU on
 * every edge and leaves the beam idle during game logic), commands are RECORDED
 * into a buffer and replayed back-to-back by uvm2_exec().  This is the model
 * Ralf's own games use, and the command encoding below is deliberately
 * bit-identical to his so both executors are comparable.
 *
 * Command word layout:
 *      bits 31..20   delay: bus cycles to idle AFTER this write (0..4095)
 *      bits 19..16   VIA register select  → A0-A3 (GPIO8-11)
 *      bits 15..8    data byte            → D0-D7 (GPIO0-7)
 *      bits  7..0    unused
 * so (word >> 8) & 0xFFF lands directly on GPIO0-11 with no shifting in the
 * inner loop — one bus cycle per command, 667 ns.
 *
 * GPIO map (Ralf, 2026-04-16; GPIO8 = A0 confirmed against his reference game):
 *   0-7 D0-D7 | 8-21 A0-A13 | 22 PB6 | 23 /IRQ | 24 A14 | 25 A15
 *   26 R/W    | 27 /HALT     | 29 /NMI | 31 CLK        (28/30 are not ours)
 */
#ifndef UVM2_BUS_H
#define UVM2_BUS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ── RP2350 SIO ──────────────────────────────────────────────────────────────
 * NOT the RP2040 offsets: RP2350 interleaves GPIO_HI_* (for GPIO32-47), so
 * every OUT/OE register moves.  (RP2350 datasheet §3.1.11.) */
#define UVM2_SIO_BASE       0xD0000000u
#define UVM2_MMIO(addr)     (*(volatile uint32_t *)(uintptr_t)(addr))
#define UVM2_REG(off)       UVM2_MMIO(UVM2_SIO_BASE + (off))
#define UVM2_GPIO_IN        UVM2_REG(0x004)
#define UVM2_GPIO_OUT       UVM2_REG(0x010)
#define UVM2_GPIO_OUT_SET   UVM2_REG(0x018)
#define UVM2_GPIO_OUT_CLR   UVM2_REG(0x020)
#define UVM2_GPIO_OUT_XOR   UVM2_REG(0x028)
#define UVM2_GPIO_OE_SET    UVM2_REG(0x038)
#define UVM2_GPIO_OE_CLR    UVM2_REG(0x040)

/* ── Pin masks ─────────────────────────────────────────────────────────────── */
#define UVM2_DATA_MASK      0x000000FFu   /* D0-D7   GPIO0-7   */
#define UVM2_ADDR_LO_MASK   0x003FFF00u   /* A0-A13  GPIO8-21  */
#define UVM2_A14_MASK       0x01000000u
#define UVM2_A15_MASK       0x02000000u
#define UVM2_RW_MASK        0x04000000u   /* 1 = read, 0 = write */
#define UVM2_HALT_MASK      0x08000000u   /* drive LOW to own the bus */
#define UVM2_CLK_MASK       0x80000000u
#define UVM2_PB6_MASK       0x00400000u

/* Everything we drive (data + full address + R/W + /HALT). */
#define UVM2_OUT_MASK       (UVM2_DATA_MASK | UVM2_ADDR_LO_MASK | \
                             UVM2_A14_MASK | UVM2_A15_MASK |      \
                             UVM2_RW_MASK  | UVM2_HALT_MASK)
/* Bus lines only — never touches /HALT, which stays asserted for good. */
#define UVM2_BUS_MASK       (UVM2_OUT_MASK & ~UVM2_HALT_MASK)

/* $D000 = A15|A14|A12; A12 is GPIO20 because GPIO8 = A0. */
#define UVM2_VIA_BASE_BITS  (UVM2_A15_MASK | UVM2_A14_MASK | (1u << 20))
/* Idle/park address: $8000 is unmapped on the Vectrex, so a parked write cycle
 * reaches no device.  Parking at $D00x instead would re-run the last VIA write
 * (or, with R/W high, keep clearing IFR flags) for as long as the bus idles. */
#define UVM2_PARK_BITS      UVM2_A15_MASK

/* The 12 bits of a command that map onto GPIO0-11. */
#define UVM2_CMD_GPIO_MASK  0x00000FFFu

/* ── VIA 6522 registers (index only — the base is implicit) ────────────────── */
enum {
    UVM2_VIA_PORTB = 0x0, UVM2_VIA_PORTA = 0x1,
    UVM2_VIA_DDRB  = 0x2, UVM2_VIA_DDRA  = 0x3,
    UVM2_VIA_T1CL  = 0x4, UVM2_VIA_T1CH  = 0x5,
    UVM2_VIA_T1LL  = 0x6, UVM2_VIA_T1LH  = 0x7,
    UVM2_VIA_T2CL  = 0x8, UVM2_VIA_T2CH  = 0x9,
    UVM2_VIA_SR    = 0xA, UVM2_VIA_ACR   = 0xB,
    UVM2_VIA_PCR   = 0xC, UVM2_VIA_IFR   = 0xD,
    UVM2_VIA_IER   = 0xE,
};

/* ── Port B bits (Vectrex wiring) ──────────────────────────────────────────── */
#define UVM2_PB_MUX_DISABLE 0x01u   /* 1 = sample/hold off (mux disabled)     */
#define UVM2_PB_MUX_SEL0    0x02u
#define UVM2_PB_MUX_SEL1    0x04u
#define UVM2_PB_RAMP_OFF    0x80u   /* /RAMP: 1 = integrators frozen          */
#define UVM2_PB_IDLE        (UVM2_PB_RAMP_OFF | UVM2_PB_MUX_DISABLE)
/* Mux channel select (with MUX_DISABLE clear the DAC value is sampled into it) */
#define UVM2_MUX_Y          0x00u
#define UVM2_MUX_ZEROREF    UVM2_PB_MUX_SEL0
#define UVM2_MUX_Z          UVM2_PB_MUX_SEL1

/* ── PCR (VIA_cntl) bits ───────────────────────────────────────────────────── */
#define UVM2_PCR_IDLE       0xCCu   /* CA2 (/ZERO) high, CB2 (/BLANK) low     */
#define UVM2_PCR_ZERO_OFF   0x02u   /* set  → /ZERO released                   */
#define UVM2_PCR_BLANK_OFF  0x20u   /* set  → beam lit                         */

/* ── Command encoding (Ralf-compatible) ────────────────────────────────────── */
#define UVM2_CMD(reg, data, delay)                     \
    (((uint32_t)(delay) << 20) | ((uint32_t)(reg) << 16) | \
     (((uint32_t)(data) & 0xFFu) << 8))
#define UVM2_CMD_MAX_DELAY  4095u

/* ── Lifecycle ─────────────────────────────────────────────────────────────── */

/* Bring-up, in three steps because their order is load-bearing:
 *   uvm2_cpu_init()  .bss, vector table, firmware interrupts off.  MUST be the
 *                    first C executed — every static is garbage until it runs.
 *   uvm2_bus_pads()  pads/function select.  CLK becomes readable here, which is
 *                    what lets a switched-off console be detected rather than
 *                    hanging on the first edge wait.
 *   uvm2_bus_halt()  park the bus, enable the drivers, assert /HALT for good.
 * uvm2_bus_init() runs all three for callers that need no diagnostics between. */
void uvm2_cpu_init(void);
void uvm2_bus_pads(void);
void uvm2_bus_halt(void);
void uvm2_bus_init(void);

/* ── Command stream ────────────────────────────────────────────────────────── */

/* Replay `count` commands back-to-back, one bus cycle each plus their delays.
 * R/W is held low for the whole batch (as in the reference executor) and the
 * bus is parked at $8000 on exit.  Returns the bus cycles consumed. */
uint32_t uvm2_exec(const uint32_t *cmds, uint32_t count);

/* Idle for `cycles` Vectrex bus cycles (667 ns each) — clock-independent, which
 * is what beam/integrator timing needs. */
void uvm2_bus_delay(uint32_t cycles);

/* ── Single accesses (outside the command stream) ───────────────────────────
 * Reads cannot be recorded — they need the data bus turned around mid-cycle —
 * so input polling runs directly, exactly as the reference does after replaying
 * its frame.  uvm2_via_write is the one-off equivalent of a single command. */
void    uvm2_via_write(uint32_t reg, uint32_t data);
uint8_t uvm2_via_read(uint32_t reg);

/* ── Instrumentation ───────────────────────────────────────────────────────
 * A 50 Hz frame is 30000 bus cycles.  These let a game (or the IDE) report how
 * much of that budget the last frame actually spent, which is the only fair way
 * to compare this command-stream model against the syscall-per-write one. */
typedef struct {
    uint32_t commands;      /* commands replayed last frame                   */
    uint32_t bus_cycles;    /* bus cycles they consumed (writes + delays)     */
    uint32_t vectors;       /* lit segments drawn last frame                  */
    uint32_t overrun;       /* frames whose stream exceeded the 50 Hz budget  */
    uint32_t moves;         /* blanked repositions last frame (beam travel)   */
    uint32_t ramp_cycles;   /* cycles spent with the integrators running      */

    /* Snapshots of the three above, taken in uvm2_frame_end and never cleared.
     *
     * The live counters are reset in uvm2_frame_begin and fill up as the frame is
     * built, so a debugger sampling at an arbitrary moment mostly catches them at
     * zero — a game that spends 40 ms emulating a CPU and 2 ms drawing is in the
     * "reset, not yet drawn" window almost always. Read these instead; they hold
     * the last COMPLETE frame for as long as it takes to look. */
    uint32_t vectors_last;
    uint32_t moves_last;
    uint32_t ramp_cycles_last;
} uvm2_stats_t;

extern uvm2_stats_t uvm2_stats;

#define UVM2_CYCLES_PER_FRAME  30000u   /* 1.5 MHz / 50 Hz */

#ifdef __cplusplus
}
#endif

#endif /* UVM2_BUS_H */
