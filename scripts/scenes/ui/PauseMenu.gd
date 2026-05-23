extends CanvasLayer

signal resume_requested
signal options_requested
signal quit_requested

@onready var panel: Panel = $Panel
@onready var resume_btn: Button = $Panel/VBox/ResumeButton
@onready var options_btn: Button = $Panel/VBox/OptionsButton
@onready var quit_btn: Button = $Panel/VBox/QuitButton

func _ready() -> void:
	resume_btn.pressed.connect(_on_resume)
	options_btn.pressed.connect(_on_options)
	quit_btn.pressed.connect(_on_quit)

func _on_resume() -> void:
	resume_requested.emit()

func _on_options() -> void:
	options_requested.emit()

func _on_quit() -> void:
	quit_requested.emit()
