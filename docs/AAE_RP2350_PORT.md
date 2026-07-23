# AAE → RP2350 Cartridge Port (Asteroids first)

Porting **AAE (Another Arcade Emulator)** — a vector-arcade emulator — to run on
the RP2350 cartridge, driving a real Vectrex. First target: **Asteroids**. This
doc is the working state + how to continue.

## Goal & approach (VALIDATED)

Run AAE arcade games on the RP2350 cart by compiling AAE **as a C game against
libvpy**, exactly like `examples/SnowBros_c` — RAM-linked `_sd.bin`, launched
from the cart's SD menu (`SYS_LAUNCH`). See `docs/RP2350_BIOS.md` and the memory
notes `c-game-rp2350-hw-validated`, `libvpy-c-runtime-plan`.

**The key alignment that makes this tractable:** AAE already draws every vector
through `v_directDraw32(x0,y0,x1,y1,brightness)` — the SAME primitive the RP2350
SDK shim provides (`ide/electron/resources/rp2350-sdk/sdk_rp2350.c`). So AAE's
video output falls straight into libvpy's draw path (with the per-path re-zero +
`MAX_CONSECUTIVE_DRAWS=32` cap fixed in commit `a06ccde5`) — **no video
re-targeting needed**. Input likewise goes through `v_readButtons` /
`v_readJoystick1Analog`, which the shim provides.

**Feasibility data (measured, see memory `aae-rp2350-feasibility`):** Tac/Scan
draws ~250 vec/frame (peak 395); the RP2350's vector budget + PiTrex-style
optimization make dense games borderline. Asteroids is far lighter (few vectors)
and CPU-cheap (6502 @ 1.5 MHz on a 150 MHz M33) — the right first target.

## Source locations

- **AAE source (outside this repo):** `/Users/daniel/projects/pitrex-baremetal/aae/`
  (memory `pitrex-aae-source-location`). Asteroids is self-contained:
  `asteroid.c` (driver + DVG vector generator + `run_asteroids` + `init_asteroid`),
  `m6502/` (6502 CPU), `cpuintrf.c`, `cpu_control.c`.
- **ROMs:** `/Users/daniel/Desktop/arcade/roms/asteroid.zip` (also in
  `vectrex-arcade-private/arcade/roms/`). The 5 base ROMs (4×2 KB program + a
  256 B vector PROM = 8.25 KB) are already embedded as C arrays in
  `examples/aae_asteroids/src/asteroid_roms.h`.
- **The project:** `examples/aae_asteroids/` — `.cvproj` (type c-external,
  target rp2350), `Makefile`, `src/`, `include/`, `roms/`.

## Execution model (mapped)

- `driver[]` in AAE's `aaemain.c` holds Asteroids' config: **CPU_6502Z @
  1.512 MHz, INT_TYPE_NMI**, cpu divisions/interrupts per frame.
- `run_cpus_to_cycles()` (`cpu_control.c`) runs the 6502 for one frame in
  divisions, firing the NMI via `cpu_do_interrupt`. `exec_cpu()` dispatches to
  `m6502zpexec(cycles)`.
- The game writes the **DVG-GO register (0x3000)** → `BWVectorGeneratorInternal`
  → `dvg_generate_vector_list()` (`asteroid.c`) → `v_directDraw32` per segment.
- `run_asteroids()` is per-frame housekeeping (watchdog, sound gate).
- ROMs are loaded by `load_roms(driver[gamenum].name, driver[gamenum].rom)`
  (`aaemain.c:1107`) from a zip; the load table is in AAE `gameroms.h`.

## Current state (what works)

- ✅ **The full Asteroids file set compiles AND links** into a RAM-resident
  `_sd.bin` with a valid `VPy2` header (entry `0x20040011`). Footprint is
  **95.6 KB of GAME_RAM's 252 KB (38%)** — text 34 KB, data 0.4 KB, bss 63.5 KB
  (the 48 KB malloc arena + `vec_ram` + `vec_colors` + CPU contexts). So the
  link+fit step is already validated with generous headroom.
- ✅ Freestanding build resolved (steps 1 + 2 below): the whole file set
  (`asteroid.c`, `m6502.c`, `m6502zp.c`, `cpuintrf.c`, `cpu_control.c`,
  `rand.c`, `acommon.c`) builds under `-ffreestanding -Os -std=gnu11`.
