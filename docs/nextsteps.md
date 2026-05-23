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

## Phase 5: Deep Performance & Feature Audit (New)

10 improvement suggestions identified via systematic codebase analysis of all 28 scripts, 17 scenes, and 6 autoloads:

### Suggestion 61: AudioManager Lazy Stream Generation

**Problem:** `AudioManager._ready()` synchronously generates all 14 procedural audio streams (~793,000 samples total) before the first frame. The 16-second menu music and 16-second game music alone account for 705,600 samples. This adds 100-300ms of startup delay visible as a blank/hang after the Godot splash.

**Current code:** `_generate_cached_streams()` called unconditionally in `_ready()`. Each `_build_16bit_stream()` call allocates a `PackedByteArray`, runs a tight loop calling the generator lambda for every sample, and constructs an `AudioStreamWAV`.

**Plan:**
1. Replace `_generate_cached_streams()` call in `_ready()` with individual lazy-init checks in each `play_*()` method.
2. For each `_stream_*` variable, use `if not _stream_laser: _stream_laser = _generate_laser_stream()` on first play.
3. Keep music streams as the only eagerly-loaded streams (play menu music immediately is expected UX).
4. Verify: launch game, confirm no startup freeze, confirm all SFX play correctly on first use.
5. Test: `test_audio_lazy_streams.gd` — acquire each stream type, verify non-null after first play call.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 62: Highway Chunk Dual-Buffer Recycling

**Problem:** `Highway._recycle_chunk()` calls `_get_cached_or_build()` which runs `duplicate()` on a cached template, then `_clear_chunk_tiles()` which `queue_free()` the old tiles node. Each recycle creates ~30-60 child nodes (MultiMeshInstance2D, Line2D, Area2D, StaticBody2D, Polygon2D) via `duplicate()` and frees an equivalent set. With 8 active chunks recycling every ~2.4 seconds, this is continuous alloc/free churn.

**Current code:** Template cache stores one tiles Node2D per ChunkType. `_get_cached_or_build` duplicates it on every call. `_recycle_chunk` calls `_clear_chunk_tiles` → `queue_free` on the old node.

**Plan:**
1. Change `_chunk_template_cache` to store Array of 2 tiles Node2D per ChunkType instead of 1.
2. Track active buffer index per chunk: use buffer[0], next recycle swaps to buffer[1].
3. Eliminate `duplicate()` calls — just reparent the pre-built buffer to the chunk.
4. Adjust `_reconnect_chunk_signals` to work on pre-built buffers (signals are lost on duplicate anyway).
5. Maintain buffer arrays in a clear state (reset colors, positions, etc.) before reuse.
6. Test: highway chunk scrolling for 60s at 60 FPS, verify no pipeline stall from alloc events.

**Effort:** Medium — **Impact:** High — **Priority:** P1

---

### Suggestion 63: Bullet Homing Distance Bounding

**Problem:** `Bullet._find_nearest()` iterates the entire `GameManager.enemy_list` per physics frame for every homing bullet. At 50 bullets (pool max) with 30 enemies, this is 1,500 distance-squared calculations per frame. The `_cache_timer` reduces `GameManager.enemy_list` refetches to every 0.25s, but the per-bullet iteration still runs every physics frame.

**Current code:** `_physics_process` calls `_find_nearest(_cached_enemies)` when `homing_strength > 0`. `_find_nearest` does a full O(n) scan with no early-out.

**Plan:**
1. Add `MAX_HOMING_RANGE = 400.0` constant — bullets beyond this range from all enemies skip homing.
2. In `_physics_process`, before calling `_find_nearest`, check if any enemy is in range via spatial distance check against first known enemy — if closest possible enemy is beyond range, skip iteration.
3. Add early-out to `_find_nearest`: if a candidate within `MAX_HOMING_RANGE` is found and distance_squared < 4000 (≈63px), return immediately.
4. Test: measure `_find_nearest` call count per frame with 30 enemies + 20 homing bullets. Verify reduction from 600 calls to ~60.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 64: WeatherSystem Acid Overlay Transition Bugfix

**Problem:** `WeatherSystem.set_weather()` initiates smooth transitions (rain particles, intensity) but the `acid_overlay` ColorRect color is never updated during or after transitions. The `_update_visuals_for_weather()` method (which sets overlay color) is only called from `_set_weather()` — a private method invoked once in `_ready()`. After the first `set_weather()` call from gameplay (`Game._on_segment_completed` at tier 8+), the overlay remains transparent black forever, so acid rain and storm have no visual overlay.

**Current code:** `set_weather()` → sets `target_weather`, `weather_transition = 0.0`, emits `weather_changed`. `_process` → `_update_weather_transition` ramps `weather_intensity` and eventually sets `current_weather = target_weather`. But `_update_visuals_for_weather(type)` is never called.

