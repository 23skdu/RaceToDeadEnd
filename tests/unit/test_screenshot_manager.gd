extends GutTest

const ScreenshotManagerScript = preload("res://scripts/autoload/ScreenshotManager.gd")
const InputRemapScript = preload("res://scripts/scenes/ui/InputRemap.gd")

var _sm
var _temp_files: Array[String] = []
const TEST_DIR: String = "user://test_screenshots"

func before_each() -> void:
	_sm = ScreenshotManagerScript.new()
	_sm.show_feedback = false
	add_child_autofree(_sm)
	_temp_files.clear()

func after_each() -> void:
	for p in _temp_files:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	if DirAccess.dir_exists_absolute(TEST_DIR):
		var d := DirAccess.open(TEST_DIR)
		if d:
			d.list_dir_begin()
			var f := d.get_next()
			while f != "":
				if not d.current_is_dir():
					d.remove(f)
				f = d.get_next()
			d.list_dir_end()
		DirAccess.remove_absolute(TEST_DIR)

func test_autoload_exists_and_process_mode() -> void:
	assert_not_null(ScreenshotManager, "ScreenshotManager autoload should be registered")
	assert_eq(_sm.layer, 110, "ScreenshotManager layer should sit above TransitionLayer")
	assert_eq(_sm.process_mode, Node.PROCESS_MODE_ALWAYS, "ScreenshotManager should process while paused")

func test_screenshot_action_registered_with_f12() -> void:
	assert_true(InputMap.has_action("screenshot"), "InputMap should have 'screenshot' action")
	var events := InputMap.action_get_events("screenshot")
	assert_gt(events.size(), 0, "'screenshot' action should have a default binding")
	var has_f12 := false
	for ev in events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_F12 or ev.keycode == KEY_F12):
			has_f12 = true
			break
	assert_true(has_f12, "'screenshot' action should default to F12")
	assert_true(InputRemapScript.ACTIONS.has("screenshot"), "InputRemap.ACTIONS should expose 'screenshot'")

func test_get_screenshot_dir() -> void:
	assert_eq(_sm.get_screenshot_dir(), "user://screenshots")

func test_build_screenshot_path_format_and_uniqueness() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var first: String = _sm.build_screenshot_path(TEST_DIR)
	assert_true(first.begins_with(TEST_DIR + "/screenshot_"), "Should start with screenshot_ prefix")
	assert_true(first.ends_with(".png"), "Should end with .png")

	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.CYAN)
	assert_eq(img.save_png(first), OK)
	_temp_files.append(first)

	var second: String = _sm.build_screenshot_path(TEST_DIR)
	assert_ne(second, first, "Second path in same second should be disambiguated")
	assert_true(second.ends_with(".png"))

func test_save_screenshot_image_writes_valid_png() -> void:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.8, 0.4, 1.0))
	var out_path := TEST_DIR.path_join("unit_shot")
	watch_signals(_sm)
	var saved: String = _sm.save_screenshot_image(img, out_path)
	_temp_files.append(saved)

	assert_eq(saved, out_path + ".png", "Should append .png when omitted")
	assert_true(FileAccess.file_exists(saved), "Saved screenshot PNG should exist on disk")
	assert_signal_emitted_with_parameters(_sm, "screenshot_saved", [saved])

	var reloaded := Image.load_from_file(saved)
	assert_not_null(reloaded)
	assert_eq(reloaded.get_width(), 32)
	assert_eq(reloaded.get_height(), 16)

func test_save_screenshot_image_null_emits_failed() -> void:
	watch_signals(_sm)
	var saved: String = _sm.save_screenshot_image(null, TEST_DIR.path_join("fail.png"))
	assert_eq(saved, "")
	assert_signal_emitted(_sm, "screenshot_failed")

func test_save_screenshot_image_empty_emits_failed() -> void:
	watch_signals(_sm)
	var empty_img := Image.new()
	var saved: String = _sm.save_screenshot_image(empty_img, TEST_DIR.path_join("empty.png"))
	assert_eq(saved, "")
	assert_signal_emitted(_sm, "screenshot_failed")

func test_play_capture_feedback_updates_ui() -> void:
	_sm._play_capture_feedback("user://screenshots/test_shot.png")
	assert_true(_sm._toast_label.visible, "Toast label should become visible on feedback")
	assert_true(_sm._toast_label.text.contains("test_shot.png"), "Toast should display filename")
	if _sm._feedback_tween and _sm._feedback_tween.is_valid():
		_sm._feedback_tween.kill()
