// The IDE's asset system as the MCP tools see it: ONE catalog of every asset type
// (format, folder, IDE editor, how VPy and C code use it, which targets), plus the
// project scan behind assets_list and the validation behind asset_create.
//
// docs/ASSETS.md is the human-readable copy of this catalog; the MCP test harness
// (ide/mcp-server/test/run-tests.js) checks that the two agree and that every
// example below compiles with `vpy_cli check-asset`.
//
// Where the facts come from:
//   folders      buildtools/vpy_codegen/src/m6809/assets.rs discover_assets (VPy: the
//                compiler finds assets BY FOLDER, [resources] in .vpyproj is not read
//                for this) and the C template Makefile (projectTemplates.ts)
//   VPy calls    buildtools/vpy_codegen/src/m6809/builtins.rs (+ arm/, pitrex/)
//   C calls      the SDK's vpy-c/include/vpy.h and vpy3d.h; headers from
//                `vpy_cli compile-asset <file> --format c` (buildtools/vpy_cli)
//   targets      measured: `vpy_cli build --target <t>` of a project using each call
//
// Pure Node (no electron import): the test harness loads it directly.

import { promises as fs, existsSync } from 'fs';
import * as os from 'os';
import * as path from 'path';
import { spawn } from 'child_process';

export type AssetType = 'vec' | 'vmus' | 'vsfx' | 'vanim' | 'vplay' | 'venemy' | 'vinstr' | 'vrec' | 'vsmp' | 'vmesh';
export type ProjectLang = 'vpy' | 'c';

export interface AssetSpec {
  type: AssetType;
  ext: string;
  title: string;
  /** Folder relative to the project root (same for VPy and the C template). */
  dir: string;
  /** IDE editor that opens it. */
  editor: string;
  /** VPy: how code uses it ('' = not usable from VPy). */
  vpy: { usable: boolean; usage: (name: string, meta?: AssetMeta) => string; note?: string };
  /** C (libvpy): how code uses it. */
  c: { usable: boolean; usage: (name: string, meta?: AssetMeta) => string; note?: string };
  /** VPy targets where a project using it builds (measured). */
  targets: string;
  /** Concise format reference. */
  format: string;
  /** Minimal valid example (JSON value) for an asset named `name`. */
  example: (name: string) => any;
  /** Where the asset's own name lives in the JSON (normalised to the file name). */
  nameField: 'name' | 'metadata.name';
}

/** Per-file facts the usage snippet depends on. */
export interface AssetMeta { is3d?: boolean; hasEnemies?: boolean; inlinePaths?: boolean }

/** C symbol base for an asset name: what `vpy_cli compile-asset` derives from the file stem. */
export function cSymbol(name: string): string {
  return name.toUpperCase().replace(/[-. ]/g, '_');
}

const cInc = (name: string) => `#include "${name}.h"`;

