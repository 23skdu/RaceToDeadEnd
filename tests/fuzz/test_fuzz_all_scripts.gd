extends GutTest

const HelpersUtil = preload("res://scripts/utils/Helpers.gd")
const WeaponDataRes = preload("res://scripts/resources/WeaponData.gd")
const ScreenshotManagerScript = preload("res://scripts/autoload/ScreenshotManager.gd")
const PostProcessingScript = preload("res://scripts/autoload/PostProcessing.gd")
const DemoSceneScript = preload("res://demo/DemoScene.gd")
const RunTestsScript = preload("res://scripts/run_tests.gd")

var _rng: RandomNumberGenerator

func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 20261115

func test_fuzz_autoloads_and_utilities() -> void:
	# AudioManager + Constants + CameraShake + ScoreManager + TransitionLayer + ScreenshotManager
	var prev_track := AudioManager.get_music_track()
	for i in range(40):
		var track_id := "track_%d" % _rng.randi_range(-10, 50)
		AudioManager.set_music_track(track_id, false)
		assert_eq(AudioManager.get_music_track(), "dynamic")
		if i % 5 == 0:
			AudioManager.restart_music()
		if i % 7 == 0:
			AudioManager.start_car_audio()
		elif i % 7 == 3:
			AudioManager.stop_car_audio()
		CameraShake.shake(_rng.randf_range(-2.0, 5.0), _rng.randf_range(-1.0, 2.0), _rng.randf_range(-5.0, 20.0))
		CameraShake.rumble(_rng.randf_range(-1.0, 2.0), _rng.randf_range(-1.0, 2.0))
		ScoreManager.register_kill(["bunny", "rotor", "scav", "drone", "sasquatch", "unknown"][i % 6], Vector2(_rng.randf_range(-500, 500), _rng.randf_range(-500, 500)))
	AudioManager.set_music_track(prev_track, false)

	var sm = ScreenshotManagerScript.new()
	sm.show_feedback = false
	add_child_autofree(sm)
	for i in range(25):
		assert_eq(sm.save_screenshot_image(null, "user://fuzz_ss_%d" % i), "")
		var candidate: String = sm.build_screenshot_path("user://fuzz_screenshots")
		assert_true(candidate.ends_with(".png"))

	# TransitionLayer fade clamping / rapid re-trigger
	TransitionLayer.fade_to_black(0.0)
	TransitionLayer.fade_from_black(0.0)
	assert_not_null(TransitionLayer._overlay)

	# Helpers + WeaponData + Constants
	var sp := Sprite2D.new()
	add_child_autofree(sp)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	sp.texture = ImageTexture.create_from_image(img)
	for i in range(25):
		HelpersUtil.scale_sprite_to_viewport(sp, _rng.randf_range(16.0, 128.0), Constants.SPRITE_BASE_VIEWPORT)
		assert_gt(sp.scale.x, 0.0)
		var wd := WeaponDataRes.new()
		wd.base_ammo = _rng.randi_range(1, 50)
		wd.display_name = "Weapon %d" % i
		assert_gt(wd.base_ammo, 0)

	# PostProcessing fuzz
	var pp = PostProcessingScript.new()
	add_child_autofree(pp)
	for i in range(20):
		pp.set_enabled(i % 2 == 0)
		pp.scanline_intensity = _rng.randf_range(0.0, 1.0)
		pp.vignette_intensity = _rng.randf_range(0.0, 1.0)
		pp.chromatic_aberration = _rng.randf_range(0.0, 0.006)
		pp.bloom_intensity = _rng.randf_range(0.0, 1.0)
		pp.film_grain = _rng.randf_range(0.0, 0.15)
		pp._apply_uniforms()
	assert_not_null(pp._rect)

