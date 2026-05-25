META TITLE = "SNOW BROS"
#META TARGET = vectrex
META MAX_ENEMIES = 8
META ROM_TOTAL_SIZE = 131072
META ROM_BANK_SIZE = 16384

# ── Debug ────────────────────────────────────────────────────────────────────
const INVINCIBLE = 1   # 1 = no muere por enemigos ni por tiempo
const START_FLOOR = 0 # piso inicial (0=normal floor 1, 2=floor 2, etc.)

# ── States ──────────────────────────────────────────────────────────────────
const STATE_TITLE = 0        # título + "press a button"
const STATE_GAME_START = 1   # "ROUND N" antes de empezar
const STATE_PLAYING = 2      # gameplay activo
const STATE_PLAYER_DEAD = 3  # animación de muerte + delay
const STATE_LEVEL_CLEAR = 4  # todos los enemigos derrotados
const STATE_BOSS_INTRO = 5   # pantalla de aviso boss (niveles múltiplos de 10)
const STATE_BOSS = 6         # combate boss
const STATE_GAME_OVER = 7    # game over
const STATE_ALL_CLEAR = 8    # completados los 50 niveles

# ── Enemy SM state indices (must match titchi.venemy state order) ─────────
const TITCHI_STATE_NORMAL = 0
const TITCHI_STATE_SNOW1 = 1
const TITCHI_STATE_SNOW2 = 2
const TITCHI_STATE_BALL = 3

# ── Frog SM state indices ─────────────────────────────────────────────────
const FROG_STATE_NORMAL    = 0
const FROG_STATE_SNOW1     = 1
const FROG_STATE_SNOW2     = 2
const FROG_STATE_BALL      = 3
const FROG_STATE_FIRE_SIDE = 4
const FROG_STATE_FIRE_DOWN = 5

# ── Frog bullet physics ───────────────────────────────────────────────────
const FROG_FIRE_INTERVAL    = 120   # frames between shots (~2s)
const FROG_BULLET_SPEED     = 3
const FROG_BULLET_DOWN_SPEED = 3
const FROG_BULLET_HW        = 4
const FROG_BULLET_HH        = 4

# ── Thaw timers (one per enemy slot, managed in VPy) ─────────────────────
const THAW_TICKS_SNOW = 180   # snow1/snow2: ~3s at 60fps
const THAW_TICKS_BALL = 300   # ball: ~5s at 60fps
thaw_timers = [0, 0, 0, 0, 0, 0, 0, 0]

# ── Frog fire system ──────────────────────────────────────────────────────
frog_fire_timer = [0, 0, 0, 0, 0, 0, 0, 0]   # per-slot shoot countdown
frog_fire_decay = [0, 0, 0, 0, 0, 0, 0, 0]   # frames until fire anim ends → back to normal
frog_bullet_active: i16 = 0
frog_bullet_x: i16 = 0
frog_bullet_y: i16 = 0
frog_bullet_vx: i16 = 0
frog_bullet_vy: i16 = 0
frog_bullet_dir: i16 = 0      # 0 = side, 1 = down
frog_bullet_mirror: i16 = 0   # 0 = right, 1 = left (side shots only)

# ── Ball-rolling system ───────────────────────────────────────────────────
const BALL_SPEED = 4
const BALL_GRAVITY = 1
const BALL_MAX_FALL = 8

ball_rolling  = [0, 0, 0, 0, 0, 0, 0, 0]   # 1 = bola en movimiento
ball_vx_arr   = [0, 0, 0, 0, 0, 0, 0, 0]   # velocidad horizontal
ball_vy_arr   = [0, 0, 0, 0, 0, 0, 0, 0]   # velocidad vertical
ball_bounces  = [0, 0, 0, 0, 0, 0, 0, 0]   # rebotes restantes antes de desaparecer
ball_collided = [0, 0, 0, 0, 0, 0, 0, 0]   # guard por frame: evita doble proceso
ball_launched: i16 = 0                       # flag: try_launch_ball encontró bola

# Half-sizes for AABB collision (approx from vec files)
const SNOW_HW = 6    # snowball half-width
const SNOW_HH = 16    # snowball half-height
const ENEMY_HW = 6   # enemy half-width
const ENEMY_HH = 8  # enemy half-height

# ── Globals de partida ──────────────────────────────────────────────────────
game_state: i16 = 0

score: i16 = 0              # TODO: usar u16/i32 cuando esté disponible
lives: i16 = 3
current_level: i16 = 1      # 1-50
time_left: i16 = 0          # frames restantes del nivel
enemy_count: i16 = 0        # enemigos vivos en pantalla
frame_timer: i16 = 0        # contador de delay para transiciones
_t0: i16 = 0                # timing checkpoint (debug)
_t1: i16 = 0
_t2: i16 = 0
_t3: i16 = 0
_t4: i16 = 0
_dbg_ctr: i16 = 0           # throttle: print section timing every 10 frames
next_is_boss: i16 = 0       # flag auxiliar para detección de nivel boss
spawn_floor_y: i16 = 0      # Y mundial del suelo detectado al cargar nivel