- ✅ `examples/aae_asteroids/` project: `.cvproj`, `Makefile` (rp2350 target),
  `include/{stdlib,string,stdio,ctype,math,assert,setjmp}.h` (libc shims),
  `src/libc_stub.c` (freestanding libc: str/mem, malloc-arena, no-op file I/O +
  math + printf), `src/asteroid_roms.h` (embedded ROMs), `src/main.c` (frame
  loop), `src/aae_stubs.c` (no-op Z80/68000/pokey/log/hi-score), `src/aae_machine.c`
  (one-row Asteroids `driver[]` + machine globals + `getport`).

- ✅ **ROM loader in place** (`aae_load_asteroid_roms()` in `aae_machine.c`,
  called before `init_asteroid()`): builds the 6502 64 KB image `GI[0]` (a
  static `.bss` buffer) and copies the embedded ROMs to their `gameroms.h`
  addresses (`035127`→0x5000, `035145`→0x6800, `035144`→0x7000, `035143`→0x7800,
  reload→0xf800 for the reset/NMI vectors). Footprint now 66.6 % of GAME_RAM.
- ✅ **Draw path verified wired (in source):** the 6502 memory map routes writes
  to DVG-GO `0x3000` → `BWVectorGeneratorInternal` → `dvg_generate_vector_list()`
  → `v_directDraw32` per segment → the RP2350 SDK shim → BIOS draw. So once the
  6502 runs the game code each frame, vectors should be emitted.

### ✅ RUNS in the IDE simulator (attract mode)

Validated in the WASM sim: Asteroids boots and draws its attract screen at
**~198 vectors/frame** at 50 Hz, coordinates in PiTrex space
(`x[-18024,16760] y[-16088,10504]`). Build + run it:
```
make -C examples/aae_asteroids sim          # emcc -> build_wasm/game.js
# open the project in the IDE and press the simulator button (the [simulate]
# section in the .cvproj points it at build_wasm/game.js)
```

Two fixes were needed to get from "links" to "runs":
- **`init_cpu_config()` must be called** (between the ROM load and
  `init_asteroid`), the same as `aaemain.c` does. It derives `num_cpus` and the
  per-frame `cyclecount` from the driver row; without it the 6502 runs 0
  cycles/frame and nothing happens.
- **`getport()` must return `0x00`, not `0xff`.** AAE reads the Asteroids PIA
  bit-by-bit (`AstPIA1Read`), and `0xff` makes the **self-test switch** read as
  ON, so the ROM sits in its RAM-test diagnostic (fills RAM with `0x88`) forever
  instead of running the game.

### ✅ Playable — controls wired

`getport()` maps the Vectrex controller (via the shim's `currentButtonState` /
`currentJoy1X/Y`, refreshed each frame by `v_readButtons` /
`v_readJoystick1Analog`) onto the Asteroids ports (bit-per-switch, active-high,
per AAE `asteroid_keys`):

| Vectrex | Asteroids |
|---|---|
| Stick ◀ / ▶ | Rotate Left / Right |
| Stick ▲ (or button 2) | Thrust |
| Button 1 | Fire |
| Button 3 | Hyperspace |
| Button 4 | Coin + P1 Start (press to begin) |

Validated in the WASM sim (attract ~220 vec/frame → gameplay ~179 on start;
Fire adds bullets). Works on HW and sim (same shim globals).

### Still to do before it ships

- **Coordinate scale** — HW-confirmed fine as-is (shim `/127`), the field fits
  and centres; only revisit if a game needs a different range.
- **Coordinate scale on HW** — the sim renders PiTrex space directly, but the
  RP2350 shim divides by `VPY_SCALE=127`: ±18 k → ±142, so the field slightly
  overflows ±127 and clips at the edges. Add a tunable scale (~÷145) and centre
  offset, dial in on hardware.
- **Sound** — Pokey is stubbed (`pokey_sh_update` no-op), so `sound writes = 0`.
  A Pokey→PSG pass is later.
- **First HW smoke test** — build the `_sd.bin`, copy to SD, launch from the cart
  menu.