export const ASSET_SPECS: AssetSpec[] = [
  {
    type: 'vec', ext: '.vec', title: 'Vector sprite', dir: 'assets/vectors', editor: 'Vector Editor',
    nameField: 'name',
    vpy: {
      usable: true,
      usage: (n, m) => m?.is3d
        ? `DRAW_VECTOR_3D("${n}", ax, ay, az, x, y)   # angles 0-127 = full turn; also DRAW_VECTOR("${n}", x, y)`
        : `DRAW_VECTOR("${n}", x, y)   # or DRAW_VECTOR_EX("${n}", x, y, mirror, intensity); turned: DRAW_VECTOR_ROT("${n}", x, y, angle[, mirror[, intensity]]) (angle 0-127 = full turn CCW)`,
    },
    c: {
      usable: true,
      usage: (n) => `${cInc(n)}\nDRAW_VECTOR(${cSymbol(n)}_vec, x, y);   /* or DRAW_VECTOR_EX(${cSymbol(n)}_vec, x, y, mirror, intensity); turned: DRAW_VECTOR_ROT(${cSymbol(n)}_vec, x, y, angle) / DRAW_VECTOR_ROT_EX(..., angle, mirror, intensity), angle 0-127 = full turn CCW */`,
    },
    targets: 'm6809, rp2350, uvm2, pitrex; C: sim, rp2350, uvm2',
    format:
`JSON. {"version":"1.0","name":<file name>,"canvas":{"width":256,"height":256,"origin":"center"},"layers":[{"name","visible":true,"paths":[{"name","intensity":0-127,"closed":bool,"points":[{"x","y"}...]}]}]}
- Coordinates are integers relative to the sprite's centre, -127..127, +Y up. A path is a polyline: 2+ points; closed=true joins the last point to the first.
- Optional per point: "z" (-127..127; makes it a 3D wireframe for DRAW_VECTOR_3D), "intensity" (override for that segment).
- Optional: "collisionMesh":{"segments":[...]}, "walkableAreas":[{"y","x_min","x_max","y2"?}] (platforms in levels; edited in the Vector Editor).
- Fewer points = fewer beam moves = faster. mirror: 0 none, 1 flip X, 2 flip Y, 3 both.`,
    example: (n) => ({
      version: '1.0', name: n, canvas: { width: 256, height: 256, origin: 'center' },
      layers: [{ name: 'default', visible: true, paths: [
        { name: 'hull', intensity: 127, closed: true, points: [{ x: 0, y: 12 }, { x: -10, y: -8 }, { x: 10, y: -8 }] },
      ] }],
    }),
  },
  {
    type: 'vmus', ext: '.vmus', title: 'Music', dir: 'assets/music', editor: 'Music Editor',
    nameField: 'name',
    vpy: { usable: true, usage: (n) => `PLAY_MUSIC("${n}")   # once (e.g. in main()); loops; STOP_MUSIC() stops it` },
    c: { usable: true, usage: (n) => `${cInc(n)}\nPLAY_MUSIC(${cSymbol(n)}_music);   /* STOP_MUSIC() stops it */` },
    targets: 'm6809, rp2350, uvm2, pitrex; C: sim, rp2350, uvm2',
    format:
`JSON. {"version":"1.0","name","author":"","tempo":BPM,"ticksPerBeat":24,"totalTicks":N,"notes":[...],"noise":[...],"loopStart":tick,"loopEnd":tick}
- note: {"id":unique string,"note":MIDI (60 = C4),"start":tick,"duration":ticks,"velocity":0-15,"channel":0|1|2}
- noise: {"id","start","duration","period":0-31 (0 = highest),"channels":bitmask 1=A 2=B 4=C,"velocity":0-15}
- "id" is required on every note and noise event. With ticksPerBeat 24: quarter = 24, eighth = 12; a 4/4 bar = 96.
- PSG channels A/B for music; channel C (2) is where SFX play. Notes on one channel must not overlap. The music engine is updated automatically.`,
    example: (n) => ({
      version: '1.0', name: n, author: '', tempo: 120, ticksPerBeat: 24, totalTicks: 96,
      notes: [
        { id: 'n1', note: 60, start: 0, duration: 24, velocity: 12, channel: 0 },
        { id: 'n2', note: 64, start: 24, duration: 24, velocity: 12, channel: 0 },
        { id: 'n3', note: 67, start: 48, duration: 48, velocity: 12, channel: 0 },
        { id: 'b1', note: 48, start: 0, duration: 96, velocity: 10, channel: 1 },
      ],
      noise: [{ id: 'h1', start: 0, duration: 6, period: 8, channels: 2, velocity: 5 }],
      loopStart: 0, loopEnd: 96,
    }),
  },
  {
    type: 'vsfx', ext: '.vsfx', title: 'Sound effect', dir: 'assets/sfx', editor: 'SFX Editor',
    nameField: 'name',
    vpy: { usable: true, usage: (n) => `PLAY_SFX("${n}")   # one-shot on PSG channel C` },
    c: { usable: true, usage: (n) => `${cInc(n)}\nPLAY_SFX(${cSymbol(n)}_sfx);` },
    targets: 'm6809, rp2350, uvm2, pitrex; C: sim, rp2350, uvm2',
    format:
`JSON, parametric (SFXR-style). {"version":"1.0","name","category","duration_ms",
 "oscillator":{"frequency":Hz,"channel":0,"duty":0-100},
 "envelope":{"attack":ms,"decay":ms,"sustain":0-15,"release":ms,"peak":1-15},
 "pitch":{"enabled":bool,"start_mult":0.1-4,"end_mult":0.1-4,"curve":-5..5},
 "noise":{"enabled":bool,"period":0-31,"volume":0-15,"decay_ms":ms},
 "modulation":{"arpeggio":bool,"arpeggio_notes":[semitones],"arpeggio_speed":ms,"vibrato":bool,"vibrato_depth":0-100,"vibrato_speed":1-20}}
- "category" must be one of: custom, laser, explosion, powerup, hit, jump, blip, coin.
- Laser: high frequency, pitch down (start 2.0 -> end 0.5). Explosion: low frequency + noise. Coin: arpeggio [0,12].`,
    example: (n) => ({
      version: '1.0', name: n, category: 'laser', duration_ms: 150,
      oscillator: { frequency: 880, channel: 0, duty: 50 },
      envelope: { attack: 0, decay: 0, sustain: 12, release: 100, peak: 15 },
      pitch: { enabled: true, start_mult: 2.0, end_mult: 0.5, curve: -2 },
      noise: { enabled: false, period: 15, volume: 0, decay_ms: 100 },
      modulation: { arpeggio: false, arpeggio_notes: [], arpeggio_speed: 50, vibrato: false, vibrato_depth: 0, vibrato_speed: 8 },
    }),
  },
  {
    type: 'vanim', ext: '.vanim', title: 'Animation', dir: 'assets/animations', editor: 'Animation Editor',
    nameField: 'name',
    vpy: { usable: true, usage: (n) => `DRAW_ANIM("${n}", x, y, mirror)   # call every frame; it advances itself (optional 5th/6th args: scale, speed)` },
    c: {
      usable: true,
      usage: (n) => `${cInc(n)}\nDRAW_ANIM(${cSymbol(n)}_anim, ${cSymbol(n)}_anim_sprites, x, y, mirror);`,
      note: 'C needs every frame as named .vec refs (vec_refs/base_refs); inline "paths" are VPy-only.',
    },
    targets: 'm6809, rp2350, uvm2, pitrex; C: sim, rp2350, uvm2 (vec_refs only)',
    format:
`JSON. {"version":"1.0","name","loop":bool,"base_refs":[vec names drawn on every frame],"frames":[{"index":0,"duration_ticks":1-255 (50 Hz ticks),"vec_refs":[vec names],"paths":[inline paths]}...]}
- vec_refs / base_refs name .vec files in assets/vectors (without extension); they must exist.
- Inline path: {"name","intensity":0-127,"points":[{"x","y"}...]} (VPy only; a C project must use vec_refs).
- One frame per pose; create the frame .vec files first (the example needs <name>_1.vec and <name>_2.vec), then the .vanim.`,
    // Frames as vec_refs (works for VPy and C): assets/vectors/<n>_1.vec and <n>_2.vec must exist.
    example: (n) => ({
      version: '1.0', name: n, loop: true, base_refs: [],
      frames: [
        { index: 0, duration_ticks: 8, vec_refs: [`${n}_1`], paths: [] },
        { index: 1, duration_ticks: 8, vec_refs: [`${n}_2`], paths: [] },
      ],
    }),
  },
  {
    type: 'vplay', ext: '.vplay', title: 'Level', dir: 'assets/playground', editor: 'Playground (level editor)',
    nameField: 'metadata.name',
    vpy: {
      usable: true,
      usage: (n, m) => `LOAD_LEVEL("${n}")   # in main()${m?.hasEnemies ? `, then SPAWN_ENEMIES("${n}")` : ''}\nSHOW_LEVEL()   # every frame in loop(); UPDATE_LEVEL() for object physics; SET_CAMERA_X(x) scrolls${m?.hasEnemies ? '\nUPDATE_ENEMIES()\nDRAW_ENEMIES()' : ''}`,
    },
    c: {
      usable: true,
      usage: (n, m) => `${cInc(n)}\nLOAD_LEVEL(${cSymbol(n)}_level, ${cSymbol(n)}_level_sprites);   /* in setup() */${m?.hasEnemies ? `\nSPAWN_ENEMIES(${cSymbol(n)}_enemies, ${cSymbol(n)}_enemy_sprites);` : ''}\nSHOW_LEVEL();   /* every frame */${m?.hasEnemies ? '\nUPDATE_ENEMIES();\nDRAW_ENEMIES();' : ''}`,
    },
    targets: 'm6809, rp2350, uvm2, pitrex; C: sim, rp2350, uvm2',
    format:
`JSON. {"version":"2.0","type":"level","metadata":{"name"},"worldBounds":{"xMin","xMax","yMin","yMax"},"layers":{"background":[],"gameplay":[],"foreground":[]}}
- Object (required: id, type, x, y, scale, rotation): {"id":unique,"type":"background"|"obstacle"|"collectible"|"enemy"|"trigger"|"player_start","vectorName":vec name,"layer","x","y" (world units),"scale":1,"rotation":0}
- Optional: "collidable":true (platforms), "physicsEnabled","physicsType":"gravity"|"bounce","velocity":{"x","y"}, "intensity".
- Enemy: type "enemy" + "enemyType":<.venemy name> + "aiType":"static"|"patrol"|"chase"|"flee"|"wander" (+ "patrolWaypoints" or "walkable_areas").
- Every vectorName / enemyType must exist (assets/vectors/<name>.vec, assets/enemies/<name>.venemy). Objects outside the screen are culled; the camera (SET_CAMERA_X/Y) scrolls the world.`,
    example: (n) => ({
      version: '2.0', type: 'level', metadata: { name: n },
      worldBounds: { xMin: -128, xMax: 127, yMin: -128, yMax: 127 },
      layers: {
        background: [],
        gameplay: [{ id: 'p1', type: 'background', vectorName: 'platform', layer: 'gameplay', x: 0, y: -60, scale: 1, rotation: 0, collidable: true }],
        foreground: [],
      },
    }),
  },
  {
    type: 'venemy', ext: '.venemy', title: 'Enemy type', dir: 'assets/enemies', editor: 'Enemy Editor',
    nameField: 'name',
    vpy: {
      usable: true,
      usage: (n) => `# placed in a level: a .vplay object {"type":"enemy","enemyType":"${n}",...}; then\nSPAWN_ENEMIES("<level>")   # after LOAD_LEVEL; UPDATE_ENEMIES() + DRAW_ENEMIES() every frame; GET_ENEMY_X(i), KILL_ENEMY(i)...`,
    },
    c: {
      usable: true,
      usage: (n) => `/* placed in a level (.vplay enemyType "${n}"); the level header carries it: */\nSPAWN_ENEMIES(<LEVEL>_enemies, <LEVEL>_enemy_sprites); UPDATE_ENEMIES(); DRAW_ENEMIES();`,
    },
    targets: 'm6809, rp2350, uvm2, pitrex; C: sim, rp2350, uvm2 (through a level)',
    format:
`JSON. {"version":"1.0","name","actions":[{"name","sprite":"assets/vectors/<x>.vec" or "assets/animations/<x>.vanim","loop":bool}],"stats":{"hp","speed","action_duration"},"behavior":{"type":"patrol"|"chase"|"flee"|"static","patrol":{"waypoints":[],"loop":true,"mirrorOnPatrol":bool,"defaultFacing":"left"|"right","patrolAction":action name}}}
- "sprite" is a path from the project root and must exist. The drawn sprite is the patrolAction, else "idle", else the first action.
- Optional "state_machine" (edited in the Enemy Editor) drives states/events (ENEMY_FIRE_EVENT(i, "name")).
- An enemy only exists in a game when a level places it (object "enemyType").`,
    example: (n) => ({
      version: '1.0', name: n,
      actions: [{ name: 'walk', sprite: `assets/vectors/${n}.vec`, loop: true }],
      stats: { hp: 1, speed: 1, action_duration: 180 },
      behavior: { type: 'patrol', patrol: { waypoints: [], loop: true, mirrorOnPatrol: true, defaultFacing: 'right', patrolAction: '' } },
    }),
  },
  {
    type: 'vinstr', ext: '.vinstr', title: 'Instrument', dir: 'assets/instruments', editor: 'Instrument Editor',
    nameField: 'name',
    vpy: { usable: true, usage: (n) => `PLAY_NOTE("${n}", channel, midi_note)   # channel 0-2, note 24-107 (60 = C4)` },
    c: {
      usable: true,
      usage: (n) => `${cInc(n)}\nPLAY_NOTE(${cSymbol(n)}_instr, channel, midi_note);   /* channel 0-2, note 24-107 (60 = C4); vpy_run() advances it */`,
    },
    targets: 'm6809, rp2350, uvm2, pitrex; C: sim, rp2350, uvm2',
    format:
`JSON. {"version":"1.0","name","duration_frames":frames,"volume":0-15,"arpeggio_count":0-4,"arpeggio_speed_frames","arpeggio_intervals":[4 signed semitones],"noise_enabled":bool,"noise_period":0-31,"pitch_sweep_delta":signed,"pitch_sweep_duration_frames"}
- A timbre without a pitch: PLAY_NOTE gives it the note. Use it for melodies driven by game logic (jingles, interactive music).`,
    example: (n) => ({
      version: '1.0', name: n, duration_frames: 12, volume: 12, arpeggio_count: 0, arpeggio_speed_frames: 2,
      arpeggio_intervals: [0, 0, 0, 0], noise_enabled: false, noise_period: 15, pitch_sweep_delta: 0, pitch_sweep_duration_frames: 0,
    }),
  },
  {
    type: 'vrec', ext: '.vrec', title: 'Vector recording (vector movie video)', dir: 'assets/recordings', editor: 'Recording viewer (read-only); made by the Emulator panel recorder or the Vector Movie editor',
    nameField: 'name',
    vpy: { usable: true, usage: (n) => `DRAW_RECORDING("${n}", x, y, scale, frame)   # scale 128 = 100%; frame wraps (frame % frame count)` },
    c: {
      usable: true,
      usage: (n) => `${cInc(n)}\nDRAW_RECORDING(${cSymbol(n)}_vrec, x, y, scale, frame);   /* scale 128 = 100%; frame wraps; frame = SAMPLE_POS(fps) to follow a .vsmp */`,
    },
    targets: 'm6809 (video only), rp2350, uvm2, pitrex; C: sim, rp2350, uvm2',
    format:
`JSON. {"version":"1.0","name","fps","frames":[{"segments":[{"x0","y0","x1","y1","i":intensity 0-127}...]}...]}
- Each frame is a list of line segments (Vectrex coordinates -128..127). Keep frames small: every segment is drawn every frame.
- Usually recorded (Emulator panel) or converted from video (Vector Movie editor), not hand-written.`,
    example: (n) => ({
      version: '1.0', name: n, fps: 15,
      frames: [
        { segments: [{ x0: -20, y0: -20, x1: 20, y1: -20, i: 100 }, { x0: 20, y0: -20, x1: 0, y1: 20, i: 100 }, { x0: 0, y0: 20, x1: -20, y1: -20, i: 100 }] },
        { segments: [{ x0: -20, y0: 20, x1: 20, y1: 20, i: 100 }, { x0: 20, y0: 20, x1: 0, y1: -20, i: 100 }, { x0: 0, y0: -20, x1: -20, y1: 20, i: 100 }] },
      ],
    }),
  },
  {
    type: 'vsmp', ext: '.vsmp', title: 'Audio sample (4-bit PCM)', dir: 'assets/samples', editor: 'Sample player (read-only); made by the Vector Movie editor or tools/audio2vsmp',
    nameField: 'name',
    vpy: { usable: true, usage: (n) => `PLAY_SAMPLE("${n}")   # rp2350/pitrex; SAMPLE_POS(fps) = audio-synced frame for DRAW_RECORDING`, note: 'Not on m6809. On uvm2 it builds, but PLAY_SAMPLE/SAMPLE_POS are no-ops there (docs/UVM2_TARGET.md).' },
    c: {
      usable: true,
      usage: (n) => `${cInc(n)}\nPLAY_SAMPLE(${cSymbol(n)}_smp);   /* SAMPLE_POS(fps) = audio-synced frame for DRAW_RECORDING */`,
      note: 'Plays in the simulator and on the rp2350 cartridge. On uvm2 it builds, but PLAY_SAMPLE is a no-op and SAMPLE_POS stays 0 (a sample does not fit in a .um2 image: docs/UVM2_TARGET.md).',
    },
    targets: 'rp2350, pitrex (uvm2: builds, plays nothing); not m6809; C: sim, rp2350 (uvm2: builds, plays nothing)',
    format:
`JSON. {"version":"1.0","name","sampleRate":Hz (e.g. 8000),"bits":4,"numSamples":N,"data":base64 of packed 4-bit samples (2 per byte, low nibble first)}
- Converted from audio (tools/audio2vsmp, or the Vector Movie editor's import), not hand-written. numSamples <= 2 x decoded bytes.`,
    example: (n) => ({ version: '1.0', name: n, sampleRate: 8000, bits: 4, numSamples: 8, data: 'iIiIiA==' }),
  },
  {
    type: 'vmesh', ext: '.vmesh', title: '3D surface mesh (vpy3d)', dir: 'assets/meshes', editor: 'Mesh Editor',
    nameField: 'name',
    vpy: { usable: false, usage: () => '', note: 'VPy has no .vmesh support; for 3D in VPy use a .vec with "z" and DRAW_VECTOR_3D.' },
    c: {
      usable: true,
      usage: (n) => `#include <vpy3d.h>\n${cInc(n)}\nstatic vpy_mesh m;\n/* setup(): */ vpy3d_load_mesh(&m, ${cSymbol(n)}_vmesh); vpy3d_look_at(0, 0, -3000, 0, 0, 0, 0, 1, 0);\n/* loop():  */ vpy_xf place = vpy3d_rot_y(angle); vpy3d_draw_mesh(&m, &place, 127);\n/* Makefile: SRCS += $(VPY_C_SDK)/vpy3d.c */`,
    },
    targets: 'C only: sim, rp2350, uvm2',
    format:
`JSON. Either explicit {"name","hard":crease degrees (45),"vertices":[{"x","y","z"}...],"faces":[[vertex indices, counter-clockwise seen from outside]...]}
or lofted {"name","hard":45,"caps":true,"sections":[{"z","points":[{"x","y"}...]} or {"z","vec":"../vectors/x.vec","path":name}...]}
- Optional "open":true for a plate (not a solid). Lofted sections all need the same point count (3+).
- Scenery (rooms, corridors), with either form or alone: "lines":[{"points":[{"x","y","z"}...] (2+ points, a polyline),"br":1..100 (% of the mesh brightness, default 100),"closed":bool,"fog":bool (default true; false = ignores vpy3d_set_scenery_fog)}] and "occluders":[{"points":[3 to 8 corners of a convex solid]}]. Occluders are never drawn: added after the mesh, they hide what is drawn later behind them; lines are cut by the occluders added before. Line/occluder coordinates: integers within +-1000000 (vertices: i16).
- A .vmesh needs faces (with vertices), sections, lines or occluders.
- Drawn with hidden-line removal by vpy3d (C only): vpy3d_load_mesh + vpy3d_draw_mesh; set the camera with vpy3d_look_at.`,
    example: (n) => ({
      name: n, hard: 45,
      vertices: [
        { x: -500, y: -500, z: -500 }, { x: 500, y: -500, z: -500 }, { x: 500, y: 500, z: -500 }, { x: -500, y: 500, z: -500 },
        { x: -500, y: -500, z: 500 }, { x: 500, y: -500, z: 500 }, { x: 500, y: 500, z: 500 }, { x: -500, y: 500, z: 500 },
      ],
      faces: [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [0, 4, 7, 3]],
    }),
  },
];

