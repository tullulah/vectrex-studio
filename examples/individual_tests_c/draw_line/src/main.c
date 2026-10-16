/* draw_line — C port of examples/individual_tests/draw_line (VPy).
 * Exercises DRAW_LINE, PRINT_TEXT and PRINT_NUMBER via the vpy.h runtime. */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { }

static void loop(void)
{
    PRINT_TEXT(-55, 20, "TEST");
    PRINT_NUMBER(-5, 20, 123);
    DRAW_LINE(0, 60, -57, 19, 80);
    DRAW_LINE(-57, 19, -35, -49, 80);
    DRAW_LINE(-35, -49, 35, -49, 80);
    DRAW_LINE(35, -49, 57, 19, 80);
    DRAW_LINE(57, 19, 0, 60, 80);
}

int main(void) { vpy_run(setup, loop); return 0; }
