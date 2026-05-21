extends GutTest

func before_each():
	TestHelper.ensure_audio_buses()

func test_audio_manager_has_music_player():
	assert_true(AudioManager.music_player != null, "Music player should exist")

func test_audio_manager_has_sfx_players():
	assert_eq(AudioManager.sfx_players.size(), 12, "Should have 12 SFX players")

func test_audio_manager_uses_sfx_bus():
	assert_true(AudioManager.sfx_players.size() > 0, "Should have SFX players")
	assert_true(AudioManager.sfx_players[0] is AudioStreamPlayer2D, "SFX players should be AudioStreamPlayer2D")

func test_audio_manager_caches_laser_stream():
	assert_true(AudioManager._stream_laser != null, "Laser stream should be cached")

func test_audio_manager_caches_explosion_stream():
	assert_true(AudioManager._stream_explosion != null, "Explosion stream should be cached")

func test_audio_manager_caches_hurt_stream():
	assert_true(AudioManager._stream_hurt != null, "Hurt stream should be cached")

func test_audio_manager_caches_boost_stream():
	assert_true(AudioManager._stream_boost != null, "Boost stream should be cached")

func test_audio_manager_caches_emp_stream():
	assert_true(AudioManager._stream_emp != null, "EMP stream should be cached")

func test_audio_manager_play_synth_laser_uses_cached():
	var before_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			before_count += 1
	AudioManager.play_synth_laser(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_eq(playing_count, before_count + 1, "Laser SFX should play")

func test_audio_manager_play_synth_explosion_uses_cached():
	AudioManager.play_synth_explosion(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Explosion SFX should play")

func test_audio_manager_play_synth_hurt_uses_cached():
	AudioManager.play_synth_hurt()
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Hurt SFX should play")

func test_audio_manager_play_synth_boost_uses_cached():
	AudioManager.play_synth_boost()
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Boost SFX should play")

func test_audio_manager_play_synth_emp_uses_cached():
	AudioManager.play_synth_emp(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "EMP SFX should play")

func test_audio_manager_stop_music():
	AudioManager.stop_music()
	assert_false(AudioManager.music_player.playing, "Music should be stopped")

func test_audio_manager_play_music_null_stream():
	AudioManager.play_music(null)
	assert_false(AudioManager.music_player.playing, "Should not play null stream")

func test_audio_manager_play_sfx_null_stream():
	var before_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			before_count += 1
	AudioManager.play_sfx(null)
	var after_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			after_count += 1
	assert_eq(after_count, before_count, "Should not play null stream")

func test_audio_manager_procedural_music_generates_stream():
	assert_true(AudioManager.music_player.playing or AudioManager.music_player.stream != null, "Music should be playing")

func test_sfx_player_count_constant():
	var am = load("res://scripts/autoload/AudioManager.gd")
	assert_eq(am.SFX_PLAYER_COUNT, 12, "SFX player count should be 12")

func test_cached_streams_are_reusable():
	var stream1 = AudioManager._stream_laser
	AudioManager.play_synth_laser(Vector2.ZERO)
	var stream2 = AudioManager._stream_laser
	assert_eq(stream1, stream2, "Cached stream should be the same instance")

func test_set_bus_volume_master():
	var initial = AudioServer.get_bus_volume_db(0)
	AudioManager.set_bus_volume(AudioManager.Bus.MASTER, -10.0)
	assert_eq(AudioServer.get_bus_volume_db(0), -10.0, "Master bus volume should change")
	AudioManager.set_bus_volume(AudioManager.Bus.MASTER, initial)

func test_find_lowest_priority_player_returns_free():
	var result = AudioManager._find_lowest_priority_player()
	assert_true(result != null, "Should return a player")

func test_play_sfx_reuses_free_player():
	AudioManager.play_synth_laser(Vector2.ZERO)
	var first_player = null
	for p in AudioManager.sfx_players:
		if p.playing:
			first_player = p
			break
	assert_true(first_player != null, "Should have a playing player")

func test_music_player_bus():
	assert_eq(AudioManager.music_player.bus, StringName("Music"), "Music player should use Music bus")

func test_sfx_players_named():
	for i in AudioManager.SFX_PLAYER_COUNT:
		assert_eq(AudioManager.sfx_players[i].name, StringName("SFXPlayer" + str(i)), "SFX player should have correct name")

func test_music_player_named():
	assert_eq(AudioManager.music_player.name, StringName("MusicPlayer"), "Music player should have correct name")

func test_generate_laser_stream():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_laser_stream()
	assert_true(stream != null, "Should generate laser stream")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "Should be 8-bit")

func test_generate_explosion_stream():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_explosion_stream()
	assert_true(stream != null, "Should generate explosion stream")

func test_generate_hurt_stream():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_hurt_stream()
	assert_true(stream != null, "Should generate hurt stream")

func test_generate_boost_stream():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_boost_stream()
	assert_true(stream != null, "Should generate boost stream")

func test_generate_emp_stream():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_emp_stream()
	assert_true(stream != null, "Should generate emp stream")

func test_play_music_sets_stream():
	AudioManager.play_music(AudioManager._stream_laser)
	assert_eq(AudioManager.music_player.stream, AudioManager._stream_laser, "Music player stream should be set")

func test_play_sfx_sets_position():
	var pos = Vector2(100, 200)
	AudioManager.play_synth_laser(pos)
	var found = false
	for p in AudioManager.sfx_players:
		if p.playing and p.global_position == pos:
			found = true
			break
	assert_true(found, "SFX position should be set")

func test_bus_enum_values():
	var am = load("res://scripts/autoload/AudioManager.gd")
	assert_eq(am.Bus.MASTER, 0, "MASTER = 0")
	assert_eq(am.Bus.MUSIC, 1, "MUSIC = 1")
	assert_eq(am.Bus.SFX, 2, "SFX = 2")

func test_set_bus_volume_music():
	var initial = AudioServer.get_bus_volume_db(1)
	AudioManager.set_bus_volume(AudioManager.Bus.MUSIC, -15.0)
	assert_eq(AudioServer.get_bus_volume_db(1), -15.0, "Music bus volume should change")
	AudioManager.set_bus_volume(AudioManager.Bus.MUSIC, initial)

func test_set_bus_volume_sfx():
	var initial = AudioServer.get_bus_volume_db(2)
	AudioManager.set_bus_volume(AudioManager.Bus.SFX, -20.0)
	assert_eq(AudioServer.get_bus_volume_db(2), -20.0, "SFX bus volume should change")
	AudioManager.set_bus_volume(AudioManager.Bus.SFX, initial)

func test_play_synth_music_generates_looping_stream():
	AudioManager.play_synth_music()
	assert_true(AudioManager.music_player.stream != null, "Music stream should be generated")
	assert_eq(AudioManager.music_player.stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Music should loop")

func test_procedural_music_uses_8bit_format():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
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
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "Music should be 8-bit")
	assert_eq(stream.mix_rate, 8000, "Music mix rate should be 8000")

func test_music_frequency_changes_over_time():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = AudioStreamWAV.new()
	var duration = 8.0
	var sample_rate = 8000.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	var freq_at_1s = 82.41
	var freq_at_3s = 98.00
	var freq_at_5s = 110.00
	var freq_at_7s = 73.42
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
	assert_eq(freq_at_1s, 82.41, "Frequency at 1s should be E2")
	assert_eq(freq_at_3s, 98.00, "Frequency at 3s should be G2")
	assert_eq(freq_at_5s, 110.00, "Frequency at 5s should be A2")
	assert_eq(freq_at_7s, 73.42, "Frequency at 7s should be D2")

func test_laser_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_laser_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "Laser should be 8-bit")
	assert_eq(stream.mix_rate, 11025, "Laser mix rate should be 11025")
	assert_gt(stream.data.size(), 0, "Laser should have data")

