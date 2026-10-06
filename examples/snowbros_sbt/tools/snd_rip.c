/* snd_rip.c — rip Snow Bros' music and SFX out of the ROM, on the host.
 *
 * The board's sound section is a Z80B (6 MHz) running sbros-4.29 with a YM3812
 * at 3 MHz: the 68000 writes a one-byte command to a latch (NMI), the Z80's
 * program plays the corresponding tune/effect by writing YM3812 registers,
 * paced by the YM's own timer IRQ. None of that hardware exists on the
 * Vectrex, but the MUSIC is those register writes — so this tool runs the real
 * Z80 program (mz80, the same core the TNZS port uses), feeds it each command
 * from a clean boot, and logs every YM3812 register write with its timestamp.
 * A later stage converts those logs to PSG .vmus/.vsfx event streams.
 *
 * Machine facts, checked against MAME (src/mame/kaneko/snowbros.cpp):
 *   Z80 @ 12MHz/2, ROM 0000-7fff, RAM 8000-87ff
 *   IO (mask 0xff): 02/03 YM3812 addr/data (status on read), 04 latch r/w
 *   latch write from the 68000 -> Z80 NMI;  YM3812 IRQ -> Z80 INT
 * YM3812 timer periods, from MAME's ymfm (ymfm_fm.ipp update_timer +
 * ymfm_opl.h timer_a_value: 8->10 bits, x4):
 *   T1 = (256-N) * 288 YM clocks; T2 = (256-N) * 1152.  YM runs at half the
 *   Z80 clock, so in Z80 cycles: T1 = (256-N)*576, T2 = (256-N)*2304.
 *
 * Usage:  snd_rip <sbros-4.29> <outdir> [cmd...]
 *   No cmds -> rip 0x01-0x3f and 0xf0-0xff.  Each command boots the Z80
 *   fresh (500 ms), sends the command, and runs until the YM has been quiet
 *   for 3 s (music never goes quiet: 120 s cap, the loop is cut later).
 *   Output: <outdir>/cmd_XX.log with "us reg val" lines, and a one-line
 *   summary per command on stdout.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mz80.h"

#define Z80_HZ      6000000u
#define BOOT_CYC    (Z80_HZ / 2)          /* 500 ms of clean boot */
#define QUIET_CYC   (3u * Z80_HZ)         /* stop after 3 s without a voice write */
#define CAP_CYC     (120u * Z80_HZ)       /* looping music: hard cap */
#define SLICE       600                   /* 100 us between timer checks */

static UINT8 base[0x10000];               /* 0000-7fff ROM, 8000-87ff RAM */
static UINT8 rom[0x8000];

/* ---- YM3812: timers + status, faithfully; voices only logged -------------- */
static UINT8  ym_addr;
static UINT8  ym_status;                  /* bit7 IRQ, bit6 T1 flag, bit5 T2 flag */
static UINT8  ym_t1, ym_t2, ym_ctl;       /* regs 02, 03, 04 */
static unsigned long long now;            /* Z80 cycles since this boot */
static unsigned long long t1_due, t2_due; /* 0 = timer stopped */
static unsigned long long last_voice;     /* time of the last non-timer write */

static FILE *logf;
static unsigned n_writes;
static unsigned chan_mask;                /* channels touched via A0-B8 */
static unsigned key_mask;                 /* keys currently down (b0-b8 + rhythm) */
static int rhythm_seen;

static void ym_write(UINT8 reg, UINT8 v)
{
    switch (reg) {
    case 0x02: ym_t1 = v; return;
    case 0x03: ym_t2 = v; return;
    case 0x04:
        if (v & 0x80) {                   /* RST: clear flags+IRQ, rest ignored */
            ym_status = 0;
            return;
        }
        ym_ctl = v;
        /* ST bits start/stop; (re)load on every control write with ST set,
         * which is how the chip behaves on a 0->1 edge and harmless otherwise:
         * the program only rewrites reg 4 to restart or stop a timer. */
        t1_due = (v & 0x01) ? now + (unsigned long long)(256 - ym_t1) * 576u  : 0;
        t2_due = (v & 0x02) ? now + (unsigned long long)(256 - ym_t2) * 2304u : 0;
        return;
    default: break;
    }
    n_writes++;
    if (reg >= 0xA0 && reg <= 0xB8) chan_mask |= 1u << (reg & 0x0F);
    if (reg == 0xBD && (v & 0x3F)) rhythm_seen = 1;
    /* "Still sounding" = some key is down: melodic key-on is bit 5 of B0-B8,
     * rhythm keys are the low 5 bits of BD. The driver refreshes every channel
     * register each timer tick whether anything plays or not, so mere write
     * traffic says nothing — the KEYS are what marks an effect's end. */
    if (reg >= 0xB0 && reg <= 0xB8) {
        if (v & 0x20) key_mask |= 1u << (reg - 0xB0); else key_mask &= ~(1u << (reg - 0xB0));
    }
    if (reg == 0xBD) {
        if (v & 0x1F) key_mask |= 1u << 9; else key_mask &= ~(1u << 9);
    }
    if (key_mask) last_voice = now;
    if (logf) fprintf(logf, "%llu %02x %02x\n", now / 6u, reg, v);
}

static void ym_tick(void)
{
    if (t1_due && now >= t1_due) {
        t1_due += (unsigned long long)(256 - ym_t1) * 576u;
        if (!(ym_ctl & 0x40)) ym_status |= 0xC0;      /* T1 flag + IRQ */
    }
    if (t2_due && now >= t2_due) {
        t2_due += (unsigned long long)(256 - ym_t2) * 2304u;
        if (!(ym_ctl & 0x20)) ym_status |= 0xA0;      /* T2 flag + IRQ */
    }
}

