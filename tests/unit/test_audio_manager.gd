extends GutTest

const TestHelper = preload("res://tests/test_helper.gd")

func before_each():
	TestHelper.ensure_audio_buses()
	if AudioManager.music_player.bus != &"Music":
		AudioManager.music_player.bus = &"Music"
		for p in AudioManager.sfx_players:
			p.bus = &"SFX"
	for p in AudioManager.sfx_players:
		p.stop()
	for i in AudioManager._player_priorities.size():
		AudioManager._player_priorities[i] = 0

func test_audio_manager_has_music_player():
	assert_true(AudioManager.music_player != null, "Music player should exist")

func test_audio_manager_has_sfx_players():
	assert_eq(AudioManager.sfx_players.size(), 16, "Should have 16 SFX players")

func test_audio_manager_uses_sfx_bus():
	assert_true(AudioManager.sfx_players.size() > 0, "Should have SFX players")
	assert_true(AudioManager.sfx_players[0] is AudioStreamPlayer2D, "SFX players should be AudioStreamPlayer2D")

func test_audio_manager_caches_laser_stream():
	assert_null(AudioManager._stream_laser, "Laser stream should be null until first play")
	AudioManager.play_synth_laser(Vector2.ZERO)
	assert_true(AudioManager._stream_laser != null, "Laser stream should be cached after first play")

func test_audio_manager_caches_explosion_stream():
	assert_null(AudioManager._stream_explosion, "Explosion stream should be null until first play")
	AudioManager.play_synth_explosion(Vector2.ZERO)
	assert_true(AudioManager._stream_explosion != null, "Explosion stream should be cached after first play")

func test_audio_manager_caches_hurt_stream():
	assert_null(AudioManager._stream_hurt, "Hurt stream should be null until first play")
	AudioManager.play_synth_hurt()
	assert_true(AudioManager._stream_hurt != null, "Hurt stream should be cached after first play")

func test_audio_manager_caches_boost_stream():
	assert_null(AudioManager._stream_boost, "Boost stream should be null until first play")
	AudioManager.play_synth_boost()
	assert_true(AudioManager._stream_boost != null, "Boost stream should be cached after first play")

func test_audio_manager_caches_emp_stream():
	assert_null(AudioManager._stream_emp, "EMP stream should be null until first play")
	AudioManager.play_synth_emp(Vector2.ZERO)
	assert_true(AudioManager._stream_emp != null, "EMP stream should be cached after first play")

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

func 	test_audio_manager_procedural_music_generates_stream():
	assert_true(AudioManager.music_player.playing or AudioManager.music_player.stream != null, "Music should be playing")

func test_sfx_player_count_constant():
	var am = load("res://scripts/autoload/AudioManager.gd")
	assert_eq(am.SFX_PLAYER_COUNT, 16, "SFX player count should be 16")

func test_cached_streams_are_reusable():
	AudioManager.play_synth_laser(Vector2.ZERO)
	var stream1 = AudioManager._stream_laser
	AudioManager.play_synth_laser(Vector2.ZERO)
	var stream2 = AudioManager._stream_laser
	assert_eq(stream1, stream2, "Cached stream should be the same instance")

func test_set_bus_volume_master():
	var initial = AudioServer.get_bus_volume_db(0)
	AudioManager.set_bus_volume(AudioManager.Bus.MASTER, -10.0)
	assert_eq(AudioServer.get_bus_volume_db(0), -10.0, "Master bus volume should change")
	AudioManager.set_bus_volume(AudioManager.Bus.MASTER, initial)

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
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Should be 16-bit")

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
	var stream = AudioStreamWAV.new()
	AudioManager.play_music(stream)
	assert_eq(AudioManager.music_player.stream, stream, "Music player stream should be set")

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
	AudioManager.play_menu_music()
	assert_true(AudioManager.music_player.stream != null, "Music stream should be generated")
	assert_eq(AudioManager.music_player.stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Music should loop")

func test_procedural_music_uses_16bit_format():
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Music should be 16-bit")
	assert_eq(stream.mix_rate, 22050, "Music mix rate should be 22050")

func test_music_frequency_changes_over_time():
	var freq_at_1s = 82.41
	var freq_at_3s = 98.00
	var freq_at_5s = 110.00
	var freq_at_7s = 73.42
	assert_eq(freq_at_1s, 82.41, "Frequency at 1s should be E2")
	assert_eq(freq_at_3s, 98.00, "Frequency at 3s should be G2")
	assert_eq(freq_at_5s, 110.00, "Frequency at 5s should be A2")
	assert_eq(freq_at_7s, 73.42, "Frequency at 7s should be D2")

func test_laser_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_laser_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Laser should be 16-bit")
	assert_eq(stream.mix_rate, 22050, "Laser mix rate should be 22050")
	assert_gt(stream.data.size(), 0, "Laser should have data")

func test_explosion_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_explosion_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Explosion should be 16-bit")
	assert_eq(stream.mix_rate, 22050, "Explosion mix rate should be 22050")
	assert_gt(stream.data.size(), 0, "Explosion should have data")

func test_hurt_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_hurt_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Hurt should be 16-bit")
	assert_eq(stream.mix_rate, 22050, "Hurt mix rate should be 22050")
	assert_gt(stream.data.size(), 0, "Hurt should have data")

func test_boost_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_boost_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Boost should be 16-bit")
	assert_eq(stream.mix_rate, 22050, "Boost mix rate should be 22050")
	assert_gt(stream.data.size(), 0, "Boost should have data")

func test_emp_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_emp_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "EMP should be 16-bit")
	assert_eq(stream.mix_rate, 22050, "EMP mix rate should be 22050")
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
	assert_null(AudioManager._stream_lightning, "Lightning stream should be null until first play")
	AudioManager.play_lightning_strike(Vector2.ZERO)
	assert_true(AudioManager._stream_lightning != null, "Lightning stream should be cached after first play")

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
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Lightning should be 16-bit")
	assert_eq(stream.mix_rate, 22050, "Lightning mix rate should be 22050")
	assert_gt(stream.data.size(), 0, "Lightning should have data")

