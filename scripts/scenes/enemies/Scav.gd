extends "res://scripts/scenes/enemies/Enemy.gd"

const BULLET_SCENE = preload("res://scenes/weapons/Bullet.tscn")

var shoot_timer: float = 0.0
var shoot_interval: float = 2.5
var target_player_x: float = 0.0
var ramming: bool = false
var world_node: Node = null

@onready var _weapon_mount: Node2D = $WeaponMount

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
		
		var flank_offset = Constants.SCAV_FLANK_OFFSET if lane >= Constants.LANE_COUNT / 2 else -Constants.SCAV_FLANK_OFFSET
		var target_x = player.global_position.x + flank_offset
		var diff_x = target_x - position.x
		
		var dist_y = abs(player.global_position.y - global_position.y)
		if dist_y < Constants.SCAV_RAM_DIST_Y and abs(diff_x) < Constants.SCAV_RAM_DIST_X:
			ramming = true
			target_x = player.global_position.x
		else:
			ramming = false
			
		var lateral_speed = Constants.SCAV_LATERAL_RAM_SPEED if ramming else Constants.SCAV_LATERAL_NORMAL_SPEED
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
	var bullet = ObjectPool.acquire("bullet")
	if not bullet:
		bullet = BULLET_SCENE.instantiate()
	if world_node:
		world_node.add_child(bullet)
	elif get_parent():
		get_parent().add_child(bullet)
	else:
		if not bullet.has_meta("_pool_name"):
			bullet.queue_free()
		else:
			ObjectPool.release(bullet)
		return
	var mount_pos = _weapon_mount.global_position if _weapon_mount else global_position
	bullet.init(mount_pos, Vector2.DOWN, false)
	AudioManager.play_synth_laser(mount_pos)
