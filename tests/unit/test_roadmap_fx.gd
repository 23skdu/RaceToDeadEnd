extends GutTest

# Coverage targets: Interceptor.gd, WeatherSystem.gd, RoadmapFx.gd
const InterceptorScript = preload("res://scripts/scenes/player/Interceptor.gd")
const WeatherSystemScript = preload("res://scripts/scenes/world/WeatherSystem.gd")
const RoadmapFx = preload("res://scripts/utils/RoadmapFx.gd")

var _original_features: Dictionary = {}
var _original_particle_scale: Variant = 1.0

func before_each() -> void:
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

func _create_player() -> Node:
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var player: Node = load("res://scenes/player/Interceptor.tscn").instantiate()
	add_child_autofree(player)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	return player

func test_feature_gate_helpers_follow_settings() -> void:
	assert_true(RoadmapFx.gpu_effects_enabled(), "gpu_effects defaults to enabled")
	assert_true(RoadmapFx.lighting_effects_enabled(), "lighting_effects defaults to enabled")
	assert_true(RoadmapFx.motion_interpolation_enabled(), "motion_interpolation defaults to enabled")
	assert_true(RoadmapFx.hdr_lighting_enabled(), "hdr_lighting defaults to enabled")
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_GPU_EFFECTS, false)
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_LIGHTING_EFFECTS, false)
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_MOTION_INTERPOLATION, false)
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_HDR_LIGHTING, false)
	assert_false(RoadmapFx.gpu_effects_enabled())
	assert_false(RoadmapFx.lighting_effects_enabled())
	assert_false(RoadmapFx.motion_interpolation_enabled())
	assert_false(RoadmapFx.hdr_lighting_enabled())

func test_particle_amount_scaling() -> void:
	SettingsManager.set_roadmap_value(RoadmapFx.PARTICLE_SCALE_SETTING, 0.5)
	assert_eq(RoadmapFx.scaled_particle_amount(100), 50, "Roadmap scale should halve particle count")
	assert_eq(RoadmapFx.scaled_particle_amount(100, 2.0), 200, "Explicit scale should override setting")
	assert_eq(RoadmapFx.scaled_particle_amount(-10), 1, "Invalid base should clamp to one")
	assert_eq(RoadmapFx.scaled_particle_amount(100, NAN), 100, "NaN scale should fall back to one")
	assert_eq(RoadmapFx.scaled_particle_amount(100000, 4.0), RoadmapFx.MAX_PARTICLE_AMOUNT, "Amount should cap")

func test_procedural_textures_have_pixels() -> void:
	var ring: Texture2D = RoadmapFx.make_ring_texture(32)
	var glow: Texture2D = RoadmapFx.make_glow_texture(16, Color(1.0, 0.5, 0.2, 1.0))
	assert_eq(ring.get_width(), 32, "Ring texture should use requested size")
	assert_eq(glow.get_height(), 16, "Glow texture should use requested size")
	assert_true(ring.get_width() > 0 and glow.get_width() > 0)

func test_interceptor_gpu_emitters_have_process_materials() -> void:
	var player: Node = _create_player()
	var emitters: Array = [
		player._boost_exhaust,
		player._muzzle_flash,
		player._boost_trail,
		player._boost_smoke,
	]
	for emitter in emitters:
		assert_not_null(emitter, "Emitter should exist")
		assert_true(emitter is GPUParticles2D, "Emitter should be GPUParticles2D")
		assert_true(emitter.process_material is ParticleProcessMaterial, "Emitter should use ParticleProcessMaterial")
		assert_not_null(emitter.texture, "Emitter should have a procedural texture")
		assert_gt(emitter.amount, 0, "Emitter should have a scaled particle count")
	assert_eq(player._boost_exhaust.name, "BoostExhaust")
	assert_eq(player._muzzle_flash.name, "MuzzleFlash")
	assert_eq(player._boost_trail.name, "BoostTrail")
	assert_eq(player._boost_smoke.name, "BoostSmoke")
	assert_eq(player._shockwave_pool.size(), InterceptorScript.EXPLOSION_POOL_SIZE, "Explosion emitters should be pooled")
	for ring in player._shockwave_pool:
		assert_true(ring is GPUParticles2D)
		assert_true(ring.one_shot, "Shockwave emitters should be one-shot")
		assert_true(ring.process_material is ParticleProcessMaterial)

