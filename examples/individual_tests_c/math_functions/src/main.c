/* math_functions — C port of examples/individual_tests/math_functions (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static void setup(void) { }

static void loop(void)
{
    int val1 = vpy_abs(-50);
    PRINT_TEXT(-100, 80, "ABS(-50)");
    PRINT_NUMBER(30, 80, val1);

    int val2 = vpy_min(30, 70);
    PRINT_TEXT(-100, 60, "MIN(30,70)");
    PRINT_NUMBER(30, 60, val2);

    int val3 = vpy_max(30, 70);
    PRINT_TEXT(-100, 40, "MAX(30,70)");
    PRINT_NUMBER(30, 40, val3);

    int val4 = vpy_clamp(150, 0, 100);
    PRINT_TEXT(-100, 20, "CLAMP(150)");
    PRINT_NUMBER(30, 20, val4);
}

int main(void) { vpy_run(setup, loop); return 0; }
