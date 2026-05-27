extends "res://scripts/scenes/enemies/Enemy.gd"

var jump_timer: float = 0.0

func _ready() -> void:
	super._ready()
	hp = 1
	score_value = 100
	speed = 150.0
	
	if not sprite.texture or sprite.texture is PlaceholderTexture2D:
		sprite.texture = _create_baby_bunny_bomb_texture()

static func _create_baby_bunny_bomb_texture() -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var camo_green = Color(0.2, 0.48, 0.12, 1.0)
	var camo_dark = Color(0.1, 0.3, 0.06, 1.0)
	var ear_pink = Color(1.0, 0.4, 0.5, 1.0)
	var bomb_gray = Color(0.3, 0.32, 0.35, 1.0)
	var flash_red = Color(1.0, 0.0, 0.1, 1.0)

	var fill_ellipse = func(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
		var x_start = clampi(int(cx - rx - 1), 0, 31)
		var x_end = clampi(int(cx + rx + 1), 0, 31)
		var y_start = clampi(int(cy - ry - 1), 0, 31)
		var y_end = clampi(int(cy + ry + 1), 0, 31)
		for px in range(x_start, x_end + 1):
			for py in range(y_start, y_end + 1):
				var nx = (px - cx) / rx
				var ny = (py - cy) / ry
				if nx * nx + ny * ny <= 1.0:
					img.set_pixel(px, py, col)

	# 1. Ears
	fill_ellipse.call(11.0, 7.0, 3.0, 7.0, camo_green)
	fill_ellipse.call(11.0, 8.0, 1.5, 5.0, ear_pink)
	fill_ellipse.call(21.0, 7.0, 3.0, 7.0, camo_green)
	fill_ellipse.call(21.0, 8.0, 1.5, 5.0, ear_pink)

	# 2. Main Body
	fill_ellipse.call(16.0, 20.0, 11.0, 8.5, camo_green)
	# camo spots
	fill_ellipse.call(11.0, 22.0, 4.0, 3.0, camo_dark)
	fill_ellipse.call(21.0, 18.0, 3.5, 2.5, camo_dark)

	# 3. Head
	fill_ellipse.call(16.0, 13.0, 8.5, 7.5, camo_green)

	# 4. Eyes (Glowing dangerous red)
	img.set_pixel(13, 12, flash_red)
	img.set_pixel(19, 12, flash_red)

	# 5. Little strapped countdown bomb on the back
	fill_ellipse.call(16.0, 22.0, 4.5, 4.5, bomb_gray)
	# Blinking red core
	img.set_pixel(16, 22, flash_red)
	# Strap lines
	img.set_pixel(11, 21, bomb_gray)
	img.set_pixel(12, 21, bomb_gray)
	img.set_pixel(20, 21, bomb_gray)
	img.set_pixel(21, 21, bomb_gray)

	return ImageTexture.create_from_image(img)

func on_pool_acquire() -> void:
	hp = 1
	speed = 150.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		return
		
	if player and is_instance_valid(player):
		velocity.x = move_toward(velocity.x, sign(player.global_position.x - global_position.x) * speed, 200.0 * delta)
	velocity.y = speed
	
	var hit_collision = move_and_collide(velocity * delta)
	if hit_collision:
		var col = hit_collision.get_collider()
		if col.name == "Player":
			_die()
