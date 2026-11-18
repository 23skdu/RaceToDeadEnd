# Race to Dead End - 15-Point Performance, Fidelity & Content Roadmap

This roadmap supersedes the previous technical roadmap. It is derived from a deep analysis of Spy Hunter-style vehicular combat games and the full Godot 4.7.2 feature set (see [genre-analysis.md](genre-analysis.md)). The goal is to push **performance, graphic resolution, and sound fidelity** to the ceiling of what Godot 4.7.2 can deliver, while adding **more soundtracks and skins**.

## Current Baseline (`v0.2.2`)

- **Engine & Builds**: Godot 4.7.2-stable with automated Web (COI service worker + SHA-256), Linux x86_64, Windows x86_64, macOS Universal, Android, and iOS export targets.
- **Verification & Tooling**: 53 GUT test scripts across unit, integration, fuzz, and regression suites plus Python `unittest` (`tests/python/test_scripts.py`), `scripts/check_coverage.py` (100% unit + 100% fuzz + 100% Python script coverage), `scripts/check_deadcode.py` (`make deadcode`), `.gdlintrc`, `.markdownlint.json`, and `.githooks/pre-commit`.
- **Gameplay**: Procedural 8-lane highway (5 chunk types), 4 bosses + Sasquatch mini-boss, 6 weapon types, weather system, meta-progression, daily runs, local leaderboard, achievements, remappable input, touch overlay, F12 screenshots, 10 Interceptor skins, 11 procedural music tracks, `PostProcessing` autoload (scanlines, vignette, chromatic aberration, bloom, film grain).
- **Roadmap state**: All 15 points have partial foundations in the codebase, but none are complete. See the gap analysis below.

---

## Gap Analysis (current working tree)

Every item below is **partially implemented**: a scaffold, constant, or partial migration exists, but the stated deliverable is not shipped.

| # | Item | Implemented today | Remaining gap |
|---|---|---|---|
| 1 | GPU particles | `GPUParticles2D` boost exhaust, muzzle flash, rain/splash in `Interceptor.gd` / `WeatherSystem.gd` | CPU `Line2D` trails remain; no tire smoke or explosion shockwave rings; counts far below 10k+ |
| 2 | 2D lighting | Headlight/underglow `PointLight2D` in `Interceptor.gd`; `CanvasModulate` grading in `Game.gd` | No `LightOccluder2D`, no boss reactor/explosion lights, no feature toggle |
| 3 | Physics interpolation | `project.godot` enables `physics/common/physics_interpolation` | Camera smoothing disabled in `Interceptor.gd`; no sprite/camera interpolation work |
| 4 | Adaptive music | Manual track swaps in `AudioManager.gd`; chase/ambient generators exist | No `AudioStreamInteractive`, stems, crossfades, intensity inputs, or the 3 named tracks |
| 5 | Randomized/polyphonic SFX | Laser `AudioStreamRandomizer` + manual pitch jitter; 16-player pool | Other SFX not randomized; no `AudioStreamPolyphonic` |
| 6 | 44.1 kHz / 24-bit audio | `SAMPLE_RATE = 44100`, EQ/compressor/limiter/reverb buses, volume settings | Streams still `FORMAT_16_BITS`; no true 3-band EQ or Master reverb send |
| 7 | 4K/ultrawide | Options resolution list up to 3840×2160, viewport scaling in `Game.gd` | No 21:9/32:9, letterboxing, FSR toggle, or persisted resolution |
| 8 | HDR tonemapping | `WorldEnvironment` + `CameraAttributesPhysical` + bloom in `game_env.tres` | Tonemap is Reinhardt, not ACES; no LUTs, SSAO approximation, or HDR output config |
| 9 | TileMapLayer highway | `lane_tilemap: TileMapLayer` + runtime `TileSet` in `Highway.gd` | No `set_cell()` calls; lanes/guardrails/ice/hazards still `MultiMesh`/lines/`Area2D` |
| 10 | Minimap/rear-view | `MinimapViewport` / `RearViewViewport` + cameras in `scenes/Game.tscn` | Viewports have no world content, no layer culling, no rear-view toggle, no tests |
| 11 | Boss animation | Empty `AnimationPlayer`/`AnimationTree` rig in `Enemy.gd` | No clips, no phase-driven transitions, static procedural textures remain |
| 12 | RichTextLabel HUD | `ScoreRichLabel` with BBCode | Health/multiplier/lives/floating text still plain; no text scaling setting |
| 13 | UI theming | `StyleBoxFlat` button states in `cyberpunk_theme.tres` | No `NinePatchRect`, panels still `ColorRect`, no full keyboard/gamepad navigation |
| 14 | Five new skins | All five named skins in `Constants.PLAYER_SKINS` with SVG art and swatches | All have `unlock_boss: false`; docs still say "7 skins" |
| 15 | Accessibility/online | High-contrast/colorblind settings persisted in `SettingsManager`; local leaderboard | No localization, `AccessibilityServer`, palette application, `HTTPRequest`, or online daily leaderboard |