# ── Player ──────────────────────────────────────────────────────────────────
player_x: i16 = 0
player_y: i16 = -2424
player_vx: i16 = 0
player_vy: i16 = 0
player_facing: i16 = 0
player_on_ground: i16 = 0
floor_y: i16 = 0
prev_y: i16 = 0
push_dx: i16 = 0

# ── Physics ──────────────────────────────────────────────────────────────────
const GRAVITY = 1
const JUMP_SPEED = 12
const MAX_FALL_SPEED = 12
const PLAYER_HH = 11     # half-height de player_idle.vec
const PLAYER_HW = 6      # half-width de player_idle.vec

# ── World bounds (deben coincidir con worldBounds del .vplay) ────────────────
const WORLD_X_MIN = -96
const WORLD_X_MAX = 95
const WORLD_Y_MIN = -2403   # suelo de pantalla 1 (desplazado -2304)
const WORLD_Y_MAX = 127     # techo de pantalla 10
const CAMERA_Y_MAX = 2304   # rango de scroll (9 × 256)
const CAMERA_Y_MIN = -2304  # posición cámara mostrando pantalla 1

camera_y: i16 = -2304
scroll_target: i16 = -2304   # objetivo de cámara durante transición de nivel

# ── Snowball system ───────────────────────────────────────────────────────────
const SNOW_SPEED = 5             # velocidad horizontal
const SNOW_LAUNCH_VY = 3        # arco inicial hacia arriba
const SNOW_LIFE_NORMAL = 14     # frames de vida sin power-up (~70px)
const SNOW_LIFE_POWER = 30      # frames de vida con power-up (~150px)
const SHOOT_COOLDOWN_MAX = 15   # frames entre disparos

shoot_cooldown: i16 = 0
player_has_power: i16 = 0
snow_life_max: i16 = 14        # cambia al recoger power-up
snow_spawn_vx: i16 = 0         # vx calculado antes de llamar try_shoot

snow0_active: i16 = 0
snow0_x: i16 = 0
snow0_y: i16 = 0
snow0_vx: i16 = 0
snow0_vy: i16 = 0
snow0_life: i16 = 0

snow1_active: i16 = 0
snow1_x: i16 = 0
snow1_y: i16 = 0
snow1_vx: i16 = 0
snow1_vy: i16 = 0
snow1_life: i16 = 0

snow2_active: i16 = 0
snow2_x: i16 = 0
snow2_y: i16 = 0
snow2_vx: i16 = 0
snow2_vy: i16 = 0
snow2_life: i16 = 0

# ── Timings (en frames a ~60fps) ────────────────────────────────────────────
const LEVEL_TIME = 3600      # 60 segundos por nivel
const LIVES_START = 3
const GAME_START_DELAY = 120
const DEATH_DELAY = 120
const LEVEL_CLEAR_DELAY = 150
const BOSS_INTRO_DELAY = 180
const GAME_OVER_DELAY = 300
const ALL_CLEAR_DELAY = 300

# ══════════════════════════════════════════════════════════════════════════════

def main():
    SET_INTENSITY(127)
    game_state = STATE_TITLE

def loop():
    if game_state == STATE_TITLE:
        state_title()
    if game_state == STATE_GAME_START:
        state_game_start()
    if game_state == STATE_PLAYING:
        state_playing()
    if game_state == STATE_PLAYER_DEAD:
        state_player_dead()
    if game_state == STATE_LEVEL_CLEAR:
        state_level_clear()
    if game_state == STATE_BOSS_INTRO:
        state_boss_intro()
    if game_state == STATE_BOSS:
        state_boss()
    if game_state == STATE_GAME_OVER:
        state_game_over()
    if game_state == STATE_ALL_CLEAR:
        state_all_clear()

# ── Estado: título ───────────────────────────────────────────────────────────
def state_title():
    DRAW_VECTOR("init_screen", 0, 40)
    PRINT_TEXT(-70, -40, "PRESS A BUTTON")
    if J1_BUTTON_1():
        PLAY_MUSIC("intro")
        score = 0
        lives = LIVES_START
        current_level = 1
        if START_FLOOR > 0:
            current_level = START_FLOOR
        enter_game_start()

# ── Estado: pantalla "ROUND N" ───────────────────────────────────────────────
def state_game_start():
    SHOW_LEVEL()
    PRINT_TEXT(-30, 20, "ROUND")
    PRINT_NUMBER(30, 20, current_level)
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
        load_current_level()
        game_state = STATE_PLAYING

