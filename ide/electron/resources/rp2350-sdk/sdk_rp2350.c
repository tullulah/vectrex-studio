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
/* SYS_RASTER_TEXT = 26. It used to be 23 — which the BIOS defines as SYS_PLAY_SFX
 * and dispatches to music::play_sfx(r0). Single-core, r2 (a string pointer) landed
 * in the SFX player as a track pointer: on the UVM2 that walked off into 0xffffffa4
 * and locked the core up inside the SVC handler. Dual-core cart games never saw it
 * because BEAM_RASTER records into the shared buffer instead of trapping, which is
 * why it stayed hidden. 26 is the first free number after SET_TEXT_METRICS (25). */
static inline void sys_raster_text(int x,int y,const unsigned char*s,int n){ register int r0 __asm__("r0")=x; register int r1 __asm__("r1")=y; register const unsigned char* r2 __asm__("r2")=s; register int r3 __asm__("r3")=n; __asm__ volatile("svc #26" :: "r"(r0),"r"(r1),"r"(r2),"r"(r3) : "memory"); }

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

/* ═══════════════════════════════════════════════════════════════════════════
 * DUAL-CORE MODE (opt-in via -DVPY_DUAL_CORE; the game's VPy2 header also sets
 * the dual-core flag so the BIOS launches it on core 1). Compute-heavy games
 * (AAE's 6502 interpreter) overlap their compute with the beam draw: the game
 * runs on CORE 1 and RECORDS its draw commands into a shared RAM ring buffer
 * with NO `svc` — so core 1 makes ZERO flash fetches during a frame. CORE 0
 * materialises the sealed buffer (flash-timed, E-synced bus writes) in parallel.
 * The svc-free requirement is load-bearing: an `svc` fetches the exception
 * vector+handler from flash, which would stall core 0's cycle-timed beam ramps
 * (stretched vectors / broken E-sync). Fixed shared addresses — MUST match the
 * firmware (hardware/debug_cart/firmware/src/dc.rs). VPy games don't define
 * VPY_DUAL_CORE and keep the unchanged single-core svc path below. ══════════ */
#ifdef VPY_DUAL_CORE
struct dc_cmd  { unsigned char op; signed char a; signed char b; unsigned char _pad; };
struct dc_ctrl {
    volatile unsigned char  state[2];  /* 0=FREE (game may write), 1=SEALED (core 0 draws) */
    unsigned char           _p0[2];
    volatile unsigned short count[2];  /* # commands in each buffer */
    volatile unsigned int   axes;      /* SYS_READ_AXES snapshot, published by core 0 */
    volatile unsigned int   buttons;   /* SYS_READ_BUTTONS snapshot (P1 bits 0-3) */
};
/* MUST match the firmware dc.rs. 4096 cmds (was 1024): DK's title/intro emit
 * >1024 beam ops; the overflow was dropped, and vk_render draws text/logo LAST,
 * so the title/letters vanished. Buffers moved down into the game-stack gap. */
#define DC_CTRL   ((struct dc_ctrl *)0x20076F00u)
#define DC_BUF0   ((struct dc_cmd  *)0x20077000u)
#define DC_BUF1   ((struct dc_cmd  *)0x2007B000u)
#define DC_CMDS_MAX 4096
#define DC_FREE 0
#define DC_SEALED 1
#define DC_OP_ZERO 0
#define DC_OP_INTENSITY 1
#define DC_OP_MOVE 2
#define DC_OP_DRAW 3
#define DC_OP_RASTER 4   /* header cmd: a=x, b=y, _pad=len; then ceil(len/4) cmds
                          * of raw string bytes. core 0 draws it with the BIOS
                          * shift-register raster font (one sweep per pixel row). */
static int s_dc_w = 0;   /* current write buffer (0/1) */
static int s_dc_n = 0;   /* commands recorded into it so far */
static inline void dc_push(unsigned char op, signed char a, signed char b) {
    if (s_dc_n < DC_CMDS_MAX) {
        struct dc_cmd *buf = s_dc_w ? DC_BUF1 : DC_BUF0;
        buf[s_dc_n].op = op; buf[s_dc_n].a = a; buf[s_dc_n].b = b;
        s_dc_n++;
    }
}
/* Record a raster-text run: a header cmd (x,y,len) followed by the string bytes
 * packed 4 per cmd. core0_materialize replays it via the shift-register font. */
