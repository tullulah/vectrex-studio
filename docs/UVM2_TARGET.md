# UVM2 Target — Ultimate Vectrex Multicart 2

Vectrex Studio compiles VPy to a native RP2350 image that runs on Ralf & Jason's
Ultimate Vectrex Multicart 2. This document describes how that target works, how
to bring a board up, and what is not implemented yet.

## Execution model

The UVM2 exposes no HAL, no BIOS and no API. Its RP2350 GPIOs are wired directly
to the Vectrex cartridge bus, and a program has two ways to put something on
screen: answer the 6809's ROM fetches, or **halt the 6809 and drive the VIA
itself**. Vectrex Studio always does the latter — the generated code is native
ARM, so the 6809 has nothing to execute.

Drawing therefore means writing the same VIA registers a 6809 game would write,
phase-locked to the 1.5 MHz clock the 6809 keeps generating while halted.

## Image format and memory map

The firmware reads a `.um2` file from the SD card, copies it to SRAM and jumps
to it. Everything lives in RAM; there is no flash or XIP for the game.

```
0x20000000  ┌──────────────────────────────┐ ← image loaded here
            │ Cortex-M vector table        │   word 0 = SP, word 1 = entry
            │ code + rodata + data + bss   │   496 KB (uvm2_game.ld)
0x2007C000  ├──────────────────────────────┤
            │ VPY_RAM — VPy variables      │   16 KB
0x20080000  ├──────────────────────────────┤
            │ scratch banks                │
0x20082000  └──────────────────────────────┘ ← initial SP, grows down
```

`.um2` header, 20 bytes little-endian, followed by the raw image:

| Offset | Field | Notes |
|---|---|---|
| 0 | magic `"2CMU"` | |
| 4 | version | 1 |
| 8 | block count | 1 |
| 12 | load address | `0x20000000` |
| 16 | length | **in 32-bit words, not bytes** |

The word count is derived from the reference image `Asteroids_0_1a.um2`, whose
header reads 0x8AC0 while its payload is 142080 bytes — exactly 35520 × 4.
Writing bytes there makes the loader copy a quarter of the image.

## The syscall ABI is shared

Every VPy builtin compiles to `svc #N`. That table is the contract, and it has
three other implementations: the RP2350 cartridge firmware, the IDE emulator
(`Rp2350System.ts`), and the C runtime used by imported C/SBT projects. UVM2 adds
a fourth by installing an SVCall handler inside the generated image — vector 11
points at `uvm2_svc_handler`.

Nothing in the shared ARM codegen is forked for UVM2. A UVM2 image differs from
an RP2350 one only in that handler and in the runtime linked beside it, which is
also why an imported C or SBT program gets UVM2 support for free.

## The SDK

`ide/electron/resources/uvm2-sdk/` — compiled and linked into every UVM2 build.

| File | Role |
|---|---|
| `uvm2_bus.c/.h` | Halt-mode transport: bring-up, the command executor, single read/write cycles |
| `uvm2_draw.c/.h` | Beam control — VIA sequences recorded into a command stream |
| `uvm2_input.c/.h` | Buttons, joysticks, PSG (real bus reads) |
| `uvm2_text.c/.h` | Stroke-font text (`SYS_PRINT_TEXT`) |
| `uvm2_audio.c/.h` | `.vmus` / `.vsfx` sequencer (`SYS_PLAY_MUSIC`, `STOP_MUSIC`, `PLAY_SFX`) |
| `uvm2_font.h` | 4×6 stroke font — **generated**, see below |
| `uvm2_led.c/.h` | Status LED and core-clock calibration |
| `uvm2_svc.c`, `uvm2_svc_entry.s` | The syscall table |
| `uvm2_game.ld` | Linker script |
| `tools/uvm2_budget.c` | Host harness: counts the command stream without hardware |
| `tools/gen_font.py` | Regenerates `uvm2_font.h` from the emulator's font |

### Bus protocol

One VIA write is one bus cycle:

```
wait CLK HIGH → drive address + data + R/W low → wait CLK LOW
```

The bus is updated just after the rising edge and held across the falling edge,
where the VIA latches. Driving during the low phase and releasing on the rising
edge changes the bus exactly at the latch point and writes garbage.

`/HALT` is asserted once at startup and never released: the moment it goes high
the 6809 resumes BIOS execution and fights for the bus. Between accesses the bus
parks at `$8000`, which is unmapped, so an idle bus cannot repeat the last write.

### Command stream

Drawing calls record 32-bit words rather than touching the bus; `SYS_WAIT_RECAL`
replays the whole buffer back-to-back. The encoding is bit-identical to the one
Ralf's own games use:

```
bits 31..20  delay — bus cycles to idle after this write
bits 19..16  VIA register  → A0-A3
bits 15..8   data byte     → D0-D7
```

`(word >> 8) & 0xFFF` lands directly on GPIO0-11, so the inner loop shifts
nothing and holds one command per bus cycle.

### Frame budget

50 Hz is 30000 bus cycles. Measured with `tools/uvm2_budget.c`:

| Drawing policy | Cycles/vector | Vectors/frame |
|---|---|---|
| Re-zero + move + draw per segment, scale 128 | 406 | 74 |
| Same, scale 64 | 262 | 114 |
| Chained segments, one centring per shape, scale 128 | 170 | 176 |
| Chained, scale 64 | 102 | 294 |
| Chained + proportional ramp (`fixup`) | 74 | 405 |

The command-stream model is not what buys throughput — it removes jitter and
makes a two-core split possible, but the cost per vector is dominated by the
drawing policy. Re-centring the beam on every segment costs 77 cycles of `/ZERO`
plus a full blanked move, and that alone is the difference between 74 and 176
vectors per frame.

`uvm2_draw_set_scale()` and `uvm2_draw_set_fixup()` expose both levers. Defaults
match the reference (scale 128, fixup off) so measurements stay comparable.
These are cycle ceilings, not stability results: per-path re-centring exists
because it cured beam trembling, so what is actually usable is a hardware
question.

## Text

`SYS_PRINT_TEXT` renders the same 4×6 stroke font the IDE emulator uses, with
identical geometry — half-unit scaling `(glyph × TEXT_SIZE) >> 1`, the same
baseline shift and the same `(7 × scale) >> 1` advance — so a string lands in
the same place on hardware as it does in the simulator. That equivalence is
verified by dumping both renderers' segments and diffing them.

The font itself is **generated** from
`ide/frontend/src/emulator/systems/vectorFont.ts` by `tools/gen_font.py`, rather
than hand-copied, so the two cannot silently drift. If a glyph changes, re-run
the script and commit the result.

Text is by far the most expensive thing a frame can do, because each glyph
re-centres the beam before drawing — that zero is what relights it, and chaining
glyphs without it leaves later ones unlit.

| String | Settings | Cycles/char | Share of a 50 Hz frame |
|---|---|---|---|
| 10 chars | default | 870 | 29% |
| 20 chars | default | 1022 | 68% |
| 10 chars | `fixup` on | 428 | 14% |
| 20 chars | `fixup` on | 521 | 35% |

Cost is independent of `TEXT_SIZE`: glyph strokes are tiny, but every one of
them ramps for the full fixed `scale`. The proportional ramp is therefore worth
roughly twice as much on text as it is on ordinary vectors.

## Audio

`.vmus` and `.vsfx` playback is a port of the software sequencer in libvpy
(`vpy-c/vpy.c`), the reference for the PiTrex and WASM paths — same event
format, same one-tick-per-frame model, same channel-C mixer merge. Equivalence
is verified by running both sequencers over the same compiled assets and diffing
the PSG writes they emit, including a looping track and an effect overlaid on
music.