**Plan:**
1. In `_update_weather_transition`, when `weather_transition >= 1.0` (transition complete), call `_update_visuals_for_weather(target_weather)`.
2. Add alpha interpolation to `acid_overlay` during transitions: lerp between old overlay color and target overlay color based on `weather_intensity`.
3. Store the previous overlay color before starting a transition: `var _prev_overlay_color: Color`.
4. In `set_weather()`, save current `acid_overlay.color` as `_prev_overlay_color`.
5. In `_process`, interpolate: `acid_overlay.color = _prev_overlay_color.lerp(target_color, weather_intensity)`.
6. Test: call `set_weather(ACID_RAIN)`, verify `acid_overlay.color.a` transitions from 0 to `ACID_OVERLAY_COLOR_LIGHT.a` over 2 seconds.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 65: Difficulty Speed Scaling

**Problem:** `Constants.BASE_SPEED = 200.0` is constant for the entire game. As difficulty tier rises, only wave composition changes (more enemies, more types). The actual gameplay speed (scrolling rate, enemy approach rate, bullet travel time) never changes. This means higher tiers feel identical to lower ones except for enemy count — no escalation in pace.

**Current code:** Interceptor uses `speed = Constants.BASE_SPEED`. Enemies use `speed = base_speed * TYPE_MULTIPLIER`. Weather transitions are tier-based. No speed scaling exists.

**Plan:**
1. Add `SPEED_PER_TIER: float = 15.0` to Constants.gd.
2. In `Spawner._process`, after computing new `wave_interval`, set `GameManager.current_speed` to `BASE_SPEED + (difficulty_tier - 1) * SPEED_PER_TIER`.
3. Add `current_speed: float` to GameManager, defaulting to `BASE_SPEED`. Start at `BASE_SPEED` in `start_game()`.
4. Add `signal speed_changed(speed: float)` to GameManager.
5. Interceptor reads `GameManager.current_speed` instead of `Constants.BASE_SPEED` for its `speed` variable, updating on `speed_changed`.
6. Enemy `init()` receives current speed from GameManager.
7. Cap at 3x BASE_SPEED (tier 28+) to prevent physics instability.
8. Test: verify speed increases by 15 per tier, caps at 600, player `velocity.y` reflects the change.

**Effort:** Low — **Impact:** High — **Priority:** P1

---

### Suggestion 66: Save/Load Data Integrity with Checksum

**Problem:** `GameManager.load_progress()` has type guards for credits, high_score, and upgrade_levels, but no integrity check. A partially written save file (power loss, disk full) loads whatever data exists, potentially setting credits to 0 or high_score to garbage. The corrupt data is silently accepted with `push_warning`.

**Current code:** `save_progress()` writes a Dictionary with `store_var()`. `load_progress()` reads with `get_var()` and applies type guards.

**Plan:**
1. Add a simple CRC32 checksum using `hash()` on the serialized dictionary string.
2. `save_progress()`: compute `data._checksum = hash(var_to_str(data))`, then write the data.
3. `load_progress()`: extract `_checksum` from loaded data, compute expected checksum over remaining fields. If mismatch, skip load entirely and use defaults.
4. Ensure backward compatibility: if loaded data has no `_checksum` key, accept it (migration from old saves).
5. Test: manually corrupt save file, verify load falls back to defaults. Test: save → load → verify values match.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 67: GameOver Restart Visual Delay

**Problem:** `Game._process()` handles game over restart immediately on `ui_accept` press with no delay or visual transition. The game over screen appears instantly, and pressing space restarts the game immediately. This can cause accidental restarts (muscle memory from shooting) and feels abrupt.

**Current code:** `if state == GAME_OVER and Input.is_action_just_pressed("ui_accept"): _restart_game()` — fires instantly.

**Plan:**
1. Add a 1.5-second cooldown timer after entering GAME_OVER state before accepting restart input.
2. Add a brief fade-to-black before `TransitionLayer.reload_scene()` (200ms tween on modulate).
3. Show "PRESS SPACE TO CONTINUE" text on game over screen that fades in after the cooldown.
4. Connect via `GameManager.game_over` signal to start the cooldown.
5. Test: trigger game over, verify space does nothing for 1.5s, then works. Verify fade transition plays.

**Effort:** Low — **Impact:** Low — **Priority:** P3

---

### Suggestion 68: ObjectPool Pickup Signal Cleanup

**Problem:** `ObjectPool.acquire_pickup()` guards against duplicate `body_entered` connections (`if not body_entered.is_connected(...)`), but never disconnects them on `release()`. This means every pooled pickup carries an active `body_entered` → `_on_pickup_body_entered` connection even while sitting invisible and disabled in the pool. When the pool holds 20 pickups, there are 20 live signal connections pointing at the same receiver method.