func test_fuzz_enemies_and_bosses_damage_and_physics() -> void:
	var mock_player := Node2D.new()
	add_child_autofree(mock_player)

	var enemy_scenes := [
		preload("res://scenes/enemies/Bunny.tscn"),
		preload("res://scenes/enemies/Rotor.tscn"),
		preload("res://scenes/enemies/Scav.tscn"),
		preload("res://scenes/enemies/Drone.tscn"),
		preload("res://scenes/enemies/Civilian.tscn"),
	]
	for scene in enemy_scenes:
		var inst = scene.instantiate()
		add_child_autofree(inst)
		for i in range(15):
			var lane := _rng.randi_range(0, Constants.LANE_COUNT - 1)
			if inst.has_method("init"):
				if scene.resource_path.ends_with("Civilian.tscn"):
					inst.init(lane, _rng.randf_range(50.0, 400.0), 1.0 if i % 2 == 0 else -1.0, mock_player)
				else:
					inst.init(i % 5, lane, mock_player, _rng.randf_range(50.0, 400.0), null)
			inst._physics_process(0.016)
			if inst.has_method("apply_stun"):
				inst.apply_stun(_rng.randf_range(0.05, 1.0))
			inst.take_damage(0)
		assert_not_null(inst)

	var boss_scenes := [
		preload("res://scenes/enemies/BossBunny.tscn"),
		preload("res://scenes/enemies/BossGiantBiker.tscn"),
		preload("res://scenes/enemies/BossSasquatch.tscn"),
		preload("res://scenes/enemies/BossVoidDrone.tscn"),
		preload("res://scenes/enemies/BossWarRig.tscn"),
	]
	for bscene in boss_scenes:
		var boss = bscene.instantiate()
		boss.player = mock_player
		add_child_autofree(boss)
		for i in range(12):
			boss.hp = _rng.randi_range(1, 60)
			boss._physics_process(0.016)
			boss.on_pool_acquire()
			boss.on_pool_release()
		assert_not_null(boss)

func test_fuzz_weapons_behavior_under_random_inputs() -> void:
	var weapon_scenes := [
		preload("res://scenes/weapons/Bullet.tscn"),
		preload("res://scenes/weapons/Mine.tscn"),
		preload("res://scenes/weapons/EMPBlast.tscn"),
		preload("res://scenes/weapons/DroneBomb.tscn"),
		preload("res://scenes/weapons/ChainSwing.tscn"),
		preload("res://scenes/weapons/PoopWeapon.tscn"),
		preload("res://scenes/weapons/BabyBunnyBomb.tscn"),
	]
	for wscene in weapon_scenes:
		var w = wscene.instantiate()
		add_child_autofree(w)
		for i in range(10):
			var pos := Vector2(_rng.randf_range(-400.0, 400.0), _rng.randf_range(-400.0, 400.0))
			if wscene.resource_path.ends_with("Bullet.tscn") or wscene.resource_path.ends_with("PoopWeapon.tscn"):
				w.init(pos, Vector2(0, -1 if i % 2 == 0 else 1), i % 2 == 0)
			elif wscene.resource_path.ends_with("BabyBunnyBomb.tscn"):
				w.init(0, i % Constants.LANE_COUNT, null, 150.0)
			elif w.has_method("init"):
				w.init(pos)
			elif w.has_method("swing"):
				w.swing()
			if w.has_method("_physics_process"):
				w._physics_process(0.016)
			elif w.has_method("_process"):
				w._process(0.016)
		assert_not_null(w)

