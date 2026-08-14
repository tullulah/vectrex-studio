/* screen_border — C port of examples/individual_tests/screen_border (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { }

static void loop(void)
{
    /* Bottom edge */
    DRAW_LINE(-96, -128, 0, -128, 80);
    DRAW_LINE(0, -128, 96, -128, 80);

    /* Top edge */
    DRAW_LINE(-96, 127, 0, 127, 80);
    DRAW_LINE(0, 127, 96, 127, 80);

    /* Left edge */
    DRAW_LINE(-96, -128, -96, -43, 80);
    DRAW_LINE(-96, -43, -96, 42, 80);
    DRAW_LINE(-96, 42, -96, 127, 80);

    /* Right edge */
    DRAW_LINE(96, -128, 96, -43, 80);
    DRAW_LINE(96, -43, 96, 42, 80);
    DRAW_LINE(96, 42, 96, 127, 80);

    /* Center crosshair */
    DRAW_LINE(-8, 0, 8, 0, 60);
    DRAW_LINE(0, -8, 0, 8, 60);
}

int main(void) { vpy_run(setup, loop); return 0; }
