META TITLE = "VREC PLAYER"

# ============================================================
#  Full-screen .vrec player — plays a vectorized video/clip.
#
#  Drop your recording at assets/recordings/clip.vrec (e.g. produced by
#  tools/video2vrec from Bad Apple etc.), build for the rp2350 target, and
#  it plays back frame by frame.
# ============================================================

t: i16 = 0              # menu-frame counter
frame: i16 = 0          # current recording frame
audio_started: i16 = 0  # PLAY_SAMPLE latch (fire once)
FPS_DIV: i16 = 3        # loop ~50 fps / recording 15 fps → advance every 3


def main():
    pass


def loop():
    t = t + 1

    # Start the audio track once. Audio is the master clock: it streams in real
    # time; the video below advances at its own fps, so both stay in sync.
    if audio_started == 0:
        audio_started = 1
        PLAY_SAMPLE("audio")

    # Advance the recording frame at the recording's fps (not the 50 fps loop).
    if t >= FPS_DIV:
        t = 0
        frame = frame + 1
    # scale 128 = 100% (full size); centred at (0,0). DRAW_RECORDING wraps the
    # frame index internally (frame % frame_count), so this loops forever.
    DRAW_RECORDING("clip", 0, 0, 128, frame)
