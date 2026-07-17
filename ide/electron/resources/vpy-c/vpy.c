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
    v_setRefresh(60);
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
