# Race to Dead End — Implementation Plan

## Engine: Godot 4.4+

**Why Godot?** MIT-licensed open source, excellent 2D isometric support via TileMapLayers, built-in physics (or Jolt integration), GDScript for fast prototyping, strong community, cross-platform export (Windows, Linux, macOS, web, mobile). No royalties or licensing fees.

---

## Phase 0: Prototype Stabilization & LSP Resolutions (COMPLETED)

We conducted a deep static analysis of the prototype codebase and resolved several critical LSP errors, compiler failures, and gameplay bugs that blocked building and execution:

### 1. Compile-Time Resource Resolution

* **Issue**: `Enemy.gd` used `preload()` for enemy vehicle sprites (`rotor.png`, `scav.png`, `drone.png`) which did not exist, causing Godot to fail compilation at startup.
* **Resolution**:
  * Generated and imported high-fidelity isometric cyberpunk pixel art assets into `assets/sprites/enemies/`.
  * Converted the compile-time `preload()` to safe dynamic runtime `load()` with a defensive `ResourceLoader.exists()` check.

### 2. Scene Property & Node Type Mismatches (TSCN)

* **Issue**: Several nodes declared invalid properties (e.g. `color = Color(...)` on `Sprite2D`, `Panel`, and `TextureRect` classes).
* **Resolution**:
  * Converted UI backdrop `Panel` nodes in `GameOver.tscn` and `Garage.tscn` to `ColorRect` which natively supports direct solid colors.
  * Converted HUD boost and weapon indicator `TextureRect` nodes to `ColorRect` for seamless flat-color support.
  * Changed `Sprite2D` nodes in vehicle/bullet/mine scenes to load `icon.svg` as a fallback texture (or their designated textures) and colored them correctly using the native `self_modulate` property.
  * Replaced the missing texture-based `TextureProgressBar` in HUD with a standard `ProgressBar` for visual rendering.
  * Removed missing node paths (`$TileMap`, `$RoadLayer`, `$DecorationLayer`) in `Highway.gd` that were absent in the scene.

### 3. Spatial Positional Audio Fix

* **Issue**: `AudioManager.gd` used non-spatial `AudioStreamPlayer` nodes but tried to set `.global_position = position`, causing a runtime crash.
* **Resolution**: Upgraded all sound effects player instances to `AudioStreamPlayer2D` which natively supports spatial coordinates.

### 4. Core Gameplay Mechanics Correction

* **Issue**: Bullet objects collided with targets, emitted a signal, and self-deleted, but never actually called `take_damage()`, leaving enemies invincible.
* **Resolution**: Updated `Bullet.gd` collision logic to check for the presence of the `take_damage()` method on both `body` and `area` entries and deliver damage successfully.
* **Issue**: `EMPBlast` collision shape was `disabled = true` by default and never enabled.
* **Resolution**: Enabled `CollisionShape2D` in `EMPBlast.tscn` and added automatic run-time enabling in `EMPBlast.gd`.

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

Use Godot's TileMapLayer with isometric tile mode:

* Create tileset with 64×32 diamond tiles for road, shoulders, grass, barriers
* Implement `Y-sort` on all vehicle nodes so sprites render in correct depth order
* Use `z_index` and `z_as_relative` for foreground/background layering
* Highway scrolling: move the TileMapLayer downward and recycle top tiles (infinite scroll via tile offset or node repositioning)
* Parallax background layers (3 layers: near, mid, far) as separate TileMapLayers or Sprite2D scrollers

Key reference: Godot docs "Using TileMaps" + community isometric tutorials for tile coordinate conversion.

## Part 14: Player Controller & Vehicle Physics

**Approach**: Use `CharacterBody2D` with custom arcade-style movement (not full rigidbody sim) for responsive feel:

```text
- velocity.y = BASE_SPEED (constant forward push)
- velocity.x = lerp toward target lane position on left/right input
- lane_width = 64 pixels (isometric tile width)
- weave_dodge = instant 2-lane shift with cooldown 0.5s
- boost = multiply speed ×2 for 1.5s, 3 charges, recharge 1 charge / 8s
```

