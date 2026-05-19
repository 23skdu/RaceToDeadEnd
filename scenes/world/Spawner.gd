extends Node

signal wave_spawned(wave_number: int)

const SPAWN_OFFSET_Y: float = -100.0
const DESPAWN_Y: float = 800.0

var player: Node = null
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
	wave_timer -= delta
	if wave_timer <= 0.0:
		_spawn_wave()
		wave_timer = wave_interval
	for e in active_enemies:
		if is_instance_valid(e) and e.global_position.y > DESPAWN_Y:
			e.queue_free()

func _spawn_wave() -> void:
	current_wave += 1
	var tier = GameManager.difficulty_tier
	var composition = _get_wave_composition(tier)
	for enemy_type in composition:
		for _i in composition[enemy_type]:
			_spawn_enemy(enemy_type)
	wave_spawned.emit(current_wave)

func _get_wave_composition(tier: int) -> Dictionary:
	var comp = {
		"rotor": clampi(1 + tier / 3, 1, 8),
		"scav": clampi(tier / 4, 0, 4),
		"drone": clampi(tier / 6, 0, 3),
	}
	return comp

func _spawn_enemy(type: String) -> void:
	if not enemy_scenes.has(type) or not enemy_scenes[type]:
		return
	var scene = enemy_scenes[type]
	var enemy = scene.instantiate()
	var lane = randi() % 4
	var lane_x = (lane - 1.5) * 64.0
	enemy.global_position = Vector2(lane_x, SPAWN_OFFSET_Y)
	if enemy.has_method("init"):
		enemy.init(enemy.EnemyType.ROTOR, lane, 200.0)
	enemy.destroyed.connect(_on_enemy_destroyed)
	add_child(enemy)
	active_enemies.append(enemy)

func _on_enemy_destroyed(position: Vector2, enemy_type: String) -> void:
	ScoreManager.register_kill(enemy_type, position)
	_drop_pickup(position)

func _drop_pickup(position: Vector2) -> void:
	var roll = randf()
	if roll < 0.15:
		pass
