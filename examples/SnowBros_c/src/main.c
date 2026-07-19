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
#include "player_die1.h"   /* PLAYER_DIE1_vec (death anim frames 1..4) */
#include "player_die2.h"
#include "player_die3.h"
#include "player_die4.h"
#include "frog_fireball_side.h"   /* FROG_FIREBALL_SIDE_vec */
#include "frog_fireball_down.h"   /* FROG_FIREBALL_DOWN_vec */

int vpy_clamp(int v, int lo, int hi);   /* libvpy (no CLAMP short-name macro) */

/* ── States (mirror main.vpy) ─────────────────────────────────────────────── */
enum {
    STATE_TITLE       = 0,   /* title + "PRESS A BUTTON" */
    STATE_GAME_START  = 1,   /* "ROUND N" before play begins */
    STATE_PLAYING     = 2,   /* gameplay */
    STATE_PLAYER_DEAD = 3,   /* death anim + delay (player-death sub-step) */
    STATE_LEVEL_CLEAR = 4,   /* "LEVEL CLEAR!" + scroll to next screen */
    STATE_BOSS_INTRO  = 5,   /* "WARNING! BOSS INCOMING" (levels 10,20,..) */
    STATE_BOSS        = 6,   /* boss fight (placeholder, mirror main.vpy) */
    STATE_GAME_OVER   = 7,   /* game over (player-death sub-step) */
    STATE_ALL_CLEAR   = 8,   /* all 50 levels cleared */
};

/* ── Config / timings (mirror main.vpy) ───────────────────────────────────── */
#define INVINCIBLE        1        /* 1 = player never dies (enemies or timeout) */
#define LIVES_START       3
#define DEATH_DELAY       120      /* frames of the death animation */
#define GAME_OVER_DELAY   300      /* frames of the game-over screen */
#define GAME_START_DELAY  120      /* frames of "ROUND N" */
#define LEVEL_CLEAR_DELAY 150      /* frames of "LEVEL CLEAR!" */
#define BOSS_INTRO_DELAY  180      /* frames of the boss warning */
#define ALL_CLEAR_DELAY   300      /* frames of the all-clear screen */
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

/* ── Ball-rolling / kick (mirror main.vpy) ─────────────────────────────────── */
#define BALL_SPEED    4       /* rolling horizontal speed */
#define BALL_GRAVITY  1       /* per-frame downward accel */
#define BALL_MAX_FALL 8       /* terminal fall speed */

/* ── Frog fire (mirror main.vpy) ───────────────────────────────────────────── */
#define FROG_STATE_NORMAL       0
#define FROG_STATE_FIRE_SIDE    4
#define FROG_STATE_FIRE_DOWN    5
#define FROG_FIRE_INTERVAL      120    /* frames between shots (~2s) */
#define FROG_BULLET_SPEED       3
#define FROG_BULLET_DOWN_SPEED  3
#define FROG_BULLET_HW          4
#define FROG_BULLET_HH          4

/* ── Globals (mirror main.vpy) ────────────────────────────────────────────── */
static int game_state    = STATE_TITLE;
static int score         = 0;
static int lives         = LIVES_START;
static int current_level = 1;
static int frame_timer   = 0;
static int camera_y      = CAMERA_Y_MIN;
static int time_left     = 0;
static int enemy_count   = 0;
static int scroll_target = CAMERA_Y_MIN;   /* camera goal during a level transition */
static int next_is_boss  = 0;              /* check_if_boss_level output flag */

/* ── Player state (mirror main.vpy) ───────────────────────────────────────── */
static int player_x = 0, player_y = -2424, player_vx = 0, player_vy = 0;
static int player_facing = 0, player_on_ground = 0;
static int floor_y = 0, prev_y = 0, push_dx = 0, spawn_floor_y = 0;
static int screen_bottom = 0, screen_floor = 0;
static int player_has_power = 0;   /* power-up flag (reset per level) */