Alternative: Use Godot-Easy-Vehicle-Physics (GEVP) addon for raycast-based vehicle feel if arcade physics needs more refinement. Start with CharacterBody2D, swap if handling doesn't feel right.

Collision layers:

* Layer 1: Player
* Layer 2: Enemies
* Layer 3: Weapons (player bullets)
* Layer 4: Weapons (enemy bullets)
* Layer 5: Pickups / Power-ups

## Part 15: Enemy AI System

Each enemy type extends a base `Enemy.gd`:

```text
Enemy.gd (extends CharacterBody2D)
├── Rotor.gd   →  SwarmAI: match player Y speed, X drift toward player lane, attack on proximity
├── Scav.gd    →  FlankAI: maintain parallel lane, fire bullets periodically, ram if adjacent
└── Drone.gd   →  HoverAI: float above road, track player X, drop bomb marker → detonate after 1.5s
```

Spawner logic (`Spawner.gd`, autoload):

* Track difficulty tier (increases every 5 segments)
* Wave composition table: tier 1 = 2 Rotors, tier 2 = 3 Rotors + 1 Scav, etc.
* Spawn enemies off-screen top, set their Y velocity to match player speed
* Despawn when off-screen bottom
* Boss waves every 3000 pts: single large enemy with multiple HP segments

## Part 16: Combat & Weapon Systems

* **Bullet pool**: Use `ObjectPool` pattern (preload N bullets, recycle on visibility lost) to avoid instancing overhead
* **Machine gun**: Fire while held, 0.1s cooldown, instantiate Bullet at player position + offset, travel upward at speed × 1.5
* **Missile**: Fire toward nearest enemy in forward arc, homing strength = 0.5, destroy on contact
* **Mine**: Drop behind player, stays on road, AOE = 1 tile radius, enemies that touch it take damage
* **EMP**: Screen-flash animation, apply damage to all enemies on screen via `get_tree().get_nodes_in_group("enemy")`

Weapon switching: cycle through secondary array with `cycle_weapon` input, update HUD icon.

## Part 17: Terrain & Road Generation

Highway chunks are 10 tiles tall × 5 tiles wide. Chunks are queued in a `PrewarmBuffer` (3 chunks ahead, 1 behind current view):

```text
Chunk types (pick randomly, weighted):
- Standard:    40% — clear 4 lanes
- Debris:      20% — 1-2 lanes blocked by static wreck tiles
- Ice:         10% — friction modifier Area2D covers chunk
- Construction:15% — barriers reduce to 2 lanes
- Bridge:      15% — no shoulder, death zone on edge tiles
```

Road tile variants (random per lane): cracks, oil stains, lane markings (dashed/solid). Shoulder tiles: grass, gravel, barrier, guardrail.

## Part 18: UI, HUD & Menus

### HUD (CanvasLayer, game scene)

* Top-left: Score (animated counter), Multiplier badge
* Top-right: Speedometer (optional, simple bar)
* Bottom-left: Health bar (5 hearts or segmented bar)
* Bottom-center: Weapon display (primary icon + secondary icons with ammo count)
* Bottom-right: Boost indicator (3 bars, recharge animation)

### Menus

* **Main menu**: "RUN" (start), "GARAGE" (upgrades), "OPTIONS" (audio/video), "QUIT"
* **Game Over screen**: Score, High Score, Credits earned, "RUN AGAIN", "GARAGE", "MAIN MENU"
* **Garage**: Grid of upgrade slots with cost + current tier, credits display

## Part 19: Audio Integration

* **Music**: High-energy synthwave / dark electronic loop (e.g., Carpenter Brut style). Single track that layers intensity based on tier.
* **SFX categories** (AudioManager with bus routing):
  * Engine hum (looping, pitch varies with speed)
  * Machine gun (rapid short crackle)
  * Missile launch (whoosh)
  * Mine drop (clank)
  * EMP burst (power-up zap + bass drop)
  * Enemy death (explosion varies by type)
  * Pickup collect (ding)
  * Damage taken (metal crunch)
  * Boost activation (pitch-sweep)
