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
signal boss_defeated(boss_type: String)
signal spawn_minion_requested(enemy_type: String, count: int)

var player: Node = null
var world_node: Node = null
var enemy_scenes: Dictionary = {}
var wave_timer: float = 0.0
var wave_interval: float = 5.0
var current_wave: int = 0

var _bosses_spawned: int = 0
var _cleanup_timer: float = 0.0
var _civilian_spawn_accumulator: float = 0.0

func _ready() -> void:
	enemy_scenes["bunny"] = preload("res://scenes/enemies/Bunny.tscn") if ResourceLoader.exists("res://scenes/enemies/Bunny.tscn") else null
	enemy_scenes["rotor"] = preload("res://scenes/enemies/Rotor.tscn") if ResourceLoader.exists("res://scenes/enemies/Rotor.tscn") else null
	enemy_scenes["scav"] = preload("res://scenes/enemies/Scav.tscn") if ResourceLoader.exists("res://scenes/enemies/Scav.tscn") else null
	enemy_scenes["sasquatch"] = preload("res://scenes/enemies/BossSasquatch.tscn") if ResourceLoader.exists("res://scenes/enemies/BossSasquatch.tscn") else null
	enemy_scenes["drone"] = preload("res://scenes/enemies/Drone.tscn") if ResourceLoader.exists("res://scenes/enemies/Drone.tscn") else null
	enemy_scenes["civilian"] = preload("res://scenes/enemies/Civilian.tscn") if ResourceLoader.exists("res://scenes/enemies/Civilian.tscn") else null
	enemy_scenes["boss"] = preload("res://scenes/enemies/BossWarRig.tscn") if ResourceLoader.exists("res://scenes/enemies/BossWarRig.tscn") else null
	enemy_scenes["boss_bunny"] = preload("res://scenes/enemies/BossBunny.tscn") if ResourceLoader.exists("res://scenes/enemies/BossBunny.tscn") else null
	enemy_scenes["boss_giant_biker"] = preload("res://scenes/enemies/BossGiantBiker.tscn") if ResourceLoader.exists("res://scenes/enemies/BossGiantBiker.tscn") else null
	enemy_scenes["boss_void_drone"] = preload("res://scenes/enemies/BossVoidDrone.tscn") if ResourceLoader.exists("res://scenes/enemies/BossVoidDrone.tscn") else null
	if not GameManager.game_started.is_connected(_on_game_started):
		GameManager.game_started.connect(_on_game_started)
	if not spawn_minion_requested.is_connected(_on_spawn_minion_requested):
		spawn_minion_requested.connect(_on_spawn_minion_requested)

func _on_game_started() -> void:
	wave_timer = wave_interval
	current_wave = 0
	_bosses_spawned = 0

func _on_spawn_minion_requested(enemy_type: String, count: int) -> void:
	for _i in count:
		_spawn_enemy(enemy_type)

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

	_civilian_spawn_accumulator += delta
	if _civilian_spawn_accumulator >= 1.0 / civilian_chance:
		_civilian_spawn_accumulator = 0.0
		_spawn_civilian()
	
	_cleanup_timer -= delta
	if _cleanup_timer > 0.0:
		return
	_cleanup_timer = 0.25
	
	var player_y = player.global_position.y
	var i = GameManager.enemy_list.size() - 1
	while i >= 0:
		var e = GameManager.enemy_list[i]
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			GameManager.enemy_list.remove_at(i)
		elif e.global_position.y - player_y > Constants.CLEANUP_DISTANCE \
				or player_y - e.global_position.y > Constants.CLEANUP_DISTANCE:
			GameManager.enemy_list.remove_at(i)
			if e.has_signal("destroyed") and e.destroyed.is_connected(_on_enemy_destroyed):
				e.destroyed.disconnect(_on_enemy_destroyed)
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
	var boss_key = "boss_bunny"
	if _bosses_spawned == 1:
		boss_key = "boss_giant_biker"
	elif _bosses_spawned == 2:
		boss_key = "boss"
	elif _bosses_spawned >= 3:
		boss_key = "boss_void_drone"
		
	_bosses_spawned += 1
	if not player:
		return
	var boss = ObjectPool.acquire(boss_key)
	if not boss:
		if enemy_scenes.has(boss_key) and enemy_scenes[boss_key]:
			boss = enemy_scenes[boss_key].instantiate()
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
	var can_bunny = GameManager.bosses_killed < 1
	var can_rotor = GameManager.bosses_killed >= 1
	var can_sasquatch = GameManager.bosses_killed >= 2
	var can_scav = GameManager.bosses_killed >= 2
	var can_drone = GameManager.bosses_killed >= 3
	if tier == 1:
		if can_bunny:
			comp["bunny"] = 1
		elif can_rotor:
			comp["rotor"] = 1
	elif tier == 2:
		if can_bunny:
			comp["bunny"] = 2
		elif can_rotor:
			comp["rotor"] = 2
		if can_sasquatch:
			comp["sasquatch"] = 1
		if can_scav:
			comp["scav"] = 1
	elif tier == 3:
		if can_bunny:
			comp["bunny"] = 1
		elif can_rotor:
			comp["rotor"] = 1
		if can_sasquatch:
			comp["sasquatch"] = 1
		if can_scav:
			comp["scav"] = 1
		if can_drone:
			comp["drone"] = 1
	else:
		if can_bunny:
			comp["bunny"] = clampi(1 + floori(tier / 3.0), 1, 6)
		elif can_rotor:
			comp["rotor"] = clampi(1 + floori(tier / 3.0), 1, 6)
		if can_sasquatch:
			comp["sasquatch"] = clampi(floori(tier / 5.0), 1, 2)
		if can_scav:
			comp["scav"] = clampi(floori(tier / 4.0), 1, 3)
		if can_drone:
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
	if type == "bunny":
		et = enemy.EnemyType.BUNNY
	elif type == "sasquatch":
		et = enemy.EnemyType.SASQUATCH
	elif type == "scav":
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
	if enemy_type in ["boss_bunny", "boss_giant_biker", "boss_void_drone", "boss"]:
		boss_defeated.emit(enemy_type)

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
