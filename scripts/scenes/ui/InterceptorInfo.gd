extends CanvasLayer

signal back_to_menu_requested

@onready var back_button: Button = $Panel/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	back_to_menu_requested.emit()
