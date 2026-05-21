extends GutTest

func _create_game_over():
	var go = load("res://scenes/ui/GameOver.tscn").instantiate()
	add_child_autofree(go)
	return go

func test_game_over_shows_on_game_over():
	var go = _create_game_over()
	go._on_game_over(1500)
	assert_true(go.visible, "Game over screen should be visible")

func test_game_over_displays_score():
	var go = _create_game_over()
	go._on_game_over(1500)
	assert_eq(go.final_score_label.text, "SCORE: 1500", "Should display score")

func test_game_over_displays_high_score():
	var go = _create_game_over()
	go._on_game_over(1500)
	assert_eq(go.high_score_label.text, "BEST: " + str(GameManager.high_score), "Should display high score")

func test_game_over_displays_credits():
	var go = _create_game_over()
	go._on_game_over(1500)
	assert_eq(go.credits_label.text, "CREDITS EARNED: +150", "Should display credits as integer")

func test_game_over_displays_credits_no_decimal():
	var go = _create_game_over()
	go._on_game_over(1555)
	assert_false("155.5" in go.credits_label.text, "Credits should not show decimal")
	assert_eq(go.credits_label.text, "CREDITS EARNED: +155", "Should floor credits")

func test_game_over_hidden_by_default():
	var go = _create_game_over()
	assert_false(go.visible, "Should be hidden by default")

func test_game_over_continue_emits_signal():
	var go = _create_game_over()
	watch_signals(go)
	go._on_continue_pressed()
	assert_signal_emitted(go, "restart_requested", "Should emit restart signal")

func test_game_over_menu_emits_signal():
	var go = _create_game_over()
	watch_signals(go)
	go._on_menu_pressed()
	assert_signal_emitted(go, "menu_requested", "Should emit menu signal")

func test_game_over_garage_emits_signal():
	var go = _create_game_over()
	watch_signals(go)
	go._on_garage_pressed()
	assert_signal_emitted(go, "garage_requested", "Should emit garage signal")

func test_game_over_ready_connects_signals():
	var go = _create_game_over()
	assert_true(GameManager.game_over.is_connected(go._on_game_over), "Should connect game_over signal")
	assert_false(go.visible, "Should be hidden by default after ready")

func test_game_over_signal_guard_prevents_double_connect():
	var go = _create_game_over()
	var connection_count = 0
	for conn in GameManager.game_over.get_connections():
		if conn.callable == go._on_game_over:
			connection_count += 1
	assert_eq(connection_count, 1, "Should only have one connection to game_over")

func test_game_over_credits_calculation():
	var go = _create_game_over()
	go._on_game_over(999)
	assert_eq(go.credits_label.text, "CREDITS EARNED: +99", "Should floor 999/10 = 99")

func test_game_over_zero_score():
	var go = _create_game_over()
	go._on_game_over(0)
	assert_eq(go.final_score_label.text, "SCORE: 0", "Should display zero score")
	assert_eq(go.credits_label.text, "CREDITS EARNED: +0", "Should display zero credits")

func test_game_over_signals_exist():
	var go = _create_game_over()
	assert_true(go.has_signal("restart_requested"), "Should have restart_requested signal")
	assert_true(go.has_signal("garage_requested"), "Should have garage_requested signal")
	assert_true(go.has_signal("menu_requested"), "Should have menu_requested signal")