func test_fuzz_player_weather_and_scenes() -> void:
	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var interceptor = preload("res://scenes/player/Interceptor.tscn").instantiate()
	add_child_autofree(interceptor)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	for i in range(25):
		interceptor.current_lane = _rng.randi_range(-3, 12)
		interceptor.target_x = interceptor._lane_to_x(interceptor.current_lane)
		assert_true(interceptor.target_x >= Constants.LANE_POSITIONS[0] and interceptor.target_x <= Constants.LANE_POSITIONS[-1])
		interceptor.set_slippery(i % 2 == 0)
		interceptor._update_timers(_rng.randf_range(0.01, 0.25))
		assert_not_null(interceptor.get_node_or_null("BoostExhaust"))
		assert_not_null(interceptor.get_node_or_null("MuzzleFlash"))

	var ws = preload("res://scenes/world/WeatherSystem.tscn").instantiate()
	add_child_autofree(ws)
	for i in range(20):
		ws.set_weather(_rng.randi_range(0, 3))
		ws._process(0.05)
	assert_not_null(ws)

	# Fuzz Game, Main, DemoScene, and run_tests.gd metadata
	var main = preload("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main)
	for i in range(15):
		var formatted: String = main.format_version_text("v0.%d.%d" % [i, i + 1], "abcdef123456")
		assert_true(formatted.begins_with("v0."))

	ProjectSettings.set_setting("physics/common/physics_interpolation", false)
	var game = preload("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	for i in range(10):
		game._on_segment_completed(i)
	assert_not_null(game)

	var demo = DemoSceneScript.new()
	demo.duration = 10.0
	add_child_autofree(demo)
	for i in range(10):
		demo._process(0.05)
		demo.queue_redraw()
	assert_not_null(RunTestsScript)

func test_fuzz_ui_screens_and_widgets() -> void:
	var ui_scenes := [
		preload("res://scenes/ui/About.tscn"),
		preload("res://scenes/ui/GameOver.tscn"),
		preload("res://scenes/ui/Garage.tscn"),
		preload("res://scenes/ui/HUD.tscn"),
		preload("res://scenes/ui/InterceptorInfo.tscn"),
		preload("res://scenes/ui/Options.tscn"),
		preload("res://scenes/ui/PauseMenu.tscn"),
	]
	for uscene in ui_scenes:
		var ui = uscene.instantiate()
		add_child_autofree(ui)
		assert_not_null(ui)

	var wb = preload("res://scripts/scenes/ui/TopWeatherBorder.gd").new()
	add_child_autofree(wb)
	var weather_names := ["clear", "light_rain", "acid_rain", "storm", "unknown"]
	for i in range(20):
		wb._on_weather_changed(weather_names[_rng.randi() % weather_names.size()])
		wb._process(_rng.randf_range(0.01, 0.2))
	assert_not_null(wb)

# --- GUT post-run orphan guard fuzz coverage ---

const OrphanGuard = preload("res://tests/gut_orphan_guard.gd")

class OrphanGuardFuzzOrphanage extends RefCounted:
	func clean() -> void:
		pass

class OrphanGuardFuzzCounter extends RefCounted:
	var live: int = 0
	var recorded: int = 0
	var orphanage: OrphanGuardFuzzOrphanage = OrphanGuardFuzzOrphanage.new()

	func orphan_count() -> int:
		return live

	func get_orphan_ids(_group = null, _subgroup = null) -> Array:
		var ids := []
		for i in recorded:
			ids.append(i)
		return ids

class OrphanGuardFuzzLogger extends RefCounted:
	var messages: Array[String] = []

	func error(message: String) -> void:
		messages.append(message)

	func log(message: String) -> void:
		messages.append(message)

class OrphanGuardFuzzGut extends RefCounted:
	var counter: OrphanGuardFuzzCounter = OrphanGuardFuzzCounter.new()
	var logger: OrphanGuardFuzzLogger = OrphanGuardFuzzLogger.new()

	func get_orphan_counter() -> OrphanGuardFuzzCounter:
		return counter

func test_fuzz_orphan_guard_counts_and_exit_codes() -> void:
	for i in 50:
		var live: int = _rng.randi_range(0, 4)
		var recorded: int = _rng.randi_range(0, 8)
		var gut := OrphanGuardFuzzGut.new()
		gut.counter.live = live
		gut.counter.recorded = recorded
		var counts: Dictionary = OrphanGuard.orphan_counts(gut)
		assert_eq(counts.get("live"), live)
		assert_eq(counts.get("recorded"), recorded)
		var guard = OrphanGuard.new()
		guard.gut = gut
		guard.run()
		if live == 0 and recorded == 0:
			assert_null(guard.get_exit_code())
		else:
			assert_eq(guard.get_exit_code(), 1)
