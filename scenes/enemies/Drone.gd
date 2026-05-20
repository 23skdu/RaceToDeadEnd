extends "res://scenes/enemies/Enemy.gd"

const BOMB_SCENE = preload("res://scenes/weapons/DroneBomb.tscn")

var bomb_timer: float = 0.0
var bomb_interval: float = 3.0
var target_x: float = 0.0
var world_node: Node = null

func _ready() -> void:
	super._ready()
	bomb_timer = bomb_interval * randf_range(0.5, 1.5)

func _physics_process(delta: float) -> void:
	if stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if player and is_instance_valid(player):
		target_x = player.global_position.x
		
		var target_y = player.global_position.y - 180.0
		var diff_y = target_y - position.y
		velocity.y = -speed + diff_y * 2.0
		
		var diff_x = target_x - position.x
		velocity.x = move_toward(velocity.x, diff_x * 4.0, 150.0 * delta)
	else:
		velocity.x = 0.0
		velocity.y = -speed * 0.6

	bomb_timer -= delta
	if bomb_timer <= 0.0:
		_drop_bomb()
		
	move_and_slide()

func _drop_bomb() -> void:
	bomb_timer = bomb_interval
	if not player:
		return
	var bomb = BOMB_SCENE.instantiate()
	if world_node:
		world_node.add_child(bomb)
	elif get_parent():
		get_parent().add_child(bomb)
	else:
		return
	
	bomb.global_position = global_position + Vector2(0, 48)
