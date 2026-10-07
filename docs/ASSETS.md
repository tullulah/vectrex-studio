# Assets

Vectrex Studio is asset-driven. Sprites, music, sound effects, animations, levels,
enemies, instruments, recordings, samples and 3D meshes are JSON files under the
project's `assets/` folder. You edit them in the IDE's editors, and code refers to
them by name. This page is the reference for every asset type: what it is, its format,
where it goes, how VPy and C code use it, and which targets support it.

The MCP tools read the same catalog (`ide/electron/src/mcp/assets.ts`):
`assets_list` lists a project's assets with the exact code that uses each one,
`asset_get_format` returns a type's format and a minimal example, and `asset_create`
writes an asset to the right folder and compiles it.

## At a glance

| Type | What | Folder | IDE editor | VPy | C (libvpy) | Targets that build it |
|------|------|--------|------------|-----|------------|-----------------------|
| `.vec` | Vector sprite | `assets/vectors/` | Vector Editor | `DRAW_VECTOR("n", x, y)`, `DRAW_VECTOR_EX("n", x, y, mirror, intensity)`, `DRAW_VECTOR_3D("n", ax, ay, az, x, y)`, `DRAW_VECTOR_ROT("n", x, y, angle)` | `#include "n.h"` → `DRAW_VECTOR(N_vec, x, y)`, `DRAW_VECTOR_ROT(N_vec, x, y, angle)` | m6809, rp2350, uvm2, pitrex; C: sim, rp2350, uvm2 |
| `.vmus` | Music | `assets/music/` | Music Editor | `PLAY_MUSIC("n")`, `STOP_MUSIC()` | `PLAY_MUSIC(N_music)` | all |
| `.vsfx` | Sound effect | `assets/sfx/` | SFX Editor | `PLAY_SFX("n")` | `PLAY_SFX(N_sfx)` | all |
| `.vanim` | Animation | `assets/animations/` | Animation Editor | `DRAW_ANIM("n", x, y, mirror)` | `DRAW_ANIM(N_anim, N_anim_sprites, x, y, mirror)` (named `.vec` frames only) | all |
| `.vplay` | Level | `assets/playground/` | Playground | `LOAD_LEVEL("n")`, `SHOW_LEVEL()`, `UPDATE_LEVEL()` | `LOAD_LEVEL(N_level, N_level_sprites)`, `SHOW_LEVEL()` | all |
| `.venemy` | Enemy type | `assets/enemies/` | Enemy Editor | placed by a level; `SPAWN_ENEMIES("level")`, `UPDATE_ENEMIES()`, `DRAW_ENEMIES()` | `SPAWN_ENEMIES(L_enemies, L_enemy_sprites)` | all |
| `.vinstr` | Instrument | `assets/instruments/` | Instrument Editor | `PLAY_NOTE("n", channel, midi_note)` | `PLAY_NOTE(N_instr, channel, midi_note)` | all |
| `.vrec` | Vector recording | `assets/recordings/` | Recording viewer | `DRAW_RECORDING("n", x, y, scale, frame)` | `DRAW_RECORDING(N_vrec, x, y, scale, frame)` | m6809 (video only), rp2350, uvm2, pitrex; C: sim, rp2350, uvm2 |
| `.vsmp` | 4-bit audio sample | `assets/samples/` | Sample player | `PLAY_SAMPLE("n")`, `SAMPLE_POS(fps)` | `PLAY_SAMPLE(N_smp)`, `SAMPLE_POS(fps)` | rp2350, pitrex; uvm2 builds but plays nothing; not m6809. C: sim, rp2350; uvm2 builds but plays nothing |
| `.vmesh` | 3D surface mesh | `assets/meshes/` (C) | Mesh Editor | not available | `vpy3d_load_mesh(&m, N_vmesh)` + `vpy3d_draw_mesh` | C only: sim, rp2350, uvm2 |

