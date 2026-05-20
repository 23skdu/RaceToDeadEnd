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
