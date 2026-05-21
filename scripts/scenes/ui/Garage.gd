extends CanvasLayer

signal back_to_menu_requested
signal start_run_requested

@onready var credits_label: Label = $Panel/CreditsLabel
@onready var upgrade_container: VBoxContainer = $Panel/TabContainer/Upgrades
@onready var customize_container: VBoxContainer = $Panel/TabContainer/Customize
@onready var back_button: Button = $Panel/BackButton
@onready var start_button: Button = $Panel/StartButton

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
		lbl.text = info.name
		lbl.custom_minimum_size = Vector2(200, 0)
		hb.add_child(lbl)
		
		for ctype in info.get("content_types", []):
			var is_active = PackManager.get_active_pack_id(ctype) == pack_id
			var btn = Button.new()
			if is_active:
				btn.text = "Disable " + ctype
				var cb = func():
					PackManager.deactivate_pack(ctype)
					_refresh_customize()
				btn.pressed.connect(cb)
			else:
				btn.text = "Enable " + ctype
				var cb = func():
					PackManager.activate_pack(pack_id, ctype)
					_refresh_customize()
				btn.pressed.connect(cb)
			hb.add_child(btn)
			
		customize_container.add_child(hb)

func _on_back_pressed() -> void:
	back_to_menu_requested.emit()

func _on_start_pressed() -> void:
	start_run_requested.emit()