# ── Estado: gameplay ─────────────────────────────────────────────────────────
def state_playing():
    time_left = time_left - 1
    if time_left <= 0:
        if INVINCIBLE == 0:
            on_player_death()
    update_player()
    update_snowballs()
    UPDATE_ENEMIES()
    update_thaw()
    update_balls()
    ball_ball_collision()
    update_frog_fire()
    update_frog_bullet()
    check_snowball_enemy_collision()
    check_player_enemy_collision()

    SET_CAMERA_Y(camera_y)

    _t0 = GET_FRAME_US()
    draw_player()
    _t1 = GET_FRAME_US()
    draw_snowballs()
    draw_frog_bullet()
    _t2 = GET_FRAME_US()
    SET_INTENSITY(85)
    DRAW_ENEMIES()
    _t3 = GET_FRAME_US()
    draw_hud()
    enemy_count = count_active_enemies()
    if enemy_count <= 0:
        enter_level_clear()
    SHOW_LEVEL()
    _t4 = GET_FRAME_US()

    _dbg_ctr = _dbg_ctr + 1
    if _dbg_ctr >= 10:
        _dbg_ctr = 0
        DEBUG_PRINT_LABELED(1, _t1 - _t0)
        DEBUG_PRINT_LABELED(2, _t2 - _t1)
        DEBUG_PRINT_LABELED(3, _t3 - _t2)
        DEBUG_PRINT_LABELED(4, _t4 - _t3)

# ── Estado: muerte del jugador ───────────────────────────────────────────────
def state_player_dead():
    SHOW_LEVEL()
    draw_hud()
    draw_player_death()
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
        if lives <= 0:
            PLAY_MUSIC("Game_Over")
            frame_timer = GAME_OVER_DELAY
            game_state = STATE_GAME_OVER
        if lives > 0:
            enter_game_start()

def draw_player_death():
    SET_INTENSITY(65)
    stop_music()
    elapsed = DEATH_DELAY - frame_timer
    if elapsed < 12:
        DRAW_VECTOR("player_die1", player_x, player_y - camera_y, player_facing)
    else:
        if elapsed < 22:
            DRAW_VECTOR("player_die2", player_x, player_y - camera_y, player_facing)
        else:
            if elapsed < 32:
                DRAW_VECTOR("player_die3", player_x, player_y - camera_y, player_facing)
            else:
                DRAW_VECTOR("player_die4", player_x, player_y - camera_y, player_facing)

# ── Estado: nivel completado ─────────────────────────────────────────────────
def state_level_clear():
    if camera_y < scroll_target:
        camera_y = camera_y + 3
        if camera_y > scroll_target:
            camera_y = scroll_target
    SET_CAMERA_Y(camera_y)
    SHOW_LEVEL()
    draw_hud()
    PRINT_TEXT(-35, 0, "LEVEL CLEAR!")
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
        current_level = current_level + 1
        if current_level > 50:
            frame_timer = ALL_CLEAR_DELAY
            STOP_MUSIC()
            game_state = STATE_ALL_CLEAR
        if current_level <= 50:
            check_if_boss_level()
            if next_is_boss == 1:
                enter_boss_intro()
            if next_is_boss == 0:
                enter_game_start()

# ── Estado: aviso de boss ────────────────────────────────────────────────────
def state_boss_intro():
    PRINT_TEXT(-30, 20, "WARNING!")
    PRINT_TEXT(-50, 0, "BOSS INCOMING")
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
        load_current_level()
        play_boss_music()
        game_state = STATE_BOSS

# ── Estado: boss (placeholder) ───────────────────────────────────────────────
def state_boss():
    # TODO: lógica IA boss
    # TODO: patrones de ataque por nivel boss
    # TODO: detección de derrota del boss → enter_level_clear()
    update_player()
    update_snowballs()
    UPDATE_ENEMIES()
    check_snowball_enemy_collision()
    SHOW_LEVEL()
    draw_player()
    draw_snowballs()
    SET_INTENSITY(85)
    DRAW_ENEMIES()
    draw_hud()

# ── Estado: game over ────────────────────────────────────────────────────────
def state_game_over():
    PRINT_TEXT(-30, 20, "GAME OVER")
    PRINT_TEXT(-30, 0, "SCORE")
    PRINT_NUMBER(30, 0, score)
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
        STOP_MUSIC()
        game_state = STATE_TITLE

# ── Estado: all clear ────────────────────────────────────────────────────────
def state_all_clear():
    PRINT_TEXT(-55, 30, "CONGRATULATIONS!")
    PRINT_TEXT(-30, 5, "ALL CLEAR!")
    PRINT_TEXT(-25, -20, "SCORE")
    PRINT_NUMBER(30, -20, score)
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
        game_state = STATE_TITLE

# ── Transiciones ────────────────────────────────────────────────────────────
def enter_game_start():
    frame_timer = GAME_START_DELAY
    camera_y = CAMERA_Y_MIN + (current_level - 1) * 256
    if camera_y > 0:
        camera_y = 0
    SET_CAMERA_Y(camera_y)
    LOAD_LEVEL("world_1_1")
    game_state = STATE_GAME_START

