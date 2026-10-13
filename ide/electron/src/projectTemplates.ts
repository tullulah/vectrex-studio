// New-project templates — the ONE place that writes a fresh project to disk.
//
// Used by the New Project dialog (ipcMain 'project:create' in main.ts) and by the MCP
// tool project_create (mcp/server.ts), so the two can never hand out different projects.
//
//   kind "vpy" → <name>.vpyproj + src/main.vpy + assets/ folders (m6809 / ARM targets
//                through vpy_cli). Asset folders and how code uses them: docs/ASSETS.md.
//   kind "c"   → <name>.cvproj + Makefile + src/main.c, a self-contained C project on the
//                SDK's libvpy runtime (#include <vpy.h>, vpy_run(setup, loop)). Its Makefile
//                compiles assets/ into gen/<name>.h with $(VPY_CLI) (the IDE passes it).
//                Builds:
//                  make sim      → build_wasm/<name>.js       WASM simulator (Shift+F5)
//                  make rp2350   → build_rp2350/<name>_sd.bin  RP2350 cartridge (F5, rp2350)
//                  make uvm2     → build_uvm2/<name>.um2       UVMC2 multicart (F5, uvm2)
//                The rp2350/uvm2 recipes are the SDK's own (uvm2-sdk/uvm2.mk); the IDE
//                passes the pinned SDK as $(UVMC2_SDK), $(VPY_C_SDK), $(PITREX_SIM_SDK),
//                $(RP2350_SDK) (see docs/SDK_VERSIONS.md). Nothing outside the project
//                folder is referenced except the SDK and the toolchains.
//
// No electron import: this module also runs under plain Node (MCP test harness).

import { promises as fs } from 'fs';
import { join } from 'path';
import { sdkDirFor } from './sdkManager.js';
import * as os from 'os';

/** The default workspace: new projects go here unless the user picks another folder. */
export function defaultProjectsDir(): string {
  return join(os.homedir(), 'VectrexStudio', 'projects');
}

/** The default workspace, created if it does not exist yet. */
export async function ensureDefaultProjectsDir(): Promise<string> {
  const dir = defaultProjectsDir();
  await fs.mkdir(dir, { recursive: true });
  return dir;
}

export type ProjectKind = 'vpy' | 'c';

export interface CreatedProject {
  kind: ProjectKind;
  name: string;
  projectDir: string;
  projectFile: string;
  /** Absolute path of the source file to open first. */
  entryFile: string;
  sdkVersion: string | null;
  files: string[];
}

export const PROJECT_NAME_RE = /^[A-Za-z][A-Za-z0-9_-]{0,63}$/;

/** TOML basic string (also valid JSON) for names that passed PROJECT_NAME_RE. */
const q = (s: string) => JSON.stringify(s);

const GITIGNORE_VPY = `# Build artifacts
/build/
*.bin
*.o

# IDE
.vscode/
*.swp
*~
`;

const GITIGNORE_C = `# Build artifacts
/gen/
/build_wasm/
/build_rp2350/
/build_uvm2/

# IDE
.vscode/
*.swp
*~
`;

function vpyProjectFile(name: string, sdkVersion: string | null): string {
  return `[project]
name = ${q(name)}
version = "0.1.0"
entry = "src/main.vpy"

[build]
output = ${q(`build/${name}.bin`)}
optimization = 2
debug_symbols = true

[sources]
vpy = ["src/**/*.vpy"]

# Assets (docs/ASSETS.md). The compiler finds them by folder; code names them by file
# name, e.g. DRAW_VECTOR("ship", x, y) for assets/vectors/ship.vec.
[resources]
vectors = ["assets/vectors/*.vec"]
music = ["assets/music/*.vmus"]
sfx = ["assets/sfx/*.vsfx"]
animations = ["assets/animations/*.vanim"]
levels = ["assets/playground/*.vplay"]
enemies = ["assets/enemies/*.venemy"]
instruments = ["assets/instruments/*.vinstr"]
recordings = ["assets/recordings/*.vrec"]
samples = ["assets/samples/*.vsmp"]
# 3D (uvm2): meshes (folders inside assets/meshes too), scenes, skeletons and their clips
meshes = ["assets/meshes/*.vmesh"]
scenes = ["assets/scenes/*.vscene"]
skeletons = ["assets/skeletons/*.vskel"]
clips = ["assets/clips/*.vclip"]
${sdkVersion ? `\n[sdk]\nversion = ${q(sdkVersion)}\n` : ''}`;
}

