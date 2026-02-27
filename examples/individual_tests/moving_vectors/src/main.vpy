# TEST: MOVING_VECTORS
# Tests DRAW_VECTOR at dynamic positions with bouncing motion
# Expected: ball and bubble move around screen, hit SFX on wall bounce

META TITLE = "MOVINGVEC"
META MUSIC = music1

# Ball state
ball_x = 0
ball_y = 20
ball_vx = 3
ball_vy = 2

# Bubble state
bub_x = -30
bub_y = -20
bub_vx = -2
bub_vy = 3

def main():
    PLAY_MUSIC("music1")
    ball_x = 0
    ball_y = 20
    ball_vx = 3
    ball_vy = 2
    bub_x = -30
    bub_y = -20
    bub_vx = -2
    bub_vy = 3

def loop():
    PRINT_TEXT(-60, 110, "MOVING VEC")

    # Move ball
    ball_x = ball_x + ball_vx
    ball_y = ball_y + ball_vy

    # Bounce ball (radius=3) — edge hits wall, not center
    if ball_x > 97:
        ball_vx = 0 - ball_vx
        ball_x = 97
        PLAY_SFX("hit")

    if ball_x < -97:
        ball_vx = 0 - ball_vx
        ball_x = -97
        PLAY_SFX("hit")

    if ball_y > 77:
        ball_vy = 0 - ball_vy
        ball_y = 77
        PLAY_SFX("hit")

    if ball_y < -77:
        ball_vy = 0 - ball_vy
        ball_y = -77
        PLAY_SFX("hit")

    # Move bubble
    bub_x = bub_x + bub_vx
    bub_y = bub_y + bub_vy

    # Bounce bubble (radius=10) — edge hits wall, not center
    if bub_x > 90:
        bub_vx = 0 - bub_vx
        bub_x = 90
        PLAY_SFX("hit")

    if bub_x < -90:
        bub_vx = 0 - bub_vx
        bub_x = -90
        PLAY_SFX("hit")

    if bub_y > 70:
        bub_vy = 0 - bub_vy
        bub_y = 70
        PLAY_SFX("hit")

    if bub_y < -70:
        bub_vy = 0 - bub_vy
        bub_y = -70
        PLAY_SFX("hit")

    # Draw sprites at their positions
    DRAW_VECTOR("ball", ball_x, ball_y)
    DRAW_VECTOR("bubble_small", bub_x, bub_y)

    # Draw boundary box
    DRAW_LINE(-100, 80, 100, 80, 60)
    DRAW_LINE(100, 80, 100, -80, 60)
    DRAW_LINE(100, -80, -100, -80, 60)
    DRAW_LINE(-100, -80, -100, 80, 60)
