META TITLE = "SNOW BROS"
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384
META MAX_ENEMIES = 8

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

# Half-sizes for AABB collision (approx from vec files)
const SNOW_HW = 6    # snowball half-width
const SNOW_HH = 16    # snowball half-height
const ENEMY_HW = 12  # enemy half-width
const ENEMY_HH = 8  # enemy half-height

# ── Globals de partida ──────────────────────────────────────────────────────
game_state: i16 = 0

score: i16 = 0              # TODO: usar u16/i32 cuando esté disponible
lives: i16 = 3
current_level: i16 = 1      # 1-50
time_left: i16 = 0          # frames restantes del nivel
enemy_count: i16 = 0        # enemigos vivos en pantalla
frame_timer: i16 = 0        # contador de delay para transiciones
next_is_boss: i16 = 0       # flag auxiliar para detección de nivel boss

# ── Player ──────────────────────────────────────────────────────────────────
player_x: i16 = 0
player_y: i16 = -120
player_vx: i16 = 0
player_vy: i16 = 0
player_facing: i16 = 0
player_on_ground: i16 = 0
floor_y: i16 = 0
prev_y: i16 = 0

# ── Physics ──────────────────────────────────────────────────────────────────
const GRAVITY = 1
const JUMP_SPEED = 11
const MAX_FALL_SPEED = 12
const PLAYER_HH = 11     # half-height de player_idle.vec

# ── World bounds (deben coincidir con worldBounds del .vplay) ────────────────
const WORLD_X_MIN = -96
const WORLD_X_MAX = 95
const WORLD_Y_MIN = -99    # suelo + margen sprite
const WORLD_Y_MAX = 127     # techo + margen sprite (pantalla llega a 127)

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
        score = 0
        lives = LIVES_START
        current_level = 1
        enter_game_start()

# ── Estado: pantalla "ROUND N" ───────────────────────────────────────────────
def state_game_start():
    PRINT_TEXT(-30, 20, "ROUND")
    PRINT_NUMBER(30, 20, current_level)
    PLAY_MUSIC("intro")
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
        load_current_level()
        game_state = STATE_PLAYING

# ── Estado: gameplay ─────────────────────────────────────────────────────────
def state_playing():
    time_left = time_left - 1
    if time_left <= 0:
        on_player_death()
    update_player()
    update_snowballs()
    UPDATE_ENEMIES()
    # update_balls()  # DEBUG: deshabilitado para ver si los saltos vienen de aquí
    check_snowball_enemy_collision()
    check_player_enemy_collision()

    draw_player()
    draw_snowballs()
    DRAW_ENEMIES()
    draw_hud()
    if enemy_count <= 0:
        enter_level_clear()
    SHOW_LEVEL()

# ── Estado: muerte del jugador ───────────────────────────────────────────────
def state_player_dead():
    SHOW_LEVEL()
    draw_hud()
    draw_player_death()
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
        if lives <= 0:
            PLAY_MUSIC("Game_Over")
        if lives > 0:
            enter_game_start()

def draw_player_death():
    SET_INTENSITY(65)
    elapsed = DEATH_DELAY - frame_timer
    if elapsed < 12:
        DRAW_VECTOR("player_die1", player_x, player_y, player_facing)
    else:
        if elapsed < 22:
            DRAW_VECTOR("player_die2", player_x, player_y, player_facing)
        else:
            if elapsed < 32:
                DRAW_VECTOR("player_die3", player_x, player_y, player_facing)
            else:
                DRAW_VECTOR("player_die4", player_x, player_y, player_facing)

# ── Estado: nivel completado ─────────────────────────────────────────────────
def state_level_clear():
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
    DRAW_ENEMIES()
    draw_hud()

# ── Estado: game over ────────────────────────────────────────────────────────
    PRINT_TEXT(-35, 20, "GAME OVER")
    PRINT_TEXT(-25, -10, "SCORE")
    PRINT_NUMBER(30, -10, score)
    if J1_BUTTON_1():
        STOP_MUSIC()
        game_state = STATE_TITLE

# ── Estado: game over ────────────────────────────────────────────────────────
def state_game_over():
    PRINT_TEXT(-30, 20, "GAME OVER")
    PRINT_TEXT(-30, 0, "SCORE")
    PRINT_NUMBER(30, 0, score)
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
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
    game_state = STATE_GAME_START

