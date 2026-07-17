/*
 * vpy.c — implementation of the VPy builtin runtime on the PiTrex SDK contract.
 * See vpy.h. Everything routes through v_directDraw32 / v_setSoundAY etc., so it
 * behaves identically on real hardware and in the IDE simulator.
 */
#include "vpy.h"
#include <vectrex/vectrexInterface.h>
#include <math.h>

#define VPY_SCALE 127   /* VPy logical unit -> PiTrex deflection unit */

/* ---- state ---- */
static int   s_cur_x = 0, s_cur_y = 0;   /* MOVE origin, in VPy units */
static int   s_intensity = 90;
static int   s_text_size = 2;
static uint32_t s_rng = 0x1234567u;
static int   s_jx = 0, s_jy = 0;
static uint8_t s_btn = 0;

/* sin table: 128 steps per full circle, amplitude +-127 */
static int8_t s_sin[128];
static int s_inited = 0;

static void ensure_tables(void)
{
    if (s_inited) return;
    for (int i = 0; i < 128; i++)
        s_sin[i] = (int8_t)lroundf(sinf((float)i * 6.2831853f / 128.0f) * 127.0f);
    s_inited = 1;
}

/* Draw one segment in absolute VPy space (no MOVE offset). */
static void raw_line(int x0, int y0, int x1, int y1, int b)
{
    v_directDraw32((int32_t)x0 * VPY_SCALE, (int32_t)y0 * VPY_SCALE,
                   (int32_t)x1 * VPY_SCALE, (int32_t)y1 * VPY_SCALE, (uint8_t)b);
}

/* ---- lifecycle ---- */
void vpy_init(void)
{
    ensure_tables();
    vectrexinit(1);
    v_init();
    v_setRefresh(50);   /* Vectrex refresh; .vmus/.vsfx are compiled at 50 fps */
}

void vpy_frame_begin(void)
{
    v_WaitRecal();
    v_readButtons();
    v_readJoystick1Analog();
    s_btn = currentButtonState;
    s_jx = (int)currentJoy1X;
    s_jy = (int)currentJoy1Y;
}

void vpy_run(void (*setup)(void), void (*loop)(void))
{
    vpy_init();
    if (setup) setup();
    for (;;) {
        vpy_frame_begin();
        /* VPy auto-injects MUSIC_UPDATE at loop start — mirror that here so
         * games don't have to call the sequencers manually. */
        vpy_music_update();
        vpy_sfx_update();
        if (loop) loop();
    }
}

/* ---- drawing ---- */
void vpy_set_intensity(int b) { s_intensity = b; }
void vpy_move(int x, int y)   { s_cur_x = x; s_cur_y = y; }

void vpy_draw_line(int x0, int y0, int x1, int y1, int b)
{
    raw_line(x0 + s_cur_x, y0 + s_cur_y, x1 + s_cur_x, y1 + s_cur_y, b);
}

void vpy_draw_circle(int cx, int cy, int r, int b)
{
    ensure_tables();
    int px = cx + r, py = cy;                 /* angle 0 */
    for (int i = 1; i <= 16; i++) {
        int a = (i * 128) / 16;               /* 0..128 */
        int x = cx + (r * s_sin[(a + 32) & 127]) / 127;  /* cos */
        int y = cy + (r * s_sin[a & 127]) / 127;         /* sin */
        raw_line(px, py, x, y, b);
        px = x; py = y;
    }
}

void vpy_draw_rect(int x, int y, int w, int h, int b)
{
    raw_line(x,     y,     x + w, y,     b);
    raw_line(x + w, y,     x + w, y + h, b);
    raw_line(x + w, y + h, x,     y + h, b);
    raw_line(x,     y + h, x,     y,     b);
}

void vpy_draw_filled_rect(int x, int y, int w, int h, int b)
{
    vpy_draw_rect(x, y, w, h, b);
    for (int yy = y + 3; yy < y + h; yy += 3)
        raw_line(x, yy, x + w, yy, b);
}

