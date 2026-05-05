META TITLE = "SNOW BROS"
META ROM_TOTAL_SIZE = 131072
META ROM_BANK_SIZE = 16384
META MAX_ENEMIES = 8

# ── States ──────────────────────────────────────────────────────────────────
STATE_TITLE: i16 = 0        # título + "press a button"
STATE_GAME_START: i16 = 1   # "ROUND N" antes de empezar
STATE_PLAYING: i16 = 2      # gameplay activo
STATE_PLAYER_DEAD: i16 = 3  # animación de muerte + delay
STATE_LEVEL_CLEAR: i16 = 4  # todos los enemigos derrotados
STATE_BOSS_INTRO: i16 = 5   # pantalla de aviso boss (niveles múltiplos de 10)
STATE_BOSS: i16 = 6         # combate boss
STATE_GAME_OVER: i16 = 7    # game over
STATE_ALL_CLEAR: i16 = 8    # completados los 50 niveles

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
anim_tick: i16 = 0          # debug counter para animación manual
walk_frame: i16 = 0         # 0-3: frame seleccionado manualmente
player_x: i16 = 0
player_y: i16 = -114
player_vx: i16 = 0
player_vy: i16 = 0
player_facing: i16 = 0
player_on_ground: i16 = 0
floor_y: i16 = 0
prev_y: i16 = 0

# ── Physics ──────────────────────────────────────────────────────────────────
GRAVITY: i16 = 1
JUMP_SPEED: i16 = 13
MAX_FALL_SPEED: i16 = 12
PLAYER_HH: i16 = 14     # half-height de player_idle.vec

# ── World bounds (deben coincidir con worldBounds del .vplay) ────────────────
WORLD_X_MIN: i16 = -96
WORLD_X_MAX: i16 = 95

# ── Snowball system ───────────────────────────────────────────────────────────
SNOW_SPEED: i16 = 5             # velocidad horizontal
SNOW_LAUNCH_VY: i16 = 3        # arco inicial hacia arriba
SNOW_LIFE_NORMAL: i16 = 14     # frames de vida sin power-up (~70px)
SNOW_LIFE_POWER: i16 = 30      # frames de vida con power-up (~150px)
SHOOT_COOLDOWN_MAX: i16 = 15   # frames entre disparos

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
LEVEL_TIME: i16 = 3600      # 60 segundos por nivel
LIVES_START: i16 = 3
GAME_START_DELAY: i16 = 120
DEATH_DELAY: i16 = 120
LEVEL_CLEAR_DELAY: i16 = 150
BOSS_INTRO_DELAY: i16 = 180
ALL_CLEAR_DELAY: i16 = 300

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
    DRAW_VECTOR("init_screen", 0, 0)
    PRINT_TEXT(-50, -90, "PRESS A BUTTON")
    if J1_BUTTON_1():
        score = 0
        lives = LIVES_START
        current_level = 1
        enter_game_start()

# ── Estado: pantalla "ROUND N" ───────────────────────────────────────────────
def state_game_start():
    PRINT_TEXT(-30, 20, "ROUND")
    PRINT_NUMBER(20, 20, current_level)
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
    # TODO: check_player_enemy_collision()
    # TODO: check_snowball_enemy_collision()
    SHOW_LEVEL()
    draw_player()
    draw_snowballs()
    DRAW_ENEMIES()
    draw_hud()
    if enemy_count <= 0:
        enter_level_clear()

# ── Estado: muerte del jugador ───────────────────────────────────────────────
def state_player_dead():
    SHOW_LEVEL()
    draw_hud()
    # TODO: draw_player_death_anim()
    frame_timer = frame_timer - 1
    if frame_timer <= 0:
        if lives <= 0:
            PLAY_MUSIC("Game_Over")
            game_state = STATE_GAME_OVER
        if lives > 0:
            enter_game_start()

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
    SHOW_LEVEL()
    draw_player()
    draw_snowballs()
    DRAW_ENEMIES()
    draw_hud()

# ── Estado: game over ────────────────────────────────────────────────────────
def state_game_over():
    PRINT_TEXT(-35, 20, "GAME OVER")
    PRINT_TEXT(-25, -10, "SCORE")
    PRINT_NUMBER(30, -10, score)
    if J1_BUTTON_1():
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
    #debug
    
    #PRINT_NUMBER(-20, 120, player_facing)
    

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
    if player_y > 110:
        player_y = 110
        player_vy = 0
    if player_y < -110:
        player_y = -110
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
    if player_on_ground == 0:
        DRAW_VECTOR("player_jump", player_x, player_y, player_facing)
    if player_on_ground == 1:
        if player_vx == 0:
            DRAW_VECTOR("player_idle", player_x, player_y, player_facing)
        else:
            # DEBUG: animación manual sin pitrex_draw_anim
            anim_tick = anim_tick + 1
            if anim_tick > 31:
                anim_tick = 0
            walk_frame = anim_tick / 8
            if walk_frame == 0:
                DRAW_VECTOR("player_walk1", player_x, player_y, player_facing)
            if walk_frame == 1:
                DRAW_VECTOR("player_walk2", player_x, player_y, player_facing)
            if walk_frame == 2:
                DRAW_VECTOR("player_walk3", player_x, player_y, player_facing)
            if walk_frame == 3:
                DRAW_VECTOR("player_walk4", player_x, player_y, player_facing)
            PRINT_NUMBER(0, 120, walk_frame)  # debug: debe ciclar 0→1→2→3

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
    else:
        if snow1_active == 0:
            snow1_x = player_x
            snow1_y = player_y
            snow1_vx = snow_spawn_vx
            snow1_vy = SNOW_LAUNCH_VY
            snow1_life = snow_life_max
            snow1_active = 1
            shoot_cooldown = SHOOT_COOLDOWN_MAX
        else:
            if snow2_active == 0:
                snow2_x = player_x
                snow2_y = player_y
                snow2_vx = snow_spawn_vx
                snow2_vy = SNOW_LAUNCH_VY
                snow2_life = snow_life_max
                snow2_active = 1
                shoot_cooldown = SHOOT_COOLDOWN_MAX

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
    PRINT_NUMBER(-80, 110, score)          # puntuación, arriba-izquierda
    PRINT_NUMBER(-80, 95, lives)           # vidas, debajo del score
    PRINT_NUMBER(60, 110, time_left / 60)   # tiempo en segundos, arriba-derecha
