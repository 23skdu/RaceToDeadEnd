extends "res://scenes/enemies/Enemy.gd"

var shoot_timer: float = 0.0
var shoot_interval: float = 2.5
var target_player_x: float = 0.0
var ramming: bool = false

signal enemy_fired_bullet(position: Vector2, direction: Vector2)

func _ready() -> void:
	super._ready()
	shoot_timer = shoot_interval * randf_range(0.5, 1.5)

func _physics_process(delta: float) -> void:
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval
		enemy_fired_bullet.emit($WeaponMount.global_position, Vector2.DOWN)
	velocity.y = -speed
	move_and_slide()