function vpyMain(name: string): string {
  return `# ${name} - main entry point

META TITLE = ${q(name.toUpperCase())}

def main():
    # Called once at startup
    SET_INTENSITY(127)

def loop():
    # Called every frame (WAIT_RECAL and the button read are injected by the compiler)
    PRINT_TEXT(-60, 60, "HELLO WORLD")
    DRAW_LINE(-50, -50, 50, 50, 127)
`;
}

function cProjectFile(name: string, sdkVersion: string | null): string {
  return `# ${name} — C project for Vectrex Studio on the SDK's libvpy runtime (#include <vpy.h>).
#
# F5 builds the target selected in the IDE and runs it on that target's emulator;
# Shift+F5 builds [simulate] (WASM) and runs it in the emulator panel. Outside the IDE:
#   make sim|rp2350|uvm2 UVMC2_SDK=~/VectrexStudio/sdk/<version>
[project]
name = ${q(name)}
type = "c-external"
target = "rp2350"
entry = "src/main.c"

# Default recipe, used when a target has no [targets.<target>] table.
[build]
command = "make"
args = ["rp2350"]
artifact = ${q(`build_rp2350/${name}_sd.bin`)}

# RP2350 cartridge: a RAM-linked game the cartridge BIOS launches from the SD card.
[targets.rp2350]
command = "make"
args = ["rp2350"]
artifact = ${q(`build_rp2350/${name}_sd.bin`)}

# UVMC2 multicart: a .um2 image (needs the pico-sdk, which the IDE downloads, and the
# Arm GNU Toolchain).
[targets.uvm2]
command = "make"
args = ["uvm2"]
artifact = ${q(`build_uvm2/${name}.um2`)}

# WASM simulator: the same C compiled with emscripten against the host SDK shim.
[simulate]
command = "make"
args = ["sim"]
module = ${q(`build_wasm/${name}.js`)}
${sdkVersion ? `\n[sdk]\nversion = ${q(sdkVersion)}\n` : ''}`;
}

