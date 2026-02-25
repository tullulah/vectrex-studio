# Stack Balance Validator

## Overview

The Stack Balance Validator is a compile-time safety feature that catches stack corruption bugs before they cause runtime hangs and crashes. It's integrated into Phase 5 (codegen) and automatically validates all generated M6809 assembly code.

## Why This Matters

Stack corruption is one of the hardest bugs to debug because:
- Symptoms appear unpredictably (programs hang, jump to random addresses)
- The corruption happens in one function but crashes in a different one
- Silent failures - no error messages, just a black screen
- Hard to reproduce (depends on runtime memory state)

The Stack Balance Validator catches these bugs at **compile time** by analyzing the generated assembly before it's linked.

## How It Works

### 1. Function Analysis

The validator scans the generated ASM for function definitions (labels ending with `:`) and analyzes each function independently:

```asm
UPDATE_ENEMIES:          ; Function start
    PSHS X              ; Push X (depth = +1)
    LDD enemy_x         ; Load data (no stack effect)
    PSHS D              ; Push D (depth = +2)
    JSR CHECK_BOUNDS    ; Call helper
    PULS D              ; Pop D (depth = +1)
    PULS X              ; Pop X (depth = 0)
    RTS                 ; Return
```

### 2. Stack Depth Tracking

For each instruction, the validator calculates the stack depth change:

| Instruction | Effect | Notes |
|---|---|---|
| `PSHS <reg>` | +1 per register | `PSHS X` = +1, `PSHS D,X` = +2 |
| `PULS <reg>` | -1 per register | `PULS X` = -1, `PULS D,X` = -2 |
| `JSR`/`JMPS` | 0 | Call convention handled by caller/callee |
| `RTS`/`RTI` | 0 | Function exit (depth must be 0 at this point) |
| Other | 0 | Load, store, branches don't affect stack |

### 3. Validation Rules

For each function:
- Starts at depth 0
- Cannot go negative (stack underflow)
- Must end at depth 0 (balanced)
- Returns error if any rule violated

### 4. Error Reporting

When an imbalance is detected, detailed error messages show:
- Function name where problem occurs
- Final depth (how many items unmatched)
- Line-by-line stack trace showing all PSHS/PULS operations
- Stack depth at each operation

## Found Bugs in pang Example

When validating the current codegen output, **5 CRITICAL STACK IMBALANCES** were detected:

### Bug 1: LOOP_BODY - Too Many Pushes

```
Error: Stack imbalance in function `LOOP_BODY`: final depth = 2
  Line 10: PUSH (+1) -> Depth = 1
  Line 27: PUSH (+1) -> Depth = 2
```

**Problem**: Function pushes 2 items but never pops them before returning.

**Impact**: Stack pointer grows by 2 bytes each loop iteration. After ~1000 iterations, stack collides with heap → crash.

### Bug 2: IF_NEXT_1 - Too Many Pushes

```
Error: Stack imbalance in function `IF_NEXT_1`: final depth = 2
  Line 4: PUSH (+1) -> Depth = 1
  Line 21: PUSH (+1) -> Depth = 2
```

**Problem**: Similar to LOOP_BODY - unmatched PSHS.

### Bug 3: IF_END_2, IF_NEXT_5-7 - Pop Without Push

```
Error: Stack imbalance in function `IF_END_2`: final depth = 0
  Line 13: Stack underflow! Depth = -1 after: PULS X
  Line 14: Stack underflow! Depth = -1 after: LEAX D,X
  ... (more underflow errors)
```

**Problem**: Trying to pop register X without first pushing it.

**Impact**: PULS loads garbage from memory above stack pointer, corrupting register X.

## Root Cause Analysis

These bugs indicate issues in the codegen phase:

1. **Prologue/Epilogue Mismatch**: Some generated functions have PSHS in prologue but missing PULS in epilogue
2. **Conditional Branch Imbalance**: If/else branches may have different stack effects that aren't properly reconciled
3. **Loop Variable Spilling**: Unbalanced push/pop across loop boundaries

## How to Use the Validator

### 1. Automatic Validation (Enabled by Default)

The validator runs automatically when you build:

```bash
cd buildtools
cargo build vpy_cli
./target/debug/vpy_cli build examples/pang/src/main.vpy
```

If stack imbalances are found, compilation stops with detailed errors.

### 2. Running Validator Tests

```bash
cargo test -p vpy_codegen stack_validator
```

