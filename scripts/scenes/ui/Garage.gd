extends CanvasLayer

signal back_to_menu_requested
signal start_run_requested

@onready var credits_label: Label = $Panel/CreditsLabel
@onready var upgrade_container: VBoxContainer = $Panel/TabContainer/Upgrades
@onready var customize_container: VBoxContainer = $Panel/TabContainer/Customize
@onready var back_button: Button = $Panel/BackButton
@onready var start_button: Button = $Panel/StartButton

var _selected_preview_pack_id: String = ""
var _preview_panel: PanelContainer = null

const UPGRADE_COSTS: Dictionary = {
	max_health = [0, 500, 1500, 3000, 5000],
	boost_capacity = [0, 300, 800, 2000, 4000],
	fire_rate = [0, 400, 1000, 2500, 5000],
	missile_ammo = [0, 150, 400, 1000, 2000],
	mine_ammo = [0, 200, 500, 1200, 2500],
	emp_ammo = [0, 250, 700, 1500, 3000],
}

const UPGRADE_NAMES: Dictionary = {
	max_health = "MAX HEALTH",
	boost_capacity = "BOOST CAPACITY",
	fire_rate = "FIRE RATE",
	missile_ammo = "MISSILE AMMO",
	mine_ammo = "MINE AMMO",
	emp_ammo = "EMP AMMO",
}

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	refresh()

func refresh() -> void:
	credits_label.text = "CREDITS: " + str(GameManager.credits)
	_refresh_upgrades()
	_refresh_customize()

func _refresh_upgrades() -> void:
	for child in upgrade_container.get_children():
		upgrade_container.remove_child(child)
		child.queue_free()
	for key in UPGRADE_NAMES:
		var level = GameManager.upgrade_levels.get(key, 1)
		var costs = UPGRADE_COSTS[key]
		var max_level = costs.size()
		var btn = Button.new()
		if level >= max_level - 1:
			btn.text = UPGRADE_NAMES[key] + " [MAX]"
			btn.disabled = true
		else:
			var cost = costs[level]
			btn.text = UPGRADE_NAMES[key] + " Lv." + str(level) + " -> " + str(cost) + "cr"
			btn.disabled = GameManager.credits < cost
			btn.pressed.connect(_on_upgrade_pressed.bind(key, cost))
		upgrade_container.add_child(btn)

func _on_upgrade_pressed(key: String, cost: int) -> void:
	if GameManager.spend_credits(cost):
		var costs = UPGRADE_COSTS[key]
		if GameManager.upgrade_levels[key] < costs.size() - 1:
			GameManager.upgrade_levels[key] += 1
		refresh()

func _refresh_customize() -> void:
	for child in customize_container.get_children():
		customize_container.remove_child(child)
		child.queue_free()
		
	if PackManager == null or not PackManager.has_method("get_discovered_pack_ids"):
		return
		
	var packs = PackManager.get_discovered_pack_ids()
	if packs.size() == 0:
		var lbl = Label.new()
		lbl.text = "No content packs found."
		customize_container.add_child(lbl)
		return
		
	for pack_id in packs:
		var info = PackManager.get_pack_info(pack_id)
		var hb = HBoxContainer.new()
		
		var lbl = Label.new()
		lbl.text = info.get("name", pack_id)
		lbl.custom_minimum_size = Vector2(200, 0)
		hb.add_child(lbl)

		var preview_btn = Button.new()
		preview_btn.text = "Preview"
		preview_btn.pressed.connect(func():
			_selected_preview_pack_id = pack_id
			_update_pack_preview(pack_id)
		)
		hb.add_child(preview_btn)
		
		for ctype in info.get("content_types", []):
			_add_toggle_button(hb, pack_id, ctype)
			
		customize_container.add_child(hb)

	if _selected_preview_pack_id.is_empty() or not ( _selected_preview_pack_id in packs ):
		_selected_preview_pack_id = packs[0]
	_build_preview_panel()
	_update_pack_preview(_selected_preview_pack_id)

func _build_preview_panel() -> void:
	_preview_panel = PanelContainer.new()
	_preview_panel.name = "PackPreviewPanel"
	_preview_panel.custom_minimum_size = Vector2(0, 120)
	var vb = VBoxContainer.new()
	vb.name = "PreviewContent"
	_preview_panel.add_child(vb)
	customize_container.add_child(_preview_panel)

func _update_pack_preview(pack_id: String) -> void:
	if not is_instance_valid(_preview_panel):
		return
	var vb: VBoxContainer = _preview_panel.get_node_or_null("PreviewContent")
	if not vb:
		return
	for child in vb.get_children():
		vb.remove_child(child)
		child.queue_free()
	var info = PackManager.get_pack_info(pack_id)
	if info.is_empty():
		return
	var title = Label.new()
	title.name = "PreviewTitle"
	title.text = "PREVIEW: " + str(info.get("name", pack_id))
	vb.add_child(title)

	var content_row = HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 12)
	vb.add_child(content_row)

	if info.has("skins") and info.skins is Dictionary and info.skins.has("player") and PackManager.has_method("load_pack_preview_texture"):
		var tex: Texture2D = PackManager.load_pack_preview_texture(pack_id, str(info.skins.player))
		if tex:
			var tr = TextureRect.new()
			tr.name = "SkinPreview"
			tr.texture = tex
			tr.custom_minimum_size = Vector2(64, 64)
			tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			content_row.add_child(tr)

	if info.has("theme") and info.theme is Dictionary and info.theme.has("palette") and info.theme.palette is Dictionary:
		var swatches = HBoxContainer.new()
		swatches.name = "ThemeSwatches"
		swatches.add_theme_constant_override("separation", 6)
		for key in info.theme.palette:
			var hex_str = str(info.theme.palette[key])
			if PackManager._is_valid_hex_color(hex_str):
				var swatch = ColorRect.new()
				swatch.custom_minimum_size = Vector2(24, 24)
				swatch.color = Color(hex_str)
				swatch.tooltip_text = str(key)
				swatches.add_child(swatch)
		content_row.add_child(swatches)

	if info.has("music") and info.music is Dictionary and info.music.has("tracks") and info.music.tracks is Array:
		var track_lbl = Label.new()
		track_lbl.name = "TrackCountLabel"
		track_lbl.text = "Music Tracks: " + str(info.music.tracks.size())
		content_row.add_child(track_lbl)

func _add_toggle_button(hb: HBoxContainer, pack_id: String, ctype: String) -> void:
	var is_active = PackManager.get_active_pack_id(ctype) == pack_id
	var btn = Button.new()
	if is_active:
		btn.text = "Disable " + ctype
		btn.pressed.connect(func():
			PackManager.deactivate_pack(ctype)
			_refresh_customize()
		)
	else:
		btn.text = "Enable " + ctype
		btn.pressed.connect(func():
			PackManager.activate_pack(pack_id, ctype)
			_refresh_customize()
		)
	hb.add_child(btn)

func _on_back_pressed() -> void:
	back_to_menu_requested.emit()

func _on_start_pressed() -> void:
	start_run_requested.emit()
