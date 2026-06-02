# BBOX_CAL 2D v2: expanded range
#
# 4 columns x 5 rows.
# Column = x offset added to PRINT_TEXT x relative to box left: 0, 4, 8, 12
# Row    = y offset subtracted from PRINT_TEXT y relative to box top: 8, 10, 12, 14, 16
#
# (continues where the first grid ended — all cells were above/left in v1)

META TITLE = "BBOX2D"

def main():
    pass

def loop():
    # Row 0 (ty=8, box_top=56, box_bottom=40)
    PRINT_TEXT(-52, 48, "H")
    DRAW_RECT(-52, 40, 16, 16, 70)
    PRINT_TEXT(-22, 48, "H")
    DRAW_RECT(-26, 40, 16, 16, 70)
    PRINT_TEXT(8, 48, "H")
    DRAW_RECT(0, 40, 16, 16, 70)
    PRINT_TEXT(38, 48, "H")
    DRAW_RECT(26, 40, 16, 16, 70)

    # Row 1 (ty=10, box_top=32, box_bottom=16)
    PRINT_TEXT(-52, 22, "H")
    DRAW_RECT(-52, 16, 16, 16, 70)
    PRINT_TEXT(-22, 22, "H")
    DRAW_RECT(-26, 16, 16, 16, 70)
    PRINT_TEXT(8, 22, "H")
    DRAW_RECT(0, 16, 16, 16, 70)
    PRINT_TEXT(38, 22, "H")
    DRAW_RECT(26, 16, 16, 16, 70)

    # Row 2 (ty=12, box_top=8, box_bottom=-8)
    PRINT_TEXT(-52, -4, "H")
    DRAW_RECT(-52, -8, 16, 16, 70)
    PRINT_TEXT(-22, -4, "H")
    DRAW_RECT(-26, -8, 16, 16, 70)
    PRINT_TEXT(8, -4, "H")
    DRAW_RECT(0, -8, 16, 16, 70)
    PRINT_TEXT(38, -4, "H")
    DRAW_RECT(26, -8, 16, 16, 70)

    # Row 3 (ty=14, box_top=-16, box_bottom=-32)
    PRINT_TEXT(-52, -30, "H")
    DRAW_RECT(-52, -32, 16, 16, 70)
    PRINT_TEXT(-22, -30, "H")
    DRAW_RECT(-26, -32, 16, 16, 70)
    PRINT_TEXT(8, -30, "H")
    DRAW_RECT(0, -32, 16, 16, 70)
    PRINT_TEXT(38, -30, "H")
    DRAW_RECT(26, -32, 16, 16, 70)

    # Row 4 (ty=16, box_top=-40, box_bottom=-56)
    PRINT_TEXT(-52, -56, "H")
    DRAW_RECT(-52, -56, 16, 16, 70)
    PRINT_TEXT(-22, -56, "H")
    DRAW_RECT(-26, -56, 16, 16, 70)
    PRINT_TEXT(8, -56, "H")
    DRAW_RECT(0, -56, 16, 16, 70)
    PRINT_TEXT(38, -56, "H")
    DRAW_RECT(26, -56, 16, 16, 70)