/* ── Snowball state (3 slots, mirror main.vpy) ────────────────────────────── */
static int shoot_cooldown = 0, snow_life_max = SNOW_LIFE_NORMAL, snow_spawn_vx = 0;
static int snow0_active = 0, snow0_x = 0, snow0_y = 0, snow0_vx = 0, snow0_vy = 0, snow0_life = 0;
static int snow1_active = 0, snow1_x = 0, snow1_y = 0, snow1_vx = 0, snow1_vy = 0, snow1_life = 0;
static int snow2_active = 0, snow2_x = 0, snow2_y = 0, snow2_vx = 0, snow2_vy = 0, snow2_life = 0;

/* ── Enemy freeze/thaw state (one slot per enemy, managed here) ────────────── */
static int thaw_timers[MAX_ENEMY_SLOTS] = {0};

/* ── Ball-rolling state (one slot per enemy, mirror main.vpy) ──────────────── */
static int ball_rolling[MAX_ENEMY_SLOTS]  = {0};   /* 1 = ball in motion */
static int ball_vx_arr[MAX_ENEMY_SLOTS]   = {0};
static int ball_vy_arr[MAX_ENEMY_SLOTS]   = {0};
static int ball_bounces[MAX_ENEMY_SLOTS]  = {0};   /* bounces left before it pops */
static int ball_collided[MAX_ENEMY_SLOTS] = {0};   /* per-frame ball-vs-ball guard */
static int ball_launched = 0;                      /* try_launch_ball found a ball */

/* ── Frog-fire state (mirror main.vpy) ─────────────────────────────────────── */
static int frog_fire_timer[MAX_ENEMY_SLOTS] = {0};   /* per-slot shoot countdown */
static int frog_fire_decay[MAX_ENEMY_SLOTS] = {0};   /* frames until fire anim ends */
static int frog_bullet_active = 0;
static int frog_bullet_x = 0, frog_bullet_y = 0, frog_bullet_vx = 0, frog_bullet_vy = 0;
static int frog_bullet_dir = 0;      /* 0 = side, 1 = down */
static int frog_bullet_mirror = 0;   /* 0 = right, 1 = left (side shots) */

static void reset_balls(void);       /* fwd: called from load_current_level */
static void reset_frog_fire(void);   /* fwd: called from load_current_level */

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

/* Boss levels are the multiples of 10 (mirror check_if_boss_level). */
static void check_if_boss_level(void)
{
    next_is_boss = 0;
    if (current_level == 10 || current_level == 20 || current_level == 30 ||
        current_level == 40 || current_level == 50)
        next_is_boss = 1;
}

/* Enter the "LEVEL CLEAR!" state: park a scroll target one screen up so the
 * camera pans to the next screen while the banner shows (mirror
 * enter_level_clear). */
static void enter_level_clear(void)
{
    frame_timer = LEVEL_CLEAR_DELAY;
    scroll_target = camera_y + 256;
    if (scroll_target > 0) scroll_target = 0;
    game_state = STATE_LEVEL_CLEAR;
}

static void enter_boss_intro(void)
{
    /* Block 7: PLAY_MUSIC("Boss_Intro"). */
    frame_timer = BOSS_INTRO_DELAY;
    game_state = STATE_BOSS_INTRO;
}

static void on_player_death(void)
{
    lives -= 1;
    frame_timer = DEATH_DELAY;
    game_state = STATE_PLAYER_DEAD;
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
    player_has_power = 0;
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) thaw_timers[i] = 0;
    reset_balls();
    reset_frog_fire();

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

