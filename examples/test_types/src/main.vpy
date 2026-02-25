# test_types - Minimal VPy Type System Test
# Tests variable-sized types: u8, i8, u16, i16
META MUSIC = music1

# u8 variables - unsigned 8-bit (0-255)
counter: u8 = 0
state: u8 = 0
shape_type: u8 = 0

# i8 variables - signed 8-bit (-128 to +127)
direction_x: i8 = 0
direction_y: i8 = 0

# i16 variables - signed 16-bit (-32768 to +32767)
pos_x: i16 = 0
pos_y: i16 = 0
joy_x: i16 = 0

const BASE_INTENSITY = 100
const MAX_X = 120
const MIN_X = -120

def main():
    # Initialize
    counter = 0
    state = 0
    shape_type = 0
    direction_x = 0
    direction_y = 0
    pos_x = 0
    pos_y = 0
    joy_x = 0
    SET_INTENSITY(BASE_INTENSITY)

def loop():
    # Read joystick
    joy_x = J1_X()

    # Update direction based on joystick (i8 from i16)
    if joy_x < 0:
        direction_x = -1
    elif joy_x > 0:
        direction_x = 1
    else:
        direction_x = 0

    # Update position with clamping (i16)
    pos_x = pos_x + direction_x
    if pos_x > MAX_X:
        pos_x = MAX_X
    if pos_x < MIN_X:
        pos_x = MIN_X

    # Oscillate Y position
    if counter < 32:
        pos_y = counter
    elif counter < 64:
        pos_y = 64 - counter
    else:
        pos_y = 0

    # Increment counter (u8 wraps at 256)
    counter = counter + 1

    # Change shape on button
    if J1_BUTTON_1() == 1:
        shape_type = shape_type + 1
        if shape_type > 2:
            shape_type = 0

    # Draw at position
    MOVE(pos_x, pos_y)

    if shape_type == 0:
        DRAW_LINE(pos_x - 10, pos_y, pos_x + 10, pos_y, BASE_INTENSITY)
    elif shape_type == 1:
        DRAW_CIRCLE(pos_x, pos_y, 10, BASE_INTENSITY)
    else:
        DRAW_POLYGON(3, BASE_INTENSITY, pos_x, pos_y - 10, pos_x + 10, pos_y + 10, pos_x - 10, pos_y + 10)

    # Debug: show counter
    SET_INTENSITY(80)
    PRINT_TEXT(-120, 110, "Types Test")
    PRINT_NUMBER(-120, 100, counter)
