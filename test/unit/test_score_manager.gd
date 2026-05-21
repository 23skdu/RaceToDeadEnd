extends GutTest

var ScoreManagerScript

class SignalCapture:
	var points = 0
	func capture(_pos, p, _label):
		points = p

func before_all():
	ScoreManagerScript = load("res://autoload/ScoreManager.gd")

func before_each():
	var save_path = "user://save.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	GameManager.state = GameManager.GameState.MENU
	GameManager.score = 0
	GameManager.health = 5
	GameManager.max_health = 5
	GameManager.multiplier = 1
	GameManager._score_timer = 0.0
	GameManager._difficulty_progress = 0.0
	GameManager._multiplier_timer = 0.0
	GameManager._base_multiplier = 1

func test_register_kill_rotor():
	GameManager.start_game()
	ScoreManager.register_kill("rotor", Vector2(100, 200))
	assert_eq(GameManager.score, 50, "Rotor kill should give 50 points")

func test_register_kill_scav():
	GameManager.start_game()
	ScoreManager.register_kill("scav", Vector2(100, 200))
	assert_eq(GameManager.score, 100, "Scav kill should give 100 points")

func test_register_kill_drone():
	GameManager.start_game()
	ScoreManager.register_kill("drone", Vector2(100, 200))
	assert_eq(GameManager.score, 200, "Drone kill should give 200 points")

func test_register_kill_unknown():
	GameManager.start_game()
	ScoreManager.register_kill("unknown", Vector2(100, 200))
	assert_eq(GameManager.score, 50, "Unknown kill should default to 50 points")

func test_register_kill_with_multiplier():
	GameManager.start_game()
	GameManager.set_multiplier(2)
	ScoreManager.register_kill("rotor", Vector2(100, 200))
	assert_eq(GameManager.score, 100, "Rotor kill with 2x multiplier should give 100 points")

func test_register_civilian_protected():
	GameManager.start_game()
	ScoreManager.register_civilian_protected(Vector2(100, 200))
	assert_eq(GameManager.score, 500, "Civilian protected should give 500 points")

func test_register_pickup_repair():
	GameManager.start_game()
	GameManager.take_damage(2)
	var initial_health = GameManager.health
	ScoreManager.register_pickup("repair", Vector2(100, 200))
	assert_eq(GameManager.health, initial_health + 1, "Repair should restore 1 HP")

func test_register_pickup_multiplier_is_temporary():
	GameManager.start_game()
	ScoreManager.register_pickup("multiplier", Vector2(100, 200))
	assert_eq(GameManager.multiplier, 2, "Multiplier should increase")
	assert_eq(GameManager._multiplier_timer, 10.0, "Multiplier timer should be 10 seconds")

func test_register_pickup_boost():
	GameManager.start_game()
	var player = load("res://scenes/player/Interceptor.tscn").instantiate()
	player.add_to_group("player")
	add_child_autofree(player)
	player.boost_charges = 1
	var initial_charges = player.boost_charges
	ScoreManager.register_pickup("boost", Vector2(100, 200))
	assert_eq(player.boost_charges, initial_charges + 1, "Boost pickup should add charge")

func test_register_pickup_ammo():
	GameManager.start_game()
	var player = load("res://scenes/player/Interceptor.tscn").instantiate()
	player.add_to_group("player")
	add_child_autofree(player)
	player.secondary_ammo[0] = 0
	player.secondary_ammo[1] = 0
	player.secondary_ammo[2] = 0
	ScoreManager.register_pickup("ammo", Vector2(100, 200))
	assert_eq(player.secondary_ammo, [1, 1, 1], "Ammo pickup should add one to each type")

func test_score_values_constants():
	assert_eq(ScoreManagerScript.SCORE_VALUES.rotor_kill, 50, "Rotor kill value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.scav_kill, 100, "Scav kill value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.drone_kill, 200, "Drone kill value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.civilian_protected, 500, "Civilian protected value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.segment_bonus, 100, "Segment bonus value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.pickup_collected, 0, "Pickup collected value")

func test_register_kill_emits_signal():
	var sm = ScoreManagerScript.new()
	add_child_autofree(sm)
	watch_signals(sm)
	sm.register_kill("rotor", Vector2(100, 200))
	assert_signal_emitted(sm, "score_popped", "Should emit score_popped signal")

func test_register_civilian_protected_emits_signal():
	var sm = ScoreManagerScript.new()
	add_child_autofree(sm)
	watch_signals(sm)
	sm.register_civilian_protected(Vector2(100, 200))
	assert_signal_emitted(sm, "score_popped", "Should emit score_popped signal")

func test_register_kill_signal_contains_correct_points():
	var sm = ScoreManagerScript.new()
	add_child_autofree(sm)
	var capture = SignalCapture.new()
	sm.score_popped.connect(capture.capture)
	sm.register_kill("drone", Vector2(50, 50))
	assert_eq(capture.points, 200, "Signal should contain 200 points for drone")

func test_register_pickup_boost_no_player():
	GameManager.start_game()
	ScoreManager.register_pickup("boost", Vector2(100, 200))
	assert_true(true, "Should not crash when no player in group")

func test_register_pickup_ammo_no_player():
	GameManager.start_game()
	ScoreManager.register_pickup("ammo", Vector2(100, 200))
	assert_true(true, "Should not crash when no player in group")