/** Files in assets/ that are not code assets, and what they are. */
export const OTHER_ASSET_FILES: Record<string, string> = {
  '.vmov': 'Vector movie manifest (Vector Movie editor): pairs a .vrec video with a .vsmp voice track. Code plays its parts: DRAW_RECORDING + PLAY_SAMPLE.',
  '.vrb': 'Binary preview generated from a .vrec by the IDE (SD-menu game preview). Generated, do not edit.',
  '.vgz': 'Compressed VGM recording of arcade audio: source material for sound rips (docs/ARCADE_SOUND_RIP.md); no compiler or editor reads it.',
};

export function specFor(type: unknown): AssetSpec {
  const t = typeof type === 'string' ? type.trim().toLowerCase().replace(/^\./, '') : '';
  const s = ASSET_SPECS.find((x) => x.type === t);
  if (!s) throw new Error(`Unknown asset type ${JSON.stringify(type)}; one of: ${ASSET_SPECS.map((x) => x.type).join(', ')}`);
  return s;
}

export function specForExt(ext: string): AssetSpec | undefined {
  return ASSET_SPECS.find((x) => x.ext === ext.toLowerCase());
}

// ── Project language and the C Makefile ───────────────────────────────────

export function projectLang(projectFile: string): ProjectLang {
  return /\.cvproj$/i.test(projectFile) ? 'c' : 'vpy';
}

