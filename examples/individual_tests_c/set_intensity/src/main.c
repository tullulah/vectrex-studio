/* set_intensity — C port of examples/individual_tests/set_intensity (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { }

static void loop(void)
{
    PRINT_TEXT(-60, 80, "INTENSITY");

    /* 5 circles at increasing intensity */
    DRAW_CIRCLE(-100, 0, 15, 20);
    DRAW_CIRCLE(-50, 0, 15, 50);
    DRAW_CIRCLE(0, 0, 15, 80);
    DRAW_CIRCLE(50, 0, 15, 110);
    DRAW_CIRCLE(100, 0, 15, 127);

    /* Labels */
    PRINT_TEXT(-120, -30, "20");
    PRINT_TEXT(-70, -30, "50");
    PRINT_TEXT(-20, -30, "80");
    PRINT_TEXT(30, -30, "110");
    PRINT_TEXT(80, -30, "127");
}

int main(void) { vpy_run(setup, loop); return 0; }
