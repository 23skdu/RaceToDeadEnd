extends "res://scripts/autoload/AudioManagerStreams.gd"

enum Bus { MASTER = 0, MUSIC = 1, SFX = 2 }

var music_player: AudioStreamPlayer
var car_engine_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer2D] = []
const SFX_PLAYER_COUNT: int = 16
const CAR_ENGINE_VOLUME_DB: float = -18.0

const POLYPHONIC_VOICES: int = 48
const SFX_RANDOMIZER_VARIANTS: int = 3
const DEFAULT_MUSIC_TRACK: String = "dynamic"

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
var _stream_car_engine: AudioStreamWAV
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

var selected_music_track: String = DEFAULT_MUSIC_TRACK
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
var _web_audio_unlocked: bool = false

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

	# The car has its own loop on the SFX bus so changing or restarting the
	# soundtrack never cuts engine audio, and the SFX volume slider still owns it.
	car_engine_player = AudioStreamPlayer.new()
	car_engine_player.bus = "SFX"
	car_engine_player.name = "CarEnginePlayer"
	car_engine_player.volume_db = CAR_ENGINE_VOLUME_DB
	add_child(car_engine_player)

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
	# The menu asks for music immediately. Generate it on the main thread so it
	# never depends on WorkerThreadPool availability or a slow background task,
	# both of which can leave the Web menu silent.
	_stream_menu_music = _generate_menu_music()
	_generate_all_async()

# Web browsers keep their audio context suspended until a real user gesture.
# The engine resumes the context for us, but a music stream started before that
# gesture can remain silent. Restart it once on the first press so menu and
# gameplay soundtracks are actually audible.
func _input(event: InputEvent) -> void:
	if not OS.has_feature("web") or _web_audio_unlocked:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventJoypadButton:
		pressed = event.pressed
	if not pressed:
		return
	_web_audio_unlocked = true
	restart_music()

func restart_music() -> void:
	if is_instance_valid(music_player) and music_player.stream:
		music_player.play()

func start_car_audio() -> void:
	if not is_instance_valid(car_engine_player):
		return
	if not _stream_car_engine:
		_stream_car_engine = _generate_car_engine()
	if car_engine_player.stream != _stream_car_engine:
		car_engine_player.stream = _stream_car_engine
	if not car_engine_player.playing:
		car_engine_player.play()

func stop_car_audio() -> void:
	if is_instance_valid(car_engine_player):
		car_engine_player.stop()

func _on_sfx_finished(player_idx: int) -> void:
	if player_idx < _player_priorities.size():
		_player_priorities[player_idx] = 0

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

func _ensure_polyphonic_playback() -> AudioStreamPlaybackPolyphonic:
	if _polyphonic_playback != null:
		return _polyphonic_playback
	if not is_instance_valid(polyphonic_player):
		return null
	if polyphonic_player.stream != _polyphonic_stream:
		polyphonic_player.stream = _polyphonic_stream
	if not polyphonic_player.playing:
		polyphonic_player.play()
	_polyphonic_playback = polyphonic_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	return _polyphonic_playback

func is_polyphonic_sfx_active() -> bool:
	return _feature_enabled(FEATURE_POLYPHONIC_SFX, false) and is_instance_valid(polyphonic_player) and _polyphonic_stream != null

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
	var target := track_id if is_valid_music_track(track_id) else DEFAULT_MUSIC_TRACK
	selected_music_track = target
	if SettingsManager and SettingsManager.has_method("set_music_track"):
		SettingsManager.set_music_track(target)
	if preview and _custom_playlist.is_empty():
		var in_gameplay := false
		if GameManager:
			in_gameplay = GameManager.state == GameManager.GameState.PLAYING or GameManager.state == GameManager.GameState.PAUSED
		if target == DEFAULT_MUSIC_TRACK:
			if in_gameplay:
				play_game_music()
			else:
				play_menu_music()
		else:
			play_music_track(target)

func play_music_track(track_id: String) -> void:
	var stream := _resolve_track_stream(track_id)
	if stream and (music_player.stream != stream or not music_player.playing):
		play_music(stream)

