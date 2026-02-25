# VPy Compiler Functionality Test Matrix

## Testing Strategy

This file tracks which VPy builtins and features are **verified working end-to-end**. We test systematically from simplest (no dependencies) to most complex, creating minimal reproducible examples for each.

Each test example should:
- Compile without errors
- Produce expected visible output on emulator
- Not depend on untested features

Once a feature is confirmed working, we move to features that depend on it.

---

## Phase 1: Core Display & Debug (PREREQUISITES)

These are the foundation for all testing. Without working display, we cannot verify anything else.

### ✅ PRINT_TEXT
- **Status:** Testing required
- **Example:** `examples/individual_tests/print_text/`
- **Test:** Display static text on screen
- **Depends on:** Nothing
- **Blocks:** All other visual tests

### ✅ PRINT_NUMBER
- **Status:** Testing required
- **Example:** `examples/individual_tests/print_number/`
- **Test:** Display numeric values, verify counter increments each frame
- **Depends on:** PRINT_TEXT
- **Blocks:** All numeric display tests

### ✅ SET_INTENSITY
- **Status:** Likely working
- **Example:** (In pang)
- **Test:** Change screen brightness to verify the function works
- **Depends on:** Nothing
- **Blocks:** (Nice to have, not critical)

---

## Phase 2: Basic Drawing (Simple Shapes)

Once PRINT_TEXT/PRINT_NUMBER confirm display is working, test drawing primitives.

### ⚠️ DRAW_LINE
- **Status:** Untested
- **Example:** `examples/individual_tests/draw_line/`
- **Test:** Draw static horizontal, vertical, diagonal lines
- **Depends on:** PRINT_TEXT (for verification text)
- **Blocks:** DRAW_POLYGON, DRAW_VECTOR, DRAW_CIRCLE

### ⚠️ DRAW_RECT
- **Status:** Untested (but likely similar to DRAW_CIRCLE)
- **Example:** `examples/individual_tests/draw_rect/`
- **Test:** Draw filled and unfilled rectangles
- **Depends on:** DRAW_LINE
- **Blocks:** None critical

### ❌ DRAW_CIRCLE
- **Status:** BROKEN (stack alignment issue, supposedly fixed in code)
- **Example:** `examples/pang_test_2e/` (existing test)
- **Test:** Draw circles with constant and variable radius
- **Known issue:** Circle disappears on joystick input (was stack bug, now fixed per MEMORY.md)
- **Depends on:** DRAW_LINE
- **Blocks:** Ball physics, enemy sprites

### ⚠️ DRAW_VECTOR
- **Status:** Untested
- **Example:** `examples/individual_tests/draw_vector/`
- **Test:** Draw vector graphics from coordinates
- **Depends on:** DRAW_LINE
- **Blocks:** Asset rendering, complex sprites

### ⚠️ DRAW_POLYGON
- **Status:** Untested
- **Example:** `examples/individual_tests/draw_polygon/`
- **Test:** Draw filled/unfilled polygons (triangles, quads)
- **Depends on:** DRAW_LINE
- **Blocks:** Advanced rendering

### ⚠️ DRAW_FILLED_RECT, DRAW_ARC, DRAW_ELLIPSE
- **Status:** Untested
- **Example:** `examples/individual_tests/draw_advanced/`
- **Test:** Advanced drawing primitives
- **Depends on:** DRAW_RECT, DRAW_CIRCLE
- **Blocks:** Advanced visuals

---

## Phase 3: Motion & Basic Input

Test ability to move things on screen and read input.

### ⚠️ J1_X / J1_Y (Joystick 1 Position)
- **Status:** BROKEN (was fixed per MEMORY.md, but needs re-verification)
- **Example:** `examples/individual_tests/joystick_position/`
- **Test:** Move joystick, verify position changes displayed on screen
- **Known issue:** Was corrupting VIA registers, supposedly fixed
- **Depends on:** PRINT_NUMBER, DRAW_CIRCLE or similar
- **Blocks:** Player control, enemy movement

