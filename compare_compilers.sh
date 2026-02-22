#!/bin/bash
# compare_compilers.sh - Comprehensive compiler comparison agent
# Compiles a project with both compilers and systematically compares functions
# Usage: ./compare_compilers.sh <project_name>

set -e

if [ -z "$1" ]; then
    echo "Usage: ./compare_compilers.sh <project_name>"
    echo "  project_name: e.g., 'pang'"
    echo ""
    echo "This script will:"
    echo "  1. Run multibuild.sh to generate binaries and ASM from both compilers"
    echo "  2. List all functions from CORE ASM"
    echo "  3. For each function, extract and compare from both ASM files"
    echo "  4. Report which functions differ"
    exit 1
fi

PROJECT_NAME="$1"
OUTPUT_DIR="examples/${PROJECT_NAME}/multibuild-output"
REPORT_FILE="${OUTPUT_DIR}/COMPARISON_REPORT.txt"

echo "=========================================="
echo "COMPILER COMPARISON AGENT"
echo "Project: $PROJECT_NAME"
echo "=========================================="
echo ""

# Step 1: Run multibuild if needed
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "1️⃣  Running multibuild to generate outputs..."
    ./multibuild.sh "examples/${PROJECT_NAME}/${PROJECT_NAME}.vpyproj"
else
    echo "1️⃣  Output directory exists, skipping multibuild"
fi

# Verify outputs exist
ASM_CORE="${OUTPUT_DIR}/${PROJECT_NAME}_core.asm"
ASM_BUILDTOOLS="${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.asm"

if [ ! -f "$ASM_CORE" ] || [ ! -f "$ASM_BUILDTOOLS" ]; then
    echo "ERROR: ASM files not found"
    exit 1
fi

# Step 2: Extract list of all major functions from CORE (skip data labels)
echo "2️⃣  Extracting function list from CORE..."
FUNCTIONS=$(grep -E "^[A-Z_][A-Z0-9_]*:$" "$ASM_CORE" | sed 's/:$//' | grep -v "^ARRAY" | grep -v "^CONST" | head -50)

echo "Found $(echo "$FUNCTIONS" | wc -l) candidate functions"
echo ""

# Step 3: Compare each function
echo "3️⃣  Comparing functions..."
echo ""

DIFFERENT_COUNT=0
IDENTICAL_COUNT=0

# Create report header
cat > "$REPORT_FILE" << EOF
========================================
COMPILER COMPARISON REPORT: $PROJECT_NAME
$(date)
========================================

SUMMARY:
--------
EOF

for FUNC in $FUNCTIONS; do
    # Skip if not a real function
    if [[ "$FUNC" =~ ^[A-Z_]+ ]]; then
        # Try to extract from both
        CORE_FUNC=$(grep -n "^${FUNC}:$" "$ASM_CORE" | head -1 | cut -d: -f1)
        BUILDTOOLS_FUNC=$(grep -n "^${FUNC}:$" "$ASM_BUILDTOOLS" | head -1 | cut -d: -f1)

        if [ -n "$CORE_FUNC" ] && [ -n "$BUILDTOOLS_FUNC" ]; then
            # Extract the function content (up to next label or EOF)
            CORE_END=$(tail -n +$((CORE_FUNC + 1)) "$ASM_CORE" | grep -n "^[A-Z_][A-Z0-9_]*:$" | head -1 | cut -d: -f1)
            BUILDTOOLS_END=$(tail -n +$((BUILDTOOLS_FUNC + 1)) "$ASM_BUILDTOOLS" | grep -n "^[A-Z_][A-Z0-9_]*:$" | head -1 | cut -d: -f1)

            if [ -z "$CORE_END" ]; then
                CORE_CONTENT=$(tail -n +$CORE_FUNC "$ASM_CORE")
            else
                CORE_CONTENT=$(sed -n "${CORE_FUNC},$((CORE_FUNC + CORE_END - 1))p" "$ASM_CORE")
            fi

            if [ -z "$BUILDTOOLS_END" ]; then
                BUILDTOOLS_CONTENT=$(tail -n +$BUILDTOOLS_FUNC "$ASM_BUILDTOOLS")
            else
                BUILDTOOLS_CONTENT=$(sed -n "${BUILDTOOLS_FUNC},$((BUILDTOOLS_FUNC + BUILDTOOLS_END - 1))p" "$ASM_BUILDTOOLS")
            fi

            # Compare
            if diff <(echo "$CORE_CONTENT") <(echo "$BUILDTOOLS_CONTENT") > /dev/null 2>&1; then
                echo "✅ $FUNC"
                ((IDENTICAL_COUNT++))
                echo "✅ $FUNC - IDENTICAL" >> "$REPORT_FILE"
            else
                echo "❌ $FUNC"
                ((DIFFERENT_COUNT++))
                echo "❌ $FUNC - DIFFERENT" >> "$REPORT_FILE"
                echo "   First difference:" >> "$REPORT_FILE"
                diff <(echo "$CORE_CONTENT" | head -30) <(echo "$BUILDTOOLS_CONTENT" | head -30) | head -10 >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"
            fi
        fi
    fi
done

echo ""
echo "=========================================="
echo "RESULTS:"
echo "=========================================="
echo "✅ Identical:  $IDENTICAL_COUNT"
echo "❌ Different:  $DIFFERENT_COUNT"
echo ""
echo "Detailed report: $REPORT_FILE"
echo ""

# Save summary to report
cat >> "$REPORT_FILE" << EOF

TOTALS:
  Identical functions:  $IDENTICAL_COUNT
  Different functions:  $DIFFERENT_COUNT

Use './compare_asm_function.sh $PROJECT_NAME <function_name>' to examine details.
EOF

if [ $DIFFERENT_COUNT -gt 0 ]; then
    echo "⚠️  $DIFFERENT_COUNT functions differ between compilers"
    echo ""
    echo "To examine a specific function:"
    echo "  ./compare_asm_function.sh $PROJECT_NAME <function_name>"
else
    echo "✅ All functions are identical!"
fi