static void dc_push_raster(signed char x, signed char y, const unsigned char *s, int len) {
    if (len < 0) len = 0;
    if (len > 255) len = 255;
    int ndata = (len + 3) / 4;
    if (s_dc_n + 1 + ndata > DC_CMDS_MAX) return;   /* no room this frame */
    struct dc_cmd *buf = s_dc_w ? DC_BUF1 : DC_BUF0;
    buf[s_dc_n].op = DC_OP_RASTER; buf[s_dc_n].a = x; buf[s_dc_n].b = y;
    buf[s_dc_n]._pad = (unsigned char)len; s_dc_n++;
    for (int i = 0; i < len; i += 4) {
        unsigned char *p = (unsigned char *)&buf[s_dc_n];
        p[0] = s[i];
        p[1] = (i + 1 < len) ? s[i + 1] : 0;
        p[2] = (i + 2 < len) ? s[i + 2] : 0;
        p[3] = (i + 3 < len) ? s[i + 3] : 0;
        s_dc_n++;
    }
}
#define BEAM_ZERO()       dc_push(DC_OP_ZERO, 0, 0)
#define BEAM_INTENSITY(b) dc_push(DC_OP_INTENSITY, (signed char)(b), 0)
#define BEAM_MOVE(x,y)    dc_push(DC_OP_MOVE, (signed char)(x), (signed char)(y))
#define BEAM_DRAW(x,y)    dc_push(DC_OP_DRAW, (signed char)(x), (signed char)(y))
#define BEAM_RASTER(x,y,s,n) dc_push_raster((signed char)(x),(signed char)(y),(s),(n))
#else
#define BEAM_ZERO()       sys_reset0ref()
#define BEAM_INTENSITY(b) sys_set_intensity(b)
#define BEAM_MOVE(x,y)    sys_move((x),(y))
#define BEAM_DRAW(x,y)    sys_draw_delta((x),(y))
#define BEAM_RASTER(x,y,s,n) sys_raster_text((x),(y),(s),(n)) /* SYS #26 */
#endif

/* Draw a raster-font string at device coords (x,y) (i8, ±127). Dual-core records
 * it into the shared list (core 0 replays via the BIOS shift-register font);
 * single-core traps to the BIOS raster primitive. `s` = bytes 0x20..0x6F. */
void v_rasterText(int x, int y, const unsigned char *s, int n) { BEAM_RASTER(x, y, s, n); }

/* Draw ONE horizontal row of RAW bytes (each byte = 8 pixels, bit7 = leftmost) at
 * device coords (x,y) via the shift-register raster sweep — the general primitive
 * behind the ZX-Spectrum screen render (one sweep per non-blank pixel row). Same
 * DC encoding as v_rasterText; core 0 now materialises OP_RASTER as raw rows. */
void v_rasterRow(int x, int y, const unsigned char *s, int n) { BEAM_RASTER(x, y, s, n); }

/* Set the beam Z-axis intensity for the following draws (records OP_INTENSITY in
 * dual-core; the core-0 materialiser calls set_brightness before replaying). The
 * raster row sweep relies on this being set BEFORE the rows (not inline). */
void v_setIntensity(int b) { BEAM_INTENSITY((signed char)b); }

/* Bound integrator drift: chaining segments with only relative moves (no re-zero)
 * lets the integrators drift, so after N consecutive segments we force a fresh
 * zero-ref. This is the runtime analogue of PiTrex's MAX_CONSECUTIVE_DRAWS (=65)
 * and of the VPy compiler's fusion cap: 32 was HW-validated to draw cleanly
 * without a re-zero, above which shapes visibly wobble. Per-game overridable
 * (-DVPY_MAX_CONSECUTIVE_DRAWS=N): games whose runtime MERGES segments emit fewer
 * but LONGER vectors that drift more per vector, so they want a lower cap (more
 * frequent re-zeros) to keep glyphs/shapes landing where they belong. */
#ifndef VPY_MAX_CONSECUTIVE_DRAWS
#define VPY_MAX_CONSECUTIVE_DRAWS 32
#endif
static int s_draws_since_zero = 0;
/* Cache the last intensity so we skip the redundant SET_INTENSITY syscall+bus
 * write when consecutive segments share a brightness — measured 42–100% of them
 * do (starcas 100%, tacscan 92%, bzone/redbaron ~45%). Reset each frame in case
 * the BIOS touches intensity between frames. Cuts per-frame beam work → less
 * flicker on the vector-heavy AAE arcade ports. */
