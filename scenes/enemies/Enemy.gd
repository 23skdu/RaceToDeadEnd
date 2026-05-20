extends CharacterBody2D

signal destroyed(position: Vector2, enemy_type: String)

enum EnemyType { ROTOR, SCAV, DRONE }

const TYPE_NAMES: Array[String] = ["rotor", "scav", "drone"]

var enemy_type: EnemyType = EnemyType.ROTOR
var hp: int = 1
var speed: float = 200.0
var lane: int = 0
var score_value: int = 50
var can_damage_player: bool = true
var player: Node = null
var stunned: bool = false
var stun_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hit_flash_timer: Timer = $HitFlashTimer

func _ready() -> void:
	collision_layer = 2
	add_to_group("enemy")

func init(type: EnemyType, start_lane: int, player_ref: Node, base_speed: float) -> void:
	enemy_type = type
	lane = start_lane
	player = player_ref
	match type:
		EnemyType.ROTOR:
			hp = 1
			speed = base_speed * 0.9
			score_value = 50
		EnemyType.SCAV:
			hp = 3
			speed = base_speed * 0.7
			score_value = 100
		EnemyType.DRONE:
			hp = 2
			speed = base_speed * 0.5
			score_value = 200
	_update_sprite()

func _update_sprite() -> void:
	match enemy_type:
		EnemyType.ROTOR:
			sprite.texture = load("res://assets/sprites/enemies/rotor.png") if ResourceLoader.exists("res://assets/sprites/enemies/rotor.png") else null
		EnemyType.SCAV:
			sprite.texture = load("res://assets/sprites/enemies/scav.png") if ResourceLoader.exists("res://assets/sprites/enemies/scav.png") else null
		EnemyType.DRONE:
			sprite.texture = load("res://assets/sprites/enemies/drone.png") if ResourceLoader.exists("res://assets/sprites/enemies/drone.png") else null

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
	if hp <= 0:
		_die()

func _play_hit_flash() -> void:
	if not stunned:
		sprite.modulate = Color.RED
	hit_flash_timer.start()

func _on_hit_flash_timer_timeout() -> void:
	if not stunned:
		sprite.modulate = Color.WHITE

func _die() -> void:
	destroyed.emit(global_position, TYPE_NAMES[enemy_type])
	queue_free()
