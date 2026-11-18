#!/usr/bin/env python3
"""Check for dead code: unreferenced resources and unused GDScript symbols.

The checker separates real code references from comments, string literals,
scenes, and tests. Test-only symbols are accepted by default because GUT
discovers test files dynamically; pass ``--include-test-only`` to report them.
"""

from pathlib import Path
import argparse
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
    "_integrate_forces",
    "_draw",
    "_notification",
    "_exit_tree",
    "_enter_tree",
    "_get_configuration_warnings",
    "on_pool_acquire",
    "on_pool_release",
}

# Godot built-ins and duck-typed interfaces used in has_method() guards.
# These are resolved on arbitrary nodes at runtime, not declared in this repo.
DYNAMIC_INTERFACE_METHODS = {
    "add_theme_font_sizes_override",
    "connect",
    "disconnect",
    "emit_signal",
    "get",
    "get_accessibility_element",
    "get_damage",
    "has_element",
    "is_supported",
    "on_enemy_animation_event",
    "queue_accessibility_update",
    "queue_free",
    "set",
    "start",
    "travel",
    "update_set_description",
    "update_set_language",
    "update_set_name",
    "update_set_role",
}

DECL_PATTERNS = [
    ("function", re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M)),
    ("signal", re.compile(r"^signal\s+([A-Za-z_][A-Za-z0-9_]*)\b", re.M)),
    ("constant", re.compile(r"^const\s+([A-Za-z_][A-Za-z0-9_]*)\b", re.M)),
    (
        "variable",
        re.compile(
            r"^(?:(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^\n]*\))?)\s+)*"
            r"(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\b",
            re.M,
        ),
    ),
]

STRING_RE = re.compile(r'"((?:\\.|[^"\\])*)"|\'((?:\\.|[^\'\\])*)\'')
DYNAMIC_METHOD_RE = re.compile(
    r"\b(?:has_method|get_method_argument_count)\(\s*[\"']([A-Za-z_][A-Za-z0-9_]*)[\"']"
)
DYNAMIC_STRING_RE = re.compile(
    r"\b(?:call|call_deferred|has_method|get_method_argument_count|emit_signal|"
    r"connect|disconnect|set|get|has_signal)\s*\(\s*[\"']([A-Za-z_][A-Za-z0-9_]*)[\"']"
)


def _should_skip(path: Path) -> bool:
    return any(part in IGNORED_PARTS for part in path.parts)


def _collect_text_files() -> dict[Path, str]:
    files: list[Path] = []
    extensions = ("*.gd", "*.tscn", "*.tres", "*.gdshader", "*.godot", "*.yml", "*.yaml", "*.sh", "*.py")
    for ext in extensions:
        for p in ROOT.rglob(ext):
            if p.is_file() and not _should_skip(p):
                files.append(p)
    for extra in (ROOT / "Makefile", ROOT / ".githooks" / "pre-commit"):
        if extra.is_file():
            files.append(extra)
    return {p: p.read_text(encoding="utf-8", errors="ignore") for p in files}


def _strip_code(text: str) -> str:
    """Remove GDScript comments and string literals while preserving line count."""
    without_strings = STRING_RE.sub(lambda m: " " * len(m.group(0)), text)
    return re.sub(r"#.*", "", without_strings)


def _dynamic_string_names(text: str) -> set[str]:
    """Names used through Godot's string-based reflection APIs."""
    return set(DYNAMIC_STRING_RE.findall(text))


def _word_count(text: str, symbol: str) -> int:
    return len(re.findall(r"\b" + re.escape(symbol) + r"\b", text))


def _is_test_path(path: Path) -> bool:
    return "tests" in path.relative_to(ROOT).parts


def _runtime_gd_files() -> list[Path]:
    return sorted(
        list((ROOT / "scripts" / "autoload").rglob("*.gd"))
        + list((ROOT / "scripts" / "resources").rglob("*.gd"))
        + list((ROOT / "scripts" / "scenes").rglob("*.gd"))
        + list((ROOT / "scripts" / "utils").rglob("*.gd"))
        + list((ROOT / "demo").rglob("*.gd"))
    )


def _resource_referenced(rel: str, texts: dict[Path, str], exclude: Path) -> bool:
    res_path = "res://" + rel
    path_re = re.compile(r"(?<![A-Za-z0-9_/])" + re.escape(rel) + r"(?![A-Za-z0-9_/])")
    for path, text in texts.items():
        if path == exclude:
            continue
        if res_path in text or path_re.search(text):
            return True
    return False


