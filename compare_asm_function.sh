#!/bin/bash
# compare_asm_function.sh - Extract and compare a specific function from both ASM files
# Usage: ./compare_asm_function.sh <project-name> [function_name]
# If function_name is omitted, lists all functions
# If function_name is provided, extracts and compares that function

set -e

if [ -z "$1" ]; then
    echo "Usage: ./compare_asm_function.sh <project-name> [function_name]"
    echo "  project-name: e.g., 'pang' (looks in examples/pang/multibuild-output/)"
    echo "  function_name: e.g., 'MAIN', 'LOOP_BODY', 'LOOP' (optional)"
    echo ""
    echo "Examples:"
    echo "  ./compare_asm_function.sh pang              # List all functions"
    echo "  ./compare_asm_function.sh pang MAIN         # Compare MAIN function"
    echo "  ./compare_asm_function.sh pang title_intensity  # Compare title_intensity"
    exit 1
fi

PROJECT_NAME="$1"
FUNCTION_NAME="${2:-}"
OUTPUT_DIR="examples/${PROJECT_NAME}/multibuild-output"

ASM_CORE="${OUTPUT_DIR}/${PROJECT_NAME}_core.asm"
ASM_BUILDTOOLS="${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.asm"

if [ ! -f "$ASM_CORE" ] || [ ! -f "$ASM_BUILDTOOLS" ]; then
    echo "ERROR: ASM files not found in $OUTPUT_DIR"
    echo "Run ./multibuild.sh examples/${PROJECT_NAME}/${PROJECT_NAME}.vpyproj first"
    exit 1
fi

# Function to extract a function from ASM by label name
extract_function() {
    local asm_file="$1"
    local func_name="$2"

    # Find the line number of the function label
    local start_line=$(grep -n "^${func_name}:" "$asm_file" | head -1 | cut -d: -f1)

    if [ -z "$start_line" ]; then
        return 1
    fi

    # Find the next label (start of next function)
    local end_line=$(tail -n +$((start_line + 1)) "$asm_file" | grep -n "^[A-Za-z_][A-Za-z0-9_]*:$" | head -1 | cut -d: -f1)

    if [ -z "$end_line" ]; then
        # No next label found, read to end of file
        sed -n "${start_line},$p" "$asm_file"
    else
        # Calculate absolute line number
        end_line=$((start_line + end_line - 1))
        sed -n "${start_line},$((end_line - 1))p" "$asm_file"
    fi
}

# If no function name provided, list all functions
if [ -z "$FUNCTION_NAME" ]; then
    echo "=========================================="
    echo "Functions in $PROJECT_NAME ASM files"
    echo "=========================================="
    echo ""

    echo "CORE functions:"
    grep -n "^[A-Za-z_][A-Za-z0-9_]*:$" "$ASM_CORE" | head -30 | awk -F: '{print "  " $2 " (line " $1 ")"}'

    echo ""
    echo "BUILDTOOLS functions:"
    grep -n "^[A-Za-z_][A-Za-z0-9_]*:$" "$ASM_BUILDTOOLS" | head -30 | awk -F: '{print "  " $2 " (line " $1 ")"}'

    echo ""
    echo "To compare a specific function:"
    echo "  ./compare_asm_function.sh $PROJECT_NAME <function_name>"
    exit 0
fi

# Extract the function from both ASM files
echo "=========================================="
echo "Comparing function: $FUNCTION_NAME"
echo "=========================================="
echo ""

CORE_OUTPUT=$(extract_function "$ASM_CORE" "$FUNCTION_NAME" 2>/dev/null)
BUILDTOOLS_OUTPUT=$(extract_function "$ASM_BUILDTOOLS" "$FUNCTION_NAME" 2>/dev/null)

if [ -z "$CORE_OUTPUT" ]; then
    echo "❌ Function '$FUNCTION_NAME' not found in CORE ASM"
    exit 1
fi

if [ -z "$BUILDTOOLS_OUTPUT" ]; then
    echo "❌ Function '$FUNCTION_NAME' not found in BUILDTOOLS ASM"
    exit 1
fi

# Save to temp files for comparison
TEMP_CORE=$(mktemp)
TEMP_BUILDTOOLS=$(mktemp)

echo "$CORE_OUTPUT" > "$TEMP_CORE"
echo "$BUILDTOOLS_OUTPUT" > "$TEMP_BUILDTOOLS"

# Show side-by-side diff
echo "CORE:"
echo "==============================================="
head -50 "$TEMP_CORE"
echo ""
echo ""
echo "BUILDTOOLS:"
echo "==============================================="
head -50 "$TEMP_BUILDTOOLS"
echo ""

# Check if identical
if diff -q "$TEMP_CORE" "$TEMP_BUILDTOOLS" > /dev/null; then
    echo "=========================================="
    echo "✅ Function ASM is IDENTICAL"
    echo "=========================================="
else
    echo "=========================================="
    echo "❌ Function ASM is DIFFERENT"
    echo "=========================================="
    echo ""
    echo "Unified diff (first 50 lines):"
    echo "-------"
    diff -u "$TEMP_CORE" "$TEMP_BUILDTOOLS" | head -60
fi

# Cleanup
rm -f "$TEMP_CORE" "$TEMP_BUILDTOOLS"
