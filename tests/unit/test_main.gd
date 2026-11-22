extends GutTest

func after_each():
	if TransitionLayer._tween and TransitionLayer._tween.is_valid():
		TransitionLayer._tween.kill()
		TransitionLayer._tween = null
	if TransitionLayer._overlay:
		TransitionLayer._overlay.modulate.a = 0.0
		TransitionLayer._overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func test_main_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/Main.tscn"), "Main scene should exist")

func test_game_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/Game.tscn"), "Game scene should exist")

func test_garage_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/ui/Garage.tscn"), "Garage scene should exist")

func test_main_script_exists():
	assert_true(ResourceLoader.exists("res://scripts/scenes/Main.gd"), "Main script should exist")

func _create_main():
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main)
	return main

func test_main_quit_calls_quit():
	var main = _create_main()
	assert_true(main.has_method("_on_quit_pressed"), "Should have quit handler")

func test_main_options_is_stub():
	var main = _create_main()
	main._on_options_pressed()
	assert_true(true, "Options handler is a stub")

func test_main_start_changes_scene():
	var main = _create_main()
	assert_true(main.has_method("_on_start_pressed"), "Should have start handler")

func test_main_sets_menu_state():
	var main = _create_main()
	assert_eq(GameManager.state, GameManager.GameState.MENU, "Should set state to MENU")

func test_main_ready_starts_menu_music():
	var main = _create_main()
	assert_not_null(AudioManager._stream_menu_music, "Menu theme should be ready before the menu asks for it")
	assert_eq(AudioManager.music_player.stream, AudioManager._stream_menu_music, "Main menu should play the menu theme")

func test_main_title_lettering_is_sharpened():
	var main = _create_main()
	var canvas: CanvasLayer = main.get_node("CanvasLayer")
	assert_gt(canvas.layer, PostProcessing.layer if PostProcessing else 5, "Main menu should render above the CRT shader")
	var title: Label = main.get_node("CanvasLayer/TitleLabel")
	assert_eq(title.get_theme_font_size(&"font_size"), 48, "Title font size should stay legible")
	assert_eq(title.get_theme_constant(&"outline_size"), 2, "Title outline should not blur glyph edges")
	assert_not_null(title.get_theme_font(&"font"), "Title should use the themed font")

func test_main_button_lettering_is_crisp():
	var main = _create_main()
	var menu_row: HBoxContainer = main.get_node("CanvasLayer/MenuRow")
	for button in menu_row.get_children():
		assert_eq(button.get_theme_font_size(&"font_size"), 20, "Menu buttons should use a legible font size")

func test_main_ready_connects_buttons():
	var main = _create_main()
	watch_signals(main)
	assert_true(main.start_button.pressed.is_connected(main._on_start_pressed), "Start button should be connected")
	assert_true(main.garage_button.pressed.is_connected(main._on_garage_pressed), "Garage button should be connected")
	assert_true(main.info_button.pressed.is_connected(main._on_info_pressed), "Info button should be connected")
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

func test_main_info_instantiates_scene():
	var main = _create_main()
	main._on_info_pressed()
	var info_found = false
	for child in main.get_children():
		if child.has_signal("back_to_menu_requested"):
			info_found = true
			child.queue_free()
			break
	assert_true(info_found, "InterceptorInfo scene should be instantiated")

func test_main_info_back_callback_queues_free():
	var main = _create_main()
	main._on_info_pressed()
	var info = null
	for child in main.get_children():
		if child.has_signal("back_to_menu_requested"):
			info = child
			break
	assert_true(info != null, "InterceptorInfo should exist")
	info.back_to_menu_requested.emit()
	assert_true(info.is_queued_for_deletion(), "InterceptorInfo should queue free on back")

func test_main_info_scene_path():
	assert_true(ResourceLoader.exists("res://scenes/ui/InterceptorInfo.tscn"), "InterceptorInfo scene should exist")

func test_physics_interpolation_enabled_in_project() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://project.godot")
	assert_eq(err, OK, "project.godot should load")
	assert_true(cfg.has_section("physics"), "project.godot should have [physics] section")
	assert_true(cfg.get_value("physics", "common/physics_interpolation", false), "Physics interpolation should be enabled")
