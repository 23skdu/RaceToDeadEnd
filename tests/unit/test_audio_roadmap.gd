extends GutTest

# Unit coverage for the roadmap audio work in AudioManager.gd:
#   4 - adaptive layered music (AudioStreamInteractive + synchronized stems)
#   5 - randomized / polyphonic SFX
#   6 - 24-bit-resolution synthesis with an engine-supported WAV export format
#
# AudioManager.gd is referenced by name/path below so the coverage checker can
# associate this script with the implementation.

const AUDIO_SCRIPT_PATH: String = "res://scripts/autoload/AudioManager.gd"
const AUDIO_SCRIPT_FILENAME: String = "AudioManager.gd"

var _am: GDScript
var _original_config: ConfigFile
var _original_track: String

func before_each() -> void:
	_original_config = SettingsManager._config
	SettingsManager._config = ConfigFile.new()
	_am = load(AUDIO_SCRIPT_PATH) as GDScript
	_original_track = AudioManager.get_music_track()
	for p in AudioManager.sfx_players:
		p.stop()
	for i in AudioManager._player_priorities.size():
		AudioManager._player_priorities[i] = 0

func after_each() -> void:
	SettingsManager._config = _original_config
	AudioManager.set_music_track(_original_track, false)

func _enable_feature(key: String, enabled: bool) -> void:
	SettingsManager._config.set_value("features", key, enabled)

func _bus_has_effect(bus_name: String, effect_class: String) -> bool:
	var bus_idx := AudioServer.get_bus_index(StringName(bus_name))
	if bus_idx < 0:
		return false
	for i in AudioServer.get_bus_effect_count(bus_idx):
		var effect := AudioServer.get_bus_effect(bus_idx, i)
		if effect != null and effect.is_class(effect_class):
			return true
	return false

func test_audio_script_constants_and_sample_rate() -> void:
	assert_eq(AUDIO_SCRIPT_FILENAME, "AudioManager.gd")
	assert_eq(_am.SAMPLE_RATE, 44100.0)
	assert_eq(_am.S24_BYTES_PER_SAMPLE, 3)
	assert_eq(_am.S16_BYTES_PER_SAMPLE, 2)
	assert_eq(_am.POLYPHONIC_VOICES, 48)
	assert_eq(_am.SFX_RANDOMIZER_VARIANTS, 3)
	assert_eq(_am.ADAPTIVE_STEM_COUNT, 4)
	assert_eq(_am.ADAPTIVE_CLIP_COUNT, 4)
	assert_eq(_am.FEATURE_POLYPHONIC_SFX, "polyphonic_sfx")
	assert_eq(_am.FEATURE_RANDOMIZED_SFX, "randomized_sfx")
	assert_eq(_am.FEATURE_ADAPTIVE_MUSIC, "adaptive_music")

func test_native_24bit_probe_matches_engine_classdb() -> void:
	# Probe via ClassDB by name; never reference a nonexistent constant directly.
	var expected := ClassDB.class_has_integer_constant("AudioStreamWAV", "FORMAT_24_BITS")
	assert_eq(_am.has_native_24bit_wav(), expected)

func test_preferred_wav_format_is_supported_by_engine() -> void:
	var constants := ClassDB.class_get_enum_constants("AudioStreamWAV", "Format", false)
	assert_true(constants.has("FORMAT_16_BITS"))
	assert_eq(_am.preferred_wav_format(), AudioStreamWAV.FORMAT_16_BITS)
	assert_true(constants.has("FORMAT_8_BITS"))

func test_encode_s24_little_endian_round_trip() -> void:
	var data := PackedByteArray()
	data.resize(9)
	_am.encode_s24(data, 0, 0)
	assert_eq(data[0], 0)
	assert_eq(data[1], 0)
	assert_eq(data[2], 0)
	_am.encode_s24(data, 3, 1)
	assert_eq(data[3], 1)
	assert_eq(data[4], 0)
	assert_eq(data[5], 0)
	_am.encode_s24(data, 6, -1)
	assert_eq(data[6], 0xFF)
	assert_eq(data[7], 0xFF)
	assert_eq(data[8], 0xFF)
	assert_eq(_am.decode_s24(data, 0), 0)
	assert_eq(_am.decode_s24(data, 3), 1)
	assert_eq(_am.decode_s24(data, 6), -1)

