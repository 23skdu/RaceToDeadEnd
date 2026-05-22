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
	var ws = load("res://scripts/scenes/world/WeatherSystem.gd")
	assert_eq(ws.RAIN_DROP_COUNT, 200, "Rain drop count")
	assert_eq(ws.LIGHTNING_DAMAGE, 1, "Lightning damage")
	assert_eq(ws.ACID_RAIN_DAMAGE_INTERVAL, 2.0, "Acid rain damage interval")
	assert_eq(ws.ACID_RAIN_DAMAGE, 1, "Acid rain damage")
	assert_eq(ws.CLOUD_COUNT, 5, "Cloud count")

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
	assert_eq(ws.rain_particles.size(), 200, "Should have 200 rain particles")

func test_rain_particle_has_node():
	var ws = _create_weather()
	assert_true(ws.rain_particles[0]["node"] != null, "Particle should have node")

func test_rain_particle_has_speed():
	var ws = _create_weather()
	assert_gt(ws.rain_particles[0]["speed"], 0.0, "Particle should have speed")

func test_rain_particle_inactive_initially():
	var ws = _create_weather()
	assert_false(ws.rain_particles[0]["active"], "Particle should be inactive initially")

func test_reset_rain_particle_activates():
	var ws = _create_weather()
	var p = ws.rain_particles[0]
	ws.current_weather = ws.WeatherType.ACID_RAIN
	ws._reset_rain_particle(p)
	assert_true(p["pos"].y < 0.0, "Particle should be reset above screen")

func test_rain_particle_color_acid_rain():
	var ws = _create_weather()
	ws.current_weather = ws.WeatherType.ACID_RAIN
	var p = ws.rain_particles[0]
	ws._reset_rain_particle(p)
	assert_gt(p["node"].color.g, p["node"].color.r, "Acid rain should be green")
	assert_gt(p["node"].color.g, p["node"].color.b, "Acid rain should be green")

func test_rain_particle_color_light_rain():
	var ws = _create_weather()
	ws.current_weather = ws.WeatherType.LIGHT_RAIN
	var p = ws.rain_particles[0]
	ws._reset_rain_particle(p)
	assert_gt(p["node"].color.b, p["node"].color.r, "Light rain should be bluish")

func test_lightning_bolt_has_points():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.STORM)
	var start = Vector2(0, -400)
	ws._create_lightning_bolt(start)
	await ws.get_tree().process_frame
	var container = ws.get_node_or_null("LightningContainer")
	if container:
		var bolts = []
		for child in container.get_children():
			if child is Line2D:
				bolts.append(child)
		assert_gt(bolts.size(), 0, "Should have lightning bolts")

func test_lightning_flash_created():
	var ws = _create_weather()
	var flash = ws._create_lightning_flash(Vector2(0, -400))
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

func test_rain_updates_particle_positions():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	var p = ws.rain_particles[0]
	p["active"] = true
	p["pos"] = Vector2(100, 700)
	p["speed"] = 500
	p["wind"] = 0
	ws._update_rain(0.1)
	assert_gt(p["pos"].y, 700.0, "Particle should move down")

func test_rain_particle_wraps():
	var ws = _create_weather()
	ws._set_weather(ws.WeatherType.ACID_RAIN)
	var p = ws.rain_particles[0]
	p["active"] = true
	p["pos"] = Vector2(100, 900)
	p["speed"] = 500
	p["wind"] = 0
	ws._update_rain(0.1)
	assert_lt(p["pos"].y, 0.0, "Particle should reset when below screen")

func test_white_texture_created():
	var ws = _create_weather()
	assert_true(ws.white_texture != null, "White texture should be created")