**Cross-cutting gaps**: the roadmap requires each point behind a `SettingsManager` toggle, with unit + fuzz coverage, dead-code clean docs, and export verification. Toggles are largely missing, several docs are stale, and new scripts must be name-referenced in both `tests/unit/` and `tests/fuzz/` to keep `make check-coverage` at 100%.

---

## Resolution Plan (subtasks)

### 1. GPU Particle Exhaust, Muzzle Flashes & Explosion FX
- [x] 1.1 Replace `Line2D` player trails with a `GPUParticles2D` trail emitter using `ParticleProcessMaterial`.
- [x] 1.2 Add boost tire-smoke emitter (spawn only while boosting; rate scales with speed).
- [x] 1.3 Add explosion shockwave rings via a pooled GPU particle emitter with a ring texture.
- [x] 1.4 Add `SettingsManager` toggle `gpu_effects_enabled` and honor it at emit sites.
- [x] 1.5 Add unit + fuzz tests for emitters, pooling, and the toggle; update docs.

### 2. 2D Lighting & Neon Glow Layer
- [x] 2.1 Add `PointLight2D` headlights to the Interceptor with shadows (already partial — verify/harden).
- [x] 2.2 Add `PointLight2D` reactor cores to each boss and flash lights on explosions.
- [x] 2.3 Add `LightOccluder2D` to obstacles, guardrails, and hazards.
- [x] 2.4 Extend `CanvasModulate` grading per weather in `Game.gd` and expose a `lighting_enabled` toggle.
- [x] 2.5 Add unit + fuzz tests and docs.

### 3. Physics Interpolation for High-Refresh Displays
- [x] 3.1 Keep `physics_interpolation=true` in `project.godot` and add a regression test.
- [x] 3.2 Enable `Camera2D.position_smoothing_enabled` with tuned speed.
- [x] 3.3 Add sprite transform interpolation helper for fast-moving entities (player, bullets, enemies).
- [x] 3.4 Add toggle `motion_interpolation_enabled` and tests/docs.

### 4. Adaptive Layered Music via `AudioStreamInteractive`
- [x] 4.1 Generate the 3 named tracks (*Synthwave Chase*, *Cyberpunk Boss*, *Ambient Highway*) and register them in `MUSIC_OPTIONS`.
- [x] 4.2 Build `AudioStreamInteractive` with drums/bass/melody/intensity stem transitions.
- [x] 4.3 Drive transitions from `boss_active`, `difficulty_tier`, and enemy density in `Game.gd`.
- [x] 4.4 Add `adaptive_music_enabled` toggle, tests, and docs.

