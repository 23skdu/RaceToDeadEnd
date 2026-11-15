extends CanvasLayer

signal screenshot_saved(file_path: String)
signal screenshot_failed(reason: String)

const SCREENSHOT_DIR: String = "user://screenshots"

var show_feedback: bool = true
var _is_capturing: bool = false
var _flash_rect: ColorRect = null
var _toast_label: Label = null
var _feedback_tween: Tween = null

func _ready() -> void:
	layer = 110
	process_mode = PROCESS_MODE_ALWAYS
	_ensure_screenshot_action()
	_setup_feedback_ui()

func _ensure_screenshot_action() -> void:
	if not InputMap.has_action("screenshot"):
		InputMap.add_action("screenshot")
	if InputMap.action_get_events("screenshot").is_empty():
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F12
		InputMap.action_add_event("screenshot", ev)

func _setup_feedback_ui() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.name = "CaptureFlash"
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash_rect)

	_toast_label = Label.new()
	_toast_label.name = "ScreenshotToast"
	_toast_label.text = ""
	_toast_label.visible = false
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.position = Vector2(24.0, 24.0)
	_toast_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.85, 1.0))
	_toast_label.add_theme_font_size_override("font_size", 16)
	add_child(_toast_label)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot") and not event.is_echo():
		take_screenshot()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

func get_screenshot_dir() -> String:
	return SCREENSHOT_DIR

func build_screenshot_path(dir_path: String = SCREENSHOT_DIR) -> String:
	var dt := Time.get_datetime_dict_from_system(false)
	var stem := "screenshot_%04d-%02d-%02d_%02d-%02d-%02d" % [
		int(dt.get("year", 2026)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]
	var candidate := dir_path.path_join(stem + ".png")
	if not FileAccess.file_exists(candidate):
		return candidate
	var suffix := 1
	while suffix < 1000:
		candidate = dir_path.path_join("%s_%03d.png" % [stem, suffix])
		if not FileAccess.file_exists(candidate):
			return candidate
		suffix += 1
	return dir_path.path_join("%s_%d.png" % [stem, Time.get_ticks_usec()])

func capture_viewport_image(viewport: Viewport = null) -> Image:
	var vp := viewport if viewport else get_viewport()
	if not vp:
		return null
	var tex := vp.get_texture()
	if not tex:
		return null
	return tex.get_image()

func save_screenshot_image(img: Image, custom_path: String = "") -> String:
	if img == null or img.is_empty():
		screenshot_failed.emit("Viewport image unavailable")
		return ""

	var target_path := custom_path.strip_edges()
	if target_path.is_empty():
		target_path = build_screenshot_path()
	elif not target_path.to_lower().ends_with(".png"):
		target_path += ".png"

	var base_dir := target_path.get_base_dir()
	if not base_dir.is_empty() and not DirAccess.dir_exists_absolute(base_dir):
		var mk_err := DirAccess.make_dir_recursive_absolute(base_dir)
		if mk_err != OK:
			screenshot_failed.emit("Failed to create screenshot directory (error %d)" % mk_err)
			return ""

	var err := img.save_png(target_path)
	if err != OK:
		screenshot_failed.emit("Failed to save PNG (error %d)" % err)
		return ""

	screenshot_saved.emit(target_path)
	return target_path

func take_screenshot(custom_path: String = "") -> String:
	if _is_capturing:
		return ""
	_is_capturing = true
	if is_inside_tree():
		await RenderingServer.frame_post_draw
	if not is_instance_valid(self) or not is_inside_tree():
		return ""
	var img := capture_viewport_image()
	var saved_path := save_screenshot_image(img, custom_path)
	_is_capturing = false
	if saved_path.is_empty():
		return ""
	if show_feedback:
		_play_capture_feedback(saved_path)
	return saved_path

func _play_capture_feedback(saved_path: String) -> void:
	if not is_instance_valid(_flash_rect) or not is_instance_valid(_toast_label):
		return
	if _feedback_tween:
		_feedback_tween.kill()
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.35)
	_toast_label.text = "Screenshot saved: " + saved_path.get_file()
	_toast_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_toast_label.visible = true

	_feedback_tween = create_tween()
	_feedback_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(_flash_rect, "color:a", 0.0, 0.18)
	_feedback_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6).set_delay(1.2)
	_feedback_tween.set_parallel(false)
	_feedback_tween.tween_callback(func():
		if is_instance_valid(_toast_label):
			_toast_label.visible = false
	)
