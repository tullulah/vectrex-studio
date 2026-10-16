/* print_number — C port of examples/individual_tests/print_number (VPy). */
#define VPY_SHORT_NAMES
#include <vpy.h>

static int counter = 0;

static void setup(void) { counter = 0; }

static void loop(void)
{
    PRINT_TEXT(-80, 0, "COUNTER");
    PRINT_NUMBER(30, 0, counter);
    PRINT_TEXT(-80, -30, "FIXED VAL");
    PRINT_NUMBER(30, -30, 9999);
    counter = counter + 1;
}

int main(void) { vpy_run(setup, loop); return 0; }
