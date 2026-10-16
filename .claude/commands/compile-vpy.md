Compile a VPy project with the buildtools compiler (`vpy_cli`).

Usage: /compile-vpy [path-to-project.vpyproj] [target]

If $ARGUMENTS names a project, use it. Otherwise list the `.vpyproj` files under `examples/` and ask which one to compile. The target is `m6809` (default; Vectrex cartridge), `rp2350`, `uvm2` or `pitrex`.

From the repo root, run the compiler from source so that it includes any local changes:
```bash
cargo run --manifest-path buildtools/Cargo.toml --bin vpy_cli -- build <path/to/project.vpyproj> --target <target>
```
To use the copy the IDE ships instead (faster, but possibly older): `./ide/electron/resources/vpy_cli build <project.vpyproj> --target <target>`.

Always build the `.vpyproj`, not a single `.vpy`: the project file gives the sources, and modules only resolve through it. A build writes into the project's `build/` folder (`<name>.bin` for m6809).

Report:
- compilation errors with the phase, file and line (`Phase N:` headings in the output)
- the output binary, its size and free space
- single-bank or multibank (`META ROM_TOTAL_SIZE` / `ROM_BANK_SIZE` in the code, or `rom_total_size` / `rom_bank_size` in `[project]`)

If the build fails:
- `Undefined symbol: <HELPER>` on m6809: check the known helper-scan gaps (a builtin used only inside a `for` body, `J1_X()`/`J1_Y()` directly in an `if` comparison, a lower-case cross-module call such as `physics.clamp_x`).
- An asset problem: run `vpy_cli check-asset <file>` on the assets in `assets/`. A build only warns about an asset that fails to load.
- uvm2 builds need the pinned SDK and the Arm GNU Toolchain (`docs/SDK_VERSIONS.md`).
- To inspect the code: `vpy_cli asm <project.vpyproj> -o /tmp/out.asm`.
