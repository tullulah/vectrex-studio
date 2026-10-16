/* joystick_position — C port of examples/individual_tests/joystick_position (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { }

static void loop(void)
{
    int x = J1_X();
    int y = J1_Y();

    PRINT_TEXT(-60, 80, "POS X");
    PRINT_NUMBER(10, 80, x);
    PRINT_TEXT(-60, 60, "POS Y");
    PRINT_NUMBER(10, 60, y);

    DRAW_CIRCLE(x / 2, y / 2, 15, 80);

    PRINT_TEXT(-60, 40, "BTN1");
    PRINT_NUMBER(0, 40, vpy_j1_button(1));
    PRINT_TEXT(-60, 20, "BTN2");
    PRINT_NUMBER(0, 20, vpy_j1_button(2));
    PRINT_TEXT(-60, 0, "BTN3");
    PRINT_NUMBER(0, 0, vpy_j1_button(3));
    PRINT_TEXT(-60, -20, "BTN4");
    PRINT_NUMBER(0, -20, vpy_j1_button(4));
}

int main(void) { vpy_run(setup, loop); return 0; }