function cMakefile(name: string): string {
  return `# ${name} — build rules (C on the libvpy runtime).
#
#   make sim      build_wasm/${name}.js        WASM simulator (emscripten)
#   make rp2350   build_rp2350/${name}_sd.bin   RP2350 cartridge (SD game)
#   make uvm2     build_uvm2/${name}.um2        UVMC2 multicart image
#
# The IDE passes the SDK pinned in ${name}.cvproj ([sdk] version) as UVMC2_SDK and the
# part variables below. Outside the IDE:
#   make sim UVMC2_SDK=~/VectrexStudio/sdk/<version>

NAME := ${name}
SRCS  = src/main.c   # more sources here; a .vmesh or .vscene also needs $(VPY_C_SDK)/vpy3d.c

# The SDK root. The simulator build only gets VPY_C_SDK/PITREX_SIM_SDK, so the root is
# derived from VPY_C_SDK (<root>/vpy-c) when UVMC2_SDK itself is not set.
VPY_C_SDK_GIVEN := $(findstring environment,$(origin VPY_C_SDK))$(findstring command,$(origin VPY_C_SDK))
UVMC2_SDK      ?= $(if $(VPY_C_SDK_GIVEN),$(abspath $(VPY_C_SDK)/..),$(error UVMC2_SDK is not set: build from Vectrex Studio, or pass UVMC2_SDK=~/VectrexStudio/sdk/<version>))
VPY_C_SDK      ?= $(UVMC2_SDK)/vpy-c
PITREX_SIM_SDK ?= $(UVMC2_SDK)/pitrex-sim
RP2350_SDK     ?= $(UVMC2_SDK)/rp2350-sdk
UVM2_SDK       ?= $(UVMC2_SDK)/uvm2-sdk

INCLUDES := -Isrc -Igen -I$(VPY_C_SDK)/include -I$(PITREX_SIM_SDK)/include

.DEFAULT_GOAL := sim

# ---- assets -> gen/<name>.h (docs/ASSETS.md) ----------------------------------
# Each asset is compiled by the IDE's compiler (the IDE passes it as VPY_CLI) into a
# header with its data; src/main.c includes it and passes the arrays to vpy.h:
#   #include "ship.h"  ->  DRAW_VECTOR(SHIP_vec, x, y);
# Levels and animations include the headers of the .vec sprites they use, and a
# level reads assets/vectors and assets/enemies, hence the extra prerequisites;
# a scene includes the headers of its .vmesh pieces.
# A .vmesh or .vscene needs vpy3d: add $(VPY_C_SDK)/vpy3d.c to SRCS.
VPY_CLI ?= vpy_cli
VEC_SRCS   := $(wildcard assets/vectors/*.vec)
AUDIO_SRCS := $(wildcard assets/music/*.vmus assets/sfx/*.vsfx assets/instruments/*.vinstr \\
                        assets/samples/*.vsmp)
REC_SRCS   := $(wildcard assets/recordings/*.vrec)
# meshes may sit in folders inside assets/meshes (one header per name: names must be unique)
rwildcard = $(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
MESH_SRCS  := $(sort $(call rwildcard,assets/meshes,*.vmesh))
MESH_DUPS  := $(sort $(foreach n,$(notdir $(MESH_SRCS)),$(if $(word 2,$(filter %/$(n),$(MESH_SRCS))),$(n))))
$(if $(MESH_DUPS),$(error two .vmesh files share a name: $(MESH_DUPS)))
SCENE_SRCS := $(wildcard assets/scenes/*.vscene)
# skeletons (.vskel) and the poses, clips and sets on them (.vclip)
CLIP_SRCS  := $(wildcard assets/clips/*.vclip)
SKEL_SRCS  := $(wildcard assets/skeletons/*.vskel)
ANIM_SRCS  := $(wildcard assets/animations/*.vanim)
LEVEL_SRCS := $(wildcard assets/playground/*.vplay)
ENEMY_SRCS := $(wildcard assets/enemies/*.venemy)
hdr = $(patsubst %,gen/%.h,$(basename $(notdir $(1))))
VEC_HDRS   := $(call hdr,$(VEC_SRCS))
MESH_HDRS  := $(call hdr,$(MESH_SRCS))
ASSET_HDRS := $(VEC_HDRS) $(MESH_HDRS) $(call hdr,$(AUDIO_SRCS) $(REC_SRCS) $(SCENE_SRCS) $(ANIM_SRCS) $(LEVEL_SRCS) $(CLIP_SRCS) $(SKEL_SRCS))

vpath %.vec    assets/vectors
vpath %.vmus   assets/music
vpath %.vsfx   assets/sfx
vpath %.vinstr assets/instruments
vpath %.vrec   assets/recordings
vpath %.vsmp   assets/samples
vpath %.vmesh  assets/meshes $(sort $(dir $(MESH_SRCS)))
vpath %.vscene assets/scenes
vpath %.vclip  assets/clips
vpath %.vskel  assets/skeletons
vpath %.vanim  assets/animations
vpath %.vplay  assets/playground
gen/%.h: %.vec   | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vmus  | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vsfx  | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vinstr | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vrec  | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vsmp  | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vmesh | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vscene | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vclip | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vskel | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vanim | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
gen/%.h: %.vplay | gen ; $(VPY_CLI) compile-asset $< --format c --out $@ >/dev/null
$(call hdr,$(ANIM_SRCS) $(LEVEL_SRCS)): $(VEC_HDRS)
$(call hdr,$(LEVEL_SRCS)): $(VEC_SRCS) $(ENEMY_SRCS)
$(call hdr,$(SCENE_SRCS)): $(MESH_HDRS)
$(call hdr,$(CLIP_SRCS)): $(SKEL_SRCS)
$(call hdr,$(SKEL_SRCS)): $(MESH_SRCS)

assets: $(ASSET_HDRS)

gen:
	mkdir -p gen

# ---- WASM simulator (Shift+F5) ----------------------------------------------
EMCC ?= emcc
WASM_LDFLAGS = -sASYNCIFY -sASYNCIFY_STACK_SIZE=65536 \\
               -sINITIAL_MEMORY=33554432 -sALLOW_MEMORY_GROWTH=1 \\
               -sINVOKE_RUN=0 -sEXIT_RUNTIME=0 \\
               -sMODULARIZE=1 -sEXPORT_NAME=createSimModule -sEXPORTED_RUNTIME_METHODS=callMain,FS

sim: $(ASSET_HDRS) | build_wasm
	$(EMCC) $(INCLUDES) -O2 $(SRCS) $(VPY_C_SDK)/vpy.c $(PITREX_SIM_SDK)/sdk_host.c \\
	        $(WASM_LDFLAGS) -o build_wasm/$(NAME).js
	@echo "=== Sim build OK: build_wasm/$(NAME).js ==="

build_wasm:
	mkdir -p build_wasm

# ---- RP2350 cartridge and UVMC2 multicart: the SDK's shared recipes ----------
# Prefer the Arm GNU Toolchain (the pico-sdk link of \`make uvm2\` needs it; Homebrew's
# arm-none-eabi-gcc lacks nosys.specs). Falls back to arm-none-eabi-gcc on PATH.
UVM2_ARM_TOOLCHAIN ?= $(firstword $(wildcard /Applications/ArmGNUToolchain/*/arm-none-eabi) \\
                                  $(wildcard /opt/arm-gnu-toolchain*/arm-none-eabi) \\
                                  $(wildcard /usr/local/arm-gnu-toolchain*/arm-none-eabi))
ARM_BIN      := $(if $(UVM2_ARM_TOOLCHAIN),$(UVM2_ARM_TOOLCHAIN)/bin/,)
UVM2_CC      := $(ARM_BIN)arm-none-eabi-gcc
UVM2_CXX     := $(ARM_BIN)arm-none-eabi-g++
UVM2_OBJCOPY := $(ARM_BIN)arm-none-eabi-objcopy

UVM2_NAME   = $(NAME)
UVM2_SRCS   = $(SRCS) $(VPY_C_SDK)/vpy.c
UVM2_CFLAGS = -mcpu=cortex-m33 -mthumb -ffreestanding -O2 \\
              -ffunction-sections -fdata-sections -fno-common $(INCLUDES)
UVM2_DEPS   = $(ASSET_HDRS)
include $(UVM2_SDK)/uvm2.mk

# uvm2.mk names the cartridge rule $(NAME)_rp2350 (and rp2350-cart).
rp2350: $(NAME)_rp2350

clean:
	rm -rf build_wasm build_rp2350 build_uvm2 gen

.PHONY: sim rp2350 assets clean
`;
}

