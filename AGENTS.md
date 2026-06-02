# AGENTS.md — VPy Development Guidance

## 🛠️ Toolchain & Commands

### M6809 (Vectrex cartridge)
- **Build All Phases**: `cd buildtools && cargo build --all`
- **Test All Phases**: `cd buildtools && cargo test --all`
- **Test Specific Phase**: `cd buildtools && cargo test -p <crate_name>`
- **Generate ASM**: `cargo run --manifest-path buildtools/Cargo.toml --bin vpy_cli -- asm <source.vpy> > /tmp/out.asm`
- **Full Build**: `cargo run --manifest-path buildtools/Cargo.toml --bin vpy_cli -- build <source.vpy>`

### RP2350 (Cortex-M33 / PiTrex debug cart)
- **Generate ARM ASM**: `cargo run --manifest-path buildtools/Cargo.toml --bin vpy_cli -- asm --target rp2350 <source.vpy> > /tmp/out.s`
- **Full Build**: `cargo run --manifest-path buildtools/Cargo.toml --bin vpy_cli -- build --target rp2350 <source.vpy>`
- **Requires**: `arm-none-eabi-gcc` (Homebrew: `arm-gcc-int@10`) and `hardware/debug_cart/firmware/rp2350_game.ld`

### PiTrex (ARMv6 / Pi Zero)
- **Full Build**: `cargo run --manifest-path buildtools/Cargo.toml --bin vpy_cli -- build --target pitrex <source.vpy>`

## 📐 Critical Architecture Rules

### General
- **Address Truth**: Only the Linker (Phase 7) determines final addresses. Never hardcode/derive them earlier.
- **Interrupts**: No interrupt vectors in ROM; they reside in BIOS ($E000-$FFFF).
- **Symbols**: Use `MODULE_symbol` (uppercase prefix) for all symbols.
- **Multibank**: Every bank starts with `ORG $0000`. Helper bank is always `(total / bank_size) - 1`.
- **Phase Testing**: Every phase must have tests for: single-bank, multibank, and error cases.

### ARM / RP2350
- **SRAM layout**: All VPy runtime variables are fixed `.equ` addresses in SRAM at `0x2007_F000+`. Defined in `buildtools/vpy_codegen/src/arm/ram_layout.rs`. Never use `.bss` for runtime state.
- **AAPCS 8-byte stack alignment**: SP must be 8-byte aligned at every `bl` call.
- **VIA PORT B is shared**: `$D000` controls BOTH the joystick 4052 mux AND PSG BDIR/BC1. **All `bus_write($D000, ...)` must happen inside `vpy_wait_recal` or `vpy_update_buttons` (at frame start).**
- **Joystick axes are cached**: `vpy_j1_x/y` are loaded from SRAM cache. Never call `bus_write($D000)` from user-callable joystick functions.
- **USER_RAM_START**: Currently `0x2007_F3DC`. Append new fixed runtime SRAM variables before this and update `RamAllocator` in `ram_layout.rs`.

## ⚠️ Implementation Gotchas

### M6809
- **Stack Balance**: `PSHS`/`PULS` must be perfectly balanced. Use `TMPVAL`/`TMPPTR` for binary/comparison operations to avoid stack drift.
- **Const Arrays**: Ensure const array pointers are initialized in `MAIN` startup to point to ROM data; otherwise, they default to $0000.
- **Sizing**: Array indexing must account for stride (1 byte for u8/i8, 2 bytes for u16/i16).
- **DP register**: Load RAM values before switching DP. Always use `>` (extended addressing) for RAM reads when DP=$D0.
- **,S++ post-increment**: Adds 1 byte, not 2 — never use for 16-bit temporaries.

### ARM / RP2350
- **Stack args**: Use `sub sp, sp, #8` (not `push {rN}`) to push a stack argument before a `bl` to maintain 8-byte alignment. Clean up with `add sp, sp, #8`.
- **Literal pools**: Each function block using `ldr rN, =SYMBOL` must end with `.ltorg`.
- **VPY_ANIM_STATE_BUF**: Stored at `0x2007_F13E` (2-byte gap). Accessed via `ldr r5, =VPY_ANIM_STATE_BUF`.

## 📚 High-Value References
- `docs/INDEX.md`: Navigation and documentation map.
- `docs/COMPILER_STATUS.md`: Supported opcodes and known gaps.
- `CLAUDE.md`: Detailed pipeline overview, history, and debugging guides.
- `buildtools/vpy_codegen/src/arm/ram_layout.rs`: RP2350 SRAM layout.
- `buildtools/vpy_codegen/src/arm/builtins.rs`: ARM builtin implementations.
- `buildtools/vpy_codegen/src/arm/helpers.rs`: ARM runtime helpers.
- **IDE/MCP**: The MCP server (port 9123) requires the Electron IDE to be running first.

