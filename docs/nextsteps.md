# End of Level Boss Fights Implementation Plan

## Goal Description
Design and implement three new distinct boss encounters to enhance the game's vehicular combat progression. The game will now feature four distinct boss levels, culminating in a final showdown against the Boss War Rig.

## Vehicular Combat Analysis & Design
Classic vehicular combat games (e.g., *Spy Hunter*, *Twisted Metal*, *Mad Max*) utilize bosses to force players to adapt their playstyle:
- **Swarm / Area Denial**: Bosses that spawn lesser entities force the player to divide their attention between dodging/killing minions and damaging the boss.
- **Evasion**: Bosses that actively dodge force the player to use area-of-effect weapons (like mines/EMPs) or time their shots carefully.

### 1. BossBunny (Level 1)
- **Archetype**: Minion Spawner / Area Denial
- **Mechanics**: Stays ahead of the player and periodically spawns `BabyBunnyBomb` entities.
- **BabyBunnyBomb**: Small enemies that hop down the lanes. They slowly track the player's X-position and explode on contact for minor damage. They can be destroyed by player weapons.

### 2. BossSasquatch (Level 2)
- **Archetype**: Evasive / Artillery
- **Mechanics**: Actively dodges player fire by rapidly switching lanes when attacked. Periodically hurls `PoopWeapon` projectiles at the player.
- **PoopWeapon**: A projectile that moves down the screen. If it hits the player, it deals damage and applies a temporary "slippery" debuff (similar to driving on ice).

### 3. BossVoidDrone (Level 3)
- **Archetype**: Swarm Commander / Bullet Hell
- **Mechanics**: A massive hovering drone that acts as a carrier. Periodically summons waves of standard `Drone` enemies to overwhelm the player, while occasionally firing heavy laser blasts.

### 4. BossWarRig (Level 4 - Final Boss)
- **Archetype**: Heavy Juggernaut
- **Mechanics**: The existing War Rig fight. Spawns waves of Scavs and attempts to ram the player. This is the grand finale of the run.

## Proposed Changes

### Configuration & Core Logic

#### [MODIFY] [Constants.gd](file:///Users/rsd/REPOS/RaceToDeadEnd/scripts/autoload/Constants.gd)
- Define new constants for `BOSS_BUNNY_HP`, `BOSS_SASQUATCH_HP`, `BOSS_VOID_DRONE_HP`.
- Define attack intervals and projectile speeds for the new bosses.

#### [MODIFY] [Spawner.gd](file:///Users/rsd/REPOS/RaceToDeadEnd/scripts/scenes/world/Spawner.gd)
- Preload the new boss scenes into `enemy_scenes`.
- Refactor `_spawn_boss()` to use `_bosses_spawned` to determine which boss to instantiate:
  - `0`: BossBunny
  - `1`: BossSasquatch
  - `2`: BossVoidDrone
  - `>= 3`: BossWarRig

#### [MODIFY] [Game.gd](file:///Users/rsd/REPOS/RaceToDeadEnd/scripts/scenes/Game.gd)
- Initialize `ObjectPool` entries for `boss_bunny`, `baby_bunny_bomb`, `boss_sasquatch`, `poop_weapon`, `boss_void_drone`.

---

### Level 1: BossBunny
#### [NEW] `scenes/enemies/BossBunny.tscn` & `scripts/scenes/enemies/BossBunny.gd`
- Inherits `Enemy`. Implements a timer to spawn `BabyBunnyBomb`s.
#### [NEW] `scenes/weapons/BabyBunnyBomb.tscn` & `scripts/scenes/weapons/BabyBunnyBomb.gd`
- Inherits `Enemy` (so it can take damage). Has a slight homing behavior towards the player's X coordinate. Explodes and deals 1 damage on player collision.

---

### Level 2: BossSasquatch
#### [NEW] `scenes/enemies/BossSasquatch.tscn` & `scripts/scenes/enemies/BossSasquatch.gd`
- Inherits `Enemy`. Implements a `_process` check: if a player bullet is approaching in the same lane, it triggers a `_dodge()` maneuver to switch lanes.
- Throws `PoopWeapon` projectiles on a timer.
#### [NEW] `scenes/weapons/PoopWeapon.tscn` & `scripts/scenes/weapons/PoopWeapon.gd`
- Inherits `Area2D` (similar to `Bullet.gd`). Travels downwards and triggers damage/status effect on player collision.

---

### Level 3: BossVoidDrone
#### [NEW] `scenes/enemies/BossVoidDrone.tscn` & `scripts/scenes/enemies/BossVoidDrone.gd`
- Inherits `Enemy`. Uses `spawn_minion_requested` signals to tell `Spawner.gd` to dispatch waves of standard drones. 

## Verification Plan

### Automated Tests
- Create `tests/unit/test_bosses.gd`.
- Verify `BossBunny` correctly spawns bombs.
- Verify `BossSasquatch` successfully changes lanes when a bullet enters its lane.
- Verify `Spawner.gd` rotates through the boss types sequentially and caps at the War Rig.