void vpy_draw_polygon(const int *xy, int n, int b)
{
    if (n < 2) return;
    for (int i = 0; i < n - 1; i++)
        raw_line(xy[2*i], xy[2*i+1], xy[2*i+2], xy[2*i+3], b);
    raw_line(xy[2*(n-1)], xy[2*(n-1)+1], xy[0], xy[1], b);  /* close */
}

void vpy_draw_ellipse(int cx, int cy, int rx, int ry, int b)
{
    ensure_tables();
    int px = cx + rx, py = cy;                /* angle 0 */
    for (int i = 1; i <= 16; i++) {
        int a = (i * 128) / 16;               /* 0..128 */
        int x = cx + (rx * s_sin[(a + 32) & 127]) / 127;  /* cos */
        int y = cy + (ry * s_sin[a & 127]) / 127;         /* sin */
        raw_line(px, py, x, y, b);
        px = x; py = y;
    }
}

/* ---- compiled vector sprites (.vec) --------------------------------------
 * Draw a compiled .vec path stream (from `vpy_cli compile-asset --format c`).
 * Byte format (LE, position-independent — no absolute pointers):
 *   [0..2] path_count (u16)
 *   per path: intensity, y0, x0, 0x00, 0x00, segments..., 0x02
 *     0xFF, dy, dx      -> line delta (i8, i8)
 *     0xFE, 8×i8        -> cubic bezier (ax,ay,cp1x,cp1y,cp2x,cp2y,bx,by),
 *                          center-relative; tessellated here into line segments
 *                          because the host SDK contract only has v_directDraw32.
 * Mirrors pitrex_draw_vector: the beam is seeded at (x0+ox, y0+oy) in VPy units
 * and each line adds its delta; bezier control points are sprite-origin
 * relative. Coordinates scale by VPY_SCALE (via raw_line), exactly like the ARM
 * path (which multiplies by 127). */
static void draw_vec_stream(const unsigned char *data, int ox, int oy,
                            int mirror, int override_b)
{
    if (!data) return;
    int path_count = (int)data[0] | ((int)data[1] << 8);
    const unsigned char *p = data + 2;

    for (int pi = 0; pi < path_count; pi++) {
        int intensity = p[0];
        int y0 = (int8_t)p[1];
        int x0 = (int8_t)p[2];
        p += 5;                     /* intensity + y0 + x0 + 2 padding bytes */
        int b = (override_b > 0) ? override_b : intensity;

        int cx = ox + (mirror ? -x0 : x0);
        int cy = oy + y0;

        for (;;) {
            unsigned char marker = *p++;
            if (marker == 0x02) break;          /* end of path */

            if (marker == 0xFE) {               /* cubic bezier segment */
                int ax  = (int8_t)p[0], ay  = (int8_t)p[1];
                int c1x = (int8_t)p[2], c1y = (int8_t)p[3];
                int c2x = (int8_t)p[4], c2y = (int8_t)p[5];
                int bx  = (int8_t)p[6], by  = (int8_t)p[7];
                p += 8;
                if (mirror) { ax = -ax; c1x = -c1x; c2x = -c2x; bx = -bx; }
                /* Absolute (VPy-unit) control points, sprite-origin relative. */
                float p0x = (float)(ox + ax),  p0y = (float)(oy + ay);
                float p1x = (float)(ox + c1x), p1y = (float)(oy + c1y);
                float p2x = (float)(ox + c2x), p2y = (float)(oy + c2y);
                float p3x = (float)(ox + bx),  p3y = (float)(oy + by);
                /* De Casteljau tessellation into 8 line segments. */
                int px = (int)lroundf(p0x), py = (int)lroundf(p0y);
                const int STEPS = 8;
                for (int s = 1; s <= STEPS; s++) {
                    float t = (float)s / (float)STEPS, u = 1.0f - t;
                    float uu = u * u, tt = t * t;
                    float w0 = uu * u, w1 = 3.0f * uu * t, w2 = 3.0f * u * tt, w3 = tt * t;
                    int nx = (int)lroundf(w0*p0x + w1*p1x + w2*p2x + w3*p3x);
                    int ny = (int)lroundf(w0*p0y + w1*p1y + w2*p2y + w3*p3y);
                    raw_line(px, py, nx, ny, b);
                    px = nx; py = ny;
                }
                cx = px; cy = py;
                continue;
            }

            /* line segment: marker (0xFF) then dy, dx */
            int dy = (int8_t)p[0];
            int dx = (int8_t)p[1];
            p += 2;
            if (mirror) dx = -dx;
            int nx = cx + dx, ny = cy + dy;
            raw_line(cx, cy, nx, ny, b);
            cx = nx; cy = ny;
        }
    }
}

