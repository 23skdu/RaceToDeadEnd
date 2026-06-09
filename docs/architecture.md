# Race to Dead End — Game Architecture

## Engine

**Godot 4.6** with GDScript. Forward+ renderer, GodotPhysics 2D. GUT for unit testing.

## Project Structure

```
res://
├── demo/                    # Boss defeat overlay scenes
├── scenes/                  # .tscn scene files
│   ├── enemies/             # Bunny, Rotor, Scav, Drone, BossBunny, BossSasquatch, BossGiantBiker, BossWarRig, BossVoidDrone, Civilian
│   ├── player/              # Interceptor
│   ├── ui/                  # HUD, GameOver, Garage, PauseMenu, Options, InputRemap, TopWeatherBorder, InterceptorInfo
│   ├── weapons/             # Bullet, Mine, EMPBlast, DroneBomb, ChainSwing, PoopWeapon, BabyBunnyBomb
│   └── world/               # Highway, Spawner, WeatherSystem
├── scripts/
│   ├── autoload/            # Singletons (autoloaded in project.godot)
│   │   ├── GameManager.gd   # Game state, scoring, difficulty, save/load
│   │   ├── ScoreManager.gd  # Score event routing, kill/pickup registration
│   │   ├── AudioManager.gd  # Procedural audio synthesis + playback
│   │   ├── ObjectPool.gd    # Generic object pool (enemies, bullets, pickups)
│   │   ├── Constants.gd     # All game constants (8 lanes, lane positions, bullet speeds, colors)
│   │   ├── CameraShake.gd   # Screen shake + gamepad rumble
│   │   ├── TransitionLayer.gd # Fade-to-black scene transitions
│   │   ├── PackManager.gd   # Asset pack management
│   │   └── SettingsManager.gd # Audio/video/input settings
│   ├── scenes/              # Scripts attached to scene nodes
│   │   ├── Game.gd          # Game root: init pools, connect signals, pause/game-over
│   │   ├── Main.gd          # Main menu
│   │   ├── enemies/         # Enemy base (boss_key, _die type emission) + subtype behaviors (Bunny, Rotor, Scav, Drone)
│   │   ├── player/          # Interceptor controller
│   │   ├── ui/              # HUD, menus, input remapping
│   │   ├── weapons/         # Bullet, Mine, EMP, DroneBomb logic
│   │   └── world/           # Highway, Spawner, WeatherSystem logic
│   ├── resources/           # Custom resources (WeaponData)
│   ├── utils/               # Development/analysis tools (Helpers.gd)
│   └── run_tests.gd         # Headless test runner (SceneTree script)
├── tests/                   # GUT test suite
│   ├── test_helper.gd       # Test utilities (audio bus setup, mock creation)
│   ├── unit/                # 43 unit test files
│   └── integration/         # 2 integration tests (combat flow, stress pool)
├── assets/                  # Sprites, audio, tilesets, environments
├── addons/gut/              # GUT plugin
├── docs/                    # Documentation
└── project.godot            # Engine config
```

## Core Systems

### Game Loop
1. `Main.tscn` → player clicks Start → `Game.tscn` loads
2. `Game._ready()` creates object pools, starts `GameManager`, connects signals
3. `Highway` generates scrolling road chunks (8 active, recycled off-screen) with 5 chunk types
4. `Spawner` spawns enemy waves based on difficulty tier, gating Scavs behind 1st boss kill and Drones behind 2nd; `Interceptor` fights them
5. `GameManager` tracks score, difficulty tier, speed scaling, and game state
6. On death → `GameManager.end_game()` → `GameOver` screen → restart/menu

### Object Pooling
- All bullets, enemies, mines, EMPs, and civilians use `ObjectPool`
- Pools created in `Game._ready()` with initial capacities (50 bullets, 8 rotors, etc.)
- Pool create overwrites (e.g., `create_pool` on an existing pool name) `queue_free` old children before repopulating
- Pooled items are hidden + disabled; `acquire()` activates, `release()` deactivates
- Pickups use a dedicated pool (`create_pickup_pool`) with `Area2D` collision + `body_entered` collection

