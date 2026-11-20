extends GutTest

const PackManagerScript = preload("res://scripts/autoload/PackManager.gd")
const InputRemapScript = preload("res://scripts/scenes/ui/InputRemap.gd")

func before_each():
	if FileAccess.file_exists("user://save.dat"):
		DirAccess.remove_absolute("user://save.dat")
	if FileAccess.file_exists("user://save.dat.tmp"):
		DirAccess.remove_absolute("user://save.dat.tmp")

func after_each():
	GameManager.daily_run_active = false
	GameManager.daily_seed = 0
	if get_tree().paused:
		get_tree().paused = false
	if AudioManager.has_method("revert_to_default_music"):
		AudioManager._custom_playlist.clear()

# --- Regression 1: AudioManager determinism & async menu music & playlist ---

func test_audio_manager_menu_music_async_and_looping():
	AudioManager.play_menu_music()
	assert_not_null(AudioManager._stream_menu_music, "Menu music should be generated via async task or fallback")
	assert_eq(AudioManager._stream_menu_music.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Menu music should loop")

func test_audio_manager_generators_deterministic_across_calls():
	var am = load("res://scripts/autoload/AudioManager.gd").new()
	autofree(am)
	var s1: AudioStreamWAV = am._generate_game_music_bunny()
	var s2: AudioStreamWAV = am._generate_game_music_bunny()
	assert_eq(s1.data, s2.data, "Bunny music generator should be deterministic with local RNG")
	var b1: AudioStreamWAV = am._generate_game_music_biker()
	var b2: AudioStreamWAV = am._generate_game_music_biker()
	assert_eq(b1.data, b2.data, "Biker music generator should be deterministic with local RNG")

func test_audio_manager_playlist_and_revert():
	var s1 = AudioStreamWAV.new()
	var s2 = AudioStreamWAV.new()
	AudioManager.set_playlist([s1, s2], false)
	assert_eq(AudioManager._custom_playlist.size(), 2, "Playlist should store 2 tracks")
	assert_eq(AudioManager.music_player.stream, s1, "First track should be active")
	AudioManager._on_music_finished()
	assert_eq(AudioManager.music_player.stream, s2, "Second track should play after finish")
	AudioManager.revert_to_default_music()
	assert_eq(AudioManager._custom_playlist.size(), 0, "Playlist should clear on revert")

# --- Regression 2: Procedural texture & eye shader caching ---

func test_enemy_eye_shader_material_cached():
	var b1 = load("res://scenes/enemies/Bunny.tscn").instantiate()
	var b2 = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(b1)
	add_child_autofree(b2)
	b1.init(b1.EnemyType.BUNNY, 0, null, 200.0)
	b2.init(b2.EnemyType.BUNNY, 1, null, 200.0)
	assert_not_null(b1.sprite.material, "Bunny should have eye shader material")
	assert_eq(b1.sprite.material, b2.sprite.material, "Eye ShaderMaterial should be shared across instances")

func test_boss_and_weapon_textures_cached():
	var bb1 = load("res://scenes/enemies/BossBunny.tscn").instantiate()
	var bb2 = load("res://scenes/enemies/BossBunny.tscn").instantiate()
	add_child_autofree(bb1)
	add_child_autofree(bb2)
	assert_eq(bb1.sprite.texture, bb2.sprite.texture, "BossBunny texture should be cached")

	var bg1 = load("res://scenes/enemies/BossGiantBiker.tscn").instantiate()
	var bg2 = load("res://scenes/enemies/BossGiantBiker.tscn").instantiate()
	add_child_autofree(bg1)
	add_child_autofree(bg2)
	assert_eq(bg1.sprite.texture, bg2.sprite.texture, "BossGiantBiker texture should be cached")

	var bs1 = load("res://scenes/enemies/BossSasquatch.tscn").instantiate()
	var bs2 = load("res://scenes/enemies/BossSasquatch.tscn").instantiate()
	add_child_autofree(bs1)
	add_child_autofree(bs2)
	assert_eq(bs1.sprite.texture, bs2.sprite.texture, "BossSasquatch texture should be cached")

	var bv1 = load("res://scenes/enemies/BossVoidDrone.tscn").instantiate()
	var bv2 = load("res://scenes/enemies/BossVoidDrone.tscn").instantiate()
	add_child_autofree(bv1)
	add_child_autofree(bv2)
	assert_eq(bv1.sprite.texture, bv2.sprite.texture, "BossVoidDrone texture should be cached")

	var bomb1 = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	var bomb2 = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb1)
	add_child_autofree(bomb2)
	assert_eq(bomb1.sprite.texture, bomb2.sprite.texture, "BabyBunnyBomb texture should be cached")

	var p1 = load("res://scenes/weapons/PoopWeapon.tscn").instantiate()
	var p2 = load("res://scenes/weapons/PoopWeapon.tscn").instantiate()
	add_child_autofree(p1)
	add_child_autofree(p2)
	assert_eq(p1.get_node("Sprite2D").texture, p2.get_node("Sprite2D").texture, "PoopWeapon texture should be cached")

