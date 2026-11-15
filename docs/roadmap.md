# Race to Dead End - 15-Point Performance, Fidelity & Content Roadmap

This roadmap supersedes the previous technical roadmap. It is derived from a deep analysis of Spy Hunter-style vehicular combat games and the full Godot 4.7.2 feature set (see [genre-analysis.md](genre-analysis.md)). The goal is to push **performance, graphic resolution, and sound fidelity** to the ceiling of what Godot 4.7.2 can deliver, while adding **more soundtracks and skins**.

## Current Baseline (`v0.2.2`)

- **Engine & Builds**: Godot 4.7.2-stable with automated Web (COI service worker + SHA-256), Linux x86_64, Windows x86_64, macOS Universal, Android, and iOS export targets.
- **Verification & Tooling**: 53 GUT test scripts across unit, integration, fuzz, and regression suites plus Python `unittest` (`tests/python/test_scripts.py`), `scripts/check_coverage.py` (100% unit + 100% fuzz + 100% Python script coverage), `scripts/check_deadcode.py` (`make deadcode`), `.gdlintrc`, `.markdownlint.json`, and `.githooks/pre-commit`.
- **Gameplay**: Procedural 8-lane highway (5 chunk types), 4 bosses + Sasquatch mini-boss, 6 weapon types, weather system, meta-progression, daily runs, local leaderboard, achievements, remappable input, touch overlay, F12 screenshots, 7 Interceptor skins, 11 procedural music tracks, `PostProcessing` autoload (scanlines, vignette, chromatic aberration, bloom, film grain).

---

## 15-Point Plan

### 1. GPU Particle Exhaust, Muzzle Flashes & Explosion FX (`scripts/scenes/player/Interceptor.gd`, `scripts/scenes/world/WeatherSystem.gd`)
Migrate all CPU-drawn trails and flashes to `GPUParticles2D` with `ParticleProcessMaterial`. Add tire smoke on boost, muzzle flash on primary fire, and shockwave rings on explosions. Target 60 fps with 10k+ particles on mid-range GPUs.

### 2. 2D Lighting & Neon Glow Layer (`scripts/scenes/player/Interceptor.gd`, `scripts/scenes/enemies/*.gd`, `scripts/autoload/PostProcessing.gd`)
Add `PointLight2D` (with `shadow_enabled`) for Interceptor headlights, boss reactor cores, neon underglow, and explosion flashes. Add `LightOccluder2D` to obstacles and highway guardrails. Layer a `CanvasModulate` for per-weather color grading (acid rain = green, storm = desaturated).

### 3. Physics Interpolation for High-Refresh Displays (`project.godot`, `scripts/scenes/player/Interceptor.gd`)
Enable `physics/common/physics_interpolation` and smooth `Camera2D` / sprite transforms between physics ticks so motion stays buttery on 120 Hz+ displays without changing the 60 Hz simulation step.

### 4. Adaptive Layered Music via AudioStreamInteractive (`scripts/autoload/AudioManager.gd`, `scripts/scenes/Game.gd`)
Replace hard track swaps with `AudioStreamInteractive` stem layers (drums, bass, melody, intensity). Crossfade stems based on `boss_active`, `difficulty_tier`, and enemy density for a seamless adaptive soundtrack. Add 3 new full tracks: *Synthwave Chase*, *Cyberpunk Boss*, and *Ambient Highway*.

### 5. AudioStreamRandomizer & Polyphonic SFX (`scripts/autoload/AudioManager.gd`)
Wrap laser, explosion, hit, and death SFX in `AudioStreamRandomizer` with pitch and stream pools. Migrate the 16-channel `AudioStreamPlayer2D` pool to `AudioStreamPolyphonic` so overlapping explosions never steal channels or clip.

### 6. 44.1 kHz / 24-bit Audio & Mastering Chain (`scripts/autoload/AudioManager.gd`, `scripts/autoload/SettingsManager.gd`)
Raise `SAMPLE_RATE` from 22050 Hz to 44100 Hz and generate 24-bit PCM (`FORMAT_24_BITS`). Add a mastering chain (compressor, 3-band EQ, limiter, reverb send) on the Master bus with per-bus volume persisted in `SettingsManager`.