def check_unreferenced_scripts(all_texts: dict[Path, str]) -> list[str]:
    issues: list[str] = []
    non_test_texts = {p: txt for p, txt in all_texts.items() if not _is_test_path(p)}

    candidates = sorted(
        list((ROOT / "scripts").rglob("*.gd"))
        + list((ROOT / "demo").rglob("*.gd"))
    )
    for p in candidates:
        if _should_skip(p):
            continue
        rel = p.relative_to(ROOT).as_posix()
        if not _resource_referenced(rel, non_test_texts, p):
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
        rel = p.relative_to(ROOT).as_posix()
        if not _resource_referenced(rel, infra_texts, p):
            issues.append(f"Unreferenced Python script: {rel}")

    return issues


def check_unreferenced_resources(all_texts: dict[Path, str]) -> list[str]:
    issues: list[str] = []
    non_test_texts = {p: txt for p, txt in all_texts.items() if not _is_test_path(p)}
    candidates = sorted(
        list((ROOT / "scenes").rglob("*.tscn"))
        + list((ROOT / "demo").rglob("*.tscn"))
        + list((ROOT / "assets").rglob("*.tres"))
        + list((ROOT / "assets").rglob("*.gdshader"))
    )
    for p in candidates:
        if _should_skip(p):
            continue
        rel = p.relative_to(ROOT).as_posix()
        if not _resource_referenced(rel, non_test_texts, p):
            issues.append(f"Unreferenced resource file: {rel}")
    return issues


def _declared_functions(all_texts: dict[Path, str]) -> set[str]:
    functions: set[str] = set()
    for p in _runtime_gd_files():
        txt = all_texts.get(p, p.read_text(encoding="utf-8", errors="ignore"))
        for kind, pattern in DECL_PATTERNS:
            if kind == "function":
                functions.update(m.group(1) for m in pattern.finditer(txt))
    return functions


def check_dynamic_method_guards(all_texts: dict[Path, str]) -> list[str]:
    issues: list[str] = []
    declared = _declared_functions(all_texts)
    for p in sorted(all_texts):
        if p.suffix != ".gd" or _is_test_path(p):
            continue
        for name in sorted(set(DYNAMIC_METHOD_RE.findall(all_texts[p]))):
            if name not in declared and name not in DYNAMIC_INTERFACE_METHODS:
                issues.append(
                    f"Dynamic method guard references undeclared method: {p.relative_to(ROOT).as_posix()}::{name}"
                )
    return issues


def check_unused_symbols(all_texts: dict[Path, str], include_test_only: bool = False) -> list[str]:
    issues: list[str] = []
    runtime_gd = [p for p in _runtime_gd_files() if not _should_skip(p)]
    code_texts = {p: _strip_code(txt) for p, txt in all_texts.items()}
    scene_texts = {
        p: txt for p, txt in all_texts.items() if p.suffix in {".tscn", ".tres", ".godot"}
    }
    string_names: set[str] = set()
    for txt in all_texts.values():
        string_names.update(_dynamic_string_names(txt))

    for p in runtime_gd:
        txt = all_texts.get(p, p.read_text(encoding="utf-8", errors="ignore"))
        rel = p.relative_to(ROOT).as_posix()
        self_code = code_texts.get(p, _strip_code(txt))

        for kind, pattern in DECL_PATTERNS:
            for match in pattern.finditer(txt):
                sym = match.group(1)
                if kind == "function" and sym in GODOT_LIFECYCLE_FUNCS:
                    continue

                self_count = _word_count(self_code, sym)
                runtime_count = sum(
                    _word_count(code, sym)
                    for other, code in code_texts.items()
                    if other != p and not _is_test_path(other)
                )
                test_count = sum(
                    _word_count(code, sym)
                    for other, code in code_texts.items()
                    if _is_test_path(other)
                )
                scene_count = sum(_word_count(code, sym) for code in scene_texts.values())

                referenced = (
                    self_count > 1
                    or runtime_count > 0
                    or scene_count > 0
                    or sym in string_names
                    or (not include_test_only and test_count > 0)
                )
                if not referenced:
                    issues.append(f"Unused {kind}: {rel}::{sym}")

    return issues


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--include-test-only",
        action="store_true",
        help="Report symbols whose only references are in tests.",
    )
    args = parser.parse_args([] if argv is None else argv)

    all_texts = _collect_text_files()
    issues: list[str] = []
    issues.extend(check_unreferenced_scripts(all_texts))
    issues.extend(check_unreferenced_resources(all_texts))
    issues.extend(check_dynamic_method_guards(all_texts))
    issues.extend(check_unused_symbols(all_texts, args.include_test_only))

    if issues:
        print("ERROR: Dead code detected:")
        for item in issues:
            print(f"  - {item}")
        return 1

    print("Dead code check passed: no unreferenced scripts, scenes, or unused symbols found.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
