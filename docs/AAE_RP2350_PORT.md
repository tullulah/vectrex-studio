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

- ✅ Approach validated: **`asteroid.c` compiles clean for thumbv8m/Cortex-M33**
  (`-ffreestanding -Os`, 7.4 KB .o) against the AAE headers + the RP2350 SDK
  include + our libc shims.
- ✅ `examples/aae_asteroids/` project scaffolded: `.cvproj`, `Makefile`
  (rp2350 target), `include/{stdlib,string,stdio}.h` (minimal libc shims),
  `src/libc_stub.c` (freestanding `memcpy/memset/rand/malloc`-arena/`printf`-nop),
  `src/asteroid_roms.h` (embedded ROMs), `src/main.c` (frame-loop skeleton).

## Remaining build steps (the grind, in order)

1. **Compile the rest of the file set.** Add `m6502.c`, `m6502zp.c`,
   `cpuintrf.c`, `cpu_control.c`, `rand.c`, `acommon.c` to the build; fix each
   freestanding issue (more libc functions → extend `libc_stub.c`; hosted-header
   uses → extend the `include/` shims). Sound (`pokey`), high-score EEPROM
   (`earom`), and file/zip loaders are stubbed or replaced.
2. **Machine setup.** `run_cpus_to_cycles()` needs AAE globals: `gamenum`,
   `driver[ASTEROID]` row, `num_cpus`, `cyclecount[]`, `running_cpu`,
   `tickcount[]`. Either include a **trimmed `aaemain.c`** (Asteroids driver row
   only) or set these up directly in `main.c`. Compute `cyclecount` from
   clock/framerate/divisions the way `aaemain` does.
3. **ROM loader.** Replace `load_roms` with a function that copies the
   `asteroid_roms.h` arrays into 6502 memory at the load addresses from AAE
   `gameroms.h` (`cpu_mem`/the 6502 memory map), then `init_asteroid()`.
4. **Coordinate scale.** AAE emits large coords (e.g. `x0-17000`, PiTrex scale).
   Pick `VPY_SCALE` in the shim (or pre-scale in a wrapper) so the drawing fits
   the Vectrex ±127 field at the right size.
5. **Link + fit.** RAM link via `rp2350_game_ram.ld` (`game_main` entry, `VPy2`
   header from `rp2350_start.s`). Confirm code + ROM + arena fit GAME_RAM (252 KB).
   `main.c`'s entry is `game_main` (the BIOS jumps there).
6. **Run on HW.** Build → SD → launch from the cart menu (same flow as
   SnowBros_c). Tune the drift cap / coord scale / CPU cycles-per-frame on
   hardware. Sound (Pokey→PSG) is a later pass.

## Build

```
make -C examples/aae_asteroids aae_asteroids_rp2350   # (WIP — links once steps 1-5 done)
arm-none-eabi-gcc ... -c asteroid.c                    # already compiles today
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
