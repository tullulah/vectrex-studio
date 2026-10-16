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
sub: i16 = 0            # acumulador del reloj de repuesto (fracciones de frame)
vframe: i16 = 0         # frame de video cuando no hay audio que mande


def main():
    pass


def loop():
    # Start the audio track once — it is the MASTER clock.
    if audio_started == 0:
        audio_started = 1
        PLAY_SAMPLE("audio")

    # Video FOLLOWS the audio: derive the frame from how much audio has played
    # (SAMPLE_POS returns samples_played * fps / rate), so the video can't drift
    # ahead of the song regardless of loop rate.
    frame = SAMPLE_POS(VID_FPS)

    # PERO SI NO HAY RELOJ DE AUDIO, EL VIDEO NO AVANZA.
    #
    # En el UVM2 los samples digitalizados no estan implementados: SAMPLE_POS cae
    # en el `default:` del despachador y devuelve 0. SIEMPRE. Asi que el frame se
    # queda clavado en el 0 — y el frame 0 de Bad Apple es negro. El sintoma es
    # exactamente el que se veia: 96.084 escrituras a la VIA y CERO vectores. El
    # reproductor corria perfectamente; lo que dibujaba estaba vacio.
    #
    # Asi que hay reloj de repuesto: un contador libre a VID_FPS sobre los 50 Hz
    # del frame. No sustituye al audio —cuando lo hay, el audio manda y esto ni se
    # mira— pero evita que la ausencia de audio se vea como "el reproductor no
    # funciona", que es lo que costo el diagnostico.
    if frame == 0:
        sub = sub + VID_FPS
        if sub >= 50:
            sub = sub - 50
            vframe = vframe + 1
        frame = vframe

    # scale 128 = 100% (full size); centred at (0,0). DRAW_RECORDING wraps the
    # frame index internally (frame % frame_count).
    DRAW_RECORDING("badapple", 0, 0, 128, frame)
