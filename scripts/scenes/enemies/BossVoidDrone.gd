extends "res://scripts/scenes/enemies/Enemy.gd"

var attack_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_reset_state()

func _reset_state() -> void:
	boss_key = "boss_void_drone"
	hp = Constants.BOSS_VOID_DRONE_HP
	score_value = Constants.BOSS_SCORE
	speed = 80.0
	attack_timer = 0.0
	
	if sprite and not sprite.texture:
		var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 0.0, 0.4, 1.0))
		sprite.texture = ImageTexture.create_from_image(img)

func on_pool_acquire() -> void:
	_reset_state()

func on_pool_release() -> void:
	_reset_state()
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		return
		
	if player:
		var target_y = player.global_position.y - 350.0
		velocity.y = (target_y - global_position.y) * 2.0
	else:
		velocity.y = speed
		
	attack_timer += delta
	if attack_timer >= Constants.BOSS_ATTACK_INTERVAL * 1.5:
		attack_timer = 0.0
		_spawn_drones()

func _spawn_drones() -> void:
	if _spawner and _spawner.has_signal("spawn_minion_requested"):
		_spawner.spawn_minion_requested.emit("drone", 2)
