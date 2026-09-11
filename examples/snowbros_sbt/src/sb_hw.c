/* sb_hw.c — Snow Bros machine: 68000 (Musashi) + memory map + Pandora sprite RAM.
 *
 * Map (from the board):
 *   000000-03ffff  program ROM (sn6 even / sn5 odd bytes, big-endian)
 *   100000-103fff  work RAM
 *   200000         watchdog (writes ignored)
 *   300001         sound latch — Z80 not emulated yet; reads echo the last
 *                  command so the boot handshake passes
 *   400000         flipscreen (ignored)
 *   500000/2/4     DSW1 / DSW2 / SYSTEM, active-low; DSW1/DSW2 bit15 is
 *                  ACTIVE_HIGH and must read LOW or the game stops
 *   600000-6001ff  palette RAM (xBGR555, stored for the renderer)
 *   700000-701fff  Pandora sprite RAM, one byte in the low lane of each word
 *   800000/900000/a00000  IRQ 4/3/2 acknowledge
 *
 * IRQs: scanline timer fires IRQ2 at line 240, IRQ3 at 128, IRQ4 at 32.
 * We autovector and auto-clear at service (the ack writes become no-ops).
 */
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include "musashi/m68k.h"
#include "sb_rom.h"

unsigned char sb_ram[0x4000];
unsigned char sb_spriteram[0x1000];
unsigned char sb_palette[0x200];

/* inputs, ACTIVE-LOW bit fields (1 = released). gmain.c clears bits. */
unsigned char sb_p1 = 0x7f;      /* up,down,left,right,b1,b2,b3 ; bit7 must stay 0 */
unsigned char sb_p2 = 0x7f;
unsigned char sb_system = 0xff;  /* start1,start2,coin1,coin2,-,tilt,coin3,- */

static unsigned char sb_dsw1 = 0xfe;  /* Europe, no flip, no service, demo snd, 1C_1C */
static unsigned char sb_dsw2 = 0xff;  /* normal, 100k, 3 lives, continues; bit6 = invuln dip */
static unsigned char soundcmd = 3;  /* Z80 ready/region code the boot demands */

int your_int_ack_handler_function(int level)
{
#ifdef SB_TRACE_IRQ
    { extern int printf(const char *, ...); printf("    irq%d taken\n", level); }
#endif
    m68k_set_virq(level, 0);
    return M68K_INT_ACK_AUTOVECTOR;
}

static unsigned int rd8(unsigned int a)
{
    a &= 0xffffff;
    if (a < 0x40000) return sb_prog[a];
    if (a >= 0x100000 && a <= 0x103fff) return sb_ram[a & 0x3fff];
    if (a == 0x300001) return 3;                           /* Z80 always "ready" */
    if (a >= 0x500000 && a <= 0x500005) {
        switch (a) {
        case 0x500000: return sb_p1 & 0x7f;   /* bit15 low! */
        case 0x500001: return sb_dsw1;
        case 0x500002: return sb_p2 & 0x7f;
        case 0x500003: return sb_dsw2;
        case 0x500004: return sb_system;
        case 0x500005: return 0xff;
        }
    }
    if (a >= 0x600000 && a <= 0x6001ff) return sb_palette[a & 0x1ff];
    if (a >= 0x700000 && a <= 0x701fff) return sb_spriteram[(a & 0x1fff) >> 1];
    return 0xff;
}

static void wr8(unsigned int a, unsigned int d)
{
    a &= 0xffffff;
    if (a >= 0x100000 && a <= 0x103fff) { sb_ram[a & 0x3fff] = d; return; }
    if (a == 0x300001) { soundcmd = d; return; }
    if (a >= 0x600000 && a <= 0x6001ff) { sb_palette[a & 0x1ff] = d; return; }
    if (a >= 0x700000 && a <= 0x701fff) {
        if (a & 1) sb_spriteram[(a & 0x1fff) >> 1] = d;    /* low lane only */
        return;
    }
    if (a >= 0x800000 && a <= 0x800001) {
#ifdef SB_TRACE_IRQ
        { extern int printf(const char *, ...); static int n; if (n < 12) { n++; printf("    irq4 ack (handler ran)\n"); } }
#endif
        m68k_set_virq(4, 0); return; }
    if (a >= 0x900000 && a <= 0x900001) {
#ifdef SB_TRACE_IRQ
        { extern int printf(const char *, ...); static int n; if (n < 6) { n++; printf("    irq3 ack\n"); } }
#endif
        m68k_set_virq(3, 0); return; }
    if (a >= 0xa00000 && a <= 0xa00001) {
#ifdef SB_TRACE_IRQ
        { extern int printf(const char *, ...); static int n; if (n < 6) { n++; printf("    irq2 ack\n"); } }
#endif
        m68k_set_virq(2, 0); return; }
    if (a == 0x200000 || a == 0x200001 || a == 0x400000 || a == 0x400001) return;
#ifdef SB_TRACE_MAP
    { extern int printf(const char *, ...); static int n; if (n < 20) { n++;
        printf("    UNMAPPED write %06x = %02x (pc %06x)\n", a, d,
               m68k_get_reg(NULL, M68K_REG_PC)); } }
#endif
}

