extends Node

enum Bus { MASTER = 0, MUSIC = 1, SFX = 2 }

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer2D] = []
const SFX_PLAYER_COUNT: int = 16

const SAMPLE_RATE: float = 44100.0
const S24_BYTES_PER_SAMPLE: int = 3
const S16_BYTES_PER_SAMPLE: int = 2
const POLYPHONIC_VOICES: int = 48
const SFX_RANDOMIZER_VARIANTS: int = 3
const ADAPTIVE_STEM_COUNT: int = 4
const ADAPTIVE_CLIP_COUNT: int = 4

const FEATURE_POLYPHONIC_SFX: String = "polyphonic_sfx"
const FEATURE_RANDOMIZED_SFX: String = "randomized_sfx"
const FEATURE_ADAPTIVE_MUSIC: String = "adaptive_music"
const REVERB_BUS_NAME: String = "Reverb"

var polyphonic_player: AudioStreamPlayer2D
var _polyphonic_stream: AudioStreamPolyphonic
var _polyphonic_playback: AudioStreamPlaybackPolyphonic

var _stream_laser: AudioStreamWAV
var _stream_laser_randomizer: AudioStreamRandomizer
var _stream_explosion_randomizer: AudioStreamRandomizer
var _stream_hurt_randomizer: AudioStreamRandomizer
var _stream_hit_randomizer: AudioStreamRandomizer
var _stream_death_randomizer: AudioStreamRandomizer
var _stream_explosion: AudioStreamWAV
var _stream_hurt: AudioStreamWAV
var _stream_boost: AudioStreamWAV
var _stream_emp: AudioStreamWAV
var _stream_menu_music: AudioStreamWAV
var _stream_game_music_bunny: AudioStreamWAV
var _stream_game_music_biker: AudioStreamWAV
var _stream_game_music_sasquatch: AudioStreamWAV
var _stream_game_music_void: AudioStreamWAV
var _stream_game_music_classic: AudioStreamWAV
var _stream_game_music_outrun: AudioStreamWAV
var _stream_game_music_industrial: AudioStreamWAV
var _stream_game_music_neon_drift: AudioStreamWAV
var _stream_game_music_synthetic_chase: AudioStreamWAV
var _stream_game_music_ambient_highway: AudioStreamWAV
var _stream_game_music_synthwave_chase: AudioStreamWAV
var _stream_game_music_cyberpunk_boss: AudioStreamWAV

var _adaptive_music: AudioStreamInteractive
var _adaptive_clip_index: int = 0
var _last_intensity_boss: bool = false
var _last_intensity_tier: int = 0
var _last_intensity_density: float = 0.0

const MUSIC_OPTIONS: Array[Dictionary] = [
	{"id": "dynamic", "name": "Dynamic (Stage Adaptive)"},
	{"id": "outrun", "name": "Outrun Synthwave"},
	{"id": "industrial", "name": "Cyber Industrial"},
	{"id": "neon_drift", "name": "Neon Drift"},
	{"id": "synthetic_chase", "name": "Synthetic Chase"},
	{"id": "synthwave_chase", "name": "Synthwave Chase"},
	{"id": "cyberpunk_boss", "name": "Cyberpunk Boss"},
	{"id": "ambient_highway", "name": "Ambient Highway"},
	{"id": "classic", "name": "Classic Arcade"},
	{"id": "bunny", "name": "Bio-Hop Beat (Stage 1)"},
	{"id": "biker", "name": "Wasteland Metal (Stage 2)"},
	{"id": "sasquatch", "name": "Feral Drums (Stage 3)"},
	{"id": "void", "name": "Void Resonance (Stage 4)"},
]

var selected_music_track: String = "dynamic"
var _stream_crash: AudioStreamWAV
var _stream_bounce: AudioStreamWAV

var _stream_bunny_hit: AudioStreamWAV
var _stream_rotor_hit: AudioStreamWAV
var _stream_scav_hit: AudioStreamWAV
var _stream_drone_hit: AudioStreamWAV
var _stream_bunny_death: AudioStreamWAV
var _stream_rotor_death: AudioStreamWAV
var _stream_scav_death: AudioStreamWAV
var _stream_drone_death: AudioStreamWAV
var _stream_lightning: AudioStreamWAV

var _stream_demo_boss_bunny: AudioStreamWAV
var _stream_demo_boss_sasquatch: AudioStreamWAV
var _stream_demo_boss_giant_biker: AudioStreamWAV
var _stream_demo_boss_void_drone: AudioStreamWAV
var _stream_demo_boss_war_rig: AudioStreamWAV

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player_priorities: Array[int] = []
var _async_tasks: Dictionary = {}
var _custom_playlist: Array[AudioStream] = []
var _custom_playlist_idx: int = 0
var _custom_playlist_shuffle: bool = true

static func _semitone_ratio(semitones: int) -> float:
	return pow(2.0, float(semitones) / 12.0)

static func _init_buses() -> void:
	var expected_buses = ["Master", "Music", "SFX"]
	for i in expected_buses.size():
		var bus_name = expected_buses[i]
		if AudioServer.get_bus_count() <= i or AudioServer.get_bus_name(i) != bus_name:
			if AudioServer.get_bus_count() <= i:
				AudioServer.add_bus()
			AudioServer.set_bus_name(i, bus_name)

func _ready() -> void:
	seed(42)
	_rng.seed = 42
	_init_buses()

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.name = "MusicPlayer"
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

	for i in SFX_PLAYER_COUNT:
		var p = AudioStreamPlayer2D.new()
		p.bus = "SFX"
		p.name = "SFXPlayer" + str(i)
		add_child(p)
		sfx_players.append(p)
		_player_priorities.append(0)
		p.finished.connect(_on_sfx_finished.bind(i))

	_setup_polyphonic_sfx()
	_setup_audio_buses()
	if SettingsManager and SettingsManager.has_method("get_music_track"):
		var saved_track: String = SettingsManager.get_music_track()
		if is_valid_music_track(saved_track):
			selected_music_track = saved_track
	_generate_all_async()

func _on_sfx_finished(player_idx: int) -> void:
	if player_idx < _player_priorities.size():
		_player_priorities[player_idx] = 0

static func has_native_24bit_wav() -> bool:
	return ClassDB.class_has_integer_constant("AudioStreamWAV", "FORMAT_24_BITS")

# Godot 4.7 does not expose FORMAT_24_BITS. Synthesize at 24-bit resolution and
# down-convert to the best PCM format the running engine actually supports.
static func preferred_wav_format() -> int:
	var constants := ClassDB.class_get_enum_constants("AudioStreamWAV", "Format", false)
	if constants.has("FORMAT_16_BITS"):
		return ClassDB.class_get_integer_constant("AudioStreamWAV", "FORMAT_16_BITS")
	if constants.has("FORMAT_8_BITS"):
		return ClassDB.class_get_integer_constant("AudioStreamWAV", "FORMAT_8_BITS")
	return AudioStreamWAV.FORMAT_16_BITS

# Little-endian signed 24-bit PCM, two's complement, clamped to [-8388608, 8388607].
static func encode_s24(data: PackedByteArray, byte_offset: int, sample: int) -> void:
	if byte_offset < 0 or byte_offset + S24_BYTES_PER_SAMPLE > data.size():
		return
	var value := clampi(sample, -8388608, 8388607) & 0xFFFFFF
	data[byte_offset] = value & 0xFF
	data[byte_offset + 1] = (value >> 8) & 0xFF
	data[byte_offset + 2] = (value >> 16) & 0xFF

static func decode_s24(data: PackedByteArray, byte_offset: int) -> int:
	if byte_offset < 0 or byte_offset + S24_BYTES_PER_SAMPLE > data.size():
		return 0
	var value := data[byte_offset] | (data[byte_offset + 1] << 8) | (data[byte_offset + 2] << 16)
	if (value & 0x800000) != 0:
		value -= 0x1000000
	return value

func _feature_enabled(key: String, default_value: bool) -> bool:
	if not SettingsManager or not SettingsManager.has_method("is_feature_enabled"):
		return default_value
	return SettingsManager.is_feature_enabled(key, default_value)

func _setup_polyphonic_sfx() -> void:
	_polyphonic_stream = AudioStreamPolyphonic.new()
	_polyphonic_stream.polyphony = POLYPHONIC_VOICES
	polyphonic_player = AudioStreamPlayer2D.new()
	polyphonic_player.bus = "SFX"
	polyphonic_player.name = "PolyphonicSFXPlayer"
	polyphonic_player.stream = _polyphonic_stream
	add_child(polyphonic_player)
	polyphonic_player.play()
	_polyphonic_playback = polyphonic_player.get_stream_playback() as AudioStreamPlaybackPolyphonic

func is_polyphonic_sfx_active() -> bool:
	return _feature_enabled(FEATURE_POLYPHONIC_SFX, false) and _polyphonic_playback != null

func _bus_effect_of_class(bus_idx: int, effect_class: StringName) -> AudioEffect:
	if bus_idx < 0 or bus_idx >= AudioServer.bus_count:
		return null
	for i in AudioServer.get_bus_effect_count(bus_idx):
		var effect := AudioServer.get_bus_effect(bus_idx, i)
		if effect and effect.is_class(String(effect_class)):
			return effect
	return null

func _restore_bus_volumes() -> void:
	if not SettingsManager or not SettingsManager.has_method("get_volume"):
		return
	for bus_name in ["Master", "Music", "SFX"]:
		var bus_idx := AudioServer.get_bus_index(bus_name)
		if bus_idx < 0:
			continue
		var linear: float = clampf(float(SettingsManager.get_volume(bus_name, 1.0)), 0.0, 1.0)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear) if linear > 0.0 else -80.0)

