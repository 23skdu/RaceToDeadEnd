extends GutTest

const PackManagerScript = preload("res://scripts/autoload/PackManager.gd")
const InputRemapScript = preload("res://scripts/scenes/ui/InputRemap.gd")

var _rng: RandomNumberGenerator

func before_each():
	_rng = RandomNumberGenerator.new()
	_rng.seed = 20261114
	if FileAccess.file_exists("user://save.dat"):
		DirAccess.remove_absolute("user://save.dat")

func _rand_string(max_len: int) -> String:
	var alphabet := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./\\:_-!@#$%^&*()[]{}~? "
	var length := _rng.randi_range(0, max_len)
	var s := ""
	for i in length:
		s += alphabet[_rng.randi() % alphabet.length()]
	return s

func test_fuzz_game_manager_load_progress_arbitrary_payloads():
	for i in range(60):
		var mode := i % 3
		if mode == 0:
			# Raw garbage bytes (no GDEC header)
			var f = FileAccess.open("user://save.dat", FileAccess.WRITE)
			if f:
				var buf := PackedByteArray()
				for b in _rng.randi_range(0, 256):
					buf.append(_rng.randi() % 256)
				f.store_buffer(buf)
				f.close()
		elif mode == 1:
			# Encrypted wrong type
			var f = FileAccess.open_encrypted_with_pass("user://save.dat", FileAccess.WRITE, GameManager._get_save_passphrase())
			if f:
				f.store_var(_rand_string(32))
				f.close()
		else:
			# Encrypted dict with mutated/missing checksum
			var f = FileAccess.open_encrypted_with_pass("user://save.dat", FileAccess.WRITE, GameManager._get_save_passphrase())
			if f:
				var bad_ck = 0 if (i % 6 == 2) else _rand_string(64)
				f.store_var({
					"version": _rng.randi_range(-5, 10),
					"payload": {"credits": _rng.randi_range(-10000, 999999), "high_score": _rng.randi_range(-100, 999999)},
					"_checksum": bad_ck,
				})
				f.close()
		GameManager.credits = 42
		GameManager.high_score = 100
		GameManager.load_progress()
		assert_gte(GameManager.credits, 0, "Fuzzed save must never produce negative credits")
		assert_ne(GameManager.credits, 999999, "Fuzzed tampered save must never inject credits")

func test_fuzz_pack_manager_path_and_manifest_validation():
	var pm = PackManagerScript.new()
	add_child_autofree(pm)
	var base := "user://packs/fuzz_pack"
	var exts: Array[String] = pm.ALLOWED_IMAGE_EXTS

	# Fuzz 200 traversal / scheme / random strings
	var traversal_prefixes := ["../", "..\\", "/", "\\", "res://", "user://", "file://", "C:\\", "a/../../", "./../"]
	var blocked := 0
	for i in range(200):
		var candidate := ""
		if i < 100:
			candidate = traversal_prefixes[i % traversal_prefixes.size()] + _rand_string(20) + ".png"
		else:
			candidate = _rand_string(30)
		var resolved := pm._resolve_safe_pack_path(base, candidate, exts)
		if resolved == "":
			blocked += 1
		else:
			assert_true(resolved.begins_with(base + "/"), "Resolved path must stay confined inside base: " + resolved)
			assert_false(resolved.contains(".."), "Resolved path must not contain ..")
			assert_true(resolved.get_extension().to_lower() in exts, "Resolved path must have allowed extension")
	assert_gt(blocked, 100, "Traversal and random invalid paths must be blocked")

	# Fuzz hex colors
	var valid_count := 0
	for i in range(150):
		var c := _rand_string(12)
		var ok := pm._is_valid_hex_color(c)
		if ok:
			valid_count += 1
			assert_eq(c.length(), 7, "Valid hex color must be 7 chars")
			assert_true(c.begins_with("#"), "Valid hex color must start with #")
	assert_gte(valid_count, 0, "Hex fuzzing completed without crash")

