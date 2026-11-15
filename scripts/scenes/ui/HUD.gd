extends CanvasLayer



@onready var score_label: Label = $ScoreLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var multiplier_label: Label = $MultiplierLabel
@onready var multiplier_timer_bar: ProgressBar = $MultiplierTimerBar
@onready var boost_container: HBoxContainer = $BoostContainer
@onready var weapon_icon: ColorRect = $WeaponIcon
@onready var ammo_label: Label = $AmmoLabel
@onready var tier_label: Label = $TierLabel
@onready var lives_label: Label = $LivesLabel

@onready var weapons_container: HBoxContainer = $WeaponsContainer
@onready var missile_panel: HBoxContainer = $WeaponsContainer/MissilePanel
@onready var missile_label: Label = $WeaponsContainer/MissilePanel/Label
@onready var mine_panel: HBoxContainer = $WeaponsContainer/MinePanel
@onready var mine_label: Label = $WeaponsContainer/MinePanel/Label
@onready var emp_panel: HBoxContainer = $WeaponsContainer/EmpPanel
@onready var emp_label: Label = $WeaponsContainer/EmpPanel/Label

var boost_indicators: Array[Control] = []
var _multiplier_pulse_timer: float = 0.0
var _boost_active: bool = false

var _player: Node = null
var _active_boss: Node = null
var _boss_max_hp: int = 1
var _boss_panel: VBoxContainer = null
var _boss_name_label: Label = null
var _boss_phase_label: Label = null
var _boss_hp_bar: ProgressBar = null

var _threat_layer: Control = null
var _threat_markers: Array[Label] = []
const MAX_THREAT_MARKERS: int = 8

var _touch_overlay: Control = null

const BOSS_DISPLAY_NAMES: Dictionary = {
	"boss_bunny": "CYBER BUNNY",
	"boss_giant_biker": "GIANT BIKER",
	"boss_void_drone": "VOID DRONE",
	"boss": "WAR RIG",
	"sasquatch": "SASQUATCH",
}

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.health_updated.connect(_on_health_updated)
	GameManager.multiplier_updated.connect(_on_multiplier_updated)
	GameManager.multiplier_timer_updated.connect(_on_multiplier_timer_updated)
	GameManager.difficulty_tier_changed.connect(_on_tier_changed)
	GameManager.lives_updated.connect(_on_lives_updated)
	boost_indicators.assign(boost_container.get_children().filter(func(c): return c is ColorRect))
	_on_lives_updated(GameManager.lives)
	if weapon_icon:
		weapon_icon.visible = false
	if ammo_label:
		ammo_label.visible = false

	# Dynamically instantiate TopWeatherBorder
	var weather_border_script = load("res://scripts/scenes/ui/TopWeatherBorder.gd")
	if weather_border_script:
		var wb = Control.new()
		wb.set_script(weather_border_script)
		wb.name = "TopWeatherBorder"
		add_child(wb)
		move_child(wb, 0)

	_setup_boss_bar()
	_setup_threat_indicators()
	_setup_touch_controls()

func _setup_boss_bar() -> void:
	_boss_panel = VBoxContainer.new()
	_boss_panel.name = "BossPanel"
	_boss_panel.position = Vector2(390, 82)
	_boss_panel.custom_minimum_size = Vector2(500, 44)
	_boss_panel.visible = false
	add_child(_boss_panel)

	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 12)
	_boss_panel.add_child(header)

	_boss_name_label = Label.new()
	_boss_name_label.name = "BossNameLabel"
	_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	_boss_name_label.add_theme_font_sizes_override("font_size", 16) if _boss_name_label.has_method("add_theme_font_sizes_override") else _boss_name_label.add_theme_font_size_override("font_size", 16)
	header.add_child(_boss_name_label)

	_boss_phase_label = Label.new()
	_boss_phase_label.name = "BossPhaseLabel"
	_boss_phase_label.text = "PHASE 1"
	_boss_phase_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_boss_phase_label.add_theme_font_size_override("font_size", 14)
	header.add_child(_boss_phase_label)

	_boss_hp_bar = ProgressBar.new()
	_boss_hp_bar.name = "BossHPBar"
	_boss_hp_bar.custom_minimum_size = Vector2(500, 16)
	_boss_hp_bar.modulate = Color(1.0, 0.2, 0.2)
	_boss_hp_bar.show_percentage = false
	_boss_panel.add_child(_boss_hp_bar)

