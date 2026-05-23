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
	AudioManager.play_menu_music()
	
	_add_controls_label()

func _add_controls_label() -> void:
	var label = Label.new()
	label.text = "CONTROLS\nKeyboard: WASD/Arrows to Move, Space/Shift to Fire\nWeapons: E for EMP, M for Mines, Q to Cycle\nController: D-Pad/Left Stick to Move, A/B to Fire, Y to Cycle"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_bottom = -20
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	$CanvasLayer.add_child(label)

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