* Use `AudioStreamPlayer2D` for positional audio (e.g., explosions behind player)

## Part 20: Build Pipeline, Testing & Deployment

### Testing strategy

* Unit tests with GUT (Godot Unit Test) addon for ScoreManager, GameManager logic
* Scene tests: spawn enemies, verify AI behavior, collision responses
* Performance profiling: monitor draw calls, particle count, instancing in Profiler tab
* Target: consistent 60 FPS on mid-range hardware

### Build targets

| Platform | Export preset | Notes |
| :--- | :--- | :--- |
| Linux | Linux/X11 | Primary dev target |
| Windows | Windows Desktop | Cross-compile from Linux |
| Web | HTML5 | For itch.io / game jams |
| Android | Android | Optional — touch controls would need rework |

### Release checklist

* [ ] All 20 parts implemented and tested
* [ ] Godot project exported and run on target platform
* [ ] Assets optimized (texture atlas, audio compression)
* [ ] Crash/error logging via `push_error` + file dump
* [ ] itch.io page with screenshots + playable web build

### Post-release

* Gather feedback on difficulty curve and vehicle handling
* Add more enemy types, road hazards, weapon variants
* Consider online leaderboard (LSP or Nakama integration)

---

## Phase 1: Deep Code Review & 10-Part Improvement Plan

A comprehensive audit of all 19 GDScript files, 14 TSCN scenes, and project configuration. Parts 21, 23, 24, 25, 26, 28, 29 are **IMPLEMENTED**. Remaining:

---

### Part 22: Replace Procedural Highway with TileMapLayer

**Problem:** Highway generates individual Polygon2D, StaticBody2D, Line2D, and Area2D nodes per tile. This is the single heaviest allocation in the project (280-480+ nodes at startup).

**Findings:**
- `Highway.gd:80-230` — 50 Polygon2D tiles + up to 50 StaticBody2D obstacles + 20 Line2D guardrails per chunk
- No batching — each Polygon2D is a separate draw call
- No TileMap usage despite Godot's optimized tile rendering

**Current approach:** Codebase uses `MultiMeshInstance2D` for batching lanes/shoulders/stripes (reduced draw calls). This is a valid alternative but not the TileMapLayer approach described in the original plan.

**Plan:**
1. Create a proper `TileSet` resource with isometric 64×32 diamond tiles for each chunk type
2. Replace `_generate_chunk_tiles()` with `TileMapLayer.set_cell()` calls
3. Use TileMapLayer's built-in collision layers for obstacles (no StaticBody2D per tile)
4. Use TileMapLayer's navigation/area layers for ice and bridge triggers
5. Guardrails: Use a single `Line2D` per chunk side instead of 20 individual segments
6. Pre-generate tile patterns as TileMapLayer data arrays for each chunk type

**Expected impact:** 90% reduction in highway node count, 10x fewer draw calls, 5x faster chunk generation

---

### Part 27: Optimize Per-Frame Operations (REMAINING: score ticker)

**Problem:** Multiple expensive operations run every frame across enemies, bullets, and the highway.

**IMPLEMENTED:**
- Bullet homing: `_cached_enemies` updated every `ENEMY_CACHE_INTERVAL` (0.25s) ✓
- Highway: cumulative threshold checks without `duplicate()` ✓
- HUD: `WEAPON_COLORS` is `const` ✓
- Interceptor: `Time.get_ticks_msec()` inside input blocks ✓

**REMAINING:**
- Score ticker still uses `_process` delta accumulation instead of a `Timer` node
- Replace `_process` in GameManager with a Timer (1s wait_time, autostart)

---

### Part 30: Code Quality, Cleanup, and Best Practices (REMAINING: dead code)

**IMPLEMENTED:**
- `Constants.LANE_POSITIONS`, `SPAWN_DISTANCE`, `CLEANUP_DISTANCE` ✓
- `TYPE_NAMES` explicit constants in `Enemy.gd` ✓
- `Constants.GUARDRAIL_WIDTH` in Highway ✓
- Dead boss check removed from GameManager ✓