void vpy_draw_vector(const unsigned char *data, int x, int y)
{
    draw_vec_stream(data, x, y, 0, 0);
}

void vpy_draw_vector_ex(const unsigned char *data, int x, int y, int mirror, int intensity)
{
    draw_vec_stream(data, x, y, mirror ? 1 : 0, intensity);
}

/* ---- vector font: glyphs on a 0..4 (w) x 0..6 (h) grid, +Y up ---- */
typedef struct { const int8_t *seg; uint8_t nseg; } Glyph;
#define GLYPH(v) { v, (uint8_t)(sizeof(v) / 4) }

static const int8_t f_sp[] = { 0 };
static const int8_t f_0[] = { 0,0,4,0, 4,0,4,6, 4,6,0,6, 0,6,0,0, 0,0,4,6 };
static const int8_t f_1[] = { 2,0,2,6, 0,4,2,6 };
static const int8_t f_2[] = { 0,6,4,6, 4,6,4,3, 4,3,0,3, 0,3,0,0, 0,0,4,0 };
static const int8_t f_3[] = { 0,6,4,6, 4,6,4,0, 4,0,0,0, 0,3,4,3 };
static const int8_t f_4[] = { 0,6,0,3, 0,3,4,3, 4,6,4,0 };
static const int8_t f_5[] = { 4,6,0,6, 0,6,0,3, 0,3,4,3, 4,3,4,0, 4,0,0,0 };
static const int8_t f_6[] = { 4,6,0,6, 0,6,0,0, 0,0,4,0, 4,0,4,3, 4,3,0,3 };
static const int8_t f_7[] = { 0,6,4,6, 4,6,2,0 };
static const int8_t f_8[] = { 0,0,4,0, 4,0,4,6, 4,6,0,6, 0,6,0,0, 0,3,4,3 };
static const int8_t f_9[] = { 4,0,4,6, 4,6,0,6, 0,6,0,3, 0,3,4,3 };
static const int8_t f_A[] = { 0,0,2,6, 2,6,4,0, 1,2,3,2 };
static const int8_t f_B[] = { 0,0,0,6, 0,6,4,6, 4,6,4,3, 4,3,0,3, 4,3,4,0, 4,0,0,0 };
static const int8_t f_C[] = { 4,6,0,6, 0,6,0,0, 0,0,4,0 };
static const int8_t f_D[] = { 0,0,0,6, 0,6,3,6, 3,6,4,5, 4,5,4,1, 4,1,3,0, 3,0,0,0 };
static const int8_t f_E[] = { 4,6,0,6, 0,6,0,0, 0,0,4,0, 0,3,3,3 };
static const int8_t f_F[] = { 4,6,0,6, 0,6,0,0, 0,3,3,3 };
static const int8_t f_G[] = { 4,6,0,6, 0,6,0,0, 0,0,4,0, 4,0,4,3, 4,3,2,3 };
static const int8_t f_H[] = { 0,0,0,6, 4,0,4,6, 0,3,4,3 };
static const int8_t f_I[] = { 0,6,4,6, 2,6,2,0, 0,0,4,0 };
static const int8_t f_J[] = { 4,6,4,0, 4,0,0,0, 0,0,0,2 };
static const int8_t f_K[] = { 0,0,0,6, 4,6,0,3, 0,3,4,0 };
static const int8_t f_L[] = { 0,6,0,0, 0,0,4,0 };
static const int8_t f_M[] = { 0,0,0,6, 0,6,2,3, 2,3,4,6, 4,6,4,0 };
static const int8_t f_N[] = { 0,0,0,6, 0,6,4,0, 4,0,4,6 };
static const int8_t f_O[] = { 0,0,4,0, 4,0,4,6, 4,6,0,6, 0,6,0,0 };
static const int8_t f_P[] = { 0,0,0,6, 0,6,4,6, 4,6,4,3, 4,3,0,3 };
static const int8_t f_Q[] = { 0,0,4,0, 4,0,4,6, 4,6,0,6, 0,6,0,0, 2,2,4,0 };
static const int8_t f_R[] = { 0,0,0,6, 0,6,4,6, 4,6,4,3, 4,3,0,3, 0,3,4,0 };
static const int8_t f_S[] = { 4,6,0,6, 0,6,0,3, 0,3,4,3, 4,3,4,0, 4,0,0,0 };
static const int8_t f_T[] = { 0,6,4,6, 2,6,2,0 };
static const int8_t f_U[] = { 0,6,0,0, 0,0,4,0, 4,0,4,6 };
static const int8_t f_V[] = { 0,6,2,0, 2,0,4,6 };
static const int8_t f_W[] = { 0,6,0,0, 0,0,2,3, 2,3,4,0, 4,0,4,6 };
static const int8_t f_X[] = { 0,0,4,6, 0,6,4,0 };
static const int8_t f_Y[] = { 0,6,2,3, 4,6,2,3, 2,3,2,0 };
static const int8_t f_Z[] = { 0,6,4,6, 4,6,0,0, 0,0,4,0 };
static const int8_t f_lp[] = { 3,6,1,4, 1,4,1,2, 1,2,3,0 };   /* ( */
static const int8_t f_rp[] = { 1,6,3,4, 3,4,3,2, 3,2,1,0 };   /* ) */
static const int8_t f_min[] = { 1,3,3,3 };                    /* - */
static const int8_t f_dot[] = { 1,0,2,0 };                    /* . */
static const int8_t f_com[] = { 2,1,1,-1 };                   /* , */
static const int8_t f_col[] = { 2,1,2,2, 2,4,2,5 };           /* : */
static const int8_t f_sl[]  = { 0,0,4,6 };                    /* / */
static const int8_t f_ex[]  = { 2,6,2,2, 2,0,2,1 };           /* ! */
static const int8_t f_q[]   = { 0,5,2,6, 2,6,4,5, 4,5,2,3, 2,3,2,2, 2,0,2,1 }; /* ? */

