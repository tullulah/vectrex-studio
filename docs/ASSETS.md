# Assets

Vectrex Studio is asset-driven. Sprites, music, sound effects, animations, levels,
enemies, instruments, recordings, samples, 3D meshes and 3D scenes are JSON files under the
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
| `.vmesh` | 3D surface mesh | `assets/meshes/` (any folder) | Mesh Editor | `LOAD_MESH("n")`, `DRAW_MESH("n", xf, br)` | `vpy3d_load_mesh(&m, N_vmesh)` + `vpy3d_draw_mesh` | VPy: uvm2; C: sim, rp2350, uvm2 |
| `.vscene` | 3D set made of `.vmesh` pieces | `assets/scenes/` | Scene Editor | `LOAD_SCENE("n")`, `DRAW_SCENE("n", x, y, z, br)` | `vpy3d_load_scene(&s, N_vscene, N_vscene_meshes)` + `vpy3d_draw_scene` | VPy: uvm2; C: sim, rp2350, uvm2 (SDK v1.3.5+) |
| `.vclip` | 3D poses, animation clips and sets on a skeleton | `assets/clips/` | 3D Animation editor | `import n` → `n.T_POSES[n.POSE_X][n.JOINT_Y]`, `n.T_KEYS`, `n.T_SET_CLIPS`… (constant tables) | `#include "n.h"` → `N_T_POSES[N_POSE_X][N_JOINT_Y]`… | VPy: uvm2 (the only target tried); C: sim, rp2350, uvm2 |
| `.vskel` | 3D skeleton: bones, joints, sockets, characters | `assets/skeletons/` | 3D Animation editor | `import n` → `n.T_BONES`, `n.T_TURNS`, `n.T_BONE_MESHES`, `n.T_MESHES`… (constant tables) | `#include "n.h"` → `N_T_BONES`… | VPy: uvm2 (`T_MESHES` needs meshes); C: sim, rp2350, uvm2 |

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
`assets/scenes/*.vscene`, `assets/clips/*.vclip`, `assets/skeletons/*.vskel`, `assets/instruments/*.vinstr`, `assets/recordings/*.vrec` and `assets/samples/*.vsmp` to
`gen/<name>.h` before `make sim`, `make rp2350` and `make uvm2`, and adds `-Igen`. A
C project created before `.vinstr`, `.vrec` and `.vsmp` could be used from C lacks
their three `gen/%.h: %.<ext>` rules and wildcards: copy them from a new project's
Makefile (`asset_create` warns when they are missing).
Animations and levels include their sprites' headers, and a level also reads
`assets/vectors` and `assets/enemies`, so keep the same folder layout as VPy. A scene
includes the headers of its meshes. A C project created before `.vscene` lacks its rule:
copy `SCENE_SRCS`, `MESH_HDRS`, `vpath %.vscene`, the `gen/%.h: %.vscene` rule and
`$(call hdr,$(SCENE_SRCS)): $(MESH_HDRS)` from a new project's Makefile.
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

### `.vmesh` (3D surface mesh)

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
  previews a lofted file's faces, until you convert it to vertices and faces.
- The editor also draws and edits scenery: the Line tool (L) places points on the view plane
  (Enter or a double-click ends the line), the Occluder tool (O) drags a box, and "Box occluder
  from selection" (B) wraps the selection. Its preview does not cut lines by occluders or
  show fog.
- Load and draw it with vpy3d:

```c
#include <vpy3d.h>
#include "cube.h"                         /* CUBE_vmesh */
static vpy_mesh cube;
/* setup():  */ vpy3d_load_mesh(&cube, CUBE_vmesh); vpy3d_look_at(0, 0, -3000, 0, 0, 0, 0, 1, 0);
/* loop():   */ vpy_xf place = vpy3d_rot_y(angle); vpy3d_draw_mesh(&cube, &place, 127);
```

Add `$(VPY_C_SDK)/vpy3d.c` to `SRCS` in the Makefile.

