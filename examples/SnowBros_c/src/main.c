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
#include "player_idle.h"   /* PLAYER_IDLE_vec */
#include "player_jump.h"   /* PLAYER_JUMP_vec */
#include "player_walk.h"   /* PLAYER_WALK_anim + PLAYER_WALK_anim_sprites */

int vpy_clamp(int v, int lo, int hi);   /* libvpy (no CLAMP short-name macro) */

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

/* ── Player physics (mirror main.vpy) ─────────────────────────────────────── */
#define GRAVITY          1
#define JUMP_SPEED       11
#define MAX_FALL_SPEED   12
#define PLAYER_HH        11        /* half-height of player_idle.vec */
#define PLAYER_HW        6         /* half-width  of player_idle.vec */
#define WORLD_X_MIN      (-96)
#define WORLD_X_MAX      95
#define WORLD_Y_MAX      127

/* ── Snowballs (mirror main.vpy) ──────────────────────────────────────────── */
#define SNOW_SPEED         5       /* horizontal launch speed */
#define SNOW_LAUNCH_VY     3       /* initial upward arc */
#define SNOW_LIFE_NORMAL   14      /* frames of flight without power-up */
#define SNOW_LIFE_POWER    30
#define SHOOT_COOLDOWN_MAX 15      /* frames between shots */

/* ── Enemy interaction: snow hit / freeze / thaw (mirror main.vpy) ─────────── */
#define MAX_ENEMY_SLOTS    8
#define SNOW_HW            6        /* snowball half-width  (AABB) */
#define SNOW_HH            16       /* snowball half-height */
#define ENEMY_HW          6        /* enemy half-width */
#define ENEMY_HH          8        /* enemy half-height */
#define THAW_TICKS_SNOW    180      /* snow1/snow2 melt-back time */
#define THAW_TICKS_BALL    300      /* ball melt-back time */
#define TITCHI_STATE_NORMAL 0
#define TITCHI_STATE_BALL   3

/* ── Globals (mirror main.vpy) ────────────────────────────────────────────── */
static int game_state    = STATE_TITLE;
static int score         = 0;
static int lives         = LIVES_START;
static int current_level = 1;
static int frame_timer   = 0;
static int camera_y      = CAMERA_Y_MIN;
static int time_left     = 0;
static int enemy_count   = 0;

/* ── Player state (mirror main.vpy) ───────────────────────────────────────── */
static int player_x = 0, player_y = -2424, player_vx = 0, player_vy = 0;
static int player_facing = 0, player_on_ground = 0;
static int floor_y = 0, prev_y = 0, push_dx = 0, spawn_floor_y = 0;
static int screen_bottom = 0, screen_floor = 0;

/* ── Snowball state (3 slots, mirror main.vpy) ────────────────────────────── */
static int shoot_cooldown = 0, snow_life_max = SNOW_LIFE_NORMAL, snow_spawn_vx = 0;
static int snow0_active = 0, snow0_x = 0, snow0_y = 0, snow0_vx = 0, snow0_vy = 0, snow0_life = 0;
static int snow1_active = 0, snow1_x = 0, snow1_y = 0, snow1_vx = 0, snow1_vy = 0, snow1_life = 0;
static int snow2_active = 0, snow2_x = 0, snow2_y = 0, snow2_vx = 0, snow2_vy = 0, snow2_life = 0;

