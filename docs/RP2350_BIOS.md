# RP2350 Cartridge BIOS — Architecture & Plan

Status: **design + skeleton** (2026-07-10). Not yet running on hardware.

## Goal

The RP2350 debug/arcade cartridge runs a **BIOS (firmware)** that:

1. Implements the `vectrexInterface` — the hardware layer that drives the Vectrex
   VIA 6522 (draw vectors, sound via the AY-3-8912 PSG, read controllers) by
   bus-mastering the Vectrex (halt the 6809, take the bus).
2. **Executes VPy programs** — the boot **intro**, a **menu/launcher**, and
   RP2350 **game ROMs** compiled from VPy.

The **system functions live in the BIOS**. VPy programs do *not* embed their own
copy of the hardware layer; they **call into the BIOS** through a stable
syscall ABI. Updating the BIOS (fixing the bus timing, improving drawing, adding
features) then requires **no recompilation of existing VPy programs**, as long as
the ABI contract is preserved.

This mirrors the real Vectrex: the BIOS lives in ROM ($E000–$FFFF) with system
routines (`Reset0Ref`, `Draw_Line_d`, …) that cartridges call. Here the RP2350
firmware is that BIOS, and VPy-compiled programs are the cartridges.

## Why a BIOS (what the code already tells us)

Inspecting the current VPy `--target rp2350` output:

- The VIA-level logic the compiler emits (`dv_reset`, `vpy_wait_recal`,
  `psg_*`, drawing) is **correct and hardware-independent** — it operates on VIA
  register addresses ($D000–$D00F).
- The **only** genuinely hardware-specific pieces are `bus_write` (the raw bus
  access) and the boot init (halt the 6809, set buffer directions, pin funcsel,
  clocks). And the emitted `bus_write` currently targets the **wrong pinout**
  (address→GP0-14, data→GP15-22, no A15, no halt/buffer/R-W handling) — it works
  in the emulator but would not drive the real cart.
- The compiler already refers to `dv_reset` / `dv_move_to` / `dv_draw_delta` as
  **"traps"** (see `buildtools/vpy_codegen/src/arm/drawing.rs`), even though it
  currently emits them inline. The design was always pointing at a BIOS.

So the natural split is: **BIOS owns everything hardware-specific plus the shared
vectrexInterface; VPy programs own only their logic + asset data and trap into
the BIOS.**

## ABI mechanism: SVC traps

VPy programs invoke BIOS services with the ARM **`svc #N`** instruction. The BIOS
`SVCall` exception handler reads the syscall number `N` and dispatches.

Why SVC (over a fixed jump table):

- **Total address decoupling** — a VPy binary embeds only the syscall *number*,
  not even a table base address. The BIOS can live/relocate anywhere.
- **Single controlled entry point** — the BIOS owns dispatch; it can version,
  emulate missing syscalls, add privilege separation for third-party ROMs.
- The "no recompile on BIOS update" property comes from **ABI stability**, not
  from SVC itself (a fixed jump table kept stable would also survive updates).
  SVC is chosen for the decoupling and OS-cleanliness above.

Encoding: the syscall number is the **8-bit immediate** of the Thumb `svc`
instruction (`0xDF NN`) → up to **256 syscalls**, ample for the whole interface.
Calling convention: **args in r0–r3, return value in r0** (AAPCS). The BIOS reads
args from the stacked exception frame and the immediate from the stacked
instruction, and writes the return value back into the frame's r0 slot.

### The golden rule (ABI stability)

**Append-only. Never renumber an existing syscall, never change its register
signature.** Add new capabilities at new numbers. Reserve `SYS_BIOS_VERSION` so a
program can query the BIOS version/capabilities at runtime. Breaking this rule
breaks every already-compiled VPy binary.

## Syscall contract (v0.1)

Canonical source of truth. Mirrored as constants in both the BIOS firmware
(`firmware/src/syscalls.rs`) and — when the compiler gains BIOS-linked mode — the
VPy compiler.

| # | Name              | Args (r0, r1, …)            | Returns (r0) | Maps to (vinterface) |
|---|-------------------|-----------------------------|--------------|----------------------|
| 0 | `SYS_RESET0REF`   | —                           | —            | `zero_beam()` |
| 1 | `SYS_WAIT_RECAL`  | —                           | —            | `wait_recal()` (frame pace ~50 Hz + zero ref) |
| 2 | `SYS_SET_INTENSITY` | r0 = intensity 0–127      | —            | `set_brightness()` |
| 3 | `SYS_MOVE`        | r0 = x (i8), r1 = y (i8)    | —            | `move8()` (beam blanked) |
| 4 | `SYS_DRAW_DELTA`  | r0 = dx (i8), r1 = dy (i8)  | —            | `draw8()` (beam lit) |
| 5 | `SYS_PSG_WRITE`   | r0 = reg, r1 = data         | —            | `psg_write()` |
| 6 | `SYS_PSG_SILENCE` | —                           | —            | `psg_silence()` |
| 7 | `SYS_READ_BUTTONS`| —                           | r0 = P1(0-3)\|P2(4-7) | `read_buttons()` |
| 255 | `SYS_BIOS_VERSION` | —                         | r0 = (major<<8)\|minor | constant |

