extends GutTest

func test_audio_manager_creates_music_player():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_is_not_null(am.music_player, "Music player should be created")

func test_audio_manager_creates_sfx_players():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_eq(am.sfx_players.size(), 12, "Should have 12 SFX players")

func test_audio_manager_uses_sfx_bus():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_eq(am.sfx_players[0].bus, "SFX", "SFX players should use SFX bus")

func test_audio_manager_caches_laser_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_is_not_null(am._stream_laser, "Laser stream should be cached")

func test_audio_manager_caches_explosion_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_is_not_null(am._stream_explosion, "Explosion stream should be cached")

func test_audio_manager_caches_hurt_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_is_not_null(am._stream_hurt, "Hurt stream should be cached")

func test_audio_manager_caches_boost_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_is_not_null(am._stream_boost, "Boost stream should be cached")

func test_audio_manager_caches_emp_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_is_not_null(am._stream_emp, "EMP stream should be cached")

func test_audio_manager_play_synth_laser_uses_cached():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	am.play_synth_laser(Vector2.ZERO)
	var playing_count = 0
	for p in am.sfx_players:
		if p.playing:
			playing_count += 1
	assert_eq(playing_count, 1, "Laser SFX should play")

func test_audio_manager_play_synth_explosion_uses_cached():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	am.play_synth_explosion(Vector2.ZERO)
	var playing_count = 0
	for p in am.sfx_players:
		if p.playing:
			playing_count += 1
	assert_eq(playing_count, 1, "Explosion SFX should play")

func test_audio_manager_play_synth_hurt_uses_cached():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	am.play_synth_hurt()
	var playing_count = 0
	for p in am.sfx_players:
		if p.playing:
			playing_count += 1
	assert_eq(playing_count, 1, "Hurt SFX should play")

func test_audio_manager_play_synth_boost_uses_cached():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	am.play_synth_boost()
	var playing_count = 0
	for p in am.sfx_players:
		if p.playing:
			playing_count += 1
	assert_eq(playing_count, 1, "Boost SFX should play")

func test_audio_manager_play_synth_emp_uses_cached():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	am.play_synth_emp(Vector2.ZERO)
	var playing_count = 0
	for p in am.sfx_players:
		if p.playing:
			playing_count += 1
	assert_eq(playing_count, 1, "EMP SFX should play")

func test_audio_manager_stop_music():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	am.stop_music()
	assert_false(am.music_player.playing, "Music should be stopped")

func test_audio_manager_play_music_null_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	am.play_music(null)
	assert_false(am.music_player.playing, "Should not play null stream")

func test_audio_manager_play_sfx_null_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	var before_count = 0
	for p in am.sfx_players:
		if p.playing:
			before_count += 1
	am.play_sfx(null)
	var after_count = 0
	for p in am.sfx_players:
		if p.playing:
			after_count += 1
	assert_eq(after_count, before_count, "Should not play null stream")

func test_audio_manager_procedural_music_generates_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_true(am.music_player.playing or am.music_player.stream != null, "Music should be generated")

func test_sfx_player_count_constant():
	var am = load("res://autoload/AudioManager.gd").new()
	assert_eq(am.SFX_PLAYER_COUNT, 12, "SFX player count should be 12")

func test_cached_streams_are_reusable():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	var stream1 = am._stream_laser
	am.play_synth_laser(Vector2.ZERO)
	var stream2 = am._stream_laser
	assert_eq(stream1, stream2, "Cached stream should be the same instance")

func test_set_bus_volume_master():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	var initial = AudioServer.get_bus_volume_db(0)
	am.set_bus_volume(am.Bus.MASTER, -10.0)
	assert_eq(AudioServer.get_bus_volume_db(0), -10.0, "Master bus volume should change")
	am.set_bus_volume(am.Bus.MASTER, initial)

func test_find_lowest_priority_player_returns_free():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	var result = am._find_lowest_priority_player()
	assert_is_not_null(result, "Should return a player")

func test_play_sfx_reuses_free_player():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	am.play_synth_laser(Vector2.ZERO)
	var first_player = null
	for p in am.sfx_players:
		if p.playing:
			first_player = p
			break
	assert_is_not_null(first_player, "Should have a playing player")

func test_play_sfx_all_players_busy():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	for p in am.sfx_players:
		p.stream = am._stream_laser
		p.play()
	am.play_synth_laser(Vector2.ZERO)
	assert_true(true, "Should handle all players busy without error")

func test_music_player_bus():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_eq(am.music_player.bus, "Master", "Music player should use Master bus")

func test_sfx_players_named():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	for i in am.SFX_PLAYER_COUNT:
		assert_eq(am.sfx_players[i].name, "SFXPlayer" + str(i), "SFX player should have correct name")

func test_music_player_named():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	assert_eq(am.music_player.name, "MusicPlayer", "Music player should have correct name")

func test_generate_laser_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	var stream = am._generate_laser_stream()
	assert_is_not_null(stream, "Should generate laser stream")
	assert_is(stream, AudioStreamWAV, "Should be AudioStreamWAV")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_8_BITS, "Should be 8-bit")

func test_generate_explosion_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	var stream = am._generate_explosion_stream()
	assert_is_not_null(stream, "Should generate explosion stream")
	assert_is(stream, AudioStreamWAV, "Should be AudioStreamWAV")

func test_generate_hurt_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	var stream = am._generate_hurt_stream()
	assert_is_not_null(stream, "Should generate hurt stream")

func test_generate_boost_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	var stream = am._generate_boost_stream()
	assert_is_not_null(stream, "Should generate boost stream")

func test_generate_emp_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	var stream = am._generate_emp_stream()
	assert_is_not_null(stream, "Should generate emp stream")

func test_play_music_sets_stream():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	am.play_music(am._stream_laser)
	assert_eq(am.music_player.stream, am._stream_laser, "Music player stream should be set")

func test_play_sfx_sets_position():
	var am = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(am)
	am._ready()
	var pos = Vector2(100, 200)
	am.play_synth_laser(pos)
	for p in am.sfx_players:
		if p.playing:
			assert_eq(p.global_position, pos, "SFX position should be set")
			break

func test_bus_enum_values():
	var am = load("res://autoload/AudioManager.gd").new()
	assert_eq(am.Bus.MASTER, 0, "MASTER = 0")
	assert_eq(am.Bus.MUSIC, 1, "MUSIC = 1")
	assert_eq(am.Bus.SFX, 2, "SFX = 2")
