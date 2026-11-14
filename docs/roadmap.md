# Race to Dead End - Technical Roadmap & Deep Code Analysis

This roadmap captures findings from a full codebase audit of **Race to Dead End** (Godot 4.7.2, GDScript, GUT test suite) and outlines **15 prioritized improvements** across **Performance**, **Security**, **Code Quality & Accuracy**, and **User Functionality**.

---

## Executive Summary of Codebase Audit

- **Engine & Runtime**: Godot `4.7.2-stable`, 9 autoload singletons (`GameManager`, `ScoreManager`, `AudioManager`, `Constants`, `ObjectPool`, `PackManager`, `CameraShake`, `TransitionLayer`, `SettingsManager`), procedural audio synthesis, procedural highway chunks, and procedural pixel textures.
- **Test Coverage**: 46 GUT test files (44 unit + 2 integration; 1,108 passing tests, 1,922 assertions).
- **Key Risks Identified**:
  1. Unsynchronized shared `RandomNumberGenerator` across `WorkerThreadPool` audio synthesis threads.
  2. Uncached per-instance procedural textures/shaders, per-frame `Gradient` allocations, and 1,396+ orphan nodes reported during test runs.
  3. Tamperable plaintext save file (`user://save.dat`) with checksum bypass (`stored_checksum == 0`), plus path-traversal and arbitrary `ResourceLoader.load()` risks in `PackManager.gd`.
  4. Several silent gameplay/UI bugs (unwired `PackManager` pack application, invisible boost trail gradient, `Scav` / `Interceptor` 4-lane legacy offsets in an 8-lane highway, `HUD` multiplier pulse reset, `BossWarRig` spread-fire guard, broken `highway_tileset.tres`, and input bindings not loaded at startup).

---

## 15 Roadmap Improvements

### Performance Improvements

#### 1. Thread-Safe & Cached Procedural Audio Synthesis (`scripts/autoload/AudioManager.gd`)
- **Problem:** `AudioManager._generate_all_async()` spawns 9 `WorkerThreadPool` tasks that concurrently call `self._rng.randf()` on a single shared `RandomNumberGenerator` instance without locking (`_generate_game_music_bunny`, `_generate_game_music_biker`, `_generate_game_music_sasquatch`, `_generate_game_music_void`), creating a data race and non-deterministic waveforms. Additionally, `_generate_menu_music()` (16 seconds at 22,050 Hz = 352,800 samples) runs synchronously on `_ready()`.
- **Improvement:** Give each generator task its own local `RandomNumberGenerator` seeded deterministically, move `_generate_menu_music()` onto `WorkerThreadPool` (or synthesize a shorter seamless loop), and replace per-sample GDScript `pow()` / `sin()` calls inside inner loops with precomputed lookup tables or phase accumulators.
- **Impact:** Eliminates thread race conditions and reduces startup main-thread stall.

#### 2. Cache Procedural Enemy/Boss/Weapon Textures & Share Eye Shader (`scripts/scenes/enemies/`, `scripts/scenes/weapons/`)
- **Problem:** While `Enemy.gd` caches `_bunny_texture` in a `static var`, `BossBunny.gd`, `BossGiantBiker.gd`, `BossSasquatch.gd` (used for wandering Sasquatches as well as bosses), `BossVoidDrone.gd`, `BabyBunnyBomb.gd`, and `PoopWeapon.gd` regenerate 16×16 to 128×128 `ImageTexture`s pixel-by-pixel via GDScript `Image.set_pixel()` on every instantiation. Furthermore, `Enemy.apply_pulsating_eyes_shader()` compiles a fresh `Shader.new()` and `ShaderMaterial.new()` on every acquire/ready.
- **Improvement:** Cache each procedural texture and the shared pulsating-eye `ShaderMaterial` in `static var` singletons (or an asset cache resource), and build `Game._setup_parallax()` layers asynchronously or via lightweight GPU shaders instead of 550k+ CPU pixel writes.
- **Impact:** Removes frame hitches during boss spawns, Sasquatch waves, and first run initialization.