### Highway
- Infinite scrolling highway in isometric diamond-tile style, **8 lanes wide** (LANE_POSITIONS from -168 to 168)
- 5 chunk types: Standard, Debris, Ice, Construction, Bridge
- Ice chunks: icy-blue diamond tiles with 15% random reflective white highlights, frosty shoulder tiles, semi-transparent blue background
- Bridge chunks: concrete-gray lane tiles, darker curb shoulders, cyan guardrails, **structural cross-beams** (Line2D) every 3 tile rows
- Dual-buffer recycling: pre-built tile arrays swapped on chunk reuse (no `duplicate()`)
- MultiMeshInstance2D for batched lane/shoulder rendering (reduced draw calls)
- Chunk difficulty weighted by tier (more hazards at higher tiers)

### Combat
- **Primary**: Machine gun (0.1s cooldown, auto-fire)
- **Secondary**: Homing missile, proximity mine, EMP blast (cycled via Q)
- Player bullet speed = `GameManager.current_speed + BULLET_SPEED_OFFSET (500)` — always outruns max player speed (including boost)
- Enemy bullet speed is constant `BULLET_SPEED (500)`
- Homing bullets use distance-bounded targeting (MAX_HOMING_RANGE = 400px)
- Enemy types: Bunny (contact-damage only, gated before 1st boss kill), Rotor (swarm, gated behind 1st boss kill), Scav (flank + shoot, gated behind 2nd boss kill), Sasquatch (wandering brute, gated behind 2nd boss kill), Drone (hover + bomb, gated behind 3rd boss kill)
- 4 boss types: BossBunny, BossGiantBiker (zombie giant on motorcycle with chain weapon), BossWarRig, BossVoidDrone (3-phase: ram → ram+bullets → ram+bullets+minions)
- Sasquatch: repurposed from 2nd boss to a random wandering monster that appears after the 2nd boss kill

### Difficulty & Speed Scaling
- Difficulty tier advances every 3000 score points (max tier 20)
- Game speed scales: `BASE_SPEED + (tier - 1) * SPEED_PER_TIER` (cap at 600)
- Wave interval decreases with tier: `BASE - (tier - 1) * 0.3` (min 2s)
- Weather escalates at tiers 5, 8, 12 (rain → acid rain → storm)
- Boss waves every 3000 score points; `bosses_killed` tracks defeated bosses

### Enemy Gating
- Bunny enemies are the only enemy type before the 1st boss kill (`bosses_killed < 1`)
- Rotor enemies become available after the 1st boss kill (`bosses_killed >= 1`)
- Scav enemies and Sasquatch enemies are excluded until `bosses_killed >= 2` (after 2nd boss fight)
- Drone enemies are excluded until `bosses_killed >= 3` (after 3rd boss fight)
- Boss scripts set `boss_key` (e.g., `boss_bunny`, `boss_sasquatch`, `boss_void_drone`, `boss`) in `_reset_state()`
- `Enemy._die()` emits the `boss_key` string instead of the default `TYPE_NAMES[enemy_type]` when `boss_key` is non-empty
- `GameManager.bosses_killed` is incremented when `Game._on_boss_defeated` fires

### Player (Interceptor)
- Sprite scaled to 84px base size (vs 64px for Rotor enemies — ~31% larger)
- `_lane_to_x()` maps lane index to world X position via `Constants.LANE_POSITIONS` (clamped 0–7)
- 6 upgradeable stats: max health, boost capacity, fire rate, missile ammo, mine ammo, EMP ammo
- Boost: 2× speed multiplier, 3 charges, 8s recharge per charge
- Slippery steering when on ice chunks
- Bridge fall: takes damage when driven off the edge of a bridge chunk

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
- **Runner**: `scripts/run_tests.gd` (SceneTree script, headless)
- **Unit tests**: 43 files covering all autoloads, scenes, and utilities
- **Integration tests**: 2 files covering combat flow and stress/pool exhaustion
- Test helper with audio bus setup, mock player creation, scene instantiation
- Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -- -gdir tests/unit`