static int s_last_intensity = -1;

static int clamp127(int v) { return v > 127 ? 127 : (v < -127 ? -127 : v); }

/* Blanked move to (x,y), split into ≤127 steps so a long move doesn't wrap the
 * i8 DAC (the integrators accumulate). Capped at 8 steps like the BIOS dv_move_to. */
static void beam_move_to(int x, int y)
{
    int dx = x - s_beam_x, dy = y - s_beam_y, steps = 0;
    while ((dx > 127 || dx < -127 || dy > 127 || dy < -127) && steps < 8) {
        int sx = clamp127(dx), sy = clamp127(dy);
        BEAM_MOVE(sx, sy);
        dx -= sx; dy -= sy; steps++;
    }
    /* Skip the reposition when the beam is already there — connected segments in
     * a path share endpoints, so this elides one MOVE(0,0) syscall per segment
     * (matches the native backend's stroke chaining; big win vs a move per seg). */
    if (dx || dy) BEAM_MOVE(dx, dy);
    s_beam_x = x; s_beam_y = y;
}

/* LIT draw to (x,y), split into N PROPORTIONAL ≤127 i8 chunks. A DP-simplified
 * long vector (Speed Freak's road rail collapses to one segment >127 units) would
 * be truncated by the i8 BEAM_DRAW / dc_cmd delta and vanish. But the split must
 * keep the SLOPE: clamping dx and dy independently draws chunks of different angles
 * → the line kinks/goes random (the bent right rail). Divide the whole vector into
 * n = ceil(max(|dx|,|dy|)/127) equal sub-segments so every chunk is collinear. */
static void beam_draw_to(int x, int y)
{
    int sx0 = s_beam_x, sy0 = s_beam_y;
    int dx = x - sx0, dy = y - sy0;
    int adx = dx < 0 ? -dx : dx, ady = dy < 0 ? -dy : dy;
    int n = ((adx > ady ? adx : ady) + 126) / 127;   /* ceil(max/127) */
    if (n < 1) n = 1;
    for (int i = 1; i <= n; i++) {
        int tx = sx0 + (int)((long)dx * i / n);
        int ty = sy0 + (int)((long)dy * i / n);
        BEAM_DRAW(tx - s_beam_x, ty - s_beam_y);
        s_beam_x = tx; s_beam_y = ty;
    }
}

/* ── Contiguous collinear-run merge — the runtime analogue of the VPy codegen's
 * vec-simplify. The AAE 3D ports (Battlezone/Red Baron) subdivide straight edges
 * into many ≤2-unit segments — ~70% of the scene — and each pays a full beam
 * setup (Y S&H charge + ramp) → flicker. Accumulate a run of contiguous,
 * same-brightness, near-collinear segments and draw it as ONE vector. MERGE_TOL
 * is the max perpendicular deviation (device units, ±127 space) a segment may add
 * before it's treated as a corner; 0 disables the merge. Applies to every game
 * that draws via v_directDraw32 (VPy games already simplify, so few merges fire). */
#ifndef MERGE_TOL
#define MERGE_TOL 1
#endif
/* Intensity-gated merge: some games mix BRIGHT long straight lines (which want an
 * aggressive tolerance so a slightly-curved run collapses to a couple of vectors —
 * e.g. Speed Freak's perspective road rails) with DIM small glyphs (text, which a
 * high tolerance would visibly deform). A vector whose brightness ≥ MERGE_INT_HI
 * uses MERGE_TOL_HI instead of MERGE_TOL. Defaults leave every game unchanged:
 * MERGE_TOL_HI = MERGE_TOL, MERGE_INT_HI = 128 (never triggers). */
#ifndef MERGE_TOL_HI
#define MERGE_TOL_HI MERGE_TOL
#endif
#ifndef MERGE_INT_HI
#define MERGE_INT_HI 128
#endif
/* Longest merged vector, in device units. The merge is bounded anyway by the i8
 * DRAW delta (±127), but a game whose art is drawn as deliberately SHORT collinear
 * chunks may have chosen that length because one long analog ramp visibly drifts or
 * bows on its hardware — merging the chunks back would undo the workaround. Lower
 * this to keep the benefit (fewer beam setups) without recreating the long ramp.
 * Default 127 = the i8 limit, i.e. unchanged for every existing game. */