**Current code:** `acquire_pickup()` checks and connects. `_on_pickup_body_entered` calls `release(pickup)` which does NOT disconnect signals.

**Plan:**
1. In `ObjectPool.release()`, check if the node has `body_entered` signal and disconnect `_on_pickup_body_entered` if connected.
2. Add a generic signal cleanup at release time: iterate `node.get_signal_list()`, disconnect all connections.
3. Verify: acquire pickup → release → re-acquire → the fresh connection in `acquire_pickup()` doesn't encounter stale connections.
4. Test: verify `body_entered.get_connections().size()` is 1 during active use, 0 while in pool.

**Effort:** Low — **Impact:** Low — **Priority:** P3

---

### Suggestion 69: BossWarRig Multi-Phase Behavior

**Problem:** BossWarRig has only 2 phases: ram-only (above 30% HP) and ram+minion (below 30% HP, triggered once). This makes boss fights predictable and monotonous. The boss doesn't change attack patterns, speed, or visual appearance as its HP decreases.

**Current code:** `_execute_attack()` checks `hp <= BOSS_WAR_RIG_HP * 0.3` and `not minion_spawned`. Before that, always calls `_ram_player()`. Only 2 attack patterns exist (ram + minion spawn).

**Plan:**
1. Add 3 phases: Phase 1 (100%-61% HP) = ram only. Phase 2 (60%-31% HP) = ram + occasional bullet volley (3 bullets in spread). Phase 3 (30%-0% HP) = ram + minion spawn + increased speed + bullet volley.
2. Add a `_fire_bullet_spread()` method that spawns 3 enemy bullets at -15°, 0°, +15° angles.
3. Increase boss speed by 20% in Phase 2, 40% in Phase 3.
4. Update `phase` variable (currently set but unused) and use it to drive behavior.
5. Add visual indicator: modulate sprite tint per phase (normal → yellow pulse → red pulse).
6. Add `signal boss_phase_changed(phase: int)` to BossWarRig.
7. Test: spawn boss at tier 5, verify phase transitions at 60% and 30% HP, verify attack pattern changes.

**Effort:** Medium — **Impact:** High — **Priority:** P1

---

### Suggestion 70: Spawner Enemy List Consolidation

**Problem:** `Spawner` maintains `active_enemies: Array[Node]` in parallel with `GameManager.enemy_list: Array[Node]`. Both track the same enemies with the same lifecycle. Spawner's list is used for cleanup, GameManager's list is used for Bullet homing targeting. Two lists means two sets of add/remove operations, two `_process` iterations, and potential for drift.

**Current code:** Spawner pushes to both lists (`active_enemies.append(enemy)` + spawner emits `enemy_spawned` → GameManager receives via `register_enemy_spawned`). Cleanup iterates `active_enemies` and attempts `ObjectPool.release()` or `queue_free()`.

**Plan:**
1. Remove `active_enemies` from Spawner. Use `GameManager.enemy_list` exclusively.
2. Spawner cleanup in `_process` iterates `GameManager.enemy_list` instead.
3. Add `GameManager.get_enemy_count()` and `GameManager.get_enemies_in_range(position, radius)` for efficient querying.
4. Add `GameManager.remove_enemy(enemy)` for cleanup, which also handles ObjectPool release.
5. Ensure Spawner's `_on_enemy_destroyed` no longer needs to `active_enemies.erase(enemy)`.
6. Test: full combat loop, verify enemies appear and disappear from `GameManager.enemy_list` correctly. Verify Bullet homing still works.

**Effort:** Medium — **Impact:** Medium — **Priority:** P2

---

## Priority Matrix

| Suggestion | Title | Effort | Impact | Priority |
|------------|-------|--------|--------|----------|
| 62 | Highway Chunk Dual-Buffer Recycling | Medium | High | P1 |
| 65 | Difficulty Speed Scaling | Low | High | P1 |
| 69 | BossWarRig Multi-Phase Behavior | Medium | High | P1 |
| 61 | AudioManager Lazy Stream Generation | Low | Medium | P2 |
| 63 | Bullet Homing Distance Bounding | Low | Medium | P2 |
| 64 | WeatherSystem Acid Overlay Bugfix | Low | Medium | P2 |
| 66 | Save/Load Data Integrity Checksum | Low | Medium | P2 |
| 70 | Spawner Enemy List Consolidation | Medium | Medium | P2 |
| 67 | GameOver Restart Visual Delay | Low | Low | P3 |
| 68 | ObjectPool Pickup Signal Cleanup | Low | Low | P3 |

**Previously deferred:** Part 22 (TileMapLayer Highway, P3), Part 35 (class_name EnemyBase, P3), Part 40 (Integration Tests, P1).

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