static void try_shoot(void);        /* fwd: called from update_player */
static void try_launch_ball(void);  /* fwd: kick a nearby frozen ball */

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

    /* Button 2: kick a nearby frozen ball if touching one, else shoot a
     * snowball. Mirror main.vpy exactly: try_launch_ball sets ball_launched
     * when it kicks; only when it did NOT do we spawn a snowball. */
    if (shoot_cooldown > 0) shoot_cooldown--;
    if (J1_BUTTON_2() && shoot_cooldown == 0) {
        ball_launched = 0;
        try_launch_ball();
        if (ball_launched == 0) {
            snow_spawn_vx = (player_facing == 1) ? -SNOW_SPEED : SNOW_SPEED;
            try_shoot();
        }
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

/* ── Ball-rolling / kick (mirror main.vpy) ─────────────────────────────────── */

/* Reset the whole ball system on level load (mirror reset_balls). */
static void reset_balls(void)
{
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) {
        ball_rolling[i]  = 0;
        ball_vx_arr[i]   = 0;
        ball_vy_arr[i]   = 0;
        ball_bounces[i]  = 0;
        ball_collided[i] = 0;
    }
}

/* Kick a nearby frozen (BALL-state) enemy into a rolling ball. Launches at most
 * one per call and sets ball_launched so update_player skips the snowball. */
static void try_launch_ball(void)
{
    int found = 0;
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) {
        if (found) break;
        if (GET_ENEMY_ACTIVE(i) != 1) continue;
        if (GET_ENEMY_STATE(i) != TITCHI_STATE_BALL) continue;
        if (ball_rolling[i] != 0) continue;
        int ex = GET_ENEMY_X(i), ey = GET_ENEMY_Y(i);
        int dx = player_x - ex; if (dx < 0) dx = -dx;
        int dy = player_y - ey; if (dy < 0) dy = -dy;
        if (dx < 25 && dy < 25) {
            ball_rolling[i]  = 1;
            ball_vx_arr[i]   = (player_facing == 1) ? -BALL_SPEED : BALL_SPEED;
            ball_vy_arr[i]   = 0;
            ball_bounces[i]  = vpy_rand_range(3, 5);
            thaw_timers[i]   = 0;
            shoot_cooldown   = SHOOT_COOLDOWN_MAX;
            ball_launched    = 1;
            found            = 1;
        }
    }
}

/* A rolling ball flattens any not-yet-ball enemy it overlaps (mirror
 * ball_kill_enemies). The +200 is intrinsic to the kill in main.vpy. */
static void ball_kill_enemies(int bx, int by)
{
    for (int j = 0; j < MAX_ENEMY_SLOTS; j++) {
        if (GET_ENEMY_ACTIVE(j) != 1) continue;
        int st = GET_ENEMY_STATE(j);
        if (st < TITCHI_STATE_BALL) {
            int ejx = GET_ENEMY_X(j), ejy = GET_ENEMY_Y(j);
            int dx = bx - ejx; if (dx < 0) dx = -dx;
            int dy = by - ejy; if (dy < 0) dy = -dy;
            if (dx < 24 && dy < 24) {
                KILL_ENEMY(j);
                score += 200;
            }
        }
    }
}

/* Physics for rolling balls: gravity, platform/floor landing (raycast from the
 * previous Y like the player), wall/mesh bounce with a bounce budget, then it
 * kills enemies it touches. When bounces run out the ball pops (mirror
 * update_balls). */
