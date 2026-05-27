extends GutTest

var ScoreManagerScript

class SignalCapture:
	var points = 0
	func capture(_pos, p, _label):
		points = p

func before_all():
	ScoreManagerScript = load("res://scripts/autoload/ScoreManager.gd")

func before_each():
	var save_path = "user://save.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	GameManager.state = GameManager.GameState.MENU
	GameManager.score = 0
	GameManager.health = 5
	GameManager.max_health = 5
	GameManager.multiplier = 1
	if GameManager._score_ticker:
		GameManager._score_ticker.stop()
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
	var player = load("res://scenes/player/Interceptor.tscn").instantiate()
	player.add_to_group("player")
	add_child_autofree(player)
	player.boost_charges = 1
	GameManager.start_game()
	var initial_charges = player.boost_charges
	ScoreManager.register_pickup("boost", Vector2(100, 200))
	assert_eq(player.boost_charges, initial_charges + 1, "Boost pickup should add charge")

func test_register_pickup_ammo():
	var player = load("res://scenes/player/Interceptor.tscn").instantiate()
	player.add_to_group("player")
	add_child_autofree(player)
	player.secondary_ammo[0] = 0
	player.secondary_ammo[1] = 0
	player.secondary_ammo[2] = 0
	GameManager.start_game()
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

class LabelCapture:
	var label = ""
	func capture(_pos, _pts, l):
		label = l

func test_register_civilian_damaged_emits_civilian_hit():
	var sm = ScoreManagerScript.new()
	add_child_autofree(sm)
	var capture = LabelCapture.new()
	sm.score_popped.connect(capture.capture)
	sm.register_civilian_damaged()
	assert_eq(capture.label, "CIVILIAN HIT!", "Label should be CIVILIAN HIT!")

func test_on_game_started_caches_player():
	var sm = ScoreManagerScript.new()
	add_child_autofree(sm)
	var player = Node2D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	sm._on_game_started()
	assert_eq(sm._cached_player, player, "Should cache player from group")

func test_on_game_over_clears_player():
	var sm = ScoreManagerScript.new()
	add_child_autofree(sm)
	var player = Node2D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	sm._on_game_started()
	assert_not_null(sm._cached_player, "Player should be cached")
	sm._on_game_over(0)
	assert_null(sm._cached_player, "Player should be cleared on game over")

func test_on_game_started_no_player_graceful():
	var sm = ScoreManagerScript.new()
	add_child_autofree(sm)
	var saved_players = []
	for p in get_tree().get_nodes_in_group("player"):
		saved_players.append(p)
		p.remove_from_group("player")
	sm._on_game_started()
	for p in saved_players:
		p.add_to_group("player")
	assert_null(sm._cached_player, "Should handle no player gracefully")

func test_score_values_has_all_keys():
	assert_true(ScoreManagerScript.SCORE_VALUES.has("rotor_kill"), "Should have rotor_kill")
	assert_true(ScoreManagerScript.SCORE_VALUES.has("scav_kill"), "Should have scav_kill")
	assert_true(ScoreManagerScript.SCORE_VALUES.has("drone_kill"), "Should have drone_kill")
	assert_true(ScoreManagerScript.SCORE_VALUES.has("civilian_protected"), "Should have civilian_protected")
	assert_true(ScoreManagerScript.SCORE_VALUES.has("pickup_collected"), "Should have pickup_collected")
	assert_true(ScoreManagerScript.SCORE_VALUES.has("segment_bonus"), "Should have segment_bonus")
	assert_eq(ScoreManagerScript.SCORE_VALUES.size(), 8, "Should have exactly 8 entries")

func test_register_kill_with_bonus_multiplier():
	GameManager.start_game()
	GameManager.set_multiplier(3)
	ScoreManager.register_kill("rotor", Vector2.ZERO)
	assert_eq(GameManager.score, 150, "Rotor kill with 3x should give 150 points")
	ScoreManager.register_kill("scav", Vector2.ZERO)
	assert_eq(GameManager.score, 450, "Scav kill with 3x should give 300 additional (450 total)")

func test_register_kill_with_max_multiplier():
	GameManager.start_game()
	GameManager.set_multiplier(8)
	ScoreManager.register_kill("drone", Vector2.ZERO)
	assert_eq(GameManager.score, 1600, "Drone kill with 8x should give 1600 points")
