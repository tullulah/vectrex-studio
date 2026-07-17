/* physics_ball — C port of examples/individual_tests/physics_ball (VPy).
 * The gravity/bounce/joystick physics is procedural and ported faithfully.
 * Audio is restored via the vpy.h compiled-asset sequencer:
 *   - PLAY_MUSIC(MUSIC1_music) at startup (music1.vmus)
 *   - PLAY_SFX(JUMP_sfx) on jump, PLAY_SFX(HIT_sfx) on bounce (jump/hit .vsfx)
 * The .vmus/.vsfx are compiled to gen headers by `vpy_cli compile-asset` (common.mk).
 * The bouncing ball is the original bubble_medium.vec sprite, drawn via
 * DRAW_VECTOR (compiled to gen/bubble_medium.h by the same tool). */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "music1.h"        /* MUSIC1_music[]        */
#include "jump.h"          /* JUMP_sfx[]            */
#include "hit.h"           /* HIT_sfx[]             */
#include "bubble_medium.h" /* BUBBLE_MEDIUM_vec[]   */

static int bx = 0, by = 60;
static int vx = 1, vy = 0;
static int jx = 0;

static void setup(void)
{
    PLAY_MUSIC(MUSIC1_music);
    bx = 0; by = 60;
    vx = 1; vy = 0;
}

static void loop(void)
{
    PRINT_TEXT(-50, 100, "PHYSICS");
    PRINT_TEXT(-50, 85, "B1=JUMP");

    /* Apply gravity */
    vy = vy - 1;

    /* Joystick horizontal control */
    jx = J1_X();
    if (jx > 40) vx = vx + 1;
    if (jx < -40) vx = vx - 1;

    /* Jump button */
    if (vpy_j1_button(1)) {
        vy = 8;
        PLAY_SFX(JUMP_sfx);
    }

    /* Clamp horizontal velocity */
    if (vx > 6) vx = 6;
    if (vx < -6) vx = -6;

    /* Apply velocity */
    bx = bx + vx;
    by = by + vy;

    /* Floor bounce */
    if (by < -90) {
        by = -90;
        vy = 0 - vy;
        if (vy > 12) vy = 12;
        PLAY_SFX(HIT_sfx);
    }

    /* Ceiling bounce */
    if (by > 90) {
        by = 90;
        vy = 0 - vy;
    }

    /* Wall bounces */
    if (bx > 100) {
        bx = 100;
        vx = 0 - vx;
        PLAY_SFX(HIT_sfx);
    }
    if (bx < -100) {
        bx = -100;
        vx = 0 - vx;
        PLAY_SFX(HIT_sfx);
    }

    /* Draw ball sprite at physics position */
    DRAW_VECTOR(BUBBLE_MEDIUM_vec, bx, by);

    /* Draw floor line */
    DRAW_LINE(-100, -110, 100, -110, 60);
}

int main(void) { vpy_run(setup, loop); return 0; }
