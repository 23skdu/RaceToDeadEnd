#!/usr/bin/env python3
"""Check for dead code: unreferenced scripts/scenes and unused symbols."""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent

IGNORED_PARTS = {".git", ".godot", "addons", "build", "builds", "venv", "__pycache__"}

GODOT_LIFECYCLE_FUNCS = {
    "_init",
    "_ready",
    "_process",
    "_physics_process",
    "_input",
    "_unhandled_input",
    "_unhandled_key_input",
    "_draw",
    "_notification",
    "_exit_tree",
    "_enter_tree",
    "_get_configuration_warnings",
    "on_pool_acquire",
    "on_pool_release",
}


def _should_skip(path: Path) -> bool:
    return any(part in IGNORED_PARTS for part in path.parts)


def _collect_text_files() -> dict[Path, str]:
    files: list[Path] = []
    for ext in ("*.gd", "*.tscn", "*.tres", "*.godot", "*.yml", "*.yaml", "*.sh", "*.py"):
        for p in ROOT.rglob(ext):
            if p.is_file() and not _should_skip(p):
                files.append(p)
    for extra in (ROOT / "Makefile", ROOT / ".githooks" / "pre-commit"):
        if extra.is_file():
            files.append(extra)
    return {p: p.read_text(encoding="utf-8", errors="ignore") for p in files}


def check_unreferenced_scripts(all_texts: dict[Path, str]) -> list[str]:
    issues: list[str] = []
    non_test_texts = {
        p: txt for p, txt in all_texts.items() if "tests" not in p.relative_to(ROOT).parts
    }

    gd_candidates = sorted(
        list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "demo").rglob("*.gd"))
    )
    for p in gd_candidates:
        if _should_skip(p):
            continue
        rel = p.relative_to(ROOT).as_posix()
        name = p.name
        referenced = any(
            k != p and (rel in txt or name in txt)
            for k, txt in non_test_texts.items()
        )
        if not referenced:
            issues.append(f"Unreferenced GDScript file: {rel}")

    py_candidates = sorted((ROOT / "scripts").rglob("*.py"))
    infra_texts = {
        p: txt
        for p, txt in non_test_texts.items()
        if p.name == "Makefile"
        or p.name == "pre-commit"
        or p.suffix in {".yml", ".yaml", ".sh"}
    }
    for p in py_candidates:
        if _should_skip(p) or p.resolve() == Path(__file__).resolve():
            # check_deadcode.py itself must be referenced in Makefile
            if p.resolve() != Path(__file__).resolve():
                continue
        rel = p.relative_to(ROOT).as_posix()
        name = p.name
        referenced = any(
            k != p and (rel in txt or name in txt)
            for k, txt in infra_texts.items()
        )
        if not referenced:
            issues.append(f"Unreferenced Python script: {rel}")

    return issues


def check_unreferenced_scenes(all_texts: dict[Path, str]) -> list[str]:
    issues: list[str] = []
    non_test_texts = {
        p: txt for p, txt in all_texts.items() if "tests" not in p.relative_to(ROOT).parts
    }

    tscn_candidates = sorted(
        list((ROOT / "scenes").rglob("*.tscn")) + list((ROOT / "demo").rglob("*.tscn"))
    )
    for p in tscn_candidates:
        if _should_skip(p):
            continue
        rel = p.relative_to(ROOT).as_posix()
        res_path = "res://" + rel
        referenced = any(
            k != p and (res_path in txt or rel in txt)
            for k, txt in non_test_texts.items()
        )
        if not referenced:
            issues.append(f"Unreferenced scene file: {rel}")

    return issues


def check_unused_symbols(all_texts: dict[Path, str]) -> list[str]:
    issues: list[str] = []
    runtime_gd = sorted(
        list((ROOT / "scripts" / "autoload").rglob("*.gd"))
        + list((ROOT / "scripts" / "resources").rglob("*.gd"))
        + list((ROOT / "scripts" / "scenes").rglob("*.gd"))
        + list((ROOT / "scripts" / "utils").rglob("*.gd"))
        + list((ROOT / "demo").rglob("*.gd"))
    )

    decl_patterns = [
        ("function", re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M)),
        ("signal", re.compile(r"^signal\s+([A-Za-z_][A-Za-z0-9_]*)\b", re.M)),
        ("constant", re.compile(r"^const\s+([A-Za-z_][A-Za-z0-9_]*)\b", re.M)),
        ("variable", re.compile(r"^(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\b", re.M)),
    ]

    for p in runtime_gd:
        if _should_skip(p):
            continue
        txt = all_texts.get(p, p.read_text(encoding="utf-8", errors="ignore"))
        other_txt = "\n".join(t for k, t in all_texts.items() if k != p)
        rel = p.relative_to(ROOT).as_posix()

        for kind, pattern in decl_patterns:
            for match in pattern.finditer(txt):
                sym = match.group(1)
                if kind == "function" and (
                    sym in GODOT_LIFECYCLE_FUNCS or sym.startswith("_on_")
                ):
                    continue
                word_re = re.compile(r"\b" + re.escape(sym) + r"\b")
                self_count = len(word_re.findall(txt))
                other_count = len(word_re.findall(other_txt))
                if self_count <= 1 and other_count == 0:
                    issues.append(f"Unused {kind}: {rel}::{sym}")

    return issues


def main() -> int:
    all_texts = _collect_text_files()
    issues = []
    issues.extend(check_unreferenced_scripts(all_texts))
    issues.extend(check_unreferenced_scenes(all_texts))
    issues.extend(check_unused_symbols(all_texts))

    if issues:
        print("ERROR: Dead code detected:")
        for item in issues:
            print(f"  - {item}")
        return 1

    print("Dead code check passed: no unreferenced scripts, scenes, or unused symbols found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
