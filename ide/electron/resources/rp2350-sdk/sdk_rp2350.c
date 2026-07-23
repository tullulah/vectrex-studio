/* sdk_rp2350.c — RP2350 hardware backend for the libvpy SDK contract.
 *
 * libvpy (vpy.c) is written against a tiny "PiTrex SDK" contract: it draws every
 * segment through v_directDraw32, writes sound through v_writePSG, reads input
 * through v_readButtons / v_readJoystick1Analog, and paces frames with
 * v_WaitRecal. The WASM sim satisfies that contract in pitrex-sim/sdk_host.c
 * (against the JS emulator); the PiTrex hardware satisfies it with the real
 * PiTrex SDK. This file is the third backend: it maps the SAME contract onto the
 * RP2350 cartridge BIOS, which owns all Vectrex hardware and exposes services as
 * ARM `svc #N` traps (see docs/RP2350_BIOS.md, BIOS_VERSION 0x0006).
 *
 * So a C game built with main.c + vpy.c + this file + rp2350_start.s links to a
 * RAM-loaded RP2350 game .bin (SYS_LAUNCH loads it at 0x20040000 and jumps to
 * game_main). No game-code or libvpy change — same contract, new backend.
 */
#include <stdint.h>

/* ── BIOS syscall traps (Thumb `svc #imm`; args r0-r3, return in r0, AAPCS).
 * The `svc` immediate must be a compile-time literal, so one wrapper per number.
 * Exception entry/return stacks r0-r3, and the SVCall handler writes only the
 * return value back into the stacked r0 — so r1-r3 are preserved across the
 * trap and r0 is in+out. */
static inline void sys_reset0ref(void)       { __asm__ volatile("svc #0"  ::: "r0","r1","r2","r3","memory"); }
static inline void sys_wait_recal(void)      { __asm__ volatile("svc #1"  ::: "r0","r1","r2","r3","memory"); }
static inline void sys_set_intensity(int b)  { register int r0 __asm__("r0")=b; __asm__ volatile("svc #2" : "+r"(r0) :: "memory"); }
static inline void sys_move(int x,int y)     { register int r0 __asm__("r0")=x; register int r1 __asm__("r1")=y; __asm__ volatile("svc #3" : "+r"(r0) : "r"(r1) : "memory"); }
static inline void sys_draw_delta(int dx,int dy){ register int r0 __asm__("r0")=dx; register int r1 __asm__("r1")=dy; __asm__ volatile("svc #4" : "+r"(r0) : "r"(r1) : "memory"); }
static inline void sys_psg_write(int reg,int val){ register int r0 __asm__("r0")=reg; register int r1 __asm__("r1")=val; __asm__ volatile("svc #5" : "+r"(r0) : "r"(r1) : "memory"); }
static inline int  sys_read_buttons(void)    { register int r0 __asm__("r0"); __asm__ volatile("svc #7"  : "=r"(r0) :: "memory"); return r0; }
static inline int  sys_read_axes(void)       { register int r0 __asm__("r0"); __asm__ volatile("svc #13" : "=r"(r0) :: "memory"); return r0; }
static inline void sys_play_music(const void *p){ register const void *r0 __asm__("r0")=p; __asm__ volatile("svc #21" : "+r"(r0) :: "memory"); }
static inline void sys_stop_music(void)      { __asm__ volatile("svc #22" ::: "r0","r1","r2","r3","memory"); }

/* ── Input snapshot owned by the SDK layer (libvpy reads these as externs). ── */
uint8_t currentButtonState = 0;
int8_t  currentJoy1X = 0;
int8_t  currentJoy1Y = 0;

/* libvpy scales VPy logical units (±127 screen) by VPY_SCALE for PiTrex
 * deflection units; the BIOS draw model wants raw i8 (±127) screen coords, so we
 * divide the scaled coords back down. The multiply was exact, so this is lossless. */
#define VPY_SCALE 127

/* ── Lifecycle (BIOS already did clocks/pins/VIA init; nothing to do here). ── */
void vectrexinit(int mode) { (void)mode; }
void v_init(void)          {}
void v_setRefresh(int hz)  { (void)hz; }   /* BIOS paces ~50 Hz in SYS_WAIT_RECAL */

/* ── Beam-position tracking. SYS_WAIT_RECAL zero-refs the beam each frame, so we
 * reset our tracked origin to centre there and issue each segment's positioning
 * as a delta from the previous endpoint (segment chaining — no redundant
 * re-zero between connected strokes). ── */
static int s_beam_x = 0, s_beam_y = 0;

/* Bound integrator drift: chaining segments with only relative moves (no re-zero)
 * lets the integrators drift, so after N consecutive segments we force a fresh
 * zero-ref. This is the runtime analogue of PiTrex's MAX_CONSECUTIVE_DRAWS (=65)
 * and of the VPy compiler's fusion cap: 32 was HW-validated to draw cleanly
 * without a re-zero, above which shapes visibly wobble. */
#define VPY_MAX_CONSECUTIVE_DRAWS 32
static int s_draws_since_zero = 0;

