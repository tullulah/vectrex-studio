/*
 * pitrex_bezier.c — Smooth curve drawing for PiTrex/Vectrex
 *
 * Provides v_drawBezierCubic, v_drawBezierQuad, v_directDrawPolyline.
 *
 * Each function decomposes the curve into small line segments and calls
 * v_directDraw32 for each one. This integrates correctly with PiTrex's
 * pipeline system: v_directDraw32 buffers vectors, which displayPipeline()
 * draws at the right time during v_WaitRecal. The smoothness comes from
 * using many small steps (16 per 90° segment = 64 steps per full circle).
 *
 * Coordinates are passed in VPy space and scaled by BEZIER_VPY_SCALE (127)
 * to match the same convention pitrex_draw_line uses before calling
 * v_directDraw32. v_directDraw32 handles sizeX/sizeY/offsetX/offsetY
 * and orientation internally.
 *
 * Include path: -I<sdk>/pitrex/  (resolves vectrex/vectrexInterface.h)
 */

#include "vectrex/vectrexInterface.h"

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
 * VPy coords are in the range ±127. pitrex_draw_line scales by 127 before
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

    for (int i = 1; i < n; i++) {
        v_directDraw32(xs[i-1], ys[i-1], xs[i], ys[i], brightness);
    }
}