def enter_level_clear():
    frame_timer = LEVEL_CLEAR_DELAY
    scroll_target = camera_y + 256
    if scroll_target > 0:
        scroll_target = 0
    game_state = STATE_LEVEL_CLEAR

def enter_boss_intro():
    PLAY_MUSIC("Boss_Intro")
    frame_timer = BOSS_INTRO_DELAY
    game_state = STATE_BOSS_INTRO

def on_player_death():
    lives = lives - 1
    frame_timer = DEATH_DELAY
    game_state = STATE_PLAYER_DEAD

# ── Detección nivel boss (múltiplos de 10) ───────────────────────────────────
def check_if_boss_level():
    next_is_boss = 0
    if current_level == 10:
        next_is_boss = 1
    if current_level == 20:
        next_is_boss = 1
    if current_level == 30:
        next_is_boss = 1
    if current_level == 40:
        next_is_boss = 1
    if current_level == 50:
        next_is_boss = 1

# ── Carga de nivel + música ──────────────────────────────────────────────────
def load_current_level():
    time_left = LEVEL_TIME
    player_x = 0
    camera_y = CAMERA_Y_MIN + (current_level - 1) * 256
    if camera_y > 0:
        camera_y = 0
    player_y = camera_y - 77   # punto de búsqueda; LEVEL_COLLISION_Y lo ajusta al suelo real
    player_vy = 0
    player_on_ground = 1
    shoot_cooldown = 0
    snow0_active = 0
    snow1_active = 0
    snow2_active = 0
    snow_life_max = SNOW_LIFE_NORMAL
    player_has_power = 0
    SET_CAMERA_Y(camera_y)
    reset_balls()
    reset_frog_fire()
    if current_level == 1:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 2:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 3:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 4:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 5:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 6:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Henshoku")
    if current_level == 7:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Henshoku")
    if current_level == 8:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 9:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 11:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 12:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        kill_offscreen_enemies()
        PLAY_MUSIC("Yukidama-Ondo")
    spawn_floor_y = GET_LEVEL_FLOOR_Y() + PLAYER_HH
    player_y = spawn_floor_y

def play_boss_music():
    if current_level == 10:
        PLAY_MUSIC("Boss_Intro")
    if current_level == 20:
        PLAY_MUSIC("Boss_Intro")
    if current_level == 30:
        PLAY_MUSIC("Boss_Intro")
    if current_level == 40:
        PLAY_MUSIC("Boss_Intro")
    if current_level == 50:
        PLAY_MUSIC("Boss_Intro")

# ── Jugador ──────────────────────────────────────────────────────────────────
def update_player():
    # Movimiento horizontal con joystick
    player_vx = clamp(J1_X() / 32, -4, 4)
    if player_vx > 0:
        player_facing = 0
    if player_vx < 0:
        player_facing = 1
    player_x = clamp(player_x + player_vx, WORLD_X_MIN, WORLD_X_MAX)
    push_dx = LEVEL_COLLISION_X(player_x, player_y, PLAYER_HW, PLAYER_HH)
    player_x = player_x + push_dx

    # Salto y validación de suelo: cada frame cuando está grounded
    if player_on_ground == 1:
        if J1_BUTTON_1():
            player_vy = JUMP_SPEED
            player_on_ground = 0
        if player_on_ground == 1:
            # Walkoff: ignore floors below visible screen (vplay has 1-screen data)
            floor_y = LEVEL_COLLISION_Y(player_x, player_y, PLAYER_HH)
            screen_bottom = camera_y - 127
            if floor_y < screen_bottom:
                floor_y = spawn_floor_y
            if floor_y < player_y:
                player_on_ground = 0

    # Gravedad, movimiento y colisión: solo cuando está en el aire
    if player_on_ground == 0:
        player_vy = player_vy - GRAVITY
        if player_vy < -MAX_FALL_SPEED:
            player_vy = -MAX_FALL_SPEED

        prev_y = player_y
        player_y = player_y + player_vy

        # Colisión con plataformas al caer (usa prev_y para evitar tunneling)
        if player_vy < 0:
            floor_y = LEVEL_COLLISION_Y(player_x, prev_y, PLAYER_HH)
            screen_bottom = camera_y - 127
            if floor_y < screen_bottom:
                floor_y = spawn_floor_y
            if player_y <= floor_y:
                player_y = floor_y
                player_vy = 0
                player_on_ground = 1

    # Límites de pantalla
    if player_y > WORLD_Y_MAX:
        player_y = WORLD_Y_MAX
        player_vy = 0
    screen_floor = spawn_floor_y
    if player_y < screen_floor:
        player_y = screen_floor
        player_vy = 0
        player_on_ground = 1

    # Disparo con botón 2
    if shoot_cooldown > 0:
        shoot_cooldown = shoot_cooldown - 1
    if J1_BUTTON_2():
        if shoot_cooldown == 0:
            ball_launched = 0
            try_launch_ball()
            if ball_launched == 0:
                snow_spawn_vx = SNOW_SPEED
                if player_facing == 1:
                    snow_spawn_vx = -SNOW_SPEED
                try_shoot()

