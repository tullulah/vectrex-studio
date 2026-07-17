/* draw_circle — C port of examples/individual_tests/draw_circle (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static int radius = 20;

static void setup(void) { radius = 20; }

static void loop(void)
{
    DRAW_CIRCLE(0, 0, 15, 80);
    DRAW_CIRCLE(-60, 0, 10, 80);
    DRAW_CIRCLE(60, 0, radius, 80);
    DRAW_CIRCLE(0, 60, 15, 80);

    radius = radius + 1;
    if (radius > 20) radius = 5;
}

int main(void) { vpy_run(setup, loop); return 0; }