#ifndef MERGE_MAX
#define MERGE_MAX 127
#endif
static int s_run = 0, s_run_x0, s_run_y0, s_run_x1, s_run_y1, s_run_b;

/* Douglas-Peucker chain simplification — the runtime twin of the compile-time
 * simplify_polyline in vpy_codegen/src/vecres.rs. A curved multi-segment path
 * (Speed Freak's road) fits the greedy collinear merge badly: it snaps at every
 * bend yet fuses near-collinear glyph strokes (text deforms). DP instead keeps the
 * vertices of maximum perpendicular deviation and drops the ones lying on the
 * retained chord — a smooth run collapses to a few long vectors while true corners
 * (glyph vertices, road bends) survive. Per-game (-DSIMPLIFY_EPS=N, a ±127-space
 * epsilon); 0 = off (default; other games unchanged). Integer math: compare
 * perp²·len2 = cross² against eps²·len2, so no sqrt. */
#ifndef SIMPLIFY_EPS
#define SIMPLIFY_EPS 0
#endif
/* Only Douglas-Peucker chains of at least this many points. Long polylines (a road)
 * simplify; short shapes (text glyphs — a few strokes) pass through INTACT, so DP
 * shrinks the road without eating letters. Per-game (-DSIMPLIFY_MIN_CHAIN=N). */
#ifndef SIMPLIFY_MIN_CHAIN
#define SIMPLIFY_MIN_CHAIN 1
#endif
#if SIMPLIFY_EPS > 0
#define CHAIN_MAX 96
static int s_chx[CHAIN_MAX], s_chy[CHAIN_MAX], s_chn = 0, s_chb = -1;
static void dp_rec(int first, int last, long long eps2, unsigned char *keep)
{
    if (last <= first + 1) return;
    long ax = s_chx[first], ay = s_chy[first];
    long bx = s_chx[last],  by = s_chy[last];
    long dx = bx - ax, dy = by - ay;
    long long len2 = (long long)dx * dx + (long long)dy * dy;
    long long best = -1; int split = first;
    for (int i = first + 1; i < last; i++) {
        long px = s_chx[i], py = s_chy[i];
        long long m;
        if (len2 > 0) {                    /* perp² · len2 == cross²          */
            long long cross = (long long)dx * (ay - py) - (long long)(ax - px) * dy;
            m = cross * cross;
        } else {                           /* degenerate chord: point dist²   */
            long long ex = px - ax, ey = py - ay;
            m = ex * ex + ey * ey;
        }
        if (m > best) { best = m; split = i; }
    }
    long long thresh = (len2 > 0) ? eps2 * len2 : eps2;
    if (best > thresh) {
        keep[split] = 1;
        dp_rec(first, split, eps2, keep);
        dp_rec(split, last,  eps2, keep);
    }
}
#endif

/* Emit one absolute segment: re-zero if the drift budget is spent, set brightness
 * (cached), blank-move to the start, lit-draw to the end (BIOS convention). */
static void beam_seg(int ax0, int ay0, int ax1, int ay1, int b)
{
    /* Bound integrator drift by re-zeroing — but ONLY at a chain boundary (where a
     * blanked move to the next start is needed anyway), never MID contiguous run.
     * A mid-run re-zero sends the beam to centre and re-approaches over a long
     * blanked move whose settle error DISPLACES the segment — worst on runs far
     * from centre (Speed Freak's right road rail, always the one that "walks off").
     * So a contiguous run draws unbroken; drift only resets between runs. */
    int need_move = (ax0 != s_beam_x || ay0 != s_beam_y);
    if (need_move && s_draws_since_zero >= VPY_MAX_CONSECUTIVE_DRAWS) {
        BEAM_ZERO();
        s_beam_x = 0; s_beam_y = 0;
        s_draws_since_zero = 0;
    }
    if (b != s_last_intensity) { BEAM_INTENSITY(b); s_last_intensity = b; }
    beam_move_to(ax0, ay0);
    beam_draw_to(ax1, ay1);   /* splits >127 i8 chunks (DP long vectors) */
    s_draws_since_zero++;
}