`n` is the asset name: the file name without its extension. `N` is that name upper-cased
with `-`, `.` and spaces turned into `_` (what `vpy_cli compile-asset` derives). "all"
means m6809, rp2350, uvm2 and pitrex for VPy, and sim, rp2350 and uvm2 for a C project.
The VPy target column was measured by building a project that uses each call with
`vpy_cli build --target <t>`.

Other files you may find in `assets/` are not used by code:

| File | What it is |
|------|------------|
| `.vmov` | Vector movie manifest (Vector Movie editor). It pairs a `.vrec` video with a `.vsmp` voice track, and code plays those parts: `DRAW_RECORDING` + `PLAY_SAMPLE`, with `SAMPLE_POS(fps)` as the frame clock. |
| `.vrb` | A binary preview the IDE generates from a `.vrec` (`vpy_cli vrec-compile`) for the SD-card game menu. It is generated, so don't edit it. |
| `.vgz` | A compressed VGM recording of arcade audio, kept as source material for sound rips ([ARCADE_SOUND_RIP.md](ARCADE_SOUND_RIP.md)). No compiler or editor reads it. |

## How a VPy project uses assets

The compiler finds assets by folder, not through the `[resources]` table of the
`.vpyproj` (`discover_assets` in `buildtools/vpy_codegen/src/m6809/assets.rs`). It
looks in `assets/vectors`, `assets/music`, `assets/sfx`, `assets/animations`,
`assets/instruments`, `assets/enemies`, `assets/recordings` and `assets/samples`. Levels
(`.vplay`) can sit in any direct sub-folder of `assets/`, and the IDE's Playground
saves them in `assets/playground`.

Code names an asset with a string literal holding its file name, and the match is
case-sensitive. Only assets the code names are embedded. The exceptions are the sprites
a level or animation references, and the `.venemy` files. Those are pulled in
automatically.

```python
def main():
    LOAD_LEVEL("level1")          # assets/playground/level1.vplay
    SPAWN_ENEMIES("level1")       # the enemies that level places
    PLAY_MUSIC("theme")           # assets/music/theme.vmus (loops)

def loop():
    SHOW_LEVEL()
    UPDATE_ENEMIES()
    DRAW_ENEMIES()
    DRAW_ANIM("hero_walk", x, y, facing_left)   # assets/animations/hero_walk.vanim
    DRAW_VECTOR("coin", 40, 20)                  # assets/vectors/coin.vec
    if J1_BUTTON_1():
        PLAY_SFX("jump")                         # assets/sfx/jump.vsfx
```

The music/SFX update and the frame sync are injected by the compiler. Don't call
`AUDIO_UPDATE()`, `MUSIC_UPDATE()` or `WAIT_RECAL()`.

A build only warns about an asset that fails to load, and then stops on an undefined
symbol. `vpy_cli check-asset <file>` loads and compiles a single asset with the same
code the backends use, and prints the real error. `asset_create` runs it for you.

## How a C project uses assets

A C project (`.cvproj`, libvpy) compiles each asset into a header with
`vpy_cli compile-asset <file> --format c --out gen/<name>.h`. The IDE passes its
compiler to the build as `$(VPY_CLI)`. The Makefile of a new C project (from
`project_create {kind:"c"}` or File > New Project) has the rules. It compiles
`assets/vectors/*.vec`, `assets/music/*.vmus`, `assets/sfx/*.vsfx`,
`assets/animations/*.vanim`, `assets/playground/*.vplay`, `assets/meshes/*.vmesh`,
`assets/instruments/*.vinstr`, `assets/recordings/*.vrec` and `assets/samples/*.vsmp` to
`gen/<name>.h` before `make sim`, `make rp2350` and `make uvm2`, and adds `-Igen`. A
C project created before `.vinstr`, `.vrec` and `.vsmp` could be used from C lacks
their three `gen/%.h: %.<ext>` rules and wildcards: copy them from a new project's
Makefile (`asset_create` warns when they are missing).
Animations and levels include their sprites' headers, and a level also reads
`assets/vectors` and `assets/enemies`, so keep the same folder layout as VPy.
`examples/individual_tests_c/common.mk` does the same for the examples.

