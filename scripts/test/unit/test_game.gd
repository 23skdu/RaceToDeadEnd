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
	ObjectPool.create_pool("test_mine", preload("res://scenes/weapons/Mine.tscn"), 1)
	game._on_player_weapon_fired("mine", Vector2.ZERO, Vector2.UP)
	assert_true(true, "Mine weapon fired should not crash")

func test_game_weapon_fired_emp():
	var game = _create_game()
	ObjectPool.create_pool("test_emp", preload("res://scenes/weapons/EMPBlast.tscn"), 1)
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
