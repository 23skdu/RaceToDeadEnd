extends GutTest

# Unit coverage for roadmap rendering/world helpers and their scene integrations.
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

var _saved_features: Dictionary = {}
var _saved_values: Dictionary = {}

func before_each() -> void:
	_saved_features.clear()
	_saved_values.clear()
	for key in ALL_FEATURES:
		_saved_features[key] = SettingsManager.is_feature_enabled(key, true)
		SettingsManager.set_feature_enabled(key, true)
	for key in [RoadmapWorld.KEY_RESOLUTION, RoadmapWorld.KEY_HUD_TEXT_SCALE]:
		_saved_values[key] = SettingsManager.get_roadmap_value(key, null)

func after_each() -> void:
	for key in _saved_features.keys():
		SettingsManager.set_feature_enabled(key, _saved_features[key])
	for key in _saved_values.keys():
		SettingsManager.set_roadmap_value(key, _saved_values[key])

func _game_script_path() -> String:
	return "res://scripts/scenes/Game.gd"

func _highway_script_path() -> String:
	return "res://scripts/scenes/world/Highway.gd"

func _hud_script_path() -> String:
	return "res://scripts/scenes/ui/HUD.gd"

func _roadmap_world_script_path() -> String:
	return "res://scripts/utils/RoadmapWorld.gd"

func _create_game() -> Node:
	assert_true(ResourceLoader.exists(_game_script_path()), "Game.gd should exist")
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	return game

func _create_highway() -> Node2D:
	assert_true(ResourceLoader.exists(_highway_script_path()), "Highway.gd should exist")
	var highway: Node2D = load("res://scripts/scenes/world/Highway.gd").new()
	add_child_autofree(highway)
	return highway

func _create_hud() -> CanvasLayer:
	assert_true(ResourceLoader.exists(_hud_script_path()), "HUD.gd should exist")
	var hud: CanvasLayer = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	return hud

func _find_child_named(node: Node, name: String) -> Node:
	if node == null:
		return null
	if node.name == name:
		return node
	for child in node.get_children():
		var found := _find_child_named(child, name)
		if found != null:
			return found
	return null

# --- RoadmapWorld.gd pure helpers ----------------------------------------------

func test_roadmap_world_contract_and_paths() -> void:
	assert_true(ResourceLoader.exists(_roadmap_world_script_path()), "RoadmapWorld.gd should exist")
	assert_eq(RoadmapWorld.DEFAULT_RESOLUTION, Vector2i(1280, 720))
	assert_eq(RoadmapWorld.MIN_RESOLUTION, Vector2i(640, 360))
	assert_eq(RoadmapWorld.MAX_RESOLUTION, Vector2i(3840, 2160))
	assert_almost_eq(RoadmapWorld.CONTENT_ASPECT_16_9, 16.0 / 9.0, 0.0001)
	assert_almost_eq(RoadmapWorld.ULTRAWIDE_ASPECT, 21.0 / 9.0, 0.0001)
	assert_almost_eq(RoadmapWorld.SUPER_ULTRAWIDE_ASPECT, 32.0 / 9.0, 0.0001)
	assert_true(RoadmapWorld.SUPPORTED_RESOLUTIONS.has(Vector2i(3440, 1440)))
	assert_true(RoadmapWorld.FSR_SHADER_CODE.contains("screen_texture"))
	assert_true(RoadmapWorld.LUT_SHADER_CODE.contains("lut"))
	assert_true(RoadmapWorld.SSAO_SHADER_CODE.contains("occlusion"))

