extends CanvasLayer



@onready var score_label: Label = $ScoreLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var multiplier_label: Label = $MultiplierLabel
@onready var multiplier_timer_bar: ProgressBar = $MultiplierTimerBar
@onready var boost_container: HBoxContainer = $BoostContainer
@onready var weapon_icon: ColorRect = $WeaponIcon
@onready var ammo_label: Label = $AmmoLabel
@onready var tier_label: Label = $TierLabel

var boost_indicators: Array[Control] = []
var _multiplier_pulse_timer: float = 0.0

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.health_updated.connect(_on_health_updated)
	GameManager.multiplier_updated.connect(_on_multiplier_updated)
	GameManager.multiplier_timer_updated.connect(_on_multiplier_timer_updated)
	GameManager.difficulty_tier_changed.connect(_on_tier_changed)
	boost_indicators.assign(boost_container.get_children())

func _process(delta: float) -> void:
	if multiplier_timer_bar.visible:
		_multiplier_pulse_timer += delta

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

func update_boost_charges(charges: int) -> void:
	for i in boost_indicators.size():
		boost_indicators[i].visible = i < charges

func update_weapon_display(weapon_index: int, ammo: int) -> void:
	var wd = Constants.WEAPON_DATA
	weapon_icon.modulate = wd[weapon_index % wd.size()].color
	ammo_label.text = str(ammo)

func _on_game_over() -> void:
	visible = false