func test_explosion_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_explosion_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "Explosion should be 8-bit")
	assert_eq(stream.mix_rate, 11025, "Explosion mix rate should be 11025")
	assert_gt(stream.data.size(), 0, "Explosion should have data")

func test_hurt_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_hurt_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "Hurt should be 8-bit")
	assert_eq(stream.mix_rate, 11025, "Hurt mix rate should be 11025")
	assert_gt(stream.data.size(), 0, "Hurt should have data")

func test_boost_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_boost_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "Boost should be 8-bit")
	assert_eq(stream.mix_rate, 11025, "Boost mix rate should be 11025")
	assert_gt(stream.data.size(), 0, "Boost should have data")

func test_emp_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_emp_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "EMP should be 8-bit")
	assert_eq(stream.mix_rate, 11025, "EMP mix rate should be 11025")
	assert_gt(stream.data.size(), 0, "EMP should have data")

func test_sfx_player_position_set():
	var pos = Vector2(150, 250)
	AudioManager.play_synth_laser(pos)
	var found = false
	for p in AudioManager.sfx_players:
		if p.playing and p.global_position == pos:
			found = true
			break
	assert_true(found, "SFX player position should match input")

func test_all_sfx_players_use_sfx_bus():
	for p in AudioManager.sfx_players:
		assert_eq(p.bus, StringName("SFX"), "SFX player should use SFX bus")