function cMain(name: string): string {
  return `/* ${name} — Vectrex Studio C project on the libvpy runtime.
 *
 * setup() runs once, loop() once per frame. vpy_run() owns the frame boundary (waits for
 * the beam, reads the controls, flushes the strokes): never call v_WaitRecal() yourself.
 * Coordinates are VPy space (-127..127, +Y up); brightness is 0..127.
 * The full API is in $(VPY_C_SDK)/include/vpy.h.
 */
#define VPY_SHORT_NAMES
#include <vpy.h>

static int ship_x;

static void setup(void)
{
    ship_x = 0;
}

static void loop(void)
{
    PRINT_TEXT(-60, 60, "HELLO WORLD");

    /* Joystick 1 moves the triangle left and right. */
    ship_x += J1_X() / 32;
    if (ship_x > 100) ship_x = 100;
    if (ship_x < -100) ship_x = -100;

    DRAW_LINE(ship_x, -20, ship_x - 15, -50, 127);
    DRAW_LINE(ship_x - 15, -50, ship_x + 15, -50, 127);
    DRAW_LINE(ship_x + 15, -50, ship_x, -20, 127);
}

int main(void)
{
    vpy_run(setup, loop);
    return 0;
}
`;
}

/** clangd include paths for the pinned SDK (as the bundled examples ship them). */
function cCompileFlags(sdkVersion: string | null): string {
  const lines = ['-Isrc'];
  if (sdkVersion) {
    const dir = sdkDirFor(sdkVersion);
    lines.unshift(`-I${join(dir, 'vpy-c', 'include')}`, `-I${join(dir, 'pitrex-sim', 'include')}`);
  }
  return lines.join('\n') + '\n';
}

