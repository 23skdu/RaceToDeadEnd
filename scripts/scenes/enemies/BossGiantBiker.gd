extends "res://scripts/scenes/enemies/Enemy.gd"

static var _boss_biker_texture: Texture2D = null

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
		if not _boss_biker_texture:
			_boss_biker_texture = _create_boss_biker_texture()
		sprite.texture = _boss_biker_texture

static func _create_boss_biker_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var rotor_blade = Color(0.55, 0.6, 0.7, 0.85)
	var rotor_blade_dark = Color(0.25, 0.28, 0.35, 0.85)
	var chrome = Color(0.75, 0.78, 0.85, 1.0)
	var chrome_light = Color(0.85, 0.88, 0.95, 1.0)
	var steel = Color(0.3, 0.32, 0.38, 1.0)
	var steel_dark = Color(0.15, 0.16, 0.2, 1.0)
	var tire = Color(0.1, 0.1, 0.12, 1.0)
	var body_red = Color(0.55, 0.05, 0.05, 1.0)
	var body_red_light = Color(0.7, 0.1, 0.1, 1.0)
	var glow_cyan = Color(0.0, 0.9, 1.0, 1.0)
	var glow_orange = Color(1.0, 0.4, 0.0, 1.0)
	var glow_red = Color(1.0, 0.0, 0.2, 1.0)

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

	# === ROTOR BLADES (top) ===
	# Spinning rotor hub
	fill_ellipse.call(64.0, 18.0, 8.0, 6.0, steel_dark)
	fill_ellipse.call(64.0, 18.0, 4.0, 3.0, glow_cyan)

	# Rotor blade left
	for blade in range(4):
		var angle = blade * PI / 2.0
		var bx = 64.0 + cos(angle) * 38.0
		var by = 18.0 + sin(angle) * 14.0
		fill_ellipse.call(bx, by, 30.0, 5.0, rotor_blade)
		fill_ellipse.call(bx - cos(angle) * 4.0, by - sin(angle) * 2.0, 24.0, 3.0, rotor_blade_dark)

	# Blade tip glows
	for blade in range(4):
		var angle = blade * PI / 2.0
		var tx = 64.0 + cos(angle) * 60.0
		var ty = 18.0 + sin(angle) * 18.0
		fill_ellipse.call(tx, ty, 4.0, 3.0, glow_cyan)

	# === BIKER BODY ARMOR (red, rotor-inspired) ===
	# Torso armor plating
	fill_ellipse.call(64.0, 42.0, 18.0, 20.0, steel_dark)
	fill_ellipse.call(64.0, 42.0, 16.0, 18.0, body_red)
	# Chest emblem
	fill_ellipse.call(64.0, 42.0, 8.0, 6.0, steel)
	fill_ellipse.call(64.0, 42.0, 5.0, 3.0, glow_cyan)
	# Shoulder pads
	fill_ellipse.call(45.0, 34.0, 6.0, 7.0, steel)
	fill_ellipse.call(83.0, 34.0, 6.0, 7.0, steel)
	fill_ellipse.call(45.0, 34.0, 3.0, 3.0, glow_red)
	fill_ellipse.call(83.0, 34.0, 3.0, 3.0, glow_red)

	# Helmet
	fill_ellipse.call(64.0, 20.0, 12.0, 10.0, steel_dark)
	fill_ellipse.call(64.0, 20.0, 10.0, 8.0, body_red)
	# Visor slit
	for y in range(18, 22):
		for x in range(56, 73):
			img.set_pixel(x, y, glow_cyan)
	# Helmet spike
	draw_thick_line.call(Vector2(64, 12), Vector2(64, 6), 3, chrome_light)

	# === BETTER MOTORCYCLE (chrome + red beast) ===
	# Fuel tank
	fill_ellipse.call(64.0, 66.0, 22.0, 12.0, body_red_light)
	fill_ellipse.call(64.0, 66.0, 18.0, 8.0, steel)

	# Engine block
	fill_ellipse.call(64.0, 78.0, 20.0, 14.0, steel_dark)
	fill_ellipse.call(64.0, 78.0, 14.0, 8.0, steel)
	# Engine cylinders
	for y in range(72, 84, 3):
		draw_thick_line.call(Vector2(48, y), Vector2(80, y), 2, chrome)
	# Exhaust pipes
	draw_thick_line.call(Vector2(52, 84), Vector2(36, 92), 4, steel)
	draw_thick_line.call(Vector2(76, 84), Vector2(92, 92), 4, steel)
	draw_thick_line.call(Vector2(36, 92), Vector2(24, 92), 4, glow_orange)
	draw_thick_line.call(Vector2(92, 92), Vector2(104, 92), 4, glow_orange)
	# Exhaust flame tips
	fill_ellipse.call(22.0, 92.0, 5.0, 4.0, glow_orange)
	fill_ellipse.call(106.0, 92.0, 5.0, 4.0, glow_orange)

	# Frame
	draw_thick_line.call(Vector2(64, 56), Vector2(64, 100), 3, chrome)
	draw_thick_line.call(Vector2(38, 100), Vector2(64, 70), 3, chrome)
	draw_thick_line.call(Vector2(90, 100), Vector2(64, 70), 3, chrome)

	# === BIGGER WHEELS ===
	# Rear wheel (left)
	fill_ellipse.call(34.0, 102.0, 16.0, 16.0, tire)
	fill_ellipse.call(34.0, 102.0, 9.0, 9.0, chrome)
	fill_ellipse.call(34.0, 102.0, 4.0, 4.0, steel_dark)
	# Rear spokes
	for a in range(6):
		var rad = a * PI / 3.0
		draw_thick_line.call(Vector2(34, 102), Vector2(34 + cos(rad) * 9, 102 + sin(rad) * 9), 2, chrome_light)
	# Rear spikes
	for a in range(8):
		var rad = a * PI / 4.0
		var sx = 34.0 + cos(rad) * 17.0
		var sy = 102.0 + sin(rad) * 17.0
		fill_ellipse.call(sx, sy, 2.5, 2.5, chrome_light)

	# Front wheel (right)
	fill_ellipse.call(94.0, 102.0, 16.0, 16.0, tire)
	fill_ellipse.call(94.0, 102.0, 9.0, 9.0, chrome)
	fill_ellipse.call(94.0, 102.0, 4.0, 4.0, steel_dark)
	# Front spokes
	for a in range(6):
		var rad = a * PI / 3.0
		draw_thick_line.call(Vector2(94, 102), Vector2(94 + cos(rad) * 9, 102 + sin(rad) * 9), 2, chrome_light)
	# Front spikes
	for a in range(8):
		var rad = a * PI / 4.0
		var sx = 94.0 + cos(rad) * 17.0
		var sy = 102.0 + sin(rad) * 17.0
		fill_ellipse.call(sx, sy, 2.5, 2.5, chrome_light)

	# === HEADLIGHT ===
	fill_ellipse.call(98.0, 56.0, 7.0, 5.0, chrome_light)
	fill_ellipse.call(99.0, 56.0, 5.0, 3.0, glow_cyan)
	# Light beam
	for x in range(102, 128):
		var y_ext = int((x - 102) * 0.3)
		for y in range(52 - y_ext, 60 + y_ext + 1):
			if y >= 0 and y < 128:
				var dist = (x - 102) / 26.0
				var alpha = clampf(0.4 * (1.0 - dist), 0.0, 0.4)
				var c = img.get_pixel(x, y)
				var beam = Color(glow_cyan.r, glow_cyan.g, glow_cyan.b, alpha)
				img.set_pixel(x, y, c.lerp(beam, alpha))

	# === HANDLEBARS ===
	draw_thick_line.call(Vector2(90, 50), Vector2(100, 46), 3, chrome)
	draw_thick_line.call(Vector2(90, 50), Vector2(80, 46), 3, chrome)
	fill_ellipse.call(100.0, 46.0, 3.0, 3.0, glow_red)
	fill_ellipse.call(80.0, 46.0, 3.0, 3.0, glow_red)

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
	handle_obstacle_collisions()

func _swing_chain() -> void:
	var chain = ObjectPool.acquire("chain_swing")
	if not chain:
		chain = preload("res://scenes/weapons/ChainSwing.tscn").instantiate()
	var parent = get_parent()
	if parent:
		parent.add_child(chain)
	chain.global_position = global_position
	chain.swing()
