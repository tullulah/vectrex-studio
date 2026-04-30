META TITLE = "ZAXXON POC"

# ─── Isometric projection (45° diagonal, corner-to-corner) ───────────────────
#
# World:  X = corridor left/right (-35..35)
#         Y = altitude             (0..32)
#         Z = forward depth        (auto-scroll via cam_z)
#
# Forward direction in screen space = (+0.5, +0.5) per Z unit  (NE diagonal)
# Lateral direction (world X) in screen = (+0.5, -0.5) per X unit (SE/NW)
# Altitude (world Y) in screen = (0, +1) per Y unit
#
#   screen_x = rel_z/2 + rel_x/2 - 20
#   screen_y = rel_z/2 - rel_x/2 + obj_y - 40
#
# ship.vec is oriented along the (0.5, 0.5) NE flight axis.
# At Z=160 the path reaches screen_y ≈ 40 (top area of screen).
# At Z=0  the path sits at screen_y ≈ -40 (bottom area of screen).

const LEVEL_LEN  = 320
const BLD_COUNT  = 6
const VIS_FAR    = 200

# ─── Level data ──────────────────────────────────────────────────────────────
const BLD_X = [8, -22, 18, -10, 26, -6]
const BLD_Z = [60, 100, 140, 185, 225, 270]
const BLD_W = [14, 20, 10, 24, 12, 18]
const BLD_H = [14, 24, 18, 14, 26, 18]

# ─── Game state ──────────────────────────────────────────────────────────────
player_x:    i16 = 0
player_y:    i16 = 8
cam_z:       i16 = 0
scroll_tick: u8  = 0
score:       i16 = 0

# ─── Building alive flags (one per building, reset on level loop) ─────────────
b0alive: u8 = 1
b1alive: u8 = 1
b2alive: u8 = 1
b3alive: u8 = 1
b4alive: u8 = 1
b5alive: u8 = 1

# ─── Bullet ───────────────────────────────────────────────────────────────────
bullet_alive:  u8  = 0
bullet_abs_z:  i16 = 0
bullet_rx:     i16 = 0
bullet_ry:     i16 = 0
btn_prev:      u8  = 0

# ─── Explosion ───────────────────────────────────────────────────────────────
expl_frames: u8  = 0
expl_sx:     i16 = 0
expl_sy:     i16 = 0

# ─── Projection I/O ──────────────────────────────────────────────────────────
p_rx: i16 = 0
p_wy: i16 = 0
p_rz: i16 = 0
p_sx: i16 = 0
p_sy: i16 = 0

# ─── Box corners ─────────────────────────────────────────────────────────────
c0x: i16 = 0
c0y: i16 = 0
c1x: i16 = 0
c1y: i16 = 0
c2x: i16 = 0
c2y: i16 = 0
c3x: i16 = 0
c3y: i16 = 0
c4x: i16 = 0
c4y: i16 = 0
c5x: i16 = 0
c5y: i16 = 0

# ─── Loop temps ──────────────────────────────────────────────────────────────
bi:        i16 = 0
bx:        i16 = 0
bz:        i16 = 0
bw:        i16 = 0
bh:        i16 = 0
rz:        i16 = 0
alive:     u8  = 0
hit_bi:    i16 = -1
bullet_rz: i16 = 0
bz_check:  i16 = 0
bx_check:  i16 = 0
bw_check:  i16 = 0
bh_check:  i16 = 0
player_sy: i16 = -40
alt_bar:   i16 = 0
gi:        i16 = 0
grz:       i16 = 0
gsx_l:     i16 = 0
gsy_l:     i16 = 0
gsx_r:     i16 = 0
gsy_r:     i16 = 0

# ─── Isometric projection (45°) ──────────────────────────────────────────────
def project():
    p_sx = p_rz / 2 + p_rx / 2 - 20
    p_sy = p_rz / 2 - p_rx / 2 + p_wy - 40

# ─── Draw isometric wireframe box ─────────────────────────────────────────────
def draw_box():
    p_rx = bx - player_x
    p_wy = 0
    p_rz = rz
    project()
    c0x = p_sx
    c0y = p_sy

    p_rx = bx + bw - player_x
    p_wy = 0
    p_rz = rz
    project()
    c1x = p_sx
    c1y = p_sy

    p_rx = bx - player_x
    p_wy = bh
    p_rz = rz
    project()
    c2x = p_sx
    c2y = p_sy

    p_rx = bx + bw - player_x
    p_wy = bh
    p_rz = rz
    project()
    c3x = p_sx
    c3y = p_sy

    p_rx = bx - player_x
    p_wy = bh
    p_rz = rz + 8
    project()
    c4x = p_sx
    c4y = p_sy

    p_rx = bx + bw - player_x
    p_wy = bh
    p_rz = rz + 8
    project()
    c5x = p_sx
    c5y = p_sy

    DRAW_LINE(c0x, c0y, c1x, c1y, 70)
    DRAW_LINE(c0x, c0y, c2x, c2y, 70)
    DRAW_LINE(c1x, c1y, c3x, c3y, 70)
    DRAW_LINE(c2x, c2y, c3x, c3y, 70)
    DRAW_LINE(c2x, c2y, c4x, c4y, 50)
    DRAW_LINE(c3x, c3y, c5x, c5y, 50)
    DRAW_LINE(c4x, c4y, c5x, c5y, 50)

def main():
    pass

