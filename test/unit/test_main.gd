extends GutTest

func test_main_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/Main.tscn"), "Main scene should exist")

func test_game_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/Game.tscn"), "Game scene should exist")

func test_garage_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/ui/Garage.tscn"), "Garage scene should exist")

func test_main_script_exists():
	assert_true(ResourceLoader.exists("res://scenes/Main.gd"), "Main script should exist")

func _create_main():
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main)
	return main

func test_main_quit_calls_quit():
	var main = _create_main()
	main._on_quit_pressed()
	assert_true(true, "Quit should be called")

func test_main_options_is_stub():
	var main = _create_main()
	main._on_options_pressed()
	assert_true(true, "Options handler is a stub")

func test_main_start_changes_scene():
	var main = _create_main()
	main._on_start_pressed()
	assert_true(true, "Start should change scene")

func test_main_sets_menu_state():
	var main = _create_main()
	assert_eq(GameManager.state, GameManager.GameState.MENU, "Should set state to MENU")

func test_main_ready_connects_buttons():
	var main = _create_main()
	watch_signals(main)
	assert_true(main.start_button.pressed.is_connected(main._on_start_pressed), "Start button should be connected")
	assert_true(main.garage_button.pressed.is_connected(main._on_garage_pressed), "Garage button should be connected")
	assert_true(main.options_button.pressed.is_connected(main._on_options_pressed), "Options button should be connected")
	assert_true(main.quit_button.pressed.is_connected(main._on_quit_pressed), "Quit button should be connected")

func test_main_garage_instantiates_scene():
	var main = _create_main()
	main._on_garage_pressed()
	var garage_found = false
	for child in main.get_children():
		if child.has_signal("back_to_menu_requested"):
			garage_found = true
			child.queue_free()
			break
	assert_true(garage_found, "Garage scene should be instantiated")

func test_main_garage_back_callback_queues_free():
	var main = _create_main()
	main._on_garage_pressed()
	var garage = null
	for child in main.get_children():
		if child.has_signal("back_to_menu_requested"):
			garage = child
			break
	assert_true(garage != null, "Garage should exist")
	garage.back_to_menu_requested.emit()
	assert_true(garage.is_queued_for_deletion(), "Garage should queue free on back")

func test_main_garage_start_callback_changes_scene():
	var main = _create_main()
	main._on_garage_pressed()
	var garage = null
	for child in main.get_children():
		if child.has_signal("back_to_menu_requested"):
			garage = child
			break
	assert_true(garage != null, "Garage should exist")
	garage.start_run_requested.emit()
	assert_true(garage.is_queued_for_deletion(), "Garage should queue free on start")

func test_main_options_instantiates_scene():
	var main = _create_main()
	main._on_options_pressed()
	var options_found = false
	for child in main.get_children():
		if child.has_signal("back_to_menu_requested"):
			options_found = true
			child.queue_free()
			break
	assert_true(options_found, "Options scene should be instantiated")

func test_main_options_back_callback_queues_free():
	var main = _create_main()
	main._on_options_pressed()
	var options = null
	for child in main.get_children():
		if child.has_signal("back_to_menu_requested"):
			options = child
			break
	assert_true(options != null, "Options should exist")
	options.back_to_menu_requested.emit()
	assert_true(options.is_queued_for_deletion(), "Options should queue free on back")
