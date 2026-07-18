/* SnowBros_c — C port of examples/SnowBros (VPy), SKELETON stage.
 *
 * Capstone validation that libvpy (ide/electron/resources/vpy-c) is a complete
 * C runtime: this reuses the enemy_test_c asset-reference pattern to boot the
 * REAL SnowBros first level (assets/playground/world_1_1.vplay) and render its
 * opening screen — the bottom-screen platforms + the enemies that spawn on it.
 *
 * ── Asset-reference mechanism (same as enemy_test_c) ────────────────────────
 * The build runs, per asset:
 *     vpy_cli compile-asset assets/playground/world_1_1.vplay --format c \
 *             --out gen/world_1_1.h
 * which emits ONE header exposing four position-independent symbols and
 * `#include`s the per-sprite .vec headers (also compiled to gen/*.h):
 *     WORLD_1_1_level[]        + WORLD_1_1_level_sprites[]   -> LOAD_LEVEL
 *     WORLD_1_1_enemies[]      + WORLD_1_1_enemy_sprites[]   -> SPAWN_ENEMIES
 * The enemy AI / waypoints / sprites are read from assets/enemies/*.venemy
 * (dir derived as {level}/../enemies) — byte-identical to the VPy pitrex build.
 *
 * ── SKELETON scope ──────────────────────────────────────────────────────────
 * This is the toolchain + asset-pipeline + libvpy-link proof only, NOT the full
 * ~1000-line game. The loop shows the level and steps/draws enemies so the sim
 * renders a bounded, nonzero segment stream every frame. Game states (title,
 * player movement, snowballs, scoring, music) are ported in later blocks.
 *
 * SnowBros' world is 10 stacked screens (worldBounds yMin ≈ -2403); the opening
 * screen is the BOTTOM one, so the camera is parked at CAMERA_Y_MIN (-2304) to
 * frame level-1's ground platforms and its first wave of enemies.
 */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "world_1_1.h"   /* WORLD_1_1_level(+_sprites), WORLD_1_1_enemies(+_enemy_sprites) */

/* Matches SnowBros/src/main.vpy: CAMERA_Y_MIN = -2304 shows screen 1. */
#define CAMERA_Y_MIN (-2304)

int main(void)
{
    vpy_init();

    /* setup — once at startup */
    SET_INTENSITY(127);
    LOAD_LEVEL(WORLD_1_1_level, WORLD_1_1_level_sprites);
    /* Park the camera on the bottom (opening) screen BEFORE spawning: libvpy's
     * SPAWN_ENEMIES keeps only enemies within cam_y +/-150, so the camera must
     * frame this screen first or level-1's first wave is filtered out. */
    SET_CAMERA_Y(CAMERA_Y_MIN);
    SPAWN_ENEMIES(WORLD_1_1_enemies, WORLD_1_1_enemy_sprites);

    /* loop — every frame */
    for (;;) {
        vpy_frame_begin();      /* WAIT_RECAL + refresh input */
        UPDATE_ENEMIES();
        SHOW_LEVEL();           /* platforms + background objects, camera-offset */
        DRAW_ENEMIES();         /* first wave of enemies on the opening screen */
    }
    return 0;
}
