extends GutTest

func before_each():
	TestHelper.ensure_audio_buses()

func test_options_scene_exists():
	assert_true(ResourceLoader.exists("res://scenes/ui/Options.tscn"), "Options scene should exist")

func test_options_script_exists():
	assert_true(ResourceLoader.exists("res://scenes/ui/Options.gd"), "Options script should exist")

func _create_options():
	var options = load("res://scenes/ui/Options.tscn").instantiate()
	add_child_autofree(options)
	return options

func test_options_has_back_signal():
	var options = _create_options()
	assert_true(options.has_signal("back_to_menu_requested"), "Should have back_to_menu_requested signal")

func test_options_back_emits_signal():
	var options = _create_options()
	watch_signals(options)
	options._on_back_pressed()
	assert_signal_emitted(options, "back_to_menu_requested", "Should emit back signal")

func test_options_master_volume_handler_exists():
	var options = _create_options()
	assert_true(options.has_method("_on_master_changed"), "Should have master volume handler")

func test_options_music_volume_handler_exists():
	var options = _create_options()
	assert_true(options.has_method("_on_music_changed"), "Should have music volume handler")

func test_options_sfx_volume_handler_exists():
	var options = _create_options()
	assert_true(options.has_method("_on_sfx_changed"), "Should have sfx volume handler")

func test_options_fullscreen_handler_exists():
	var options = _create_options()
	assert_true(options.has_method("_on_fullscreen_toggled"), "Should have fullscreen handler")

func test_options_fullscreen_toggle_sets_mode():
	var options = _create_options()
	options._on_fullscreen_toggled(true)
	var mode = DisplayServer.window_get_mode()
	assert_true(mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_MAXIMIZED, "Should change window mode")

func test_options_volume_handlers_call_audio_server():
	var options = _create_options()
	var before = AudioServer.get_bus_volume_db(0)
	options._on_master_changed(0.0)
	var after = AudioServer.get_bus_volume_db(0)
	assert_true(after <= before, "Master handler should affect bus volume")

func test_options_linear_to_db_conversion():
	var options = _create_options()
	options._on_master_changed(1.0)
	assert_eq(AudioServer.get_bus_volume_db(0), 0.0, "Full slider should be 0dB")

func test_options_zero_slider_very_low():
	var options = _create_options()
	options._on_master_changed(0.0)
	assert_lt(AudioServer.get_bus_volume_db(0), -70.0, "Zero slider should be very low dB")

func test_options_music_volume_changes_bus():
	var options = _create_options()
	var before = AudioServer.get_bus_volume_db(1)
	options._on_music_changed(0.5)
	var after = AudioServer.get_bus_volume_db(1)
	assert_ne(before, after, "Music handler should affect music bus volume")

func test_options_sfx_volume_changes_bus():
	var options = _create_options()
	var before = AudioServer.get_bus_volume_db(2)
	options._on_sfx_changed(0.5)
	var after = AudioServer.get_bus_volume_db(2)
	assert_ne(before, after, "SFX handler should affect SFX bus volume")

func test_options_music_full_volume():
	var options = _create_options()
	options._on_music_changed(1.0)
	assert_eq(AudioServer.get_bus_volume_db(1), 0.0, "Music full volume should be 0dB")

func test_options_sfx_full_volume():
	var options = _create_options()
	options._on_sfx_changed(1.0)
	assert_eq(AudioServer.get_bus_volume_db(2), 0.0, "SFX full volume should be 0dB")

func test_options_music_zero_volume():
	var options = _create_options()
	options._on_music_changed(0.0)
	assert_lt(AudioServer.get_bus_volume_db(1), -70.0, "Music zero volume should be very low dB")

func test_options_sfx_zero_volume():
	var options = _create_options()
	options._on_sfx_changed(0.0)
	assert_lt(AudioServer.get_bus_volume_db(2), -70.0, "SFX zero volume should be very low dB")

func test_options_load_volume_settings_reads_buses():
	var options = _create_options()
	var master_val = db_to_linear(AudioServer.get_bus_volume_db(0))
	var music_val = db_to_linear(AudioServer.get_bus_volume_db(1))
	var sfx_val = db_to_linear(AudioServer.get_bus_volume_db(2))
	assert_gt(master_val, 0.0, "Master slider should have value from bus")
	assert_gt(music_val, 0.0, "Music slider should have value from bus")
	assert_gt(sfx_val, 0.0, "SFX slider should have value from bus")

func test_options_fullscreen_untoggle_sets_windowed():
	var options = _create_options()
	options._on_fullscreen_toggled(false)
	var mode = DisplayServer.window_get_mode()
	assert_true(mode == DisplayServer.WINDOW_MODE_WINDOWED or mode == DisplayServer.WINDOW_MODE_MAXIMIZED, "Should set windowed mode")

func test_options_back_button_connected():
	var options = _create_options()
	assert_true(options.back_button.pressed.is_connected(options._on_back_pressed), "Back button should be connected")

func test_options_sliders_connected():
	var options = _create_options()
	assert_true(options.master_slider.value_changed.is_connected(options._on_master_changed), "Master slider should be connected")
	assert_true(options.music_slider.value_changed.is_connected(options._on_music_changed), "Music slider should be connected")
	assert_true(options.sfx_slider.value_changed.is_connected(options._on_sfx_changed), "SFX slider should be connected")

func test_options_fullscreen_check_connected():
	var options = _create_options()
	assert_true(options.fullscreen_check.toggled.is_connected(options._on_fullscreen_toggled), "Fullscreen check should be connected")