func _setup_audio_buses() -> void:
	for i in AudioServer.bus_count:
		var bus_name := str(AudioServer.get_bus_name(i))
		match bus_name:
			"SFX":
				if _bus_effect_of_class(i, &"AudioEffectReverb") == null:
					var reverb := AudioEffectReverb.new()
					reverb.room_size = 0.2
					reverb.damping = 0.55
					reverb.wet = 0.12
					reverb.dry = 1.0
					AudioServer.add_bus_effect(i, reverb)
			"Music":
				if _bus_effect_of_class(i, &"AudioEffectEQ") == null:
					AudioServer.add_bus_effect(i, AudioEffectEQ.new())
			"Master":
				var eq := _bus_effect_of_class(i, &"AudioEffectEQ6") as AudioEffectEQ6
				if eq == null:
					eq = AudioEffectEQ6.new()
					AudioServer.add_bus_effect(i, eq)
				eq.set_band_gain_db(0, 3.0) # low
				eq.set_band_gain_db(2, -2.0) # low-mid
				eq.set_band_gain_db(3, -1.5) # mid
				eq.set_band_gain_db(5, 2.0) # high
				if _bus_effect_of_class(i, &"AudioEffectCompressor") == null:
					var compressor := AudioEffectCompressor.new()
					compressor.threshold = -8.0
					compressor.ratio = 3.5
					compressor.gain = 1.0
					AudioServer.add_bus_effect(i, compressor)
				if _bus_effect_of_class(i, &"AudioEffectLimiter") == null:
					var limiter := AudioEffectLimiter.new()
					limiter.ceiling_db = -0.5
					limiter.threshold_db = -1.0
					AudioServer.add_bus_effect(i, limiter)
				if _bus_effect_of_class(i, &"AudioEffectReverb") == null:
					var master_reverb := AudioEffectReverb.new()
					master_reverb.room_size = 0.35
					master_reverb.damping = 0.6
					master_reverb.wet = 0.06
					master_reverb.dry = 1.0
					AudioServer.add_bus_effect(i, master_reverb)

	# Dedicated reverb return bus. SFX feeds it, and it returns to Master, giving
	# a real send/return topology without removing the SFX insert reverb.
	var reverb_idx := AudioServer.get_bus_index(StringName(REVERB_BUS_NAME))
	if reverb_idx < 0:
		AudioServer.add_bus()
		reverb_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(reverb_idx, REVERB_BUS_NAME)
	if _bus_effect_of_class(reverb_idx, &"AudioEffectReverb") == null:
		var send_reverb := AudioEffectReverb.new()
		send_reverb.room_size = 0.65
		send_reverb.damping = 0.45
		send_reverb.wet = 0.22
		send_reverb.dry = 1.0
		AudioServer.add_bus_effect(reverb_idx, send_reverb)
	AudioServer.set_bus_send(reverb_idx, &"Master")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_send(sfx_idx, StringName(REVERB_BUS_NAME))
	_restore_bus_volumes()

func _build_stream(duration: float, generator: Callable) -> AudioStreamWAV:
	var num_samples := maxi(0, int(SAMPLE_RATE * duration))
	# Always synthesize at 24-bit resolution first, including on engines that
	# can only store 16-bit PCM data.
	var s24_data := PackedByteArray()
	s24_data.resize(num_samples * S24_BYTES_PER_SAMPLE)
	for i in num_samples:
		var sample := float(generator.call(i / SAMPLE_RATE, i))
		encode_s24(s24_data, i * S24_BYTES_PER_SAMPLE, int(round(sample * 256.0)))

	var format := preferred_wav_format()
	var data := PackedByteArray()
	if format == AudioStreamWAV.FORMAT_16_BITS:
		data.resize(num_samples * S16_BYTES_PER_SAMPLE)
		for i in num_samples:
			data.encode_s16(i * S16_BYTES_PER_SAMPLE, clampi(decode_s24(s24_data, i * S24_BYTES_PER_SAMPLE) >> 8, -32768, 32767))
	else:
		data.resize(num_samples)
		for i in num_samples:
			data[i] = clampi(decode_s24(s24_data, i * S24_BYTES_PER_SAMPLE) >> 16, -128, 127) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = format
	stream.mix_rate = int(SAMPLE_RATE)
	stream.data = data
	return stream

func get_music_options() -> Array[Dictionary]:
	return MUSIC_OPTIONS

func is_valid_music_track(track_id: String) -> bool:
	for opt in MUSIC_OPTIONS:
		if str(opt.get("id", "")) == track_id:
			return true
	return false

func get_music_track() -> String:
	return selected_music_track

func set_music_track(track_id: String, preview: bool = true) -> void:
	var target := track_id if is_valid_music_track(track_id) else "dynamic"
	selected_music_track = target
	if SettingsManager and SettingsManager.has_method("set_music_track"):
		SettingsManager.set_music_track(target)
	if preview and _custom_playlist.is_empty():
		if target == "dynamic":
			if GameManager and GameManager.state == GameManager.GameState.PLAYING:
				play_game_music()
			else:
				play_menu_music()
		else:
			play_music_track(target)

func play_music_track(track_id: String) -> void:
	var stream := _resolve_track_stream(track_id)
	if stream and music_player.stream != stream:
		play_music(stream)

func _resolve_track_stream(track_id: String) -> AudioStreamWAV:
	match track_id:
		"outrun":
			_wait_for_task("game_music_outrun")
			if not _stream_game_music_outrun:
				_stream_game_music_outrun = _generate_game_music_outrun()
			return _stream_game_music_outrun
		"industrial":
			_wait_for_task("game_music_industrial")
			if not _stream_game_music_industrial:
				_stream_game_music_industrial = _generate_game_music_industrial()
			return _stream_game_music_industrial
		"neon_drift":
			_wait_for_task("game_music_neon_drift")
			if not _stream_game_music_neon_drift:
				_stream_game_music_neon_drift = _generate_game_music_neon_drift()
			return _stream_game_music_neon_drift
		"synthetic_chase":
			_wait_for_task("game_music_synthetic_chase")
			if not _stream_game_music_synthetic_chase:
				_stream_game_music_synthetic_chase = _generate_game_music_synthetic_chase()
			return _stream_game_music_synthetic_chase
		"synthwave_chase":
			_wait_for_task("game_music_synthwave_chase")
			if not _stream_game_music_synthwave_chase:
				_stream_game_music_synthwave_chase = _generate_game_music_synthwave_chase()
			return _stream_game_music_synthwave_chase
		"cyberpunk_boss":
			_wait_for_task("game_music_cyberpunk_boss")
			if not _stream_game_music_cyberpunk_boss:
				_stream_game_music_cyberpunk_boss = _generate_game_music_cyberpunk_boss()
			return _stream_game_music_cyberpunk_boss
		"ambient_highway":
			_wait_for_task("game_music_ambient_highway")
			if not _stream_game_music_ambient_highway:
				_stream_game_music_ambient_highway = _generate_game_music_ambient_highway()
			return _stream_game_music_ambient_highway
		"classic":
			_wait_for_task("game_music_classic")
			if not _stream_game_music_classic:
				_stream_game_music_classic = _generate_game_music()
			return _stream_game_music_classic
		"bunny":
			_wait_for_task("game_music_bunny")
			if not _stream_game_music_bunny:
				_stream_game_music_bunny = _generate_game_music_bunny()
			return _stream_game_music_bunny
		"biker":
			_wait_for_task("game_music_biker")
			if not _stream_game_music_biker:
				_stream_game_music_biker = _generate_game_music_biker()
			return _stream_game_music_biker
		"sasquatch":
			_wait_for_task("game_music_sasquatch")
			if not _stream_game_music_sasquatch:
				_stream_game_music_sasquatch = _generate_game_music_sasquatch()
			return _stream_game_music_sasquatch
		"void":
			_wait_for_task("game_music_void")
			if not _stream_game_music_void:
				_stream_game_music_void = _generate_game_music_void()
			return _stream_game_music_void
	return null

func play_menu_music() -> void:
	if not _custom_playlist.is_empty():
		return
	_wait_for_task("menu_music")
	if not _stream_menu_music:
		_stream_menu_music = _generate_menu_music()
	if music_player.stream != _stream_menu_music:
		play_music(_stream_menu_music)

func play_game_music() -> void:
	if not _custom_playlist.is_empty():
		if not music_player.playing:
			_play_current_playlist_track()
		return
	if selected_music_track != "dynamic":
		var selected_stream := _resolve_track_stream(selected_music_track)
		if selected_stream and music_player.stream != selected_stream:
			play_music(selected_stream)
		return
	var stream: AudioStreamWAV = null
	var bosses_killed = GameManager.bosses_killed
	
	if bosses_killed == 0:
		_wait_for_task("game_music_bunny")
		if not _stream_game_music_bunny:
			_stream_game_music_bunny = _generate_game_music_bunny()
		stream = _stream_game_music_bunny
	elif bosses_killed == 1:
		_wait_for_task("game_music_biker")
		if not _stream_game_music_biker:
			_stream_game_music_biker = _generate_game_music_biker()
		stream = _stream_game_music_biker
	elif bosses_killed == 2:
		_wait_for_task("game_music_sasquatch")
		if not _stream_game_music_sasquatch:
			_stream_game_music_sasquatch = _generate_game_music_sasquatch()
		stream = _stream_game_music_sasquatch
	else:
		_wait_for_task("game_music_void")
		if not _stream_game_music_void:
			_stream_game_music_void = _generate_game_music_void()
		stream = _stream_game_music_void
		
	if music_player.stream != stream:
		play_music(stream)