**REMAINING:**
- `set_target_x()` in `Rotor.gd:3` — dead code (never called)
- `randf()` in Highway without RNG seed for determinism

---

## Phase 2: Deep Codebase Optimization (Completed May 2026)

A thorough codebase-wide audit of all 28 game scripts, 17 scenes, and 6 autoloads identified **15 issues** spanning performance, potential bugs, architecture, and maintainability. All 15 issues are resolved.

---

## Phase 3: Post-Optimization Growth Plan (10 Improvements)

Parts 32, 33, 34, 36, 37, 38, 39 are **IMPLEMENTED**. Remaining:

---

### Part 35: Enemy Inheritance via `class_name` (DEFERRED)

**Problem:** `Drone.gd:1`, `Scav.gd:1`, `Rotor.gd:1` use `extends "res://scripts/scenes/enemies/Enemy.gd"` — a fragile string path.

**Attempted:** Added `class_name EnemyBase` to `Enemy.gd` and changed subtypes to `extends EnemyBase`.

**Result:** Godot 4 headless mode fails to resolve `class_name` in compile-order when subtypes are `load()`-ed directly (GUT test context). String-path extends is more reliable in this environment.

**Status:** DEFERRED — revisit after Godot 4 resolves class_name compile-order issues. String-path `extends "res://..."` works correctly in both editor and headless modes.

---

### Part 40: Integration, Stress, and Performance Tests

**Problem:** All 560 tests are unit tests with mocked dependencies. No integration tests, stress tests, or performance benchmarks exist.

**Findings:**
- 30 test files, 560 total tests — all unit tests with isolated components
- No test spawns enemies + fires weapons + verifies score tracking end-to-end
- No test measures FPS under load (50+ enemies, 200+ bullets)
- `run_tests.gd` uses manually configured batches rather than glob-based discovery
- `test_helper.gd:24-28` mock is incomplete — uses `set()` for methods instead of actual method definitions

**Plan:**
1. **Integration tests (3-5 new files):**
   - "Spawner + Interceptor combat loop": Spawn enemy, fire weapon from player, enemy takes damage, enemy dies, score increases
   - "Highway + player movement": Player vehicle moves through 10 highway chunks, verify chunk recycle and position tracking
   - "Weather + player interaction": Rain starts, player enters bridge zone, verify both systems active simultaneously
2. **Stress tests (1 file):**
   - Spawn 30 enemies, fire 100 bullets, verify no crash and FPS > 30 (simulated)
   - Pool exhaustion: acquire 200 items from ObjectPool, verify no null returns
3. **Performance benchmarks (1 file):**
   - Time chunk generation: average of 10 generation cycles, report ms
   - Time bullet pool acquire/release: 1000 cycle average
4. **Cleanup `run_tests.gd`** to auto-discover test files using `-gdir` instead of hardcoded lists
5. **Fix `test_helper.gd`** mock — replace `set()` with actual `MockPlayer.gd` script

---

### Part 41: Code Quality Deep Cleanup (REMAINING)

**IMPLEMENTED:**
- `Constants.LANE_POSITIONS` used in `Interceptor._lane_to_x()` ✓
- `WeaponData.gd` resource class exists ✓

**REMAINING:**
- ObjectPool still uses `set_meta`/`get_meta` — should use typed properties
- No `UpgradeType` enum for typed keys (GameManager/Garage use string keys)
- Dev scripts remain in root (`check_bg.py`, `remove_bg.py`)
- `test_input.gd` dead file at root
- `default_env.tres` unused
- `WEAPON_TYPES` in Interceptor + `WEAPON_COLORS` in HUD still manually synced (WeaponData resource exists but not wired)
- Two test files use `extends "res://addons/gut/test.gd"` instead of `extends GutTest`

---

## Phase 4: Deep Codebase Audit — 10 Improvement Opportunities (COMPLETED)