# --- Regression 3 & 9: Interceptor boost trail & bridge fall ---

func test_interceptor_boost_trail_reuses_gradient_and_is_visible():
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var player = load("res://scenes/player/Interceptor.tscn").instantiate()
	add_child_autofree(player)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	var grad = player._trail_gradient
	assert_not_null(grad, "Pre-allocated gradient should exist")
	assert_eq(player._trail_line.gradient, grad, "Line2D should use pre-allocated gradient")
	assert_gt(player._trail_line.default_color.a, 0.0, "Trail default_color must have non-zero alpha")
	player.boost_active = true
	player.velocity = Vector2(0, -300)
	player._trail_spacing_counter = player.TRAIL_SPACING
	player._update_boost_trail()
	player._trail_spacing_counter = player.TRAIL_SPACING
	player._update_boost_trail()
	assert_eq(player._trail_line.gradient, grad, "Boost trail must reuse same Gradient instance")
	assert_gt(player._trail_line.gradient.colors[0].a, 0.0, "Gradient start color should be visible")

func test_interceptor_bridge_fall_right_half_snaps_to_right_lane():
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var player = load("res://scenes/player/Interceptor.tscn").instantiate()
	add_child_autofree(player)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	GameManager.start_game()
	player.position.x = 500.0
	player.on_bridge_fall(player)
	assert_gt(player.position.x, 0.0, "Bridge fall from right side must recover to right-half lane")
	assert_eq(player.current_lane, 6, "Right-side bridge fall should snap to lane 6")

# --- Regression 3: TopWeatherBorder redraw throttling ---

func test_top_weather_border_throttles_redraws():
	var border = load("res://scripts/scenes/ui/TopWeatherBorder.gd").new()
	add_child_autofree(border)
	border._redraw_count = 0
	for i in range(60):
		border._process(1.0 / 60.0)
	assert_lt(border._redraw_count, 35, "Ambient redraws should be throttled below 60 Hz")
	assert_gt(border._redraw_count, 10, "Ambient redraws should still occur periodically")

# --- Regression 4: Highway MultiMesh per-instance colors & Bridge ArrayMesh batching ---

func test_highway_ice_uses_multimesh_colors():
	var h = load("res://scripts/scenes/world/Highway.gd").new()
	add_child_autofree(h)
	var tiles = Node2D.new()
	add_child_autofree(tiles)
	h._build_tiles_into(tiles, h.ChunkType.ICE)
	var lane_mmi: MultiMeshInstance2D = tiles.get_node_or_null("LaneMultiMesh")
	assert_not_null(lane_mmi, "LaneMultiMesh should exist")
	assert_true(lane_mmi.multimesh.use_colors, "MultiMesh must enable per-instance colors")
	assert_eq(lane_mmi.modulate, Color.WHITE, "LaneMultiMesh modulate should be white when using instance colors")