func play_music(stream: AudioStream) -> void:
	if not stream:
		return
	music_player.stream = stream
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func get_adaptive_music_stream() -> AudioStreamInteractive:
	if not _adaptive_music:
		_adaptive_music = _build_adaptive_music()
	return _adaptive_music

func get_adaptive_clip_index() -> int:
	return _adaptive_clip_index

static func _select_adaptive_clip(boss_active: bool, difficulty_tier: int, enemy_density: float) -> int:
	if boss_active:
		return 3
	var tier_score := clampf(float(clampi(difficulty_tier, 0, 20)) / 12.0, 0.0, 1.0)
	var density_score := clampf(enemy_density, 0.0, 1.0)
	var score := tier_score * 0.45 + density_score * 0.55
	if score >= 0.68:
		return 2
	if score >= 0.32:
		return 1
	return 0

func set_music_intensity(boss_active: bool, difficulty_tier: int, enemy_density: float) -> void:
	var tier := clampi(difficulty_tier, 0, 20)
	var density := clampf(enemy_density, 0.0, 1.0)
	if is_nan(density) or is_inf(density):
		density = 0.0
	_last_intensity_boss = boss_active
	_last_intensity_tier = tier
	_last_intensity_density = density
	if not _feature_enabled(FEATURE_ADAPTIVE_MUSIC, true) or not _custom_playlist.is_empty():
		return
	# Respect an explicitly selected music track; adaptive mixing belongs to the
	# default "dynamic" mode.
	if selected_music_track != "dynamic":
		return
	var target := _select_adaptive_clip(boss_active, tier, density)
	_adaptive_clip_index = target
	var stream := get_adaptive_music_stream()
	if music_player.stream != stream or not music_player.playing:
		play_music(stream)
	var playback := music_player.get_stream_playback()
	if playback is AudioStreamPlaybackInteractive:
		playback.switch_to_clip(target)

func set_playlist(tracks: Array[AudioStream], shuffle: bool = true) -> void:
	_custom_playlist.clear()
	for t in tracks:
		if t:
			_custom_playlist.append(t)
	_custom_playlist_shuffle = shuffle
	_custom_playlist_idx = 0
	if not _custom_playlist.is_empty():
		if _custom_playlist_shuffle and _custom_playlist.size() > 1:
			_custom_playlist_idx = _rng.randi() % _custom_playlist.size()
		_play_current_playlist_track()

func revert_to_default_music() -> void:
	_custom_playlist.clear()
	_custom_playlist_idx = 0
	if GameManager.state == GameManager.GameState.PLAYING:
		play_game_music()
	else:
		play_menu_music()

func _play_current_playlist_track() -> void:
	if _custom_playlist.is_empty() or not is_instance_valid(music_player):
		return
	var idx := clampi(_custom_playlist_idx, 0, _custom_playlist.size() - 1)
	play_music(_custom_playlist[idx])

func _on_music_finished() -> void:
	if _custom_playlist.is_empty():
		return
	if _custom_playlist_shuffle and _custom_playlist.size() > 1:
		_custom_playlist_idx = _rng.randi() % _custom_playlist.size()
	else:
		_custom_playlist_idx = (_custom_playlist_idx + 1) % _custom_playlist.size()
	_play_current_playlist_track()

func play_demo_music(boss_type: String) -> void:
	var stream: AudioStreamWAV
	if boss_type == "boss_bunny":
		_wait_for_task("demo_boss_bunny")
		if not _stream_demo_boss_bunny:
			_stream_demo_boss_bunny = _generate_demo_music_bunny()
		stream = _stream_demo_boss_bunny
	elif boss_type == "boss_giant_biker":
		_wait_for_task("demo_boss_giant_biker")
		if not _stream_demo_boss_giant_biker:
			_stream_demo_boss_giant_biker = _generate_demo_music_giant_biker()
		stream = _stream_demo_boss_giant_biker
	elif boss_type == "boss_sasquatch":
		_wait_for_task("demo_boss_sasquatch")
		if not _stream_demo_boss_sasquatch:
			_stream_demo_boss_sasquatch = _generate_demo_music_sasquatch()
		stream = _stream_demo_boss_sasquatch
	elif boss_type == "boss_void_drone":
		_wait_for_task("demo_boss_void_drone")
		if not _stream_demo_boss_void_drone:
			_stream_demo_boss_void_drone = _generate_demo_music_void_drone()
		stream = _stream_demo_boss_void_drone
	elif boss_type == "boss":
		_wait_for_task("demo_boss_war_rig")
		if not _stream_demo_boss_war_rig:
			_stream_demo_boss_war_rig = _generate_demo_music_war_rig()
		stream = _stream_demo_boss_war_rig
	
	if stream and music_player.stream != stream:
		play_music(stream)

func play_sfx(stream: AudioStream, pos: Vector2 = Vector2.ZERO, priority: int = 0) -> void:
	if not stream:
		return
	if is_polyphonic_sfx_active():
		polyphonic_player.global_position = pos
		var voice_id := _polyphonic_playback.play_stream(
			stream,
			0.0,
			0.0,
			_rng.randf_range(0.92, 1.08),
			AudioServer.PLAYBACK_TYPE_DEFAULT,
			&"SFX"
		)
		if voice_id != AudioStreamPlaybackPolyphonic.INVALID_ID:
			return
		# Polyphony exhausted: fall through to the original 16-player pool.
	var best_idx = -1
	var lowest_priority = 999
	var all_busy = true
	for i in sfx_players.size():
		var p = sfx_players[i]
		if not p.playing:
			best_idx = i
			all_busy = false
			break
		if _player_priorities[i] < lowest_priority:
			lowest_priority = _player_priorities[i]
			best_idx = i
	if all_busy and best_idx >= 0 and priority <= lowest_priority:
		return
	if best_idx == -1:
		best_idx = 0
	var player = sfx_players[best_idx]
	player.stream = stream
	player.global_position = pos
	player.pitch_scale = _rng.randf_range(0.92, 1.08)
	player.play()
	if best_idx < _player_priorities.size():
		_player_priorities[best_idx] = priority

func set_bus_volume(bus: Bus, volume_db: float) -> void:
	var clean_db := clampf(volume_db, -80.0, 24.0)
	if is_nan(clean_db) or is_inf(clean_db):
		clean_db = 0.0
	AudioServer.set_bus_volume_db(bus, clean_db)
	if bus >= 0 and bus < AudioServer.bus_count and SettingsManager and SettingsManager.has_method("set_volume"):
		SettingsManager.set_volume(str(AudioServer.get_bus_name(bus)), db_to_linear(clean_db))
		# SettingsManager re-derives dB from linear; restore the exact value so
		# callers still observe the volume they requested.
		AudioServer.set_bus_volume_db(bus, clean_db)

func _create_sfx_randomizer(base: AudioStream, pitch: float, volume_db: float) -> AudioStreamRandomizer:
	var randomizer := AudioStreamRandomizer.new()
	randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	randomizer.random_pitch = pitch
	randomizer.random_volume_offset_db = volume_db
	for i in SFX_RANDOMIZER_VARIANTS:
		var variant: AudioStream = base.duplicate() if i > 0 else base
		randomizer.add_stream(i, variant, 1.0 - 0.2 * float(i))
	return randomizer

func _hit_randomizer() -> AudioStreamRandomizer:
	if not _stream_bunny_hit:
		_stream_bunny_hit = _generate_bunny_hit_stream()
	if not _stream_rotor_hit:
		_stream_rotor_hit = _generate_rotor_hit_stream()
	if not _stream_scav_hit:
		_stream_scav_hit = _generate_scav_hit_stream()
	if not _stream_drone_hit:
		_stream_drone_hit = _generate_drone_hit_stream()
	if not _stream_hit_randomizer:
		var pools := [_stream_bunny_hit, _stream_rotor_hit, _stream_scav_hit, _stream_drone_hit]
		_stream_hit_randomizer = AudioStreamRandomizer.new()
		_stream_hit_randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		_stream_hit_randomizer.random_pitch = 1.14
		_stream_hit_randomizer.random_volume_offset_db = 1.8
		for i in pools.size():
			_stream_hit_randomizer.add_stream(i, pools[i], 1.0)
	return _stream_hit_randomizer

func _death_randomizer() -> AudioStreamRandomizer:
	if not _stream_bunny_death:
		_stream_bunny_death = _generate_bunny_death_stream()
	if not _stream_rotor_death:
		_stream_rotor_death = _generate_rotor_death_stream()
	if not _stream_scav_death:
		_stream_scav_death = _generate_scav_death_stream()
	if not _stream_drone_death:
		_stream_drone_death = _generate_drone_death_stream()
	if not _stream_death_randomizer:
		var pools := [_stream_bunny_death, _stream_rotor_death, _stream_scav_death, _stream_drone_death]
		_stream_death_randomizer = AudioStreamRandomizer.new()
		_stream_death_randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		_stream_death_randomizer.random_pitch = 1.09
		_stream_death_randomizer.random_volume_offset_db = 2.0
		for i in pools.size():
			_stream_death_randomizer.add_stream(i, pools[i], 1.0)
	return _stream_death_randomizer

