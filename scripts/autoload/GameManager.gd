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

var enemy_list: Array[Node] = []

var upgrade_levels: Dictionary = {
	max_health = 1,
	boost_capacity = 1,
	fire_rate = 1,
	missile_ammo = 1,
	mine_ammo = 1,
	emp_ammo = 1,
}

var _difficulty_progress: float = 0.0
var _multiplier_timer: float = 0.0
var _base_multiplier: int = 1
var _last_tier_threshold: int = 0

var _score_ticker: Timer
var current_speed: float = Constants.BASE_SPEED

signal speed_changed(speed: float)

func _ready() -> void:
	_add_input_mappings()
	load_progress()
	_score_ticker = Timer.new()
	_score_ticker.name = "ScoreTicker"
	_score_ticker.wait_time = 1.0
	_score_ticker.timeout.connect(_on_score_tick)
	_score_ticker.one_shot = false
	add_child(_score_ticker)

func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	
	if _multiplier_timer > 0.0:
		_multiplier_timer -= delta
		multiplier_timer_updated.emit(_multiplier_timer)
		if _multiplier_timer <= 0.0:
			_reset_multiplier()

func _on_score_tick() -> void:
	if state != GameState.PLAYING:
		return
	add_score(Constants.SCORE_RATE)

func start_game() -> void:
	state = GameState.PLAYING
	score = 0
	_difficulty_progress = 0.0
	_multiplier_timer = 0.0
	_base_multiplier = 1
	max_health = 4 + upgrade_levels.get("max_health", 1)
	health = max_health
	multiplier = 1
	difficulty_tier = 1
	current_segment = 0
	current_speed = Constants.BASE_SPEED
	speed_changed.emit(current_speed)
	score_updated.emit(score)
	health_updated.emit(health)
	multiplier_updated.emit(multiplier)
	difficulty_tier_changed.emit(difficulty_tier)
	game_started.emit()
	if _score_ticker:
		_score_ticker.start()

func register_enemy_spawned(enemy: Node) -> void:
	enemy_list.append(enemy)

func register_enemy_destroyed(enemy: Node) -> void:
	enemy_list.erase(enemy)

func add_score(points: int) -> void:
	var multiplied_points = points * multiplier
	score += multiplied_points
	_difficulty_progress += multiplied_points
	score_updated.emit(score)
	_check_difficulty_advance()

func _check_difficulty_advance() -> void:
	var new_tier = mini(1 + floori(_difficulty_progress / Constants.TIER_THRESHOLD), Constants.MAX_TIER)
	if new_tier > difficulty_tier:
		difficulty_tier = new_tier
		current_speed = mini(Constants.BASE_SPEED + (difficulty_tier - 1) * Constants.SPEED_PER_TIER, Constants.MAX_GAME_SPEED)
		difficulty_tier_changed.emit(difficulty_tier)
		speed_changed.emit(current_speed)

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
	_multiplier_timer = Constants.MULTIPLIER_DURATION
	multiplier_updated.emit(multiplier)

func _reset_multiplier() -> void:
	multiplier = _base_multiplier
	multiplier_updated.emit(multiplier)

func advance_segment() -> void:
	current_segment += 1
	_difficulty_progress += Constants.SEGMENT_DIFFICULTY_BONUS
	segment_advanced.emit(current_segment)
	_check_difficulty_advance()

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
		get_tree().paused = false
		return true
	return false

func _add_input_mappings() -> void:
	# Gamepad mappings
	_add_joy_motion("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_motion("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	
	_add_joy_motion("accelerate", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_button("accelerate", JOY_BUTTON_DPAD_UP)
	_add_joy_motion("brake", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button("brake", JOY_BUTTON_DPAD_DOWN)
	
	_add_joy_button("primary_fire", JOY_BUTTON_A)
	_add_joy_button("secondary_fire", JOY_BUTTON_B)
	_add_joy_button("boost", JOY_BUTTON_X)
	_add_joy_button("cycle_weapon", JOY_BUTTON_Y)
	
	# Keyboard arrow keys (added programmatically just in case)
	_add_key_mapping("move_left", KEY_LEFT)
	_add_key_mapping("move_right", KEY_RIGHT)
	_add_key_mapping("accelerate", KEY_UP)
	_add_key_mapping("brake", KEY_DOWN)
	
	# Explicit weapon binds
	_add_key_mapping("fire_emp", KEY_E)
	_add_key_mapping("drop_mine", KEY_M)
	_add_key_mapping("primary_fire", KEY_SPACE)

func _add_key_mapping(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)
	
func _add_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		return
	var ev = InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_joy_motion(action: String, axis: int, dir: float) -> void:
	if not InputMap.has_action(action):
		return
	var ev = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)

func save_progress() -> void:
	var payload = {
		credits = credits,
		high_score = high_score,
		upgrade_levels = upgrade_levels.duplicate(),
	}
	var payload_str = var_to_str(payload)
	var save_data = {
		payload = payload,
		_checksum = hash(payload_str),
	}
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	if file:
		file.store_var(save_data)

func load_progress() -> void:
	var file = FileAccess.open("user://save.dat", FileAccess.READ)
	if file:
		var data = file.get_var()
		if data is Dictionary:
			var payload = data.get("payload")
			var stored_checksum = data.get("_checksum", 0)
			if payload is Dictionary and stored_checksum != 0:
				var expected_checksum = hash(var_to_str(payload))
				if expected_checksum != stored_checksum:
					push_warning("Save file checksum mismatch, using defaults")
					return
			if payload is Dictionary:
				if payload.has("credits") and typeof(payload.credits) == TYPE_INT:
					credits = maxi(0, payload.credits)
				if payload.has("high_score") and typeof(payload.high_score) == TYPE_INT:
					high_score = maxi(0, payload.high_score)
				if payload.has("upgrade_levels") and typeof(payload.upgrade_levels) == TYPE_DICTIONARY:
					for key in upgrade_levels:
						if payload.upgrade_levels.has(key) and typeof(payload.upgrade_levels[key]) == TYPE_INT:
							var val = clampi(payload.upgrade_levels[key], 1, 5)
							upgrade_levels[key] = val
		else:
			push_warning("Save data corrupted, using defaults")
			credits = 0
			high_score = 0
