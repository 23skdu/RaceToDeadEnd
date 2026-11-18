extends GutTest

# Fuzz coverage for roadmap world/scene helpers.
# Covered scripts: RoadmapWorld.gd, Game.gd, Highway.gd, HUD.gd.

const RoadmapWorld = preload("res://scripts/utils/RoadmapWorld.gd")

const ALL_FEATURES: Array = [
	RoadmapWorld.FEATURE_TILEMAP_HIGHWAY,
	RoadmapWorld.FEATURE_REAR_VIEW,
	RoadmapWorld.FEATURE_FSR_UPSCALING,
	RoadmapWorld.FEATURE_RICH_HUD,
	RoadmapWorld.FEATURE_LIGHTING,
	RoadmapWorld.FEATURE_HDR,
	RoadmapWorld.FEATURE_WEATHER_LUT,
	RoadmapWorld.FEATURE_SSAO,
	RoadmapWorld.FEATURE_MOTION_INTERPOLATION,
]

var _rng: RandomNumberGenerator
var _saved_features: Dictionary = {}
var _saved_values: Dictionary = {}

func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 20261118
	_saved_features.clear()
	_saved_values.clear()
	for key in ALL_FEATURES:
		_saved_features[key] = SettingsManager.is_feature_enabled(key, true)
	for key in [RoadmapWorld.KEY_RESOLUTION, RoadmapWorld.KEY_HUD_TEXT_SCALE]:
		_saved_values[key] = SettingsManager.get_roadmap_value(key, null)

func after_each() -> void:
	for key in _saved_features.keys():
		SettingsManager.set_feature_enabled(key, _saved_features[key])
	for key in _saved_values.keys():
		SettingsManager.set_roadmap_value(key, _saved_values[key])

func _rand_string(length: int) -> String:
	var alphabet := "abcdefghijklmnopqrstuvwxyz_0123456789xX,: "
	var value := ""
	for i in length:
		value += alphabet[_rng.randi() % alphabet.length()]
	return value

func _rand_resolution_text() -> String:
	var kind := _rng.randi() % 4
	match kind:
		0:
			return "%dx%d" % [_rng.randi_range(-100, 5000), _rng.randi_range(-100, 3000)]
		1:
			return "%d, %d" % [_rng.randi_range(1, 4000), _rng.randi_range(1, 2500)]
		2:
			return _rand_string(_rng.randi_range(0, 12))
		_:
			var supported: Vector2i = RoadmapWorld.SUPPORTED_RESOLUTIONS[_rng.randi() % RoadmapWorld.SUPPORTED_RESOLUTIONS.size()]
			return "%dx%d" % [supported.x, supported.y]

func _assert_color_finite(color: Color, message: String) -> void:
	assert_true(is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a), message)

func test_fuzz_roadmap_world_math_and_resolutions() -> void:
	for i in 40:
		var width := float(_rng.randi_range(-500, 5000))
		var height := float(_rng.randi_range(-500, 3000))
		var aspect := RoadmapWorld.aspect_ratio(width, height)
		assert_true(is_finite(aspect), "Aspect should stay finite")
		assert_true(RoadmapWorld.aspect_category(aspect) != "", "Category should be a string")
		var rect := RoadmapWorld.letterbox_rect(Vector2(width, height), aspect)
		assert_gte(rect.size.x, 0.0)
		assert_gte(rect.size.y, 0.0)
		assert_true(is_finite(RoadmapWorld.viewport_scale_factor(Vector2(width, height))))
		var parsed := RoadmapWorld.parse_resolution(_rand_resolution_text())
		assert_true(parsed.x >= 0 and parsed.y >= 0)
		var value: Variant
		match i % 5:
			0: value = parsed
			1: value = Vector2(width, height)
			2: value = _rand_resolution_text()
			3: value = [width, height]
			_: value = null
		var sanitized := RoadmapWorld.sanitize_resolution(value)
		assert_gte(sanitized.x, RoadmapWorld.MIN_RESOLUTION.x)
		assert_lte(sanitized.x, RoadmapWorld.MAX_RESOLUTION.x)
		assert_gte(sanitized.y, RoadmapWorld.MIN_RESOLUTION.y)
		assert_lte(sanitized.y, RoadmapWorld.MAX_RESOLUTION.y)
		assert_true(not RoadmapWorld.resolution_to_string(sanitized).is_empty())

