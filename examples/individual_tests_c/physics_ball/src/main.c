/* physics_ball — C port of examples/individual_tests/physics_ball (VPy).
 * The gravity/bounce/joystick physics is procedural and ported faithfully.
 * Asset-backed lines are out of scope for the vpy.h runtime:
 *   - PLAY_MUSIC("music1") / PLAY_SFX("jump"|"hit") dropped (no asset audio).
 *   - DRAW_VECTOR("bubble_medium", bx, by) replaced with DRAW_CIRCLE so the
 *     bouncing ball stays visible. */
#define VPY_SHORT_NAMES
#include <vpy.h>

static int bx = 0, by = 60;
static int vx = 1, vy = 0;
static int jx = 0;

static void setup(void)
{
    /* PLAY_MUSIC("music1") — asset audio, out of scope */
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
        /* PLAY_SFX("jump") — asset audio, out of scope */
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
        /* PLAY_SFX("hit") — asset audio, out of scope */
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
        /* PLAY_SFX("hit") — asset audio, out of scope */
    }
    if (bx < -100) {
        bx = -100;
        vx = 0 - vx;
        /* PLAY_SFX("hit") — asset audio, out of scope */
    }

    /* Draw ball (was DRAW_VECTOR("bubble_medium", bx, by)) */
    DRAW_CIRCLE(bx, by, 10, 90);

    /* Draw floor line */
    DRAW_LINE(-100, -110, 100, -110, 60);
}

int main(void) { vpy_run(setup, loop); return 0; }