/** The text of this C project's Makefile and the files it includes (literal paths only). */
async function makefileTexts(rootDir: string): Promise<string[]> {
  const seen = new Set<string>();
  const texts: string[] = [];
  const visit = async (file: string, depth: number): Promise<void> => {
    if (depth > 3 || seen.has(file)) return;
    seen.add(file);
    let text: string;
    try { text = await fs.readFile(file, 'utf-8'); } catch { return; }
    texts.push(text);
    for (const m of text.matchAll(/^\s*-?include\s+(\S+)\s*$/gm)) {
      const inc = m[1];
      if (inc.includes('$(')) continue;
      await visit(path.resolve(path.dirname(file), inc), depth + 1);
    }
  };
  await visit(path.join(rootDir, 'Makefile'), 0);
  return texts;
}

/** Does this C project's Makefile (or a file it includes) compile assets with vpy_cli? */
export async function makefileCompilesAssets(rootDir: string): Promise<boolean> {
  return (await makefileTexts(rootDir)).some((t) => /compile-asset/.test(t));
}

/**
 * Does it compile assets with extension `ext` (".vinstr")? True when a pattern rule names
 * `%<ext>` — what a C project's template Makefile has for every type C can use. A Makefile
 * from before a type became usable from C compiles assets but not that one.
 */
