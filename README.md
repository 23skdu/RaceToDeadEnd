<img width="1024" height="1024" alt="image" src="https://github.com/user-attachments/assets/73206466-a21d-4f86-8c64-89a932b66d07" />

# Race to Dead End

Isometric vehicular combat racing game. Drive a futuristic interceptor down an endless highway, fighting zombie bunnies, zombie bikers, post-apocalyptic gang trucks, and alien saucers. Inspired by Spy Hunter (1983).

## Setup

1. Download Godot 4.4+ from [godotengine.org](https://godotengine.org)
2. Clone this repo
3. Open the project in Godot (import `project.godot`)
4. Press F5 to run

## Controls

| Action | Key |
| --- | --- |
| Move left/right | A / D |
| Accelerate | W |
| Brake | S |
| Primary fire | Space |
| Secondary fire | Shift |
| Boost | Tab |
| Cycle weapon | Q |

## Development

- **Engine**: Godot 4.4+
- **Scripting**: GDScript
- **Art**: Placeholder colored sprites (replace with actual assets)
- **Physics**: GodotPhysics 2D

## Directory Structure

```text
res://
├── assets/          # Sprites, audio, tilesets
├── addons/          # External plugins
├── docs/            # Architecture and planning documentation
├── scenes/          # Visual .tscn files
│   ├── enemies/     # Rotor, Scav, Drone
│   ├── player/      # Interceptor
│   ├── ui/          # HUD, GameOver, Garage
│   ├── weapons/     # Bullet, Missile, Mine, EMPBlast
│   └── world/       # Highway, Spawner
├── scripts/         # All .gd and .py scripts
│   ├── autoload/    # Singleton scripts (GameManager, ScoreManager, AudioManager)
│   ├── scenes/      # Scene-specific logic
│   └── utils/       # Shared utility scripts
└── tests/           # GUT unit and integration tests
```

## License

MIT