All 10 parts (42-51) are implemented and tested:
- Part 42: Signal-based enemy list (active_enemies in Spawner, GameManager.register_enemy_spawned/destroyed)
- Part 43: Parallax background layers (3-layer ParallaxBackground with motion scales)
- Part 44: Civilian vehicles (Civilian.tscn, Civilian.gd, Spawner integration)
- Part 45: Boss encounters (BossWarRig.tscn, BossWarRig.gd, spawn threshold)
- Part 46: Floating combat text (pooled popup labels, damage numbers, CRIT!)
- Part 47: Screen transition effects (TransitionLayer autoload, fade-to-black)
- Part 48: Gamepad rumble (CameraShake.rumble(), all call sites wired)
- Part 49: Shared sprite scaling utility (Helpers.gd autoload)
- Part 50: Multiplier timer HUD indicator (ProgressBar, pulse animation)
- Part 51: Constants consolidation (WORLD_SCALE, CAMERA_Y_OFFSET, etc.)

---

## Phase 5: Production Hardening — 10 Targeted Improvements

Parts 57 (PauseMenu TSCN) and 59 (Scav/Drone parent assumption) are **IMPLEMENTED**. Remaining:

---

### Part 52: Persist Options Volume Settings to Disk

**Problem:** `Options.gd` modifies audio bus volumes via `AudioServer.set_bus_volume_db()` but never saves them. Every restart resets volumes to defaults.

**Files:** `scripts/scenes/ui/Options.gd:38-45`

**Findings:**
- `Options.gd:38-45` — `_on_master_changed()`, `_on_music_changed()`, `_on_sfx_changed()` call `AudioServer.set_bus_volume_db()` but never write to disk
- `Options.gd:29-32` — `_load_volume_settings()` reads from `AudioServer` which defaults to project settings (1.0 linear = 0 dB)
- Volume, fullscreen toggle, and any future settings are ephemeral
- `GameManager.gd:196-225` — `save_progress()` saves credits/high_score/upgrades but not audio settings
- `ConfigFile` class is never used anywhere in the project — the entire settings persistence API is unused

**Plan:**
1. Create `SettingsManager.gd` autoload that wraps `ConfigFile` for all user settings (audio, video, input, accessibility)
2. Add methods: `get_volume(bus_name)`, `set_volume(bus_name, value)`, `save()`, `load()`
3. In `Options.gd:_on_master_changed()` etc.: call `SettingsManager.set_volume()` instead of directly setting AudioServer
4. `SettingsManager.load()` runs in `_ready()` to restore saved volumes at startup
5. Add fullscreen toggle save/restore: `SettingsManager.get_bool("video/fullscreen", false)`
6. Write tests: verify save → restart → load restores volumes, fullscreen

**Subtasks:**
```
52.1 — Create SettingsManager.gd autoload wrapping ConfigFile (volume, video)
52.2 — Add get_volume/set_volume methods with AudioServer integration
52.3 — Update Options.gd to delegate to SettingsManager for all bus changes
52.4 — Save fullscreen toggle state to SettingsManager
52.5 — Test: save → restart → load restores all options correctly
```

**Expected impact:** Player settings persist across sessions. Audio tuning is no longer lost on restart.

---

### Part 53: Replace BossWarRig Private Method Access with Public Signal

**Problem:** `BossWarRig.gd:49` calls `_spawner._spawn_enemy("scav")` — accessing a private (underscore-prefixed) method of `Spawner.gd`.

**Files:** `scripts/scenes/enemies/BossWarRig.gd:49`, `scripts/scenes/world/Spawner.gd`

**Findings:**
- `BossWarRig.gd:34-37` — `_spawn_minions()` calls `_spawner._spawn_enemy("scav")` — underscore-prefixed private method
- `Spawner.gd` has a `boss_spawned` signal (line 6) but no `spawn_minion_requested` signal
- No `public` method equivalent exists — `_spawn_enemy()` is the only spawn entry point

**Plan:**
1. Add `signal spawn_minion_requested(enemy_type: String, count: int)` to `Spawner.gd`
2. In `BossWarRig.gd:_spawn_minions()`: emit the signal instead of calling `_spawner._spawn_enemy()`
3. In `Spawner.gd: _ready()` or boss registration step: connect minion spawn signal to `_spawn_enemy`
4. Remove the `_spawner` reference from `BossWarRig` if no other private methods are accessed
5. Update tests: verify minion spawn signal is emitted and handled correctly

