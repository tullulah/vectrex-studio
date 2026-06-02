#!/bin/bash
# run_vpy_tests_visual.sh — Launch interactive visual test viewer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🎨 Launching VPy Visual Test Viewer..."
node "$SCRIPT_DIR/vpy_test_runner_visual.cjs"
