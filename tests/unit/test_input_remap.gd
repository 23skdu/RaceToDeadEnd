extends GutTest

var InputRemapScript
var _remap

func before_all():
	InputRemapScript = load("res://scripts/scenes/ui/InputRemap.gd")

func before_each():
	_remap = InputRemapScript.new()
	add_child_autofree(_remap)

func test_actions_not_empty():
	assert_gt(_remap.ACTIONS.size(), 0)

func test_actions_contains_expected():
	assert_true(_remap.ACTIONS.has("move_left"))
	assert_true(_remap.ACTIONS.has("accelerate"))
	assert_true(_remap.ACTIONS.has("pause"))
	assert_true(_remap.ACTIONS.has("boost"))

func test_event_to_string_key():
	var event = InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	var result = _remap._event_to_string(event)
	assert_eq(result, "Space")

func test_event_to_string_joypad_button():
	var event = InputEventJoypadButton.new()
	event.button_index = 3
	var result = _remap._event_to_string(event)
	assert_eq(result, "Btn3")

func test_event_to_string_joypad_motion():
	var event = InputEventJoypadMotion.new()
	event.axis = 1
	var result = _remap._event_to_string(event)
	assert_eq(result, "Axis1")

func test_event_to_string_unknown():
	var event = InputEventKey.new()
	event.physical_keycode = KEY_P
	var result = _remap._event_to_string(event)
	assert_eq(result, "P")

func test_serialize_event_key():
	var event = InputEventKey.new()
	event.physical_keycode = 65
	var result = _remap._serialize_event(event)
	assert_eq(result, "key:65")

func test_serialize_event_joypad_button():
	var event = InputEventJoypadButton.new()
	event.button_index = 0
	var result = _remap._serialize_event(event)
	assert_eq(result, "jbtn:0")

func test_serialize_event_unknown():
	var event = InputEventKey.new()
	event.physical_keycode = 0
	var result = _remap._serialize_event(event)
	assert_eq(result, "key:0")

func test_deserialize_event_key():
	var result = _remap._deserialize_event("key:65")
	assert_true(result is InputEventKey)
	assert_eq(result.physical_keycode, 65)

func test_deserialize_event_jbtn():
	var result = _remap._deserialize_event("jbtn:0")
	assert_true(result is InputEventJoypadButton)
	assert_eq(result.button_index, 0)

func test_deserialize_event_bad_format():
	var result = _remap._deserialize_event("bad")
	assert_null(result)

func test_deserialize_event_empty():
	var result = _remap._deserialize_event("")
	assert_null(result)

func test_deserialize_event_partial():
	var result = _remap._deserialize_event("key:")
	assert_true(result is InputEventKey, "Partial key: should still produce an InputEventKey with keycode 0")

func test_save_bindings_does_not_crash():
	_remap.save_bindings()
	assert_true(true, "save_bindings should not crash")

func test_load_bindings_does_not_crash_when_no_file():
	_remap.load_bindings()
	assert_true(true, "load_bindings should not crash when no save file")

func test_binding_changed_signal_exists():
	assert_true(_remap.has_signal("binding_changed"))

func test_on_clear_pressed_exists():
	assert_true(_remap.has_method("_on_clear_pressed"))

func test_rebuild_exists():
	assert_true(_remap.has_method("_rebuild"))

func test_apply_binding_emits_signal():
	var container = VBoxContainer.new()
	_remap.action_list = container
	_remap.add_child(container)
	watch_signals(_remap)
	var event = InputEventKey.new()
	event.physical_keycode = KEY_A
	_remap._apply_binding("move_left", 0, event)
	assert_signal_emitted(_remap, "binding_changed")

func test_on_rebind_pressed_sets_listening():
	var btn = Button.new()
	add_child_autofree(btn)
	_remap._on_rebind_pressed("move_left", 0, btn)
	assert_eq(_remap._listening_action, "move_left")
	assert_eq(_remap._listening_idx, 0)
	assert_true(btn.disabled)

func test_serialize_event_joypad_axis():
	var event = InputEventJoypadMotion.new()
	event.axis = 0
	event.axis_value = 1.0
	var result = _remap._serialize_event(event)
	assert_eq(result, "jaxis:0:1.0", "Joypad axis should serialize with axis_value")

func test_serialize_event_joypad_axis_negative():
	var event = InputEventJoypadMotion.new()
	event.axis = 0
	event.axis_value = -1.0
	var result = _remap._serialize_event(event)
	assert_eq(result, "jaxis:0:-1.0", "Joypad axis should serialize negative axis_value")

func test_deserialize_event_joypad_axis():
	var result = _remap._deserialize_event("jaxis:1:1.0")
	assert_true(result is InputEventJoypadMotion, "Should deserialize to JoypadMotion")
	assert_eq(result.axis, 1, "Axis should be 1")
	assert_eq(result.axis_value, 1.0, "Axis value should be 1.0")

func test_deserialize_event_joypad_axis_negative():
	var result = _remap._deserialize_event("jaxis:0:-1.0")
	assert_true(result is InputEventJoypadMotion, "Should deserialize to JoypadMotion")
	assert_eq(result.axis, 0, "Axis should be 0")
	assert_eq(result.axis_value, -1.0, "Axis value should be -1.0")

func test_deserialize_event_joypad_axis_backward_compat():
	var result = _remap._deserialize_event("jaxis:1")
	assert_true(result is InputEventJoypadMotion, "Should deserialize old format to JoypadMotion")
	assert_eq(result.axis, 1, "Old format axis should be 1")
	assert_eq(result.axis_value, 1.0, "Old format axis value should default to 1.0")

func test_event_to_string_joypad_axis():
	var event = InputEventJoypadMotion.new()
	event.axis = 0
	var result = _remap._event_to_string(event)
	assert_eq(result, "Axis0", "Event to string should return Axis0")