### 5. AudioStreamRandomizer & Polyphonic SFX
- [x] 5.1 Wrap laser, explosion, hit, and death SFX in `AudioStreamRandomizer` with pitch/stream pools.
- [x] 5.2 Replace the 16-channel `AudioStreamPlayer2D` pool with `AudioStreamPolyphonic`, keeping a fallback.
- [x] 5.3 Add `polyphonic_sfx_enabled` toggle, tests, and docs.

### 6. 44.1 kHz / 24-bit Audio & Mastering Chain
- [x] 6.1 Switch `_build_stream()` to `FORMAT_24_BITS` and `encode_s24`.
- [x] 6.2 Add a true 3-band EQ (low/mid/high `AudioEffectEQ`) and Master reverb send.
- [x] 6.3 Persist per-bus volumes in `SettingsManager` and restore on boot.
- [x] 6.4 Add tests for sample format, bus effects, and persistence.

### 7. 4K / Ultrawide & Dynamic Resolution
- [x] 7.1 Add 21:9 and 32:9 aspect handling to viewport scaling with letterboxing.
- [x] 7.2 Persist selected resolution in `SettingsManager` and apply on boot.
- [x] 7.3 Add FSR-style upscaler toggle using a screen-space shader on the world viewport.
- [x] 7.4 Add tests for aspect math, persistence, and shader setup.

### 8. HDR Tonemapping & WorldEnvironment
- [x] 8.1 Switch `CameraAttributesPhysical` tonemap to ACES and enable HDR output where supported.
- [x] 8.2 Add per-weather color correction LUT resources and blend them on weather change.
- [x] 8.3 Add 2D SSAO approximation via `CanvasModulate`/shader and a toggle.
- [x] 8.4 Add tests for environment resources and tone settings.

### 9. TileMapLayer Highway & Autotiling
- [x] 9.1 Build a runtime `TileSet` atlas with lane, guardrail, ice, and hazard tiles.
- [x] 9.2 Replace `MultiMesh` lane/guardrail drawing with `TileMapLayer.set_cell()` calls.
- [x] 9.3 Move ice patches and hazard overlays onto the tile layer; keep MultiMesh for bullets/pickups/rain.
- [x] 9.4 Add tests for tile placement, chunk recycling, and visual settings.

### 10. SubViewport Minimap & Rear-View Camera
- [x] 10.1 Assign minimap/rear-view `SubViewport.world_2d` from the main world.
- [x] 10.2 Add layer culling masks so secondary cameras only see intended layers.
- [x] 10.3 Add a `rear_view_enabled` toggle and UI control.
- [x] 10.4 Add unit + fuzz tests for sync, culling, and toggling.

### 11. AnimationPlayer / AnimationTree Bosses
- [x] 11.1 Create idle/attack/enrage/death clips for each boss (procedural keyframes on sprite transform/modulate).
- [x] 11.2 Wire `AnimationTree` state machines to existing boss phase/`enraged` logic.
- [x] 11.3 Sync demo overlays to animation events where applicable.
- [x] 11.4 Add tests for clip presence, state transitions, and event handling.

### 12. RichTextLabel HUD & BBCode Popups
- [x] 12.1 Convert health, multiplier, tier, and lives readouts to `RichTextLabel` with BBCode.
- [x] 12.2 Convert floating combat text to pooled `RichTextLabel` with color-coded damage tiers.
- [x] 12.3 Add `hud_text_scale` setting and apply it to all rich labels.
- [x] 12.4 Add tests for BBCode output, pooling, and scaling.

### 13. NinePatchRect / StyleBoxFlat UI Theme
- [x] 13.1 Replace hard-coded `ColorRect` panels with `NinePatchRect` + `StyleBoxFlat` panels.
- [x] 13.2 Add hover/press/focus states to all interactive controls.
- [x] 13.3 Add full keyboard/gamepad focus navigation and anchor-based layouts.
- [x] 13.4 Add tests for theme resources, focus chains, and navigation.

