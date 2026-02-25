# Changelog

All notable changes to the Vectrex Studio project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Pending
- Resolve BIOS symbols in second pass (Vec_Misc_Count)
- Implement LEA instructions (LEAX, LEAY, LEAU, LEAS)
- Indexed addressing with numeric offsets (5,X, -2,Y)
- Auto-increment/decrement (,X+, ,-X)

---

## [v0.1.1] — 2026-02-25

### Fixed — Core compiler (`vectrexc`)

- **MOVE builtin**: Was completely absent from the builtins list → generated
  `JSR MOVE` (undefined symbol at link time). Now correctly stores `x → VPY_MOVE_X`,
  `y → VPY_MOVE_Y` (signed byte RAM vars) and `DRAW_LINE_WRAPPER` adds the offset
  via `ADDA/ADDB` before `Moveto_d`.
- **MIN / MAX / CLAMP**: Not in `BUILTIN_ARITIES` (semantic gate) → "Unknown function"
  error. Added with correct arities (2, 2, 3).
- **MIN / MAX / CLAMP**: `TMPLEFT`/`TMPRIGHT` RAM slots not allocated because
  `analyze_runtime_usage()` never scanned for those calls. Added detection.
- **MIN / MAX**: Used `SUBD + BGT` which produced wrong results (30 returned 70).
  Replaced with `CMPD + BLE/BGE` (non-destructive comparison) matching buildtools.
- **ABS / MIN / MAX / CLAMP**: Labels emitted as `LABEL: INSTRUCTION` on one line.
  The core assembler parses the mnemonic as `"LABEL:"` and silently discards the
  instruction. Fixed by separating labels onto their own line.
- **DRAW_CIRCLE runtime path**: Was using an 8-segment octagon. Upgraded to 16-segment
  polygon (matching the constant-path and buildtools output).

### Fixed — Buildtools compiler (`vpy_cli`)

- **MOVE builtin**: Was calling `Moveto_d_7F` without the required BIOS `DP=$D0` setup,
  and `DRAW_LINE_WRAPPER`'s `Reset0Ref` call would have cancelled the position anyway.
  Now uses the same `VPY_MOVE_X/Y` RAM-offset approach as core.
- **DRAW_CIRCLE runtime path**: Upgraded from 8-segment to 16-segment polygon using
  MUL-based fixed-point fractions (a=0.3827r, b=0.3244r, c=0.2168r, d=0.0761r).

### Added — Both assemblers

- **MUL instruction** (opcode `0x3D`): Added to both `core` and `buildtools` assemblers.
  Used by the DRAW_CIRCLE 16-segment path for fixed-point fraction computation.

### Added — Examples / Snippets

New `examples/individual_tests/` projects (each is a self-contained `.vpyproj`):

| Project | Tests |
|---------|-------|
| `draw_circle` | DRAW_CIRCLE with various radii |
| `draw_line` | DRAW_LINE basic and delta tests |
| `draw_move` | MOVE + DRAW_LINE coordinate offset |
| `draw_rect` | DRAW_RECT bounding boxes |
| `draw_vector` | DRAW_VECTOR asset rendering |
| `joystick_buttons` | J1_BUTTON_1–4 debounce display |
| `joystick_position` | J1_X / J1_Y analog and digital |
| `math_functions` | abs, min, max, clamp |
| `play_music` | PLAY_MUSIC / STOP_MUSIC |
| `print_number` | PRINT_NUMBER signed decimal |
| `print_text` | PRINT_TEXT positioning |

## [November 15, 2025] - Native M6809 Assembler - Massive Implementation 🚀

### Major Achievement: 23 New MC6809 Instructions

#### Added - Load/Store 16-bit Operations
- **LDU** (Load U register): immediate (0xCE), extended (0xFE)
- **STU** (Store U register): extended (0xFF)
- **LDD indexed** (0xEC + postbyte): Support for ,X ,Y ,U ,S without offset

#### Added - 16-bit Arithmetic
- **ADDD** (Add to D): immediate (0xC3), extended (0xF3)
- **SUBD** (Subtract from D): immediate (0x83), extended (0xB3)
- **ABX** (Add B to X): 0x3A
- **CMPD** (Compare D): immediate (0x1083), extended (0x10B3)

#### Added - 8-bit Logic & Shifts
- **ANDB** (AND B): immediate (0xC4)
- **ASLA/ASLB** (Arithmetic Shift Left): 0x48/0x58
- **ROLA/ROLB** (Rotate Left through Carry): 0x49/0x59
- **LSRA/LSRB** (Logical Shift Right): 0x44/0x54
- **RORA/RORB** (Rotate Right through Carry): 0x46/0x56

