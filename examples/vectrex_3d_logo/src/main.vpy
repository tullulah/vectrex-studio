META TITLE = "Vectrex 3D Logo"

# Rotation angles (0-255 for full circle, like angle units)
rot_x: i16 = 0
rot_y: i16 = 0
rot_z: i16 = 0

# Rotation speeds (adjustable)
rot_speed_x: i16 = 1
rot_speed_y: i16 = 2
rot_speed_z: i16 = 1

def main():
    pass

def loop():
    # Update rotation angles
    rot_x = rot_x + rot_speed_x
    rot_y = rot_y + rot_speed_y
    rot_z = rot_z + rot_speed_z

    # Keep angles in 0-255 range (wraps naturally)
    if rot_x >= 256:
        rot_x = rot_x - 256
    if rot_y >= 256:
        rot_y = rot_y - 256
    if rot_z >= 256:
        rot_z = rot_z - 256

    # Read joystick to adjust rotation speeds
    joy_x = J1_X()
    joy_y = J1_Y()

    # Speed adjustment with buttons
    if J1_BUTTON_1():
        rot_speed_x = rot_speed_x + 1
    if J1_BUTTON_2():
        rot_speed_x = clamp(rot_speed_x - 1, 0, 10)
    if J1_BUTTON_3():
        rot_speed_y = rot_speed_y + 1
    if J1_BUTTON_4():
        rot_speed_y = clamp(rot_speed_y - 1, 0, 10)

    # Draw logo with 3D rotation (currently: stub that ignores rotation, draws 2D)
    DRAW_VECTOR_3D("logo", rot_x, rot_y, rot_z, 0, 0)
