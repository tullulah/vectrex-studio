# VPy Compiler Enhancement Roadmap

## Goal: Variable-Sized Types Support (u8, i8, u16, i16)

**Status:** 🟡 IN PROGRESS (Phase 1-3 complete, Phase 4-5 pending)
**Estimated Effort:** 18-28 developer-hours (3-4 hours remaining)
**Expected Benefit:** ~20% RAM savings (~200 bytes per game) + compile-time type safety
**Backward Compatible:** ✅ Yes (untyped variables default to 16-bit)

---

## Phase 1: Parser (vpy_parser) — ✅ COMPLETE
**Effort:** 1-2 hours | **Risk:** Low | **Blocker for:** Phase 2
**Completed:** 2026-02-21 | **Commit:** feat/variable-sized-types

### Tasks:
- [x] Add `type_annotation: Option<String>` field to `Item::GlobalLet` in `ast.rs`
- [x] Add `type_annotation: Option<String>` field to `Item::Const` in `ast.rs`
- [x] Add `type_annotation: Option<String>` field to `Stmt::Let` in `ast.rs`
- [x] Update parser in `parser.rs` to parse type hints after variable names
  - [x] Handle syntax: `x: u8 = 10`
  - [x] Handle syntax: `const LIMIT: u16 = 1000`
  - [x] Support type names: `u8`, `i8`, `u16`, `i16`
- [x] Add parser tests for type hint syntax
  - [x] Test valid type hints: `x: u8`, `y: i16`, `score: u16`
  - [x] Test without type hints (backward compat): `x = 10`
  - [x] Test error cases: invalid type names, malformed syntax

**Files modified:**
- `buildtools/vpy_parser/src/ast.rs` — Added type_annotation field (+3 lines)
- `buildtools/vpy_parser/src/parser.rs` — Implemented type hint parsing (+188 lines, 10 tests)
- `buildtools/vpy_unifier/src/lib.rs` — Updated pattern matches (+15 lines)

**Results:**
- ✅ Type annotations parse correctly for all 4 types
- ✅ Parser handles both typed and untyped variables (backward compatible)
- ✅ Invalid type names rejected with clear error messages
- ✅ All 143 compiler tests pass (52 parser + 91 other phases)

---

## Phase 2: Type System Infrastructure — ✅ COMPLETE
**Effort:** 1-2 hours | **Risk:** Low | **Depends on:** Phase 1 ✅ | **Blocker for:** Phase 3
**Completed:** 2026-02-21 | **Commit:** feat/variable-sized-types 3489b55f

### Tasks:
- [x] Create `VarType` struct in `vpy_unifier/src/types.rs` (new file)
  - [x] Implement `from_str()` parser for type names
  - [x] Implement `default_i16()` for backward compatibility
  - [x] Implement `from_optional()` for AST integration
- [x] Create type registry/lookup functions
  - [x] `is_valid_type_name()` validation
  - [x] Support u8, i8, u16, i16 with correct metadata
- [x] Add type tracking to symbol table
  - [x] Update `Scope::variables` to use `HashMap<String, VarType>`
  - [x] Add `lookup_var()` method for type queries
  - [x] Default type for untyped vars: `VarType::default_i16()`

**Files modified/created:**
- `buildtools/vpy_unifier/src/types.rs` — NEW: VarType struct + registry (+148 lines)
- `buildtools/vpy_unifier/src/scope.rs` — Updated symbol table (+66 lines)
- `buildtools/vpy_unifier/src/lib.rs` — Export VarType (+2 lines)

**Results:**
- ✅ VarType struct with complete type metadata
- ✅ Type registry with from_str() parser
- ✅ Symbol table now tracks types per variable
- ✅ 16 new type system tests (8 VarType + 8 Scope)
- ✅ All 179 tests pass (36 vpy_unifier + 143 baseline)

---

## Phase 3: Unifier (vpy_unifier) — ✅ COMPLETE
**Effort:** 1-2 hours | **Risk:** Low | **Depends on:** Phase 2 ✅ | **Blocker for:** Phase 4
**Completed:** 2026-02-21 | **Commit:** feat/variable-sized-types 828714e9

### Tasks:
- [x] Create TypeTracker for type mapping during unification
- [x] Implement extract_types_from_module() for unified modules
- [x] Validate type consistency in assignments
  - [x] validate_types() checks for valid type names
  - [x] Support for all 4 type names (u8, i8, u16, i16)
- [x] Add unifier tests for type tracking
  - [x] Type tracking for const and global let items
  - [x] Multiple variable type extraction
  - [x] Untyped variable defaults to i16