def enter_level_clear():
    frame_timer = LEVEL_CLEAR_DELAY
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
    enemy_count = 2     # world_1_1 has 2 enemies
    player_x = 0
    player_y = -114
    player_vy = 0
    player_on_ground = 0
    shoot_cooldown = 0
    snow0_active = 0
    snow1_active = 0
    snow2_active = 0
    snow_life_max = SNOW_LIFE_NORMAL
    player_has_power = 0
    if current_level == 1:
        LOAD_LEVEL("world_1_1")
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 2:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_2
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 3:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_3
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 4:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_4
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 5:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_5
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 6:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_6
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Henshoku")
    if current_level == 7:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_7
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Henshoku")
    if current_level == 8:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_8
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 9:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_9
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 11:
        LOAD_LEVEL("world_1_1")         # TODO: world_2_1
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 12:
        LOAD_LEVEL("world_1_1")         # TODO: world_2_2
        SPAWN_ENEMIES("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    # TODO: niveles 13-50

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

    # Salto y validación de suelo: cada frame cuando está grounded
    if player_on_ground == 1:
        if J1_BUTTON_1():
            player_vy = JUMP_SPEED
            player_on_ground = 0
        if player_on_ground == 1:
            # Verificar que sigue habiendo suelo bajo el jugador (walkoff detection)
            floor_y = LEVEL_COLLISION_Y(player_x, player_y, PLAYER_HH)
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
        if player_vy <= 0:
            floor_y = LEVEL_COLLISION_Y(player_x, prev_y, PLAYER_HH)
            if player_y <= floor_y:
                player_y = floor_y
                player_vy = 0
                player_on_ground = 1

    # Límites de pantalla
    if player_y > WORLD_Y_MAX:
        player_y = WORLD_Y_MAX
        player_vy = 0
    if player_y < WORLD_Y_MIN:
        player_y = WORLD_Y_MIN
        player_vy = 0
        player_on_ground = 1

    # Disparo con botón 2
    if shoot_cooldown > 0:
        shoot_cooldown = shoot_cooldown - 1
    if J1_BUTTON_2():
        if shoot_cooldown == 0:
            snow_spawn_vx = SNOW_SPEED
            if player_facing == 1:
                snow_spawn_vx = -SNOW_SPEED
            try_shoot()

def draw_player():
    SET_INTENSITY(65)
    if player_on_ground == 0:
        DRAW_VECTOR("player_jump", player_x, player_y, player_facing)
    if player_on_ground == 1:
        if player_vx == 0:
            DRAW_VECTOR("player_idle", player_x, player_y, player_facing)
        else:
            DRAW_ANIM("player_walk", player_x, player_y, player_facing)

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
        if snow0_y < -110:
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
        if snow1_y < -110:
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
        if snow2_y < -110:
            snow2_active = 0
        if snow2_x < -127:
            snow2_active = 0
        if snow2_x > 127:
            snow2_active = 0

def draw_snowballs():
    if snow0_active == 1:
        DRAW_CIRCLE(snow0_x, snow0_y, 5, 120)
    if snow1_active == 1:
        DRAW_CIRCLE(snow1_x, snow1_y, 5, 120)
    if snow2_active == 1:
        DRAW_CIRCLE(snow2_x, snow2_y, 5, 120)

# ── HUD ──────────────────────────────────────────────────────────────────────
def draw_hud():
    #(rompe 6809)
    PRINT_NUMBER(-10, 127, score)          # puntuación, arriba-izquierda
    PRINT_NUMBER(-78, 116, lives)           # vidas, debajo del score
    PRINT_NUMBER(58, 127, time_left / 60)   # tiempo en segundos, arriba-derecha
    # DEBUG: titchi superior (idx 1) — waypoints (y=99,y=99): Y debe ser constante
    PRINT_TEXT(-98, -110, "Y")
    PRINT_NUMBER(-85, -110, GET_ENEMY_Y(1))
    PRINT_TEXT(-25, -110, "X")
    PRINT_NUMBER(-10, -110, GET_ENEMY_X(1))
    PRINT_TEXT(40, -110, "S")
    PRINT_NUMBER(55, -110, GET_ENEMY_STATE(1))

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

# ── Gravedad sobre bolas/snow (caen por precipicios) ────────────────────────
# - Si LEVEL_COLLISION_Y devuelve <= -100 (sentinel "no floor"), no cae
#   (evita caer infinitamente al ser empujado fuera del nivel).
# - Cae sólo si gap > ENEMY_HH (mismatch de patrol_y vs platform_top no aplica).
def update_balls():
    i = 0
    while i < 8:
        if GET_ENEMY_ACTIVE(i) == 1:
            st = GET_ENEMY_STATE(i)
            if st != TITCHI_STATE_NORMAL:
                ex = GET_ENEMY_X(i)
                ey = GET_ENEMY_Y(i)
                floor = LEVEL_COLLISION_Y(ex, ey, ENEMY_HH)
                if floor > -100:
                    gap = ey - floor
                    if gap > ENEMY_HH:
                        new_y = ey - 3
                        if new_y < floor:
                            new_y = floor
                        SET_ENEMY_Y(i, new_y)
        i = i + 1

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
                        # Sólo muere el jugador al tocar un TITCHI patrullando
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
