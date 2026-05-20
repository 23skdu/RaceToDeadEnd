extends Node

const BULLET_SCENE = preload("res://scenes/weapons/Bullet.tscn")
const MINE_SCENE = preload("res://scenes/weapons/Mine.tscn")
const EMP_SCENE = preload("res://scenes/weapons/EMPBlast.tscn")

@onready var world: Node2D = $World
@onready var highway: Node2D = $World/Highway
@onready var spawner: Node = $World/Spawner
@onready var player: CharacterBody2D = $World/Player
@onready var hud: CanvasLayer = $UI/HUD
@onready var game_over: CanvasLayer = $UI/GameOver

func _ready() -> void:
	ObjectPool.create_pool("bullet", BULLET_SCENE, 50)
	ObjectPool.create_pool("mine", MINE_SCENE, 10)
	ObjectPool.create_pool("emp", EMP_SCENE, 5)
	
	GameManager.start_game()
	spawner.player = player
	spawner.world_node = world
	highway.player = player
	
	if player:
		player.weapon_fired.connect(_on_player_weapon_fired)
		player.weapon_switched.connect(func(idx): hud.update_weapon_display(idx, player.secondary_ammo[idx]))
		player.boost_charge_updated.connect(hud.update_boost_charges)
		
		highway.ice_entered.connect(player.set_slippery.bind(true))
		highway.ice_exited.connect(player.set_slippery.bind(false))
		highway.bridge_fall.connect(_on_bridge_fall)
		
		# Initial UI sync
		hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
		hud.update_boost_charges(player.boost_charges)
		
	if game_over and game_over.has_signal("restart_requested"):
		game_over.restart_requested.connect(_restart_game)
	if game_over and game_over.has_signal("menu_requested"):
		game_over.menu_requested.connect(_go_to_menu)
	if game_over and game_over.has_signal("garage_requested"):
		game_over.garage_requested.connect(_go_to_garage)
	
	if hud:
		GameManager.game_over.connect(hud._on_game_over)

func _on_bridge_fall(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(2)
	if "current_lane" in body:
		if body.position.x < 0:
			body.position.x = -32
			body.current_lane = 1
		else:
			body.position.x = 32
			body.current_lane = 2

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _go_to_garage() -> void:
	var garage = preload("res://scenes/ui/Garage.tscn").instantiate()
	add_child(garage)
	garage.back_to_menu_requested.connect(func():
		garage.queue_free()
		_go_to_menu()
	)
	garage.start_run_requested.connect(func():
		garage.queue_free()
		_restart_game()
	)

func _process(_delta: float) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		if Input.is_action_just_pressed("ui_accept"):
			_restart_game()

func _on_player_weapon_fired(type: String, pos: Vector2, dir: Vector2) -> void:
	match type:
		"machine_gun":
			var bullet = ObjectPool.get("bullet")
			world.add_child(bullet)
			bullet.init(pos, dir, true)
			AudioManager.play_synth_laser(pos)
		"missile":
			var bullet = ObjectPool.get("bullet")
			world.add_child(bullet)
			bullet.init(pos, dir, true)
			bullet.homing_strength = 6.0
			bullet.damage = 3
			bullet.scale = Vector2(1.8, 1.8)
			bullet.modulate = Color(1.0, 0.25, 0.25)
			hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
			AudioManager.play_synth_laser(pos)
		"mine":
			var mine = ObjectPool.get("mine")
			world.add_child(mine)
			mine.init(pos)
			hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
			AudioManager.play_synth_explosion(pos)
		"emp":
			var emp = ObjectPool.get("emp")
			world.add_child(emp)
			emp.init(pos)
			hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
			AudioManager.play_synth_emp(pos)
