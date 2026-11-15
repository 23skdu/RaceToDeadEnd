<img width="1024" height="1024" alt="Race to Dead End Banner" src="https://github.com/user-attachments/assets/73206466-a21d-4f86-8c64-89a932b66d07" />

# Race to Dead End

Isometric (2.5D) vehicular combat racing game built with **Godot 4.7.2**. Drive a heavily armed Interceptor MK-VI down an endless 8-lane highway, fighting off infected zombie bunnies, biker gangs, armored scav trucks, wandering sasquatches, and alien void drones. Inspired by *Spy Hunter* (1983).

## Key Features

- **8-Lane Isometric Combat:** Procedural endless highway with 5 chunk types (Standard, Debris, Ice, Construction, Bridge), dynamic weather (Clear, Light Rain, Acid Rain, Storm), and 4-layer synthwave parallax horizon.
- **Boss Progression:** Milestone boss encounters every 3,000 points — **Cyber Bunny** → **Giant Biker** → **War Rig** → **Void Drone**, plus the wandering **Sasquatch** mini-boss. See [Boss Guide](docs/bosses.md) for stats and screenshots.
- **Interceptor Car Skins:** 5 built-in Interceptor skins in the Garage (*Interceptor Classic*, *Crimson Viper*, *Toxic Volt*, *Solar Chrome*, plus *Urban Camo* unlocked by defeating the 1st boss) and external `user://packs/` custom skin support.
- **Procedural 16-Bit Audio & Music Selector:** Zero external audio assets — all SFX and 9 selectable synth/stage music options (*Dynamic Stage-Adaptive*, *Outrun Synthwave*, *Cyber Industrial*, *Neon Drift*, *Classic Arcade*, and stage themes) are synthesized at runtime.
- **In-Game Screenshots:** Press `F12` anywhere (menus, paused, or active gameplay) to save PNG screenshots to `user://screenshots/`.
- **Meta-Progression & Modes:** Garage upgrades, Daily Run deterministic seeded challenges, local Top-10 leaderboard, achievements, remappable keyboard/gamepad controls, and optional touch overlay.

## Setup & Running

1. Install **Godot 4.7.2** from [godotengine.org](https://godotengine.org).
2. Clone the repository and initialize dependencies:

```bash
git clone https://github.com/23skdu/RaceToDeadEnd.git
cd RaceToDeadEnd
make deps
make import
```

3. Launch the game or open in the editor:

```bash
make run      # Run the game
make editor   # Open in Godot Editor
```

## Controls

| Action | Default Key / Input |
| --- | --- |
| Move left / right | `A` / `D` or `Left` / `Right` |
| Double-tap weave / dodge | Tap `A`+`A` or `D`+`D` within `0.25s` |
| Accelerate / Brake | `W` / `S` or `Up` / `Down` |
| Primary fire (machine gun) | `Space` |
| Secondary fire (missile / mine / EMP) | `Shift` |
| Cycle secondary weapon | `Q` or `R` |
| Quick EMP / Drop Mine | `F` / `V` |
| Boost (2× speed, collision immunity) | `Tab` |
| Pause | `Esc` |
| Take screenshot | `F12` |

All bindings can be customized in **Options → Input**.

## Verification & Build Targets

Run `make help` for all Makefile targets. Common workflows:

```bash
make check          # Run godot check, lint, lint-docs, deadcode, coverage, Python tests, and GUT suite
make test           # Run full GUT test suite (unit + integration + fuzz + regression)
make test-python    # Run Python utility script unit and fuzz tests
make check-coverage # Verify 100% unit, fuzz, and Python script test coverage
make check-assets   # Verify enemy sprite PNG alpha channels
make deadcode       # Check for unreferenced scripts, scenes, or unused symbols
make build-web      # Export Web build with COOP/COEP coi-serviceworker.js
make build-all      # Export Web, Linux, Windows, and macOS release builds
```

## Directory Structure

```text
res://
├── assets/                  # Sprites (player skins, enemies), themes, fonts, environments
├── demo/                    # Boss defeat celebration overlays (DemoScene.gd + DemoBoss*.tscn)
├── docs/                    # Architecture, design, bosses, development, and roadmap docs
├── scenes/                  # Godot .tscn scenes (enemies, player, ui, weapons, world)
├── scripts/
│   ├── autoload/            # 10 singletons (GameManager, AudioManager, ScreenshotManager, etc.)
│   ├── resources/           # WeaponData custom resource
│   ├── scenes/              # Scene scripts (Game, Main, player, enemies, weapons, ui, world)
│   ├── utils/               # Shared GDScript helpers (Helpers.gd)
│   ├── check_bg.py          # Enemy sprite PNG alpha verification
│   ├── check_coverage.py    # 100% unit/fuzz/Python coverage verifier
│   ├── check_deadcode.py    # Dead script, scene, and symbol scanner
│   ├── remove_bg.py         # Sprite background transparency utility
│   └── run_tests.gd         # Headless SceneTree test runner
├── tests/
│   ├── unit/                # GUT unit tests
│   ├── integration/         # GUT integration tests
│   ├── fuzz/                # GUT fuzz tests
│   ├── regression/          # GUT regression tests
│   └── python/              # Python unittest + fuzz tests
├── Makefile                 # Build, test, lint, deadcode, coverage, and export automation
└── project.godot            # Godot 4.7.2 project configuration
```

## Documentation

- [Game Design Document](docs/design.md)
- [Boss Guide & Screenshots](docs/bosses.md)
- [Architecture Overview](docs/architecture.md)
- [Development Guide](docs/development.md)
- [Technical Roadmap](docs/roadmap.md)

## License

MIT
