#!/usr/bin/env bash
# Build the Vectrex Debug Cart firmware for RP2350 (Pico 2)
#
# Usage:
#   ./build_firmware.sh           # debug build
#   ./build_firmware.sh --release # release build
#   ./build_firmware.sh --flash   # release build + flash via probe-rs (SWD)
#   ./build_firmware.sh --uf2     # release build + convert to UF2 (drag & drop)

set -euo pipefail

FIRMWARE_DIR="$(cd "$(dirname "$0")/firmware" && pwd)"
TARGET="thumbv8m.main-none-eabihf"
CHIP="RP2350"
BIN_NAME="vectrex-cart"

RELEASE=false
FLASH=false
UF2=false

for arg in "$@"; do
    case "$arg" in
        --release) RELEASE=true ;;
        --flash)   RELEASE=true; FLASH=true ;;
        --uf2)     RELEASE=true; UF2=true ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--release] [--flash] [--uf2]"
            exit 1 ;;
    esac
done

echo "=== Vectrex Debug Cart Firmware ==="
echo "Target: $TARGET ($CHIP)"

# Check Rust target is installed
if ! rustup target list --installed | grep -q "$TARGET"; then
    echo "Installing Rust target $TARGET..."
    rustup target add "$TARGET"
fi

# Build
cd "$FIRMWARE_DIR"

if $RELEASE; then
    echo "Building (release)..."
    cargo build --release
    ELF="target/$TARGET/release/$BIN_NAME"
else
    echo "Building (debug)..."
    cargo build
    ELF="target/$TARGET/debug/$BIN_NAME"
fi

echo ""
echo "Binary: $FIRMWARE_DIR/$ELF"
arm-none-eabi-size "$ELF" 2>/dev/null || true

if $FLASH; then
    echo ""
    echo "Flashing via probe-rs (SWD)..."
    probe-rs run --chip "$CHIP" "$ELF"
fi

if $UF2; then
    echo ""
    UF2_OUT="${ELF%.elf}.uf2"
    UF2_OUT="${ELF}.uf2"
    echo "Converting to UF2: $UF2_OUT"
    if command -v elf2uf2-rs &>/dev/null; then
        elf2uf2-rs "$ELF" "$UF2_OUT"
        echo "UF2 ready: $UF2_OUT"
        echo ""
        echo "To flash: hold BOOTSEL on Pico 2, connect USB, copy the .uf2 to the RPI-RP2 drive."
    else
        echo "elf2uf2-rs not found. Install with: cargo install elf2uf2-rs"
        exit 1
    fi
fi

echo ""
echo "Done."
