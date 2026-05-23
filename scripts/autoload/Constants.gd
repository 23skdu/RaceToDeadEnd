extends Node

# Highway / Lane
const LANE_POSITIONS: Array[float] = [-120.0, -72.0, -24.0, 24.0, 72.0, 120.0]
const LANE_WIDTH: float = 48.0
const LANE_COUNT: int = 6
const SPAWN_DISTANCE: float = 450.0
const CLEANUP_DISTANCE: float = 450.0
const BASE_SPEED: float = 200.0

# Difficulty
const TIER_THRESHOLD: int = 1000
const MAX_TIER: int = 20
const SEGMENT_DIFFICULTY_BONUS: float = 200.0
const SCORE_RATE: int = 10

# Spawner
const BASE_WAVE_INTERVAL: float = 5.0
const MIN_WAVE_INTERVAL: float = 2.0
const WAVE_INTERVAL_DECAY: float = 0.3

# Enemies
const SCAV_SHOOT_INTERVAL: float = 2.5
const DRONE_BOMB_INTERVAL: float = 3.0
const ROTOR_SPEED_MULTIPLIER: float = 0.9
const SCAV_SPEED_MULTIPLIER: float = 0.7
const DRONE_SPEED_MULTIPLIER: float = 0.5

# Weather
const RAIN_DROP_COUNT: int = 200
const LIGHTNING_DAMAGE: int = 1
const ACID_RAIN_DAMAGE_INTERVAL: float = 2.0
const ACID_RAIN_DAMAGE: int = 1
const CLOUD_COUNT: int = 5
const LIGHTNING_CHANCE_PER_SECOND: float = 0.15

# Player
const BOOST_SPEED_MULTIPLIER: float = 2.0
const WEAVE_DISTANCE: float = 128.0
const WEAVE_COOLDOWN: float = 0.5
const BOOST_DURATION: float = 1.5
const BOOST_RECHARGE_TIME: float = 8.0
const PRIMARY_FIRE_COOLDOWN: float = 0.1
const DOUBLE_TAP_DELAY: float = 0.25
const ACCEL_SPEED: float = 300.0
const REVERSE_SPEED: float = -350.0

# Multiplier
const MULTIPLIER_DURATION: float = 10.0

# Bullet
const ENEMY_CACHE_INTERVAL: float = 0.25
const BULLET_SPEED: float = 500.0

# Mine
const MINE_DAMAGE: int = 2
const MINE_EXPLOSION_RADIUS: float = 64.0
const MINE_ARM_TIME: float = 0.5

# EMP
const EMP_DAMAGE: int = 1
const EMP_STUN_DURATION: float = 2.0
const EMP_EXPAND_SPEED: float = 400.0
const EMP_MAX_RADIUS: float = 400.0

# Drone Bomb
const DETONATION_TIME: float = 1.5
const BLAST_RADIUS: float = 80.0

# World / Camera
const WORLD_SCALE: Vector2 = Vector2(1.0, 0.5)
const CAMERA_Y_OFFSET: float = -100.0

# Civilian
const CIVILIAN_SPEED: float = 150.0
const CIVILIAN_SPAWN_CHANCE: float = 0.15
const CIVILIAN_BONUS: int = 500
const CIVILIAN_PENALTY: int = 1

# Boss
const BOSS_SCORE_INTERVAL: int = 3000
const BOSS_WAR_RIG_HP: int = 20
const BOSS_ALIEN_CARRIER_HP: int = 15
const BOSS_SCORE: int = 1000
const BOSS_ATTACK_INTERVAL: float = 2.0

# Visual
const SPRITE_BASE_SIZE: float = 64.0
const SPRITE_BASE_VIEWPORT: float = 1280.0
const GUARDRAIL_WIDTH: float = 3.0
const SCAV_FLANK_OFFSET: float = 64.0

# HUD Multiplier Bar
const MULTIPLIER_BAR_WIDTH: float = 120.0
const MULTIPLIER_BAR_HEIGHT: float = 8.0

# Weapon Data (shared between Interceptor and HUD)
const WEAPON_DATA: Array[Dictionary] = [
	{type_name = "missile", display_name = "Homing Missile", color = Color.RED, base_ammo = 30},
	{type_name = "mine", display_name = "Proximity Mine", color = Color.YELLOW, base_ammo = 15},
	{type_name = "emp", display_name = "EMP Blast", color = Color.CYAN, base_ammo = 5},
]

# Weather Colors
const RAIN_DROPLET_COLOR: Color = Color(0.5, 0.6, 0.8, 0.5)
const RAIN_DROPLET_ZERO_ALPHA: Color = Color(0.5, 0.6, 0.8, 0.0)
const RAIN_PARTICLE_CLEAR: Color = Color(0.5, 0.6, 0.8, 0.3)
const RAIN_PARTICLE_ACID: Color = Color(0.2, 0.9, 0.2, 0.5)
const RAIN_PARTICLE_STORM: Color = Color(0.3, 0.8, 0.3, 0.6)
const LIGHTNING_BOLT_COLOR: Color = Color(0.8, 0.9, 1.0, 1.0)
const LIGHTNING_FLASH_COLOR: Color = Color(0.9, 0.95, 1.0, 0.8)
const CLOUD_BODY_COLOR: Color = Color(0.15, 0.1, 0.2, 0.7)
const CLOUD_GLOW_COLOR: Color = Color(0.0, 0.8, 0.2, 0.2)
const ACID_OVERLAY_CLEAR: Color = Color(0, 0, 0, 0)
const ACID_OVERLAY_COLOR_LIGHT: Color = Color(0.1, 0.3, 0.1, 0.15)
const ACID_OVERLAY_COLOR_HEAVY: Color = Color(0.15, 0.2, 0.15, 0.25)

const ACID_OVERLAY_ALPHA_LIGHT: float = 0.15
const ACID_OVERLAY_ALPHA_HEAVY: float = 0.25