func play_synth_laser(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_laser:
		_stream_laser = _generate_laser_stream()
	var stream: AudioStream = _stream_laser
	if _feature_enabled(FEATURE_RANDOMIZED_SFX, true):
		if not _stream_laser_randomizer:
			_stream_laser_randomizer = _create_sfx_randomizer(_stream_laser, 1.06, 1.5)
		stream = _stream_laser_randomizer
	play_sfx(stream, pos)

func play_synth_explosion(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_explosion:
		_stream_explosion = _generate_explosion_stream()
	var stream: AudioStream = _stream_explosion
	if _feature_enabled(FEATURE_RANDOMIZED_SFX, true):
		if not _stream_explosion_randomizer:
			_stream_explosion_randomizer = _create_sfx_randomizer(_stream_explosion, 1.18, 2.2)
		stream = _stream_explosion_randomizer
	play_sfx(stream, pos)

func play_synth_hurt() -> void:
	if not _stream_hurt:
		_stream_hurt = _generate_hurt_stream()
	var stream: AudioStream = _stream_hurt
	if _feature_enabled(FEATURE_RANDOMIZED_SFX, true):
		if not _stream_hurt_randomizer:
			_stream_hurt_randomizer = _create_sfx_randomizer(_stream_hurt, 1.12, 1.6)
		stream = _stream_hurt_randomizer
	play_sfx(stream, Vector2.ZERO)

func play_synth_boost() -> void:
	if not _stream_boost:
		_stream_boost = _generate_boost_stream()
	play_sfx(_stream_boost, Vector2.ZERO)

func play_synth_emp(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_emp:
		_stream_emp = _generate_emp_stream()
	play_sfx(_stream_emp, pos)

func _play_hit_sfx(fallback: AudioStream, pos: Vector2) -> void:
	var stream: AudioStream = fallback
	if _feature_enabled(FEATURE_RANDOMIZED_SFX, true):
		stream = _hit_randomizer()
	play_sfx(stream, pos)

func _play_death_sfx(fallback: AudioStream, pos: Vector2) -> void:
	var stream: AudioStream = fallback
	if _feature_enabled(FEATURE_RANDOMIZED_SFX, true):
		stream = _death_randomizer()
	play_sfx(stream, pos)

func play_bunny_hit(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_bunny_hit:
		_stream_bunny_hit = _generate_bunny_hit_stream()
	_play_hit_sfx(_stream_bunny_hit, pos)

func play_rotor_hit(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_rotor_hit:
		_stream_rotor_hit = _generate_rotor_hit_stream()
	_play_hit_sfx(_stream_rotor_hit, pos)

func play_scav_hit(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_scav_hit:
		_stream_scav_hit = _generate_scav_hit_stream()
	_play_hit_sfx(_stream_scav_hit, pos)

func play_drone_hit(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_drone_hit:
		_stream_drone_hit = _generate_drone_hit_stream()
	_play_hit_sfx(_stream_drone_hit, pos)

func play_bunny_death(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_bunny_death:
		_stream_bunny_death = _generate_bunny_death_stream()
	_play_death_sfx(_stream_bunny_death, pos)

func play_rotor_death(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_rotor_death:
		_stream_rotor_death = _generate_rotor_death_stream()
	_play_death_sfx(_stream_rotor_death, pos)

func play_scav_death(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_scav_death:
		_stream_scav_death = _generate_scav_death_stream()
	_play_death_sfx(_stream_scav_death, pos)

func play_drone_death(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_drone_death:
		_stream_drone_death = _generate_drone_death_stream()
	_play_death_sfx(_stream_drone_death, pos)

func play_synth_crash(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_crash:
		_stream_crash = _generate_crash_stream()
	play_sfx(_stream_crash, pos)

func play_synth_bounce(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_bounce:
		_stream_bounce = _generate_bounce_stream()
	play_sfx(_stream_bounce, pos)

func play_lightning_strike(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_lightning:
		_stream_lightning = _generate_lightning_stream()
	play_sfx(_stream_lightning, pos)

# =====Procedural Synthesizers (24-bit resolution, exported to engine PCM format)======

func _generate_laser_stream() -> AudioStreamWAV:
	return _build_stream(0.12, func(t: float, _i: int) -> float:
		var freq = lerpf(800.0, 150.0, t / 0.12)
		return 6000.0 if sin(TAU * freq * t) >= 0.0 else -6000.0
	)

func _generate_explosion_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	return _build_stream(0.35, func(t: float, _i: int) -> float:
		var amp = lerpf(12000.0, 0.0, t / 0.35)
		return rng.randf_range(-amp, amp)
	)

func _generate_hurt_stream() -> AudioStreamWAV:
	return _build_stream(0.2, func(t: float, _i: int) -> float:
		var freq = lerpf(180.0, 45.0, t / 0.2)
		return 9000.0 if sin(TAU * freq * t) >= 0.0 else -9000.0
	)

func _generate_boost_stream() -> AudioStreamWAV:
	return _build_stream(0.4, func(t: float, _i: int) -> float:
		var freq = lerpf(250.0, 850.0, t / 0.4)
		return 5000.0 if sin(TAU * freq * t) >= 0.0 else -5000.0
	)

func _generate_emp_stream() -> AudioStreamWAV:
	return _build_stream(0.6, func(t: float, _i: int) -> float:
		var freq = 350.0 + sin(t * 70.0) * 120.0
		return 7000.0 if sin(TAU * freq * t) >= 0.0 else -7000.0
	)

func _generate_menu_music() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var arpeggio: Array[int] = [0, 4, 7, 12, 7, 4, 0, -5, 0, 4, 7, 12, 7, 4, 0, -5,
		2, 5, 9, 14, 9, 5, 2, -3, 0, 4, 7, 12, 7, 4, 0, -5]
	var arp_ratios: Array[float] = []
	for s in arpeggio:
		arp_ratios.append(_semitone_ratio(s))
	var measure_ratios: Array[float] = [1.0, 1.0, _semitone_ratio(5), _semitone_ratio(7)]
	var bpm = 120.0
	var step_duration = (60.0 / bpm) / 4.0
	var base_freq = 110.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)
		var measure = int(t / (step_duration * 8.0))
		var current_base = base_freq * measure_ratios[measure % 4]
		var freq = current_base * arp_ratios[step_idx % arp_ratios.size()]
		var wave = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		var env = maxf(0.0, 1.0 - (step_t / step_duration))
		var val = wave * 4000.0 * env

		var bass_freq = current_base / 2.0
		var bass_wave = 1.0 if fmod(t * bass_freq, 1.0) < 0.5 else -1.0
		val += bass_wave * 2000.0

		if step_idx % 4 == 0:
			var kick = sin(TAU * lerpf(150.0, 40.0, step_t / step_duration) * step_t)
			val += kick * 5000.0 * maxf(0.0, 1.0 - (step_t / (step_duration * 1.5)))

		if step_idx % 8 == 4:
			var snare = rng.randf() * 2.0 - 1.0
			val += snare * 4000.0 * maxf(0.0, 1.0 - (step_t / step_duration))

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 203
	var arp_normal: Array[float] = []
	for s in [0, 3, 7, 12, 7, 3, 0, -5, 0, 4, 7, 14, 7, 4, 0, -5]:
		arp_normal.append(pow(1.059463, float(s) / 12.0))
	var arp_fill: Array[float] = []
	for s in [0, 3, 7, 12, 14, 12, 7, 3, 0, 4, 7, 14, 17, 14, 7, 4]:
		arp_fill.append(pow(1.059463, float(s) / 12.0))
	var chord_progression = [
		55.0, 55.0, 55.0, 55.0,
		65.41, 65.41, 65.41, 65.41,
		73.42, 73.42, 73.42, 73.42,
		49.00, 49.00, 49.00, 49.00,
		55.0, 55.0, 55.0, 55.0,
		65.41, 65.41, 65.41, 65.41,
		73.42, 73.42, 73.42, 73.42,
		49.00, 49.00, 49.00, 49.00
	]
	var bpm = 150.0
	var beat_duration = 60.0 / bpm
	var step_duration = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)
		var val = 0.0

		var measure_idx = int(t / (beat_duration * 4.0)) % chord_progression.size()
		var bass_freq = chord_progression[measure_idx]

		var fill_factor = fmod(t, beat_duration * 16.0) / (beat_duration * 16.0)
		var fill_intensity = 1.0
		if fill_factor > 0.85:
			fill_intensity = 1.0 + (fill_factor - 0.85) * 3.0

		if step_idx % 2 == 0:
			var bass_env = maxf(0.0, 1.0 - (step_t / step_duration))
			var bass_wave = 1.0 if sin(TAU * bass_freq * t) > 0 else -1.0
			val += bass_wave * 3000.0 * bass_env

		var is_fill = measure_idx >= 4 and measure_idx < 6
		var arp_arr = arp_fill if is_fill else arp_normal
		var arp_freq = bass_freq * arp_arr[step_idx % arp_arr.size()]
		var arp_env = maxf(0.0, 1.0 - (step_t / (step_duration * 0.8)))
		var arp_wave = 1.0 if fmod(t * arp_freq, 1.0) < 0.25 else -1.0
		val += arp_wave * 2500.0 * arp_env * fill_intensity

		if step_idx % 4 == 0:
			var kick_env = maxf(0.0, 1.0 - (step_t / (step_duration * 1.5)))
			var kick_pitch = lerpf(150.0, 40.0, step_t / (step_duration * 1.5))
			var kick_wave = sin(TAU * kick_pitch * step_t)
			val += kick_wave * 5000.0 * kick_env

		if (step_idx + 4) % 8 == 0:
			var snare_env = maxf(0.0, 1.0 - (step_t / step_duration))
			var noise = rng.randf() * 2.0 - 1.0
			val += noise * 4000.0 * snare_env

		if step_idx % 2 == 1:
			var hat_env = maxf(0.0, 1.0 - (step_t / (step_duration * 0.5)))
			var noise = rng.randf() * 2.0 - 1.0
			val += noise * 1500.0 * hat_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_bunny_hit_stream() -> AudioStreamWAV:
	return _build_stream(0.06, func(t: float, _i: int) -> float:
		var freq = lerpf(1200.0, 600.0, t / 0.06)
		var env = 1.0 - (t / 0.06)
		var val = 5000.0 if sin(TAU * freq * t) >= 0.0 else -5000.0
		return val * env
	)

func _generate_rotor_hit_stream() -> AudioStreamWAV:
	return _build_stream(0.08, func(t: float, _i: int) -> float:
		var freq = lerpf(600.0, 200.0, t / 0.08)
		var env = 1.0 - (t / 0.08)
		var val = 7000.0 if sin(TAU * freq * t) >= 0.0 else -7000.0
		return val * env
	)

func _generate_scav_hit_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 102
	return _build_stream(0.15, func(t: float, _i: int) -> float:
		var freq = lerpf(300.0, 100.0, t / 0.15)
		var amp = lerpf(8000.0, 0.0, t / 0.15)
		return sin(TAU * freq * t) * amp + (rng.randf() * 3000.0 - 1500.0) * (1.0 - t / 0.15)
	)

func _generate_drone_hit_stream() -> AudioStreamWAV:
	return _build_stream(0.1, func(t: float, _i: int) -> float:
		var freq = 1200.0 + sin(t * 200.0) * 400.0
		var env = 1.0 - (t / 0.1)
		var val = 5000.0 if sin(TAU * freq * t) >= 0.0 else -5000.0
		return val * env
	)

func _generate_bunny_death_stream() -> AudioStreamWAV:
	return _build_stream(0.25, func(t: float, _i: int) -> float:
		var freq = lerpf(800.0, 100.0, t / 0.25)
		var amp = lerpf(7000.0, 0.0, t / 0.25)
		return sin(TAU * freq * t) * amp
	)

func _generate_rotor_death_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 103
	return _build_stream(0.4, func(t: float, _i: int) -> float:
		var freq = lerpf(400.0, 50.0, t / 0.4)
		var amp = lerpf(9000.0, 0.0, t / 0.4)
		var val = sin(TAU * freq * t) * amp
		if fmod(t * 30.0, 1.0) < 0.3:
			val += rng.randf() * 4000.0 - 2000.0
		return val
	)

func _generate_scav_death_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 104
	return _build_stream(0.5, func(t: float, _i: int) -> float:
		var amp = lerpf(12000.0, 0.0, t / 0.5)
		var val = rng.randf_range(-amp, amp)
		if t < 0.1:
			val += sin(TAU * 200.0 * t) * 5000.0
		return val
	)

func _generate_drone_death_stream() -> AudioStreamWAV:
	return _build_stream(0.6, func(t: float, _i: int) -> float:
		var freq = lerpf(800.0, 30.0, pow(t / 0.6, 0.5))
		var amp = lerpf(8000.0, 0.0, t / 0.6)
		var val = sin(TAU * freq * t) * amp
		val += sin(TAU * freq * 1.5 * t) * amp * 0.3
		return val
	)

func _generate_lightning_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 105
	return _build_stream(0.5, func(t: float, _i: int) -> float:
		var amp = lerpf(14000.0, 0.0, t / 0.5)
		var val = rng.randf_range(-amp, amp)
		if t < 0.05:
			val += sin(TAU * 2000.0 * t) * 7000.0
		if fmod(t * 15.0, 1.0) < 0.2:
			val += rng.randf() * 5000.0 - 2500.0
		return val
	)

func _generate_crash_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 106
	return _build_stream(0.3, func(t: float, _i: int) -> float:
		var amp = lerpf(11000.0, 0.0, t / 0.3)
		var noise = rng.randf_range(-amp, amp)
		var freq = lerpf(400.0, 80.0, t / 0.3)
		var metal = sin(TAU * freq * t) * amp * 0.5
		return noise + metal
	)

func _generate_bounce_stream() -> AudioStreamWAV:
	return _build_stream(0.1, func(t: float, _i: int) -> float:
		var freq = lerpf(300.0, 600.0, t / 0.1)
		var env = 1.0 - (t / 0.1)
		var val = sin(TAU * freq * t) * 4000.0
		return val * env
	)

func _generate_demo_music_bunny() -> AudioStreamWAV:
	# Bouncy 8-bit victory tune
	var arpeggio = [0, 4, 7, 12, 16, 12, 7, 4]
	var arp_freqs: Array[float] = []
	for s in arpeggio:
		arp_freqs.append(440.0 * _semitone_ratio(s))
	var stream = _build_stream(4.0, func(t: float, _i: int) -> float:
		var step_idx = int(t * 8.0)
		var freq = arp_freqs[step_idx % arp_freqs.size()]
		var wave = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		return wave * 6000.0 * maxf(0.0, 1.0 - fmod(t * 8.0, 1.0))
	)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _generate_demo_music_giant_biker() -> AudioStreamWAV:
	var stream = _build_stream(4.0, func(t: float, _i: int) -> float:
		var step_idx = int(t * 6.0)
		var val = 0.0
		var bass_freq = 65.41 if step_idx % 4 < 2 else 82.41
		val += 7000.0 if sin(TAU * bass_freq * t) >= 0.0 else -7000.0
		if step_idx % 2 == 0:
			var rev = sin(TAU * lerpf(200.0, 30.0, fmod(t * 6.0, 1.0)) * fmod(t * 6.0, 1.0))
			val += rev * 5000.0 * maxf(0.0, 1.0 - fmod(t * 6.0, 1.0) * 2.0)
		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _generate_demo_music_sasquatch() -> AudioStreamWAV:
	# Heavy, lumbering beat
	var stream = _build_stream(4.0, func(t: float, _i: int) -> float:
		var step_idx = int(t * 4.0)
		var freq = 110.0 if step_idx % 2 == 0 else 164.81 # A2 to E3
		var val = sin(TAU * freq * t) * 8000.0
		var step_t = fmod(t * 4.0, 1.0)
		if step_idx % 2 == 0:
			val += sin(TAU * lerpf(100.0, 20.0, step_t) * step_t) * 10000.0 * maxf(0.0, 1.0 - step_t)
		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _generate_demo_music_void_drone() -> AudioStreamWAV:
	# Spacy, pulsing electronic tune
	var stream = _build_stream(4.0, func(t: float, _i: int) -> float:
		var freq = 220.0 + sin(t * TAU * 2.0) * 10.0
		var wave = sin(TAU * freq * t)
		var pulse = sin(TAU * t * 8.0) * 0.5 + 0.5
		return wave * 7000.0 * pulse
	)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _generate_demo_music_war_rig() -> AudioStreamWAV:
	# Epic, intense distorted chords
	var stream = _build_stream(6.0, func(t: float, _i: int) -> float:
		var step = int(t * 2.0)
		var base_freq = 55.0 if step % 4 < 2 else 65.41
		var v1 = 1.0 if fmod(t * base_freq, 1.0) < 0.5 else -1.0
		var v2 = 1.0 if fmod(t * base_freq * 1.5, 1.0) < 0.5 else -1.0
		var v3 = 1.0 if fmod(t * base_freq * 2.0, 1.0) < 0.5 else -1.0
		return (v1 + v2 + v3) * 2500.0
	)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _generate_game_music_bunny() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 301
	var arp_notes = [0, 4, 7, 11, 12, 11, 7, 4]
	var arp_ratios: Array[float] = []
	for s in arp_notes:
		arp_ratios.append(_semitone_ratio(s))
	var chord_progression = [
		65.41, 65.41, 73.42, 73.42,
		82.41, 82.41, 98.00, 98.00
	]
	var bpm = 150.0
	var beat_duration = 60.0 / bpm
	var step_duration = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)
		var val = 0.0

		var measure_idx = int(t / (beat_duration * 4.0)) % chord_progression.size()
		var bass_freq = chord_progression[measure_idx]

		# Bouncy bass line
		if step_idx % 2 == 0:
			var bass_env = maxf(0.0, 1.0 - (step_t / step_duration))
			var bass_wave = 1.0 if sin(TAU * bass_freq * t) > 0 else -1.0
			val += bass_wave * 2500.0 * bass_env

		# Cute arpeggio melody
		var arp_freq = bass_freq * 2.0 * arp_ratios[step_idx % arp_ratios.size()]
		var arp_env = maxf(0.0, 1.0 - (step_t / (step_duration * 0.75)))
		var arp_wave = 1.0 if fmod(t * arp_freq, 1.0) < 0.3 else -1.0
		val += arp_wave * 2000.0 * arp_env

		# Bouncy Kick Drum
		if step_idx % 4 == 0:
			var kick_env = maxf(0.0, 1.0 - (step_t / (step_duration * 1.2)))
			var kick_pitch = lerpf(180.0, 45.0, step_t / (step_duration * 1.2))
			var kick_wave = sin(TAU * kick_pitch * step_t)
			val += kick_wave * 5500.0 * kick_env

		# Snare
		if (step_idx + 4) % 8 == 0:
			var snare_env = maxf(0.0, 1.0 - (step_t / step_duration))
			var noise = rng.randf() * 2.0 - 1.0
			val += noise * 3000.0 * snare_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_biker() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 302
	var chord_progression = [
		49.00, 49.00, 58.27, 58.27,
		41.20, 41.20, 43.65, 43.65
	]
	var bpm = 140.0
	var beat_duration = 60.0 / bpm
	var step_duration = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)
		var val = 0.0

		var measure_idx = int(t / (beat_duration * 4.0)) % chord_progression.size()
		var bass_freq = chord_progression[measure_idx]

		# Heavy distorted bass (sawtooth wave with clipping)
		var saw = fmod(t * bass_freq, 1.0) * 2.0 - 1.0
		var dist_bass = clampf(saw * 3.0, -1.0, 1.0)
		val += dist_bass * 3500.0

		# Metal power chord riffs
		if step_idx % 8 < 6:
			var chord_saw1 = fmod(t * bass_freq * 2.0, 1.0) * 2.0 - 1.0
			var chord_saw2 = fmod(t * bass_freq * 3.0, 1.0) * 2.0 - 1.0
			var chord_dist = clampf((chord_saw1 + chord_saw2) * 2.0, -1.0, 1.0)
			var chord_env = maxf(0.0, 1.0 - (fmod(t, step_duration * 2.0) / (step_duration * 2.0)))
			val += chord_dist * 3000.0 * chord_env

		# Intense Kick Drum
		if step_idx % 4 == 0 or step_idx % 8 == 2:
			var kick_env = maxf(0.0, 1.0 - (step_t / (step_duration * 1.0)))
			var kick_pitch = lerpf(120.0, 30.0, step_t / (step_duration * 1.0))
			var kick_wave = sin(TAU * kick_pitch * step_t)
			val += kick_wave * 6000.0 * kick_env

		# Loud Metal Snare
		if (step_idx + 4) % 8 == 0:
			var snare_env = maxf(0.0, 1.0 - (step_t / (step_duration * 1.5)))
			var noise = rng.randf() * 2.0 - 1.0
			val += noise * 4500.0 * snare_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_sasquatch() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var chord_progression = [
		43.65, 43.65, 49.00, 49.00,
		36.71, 36.71, 38.89, 38.89
	]
	var bpm = 120.0
	var beat_duration = 60.0 / bpm
	var step_duration = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)
		var val = 0.0

		var measure_idx = int(t / (beat_duration * 4.0)) % chord_progression.size()
		var bass_freq = chord_progression[measure_idx]

		# Slow pulsing deep bass
		var bass_env = maxf(0.0, 1.0 - (step_t / (step_duration * 2.0)))
		var bass_wave = sin(TAU * bass_freq * t)
		val += bass_wave * 4000.0 * bass_env

		# Tribal wooden percussion sounds
		if step_idx % 3 == 0:
			var wood_freq = 300.0 + sin(t * 15.0) * 100.0
			var wood_env = maxf(0.0, 1.0 - (step_t / (step_duration * 0.5)))
			var wood_wave = sin(TAU * wood_freq * step_t)
			val += wood_wave * 2500.0 * wood_env

		# Deep thunderous Kick
		if step_idx % 4 == 0:
			var kick_env = maxf(0.0, 1.0 - (step_t / (step_duration * 2.0)))
			var kick_pitch = lerpf(80.0, 20.0, step_t / (step_duration * 2.0))
			var kick_wave = sin(TAU * kick_pitch * step_t)
			val += kick_wave * 7000.0 * kick_env

		# Tribal Shaker
		if step_idx % 2 == 1:
			var shaker_env = maxf(0.0, 1.0 - (step_t / (step_duration * 0.4)))
			var noise = rng.randf() * 2.0 - 1.0
			val += noise * 1800.0 * shaker_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_void() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 304
	var chord_progression = [
		73.42, 73.42, 87.31, 87.31,
		65.41, 65.41, 58.27, 58.27
	]
	var bpm = 135.0
	var beat_duration = 60.0 / bpm
	var step_duration = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)
		var val = 0.0

		var measure_idx = int(t / (beat_duration * 4.0)) % chord_progression.size()
		var bass_freq = chord_progression[measure_idx]

		# Resonance sweeping space wave
		var sweep = sin(TAU * 0.1 * t) * 0.5 + 0.5
		var sweep_freq = lerpf(200.0, 1200.0, sweep)
		var pulse_freq = bass_freq * 4.0
		if sin(TAU * sweep_freq * t) > 0.0:
			var wave = sin(TAU * pulse_freq * t)
			val += wave * 2500.0

		# Deep bass
		var bass_wave = 1.0 if sin(TAU * bass_freq * t) > 0 else -1.0
		var bass_env = maxf(0.0, 1.0 - (step_t / step_duration))
		val += bass_wave * 2500.0 * bass_env

		# Cyber Kick
		if step_idx % 4 == 0:
			var kick_env = maxf(0.0, 1.0 - (step_t / (step_duration * 1.5)))
			var kick_pitch = lerpf(220.0, 40.0, step_t / (step_duration * 1.5))
			var kick_wave = sin(TAU * kick_pitch * step_t)
			val += kick_wave * 5000.0 * kick_env

		# Space snare
		if (step_idx + 4) % 8 == 0:
			var snare_env = maxf(0.0, 1.0 - (step_t / (step_duration * 1.2)))
			var noise = rng.randf() * 2.0 - 1.0
			var snare_wave = noise * 3000.0 + sin(TAU * 180.0 * step_t) * 1500.0
			val += snare_wave * snare_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_outrun() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 305
	var chord_progression: Array[float] = [
		55.00, 55.00, 43.65, 43.65,
		49.00, 49.00, 41.20, 41.20
	]
	var arp_offsets: Array[int] = [0, 7, 12, 15, 19, 15, 12, 7]
	var arp_ratios: Array[float] = []
	for s in arp_offsets:
		arp_ratios.append(_semitone_ratio(s))
	var bpm: float = 128.0
	var beat_duration: float = 60.0 / bpm
	var step_duration: float = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx := int(t / step_duration)
		var step_t := fmod(t, step_duration)
		var measure_idx := int(t / (beat_duration * 4.0)) % chord_progression.size()
		var bass_freq: float = chord_progression[measure_idx]
		var val: float = 0.0

		# Driving 16th-note synthwave bassline
		var saw_bass: float = fmod(t * bass_freq, 1.0) * 2.0 - 1.0
		var bass_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 1.1)))
		val += saw_bass * 3200.0 * bass_env

		# Warm saw pad chord (root + minor third + fifth)
		var pad_1: float = sin(TAU * bass_freq * 2.0 * t)
		var pad_2: float = sin(TAU * bass_freq * 2.0 * _semitone_ratio(3) * t)
		var pad_3: float = sin(TAU * bass_freq * 3.0 * t)
		val += (pad_1 + pad_2 + pad_3) * 900.0

		# Shimmering retro lead arp
		var arp_freq: float = bass_freq * 4.0 * arp_ratios[step_idx % arp_ratios.size()]
		var arp_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 0.9)))
		var arp_wave: float = 1.0 if fmod(t * arp_freq, 1.0) < 0.35 else -1.0
		val += arp_wave * 1800.0 * arp_env

		# Four-on-the-floor kick
		if step_idx % 4 == 0:
			var kick_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 1.4)))
			var kick_pitch: float = lerpf(160.0, 42.0, step_t / (step_duration * 1.4))
			val += sin(TAU * kick_pitch * step_t) * 5200.0 * kick_env

		# Gated 80s snare on 2 and 4
		if step_idx % 8 == 4:
			var snare_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 1.6)))
			val += (rng.randf() * 2.0 - 1.0) * 3800.0 * snare_env

		# Off-beat crisp hi-hat
		if step_idx % 4 == 2:
			var hat_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 0.45)))
			val += (rng.randf() * 2.0 - 1.0) * 1600.0 * hat_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_industrial() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 306
	var bass_pattern: Array[float] = [41.20, 41.20, 46.25, 41.20, 49.00, 41.20, 38.89, 43.65]
	var bpm: float = 155.0
	var beat_duration: float = 60.0 / bpm
	var step_duration: float = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx := int(t / step_duration)
		var step_t := fmod(t, step_duration)
		var bass_freq: float = bass_pattern[(step_idx / 4) % bass_pattern.size()]
		var val: float = 0.0

		# Aggressive FM-distorted cyber bass
		var mod_sig: float = sin(TAU * bass_freq * 3.0 * t) * 2.5
		var fm_bass: float = clampf(sin(TAU * bass_freq * t + mod_sig) * 2.2, -1.0, 1.0)
		var bass_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 0.85)))
		val += fm_bass * 3600.0 * bass_env

		# Syncopated metallic industrial clang
		if step_idx % 6 == 0 or step_idx % 16 == 10:
			var clang_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 1.2)))
			var clang: float = sin(TAU * 420.0 * step_t) * sin(TAU * 673.0 * step_t)
			val += clang * 3400.0 * clang_env

		# Relentless industrial kick
		if step_idx % 4 == 0 or step_idx % 16 == 14:
			var kick_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 1.1)))
			var kick_pitch: float = lerpf(190.0, 34.0, step_t / (step_duration * 1.1))
			val += sin(TAU * kick_pitch * step_t) * 5800.0 * kick_env

		# Crunch snare
		if (step_idx + 4) % 8 == 0:
			var snare_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 1.3)))
			val += (rng.randf() * 2.0 - 1.0) * 4200.0 * snare_env

		# Double-time hi-hat tick
		var hat_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 0.35)))
		val += (rng.randf() * 2.0 - 1.0) * 1400.0 * hat_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_neon_drift() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 307
	var chord_progression: Array[float] = [
		65.41, 65.41, 73.42, 73.42,
		87.31, 87.31, 73.42, 98.00
	]
	var pentatonic: Array[int] = [0, 3, 5, 7, 10, 12, 10, 7]
	var lead_ratios: Array[float] = []
	for s in pentatonic:
		lead_ratios.append(_semitone_ratio(s))
	var bpm: float = 132.0
	var beat_duration: float = 60.0 / bpm
	var step_duration: float = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx := int(t / step_duration)
		var step_t := fmod(t, step_duration)
		var measure_idx := int(t / (beat_duration * 4.0)) % chord_progression.size()
		var bass_freq: float = chord_progression[measure_idx]
		var val: float = 0.0

		# Bouncy off-beat sub-bass
		if step_idx % 2 == 1:
			var bass_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 1.1)))
			val += sin(TAU * bass_freq * t) * 3400.0 * bass_env

		# Melodic pentatonic arcade lead
		var lead_freq: float = bass_freq * 4.0 * lead_ratios[(step_idx / 2) % lead_ratios.size()]
		var lead_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 1.4)))
		var lead_wave: float = (fmod(t * lead_freq, 1.0) * 2.0 - 1.0) * 0.5 + (1.0 if sin(TAU * lead_freq * t) > 0.0 else -1.0) * 0.5
		val += lead_wave * 2400.0 * lead_env

		# Punchy kick
		if step_idx % 4 == 0:
			var kick_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 1.3)))
			var kick_pitch: float = lerpf(170.0, 45.0, step_t / (step_duration * 1.3))
			val += sin(TAU * kick_pitch * step_t) * 5200.0 * kick_env

		# Snappy clap/snare
		if step_idx % 8 == 4:
			var clap_env: float = maxf(0.0, 1.0 - (step_t / (step_duration * 0.9)))
			val += (rng.randf() * 2.0 - 1.0) * 3500.0 * clap_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_synthetic_chase() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 308
	var bass_pattern: Array[float] = [55.00, 55.00, 65.41, 65.41, 73.42, 73.42, 82.41, 82.41]
	var arp_offsets: Array[int] = [0, 4, 7, 12, 16, 12, 7, 4]
	var arp_ratios: Array[float] = []
	for s in arp_offsets:
		arp_ratios.append(_semitone_ratio(s))
	var bpm: float = 145.0
	var beat_duration: float = 60.0 / bpm
	var step_duration: float = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx := int(t / step_duration)
		var step_t := fmod(t, step_duration)
		var measure_idx := int(t / (beat_duration * 4.0)) % bass_pattern.size()
		var bass_freq: float = bass_pattern[measure_idx]
		var val: float = 0.0

		# Driving synthwave bass with pulse-width sweep
		var pulse_width := 0.5 + 0.3 * sin(TAU * 0.25 * t)
		var saw := fmod(t * bass_freq, 1.0)
		var bass_wave := 1.0 if saw < pulse_width else -1.0
		var bass_env := maxf(0.0, 1.0 - (step_t / (step_duration * 1.05)))
		val += bass_wave * 3400.0 * bass_env

		# Bright arcade lead
		var lead_freq := bass_freq * 4.0 * arp_ratios[step_idx % arp_ratios.size()]
		var lead_env := maxf(0.0, 1.0 - (step_t / (step_duration * 0.85)))
		var lead_wave := (fmod(t * lead_freq, 1.0) * 2.0 - 1.0) * 0.6 + (1.0 if sin(TAU * lead_freq * t) > 0.0 else -1.0) * 0.4
		val += lead_wave * 2200.0 * lead_env

		# Tight kick
		if step_idx % 4 == 0:
			var kick_env := maxf(0.0, 1.0 - (step_t / (step_duration * 1.2)))
			var kick_pitch := lerpf(180.0, 45.0, step_t / (step_duration * 1.2))
			val += sin(TAU * kick_pitch * step_t) * 5400.0 * kick_env

		# Snappy snare
		if step_idx % 8 == 4:
			var snare_env := maxf(0.0, 1.0 - (step_t / (step_duration * 0.9)))
			val += (rng.randf() * 2.0 - 1.0) * 3600.0 * snare_env

		# Crisp hi-hat
		if step_idx % 2 == 1:
			var hat_env := maxf(0.0, 1.0 - (step_t / (step_duration * 0.4)))
			val += (rng.randf() * 2.0 - 1.0) * 1500.0 * hat_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_synthwave_chase() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 310
	var chord_roots: Array[float] = [110.00, 87.31, 98.00, 82.41]
	var arp_offsets: Array[int] = [0, 7, 12, 15, 19, 15, 12, 7]
	var arp_ratios: Array[float] = []
	for s in arp_offsets:
		arp_ratios.append(_semitone_ratio(s))
	var bpm: float = 118.0
	var beat_duration: float = 60.0 / bpm
	var step_duration: float = beat_duration / 4.0

	var stream := _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx := int(t / step_duration)
		var step_t := fmod(t, step_duration)
		var measure_idx := int(t / (beat_duration * 4.0)) % chord_roots.size()
		var root: float = chord_roots[measure_idx]
		var val: float = 0.0

		# Wide detuned pad, gated on each bar.
		var pad_gate: float = 0.4 + 0.6 * maxf(0.0, 1.0 - step_t / (step_duration * 8.0))
		val += (sin(TAU * root * t) + sin(TAU * root * _semitone_ratio(7) * t * 1.003)) * 1500.0 * pad_gate

		# Pumping off-beat bass.
		if step_idx % 2 == 1:
			var bass_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 1.4))
			var bass_wave: float = 1.0 if fmod(t * root * 0.5, 1.0) < 0.45 else -1.0
			val += bass_wave * 3600.0 * bass_env

		# Fast gated arpeggio.
		var lead_freq: float = root * 2.0 * arp_ratios[step_idx % arp_ratios.size()]
		var lead_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 0.7))
		val += sin(TAU * lead_freq * t) * 1900.0 * lead_env

		# Four-on-the-floor kick and reverse-swell snare.
		if step_idx % 4 == 0:
			var kick_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 1.4))
			var kick_pitch: float = lerpf(160.0, 42.0, step_t / (step_duration * 1.4))
			val += sin(TAU * kick_pitch * step_t) * 5200.0 * kick_env
		if step_idx % 8 == 4:
			var snare_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 1.1))
			val += (rng.randf() * 2.0 - 1.0) * 3400.0 * snare_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_cyberpunk_boss() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	var drone_roots: Array[float] = [55.00, 58.27, 49.00, 51.91]
	var stab_offsets: Array[int] = [0, 1, 6, 12]
	var stab_ratios: Array[float] = []
	for s in stab_offsets:
		stab_ratios.append(_semitone_ratio(s))
	var bpm: float = 160.0
	var beat_duration: float = 60.0 / bpm
	var step_duration: float = beat_duration / 4.0

	var stream := _build_stream(16.0, func(t: float, _i: int) -> float:
		var step_idx := int(t / step_duration)
		var step_t := fmod(t, step_duration)
		var measure_idx := int(t / (beat_duration * 4.0)) % drone_roots.size()
		var root: float = drone_roots[measure_idx]
		var val: float = 0.0

		# Grinding distorted bass (folded saw).
		var saw: float = fmod(t * root, 1.0) * 2.0 - 1.0
		var distorted: float = clampf(saw * 2.6, -1.0, 1.0)
		var bass_env: float = 0.7 + 0.3 * maxf(0.0, 1.0 - step_t / (step_duration * 1.2))
		val += distorted * 2900.0 * bass_env

		# Dissonant stab hits.
		if step_idx % 8 == 0 or step_idx % 8 == 6:
			var stab_freq: float = root * 4.0 * stab_ratios[(step_idx / 8) % stab_ratios.size()]
			var stab_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 2.0))
			val += (sin(TAU * stab_freq * t) + sin(TAU * stab_freq * 1.0595 * t)) * 1700.0 * stab_env

		# Triple-kick pattern and metallic noise.
		if step_idx % 4 == 0 or step_idx % 4 == 3:
			var kick_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 0.8))
			var kick_pitch: float = lerpf(210.0, 48.0, step_t / (step_duration * 0.8))
			val += sin(TAU * kick_pitch * step_t) * 5000.0 * kick_env
		if step_idx % 2 == 1:
			var hat_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 0.35))
			val += (rng.randf() * 2.0 - 1.0) * 1800.0 * hat_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

