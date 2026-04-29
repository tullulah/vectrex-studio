# BBOX_CAL 2D: PiTrex text offset calibration grid
#
# 4 columns x 5 rows. Each cell draws "H" with a 16x16 bounding box.
# Column = x offset added to PRINT_TEXT x relative to box left: 0, 2, 4, 6
# Row    = y offset subtracted from PRINT_TEXT y relative to box top: 0, 2, 4, 6, 8
#
# The cell where "H" best fits gives the (x_offset, y_offset) correction needed.
# DRAW_RECT(x, y, w, h, b): (x,y) = bottom-left corner, extends right+up.

META TITLE = "BBOX2D"

def main():
    pass

def loop():
    # Row 0 (ty=0, box_top=56, box_bottom=40)
    PRINT_TEXT(-52, 56, "H")
    DRAW_RECT(-52, 40, 16, 16, 70)
    PRINT_TEXT(-24, 56, "H")
    DRAW_RECT(-26, 40, 16, 16, 70)
    PRINT_TEXT(4, 56, "H")
    DRAW_RECT(0, 40, 16, 16, 70)
    PRINT_TEXT(32, 56, "H")
    DRAW_RECT(26, 40, 16, 16, 70)

    # Row 1 (ty=2, box_top=32, box_bottom=16)
    PRINT_TEXT(-52, 30, "H")
    DRAW_RECT(-52, 16, 16, 16, 70)
    PRINT_TEXT(-24, 30, "H")
    DRAW_RECT(-26, 16, 16, 16, 70)
    PRINT_TEXT(4, 30, "H")
    DRAW_RECT(0, 16, 16, 16, 70)
    PRINT_TEXT(32, 30, "H")
    DRAW_RECT(26, 16, 16, 16, 70)

    # Row 2 (ty=4, box_top=8, box_bottom=-8)
    PRINT_TEXT(-52, 4, "H")
    DRAW_RECT(-52, -8, 16, 16, 70)
    PRINT_TEXT(-24, 4, "H")
    DRAW_RECT(-26, -8, 16, 16, 70)
    PRINT_TEXT(4, 4, "H")
    DRAW_RECT(0, -8, 16, 16, 70)
    PRINT_TEXT(32, 4, "H")
    DRAW_RECT(26, -8, 16, 16, 70)

    # Row 3 (ty=6, box_top=-16, box_bottom=-32)
    PRINT_TEXT(-52, -22, "H")
    DRAW_RECT(-52, -32, 16, 16, 70)
    PRINT_TEXT(-24, -22, "H")
    DRAW_RECT(-26, -32, 16, 16, 70)
    PRINT_TEXT(4, -22, "H")
    DRAW_RECT(0, -32, 16, 16, 70)
    PRINT_TEXT(32, -22, "H")
    DRAW_RECT(26, -32, 16, 16, 70)

    # Row 4 (ty=8, box_top=-40, box_bottom=-56)
    PRINT_TEXT(-52, -48, "H")
    DRAW_RECT(-52, -56, 16, 16, 70)
    PRINT_TEXT(-24, -48, "H")
    DRAW_RECT(-26, -56, 16, 16, 70)
    PRINT_TEXT(4, -48, "H")
    DRAW_RECT(0, -56, 16, 16, 70)
    PRINT_TEXT(32, -48, "H")
    DRAW_RECT(26, -56, 16, 16, 70)
