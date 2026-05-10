# test_scroll - horizontal scroll + player character (no physics yet)
# Joystick X: move player left/right; camera follows.

META TITLE = "TEST SCROLL"

# Player world position
player_x: i16 = 0
player_y: i16 = 30  # below center, on the ground line

# Walking state
is_walking: u8 = 0

# Camera state (16-bit world units)
camera_x: i16 = 0
scroll_left:  i16 = 0
scroll_right: i16 = 0
scroll_right_edge: i16 = 0
screen_x: i16 = 0

def main():
    SET_INTENSITY(127)
    LOAD_LEVEL("test")
    scroll_left  = GET_SCROLL_LIMIT_LEFT()
    scroll_right = GET_SCROLL_LIMIT_RIGHT()
    # Keep player roughly centered: camera right limit minus half-screen
    scroll_right_edge = scroll_right - 96

def loop():
    joy_x = J1_X()

    # Horizontal movement (3 px/frame)
    is_walking = 0
    if joy_x > 20:
        player_x = player_x + 3
        is_walking = 1
    if joy_x < -20:
        player_x = player_x - 3
        is_walking = 1

    # Clamp player to scroll-limit world bounds
    player_x = clamp(player_x, scroll_left, scroll_right)

    # Camera follows player, offset so player appears near center
    camera_x = player_x - 30
    camera_x = clamp(camera_x, scroll_left, scroll_right_edge)

    SET_CAMERA_X(camera_x)
    SHOW_LEVEL()

    # Player screen position (world - camera)
    screen_x = player_x - camera_x

    # Draw player: walk anim while moving, static pose when idle
    if is_walking == 1:
        #DRAW_VECTOR("mario_body", screen_x, player_y)
        DRAW_ANIM("mario_walk", screen_x, player_y)
    else:
        DRAW_VECTOR("mario_body", screen_x, player_y)
        DRAW_VECTOR("mario_legs_straight", screen_x, player_y)