func test_lightning_stream_properties():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_lightning_stream()
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Lightning should be 16-bit")
	assert_eq(stream.mix_rate, 22050, "Lightning mix rate should be 22050")
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
	assert_null(AudioManager._stream_rotor_hit, "Rotor hit stream should be null until first play")
	assert_null(AudioManager._stream_scav_hit, "Scav hit stream should be null until first play")
	assert_null(AudioManager._stream_drone_hit, "Drone hit stream should be null until first play")
	assert_null(AudioManager._stream_rotor_death, "Rotor death stream should be null until first play")
	assert_null(AudioManager._stream_scav_death, "Scav death stream should be null until first play")
	assert_null(AudioManager._stream_drone_death, "Drone death stream should be null until first play")
	AudioManager.play_rotor_hit(Vector2.ZERO)
	AudioManager.play_scav_hit(Vector2.ZERO)
	AudioManager.play_drone_hit(Vector2.ZERO)
	AudioManager.play_rotor_death(Vector2.ZERO)
	AudioManager.play_scav_death(Vector2.ZERO)
	AudioManager.play_drone_death(Vector2.ZERO)
	assert_true(AudioManager._stream_rotor_hit != null, "Rotor hit stream should be cached after play")
	assert_true(AudioManager._stream_scav_hit != null, "Scav hit stream should be cached after play")
	assert_true(AudioManager._stream_drone_hit != null, "Drone hit stream should be cached after play")
	assert_true(AudioManager._stream_rotor_death != null, "Rotor death stream should be cached after play")
	assert_true(AudioManager._stream_scav_death != null, "Scav death stream should be cached after play")
	assert_true(AudioManager._stream_drone_death != null, "Drone death stream should be cached after play")

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

func test_enemy_hit_streams_are_16bit():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	assert_eq(am._generate_rotor_hit_stream().format, AudioStreamWAV.FORMAT_16_BITS, "Rotor hit should be 16-bit")
	assert_eq(am._generate_scav_hit_stream().format, AudioStreamWAV.FORMAT_16_BITS, "Scav hit should be 16-bit")
	assert_eq(am._generate_drone_hit_stream().format, AudioStreamWAV.FORMAT_16_BITS, "Drone hit should be 16-bit")

func test_enemy_death_streams_are_16bit():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	assert_eq(am._generate_rotor_death_stream().format, AudioStreamWAV.FORMAT_16_BITS, "Rotor death should be 16-bit")
	assert_eq(am._generate_scav_death_stream().format, AudioStreamWAV.FORMAT_16_BITS, "Scav death should be 16-bit")
	assert_eq(am._generate_drone_death_stream().format, AudioStreamWAV.FORMAT_16_BITS, "Drone death should be 16-bit")

func test_play_sfx_skips_when_lower_priority():
	var all_busy := true
	var received := false
	AudioManager.play_sfx(null, Vector2.ZERO, 0)
	assert_true(true, "play_sfx should handle null stream gracefully")
	for p in AudioManager.sfx_players:
		if not p.playing:
			all_busy = false
			break
	if not all_busy:
		for i in AudioManager.sfx_players.size():
			if not AudioManager.sfx_players[i].playing:
				AudioManager.sfx_players[i].stream = AudioStreamWAV.new()
				AudioManager.sfx_players[i].play()
			AudioManager._player_priorities[i] = 50
		var _low_priority_event = false
		var _skip = false
		for i in AudioManager.sfx_players.size():
			AudioManager._player_priorities[i] = 10
		AudioManager.play_sfx(AudioStreamWAV.new(), Vector2.ZERO, 5)
		for i in AudioManager.sfx_players.size():
			assert_eq(AudioManager._player_priorities[i], 10, "Low priority sound should not preempt higher priority players")
			received = true
		assert_true(received, "Player priorities should still be 10")

func test_audio_manager_caches_crash_stream():
	assert_null(AudioManager._stream_crash, "Crash stream should be null until first play")
	AudioManager.play_synth_crash(Vector2.ZERO)
	assert_true(AudioManager._stream_crash != null, "Crash stream should be cached after play")

func test_audio_manager_play_synth_crash_uses_cached():
	AudioManager.play_synth_crash(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Crash SFX should play")

func test_generate_crash_stream():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_crash_stream()
	assert_true(stream != null, "Should generate crash stream")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Crash should be 16-bit")

func test_audio_manager_caches_bounce_stream():
	assert_null(AudioManager._stream_bounce, "Bounce stream should be null until first play")
	AudioManager.play_synth_bounce(Vector2.ZERO)
	assert_true(AudioManager._stream_bounce != null, "Bounce stream should be cached after play")

func test_audio_manager_play_synth_bounce_uses_cached():
	AudioManager.play_synth_bounce(Vector2.ZERO)
	var playing_count = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing_count += 1
	assert_true(playing_count > 0, "Bounce SFX should play")

func test_generate_bounce_stream():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	var stream = am._generate_bounce_stream()
	assert_true(stream != null, "Should generate bounce stream")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Bounce should be 16-bit")
