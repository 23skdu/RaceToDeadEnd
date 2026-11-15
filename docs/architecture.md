# Race to Dead End - Game Architecture

## Engine

**Godot 4.7.2** with GDScript. Forward+ renderer, GodotPhysics 2D. GUT (`v9.7.1`) for GDScript testing and Python `unittest` for tooling scripts.

## Project Structure

```text
res://
├── demo/                    # Boss defeat overlay scenes
├── scenes/                  # .tscn scene files
│   ├── enemies/             # Bunny, Rotor, Scav, Drone, BossBunny, BossSasquatch, BossGiantBiker, BossWarRig, BossVoidDrone, Civilian
│   ├── player/              # Interceptor
│   ├── ui/                  # HUD, GameOver, Garage, PauseMenu, Options, InputRemap, TopWeatherBorder, InterceptorInfo
│   ├── weapons/             # Bullet, Mine, EMPBlast, DroneBomb, ChainSwing, PoopWeapon, BabyBunnyBomb
│   └── world/               # Highway, Spawner, WeatherSystem
├── scripts/
│   ├── autoload/            # 10 singletons (autoloaded in project.godot)
│   │   ├── GameManager.gd   # Game state, scoring, difficulty, boss unlocks, save/load
│   │   ├── ScoreManager.gd  # Score event routing, kill/pickup registration
│   │   ├── AudioManager.gd  # Procedural audio synthesis, playback & 9 music track options
│   │   ├── ObjectPool.gd    # Generic object pool (enemies, bullets, pickups)
│   │   ├── Constants.gd     # Game constants (8 lanes, lane positions, bullet speeds, PLAYER_SKINS)
│   │   ├── CameraShake.gd   # Screen shake + gamepad rumble
│   │   ├── TransitionLayer.gd # Fade-to-black scene transitions
│   │   ├── PackManager.gd   # Asset pack management
│   │   ├── SettingsManager.gd # Audio/video/input/skin/music settings
│   │   └── ScreenshotManager.gd # In-game F12 viewport screenshot capture + PNG export
│   ├── scenes/              # Scripts attached to scene nodes
│   │   ├── Game.gd          # Game root: init pools, connect signals, pause/game-over
│   │   ├── Main.gd          # Main menu
│   │   ├── enemies/         # Enemy base (boss_key, _die type emission) + subtypes & bosses
│   │   ├── player/          # Interceptor controller + skin loading
│   │   ├── ui/              # HUD, Garage (upgrades & skins), menus, options, input remapping
│   │   ├── weapons/         # Bullet, Mine, EMP, DroneBomb, ChainSwing, PoopWeapon, BabyBunnyBomb
│   │   └── world/           # Highway, Spawner, WeatherSystem logic
│   ├── resources/           # Custom resources (WeaponData)
│   ├── utils/               # Shared utilities (Helpers.gd)
│   ├── check_bg.py          # Enemy sprite PNG alpha verification
│   ├── check_coverage.py    # 100% unit/fuzz/Python script coverage check
│   ├── check_deadcode.py    # Unreferenced file and unused symbol scanner
│   ├── remove_bg.py         # Enemy sprite background removal utility
│   └── run_tests.gd         # Headless test runner (SceneTree script)
├── tests/                   # Automated test suites
│   ├── test_helper.gd       # Test utilities (audio bus setup, mock creation)
│   ├── unit/                # GUT unit tests (100% script coverage)
│   ├── integration/         # GUT integration tests
│   ├── fuzz/                # GUT fuzz tests (100% script coverage)
│   ├── regression/          # GUT regression tests
│   └── python/              # Python utility unit + fuzz tests
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
- Player bullet speed = `GameManager.current_speed + BULLET_SPEED_OFFSET (500)` - always outruns max player speed (including boost)
- Enemy bullet speed is constant `BULLET_SPEED (500)`
- Homing bullets use distance-bounded targeting (MAX_HOMING_RANGE = 400px)
- Enemy types: Bunny (contact-damage only, gated before 1st boss kill), Rotor (swarm, gated behind 1st boss kill), Scav (flank + shoot, gated behind 2nd boss kill), Sasquatch (wandering brute, gated behind 2nd boss kill), Drone (hover + bomb, gated behind 3rd boss kill)
- 4 main boss encounters (Cyber Bunny, Giant Biker, War Rig, Void Drone) plus the repurposed Sasquatch mini-boss — see [Boss Guide](bosses.md) for full details and screenshots
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
- Sprite scaled to 108px design height (via `Helpers.scale_sprite_to_viewport`)
- `_lane_to_x()` maps lane index to world X position via `Constants.LANE_POSITIONS` (clamped 0–7)
- 6 upgradeable stats: max health, boost capacity, fire rate, missile ammo, mine ammo, EMP ammo
- 5 built-in Interceptor skins (`Constants.PLAYER_SKINS`): *Interceptor Classic*, *Crimson Viper*, *Toxic Volt*, *Solar Chrome*, and *Urban Camo* (unlocked after defeating the 1st boss, persisted via `GameManager.first_boss_defeated`), plus `PackManager` custom skins
- Boost: 2× speed multiplier, 3 charges, 8s recharge per charge
- Slippery steering when on ice chunks
- Bridge fall: takes damage when driven off the edge of a bridge chunk

### Audio
- Fully procedural: all SFX and music synthesized at runtime (no asset files)
- 16-bit WAV generation at 22050 Hz via `_build_16bit_stream(duration, generator)`
- Lazy initialization: SFX streams generated on first play (music loaded asynchronously via `WorkerThreadPool`)
- 9 selectable music options (`AudioManager.MUSIC_OPTIONS`): `dynamic` (stage-adaptive), `outrun` (*Outrun Synthwave*), `industrial` (*Cyber Industrial*), `neon_drift` (*Neon Drift*), `classic` (*Classic Arcade*), plus individual boss-stage tracks (`bunny`, `biker`, `sasquatch`, `void`), persisted in `SettingsManager`
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

- **Framework**: GUT (Godot Unit Testing) via `addons/gut/` + Python `unittest` (`tests/python/`)
- **Runner**: `scripts/run_tests.gd` (SceneTree script, headless) and `make test`
- **Coverage**: `scripts/check_coverage.py` enforces 100% unit (`tests/unit/`) and fuzz (`tests/fuzz/`) coverage across all `.gd` scripts in `scripts/` and `demo/`, plus 100% coverage of Python scripts in `tests/python/`
- **Dead Code Verification**: `make deadcode` (`scripts/check_deadcode.py`) scans for unreferenced scripts/scenes and unused symbols
- **Run**: `make check` or `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://tests/fuzz,res://tests/regression -ginclude_subdirs -gexit -glog=1`
