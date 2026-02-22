# BuildTools: Modular Compilation Pipeline for VPy

A from-scratch redesign of the compiler architecture, breaking the monolithic pipeline into 9 independent crates with clear interfaces and comprehensive tests.

## Why This Matters

The current compiler (in `core/`) has fundamental issues:
- **No single source of truth**: Addresses calculated in 3 places (fragile)
- **Not a real linker**: Just divides ASM files (no relocation)
- **PDB addresses guessed**: Reconstructed from bank files (unreliable)
- **Multibank broken**: Linker doesn't properly allocate functions
- **Hard to test**: No clear phase boundaries

**This pipeline fixes all of that** by implementing a real compiler with:
- ✅ Separate phases with type-safe interfaces
- ✅ Single source of truth (linker computes all addresses)
- ✅ Real relocations and symbol table
- ✅ Comprehensive tests for single + multibank
- ✅ Correct PDB generation from linker output

## Pipeline Architecture

```
Phase 1: vpy_loader     → ProjectInfo {metadata, files, assets}
Phase 2: vpy_parser     → Vec<Module> {AST per file}
Phase 3: vpy_unifier    → UnifiedModule {merged AST + symbols}
Phase 4: vpy_bank_allocator → BankLayout {bank assignments}
Phase 5: vpy_codegen    → GeneratedIR {ASM per bank}
Phase 6: vpy_assembler  → Vec<ObjectFile> {bytes + relocs}
Phase 7: vpy_linker     → LinkedBinary + SymbolTable ⭐ SOURCE OF TRUTH
Phase 8: vpy_binary_writer → .bin file (on disk)
Phase 9: vpy_debug_gen  → .pdb file (from linker data)
```

## Current Status

### ✅ Phase 1: vpy_loader (COMPLETE)
- Parses `.vpyproj` metadata (single + multibank config)
- Discovers all `.vpy` files recursively
- Discovers asset files (`.vec`, `.vmus`)
- **Tests**: 5/5 passing (single-bank, multibank, error cases)

### ✅ Phase 2: vpy_parser (COMPLETE)
- Full lexer with 11 tests passing
- Complete AST types (345 lines)
- Parser with 41 tests passing (1496 lines)
- Expression, statement, and module parsing

