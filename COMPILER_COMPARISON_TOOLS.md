# Compiler Comparison Tools

Tools for comparing Core (legacy) and Buildtools (new) compiler output at the ASM level.

## Quick Start

```bash
# Full comparison (all functions)
./compare_compilers.sh pang

# List functions in project
./compare_asm_function.sh pang

# Compare specific function
./compare_asm_function.sh pang MAIN
./compare_asm_function.sh pang LOOP_BODY
```

## Tools Overview

### 1. `multibuild.sh` - Dual Compiler Build

Compiles a VPy project with **both Core and Buildtools** compilers and generates comparable outputs.

**Usage:**
```bash
./multibuild.sh examples/pang/pang.vpyproj
```

**Output:** `examples/pang/multibuild-output/`
- `pang_core.bin` - Binary from Core compiler
- `pang_core.asm` - Assembly from Core compiler
- `pang_buildtools.bin` - Binary from Buildtools compiler
- `pang_buildtools.asm` - Assembly from Buildtools compiler
- Automatic binary MD5 comparison

**Requirements:**
- Project must have a `.vpyproj` file in the project directory
- `.vpyproj` must define `entry = "path/to/main.vpy"`

### 2. `compare_asm_function.sh` - Function-Level Comparison

Extracts and compares individual functions/labels from both ASM files.

**List all functions:**
```bash
./compare_asm_function.sh pang
```

**Compare specific function:**
```bash
./compare_asm_function.sh pang MAIN
./compare_asm_function.sh pang LOOP_BODY
./compare_asm_function.sh pang title_intensity
```

**Output:**
- Side-by-side ASM code
- Unified diff if different
- ✅ Identical or ❌ Different status

### 3. `compare_compilers.sh` - Full Comparison Agent

Automatically compares all functions from both compilers and generates a report.

**Usage:**
```bash
./compare_compilers.sh pang
```

**Output:**
- Console summary (✅ Identical / ❌ Different)
- Detailed report: `examples/pang/multibuild-output/COMPARISON_REPORT.txt`
- Lists which functions diverge

## Workflow for Debugging Compiler Differences

1. **Run full comparison:**
   ```bash
   ./compare_compilers.sh pang
   ```
   → Identifies which functions differ

2. **Examine a specific function:**
   ```bash
   ./compare_asm_function.sh pang MAIN
   ```
   → Shows exact differences in ASM

3. **Locate root cause:**
   - Check which instructions differ
   - Trace to corresponding VPy code
   - Compare buildtools codegen for that instruction type

## Example Output

### Full Comparison
```
==========================================
COMPILER COMPARISON AGENT
Project: pang
==========================================

✅ START
✅ MAIN
❌ LOOP_BODY        ← Function differs!
✅ update_enemies
✅ draw_enemies

Results:
✅ Identical:  23
❌ Different:  1

Detailed report: examples/pang/multibuild-output/COMPARISON_REPORT.txt
```

### Specific Function Comparison
```
./compare_asm_function.sh pang LOOP_BODY

==========================================
Comparing function: LOOP_BODY
==========================================

CORE:
LDX #ARRAY_LOCATION_NAMES_DATA  ; Const array pointer -> ROM
...

BUILDTOOLS:
LDX VAR_LOCATION_NAMES          ; Using RAM pointer instead
...

❌ Function ASM is DIFFERENT
```

## Integration with Claude Code

These tools are designed for use with Claude Code agents:

1. **Explore Phase**: Agent runs `compare_compilers.sh` to identify diverging functions
2. **Analysis Phase**: Agent uses `compare_asm_function.sh` to examine specific functions
3. **Diagnosis Phase**: Agent correlates ASM differences to codegen source code
4. **Fix Phase**: Agent implements fix in appropriate buildtools phase

## Tips

- Start with `compare_compilers.sh` for a high-level overview
- Use `compare_asm_function.sh` to drill into specifics
- Filter function output with `grep` if needed:
  ```bash
  ./compare_asm_function.sh pang 2>&1 | grep "❌"
  ```
- Check the `COMPARISON_REPORT.txt` for cumulative findings

## Known Issues

- ASM generation for buildtools may fail if paths are not absolute
- Function extraction depends on consistent label formatting (must end with `:`)
- Data labels (ARRAY_*, CONST_*) are filtered out from main comparison
