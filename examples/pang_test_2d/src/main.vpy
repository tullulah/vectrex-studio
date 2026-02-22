# TEST 2D: Vector vs Circle Comparison
# Tests: DRAW_VECTOR (should work) vs DRAW_CIRCLE (possibly broken)

META TITLE = "PANG_TEST_2D"
META MUSIC = music1

screen = 0
x_val = 30
y_val = 20

def main():
    screen = 0

def loop():
    # Draw vector instead of circle
    DRAW_VECTOR("test_square", x_val, y_val)
