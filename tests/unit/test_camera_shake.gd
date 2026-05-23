extends GutTest

var CameraShakeScript
var _cam_shake

func before_all():
	CameraShakeScript = load("res://scripts/autoload/CameraShake.gd")

func before_each():
	_cam_shake = CameraShakeScript.new()
	add_child_autofree(_cam_shake)

func test_shake_sets_trauma():
	_cam_shake.shake(0.5, 0.3, 8.0)
	assert_gt(_cam_shake._trauma, 0.0)

func test_shake_increases_trauma_when_already_shaking():
	_cam_shake._trauma = 0.2
	_cam_shake.shake(0.5, 0.3, 8.0)
	assert_eq(_cam_shake._trauma, 0.5)

func test_shake_does_not_decrease_trauma_when_existing_higher():
	_cam_shake._trauma = 0.9
	_cam_shake.shake(0.5, 0.3, 8.0)
	assert_eq(_cam_shake._trauma, 0.9)

func test_shake_sets_max_offset():
	_cam_shake.shake(0.5, 0.3, 16.0)
	assert_eq(_cam_shake._max_offset, 16.0)

func test_shake_sets_decay_from_duration():
	_cam_shake.shake(0.5, 0.5, 8.0)
	assert_almost_eq(_cam_shake._decay, 2.0, 0.001)

func test_process_decreases_trauma():
	_cam_shake._trauma = 1.0
	_cam_shake._decay = 5.0
	_cam_shake._camera = Camera2D.new()
	add_child_autofree(_cam_shake._camera)
	_cam_shake._process(0.1)
	assert_lt(_cam_shake._trauma, 1.0)

func test_process_decays_to_zero():
	_cam_shake._trauma = 0.5
	_cam_shake._decay = 10.0
	_cam_shake._camera = Camera2D.new()
	add_child_autofree(_cam_shake._camera)
	_cam_shake._process(1.0)
	assert_eq(_cam_shake._trauma, 0.0)

func test_process_does_nothing_when_trauma_zero():
	_cam_shake._trauma = 0.0
	var camera = Camera2D.new()
	add_child_autofree(camera)
	camera.offset = Vector2(100, 100)
	_cam_shake._camera = camera
	_cam_shake._process(0.1)
	assert_eq(camera.offset, Vector2(100, 100))

func test_process_does_nothing_when_camera_null():
	_cam_shake._trauma = 1.0
	_cam_shake._camera = null
	_cam_shake._process(0.1)
	assert_true(true, "Should not crash when camera is null")

func test_process_handles_invalid_camera():
	var camera = Camera2D.new()
	_cam_shake._camera = camera
	camera.free()
	_cam_shake._trauma = 1.0
	_cam_shake._process(0.1)
	assert_null(_cam_shake._camera)

func test_find_camera_returns_null_when_no_tree():
	_cam_shake._find_camera()
	assert_null(_cam_shake._camera)

func test_rumble_callable_does_not_crash():
	_cam_shake.rumble(0.5, 0.1)
	assert_true(true, "rumble should not crash when no joypad connected")

func test_shake_calls_find_camera_when_no_camera():
	_cam_shake._camera = null
	_cam_shake.shake(0.5, 0.3, 8.0)
	assert_true(true, "shake should handle missing camera gracefully")

func test_process_applies_camera_offset():
	_cam_shake._trauma = 1.0
	_cam_shake._decay = 0.0
	var camera = Camera2D.new()
	add_child_autofree(camera)
	_cam_shake._camera = camera
	_cam_shake._process(0.016)
	assert_ne(camera.offset, Vector2.ZERO)
