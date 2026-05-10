#!/usr/bin/env bash
# run_vpy_tests.sh — Run all VPy visual tests
# Usage: ./tools/run_vpy_tests.sh [--golden] [--filter <pattern>] [--verbose]
#
# Options:
#   --golden    Save golden snapshots for all tests (first-time setup)
#   --filter    Only run tests whose path matches the pattern (e.g. draw_line)
#   --verbose   Show draw lists and detailed output
#   --no-compile  Skip compilation, use existing .bin files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNNER="$SCRIPT_DIR/vpy_test_runner.cjs"

# ── Parse flags ────────────────────────────────────────────────────────────
GOLDEN_FLAG=""
VERBOSE_FLAG=""
NO_COMPILE_FLAG=""
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --golden)      GOLDEN_FLAG="--golden"; shift ;;
    --verbose)     VERBOSE_FLAG="--verbose"; shift ;;
    --no-compile)  NO_COMPILE_FLAG="--no-compile"; shift ;;
    --filter)      FILTER="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Discover test specs ────────────────────────────────────────────────────
SPECS=()
while IFS= read -r -d '' spec; do
  if [[ -z "$FILTER" ]] || [[ "$spec" == *"$FILTER"* ]]; then
    SPECS+=("$spec")
  fi
done < <(find "$WORKSPACE/examples" -name "test.vpy.js" -print0 | sort -z)

if [[ ${#SPECS[@]} -eq 0 ]]; then
  echo "No test specs found$([ -n "$FILTER" ] && echo " matching '$FILTER'")."
  echo "Create a test.vpy.js file in your test project, or run:"
  echo "  node tools/vpy_test_runner.cjs <test_spec.js> --golden"
  exit 0
fi

echo "══════════════════════════════════════════"
echo " VPy Visual Test Runner"
echo " Found ${#SPECS[@]} test(s)"
if [[ -n "$GOLDEN_FLAG" ]]; then
  echo " MODE: Saving golden snapshots"
fi
echo "══════════════════════════════════════════"
echo ""

# ── Run each spec ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

for spec in "${SPECS[@]}"; do
  # Make path relative to workspace (portable across macOS/Linux)
  rel="${spec#$WORKSPACE/}"
  printf "▶  %-60s " "$rel"

  # Build flags
  FLAGS="$GOLDEN_FLAG $VERBOSE_FLAG $NO_COMPILE_FLAG"

  # Run test
  if output=$(node "$RUNNER" "$spec" $FLAGS 2>&1); then
    if [[ "$output" == *"[PASS]"* ]]; then
      echo "✓ PASS"
      ((PASS++)) || true
    elif [[ "$output" == *"[GOLDEN]"* ]]; then
      echo "◎ GOLDEN"
      ((PASS++)) || true
    elif [[ "$output" == *"[WARN]"* ]]; then
      echo "⚠ NO ASSERTIONS"
      ((SKIP++)) || true
    else
      echo "✓ PASS"
      ((PASS++)) || true
    fi
    if [[ -n "$VERBOSE_FLAG" ]]; then
      echo "$output" | sed 's/^/   /'
    fi
  else
    echo "✗ FAIL"
    ((FAIL++)) || true
    echo "$output" | grep -E "✗|ERROR|FAIL" | sed 's/^/   /' || echo "$output" | head -20 | sed 's/^/   /'
  fi
done

echo ""
echo "══════════════════════════════════════════"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "══════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
