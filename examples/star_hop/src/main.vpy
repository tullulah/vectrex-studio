META TITLE = "STAR HOP"
META MUSIC = music1

# ── Game states ──────────────────────────────────────────────
const STATE_TITLE    = 0
const STATE_GAME     = 1
const STATE_GAMEOVER = 2

# ── Physics constants ─────────────────────────────────────────
const GRAVITY    = 1
const JUMP_VY    = 11
const MOVE_SPEED = 2
const MAX_FALL   = -15
const PLAYER_HH  = 12   # distance from origin (drawn position) down to the feet (lowest leg point in player_walk frames)

# ── World constants ───────────────────────────────────────────
const STAR_COUNT  = 6
const MAX_ENEMIES = 8     # default M6809 pool size — iterate up to this in collision checks
const HIT_DX      = 14    # X overlap threshold (≈ half enemy + half player width)
const HIT_DY      = 16    # Y overlap threshold (≈ half body height)

# ── Player ────────────────────────────────────────────────────
player_x: i16 = 0
player_y: i16 = 0
prev_player_y: i16 = 0
player_vy: i16 = 0
grounded: i8  = 0
facing: i8    = 1
walking: i8   = 0
spawn_floor_y: i16 = 0

# ── Camera ────────────────────────────────────────────────────
camera_x: i16 = 0

# ── Stars (parallel arrays — positions from Playground) ───────
const star_x = [10, 5, 90, 120, 200, 220]
const star_y = [-30, 20, -10, 0, 20, 28]
star_taken   = [0, 0, 0, 0, 0, 0]

# ── Score and state ───────────────────────────────────────────
score: i16 = 0
state: i16 = STATE_TITLE
won: i8 = 0                # 1 = collected all stars, 0 = killed by enemy (drives win/lose text)
hud_frame: i8 = 0          # alternador para skip-frame del HUD (50→25 Hz solo el HUD)


def main():
    SET_INTENSITY(85)
    LOAD_LEVEL("world_2")
    SPAWN_ENEMIES("world_2")
    PLAY_MUSIC("theme")
    spawn_floor_y = GET_LEVEL_FLOOR_Y() + PLAYER_HH
    player_y      = spawn_floor_y
    prev_player_y = spawn_floor_y


def loop():
    switch state:
        case STATE_TITLE:
            draw_title()
        case STATE_GAME:
            update()
            draw()
        case STATE_GAMEOVER:
            draw_gameover()


# ── Update ────────────────────────────────────────────────────

def update():
    update_player()
    check_stars()
    scroll_camera()
    UPDATE_ENEMIES()
    check_enemy_collision()


def update_player():
    prev_player_y = player_y

    jx = J1_X()
    walking = 0

    if jx > 20:
        player_x += MOVE_SPEED
        facing = 1
        walking = 1
    if jx < -20:
        player_x -= MOVE_SPEED
        facing = -1
        walking = 1

    if J1_BUTTON_1() and grounded:
        player_vy = JUMP_VY
        grounded  = 0
        PLAY_SFX("jump")

    if grounded == 1:
        floor_y = LEVEL_COLLISION_Y(player_x, player_y, PLAYER_HH)
        if floor_y < spawn_floor_y:
            floor_y = spawn_floor_y
        if floor_y < player_y:
            grounded = 0

    if grounded == 0:
        player_vy -= GRAVITY
        if player_vy < MAX_FALL:
            player_vy = MAX_FALL
        player_y += player_vy

        if player_vy < 0:
            floor_y = LEVEL_COLLISION_Y(player_x, prev_player_y, PLAYER_HH)
            if floor_y < spawn_floor_y:
                floor_y = spawn_floor_y
            if player_y <= floor_y:
                player_y  = floor_y
                player_vy = 0
                grounded  = 1

    if player_y < spawn_floor_y:
        player_y  = spawn_floor_y
        player_vy = 0
        grounded  = 1

    player_x = clamp(player_x, -128, 260)


def scroll_camera():
    target   = player_x - 30
    camera_x = clamp(target, GET_SCROLL_LIMIT_LEFT(), GET_SCROLL_LIMIT_RIGHT())
    SET_CAMERA_X(camera_x)


