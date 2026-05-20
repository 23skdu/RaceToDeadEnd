extends Node

signal wave_spawned(wave_number: int)

var player: Node = null
var world_node: Node = null
var enemy_scenes: Dictionary = {}
var active_enemies: Array[Node] = []
var wave_timer: float = 0.0
var wave_interval: float = 5.0
var current_wave: int = 0

func _ready() -> void:
	enemy_scenes["rotor"] = preload("res://scenes/enemies/Rotor.tscn") if ResourceLoader.exists("res://scenes/enemies/Rotor.tscn") else null
	enemy_scenes["scav"] = preload("res://scenes/enemies/Scav.tscn") if ResourceLoader.exists("res://scenes/enemies/Scav.tscn") else null
	enemy_scenes["drone"] = preload("res://scenes/enemies/Drone.tscn") if ResourceLoader.exists("res://scenes/enemies/Drone.tscn") else null

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
		
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return
			
	wave_timer -= delta
	if wave_timer <= 0.0:
		_spawn_wave()
		wave_interval = maxf(2.0, 5.0 - (GameManager.difficulty_tier - 1) * 0.3)
		wave_timer = wave_interval
		
	var player_y = player.global_position.y
	var i = active_enemies.size() - 1
	while i >= 0:
		var e = active_enemies[i]
		if not is_instance_valid(e):
			active_enemies.remove_at(i)
		elif e.global_position.y - player_y > Constants.CLEANUP_DISTANCE:
			active_enemies.remove_at(i)
			e.queue_free()
		i -= 1

func _spawn_wave() -> void:
	current_wave += 1
	var tier = GameManager.difficulty_tier
	var composition = _get_wave_composition(tier)
	for enemy_type in composition:
		for _i in composition[enemy_type]:
			_spawn_enemy(enemy_type)
	wave_spawned.emit(current_wave)

func _get_wave_composition(tier: int) -> Dictionary:
	var comp = {}
	if tier == 1:
		comp["rotor"] = 2
	elif tier == 2:
		comp["rotor"] = 2
		comp["scav"] = 1
	elif tier == 3:
		comp["rotor"] = 1
		comp["scav"] = 1
		comp["drone"] = 1
	else:
		comp["rotor"] = clampi(1 + floori(tier / 3.0), 1, 6)
		comp["scav"] = clampi(floori(tier / 4.0), 1, 3)
		comp["drone"] = clampi(floori(tier / 6.0), 1, 2)
	return comp

func _spawn_enemy(type: String) -> void:
	if not enemy_scenes.has(type) or not enemy_scenes[type]:
		return
	if not player:
		return
		
	var scene = enemy_scenes[type]
	var enemy = scene.instantiate()
	var lane = randi_range(0, Constants.LANE_COUNT - 1)
	var lane_x = Constants.LANE_POSITIONS[lane]
	
	enemy.global_position = Vector2(lane_x, player.global_position.y - Constants.SPAWN_DISTANCE)
	
	var et = enemy.EnemyType.ROTOR
	if type == "scav":
		et = enemy.EnemyType.SCAV
	elif type == "drone":
		et = enemy.EnemyType.DRONE
		
	if enemy.has_method("init"):
		enemy.init(et, lane, player, Constants.BASE_SPEED)
		
	if type == "scav" and "world_node" in enemy:
		enemy.world_node = world_node
	if type == "drone" and "world_node" in enemy:
		enemy.world_node = world_node
		
	enemy.destroyed.connect(_on_enemy_destroyed)
	add_child(enemy)
	active_enemies.append(enemy)

func _on_enemy_destroyed(position: Vector2, enemy_type: String) -> void:
	ScoreManager.register_kill(enemy_type, position)
	_drop_pickup(position)
	AudioManager.play_synth_explosion(position)

func _drop_pickup(position: Vector2) -> void:
	var roll = randf()
	if roll < 0.15:
		var pickup_type = _pick_pickup_type()
		_spawn_pickup(position, pickup_type)

func _pick_pickup_type() -> String:
	var r = randf()
	if r < 0.35:
		return "repair"
	elif r < 0.60:
		return "ammo"
	elif r < 0.80:
		return "boost"
	else:
		return "multiplier"

func _spawn_pickup(position: Vector2, pickup_type: String) -> void:
	var pickup = Area2D.new()
	pickup.collision_layer = 0
	pickup.collision_mask = 1
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	col.shape = circle
	pickup.add_child(col)
	
	var visual = Polygon2D.new()
	var pts = []
	var segments = 8
	for i in segments:
		var angle = i * TAU / segments
		pts.append(Vector2(cos(angle) * 16.0, sin(angle) * 16.0))
	visual.polygon = PackedVector2Array(pts)
	match pickup_type:
		"repair":
			visual.color = Color(0.2, 1.0, 0.3)
		"ammo":
			visual.color = Color(1.0, 0.8, 0.2)
		"boost":
			visual.color = Color(0.2, 0.8, 1.0)
		"multiplier":
			visual.color = Color(1.0, 0.3, 1.0)
	pickup.add_child(visual)
	
	pickup.global_position = position
	pickup.body_entered.connect(_on_pickup_collected.bind(pickup_type, pickup))
	add_child(pickup)

func _on_pickup_collected(body: Node, pickup_type: String, pickup: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	ScoreManager.register_pickup(pickup_type, pickup.global_position)
	pickup.queue_free()
