extends "res://scripts/scenes/enemies/Enemy.gd"

var attack_timer: float = 0.0
var minion_spawned: bool = false
var phase: int = 1
var _phase_2_done: bool = false

signal boss_phase_changed(p: int)

func _ready() -> void:
	super._ready()
	_reset_state()

func _reset_state() -> void:
	hp = Constants.BOSS_WAR_RIG_HP
	score_value = Constants.BOSS_SCORE
	speed = 80.0
	attack_timer = 0.0
	minion_spawned = false
	_phase_2_done = false
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
	_check_phase()
	attack_timer += delta
	if attack_timer >= Constants.BOSS_ATTACK_INTERVAL:
		attack_timer = 0.0
		_execute_attack()

func _check_phase() -> void:
	var max_hp = Constants.BOSS_WAR_RIG_HP
	var new_phase = 1
	if hp <= max_hp * 0.3:
		new_phase = 3
	elif hp <= max_hp * 0.6:
		new_phase = 2
	if new_phase != phase:
		phase = new_phase
		if phase == 2:
			speed = 80.0 * 1.2
		elif phase == 3:
			speed = 80.0 * 1.4
		_update_phase_visuals()
		boss_phase_changed.emit(phase)

func _update_phase_visuals() -> void:
	match phase:
		2:
			sprite.modulate = Color(1.0, 0.9, 0.3, 1.0)
		3:
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
		_:
			sprite.modulate = Color.WHITE

func _execute_attack() -> void:
	if hp <= Constants.BOSS_WAR_RIG_HP * 0.3 and not minion_spawned:
		minion_spawned = true
		_spawn_minions()
		return
	if phase >= 2:
		var spread_roll = randf()
		if spread_roll < 0.4:
			_fire_bullet_spread()
			return
	_ram_player()

func _ram_player() -> void:
	velocity.x = move_toward(velocity.x, 200.0 * (1 if player and player.global_position.x > global_position.x else -1), 500.0 * get_process_delta_time())
	CameraShake.shake(0.4, 0.2, 6.0)
	CameraShake.rumble(0.5, 0.2)

func _fire_bullet_spread() -> void:
	if not _spawner or not _spawner.has_signal("spawn_minion_requested"):
		return
	const BULLET_SCENE = preload("res://scenes/weapons/Bullet.tscn")
	for angle_offset in [-15.0, 0.0, 15.0]:
		var bullet = ObjectPool.acquire("bullet")
		if not bullet:
			bullet = BULLET_SCENE.instantiate()
		var parent = get_parent()
		if parent:
			parent.add_child(bullet)
		bullet.global_position = global_position + Vector2(0, 48)
		var dir = Vector2.DOWN.rotated(deg_to_rad(angle_offset))
		bullet.init(bullet.global_position, dir, false)
		AudioManager.play_synth_laser(global_position)

func _spawn_minions() -> void:
	if _spawner and _spawner.has_signal("spawn_minion_requested"):
		_spawner.spawn_minion_requested.emit("scav", 2)
