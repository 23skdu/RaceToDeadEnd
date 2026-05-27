extends CanvasLayer

var _overlay: ColorRect = null
var _tween: Tween = null

func _ready() -> void:
	layer = 100
	process_mode = PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.modulate = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

func fade_to_black(duration: float = 0.3) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(func(a): if _overlay: _overlay.modulate.a = a, 0.0, 1.0, duration)
	_tween.tween_callback(func(): if _overlay: _overlay.mouse_filter = Control.MOUSE_FILTER_STOP)
	await _tween.finished

func fade_from_black(duration: float = 0.3) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(func(a): if _overlay: _overlay.modulate.a = a, 1.0, 0.0, duration)
	_tween.tween_callback(func():
		if _overlay:
			_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
	await _tween.finished

func change_scene(path: String) -> void:
	await fade_to_black()
	get_tree().change_scene_to_file(path)
	await fade_from_black()

func reload_scene() -> void:
	await fade_to_black()
	get_tree().reload_current_scene()
	await fade_from_black()
