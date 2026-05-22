extends CharacterBody2D

signal destroyed(position: Vector2, enemy_type: String)

enum EnemyType { ROTOR, SCAV, DRONE }

const TYPE_NAMES: Array[String] = ["rotor", "scav", "drone"]
const ROTOR_TEXTURE = preload("res://assets/sprites/enemies/rotor.png")
const SCAV_TEXTURE = preload("res://assets/sprites/enemies/scav.png")
const DRONE_TEXTURE = preload("res://assets/sprites/enemies/drone.png")

var enemy_type: EnemyType = EnemyType.ROTOR
var hp: int = 1
var speed: float = 200.0
var lane: int = 0
var score_value: int = 50
var can_damage_player: bool = true
var player: Node = null
var stunned: bool = false
var stun_timer: float = 0.0
var _spawner: Node = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hit_flash_timer: Timer = $HitFlashTimer

const BASE_SPRITE_SIZE: float = 64.0
const BASE_VIEWPORT_WIDTH: float = 1280.0

func _ready() -> void:
	collision_layer = 2
	z_index = 1
	add_to_group("enemy")
	_scale_sprite()

func init(type: EnemyType, start_lane: int, player_ref: Node, base_speed: float, spawner: Node = null) -> void:
	enemy_type = type
	lane = start_lane
	player = player_ref
	_spawner = spawner
	match type:
		EnemyType.ROTOR:
			hp = 1
			speed = base_speed * Constants.ROTOR_SPEED_MULTIPLIER
			score_value = 50
		EnemyType.SCAV:
			hp = 3
			speed = base_speed * Constants.SCAV_SPEED_MULTIPLIER
			score_value = 100
		EnemyType.DRONE:
			hp = 2
			speed = base_speed * Constants.DRONE_SPEED_MULTIPLIER
			score_value = 200
	_update_sprite()

func _update_sprite() -> void:
	match enemy_type:
		EnemyType.ROTOR:
			sprite.texture = ROTOR_TEXTURE
		EnemyType.SCAV:
			sprite.texture = SCAV_TEXTURE
		EnemyType.DRONE:
			sprite.texture = DRONE_TEXTURE
	_scale_sprite()

func _scale_sprite() -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	var viewport_width = viewport.get_visible_rect().size.x
	var scale_factor = viewport_width / BASE_VIEWPORT_WIDTH
	var target_size = BASE_SPRITE_SIZE * scale_factor
	if sprite.texture:
		var tex_height = sprite.texture.get_height()
		var current_scale = target_size / tex_height
		sprite.scale = Vector2(current_scale, current_scale)

func _physics_process(delta: float) -> void:
	if stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			stunned = false
			sprite.modulate = Color.WHITE

func apply_stun(duration: float) -> void:
	stunned = true
	stun_timer = duration
	sprite.modulate = Color(0.5, 0.5, 1.0, 0.7)

func take_damage(amount: int = 1) -> void:
	hp -= amount
	_play_hit_flash()
	_play_hit_sound()
	if hp <= 0:
		_die()

func on_pool_release() -> void:
	stunned = false
	stun_timer = 0.0
	hp = 1
	speed = 200.0
	sprite.modulate = Color.WHITE
	velocity = Vector2.ZERO

func _play_hit_sound() -> void:
	match enemy_type:
		EnemyType.ROTOR:
			AudioManager.play_rotor_hit(global_position)
		EnemyType.SCAV:
			AudioManager.play_scav_hit(global_position)
		EnemyType.DRONE:
			AudioManager.play_drone_hit(global_position)

func _play_hit_flash() -> void:
	if not stunned:
		sprite.modulate = Color.RED
	hit_flash_timer.start()

func _on_hit_flash_timer_timeout() -> void:
	if not stunned:
		sprite.modulate = Color.WHITE

func _die() -> void:
	_play_death_sound()
	CameraShake.shake(0.3, 0.2, 4.0)
	destroyed.emit(global_position, TYPE_NAMES[enemy_type])
	if _spawner and destroyed.is_connected(_spawner._on_enemy_destroyed):
		destroyed.disconnect(_spawner._on_enemy_destroyed)
	ObjectPool.release(self)

func _play_death_sound() -> void:
	match enemy_type:
		EnemyType.ROTOR:
			AudioManager.play_rotor_death(global_position)
		EnemyType.SCAV:
			AudioManager.play_scav_death(global_position)
		EnemyType.DRONE:
			AudioManager.play_drone_death(global_position)
