# SDK Versions (uvmc2-sdk)

The ARM targets and C projects build against the **uvmc2-sdk** (`uvm2-sdk/`, `vpy-c/`,
`pitrex-sim/`, `rp2350-sdk/`, `vectrex-draw/`, `tools/`, ...). The SDK is not bundled
with the IDE or with `vpy_cli`: each project pins a release in its project file, and
Vectrex Studio downloads that release on demand. This document covers the pin, where
releases are installed, which builds need them, and how command-line builds find them.

## Contents

- [Pinning a version](#pinning-a-version)
- [Where releases come from](#where-releases-come-from)
- [Install location](#install-location)
- [Which builds need the SDK](#which-builds-need-the-sdk)
- [How the IDE passes the SDK to a build](#how-the-ide-passes-the-sdk-to-a-build)
- [Building outside the IDE](#building-outside-the-ide)
- [Project Settings panel](#project-settings-panel)
- [pico-sdk and the Arm toolchain (uvm2)](#pico-sdk-and-the-arm-toolchain-uvm2)
- [Related](#related)

## Pinning a version

Both `.vpyproj` and `.cvproj` files carry an `[sdk]` table:

```toml
[sdk]
version = "v1.3.2"
```

- All example projects in `examples/` are pinned to `v1.3.2`.
- **UVMC2 over USB needs `v1.4.0` or later**: Build → Upload to Cartridge and Debug →
  Debug on Cartridge build the game with the SDK's debug monitor, which older versions do
  not have (the upload still works from the multicart's menu, through the SD bridge, but the
  game then has no monitor to debug). The console's reset button (one press: the game
  again, two: the menu) is also `v1.4.0`. See [IDE_GUIDE.md](IDE_GUIDE.md).
- **vpy3d scenes and scenery (`.vscene`, version-2 `.vmesh`), float on the FPU, SD folders
  and seek need `v1.4.1` or later.** That work lived only in SDK copies installed on one
  machine (a "v1.3.5" / "v1.3.6" that was never a published tag) until v1.4.1.
- **Never change an installed SDK by hand.** A project built against it works on that machine
  and nowhere else: every other one downloads the published tag. Change the SDK repository,
  publish a release, pin the project to it. An installed SDK whose marker
  (`.vectrex-studio-sdk.json`) has a `"local"` note is such a copy, and every build against
  it says so in the build output (`[SDK] WARNING: SDK vX here is a local copy changed by hand`).
- New projects (`project:create`, VPy or C — templates in `ide/electron/src/projectTemplates.ts`) and C imports are created pinned to the latest tag.
- A project with no `[sdk] version` is pinned to the latest tag the first time the IDE
  resolves its SDK (offline: the newest installed release). The IDE writes the pin into
  the file and logs it in the console:
  `[SDK] <project file> had no [sdk] version — pinned to vX.Y.Z`.
- If the project has no pin, GitHub is unreachable and nothing is installed, the build
  fails with an explicit error.

## Where releases come from

Releases are the tags of the GitHub repository
[`tullulah/uvmc2-sdk`](https://github.com/tullulah/uvmc2-sdk) (`v1.1` … `v1.4.1`); what each
one changes is in the SDK's `CHANGELOG.md` and the tag messages. The uvmc2-starter-kit pins
the SDK as its `sdk` submodule, and a kit release carries the tag of the SDK it pins
(`v1.4.0`, `v1.4.1`; the kit has no `v1.3.3` or `v1.3.4`).

The IDE downloads the tag tarball
(`https://codeload.github.com/tullulah/uvmc2-sdk/tar.gz/refs/tags/<tag>`) and extracts
it — git is not required. The list of available tags comes from the GitHub API.

## Install location

```
~/VectrexStudio/sdk/<tag>/
```

The root can be overridden with the environment variable `VECTREX_STUDIO_SDK_DIR`.

A complete install contains the marker file `.vectrex-studio-sdk.json`. A folder without
the marker is treated as a broken earlier attempt and is not used (the IDE replaces it
on the next download; `vpy_cli` ignores it).

The implementation is in `ide/electron/src/sdkManager.ts`; the renderer reaches it through
`window.sdk` (`ide/electron/src/preload.ts`).

## Which builds need the SDK

Only targets that use the SDK resolve (and, if needed, download) it:

| Build | SDK |
|---|---|
| VPy, `m6809` target | Not needed |
| VPy, `uvm2` target | Required (`uvm2-sdk/`) |
| VPy, `pitrex` target | Optional (`vpy-c/`, the libvpy C runtime) |
| C projects (`.cvproj`), every target | Required |
| C projects in the WASM simulator | Required (`pitrex-sim/`, `vpy-c/`) |

## How the IDE passes the SDK to a build

The IDE sets these environment variables for `vpy_cli`, the C makefiles and the simulator
build, all derived from the installed release directory `<dir>`:

| Variable | Value |
|---|---|
| `UVMC2_SDK` | `<dir>` (the SDK root) |
| `UVM2_SDK_DIR` | `<dir>/uvm2-sdk` |
| `VPY_C_DIR` | `<dir>/vpy-c` |
| `VPY_C_SDK` | `<dir>/vpy-c` |
| `PITREX_SIM_SDK` | `<dir>/pitrex-sim` |
| `RP2350_SDK` | `<dir>/rp2350-sdk` |

A `.cvproj` `[env]` table can still override any of them.

## Building outside the IDE

### vpy_cli

`vpy_cli` never downloads anything; it only looks for an installed SDK. For each SDK part
(`uvm2-sdk`, `vpy-c`) it tries, in order (`buildtools/vpy_cli/src/sdk.rs`):

1. The part's own variable — `UVM2_SDK_DIR` or `VPY_C_DIR` — pointing straight at the part.
2. `UVMC2_SDK` — the SDK root; the part is `$UVMC2_SDK/<part>`.
3. The `.vpyproj`'s `[sdk] version` → `~/VectrexStudio/sdk/<version>/<part>` (or under
   `$VECTREX_STUDIO_SDK_DIR`), only if that release has the `.vectrex-studio-sdk.json`
   marker. A plain `.vpy` has no project, so only 1 and 2 apply.

Each candidate must also contain the part's sentinel file (`uvm2_bus.c`, `vpy.c`), otherwise
the next one is tried. If none matches, the error tells you to build the project once in
Vectrex Studio (which downloads the pinned release) or to set `UVMC2_SDK`.

```bash
# Use a release the IDE already downloaded (found through the project's pin):
vpy_cli build examples/SnowBros/SnowBros.vpyproj --target uvm2

# Or point at any SDK checkout explicitly:
UVMC2_SDK=~/src/uvmc2-sdk vpy_cli build mygame.vpy --target uvm2
```

### C example makefiles

`examples/individual_tests_c/common.mk` and the other C examples' makefiles take the SDK
from `UVMC2_SDK` and stop with a clear error when it is unset. Outside the IDE:

```bash
make <target> UVMC2_SDK=~/VectrexStudio/sdk/v1.3.2
```

## Project Settings panel

With a project open, the **Project Settings** sidebar panel
(`ide/frontend/src/components/panels/ProjectSettingsPanel.tsx`):

- shows the SDK version the project is pinned to;
- lists the installed releases and the tags available on GitHub;
- changes the pin — only the `[sdk]` table of the project file is rewritten, so comments
  and layout are preserved;
- downloads a release with progress.

## pico-sdk and the Arm toolchain (uvm2)

UVM2 builds link through the Raspberry Pi **pico-sdk**. It is pinned, not "latest":
the startup contract the multicart loader validates (IMAGE_DEF block, `no_flash`
binary type, the weak `isr_svcall` the SDK overrides) can move between pico-sdk
releases.

- **Which version:** the one the SDK release asks for, in a `PICO_SDK_VERSION` file at
  its root. Every release so far has none and uses **2.2.0**.
- **Download:** the IDE fetches it like the SDK, on the first uvm2 build, into
  `~/VectrexStudio/pico-sdk/<version>/` (override the root with
  `VECTREX_STUDIO_PICO_SDK_DIR`), with the same `.vectrex-studio-sdk.json` marker. It
  is the GitHub tag tarball (~2 MB, ~26 MB installed) **without submodules** —
  TinyUSB, lwIP, BTstack and mbedTLS, which no uvm2 image enables.
- **Passed to builds** as `UVM2_PICO_SDK` and `PICO_SDK_PATH`. Only uvm2 builds get it.
- **vpy_cli** finds it by `UVM2_PICO_SDK`, then `PICO_SDK_PATH`, then
  `~/VectrexStudio/pico-sdk/<version>/`; it never downloads. `uvm2.mk` reads the same
  variables. A CMake cache made with a different pico-sdk is discarded and reconfigured.

**One compiler and one Rust everywhere.** The same game used to build to different sizes on
different machines: Ubuntu's gcc 14.2 made return of the jedi ~4 KB bigger than Arm's 15.2 on
the Mac, and a fresh machine's Rust 1.99 another ~3 KB. A game that fitted on one machine
overflowed on another. So uvm2 builds pin both:

- **Arm GNU Toolchain 15.2.rel1** (gcc 15.2.1). The IDE uses, in this order:
  1. `UVM2_ARM_TOOLCHAIN`, if set; any version, and the build output says so when it is not 15.2;
  2. a 15.2 already installed:
     - its own, in `~/VectrexStudio/toolchains/15.2.rel1`;
     - Arm's macOS `.pkg` (`/Applications/ArmGNUToolchain/15.2.rel1`);
     - `/opt` or `/usr/local` (`arm-gnu-toolchain-*`);
     - the `PATH`.
  3. Otherwise, on the first uvm2 build, it downloads Arm's archive for the machine into `~/VectrexStudio/toolchains`: about 150 MB, the SHA-256 pinned in `sdkManager.ts`, once.

  Other versions, for example a Linux distribution's `gcc-arm-none-eabi`, are listed in Project Settings with the reason, and never used. Arm publishes 15.2 for macOS arm64, Linux x86_64 and aarch64, and Windows; not for Intel Macs. The IDE passes the toolchain to every uvm2 build as `UVM2_ARM_TOOLCHAIN`, and `vpy_cli` also finds the IDE's copy by itself.
- **Rust 1.91.1**, pinned by the SDK's `rust-toolchain.toml` (SDK v1.4.3 or later). rustup installs it, with the `thumbv8m.main-none-eabi` target, the first time cargo runs in the SDK. The SDK also remaps the paths Rust embeds (`~`, `uvmc2-sdk`), so where things are installed does not change the size.

**Rust needs rustup, set up by the IDE.** Before a uvm2 build, the IDE checks for rustup:
- with rustup installed, it adds what an older SDK needs (`rustup default stable`, `rustup target add`);
- with neither rustup nor cargo, it runs the official installer (`curl https://sh.rustup.rs`, into `~/.cargo`, no sudo; macOS and Linux).

Every step shows in the build output.

**Windows: the IDE brings the rest.** A Windows PC has none of the build tools, so the first C, uvm2 or simulator build downloads them into `~/VectrexStudio/toolchains/windows/`, each pinned by version and SHA-256 (`ide/electron/src/winBuildTools.ts`):

| Tool | Version | Used for |
|------|---------|----------|
| xPack Windows Build Tools | make 4.4.1-3 | `make`; its busybox is the recipes' `sh` (`mkdir -p`, `grep`, `sed`...) |
| CMake | 4.2.8 | the pico-sdk build, with `CMAKE_GENERATOR=Ninja` |
| Ninja | 1.13.2 | the generator: the "Unix Makefiles" one refuses a `PATH` with `sh.exe` on it |
| picotool | 2.2.0-a4 (Raspberry Pi's prebuilt) | `.uf2`/binary info; passed as `PICOTOOL_FETCH_FROM_GIT_PATH`, so the pico-sdk does not build it with a PC compiler |
| Rust | the SDK's channel, `x86_64-pc-windows-gnu` host | the drawing layer. The gnu host brings its own linker; the msvc one needs Visual Studio's `link.exe`. rustup is installed for the user if missing, and the build gets `RUSTUP_TOOLCHAIN=<channel>-x86_64-pc-windows-gnu` |
| emscripten (emsdk) | 6.0.3 (emsdk by its tag; its Python by SHA-256) | `make sim`, the WASM simulator. EMCC is `<emsdk python> emcc.py` (busybox's `sh` does not run `.bat` files); an `EMSDK` the user set up is used instead. About 400 MB |

- uvm2 on Windows needs **SDK v1.4.4 or later**: in older ones, the Rust build tools link through `windows-sys` 0.61, which needs MinGW's `dlltool` and assembler. The IDE says so in the build output.
- Paths go to `make` and CMake with `/` (busybox's `sh` takes `\` for an escape). `VPY_CLI` is copied to `~/VectrexStudio/tools/bin/` when the install path has a space.
- The archives are extracted with Windows' own `tar` (`System32`): a GNU tar from Git for Windows reads `D:\` as a host name.
- The SD card and the RP2350's BOOTSEL drive are found among the removable drives (`Get-Volume`), as `/Volumes` on macOS and `/media/<user>` on Linux.
- Upload to Cartridge uses the downloaded picotool and the monitor's COM port (IDE_GUIDE.md, "Upload to Cartridge").
- `.github/workflows/windows-builds.yml` checks it on a clean Windows: a C project (`make uvm2`, `make rp2350`, `make sim`, an asset), a VPy project for uvm2, and what Upload to Cartridge can do without a cartridge; every tool downloaded as the IDE does it.

**Linux, the rest of a uvm2 build.** The pico-sdk builds `picotool` from source when it is not installed, so it needs `cmake`, a host C/C++ compiler and libusb. The Vectrex Studio `.deb` depends on all of them, and on `curl`, `git` and `xz-utils` (for the toolchain archive). It recommends `rustup`, which Debian 12 and Ubuntu 22.04 do not package. Elsewhere:

```sh
sudo dnf install cmake gcc-c++ pkgconf libusb1-devel git xz rustup     # Fedora
sudo pacman -S cmake base-devel libusb git xz rustup                   # Arch/Manjaro
```

**Upload / Debug on Cartridge (UVMC2) on Linux:**
- **udev rule.** The .deb installs `/etc/udev/rules.d/60-vectrex-studio-uvmc2.rules` (`uaccess` for VID 2E8A), so the logged-in user reaches the cartridge's USB and serial port without sudo or the `dialout` group.
- **picotool.** Ubuntu has no `picotool` package, and the pico-sdk builds its own without USB (`PICOTOOL_NO_LIBUSB`). On the first upload, the IDE therefore builds one with USB:
  - from the source the uvm2 build fetched (`_deps/picotool-src`);
  - into `~/VectrexStudio/tools/picotool`, which every later upload uses.

  A `picotool` 2.x on the `PATH` is used first.

## Related

- [UVM2_TARGET.md](UVM2_TARGET.md) — the UVM2 target and the `uvm2-sdk/` contents
- [IDE_GUIDE.md](IDE_GUIDE.md) — panels, build targets, project file format
- [SETUP.md](SETUP.md) — installation and command-line builds
- [AAE_RP2350_PORT.md](AAE_RP2350_PORT.md) — C ports against the `rp2350-sdk/` shim