/* ── Enemy freeze/thaw state (one slot per enemy, managed here) ────────────── */
static int thaw_timers[MAX_ENEMY_SLOTS] = {0};
static int ball_rolling[MAX_ENEMY_SLOTS] = {0};   /* ball-rolling system -> later sub-step */

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
    player_x  = 0;
    player_vy = 0;
    player_on_ground = 1;
    shoot_cooldown = 0;
    snow_life_max = SNOW_LIFE_NORMAL;
    snow0_active = snow1_active = snow2_active = 0;
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) { thaw_timers[i] = 0; ball_rolling[i] = 0; }

    LOAD_LEVEL(WORLD_1_1_level, WORLD_1_1_level_sprites);
    SET_CAMERA_Y(camera_y);
    SPAWN_ENEMIES(WORLD_1_1_enemies, WORLD_1_1_enemy_sprites);

    /* Spawn the player on the screen-bottom floor — EXACTLY as VPy
     * load_current_level does (spawn_floor_y = GET_LEVEL_FLOOR_Y() + PLAYER_HH;
     * player_y = spawn_floor_y). The earlier "search a platform with
     * LEVEL_COLLISION_Y" diverged from the reference and landed the player at a
     * different height than the VPy build. */
    spawn_floor_y = GET_LEVEL_FLOOR_Y() + PLAYER_HH;
    player_y = spawn_floor_y;
    /* Block 7: PLAY_MUSIC("Yukidama-Ondo") once .vmus assets exist. */
}

static void try_shoot(void);   /* fwd: called from update_player */

/* ── Player (mirror main.vpy update_player/draw_player) ────────────────────── */
static void update_player(void)
{
    /* Horizontal move from the analog joystick. */
    player_vx = vpy_clamp(J1_X() / 32, -4, 4);
    if (player_vx > 0) player_facing = 0;
    if (player_vx < 0) player_facing = 1;
    player_x = vpy_clamp(player_x + player_vx, WORLD_X_MIN, WORLD_X_MAX);
    push_dx = LEVEL_COLLISION_X(player_x, player_y, PLAYER_HW, PLAYER_HH);
    player_x += push_dx;

    /* Jump + ground validation while grounded. */
    if (player_on_ground == 1) {
        if (J1_BUTTON_1()) {
            player_vy = JUMP_SPEED;
            player_on_ground = 0;
        }
        if (player_on_ground == 1) {
            floor_y = LEVEL_COLLISION_Y(player_x, player_y, PLAYER_HH);
            screen_bottom = camera_y - 127;
            if (floor_y < screen_bottom) floor_y = spawn_floor_y;   /* walk-off guard */
            if (floor_y < player_y) player_on_ground = 0;
        }
    }

    /* Gravity + fall + platform landing (uses prev_y to avoid tunneling). */
    if (player_on_ground == 0) {
        player_vy -= GRAVITY;
        if (player_vy < -MAX_FALL_SPEED) player_vy = -MAX_FALL_SPEED;
        prev_y = player_y;
        player_y += player_vy;
        if (player_vy < 0) {
            floor_y = LEVEL_COLLISION_Y(player_x, prev_y, PLAYER_HH);
            screen_bottom = camera_y - 127;
            if (floor_y < screen_bottom) floor_y = spawn_floor_y;
            if (player_y <= floor_y) {
                player_y = floor_y;
                player_vy = 0;
                player_on_ground = 1;
            }
        }
    }

    /* Screen bounds. */
    if (player_y > WORLD_Y_MAX) { player_y = WORLD_Y_MAX; player_vy = 0; }
    screen_floor = spawn_floor_y;
    if (player_y < screen_floor) {
        player_y = screen_floor;
        player_vy = 0;
        player_on_ground = 1;
    }

    /* Shoot a snowball with button 2 (ball-rolling try_launch_ball -> later,
     * with the enemy freeze/ball system). */
    if (shoot_cooldown > 0) shoot_cooldown--;
    if (J1_BUTTON_2() && shoot_cooldown == 0) {
        snow_spawn_vx = (player_facing == 1) ? -SNOW_SPEED : SNOW_SPEED;
        try_shoot();
    }
}

static void draw_player(void)
{
    int sy = player_y - camera_y;   /* world -> screen */
    if (player_on_ground == 0) {
        DRAW_VECTOR_EX(PLAYER_JUMP_vec, player_x, sy, player_facing, 65);
    } else if (player_vx == 0) {
        DRAW_VECTOR_EX(PLAYER_IDLE_vec, player_x, sy, player_facing, 65);
    } else {
        DRAW_ANIM(PLAYER_WALK_anim, PLAYER_WALK_anim_sprites, player_x, sy, player_facing);
    }
}

