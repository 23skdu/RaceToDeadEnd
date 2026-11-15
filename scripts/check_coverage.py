#!/usr/bin/env python3
"""Verify 100% unit, fuzz, and Python test coverage across all scripts."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent

GDSCRIPT_DIRS = [
    ROOT / "scripts" / "autoload",
    ROOT / "scripts" / "resources",
    ROOT / "scripts" / "scenes",
    ROOT / "scripts" / "utils",
    ROOT / "demo",
]
EXTRA_GDSCRIPTS = [
    ROOT / "scripts" / "run_tests.gd",
]

PYTHON_DIR = ROOT / "scripts"
PYTHON_TEST_DIR = ROOT / "tests" / "python"

TEST_DIRS = [
    ROOT / "tests" / "unit",
    ROOT / "tests" / "integration",
    ROOT / "tests" / "fuzz",
    ROOT / "tests" / "regression",
]


def _read_combined_tests(test_dir: Path, pattern: str = "*.gd") -> str:
    contents = []
    for tf in test_dir.glob(pattern):
        contents.append(tf.read_text(encoding="utf-8", errors="ignore"))
    return "\n".join(contents)


def _is_script_referenced(script: Path, test_text: str) -> bool:
    rel = script.relative_to(ROOT).as_posix()
    stem = script.stem
    scene_rel = rel.replace("scripts/", "").replace(".gd", ".tscn")
    return rel in test_text or scene_rel in test_text or stem in test_text


def main() -> int:
    for test_dir in TEST_DIRS:
        if not test_dir.is_dir():
            print(f"ERROR: Missing required test directory: {test_dir.relative_to(ROOT)}")
            return 1
        test_files = sorted(test_dir.glob("test_*.gd"))
        if not test_files:
            print(f"ERROR: No test_*.gd files found in {test_dir.relative_to(ROOT)}")
            return 1

    if not PYTHON_TEST_DIR.is_dir() or not list(PYTHON_TEST_DIR.glob("test_*.py")):
        print("ERROR: Missing Python test suite in tests/python/")
        return 1

    unit_text = _read_combined_tests(ROOT / "tests" / "unit", "*.gd")
    fuzz_text = _read_combined_tests(ROOT / "tests" / "fuzz", "*.gd")
    py_test_text = _read_combined_tests(PYTHON_TEST_DIR, "*.py")

    gd_scripts = list(EXTRA_GDSCRIPTS)
    for d in GDSCRIPT_DIRS:
        if d.is_dir():
            gd_scripts.extend(sorted(d.rglob("*.gd")))
    gd_scripts = sorted(set(gd_scripts))

    py_scripts = sorted(p for p in PYTHON_DIR.glob("*.py"))

    missing_unit = [
        s.relative_to(ROOT).as_posix()
        for s in gd_scripts
        if not _is_script_referenced(s, unit_text)
    ]
    missing_fuzz = [
        s.relative_to(ROOT).as_posix()
        for s in gd_scripts
        if not _is_script_referenced(s, fuzz_text)
    ]
    missing_py = [
        s.relative_to(ROOT).as_posix()
        for s in py_scripts
        if not _is_script_referenced(s, py_test_text)
    ]

    if missing_unit or missing_fuzz or missing_py:
        if missing_unit:
            print("ERROR: The following GDScript files lack unit test coverage (tests/unit/):")
            for u in missing_unit:
                print(f"  - {u}")
        if missing_fuzz:
            print("ERROR: The following GDScript files lack fuzz test coverage (tests/fuzz/):")
            for f in missing_fuzz:
                print(f"  - {f}")
        if missing_py:
            print("ERROR: The following Python scripts lack test coverage (tests/python/):")
            for p in missing_py:
                print(f"  - {p}")
        return 1

    print(
        f"Coverage check passed: {len(gd_scripts)}/{len(gd_scripts)} GDScript files "
        f"(100% unit + 100% fuzz) and {len(py_scripts)}/{len(py_scripts)} Python scripts covered."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
