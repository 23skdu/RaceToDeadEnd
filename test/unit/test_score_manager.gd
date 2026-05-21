extends GutTest

var ScoreManagerScript

func before_all():
	ScoreManagerScript = load("res://autoload/ScoreManager.gd")

func before_each():
	var sm = ScoreManagerScript.new()
	add_child_autofree(sm)
	set_meta("sm", sm)

func get_sm():
	return get_meta("sm")

func test_register_kill_rotor():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	sm.register_kill("rotor", Vector2(100, 200))
	assert_eq(gm.score, 50, "Rotor kill should give 50 points")

func test_register_kill_scav():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	sm.register_kill("scav", Vector2(100, 200))
	assert_eq(gm.score, 100, "Scav kill should give 100 points")

func test_register_kill_drone():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	sm.register_kill("drone", Vector2(100, 200))
	assert_eq(gm.score, 200, "Drone kill should give 200 points")

func test_register_kill_unknown():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	sm.register_kill("unknown", Vector2(100, 200))
	assert_eq(gm.score, 50, "Unknown kill should default to 50 points")

func test_register_kill_with_multiplier():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	gm.set_multiplier(2)
	sm.register_kill("rotor", Vector2(100, 200))
	assert_eq(gm.score, 100, "Rotor kill with 2x multiplier should give 100 points")

func test_register_civilian_protected():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	sm.register_civilian_protected(Vector2(100, 200))
	assert_eq(gm.score, 500, "Civilian protected should give 500 points")

func test_register_pickup_repair():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	gm.take_damage(2)
	var initial_health = gm.health
	sm.register_pickup("repair", Vector2(100, 200))
	assert_eq(gm.health, initial_health + 1, "Repair should restore 1 HP")

func test_register_pickup_multiplier_is_temporary():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	sm.register_pickup("multiplier", Vector2(100, 200))
	assert_eq(gm.multiplier, 2, "Multiplier should increase")
	assert_eq(gm._multiplier_timer, 10.0, "Multiplier timer should be 10 seconds")

func test_register_pickup_boost():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	var player = load("res://scenes/player/Interceptor.tscn").instantiate()
	player.add_to_group("player")
	add_child_autofree(player)
	var initial_charges = player.boost_charges
	player.boost_charges = 1
	sm.register_pickup("boost", Vector2(100, 200))
	assert_eq(player.boost_charges, initial_charges, "Boost pickup should add charge")

func test_register_pickup_ammo():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	var player = load("res://scenes/player/Interceptor.tscn").instantiate()
	player.add_to_group("player")
	add_child_autofree(player)
	var initial_ammo = player.secondary_ammo.duplicate()
	player.secondary_ammo = [0, 0, 0]
	sm.register_pickup("ammo", Vector2(100, 200))
	assert_eq(player.secondary_ammo, [1, 1, 1], "Ammo pickup should add one to each type")

func test_score_values_constants():
	assert_eq(ScoreManagerScript.SCORE_VALUES.rotor_kill, 50, "Rotor kill value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.scav_kill, 100, "Scav kill value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.drone_kill, 200, "Drone kill value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.civilian_protected, 500, "Civilian protected value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.segment_bonus, 100, "Segment bonus value")
	assert_eq(ScoreManagerScript.SCORE_VALUES.pickup_collected, 0, "Pickup collected value")

func test_register_kill_emits_signal():
	var sm = get_sm()
	watch_signals(sm)
	sm.register_kill("rotor", Vector2(100, 200))
	assert_signal_emitted(sm, "score_popped", "Should emit score_popped signal")

func test_register_civilian_protected_emits_signal():
	var sm = get_sm()
	watch_signals(sm)
	sm.register_civilian_protected(Vector2(100, 200))
	assert_signal_emitted(sm, "score_popped", "Should emit score_popped signal")

func test_register_kill_signal_contains_correct_points():
	var sm = get_sm()
	watch_signals(sm)
	sm.register_kill("drone", Vector2(50, 50))
	var signal_args = get_signal_parameters(sm, "score_popped")
	assert_eq(signal_args[0][1], 200, "Signal should contain 200 points for drone")

func test_register_pickup_boost_no_player():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	sm.register_pickup("boost", Vector2(100, 200))
	assert_true(true, "Should not crash when no player in group")

func test_register_pickup_ammo_no_player():
	var sm = get_sm()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	sm.register_pickup("ammo", Vector2(100, 200))
	assert_true(true, "Should not crash when no player in group")
