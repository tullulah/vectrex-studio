# VPy Compiler Enhancement Roadmap

## Goal: Variable-Sized Types Support (u8, i8, u16, i16)

**Status:** 🟡 PLANNED (Documentation complete, implementation pending)
**Estimated Effort:** 18-28 developer-hours
**Expected Benefit:** ~20% RAM savings (~200 bytes per game) + compile-time type safety
**Backward Compatible:** ✅ Yes (untyped variables default to 16-bit)

---

## Phase 1: Parser (vpy_parser) — PENDING
**Effort:** 1-2 hours | **Risk:** Low | **Blocker for:** Phase 2

### Tasks:
- [ ] Add `type_annotation: Option<String>` field to `Item::GlobalLet` in `ast.rs`
- [ ] Add `type_annotation: Option<String>` field to `Item::Const` in `ast.rs`
- [ ] Update parser in `parser.rs` to parse type hints after variable names
  - [ ] Handle syntax: `x: u8 = 10`
  - [ ] Handle syntax: `const LIMIT: u16 = 1000`
  - [ ] Support type names: `u8`, `i8`, `u16`, `i16`
- [ ] Add parser tests for type hint syntax
  - [ ] Test valid type hints: `x: u8`, `y: i16`, `score: u16`
  - [ ] Test without type hints (backward compat): `x = 10`
  - [ ] Test error cases: invalid type names, malformed syntax

**Files to modify:**
- `buildtools/vpy_parser/src/ast.rs` — Add type_annotation field
- `buildtools/vpy_parser/src/parser.rs` — Implement type hint parsing

---

## Phase 2: Type System Infrastructure — PENDING
**Effort:** 1-2 hours | **Risk:** Low | **Depends on:** Phase 1 | **Blocker for:** Phase 3

### Tasks:
- [ ] Create `VarType` struct in `vpy_unifier/src/types.rs` (new file)
  ```rust
  pub struct VarType {
      pub name: String,        // "u8", "i8", "u16", "i16"
      pub size_bytes: usize,
      pub signed: bool,
  }
  ```
- [ ] Create type registry/lookup functions
  - [ ] `get_type_info(name: &str) -> Option<VarType>`
  - [ ] Validate type names at parse time
- [ ] Add type tracking to symbol table
  - [ ] Extend `Symbol` struct to include `type_info: VarType`
  - [ ] Default type for untyped vars: `VarType { name: "i16", size: 2, signed: true }`

**Files to modify/create:**
- `buildtools/vpy_unifier/src/types.rs` — New file with VarType
- `buildtools/vpy_unifier/src/scope.rs` — Update symbol table to track types

---

## Phase 3: Unifier (vpy_unifier) — PENDING
**Effort:** 1-2 hours | **Risk:** Low | **Depends on:** Phase 2 | **Blocker for:** Phase 4

### Tasks:
- [ ] Update `define_var()` to accept and store `VarType`
- [ ] Update symbol resolution to preserve type information
- [ ] Validate type consistency in assignments
  - [ ] Warn/error on type mismatch without conversion
  - [ ] Track type through variable usage
- [ ] Add unifier tests for type tracking
  - [ ] Track declared type through symbol table
  - [ ] Verify types persist after renaming

**Files to modify:**
- `buildtools/vpy_unifier/src/resolver.rs` — Thread types through resolution
- `buildtools/vpy_unifier/src/visitor.rs` — Update type handling

---

## Phase 4: Bank Allocator (vpy_bank_allocator) — PENDING
**Effort:** 1-2 hours | **Risk:** Low | **Depends on:** Phase 3 | **Blocker for:** Phase 5

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

### 2026-02-21 - Initial Analysis & Planning
- Analyzed why 16-bit-only (compiler simplicity vs RAM efficiency)
- Assessed feasibility: Medium refactoring, 18-28 hours
- Designed Python type hints syntax (u8, i8, u16, i16)
- Created phase-by-phase breakdown
- Documented codegen complexity (Phase 5 is critical path)
- Created this TODO.md for tracking progress
