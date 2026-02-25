# DRAW_CIRCLE Diagnostic Tests

## Hypothesis
DRAW_CIRCLE_RUNTIME is generating a deformed octagon approximation instead of a proper circle.

## Test Sequence (Run in Emulator)

### Test 2C: DRAW_CIRCLE (Fixed Values)
```vpy
x_val = 30
y_val = 20
DRAW_CIRCLE(x_val, y_val, 10, 127)
```

**Expected:** A circular shape centered at (30, 20)

**What to observe:**
- Is it actually circular?
- Or is it deformed (star-like, points sticking out)?
- Are some segments missing or displaced?
- Does joystick movement cause it to disappear?

### Test 2D: DRAW_VECTOR (Square Vector)
```vpy
x_val = 30
y_val = 20
DRAW_VECTOR("test_square", x_val, y_val)
```

**Expected:** A perfect 40x40 square centered at (30, 20)

**What to observe:**
- Is the square perfectly drawn?
- Are corners sharp and square?
- Does it render without artifacts?
- Does joystick movement cause it to disappear?

## Diagnosis

### If 2C is deformed BUT 2D is perfect
- **Problem:** DRAW_CIRCLE_RUNTIME octagon algorithm
- **Root cause:** Incorrect delta calculations in the 8 segment drawing
- **Affected code:** buildtools/vpy_codegen/src/m6809/drawing.rs lines 516-575

### If both 2C and 2D are deformed
- **Problem:** Something else (DP corruption, memory corruption, etc.)
- **Affected code:** Could be joystick, BIOS functions, or memory layout

### If both 2C and 2D work perfectly with joystick
- **Status:** Problem resolved! ✓
- **Action:** None needed

## Known Issues in DRAW_CIRCLE_RUNTIME

The octagon approximation uses these 8 segments:
```
Seg 1: NE to N  (dx=-r/2, dy=-r)
Seg 2: N to NW  (dx=-r, dy=-r/2)
Seg 3: NW to W  (dx=-r/2, dy=+r)
Seg 4: W to SW  (dx=+r/2, dy=+r)
Seg 5: SW to S  (dx=+r, dy=+r/2)
Seg 6: S to SE  (dx=+r, dy=-r/2)
Seg 7: SE to E  (dx=+r/2, dy=-r)
Seg 8: E to NE  (dx=-r/2, dy=-r)
```

If the circle looks like 2 triangles or a star, the issue is likely:
- Incorrect ratio calculations (0.5 vs other values)
- Wrong register usage (A vs B confusion)
- Stack corruption in segment drawing

## Files to Check if Problem Found

**If DRAW_CIRCLE is broken:**
- `buildtools/vpy_codegen/src/m6809/drawing.rs` (DRAW_CIRCLE_RUNTIME generation)
- Check segment delta calculations
- Verify DRAW_CIRCLE_RADIUS is loaded correctly

**If DRAW_VECTOR works but DRAW_CIRCLE doesn't:**
- The BIOS drawing functions work fine
- DRAW_CIRCLE_RUNTIME has a bug in the octagon algorithm
