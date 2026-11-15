extends Node

signal score_updated(score: int)
signal health_updated(health: int)
signal multiplier_updated(multiplier: int)
signal difficulty_tier_changed(tier: int)
signal game_over(final_score: int)
signal game_started
signal segment_advanced(segment: int)
signal multiplier_timer_updated(time_left: float)
signal lives_updated(lives: int)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var state: GameState = GameState.MENU
var score: int = 0
var health: int = 5
var max_health: int = 5
var lives: int = 3
var max_lives: int = 3
var multiplier: int = 1
var difficulty_tier: int = 1
var current_segment: int = 0
var credits: int = 0
var high_score: int = 0

var enemy_list: Array[Node] = []
var bosses_killed: int = 0
var first_boss_defeated: bool = false
var boss_active: bool = false

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

var _score_ticker: Timer
var current_speed: float = Constants.BASE_SPEED

signal speed_changed(speed: float)
signal achievement_unlocked(achievement_id: String, title: String)

const SAVE_PATH: String = "user://save.dat"
const SAVE_TMP_PATH: String = "user://save.dat.tmp"
const SAVE_VERSION: int = 2
const MAX_LEADERBOARD_ENTRIES: int = 10

const ACHIEVEMENT_TITLES: Dictionary = {
	"first_blood": "First Blood (10 Kills)",
	"centurion": "Road Warrior (50 Kills)",
	"boss_slayer": "Boss Slayer (Defeat a Boss)",
	"protector": "Guardian (Protect 3 Civilians)",
	"speed_demon": "Speed Demon (Reach Tier 5)",
	"high_roller": "Legend (Score 10,000+)",
}

var daily_run_active: bool = false
var daily_seed: int = 0
var leaderboard: Array[Dictionary] = []
var unlocked_achievements: Array[String] = []
var run_stats: Dictionary = {
	"kills": 0,
	"kills_by_type": {},
	"civilians_protected": 0,
	"civilians_damaged": 0,
	"max_multiplier": 1,
	"segments_cleared": 0,
	"daily": false,
}

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
	lives = max_lives
	multiplier = 1
	difficulty_tier = 1
	current_segment = 0
	boss_active = false
	enemy_list.clear()
	run_stats = {
		"kills": 0,
		"kills_by_type": {},
		"civilians_protected": 0,
		"civilians_damaged": 0,
		"max_multiplier": 1,
		"segments_cleared": 0,
		"daily": daily_run_active,
	}
	current_speed = Constants.BASE_SPEED
	speed_changed.emit(current_speed)
	score_updated.emit(score)
	health_updated.emit(health)
	lives_updated.emit(lives)
	multiplier_updated.emit(multiplier)
	difficulty_tier_changed.emit(difficulty_tier)
	game_started.emit()
	if _score_ticker:
		_score_ticker.start()

static func compute_daily_seed(date_dict: Dictionary = {}) -> int:
	var d: Dictionary = date_dict if not date_dict.is_empty() else Time.get_date_dict_from_system(true)
	var date_str := "%04d-%02d-%02d" % [int(d.get("year", 2026)), int(d.get("month", 1)), int(d.get("day", 1))]
	return int(hash("daily_run:" + date_str))

func start_daily_run() -> void:
	daily_run_active = true
	daily_seed = compute_daily_seed()
	start_game()

func record_run_kill(enemy_type: String) -> void:
	run_stats["kills"] = int(run_stats.get("kills", 0)) + 1
	var by_type: Dictionary = run_stats.get("kills_by_type", {})
	by_type[enemy_type] = int(by_type.get(enemy_type, 0)) + 1
	run_stats["kills_by_type"] = by_type
	var total_kills: int = int(run_stats["kills"])
	if total_kills >= 10:
		_unlock_achievement("first_blood")
	if total_kills >= 50:
		_unlock_achievement("centurion")
	if enemy_type.begins_with("boss"):
		first_boss_defeated = true
		_unlock_achievement("boss_slayer")

func record_boss_defeated(_boss_type: String = "") -> void:
	bosses_killed += 1
	first_boss_defeated = true
	save_progress()

