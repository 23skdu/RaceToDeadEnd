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
	# Top-down view of a real motorcycle and its rider, facing up the highway.
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var tire := Color(0.07, 0.07, 0.08, 1.0)
	var tread := Color(0.20, 0.20, 0.22, 1.0)
	var chrome := Color(0.62, 0.65, 0.69, 1.0)
	var chrome_light := Color(0.86, 0.88, 0.91, 1.0)
	var steel := Color(0.30, 0.32, 0.35, 1.0)
	var steel_dark := Color(0.16, 0.17, 0.19, 1.0)
	var paint := Color(0.40, 0.035, 0.045, 1.0)
	var paint_light := Color(0.62, 0.08, 0.08, 1.0)
	var leather := Color(0.13, 0.11, 0.11, 1.0)
	var leather_light := Color(0.23, 0.19, 0.18, 1.0)
	var visor := Color(0.06, 0.08, 0.10, 1.0)
	var warm_light := Color(1.0, 0.93, 0.75, 1.0)
	var exhaust_glow := Color(0.72, 0.32, 0.10, 0.75)

	var put := func(dx: float, dy: float, col: Color) -> void:
		var px := int(round(dx))
		var py := int(round(dy))
		if px >= 0 and px < 128 and py >= 0 and py < 128:
			img.set_pixel(px, py, col)

	var ellipse := func(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
		var reach := maxf(rx, ry) + 1.0
		var x0 := clampi(int(cx - reach), 0, 127)
		var x1 := clampi(int(cx + reach), 0, 127)
		var y0 := clampi(int(cy - reach), 0, 127)
		var y1 := clampi(int(cy + reach), 0, 127)
		for px in range(x0, x1 + 1):
			for py in range(y0, y1 + 1):
				var nx := (float(px) - cx) / rx
				var ny := (float(py) - cy) / ry
				if nx * nx + ny * ny <= 1.0:
					put.call(float(px), float(py), col)

	var line := func(x0: float, y0: float, x1: float, y1: float, width: float, col: Color) -> void:
		var seg := Vector2(x1 - x0, y1 - y0)
		var len_sq := maxf(1.0, seg.length_squared())
		var x_min := clampi(int(minf(x0, x1) - width - 1.0), 0, 127)
		var x_max := clampi(int(maxf(x0, x1) + width + 1.0), 0, 127)
		var y_min := clampi(int(minf(y0, y1) - width - 1.0), 0, 127)
		var y_max := clampi(int(maxf(y0, y1) + width + 1.0), 0, 127)
		for px in range(x_min, x_max + 1):
			for py in range(y_min, y_max + 1):
				var pt := Vector2(float(px), float(py))
				var t := clampf((pt - Vector2(x0, y0)).dot(seg) / len_sq, 0.0, 1.0)
				if pt.distance_squared_to(Vector2(x0, y0) + seg * t) <= width * width:
					put.call(float(px), float(py), col)

	var tread_lines := func(cx: float, cy: float, rx: float, ry: float) -> void:
		for y in range(int(cy - ry + 3), int(cy + ry - 2), 4):
			var ny := (float(y) - cy) / ry
			var half := rx * sqrt(maxf(0.0, 1.0 - ny * ny)) * 0.85
			line.call(cx - half, float(y), cx + half, float(y), 0.9, tread)

	# Wheels: narrow rubber ovals seen from above, with chrome fenders and hubs.
	ellipse.call(64.0, 26.0, 13.0, 25.0, chrome)
	ellipse.call(64.0, 26.0, 10.5, 23.0, tire)
	tread_lines.call(64.0, 26.0, 10.5, 23.0)
	ellipse.call(64.0, 26.0, 3.0, 4.0, chrome_light)

	line.call(55.0, 44.0, 52.0, 62.0, 2.5, chrome)
	line.call(73.0, 44.0, 76.0, 62.0, 2.5, chrome)
	line.call(50.0, 92.0, 54.0, 110.0, 2.0, chrome)
	line.call(78.0, 92.0, 74.0, 110.0, 2.0, chrome)
	ellipse.call(64.0, 112.0, 12.0, 14.0, tire)
	tread_lines.call(64.0, 112.0, 12.0, 14.0)
	ellipse.call(64.0, 112.0, 3.5, 4.0, chrome_light)

	# Frame, engine, pipes and tank.
	line.call(49.0, 62.0, 47.0, 98.0, 2.0, chrome)
	line.call(79.0, 62.0, 81.0, 98.0, 2.0, chrome)
	ellipse.call(64.0, 90.0, 15.0, 10.0, steel_dark)
	ellipse.call(64.0, 90.0, 12.0, 7.0, steel)
	for fin_y in [86.0, 89.0, 92.0, 95.0]:
		line.call(52.0, fin_y, 76.0, fin_y, 0.9, chrome)
	line.call(49.0, 92.0, 38.0, 112.0, 3.0, chrome)
	line.call(79.0, 92.0, 90.0, 112.0, 3.0, chrome)
	ellipse.call(37.0, 113.0, 3.0, 2.0, exhaust_glow)
	ellipse.call(91.0, 113.0, 3.0, 2.0, exhaust_glow)
	ellipse.call(64.0, 99.0, 12.0, 8.0, leather)
	ellipse.call(64.0, 72.0, 17.0, 16.0, paint)
	ellipse.call(59.0, 67.0, 9.0, 6.0, paint_light)
	ellipse.call(64.0, 64.0, 3.0, 2.0, chrome_light)

	# Handlebars, mirrors and a warm headlamp.
	line.call(40.0, 57.0, 64.0, 62.0, 2.5, chrome)
	line.call(64.0, 62.0, 88.0, 57.0, 2.5, chrome)
	ellipse.call(34.0, 49.0, 4.0, 3.0, chrome)
	ellipse.call(94.0, 49.0, 4.0, 3.0, chrome)
	ellipse.call(34.0, 49.0, 2.0, 1.5, steel_dark)
	ellipse.call(94.0, 49.0, 2.0, 1.5, steel_dark)
	ellipse.call(64.0, 48.0, 6.0, 4.0, chrome_light)
	ellipse.call(64.0, 48.0, 4.0, 2.5, warm_light)

	# Rider: legs, leather jacket, arms reaching the grips, full-face helmet.
	ellipse.call(51.0, 99.0, 6.0, 10.0, leather)
	ellipse.call(77.0, 99.0, 6.0, 10.0, leather)
	ellipse.call(47.0, 109.0, 5.0, 4.0, leather_light)
	ellipse.call(81.0, 109.0, 5.0, 4.0, leather_light)
	ellipse.call(64.0, 87.0, 15.5, 14.0, leather)
	ellipse.call(59.0, 83.0, 7.0, 5.0, leather_light)
	line.call(64.0, 79.0, 64.0, 95.0, 1.5, paint_light)
	ellipse.call(49.0, 79.0, 7.0, 6.0, leather)
	ellipse.call(79.0, 79.0, 7.0, 6.0, leather)
	line.call(50.0, 80.0, 41.0, 58.0, 4.0, leather)
	line.call(78.0, 80.0, 87.0, 58.0, 4.0, leather)
	ellipse.call(41.0, 57.0, 4.0, 3.0, steel_dark)
	ellipse.call(87.0, 57.0, 4.0, 3.0, steel_dark)
	ellipse.call(64.0, 69.0, 10.0, 11.0, chrome)
	ellipse.call(64.0, 69.0, 9.0, 10.0, paint)
	ellipse.call(64.0, 65.0, 7.5, 3.5, visor)
	line.call(59.0, 64.0, 64.0, 63.0, 1.0, chrome_light)
	ellipse.call(64.0, 76.0, 6.0, 2.5, steel_dark)
	ellipse.call(64.0, 73.0, 1.5, 1.0, chrome_light)

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
		play_boss_animation("enrage")

	attack_timer += delta
	var interval = Constants.BOSS_ATTACK_INTERVAL * (0.6 if enraged else 1.0)
	if attack_timer >= interval:
		attack_timer = 0.0
		_swing_chain()

	move_and_slide()
	handle_obstacle_collisions()

func _swing_chain() -> void:
	play_boss_animation("attack")
	var chain = ObjectPool.acquire("chain_swing")
	if not chain:
		chain = preload("res://scenes/weapons/ChainSwing.tscn").instantiate()
	var parent = get_parent()
	if parent:
		parent.add_child(chain)
	chain.global_position = global_position
	chain.swing()
