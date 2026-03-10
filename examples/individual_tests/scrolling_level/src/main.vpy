META TITLE = "SCROLL TEST"

camera_x: i16 = 0
camera_y: i16 = 0

def main():
    LOAD_LEVEL("world")

def loop():
    joy_x = J1_X()
    joy_y = J1_Y()

    if joy_x > 20:
        camera_x = camera_x + 3
    if joy_x < -20:
        camera_x = camera_x - 3
    if joy_y > 20:
        camera_y = camera_y + 3
    if joy_y < -20:
        camera_y = camera_y - 3

    camera_x = clamp(camera_x, -128, 400)
    camera_y = clamp(camera_y, -300, 127)

    SET_CAMERA_X(camera_x)
    SET_CAMERA_Y(camera_y)
    SHOW_LEVEL()

    # Draw a fixed crosshair at screen center to show camera position
    DRAW_VECTOR("marker", 0, 0)
