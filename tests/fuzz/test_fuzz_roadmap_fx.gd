extends GutTest

# Fuzz coverage targets: Interceptor.gd, WeatherSystem.gd, RoadmapFx.gd
const InterceptorScript = preload("res://scripts/scenes/player/Interceptor.gd")
const WeatherSystemScript = preload("res://scripts/scenes/world/WeatherSystem.gd")
const RoadmapFx = preload("res://scripts/utils/RoadmapFx.gd")

var _rng: RandomNumberGenerator
var _original_features: Dictionary = {}
var _original_particle_scale: Variant = 1.0

func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 20261118
	_original_features = {
		RoadmapFx.FEATURE_GPU_EFFECTS: SettingsManager.is_feature_enabled(RoadmapFx.FEATURE_GPU_EFFECTS, true),
		RoadmapFx.FEATURE_LIGHTING_EFFECTS: SettingsManager.is_feature_enabled(RoadmapFx.FEATURE_LIGHTING_EFFECTS, true),
		RoadmapFx.FEATURE_MOTION_INTERPOLATION: SettingsManager.is_feature_enabled(RoadmapFx.FEATURE_MOTION_INTERPOLATION, true),
		RoadmapFx.FEATURE_HDR_LIGHTING: SettingsManager.is_feature_enabled(RoadmapFx.FEATURE_HDR_LIGHTING, true),
	}
	_original_particle_scale = SettingsManager.get_roadmap_value(RoadmapFx.PARTICLE_SCALE_SETTING, 1.0)

func after_each() -> void:
	for key in _original_features.keys():
		SettingsManager.set_feature_enabled(key, _original_features[key])
	SettingsManager.set_roadmap_value(RoadmapFx.PARTICLE_SCALE_SETTING, _original_particle_scale)

func _random_transform() -> Transform2D:
	var angle: float = _rng.randf_range(-TAU, TAU)
	var scale := Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-2.0, 2.0))
	var origin := Vector2(_rng.randf_range(-500.0, 500.0), _rng.randf_range(-500.0, 500.0))
	return Transform2D(angle, scale, 0.0, origin)

func _random_string(length: int) -> String:
	var value := ""
	for i in length:
		value += char(_rng.randi_range(32, 126))
	return value

func test_fuzz_interpolation_with_valid_and_invalid_inputs() -> void:
	for i in 20:
		var from := _random_transform()
		var to := _random_transform()
		var alpha: float = _rng.randf_range(-3.0, 3.0)
		var result: Transform2D = RoadmapFx.interpolate_transform(from, to, alpha)
		assert_true(result.is_finite(), "Interpolated transform must stay finite")
	for invalid in [NAN, INF, -INF]:
		var result: Transform2D = RoadmapFx.interpolate_transform(_random_transform(), _random_transform(), invalid)
		assert_true(result.is_finite(), "Invalid alpha must not corrupt transform")

func test_fuzz_weather_lut_names() -> void:
	var names: Array = ["clear", "rain", "light_rain", "acid_rain", "storm", "ACID_RAIN", "", "not_weather"]
	for name in names:
		var lut: Texture2D = RoadmapFx.make_weather_lut(str(name))
		assert_not_null(lut, "LUT generation should never return null")
		assert_gt(lut.get_width(), 0)
	for i in 20:
		var lut: Texture2D = RoadmapFx.make_weather_lut(_random_string(_rng.randi_range(0, 12)))
		assert_not_null(lut, "Random weather names should be handled")

func test_fuzz_occluders_and_procedural_textures() -> void:
	for i in 20:
		var points := PackedVector2Array()
		for j in _rng.randi_range(0, 7):
			points.append(Vector2(_rng.randf_range(-200.0, 200.0), _rng.randf_range(-200.0, 200.0)))
		var occluder: LightOccluder2D = RoadmapFx.create_light_occluder(points, i % 2 == 0)
		add_child_autofree(occluder)
		assert_not_null(occluder, "LightOccluder2D creation should not crash")
		assert_not_null(occluder.occluder, "Occluder resource should always be attached")
		var tint := Color(_rng.randf_range(0.0, 1.0), _rng.randf_range(0.0, 1.0), _rng.randf_range(0.0, 1.0), 1.0)
		var ring: Texture2D = RoadmapFx.make_ring_texture(_rng.randi_range(8, 64), _rng.randf_range(-0.5, 1.0), tint)
		assert_gt(ring.get_width(), 0, "Ring texture should have valid dimensions")
		var glow: Texture2D = RoadmapFx.make_glow_texture(_rng.randi_range(2, 48), tint)
		assert_gt(glow.get_height(), 0, "Glow texture should have valid dimensions")

