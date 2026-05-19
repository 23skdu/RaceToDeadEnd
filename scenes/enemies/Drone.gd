extends "res://scenes/enemies/Enemy.gd"

var bomb_timer: float = 0.0
var bomb_interval: float = 3.0
var target_x: float = 0.0
var marker_visible: bool = false

signal bomb_dropped(position: Vector2)

func _ready() -> void:
	super._ready()
	bomb_timer = bomb_interval * randf_range(0.5, 1.5)

func _physics_process(delta: float) -> void:
	bomb_timer -= delta
	var diff = target_x - position.x
	velocity.x = move_toward(velocity.x, diff * 4.0, 100.0 * delta)
	velocity.y = -speed * 0.6
	move_and_slide()
	if bomb_timer <= 0.0 and not marker_visible:
		_drop_bomb()

func set_target_x(player_x: float) -> void:
	target_x = player_x

func _drop_bomb() -> void:
	marker_visible = true
	bomb_timer = bomb_interval
	bomb_dropped.emit(global_position + Vector2(0, 64))
