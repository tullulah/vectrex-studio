META TITLE = "SUPER MARIO POC"

# Mario half-height (from mario.vec HALF_HEIGHT = 13)
const MARIO_HH = 13
const MARIO_HW = 8

# Player world position (player_y = center of mario sprite)
player_x: i16 = 0
player_y: i16 = -62   # ground tiles at y=-103, half_height=8 -> floor_y = -95+13 = -82

# Physics
vel_y: i16 = 0
on_ground: u8 = 1
prev_y: i16 = -62

# Camera
camera_x: i16 = 0

# Movement state
is_walking: u8 = 0

# Collision result (floor_y = where player center lands = tile_top + MARIO_HH)
floor_y: i16 = -62

def main():
    LOAD_LEVEL("world_1_1")
    #PLAY_MUSIC("theme")

def loop():
    joy_x = J1_X()
    btn_jump = J1_BUTTON_1()

    # Horizontal movement
    is_walking = 0
    if joy_x > 20:
        player_x = player_x + 3
        is_walking = 1
    if joy_x < -20:
        player_x = player_x - 3
        is_walking = 1

    # Clamp player to level bounds
    player_x = clamp(player_x, -62, 1050)

    # Horizontal collision: only when not moving upward
    # (prevents spurious lateral push when jumping into a block from below)
    if vel_y <= 0:
        dx_push = LEVEL_COLLISION_X(player_x, player_y, MARIO_HW, MARIO_HH)
        player_x = player_x + dx_push

    # Jump
    if btn_jump == 1:
        if on_ground == 1:
            vel_y = 12
            on_ground = 0
            PLAY_SFX("jump")

    # Apply gravity when airborne
    if on_ground == 0:
        prev_y = player_y
        player_y = player_y + vel_y
        vel_y = vel_y - 1

        # Find highest surface at prev_y using full AABB (3rd arg = mario half_height)
        # Returns tile_top + MARIO_HH → where player center should land
        floor_y = LEVEL_COLLISION_Y(player_x, prev_y, MARIO_HH)
        floor_y = max(floor_y, -120)

        # Land on solid surface
        if player_y <= floor_y:
            player_y = floor_y
            vel_y = 0
            on_ground = 1

    # When grounded, check if surface still exists (walk off platform edge)
    if on_ground == 1:
        floor_y = LEVEL_COLLISION_Y(player_x, player_y, MARIO_HH)
        floor_y = max(floor_y, -120)
        if player_y > floor_y:
            on_ground = 0

    # Camera follows player (player appears at screen_x = -30)
    camera_x = player_x + 30
    camera_x = clamp(camera_x, 0, 970)

    SET_CAMERA_X(camera_x)
    SHOW_LEVEL()

    # Draw player: walk animation only while moving, static pose when idle
    if is_walking == 1:
        DRAW_ANIM("mario_walk", -30, player_y)
    else:
        DRAW_VECTOR("mario_body", -30, player_y)
        DRAW_VECTOR("mario_legs_straight", -30, player_y)
    debug_print(floor_y)
    debug_print(player_y)
