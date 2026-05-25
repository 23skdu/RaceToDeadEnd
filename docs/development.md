# Race to Dead End — Development Guide

This guide covers everything you need to know to contribute to the project: setup, architecture, testing, coding conventions, and common development tasks.

---

## Quick Start

### Prerequisites

- **Godot 4.6+** — Download from [godotengine.org](https://godotengine.org)
- **Git** — For version control
- **VS Code** (optional) — Recommended with the [Godot Tools](https://marketplace.visualstudio.com/items?itemName=geequlim.godot-tools) extension

### Setup

```bash
git clone <repo-url>
cd RaceToDeadEnd
```

1. Open Godot → Import `project.godot`
2. Press **F5** to run the game
3. See [Controls](#controls) below

### Controls

| Action | Key |
|---|---|
| Move left/right | A / D |
| Double-tap weave/dodge | Tap A/A or D/D within 0.25s |
| Primary fire (machine gun) | Space |
| Secondary fire (missile/mine/EMP) | Shift |
| Cycle secondary weapon | Q |
| Boost (2× speed, 1.5s) | Tab |

---

## Architecture

### Scene Tree

```
Main.tscn (entry point)
└── CanvasLayer
    ├── StartButton → Game.tscn
    ├── GarageButton → Garage.tscn
    ├── OptionsButton
    └── QuitButton

Game.tscn (gameplay root)
├── World (Node2D)
│   ├── Highway (procedural road generator)
│   ├── Spawner (enemy wave spawner)
│   └── Player/Interceptor (CharacterBody2D)
└── UI (CanvasLayer)
    ├── HUD
    └── GameOver

Garage.tscn (meta-progression shop)
```

### Autoload Singletons

| Singleton | Path | Responsibility |
|---|---|---|
| `GameManager` | `autoload/GameManager.gd` | Game state, scoring, difficulty curve, save/load |
| `ScoreManager` | `autoload/ScoreManager.gd` | Kill registration, pickup handling, score popups |
| `AudioManager` | `autoload/AudioManager.gd` | Procedural 8-bit SFX/music synthesis, audio pooling |

### Collision Layers

| Layer | Entity | Notes |
|---|---|---|
| 1 | Player, obstacles, triggers, enemy bullets | Player body + ice/bridge areas |
| 2 | Enemies, player bullets, mines, EMP | Enemy bodies + offensive weapons |
| 4 | Drone bombs | Dropped by Void Drones |

**Mask rules:**
- Player bullets: `collision_mask = 2` → hits enemies
- Enemy bullets: `collision_mask = 1` → hits player
- Mines/EMP: `collision_mask = 2` → hits enemies only

### Key Signals

**GameManager:**
- `score_updated(score: int)`
- `health_updated(health: int)`
- `multiplier_updated(multiplier: int)`
- `difficulty_tier_changed(tier: int)`
- `game_over(final_score: int)`
- `game_started`
- `segment_advanced(segment: int)`

**Interceptor (player):**
- `weapon_fired(type, pos, dir)`
- `boost_activated` / `boost_depleted`
- `boost_charge_updated(charges)`
- `weapon_switched(index)`

**Enemy (base):**
- `destroyed(position, enemy_type)`

---

## Testing with GUT

This project uses **GUT (Godot Unit Test) v9.6.0** for automated testing.

### Install GUT

GUT is **not committed** to the repository. Install it locally:

```bash
# Option 1: Download from GitHub
cd /tmp
curl -L -o gut.zip https://github.com/bitwes/Gut/archive/refs/tags/v9.6.0.zip
unzip gut.zip
cp -r Gut-9.6.0/addons/gut/* <project>/addons/gut/
rm -rf Gut-9.6.0 gut.zip
```

```bash
# Option 2: Godot Asset Library
# Open Godot → AssetLib tab → Search "GUT" → Install "Godot Unit Test (GUT)"
```

After installing, enable the plugin:

1. **Project → Project Settings → Plugins** tab
2. Check the box next to **Gut**
3. Restart Godot

### Run Tests

**From the editor:**
- The **GUT** panel appears at the bottom of the editor
- Set test directory to `res://test/`
- Click **Run All**

**From the command line:**

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test --exit
```

### Write Tests

Test files live in `test/unit/` and must:
- Be prefixed with `test_` (e.g., `test_game_manager.gd`)
- Extend `GutTest` (from `res://addons/gut/test.gd`)

```gdscript
extends GutTest

func test_something():
	var result = 2 + 2
	assert_eq(result, 4, "Math should work")
```

**Key assertion helpers:**
- `assert_eq(a, b, msg)` / `assert_ne(a, b, msg)`
- `assert_gt(a, b, msg)` / `assert_lt(a, b, msg)`
- `assert_true(val, msg)` / `assert_false(val, msg)`
- `assert_is_null(val, msg)` / `assert_is_not_null(val, msg)`
- `assert_has(arr, val, msg)`
- `assert_signal_emitted(obj, signal_name, msg)`

**Lifecycle hooks:**
- `before_all()` / `after_all()` — run once per file
- `before_each()` / `after_each()` — run before/after each test
- `add_child_autofree(node)` — auto-frees nodes after test

**Testing autoloads:**
Autoload singletons are globally available during tests, but for isolated tests, instantiate them manually:

```gdscript
var gm = load("res://autoload/GameManager.gd").new()
add_child_autofree(gm)
gm._ready()
```

**Testing signals:**

```gdscript
watch_signals(gm)
gm.add_score(100)
assert_signal_emitted_with_parameters(gm, "score_updated", [[100]])
```

**Parameterized tests:**

```gdscript
func test_damage_types():
	var params = build_params([
		["rotor", 50],
		["scav", 100],
		["drone", 200],
	])
	use_parameters(params)
	var p = get_parameter()
	sm.register_kill(p[0], Vector2.ZERO)
	assert_eq(gm.score, p[1])
```

### Existing Tests

| File | Coverage |
|---|---|
| `test/unit/test_game_manager.gd` | State, scoring, difficulty, save/load, score ticker, upgrades |
| `test/unit/test_score_manager.gd` | Kill registration, civilian protection, pickups, constants |
| `test/unit/test_audio_manager.gd` | Player creation, SFX pooling, procedural synthesis, null handling |
| `test/unit/test_highway.gd` | Chunk generation, tile variants, recycling, constants, ice/bridge |
| `test/unit/test_spawner.gd` | Wave composition, pickup drops, garbage collection, timer logic |
| `test/unit/test_interceptor.gd` | Lane system, weapons, boost, invincibility, weave, upgrades |
| `test/unit/test_enemy.gd` | Init types, damage, death signals, hit flash, collision layer |
| `test/unit/test_bullet.gd` | Init, direction, homing, nearest-finding, movement, groups |
| `test/unit/test_mine.gd` | Arming, explosion, body/area triggers, collision mask |
| `test/unit/test_emp.gd` | Expansion, max radius, damage, scale, groups |
| `test/unit/test_drone_bomb.gd` | Detonation timing, blink warning, explosion visual, collision |
| `test/unit/test_hud.gd` | Score, health, multiplier, tier, boost, weapon display |
| `test/unit/test_game_over.gd` | Score display, credits (integer), signals, visibility |
| `test/unit/test_garage.gd` | Upgrade costs, max level, insufficient credits, signals |
| `test/unit/test_main.gd` | Scene paths, state management, button handlers |
| `test/unit/test_game.gd` | Scene paths, restart, menu navigation, game over handling |

---

## Coding Conventions

### Naming

- **Files**: `PascalCase.gd` for scripts, `PascalCase.tscn` for scenes
- **Variables/functions**: `snake_case`
- **Constants**: `UPPER_SNAKE_CASE`
- **Signals**: `snake_case` with past tense where appropriate (`game_over`, `score_updated`)
- **Private members**: prefix with `_` (e.g., `_spawn_wave`, `_score_timer`)

### Style

- Use 4-space indentation (Godot default)
- Type hints on function parameters and return types
- Use `const` for values that never change, `var` otherwise
- Group related `var` declarations together
- Use `@onready` for node references that depend on the scene tree

### Signals over Direct References

Prefer signals for cross-system communication. The GameManager emits signals that the HUD listens to — this keeps UI decoupled from game logic.

### Error Handling

- Use `ResourceLoader.exists()` before `load()` for optional assets
- Use `is_instance_valid()` before accessing node references
- Use `has_method()` for duck-typed calls (e.g., `take_damage`)

---

## Common Development Tasks

### Add a New Enemy Type

1. Create `scenes/enemies/NewEnemy.tscn`:
   - Root: `CharacterBody2D` with `collision_layer = 2`
   - Add `Sprite2D`, `CollisionShape2D`, `Timer` (HitFlashTimer)
   - Attach script extending `res://scenes/enemies/Enemy.gd`

2. Create `scenes/enemies/NewEnemy.gd`:

```gdscript
extends "res://scripts/scenes/enemies/Enemy.gd"

func _physics_process(delta: float) -> void:
	# Your AI logic here
	velocity.y = -speed
	move_and_slide()
```

3. Add to `EnemyType` enum in `Enemy.gd` and add texture, sound, and init handling

4. Add audio streams in `AudioManager.gd` (hit + death generators)

5. Add speed multiplier constant in `Constants.gd`

6. Register in `Spawner.gd`:

```gdscript
enemy_scenes["new_enemy"] = preload("res://scenes/enemies/NewEnemy.tscn")
```

7. Add to wave composition in `_get_wave_composition()`

8. Add score value in `ScoreManager.SCORE_VALUES`

9. Add pool in `Game.gd`:

```gdscript
ObjectPool.create_pool("new_enemy", NEW_ENEMY_SCENE, N)
```

### Add a New Weapon

1. Create weapon scene in `scenes/weapons/` (Area2D or Node2D)
2. Implement `init(pos: Vector2)` method
3. Handle damage via `body_entered` / `area_entered` signals
4. Wire up in `Game.gd._on_player_weapon_fired()`
5. Add to Interceptor's `secondary_ammo` array and weapon cycle

### Add a New Road Chunk Type

1. Add to `Highway.ChunkType` enum
2. Add weight in `chunk_weights` dictionary
3. Handle in `_get_tile_variant()` for obstacle placement
4. Handle in `_generate_chunk_tiles()` for colors and special areas (ice triggers, bridge danger zones)

### Add a Pickup Type

1. Handle in `ScoreManager.register_pickup()` match block
2. Add corresponding method on Interceptor (e.g., `add_boost()`, `add_ammo()`)
3. Add visual color in `Spawner._spawn_pickup()` match block
4. Adjust drop weights in `Spawner._pick_pickup_type()`

---

## Project Structure

```
res://
├── autoload/              # Global singletons
│   ├── GameManager.gd     # State, scoring, difficulty, save/load
│   ├── ScoreManager.gd    # Kill registration, pickups
│   └── AudioManager.gd    # Procedural 8-bit audio
├── scenes/
│   ├── Main.tscn/.gd      # Main menu
│   ├── Game.tscn/.gd      # Gameplay root
│   ├── world/
│   │   ├── Highway.tscn/.gd   # Procedural road generation
│   │   └── Spawner.tscn/.gd   # Enemy wave spawning
│   ├── player/
│   │   └── Interceptor.tscn/.gd  # Player vehicle
│   ├── enemies/
│   │   ├── Enemy.gd           # Base enemy class
│   │   ├── Bunny.tscn/.gd     # Infected zombie bunny
│   │   ├── Rotor.tscn/.gd     # Zombie biker
│   │   ├── Scav.tscn/.gd      # Gang pickup
│   │   ├── Sasquatch.tscn/.gd # Wandering brute (renamed from BossSasquatch)
│   │   └── Drone.tscn/.gd     # Alien saucer
│   ├── weapons/
│   │   ├── Bullet.tscn/.gd    # Machine gun projectile
│   │   ├── Mine.tscn/.gd      # Dropped mine
│   │   ├── EMPBlast.tscn/.gd  # Screen-wide EMP
│   │   └── DroneBomb.gd       # Drone bomb (script-only)
│   └── ui/
│       ├── HUD.tscn/.gd       # In-game HUD
│       ├── GameOver.tscn/.gd  # Game over screen
│       └── Garage.tscn/.gd    # Meta-upgrade shop
├── assets/
│   ├── sprites/enemies/       # Enemy sprite PNGs
│   └── tilesets/              # Isometric tile definitions
├── test/
│   └── unit/                  # GUT unit tests
├── docs/
│   ├── design.md              # Full game design document
│   ├── nextsteps.md           # Implementation plan + bug fix log
│   └── development.md         # This file
├── addons/                    # Third-party plugins (gitignored)
│   └── gut/                   # GUT testing framework
└── project.godot              # Project configuration
```

---

## Build & Export

### Export Presets

Configure in **Project → Export**:

| Platform | Preset | Notes |
|---|---|---|
| Linux | Linux/X11 | Primary dev target |
| Windows | Windows Desktop | Cross-compile from Linux/macOS |
| macOS | macOS | Native build |
| Web | HTML5 | For itch.io / game jams |

### Release Checklist

- [ ] All tests pass (`godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test --exit`)
- [ ] No editor warnings in Output panel
- [ ] Export runs on target platform
- [ ] Assets optimized (texture compression, audio VOC/OGG)
- [ ] Save file path works on target platform (`user://`)

---

## Not Yet Implemented

These features are defined in the design doc but not yet coded:

- Civilian vehicles (spawn logic, protect bonus)
- Weather system (fog, dust storms, acid rain)
- Boss encounters (every 3000 pts — BossBunny, BossGiantBiker, BossWarRig, BossVoidDrone)
- Parallax background layers
- Options menu (audio/video settings)
- Daily run challenge / seed system
- Achievement badges
- Online leaderboard
- Touch/mobile controls
- Cosmetic skins in garage

See `docs/design.md` for full specifications.

---

## Troubleshooting

**GUT tests don't appear in the panel:**
- Verify test files are in `res://test/` and prefixed with `test_`
- Check GUT panel settings → Test Directory = `res://test/`
- Reload project after adding new test files

**Godot won't import the project:**
- Ensure Godot version is 4.6+ (check `project.godot` → `config/features`)
- Delete `.godot/` folder and re-import

**Autoload errors:**
- Check `project.godot` → `[autoload]` section has correct paths
- Autoloads are available globally — no need to `preload()` them

**Collision not working:**
- Verify `collision_layer` and `collision_mask` on both nodes
- Check that nodes are in the correct groups (`"player"`, `"enemy"`)
- Ensure CollisionShape2D has a valid shape assigned