export async function makefileCompilesExt(rootDir: string, ext: string): Promise<boolean> {
  const texts = await makefileTexts(rootDir);
  const rule = new RegExp(`%${ext.replace('.', '\\.')}\\b`);
  return texts.some((t) => /compile-asset/.test(t)) && texts.some((t) => rule.test(t));
}

// ── Summaries (cheap, from the JSON) ──────────────────────────────────────

const MAX_PARSE = 4 * 1024 * 1024;

async function readJson(file: string): Promise<{ json: any | null; size: number; error?: string }> {
  const st = await fs.stat(file);
  if (st.size > MAX_PARSE) return { json: null, size: st.size };
  try { return { json: JSON.parse(await fs.readFile(file, 'utf-8')), size: st.size }; } catch (e: any) {
    return { json: null, size: st.size, error: `invalid JSON: ${e.message}` };
  }
}

/** One-line summary + the facts the usage snippet needs. Never throws. */
export async function summarizeAsset(spec: AssetSpec, file: string): Promise<{ summary: string; meta: AssetMeta; refs: string[] }> {
  const meta: AssetMeta = {};
  const refs: string[] = [];
  try {
    if (spec.type === 'vsmp') {
      // Big base64 payload: the header fields come first.
      const fd = await fs.open(file, 'r');
      const buf = Buffer.alloc(512);
      await fd.read(buf, 0, 512, 0);
      await fd.close();
      const head = buf.toString('utf-8');
      const rate = Number(/"sampleRate"\s*:\s*(\d+)/.exec(head)?.[1] || 0);
      const n = Number(/"numSamples"\s*:\s*(\d+)/.exec(head)?.[1] || 0);
      return { summary: rate ? `${n} samples @ ${rate} Hz (${(n / rate).toFixed(1)} s)` : 'sample (header not readable)', meta, refs };
    }
    const { json: j, size, error } = await readJson(file);
    if (error) return { summary: error, meta, refs };
    if (!j) return { summary: `${(size / 1048576).toFixed(1)} MB (not parsed)`, meta, refs };
    switch (spec.type) {
      case 'vec': {
        const paths = (j.layers || []).flatMap((l: any) => l?.paths || []);
        const pts = paths.flatMap((p: any) => p?.points || []);
        meta.is3d = pts.some((p: any) => typeof p?.z === 'number' && p.z !== 0);
        let x0 = 0, x1 = 0, y0 = 0, y1 = 0;
        if (pts.length) {
          x0 = Math.min(...pts.map((p: any) => p.x)); x1 = Math.max(...pts.map((p: any) => p.x));
          y0 = Math.min(...pts.map((p: any) => p.y)); y1 = Math.max(...pts.map((p: any) => p.y));
        }
        return { summary: `${paths.length} path(s), ${pts.length} point(s), ${x1 - x0}x${y1 - y0}${meta.is3d ? ', 3D' : ''}`, meta, refs };
      }
      case 'vmus': {
        const notes = j.notes || [], noise = j.noise || [];
        const ch = [...new Set(notes.map((n: any) => n.channel))].sort().join('');
        const secs = j.tempo && j.ticksPerBeat ? (j.totalTicks / j.ticksPerBeat) * 60 / j.tempo : 0;
        return { summary: `${notes.length} notes, ${noise.length} noise, ${secs.toFixed(1)} s @ ${j.tempo} BPM, channels ${ch || '-'}`, meta, refs };
      }
      case 'vsfx':
        return { summary: `${j.category || 'custom'}, ${j.duration_ms ?? '?'} ms, ${j.oscillator?.frequency ?? '?'} Hz${j.noise?.enabled ? ' + noise' : ''}`, meta, refs };
      case 'vanim': {
        const frames = j.frames || [];
        for (const r of [...(j.base_refs || []), ...frames.flatMap((f: any) => f?.vec_refs || [])]) if (!refs.includes(r)) refs.push(r);
        meta.inlinePaths = frames.some((f: any) => (f?.paths || []).length);
        return { summary: `${frames.length} frame(s), ${j.loop === false ? 'once' : 'loop'}${refs.length ? `, vecs: ${refs.join(' ')}` : ''}${meta.inlinePaths ? ', inline paths' : ''}`, meta, refs };
      }
      case 'vplay': {
        const L = j.layers || {};
        const objs = [...(L.background || []), ...(L.gameplay || []), ...(L.foreground || [])];
        const vecs = [...new Set(objs.map((o: any) => o?.vectorName).filter(Boolean))] as string[];
        const enemies = [...new Set(objs.map((o: any) => o?.enemyType).filter(Boolean))] as string[];
        meta.hasEnemies = enemies.length > 0;
        refs.push(...vecs);
        const wb = j.worldBounds || {};
        return { summary: `${objs.length} object(s), vecs: ${vecs.join(' ') || '-'}${enemies.length ? `, enemies: ${enemies.join(' ')}` : ''}, world x ${wb.xMin}..${wb.xMax}`, meta, refs };
      }
      case 'venemy': {
        const acts = j.actions || [];
        return { summary: `${j.behavior?.type || 'patrol'}, hp ${j.stats?.hp ?? '?'}, actions: ${acts.map((a: any) => a?.name).join(' ')}`, meta, refs };
      }
      case 'vinstr':
        return { summary: `${j.duration_frames ?? '?'} frames, volume ${j.volume ?? '?'}${j.noise_enabled ? ', noise' : ''}${j.arpeggio_count ? ', arpeggio' : ''}`, meta, refs };
      case 'vrec': {
        const frames = j.frames || [];
        const segs = frames.reduce((a: number, f: any) => a + (f?.segments?.length || 0), 0);
        return { summary: `${frames.length} frame(s) @ ${j.fps} fps, ~${Math.round(segs / Math.max(1, frames.length))} segments/frame`, meta, refs };
      }
      case 'vmesh':
      {
        const scene = [
          Array.isArray(j.lines) && j.lines.length ? `${j.lines.length} line(s)` : '',
          Array.isArray(j.occluders) && j.occluders.length ? `${j.occluders.length} occluder(s)` : '',
        ].filter(Boolean).join(', ');
        const body = j.sections ? `lofted, ${j.sections.length} section(s)`
          : (j.vertices || []).length || (j.faces || []).length || !scene ? `${(j.vertices || []).length} vertices, ${(j.faces || []).length} faces` : '';
        return { summary: [body, scene].filter(Boolean).join(', '), meta, refs };
      }
    }
  } catch (e: any) {
    return { summary: `unreadable: ${e?.message || e}`, meta, refs };
  }
  return { summary: '', meta, refs };
}