func test_fuzz_particle_amount_scaling() -> void:
	for i in 30:
		var amount: int = RoadmapFx.scaled_particle_amount(_rng.randi_range(-10, 1000), _rng.randf_range(-2.0, 5.0))
		assert_true(amount >= 1 and amount <= RoadmapFx.MAX_PARTICLE_AMOUNT, "Scaled amount should stay in range")
	for invalid in [NAN, INF, -INF]:
		assert_eq(RoadmapFx.scaled_particle_amount(50, invalid), 50, "Invalid scale should fall back to base amount")
	SettingsManager.set_roadmap_value(RoadmapFx.PARTICLE_SCALE_SETTING, _rng.randf_range(0.1, 3.0))
	assert_gt(RoadmapFx.scaled_particle_amount(100), 0, "Roadmap-driven scaling should produce a positive count")

func test_fuzz_interceptor_explosion_fx_and_toggles() -> void:
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var player: Node = load("res://scenes/player/Interceptor.tscn").instantiate()
	add_child_autofree(player)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	assert_not_null(InterceptorScript, "Interceptor.gd should be loadable")
	assert_eq(player._shockwave_pool.size(), InterceptorScript.EXPLOSION_POOL_SIZE, "Pool size should remain stable")
	for i in 6:
		var enabled: bool = i % 2 == 0
		SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_GPU_EFFECTS, enabled)
		SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_LIGHTING_EFFECTS, enabled)
		player.boost_active = i % 3 == 0
		player._update_boost_trail()
		var pos := Vector2(_rng.randf_range(-800.0, 800.0), _rng.randf_range(-800.0, 800.0))
		player.spawn_explosion_fx(pos)
		assert_true(player._boost_trail is GPUParticles2D)
		assert_true(player._boost_smoke is GPUParticles2D)
		for ring in player._shockwave_pool:
			assert_true(ring is GPUParticles2D)

func test_fuzz_weather_gpu_particles_and_lut_hooks() -> void:
	var ws: Node = load("res://scenes/world/WeatherSystem.tscn").instantiate()
	add_child_autofree(ws)
	assert_not_null(WeatherSystemScript, "WeatherSystem.gd should be loadable")
	for i in 20:
		ws.set_weather(_rng.randi_range(0, 3))
		ws.weather_intensity = _rng.randf_range(0.0, 1.0)
		ws._update_rain_particles(0.016)
		var lut: Texture2D = ws.get_color_grading_lut(_random_string(_rng.randi_range(0, 10)))
		if RoadmapFx.hdr_lighting_enabled():
			assert_not_null(lut, "LUT hook should return a texture when enabled")
		else:
			assert_null(lut, "LUT hook should be disabled")
	assert_true(ws._rain_particles is GPUParticles2D)
	assert_true(ws._splash_particles is GPUParticles2D)

func test_fuzz_flash_light_and_occluder_toggles() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	for i in 8:
		SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_LIGHTING_EFFECTS, i % 2 == 0)
		var light: PointLight2D = RoadmapFx.spawn_explosion_flash(
			host,
			Vector2(_rng.randf_range(-300.0, 300.0), _rng.randf_range(-300.0, 300.0)),
			Color(1.0, _rng.randf_range(0.0, 1.0), 0.2, 1.0),
			_rng.randf_range(-1.0, 3.0),
			_rng.randf_range(-1.0, 8.0)
		)
		if RoadmapFx.lighting_effects_enabled():
			assert_not_null(light, "Flash should be created when lighting is enabled")
		else:
			assert_null(light, "Flash should be gated off")
		var points := PackedVector2Array([Vector2(NAN, 0.0), Vector2(1.0, INF), Vector2.ZERO, Vector2(2.0, 2.0)])
		var occluder: LightOccluder2D = RoadmapFx.create_light_occluder(points)
		add_child_autofree(occluder)
		assert_not_null(occluder, "Invalid points should still produce an occluder")