**Files modified/created:**
- `buildtools/vpy_unifier/src/type_tracker.rs` — NEW: TypeTracker + extraction (+220 lines)
- `buildtools/vpy_unifier/src/lib.rs` — Export TypeTracker (+2 lines)

**Results:**
- ✅ TypeTracker extracts types from unified modules
- ✅ Support for type validation and consistency checking
- ✅ 7 new type tracking tests
- ✅ All 186 tests pass (43 vpy_unifier + 143 baseline)
- ✅ Type information flows through unified module

---

## Phase 4: Bank Allocator (vpy_bank_allocator) — ⏭️ NEXT (PENDING)
**Effort:** 1-2 hours | **Risk:** Low | **Depends on:** Phase 3 ✅ | **Blocker for:** Phase 5

### Tasks:
- [ ] Query variable types from symbol table instead of assuming 16-bit
- [ ] Calculate per-variable allocation sizes:
  - [ ] u8, i8 → 1 byte
  - [ ] u16, i16 → 2 bytes
- [ ] Update bank size calculations to account for mixed sizes
- [ ] Add allocator tests for mixed-size variables
  - [ ] Array of u8 takes correct amount of space
  - [ ] Array of u16 takes correct amount of space
  - [ ] Mixed arrays allocate correctly

**Files to modify:**
- `buildtools/vpy_bank_allocator/src/lib.rs` — Use variable types for sizing

---

## Phase 5: Codegen (vpy_codegen) — PENDING ⚠️ CRITICAL
**Effort:** 12-20 hours | **Risk:** Medium | **Depends on:** Phase 4 | **Blocker for:** Phase 6

### Core Infrastructure:
- [ ] Create width dispatch helpers in `expressions.rs`
  - [ ] `fn get_var_type(name: &str, ctx: &CodegenContext) -> VarType`
  - [ ] `fn emit_load_into_d(var_name: &str, out: &mut String, ctx: &CodegenContext)`
  - [ ] `fn emit_store_from_d(var_name: &str, out: &mut String, ctx: &CodegenContext)`
  - [ ] `fn emit_type_promotion(from: VarType, to: VarType, out: &mut String) -> VarType`

### Variable Loading/Storage:
- [ ] Update all `LDD` instructions to dispatch based on type:
  - [ ] 8-bit: `LDA` + `CLRB` (zero-extend) or sign-extend with `SXA`
  - [ ] 16-bit: `LDD` (current behavior)
- [ ] Update all `STD` instructions to dispatch based on type:
  - [ ] 8-bit: `STA` (store A only)
  - [ ] 16-bit: `STD` (current behavior)

### Arithmetic Operations:
- [ ] Update `emit_binop()` in `expressions.rs` (lines 142-233)
  - [ ] Add: determine result type based on operand widths
  - [ ] Subtract: same
  - [ ] Multiply: handle 8x8→16, 16x16→32 (may need helpers)
  - [ ] Divide: handle 16÷8→16, 16÷16→16
- [ ] Update all arithmetic helpers:
  - [ ] `math.rs` — Add width dispatch for LDA/STA vs LDD/STD
  - [ ] `math_extended.rs` — Update trig, sqrt, pow for different widths

### Bitwise Operations:
- [ ] Update bitwise AND, OR, XOR, NOT
  - [ ] 8-bit: `ANDA`, `ORA`, `EORA`, `COMA`
  - [ ] 16-bit: `ANDA X`, `ORA X+1`, etc. (current behavior)
- [ ] Update shifts (LSL, ASL, LSR, ASR)
  - [ ] 8-bit: single A or B register
  - [ ] 16-bit: D register with carry

### Array Indexing:
- [ ] Update `emit_index()` in `expressions.rs` (lines 267-299)
  - [ ] Calculate shift amount from element size: `size.log2()`
  - [ ] 8-bit elements: shift 0 (no multiplication)
  - [ ] 16-bit elements: shift 1 (multiply by 2, current behavior)
  - [ ] Future 32-bit: shift 2 (multiply by 4)

### Sign Extension:
- [ ] Implement sign extension for i8→i16 conversions
  - [ ] Use `SXA` or equivalent when loading i8 into D
  - [ ] Zero-extension for u8→u16: `CLRB`

### Type Coercion/Promotion:
- [ ] Implement implicit widening rules:
  - [ ] u8 + i8 → i16 (promote both to signed int)
  - [ ] u8 + u16 → u16 (promote to wider unsigned)
  - [ ] i8 + i16 → i16 (promote to wider signed)
- [ ] Add assignment type checking:
  - [ ] Allow: `x: u16 = y: u8` (implicit widening)
  - [ ] Warn/error: `x: u8 = y: u16` (potential truncation)

