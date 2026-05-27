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

	if not sprite.texture or sprite.texture is PlaceholderTexture2D:
		sprite.texture = _create_boss_biker_texture()

static func _create_boss_biker_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var metallic_gray = Color(0.5, 0.55, 0.6, 1.0)
	var chrome_light = Color(0.8, 0.82, 0.85, 1.0)
	var steel_dark = Color(0.2, 0.22, 0.25, 1.0)
	var tire_black = Color(0.12, 0.12, 0.14, 1.0)
	var leather_black = Color(0.06, 0.06, 0.08, 1.0)
	var glow_orange = Color(1.0, 0.35, 0.0, 1.0)
	var glow_red = Color(1.0, 0.0, 0.15, 1.0)
	var beam_yellow = Color(1.0, 0.85, 0.2, 0.3)

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

	var draw_thick_line = func(p1: Vector2, p2: Vector2, width: int, col: Color) -> void:
		var steps = max(1.0, p1.distance_to(p2) * 2.0)
		for j in range(int(steps) + 1):
			var t = float(j) / steps
			var pt = p1.lerp(p2, t)
			for dx in range(-int(width / 2.0), int((width + 1.0) / 2.0)):
				for dy in range(-int(width / 2.0), int((width + 1.0) / 2.0)):
					var px = clampi(int(pt.x + dx), 0, 127)
					var py = clampi(int(pt.y + dy), 0, 127)
					img.set_pixel(px, py, col)

	# 1. Front headlamp lighting beam (yellow flare)
	for x in range(96, 128):
		var y_extent = int((x - 96) * 0.35)
		for y in range(48 - y_extent, 48 + y_extent + 1):
			if y >= 0 and y < 128:
				img.set_pixel(x, y, beam_yellow)

	# 2. Chrome Chassis Fork & Frame Lines
	draw_thick_line.call(Vector2(38, 80), Vector2(64, 60), 4, metallic_gray) # rear swingarm
	draw_thick_line.call(Vector2(90, 80), Vector2(76, 44), 3, chrome_light)  # front fork
	draw_thick_line.call(Vector2(64, 60), Vector2(76, 44), 4, steel_dark)     # main spine
	draw_thick_line.call(Vector2(38, 80), Vector2(76, 44), 2, chrome_light)  # frame strut

	# 3. Two Large spiked tires
	fill_ellipse.call(38.0, 80.0, 18.0, 18.0, tire_black)
	fill_ellipse.call(38.0, 80.0, 10.0, 10.0, chrome_light)
	fill_ellipse.call(38.0, 80.0, 4.0, 4.0, steel_dark)

	fill_ellipse.call(90.0, 80.0, 18.0, 18.0, tire_black)
	fill_ellipse.call(90.0, 80.0, 10.0, 10.0, chrome_light)
	fill_ellipse.call(90.0, 80.0, 4.0, 4.0, steel_dark)

	# Silver Tire Spikes
	for a in range(8):
		var rad = a * PI / 4.0
		var sx1 = int(38.0 + cos(rad) * 19.0)
		var sy1 = int(80.0 + sin(rad) * 19.0)
		var sx2 = int(90.0 + cos(rad) * 19.0)
		var sy2 = int(80.0 + sin(rad) * 19.0)
		if sx1 >= 0 and sx1 < 128 and sy1 >= 0 and sy1 < 128:
			img.set_pixel(sx1, sy1, chrome_light)
		if sx2 >= 0 and sx2 < 128 and sy2 >= 0 and sy2 < 128:
			img.set_pixel(sx2, sy2, chrome_light)

	# 4. Roaring hot engine block
	fill_ellipse.call(64.0, 64.0, 18.0, 13.0, steel_dark)
	# Engine cylinders (horizontal lines)
	for y in range(58, 71, 3):
		draw_thick_line.call(Vector2(50, y), Vector2(78, y), 2, metallic_gray)
	# Exhaust pipes glowing
	draw_thick_line.call(Vector2(55, 68), Vector2(40, 62), 3, glow_orange)
	draw_thick_line.call(Vector2(40, 62), Vector2(24, 62), 3, glow_orange)

	# 5. Biker Torso (leather jacket)
	fill_ellipse.call(64.0, 40.0, 14.0, 16.0, leather_black)
	# Spikes on shoulders
	fill_ellipse.call(50.0, 28.0, 3.0, 3.0, chrome_light)
	fill_ellipse.call(78.0, 28.0, 3.0, 3.0, chrome_light)

	# 6. Biker Helmet & Visor
	fill_ellipse.call(64.0, 22.0, 9.0, 9.0, steel_dark)
	fill_ellipse.call(66.0, 21.0, 7.0, 3.5, glow_red) # glowing eye slit visor

	# 7. Front headlamp shell
	fill_ellipse.call(94.0, 48.0, 5.0, 5.0, chrome_light)
	fill_ellipse.call(95.0, 48.0, 3.0, 3.0, glow_orange)

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
