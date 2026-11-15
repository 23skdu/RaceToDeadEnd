extends Node

enum Bus { MASTER = 0, MUSIC = 1, SFX = 2 }

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer2D] = []
const SFX_PLAYER_COUNT: int = 16

const SAMPLE_RATE: float = 22050.0

var _stream_laser: AudioStreamWAV
var _stream_explosion: AudioStreamWAV
var _stream_hurt: AudioStreamWAV
var _stream_boost: AudioStreamWAV
var _stream_emp: AudioStreamWAV
var _stream_menu_music: AudioStreamWAV
var _stream_game_music_bunny: AudioStreamWAV
var _stream_game_music_biker: AudioStreamWAV
var _stream_game_music_sasquatch: AudioStreamWAV
var _stream_game_music_void: AudioStreamWAV
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

	_setup_audio_buses()
	_generate_all_async()

func _on_sfx_finished(player_idx: int) -> void:
	if player_idx < _player_priorities.size():
		_player_priorities[player_idx] = 0

func _setup_audio_buses() -> void:
	for i in AudioServer.bus_count:
		var bus_name = AudioServer.get_bus_name(i)
		if bus_name == "SFX":
			var fx_count = AudioServer.get_bus_effect_count(i)
			if fx_count == 0:
				var reverb = AudioEffectReverb.new()
				reverb.room_size = 0.25
				reverb.damping = 0.5
				reverb.wet = 0.15
				reverb.dry = 1.0
				AudioServer.add_bus_effect(i, reverb)
		if bus_name == "Master":
			var fx_count = AudioServer.get_bus_effect_count(i)
			if fx_count == 0:
				var compressor = AudioEffectCompressor.new()
				compressor.threshold = -6.0
				compressor.ratio = 3.0
				compressor.gain = 1.0
				AudioServer.add_bus_effect(i, compressor)



func _build_16bit_stream(duration: float, generator: Callable) -> AudioStreamWAV:
	var num_samples = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var sample = generator.call(i / SAMPLE_RATE, i)
		var clamped = clampi(int(sample), -32768, 32767)
		data.encode_s16(i * 2, clamped)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.data = data
	return stream

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
	AudioServer.set_bus_volume_db(bus, volume_db)

