/* draw_move — C port of examples/individual_tests/draw_move (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { }

static void loop(void)
{
    /* Move to left position and draw */
    MOVE(-60, 60);
    DRAW_LINE(0, 0, 40, -40, 80);

    /* Move to right position and draw */
    MOVE(60, 60);
    DRAW_LINE(0, 0, -40, -40, 80);

    /* Move to center and draw */
    MOVE(0, 0);
    DRAW_LINE(-30, 0, 30, 0, 80);
}

int main(void) { vpy_run(setup, loop); return 0; }