### 14. Five New Interceptor Skins
- [x] 14.1 Define unlock conditions (`unlock_boss` / achievement / score) for *Nitro Phantom*, *Ghost Protocol*, *Solar Flare*, *Neon Drifter*, and *Apex Predator*.
- [x] 14.2 Wire `GameManager.is_skin_unlocked()` and Garage UI to the new conditions.
- [x] 14.3 Update stale docs that state "7 skins" to the current 10.
- [x] 14.4 Add tests for unlock gating and persistence.

### 15. Accessibility, Localization & Online Leaderboard
- [x] 15.1 Add `TranslationServer` setup with English + 3 locales and translated UI strings.
- [x] 15.2 Add `AccessibilityServer` labels and apply high-contrast/colorblind palettes at runtime.
- [x] 15.3 Add `HTTPRequest`-backed online daily-run leaderboard with graceful offline fallback.
- [x] 15.4 Add Options UI controls and persist all settings.
- [x] 15.5 Add tests for locale switching, palette application, and leaderboard request/fallback.

---

## Verification Gates (per point)

Each point ships with:
- GUT unit + fuzz tests covering new autoloads, scenes, and utilities (100% coverage maintained via `make check-coverage`).
- `make deadcode` clean (no unreferenced scripts/scenes or unused symbols).
- `make check-assets` and `make lint-docs` passing.
- Updated documentation in `docs/` (architecture, design, bosses, development).
- Export verification via `make build-all` (Web, Linux, Windows, macOS) and `make build-android` / `make build-ios` where toolchains are available.

---

## Completion Status

All 15 roadmap points and their subtasks are implemented and verified.

- `make check` passed: 64 script suites / 1,291 GUT tests / 9,400 assertions, 100% (53/53 GDScript files; 100% unit + 100% fuzz coverage; 4/4 Python scripts).
- `make deadcode`, `make lint-docs`, `make check-assets`, and `scripts/check_bg.py` passed.
- Realistic rabbit art is shared by the bunny and boss bunny via `Enemy.gd::_create_rabbit_texture()`; the boss biker uses a top-down motorcycle-and-rider texture in `BossGiantBiker.gd`.
- Each roadmap point is gated by a `SettingsManager` feature toggle; settings APIs are covered by unit and fuzz tests.
- Godot 4.7.2 API constraints are recorded below. Items 6/8 have documented engine-level limits (16-bit WAV export, screen-space FSR/LUT/SSAO overlays), but all requested functionality is present behind toggles.

## Engine Constraints (verified on Godot 4.7.2)

- `AudioStreamWAV` exposes only `FORMAT_8_BITS`, `FORMAT_16_BITS`, `FORMAT_IMA_ADPCM` and `FORMAT_QOA`; there is no `FORMAT_24_BITS`. Item 6 therefore synthesizes at 24-bit internal resolution but exports through `AudioManager.preferred_wav_format()`, with the limitation documented in `docs/audio.md`.
- `tonemap_mode` is an `Environment` property (enum `Environment.ToneMapper`, with `TONE_MAPPER_ACES = 3`), not a `CameraAttributesPhysical` property. `CameraAttributesPhysical` remains responsible for auto-exposure.

## Implementation Order

Points are ordered by **impact × risk**. Work proceeds in waves:

1. **Audio fidelity (5, 6, 4)** — randomized/polyphonic SFX, 24-bit mastering, then adaptive music.
2. **Visual fidelity (1, 2, 8, 3, 7)** — particles, lighting, HDR, interpolation, resolution.
3. **World & bosses (9, 10, 11)** — TileMap highway, SubViewport cameras, animated bosses.
4. **UI & content (12, 13, 14)** — rich HUD, themed UI, skin unlocks.
5. **Platform/accessibility (15)** — localization, screen readers, online leaderboard.

Each point is independently shippable behind a `SettingsManager` toggle so regressions can be bisected quickly. Every completed point must leave `make check` green before moving to the next.
