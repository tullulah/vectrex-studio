/* moving_vectors — C port of examples/individual_tests/moving_vectors (VPy).
 * Two .vec sprites (ball, bubble_small) bounce inside a box, with music playing.
 * ball.vec / bubble_small.vec are compiled to gen headers by `vpy_cli compile-asset`
 * (see common.mk); DRAW_VECTOR walks the same path stream the ARM/PiTrex backend
 * draws. Expected: ball and bubble move around the screen. */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "ball.h"           /* BALL_vec[]          */
#include "bubble_small.h"   /* BUBBLE_SMALL_vec[]  */
#include "music1.h"         /* MUSIC1_music[]      */

/* Ball state */
static int ball_x, ball_y, ball_vx, ball_vy;
/* Bubble state */
static int bub_x, bub_y, bub_vx, bub_vy;

static void setup(void)
{
    PLAY_MUSIC(MUSIC1_music);
    ball_x = 0;   ball_y = 20;  ball_vx = 3;  ball_vy = 2;
    bub_x  = -30; bub_y  = -20; bub_vx  = -2; bub_vy  = 3;
}

static void loop(void)
{
    SET_INTENSITY(100);
    PRINT_TEXT(-60, 110, "MOVING VEC");
    PRINT_NUMBER(-60, 90, ball_x);
    PRINT_NUMBER(-60, 70, ball_vx);

    /* Move ball */
    ball_x += ball_vx;
    ball_y += ball_vy;

    /* Bounce ball (radius=3) — edge hits wall, not center */
    if (ball_x >  97) { ball_vx = -ball_vx; ball_x =  97; }
    if (ball_x < -97) { ball_vx = -ball_vx; ball_x = -97; }
    if (ball_y >  77) { ball_vy = -ball_vy; ball_y =  77; }
    if (ball_y < -77) { ball_vy = -ball_vy; ball_y = -77; }

    /* Move bubble */
    bub_x += bub_vx;
    bub_y += bub_vy;

    /* Bounce bubble (radius=10) — edge hits wall, not center */
    if (bub_x >  90) { bub_vx = -bub_vx; bub_x =  90; }
    if (bub_x < -90) { bub_vx = -bub_vx; bub_x = -90; }
    if (bub_y >  70) { bub_vy = -bub_vy; bub_y =  70; }
    if (bub_y < -70) { bub_vy = -bub_vy; bub_y = -70; }

    /* Draw sprites at their positions */
    DRAW_VECTOR(BALL_vec, ball_x, ball_y);
    DRAW_VECTOR(BUBBLE_SMALL_vec, bub_x, bub_y);

    /* Draw boundary box */
    DRAW_LINE(-100,  80,  100,  80, 60);
    DRAW_LINE( 100,  80,  100, -80, 60);
    DRAW_LINE( 100, -80, -100, -80, 60);
    DRAW_LINE(-100, -80, -100,  80, 60);
}

int main(void) { vpy_run(setup, loop); return 0; }
