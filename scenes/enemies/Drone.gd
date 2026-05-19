extends "res://scenes/enemies/Enemy.gd"

const BOMB_SCRIPT = preload("res://scenes/weapons/DroneBomb.gd")

var bomb_timer: float = 0.0
var bomb_interval: float = 3.0
var target_x: float = 0.0
var player: Node = null

func _ready() -> void:
	super._ready()
	bomb_timer = bomb_interval * randf_range(0.5, 1.5)

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			
	if player:
		target_x = player.global_position.x
		
		# Hover 180 pixels ahead of player to drop markers
		var target_y = player.global_position.y - 180.0
		var diff_y = target_y - position.y
		velocity.y = player.velocity.y + diff_y * 2.0
		
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
	# Instantiate script-based Area2D bomb
	var bomb = Area2D.new()
	bomb.set_script(BOMB_SCRIPT)
	get_parent().add_child(bomb)
	
	# Drop slightly behind the drone on the road
	bomb.global_position = global_position + Vector2(0, 48)
