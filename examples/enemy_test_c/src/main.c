/* enemy_test_c — C port of examples/enemy_test (VPy).
 *
 * Proves libvpy's LEVEL + ENEMY runtime is usable FROM C. Mirrors the VPy
 * enemy_test exactly:
 *
 *     def main():  LOAD_LEVEL("level1"); SPAWN_ENEMIES("level1")
 *     def loop():  UPDATE_ENEMIES(); DRAW_ENEMIES(); show_level()
 *
 * ── Asset-reference mechanism (the reusable pattern for a C SnowBros) ────────
 * Where VPy resolves "level1" to link-time symbols behind the scenes, C names
 * the compiled position-independent asset symbols explicitly. The build runs
 *     vpy_cli compile-asset assets/playground/level1.vplay --format c \
 *             --out gen/level1.h
 * which emits ONE header exposing four PI symbols (and #includes the per-sprite
 * .vec header for the compiled sprite arrays):
 *     LEVEL1_level[]    + LEVEL1_level_sprites[]    -> vpy_load_level()
 *     LEVEL1_enemies[]  + LEVEL1_enemy_sprites[]    -> vpy_spawn_enemies()
 * The enemy image + its sprite table are compiled from the SAME .vplay: the
 * level compiler reads the enemy AI / waypoints / sprite from
 * assets/enemies/*.venemy (dir derived as {level}/../enemies) and reuses the
 * exact byte layout vpy.c's vpy_spawn_enemies expects. Nothing is hand-built —
 * the bytes are byte-identical to the VPy pitrex build.
 *
 * The frame loop is written out explicitly (init + setup, then a WAIT_RECAL-
 * paced loop). `vpy_run(setup, loop)` is the equivalent libvpy one-liner; the
 * explicit form is used here so the per-frame structure is visible (a real game
 * such as SnowBros-C reads input and steps game logic in the same place).
 */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "level1.h"   /* LEVEL1_level(+_sprites), LEVEL1_enemies(+_enemy_sprites) */

int main(void)
{
    vpy_init();

    /* setup — once at startup */
    LOAD_LEVEL(LEVEL1_level, LEVEL1_level_sprites);
    SPAWN_ENEMIES(LEVEL1_enemies, LEVEL1_enemy_sprites);

    /* loop — every frame */
    for (;;) {
        vpy_frame_begin();      /* WAIT_RECAL + refresh input */
        UPDATE_ENEMIES();
        DRAW_ENEMIES();
        SHOW_LEVEL();
    }
    return 0;
}
