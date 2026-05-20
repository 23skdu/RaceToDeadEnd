extends CanvasLayer

const WEAPON_COLORS = [Color.RED, Color.YELLOW, Color.CYAN]

@onready var score_label: Label = $ScoreLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var multiplier_label: Label = $MultiplierLabel
@onready var boost_container: HBoxContainer = $BoostContainer
@onready var weapon_icon: ColorRect = $WeaponIcon
@onready var ammo_label: Label = $AmmoLabel
@onready var tier_label: Label = $TierLabel

var boost_indicators: Array[Control] = []

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.health_updated.connect(_on_health_updated)
	GameManager.multiplier_updated.connect(_on_multiplier_updated)
	GameManager.difficulty_tier_changed.connect(_on_tier_changed)
	boost_indicators.assign(boost_container.get_children())

func _on_score_updated(score: int) -> void:
	score_label.text = str(score)

func _on_health_updated(health: int) -> void:
	health_bar.value = health

func _on_multiplier_updated(multiplier: int) -> void:
	multiplier_label.text = "x" + str(multiplier)

func _on_tier_changed(tier: int) -> void:
	tier_label.text = "TIER " + str(tier)

func update_boost_charges(charges: int) -> void:
	for i in boost_indicators.size():
		boost_indicators[i].visible = i < charges

func update_weapon_display(weapon_index: int, ammo: int) -> void:
	weapon_icon.modulate = WEAPON_COLORS[weapon_index]
	ammo_label.text = str(ammo)

func _on_game_over() -> void:
	visible = false