def loop():
    joy_x = J1_X()
    joy_y = J1_Y()
    btn1  = J1_BUTTON_1()

    # ── Camera scroll ─────────────────────────────────────────────────────────
    scroll_tick = scroll_tick + 1
    if scroll_tick >= 2:
        scroll_tick = 0
        cam_z = cam_z + 1
    if cam_z >= LEVEL_LEN:
        cam_z = 0
        b0alive = 1
        b1alive = 1
        b2alive = 1
        b3alive = 1
        b4alive = 1
        b5alive = 1

    # ── Player movement ───────────────────────────────────────────────────────
    if joy_x > 20:
        player_x = player_x + 1
    if joy_x < -20:
        player_x = player_x - 1
    if joy_y > 20:
        player_y = player_y + 1
    if joy_y < -20:
        player_y = player_y - 1
    player_x = clamp(player_x, -30, 30)
    player_y = clamp(player_y, 0, 32)

    # ── Fire (debounced) ──────────────────────────────────────────────────────
    if btn1 == 1:
        if btn_prev == 0:
            if bullet_alive == 0:
                bullet_alive = 1
                bullet_abs_z = cam_z + 10
                bullet_rx = player_x
                bullet_ry = player_y
                PLAY_SFX("laser")
    btn_prev = btn1

    # ── Update and draw bullet ────────────────────────────────────────────────
    if bullet_alive == 1:
        bullet_abs_z = bullet_abs_z + 4
        bullet_rz = bullet_abs_z - cam_z
        if bullet_rz >= VIS_FAR:
            bullet_alive = 0
        else:
            p_rx = bullet_rx - player_x
            p_wy = bullet_ry
            p_rz = bullet_rz
            project()
            DRAW_VECTOR("bullet", p_sx, p_sy)

            # Hit detection — find which building the bullet hits
            hit_bi = -1
            bi = 0
            while bi < BLD_COUNT:
                bz_check = BLD_Z[bi]
                bx_check = BLD_X[bi]
                bw_check = BLD_W[bi]
                bh_check = BLD_H[bi]
                if bullet_abs_z >= bz_check:
                    if bullet_abs_z <= bz_check + 8:
                        if bullet_rx >= bx_check:
                            if bullet_rx <= bx_check + bw_check:
                                if bullet_ry <= bh_check:
                                    hit_bi = bi
                                    bi = BLD_COUNT
                bi = bi + 1

            # Apply destruction based on which building was hit
            if hit_bi >= 0:
                bullet_alive = 0
                expl_frames = 14
                expl_sx = p_sx
                expl_sy = p_sy
                score = score + 1
                if hit_bi == 0:
                    b0alive = 0
                if hit_bi == 1:
                    b1alive = 0
                if hit_bi == 2:
                    b2alive = 0
                if hit_bi == 3:
                    b3alive = 0
                if hit_bi == 4:
                    b4alive = 0
                if hit_bi == 5:
                    b5alive = 0

    # ── Explosion flash ───────────────────────────────────────────────────────
    if expl_frames > 0:
        DRAW_VECTOR("explosion", expl_sx, expl_sy)
        expl_frames = expl_frames - 1

    # ── Ground: two NE rails + SE cross-ties spanning full screen depth ────────
    # Rails run from Z=-80 (behind player, screen bottom) to Z=200 (screen top)
    # Left rail: world X = -30
    p_rx = -30 - player_x
    p_wy = 0
    p_rz = -80
    project()
    gsx_l = p_sx
    gsy_l = p_sy
    p_rz = 200
    project()
    gsx_r = p_sx
    gsy_r = p_sy
    DRAW_LINE(gsx_l, gsy_l, gsx_r, gsy_r, 25)

    # Right rail: world X = +30
    p_rx = 30 - player_x
    p_wy = 0
    p_rz = -80
    project()
    gsx_l = p_sx
    gsy_l = p_sy
    p_rz = 200
    project()
    gsx_r = p_sx
    gsy_r = p_sy
    DRAW_LINE(gsx_l, gsy_l, gsx_r, gsy_r, 25)

    # Cross-ties every 40 units from Z=-80 to Z=200 (8 ties total)
    gi = 0
    while gi < 8:
        grz = gi * 40 - 80
        p_rx = -30 - player_x
        p_wy = 0
        p_rz = grz
        project()
        gsx_l = p_sx
        gsy_l = p_sy
        p_rx = 30 - player_x
        project()
        gsx_r = p_sx
        gsy_r = p_sy
        DRAW_LINE(gsx_l, gsy_l, gsx_r, gsy_r, 18)
        gi = gi + 1

    # ── Buildings (skip destroyed ones) ──────────────────────────────────────
    bi = 0
    while bi < BLD_COUNT:
        bx = BLD_X[bi]
        bz = BLD_Z[bi]
        bw = BLD_W[bi]
        bh = BLD_H[bi]
        rz = bz - cam_z

        # Read alive flag for this index
        alive = b0alive
        if bi == 1:
            alive = b1alive
        if bi == 2:
            alive = b2alive
        if bi == 3:
            alive = b3alive
        if bi == 4:
            alive = b4alive
        if bi == 5:
            alive = b5alive

        if alive == 1:
            if rz > -20:
                if rz < VIS_FAR:
                    draw_box()

        bi = bi + 1

    # ── Player ship (vec asset — oriented along NE isometric axis) ────────────
    player_sy = player_y - 40
    DRAW_VECTOR("ship", -20, player_sy)

    # Ground shadow dot
    p_rx = 0
    p_wy = 0
    p_rz = 0
    project()
    DRAW_LINE(p_sx - 2, p_sy, p_sx + 2, p_sy, 35)

    # ── Altitude bar ─────────────────────────────────────────────────────────
    alt_bar = player_y * 2
    DRAW_LINE(-93, -120, -93, -120 + 64, 22)
    DRAW_LINE(-90, -120, -90, -120 + alt_bar, 55)

    # ── Score ─────────────────────────────────────────────────────────────────
    PRINT_NUMBER(-90, 110, score)
