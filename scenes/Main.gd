extends Node

@onready var start_button: Button = $CanvasLayer/StartButton
@onready var garage_button: Button = $CanvasLayer/GarageButton
@onready var options_button: Button = $CanvasLayer/OptionsButton
@onready var quit_button: Button = $CanvasLayer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	garage_button.pressed.connect(_on_garage_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	GameManager.state = GameManager.GameState.MENU

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_garage_pressed() -> void:
	var garage = preload("res://scenes/ui/Garage.tscn").instantiate()
	add_child(garage)
	garage.back_to_menu_requested.connect(func(): garage.queue_free())
	garage.start_run_requested.connect(func():
		garage.queue_free()
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	)

func _on_options_pressed() -> void:
	var options = preload("res://scenes/ui/Options.tscn").instantiate()
	add_child(options)
	options.back_to_menu_requested.connect(func(): options.queue_free())

func _on_quit_pressed() -> void:
	get_tree().quit()
