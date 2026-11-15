# Race to Dead End - Technical Roadmap

This roadmap tracks remaining future polish items for **Race to Dead End** (Godot `4.7.2-stable`), following completion of the security, performance, gameplay/pooling bug-fix, customization-pack, HUD, mobile touch, daily-run, typography/About UI, Windows/Linux/macOS/Web export, and CI/test-suite milestones.

## Current Baseline (`v0.2.1`)

- **Engine & Builds**: Godot `4.7.2-stable` with automated Web (COI service worker + SHA-256 verification), Linux x86_64, Windows x86_64, and macOS Universal CI exports and GitHub Pages/Release publishing.
- **Verification & Tooling**: 49 GUT test scripts (unit, integration, fuzz, and regression; 1,155 passing tests, 3,179 assertions), `scripts/check_coverage.py` (44/44 runtime scripts covered), `.gdlintrc`, and `.githooks/pre-commit`.

---

## Remaining Planned Improvements

### 1. Signed Android & iOS CI Release Pipelines (`export_presets.cfg`, `.github/workflows/build-and-publish.yml`)
- **Problem:** `export_presets.cfg` and `Makefile` define Android and iOS export targets, while CI currently builds and attaches Web, Linux, Windows, and macOS artifacts to GitHub Releases.
- **Improvement:** Configure keystore/provisioning secrets in GitHub Actions to export signed Android `.apk`/`.aab` (and macOS-runner iOS `.ipa`) artifacts on tagged releases.

### 2. Strict `gdtoolkit` Upgrades for Godot 4.7 Syntax (`scripts/`, `.gdlintrc`)
- **Problem:** `gdtoolkit` `4.5.0` does not yet parse Godot `4.3+` single-line inline lambdas (`func(x): ...`) in a few files (`TransitionLayer.gd`, `test_weather_system.gd`), keeping `gdlint` optional in CI.
- **Improvement:** Upgrade `gdtoolkit` once upstream supports Godot 4.7 lambda grammar and promote `make lint-gd` / `make fmt-check` to strict CI requirements.

### 3. Zero Residual Headless Audio Driver Exit Refs (`scripts/autoload/AudioManager.gd`)
- **Problem:** All scene/node orphan leaks are eliminated (0 orphans), while Godot's headless `--audio-driver Dummy` occasionally reports 2 residual `AudioStreamWAV` / `AudioStreamPlaybackWAV` ObjectDB references at process teardown.
- **Improvement:** Investigate `AudioServer` teardown ordering in Godot headless Dummy driver so `--verbose` exits with 0 ObjectDB instances across all test suites.
