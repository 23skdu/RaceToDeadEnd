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
	
	if sprite and (not sprite.texture or sprite.texture is PlaceholderTexture2D):
		sprite.texture = _create_boss_void_drone_texture()

static func _create_boss_void_drone_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var obsidian = Color(0.08, 0.05, 0.12, 1.0)
	var panel_dark = Color(0.16, 0.12, 0.22, 1.0)
	var glow_cyan = Color(0.0, 0.95, 1.0, 1.0)
	var glow_purple = Color(0.7, 0.05, 1.0, 1.0)
	var core_white = Color(1.0, 1.0, 1.0, 1.0)

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

	var fill_triangle = func(p1: Vector2, p2: Vector2, p3: Vector2, col: Color) -> void:
		var min_x = clampi(int(minf(p1.x, minf(p2.x, p3.x))), 0, 127)
		var max_x = clampi(int(maxf(p1.x, maxf(p2.x, p3.x))), 0, 127)
		var min_y = clampi(int(minf(p1.y, minf(p2.y, p3.y))), 0, 127)
		var max_y = clampi(int(maxf(p1.y, maxf(p2.y, p3.y))), 0, 127)
		var denom = (p2.y - p3.y) * (p1.x - p3.x) + (p3.x - p2.x) * (p1.y - p3.y)
		if abs(denom) < 0.001:
			return
		for px in range(min_x, max_x + 1):
			for py in range(min_y, max_y + 1):
				var s = ((p2.y - p3.y) * (px - p3.x) + (p3.x - p2.x) * (py - p3.y)) / denom
				var t = ((p3.y - p1.y) * (px - p3.x) + (p1.x - p3.x) * (py - p3.y)) / denom
				var u = 1.0 - s - t
				if s >= 0.0 and t >= 0.0 and u >= 0.0:
					img.set_pixel(px, py, col)

	# 1. Main outer triangle body (Fuselage + Wings)
	fill_triangle.call(Vector2(64, 16), Vector2(20, 96), Vector2(108, 96), obsidian)

	# 2. Layered inner wing paneling
	fill_triangle.call(Vector2(64, 28), Vector2(28, 90), Vector2(100, 90), panel_dark)

	# 3. Glowing purple aerodynamic stabilizer streaks
	fill_triangle.call(Vector2(48, 54), Vector2(34, 88), Vector2(54, 80), glow_purple)
	fill_triangle.call(Vector2(80, 54), Vector2(94, 88), Vector2(74, 80), glow_purple)

	# 4. Neon cyan thruster plumes at the rear base
	for x in [42, 43, 44, 45, 46, 82, 83, 84, 85, 86]:
		for y in range(96, 114):
			var dist = y - 96
			var alpha = 1.0 - float(dist) / 18.0
			img.set_pixel(x, y, Color(glow_cyan.r, glow_cyan.g, glow_cyan.b, alpha))

	# 5. Core Central Void Reactor Eye
	fill_ellipse.call(64.0, 64.0, 16.0, 16.0, glow_purple)
	fill_ellipse.call(64.0, 64.0, 10.0, 10.0, glow_cyan)
	fill_ellipse.call(64.0, 64.0, 5.0, 5.0, core_white)

	# 6. High-tech nose paneling highlights
	fill_triangle.call(Vector2(64, 20), Vector2(60, 32), Vector2(68, 32), glow_cyan)

	return ImageTexture.create_from_image(img)

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