func _setup_threat_indicators() -> void:
	_threat_layer = Control.new()
	_threat_layer.name = "ThreatIndicators"
	_threat_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_threat_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_threat_layer)
	for i in MAX_THREAT_MARKERS:
		var marker = Label.new()
		marker.text = "!"
		marker.visible = false
		marker.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		marker.add_theme_font_size_override("font_size", 22)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_threat_layer.add_child(marker)
		_threat_markers.append(marker)

func _setup_touch_controls() -> void:
	_touch_overlay = Control.new()
	_touch_overlay.name = "TouchControls"
	_touch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_overlay)

	var buttons_spec: Array[Dictionary] = [
		{"name": "TouchLeft", "label": "<", "action": "move_left", "pos": Vector2(24, 560), "size": Vector2(64, 64)},
		{"name": "TouchRight", "label": ">", "action": "move_right", "pos": Vector2(160, 560), "size": Vector2(64, 64)},
		{"name": "TouchAccel", "label": "^", "action": "accelerate", "pos": Vector2(92, 492), "size": Vector2(64, 64)},
		{"name": "TouchBrake", "label": "v", "action": "brake", "pos": Vector2(92, 624), "size": Vector2(64, 64)},
		{"name": "TouchFire", "label": "FIRE", "action": "primary_fire", "pos": Vector2(1150, 560), "size": Vector2(90, 64)},
		{"name": "TouchSecondary", "label": "WPN", "action": "secondary_fire", "pos": Vector2(1050, 560), "size": Vector2(84, 64)},
		{"name": "TouchBoost", "label": "BST", "action": "boost", "pos": Vector2(1150, 488), "size": Vector2(90, 56)},
		{"name": "TouchCycle", "label": "CYC", "action": "cycle_weapon", "pos": Vector2(1050, 488), "size": Vector2(84, 56)},
	]
	for spec in buttons_spec:
		var btn = Button.new()
		btn.name = spec["name"]
		btn.text = spec["label"]
		btn.position = spec["pos"]
		btn.size = spec["size"]
		btn.modulate = Color(1, 1, 1, 0.55)
		btn.focus_mode = Control.FOCUS_NONE
		var act: String = spec["action"]
		btn.button_down.connect(func(): Input.action_press(act))
		btn.button_up.connect(func(): Input.action_release(act))
		_touch_overlay.add_child(btn)
	refresh_touch_controls_visibility()

func refresh_touch_controls_visibility() -> void:
	if not is_instance_valid(_touch_overlay):
		return
	var mode := "auto"
	if SettingsManager and SettingsManager.has_method("get_touch_controls_mode"):
		mode = SettingsManager.get_touch_controls_mode()
	if mode == "on":
		_touch_overlay.visible = true
	elif mode == "off":
		_touch_overlay.visible = false
	else:
		_touch_overlay.visible = DisplayServer.is_touchscreen_available()

func set_touch_controls_visible(show_controls: bool) -> void:
	if is_instance_valid(_touch_overlay):
		_touch_overlay.visible = show_controls

func set_player(p: Node) -> void:
	_player = p

func bind_boss(boss: Node) -> void:
	if not is_instance_valid(boss):
		return
	_active_boss = boss
	var b_key: String = str(boss.get("boss_key")) if "boss_key" in boss else ""
	_boss_max_hp = maxi(1, int(boss.get("hp")) if "hp" in boss else 1)
	if _boss_name_label:
		_boss_name_label.text = BOSS_DISPLAY_NAMES.get(b_key, "BOSS")
	if _boss_phase_label:
		var p_val: int = int(boss.get("phase")) if "phase" in boss else 1
		_boss_phase_label.text = "PHASE %d" % p_val
	if _boss_hp_bar:
		_boss_hp_bar.max_value = _boss_max_hp
		_boss_hp_bar.value = _boss_max_hp
	if boss.has_signal("boss_phase_changed") and not boss.boss_phase_changed.is_connected(_on_boss_phase_changed):
		boss.boss_phase_changed.connect(_on_boss_phase_changed)
	if _boss_panel:
		_boss_panel.visible = true

func unbind_boss() -> void:
	_active_boss = null
	if _boss_panel:
		_boss_panel.visible = false

func _on_boss_phase_changed(new_phase: int) -> void:
	if _boss_phase_label:
		_boss_phase_label.text = "PHASE %d" % new_phase