```c
#define VPY_SHORT_NAMES
#include <vpy.h>
#include "ship.h"      /* SHIP_vec */
#include "theme.h"     /* THEME_music */
#include "laser.h"     /* LASER_sfx */
#include "walk.h"      /* WALK_anim, WALK_anim_sprites */
#include "level1.h"    /* LEVEL1_level, LEVEL1_level_sprites, LEVEL1_enemies, LEVEL1_enemy_sprites */

static void setup(void) {
    LOAD_LEVEL(LEVEL1_level, LEVEL1_level_sprites);
    SPAWN_ENEMIES(LEVEL1_enemies, LEVEL1_enemy_sprites);
    PLAY_MUSIC(THEME_music);
}
static void loop(void) {
    SHOW_LEVEL();
    UPDATE_ENEMIES();
    DRAW_ENEMIES();
    DRAW_ANIM(WALK_anim, WALK_anim_sprites, 0, -40, 0);
    DRAW_VECTOR(SHIP_vec, 0, 0);
    if (J1_BUTTON_1()) PLAY_SFX(LASER_sfx);
}
int main(void) { vpy_run(setup, loop); return 0; }
```

Two names can share a header file, for example `ship.vec` and `ship.vmus`, which both
become `gen/ship.h`. Give each asset of a C project a different name.

Instruments, recordings and samples:

```c
#include "bell.h"     /* BELL_instr */
#include "intro.h"    /* INTRO_vrec */
#include "voice.h"    /* VOICE_smp  */

static void setup(void) { PLAY_SAMPLE(VOICE_smp); }
static void loop(void) {
    DRAW_RECORDING(INTRO_vrec, 0, 0, 128, SAMPLE_POS(15));   /* the video follows the audio */
    if (J1_BUTTON_1()) PLAY_NOTE(BELL_instr, 0, 60);         /* channel A, middle C */
}
```

