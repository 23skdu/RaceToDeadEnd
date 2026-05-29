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

func _process(delta: float) -> void:
	if multiplier_timer_bar.visible:
		_multiplier_pulse_timer += delta
	if _boost_active:
		var pulse = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
		for i in boost_indicators.size():
			if i < boost_indicators.size():
				boost_indicators[i].modulate = Color(1.0, pulse, 0.2) if i < boost_indicators.size() else Color.WHITE

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
		_multiplier_pulse_timer = 0.0
		multiplier_timer_bar.value = (time_left / Constants.MULTIPLIER_DURATION) * 100.0
		if time_left < 3.0:
			var pulse = 0.7 + 0.3 * sin(_multiplier_pulse_timer * 5.0)
			multiplier_timer_bar.modulate = Color(1.0, pulse, 0.0)

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