func test_fuzz_roadmap_world_bbcode_damage_and_scales() -> void:
	for i in 30:
		var scale_value: Variant
		match i % 4:
			0: scale_value = _rng.randf_range(-4.0, 4.0)
			1: scale_value = str(_rng.randf_range(-4.0, 4.0))
			2: scale_value = _rng.randi_range(-5, 5)
			_: scale_value = _rand_string(_rng.randi_range(0, 6))
		var scale := RoadmapWorld.clamp_text_scale(scale_value)
		assert_true(scale >= 0.5 and scale <= 3.0)
		var size := RoadmapWorld.scaled_font_size(_rng.randi_range(0, 40), scale)
		assert_gte(size, 1)
		assert_lte(size, 128)
		var bbcode := RoadmapWorld.bbcode_text(_rand_string(6), "#%06x" % (_rng.randi() % 0xFFFFFF), i % 2 == 0)
		assert_true(bbcode.begins_with("[color="))
		var amount := _rng.randi_range(-5, 30)
		assert_gte(RoadmapWorld.damage_tier(amount), 0)
		assert_lte(RoadmapWorld.damage_tier(amount), 3)
		assert_true(RoadmapWorld.damage_bbcode("-1", amount).contains("[color="))
		var density := RoadmapWorld.enemy_density(_rng.randi_range(-4, 30), _rng.randi_range(-4, 30))
		assert_true(density >= 0.0 and density <= 1.0)

func test_fuzz_roadmap_world_weather_materials_and_occluders() -> void:
	for i in 20:
		var weather_type := _rng.randi_range(-2, 8)
		var weather := RoadmapWorld.weather_name(weather_type)
		assert_false(weather.is_empty())
		_assert_color_finite(RoadmapWorld.weather_grade_color(weather, weather_type), "Grade color must be finite")
		var lut := RoadmapWorld.make_weather_lut(_rand_string(_rng.randi_range(0, 10)) if i % 3 == 0 else weather)
		assert_not_null(lut)
		assert_gt(lut.get_width(), 0)
		var lut_material := RoadmapWorld.make_lut_material(lut)
		assert_true(lut_material.shader.code.contains("lut"))
		var sharpness := _rng.randf_range(-2.0, 2.0)
		var fsr_material := RoadmapWorld.make_fsr_material(sharpness)
		assert_true(fsr_material.shader.code.contains("sharpness"))
		assert_gte(float(fsr_material.get_shader_parameter("sharpness")), 0.0)
		assert_lte(float(fsr_material.get_shader_parameter("sharpness")), 1.0)
		var ssao_material := RoadmapWorld.make_ssao_material(sharpness)
		assert_true(ssao_material.shader.code.contains("occlusion"))
		assert_gte(float(ssao_material.get_shader_parameter("strength")), 0.0)
		assert_lte(float(ssao_material.get_shader_parameter("strength")), 1.0)
		var size := Vector2(_rng.randf_range(-50.0, 80.0), _rng.randf_range(-50.0, 80.0))
		var kind := "circle" if i % 2 == 0 else "guardrail"
		assert_gte(RoadmapWorld.occluder_polygon(kind, size).size(), 3)
		var occluder := RoadmapWorld.make_light_occluder(kind, size)
		assert_not_null(occluder.occluder)
		assert_gte(occluder.occluder.polygon.size(), 3)
		assert_gt(RoadmapWorld.make_light_texture().get_width(), 0)
		var flash := RoadmapWorld.make_flash_light(Color(1.0, _rng.randf(), 0.2, 1.0))
		assert_gt(flash.energy, 0.0)
		var reactor := RoadmapWorld.make_reactor_light()
		assert_gt(reactor.texture_scale, 0.0)

