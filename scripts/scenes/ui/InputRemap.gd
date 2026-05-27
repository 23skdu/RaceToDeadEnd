extends Control

signal binding_changed(action: String)

const ACTIONS: Array[String] = [
	"move_left", "move_right", "accelerate", "brake",
	"primary_fire", "secondary_fire", "boost", "cycle_weapon",
	"fire_emp", "drop_mine", "pause"
]

const SAVE_PATH: String = "user://input_bindings.cfg"

var _listening_action: String = ""
var _listening_idx: int = -1
var _rows: Array[Dictionary] = []

@onready var action_list: VBoxContainer = $ActionList

func _ready() -> void:
	if not action_list:
		return
	_build_action_list()

func _build_action_list() -> void:
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.queue_free()
	_rows.clear()

	for action in ACTIONS:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)

		var label = Label.new()
		label.text = action
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.minimum_size_changed.connect(func():
			label.custom_minimum_size.x = 150
		)
		row.add_child(label)

		var events = InputMap.action_get_events(action)
		var key_count = mini(events.size(), 2)
		for ei in key_count:
			var btn = Button.new()
			btn.text = _event_to_string(events[ei]) if ei < events.size() else "..."
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size.x = 120
			var captured_action = action
			var captured_idx = ei
			btn.pressed.connect(_on_rebind_pressed.bind(captured_action, captured_idx, btn))
			row.add_child(btn)

		var clear_btn = Button.new()
		clear_btn.text = "X"
		clear_btn.custom_minimum_size.x = 30
		var captured_action2 = action
		var captured_idx2 = 0
		clear_btn.pressed.connect(_on_clear_pressed.bind(captured_action2, captured_idx2))
		row.add_child(clear_btn)

		action_list.add_child(row)
		_rows.append({"action": action, "buttons": []})

func _event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode)
	if event is InputEventJoypadButton:
		return "Btn" + str(event.button_index)
	if event is InputEventJoypadMotion:
		return "Axis" + str(event.axis)
	return "?"

func _on_rebind_pressed(action: String, idx: int, btn: Button) -> void:
	if _listening_action != "":
		return
	_listening_action = action
	_listening_idx = idx
	btn.text = "... press a key ..."
	btn.disabled = true

func _input(event: InputEvent) -> void:
	if _listening_action == "":
		return
	if event is InputEventKey and event.pressed:
		_apply_binding(_listening_action, _listening_idx, event)
		_listening_action = ""
		_listening_idx = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_apply_binding(_listening_action, _listening_idx, event)
		_listening_action = ""
		_listening_idx = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
		_apply_binding(_listening_action, _listening_idx, event)
		_listening_action = ""
		_listening_idx = -1
		get_viewport().set_input_as_handled()

func _apply_binding(action: String, idx: int, event: InputEvent) -> void:
	var events = InputMap.action_get_events(action)
	if idx < events.size():
		events[idx] = event
	else:
		events.append(event)
	InputMap.action_erase_events(action)
	for e in events:
		InputMap.action_add_event(action, e)
	save_bindings()
	binding_changed.emit(action)
	_rebuild()

func _on_clear_pressed(action: String, idx: int) -> void:
	var events = InputMap.action_get_events(action)
	if idx < events.size():
		events.remove_at(idx)
	InputMap.action_erase_events(action)
	for e in events:
		InputMap.action_add_event(action, e)
	save_bindings()
	binding_changed.emit(action)
	_rebuild()

func _rebuild() -> void:
	_build_action_list()

func save_bindings() -> void:
	var config = ConfigFile.new()
	for action in ACTIONS:
		var events = InputMap.action_get_events(action)
		var serialized: Array[String] = []
		for e in events:
			var str = _serialize_event(e)
			if str:
				serialized.append(str)
		config.set_value("bindings", action, serialized)
	config.save(SAVE_PATH)

func load_bindings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK:
		return
	for action in ACTIONS:
		var serialized = config.get_value("bindings", action, [])
		if serialized.size() > 0:
			InputMap.action_erase_events(action)
			for s in serialized:
				var e = _deserialize_event(s)
				if e:
					InputMap.action_add_event(action, e)

func _serialize_event(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:" + str(event.physical_keycode)
	if event is InputEventJoypadButton:
		return "jbtn:" + str(event.button_index)
	if event is InputEventJoypadMotion:
		return "jaxis:" + str(event.axis) + ":" + str(event.axis_value)
	return ""

func _deserialize_event(s: String) -> InputEvent:
	var parts = s.split(":")
	if parts.size() < 2:
		return null
	if parts[0] == "key":
		var e = InputEventKey.new()
		e.physical_keycode = int(parts[1])
		return e
	if parts[0] == "jbtn":
		var e = InputEventJoypadButton.new()
		e.button_index = int(parts[1])
		return e
	if parts[0] == "jaxis":
		var e = InputEventJoypadMotion.new()
		e.axis = int(parts[1])
		e.axis_value = float(parts[2]) if parts.size() >= 3 and parts[2] != "" else 1.0
		return e
	return null