#### 3. Eliminate Per-Frame Allocations & Redraws in `Interceptor.gd` and `TopWeatherBorder.gd`
- **Problem:** `Interceptor._update_boost_trail()` allocates `Gradient.new()` and `PackedColorArray` every physics frame while boosting (and leaves the gradient empty). `TopWeatherBorder._process()` unconditionally invokes `queue_redraw()` every frame, re-triangulating starfields, mountain polygons, clouds, and horizon grids at full display refresh rate.
- **Improvement:** Pre-allocate a single `Gradient` resource on `Interceptor._ready()` and only update `Line2D.points` when a new trail point is pushed. Throttle `TopWeatherBorder` redraws (e.g., 20–30 Hz for ambient drift, immediate redraw on weather change or lightning flash) and cache static mountain `PackedVector2Array` geometry across frames.
- **Impact:** Reduces GC/RID churn and 2D canvas draw overhead on low-power and WebGL/WebGPU targets.

#### 4. True GPU Batching for `Highway.gd` Tiles, Ice Highlights, and Bridge Trusses
- **Problem:** `Highway._build_tiles_into()` builds per-tile color dictionaries (including 15% reflective white ice highlights), but `MultiMeshInstance2D` does not enable `multimesh.use_colors = true` and instead tints the entire mesh with `lane_polygons[0]["color"]`, losing visual variety. Bridge chunks also spawn dozens of individual `Line2D` and `Polygon2D` child nodes per chunk buffer instead of batching geometry.
- **Improvement:** Enable `multimesh.use_colors = true` with `set_instance_color()` for per-tile ice/asphalt variation, and bake bridge trusses, deck joints, and cables into a single cached `ArrayMesh` per chunk type.
- **Impact:** Cuts node count per Bridge chunk by ~80% and restores per-tile ice reflections with zero extra draw calls.

---

### Security Improvements

#### 5. Encrypt Save Data & Replace Bypassable 32-bit Hash Checksum (`scripts/autoload/GameManager.gd`)
- **Problem:** `user://save.dat` is stored unencrypted via `FileAccess.open()` and validated only with Godot's 32-bit `hash(var_to_str(payload))`. Worse, `load_progress()` (`if payload is Dictionary and stored_checksum != 0:`) skips checksum verification entirely if `_checksum` is omitted or set to `0`, making save tampering trivial.
- **Improvement:** Persist save files using `FileAccess.open_encrypted_with_pass()` (or HMAC-SHA256 via `Crypto` / `HashingContext` with a versioned schema), enforce strict non-bypassable integrity validation, and preserve atomic write-then-rename (`save.dat.tmp` -> `save.dat`) to prevent save corruption on crash.
- **Impact:** Closes trivial save tampering/checksum bypasses and protects player progression against partial writes.

#### 6. Harden `PackManager.gd` Against Path Traversal & Arbitrary `ResourceLoader.load()` (`scripts/autoload/PackManager.gd`)
- **Problem:** `PackManager._validate_content_section()` and `_apply_*_pack()` join untrusted relative paths from `pack.json` directly with `base.path_join(...)` without canonicalizing or checking for `..`, absolute paths, or `res://`/`user://` URI prefixes. Additionally, `_apply_music_pack()` and `_apply_skin_pack()` pass user-pack paths to `ResourceLoader.load()`, which can deserialize and instantiate arbitrary Godot `.tres`/`.tscn` scripts.
- **Improvement:** Enforce strict path containment (`simplify_path()`, reject `..`, leading `/`, or scheme prefixes), enforce file-extension allowlists (`.png`/`.webp`/`.jpg` for skins/themes; `.ogg`/`.mp3`/`.wav` for music), load textures via `Image.load_from_file()` + `ImageTexture.create_from_image()`, load audio via safe stream loaders (`AudioStreamOggVorbis.load_from_file()`), and validate hex colors against `^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$`.
- **Impact:** Prevents arbitrary resource/script execution and directory traversal from third-party content packs.

#### 7. Pin Supply-Chain Scripts & Validate Persisted Config Bounds (`scripts/autoload/SettingsManager.gd`, `scripts/scenes/ui/InputRemap.gd`, CI)
- **Problem:** Web deployments historically fetched `coi-serviceworker.js` from unpinned `master` without integrity pinning. Locally, `SettingsManager.set_volume()` accepts arbitrary unbounded floats into `user://settings.cfg` and `linear_to_db()`, and `InputRemap._deserialize_event()` trusts raw integers from `user://input_bindings.cfg` without validating keycode/button/axis bounds.
- **Improvement:** Pin `coi-serviceworker.js` to an immutable commit SHA (and verify SHA-256 in CI/Makefile), clamp `SettingsManager` linear volume to `[0.0, 1.0]`, and validate deserialized `InputEvent` ranges and action allowlists in `InputRemap.gd`.
- **Impact:** Protects Web builds from upstream supply-chain tampering and prevents malformed config files from corrupting audio or input state.

