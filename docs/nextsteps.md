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

---

## Phase 2: Deep Codebase Optimization (Completed May 2026)

A thorough codebase-wide audit of all 28 game scripts, 17 scenes, and 6 autoloads identified **15 issues** spanning performance, potential bugs, architecture, and maintainability. Below is the prioritized improvement plan.

---

### Issue 1 (High): ObjectPool Doesn't Call Lifecycle Methods — State Bleed Bug

**Files:** `scripts/autoload/ObjectPool.gd:116-147`, `scripts/scenes/weapons/Bullet.gd:73-82`

**Problem:** `ObjectPool.acquire()` never calls `on_pool_get()`, and `release()` never calls `on_pool_release()`. The `Bullet` class defines both methods (including resetting homing_strength, damage, scale, modulate) but they're never invoked. Reused bullets retain stale state from prior use (e.g., a missile bullet scaled to 1.5× retains that scale when reused as a normal bullet).

**Fix:** Add lifecycle method calls in both `acquire()` and `release()`:
```gdscript
# In acquire(), after setting visible/process_mode:
if item.has_method("on_pool_acquire"):
    item.on_pool_acquire()

# In release(), before appending to pool:
if node.has_method("on_pool_release"):
    node.on_pool_release()
```

---

### Issue 2 (High): Enemies Not Object-Pooled — GC Churn

**Files:** `scripts/scenes/world/Spawner.gd:39,75`, `scripts/scenes/enemies/Scav.gd:54`, `scripts/scenes/enemies/Drone.gd:44`

**Problem:** Enemy entities and their projectiles are created via `scene.instantiate()` and destroyed via `queue_free()` every time. Only player weapons use the `ObjectPool`. During high-intensity waves, this causes constant GC pressure.

**Fix:** Create pools for enemy types and enemy projectiles in `Game.gd:_ready()`. Modify `Spawner._spawn_enemy()` to use `ObjectPool.acquire()`/`release()`. Add `on_pool_get()`/`on_pool_release()` lifecycle methods to `Enemy.gd`.

---

### Issue 3 (Medium): ObjectPool.acquire() Uses O(n) Linear Scan

**Files:** `scripts/autoload/ObjectPool.gd:56-81,121-128`

**Problem:** `acquire()` iterates the entire pool from index 0 looking for an available item. With pool sizes of 50 (bullets) + 10 (mines) + 5 (EMP) + 20 (pickups), during heavy gameplay where many items are in use, this scans many unavailable items before finding an available one.

**Fix:** Change the pool to stack-based O(1) access — `pop_back()` on acquire, `push_back()` on release. Since pooled objects are identical, order doesn't matter:
```gdscript
func acquire(pool_name: String) -> Node:
    var pool: Array[Node] = _pools[pool_name]
    while pool.size() > 0:
        var item = pool.pop_back()
        if is_instance_valid(item):
            item.set_meta("_in_pool", false)
            item.visible = true
            item.process_mode = Node.PROCESS_MODE_INHERIT
            if item.has_method("on_pool_acquire"):
                item.on_pool_acquire()
            return item
    # fallback instantiate
```

---

### Issue 4 (Medium): Highway Creates Hundreds of Tiny Nodes Per Chunk

**Files:** `scripts/scenes/world/Highway.gd:120-319`

**Problem:** Each chunk creates individual `Polygon2D` per stripe, per decoration, per obstacle visual, plus `CollisionShape2D`/`CollisionPolygon2D` per obstacle, `Line2D` per guardrail, `Area2D` per zone. With CHUNK_HEIGHT=10 and CHUNK_WIDTH=14, each chunk can have 200+ nodes. With 8 active chunks, that's 1600+ nodes.

**Fix:** Use `MultiMeshInstance2D` for ALL stripe positions (same diamond mesh). Use single `MultiMeshInstance2D` for decorations. Create shared pool of obstacle `StaticBody2D` nodes. Merge collision shapes. Cache and reuse `Line2D` nodes for guardrails.

---

### Issue 5 (Medium): Enemy.load() Textures From Disk on Every Spawn

**Files:** `scripts/scenes/enemies/Enemy.gd:51-59`

**Problem:** `_update_sprite()` calls `load(resource_path)` every time `init()` is called. Although guarded by `ResourceLoader.exists()`, this performs disk-backed resource lookup on every enemy spawn.

**Fix:** Preload textures as class constants:
```gdscript
const ROTOR_TEXTURE = preload("res://assets/sprites/enemies/rotor.png")
const SCAV_TEXTURE = preload("res://assets/sprites/enemies/scav.png")
const DRONE_TEXTURE = preload("res://assets/sprites/enemies/drone.png")
```

---

### Issue 6 (Medium): Bullet Homing Refetches Enemy Group Every 0.25s Per Missile

**Files:** `scripts/scenes/weapons/Bullet.gd:35-56`

**Problem:** Each homing bullet calls `get_tree().get_nodes_in_group("enemy")` every `ENEMY_CACHE_INTERVAL` (0.25s). With 5 homing missiles in flight, 5 redundant group queries occur within the same window, each allocating a full enemy array.

**Fix:** Create a centralized enemy list updated once per frame (leverage `Spawner.active_enemies`). Or use `Area2D` overlap detection with configured radius instead of distance-checking all enemies.

---

### Issue 7 (Medium): Mine Explosion Uses Group Query Instead of Area2D Overlap

**Files:** `scripts/scenes/weapons/Mine.gd:35-41`

**Problem:** Mine queries ALL enemies via `get_tree().get_nodes_in_group("enemy")` then iterates all checking distance. Typically only 0-2 enemies are within the blast radius. The mine is already an `Area2D` with collision — it should use `get_overlapping_bodies()`.

**Fix:** Expand the `CollisionShape2D` radius on detonation and use `get_overlapping_bodies()` / `get_overlapping_areas()` instead of group query.

---

### Issue 8 (Medium): Signal Connections Accumulate on Scene Reload

**Files:** `scripts/scenes/Game.gd:58`, `scripts/scenes/ui/GameOver.gd:15-16`

**Problem:** `Game.gd` connects `GameManager.game_over` to `hud._on_game_over` every `_ready()` without an `is_connected` guard. `GameOver.gd` has the guard but `Game.gd` doesn't. On restart, duplicate connections fire `_on_game_over` multiple times.

**Fix:** Add guard:
```gdscript
if not GameManager.game_over.is_connected(hud._on_game_over):
    GameManager.game_over.connect(hud._on_game_over)
```

---

### Issue 9 (Medium/Latent): Enemy Destroyed Signal Never Disconnected

**Files:** `scripts/scenes/world/Spawner.gd:87`, `scripts/scenes/enemies/Enemy.gd:107-110`

**Problem:** Spawner connects to enemy `destroyed` signal but never disconnects. Currently safe because enemies `queue_free()` which auto-disconnects. But if enemy pooling is added (Issue 2), the signal persists across pool reuse, causing double-firing.

**Fix:** Disconnect in `_die()` before emitting, or use `CONNECT_ONE_SHOT` in Godot 4.

---

### Issue 10 (Medium): Score Popup Labels Constantly Created/Freed

**Files:** `scripts/scenes/Game.gd:128-138`

**Problem:** Every score popup creates a new `Label` node, adds to container, tweens, and frees. During rapid kills (clearing a wave of 9 enemies = 9 popups), many short-lived control nodes churn constantly.

**Fix:** Pre-create a pool of score popup labels (similar to ObjectPool). Track which labels are currently animating and which are available.

---

### Issue 11 (Low): Highway._pick_chunk_type() Duplicates Weights Dictionary Every Call

**Files:** `scripts/scenes/world/Highway.gd:87-106`

**Problem:** Every chunk type selection allocates a new `chunk_weights.duplicate()` dictionary, then modifies it. Happens every ~2 seconds during gameplay.

**Fix:** Compute weights inline without duplication — use local variables for each weight and do cumulative threshold checks.

---

### Issue 12 (Low): EMPBlast Calls has_meta() Every Frame

**Files:** `scripts/scenes/weapons/EMPBlast.gd:22-29`

**Problem:** EMP blast checks `has_meta("_pool_name")` every frame in `_process()`. String-keyed metadata lookup every frame for every active EMP.

**Fix:** Cache pool membership in a boolean variable during `init()`.

---

### Issue 13 (Low): GameManager _process() Runs When Not Playing

**Files:** `scripts/autoload/GameManager.gd:43-54`

**Problem:** Autoload `_process()` is invoked every frame even on the menu screen. Minor CPU waste.

**Fix:** Early return or toggle `process_mode` based on game state.

---

### Issue 14 (Low): Non-Deterministic Procedural Audio

**Files:** `scripts/autoload/AudioManager.gd:162,319,325`

**Problem:** Audio generators use `randf()` for noise generation at startup. Generated audio varies between runs, making testing difficult and creating inconsistent player experiences.

**Fix:** Seed `randi()` with a fixed value before procedural generation, or use hash-based deterministic noise.

---

### Issue 15 (Medium): Magic Numbers Scattered Across 10+ Files

**Files:** Multiple — `GameManager.gd:86`, `Spawner.gd:28,51-65`, `Highway.gd:91-95`, `Scav.gd:6`, `Drone.gd:6`, `WeatherSystem.gd:8-14`, etc.

**Problem:** Gameplay-critical numbers (tier thresholds, wave intervals, shoot intervals, weather parameters) are hardcoded as magic values across scripts. No single configuration point for game balance tuning. Zero `@export` variables — nothing is tunable from the inspector.

**Fix:** Create a `GameBalance` resource or extend `Constants.gd` to include ALL tunable parameters. Use `@export` where inspector tuning is useful.

---

### Priority Matrix

