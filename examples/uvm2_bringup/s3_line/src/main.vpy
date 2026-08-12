# UVM2 bring-up, stage 3 — does the ramp produce the length we asked for?
#
# A horizontal line from centre, 60 units to the right, and a vertical one
# 60 units up. Same length, so they calibrate the X and Y paths against
# each other.
#
# PASS: an L of two equal arms meeting at centre.
# Arms of different length -> X (live DAC) and Y (sample/hold) are not matched.
# Length wrong but equal   -> `scale` needs calibrating (uvm2_draw_set_scale).
# Second arm missing       -> the per-path re-zero is not restoring the beam.
META TITLE = "UVM2 S3"

def main():
    pass

def loop():
    DRAW_LINE(0, 0, 60, 0, 90)
    DRAW_LINE(0, 0, 0, 60, 90)
