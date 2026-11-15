extends Node

@onready var start_button: Button = $CanvasLayer/StartButton
@onready var garage_button: Button = $CanvasLayer/GarageButton
@onready var info_button: Button = $CanvasLayer/InfoButton
@onready var options_button: Button = $CanvasLayer/OptionsButton
@onready var quit_button: Button = $CanvasLayer/QuitButton
@onready var version_label: Label = get_node_or_null("CanvasLayer/VersionLabel")

func _ready() -> void:
	if version_label:
		version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	start_button.pressed.connect(_on_start_pressed)
	garage_button.pressed.connect(_on_garage_pressed)
	info_button.pressed.connect(_on_info_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_setup_daily_run_button()
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

var daily_run_button: Button = null

func _setup_daily_run_button() -> void:
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas:
		return
	daily_run_button = Button.new()
	daily_run_button.name = "DailyRunButton"
	daily_run_button.text = "DAILY RUN"
	daily_run_button.offset_left = 810.0
	daily_run_button.offset_top = 300.0
	daily_run_button.offset_right = 990.0
	daily_run_button.offset_bottom = 360.0
	daily_run_button.pressed.connect(_on_daily_run_pressed)
	canvas.add_child(daily_run_button)

func _on_daily_run_pressed() -> void:
	GameManager.daily_run_active = true
	GameManager.daily_seed = GameManager.compute_daily_seed()
	TransitionLayer.change_scene("res://scenes/Game.tscn")

func _on_start_pressed() -> void:
	GameManager.daily_run_active = false
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
