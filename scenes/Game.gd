extends Node

@onready var world: Node2D = $World
@onready var highway: Node2D = $World/Highway
@onready var spawner: Node = $World/Spawner
@onready var player: CharacterBody2D = $World/Player
@onready var hud: CanvasLayer = $UI/HUD
@onready var game_over: CanvasLayer = $UI/GameOver

func _ready() -> void:
	GameManager.start_game()
	spawner.player = player
	highway.player = player
	if game_over and game_over.has_signal("restart_requested"):
		game_over.restart_requested.connect(_restart_game)
	if game_over and game_over.has_signal("menu_requested"):
		game_over.menu_requested.connect(_go_to_menu)

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _process(delta: float) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		if Input.is_action_just_pressed("ui_accept"):
			_restart_game()