/* ── Frame-level stroke reorder (nearest-neighbour) ─────────────────────────
 * On this HW the beam's per-vector time is ∝ travel, so drawing shapes in the
 * order the game emits them makes the beam criss-cross the screen BLANKED — for
 * a busy screen (Donkey Kong) ~80% of the frame's beam-time was wasted on those
 * repositioning moves, collapsing the refresh rate → heavy flicker. So instead
 * of emitting each segment immediately, emit_seg() RECORDS it into a stroke (a
 * maximal run of connected, same-brightness segments); at v_WaitRecal the frame
 * is flushed with the strokes ordered greedily nearest-first, each in whichever
 * direction starts closest to the beam. Same picture (phosphor persistence hides
 * draw order), a fraction of the blanked travel — applies to EVERY game.
 * Per-game escape: -DVPY_NO_REORDER falls back to immediate emission. */
#ifndef VPY_NO_REORDER
#ifndef VPY_REORDER_MAX_PTS
#define VPY_REORDER_MAX_PTS    4096
#endif
#ifndef VPY_REORDER_MAX_STROKE
#define VPY_REORDER_MAX_STROKE 1024
#endif
static short  rr_y[VPY_REORDER_MAX_PTS], rr_x[VPY_REORDER_MAX_PTS];
static int    rr_off[VPY_REORDER_MAX_STROKE], rr_len[VPY_REORDER_MAX_STROKE], rr_b[VPY_REORDER_MAX_STROKE];
static int    rr_npts = 0, rr_nst = 0;
/* Last frame's stroke count, kept after the reset so it can be read live. */
volatile int  vpy_strokes_last = 0;

/* record a segment; extend the open stroke iff it connects and shares brightness */
static void emit_seg(int ax0, int ay0, int ax1, int ay1, int b)
{
    if (rr_nst > 0 && rr_npts > 0 && rr_npts < VPY_REORDER_MAX_PTS &&
        rr_y[rr_npts-1] == ay0 && rr_x[rr_npts-1] == ax0 && rr_b[rr_nst-1] == b) {
        rr_y[rr_npts] = ay1; rr_x[rr_npts] = ax1; rr_npts++;
        rr_len[rr_nst-1]++;
        return;
    }
    if (rr_nst < VPY_REORDER_MAX_STROKE && rr_npts + 2 <= VPY_REORDER_MAX_PTS) {
        rr_off[rr_nst] = rr_npts; rr_len[rr_nst] = 2; rr_b[rr_nst] = b; rr_nst++;
        rr_y[rr_npts] = ay0; rr_x[rr_npts] = ax0; rr_npts++;
        rr_y[rr_npts] = ay1; rr_x[rr_npts] = ax1; rr_npts++;
        return;
    }
    beam_seg(ax0, ay0, ax1, ay1, b);   /* buffer full → emit directly (no reorder) */
}

static long rr_d2(int ay, int ax, int by, int bx){ long dy = ay-by, dx = ax-bx; return dy*dy + dx*dx; }

/* reorder + emit the frame's recorded strokes, then reset. Beam starts at the
 * device origin (0,0) — v_WaitRecal re-zeros it right after. O(strokes^2). */
static void flush_frame(void)
{
    int by = 0, bx = 0;
    for (int done = 0; done < rr_nst; done++) {
        int best = -1, rev = 0; long bestd = 0;
        for (int s = 0; s < rr_nst; s++) {
            if (rr_len[s] < 0) continue;                 /* already emitted */
            int a = rr_off[s], z = rr_off[s] + rr_len[s] - 1;
            long d0 = rr_d2(by, bx, rr_y[a], rr_x[a]);
            long d1 = rr_d2(by, bx, rr_y[z], rr_x[z]);
            if (best < 0 || d0 < bestd) { bestd = d0; best = s; rev = 0; }
            if (d1 < bestd)             { bestd = d1; best = s; rev = 1; }
        }
        int a = rr_off[best], n = rr_len[best], b = rr_b[best];
        rr_len[best] = -1;
        if (!rev) {
            for (int i = 0; i < n-1; i++) beam_seg(rr_x[a+i], rr_y[a+i], rr_x[a+i+1], rr_y[a+i+1], b);
            by = rr_y[a+n-1]; bx = rr_x[a+n-1];
        } else {
            for (int i = n-1; i > 0; i--) beam_seg(rr_x[a+i], rr_y[a+i], rr_x[a+i-1], rr_y[a+i-1], b);
            by = rr_y[a]; bx = rr_x[a];
        }
    }
    vpy_strokes_last = rr_nst;
    rr_npts = 0; rr_nst = 0;
}
#else
#define emit_seg    beam_seg    /* reorder disabled: emit immediately */
#define flush_frame()           ((void)0)
#endif

