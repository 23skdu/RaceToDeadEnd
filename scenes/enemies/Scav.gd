extends "res://scenes/enemies/Enemy.gd"

const BULLET_SCENE = preload("res://scenes/weapons/Bullet.tscn")

var shoot_timer: float = 0.0
var shoot_interval: float = 2.5
var target_player_x: float = 0.0
var ramming: bool = false
var player: Node = null

func _ready() -> void:
	super._ready()
	shoot_timer = shoot_interval * randf_range(0.5, 1.5)

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			
	if player:
		target_player_x = player.global_position.x
		
		# Position flanking player slightly ahead on left/right adjacent lane
		var flank_offset = 64.0 if lane > player.current_lane else -64.0
		var target_x = player.global_position.x + flank_offset
		var diff_x = target_x - position.x
		
		# If close to player, initiate ramming!
		var dist_y = abs(player.global_position.y - global_position.y)
		if dist_y < 120.0 and abs(diff_x) < 80.0:
			ramming = true
			target_x = player.global_position.x # target player directly!
		else:
			ramming = false
			
		var lateral_speed = 300.0 if ramming else 150.0
		velocity.x = move_toward(velocity.x, (target_x - position.x) * 4.0, lateral_speed * delta)
		
		# Maintain Y speed to match player
		var target_y = player.global_position.y - 120.0
		var diff_y = target_y - position.y
		velocity.y = player.velocity.y + diff_y * 2.0
	else:
		velocity.x = 0.0
		velocity.y = -speed

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval
		_fire_bullet()
		
	move_and_slide()

func _fire_bullet() -> void:
	var bullet = BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)
	var mount_pos = global_position
	if has_node("WeaponMount"):
		mount_pos = $WeaponMount.global_position
	bullet.init(mount_pos, Vector2.DOWN, false)
