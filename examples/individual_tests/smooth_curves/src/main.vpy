# TEST: SMOOTH_CURVES (PiTrex target)
#
# Demonstrates smooth continuous Bézier curve drawing via v_drawBezierCubic.
# Unlike DRAW_CIRCLE (16 line segments with beam-off between each), DRAW_BEZIER
# keeps the beam lit throughout the entire stroke — no vertex bright spots.
#
# CIRCLE: 4 cubic Bézier segments, radius=55, k=30 (= 55 * 0.5523)
#   Each segment covers 90°. Control offsets follow the tangent direction.
#
# SPIRAL: Archimedean spiral, 2 full turns, radius 8→56 (step 6 per quarter).
#   8 cubic Bézier segments; start/end radii differ so the spiral expands.
#
# Expected: Both shapes drawn without visible vertex kinks or bright spots.
# Target: PiTrex only (v_drawBezierCubic lives in libpitrex).

META TITLE = "SMOOTH CURVES"

def loop():
    SET_INTENSITY(100)

    # ── Smooth circle, radius 55 ──────────────────────────────────────────
    # CP formula: CP1 = P0 + k*tangent(α),  CP2 = P3 − k*tangent(β)
    # tangent at angle θ (CCW) = (−sinθ, cosθ)
    # k = round(55 * 0.5523) = 30

    # Q1: (55,0) → (0,55)
    DRAW_BEZIER( 55,   0,   55,  30,   30,  55,    0,  55,   16, 100)
    # Q2: (0,55) → (−55,0)
    DRAW_BEZIER(  0,  55,  -30,  55,  -55,  30,  -55,   0,   16, 100)
    # Q3: (−55,0) → (0,−55)
    DRAW_BEZIER(-55,   0,  -55, -30,  -30, -55,    0, -55,   16, 100)
    # Q4: (0,−55) → (55,0)
    DRAW_BEZIER(  0, -55,   30, -55,   55, -30,   55,   0,   16, 100)

    # ── Archimedean spiral, 2 turns ───────────────────────────────────────
    # Radii at segment boundaries: 8, 14, 20, 26, 32, 38, 44, 50, 56
    # CP1 = P0 + r0*k*tangent(α),  CP2 = P3 − r3*k*tangent(β),  k≈0.55

    # Turn 1
    # Seg 0:  (8,0)   → (0,14)    [0°→90°,   r 8→14]
    # DRAW_BEZIER(  8,   0,    8,   4,    8,  14,    0,  14,   12,  80)
    # Seg 1:  (0,14)  → (−20,0)   [90°→180°, r 14→20]
    DRAW_BEZIER(  0,  14,   -8,  14,  -20,  11,  -20,   0,   12,  80)
    # Seg 2:  (−20,0) → (0,−26)   [180°→270°,r 20→26]
    DRAW_BEZIER(-20,   0,  -20, -11,  -14, -26,    0, -26,   12,  80)
    # Seg 3:  (0,−26) → (32,0)    [270°→360°,r 26→32]
    DRAW_BEZIER(  0, -26,   14, -26,   32, -18,   32,   0,   12,  80)

    # Turn 2
    # Seg 4:  (32,0)  → (0,38)    [0°→90°,   r 32→38]
    DRAW_BEZIER( 32,   0,   32,  18,   21,  38,    0,  38,   12,  80)
    # Seg 5:  (0,38)  → (−44,0)   [90°→180°, r 38→44]
    DRAW_BEZIER(  0,  38,  -21,  38,  -44,  24,  -44,   0,   12,  80)
    # Seg 6:  (−44,0) → (0,−50)   [180°→270°,r 44→50]
    DRAW_BEZIER(-44,   0,  -44, -24,  -28, -50,    0, -50,   12,  80)
    # Seg 7:  (0,−50) → (56,0)    [270°→360°,r 50→56]
    DRAW_BEZIER(  0, -50,   28, -50,   56, -31,   56,   0,   12,  80)

    DRAW_VECTOR("test", 0, -70)