### ⚠️ J1_BUTTON_1/2/3/4
- **Status:** Untested
- **Example:** `examples/individual_tests/joystick_buttons/`
- **Test:** Press buttons, display which button pressed
- **Depends on:** PRINT_NUMBER
- **Blocks:** Game controls, menu navigation

### ⚠️ UPDATE_BUTTONS
- **Status:** Untested
- **Example:** (In pang, but not isolated)
- **Test:** Button debouncing and state tracking
- **Depends on:** J1_BUTTON_*
- **Blocks:** Reliable input handling

### ⚠️ MOVE (Set draw position)
- **Status:** Untested
- **Example:** `examples/individual_tests/draw_move/`
- **Test:** MOVE to position, then DRAW_LINE from that position
- **Depends on:** DRAW_LINE
- **Blocks:** Relative drawing

---

## Phase 4: Variables & State Management

Test variable types and state changes.

### ✅ Basic Variables (i16)
- **Status:** WORKING (tested in pang)
- **Example:** (pang compiles)
- **Test:** Increment/decrement counters, store positions
- **Depends on:** Nothing
- **Blocks:** All game logic

### ✅ Variable-Sized Types (u8, i8, u16)
- **Status:** WORKING (verified 2026-02-21)
- **Example:** `examples/pang8bits/`, `examples/test_types/`
- **Test:** Define variables with type annotations, verify correct size in RAM
- **Depends on:** Basic Variables
- **Blocks:** Memory-optimized games

### ❌ Const Arrays with Type Annotations
- **Status:** BROKEN (bug documented in MEMORY.md)
- **Example:** (pang fails when using `const array: u8 = [...]`)
- **Test:** Define const array with type, read values
- **Known issue:** Simple u8 arrays work, complex ones cause logic failures
- **Workaround:** Don't use type annotations on const arrays
- **Depends on:** Variable-Sized Types
- **Blocks:** Optimized level/asset data

### ⚠️ Mutable Arrays
- **Status:** WORKING (used in pang for enemy storage)
- **Example:** (pang uses these)
- **Test:** Create array, modify elements, read them back
- **Depends on:** Basic Variables
- **Blocks:** Game object storage

### ⚠️ Structs
- **Status:** BROKEN (parser works, codegen missing)
- **Example:** (commented out in jetpac)
- **Test:** Define struct, instantiate, access fields
- **Known issue:** No codegen support for field access
- **Depends on:** Basic Variables
- **Blocks:** Organized game objects

---

## Phase 5: Game Loop Mechanics

Test frame-by-frame logic and state transitions.

### ✅ Main Loop + Variable Updates
- **Status:** WORKING (pang loop runs)
- **Example:** (pang)
- **Test:** Variables update each frame, display counter
- **Depends on:** Variables, PRINT_NUMBER
- **Blocks:** All game logic

### ✅ WAIT_RECAL
- **Status:** WORKING (auto-injected)
- **Example:** (pang)
- **Test:** Game runs at consistent frame rate
- **Depends on:** Main Loop
- **Blocks:** Timing-dependent features

### ⚠️ Function Calls & Return Values
- **Status:** WORKING (compiled in pang, logic verified)
- **Example:** `examples/pang/` (update_enemies, draw_enemies)
- **Test:** Call user functions, modify state, return to main loop
- **Known issue:** Was suspected broken, now verified working (per MEMORY.md)
- **Depends on:** Variables, Main Loop
- **Blocks:** Modular game logic

### ⚠️ Conditionals (if/else)
- **Status:** WORKING (in pang)
- **Example:** (pang state machine)
- **Test:** Branch based on variable, execute different code paths
- **Depends on:** Variables
- **Blocks:** Game logic, AI

### ⚠️ Loops (while, for)
- **Status:** WORKING (in pang)
- **Example:** (pang for loops over arrays)
- **Test:** Iterate over array, execute body multiple times
- **Depends on:** Variables, Arrays
- **Blocks:** Batch operations, efficient rendering

