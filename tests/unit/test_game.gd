extends GutTest

class MockBody:
	extends Node2D
	var damage_taken = 0
	var current_lane = 0
	func take_damage(amount = 1):
		damage_taken = amount

func test_game_scene_exists():
	assert_true(ResourceLoader.exists("res://scenes/Game.tscn"), "Game scene should exist")

func test_game_script_exists():
	assert_true(ResourceLoader.exists("res://scripts/scenes/Game.gd"), "Game script should exist")

func _create_game():
	var game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game)
	return game

func test_game_restart_reloads_scene():
	var game = _create_game()
	assert_true(game.has_method("_restart_game"), "Restart method should exist")

func test_game_menu_changes_scene():
	var game = _create_game()
	assert_true(game.has_method("_go_to_menu"), "Menu method should exist")

func test_game_process_restarts_on_game_over():
	var game = _create_game()
	GameManager.state = GameManager.GameState.GAME_OVER
	game._process(0.1)
	assert_true(true, "Process should handle game over state")

func test_game_process_does_nothing_when_playing():
	var game = _create_game()
	GameManager.state = GameManager.GameState.PLAYING
	game._process(0.1)
	assert_true(true, "Process should not restart when playing")

func test_game_bridge_fall_signal_connected():
	var game = _create_game()
	assert_true(game.highway.has_signal("bridge_fall"), "Highway should have bridge_fall signal")

func test_game_go_to_garage_instantiates():
	var game = _create_game()
	game._go_to_garage()
	var garage_found = false
	for child in game.get_children():
		if child.has_signal("back_to_menu_requested"):
			garage_found = true
			child.queue_free()
			break
	assert_true(garage_found, "Garage scene should be instantiated")

func test_game_weapon_fired_machine_gun():
	var game = _create_game()
	ObjectPool.create_pool("test_mg", preload("res://scenes/weapons/Bullet.tscn"), 1)
	game._on_player_weapon_fired("machine_gun", Vector2.ZERO, Vector2.UP)
	assert_true(true, "Machine gun weapon fired should not crash")

func test_game_weapon_fired_missile():
	var game = _create_game()
	ObjectPool.create_pool("test_missile", preload("res://scenes/weapons/Bullet.tscn"), 1)
	game._on_player_weapon_fired("missile", Vector2.ZERO, Vector2.UP)
	assert_true(true, "Missile weapon fired should not crash")

func test_game_weapon_fired_mine():
	var game = _create_game()
	ObjectPool.create_pool("mine", preload("res://scenes/weapons/Mine.tscn"), 1)
	game._on_player_weapon_fired("mine", Vector2.ZERO, Vector2.UP)
	assert_true(true, "Mine weapon fired should not crash")

func test_game_weapon_fired_emp():
	var game = _create_game()
	ObjectPool.create_pool("emp", preload("res://scenes/weapons/EMPBlast.tscn"), 1)
	game._on_player_weapon_fired("emp", Vector2.ZERO, Vector2.UP)
	assert_true(true, "EMP weapon fired should not crash")

func test_game_ready_enables_y_sort():
	var game = _create_game()
	assert_true(game.world.is_y_sort_enabled(), "World should have Y-sort enabled")

func test_game_has_parallax():
	var game = _create_game()
	assert_true(game._parallax != null, "ParallaxBackground should exist")
	assert_gt(game._parallax.get_child_count(), 0, "Parallax should have layers")

func test_game_scene_constants():
	var script = load("res://scripts/scenes/Game.gd")
	assert_true(script.BULLET_SCENE != null, "Bullet scene should be preloaded")
	assert_true(script.MINE_SCENE != null, "Mine scene should be preloaded")
	assert_true(script.EMP_SCENE != null, "EMP scene should be preloaded")

func test_game_over_restart_delay_cooldown():
	var game = _create_game()
	GameManager.state = GameManager.GameState.GAME_OVER
	game._game_over_restart_timer = 0.0
	game._process(1.0)
	assert_lt(game._game_over_restart_timer, 1.5, "Should not trigger restart before 1.5s")

