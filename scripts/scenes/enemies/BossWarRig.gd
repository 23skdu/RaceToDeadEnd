extends "res://scripts/scenes/enemies/Enemy.gd"

var attack_timer: float = 0.0
var minion_spawned: bool = false
var phase: int = 1

func _ready() -> void:
	super._ready()
	_reset_state()

func _reset_state() -> void:
	hp = Constants.BOSS_WAR_RIG_HP
	score_value = Constants.BOSS_SCORE
	speed = 80.0
	attack_timer = 0.0
	minion_spawned = false
	phase = 1

func on_pool_acquire() -> void:
	_reset_state()

func on_pool_release() -> void:
	_reset_state()
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		return
	attack_timer += delta
	if attack_timer >= Constants.BOSS_ATTACK_INTERVAL:
		attack_timer = 0.0
		_execute_attack()

func _execute_attack() -> void:
	if hp <= Constants.BOSS_WAR_RIG_HP * 0.3 and not minion_spawned:
		minion_spawned = true
		_spawn_minions()
		return
	_ram_player()

func _ram_player() -> void:
	velocity.x = move_toward(velocity.x, 200.0 * (1 if player and player.global_position.x > global_position.x else -1), 500.0 * get_process_delta_time())
	CameraShake.shake(0.4, 0.2, 6.0)
	CameraShake.rumble(0.5, 0.2)

func _spawn_minions() -> void:
	if _spawner and _spawner.has_signal("spawn_minion_requested"):
		_spawner.spawn_minion_requested.emit("scav", 2)