func test_roadmap_world_aspect_and_letterbox_math() -> void:
	assert_almost_eq(RoadmapWorld.aspect_ratio(1920.0, 1080.0), 16.0 / 9.0, 0.0001)
	assert_eq(RoadmapWorld.aspect_ratio(0.0, 1080.0), 0.0)
	assert_eq(RoadmapWorld.aspect_category(-1.0), "invalid")
	assert_eq(RoadmapWorld.aspect_category(16.0 / 9.0), "standard")
	assert_eq(RoadmapWorld.aspect_category(21.0 / 9.0), "ultrawide")
	assert_eq(RoadmapWorld.aspect_category(32.0 / 9.0), "super_ultrawide")
	assert_true(RoadmapWorld.is_ultrawide(21.0 / 9.0))
	assert_false(RoadmapWorld.is_ultrawide(16.0 / 9.0))
	var rect := RoadmapWorld.letterbox_rect(Vector2(3440, 1440), RoadmapWorld.CONTENT_ASPECT_16_9)
	assert_almost_eq(rect.size.x, 2560.0, 0.01)
	assert_almost_eq(rect.size.y, 1440.0, 0.01)
	assert_almost_eq(rect.position.x, 440.0, 0.01)
	assert_eq(RoadmapWorld.letterbox_rect(Vector2.ZERO, 16.0 / 9.0), Rect2())
	assert_almost_eq(RoadmapWorld.viewport_scale_factor(Vector2(1280, 720)), 1.0, 0.0001)
	assert_lte(RoadmapWorld.viewport_scale_factor(Vector2(100, 100)), 1.0)

func test_roadmap_world_resolution_helpers() -> void:
	assert_eq(RoadmapWorld.parse_resolution("1920x1080"), Vector2i(1920, 1080))
	assert_eq(RoadmapWorld.parse_resolution("2560, 1440"), Vector2i(2560, 1440))
	assert_eq(RoadmapWorld.parse_resolution("bad"), Vector2i.ZERO)
	assert_eq(RoadmapWorld.sanitize_resolution("not-a-resolution"), RoadmapWorld.DEFAULT_RESOLUTION)
	assert_eq(RoadmapWorld.sanitize_resolution(Vector2(10000, 20)), RoadmapWorld.MAX_RESOLUTION)
	assert_eq(RoadmapWorld.sanitize_resolution([800, 600]), Vector2i(800, 600))
	assert_eq(RoadmapWorld.resolution_to_string(Vector2i(3440, 1440)), "3440x1440")

func test_roadmap_world_hud_helpers() -> void:
	assert_almost_eq(RoadmapWorld.clamp_text_scale("1.5"), 1.5, 0.0001)
	assert_almost_eq(RoadmapWorld.clamp_text_scale(NAN), 1.0, 0.0001)
	assert_almost_eq(RoadmapWorld.clamp_text_scale(10.0), 3.0, 0.0001)
	assert_eq(RoadmapWorld.scaled_font_size(20, 2.0), 40)
	assert_eq(RoadmapWorld.scaled_font_size(0, 2.0), 1)
	assert_true(RoadmapWorld.bbcode_text("HI", "#ffcc00").contains("[b]HI[/b]"))
	assert_true(RoadmapWorld.bbcode_text("HI", "invalid").contains("#ffffff"))
	assert_eq(RoadmapWorld.bbcode_color(1), "#ffffff")
	assert_eq(RoadmapWorld.bbcode_color(6), "#00f0ff")
	assert_eq(RoadmapWorld.bbcode_color(14), "#ff3366")
	assert_eq(RoadmapWorld.damage_tier(0), 0)
	assert_eq(RoadmapWorld.damage_tier(3), 2)
	assert_eq(RoadmapWorld.damage_tier(9), 3)
	assert_true(RoadmapWorld.damage_bbcode("-9", 9).contains("#ff3366"))
	assert_almost_eq(RoadmapWorld.enemy_density(6, 12), 0.5, 0.0001)
	assert_eq(RoadmapWorld.enemy_density(5, 0), 0.0)

