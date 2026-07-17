/*
 * vpy.c — implementation of the VPy builtin runtime on the PiTrex SDK contract.
 * See vpy.h. Everything routes through v_directDraw32 / v_writePSG etc., so it
 * behaves identically on real hardware and in the IDE simulator.
 */
#include "vpy.h"
#include <vectrex/vectrexInterface.h>
/* No <math.h>: libvpy is integer-only so it compiles to plain integer ARM that
 * both real hardware and the VPy sim (PitrexCore's ARMv6 interpreter) can run. */

#define VPY_SCALE 127   /* VPy logical unit -> PiTrex deflection unit */

/* ---- state ---- */
static int   s_cur_x = 0, s_cur_y = 0;   /* MOVE origin, in VPy units */
static int   s_intensity = 90;
static int   s_text_size = 8;   /* matches inline PITREX_TEXT_SIZE default (0 -> 8) */
static uint32_t s_rng = 0u;   /* matches the inline RAND_SEED (zeroed .bss) */

/* sin table: 128 steps per full circle, amplitude +-127 (compile-time const). */
static const int8_t s_sin[128] = {
       0,   6,  12,  19,  25,  31,  37,  43,  49,  54,  60,  65,  71,  76,  81,  85,
      90,  94,  98, 102, 106, 109, 112, 115, 117, 120, 122, 123, 125, 126, 126, 127,
     127, 127, 126, 126, 125, 123, 122, 120, 117, 115, 112, 109, 106, 102,  98,  94,
      90,  85,  81,  76,  71,  65,  60,  54,  49,  43,  37,  31,  25,  19,  12,   6,
       0,  -6, -12, -19, -25, -31, -37, -43, -49, -54, -60, -65, -71, -76, -81, -85,
     -90, -94, -98,-102,-106,-109,-112,-115,-117,-120,-122,-123,-125,-126,-126,-127,
    -127,-127,-126,-126,-125,-123,-122,-120,-117,-115,-112,-109,-106,-102, -98, -94,
     -90, -85, -81, -76, -71, -65, -60, -54, -49, -43, -37, -31, -25, -19, -12,  -6,
};
/* atan LUT for the integer atan2 octant — ported BIT-EXACT from the VPy PiTrex
 * inline codegen (`pitrex_atan_lut` in vpy_codegen builtins.rs). 33 entries map a
 * ratio 0..32 (= |smaller|*32/|larger|) to an octant angle 0..22. This is the
 * SAME quantized table the inline `pitrex_atan2` uses, so vpy_atan2 reproduces it
 * exactly (the inline's 45deg endpoint is 22, NOT the ideal 16 — matched on
 * purpose for bit-identical output). */
static const uint8_t s_atan[33] = {
    0,1,2,3,4,5,6,7,8,8,9,10,11,12,12,13,14,14,15,15,16,17,17,18,18,19,19,20,20,20,21,21,22
};

