# VECTREX PONG - Full Game Example
# Control: Use joystick to move paddle up/down
# Goal: Destroy all bricks and don't let the ball get past!

META TITLE = "PONG"
META MUSIC = music1

# CONSTANTS

SCREEN_WIDTH: i16 = 115
SCREEN_HEIGHT: i16 = 115
PADDLE_WIDTH: i16 = 10
PADDLE_HEIGHT: i16 = 30
BALL_RADIUS: i8 = 3
BRICK_WIDTH: i16 = 20
BRICK_HEIGHT: i16 = 10
BRICK_COLS: u8 = 4
BRICK_ROWS: u8 = 3
TOTAL_BRICKS: u8 = 12

# VARIABLES
score: u16 = 0
lives: u8 = 3
level_complete: u8 = 0
game_state: u8 = 0  # 0=TITLE, 1=PLAY, 2=GAMEOVER

ball_x: i16 = 0
ball_y: i16 = 0
ball_vx: i8 = 2
ball_vy: i8 = 1

player_y: i16 = 0
ai_y: i16 = 0

brick_active = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  # Brick states

def clamp(value , min_val, max_val):
    if value < min_val:
        return min_val
    if value > max_val:
        return max_val
    return value

def check_brick_collision():
    for i in range(TOTAL_BRICKS):
        if brick_active[i] == 0:
            continue

        col = i % BRICK_COLS
        row = i / BRICK_COLS

        brick_x = -100 + col * BRICK_WIDTH
        brick_y = 80 - row * BRICK_HEIGHT

        # AABB collision
        if ball_x > brick_x and ball_x < brick_x + BRICK_WIDTH:
            if ball_y > brick_y and ball_y < brick_y + BRICK_HEIGHT:
                brick_active[i] = 0
                ball_vy = -ball_vy
                return 1

    return 0

def check_paddle_collision():
    # Check player paddle (bottom)
    if ball_y < -100 + PADDLE_HEIGHT:
        if ball_x > player_y - PADDLE_WIDTH and ball_x < player_y + PADDLE_WIDTH:
            ball_vy = -ball_vy
            return 1

    # Check AI paddle (top)
    if ball_y > 100 - PADDLE_HEIGHT:
        if ball_x > ai_y - PADDLE_WIDTH and ball_x < ai_y + PADDLE_WIDTH:
            ball_vy = -ball_vy
            return 1

    return 0

def draw_title():
    PRINT_TEXT(-80, 50, "VECTREX PONG")
    PRINT_TEXT(-110, 30, "PRESS ANY BUTTON")
    PRINT_TEXT(-55, 10, "TO START")

def draw_game():
    # Draw bricks
    for i in range(TOTAL_BRICKS):
        if brick_active[i] == 1:
            col = i % BRICK_COLS
            row = i / BRICK_COLS
            brick_x = -100 + col * BRICK_WIDTH
            brick_y = 80 - row * BRICK_HEIGHT
            DRAW_RECT(brick_x, brick_y, BRICK_WIDTH, BRICK_HEIGHT, 80)

    # Draw paddles
    DRAW_RECT(player_y, -105, PADDLE_WIDTH, PADDLE_HEIGHT, 80)
    DRAW_RECT(ai_y, 105, PADDLE_WIDTH, PADDLE_HEIGHT, 80)

    # Draw ball
    DRAW_CIRCLE(ball_x, ball_y, BALL_RADIUS, 80)

    # Draw score and lives
    #PRINT_NUMBER(-110, -110, score)
    #PRINT_TEXT(80, -110, "LIVES")
    #PRINT_NUMBER(110, -110, lives)

def draw_gameover():
    PRINT_TEXT(-20, 50, "GAME OVER")
    PRINT_TEXT(-10, 0, "SCORE:")
    PRINT_NUMBER(30, 0, score)
    PRINT_TEXT(-20, -40, "Press to Restart")

def setup():
    SET_INTENSITY(80)
    game_state = 0

def loop():
    UPDATE_BUTTONS()

    if game_state == 0:  # TITLE
        draw_title()
        if J1_BUTTON_1() == 1:
            game_state = 1
            score = 0
            lives = 3

    elif game_state == 1:  # PLAY
        # Update player paddle
        PRINT_TEXT(-10, 0, "SCORE:")
        return
        player_y = J1_Y()
        player_y = clamp(player_y, -105, 105)

        # AI follows ball (simple AI)
        if ai_y < ball_x - 10:
            ai_y = ai_y + 1
        elif ai_y > ball_x + 10:
            ai_y = ai_y - 1
        ai_y = clamp(ai_y, -105, 105)

        # Update ball
        ball_x = ball_x + ball_vx
        ball_y = ball_y + ball_vy

        # Wall collisions
        if ball_x > SCREEN_WIDTH:
            ball_vx = -ball_vx
            ball_x = SCREEN_WIDTH - 1
        if ball_x < -SCREEN_WIDTH:
            ball_vx = -ball_vx
            ball_x = -SCREEN_WIDTH + 1

        # Check collisions
        check_brick_collision()
        check_paddle_collision()

        # Ball out of bounds (lost)
        if ball_y < -SCREEN_HEIGHT:
            lives = lives - 1
            if lives == 0:
                game_state = 2
            else:
                ball_x = 0
                ball_y = 0
                ball_vx = 2
                ball_vy = 1

        # Win condition (all bricks destroyed)
        if level_complete == 0:
            bricks_left = 0
            for i in range(TOTAL_BRICKS):
                if brick_active[i] == 1:
                    bricks_left = bricks_left + 1
            if bricks_left == 0:
                score = score + 100
                level_complete = 1

        #draw_game()

    elif game_state == 2:  # GAMEOVER
        draw_gameover()
        if J1_BUTTON_1() == 1:
            game_state = 0