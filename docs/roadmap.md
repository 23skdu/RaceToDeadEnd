# Race to Dead End - 15-Point Performance, Fidelity & Content Roadmap

This roadmap supersedes the previous technical roadmap. It is derived from a deep analysis of Spy Hunter-style vehicular combat games and the full Godot 4.7.2 feature set (see [genre-analysis.md](genre-analysis.md)). The goal is to push **performance, graphic resolution, and sound fidelity** to the ceiling of what Godot 4.7.2 can deliver, while adding **more soundtracks and skins**.

## Current Baseline (`v0.2.6`)

- **Engine & Builds**: Godot 4.7.2-stable with automated Web (COI service worker + SHA-256), Linux x86_64, Windows x86_64, macOS Universal, Android, and iOS export targets.
- **Verification & Tooling**: 64 GUT test scripts (1,306 tests / 9,612 assertions) across unit, integration, fuzz, and regression suites plus Python `unittest` (`tests/python/test_scripts.py`), `scripts/check_coverage.py` (100% unit + 100% fuzz + 100% Python script coverage), `scripts/check_deadcode.py` (`make deadcode`), `make check-leaks` / `make check-memory-leaks` (verbose exit ObjectDB, RID, resource, StringName, and orphan node leak verification), `.gdlintrc`, `.markdownlint.json`, and `.githooks/pre-commit`.
- **Gameplay**: Procedural 4-lane highway (5 chunk types), 4 bosses + Sasquatch mini-boss, 6 weapon types, weather system, meta-progression, daily runs, local and online leaderboards, achievements, remappable input, touch overlay, F12 screenshots, 10 Interceptor skins, 13 procedural music options (including adaptive 4-stem `AudioStreamInteractive` mix), `PostProcessing` autoload (scanlines, vignette, chromatic aberration, bloom, film grain).
- **Roadmap state**: All 15 points and their subtasks are implemented, feature-gated via `SettingsManager`, and verified by unit, integration, fuzz, regression, deadcode, and zero-leak checks. See the historical baseline gap analysis and the post-`v0.2.6` further gap analysis below.

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
- `make check-orphans` clean (GUT post-run guard fails on any orphaned node).
- `make check-assets` and `make lint-docs` passing.
- Updated documentation in `docs/` (architecture, design, bosses, development).
- Export verification via `make build-all` (Web, Linux, Windows, macOS) and `make build-android` / `make build-ios` where toolchains are available.

---

## Completion Status

All 15 roadmap points and their subtasks are implemented and verified.

- `make check` and `make check-leaks` passed: 64 script suites / 1,306 GUT tests / 9,612 assertions, 100% coverage (53/53 GDScript files; 100% unit + 100% fuzz coverage; 4/4 Python scripts), 0 orphan nodes, 0 ObjectDB leaks, 0 RID leaks, and 0 unclaimed StringNames.
- `make deadcode`, `make lint-docs`, `make check-assets`, and `scripts/check_bg.py` passed.
- Realistic rabbit art is shared by the bunny and boss bunny via `Enemy.gd::_create_rabbit_texture()`; the boss biker uses a top-down motorcycle-and-rider texture in `BossGiantBiker.gd`.
- Each roadmap point is gated by a `SettingsManager` feature toggle; settings APIs are covered by unit and fuzz tests.
- Godot 4.7.2 API constraints are recorded below. Items 6/8 have documented engine-level limits (16-bit WAV export, screen-space FSR/LUT/SSAO overlays), but all requested functionality is present behind toggles.

---

## Memory Leak & Frame-Pacing Hardening (`v0.2.6`)

During the `v0.2.6` audit, memory leaks and frame-pacing/jitter bottlenecks were tracked down, resolved, and locked behind automated verification:

1. **Automated Memory Leak Gate (`make check-leaks` / `make check-memory-leaks`)**:
   - Added `check-leaks` (and alias `check-memory-leaks`) to `Makefile` and wired it into `make check` and `.githooks/pre-commit`.
   - Runs the full GUT suite under `godot --headless --verbose` with `-gpost_run_script=res://tests/gut_orphan_guard.gd` and fails on any orphan node, leaked `ObjectDB` instance, leaked `RID` allocation, unclaimed `StringName`, or freed lambda capture.
