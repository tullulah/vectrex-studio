# UVM2 bring-up, stage 4 — signs, and repeatability across paths.
#
# Four arms from centre. Any axis inversion or sign error in the DAC shows up
# immediately as an asymmetric cross.
#
# PASS: a symmetric cross, all four arms the same length.
# Only two arms          -> negative deltas are wrong (i8 sign into the DAC).
# Arms drift frame to frame -> the beam is not returning to a true zero.
META TITLE = "UVM2 S4"

def main():
    pass

def loop():
    DRAW_LINE(0, 0,  50,   0, 90)
    DRAW_LINE(0, 0, -50,   0, 90)
    DRAW_LINE(0, 0,   0,  50, 90)
    DRAW_LINE(0, 0,   0, -50, 90)
