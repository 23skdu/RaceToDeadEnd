extends CanvasLayer

const WeaponDataRes = preload("res://scripts/resources/WeaponData.gd")

signal back_to_menu_requested

@onready var back_button: Button = $Panel/BackButton
@onready var movement_text: Label = get_node_or_null("Panel/TabContainer/Controls/MovementText")
@onready var weapons_text: Label = get_node_or_null("Panel/TabContainer/Controls/WeaponsText")
@onready var boost_text: Label = get_node_or_null("Panel/TabContainer/Controls/BoostText")

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	refresh_control_hints()

func refresh_control_hints() -> void:
	if movement_text:
		movement_text.text = "%s = Accelerate\n%s = Brake / Reverse\n%s = Move Left\n%s = Move Right" % [
			_format_action_keys("accelerate"),
			_format_action_keys("brake"),
			_format_action_keys("move_left"),
			_format_action_keys("move_right"),
		]
	if weapons_text:
		var descriptions: Dictionary = {
			"missile": "Homes onto nearest enemy. 3 dmg.",
			"mine": "Drops behind you. Arms in 0.5s. 2 dmg.",
			"emp": "Stuns all enemies for 2s. 1 dmg.",
		}
		var weapon_lines: Array[String] = []
		for entry in Constants.WEAPON_DATA:
			var wd := WeaponDataRes.new()
			wd.type_name = str(entry.get("type_name", ""))
			wd.display_name = str(entry.get("display_name", ""))
			wd.color = entry.get("color", Color.WHITE)
			wd.base_ammo = int(entry.get("base_ammo", 0))
			wd.description = str(descriptions.get(wd.type_name, ""))
			weapon_lines.append("%s: %s" % [wd.display_name, wd.description])
		weapons_text.text = "%s = Primary Fire (rapid-fire machine gun)\n%s = Cycle weapon (Missile -> Mine -> EMP)\n%s = Fire selected secondary weapon\n\n%s\n\n%s = Fire EMP directly\n%s = Drop Mine directly\n%s = Take Screenshot" % [
			_format_action_keys("primary_fire"),
			_format_action_keys("cycle_weapon"),
			_format_action_keys("secondary_fire"),
			"\n".join(weapon_lines),
			_format_action_keys("fire_emp"),
			_format_action_keys("drop_mine"),
			_format_action_keys("screenshot"),
		]
	if boost_text:
		boost_text.text = "%s = Activate boost. 2x speed for 1.5s. Invincible while boosting.\n3 charges by default. Each charge takes 8s to recharge.\nUpgrade boost capacity in the Garage for more charges." % [
			_format_action_keys("boost"),
		]

static func _format_action_keys(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	var parts: Array[String] = []
	for ev in events:
		if ev is InputEventKey:
			var code: Key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			var name_str := OS.get_keycode_string(code)
			if not name_str.is_empty() and not (name_str in parts):
				parts.append(name_str)
		elif ev is InputEventJoypadButton:
			var b_str := "Btn" + str(ev.button_index)
			if not (b_str in parts):
				parts.append(b_str)
		elif ev is InputEventJoypadMotion:
			var a_str := "Axis" + str(ev.axis)
			if not (a_str in parts):
				parts.append(a_str)
	return " / ".join(parts) if not parts.is_empty() else "Unbound"

func _on_back_pressed() -> void:
	back_to_menu_requested.emit()
