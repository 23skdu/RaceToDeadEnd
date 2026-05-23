# Race to Dead End — Game Architecture

## Engine

**Godot 4.6** with GDScript. Forward+ renderer, GodotPhysics 2D. GUT for unit testing.

## Project Structure

```
res://
├── autoload/                # .gd.uid stubs (editor tracking for relocated scripts)
├── scenes/                  # .tscn scene files
│   ├── enemies/             # Rotor, Scav, Drone, BossWarRig, Civilian
│   ├── player/              # Interceptor
│   ├── ui/                  # HUD, GameOver, Garage, Options, PauseMenu
│   ├── weapons/             # Bullet, Mine, EMPBlast, DroneBomb
│   └── world/               # Highway, Spawner, WeatherSystem
├── scripts/
│   ├── autoload/            # Singletons (autoloaded in project.godot)
│   │   ├── GameManager.gd   # Game state, scoring, difficulty, save/load
│   │   ├── ScoreManager.gd  # Score event routing, kill/pickup registration
│   │   ├── AudioManager.gd  # Procedural audio synthesis + playback
│   │   ├── ObjectPool.gd    # Generic object pool (enemies, bullets, pickups)
│   │   ├── Constants.gd     # All game constants
│   │   ├── CameraShake.gd   # Screen shake + gamepad rumble
│   │   ├── TransitionLayer.gd # Fade-to-black scene transitions
│   │   ├── Helpers.gd       # Static utility functions (sprite scaling)
│   │   ├── PackManager.gd   # Asset pack management
│   │   └── SettingsManager.gd # Audio/video/input settings
│   ├── scenes/              # Scripts attached to scene nodes
│   │   ├── Game.gd          # Game root: init pools, connect signals, pause/game-over
│   │   ├── Main.gd          # Main menu
│   │   ├── enemies/         # Enemy base + subtype behaviors
│   │   ├── player/          # Interceptor controller
│   │   ├── ui/              # HUD, menus, input remapping
│   │   ├── weapons/         # Bullet, Mine, EMP, DroneBomb logic
│   │   └── world/           # Highway, Spawner, WeatherSystem logic
│   ├── resources/           # Custom resources (WeaponData)
│   └── utils/               # Development/analysis tools
├── tests/                   # GUT test suite
│   ├── test_helper.gd       # Test utilities (class_name TestHelper)
│   ├── unit/                # 35+ unit test files
│   └── integration/         # Integration tests (combat flow, stress pool)
├── assets/                  # Sprites, audio, tilesets, environments
├── addons/gut/              # GUT plugin
├── docs/                    # Documentation
├── project.godot            # Engine config
├── run_tests.gd             # Headless test runner (SceneTree script)
└── run_tests.sh             # Batch test runner for CI
```

## Core Systems

### Game Loop
1. `Main.tscn` → player clicks Start → `Game.tscn` loads
2. `Game._ready()` creates object pools, starts `GameManager`, connects signals
3. `Highway` generates scrolling road chunks (8 active, recycled off-screen)
4. `Spawner` spawns enemy waves based on difficulty tier, `Interceptor` fights them
5. `GameManager` tracks score, difficulty tier, speed scaling, and game state
6. On death → `GameManager.end_game()` → `GameOver` screen → restart/menu

### Object Pooling
- All bullets, enemies, mines, EMPs, and civilians use `ObjectPool`
- Pools created in `Game._ready()` with initial capacities (50 bullets, 8 rotors, etc.)
- Pooled items are hidden + disabled; `acquire()` activates, `release()` deactivates
- Pickups use a dedicated pool with `Area2D` collision + `body_entered` collection

### Highway
- Infinite scrolling highway in isometric diamond-tile style
- 5 chunk types: Standard, Debris, Ice, Construction, Bridge
- Dual-buffer recycling: pre-built tile arrays swapped on chunk reuse (no `duplicate()`)
- MultiMeshInstance2D for batched lane/shoulder rendering (reduced draw calls)
- Chunk difficulty weighted by tier (more hazards at higher tiers)

### Combat
- **Primary**: Machine gun (0.1s cooldown, auto-fire)
- **Secondary**: Homing missile, proximity mine, EMP blast (cycled via Q)
- Homing bullets use distance-bounded targeting (MAX_HOMING_RANGE = 400px)
- Enemy types: Rotor (swarm), Scav (flank + shoot), Drone (hover + bomb)
- BossWarRig: 3-phase boss (ram → ram+bullets → ram+bullets+minions)

### Difficulty & Speed Scaling
- Difficulty tier advances every 1000 score points (max tier 20)
- Game speed scales: `BASE_SPEED + (tier - 1) * SPEED_PER_TIER` (cap at 600)
- Wave interval decreases with tier: `BASE - (tier - 1) * 0.3` (min 2s)
- Weather escalates at tiers 5, 8, 12 (rain → acid rain → storm)
- Boss waves every 3000 score points

### Audio
- Fully procedural: all SFX and music synthesized at runtime (no asset files)
- 16-bit WAV generation at 22050 Hz via `_build_16bit_stream(duration, generator)`
- Lazy initialization: SFX streams generated on first play (music loaded eagerly)
- 16-channel SFX player pool with priority system
- Reverb on SFX bus, compressor on Master bus

### Save System
- Save file at `user://save.dat` with CRC32 checksum via `hash(var_to_str(payload))`
- Stores: credits, high score, upgrade levels
- Load validates checksum, type-checks all fields, falls back to defaults on corruption

### Weather System
- 4 states: Clear, Light Rain, Acid Rain, Storm
- GPU particles for rain, Line2D lightning bolts, cloud polygons
- Acid rain deals damage over time; overlay color transitions smoothly
- Weather transitions lerp between previous and target overlay color

### UI
- HUD: Score, multiplier bar, health, weapon display, boost charges
- GameOver: Score summary + fade-in "PRESS SPACE TO CONTINUE" (1.5s delay)
- Garage: Meta-upgrade shop (health, boost, ammo, fire rate)
- Pause: Resume, Options, Quit
- Floating combat text for damage/score popups (pooled Labels)

## Testing

- **Framework**: GUT (Godot Unit Testing) via `addons/gut/`
- **Runner**: `run_tests.gd` (SceneTree script, headless) and `run_tests.sh` (batch CI)
- **Unit tests**: 35+ files covering all autoloads, scenes, and utilities
- **Integration tests**: Combat flow and stress/pool exhaustion
- Test helper with audio bus setup, mock player creation, scene instantiation
