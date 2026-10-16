/* vplay_test — C port of examples/individual_tests/vplay_test (VPy).
 * Loads a compiled .vplay level, advances its object physics each frame, draws
 * it, and overlays a text label — all via the vpy.h runtime.
 *
 * demo_level.vplay is compiled to gen/demo_level.h by `vpy_cli compile-asset`
 * (see common.mk): DEMO_LEVEL_level is the byte image and
 * DEMO_LEVEL_level_sprites the sprite pointer table. */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "demo_level.h"  /* DEMO_LEVEL_level[] + DEMO_LEVEL_level_sprites[] */
#include "platform.h"    /* PLATFORM_vec[] — drawn directly too */

static void setup(void)
{
    LOAD_LEVEL(DEMO_LEVEL_level, DEMO_LEVEL_level_sprites);
}

static void loop(void)
{
    PRINT_TEXT(-55, 120, "VPLAY TEST");

    UPDATE_LEVEL();
    SHOW_LEVEL();

    DRAW_VECTOR(PLATFORM_vec, 0, 80);
}

int main(void) { vpy_run(setup, loop); return 0; }
