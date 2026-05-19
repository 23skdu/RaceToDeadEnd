extends Node

signal score_updated(score: int)
signal health_updated(health: int)
signal multiplier_updated(multiplier: int)
signal difficulty_tier_changed(tier: int)
signal game_over(final_score: int)
signal game_started
signal segment_advanced(segment: int)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var state: GameState = GameState.MENU
var score: int = 0
var health: int = 5
var max_health: int = 5
var multiplier: int = 1
var difficulty_tier: int = 1
var current_segment: int = 0
var credits: int = 0
var high_score: int = 0

const BASE_SCORE_RATE: int = 10
const SEGMENT_DISTANCE: float = 10.0
const DIFFICULTY_TIER_INTERVAL: int = 5
const BOSS_INTERVAL: int = 3000

var upgrade_levels: Dictionary = {
	max_health = 1,
	boost_capacity = 1,
	starting_ammo = 1,
	fire_rate = 1,
}

func _ready() -> void:
	load_progress()

func start_game() -> void:
	state = GameState.PLAYING
	score = 0
	health = max_health
	multiplier = 1
	difficulty_tier = 1
	current_segment = 0
	score_updated.emit(score)
	health_updated.emit(health)
	multiplier_updated.emit(multiplier)
	difficulty_tier_changed.emit(difficulty_tier)
	game_started.emit()

func add_score(points: int) -> void:
	score += points * multiplier
	score_updated.emit(score)
	if score > 0 and score % BOSS_INTERVAL < points * multiplier:
		pass
	if score > 0 and score / 1000 > (score - points * multiplier) / 1000:
		_advance_difficulty()

func add_health(amount: int) -> void:
	health = clampi(health + amount, 0, max_health)
	health_updated.emit(health)
	if health <= 0:
		end_game()

func take_damage(amount: int) -> void:
	add_health(-amount)

func set_multiplier(value: int) -> void:
	multiplier = clampi(value, 1, 8)
	multiplier_updated.emit(multiplier)

func advance_segment() -> void:
	current_segment += 1
	segment_advanced.emit(current_segment)
	if current_segment % DIFFICULTY_TIER_INTERVAL == 0:
		_advance_difficulty()

func _advance_difficulty() -> void:
	difficulty_tier = mini(difficulty_tier + 1, 20)
	difficulty_tier_changed.emit(difficulty_tier)

func end_game() -> void:
	state = GameState.GAME_OVER
	credits += score / 10
	if score > high_score:
		high_score = score
	save_progress()
	game_over.emit(score)

func add_credits(amount: int) -> void:
	credits += amount

func spend_credits(amount: int) -> bool:
	if credits >= amount:
		credits -= amount
		save_progress()
		return true
	return false

func save_progress() -> void:
	var save_data = {
		credits = credits,
		high_score = high_score,
		upgrade_levels = upgrade_levels.duplicate(),
	}
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	if file:
		file.store_var(save_data)

func load_progress() -> void:
	var file = FileAccess.open("user://save.dat", FileAccess.READ)
	if file:
		var data = file.get_var()
		if data:
			credits = data.get("credits", 0)
			high_score = data.get("high_score", 0)
			upgrade_levels = data.get("upgrade_levels", upgrade_levels)
