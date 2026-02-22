#!/bin/bash
# multibuild.sh - Compile a VPy project with both core and buildtools compilers
# Usage: ./multibuild.sh <path-to-project.vpyproj>

set -e

if [ -z "$1" ]; then
    echo "Usage: ./multibuild.sh <path-to-project.vpyproj>"
    exit 1
fi

VPYPROJ="$1"
PROJECT_DIR="$(dirname "$VPYPROJ")"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/multibuild-output"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "Multi-Build: $PROJECT_NAME"
echo "=========================================="
echo "Project: $VPYPROJ"
echo "Output: $OUTPUT_DIR"
echo ""

# Extract entry point from vpyproj
ENTRY_POINT=$(grep -E '^\s*entry\s*=' "$VPYPROJ" | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/')
if [ -z "$ENTRY_POINT" ]; then
    echo "ERROR: Could not find entry point in $VPYPROJ"
    exit 1
fi

ENTRY_PATH="${PROJECT_DIR}/${ENTRY_POINT}"
echo "Entry point: $ENTRY_POINT"
echo ""

# Get project title (for --title flag)
TITLE=$(grep -E '^\s*name\s*=' "$VPYPROJ" | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' | tr '[:lower:]' '[:upper:]')
INCLUDE_DIR="$(pwd)"

echo "1️⃣  Compiling with CORE..."
./target/release/vectrexc build "$VPYPROJ" \
    --target vectrex \
    --title "$TITLE" \
    --bin \
    --include-dir "$INCLUDE_DIR" \
    2>&1 | tail -3
if [ -f "${PROJECT_DIR}/build/${PROJECT_NAME}.bin" ]; then
    cp "${PROJECT_DIR}/build/${PROJECT_NAME}.bin" "${OUTPUT_DIR}/${PROJECT_NAME}_core.bin"
    echo "✓ Core binary: ${PROJECT_NAME}_core.bin"
else
    echo "✗ Core binary not found"
fi

# Generate core ASM
./target/release/vectrexc build "$VPYPROJ" \
    --target vectrex \
    --title "$TITLE" \
    --include-dir "$INCLUDE_DIR" \
    2>&1 | tail -1
if [ -f "${PROJECT_DIR}/src/main.asm" ]; then
    cp "${PROJECT_DIR}/src/main.asm" "${OUTPUT_DIR}/${PROJECT_NAME}_core.asm"
    echo "✓ Core ASM: ${PROJECT_NAME}_core.asm"
fi
echo ""

echo "2️⃣  Compiling with BUILDTOOLS..."
./buildtools/target/release/vpy_cli build "$VPYPROJ" \
    2>&1 | tail -2
if [ -f "${PROJECT_DIR}/build/${PROJECT_NAME}.bin" ]; then
    cp "${PROJECT_DIR}/build/${PROJECT_NAME}.bin" "${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.bin"
    echo "✓ Buildtools binary: ${PROJECT_NAME}_buildtools.bin"
else
    echo "✗ Buildtools binary not found"
fi

# Generate buildtools ASM using vpy_cli asm
cd "$(pwd)" # Make sure we're in project root
./buildtools/target/release/vpy_cli asm "${PROJECT_DIR}/${ENTRY_POINT}" > "${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.asm" 2>&1
if [ -s "${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.asm" ] && ! grep -q "Error:" "${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.asm"; then
    echo "✓ Buildtools ASM: ${PROJECT_NAME}_buildtools.asm"
else
    echo "✗ Buildtools ASM generation failed"
    # Try alternative: use cargo run directly
    cargo run --manifest-path buildtools/Cargo.toml --release --bin vpy_cli -- asm "${PROJECT_DIR}/${ENTRY_POINT}" > "${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.asm" 2>&1 || true
fi
echo ""

echo "=========================================="
echo "Comparison Results"
echo "=========================================="

# Compare binaries
if [ -f "${OUTPUT_DIR}/${PROJECT_NAME}_core.bin" ] && [ -f "${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.bin" ]; then
    MD5_CORE=$(md5 -q "${OUTPUT_DIR}/${PROJECT_NAME}_core.bin")
    MD5_BUILDTOOLS=$(md5 -q "${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.bin")

    echo "Core binary MD5:       $MD5_CORE"
    echo "Buildtools binary MD5: $MD5_BUILDTOOLS"

    if [ "$MD5_CORE" = "$MD5_BUILDTOOLS" ]; then
        echo "✅ Binaries are IDENTICAL"
    else
        echo "❌ Binaries are DIFFERENT"

        # Show first byte differences
        echo ""
        echo "First 10 byte differences:"
        cmp -l "${OUTPUT_DIR}/${PROJECT_NAME}_core.bin" "${OUTPUT_DIR}/${PROJECT_NAME}_buildtools.bin" | head -10
    fi
else
    echo "⚠️  Could not compare binaries (one or both missing)"
fi

echo ""
echo "Output files in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
