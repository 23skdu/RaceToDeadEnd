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

ObjectPool for bullets/mines/EMP. Machine gun (0.1s cooldown), homing missile, proximity mine, EMP stun. Weapon cycling via `cycle_weapon`.

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

## Priority Matrix (Remaining)

| Part | Title | Effort | Impact | Priority |
|------|-------|--------|--------|----------|
| 22 | TileMapLayer Highway | High | Critical | P3 |
| 35 | class_name EnemyBase | Low | Medium | P3 |
| 40 | Integration Tests | Medium | High | P1 |

**P1 (do next):** Part 40 — Integration tests to verify cross-system behavior.
**P3 (deferred):** Parts 22, 35 — TileMapLayer rewrite and class_name fix blocked by Godot 4 issues.
