extends "res://scripts/scenes/enemies/Enemy.gd"

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
		sprite.texture = _create_boss_bunny_texture()

static func _create_boss_bunny_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var camo_dark = Color(0.06, 0.22, 0.06, 1.0)
	var camo_med = Color(0.12, 0.32, 0.10, 1.0)
	var camo_light = Color(0.18, 0.40, 0.12, 1.0)
	var steel_gray = Color(0.45, 0.48, 0.52, 1.0)
	var steel_dark = Color(0.25, 0.26, 0.30, 1.0)
	var glow_red = Color(1.0, 0.0, 0.15, 1.0)
	var glow_eye = Color(1.0, 0.3, 0.4, 1.0)

	var camo_colors = [camo_dark, camo_med, camo_light]

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

	var fill_ellipse_camo = func(cx: float, cy: float, rx: float, ry: float) -> void:
		var x_start = clampi(int(cx - rx - 1), 0, 127)
		var x_end = clampi(int(cx + rx + 1), 0, 127)
		var y_start = clampi(int(cy - ry - 1), 0, 127)
		var y_end = clampi(int(cy + ry + 1), 0, 127)
		for px in range(x_start, x_end + 1):
			for py in range(y_start, y_end + 1):
				var nx = (px - cx) / rx
				var ny = (py - cy) / ry
				if nx * nx + ny * ny <= 1.0:
					var idx = (px * 13 + py * 7) % camo_colors.size()
					img.set_pixel(px, py, camo_colors[idx])

	var glow_ellipse = func(cx: float, cy: float, rx: float, ry: float, col: Color, thickness: float) -> void:
		var x_start = clampi(int(cx - rx - thickness - 1), 0, 127)
		var x_end = clampi(int(cx + rx + thickness + 1), 0, 127)
		var y_start = clampi(int(cy - ry - thickness - 1), 0, 127)
		var y_end = clampi(int(cy + ry + thickness + 1), 0, 127)
		for px in range(x_start, x_end + 1):
			for py in range(y_start, y_end + 1):
				var nx = (px - cx) / (rx + thickness)
				var ny = (py - cy) / (ry + thickness)
				if nx * nx + ny * ny <= 1.0:
					var in_nx = (px - cx) / rx
					var in_ny = (py - cy) / ry
					if in_nx * in_nx + in_ny * in_ny > 1.0:
						var dist = minf(1.0, sqrt(in_nx * in_nx + in_ny * in_ny) - 1.0)
						var alpha = clampf((1.0 - dist / thickness) * 0.4, 0.0, 0.4)
						var current_a = img.get_pixel(px, py).a
						if current_a < alpha:
							img.set_pixel(px, py, Color(col.r, col.g, col.b, alpha))

	# Glow auras first
	glow_ellipse.call(42.0, 24.0, 11.0, 26.0, glow_red, 4.0)
	glow_ellipse.call(86.0, 24.0, 11.0, 26.0, glow_red, 4.0)
	glow_ellipse.call(64.0, 80.0, 34.0, 30.0, glow_red, 5.0)
	glow_ellipse.call(64.0, 48.0, 28.0, 24.0, glow_red, 5.0)

	# Ears
	fill_ellipse_camo.call(42.0, 24.0, 11.0, 26.0)
	fill_ellipse.call(42.0, 26.0, 5.0, 18.0, steel_gray)
	fill_ellipse.call(42.0, 26.0, 1.5, 14.0, glow_red)

	fill_ellipse_camo.call(86.0, 24.0, 11.0, 26.0)
	fill_ellipse.call(86.0, 26.0, 5.0, 18.0, steel_gray)
	fill_ellipse.call(86.0, 26.0, 1.5, 14.0, glow_red)

	# Main Body
	fill_ellipse_camo.call(64.0, 80.0, 34.0, 30.0)

	# Main Head
	fill_ellipse_camo.call(64.0, 48.0, 28.0, 24.0)

	# Cyber Chest Armor
	fill_ellipse.call(64.0, 84.0, 22.0, 15.0, steel_gray)
	fill_ellipse.call(64.0, 84.0, 16.0, 10.0, steel_dark)
	fill_ellipse.call(64.0, 84.0, 5.0, 5.0, glow_red)

	# Cyber mouthguard/jaw
	fill_ellipse.call(64.0, 56.0, 16.0, 8.0, steel_gray)
	# Screws on mouthguard
	img.set_pixel(54, 56, steel_dark)
	img.set_pixel(74, 56, steel_dark)

	# Cyber Vizor/Eyes
	fill_ellipse.call(52.0, 44.0, 8.0, 3.5, steel_dark)
	fill_ellipse.call(52.0, 44.0, 5.0, 1.5, glow_eye)

	fill_ellipse.call(76.0, 44.0, 8.0, 3.5, steel_dark)
	fill_ellipse.call(76.0, 44.0, 5.0, 1.5, glow_eye)

	# Nose
	fill_ellipse.call(64.0, 49.0, 2.5, 1.8, steel_gray)

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

func _spawn_baby_bunny() -> void:
	var bomb = ObjectPool.acquire("baby_bunny_bomb")
	if not bomb:
		bomb = preload("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	var parent = get_parent()
	if parent:
		parent.add_child(bomb)
	bomb.global_position = global_position + Vector2(0, 64)
	bomb.player = player
