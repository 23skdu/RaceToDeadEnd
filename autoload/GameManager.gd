extends Node

signal score_updated(score: int)
signal health_updated(health: int)
signal multiplier_updated(multiplier: int)
signal difficulty_tier_changed(tier: int)
signal game_over(final_score: int)
signal game_started
signal segment_advanced(segment: int)
signal multiplier_timer_updated(time_left: float)

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
const MULTIPLIER_DURATION: float = 10.0

var upgrade_levels: Dictionary = {
	max_health = 1,
	boost_capacity = 1,
	starting_ammo = 1,
	fire_rate = 1,
}

var _score_timer: float = 0.0
var _difficulty_progress: float = 0.0
var _multiplier_timer: float = 0.0
var _base_multiplier: int = 1

func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		_score_timer += delta
		if _score_timer >= 1.0:
			_score_timer -= 1.0
			add_score(BASE_SCORE_RATE)
		
		if _multiplier_timer > 0.0:
			_multiplier_timer -= delta
			multiplier_timer_updated.emit(_multiplier_timer)
			if _multiplier_timer <= 0.0:
				_reset_multiplier()

func _ready() -> void:
	load_progress()

func start_game() -> void:
	state = GameState.PLAYING
	score = 0
	_score_timer = 0.0
	_difficulty_progress = 0.0
	_multiplier_timer = 0.0
	_base_multiplier = 1
	max_health = 4 + upgrade_levels.get("max_health", 1)
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
	var multiplied_points = points * multiplier
	score += multiplied_points
	_difficulty_progress += multiplied_points
	score_updated.emit(score)
	if score > 0 and floori(score / 1000.0) > floori((score - multiplied_points) / 1000.0):
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

func add_temporary_multiplier(bonus: int) -> void:
	_base_multiplier = multiplier
	multiplier = clampi(multiplier + bonus, 1, 8)
	_multiplier_timer = MULTIPLIER_DURATION
	multiplier_updated.emit(multiplier)

func _reset_multiplier() -> void:
	multiplier = _base_multiplier
	multiplier_updated.emit(multiplier)

func advance_segment() -> void:
	current_segment += 1
	_difficulty_progress += 200.0
	segment_advanced.emit(current_segment)
	if current_segment % DIFFICULTY_TIER_INTERVAL == 0:
		_advance_difficulty()

func _advance_difficulty() -> void:
	difficulty_tier = mini(difficulty_tier + 1, 20)
	difficulty_tier_changed.emit(difficulty_tier)

func end_game() -> void:
	state = GameState.GAME_OVER
	credits += floori(score / 10.0)
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
		if data is Dictionary:
			if data.has("credits") and typeof(data.credits) == TYPE_INT:
				credits = data.credits
			if data.has("high_score") and typeof(data.high_score) == TYPE_INT:
				high_score = data.high_score
			if data.has("upgrade_levels") and typeof(data.upgrade_levels) == TYPE_DICTIONARY:
				for key in upgrade_levels:
					if data.upgrade_levels.has(key) and typeof(data.upgrade_levels[key]) == TYPE_INT:
						upgrade_levels[key] = data.upgrade_levels[key]
