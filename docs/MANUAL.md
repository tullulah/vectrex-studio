# VPy Language Manual

VPy is a Python-inspired language that compiles to MC6809 assembly for the Vectrex console. It is statically typed (all values are 16-bit integers), compiled, and designed for game development on constrained hardware.

---

## Table of Contents

1. [Program Structure](#1-program-structure)
2. [Variables and Constants](#2-variables-and-constants)
3. [Types and Values](#3-types-and-values)
4. [Operators](#4-operators)
5. [Control Flow](#5-control-flow)
6. [Functions](#6-functions)
7. [Arrays](#7-arrays)
8. [META Directives](#8-meta-directives)
9. [Built-in Functions](#9-built-in-functions)
10. [VectorList DSL](#10-vectorlist-dsl)
11. [Language Rules and Gotchas](#11-language-rules-and-gotchas)
12. [Known Limitations](#12-known-limitations)

---

## 1. Program Structure

Every VPy program has two special functions:

```python
def main():
    # Called once at startup — initialization only
    SET_INTENSITY(127)
    player_x = 0

def loop():
    # Called every frame automatically — game logic goes here
    draw_player()
```

- `main()` runs once when the cartridge starts. Use it for initialization.
- `loop()` runs every frame (~50 fps). All game logic, drawing, and input handling goes here.
- You do not need an explicit frame loop — the runtime calls `loop()` automatically.
- Other functions can be defined and called freely from `main()` or `loop()`.

### Minimal example

```python
META TITLE = "HELLO"

def main():
    SET_INTENSITY(100)

def loop():
    PRINT_TEXT(-50, 0, "HELLO WORLD")
```

---

## 2. Variables and Constants

### Global variables

Variables declared at the top level (outside functions) are globals, persisted across frames:

```python
player_x = 0
player_y = 0
score = 0
```

### Local variables

Variables declared inside a function are local to that function call:

```python
def update_player():
    dx = joy_x * 2      # local
    player_x = player_x + dx   # player_x is global
```

The compiler determines scope automatically: if the name was declared at the top level, assignment inside a function modifies the global. Otherwise it's local.

### Constants

`const` declares a compile-time constant. Constants cannot be reassigned:

```python
const MAX_ENEMIES = 8
const GRAVITY = 1
const GROUND_Y = -70
```

### Compound assignment

```python
x += 1
x -= 5
x *= 2
counter += 1
```

---

## 3. Types and Values

VPy has a single type: **16-bit integer**.

- All arithmetic is unsigned 16-bit (values wrap modulo 65536).
- Truthiness: `0` is false, any other value is true.
- No floating point.
- No booleans (`True`/`False`) — use `1` and `0` instead.

### Why 16-bit only?

VPy uses a unified 16-bit type for simplicity — the compiler doesn't need to handle multiple types or conversions. However, this is a notable limitation: **the Vectrex hardware is fundamentally 8-bit** (joystick values, display coordinates, and intensity are all 8-bit), so VPy wastes approximately **20% of available RAM** by storing everything as 16-bit. A typical game loses ~200 bytes of the 970 bytes available.

This trade-off prioritizes compiler simplicity over memory efficiency. For resource-constrained retro development, 8-bit types would be preferable.

### Integer literals

```python
x = 42        # decimal
x = 0xFF      # hexadecimal
x = 0b1010    # binary
x = -7        # negative (compiled as 0 - 7)
```

### String literals

Strings are used as arguments to built-in functions or stored in arrays. They are zero-terminated (high-bit terminated for Vectrex BIOS):

```python
PRINT_TEXT(-50, 0, "GAME OVER")
const names = ["LEVEL 1", "LEVEL 2", "LEVEL 3"]
```

---

## 4. Operators

### Arithmetic

| Operator | Description |
|----------|-------------|
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Integer division (truncates) |
| `%` | Modulo |
| `-x` | Unary negation (compiled as `0 - x`) |

### Bitwise

| Operator | Description |
|----------|-------------|
| `&` | AND |
| `\|` | OR |
| `^` | XOR |
| `~` | NOT (bitwise complement) |
| `<<` | Shift left |
| `>>` | Shift right |

### Comparison

`==`, `!=`, `<`, `<=`, `>`, `>=`

Chained comparisons are supported: `0 < x < 100` expands to `(0 < x) and (x < 100)`.

### Logical

`and`, `or`, `not` — short-circuit evaluation.

### Operator precedence (high to low)

1. Unary: `- + not ~`
2. `* / %`
3. `+ -`
4. `<< >>`
5. `&`
6. `^`
7. `|`
8. Comparisons (including chained)
9. `and`
10. `or`

---

## 5. Control Flow

### if / elif / else

```python
if x > 0:
    move_right()
elif x < 0:
    move_left()
else:
    stay()
```

### while

```python
while active == 1:
    update()
    if done == 1:
        break
```

### for (range-based)

```python
for i in range(0, 8):
    if enemy_active[i] == 1:
        update_enemy(i)

# With step:
for i in range(0, 100, 5):
    draw_tick(i)
```

- `range(start, end)` — runs while `i < end`, step defaults to 1.
- `range(start, end, step)` — custom step.
- The loop variable is always local to the loop.

### for (array iteration)

```python
for enemy in enemies:
    if enemy > 0:
        draw_enemy(enemy)
```

### switch / case

```python
switch screen:
    case STATE_TITLE:
        draw_title()
    case STATE_GAME:
        draw_game()
    default:
        draw_error()
```

### break / continue

Work as in Python — `break` exits the loop, `continue` skips to the next iteration.

---

## 6. Functions

```python
def add(a, b):
    return a + b

def draw_player(x, y, frame):
    DRAW_VECTOR("player", x, y)
```

- Up to 4 parameters per function.
- Parameters are passed through `VAR_ARG0`..`VAR_ARG3` on the 6809.
- Return value is stored in the D register (16-bit).
- Functions can call other functions freely.
- Recursion is not safe (no stack depth protection).

---

## 7. Arrays

### Mutable arrays

```python
enemy_active = [0, 0, 0, 0, 0, 0, 0, 0]
enemy_x = [0, 0, 0, 0, 0, 0, 0, 0]
```

### Constant arrays (read-only)

```python
const level_names = ["LEVEL 1", "LEVEL 2", "LEVEL 3"]
const x_coords = [40, 40, -40, -10, 20, 50]
```

### Access and assignment

```python
x = enemy_x[i]          # read by index
enemy_x[i] = new_x      # write by index
count = len(enemy_x)    # array length
```

### for-in over arrays

```python
for state in enemy_active:
    if state == 1:
        active_count += 1
```

### Notes

- Array size is fixed at compile time.
- Index must be within bounds — no runtime bounds checking.
- Coordinates are clamped to 8-bit signed (-128..127) for drawing.

---

## 8. META Directives

META directives go at the top of the entry file and customize the ROM header:

```python
META TITLE = "PANG"
META COPYRIGHT = "g GCE 2025"
META MUSIC = music1
META MUSIC = "0"        # disables startup music
```

| Directive | Description |
|-----------|-------------|
| `META TITLE` | Game title (max 24 chars, auto-uppercased) |
| `META COPYRIGHT` | Copyright string (default: `g GCE 1998`) |
| `META MUSIC` | BIOS music symbol played at startup, or `"0"` to disable |

---

## 9. Built-in Functions

VPy is case-insensitive, so `DRAW_LINE`, `draw_line`, and `Draw_Line` are all the same.

### Frame control

| Function | Description |
|----------|-------------|
| `SET_INTENSITY(val)` | Set beam intensity (0–127) |

> **Note:** `WAIT_RECAL` is **automatically injected** by the compiler at the start of every `loop()` call. Do not call it manually — it must never appear in VPy source code.

### Drawing

| Function | Description |
|----------|-------------|
| `MOVE(x, y)` | Move beam to position without drawing |
| `DRAW_LINE(x0, y0, x1, y1, intensity)` | Draw a line segment |
| `DRAW_CIRCLE(cx, cy, diam, intensity)` | Draw a circle (16 segments) |
| `DRAW_CIRCLE_SEG(segs, cx, cy, diam, intensity)` | Draw a circle with custom segment count |
| `DRAW_POLYGON(x0, y0, x1, y1, ..., intensity)` | Draw a polygon |
| `DRAW_VECTOR("name", x, y)` | Draw a `.vec` vector asset at position (x, y) |
| `DRAW_VECTOR_EX("name", x, y, mirror, intensity)` | Draw a `.vec` asset with mirror and intensity override |
| `DRAW_RECT(x, y, w, h, intensity)` | Draw a rectangle outline |
| `DRAW_FILLED_RECT(x, y, w, h, intensity)` | Draw a filled rectangle |
| `DRAW_ARC(segs, cx, cy, r, start_deg, sweep_deg, intensity)` | Draw an arc |
| `DRAW_ELLIPSE(cx, cy, rx, ry, intensity)` | Draw an ellipse |

**Parameters:**
- `mirror` values for `DRAW_VECTOR_EX`: `0`=none, `1`=flip X, `2`=flip Y, `3`=flip both
- All coordinates are 8-bit signed (-128..127), clamped at compile time
- Intensity values: 0 (off) to 127 (maximum brightness)

### Text & Debug

| Function | Description |
|----------|-------------|
| `PRINT_TEXT(x, y, "text")` | Print a string at screen position |
| `PRINT_TEXT(x, y, var)` | Print a string variable |
| `PRINT_NUMBER(x, y, number)` | Print a 16-bit integer value |
| `DEBUG_PRINT(value)` | Debug output to console (editor only) |
| `DEBUG_PRINT_LABELED("label", value)` | Debug output with label |
| `DEBUG_PRINT_STR("text")` | Debug string output |

### Input — Joystick 1

| Function | Description |
|----------|-------------|
| `J1_X()` | Return X-axis value (-128..127) |
| `J1_Y()` | Return Y-axis value (-128..127) |
| `J1_BUTTON_1()` | Returns 1 on press (rising edge), 0 otherwise |
| `J1_BUTTON_2()` | Same for button 2 |
| `J1_BUTTON_3()` | Same for button 3 |
| `J1_BUTTON_4()` | Same for button 4 |

### Input — Joystick 2

| Function | Description |
|----------|-------------|
| `J2_X()` | Return X-axis value (-128..127) |
| `J2_Y()` | Return Y-axis value (-128..127) |
| `J2_BUTTON_1()` | Returns 1 on press (rising edge), 0 otherwise |
| `J2_BUTTON_2()` | Same for button 2 |
| `J2_BUTTON_3()` | Same for button 3 |
| `J2_BUTTON_4()` | Same for button 4 |
| `J2_ANALOG_X()` | Raw analog X value |
| `J2_ANALOG_Y()` | Raw analog Y value |
| `J2_DIGITAL_X()` | Digital X direction (-1, 0, +1) |
| `J2_DIGITAL_Y()` | Digital Y direction (-1, 0, +1) |
| `J2_BUTTON_UP()` | Returns 1 if up button pressed |
| `J2_BUTTON_DOWN()` | Returns 1 if down button pressed |
| `J2_BUTTON_LEFT()` | Returns 1 if left button pressed |
| `J2_BUTTON_RIGHT()` | Returns 1 if right button pressed |

### Input — Button Updates

| Function | Description |
|----------|-------------|
| `UPDATE_BUTTONS()` | Poll and update all button states (edge detection) |

### Audio

| Function | Description |
|----------|-------------|
| `PLAY_MUSIC("name")` | Play a `.vmus` music file |
| `STOP_MUSIC()` | Stop current music |
| `PLAY_SFX("name")` | Play a `.vsfx` sound effect |
| `AUDIO_UPDATE()` | Update audio engine state (called automatically in loop) |
| `MUSIC_UPDATE()` | Update music playback (called automatically in loop) |

### Level System

| Function | Description |
|----------|-------------|
| `LOAD_LEVEL("name")` | Load a `.vplay` level file into memory |
| `SHOW_LEVEL()` | Render the currently loaded level to screen |
| `UPDATE_LEVEL()` | Update level state (tile animations, etc.) |
| `GET_LEVEL_WIDTH()` | Return width of current level in tiles |
| `GET_LEVEL_HEIGHT()` | Return height of current level in tiles |
| `GET_LEVEL_TILE(x, y)` | Return tile value at position (x, y) |

### Math

#### Basic Functions

| Function | Description |
|----------|-------------|
| `abs(x)` | Absolute value |
| `min(a, b)` | Minimum of two values |
| `max(a, b)` | Maximum of two values |
| `clamp(v, lo, hi)` | Clamp value between lo and hi |

#### Trigonometry (Buildtools only)

| Function | Description |
|----------|-------------|
| `sin(a)` | Sine — argument 0..127 covers full circle, result -127..127 |
| `cos(a)` | Cosine — same range as sin |
| `tan(a)` | Tangent — argument 0..127, result varies |
| `atan2(y, x)` | Two-argument arctangent (returns angle 0..127) |

#### Power & Roots (Buildtools only)

| Function | Description |
|----------|-------------|
| `sqrt(x)` | Integer square root |
| `pow(x, y)` | Integer power: x raised to the y-th power |

#### Random Numbers (Buildtools only)

| Function | Description |
|----------|-------------|
| `rand()` | Return random value 0..65535 |
| `rand_range(min, max)` | Return random value in range [min, max) |

**Note:** All trigonometric functions use 128-entry lookup tables for performance. Angles wrap at 128 (360 degrees).

### Utilities (Buildtools only)

| Function | Description |
|----------|-------------|
| `wait(frames)` | Wait (pause) for N frame cycles |
| `beep()` | Emit a beep sound |
| `fade_in()` | Fade display from black to full intensity |
| `fade_out()` | Fade display from full intensity to black |
| `peek(addr)` | Read 16-bit value from memory address (constant only) |
| `poke(addr, value)` | Write 16-bit value to memory address (constant only) |

**Note:** `peek()` and `poke()` only support constant addresses known at compile time.

### Advanced (Buildtools only)

| Function | Description |
|----------|-------------|
| `asm("code")` | Inline raw MC6809 assembly code |

---

## 10. VectorList DSL

`vectorlist` blocks define reusable static vector graphics compiled into the ROM:

```python
vectorlist player_sprite:
    SET_INTENSITY(0x7F)
    MOVE(-8, -8)
    RECT(-8, -8, 8, 8)
    CIRCLE(0, 0, 12, 24)

def draw_player():
    DRAW_VECTORLIST("player_sprite")
```

### Available commands

| Command | Description |
|---------|-------------|
| `MOVE(x, y)` | Move beam to absolute position |
| `SET_INTENSITY(val)` | Set beam intensity |
| `SET_ORIGIN()` | Reset to (0,0) — same as `ORIGIN` |
| `ORIGIN` | Reset to (0,0) (no parentheses) |
| `INTENSITY(val)` | Set intensity (alias for SET_INTENSITY) |
| `RECT(x1, y1, x2, y2)` | Rectangle (4 segments) |
| `POLYGON(N, x0, y0, x1, y1, ..., xN-1, yN-1)` | Closed polygon with N vertices |
| `CIRCLE(cx, cy, r)` | Circle (16 segments) |
| `CIRCLE(cx, cy, r, segs)` | Circle with custom segment count |
| `ARC(cx, cy, r, start_deg, sweep_deg)` | Open arc (16 segments) |
| `ARC(cx, cy, r, start_deg, sweep_deg, segs)` | Arc with custom segment count |
| `SPIRAL(cx, cy, r_start, r_end, turns)` | Spiral (64 segments) |
| `SPIRAL(cx, cy, r_start, r_end, turns, segs)` | Spiral with custom segment count |

### Notes

- Coordinates are 8-bit signed (-128..127).
- The backend automatically inserts a `MOVE(0,0)` at the start and moves the first `SET_INTENSITY` after it.
- Consecutive duplicate `ORIGIN` or `MOVE` commands are collapsed.
- Dense vectorlists can cause flicker — split into multiple lists drawn on alternating frames if needed.

---

## 11. Language Rules and Gotchas

### Case-insensitivity

VPy is case-insensitive. `INTENSITY`, `intensity`, and `Intensity` are the same identifier. This means **built-in names cannot be used as variable names**:

```python
# BAD — conflicts with built-in
intensity = 50       # ERROR: 'intensity' is a built-in

# GOOD — use a different name
brightness = 50
```

Common conflicts to avoid: `intensity`, `sin`, `cos`, `tan`, `min`, `max`, `abs`, `clamp`, `move`.

### Variable scope

- Top-level assignments → global (allocated in RAM, persisted across frames)
- Assignments inside a function → local (stack frame, discarded when function returns)
- There is no `global` keyword — globals are accessed automatically

### 16-bit unsigned arithmetic

All values wrap at 65536. Negative numbers are represented as two's complement:

```python
x = -1      # compiled as 0xFFFF = 65535
x = -70     # compiled as 65466
```

This is fine for positions and velocities since the Vectrex coordinate system is signed 8-bit.

### Parameter limit

Functions accept up to 4 parameters. Additional parameters are ignored.

### No recursion safety

The compiler does not prevent recursion, but there is no stack overflow detection. Deep recursion will corrupt RAM.

### Comments

```python
# This is a comment
x = 42  # inline comment
```

Block comments (`"""..."""`) are not supported.

### Indentation

Exactly 4 spaces per block level. Tabs are not allowed.

### Parser error reporting

The parser currently reports only the first error per file. Fix errors one at a time.

---

## 12. Known Limitations

### Features NOT YET IMPLEMENTED

These features are recognized by the parser but do not generate working code:

- **Structs**: Parser accepts `struct` definitions, but codegen does not emit field access (`obj.field`). Use parallel arrays instead.
- **Enums**: Not supported. Use named constants instead.
- **`len()`**: Always returns 0. Track array lengths in separate variables.
- **Recursive functions**: Allowed but unsafe. No stack overflow protection.

### Removed Built-ins

The following built-ins were documented in previous versions but are no longer supported:

- **`DRAW_TO(x, y)`**: Removed. Use `MOVE(x, y)` followed by `DRAW_LINE(current_x, current_y, x, y, intensity)` instead.
- **`SET_SCALE(val)`**: Not implemented.
- **`GET_TIME()`**: Placeholder only; unreliable.
