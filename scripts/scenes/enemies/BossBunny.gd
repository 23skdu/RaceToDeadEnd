extends "res://scripts/scenes/enemies/Enemy.gd"

const EnemyScript = preload("res://scripts/scenes/enemies/Enemy.gd")

static var _boss_bunny_texture: Texture2D = null

var attack_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_reset_state()

func _reset_state() -> void:
	boss_key = "boss_bunny"
	hp = Constants.BOSS_BUNNY_HP
	score_value = Constants.BOSS_SCORE
	speed = 80.0
	attack_timer = 0.0
	
	if not sprite.texture or sprite.texture is PlaceholderTexture2D:
		if not _boss_bunny_texture:
			_boss_bunny_texture = _create_boss_bunny_texture()
		sprite.texture = _boss_bunny_texture
	apply_pulsating_eyes_shader()

static func _create_boss_bunny_texture() -> ImageTexture:
	# Same natural rabbit artwork as the regular bunny, enlarged for the boss.
	return EnemyScript._create_rabbit_texture(128, true)

func on_pool_acquire() -> void:
	super.on_pool_acquire()
	_reset_state()

func on_pool_release() -> void:
	super.on_pool_release()
	_reset_state()
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		return
		
	# Try to stay ahead of the player
	if player:
		var target_y = player.global_position.y - 350.0
		velocity.y = (target_y - global_position.y) * 2.0
	else:
		velocity.y = speed
		
	attack_timer += delta
	if attack_timer >= Constants.BOSS_ATTACK_INTERVAL:
		attack_timer = 0.0
		_spawn_baby_bunny()
		
	move_and_slide()
	handle_obstacle_collisions()

func _spawn_baby_bunny() -> void:
	play_boss_animation("attack")
	var bomb = ObjectPool.acquire("baby_bunny_bomb")
	if not bomb:
		bomb = preload("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	var parent = get_parent()
	if parent:
		parent.add_child(bomb)
	bomb.global_position = global_position + Vector2(0, 64)
	bomb.player = player