| # | Severity | Category | Effort | Impact |
|---|----------|----------|--------|--------|
| 1 | **High** | Bug (pool state bleed) | Low | High |
| 2 | **High** | Performance (enemy GC) | Medium | High |
| 3 | Medium | Performance (O(n) pool scan) | Low | Medium |
| 4 | Medium | Performance (1600+ nodes) | High | High |
| 5 | Medium | Performance (disk load) | Low | Medium |
| 6 | Medium | Performance (homing queries) | Medium | Medium |
| 7 | Medium | Performance (mine AoE) | Low | Medium |
| 8 | Medium | Bug (signal accumulation) | Low | Medium |
| 9 | Medium | Bug (latent — pooled enemies) | Low | Medium |
| 10 | Medium | Performance (popup labels) | Low | Medium |
| 11 | Low | Performance (dict duplicate) | Low | Low |
| 12 | Low | Performance (has_meta/frame) | Low | Low |
| 13 | Low | CPU waste (idle _process) | Low | Low |
| 14 | Low | Maintainability (audio RNG) | Low | Low |
| 15 | Medium | Maintainability (magic nums) | Medium | Medium |

**P0 (do now):** Issues 1, 2, 8 — Fix state bleed, enable enemy pooling, fix signal accumulation
**P1 (do next):** Issues 3, 5, 6, 7, 10, 15 — Optimize common paths, consolidate constants
**P2 (do later):** Issues 4, 9, 11, 12, 13, 14 — Major refactors and polish

---

## Phase 3: Post-Optimization Growth Plan (10 Improvements)

Following the completion of 15 P0/P1/P2 optimization issues, a comprehensive re-audit of the entire codebase identified these 10 high-value improvements spanning performance, rendering, audio, UX, and testing.

---

### Part 32: Replace Manual Rain Particles with GPUParticles2D

**Problem:** `WeatherSystem.gd:199-220` manages 200 rain drops as individual Polygon2D nodes, each updated every frame with position/visibility logic. This is an anti-pattern in Godot 4 — 200+ nodes for a simple particle effect.

**Findings:**
- `WeatherSystem.gd:199-220` — 200 `Polygon2D` nodes created, positioned, and toggled per-frame
- Each drop is 4 vertices + draw call overhead = 800+ extra draw calls for rain alone
- Manual `_process` loop over all 200 drops every frame to move and cull them
- No GPU acceleration — all particle work is on the CPU

**Plan:**
1. Create a `GPUParticles2D` scene with a simple line/sliver texture for rain
2. Configure emission shape (rectangle covering camera view), velocity (downward angle), lifetime, and amount (200)
3. Replace all rain drop generation in `WeatherSystem.gd` with the single GPUParticles2D node
4. Maintain existing weather type → particle amount/color mapping (light rain = 50, storm = 400)
5. Add a `CPUParticles2D` fallback for web/mobile export targets via config check
6. Preserve existing lightning/screen flash logic as-is

**Subtasks:**
```
32.1 — Create RainParticles.tscn with GPUParticles2D (line texture, 200 count, downward velocity)
32.2 — Add rain_color/rain_amount modulation based on weather type
32.3 — Integrate into WeatherSystem.gd replacing Polygon2D array
32.4 — Add CPUParticles2D fallback for low-end devices
32.5 — Remove old manual raindrop node allocation code
32.6 — Verify rain visual matches existing look; update tests
```

**Expected impact:** ~200 Polygon2D nodes eliminated per scene, ~0 CPU particle processing per frame, reduced draw calls.

---

### Part 33: Cache Highway Chunk Templates Per Type

**Problem:** Every chunk recycle in `Highway.gd:66-85` fully regenerates all child nodes (stripe MultiMesh, guardrails, decorations, collision areas). For 8 active chunks, this creates constant node allocation churn even though there are only 5 chunk types.

**Findings:**
- `Highway.gd:_spawn_chunk()` fully clears and rebuilds every recycle — even for the same chunk type as before
- 5 distinct `ChunkType` values exist but no caching by type
- Each rebuild creates MultiMeshInstance2D, Line2D, Area2D, StaticBody2D, and up to 60+ decoration Polygon2D nodes
- Recycling every ~3 seconds with 8 chunks = 2-3 full rebuilds per second

