# Vector-fusion stress test.
# A circle traced as 48 OPEN 2-point segments that share endpoints, so Stage-2
# path fusion (VPY_VEC_MERGE_PATHS=1) chains them into ONE continuous beam sweep
# with no per-segment re-zero. Static screen: integrator drift is the only
# variable, so any trembling / the circle failing to close reveals the drift a
# given VPY_VEC_MERGE_MAX_SEGS cap allows. Sweep the cap (8 -> 16 -> 32 -> 65)
# on real hardware to find where the shape starts to wobble.

META TITLE = "FUSION STRESS"

def main():
    pass

def loop():
    SET_INTENSITY(127)
    DRAW_VECTOR("stress", 0, 0)
