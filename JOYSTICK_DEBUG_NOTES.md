# Joystick Input Corruption Issue

## Problem
- **pang_test_2**: Circle with joystick input disappears when stick moves
- **pang_test_2b**: Direct J1_X/Y calls in DRAW_CIRCLE also disappears
- **pang_test_2c**: Fixed values work fine (circle visible)

## Test Sequence for Emulator

Test these in order to isolate the issue:

### 1. Test 2C (Fixed Values) - Should Work ✓
- Draws circle at fixed position (30, 20)
- Does NOT call J1_X() or J1_Y()
- **Expected:** Circle is visible and stable

### 2. Test 2 (With Array) - Problem Case
- Calls J1_X() and J1_Y()
- Stores in joystick1_state array
- Passes array values to DRAW_CIRCLE
- **Expected:** Circle should follow joystick, but **ACTUALLY DISAPPEARS**

### 3. Test 2B (Direct Call) - Problem Case
- Calls J1_X() and J1_Y() directly in DRAW_CIRCLE arguments
- No array storage
- **Expected:** Should work, but **ALSO DISAPPEARS**

## Diagnosis Guide

### If Test 2C works but Test 2B fails:
- Problem is in J1_X_BUILTIN or J1_Y_BUILTIN
- Could be:
  - Stack corruption
  - Register corruption
  - Direct page changes not restored
  - DP_to_C8/D0 calls not working correctly

### If Test 2C works and Test 2B works but Test 2 fails:
- Problem is in array access
- Could be:
  - Array pointer incorrect
  - Array overflow writing to adjacent variables
  - joystick1_state being corrupted

### If Test 2C fails:
- Problem is in DRAW_CIRCLE itself (not joystick related)
- Should not happen since we fixed DRAW_CIRCLE_RADIUS

## Potential Root Causes

1. **J1X_BUILTIN/J1Y_BUILTIN DP manipulation**
   - Changes DP from $C8 to $D0 and back
   - If not restored, subsequent code fails
   - File: buildtools/vpy_codegen/src/m6809/joystick.rs

2. **Joy_Analog ($F1F5) side effects**
   - BIOS function might not preserve all registers
   - Could modify stack pointer
   - Could write to wrong memory locations

3. **Array address calculation**
   - joystick1_state array stored at $C88D
   - Index calculation might overflow or be wrong
   - File: buildtools/vpy_codegen/src/m6809/functions.rs

4. **DRAW_CIRCLE argument passing**
   - Values might not be loaded correctly after joystick calls
   - TMPVAL, TMPPTR, TMPPTR2 might be corrupted
   - File: buildtools/vpy_codegen/src/m6809/drawing.rs

## Next Steps

Run tests 2C, 2, and 2B in the emulator and report:
1. Does test 2C show a stable circle? (YES/NO)
2. Does test 2 circle disappear when you move joystick? (YES/NO)
3. Does test 2B circle disappear when you move joystick? (YES/NO)
4. When does it disappear? Immediately? After a few frames?
5. Does it reappear when you return to center (0,0)?

This will help narrow down which component is failing.
