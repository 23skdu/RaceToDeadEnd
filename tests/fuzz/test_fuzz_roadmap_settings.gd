extends GutTest

# Fuzz coverage for SettingsManager.gd roadmap settings API.

var _rng: RandomNumberGenerator

func before_each():
	_rng = RandomNumberGenerator.new()
	_rng.seed = 20261118
	SettingsManager._config = ConfigFile.new()

func _rand_key() -> String:
	var alphabet := "abcdefghijklmnopqrstuvwxyz_0123456789"
	var length := _rng.randi_range(0, 24)
	var s := ""
	for i in length:
		s += alphabet[_rng.randi() % alphabet.length()]
	return s

func test_fuzz_feature_toggle_arbitrary_keys():
	for i in range(80):
		var key := _rand_key()
		var default := _rng.randf() < 0.5
		var value := _rng.randf() < 0.5
		SettingsManager.set_feature_enabled(key, value)
		var observed := SettingsManager.is_feature_enabled(key, default)
		if key.is_empty():
			assert_eq(observed, default)
		else:
			assert_eq(observed, value)

func test_fuzz_roadmap_values_arbitrary_keys_and_types():
	for i in range(80):
		var key := _rand_key()
		var kind := i % 4
		var value: Variant
		match kind:
			0: value = _rng.randi_range(-1000, 1000)
			1: value = _rng.randf_range(-100.0, 100.0)
			2: value = _rand_key()
			3: value = _rng.randf() < 0.5
		var fallback: Variant = "fallback"
		SettingsManager.set_roadmap_value(key, value)
		if key.is_empty():
			assert_eq(SettingsManager.get_roadmap_value(key, fallback), fallback)
		else:
			var observed = SettingsManager.get_roadmap_value(key, fallback)
			assert_eq(typeof(observed), typeof(value))
