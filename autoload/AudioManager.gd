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
	play_synth_music()

func _generate_cached_streams() -> void:
	_stream_laser = _generate_laser_stream()
	_stream_explosion = _generate_explosion_stream()
	_stream_hurt = _generate_hurt_stream()
	_stream_boost = _generate_boost_stream()
	_stream_emp = _generate_emp_stream()

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

func play_synth_music() -> void:
	var duration = 8.0
	var sample_rate = 8000.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = i / sample_rate
		var freq = 82.41
		if t >= 2.0 and t < 4.0:
			freq = 98.00
		elif t >= 4.0 and t < 6.0:
			freq = 110.00
		elif t >= 6.0:
			freq = 73.42
			
		var val = sin(TAU * freq * t) * 35.0
		var val_sub = sin(TAU * (freq * 0.5) * t) * 15.0
		data[i] = int(val + val_sub) + 128
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	play_music(stream)