func _generate_game_music_ambient_highway() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 309
	var drone_freqs: Array[float] = [55.00, 65.41, 73.42, 49.00]
	var bpm: float = 90.0
	var beat_duration: float = 60.0 / bpm
	var step_duration: float = beat_duration / 4.0

	var stream = _build_stream(16.0, func(t: float, _i: int) -> float:
		var measure_idx := int(t / (beat_duration * 8.0)) % drone_freqs.size()
		var bass_freq: float = drone_freqs[measure_idx]
		var val: float = 0.0

		# Slow evolving ambient pad (detuned sine cluster)
		var pad1 := sin(TAU * bass_freq * t)
		var pad2 := sin(TAU * bass_freq * _semitone_ratio(7) * t)
		var pad3 := sin(TAU * bass_freq * _semitone_ratio(12) * t)
		var pad_env := 0.5 + 0.5 * sin(TAU * 0.08 * t)
		val += (pad1 + pad2 + pad3) * 1800.0 * pad_env

		# Gentle pluck arpeggio
		var step_idx := int(t / step_duration)
		var step_t := fmod(t, step_duration)
		var pluck_freq := bass_freq * 4.0 * _semitone_ratio([0, 7, 12, 19][step_idx % 4])
		var pluck_env := maxf(0.0, 1.0 - (step_t / (step_duration * 1.6)))
		val += sin(TAU * pluck_freq * t) * 1400.0 * pluck_env

		# Soft heartbeat kick
		if step_idx % 8 == 0:
			var kick_env := maxf(0.0, 1.0 - (step_t / (step_duration * 2.0)))
			var kick_pitch := lerpf(90.0, 30.0, step_t / (step_duration * 2.0))
			val += sin(TAU * kick_pitch * step_t) * 3200.0 * kick_env

		# Gentle noise wash
		val += (rng.randf() * 2.0 - 1.0) * 300.0 * (0.4 + 0.6 * sin(TAU * 0.12 * t))

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 16.0)
	return stream

