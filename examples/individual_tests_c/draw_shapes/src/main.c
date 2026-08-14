/* draw_shapes — C port of examples/individual_tests/draw_shapes (VPy).
 * VPy DRAW_POLYGON(n_sides, intensity, x0,y0,...) maps to the vpy.h
 * vpy_draw_polygon(xy[], n, b) contract; DRAW_ARC is skipped (commented
 * out in the original and not provided by the vpy.h runtime). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { }

static void loop(void)
{
    /* Top-left: triangle */
    static const int tri[] = { -50, 50, -30, 50, -40, 70 };
    vpy_draw_polygon(tri, 3, 80);

    /* Top-right: filled rectangle */
    DRAW_FILLED_RECT(30, 50, 30, 20, 80);

    /* Bottom-left: ellipse (cx, cy, rx, ry, intensity) */
    DRAW_ELLIPSE(-40, -30, 25, 15, 80);
}

int main(void) { vpy_run(setup, loop); return 0; }
