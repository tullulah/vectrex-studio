META TITLE = "SCOPE"

# Oscilloscope bring-up test: draws ONE known horizontal line every frame.
# No text, no music — so the RP2350 produces a clean, regular burst of A15
# write pulses (one line = Reset0Ref + SetIntensity + Moveto + Draw_Line, a
# handful of E-synced bus writes). Trigger the scope on A15 (GP19) rising to
# catch the burst and measure the select vs /OE-fall placement.

def main():
    pass


def loop():
    # A closed square (4 lines). This is the "split box" failing case: if it
    # doesn't close on screen, scope A15 vs /OE to see whether any write is
    # anomalous (blind-fallback long pulse / wrong E-fall coverage = a bus
    # problem) or every write is clean (→ the split is analog integrator drift).
    SET_INTENSITY(120)
    DRAW_LINE(-50, -50, 50, -50, 120)
    DRAW_LINE(50, -50, 50, 50, 120)
    DRAW_LINE(50, 50, -50, 50, 120)
    DRAW_LINE(-50, 50, -50, -50, 120)