### 7. 4K / Ultrawide & Dynamic Resolution (`project.godot`, `scripts/scenes/Game.gd`, `scripts/scenes/player/Interceptor.gd`)
Support 1920×1080, 2560×1440, 3840×2160, and 21:9/32:9 ultrawide. Replace the fixed 1280×720 base with dynamic viewport scaling, letterboxing, and a resolution selector in Options. Add an FSR-style upscaler toggle for low-end hardware.

### 8. HDR Tonemapping & WorldEnvironment (`scripts/scenes/Game.gd`, `assets/environments/game_env.tres`)
Enable `CameraAttributesPhysical` with auto-exposure and ACES tonemapping. Add bloom, SSAO (2D approximated via CanvasModulate), and color correction LUTs per weather state for cinematic HDR output on supported displays.

### 9. TileMapLayer Highway & Autotiling (`scripts/scenes/world/Highway.gd`, `scenes/world/Highway.tscn`)
Migrate the procedural highway from custom `MultiMeshInstance2D` to `TileMapLayer` with autotiling for lane markings, guardrails, ice patches, and hazard overlays. Keep MultiMesh for bullets/pickups/rain for maximum GPU throughput.

### 10. SubViewport Minimap & Rear-View Camera (`scripts/scenes/Game.gd`, `scenes/Game.tscn`)
Add a `SubViewportContainer` + `SubViewport` rendering a top-down minimap and an optional rear-view mirror. Reuse the existing camera transform with a second `Camera2D` and layer culling to keep draw calls flat.

### 11. AnimationPlayer / AnimationTree Bosses (`scripts/scenes/enemies/Boss*.gd`, `scenes/enemies/Boss*.tscn`)
Replace static procedural boss textures with skeletal `AnimationPlayer`/`AnimationTree` rigs (idle, attack, enrage, death). Drive state transitions from existing boss phase logic and sync demo overlays to animation events.

### 12. RichTextLabel HUD & BBCode Popups (`scripts/scenes/ui/HUD.gd`, `scripts/scenes/Game.gd`)
Migrate score, health, multiplier, and floating combat text to `RichTextLabel` with BBCode for color-coded damage tiers, animated score popups, and accessibility-friendly text scaling.

### 13. NinePatchRect / StyleBoxFlat UI Theme (`scenes/ui/*.tscn`, `assets/themes/cyberpunk_theme.tres`)
Replace hard-coded `ColorRect` panels with `NinePatchRect` and `StyleBoxFlat` for scalable, themed, resolution-independent UI. Add hover/press/focus states and keyboard/gamepad navigation to all menus.

### 14. Five New Interceptor Skins (`scripts/autoload/Constants.gd`, `assets/sprites/player/`)
Add *Nitro Phantom* (void-black + purple/cyan ghost trails), *Ghost Protocol* (matte black + ice-cyan digital camo), *Solar Flare* (gold + crimson), *Neon Drifter* (magenta + teal), and *Apex Predator* (carbon fiber + amber). Each ships with matching color swatches and unlock conditions.

### 15. Accessibility, Localization & Online Leaderboard (`scripts/autoload/GameManager.gd`, `scripts/scenes/ui/Options.gd`, `project.godot`)
Add `TranslationServer`-backed localization (English + 3 languages), `AccessibilityServer` screen-reader labels, high-contrast / colorblind palettes, and an optional `HTTPRequest`-backed online leaderboard for daily runs. Persist all settings in `SettingsManager`.

---

## Verification Gates (per point)

Each point ships with:
- GUT unit + fuzz tests covering new autoloads, scenes, and utilities (100% coverage maintained).
- `make deadcode` clean (no unreferenced scripts/scenes or unused symbols).
- `make check-assets` and `make lint-docs` passing.
- Updated documentation in `docs/` (architecture, design, bosses, development).
- Export verification via `make build-all` (Web, Linux, Windows, macOS) and `make build-android` / `make build-ios` where toolchains are available.

## Implementation Order

Points are ordered by **impact × risk**: lighting and post-processing (2, 8) first for immediate visual payoff, then audio fidelity (5, 6, 4), then resolution/performance (3, 7, 1, 9, 10), then content (11, 12, 13, 14), then platform/accessibility (15). Each point is independently shippable behind a `SettingsManager` toggle so regressions can be bisected quickly.
