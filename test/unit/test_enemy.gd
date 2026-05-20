extends GutTest

var Enemy

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
	var destroyed_emitted = false
	e.destroyed.connect(func(_pos, _type): destroyed_emitted = true)
	e.take_damage(1)
	assert_true(destroyed_emitted, "Destroyed signal should emit")

func test_take_damage_does_not_kill_above_zero():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 0, player, 200.0)
	var destroyed_emitted = false
	e.destroyed.connect(func(_pos, _type): destroyed_emitted = true)
	e.take_damage(1)
	assert_false(destroyed_emitted, "Should not emit destroyed with remaining HP")

func test_die_emits_correct_enemy_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.DRONE, 0, player, 200.0)
	var emitted_type = ""
	e.destroyed.connect(func(_pos, type): emitted_type = type)
	e.take_damage(2)
	assert_eq(emitted_type, "drone", "Should emit lowercase enemy type")

func test_die_rotor_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	var emitted_type = ""
	e.destroyed.connect(func(_pos, type): emitted_type = type)
	e.take_damage(1)
	assert_eq(emitted_type, "rotor", "Should emit 'rotor'")

func test_die_scav_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 0, player, 200.0)
	var emitted_type = ""
	e.destroyed.connect(func(_pos, type): emitted_type = type)
	e.take_damage(3)
	assert_eq(emitted_type, "scav", "Should emit 'scav'")

func test_hit_flash_changes_color():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e._play_hit_flash()
	assert_eq(e.sprite.modulate, Color.RED, "Sprite should flash red")

func test_hit_flash_timer_starts():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e._play_hit_flash()
	assert_true(e.hit_flash_timer.time_left > 0.0, "Hit flash timer should be running")

func test_enemy_added_to_group():
	var e = _create_enemy()
	e._ready()
	assert_true(e.is_in_group("enemy"), "Enemy should be in 'enemy' group")

func test_collision_layer_set():
	var e = _create_enemy()
	e._ready()
	assert_eq(e.collision_layer, 2, "Enemy collision layer should be 2")

func test_no_screen_exited_handler():
	var e = _create_enemy()
	assert_false(e.has_method("_on_visible_on_screen_notifier_screen_exited"), "Should not have dead screen-exited handler")

func test_update_sprite_loads_texture():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e._update_sprite()
	assert_true(e.sprite.texture != null, "Sprite should have texture loaded")

func test_hit_flash_timer_timeout_resets_color():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e._play_hit_flash()
	e._on_hit_flash_timer_timeout()
	assert_eq(e.sprite.modulate, Color.WHITE, "Sprite color should reset to white")

func test_stunned_physics_process_clears_stun():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.apply_stun(0.1)
	e._physics_process(0.2)
	assert_false(e.stunned, "Stun should clear after timer expires")

func test_enemy_stun_applies():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.apply_stun(2.0)
	assert_true(e.stunned, "Enemy should be stunned")
	assert_eq(e.stun_timer, 2.0, "Stun timer should be 2 seconds")

func test_enemy_stun_visual():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.apply_stun(1.0)
	assert_eq(e.sprite.modulate, Color(0.5, 0.5, 1.0, 0.7), "Stunned enemy should have blue tint")

func test_enemy_stun_expires():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.apply_stun(0.5)
	e._physics_process(0.6)
	assert_false(e.stunned, "Stun should expire after timer")

func test_enemy_stun_clears_visual():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.apply_stun(0.5)
	e._physics_process(0.6)
	assert_eq(e.sprite.modulate, Color.WHITE, "Visual should reset after stun expires")

func test_destroyed_signal_emits_position():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.global_position = Vector2(100, 200)
	var emitted_pos = Vector2.ZERO
	e.destroyed.connect(func(pos, _type): emitted_pos = pos)
	e.take_damage(1)
	assert_eq(emitted_pos, Vector2(100, 200), "Should emit global position")

func test_take_damage_overkill():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	var destroyed_emitted = false
	e.destroyed.connect(func(_pos, _type): destroyed_emitted = true)
	e.take_damage(100)
	assert_true(destroyed_emitted, "Should die from overkill damage")

func _create_enemy():
	var scene = load("res://scenes/enemies/Rotor.tscn")
	var e = scene.instantiate()
	add_child_autofree(e)
	return e
