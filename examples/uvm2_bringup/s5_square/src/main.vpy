# UVM2 bring-up, stage 5 — a closed shape, and brightness.
#
# A square drawn as four connected segments, plus a dimmer one inside it. The
# square closing exactly is the real test: it means the beam ends each segment
# where the next one starts, which is what makes chained drawing viable at all.
#
# PASS: a closed square with a visibly dimmer square inside.
# Square does not close    -> accumulated error per segment; the ramp overshoots.
# Inner square same colour -> the Z mux is not latching intensity changes.
# Visible flicker          -> the frame is over budget; check uvm2_stats.overrun.
META TITLE = "UVM2 S5"

def main():
    pass

def loop():
    DRAW_LINE(-50, -50,  50, -50, 100)
    DRAW_LINE( 50, -50,  50,  50, 100)
    DRAW_LINE( 50,  50, -50,  50, 100)
    DRAW_LINE(-50,  50, -50, -50, 100)

    DRAW_LINE(-25, -25,  25, -25, 40)
    DRAW_LINE( 25, -25,  25,  25, 40)
    DRAW_LINE( 25,  25, -25,  25, 40)
    DRAW_LINE(-25,  25, -25, -25, 40)
