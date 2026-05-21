extends GutTest

var Enemy

class SignalCapture:
	var pos = Vector2.ZERO
	var type = ""
	var count = 0
	func capture(p, t):
		pos = p
		type = t
		count += 1

func before_all():
	Enemy = load("res://scenes/enemies/Enemy.gd")

func test_enemy_type_enum():
	assert_eq(Enemy.EnemyType.ROTOR, 0, "ROTOR = 0")
	assert_eq(Enemy.EnemyType.SCAV, 1, "SCAV = 1")
	assert_eq(Enemy.EnemyType.DRONE, 2, "DRONE = 2")

func test_type_names_constant():
	assert_eq(Enemy.TYPE_NAMES.size(), 3, "Should have 3 type names")
	assert_eq(Enemy.TYPE_NAMES[0], "rotor", "Type name 0 should be rotor")
	assert_eq(Enemy.TYPE_NAMES[1], "scav", "Type name 1 should be scav")
	assert_eq(Enemy.TYPE_NAMES[2], "drone", "Type name 2 should be drone")

func test_init_rotor():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	assert_eq(e.hp, 1, "Rotor HP")
	assert_eq(e.speed, 200.0 * 0.9, "Rotor speed")
	assert_eq(e.score_value, 50, "Rotor score")
	assert_eq(e.player, player, "Player reference should be set")

func test_init_scav():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 1, player, 200.0)
	assert_eq(e.hp, 3, "Scav HP")
	assert_eq(e.speed, 200.0 * 0.7, "Scav speed")
	assert_eq(e.score_value, 100, "Scav score")
	assert_eq(e.player, player, "Player reference should be set")

func test_init_drone():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.DRONE, 2, player, 200.0)
	assert_eq(e.hp, 2, "Drone HP")
	assert_eq(e.speed, 200.0 * 0.5, "Drone speed")
	assert_eq(e.score_value, 200, "Drone score")
	assert_eq(e.player, player, "Player reference should be set")

func test_init_uses_base_speed_not_player_speed():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	assert_eq(e.speed, 180.0, "Speed should be based on base_speed, not player.current_speed")

func test_take_damage_reduces_hp():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 0, player, 200.0)
	e.take_damage(1)
	assert_eq(e.hp, 2, "HP should decrease by 1")

func test_take_damage_kills_at_zero():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	watch_signals(e)
	e.take_damage(1)
	assert_signal_emitted(e, "destroyed", "Destroyed signal should emit")

func test_take_damage_does_not_kill_above_zero():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 0, player, 200.0)
	var destroy_count = 0
	e.destroyed.connect(func(_pos, _type): destroy_count += 1)
	e.take_damage(1)
	assert_eq(destroy_count, 0, "Should not emit destroyed with remaining HP")

func test_die_emits_correct_enemy_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.DRONE, 0, player, 200.0)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(2)
	assert_eq(capture.type, "drone", "Should emit lowercase enemy type")
	assert_eq(capture.count, 1, "Signal should be emitted once")

func test_die_rotor_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(1)
	assert_eq(capture.type, "rotor", "Should emit 'rotor'")

func test_die_scav_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 0, player, 200.0)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(3)
	assert_eq(capture.type, "scav", "Should emit 'scav'")

func test_destroyed_signal_emits_position():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.global_position = Vector2(100, 200)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(1)
	assert_eq(capture.pos, Vector2(100, 200), "Should emit global position")

func test_take_damage_overkill():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	watch_signals(e)
	e.take_damage(100)
	assert_signal_emitted(e, "destroyed", "Should die from overkill damage")

func _create_enemy():
	var scene = load("res://scenes/enemies/Rotor.tscn")
	var e = scene.instantiate()
	add_child_autofree(e)
	return e