def draw_player():
    SET_INTENSITY(65)
    if player_on_ground == 0:
        DRAW_VECTOR("player_jump", player_x, player_y - camera_y, player_facing)
    if player_on_ground == 1:
        if player_vx == 0:
            DRAW_VECTOR("player_idle", player_x, player_y - camera_y, player_facing)
        else:
            DRAW_ANIM("player_walk", player_x, player_y - camera_y, player_facing)

# ── Snowballs ────────────────────────────────────────────────────────────────
def try_shoot():
    if snow0_active == 0:
        snow0_x = player_x
        snow0_y = player_y
        snow0_vx = snow_spawn_vx
        snow0_vy = SNOW_LAUNCH_VY
        snow0_life = snow_life_max
        snow0_active = 1
        shoot_cooldown = SHOOT_COOLDOWN_MAX
        PLAY_SFX("shot_normal")
    else:
        if snow1_active == 0:
            snow1_x = player_x
            snow1_y = player_y
            snow1_vx = snow_spawn_vx
            snow1_vy = SNOW_LAUNCH_VY
            snow1_life = snow_life_max
            snow1_active = 1
            shoot_cooldown = SHOOT_COOLDOWN_MAX
            PLAY_SFX("shot_normal")
        else:
            if snow2_active == 0:
                snow2_x = player_x
                snow2_y = player_y
                snow2_vx = snow_spawn_vx
                snow2_vy = SNOW_LAUNCH_VY
                snow2_life = snow_life_max
                snow2_active = 1
                shoot_cooldown = SHOOT_COOLDOWN_MAX
                PLAY_SFX("shot_normal")

def update_snowballs():
    if snow0_active == 1:
        snow0_vy = snow0_vy - GRAVITY
        if snow0_vy < -MAX_FALL_SPEED:
            snow0_vy = -MAX_FALL_SPEED
        snow0_x = snow0_x + snow0_vx
        snow0_y = snow0_y + snow0_vy
        snow0_life = snow0_life - 1
        if snow0_life <= 0:
            snow0_active = 0
        if snow0_y - camera_y < -110:
            snow0_active = 0
        if snow0_x < -127:
            snow0_active = 0
        if snow0_x > 127:
            snow0_active = 0
    if snow1_active == 1:
        snow1_vy = snow1_vy - GRAVITY
        if snow1_vy < -MAX_FALL_SPEED:
            snow1_vy = -MAX_FALL_SPEED
        snow1_x = snow1_x + snow1_vx
        snow1_y = snow1_y + snow1_vy
        snow1_life = snow1_life - 1
        if snow1_life <= 0:
            snow1_active = 0
        if snow1_y - camera_y < -110:
            snow1_active = 0
        if snow1_x < -127:
            snow1_active = 0
        if snow1_x > 127:
            snow1_active = 0
    if snow2_active == 1:
        snow2_vy = snow2_vy - GRAVITY
        if snow2_vy < -MAX_FALL_SPEED:
            snow2_vy = -MAX_FALL_SPEED
        snow2_x = snow2_x + snow2_vx
        snow2_y = snow2_y + snow2_vy
        snow2_life = snow2_life - 1
        if snow2_life <= 0:
            snow2_active = 0
        if snow2_y - camera_y < -110:
            snow2_active = 0
        if snow2_x < -127:
            snow2_active = 0
        if snow2_x > 127:
            snow2_active = 0

def draw_snowballs():
    if snow0_active == 1:
        DRAW_CIRCLE(snow0_x, snow0_y - camera_y, 5, 120)
    if snow1_active == 1:
        DRAW_CIRCLE(snow1_x, snow1_y - camera_y, 5, 120)
    if snow2_active == 1:
        DRAW_CIRCLE(snow2_x, snow2_y - camera_y, 5, 120)

# ── HUD ──────────────────────────────────────────────────────────────────────
def draw_hud():
    #(rompe 6809)
    PRINT_NUMBER(0, 127, score)          # puntuación, arriba-izquierda
    PRINT_NUMBER(-78, 127, lives)           # vidas, debajo del score
    PRINT_NUMBER(58, 127, time_left / 60)   # tiempo en segundos, arriba-derecha


# ── Colisión nieve vs enemigos ────────────────────────────────────────────────
def check_snowball_enemy_collision():
    i = 0
    while i < 8:
        if GET_ENEMY_ACTIVE(i) == 1:
            ex = GET_ENEMY_X(i)
            ey = GET_ENEMY_Y(i)
            check_snow_vs_enemy(i, ex, ey)
        i = i + 1