static int clamp127(int v) { return v > 127 ? 127 : (v < -127 ? -127 : v); }

/* Blanked move to (x,y), split into ≤127 steps so a long move doesn't wrap the
 * i8 DAC (the integrators accumulate). Capped at 8 steps like the BIOS dv_move_to. */
static void beam_move_to(int x, int y)
{
    int dx = x - s_beam_x, dy = y - s_beam_y, steps = 0;
    while ((dx > 127 || dx < -127 || dy > 127 || dy < -127) && steps < 8) {
        int sx = clamp127(dx), sy = clamp127(dy);
        sys_move(sx, sy);
        dx -= sx; dy -= sy; steps++;
    }
    /* Skip the reposition when the beam is already there — connected segments in
     * a path share endpoints, so this elides one MOVE(0,0) syscall per segment
     * (matches the native backend's stroke chaining; big win vs a move per seg). */
    if (dx || dy) sys_move(dx, dy);
    s_beam_x = x; s_beam_y = y;
}

/* One absolute segment: set brightness, blank-move to the start, lit-draw to the
 * end. A line per the BIOS convention: SET_INTENSITY → MOVE(x0,y0) → DRAW_DELTA. */
void v_directDraw32(int32_t x0, int32_t y0, int32_t x1, int32_t y1, uint8_t b)
{
    int ax0 = (int)x0 / VPY_SCALE, ay0 = (int)y0 / VPY_SCALE;
    int ax1 = (int)x1 / VPY_SCALE, ay1 = (int)y1 / VPY_SCALE;
    /* After N chained segments the beam has drifted enough to wobble — force a
     * fresh zero-ref so the next segment positions from a clean origin. */
    if (s_draws_since_zero >= VPY_MAX_CONSECUTIVE_DRAWS) {
        sys_reset0ref();
        s_beam_x = 0; s_beam_y = 0;
        s_draws_since_zero = 0;
    }
    sys_set_intensity(b);
    beam_move_to(ax0, ay0);
    sys_draw_delta(ax1 - ax0, ay1 - ay0);
    s_beam_x = ax1; s_beam_y = ay1;
    s_draws_since_zero++;
}

/* ── Frame pace + input. vpy_frame_begin() calls v_WaitRecal then the two input
 * refreshers, so v_WaitRecal only paces + re-zeros our tracked beam. ── */
void v_WaitRecal(void)
{
    sys_wait_recal();
    s_beam_x = 0; s_beam_y = 0;
    s_draws_since_zero = 0;   /* WAIT_RECAL zero-refs the beam → fresh drift budget */
}

/* Start a new stroke/path with a fresh zero-ref, so integrator drift can't carry
 * across shape/path boundaries (mirrors the native ARM backend's per-path
 * re-zero). libvpy calls this at each path start on RP2350. The MAX_CONSECUTIVE
 * cap in v_directDraw32 still bounds a single very long path on top of this. */
void v_beamNewStroke(void)
{
    sys_reset0ref();
    s_beam_x = 0; s_beam_y = 0;
    s_draws_since_zero = 0;
}

uint8_t v_readButtons(void)
{
    /* SYS_READ_BUTTONS returns P1 in bits 0-3 (P2 in 4-7); libvpy's J1_BUTTON_N
     * reads bit N-1 of currentButtonState, so this maps 1:1. */
    currentButtonState = (uint8_t)sys_read_buttons();
    return currentButtonState;
}

void v_readJoystick1Analog(void)
{
    /* SYS_READ_AXES: (J1X<<24)|(J1Y<<16)|(J2X<<8)|J2Y, each a raw i8. */
    int a = sys_read_axes();
    currentJoy1X = (int8_t)(a >> 24);
    currentJoy1Y = (int8_t)(a >> 16);
}

void v_writePSG(uint8_t reg, uint8_t val) { sys_psg_write(reg, val); }

/* ── Core-1 music. The BIOS runs the .vmus sequencer on core 1 (tempo decoupled
 * from core-0 draw load); core 0 just hands over the track and stops it. libvpy
 * calls these instead of its software sequencer when built for RP2350. ── */
void v_playMusic(const unsigned char *vmus) { sys_play_music(vmus); }
void v_stopMusic(void)                      { sys_stop_music(); }

/* ── Freestanding libc bits. GCC emits calls to memset/memcpy/memmove for
 * aggregate init and array ops, and there is no libc in this bare-metal link
 * (we pull in only libgcc for the AEABI integer-division helpers). ── */
#include <stddef.h>
void *memset(void *d, int c, size_t n)  { unsigned char *p = d; while (n--) *p++ = (unsigned char)c; return d; }
void *memcpy(void *d, const void *s, size_t n) { unsigned char *pd = d; const unsigned char *ps = s; while (n--) *pd++ = *ps++; return d; }
void *memmove(void *d, const void *s, size_t n) {
    unsigned char *pd = d; const unsigned char *ps = s;
    if (pd < ps) { while (n--) *pd++ = *ps++; }
    else { pd += n; ps += n; while (n--) *--pd = *--ps; }
    return d;
}
