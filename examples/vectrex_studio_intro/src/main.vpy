META TITLE = "VECTREX STUDIO"

# ============================================================
#  VECTREX STUDIO — cartridge intro
#
#  Timeline (frame-driven, ~50 fps):
#    Phase 0  REVEAL   the "VS" logo swings in (3D ease-out) and
#                      brightens up from black.
#    Phase 1  TITLE    the VECTREX wordmark + STUDIO fade in below.
#    Phase 2  IDLE     everything holds with a slow "breathing" pulse.
# ============================================================

# --- animation state --------------------------------------
phase: i16 = 0          # 0 reveal, 1 title, 2 idle
t: i16 = 0              # free-running frame counter (for SIN pulse)

logo_rot: i16 = 64      # logo Y-rotation; one slow turn down to 0 (facing front)
logo_i: i16 = 0         # logo intensity, eases in to LOGO_MAX

word_i: i16 = 0         # VECTREX wordmark intensity
sub_i: i16 = 0          # STUDIO subtitle intensity
music_on: i16 = 0       # jingle-started latch (play once, not every frame)

# --- tunables ---------------------------------------------
LOGO_MAX: i16 = 118     # peak logo brightness
WORD_MAX: i16 = 100     # peak wordmark brightness
SUB_MAX: i16 = 80       # peak subtitle brightness

def main():
    pass


def loop():
    t = t + 1

    # kick off the jingle on the first frame (latched so it plays once)
    if music_on == 0:
        music_on = 1
        PLAY_MUSIC("jingle")

    # ---------- PHASE 0 : REVEAL ----------
    if phase == 0:
        # ONE slow turn to face front (rot -> 0), 1 unit/frame
        logo_rot = logo_rot - 1
        if logo_rot < 0:
            logo_rot = 0
        # slow linear brighten from black — takes ~1 s so you SEE it come up
        if logo_i < LOGO_MAX:
            logo_i = logo_i + 2
        # settled -> advance
        if logo_rot <= 0:
            phase = 1

    # ---------- PHASE 1 : TITLE ----------
    if phase == 1:
        # wide "breathing" pulse on the logo (clearly visible, ~2.5 s period)
        logo_i = LOGO_MAX - 24 + (SIN(t) / 5)
        # bring in the wordmark, then the subtitle
        if word_i < WORD_MAX:
            word_i = word_i + 3
        if word_i > 40:
            if sub_i < SUB_MAX:
                sub_i = sub_i + 2
        if sub_i >= SUB_MAX:
            phase = 2

    # ---------- PHASE 2 : IDLE ----------
    if phase == 2:
        # slow synchronized breathing on the whole composition
        logo_i = LOGO_MAX - 24 + (SIN(t) / 5)
        word_i = WORD_MAX - 20 + (SIN(t) / 6)

    # ================= DRAW =================
    # "VS" logo (upper centre), spinning in / breathing
    SET_INTENSITY(logo_i)
    DRAW_VECTOR_3D("logo", 0, logo_rot, 0, 0, 34)

    # VECTREX wordmark (lower centre)
    if word_i > 0:
        SET_INTENSITY(word_i)
        DRAW_VECTOR("text", 0, -40)

    # STUDIO subtitle (BIOS text, under the wordmark)
    if sub_i > 0:
        SET_INTENSITY(sub_i)
        SET_TEXT_SIZE(6)
        PRINT_TEXT(-14, -64, "STUDIO")