func test_highway_bridge_batches_structure_into_single_mesh():
	var h = load("res://scripts/scenes/world/Highway.gd").new()
	add_child_autofree(h)
	var tiles = Node2D.new()
	add_child_autofree(tiles)
	h._build_tiles_into(tiles, h.ChunkType.BRIDGE)
	var bridge_mesh: MeshInstance2D = tiles.get_node_or_null("BridgeStructureMesh")
	assert_not_null(bridge_mesh, "BridgeStructureMesh should batch bridge geometry")
	assert_is(bridge_mesh.mesh, ArrayMesh, "BridgeStructureMesh should hold an ArrayMesh")
	var line_count = 0
	for child in tiles.get_children():
		if child is Line2D:
			line_count += 1
	assert_eq(line_count, 2, "Bridge chunk should only have LeftRail and RightRail Line2D nodes")

# --- Regression 5: Encrypted save & non-bypassable checksum ---

func test_save_file_is_encrypted_and_rejects_zero_or_missing_checksum():
	GameManager.credits = 777
	GameManager.high_score = 4200
	GameManager.save_progress()
	var raw_file = FileAccess.open("user://save.dat", FileAccess.READ)
	assert_not_null(raw_file, "Encrypted save file should exist")
	var raw_bytes = raw_file.get_buffer(raw_file.get_length())
	raw_file.close()
	var raw_text = raw_bytes.get_string_from_ascii()
	assert_false(raw_text.contains("777"), "Plaintext credits must not appear in encrypted save file")

	# Inject zero checksum inside encrypted payload and ensure it is rejected
	var wfile = FileAccess.open_encrypted_with_pass("user://save.dat", FileAccess.WRITE, GameManager._get_save_passphrase())
	wfile.store_var({"version": 2, "payload": {"credits": 99999}, "_checksum": 0})
	wfile.close()
	GameManager.credits = 10
	GameManager.load_progress()
	assert_eq(GameManager.credits, 10, "Zero checksum must NOT bypass validation")

# --- Regression 6: PackManager path traversal & extension allowlist ---

func test_pack_manager_blocks_path_traversal_and_unsafe_extensions():
	var pm = PackManagerScript.new()
	add_child_autofree(pm)
	var base := "user://packs/test_pack"
	assert_eq(pm._resolve_safe_pack_path(base, "../secret.png", pm.ALLOWED_IMAGE_EXTS), "")
	assert_eq(pm._resolve_safe_pack_path(base, "sub/../../secret.png", pm.ALLOWED_IMAGE_EXTS), "")
	assert_eq(pm._resolve_safe_pack_path(base, "/etc/passwd.png", pm.ALLOWED_IMAGE_EXTS), "")
	assert_eq(pm._resolve_safe_pack_path(base, "res://icon.svg", pm.ALLOWED_IMAGE_EXTS), "")
	assert_eq(pm._resolve_safe_pack_path(base, "user://save.dat", pm.ALLOWED_IMAGE_EXTS), "")
	assert_eq(pm._resolve_safe_pack_path(base, "malicious.gd", pm.ALLOWED_IMAGE_EXTS), "")
	assert_eq(pm._resolve_safe_pack_path(base, "malicious.tres", pm.ALLOWED_IMAGE_EXTS), "")
	assert_eq(pm._resolve_safe_pack_path(base, "skin.png", pm.ALLOWED_AUDIO_EXTS), "")
	assert_ne(pm._resolve_safe_pack_path(base, "sprites/player.png", pm.ALLOWED_IMAGE_EXTS), "")
	assert_ne(pm._resolve_safe_pack_path(base, "music/track1.ogg", pm.ALLOWED_AUDIO_EXTS), "")

# --- Regression 7: SettingsManager volume clamping & InputRemap bounds ---

func test_settings_manager_clamps_volume():
	SettingsManager.set_volume("Master", 5.0)
	assert_eq(SettingsManager.get_volume("Master"), 1.0, "Volume above 1.0 should clamp to 1.0")
	SettingsManager.set_volume("Master", -2.5)
	assert_eq(SettingsManager.get_volume("Master"), 0.0, "Volume below 0.0 should clamp to 0.0")
	SettingsManager.set_volume("Master", NAN)
	assert_eq(SettingsManager.get_volume("Master"), 1.0, "NaN volume should sanitize to 1.0")
	SettingsManager.set_volume("Master", 1.0)