func is_skin_unlocked(skin_id: String) -> bool:
	if skin_id == "urban_camo":
		return first_boss_defeated or bosses_killed >= 1 or ("boss_slayer" in unlocked_achievements)
	for skin in Constants.PLAYER_SKINS:
		if str(skin.get("id", "")) == skin_id:
			return not bool(skin.get("unlock_boss", false))
	return false

func record_civilian_protected() -> void:
	run_stats["civilians_protected"] = int(run_stats.get("civilians_protected", 0)) + 1
	if int(run_stats["civilians_protected"]) >= 3:
		_unlock_achievement("protector")

func record_civilian_damaged() -> void:
	run_stats["civilians_damaged"] = int(run_stats.get("civilians_damaged", 0)) + 1

func _unlock_achievement(ach_id: String) -> void:
	if ach_id in unlocked_achievements or not ACHIEVEMENT_TITLES.has(ach_id):
		return
	unlocked_achievements.append(ach_id)
	achievement_unlocked.emit(ach_id, ACHIEVEMENT_TITLES[ach_id])

func register_enemy_spawned(enemy: Node) -> void:
	if is_instance_valid(enemy) and not enemy_list.has(enemy):
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
		current_speed = minf(Constants.BASE_SPEED + (difficulty_tier - 1) * Constants.SPEED_PER_TIER, Constants.MAX_GAME_SPEED)
		if difficulty_tier >= 5:
			_unlock_achievement("speed_demon")
		difficulty_tier_changed.emit(difficulty_tier)
		speed_changed.emit(current_speed)

func add_health(amount: int) -> void:
	health = clampi(health + amount, 0, max_health)
	health_updated.emit(health)
	if health <= 0:
		# Consume a life
		lives -= 1
		lives_updated.emit(lives)
		if lives > 0:
			health = max_health
			health_updated.emit(health)
		else:
			end_game()

func take_damage(amount: int) -> void:
	add_health(-amount)

func set_multiplier(value: int) -> void:
	multiplier = clampi(value, 1, 8)
	run_stats["max_multiplier"] = maxi(int(run_stats.get("max_multiplier", 1)), multiplier)
	multiplier_updated.emit(multiplier)

func add_temporary_multiplier(bonus: int) -> void:
	_base_multiplier = multiplier
	multiplier = clampi(multiplier + bonus, 1, 8)
	run_stats["max_multiplier"] = maxi(int(run_stats.get("max_multiplier", 1)), multiplier)
	_multiplier_timer = Constants.MULTIPLIER_DURATION
	multiplier_updated.emit(multiplier)

func _reset_multiplier() -> void:
	multiplier = _base_multiplier
	multiplier_updated.emit(multiplier)

func advance_segment() -> void:
	current_segment += 1
	run_stats["segments_cleared"] = current_segment
	_difficulty_progress += Constants.SEGMENT_DIFFICULTY_BONUS
	segment_advanced.emit(current_segment)
	if credits > 0 or score > 0:
		save_progress()
	_check_difficulty_advance()

func end_game() -> void:
	state = GameState.GAME_OVER
	credits += floori(score / 10.0)
	if score > high_score:
		high_score = score
	if score >= 10000:
		_unlock_achievement("high_roller")
	if score > 0:
		var entry := {
			"score": score,
			"tier": difficulty_tier,
			"segments": current_segment,
			"daily": daily_run_active,
		}
		leaderboard.append(entry)
		leaderboard.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
		if leaderboard.size() > MAX_LEADERBOARD_ENTRIES:
			leaderboard.resize(MAX_LEADERBOARD_ENTRIES)
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
	_add_key_mapping("fire_emp", KEY_F)
	_add_key_mapping("drop_mine", KEY_V)
	_add_key_mapping("cycle_weapon", KEY_R)
	_add_key_mapping("primary_fire", KEY_SPACE)
	if not InputMap.has_action("screenshot"):
		_add_key_mapping("screenshot", KEY_F12)

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

func _get_save_passphrase() -> String:
	return "RaceToDeadEnd::v2::SaveKey::" + str(ProjectSettings.get_setting("application/config/name", "Race to Dead End"))