# Layered adaptive stems: 0 = drums, 1 = bass, 2 = melody, 3 = intensity.
# Each stem is a short deterministic loop; intensity mixes change which layers
# are audible, so the music can grow without restarting a separate track.
func _generate_adaptive_stem(stem: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + stem
	var roots: Array[float] = [55.00, 65.41, 73.42, 82.41]
	var offsets: Array[int] = [0, 3, 7, 10, 12, 10, 7, 3]
	var ratios: Array[float] = []
	for s in offsets:
		ratios.append(_semitone_ratio(s))
	var bpm: float = 128.0
	var beat_duration: float = 60.0 / bpm
	var step_duration: float = beat_duration / 4.0

	var stream := _build_stream(4.0, func(t: float, _i: int) -> float:
		var step_idx := int(t / step_duration)
		var step_t := fmod(t, step_duration)
		var measure_idx := int(t / (beat_duration * 4.0)) % roots.size()
		var root: float = roots[measure_idx]
		var val: float = 0.0
		match stem:
			0: # drums
				if step_idx % 4 == 0:
					var kick_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 1.3))
					var kick_pitch: float = lerpf(175.0, 44.0, step_t / (step_duration * 1.3))
					val += sin(TAU * kick_pitch * step_t) * 5200.0 * kick_env
				if step_idx % 8 == 4:
					var snare_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 0.8))
					val += (rng.randf() * 2.0 - 1.0) * 3000.0 * snare_env
				if step_idx % 2 == 1:
					var hat_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 0.3))
					val += (rng.randf() * 2.0 - 1.0) * 1100.0 * hat_env
			1: # sub bass
				var bass_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 1.1))
				val += sin(TAU * root * t) * 3600.0 * bass_env
			2: # melodic arpeggio
				var lead_freq: float = root * 4.0 * ratios[step_idx % ratios.size()]
				var lead_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 1.2))
				val += sin(TAU * lead_freq * t) * 2100.0 * lead_env
			3: # intensity layer: fast detuned saw pulse
				var pulse_freq: float = root * 8.0
				var saw: float = fmod(t * pulse_freq, 1.0) * 2.0 - 1.0
				var intensity_env: float = maxf(0.0, 1.0 - step_t / (step_duration * 0.9))
				val += (saw + sin(TAU * pulse_freq * 1.007 * t)) * 1500.0 * intensity_env
		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(SAMPLE_RATE * 4.0)
	return stream