#### Added - Long Branches (16-bit offset)
- **LBRA** (Long Branch Always): 0x16
- **LBEQ, LBNE, LBCS, LBCC**: 0x1027, 0x1026, 0x1025, 0x1024
- **LBLT, LBGE, LBGT, LBLE**: 0x102D, 0x102C, 0x102E, 0x102F
- **LBMI, LBPL**: 0x102B, 0x102A

#### Added - Aliases & Memory
- **BLO/BHS**: Aliases for BCS/BCC (0x25/0x24)
- **CLR extended**: Clear memory (0x7F)

### Fixed
- **BCS/BCC**: Now support labels, not just numeric offsets
- **parse_indexed_postbyte**: Corrected parameter mismatch
- **emit_ldd**: Added indexed mode support (,X ,Y ,U ,S)

### Documentation
- **Added**: SETUP.md - Complete setup guide from scratch
- **Added**: INDEX.md - Navigable documentation index
- **Updated**: COMPILER_STATUS.md - Complete native assembler section with roadmap
- **Updated**: README.md - Quick start and SETUP.md references

### Metrics
- **Instructions**: 40 → 63 (+57.5%)
- **rotating_line_correct.vpy**: 40 → 242 lines processed (+505%)
- **MC6809 Coverage**: ~35% → ~55%

### Performance
- **3-Phase Architecture**: PRE-PASS (INCLUDE + EQU) → PASS1 (code + placeholders) → PASS2 (symbol resolution)
- **258 BIOS Symbols**: Loaded from VECTREX.I
- **Case-insensitive**: Symbol lookup with automatic uppercase conversion
- **Expressions**: Recursive evaluation (VAR+1, LABEL-2)

## [September 26, 2025] - Test Infrastructure Consolidation & Organization 🧪

### Test Infrastructure Overhaul
- **Complete Test Reorganization**: Transformed flat test structure into organized hierarchy
- **Eliminated 24 Duplicate Tests**: Removed redundant tests across B register, memory, branch, and logic operations
- **281 Total Tests**: 256 opcode tests + 19 component tests, all passing with 100% success rate

### Added
- **Structured Test Organization**:
  - `tests/opcodes/` - Organized by functionality (arithmetic, branch, comparison, data_transfer, logic, register, stack)
  - `tests/components/` - Separated by domain (integration, hardware, engine, memory, cpu)
  - One file per opcode rule with descriptive naming (`test_adda.rs`, `test_jsr.rs`)
- **Standardized Test Configuration**:
  - RAM mapped at 0xC800-0xCFFF for all tests
  - Stack initialized at 0xCFFF consistently
  - Template-based test structure with `setup_emulator()` helper
  - Mandatory verification of registers, flags, memory, and cycles
- **Component Test Categories**:
  - Integration tests for component coordination
  - Hardware tests (PSG, Screen, Shift Register, Timers)
  - Engine tests (Types, DelayedValueStore)
  - Memory device tests
  - CPU-specific functionality tests

### Removed
- **Duplicate Test Elimination**:
  - B register opcodes: 4 duplicates removed
  - Memory operations: 6 duplicates removed
  - Branch operations: 3 duplicates removed  
  - Logic operations: 11 duplicates removed (AND, EOR, OR)
  - Empty/placeholder files cleaned up

### Changed
- **Test Structure**: From flat 280 tests to organized 281 tests (net +1 after duplicates removed)
- **Naming Convention**: Consistent `test_[opcode]_[mode]_0x[hexcode]` format
- **Memory Layout**: Standardized 0xC800 RAM start, 0xCFFF stack across all tests
- **Documentation**: Updated copilot-instructions.md with comprehensive test rules and templates

### Technical Improvements
- **Maintainability**: Clear separation between opcode and component testing
- **Discoverability**: Logical categorization makes finding specific tests trivial
- **Consistency**: Standard memory configuration eliminates test variance
- **Extensibility**: Template structure facilitates adding new tests

## [September 25, 2025] - 99.2% Vectrexy Compliance Achievement 🌟

### Major Achievement
- **99.2% CPU Compliance**: Achieved near-perfect compliance with Vectrexy C++ reference implementation
- **222 of 224 opcodes implemented** - Only 2 non-critical opcodes missing (SYNC, RESET*)
- **All 270+ unit tests passing** with 100% success rate
- **Complete interrupt handling compliance** - 1:1 behavioral match with Vectrexy

