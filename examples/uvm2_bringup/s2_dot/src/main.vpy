# UVM2 bring-up, stage 2 — the first bus write that has to reach the VIA.
#
# One very short segment at dead centre. Everything the beam needs is exercised
# once: VIA config, zero reference, the Z mux for intensity, /RAMP and /BLANK.
#
# PASS: a single bright dot in the middle of the screen.
# Dot but off-centre  -> zero reference is not landing (mux/PCR sequence).
# Nothing, LED green  -> writes are the wrong CLK phase, or R/W never goes low.
# Whole screen bright -> /BLANK stuck off (PCR bit 5 polarity).
META TITLE = "UVM2 S2"

def main():
    pass

def loop():
    DRAW_LINE(0, 0, 2, 0, 100)
