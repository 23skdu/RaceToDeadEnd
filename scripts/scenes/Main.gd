extends Node

@onready var start_button: Button = $CanvasLayer/StartButton
@onready var garage_button: Button = $CanvasLayer/GarageButton
@onready var info_button: Button = $CanvasLayer/InfoButton
@onready var options_button: Button = $CanvasLayer/OptionsButton
@onready var quit_button: Button = $CanvasLayer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	garage_button.pressed.connect(_on_garage_pressed)
	info_button.pressed.connect(_on_info_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	GameManager.state = GameManager.GameState.MENU
	AudioManager.play_menu_music()
	
	var bg: TextureRect = $CanvasLayer/Background
	if bg:
		bg.anchor_left = 0.1
		bg.anchor_top = 0.1
		bg.anchor_right = 0.9
		bg.anchor_bottom = 0.9
		bg.offset_left = 0
		bg.offset_top = 0
		bg.offset_right = 0
		bg.offset_bottom = 0
		bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
		bg.grow_vertical = Control.GROW_DIRECTION_BOTH

func _on_info_pressed() -> void:
	var info = preload("res://scenes/ui/InterceptorInfo.tscn").instantiate()
	add_child(info)
	info.back_to_menu_requested.connect(func(): info.queue_free())

func _on_start_pressed() -> void:
	TransitionLayer.change_scene("res://scenes/Game.tscn")

func _on_garage_pressed() -> void:
	var garage = preload("res://scenes/ui/Garage.tscn").instantiate()
	add_child(garage)
	garage.back_to_menu_requested.connect(func(): garage.queue_free())
	garage.start_run_requested.connect(func():
		garage.queue_free()
		TransitionLayer.change_scene("res://scenes/Game.tscn")
	)

func _on_options_pressed() -> void:
	var options = preload("res://scenes/ui/Options.tscn").instantiate()
	add_child(options)
	options.back_to_menu_requested.connect(func(): options.queue_free())

func _on_quit_pressed() -> void:
	get_tree().quit()