unsigned int m68k_read_memory_8(unsigned int a)  { return rd8(a); }
unsigned int m68k_read_memory_16(unsigned int a) { return (rd8(a) << 8) | rd8(a + 1); }
unsigned int m68k_read_memory_32(unsigned int a)
{ return (m68k_read_memory_16(a) << 16) | m68k_read_memory_16(a + 2); }

void m68k_write_memory_8(unsigned int a, unsigned int d)  { wr8(a, d & 0xff); }
void m68k_write_memory_16(unsigned int a, unsigned int d)
{ wr8(a, (d >> 8) & 0xff); wr8(a + 1, d & 0xff); }
void m68k_write_memory_32(unsigned int a, unsigned int d)
{ m68k_write_memory_16(a, d >> 16); m68k_write_memory_16(a + 2, d & 0xffff); }

/* disassembler hooks some Musashi builds want */
unsigned int m68k_read_disassembler_8(unsigned int a)  { return rd8(a); }
unsigned int m68k_read_disassembler_16(unsigned int a) { return m68k_read_memory_16(a); }
unsigned int m68k_read_disassembler_32(unsigned int a) { return m68k_read_memory_32(a); }

#ifndef SB_CHEATS_DEFAULT
#define SB_CHEATS_DEFAULT 0
#endif

void sb_hw_init(void)
{
    /* DSW2 bit6 = the board's own Invulnerability dip (active low).
     * make CHEATS=1, or SB_INVULN=1 at runtime on the host. */
    if (SB_CHEATS_DEFAULT || getenv("SB_INVULN"))
        sb_dsw2 &= ~0x40;
    memset(sb_ram, 0, sizeof sb_ram);
    memset(sb_spriteram, 0, sizeof sb_spriteram);
    memset(sb_palette, 0, sizeof sb_palette);
    m68k_init();
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_pulse_reset();
}

/* 8MHz, 60Hz, 262 lines -> ~509 cycles/line. IRQ4 @32, IRQ3 @128, IRQ2 @240. */
#define CYC_LINE 509
static void slice(int cycles)
{
    static int hist_on = -1;
    static unsigned hist[0x8000];  /* PC/8 buckets over the 256KB ROM */
    static long samples = 0;
    if (hist_on < 0) hist_on = getenv("PCHIST") ? 1 : 0;
    if (!hist_on) { m68k_execute(cycles); return; }
    while (cycles > 0) {
        m68k_execute(64);
        cycles -= 64;
        unsigned pc = m68k_get_reg(NULL, M68K_REG_PC);
        if (pc < 0x40000) hist[pc >> 3]++;
        if (++samples == 400000) {
            printf("  -- top PCs --\n");
            for (int pass = 0; pass < 10; pass++) {
                unsigned best = 0, bi = 0;
                for (unsigned i = 0; i < 0x8000; i++)
                    if (hist[i] > best) { best = hist[i]; bi = i; }
                if (!best) break;
                printf("    %06x  %u\n", bi << 3, best);
                hist[bi] = 0;
            }
            samples = 0;
        }
    }
}

void sb_hw_frame(void)
{
    /* SB_POKE=off:val[,off:val...] — force work-RAM bytes every frame */
    static int npokes = -1;
    static struct { int off, val; } pokes[32];
    if (npokes < 0) {
        npokes = 0;
        const char *e = getenv("SB_POKE");
        while (e && *e && npokes < 32) {
            unsigned o, v;
            if (sscanf(e, "%x:%x", &o, &v) == 2 && o < 0x4000) {
                pokes[npokes].off = o; pokes[npokes].val = v; npokes++;
            }
            e = strchr(e, ',');
            if (e) e++;
        }
    }
    static int trace = -1, fr = 0;
    if (fr > 280)
        for (int i = 0; i < npokes; i++) sb_ram[pokes[i].off] = pokes[i].val;
    if (trace < 0) trace = getenv("PCTRACE") ? 1 : 0;
    slice(32 * CYC_LINE);
    m68k_set_irq(4);
    slice((128 - 32) * CYC_LINE);
    m68k_set_irq(3);
    slice((240 - 128) * CYC_LINE);
    m68k_set_irq(2);
    slice((262 - 240) * CYC_LINE);
    ++fr;
    if (trace && fr >= 250 && fr < 256) {
        printf("  f%d pc=%06x sr=%04x  shadow27c=%02x%02x shadowc7c=%02x%02x\n",
               fr, m68k_get_reg(NULL, M68K_REG_PC), m68k_get_reg(NULL, M68K_REG_SR),
               sb_ram[0x27c], sb_ram[0x27d], sb_ram[0xc7c], sb_ram[0xc7d]);
    }
}
