extends Node

@export_group("Waves")
@export var base_wave_interval: float = Constants.BASE_WAVE_INTERVAL
@export var min_wave_interval: float = Constants.MIN_WAVE_INTERVAL
@export var wave_interval_decay: float = Constants.WAVE_INTERVAL_DECAY

@export_group("Spawning")
@export var spawn_distance: float = Constants.SPAWN_DISTANCE
@export var cleanup_distance: float = Constants.CLEANUP_DISTANCE
@export var civilian_chance: float = Constants.CIVILIAN_SPAWN_CHANCE

signal wave_spawned(wave_number: int)
signal enemy_spawned(enemy: Node)
signal enemy_destroyed(enemy: Node)
signal boss_spawned(boss: Node)
signal spawn_minion_requested(enemy_type: String, count: int)

var player: Node = null
var world_node: Node = null
var enemy_scenes: Dictionary = {}
var wave_timer: float = 0.0
var wave_interval: float = 5.0
var current_wave: int = 0

var _bosses_spawned: int = 0

func _ready() -> void:
	enemy_scenes["rotor"] = preload("res://scenes/enemies/Rotor.tscn") if ResourceLoader.exists("res://scenes/enemies/Rotor.tscn") else null
	enemy_scenes["scav"] = preload("res://scenes/enemies/Scav.tscn") if ResourceLoader.exists("res://scenes/enemies/Scav.tscn") else null
	enemy_scenes["drone"] = preload("res://scenes/enemies/Drone.tscn") if ResourceLoader.exists("res://scenes/enemies/Drone.tscn") else null
	enemy_scenes["civilian"] = preload("res://scenes/enemies/Civilian.tscn") if ResourceLoader.exists("res://scenes/enemies/Civilian.tscn") else null
	enemy_scenes["boss"] = preload("res://scenes/enemies/BossWarRig.tscn") if ResourceLoader.exists("res://scenes/enemies/BossWarRig.tscn") else null

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
		
	if not player or not is_instance_valid(player):
		return
			
	wave_timer -= delta
	if wave_timer <= 0.0:
		_spawn_wave()
		wave_interval = maxf(min_wave_interval, base_wave_interval - (GameManager.difficulty_tier - 1) * wave_interval_decay)
		wave_timer = wave_interval

	if randf() < Constants.CIVILIAN_SPAWN_CHANCE * delta:
		_spawn_civilian()
		
	var player_y = player.global_position.y
	var i = GameManager.enemy_list.size() - 1
	while i >= 0:
		var e = GameManager.enemy_list[i]
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			GameManager.enemy_list.remove_at(i)
		elif e.global_position.y - player_y > Constants.CLEANUP_DISTANCE:
			GameManager.enemy_list.remove_at(i)
			if e.has_method("on_pool_release"):
				ObjectPool.release(e)
			else:
				e.queue_free()
		i -= 1

func _spawn_wave() -> void:
	current_wave += 1
	var tier = GameManager.difficulty_tier
	if _should_spawn_boss():
		_spawn_boss()
		return
	var composition = _get_wave_composition(tier)
	for enemy_type in composition:
		for _i in composition[enemy_type]:
			_spawn_enemy(enemy_type)
	wave_spawned.emit(current_wave)

func _should_spawn_boss() -> bool:
	var next_threshold = (_bosses_spawned + 1) * Constants.BOSS_SCORE_INTERVAL
	return GameManager.score >= next_threshold and enemy_scenes.has("boss") and enemy_scenes["boss"]

func _spawn_boss() -> void:
	_bosses_spawned += 1
	if not player:
		return
	var boss = ObjectPool.acquire("boss")
	if not boss:
		if enemy_scenes.has("boss") and enemy_scenes["boss"]:
			boss = enemy_scenes["boss"].instantiate()
		else:
			return
	var lane = randi_range(2, 3)
	var lane_x = Constants.LANE_POSITIONS[lane]
	boss.global_position = Vector2(lane_x, player.global_position.y - Constants.SPAWN_DISTANCE)
	boss.player = player
	boss._spawner = self
	boss.destroyed.connect(_on_enemy_destroyed)
	add_child(boss)
	boss_spawned.emit(boss)
	enemy_spawned.emit(boss)

func _spawn_civilian() -> void:
	if not player or not is_instance_valid(player):
		return
	if not enemy_scenes.has("civilian") or not enemy_scenes["civilian"]:
		return
	var civilian = ObjectPool.acquire("civilian")
	if not civilian:
		if enemy_scenes.has("civilian") and enemy_scenes["civilian"]:
			civilian = enemy_scenes["civilian"].instantiate()
		else:
			return
	var lane = randi_range(0, Constants.LANE_COUNT - 1)
	var dir = 1.0 if randi() % 2 == 0 else -1.0
	civilian.init(lane, GameManager.current_speed, dir, player)
	civilian.global_position = Vector2(Constants.LANE_POSITIONS[lane], player.global_position.y - Constants.SPAWN_DISTANCE * 0.5)
	civilian.exited_safely.connect(_on_civilian_safe_exit.bind(civilian), CONNECT_ONE_SHOT)
	civilian.hit_by_player.connect(_on_civilian_hit.bind(civilian), CONNECT_ONE_SHOT)
	add_child(civilian)
	GameManager.register_enemy_spawned(civilian)

func _on_civilian_safe_exit(civilian: Node) -> void:
	ScoreManager.register_civilian_protected(civilian.global_position)
	GameManager.register_enemy_destroyed(civilian)
	if civilian.has_method("on_pool_release"):
		ObjectPool.release(civilian)

func _on_civilian_hit(civilian: Node) -> void:
	ScoreManager.register_civilian_damaged()
	GameManager.register_enemy_destroyed(civilian)
	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(Constants.CIVILIAN_PENALTY)
	if civilian.has_method("on_pool_release"):
		ObjectPool.release(civilian)

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
		
	var enemy = ObjectPool.acquire(type)
	if not enemy:
		if enemy_scenes.has(type) and enemy_scenes[type]:
			enemy = enemy_scenes[type].instantiate()
		else:
			return
	var lane = randi_range(0, Constants.LANE_COUNT - 1)
	var lane_x = Constants.LANE_POSITIONS[lane]
	
	enemy.global_position = Vector2(lane_x, player.global_position.y - Constants.SPAWN_DISTANCE)
	
	var et = enemy.EnemyType.ROTOR
	if type == "scav":
		et = enemy.EnemyType.SCAV
	elif type == "drone":
		et = enemy.EnemyType.DRONE
		
	enemy.destroyed.connect(_on_enemy_destroyed)
	add_child(enemy)
	enemy_spawned.emit(enemy)

	if enemy.has_method("init"):
		enemy.init(et, lane, player, GameManager.current_speed, self)
		
	if type == "scav" and "world_node" in enemy:
		enemy.world_node = world_node
	if type == "drone" and "world_node" in enemy:
		enemy.world_node = world_node

func _on_enemy_destroyed(pos: Vector2, enemy_type: String, enemy: Node) -> void:
	ScoreManager.register_kill(enemy_type, pos)
	_drop_pickup(pos)
	enemy_destroyed.emit(enemy)

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
