/* joystick_buttons — C port of examples/individual_tests/joystick_buttons (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { }

static void loop(void)
{
    int btn1 = vpy_j1_button(1);
    int btn2 = vpy_j1_button(2);
    int btn3 = vpy_j1_button(3);
    int btn4 = vpy_j1_button(4);

    PRINT_TEXT(-60, 80, "BTN1");
    PRINT_NUMBER(0, 80, btn1);

    PRINT_TEXT(-60, 60, "BTN2");
    PRINT_NUMBER(0, 60, btn2);

    PRINT_TEXT(-60, 40, "BTN3");
    PRINT_NUMBER(0, 40, btn3);

    PRINT_TEXT(-60, 20, "BTN4");
    PRINT_NUMBER(0, 20, btn4);

    if (btn1 == 1) DRAW_CIRCLE(-40, 0, 10, 80);
    if (btn2 == 1) DRAW_CIRCLE(0, 0, 10, 80);
    if (btn3 == 1) DRAW_CIRCLE(40, 0, 10, 80);
    if (btn4 == 1) DRAW_CIRCLE(0, -40, 10, 80);
}

int main(void) { vpy_run(setup, loop); return 0; }