### Comparison Operations:
- [ ] Update `CMPD` to dispatch on operand width
  - [ ] 8-bit: `CMPA` or `CMPB`
  - [ ] 16-bit: `CMPD` (current behavior)

### Function Call Parameters:
- [ ] Update parameter passing in `helpers.rs`
  - [ ] Track VAR_ARG0-3 sizes based on function signature
  - [ ] Store appropriately sized value (8 or 16 bit)
- [ ] Update return value handling
  - [ ] Return u8/i8 in A register only
  - [ ] Return u16/i16 in D register (current behavior)

### Context Threading:
- [ ] Extend `CodegenContext` struct
  - [ ] Add `var_sizes: HashMap<String, VarType>`
  - [ ] Thread context through all expression evaluation calls

### Codegen Tests (Required):
- [ ] Unit tests for width dispatch (20+ cases)
  - [ ] Load/store u8, i8, u16, i16
  - [ ] Add/sub/mul/div with each type
  - [ ] Bitwise ops on each type
  - [ ] Array indexing with 1-byte and 2-byte elements
  - [ ] Sign extension (i8→i16)
  - [ ] Zero extension (u8→u16)
  - [ ] Type promotion in mixed expressions
- [ ] Integration tests
  - [ ] Small program with mixed-type variables
  - [ ] Arrays of different element sizes
  - [ ] Function calls with typed parameters
  - [ ] Compile real example (pang) with type hints

**Files to modify:**
- `buildtools/vpy_codegen/src/m6809/expressions.rs` — Width dispatch (LARGEST)
- `buildtools/vpy_codegen/src/m6809/math.rs` — Arithmetic width dispatch
- `buildtools/vpy_codegen/src/m6809/math_extended.rs` — Extended math ops
- `buildtools/vpy_codegen/src/m6809/variables.rs` — Variable allocation
- `buildtools/vpy_codegen/src/m6809/builtins.rs` — Builtin type handling
- `buildtools/vpy_codegen/src/m6809/context.rs` — Add var_sizes to context
- `buildtools/vpy_codegen/src/m6809/helpers.rs` — Parameter passing

---

## Phase 6: Assembler (vpy_assembler) — NO CHANGES
**Status:** ✅ Ready | **Effort:** 0 hours

Assembler already supports all instruction variants (LDA/LDD, STA/STD, etc.)
No changes needed.

---

## Phase 7: Linker (vpy_linker) — NO CHANGES
**Status:** ✅ Ready | **Effort:** 0 hours

Linker operates at symbol and address level, not type level.
No changes needed.

---

## Phase 8: Binary Writer (vpy_binary_writer) — MINIMAL
**Status:** ⏳ Optional | **Effort:** 0.5-1 hour

- [ ] No functional changes required
- [ ] Optional: Update comments/metadata to reflect type info

---

## Phase 9: Debug Generator (vpy_debug_gen) — MINIMAL
**Status:** ⏳ Optional | **Effort:** 0.5-1 hour

- [ ] Update PDB file generation to include type info for debugger
- [ ] Allow debugger to display proper sizes for variables

---

## Documentation & Examples — PENDING
**Effort:** 2-3 hours | **Depends on:** All phases

### Tasks:
- [ ] Update MANUAL.md with complete type system examples
- [ ] Create example file: `examples/typed_variables.vpy`
  - [ ] Demonstrate u8, i8, u16, i16 usage
  - [ ] Show implicit widening
  - [ ] Show arrays of typed elements
- [ ] Update language.mdx for web docs
- [ ] Create migration guide: "Adding types to your VPy code"

---

## Testing Strategy

### Unit Tests:
- **Parser:** 10+ tests (type hint parsing)
- **Unifier:** 8+ tests (type tracking)
- **Codegen:** 50+ tests (width dispatch combinations)

### Integration Tests:
- **Compile existing examples** (pang, jetpac) with new parser
- **Backward compat test:** Untyped code produces identical output
- **Type-annotated version** of pang that uses 8-bit where appropriate

### Validation Tests:
- **RAM usage:** Verify typed version uses less RAM
- **Correctness:** Verify typed and untyped versions produce identical game behavior
- **Performance:** Check codegen doesn't regress on other aspects

---

## Rollout Plan

### Stage 1: Infrastructure (Phases 1-4)
- [ ] Parser support + tests ✓ Phase 1 complete
- [ ] Type system infrastructure ✓ Phase 2 complete
- [ ] Unifier integration ✓ Phase 3 complete
- [ ] Bank allocator integration ✓ Phase 4 complete
- **Checkpoint:** Can parse and allocate typed variables correctly