## Build notes learned

- **Compiler must be forced.** A `CC=cc` in the environment overrides the
  Makefile's `?=` default and pulls in host clang (which rejects
  `-mcpu=cortex-m33`). The Makefile now uses `RP2350_CC` (a non-standard name)
  so the environment can't hijack it.
- **`-std=gnu11` is required.** AAE is K&R C (`int (*f)()` = unspecified args).
  GCC 15 defaults to C23 where `()` means `(void)`, turning AAE's handler tables
  into hard errors. `-std=gnu11` restores K&R semantics.
- **`CCNT0()`** (a PiTrex ARM cycle-counter profiling macro) is defined to a
  no-op via `-D'CCNT0(x)=do{}while(0)'`.

## Remaining build steps (the grind, in order)

1. ✅ **Compile the rest of the file set.** Done. Needed: `-std=gnu11`, no-op
   `CCNT0`, and libc shims for `assert.h`, `setjmp.h` (only pulled by the unused
   musashi 68000 core), `ctype.h`, `math.h` (only `log` is referenced), plus
   `RAND_MAX`, `strcat`/`strncat`/`strncmp`, and no-op file I/O. Sound (pokey),
   high-score EEPROM, and file/zip loaders are stubbed (`src/aae_stubs.c`).
2. ✅ **Machine setup.** Done via `src/aae_machine.c`: a ONE-ROW `driver[]` with
   only the "Asteroids (Revision 2)" entry (copied verbatim from `aaemain.c`) so
   no other game's `init_*` is dragged in, plus the globals the run path reads
   (`GI`, `c6502`, `cMZ80`, `gamenum=0`, `WATCHDOG`, `total_length`,
   `vec_colors`, `config`, `testsw`, `paused`). `cyclecount` is derived inside
   `cpu_control.c` from `cpu_freq/fps/cpu_divisions` — no manual setup needed.
3. ✅ **ROM loader.** Done — `aae_load_asteroid_roms()` builds `GI[0]` (static
   64 KB) and copies the embedded ROMs to the `gameroms.h` addresses (incl. the
   `ROM_RELOAD`→0xf800 that mirrors the reset/NMI vectors). Runs before
   `init_asteroid()`, which then points the 6502's `m6502Base` at `GI[0]`.
4. **Coordinate scale (NEXT, best tuned on HW).** asteroid.c emits
   `v_directDraw32(x-17000, y+17000, …)` (~±16 k); the shim divides by
   `VPY_SCALE=127` → ~±127, so it is approximately compatible already. Add a
   tunable offset/scale (in a small wrapper or the shim) and dial it in on
   hardware so the field fits and is centred.
5. ✅ **Link + fit.** Validated — RAM link via `rp2350_game_ram.ld`, `VPy2`
   header from `rp2350_start.s`, entry is `main()` (rp2350_start's `game_main`
   zeroes bss and calls it). 38 % of GAME_RAM used.
6. **Run on HW.** Build → SD → launch from the cart menu (same flow as
   SnowBros_c). Wire real input into `getport` (`v_readButtons` /
   `v_readJoystick1Analog`). Tune the drift cap / coord scale / CPU
   cycles-per-frame on hardware. Sound (Pokey→PSG) is a later pass.

## Build

```
make -C examples/aae_asteroids aae_asteroids_rp2350 RP2350_CC=arm-none-eabi-gcc
# -> build_rp2350/aae_asteroids_sd.bin  (links today; runs once steps 3-4 + input land)
```
The IDE builds it via the `.cvproj` rp2350 recipe (`make aae_asteroids_rp2350`).

## Notes / gotchas

- Same toolchain as SnowBros_c: homebrew `arm-none-eabi-gcc` is **bare (no
  newlib)** → the build is `-nostdlib` and AAE's libc uses are shimmed.
- Keep `-Iinclude` FIRST so the shim `stdlib.h`/`string.h`/`stdio.h` win.
- AAE includes `<vectrex/vectrexInterface.h>` (its PiTrex output header);
  resolved via the vpy-c / pitrex-sim include dirs, which declare `v_directDraw32`.
- Don't pull in ALL AAE game drivers — trim to Asteroids or the link fails on
  every other game's `init_*`.
