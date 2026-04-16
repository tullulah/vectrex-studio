# TEST: PHYSICS_BALL
# Tests arcade-style physics: gravity, bounce, joystick control
# Expected: bubble falls with gravity, bounces off floor/walls
# BTN1=jump, joystick=horizontal push, music+SFX on bounce

META TITLE = "PHYSICS"
META MUSIC = music1

bx = 0
by = 60
vx = 1
vy = 0
jx = 0

def main():
    PLAY_MUSIC("music1")
    bx = 0
    by = 60
    vx = 1
    vy = 0

def loop():
    PRINT_TEXT(-50, 100, "PHYSICS")
    PRINT_TEXT(-50, 85, "B1=JUMP")

    # Apply gravity
    vy = vy - 1

    # Joystick horizontal control — literal comparisons avoid MUL16
    jx = J1_X()
    if jx > 40:
        vx = vx + 1
    if jx < -40:
        vx = vx - 1

    # Jump button
    if J1_BUTTON_1():
        vy = 8
        PLAY_SFX("jump")

    # Clamp horizontal velocity — literals avoid MUL16
    if vx > 6:
        vx = 6
    if vx < -6:
        vx = -6

    # Apply velocity
    bx = bx + vx
    by = by + vy

    # Floor bounce — use 0-vy instead of -vy to avoid MUL16 hang
    if by < -90:
        by = -90
        vy = 0 - vy
        if vy > 12:
            vy = 12
        PLAY_SFX("hit")

    # Ceiling bounce
    if by > 90:
        by = 90
        vy = 0 - vy

    # Wall bounces — use literals and 0-vx to avoid MUL16 hang
    if bx > 100:
        bx = 100
        vx = 0 - vx
        PLAY_SFX("hit")

    if bx < -100:
        bx = -100
        vx = 0 - vx
        PLAY_SFX("hit")

    # Draw bubble at physics position
    DRAW_VECTOR("bubble_medium", bx, by)

    # Draw floor line with literal coords
    DRAW_LINE(-100, -110, 100, -110, 60)
