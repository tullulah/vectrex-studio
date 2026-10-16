# UVM2 bring-up, stage 8 — sound.
#
# The PSG is reached through the VIA like everything else, but with a handshake
# (BC1/BDIR on Port B) instead of a beam ramp. Writes go out between frames,
# while /ZERO clamps the beam — driving Port B mid-draw would disturb it.
#
# The sequencer is ticked once per frame from WAIT_RECAL, which is exactly the
# 50 Hz the assets are compiled at. That ties tempo to frame rate: a frame that
# overruns its budget stretches the music with it.
#
# PASS: the track loops cleanly, and button 1 fires an effect over it without
#       cutting the music.
# Silence entirely     -> the PSG handshake never latches (Port B BC1/BDIR).
# Music but no effect  -> channel C is being masked out of the mixer merge.
# Effect cuts music    -> reg 7 is being written whole instead of merged.
# Tempo drifts         -> frames are over budget; check uvm2_stats.overrun.
# Buzz while drawing   -> PSG writes are landing inside a frame, not between.
META TITLE = "UVM2 S8"
META MUSIC = music1

def main():
    PLAY_MUSIC("music1")

def loop():
    PRINT_TEXT(-55, 40, "AUDIO")
    PRINT_TEXT(-55, 15, "B1=SFX")

    if J1_BUTTON_1():
        PLAY_SFX("laser")

    DRAW_LINE(-55, -10, 55, -10, 70)
