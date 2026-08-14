/* fade_effects — C port of examples/individual_tests/fade_effects (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static int brightness = 100;

static void setup(void) { brightness = 100; }

static void loop(void)
{
    PRINT_TEXT(-60, 90, "BRIGHTNESS");
    PRINT_TEXT(-80, 70, "B1=DIM B2=BRIGHT");

    if (vpy_j1_button(1)) {
        if (brightness > 5) brightness = brightness - 5;
    }

    if (vpy_j1_button(2)) {
        if (brightness < 120) brightness = brightness + 5;
    }

    DRAW_LINE(-40, -40, 40, -40, brightness);
    DRAW_LINE(40, -40, 40, 40, brightness);
    DRAW_LINE(40, 40, -40, 40, brightness);
    DRAW_LINE(-40, 40, -40, -40, brightness);
    DRAW_LINE(-40, -40, 40, 40, brightness);
    DRAW_LINE(40, -40, -40, 40, brightness);
}

int main(void) { vpy_run(setup, loop); return 0; }
