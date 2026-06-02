META TITLE = "SCREEN BORDER"

# Vectrex screen: X = -96..+96, Y = -128..+128
# Draw_Line_d max segment = 127 units so we split each side.
# Each horizontal side (width=192) → 2 segments of 96
# Each vertical side (height=256) → 2 segments of 127+1 → use 3x86

def main():
    pass

def loop():
    # Bottom edge: y=-128, from x=-96 to x=+96 (split into 2×96)
    DRAW_LINE(-96, -128, 0, -128, 80)
    DRAW_LINE(0, -128, 96, -128, 80)

    # Top edge: y=+127, from x=-96 to x=+96
    DRAW_LINE(-96, 127, 0, 127, 80)
    DRAW_LINE(0, 127, 96, 127, 80)

    # Left edge: x=-96, from y=-128 to y=+127 (split into 3)
    DRAW_LINE(-96, -128, -96, -43, 80)
    DRAW_LINE(-96, -43, -96, 42, 80)
    DRAW_LINE(-96, 42, -96, 127, 80)

    # Right edge: x=+96
    DRAW_LINE(96, -128, 96, -43, 80)
    DRAW_LINE(96, -43, 96, 42, 80)
    DRAW_LINE(96, 42, 96, 127, 80)

    # Center crosshair
    DRAW_LINE(-8, 0, 8, 0, 60)
    DRAW_LINE(0, -8, 0, 8, 60)
