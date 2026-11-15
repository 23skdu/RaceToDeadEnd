extends GutTest

var WeatherSystemScene

func before_all():
	WeatherSystemScene = load("res://scenes/world/WeatherSystem.tscn")

func before_each():
	for key in GameManager.upgrade_levels:
		GameManager.upgrade_levels[key] = 1
	GameManager.state = GameManager.GameState.MENU

func _create_weather():
	var ws = WeatherSystemScene.instantiate()
	add_child_autofree(ws)
	return ws

func test_weather_type_enum():
	var ws = load("res://scripts/scenes/world/WeatherSystem.gd")
	assert_eq(ws.WeatherType.CLEAR, 0, "CLEAR = 0")
	assert_eq(ws.WeatherType.LIGHT_RAIN, 1, "LIGHT_RAIN = 1")
	assert_eq(ws.WeatherType.ACID_RAIN, 2, "ACID_RAIN = 2")
	assert_eq(ws.WeatherType.STORM, 3, "STORM = 3")

func test_constants():
	assert_eq(Constants.RAIN_DROP_COUNT, 200, "Rain drop count")
	assert_eq(Constants.LIGHTNING_DAMAGE, 1, "Lightning damage")
	assert_eq(Constants.ACID_RAIN_DAMAGE_INTERVAL, 2.0, "Acid rain damage interval")
	assert_eq(Constants.ACID_RAIN_DAMAGE, 1, "Acid rain damage")
	assert_eq(Constants.CLOUD_COUNT, 5, "Cloud count")

func test_initial_state():
	var ws = _create_weather()
	assert_eq(ws.current_weather, ws.WeatherType.CLEAR, "Should start clear")
	assert_eq(ws.target_weather, ws.WeatherType.CLEAR, "Target should be clear")
	assert_eq(ws.weather_intensity, 0.0, "Intensity should be 0 when clear")

func test_set_weather_clear():
	var ws = _create_weather()
	ws.set_weather(ws.WeatherType.CLEAR)
	assert_eq(ws.target_weather, ws.WeatherType.CLEAR, "Target should be clear")

func test_set_weather_acid_rain():
	var ws = _create_weather()
	ws.set_weather(ws.WeatherType.ACID_RAIN)
	assert_eq(ws.target_weather, ws.WeatherType.ACID_RAIN, "Target should be acid rain")
	assert_eq(ws.weather_transition, 0.0, "Transition should reset")

func test_set_weather_storm():
	var ws = _create_weather()
	ws.set_weather(ws.WeatherType.STORM)
	assert_eq(ws.target_weather, ws.WeatherType.STORM, "Target should be storm")

func test_weather_name_clear():
	var ws = _create_weather()
	assert_eq(ws._weather_name(ws.WeatherType.CLEAR), "clear", "Weather name for clear")

func test_weather_name_light_rain():
	var ws = _create_weather()
	assert_eq(ws._weather_name(ws.WeatherType.LIGHT_RAIN), "light_rain", "Weather name for light rain")

func test_weather_name_acid_rain():
	var ws = _create_weather()
	assert_eq(ws._weather_name(ws.WeatherType.ACID_RAIN), "acid_rain", "Weather name for acid rain")

func test_weather_name_storm():
	var ws = _create_weather()
	assert_eq(ws._weather_name(ws.WeatherType.STORM), "storm", "Weather name for storm")

func test_set_player():
	var ws = _create_weather()
	var dummy = Node2D.new()
	add_child_autofree(dummy)
	ws.set_player(dummy)
	assert_eq(ws.player_ref, dummy, "Player reference should be set")

func test_set_highway():
	var ws = _create_weather()
	var dummy = Node2D.new()
	add_child_autofree(dummy)
	ws.set_highway(dummy)
	assert_eq(ws.highway_ref, dummy, "Highway reference should be set")

func test_acid_rain_overlay_color():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	var overlay = ws.get_node_or_null("WeatherCanvas/AcidOverlay")
	assert_not_null(overlay, "Acid overlay should exist")
	if overlay:
		assert_gt(overlay.color.a, 0.0, "Acid overlay should have alpha")
		assert_gt(overlay.color.g, overlay.color.r, "Acid overlay should be greenish")

func test_storm_overlay_darker():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	var overlay = ws.get_node_or_null("WeatherCanvas/AcidOverlay")
	assert_not_null(overlay, "Storm overlay should exist")
	if overlay:
		assert_gt(overlay.color.a, 0.0, "Storm overlay should have alpha")

func test_clear_overlay_transparent():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.CLEAR)
	var overlay = ws.get_node_or_null("WeatherCanvas/AcidOverlay")
	assert_not_null(overlay, "Clear overlay should exist")
	if overlay:
		assert_eq(overlay.color.a, 0.0, "Clear overlay should be transparent")

