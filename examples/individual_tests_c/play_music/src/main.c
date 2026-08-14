/* play_music — C port of examples/individual_tests/play_music (VPy).
 * Exercises PLAY_MUSIC with a compiled .vmus asset via the vpy.h runtime.
 * The music1.vmus is compiled to gen/music1.h by `vpy_cli compile-asset`
 * (see common.mk); the sequencer is driven automatically by vpy_run(). */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "music1.h"   /* provides MUSIC1_music[] (compiled PSG stream) */

static int music_playing = 0;

static void setup(void)
{
    music_playing = 1;
    PLAY_MUSIC(MUSIC1_music);
}

static void loop(void)
{
    PRINT_TEXT(-70, 80, "MUSIC");
    PRINT_TEXT(0, 80, "PLAYING");

    if (music_playing == 1)
        DRAW_CIRCLE(0, 0, 20, 80);
}

int main(void) { vpy_run(setup, loop); return 0; }
