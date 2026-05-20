extends GutTest

func test_game_over_shows_on_game_over():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	go._on_game_over(1500)
	assert_true(go.visible, "Game over screen should be visible")

func test_game_over_displays_score():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	go._on_game_over(1500)
	assert_eq(go.final_score_label.text, "SCORE: 1500", "Should display score")

func test_game_over_displays_high_score():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	go._on_game_over(1500)
	assert_eq(go.high_score_label.text, "BEST: " + str(go.get_node("/root/GameManager").high_score if go.has_node("/root/GameManager") else 0), "Should display high score")

func test_game_over_displays_credits():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	go._on_game_over(1500)
	assert_eq(go.credits_label.text, "CREDITS EARNED: +150", "Should display credits as integer")

func test_game_over_displays_credits_no_decimal():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	go._on_game_over(1555)
	assert_false("155.5" in go.credits_label.text, "Credits should not show decimal")
	assert_eq(go.credits_label.text, "CREDITS EARNED: +155", "Should floor credits")

func test_game_over_hidden_by_default():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	assert_false(go.visible, "Should be hidden by default")

func test_game_over_continue_emits_signal():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	watch_signals(go)
	go._on_continue_pressed()
	assert_signal_emitted(go, "restart_requested", "Should emit restart signal")

func test_game_over_menu_emits_signal():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	watch_signals(go)
	go._on_menu_pressed()
	assert_signal_emitted(go, "menu_requested", "Should emit menu signal")

func test_game_over_garage_emits_signal():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	watch_signals(go)
	go._on_garage_pressed()
	assert_signal_emitted(go, "garage_requested", "Should emit garage signal")

func test_game_over_ready_connects_signals():
	var go = load("res://scenes/ui/GameOver.gd").new()
	add_child_autofree(go)
	assert_true(GameManager.game_over.is_connected(go._on_game_over), "Should connect game_over signal")
	assert_false(go.visible, "Should be hidden by default after ready")