---

### Code Quality & Accuracy Improvements

#### 8. Fix Broken Assets, Version Mismatch, and Export Preset Drift (`assets/tilesets/highway_tileset.tres`, `export_presets.cfg`, `project.godot`, `scenes/Main.tscn`)
- **Problem:** `assets/tilesets/highway_tileset.tres` throws a parse error on project import (`Missing 'type' field in 'gd_resource' tag`) and references a missing `res://assets/tilesets/highway_tiles.png`. `project.godot` embeds stale `[export]` dictionaries that diverge from `export_presets.cfg` (e.g., `"Linux/X11"` + `"Windows Desktop"` vs `"Linux"`), and `Main.tscn` hardcodes `"v0.1.0 - Prototype"` while `project.godot` reports `0.0.1`.
- **Improvement:** Fix or remove the unused broken `highway_tileset.tres`, synchronize `project.godot` (`config/version`) and `export_presets.cfg` (add `"Windows Desktop"` preset cleanly if needed, remove stale `[export]` block from `project.godot`), and read `ProjectSettings.get_setting("application/config/version")` dynamically in `Main.gd`.
- **Impact:** Achieves zero startup/import errors and consistent release versioning across all platforms.

#### 9. Resolve Gameplay Logic & Math Bugs Across Entities and Weapons
- **Problem:** Audit uncovered multiple silent logic defects:
  - `Interceptor._update_boost_trail()` (`Interceptor.gd:324-330`) builds a `colors` array without assigning it to `gradient` and sets `default_color` alpha to `0.0`, rendering boost trails invisible.
  - `Interceptor.on_bridge_fall()` (`Interceptor.gd:381-388`) snaps `position.x >= 0` to `LANE_POSITIONS[2]` (`-180`, still on the left half) instead of a right-half lane (`LANE_POSITIONS[5]` or `[6]`).
  - `Scav.gd:27` checks `lane > 1` (legacy 4-lane assumption) instead of `lane >= Constants.LANE_COUNT / 2` for 8-lane flanking.
  - `BossWarRig.gd:90` calls `get_process_delta_time()` inside `_physics_process()`, and `_fire_bullet_spread()` (`BossWarRig.gd:95`) aborts if `_spawner` lacks `spawn_minion_requested` even though it spawns bullets directly.
  - `PoopWeapon.gd:70` matches `body.name == "Player"` instead of `body.is_in_group("player")`, and `Game._on_boss_defeated()` (`Game.gd:457-470`) pauses the tree without unpausing if `boss_type` has no matching demo scene.
  - `HUD.gd:72` resets `_multiplier_pulse_timer = 0.0` on every `multiplier_timer_updated` emission, freezing the low-timer warning pulse.
- **Improvement:** Fix each of these conditions, remove unused `@export` / `var` dead fields (`Bullet.gd` unused exports, `Highway.gd` unused `HALF_CHUNK`, `SHOULDER_COLUMNS`, `chunk_weights`, `BossWarRig._phase_2_done`), and add regression unit tests for each fix.
- **Impact:** Restores intended combat, flanking, UI feedback, and hazard recovery behavior.

#### 10. Eliminate ObjectDB / Orphan Node Leaks & Fix `ObjectPool` Fallback Handling (`scripts/autoload/ObjectPool.gd`, `scripts/autoload/GameManager.gd`, `tests/`)
- **Problem:** Running the GUT suite surfaces **1,396 orphan nodes** and **1,894 leaked ObjectDB instances** at exit. In runtime code, `ObjectPool.acquire()` fallback nodes do not set `_pool_name`, causing `release()` to `queue_free()` them instead of returning them to the pool; `GameManager.enemy_list` is not cleared on `start_game()` and accepts `null` entries; `Game._popup_pool` grows unbounded; and `ChainSwing.on_pool_release()` does not stop active tweens.
- **Improvement:** Ensure `ObjectPool` fallback nodes are tagged/tracked or capped cleanly, clear `GameManager.enemy_list` in `start_game()` with `is_instance_valid()` filtering in `register_enemy_spawned()`, cap `Game._popup_pool` to `POPUP_POOL_SIZE`, kill active tweens in `ChainSwing.on_pool_release()`, and clean up test-created nodes with `add_child_autofree()` / `free()` in GUT tests.
- **Impact:** Prevents long-session memory growth and brings test orphan/leak counts to zero.