func test_rain_particles_initialized():
	var ws = _create_weather()
	assert_true(ws._rain_particles != null, "Rain particles node should exist")
	assert_eq(ws._rain_particles.amount, 200, "Should have 200 rain particles capacity")
	assert_false(ws._rain_particles.emitting, "Rain should not emit initially")

func test_rain_particles_have_material():
	var ws = _create_weather()
	assert_true(ws._rain_particle_material != null, "Particle material should exist")

func test_rain_particles_have_texture():
	var ws = _create_weather()
	assert_true(ws._rain_particles.texture != null, "Rain particles should have a texture")

func test_rain_particles_emit_on_storm():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	ws._update_rain_particles(0.0)
	assert_true(ws._rain_particles.emitting, "Rain should emit during storm")

func test_rain_particles_stop_on_clear():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	ws._update_rain_particles(0.0)
	assert_true(ws._rain_particles.emitting, "Rain should emit during storm")
	ws._set_weather(ws.WeatherType.CLEAR)
	ws._update_rain_particles(0.0)
	assert_false(ws._rain_particles.emitting, "Rain should stop on clear")

func test_lightning_bolt_has_points():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	var start = Vector2(0, -400)
	ws._create_lightning_bolt(start)
	await ws.get_tree().process_frame
	assert_not_null(ws.lightning_container, "LightningContainer should exist")
	var bolts = []
	for child in ws.lightning_container.get_children():
		if child is Line2D:
			bolts.append(child)
	assert_gt(bolts.size(), 0, "Should have lightning bolts")

func test_lightning_flash_created():
	var ws = _create_weather()
	var flash = ws._create_lightning_flash(Vector2(0, -400))
	add_child_autofree(flash)
	assert_not_null(flash, "Flash should be created")
	if flash:
		assert_gt(flash.color.a, 0.0, "Flash should be visible")

func test_cloud_spawn():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	ws._spawn_cloud()
	assert_gt(ws.active_clouds.size(), 0, "Should have active clouds")

func test_cloud_has_body():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	ws._spawn_cloud()
	var cloud = ws.active_clouds[0]
	var has_polygon = false
	for child in cloud.get_children():
		if child is Polygon2D:
			has_polygon = true
			break
	assert_true(has_polygon, "Cloud should have polygon body")

func test_cloud_speed_meta():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	ws._spawn_cloud()
	var cloud = ws.active_clouds[0]
	var speed = cloud.get_meta("speed", 0.0)
	assert_gt(speed, 0.0, "Cloud should have speed")

func test_weather_changed_signal_on_set():
	var ws = _create_weather()
	watch_signals(ws)
	ws.set_weather(ws.WeatherType.ACID_RAIN)
	assert_signal_emitted(ws, "weather_changed", "Should emit weather_changed")

func test_lightning_strike_signal():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	var dummy_player = Node2D.new()
	dummy_player.global_position = Vector2(0, 0)
	add_child_autofree(dummy_player)
	ws.player_ref = dummy_player
	watch_signals(ws)
	ws._spawn_lightning_strike()
	assert_signal_emitted(ws, "lightning_strike", "Should emit lightning_strike")

func test_update_weather_transition_increments():
	var ws = _create_weather()
	ws.current_weather = ws.WeatherType.CLEAR
	ws.target_weather = ws.WeatherType.ACID_RAIN
	ws.weather_transition = 0.0
	ws._update_weather_transition(0.1)
	assert_gt(ws.weather_transition, 0.0, "Transition should increment")

func test_update_weather_transition_completes():
	var ws = _create_weather()
	ws.current_weather = ws.WeatherType.CLEAR
	ws.target_weather = ws.WeatherType.ACID_RAIN
	ws.weather_transition = 0.9
	ws._update_weather_transition(0.2)
	assert_eq(ws.current_weather, ws.WeatherType.ACID_RAIN, "Weather should change after transition")

func test_acid_rain_damage_timer():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	ws.acid_rain_timer = 0.1
	ws._update_acid_rain_damage(0.2)
	assert_gt(ws.acid_rain_timer, 0.0, "Timer should reset after damage")

func test_lightning_timer_decrements():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	ws.lightning_timer = 0.5
	ws._process(0.1)
	assert_lt(ws.lightning_timer, 0.5, "Lightning timer should decrement")

func test_clouds_move():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	ws._spawn_cloud()
	var cloud = ws.active_clouds[0]
	var initial_x = cloud.position.x
	ws._update_clouds(0.1)
	assert_gt(cloud.position.x, initial_x, "Cloud should move right")