func test_interceptor_spawn_explosion_fx_reuses_pool_and_adds_flash() -> void:
	var player: Node = _create_player()
	var emitting_before: int = 0
	for ring in player._shockwave_pool:
		if ring.emitting:
			emitting_before += 1
	player.spawn_explosion_fx(Vector2(120.0, -40.0))
	var emitting_after: int = 0
	for ring in player._shockwave_pool:
		if ring.emitting:
			emitting_after += 1
	assert_eq(emitting_after, emitting_before + 1, "Exactly one pooled ring should be triggered")
	var flash: Node = player.get_node_or_null("ExplosionShockwaveHost/ExplosionFlash")
	assert_not_null(flash, "Explosion flash light should be spawned")
	assert_true(flash is PointLight2D, "Flash should be a PointLight2D")
	assert_almost_eq(flash.global_position.x, 120.0, 0.01)

func test_interceptor_explosion_fx_respects_feature_gates() -> void:
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_GPU_EFFECTS, false)
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_LIGHTING_EFFECTS, false)
	var player: Node = _create_player()
	player.spawn_explosion_fx(Vector2.ZERO)
	for ring in player._shockwave_pool:
		assert_false(ring.emitting, "Shockwave should not emit with gpu_effects disabled")
	assert_null(player.get_node_or_null("ExplosionShockwaveHost/ExplosionFlash"), "Flash should not spawn with lighting_effects disabled")

func test_interceptor_headlight_has_shadows_and_underglow_is_neon() -> void:
	var player: Node = _create_player()
	assert_not_null(player._headlight, "Headlight should exist")
	assert_true(player._headlight.shadow_enabled, "Headlight should cast shadows")
	assert_true(player._headlight.energy > 1.0, "Headlight should be strengthened")
	assert_not_null(player._underglow, "Underglow should exist")
	assert_gt(player._underglow.energy, 0.0, "Underglow should be visible")
	assert_gt(player._underglow.color.b, player._underglow.color.r, "Underglow should be neon blue")

func test_explosion_flash_helper_is_gated() -> void:
	var player: Node = _create_player()
	var flash: PointLight2D = RoadmapFx.spawn_explosion_flash(player.get_parent(), Vector2(10.0, 20.0))
	assert_not_null(flash, "Flash helper should create a light when enabled")
	assert_true(flash is PointLight2D)
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_LIGHTING_EFFECTS, false)
	assert_null(RoadmapFx.spawn_explosion_flash(player.get_parent(), Vector2.ZERO), "Flash helper should be gated")

func test_light_occluder_resources_are_created_and_gated() -> void:
	var points := PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0)])
	var polygon: OccluderPolygon2D = RoadmapFx.make_occluder_polygon(points, true)
	assert_true(polygon is OccluderPolygon2D)
	assert_eq(polygon.polygon.size(), 3, "Polygon should keep valid points")
	assert_true(polygon.closed, "Polygon should be closed by default")
	var occluder: LightOccluder2D = RoadmapFx.create_light_occluder(points)
	add_child_autofree(occluder)
	assert_true(occluder is LightOccluder2D)
	assert_not_null(occluder.occluder, "Occluder resource should be attached")
	assert_eq(occluder.occluder_light_mask, 1, "Lighting enabled should set occluder mask")
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_LIGHTING_EFFECTS, false)
	var disabled: LightOccluder2D = RoadmapFx.create_light_occluder(points)
	add_child_autofree(disabled)
	assert_eq(disabled.occluder_light_mask, 0, "Disabled lighting should clear occluder mask")

func test_interpolate_transform_endpoints_and_clamping() -> void:
	var from := Transform2D(0.0, Vector2.ZERO)
	var to := Transform2D(PI * 0.5, Vector2(10.0, 20.0))
	var mid: Transform2D = RoadmapFx.interpolate_transform(from, to, 0.5)
	assert_almost_eq(mid.origin.x, 5.0, 0.001, "Origin X should be halfway")
	assert_almost_eq(mid.origin.y, 10.0, 0.001, "Origin Y should be halfway")
	assert_almost_eq(mid.get_rotation(), PI * 0.25, 0.001, "Rotation should be halfway")
	assert_true(RoadmapFx.interpolate_transform(from, to, -3.0).is_equal_approx(from), "Negative alpha should clamp to start")
	assert_true(RoadmapFx.interpolate_transform(from, to, 5.0).is_equal_approx(to), "Large alpha should clamp to end")
	assert_true(RoadmapFx.interpolate_transform(from, to, NAN).is_equal_approx(from), "NaN alpha should be safe")