/* ── Snowballs (mirror main.vpy try_shoot/update_snowballs/draw_snowballs) ─── */
static void try_shoot(void)
{
    /* Spawn into the first free of the 3 slots at the player, arcing up. */
    if (snow0_active == 0) {
        snow0_x = player_x; snow0_y = player_y;
        snow0_vx = snow_spawn_vx; snow0_vy = SNOW_LAUNCH_VY;
        snow0_life = snow_life_max; snow0_active = 1;
        shoot_cooldown = SHOOT_COOLDOWN_MAX;
    } else if (snow1_active == 0) {
        snow1_x = player_x; snow1_y = player_y;
        snow1_vx = snow_spawn_vx; snow1_vy = SNOW_LAUNCH_VY;
        snow1_life = snow_life_max; snow1_active = 1;
        shoot_cooldown = SHOOT_COOLDOWN_MAX;
    } else if (snow2_active == 0) {
        snow2_x = player_x; snow2_y = player_y;
        snow2_vx = snow_spawn_vx; snow2_vy = SNOW_LAUNCH_VY;
        snow2_life = snow_life_max; snow2_active = 1;
        shoot_cooldown = SHOOT_COOLDOWN_MAX;
    }
    /* Block 7: PLAY_SFX("shot_normal") once .vsfx assets exist. */
}

/* one snowball slot step: gravity + move + life/offscreen cull. */
#define SNOW_STEP(A,X,Y,VX,VY,L)                                  \
    if (A == 1) {                                                 \
        VY -= GRAVITY;                                            \
        if (VY < -MAX_FALL_SPEED) VY = -MAX_FALL_SPEED;           \
        X += VX; Y += VY; L -= 1;                                 \
        if (L <= 0)                A = 0;                         \
        else if (Y - camera_y < -110) A = 0;                     \
        else if (X < -127 || X > 127) A = 0;                     \
    }

static void update_snowballs(void)
{
    SNOW_STEP(snow0_active, snow0_x, snow0_y, snow0_vx, snow0_vy, snow0_life)
    SNOW_STEP(snow1_active, snow1_x, snow1_y, snow1_vx, snow1_vy, snow1_life)
    SNOW_STEP(snow2_active, snow2_x, snow2_y, snow2_vx, snow2_vy, snow2_life)
}

static void draw_snowballs(void)
{
    if (snow0_active == 1) DRAW_CIRCLE(snow0_x, snow0_y - camera_y, 5, 120);
    if (snow1_active == 1) DRAW_CIRCLE(snow1_x, snow1_y - camera_y, 5, 120);
    if (snow2_active == 1) DRAW_CIRCLE(snow2_x, snow2_y - camera_y, 5, 120);
}

/* ── HUD (mirror main.vpy draw_hud) ───────────────────────────────────────── */
static void draw_hud(void)
{
    SET_INTENSITY(90);
    PRINT_NUMBER(0,   127, score);          /* score, top-left  */
    PRINT_NUMBER(-78, 127, lives);          /* lives            */
    PRINT_NUMBER(58,  127, time_left / 60);  /* seconds left, top-right */
}

/* ── Snowball vs enemy: hit -> freeze; frozen enemies thaw over time ───────── */
static void on_snow_hit_enemy(int idx)
{
    ENEMY_FIRE_EVENT(idx, "onSnowHit");        /* advance the enemy state machine */
    int new_state = GET_ENEMY_STATE(idx);
    thaw_timers[idx] = (new_state == TITCHI_STATE_BALL) ? THAW_TICKS_BALL : THAW_TICKS_SNOW;
}

/* AABB test one snowball slot against enemy (ex,ey); on overlap consume the
 * snowball and fire the hit. Returns nothing; *active is cleared on hit. */
