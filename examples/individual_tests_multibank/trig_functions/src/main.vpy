# TEST: TRIG_FUNCTIONS
# Tests sin() and cos() with animated circular motion
# Expected: Dot orbiting in a circle around center
# sin/cos arguments: 0..127 = full circle, result -127..127

META TITLE = "TRIG"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

angle = 0

def main():
    angle = 0

def loop():
    PRINT_TEXT(-50, 90, "SIN/COS")

    # Compute position on circle (radius ~40)
    # sin/cos return -127..127, divide by 3 to get ~40 pixel radius
    px = cos(angle) / 3
    py = sin(angle) / 3

    # Draw orbiting dot
    DRAW_CIRCLE(px, py, 30, 100)

    # Draw center crosshair
    DRAW_LINE(0, -5, 0, 5, 40)
    DRAW_LINE(-5, 0, 5, 0, 40)

    # Draw orbit path (faint circle)
    DRAW_CIRCLE(0, 0, 42, 80)

    # Advance angle (0..127 = full circle)
    angle = angle + 1
    if angle > 127:
        angle = 0