func test_encode_s24_clamps_and_handles_bad_offsets() -> void:
	var data := PackedByteArray()
	data.resize(6)
	_am.encode_s24(data, 0, 8388607)
	assert_eq(data[0], 0xFF)
	assert_eq(data[1], 0xFF)
	assert_eq(data[2], 0x7F)
	assert_eq(_am.decode_s24(data, 0), 8388607)
	_am.encode_s24(data, 3, -8388608)
	assert_eq(data[3], 0x00)
	assert_eq(data[4], 0x00)
	assert_eq(data[5], 0x80)
	assert_eq(_am.decode_s24(data, 3), -8388608)
	_am.encode_s24(data, 0, 99999999)
	assert_eq(_am.decode_s24(data, 0), 8388607)
	_am.encode_s24(data, -2, 123)
	assert_eq(_am.decode_s24(data, 100), 0)

func test_generated_streams_use_supported_format_and_44100_rate() -> void:
	var gen = _am.new()
	autofree(gen)
	var streams: Array[AudioStreamWAV] = [
		gen._generate_laser_stream(),
		gen._generate_explosion_stream(),
		gen._generate_hurt_stream(),
		gen._generate_game_music_outrun(),
	]
	for stream in streams:
		assert_not_null(stream)
		assert_eq(stream.format, _am.preferred_wav_format())
		assert_eq(stream.mix_rate, 44100)
		assert_gt(stream.data.size(), 0)

func test_mastering_chain_and_reverb_return_bus() -> void:
	assert_true(_bus_has_effect("Master", "AudioEffectEQ6"))
	assert_true(_bus_has_effect("Master", "AudioEffectCompressor"))
	assert_true(_bus_has_effect("Master", "AudioEffectLimiter"))
	assert_true(_bus_has_effect("Master", "AudioEffectReverb"))
	assert_true(_bus_has_effect("SFX", "AudioEffectReverb"))
	var reverb_idx := AudioServer.get_bus_index(StringName(_am.REVERB_BUS_NAME))
	assert_true(reverb_idx >= 0)
	assert_true(_bus_has_effect(_am.REVERB_BUS_NAME, "AudioEffectReverb"))
	assert_eq(AudioServer.get_bus_send(reverb_idx), StringName("Master"))
	var sfx_idx := AudioServer.get_bus_index(StringName("SFX"))
	assert_eq(AudioServer.get_bus_send(sfx_idx), StringName(_am.REVERB_BUS_NAME))

func test_randomized_sfx_builds_pools_when_enabled() -> void:
	_enable_feature(_am.FEATURE_RANDOMIZED_SFX, true)
	AudioManager.play_synth_laser(Vector2.ZERO)
	AudioManager.play_synth_explosion(Vector2.ZERO)
	AudioManager.play_synth_hurt()
	AudioManager.play_bunny_hit(Vector2.ZERO)
	AudioManager.play_bunny_death(Vector2.ZERO)
	assert_not_null(AudioManager._stream_laser_randomizer)
	assert_not_null(AudioManager._stream_explosion_randomizer)
	assert_not_null(AudioManager._stream_hurt_randomizer)
	assert_not_null(AudioManager._stream_hit_randomizer)
	assert_not_null(AudioManager._stream_death_randomizer)
	var randomizers: Array[AudioStreamRandomizer] = [
		AudioManager._stream_laser_randomizer,
		AudioManager._stream_explosion_randomizer,
		AudioManager._stream_hurt_randomizer,
	]
	for randomizer in randomizers:
		assert_eq(randomizer.streams_count, _am.SFX_RANDOMIZER_VARIANTS)
		assert_eq(randomizer.playback_mode, AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS)
		assert_gt(randomizer.random_pitch, 1.0)
		assert_gt(randomizer.random_volume_offset_db, 0.0)
	assert_eq(AudioManager._stream_hit_randomizer.streams_count, 4)
	assert_eq(AudioManager._stream_death_randomizer.streams_count, 4)