func test_roadmap_world_weather_materials_and_lights() -> void:
	assert_eq(RoadmapWorld.weather_name(0), "clear")
	assert_eq(RoadmapWorld.weather_name(2), "acid_rain")
	assert_eq(RoadmapWorld.weather_name(99), "clear")
	assert_eq(RoadmapWorld.weather_grade_color("clear", 1), Color.WHITE)
	assert_ne(RoadmapWorld.weather_grade_color("storm", 12), Color.WHITE)
	var lut := RoadmapWorld.make_weather_lut("acid_rain")
	assert_not_null(lut)
	assert_gt(lut.get_width(), 0)
	var lut_material := RoadmapWorld.make_lut_material(lut)
	assert_true(lut_material.shader.code.contains("lut"))
	var fsr_material := RoadmapWorld.make_fsr_material(0.75)
	assert_true(fsr_material.shader.code.contains("sharpness"))
	assert_almost_eq(float(fsr_material.get_shader_parameter("sharpness")), 0.75, 0.0001)
	var ssao_material := RoadmapWorld.make_ssao_material(0.4)
	assert_true(ssao_material.shader.code.contains("occlusion"))
	assert_almost_eq(float(ssao_material.get_shader_parameter("strength")), 0.4, 0.0001)
	assert_eq(RoadmapWorld.occluder_polygon("circle", Vector2(20, 20)).size(), 12)
	assert_eq(RoadmapWorld.occluder_polygon("box", Vector2(20, 20)).size(), 4)
	var occluder := RoadmapWorld.make_light_occluder("circle", Vector2(24, 24))
	add_child_autofree(occluder)
	assert_not_null(occluder.occluder)
	assert_gte(occluder.occluder.polygon.size(), 3)
	assert_gt(RoadmapWorld.make_light_texture().get_width(), 0)
	var flash := RoadmapWorld.make_flash_light(Color.RED)
	add_child_autofree(flash)
	assert_eq(flash.energy, 3.0)
	var reactor := RoadmapWorld.make_reactor_light()
	add_child_autofree(reactor)
	assert_eq(reactor.name, "BossReactorLight")

# --- Game.gd integration --------------------------------------------------------

func test_game_resolution_letterbox_and_fsr_toggle() -> void:
	SettingsManager.set_roadmap_value(RoadmapWorld.KEY_RESOLUTION, "3440x1440")
	var game := _create_game()
	assert_eq(game.active_resolution, Vector2i(3440, 1440))
	var content: Rect2 = game.apply_letterbox_for_size(Vector2(3440, 1440))
	assert_almost_eq(content.size.x, 3360.0, 1.0)
	assert_gt(game._letterbox_bars[0].size.x, 0.0)
	game.set_fsr_upscaling_enabled(true)
	assert_true(game._fsr_overlay.visible)
	assert_not_null(game._fsr_overlay.material)
	game.set_fsr_upscaling_enabled(false)
	assert_false(game._fsr_overlay.visible)
	game.set_ssao_enabled(true)
	assert_true(game._ssao_overlay.visible)
	assert_not_null(game._ssao_overlay.material)
	game.set_ssao_enabled(false)
	assert_false(game._ssao_overlay.visible)
	game.apply_resolution(Vector2i(99999, 1))
	assert_eq(game.active_resolution, RoadmapWorld.MAX_RESOLUTION)
	assert_eq(SettingsManager.get_roadmap_value(RoadmapWorld.KEY_RESOLUTION, ""), "3840x2160")

func test_game_secondary_viewports_and_rear_view_toggle() -> void:
	var game := _create_game()
	assert_eq(game._minimap_viewport.world_2d, game.world.get_world_2d())
	assert_eq(game._rear_view_viewport.world_2d, game.world.get_world_2d())
	var camera_has_enabled := false
	for prop in game._rear_view_camera.get_property_list():
		if str(prop.get("name", "")) == "enabled":
			camera_has_enabled = true
			break
	game.set_rear_view_enabled(false)
	assert_false(game._rear_view_container.visible)
	if camera_has_enabled:
		assert_false(bool(game._rear_view_camera.get("enabled")))
	game.set_rear_view_enabled(true)
	assert_true(game._rear_view_container.visible)
	if camera_has_enabled:
		assert_true(bool(game._rear_view_camera.get("enabled")))