Where our own cartridge runs this on core 1 — clocked by real time — UVM2 ticks
it from `SYS_WAIT_RECAL`, but on **elapsed Vectrex time rather than once per
frame**: `uvm2_frame_bus_cycles()` reports what the frame really cost, and the
sequencer is advanced once per 30000 of those cycles, catching up when a frame
runs over. Ticking once per frame instead means a draw-heavy game plays its
music at half speed, which is exactly what a 25 Hz game did.

A game that overruns still runs at a lower frame rate; only the tempo is
insulated. `uvm2_stats.overrun` counts the frames that went over.

PSG writes go out as direct bus accesses in the same between-frames window as
input, never recorded into the beam command stream: they drive Port B, which
would disturb a draw in progress. A frame's worth costs a few dozen bus cycles
out of 30000.

## Simulator

`ide/frontend/src/emulator/systems/Uvm2System.ts` runs a `.um2` image without
hardware. It is deliberately **not** the RP2350 system with a different loader:
that one intercepts every `svc` in JavaScript and injects vectors straight into
the beam, which is correct for our own cartridge because the syscalls really are
firmware there. On the UVM2 the syscall handler, the bus protocol and the beam
timing all live inside the image — they are exactly the code that has never run
on hardware, so intercepting them would simulate everything except the part
worth testing.

It emulates the wire instead:

- SIO GPIO registers at `0xD0000000`, Vectrex CLK on bit 31
- a 1.5 MHz bus clock derived from CPU cycles (100 core cycles per bus cycle)
- address/data/R-W decoded on each **falling** edge into a real `Via6522` write,
  the same edge the hardware latches on
- `Via6522` + `Beam` ticked once per bus cycle, so our own ramp timings drive
  the analog integrators and produce vectors
- `svc` performing a real Cortex-M exception entry into the image's own handler

A wrong CLK phase, a mis-encoded command, a ramp that is too short or a frame
over budget therefore fail here the same way they would on a console.

Frame 0 is consumed entirely by the `/HALT` settle (30000 bus cycles by design),
frame 1 by VIA initialisation; steady state begins at frame 2.

It is wired into the IDE like any other target. Building with `uvm2` selected
runs the result in the emulator panel, badged **EMULATING UVM2 (halt-mode bus)**,
and opening a `.um2` from disk is auto-detected by its `2CMU` header. Joystick
and buttons feed the emulated analog path — the image reads them by driving the
DAC against the comparator, exactly as it will on hardware — and the PSG plays
through Web Audio.

Input is worth its own note, because three separate things have to line up.
`uvm2_via_read` samples on a rising edge and must leave the clock LOW before
returning — otherwise the caller's next write starts in the dying part of that
same high phase and misses the falling edge that latches it, so the first write
after every read is silently lost. Buttons live on **PSG register 14**, not VIA
Port B, whose bit 5 is the joystick comparator: routing buttons through Port B
pins the comparator high and every axis reads as full deflection. And `svc #7`
and `svc #14` return the same byte in different shapes — #7 as "1 = pressed"
with J1 in bits 0-3, #14 as `(J1 << 8) | J2` still active-low with J1 at bits
4-7. Returning one where the other is expected leaves every button held down.

Note that the frame loop is capped at 50 Hz by the host, but the image paces
itself against the emulated bus clock, so a frame that overruns its budget slows
down here in the same way it would on a console.

Two notes for anyone extending this. JavaScript bitwise operators yield a
**signed** 32-bit result, so `addr & 0xFFFFF000` never equals `0xD0000000` and
`pc & 0xFFFFFFF0` never equals `0xFFFFFFF0` — both need `>>> 0`, and both bugs
presented as "the image runs but nothing happens". And the joystick axes read
back whatever the emulated comparator happens to hold, so a stick-driven sprite
sits off-centre in the simulator; that is the simulator, not the game.

## Bring-up

`examples/uvm2_bringup/` is a ladder of eight images, each adding exactly one
thing so a failure isolates its cause. Build one, copy the `.um2` to the SD card,
run it:

```bash
vpy_cli build --target uvm2 examples/uvm2_bringup/s2_dot/s2_dot.vpyproj
```

| Stage | Adds | Pass looks like |
|---|---|---|
| `s1_frame` | nothing — boot and frame pacing only | black screen, **green LED** |
| `s2_dot` | the first VIA write that must reach the beam | one dot at centre |
| `s3_line` | ramp length on both axes | an L with two equal arms |
| `s4_cross` | negative deltas | a symmetric cross |
| `s5_square` | chained segments, intensity | a closed square, dimmer one inside |
| `s6_input` | bus **reads** | cross follows the stick, button 1 brightens |
| `s7_text` | stroke-font text | two readable lines above a rule |
| `s8_audio` | PSG music and SFX | track loops; button 1 fires an effect over it |

Each stage's `.vpy` documents what specific failures mean.

### Status LED

The cartridge has no serial port, no debugger and no `printf`, so the WS2812 on
GPIO30 is the only channel that works when the screen is black.

| Colour | Meaning |
|---|---|
| blue | image booted, no Vectrex clock seen yet |
| red | no clock at all — console off, or cart not seated |
| amber | clock found, taking the bus; stuck here = the 6809 never halted |
| green | frames going out |

The core clock is calibrated against the Vectrex's 1.5 MHz CLK, since that is the
one frequency we know. Calibration is bounded: a missing clock returns rather
than hanging, because that case is exactly what the red state reports.

## Not implemented

- **Digitised samples** and **SD browsing**. These are no-ops, matching the IDE
  emulator, so a game that calls them runs rather than hanging.
- **Analog joystick.** The successive-approximation path is written but its
  comparator polarity is inferred, not measured. Digital axes — a literal port of
  the reference — are the default, scaled to ±127 so ordinary game code behaves.
- **Two-core drawing.** The command stream is built for it (compose on core 0,
  replay on core 1, double-buffered) but the split is not implemented.
- **Return to the menu.** CrazyStones calls `rom_reboot(BOOT_TYPE_NORMAL, ...)`;
  whether that is the intended mechanism is unconfirmed.

## What is not implemented

Six syscalls are accepted and return 0, matching the IDE emulator, so a game
that calls them runs rather than hangs:

| Syscall | What is missing |
|---|---|
| `#9` PLAY_SAMPLE, `#10` SAMPLE_POS | digitised `.vsmp` audio |
| `#17`-`#20` SD_COUNT / SD_NAME / SD_PREVIEW / LAUNCH | browsing and launching other SD games from inside a game |

Everything else — drawing, text, input, PSG music and SFX, raw bus access — is
implemented.

Beyond the syscall table:

- **Two-core drawing.** The command stream is built for it (compose on core 0,
  replay on core 1) but the split is not written. This is the fix for a
  draw-heavy game running at 25 Hz, not a correctness gap.
- **Analog joystick.** The successive-approximation path exists but its
  comparator polarity is inferred from the BIOS listing, not measured. Digital
  axes — a literal port of the reference — are the default.
- **Return to the multicart menu.** A game that ends simply spins; CrazyStones
  calls `rom_reboot`, but whether that is the supported route is unconfirmed.

## Assumptions still unverified on hardware

These are the things to suspect first if something misbehaves, in the order
they would bite:

1. **The `.um2` length field is a word count.** Deduced from Ralf's Asteroids
   image, never confirmed. If it is wrong, nothing loads at all.
2. **Port B bit 0 polarity** is documented two contradictory ways. The input and
   mux sequences are ported literally from the reference for exactly this
   reason — suspect them only after everything else.
3. **The bus parks at `$8000`** on the assumption nothing decodes it.
4. **Beam timings** (`scale`, the hold and blank delays) are the reference's
   defaults. They produce correct geometry in simulation; whether the real beam
   is stable and evenly lit at those numbers is unknown.

## Open questions for Ralf

1. Is the `.um2` length field really a word count?
2. Is `rom_reboot` the supported way back to the multicart menu?
