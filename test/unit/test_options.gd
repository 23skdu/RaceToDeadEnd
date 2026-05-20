extends GutTest

func test_options_scene_exists():
	assert_true(ResourceLoader.exists("res://scenes/ui/Options.tscn"), "Options scene should exist")

func test_options_script_exists():
	assert_true(ResourceLoader.exists("res://scenes/ui/Options.gd"), "Options script should exist")

func test_options_has_back_signal():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	assert_true(options.has_signal("back_to_menu_requested"), "Should have back_to_menu_requested signal")

func test_options_back_emits_signal():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	watch_signals(options)
	options._on_back_pressed()
	assert_signal_emitted(options, "back_to_menu_requested", "Should emit back signal")

func test_options_master_volume_handler_exists():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	assert_true(options.has_method("_on_master_changed"), "Should have master volume handler")

func test_options_music_volume_handler_exists():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	assert_true(options.has_method("_on_music_changed"), "Should have music volume handler")

func test_options_sfx_volume_handler_exists():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	assert_true(options.has_method("_on_sfx_changed"), "Should have sfx volume handler")

func test_options_fullscreen_handler_exists():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	assert_true(options.has_method("_on_fullscreen_toggled"), "Should have fullscreen handler")

func test_options_fullscreen_toggle_sets_mode():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	options._on_fullscreen_toggled(true)
	var mode = DisplayServer.window_get_mode()
	assert_true(mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_MAXIMIZED, "Should change window mode")

func test_options_volume_handlers_call_audio_server():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	var before = AudioServer.get_bus_volume_db(0)
	options._on_master_changed(0.0)
	var after = AudioServer.get_bus_volume_db(0)
	assert_true(after <= before, "Master handler should affect bus volume")

func test_options_linear_to_db_conversion():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	options._on_master_changed(1.0)
	assert_eq(AudioServer.get_bus_volume_db(0), 0.0, "Full slider should be 0dB")

func test_options_zero_slider_very_low():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	options._on_master_changed(0.0)
	assert_lt(AudioServer.get_bus_volume_db(0), -70.0, "Zero slider should be very low dB")
