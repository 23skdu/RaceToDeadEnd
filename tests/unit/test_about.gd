extends GutTest

func test_about_scene_exists():
	assert_true(ResourceLoader.exists("res://scenes/ui/About.tscn"), "About scene should exist")

func test_about_script_exists():
	assert_true(ResourceLoader.exists("res://scripts/scenes/ui/About.gd"), "About script should exist")

func _create_about():
	var about = load("res://scenes/ui/About.tscn").instantiate()
	add_child_autofree(about)
	return about

func test_about_displays_author_and_github():
	var about = _create_about()
	assert_true(about.author_label.text.contains("23skdu"), "Should display author name")
	assert_true(about.github_button.text.contains("https://github.com/23skdu/RaceToDeadEnd"), "Should display GitHub URL")
	assert_true(about.version_label.text.begins_with("BUILD: v"), "Should display build version")

func test_about_buttons_connected():
	var about = _create_about()
	assert_true(about.back_button.pressed.is_connected(about._on_back_pressed), "Back button should be connected")
	assert_true(about.github_button.pressed.is_connected(about._on_github_pressed), "GitHub button should be connected")
	assert_true(about.author_button.pressed.is_connected(about._on_author_pressed), "Author button should be connected")

func test_about_back_emits_signal():
	var about = _create_about()
	watch_signals(about)
	about._on_back_pressed()
	assert_signal_emitted(about, "back_to_menu_requested", "Should emit back_to_menu_requested")