func _build_adaptive_music() -> AudioStreamInteractive:
	var stems: Array[AudioStreamWAV] = []
	for i in ADAPTIVE_STEM_COUNT:
		stems.append(_generate_adaptive_stem(i))

	var clip_names: Array[StringName] = [&"Cruise", &"Chase", &"Overdrive", &"Boss"]
	# Per-clip stem volumes in dB: [drums, bass, melody, intensity].
	var mixes: Array = [
		[-12.0, -6.0, -10.0, -60.0],
		[-6.0, -3.0, -6.0, -22.0],
		[-2.0, 0.0, -3.0, -9.0],
		[0.0, 1.0, -1.0, -2.0],
	]
	var interactive := AudioStreamInteractive.new()
	interactive.clip_count = ADAPTIVE_CLIP_COUNT
	for clip_idx in ADAPTIVE_CLIP_COUNT:
		var synced := AudioStreamSynchronized.new()
		synced.stream_count = ADAPTIVE_STEM_COUNT
		for stem_idx in ADAPTIVE_STEM_COUNT:
			synced.set_sync_stream(stem_idx, stems[stem_idx])
			synced.set_sync_stream_volume(stem_idx, float(mixes[clip_idx][stem_idx]))
		interactive.set_clip_stream(clip_idx, synced)
		interactive.set_clip_name(clip_idx, clip_names[clip_idx])

	interactive.initial_clip = 0
	for from_idx in ADAPTIVE_CLIP_COUNT:
		for to_idx in ADAPTIVE_CLIP_COUNT:
			if from_idx == to_idx:
				continue
			interactive.add_transition(
				from_idx,
				to_idx,
				AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR,
				AudioStreamInteractive.TRANSITION_TO_TIME_SAME_POSITION,
				AudioStreamInteractive.FADE_CROSS,
				2.0
			)
	return interactive

