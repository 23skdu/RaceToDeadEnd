extends GutTest

# SettingsManager.gd shared roadmap settings API (feature toggles and generic
# persisted values). All roadmap points rely on these helpers.

var _sm

func before_each():
	_sm = SettingsManager
	_sm._config = ConfigFile.new()
	_sm._loaded = false

func test_feature_toggle_defaults_to_true():
	assert_true(_sm.is_feature_enabled("gpu_effects", true))
	assert_false(_sm.is_feature_enabled("", false))

func test_feature_toggle_round_trip():
	_sm.set_feature_enabled("adaptive_music", false)
	assert_false(_sm.is_feature_enabled("adaptive_music", true))
	assert_eq(_sm._config.get_value("features", "adaptive_music", null), false)

func test_feature_toggle_emits_signal():
	watch_signals(_sm)
	_sm.set_feature_enabled("rich_hud", true)
	assert_signal_emitted_with_parameters(_sm, "feature_toggle_changed", ["rich_hud", true])

func test_feature_toggle_ignores_empty_key():
	_sm.set_feature_enabled("", true)
	assert_false(_sm._config.has_section("features"))

func test_roadmap_value_round_trip():
	_sm.set_roadmap_value("resolution", "2560x1440")
	assert_eq(_sm.get_roadmap_value("resolution", "1280x720"), "2560x1440")

func test_roadmap_value_defaults():
	assert_eq(_sm.get_roadmap_value("missing", 42), 42)
	assert_eq(_sm.get_roadmap_value("", "fallback"), "fallback")

func test_roadmap_set_ignores_empty_key():
	_sm.set_roadmap_value("", 1)
	assert_false(_sm._config.has_section("roadmap"))
