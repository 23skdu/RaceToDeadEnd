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
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var instance = scene.instantiate()
	add_child_autofree(instance)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	var sprite = instance.get_node_or_null("Sprite2D")
	assert_not_null(sprite, "Should have Sprite2D node")

func test_interceptor_scene_has_collision():
	var scene = load("res://scenes/player/Interceptor.tscn")
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var instance = scene.instantiate()
	add_child_autofree(instance)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	var col = instance.get_node_or_null("CollisionShape2D")
	assert_not_null(col, "Should have CollisionShape2D node")

func test_interceptor_scene_has_weapon_mount():
	var scene = load("res://scenes/player/Interceptor.tscn")
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var instance = scene.instantiate()
	add_child_autofree(instance)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	var mount = instance.get_node_or_null("WeaponMount")
	assert_not_null(mount, "Should have WeaponMount node")

func test_interceptor_scene_has_camera():
	var scene = load("res://scenes/player/Interceptor.tscn")
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var instance = scene.instantiate()
	add_child_autofree(instance)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
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

func test_interceptor_has_neon_lights() -> void:
	var interceptor = load("res://scenes/player/Interceptor.tscn").instantiate()
	add_child_autofree(interceptor)
	assert_not_null(interceptor.get_node_or_null("Headlight"), "Interceptor should have a Headlight PointLight2D")
	assert_not_null(interceptor.get_node_or_null("Underglow"), "Interceptor should have an Underglow PointLight2D")
	var hl: PointLight2D = interceptor.get_node("Headlight")
	var ug: PointLight2D = interceptor.get_node("Underglow")
	assert_true(hl.shadow_enabled, "Headlight should cast shadows")
	assert_gt(hl.energy, 0.0)
	assert_gt(ug.energy, 0.0)
	assert_not_null(hl.texture)
	assert_not_null(ug.texture)

func test_interceptor_has_gpu_particle_effects() -> void:
	var interceptor = load("res://scenes/player/Interceptor.tscn").instantiate()
	add_child_autofree(interceptor)
	assert_not_null(interceptor.get_node_or_null("BoostExhaust"), "Interceptor should have BoostExhaust GPUParticles2D")
	assert_not_null(interceptor.get_node_or_null("MuzzleFlash"), "Interceptor should have MuzzleFlash GPUParticles2D")
	var exhaust: GPUParticles2D = interceptor.get_node("BoostExhaust")
	var flash: GPUParticles2D = interceptor.get_node("MuzzleFlash")
	assert_true(exhaust is GPUParticles2D)
	assert_true(flash is GPUParticles2D)
	assert_false(exhaust.emitting, "Boost exhaust should be off by default")
	assert_false(flash.emitting, "Muzzle flash should be off by default")

func test_all_player_skin_svgs_valid():
	assert_eq(Constants.PLAYER_SKINS.size(), 10, "Should define default + 8 style skins + urban camo")
	for skin in Constants.PLAYER_SKINS:
		var tex_path := str(skin.get("texture_path", ""))
		assert_true(ResourceLoader.exists(tex_path), "Skin SVG should exist: " + tex_path)
		var tex = load(tex_path)
		assert_not_null(tex, "Skin texture should load: " + tex_path)
		var img = tex.get_image()
		assert_eq(img.get_width(), 64, "Skin SVG width should be 64: " + tex_path)
		assert_eq(img.get_height(), 96, "Skin SVG height should be 96: " + tex_path)
		assert_eq(img.get_pixel(0, 0).a, 0.0, "Top-left must be transparent: " + tex_path)
		assert_eq(img.get_pixel(63, 95).a, 0.0, "Bottom-right must be transparent: " + tex_path)

func test_urban_camo_unlocks_after_first_boss():
	var prev_first := GameManager.first_boss_defeated
	var prev_killed := GameManager.bosses_killed
	var prev_ach := GameManager.unlocked_achievements.duplicate()
	var prev_skin := SettingsManager.get_player_skin()

	GameManager.first_boss_defeated = false
	GameManager.bosses_killed = 0
	GameManager.unlocked_achievements.clear()
	assert_true(GameManager.is_skin_unlocked("default"))
	assert_true(GameManager.is_skin_unlocked("crimson_viper"))
	assert_true(GameManager.is_skin_unlocked("toxic_volt"))
	assert_true(GameManager.is_skin_unlocked("solar_chrome"))
	assert_false(GameManager.is_skin_unlocked("urban_camo"), "Urban Camo should be locked before 1st boss kill")

	# Trying to equip locked urban_camo in Interceptor falls back to default
	SettingsManager.set_player_skin("urban_camo")
	var interceptor = load("res://scenes/player/Interceptor.tscn").instantiate()
	add_child_autofree(interceptor)
	assert_eq(interceptor.sprite.texture.resource_path, "res://assets/sprites/player/interceptor.svg", "Locked Urban Camo should not apply")

	# Defeat 1st boss
	GameManager.record_boss_defeated("boss_bunny")
	assert_true(GameManager.is_skin_unlocked("urban_camo"), "Urban Camo should unlock after 1st boss kill")
	interceptor._on_player_skin_changed("urban_camo")
	assert_eq(interceptor.sprite.texture.resource_path, "res://assets/sprites/player/interceptor_urban_camo.svg", "Unlocked Urban Camo should apply")
	assert_eq(interceptor.sprite.self_modulate, Color.WHITE, "Custom skin should use full-color WHITE modulate")

	# Restore state
	SettingsManager.set_player_skin(prev_skin)
	GameManager.first_boss_defeated = prev_first
	GameManager.bosses_killed = prev_killed
	GameManager.unlocked_achievements = prev_ach