func play_synth_laser(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_laser:
		_stream_laser = _generate_laser_stream()
	play_sfx(_stream_laser, pos)

func play_synth_explosion(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_explosion:
		_stream_explosion = _generate_explosion_stream()
	play_sfx(_stream_explosion, pos)

func play_synth_hurt() -> void:
	if not _stream_hurt:
		_stream_hurt = _generate_hurt_stream()
	play_sfx(_stream_hurt, Vector2.ZERO)

func play_synth_boost() -> void:
	if not _stream_boost:
		_stream_boost = _generate_boost_stream()
	play_sfx(_stream_boost, Vector2.ZERO)

func play_synth_emp(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_emp:
		_stream_emp = _generate_emp_stream()
	play_sfx(_stream_emp, pos)

func play_bunny_hit(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_bunny_hit:
		_stream_bunny_hit = _generate_bunny_hit_stream()
	play_sfx(_stream_bunny_hit, pos)

func play_rotor_hit(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_rotor_hit:
		_stream_rotor_hit = _generate_rotor_hit_stream()
	play_sfx(_stream_rotor_hit, pos)

func play_scav_hit(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_scav_hit:
		_stream_scav_hit = _generate_scav_hit_stream()
	play_sfx(_stream_scav_hit, pos)

func play_drone_hit(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_drone_hit:
		_stream_drone_hit = _generate_drone_hit_stream()
	play_sfx(_stream_drone_hit, pos)

func play_bunny_death(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_bunny_death:
		_stream_bunny_death = _generate_bunny_death_stream()
	play_sfx(_stream_bunny_death, pos)

func play_rotor_death(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_rotor_death:
		_stream_rotor_death = _generate_rotor_death_stream()
	play_sfx(_stream_rotor_death, pos)

func play_scav_death(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_scav_death:
		_stream_scav_death = _generate_scav_death_stream()
	play_sfx(_stream_scav_death, pos)

func play_drone_death(pos: Vector2 = Vector2.ZERO) -> void:
	if not _stream_drone_death:
		_stream_drone_death = _generate_drone_death_stream()
	play_sfx(_stream_drone_death, pos)

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

# =================Procedural 16-bit Synthesizer Stream Generators=================

func _generate_laser_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.12, func(t: float, _i: int) -> float:
		var freq = lerpf(800.0, 150.0, t / 0.12)
		return 6000.0 if sin(TAU * freq * t) >= 0.0 else -6000.0
	)

func _generate_explosion_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	return _build_16bit_stream(0.35, func(t: float, _i: int) -> float:
		var amp = lerpf(12000.0, 0.0, t / 0.35)
		return rng.randf_range(-amp, amp)
	)

func _generate_hurt_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.2, func(t: float, _i: int) -> float:
		var freq = lerpf(180.0, 45.0, t / 0.2)
		return 9000.0 if sin(TAU * freq * t) >= 0.0 else -9000.0
	)

func _generate_boost_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.4, func(t: float, _i: int) -> float:
		var freq = lerpf(250.0, 850.0, t / 0.4)
		return 5000.0 if sin(TAU * freq * t) >= 0.0 else -5000.0
	)

func _generate_emp_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.6, func(t: float, _i: int) -> float:
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

	var stream = _build_16bit_stream(16.0, func(t: float, _i: int) -> float:
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
	stream.loop_end = int(22050.0 * 16.0)
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

	var stream = _build_16bit_stream(16.0, func(t: float, _i: int) -> float:
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
	stream.loop_end = int(22050.0 * 16.0)
	return stream

func _generate_bunny_hit_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.06, func(t: float, _i: int) -> float:
		var freq = lerpf(1200.0, 600.0, t / 0.06)
		var env = 1.0 - (t / 0.06)
		var val = 5000.0 if sin(TAU * freq * t) >= 0.0 else -5000.0
		return val * env
	)

func _generate_rotor_hit_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.08, func(t: float, _i: int) -> float:
		var freq = lerpf(600.0, 200.0, t / 0.08)
		var env = 1.0 - (t / 0.08)
		var val = 7000.0 if sin(TAU * freq * t) >= 0.0 else -7000.0
		return val * env
	)

func _generate_scav_hit_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 102
	return _build_16bit_stream(0.15, func(t: float, _i: int) -> float:
		var freq = lerpf(300.0, 100.0, t / 0.15)
		var amp = lerpf(8000.0, 0.0, t / 0.15)
		return sin(TAU * freq * t) * amp + (rng.randf() * 3000.0 - 1500.0) * (1.0 - t / 0.15)
	)

func _generate_drone_hit_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.1, func(t: float, _i: int) -> float:
		var freq = 1200.0 + sin(t * 200.0) * 400.0
		var env = 1.0 - (t / 0.1)
		var val = 5000.0 if sin(TAU * freq * t) >= 0.0 else -5000.0
		return val * env
	)

func _generate_bunny_death_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.25, func(t: float, _i: int) -> float:
		var freq = lerpf(800.0, 100.0, t / 0.25)
		var amp = lerpf(7000.0, 0.0, t / 0.25)
		return sin(TAU * freq * t) * amp
	)

func _generate_rotor_death_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 103
	return _build_16bit_stream(0.4, func(t: float, _i: int) -> float:
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
	return _build_16bit_stream(0.5, func(t: float, _i: int) -> float:
		var amp = lerpf(12000.0, 0.0, t / 0.5)
		var val = rng.randf_range(-amp, amp)
		if t < 0.1:
			val += sin(TAU * 200.0 * t) * 5000.0
		return val
	)

func _generate_drone_death_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.6, func(t: float, _i: int) -> float:
		var freq = lerpf(800.0, 30.0, pow(t / 0.6, 0.5))
		var amp = lerpf(8000.0, 0.0, t / 0.6)
		var val = sin(TAU * freq * t) * amp
		val += sin(TAU * freq * 1.5 * t) * amp * 0.3
		return val
	)

func _generate_lightning_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 105
	return _build_16bit_stream(0.5, func(t: float, _i: int) -> float:
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
	return _build_16bit_stream(0.3, func(t: float, _i: int) -> float:
		var amp = lerpf(11000.0, 0.0, t / 0.3)
		var noise = rng.randf_range(-amp, amp)
		var freq = lerpf(400.0, 80.0, t / 0.3)
		var metal = sin(TAU * freq * t) * amp * 0.5
		return noise + metal
	)

func _generate_bounce_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.1, func(t: float, _i: int) -> float:
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
	var stream = _build_16bit_stream(4.0, func(t: float, _i: int) -> float:
		var step_idx = int(t * 8.0)
		var freq = arp_freqs[step_idx % arp_freqs.size()]
		var wave = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		return wave * 6000.0 * maxf(0.0, 1.0 - fmod(t * 8.0, 1.0))
	)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _generate_demo_music_giant_biker() -> AudioStreamWAV:
	var stream = _build_16bit_stream(4.0, func(t: float, _i: int) -> float:
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
	var stream = _build_16bit_stream(4.0, func(t: float, _i: int) -> float:
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
	var stream = _build_16bit_stream(4.0, func(t: float, _i: int) -> float:
		var freq = 220.0 + sin(t * TAU * 2.0) * 10.0
		var wave = sin(TAU * freq * t)
		var pulse = sin(TAU * t * 8.0) * 0.5 + 0.5
		return wave * 7000.0 * pulse
	)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _generate_demo_music_war_rig() -> AudioStreamWAV:
	# Epic, intense distorted chords
	var stream = _build_16bit_stream(6.0, func(t: float, _i: int) -> float:
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

	var stream = _build_16bit_stream(16.0, func(t: float, _i: int) -> float:
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
	stream.loop_end = int(22050.0 * 16.0)
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

	var stream = _build_16bit_stream(16.0, func(t: float, _i: int) -> float:
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
	stream.loop_end = int(22050.0 * 16.0)
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

	var stream = _build_16bit_stream(16.0, func(t: float, _i: int) -> float:
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
	stream.loop_end = int(22050.0 * 16.0)
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

	var stream = _build_16bit_stream(16.0, func(t: float, _i: int) -> float:
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
	stream.loop_end = int(22050.0 * 16.0)
	return stream

func _generate_all_async() -> void:
	_async_tasks["menu_music"] = WorkerThreadPool.add_task(func(): _stream_menu_music = _generate_menu_music())
	
	_async_tasks["game_music_bunny"] = WorkerThreadPool.add_task(func(): _stream_game_music_bunny = _generate_game_music_bunny())
	_async_tasks["game_music_biker"] = WorkerThreadPool.add_task(func(): _stream_game_music_biker = _generate_game_music_biker())
	_async_tasks["game_music_sasquatch"] = WorkerThreadPool.add_task(func(): _stream_game_music_sasquatch = _generate_game_music_sasquatch())
	_async_tasks["game_music_void"] = WorkerThreadPool.add_task(func(): _stream_game_music_void = _generate_game_music_void())
	
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
	_custom_playlist.clear()
	_stream_laser = null
	_stream_explosion = null
	_stream_hurt = null
	_stream_boost = null
	_stream_emp = null
	_stream_menu_music = null
	_stream_game_music_bunny = null
	_stream_game_music_biker = null
	_stream_game_music_sasquatch = null
	_stream_game_music_void = null
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