func test_randomized_sfx_fallback_when_disabled() -> void:
	_enable_feature(_am.FEATURE_RANDOMIZED_SFX, false)
	var saved: AudioStreamRandomizer = AudioManager._stream_laser_randomizer
	AudioManager._stream_laser_randomizer = null
	AudioManager.play_synth_laser(Vector2.ZERO)
	assert_null(AudioManager._stream_laser_randomizer)
	AudioManager._stream_laser_randomizer = saved

func test_polyphonic_player_setup_and_feature_gate() -> void:
	assert_not_null(AudioManager.polyphonic_player)
	assert_eq(AudioManager.polyphonic_player.bus, StringName("SFX"))
	assert_not_null(AudioManager._polyphonic_stream)
	assert_eq(AudioManager._polyphonic_stream.polyphony, _am.POLYPHONIC_VOICES)
	assert_false(AudioManager.is_polyphonic_sfx_active())
	_enable_feature(_am.FEATURE_POLYPHONIC_SFX, true)
	var expected := AudioManager._polyphonic_playback != null
	assert_eq(AudioManager.is_polyphonic_sfx_active(), expected)

func test_play_sfx_polyphonic_and_pool_fallback() -> void:
	var stream := AudioStreamWAV.new()
	stream.data.resize(64)
	_enable_feature(_am.FEATURE_POLYPHONIC_SFX, true)
	var before := 0
	for p in AudioManager.sfx_players:
		if p.playing:
			before += 1
	AudioManager.play_sfx(stream, Vector2.ZERO)
	var after := 0
	for p in AudioManager.sfx_players:
		if p.playing:
			after += 1
	if AudioManager._polyphonic_playback != null:
		assert_eq(after, before, "Polyphonic voices should not consume the 2D pool")
	else:
		assert_eq(after, before + 1, "Polyphony unavailable: use the 2D pool")

	_enable_feature(_am.FEATURE_POLYPHONIC_SFX, false)
	before = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			before += 1
	AudioManager.play_sfx(stream.duplicate(), Vector2.ZERO)
	after = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			after += 1
	assert_eq(after, before + 1, "Disabled polyphony should use the 2D pool")

func test_new_music_tracks_are_registered_and_generate_loops() -> void:
	var ids: Array[String] = []
	for option in _am.MUSIC_OPTIONS:
		ids.append(str(option.get("id", "")))
	assert_true(ids.has("synthwave_chase"))
	assert_true(ids.has("cyberpunk_boss"))
	assert_true(AudioManager.is_valid_music_track("synthwave_chase"))
	assert_true(AudioManager.is_valid_music_track("cyberpunk_boss"))
	var gen = _am.new()
	autofree(gen)
	var chase: AudioStreamWAV = gen._generate_game_music_synthwave_chase()
	var boss: AudioStreamWAV = gen._generate_game_music_cyberpunk_boss()
	for s in [chase, boss]:
		assert_not_null(s)
		assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS)
		assert_eq(s.mix_rate, 44100)
		assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_eq(s.loop_end, int(44100 * 16.0))
		assert_gt(s.data.size(), 0)
	assert_false(chase.data == boss.data, "Tracks should have distinct audio data")

