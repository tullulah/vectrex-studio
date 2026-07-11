META TITLE = "TDCM"

# ============================================================
#  The Demented Cartoon Movie — vector movie player (video + voice).
#
#  Video (tdcm.vrec) + 4-bit voice (tdcm.vsmp) play in sync:
#  the audio is the master clock, the video frame follows it via SAMPLE_POS.
#
#  Both tracks are named after the source video (tdcm.mp4 -> tdcm.vrec + tdcm.vsmp),
#  so the recording AND the sample are referenced as "tdcm". VID_FPS must match
#  the fps the .vmov was converted at.
#
#  Assets are DEV-ONLY (copyrighted; gitignored) — regenerate with
#  tools/fetch/url2vmov.sh, then copy the .vrec/.vsmp into assets/.
# ============================================================

audio_started: i16 = 0  # PLAY_SAMPLE latch (fire once)
VID_FPS: i16 = 15       # must match the .vmov's converted fps


def main():
    pass


def loop():
    # Start the voice track once — it is the MASTER clock.
    if audio_started == 0:
        audio_started = 1
        PLAY_SAMPLE("tdcm")

    # Video FOLLOWS the audio: frame = samples_played * fps / rate, so it can't
    # drift ahead of the soundtrack regardless of the loop rate.
    frame = SAMPLE_POS(VID_FPS)

    # Full-screen, centred. DRAW_RECORDING wraps frame % frame_count internally.
    DRAW_RECORDING("tdcm", 0, 0, 128, frame)