#if SIMPLIFY_EPS > 0
/* Douglas-Peucker the buffered contiguous chain, emit the kept vertices as
 * connected segments. */
static void flush_chain(void)
{
    if (s_chn < 2) { s_chn = 0; return; }
    unsigned char keep[CHAIN_MAX];
    for (int i = 0; i < s_chn; i++) keep[i] = 0;
    keep[0] = keep[s_chn - 1] = 1;
    if (s_chn >= SIMPLIFY_MIN_CHAIN)
        dp_rec(0, s_chn - 1, (long long)SIMPLIFY_EPS * SIMPLIFY_EPS, keep);
    else
        for (int i = 1; i < s_chn - 1; i++) keep[i] = 1;   /* short shape: keep all */
    int px = s_chx[0], py = s_chy[0];
    for (int i = 1; i < s_chn; i++)
        if (keep[i]) { emit_seg(px, py, s_chx[i], s_chy[i], s_chb); px = s_chx[i]; py = s_chy[i]; }
    s_chn = 0;
}
#endif

/* Draw + clear the pending merged run. MUST be called before anything that
 * re-zeros the beam (WAIT_RECAL, new stroke) or the run draws from a stale origin. */
static void flush_run(void)
{
    if (s_run) { emit_seg(s_run_x0, s_run_y0, s_run_x1, s_run_y1, s_run_b); s_run = 0; }
#if SIMPLIFY_EPS > 0
    flush_chain();
#endif
}

/* Drop lit segments whose device delta is below CULL_MIN_AX (in ±127 space) on
 * BOTH axes: sub-visible short vectors that still cost a full beam settle. For
 * pseudo-3D / ray-cast games (Speed Freak) these are the far-distance detail that
 * clusters near the vanishing point — invisible-but-expensive now, and re-drawn at
 * full size as the camera nears. Per-game (-DCULL_MIN_AX=N); default 0 = keep all. */
#ifndef CULL_MIN_AX
#define CULL_MIN_AX 0
#endif

/* TEXT opts OUT of the sub-visible cull AND of the collinear merge: glyph strokes
 * ARE small (1-2 units), so culling them mangles the letters, and merging fuses
 * strokes of adjacent letters that happen to abut into one long bright bar. The
 * game brackets its text with v_textBegin()/v_textEnd(); segments drawn in between
 * are kept at full detail and emitted one-for-one, so only NON-text vectors are
 * culled/merged. Before this, a game with vector text had to disable the merge
 * game-wide (jetpac_sbt built -DMERGE_TOL=0), which left its long straight line-art
 * — platforms, floor — drawn as a chain of separate short dashes. No-op for games
 * that never call it (s_in_text stays 0) or that build with both off. */
static int s_in_text = 0;
void v_textBegin(void) { s_in_text = 1; }
void v_textEnd(void)   { s_in_text = 0; }

