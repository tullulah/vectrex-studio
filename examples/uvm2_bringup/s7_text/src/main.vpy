# UVM2 bring-up, stage 7 — text.
#
# Text is the most expensive thing a frame can do here: each glyph re-centres
# the beam before drawing, because that zero is what relights it. Ten
# characters cost about 29% of a 50 Hz frame at the default settings.
#
# The geometry is verified identical to the IDE emulator, so what appears here
# should match what the simulator shows, character for character.
#
# PASS: two readable lines, the number right-aligned under the word.
# Glyphs drawn but misplaced -> baseline adjustment or advance is off.
# First glyph only            -> the per-glyph re-zero is not restoring the beam.
# Glyphs dimmer than the box  -> the beam is not relighting after the zero.
# Visible flicker             -> over budget; drop TEXT_SIZE or shorten the string.
META TITLE = "UVM2 S7"

def main():
    pass

def loop():
    PRINT_TEXT(-60, 40, "SCORE")
    PRINT_NUMBER(20, 40, 1234)

    DRAW_LINE(-60, 10, 60, 10, 80)