---

### Part 54: Fix DroneBomb Collision Mask — Enable Counterplay

**Problem:** `DroneBomb.gd:10` sets `collision_mask = 1` (player layer only). Player bullets are on layer 3. Drone bombs can never be shot down.

**Files:** `scripts/scenes/weapons/DroneBomb.gd:8-10`

**Findings:**
- `DroneBomb.gd:10` — `collision_mask = 1` — detects only player body (layer 1). Player bullets are layer 3.
- `Bullet.gd:9-10` — Collision layer = 3 (player weapons), mask = 2 (enemies)
- No collision path exists from bullet → drone bomb
- `DroneBomb.gd:67-70` — `_detonate()` only checks bodies overlapping the blast, cannot pre-detonate from bullet hit

**Plan:**
1. Change `DroneBomb.gd:10` to use `collision_mask = 1 | 3` (player + player bullets)
2. Add `_on_area_entered()` handler to DroneBomb that detects bullet hits
3. On bullet hit: trigger immediate detonation
4. Add `hit_by_bullet` flag to distinguish bullet-triggered detonation from timer detonation
5. Optionally give drone bomb a small amount of HP (2 hits) so it doesn't die to a single MG bullet

---

### Part 55: Cache Civilian Player Reference Instead of Tree Traversal

**Problem:** `Civilian.gd:46` calls `get_tree().get_first_node_in_group("player")` every physics frame.

**Files:** `scripts/scenes/enemies/Civilian.gd:44-51`

**Findings:**
- `Civilian.gd:46` — `get_tree().get_first_node_in_group("player")` called every physics process (~60fps)
- `Civilian.gd:22-29` — `init()` method already exists with start_lane, speed, direction parameters — but no player reference parameter
- `Spawner.gd:108-115` — `_spawn_civilian()` calls `civilian.init(...)` but player is available as `player` member
- Other enemies cache player in `init()` via `_player = p_player`

**Plan:**
1. Add `var _player: Node = null` member to `Civilian.gd`
2. Add `player_ref` parameter to `Civilian.gd:init()`
3. In `Civilian.gd:_physics_process()`: use `_player` instead of `get_tree().get_first_node_in_group("player")`
4. In `Spawner.gd:_spawn_civilian()`: pass `player` to `civilian.init()`
5. Add `is_instance_valid(_player)` guard before `_player.global_position` access

---

### Part 56: Add @export Variables Across All Tunable Scripts

**Problem:** Zero `@export` variables exist in the entire project. Every gameplay value — speed, HP, cooldowns, spawn rates — requires editing GDScript to change.

**Files:** All `.gd` files with gameplay values

**Findings:**
- `Interceptor.gd` — `BASE_SPEED`, `BOOST_SPEED_MULTIPLIER`, `BOOST_DURATION`, `WEAVE_COOLDOWN` all hardcoded
- `Spawner.gd` — `MIN_WAVE_INTERVAL`, `WAVE_INTERVAL_TIER_REDUCTION` used but not editable
- `Highway.gd` — `CHUNK_HEIGHT`, `CHUNK_WIDTH`, chunk weights all hardcoded
- `Bullet.gd` — `speed`, `damage`, `homing_strength` set at runtime but not exposed
- `WeatherSystem.gd` — weather transition times, particle amounts, damage values hardcoded
- Zero `@export_group` annotations — no organizational structure for inspector

**Plan:**
1. Add `@export var` declarations to all gameplay-critical scripts, grouped by purpose:
   - `Interceptor.gd`: export speed, boost, weave cooldown, max health
   - `Spawner.gd`: export wave intervals, spawn distances, composition scaling
   - `Highway.gd`: export chunk dimensions, type weights, scroll speed
   - `Bullet.gd`: export base damage, speed, homing strength
   - `WeatherSystem.gd`: export transition times, particle amounts, damage values
2. Add `@export_group`, `@export_range`, `@export_tooltip` for organization and constraints

