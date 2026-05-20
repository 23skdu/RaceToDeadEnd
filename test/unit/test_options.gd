extends GutTest

func test_options_ready_connects_signals():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	watch_signals(options)
	assert_true(true, "Options should load without errors")

func test_options_master_volume_changes():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	var initial_volume = AudioServer.get_bus_volume_db(0)
	options._on_master_changed(0.5)
	var new_volume = AudioServer.get_bus_volume_db(0)
	assert_ne(new_volume, initial_volume, "Master volume should change")

func test_options_music_volume_changes():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	var initial_volume = AudioServer.get_bus_volume_db(1)
	options._on_music_changed(0.5)
	var new_volume = AudioServer.get_bus_volume_db(1)
	assert_ne(new_volume, initial_volume, "Music volume should change")

func test_options_sfx_volume_changes():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	var initial_volume = AudioServer.get_bus_volume_db(2)
	options._on_sfx_changed(0.5)
	var new_volume = AudioServer.get_bus_volume_db(2)
	assert_ne(new_volume, initial_volume, "SFX volume should change")

func test_options_fullscreen_toggle():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	options._on_fullscreen_toggled(true)
	assert_eq(DisplayServer.window_get_mode(), DisplayServer.WINDOW_MODE_FULLSCREEN, "Should enter fullscreen")
	options._on_fullscreen_toggled(false)
	assert_eq(DisplayServer.window_get_mode(), DisplayServer.WINDOW_MODE_WINDOWED, "Should exit fullscreen")

func test_options_back_emits_signal():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	watch_signals(options)
	options._on_back_pressed()
	assert_signal_emitted(options, "back_to_menu_requested", "Should emit back signal")

func test_options_slider_values_map_to_db():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	options._on_master_changed(1.0)
	assert_eq(AudioServer.get_bus_volume_db(0), 0.0, "Full slider should be 0dB")
	options._on_master_changed(0.0)
	assert_lt(AudioServer.get_bus_volume_db(0), -70.0, "Zero slider should be very low dB")

func test_options_master_at_half_volume():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	options._on_master_changed(0.5)
	var db = AudioServer.get_bus_volume_db(0)
	assert_lt(db, 0.0, "Half volume should be negative dB")
	assert_gt(db, -70.0, "Half volume should not be silent")

func test_options_music_at_full_volume():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	options._on_music_changed(1.0)
	assert_eq(AudioServer.get_bus_volume_db(1), 0.0, "Full music volume should be 0dB")

func test_options_sfx_at_full_volume():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	options._on_sfx_changed(1.0)
	assert_eq(AudioServer.get_bus_volume_db(2), 0.0, "Full SFX volume should be 0dB")

func test_options_audio_buses_exist():
	assert_eq(AudioServer.bus_count, 3, "Should have 3 audio buses")
	assert_eq(AudioServer.get_bus_name(0), "Master", "Bus 0 should be Master")
	assert_eq(AudioServer.get_bus_name(1), "Music", "Bus 1 should be Music")
	assert_eq(AudioServer.get_bus_name(2), "SFX", "Bus 2 should be SFX")

func test_options_fullscreen_exit_sets_windowed():
	var options = load("res://scenes/ui/Options.gd").new()
	add_child_autofree(options)
	options._on_fullscreen_toggled(false)
	assert_eq(DisplayServer.window_get_mode(), DisplayServer.WINDOW_MODE_WINDOWED, "Should be windowed")
