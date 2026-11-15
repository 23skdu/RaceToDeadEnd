#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
GODOT="${GODOT:-godot}"

TEST_DIRS=(
    "res://tests/unit"
    "res://tests/integration"
    "res://tests/fuzz"
    "res://tests/regression"
)

mapfile -t ALL_TESTS < <(
    find "$ROOT_DIR/tests/unit" "$ROOT_DIR/tests/integration" "$ROOT_DIR/tests/fuzz" "$ROOT_DIR/tests/regression" \
        -maxdepth 1 -type f -name "test_*.gd" | sort
)

if [ "${#ALL_TESTS[@]}" -eq 0 ]; then
    echo "ERROR: No test_*.gd files discovered."
    exit 1
fi

echo "Discovered ${#ALL_TESTS[@]} test files across unit, integration, fuzz, and regression suites."

"$GODOT" --headless -s "$ROOT_DIR/addons/gut/gut_cmdln.gd" \
    -gdir="$(IFS=,; echo "${TEST_DIRS[*]}")" \
    -ginclude_subdirs -gexit -glog=1

echo ""
echo "==========================================="
echo "  ALL TESTS PASSED (${#ALL_TESTS[@]} files)"
echo "==========================================="
