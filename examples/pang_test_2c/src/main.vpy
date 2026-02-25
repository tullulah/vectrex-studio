# TEST 2C: Fixed Values Test (No Joystick)
# Tests: DRAW_CIRCLE with fixed values to isolate joystick issue

META TITLE = "PANG_TEST_2C"
META MUSIC = music1

screen = 0
x_val = 30
y_val = 20

def main():
    screen = 0

def loop():
    # Draw circle at fixed position (no joystick calls)
    DRAW_CIRCLE(x_val, y_val, 10, 127)