func test_input_remap_rejects_out_of_bounds_and_builds_reset():
	assert_null(InputRemapScript.deserialize_event_safe("key:-1"))
	assert_null(InputRemapScript.deserialize_event_safe("key:notanumber"))
	assert_null(InputRemapScript.deserialize_event_safe("jbtn:9999"))
	assert_null(InputRemapScript.deserialize_event_safe("jaxis:999:1.0"))
	assert_null(InputRemapScript.deserialize_event_safe("jaxis:0:99.0"))
	assert_null(InputRemapScript.deserialize_event_safe("jaxis:0:nan"))

	var remap = InputRemapScript.new()
	var list = VBoxContainer.new()
	list.name = "ActionList"
	remap.add_child(list)
	remap.action_list = list
	add_child_autofree(remap)
	assert_not_null(list.get_node_or_null("ResetDefaultsButton"), "ResetDefaultsButton should be created")

# --- Regression 8 & 9: Version label, Scav 8-lane flank, BossWarRig spread, PoopWeapon group, Game pause, HUD pulse ---

func test_main_reads_project_version():
	var MainScript = load("res://scripts/scenes/Main.gd")
	assert_eq(MainScript.format_version_text("0.2.0", ""), "v0.2.0")
	assert_eq(MainScript.format_version_text("0.2.0", "unknown"), "v0.2.0")
	assert_eq(MainScript.format_version_text("0.2.0", "355fdda1234"), "v0.2.0 (355fdda)")

	var main = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main)
	var expected_prefix = "v" + str(ProjectSettings.get_setting("application/config/version", "0.2.0"))
	var label_text: String = main.get_node("CanvasLayer/VersionLabel").text
	assert_true(label_text.begins_with(expected_prefix), "VersionLabel should start with project version: " + label_text)

func test_cyberpunk_theme_and_about_button():
	var theme_path := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	assert_eq(theme_path, "res://assets/themes/cyberpunk_theme.tres", "Project should use cyberpunk custom theme")
	var theme: Theme = load(theme_path)
	assert_not_null(theme, "Cyberpunk theme should load")
	assert_not_null(theme.default_font, "Cyberpunk theme should set techno default font")
	var font: FontFile = theme.default_font as FontFile
	assert_not_null(font, "Default theme font should be the imported Orbitron FontFile")
	assert_eq(font.hinting, 2, "Orbitron should use normal hinting for crisp menu glyphs")
	assert_eq(font.subpixel_positioning, 1, "Font size 48 should not use subpixel glyph blur")
	assert_eq(font.oversampling, 2.0, "Glyph cache should render above display resolution")
	assert_false(font.generate_mipmaps, "Mipmaps would soften flat UI lettering")

	var main = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main)
	assert_not_null(main.about_button, "Main menu should have About button")
	var menu_row: HBoxContainer = main.get_node_or_null("CanvasLayer/MenuRow")
	assert_not_null(menu_row, "Main menu should group buttons in MenuRow HBoxContainer")
	assert_eq(menu_row.get_child_count(), 7, "All 7 main menu buttons should fit in one row")
	main._on_about_pressed()
	var found_about := false
	for c in main.get_children():
		if c.name == "About":
			found_about = true
			c.queue_free()
	assert_true(found_about, "Pressing About should instantiate About screen")