func test_interceptor_tracks_sprite_transform_for_interpolation() -> void:
	var player: Node = _create_player()
	player.velocity.x = 400.0
	player._physics_process(0.016)
	assert_true(player._sprite_interpolation_ready, "Physics step should capture a sprite transform")
	player._apply_sprite_interpolation()
	assert_true(player.sprite.transform.is_finite(), "Interpolated sprite transform should stay finite")
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_MOTION_INTERPOLATION, false)
	player._apply_sprite_interpolation()
	assert_true(player.sprite.transform.is_finite(), "Disabled interpolation should be safe")

func test_weather_lut_generation_is_distinct_per_weather() -> void:
	var clear: Texture2D = RoadmapFx.make_weather_lut("clear")
	var rain: Texture2D = RoadmapFx.make_weather_lut("rain")
	var acid: Texture2D = RoadmapFx.make_weather_lut("acid_rain")
	var storm: Texture2D = RoadmapFx.make_weather_lut("storm")
	for lut in [clear, rain, acid, storm]:
		assert_not_null(lut, "LUT should be generated")
		assert_true(lut is Texture2D)
		assert_eq(lut.get_width(), RoadmapFx.LUT_SIZE, "LUT should be small")
	var clear_tex: GradientTexture1D = clear as GradientTexture1D
	var acid_tex: GradientTexture1D = acid as GradientTexture1D
	var storm_tex: GradientTexture1D = storm as GradientTexture1D
	assert_not_null(clear_tex)
	assert_ne(clear_tex.gradient.colors[0], acid_tex.gradient.colors[0], "Acid LUT should be green-tinted")
	assert_ne(clear_tex.gradient.colors[0], storm_tex.gradient.colors[0], "Storm LUT should be desaturated")
	assert_not_null(RoadmapFx.make_weather_lut("unknown"), "Unknown weather should still return a fallback LUT")

func test_apply_weather_lut_is_gated() -> void:
	var env := Environment.new()
	RoadmapFx.apply_weather_lut(env, "acid_rain")
	assert_true(env.adjustment_enabled, "HDR grading should enable adjustments")
	assert_not_null(env.adjustment_color_correction, "Weather LUT should be attached to environment")
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_HDR_LIGHTING, false)
	var disabled_env := Environment.new()
	RoadmapFx.apply_weather_lut(disabled_env, "acid_rain")
	assert_false(disabled_env.adjustment_enabled, "Grading should be skipped when hdr_lighting is off")

func test_weather_system_gpu_particles_and_grading_hook() -> void:
	var ws: Node = load("res://scenes/world/WeatherSystem.tscn").instantiate()
	add_child_autofree(ws)
	assert_not_null(WeatherSystemScript, "WeatherSystem.gd should be loadable")
	assert_true(ws._rain_particles is GPUParticles2D, "Rain should use GPU particles")
	assert_true(ws._splash_particles is GPUParticles2D, "Splashes should use GPU particles")
	assert_gt(ws._rain_particles.amount, 0)
	ws._set_weather(ws.WeatherType.STORM)
	ws._update_rain_particles(0.0)
	assert_true(ws._rain_particles.emitting, "Rain should emit during storm")
	var lut: Texture2D = ws.get_color_grading_lut("storm")
	assert_not_null(lut, "WeatherSystem should expose the weather LUT hook")
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_GPU_EFFECTS, false)
	ws._update_rain_particles(0.0)
	assert_false(ws._rain_particles.emitting, "Rain should stop when gpu_effects is off")
	SettingsManager.set_feature_enabled(RoadmapFx.FEATURE_HDR_LIGHTING, false)
	assert_null(ws.get_color_grading_lut("storm"), "LUT hook should be gated by hdr_lighting")

func test_project_hdr_and_aces_environment_settings() -> void:
	assert_true(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "Physics interpolation should stay enabled")
	assert_true(bool(ProjectSettings.get_setting("rendering/viewport/hdr_2d", false)), "HDR 2D should be enabled for HDR-friendly rendering")
	var env: Environment = load("res://assets/environments/game_env.tres") as Environment
	assert_not_null(env, "game_env.tres should load as Environment")
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_ACES, "Environment should use ACES tonemapping")
	assert_true(env.glow_enabled, "Bloom should remain enabled")
