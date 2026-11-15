extends "res://scripts/scenes/enemies/Enemy.gd"

static var _boss_sasquatch_texture: Texture2D = null

var attack_timer: float = 0.0
var dodge_timer: float = 0.0
var target_lane_x: float = 0.0

func _ready() -> void:
	super._ready()
	if not sprite.texture or sprite.texture is PlaceholderTexture2D:
		if not _boss_sasquatch_texture:
			_boss_sasquatch_texture = _create_boss_sasquatch_texture()
		sprite.texture = _boss_sasquatch_texture

static func _create_boss_sasquatch_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var fur_dark = Color(0.3, 0.15, 0.08, 1.0)
	var fur_med = Color(0.42, 0.22, 0.12, 1.0)
	var fur_light = Color(0.52, 0.28, 0.16, 1.0)
	var skin_gray = Color(0.28, 0.28, 0.32, 1.0)
	var glow_orange = Color(1.0, 0.5, 0.0, 1.0)
	var glow_red = Color(1.0, 0.1, 0.1, 1.0)
	var fang_white = Color(0.95, 0.95, 0.9, 1.0)

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

	var draw_fur_tuft = func(cx: float, cy: float, col: Color) -> void:
		for dx in range(-4, 5):
			for dy in range(-4, 5):
				var px = clampi(int(cx + dx), 0, 127)
				var py = clampi(int(cy + dy), 0, 127)
				if (dx * dx + dy * dy) <= 16:
					if (px * 3 + py * 7) % 2 == 0:
						img.set_pixel(px, py, col)

	# 1. Broad hairy body base
	fill_ellipse.call(64.0, 78.0, 36.0, 32.0, fur_dark)

	# Fur shading layers
	for row in range(54, 102, 6):
		for col in range(36, 92, 10):
			draw_fur_tuft.call(col, row, fur_med)
			if (col + row) % 3 == 0:
				draw_fur_tuft.call(col + 3, row + 2, fur_light)

	# 2. Large powerful arms
	fill_ellipse.call(26.0, 76.0, 11.0, 24.0, fur_dark)
	fill_ellipse.call(102.0, 76.0, 11.0, 24.0, fur_dark)

	# Claws (white spikes) at the base of hands
	fill_ellipse.call(26.0, 98.0, 8.0, 4.0, skin_gray)
	fill_ellipse.call(102.0, 98.0, 8.0, 4.0, skin_gray)
	for x in range(20, 33, 4):
		img.set_pixel(x, 103, fang_white)
		img.set_pixel(x + 76, 103, fang_white)

	# 3. Head & Hairy chest
	fill_ellipse.call(64.0, 42.0, 22.0, 18.0, fur_dark)
	fill_ellipse.call(64.0, 44.0, 16.0, 13.0, skin_gray) # Face area

	# 4. Glowing orange eyes
	fill_ellipse.call(55.0, 38.0, 4.0, 4.0, glow_red)
	fill_ellipse.call(55.0, 38.0, 2.0, 2.0, glow_orange)

	fill_ellipse.call(73.0, 38.0, 4.0, 4.0, glow_red)
	fill_ellipse.call(73.0, 38.0, 2.0, 2.0, glow_orange)

	# 5. Snarl Mouth with Fangs
	fill_ellipse.call(64.0, 50.0, 10.0, 4.0, fur_dark)
	img.set_pixel(57, 49, fang_white)
	img.set_pixel(58, 50, fang_white)
	img.set_pixel(70, 49, fang_white)
	img.set_pixel(71, 50, fang_white)

	# 6. Upper brow shadows
	draw_fur_tuft.call(64.0, 32.0, fur_dark)

	return ImageTexture.create_from_image(img)

func on_pool_acquire() -> void:
	super.on_pool_acquire()
	attack_timer = 0.0
	dodge_timer = 0.0
	target_lane_x = global_position.x

func on_pool_release() -> void:
	super.on_pool_release()
	attack_timer = 0.0
	dodge_timer = 0.0
	target_lane_x = 0.0
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not player or not is_instance_valid(player):
		velocity.y = speed
		move_and_slide()
		return

	var target_y = player.global_position.y - 300.0
	velocity.y = (target_y - global_position.y) * 2.0

	dodge_timer += delta
	if dodge_timer >= 1.5:
		dodge_timer = 0.0
		_dodge()

	velocity.x = (target_lane_x - global_position.x) * 5.0

	attack_timer += delta
	if attack_timer >= Constants.BOSS_ATTACK_INTERVAL * 1.5:
		attack_timer = 0.0
		_throw_poop()

	move_and_slide()
	handle_obstacle_collisions()

func _dodge() -> void:
	var new_lane = randi_range(0, Constants.LANE_COUNT - 1)
	target_lane_x = Constants.LANE_POSITIONS[new_lane]

func _throw_poop() -> void:
	var poop = ObjectPool.acquire("poop_weapon")
	if not poop:
		poop = preload("res://scenes/weapons/PoopWeapon.tscn").instantiate()
	var parent = get_parent()
	if parent:
		parent.add_child(poop)
	poop.global_position = global_position + Vector2(0, 64)
	var dir = Vector2.DOWN
	if player:
		dir = (player.global_position - poop.global_position).normalized()
	poop.init(poop.global_position, dir, false)