async function assertNoProjectIn(projectDir: string): Promise<void> {
  try {
    const existing = await fs.readdir(projectDir);
    if (existing.some((e) => /\.(vpyproj|cvproj)$/i.test(e))) {
      throw new Error(`A project already exists in ${projectDir}`);
    }
  } catch (e: any) {
    if (e?.code !== 'ENOENT') throw e;
  }
}

/**
 * Create <parentDir>/<name> with a working project of `kind`. Refuses to touch a folder
 * that already holds a project. `sdkVersion` is the [sdk] pin (null = none; the IDE pins
 * the latest on the first build).
 */
export async function createProjectFromTemplate(opts: {
  kind: ProjectKind;
  name: string;
  parentDir: string;
  sdkVersion: string | null;
}): Promise<CreatedProject> {
  const { kind, name, parentDir, sdkVersion } = opts;
  if (!PROJECT_NAME_RE.test(name)) {
    throw new Error(`Invalid project name "${name}": start with a letter; then letters, digits, "_" or "-" (max 64)`);
  }
  const projectDir = join(parentDir, name);
  await assertNoProjectIn(projectDir);

  const files: Array<[string, string]> = [];
  let projectFile: string;
  let entryFile: string;

  if (kind === 'c') {
    projectFile = join(projectDir, `${name}.cvproj`);
    entryFile = join(projectDir, 'src', 'main.c');
    await fs.mkdir(join(projectDir, 'src'), { recursive: true });
    files.push(
      [projectFile, cProjectFile(name, sdkVersion)],
      [join(projectDir, 'Makefile'), cMakefile(name)],
      [entryFile, cMain(name)],
      [join(projectDir, 'compile_flags.txt'), cCompileFlags(sdkVersion)],
      [join(projectDir, '.gitignore'), GITIGNORE_C],
    );
  } else {
    projectFile = join(projectDir, `${name}.vpyproj`);
    entryFile = join(projectDir, 'src', 'main.vpy');
    for (const d of ['src', 'build', 'assets/vectors', 'assets/music', 'assets/sfx', 'assets/animations', 'assets/playground',
      'assets/enemies', 'assets/instruments', 'assets/recordings', 'assets/samples', 'assets/movies',
      'assets/meshes', 'assets/scenes', 'assets/skeletons', 'assets/clips']) {
      await fs.mkdir(join(projectDir, d), { recursive: true });
    }
    files.push(
      [projectFile, vpyProjectFile(name, sdkVersion)],
      [entryFile, vpyMain(name)],
      [join(projectDir, '.gitignore'), GITIGNORE_VPY],
    );
  }

  for (const [p, content] of files) await fs.writeFile(p, content, 'utf-8');
  return { kind, name, projectDir, projectFile, entryFile, sdkVersion, files: files.map(([p]) => p) };
}