---

## Phase 6: Audio

Test sound and music playback.

### ⚠️ PLAY_MUSIC
- **Status:** Untested end-to-end
- **Example:** `examples/individual_tests/play_music/`
- **Test:** Play .vmus file, hear music in emulator
- **Depends on:** Main Loop
- **Blocks:** Game audio

### ⚠️ STOP_MUSIC
- **Status:** Untested
- **Example:** (In pang, needs verification)
- **Test:** Start music, stop it, verify silence
- **Depends on:** PLAY_MUSIC
- **Blocks:** Music transitions

### ⚠️ PLAY_SFX
- **Status:** Untested
- **Example:** `examples/individual_tests/play_sfx/`
- **Test:** Play .vsfx effect, hear sound in emulator
- **Depends on:** Main Loop
- **Blocks:** Game audio effects

### ⚠️ AUDIO_UPDATE, MUSIC_UPDATE
- **Status:** WORKING (auto-injected)
- **Example:** (pang)
- **Test:** Audio continues playing frame-to-frame
- **Depends on:** PLAY_MUSIC, PLAY_SFX
- **Blocks:** Audio playback

---

## Phase 7: Input (Advanced)

Test joystick 2 and advanced input.

### ⚠️ J2_X / J2_Y (Joystick 2)
- **Status:** Untested
- **Example:** `examples/individual_tests/joystick2/`
- **Test:** Read J2 position, display on screen
- **Depends on:** J1_X/J1_Y working
- **Blocks:** Two-player games

### ⚠️ J2_DIGITAL_X/Y, J2_ANALOG_X/Y
- **Status:** Untested
- **Example:** (In builtins but not tested)
- **Test:** Read J2 advanced input modes
- **Depends on:** J2_X/J2_Y
- **Blocks:** Advanced input handling

---

## Phase 8: Levels & Tilemap

Test level system and assets.

### ⚠️ LOAD_LEVEL
- **Status:** Untested
- **Example:** (In pang but not verified isolated)
- **Test:** Load .vlevel file, verify contents accessible
- **Depends on:** Const Arrays (working)
- **Blocks:** Level management

### ⚠️ SHOW_LEVEL
- **Status:** Untested
- **Example:** (In pang but visual verification needed)
- **Test:** Display level on screen, see correct tiles
- **Depends on:** LOAD_LEVEL
- **Blocks:** Level rendering

### ⚠️ GET_LEVEL_WIDTH/HEIGHT/TILE
- **Status:** Untested
- **Example:** (In pang but not verified isolated)
- **Test:** Query level dimensions and tile values
- **Depends on:** LOAD_LEVEL
- **Blocks:** Level interaction

### ⚠️ UPDATE_LEVEL
- **Status:** Untested
- **Example:** (In pang but not verified)
- **Test:** Modify level during gameplay
- **Depends on:** LOAD_LEVEL, Conditionals
- **Blocks:** Dynamic level changes

---

## Phase 9: Math & Utilities

Test helper functions and math operations.

### ✅ abs, min, max, clamp
- **Status:** WORKING (basic arithmetic)
- **Example:** (pang uses)
- **Test:** Call functions, verify results
- **Depends on:** Variables
- **Blocks:** Game logic

### ⚠️ sin, cos, tan, atan2, sqrt, pow
- **Status:** WORKING (LUT-based)
- **Example:** (In pang but not isolated)
- **Test:** Calculate angles, distances for movement
- **Depends on:** Variables
- **Blocks:** Physics, animation

### ⚠️ rand, rand_range
- **Status:** WORKING (in builtins)
- **Example:** (In pang but not verified isolated)
- **Test:** Generate random numbers, verify distribution
- **Depends on:** Variables
- **Blocks:** Randomized gameplay

### ⚠️ wait()
- **Status:** WORKING (simple pause)
- **Example:** (In pang)
- **Test:** Pause game for N frames
- **Depends on:** Main Loop
- **Blocks:** Timing, animations

