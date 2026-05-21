extends Node

enum Bus { MASTER = 0, MUSIC = 1, SFX = 2 }

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer2D] = []
const SFX_PLAYER_COUNT: int = 12

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

func _ready() -> void:
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
		
	_generate_cached_streams()
	play_menu_music()

func _generate_cached_streams() -> void:
	_stream_laser = _generate_laser_stream()
	_stream_explosion = _generate_explosion_stream()
	_stream_hurt = _generate_hurt_stream()
	_stream_boost = _generate_boost_stream()
	_stream_emp = _generate_emp_stream()
	_stream_menu_music = _generate_menu_music()
	_stream_game_music = _generate_game_music()
	_stream_rotor_hit = _generate_rotor_hit_stream()
	_stream_scav_hit = _generate_scav_hit_stream()
	_stream_drone_hit = _generate_drone_hit_stream()
	_stream_rotor_death = _generate_rotor_death_stream()
	_stream_scav_death = _generate_scav_death_stream()
	_stream_drone_death = _generate_drone_death_stream()
	_stream_lightning = _generate_lightning_stream()

func play_menu_music() -> void:
	if music_player.stream != _stream_menu_music:
		play_music(_stream_menu_music)

func play_game_music() -> void:
	if music_player.stream != _stream_game_music:
		play_music(_stream_game_music)

func play_music(stream: AudioStream) -> void:
	if not stream:
		return
	music_player.stream = stream
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_sfx(stream: AudioStream, pos: Vector2 = Vector2.ZERO, _priority: int = 0) -> void:
	if not stream:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.global_position = pos
			p.play()
			return
	var player = _find_lowest_priority_player()
	player.stream = stream
	player.global_position = pos
	player.play()

func _find_lowest_priority_player() -> AudioStreamPlayer2D:
	for i in range(1, sfx_players.size()):
		if not sfx_players[i].playing:
			return sfx_players[i]
	return sfx_players[0]

func set_bus_volume(bus: Bus, volume_db: float) -> void:
	AudioServer.set_bus_volume_db(bus, volume_db)

func play_synth_laser(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_laser, pos)

func play_synth_explosion(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_explosion, pos)

func play_synth_hurt() -> void:
	play_sfx(_stream_hurt, Vector2.ZERO)

func play_synth_boost() -> void:
	play_sfx(_stream_boost, Vector2.ZERO)

func play_synth_emp(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_emp, pos)

func play_rotor_hit(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_rotor_hit, pos)

func play_scav_hit(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_scav_hit, pos)

func play_drone_hit(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_drone_hit, pos)

func play_rotor_death(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_rotor_death, pos)

func play_scav_death(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_scav_death, pos)

func play_drone_death(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_drone_death, pos)

func play_lightning_strike(pos: Vector2 = Vector2.ZERO) -> void:
	play_sfx(_stream_lightning, pos)

# =================Procedural 8-bit Retro Synthesizer Stream Generators=================

func _generate_laser_stream() -> AudioStreamWAV:
	var duration = 0.12
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = lerpf(800.0, 150.0, t / duration)
		var val = 40 if sin(TAU * freq * t) >= 0.0 else -40
		data[i] = val + 128
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_explosion_stream() -> AudioStreamWAV:
	var duration = 0.35
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var amp = lerpf(80.0, 0.0, t / duration)
		var val = randf_range(-amp, amp)
		data[i] = clampi(int(val) + 128, 0, 255)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_hurt_stream() -> AudioStreamWAV:
	var duration = 0.2
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = lerpf(180.0, 45.0, t / duration)
		var val = 70 if sin(TAU * freq * t) >= 0.0 else -70
		data[i] = val + 128
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_boost_stream() -> AudioStreamWAV:
	var duration = 0.4
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = lerpf(250.0, 850.0, t / duration)
		var val = 30 if sin(TAU * freq * t) >= 0.0 else -30
		data[i] = val + 128
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_emp_stream() -> AudioStreamWAV:
	var duration = 0.6
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = 350.0 + sin(t * 70.0) * 120.0
		var val = 50 if sin(TAU * freq * t) >= 0.0 else -50
		data[i] = val + 128
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_menu_music() -> AudioStreamWAV:
	var duration = 4.0
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var bpm = 120.0
	var step_duration = (60.0 / bpm) / 4.0
	
	var arpeggio = [0, 4, 7, 12, 7, 4, 0, -5]
	var base_freq = 110.0 # A2
	
	for i in num_samples:
		var t = i / sample_rate
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)
		
		var semitone = arpeggio[step_idx % arpeggio.size()]
		
		# Slowly shift the base frequency up over the 4 seconds to build tension
		var current_base = base_freq
		if t > 2.0:
			current_base = base_freq * pow(1.059463, 5) # up to D
			
		var freq = current_base * pow(1.059463, semitone)
		
		# Pulse wave 50% duty
		var wave = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		var env = max(0.0, 1.0 - (step_t / step_duration))
		var val = wave * 30.0 * env
		
		# Add a subtle bass drone
		var bass_freq = current_base / 2.0
		var bass_wave = 1.0 if fmod(t * bass_freq, 1.0) < 0.5 else -1.0
		val += bass_wave * 15.0
		
		data[i] = clampi(int(val) + 128, 0, 255)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

