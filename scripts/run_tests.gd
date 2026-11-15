extends SceneTree

func _init() -> void:
	var all_files: Array[String] = []
	for subdir in ["res://tests/unit", "res://tests/integration", "res://tests/fuzz", "res://tests/regression"]:
		var dir := DirAccess.open(subdir)
		if dir:
			dir.list_dir_begin()
			var f := dir.get_next()
			while f != "":
				if f.begins_with("test_") and f.ends_with(".gd"):
					all_files.append(subdir + "/" + f)
				f = dir.get_next()
			dir.list_dir_end()
	all_files.sort()

	print("=== RaceToDeadEnd Full Test Suite ===")
	print("Found %d test files" % all_files.size())

	await self.process_frame

	var gut_config = load("res://addons/gut/gut_config.gd").new()
	var options = gut_config.default_options.duplicate()
	options.log_level = 1
	options.should_exit = true
	options.prefix = "test_"
	options.suffix = ".gd"
	options.dirs = ["res://tests/unit", "res://tests/integration", "res://tests/fuzz", "res://tests/regression"]
	options.include_subdirs = true
	gut_config.options = options

	var runner = load("res://addons/gut/gui/GutRunner.tscn").instantiate()
	runner.set_gut_config(gut_config)
	root.add_child(runner)
	runner.run_tests()