/* ---- Z80 machine hooks ---------------------------------------------------- */
static UINT8 latch_cmd;

static UINT16 io_read(UINT16 a, struct z80PortRead *p)
{
    (void)p;
    switch (a & 0xff) {
    case 0x02: case 0x03: return ym_status;
    case 0x04:            return latch_cmd;
    }
    return 0xff;
}

static void io_write(UINT16 a, UINT8 v, struct z80PortWrite *p)
{
    (void)p;
    /* SND_RAWIO=1: dump every OUT as seen, before decoding — for debugging the
     * port model itself (a16 is whatever mz80 puts on the bus). */
    { static int raw = -1; if (raw < 0) raw = getenv("SND_RAWIO") ? 1 : 0;
      if (raw) fprintf(stderr, "OUT %04x %02x @%llu\n", a, v, now / 6u); }
    switch (a & 0xff) {
    case 0x02: ym_addr = v;            return;
    case 0x03: ym_write(ym_addr, v);   return;
    case 0x04: /* reply to the 68000 */ return;
    }
}

static void rom_write(UINT32 a, UINT8 v, struct MemoryWriteByte *p)
{ (void)a; (void)v; (void)p; }        /* writes into ROM: ignore */

/* The FULL 16-bit range, not 00-ff: mz80's block I/O (OUTI here — the YM data
 * write in the ROM's register loop) matches the handler against the whole BC
 * pair, so with B as loop counter the port shows up as e.g. 0x1603. The board
 * only decodes A0-A7 and so do the handlers (a & 0xff). */
static struct z80PortRead  io_rd[] = {
    { 0x0000, 0xffff, io_read, NULL }, { 0xffff, 0xffff, NULL, NULL } };
static struct z80PortWrite io_wr[] = {
    { 0x0000, 0xffff, io_write, NULL }, { 0xffff, 0xffff, NULL, NULL } };
static struct MemoryReadByte  mem_rd[] = {
    { 0xffffffff, 0xffffffff, NULL, NULL } };     /* all plain memory */
static struct MemoryWriteByte mem_wr[] = {
    { 0x0000, 0x7fff, rom_write, NULL }, { 0xffffffff, 0xffffffff, NULL, NULL } };

static void machine_boot(void)
{
    struct mz80context c;
    memset(base, 0, sizeof base);
    memcpy(base, rom, sizeof rom);
    memset(&c, 0, sizeof c);
    mz80GetContext(&c);                   /* pick up defaults (int/nmi addrs) */
    c.z80Base     = base;
    c.z80MemRead  = mem_rd;
    c.z80MemWrite = mem_wr;
    c.z80IoRead   = io_rd;
    c.z80IoWrite  = io_wr;
    mz80SetContext(&c);
    mz80reset();
    ym_addr = ym_status = ym_t1 = ym_t2 = ym_ctl = 0;
    now = 0; t1_due = t2_due = 0; last_voice = 0;
    latch_cmd = 0;
}

static void run_cycles(unsigned long long cycles)
{
    unsigned long long end = now + cycles;
    while (now < end) {
        if (ym_status & 0x80) mz80int(0);     /* level IRQ until RST clears it */
        mz80exec(SLICE);
        now += mz80GetElapsedTicks(1 /* clear */);
        ym_tick();
    }
}

int main(int argc, char **argv)
{
    if (argc < 3) { fprintf(stderr, "usage: %s <sbros-4.29> <outdir> [cmd...]\n", argv[0]); return 1; }

    FILE *f = fopen(argv[1], "rb");
    if (!f || fread(rom, 1, sizeof rom, f) != sizeof rom) {
        fprintf(stderr, "cannot read %s\n", argv[1]); return 1;
    }
    fclose(f);

    int cmds[256], ncmd = 0;
    if (argc > 3) {
        for (int i = 3; i < argc; i++) cmds[ncmd++] = (int)strtoul(argv[i], 0, 16);
    } else {
        for (int c = 0x01; c <= 0x3f; c++) cmds[ncmd++] = c;
        for (int c = 0xf0; c <= 0xff; c++) cmds[ncmd++] = c;
    }

    mz80init();

    for (int i = 0; i < ncmd; i++) {
        int cmd = cmds[i];
        char path[512];

        machine_boot();
        run_cycles(BOOT_CYC);

        snprintf(path, sizeof path, "%s/cmd_%02x.log", argv[2], cmd);
        logf = fopen(path, "w");
        n_writes = 0; chan_mask = 0; rhythm_seen = 0; key_mask = 0;
        last_voice = now;
        unsigned long long t0 = now, cap = now + CAP_CYC;

        latch_cmd = (UINT8)cmd;
        mz80nmi();
        /* The NMI handler (0x66: IN A,(4); LD (8000),A) consumes the command
         * within a few instructions. Clear the latch right after, so a driver
         * that also POLLS port 4 does not see the command forever and retrigger
         * the sound — on the board the latch only matters with the NMI. */
        run_cycles(1000);
        latch_cmd = 0;

        while (now < cap && now - last_voice < QUIET_CYC)
            run_cycles(Z80_HZ / 100);         /* 10 ms at a time */

        fclose(logf); logf = NULL;

        unsigned long long dur_ms =
            n_writes ? (last_voice - t0) / (Z80_HZ / 1000u) : 0;
        if (!n_writes) { remove(path); }
        printf("cmd %02x: %6u writes  %6llu ms%s  chans %03x%s\n",
               cmd, n_writes, dur_ms,
               (now >= cap) ? " (loops)" : "        ",
               chan_mask, rhythm_seen ? "  +rhythm" : "");
        fflush(stdout);
    }
    return 0;
}