func _generate_all_async() -> void:
	_async_tasks["menu_music"] = WorkerThreadPool.add_task(func(): _stream_menu_music = _generate_menu_music())
	
	_async_tasks["game_music_bunny"] = WorkerThreadPool.add_task(func(): _stream_game_music_bunny = _generate_game_music_bunny())
	_async_tasks["game_music_biker"] = WorkerThreadPool.add_task(func(): _stream_game_music_biker = _generate_game_music_biker())
	_async_tasks["game_music_sasquatch"] = WorkerThreadPool.add_task(func(): _stream_game_music_sasquatch = _generate_game_music_sasquatch())
	_async_tasks["game_music_void"] = WorkerThreadPool.add_task(func(): _stream_game_music_void = _generate_game_music_void())
	_async_tasks["game_music_classic"] = WorkerThreadPool.add_task(func(): _stream_game_music_classic = _generate_game_music())
	_async_tasks["game_music_outrun"] = WorkerThreadPool.add_task(func(): _stream_game_music_outrun = _generate_game_music_outrun())
	_async_tasks["game_music_industrial"] = WorkerThreadPool.add_task(func(): _stream_game_music_industrial = _generate_game_music_industrial())
	_async_tasks["game_music_neon_drift"] = WorkerThreadPool.add_task(func(): _stream_game_music_neon_drift = _generate_game_music_neon_drift())
	_async_tasks["game_music_synthetic_chase"] = WorkerThreadPool.add_task(func(): _stream_game_music_synthetic_chase = _generate_game_music_synthetic_chase())
	_async_tasks["game_music_synthwave_chase"] = WorkerThreadPool.add_task(func(): _stream_game_music_synthwave_chase = _generate_game_music_synthwave_chase())
	_async_tasks["game_music_cyberpunk_boss"] = WorkerThreadPool.add_task(func(): _stream_game_music_cyberpunk_boss = _generate_game_music_cyberpunk_boss())
	_async_tasks["game_music_ambient_highway"] = WorkerThreadPool.add_task(func(): _stream_game_music_ambient_highway = _generate_game_music_ambient_highway())
	
	_async_tasks["demo_boss_bunny"] = WorkerThreadPool.add_task(func(): _stream_demo_boss_bunny = _generate_demo_music_bunny())
	_async_tasks["demo_boss_giant_biker"] = WorkerThreadPool.add_task(func(): _stream_demo_boss_giant_biker = _generate_demo_music_giant_biker())
	_async_tasks["demo_boss_sasquatch"] = WorkerThreadPool.add_task(func(): _stream_demo_boss_sasquatch = _generate_demo_music_sasquatch())
	_async_tasks["demo_boss_void_drone"] = WorkerThreadPool.add_task(func(): _stream_demo_boss_void_drone = _generate_demo_music_void_drone())
	_async_tasks["demo_boss_war_rig"] = WorkerThreadPool.add_task(func(): _stream_demo_boss_war_rig = _generate_demo_music_war_rig())

func _wait_for_task(key: String) -> void:
	if _async_tasks.has(key):
		var task_id = _async_tasks[key]
		WorkerThreadPool.wait_for_task_completion(task_id)
		_async_tasks.erase(key)

func _exit_tree() -> void:
	var keys = _async_tasks.keys()
	for key in keys:
		_wait_for_task(key)
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null
	for p in sfx_players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	if is_instance_valid(polyphonic_player):
		polyphonic_player.stop()
		polyphonic_player.stream = null
	_polyphonic_playback = null
	_polyphonic_stream = null
	_custom_playlist.clear()
	_adaptive_music = null
	_stream_laser = null
	_stream_laser_randomizer = null
	_stream_explosion_randomizer = null
	_stream_hurt_randomizer = null
	_stream_hit_randomizer = null
	_stream_death_randomizer = null
	_stream_explosion = null
	_stream_hurt = null
	_stream_boost = null
	_stream_emp = null
	_stream_menu_music = null
	_stream_game_music_bunny = null
	_stream_game_music_biker = null
	_stream_game_music_sasquatch = null
	_stream_game_music_void = null
	_stream_game_music_classic = null
	_stream_game_music_outrun = null
	_stream_game_music_industrial = null
	_stream_game_music_neon_drift = null
	_stream_game_music_synthetic_chase = null
	_stream_game_music_synthwave_chase = null
	_stream_game_music_cyberpunk_boss = null
	_stream_game_music_ambient_highway = null
	_stream_crash = null
	_stream_bounce = null
	_stream_bunny_hit = null
	_stream_rotor_hit = null
	_stream_scav_hit = null
	_stream_drone_hit = null
	_stream_bunny_death = null
	_stream_rotor_death = null
	_stream_scav_death = null
	_stream_drone_death = null
	_stream_lightning = null
	_stream_demo_boss_bunny = null
	_stream_demo_boss_sasquatch = null
	_stream_demo_boss_giant_biker = null
	_stream_demo_boss_void_drone = null
	_stream_demo_boss_war_rig = null

