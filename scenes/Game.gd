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
	
	if player:
		player.weapon_fired.connect(_on_player_weapon_fired)
		player.weapon_switched.connect(func(idx): hud.update_weapon_display(idx, player.secondary_ammo[idx]))
		player.boost_charge_updated.connect(hud.update_boost_charges)
		
		# Initial UI sync
		hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
		hud.update_boost_charges(player.boost_charges)
		
	if game_over and game_over.has_signal("restart_requested"):
		game_over.restart_requested.connect(_restart_game)
	if game_over and game_over.has_signal("menu_requested"):
		game_over.menu_requested.connect(_go_to_menu)

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _process(_delta: float) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		if Input.is_action_just_pressed("ui_accept"):
			_restart_game()

func _on_player_weapon_fired(type: String, pos: Vector2, dir: Vector2) -> void:
	match type:
		"machine_gun":
			var bullet_scene = load("res://scenes/weapons/Bullet.tscn")
			var bullet = bullet_scene.instantiate()
			world.add_child(bullet)
			bullet.init(pos, dir, true)
			AudioManager.play_synth_laser(pos)
		"missile":
			var bullet_scene = load("res://scenes/weapons/Bullet.tscn")
			var bullet = bullet_scene.instantiate()
			world.add_child(bullet)
			bullet.init(pos, dir, true)
			bullet.homing_strength = 6.0
			bullet.damage = 3
			bullet.scale = Vector2(1.8, 1.8)
			bullet.modulate = Color(1.0, 0.25, 0.25)
			hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
			AudioManager.play_synth_laser(pos)
		"mine":
			var mine_scene = load("res://scenes/weapons/Mine.tscn")
			var mine = mine_scene.instantiate()
			world.add_child(mine)
			if mine.has_method("init"):
				mine.init(pos)
			else:
				mine.global_position = pos
			hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
			AudioManager.play_synth_laser(pos)
		"emp":
			var emp_scene = load("res://scenes/weapons/EMPBlast.tscn")
			var emp = emp_scene.instantiate()
			world.add_child(emp)
			if emp.has_method("init"):
				emp.init(pos)
			else:
				emp.global_position = pos
			hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
			AudioManager.play_synth_emp(pos)
