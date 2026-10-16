/* vpy_fault.c -- a HardFault that leaves a witness on the SD card (uvm2, C backend).
 *
 * The SDK's isr_hardfault paints the LED red and spins: the console says "it crashed" and
 * nothing else. This one is installed over it at boot (the vector table is in SRAM) and
 * writes, before going red:
 *
 *     VPYFAULT.TXT   the faulting core's registers and the fault status registers, as
 *                    NAME=0x........ lines (tools/uvm2_fault.py symbolises them against the ELF)
 *     VPYRAM.BIN     all of SRAM, 0x20000000..0x20082000, byte for byte
 *
 * The LED says how far it got: blue while writing, then red blinking if both files were
 * written, solid red if the card write failed.
 *
 * ITS OWN STACK. A fault is often a stack gone wrong, so the handler leaves it at once: it
 * runs on the jack's 8 KB ring at the top of SRAM (UVM2_JACK_RING_TOP pins it at 0x2007E000;
 * the audio is not worth keeping), which also leaves both cores' real stacks untouched in
 * the dump. MSPLIM is cleared first: the ring lies below core 0's stack limit.
 *
 * WHICH CORE. The game runs on core 0, where the card is used. If core 1 faults, the
 * handler waits a little before touching the card: core 0 then sits waiting for a frame
 * core 1 will never finish, and is not in the middle of a card transfer. The first core to
 * fault owns the handler; a second one just stops.
 *
 * The card driver polls SPI with bounded waits (no interrupts, no DMA), so it works from
 * here. The open music stream is dropped and the card remounted: the fault may have hit in
 * the middle of a transfer. */
#include <stdint.h>
#include "uvm2_sd.h"

#ifndef UVM2_JACK_RING_TOP
#error "vpy_fault.c runs on the jack ring at the top of SRAM: build with UVM2_JACK_RING_TOP"
#endif

#ifndef VPYF_GAME
#define VPYF_GAME "vpy"
#endif

#define RING        0x2007E000u        /* uvm2_pico.cmake: --section-start=.jackring */
#define SAVED(core) ((volatile uint32_t *)(RING + 0x20 + (core) * 0x20))   /* r4-r11 */
#define TEXT        ((char *)(RING + 0x100))
#define TEXT_MAX    0xB00u             /* up to RING + 0xC00; the stack is above, to 0x20080000 */
#define SRAM_BASE   0x20000000u
#define SRAM_END    0x20082000u

#define REG(a)      (*(volatile uint32_t *)(a))
#define SCB_VTOR    0xE000ED08u
#define SIO_CPUID   0xD0000000u
#define DMA_ABORT   0x50000464u        /* RP2350 DMA CHAN_ABORT */

extern uint32_t uvm2_frame_count(void);
extern void uvm2_led_rgb(uint8_t r, uint8_t g, uint8_t b);
void vpyf_hardfault(void);
volatile uint32_t vpyf_owner;          /* the core in the handler, plus one (not in the ring: music fills it) */

static char *put(char *p, const char *name, uint32_t v)
{
    while (*name) *p++ = *name++;
    *p++ = '=';
    *p++ = '0';
    *p++ = 'x';
    for (int s = 28; s >= 0; s -= 4) *p++ = "0123456789abcdef"[(v >> s) & 15u];
    *p++ = '\n';
    return p;
}

static void spin(uint32_t n)
{
    for (volatile uint32_t i = 0; i < n; i++) {
    }
}

