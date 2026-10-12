# VPy Language Manual

VPy is a Python-inspired language for the Vectrex console. The buildtools compiler (`vpy_cli`) compiles it to MC6809 assembly for a cartridge ROM (`--target m6809`, the default) and to ARM code for the RP2350 cartridge, the UVM2 multicart and the PiTrex. It supports the integer types u8, i8, u16, i16 (plus u32 and i32 on the ARM targets) and is designed for game development on constrained hardware. Builtins that exist on only some targets are marked in [section 9](#9-built-in-functions).

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

A plain assignment inside a function creates a local variable. There are no `let`, `var` or `global` keywords, and locals cannot carry a type annotation (`x: u8 = 1` inside a function is a parse error):

```python
def update_player():
    dx = joy_x * 2      # local
    player_x = player_x + dx   # player_x is global
```

The compiler determines scope automatically: if the name was declared at the top level, assignment inside a function modifies the global. Otherwise it's local.

On m6809 each function has its own locals: `t` in `update_player()` and `t` in `draw_hud()` are two different variables, and a local of `main()` is not visible in `loop()`. To share a value between functions (or keep it from one frame to the next), declare it at the top level. Reading a name that is not a parameter, not assigned in the function and not declared at the top level is a compile error on m6809.

### Constants

`const` declares a compile-time constant. Constants cannot be reassigned:

```python
const MAX_ENEMIES = 8
const GRAVITY = 1
const GROUND_Y = -70
const HALF_W = WIDTH // 2      # consts of consts, in any order
const WIDTH = 120
const FLAG = 8
const MASK = ~FLAG & 0xFF      # 0xF7
```

A scalar constant's value is computed at compile time: it can be a number, another
constant, or arithmetic (`+ - * / // %`) and bit operations (`& | ^ ~ << >>`, `not`,
comparisons) on those. Division truncates toward zero, as at run time. On m6809 a constant has no RAM;
every use is an immediate value, so a value that cannot be computed at compile time
(a variable, a call, a string) or that does not fit in 16 bits is a compile error with
its line.

### Enums

`enum` declares a group of constants numbered 0, 1, 2… as in C. `NAME = n` sets a value
and the members after it count on from it. Members are global constants (the enum's
name only labels the group); one per line, or several on a line separated by commas:

```python
enum State:
    ST_TITLE                # 0
    ST_PLAY, ST_PAUSE       # 1, 2
    ST_OVER = 10
    ST_WON                  # 11
```

### Compound assignment

```python
x += 1
x -= 5
x *= 2
counter += 1
flags |= 4
flags &= 251
bits ^= 1
v <<= 2
v >>= 1
```

`+= -= *= /= //= %= &= |= ^= <<= >>=` all work on variables and on array elements.

---

## 3. Types and Values

VPy supports four integer types on every target, plus two 32-bit types on the ARM targets (rp2350, uvm2, pitrex). Untyped variables default to `i16`.

### Integer Types

Use Python type-hint syntax to declare the type of a global (module-level) variable. Type annotations are only accepted at module level; locals are always untyped:

```python
x: u8 = 10           # 8-bit unsigned: 0–255
y: i8 = -5           # 8-bit signed: -128 to +127
score: u16 = 1000    # 16-bit unsigned: 0–65535
pos: i16 = -100      # 16-bit signed: -32768 to +32767
x = 0                # no annotation → defaults to i16
```

| Type | Size | Signed | Range |
|------|------|--------|-------|
| `u8` | 1 byte | No | 0–255 |
| `i8` | 1 byte | Yes | -128 to +127 |
| `u16` | 2 bytes | No | 0–65535 |
| `i16` | 2 bytes | Yes | -32768 to +32767 |
| `u32` | 4 bytes | No | 0–4294967295 (ARM targets only) |
| `i32` | 4 bytes | Yes | -2147483648 to +2147483647 (ARM targets only) |

`u32`/`i32` on m6809 are a compile error with the line. On the ARM targets every scalar
variable (global, local or parameter) is a 32-bit word whatever its annotation, and
arithmetic is 32-bit; the annotation matters for arrays, whose elements have the declared
size.

- Truthiness: `0` is false, any other value is true.
- No floating point. No booleans — use `1` and `0` instead.

**Memory:** `u8`/`i8` occupy 1 byte of RAM; `u16`/`i16` occupy 2 bytes. Using smaller types saves RAM — roughly 1 byte per 8-bit variable.

**Backward compatibility:** All code without type annotations continues to work unchanged (`i16` default).

**Known limitation:** Const arrays with `u8` type annotation may cause runtime issues in complex games. Use untyped const arrays as a workaround (they default to `i16`).


**Example: typed game state**

```python
health: u8 = 100        # 0–255 is sufficient for health
direction: i8 = 1       # -1, 0, or +1
score: u16 = 0          # 0–65535 for high scores
x: i16 = 0              # full range for screen coordinates
```

### Arrays with types

Array elements use the declared element type:

```python
enemy_hp: u8 = [100, 90, 80]   # 3 bytes in RAM
offsets: i8 = [-1, 0, 1]       # 3 bytes in RAM
coords = [0, 100, 200]         # untyped → i16, 6 bytes in RAM
world_z: i32 = [40000, -90000] # ARM targets only, 8 bytes in RAM
```

Stride for element access is 1 byte for `u8`/`i8`, 2 bytes for `u16`/`i16`, 4 bytes for
`u32`/`i32`, for indexing and for `for v in arr` alike, on every target. Unsigned
elements are zero-extended and signed elements sign-extended when read.

A value must fit its element: an array literal element, or a constant stored into a global
array (`xs[i] = 100000`), that does not fit 8 bits (u8/i8), 16 bits (untyped/u16/i16) or
32 bits is a compile error with the line. Values computed at run time are truncated to the
element size, as in C.

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
| `>>` | Shift right, arithmetic (keeps the sign: `-100 >> 2` is `-25`) |

They bind as in Python: `x & 3 == 0` is `(x & 3) == 0`, `1 + b << 3` is `(1 + b) << 3`.

### Comparison

`==`, `!=`, `<`, `<=`, `>`, `>=`

Chained comparisons are supported: `0 < x < 100` expands to `(0 < x) and (x < 100)`.

### Logical

`and`, `or`, `not` — short-circuit evaluation.

### Operator precedence (high to low)

1. Unary: `- not ~`
2. `* / // %`
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

- Calling a function with a different number of arguments than it declares is a compile error on m6809.
- An array argument is passed as its base address; the function indexes it like an
  array (`arr[i]`, `arr[i] = v`). See [Arrays as parameters](#arrays-as-parameters).
- A parameter hides a global or `const` with the same name inside its function. Names
  are case-insensitive, so a parameter `b` also hides `const B`.
- Return value is stored in the D register (16-bit).
- Functions can call other functions freely. On m6809 they cannot call themselves: recursion (direct, or through other functions) is a compile error that names the cycle; write it as a loop. The ARM targets (rp2350, uvm2, pitrex) give every call its own stack frame, so recursion works there.
- On m6809 a function's parameters and locals live at fixed RAM addresses (its *frame*), not on the stack: the caller stores the arguments straight into the callee's parameter slots, so a parameter keeps its value across the calls the function makes. Functions that can never run at the same time share the same bytes (frames are overlaid by call graph), so locals do not keep their value from one call to the next.
- Calling a name that is not a builtin, a BIOS routine (m6809) or a function of the program is a compile error with its line.

### Modules (multiple files)

Every `.vpy` under the project's `[sources]` is a module named after its file (`src/physics.vpy` → `physics`). Import a module to use its functions, variables, constants and arrays:

```python
import physics                    # physics.clamp_x(v), physics.speed, physics.table[i]
import physics as ph              # ph.clamp_x(v)
from physics import clamp_x       # clamp_x(v)
from physics import speed as spd  # spd

def loop():
    px = physics.clamp_x(px)
    physics.speed = 2
```

- Inside `physics.vpy`, its own functions and globals are used by their plain names.
- Struct types, enum members and arrays (of any dimension) are module symbols too:
  `enemies = types.Tie[8]`, `from types import Tie, S_PLAY`, `types.GRID[r][c]`,
  `types.ties[i].hp -= 1`. On the ARM targets a function of another module can be passed
  as a value: `each(physics.step)`.
- A compile error names the file it is in (`src/space.vpy:18: error: …`), whichever module
  the code comes from, and the names as written in it (`ties.hp`, not the generated global).
- Names are case-insensitive: `physics.CLAMP_X()` and `physics.clamp_x()` are the same function.
- Modules may import each other, as in Python: `common` can call `sound.play()` while `sound` reads `common.state`. Every name resolves against every module, so nothing depends on which one comes first.
- In the generated code a module's symbols are named `MODULE_symbol` (`PHYSICS_clamp_x`; m6809 labels are upper-case: `PHYSICS_CLAMP_X`). Two modules whose names collide that way are a compile error.
- Build the project (`.vpyproj`): every target (m6809, rp2350, uvm2, pitrex) compiles all of its modules. Building a lone `.vpy` compiles only that file, so an `import` there fails with `main.vpy:1: error: module `physics` not found …`.
- `module.name` where the module has no such symbol, or a module used without `import`, is a compile error with the file and line.
- Scopes inside a function: a parameter is local; a name assigned in the function (`x = …`, `x += …`, `for x in …`) is the module's global if the module defines it or imports it with `from m import x` (there is no `global` keyword, assigning writes that global), and a local otherwise. A local or parameter of `enemies.vpy` named like a global of `main.vpy` is its own variable: it never reads or writes main's `x`.
- A module cannot see the main program's globals (or another module's) by their bare name: `return x` in `enemies.vpy`, where only `main.vpy` defines `x`, is `enemies.vpy:N: error: `x` is not defined in module `enemies`…`. Pass the value as a parameter, or put shared state in a module both files import.
- A library of 3D poses and clips is imported like a module: `import fighters`, with no `fighters.vpy`, reads `assets/clips/**/fighters.vclip` (and its skeleton) as constants: `fighters.T_POSES[fighters.POSE_GUARD][fighters.JOINT_TWIST]`. The tables are listed in [ASSETS.md](ASSETS.md#vclip-3d-poses-and-clips). A `.vpy` module of the same name wins.

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

### Repetition and several dimensions

A list can be repeated (`[0] * 12`, `[1, 2] * 3`), and lists can nest: an array of N
dimensions must be rectangular and is indexed with one index per dimension. It is stored
flat, row after row (`g[r][c]` is element `r * columns + c`), and `len()` gives the first
dimension:

```python
xf: i32 = [0] * 12                  # twelve zeros
grid = [[0] * 8] * 4                # 4 rows of 8
const GAPS = [[1, 2, 3], [4, 5, 6]] # 2 x 3, in ROM

grid[r][c] = 1
n = len(grid)                       # 4
```

Indexing it with fewer indices than it has dimensions, and `for v in` over it, are compile
errors. Passed to a function it is a flat address: index it once there. A list may end with
a comma (`[1, 2, 3,]`), as in Python: handy in a table written one row per line.

### Access and assignment

```python
x = enemy_x[i]          # read by index
enemy_x[i] = new_x      # write by index
count = len(enemy_x)    # array length, a compile-time constant
```

`len(name)` works on a global or const array, on every target. Any other argument (a
parameter, a scalar, an expression, a string) is a compile error with its line.

### for-in over arrays

```python
for state in enemy_active:
    if state == 1:
        active_count += 1
```

`for v in name` needs a global or const array (its length is known at compile time).
Each element is read with the array's element type. On m6809, iterating a parameter or
a non-array is a compile error; loop over `range(0, n)` and index instead.

### Arrays as parameters

```python
speeds: u8 = [1, 2, 4]

def fastest(arr, n):
    best = 0
    for i in range(0, n):
        if arr[i] > best:
            best = arr[i]
    return best

def loop():
    top = fastest(speeds, len(speeds))
```

Passing an array passes its base address; inside the function the parameter is
indexed through that address. Parameters carry no type, so on every target the element
size of an indexed parameter comes from the arrays passed at its call sites (also through
other functions that forward the parameter):

- Every call passes a `u8` array → the parameter is indexed as `u8`; likewise `i8`,
  untyped/`i16`/`u16` (2-byte elements) or `i32`/`u32` (4-byte elements, ARM targets).
- Calls pass arrays with different element types (`u8` in one call, untyped in another)
  → compile error naming both arrays and their lines. Use one element type, or two functions.
- No call passes a named array (e.g. only computed addresses) → 2-byte elements.

`len()` and `for v in` don't work on a parameter (the length is unknown): pass the length too.

### Structs

A `struct` groups fields; each field has a type (default `i16`) and a default value
(default 0). A struct variable is a global: one (`Name()`, with optional values for the
fields in order) or an array of them (`Name[count]`):

```python
struct Tie:
    x: i32
    z: i32 = 4000
    hp: u8 = 3

ties = Tie[8]               # eight TIEs
boss = Tie(0, 9000, 20)     # one, x = 0, z = 9000, hp = 20

def hit(i, damage):         # a function takes the element's index
    ties[i].hp -= damage
    if ties[i].hp == 0:
        boss.z += 100

def loop():
    for i in range(0, len(ties)):
        ties[i].z -= 50
```

Each field is stored as its own global (an array for an array of structs: `ties[i].hp`
is element `i` of the field array `hp`), so fields keep their own size and every target
compiles them. A struct is not a value: passing, assigning, comparing or iterating a whole
struct, methods, and struct variables inside a function are compile errors with the line.
Pass an element's index instead.

### Function references (ARM targets)

On rp2350, uvm2 and pitrex a function's name can be stored like a number, and calling a
variable calls the function it holds:

```python
def draw_tie(i):
    ...
def draw_bolt(i):
    ...

def draw_all(draw, n):      # `draw` is a function
    for i in range(0, n):
        draw(i)

def loop():
    draw_all(draw_tie, 8)
    draw_all(draw_bolt, 4)
```

Nothing checks the number of arguments of a call through a variable. On m6809 both are a
compile error (its frames need the callee at compile time); pick the function with `if` or
`switch` there. Function names in array literals (dispatch tables) are not supported yet.

### Notes

- Array size is fixed at compile time.
- A table of strings (`const NAMES = ["HOTH", "ENDOR"]`, also nested) holds their
  addresses; `NAMES[i]` can be passed wherever a string goes. On the ARM targets it must be
  `const`.
- Array literals hold numbers or only strings. A number can be a constant expression: literals, `const`s and enum members, and arithmetic over them (`[SX_LASER, MAX_X * 2, -3]`), laid out as its value. Anything else (a variable, a call) is a compile error.
- Index must be within bounds — no runtime bounds checking.
- Coordinates are clamped to 8-bit signed (-128..127) for drawing.

---

## 8. META Directives

META directives go at the top of the entry file and customize the ROM header:

```python
META TITLE = "PANG"
META COPYRIGHT = "g GCE 2025"
META MUSIC = music1
```

| Directive | Description |
|-----------|-------------|
| `META TITLE` | Game title (max 24 chars, auto-uppercased) |
| `META COPYRIGHT` | Copyright string (default: `g GCE 1998`) |
| `META MUSIC` | BIOS music symbol to play at startup (required to avoid audio glitches) |

> **Important:** Always set `META MUSIC` to a valid music symbol (e.g., `music1`). Omitting it or using invalid values causes audio artifacts during gameplay.

---

## 9. Built-in Functions

VPy is case-insensitive, so `DRAW_LINE`, `draw_line`, and `Draw_Line` are all the same.

Unless a row says otherwise, a builtin works on both backends: **m6809** (cartridge ROM) and **ARM** (`rp2350`, `uvm2`). A builtin marked "m6809 only" fails to link on ARM ("undefined reference"); one marked "ARM only" fails to assemble on m6809 ("Undefined symbol"). The PiTrex target has its own backend and is not covered by these marks.

Builtins that take an asset name (`DRAW_VECTOR`, `PLAY_MUSIC`, `PLAY_SFX`, `DRAW_ANIM`, `LOAD_LEVEL`, `SPAWN_ENEMIES`, `PLAY_NOTE`, `DRAW_RECORDING`, `PLAY_SAMPLE`) are covered, with every asset format and folder, in [ASSETS.md](ASSETS.md).

The tables of this section are the doc lines of `vpy_cli builtins` (and so of the IDE's `api_reference` and the `api` block of `ide_get_context`). That command finds the builtins by compiling a call to each candidate for every target, so its target lists are measured; a builtin with no row here fails `cargo test -p vpy_cli`. Write a row as `` | `NAME(args)` | description | `` (the first sentence is the short purpose).

### Frame control

| Function | Description |
|----------|-------------|
| `SET_INTENSITY(val)` | Set beam intensity (0–127) |
| `GET_FRAME_US()` | Microseconds since the last frame sync (ARM). Always 0 on m6809 |

> **Note:** `WAIT_RECAL` is **automatically injected** by the compiler at the start of every `loop()` call. Do not call it yourself.

### Drawing

| Function | Description |
|----------|-------------|
| `MOVE(x, y)` | Move the beam to (x, y) without drawing. Constant or variable arguments |
| `DRAW_LINE(x0, y0, x1, y1, intensity)` | Draw a line segment |
| `DRAW_CIRCLE(cx, cy, radius, intensity)` | Circle as a 16-segment polygon |
| `DRAW_CIRCLE_SEG(segs, cx, cy, radius, intensity)` | Circle with a custom segment count (3–64). m6809 only, constant arguments only |
| `DRAW_POLYGON(n, intensity, x0, y0, ..., xn-1, yn-1)` | Closed polygon with `n` (≥ 3) vertices. m6809 also accepts the form without `intensity` |
| `DRAW_RECT(x, y, w, h, intensity)` | Rectangle outline |
| `DRAW_FILLED_RECT(x, y, w, h, intensity)` | Filled rectangle (scanlines) |
| `DRAW_ARC(segs, cx, cy, r, start_deg, sweep_deg, intensity)` | Open arc |
| `DRAW_ELLIPSE(cx, cy, rx, ry, intensity)` | Ellipse |
| `DRAW_BEZIER(x0, y0, cp1x, cp1y, cp2x, cp2y, x1, y1, steps, intensity)` | Cubic Bézier as `steps` line segments |
| `DRAW_BEZIER_QUAD(x0, y0, cpx, cpy, x1, y1, steps, intensity)` | Quadratic Bézier as `steps` line segments |
| `DRAW_VECTOR("name", x, y[, mirror])` | Draw a `.vec` asset at (x, y) |
| `DRAW_VECTOR_EX("name", x, y, mirror, intensity)` | Draw a `.vec` asset with mirror and intensity override |
| `DRAW_VECTOR_3D("name", ax, ay, az, x, y)` | Draw a 3D `.vec` asset rotated by (ax, ay, az) |
| `DRAW_VECTOR_ROT("name", x, y, angle[, mirror[, intensity]])` | Draw a `.vec` asset turned by `angle` about its origin (0–127 = one full turn, counter-clockwise, the unit of `sin`/`cos`); `mirror` flips it before turning, `intensity` > 0 overrides every path |

**Parameters:**
- `mirror`: `0`=none, `1`=flip X, `2`=flip Y, `3`=flip both
- Coordinates are 8-bit signed (-128..127)
- Intensity values: 0 (off) to 127 (maximum brightness). m6809 lets you omit the trailing `intensity` of the circle, rectangle, arc and ellipse builtins (default `0x5F`); ARM does not, so always pass it

**`DRAW_VECTOR_ROT`:** `angle` is any expression, taken modulo 128 (32 = 90°, 64 = 180°). The sprite turns about the centre of the `.vec`'s bounding box, the point `DRAW_VECTOR` puts at (x, y), and uses the sprite's ordinary path data (no extra ROM per asset). The name must be a string literal naming a `.vec` of the project, and the call takes 4 to 6 arguments; anything else is a compile error with its line, on every target. Per target:
- m6809: sin/cos are looked up once per call, then each point costs four 8×8 multiplies. Points land on whole units (a point more than 64 units from the centre can be one unit short at angle 0, from the 127/128 scale of the sine table). A sprite source segment longer than 64 units is drawn in two halves. It is not clipped at the screen edge (as single-bank `DRAW_VECTOR`), and without an `intensity` argument each path keeps its own (`SET_INTENSITY` does not override it, as with `DRAW_VECTOR`).
- rp2350 / uvm2: points are placed in 1/16 units. A `SET_INTENSITY` override of the frame applies when there is no `intensity` argument, as with `DRAW_VECTOR`.
- pitrex: calls libvpy's `vpy_draw_vector_rot_ex`, which needs an SDK newer than v1.3.2 (the build says so otherwise).

**m6809 limitation:** `DRAW_LINE`, `DRAW_CIRCLE` and `DRAW_RECT` accept variables. `DRAW_POLYGON`, `DRAW_CIRCLE_SEG`, `DRAW_ARC`, `DRAW_FILLED_RECT`, `DRAW_ELLIPSE`, `DRAW_BEZIER` and `DRAW_BEZIER_QUAD` are expanded at compile time and need **constant** arguments; with variables they compile but draw nothing. The ARM backend accepts variables for all of them.

### Animation and recordings

| Function | Description |
|----------|-------------|
| `DRAW_ANIM("name", x, y[, mirror[, scale[, speed]]])` | Draw the current frame of a `.vanim` and advance it; call it every frame. `scale` `$7F` = normal size |
| `DRAW_RECORDING("name", x, y, scale, frame)` | Draw frame `frame` (wrapped) of a `.vrec` recording; `scale` 128 = 100% |

### Text & Debug

| Function | Description |
|----------|-------------|
| `PRINT_TEXT(x, y, "text")` | Print a string at screen position |
| `PRINT_TEXT(x, y, var)` | Print a string variable |
| `PRINT_TEXT(x, y, "text", height, width)` | Print with an explicit text size (m6809) |
| `PRINT_NUMBER(x, y, number)` | Print a decimal number. m6809: 0–9999. ARM: -9999..9999, no leading zeros |
| `SET_TEXT_SIZE(n)` | Text size for later `PRINT_TEXT` calls (ARM only; on m6809 it currently fails to assemble) |
| `MSG_DEF(id, x, y, "text")` | Declare message `id` in a ROM table (emits no code) |
| `PRINT_MSG(id)` | Print the message declared with `MSG_DEF` for `id` (runtime lookup). On m6809 the program must also call `PRINT_TEXT` somewhere, or the text helper is not linked |
| `DEBUG_PRINT(value)` | Debug output to console (editor only) |
| `DEBUG_PRINT_LABELED("label", value)` | Debug output with label |
| `DEBUG_PRINT_STR("text")` | Debug string output |

### Input — Joystick 1

| Function | Description |
|----------|-------------|
| `J1_X()` | Analog X position, signed (about -127..127, 0 at centre) |
| `J1_Y()` | Analog Y position, signed (about -127..127, 0 at centre) |
| `J1_BUTTON_1()` | 1 while button 1 is held, 0 otherwise (level, not edge) |
| `J1_BUTTON_2()` | Same for button 2 |
| `J1_BUTTON_3()` | Same for button 3 |
| `J1_BUTTON_4()` | Same for button 4 |
| `J1_BTN1()` … `J1_BTN4()` | Short names of `J1_BUTTON_1()` … `J1_BUTTON_4()` (ARM targets) |

The analog axes and the buttons are read once per frame by code the compiler injects at the start of `loop()` (on m6809, BIOS `Read_Btns` every frame and `Joy_Analog` only when the program uses an axis). The builtins return the cached values, so calling them several times per frame is cheap. To act once per press, compare with the previous frame's value yourself.

### Input — Joystick 2

| Function | Description |
|----------|-------------|
| `J2_X()` | Analog X position, signed (same as `J1_X`) |
| `J2_Y()` | Analog Y position, signed |
| `J2_BUTTON_1()` … `J2_BUTTON_4()` | 1 while the button is held |
| `J2_BTN1()` … `J2_BTN4()` | Short names of `J2_BUTTON_1()` … `J2_BUTTON_4()` (ARM targets) |
| `J2_ANALOG_X()` / `J2_ANALOG_Y()` | Raw unsigned axis byte (0–255). m6809 only |
| `J2_BUTTON_UP()` / `J2_BUTTON_DOWN()` / `J2_BUTTON_LEFT()` / `J2_BUTTON_RIGHT()` | 1 while the stick is pushed past the threshold in that direction. m6809 only |

`J2_DIGITAL_X()` / `J2_DIGITAL_Y()` do not work yet (see [Recognised but not working](#recognised-but-not-working)).

### Input — Button Updates

| Function | Description |
|----------|-------------|
| `UPDATE_BUTTONS()` | Re-read the buttons now. Not needed normally — the compiler already reads them at the start of every frame |

### Audio

| Function | Description |
|----------|-------------|
| `PLAY_MUSIC("name")` | Play a `.vmus` music file |
| `STOP_MUSIC()` | Stop current music. On m6809 the program must also use `PLAY_MUSIC` (the runtime is only linked then) |
| `PLAY_SFX("name")` | Play a `.vsfx` sound effect |
| `PLAY_NOTE("instrument", channel, midi_note)` | Play a note on a `.vinstr` instrument |
| `PLAY_SAMPLE("name")` / `SAMPLE_POS(fps)` | Play a `.vsmp` sample / audio-synced frame index. rp2350 and pitrex; on uvm2 they build but do nothing; on m6809 a compile error ("not supported on m6809") |

The music/SFX engine is updated automatically every frame when the program uses `PLAY_MUSIC` or `PLAY_SFX`; there is nothing to call. (On m6809 the injected routine is `AUDIO_UPDATE`; calling it yourself is harmless but redundant. There is no user-callable `MUSIC_UPDATE`.) Formats and folders are in [ASSETS.md](ASSETS.md).

### Jukebox (uvm2)

Recorded music and effects off the SD card, out of the UVMC2's audio jack — the same player the C games use, compiled into the image when a program calls any of these. A track is `<dir>/<ID>.PCM` on the card (4-bit IMA ADPCM, `RJMU` header); the effects are one pack, `<dir>/SFX.PCM` (`RJSX`: numbered groups of clips, one of a group at random), loaded whole into the cartridge's PSRAM. The track playing is streamed into PSRAM a slice a frame while it plays, and a new one cross-fades in. Five voices mix over the music: 0 an engine or hum, 1 yours, 2 the world, 3 voices (they duck the music), 4 things passing. The compiler calls the jukebox at the start of every frame; there is nothing to update. Where there is no jack, no PSRAM or no file, every call is silent: `SFX_PCM` returns 0, so the program can fall back to `PLAY_SFX`.

| Function | Description |
|----------|-------------|
| `JUKEBOX_DIR("dir")` | The card folder the tracks and `SFX.PCM` are in (e.g. `"ROTJ"`); call it in `main()` |
| `JUKEBOX_MODE(m)` | How much of each frame the card may take: 0 a screen (~6 ms, the default), 1 play (~2 ms), 2 a loading screen (~15 ms) |
| `JUKEBOX_PROGRESS()` | 0..256: the effects pack, then the first track's head, loaded; 256 = ready (a loading bar) |
| `JUKEBOX_LIVE()` | 1 while a track is playing or loading out of the jack |
| `JUKEBOX_REPORT()` | One line of what the audio path is doing (jack, PSRAM, card, slots), as a string for the text builtins |
| `MUSIC_TRACK("ID")` | Play `<dir>/ID.PCM`, cross-fading from the one playing; the same track carries on, so it is safe every frame. `""` fades to silence |
| `SFX_PCM(group, voice[, gain, loop])` | A clip of `group` on `voice` (it cuts what that voice played); gain 256 = full (0 = full), loop 1 for a hum. Returns 1 if it plays |
| `SFX_PCM_AT(group, voice, gain, loop, x, y, z)` | The same, heard from a place in the world: quieter far off, in the ear on its side |
| `SFX_PCM_MOVE(voice, x, y, z)` | Move a voice that is playing (a ship going by) |
| `SFX_PCM_STOP(voice)` / `SFX_PCM_BUSY(voice)` | Stop a voice / 1 while it plays |
| `LISTENER(x, y, z, fx, fz)` | Where the listener is (usually the camera) and its heading on the floor, for the placed sounds |

### Level System

| Function | Description |
|----------|-------------|
| `LOAD_LEVEL("name")` | Load a `.vplay` level file into memory |
| `SHOW_LEVEL()` | Render the currently loaded level at the current camera position |
| `UPDATE_LEVEL()` | Update level state |
| `SET_CAMERA_X(x)` | Set the horizontal scroll offset (16-bit signed) |
| `SET_CAMERA_Y(y)` | Set the vertical scroll offset (16-bit signed) |
| `GET_CAMERA_X()` / `GET_CAMERA_Y()` | Read the scroll offset back. ARM only |
| `GET_SCROLL_LIMIT_LEFT()` / `_RIGHT()` / `_TOP()` / `_BOTTOM()` | Scroll limits of the loaded level |
| `GET_LEVEL_FLOOR_Y()` | Floor surface Y of the loaded level |
| `LEVEL_COLLISION_Y(x, y, half_height)` | Resolve vertical collision against the level; returns the corrected Y |
| `LEVEL_COLLISION_X(x, y, half_width, half_height)` | Resolve horizontal collision; returns the push-out dx |
| `GET_LEVEL_WIDTH()` | Width of the current level. m6809 only |
| `GET_LEVEL_HEIGHT()` | Height of the current level. m6809 only |
| `GET_LEVEL_TILE(x, y)` | Tile value at (x, y). m6809 only |

On m6809 the level builtins (other than `LOAD_LEVEL`) only assemble in a program that also calls `LOAD_LEVEL`, because the level runtime and its RAM are only linked then. Enemy builtins are listed under [Enemies](#enemies); the `.venemy` format is in [ASSETS.md](ASSETS.md).

#### Scrolling

Levels can extend beyond the Vectrex screen (–128 to +127 on each axis). `SET_CAMERA_X` and `SET_CAMERA_Y` shift the viewport so the game can scroll through worlds larger than the screen.

```python
camera_x: i16 = 0
camera_y: i16 = 0

def loop():
    joy_x = J1_X()
    joy_y = J1_Y()
    if joy_x > 20:
        camera_x = camera_x + 2
    if joy_x < -20:
        camera_x = camera_x - 2
    if joy_y > 20:
        camera_y = camera_y + 2
    if joy_y < -20:
        camera_y = camera_y - 2

    # Clamp to world bounds (defined in the .vplay file)
    camera_x = clamp(camera_x, 0, 800)
    camera_y = clamp(camera_y, -200, 0)

    SET_CAMERA_X(camera_x)
    SET_CAMERA_Y(camera_y)
    SHOW_LEVEL()
```

- Objects are positioned in **world coordinates** in the `.vplay` file.
- `SHOW_LEVEL()` subtracts `CAMERA_X`/`CAMERA_Y` from each object's world position to compute screen coordinates.
- Objects outside the visible range are automatically culled (not drawn).
- `LOAD_LEVEL()` resets both `CAMERA_X` and `CAMERA_Y` to 0.

#### .vplay file format

Level files are JSON (version 2.0). They are created and edited in the Playground tab of the IDE.

```json
{
  "version": "2.0",
  "type": "level",
  "metadata": { "name": "entrance", ... },
  "worldBounds": {
    "xMin": -96,
    "xMax": 863,
    "yMin": -128,
    "yMax": 127
  },
  "layers": {
    "background": [ ... ],
    "gameplay": [ ... ],
    "foreground": [ ... ]
  }
}
```

Each object in a layer:

```json
{
  "id": "obj_unique_id",
  "type": "enemy",
  "vectorName": "lamp",
  "layer": "gameplay",
  "x": 458,
  "y": -2,
  "rotation": 0,
  "scale": 1
}
```

| Field | Description |
|-------|-------------|
| `vectorName` | Name of the `.vec` asset to draw (without extension) |
| `x`, `y` | World-space position |
| `layer` | `"background"`, `"gameplay"`, or `"foreground"` |
| `rotation` | Rotation in degrees (stored but not yet applied at runtime) |
| `scale` | Scale factor (stored but not yet applied at runtime) |

`worldBounds` documents the intended world extents for the game logic (e.g. for clamping `CAMERA_X`); they are not enforced by the runtime.

### Enemies

Enemies are `.venemy` types placed by a `.vplay` level. `i` is the slot in the enemy pool (0 .. count-1).

| Function | Description |
|----------|-------------|
| `SPAWN_ENEMIES("level")` | Spawn the enemies the level places (after `LOAD_LEVEL`) |
| `UPDATE_ENEMIES()` | Move every live enemy (behaviour, state machine); call once per frame |
| `DRAW_ENEMIES()` | Draw every live enemy; call once per frame |
| `GET_ENEMY_ACTIVE(i)` | 1 if slot `i` holds a live enemy, else 0 |
| `GET_ENEMY_X(i)` / `GET_ENEMY_Y(i)` | Position of enemy `i` |
| `SET_ENEMY_X(i, x)` / `SET_ENEMY_Y(i, y)` | Move enemy `i` |
| `GET_ENEMY_HP(i)` | Hit points of enemy `i` |
| `GET_ENEMY_STATE(i)` / `SET_ENEMY_STATE(i, state)` | State-machine state of enemy `i` (255 = no state machine) |
| `SET_ENEMY_DIR(i, dir)` | Facing of enemy `i`: 0 left, 1 right |
| `KILL_ENEMY(i)` | Remove enemy `i`; returns the number of enemies left |
| `ENEMY_FIRE_EVENT(i, "event")` | Fire a state-machine event on enemy `i` |
| `GET_ENEMY_AREA_IDX(i)` | Walkable area enemy `i` stands on (255 if inactive); for debugging |

### Math

#### Basic Functions

| Function | Description |
|----------|-------------|
| `abs(x)` | Absolute value |
| `min(a, b)` | Minimum of two values |
| `max(a, b)` | Maximum of two values |
| `clamp(v, lo, hi)` | Clamp value between lo and hi |
| `MUL_SHR(a, b, shift)` | `(a * b) >> shift` with a 64-bit product, for fixed-point maths whose product does not fit 32 bits (`MUL_SHR(x, SIN_Q14(a), 14)`). ARM targets only |

#### Trigonometry

| Function | Description |
|----------|-------------|
| `sin(a)` | Sine — argument 0..127 covers full circle, result -127..127 |
| `cos(a)` | Cosine — same range as sin |
| `tan(a)` | Tangent — argument 0..127, result varies. m6809 only |
| `atan2(y, x)` | Two-argument arctangent (returns angle 0..127). m6809 only, constant arguments only (folded at compile time); variable arguments are a compile error |

#### Power & Roots

| Function | Description |
|----------|-------------|
| `sqrt(x)` | Integer square root |
| `pow(x, y)` | Integer power: x raised to the y-th power. m6809 only |

#### Random Numbers

| Function | Description |
|----------|-------------|
| `rand()` | Return random value 0..65535 |
| `rand_range(min, max)` | Return random value in range [min, max) |

**Note:** All trigonometric functions use 128-entry lookup tables for performance. Angles wrap at 128 (360 degrees).

### Utilities

| Function | Description |
|----------|-------------|
| `wait(frames)` | Busy-wait N frames (nothing else runs meanwhile). m6809: `frames` must be a constant (a number, a const or a constant expression, up to 65535) |
| `beep(period, frames)` | Non-blocking PSG tone: `period` is the PSG tone period (higher = lower pitch), `frames` the duration. m6809 also accepts `beep()` (period 50, 8 frames); on ARM pass both arguments |
| `len(array)` | Number of elements of a global array (a compile-time constant) |
| `peek(addr)` | Read one byte from a Vectrex address. m6809: constant `addr` only |
| `poke(addr, value)` | Write one byte to a Vectrex address. m6809: constant `addr` and `value` only |
| `DEBUG_PRINT…` | See [Text & Debug](#text--debug) |

On m6809, `wait`, `peek`, `poke` and `beep(period, frames)` with non-constant arguments are a compile error.

### 3D (uvm2)

Meshes (`.vmesh`, anywhere under `assets/meshes/`) and scenes (`.vscene`, in
`assets/scenes/`) drawn in perspective with hidden-line removal, occluders and fog. These
builtins call the SDK's vpy3d — the same 3D layer C games use — which vpy_cli compiles
into the `.um2` when the program uses any of them. On m6809, rp2350 and pitrex they are a
compile error. See [ASSETS.md](ASSETS.md) for the `.vmesh` / `.vscene` formats.

**Transforms** are global `i32` arrays of 12 elements (a Q14 rotation, 16384 = 1.0, then a
translation); declare one per placement you need:

```python
pose: i32 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
spin: i32 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

def main():
    LOAD_MESH("tie_cockpit")
    CAMERA_LOOK_AT(0, 0, -2000, 0, 0, 0)

def loop():
    XF_ROT_Y(spin, angle)                 # 4096 = one turn
    XF_TRANSLATE(pose, x, y, z)
    XF_MUL(pose, pose, spin)              # spin first, then move
    DRAW_MESH("tie_cockpit", pose, 110)
```

Units: world coordinates are 32-bit integers in the meshes' own unit; angles are 4096 per
turn; brightness 0..127. Screen positions from `PROJECT` are deflection units (VPy units
×127). A mesh must be loaded (`LOAD_MESH`) before it is drawn; meshes and scenes are named by
string literal and must exist (a missing one is a compile error).

| Function | Description |
|----------|-------------|
| `XF_IDENTITY(xf)` | `xf` = no rotation, no move |
| `XF_TRANSLATE(xf, x, y, z)` | `xf` = a move by (x, y, z) |
| `XF_ROT_X(xf, angle)` / `XF_ROT_Y(xf, angle)` / `XF_ROT_Z(xf, angle)` | `xf` = a rotation about one axis (4096 per turn) |
| `XF_MUL(dst, a, b)` | `dst` = `b` then `a` (`dst` may be `a` or `b`) |
| `XF_POINT(out, xf, x, y, z)` | `out[0..2]` = the point (x, y, z) moved by `xf` (`out`: an `i32` array of 3) |
| `XF_TO_MODEL(out, xf, x, y, z)` | The reverse: `out[0..2]` = the world point (x, y, z) in `xf`'s own frame |
| `CAMERA_LOOK_AT(ex, ey, ez, tx, ty, tz[, ux, uy, uz])` | Camera at the eye (ex, ey, ez) looking at (tx, ty, tz); (ux, uy, uz) is the world direction that ends up pointing up on screen (default +y; tilt it to bank, e.g. `SIN_Q14(roll), COS_Q14(roll), 0`). Returns 0 if eye and target coincide |
| `CAMERA_SET(xf)` / `CAMERA_GET(xf)` | Set the world→camera transform / read it into `xf` |
| `CAMERA_FOCAL(f)` | Field of view: deflection units per unit of x over z (default 28000, about 58°; bigger = narrower) |
| `CAMERA_NEAR(z)` | Nothing nearer than `z` is drawn (default 600) |
| `CAMERA_CLIP(half_x[, half_y])` | Half the visible window in deflection units (default 15500 square) |
| `PROJECT(out, x, y, z)` | Where a world point lands on screen: `out[0]`, `out[1]` in deflection units (`out`: an `i32` array of 2). Returns 0 if it is behind the camera |
| `PROJECT_CAM(out, x, y, z)` | The same for a point already in camera space (x right, y up, z ahead) |
| `SCREEN_SIZE(x, y, z, radius)` | How big a ball of `radius` at world (x, y, z) looks, in deflection units |
| `SIN_Q14(angle)` / `COS_Q14(angle)` | Sine and cosine with 4096 per turn, -16384..16384 |
| `ATAN2_Q14(y, x)` | The angle of (x, y) from +x towards +y, 4096 per turn (0..4095) |
| `LOAD_MESH("name")` | Load `name.vmesh` into the mesh pools. Returns 0 if the pools are full (raise `VPY3D_POOL_*` in the project's `[uvm2] defs`) |
| `DRAW_MESH("name", xf, brightness)` | Draw a loaded mesh placed by `xf` |
| `MESH("name")` | The mesh's slot, as a number: every mesh argument also takes a slot, so a function can be handed the mesh to draw (`def figure(p, body): DRAW_MESH(body, p, 100)` … `figure(p, MESH("scout_trooper"))`) |
| `MESH_OCCLUSION(on)` | 1: meshes are cut by the solids drawn before them in the frame (meshes and `OCCL_*`), as lines already are; 0 (the default): meshes are drawn whole |
| `MESH_POOL_MARK()` / `MESH_POOL_RELEASE()` | Remember where the pools are / give back every mesh loaded since (load them again before drawing them) |
| `LOAD_SCENE("name")` | Load `name.vscene` and the meshes it places. Returns 0 on failure |
| `DRAW_SCENE("name", x, y, z, brightness[, groups])` | Draw a scene at position (x, y, z) — what its `follow` items move with; `groups` is the bit mask its `group` items test |
| `DRAW_SCENE_AT("name", xf, x, y, z, brightness[, groups])` | `DRAW_SCENE`, the whole scene placed by the transform `xf` (moved and turned) |
| `LINE_3D(ax, ay, az, bx, by, bz, brightness)` | A line in world space |
| `LINE_CAM(ax, ay, az, bx, by, bz, brightness)` | A line in camera space (x right, y up, z ahead): gunsights and other overlays that turn with the view |
| `OCCL_RESET()` | Forget the occluders (once per frame, before adding the frame's) |
| `OCCL_LINE(ax, ay, az, bx, by, bz, brightness)` | A world line hidden by the occluders added so far |
| `OCCL_MESH("name", xf)` | Add a loaded mesh placed by `xf` as an occluder: it hides what is drawn after it |
| `OCCL_ADD(corners, n)` | Add a convex occluder of `n` (3..8) corners; `corners` is an `i32` array of `n` points (x, y, z) |
| `RAY_MESH(out, "mesh", xf, ox, oy, oz, dx, dy, dz, max_dist)` | The first face of a loaded mesh placed by `xf` that the ray from (ox, oy, oz) along (dx, dy, dz) meets within `max_dist`: its index, or -1. `out` (an `i32` array of 7) gets the hit point, the face's normal (Q14) and the distance |
| `MARKS_CLEAR(k)` / `MARKS_ADD(k, xf, x, y, z, nx, ny, nz)` | Damage marks, set `k` (0..3; raise `VPYX_MARK_SETS` in `[uvm2] defs`): forget them / add a hit at (x, y, z) with face normal (nx, ny, nz) on the object placed by `xf` (what `RAY_MESH` gives). They turn and move with the object |
| `MARKS_DRAW(k, xf, radius, brightness[, style])` | Draw set `k` on the object placed by `xf`: style 0 a scorch ring, 1 a crack; draw right after the object, before adding it as an occluder |
| `FOG(brightness, x, y, z, full_until, gone_at)` | `brightness` faded by the distance of (x, y, z) from the camera: full up to `full_until`, 0 from `gone_at` |
| `SCENERY_FOG(full_until, gone_at)` | The same fade for the lines of `.vmesh` scenery (0, 0 = off) |
| `TEXT_BILLBOARD(text, x, y, z, height, brightness[, flags])` | Text in the world at (x, y, z), facing the camera, `height` world units tall (libvpy's vector font). `text` is a string literal or a variable or parameter holding one. flags: 1 hidden by the occluders, 2 centred, 4 only seen from the front |
| `TEXT_3D(text, xf, height, brightness[, flags])` | Text on the plane placed by `xf` (its x along the text, y up) |
| `LABEL_NUM(text, n)` | `text` followed by `n` in decimal, as a string for the text builtins (`TEXT_BILLBOARD(LABEL_NUM("SCORE ", score), …)`); four can be alive at once |
| `VEC_3D("name", xf, scale, brightness[, flags])` | A `.vec` drawn on the plane placed by `xf`, its units times `scale` |

**Effects** (vpyfx): short-lived pieces that fly, fall, bounce on a floor and fade. Spawn
them, then `FX_STEP()` and `FX_DRAW()` once per frame. Velocities are units per second,
gravity units per second², `life` in frames. Each spawn returns how many pieces it made.

| Function | Description |
|----------|-------------|
| `FX_RESET()` | No pieces, no floor, no gravity |
| `FX_SEED(seed)` / `FX_RATE(steps_per_second)` / `FX_BUDGET(strokes)` | Random seed; simulation rate (default 50); strokes drawn per frame at most (default 160) |
| `FX_GRAVITY(gx, gy, gz)` | Gravity on every piece |
| `FX_FLOOR(on, y, bounce_q8)` | A floor at height `y`; `bounce_q8` 256 = a perfect bounce |
| `FX_SPARK(x, y, z, vx, vy, vz, life, brightness)` | One spark |
| `FX_BURST(x, y, z, vx, vy, vz, count, speed, life, brightness)` | `count` sparks thrown out from a point, moving with (vx, vy, vz) |
| `FX_STICK(ax, ay, az, bx, by, bz, vx, vy, vz, spin, life, brightness)` | A spinning line segment |
| `FX_LINE(ax, ay, az, bx, by, bz, life, brightness)` | A line that stays put and fades |
| `FX_RING(cx, cy, cz, nx, ny, nz, r0, speed, segments, life, brightness)` | A ring around the axis (nx, ny, nz), growing from radius `r0` |
| `FX_SHATTER("mesh", xf, vx, vy, vz, cx, cy, cz, speed, spin, life, brightness)` | A loaded mesh placed by `xf` broken into its edges, flying out from (cx, cy, cz) |
| `FX_DISINTEGRATE("mesh", xf, cx, cy, cz, per_edge, speed, spin, wave, life, brightness)` | A mesh coming apart in a wave from (cx, cy, cz) |
| `FX_ASSEMBLE("mesh", xf, per_edge, scatter, frames, stagger, brightness)` | Pieces flying in to form the mesh; returns a group |
| `FX_ASSEMBLED(group)` / `FX_RELEASE(group)` | Is the group in place / let its pieces go |
| `FX_STEP()` / `FX_DRAW([occlude])` / `FX_DRAW2D()` | Move the pieces / draw them in 3D (1 = hidden by the occluders) / draw 2D pieces |

**Skeletons** (vpybone): bones in a tree, each with an optional mesh, posed by rotations
or by IK. A skeleton is a number, 0 or 1 by default (raise `VPYX_SKELETONS` in the project's
`[uvm2] defs`); bone -1 in `BONE_ROT` / `BONE_ROT_MUL` is the root.

| Function | Description |
|----------|-------------|
| `BONE_INIT(sk)` | Empty skeleton `sk` |
| `BONE_ADD(sk, parent, ox, oy, oz[, "mesh"])` | A bone at offset (ox, oy, oz) from its parent's joint (`parent` -1 = a root), drawn with the mesh; returns its index, -1 if refused |
| `BONE_ROT(sk, bone, ax, ay, az, angle)` | The bone's rotation about the axis (ax, ay, az), 4096 per turn |
| `BONE_ROT_MUL(sk, bone, ax, ay, az, angle)` | Compose a second rotation: rotation = rotation × (axis, angle), as `qmul(rotation, q)` in C |
| `BONE_POSE(sk, x, y, z)` | Place the skeleton's root at (x, y, z) and work out every bone (call after changing rotations) |
| `BONE_IK(sk, upper, tx, ty, tz, px, py, pz)` | Bend the two bones below `upper` so its chain reaches (tx, ty, tz), the knee towards (px, py, pz); 1 if it reached. `BONE_POSE` again afterwards |
| `BONE_XF(xf, sk, bone)` / `BONE_POS(out, sk, bone)` | A bone's transform / its joint in the world (`out`: an `i32` array of 3) |
| `BONE_DRAW(sk, brightness[, what])` | Draw the skeleton: 1 meshes (default), 2 lines, 3 both |

**Soft bodies** (vpysoft): cloth sheets and blobs of points and springs. Each made one is a
body number; `SOFT_STEP()` and `SOFT_DRAW(body, …)` once per frame.

| Function | Description |
|----------|-------------|
| `SOFT_RESET()` | No bodies |
| `SOFT_RATE(n)` / `SOFT_ITERATIONS(n)` / `SOFT_DAMPING(q8)` / `SOFT_BUDGET(strokes)` | Simulation rate, solver iterations (default 8), damping (default 254 of 256), strokes per draw |
| `SOFT_GRAVITY(gx, gy, gz)` / `SOFT_FLOOR(on, y, friction_q8)` | Gravity; a floor at height `y` |
| `SOFT_CLOTH(x, y, z, w, h, cell, stiff_q8)` | A `w` × `h` sheet of points `cell` apart, its top-left corner at (x, y, z); returns the body |
| `SOFT_BLOB(x, y, z, n, radius, stiff_q8, pressure_q8)` | A ring of `n` points that keeps its area |
| `SOFT_MESH("mesh", x, y, z, stiff_q8)` | A loaded mesh made soft |
| `SOFT_PIN(body, i, x, y, z)` / `SOFT_UNPIN(body, i)` | Hold point `i` at (x, y, z) / let it go |
| `SOFT_PUSH(body, vx, vy, vz)` | Add a velocity to every point |
| `SOFT_POINT(out, body, i)` / `SOFT_POINTS(body)` | Where point `i` is (`out`: an `i32` array of 3) / how many points |
| `SOFT_FREE(body)` | Remove the body |
| `SOFT_STEP()` / `SOFT_DRAW(body, brightness[, occlude])` | Move every body / draw one |

The pool sizes of these layers (`VPYFX_MAX`, `VPYSOFT_MAX_POINTS`, `VPYSOFT_MAX_SPRINGS`,
`VPYB_MAX_BONES`, and `VPYX_SKELETONS`: how many skeletons, 2 by default) go in the
project's `[uvm2] defs`. `VPYX_LAYERS_OS` there compiles these layers (effects, skeletons,
cloth) for size instead of speed: a `.um2` runs from SRAM, where code and data share 512 KB,
and a big game may need the room. Not available yet from VPy: terrain and bone animation
clips.

On uvm2 a program's variables live in the 16 KB the runtime reserves at the top of SRAM: the
scalars (and each array's pointer) in the ~2.9 KB after the runtime's own, the arrays' data in
the 12 KB below it. Running out of either is a compile error.

### SD launcher (ARM only)

| Function | Description |
|----------|-------------|
| `SD_FILE_COUNT()` / `SD_FILE_NAME(i)` | Number of games on the SD card / pointer to the name of game `i` (both also build on m6809, with simulated data) |
| `DRAW_SD_PREVIEW(i, x, y, scale)` | Play the `.vrec` preview of game `i` |
| `LAUNCH_GAME(i)` | Load game `i` from the SD card and run it (does not return) |
| `CALIBRATE()` | Show the console calibration screen |

See [RP2350_BIOS.md](RP2350_BIOS.md) for the BIOS calls behind them.

### Injected by the compiler

The compiler emits these itself; a program never needs to call them.

| Function | Description |
|----------|-------------|
| `WAIT_RECAL()` | Frame sync, injected at the start of every `loop()` |
| `AUDIO_UPDATE()` | m6809 music/SFX update, injected every frame when the program plays audio |
| `MUSIC_UPDATE()` / `SFX_UPDATE()` | Music / SFX sequencer step, injected every frame when the program plays audio (m6809: `MUSIC_UPDATE` does not assemble) |

### Recognised but not working

| Function | Description |
|----------|-------------|
| `GET_TIME()` | Placeholder: on m6809 it reads a `FRAME_COUNTER` that is never defined, so it does not assemble |
| `J2_DIGITAL_X()` / `J2_DIGITAL_Y()` | m6809: fail to assemble (missing `J2X_BUILTIN` helper); use `J2_X()` with a threshold |

---

## 10. VectorList DSL

The parser accepts `vectorlist name:` blocks (with `MOVE`, `SET_INTENSITY`, `RECT`, `POLYGON`, `CIRCLE`, `ARC`, `SPIRAL`… commands), but **no backend emits code for them**, and there is no builtin that draws one. Draw static shapes with `.vec` assets and `DRAW_VECTOR` instead (see [ASSETS.md](ASSETS.md)), or with the drawing builtins in [section 9](#drawing).

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

For the same reason a module cannot define one name twice as different things — `struct
Target` and `def target`, a function and a global — and says so at the second definition.
A struct may share its name with a variable (`tie = Tie[4]`), and a global may be declared
again. A function of the program with a builtin's name is used instead of the builtin.

### Variable scope

- Top-level assignments → global (allocated in RAM, persisted across frames)
- Assignments inside a function to a name that is not a global → local of that function (on m6809, a slot in the function's static frame; its value is not kept between calls)
- Parameters hide globals and consts of the same name
- There is no `global` keyword — assigning to a global's name inside a function writes the global

### 16-bit unsigned arithmetic

All values wrap at 65536. Negative numbers are represented as two's complement:

```python
x = -1      # compiled as 0xFFFF = 65535
x = -70     # compiled as 65466
```

This is fine for positions and velocities since the Vectrex coordinate system is signed 8-bit.

### Parameters and recursion (m6809)

Parameters and locals are 16-bit slots in the function's static frame; there is no limit on the number of parameters other than RAM. A call with the wrong number of arguments is a compile error. Recursion is a compile error (a frame holds one activation of its function): use a loop. The build also fails when the program's variables, frames included, do not fit in the 1 KB of RAM, and warns when fewer than 64 bytes are left for the stack.

On the ARM targets (rp2350, uvm2, pitrex) parameters and locals live in a stack frame per call instead: the same name rules and errors apply (a parameter hides a global, wrong argument counts and undeclared names fail with their line), a parameter keeps its value across the calls the function makes, and recursion is allowed (limited only by stack space).

### Comments

```python
# This is a comment
x = 42  # inline comment
```

Block comments (`"""..."""`) are not supported.

### Indentation

Exactly 4 spaces per block level. Tabs are not allowed.

As in Python, a line inside an open `(` or `[` goes on onto the next one, whose
indentation does not count — a long call or array can be split:

```python
FX_SHATTER("tie_wing", wing, vx, vy, vz, x, y, z,
           2200, TURN, 45, 120)
```

### Parser error reporting

The parser currently reports only the first error per file. Fix errors one at a time.

---

## 12. Known Limitations

### Features NOT YET IMPLEMENTED

These features are recognized by the parser but do not generate working code:

- **Struct methods**: a `def` inside a `struct` is a compile error; write functions that take the element's index ([Structs](#structs)).
- **`vectorlist` blocks**: Parsed, never emitted (see [section 10](#10-vectorlist-dsl)).
- **`len()`**: `len(arr)` is the compile-time length of a global or const array. On every target anything else (a parameter, a scalar, an expression, a string) is a compile error with its line.
- **Inline assembly**: `asm("...")` is not implemented on any backend (the build fails with an undefined `ASM` symbol).
- **Recursive functions**: Allowed but unsafe. No stack overflow protection.

### Removed Built-ins

These names are not available; a program that calls them fails to build:

- **`DRAW_TO(x, y)`**: Not implemented. Use `DRAW_LINE(x0, y0, x1, y1, intensity)`.
- **`SET_SCALE(val)`**: Not implemented.
- **`GET_TIME()`**: Not implemented (m6809 references an undefined `FRAME_COUNTER`; ARM has no such builtin). Keep your own frame counter.
- **`fade_in()` / `fade_out()`**: Removed. A vector display has no framebuffer to fade; vary the intensity you pass to the drawing builtins instead.
- **`MUSIC_UPDATE()`**: Not user-callable; the audio update is injected automatically.