Coordinate/units convention (unchanged from the proven `master.rs`): coordinates
are signed 8-bit (±127) from screen centre, **Y up positive**. A line is drawn as
`RESET0REF → SET_INTENSITY → MOVE(x0,y0) → DRAW_DELTA(x1-x0, y1-y0)`.

This set is deliberately the **primitive** layer. The asset-iterating logic
(`vpy_draw_vector` walking a `.vec` path list, `DRAW_VECTOR_3D` rotation, etc.)
stays in the VPy program for now — it is data-driven and program-specific, and it
composes these primitives. A later ABI revision may promote hot paths (e.g. a
whole `draw_vector`) into the BIOS if profiling shows the per-primitive SVC
overhead matters.

## Memory map (RP2350, 512 KB SRAM @ 0x20000000, flash @ 0x10000000)

```
Flash 0x10000000 ┌──────────────────────────┐
                 │ BIOS image (.start_block, │  boots first; RP2350 bootrom entry
                 │ vector table, vinterface, │
                 │ SVCall dispatcher, loader) │
                 ├──────────────────────────┤
                 │ Boot program: the intro   │  run by the BIOS at power-on
                 ├──────────────────────────┤
                 │ VPy program store (menu,  │  further VPy "ROMs", selected by
                 │ games) — flash or SD/PSRAM │  the menu/launcher
                 └──────────────────────────┘
SRAM  0x2007F000 ┌──────────────────────────┐
                 │ VPy runtime RAM (existing │  ram_layout.rs region
                 │ arm/ram_layout.rs map)     │
                 └──────────────────────────┘
```

Open decision: whether VPy programs are (a) linked to a fixed load address and
run in place from flash, or (b) position-independent and copied to RAM/PSRAM by
the loader. (a) is simplest for the intro; (b) is needed for a general multicart.
Start with (a) for the boot intro.

## Boot flow

```
power-on
  → RP2350 bootrom validates the BIOS .start_block/ImageDef, jumps to _start
  → BIOS: clocks/PLL init
  → BIOS: bus init (assert /HALT on the 6809, buffers → DRIVE, pins → SIO)
  → BIOS: VIA init (DDRs, ACR=0x80, beam off, PSG silence)
  → BIOS: run the boot program = the INTRO (calls BIOS via SVC)
  → (later) INTRO finishes / button press → MENU → launch selected VPy ROM
```

## Hardware facts the BIOS bus layer must honor (proven in `master.rs`)

These were hard-won on real hardware — do **not** re-derive or guess:

