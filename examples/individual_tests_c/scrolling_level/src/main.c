/* scrolling_level — C port of examples/individual_tests/scrolling_level (VPy).
 * Loads a compiled .vplay level, scrolls the camera with joystick 1, and draws
 * a fixed crosshair marker at screen center via the vpy.h runtime.
 *
 * world.vplay is compiled to gen/world.h by `vpy_cli compile-asset` (see
 * common.mk): WORLD_level is the byte image, WORLD_level_sprites is the sprite
 * pointer table (objects reference ground/marker/tile sprites by index). The C
 * runtime walks the same header/object layout the ARM/PiTrex backend uses. */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "world.h"    /* WORLD_level[] + WORLD_level_sprites[] (+ sprite .vec headers) */
#include "marker.h"   /* MARKER_vec[] — fixed crosshair sprite */

static int camera_x = 0;
static int camera_y = 0;

static void setup(void)
{
    LOAD_LEVEL(WORLD_level, WORLD_level_sprites);
}

static void loop(void)
{
    int joy_x = J1_X();
    int joy_y = J1_Y();

    if (joy_x >  20) camera_x += 3;
    if (joy_x < -20) camera_x -= 3;
    if (joy_y >  20) camera_y += 3;
    if (joy_y < -20) camera_y -= 3;

    camera_x = vpy_clamp(camera_x, -128, 400);
    camera_y = vpy_clamp(camera_y, -300, 127);

    SET_CAMERA_X(camera_x);
    SET_CAMERA_Y(camera_y);
    SHOW_LEVEL();

    /* Fixed crosshair at screen center to show the camera position. */
    DRAW_VECTOR(MARKER_vec, 0, 0);
}

int main(void) { vpy_run(setup, loop); return 0; }