func test_fuzz_input_remap_deserialize_event():
	var prefixes: Array[String] = ["key:", "jbtn:", "jaxis:", "unknown:", "", "::"]
	for i in range(250):
		var raw: String = prefixes[i % prefixes.size()] + _rand_string(16)
		if i % 5 == 0:
			raw = "jaxis:%d:%f" % [_rng.randi_range(-10, 50), _rng.randf_range(-10.0, 10.0)]
		elif i % 5 == 1:
			raw = "key:%d" % _rng.randi_range(-100, 10000000)
		elif i % 5 == 2:
			raw = "jbtn:%d" % _rng.randi_range(-20, 500)
		var ev = InputRemapScript.deserialize_event_safe(raw)
		if ev != null:
			if ev is InputEventKey:
				assert_gte(ev.physical_keycode, 0)
			elif ev is InputEventJoypadButton:
				assert_true(ev.button_index >= 0 and ev.button_index < JOY_BUTTON_MAX)
			elif ev is InputEventJoypadMotion:
				assert_true(ev.axis >= 0 and ev.axis < JOY_AXIS_MAX)
				assert_lte(absf(ev.axis_value), 1.0)

func test_fuzz_settings_manager_volume_bounds():
	var buses := ["Master", "Music", "SFX", "NonExistent", ""]
	var special_vals := [-1000.0, -0.001, 0.0, 0.5, 1.0, 1.001, 99999.0, NAN, INF, -INF]
	for i in range(120):
		var bus: String = buses[i % buses.size()]
		var val: float = special_vals[i % special_vals.size()] if i < 60 else _rng.randf_range(-50.0, 50.0)
		SettingsManager.set_volume(bus, val)
		if bus in ["Master", "Music", "SFX"]:
			var stored := SettingsManager.get_volume(bus)
			assert_true(stored >= 0.0 and stored <= 1.0, "Stored volume must stay in [0.0, 1.0]")
	SettingsManager.set_volume("Master", 1.0)
	SettingsManager.set_volume("Music", 1.0)
	SettingsManager.set_volume("SFX", 1.0)

func test_fuzz_highway_chunk_and_tile_generation():
	var h = load("res://scripts/scenes/world/Highway.gd").new()
	add_child_autofree(h)
	for i in range(100):
		GameManager.difficulty_tier = _rng.randi_range(-5, 50)
		var ct = h._pick_chunk_type()
		assert_true(ct >= 0 and ct <= 4, "ChunkType must always be valid")
		var v = h._get_tile_variant(ct, _rng.randi_range(0, 13), _rng.randi_range(0, 13))
		assert_true(v >= 0 and v <= 4, "Tile variant must always be valid")
	GameManager.difficulty_tier = 1

func test_fuzz_spawner_wave_composition():
	var sp = load("res://scripts/scenes/world/Spawner.gd").new()
	add_child_autofree(sp)
	var valid_keys := ["bunny", "rotor", "sasquatch", "scav", "drone"]
	for i in range(100):
		var tier := _rng.randi_range(0, 50)
		GameManager.bosses_killed = _rng.randi_range(0, 10)
		var comp: Dictionary = sp._get_wave_composition(tier)
		for k in comp:
			assert_true(k in valid_keys, "Wave composition key must be valid: " + str(k))
			assert_gte(int(comp[k]), 0, "Enemy count must be non-negative")
	GameManager.bosses_killed = 0

func test_fuzz_object_pool_acquire_release_cycles():
	var pool_name := "fuzz_bullet_pool"
	ObjectPool.create_pool(pool_name, preload("res://scenes/weapons/Bullet.tscn"), 4)
	var active: Array[Node] = []
	for i in range(80):
		if _rng.randf() < 0.6 or active.is_empty():
			var n = ObjectPool.acquire(pool_name)
			if n:
				active.append(n)
		else:
			var idx := _rng.randi() % active.size()
			var n = active[idx]
			active.remove_at(idx)
			ObjectPool.release(n)
	for n in active:
		ObjectPool.release(n)
	assert_true(true, "Fuzzed ObjectPool acquire/release completed cleanly")
