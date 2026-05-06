/*
 * pitrex_bezier.c — Smooth curve drawing for PiTrex/Vectrex
 *
 * Provides v_drawBezierCubic, v_drawBezierQuad, v_directDrawPolyline.
 *
 * Each function decomposes the curve into small line segments and calls
 * v_directDraw32 for each sub-segment. To avoid the "beam off/on at every
 * vertex" behaviour caused by beamOffBetweenConsecutiveDraws=1 (the SDK
 * default), we set that flag to 0 so handlePipeline() keeps the beam lit
 * continuously across all sub-segments.
 *
 * BEZIER_TRACE: define to enable UART diagnostics (prints every ~50 frames).
 *
 * Include path: -I<sdk>/pitrex/  (resolves vectrex/vectrexInterface.h)
 */

#include "vectrex/vectrexInterface.h"

/* beamOffBetweenConsecutiveDraws is declared as extern uint8_t in vectrexInterface.h */

/* ---- de Casteljau helpers ---- */

static int32_t dc_lerp(int32_t a, int32_t b, int i, int steps)
{
    return ((int32_t)(steps - i) * a + (int32_t)i * b) / steps;
}

static int32_t dc_cubic(int32_t p0, int32_t p1, int32_t p2, int32_t p3, int i, int steps)
{
    int32_t q0 = dc_lerp(p0, p1, i, steps);
    int32_t q1 = dc_lerp(p1, p2, i, steps);
    int32_t q2 = dc_lerp(p2, p3, i, steps);
    int32_t r0 = dc_lerp(q0, q1, i, steps);
    int32_t r1 = dc_lerp(q1, q2, i, steps);
    return dc_lerp(r0, r1, i, steps);
}

static int32_t dc_quad(int32_t p0, int32_t p1, int32_t p2, int i, int steps)
{
    int32_t q0 = dc_lerp(p0, p1, i, steps);
    int32_t q1 = dc_lerp(p1, p2, i, steps);
    return dc_lerp(q0, q1, i, steps);
}

/*
 * VPy coords are in the range +-127. pitrex_draw_line scales by 127 before
 * calling v_directDraw32. We apply the same scale here so all drawing
 * functions use the same coordinate space.
 */
#define BEZIER_VPY_SCALE 127

/* ---- Public API ---- */

void v_drawBezierCubic(int32_t x0, int32_t y0, int32_t cx0, int32_t cy0,
                        int32_t cx1, int32_t cy1, int32_t x1, int32_t y1,
                        int steps, uint8_t brightness)
{
    if (brightness == 0) return;
    if (steps < 2) steps = 2;
    if (steps > 64) steps = 64;

    x0  *= BEZIER_VPY_SCALE;  y0  *= BEZIER_VPY_SCALE;
    cx0 *= BEZIER_VPY_SCALE;  cy0 *= BEZIER_VPY_SCALE;
    cx1 *= BEZIER_VPY_SCALE;  cy1 *= BEZIER_VPY_SCALE;
    x1  *= BEZIER_VPY_SCALE;  y1  *= BEZIER_VPY_SCALE;

    /* Keep beam on between all sub-segments of this curve.
     * beamOffBetweenConsecutiveDraws=1 (SDK default) causes a PL_SWITCH_BEAM_OFF
     * between each v_directDraw32 call, producing visible dots at every vertex.
     * Setting it to 0 here keeps the beam lit continuously for all segments.
     * It must be 0 when handlePipeline() reads it at v_WaitRecal time. */
    beamOffBetweenConsecutiveDraws = 0;

    int32_t prev_x = x0, prev_y = y0;
    for (int i = 1; i <= steps; i++) {
        int32_t px = dc_cubic(x0, cx0, cx1, x1, i, steps);
        int32_t py = dc_cubic(y0, cy0, cy1, y1, i, steps);
        v_directDraw32(prev_x, prev_y, px, py, brightness);
        prev_x = px;
        prev_y = py;
    }
}

void v_drawBezierQuad(int32_t x0, int32_t y0, int32_t cx, int32_t cy,
                       int32_t x1, int32_t y1, int steps, uint8_t brightness)
{
    if (brightness == 0) return;
    if (steps < 2) steps = 2;
    if (steps > 64) steps = 64;

    x0 *= BEZIER_VPY_SCALE;  y0 *= BEZIER_VPY_SCALE;
    cx *= BEZIER_VPY_SCALE;  cy *= BEZIER_VPY_SCALE;
    x1 *= BEZIER_VPY_SCALE;  y1 *= BEZIER_VPY_SCALE;

    beamOffBetweenConsecutiveDraws = 0;

    int32_t prev_x = x0, prev_y = y0;
    for (int i = 1; i <= steps; i++) {
        int32_t px = dc_quad(x0, cx, x1, i, steps);
        int32_t py = dc_quad(y0, cy, y1, i, steps);
        v_directDraw32(prev_x, prev_y, px, py, brightness);
        prev_x = px;
        prev_y = py;
    }
}

void v_directDrawPolyline(const int32_t *xs, const int32_t *ys, int n, uint8_t brightness)
{
    if (n < 2 || brightness == 0) return;

    beamOffBetweenConsecutiveDraws = 0;

    for (int i = 1; i < n; i++) {
        v_directDraw32(xs[i-1], ys[i-1], xs[i], ys[i], brightness);
    }
}
