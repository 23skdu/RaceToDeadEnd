extends Node

# Highway / Lane
const LANE_POSITIONS: Array[float] = [-420.0, -300.0, -180.0, -60.0, 60.0, 180.0, 300.0, 420.0]
const LANE_WIDTH: float = 120.0
const LANE_COUNT: int = 8
const SPAWN_DISTANCE: float = 450.0
const CLEANUP_DISTANCE: float = 450.0
const BASE_SPEED: float = 200.0

# Difficulty
const TIER_THRESHOLD: int = 3000
const MAX_TIER: int = 20
const SEGMENT_DIFFICULTY_BONUS: float = 200.0
const SCORE_RATE: int = 10
const SPEED_PER_TIER: float = 15.0
const MAX_GAME_SPEED: float = 600.0

# Spawner
const BASE_WAVE_INTERVAL: float = 5.0
const MIN_WAVE_INTERVAL: float = 2.0
const WAVE_INTERVAL_DECAY: float = 0.3

# Enemies
const BUNNY_SPEED_MULTIPLIER: float = 0.85
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
const REVERSE_SPEED: float = 400.0

# Multiplier
const MULTIPLIER_DURATION: float = 10.0

# Bullet
const ENEMY_CACHE_INTERVAL: float = 0.25
const BULLET_SPEED: float = 500.0
const BULLET_SPEED_OFFSET: float = 500.0

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
const CAMERA_Y_OFFSET: float = -220.0

# Highway Perspective
const HIGHWAY_PERSPECTIVE_MIN_SCALE: float = 0.28
const HIGHWAY_PERSPECTIVE_STRENGTH: float = 0.65
const HORIZON_Y_NORMALIZED: float = 0.12

# Civilian
const CIVILIAN_SPEED: float = 150.0
const CIVILIAN_SPAWN_CHANCE: float = 0.15
const CIVILIAN_BONUS: int = 500
const CIVILIAN_PENALTY: int = 1

# Boss
const BOSS_SCORE_INTERVAL: int = 3000
const BOSS_BUNNY_HP: int = 25
const BOSS_GIANT_BIKER_HP: int = 35
const BOSS_SASQUATCH_HP: int = 15
const BOSS_VOID_DRONE_HP: int = 45
const BOSS_WAR_RIG_HP: int = 60
const BOSS_SCORE: int = 1000
const BOSS_ATTACK_INTERVAL: float = 1.5

# Visual
const SPRITE_BASE_SIZE: float = 57.6
const SPRITE_BASE_VIEWPORT: float = 1280.0
const GUARDRAIL_WIDTH: float = 3.0
const SCAV_FLANK_OFFSET: float = 64.0

# HUD Multiplier Bar
const MULTIPLIER_BAR_WIDTH: float = 120.0
const MULTIPLIER_BAR_HEIGHT: float = 8.0

# Fire Rate Upgrade
const FIRE_RATE_STEP: float = 0.01
const FIRE_RATE_MIN: float = 0.05
const FIRE_RATE_MAX: float = 0.1

# Scav
const SCAV_RAM_DIST_Y: float = 120.0
const SCAV_RAM_DIST_X: float = 80.0
const SCAV_LATERAL_RAM_SPEED: float = 300.0
const SCAV_LATERAL_NORMAL_SPEED: float = 150.0

# Boss
const BOSS_RAM_FORCE: float = 200.0
const BOSS_RAM_SPEED: float = 500.0

# Highway chunk weights
const CHUNK_WEIGHT_STANDARD_BASE: float = 40.0
const CHUNK_WEIGHT_DEBRIS_BASE: float = 20.0
const CHUNK_WEIGHT_ICE_BASE: float = 10.0
const CHUNK_WEIGHT_CONSTRUCTION_BASE: float = 15.0
const CHUNK_WEIGHT_BRIDGE_BASE: float = 15.0
const CHUNK_HAZARD_CAP: int = 10
const CHUNK_HAZARD_STEP: int = 2
const CHUNK_WEIGHT_STANDARD_MIN: float = 15.0
const CHUNK_WEIGHT_DEBRIS_MAX: float = 35.0
const CHUNK_WEIGHT_ICE_MAX: float = 25.0
const CHUNK_WEIGHT_CONSTRUCTION_MAX: float = 30.0
const CHUNK_WEIGHT_BRIDGE_MAX: float = 30.0

# Highway
const GUARDRAIL_COLOR: Color = Color(1.0, 1.0, 0.8)
const BRIDGE_GUARDRAIL_COLOR: Color = Color(0.0, 0.8, 1.0)

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

# Player Car Skins
const PLAYER_SKINS: Array[Dictionary] = [
	{
		"id": "default",
		"name": "Interceptor Classic",
		"description": "Standard MK-VI Cyan-Navy Alloy",
		"texture_path": "res://assets/sprites/player/interceptor.svg",
		"use_default_modulate": true,
		"colors": ["#1a2a3a", "#00ffcc", "#ff6600"],
		"unlock_boss": false,
	},
	{
		"id": "crimson_viper",
		"name": "Crimson Viper",
		"description": "Twin-Stripe Obsidian & Scarlet",
		"texture_path": "res://assets/sprites/player/interceptor_crimson_viper.svg",
		"use_default_modulate": false,
		"colors": ["#1c090e", "#ff1e42", "#ffcc33"],
		"unlock_boss": false,
	},
	{
		"id": "toxic_volt",
		"name": "Toxic Volt",
		"description": "Hazard-Chevron Charcoal & Acid Lime",
		"texture_path": "res://assets/sprites/player/interceptor_toxic_volt.svg",
		"use_default_modulate": false,
		"colors": ["#161b18", "#99ff00", "#ffee00"],
		"unlock_boss": false,
	},
	{
		"id": "solar_chrome",
		"name": "Solar Chrome",
		"description": "Synthwave Silver & Sunset Slashes",
		"texture_path": "res://assets/sprites/player/interceptor_solar_chrome.svg",
		"use_default_modulate": false,
		"colors": ["#9aa8bc", "#ff2a85", "#ff7b00"],
		"unlock_boss": false,
	},
	{
		"id": "urban_camo",
		"name": "Urban Camo",
		"description": "Special Stealth Camouflage (Defeat 1st Boss)",
		"texture_path": "res://assets/sprites/player/interceptor_urban_camo.svg",
		"use_default_modulate": false,
		"colors": ["#2b3038", "#6b7482", "#b4becb"],
		"unlock_boss": true,
	},
]