def check_snow_vs_enemy(idx, ex, ey):
    thw = SNOW_HW + ENEMY_HW
    thh = SNOW_HH + ENEMY_HH
    if snow0_active == 1:
        dx = snow0_x - ex
        if dx < 0:
            dx = -dx
        dy = snow0_y - ey
        if dy < 0:
            dy = -dy
        if dx < thw:
            if dy < thh:
                snow0_active = 0
                on_snow_hit_enemy(idx)
    if snow1_active == 1:
        dx = snow1_x - ex
        if dx < 0:
            dx = -dx
        dy = snow1_y - ey
        if dy < 0:
            dy = -dy
        if dx < thw:
            if dy < thh:
                snow1_active = 0
                on_snow_hit_enemy(idx)
    if snow2_active == 1:
        dx = snow2_x - ex
        if dx < 0:
            dx = -dx
        dy = snow2_y - ey
        if dy < 0:
            dy = -dy
        if dx < thw:
            if dy < thh:
                snow2_active = 0
                on_snow_hit_enemy(idx)

def on_snow_hit_enemy(idx):
    ENEMY_FIRE_EVENT(idx, "onSnowHit")
    new_state = GET_ENEMY_STATE(idx)
    ticks = THAW_TICKS_SNOW
    if new_state == TITCHI_STATE_BALL:
        ticks = THAW_TICKS_BALL
    thaw_timers[idx] = ticks

def update_thaw():
    i = 0
    while i < 8:
        st = GET_ENEMY_STATE(i)
        if st > 0:
            if st < 4:
                if ball_rolling[i] == 0:
                    thaw_timers[i] = thaw_timers[i] - 1
                    if thaw_timers[i] <= 0:
                        st = st - 1
                        SET_ENEMY_STATE(i, st)
                        if st > 0:
                            thaw_timers[i] = THAW_TICKS_SNOW
        i = i + 1

# ── Cuenta enemigos activos directamente del pool ───────────────────────────
def count_active_enemies():
    n = 0
    i = 0
    while i < 8:
        if GET_ENEMY_ACTIVE(i) == 1:
            n = n + 1
        i = i + 1
    enemy_count = n

# ── Elimina enemigos fuera de la pantalla actual ────────────────────────────
def kill_offscreen_enemies():
    i = 0
    screen_min = camera_y - 128
    screen_max = camera_y + 128
    while i < 8:
        if GET_ENEMY_ACTIVE(i) == 1:
            ey = GET_ENEMY_Y(i)
            if ey < screen_min:
                KILL_ENEMY(i)
            if ey > screen_max:
                KILL_ENEMY(i)
        i = i + 1

# ── Reset del sistema de bolas al cargar nivel ──────────────────────────────
def reset_balls():
    i = 0
    while i < 8:
        ball_rolling[i] = 0
        ball_vx_arr[i] = 0
        ball_vy_arr[i] = 0
        ball_bounces[i] = 0
        ball_collided[i] = 0
        i = i + 1

# ── Lanzamiento de bola (si el jugador dispara tocando una bola) ─────────────
def try_launch_ball():
    i = 0
    found = 0
    while i < 8:
        if found == 0:
            if GET_ENEMY_ACTIVE(i) == 1:
                if GET_ENEMY_STATE(i) == TITCHI_STATE_BALL:
                    if ball_rolling[i] == 0:
                        ex = GET_ENEMY_X(i)
                        ey = GET_ENEMY_Y(i)
                        dx = player_x - ex
                        if dx < 0:
                            dx = -dx
                        dy = player_y - ey
                        if dy < 0:
                            dy = -dy
                        if dx < 25:
                            if dy < 25:
                                ball_rolling[i] = 1
                                ball_vx_arr[i] = BALL_SPEED
                                if player_facing == 1:
                                    ball_vx_arr[i] = -BALL_SPEED
                                ball_vy_arr[i] = 0
                                ball_bounces[i] = rand_range(3, 5)
                                thaw_timers[i] = 0
                                shoot_cooldown = SHOOT_COOLDOWN_MAX
                                ball_launched = 1
                                found = 1
        i = i + 1

