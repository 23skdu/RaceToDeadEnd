#!/usr/bin/env python3
"""Verify 100% script-to-test coverage across runtime GDScript modules and test suites."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent

RUNTIME_DIRS = [
    ROOT / "scripts" / "autoload",
    ROOT / "scripts" / "resources",
    ROOT / "scripts" / "scenes",
]
EXTRA_RUNTIME_FILES = [
    ROOT / "scripts" / "utils" / "Helpers.gd",
]
TEST_DIRS = [
    ROOT / "tests" / "unit",
    ROOT / "tests" / "integration",
    ROOT / "tests" / "fuzz",
    ROOT / "tests" / "regression",
]


def main() -> int:
    for test_dir in TEST_DIRS:
        if not test_dir.is_dir():
            print(f"ERROR: Missing required test directory: {test_dir.relative_to(ROOT)}")
            return 1
        test_files = sorted(test_dir.glob("test_*.gd"))
        if not test_files:
            print(f"ERROR: No test_*.gd files found in {test_dir.relative_to(ROOT)}")
            return 1

    all_test_contents = []
    for test_dir in TEST_DIRS:
        for tf in test_dir.glob("*.gd"):
            all_test_contents.append(tf.read_text(encoding="utf-8", errors="ignore"))
    combined_tests = "\n".join(all_test_contents)

    runtime_scripts = list(EXTRA_RUNTIME_FILES)
    for d in RUNTIME_DIRS:
        runtime_scripts.extend(sorted(d.rglob("*.gd")))

    uncovered = []
    for script in sorted(set(runtime_scripts)):
        rel = script.relative_to(ROOT).as_posix()
        stem = script.stem
        # Check either explicit script/scene path reference or autoload/class name usage
        scene_rel = rel.replace("scripts/", "").replace(".gd", ".tscn")
        if (
            rel in combined_tests
            or scene_rel in combined_tests
            or stem in combined_tests
        ):
            continue
        uncovered.append(rel)

    if uncovered:
        print("ERROR: The following runtime GDScript files lack test coverage:")
        for u in uncovered:
            print(f"  - {u}")
        return 1

    print(
        f"Coverage check passed: {len(runtime_scripts)}/{len(runtime_scripts)} "
        "runtime scripts covered across unit/integration/fuzz/regression suites."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
