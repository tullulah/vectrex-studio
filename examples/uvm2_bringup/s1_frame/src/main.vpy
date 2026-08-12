# UVM2 bring-up, stage 1 — does anything run at all?
#
# Draws NOTHING. The screen stays black on success; the cartridge LED is the
# only readout, and that is the point: this stage separates "the image never
# booted" from "the beam code is wrong".
#
# LED:  blue  = booted, but no Vectrex clock seen yet
#       red   = no clock at all -> console off, or cart not seated
#       amber = clock found, taking the bus (stuck here = the 6809 never halted)
#       green = frames going out at 50 Hz  <- PASS
META TITLE = "UVM2 S1"

def main():
    pass

def loop():
    pass