// ── Project scan (assets_list) ────────────────────────────────────────────

export interface FoundAsset { type: AssetType; name: string; path: string; summary: string; usage: string; warning?: string }

/** Is `rel` (posix, from the project root) where the build finds a `spec` asset? */
export function inBuildFolder(spec: AssetSpec, rel: string, lang: ProjectLang): boolean {
  const dir = path.posix.dirname(rel);
  // VPy finds levels in ANY direct sub-folder of assets/ (discover_assets).
  if (lang === 'vpy' && spec.type === 'vplay') return /^assets\/[^/]+$/.test(dir);
  return dir === spec.dir;
}

export async function scanProjectAssets(rootDir: string, lang: ProjectLang, opts: { type?: AssetType; maxPerType?: number } = {}) {
  const maxPerType = Math.max(1, Math.min(opts.maxPerType ?? 100, 1000));
  const byType: Record<string, FoundAsset[]> = {};
  const counts: Record<string, number> = {};
  const other: Array<{ path: string; what: string }> = [];
  const assetsRoot = path.join(rootDir, 'assets');
  const walk = async (dir: string, depth: number): Promise<void> => {
    if (depth > 4) return;
    let items: import('fs').Dirent[];
    try { items = await fs.readdir(dir, { withFileTypes: true }); } catch { return; }
    items.sort((a, b) => a.name.localeCompare(b.name));
    for (const it of items) {
      const full = path.join(dir, it.name);
      if (it.isDirectory()) { await walk(full, depth + 1); continue; }
      if (!it.isFile()) continue;
      const ext = path.extname(it.name).toLowerCase();
      const rel = path.relative(rootDir, full).split(path.sep).join('/');
      const spec = specForExt(ext);
      if (!spec) {
        if (OTHER_ASSET_FILES[ext]) other.push({ path: rel, what: OTHER_ASSET_FILES[ext] });
        continue;
      }
      if (opts.type && spec.type !== opts.type) continue;
      counts[spec.type] = (counts[spec.type] || 0) + 1;
      const list = (byType[spec.type] ||= []);
      if (list.length >= maxPerType) continue;
      const name = path.basename(it.name, path.extname(it.name));
      const { summary, meta } = await summarizeAsset(spec, full);
      const side = lang === 'c' ? spec.c : spec.vpy;
      const entry: FoundAsset = { type: spec.type, name, path: rel, summary, usage: side.usable ? side.usage(name, meta) : '' };
      if (!side.usable) entry.warning = side.note || `not usable from ${lang === 'c' ? 'C' : 'VPy'}`;
      else if (!inBuildFolder(spec, rel, lang)) {
        entry.warning = lang === 'vpy'
          ? `not in ${spec.type === 'vplay' ? 'a direct sub-folder of assets/' : spec.dir + '/'}: the compiler will not find it`
          : `not in ${spec.dir}/: the project Makefile does not compile it`;
      } else if (lang === 'c' && spec.type === 'vanim' && meta.inlinePaths) {
        entry.warning = 'has inline paths: the C build rejects it (use vec_refs)';
      }
      list.push(entry);
    }
  };
  await walk(assetsRoot, 0);
  const assets: Record<string, { count: number; truncated: boolean; items: FoundAsset[] }> = {};
  for (const s of ASSET_SPECS) {
    if (byType[s.type]) assets[s.type] = { count: counts[s.type], truncated: counts[s.type] > byType[s.type].length, items: byType[s.type] };
  }
  const usableNone = ASSET_SPECS
    .filter((s) => (lang === 'c' ? s.c.usable : s.vpy.usable) && !byType[s.type] && (!opts.type || opts.type === s.type))
    .map((s) => ({ type: s.type, ext: s.ext, title: s.title, folder: s.dir + '/', editor: s.editor }));
  const notUsable = ASSET_SPECS
    .filter((s) => !(lang === 'c' ? s.c.usable : s.vpy.usable))
    .map((s) => ({ type: s.type, why: (lang === 'c' ? s.c.note : s.vpy.note) || '' }));
  return { assets, usableTypesWithNoAssets: usableNone, typesNotUsableInThisLanguage: notUsable, other };
}