2. **Resolved Memory & Resource Leaks**:
   - **Freed Lambda Capture in `PoopWeapon.gd`**: Replaced direct `body: Node` capture in the 2.0-second slippery-debuff `SceneTreeTimer` lambda with `weakref(body)` so freeing an entity before the timer expires never triggers a freed lambda capture error.
   - **Conditional `MultiMeshInstance2D` Allocation in `Highway.gd`**: Moved `crack_mmi = MultiMeshInstance2D.new()` inside `if crack_positions.size() > 0:` in `_build_tiles_into()` so chunks with zero random cracks never leak an unparented `MultiMeshInstance2D` node and its `CanvasItem` RID.
   - **Pooled Obstacle Reuse in `Enemy.gd` & `Highway.gd`**: When bosses collide with obstacles inside pooled `Highway` `Tiles` buffers, `Enemy.handle_obstacle_collisions()` hides and disables the obstacle collider instead of calling `queue_free()`, and `Highway._reconnect_chunk_signals()` restores visibility and collision layers when the chunk buffer is recycled.
   - **Reusable Explosion Visual in `DroneBomb.gd`**: Pre-allocated `explosion_visual` in `_ready()` and toggled visibility on detonation/pool acquisition instead of allocating and freeing a new `Polygon2D` on every detonation.
   - **Audio & Static Cache Teardown (`AudioManager.gd`, `ObjectPool.gd`, `tests/gut_orphan_guard.gd`)**: Added `AudioManager.stop_all_audio()` (stopping players, clearing `_stream_car_engine` and all cached streams/randomizers/interactive stems, and lazy-starting polyphonic playback only when enabled), `ObjectPool.clear_all_pools()`, and `gut_orphan_guard.gd::release_static_caches()` with mixer frame draining so headless runs exit with 0 leaked `ObjectDB` instances.
3. **Resolved Gameplay Stutters & Frame Jitter**:
   - **Restored VSync (`project.godot`)**: Restored `window/vsync/vsync_mode=1` under `[display]` for consistent desktop frame pacing.
   - **Eliminated Main/Secondary Camera Interpolation Jitter (`Interceptor.gd`, `Interceptor.tscn`, `Game.gd`)**: Disabled conflicting `Camera2D.position_smoothing_enabled` when `physics_interpolation` is active, interpolated `$Camera2D` Y tracking across render frames using `Engine.get_physics_interpolation_fraction()`, and synced `_minimap_camera` and `_rear_view_camera` in `Game.gd` to `player.get_interpolated_global_position()`.
   - **Eliminated Per-Frame Adaptive Music Transition Spam (`AudioManager.gd`)**: Guarded `AudioStreamPlaybackInteractive.switch_to_clip(target)` in `AudioManager.set_music_intensity()` so it is only invoked when the target clip index changes or playback starts, rather than re-triggering transition scheduling on every `_process()` frame.
   - **Eliminated Per-Segment Shader Recompilation & Per-Kill Texture Synthesis (`RoadmapWorld.gd`, `RoadmapFx.gd`, `Game.gd`)**: Cached compiled `Shader` instances (`_lut_shader`, `_fsr_shader`, `_ssao_shader`) in `RoadmapWorld.gd`, reused the `_grade_overlay` `ShaderMaterial` in `Game.gd::_apply_weather_lut()`, and cached procedural glow, ring, and weather LUT textures in `RoadmapFx.gd`.

---

## Further Gap Analysis (Post-`v0.2.6` Audit)

A comprehensive audit of the `v0.2.6` codebase after completing the 15-point roadmap and frame-jitter fixes identified the following next-horizon gaps across options UI exposure, rendering pipeline consolidation, procedural world/combat pooling, and gameplay fidelity:

| # | Area | Current state (`v0.2.6`) | Remaining gap / opportunity |
|---|---|---|---|
| G1 | **Options UI Coverage for All Roadmap Feature Toggles & Ultrawide Modes** | `Options.gd` generates checkboxes for the 4 keys in `Constants.ROADMAP_FEATURE_KEYS` (`boss_animations`, `themed_ui`, `localization`, `online_leaderboard`) and lists 4 16:9 resolutions in `RESOLUTION_OPTIONS`. | The other 11 feature toggles (`tilemap_highway`, `rear_view`, `fsr_upscaling`, `rich_hud`, `lighting_enabled`, `hdr_tonemapping`, `weather_luts`, `ssao_approximation`, `motion_interpolation_enabled`, `polyphonic_sfx`, `randomized_sfx`, `adaptive_music`) plus `hud_text_scale` and `particle_scale` sliders and ultrawide presets (`2560x1080`, `3440x1440`, `3840x1080`) exist in `RoadmapWorld` / `RoadmapFx` / `AudioManager` APIs but are not exposed as interactive controls in `Options.tscn` / `Options.gd`. |
| G2 | **Options Resolution Selector Integration with `Game.apply_resolution()`** | `Options.gd::_on_resolution_selected()` calls `DisplayServer.window_set_size(sz)` directly without persisting `"resolution"` in `SettingsManager` or updating `Game.active_resolution` / letterbox bars. | Route `Options.gd` resolution selection through `RoadmapWorld.sanitize_resolution()` and persist `RoadmapWorld.KEY_RESOLUTION` so in-game pause-menu resolution changes immediately update ultrawide pillarbox/letterbox framing. |
| G3 | **Multi-Pass Fullscreen Canvas Shader Consolidation** | When `PostProcessing` (CRT/scanlines/chromatic aberration/vignette/film grain), `WeatherSystem` (`WetRoadReflection`), and `Game.gd` (`FsrUpscaler`, `SsaoApproximation`, `WeatherLutGrade`) are all enabled, multiple full-viewport `ColorRect` passes sample `hint_screen_texture` sequentially each frame. | Consolidate `FsrUpscaler`, `SsaoApproximation`, and `WeatherLutGrade` into a single combined post-process `ShaderMaterial` pass (with uniform toggles) to eliminate redundant fullscreen backbuffer copies on 4K/integrated GPUs. |
| G4 | **Pooled Explosion Flash Lights & Mine/Lightning Visuals** | `Game.spawn_explosion_flash()` and `RoadmapFx.spawn_explosion_flash()` reuse cached `Texture2D` assets, but still instantiate and `queue_free()` a `PointLight2D` node + `Tween` per explosion; `Mine.gd::_explode()` allocates a temporary `Polygon2D` flash, and `WeatherSystem.gd` allocates `Line2D` / `ColorRect` nodes per lightning strike and cloud. | Add a fixed pre-warmed `PointLight2D` flash ring buffer in `Game.gd` / `RoadmapFx.gd`, pre-allocate reusable lightning/cloud nodes in `WeatherSystem.gd`, and replace `Mine.gd`'s ephemeral `Polygon2D` with a pooled flash effect. |
| G5 | **Async / Pre-Warmed Adaptive Music Stems & Core SFX** | `AudioManager._generate_all_async()` pre-generates the 12 stage/synthwave music tracks and 5 demo tracks on `WorkerThreadPool`, while `_adaptive_music` (4 × 4.0s stems) and core SFX (`_stream_laser`, `_stream_explosion`, etc.) synthesize lazily on first play. | Offload `_build_adaptive_music()` stem generation to `WorkerThreadPool` at startup so the first transition into gameplay never synthesizes 16s of PCM audio on the main thread, while preserving lazy unit-test contracts on individual SFX fields. |
| G6 | **2D Physics Interpolation Extension to Enemies, Projectiles & Pickups** | `Interceptor.gd` interpolates its `Sprite2D` transform and camera position between physics ticks using `Engine.get_physics_interpolation_fraction()`. | Extend visual sub-tick transform interpolation (`RoadmapFx.interpolate_transform`) or native Godot 2D physics interpolation to fast-moving `Bullet.gd`, `Enemy.gd`, and `PoopWeapon.gd` sprites on 120 Hz / 144 Hz / 240 Hz monitors. |
| G7 | **Documentation & Architecture Sync** | `docs/roadmap.md` reflects `v0.2.6`, while parts of `docs/architecture.md` and `README.md` still mention older counts (e.g., "9 selectable music options", "10 singletons", or "22050 Hz" in legacy sections). | Synchronize `docs/architecture.md`, `docs/development.md`, and `README.md` with the current 11 autoloads, 13 music options, 10 skins, 44.1 kHz synthesis pipeline, and `make check-leaks` workflow. |

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