static void update_balls(void)
{
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) {
        if (ball_rolling[i] != 1) continue;

        ball_vy_arr[i] -= BALL_GRAVITY;
        if (ball_vy_arr[i] < -BALL_MAX_FALL) ball_vy_arr[i] = -BALL_MAX_FALL;

        int prev_by = GET_ENEMY_Y(i);
        int bx = GET_ENEMY_X(i) + ball_vx_arr[i];
        int by = prev_by + ball_vy_arr[i];

        /* Falling: land on the platform under the PREVIOUS position (no tunnel). */
        if (ball_vy_arr[i] < 0) {
            int floor = LEVEL_COLLISION_Y(bx, prev_by, ENEMY_HH);
            int screen_bottom = camera_y - 127;
            if (floor < screen_bottom) floor = GET_LEVEL_FLOOR_Y() + ENEMY_HH;
            if (by <= floor) { by = floor; ball_vy_arr[i] = 0; }
        }
        /* World-floor fallback so a ball rests ON the ground, not floating. */
        if (by < GET_LEVEL_FLOOR_Y() + ENEMY_HH) {
            by = GET_LEVEL_FLOOR_Y() + ENEMY_HH;
            ball_vy_arr[i] = 0;
        }

        /* Wall bounce (consumes a bounce). */
        if (bx < WORLD_X_MIN) { bx = WORLD_X_MIN; ball_vx_arr[i] =  BALL_SPEED; ball_bounces[i]--; }
        if (bx > WORLD_X_MAX) { bx = WORLD_X_MAX; ball_vx_arr[i] = -BALL_SPEED; ball_bounces[i]--; }

        /* Mesh bounce (does NOT consume a bounce, matches main.vpy). */
        int push = LEVEL_COLLISION_X(bx, by, ENEMY_HW, ENEMY_HH);
        if (push != 0) { bx += push; ball_vx_arr[i] = -ball_vx_arr[i]; }

        SET_ENEMY_X(i, bx);
        SET_ENEMY_Y(i, by);
        ball_kill_enemies(bx, by);

        if (ball_bounces[i] <= 0) { ball_rolling[i] = 0; KILL_ENEMY(i); }
    }
}

/* Ball-vs-ball billiard repulsion. Guard ball_collided so each (i,j) pair is
 * processed once per frame: i reverses, j inherits i's original direction
 * (mirror ball_ball_collision). */
