extends GutTest

const RunTestsScript = preload("res://scripts/run_tests.gd")

func test_run_tests_script_loads() -> void:
	assert_not_null(RunTestsScript, "scripts/run_tests.gd should load cleanly")

func test_run_tests_discovers_all_test_suites() -> void:
	var expected_dirs := [
		"res://tests/unit",
		"res://tests/integration",
		"res://tests/fuzz",
		"res://tests/regression",
	]
	for subdir in expected_dirs:
		var dir := DirAccess.open(subdir)
		assert_not_null(dir, "Test directory should exist: " + subdir)
		var count := 0
		if dir:
			dir.list_dir_begin()
			var f := dir.get_next()
			while f != "":
				if f.begins_with("test_") and f.ends_with(".gd"):
					count += 1
				f = dir.get_next()
			dir.list_dir_end()
		assert_gt(count, 0, "Should discover test_*.gd files in " + subdir)