### ⚠️ beep()
- **Status:** Untested
- **Example:** `examples/individual_tests/beep/`
- **Test:** Produce system beep sound
- **Depends on:** Nothing
- **Blocks:** UI feedback

### ⚠️ fade_in, fade_out
- **Status:** Untested
- **Example:** `examples/individual_tests/fade/`
- **Test:** Fade screen in/out
- **Depends on:** SET_INTENSITY
- **Blocks:** Screen transitions

### ⚠️ peek, poke (Memory access)
- **Status:** PARTIALLY WORKING (constants only)
- **Example:** (In pang but limited use)
- **Test:** Read/write memory addresses
- **Known limitation:** Only works with constant addresses
- **Depends on:** Nothing
- **Blocks:** Low-level tricks

### ⚠️ asm() (Inline assembly)
- **Status:** UNTESTED
- **Example:** `examples/individual_tests/inline_asm/`
- **Test:** Execute raw M6809 instructions
- **Depends on:** Nothing
- **Blocks:** Performance optimization

---

## Phase 10: NOT IMPLEMENTED (Known Gaps)

These features are documented but don't work yet.

### ❌ DRAW_TO(x, y)
- **Status:** BROKEN (parsed, but codegen incomplete)
- **Example:** None
- **Reason:** Codegen never handles the case
- **Impact:** Relative drawing not possible

### ❌ SET_SCALE(factor)
- **Status:** MISSING (no code anywhere)
- **Example:** None
- **Reason:** Never implemented
- **Impact:** Can't scale graphics

### ❌ len(array)
- **Status:** BROKEN (returns hardcoded 0)
- **Example:** None
- **Reason:** Stub implementation only
- **Impact:** Can't query array lengths dynamically

### ❌ GET_TIME()
- **Status:** PLACEHOLDER (not functional)
- **Example:** None
- **Reason:** Returns dummy value
- **Impact:** Can't measure elapsed time precisely

### ❌ Struct Field Access
- **Status:** BROKEN (parser accepts, codegen missing)
- **Example:** (commented out in jetpac)
- **Reason:** No codegen support
- **Impact:** Can't use structs for organization

### ❌ Enum Support
- **Status:** NOT IMPLEMENTED
- **Example:** None
- **Reason:** Zero implementation
- **Impact:** Can't use enums for state

---

## Test Execution Plan

### Week 1: Phase 1-2 (Display & Drawing)
- [ ] Create `test_print_text` example
- [ ] Create `test_print_number` example
- [ ] Create `test_draw_line` example
- [ ] Create `test_draw_rect` example
- [ ] Re-test DRAW_CIRCLE (verify stack fix)
- [ ] Create `test_draw_vector` example

### Week 2: Phase 3-4 (Input & Variables)
- [ ] Re-test J1_X/J1_Y (verify VIA fix)
- [ ] Create `test_joystick_buttons` example
- [ ] Verify variable-sized types (already passing)
- [ ] Create comprehensive variable test

### Week 3: Phase 5-6 (Loop & Audio)
- [ ] Verify main loop with state updates
- [ ] Test function calls (update_enemies, draw_enemies in pang)
- [ ] Test PLAY_MUSIC (pang_test_5)
- [ ] Test PLAY_SFX isolated

### Week 4: Phase 7-9 (Input, Levels, Math)
- [ ] Test J2 inputs
- [ ] Test level loading and rendering
- [ ] Test math functions

### Week 5+: Debugging & Polish
- [ ] Fix ❌ items if time permits
- [ ] Optimize working features
- [ ] Document results

---

## Success Criteria

A feature is ✅ **VERIFIED WORKING** when:
1. A minimal example compiles without errors
2. The compiled binary runs in the emulator
3. Visual/audio output matches expected behavior
4. The example can be added to `examples/` as proof

All other features are ⚠️ **UNTESTED** or ❌ **BROKEN**.
