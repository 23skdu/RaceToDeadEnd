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

A comprehensive audit of all 19 GDScript files, 14 TSCN scenes, and project configuration identified **5 critical**, **10 high**, **15 medium**, and **15 low** severity issues across performance, gameplay, architecture, and code quality. Below is a prioritized 10-part plan to address them.

---

### Part 21: Object Pooling for Weapons, Pickups, and Road Chunks

**Problem:** Every weapon fire, enemy death, and chunk recycle allocates new nodes from scratch. During combat this generates 50-100+ allocations per second, causing GC pressure and frame spikes.

**Findings:**
- `Game.gd:43,49,60,70` — `load("res://scenes/weapons/Bullet.tscn")` called on every shot
- `Spawner.gd:120-150` — Pickups create 4 new nodes each (Area2D + CollisionShape2D + CircleShape2D + Polygon2D)
- `Highway.gd:80-230` — Each chunk generates 70-120+ nodes (Polygon2D, StaticBody2D, CollisionPolygon2D, Line2D, Area2D)

**Plan:**
1. Create a generic `ObjectPool.gd` singleton that pre-allocates N instances and recycles them
2. Preload Bullet, Mine, EMP, and Pickup scenes into pools at game start
3. Pool size: 50 bullets, 10 mines, 5 EMPs, 20 pickups
4. Highway: Pre-create 6 chunk Node2D containers and recycle their tile children instead of creating new nodes
5. Replace all `load().instantiate()` and `Node2D.new()` calls with `pool.get()` / `pool.release()`

**Expected impact:** 60-80% reduction in runtime allocations, elimination of GC-related frame drops

---

### Part 22: Replace Procedural Highway with TileMapLayer

**Problem:** Highway generates individual Polygon2D, StaticBody2D, Line2D, and Area2D nodes per tile. This is the single heaviest allocation in the project (280-480+ nodes at startup).

**Findings:**
- `Highway.gd:80-230` — 50 Polygon2D tiles + up to 50 StaticBody2D obstacles + 20 Line2D guardrails per chunk
- No batching — each Polygon2D is a separate draw call
- No TileMap usage despite Godot's optimized tile rendering

**Plan:**
1. Create a proper `TileSet` resource with isometric 64×32 diamond tiles for each chunk type
2. Replace `_generate_chunk_tiles()` with `TileMapLayer.set_cell()` calls
3. Use TileMapLayer's built-in collision layers for obstacles (no StaticBody2D per tile)
4. Use TileMapLayer's navigation/area layers for ice and bridge triggers
5. Guardrails: Use a single `Line2D` per chunk side instead of 20 individual segments
6. Pre-generate tile patterns as TileMapLayer data arrays for each chunk type

**Expected impact:** 90% reduction in highway node count, 10x fewer draw calls, 5x faster chunk generation

---

### Part 23: Cache Procedural Audio Streams

**Problem:** Every SFX call regenerates audio waveforms from scratch, allocating PackedByteArray and AudioStreamWAV objects.

**Findings:**
- `AudioManager.gd:52-140` — Each `play_synth_*` function creates a new `PackedByteArray` (1323-4800 bytes) and `AudioStreamWAV`
- During combat with 5+ simultaneous enemy deaths, this generates 10-20 allocations per second
- Music stream is generated once at startup (correct), but SFX is not

