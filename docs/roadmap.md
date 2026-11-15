# Race to Dead End - Technical Roadmap

This roadmap consolidates all remaining planned improvements for **Race to Dead End** (Godot `4.7.2-stable`, `v0.2.0`), following completion of the initial security, performance, gameplay bug-fix, customization-pack, HUD, mobile touch, daily-run, and CI/test-suite hardening milestones.

## Current Baseline (`v0.2.0`)

- **Engine & Build**: Godot `4.7.2-stable` with automated Web (COI service worker + SHA-256 verification), Linux x86_64, and macOS Universal CI exports and GitHub Pages/Release publishing.
- **Verification & Tooling**: 48 GUT test scripts (unit, integration, fuzz, and regression; 1,144 passing tests, 3,131 assertions), `scripts/check_coverage.py` (43/43 runtime scripts covered), and `.githooks/pre-commit` enforcement.

---

## Remaining Planned Improvements

### Visual Polish & Shaders

#### 1. Dynamic Rain Splashes and Road Reflection Effects (`scripts/scenes/world/WeatherSystem.gd`, `scripts/scenes/world/Highway.gd`)
- **Problem:** During `LIGHT_RAIN`, `ACID_RAIN`, and `STORM` weather states, rain droplets fall across the screen without interacting with the highway surface, leaving the road looking dry and static.
- **Improvement:** Add micro-splash particles where rain impacts the highway surface, and introduce a lightweight wet-road reflection shader or modulating layer reflecting the synthwave sun, neon signage, and glowing enemy eyes.
- **Verification:** Visual inspection across `CLEAR` -> `LIGHT_RAIN` -> `ACID_RAIN` -> `STORM` transitions plus unit tests verifying wet-road shader/splash state activation on weather changes.

#### 2. EMP Shockwave Screen-Space Distortion (`scripts/scenes/weapons/EMPBlast.gd`, `scenes/weapons/EMPBlast.tscn`)
- **Problem:** The EMP blast stuns and damages enemies as designed, but its expanding visual lacks screen-space impact and weight.
- **Improvement:** Add a screen-space radial shockwave distortion shader on `EMPBlast` whose ring radius and intensity track the expanding EMP collision radius.
- **Verification:** Trigger EMP in-game and add a unit test confirming shader uniforms track EMP radius expansion and reset cleanly on `on_pool_release()`.

---

### Performance & Engine Hygiene

#### 3. GPU-Driven Parallax Sky & Zero Exit ObjectDB Refs (`scripts/scenes/Game.gd`, `scripts/autoload/AudioManager.gd`)
- **Problem:** While `Game._setup_parallax()` caches generated textures across runs in `_parallax_texture_cache`, first-run initialization still writes 550k+ pixels on the CPU. Additionally, headless runs occasionally report 2–4 residual `AudioStreamWAV` / `AudioStreamPlaybackWAV` ObjectDB references at process exit.
- **Improvement:** Replace the CPU pixel loop in `Game._setup_parallax()` with lightweight procedural canvas shaders (or `WorkerThreadPool` image generation), and release cached audio streams cleanly on `AudioManager._exit_tree()` so `--verbose` exits with zero ObjectDB leaks across all test suites.
- **Verification:** Benchmark first-run `Game.tscn` load time and assert zero ObjectDB leaks in `make test --verbose`.

---

### Tooling, CI & Platform Expansion

#### 4. Enforce `gdtoolkit` (`gdlint` / `gdformat`) in CI & Add `.gdlintrc` (`Makefile`, `.github/workflows/build-and-publish.yml`)
- **Problem:** `Makefile` runs `gdlint` and `gdformat --check` opportunistically when installed locally, but CI does not yet install `gdtoolkit` or enforce consistent GDScript formatting/linting via a project `.gdlintrc`.
- **Improvement:** Add a tuned `.gdlintrc` matching project conventions, install `gdtoolkit` in the CI `Test & Verify` job (and `scripts/requirements.txt`), and make `lint-gd` and `fmt-check` strict gates in CI.
- **Verification:** `make lint-gd` and `make fmt-check` pass with zero errors both locally and in GitHub Actions.

#### 5. Windows Desktop Preset & Signed Mobile CI Builds (`export_presets.cfg`, `Makefile`, `.github/workflows/build-and-publish.yml`)
- **Problem:** `export_presets.cfg` and `Makefile` define Web, Linux, macOS, Android, and iOS targets, while Windows Desktop is not yet configured in `export_presets.cfg` and Android/iOS builds are not packaged in CI releases.
- **Improvement:** Add a `Windows Desktop` preset to `export_presets.cfg` + `build-windows` target in `Makefile`, and wire Windows release artifacts (plus optional Android APK packaging) into `.github/workflows/build-and-publish.yml`.
- **Verification:** `godot --headless --export-release "Windows Desktop"` succeeds cleanly in CI and attaches the Windows archive to tagged GitHub Releases.
