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
- New projects (`project:create`, VPy or C — templates in `ide/electron/src/projectTemplates.ts`) and C imports are created pinned to the latest tag.
- A project with no `[sdk] version` is pinned to the latest tag the first time the IDE
  resolves its SDK (offline: the newest installed release). The IDE writes the pin into
  the file and logs it in the console:
  `[SDK] <project file> had no [sdk] version — pinned to vX.Y.Z`.
- If the project has no pin, GitHub is unreachable and nothing is installed, the build
  fails with an explicit error.

## Where releases come from

Releases are the tags of the GitHub repository
[`tullulah/uvmc2-sdk`](https://github.com/tullulah/uvmc2-sdk) (`v1.1` … `v1.4.0`); what each
one changes is in the SDK's `CHANGELOG.md` and the tag messages. The uvmc2-starter-kit pins
the SDK as its `sdk` submodule, and a kit release carries the tag of the SDK it pins
(`v1.4.0`; the kit has no `v1.3.2` … `v1.3.4`).

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

`examples/individual_tests_c/common.mk` and `examples/snowbros_sbt/Makefile` take the SDK
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

The **Arm GNU Toolchain** is not downloaded: it is large and platform-specific.

- **Where it is looked for.** vpy_cli and the IDE look in this order:
  1. `UVM2_ARM_TOOLCHAIN`;
  2. `/Applications/ArmGNUToolchain/*`, `/opt/arm-gnu-toolchain*` and `/usr/local/arm-gnu-toolchain*`, newest first;
  3. the `arm-none-eabi-gcc` on the `PATH`, whose `bin/`'s parent is the toolchain (`/usr` for a Linux distribution's package).
- **Passed to builds.** The IDE passes the one it finds to every uvm2 build as `UVM2_ARM_TOOLCHAIN`. That covers `uvm2.mk`, which by itself only looks in the standard locations.
- **nosys.specs.** The toolchain needs newlib's `nosys.specs`, because the pico-sdk links with it. The compiler is asked where that file is (`-print-file-name=nosys.specs`).
  - It is there in the Arm build from developer.arm.com and in the Debian/Ubuntu packages.
  - Homebrew's `arm-none-eabi-gcc` has none and is rejected with that reason.

**Installing it:**

- **macOS:** the Arm `.pkg` (arm-none-eabi, AArch32 bare-metal target), which installs into `/Applications/ArmGNUToolchain`.
- **Linux:** the distribution's packages. A uvm2 build also needs:
  - a host C/C++ compiler and libusb, because the pico-sdk builds `picotool` from source when it is not installed;
  - Rust with the Cortex-M33 target, because the SDK's drawing layer is Rust.

  Tested on Ubuntu 24.04 arm64: `gcc-arm-none-eabi` 13.2 builds a `.um2`.

  ```sh
  # Debian/Ubuntu (the Vectrex Studio .deb recommends all of these, so apt installs them with it)
  sudo apt install gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib \
                   cmake build-essential pkg-config libusb-1.0-0-dev git rustup
  # Fedora
  sudo dnf install arm-none-eabi-gcc-cs arm-none-eabi-gcc-cs-c++ arm-none-eabi-newlib \
                   cmake gcc-c++ pkgconf libusb1-devel git
  # Arch/Manjaro
  sudo pacman -S arm-none-eabi-gcc arm-none-eabi-newlib cmake base-devel libusb git
  # Rust, where the distribution has no rustup package
  curl -sSf https://sh.rustup.rs | sh
  ```

  **Rust is set up by the IDE, once.** The Rust toolchain lives in each user's `~/.rustup`, so no package can install it.
  - Before a uvm2 build, the IDE checks for the `thumbv8m.main-none-eabi` target.
  - If it is missing and rustup is installed, it runs `rustup default stable` when there is no toolchain yet, then `rustup target add`. Every step shows in the build output.

When no toolchain is found, the build error and the Project Settings panel show these
instructions for the machine they run on.

## Related

- [UVM2_TARGET.md](UVM2_TARGET.md) — the UVM2 target and the `uvm2-sdk/` contents
- [IDE_GUIDE.md](IDE_GUIDE.md) — panels, build targets, project file format
- [SETUP.md](SETUP.md) — installation and command-line builds
- [AAE_RP2350_PORT.md](AAE_RP2350_PORT.md) — C ports against the `rp2350-sdk/` shim
