# UVM2 bring-up, stage 6 — the read path.
#
# Reads are the one thing the command stream cannot do: they need the data bus
# turned around mid-cycle. This is the only stage that exercises that.
#
# A cross follows joystick 1; button 1 brightens it.
#
# PASS: the cross moves with the stick and brightens on button 1.
# Nothing moves          -> the read cycle samples on the wrong edge.
# Moves but jumps to the extremes -> digital axes are being scaled to +/-127;
#                           expected until the analog SAR path is validated.
# Picture tears when reading -> input is running inside a frame instead of
#                           between frames, while /ZERO holds the beam.
META TITLE = "UVM2 S6"

px = 0
py = 0
bright = 0

def main():
    pass

def loop():
    px = J1_X() / 4
    py = J1_Y() / 4

    bright = 60
    if J1_BUTTON_1() == 1:
        bright = 120

    DRAW_LINE(px - 20, py, px + 20, py, bright)
    DRAW_LINE(px, py - 20, px, py + 20, bright)