func _process(delta: float) -> void:
	if multiplier_timer_bar.visible:
		_multiplier_pulse_timer += delta
	if _boost_active:
		var pulse = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
		for i in boost_indicators.size():
			if i < boost_indicators.size():
				boost_indicators[i].modulate = Color(1.0, pulse, 0.2)
	if is_instance_valid(_active_boss) and _boss_panel and _boss_panel.visible:
		var cur_hp: int = maxi(0, int(_active_boss.get("hp")) if "hp" in _active_boss else 0)
		if _boss_hp_bar:
			_boss_hp_bar.value = cur_hp
		if cur_hp <= 0 or not GameManager.boss_active:
			unbind_boss()
	elif _boss_panel and _boss_panel.visible and not GameManager.boss_active:
		unbind_boss()
	_update_threat_indicators()

func _update_threat_indicators() -> void:
	if _threat_markers.is_empty():
		return
	for m in _threat_markers:
		m.visible = false
	if GameManager.state != GameManager.GameState.PLAYING or not is_instance_valid(_player):
		return
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	var p_pos: Vector2 = _player.global_position
	var marker_idx := 0
	for enemy in GameManager.enemy_list:
		if marker_idx >= _threat_markers.size():
			break
		if not is_instance_valid(enemy):
			continue
		var delta_pos: Vector2 = enemy.global_position - p_pos
		if absf(delta_pos.x) > 580.0 or delta_pos.y < -420.0 or delta_pos.y > 260.0:
			if delta_pos.length_squared() <= 1400.0 * 1400.0:
				var m := _threat_markers[marker_idx]
				var sx := clampf(vp_size.x * 0.5 + delta_pos.x * 0.5, 24.0, vp_size.x - 36.0)
				var sy := 78.0 if delta_pos.y < -420.0 else (vp_size.y - 36.0 if delta_pos.y > 260.0 else clampf(vp_size.y * 0.5 + delta_pos.y * 0.4, 80.0, vp_size.y - 40.0))
				m.position = Vector2(sx, sy)
				m.visible = true
				marker_idx += 1

func _on_score_updated(score: int) -> void:
	score_label.text = str(score)

func _on_health_updated(health: int) -> void:
	health_bar.value = health

func _on_multiplier_updated(multiplier: int) -> void:
	multiplier_label.text = "x%d" % multiplier

func _on_multiplier_timer_updated(time_left: float) -> void:
	var active = time_left > 0.0
	multiplier_timer_bar.visible = active
	if active:
		multiplier_timer_bar.value = (time_left / Constants.MULTIPLIER_DURATION) * 100.0
		if time_left < 3.0:
			var pulse = 0.7 + 0.3 * sin(_multiplier_pulse_timer * 5.0)
			multiplier_timer_bar.modulate = Color(1.0, pulse, 0.0)
		else:
			multiplier_timer_bar.modulate = Color(1.0, 0.8, 0.0)
	else:
		_multiplier_pulse_timer = 0.0

func _on_tier_changed(tier: int) -> void:
	tier_label.text = "TIER %d" % tier

func _on_lives_updated(lives: int) -> void:
	lives_label.text = "♥ %d" % lives

func set_boost_active(active: bool) -> void:
	_boost_active = active
	if not active:
		for indicator in boost_indicators:
			indicator.modulate = Color.WHITE

func update_boost_charges(charges: int) -> void:
	for i in boost_indicators.size():
		boost_indicators[i].visible = i < charges

func update_weapon_display(weapon_index: int, ammo: int) -> void:
	var wd = Constants.WEAPON_DATA
	if weapon_icon:
		weapon_icon.modulate = wd[weapon_index % wd.size()].color
	if ammo_label:
		ammo_label.text = str(ammo)

func update_weapons(active_index: int, ammo_list: Array) -> void:
	var panels = [missile_panel, mine_panel, emp_panel]
	var labels = [missile_label, mine_label, emp_label]
	var prefixes = ["MSL: ", "MNE: ", "EMP: "]
	
	for i in range(panels.size()):
		if i < panels.size() and panels[i] and labels[i]:
			if i < ammo_list.size():
				var ammo = ammo_list[i]
				if ammo > 0:
					panels[i].visible = true
					labels[i].text = prefixes[i] + str(ammo)
					if i == active_index:
						panels[i].modulate.a = 1.0
					else:
						panels[i].modulate.a = 0.4
				else:
					panels[i].visible = false
			else:
				panels[i].visible = false

func _on_game_over() -> void:
	visible = false
