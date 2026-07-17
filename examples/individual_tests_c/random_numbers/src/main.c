/* random_numbers — C port of examples/individual_tests/random_numbers (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static int rx1 = 0, ry1 = 0;
static int rx2 = 0, ry2 = 0;
static int rx3 = 0, ry3 = 0;

static void setup(void)
{
    rx1 = 0; ry1 = 0;
    rx2 = 0; ry2 = 0;
    rx3 = 0; ry3 = 0;
}

static void loop(void)
{
    PRINT_TEXT(-50, 90, "RANDOM");

    /* Generate random positions and draw dots */
    rx1 = vpy_rand_range(-80, 80);
    ry1 = vpy_rand_range(-60, 60);
    DRAW_CIRCLE(rx1, ry1, 20, 100);

    rx2 = vpy_rand_range(-80, 80);
    ry2 = vpy_rand_range(-60, 60);
    DRAW_CIRCLE(rx2, ry2, 20, 80);

    rx3 = vpy_rand_range(-80, 80);
    ry3 = vpy_rand_range(-60, 60);
    DRAW_CIRCLE(rx3, ry3, 20, 60);
}

int main(void) { vpy_run(setup, loop); return 0; }