void v_directDraw32(int32_t x0, int32_t y0, int32_t x1, int32_t y1, uint8_t b)
{
    int ax0 = (int)x0 / VPY_SCALE, ay0 = (int)y0 / VPY_SCALE;
    int ax1 = (int)x1 / VPY_SCALE, ay1 = (int)y1 / VPY_SCALE;
#if CULL_MIN_AX > 0
    if (!s_in_text) {
        int cdx = ax1 - ax0, cdy = ay1 - ay0;
        if (cdx < CULL_MIN_AX && cdx > -CULL_MIN_AX &&
            cdy < CULL_MIN_AX && cdy > -CULL_MIN_AX)
            return;   /* too small to see; the next lit seg's move_to repositions */
    }
#endif
#if SIMPLIFY_EPS > 0
    /* Buffer a contiguous, same-brightness chain; Douglas-Peucker it on flush. */
    if (s_chn > 0 && (int)b == s_chb &&
        ax0 == s_chx[s_chn - 1] && ay0 == s_chy[s_chn - 1] && s_chn < CHAIN_MAX - 1) {
        s_chx[s_chn] = ax1; s_chy[s_chn] = ay1; s_chn++;
    } else {
        flush_chain();
        s_chx[0] = ax0; s_chy[0] = ay0; s_chx[1] = ax1; s_chy[1] = ay1; s_chn = 2; s_chb = (int)b;
    }
    return;
#endif
#if MERGE_TOL > 0 || MERGE_TOL_HI > 0
    int tol = s_in_text ? 0 : (((int)b >= MERGE_INT_HI) ? MERGE_TOL_HI : MERGE_TOL);
    if (tol > 0 && s_run && (int)b == s_run_b && ax0 == s_run_x1 && ay0 == s_run_y1) {
        int rdx = s_run_x1 - s_run_x0, rdy = s_run_y1 - s_run_y0;  /* run so far     */
        int ndx = ax1 - ax0,          ndy = ay1 - ay0;            /* new segment    */
        int ex  = ax1 - s_run_x0,     ey  = ay1 - s_run_y0;       /* merged delta   */
        long cross = (long)rdx * ndy - (long)rdy * ndx;           /* |run||new|sinθ  */
        long dot   = (long)rdx * ndx + (long)rdy * ndy;           /* same direction? */
        long run2  = (long)rdx * rdx + (long)rdy * rdy;
        /* Extend the run iff: same general direction, perpendicular deviation
         * (|cross|/|run|) ≤ tol, and the merged delta still fits an i8 DRAW (and
         * MERGE_MAX, if the game asked for a shorter ceiling than the i8 limit). */
        if (dot >= 0 && cross * cross <= run2 * (long)(tol * tol)
            && ex <= MERGE_MAX && ex >= -MERGE_MAX && ey <= MERGE_MAX && ey >= -MERGE_MAX) {
            s_run_x1 = ax1; s_run_y1 = ay1;
            return;
        }
    }
    flush_run();
    s_run = 1; s_run_x0 = ax0; s_run_y0 = ay0; s_run_x1 = ax1; s_run_y1 = ay1; s_run_b = (int)b;
#else
    emit_seg(ax0, ay0, ax1, ay1, (int)b);
#endif
}

/* ── Frame pace + input. vpy_frame_begin() calls v_WaitRecal then the two input
 * refreshers, so v_WaitRecal only paces + re-zeros our tracked beam. ── */
void v_WaitRecal(void)
{
    flush_run();    /* push the frame's last pending merged run into the buffer  */
    flush_frame();  /* reorder the frame's strokes nearest-first, then emit them */
#ifdef VPY_DUAL_CORE
    /* Seal the frame we just recorded for core 0, then spin (in RAM, no svc/flash)
     * until the OTHER buffer is free so we never overwrite one core 0 is drawing.
     * Pipeline: core 0 draws buffer A while we record buffer B → frame = max(). */
    DC_CTRL->count[s_dc_w] = (unsigned short)s_dc_n;
    __asm__ volatile("dmb 0xf" ::: "memory");
    DC_CTRL->state[s_dc_w] = DC_SEALED;
    __asm__ volatile("sev" ::: "memory");           /* wake core 0 if it's waiting */
    int n = 1 - s_dc_w;
    while (DC_CTRL->state[n] != DC_FREE) { __asm__ volatile("" ::: "memory"); }
    __asm__ volatile("dmb 0xf" ::: "memory");
    s_dc_w = n; s_dc_n = 0;
#else
    sys_wait_recal();
#endif
    s_beam_x = 0; s_beam_y = 0;
    s_draws_since_zero = 0;   /* WAIT_RECAL zero-refs the beam → fresh drift budget */
    s_last_intensity = -1;    /* re-establish brightness on the first segment of the frame */
}

/* Start a new stroke/path with a fresh zero-ref, so integrator drift can't carry
 * across shape/path boundaries (mirrors the native ARM backend's per-path
 * re-zero). libvpy calls this at each path start on RP2350. The MAX_CONSECUTIVE
 * cap in v_directDraw32 still bounds a single very long path on top of this. */
void v_beamNewStroke(void)
{
    flush_run();   /* finish the pending run before this stroke's re-zero */
    BEAM_ZERO();
    s_beam_x = 0; s_beam_y = 0;
    s_draws_since_zero = 0;
}

uint8_t v_readButtons(void)
{
    /* SYS_READ_BUTTONS returns P1 in bits 0-3 (P2 in 4-7); libvpy's J1_BUTTON_N
     * reads bit N-1 of currentButtonState, so this maps 1:1. In dual-core, core 0
     * owns the bus and publishes the snapshot (no svc / bus access from core 1). */
#ifdef VPY_DUAL_CORE
    currentButtonState = (uint8_t)DC_CTRL->buttons;
#else
    currentButtonState = (uint8_t)sys_read_buttons();
#endif
    return currentButtonState;
}

