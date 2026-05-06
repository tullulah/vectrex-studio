# Twinkle Twinkle Little Star — instrument demo
# Melody on channel A (pluck) + bass on channel B (bell)

# Melody notes (MIDI): C4=60, D4=62, E4=64, F4=65, G4=67, A4=69
const melody = [60, 60, 67, 67, 69, 69, 67, 65, 65, 64, 64, 62, 62, 60]
const melody_len = 14
# Bass notes (one octave lower)
const bass = [48, 48, 55, 55, 57, 57, 55, 53, 53, 52, 52, 50, 50, 48]

note_timer = 0
note_index = 0

def loop():
    if note_timer <= 0:
        PLAY_NOTE("pluck", 0, melody[note_index])
        PLAY_NOTE("bell", 1, bass[note_index])
        note_index = note_index + 1
        if note_index >= melody_len:
            note_index = 0
        note_timer = 12
    note_timer = note_timer - 1

    SET_INTENSITY(64)
    PRINT_TEXT(-60, 40, "INSTRUMENT DEMO")
    PRINT_TEXT(-60, 20, "TWINKLE TWINKLE")
