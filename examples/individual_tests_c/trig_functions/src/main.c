/* trig_functions — C port of examples/individual_tests/trig_functions (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static int angle = 0;

static void setup(void) { angle = 0; }

static void loop(void)
{
    PRINT_TEXT(-50, 90, "SIN/COS");

    /* sin/cos return -127..127, divide by 3 to get ~40 unit radius */
    int px = vpy_cos(angle) / 3;
    int py = vpy_sin(angle) / 3;

    /* Draw orbiting dot */
    DRAW_CIRCLE(px, py, 5, 120);

    /* Draw center crosshair */
    DRAW_LINE(0, -5, 0, 5, 40);
    DRAW_LINE(-5, 0, 5, 0, 40);

    /* Draw orbit path (faint circle) */
    DRAW_CIRCLE(0, 0, 42, 80);

    /* Advance angle (0..127 = full circle) */
    angle = angle + 1;
    if (angle > 127) angle = 0;
}

int main(void) { vpy_run(setup, loop); return 0; }
