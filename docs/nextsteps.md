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
