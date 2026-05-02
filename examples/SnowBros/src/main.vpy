META TITLE = "SNOW BROS"

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
player_x: i16 = 0
player_y: i16 = -100
player_vx: i16 = 0
player_vy: i16 = 0
player_facing: i16 = 0

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
    # TODO: update_enemies()
    # TODO: check_player_enemy_collision()
    # TODO: check_snowball_enemy_collision()
    SHOW_LEVEL()
    draw_player()
    # TODO: draw_enemies()
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
    SHOW_LEVEL()
    draw_player()
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
    enemy_count = 1     # TODO: leer de datos del nivel
    player_x = 0
    player_y = -100
    if current_level == 1:
        LOAD_LEVEL("world_1_1")
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 2:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_2
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 3:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_3
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 4:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_4
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 5:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_5
        PLAY_MUSIC("Yukidama-Ondo")
    if current_level == 6:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_6
        PLAY_MUSIC("Henshoku")
    if current_level == 7:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_7
        PLAY_MUSIC("Henshoku")
    if current_level == 8:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_8
        PLAY_MUSIC("Yukida-March")
    if current_level == 9:
        LOAD_LEVEL("world_1_1")         # TODO: world_1_9
        PLAY_MUSIC("Yukida-March")
    if current_level == 11:
        LOAD_LEVEL("world_1_1")         # TODO: world_2_1
        PLAY_MUSIC("Dosukoi-Snow")
    if current_level == 12:
        LOAD_LEVEL("world_1_1")         # TODO: world_2_2
        PLAY_MUSIC("Dosukoi-Snow")
    # TODO: niveles 13-50

def play_boss_music():
    if current_level == 10:
        PLAY_MUSIC("Boss_de_Ska")
    if current_level == 20:
        PLAY_MUSIC("Yoh")
    if current_level == 30:
        PLAY_MUSIC("Boss-Yade")
    if current_level == 40:
        PLAY_MUSIC("Dosukoi-Snow")
    if current_level == 50:
        PLAY_MUSIC("Boss_de_Ska")

# ── Jugador ──────────────────────────────────────────────────────────────────
def update_player():
    player_vx = clamp(J1_X() / 64, -3, 3)
    player_vy = clamp(J1_Y() / 64, -3, 3)
    player_x = clamp(player_x + player_vx, -120, 120)
    player_y = clamp(player_y + player_vy, -120, 120)
    if player_vx < 0:
        player_facing = 1
    if player_vx > 0:
        player_facing = 0

def draw_player():
    if player_vx == 0:
        DRAW_VECTOR("player_idle", player_x, player_y, player_facing)
    else:
        DRAW_ANIM("player_walk", player_x, player_y, player_facing, 80, 1)

# ── HUD ──────────────────────────────────────────────────────────────────────
def draw_hud():
    PRINT_NUMBER(-80, 110, score)          # puntuación, arriba-izquierda
    PRINT_NUMBER(-80, 95, lives)           # vidas, debajo del score
    PRINT_NUMBER(60, 110, time_left / 60)   # tiempo en segundos, arriba-derecha
