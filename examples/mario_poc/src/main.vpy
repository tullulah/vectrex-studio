META TITLE = "SUPER MARIO POC"

# Player world position
player_x: i16 = 0
player_y: i16 = -70

# Physics
vel_y: i8 = 0
on_ground: u8 = 1

# Camera
camera_x: i16 = 0

def main():
    LOAD_LEVEL("world_1_1")
    PLAY_MUSIC("overworld")

def loop():
    joy_x = J1_X()
    btn_jump = J1_BUTTON_1()

    # Horizontal movement
    if joy_x > 20:
        player_x = player_x + 3
    if joy_x < -20:
        player_x = player_x - 3

    # Clamp player to level bounds
    player_x = clamp(player_x, -100, 1050)

    # Jump
    if btn_jump == 1:
        if on_ground == 1:
            vel_y = 12
            on_ground = 0
            PLAY_SFX("jump")

    # Apply gravity when airborne
    if on_ground == 0:
        player_y = player_y + vel_y
        vel_y = vel_y - 1

        # Ground collision
        if player_y <= -70:
            player_y = -70
            vel_y = 0
            on_ground = 1

    # Camera follows player (player appears at screen_x = -30)
    camera_x = player_x + 30
    camera_x = clamp(camera_x, 0, 970)

    SET_CAMERA_X(camera_x)
    SHOW_LEVEL()

    # Draw player at fixed screen position
    DRAW_VECTOR("mario", -30, player_y)
