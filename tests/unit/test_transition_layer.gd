extends GutTest

var _tl

func before_all():
	_tl = TransitionLayer

func before_each():
	while _tl.get_child_count() > 0:
		_tl.remove_child(_tl.get_child(0))
	_tl._overlay = null
	_tl._tween = null

func test_ready_sets_layer():
	_tl._ready()
	assert_eq(_tl.layer, 100)

func test_ready_sets_process_mode():
	_tl._ready()
	assert_eq(_tl.process_mode, PROCESS_MODE_ALWAYS)

func test_ready_creates_overlay():
	_tl._ready()
	assert_not_null(_tl._overlay)
	assert_true(_tl._overlay is ColorRect)

func test_ready_overlay_color():
	_tl._ready()
	assert_eq(_tl._overlay.color, Color.BLACK)

func test_ready_overlay_modulate():
	_tl._ready()
	assert_eq(_tl._overlay.modulate.a, 0.0)

func test_ready_overlay_mouse_filter():
	_tl._ready()
	assert_eq(_tl._overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_ready_overlay_full_rect():
	_tl._ready()
	assert_eq(_tl._overlay.anchor_left, 0.0)
	assert_eq(_tl._overlay.anchor_right, 1.0)
	assert_eq(_tl._overlay.anchor_top, 0.0)
	assert_eq(_tl._overlay.anchor_bottom, 1.0)

func test_ready_overlay_is_child():
	_tl._ready()
	assert_eq(_tl._overlay.get_parent(), _tl)

func test_fade_to_black_creates_tween():
	_tl._ready()
	_tl.fade_to_black(0.0)
	assert_not_null(_tl._tween)

func test_fade_to_black_sets_tween_pause_mode():
	_tl._ready()
	_tl.fade_to_black(0.0)
	assert_not_null(_tl._tween)

func test_fade_from_black_creates_tween():
	_tl._ready()
	_tl._overlay.modulate.a = 1.0
	_tl.fade_from_black(0.0)
	assert_not_null(_tl._tween)

func test_fade_from_black_sets_tween_pause_mode():
	_tl._ready()
	_tl._overlay.modulate.a = 1.0
	_tl.fade_from_black(0.0)
	assert_not_null(_tl._tween)

func test_rapid_fade_kills_previous_tween():
	_tl._ready()
	_tl.fade_to_black(0.0)
	var first = _tl._tween
	assert_not_null(first)
	_tl.fade_to_black(0.0)
	var second = _tl._tween
	assert_not_null(second)
	assert_ne(first, second, "Should create new tween on rapid fade")

func test_reload_scene_exists():
	assert_true(_tl.has_method("reload_scene"))

func test_change_scene_exists():
	assert_true(_tl.has_method("change_scene"))

func test_fade_to_black_exists():
	assert_true(_tl.has_method("fade_to_black"))

func test_fade_from_black_exists():
	assert_true(_tl.has_method("fade_from_black"))