### Added
- **Comprehensive Compliance Analysis**:
  - `compliance_check.py`: Full opcode comparison against Vectrexy reference
  - `missing_opcodes.py`: Accurate analysis excluding illegal opcodes
  - Detailed compliance reporting with 99.2% functional coverage
- **Complete CPU Implementation**:
  - All arithmetic operations (ADD, SUB, ADC, SBC) across all addressing modes
  - All logic operations (AND, OR, EOR, BIT) with full register support
  - All compare operations (CMP, CMPX, CMPY, CMPD, CMPU, CMPS)
  - All shift/rotate operations (LSL, LSR, ROL, ROR, ASL, ASR)
  - Complete branch operation set (short and long branches)
  - Full register transfer and exchange operations (TFR, EXG)
  - Stack operations with exact Vectrexy compliance (PSHS, PULS, PSHU, PULU)

### Fixed
- **Interrupt Stack Compliance**: 
  - All 7 interrupt tests now pass with perfect Vectrexy behavioral match
  - CWAI/SWI/RTI stack push/pop order exactly matches C++ reference
  - CC register Entire bit handling in interrupt contexts
  - Stack pointer management during interrupt operations
- **Test Infrastructure**:
  - Memory mapping constraints properly enforced (0xC800-0xCFFF RAM)
  - PC addresses corrected for executable memory regions
  - NOP instructions added at jump destinations for valid execution

### Technical Validation
- **Perfect Behavioral Match**: Core CPU operations identical to Vectrexy
- **Comprehensive Test Coverage**: Every opcode category thoroughly validated
- **1:1 Implementation**: Direct port maintains exact C++ semantics
- **Production Ready**: Emulator capable of running real 6809 code including Vectrex BIOS

### Documentation
- Corrected inaccurate compliance analysis (`analyze_missing_opcodes.py` identified as flawed)
- Added proper Vectrexy comparison methodology
- Comprehensive achievement documentation

## [September 25, 2025] - Long Branch Operations Implementation

### Added
- **Long Branch Operations**: Complete 16-opcode implementation with 1:1 C++ compliance
  - LBRA (0x16): Long Branch Always - unconditional 16-bit offset jump
  - 15 Long Conditional Branches (0x1021-0x102F): LBRN, LBHI, LBLS, LBCC, LBCS, LBNE, LBEQ, LBVC, LBVS, LBPL, LBMI, LBGE, LBLT, LBGT, LBLE
  - Correct cycle timing: 5 base cycles + 1 extra when branch taken (except LBRA always 5)
  - Full signed 16-bit offset support for both positive and negative jumps
  - Complete integration with page 0/page 1 opcode tables
  - 13 comprehensive tests covering all conditions and edge cases

### Technical
- **C++ Reference Compliance**: Perfect 1:1 port from Vectrexy OpLBRA() and OpLongBranch(condFunc) 
- **Memory Architecture**: Tests using proper 0xC800 RAM mapping as specified
- **Opcode Table Integration**: LBRA added to page 0, all conditional long branches in page 1
- **Cycle Management**: Proper add_cycles() pattern maintaining timing accuracy
- **Comprehensive Test Coverage**: Both basic functionality and edge case validation
- **Branch Condition Logic**: All 6809 condition code combinations correctly implemented

### Fixed
- Missing LBRA (0x16) entry in opcode lookup table that was causing "Illegal instruction" errors
- Proper API usage patterns in test infrastructure

## [September 25, 2025] - Comprehensive Stack Order Compliance

### Added
- **Stack Order Compliance Tests**: Complete test suite for all stack operations with 1:1 C++ compliance verification
  - 16 comprehensive tests in `test_stack_compliance_comprehensive.rs`
  - PSHS/PULS/PSHU/PULU operations fully tested (11 tests)
  - JSR/BSR stack order compliance tests (5 tests)
  - Multiple JSR call stack accumulation validation
  - Exact stack layout verification: [HIGH][LOW] bytes as per C++ Push16 behavior
  - All 289 tests passing with zero failures

### Fixed
- Removed obsolete debug test files that used deprecated APIs
- Cleaned up compilation errors from outdated stack test files

### Technical
- Stack operations now fully validated against C++ reference implementation
- Perfect 1:1 compliance with Vectrexy's Push16/Pop16 behavior
- Ready for RTS (0x39) implementation to complete JSR→RTS cycle

## [September 24, 2025] - JSR/BSR and TFR/EXG Implementation

