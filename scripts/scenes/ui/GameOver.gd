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

func _ready() -> void:
	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)
	continue_button.pressed.connect(_on_continue_pressed)
	garage_button.pressed.connect(_on_garage_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	hide()

func _on_game_over(final_score: int) -> void:
	final_score_label.text = "SCORE: " + str(final_score)
	high_score_label.text = "BEST: " + str(GameManager.high_score)
	credits_label.text = "CREDITS EARNED: +" + str(floori(final_score / 10.0))
	show()

func _on_continue_pressed() -> void:
	hide()
	restart_requested.emit()

func _on_garage_pressed() -> void:
	hide()
	garage_requested.emit()

func _on_menu_pressed() -> void:
	hide()
	menu_requested.emit()