func test_fuzz_game_roadmap_toggles_and_overlays() -> void:
	assert_true(ResourceLoader.exists("res://scripts/scenes/Game.gd"), "Game.gd fuzz target")
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	for i in 8:
		SettingsManager.set_feature_enabled(RoadmapWorld.FEATURE_FSR_UPSCALING, i % 2 == 0)
		SettingsManager.set_feature_enabled(RoadmapWorld.FEATURE_REAR_VIEW, i % 3 == 0)
		SettingsManager.set_feature_enabled(RoadmapWorld.FEATURE_SSAO, i % 4 == 0)
		game.set_fsr_upscaling_enabled(i % 2 == 0)
		game.set_ssao_enabled(i % 4 == 0)
		game.set_rear_view_enabled(i % 3 == 0)
		game.apply_resolution(RoadmapWorld.sanitize_resolution(_rand_resolution_text()))
		var viewport := Vector2(_rng.randi_range(320, 4000), _rng.randi_range(200, 2200))
		var content: Rect2 = game.apply_letterbox_for_size(viewport)
		assert_gte(content.size.x, 0.0)
		assert_gte(content.size.y, 0.0)
		assert_eq(game._fsr_overlay.visible, SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_FSR_UPSCALING, false))
		assert_eq(game._ssao_overlay.visible, SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_SSAO, false))
		assert_eq(game._rear_view_container.visible, game.rear_view_enabled)
		assert_true(game.bbcode_for_damage("-1", i).contains("[color="))
		var intensity: Array = game.compute_music_intensity()
		assert_gte(intensity.size(), 3)
		var popup: RichTextLabel = game._get_rich_popup_label()
		popup.text = game.bbcode_for_damage("-1", i)
		game._return_rich_popup_label(popup)
		assert_lte(game._rich_popup_pool.size(), game.POPUP_POOL_SIZE)

func test_fuzz_highway_tilemap_toggles_and_recycling() -> void:
	assert_true(ResourceLoader.exists("res://scripts/scenes/world/Highway.gd"), "Highway.gd fuzz target")
	var highway: Node2D = load("res://scripts/scenes/world/Highway.gd").new()
	add_child_autofree(highway)
	for i in 8:
		var enabled := i % 2 == 0
		highway.set_tilemap_highway_enabled(enabled)
		assert_eq(highway.lane_tilemap.visible, true)
		if enabled:
			assert_gt(highway._tile_cells.size(), 0)
		else:
			assert_eq(highway._tile_cells.size(), 0)
		highway._spawn_chunk(i)
		highway._recycle_chunk(highway.active_chunks[i % highway.active_chunks.size()])
		assert_true(highway.active_chunks.size() >= 10)

func test_fuzz_hud_rich_scaling_and_updates() -> void:
	assert_true(ResourceLoader.exists("res://scripts/scenes/ui/HUD.gd"), "HUD.gd fuzz target")
	var hud: CanvasLayer = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	for i in 12:
		hud.set_rich_hud_enabled(i % 2 == 0)
		hud.set_hud_text_scale(_rng.randf_range(0.1, 4.0))
		assert_true(hud.hud_text_scale >= 0.5 and hud.hud_text_scale <= 3.0)
		hud._on_score_updated(_rng.randi_range(0, 20000))
		hud._on_multiplier_updated(_rng.randi_range(1, 20))
		hud._on_tier_changed(_rng.randi_range(1, 20))
		hud._on_lives_updated(_rng.randi_range(0, 9))
		hud._on_health_updated(_rng.randi_range(0, 5))
		assert_true(hud.multiplier_rich_label.text.contains("[color="))
		assert_true(hud.tier_rich_label.text.contains("[color="))
		assert_true(hud.lives_rich_label.text.contains("[color="))
		assert_true(hud.health_rich_label.text.contains("[color="))
		assert_gt(hud.multiplier_rich_label.get_theme_font_size("normal_font_size"), 0)