func test_game_music_lighting_bbcode_and_weather_lut() -> void:
	var game := _create_game()
	GameManager.boss_active = true
	GameManager.difficulty_tier = 8
	GameManager.enemy_list.clear()
	var intensity: Array = game.compute_music_intensity()
	assert_eq(intensity[0], true)
	assert_eq(intensity[1], 8)
	assert_almost_eq(float(intensity[2]), 0.0, 0.0001)
	assert_true(game.bbcode_for_damage("-5", 5).contains("#ff3366"))
	var flash: PointLight2D = game.spawn_explosion_flash(Vector2(12, 34), Color.RED)
	assert_not_null(flash)
	assert_eq(flash.position, Vector2(12, 34))
	var boss := Node2D.new()
	add_child_autofree(boss)
	game._on_boss_spawned_flash(boss)
	assert_not_null(boss.get_node_or_null("BossReactorLight"))
	game._apply_weather_lut()
	assert_true(game._grade_overlay.visible)
	assert_not_null(game._weather_lut)

func test_game_rich_popup_pool_and_damage_tiers() -> void:
	var game := _create_game()
	assert_true(game.bbcode_for_damage("-2", 2).contains("#a0ff60"))
	assert_true(game.bbcode_for_damage("-4", 4).contains("#ffcc00"))
	var popup: RichTextLabel = game._get_rich_popup_label()
	assert_is(popup, RichTextLabel)
	assert_true(popup.bbcode_enabled)
	game._return_rich_popup_label(popup)
	assert_gte(game._rich_popup_pool.size(), 1)
	var reused: RichTextLabel = game._get_rich_popup_label()
	assert_eq(reused, popup)

# --- Highway.gd integration -----------------------------------------------------

func test_highway_tilemap_population_toggle_and_occluders() -> void:
	var highway := _create_highway()
	assert_not_null(highway.lane_tilemap)
	assert_gt(highway._tile_cells.size(), 0)
	var chunk: Node2D = highway.active_chunks[0]
	var cells: Array = chunk.get_meta("tilemap_cells", [])
	assert_gt(cells.size(), 0)
	var tiles := _find_child_named(chunk, "Tiles")
	var rail := _find_child_named(tiles, "LeftRail")
	assert_not_null(rail)
	assert_false(rail.visible)
	assert_not_null(_find_child_named(tiles, "LeftRailOccluder"))
	highway.set_tilemap_highway_enabled(false)
	assert_eq(highway._tile_cells.size(), 0)
	assert_true(rail.visible)
	highway.set_tilemap_highway_enabled(true)
	assert_gt(highway._tile_cells.size(), 0)
	assert_false(rail.visible)

# --- HUD.gd integration ---------------------------------------------------------

func test_hud_rich_readouts_scaling_and_toggle() -> void:
	var hud := _create_hud()
	assert_not_null(hud.health_rich_label)
	assert_not_null(hud.multiplier_rich_label)
	assert_not_null(hud.tier_rich_label)
	assert_not_null(hud.lives_rich_label)
	hud._on_multiplier_updated(4)
	assert_eq(hud.multiplier_label.text, "x4")
	assert_true(hud.multiplier_rich_label.text.contains("#ffcc00"))
	hud._on_tier_changed(14)
	assert_eq(hud.tier_label.text, "TIER 14")
	assert_true(hud.tier_rich_label.text.contains(RoadmapWorld.bbcode_color(14)))
	hud._on_lives_updated(1)
	assert_true(hud.lives_rich_label.text.contains("#ff3366"))
	hud._on_health_updated(1)
	assert_true(hud.health_rich_label.text.contains("#ff3366"))
	hud.set_hud_text_scale(2.0)
	assert_almost_eq(hud.hud_text_scale, 2.0, 0.0001)
	assert_almost_eq(
		float(SettingsManager.get_roadmap_value(RoadmapWorld.KEY_HUD_TEXT_SCALE, 1.0)),
		2.0,
		0.0001
	)
	assert_eq(
		hud.multiplier_rich_label.get_theme_font_size("normal_font_size"),
		RoadmapWorld.scaled_font_size(20, 2.0)
	)
	hud.set_rich_hud_enabled(false)
	assert_false(hud.multiplier_rich_label.visible)
	assert_true(hud.multiplier_label.visible)
	hud.set_rich_hud_enabled(true)
	assert_true(hud.multiplier_rich_label.visible)
	assert_false(hud.multiplier_label.visible)
