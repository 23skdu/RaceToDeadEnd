extends "res://scripts/scenes/enemies/Enemy.gd"

static var _boss_war_rig_texture: Texture2D = null

var attack_timer: float = 0.0
var minion_spawned: bool = false
var phase: int = 1

signal boss_phase_changed(p: int)

func _ready() -> void:
	super._ready()
	_reset_state()

func _reset_state() -> void:
	boss_key = "boss"
	hp = Constants.BOSS_WAR_RIG_HP
	score_value = Constants.BOSS_SCORE
	speed = 80.0
	attack_timer = 0.0
	minion_spawned = false
	phase = 1
	if sprite:
		sprite.modulate = Color.WHITE
		if PackManager and PackManager.has_method("get_custom_skin"):
			var custom_tex: Texture2D = PackManager.get_custom_skin("boss")
			if custom_tex:
				sprite.texture = custom_tex
				return
		if not sprite.texture or sprite.texture is PlaceholderTexture2D:
			if not _boss_war_rig_texture:
				_boss_war_rig_texture = _create_boss_war_rig_texture()
			sprite.texture = _boss_war_rig_texture

static func _create_boss_war_rig_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var armor_dark = Color(0.16, 0.14, 0.16, 1.0)
	var armor_mid = Color(0.28, 0.25, 0.26, 1.0)
	var armor_rust = Color(0.42, 0.20, 0.12, 1.0)
	var chrome = Color(0.75, 0.78, 0.84, 1.0)
	var steel = Color(0.42, 0.45, 0.50, 1.0)
	var tire = Color(0.08, 0.08, 0.10, 1.0)
	var hazard_yellow = Color(0.95, 0.72, 0.10, 1.0)
	var glow_red = Color(1.0, 0.12, 0.15, 1.0)
	var glow_orange = Color(1.0, 0.50, 0.05, 1.0)

	var fill_rect = func(x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
		for px in range(maxi(0, x0), mini(127, x1) + 1):
			for py in range(maxi(0, y0), mini(127, y1) + 1):
				img.set_pixel(px, py, col)

	var fill_ellipse = func(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
		var x_start = clampi(int(cx - rx - 1), 0, 127)
		var x_end = clampi(int(cx + rx + 1), 0, 127)
		var y_start = clampi(int(cy - ry - 1), 0, 127)
		var y_end = clampi(int(cy + ry + 1), 0, 127)
		for px in range(x_start, x_end + 1):
			for py in range(y_start, y_end + 1):
				var nx = (px - cx) / rx
				var ny = (py - cy) / ry
				if nx * nx + ny * ny <= 1.0:
					img.set_pixel(px, py, col)

	# 6 heavy armored wheels (3 left, 3 right)
	for wy in [26, 56, 88]:
		fill_rect.call(16, wy - 9, 28, wy + 9, tire)
		fill_rect.call(14, wy - 2, 18, wy + 2, chrome)
		fill_rect.call(20, wy - 5, 25, wy + 5, steel)
		fill_rect.call(100, wy - 9, 112, wy + 9, tire)
		fill_rect.call(110, wy - 2, 114, wy + 2, chrome)
		fill_rect.call(103, wy - 5, 108, wy + 5, steel)

	# Rear armored trailer / cargo citadel
	fill_rect.call(28, 12, 100, 62, armor_dark)
	fill_rect.call(32, 16, 96, 58, armor_mid)
	fill_rect.call(36, 20, 92, 54, armor_rust)
	# Reinforced steel ribs on trailer roof
	for ry in [24, 36, 48]:
		fill_rect.call(32, ry, 96, ry + 3, steel)
	# Twin roof gun turrets
	for tx in [46.0, 82.0]:
		fill_ellipse.call(tx, 34.0, 8.0, 8.0, armor_dark)
		fill_ellipse.call(tx, 34.0, 5.0, 5.0, steel)
		fill_rect.call(int(tx) - 2, 34, int(tx) + 2, 50, chrome)
		fill_ellipse.call(tx, 34.0, 2.0, 2.0, glow_red)

	# Twin rear exhaust stacks + flames
	fill_rect.call(34, 6, 40, 22, steel)
	fill_rect.call(88, 6, 94, 22, steel)
	fill_ellipse.call(37.0, 6.0, 4.0, 4.0, glow_orange)
	fill_ellipse.call(91.0, 6.0, 4.0, 4.0, glow_orange)

	# Hitch connector
	fill_rect.call(48, 60, 80, 66, armor_dark)

	# Front armored semi-cab & engine hood (facing downward toward player)
	fill_rect.call(28, 64, 100, 106, armor_dark)
	fill_rect.call(32, 68, 96, 102, armor_mid)
	# Armored windshield visor
	fill_rect.call(38, 72, 90, 80, armor_dark)
	fill_rect.call(40, 74, 61, 78, glow_red)
	fill_rect.call(67, 74, 88, 78, glow_red)
	# Engine grille & supercharger blower
	fill_rect.call(48, 84, 80, 100, armor_rust)
	for gx in range(52, 78, 4):
		fill_rect.call(gx, 86, gx + 1, 98, chrome)

	# Hazard stripe bumper
	fill_rect.call(24, 102, 104, 108, armor_dark)
	for hx in range(28, 100, 10):
		fill_rect.call(hx, 103, hx + 4, 107, hazard_yellow)

	# Glowing headlights
	fill_ellipse.call(34.0, 102.0, 4.0, 3.0, glow_orange)
	fill_ellipse.call(94.0, 102.0, 4.0, 3.0, glow_orange)

	# Spiked V-plow ram at front
	for py in range(108, 123):
		var half_w := int((123 - py) * 2.6)
		fill_rect.call(64 - half_w, py, 64 + half_w, py, steel if py % 3 != 0 else chrome)
	for sx in range(30, 100, 14):
		fill_rect.call(sx - 1, 114, sx + 1, 121, chrome)
	fill_rect.call(62, 118, 66, 125, chrome)

	return ImageTexture.create_from_image(img)

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
		
	_check_phase()
	attack_timer += delta
	if attack_timer >= Constants.BOSS_ATTACK_INTERVAL:
		attack_timer = 0.0
		_execute_attack()
		
	move_and_slide()
	handle_obstacle_collisions()

func _check_phase() -> void:
	var max_hp = Constants.BOSS_WAR_RIG_HP
	var new_phase = 1
	if hp <= max_hp * 0.3:
		new_phase = 3
	elif hp <= max_hp * 0.6:
		new_phase = 2
	if new_phase != phase:
		phase = new_phase
		if phase == 2:
			speed = 80.0 * 1.2
		elif phase == 3:
			speed = 80.0 * 1.4
		_update_phase_visuals()
		boss_phase_changed.emit(phase)

func _update_phase_visuals() -> void:
	match phase:
		2:
			sprite.modulate = Color(1.0, 0.9, 0.3, 1.0)
		3:
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
		_:
			sprite.modulate = Color.WHITE

func _execute_attack() -> void:
	if hp <= Constants.BOSS_WAR_RIG_HP * 0.3 and not minion_spawned:
		minion_spawned = true
		_spawn_minions()
		return
	if phase >= 2:
		var spread_roll = randf()
		if spread_roll < 0.4:
			_fire_bullet_spread()
			return
	_ram_player()

func _ram_player() -> void:
	velocity.x = move_toward(velocity.x, Constants.BOSS_RAM_FORCE * (1 if player and player.global_position.x > global_position.x else -1), Constants.BOSS_RAM_SPEED * get_physics_process_delta_time())
	CameraShake.shake(0.4, 0.2, 6.0)
	CameraShake.rumble(0.5, 0.2)

func _fire_bullet_spread() -> void:
	const BULLET_SCENE = preload("res://scenes/weapons/Bullet.tscn")
	var parent = get_parent()
	if not parent:
		return
	for angle_offset in [-15.0, 0.0, 15.0]:
		var bullet = ObjectPool.acquire("bullet")
		if not bullet:
			bullet = BULLET_SCENE.instantiate()
		parent.add_child(bullet)
		bullet.global_position = global_position + Vector2(0, 48)
		var dir = Vector2.DOWN.rotated(deg_to_rad(angle_offset))
		bullet.init(bullet.global_position, dir, false)
	AudioManager.play_synth_laser(global_position)

func _spawn_minions() -> void:
	if _spawner and _spawner.has_signal("spawn_minion_requested"):
		_spawner.spawn_minion_requested.emit("scav", 2)