### ✅ Phase 3: vpy_unifier (COMPLETE)
- Module dependency graph with cycle detection
- Topological sorting (Kahn's algorithm)
- Symbol resolution with MODULE_symbol naming
- **Symbol case fix**: Preserves lowercase symbols, uppercase prefixes only
- 24 comprehensive tests passing

### ✅ Phase 4: vpy_bank_allocator (COMPLETE)
- **Call graph analysis**: Function dependency tracking
- **Sequential allocation**: First-fit assignment to banks
- **Tests**: 12 passing (single-bank, multibank, overflow)
- **Status**: Ready for Phase 7 linker integration

### ✅ Phase 5: vpy_codegen - Stack Balance Validation (COMPLETE)
- **Tree Shaking System**: Automatic detection and elimination of unused runtime helpers
- **Modular Architecture**: 5 helper modules (drawing, math, joystick, level, utilities)
- **Usage Analysis**: AST traversal detects which helpers are actually needed
- **Results**: Only emits helpers used in code (e.g., joystick_test: 3/17 helpers)
- **Benefits**: Smaller binaries, zero manual configuration, automatic dependency resolution

**Stack Balance Validator** (NEW - 2026-02-22):
- **Purpose**: Catches stack corruption bugs at compile time
- **Validation**: Checks PSHS/PULS balance in all generated functions
- **Detection**: Reports unmatched pushes/pops with exact line numbers and stack trace
- **Scope**: Validates each function independently (PSHS/PULS within function must balance)
- **Implementation**: `stack_validator.rs` module (280 lines, 5 tests)
- **Error Messages**: Detailed stack traces show depth at each push/pop
- **Result**: **FOUND 5 STACK IMBALANCES** in pang example (LOOP_BODY +2, IF_NEXT_1 +2, 3x underflow)
- **Key Finding**: Current codegen has unmatched PSHS/PULS pairs - preventing silent runtime hangs

### ✅ Phase 6: vpy_assembler - Critical Fixes (2026-01-17)
- **ORG Directive Processing**: Fixed multibank boot sequence
  - Added `set_org()` method with 0xFF padding
  - Fixed parsing to recognize `$FFF0` and `0xFFF0` formats
  - Applies ORG directives sequentially (was ignoring all after first)
  
- **Interrupt Vector Fix**: Removed from cartridge ROM
  - Vectors are in BIOS ROM ($E000-$FFFF) and configurable RAM ($CBF2-$CBFB)
  - Cartridge ROM only contains code ($0000-$7FFF)
  - Reference: http://vide.malban.de/27th-of-november-2020-lose-ends-irq
  
- **Missing Opcodes Added**: Fixed desensamblador
  - 0xFC (LDD extended), 0xDC (LDD direct)
  - 0xFD (STD extended), 0xBF (STX extended)
  - 0xFE (LDU extended)

### ✅ Phase 6.7: Multi-bank ROM Generation (IMPLEMENTED 2026-01-17)

**Status**: ✅ FULLY IMPLEMENTED - Dynamic bank allocation

Buildtools now supports multi-bank cartridges up to 4MB:

**Features**:
- Automatic detection of multibank projects (ROM size > 32KB)
- Dynamic bank count calculation (supports 1-256 banks)
- All banks marked in ASM with proper headers
- Helpers bank dynamically placed at last bank position
- Sequential bank model: ALL banks use ORG $0000
- No hardcoded bank numbers - fully scalable

**Configuration** (in .vpy source):
```python
META ROM_TOTAL_SIZE = 524288   # 512KB (32 banks)
META ROM_BANK_SIZE = 16384      # 16KB per bank (standard)

# Supports up to 4MB:
# META ROM_TOTAL_SIZE = 4194304   # 4MB (256 banks)
```

**Generated Bank Structure**:
```
; ================================================
; BANK #0 - Entry point and main code
; ================================================
    ORG $0000
    [Vectrex header + START label + user functions]

; ================================================
; BANK #1 - 0 function(s) [EMPTY]
; ================================================
    ORG $0000
    ; Reserved for future code overflow

; ... (Banks 2-30: Empty placeholders)

; ================================================
; BANK #31 - 0 function(s) [HELPERS ONLY]
; ================================================
    ORG $0000
    ; Runtime helpers (VECTREX_PRINT_TEXT, etc.)
```

**Implementation**:
- `vpy_codegen/src/m6809/mod.rs`: Emits ALL bank markers dynamically
- `vpy_cli/src/main.rs`: Detects multibank and invokes multi_bank_linker
- `vpy_linker/src/multi_bank_linker.rs`: Ported from core, assembles each bank

**Key Technical Details**:
- Helpers bank = `(rom_total_size / rom_bank_size) - 1`
- All banks 1 to (helpers_bank - 1) marked as [EMPTY]
- Compatible with multi_bank_linker::split_asm_by_bank()
- Tested with 512KB ROM (32 banks) - generates valid binary

### Phase 7: ROM Linker
  - Added `set_org()` method with 0xFF padding to `binary_emitter.rs`
  - Modified `asm_to_binary.rs` to parse and apply ORG directives
  - Removed "ORG ya se manejó" ignore pattern that broke multibank
  - Enhanced symbol resolution logging (shows buffer length)
- **Interrupt Vector Fix**: Cartridge ROM architecture corrected
  - Removed vector generation at $FFF0-$FFFF (they belong in BIOS ROM)
  - Hardware vectors ($FFF0-$FFFF) are in BIOS ROM ($E000-$FFFF)
  - Configurable vectors ($CBF2-$CBFB) are in RAM per VECTREX.I
  - BIOS verifies copyright and jumps to $0000 (cartridge entry point)
- **Modular Refactoring**: Extracted 480 lines into 3 focused modules
  - `parser.rs` (130 lines, 4 tests): Directive/label parsing
  - `expression.rs` (180 lines, 5 tests): Arithmetic evaluation
  - `symbols.rs` (170 lines, 3 tests): VECTREX.I loading
- **Result**: Binary now 32KB (was 64KB). test1.bin runs correctly in emulator.
- **Reference**: http://vide.malban.de/27th-of-november-2020-lose-ends-irq

### ✅ Phase 7: vpy_linker (IN PROGRESS - Day 2/5.5 Complete)
**Purpose**: Links .vo object files into final multibank ROM

**Day 1 Complete** (2026-01-17):
- ✅ `object.rs`: VectrexObject format (305 lines, 3 tests)
- ✅ Section/Symbol/Relocation types with serde
- ✅ Binary serialization with magic number validation
- ✅ Tests: create_empty, section_size, serialization

**Day 2 Complete** (2026-01-17):
- ✅ `resolver.rs`: 4-step symbol resolution algorithm (441 lines, 5 tests)
- ✅ Step 1: collect_symbols() - Build global table, detect duplicates
- ✅ Step 2: verify_imports() - Check for undefined symbols
- ✅ Step 3: assign_addresses() - Calculate final addresses
- ✅ Step 4: apply_relocations() - Patch code with 7 relocation types
- ✅ Tests: collect, duplicate, verify success/fail, assign
- ✅ Enhanced error.rs with DuplicateSymbol, UndefinedSymbols, etc.

**Day 3 Complete** (2026-01-17):
- ✅ `bank_layout.rs`: Multibank ROM integration (356 lines, 3 tests)
- ✅ BankConfig: vectrex_512kb(), single_bank()
- ✅ MultibankLayout: Full pipeline (collect → verify → assign → apply → build)
- ✅ Section assignment algorithm (sequential, respects bank limits)
- ✅ Address assignment per bank (switchable $0000 / fixed $4000)
- ✅ Bank data building with symbol tracking
- ✅ File output: write_banks() (per-bank), write_merged() (single file)
- ✅ Tests: single_bank, multibank_assignment, section_overflow

**Day 4 Complete** (2026-01-17):
- ✅ `integration_test.rs`: End-to-end pipeline validation (313 lines, 5 tests)
- ✅ test_end_to_end_simple_link: Basic single object → binary
- ✅ test_end_to_end_multibank: Multi-object bank allocation
- ✅ test_end_to_end_with_imports: Symbol resolution + relocation patching
- ✅ test_end_to_end_file_output: Binary file I/O
- ✅ test_end_to_end_symbol_table: Multi-section address calculation
- ✅ **Complete pipeline verified**: Object → Resolve → Relocate → Layout → Output

**Pending**:
- Day 5: Cross-bank call wrappers + polish

### ⏳ Phase 8-9: Planned
- Phase 8: vpy_binary_writer (trivial ROM assembly)
- Phase 9: vpy_debug_gen (PDB generation)

## Getting Started

### Run Tests
```bash
cd buildtools
cargo test --all         # Run all tests
cargo test vpy_loader   # Run specific crate
```

### Test Script
```bash
./test_buildtools.sh    # Run all crate compilation checks
```

### Browse Documentation
```bash
cat ARCHITECTURE.md     # Detailed pipeline design
cat STATUS.md          # Current progress
```

## File Structure

```
buildtools/
├── Cargo.toml              # Workspace definition
├── ARCHITECTURE.md         # Pipeline design details
├── STATUS.md              # Progress tracking
├── TREE_SHAKING_COMPLETE.md # Tree shaking documentation
├── test_buildtools.sh     # Test all crates
│
├── vpy_loader/            ✅ Complete (Phase 1)
│   ├── src/lib.rs         (413 lines, 5 tests passing)
│   ├── Cargo.toml
│   └── tests/
│
├── vpy_parser/            ✅ Complete (Phase 2)
│   ├── src/
│   │   ├── lib.rs
│   │   ├── ast.rs         (345 lines)
│   │   ├── lexer.rs       (570 lines, 11 tests)
│   │   ├── parser.rs      (1496 lines, 41 tests)
│   │   └── ...
│   ├── Cargo.toml
│   └── tests/
│
├── vpy_unifier/           ✅ Complete (Phase 3)
│   ├── src/
│   │   ├── lib.rs
│   │   ├── graph.rs       (cycle detection, topological sort)
│   │   ├── resolver.rs    (MODULE_symbol naming)
│   │   └── ...
│   ├── Cargo.toml
│   └── tests/             (24 tests passing)
│
├── vpy_bank_allocator/    ✅ Complete (Phase 4)
│   ├── src/
│   │   ├── lib.rs         (177 lines, 3 tests)
│   │   ├── graph.rs       (270 lines, 4 tests - call graph analysis)
│   │   ├── allocator.rs   (329 lines, 5 tests - sequential assignment)
│   │   └── error.rs
│   ├── Cargo.toml
│   └── tests/             (12 tests passing)
│
├── vpy_codegen/           ✅ Optimization Complete (Tree Shaking)
│   ├── src/m6809/
│   │   ├── helpers.rs     (analysis + coordination)
│   │   ├── drawing.rs     (DRAW_CIRCLE, DRAW_RECT)
│   │   ├── math.rs        (MUL16, DIV16, SQRT, POW, etc.)
│   │   ├── joystick.rs    (J1X, J1Y, J2X, J2Y)
│   │   ├── level.rs       (SHOW_LEVEL)
│   │   └── utilities.rs   (RAND, FADE_IN/OUT)
│   └── ...
│
├── vpy_assembler/         ✅ Refactored + Fixed (Phase 6)
│   ├── src/m6809/
│   │   ├── asm_to_binary.rs (2651 lines, 15 tests)
│   │   ├── binary_emitter.rs (set_org() with padding, symbol logging)
│   │   ├── parser.rs        (130 lines, 4 tests - directives)
│   │   ├── expression.rs    (180 lines, 5 tests - arithmetic)
│   │   ├── symbols.rs       (170 lines, 3 tests - VECTREX.I)
│   │   └── mod.rs
│   ├── REFACTOR_PROGRESS.md (detailed module documentation)
│   └── Cargo.toml
│   └── Note: ORG processing fixed, interrupt vectors removed from cartridge
│
├── vpy_disasm/            ✅ Complete (Disassembler)
│   ├── src/lib.rs         (MC6809 instruction decoder)
│   ├── Added opcodes: 0xFC (LDD ext), 0xFD (STD ext), 0xBF (STX ext)
│   │                  0xFE (LDU ext), 0xDC (LDD direct)
│   └── Cargo.toml
│
├── vpy_linker/            🚀 Phase 7 (IN PROGRESS)
├── vpy_binary_writer/     ✅ Complete (Phase 8)
└── vpy_debug_gen/         ⏳ Phase 9 (TODO)
```

## Key Design Decisions

### 1. One Crate Per Phase
- Clear separation of concerns
- Testable in isolation
- Can parallelize builds
- Easy to debug

### 2. Type-Safe Interfaces
```rust
// Not this:
emit_codegen(source: String) -> String

// But this:
pub fn codegen(unified: UnifiedModule, layout: BankLayout) 
    -> Result<GeneratedIR, CodegenError>
```

### 3. Single Source of Truth
- **Only the linker computes final addresses**
- All other phases pass data downstream
- PDB derives from linker, guaranteed correct
- IDE breakpoints work reliably

### 4. Real Linker (Not "Divide and Hope")
- Takes object files with relocations
- Places code in address space
- Applies relocations
- Generates symbol table
- Returns authoritative address map

## Testing Strategy

Every phase tested with:
- **Single-bank**: Code must fit in 32KB
- **Multibank**: Code distributed across 32×16KB banks
- **Error cases**: Missing files, invalid code, etc.

Example test:
```rust
#[test]
fn test_load_multibank_project() {
    let info = load_project(&proj_path).unwrap();
    assert!(info.is_multibank());
    assert_eq!(info.num_banks(), 32);
    assert_eq!(info.source_files.len(), 1);
}
```

## Porting from core/ (Next Steps)

1. **vpy_parser** (~1-2 days)
   - Move core/src/parser.rs → buildtools/vpy_parser/
   - Define AST types
   - Add single + multibank tests

2. **vpy_unifier** (~1 day)
   - Move core/src/unifier.rs → buildtools/vpy_unifier/
   - Import resolution logic
   - Multi-module tests

3. **vpy_bank_allocator** (~2 days, NEW)
   - Graph analysis for function placement
   - Bank assignment strategy
   - Single vs multibank logic

4. **vpy_codegen** (~2 days)
   - Move core/src/backend/m6809/mod.rs
   - Generate ASM per bank
   - Metadata emission

5. **vpy_assembler** (~1 day)
   - Move core/src/backend/asm_to_binary.rs
   - Produce object files with relocations
   - Symbol extraction

6. **vpy_linker** (~3 days, CRITICAL)
   - NEW: Real linker implementation
   - Address space allocation
   - Relocation application
   - Symbol table generation

7. **vpy_binary_writer** (~0.5 days)
   - Trivial: just write bytes to disk

8. **vpy_debug_gen** (~1 day)
   - NEW: Derive PDB from linker
   - Source map generation
   - JSON output

**Total: ~2 weeks** for complete pipeline with all tests

## Comparison: Old vs New

| Aspect | Old (core/) | New (buildtools/) |
|--------|---|---|
| Monolithic | Single binary | 9 independent crates |
| Address calc | 3 places | 1 place (linker) |
| Linker | Divides ASM | Real relocation |
| PDB | Guesses | Derives from linker |
| Tests | Implicit | Explicit single/multi |
| Debuggability | Hard | Easy (clear phases) |

## Contributing

Follow this pattern for each new crate:

1. Create directory and Cargo.toml
2. Implement minimal API in lib.rs
3. Add 5-10 representative tests
4. Run `cargo test` locally
5. Document interfaces and design decisions
6. Mark as "complete" when 100% tests pass

## Questions?

See:
- `ARCHITECTURE.md` - Detailed design
- `STATUS.md` - Progress and next steps
- Individual crate Cargo.toml files for dependencies