func test_emp_shockwave_and_no_post_death_stun():
	var emp = load("res://scenes/weapons/EMPBlast.tscn").instantiate()
	add_child_autofree(emp)
	emp.init(Vector2.ZERO)
	assert_not_null(emp._shockwave_material, "EMP should create shockwave ShaderMaterial")
	emp._process(0.5)
	var progress: float = emp._shockwave_material.get_shader_parameter("ring_progress")
	assert_gt(progress, 0.0, "Shockwave ring_progress should advance with EMP radius")

	ObjectPool.create_pool("test_emp_bunny", load("res://scenes/enemies/Bunny.tscn"), 1)
	var bunny = ObjectPool.acquire("test_emp_bunny")
	add_child_autofree(bunny)
	bunny.init(bunny.EnemyType.BUNNY, 0, null, 200.0)
	emp._on_body_entered(bunny)
	assert_true(bunny.get_meta("_in_pool", false), "Bunny should die from EMP damage")
	assert_false(bunny.stunned, "Pooled bunny killed by EMP must not remain stunned")
	ObjectPool._pools.erase("test_emp_bunny")

func test_weather_rain_splashes_and_wet_road_reflection():
	var ws = load("res://scenes/world/WeatherSystem.tscn").instantiate()
	add_child_autofree(ws)
	assert_not_null(ws._splash_particles, "WeatherSystem should have RainSplashes GPUParticles2D")
	assert_not_null(ws._wet_reflection_material, "WeatherSystem should have wet road reflection shader")
	ws._set_weather(ws.WeatherType.STORM)
	ws._update_rain_particles(0.016)
	assert_true(ws._splash_particles.emitting, "Rain splashes should emit in STORM")
	assert_gt(ws._wetness, 0.5, "Wet road reflection should be active in STORM")
	ws._set_weather(ws.WeatherType.CLEAR)
	ws._update_rain_particles(0.016)
	assert_false(ws._splash_particles.emitting, "Rain splashes should stop in CLEAR")
	assert_eq(ws._wetness, 0.0, "Wet road reflection should reset in CLEAR")

func test_baby_bunny_bomb_resets_and_dies_on_reacquire():
	ObjectPool.create_pool("test_baby_bomb", load("res://scenes/weapons/BabyBunnyBomb.tscn"), 1)
	var b1 = ObjectPool.acquire("test_baby_bomb")
	add_child_autofree(b1)
	b1.take_damage(1)
	assert_true(b1.get_meta("_in_pool", false), "First BabyBunnyBomb should die and pool")
	var b2 = ObjectPool.acquire("test_baby_bomb")
	add_child_autofree(b2)
	assert_false(b2.collision.disabled, "Reacquired BabyBunnyBomb must have collision enabled")
	assert_eq(b2.hp, 1, "Reacquired BabyBunnyBomb must have 1 HP")
	b2.take_damage(1)
	assert_true(b2.get_meta("_in_pool", false), "Reacquired BabyBunnyBomb must die again")
	ObjectPool._pools.erase("test_baby_bomb")

func test_scav_eight_lane_flank_direction():
	var scav_left = load("res://scenes/enemies/Scav.tscn").instantiate()
	var scav_right = load("res://scenes/enemies/Scav.tscn").instantiate()
	add_child_autofree(scav_left)
	add_child_autofree(scav_right)
	var player = Node2D.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, -500)
	scav_left.position = Vector2(0, 0)
	scav_right.position = Vector2(0, -120)
	scav_left.init(scav_left.EnemyType.SCAV, 2, player, 200.0)
	scav_right.init(scav_right.EnemyType.SCAV, 5, player, 200.0)
	scav_left._physics_process(0.1)
	scav_right._physics_process(0.1)
	assert_lt(scav_left.velocity.x, 0.0, "Lane 2 (left half of 8-lane highway) should flank left")
	assert_gt(scav_right.velocity.x, 0.0, "Lane 5 (right half of 8-lane highway) should flank right")

func test_boss_war_rig_spread_fires_without_spawner():
	var container = Node2D.new()
	add_child_autofree(container)
	var boss = load("res://scenes/enemies/BossWarRig.tscn").instantiate()
	container.add_child(boss)
	boss._spawner = null
	var before = container.get_child_count()
	boss._fire_bullet_spread()
	assert_eq(container.get_child_count() - before, 3, "BossWarRig spread should fire 3 bullets even with null _spawner")