func _generate_game_music() -> AudioStreamWAV:
	var duration = 6.4
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var bpm = 150.0
	var beats_per_sec = bpm / 60.0
	var beat_duration = 1.0 / beats_per_sec
	var step_duration = beat_duration / 4.0
	
	for i in num_samples:
		var t = i / sample_rate
		var step_idx = int(t / step_duration)
		var step_t = fmod(t, step_duration)
		var val = 0.0
		
		var chord_progression = [
			55.0, 55.0, 55.0, 55.0,
			65.41, 65.41, 65.41, 65.41,
			73.42, 73.42, 73.42, 73.42,
			49.00, 49.00, 49.00, 49.00
		]
		var measure_idx = int(t / (beat_duration * 4.0)) % 4
		var bass_freq = chord_progression[measure_idx * 4]
		
		if step_idx % 2 == 0:
			var bass_env = max(0.0, 1.0 - (step_t / step_duration))
			var bass_wave = 1.0 if sin(TAU * bass_freq * t) > 0 else -1.0
			val += bass_wave * 20.0 * bass_env
			
		var arp_notes = [0, 3, 7, 12, 7, 3, 0, -5]
		var semitone = arp_notes[step_idx % arp_notes.size()]
		var arp_freq = bass_freq * pow(1.059463, semitone / 12.0)
		var arp_env = max(0.0, 1.0 - (step_t / (step_duration * 0.8)))
		var arp_wave = 1.0 if fmod(t * arp_freq, 1.0) < 0.25 else -1.0
		val += arp_wave * 15.0 * arp_env
		
		if step_idx % 4 == 0:
			var kick_env = max(0.0, 1.0 - (step_t / (step_duration * 1.5)))
			var kick_pitch = lerpf(150.0, 40.0, step_t / (step_duration * 1.5))
			var kick_wave = sin(TAU * kick_pitch * step_t)
			val += kick_wave * 30.0 * kick_env
			
		if (step_idx + 4) % 8 == 0:
			var snare_env = max(0.0, 1.0 - (step_t / step_duration))
			var noise = randf() * 2.0 - 1.0
			val += noise * 25.0 * snare_env
			
		if step_idx % 2 == 1:
			var hat_env = max(0.0, 1.0 - (step_t / (step_duration * 0.5)))
			var noise = randf() * 2.0 - 1.0
			val += noise * 10.0 * hat_env
			
		data[i] = clampi(int(val) + 128, 0, 255)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

func _generate_rotor_hit_stream() -> AudioStreamWAV:
	var duration = 0.08
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = lerpf(600.0, 200.0, t / duration)
		var val = 50 if sin(TAU * freq * t) >= 0.0 else -50
		var env = 1.0 - (t / duration)
		data[i] = clampi(int(val * env) + 128, 0, 255)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_scav_hit_stream() -> AudioStreamWAV:
	var duration = 0.15
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = lerpf(300.0, 100.0, t / duration)
		var amp = lerpf(60.0, 0.0, t / duration)
		var val = sin(TAU * freq * t) * amp + (randf() * 20.0 - 10.0) * (1.0 - t / duration)
		data[i] = clampi(int(val) + 128, 0, 255)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_drone_hit_stream() -> AudioStreamWAV:
	var duration = 0.1
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = 1200.0 + sin(t * 200.0) * 400.0
		var val = 35 if sin(TAU * freq * t) >= 0.0 else -35
		var env = 1.0 - (t / duration)
		data[i] = clampi(int(val * env) + 128, 0, 255)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_rotor_death_stream() -> AudioStreamWAV:
	var duration = 0.4
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = lerpf(400.0, 50.0, t / duration)
		var amp = lerpf(70.0, 0.0, t / duration)
		var val = sin(TAU * freq * t) * amp
		if fmod(t * 30.0, 1.0) < 0.3:
			val += randf() * 30.0 - 15.0
		data[i] = clampi(int(val) + 128, 0, 255)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_scav_death_stream() -> AudioStreamWAV:
	var duration = 0.5
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var amp = lerpf(90.0, 0.0, t / duration)
		var val = randf_range(-amp, amp)
		if t < 0.1:
			val += sin(TAU * 200.0 * t) * 40.0
		data[i] = clampi(int(val) + 128, 0, 255)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_drone_death_stream() -> AudioStreamWAV:
	var duration = 0.6
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = lerpf(800.0, 30.0, pow(t / duration, 0.5))
		var amp = lerpf(60.0, 0.0, t / duration)
		var val = sin(TAU * freq * t) * amp
		val += sin(TAU * freq * 1.5 * t) * amp * 0.3
		data[i] = clampi(int(val) + 128, 0, 255)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream

func _generate_lightning_stream() -> AudioStreamWAV:
	var duration = 0.5
	var sample_rate = 11025.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var amp = lerpf(100.0, 0.0, t / duration)
		var val = randf_range(-amp, amp)
		if t < 0.05:
			val += sin(TAU * 2000.0 * t) * 50.0
		if fmod(t * 15.0, 1.0) < 0.2:
			val += randf() * 40.0 - 20.0
		data[i] = clampi(int(val) + 128, 0, 255)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	return stream
