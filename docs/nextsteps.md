# Race to Dead End — Implementation Plan

## Engine: Godot 4.4+

**Why Godot?** MIT-licensed open source, excellent 2D isometric support via TileMapLayers, built-in physics (or Jolt integration), GDScript for fast prototyping, strong community, cross-platform export (Windows, Linux, macOS, web, mobile). No royalties or licensing fees.

---

## Phase 0: Prototype Stabilization & LSP Resolutions (COMPLETED)

We conducted a deep static analysis of the prototype codebase and resolved several critical LSP errors, compiler failures, and gameplay bugs that blocked building and execution.

---

## Part 11: Engine Setup & Project Scaffolding

* Install Godot 4.4+ from godotengine.org
* Create project with renderer: Forward+ (2D isometric doesn't need Mobile)
* Enable Jolt physics in Project Settings → Physics → 3D (or stick with GodotPhysics for 2D)
* Set up input map actions: `move_left`, `move_right`, `accelerate`, `brake`, `primary_fire`, `secondary_fire`, `boost`, `cycle_weapon`
* Configure display: window 1280×720, stretch mode `viewport`, aspect `keep`
* Seed directory structure: `scenes/`, `scripts/`, `assets/sprites/`, `assets/audio/`, `assets/tilesets/`, `addons/`
* Create `autoload/` singletons: `GameManager`, `ScoreManager`, `AudioManager`

## Part 12: Project Structure & Architecture (Godot Scenes)

```text
res://
├── autoload/
│   ├── GameManager.gd          # Game state, difficulty curve, wave spawning
│   ├── ScoreManager.gd         # Score tracking, multipliers, credits
│   └── AudioManager.gd         # SFX/music bus routing, one-shot players
├── scenes/
│   ├── Main.tscn               # Main menu (start, garage, quit)
│   ├── Game.tscn               # Root game scene (holds world + UI)
│   ├── world/
│   │   ├── Highway.tscn        # TileMap-based road generator
│   │   └── Spawner.tscn        # Enemy wave spawner node
│   ├── player/
│   │   └── Interceptor.tscn    # Player car scene
│   ├── enemies/
│   │   ├── Rotor.tscn          # Zombie biker
│   │   ├── Scav.tscn           # Gang pickup truck
│   │   └── Drone.tscn          # Alien saucer
│   ├── weapons/
│   │   ├── Bullet.tscn         # Machine gun projectile
│   │   ├── Missile.tscn        # Homing missile
│   │   ├── Mine.tscn           # Dropped mine
│   │   └── EMPBlast.tscn       # Area stun effect
│   └── ui/
│       ├── HUD.tscn            # Score, health, weapons, boost
│       ├── GameOver.tscn       # Score summary + restart
│       └── Garage.tscn         # Meta-upgrade shop
├── scripts/                    # Shared .gd scripts
├── assets/
│   ├── sprites/                # PNG sprites (isometric)
│   ├── tilesets/               # Isometric road tiles
│   └── audio/                  # SFX + music
└── addons/                     # Plugins (GEVP vehicle physics)
```

## Part 13: Isometric Rendering System

Use Godot's TileMapLayer with isometric tile mode. Create tileset with 64×32 diamond tiles, Y-sort on vehicles, z_index layering, infinite scroll via tile offset or node repositioning. Parallax background layers (3 layers: near, mid, far).

## Part 14: Player Controller & Vehicle Physics

CharacterBody2D with arcade-style movement: constant forward push, lane-snapping lateral movement, weave dodge (2-lane shift, 0.5s cooldown), boost (2x speed, 1.5s, recharge).

## Part 15: Enemy AI System

Enemy base class with 3 subtypes: Rotor (swarm/close), Scav (flank/shoot), Drone (hover/bomb). Spawner manages difficulty tiers, wave composition, boss waves every 3000 pts.

## Part 16: Combat & Weapon Systems

ObjectPool for bullets/mines/EMP. Machine gun (0.1s cooldown), homing missile (bullet with homing_strength overlay), proximity mine, EMP stun. Weapon cycling via `cycle_weapon`.

## Part 17: Terrain & Road Generation

Highway chunks (10 tiles × 5 tiles) in PrewarmBuffer (3 ahead, 1 behind). 5 chunk types: Standard (40%), Debris (20%), Ice (10%), Construction (15%), Bridge (15%). Implemented via MultiMeshInstance2D.

## Part 18: UI, HUD & Menus

HUD: Score, multiplier, health bar, weapon display, boost indicators. Menus: Main, Garage (upgrades), Options (audio/video/input), Game Over. Pause overlay with Resume/Options/Quit.

## Part 19: Audio Integration

Synthwave/dark electronic music, procedural SFX via AudioManager. AudioStreamPlayer2D for positional audio. Reverb on SFX bus, compressor on Master bus. 16-player pool with priority system.

## Part 20: Build Pipeline, Testing & Deployment

Unit tests with GUT (560+ tests across 30 files). Performance profiling target 60 FPS. Export targets: Linux, Windows, Web, Android.

---

## Phase 1: Deep Code Review & 10-Part Improvement Plan (COMPLETED — Part 22 deferred)

All 10 parts implemented except Part 22 (deferred):

### Part 22: TileMapLayer Highway (DEFERRED)

**Problem:** Highway generates individual Polygon2D, StaticBody2D, Line2D, Area2D nodes per tile.

**Current approach:** MultiMeshInstance2D for batching lanes/shoulders/stripes — reduced draw calls but not TileMapLayer.

**Status:** DEFERRED — the MultiMeshInstance2D approach achieves the performance goal via a different technique. A TileMapLayer rewrite would be a pure architectural change with no additional performance benefit.

---

## Phase 2: Deep Codebase Optimization (Completed May 2026)

A thorough codebase-wide audit of 28 game scripts, 17 scenes, 6 autoloads — 15 issues resolved.

---

## Phase 3: Post-Optimization Growth Plan (10 Improvements)

Parts 32, 33, 34, 36, 37, 38, 39, 41 are **IMPLEMENTED**. Remaining:

### Part 35: Enemy Inheritance via `class_name` (DEFERRED)

**Problem:** Subtypes use `extends "res://..."` string path instead of `class_name EnemyBase`.

**Attempted:** Added `class_name EnemyBase`, changed subtypes to `extends EnemyBase`.

**Result:** Godot 4 headless mode fails to resolve `class_name` in compile-order when subtypes are `load()`-ed in GUT test context. Reverted to string-path extends.

**Status:** DEFERRED — revisit after Godot 4 resolves class_name compile-order issues.

### Part 40: Integration, Stress, and Performance Tests

**Problem:** All 560+ tests are unit tests with mocked dependencies. No integration tests, stress tests, or performance benchmarks exist.

**Plan:**
1. Create 3-5 integration test files (combat loop, highway + player, weather + player)
2. Create stress test file (30 enemies + 100 bullets, pool exhaustion)
3. Create performance benchmark file (chunk generation, pool acquire/release)
4. Convert `run_tests.gd` to glob-based discovery
5. Fix `test_helper.gd` mock (replace `set()` with actual MockPlayer.gd)

---

## Phase 4: Deep Codebase Audit — 10 Improvement Opportunities (COMPLETED)

All 10 parts (42-51) implemented and tested:
- Signal-based enemy list, parallax backgrounds, civilian vehicles, boss encounters
- Floating combat text, screen transitions, gamepad rumble, shared sprite scaling
- Multiplier timer HUD, constants consolidation

---

## Phase 5: Deep Performance & Feature Audit (COMPLETED)

All 10 improvement suggestions implemented. S61-S70 completed across multiple codebase optimization passes. Detailed per-suggestion implementation notes below.

### S61 — AudioManager Lazy Stream Generation
**Fix:** Replaced eager `_generate_cached_streams()` call in `_ready()` with per-method lazy init. Only menu music is eagerly generated. All 14 SFX streams use `if not _stream_x: _stream_x = _generate_x_stream()` on first `play_*()` call. Music streams (`play_menu_music()`, `play_game_music()`) also use lazy init patterns.
**Tests:** `test_audio_manager.gd` — explicit assertions that `_stream_*` is null before first play and non-null after, covering laser, explosion, hurt, boost, emp, lightning, and all enemy hit/death streams.

### S62 — Highway Chunk Dual-Buffer Recycling
**Fix:** Replaced `_chunk_template_cache` + `_chunk_recycle_pool` with `_chunk_dual_buffers` (2 Node2D per ChunkType) and `_buffer_in_use` tracking. `_reserve_tiles()` returns a free buffer; `_mark_buffer_free()` marks it available on recycle. Removed buggy `_detect_chunk_type()` (DEBRIS/CONSTRUCTION always classified as STANDARD). Eliminated `duplicate()` in the common case.
**Tests:** `test_reserve_tiles_returns_two_buffers` verifies separate instances with matching child counts.

### S63 — Bullet Homing Distance Bounding
**Fix:** Added `MAX_HOMING_RANGE = 400.0` and `EARLY_OUT_DIST_SQ = 4000.0` constants to `Bullet.gd`. `_find_nearest()` skips distance calc if all enemies are beyond range, and returns early when a very close enemy is found.
**Tests:** `test_find_nearest_early_out_close_enemy`, `test_find_nearest_returns_null_when_all_out_of_range`, `test_max_homing_range_constant`, `test_early_out_dist_sq_constant`.

### S64 — WeatherSystem Acid Overlay Transition Bugfix
**Fix:** `_update_weather_transition()` now calls `_update_visuals_for_weather(target_weather)` when `weather_transition >= 1.0`. Added `_prev_overlay_color` and `_target_overlay_color` with `lerp()` interpolation during transition in `_process()`. `set_weather()` saves current overlay color before starting transition.
**Tests:** `test_overlay_transition_sets_prev_color`, `test_overlay_color_lerps_during_transition`, `test_overlay_color_completes_on_transition_end`.

### S65 — Difficulty Speed Scaling
**Fix:** Added `SPEED_PER_TIER = 15.0` and `MAX_GAME_SPEED` to `Constants.gd`. `GameManager` tracks `current_speed`, emits `speed_changed` signal on tier advance. `Interceptor` reads `GameManager.current_speed` and listens to `speed_changed`.
**Tests:** `test_current_speed_starts_at_base`, `test_current_speed_increases_with_tier`, `test_current_speed_formula_respects_max`, `test_speed_changed_emitted_on_difficulty_advance`, `test_speed_changed_contains_correct_value`.

### S66 — Save/Load Data Integrity with Checksum
**Fix:** `save_progress()` computes `_checksum = hash(var_to_str(payload))`. `load_progress()` verifies checksum before applying save data; mismatch → skip load and use defaults. Backward-compatible with saves missing `_checksum` key.
**Tests:** `test_load_rejects_checksum_mismatch`, `test_load_validation_ignores_invalid_types`, `test_load_validation_accepts_valid_data`, `test_save_and_load_roundtrip`.

### S67 — GameOver Restart Visual Delay
**Fix:** Added `_game_over_restart_timer: float` to `Game.gd`. `_process()` requires 1.5s cooldown before accepting `ui_accept` restart input.
**Tests:** `test_game_over_restart_delay_cooldown` (timer below 1.5s, no trigger), `test_game_over_restart_delay_allows_after_cooldown` (at 1.5s+, restart fires).

### S68 — ObjectPool Pickup Signal Cleanup
**Fix:** `ObjectPool.release()` disconnects `body_entered` from `_on_pickup_body_entered` if connected, preventing stale signal buildup across pool cycles.
**Tests:** `test_pickup_signal_disconnected_on_release` — acquire pickup (signal connected), release (signal disconnected).

### S69 — BossWarRig Multi-Phase Behavior
**Fix:** Three-phase behavior: Phase 1 (100%-61% HP, ram only), Phase 2 (60%-31% HP, ram + bullet spread), Phase 3 (30%-0% HP, ram + minions + increased speed). Speed: +20% Phase 2, +40% Phase 3. `_check_phase()` drives transitions, `_update_phase_visuals()` sets sprite tint (yellow/red). `boss_phase_changed` signal emitted.
**Tests:** `test_boss_phase_2_at_60_percent_hp`, `test_boss_phase_3_at_30_percent_hp`, `test_boss_speed_increases_in_phase_2`, `test_boss_speed_increases_in_phase_3`, `test_boss_has_bullet_spread_method`, `test_fire_bullet_spread_creates_three_bullets`, `test_boss_phase_changed_signal_emits_correct_phase`, `test_execute_attack_calls_ram_player_in_phase_1`, `test_execute_attack_phase_2_handles_spread`, `test_execute_attack_phase_3_spawns_minions`.

### S70 — Spawner Enemy List Consolidation
**Fix:** Removed `active_enemies` from Spawner. Cleanup loop in `_process()` iterates `GameManager.enemy_list` exclusively. Civilians registered with `GameManager.register_enemy_spawned()` for automatic cleanup.
**Tests:** `test_garbage_collection_removes_far_enemies`, `test_garbage_collection_keeps_near_enemies`, `test_garbage_collection_removes_invalid_enemies`, `test_cleanup_disconnects_destroyed_signal`, `test_spawner_uses_game_manager_enemy_list_only`.

---

## Phase 6: Deep Codebase Bugfix & Performance Audit (New)

10 additional improvement suggestions identified via systematic codebase analysis of all game scripts. Focus: bugs found during deep review, performance hot paths, and edge-case resource leaks.

### Suggestion 71: InputRemap Destructive Rebind

**Problem:** `InputRemap._apply_binding()` calls `InputMap.action_erase_events(action)` which removes ALL input events for an action — including gamepad bindings added by `GameManager._add_input_mappings()`. Rebinding any single key destroys all controller bindings for that action. The Clear button has the same issue.

**Current code:** `_apply_binding()` erases the entire action then adds only the rebound key. `_on_clear_pressed()` also erases the entire action. The `_listening_idx` variable tracks which slot (0 or 1) is being rebound but is never used to target the replacement.

**Plan:**
1. In `_apply_binding()`, get the current event list with `InputMap.action_get_events(action)`.
2. If `_listening_idx < events.size()`, replace `events[_listening_idx]` with the new event.
3. If `_listening_idx >= events.size()`, append the new event.
4. Erase the action, re-add all (preserved) events including the new one.
5. In `_on_clear_pressed()`, add an `idx` parameter and remove only that slot's event, not all events.
6. Test: rebind `move_left` to a key, verify gamepad DPAD_LEFT still works. Clear a single binding, verify others remain.

**Effort:** Low — **Impact:** High — **Priority:** P1

---

### Suggestion 72: DroneBomb Pool State Reset

**Problem:** DroneBomb has no `on_pool_acquire()` or `init()` method. When a DroneBomb is released to the ObjectPool and re-acquired:
- `age` retains its previous value (~2.1s after detonation), causing immediate re-detonation.
- `exploded` is still `true`, so the `_process` branch goes straight to the explosion-fade code, skipping the warning blink phase.
- `explosion_visual` Polygon2D from the previous detonation is still a child node, creating visual garbage.

**Current code:** `_ready()` runs once when the pool is created. `process_mode` is set to `DISABLED` on pool release, pausing `_process`. On re-acquire, `process_mode` is restored, but `age`, `exploded`, and visuals are stale.

**Plan:**
1. Add `on_pool_acquire()` to DroneBomb that resets `age = 0.0`, `exploded = false`, `hit_by_bullet = false`.
2. In `on_pool_acquire()`, remove any leftover `explosion_visual` Polygon2D child (use `queue_free()`).
3. Add `warning_visual.visible = true` so the warning circle shows immediately on reuse.
4. Test: spawn two DroneBombs sequentially from pool, verify second bomb has full 1.5s detonation delay and no visual artifacts.
5. Test: acquire → detonate → release → acquire → verify age is 0 and bomb does not instantly detonate.

**Effort:** Low — **Impact:** High — **Priority:** P1

---

### Suggestion 73: AudioManager SFX Priority System Broken

**Problem:** `AudioManager.play_sfx()` accepts a `priority: int` parameter intended to allow high-priority sounds (explosions, alerts) to preempt lower-priority ones. However, the loop uses the player array `index` (`i`) as the comparison value instead of the `priority` argument. This means `sfx_players[0]` always has the highest "priority", regardless of which sound is playing in it. The `priority` parameter is silently ignored.

**Current code:**
```gdscript
for i in sfx_players.size():
    var p = sfx_players[i]
    if not p.playing:
        best_idx = i
        break
    if i < best_priority:   # BUG: should compare priority of playing sound, not index
        best_priority = i
        best_idx = i
```

**Plan:**
1. Store the priority of each currently-playing sound in a parallel array `_player_priorities: Array[int]`, defaulting to 0.
2. At `play_sfx()` call time, set `_player_priorities[best_idx] = priority`.
3. When a player finishes playing (detect via `finished` signal), reset its priority to 0.
4. In the find-best loop, when a player is busy, compare `_player_priorities[i]` against the incoming `priority` — if the incoming priority is higher, preempt.
5. Connect `finished` signal on each SFX player in `_ready()` to a cleanup handler.
6. Test: play 17 sounds (exhausting the 16-player pool) with varying priorities, verify highest-priority sounds preempt lowest.

**Effort:** Medium — **Impact:** High — **Priority:** P1

---

### Suggestion 74: Game Pause Options Loads Script Instead of Scene

**Problem:** `Game._show_pause_options()` instantiates `Options.gd` directly:
```gdscript
_options_menu = preload("res://scripts/scenes/ui/Options.gd").new()
```
This creates a bare `CanvasLayer` with no child nodes. The `@onready` variables in `Options.gd` reference `$Panel`, `$Panel/TabContainer`, etc., which only exist in `Options.tscn`. These will all be null, causing either silent failures or crashes when the pause options menu is opened.

**Current code:** Main menu correctly uses `preload("res://scenes/ui/Options.tscn").instantiate()`, but the pause menu does not.

**Plan:**
1. Change the load in `_show_pause_options()` from `preload("res://scripts/scenes/ui/Options.gd").new()` to `preload("res://scenes/ui/Options.tscn").instantiate()`.
2. Verify: press pause during gameplay, click Options, confirm the full options UI appears with sliders, checkboxes, and input remapping.
3. Test: verify `back_to_menu_requested` signal from Options scene properly returns to pause menu.

**Effort:** Low — **Impact:** High — **Priority:** P1

---

### Suggestion 75: Mine Explosion Redundant Group Scan

**Problem:** `Mine._explode()` falls back to `get_tree().get_nodes_in_group("enemy")` when direct `get_overlapping_bodies()` / `get_overlapping_areas()` returns no hits. This:
- Creates a new `Array` allocation via the scene tree scan.
- Iterates ALL enemies in the scene (including off-screen ones).
- Performs manual distance checks that the physics engine already handles.
- Happens every mine explosion (~15 per 60s game at tier 10+).

**Current code:**
```gdscript
if not hit:
    var enemies = get_tree().get_nodes_in_group("enemy")
    for enemy in enemies:
        if not is_instance_valid(enemy): continue
        var dist = global_position.distance_to(enemy.global_position)
        if dist <= explosion_radius and enemy.has_method("take_damage"):
            enemy.take_damage(damage)
```

**Plan:**
1. Replace the group scan fallback with a direct iteration of `GameManager.enemy_list` (already available, no allocation needed).
2. Add an early distance-sq check to avoid `distance_to()` sqrt: `if global_position.distance_squared_to(enemy.global_position) <= explosion_radius * explosion_radius`.
3. Remove the `is_instance_valid` check — `GameManager.enemy_list` entries are cleaned up every frame.
4. Test: detonate mine near 3 enemies, verify all 3 take damage. Test: mine explosion with no nearby enemies, verify no crash.
5. Benchmark: measure mine explosion before/after to confirm no group scan allocation.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 76: SettingsManager Unthrottled ConfigFile Save

**Problem:** `SettingsManager.set_volume()` calls `save_settings()` immediately on every call. During slider drag, `value_changed` fires continuously (dozens of events per second), causing rapid ConfigFile writes. This can cause:
- Disk wear (small writes)
- Frame hitches from synchronous I/O
- Race conditions if the file is written while another process reads it

**Current code:** `_on_master_changed(value)` → `SettingsManager.set_volume("Master", value)` → `save_settings()` → `_config.save(SETTINGS_PATH)` — synchronous disk write on every slider movement.

**Plan:**
1. Add a `_save_debounce_timer: float` to `SettingsManager`, defaulting to 0.
2. In `set_volume()`, instead of calling `save_settings()` immediately, set the timer to 0.5 seconds.
3. In `_process(delta)`, decrement the timer; when it hits 0, call `save_settings()` and set the timer to -1 (no pending save).
4. Call `save_settings()` immediately in `set_fullscreen()` (user expects instant response for toggle).
5. Test: drag Master volume slider rapidly for 3 seconds, verify only 1-2 ConfigFile writes occur.
6. Test: verify settings are still persisted correctly after debounced save fires.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 77: HUD Multiplier Timer Bar Per-Frame sin() Compute

**Problem:** `HUD._on_multiplier_timer_updated()` calls `sin(Time.get_ticks_msec() * 0.01)` every frame the multiplier timer bar is visible. The `Time.get_ticks_msec()` returns milliseconds since engine start (~106 days worth). Multiplying by 0.01 and calling `sin()` generates a per-frame allocation (the float result) and causes the bar color to pulse. This computation is trivial but runs every render frame (~3600 calls per minute of active multiplier time).

**Current code:**
```gdscript
if time_left < 3.0:
    var pulse = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
    multiplier_timer_bar.modulate = Color(1.0, pulse, 0.0)
```

**Plan:**
1. Replace the absolute-time `sin()` with a relative-time approach using `_multiplier_pulse_timer: float` that increments by `delta` in the HUD's `_process`.
2. Use `sin(_multiplier_pulse_timer * 5.0)` for a consistent 5 rad/s pulse speed regardless of engine uptime.
3. Reset `_multiplier_pulse_timer` to 0 when the timer bar becomes visible.
4. Remove the `Time.get_ticks_msec()` call entirely.
5. Test: verify the pulse visual is indistinguishable from the original.
6. Verify: no `Time` singleton calls remain in `_process` hot path.

**Effort:** Low — **Impact:** Low — **Priority:** P3

---

### Suggestion 78: Parallax Background Per-Game Image Allocation

**Problem:** `Game._setup_parallax()` creates three procedural `Image` textures every time a new `Game.tscn` is loaded (each restart, each new run). Each image is 4×256 pixels with a per-pixel fill loop (1024 pixel writes per layer × 3 layers = 3072 writes). The resulting `ImageTexture` objects are discarded on scene unload. This is visible as a ~5-10ms hitch on game start.

**Current code:** `_setup_parallax()` unconditionally runs `Image.create()` + double-loop + `ImageTexture.create_from_image()` for each of 3 layers.

**Plan:**
1. Move the parallax texture creation to a static variable: `static var _parallax_textures: Array[Texture2D] = []`.
2. In `_setup_parallax()`, check `_parallax_textures.size() > 0` — if cached, assign textures directly without regenerating.
3. Generate textures only on first call (when `_parallax_textures` is empty).
4. Keep the per-layer color customization (the gradient colors are layer-specific, not in the textures — they're in the `ColorRect` or sprite modulate). Actually, the colors ARE in the texture data, so cache by layer.
5. Since the colors are identical every game start (same `l` array in the closure), caching is safe.
6. Test: restart game 3 times, verify `Image.create()` runs only once. Confirm parallax rendering is identical to pre-cache behavior.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 79: Mine Arm Timer Lost on Pool Reuse

**Problem:** `Mine._ready()` contains `await get_tree().create_timer(arm_time).timeout` which runs exactly once when the mine is first instantiated. After the timer completes, `armed = true`. When the mine is released to pool and re-acquired, `_ready()` does NOT re-run, so `armed` remains `true` and the 0.5-second arm delay is lost. Player-placed mines are immediately armed on the second use.

**Current code:** `_ready()` → await timer (0.5s) → `armed = true`. `ObjectPool.release()` hides the node but doesn't reset `armed`. `ObjectPool.acquire()` does not call any reset method on Mine (no `on_pool_acquire()` exists).

**Plan:**
1. Add `on_pool_acquire()` to Mine that resets `armed = false` and starts a new arm timer.
2. Instead of a coroutine (which can't be created in `on_pool_acquire` since it's called from `acquire()`), use `create_tween()`: `create_tween().tween_interval(arm_time).tween_callback(func(): armed = true)`.
3. Kill any existing tween in `on_pool_acquire()` before starting the new one to avoid stale callbacks.
4. Store the tween in a `var _arm_tween: Tween` variable.
5. Test: drop mine → wait 0.2s → touch enemy → verify no explosion (not armed yet). Drop second mine (from pool) → wait 0.2s → verify still not armed.
6. Test: drop mine → wait 0.6s → touch enemy → verify explosion.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 80: Civilian Cleanup Edge Case

**Problem:** Civilians spawned by `Spawner._spawn_civilian()` are added as direct children of Spawner but are NOT added to `GameManager.enemy_list`. The main cleanup loop in `Spawner._process()` only acts on `GameManager.enemy_list`, so civilians are immune to distance-based cleanup. They rely entirely on two one-shot signals (`exited_safely` and `hit_by_player`) for cleanup. If both signals fail to fire (civilian stays in bounds without player interaction), the civilian node remains forever, accumulating orphan nodes over long play sessions.

**Current code:** `_spawn_civilian()` → `add_child(civilian)`. No registration in `GameManager.enemy_list`. `_on_civilian_safe_exit()` and `_on_civilian_hit()` handle cleanup individually via one-shot signal connections.

**Plan:**
1. Add civilians to `GameManager.enemy_list` in `_spawn_civilian()`: `GameManager.register_enemy_spawned(civilian)`.
2. In `_on_civilian_safe_exit()` and `_on_civilian_hit()`, call `GameManager.register_enemy_destroyed(civilian)` before `ObjectPool.release()`.
3. The existing `Spawner._process()` cleanup loop already handles position-based cleanup for `GameManager.enemy_list` — civilians will now be cleaned up when they scroll past `CLEANUP_DISTANCE` even if signals don't fire.
4. Add a `civilian` group or type check in the cleanup loop to ensure civilians are released to pool (not `queue_free()`).
5. Test: spawn civilian, let it scroll off screen without player interaction, verify it is cleaned up within 10 seconds.
6. Test: civilian hit by player, verify cleanup still works via signal path (no double-cleanup).

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

## Priority Matrix (Phase 6)

| Suggestion | Title | Effort | Impact | Priority |
|------------|-------|--------|--------|----------|
| 71 | InputRemap Destructive Rebind | Low | High | P1 |
| 72 | DroneBomb Pool State Reset | Low | High | P1 |
| 73 | AudioManager SFX Priority System Broken | Medium | High | P1 |
| 74 | Game Pause Options Script vs Scene | Low | High | P1 |
| 75 | Mine Explosion Redundant Group Scan | Low | Medium | P2 |
| 76 | SettingsManager Unthrottled Save | Low | Medium | P2 |
| 78 | Parallax Background Per-Game Allocation | Low | Medium | P2 |
| 79 | Mine Arm Timer Lost on Pool Reuse | Low | Medium | P2 |
| 80 | Civilian Cleanup Edge Case | Low | Medium | P2 |
| 77 | HUD Multiplier Timer Per-Frame sin() | Low | Low | P3 |

**Previously deferred (unchanged):** Part 22 (TileMapLayer Highway, P3), Part 35 (class_name EnemyBase, P3), Part 40 (Integration Tests, P1).

---

## Phase 7: Deep Codebase Audit — 10 Improvement Suggestions (COMPLETED)

10 additional improvement suggestions identified via systematic codebase analysis. Focus: signal leak prevention, pool lifecycle correctness, null safety, node path optimization, magic number centralization, and string formatting consistency.

### Suggestion 81: Spawner Cleanup Signal Disconnect

**Problem:** When `Spawner._process()` cleans up an enemy that has scrolled past `CLEANUP_DISTANCE`, it calls `ObjectPool.release(e)` but does not disconnect the `destroyed` signal that was connected during spawning. This leaves a stale signal connection pointing at `Spawner._on_enemy_destroyed`. When the enemy is re-acquired from the pool and re-enters play, `_spawn_enemy()` connects the signal again — creating a duplicate connection that fires twice on death.

**Current code:** Cleanup loop calls `ObjectPool.release(e)` without any signal management. `_spawn_enemy()` always calls `enemy.destroyed.connect(_on_enemy_destroyed)` unconditionally.

**Fix:** Before `ObjectPool.release()` in the cleanup loop, check `e.destroyed.is_connected(_on_enemy_destroyed)` and disconnect if true.

**Tests:** `test_cleanup_disconnects_destroyed_signal` — spawn enemy, verify signal connected, run cleanup, verify signal disconnected.

---

### Suggestion 82: ObjectPool Fallback Pool Name Leak

**Problem:** `ObjectPool.acquire()` has a fallback path that instantiates a new instance from the scene path when the pool is empty. The fallback path was setting `fallback.set_meta("_pool_name", pool_name)`, which causes the fallback instance to be returned to the pool on `release()`. This means:
- Fallback instances that should be `queue_free()`'d after a single use (like EMPBlast, which has no `on_pool_release()` cycle) are instead re-added to the pool.
- The pool grows without bound via fallback instances.
- The `_pool_name` metadata is the only discriminator between "poolable" and "non-poolable" instances.

**Current code:** `acquire()` fallback sets `_pool_name` meta, causing the fallback instance to be poolable.

**Fix:** Remove `fallback.set_meta("_pool_name", pool_name)` from the fallback path. Fallback instances will not have `_pool_name` set, so `ObjectPool.release()` will fall through to `queue_free()`.

**Tests:** `test_emp_fallback_does_not_set_pool_name` — instantiate EMP, verify no `_pool_name` meta exists.

---

### Suggestion 83: Spawner Cleanup Loop Unthrottled

**Problem:** `Spawner._process()` runs the full enemy cleanup loop (iterating `GameManager.enemy_list`) every frame. With 30+ enemies, this means 30+ `is_instance_valid` checks and potentially 30+ `global_position.y` comparisons every frame (60 times per second = 1800 checks/s). The cleanup only needs to run at most 4 times per second (the rate at which an enemy can scroll past `CLEANUP_DISTANCE` at max speed).

**Current code:** Cleanup runs unconditionally inside `_process()` with no rate limiting.

**Fix:** Add `_cleanup_timer: float` that decrements by `delta` each frame, defaulting to 0. When `_cleanup_timer > 0.0`, skip cleanup. Reset to 0.25s after running.

**Tests:** `test_cleanup_timer_throttles_iteration` — set timer to 0.25, add enemy, run 0.1s delta (should skip), run 0.2s more (should process).

---

### Suggestion 84: WeatherSystem Lightning Tween Null Safety

**Problem:** In `WeatherSystem._spawn_lightning_strike()` and `_create_lightning_bolt()`, tween callbacks call `flash.queue_free` and `bolt.queue_free` directly. If the lightning flash or bolt node is freed before the tween completes (e.g., scene transition, weather reset), the callback throws an error: `"Attempt to call method 'queue_free' on a null instance."`. This occurs silently but generates error spam in debug builds.

**Current code:** `tween.tween_callback(flash.queue_free)` — passes the method directly, no null guard.

**Fix:** Wrap in lambda: `tween.tween_callback(func(): if is_instance_valid(flash): flash.queue_free)`.

**Tests:** `test_lightning_tween_callback_valid_instance` — create flash, tween, wait for completion, verify no crash.

---

### Suggestion 85: Enemy Pool Release Signal Disconnect

**Problem:** `Enemy.on_pool_release()` resets all state (HP, speed, stun, etc.) but does not disconnect the `destroyed` signal from `_spawner._on_enemy_destroyed`. When the enemy is re-acquired from pool and re-initialized, `_spawn_enemy()` re-connects the signal, creating a duplicate connection. On death, `_on_enemy_destroyed` fires twice, awarding double score and double SFX.

**Current code:** `on_pool_release()` resets HP, speed, stun. No signal management.

**Fix:** In `on_pool_release()`, if `_spawner` is valid and `destroyed` is connected to `_spawner._on_enemy_destroyed`, disconnect it.

**Tests:** `test_on_pool_release_disconnects_destroyed_signal` — connect signal to mock spawner, release, verify disconnected.

---

### Suggestion 86: Scav WeaponMount Node Path Redundancy

**Problem:** `Scav._fire_bullet()` calls `$WeaponMount` every time it fires a bullet. With Scavs firing every ~2.5 seconds at tiers 6+, this is a node path resolution per shot. Node path resolution (`$WeaponMount`) is slower than accessing a cached reference because it walks the scene tree.

**Current code:** `$WeaponMount.global_position` in `_fire_bullet()` resolves the path every frame.

**Fix:** Add `@onready var _weapon_mount: Node2D = $WeaponMount` and reference `_weapon_mount.global_position` instead.

**Tests:** `test_scav_weapon_mount_onready_cached` — instantiate Scav, verify `_weapon_mount` is non-null and named "WeaponMount".

---

### Suggestion 87: Interceptor Lane-to-X Out-of-Bounds Crash

**Problem:** `Interceptor._lane_to_x()` accesses `Constants.LANE_POSITIONS[lane]` with no bounds check. If a negative lane index or an index ≥ `LANE_POSITIONS.size()` is passed (e.g., from a code path calling `_lane_to_x(-1)` or `_lane_to_x(10)`), this produces a subscript error: `"Index out of bounds."`. The lane index is always valid in normal gameplay (clamped by InputRemap), but future features or boss attacks that manipulate the player lane could trigger this.

**Current code:** `return Constants.LANE_POSITIONS[lane] if lane < LANE_POSITIONS.size() else 0.0` — only guards against one direction, returns 0.0 (center) for invalid values.

**Fix:** Use `clampi(lane, 0, LANE_POSITIONS.size() - 1)` to clamp to valid range before indexing.

**Tests:** `test_lane_to_x_clamps_negative` and `test_lane_to_x_clamps_above_max` — verify clamping returns valid lane positions.

---

### Suggestion 88: Constants Centralization

**Problem:** Multiple scripts use magic numbers that should be centralized in `Constants.gd`:
- `Interceptor.gd:91`: `0.01`, `0.05`, `0.1` for fire rate calculation (already uses `Constants.PRIMARY_FIRE_COOLDOWN` for the base)
- `Scav.gd:53-63`: `120.0`, `80.0`, `300.0`, `150.0` for ram distance and lateral speed thresholds
- `BossWarRig.gd:78`: `200.0`, `500.0` for ram force and speed
- Various other scattered magic numbers

**Current code:** Magic numbers embedded inline.

**Fix:** Added the following constants to `Constants.gd`:
- `FIRE_RATE_STEP`, `FIRE_RATE_MIN`, `FIRE_RATE_MAX` — fire rate upgrade scaling
- `SCAV_RAM_DIST_Y`, `SCAV_RAM_DIST_X` — scav ram detection thresholds
- `SCAV_LATERAL_RAM_SPEED`, `SCAV_LATERAL_NORMAL_SPEED` — scav lateral movement
- `BOSS_RAM_FORCE`, `BOSS_RAM_SPEED` — boss ram physics
- `CHUNK_WEIGHT_*`, `CHUNK_HAZARD_*` — highway chunk weight parameters

Updated all references to use the new constants.

**Tests:** `test_fire_rate_constants`, `test_scav_constants`, `test_boss_constants`, `test_highway_chunk_weight_constants` — verify constant values.

---

### Suggestion 89: HUD String Concatenation

**Problem:** `HUD.gd` uses `+` string concatenation for label text: `"x" + str(multiplier)` and `"TIER " + str(tier)`. String concatenation in GDScript allocates intermediate strings and is slower than format strings. With labels updating every frame during multiplier decay or tier transitions, this generates unnecessary garbage.

**Current code:** `multiplier_label.text = "x" + str(multiplier)` and `tier_label.text = "TIER " + str(tier)`.

**Fix:** Replace with `"x%d" % multiplier` and `"TIER %d" % tier` — the `%` format operator is faster and allocates fewer intermediate strings.

**Tests:** Existing `test_hud_multiplier_update` and `test_hud_tier_update` verify the output text remains identical.

---

### Suggestion 90: Highway Chunk Weight Constants Centralization

**Problem:** `Highway.gd` defines chunk weights as literal Dictionary values (40, 20, 10, 15, 15) and dynamic weight adjustments with magic numbers `40`, `20`, `10`, `15`, `15` and max/min caps `15`, `35`, `25`, `30`, `30` inside `_pick_chunk_type()`. These weights should be defined in `Constants.gd` along with max/min cap constants.

**Current code:** `var chunk_weights` dictionary with inline values. `_pick_chunk_type()` uses inline magic numbers.

**Fix:** Move base weights to `Constants.gd` as `CHUNK_WEIGHT_STANDARD_BASE = 40.0`, etc., plus `CHUNK_HAZARD_CAP`, `CHUNK_HAZARD_STEP`, and per-type max/min constants. Reference from `Constants.gd` in both `chunk_weights` initialization and `_pick_chunk_type()`.

**Tests:** `test_chunk_weights_use_constants` — verify chunk_weights match `Constants.CHUNK_WEIGHT_*_BASE`.

---

## Priority Matrix (Phase 7)

| Suggestion | Title | Effort | Impact | Priority |
|------------|-------|--------|--------|----------|
| 81 | Spawner Cleanup Signal Disconnect | Low | High | P1 |
| 82 | ObjectPool Fallback Pool Name Leak | Low | High | P1 |
| 83 | Spawner Cleanup Loop Unthrottled | Low | Medium | P2 |
| 84 | WeatherSystem Lightning Tween Null Safety | Low | Medium | P2 |
| 85 | Enemy Pool Release Signal Disconnect | Low | High | P1 |
| 86 | Scav WeaponMount Node Path Redundancy | Low | Low | P3 |
| 87 | Interceptor Lane-to-X Out-of-Bounds Crash | Low | Medium | P2 |
| 88 | Constants Centralization | Low | Low | P3 |
| 89 | HUD String Concatenation | Low | Low | P3 |
| 90 | Highway Chunk Weight Constants Centralization | Low | Low | P3 |

**Previously deferred (unchanged):** Part 22 (TileMapLayer Highway, P3), Part 35 (class_name EnemyBase, P3), Part 40 (Integration Tests, P1).
