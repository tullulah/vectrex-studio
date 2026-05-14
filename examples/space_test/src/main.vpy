# VPy SPACE TEST - Basic Space Shooter
META TITLE = "SPACE TEST"

# CONSTANTS
SCREEN_WIDTH: i16 = 115
SCREEN_HEIGHT: i16 = 115
PLAYER_SIZE: i16 = 8
ENEMY_SIZE: i16 = 6
BULLET_SPEED: i8 = 4

# VARIABLES
game_state: u8 = 0  # 0=TITLE, 1=PLAY, 2=GAMEOVER
score: u16 = 0
player_x: i16 = 0
player_y: i16 = -90

bullet_active: u8 = 0
bullet_x: i16 = 0
bullet_y: i16 = 0

enemy_active: u8 = 1
enemy_x: i16 = 0
enemy_y: i16 = 100
enemy_vx: i8 = 1

def reset_enemy():
    enemy_x = 0
    enemy_y = 100
    enemy_active = 1

def draw_player():
    # Triángulo simple para la nave
    DRAW_LINE(player_x, player_y, player_x - PLAYER_SIZE, player_y - PLAYER_SIZE, 80)
    DRAW_LINE(player_x, player_y, player_x + PLAYER_SIZE, player_y - PLAYER_SIZE, 80)
    DRAW_LINE(player_x - PLAYER_SIZE, player_y - PLAYER_SIZE, player_x + PLAYER_SIZE, player_y - PLAYER_SIZE, 80)

def draw_enemy():
    if enemy_active == 1:
        DRAW_RECT(enemy_x, enemy_y, ENEMY_SIZE, ENEMY_SIZE, 80)

def draw_bullet():
    if bullet_active == 1:
        DRAW_LINE(bullet_x, bullet_y, bullet_x, bullet_y + 2, 80)

def setup():
    SET_INTENSITY(80)
    game_state = 0

def loop():
    UPDATE_BUTTONS()

    if game_state == 0:
        PRINT_TEXT(-50, 20, "SPACE SHOOTER")
        PRINT_TEXT(-60, 0, "PRESS BUTTON 1")
        if J1_BUTTON_1() == 1:
            game_state = 1
            score = 0
            reset_enemy()

    elif game_state == 1:
        # Mover Jugador
        player_x = J1_X()
        
        # Disparo
        if J1_BUTTON_1() == 1 and bullet_active == 0:
            bullet_active = 1
            bullet_x = player_x
            bullet_y = player_y

        # Actualizar Bala
        if bullet_active == 1:
            bullet_y = bullet_y + BULLET_SPEED
            if bullet_y > SCREEN_HEIGHT:
                bullet_active = 0
            
            # Colisión Bala vs Enemigo
            if enemy_active == 1:
                if bullet_x > enemy_x - ENEMY_SIZE and bullet_x < enemy_x + ENEMY_SIZE:
                    if bullet_y > enemy_y - ENEMY_SIZE and bullet_y < enemy_y + ENEMY_SIZE:
                        enemy_active = 0
                        bullet_active = 0
                        score = score + 10

        # Actualizar Enemigo
        if enemy_active == 1:
            enemy_y = enemy_y - 1
            enemy_x = enemy_x + enemy_vx
            if enemy_x > 100 or enemy_x < -100:
                enemy_vx = -enemy_vx
            
            if enemy_y < player_y:
                game_state = 2 # Game Over
        else:
            reset_enemy()

        # Renderizado
        draw_player()
        draw_enemy()
        draw_bullet()
        PRINT_NUMBER(-100, 100, score)

    elif game_state == 2:
        PRINT_TEXT(-30, 20, "GAME OVER")
        PRINT_TEXT(-20, 0, "SCORE:")
        PRINT_NUMBER(10, 0, score)
        if J1_BUTTON_1() == 1:
            game_state = 0