// ── Names, references, the compiler check ─────────────────────────────────

export const NEW_ASSET_NAME_RE = /^[A-Za-z_][A-Za-z0-9_-]{0,63}$/;

export function newAssetName(name: unknown, ext: string): string {
  if (typeof name !== 'string' || !name.trim()) throw new Error('"name" is required and must be a non-empty string');
  let n = name.trim();
  if (n.toLowerCase().endsWith(ext)) n = n.slice(0, -ext.length);
  if (!NEW_ASSET_NAME_RE.test(n)) {
    throw new Error(`Invalid asset name "${n}": start with a letter or "_", then letters, digits, "_" or "-" (it becomes a code symbol; no paths, no dots)`);
  }
  return n;
}

/** Set the asset's own name field to the file name (the compiler names symbols after the file). */
export function normaliseName(spec: AssetSpec, json: any, name: string): boolean {
  if (!json || typeof json !== 'object' || Array.isArray(json)) return false;
  if (spec.nameField === 'metadata.name') {
    if (!json.metadata || typeof json.metadata !== 'object') json.metadata = {};
    if (json.metadata.name === name) return false;
    json.metadata.name = name;
    return true;
  }
  if (json.name === name) return false;
  json.name = name;
  return true;
}

/**
 * Structural errors the IDE checks itself before the compiler runs: the
 * `.vmesh` "lines"/"occluders" (an older bundled vpy_cli ignores those keys,
 * so a bad one would pass silently). Mirrors the Mesh Editor's validation.
 */
export function structuralErrors(spec: AssetSpec, json: any): string[] {
  const errs: string[] = [];
  if (spec.type !== 'vmesh' || !json || typeof json !== 'object') return errs;
  const isInt = (v: unknown) => typeof v === 'number' && Number.isInteger(v);
  const LIM = 1_000_000;
  const points = (where: string, pts: unknown, min: number, max: number) => {
    if (!Array.isArray(pts)) { errs.push(`${where}: "points" must be an array`); return; }
    if (pts.length < min || pts.length > max) errs.push(`${where} has ${pts.length} point(s), needs ${max === Infinity ? `at least ${min}` : `${min} to ${max}`}`);
    pts.forEach((p: any, i: number) => {
      if (!p || typeof p !== 'object' || Array.isArray(p)) { errs.push(`${where} point ${i} must be {"x","y","z"}`); return; }
      for (const a of ['x', 'y', 'z']) {
        if (p[a] === undefined && a === 'z') continue;
        if (!isInt(p[a]) || Math.abs(p[a]) > LIM) errs.push(`${where} point ${i}: "${a}" must be a whole number within +-${LIM}`);
      }
    });
  };
  for (const key of ['lines', 'occluders']) {
    if (json[key] !== undefined && !Array.isArray(json[key])) errs.push(`"${key}" must be an array`);
  }
  (Array.isArray(json.lines) ? json.lines : []).forEach((l: any, i: number) => {
    if (!l || typeof l !== 'object' || Array.isArray(l)) { errs.push(`line ${i} must be an object {"points":[...]}`); return; }
    points(`line ${i}`, l.points, 2, Infinity);
    if (l.br !== undefined && l.br !== null && (!isInt(l.br) || l.br < 1 || l.br > 100)) errs.push(`line ${i}: "br" must be a whole percent 1..100`);
    for (const b of ['closed', 'fog']) {
      if (l[b] !== undefined && l[b] !== null && typeof l[b] !== 'boolean') errs.push(`line ${i}: "${b}" must be true or false`);
    }
  });
  (Array.isArray(json.occluders) ? json.occluders : []).forEach((o: any, i: number) => {
    if (!o || typeof o !== 'object' || Array.isArray(o)) { errs.push(`occluder ${i} must be an object {"points":[...]}`); return; }
    points(`occluder ${i}`, o.points, 3, 8);
  });
  return errs.slice(0, 20);
}

