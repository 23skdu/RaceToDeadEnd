extends CanvasLayer

signal restart_requested
signal garage_requested
signal menu_requested

@onready var final_score_label: Label = $Panel/FinalScore
@onready var high_score_label: Label = $Panel/HighScore
@onready var credits_label: Label = $Panel/CreditsEarned
@onready var continue_button: Button = $Panel/ContinueButton
@onready var garage_button: Button = $Panel/GarageButton
@onready var menu_button: Button = $Panel/MenuButton
@onready var press_space_label: Label = $Panel/PressSpaceLabel

var _stats_label: Label = null

func _ready() -> void:
	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)
	continue_button.pressed.connect(_on_continue_pressed)
	garage_button.pressed.connect(_on_garage_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	press_space_label.modulate = Color(1, 1, 1, 0)
	var panel = get_node_or_null("Panel")
	if panel:
		_stats_label = Label.new()
		_stats_label.name = "RunStatsLabel"
		_stats_label.offset_left = 40.0
		_stats_label.offset_top = 265.0
		_stats_label.offset_right = 560.0
		_stats_label.offset_bottom = 310.0
		_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_label.add_theme_font_size_override("font_size", 13)
		_stats_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		panel.add_child(_stats_label)
	hide()

func _on_game_over(final_score: int) -> void:
	final_score_label.text = "SCORE: " + str(final_score)
	high_score_label.text = "BEST: " + str(GameManager.high_score)
	credits_label.text = "CREDITS EARNED: +" + str(floori(final_score / 10.0))
	if _stats_label and "run_stats" in GameManager:
		var st: Dictionary = GameManager.run_stats
		var top_str := ""
		if "leaderboard" in GameManager and not GameManager.leaderboard.is_empty():
			top_str = " | TOP1: " + str(GameManager.leaderboard[0].get("score", 0))
		var ach_count: int = GameManager.unlocked_achievements.size() if "unlocked_achievements" in GameManager else 0
		_stats_label.text = "KILLS: %d | CIVS: %d | MAX x%d | SEG: %d | ACH: %d/%d%s" % [
			int(st.get("kills", 0)),
			int(st.get("civilians_protected", 0)),
			int(st.get("max_multiplier", 1)),
			int(st.get("segments_cleared", 0)),
			ach_count,
			GameManager.ACHIEVEMENT_TITLES.size(),
			top_str,
		]
	show()
	_fade_in_press_space()

func _fade_in_press_space() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(1.5)
	tween.tween_property(press_space_label, "modulate:a", 1.0, 0.4)

func _on_continue_pressed() -> void:
	hide()
	restart_requested.emit()

func _on_garage_pressed() -> void:
	hide()
	garage_requested.emit()

func _on_menu_pressed() -> void:
	hide()
	menu_requested.emit()