/* frame: what the core stacked (r0-r3, r12, lr, pc, xpsr); exc: EXC_RETURN */
__attribute__((used, noreturn)) void vpyf_fault_c(uint32_t *frame, uint32_t exc)
{
    static const char *const RN[8] = { "r0", "r1", "r2", "r3", "r12", "lr", "pc", "xpsr" };
    static const char *const SN[8] = { "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11" };
    const uint32_t core = REG(SIO_CPUID) & 1u;
    const uint32_t f = (uint32_t)frame;
    const int ok = f >= SRAM_BASE && f + 32u <= SRAM_END && (f & 3u) == 0;
    uvm2_led_rgb(0, 0, 40);
    REG(DMA_ABORT) = 0xFFFFu;                /* the jack's DMA reads the ring we stand on */

    char *p = TEXT;
    for (const char *s = "VPY HARDFAULT " VPYF_GAME "\nbuild=" __DATE__ " " __TIME__ "\n"; *s; ) *p++ = *s++;
    p = put(p, "core", core);
    p = put(p, "frame", uvm2_frame_count());
    for (int i = 0; i < 8; i++) p = put(p, RN[i], ok ? frame[i] : 0xDEADDEADu);
    for (int i = 0; i < 8; i++) p = put(p, SN[i], SAVED(core)[i]);
    /* the sp before the fault: the frame (8 words, 26 with the FPU's), plus the realignment */
    uint32_t sp = f + ((exc & 0x10u) ? 32u : 104u);
    if (ok && (frame[7] & 0x200u)) sp += 4u;
    p = put(p, "sp", sp);
    p = put(p, "exc_return", exc);
    p = put(p, "cfsr", REG(0xE000ED28u));
    p = put(p, "hfsr", REG(0xE000ED2Cu));
    p = put(p, "mmfar", REG(0xE000ED34u));
    p = put(p, "bfar", REG(0xE000ED38u));
    p = put(p, "sfsr", REG(0xE000EDE4u));
    p = put(p, "sfar", REG(0xE000EDE8u));
    p = put(p, "handler", (uint32_t)vpyf_hardfault);
    const char *tail = "ram=VPYRAM.BIN 0x20000000\n";
    char *before = p;
    while (*tail) *p++ = *tail++;

    uvm2_sd_diag.streams = 0;                /* remount: the card may be mid-transfer */
    int wrote = uvm2_sd_write("VPYFAULT.TXT", (const unsigned char *)TEXT, (uint32_t)(before - TEXT));
    wrote = wrote && uvm2_sd_write("VPYRAM.BIN", (const unsigned char *)SRAM_BASE, SRAM_END - SRAM_BASE);
    if (wrote)
        wrote = uvm2_sd_write("VPYFAULT.TXT", (const unsigned char *)TEXT, (uint32_t)(p - TEXT));
    for (;;) {
        uvm2_led_rgb(255, 0, 0);
        if (wrote) {
            spin(20000000u);
            uvm2_led_rgb(0, 0, 0);
            spin(20000000u);
        }
    }
}

/* Leave the faulting stack at once. Only r0-r3 are free (the core stacked them): the owner
 * check, core 1's wait (in registers: core 0 may still be filling the ring), r4-r11 saved,
 * then the ring as the stack. */
__attribute__((naked)) void vpyf_hardfault(void)
{
    __asm volatile(
        "ldr   r2, =vpyf_owner      \n"
        "ldr   r3, [r2]             \n"
        "cmp   r3, #0               \n"
        "bne   9f                   \n"     /* the other core already owns it */
        "ldr   r3, =0xD0000000      \n"
        "ldr   r3, [r3]             \n"     /* CPUID: 0 or 1 */
        "adds  r1, r3, #1           \n"
        "str   r1, [r2]             \n"
        "cmp   r3, #0               \n"
        "beq   2f                   \n"
        "ldr   r2, =60000000        \n"     /* core 1: ~0.5 s for core 0 to park in its frame wait */
        "1: subs r2, r2, #1         \n"
        "bne   1b                   \n"
        "2: lsls r3, r3, #5         \n"
        "ldr   r2, =0x2007E020      \n"
        "add   r2, r2, r3           \n"
        "stmia r2!, {r4-r11}        \n"
        "tst   lr, #4               \n"
        "ite   eq                   \n"
        "mrseq r0, msp              \n"
        "mrsne r0, psp              \n"
        "mov   r1, lr               \n"
        "movs  r3, #0               \n"
        "msr   msplim, r3           \n"
        "ldr   r3, =0x20080000      \n"
        "mov   sp, r3               \n"
        "b     vpyf_fault_c         \n"
        "9: b  9b                   \n"
        ".ltorg                     \n");
}

/* Point the HardFault vector (shared by both cores) at the handler above. */
void vpyf_install(void)
{
    uint32_t *vt = (uint32_t *)REG(SCB_VTOR);
    if ((uint32_t)vt < SRAM_BASE || (uint32_t)vt >= SRAM_END) return;   /* not a table we can write */
    vt[3] = (uint32_t)vpyf_hardfault;
    __asm volatile ("dsb\n isb" ::: "memory");
}