static const Glyph *glyph_for(char c)
{
    static const Glyph G_SP = GLYPH(f_sp);
    static const Glyph digits[10] = {
        GLYPH(f_0),GLYPH(f_1),GLYPH(f_2),GLYPH(f_3),GLYPH(f_4),
        GLYPH(f_5),GLYPH(f_6),GLYPH(f_7),GLYPH(f_8),GLYPH(f_9) };
    static const Glyph letters[26] = {
        GLYPH(f_A),GLYPH(f_B),GLYPH(f_C),GLYPH(f_D),GLYPH(f_E),GLYPH(f_F),
        GLYPH(f_G),GLYPH(f_H),GLYPH(f_I),GLYPH(f_J),GLYPH(f_K),GLYPH(f_L),
        GLYPH(f_M),GLYPH(f_N),GLYPH(f_O),GLYPH(f_P),GLYPH(f_Q),GLYPH(f_R),
        GLYPH(f_S),GLYPH(f_T),GLYPH(f_U),GLYPH(f_V),GLYPH(f_W),GLYPH(f_X),
        GLYPH(f_Y),GLYPH(f_Z) };
    static const Glyph g_lp = GLYPH(f_lp), g_rp = GLYPH(f_rp), g_min = GLYPH(f_min),
        g_dot = GLYPH(f_dot), g_com = GLYPH(f_com), g_col = GLYPH(f_col),
        g_sl = GLYPH(f_sl), g_ex = GLYPH(f_ex), g_q = GLYPH(f_q);

    if (c >= '0' && c <= '9') return &digits[c - '0'];
    if (c >= 'A' && c <= 'Z') return &letters[c - 'A'];
    if (c >= 'a' && c <= 'z') return &letters[c - 'a'];
    switch (c) {
        case ' ': return &G_SP;
        case '(': return &g_lp;  case ')': return &g_rp;
        case '-': return &g_min; case '.': return &g_dot;
        case ',': return &g_com; case ':': return &g_col;
        case '/': return &g_sl;  case '!': return &g_ex;
        case '?': return &g_q;
    }
    return &G_SP;
}

