# Claude Code Agent: Compiler Diff Analyzer

A specialized Claude Code agent for analyzing differences between Core and Buildtools compiler output.

## What This Agent Does

When you invoke this agent with a VPy project name, it will:

1. **Run full compiler comparison** using `compare_compilers.sh`
2. **Identify all diverging functions** between core and buildtools
3. **Deep-dive into each difference** using `compare_asm_function.sh`
4. **Analyze root causes** by examining the ASM differences
5. **Trace back to source code** in the buildtools compiler phases
6. **Generate diagnostic report** with findings and recommendations

## How to Use in Claude Code

### Basic Usage

```
@claude-compiler-diff-analyzer analyze pang
```

This will:
- Compile `examples/pang/pang.vpyproj` with both compilers
- Compare all functions
- Report which ones differ
- Provide detailed analysis

### Detailed Analysis

```
@claude-compiler-diff-analyzer analyze pang --detailed
```

For each differing function:
- Shows exact ASM differences
- Identifies the pattern of divergence
- Suggests which compiler phase might be responsible
- Provides code location hints

### Focus on Specific Functions

```
@claude-compiler-diff-analyzer analyze pang --functions MAIN,LOOP_BODY,title_intensity
```

Only analyze specific functions instead of all.

### Export Report

```
@claude-compiler-diff-analyzer analyze pang --export-report /path/to/report.txt
```

Generates a comprehensive markdown report suitable for documentation.

## Agent Implementation

The agent should:

### Input
- `project_name` (string): e.g., "pang"
- `--detailed` (flag): Show full ASM diffs
- `--functions` (list): Comma-separated function names to analyze
- `--export-report` (path): Export to file instead of console

### Process

1. **Validation Phase**
   ```bash
   if [ ! -f "examples/${PROJECT}/pang.vpyproj" ]; then
       error "Project not found"
   fi
   ```

2. **Compilation Phase**
   ```bash
   ./multibuild.sh "examples/${PROJECT}/${PROJECT}.vpyproj"
   ```

3. **Comparison Phase**
   ```bash
   ./compare_compilers.sh "$PROJECT" > /tmp/comparison.txt
   ```

4. **Analysis Phase**
   For each differing function:
   ```bash
   ./compare_asm_function.sh "$PROJECT" "$FUNCTION"
   ```

5. **Root Cause Analysis**
   - Categorize differences:
     - Instruction sequence variations
     - Register allocation differences
     - Memory access patterns
     - Stack management
     - Branching logic

6. **Report Generation**
   - Summary table of differences
   - Detailed findings per function
   - Buildtools source code locations
   - Recommendations for fixes

### Output

The agent produces:

1. **Console Summary**
   ```
   ✅ 23 functions identical
   ❌ 1 function different: LOOP_BODY

   Detailed findings:
   - LOOP_BODY differs in instruction sequence (core has more efficient addressing)
   - Likely cause: Phase 5 codegen (buildtools/vpy_codegen/src/m6809/expressions.rs)
   ```

2. **Detailed Report** (if --detailed)
   ```
   FUNCTION: LOOP_BODY
   STATUS: ❌ DIFFERENT

   CORE ASM (lines 500-520):
   [ASM content]

   BUILDTOOLS ASM (lines 480-495):
   [ASM content]

   ROOT CAUSE ANALYSIS:
   The addressing mode differs for array access...
   ```

3. **Recommendations**
   ```
   RECOMMENDATIONS:
   1. Check buildtools/vpy_codegen/src/m6809/expressions.rs line 245
   2. Compare emit_array_access implementation
   3. Test with: ./compare_asm_function.sh pang LOOP_BODY
   ```

## Key Capabilities

The agent should leverage:

- **ASM Pattern Recognition**: Identify common divergence patterns
- **Source Code Mapping**: Link ASM differences to buildtools source files
- **Incremental Analysis**: Focus on one function at a time
- **Root Cause Correlation**: Connect patterns to specific compiler phases
- **Report Generation**: Professional diagnostic output

## Integration with Other Agents

### With Compiler Engineer Agent

```
@claude-compiler-engineer fix-based-on-analysis <report-file>
```

Takes the compiler diff analysis and implements fixes in buildtools.

### With Test Engineer Agent

```
@claude-test-engineer write-regression-tests-for-function <function-name>
```

Ensures the fix doesn't break other functionality.

## Example Session

```
User: Analyze why pang behaves differently between compilers