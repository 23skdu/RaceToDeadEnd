extends "res://scripts/scenes/enemies/Enemy.gd"

var attack_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_reset_state()

func _reset_state() -> void:
	hp = Constants.BOSS_BUNNY_HP
	score_value = Constants.BOSS_SCORE
	speed = 80.0
	attack_timer = 0.0
	
	if not sprite.texture:
		var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.7, 0.9, 1.0))
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

func _spawn_baby_bunny() -> void:
	var bomb = ObjectPool.acquire("baby_bunny_bomb")
	if not bomb:
		bomb = preload("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	var parent = get_parent()
	if parent:
		parent.add_child(bomb)
	bomb.global_position = global_position + Vector2(0, 64)
	bomb.player = player