void vpy_set_text_size(int s) { s_text_size = (s < 1) ? 1 : s; }

void vpy_print_text(int x, int y, const char *s)
{
    int sz = s_text_size;
    for (; *s; s++) {
        const Glyph *g = glyph_for(*s);
        for (int i = 0; i < g->nseg; i++) {
            const int8_t *p = &g->seg[i * 4];
            raw_line(x + p[0] * sz, y + p[1] * sz, x + p[2] * sz, y + p[3] * sz, s_intensity);
        }
        x += 5 * sz;   /* advance: 4-wide glyph + 1 gap */
    }
}

void vpy_print_number(int x, int y, long n)
{
    char buf[16];
    int i = 0;
    if (n < 0) { buf[i++] = '-'; n = -n; }
    char digs[12]; int d = 0;
    if (n == 0) digs[d++] = '0';
    while (n > 0 && d < 12) { digs[d++] = (char)('0' + (n % 10)); n /= 10; }
    while (d > 0) buf[i++] = digs[--d];
    buf[i] = 0;
    vpy_print_text(x, y, buf);
}

/* ---- input ---- */
int vpy_j1_x(void) { return s_jx; }
int vpy_j1_y(void) { return s_jy; }
int vpy_j1_button(int n) { return (n >= 1 && n <= 4) ? ((s_btn >> (n - 1)) & 1) : 0; }

/* ---- math ---- */
int vpy_abs(int v) { return v < 0 ? -v : v; }
int vpy_min(int a, int b) { return a < b ? a : b; }
int vpy_max(int a, int b) { return a > b ? a : b; }
int vpy_clamp(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }
int vpy_sin(int a) { ensure_tables(); return s_sin[((a % 128) + 128) & 127]; }
int vpy_cos(int a) { ensure_tables(); return s_sin[(((a % 128) + 128) + 32) & 127]; }
int vpy_sqrt(int v) { return v <= 0 ? 0 : (int)lroundf(sqrtf((float)v)); }
int vpy_atan2(int y, int x) {
    float a = atan2f((float)y, (float)x);   /* -pi..pi */
    int t = (int)lroundf(a * 128.0f / 6.2831853f);
    return ((t % 128) + 128) & 127;
}
void vpy_seed(unsigned s) { s_rng = s ? s : 1; }
int vpy_rand(void) { s_rng = s_rng * 1103515245u + 12345u; return (int)((s_rng >> 16) & 0x7fff); }
int vpy_rand_range(int lo, int hi) {
    if (hi <= lo) return lo;
    return lo + vpy_rand() % (hi - lo + 1);
}

/* ---- sound ---- */
void vpy_tone(int period, int volume)
{
    if (volume <= 0) { v_setSoundAY(8, 0x00); return; }
    v_setSoundAY(0, period & 0xff);
    v_setSoundAY(1, (period >> 8) & 0x0f);
    v_setSoundAY(8, volume & 0x0f);
    v_setSoundAY(7, 0x3e);           /* enable tone A only */
}
void vpy_beep(int on) { if (on) vpy_tone(0xD5, 0x0f); else vpy_tone(0, 0); }

/* ---- compiled music / SFX sequencer -----------------------------------------
 * Plays a compiled PSG event stream (see compile-asset). Byte format (LE):
 *   MUSIC: [0..4]=num_events, [4..8]=loop_event_byte_offset, events at base+8.
 *   SFX:   [0..4]=num_events, events at base+4.
 *   event = [delay, num_writes, (reg,val)*num_writes]
 *          num_writes==0xFF -> loop (music), ==0 -> end.
 * Sequencer model (mirrors the ARM pitrex_music_update / pitrex_sfx_update):
 *   the FIRST event fires immediately (delay starts 0); each event's own delay
 *   byte is the wait BEFORE the NEXT event, read after the current one fires. */