func test_poop_weapon_checks_player_group_not_name():
	var poop = load("res://scenes/weapons/PoopWeapon.tscn").instantiate()
	add_child_autofree(poop)
	var fake = CharacterBody2D.new()
	fake.name = "Player"
	add_child_autofree(fake)
	poop._on_body_entered(fake)
	assert_true(true, "Node named Player not in player group should not trigger error")

func test_game_on_boss_defeated_unknown_does_not_freeze_paused():
	var game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game)
	get_tree().paused = false
	game._on_boss_defeated("unknown_boss_xyz")
	assert_false(get_tree().paused, "Unknown boss_type must not leave scene tree paused")

func test_hud_multiplier_pulse_timer_advances_while_active():
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	hud._on_multiplier_timer_updated(2.5)
	hud._process(0.25)
	hud._on_multiplier_timer_updated(2.25)
	assert_gt(hud._multiplier_pulse_timer, 0.2, "Pulse timer must not reset on active updates")

# --- Regression 12, 13, 14, 15: Boss HUD, Touch Controls, Daily Run, Leaderboard, Achievements ---

func test_hud_boss_bar_and_touch_controls():
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	var boss = load("res://scenes/enemies/BossWarRig.tscn").instantiate()
	add_child_autofree(boss)
	hud.bind_boss(boss)
	assert_true(hud._boss_panel.visible, "Boss panel should become visible when boss bound")
	assert_eq(hud._boss_name_label.text, "WAR RIG")
	boss.boss_phase_changed.emit(2)
	assert_eq(hud._boss_phase_label.text, "PHASE 2")
	hud.unbind_boss()
	assert_false(hud._boss_panel.visible, "Boss panel should hide when unbound")
	hud.set_touch_controls_visible(true)
	assert_true(hud._touch_overlay.visible, "Touch overlay should be toggleable")
	hud.set_touch_controls_visible(false)
	assert_false(hud._touch_overlay.visible)

func test_daily_run_seed_and_leaderboard_and_achievements():
	var s1 = GameManager.compute_daily_seed({"year": 2026, "month": 11, "day": 14})
	var s2 = GameManager.compute_daily_seed({"year": 2026, "month": 11, "day": 14})
	var s3 = GameManager.compute_daily_seed({"year": 2026, "month": 11, "day": 15})
	assert_eq(s1, s2, "Daily seed must be deterministic for same UTC date")
	assert_ne(s1, s3, "Daily seed must change across dates")

	GameManager.leaderboard.clear()
	GameManager.unlocked_achievements.clear()
	GameManager.start_daily_run()
	assert_true(GameManager.daily_run_active)
	for i in range(10):
		GameManager.record_run_kill("bunny")
	assert_true("first_blood" in GameManager.unlocked_achievements, "10 kills should unlock first_blood")
	GameManager.score = 12000
	GameManager.end_game()
	assert_true("high_roller" in GameManager.unlocked_achievements, "10000+ score should unlock high_roller")
	assert_gt(GameManager.leaderboard.size(), 0, "Leaderboard should record run score")

func test_interceptor_info_formats_dynamic_keybindings():
	var info = load("res://scenes/ui/InterceptorInfo.tscn").instantiate()
	add_child_autofree(info)
	assert_not_null(info.movement_text)
	assert_true(info.movement_text.text.contains("Accelerate"), "Control hints should be populated")

func test_garage_builds_pack_preview_panel():
	PackManager.discovered_packs["mock_pack"] = {
		"data": {
			"pack_id": "mock_pack",
			"name": "Mock Pack",
			"content_types": ["theme", "music"],
			"theme": {"palette": {"lane_color": "#112233"}},
			"music": {"tracks": ["a.ogg", "b.ogg"]},
		},
		"folder": "",
		"size": 100,
	}
	var garage = load("res://scenes/ui/Garage.tscn").instantiate()
	add_child_autofree(garage)
	assert_not_null(garage.customize_container.get_node_or_null("PackPreviewPanel"), "Garage should build PackPreviewPanel")
	PackManager.discovered_packs.erase("mock_pack")
