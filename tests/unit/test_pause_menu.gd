extends GutTest

func test_pause_menu_scene_exists():
	assert_true(ResourceLoader.exists("res://scenes/ui/PauseMenu.tscn"), "PauseMenu scene should exist")

func test_pause_menu_script_exists():
	assert_true(ResourceLoader.exists("res://scripts/scenes/ui/PauseMenu.gd"), "PauseMenu script should exist")

func _create_pause_menu():
	var pm = load("res://scenes/ui/PauseMenu.tscn").instantiate()
	add_child_autofree(pm)
	return pm

func test_pause_menu_has_signals():
	var pm = _create_pause_menu()
	assert_true(pm.has_signal("resume_requested"), "Should have resume_requested signal")
	assert_true(pm.has_signal("options_requested"), "Should have options_requested signal")
	assert_true(pm.has_signal("quit_requested"), "Should have quit_requested signal")

func test_pause_menu_has_nodes():
	var pm = _create_pause_menu()
	assert_not_null(pm.panel, "Should have Panel node")
	assert_not_null(pm.resume_btn, "Should have Resume button")
	assert_not_null(pm.options_btn, "Should have Options button")
	assert_not_null(pm.quit_btn, "Should have Quit button")

func test_pause_menu_resume_emits_signal():
	var pm = _create_pause_menu()
	watch_signals(pm)
	pm._on_resume()
	assert_signal_emitted(pm, "resume_requested", "Resume should emit signal")

func test_pause_menu_options_emits_signal():
	var pm = _create_pause_menu()
	watch_signals(pm)
	pm._on_options()
	assert_signal_emitted(pm, "options_requested", "Options should emit signal")

func test_pause_menu_quit_emits_signal():
	var pm = _create_pause_menu()
	watch_signals(pm)
	pm._on_quit()
	assert_signal_emitted(pm, "quit_requested", "Quit should emit signal")
