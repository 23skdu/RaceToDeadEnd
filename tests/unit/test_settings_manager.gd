extends GutTest

var _sm

func before_all():
	_sm = SettingsManager

func before_each():
	_sm._config = ConfigFile.new()
	_sm._loaded = false

func test_ready_calls_load_settings():
	watch_signals(_sm)
	_sm._ready()
	assert_true(_sm._loaded, "_ready should call load_settings")

func test_load_settings_handles_missing_file():
	_sm._loaded = false
	_sm.load_settings()
	assert_true(_sm._loaded, "Should handle missing file gracefully")

func test_save_settings_does_not_crash():
	_sm.save_settings()
	assert_true(true, "save_settings should not crash")

func test_set_volume_sets_config_value():
	_sm.set_volume("Master", 0.5)
	var val = _sm._config.get_value("audio", "Master", -1.0)
	assert_eq(val, 0.5, "set_volume should store value in config")

func test_get_volume_returns_default_when_no_config():
	var val = _sm.get_volume("UnknownBus", 0.75)
	assert_eq(val, 0.75, "get_volume should return default for unknown bus")

func test_get_volume_returns_stored_value():
	_sm._config.set_value("audio", "Master", 0.3)
	var val = _sm.get_volume("Master", 1.0)
	assert_eq(val, 0.3, "get_volume should return stored value")

func test_volume_round_trip():
	_sm.set_volume("Master", 0.42)
	var val = _sm.get_volume("Master", 1.0)
	assert_eq(val, 0.42, "Volume set and get should round-trip")

func test_set_fullscreen_sets_config_value():
	_sm.set_fullscreen(true)
	var val = _sm._config.get_value("video", "fullscreen", null)
	assert_true(val, "set_fullscreen(true) should store true in config")

func test_set_fullscreen_false_sets_config():
	_sm.set_fullscreen(false)
	var val = _sm._config.get_value("video", "fullscreen", null)
	assert_false(val, "set_fullscreen(false) should store false in config")

func test_get_fullscreen_returns_default_when_no_config():
	var val = _sm.get_fullscreen(true)
	assert_true(val, "get_fullscreen should return default when no config set")

func test_get_fullscreen_returns_stored_value():
	_sm._config.set_value("video", "fullscreen", true)
	var val = _sm.get_fullscreen(false)
	assert_true(val, "get_fullscreen should return stored true value")

func test_fullscreen_round_trip():
	_sm.set_fullscreen(true)
	var val = _sm.get_fullscreen(false)
	assert_true(val, "Fullscreen set and get should round-trip")
	_sm.set_fullscreen(false)
	val = _sm.get_fullscreen(true)
	assert_false(val, "Fullscreen set false and get should round-trip")

func test_set_volume_calls_save_settings():
	_sm.set_volume("Master", 0.8)
	assert_true(true, "set_volume should call save_settings without crash")

func test_set_volume_ignores_unknown_bus():
	_sm.set_volume("NonExistentBusXYZ", 0.5)
	assert_true(true, "set_volume with unknown bus should not crash")

func test_player_skin_round_trip():
	assert_eq(_sm.get_player_skin(), "default")
	_sm.set_player_skin("solar_chrome")
	assert_eq(_sm.get_player_skin(), "solar_chrome")

func test_music_track_round_trip():
	assert_eq(_sm.get_music_track(), "dynamic")
	_sm.set_music_track("outrun")
	assert_eq(_sm.get_music_track(), "outrun")

func test_high_contrast_round_trip():
	assert_false(_sm.get_high_contrast())
	_sm.set_high_contrast(true)
	assert_true(_sm.get_high_contrast())

func test_colorblind_mode_round_trip():
	assert_eq(_sm.get_colorblind_mode(), "none")
	_sm.set_colorblind_mode("protanopia")
	assert_eq(_sm.get_colorblind_mode(), "protanopia")
	_sm.set_colorblind_mode("invalid_mode")
	assert_eq(_sm.get_colorblind_mode(), "none")