**Plan:**
1. Generate all 5 SFX streams once in `_ready()` and cache as `const` or member variables
2. `play_synth_laser()`, `play_synth_explosion()`, etc. simply play the cached stream
3. Increase SFX player pool from 8 to 12 for intense combat scenarios
4. Add priority system: hurt > explosion > laser > boost > emp (important sounds don't get interrupted)
5. Configure proper audio buses in `project.godot` [audio] section (Master, Music, SFX)

**Expected impact:** 100% elimination of audio-related runtime allocations, better sound reliability

---

### Part 24: Fix Difficulty Scaling and Game Balance

**Problem:** Difficulty advances at double the intended rate, enemy speeds are inconsistent, and wave frequency never changes.

**Findings:**
- `GameManager.gd:62-68, 83-87` — Both score-based AND segment-based triggers advance difficulty independently
- `Spawner.gd:92` — Enemy speed uses `player.speed` which is inflated during boost (400 vs 200)
- `Spawner.gd:9` — Wave interval is fixed at 5.0s regardless of difficulty tier
- `Highway.gd:14-20` — Chunk type weights are static; harder terrains don't increase with difficulty

**Plan:**
1. Unify difficulty advancement: use a single `difficulty_progress` float that increments from both score and segments, advancing tier when it crosses thresholds
2. Fix enemy spawn speed: use `BASE_SPEED` constant instead of `player.speed` in `Spawner.gd:92`
3. Scale wave interval with difficulty: `wave_interval = max(2.0, 5.0 - (tier - 1) * 0.3)`
4. Scale chunk weights with difficulty: increase debris/ice/bridge weights, decrease standard weight as tier rises
5. Add visual tier transition notification (screen flash + "TIER X" label animation)

**Expected impact:** Predictable difficulty curve, consistent enemy behavior, escalating tension

---

### Part 25: Fix Broken Weapon Mechanics

**Problem:** Mines have no AOE damage, EMP has no stun effect, and both lack explosion audio/visual feedback.

**Findings:**
- `Mine.gd:34-35` — `_explode()` only calls `queue_free()` despite `explosion_radius = 64.0` being defined
- `EMPBlast.gd:4` — `stun_duration = 2.0` is defined but never applied to enemies
- `Mine.gd` — No explosion sound effect
- `EMPBlast.gd:20-25` — Collision shape scaling via node `scale` may not work correctly in Godot 4

**Plan:**
1. Mine AOE: On explosion, use `get_tree().get_nodes_in_group("enemy")` and damage all within `explosion_radius` distance
2. Mine explosion: Add `AudioManager.play_synth_explosion()` call in `_explode()`
3. Mine visual: Add a brief flash/polygon explosion effect before `queue_free()`
4. EMP stun: Add `stun_timer` variable to `Enemy.gd`; when stunned, set `velocity = Vector2.ZERO` and skip AI logic
5. EMP collision: Modify `CollisionShape2D.shape.radius` directly instead of scaling the node
6. EMP visual: Add expanding ring Line2D or particle effect

**Expected impact:** Weapons behave as designed, satisfying combat feedback

---

### Part 26: Decouple Systems via Signal Architecture

**Problem:** Highway directly calls methods on player body, Scav assumes parent is world node, and ScoreManager traverses the scene tree for player references.

**Findings:**
- `Highway.gd:232-251` — Calls `body.set_slippery()`, `body.take_damage()`, sets `body.current_lane` directly
- `Scav.gd:57` — `get_parent().add_child(bullet)` assumes parent is the world node
- `ScoreManager.gd:28-34` — `get_tree().get_nodes_in_group("player")` on every pickup collection
- `Rotor.gd:10-13, Scav.gd:16-19, Drone.gd:15-18` — All enemies do tree traversal until player is cached

**Plan:**
1. Highway: Replace direct method calls with signal emissions (`ice_entered`, `ice_exited`, `bridge_fall`); player listens and responds
2. Scav/Drone: Use a `world` reference passed from `Game.gd` or emit `fire_bullet` signal that Game handles
3. ScoreManager: Cache player reference on `GameManager.game_started` signal, invalidate on `game_over`
4. Enemies: Pass player reference through `init()` from Spawner (already available), remove tree traversal fallback
5. Create a `GameEvents` signal bus singleton for cross-system communication if needed

**Expected impact:** Loose coupling, easier testing, no hidden dependencies between systems

---

### Part 27: Optimize Per-Frame Operations

**Problem:** Multiple expensive operations run every frame across enemies, bullets, and the highway.

**Findings:**
- `Bullet.gd:27-32` — Homing bullets call `get_tree().get_nodes_in_group("enemy")` + iterate all enemies every frame
- `Highway.gd:68-78` — `_pick_chunk_type()` recalculates total weight (95) every call
- `HUD.gd:37` — `[Color.RED, Color.YELLOW, Color.CYAN]` array allocated on every weapon display update
- `Interceptor.gd:92` — `Time.get_ticks_msec()` called every frame even when no input
- `GameManager.gd:37-42` — `_process` runs score ticker even when not needed (could use Timer node)

**Plan:**
1. Bullet homing: Cache enemy list, update every 0.25s instead of every frame; use spatial partitioning or nearest-enemy signal
2. Highway: Make `TOTAL_CHUNK_WEIGHT = 95` a constant
3. HUD: Move weapon color array to `const WEAPON_COLORS = [Color.RED, Color.YELLOW, Color.CYAN]`
4. Interceptor: Move `Time.get_ticks_msec()` inside the `Input.is_action_just_pressed` blocks
5. Score ticker: Replace `_process` delta accumulation with a `Timer` node (1s wait_time, autostart)
6. Enemy tree traversal: Eliminate entirely by passing player reference in `init()` (see Part 26)

**Expected impact:** 30-50% reduction in per-frame CPU work, smoother 60 FPS

---

### Part 28: Fix Multiplier, Score, and Progression Bugs

**Problem:** Score multiplier pickups are permanent instead of timed, credits display shows decimals, and save data has no corruption handling.

**Findings:**
- `ScoreManager.gd:35-36` — Multiplier pickup permanently increases multiplier (design says "2× for 10 seconds")
- `GameOver.gd:24` — `floori(final_score / 10.0)` — float division then floor (already fixed, but verify)
- `GameManager.gd:121-128` — No `typeof()` validation on loaded save data
- `Garage.gd:49-52` — No max-level enforcement at data layer
- `HUD.gd:40-41` — `_on_game_over()` method exists but is never connected to GameManager signal

**Plan:**
1. Multiplier timer: Add `multiplier_timer` to GameManager; on pickup, set timer; on timeout, reset multiplier to 1
2. HUD: Connect `GameManager.game_over` to `HUD._on_game_over()` in `Game.gd`
3. Save validation: Add `typeof()` checks on loaded data; if corrupted, log warning and use defaults
4. Garage: Add `if level < costs.size() - 1:` guard in `_on_upgrade_pressed()`
5. Add score popup labels: Connect `ScoreManager.score_popped` to a `ScorePopup` node that shows "+50" floating text

**Expected impact:** Correct game behavior, robust save system, better player feedback

---

### Part 29: Add Missing Gameplay Features

**Problem:** Several core features from the design document are stubs or entirely missing.

**Findings:**
- `Main.gd:27-28` — Options menu handler is `pass`
- `Spawner.gd` — Pickup drops implemented but boost/ammo pickups were stubs (now fixed)
- No civilian vehicles (design: +500 for protecting, -1 HP for hitting)
- No weather system (design: fog, dust storms, acid rain)
- No boss encounters (design: every 3000 pts)
- No parallax backgrounds
- `project.godot` — `accelerate` (W) and `brake` (S) inputs defined but unused

**Plan (prioritized by impact):**
1. **Phase 1 (essential):**
   - Options menu: Add audio volume sliders (Master, Music, SFX buses), fullscreen toggle
   - Connect W/S to speed control: `speed = BASE_SPEED * (1.0 + input_strength * 0.5)`
   - HUD game-over visibility: Connect signal properly
   - Score popup labels for kills and pickups

2. **Phase 2 (important):**
   - Civilian vehicles: Non-hostile Area2D nodes; bonus for not hitting them, penalty for collision
   - Parallax backgrounds: 3-layer scrolling (near: guardrails, mid: ruins, far: mountains)
   - Boss encounters: Every 3000 pts, spawn a large multi-HP enemy with special attacks

3. **Phase 3 (polish):**
   - Weather system: Visual overlay (fog/dust particles), gameplay effects (reduced visibility on acid rain)
   - Pause state: Implement `GameState.PAUSED`, freeze all `_process` logic
   - Daily run challenge: Seed-based procedural generation

**Expected impact:** Complete feature set matching design document, professional polish

---

### Part 30: Code Quality, Cleanup, and Best Practices

**Problem:** Dead code, magic numbers, fragile patterns, and missing error handling throughout the codebase.

**Findings:**
- `GameManager.gd:65-66` — Boss check with `pass` body (dead code)
- `Rotor.gd:25-27` — `set_target_x()` never called (dead code)
- `Enemy.gd:66-67` — `_on_visible_on_screen_notifier_screen_exited()` never fires (no notifier in scene)
- `GameOver.gd:4` — `garage_requested` signal defined but never connected in `Game.gd`
- `Spawner.gd:80` / `Interceptor.gd:125-127` — Lane position formula duplicated (`-96.0 + lane * 64.0`)
- `Enemy.gd:63` — Enemy type string derived from `Enum.keys()[type].to_lower()` (fragile)
- Magic numbers: `450.0` spawn distance in Spawner and Highway, hardcoded rail positions in Highway

**Plan:**
1. Remove all dead code: boss check stub, `set_target_x()`, unused screen-exited handler, unused garage signal
2. Extract shared constants: `LANE_POSITIONS = [-96.0, -32.0, 32.0, 96.0]`, `SPAWN_DISTANCE = 450.0`, `CLEANUP_DISTANCE = 450.0`
3. Replace enum-to-string with explicit constants: `const ENEMY_TYPE_STRINGS = ["rotor", "scav", "drone"]`
4. Add `const` for Highway rail positions derived from lane geometry
5. Add null guards and `is_instance_valid()` checks on all cross-node references
6. Add `push_warning()` for unexpected states (e.g., pickup collected by non-player)
7. Standardize error handling pattern: check → warn → fallback

**Expected impact:** Cleaner codebase, fewer silent failures, easier maintenance for contributors

---

## Priority Matrix

| Part | Effort | Impact | Priority |
|---|---|---|---|
| 21. Object Pooling | Medium | High | P0 |
| 22. TileMapLayer Highway | High | Critical | P0 |
| 23. Cache Audio Streams | Low | Medium | P1 |
| 24. Fix Difficulty Scaling | Medium | High | P0 |
| 25. Fix Weapon Mechanics | Low | High | P0 |
| 26. Decouple Systems | Medium | Medium | P1 |
| 27. Optimize Per-Frame Ops | Low | Medium | P1 |
| 28. Fix Progression Bugs | Low | High | P0 |
| 29. Add Missing Features | High | High | P2 |
| 30. Code Quality Cleanup | Low | Medium | P1 |

**P0 (do now):** Parts 21, 22, 24, 25, 28 — Fix broken mechanics and critical performance issues
**P1 (do next):** Parts 23, 26, 27, 30 — Optimize and clean up architecture
**P2 (do later):** Part 29 — Add missing design features

---

## Part 31: Loadable Content Pack System (Music, Skins, Themes)

### Overview

A modular content pack system that lets players drop folders into `user://packs/` to customize the game's music, vehicle sprites, and visual theme without modifying the core project. Packs are discovered at startup, validated, and activated through a new **Customize** tab in the Garage UI. Each pack is self-contained with a `pack.json` manifest.

### Architecture

```
user://packs/
├── synthwave_vibes/
│   ├── pack.json
│   ├── music/
│   │   ├── track_01.ogg
│   │   └── track_02.ogg
│   ├── skins/
│   │   ├── player/interceptor.png
│   │   ├── enemies/rotor.png
│   │   ├── enemies/scav.png
│   │   └── enemies/drone.png
│   └── theme/
│       ├── highway_lane.png
│       ├── highway_shoulder.png
│       ├── highway_stripe.png
│       ├── desert_sand.png
│       └── palette.json
└── metal_mayhem/
    ├── pack.json
    └── ...
```

### 31.1: Pack Manifest Schema (`pack.json`)

```json
{
  "pack_id": "synthwave_vibes",
  "name": "Synthwave Vibes",
  "author": "PlayerName",
  "version": "1.0.0",
  "description": "Dark synthwave soundtrack with neon car skins",
  "content_types": ["music", "skin", "theme"],
  "music": {
    "tracks": ["music/track_01.ogg", "music/track_02.ogg"],
    "shuffle": true
  },
  "skins": {
    "player": "skins/player/interceptor.png",
    "enemies": {
      "rotor": "skins/enemies/rotor.png",
      "scav": "skins/enemies/scav.png",
      "drone": "skins/enemies/drone.png"
    }
  },
  "theme": {
    "highway_lane": "theme/highway_lane.png",
    "highway_shoulder": "theme/highway_shoulder.png",
    "highway_stripe": "theme/highway_stripe.png",
    "desert_sand": "theme/desert_sand.png",
    "palette": {
      "lane_color": "#2e2e38",
      "shoulder_color": "#c2a36a",
      "stripe_color": "#ffffcc",
      "guardrail_color": "#ff0080",
      "sky_color": "#0a0a14"
    }
  }
}
```

**Validation rules:**
- `pack_id` must be unique, alphanumeric + underscores, max 32 chars
- `content_types` is an array of strings from `["music", "skin", "theme"]`
- All referenced file paths must exist relative to the pack folder
- Image files must be PNG, SVG, or WebP; audio must be OGG or WAV
- Max pack size: 50 MB (enforced at load time)

### 31.2: PackManager Singleton (`autoload/PackManager.gd`)

Responsibilities:
- Scan `user://packs/` on `_ready()` for valid `pack.json` manifests
- Parse and validate each manifest against the schema
- Store discovered packs in a `Dictionary` keyed by `pack_id`
- Provide methods to activate/deactivate packs by content type
- Expose signals for UI updates when packs change

```gdscript
extends Node

signal pack_discovered(pack_id: String, name: String)
signal pack_activated(pack_id: String, content_type: String)
signal pack_deactivated(content_type: String)
signal pack_validation_failed(pack_id: String, error: String)

const PACKS_DIR: String = "user://packs/"
const MAX_PACK_SIZE_BYTES: int = 50 * 1024 * 1024  # 50 MB

var discovered_packs: Dictionary = {}
var active_packs: Dictionary = {
    music = "",
    skin = "",
    theme = ""
}

func _ready() -> void:
    _scan_packs()

func _scan_packs() -> void:
    if not DirAccess.dir_exists_absolute(PACKS_DIR):
        return
    var dir = DirAccess.open(PACKS_DIR)
    dir.list_dir_begin()
    var folder = dir.get_next()
    while folder != "":
        if dir.current_is_dir():
            var manifest_path = PACKS_DIR.path_join(folder).path_join("pack.json")
            if FileAccess.file_exists(manifest_path):
                _load_manifest(manifest_path, folder)
        folder = dir.get_next()
    dir.list_dir_end()

func _load_manifest(path: String, folder: String) -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return
    var json_text = file.get_as_text()
    var json = JSON.new()
    var parse_result = json.parse(json_text)
    if parse_result != OK:
        pack_validation_failed.emit(folder, "Invalid JSON")
        return
    var data = json.data
    if not _validate_manifest(data, folder):
        return
    discovered_packs[data.pack_id] = {
        "data": data,
        "folder": PACKS_DIR.path_join(folder),
        "size": _get_folder_size(PACKS_DIR.path_join(folder))
    }
    pack_discovered.emit(data.pack_id, data.name)

func _validate_manifest(data: Dictionary, folder: String) -> bool:
    # Required fields
    if not data.has("pack_id") or not data.has("name"):
        pack_validation_failed.emit(folder, "Missing pack_id or name")
        return false
    if not data.pack_id.match("[a-z0-9_]+"):
        pack_validation_failed.emit(folder, "Invalid pack_id format")
        return false
    # Check content_types
    if not data.has("content_types") or not data.content_types is Array:
        pack_validation_failed.emit(folder, "Missing content_types")
        return false
    # Validate referenced files exist
    var base = PACKS_DIR.path_join(folder)
    for content_type in data.content_types:
        if not _validate_content_section(data, content_type, base):
            return false
    return true

func _validate_content_section(data: Dictionary, type: String, base: String) -> bool:
    match type:
        "music":
            if data.has("music") and data.music.has("tracks"):
                for track in data.music.tracks:
                    if not FileAccess.file_exists(base.path_join(track)):
                        pack_validation_failed.emit(data.pack_id, "Missing track: " + track)
                        return false
        "skin":
            if data.has("skins"):
                if data.skins.has("player"):
                    if not FileAccess.file_exists(base.path_join(data.skins.player)):
                        pack_validation_failed.emit(data.pack_id, "Missing player skin")
                        return false
                if data.skins.has("enemies"):
                    for enemy in data.skins.enemies:
                        if not FileAccess.file_exists(base.path_join(data.skins.enemies[enemy])):
                            pack_validation_failed.emit(data.pack_id, "Missing enemy skin: " + enemy)
                            return false
        "theme":
            if data.has("theme"):
                if data.theme.has("palette"):
                    for color_key in data.theme.palette:
                        if not _is_valid_hex_color(data.theme.palette[color_key]):
                            pack_validation_failed.emit(data.pack_id, "Invalid color: " + color_key)
                            return false
    return true

func _is_valid_hex_color(s: String) -> bool:
    if not s.begins_with("#"):
        return false
    if s.length() != 7:
        return false
    return true

func _get_folder_size(path: String) -> int:
    var total = 0
    var dir = DirAccess.open(path)
    if not dir:
        return 0
    dir.list_dir_begin()
    var file = dir.get_next()
    while file != "":
        if dir.current_is_dir():
            total += _get_folder_size(path.path_join(file))
        else:
            total += dir.get_length()
        file = dir.get_next()
    dir.list_dir_end()
    return total

func activate_pack(pack_id: String, content_type: String) -> bool:
    if not discovered_packs.has(pack_id):
        return false
    var pack = discovered_packs[pack_id]
    if pack.size > MAX_PACK_SIZE_BYTES:
        return false
    active_packs[content_type] = pack_id
    pack_activated.emit(pack_id, content_type)
    _apply_pack_content(pack, content_type)
    return true

func deactivate_pack(content_type: String) -> void:
    active_packs[content_type] = ""
    pack_deactivated.emit(content_type)
    _revert_pack_content(content_type)

func _apply_pack_content(pack: Dictionary, content_type: String) -> void:
    match content_type:
        "music":
            _apply_music_pack(pack.data)
        "skin":
            _apply_skin_pack(pack.data, pack.folder)
        "theme":
            _apply_theme_pack(pack.data, pack.folder)

func _apply_music_pack(data: Dictionary) -> void:
    if data.has("music") and data.music.has("tracks"):
        var base = discovered_packs[data.pack_id].folder
        var tracks: Array[AudioStreamOggVorbis] = []
        for track_path in data.music.tracks:
            var full_path = base.path_join(track_path)
            var stream = load(full_path) as AudioStreamOggVorbis
            if stream:
                tracks.append(stream)
        if tracks.size() > 0:
            AudioManager.set_playlist(tracks, data.music.get("shuffle", true))

func _apply_skin_pack(data: Dictionary, base: String) -> void:
    if data.has("skins"):
        if data.skins.has("player"):
            var path = base.path_join(data.skins.player)
            var tex = load(path) as Texture2D
            if tex:
                _emit_skin_loaded("player", tex)
        if data.skins.has("enemies"):
            for enemy in data.skins.enemies:
                var path = base.path_join(data.skins.enemies[enemy])
                var tex = load(path) as Texture2D
                if tex:
                    _emit_skin_loaded(enemy, tex)

func _apply_theme_pack(data: Dictionary, base: String) -> void:
    if data.has("theme"):
        var theme = data.theme
        if theme.has("palette"):
            for color_key in theme.palette:
                var color = Color(theme.palette[color_key])
                _emit_theme_color_loaded(color_key, color)
        if theme.has("highway_lane"):
            var tex = load(base.path_join(theme.highway_lane)) as Texture2D
            if tex:
                _emit_theme_texture_loaded("highway_lane", tex)

signal skin_loaded(entity: String, texture: Texture2D)
signal theme_color_loaded(key: String, color: Color)
signal theme_texture_loaded(key: String, texture: Texture2D)

func _emit_skin_loaded(entity: String, texture: Texture2D) -> void:
    skin_loaded.emit(entity, texture)

func _emit_theme_color_loaded(key: String, color: Color) -> void:
    theme_color_loaded.emit(key, color)

func _emit_theme_texture_loaded(key: String, texture: Texture2D) -> void:
    theme_texture_loaded.emit(key, texture)

func _revert_pack_content(content_type: String) -> void:
    match content_type:
        "music":
            AudioManager.revert_to_default_music()
        "skin":
            skin_loaded.emit("player", null)
            skin_loaded.emit("rotor", null)
            skin_loaded.emit("scav", null)
            skin_loaded.emit("drone", null)
        "theme":
            theme_color_loaded.emit("lane_color", Color(0.18, 0.18, 0.22))
            theme_color_loaded.emit("shoulder_color", Color(0.76, 0.64, 0.42))
            theme_color_loaded.emit("stripe_color", Color(1.0, 1.0, 0.8))
            theme_color_loaded.emit("guardrail_color", Color(1.0, 1.0, 0.8))

func get_active_pack_id(content_type: String) -> String:
    return active_packs.get(content_type, "")

func get_discovered_pack_ids() -> Array[String]:
    return discovered_packs.keys()

func get_pack_info(pack_id: String) -> Dictionary:
    if discovered_packs.has(pack_id):
        return discovered_packs[pack_id].data
    return {}
```

### 31.3: AudioManager Playlist Support

Add to `AudioManager.gd`:

```gdscript
var _playlist: Array[AudioStream] = []
var _playlist_index: int = 0
var _playlist_shuffle: bool = true
var _playlist_active: bool = false

func set_playlist(tracks: Array[AudioStream], shuffle: bool = true) -> void:
    _playlist = tracks.duplicate()
    _playlist_shuffle = shuffle
    _playlist_active = true
    _playlist_index = 0
    if _playlist_shuffle:
        _playlist.shuffle()
    if _playlist.size() > 0:
        play_music(_playlist[0])
    music_player.finished.connect(_on_music_finished)

func revert_to_default_music() -> void:
    _playlist_active = false
    music_player.finished.disconnect(_on_music_finished)
    play_synth_music()

func _on_music_finished() -> void:
    if not _playlist_active or _playlist.size() == 0:
        return
    _playlist_index = (_playlist_index + 1) % _playlist.size()
    if _playlist_index == 0 and _playlist_shuffle:
        _playlist.shuffle()
    play_music(_playlist[_playlist_index])
```

### 31.4: Skin Integration in Player and Enemies

**Interceptor.gd** — listen for skin changes:

```gdscript
func _ready() -> void:
    # ... existing code ...
    PackManager.skin_loaded.connect(_on_skin_loaded)
    _apply_current_skin()

func _on_skin_loaded(entity: String, texture: Texture2D) -> void:
    if entity == "player" and texture:
        sprite.texture = texture
    elif entity == "player" and texture == null:
        sprite.texture = load("res://assets/sprites/player/interceptor.svg")

func _apply_current_skin() -> void:
    var active = PackManager.get_active_pack_id("skin")
    if active != "":
        var info = PackManager.get_pack_info(active)
        if info.has("skins") and info.skins.has("player"):
            var base = PackManager.discovered_packs[active].folder
            var path = base.path_join(info.skins.player)
            var tex = load(path) as Texture2D
            if tex:
                sprite.texture = tex
```

**Enemy.gd** — same pattern in `_update_sprite()`:

```gdscript
func _update_sprite() -> void:
    var type_name = TYPE_NAMES[enemy_type]
    var active = PackManager.get_active_pack_id("skin")
    if active != "":
        var info = PackManager.get_pack_info(active)
        if info.has("skins") and info.skins.has("enemies") and info.skins.enemies.has(type_name):
            var base = PackManager.discovered_packs[active].folder
            var path = base.path_join(info.skins.enemies[type_name])
            var tex = load(path) as Texture2D
            if tex:
                sprite.texture = tex
                _scale_sprite()
                return
    # fallback to default
    match enemy_type:
        EnemyType.ROTOR:
            sprite.texture = load("res://assets/sprites/enemies/rotor.png") if ResourceLoader.exists("res://assets/sprites/enemies/rotor.png") else null
        EnemyType.SCAV:
            sprite.texture = load("res://assets/sprites/enemies/scav.png") if ResourceLoader.exists("res://assets/sprites/enemies/scav.png") else null
        EnemyType.DRONE:
            sprite.texture = load("res://assets/sprites/enemies/drone.png") if ResourceLoader.exists("res://assets/sprites/enemies/drone.png") else null
    _scale_sprite()
```

### 31.5: Theme Integration in Highway

**Highway.gd** — listen for theme color/texture changes:

```gdscript
var _theme_colors: Dictionary = {
    lane_color = Color(0.18, 0.18, 0.22),
    shoulder_color = Color(0.76, 0.64, 0.42),
    stripe_color = Color(1.0, 1.0, 0.8),
    guardrail_color = Color(1.0, 1.0, 0.8),
}

func _ready() -> void:
    PackManager.theme_color_loaded.connect(_on_theme_color_loaded)
    PackManager.theme_texture_loaded.connect(_on_theme_texture_loaded)
    for i in PREWARM_CHUNKS:
        _spawn_chunk(i)

func _on_theme_color_loaded(key: String, color: Color) -> void:
    if _theme_colors.has(key):
        _theme_colors[key] = color

func _on_theme_texture_loaded(key: String, texture: Texture2D) -> void:
    # Store for use in chunk generation (e.g., textured shoulders)
    pass

# In _generate_chunk_tiles(), replace hardcoded colors:
# Color(0.18, 0.18, 0.22) -> _theme_colors.lane_color
# Color(0.76, 0.64, 0.42) -> _theme_colors.shoulder_color
# Color(1.0, 1.0, 0.8)   -> _theme_colors.stripe_color
# Color(1.0, 1.0, 0.8)   -> _theme_colors.guardrail_color
```

### 31.6: Customize UI (`scenes/ui/Customize.tscn` + `Customize.gd`)

A new overlay accessible from the Garage via a "CUSTOMIZE" tab button.

**Layout:**
```
┌─────────────────────────────────────────┐
│  CUSTOMIZE                              │
│  ┌─────────┬──────────┬───────────┐     │
│  │ MUSIC   │  SKINS   │  THEMES   │     │
│  ├─────────┼──────────┼───────────┤     │
│  │ [None]  │ [None]   │ [None]    │     │
│  │ Synth   │ Neon     │ Desert    │     │
│  │ Metal   │ Classic  │ Night     │     │
│  │         │ Retro    │           │     │
│  ├─────────┴──────────┴───────────┤     │
│  │ [Preview]     [Activate]       │     │
│  │                                │     │
│  │ Drop packs in:                 │     │
│  │ user://packs/                  │     │
│  └────────────────────────────────┘     │
│  [BACK]                                 │
└─────────────────────────────────────────┘
```

**Customize.gd:**

```gdscript
extends CanvasLayer

signal back_to_garage_requested

@onready var tab_bar: TabBar = $Panel/TabBar
@onready var pack_list: ItemList = $Panel/PackList
@onready var activate_btn: Button = $Panel/ActivateButton
@onready var deactivate_btn: Button = $Panel/DeactivateButton
@onready var preview_btn: Button = $Panel/PreviewButton
@onready var pack_path_label: Label = $Panel/PackPathLabel
@onready var back_btn: Button = $Panel/BackButton

const CONTENT_TYPES = ["music", "skin", "theme"]

func _ready() -> void:
    back_btn.pressed.connect(_on_back_pressed)
    tab_bar.tab_changed.connect(_on_tab_changed)
    activate_btn.pressed.connect(_on_activate_pressed)
    deactivate_btn.pressed.connect(_on_deactivate_pressed)
    PackManager.pack_discovered.connect(_on_pack_discovered)
    PackManager.pack_validation_failed.connect(_on_pack_validation_failed)
    refresh()
    pack_path_label.text = "Drop packs in: " + PackManager.PACKS_DIR

func refresh() -> void:
    _on_tab_changed(tab_bar.current_tab)

func _on_tab_changed(tab_index: int) -> void:
    pack_list.clear()
    var content_type = CONTENT_TYPES[tab_index]
    var active = PackManager.get_active_pack_id(content_type)
    pack_list.add_item("[None] (Default)")
    if active == "":
        pack_list.select(0)
    for pack_id in PackManager.get_discovered_pack_ids():
        var info = PackManager.get_pack_info(pack_id)
        if info.has("content_types") and content_type in info.content_types:
            var display = info.name
            if info.has("author"):
                display += " by " + info.author
            var idx = pack_list.add_item(display)
            if pack_id == active:
                pack_list.select(idx)

func _on_activate_pressed() -> void:
    var tab = tab_bar.current_tab
    var content_type = CONTENT_TYPES[tab]
    var selected = pack_list.get_selected_items()
    if selected.size() == 0:
        PackManager.deactivate_pack(content_type)
        return
    var idx = selected[0]
    if idx == 0:
        PackManager.deactivate_pack(content_type)
        return
    var pack_id = PackManager.get_discovered_pack_ids()[idx - 1]
    PackManager.activate_pack(pack_id, content_type)
    refresh()

func _on_deactivate_pressed() -> void:
    var tab = tab_bar.current_tab
    var content_type = CONTENT_TYPES[tab]
    PackManager.deactivate_pack(content_type)
    pack_list.select(0)

func _on_pack_discovered(pack_id: String, name: String) -> void:
    refresh()

func _on_pack_validation_failed(pack_id: String, error: String) -> void:
    push_warning("Pack validation failed for '%s': %s" % [pack_id, error])

func _on_back_pressed() -> void:
    back_to_garage_requested.emit()
```

### 31.7: Save/Load Active Packs

Extend `GameManager.gd` save data:

```gdscript
func save_progress() -> void:
    var save_data = {
        credits = credits,
        high_score = high_score,
        upgrade_levels = upgrade_levels.duplicate(),
        active_packs = PackManager.active_packs.duplicate(),
    }
    var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
    if file:
        file.store_var(save_data)

func load_progress() -> void:
    var file = FileAccess.open("user://save.dat", FileAccess.READ)
    if file:
        var data = file.get_var()
        if data is Dictionary:
            # ... existing load logic ...
            if data.has("active_packs") and typeof(data.active_packs) == TYPE_DICTIONARY:
                for content_type in data.active_packs:
                    var pack_id = data.active_packs[content_type]
                    if pack_id != "" and PackManager.discovered_packs.has(pack_id):
                        PackManager.activate_pack(pack_id, content_type)
```

### 31.8: Sample Content Packs

Create two sample packs to demonstrate the system:

**Pack 1: `neon_nights`** — Synthwave aesthetic
```
user://packs/neon_nights/
├── pack.json
├── music/
│   └── neon_drive.ogg          # 80s synthwave loop (generated procedurally in code)
├── skins/
│   ├── player/interceptor.png  # Neon cyan car with glowing edges
│   ├── enemies/rotor.png       # Purple zombie biker
│   ├── enemies/scav.png        # Red rusted truck
│   └── enemies/drone.png       # Green alien saucer
└── theme/
    └── palette.json            # Dark purple/blue palette
```

**Pack 2: `dust_bowl`** — Mad Max aesthetic
```
user://packs/dust_bowl/
├── pack.json
├── music/
│   └── wasteland.ogg           # Industrial percussion loop
├── skins/
│   ├── player/interceptor.png  # Rusted muscle car
│   ├── enemies/rotor.png       # Skeleton biker
│   ├── enemies/scav.png        # Armored war rig
│   └── enemies/drone.png       # Scrap helicopter
└── theme/
    └── palette.json            # Orange/brown desert palette
```

### 31.9: Unit Tests

**Test file: `test/unit/test_pack_manager.gd`**

Tests to cover:
1. `_scan_packs()` finds no packs when directory is empty
2. `_load_manifest()` correctly parses a valid manifest
3. `_validate_manifest()` rejects missing `pack_id`
4. `_validate_manifest()` rejects invalid `pack_id` format (uppercase, spaces)
5. `_validate_manifest()` rejects missing `content_types`
6. `_validate_manifest()` rejects non-existent file references
7. `_validate_manifest()` rejects invalid hex colors
8. `activate_pack()` succeeds with valid pack
9. `activate_pack()` fails with non-existent pack_id
10. `activate_pack()` fails when pack exceeds size limit
11. `deactivate_pack()` reverts to defaults
12. `get_discovered_pack_ids()` returns correct list
13. `get_pack_info()` returns correct data for known pack
14. `get_active_pack_id()` returns active pack per content type
15. Music playlist shuffles when enabled
16. Music playlist advances to next track on finish
17. Skin loading emits `skin_loaded` signal with correct texture
18. Theme color loading emits `theme_color_loaded` with correct Color
19. Save/load roundtrip preserves active pack selections
20. Multiple packs can be active simultaneously (one per content type)

### 31.10: Implementation Order

| Step | Task | Effort |
|------|------|--------|
| 1 | Create `PackManager.gd` autoload with scan/validate/activate | Medium |
| 2 | Add playlist support to `AudioManager.gd` | Low |
| 3 | Integrate skin loading in `Interceptor.gd` and `Enemy.gd` | Low |
| 4 | Integrate theme colors in `Highway.gd` | Low |
| 5 | Create `Customize.tscn` + `Customize.gd` UI | Medium |
| 6 | Wire Customize tab into Garage navigation | Low |
| 7 | Extend save/load in `GameManager.gd` | Low |
| 8 | Create `neon_nights` sample pack assets | Medium |
| 9 | Create `dust_bowl` sample pack assets | Medium |
| 10 | Write 20 unit tests in `test_pack_manager.gd` | Medium |
| 11 | Integration testing: drop packs, verify activation | Low |

### 31.11: Security Considerations

- Pack files are loaded from `user://` sandbox — no access to system files
- JSON parsing uses Godot's built-in `JSON` class — no code execution
- Image/audio files loaded via `load()` — Godot's import pipeline handles validation
- No script files (`.gd`, `.gdc`, `.gde`) are loaded from packs
- Max pack size enforced at 50 MB
- `pack_id` restricted to alphanumeric + underscore — no path traversal

### 31.12: Future Extensions

- **Pack sharing**: Export packs as `.zip` with metadata for itch.io / community sharing
- **Pack ratings**: Community voting system for discovered packs
- **Animated skins**: Support for `AnimatedTexture2D` or `SpriteFrames` in skin packs
- **Dynamic themes**: Time-of-day themes (dawn, day, dusk, night) that shift palette automatically
- **SFX packs**: Replace procedural SFX with custom sound effects
- **Font packs**: Custom fonts for HUD text
- **Pack dependencies**: Packs that require another pack to be active