#### 11. Unify Test Execution & Add Automated GDScript Static Checks (`scripts/run_tests.sh`, CI)
- **Problem:** `scripts/run_tests.sh` hardcodes 38 unit test files, omitting 6 unit test files (`test_bunny.gd`, `test_chain_swing.gd`, `test_interceptor_info.gd`, `test_poop_weapon.gd`, `test_top_weather_border.gd`, `test_weapon_data.gd`) and both integration test suites (`tests/integration/`). Meanwhile, there is no automated `gdlint` / `gdformat` enforcement or test gate before publishing builds.
- **Improvement:** Route all test invocations through directory discovery (`make test` / updated `scripts/run_tests.sh` scanning `tests/unit` and `tests/integration`), adopt `gdtoolkit` (`gdlint` / `gdformat`) with a project `.gdlintrc`, and gate the build-and-publish CI pipeline on passing tests and lint checks.
- **Impact:** Ensures 100% of unit and integration tests run locally and in CI on every change.

---

### User Functionality Improvements

#### 12. Wire Up Customization Packs & Add Garage Pack Previews (`scripts/autoload/PackManager.gd`, `scripts/scenes/ui/Garage.gd`)
- **Problem:** Enabling a music, skin, or theme pack in `Garage.gd` updates `PackManager.active_packs` and emits `skin_loaded`, `theme_color_loaded`, and `theme_texture_loaded`, but `Interceptor`, `Enemy`, `Highway`, and `AudioManager` never subscribe to those signals or implement `set_playlist()` / `revert_to_default_music()`. Players also have no visual preview before enabling a pack.
- **Improvement:** Connect `PackManager` signals to `Interceptor`, `Enemy`, `Highway`, and implement `AudioManager.set_playlist()` / `revert_to_default_music()`, persist active pack selections in `SettingsManager`, and add a preview panel in the Garage Customize tab showing the skin sprite, highway color swatches, and track count.
- **Impact:** Delivers full end-to-end custom skins, themes, and soundtracks as designed.

#### 13. Startup Input Binding Persistence, Full Slot Clearing & Control Hints (`scripts/scenes/ui/InputRemap.gd`, `scripts/autoload/GameManager.gd`)
- **Problem:** `InputRemap.load_bindings()` is only invoked when opening the Options menu, so custom keybindings saved to `user://input_bindings.cfg` do not take effect when launching straight into a run. Additionally, the `"X"` clear button in `InputRemap.gd:59-60` always clears index `0` regardless of binding slots, and there is no "Reset to Defaults" action.
- **Improvement:** Load saved input bindings at startup in `SettingsManager._ready()` (after `GameManager._add_input_mappings()`), add per-slot clear buttons and a "Reset to Defaults" button in `InputRemap.gd`, and reflect active keybindings dynamically in `HUD` / `InterceptorInfo`.
- **Impact:** Makes custom keyboard and gamepad remapping reliable across sessions.

#### 14. Boss HUD Health Bar, Telegraphing & Off-Screen Threat Indicators (`scripts/scenes/ui/HUD.gd`, `scripts/scenes/world/Spawner.gd`)
- **Problem:** When a boss spawns, `HUD` displays no boss name, health bar, or phase indicator, and fast-moving Scavs/DroneBombs/Babies give limited off-screen warning on narrower aspect ratios.
- **Improvement:** Add a dedicated Boss HP bar + phase badge on `HUD` wired to `Spawner.boss_spawned` and boss `hp`/`boss_phase_changed` signals, plus edge-of-screen directional markers for incoming hazards and pickups.
- **Impact:** Improves combat readability and boss-fight tension.

#### 15. Touch/Mobile Controls, Run Stats Summary, Local Leaderboard & Daily Seeded Runs
- **Problem:** `export_presets.cfg` defines Web, Android, and iOS targets, yet gameplay relies exclusively on keyboard/gamepad input (`WASD`/arrows/Space/Shift/Tab/Q). Additionally, `Highway.gd:53` hardcodes `hash("highway_seed")`, and `docs/design.md` features (detailed run breakdown, local leaderboard, achievement badges, daily seeded runs) are not yet implemented.
- **Improvement:** Add an optional/auto-detected touch control overlay (lane left/right, accelerate/brake, fire/secondary/boost) for mobile and mobile-web browsers; track per-run kill/protection stats for `GameOver`; persist a local top-10 leaderboard + achievement milestones; and add a Daily Run mode seeded from the UTC date (`Time.get_date_dict_from_system(true)`).
- **Impact:** Unlocks mobile/touch playability and substantially increases replayability.
