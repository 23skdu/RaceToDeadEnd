extends CharacterBody2D

signal destroyed(position: Vector2, enemy_type: String)

enum EnemyType { ROTOR, SCAV, DRONE }

var enemy_type: EnemyType = EnemyType.ROTOR
var hp: int = 1
var speed: float = 200.0
var lane: int = 0
var score_value: int = 50
var can_damage_player: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hit_flash_timer: Timer = $HitFlashTimer

func _ready() -> void:
	add_to_group("enemy")

func init(type: EnemyType, start_lane: int, player_speed: float) -> void:
	enemy_type = type
	lane = start_lane
	match type:
		EnemyType.ROTOR:
			hp = 1
			speed = player_speed * 0.9
			score_value = 50
		EnemyType.SCAV:
			hp = 3
			speed = player_speed * 0.7
			score_value = 100
		EnemyType.DRONE:
			hp = 2
			speed = player_speed * 0.5
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

func take_damage(amount: int = 1) -> void:
	hp -= amount
	_play_hit_flash()
	if hp <= 0:
		_die()

func _play_hit_flash() -> void:
	sprite.modulate = Color.RED
	hit_flash_timer.start()

func _on_hit_flash_timer_timeout() -> void:
	sprite.modulate = Color.WHITE

func _die() -> void:
	destroyed.emit(global_position, EnemyType.keys()[enemy_type].to_lower())
	queue_free()

func _on_visible_on_screen_notifier_screen_exited() -> void:
	queue_free()
