extends GutTest

func test_interceptor_svg_exists():
	var tex = load("res://assets/sprites/player/interceptor.svg")
	assert_not_null(tex, "Interceptor SVG should exist")

func test_interceptor_svg_has_content():
	var tex = load("res://assets/sprites/player/interceptor.svg")
	assert_not_null(tex)
	var img = tex.get_image()
	assert_not_null(img)
	assert_gt(img.get_width(), 0, "SVG should have width")
	assert_gt(img.get_height(), 0, "SVG should have height")

func test_interceptor_svg_dimensions():
	var tex = load("res://assets/sprites/player/interceptor.svg")
	var img = tex.get_image()
	assert_eq(img.get_width(), 64, "SVG width should be 64")
	assert_eq(img.get_height(), 96, "SVG height should be 96")

func test_interceptor_has_dark_hull():
	var tex = load("res://assets/sprites/player/interceptor.svg")
	var img = tex.get_image()
	var w = img.get_width()
	var h = img.get_height()
	var center = img.get_pixel(w / 2, h / 3)
	assert_lt(center.r, 0.5, "Center should be dark (low red)")
	assert_lt(center.g, 0.5, "Center should be dark (low green)")
	assert_lt(center.b, 0.5, "Center should be dark (low blue)")

func test_interceptor_has_neon_accents():
	var tex = load("res://assets/sprites/player/interceptor.svg")
	var img = tex.get_image()
	var w = img.get_width()
	var h = img.get_height()
	var found_neon = false
	for x in range(w):
		for y in range(h):
			var p = img.get_pixel(x, y)
			if p.a > 0.5 and (p.g > 0.8 or p.r > 0.8):
				found_neon = true
				break
		if found_neon:
			break
	assert_true(found_neon, "Should have neon accent pixels")

func test_interceptor_has_transparency():
	var tex = load("res://assets/sprites/player/interceptor.svg")
	var img = tex.get_image()
	var w = img.get_width()
	var h = img.get_height()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "Top-left should be transparent")
	assert_eq(img.get_pixel(w - 1, 0).a, 0.0, "Top-right should be transparent")
	assert_eq(img.get_pixel(0, h - 1).a, 0.0, "Bottom-left should be transparent")
	assert_eq(img.get_pixel(w - 1, h - 1).a, 0.0, "Bottom-right should be transparent")

func test_interceptor_scene_loads():
	var scene = load("res://scenes/player/Interceptor.tscn")
	assert_not_null(scene, "Interceptor scene should load")

func test_interceptor_scene_has_sprite():
	var scene = load("res://scenes/player/Interceptor.tscn")
	var instance = scene.instantiate()
	add_child_autofree(instance)
	var sprite = instance.get_node_or_null("Sprite2D")
	assert_not_null(sprite, "Should have Sprite2D node")

func test_interceptor_scene_has_collision():
	var scene = load("res://scenes/player/Interceptor.tscn")
	var instance = scene.instantiate()
	add_child_autofree(instance)
	var col = instance.get_node_or_null("CollisionShape2D")
	assert_not_null(col, "Should have CollisionShape2D node")

func test_interceptor_scene_has_weapon_mount():
	var scene = load("res://scenes/player/Interceptor.tscn")
	var instance = scene.instantiate()
	add_child_autofree(instance)
	var mount = instance.get_node_or_null("WeaponMount")
	assert_not_null(mount, "Should have WeaponMount node")

func test_interceptor_scene_has_camera():
	var scene = load("res://scenes/player/Interceptor.tscn")
	var instance = scene.instantiate()
	add_child_autofree(instance)
	var cam = instance.get_node_or_null("Camera2D")
	assert_not_null(cam, "Should have Camera2D node")

func test_interceptor_svg_not_icon():
	var tex = load("res://assets/sprites/player/interceptor.svg")
	assert_not_null(tex)
	var img = tex.get_image()
	var w = img.get_width()
	var h = img.get_height()
	var center = img.get_pixel(w / 2, h / 2)
	assert_true(center.r < 0.5 or center.g < 0.5 or center.b < 0.5, "Center should not be white like icon.svg")