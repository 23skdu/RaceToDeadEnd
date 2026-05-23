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
var _stream_game_music: AudioStreamWAV

var _stream_rotor_hit: AudioStreamWAV
var _stream_scav_hit: AudioStreamWAV
var _stream_drone_hit: AudioStreamWAV
var _stream_rotor_death: AudioStreamWAV
var _stream_scav_death: AudioStreamWAV
var _stream_drone_death: AudioStreamWAV
var _stream_lightning: AudioStreamWAV

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player_priorities: Array[int] = []

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
	_generate_menu_music()
	play_menu_music()

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
	if not _stream_menu_music:
		_stream_menu_music = _generate_menu_music()
	if music_player.stream != _stream_menu_music:
		play_music(_stream_menu_music)

func play_game_music() -> void:
	if not _stream_game_music:
		_stream_game_music = _generate_game_music()
	if music_player.stream != _stream_game_music:
		play_music(_stream_game_music)

func play_music(stream: AudioStream) -> void:
	if not stream:
		return
	music_player.stream = stream
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_sfx(stream: AudioStream, pos: Vector2 = Vector2.ZERO, priority: int = 0) -> void:
	if not stream:
		return
	var best_idx = -1
	var lowest_priority = 999
	for i in sfx_players.size():
		var p = sfx_players[i]
		if not p.playing:
			best_idx = i
			break
		if _player_priorities[i] < lowest_priority:
			lowest_priority = _player_priorities[i]
			best_idx = i
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
	return _build_16bit_stream(0.35, func(t: float, _i: int) -> float:
		var amp = lerpf(12000.0, 0.0, t / 0.35)
		return _rng.randf_range(-amp, amp)
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
	var stream = _build_16bit_stream(16.0, func(t: float, _i: int) -> float:
		var bpm = 120.0
		var step_duration = (60.0 / bpm) / 4.0
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)

		var arpeggio = [0, 4, 7, 12, 7, 4, 0, -5, 0, 4, 7, 12, 7, 4, 0, -5,
						2, 5, 9, 14, 9, 5, 2, -3, 0, 4, 7, 12, 7, 4, 0, -5]
		var base_freq = 110.0
		var semitone = arpeggio[step_idx % arpeggio.size()]

		var measure = int(t / (step_duration * 8.0))
		var current_base = base_freq
		if measure % 4 == 2:
			current_base = base_freq * pow(1.059463, 5)
		if measure % 4 == 3:
			current_base = base_freq * pow(1.059463, 7)

		var freq = current_base * pow(1.059463, semitone)
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
			var snare = _rng.randf() * 2.0 - 1.0
			val += snare * 4000.0 * maxf(0.0, 1.0 - (step_t / step_duration))

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(22050.0 * 16.0)
	return stream

func _generate_game_music() -> AudioStreamWAV:
	var stream = _build_16bit_stream(16.0, func(t: float, _i: int) -> float:
		var bpm = 150.0
		var beat_duration = 60.0 / bpm
		var step_duration = beat_duration / 4.0
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)
		var val = 0.0

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
		var arp_notes = [0, 3, 7, 12, 7, 3, 0, -5, 0, 4, 7, 14, 7, 4, 0, -5]
		if is_fill:
			arp_notes = [0, 3, 7, 12, 14, 12, 7, 3, 0, 4, 7, 14, 17, 14, 7, 4]
		var semitone = arp_notes[step_idx % arp_notes.size()]
		var arp_freq = bass_freq * pow(1.059463, semitone / 12.0)
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
			var noise = _rng.randf() * 2.0 - 1.0
			val += noise * 4000.0 * snare_env

		if step_idx % 2 == 1:
			var hat_env = maxf(0.0, 1.0 - (step_t / (step_duration * 0.5)))
			var noise = _rng.randf() * 2.0 - 1.0
			val += noise * 1500.0 * hat_env

		return val
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(22050.0 * 16.0)
	return stream

func _generate_rotor_hit_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.08, func(t: float, _i: int) -> float:
		var freq = lerpf(600.0, 200.0, t / 0.08)
		var env = 1.0 - (t / 0.08)
		var val = 7000.0 if sin(TAU * freq * t) >= 0.0 else -7000.0
		return val * env
	)

func _generate_scav_hit_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.15, func(t: float, _i: int) -> float:
		var freq = lerpf(300.0, 100.0, t / 0.15)
		var amp = lerpf(8000.0, 0.0, t / 0.15)
		return sin(TAU * freq * t) * amp + (_rng.randf() * 3000.0 - 1500.0) * (1.0 - t / 0.15)
	)

func _generate_drone_hit_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.1, func(t: float, _i: int) -> float:
		var freq = 1200.0 + sin(t * 200.0) * 400.0
		var env = 1.0 - (t / 0.1)
		var val = 5000.0 if sin(TAU * freq * t) >= 0.0 else -5000.0
		return val * env
	)

func _generate_rotor_death_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.4, func(t: float, _i: int) -> float:
		var freq = lerpf(400.0, 50.0, t / 0.4)
		var amp = lerpf(9000.0, 0.0, t / 0.4)
		var val = sin(TAU * freq * t) * amp
		if fmod(t * 30.0, 1.0) < 0.3:
			val += _rng.randf() * 4000.0 - 2000.0
		return val
	)

func _generate_scav_death_stream() -> AudioStreamWAV:
	return _build_16bit_stream(0.5, func(t: float, _i: int) -> float:
		var amp = lerpf(12000.0, 0.0, t / 0.5)
		var val = _rng.randf_range(-amp, amp)
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
	return _build_16bit_stream(0.5, func(t: float, _i: int) -> float:
		var amp = lerpf(14000.0, 0.0, t / 0.5)
		var val = _rng.randf_range(-amp, amp)
		if t < 0.05:
			val += sin(TAU * 2000.0 * t) * 7000.0
		if fmod(t * 15.0, 1.0) < 0.2:
			val += _rng.randf() * 5000.0 - 2500.0
		return val
	)
