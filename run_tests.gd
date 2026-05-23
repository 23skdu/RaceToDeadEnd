extends SceneTree

func _init() -> void:
	var dir := DirAccess.open("res://tests/unit")
	var all_files: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.begins_with("test_") and f.ends_with(".gd"):
				all_files.append("res://tests/unit/" + f)
			f = dir.get_next()
		dir.list_dir_end()
	all_files.sort()

	print("=== RaceToDeadEnd Unit Tests ===")
	print("Found %d test files" % all_files.size())

	var gut_config = load("res://addons/gut/gut_config.gd").new()
	var options = gut_config.default_options.duplicate()
	options.log_level = 3
	options.should_exit = true
	options.prefix = "test_"
	options.suffix = ".gd"
	options.dirs = []
	options.tests = all_files

	gut_config.options = options

	var gut = load("res://addons/gut/gut.gd").new()
	var lgr = load("res://addons/gut/logger.gd").new()
	gut.set_logger(lgr)
	gut.error_tracker = load("res://addons/gut/error_tracker.gd").new()
	load("res://addons/gut/gut_tracked_error.gd")
	load("res://addons/gut/collected_script.gd")
	load("res://addons/gut/collected_test.gd")
	load("res://addons/gut/one_to_many.gd")
	load("res://addons/gut/orphan_counter.gd")
	load("res://addons/gut/logger.gd")
	load("res://addons/gut/summary.gd")

	gut.log_level = 3
	gut.ignore_pause_before_teardown = true

	gut_config._apply_options(options, gut)

	await self.process_frame

	gut.test_scripts()

	await gut.end_run
	var fail_count = gut.get_fail_count()
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
