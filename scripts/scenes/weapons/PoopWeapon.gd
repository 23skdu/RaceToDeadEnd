extends Area2D

static var _poop_texture: Texture2D = null

var speed: float = Constants.BULLET_SPEED * 0.6
var direction: Vector2 = Vector2.DOWN
var damage: int = 1

func _ready() -> void:
	z_index = 2
	add_to_group("enemy_projectile")
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_visible_on_screen_notifier_screen_exited)
	
	if not $Sprite2D.texture or $Sprite2D.texture is PlaceholderTexture2D:
		if not _poop_texture:
			_poop_texture = _create_poop_texture()
		$Sprite2D.texture = _poop_texture

static func _create_poop_texture() -> ImageTexture:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var brown_dark = Color(0.40, 0.20, 0.08, 1.0)
	var brown_med = Color(0.50, 0.26, 0.12, 1.0)
	var brown_light = Color(0.60, 0.32, 0.16, 1.0)
	var highlight = Color(0.72, 0.44, 0.25, 1.0)
	var toxic_green = Color(0.2, 0.85, 0.1, 0.85)

	var fill_ellipse = func(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
		var x_start = clampi(int(cx - rx - 1), 0, 15)
		var x_end = clampi(int(cx + rx + 1), 0, 15)
		var y_start = clampi(int(cy - ry - 1), 0, 15)
		var y_end = clampi(int(cy + ry + 1), 0, 15)
		for px in range(x_start, x_end + 1):
			for py in range(y_start, y_end + 1):
				var nx = (px - cx) / rx
				var ny = (py - cy) / ry
				if nx * nx + ny * ny <= 1.0:
					img.set_pixel(px, py, col)

	# 1. Base Swirl layer
	fill_ellipse.call(8.0, 12.0, 6.5, 3.2, brown_dark)
	# 2. Middle Swirl layer
	fill_ellipse.call(8.0, 8.5, 4.5, 2.8, brown_med)
	# 3. Top Peak layer
	fill_ellipse.call(8.0, 5.0, 2.5, 2.2, brown_light)
	fill_ellipse.call(8.0, 3.5, 1.2, 1.2, highlight)

	# Highlights to define curved layers
	img.set_pixel(5, 11, highlight)
	img.set_pixel(6, 11, highlight)
	img.set_pixel(6, 7, highlight)
	img.set_pixel(7, 7, highlight)

	# Toxic floating gas particles
	img.set_pixel(2, 4, toxic_green)
	img.set_pixel(13, 6, toxic_green)
	img.set_pixel(3, 10, toxic_green)
	img.set_pixel(12, 11, toxic_green)

	return ImageTexture.create_from_image(img)

func init(pos: Vector2, dir: Vector2, _player_owned: bool = false) -> void:
	global_position = pos
	direction = dir.normalized()
	collision_layer = 4
	collision_mask = 1

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("set_slippery"):
			body.set_slippery(true)
			get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(body): body.set_slippery(false))
	_die()

func _die() -> void:
	ObjectPool.release(self)

func on_pool_acquire() -> void:
	pass

func on_pool_release() -> void:
	pass

func _on_visible_on_screen_notifier_screen_exited() -> void:
	ObjectPool.release(self)
