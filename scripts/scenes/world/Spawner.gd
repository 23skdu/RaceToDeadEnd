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
		comp["rotor"] = 1
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
	var pickup = ObjectPool.acquire_pickup(pickup_type, position, _on_pickup_collected)
	if get_parent():
		get_parent().add_child(pickup)

func _on_pickup_collected(pickup_type: String, _pickup: Area2D) -> void:
	ScoreManager.register_pickup(pickup_type, _pickup.global_position)
