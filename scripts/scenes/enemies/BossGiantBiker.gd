extends "res://scripts/scenes/enemies/Enemy.gd"

var attack_timer: float = 0.0
var enraged: bool = false

func _ready() -> void:
	super._ready()
	_reset_state()

func _reset_state() -> void:
	boss_key = "boss_giant_biker"
	hp = Constants.BOSS_GIANT_BIKER_HP
	score_value = Constants.BOSS_SCORE
	speed = 120.0
	attack_timer = 0.0
	enraged = false
	sprite.modulate = Color.WHITE

	if not sprite.texture:
		var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.6, 0.1, 0.1, 1.0))
		for x in range(128):
			for y in range(128):
				var dx = x - 64
				var dy = y - 64
				var d = dx * dx + dy * dy
				if d > 3600 and d < 4096:
					img.set_pixel(x, y, Color(0.3, 0.05, 0.05, 1.0))
		for x in range(52, 76):
			for y in range(20, 40):
				var ex = x - 64
				var ey = y - 30
				if ex * ex + ey * ey < 144:
					img.set_pixel(x, y, Color(0.8, 0.7, 0.6, 1.0))
		img.set_pixel(60, 32, Color(1.0, 0.0, 0.0, 1.0))
		img.set_pixel(68, 32, Color(1.0, 0.0, 0.0, 1.0))
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

	if not player:
		velocity.y = speed
		move_and_slide()
		return

	var target_y = player.global_position.y - 350.0
	var current_speed = speed * (1.6 if enraged else 1.0)
	var target_vy = (target_y - global_position.y) * 2.0
	if abs(target_vy) < current_speed:
		target_vy = -current_speed
	velocity.y = move_toward(velocity.y, target_vy, 200.0 * delta)

	var diff = player.global_position.x - global_position.x
	velocity.x = move_toward(velocity.x, diff, 100.0 * delta)

	var hp_pct = float(hp) / float(Constants.BOSS_GIANT_BIKER_HP)
	if hp_pct < 0.5 and not enraged:
		enraged = true
		sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)

	attack_timer += delta
	var interval = Constants.BOSS_ATTACK_INTERVAL * (0.6 if enraged else 1.0)
	if attack_timer >= interval:
		attack_timer = 0.0
		_swing_chain()

	move_and_slide()

func _swing_chain() -> void:
	var chain = ObjectPool.acquire("chain_swing")
	if not chain:
		chain = preload("res://scenes/weapons/ChainSwing.tscn").instantiate()
	var parent = get_parent()
	if parent:
		parent.add_child(chain)
	chain.global_position = global_position
	chain.swing()