static const unsigned char *s_mus_base = 0;   /* stream base (for loop) */
static const unsigned char *s_mus_ptr  = 0;   /* cursor: current event */
static int s_mus_playing = 0;
static int s_mus_delay   = 0;                  /* frames left before next event */

static const unsigned char *s_sfx_ptr = 0;
static int s_sfx_active = 0;
static int s_sfx_delay  = 0;

/* Shadow of PSG mixer reg 7 so SFX (channel C) can read-modify-write it without
 * silencing music on channels A/B (the ARM runtime read-modify-writes reg 7). */
static uint8_t s_psg_mixer = 0x3f;

static uint32_t rd_le32(const unsigned char *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8)
         | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

/* Write a PSG register, tracking the mixer shadow. */
static void psg_write(uint8_t reg, uint8_t val)
{
    if (reg == 7) s_psg_mixer = val;
    v_setSoundAY(reg, val);
}

void vpy_play_music(const unsigned char *data)
{
    if (!data) return;
    /* Guard: same track already playing -> no-op (prevents per-frame restart). */
    if (s_mus_playing && s_mus_base == data) return;
    s_mus_base    = data;
    s_mus_ptr     = data + 8;   /* first event follows the 8-byte header */
    s_mus_playing = 1;
    s_mus_delay   = 0;          /* first event fires immediately */
}

void vpy_stop_music(void)
{
    s_mus_playing = 0;
    psg_write(8, 0);            /* channel A volume */
    psg_write(9, 0);            /* channel B volume */
    psg_write(10, 0);           /* channel C volume */
    psg_write(7, 0x3f);         /* mixer: all disabled */
}

void vpy_music_update(void)
{
    if (!s_mus_playing || !s_mus_ptr) return;
    if (s_mus_delay > 0) { s_mus_delay--; return; }

    const unsigned char *p = s_mus_ptr;
    uint8_t num_writes = p[1];

    if (num_writes == 0x00) {          /* end marker */
        vpy_stop_music();
        return;
    }
    if (num_writes == 0xff) {          /* loop marker */
        uint32_t off = rd_le32(s_mus_base + 4);
        s_mus_ptr   = s_mus_base + off;
        s_mus_delay = s_mus_ptr[0];    /* delay of the loop-start event */
        return;
    }

    /* Fire this event: write each (reg,val) pair. */
    const unsigned char *w = p + 2;
    for (uint8_t i = 0; i < num_writes; i++) {
        psg_write(w[0], w[1]);
        w += 2;
    }
    /* Advance to next event; its delay byte is the wait before it fires. */
    s_mus_ptr   = w;
    s_mus_delay = w[0];
}

void vpy_play_sfx(const unsigned char *data)
{
    if (!data) return;
    s_sfx_ptr    = data + 4;   /* first event follows the 4-byte header */
    s_sfx_active = 1;
    s_sfx_delay  = 0;
}

void vpy_sfx_update(void)
{
    if (!s_sfx_active || !s_sfx_ptr) return;
    if (s_sfx_delay > 0) { s_sfx_delay--; return; }

    const unsigned char *p = s_sfx_ptr;
    uint8_t num_writes = p[1];

    if (num_writes == 0x00) {          /* end of SFX */
        psg_write(10, 0);              /* mute channel C */
        s_sfx_active = 0;
        return;
    }

    const unsigned char *w = p + 2;
    for (uint8_t i = 0; i < num_writes; i++) {
        uint8_t reg = w[0], val = w[1];
        if (reg == 7) {
            /* Merge only channel-C mixer bits (0x24) from the SFX; keep the
             * music's A/B bits from the current mixer shadow. */
            val = (uint8_t)((s_psg_mixer & 0xdb) | (val & 0x24));
        }
        psg_write(reg, val);
        w += 2;
    }
    s_sfx_ptr   = w;
    s_sfx_delay = w[0];
}
