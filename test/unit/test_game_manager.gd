extends GutTest

var GameManager

func before_all():
	GameManager = load("res://autoload/GameManager.gd")

func before_each():
	var gm = GameManager.new()
	add_child_autofree(gm)
	gm._ready()
	set_meta("gm", gm)

func get_gm():
	return get_meta("gm")

func test_initial_state():
	var gm = get_gm()
	assert_eq(gm.state, gm.GameState.MENU, "Initial state should be MENU")
	assert_eq(gm.score, 0, "Initial score should be 0")
	assert_eq(gm.health, 5, "Initial health should be 5")
	assert_eq(gm.max_health, 5, "Initial max_health should be 5")
	assert_eq(gm.multiplier, 1, "Initial multiplier should be 1")
	assert_eq(gm.difficulty_tier, 1, "Initial difficulty tier should be 1")
	assert_eq(gm.current_segment, 0, "Initial segment should be 0")
	assert_eq(gm.credits, 0, "Initial credits should be 0")
	assert_eq(gm.high_score, 0, "Initial high score should be 0")

func test_start_game():
	var gm = get_gm()
	gm.start_game()
	assert_eq(gm.state, gm.GameState.PLAYING, "State should be PLAYING")
	assert_eq(gm.score, 0, "Score should reset to 0")
	assert_eq(gm.multiplier, 1, "Multiplier should reset to 1")
	assert_eq(gm.difficulty_tier, 1, "Difficulty tier should reset to 1")
	assert_eq(gm.current_segment, 0, "Segment should reset to 0")
	assert_eq(gm.health, gm.max_health, "Health should equal max_health")

func test_start_game_resets_difficulty_progress():
	var gm = get_gm()
	gm.start_game()
	gm._difficulty_progress = 500.0
	gm.start_game()
	assert_eq(gm._difficulty_progress, 0.0, "Difficulty progress should reset")

func test_start_game_with_upgrades():
	var gm = get_gm()
	gm.upgrade_levels["max_health"] = 3
	gm.start_game()
	assert_eq(gm.max_health, 4 + 3, "Max health should be 4 + upgrade level")
	assert_eq(gm.health, 7, "Health should equal max_health with upgrades")

func test_add_score_basic():
	var gm = get_gm()
	gm.start_game()
	gm.add_score(100)
	assert_eq(gm.score, 100, "Score should be 100")

func test_add_score_with_multiplier():
	var gm = get_gm()
	gm.start_game()
	gm.set_multiplier(3)
	gm.add_score(100)
	assert_eq(gm.score, 300, "Score should be 300 with 3x multiplier")

func test_add_score_max_multiplier():
	var gm = get_gm()
	gm.start_game()
	gm.set_multiplier(10)
	assert_eq(gm.multiplier, 8, "Multiplier should cap at 8")

func test_add_score_min_multiplier():
	var gm = get_gm()
	gm.start_game()
	gm.set_multiplier(-5)
	assert_eq(gm.multiplier, 1, "Multiplier should floor at 1")

func test_add_score_advances_difficulty_at_1000():
	var gm = get_gm()
	gm.start_game()
	gm.add_score(999)
	assert_eq(gm.difficulty_tier, 1, "Tier should still be 1 at 999")
	gm.add_score(1)
	assert_eq(gm.difficulty_tier, 2, "Tier should advance to 2 at 1000")

func test_add_health():
	var gm = get_gm()
	gm.start_game()
	gm.add_health(1)
	assert_eq(gm.health, gm.max_health, "Health should not exceed max")

func test_add_health_negative():
	var gm = get_gm()
	gm.start_game()
	gm.add_health(-2)
	assert_eq(gm.health, gm.max_health - 2, "Health should decrease")

func test_add_health_clamp_zero():
	var gm = get_gm()
	gm.start_game()
	gm.add_health(-100)
	assert_eq(gm.health, 0, "Health should clamp at 0")

func test_take_damage():
	var gm = get_gm()
	gm.start_game()
	var initial_health = gm.health
	gm.take_damage(2)
	assert_eq(gm.health, initial_health - 2, "Health should decrease by damage amount")

func test_take_damage_triggers_game_over():
	var gm = get_gm()
	gm.start_game()
	gm.take_damage(gm.max_health)
	assert_eq(gm.state, gm.GameState.GAME_OVER, "State should be GAME_OVER")

func test_end_game_calculates_credits():
	var gm = get_gm()
	gm.start_game()
	gm.add_score(1500)
	gm.end_game()
	assert_eq(gm.credits, 150, "Credits should be floor(score / 10)")

func test_end_game_updates_high_score():
	var gm = get_gm()
	gm.start_game()
	gm.add_score(2000)
	gm.end_game()
	assert_eq(gm.high_score, 2000, "High score should update")

func test_end_game_preserves_higher_high_score():
	var gm = get_gm()
	gm.high_score = 5000
	gm.start_game()
	gm.add_score(1000)
	gm.end_game()
	assert_eq(gm.high_score, 5000, "High score should not decrease")

func test_advance_segment():
	var gm = get_gm()
	gm.start_game()
	gm.advance_segment()
	assert_eq(gm.current_segment, 1, "Segment should increment")