static void ball_ball_collision(void)
{
    for (int k = 0; k < MAX_ENEMY_SLOTS; k++) ball_collided[k] = 0;
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) {
        if (ball_rolling[i] != 1) continue;
        if (ball_collided[i] != 0) continue;
        int bx = GET_ENEMY_X(i), by = GET_ENEMY_Y(i);
        for (int j = 0; j < MAX_ENEMY_SLOTS; j++) {
            if (i == j) continue;
            if (ball_collided[j] != 0) continue;
            if (GET_ENEMY_ACTIVE(j) != 1) continue;
            if (GET_ENEMY_STATE(j) != TITCHI_STATE_BALL) continue;
            int ejx = GET_ENEMY_X(j), ejy = GET_ENEMY_Y(j);
            int dx = bx - ejx; if (dx < 0) dx = -dx;
            int dy = by - ejy; if (dy < 0) dy = -dy;
            /* Only resolve the hit when the two balls are APPROACHING. main.vpy
             * (and this port) reverses velocities on any overlap frame, so two
             * balls that meet at the same Y swap velocities, cross, still
             * overlap, and swap right back — locking into a 2-frame oscillation
             * that never separates, never reaches a wall to burn a bounce, and
             * so never pops (the "stuck at the bottom" bug). Gating on the
             * closing direction (rel_x and rel_vx opposite signs) resolves each
             * pair exactly once, sending them to opposite sides where they then
             * bounce off walls and disappear. NOTE: intentional divergence from
             * main.vpy — it fixes a bug present in the VPy reference too. */
            int rel_x  = ejx - bx;
            int rel_vx = ball_vx_arr[j] - ball_vx_arr[i];
            if (dx < 20 && dy < 20 && rel_x * rel_vx < 0) {
                int old_vx = ball_vx_arr[i];
                ball_vx_arr[i] = -old_vx;
                ball_vx_arr[j] =  old_vx;
                ball_rolling[j] = 1;
                thaw_timers[j] = 0;
                if (ball_bounces[j] <= 0) ball_bounces[j] = vpy_rand_range(3, 5);
                ball_collided[i] = 1;
                ball_collided[j] = 1;
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

/* Player vs enemies: touching a NORMAL enemy kills the player (only when not
 * INVINCIBLE); touching a frozen enemy/ball instead pushes it aside and nudges
 * the player back (a solid block). Mirror check_player_enemy_collision. */
static void check_player_enemy_collision(void)
{
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) {
        if (GET_ENEMY_ACTIVE(i) != 1) continue;
        int st = GET_ENEMY_STATE(i);
        int ex = GET_ENEMY_X(i), ey = GET_ENEMY_Y(i);
        int dx = player_x - ex; if (dx < 0) dx = -dx;
        int dy = player_y - ey; if (dy < 0) dy = -dy;
        if (dx < 20 && dy < 20) {
            if (st == TITCHI_STATE_NORMAL) {
                if (INVINCIBLE == 0) on_player_death();
            } else {
                /* Push the frozen enemy/ball away and block the player. */
                if (ex >= player_x) { SET_ENEMY_X(i, player_x + 20); player_x -= 1; }
                if (ex <  player_x) { SET_ENEMY_X(i, player_x - 20); player_x += 1; }
            }
        }
    }
}

/* ── Frog fire (mirror main.vpy) ───────────────────────────────────────────── */

/* Reset the frog-fire system on level load (mirror reset_frog_fire). */
static void reset_frog_fire(void)
{
    frog_bullet_active = 0;
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) {
        frog_fire_timer[i] = FROG_FIRE_INTERVAL;
        frog_fire_decay[i] = 0;
    }
}

/* Frogs count down and shoot: down at a player below and aligned, else sideways
 * toward the player. FIRE_SIDE/FIRE_DOWN states decay back to NORMAL after 40
 * frames. Only one frog bullet exists at a time (mirror update_frog_fire). */
static void update_frog_fire(void)
{
    for (int i = 0; i < MAX_ENEMY_SLOTS; i++) {
        if (GET_ENEMY_ACTIVE(i) != 1) continue;
        int st = GET_ENEMY_STATE(i);
        if (st == FROG_STATE_FIRE_SIDE) {
            if (--frog_fire_decay[i] <= 0) {
                SET_ENEMY_STATE(i, FROG_STATE_NORMAL);
                frog_fire_timer[i] = FROG_FIRE_INTERVAL;
            }
        }
        if (st == FROG_STATE_FIRE_DOWN) {
            if (--frog_fire_decay[i] <= 0) {
                SET_ENEMY_STATE(i, FROG_STATE_NORMAL);
                frog_fire_timer[i] = FROG_FIRE_INTERVAL;
            }
        }
        if (st == 0) {
            if (--frog_fire_timer[i] <= 0) {
                frog_fire_timer[i] = FROG_FIRE_INTERVAL;
                int ex = GET_ENEMY_X(i), ey = GET_ENEMY_Y(i);
                int fire_down_flag = 0;
                if (player_y < ey - 20) {
                    int dx = player_x - ex; if (dx < 0) dx = -dx;
                    if (dx < 40) fire_down_flag = 1;
                }
                if (fire_down_flag == 1) {
                    ENEMY_FIRE_EVENT(i, "onFireDown");
                    if (GET_ENEMY_STATE(i) == FROG_STATE_FIRE_DOWN) {
                        frog_fire_decay[i] = 40;
                        if (frog_bullet_active == 0) {
                            frog_bullet_x = ex; frog_bullet_y = ey;
                            frog_bullet_vx = 0; frog_bullet_vy = -FROG_BULLET_DOWN_SPEED;
                            frog_bullet_dir = 1; frog_bullet_mirror = 0;
                            frog_bullet_active = 1;
                        }
                    }
                } else {
                    /* Face the player, then fire sideways so the sprite mirrors. */
                    int face_left = (player_x < ex) ? 1 : 0;
                    if (face_left == 1) SET_ENEMY_DIR(i, 0);
                    if (face_left == 0) SET_ENEMY_DIR(i, 1);
                    ENEMY_FIRE_EVENT(i, "onFireSide");
                    if (GET_ENEMY_STATE(i) == FROG_STATE_FIRE_SIDE) {
                        frog_fire_decay[i] = 40;
                        if (frog_bullet_active == 0) {
                            frog_bullet_x = ex; frog_bullet_y = ey;
                            frog_bullet_vx = (face_left == 1) ? -FROG_BULLET_SPEED : FROG_BULLET_SPEED;
                            frog_bullet_vy = 0;
                            frog_bullet_dir = 0; frog_bullet_mirror = face_left;
                            frog_bullet_active = 1;
                        }
                    }
                }
            }
        }
    }
}

/* Fly the single frog bullet, cull it off-screen, and (unless INVINCIBLE) kill
 * the player on overlap (mirror update_frog_bullet). */
static void update_frog_bullet(void)
{
    if (frog_bullet_active != 1) return;
    frog_bullet_x += frog_bullet_vx;
    frog_bullet_y += frog_bullet_vy;
    if (frog_bullet_x < -127 || frog_bullet_x > 127) frog_bullet_active = 0;
    int scr_y = frog_bullet_y - camera_y;
    if (scr_y < -127 || scr_y > 127) frog_bullet_active = 0;
    if (frog_bullet_active == 1) {
        int dx = frog_bullet_x - player_x; if (dx < 0) dx = -dx;
        int dy = frog_bullet_y - player_y; if (dy < 0) dy = -dy;
        if (dx < FROG_BULLET_HW + PLAYER_HW && dy < FROG_BULLET_HH + PLAYER_HH) {
            frog_bullet_active = 0;
            if (INVINCIBLE == 0) on_player_death();
        }
    }
}

static void draw_frog_bullet(void)
{
    if (frog_bullet_active != 1) return;
    SET_INTENSITY(110);
    int scr_y = frog_bullet_y - camera_y;
    if (frog_bullet_dir == 0)
        DRAW_VECTOR_EX(FROG_FIREBALL_SIDE_vec, frog_bullet_x, scr_y, frog_bullet_mirror, 110);
    if (frog_bullet_dir == 1)
        DRAW_VECTOR_EX(FROG_FIREBALL_DOWN_vec, frog_bullet_x, scr_y, 0, 110);
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
    if (time_left <= 0 && INVINCIBLE == 0) on_player_death();

    update_player();
    update_snowballs();
    UPDATE_ENEMIES();
    update_thaw();
    update_balls();
    ball_ball_collision();
    update_frog_fire();
    update_frog_bullet();
    check_snowball_enemy_collision();
    check_player_enemy_collision();

    SET_CAMERA_Y(camera_y);

    draw_player();
    draw_snowballs();
    draw_frog_bullet();
    SET_INTENSITY(85);
    DRAW_ENEMIES();
    draw_hud();
    enemy_count = count_active_enemies();
    if (enemy_count <= 0) enter_level_clear();
    SHOW_LEVEL();
}

/* ── State: player death — 4-frame death animation, then respawn or game over ─ */
static void draw_player_death(void)
{
    SET_INTENSITY(65);
    STOP_MUSIC();
    int sy = player_y - camera_y;
    int elapsed = DEATH_DELAY - frame_timer;
    if (elapsed < 12)      DRAW_VECTOR_EX(PLAYER_DIE1_vec, player_x, sy, player_facing, 65);
    else if (elapsed < 22) DRAW_VECTOR_EX(PLAYER_DIE2_vec, player_x, sy, player_facing, 65);
    else if (elapsed < 32) DRAW_VECTOR_EX(PLAYER_DIE3_vec, player_x, sy, player_facing, 65);
    else                   DRAW_VECTOR_EX(PLAYER_DIE4_vec, player_x, sy, player_facing, 65);
}

static void state_player_dead(void)
{
    SHOW_LEVEL();
    draw_hud();
    draw_player_death();
    if (--frame_timer <= 0) {
        if (lives <= 0) {
            /* Block 7: PLAY_MUSIC("Game_Over"). */
            frame_timer = GAME_OVER_DELAY;
            game_state = STATE_GAME_OVER;
        }
        if (lives > 0) enter_game_start();
    }
}

static void state_game_over(void)
{
    PRINT_TEXT(-30, 20, "GAME OVER");
    PRINT_TEXT(-30, 0, "SCORE");
    PRINT_NUMBER(30, 0, score);
    if (--frame_timer <= 0) {
        STOP_MUSIC();
        game_state = STATE_TITLE;
    }
}

/* ── State: LEVEL CLEAR! — pan the camera up one screen, then advance ───────── */
static void state_level_clear(void)
{
    if (camera_y < scroll_target) {
        camera_y += 3;
        if (camera_y > scroll_target) camera_y = scroll_target;
    }
    SET_CAMERA_Y(camera_y);
    SHOW_LEVEL();
    draw_hud();
    PRINT_TEXT(-35, 0, "LEVEL CLEAR!");
    if (--frame_timer <= 0) {
        current_level += 1;
        if (current_level > 50) {
            frame_timer = ALL_CLEAR_DELAY;
            STOP_MUSIC();
            game_state = STATE_ALL_CLEAR;
        }
        if (current_level <= 50) {
            check_if_boss_level();
            if (next_is_boss == 1) enter_boss_intro();
            if (next_is_boss == 0) enter_game_start();
        }
    }
}

/* ── State: all 50 levels cleared ──────────────────────────────────────────── */
static void state_all_clear(void)
{
    PRINT_TEXT(-55, 30, "CONGRATULATIONS!");
    PRINT_TEXT(-30,  5, "ALL CLEAR!");
    PRINT_TEXT(-25, -20, "SCORE");
    PRINT_NUMBER(30, -20, score);
    if (--frame_timer <= 0) game_state = STATE_TITLE;
}

/* ── State: boss warning (levels 10,20,..) ─────────────────────────────────── */
static void state_boss_intro(void)
{
    PRINT_TEXT(-30, 20, "WARNING!");
    PRINT_TEXT(-50,  0, "BOSS INCOMING");
    if (--frame_timer <= 0) {
        load_current_level();
        /* Block 7: play_boss_music(). */
        game_state = STATE_BOSS;
    }
}

/* ── State: boss fight (placeholder — no win condition yet, mirror main.vpy) ── */
static void state_boss(void)
{
    update_player();
    update_snowballs();
    UPDATE_ENEMIES();
    check_snowball_enemy_collision();
    SHOW_LEVEL();
    draw_player();
    draw_snowballs();
    SET_INTENSITY(85);
    DRAW_ENEMIES();
    draw_hud();
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
/* ball-rolling test seam. */
int  sbc_ball_rolling(int i)       { return (i>=0&&i<MAX_ENEMY_SLOTS)?ball_rolling[i]:-1; }
int  sbc_ball_bounces(int i)       { return (i>=0&&i<MAX_ENEMY_SLOTS)?ball_bounces[i]:-1; }
int  sbc_ball_vx(int i)            { return (i>=0&&i<MAX_ENEMY_SLOTS)?ball_vx_arr[i]:0; }
int  sbc_ball_launched(void)       { return ball_launched; }
void sbc_set_player(int x,int y,int f){ player_x=x; player_y=y; player_facing=f; }
void sbc_set_enemy_state(int i,int s){ SET_ENEMY_STATE(i,s); }
void sbc_set_enemy_x(int i,int v)  { SET_ENEMY_X(i,v); }
void sbc_set_enemy_y(int i,int v)  { SET_ENEMY_Y(i,v); }
void sbc_try_launch_ball(void)     { ball_launched=0; try_launch_ball(); }
void sbc_update_balls(void)        { update_balls(); }
void sbc_ball_ball_collision(void) { ball_ball_collision(); }
void sbc_reset_balls(void)         { reset_balls(); }
/* level-clear / state-machine test seam. */
void sbc_set_game_state(int s)     { game_state = s; }
void sbc_set_current_level(int n)  { current_level = n; }
int  sbc_current_level(void)       { return current_level; }
int  sbc_camera_y(void)            { return camera_y; }
int  sbc_scroll_target(void)       { return scroll_target; }
int  sbc_frame_timer(void)         { return frame_timer; }
void sbc_load_current_level(void)  { load_current_level(); }
void sbc_kill_all_enemies(void)    { for (int i=0;i<MAX_ENEMY_SLOTS;i++) KILL_ENEMY(i); }
void sbc_step(void) {               /* run one frame of the current state */
    switch (game_state) {
        case STATE_TITLE:       state_title();       break;
        case STATE_GAME_START:  state_game_start();  break;
        case STATE_PLAYING:     state_playing();     break;
        case STATE_PLAYER_DEAD: state_player_dead(); break;
        case STATE_GAME_OVER:   state_game_over();   break;
        case STATE_LEVEL_CLEAR: state_level_clear(); break;
        case STATE_BOSS_INTRO:  state_boss_intro();  break;
        case STATE_BOSS:        state_boss();        break;
        case STATE_ALL_CLEAR:   state_all_clear();   break;
        default:                game_state = STATE_TITLE; break;
    }
}
int  sbc_lives_get(void)           { return lives; }
void sbc_set_lives(int n)          { lives = n; }
void sbc_force_player_death(void)  { on_player_death(); }  /* bypass INVINCIBLE for tests */
void sbc_check_player_enemy(void)  { check_player_enemy_collision(); }
/* frog-fire test seam. */
int  sbc_frog_bullet_active(void)  { return frog_bullet_active; }
int  sbc_frog_bullet_x(void)       { return frog_bullet_x; }
int  sbc_frog_bullet_y(void)       { return frog_bullet_y; }
int  sbc_frog_bullet_vx(void)      { return frog_bullet_vx; }
int  sbc_frog_bullet_vy(void)      { return frog_bullet_vy; }
int  sbc_frog_bullet_dir(void)     { return frog_bullet_dir; }
int  sbc_frog_bullet_mirror(void)  { return frog_bullet_mirror; }
int  sbc_frog_fire_decay(int i)    { return (i>=0&&i<MAX_ENEMY_SLOTS)?frog_fire_decay[i]:-1; }
void sbc_set_frog_timer(int i,int v){ if(i>=0&&i<MAX_ENEMY_SLOTS) frog_fire_timer[i]=v; }
void sbc_set_frog_bullet(int x,int y,int a){ frog_bullet_x=x; frog_bullet_y=y; frog_bullet_active=a; frog_bullet_vx=0; frog_bullet_vy=0; }
void sbc_update_frog_fire(void)    { update_frog_fire(); }
void sbc_update_frog_bullet(void)  { update_frog_bullet(); }
void sbc_reset_frog_fire(void)     { reset_frog_fire(); }
int  sbc_fire_side_probe(int i)    { ENEMY_FIRE_EVENT(i,"onFireSide"); return GET_ENEMY_STATE(i); }
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
            case STATE_TITLE:       state_title();       break;
            case STATE_GAME_START:  state_game_start();  break;
            case STATE_PLAYING:     state_playing();     break;
            case STATE_PLAYER_DEAD: state_player_dead(); break;
            case STATE_GAME_OVER:   state_game_over();   break;
            case STATE_LEVEL_CLEAR: state_level_clear(); break;
            case STATE_BOSS_INTRO:  state_boss_intro();  break;
            case STATE_BOSS:        state_boss();        break;
            case STATE_ALL_CLEAR:   state_all_clear();   break;
            default:                game_state = STATE_TITLE; break;
        }
    }
    return 0;
}