static void snow_vs_enemy(int *active, int sx, int sy, int idx, int ex, int ey)
{
    if (*active != 1) return;
    int dx = sx - ex; if (dx < 0) dx = -dx;
    int dy = sy - ey; if (dy < 0) dy = -dy;
    if (dx < SNOW_HW + ENEMY_HW && dy < SNOW_HH + ENEMY_HH) {
        *active = 0;
        on_snow_hit_enemy(idx);
    }
}

static void check_snowball_enemy_collision(void)
{
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) {
        if (GET_ENEMY_ACTIVE(i) != 1) continue;
        int ex = GET_ENEMY_X(i), ey = GET_ENEMY_Y(i);
        snow_vs_enemy(&snow0_active, snow0_x, snow0_y, i, ex, ey);
        snow_vs_enemy(&snow1_active, snow1_x, snow1_y, i, ex, ey);
        snow_vs_enemy(&snow2_active, snow2_x, snow2_y, i, ex, ey);
    }
}

/* Frozen enemies (state 1..3) melt one level at a time after their timer. */
static void update_thaw(void)
{
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) {
        int st = GET_ENEMY_STATE(i);
        if (st > 0 && st < 4 && ball_rolling[i] == 0) {
            if (--thaw_timers[i] <= 0) {
                st -= 1;
                SET_ENEMY_STATE(i, st);
                if (st > 0) thaw_timers[i] = THAW_TICKS_SNOW;
            }
        }
    }
}

static int count_active_enemies(void)
{
    int n = 0;
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++)
        if (GET_ENEMY_ACTIVE(i) == 1) n++;
    return n;
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
    /* Block 2: player movement + input. Collision (snowball/enemy), snowballs
     * and scoring land in later blocks. */
    /* Level timer (INVINCIBLE mode -> no death on timeout yet; the player-death
     * state lands with the enemy block). */
    if (time_left > 0) time_left--;

    update_player();
    update_snowballs();
    UPDATE_ENEMIES();
    update_thaw();
    check_snowball_enemy_collision();

    SET_CAMERA_Y(camera_y);

    draw_player();
    draw_snowballs();
    SET_INTENSITY(85);
    DRAW_ENEMIES();
    draw_hud();
    enemy_count = count_active_enemies();
    SHOW_LEVEL();
}

#ifdef SBC_TEST
/* Test seam: expose game/player state to the native render-verification driver.
 * Compiled out of every real build (hardware + WASM sim). */
int sbc_game_state(void)       { return game_state; }
int sbc_player_x(void)         { return player_x; }
int sbc_player_y(void)         { return player_y; }
int sbc_player_on_ground(void) { return player_on_ground; }
int sbc_snow_active(void)      { return snow0_active + snow1_active + snow2_active; }
int sbc_shoot_cooldown(void)   { return shoot_cooldown; }
int sbc_time_left(void)        { return time_left; }
int sbc_score(void)            { return score; }
int sbc_lives(void)            { return lives; }
int sbc_enemy_count(void)      { return enemy_count; }
/* force a snowball onto (x,y) and run the snow/enemy hit check, for tests. */
void sbc_force_snow0(int x, int y) { snow0_x = x; snow0_y = y; snow0_vx = 0; snow0_vy = 0;
                                     snow0_life = SNOW_LIFE_NORMAL; snow0_active = 1; }
void sbc_run_snow_check(void)      { check_snowball_enemy_collision(); }
int  sbc_thaw_timer(int i)         { return (i>=0 && i<MAX_ENEMY_SLOTS) ? thaw_timers[i] : -1; }
/* enemy-pool observation (mirror GET_ENEMY_* used by the game code). */
int  sbc_enemy_active(int i)       { return GET_ENEMY_ACTIVE(i); }
int  sbc_enemy_state(int i)        { return GET_ENEMY_STATE(i); }
int  sbc_enemy_x(int i)            { return GET_ENEMY_X(i); }
int  sbc_enemy_y(int i)            { return GET_ENEMY_Y(i); }
/* drive one full playing-state frame (locomotion + thaw + collision). */
void sbc_update_thaw(void)         { update_thaw(); }
#endif

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