func _compute_save_checksum(payload: Dictionary) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("R2DE_SAVE_V2:" + JSON.stringify(payload, "", true)).to_utf8_buffer())
	return ctx.finish().hex_encode()

func save_progress() -> void:
	var payload = {
		"credits": credits,
		"high_score": high_score,
		"upgrade_levels": upgrade_levels.duplicate(),
		"leaderboard": leaderboard.duplicate(true),
		"achievements": unlocked_achievements.duplicate(),
		"first_boss_defeated": first_boss_defeated,
	}
	var save_data = {
		"version": SAVE_VERSION,
		"payload": payload,
		"_checksum": _compute_save_checksum(payload),
	}
	var file = FileAccess.open_encrypted_with_pass(SAVE_TMP_PATH, FileAccess.WRITE, _get_save_passphrase())
	if file:
		file.store_var(save_data)
		file.close()
		var err = DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)
		if err != OK:
			var fallback = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, _get_save_passphrase())
			if fallback:
				fallback.store_var(save_data)
				fallback.close()

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var probe := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not probe:
		push_warning("Save data corrupted, using defaults")
		credits = 0
		high_score = 0
		return
	var file_len := probe.get_length()
	var magic := probe.get_32() if file_len >= 4 else 0
	probe.close()
	if file_len < 32 or magic != 0x43454447:
		push_warning("Save data corrupted, using defaults")
		credits = 0
		high_score = 0
		return
	var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, _get_save_passphrase())
	if not file:
		push_warning("Save data corrupted, using defaults")
		credits = 0
		high_score = 0
		return
	var data = file.get_var()
	file.close()
	if not (data is Dictionary):
		push_warning("Save data corrupted, using defaults")
		credits = 0
		high_score = 0
		return
	var payload = data.get("payload")
	var stored_checksum = data.get("_checksum", "")
	if not (payload is Dictionary) or not (stored_checksum is String) or stored_checksum.length() != 64:
		push_warning("Save file checksum mismatch, using defaults")
		return
	var expected_checksum = _compute_save_checksum(payload)
	if expected_checksum != stored_checksum:
		push_warning("Save file checksum mismatch, using defaults")
		return
	if payload.has("credits") and (typeof(payload.credits) == TYPE_INT or typeof(payload.credits) == TYPE_FLOAT):
		credits = maxi(0, int(payload.credits))
	if payload.has("high_score") and (typeof(payload.high_score) == TYPE_INT or typeof(payload.high_score) == TYPE_FLOAT):
		high_score = maxi(0, int(payload.high_score))
	if payload.has("upgrade_levels") and typeof(payload.upgrade_levels) == TYPE_DICTIONARY:
		for key in upgrade_levels:
			if payload.upgrade_levels.has(key) and (typeof(payload.upgrade_levels[key]) == TYPE_INT or typeof(payload.upgrade_levels[key]) == TYPE_FLOAT):
				var val = clampi(int(payload.upgrade_levels[key]), 1, 5)
				upgrade_levels[key] = val
	if payload.has("leaderboard") and typeof(payload.leaderboard) == TYPE_ARRAY:
		leaderboard.clear()
		for entry in payload.leaderboard:
			if entry is Dictionary and leaderboard.size() < MAX_LEADERBOARD_ENTRIES:
				leaderboard.append({
					"score": maxi(0, int(entry.get("score", 0))),
					"tier": clampi(int(entry.get("tier", 1)), 1, Constants.MAX_TIER),
					"segments": maxi(0, int(entry.get("segments", 0))),
					"daily": bool(entry.get("daily", false)),
				})
	if payload.has("achievements") and typeof(payload.achievements) == TYPE_ARRAY:
		unlocked_achievements.clear()
		for ach in payload.achievements:
			if ach is String and ACHIEVEMENT_TITLES.has(ach) and not (ach in unlocked_achievements):
				unlocked_achievements.append(ach)
	if payload.has("first_boss_defeated") and typeof(payload.first_boss_defeated) == TYPE_BOOL:
		first_boss_defeated = payload.first_boss_defeated
	elif "boss_slayer" in unlocked_achievements:
		first_boss_defeated = true
