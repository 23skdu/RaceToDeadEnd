extends RefCounted
class_name AccessibilityUtil
## Accessibility bridge for roadmap item 14.
##
## The helper is deliberately defensive: headless test runs have no
## AccessibilityServer singleton and some platforms report is_supported() ==
## false. In those cases tooltips/metadata and focus neighbours still work, so
## the UI remains keyboard and screen-reader friendly on real builds.

signal announcement_requested(message: String)

const ROLE_BUTTON := 7
const ROLE_STATIC_TEXT := 4
const ROLE_CONTAINER := 5
const ROADMAP_UI_GROUP := "roadmap_ui_root"

## Colourblind palettes are intentionally subtle tints rather than replacements:
## the underlying cyberpunk colours still read correctly while the mode is on.
const PALETTE_NONE := Color(1.0, 1.0, 1.0, 1.0)
const PALETTE_HIGH_CONTRAST := Color(1.25, 1.25, 1.25, 1.0)
const PALETTE_PROTANOPIA := Color(1.0, 0.86, 0.72, 1.0)
const PALETTE_DEUTERANOPIA := Color(0.88, 1.0, 0.82, 1.0)
const PALETTE_TRITANOPIA := Color(0.82, 0.92, 1.0, 1.0)

var screen_reader_supported: bool = false
var _server: Object = null
var _descriptions: Dictionary = {}


func _init() -> void:
	if Engine.has_singleton("AccessibilityServer"):
		_server = Engine.get_singleton("AccessibilityServer")
	if _server != null and _server.has_method("is_supported"):
		screen_reader_supported = bool(_server.call("is_supported"))


static func has_screen_reader_service() -> bool:
	return Engine.has_singleton("AccessibilityServer")


func is_active() -> bool:
	return screen_reader_supported and _server != null


static func palette_for(high_contrast: bool, colorblind_mode: String) -> Color:
	if high_contrast:
		return PALETTE_HIGH_CONTRAST
	match colorblind_mode:
		"protanopia":
			return PALETTE_PROTANOPIA
		"deuteranopia":
			return PALETTE_DEUTERANOPIA
		"tritanopia":
			return PALETTE_TRITANOPIA
		_:
			return PALETTE_NONE


func apply_palette(root: Node, high_contrast: bool, colorblind_mode: String) -> Color:
	var tint: Color = palette_for(high_contrast, colorblind_mode)
	if root == null:
		return tint
	var targets: Array[Node] = []
	if root.is_in_group(ROADMAP_UI_GROUP):
		targets.append(root)
	targets.append_array(root.find_children("*", "Control", true, false))
	for target in targets:
		if target is Control and target.name == "Panel":
			(target as Control).modulate = tint
	return tint


func describe_control(node: Control, label: String, hint: String = "") -> void:
	if node == null:
		return
	if not hint.is_empty() and node.tooltip_text.is_empty():
		node.tooltip_text = hint
	_descriptions[node.get_instance_id()] = {
		"ref": weakref(node),
		"label": label,
		"hint": hint,
	}
	_apply_description(node, label, hint)


func refresh_descriptions() -> void:
	for entry in _descriptions.values():
		var ref: WeakRef = entry.get("ref") as WeakRef
		if ref == null:
			continue
		var node = ref.get_ref()
		if node is Control:
			_apply_description(node, String(entry.get("label", "")), String(entry.get("hint", "")))


func announce(message: String) -> void:
	announcement_requested.emit(message)


static func link_focus_chain(controls: Array) -> void:
	var count: int = controls.size()
	if count < 2:
		return
	for i in range(count):
		var current: Control = controls[i] as Control
		if current == null:
			continue
		var previous: Control = controls[(i - 1 + count) % count] as Control
		var following: Control = controls[(i + 1) % count] as Control
		if previous != null:
			current.focus_neighbor_left = current.get_path_to(previous)
		if following != null:
			current.focus_neighbor_right = current.get_path_to(following)
		if previous != null:
			current.focus_neighbor_top = current.get_path_to(previous)
		if following != null:
			current.focus_neighbor_bottom = current.get_path_to(following)


static func link_focus_grid(buttons: Array, columns: int) -> void:
	var count: int = buttons.size()
	var cols: int = maxi(1, columns)
	if count == 0:
		return
	for i in range(count):
		var current: Control = buttons[i] as Control
		if current == null:
			continue
		var left: Control = null
		var right: Control = null
		var up: Control = null
		var down: Control = null
		if i % cols != 0:
			left = buttons[i - 1] as Control
		if (i + 1) % cols != 0 and i + 1 < count:
			right = buttons[i + 1] as Control
		if i >= cols:
			up = buttons[i - cols] as Control
		if i + cols < count:
			down = buttons[i + cols] as Control
		if left != null:
			current.focus_neighbor_left = current.get_path_to(left)
		if right != null:
			current.focus_neighbor_right = current.get_path_to(right)
		if up != null:
			current.focus_neighbor_top = current.get_path_to(up)
		if down != null:
			current.focus_neighbor_bottom = current.get_path_to(down)


func _apply_description(node: Control, label: String, hint: String) -> void:
	if not is_active() or not node.has_method("get_accessibility_element"):
		return
	var element: Variant = node.call("get_accessibility_element")
	if not (element is RID):
		return
	if _server.has_method("has_element") and not bool(_server.call("has_element", element)):
		return
	var role: int = ROLE_CONTAINER
	if node is Button:
		role = ROLE_BUTTON
	elif node is Label:
		role = ROLE_STATIC_TEXT
	if _server.has_method("update_set_role"):
		_server.call("update_set_role", element, role)
	if _server.has_method("update_set_name"):
		_server.call("update_set_name", element, label)
	if _server.has_method("update_set_description"):
		_server.call("update_set_description", element, hint)
	if _server.has_method("update_set_language"):
		_server.call("update_set_language", element, TranslationServer.get_locale())
	if node.has_method("queue_accessibility_update"):
		node.call("queue_accessibility_update")