### Stage 2: Codegen (Phase 5) ⚠️ CRITICAL
- [ ] Width dispatch helpers ✓
- [ ] Load/store operations ✓
- [ ] Arithmetic operations ✓
- [ ] Array indexing ✓
- [ ] Type promotion ✓
- [ ] Comprehensive testing ✓
- **Checkpoint:** All typed operations generate correct assembly

### Stage 3: Validation (Phases 6-9)
- [ ] Run full compiler pipeline on typed code ✓
- [ ] Verify output correctness ✓
- [ ] Verify backward compatibility ✓
- **Checkpoint:** Feature complete and stable

### Stage 4: Documentation & Release
- [ ] Examples updated ✓
- [ ] User guide written ✓
- [ ] Migration guide written ✓
- [ ] Release notes prepared ✓

---

## Success Criteria

- [ ] Untyped code compiles identically (100% backward compatible)
- [ ] Typed code compiles without errors
- [ ] RAM usage reduced by ~20% for typed games
- [ ] No performance regression on existing games
- [ ] All compiler tests pass
- [ ] Example game compiles with type hints
- [ ] Documentation complete and accurate

---

## Known Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Codegen complexity | HIGH | CRITICAL | Thorough testing, incremental implementation |
| Sign extension bugs | MEDIUM | HIGH | Explicit tests for i8→i16, edge cases |
| Type promotion ambiguity | MEDIUM | MEDIUM | Clear, well-documented rules |
| Backward compat broken | LOW | CRITICAL | Don't change default behavior, extensive testing |
| Performance regression | MEDIUM | MEDIUM | Benchmark before/after, optimize dispatch |

---

## Related Issues

- Community feedback: 16-bit-only wastes ~20% RAM
- Hardware mismatch: Vectrex is 8-bit native
- Code bloat: 80+ builtins, 20 expression evaluation locations needing dispatch

---

## Session Notes

**Started:** 2026-02-21
**Last Updated:** 2026-02-21
**Sessions:** 1
**Progress:** Phase 3/5 complete (60%)

### 2026-02-21 - Initial Analysis & Planning
- Analyzed why 16-bit-only (compiler simplicity vs RAM efficiency)
- Assessed feasibility: Medium refactoring, 18-28 hours
- Designed Python type hints syntax (u8, i8, u16, i16)
- Created phase-by-phase breakdown
- Documented codegen complexity (Phase 5 is critical path)
- Created this TODO.md for tracking progress

### 2026-02-21 - Phase 1: Parser Implementation ✅
- **Duration:** ~1 hour (faster than estimated)
- Created `feat/variable-sized-types` branch
- Added type_annotation fields to AST (Item::Const, Item::GlobalLet, Stmt::Let)
- Implemented type hint parsing with validation (u8, i8, u16, i16)
- Added 10 parser unit tests covering all type cases
- Verified backward compatibility (untyped variables unaffected)
- Commit: `feat/variable-sized-types 2239fcb5`
- **Test Results:** All 143 tests pass (0 failures, 0 regressions)

### 2026-02-21 - Phase 2: Type System Infrastructure ✅
- **Duration:** ~45 minutes (faster than estimated)
- Created VarType struct with size_bytes + signed metadata
- Implemented type registry with from_str() parser (u8, i8, u16, i16)
- Updated Scope to use HashMap<String, VarType> for symbol table
- Added lookup_var() method for type queries
- Added 16 new type system tests (8 VarType + 8 Scope coverage)
- Verified backward compatibility with default_i16() for untyped vars
- Commit: `feat/variable-sized-types 3489b55f`
- **Test Results:** All 179 tests pass (36 vpy_unifier + 143 baseline), 0 regressions

### 2026-02-21 - Phase 3: Unifier Type Tracking ✅
- **Duration:** ~40 minutes (faster than estimated)
- Created TypeTracker module for mapping variable types during unification
- Implemented extract_types_from_module() to build type maps from unified modules
- Added validate_types() for type consistency validation
- Support for extracting types from Item::Const and Item::GlobalLet
- Handled optional type annotations with fallback to default i16
- Added 7 TypeTracker tests covering:
  - Type tracking, extraction, validation
  - Untyped variable defaults
  - Multiple variable handling
- Commit: `feat/variable-sized-types 828714e9`
- **Test Results:** All 186 tests pass (43 vpy_unifier + 143 baseline), 0 regressions
- **Type Info Flow:** Types now persist through unified module for Phase 4/5
- **Next:** Phase 4 (Bank Allocator - use types for per-variable sizing)
