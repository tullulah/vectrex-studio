# VPy Reserved Words and Built-in Names

## VPy is case-insensitive

VPy does not distinguish between uppercase and lowercase. `INTENSITY`, `intensity`, and `Intensity` are all the same identifier. This means that if a name is used as a built-in function, you cannot use that name as a variable.

```python
# BAD
intensity = 50      # conflicts with SET_INTENSITY / INTENSITY built-in
sin = 45            # conflicts with sin() math function
max = 100           # conflicts with max() built-in

# GOOD
brightness = 50
angle = 45
maximum = 100
```

---

## Language keywords

These are reserved by the lexer (case-insensitively) and cannot be used as identifiers:

`def`, `return`, `for`, `in`, `range`, `if`, `elif`, `else`, `while`, `break`, `continue`, `pass`, `and`, `or`, `not`, `true`, `false`, `const`, `switch`, `case`, `default`, `meta`, `vectorlist`, `struct`, `self`, `import`, `from`, `as`, `export`

`let`, `var` and `global` are **not** keywords: VPy declares variables by plain assignment (see [MANUAL.md](MANUAL.md#2-variables-and-constants)).

---

## Built-in names (cannot be used as variable names)

### Frame control
`WAIT_RECAL`, `SET_INTENSITY`, `SET_SCALE`

### Drawing
`MOVE`, `DRAW_TO`, `DRAW_LINE`, `DRAW_CIRCLE`, `DRAW_CIRCLE_SEG`, `DRAW_ARC`, `DRAW_RECT`, `DRAW_FILLED_RECT`, `DRAW_POLYGON`, `DRAW_ELLIPSE`, `DRAW_VECTOR`, `DRAW_VECTOR_EX`

### Text
`PRINT_TEXT`, `PRINT_STR`, `DEBUG_PRINT_STR`, `DEBUG_PRINT`

### Input
`J1_BUTTON_1`, `J1_BUTTON_2`, `J1_BUTTON_3`, `J1_BUTTON_4`, `J2_BUTTON_1`, `J2_BUTTON_2`, `J2_BUTTON_3`, `J2_BUTTON_4`

### Audio
`PLAY_MUSIC`, `PLAY_SFX`, `STOP_MUSIC`

### Level / Assets
`LOAD_LEVEL`

### Math
`abs`, `min`, `max`, `clamp`, `sin`, `cos`, `tan`

### Special functions
`main`, `loop` — reserved as the entry points; avoid using as names for other purposes.

---

## Safe naming conventions

| Purpose | Avoid | Use instead |
|---------|-------|-------------|
| Beam intensity value | `intensity` | `brightness`, `power`, `beam_val` |
| Trig angle | `sin`, `cos`, `tan` | `angle`, `rotation`, `degrees` |
| Max/min value | `max`, `min` | `maximum`, `minimum`, `upper`, `lower` |
| Move delta | `move`, `draw_to` | `delta_x`, `dx`, `offset` |

### General rules

1. Use descriptive prefixes: `player_x`, `enemy_speed`, `game_score`
2. Use clarifying suffixes: `speed_max`, `angle_cos`, `value_abs`
3. When in doubt, compile and check — the LSP will flag name conflicts as diagnostics.

---

## Program entry points

```python
def main():
    # runs once at startup

def loop():
    # runs every frame (~50fps)
```

Both `main` and `loop` are called automatically by the runtime. Do not call them manually.
