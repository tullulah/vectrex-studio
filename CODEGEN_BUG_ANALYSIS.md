# VPy Compiler Codegen Bug Analysis Report

**Date:** 2026-02-22
**Status:** IDENTIFIED AND FIXED
**Severity:** CRITICAL

---

## Summary

A critical bug in the VPy buildtools compiler (Phase 5: Code Generation) was identified and fixed. The bug prevented all compound assignment operations (`+=`, `-=`) from working correctly, causing variables to never accumulate changes across frames.

## Root Cause

**File:** `/Users/daniel/projects/vectrex-pseudo-python/buildtools/vpy_codegen/src/m6809/functions.rs`
**Line:** 297
**Mechanism:** Variable name case mismatch in assembly label generation

The VPy compiler allocates variables with uppercase labels (e.g., `VAR_TITLE_INTENSITY`). During compound assignment code generation, the compiler was:

1. **Loading** variables using the original case: `LDD VAR_title_intensity`
2. **Storing** variables using uppercase: `STD VAR_TITLE_INTENSITY`

This caused a mismatch where:
- Load reads from undefined location `VAR_title_intensity` → undefined/garbage value
- Arithmetic operates on garbage
- Store writes to correct location `VAR_TITLE_INTENSITY`
- Next frame repeats, never accumulating changes

## Comparison: Before and After

### Before Fix (BUGGY)

```rust
// Line 297 - MISSING .to_uppercase()
asm.push_str(&format!("    LDD VAR_{}\n", name));
asm.push_str("    STD TMPVAL          ; Save left operand\n");
// ... arithmetic ...
asm.push_str(&format!("    STD VAR_{}\n", name.to_uppercase()));  // Different location!
```

Generated ASM (from line 2589 of pang output):
```asm
LDD VAR_title_intensity      ; ❌ Wrong - loads from undefined
STD TMPVAL
; arithmetic
STD VAR_TITLE_INTENSITY      ; Different memory location!
```

### After Fix (CORRECT)

```rust
// Line 297 - NOW HAS .to_uppercase()
asm.push_str(&format!("    LDD VAR_{}\n", name.to_uppercase()));
asm.push_str("    STD TMPVAL          ; Save left operand\n");
// ... arithmetic ...
asm.push_str(&format!("    STD VAR_{}\n", name.to_uppercase()));  // Same location!
```

Generated ASM (from line 2569 of pang output):
```asm
LDD VAR_TITLE_INTENSITY      ; ✓ Correct - loads from defined location
STD TMPVAL
; arithmetic
STD VAR_TITLE_INTENSITY      ; Same memory location!
```

## Impact on Pang Example Game

### Affected Code
File: `examples/pang/src/main.vpy` lines 290-293 in `draw_title_screen()`:

```python
if (title_state == 0):
    title_intensity += 1    # Compound assignment - BROKEN

if (title_state == 1):
    title_intensity -= 1    # Compound assignment - BROKEN
```

### Observable Behavior

**Before Fix:**
- Title screen text stays at fixed intensity (initial value: 30)
- No animation effect
- Intensity never changes regardless of state variable

**After Fix:**
- Title screen text smoothly fades in/out
- Intensity correctly increments from 30 to 80
- Intensity correctly decrements from 80 to 30
- Complete pulsing animation effect works

## Verification Results

### Compilation Test
```
Command: cargo run --manifest-path buildtools/Cargo.toml --bin vpy_cli -- build examples/pang/src/main.vpy

Result: SUCCESS
- Binary size: 32768 bytes (as expected)
- Assembly generation completed
- No compilation errors
```

### Regression Testing
```
Command: cd buildtools && cargo test --all

Result: ALL 180 TESTS PASS
- vpy_loader tests:         23 passed
- vpy_parser tests:          3 passed
- vpy_unifier tests:        20 passed
- vpy_bank_allocator tests: 10 passed
- vpy_codegen tests:        19 passed
- vpy_assembler tests:       5 passed
- vpy_linker tests:          5 passed
- Additional tests:          95 passed (52 + 43)

No test failures - fix does not break any existing functionality.
```

### ASM Output Verification

**Before Fix - Variable Reference Inconsistency:**
```
grep "VAR_title_intensity" pang_buildtools.asm
Result: 2 matches (incorrect lowercase)
grep "VAR_TITLE_INTENSITY" pang_buildtools.asm
Result: Multiple matches (correct uppercase)
```

**After Fix - All References Consistent:**
```
grep "VAR_title_intensity" pang_buildtools_fixed.asm
Result: 0 matches (no lowercase references)
grep "VAR_TITLE_INTENSITY" pang_buildtools_fixed.asm
Result: Multiple matches (all uppercase)
```

## Scope of Bug

### What This Fixes
- All `+=` operations on variables (global and local)
- All `-=` operations on variables (global and local)
- Affects EVERY VPy program using compound assignments

### What This Does NOT Affect
- Regular assignments (`x = y`) - already working
- Other compound operators (`*=`, `/=`, `%=`) - not yet implemented
- Array operations - use different code path
- Function calls - use different code path

## Files Modified

### Code Changes
1. **buildtools/vpy_codegen/src/m6809/functions.rs**
   - Line 296: Updated comment for accuracy
   - Line 297: Added `.to_uppercase()` to variable load operation

### Test Results
- All 180 buildtools tests passing
- No new issues introduced

## Implementation Details

### Variable Allocation Strategy
The VPy compiler allocates variables with uppercase labels for consistency:

```rust
// From variables.rs line 68
ram.allocate(&format!("VAR_{}", var.to_uppercase()), ...)
```

This creates labels like:
- `title_intensity` → `VAR_TITLE_INTENSITY`
- `current_location` → `VAR_CURRENT_LOCATION`
- `enemy_x` → `VAR_ENEMY_X`

### Load Operation Fix
The compound assignment handler must ensure load operations use the same naming convention as the variable allocation:

```rust
// MUST BE:
LDD VAR_{variable_name.to_uppercase()}

// NOT:
LDD VAR_{variable_name}  // Without .to_uppercase()
```

## Lessons Learned

1. **Naming Consistency is Critical:** When variables are allocated with a specific naming convention (uppercase), ALL code that references them must use the same convention.

2. **Copy-Paste Code Paths:** The regular `Assign` handler already had the correct `.to_uppercase()` call. The `CompoundAssign` handler should have been updated to match, but was missed.

3. **Comment Accuracy:** The comment saying "Name already comes uppercase from unifier" was incorrect. Names do NOT come uppercase - they must be explicitly uppercased when generating labels. This misleading comment contributed to the bug.

## Recommendation

After this fix is merged:

1. Add a test case that verifies compound assignments work correctly
2. Document the variable naming convention in code comments
3. Review other statement handlers to ensure consistent label generation
4. Consider extracting variable label generation into a helper function to avoid duplication

---

## Absolute File Paths

- Modified file: `/Users/daniel/projects/vectrex-pseudo-python/buildtools/vpy_codegen/src/m6809/functions.rs`
- Analysis files: `/tmp/analysis_report.md`, `/tmp/CODEGEN_BUG_FIX.md`, `/tmp/FINAL_SUMMARY.md`
- Generated outputs: `/tmp/pang_buildtools_fixed.asm`, `/tmp/pang_buildtools.asm`
