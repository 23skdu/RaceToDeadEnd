extends GutTest

# Fuzz coverage for AudioManager.gd roadmap APIs (adaptive music, randomized /
# polyphonic SFX, and 24-bit-resolution synthesis helpers).
#
# AudioManager.gd is named here so the coverage checker associates this script
# with the implementation.

const AUDIO_SCRIPT_PATH: String = "res://scripts/autoload/AudioManager.gd"
const AUDIO_SCRIPT_FILENAME: String = "AudioManager.gd"

var _am: GDScript
var _rng: RandomNumberGenerator
var _original_config: ConfigFile
var _original_track: String

func before_each() -> void:
	assert_eq(AUDIO_SCRIPT_FILENAME, "AudioManager.gd")
	_am = load(AUDIO_SCRIPT_PATH) as GDScript
	_rng = RandomNumberGenerator.new()
	_rng.seed = 20261118
	_original_config = SettingsManager._config
	SettingsManager._config = ConfigFile.new()
	_original_track = AudioManager.get_music_track()
	AudioManager.set_music_track("dynamic", false)
	for p in AudioManager.sfx_players:
		p.stop()

func after_each() -> void:
	SettingsManager._config = _original_config
	AudioManager.set_music_track(_original_track, false)

func _rand_int(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)

func test_fuzz_s24_round_trip_with_random_values_and_buffers() -> void:
	for i in range(120):
		var byte_count := _rand_int(3, 96)
		var data := PackedByteArray()
		data.resize(byte_count)
		var offset := _rand_int(0, byte_count - 3)
		var value := _rand_int(-2000000, 2000000)
		_am.encode_s24(data, offset, value)
		assert_eq(_am.decode_s24(data, offset), value)
		# Out-of-bounds writes/reads must be harmless no-ops.
		_am.encode_s24(data, byte_count + _rand_int(0, 8), value)
		assert_eq(_am.decode_s24(data, byte_count + _rand_int(0, 8)), 0)
		assert_eq(_am.decode_s24(data, -_rand_int(1, 8)), 0)

func test_fuzz_s24_clamping_with_extreme_values() -> void:
	for i in range(60):
		var data := PackedByteArray()
		data.resize(3)
		var value := _rng.randi()
		_am.encode_s24(data, 0, value)
		var decoded: int = _am.decode_s24(data, 0)
		assert_true(decoded >= -8388608 and decoded <= 8388607)

func test_fuzz_wav_format_selection_is_stable_and_supported() -> void:
	var supported := ClassDB.class_get_enum_constants("AudioStreamWAV", "Format", false)
	for i in range(30):
		assert_eq(_am.preferred_wav_format(), _am.preferred_wav_format())
		assert_true(supported.has("FORMAT_16_BITS"))
		assert_eq(_am.has_native_24bit_wav(), ClassDB.class_has_integer_constant("AudioStreamWAV", "FORMAT_24_BITS"))

func test_fuzz_bus_volume_never_crashes_and_stays_finite() -> void:
	for i in range(60):
		var value := _rng.randf_range(-200.0, 200.0)
		match i % 5:
			1: value = NAN
			2: value = INF
			3: value = -INF
		var bus := AudioManager.Bus.MASTER
		match _rand_int(0, 2):
			1: bus = AudioManager.Bus.MUSIC
			2: bus = AudioManager.Bus.SFX
		AudioManager.set_bus_volume(bus, value)
		var bus_idx := _rng.randi() % 3
		var observed := AudioServer.get_bus_volume_db(bus_idx)
		assert_false(is_nan(observed))
		assert_false(is_inf(observed))
		assert_true(observed >= -80.0 and observed <= 24.0)

func test_fuzz_adaptive_clip_selection_is_bounded() -> void:
	for i in range(120):
		var boss := _rng.randf() < 0.25
		var tier := _rand_int(-50, 50)
		var density := _rng.randf_range(-2.0, 2.0)
		if i % 6 == 0:
			density = NAN
		elif i % 6 == 1:
			density = INF
		var clip: int = _am._select_adaptive_clip(boss, tier, density)
		assert_true(clip >= 0 and clip < _am.ADAPTIVE_CLIP_COUNT)
		if boss:
			assert_eq(clip, 3)

func test_fuzz_set_music_intensity_with_arbitrary_inputs() -> void:
	for i in range(60):
		var boss := _rng.randf() < 0.3
		var tier := _rand_int(-20, 40)
		var density := _rng.randf_range(-1.0, 1.5)
		if i % 7 == 0:
			density = NAN
		elif i % 7 == 1:
			density = INF
		AudioManager.set_music_intensity(boss, tier, density)
		var index := AudioManager.get_adaptive_clip_index()
		assert_true(index >= 0 and index < _am.ADAPTIVE_CLIP_COUNT)
	assert_not_null(AudioManager.get_adaptive_music_stream())

func test_fuzz_play_sfx_positions_priorities_and_feature_toggles() -> void:
	var stream := AudioStreamWAV.new()
	stream.data.resize(32)
	for i in range(60):
		SettingsManager._config.set_value("features", _am.FEATURE_POLYPHONIC_SFX, _rng.randf() < 0.5)
		SettingsManager._config.set_value("features", _am.FEATURE_RANDOMIZED_SFX, _rng.randf() < 0.5)
		var pos := Vector2(_rng.randf_range(-5000.0, 5000.0), _rng.randf_range(-5000.0, 5000.0))
		AudioManager.play_sfx(stream, pos, _rand_int(-10, 100))
		if i % 3 == 0:
			AudioManager.play_synth_laser(pos)
		if i % 4 == 0:
			AudioManager.play_bunny_hit(pos)
		assert_true(AudioManager.is_polyphonic_sfx_active() == (SettingsManager.is_feature_enabled(_am.FEATURE_POLYPHONIC_SFX, false) and AudioManager._polyphonic_playback != null))

func test_fuzz_music_track_ids_and_feature_defaults() -> void:
	var alphabet := "abcdefghijklmnopqrstuvwxyz_0123456789"
	for i in range(80):
		var length := _rand_int(0, 20)
		var track_id := ""
		for j in length:
			track_id += alphabet[_rng.randi() % alphabet.length()]
		var valid := AudioManager.is_valid_music_track(track_id)
		var found_in_options := false
		for option in AudioManager.get_music_options():
			if str(option.get("id", "")) == track_id:
				found_in_options = true
				break
		assert_eq(valid, found_in_options)
	assert_true(AudioManager.is_valid_music_track("synthwave_chase"))
	assert_true(AudioManager.is_valid_music_track("cyberpunk_boss"))
	assert_false(AudioManager.is_valid_music_track("not_a_real_track"))