From VPy (uvm2 target), the same mesh is a name and a transform, a global `i32` array of 12
([MANUAL.md](MANUAL.md#3d-uvm2) lists every 3D builtin):

```python
place: i32 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
def main():
    LOAD_MESH("cube")
    CAMERA_LOOK_AT(0, 0, -3000, 0, 0, 0)
def loop():
    XF_ROT_Y(place, angle)
    DRAW_MESH("cube", place, 127)
```

vpy_cli compiles the SDK's `vpy3d.c` into the `.um2` when the program uses a 3D builtin. The
pool sizes (`VPY3D_POOL_V` &c.) go in the project's `[uvm2] defs`. On m6809, rp2350 and
pitrex the 3D builtins are a compile error; there, a `.vec` with `z` and `DRAW_VECTOR_3D`
gives simple 3D.

#### Scenery: `lines` and `occluders` (SDK v1.3.5 or later)

A `.vmesh` can also hold a piece of scenery (a room, a hangar bay, a corridor section),
with or without faces:

```json
{"name":"throne_room",
 "lines":[{"points":[{"x":-3000,"y":280,"z":1800},{"x":3000,"y":280,"z":1800}],"br":70},
          {"points":[ ...16 points... ],"br":90,"closed":true}],
 "occluders":[{"points":[ ...3 to 8 corners of a convex solid... ]}]}
```

- `lines` are polylines of 2 to 255 points. They are not edges of a face, and they are never
  culled. `br` (1–100, default 100) is a percent of the brightness passed to
  `vpy3d_draw_mesh`: draw the scenery at 100 and each `br` is its absolute brightness.
  `closed: true` joins the last point to the first.
- `occluders` are convex solids given by their corners (3 to 8). They are never drawn. Once
  the mesh is drawn they go into the occluder table, so they hide whatever is drawn **after**
  it, never the mesh's own lines. Draw near to far, as with `vpy3d_occl_add`.
- A line always goes through the occluders already added, the way `vpy3d_occl_line` does.
- Scenery points may be 32-bit (±1,000,000), so a room fits in model units. Vertices keep
  the 16-bit range. The compiler stores a line or occluder whose points all fit in 16 bits
  at half the size; that matters on uvm2, where the whole game runs from SRAM.
- `vpy3d_set_scenery_fog(full_until, gone_at)` fades each line segment by the camera depth
  of its middle, as `vpy3d_fog` does, and drops a segment faded below brightness 4. `0, 0`
  turns it off (the default). A line with `"fog": false` keeps its brightness.
- A file without `lines` or `occluders` compiles to a version-1 image, unchanged. A file
  with them compiles to version 2, which needs SDK v1.3.5. A scenery-only mesh uses no vpy3d
  pool space; its data is read in place from the compiled array.

```c
#include "throne_room.h"                  /* THRONE_ROOM_vmesh */
static vpy_mesh room;
/* setup():  */ vpy3d_load_mesh(&room, THRONE_ROOM_vmesh);
/* loop():   */ vpy_xf at = vpy3d_translate(0, 0, 6000); vpy3d_draw_mesh(&room, &at, 100);
```

### `.vscene` (3D set, SDK v1.3.5 or later)

A scene arranges `.vmesh` pieces over time. It says where each piece stands, how it
moves as the player travels, how often it repeats, and which pieces the game switches on
and off: the ribs of a tunnel coming at you every 2000 units, two mountain ranges sliding
by at different speeds, the stripes of a floor. Each frame the game passes one position,
`pos` (how far it has gone along x, y and z), and the scene places every piece from it.

```json
{"name":"ds_tunnel",
 "fog":{"full":3000,"gone":17500},
 "groups":["alarm"],
 "items":[
   {"name":"ribs","mesh":"tunnel_rib","at":{"z":600},"follow":{"z":-1},
    "repeat":{"axis":"z","step":2000,"count":9},"fog":"whole"},
   {"name":"wall panels","mesh":["tunnel_panels_high","tunnel_panels_low"],"at":{"z":600},
    "follow":{"z":-1},"repeat":{"axis":"z","step":2000,"count":9},"window":{"max":10999}},
   {"name":"long edges","mesh":"tunnel_edges","fog":false},
   {"name":"red lights","mesh":"alarm_lights","group":"alarm"}]}
```

- `mesh` names a `.vmesh` in `assets/meshes/` (without the extension). A scene uses at most
  16 different meshes.
- `at` is where the piece stands (x, y, z; a missing axis is 0).
- `follow` is how far the piece moves per unit of `pos`, per axis. With `{"z": -1}` it
  comes at you as you advance. With `{"x": 0.9167}`, a far range slides by almost as fast as
  you turn, so it seems to move only a little. Fractions are kept to 1/65536.
- `repeat` makes `count` copies `step` apart along `axis`. The copies wrap with the
  movement, so there are always `count` of them, the first within one `step` past `at`.
  With a list of meshes the copies take turns: copy n uses mesh n mod the list's length,
  counted along the whole run, so the pattern stays put as it scrolls.
- `window` draws a copy only while its z in the world (after `place`) is within `min`..`max`.
  Use it for the near bays only, or to drop what is behind the camera.
- `br` is a percent (1–100, default 100) of the brightness passed to `vpy3d_draw_scene`.
- `fog` controls how the scene's `fog` fades the piece. `true` (the default) fades each line
  segment by the depth of its middle. `"whole"` fades each copy as one, by the depth of its
  `at`, and skips a copy faded below brightness 4; this fades its faces too. `false` leaves
  the piece unfaded. With `true`, faces are not faded, only scenery lines.
- `group` draws the piece only while the game sets that group's bit (bit n = the n-th name
  in `groups`). `"!name"` works the other way round. A scene can have up to 32 groups.
- Items are drawn in the order listed, each repeat from `at` outwards. A piece's occluders
  hide only what is drawn after it, so list the near pieces first. When a frame has more
  strokes than the stroke buffer holds, the strokes drawn last are dropped, which is one
  more reason to put the far pieces last.

```c
#include <vpy3d.h>
#include "ds_tunnel.h"                  /* DS_TUNNEL_vscene, DS_TUNNEL_vscene_meshes */
static vpy_scene tunnel;
/* setup():  */ vpy3d_load_scene(&tunnel, DS_TUNNEL_vscene, DS_TUNNEL_vscene_meshes);
/* loop():   */ int32_t pos[3] = { 0, 0, dist };
                vpy3d_draw_scene(&tunnel, 0, pos, alarm ? 1 : 0, 90);
```

`vpy3d_draw_scene(&s, place, pos, groups, br)` takes `place` (0 for none) to put the whole
scene in the world after its pieces have moved. Each copy goes through `vpy3d_draw_mesh`.
The scene's fog applies to its own pieces only, and the game's `vpy3d_set_scenery_fog` is
back afterwards.

A scenery-only mesh in a scene uses no RAM: it is read in place from the compiled array at
every draw. A mesh with faces is built into the vpy3d pools once and kept in one of
`VPY3D_SCENE_SOLIDS` slots (default 8) that all scenes share. Loading the same image again
reuses its slot. Load scenes with solid pieces at start-up, before any `vpy3d_pool_mark`.
`vpy3d_load_scene` returns 0 when the image or a mesh is bad, or when the slots are full,
and `vpy3d_error()` says which. A `vpy_scene` itself is 24 bytes on the cartridges.

### `.vskel` (3D skeleton)

A skeleton is a tree of rigid bones, the model of vpybone (`vpy-c/vpybone.h`). Each bone
hangs from its parent's joint at an offset and carries one `.vmesh`, so nothing stretches.
Bones are not posed directly. A small set of named **joints**, each a single angle, turns
them: a shoulder has a pitch and a roll, an elbow one angle. Poses and clips
([`.vclip`](#vclip-3d-poses-and-clips)) store joint angles, so a pose made for one character
fits every character on the same skeleton. A rigid object is a skeleton with one bone.

```json
{
  "version": 1,
  "angle_unit": 4096,
  "joints": [ { "name": "twist" }, { "name": "lean" }, { "name": "elbow_r" } ],
  "bones": [
    { "name": "hips",  "parent": null,   "offset": [0, 950, 0], "mesh": "tunic_hips", "rotate": [] },
    { "name": "torso", "parent": "hips", "offset": [0, 0, 0],   "mesh": "jedi_torso",
      "rotate": [ { "joint": "twist", "axis": "y" }, { "joint": "lean", "axis": "x" } ] },
    { "name": "head",  "parent": "torso", "offset": [0, 680, 0], "mesh": "luke_head",
      "rotate": [ { "joint": "twist", "axis": "y", "mul": -1, "div": 2 } ] }
  ],
  "variants": {
    "vader": { "scale": 282, "meshes": { "head": "vader_helmet", "torso": "vader_torso" } },
    "yoda":  { "scale": 72,  "meshes": { "head": "yoda_head" }, "offsets": { "head": [0, 640, 0] } }
  }
}
```

- `angle_unit`: angles per turn. Every angle in the skeleton and its clips is a whole
  number in this unit (4096 is libvpy's `VPY_Q14_TURN`), so files round-trip exactly.
- `joints`: the joint names, in order. That order is the order of a pose's angles when a
  program stores a pose as an array. A joint may have `min` and `max`: the range of the
  editor's slider (code never sees them).
- `bones`: parents come before their children. `offset` is the joint's position in the
  parent's frame (x right, y up, z forward). `mesh` is a `.vmesh` name, or `null` for a bone
  that only carries others.
- `rotate`: the bone's local rotation, a product of single-axis turns in the order listed
  (the first is outermost: `[y, x]` is `qmul(qy, qx)`). Each turn's angle is
  `joint * mul / div + add`, in integer arithmetic truncating toward zero (as in C).
  `mul` and `div` default to 1, `add` to 0, and a turn without `joint` is the constant `add`.
  An empty list leaves the bone unturned.
- The axes, as seen from the bone's frame: a positive **x** turn swings a limb that hangs
  down (−y) forward, towards +z. A positive **y** turn turns +z towards +x. A positive **z**
  turn turns +x towards +y. vpybone's `vpyb_quat_axis` has the opposite sign about x, so a
  program negates x angles when it builds the quaternions (Return of the Jedi measures the
  signs at boot: `fight_probe`).
- `sockets` (optional): named segments fixed to a bone, from `from` to `to` in the bone's
  frame: what a hand holds (a blade, a gun), where a shot leaves. Unreal calls them sockets.
  The editor draws them; the game finds them in the same place.
- `variants`: the characters that share the skeleton. `scale` is Q8 (256 = as modelled) and
  scales the whole character: every offset (`offset * scale / 256`, truncating), the meshes
  and the sockets. `meshes` and `offsets` replace a bone's mesh or offset (`null`: no mesh).
  `bones` adds bones after the shared ones (Grievous's second pair of arms), `rotate`
  replaces a bone's rotation, and `sockets` replaces the skeleton's sockets. A bone that two
  variants add comes at the same place in both and hangs from the same parent.

**What code reads.** As a `.vclip`, the compiler turns a skeleton into constant tables: a
VPy program writes `import humanoid` (the compiler finds `assets/skeletons/**/humanoid.vskel`;
a `.vclip` and a `.vskel` of one name are an error), a C program includes `gen/humanoid.h`
(`vpy_cli compile-asset humanoid.vskel --format c`; a new C project's Makefile has the rule):

| Name | What |
|---|---|
| `N_JOINTS`, `JOINT_<j>` | the joints, in order |
| `N_BONES`, `BONE_<b>` | every bone: the shared ones, then the variants' own |
| `N_VARIANTS`, `VARIANT_<v>`, `T_VARIANTS[N_VARIANTS][2]` | a variant's scale (Q8) and how many bones it has |
| `T_BONES[N_BONES][5]` | parent (-1: the root), offset x y z as modelled, turn list (row of `T_ROTS`) |
| `N_ROTS`, `T_ROTS[N_ROTS][2]` | a turn list: first row of `T_TURNS`, how many (0: unturned) |
| `N_TURNS`, `T_TURNS[N_TURNS][5]` | axis (0 x, 1 y, 2 z), joint (-1: none), mul, div, add |
| `N_VARIANT_BONES`, `T_VARIANT_BONES[..][6]` | variant, bone, offset x y z, turn list: where a variant's bone differs from `T_BONES` |
| `N_MESHES`, `MESH_<m>`, `T_BONE_MESHES[N_VARIANTS][N_BONES]` | each variant's mesh on each bone (-1: none) |
| `T_MESHES[N_MESHES]` | VPy only: each mesh's `MESH("name")` slot |
| `N_SOCKETS`, `SOCKET_<s>`, `T_VARIANT_SOCKETS[N_VARIANTS][N_SOCKETS]` | a variant's socket (row of `T_SOCKETS`, -1: none) |
| `T_SOCKETS[..][7]` | bone, from x y z, to x y z, in the bone's frame as modelled |

Variants and meshes are numbered alphabetically, bones in the file's order, sockets in the
order first met (the skeleton's, then each variant's). A file without variants has one,
`default`. Every table is there: one with nothing in it holds a single row that is never
read (its count is 0), so code needs no conditionals. Offsets are as modelled: a program
scales them by the variant's scale (`offset * scale / 256`, truncating) and places meshes and
sockets with the bone's frame scaled the same way. In C a mesh is an object the program
loads, so it supplies one table, `MESH_<m>` → its `vpy_mesh`; `<N>_MESH_NAMES` lists the
names. VPy gets the slots in `T_MESHES`.

A program builds a character with one `vpyb_add` / `BONE_ADD` per bone, and turns it each
frame: for every bone, the product of its turns, each `joint * mul / div + add` (the first
turn outermost, the same truncation). Return of the Jedi does both in a few lines (`skel_build`,
`skel_turn` and `fsocket` in its `main.c`; `skel.build`, `skel.turn` and `fighter.socket` in
the VPy port), then turns a few bones itself for what the format does not hold: Grievous's
hands spinning, the cast sitting down.

### `.vclip` (3D poses and clips)

A clip library for one skeleton: named **poses** (one angle per joint), **clips** that move
through poses over frames, and **sets** that say which clip a character plays for each
role. The editor and the compiler know nothing about what a role, a property or a mark
means. The game reads them, so the same format serves a sword fight, a door or a walk.

```json
{
  "version": 1,
  "skeleton": "fighter",
  "poses": {
    "maul_guard":    { "twist": 227, "lean": 136, "elbow_r": 796 },
    "maul_cut_wind": { "twist": -341, "lean": 56, "elbow_r": 455 }
  },
  "clips": {
    "maul_slash": {
      "keys": [ { "frame": 0, "pose": "maul_guard" }, { "frame": 4, "pose": "maul_cut_wind" },
                { "frame": 8, "pose": "maul_cut_strike" }, { "frame": 12, "pose": "maul_guard" } ],
      "loop": false,
      "props": { "damage": 1, "lunge": 60 },
      "marks": [ { "frame": 4, "name": "strike" }, { "frame": 8, "name": "recover" } ]
    }
  },
  "sets": {
    "maul": { "poses": { "guard": "maul_guard" }, "clips": { "slash": "maul_slash" },
              "props": { "stance": 90, "twirl": 1 } }
  }
}
```

- `skeleton`: the `.vskel` name. A pose names every joint of it (the example shows three), in its `angle_unit`.
- `keys`: poses at frames, in rising frame order. Between keys the joints move from one
  pose to the next; how (straight, or chased by springs as Return of the Jedi does) is the
  program's choice. `loop` wraps the last key back to the first.
- `props`: whole numbers the game reads off the clip (damage, how far a blow lunges).
- `marks`: named instants on the clip's timeline (`value` optional): where a blow lands,
  where a footstep falls. Unreal calls these notifies; Unity calls them animation events.
- `sets`: per character or style, the clip for each role and the pose for each named
  stance, plus that style's own numbers. Two sets may share clips.

**What code reads.** The compiler turns a library into constant tables: a VPy program writes
`import fighters` (no `fighters.vpy` needed: the compiler finds
`assets/clips/**/fighters.vclip` and its skeleton), a C program includes `gen/fighters.h`
(`vpy_cli compile-asset fighters.vclip --format c`; a new C project's Makefile has the rule).
The names are the same in both, with the library's prefix in C (`FIGHTERS_POSE_GUARD`):

| Name | What |
|---|---|
| `N_JOINTS`, `JOINT_<j>` | the skeleton's joints, in its order: a pose's columns |
| `N_POSES`, `POSE_<p>`, `T_POSES[N_POSES][N_JOINTS]` | every pose's angles |
| `N_CLIPS`, `CLIP_<c>`, `T_CLIPS[N_CLIPS][4]` | a clip's first key, key count, length in frames, loop |
| `N_KEYS`, `T_KEYS[N_KEYS][2]` | frame and pose of every clip's keys, one clip after another |
| `N_PROPS`, `PROP_<k>`, `T_CLIP_PROPS[N_CLIPS][N_PROPS]` | the clips' properties (0 if absent) |
| `N_MARKS`, `MARK_<m>`, `N_MARK_ROWS`, `T_MARKS[..][4]` | every mark: clip, frame, mark, value |
| `N_SETS`, `SET_<s>` | the sets |
| `N_STANCES`, `STANCE_<r>`, `T_SET_POSES[N_SETS][N_STANCES]` | a set's pose per stance (-1 if absent) |
| `N_ROLES`, `ROLE_<r>`, `T_SET_CLIPS[N_SETS][N_ROLES]` | a set's clip per role (-1 if absent) |
| `N_SPROPS`, `SPROP_<k>`, `T_SET_PROPS[N_SETS][N_SPROPS]` | a set's properties (0 if absent) |

Names are upper-cased (`maul_guard` → `POSE_MAUL_GUARD`). Read everything by name: poses,
clips and sets are numbered alphabetically, so adding one renumbers the rest. In C each
array has the narrowest type its values need (`int8_t`, `int16_t` or `int32_t`; `T_POSES`
at least `int16_t`, so a row reads as one 16-bit angle per joint); index the arrays rather
than keeping pointers of a fixed type. A table with no rows or columns is left out. Return
of the Jedi reads its duels this way (`move_of` in its `main.c`, `fighter.mv` in the VPy
port): a blow is a clip of four keys (guard, wind-up, strike, guard) plus `damage` and
`lunge`.

## Known gaps

- On m6809, `PLAY_SAMPLE` and `SAMPLE_POS` don't build ("Undefined symbol").
- On m6809, `STOP_MUSIC()` only builds when the program also calls `PLAY_MUSIC`.
- `.vsmp` doesn't play on uvm2, from VPy or C.
- `.vmesh` and `.vscene` work from VPy on uvm2 only (not m6809, rp2350 or pitrex).