func _resolve_track_stream(track_id: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV
	match track_id:
		"outrun":
			_wait_for_task("game_music_outrun")
			if not _stream_game_music_outrun:
				_stream_game_music_outrun = _generate_game_music_outrun()
			stream = _stream_game_music_outrun
		"industrial":
			_wait_for_task("game_music_industrial")
			if not _stream_game_music_industrial:
				_stream_game_music_industrial = _generate_game_music_industrial()
			stream = _stream_game_music_industrial
		"neon_drift":
			_wait_for_task("game_music_neon_drift")
			if not _stream_game_music_neon_drift:
				_stream_game_music_neon_drift = _generate_game_music_neon_drift()
			stream = _stream_game_music_neon_drift
		"synthetic_chase":
			_wait_for_task("game_music_synthetic_chase")
			if not _stream_game_music_synthetic_chase:
				_stream_game_music_synthetic_chase = _generate_game_music_synthetic_chase()
			stream = _stream_game_music_synthetic_chase
		"synthwave_chase":
			_wait_for_task("game_music_synthwave_chase")
			if not _stream_game_music_synthwave_chase:
				_stream_game_music_synthwave_chase = _generate_game_music_synthwave_chase()
			stream = _stream_game_music_synthwave_chase
		"cyberpunk_boss":
			_wait_for_task("game_music_cyberpunk_boss")
			if not _stream_game_music_cyberpunk_boss:
				_stream_game_music_cyberpunk_boss = _generate_game_music_cyberpunk_boss()
			stream = _stream_game_music_cyberpunk_boss
		"ambient_highway":
			_wait_for_task("game_music_ambient_highway")
			if not _stream_game_music_ambient_highway:
				_stream_game_music_ambient_highway = _generate_game_music_ambient_highway()
			stream = _stream_game_music_ambient_highway
		"classic":
			_wait_for_task("game_music_classic")
			if not _stream_game_music_classic:
				_stream_game_music_classic = _generate_game_music()
			stream = _stream_game_music_classic
		"bunny":
			_wait_for_task("game_music_bunny")
			if not _stream_game_music_bunny:
				_stream_game_music_bunny = _generate_game_music_bunny()
			stream = _stream_game_music_bunny
		"biker":
			_wait_for_task("game_music_biker")
			if not _stream_game_music_biker:
				_stream_game_music_biker = _generate_game_music_biker()
			stream = _stream_game_music_biker
		"sasquatch":
			_wait_for_task("game_music_sasquatch")
			if not _stream_game_music_sasquatch:
				_stream_game_music_sasquatch = _generate_game_music_sasquatch()
			stream = _stream_game_music_sasquatch
		"void":
			_wait_for_task("game_music_void")
			if not _stream_game_music_void:
				_stream_game_music_void = _generate_game_music_void()
			stream = _stream_game_music_void
	return stream

func play_menu_music() -> void:
	if not _custom_playlist.is_empty():
		return
	stop_car_audio()
	_wait_for_task("menu_music")
	if not _stream_menu_music:
		_stream_menu_music = _generate_menu_music()
	if music_player.stream != _stream_menu_music or not music_player.playing:
		play_music(_stream_menu_music)

func play_game_music() -> void:
	start_car_audio()
	if not _custom_playlist.is_empty():
		if not music_player.playing:
			_play_current_playlist_track()
		return
	if selected_music_track != DEFAULT_MUSIC_TRACK:
		var selected_stream := _resolve_track_stream(selected_music_track)
		if selected_stream and (music_player.stream != selected_stream or not music_player.playing):
			play_music(selected_stream)
		return
	# The default gameplay soundtrack is the adaptive mix. Start it here so a new
	# run has music immediately; the stage-based stream below is the fallback for
	# players who disable adaptive music.
	if _feature_enabled(FEATURE_ADAPTIVE_MUSIC, true):
		var boss_active := bool(GameManager.boss_active) if GameManager else false
		var tier := clampi(int(GameManager.difficulty_tier), 0, 20) if GameManager else 0
		set_music_intensity(boss_active, tier, 0.0)
		if music_player.stream == get_adaptive_music_stream() and music_player.playing:
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
		
	if music_player.stream != stream or not music_player.playing:
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
	if selected_music_track != DEFAULT_MUSIC_TRACK:
		return
	var target := _select_adaptive_clip(boss_active, tier, density)
	var prev_clip := _adaptive_clip_index
	_adaptive_clip_index = target
	var stream := get_adaptive_music_stream()
	var started_now := false
	if music_player.stream != stream or not music_player.playing:
		play_music(stream)
		started_now = true
	if started_now or target != prev_clip:
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
		var pb := _ensure_polyphonic_playback()
		if pb != null:
			polyphonic_player.global_position = pos
			var voice_id := pb.play_stream(
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

func _generate_all_async() -> void:
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

func stop_all_audio() -> void:
	var keys = _async_tasks.keys()
	for key in keys:
		_wait_for_task(key)
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null
	if is_instance_valid(car_engine_player):
		car_engine_player.stop()
		car_engine_player.stream = null
	for i in sfx_players.size():
		var p = sfx_players[i]
		if is_instance_valid(p):
			p.stop()
			p.stream = null
		if i < _player_priorities.size():
			_player_priorities[i] = 0
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
	_stream_car_engine = null
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

func _exit_tree() -> void:
	stop_all_audio()