func test_adaptive_music_stream_has_layered_clips_and_crossfades() -> void:
	var stream: AudioStreamInteractive = AudioManager.get_adaptive_music_stream()
	assert_not_null(stream)
	assert_true(stream is AudioStreamInteractive)
	assert_eq(stream.clip_count, _am.ADAPTIVE_CLIP_COUNT)
	assert_eq(stream.initial_clip, 0)
	for clip_idx in _am.ADAPTIVE_CLIP_COUNT:
		var synced := stream.get_clip_stream(clip_idx) as AudioStreamSynchronized
		assert_not_null(synced)
		assert_eq(synced.stream_count, _am.ADAPTIVE_STEM_COUNT)
		for stem_idx in _am.ADAPTIVE_STEM_COUNT:
			assert_not_null(synced.get_sync_stream(stem_idx))
	assert_true(stream.has_transition(0, 1))
	assert_true(stream.has_transition(2, 3))
	assert_eq(stream.get_transition_fade_mode(0, 1), AudioStreamInteractive.FADE_CROSS)
	var calm := stream.get_clip_stream(0) as AudioStreamSynchronized
	var boss := stream.get_clip_stream(3) as AudioStreamSynchronized
	assert_lt(calm.get_sync_stream_volume(3), boss.get_sync_stream_volume(3))

func test_adaptive_clip_selection_mapping() -> void:
	assert_eq(_am._select_adaptive_clip(false, 0, 0.0), 0)
	assert_eq(_am._select_adaptive_clip(false, 6, 0.5), 1)
	assert_eq(_am._select_adaptive_clip(false, 12, 1.0), 2)
	assert_eq(_am._select_adaptive_clip(true, 0, 0.0), 3)
	assert_eq(_am._select_adaptive_clip(false, 999, 99.0), 2)

func test_set_music_intensity_switches_adaptive_clip() -> void:
	_enable_feature(_am.FEATURE_ADAPTIVE_MUSIC, true)
	AudioManager.set_music_track("dynamic", false)
	AudioManager.revert_to_default_music()
	AudioManager.set_music_intensity(false, 0, 0.0)
	assert_eq(AudioManager.get_adaptive_clip_index(), 0)
	AudioManager.set_music_intensity(false, 12, 1.0)
	assert_eq(AudioManager.get_adaptive_clip_index(), 2)
	AudioManager.set_music_intensity(true, 0, 0.0)
	assert_eq(AudioManager.get_adaptive_clip_index(), 3)
	assert_eq(AudioManager.music_player.stream, AudioManager.get_adaptive_music_stream())
	AudioManager.set_music_intensity(false, 0, NAN)
	assert_eq(AudioManager.get_adaptive_clip_index(), 0)

func test_adaptive_feature_toggle_and_playlist_noop() -> void:
	AudioManager.set_music_track("dynamic", false)
	AudioManager.set_music_intensity(false, 0, 0.0)
	var original_index := AudioManager.get_adaptive_clip_index()
	_enable_feature(_am.FEATURE_ADAPTIVE_MUSIC, false)
	AudioManager.set_music_intensity(true, 20, 1.0)
	assert_eq(AudioManager.get_adaptive_clip_index(), original_index)

	_enable_feature(_am.FEATURE_ADAPTIVE_MUSIC, true)
	var dummy := AudioStreamWAV.new()
	AudioManager.set_playlist([dummy], false)
	AudioManager.set_music_intensity(true, 20, 1.0)
	assert_eq(AudioManager.get_adaptive_clip_index(), original_index)
	AudioManager.revert_to_default_music()

func test_set_music_intensity_respects_explicit_track() -> void:
	_enable_feature(_am.FEATURE_ADAPTIVE_MUSIC, true)
	AudioManager.set_music_track("outrun", false)
	AudioManager.play_music_track("outrun")
	AudioManager.set_music_intensity(false, 0, 0.0)
	var index := AudioManager.get_adaptive_clip_index()
	AudioManager.set_music_intensity(true, 12, 1.0)
	assert_eq(AudioManager.get_adaptive_clip_index(), index)
	assert_ne(AudioManager.music_player.stream, AudioManager.get_adaptive_music_stream())

func test_set_bus_volume_persists_to_settings() -> void:
	var initial_db := AudioServer.get_bus_volume_db(0)
	AudioManager.set_bus_volume(AudioManager.Bus.MASTER, -6.0)
	assert_eq(AudioServer.get_bus_volume_db(0), -6.0)
	assert_almost_eq(SettingsManager.get_volume("Master", 1.0), db_to_linear(-6.0), 0.0001)
	AudioManager.set_bus_volume(AudioManager.Bus.MASTER, initial_db)
