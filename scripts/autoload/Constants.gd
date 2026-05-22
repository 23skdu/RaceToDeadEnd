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