# ── Física y colisión de bolas rodando ──────────────────────────────────────
def update_balls():
    i = 0
    while i < 8:
        if ball_rolling[i] == 1:
            # Gravedad vertical
            ball_vy_arr[i] = ball_vy_arr[i] - BALL_GRAVITY
            if ball_vy_arr[i] < -BALL_MAX_FALL:
                ball_vy_arr[i] = -BALL_MAX_FALL
            # Guardar posición anterior y calcular nueva
            prev_by = GET_ENEMY_Y(i)
            bx = GET_ENEMY_X(i) + ball_vx_arr[i]
            by = prev_by + ball_vy_arr[i]
            # Colisión con plataforma: raycast desde posición ANTERIOR
            # (igual que el player: prev_y → evita tunneling a través de plataformas)
            if ball_vy_arr[i] < 0:
                floor = LEVEL_COLLISION_Y(bx, prev_by, ENEMY_HH)
                screen_bottom = camera_y - 127
                if floor < screen_bottom:
                    floor = camera_y - 86
                if by <= floor:
                    by = floor
                    ball_vy_arr[i] = 0
            # Fallback: fondo del mundo
            if by < WORLD_Y_MIN:
                by = WORLD_Y_MIN
                ball_vy_arr[i] = 0
            # Rebote en paredes
            if bx < WORLD_X_MIN:
                bx = WORLD_X_MIN
                ball_vx_arr[i] = BALL_SPEED
                ball_bounces[i] = ball_bounces[i] - 1
            if bx > WORLD_X_MAX:
                bx = WORLD_X_MAX
                ball_vx_arr[i] = -BALL_SPEED
                ball_bounces[i] = ball_bounces[i] - 1
            push_dx = LEVEL_COLLISION_X(bx, by, ENEMY_HW, ENEMY_HH)
            if push_dx != 0:
                bx = bx + push_dx
                ball_vx_arr[i] = -ball_vx_arr[i]
            SET_ENEMY_X(i, bx)
            SET_ENEMY_Y(i, by)
            # Matar enemigos que toca
            ball_kill_enemies(bx, by)
            # ¿Se ha agotado el número de rebotes?
            if ball_bounces[i] <= 0:
                ball_rolling[i] = 0
                KILL_ENEMY(i)
        i = i + 1

# ── Colisión bola vs bola: repulsión tipo billar ────────────────────────────
# Guard ball_collided: cada par (i,j) se procesa una sola vez por frame.
# i invierte dirección; j hereda la dirección original de i (efecto billar).
def ball_ball_collision():
    k = 0
    while k < 8:
        ball_collided[k] = 0
        k = k + 1
    i = 0
    while i < 8:
        if ball_rolling[i] == 1:
            if ball_collided[i] == 0:
                bx = GET_ENEMY_X(i)
                by = GET_ENEMY_Y(i)
                j = 0
                while j < 8:
                    skip = 0
                    if i == j:
                        skip = 1
                    if skip == 0:
                        if ball_collided[j] == 0:
                            if GET_ENEMY_ACTIVE(j) == 1:
                                if GET_ENEMY_STATE(j) == TITCHI_STATE_BALL:
                                    ejx = GET_ENEMY_X(j)
                                    ejy = GET_ENEMY_Y(j)
                                    dx = bx - ejx
                                    if dx < 0:
                                        dx = -dx
                                    dy = by - ejy
                                    if dy < 0:
                                        dy = -dy
                                    if dx < 20:
                                        if dy < 20:
                                            old_vx = ball_vx_arr[i]
                                            ball_vx_arr[i] = -old_vx
                                            ball_vx_arr[j] = old_vx
                                            ball_rolling[j] = 1
                                            thaw_timers[j] = 0
                                            if ball_bounces[j] <= 0:
                                                ball_bounces[j] = rand_range(3, 5)
                                            ball_collided[i] = 1
                                            ball_collided[j] = 1
                    j = j + 1
        i = i + 1

# ── Colisión de bola rodando vs enemigos ────────────────────────────────────
def ball_kill_enemies(bx, by):
    j = 0
    while j < 8:
        if GET_ENEMY_ACTIVE(j) == 1:
            st = GET_ENEMY_STATE(j)
            if st < TITCHI_STATE_BALL:
                ejx = GET_ENEMY_X(j)
                ejy = GET_ENEMY_Y(j)
                dx = bx - ejx
                if dx < 0:
                    dx = -dx
                dy = by - ejy
                if dy < 0:
                    dy = -dy
                if dx < 24:
                    if dy < 24:
                        KILL_ENEMY(j)
                        score = score + 200
        j = j + 1

# ── Colisión jugador vs enemigos ──────────────────────────────────────────────
def check_player_enemy_collision():
    i = 0
    while i < 8:
        if GET_ENEMY_ACTIVE(i) == 1:
            st = GET_ENEMY_STATE(i)
            ex = GET_ENEMY_X(i)
            ey = GET_ENEMY_Y(i)
            dx = player_x - ex
            if dx < 0:
                dx = -dx
            dy = player_y - ey
            if dy < 0:
                dy = -dy
            if dx < 20:
                if dy < 20:
                    if st == TITCHI_STATE_NORMAL:
                        if INVINCIBLE == 0:
                            on_player_death()
                    if st != TITCHI_STATE_NORMAL:
                        # Empujar bola/snow lejos del jugador, bloquear al jugador
                        if ex >= player_x:
                            SET_ENEMY_X(i, player_x + 20)
                            player_x = player_x - 1
                        if ex < player_x:
                            SET_ENEMY_X(i, player_x - 20)
                            player_x = player_x + 1
        i = i + 1