static void ensure_tables(void) { /* tables are compile-time const now */ }

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
    v_readButtons();          /* refresh currentButtonState */
    v_readJoystick1Analog();  /* refresh currentJoy1X / currentJoy1Y */
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
                int P0x = ox + ax,  P0y = oy + ay;
                int P1x = ox + c1x, P1y = oy + c1y;
                int P2x = ox + c2x, P2y = oy + c2y;
                int P3x = ox + bx,  P3y = oy + by;
                /* Integer De Casteljau into 8 line segments (repeated lerp). */
                int px = P0x, py = P0y;
                const int STEPS = 8;
                for (int t = 1; t <= STEPS; t++) {
                    int abx = P0x + (P1x-P0x)*t/STEPS, aby = P0y + (P1y-P0y)*t/STEPS;
                    int bcx = P1x + (P2x-P1x)*t/STEPS, bcy = P1y + (P2y-P1y)*t/STEPS;
                    int cdx = P2x + (P3x-P2x)*t/STEPS, cdy = P2y + (P3y-P2y)*t/STEPS;
                    int abc_x = abx + (bcx-abx)*t/STEPS, abc_y = aby + (bcy-aby)*t/STEPS;
                    int bcd_x = bcx + (cdx-bcx)*t/STEPS, bcd_y = bcy + (cdy-bcy)*t/STEPS;
                    int nx = abc_x + (bcd_x-abc_x)*t/STEPS, ny = abc_y + (bcd_y-abc_y)*t/STEPS;
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

/* ---- SDK vector font (ported from pitrex-baremetal vectorFont.i, the ACTIVE
 * BLOW_UP=15 table) ---------------------------------------------------------
 * This is the SAME font the inline PiTrex path renders via v_printString, so
 * PRINT_TEXT looks identical on hardware, the C-import WASM sim, and the VPy
 * PitrexCore sim — all drawn through v_directDraw32 (we do NOT add
 * v_printString to the SDK contract).
 *
 * Each glyph is a stream of [pattern, dy, dx] signed-byte triples (the dy/dx
 * deltas are already ×BLOW_UP=15), terminated by a lone 0x01. Reproducing
 * v_printString's pipeline:
 *   pattern != 0  -> draw a stroke  cursor -> cursor + delta*SCALEFONT
 *   pattern == 0  -> move only (no beam), advance the cursor
 * with SCALEFONT = textSize*1.5. The loop continues while the NEXT entry's
 * pattern byte is <= 0; the 0x01 endmarker (positive) stops it. The trailing
 * move in each glyph bakes in the inter-character advance. */
static const signed char F_Folder[] = {-1,120,0,-1,0,60,-1,-60,0,0,0,-15,-1,-60,0,0,0,30,-1,45,0,-1,15,-15,-1,0,-15,0,-60,-45,-1,0,75,0,0,15,1};
static const signed char F_ABC_0[] = {-1,45,0,-1,45,0,-1,30,30,-1,-30,30,-1,-45,0,-1,0,-60,0,0,60,-1,-45,0,0,0,30,1};
static const signed char F_ABC_1[] = {-1,120,0,-1,0,30,-1,-15,30,-1,-30,-15,0,0,-45,-1,0,45,-1,-45,15,-1,-30,-30,-1,0,-30,0,0,90,1};
static const signed char F_ABC_2[] = {0,120,60,-1,0,-60,-1,-120,0,-1,0,60,0,0,30,1};
static const signed char F_ABC_3[] = {-1,120,0,-1,0,30,-1,-45,30,-1,-30,0,-1,-45,-30,-1,0,-30,0,0,90,1};
static const signed char F_ABC_4[] = {0,120,60,-1,0,-60,-1,-45,0,0,0,60,-1,0,-60,-1,-75,0,-1,0,60,0,0,30,1};
static const signed char F_ABC_5[] = {-1,75,0,-1,0,60,0,0,-60,-1,45,0,-1,0,60,0,-120,30,1};
static const signed char F_ABC_6[] = {0,105,60,-1,15,0,-1,0,-60,-1,-120,0,-1,0,60,-1,75,0,-1,0,-30,0,-75,60,1};
static const signed char F_ABC_7[] = {-1,120,0,0,-45,0,-1,0,60,0,45,0,-1,-120,0,0,0,30,1};
static const signed char F_ABC_8[] = {-1,0,60,0,0,-30,-1,120,0,0,0,-30,-1,0,60,0,-120,30,1};
static const signed char F_ABC_9[] = {0,30,0,-1,-30,15,-1,0,45,-1,120,0,-1,0,-30,0,-120,60,1};
static const signed char F_ABC_10[] = {-1,120,0,0,-45,0,-1,45,60,0,-45,-60,-1,-75,60,0,0,30,1};
static const signed char F_ABC_11[] = {0,120,0,-1,-120,0,-1,0,60,0,0,30,1};
static const signed char F_ABC_12[] = {-1,120,0,-1,-45,30,-1,45,30,-1,-120,0,0,0,30,1};
static const signed char F_ABC_13[] = {-1,120,0,-1,-120,60,-1,120,0,0,-120,30,1};
static const signed char F_ABC_14[] = {0,0,0,-1,120,0,-1,0,60,-1,-120,0,-1,0,-60,0,0,90,1};
static const signed char F_ABC_15[] = {-1,120,0,-1,0,60,-1,-45,0,-1,0,-60,0,-75,90,1};
static const signed char F_ABC_16[] = {0,0,30,-1,0,-30,-1,120,0,-1,0,60,-1,-90,0,-1,-30,-30,0,30,0,-1,-30,30,0,0,30,1};
static const signed char F_ABC_17[] = {-1,120,0,-1,0,60,-1,-45,0,-1,0,-60,-1,-75,60,0,0,30,1};
static const signed char F_ABC_18[] = {0,120,60,-1,0,-60,-1,-45,0,-1,0,60,-1,-75,0,-1,0,-60,0,0,90,1};
static const signed char F_ABC_19[] = {0,0,30,-1,120,0,0,0,-30,-1,0,60,0,-120,30,1};
static const signed char F_ABC_20[] = {0,120,0,-1,-120,0,-1,0,60,-1,120,0,0,-120,30,1};
static const signed char F_ABC_21[] = {0,120,0,-1,-120,30,-1,120,30,0,-120,30,1};
static const signed char F_ABC_22[] = {0,120,0,-1,-120,0,-1,45,30,-1,-45,30,-1,120,0,0,-120,30,1};
static const signed char F_ABC_23[] = {-1,120,60,0,0,-60,-1,-120,60,0,0,30,1};
static const signed char F_ABC_24[] = {0,120,0,-1,-45,30,-1,45,30,0,-45,-30,-1,-75,0,0,0,60,1};
static const signed char F_ABC_25[] = {0,120,0,-1,0,60,-1,-120,-60,-1,0,60,0,0,30,1};
static const signed char F_ABC_26[] = {-1,0,30,-1,30,0,-1,0,-30,-1,-30,0,0,0,90,1};
static const signed char F_ABC_27[] = {0,0,90,1};
static const signed char F_ABC_28[] = {-1,0,30,-1,30,0,-1,0,-30,-1,-30,0,0,45,15,-1,75,0,0,-120,60,1};
static const signed char F_ABC_29[] = {0,120,45,-1,-120,0,0,0,45,1};
static const signed char F_ABC_30[] = {0,120,0,-1,0,60,-1,-45,0,-1,0,-60,-1,-75,0,-1,0,60,0,0,30,1};
static const signed char F_ABC_31[] = {0,120,0,-1,0,60,-1,-45,0,-1,0,-60,0,0,60,-1,-75,0,-1,0,-60,0,0,90,1};
static const signed char F_ABC_32[] = {0,0,60,-1,120,0,0,0,-60,-1,-45,0,-1,0,60,0,-75,30,1};
static const signed char F_ABC_33[] = {-1,0,60,-1,75,0,-1,0,-60,-1,45,0,-1,0,60,0,-120,30,1};
static const signed char F_ABC_34[] = {-1,120,0,-1,0,60,0,-45,-60,-1,0,60,-1,-75,0,-1,0,-60,0,0,90,1};
static const signed char F_ABC_35[] = {0,0,60,-1,120,0,-1,0,-60,0,-120,90,1};
static const signed char F_ABC_36[] = {-1,120,0,-1,0,60,-1,-120,0,-1,0,-60,0,75,0,-1,0,60,0,-75,30,1};
static const signed char F_ABC_37[] = {0,75,60,-1,0,-60,-1,45,0,-1,0,60,-1,-120,0,0,0,30,1};
static const signed char F_ABC_38[] = {-1,120,0,-1,0,60,-1,-120,0,-1,0,-60,0,0,90,1};
static const signed char F_ABC_39[] = {0,30,15,-1,30,-15,-1,30,15,0,-30,45,-1,0,-60,0,-60,90,1};
static const signed char F_ABC_40[] = {0,60,0,-1,0,60,-1,30,-15,0,-60,0,-1,30,15,0,-60,30,1};

/* ASCII(0x20..)->glyph pointer, exactly as the SDK ABC[] index. */
static const signed char *const FONT_ABC[143] = {
    F_ABC_27,F_ABC_28,F_ABC_27,F_ABC_27,F_Folder,F_ABC_27,F_ABC_27,F_ABC_27,
    F_ABC_27,F_ABC_27,F_ABC_27,F_ABC_27,F_ABC_27,F_ABC_27,F_ABC_26,F_ABC_27,
    F_ABC_38,F_ABC_29,F_ABC_30,F_ABC_31,F_ABC_32,F_ABC_33,F_ABC_34,F_ABC_35,
    F_ABC_36,F_ABC_37,F_ABC_27,F_ABC_27,F_ABC_39,F_ABC_27,F_ABC_40,F_ABC_27,
    F_ABC_27,F_ABC_0,F_ABC_1,F_ABC_2,F_ABC_3,F_ABC_4,F_ABC_5,F_ABC_6,
    F_ABC_7,F_ABC_8,F_ABC_9,F_ABC_10,F_ABC_11,F_ABC_12,F_ABC_13,F_ABC_14,
    F_ABC_15,F_ABC_16,F_ABC_17,F_ABC_18,F_ABC_19,F_ABC_20,F_ABC_21,F_ABC_22,
    F_ABC_23,F_ABC_24,F_ABC_25,F_ABC_27,F_ABC_27,F_ABC_27,F_ABC_27,F_ABC_27,
    F_ABC_27,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
    F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
    F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
    F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
    F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
    F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
    F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
    F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
    F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
    F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,F_ABC_26,
};
#define FONT_ABC_N 143

/* toupper + range-map to a glyph pointer, exactly like the SDK ABC[] lookup
 * (`ABC[toupper(*string)-0x20]`); out-of-range chars fall back to space. */
static const signed char *font_glyph(unsigned char c)
{
    if (c >= 'a' && c <= 'z') c -= 32;
    int idx = (int)c - 0x20;
    if (idx < 0 || idx >= FONT_ABC_N) idx = 0;   /* -> space (F_ABC_27) */
    return FONT_ABC[idx];
}

/* textSize used by the print routines: SET_TEXT_SIZE value, or 8 by default
 * (matches the inline PITREX_TEXT_SIZE default = m6809 "normal"). */
static int font_text_size(void) { return (s_text_size > 0) ? s_text_size : 8; }

/* Core glyph-stream renderer, reproducing the inline PiTrex print sequence
 * (builtins.rs pitrex_print_text) followed by v_printString's pipeline, but
 * drawing each stroke via v_directDraw32 in raw deflection units:
 *   baseline = y - 8                       (inline cap_height shift, VPy units)
 *   startX   = ((x*127) >> 7) * 128        (inline 127/128 pre-scale, then *128)
 * Each stroke endpoint = trunc(cursor + delta * textSize * 1.5); computed
 * exactly in integer as (cursor*2 + delta*textSize*3) / 2 (C /2 truncates
 * toward zero, matching v_printString's double->int truncation). */
static void font_draw_string(int x, int y, const char *s)
{
    int ts = font_text_size();
    int yb = y - 8;
    int startX = ((x  * 127) >> 7) * 128;
    int startY = ((yb * 127) >> 7) * 128;
    for (; *s; s++) {
        const signed char *list = font_glyph((unsigned char)*s);
        do {
            int pat = list[0];
            int nx = (startX * 2 + (int)list[2] * ts * 3) / 2;
            int ny = (startY * 2 + (int)list[1] * ts * 3) / 2;
            if (pat != 0)
                v_directDraw32(startX, startY, nx, ny, (uint8_t)s_intensity);
            startX = nx;
            startY = ny;
            list += 3;
        } while ((int)list[0] <= 0);
    }
}

void vpy_set_text_size(int s) { s_text_size = s; }

void vpy_print_text(int x, int y, const char *s) { font_draw_string(x, y, s); }

void vpy_print_number(int x, int y, long n)
{
    int ts = font_text_size();
    int neg = (n < 0);
    long v = neg ? -n : n;

    /* Format a fixed 4-digit field (1000s/100s/10s/1s), '-' prefix if negative,
     * exactly like the inline pitrex_print_number buffer layout. */
    char buf[8];
    int i = 0;
    if (neg) buf[i++] = '-';
    buf[i++] = (char)('0' + (int)((v / 1000) % 10));
    buf[i++] = (char)('0' + (int)((v / 100)  % 10));
    buf[i++] = (char)('0' + (int)((v / 10)   % 10));
    buf[i++] = (char)('0' + (int)( v         % 10));
    buf[i]   = 0;

    /* The SDK vector font maps '-' to a blank space glyph, so the inline path
     * draws the minus as a manual horizontal stroke in raw deflection units:
     *   x0 = x*127, x1 = x0 + 8*ts, y = (y-8)*127 + 6*ts. Reproduce it here. */
    if (neg) {
        int x0   = x * 127;
        int ymid = (y - 8) * 127 + 6 * ts;
        v_directDraw32(x0, ymid, x0 + 8 * ts, ymid, (uint8_t)s_intensity);
    }

    /* Leading-zero suppression: the inline scan starts at buf[0]; for negatives
     * that is '-' (not '0') so it stops immediately — i.e. suppression applies
     * to positive values only. Reproduce that quirk for a matching layout. */
    const char *p = buf;
    while (p[0] == '0' && p[1] != 0) p++;
    font_draw_string(x, y, p);
}

/* ---- input ----
 * Read the SDK input globals DIRECTLY. They are refreshed every frame by
 * v_readButtons() / v_readJoystick1Analog() — called by BOTH vpy_frame_begin()
 * (the C vpy_run path) AND the VPy pitrex game loop before the loop body. This
 * makes these functions bit-identical to the inline VPy codegen (pitrex_j1_x/y
 * ldrsb currentJoy1X/Y; pitrex_j1_btnN reads bit N-1 of currentButtonState) and
 * avoids the stale-snapshot bug: the old s_jx/s_jy/s_btn snapshot was only taken
 * by vpy_frame_begin, which the VPy game loop never calls. */
int vpy_j1_x(void) { return (int)currentJoy1X; }
int vpy_j1_y(void) { return (int)currentJoy1Y; }
int vpy_j1_button(int n) { return (n >= 1 && n <= 4) ? ((currentButtonState >> (n - 1)) & 1) : 0; }
void vpy_update_buttons(void) { v_readButtons(); v_readJoystick1Analog(); }

/* ---- math ---- */
int vpy_abs(int v) { return v < 0 ? -v : v; }
int vpy_min(int a, int b) { return a < b ? a : b; }
int vpy_max(int a, int b) { return a > b ? a : b; }
int vpy_clamp(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }
int vpy_sin(int a) { ensure_tables(); return s_sin[((a % 128) + 128) & 127]; }
int vpy_cos(int a) { ensure_tables(); return s_sin[(((a % 128) + 128) + 32) & 127]; }
int vpy_sqrt(int v) {
    if (v <= 0) return 0;
    int x = v, y = (x + 1) / 2;
    while (y < x) { x = y; y = (x + v / x) / 2; }   /* integer Newton */
    return x;
}
/* Integer atan2 -> full-circle angle 0..127. BIT-EXACT port of the VPy PiTrex
 * inline `pitrex_atan2(r0=y, r1=x)`:
 *   octant split on |x| >= |y| (shallow) vs |y| > |x| (steep);
 *   ratio = |smaller| * 32 / |larger| (integer div, truncates toward zero — both
 *   operands non-negative, identical to ARM __aeabi_idiv here);
 *   shallow angle = s_atan[ratio], steep angle = 32 - s_atan[ratio];
 *   then the same quadrant map (Q4 = 128-a) and & 127.
 * The ratio is clamped to 32 to mirror the inline's `cmp/movgt` guard before the
 * table index. */
int vpy_atan2(int y, int x) {
    int ax = x < 0 ? -x : x;
    int ay = y < 0 ? -y : y;
    if (ax == 0 && ay == 0) return 0;
    int a;                                 /* octant angle 0..32 */
    if (ax >= ay) {                        /* shallow: |y| <= |x| (0..45deg) */
        int r = ax ? (ay * 32) / ax : 0;
        if (r > 32) r = 32;
        a = s_atan[r];
    } else {                               /* steep: |y| > |x| (45..90deg) */
        int r = ay ? (ax * 32) / ay : 0;
        if (r > 32) r = 32;
        a = 32 - s_atan[r];
    }
    int ang;
    if      (x >= 0 && y >= 0) ang = a;            /* Q1 */
    else if (x <  0 && y >= 0) ang = 64 - a;       /* Q2 */
    else if (x <  0 && y <  0) ang = 64 + a;       /* Q3 */
    else                        ang = 128 - a;      /* Q4 (x>=0, y<0) */
    return ang & 127;
}

/* PRNG — BIT-EXACT port of the VPy PiTrex inline `pitrex_random`:
 *   state = state * 1664525 + 1013904223  (32-bit wraparound)
 *   output = (state >> 16) & 0xFFFF        (16-bit, 0..65535)
 * The inline seed lives in a zeroed .bss word (RAND_SEED), so the initial state
 * is 0 — s_rng starts at 0 to match, giving an identical sequence from reset. */
void vpy_seed(unsigned s) { s_rng = s; }
int vpy_rand(void) {
    s_rng = s_rng * 1664525u + 1013904223u;
    return (int)((s_rng >> 16) & 0xFFFFu);
}
/* rand_range — BIT-EXACT port of inline `pitrex_rand_range`:
 *   range = hi - lo + 1;  return lo + rand() % range.
 * The inline has no lo/hi guard (it relies on ARM aeabi div-by-zero -> 0 for the
 * degenerate hi < lo case); we guard only the truly-undefined range <= 0 path to
 * avoid C modulo-by-zero UB. For the real contract (hi >= lo) the guard never
 * fires and the result is identical to the inline. */
int vpy_rand_range(int lo, int hi) {
    int range = hi - lo + 1;
    if (range <= 0) return lo;
    return lo + vpy_rand() % range;
}

/* ---- sound ---- */
void vpy_tone(int period, int volume)
{
    if (volume <= 0) { v_writePSG(8, 0x00); return; }
    v_writePSG(0, period & 0xff);
    v_writePSG(1, (period >> 8) & 0x0f);
    v_writePSG(8, volume & 0x0f);
    v_writePSG(7, 0x3e);           /* enable tone A only */
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
    v_writePSG(reg, val);
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

/* ---- compiled levels (.vplay) ------------------------------------------------
 * Interprets the level byte image produced by `vpy_cli compile-asset
 * <file>.vplay --format c`. The layout mirrors the ARM/PiTrex level format
 * (pitrex_load_level / pitrex_show_level / pitrex_update_level) byte-for-byte at
 * the object level, so this is a straight C port of that runtime. The only two
 * differences (a static C array can't hold absolute addresses) are:
 *   - header layer pointers are byte OFFSETS from the image base
 *   - object sprite field is an INDEX into the sprite pointer table supplied to
 *     vpy_load_level (0xFFFFFFFF = no sprite / enemy marker → not drawn here).
 *
 * Header (36 bytes):
 *   +0  xMin i16  +2 xMax i16  +4 yMin i16  +6 yMax i16
 *   +8  bgCount u8 +9 gpCount u8 +10 fgCount u8 +11 pad
 *   +12 bgObjectsOff u32 +16 gpObjectsOff u32 +20 fgObjectsOff u32
 *   +24 scrollLeft i16 +26 scrollRight i16 +28 scrollTop i16 +30 scrollBottom i16
 *   +32 groundBottomOffset i16 +34 pad
 * Object (20 bytes):
 *   +0 x i16 +2 y i16 +4 scale u8 +5 intensity u8 +6 flags u8 +7 type u8
 *   +8 sprite_index u32 +12 half_w u8 +13 half_h u8 +14 vel_x i8 +15 vel_y i8
 *   +16 coll_mesh u32 (unused in C — collision queries deferred)
 * GP mutable buffer entry (8 bytes): x i16, y i16, vx i16, vy i16. */

#define VPY_LEVEL_MAX_GP 64   /* mutable gameplay-object slots */

static const unsigned char       *s_level      = 0;    /* header base */
static const unsigned char *const *s_sprites   = 0;    /* sprite pointer table */
static int  s_cam_x = 0, s_cam_y = 0;
static int  s_gp_count = 0;
static short s_gp_buf[VPY_LEVEL_MAX_GP][4];             /* x, y, vx, vy per GP object */

static int16_t rd_i16(const unsigned char *p) { return (int16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8)); }

void vpy_set_camera_x(int x) { s_cam_x = x; }
void vpy_set_camera_y(int y) { s_cam_y = y; }
int  vpy_get_camera_x(void)  { return s_cam_x; }
int  vpy_get_camera_y(void)  { return s_cam_y; }

void vpy_load_level(const unsigned char *level, const unsigned char *const *sprites)
{
    s_level   = level;
    s_sprites = sprites;
    s_gp_count = 0;
    if (!level) return;

    int gp = level[9];
    if (gp > VPY_LEVEL_MAX_GP) gp = VPY_LEVEL_MAX_GP;
    s_gp_count = gp;

    /* Copy GP object positions/velocities into the mutable buffer (positions
     * mutate via UPDATE_LEVEL; the ROM image stays the source of sprite/type). */
    uint32_t gp_off = rd_le32(level + 16);
    const unsigned char *o = level + gp_off;
    for (int i = 0; i < gp; i++) {
        s_gp_buf[i][0] = rd_i16(o + 0);          /* x */
        s_gp_buf[i][1] = rd_i16(o + 2);          /* y */
        s_gp_buf[i][2] = (short)(int8_t)o[14];   /* vx (init) */
        s_gp_buf[i][3] = (short)(int8_t)o[15];   /* vy (init) */
        o += 20;
    }
}

/* Draw one object: sprite via index, offset by (x - cam_x, y - cam_y), culled
 * to the screen. Mirrors the per-object body of pitrex_show_level. */
static void level_draw_obj(const unsigned char *o, int wx, int wy)
{
    uint32_t sidx = rd_le32(o + 8);
    if (sidx == 0xFFFFFFFFu || !s_sprites) return;        /* no sprite / enemy */
    const unsigned char *sprite = s_sprites[sidx];
    if (!sprite) return;

    int ox = wx - s_cam_x;
    int oy = wy - s_cam_y;
    /* Cull off-screen (13-unit buffer past the ±127 screen edge), like ARM. */
    if (vpy_abs(ox) > 180 || vpy_abs(oy) > 140) return;

    int intensity = o[5];
    vpy_draw_vector_ex(sprite, ox, oy, 0, intensity);
}

void vpy_show_level(void)
{
    const unsigned char *lvl = s_level;
    if (!lvl) return;

    /* BG layer — positions straight from the ROM image. */
    int bg = lvl[8];
    const unsigned char *o = lvl + rd_le32(lvl + 12);
    for (int i = 0; i < bg; i++, o += 20)
        level_draw_obj(o, rd_i16(o + 0), rd_i16(o + 2));

    /* GP layer — positions from the mutable buffer; skip enemy-type objects
     * (type byte == 1), which a future enemy runtime would draw instead. */
    const unsigned char *g = lvl + rd_le32(lvl + 16);
    for (int i = 0; i < s_gp_count; i++, g += 20) {
        if (g[7] == 1) continue;
        level_draw_obj(g, s_gp_buf[i][0], s_gp_buf[i][1]);
    }

    /* FG layer — positions straight from the ROM image. */
    int fg = lvl[10];
    o = lvl + rd_le32(lvl + 20);
    for (int i = 0; i < fg; i++, o += 20)
        level_draw_obj(o, rd_i16(o + 0), rd_i16(o + 2));
}

void vpy_update_level(void)
{
    const unsigned char *lvl = s_level;
    if (!lvl || s_gp_count == 0) return;

    int y_min = rd_i16(lvl + 4);
    int y_max = rd_i16(lvl + 6);
    const unsigned char *o = lvl + rd_le32(lvl + 16);   /* ROM GP (for flags) */

    for (int i = 0; i < s_gp_count; i++, o += 20) {
        unsigned char flags = o[6];
        if (!(flags & 0x01)) continue;                  /* physics disabled */

        int x  = s_gp_buf[i][0];
        int y  = s_gp_buf[i][1];
        int vx = s_gp_buf[i][2];
        int vy = s_gp_buf[i][3];

        if (flags & 0x02) {                             /* gravity */
            vy -= 1;
            if (vy < -32) vy = -32;                      /* clamp fall speed */
        }
        x += vx;
        y += vy;
        if (y < y_min) { y = y_min; vy = 0; }           /* hit floor */
        if (y > y_max) { y = y_max; vy = 0; }           /* hit ceiling */

        s_gp_buf[i][0] = (short)x;
        s_gp_buf[i][1] = (short)y;
        s_gp_buf[i][3] = (short)vy;
    }
}
