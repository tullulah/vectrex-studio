/* play_sfx — C port of examples/individual_tests/play_sfx (VPy).
 * BTN1 -> jump SFX, BTN2 -> explosion SFX, via the vpy.h runtime.
 * jump.vsfx / explosion.vsfx are compiled to gen headers by `vpy_cli compile-asset`
 * (see common.mk); the SFX sequencer is driven automatically by vpy_run(). */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "jump.h"        /* JUMP_sfx[] */
#include "explosion.h"   /* EXPLOSION_sfx[] */

static void setup(void) { }

static void loop(void)
{
    PRINT_TEXT(-60, 80, "SFX TEST");
    PRINT_TEXT(-80, 50, "BTN1=JUMP");
    PRINT_TEXT(-80, 30, "BTN2=BOOM");

    if (vpy_j1_button(1)) {
        PLAY_SFX(JUMP_sfx);
        DRAW_CIRCLE(0, -20, 15, 100);
    }

    if (vpy_j1_button(2)) {
        PLAY_SFX(EXPLOSION_sfx);
        DRAW_CIRCLE(0, -20, 30, 100);
    }

    /* Visual indicator always visible */
    DRAW_CIRCLE(0, -20, 5, 40);
}

int main(void) { vpy_run(setup, loop); return 0; }