---

### Part 58: Create Shared WeaponData Resource (REMAINING: wire into Interceptor/HUD)

**IMPLEMENTED:**
- `scripts/resources/WeaponData.gd` resource class exists ✓

**REMAINING:**
- No `weapons_data.tres` resource file exists
- `Interceptor.gd` still uses `const WEAPON_TYPES` (line 10), not WeaponData
- `HUD.gd` still uses `const WEAPON_COLORS` (line 3), not WeaponData
- Manual sync between the two arrays is still required

**Plan:**
1. Create `weapons_data.tres` resource file with all 3 weapon entries (missile, mine, emp)
2. Replace `Interceptor.WEAPON_TYPES` with reference to the resource file
3. Replace `HUD.WEAPON_COLORS` with same resource reference
4. Both scripts load the same `preload("res://scripts/resources/weapons_data.tres")` — guaranteed sync
5. All future weapons are added by editing one resource file

---

### Part 60: Extract WeatherSystem Hardcoded Colors into Constants.gd (REMAINING: Color objects)

**IMPLEMENTED:**
- Numeric constants extracted: `ACID_OVERLAY_ALPHA_LIGHT`, `ACID_OVERLAY_ALPHA_HEAVY` in Constants.gd ✓

**REMAINING:**
- Hardcoded `Color()` RGB values remain in `WeatherSystem.gd`:
  - Acid overlay: `Color(0.1, 0.3, 0.1, 0.15)` (line 244)
  - Storm overlay: `Color(0.15, 0.2, 0.15, 0.25)` (line 247)
  - Rain particle colors constructed inline (lines 101, 104, 107)
- No `ACID_OVERLAY_COLOR_LIGHT`, `SKY_TINT_CLEAR`, etc. in Constants.gd

**Plan:**
1. Audit `WeatherSystem.gd` for all hardcoded `Color()` values
2. Add constants to `Constants.gd:`
   - `ACID_OVERLAY_COLOR_LIGHT: Color`
   - `ACID_OVERLAY_COLOR_HEAVY: Color`
   - `RAIN_TINT_COLOR_LIGHT`, `RAIN_TINT_COLOR_STORM`, `RAIN_TINT_COLOR_ACID: Color`
   - `LIGHTNING_FLASH_COLOR: Color`
   - `SKY_TINT_CLEAR`, `SKY_TINT_RAIN`, `SKY_TINT_STORM: Color`
   - `ACID_RAIN_DAMAGE_PER_SECOND: int`
   - `WEATHER_TRANSITION_SPEED: float`
3. Update `WeatherSystem.gd` to reference all constants instead of literals

---

## Priority Matrix (Remaining Parts)

| Part | Title | Effort | Impact | Priority |
|------|-------|--------|--------|----------|
| 22 | TileMapLayer Highway | High | Critical | P2 |
| 27 | Score ticker Timer | Low | Low | P2 |
| 30 | Dead code cleanup | Low | Low | P2 |
| 35 | class_name EnemyBase | Low | Medium | P3 |
| 40 | Integration Tests | Medium | High | P1 |
| 41 | Code Quality Cleanup | Medium | Medium | P1 |
| 52 | Persist Options Volume | Low | Medium | P1 |
| 53 | BossWarRig Private Method | Low | Medium | P1 |
| 54 | DroneBomb Collision Mask | Low | High | P0 |
| 55 | Cache Civilian Player Ref | Low | Low | P2 |
| 56 | @export Variables | Medium | High | P1 |
| 58 | Wire WeaponData Resource | Low | Medium | P2 |
| 60 | WeatherSystem Color Constants | Low | Low | P2 |

**P0 (do now):** Part 54 — DroneBomb cannot be shot down, gameplay fairness issue.
**P1 (do next):** Parts 40, 41, 52, 53, 56 — Integration tests, remaining cleanup, settings persistence, coupling fixes, inspector tuning.
**P2 (do later):** Parts 22, 27, 30, 55, 58, 60 — Major refactors and polish items.
**P3 (deferred):** Part 35 — Wait for Godot 4 class_name compile-order fix.