`vpy_run()` advances notes each frame, as it does music and SFX. The C calls behave like
the VPy ones (the same bytes, the same runtime arithmetic), with one difference:
`DRAW_RECORDING` in C always draws at the recorded intensities, because `SET_INTENSITY`
doesn't override sprites in libvpy. Where a sample sounds is listed under
[`.vsmp`](#vsmp-audio-sample).

A `.vanim` must list its frames as named `.vec` files (`vec_refs`), because inline
`paths` are rejected by the C compile.

## Formats

All formats are JSON. Coordinates are integers on the Vectrex screen, which runs from
-128 to 127 on each axis with +Y up. Brightness (intensity) runs from 0 to 127. Each
asset's own `name` field should equal its file name. `asset_create` sets it for you.

### `.vec` (vector sprite)

```json
{"version":"1.0","name":"ship","canvas":{"width":256,"height":256,"origin":"center"},
 "layers":[{"name":"default","visible":true,"paths":[
   {"name":"hull","intensity":127,"closed":true,
    "points":[{"x":0,"y":12},{"x":-10,"y":-8},{"x":10,"y":-8}]}]}]}
```

- Points are relative to the sprite's centre. A path is a polyline of 2 or more points,
  and `closed: true` joins the last point to the first.
- A point can also carry these optional fields:
  - `z` (-127..127) makes the sprite a 3D wireframe for `DRAW_VECTOR_3D`. Angles there
    run 0-127 for a full turn.
  - `intensity` sets the brightness of the segment to that point.
- `collisionMesh` and `walkableAreas` (`[{"y","x_min","x_max","y2"?}]`) are optional.
  They make a sprite a platform in levels and are edited in the Vector Editor.
- For `DRAW_VECTOR_EX`, `mirror` is 0 for none, 1 to flip X, 2 to flip Y and 3 for both.
- `DRAW_VECTOR_ROT` draws the same sprite turned about its centre (the centre of its
  bounding box, the point `DRAW_VECTOR` places at `x, y`), so one `.vec` serves every
  heading of a ship or a rock. `angle` uses the unit of `sin`/`cos` and
  `DRAW_VECTOR_3D`: 0-127 is one full turn counter-clockwise (32 = 90 degrees), and any
  value is taken modulo 128. It needs no extra data: it reads the sprite's ordinary paths.

  ```python
  DRAW_VECTOR_ROT("ship", x, y, heading)            # each path at its own intensity
  DRAW_VECTOR_ROT("ship", x, y, heading, 1, 90)     # flipped left-right, then turned; intensity 90
  ```

  ```c
  DRAW_VECTOR_ROT(SHIP_vec, x, y, heading);                 /* vpy_draw_vector_rot */
  DRAW_VECTOR_ROT_EX(SHIP_vec, x, y, heading, 1, 90);       /* vpy_draw_vector_rot_ex */
  ```

  The optional `mirror` (same values as `DRAW_VECTOR_EX`) flips the sprite before it is
  turned. The optional `intensity` (> 0) replaces every path's own. In C, and in VPy on
  pitrex, it comes from libvpy (`vpy_draw_vector_rot` / `vpy_draw_vector_rot_ex`), which
  is newer than SDK v1.3.2: a pitrex build against an SDK without it stops with an error
  that names the SDK.
- Every point is a beam move, so keep point counts low.

### `.vmus` (music)

```json
{"version":"1.0","name":"theme","author":"","tempo":120,"ticksPerBeat":24,"totalTicks":96,
 "notes":[{"id":"n1","note":60,"start":0,"duration":24,"velocity":12,"channel":0}],
 "noise":[{"id":"h1","start":0,"duration":6,"period":8,"channels":2,"velocity":5}],
 "loopStart":0,"loopEnd":96}
```

- Every note and noise event needs an `id`.
- `note` is a MIDI number (60 is C4), `velocity` runs 0-15, and `channel` is 0, 1 or 2
  (PSG A, B or C).
- For noise events, `period` runs 0-31 with 0 the highest pitch. `channels` is a bitmask:
  1 for A, 2 for B, 4 for C.
- With `ticksPerBeat` 24, a quarter note is 24 ticks and a 4/4 bar is 96.
- Use channels A and B for music, because sound effects play on C. Notes on one channel
  must not overlap.

### `.vsfx` (sound effect)

```json
{"version":"1.0","name":"laser","category":"laser","duration_ms":150,
 "oscillator":{"frequency":880,"channel":0,"duty":50},
 "envelope":{"attack":0,"decay":0,"sustain":12,"release":100,"peak":15},
 "pitch":{"enabled":true,"start_mult":2.0,"end_mult":0.5,"curve":-2},
 "noise":{"enabled":false,"period":15,"volume":0,"decay_ms":100},
 "modulation":{"arpeggio":false,"arpeggio_notes":[],"arpeggio_speed":50,
               "vibrato":false,"vibrato_depth":0,"vibrato_speed":8}}
```

- `category` must be one of `custom`, `laser`, `explosion`, `powerup`, `hit`, `jump`,
  `blip` or `coin`. Any other value fails to load.
- In `envelope`, `attack`, `decay` and `release` are in ms. `sustain` and `peak` run
  0-15.
- `pitch` sweeps the frequency from `start_mult` to `end_mult`, with `curve` from -5 to 5.
- `noise.period` runs 0-31.
- The effect plays once on PSG channel C.
- More detail: [GUIDE_SFX_CREATION.md](GUIDE_SFX_CREATION.md).

### `.vanim` (animation)

```json
{"version":"1.0","name":"walk","loop":true,"base_refs":[],
 "frames":[{"index":0,"duration_ticks":8,"vec_refs":["walk_1"],"paths":[]},
           {"index":1,"duration_ticks":8,"vec_refs":["walk_2"],"paths":[]}]}
```

- `vec_refs` and `base_refs` name `.vec` files in `assets/vectors`, which must exist.
  `base_refs` are drawn on every frame.
- `duration_ticks` is in 50 Hz frames.
- A frame can also hold inline `paths` (`{"name","intensity","points"}`), but only VPy
  supports them.
- `DRAW_ANIM` advances the animation itself, so call it every frame. In VPy, the optional
  5th argument is the scale (`$7F` is normal size) and the 6th is the speed.

### `.vplay` (level)

```json
{"version":"2.0","type":"level","metadata":{"name":"level1"},
 "worldBounds":{"xMin":-128,"xMax":127,"yMin":-128,"yMax":127},
 "layers":{"background":[],"foreground":[],"gameplay":[
   {"id":"p1","type":"background","vectorName":"platform","layer":"gameplay",
    "x":0,"y":-60,"scale":1,"rotation":0,"collidable":true},
   {"id":"e1","type":"enemy","vectorName":"crawler","enemyType":"crawler","aiType":"patrol",
    "layer":"gameplay","x":40,"y":-40,"scale":1,"rotation":0}]}}
```

- `version` must be `"2.0"`.
- Each object needs `id`, `type`, `x`, `y`, `scale` and `rotation`. `type` is one of
  `background`, `obstacle`, `collectible`, `enemy`, `trigger` or `player_start`.
- `vectorName` names a `.vec` and `enemyType` names a `.venemy`. Both must exist.
- An enemy's `aiType` is one of `static`, `patrol`, `chase`, `flee` or `wander`, with
  `patrolWaypoints` or `walkable_areas` as needed.
- Objects can also set `collidable`, `physicsEnabled`, `physicsType` (`gravity` or
  `bounce`), `velocity` and `intensity`.
- `SET_CAMERA_X` and `SET_CAMERA_Y` scroll the world. Objects off screen are culled.
- More detail: [MANUAL.md](MANUAL.md) (Level System).

### `.venemy` (enemy type)

```json
{"version":"1.0","name":"crawler",
 "actions":[{"name":"walk","sprite":"assets/vectors/crawler.vec","loop":true}],
 "stats":{"hp":1,"speed":1,"action_duration":180},
 "behavior":{"type":"patrol","patrol":{"waypoints":[],"loop":true,"mirrorOnPatrol":true,
                                       "defaultFacing":"right","patrolAction":""}}}
```

- `sprite` is a path from the project root to a `.vec` or `.vanim`, and the file must
  exist.
- The sprite drawn is the one for `patrolAction`, then `idle`, then the first action.
- An optional `state_machine` (Enemy Editor) handles the events that
  `ENEMY_FIRE_EVENT(i, "name")` fires.
- An enemy only appears in a game when a level places it. You can access spawned enemies
  with `GET_ENEMY_X(i)`, `GET_ENEMY_Y(i)`, `GET_ENEMY_ACTIVE(i)`, `KILL_ENEMY(i)` and
  `SET_ENEMY_X(i, x)`.

### `.vinstr` (instrument)

```json
{"version":"1.0","name":"piano","duration_frames":12,"volume":12,"arpeggio_count":0,
 "arpeggio_speed_frames":2,"arpeggio_intervals":[0,0,0,0],"noise_enabled":false,
 "noise_period":15,"pitch_sweep_delta":0,"pitch_sweep_duration_frames":0}
```

An instrument is a timbre without a pitch. `PLAY_NOTE("piano", channel, note)` plays it
on a PSG channel (0-2) at a MIDI note (24-107). In C, the call is
`PLAY_NOTE(PIANO_instr, channel, note)`.

- The note lasts `duration_frames` (0 holds it until the next note on that channel) and
  cycles through the first `arpeggio_count` intervals every `arpeggio_speed_frames`.
- `noise_*` and `pitch_sweep_*` are stored but not played by the rp2350, uvm2, pitrex or
  C runtimes.

### `.vrec` (vector recording)

```json
{"version":"1.0","name":"clip","fps":15,
 "frames":[{"segments":[{"x0":-20,"y0":-20,"x1":20,"y1":-20,"i":100}]}]}
```

- Recordings are usually captured with the Emulator panel's recorder or converted from
  video by the Vector Movie editor (`tools/video2vrec`).
- `DRAW_RECORDING("clip", x, y, scale, frame)` takes `scale` with 128 as 100%, and wraps
  `frame` with `frame % frame_count`. In C it is `DRAW_RECORDING(CLIP_vrec, x, y, scale,
  frame)`, and `vpy_recording_frames(CLIP_vrec)` returns the frame count.
- Every segment is drawn every frame, so keep frames small.

### `.vsmp` (audio sample)

```json
{"version":"1.0","name":"voice","sampleRate":8000,"bits":4,"numSamples":8,"data":"iIiIiA=="}
```

- `data` is base64 of packed 4-bit samples, 2 per byte with the low nibble first.
- Samples are converted from audio with `tools/audio2vsmp` or the Vector Movie editor's
  import.
- `PLAY_SAMPLE("voice")` streams the sample to the PSG volume DAC. In C it is
  `PLAY_SAMPLE(VOICE_smp)`. A new call restarts the sample.
- `SAMPLE_POS(fps)` returns the audio-synced frame number, which you pass to
  `DRAW_RECORDING`. It is 0 when no sample is playing, except on pitrex hardware.
- Where a sample sounds:

  | Target | VPy | C (libvpy) |
  |--------|-----|------------|
  | rp2350 cartridge | plays (BIOS sample player) | plays (BIOS sample player, BIOS table version 2 or later) |
  | WASM simulator (C projects) | — | plays (Web Audio) |
  | IDE RP2350 emulator | plays (Web Audio) | plays (Web Audio) |
  | pitrex hardware | silent; `SAMPLE_POS` counts frames from its first call | not a C target |
  | uvm2 | builds; both calls are no-ops | builds; `PLAY_SAMPLE` is a no-op and `SAMPLE_POS` returns 0 |
  | m6809 | the build fails | — |

  On uvm2 the sample data is still linked into the `.um2`, and a large one overflows the
  image ([UVM2_TARGET.md](UVM2_TARGET.md)). Keep samples out of uvm2 builds.

### `.vmesh` (3D surface mesh, C only)

```json
{"name":"cube","hard":45,
 "vertices":[{"x":-500,"y":-500,"z":-500},{"x":500,"y":-500,"z":-500}, ...],
 "faces":[[0,3,2,1],[4,5,6,7], ...]}
```

- A mesh is either listed outright (`vertices` and `faces`) or lofted from `sections`:
  `[{"z","points":[...]}]`, or `{"z","vec":"../vectors/x.vec","path":"name"}` to take
  the ring from a `.vec`. Every section needs the same point count.
- `hard` is the crease angle in degrees. `open: true` makes a plate instead of a solid.
- The IDE's Mesh Editor (File > New > 3D Mesh) edits the explicit form. It checks the file
  the way the compiler does, and it can show what vpy3d draws from any angle. It only
  previews a lofted file, until you convert it to vertices and faces.
- Load and draw it with vpy3d:

```c
#include <vpy3d.h>
#include "cube.h"                         /* CUBE_vmesh */
static vpy_mesh cube;
/* setup():  */ vpy3d_load_mesh(&cube, CUBE_vmesh); vpy3d_look_at(0, 0, -3000, 0, 0, 0, 0, 1, 0);
/* loop():   */ vpy_xf place = vpy3d_rot_y(angle); vpy3d_draw_mesh(&cube, &place, 127);
```

Add `$(VPY_C_SDK)/vpy3d.c` to `SRCS` in the Makefile. VPy has no `.vmesh` support. For
3D in VPy, use a `.vec` with `z` and `DRAW_VECTOR_3D`.

## Known gaps

- On m6809, `PLAY_SAMPLE` and `SAMPLE_POS` don't build ("Undefined symbol").
- On m6809, `STOP_MUSIC()` only builds when the program also calls `PLAY_MUSIC`.
- `.vsmp` doesn't play on uvm2, from VPy or C.
- `.vmesh` has no VPy support.