**Plan:**
1. Create a `ChunkCache` dictionary: keyed by `ChunkType`, values are pre-built Node2D templates
2. On first encounter of a given ChunkType, build and store the template
3. On subsequent recycles, clone the cached template with `duplicate()` (much cheaper than `_generate_chunk_tiles()`)
4. Clone cost vs regenerate cost: `duplicate()` is ~5-10x faster than full procedural generation
5. Hold 3 chunks ahead per type to absorb burst traffic
6. Keep pre-generated template pool warm across difficulty tier transitions (weights change but chunk types don't)

**Subtasks:**
```
33.1 — Add ChunkCache dictionary to Highway.gd
33.2 — Split _spawn_chunk into _build_template + _clone_template
33.3 — Cache template after first generation per type
33.4 — Verify chunk type-specific variations (debris, bridge gaps) are preserved in templates
33.5 — Add cache hit/miss debug logging (optional)
33.6 — Test with all 5 chunk types across tier transitions
```

**Expected impact:** 80-90% reduction in chunk node creation; elimination of procedural generation cost on recycle.

---

### Part 34: Switch Renderer to Forward+ and Add Post-Processing

**Problem:** `project.godot:520` uses `gl_compatibility` (OpenGL 3.0 / WebGL 2.0) which lacks glow, bloom, tonemapping, and color grading. A neon post-apocalyptic game needs these for visual impact.

**Findings:**
- `project.godot:520` — `rendering/renderer/rendering_method=gl_compatibility`
- No `WorldEnvironment` node exists anywhere in the game
- No post-processing: no glow/bloom on neon elements, no color grading, no vignette
- Enemy sprites, highway lanes, and UI all render flat — visual presentation is muted for the intended aesthetic
- `gl_compatibility` is only required for web exports; desktop can use `forward_plus`

**Plan:**
1. Add a second export preset for desktop: `forward_plus` renderer, keep `gl_compatibility` for web
2. Add `WorldEnvironment` node to `Game.tscn` with environment tweaks:
   - Glow (bloom) intensity 0.3 on an "emissive" layer for neon elements
   - Tonemap mode: Filmic or Reinhard for high dynamic range
   - Ambient light: dim cool tone to match post-apocalyptic mood
3. Add per-scene `WorldEnvironment` for Main menu, Game, and Garage (different ambience)
4. Add subtle vignette via `Environment.tonemap_vignette`
5. Verify 60 FPS target still holds — `forward_plus` 2D is negligible overhead

**Subtasks:**
```
34.1 — Add desktop export preset with rendering_method=forward_plus
34.2 — Create environment.tres base resource (tone map, glow, ambient)
34.3 — Add WorldEnvironment node to Game.tscn
34.4 — Add WorldEnvironment to Main.tscn (darker, no glow)
34.5 — Add WorldEnvironment to Garage.tscn (warm, low glow)
34.6 — Tune glow layer to affect only neon elements (lane stripes, boost, enemy eyes)
34.7 — Verify FPS impact < 2% on medium hardware
```

**Expected impact:** Dramatic visual improvement — neon elements pop, scenes feel atmospheric. Negligible performance cost (forward_plus in 2D is very lightweight).

---

### Part 35: Enemy Inheritance via `class_name` Instead of String Path

**Problem:** `Drone.gd:1`, `Scav.gd:1`, `Rotor.gd:1` use `extends "res://scripts/scenes/enemies/Enemy.gd"` — a fragile string path that breaks silently if the file is renamed or moved.

**Findings:**
- All 3 enemy subtypes use a string literal for the base class
- Base `Enemy.gd` has no `class_name` declaration
- Renaming/moving `Enemy.gd` would cause all 3 subclass scripts to silently fail to load
- Godot 4's recommended approach is `class_name EnemyBase` + `extends EnemyBase`
- String path extends also prevents GDScript from resolving autocomplete and type hints for the base class

**Plan:**
1. Add `class_name EnemyBase` at the top of `scripts/scenes/enemies/Enemy.gd`
2. Change all 3 subclass files: `extends "res://..."` → `extends EnemyBase`
3. Update any `load("res://...Enemy.gd").` references to use the class name directly
4. Verify all enemy subtypes still work (spawn, AI, take damage, die)
5. Run full test suite

**Subtasks:**
```
35.1 — Add class_name EnemyBase to Enemy.gd
35.2 — Update Drone.gd extends directive
35.3 — Update Scav.gd extends directive
35.4 — Update Rotor.gd extends directive
35.5 — Search for load("...Enemy.gd") references and update
35.6 — Run full test suite, fix any type resolution issues
```

**Expected impact:** Robust inheritance chain, proper type hints/autocomplete in all subclasses, safe to rename/move base file.

---

### Part 36: Implement Pause Menu

**Problem:** `GameManager.gd:12` defines `GameState.PAUSED` but it is never set anywhere. There is no way to pause the game during gameplay — a critical missing UX feature.

**Findings:**
- `GameState.PAUSED = 2` defined at `GameManager.gd:12` — zero references outside test code
- `GameState.GAME_OVER = 3` in same enum works correctly
- No "Pause" action in `project.godot` input map
- No pause overlay panel or menu in any scene
- `get_tree().paused = true` is used in `GameManager.gd:140` for garage transition (global pause)
- Tests verify PAUSED enum value but nothing tests the actual pause behavior

**Plan:**
1. Add "pause" input action in `project.godot` (ESC key, Start button on gamepad)
2. Create `PauseMenu.tscn` — CanvasLayer with Panel, Resume/Options/Quit buttons and a "PAUSED" title label
3. Add to `Game.tscn` as hidden by default
4. In `Game.gd` or `GameManager.gd`: on pause action, toggle `GameState.PAUSED` and show/hide overlay
5. On pause: `get_tree().paused = true` only during gameplay (not on menu/garage)
6. Resume: restore state, hide overlay, `get_tree().paused = false`
7. Options button opens the existing `Options.gd` scene on top
8. Quit button shows confirmation dialog → Main menu

**Subtasks:**
```
36.1 — Add "pause" input action to project.godot (ESC / Start)
36.2 — Create PauseMenu.tscn with overlay, buttons, title
36.3 — Create PauseMenu.gd with signal connections
36.4 — Integrate into Game.tscn + wire input handling in Game.gd
36.5 — Test pause/unpause cycle with all game systems paused correctly
36.6 — Verify enemies, bullets, highway, weather, and score timer all freeze
36.7 — Add confirmation dialog for quit action
36.8 — Run full test suite (ensure pause interaction with existing tests)
```

**Expected impact:** Complete pause functionality — players can pause, resume, adjust settings, or quit mid-run.

---

### Part 37: Input Remapping UI

**Problem:** All input bindings are hardcoded in `project.godot` and `GameManager.gd:144-192`. Players cannot rebind controls, which is a critical accessibility and UX gap.

**Findings:**
- `project.godot:464-510` defines 10 input actions with hardcoded keys/buttons
- `GameManager.gd:144-192` adds programmatic binds every startup (arrow keys, E, M, Space)
- No UI for rebinding — no way to customize for AZERTY keyboards, left-handed play, or controller preference
- `GameManager.gd:146-158` uses potentially deprecated joypad constants
- `InputMap.action_add_event()` is never used anywhere

**Plan:**
1. Expand Options.gd scene with an "Input" tab showing all 10 actions in a scrollable list
2. Each row: action name label + current key/button label + "Change" button
3. On "Change" click: enter listening mode, capture next keypress/button, display confirmation
4. Store bindings per-device (keyboard separate from gamepad) using `ConfigFile`
5. Apply on game start via `InputMap.load_from_project_settings()` + custom overrides
6. Add "Reset to Defaults" button
7. Update `GameManager.gd` programmatic bind logic to check for conflicts

**Subtasks:**
```
37.1 — Design input rebinding UI layout (scrollable list, action rows)
37.2 — Create InputRemapping.gd script with listen/rebind logic
37.3 — Create InputMappingRow.tscn (label + current + change + clear)
37.4 — Add Input tab to Options.gd / Options.tscn
37.5 — Implement save/load for custom bindings via ConfigFile
37.6 — Implement "Reset to Defaults" using project.godot defaults
37.7 — Update GameManager.gd programmatic binding to respect saved overrides
37.8 — Verify all 10 actions are rebindable and persist across restarts
37.9 — Test edge cases: unbind all, same key for two actions, empty bind
```

**Expected impact:** Full input remapping support — accessibility compliant, AZERTY-compatible, left-handed, custom controller layouts.

---

### Part 38: Camera Shake System

**Problem:** There is no camera shake on explosions, collisions, or boost activation. The game feels flat during combat — no visceral feedback for high-impact events.

**Findings:**
- `Camera2D` is a child of `Interceptor.tscn` at `$Camera2D` with a fixed Y offset
- No `offset` manipulation, no shake decay, no `PerlinNoise` usage in the project
- `Mine.gd:_explode()` has no visual feedback beyond a temporary Polygon2D circle
- `Enemy.gd:_die()` plays sound but no screen feedback
- `Interceptor.gd:_take_damage()` changes modulate but no camera shake

**Plan:**
1. Create `CameraShake.gd` autoload or component with a `shake(power, duration)` method
2. Implement using Camera2D offset with exponential decay (aka "trauma" pattern):
   - `offset = Vector2(cos(randf() * TAU), sin(randf() * TAU)) * trauma * max_offset`
   - `trauma = max(0, trauma - decay * delta)`
3. Connect shake calls from: `Enemy._die()` (medium), `Mine._explode()` (strong), `DroneBomb._detonate()` (very strong), `Interceptor._take_damage()` (medium), `BOOST` activation (weak)
4. Vary shake power by event proximity to player (closer = stronger)
5. Optionally use `PerlinNoise` for organic shake pattern instead of pure random

**Subtasks:**
```
38.1 — Create CameraShake.gd with trauma/decay pattern
38.2 — Implement shake(power, duration, max_offset) method
38.3 — Wire into Camera2D via signal or direct reference
38.4 — Add proximity-based intensity calculation
38.5 — Add shake calls to: Enemy._die, Mine._explode, DroneBomb._detonate, Interceptor._take_damage, BOOST
38.6 — Test shake does not cause motion sickness (cap max offset to 8px)
38.7 — Add optional toggle in Options: "Screen Shake"
```

**Expected impact:** Significantly improved combat feel — every explosion and hit registers viscerally through the camera.

---

### Part 39: Audio Overhaul — Higher Quality, Longer Music, FX Bus

**Problem:** Procedural audio at 8000-11025 Hz / 8-bit sounds very low-fidelity. Music loops are only 4-6.4 seconds long. No audio bus effects (reverb, compression).

**Findings:**
- `AudioManager.gd` — all `_generate_*` methods use 8000-11025 Hz, 8-bit PCM
- Music: 4 seconds (menu) and 6.4 seconds (game) — extremely short and repetitive
- No audio bus effects in `project.godot` audio section
- `_find_lowest_priority_player()` does not actually respect priority despite `_priority` parameter
- No pitch randomization on repeated sounds — same waveform plays identically each time

**Plan:**
1. Increase sample rate to 22050 Hz across all generators (balance quality vs memory)
2. Use 16-bit PCM for all procedural streams (8-bit has audible quantization noise)
3. Generate longer music: 16-32 second loops with chord progression, bridge, and fills
4. Add `compress` effect to Master bus (light 3:1 ratio, -6dB threshold)
5. Add `reverb` effect to SFX bus (room 0.3, damp 0.5, wet 0.2)
6. Fix `_find_lowest_priority_player()` to actually respect priority parameter
7. Add `pitch_scale = randf_range(0.9, 1.1)` randomization on SFX playback

**Subtasks:**
```
39.1 — Update all _generate_* sample rate to 22050 Hz and to 16-bit
39.2 — Rewrite _generate_menu_music() for 16-32 second loop (add chord variations)
39.3 — Rewrite _generate_game_music() for 16-32 second loop (add fills, breakdown section)
39.4 — Add Reverb effect to SFX bus in AudioManager._ready() or project.godot
39.5 — Add Compression to Master bus
39.6 — Fix _find_lowest_priority_player to evaluate priority correctly
39.7 — Add pitch_scale randomization to all SFX playback
39.8 — Test: verify music loops seamlessly, audio quality improved, no crackling
```

**Expected impact:** Dramatically improved audio quality — music no longer feels like a 4-second loop, SFX have spatial presence via reverb, no more audio starvation.

---

### Part 40: Integration, Stress, and Performance Tests

**Problem:** All 26 test files are unit tests with mocked dependencies. There are no integration tests (multiple systems interacting), stress tests (extreme entity counts), or performance benchmarks.

**Findings:**
- 122 tests across 26 files — all unit tests with isolated components
- No test spawns enemies + fires weapons + verifies score tracking end-to-end
- No test measures FPS under load (50+ enemies, 200+ bullets)
- `run_tests.gd` uses manually configured batches rather than glob-based discovery
- `test_helper.gd:24-28` mock is incomplete — uses `set()` for methods instead of actual method definitions

**Plan:**
1. **Integration tests (3-5 new files):**
   - "Spawner + Interceptor combat loop": Spawn enemy, fire weapon from player, enemy takes damage, enemy dies, score increases
   - "Highway + player movement": Player vehicles moves through 10 highway chunks, verify chunk recycle and position tracking
   - "Weather + player interaction": Rain starts, player enters bridge zone, verify both systems active simultaneously
2. **Stress tests (1 file):**
   - Spawn 30 enemies, fire 100 bullets, verify no crash and FPS > 30 (simulated)
   - Pool exhaustion: acquire 200 items from ObjectPool, verify no null returns
3. **Performance benchmarks (1 file):**
   - Time chunk generation: average of 10 generation cycles, report ms
   - Time bullet pool acquire/release: 1000 cycle average
4. **Cleanup `run_tests.gd`** to auto-discover test files using `-gdir` instead of hardcoded lists
5. **Fix `test_helper.gd`** mock — replace `set()` with actual `MockPlayer.gd` script

**Subtasks:**
```
40.1 — Create test_integration_combat.gd (spawn → fight → score → die)
40.2 — Create test_integration_highway.gd (chunk generation, recycle, player movement)
40.3 — Create test_stress.gd (30 enemies + 100 bullets + weather, verify stability)
40.4 — Create test_performance.gd (benchmark pool operations, chunk generation)
40.5 — Fix test_helper.gd MockPlayer with proper method definitions
40.6 — Convert run_tests.gd to glob-based test discovery
40.7 — Add target FPS assertions to stress tests
40.8 — Run full suite: verify 122 unit + new integration/stress tests all pass
```

**Expected impact:** End-to-end coverage across system boundaries; performance regression detection; simpler test runner maintenance.

---

### Part 41: Code Quality Deep Cleanup

**Problem:** Multiple long-standing code quality issues remain: fragile string key usage, dead code, utility files cluttering root, and deprecated pattern usage.

**Findings:**
- `set_meta`/`get_meta` for pool state in `ObjectPool.gd` — slower than typed properties, not refactorable
- `upgrade_levels` dictionary with string keys throughout `GameManager.gd`, `Garage.gd` — typo-prone
- Dead code: `test_input.gd` at root, `check_bg.py`, `remove_bg.py`, other dev utilities
- `default_env.tres` exists but is unused
- `WEAPON_TYPES` array in Interceptor + `WEAPON_COLORS` array in HUD must match manually (no shared def)
- `_lane_to_x()` in `Interceptor.gd` recalculates from LANE_WIDTH instead of using `Constants.LANE_POSITIONS`
- `randi()`, `randf()` in Highway/Spawner use global RNG with no seed for replay determinism
- Two test files use `extends "res://addons/gut/test.gd"` instead of `extends GutTest`

**Plan:**
1. Replace `set_meta`/`get_meta` in ObjectPool with an inner `PoolItem` class or embedded Dictionary field
2. Add `enum UpgradeType { SPEED, HANDLING, ARMOR, FIRE_RATE, MISSILE_DAMAGE, MINE_COUNT, EMP_AMMO }` and use typed keys
3. Move dev utility scripts to `tools/` directory, remove dead `test_input.gd`
4. Remove unused `default_env.tres` or connect it
5. Create shared `WeaponData` resource: array of `{type: String, color: Color, icon: Texture2D}` used by both Interceptor and HUD
6. Update `Interceptor._lane_to_x()` to use `Constants.LANE_POSITIONS`
7. Add seeded `RandomNumberGenerator` instance to Highway and Spawner for replay determinism
8. Fix the 2 test files to use `extends GutTest` for consistency

**Subtasks:**
```
41.1 — Refactor ObjectPool.gd away from set_meta/get_meta into typed properties
41.2 — Add UpgradeType enum, refactor all string key usage in GameManager/Garage
41.3 — Move dev scripts to tools/, remove dead code /test_input.gd
41.4 — Remove or wire default_env.tres
41.5 — Create shared WeaponData resource, update Interceptor + HUD to use it
41.6 — Fix Interceptor._lane_to_x() to reference Constants.LANE_POSITIONS
41.7 — Add seeded RNG to Highway and Spawner for deterministic replay
41.8 — Fix 2 test files: extends "res://addons/..." → extends GutTest
41.9 — Run full test suite, verify no regressions
```

**Expected impact:** Type-safe code, refactorable string keys gone, cleaner project root, deterministic replays, consistent test bases.

---

### Priority Matrix

| Part | Title | Effort | Impact | Priority |
|------|-------|--------|--------|----------|
| 32 | GPUParticles2D for Rain | Low | Medium | P1 |
| 33 | Cache Highway Chunk Templates | Medium | High | P0 |
| 34 | Forward+ Renderer + Post-Processing | Low | High | P1 |
| 35 | class_name Enemy Inheritance | Low | Medium | P1 |
| 36 | Pause Menu | Medium | High | P0 |
| 37 | Input Remapping UI | High | High | P2 |
| 38 | Camera Shake System | Low | Medium | P1 |
| 39 | Audio Overhaul (quality, length, FX bus) | Medium | Medium | P2 |
| 40 | Integration + Stress Tests | Medium | High | P1 |
| 41 | Code Quality Deep Cleanup | Medium | Medium | P2 |

**P0 (do now):** Parts 33, 36 — Highway chunk caching eliminates major node churn; Pause menu is critical UX gap.
**P1 (do next):** Parts 32, 34, 35, 38, 40 — Visual + audio polish, type safety, test coverage expansion.
**P2 (do later):** Parts 37, 39, 41 — Input remapping, audio overhaul complex refactors, deep cleanup.

---

## Phase 4: Deep Codebase Audit — 10 New Improvement Opportunities

Following completion of Phase 3, a comprehensive re-audit of all 36+ game scripts, 7 autoloads, and full test suite identified these 10 remaining high-value improvements spanning performance, gameplay depth, code quality, UX, and design-doc completion.

---

### Part 42: Replace Polling Enemy List with Signal-Based Live List

**Problem:** `GameManager.gd:56-59` calls `get_tree().get_nodes_in_group("enemy")` every 0.25s, allocating and discarding a full array every time. This runs even when no homing bullets are active and does redundant work when multiple calls happen in the same frame.

**Findings:**
- `GameManager.gd:56-59` — `enemy_list = get_tree().get_nodes_in_group("enemy")` every 250ms regardless of combat state
- `Spawner.gd:92` — Connects `enemy.destroyed` signal but never manages a live list itself
- `active_enemies` in Spawner (line 8) already tracks all spawned enemies but is not shared with GameManager
- `Bullet.gd:37` — Copies `GameManager.enemy_list` reference each cache interval per homing bullet
- No null check on `nearest` return before accessing `nearest.global_position` in `Bullet.gd:40`

**Plan:**
1. Remove `_enemy_list_timer` and group query from `GameManager._process()`
2. Add `enemy_spawned` signal to `Spawner.gd`; emit when `_spawn_enemy()` completes
3. Add `enemy_destroyed` signal to `Spawner.gd`; reuse existing `_on_enemy_destroyed()` path
4. `GameManager` listens to both signals and maintains enemy list as a live array
5. `Bullet.gd:_find_nearest()` — add null guard before `nearest.global_position` access
6. Move enemy list from GameManager to a dedicated `CombatRegistry` autoload or keep in GameManager but decouple from timer

**Subtasks:**
```
42.1 — Add enemy_spawned signal to Spawner.gd
42.2 — Wire Spawner.enemy_spawned → GameManager live list append
42.3 — Wire Spawner._on_enemy_destroyed → GameManager live list remove
42.4 — Remove _enemy_list_timer and group query from GameManager._process()
42.5 — Add null guard to Bullet.gd:38-41 before nearest.global_position
42.6 — Update all test references (test_bullet.gd, test_game_manager.gd, test_spawner.gd)
42.7 — Verify homing missile behavior unchanged with signal-driven list
```

**Expected impact:** Eliminates periodic full tree traversal, reduces allocations during combat by ~4 arrays/sec (16 arrays in flight at any time), fixes latent null-pointer crash in homing logic.

---

### Part 43: Add Parallax Background Layers

**Problem:** No scrolling background layers exist beyond a solid dark color from `game_env.tres` ambient light. The design doc (`docs/design.md:129-133`) specifies 3 parallax layers: near (guardrails/signs), mid (ruined buildings), far (mountains/skybeams). The world feels flat and empty during gameplay.

**Findings:**
- `assets/environments/` — Contains only `game_env.tres` (Environment resource)
- No background Sprite2D, ParallaxBackground, or ParallaxLayer nodes in `Game.tscn` world tree
- `project.godot` — No background textures imported
- `Game.gd:_ready()` (line 23) — `world.scale = Vector2(1.0, 0.5)` squashes world but background could be unscaled
- Game feels visually shallow; scrolling background is the single biggest visual polish gap

**Plan:**
1. Create `assets/textures/backgrounds/` directory with 3 gradient/stripe textures for far mountains, mid ruins silhouette, near guardrails
2. Add `ParallaxBackground` node as child of `$World` in `Game.tscn` but before the y-scaled world contents (or outside the world Node2D)
3. Far layer: `ParallaxLayer` with `motion_scale = Vector2(0.1, 0.0)` — mountain silhouettes, slow horizontal parallax
4. Mid layer: `motion_scale = Vector2(0.3, 0.0)` — ruined building silhouettes, moderate tracking
5. Near layer: `motion_scale = Vector2(0.6, 0.0)` — guardrail/sign silhouettes, faster movement
6. All layers scroll vertically to match highway movement direction (downward = forward)
7. Tint layers with `self_modulate` to match game_env ambient lighting

**Subtasks:**
```
43.1 — Create 3 background texture assets (far mountains, mid ruins, near guardrails)
43.2 — Add ParallaxBackground node to Game.tscn as sibling of $World
43.3 — Configure ParallaxLayer × 3 with motion scales and textures
43.4 — Apply shader/material tint to match game_env ambient light color
43.5 — Verify 60 FPS with all 3 layers active (negligible overhead)
43.6 — Optionally add parallax to Main menu background too
```

**Expected impact:** Dramatic visual depth — world goes from flat dark void to atmospheric three-plane landscape. Design doc feature completed.

---

### Part 44: Implement Civilian Vehicles

**Problem:** `ScoreManager.gd:9` defines `civilian_protected = 500`, and `register_civilian_protected()` (lines 33-35) is fully implemented, but no civilian vehicle scene, spawn logic, or collision handling exists. The design doc (`docs/design.md:87-91`) specifies: "+500 bonus for protecting civilians, -1 HP for hitting them."

**Findings:**
- `ScoreManager.gd:9` — `civilian_protected = 500` defined but never triggered
- `ScoreManager.gd:33-35` — `register_civilian_protected()` is dead code
- `Constants.gd` — No civilian constants (speed, HP, spawn interval, etc.)
- `Spawner.gd` — No civilian spawn logic in `_get_wave_composition()` or `_process()`
- No civilian TSCN scene exists in the project
- Pickup `"repair"` restores 1 HP when collected — but civilian collision does nothing

**Plan:**
1. Create `Civilian.tscn` — CharacterBody2D with lower speed, distinctive sprite (civilian car), `take_damage()` method
2. Create `scripts/scenes/enemies/Civilian.gd` — Passive driving behavior, flee or stay in lane, no combat
3. Add `CIVILIAN_SPAWN_CHANCE`, `CIVILIAN_BONUS`, `CIVILIAN_HIT_PENALTY` to Constants.gd
4. Integrate into `Spawner.gd`: spawn civilians periodically alongside enemies with low probability
5. Player collision with civilian: call `Player.take_damage(1)` + remove civilian + display "+500 PROTECTED!" or "CIVILIAN HIT -1"
6. If civilian exits screen safely: call `ScoreManager.register_civilian_protected()` and emit score popup
7. Add `Civilian`s to ObjectPool for recycling

**Subtasks:**
```
44.1 — Create Civilian.tscn + Civilian.gd (simple passive vehicle, vulnerable)
44.2 — Add civilian constants to Constants.gd (SPEED, SPAWN_CHANCE, SCORE_VALUES)
44.3 — Integrate into Spawner.gd _get_wave_composition or _drop_pickup odds
44.4 — Wire player-civilian collision → take_damage + score popup
44.5 — Wire safe exit → register_civilian_protected → "+500 PROTECTED!" popup
44.6 — Add civilian pool to Game.gd ObjectPool setup
44.7 — Test: civilian spawns, moves, can be hit/protected, score reflects correctly
```

**Expected impact:** Design doc feature completed. Adds moral decision to combat — avoid hitting civilians for bonus, risk damage for protecting them.

---

### Part 45: Implement Boss Encounters

**Problem:** Design doc (`docs/design.md:144`) specifies boss waves every 3000 points — "giant Scav war-rig or alien carrier" with multiple HP segments. No boss logic, scenes, or Spawner integration exists despite `GameManager.gd` having latent boss check code.

**Findings:**
- `GameManager.gd:65-66` — `_check_boss_wave()` originally had a `pass` body (dead code removed in Phase 2 cleanups)
- `Spawner.gd:_get_wave_composition()` (lines 51-66) — No boss wave entries at any tier
- No boss scene files exist in `scenes/enemies/`
- `Constants.gd` — No boss constants (HP, speed, attack interval, score reward)
- Design doc: boss every 3000 pts, multi-HP, special attacks
- `Enemy.gd` stun system and multiple HP mechanics already exist and can be reused

**Plan:**
1. Create `BossWarRig.tscn` and `scripts/scenes/enemies/BossWarRig.gd` — large sprite, 5x HP, 2 attack patterns (ram + spawn minions)
2. Create `BossAlienCarrier.tscn` and `scripts/scenes/enemies/BossAlienCarrier.gd` — hover boss, drops drone swarms, beam attack
3. Add boss constants to Constants.gd (BOSS_INTERVAL, BOSS_HP, BOSS_SCORE, attack cooldowns)
4. Extend `Spawner.gd:_get_wave_composition()`: when `GameManager.score >= 3000 * boss_count`, spawn boss instead of normal wave
5. Spawner emits `boss_spawned` signal; GameManager listens for boss state
6. Boss death: big explosion, large score award (+500-1000), camera shake (very strong)
7. Add boss scenes to ObjectPool

**Subtasks:**
```
45.1 — Create BossWarRig.tscn + BossWarRig.gd (ram attack, spawn scavs, 5x HP)
45.2 — Create BossAlienCarrier.tscn + BossAlienCarrier.gd (beam attack, spawn drones)
45.3 — Add boss constants to Constants.gd
45.4 — Update Spawner.gd: check score threshold, spawn boss wave, emit signal
45.5 — Wire boss_spawned → GameManager boss state tracking
45.6 — Add boss death sequence (big explosion, score award, camera shake)
45.7 — Add boss scenes to ObjectPool
45.8 — Test: boss spawns at 3000 pts, deals damage, dies, score awarded
```

**Expected impact:** Design doc feature completed. Adds climactic gameplay moments every 3000 points, breaks up endless-runner monotony.

---

### Part 46: Add Floating Combat Text / Damage Numbers

**Problem:** When the player takes damage, enemies are hit, or weapons connect, there is no numeric feedback beyond health bar changes. The existing score popup system (`Game.gd:_on_score_popped()` lines 204-215) only handles scoring events, not combat feedback.

**Findings:**
- `Game.gd:204-215` — Score popups exist but only for score events, not damage
- `Interceptor.gd:218-226` — `take_damage()` flashes sprite red + camera shake, no damage number
- `Bullet.gd:56-66` — `_on_body_entered()` calls `take_damage()` but displays nothing
- `Enemy.gd:107-118` — `_die()` emits destroyed signal but no damage number appears
- No "DAMAGE" or "MISS" or "CRIT" floating text anywhere
- Popup label pool already exists (`Game.gd:186-202`) and can be reused

**Plan:**
1. Extend `Game.gd:_get_popup_label()` → `_show_floating_text(pos, text, color, size)` that reuses the popup pool
2. In `Interceptor.take_damage()`: call `_show_floating_text()` with red "-1" text
3. In `Bullet._on_body_entered()`: call `_show_floating_text()` with yellow damage number at impact position
4. In `Enemy._die()`: call `_show_floating_text()` with orange final hit marker
5. Add critical hit color variation (white for 3+ damage, red for 1, orange for 2)
6. Add font size scaling: larger numbers for bigger hits
7. If damage > 3, add "CRIT!" label alongside number

**Subtasks:**
```
46.1 — Create _show_floating_text() helper in Game.gd sharing popup label pool
46.2 — Wire Interceptor.take_damage() → floating red "-1" at player position
46.3 — Wire Bullet._on_body_entered() → floating yellow damage at hit position
46.4 — Wire Enemy._die() → floating orange "+" finisher marker
46.5 — Add color/size scaling by damage amount (1=red/18px, 3+=white/24px)
46.6 — Add "CRIT!" label for hits dealing 3+ damage
46.7 — Verify popup pool does not leak or overflow during rapid combat
```

**Expected impact:** Immediate visual feedback for all combat events. Every bullet hit and damage instance registers as clearly as score events.

---

### Part 47: Add Screen Transition Effects

**Problem:** Scene changes use `get_tree().change_scene_to_file()` directly (Main.gd:28, Game.gd:96) with zero transition. The game snaps instantly between menu, gameplay, and game over screens — a jarring UX gap.

**Findings:**
- `Main.gd:28` — `get_tree().change_scene_to_file("res://scenes/Game.tscn")` — snap transition
- `Game.gd:96` — `get_tree().change_scene_to_file("res://scenes/Main.tscn")` — snap transition
- `Game.gd:92-93` — `get_tree().reload_current_scene()` — instant reload, no fade
- No `SceneTreeTimer` usage for transition delays
- No `ColorRect` fade overlay anywhere in the project
- TransitionController or TransitionLayer pattern is standard in Godot 4 games

**Plan:**
1. Create `TransitionLayer.gd` autoload — a CanvasLayer with full-screen ColorRect that fades alpha
2. Expose methods: `fade_to_black(duration: float)`, `fade_from_black(duration: float)`
3. On scene change: call `fade_to_black()`, wait for completion via `await`, then `change_scene_to_file()`, then `fade_from_black()`
4. Replace all direct `change_scene_to_file()` calls with `TransitionLayer.change_scene()` wrapper
5. Add `reload_scene_with_transition()` for restart (fade → reload → fade)
6. Create separate tween for fade overlay — independent of `get_tree().paused` state (use `process_mode = PROCESS_MODE_ALWAYS`)

**Subtasks:**
```
47.1 — Create TransitionLayer.gd autoload (ColorRect overlay, cross-scene persistence)
47.2 — Implement fade_to_black(duration) and fade_from_black(duration) with tweens
47.3 — Create change_scene(path) wrapper: fade → await → change_scene → fade
47.4 — Create reload_scene() wrapper with fade
47.5 — Replace all change_scene_to_file calls in Main.gd, Game.gd
47.6 — Replace reload_current_scene calls in Game.gd
47.7 — Test: all scene transitions show smooth fade, no snap, no crash
```

**Expected impact:** Professional polish — every transition is smooth and visually pleasing. No more jarring scene snaps.

---

### Part 48: Add Gamepad Rumble Support

**Problem:** Camera shake on explosions/damage/boost (Part 38) provides visual feedback but no tactile feedback. Godot 4's `Input.start_joy_vibration()` is never called anywhere in the project.

**Findings:**
- `Interceptor.gd:226` — `CameraShake.shake(0.4, 0.2, 5.0)` on damage — no rumble
- `Interceptor.gd:211` — `CameraShake.shake(0.2, 0.15, 3.0)` on boost — no rumble
- `Enemy.gd:_die()` — `CameraShake.shake(0.3, 0.2, 4.0)` — no rumble
- `Mine.gd:_explode()` — `CameraShake.shake(0.6, 0.3, 8.0)` — no rumble
- `DroneBomb.gd:_detonate()` — `CameraShake.shake(0.8, 0.4, 10.0)` — no rumble
- All 5 shake calls share the same pattern — rumble can be added alongside each shake call
- No controller_id management needed for single-player (use 0 for first connected gamepad)

**Plan:**
1. Add `rumble(power: float, duration: float)` method to `CameraShake.gd` (same module, same call sites)
2. `rumble()` calls `Input.start_joy_vibration(0, power, power, duration)` and stops after duration via `SceneTreeTimer`
3. Add rumble calls alongside every existing `CameraShake.shake()` call:
   - Enemy death: weak rumble (0.3, 0.2s)
   - Player damage: medium rumble (0.5, 0.3s)
   - Mine explosion: strong rumble (0.8, 0.4s)
   - DroneBomb detonation: very strong (1.0, 0.5s)
   - Boost activation: light rumble (0.2, 0.15s)
4. Add "Controller Rumble" toggle to Options → Audio tab
5. Check `Input.get_connected_joypads().size() > 0` before vibrating

**Subtasks:**
```
48.1 — Add rumble(power, duration) method to CameraShake.gd
48.2 — Wire rumble calls at all 5 CameraShake.shake() call sites
48.3 — Add rumble toggle to Options → Audio section
48.4 — Add connected-gamepad check before vibration calls
48.5 — Test: rumble fires on each event, respects toggle, stops after duration
```

**Expected impact:** Tactile feedback for all high-impact events. Immersion improvement proportional to effort — ~50 lines of code for significant sensory gain.

---

### Part 49: Extract Shared Sprite Scaling Utility

**Problem:** `Interceptor.gd:231-241` and `Enemy.gd:66-76` contain identical `_scale_sprite()` logic: get viewport width, divide by `BASE_VIEWPORT_WIDTH`, multiply by `BASE_SPRITE_SIZE`, divide by texture height, apply scale. Duplicated code violates DRY and both instances call the function twice during initialization.

**Findings:**
- `Interceptor.gd:231-241` — `_scale_sprite()` — 11 lines, identical formula to Enemy.gd
- `Enemy.gd:66-76` — `_scale_sprite()` — 11 lines, identical formula to Interceptor.gd
- Both use `BASE_SPRITE_SIZE = 64.0` and `BASE_VIEWPORT_WIDTH = 1280.0` as local consts
- Both are called from `_ready()` AND from `_update_sprite()`/`init()` — double-scaled on init
- `Enemy.gd:73` checks `if sprite.texture:` before scaling (Interceptor.gd:238 also checks)
- A shared helper reduces duplication and centralizes viewport-responsive scaling logic

**Plan:**
1. Add a static utility function `scale_sprite_to_viewport(sprite: Sprite2D, base_size: float = 64.0, base_viewport: float = 1280.0)` to a new `helpers.gd` autoload or as a static method on existing autoload
2. Replace both `_scale_sprite()` methods with calls to the shared utility
3. Remove duplicate const declarations from both files
4. Fix double-scaling: remove the `_scale_sprite()` call from `_ready()` in Enemy.gd (line 34) — `init()` already calls `_update_sprite()` which calls `_scale_sprite()`
5. Fix double-scaling in Interceptor.gd: `_scale_sprite()` called from both `_ready()` and weapon-init paths

**Subtasks:**
```
49.1 — Create helpers.gd autoload or add static method to existing autoload
49.2 — Implement scale_sprite_to_viewport(sprite, base_size, base_viewport) utility
49.3 — Replace Interceptor.gd _scale_sprite() with utility call
49.4 — Replace Enemy.gd _scale_sprite() with utility call
49.5 — Remove redundant _scale_sprite() call from Enemy.gd _ready()
49.6 — Remove redundant _scale_sprite() call from Interceptor.gd _ready()
49.7 — Verify sprite scaling identical before/after for all viewport sizes
```

**Expected impact:** DRY compliance — 22 duplicated lines reduced to 1 utility call × 2. Eliminates double-scaling on initialization (~20% wasted work per enemy spawn).

---

### Part 50: Add Multiplier Timer HUD Indicator

**Problem:** `GameManager.gd:52` emits `multiplier_timer_updated(time_left)` every frame during active multiplier, but `HUD.gd` never connects to this signal. The player has zero visual feedback showing how much time remains on their score multiplier.

**Findings:**
- `GameManager.gd:10` — `signal multiplier_timer_updated(time_left: float)` — defined
- `GameManager.gd:50-54` — emitted every frame when `_multiplier_timer > 0.0` — functional
- `HUD.gd:16-20` — connects to `score_updated`, `health_updated`, `multiplier_updated`, `difficulty_tier_changed` — but NOT to `multiplier_timer_updated`
- `HUD.gd:7` — `@onready var multiplier_label: Label = $MultiplierLabel` — exists and shows "x1" etc.
- `HUD.gd:28-29` — `_on_multiplier_updated()` updates label text — works, but no timer indicator
- HUD has no progress bar or countdown visual for the multiplier timer

**Plan:**
1. Add `multiplier_timer_bar: TextureProgressBar` or `ProgressBar` node to `HUD.tscn` scene (small bar below multiplier label)
2. Connect `GameManager.multiplier_timer_updated` in `HUD._ready()`
3. On signal: update progress bar value from `time_left / MULTIPLIER_DURATION`
4. Show bar only when `time_left > 0` (visible = `time_left > 0` via signal data or check)
5. Style bar: yellow/gold color to match multiplier theme, pulsing animation when < 3 seconds remain
6. Ensure bar is hidden during normal (non-timed) multiplier state

**Subtasks:**
```
50.1 — Add ProgressBar node to HUD.tscn below multiplier_label
50.2 — Connect multiplier_timer_updated signal in HUD._ready()
50.3 — Update bar value = time_left / MULTIPLIER_DURATION on each signal
50.4 — Show bar only when time_left > 0
50.5 — Add pulse animation (modulate oscillation) when time_left < 3.0
50.6 — Test: collect multiplier pickup, verify bar appears/animates/disappears
```

**Expected impact:** Clear visual feedback for timed multiplier — player knows exactly how long their 2× bonus lasts. Signal that was already fully wired on the emitter side finally has a consumer.

---

### Part 51: Consolidate Remaining Hardcoded Values into Constants.gd

**Problem:** Despite three previous phases of constant extraction (`Constants.gd:68 lines`), several gameplay-critical values remain hardcoded across scripts. This makes tuning impossible without editing individual files.

**Findings:**
- `Game.gd:23` — `world.scale = Vector2(1.0, 0.5)` — isometric scale factor should be `Constants.WORLD_SCALE`
- `Interceptor.gd:257-263` — bridge fall repositioning uses literal `-32` and `32` for lane reset — should reference `Constants.LANE_POSITIONS[1]` and `LANE_POSITIONS[2]`
- `Interceptor.gd:45` — `Camera2D` offset `position.y = -100` — should be `Constants.CAMERA_Y_OFFSET`
- `Interceptor.gd:113` — `move_toward(velocity.x, Constants.WEAVE_DISTANCE` — uses constant but also has literal `128.0` comment
- `WeatherSystem.gd:244,247` — acid overlay alpha values `Color(0.1, 0.3, 0.1, 0.15)` and `Color(0.15, 0.2, 0.15, 0.25)` — should be constants
- `Scav.gd:25` — `flank_offset = 64.0` — should be `Constants.SCAV_FLANK_OFFSET`
- `Enemy.gd:7-8` — `BASE_SPRITE_SIZE: float = 64.0` and `BASE_VIEWPORT_WIDTH: float = 1280.0` — duplicated in Interceptor.gd
- `Highway.gd:178-179` — `Line2D.width = 3.0` for guardrails — should be `Constants.GUARDRAIL_WIDTH`

**Plan:**
1. Add all identified values to `Constants.gd` with clear section naming
2. Update all 7+ files to reference constants instead of literals
3. Verify no gameplay changes — values remain identical, only source changes
4. Run full test suite — no regression expected since values are unchanged
5. Document each constant with its range and purpose

**Subtasks:**
```
51.1 — Add world, camera, UI constants to Constants.gd
51.2 — Fix Game.gd world.scale → Constants.WORLD_SCALE
51.3 — Fix Interceptor.gd bridge fall literal lanes → Constants.LANE_POSITIONS
51.4 — Fix Interceptor.gd camera Y offset → Constants.CAMERA_Y_OFFSET
51.5 — Fix WeatherSystem.gd overlay alpha values → constants
51.6 — Fix Scav.gd flank_offset → Constants.SCAV_FLANK_OFFSET
51.7 — Fix Highway.gd guardrail width → Constants.GUARDRAIL_WIDTH
51.8 — Move Enemy.gd/Interceptor.gd BASE_SPRITE_SIZE/VIEWPORT_WIDTH to Constants
51.9 — Run full test suite, verify zero gameplay changes
```

**Expected impact:** Single source of truth for game balance. Tuning any value requires editing Constants.gd only. Enables future inspector-based tuning via `@export`.

---

### Priority Matrix

| Part | Title | Effort | Impact | Priority |
|------|-------|--------|--------|----------|
| 42 | Signal-Based Enemy List | Medium | High | P0 |
| 43 | Parallax Background Layers | High | High | P2 |
| 44 | Civilian Vehicles | Medium | Medium | P2 |
| 45 | Boss Encounters | High | High | P1 |
| 46 | Floating Combat Text | Low | Medium | P1 |
| 47 | Screen Transition Effects | Low | Medium | P1 |
| 48 | Gamepad Rumble | Low | Low | P2 |
| 49 | Shared Sprite Scaling Utility | Low | Low | P2 |
| 50 | Multiplier Timer HUD Indicator | Low | Low | P1 |
| 51 | Constants Consolidation | Low | Medium | P1 |

**P0 (do now):** Part 42 — Eliminates periodic tree traversal and fixes latent null-pointer crash in homing logic.
**P1 (do next):** Parts 45, 46, 47, 50, 51 — Boss encounters, combat text, screen transitions, timer indicator, constants consolidation.
**P2 (do later):** Parts 43, 44, 48, 49 — Parallax backgrounds, civilian vehicles, gamepad rumble, shared utility.

---

## Phase 5: Production Hardening — 10 Targeted Improvements

Following completion of Phase 4 (Parts 42-51), a comprehensive re-audit of all 38+ game scripts, 9 autoloads, 20 TSCN scenes, and the 363-test suite identified these 10 remaining issues. Each has a concrete fix with measurable impact.

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
6. Move `input_remap.load_bindings()` / `save_bindings()` to use the same `ConfigFile`
7. Write tests: verify save → restart → load restores volumes, fullscreen, and input bindings

**Subtasks:**
```
52.1 — Create SettingsManager.gd autoload wrapping ConfigFile (volume, video, input)
52.2 — Add get_volume/set_volume methods with AudioServer integration
52.3 — Update Options.gd to delegate to SettingsManager for all bus changes
52.4 — Add SettingsManager.load() call in Options.gd _ready()
52.5 — Save fullscreen toggle state to SettingsManager
52.6 — Migrate input_remap save/load to SettingsManager ConfigFile
52.7 — Test: save → restart → load restores all options correctly
52.8 — Test: missing ConfigFile falls back to project defaults gracefully
```

**Expected impact:** Player settings persist across sessions. Audio tuning is no longer lost on restart. Unified settings API replaces ad-hoc save patterns.

---

### Part 53: Replace BossWarRig Private Method Access with Public Signal

**Problem:** `BossWarRig.gd:35-37` calls `_spawner._spawn_enemy("scav")` — accessing a private (underscore-prefixed) method of `Spawner.gd`. This is tight coupling that breaks if `_spawn_enemy` is renamed, refactored, or made truly private.

**Files:** `scripts/scenes/enemies/BossWarRig.gd:34-37`, `scripts/scenes/world/Spawner.gd`

**Findings:**
- `BossWarRig.gd:34-37` — `_spawn_minions()` calls `_spawner._spawn_enemy("scav")` — underscore-prefixed private method
- `Spawner.gd` has a `boss_spawned` signal (line 16) but no `spawn_minion_requested` signal
- No `public` method equivalent exists — `_spawn_enemy()` is the only spawn entry point
- `BossWarRig` stores `_spawner` as a weak reference set during `init()` — reasonable, but the API is wrong
- This pattern prevents `Spawner` from ever making `_spawn_enemy` truly private without breaking boss AI

**Plan:**
1. Add `signal spawn_minion_requested(enemy_type: String, count: int)` to `Spawner.gd`
2. In `BossWarRig.gd:_spawn_minions()`: emit the signal instead of calling `_spawner._spawn_enemy()`
3. In `Spawner.gd: _ready()` or boss registration step: connect minion spawn signal to `_spawn_enemy`
4. Remove the `_spawner` reference from `BossWarRig` if no other private methods are accessed
5. Update tests: verify minion spawn signal is emitted and handled correctly
6. Verify no other scripts access underscore-prefixed methods on other singletons

**Subtasks:**
```
53.1 — Add spawn_minion_requested signal to Spawner.gd
53.2 — Replace BossWarRig._spawn_minions() direct call with signal emit
53.3 — Wire Spawner signal handler to call _spawn_enemy (the only consumer)
53.4 — Remove BossWarRig._spawner reference if no remaining usages
53.5 — Audit all other scripts for underscore-prefixed method access (e.g. _spawn_enemy, _on_*)
53.6 — Run full test suite, verify boss minion spawn works identically
```

**Expected impact:** Clean API boundary. `_spawn_enemy` can be renamed or refactored without breaking boss behavior. Eliminates fragile cross-script coupling.

---

### Part 54: Fix DroneBomb Collision Mask — Enable Counterplay

**Problem:** `DroneBomb.gd:10` sets `collision_mask = 1` (player layer only). Player bullets are on layer 3. Drone bombs can never be shot down by the player — they are guaranteed to detonate.

**Files:** `scripts/scenes/weapons/DroneBomb.gd:8-10`

**Findings:**
- `DroneBomb.gd:10` — `collision_mask = 1` — detects only player body (layer 1). Player bullets are layer 3.
- `Bullet.gd:9-10` — Collision layer = 3 (player weapons), mask = 2 (enemies)
- No collision path exists from bullet → drone bomb
- `DroneBomb.gd:67-70` — `_detonate()` only checks bodies overlapping the blast, cannot pre-detonate from bullet hit
- Gameplay impact: drone bombs are always a guaranteed hit — no skill expression or counterplay

**Plan:**
1. Change `DroneBomb.gd:10` to use `collision_mask = 1 | 3` (player + player bullets)
2. Add `_on_body_entered()` / `_on_area_entered()` handler to DroneBomb that detects bullet hits
3. On bullet hit: trigger immediate detonation (early explosion damages player less predictably)
4. Add `hit_by_bullet` flag to distinguish bullet-triggered detonation from timer detonation
5. Optionally give drone bomb a small amount of HP (2 hits) so it doesn't die to a single MG bullet
6. Verify player bullets can collide with drone bombs in test scene

**Subtasks:**
```
54.1 — Update DroneBomb.gd collision_mask to include player bullet layer (3)
54.2 — Add _on_body_entered / _on_area_entered handlers for bullet detection
54.3 — Implement early detonation on bullet hit with visual difference
54.4 — Optionally add 2-HP system so drone bomb survives one bullet
54.5 — Test: fire bullet at drone bomb, verify detonation/hit response
54.6 — Test: drone bomb still detonates on timer if not shot down
```

**Expected impact:** Skilled players can shoot down drone bombs for counterplay. Rookie players still take damage from undetected bombs. Better skill expression without removing the threat entirely.

---

### Part 55: Cache Civilian Player Reference Instead of Tree Traversal

**Problem:** `Civilian.gd:46` calls `get_tree().get_first_node_in_group("player")` every physics frame. This is an O(depth) tree traversal on every `_physics_process` tick.

**Files:** `scripts/scenes/enemies/Civilian.gd:44-51`

**Findings:**
- `Civilian.gd:46` — `get_tree().get_first_node_in_group("player")` called every physics process (~60fps)
- `Civilian.gd:22-29` — `init()` method already exists with start_lane, speed, direction parameters — but no player reference parameter
- `Spawner.gd:108-115` — `_spawn_civilian()` calls `civilian.init(...)` but player is available as `player` member
- `Spawner.gd:46` — `player` member variable already exists
- Similar pattern in other enemies but they cache in `init()` via `_player = p_player`

**Plan:**
1. Add `var _player: Node = null` member to `Civilian.gd`
2. Add `player_ref` parameter to `Civilian.gd:init()`
3. In `Civilian.gd:_physics_process()`: use `_player` instead of `get_tree().get_first_node_in_group("player")`
4. In `Spawner.gd:_spawn_civilian()`: pass `player` to `civilian.init()`
5. Add `is_instance_valid(_player)` guard before `_player.global_position` access
6. Verify civilian still correctly detects safe exit (player Y position comparison)

**Subtasks:**
```
55.1 — Add _player member variable to Civilian.gd
55.2 — Add player_ref parameter to Civilian.init()
55.3 — Replace get_tree().get_first_node_in_group("player") with _player reference
55.4 — Pass player reference from Spawner._spawn_civilian()
55.5 — Add is_instance_valid guard before _player access
55.6 — Test: civilian spawns, moves, exits safely without tree traversal errors
```

**Expected impact:** Eliminates tree traversal in every physics frame per civilian. Pattern consistency with other enemies. Marginal perf improvement that compounds with multiple civilians on screen.

---

### Part 56: Add @export Variables Across All Tunable Scripts

**Problem:** Zero `@export` variables exist in the entire project. Every gameplay value — speed, HP, cooldowns, spawn rates — requires editing GDScript to change. This makes game balance tuning, prototyping, and designer iteration impossible without a programmer.

**Files:** All `.gd` files with gameplay values

**Findings:**
- `Constants.gd` centralizes 99 lines of values but none are exposed to the inspector
- `Interceptor.gd` — `BASE_SPEED`, `BOOST_SPEED_MULTIPLIER`, `BOOST_DURATION`, `WEAVE_COOLDOWN` all hardcoded
- `Enemy.gd` — `hp`, `speed`, `score_value` instance vars set in subclasses but not `@export`
- `Spawner.gd` — `MIN_WAVE_INTERVAL`, `WAVE_INTERVAL_TIER_REDUCTION` used but not editable
- `Highway.gd` — `CHUNK_HEIGHT`, `CHUNK_WIDTH`, `NUM_LANES`, chunk weights all hardcoded
- `Bullet.gd` — `speed`, `damage`, `homing_strength` set at runtime but not exposed
- `WeatherSystem.gd` — `WEATHER_TRANSITION_TIME`, `RAIN_AMOUNT`, lightning parameters hardcoded
- Zero `@export_group` annotations — no organizational structure for inspector

**Plan:**
1. Add `@export var` declarations to all gameplay-critical scripts, grouped by purpose:
   - `Constants.gd`: mark all static values with `@export` where appropriate
   - `Interceptor.gd`: export `BASE_SPEED`, `BOOST_DURATION`, `WEAVE_COOLDOWN`, `MAX_HEALTH`
   - `Spawner.gd`: export wave intervals, spawn distances, composition scaling
   - `Highway.gd`: export chunk dimensions, type weights, scroll speed
   - `Bullet.gd`: export base damage, speed, homing strength
   - `WeatherSystem.gd`: export transition times, particle amounts, damage values
2. Add `@export_group("Combat")`, `@export_group("Movement")`, etc. for organization
3. Add `@export_range(min, max, step)` constraints where applicable
4. Add `@export_tooltip("Description of what this value controls")` for documentation
5. Create a `game_params.tres` resource (or keep in Constants.gd with `@export`) for single-file tuning
6. Verify no gameplay values remain as bare literals after export conversion

**Subtasks:**
```
56.1 — Add @export vars to Interceptor.gd (speed, boost, weave, HP)
56.2 — Add @export vars to Spawner.gd (wave intervals, spawn distances)
56.3 — Add @export vars to Highway.gd (chunk dims, weights, scroll)
56.4 — Add @export vars to Bullet.gd (damage, speed, homing)
56.5 — Add @export_group annotations for inspector organization
56.6 — Add @export_range and @export_tooltip for documentation
56.7 — Convert Constants.gd static values to @export where appropriate
56.8 — Test: verify exported values correctly override defaults
56.9 — Test: verify inspector values load correctly on scene instantiation
```

**Expected impact:** First-class designer/developer workflow. Game balance can be tuned live in the editor without code changes. Lowers barrier for rapid iteration on difficulty, feel, and pacing.

---

### Part 57: Create PauseMenu TSCN Scene File

**Problem:** `Game.gd:165` creates the pause menu via `preload("res://scripts/scenes/ui/PauseMenu.gd").new()` — script-only instantiation. There is no `.tscn` scene file, preventing visual layout editing, theme application, and preview.

**Files:** `scripts/scenes/ui/PauseMenu.gd`, `scripts/scenes/Game.gd:148-193`

**Findings:**
- `PauseMenu.gd` exists at `scripts/scenes/ui/PauseMenu.gd` — a script that creates its entire UI programmatically in `_ready()`
- `Game.gd:165` — loads the script directly: `preload("res://scripts/scenes/ui/PauseMenu.gd").new()`
- No `scenes/ui/PauseMenu.tscn` file exists
- Pause menu layout cannot be previewed, themed, or designed visually
- `Options.tscn` exists — pause menu is the only menu without a scene file
- `PauseMenu.gd` uses hardcoded positions, sizes, and colors — inconsistent with the visual design workflow used for other menus

**Plan:**
1. Create `scenes/ui/PauseMenu.tscn` with `CanvasLayer` root, containing:
   - Full-screen `ColorRect` overlay (modulate dark, click barrier)
   - `Panel` center container with "PAUSED" title label
   - "Resume" button, "Options" button, "Quit to Menu" button
   - VBoxContainer layout for button arrangement
2. Move all layout/style from `PauseMenu.gd:_ready()` into the TSCN file
3. Update `PauseMenu.gd` to reference child nodes via `@onready` instead of creating them
4. Update `Game.gd:165` to use `load("res://scenes/ui/PauseMenu.tscn").instantiate()` instead of `.gd.new()`
5. Apply same theme/style as other menu scenes (Main menu, GameOver, Options, Garage)
6. Remove all programmatic node creation code from `PauseMenu.gd`
7. Test: pause/unpause cycle works identically before and after

**Subtasks:**
```
57.1 — Create scenes/ui/PauseMenu.tscn with Panel, ColorRect overlay, Resume/Options/Quit buttons
57.2 — Update PauseMenu.gd: replace programmatic node creation with @onready references
57.3 — Update Game.gd: _show_pause_menu to instantiate .tscn instead of .gd.new()
57.4 — Apply consistent menu theming (colors, fonts, spacing)
57.5 — Test: pause/unpause works, buttons functional, Options opens correctly
57.6 — Run full test suite — ensure signals connect on instantiated scene
```

**Expected impact:** Pause menu is visually consistent with other menus, editable in the scene editor, and maintainable without code changes. Eliminates the only script-only UI in the project.

---

### Part 58: Create Shared WeaponData Resource to Eliminate Manual Array Sync

**Problem:** `Interceptor.gd:10` defines `WEAPON_TYPES = ["missile", "mine", "emp"]` and `HUD.gd:3` defines `WEAPON_COLORS = [Color.RED, Color.YELLOW, Color.CYAN]`. These arrays must match by index manually — adding a new weapon requires updating both files in sync.

**Files:** `scripts/scenes/player/Interceptor.gd:10`, `scripts/scenes/ui/HUD.gd:3`

**Findings:**
- `Interceptor.gd:10` — `const WEAPON_TYPES: Array[String] = ["missile", "mine", "emp"]`
- `HUD.gd:3` — `const WEAPON_COLORS = [Color.RED, Color.YELLOW, Color.CYAN]`
- Both are `const` at class level, must remain index-aligned manually
- `Interceptor.gd:178-181` — `secondary_ammo` array size set in `_ready()` from `WEAPON_TYPES.size()`
- `HUD.gd:40-50` — `update_weapon_display()` uses `WEAPON_COLORS[weapon_index]` — crashes or wrong color if indices drift
- No single source of truth for weapon metadata (type name, color, icon, base ammo, description)

**Plan:**
1. Create `scripts/resources/WeaponData.gd` as a `Resource` with `class_name WeaponData`
2. Fields: `type_name: String`, `display_name: String`, `color: Color`, `icon: Texture2D`, `base_ammo: int`, `description: String`
3. Create `weapons_data.tres` resource file with all 3 weapon entries
4. Replace `Interceptor.WEAPON_TYPES` with reference to the resource file
5. Replace `HUD.WEAPON_COLORS` with same resource reference
6. Both scripts load the same `preload("res://scripts/resources/weapons_data.tres")` — guaranteed sync
7. Update `Interceptor._ready()`: allocate `secondary_ammo` from `weapon_data.size()`
8. Update `HUD.update_weapon_display()`: read color from `weapon_data[weapon_index].color`
9. All future weapons are added by editing one resource file

**Subtasks:**
```
58.1 — Create WeaponData.gd resource class (type_name, color, icon, base_ammo)
58.2 — Create weapons_data.tres with 3 entries (missile, mine, emp)
58.3 — Update Interceptor.gd: replace WEAPON_TYPES const with resource reference
58.4 — Update HUD.gd: replace WEAPON_COLORS const with resource reference
58.5 — Verify secondary_ammo sizing, color display, and weapon switching still work
58.6 — Test: add a 4th weapon to resource, verify both files pick it up automatically
```

**Expected impact:** Single source of truth for weapon metadata. Adding a weapon requires editing one resource file instead of 2+ scripts. Zero risk of index drift between Interceptor and HUD.

---

### Part 59: Refactor Scav/Drone Bullet Spawning to Avoid Parent Assumption

**Problem:** `Scav.gd:57-60` and `Drone.gd:47-50` use `get_parent().add_child(bullet)` to add spawned projectiles to the scene tree. This assumes the parent node is the root world container — a fragile assumption that breaks if the spawner hierarchy changes.

**Files:** `scripts/scenes/enemies/Scav.gd:54-71`, `scripts/scenes/enemies/Drone.gd:44-56`

**Findings:**
- `Scav.gd:57` — `get_parent().add_child(bullet)` — assumes parent is the world node
- `Drone.gd:47` — `get_parent().add_child(bomb)` — same assumption
- Both enemies are children of `Spawner` → children of `World` in `Game.tscn` — parent IS the world currently, but this is an implicit contract
- `Bullet.gd:19` extends `Area2D` — works anywhere in the scene tree, but should be child of world for proper coordinate space
- `Spawner.gd` already has `world_node` member (set in `Game.gd:47`) that could be used
- Other enemies (`Rotor.gd`) don't spawn projectiles — only Scav and Drone have this pattern

**Plan:**
1. Store `world_node` reference in both `Scav.gd` and `Drone.gd` (passed from `Spawner` in `init()`)
2. Replace `get_parent().add_child()` with `_world_node.add_child()`
3. Add `world_node: Node2D` parameter to `Scav.gd:init()` and `Drone.gd:init()`
4. Update `Spawner.gd:_spawn_enemy()` to pass `world_node` when calling `init()`
5. Verify all projectile spawning works identically before and after
6. Add explicit `is_instance_valid(_world_node)` guard before `add_child()`

**Subtasks:**
```
59.1 — Add _world_node member to Scav.gd, pass in init() from Spawner
59.2 — Add _world_node member to Drone.gd, pass in init() from Spawner
59.3 — Replace get_parent().add_child() with _world_node.add_child() in both files
59.4 — Update Spawner._spawn_enemy() to pass world_node to init()
59.5 — Add is_instance_valid guard before add_child in both files
59.6 — Test: Scav fires bullets, Drone drops bombs — projectiles exist in world space
59.7 — Run full test suite — ensure no regression in enemy projectile spawning
```

**Expected impact:** No hidden coupling between enemy position in scene tree and world container. Safe to restructure Spawner or Enemy hierarchy without breaking projectile spawning.

---

### Part 60: Extract WeatherSystem Hardcoded Colors into Constants.gd

**Problem:** `WeatherSystem.gd` contains hardcoded `Color` values for acid overlay, sky tint, lightning flash, and rain tint that should live in `Constants.gd` for unified tuning.

**Files:** `scripts/scenes/world/WeatherSystem.gd`

**Findings:**
- `WeatherSystem.gd` — multiple `Color()` literals for weather visuals (acid overlay, rain tint, lightning flash)
- `Constants.gd` already has `ACID_OVERLAY_ALPHA_LIGHT = 0.15` and `ACID_OVERLAY_ALPHA_HEAVY = 0.25` — but the Color constructors themselves have hardcoded RGB values
- Example pattern: `Color(0.1, 0.3, 0.1, 0.15)` — RGB + alpha should be a named constant
- No single weather color tuning point — changing acid rain color requires editing RGB values across multiple locations
- `WeatherSystem.gd:126-133` — acid rain damage amounts also hardcoded

**Plan:**
1. Audit `WeatherSystem.gd` for all hardcoded `Color()` values
2. Add constants to `Constants.gd:`
   - `ACID_OVERLAY_COLOR_LIGHT: Color`
   - `ACID_OVERLAY_COLOR_HEAVY: Color`
   - `RAIN_TINT_COLOR: Color` (for each weather type)
   - `LIGHTNING_FLASH_COLOR: Color`
   - `SKY_TINT_CLEAR`, `SKY_TINT_RAIN`, `SKY_TINT_STORM: Color`
   - `ACID_RAIN_DAMAGE_PER_SECOND: int`
   - `WEATHER_TRANSITION_SPEED: float`
3. Update `WeatherSystem.gd` to reference all constants instead of literals
4. Verify all weather visuals and effects are identical after refactor
5. Document each constant with its visual purpose and valid range

**Subtasks:**
```
60.1 — Audit WeatherSystem.gd for all hardcoded Color and float values
60.2 — Add weather color/effect constants to Constants.gd (organized section)
60.3 — Replace all literals in WeatherSystem.gd with constant references
60.4 — Verify weather visuals identical before/after refactor
60.5 — Document each constant with purpose, range, and weather type
60.6 — Run full test suite ensuring no gameplay regression
```

**Expected impact:** Complete weather tuning from `Constants.gd` only. Acid rain color, sky tint, lightning color, and damage rate all adjustable without touching WeatherSystem.gd.

---

### Priority Matrix

| Part | Title | Effort | Impact | Priority |
|------|-------|--------|--------|----------|
| 52 | Persist Options Volume Settings | Low | Medium | P1 |
| 53 | BossWarRig Private Method Access | Low | Medium | P1 |
| 54 | DroneBomb Collision Mask Fix | Low | High | P0 |
| 55 | Cache Civilian Player Reference | Low | Low | P2 |
| 56 | @export Variables for Tuning | Medium | High | P1 |
| 57 | PauseMenu TSCN Scene File | Medium | Medium | P1 |
| 58 | Shared WeaponData Resource | Low | Medium | P2 |
| 59 | Scav/Drone Parent Assumption Fix | Low | Medium | P1 |
| 60 | WeatherSystem Color Constants | Low | Low | P2 |

**P0 (do now):** Part 54 — DroneBomb can't be shot down, fundamental gameplay fairness issue.
**P1 (do next):** Parts 52, 53, 56, 57, 59 — Settings persistence, coupling fixes, inspector tuning, pause menu scene, parent assumption fix.
**P2 (do later):** Parts 55, 58, 60 — Civilian optimization, weapon data resource, weather color extraction.