- Pinout: A0–A14 = GP4–GP18, **A15 = GP19** (the pin labelled "CART_nCE"; without
  it the VIA at $D000 can't be selected). D0–D7 = GP21–GP28.
- `/HALT` = GP1 **HIGH asserts** (BSS138 FET → /HALT low at the 6809).
- Buffers: `ABUS_DIR` = GP20, `DIR_CTRL` = GP29, **LOW = DRIVE** (RP→Vectrex).
  HIGH caused bus contention and the RP2350 got HOT — heat is the discriminator.
- `R/W` drive = GP30, **LOW = write** (U8 = 74LVC1G07 non-inverting open-drain).
- **Pads must be set to SIO funcsel first** (HAL `into_push_pull_output()`); raw
  SIO writes do nothing until then.
- A write holds the bus ~1.3 µs (≈2 E cycles); E keeps running with the 6809
  halted, so the VIA latches. Do **not** sync writes to /OE (never toggles).
- `aux_cntl` (ACR) = **0x80** for the CNTL-beam draw model (T1→PB7 ramp on, shift
  register disabled). 0x98 leaves the SR driving CB2 → fights the beam and buzzes
  the PSG.
- Draw model = immediate8/BIOS: DAC (VIA port A) = beam velocity (raw ±127); VIA
  T1 timer = ramp duration (fixed `DRAW_SCALE ≈ 0x7F`).

## Compiler changes (VPy `--target rp2350` → BIOS-linked mode)

Design only (not yet implemented — see "Do not break" below):

- Add a **BIOS-linked emission mode** (a new `--target rp2350-bios`, or a flag on
  `rp2350`). In this mode the backend emits `svc #SYS_x` for the system
  primitives instead of their inline bodies:
  - `dv_reset` → `svc #SYS_RESET0REF`
  - `vpy_wait_recal` → `svc #SYS_WAIT_RECAL`
  - `vpy_set_intensity` / the SET_INTENSITY override store stays program-side, but
    the DAC write becomes `svc #SYS_SET_INTENSITY`
  - `dv_move_to` → `svc #SYS_MOVE`
  - `dv_draw_delta` → `svc #SYS_DRAW_DELTA`
  - PSG writes → `svc #SYS_PSG_WRITE`, `read_buttons` → `svc #SYS_READ_BUTTONS`
  - `bus_write` and the boot init are **dropped entirely** (owned by the BIOS).
- The existing inline `rp2350` mode is kept for the **emulator** path (the
  emulator does not implement SVC). Keep both until the emulator learns SVC.
- The compiler must NOT emit clocks/pin/halt init in BIOS-linked mode (the BIOS
  did it). The program's entry becomes "call `main`, then loop `loop()`", with all
  hardware access via SVC.
- Boot-image requirements for a standalone program that the BIOS jumps to:
  agree a load address + entry ABI with the loader (see Memory map open
  decision).

## Do NOT break (constraints while iterating)

- The **emulator** path (inline `rp2350`) must keep working — it's how the intro
  is previewed. Any SVC emission must be a *new* mode, gated, not a replacement.
- The proven `master.rs` bus-master house demo must keep building/flashing — it's
  the only end-to-end-verified hardware bring-up. The BIOS reuses its exact
  timing/pinout; it does not replace it until validated on hardware.

## Implementation status (2026-07-10, this session)

Firmware skeleton added to the private repo
(`vectrex-arcade-private/hardware/debug_cart/firmware/`):

- `src/syscalls.rs` — the ABI constants above (shared source of truth).
- `src/vinterface.rs` — the `vectrexInterface` primitives + `init()`, extracted
  from the proven `master.rs` (same pinout/timing/model), exposed for reuse.
- `src/bios.rs` — `run()` (init → boot program), the `SVCall` dispatcher, and a
  demo that exercises the syscall table.
- `main.rs` still runs `master::run` (the proven demo) by default so nothing
  regresses; switching the boot to the BIOS is a one-line change once validated.

## Roadmap

1. **BIOS skeleton compiles** (this session) — vinterface + syscalls + SVC
   dispatcher.
2. **Validate SVC on hardware** — flash a BIOS that draws the house via `svc`
   calls (not direct calls); confirm the dispatcher + frame handling work.
3. **Compiler BIOS-linked mode** — emit `svc #N`; drop inline runtime + init.
4. **Run the intro** as a BIOS-linked program at boot (the actual goal).
5. **Loader + menu** — the BIOS boots into a menu that launches VPy ROMs; the
   intro plays first.
6. **Emulator SVC support** (optional) so the BIOS-linked build previews too.

## Retained-mode dual-core render engine (DESIGN — next milestone after the intro boots)

Goal: maximize vectors per frame by removing the two mutual stalls of the
current immediate mode, where the CPU busy-waits ~85-100 µs per segment ramp
and the beam sits dark while the program computes. Proposed by the user
(2026-07-11); applies conceptually to PiTrex too (minus the parallelism).

### Architecture

```
CORE 0 (logic)                        CORE 1 (render engine)
──────────────                        ──────────────────────
VPy program runs                      loop:
  svc SYS_MOVE/DRAW/... ──┐             frame_sync (absolute 20 ms deadline)
                          │             pop next display list from queue
  BIOS RECORDS the call   │             draw it (E-synced bus protocol)
  into the current list ──┘             PSG music tick between segments
  svc SYS_WAIT_RECAL:
    seal list → SORT → push to queue
    (blocks only if queue full)
```

- **Transparent to programs and the compiler.** The immediate-mode syscalls
  (SYS_MOVE, SYS_DRAW_DELTA, SYS_SET_INTENSITY, SYS_RESET0REF) stop executing
  hardware writes and instead *record*: the BIOS tracks the absolute beam
  position (zero = centre; moves/draws are deltas) and appends absolute
  segments `(x0, y0, x1, y1, intensity)` to the frame's list. SYS_WAIT_RECAL
  seals, sorts and enqueues the list, then starts the next. **No new ABI, no
  compiler change, no VPy recompilation** — the append-only ABI paying off.
- Reads (SYS_READ_BUTTONS, SYS_BIOS_VERSION) stay immediate. SYS_BUS_WRITE
  (raw VIA, used by the program-side music engine) is forwarded to core 1 as
  ordered list items or handled by a core-1 PSG mailbox — decide during
  implementation; PSG writes must NOT be reordered relative to each other.

### Display list

Per segment: `x0, y0, x1, y1 (i8 each), intensity (u8)` ≈ 5-6 bytes. A maxed
frame (~145 segments) is under 1 KB. Statically allocate N buffers.

### Sorter (core 0, at seal time)

Physics note: with a FIXED ramp (T1 = 0x7F) a short blanked move costs the
same ~85 µs as a long one — so plain distance minimization buys nothing by
itself. The wins, in order:

1. **Chaining** — order segments so one ends where the next begins (greedy
   nearest-neighbour over endpoints, trying both segment orientations). A
   chained segment needs NO move at all: the big win.
2. **Variable move ramps** — the BIOS controls T1CL per operation, so short
   moves can use a short T1 (the real BIOS varies its waits by distance too).
   With this, minimizing residual move *distance* pays. Scale T1 ≈
   max(|dx|, |dy|) with a floor; velocity stays the raw delta.
3. Re-zero (`Reset0Ref`) only on drift budget (every K segments or when the
   tracked error bound exceeds a threshold), not per path.

Greedy nearest-neighbour is O(n²) with n ≈ 150 → trivial for core 0.

### Queue depth = 2 (maybe 3) — NOT 5

Every queued frame is +20 ms between game logic and the eye. Depth 5 = 100 ms
input lag (unplayable feel); depth 2 = classic double buffering (compute N+1
while drawing N) = 20 ms latency and no stalls unless compute time exceeds a
frame. Depth 3 only if compute time proves spiky. Overrun policy: if a list
takes > 20 ms to draw (too many segments), core 1 finishes it and the frame
rate drops for that frame; core 0 blocks on a full queue (natural
back-pressure).

### Inter-core protocol (RP2350)

- `hal::multicore::Multicore` to launch core 1 (own stack, ~4 KB).
- Ring of list buffers + SIO FIFO for ownership handoff (or two atomics:
  `ready_idx` / `free_idx`). Core 1 owns ALL Vectrex bus access after boot —
  single writer, keeps the E-sync timing clean.
- defmt/RTT stays on core 0.

### Candidate optimization: burst E-sync (measure on HW first)

`bus_write` currently re-syncs to the E clock on EVERY write (flip R/W→READ,
wait for an /OE falling edge, flip R/W→WRITE, pulse A15 across one E fall).
For a burst of ~6 writes per vector that's ~0.5–1.3 µs of /OE-wait each. Since
E is a stable 1.5 MHz clock, we could sync ONCE at the start of a burst and
time the remaining writes open-loop (known 666 ns offsets), cutting per-write
overhead toward ~1 µs or less. RISK: accumulated phase drift if the open-loop
timing isn't exact — must be verified on a scope (watch /OE vs our A15 pulses
over a burst). Do NOT enable blindly; measure the current single-pulse E-sync
throughput on hardware Monday first, and only pursue burst-sync if writes are
the bottleneck. (Note: the earlier double-pulse write was already replaced by
single-pulse E-sync in commit 04cf45f — there is no double-pulse to remove.)