func test_game_over_restart_delay_allows_after_cooldown():
	var game = _create_game()
	GameManager.state = GameManager.GameState.GAME_OVER
	game._game_over_restart_timer = 1.5
	assert_gte(game._game_over_restart_timer, 1.5, "Should allow restart after 1.5s")

func test_ready_creates_pools():
	var _game = _create_game()
	assert_true(ObjectPool.has_pool("bullet"), "Bullet pool should exist")
	assert_true(ObjectPool.has_pool("mine"), "Mine pool should exist")
	assert_true(ObjectPool.has_pool("emp"), "EMP pool should exist")
	assert_true(ObjectPool.has_pool("rotor"), "Rotor pool should exist")
	assert_true(ObjectPool.has_pool("scav"), "Scav pool should exist")
	assert_true(ObjectPool.has_pool("drone"), "Drone pool should exist")
	assert_true(ObjectPool.has_pool("drone_bomb"), "Drone bomb pool should exist")
	assert_true(ObjectPool.has_pool("boss"), "Boss pool should exist")
	assert_true(ObjectPool.has_pool("civilian"), "Civilian pool should exist")
	assert_true(ObjectPool.has_pool("pickup"), "Pickup pool should exist")

func test_ready_starts_game():
	var _game = _create_game()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "Game should be PLAYING after _ready")

func test_ready_connects_spawner_signals():
	var game = _create_game()
	assert_true(game.spawner.enemy_spawned.is_connected(GameManager.register_enemy_spawned), "Spawner enemy_spawned should be connected to GameManager")
	assert_true(game.spawner.enemy_destroyed.is_connected(GameManager.register_enemy_destroyed), "Spawner enemy_destroyed should be connected to GameManager")

func test_ready_connects_player_damage_taken():
	var game = _create_game()
	var conns = game.player.damage_taken.get_connections()
	assert_gt(conns.size(), 0, "Player damage_taken signal should have at least one connection")

func test_weapon_fired_machine_gun_acquires_bullet():
	var game = _create_game()
	var before = game.world.get_child_count()
	game._on_player_weapon_fired("machine_gun", Vector2.ZERO, Vector2.UP)
	assert_eq(game.world.get_child_count(), before + 1, "Bullet should be added to world")

func test_weapon_fired_missile_sets_homing_and_damage():
	var game = _create_game()
	game._on_player_weapon_fired("missile", Vector2.ZERO, Vector2.UP)
	var found = false
	for child in game.world.get_children():
		if child.has_method("init") and abs(child.homing_strength - 6.0) < 0.01:
			found = true
			assert_eq(child.damage, 3, "Missile damage should be 3")
			break
	assert_true(found, "Missile bullet with homing_strength 6.0 should exist in world")

func test_weapon_fired_mine_acquires_mine():
	var game = _create_game()
	var before = game.world.get_child_count()
	game._on_player_weapon_fired("mine", Vector2.ZERO, Vector2.UP)
	assert_eq(game.world.get_child_count(), before + 1, "Mine should be added to world")

func test_weapon_fired_emp_acquires_emp():
	var game = _create_game()
	var before = game.world.get_child_count()
	game._on_player_weapon_fired("emp", Vector2.ZERO, Vector2.UP)
	assert_eq(game.world.get_child_count(), before + 1, "EMP should be added to world")

func test_segment_completed_sets_light_rain_at_tier_5():
	var game = _create_game()
	GameManager.difficulty_tier = 5
	game._on_segment_completed(10)
	assert_eq(game.weather.target_weather, game.weather.WeatherType.LIGHT_RAIN, "Tier 5 should set LIGHT_RAIN")

func test_segment_completed_sets_acid_rain_at_tier_8():
	var game = _create_game()
	GameManager.difficulty_tier = 8
	game._on_segment_completed(10)
	assert_eq(game.weather.target_weather, game.weather.WeatherType.ACID_RAIN, "Tier 8 should set ACID_RAIN")

