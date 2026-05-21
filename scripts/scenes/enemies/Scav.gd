extends "res://scripts/scenes/enemies/Enemy.gd"

const BULLET_SCENE = preload("res://scenes/weapons/Bullet.tscn")

var shoot_timer: float = 0.0
var shoot_interval: float = 2.5
var target_player_x: float = 0.0
var ramming: bool = false
var world_node: Node = null

func _ready() -> void:
	super._ready()
	shoot_timer = shoot_interval * randf_range(0.5, 1.5)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if player and is_instance_valid(player):
		target_player_x = player.global_position.x
		
		var flank_offset = 64.0 if lane > 1 else -64.0
		var target_x = player.global_position.x + flank_offset
		var diff_x = target_x - position.x
		
		var dist_y = abs(player.global_position.y - global_position.y)
		if dist_y < 120.0 and abs(diff_x) < 80.0:
			ramming = true
			target_x = player.global_position.x
		else:
			ramming = false
			
		var lateral_speed = 300.0 if ramming else 150.0
		velocity.x = move_toward(velocity.x, (target_x - position.x) * 4.0, lateral_speed * delta)
		
		var target_y = player.global_position.y - 120.0
		var diff_y = target_y - position.y
		velocity.y = -speed + diff_y * 2.0
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
	if world_node:
		world_node.add_child(bullet)
	elif get_parent():
		get_parent().add_child(bullet)
	else:
		return
	var mount_pos = global_position
	if has_node("WeaponMount"):
		mount_pos = $WeaponMount.global_position
	bullet.init(mount_pos, Vector2.DOWN, false)