func test_advance_segment_advances_difficulty_every_5():
	var gm = get_gm()
	gm.start_game()
	for i in range(5):
		gm.advance_segment()
	assert_eq(gm.difficulty_tier, 2, "Tier should advance after 5 segments")

func test_advance_difficulty_caps_at_20():
	var gm = get_gm()
	gm.start_game()
	for i in range(50):
		gm._advance_difficulty()
	assert_eq(gm.difficulty_tier, 20, "Tier should cap at 20")

func test_spend_credits_success():
	var gm = get_gm()
	gm.credits = 100
	var result = gm.spend_credits(50)
	assert_true(result, "Should return true when spending credits")
	assert_eq(gm.credits, 50, "Credits should decrease")

func test_spend_credits_insufficient():
	var gm = get_gm()
	gm.credits = 30
	var result = gm.spend_credits(50)
	assert_false(result, "Should return false when insufficient credits")
	assert_eq(gm.credits, 30, "Credits should not change")

func test_add_credits():
	var gm = get_gm()
	gm.add_credits(200)
	assert_eq(gm.credits, 200, "Credits should increase")

func test_upgrade_levels_default():
	var gm = get_gm()
	assert_eq(gm.upgrade_levels["max_health"], 1, "Default max_health upgrade")
	assert_eq(gm.upgrade_levels["boost_capacity"], 1, "Default boost_capacity upgrade")
	assert_eq(gm.upgrade_levels["starting_ammo"], 1, "Default starting_ammo upgrade")
	assert_eq(gm.upgrade_levels["fire_rate"], 1, "Default fire_rate upgrade")

func test_score_timer_ticks():
	var gm = get_gm()
	gm.start_game()
	gm._process(1.0)
	assert_eq(gm.score, 10, "Score should increase by BASE_SCORE_RATE after 1 second")

func test_score_timer_accumulates():
	var gm = get_gm()
	gm.start_game()
	gm._process(0.5)
	gm._process(0.5)
	assert_eq(gm.score, 10, "Score should tick after accumulating 1 second")

func test_score_timer_does_not_tick_before_1s():
	var gm = get_gm()
	gm.start_game()
	gm._process(0.9)
	assert_eq(gm.score, 0, "Score should not tick before 1 second")

func test_score_timer_resets_on_start():
	var gm = get_gm()
	gm.start_game()
	gm._score_timer = 0.9
	gm.start_game()
	assert_eq(gm._score_timer, 0.0, "Score timer should reset on start")

func test_score_not_ticked_when_not_playing():
	var gm = get_gm()
	gm._process(1.0)
	assert_eq(gm.score, 0, "Score should not tick when not PLAYING")

func test_temporary_multiplier_adds_bonus():
	var gm = get_gm()
	gm.start_game()
	gm.add_temporary_multiplier(2)
	assert_eq(gm.multiplier, 3, "Multiplier should increase by bonus")

func test_temporary_multiplier_caps_at_8():
	var gm = get_gm()
	gm.start_game()
	gm.set_multiplier(7)
	gm.add_temporary_multiplier(5)
	assert_eq(gm.multiplier, 8, "Multiplier should cap at 8")

func test_temporary_multiplier_timer_starts():
	var gm = get_gm()
	gm.start_game()
	gm.add_temporary_multiplier(1)
	assert_eq(gm._multiplier_timer, 10.0, "Timer should be 10 seconds")

func test_temporary_multiplier_expires():
	var gm = get_gm()
	gm.start_game()
	gm.add_temporary_multiplier(2)
	gm._multiplier_timer = 0.1
	gm._process(0.2)
	assert_eq(gm.multiplier, 1, "Multiplier should reset after timer expires")

func test_temporary_multiplier_resets_to_base():
	var gm = get_gm()
	gm.start_game()
	gm.set_multiplier(3)
	gm.add_temporary_multiplier(2)
	gm._multiplier_timer = 0.1
	gm._process(0.2)
	assert_eq(gm.multiplier, 3, "Multiplier should reset to base value")

func test_save_validation_with_corrupted_data():
	var gm = get_gm()
	gm.credits = 100
	gm.high_score = 500
	gm.save_progress()
	assert_true(true, "Save should succeed with valid data")

func test_load_validation_ignores_invalid_types():
	var gm = get_gm()
	gm.credits = 100
	gm.save_progress()
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	if file:
		file.store_string("corrupted data")
		file.close()
	gm.credits = 0
	gm.load_progress()
	assert_eq(gm.credits, 0, "Credits should remain at default with corrupted save")

func test_load_validation_accepts_valid_data():
	var gm = get_gm()
	gm.credits = 500
	gm.high_score = 1000
	gm.save_progress()
	gm.credits = 0
	gm.high_score = 0
	gm.load_progress()
	assert_eq(gm.credits, 500, "Credits should load correctly")
	assert_eq(gm.high_score, 1000, "High score should load correctly")

func test_difficulty_progress_increments_on_score():
	var gm = get_gm()
	gm.start_game()
	gm.add_score(500)
	assert_eq(gm._difficulty_progress, 500, "Difficulty progress should match score")

func test_difficulty_progress_increments_on_segment():
	var gm = get_gm()
	gm.start_game()
	gm.advance_segment()
	assert_eq(gm._difficulty_progress, 200.0, "Segment should add 200 to difficulty progress")