Output:
```
running 5 tests
test stack_validator::tests::test_simple_balanced_function ... ok
test stack_validator::tests::test_unbalanced_function_too_many_pushes ... ok
test stack_validator::tests::test_unbalanced_function_too_many_pops ... ok
test stack_validator::tests::test_multiple_functions ... ok
test stack_validator::tests::test_jsr_includes_return_address ... ok

test result: ok. 5 passed
```

### 3. Interpreting Error Messages

When an error occurs, look for:

1. **Function name**: Which generated function has the problem
   - `LOOP_BODY`, `IF_NEXT_1`, etc. are generated from control flow
   - User functions like `UPDATE_ENEMIES` may also appear

2. **Final depth**: How many items are unmatched
   - Positive = too many PSHS (pushes not popped)
   - Negative = too many PULS (pops without matching pushes)

3. **Stack trace**: Line-by-line log showing each PSHS/PULS
   - Helps locate exactly where balance is lost
   - Shows depth after each operation

## Limitations

The validator has these known limitations:

1. **Single Function Scope**: Validates each function independently
   - Doesn't track stack effects across function calls
   - Assumes JSR/RTS are correctly balanced at call sites

2. **No Conditional Path Analysis**: Doesn't distinguish between different code paths
   - All PSHS/PULS instructions are counted uniformly
   - If/else branches must each have their own balance

3. **Heuristic Label Detection**: Uses naming conventions to identify functions
   - Labels starting with `.` (local labels) are skipped
   - Labels starting with `BANK` (section markers) are skipped
   - This may miss some non-standard function names

4. **No Instruction Semantics**: Only counts PSHS/PULS
   - Doesn't verify correctness of registers pushed
   - Doesn't check for ABI violations (e.g., callee-saved registers)

## Implementation Details

### File Location
`buildtools/vpy_codegen/src/stack_validator.rs` (285 lines)

### Key Functions

**`validate_stack_balance(asm_source: &str) -> Result<(), Vec<StackValidationError>>`**
- Entry point - validates entire ASM source
- Returns Ok(()) if all functions balanced
- Returns Err(Vec<errors>) with detailed problem list

**`analyze_instruction_depth(line: &str) -> i32`**
- Analyzes single instruction for stack effects
- Returns depth change: +1 for PSHS, -1 for PULS, 0 for others

**`check_function_balance(function_name: &str, lines: &[&str]) -> Result<(), (i32, Vec<String>)>`**
- Validates single function
- Returns Ok(()) if balanced
- Returns Err((final_depth, issues)) with problem details

### Integration Point

In `buildtools/vpy_codegen/src/lib.rs`:

```rust
pub fn generate_from_module(...) -> Result<GeneratedASM, CodegenError> {
    let asm_source = m6809::generate_m6809_asm(...)?;

    // Validate stack balance
    if let Err(validation_errors) = stack_validator::validate_stack_balance(&asm_source) {
        // Return detailed error with all problems
        return Err(CodegenError::Error(error_msg));
    }

    Ok(GeneratedASM { asm_source, ... })
}
```

## Next Steps

To fix the stack imbalances found in pang:

1. **Locate the buggy generator**: Identify which codegen module creates these functions
   - `LOOP_BODY` → `functions.rs` loop body generation
   - `IF_NEXT_1` → `expressions.rs` if/else branch generation

2. **Review prologue/epilogue**: Ensure PSHS/PULS are matched
   ```asm
   LOOP_BODY:
       PSHS X          ; Prologue: save X
       ... user code ...
       PULS X          ; Epilogue: restore X
       RTS
   ```

3. **Test fix**: Rebuild and verify validator passes
   ```bash
   cargo build -p vpy_cli
   ./target/debug/vpy_cli build examples/pang/src/main.vpy
   # Should show "✓ BUILD SUCCESS" instead of stack errors
   ```

4. **Extend validator**: Consider adding checks for:
   - Callee-saved register preservation (X, Y, U, S)
   - Function ABI compliance
   - Cross-function call stack effects

## References

- **MC6809 Architecture**: http://6809.wikidot.com/
- **Stack Operations**: PSHS/PULS instructions (introdu-
- **Vectrex Reference**: `docs/` directory in this repo
- **Core Compiler Implementation**: `core/src/backend/m6809/` (legacy reference)

## See Also

- `buildtools/README.md` - Pipeline architecture
- `docs/COMPILER_STATUS.md` - Compiler phases status
- `examples/pang/src/main.vpy` - Example with detected bugs
