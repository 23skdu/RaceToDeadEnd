extends GutTest

func test_settings_manager_loads_without_crash():
	assert_not_null(SettingsManager, "SettingsManager should be loaded")

func test_settings_manager_set_and_get_volume():
	var test_val = 0.5
	SettingsManager.set_volume("Master", test_val)
	var loaded = SettingsManager.get_volume("Master", 1.0)
	assert_eq(loaded, test_val, "Volume should be saved and retrieved")

func test_settings_manager_get_volume_default():
	var val = SettingsManager.get_volume("NonExistentBus", 0.75)
	assert_eq(val, 0.75, "Unknown bus should return default")

func test_settings_manager_get_fullscreen_default():
	var fs = SettingsManager.get_fullscreen()
	assert_false(fs, "Default fullscreen should be false")
