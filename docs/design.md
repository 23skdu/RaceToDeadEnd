# Race to Dead End — Game Design Document

## Part 1: Game Concept & Elevator Pitch

Race to Dead End is an isometric vehicular combat racing game inspired by Spy Hunter (1983, Bally Midway). You drive a heavily armed futuristic interceptor down an endless multi-lane highway, fighting off zombie bikers, post-apocalyptic gang trucks, and alien saucers. The goal is to survive as long as possible, rack up kills, and beat your high score — no finish line, just the dead end.

## Part 2: Core Inspirations from Spy Hunter

| Spy Hunter Mechanic | Our Adaptation |
|---|---|
| Top-down vertical scrolling | **Isometric (2.5D)** perspective |
| G-6155 Interceptor spy car | Armageddon-class interceptor with modular weapons |
| Machine guns, oil slicks, smoke | Machine guns, missiles, EMP burst, mines |
| Weapons van upgrade | Wreckage salvage drops from destroyed enemies |
| Civilian cars (penalty for hitting) | Civilian convoys (bonus for protecting) |
| Water/boat transformation | Terrain lane hazards (ice, debris, oil) |
| Endless road with score pacing | Endless procedural highway with difficulty waves |
| Helicopter bomb enemies | Alien saucers with laser bombardment |

## Part 3: Story & World Setting

Year 2187. The last remaining highway — the Pan-Continental Arterial — stretches across a poisoned Earth. Society collapsed decades ago. Three factions rule the road:
- **Bunnies** — infected zombie rabbits, the first mutated stage of the plague; mindless and swarm in packs
- **Rotors** — zombie-like plague victims on souped-up motorcycles, mindless, swarm tactics
- **Scavs** — post-apocalyptic warrior clans driving armored pickups with turrets
- **Void Drones** — alien reconnaissance saucers that descended during the chaos

You are a lone runner piloting the last military-grade interceptor, racing toward the fabled Dead End — a fortress city rumored to be humanity's final safe zone.

## Part 4: Visual Perspective & Art Direction

- **Camera**: Fixed isometric (2.5D) ~45-degree angle, scrolling vertically as the player advances
- **Style**: Dark, gritty neon-apocalyptic — think Mad Max meets Blade Runner in pseudo-3D
- **Color palette**: Desaturated browns/grays for road and terrain; neon cyan, magenta, and orange for enemy factions and HUD
- **Tile resolution**: 64×32 isometric tiles for road, 32×32 sprites for vehicles (scaled to isometric grid)
- **Weather system**: Dynamic fog, dust storms, acid rain (visual-only phase 1, gameplay-affecting phase 2)

## Part 5: Core Gameplay Loop

1. Drive forward (auto-scroll or player-controlled speed)
2. Dodge/weave between lanes to avoid enemies
3. Shoot/use weapons to destroy threats
4. Collect salvage drops from destroyed enemies
5. Avoid civilian vehicles (or protect them for bonus)
6. Survive increasingly difficult waves
7. Die → view score → restart

The highway is divided into **segments** (each ~10 seconds of driving). Every 5 segments, a difficulty tier increases — more enemies, faster speeds, new enemy types.

## Part 6: Player Vehicle & Abilities

**Interceptor MK-VI** stats:
- **Speed**: Fixed base speed + boost meter (3 charges, refills slowly)
- **Health**: 5 hit points (repair pickups restore 1 HP)
- **Lane switching**: Left/right across 8 lanes + weave (quick dodge)
- **Boost**: Temporary 2× speed, grants collision immunity during activation

**Controls** (keyboard/gamepad):
- Up/Down: Accelerate/brake (or auto-accelerate with speed control)
- Left/Right: Lane change
- Space / A button: Primary weapon (machine gun)
- Shift / X button: Secondary weapon (missile/mine/EMP — cycle)
- Tab / Y button: Boost

## Part 7: Enemy Types & AI Behavior

### Bunnies (Infected Zombie Bunnies)
- **Appearance**: Small pink-hued rabbit shapes with menacing red eyes
- **Behavior**: Hop toward the player's lane, contact-only damage
- **Speed**: Slightly slower than player base speed
- **HP**: 1 hit
- **Attack**: Contact damage (1 HP)
- **Note**: Only appear before the first boss (BossBunny) — they are the introductory enemy type

