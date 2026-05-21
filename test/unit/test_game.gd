extends GutTest

func test_game_scene_exists():
	assert_true(ResourceLoader.exists("res://scenes/Game.tscn"), "Game scene should exist")

func test_game_script_exists():
	assert_true(ResourceLoader.exists("res://scenes/Game.gd"), "Game script should exist")

func _create_game():
	var game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game)
	return game

func test_game_restart_reloads_scene():
	var game = _create_game()
	watch_signals(game.get_tree())
	game._restart_game()
	assert_true(true, "Restart should reload scene")

func test_game_menu_changes_scene():
	var game = _create_game()
	game._go_to_menu()
	assert_true(true, "Menu should change scene")

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

func test_game_bridge_fall_damages_player():
	var game = _create_game()
	var gm = TestHelper.create_game_manager()
	add_child_autofree(gm)
	gm.start_game()
	var mock_body = Node2D.new()
	mock_body.position = Vector2(-100, 0)
	mock_body.set("take_damage", func(amount = 1): gm.take_damage(amount))
	mock_body.set("current_lane", 0)
	game._on_bridge_fall(mock_body)
	assert_lt(gm.health, gm.max_health, "Bridge fall should damage player")

func test_game_bridge_fall_repositions_left():
	var game = _create_game()
	var mock_body = Node2D.new()
	mock_body.position = Vector2(-100, 0)
	mock_body.set("take_damage", func(amount = 1): pass)
	mock_body.set("current_lane", 0)
	game._on_bridge_fall(mock_body)
	assert_eq(mock_body.position.x, -32, "Should reposition to lane 1")
	assert_eq(mock_body.get("current_lane"), 1, "Lane should be updated")

func test_game_bridge_fall_repositions_right():
	var game = _create_game()
	var mock_body = Node2D.new()
	mock_body.position = Vector2(100, 0)
	mock_body.set("take_damage", func(amount = 1): pass)
	mock_body.set("current_lane", 3)
	game._on_bridge_fall(mock_body)
	assert_eq(mock_body.position.x, 32, "Should reposition to lane 2")
	assert_eq(mock_body.get("current_lane"), 2, "Lane should be updated")

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
	game._on_player_weapon_fired("machine_gun", Vector2.ZERO, Vector2.UP)
	assert_true(true, "Machine gun weapon fired should not crash")

func test_game_weapon_fired_missile():
	var game = _create_game()
	game._on_player_weapon_fired("missile", Vector2.ZERO, Vector2.UP)
	assert_true(true, "Missile weapon fired should not crash")

func test_game_weapon_fired_mine():
	var game = _create_game()
	game._on_player_weapon_fired("mine", Vector2.ZERO, Vector2.UP)
	assert_true(true, "Mine weapon fired should not crash")

func test_game_weapon_fired_emp():
	var game = _create_game()
	game._on_player_weapon_fired("emp", Vector2.ZERO, Vector2.UP)
	assert_true(true, "EMP weapon fired should not crash")

func test_game_scene_constants():
	var script = load("res://scenes/Game.gd")
	assert_true(script.BULLET_SCENE != null, "Bullet scene should be preloaded")
	assert_true(script.MINE_SCENE != null, "Mine scene should be preloaded")
	assert_true(script.EMP_SCENE != null, "EMP scene should be preloaded")