Hard ceiling: the Vectrex VIA is clocked by the 6809's Φ2/E (~1.5 MHz),
generated by the Vectrex crystal divider — it keeps running when the 6809 is
halted (that's why our approach works), but we cannot exceed ~1.5 M register
writes/sec (~666 ns/write) nor change the T1 timer granularity. The RP2350 at
150 MHz is ~100× faster than E, so we are always E-bound and analog-bound
(integrator slew / DAC settle / phosphor), never CPU-bound.

### Phasing

1. Ship the intro on the current immediate mode first (Monday) — baseline.
2. Core 1 bring-up: move the existing immediate executor to core 1 behind a
   1-deep mailbox (no sorting) — validates multicore + single-writer bus.
3. Recording + seal-on-WAIT_RECAL + depth-2 queue.
4. Sorter (chaining), then variable move ramps, then drift-budget re-zeros.
5. Measure: segments/frame before vs after on real hardware.

## Open questions (decide with the user)

- VPy program load model: run-in-place (fixed address) vs copy-to-RAM/PIC.
- Where the VPy program store lives: internal flash, external QSPI flash, SD.
- Frame pacing: `SYS_WAIT_RECAL` fixed ~50 Hz delay vs a real VIA T2-based recal.
- Whether to promote `draw_vector` (asset walk) into the BIOS for speed.