# ── Frog fire system ──────────────────────────────────────────────────────
def reset_frog_fire():
    i = 0
    frog_bullet_active = 0
    while i < 8:
        frog_fire_timer[i] = FROG_FIRE_INTERVAL
        frog_fire_decay[i] = 0
        i = i + 1

def update_frog_fire():
    i = 0
    while i < 8:
        if GET_ENEMY_ACTIVE(i) == 1:
            st = GET_ENEMY_STATE(i)
            # Fire state decay: return to normal after 40 frames
            if st == FROG_STATE_FIRE_SIDE:
                frog_fire_decay[i] = frog_fire_decay[i] - 1
                if frog_fire_decay[i] <= 0:
                    SET_ENEMY_STATE(i, FROG_STATE_NORMAL)
                    frog_fire_timer[i] = FROG_FIRE_INTERVAL
            if st == FROG_STATE_FIRE_DOWN:
                frog_fire_decay[i] = frog_fire_decay[i] - 1
                if frog_fire_decay[i] <= 0:
                    SET_ENEMY_STATE(i, FROG_STATE_NORMAL)
                    frog_fire_timer[i] = FROG_FIRE_INTERVAL
            # Normal state: countdown to next shot
            if st == 0:
                frog_fire_timer[i] = frog_fire_timer[i] - 1
                if frog_fire_timer[i] <= 0:
                    frog_fire_timer[i] = FROG_FIRE_INTERVAL
                    ex = GET_ENEMY_X(i)
                    ey = GET_ENEMY_Y(i)
                    # Fire down if player is below and roughly aligned
                    fire_down_flag = 0
                    if player_y < ey - 20:
                        dx = player_x - ex
                        if dx < 0:
                            dx = -dx
                        if dx < 40:
                            fire_down_flag = 1
                    if fire_down_flag == 1:
                        ENEMY_FIRE_EVENT(i, "onFireDown")
                        new_st = GET_ENEMY_STATE(i)
                        if new_st == FROG_STATE_FIRE_DOWN:
                            frog_fire_decay[i] = 40
                            if frog_bullet_active == 0:
                                frog_bullet_x = ex
                                frog_bullet_y = ey
                                frog_bullet_vx = 0
                                frog_bullet_vy = -FROG_BULLET_DOWN_SPEED
                                frog_bullet_dir = 1
                                frog_bullet_mirror = 0
                                frog_bullet_active = 1
                    if fire_down_flag == 0:
                        # Face the player before firing sideways so the
                        # frog_fire_side sprite mirrors correctly (left/right).
                        face_left = 0
                        if player_x < ex:
                            face_left = 1
                        # pool.dir: 0=left, 1=right (mirrored against default_facing)
                        if face_left == 1:
                            SET_ENEMY_DIR(i, 0)
                        if face_left == 0:
                            SET_ENEMY_DIR(i, 1)
                        ENEMY_FIRE_EVENT(i, "onFireSide")
                        new_st = GET_ENEMY_STATE(i)
                        if new_st == FROG_STATE_FIRE_SIDE:
                            frog_fire_decay[i] = 40
                            if frog_bullet_active == 0:
                                frog_bullet_x = ex
                                frog_bullet_y = ey
                                frog_bullet_vx = FROG_BULLET_SPEED
                                if face_left == 1:
                                    frog_bullet_vx = -FROG_BULLET_SPEED
                                frog_bullet_vy = 0
                                frog_bullet_dir = 0
                                frog_bullet_mirror = face_left
                                frog_bullet_active = 1
        i = i + 1

def update_frog_bullet():
    if frog_bullet_active == 1:
        frog_bullet_x = frog_bullet_x + frog_bullet_vx
        frog_bullet_y = frog_bullet_y + frog_bullet_vy
        if frog_bullet_x < -127:
            frog_bullet_active = 0
        if frog_bullet_x > 127:
            frog_bullet_active = 0
        scr_y = frog_bullet_y - camera_y
        if scr_y < -127:
            frog_bullet_active = 0
        if scr_y > 127:
            frog_bullet_active = 0
        if frog_bullet_active == 1:
            dx = frog_bullet_x - player_x
            if dx < 0:
                dx = -dx
            dy = frog_bullet_y - player_y
            if dy < 0:
                dy = -dy
            if dx < FROG_BULLET_HW + PLAYER_HW:
                if dy < FROG_BULLET_HH + PLAYER_HH:
                    frog_bullet_active = 0
                    if INVINCIBLE == 0:
                        on_player_death()

def draw_frog_bullet():
    if frog_bullet_active == 1:
        SET_INTENSITY(110)
        scr_y = frog_bullet_y - camera_y
        if frog_bullet_dir == 0:
            DRAW_VECTOR("frog_fireball_side", frog_bullet_x, scr_y, frog_bullet_mirror)
        if frog_bullet_dir == 1:
            DRAW_VECTOR("frog_fireball_down", frog_bullet_x, scr_y, 0)
