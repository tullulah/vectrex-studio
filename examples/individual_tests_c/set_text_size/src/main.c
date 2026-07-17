/* set_text_size — C port of examples/individual_tests/set_text_size (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { SET_INTENSITY(100); }

static void draw_scales(void)
{
    SET_TEXT_SIZE(8);
    PRINT_TEXT(-80, 80, "SIZE 8 NORMAL");
    SET_TEXT_SIZE(6);
    PRINT_TEXT(-80, 40, "SIZE 6");
    SET_TEXT_SIZE(4);
    PRINT_TEXT(-80, 5, "SIZE 4");
    SET_TEXT_SIZE(2);
    PRINT_TEXT(-80, -30, "SIZE 2");
    SET_TEXT_SIZE(1);
    PRINT_TEXT(-80, -60, "SIZE 1 SMALL");
    SET_TEXT_SIZE(8);
}

static void loop(void)
{
    draw_scales();
}

int main(void) { vpy_run(setup, loop); return 0; }