/** Assets this one references that do not exist. Paths are checked from the project root. */
export function missingReferences(spec: AssetSpec, json: any, rootDir: string, fileDir: string): string[] {
  const missing: string[] = [];
  const need = (rel: string, label: string) => {
    if (!existsSync(path.join(rootDir, rel))) missing.push(`${label} -> ${rel}`);
  };
  if (!json || typeof json !== 'object') return missing;
  if (spec.type === 'vanim') {
    const refs = new Set<string>([...(json.base_refs || []), ...((json.frames || []).flatMap((f: any) => f?.vec_refs || []))]);
    for (const r of refs) if (typeof r === 'string') need(`assets/vectors/${r}.vec`, `vec ref "${r}"`);
  } else if (spec.type === 'vplay') {
    const L = json.layers || {};
    for (const o of [...(L.background || []), ...(L.gameplay || []), ...(L.foreground || [])]) {
      if (o?.vectorName && !o?.enemyType) need(`assets/vectors/${o.vectorName}.vec`, `object "${o.id}" vectorName "${o.vectorName}"`);
      if (o?.enemyType) need(`assets/enemies/${o.enemyType}.venemy`, `object "${o.id}" enemyType "${o.enemyType}"`);
    }
  } else if (spec.type === 'venemy') {
    for (const a of json.actions || []) {
      if (typeof a?.sprite === 'string' && a.sprite) need(a.sprite, `action "${a.name}" sprite`);
    }
  } else if (spec.type === 'vmesh') {
    for (const s of json.sections || []) {
      if (typeof s?.vec === 'string') {
        if (!existsSync(path.resolve(fileDir, s.vec))) missing.push(`section vec -> ${s.vec} (relative to the .vmesh)`);
      }
    }
  }
  return missing;
}

/** The bundled compiler: $VPY_COMPILER_BIN, the packaged resources, or ide/electron/resources. */
export function resolveVpyCli(): string | null {
  const exe = process.platform === 'win32' ? 'vpy_cli.exe' : 'vpy_cli';
  const candidates = [
    process.env.VPY_COMPILER_BIN,
    (process as any).resourcesPath ? path.join((process as any).resourcesPath, exe) : undefined,
    path.join(__dirname, '..', '..', 'resources', exe),
  ];
  for (const c of candidates) if (c && existsSync(c)) return c;
  return null;
}

function run(cmd: string, args: string[], timeoutMs = 60000): Promise<{ code: number; stdout: string; stderr: string }> {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    const t = setTimeout(() => child.kill(), timeoutMs);
    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });
    child.on('error', (e) => { clearTimeout(t); resolve({ code: -1, stdout, stderr: String(e) }); });
    child.on('close', (code) => { clearTimeout(t); resolve({ code: code ?? -1, stdout, stderr }); });
  });
}

const stripAnsi = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '');

export interface CheckResult { ok: boolean; validatedBy: string; summary?: string; error?: string }

/**
 * Compile-check an asset file with the real compiler: `vpy_cli check-asset` (every type,
 * the loaders the backends use), plus — for a C project — `vpy_cli compile-asset --format c`,
 * the exact step its Makefile runs.
 */
export async function compileCheck(cli: string, file: string, spec: AssetSpec, lang: ProjectLang): Promise<CheckResult> {
  const r = await run(cli, ['check-asset', file, '--json']);
  let validatedBy = 'vpy_cli check-asset';
  let summary: string | undefined;
  const line = r.stdout.trim().split('\n').reverse().find((l) => l.startsWith('{'));
  if (line) {
    let j: any = null;
    try { j = JSON.parse(line); } catch { /* fall through */ }
    if (j && j.ok === false) return { ok: false, validatedBy, error: j.error };
    if (j && j.ok) summary = j.summary;
  } else if (/unrecognized subcommand|unexpected argument|Found argument/i.test(r.stderr)) {
    // An older bundled compiler without check-asset (rebuild with run-ide.sh).
    validatedBy = '';
  } else if (r.code !== 0) {
    return { ok: false, validatedBy, error: stripAnsi(r.stderr || r.stdout).trim().slice(-2000) || `vpy_cli exited ${r.code}` };
  }
  const cTypes: AssetType[] = ['vec', 'vmus', 'vsfx', 'vanim', 'vplay', 'vmesh', 'vinstr', 'vrec', 'vsmp'];
  if (lang === 'c' || (!validatedBy && cTypes.includes(spec.type))) {
    if (cTypes.includes(spec.type)) {
      const tmp = path.join(os.tmpdir(), `vs-asset-${process.pid}-${Date.now()}.h`);
      const c = await run(cli, ['compile-asset', file, '--format', 'c', '--out', tmp]);
      await fs.rm(tmp, { force: true });
      if (c.code !== 0) {
        const msg = stripAnsi(c.stderr || c.stdout).trim().split('\n').filter((l) => /error|Error|unsupported|not supported|compile/i.test(l)).join('\n');
        return { ok: false, validatedBy: 'vpy_cli compile-asset --format c', error: (msg || stripAnsi(c.stderr || c.stdout).trim()).slice(-2000) };
      }
      validatedBy = validatedBy ? `${validatedBy} + compile-asset --format c` : 'vpy_cli compile-asset --format c';
    }
  }
  if (!validatedBy) return { ok: true, validatedBy: 'JSON only (the bundled vpy_cli has no check-asset: rebuild it with run-ide.sh)', summary };
  return { ok: true, validatedBy, summary };
}