### Added
- **JSR/BSR Subroutine Opcodes**: Complete implementation with 1:1 C++ compliance
  - JSR Direct (0x9D), Extended (0xBD), Indexed (0xAD)
  - BSR Relative (0x8D), LBSR Long Relative (0x17)
  - Proper stack management and return address handling
  - 10 comprehensive tests with exact cycle timing verification

- **TFR/EXG Opcodes**: Transfer and Exchange operations (0x1F/0x1E)
  - Complete 1:1 port from Vectrexy C++ implementation
  - 8-bit and 16-bit register transfers
  - 8 comprehensive tests covering all register combinations

- **6809 Stack Operations**: Full PSHS/PULS/PSHU/PULU implementation
  - Perfect bit processing order compliance with C++ reference
  - System and User stack separation
  - Multiple register combinations support

### Improved
- **Branch Opcodes**: Complete 0x20-0x2F range with comprehensive tests
- **Arithmetic/Logic**: Extended addressing modes for all operations
- **LEA Opcodes**: Load Effective Address family complete
- **CMP Instructions**: All variants implemented (CMPA/B/D/X/Y/S/U)

### Technical
- 54+ opcodes implemented with 1:1 Vectrexy compliance
- Comprehensive test coverage with cycle-accurate timing
- Automatic TODO list generation system
- Compiler warnings resolution while preserving compatibility

## [September 22-23, 2025] - Emulator v2 Foundation

### Added
- **Emulator v2**: Complete rewrite with 1:1 Vectrexy port architecture
  - Main Emulator class with exact C++ behavior
  - Memory devices following Vectrexy patterns
  - VIA6522 with corrected method signatures
  - MemoryBus ownership pattern matching C++

- **AY-3-8912 PSG**: Complete audio generator implementation
  - Full Programmable Sound Generator
  - Critical JSR timing bug fixes
  - Performance optimizations with trace commenting

### Fixed
- VIA delegation and integrator MUX implementation
- Copyright timeout optimizations
- Compilation errors and corrupted test files

### Documentation
- Updated SUPER_SUMMARY with PSG completion status
- SIMULATION_LIMITATIONS audio section marked complete
- Comprehensive VIA6522 and emulator_v2 status documentation

## [September 20, 2025] - Compiler Pipeline and BIOS Integration

### Added
- **Vendorization**: Complete source integration
  - Original JSVecx sources vendored (dropped submodule)
  - Vectrexy parity host sources integrated
  - Eliminated external dependencies

- **Compiler Pipeline**: Complete semantic analysis and optimization
  - S3 semantic validation pass with comprehensive tests
  - S4-S6 optimization passes (constant folding, dead code elimination)
  - 16-bit documentation and unused variable warnings
  - CallInfo spans for enhanced error reporting

- **BIOS Integration**: Enhanced emulator-UI coordination
  - BIOS frame and draw vector line exports
  - Instruction throttling with configurable budgets
  - Enhanced metrics and panel controls

### Improved
- **CPU6809**: Module consolidation and cleanup
  - Eliminated duplicate constants and types
  - Centralized illegal opcode handling
  - Enhanced mnemonic mapping for indexed operations

- **Documentation**: Comprehensive status tracking
  - COMPILER_STATUS.md with implementation progress
  - Enhanced SUPER_SUMMARY with technical details
  - BIOS mapping with Init_OS and loop identification

## [September 16-19, 2025] - Core Emulation and IDE Enhancement

### Added
- **Comprehensive Opcode Implementation**:
  - CWAI (0x3C), MUL (0x3D), SYNC relocation to 0x13
  - ABA (0x1B), LDX indexed (0xAE), ADDD immediate (0xC3)
  - DAA (0x19), ORA extended (0xBA), CMPB indexed (0xE1)
  - Enhanced cycle timing and illegal opcode centralization

- **IDE Enhancements**:
  - Trace vectors UI toggle and animation loop logging
  - Robust demo retry with status overlay
  - File system integration with IPC readFileBin
  - Per-document scroll position retention

### Fixed
- **Base Address Handling**: Enforced 0x0000 base with header auto-correction
- **M6809 Backend**: Hardcoded ORG alignment and loader base fixes
- **UI Reliability**: Demo mode triangle fallback and toast notifications

### Technical
- **Metrics System**: Opcode coverage analysis and snapshot functionality
- **Test Infrastructure**: Enhanced interrupt, stack, and transfer test suites
- **Performance**: WASM build integration and artifact management

## [September 12-14, 2025] - LSP and Development Environment

