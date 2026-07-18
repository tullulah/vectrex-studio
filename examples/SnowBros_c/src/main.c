/* SnowBros_c — C port of examples/SnowBros (VPy). Incremental build.
 *
 * Capstone validation that libvpy (ide/electron/resources/vpy-c) is a complete
 * C runtime. Ported in blocks; each block mirrors the VPy source in main.vpy
 * and is render-verified through the PitrexArm32 sim before the next lands.
 *
 *   Block 0 (skeleton)  ok  boot + LOAD_LEVEL/SPAWN_ENEMIES/SHOW_LEVEL/DRAW_ENEMIES
 *   Block 1 (this file) ok  state machine + title screen -> ROUND intro -> playing
 *   Block 2  player movement + input          (pending)
 *   Block 3  enemy locomotion (GET/SET_ENEMY)  (pending)
 *   Block 4  collision                         (pending)
 *   Block 5  snowball / throw                  (pending)
 *   Block 6  scoring / HUD                      (pending)
 *   Block 7  music / sfx                        (pending — SnowBros ships .vgz/.mid,
 *                                                needs .vmus/.vsfx conversion first)
 *
 * ── Asset-reference mechanism (the enemy_test_c pattern) ────────────────────
 * The build compiles each asset to a self-contained C header via
 *   vpy_cli compile-asset <asset> --format c --out gen/<name>.h
 * exposing position-independent symbols the C code passes to libvpy:
 *   world_1_1.vplay -> WORLD_1_1_level(+_sprites) + WORLD_1_1_enemies(+_enemy_sprites)
 *   init_screen.vec -> INIT_SCREEN_vec  (title logo)
 */
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "world_1_1.h"     /* WORLD_1_1_level(+_sprites), WORLD_1_1_enemies(+_enemy_sprites) */
#include "init_screen.h"   /* INIT_SCREEN_vec */

/* ── States (mirror main.vpy) ─────────────────────────────────────────────── */
enum {
    STATE_TITLE      = 0,   /* title + "PRESS A BUTTON" */
    STATE_GAME_START = 1,   /* "ROUND N" before play begins */
    STATE_PLAYING    = 2,   /* gameplay (minimal until Block 2+) */
};

/* ── Config / timings (mirror main.vpy) ───────────────────────────────────── */
#define LIVES_START       3
#define GAME_START_DELAY  120      /* frames of "ROUND N" */
#define LEVEL_TIME        3600
#define CAMERA_Y_MIN      (-2304)  /* camera that frames screen 1 */

/* ── Globals (mirror main.vpy) ────────────────────────────────────────────── */
static int game_state    = STATE_TITLE;
static int score         = 0;
static int lives         = LIVES_START;
static int current_level = 1;
static int frame_timer   = 0;
static int camera_y      = CAMERA_Y_MIN;
static int time_left     = 0;
static int enemy_count   = 0;

/* level camera for a given level (screen N stacks +256 above screen 1). */
static int level_camera_y(int level)
{
    int c = CAMERA_Y_MIN + (level - 1) * 256;
    return (c > 0) ? 0 : c;
}

/* ── Transitions ──────────────────────────────────────────────────────────── */
static void enter_game_start(void)
{
    frame_timer = GAME_START_DELAY;
    camera_y = level_camera_y(current_level);
    LOAD_LEVEL(WORLD_1_1_level, WORLD_1_1_level_sprites);
    SET_CAMERA_Y(camera_y);          /* libvpy LOAD_LEVEL does NOT reset camera */
    game_state = STATE_GAME_START;
}

/* load_current_level(): mirror of main.vpy — reset per-level state, load the
 * level and spawn its enemies. The camera must be parked BEFORE SPAWN_ENEMIES
 * (libvpy Y-filters spawns to cam_y +/-150), so SET_CAMERA_Y precedes spawn. */
static void load_current_level(void)
{
    STOP_MUSIC();
    time_left = LEVEL_TIME;
    camera_y  = level_camera_y(current_level);

    LOAD_LEVEL(WORLD_1_1_level, WORLD_1_1_level_sprites);
    SET_CAMERA_Y(camera_y);
    SPAWN_ENEMIES(WORLD_1_1_enemies, WORLD_1_1_enemy_sprites);
    /* Block 7: PLAY_MUSIC("Yukidama-Ondo") once .vmus assets exist. */
}

/* ── States ───────────────────────────────────────────────────────────────── */
static void state_title(void)
{
    SET_INTENSITY(85);
    DRAW_VECTOR(INIT_SCREEN_vec, 0, 40);
    PRINT_TEXT(-70, -40, "PRESS A BUTTON");
    if (J1_BUTTON_1()) {
        /* Block 7: PLAY_MUSIC("intro"); */
        score = 0;
        lives = LIVES_START;
        current_level = 1;
        enter_game_start();
    }
}

static void state_game_start(void)
{
    /* Enemies are not spawned yet (that happens when frame_timer hits 0), so
     * only the level platforms are shown behind the ROUND banner. */
    SHOW_LEVEL();
    PRINT_TEXT(-30, 20, "ROUND");
    PRINT_NUMBER(30, 20, current_level);
    if (--frame_timer <= 0) {
        load_current_level();
        game_state = STATE_PLAYING;
    }
}

static void state_playing(void)
{
    /* Minimal gameplay until Block 2+: park the camera, step + draw enemies,
     * show the level. Player movement / collision / snowballs land next. */
    SET_CAMERA_Y(camera_y);
    UPDATE_ENEMIES();
    SET_INTENSITY(85);
    DRAW_ENEMIES();
    SHOW_LEVEL();
    (void)score; (void)lives; (void)time_left; (void)enemy_count;
}

int main(void)
{
    vpy_init();

    /* main(): SET_INTENSITY(127); game_state = STATE_TITLE */
    SET_INTENSITY(127);
    game_state = STATE_TITLE;

    for (;;) {
        vpy_frame_begin();      /* WAIT_RECAL + refresh input */
        switch (game_state) {
            case STATE_TITLE:      state_title();      break;
            case STATE_GAME_START: state_game_start(); break;
            case STATE_PLAYING:    state_playing();    break;
            default:               game_state = STATE_TITLE; break;
        }
    }
    return 0;
}
