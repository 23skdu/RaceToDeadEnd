extends SceneTree

func _init() -> void:
	var GUT = load("res://addons/gut/gut.gd")
	var gut = GUT.new()
	gut.add_directory("res://tests/unit")
	gut.add_directory("res://tests/integration")
	gut.pause_before_teardown = false
	gut.disable_colors = true
	gut.show_expecteds = true
	gut.should_exit = true
	gut.compact_mode = true
	root.add_child(gut)
	await process_frame
	gut.test_the_scripts()

func _process(_delta):
	if Input.is_key_pressed(KEY_ESCAPE):
		quit()