### Rotors (Zombie Bikers)
- **Appearance**: Hunched figures on rusted bikes, glowing red eyes
- **Behavior**: Swarm from behind, try to flank and sideswipe
- **Speed**: Equal to player base speed
- **HP**: 1 hit
- **Attack**: Bump damage (1 HP)

### Sasquatches (Wandering Brutes)
- **Appearance**: Large brown shaggy humanoid figures
- **Behavior**: Wanders between lanes, dodges player attacks, throws projectiles
- **Speed**: Slower than player base speed
- **HP**: 5 hits
- **Attack**: Ranged projectile (causes slippery effect on hit)
- **Note**: Random wandering monster that starts appearing after the 2nd boss fight (Giant Biker)

### Scavs (Warrior Pickups)
- **Appearance**: Armored trucks with roof gunners, faction colors
- **Behavior**: Drive alongside and shoot; some try to box the player in
- **Speed**: Slightly slower, accelerate when attacking
- **HP**: 3 hits
- **Attack**: Gun turret (pew pew style)

### Void Drones (Alien Saucers)
- **Appearance**: Glowing metallic discs with pulsing energy core
- **Behavior**: Hover above road, drop laser markers then bombard
- **Speed**: Slow forward, track player horizontally
- **HP**: 2 hits
- **Attack**: Bombardment (delay + explosion AOE)

### Civilians
- Non-hostile vehicles (convoys, trucks)
- Collision penalty: lose 1 HP, score freeze 5 seconds
- Protecting them (blocking enemies) gives bonus score

## Part 8: Weapons, Power-ups & Upgrades

### Primary: Machine Gun
- Unlimited ammo, continuous fire
- Rapid fire, low damage per hit

### Secondary (cycle through 3):
1. **Missile** (3 ammo max) — lock-on, fires ahead, destroys any enemy in 1 hit
2. **Mine** (2 ammo max) — drops behind, AOE blast
3. **EMP Burst** (1 ammo max) — screen-wide stun, damages all enemies for 1 HP

### Power-ups (from destroyed enemies):
- **Repair Kit** — restores 1 HP
- **Boost Charge** — refills one boost charge
- **Ammo Drop** — refills secondary ammo
- **Score Multiplier** — 2× points for 10 seconds

### Upgrade system (per-run progression):
- Kill Streak milestones grant weapon upgrades (e.g., faster fire rate, missile homing improvement)
- Persistent meta-upgrades (between runs) using credits earned: max HP, boost capacity, starting weapon tier

## Part 9: Environment, Terrain & Levels

The highway is procedurally generated in real-time from tile chunks:

**Road types** (rotated per segment):
- **Standard** — 8 lanes, clear driving
- **Debris-strewn** — obstacles in random lanes, must dodge
- **Icy** — reduced traction, lane changes slide
- **Construction** — narrower lanes, barriers
- **Bridge** — no shoulder, environmental death if forced off

**Environmental hazards**:
- Abandoned vehicles (stationary obstacles)
- Oil slicks (spin-out hazard, also usable offensively)
- Road fractures (slow you down if hit)

**Background scenery layers** (parallax):
- Near: Guardrails, signs, debris
- Mid: Ruined buildings, billboards
- Far: Mountains, alien skybeams, burning refineries

## Part 10: Progression, Scoring & Replayability

### In-run scoring:
- +10 pts/sec base driving
- +50 per kill (Bunnies/Rotors), +100 (Scavs), +200 (Drones), +300 (Sasquatches)
- +500 for protecting a civilian convoy wave
- Multiplier from power-ups stacks additively (max 8×)

### Run milestones:
- Every 3000 pts = new difficulty tier unlock
- Every 3000 pts = boss encounter (BossBunny → Giant Biker → War Rig → Void Drone)

### Meta-progression (between runs):
- Credits earned = score / 10
- Spend credits in garage on:
  - +Max HP (upgrade tiers)
  - +Boost capacity
  - +Starting secondary ammo
  - Unlock weapon variants
  - Cosmetic skins for the interceptor

### Replayability hooks:
- Leaderboard (local, later online)
- Achievement badges for kill counts, distance milestones, no-hit segments
- Daily run challenge (same seed for all players)