def check_stars():
    for i in range(STAR_COUNT):
        if star_taken[i] == 0:
            dx = abs(player_x - star_x[i])
            dy = abs(player_y - star_y[i])
            if dx < 12 and dy < 12:
                star_taken[i] = 1
                score        += 1
                PLAY_SFX("collect")
                if score >= STAR_COUNT:
                    won = 1
                    state = STATE_GAMEOVER


def check_enemy_collision():
    # Iterate the enemy pool; if any active enemy overlaps the player,
    # transition to game over (loss). GET_ENEMY_ACTIVE returns 0 for
    # empty/dead slots so dead enemies don't kill us.
    for i in range(MAX_ENEMIES):
        if GET_ENEMY_ACTIVE(i):
            dx = abs(player_x - GET_ENEMY_X(i))
            dy = abs(player_y - GET_ENEMY_Y(i))
            if dx < HIT_DX and dy < HIT_DY:
                won = 0
                state = STATE_GAMEOVER


# ── Draw ──────────────────────────────────────────────────────

def draw():
    SHOW_LEVEL()
    draw_stars()
    DRAW_ENEMIES()
    draw_player()
    # Skip-frame del HUD: dibuja cada 2 frames (25 Hz, imperceptible para texto
    # estático). Ahorra ~50 % del coste de Print_Str_d cuando sumamos las 4
    # llamadas (PRINT_TEXT/PRINT_NUMBER × 4 ≈ 3500 cycles/frame → 1750 promedio).
    hud_frame = 1 - hud_frame
    if hud_frame == 0:
        draw_hud()


def draw_player():
    screen_x = player_x - camera_x
    # Only animate while walking. When idle, just draw the static body
    # (no legs) — keeps the screen calm and saves a few cycles. For an
    # idle pose with legs, create a player_idle.vec and DRAW_VECTOR it
    # here instead.
    if walking:
        if facing < 0:
            DRAW_ANIM("player_walk", screen_x, player_y, 1)
        else:
            DRAW_ANIM("player_walk", screen_x, player_y, 0)
    else:
        if facing < 0:
            DRAW_ANIM("player_idle", screen_x, player_y, 1)
        else:
            DRAW_ANIM("player_idle", screen_x, player_y, 0)


def draw_stars():
    for i in range(STAR_COUNT):
        if star_taken[i] == 0:
            sx = star_x[i] - camera_x
            sy = star_y[i]
            DRAW_VECTOR("star", sx, sy)


def draw_hud():
    PRINT_TEXT(-120, 115, "STARS")
    PRINT_NUMBER(-60, 115, score)
    PRINT_TEXT(-40, 115, "OF")
    PRINT_NUMBER(-10, 115, STAR_COUNT)


# ── Screens ───────────────────────────────────────────────────

def draw_title():
    PRINT_TEXT(-40, 30, "STAR HOP")
    PRINT_TEXT(-75, 5, "COLLECT ALL STARS")
    PRINT_TEXT(-65, -15, "PRESS BUTTON 1")
    if J1_BUTTON_1():
        state = STATE_GAME


def draw_gameover():
    if won:
        PRINT_TEXT(-45, 30, "YOU WIN!")
    else:
        PRINT_TEXT(-45, 30, "GAME OVER")
    PRINT_TEXT(-35, 5, "SCORE")
    PRINT_NUMBER(20, 5, score)
    PRINT_TEXT(-65, -15, "PRESS BUTTON 1")
    if J1_BUTTON_1():
        reset_game()


def reset_game():
    player_vy = 0
    grounded  = 0
    facing    = 1
    walking   = 0
    score     = 0
    won       = 0
    camera_x  = 0
    for i in range(STAR_COUNT):
        star_taken[i] = 0
    LOAD_LEVEL("world_2")
    SPAWN_ENEMIES("world_2")
    spawn_floor_y = GET_LEVEL_FLOOR_Y() + PLAYER_HH
    player_x      = 0
    player_y      = spawn_floor_y
    prev_player_y = spawn_floor_y
    state = STATE_TITLE
