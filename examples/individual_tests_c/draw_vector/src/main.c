/* draw_vector — C port of examples/individual_tests/draw_vector (VPy).
 * Exercises DRAW_VECTOR / DRAW_VECTOR_EX with a compiled .vec sprite via the
 * vpy.h runtime. platform.vec is compiled to gen/platform.h by
 * `vpy_cli compile-asset` (see common.mk); the C runtime walks the same
 * path/segment byte stream the ARM/PiTrex backend draws. */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "platform.h"   /* provides PLATFORM_vec[] (compiled path stream) */

static void setup(void) {}

static void loop(void)
{
    /* Draw the sprite at an offset position... */
    DRAW_VECTOR(PLATFORM_vec, -50, 50);
    /* ...and centred (mirror=0, intensity=0 -> use the asset's own intensity). */
    DRAW_VECTOR_EX(PLATFORM_vec, 0, 0, 0, 0);
}

int main(void) { vpy_run(setup, loop); return 0; }