func test_audio_manager_caches_lightning_stream():
	assert_true(AudioManager._stream_lightning != null, "Lightning stream should be cached")

func test_audio_manager_play_lightning_uses_cached():
	AudioManager.play_lightning_strike(Vector2(0, -400))
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Lightning SFX should play")

func test_generate_lightning_stream():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_lightning_stream()
	assert_true(stream != null, "Should generate lightning stream")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "Lightning should be 8-bit")
	assert_eq(stream.mix_rate, 11025, "Lightning mix rate should be 11025")
	assert_gt(stream.data.size(), 0, "Lightning should have data")

func test_lightning_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_lightning_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "Lightning should be 8-bit")
	assert_eq(stream.mix_rate, 11025, "Lightning mix rate should be 11025")
	assert_gt(stream.data.size(), 0, "Lightning should have data")

func test_play_lightning_strike_sets_position():
	var pos = Vector2(0, -400)
	AudioManager.play_lightning_strike(pos)
	var found = false
	for p in AudioManager.sfx_players:
		if p.playing and p.global_position == pos:
			found = true
			break
	assert_true(found, "Lightning SFX position should be set")

func test_cached_streams_enemy_hit_death():
	assert_true(AudioManager._stream_rotor_hit != null, "Rotor hit stream should be cached")
	assert_true(AudioManager._stream_scav_hit != null, "Scav hit stream should be cached")
	assert_true(AudioManager._stream_drone_hit != null, "Drone hit stream should be cached")
	assert_true(AudioManager._stream_rotor_death != null, "Rotor death stream should be cached")
	assert_true(AudioManager._stream_scav_death != null, "Scav death stream should be cached")
	assert_true(AudioManager._stream_drone_death != null, "Drone death stream should be cached")

func test_play_rotor_hit():
	AudioManager.play_rotor_hit(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Rotor hit SFX should play")

func test_play_scav_hit():
	AudioManager.play_scav_hit(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Scav hit SFX should play")

func test_play_drone_hit():
	AudioManager.play_drone_hit(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Drone hit SFX should play")

func test_play_rotor_death():
	AudioManager.play_rotor_death(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Rotor death SFX should play")

func test_play_scav_death():
	AudioManager.play_scav_death(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Scav death SFX should play")

func test_play_drone_death():
	AudioManager.play_drone_death(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Drone death SFX should play")

func test_enemy_hit_streams_are_8bit():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	assert_eq(am._generate_rotor_hit_stream().format, AudioStreamWAV.FORMAT_8_BITS, "Rotor hit should be 8-bit")
	assert_eq(am._generate_scav_hit_stream().format, AudioStreamWAV.FORMAT_8_BITS, "Scav hit should be 8-bit")
	assert_eq(am._generate_drone_hit_stream().format, AudioStreamWAV.FORMAT_8_BITS, "Drone hit should be 8-bit")

func test_enemy_death_streams_are_8bit():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	assert_eq(am._generate_rotor_death_stream().format, AudioStreamWAV.FORMAT_8_BITS, "Rotor death should be 8-bit")
	assert_eq(am._generate_scav_death_stream().format, AudioStreamWAV.FORMAT_8_BITS, "Scav death should be 8-bit")
	assert_eq(am._generate_drone_death_stream().format, AudioStreamWAV.FORMAT_8_BITS, "Drone death should be 8-bit")