void v_readJoystick1Analog(void)
{
    /* SYS_READ_AXES: (J1X<<24)|(J1Y<<16)|(J2X<<8)|J2Y, each a raw i8. */
#ifdef VPY_DUAL_CORE
    unsigned int a = DC_CTRL->axes;
#else
    unsigned int a = (unsigned int)sys_read_axes();
#endif
    currentJoy1X = (int8_t)(a >> 24);
    currentJoy1Y = (int8_t)(a >> 16);
}

/* The OTHER two mux channels. SYS_READ_AXES already samples all four (the BIOS SARs
 * channels 0..3 = J1X, J1Y, J2X, J2Y in one go), so this costs nothing extra — it just
 * unpacks the half that v_readJoystick1Analog throws away. Useful for a second pad, and
 * for telling "this axis is dead" apart from "this axis is on a different channel than
 * we think" when a controller misbehaves. */
/* WEAK: several AAE ports already define these in their own aae_stubs.c (as
 * `signed char`), and a strong definition here collided with them — 9 games stopped
 * linking with "multiple definition of `currentJoy2X'" the moment this was added.
 * Weak means the SDK supplies them only when the game does not. */
__attribute__((weak)) int8_t currentJoy2X = 0;
__attribute__((weak)) int8_t currentJoy2Y = 0;
__attribute__((weak)) void v_readJoystick2Analog(void)
{
#ifdef VPY_DUAL_CORE
    unsigned int a = DC_CTRL->axes;
#else
    unsigned int a = (unsigned int)sys_read_axes();
#endif
    currentJoy2X = (int8_t)(a >> 8);
    currentJoy2Y = (int8_t)a;
}

void v_writePSG(uint8_t reg, uint8_t val) { sys_psg_write(reg, val); }

/* Digitised-sample audio (AAE Sega-G80). No-op on RP2350 for now: HW needs a
 * software voice mixer feeding the PSG volume-DAC streamer (see the .vsmp path).
 * A game built for rp2350 still triggers these; they just stay silent. */
void v_playSample(int idx, int voice, int loop) { (void)idx; (void)voice; (void)loop; }
void v_stopSample(int voice)                    { (void)voice; }
int  v_samplePlaying(int voice)                 { (void)voice; return 0; }

/* ── Core-1 music. The BIOS runs the .vmus sequencer on core 1 (tempo decoupled
 * from core-0 draw load); core 0 just hands over the track and stops it. libvpy
 * calls these instead of its software sequencer when built for RP2350. ── */
void v_playMusic(const unsigned char *vmus) { sys_play_music(vmus); }
void v_stopMusic(void)                      { sys_stop_music(); }

/* ── Freestanding libc bits. GCC emits calls to memset/memcpy/memmove for
 * aggregate init and array ops, and there is no libc in this bare-metal link
 * (we pull in only libgcc for the AEABI integer-division helpers). ── */
#include <stddef.h>
/* Only when there is NO libc behind us. Under the UVM2 pico-sdk build there is,
 * and defining these again is actively dangerous rather than merely redundant:
 * GCC recognises `while (n--) *p++ = c` as a memset and rewrites it into a CALL
 * to memset — this function — so it recurses until the stack eats the image.
 * Seen on hardware 2026-08-04: dkong's stack walked from 0x20082000 down past
 * 0x20027700 (371 KB) overwriting its own code, then took a HardFault whose
 * handler faulted too and locked the core up. The freestanding cartridge build
 * still needs them; it links no libc at all. */
#ifndef UVM2_PICO_RUNTIME
void *memset(void *d, int c, size_t n)  { unsigned char *p = d; while (n--) *p++ = (unsigned char)c; return d; }
void *memcpy(void *d, const void *s, size_t n) { unsigned char *pd = d; const unsigned char *ps = s; while (n--) *pd++ = *ps++; return d; }
void *memmove(void *d, const void *s, size_t n) {
    unsigned char *pd = d; const unsigned char *ps = s;
    if (pd < ps) { while (n--) *pd++ = *ps++; }
    else { pd += n; ps += n; while (n--) *--pd = *--ps; }
    return d;
}
#endif
