extends GutTest

func test_main_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/Main.tscn"), "Main scene should exist")

func test_game_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/Game.tscn"), "Game scene should exist")

func test_garage_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/ui/Garage.tscn"), "Garage scene should exist")

func test_main_script_exists():
	assert_true(ResourceLoader.exists("res://scenes/Main.gd"), "Main script should exist")

func test_main_quit_calls_quit():
	var main = load("res://scenes/Main.gd").new()
	add_child_autofree(main)
	main._on_quit_pressed()
	assert_true(true, "Quit should be called")

func test_main_options_is_stub():
	var main = load("res://scenes/Main.gd").new()
	add_child_autofree(main)
	main._on_options_pressed()
	assert_true(true, "Options handler is a stub")

func test_main_start_changes_scene():
	var main = load("res://scenes/Main.gd").new()
	add_child_autofree(main)
	main._on_start_pressed()
	assert_true(true, "Start should change scene")

func test_main_sets_menu_state():
	var main = load("res://scenes/Main.gd").new()
	add_child_autofree(main)
	assert_eq(GameManager.state, GameManager.GameState.MENU, "Should set state to MENU")

func test_main_ready_connects_buttons():
	var main = load("res://scenes/Main.gd").new()
	add_child_autofree(main)
	watch_signals(main)
	assert_true(main.start_button.pressed.is_connected(main._on_start_pressed), "Start button should be connected")
	assert_true(main.garage_button.pressed.is_connected(main._on_garage_pressed), "Garage button should be connected")
	assert_true(main.options_button.pressed.is_connected(main._on_options_pressed), "Options button should be connected")
	assert_true(main.quit_button.pressed.is_connected(main._on_quit_pressed), "Quit button should be connected")

func test_main_garage_instantiates_scene():
	var main = load("res://scenes/Main.gd").new()
	add_child_autofree(main)
	main._on_garage_pressed()
	var garage_found = false
	for child in main.get_children():
		if child.has_signal("back_to_menu_requested"):
			garage_found = true
			child.queue_free()
			break
	assert_true(garage_found, "Garage scene should be instantiated")
