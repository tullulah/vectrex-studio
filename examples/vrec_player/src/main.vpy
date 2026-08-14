META TITLE = "VREC PLAYER"

# ============================================================
#  Full-screen .vrec player — plays a vectorized video/clip.
#
#  Drop your recording at assets/recordings/clip.vrec (e.g. produced by
#  tools/video2vrec from Bad Apple etc.), build for the rp2350 target, and
#  it plays back frame by frame.
# ============================================================

audio_started: i16 = 0  # PLAY_SAMPLE latch (fire once)
VID_FPS: i16 = 15       # the recording's capture fps


def main():
    pass


def loop():
    # Start the audio track once — it is the MASTER clock.
    if audio_started == 0:
        audio_started = 1
        #PLAY_SAMPLE("audio")

    # Video FOLLOWS the audio: derive the frame from how much audio has played
    # (SAMPLE_POS returns samples_played * fps / rate). No free-running counter,
    # so the video can't drift ahead of the song regardless of loop rate.
    frame = SAMPLE_POS(VID_FPS)

    # scale 128 = 100% (full size); centred at (0,0). DRAW_RECORDING wraps the
    # frame index internally (frame % frame_count).
    DRAW_RECORDING("clip", 0, 0, 128, frame)