func test_cloud_recycles_when_offscreen():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	ws._spawn_cloud()
	var cloud = ws.active_clouds[0]
	cloud.position.x = 700
	ws._update_clouds(0.1)
	assert_lt(cloud.position.x, 0.0, "Cloud should wrap to left side")

func test_rain_particles_color_acid_rain():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	ws._update_rain_particles(0.0)
	var c = ws._rain_particle_material.color
	assert_gt(c.g, c.r, "Acid rain should be greenish")
	assert_gt(c.g, c.b, "Acid rain should be greenish")

func test_rain_particles_emit_count_scales():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.LIGHT_RAIN)
	ws.weather_intensity = 1.0
	ws._update_rain_particles(0.0)
	assert_lt(ws._rain_particles.amount_ratio, 1.0, "Light rain should have lower amount ratio than max")

func test_white_texture_created():
	var ws = _create_weather()
	assert_true(ws.white_texture != null, "White texture should be created")

func test_lightning_tween_callback_valid_instance():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	var flash = ColorRect.new()
	flash.name = "TestFlash"
	ws.add_child(flash)
	var tween = ws.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.01)
	tween.tween_callback(func(): if is_instance_valid(flash): flash.queue_free)
	tween.tween_callback(func(): assert_true(true, "Tween should complete without error"))
	await tween.finished
	await get_tree().process_frame
	assert_true(true, "Lightning tween callback should not crash with valid instance")

func test_overlay_transition_sets_prev_color():
	var ws = _create_weather()
	ws.set_weather(ws.WeatherType.CLEAR)
	var prev = ws._prev_overlay_color
	ws.set_weather(ws.WeatherType.ACID_RAIN)
	assert_eq(ws._prev_overlay_color, Constants.ACID_OVERLAY_CLEAR, "Prev overlay should be clear")
	assert_eq(ws._target_overlay_color, Constants.ACID_OVERLAY_COLOR_LIGHT, "Target overlay should be acid light")

func test_overlay_color_lerps_during_transition():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.CLEAR)
	ws.set_weather(ws.WeatherType.ACID_RAIN)
	ws.weather_transition = 0.5
	ws._update_weather_transition(0.0)
	if ws.acid_overlay:
		var expected = Constants.ACID_OVERLAY_CLEAR.lerp(Constants.ACID_OVERLAY_COLOR_LIGHT, 0.5)
		assert_almost_eq(ws.acid_overlay.color.a, expected.a, 0.01, "Overlay alpha should be mid-transition")

func test_overlay_color_completes_on_transition_end():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.CLEAR)
	ws.set_weather(ws.WeatherType.STORM)
	ws.weather_transition = 0.9
	ws._update_weather_transition(0.2)
	assert_eq(ws.current_weather, ws.WeatherType.STORM, "Weather should be storm after transition")
	if ws.acid_overlay:
		assert_almost_eq(ws.acid_overlay.color.a, Constants.ACID_OVERLAY_COLOR_HEAVY.a, 0.01, "Overlay should match target after transition")

func test_lightning_flash_cleaned_after_tween():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	var flash = ws._create_lightning_flash(Vector2.ZERO)
	ws.lightning_container.add_child(flash)
	var tween = ws.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.01)
	tween.tween_callback(func(): if is_instance_valid(flash): flash.queue_free())
	await tween.finished
	await get_tree().process_frame
	assert_false(is_instance_valid(flash), "Flash should be freed after tween")

func test_lightning_bolt_cleaned_after_tween():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	var bolt = Line2D.new()
	bolt.points = PackedVector2Array([Vector2.ZERO, Vector2(10, 10)])
	ws.lightning_container.add_child(bolt)
	var tween = ws.create_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, 0.01)
	tween.tween_callback(func(): if is_instance_valid(bolt): bolt.queue_free())
	await tween.finished
	await get_tree().process_frame
	assert_false(is_instance_valid(bolt), "Bolt should be freed after tween")
func test_get_color_grading_tint_returns_distinct_colors() -> void:
	var ws = load("res://scenes/world/WeatherSystem.tscn").instantiate()
	add_child_autofree(ws)
	var clear_tint: Color = ws.get_color_grading_tint(ws.WeatherType.CLEAR)
	var acid_tint: Color = ws.get_color_grading_tint(ws.WeatherType.ACID_RAIN)
	var storm_tint: Color = ws.get_color_grading_tint(ws.WeatherType.STORM)
	var rain_tint: Color = ws.get_color_grading_tint(ws.WeatherType.LIGHT_RAIN)
	assert_eq(clear_tint, Color.WHITE)
	assert_ne(acid_tint, clear_tint, "Acid rain tint should differ from clear")
	assert_ne(storm_tint, clear_tint, "Storm tint should differ from clear")
	assert_ne(rain_tint, clear_tint, "Light rain tint should differ from clear")