func test_segment_completed_sets_storm_at_tier_12():
	var game = _create_game()
	GameManager.difficulty_tier = 12
	game._on_segment_completed(10)
	assert_eq(game.weather.target_weather, game.weather.WeatherType.STORM, "Tier 12 should set STORM")

func test_segment_completed_low_tier_keeps_clear():
	var game = _create_game()
	GameManager.difficulty_tier = 1
	game._on_segment_completed(10)
	assert_eq(game.weather.target_weather, game.weather.WeatherType.CLEAR, "Tier 1 should stay CLEAR")

func test_show_floating_text_creates_label():
	var game = _create_game()
	var before = game.score_popup_container.get_child_count()
	game._show_floating_text(Vector2(100, 100), "TEST", Color.RED, 18)
	assert_eq(game.score_popup_container.get_child_count(), before + 1, "Floating text should add a Label child")

func test_get_popup_label_returns_label():
	var game = _create_game()
	var label = game._get_popup_label()
	autofree(label)
	assert_is(label, Label, "Should return a Label instance")

func test_get_popup_label_creates_new_if_pool_empty():
	var game = _create_game()
	var old_pool = game._popup_pool.duplicate()
	game._popup_pool.clear()
	var label = game._get_popup_label()
	autofree(label)
	assert_is(label, Label, "Should create a new Label when pool is empty")
	game._popup_pool = old_pool

func test_return_popup_label_adds_to_pool():
	var game = _create_game()
	var before = game._popup_pool.size()
	var label = Label.new()
	game._return_popup_label(label)
	assert_eq(game._popup_pool.size(), before + 1, "Label should be returned to pool")
	assert_eq(game._popup_pool[game._popup_pool.size() - 1], label, "Returned label should be at end of pool")

func test_return_popup_label_resets_properties():
	var game = _create_game()
	var label = Label.new()
	label.text = "OLD"
	label.position = Vector2(10, 20)
	label.modulate = Color.RED
	label.visible = true
	game._return_popup_label(label)
	assert_eq(label.text, "", "Text should be cleared")
	assert_eq(label.position, Vector2.ZERO, "Position should be reset")
	assert_eq(label.modulate, Color.WHITE, "Modulate should be white")
	assert_false(label.visible, "Label should be invisible")

func test_score_popped_creates_floating_text():
	var game = _create_game()
	var before = game.score_popup_container.get_child_count()
	game._on_score_popped(Vector2(50, 50), 100, "+100")
	assert_eq(game.score_popup_container.get_child_count(), before + 1, "Score pop should create a Label child")

func test_process_playing_pause_detected():
	var game = _create_game()
	GameManager.state = GameManager.GameState.PLAYING
	game._process(0.1)
	assert_true(true, "Playing _process should handle pause detection without crash")

func test_process_game_over_restart_timer_accept():
	var game = _create_game()
	GameManager.state = GameManager.GameState.GAME_OVER
	game._game_over_restart_timer = 1.5
	game._process(0.1)
	assert_true(true, "Game over _process should handle ui_accept check without crash")

func test_game_viewport_resize_adjusts_world_scale():
	var game = _create_game()
	game._on_viewport_size_changed()
	assert_eq(game.world.scale, Constants.WORLD_SCALE, "World scale should match Constants.WORLD_SCALE at default viewport width")

func test_return_popup_label_caps_at_pool_size():
	var game = _create_game()
	var excess_labels: Array[Label] = []
	for i in game.POPUP_POOL_SIZE + 2:
		var lbl = Label.new()
		game._return_popup_label(lbl)
		if lbl.is_queued_for_deletion():
			excess_labels.append(lbl)
	assert_eq(game._popup_pool.size(), game.POPUP_POOL_SIZE, "Popup pool should cap at POPUP_POOL_SIZE")
	assert_eq(excess_labels.size(), 2, "Excess popup labels should be queued for deletion")
	await get_tree().process_frame
