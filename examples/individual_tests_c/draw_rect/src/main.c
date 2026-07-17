/* draw_rect — C port of examples/individual_tests/draw_rect (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { }

static void loop(void)
{
    /* Left rectangle: (-80,-40), 30 wide, 80 tall */
    DRAW_RECT(-80, -40, 30, 80, 80);

    /* Right rectangle: (50,-40), 30 wide, 80 tall */
    DRAW_RECT(50, -40, 30, 80, 80);

    /* Center square: (-15,-15), 30 wide, 30 tall */
    DRAW_RECT(-15, -15, 30, 30, 80);
}

int main(void) { vpy_run(setup, loop); return 0; }
