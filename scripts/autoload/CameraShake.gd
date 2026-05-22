extends Node

var _camera: Camera2D = null
var _trauma: float = 0.0
var _max_offset: float = 8.0
var _decay: float = 5.0

func _process(delta: float) -> void:
	if _trauma <= 0.0:
		return
	if not _camera or not is_instance_valid(_camera):
		_camera = null
		return
	_trauma = maxf(0.0, _trauma - _decay * delta)
	var amount = _trauma * _trauma
	var offset = Vector2(
		randf_range(-_max_offset, _max_offset),
		randf_range(-_max_offset, _max_offset)
	) * amount
	_camera.offset = offset

func shake(power: float = 0.5, duration: float = 0.3, max_offset: float = 8.0) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma, power)
	else:
		_trauma = power
	_decay = 1.0 / maxf(duration, 0.01)
	_max_offset = max_offset
	if not _camera:
		_find_camera()

func _find_camera() -> void:
	var tree = get_tree()
	if not tree:
		return
	var root = tree.current_scene
	if not root:
		return
	_camera = root.find_child("Camera2D", true, false) as Camera2D