### Added
- **Language Server Protocol (LSP)**:
  - Complete Rust LSP server implementation
  - Diagnostics, completions, hover information
  - Go-to-definition and semantic token support
  - Enhanced syntax highlighting for VPy language

- **IDE Migration**: Tauri to Electron transition
  - Consolidated LSP implementation
  - Dockable resizable panels with Monaco integration
  - Global errors panel with diagnostics aggregation
  - User layout controls and responsive design

- **VS Code Extension**:
  - VPy language support extension (v0.0.3)
  - Syntax highlighting for functions, operators, constants
  - Repository metadata and packaging setup
  - MIT licensing and distribution preparation

### Enhanced
- **Real Emulation Pipeline**: Initial 6809 core with canvas integration
- **Opcode Implementation**: Batches A, B, C with comprehensive instruction sets
- **UI Components**: Output panel with register display and unknown opcode logging

## [September 10-11, 2025] - Vectrex Graphics and Math

### Added
- **Vector Graphics Macros**:
  - DRAW_POLYGON with triangle/square/hexagon examples
  - DRAW_CIRCLE (16-gon approximation)
  - DRAW_CIRCLE_SEG, DRAW_ARC, DRAW_SPIRAL with variable segments
  - Composition demo showcasing all graphic primitives

- **Mathematical Foundation**:
  - Precomputed SIN/COS/TAN lookup tables
  - Built-in trigonometric functions for M6809
  - Optimized polygon rendering with single reset/intensity

- **Vectrex Integration**:
  - Proper BIOS header and equates
  - Built-in intrinsics: print_text, move_to, draw_to, draw_line
  - Hello world example with set_intensity builtin
  - Namespace qualified identifiers (vectrex.*)

### Improved
- **Assembly Output**: Section headers for readability (DEFINE/HEADER/CODE/RUNTIME/DATA)
- **Build Tools**: WSL lwtools installer with Ubuntu auto-install
- **Documentation**: Vector DSL documentation with Pac-Man maze example

## [September 9-10, 2025] - Language Features and Optimization

### Added
- **Control Flow**: Switch/case/default statements with backend lowering
- **String Literals**: Centralized collection and backend emission
- **Local Variables**: 2-byte stack slots with implicit for-loop variables
- **Constant Optimization**: Switch folding with 6809 jump tables

### Enhanced
- **Language Syntax**:
  - Bitwise operators: %, <<, >>, ~
  - Comments support
  - Hex and binary literals
  - Let declarations with prototype local syntax

- **Backend Support**: ARM, Cortex-M, and 6809 assembly generation
- **Optimizer**: Multiple passes with string literal preservation
- **Testing**: Comprehensive test suite with checksum validation

## [September 9, 2025] - Project Genesis

### Added
- **Initial Commit**: Multi-target pseudo-python compiler foundation
  - Support for ARM, Cortex-M, and 6809 architectures
  - Bitwise operations and arithmetic expressions
  - Optimizer passes for dead code elimination
  - Comprehensive manual and README documentation

### Features
- **Core Language**: Expression parsing and AST generation
- **Code Generation**: Multi-target backend architecture
- **Documentation**: Complete manual with examples and usage instructions
- **Build System**: Cargo-based Rust project structure

---

## Summary Statistics

- **Total Commits**: 150+
- **Development Period**: September 9-25, 2025
- **Major Milestones**:
  - Complete 6809 CPU emulation with 289 passing tests
  - LSP server and VS Code extension
  - Comprehensive graphics macro system
  - Multi-target compiler with optimization passes
  - Full Vectrex integration with BIOS support

## Key Technical Achievements

1. **1:1 C++ Compliance**: Perfect emulation matching Vectrexy reference
2. **Comprehensive Testing**: 289 tests with zero failures
3. **Stack Operations**: Complete PSHS/PULS/PSHU/PULU with JSR/BSR
4. **Graphics Pipeline**: Vector drawing with mathematical primitives
5. **Development Environment**: Full IDE with LSP and debugging support
6. **Multi-Architecture**: ARM, Cortex-M, and 6809 backend support
7. **Language Features**: Complete pseudo-python dialect with Vectrex extensions

## Next Steps

- **RTS Implementation**: Complete JSR→RTS cycle for full subroutine support
- **Interrupt Handling**: RTI, SWI, CWAI implementation
- **Advanced Graphics**: Enhanced vector drawing optimizations
- **Performance**: Further emulation speed improvements
- **Documentation**: API reference and tutorial completion