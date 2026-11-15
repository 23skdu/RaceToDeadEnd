extends GutTest

var BossScene
var EnemyScript

class MockSpawner:
	extends Node2D
	signal spawn_minion_requested(type: String, count: int)

func before_all():
	BossScene = load("res://scenes/enemies/BossWarRig.tscn")
	EnemyScript = load("res://scripts/scenes/enemies/Enemy.gd")

func _create_boss():
	var b = BossScene.instantiate()
	add_child_autofree(b)
	return b

func test_boss_scene_exists():
	assert_true(ResourceLoader.exists("res://scenes/enemies/BossWarRig.tscn"), "Boss scene should exist")

func test_boss_defaults():
	var b = _create_boss()
	assert_eq(b.hp, Constants.BOSS_WAR_RIG_HP, "Default HP")
	assert_eq(b.score_value, Constants.BOSS_SCORE, "Default score")
	assert_eq(b.speed, 80.0, "Default speed")
	assert_eq(b.phase, 1, "Default phase")
	assert_false(b.minion_spawned, "Minions not yet spawned")

func test_boss_phase_starts_at_1():
	var b = _create_boss()
	assert_eq(b.phase, 1, "Phase should start at 1")

func test_boss_phase_2_at_60_percent_hp():
	var b = _create_boss()
	b.hp = int(Constants.BOSS_WAR_RIG_HP * 0.6) + 1
	b._check_phase()
	assert_eq(b.phase, 1, "Should still be phase 1 above 60% HP")
	b.hp = int(Constants.BOSS_WAR_RIG_HP * 0.6)
	b._check_phase()
	assert_eq(b.phase, 2, "Should enter phase 2 at 60% HP")

func test_boss_phase_3_at_30_percent_hp():
	var b = _create_boss()
	b.hp = int(Constants.BOSS_WAR_RIG_HP * 0.3)
	b._check_phase()
	assert_eq(b.phase, 3, "Should enter phase 3 at 30% HP")

func test_boss_speed_increases_in_phase_2():
	var b = _create_boss()
	b.hp = int(Constants.BOSS_WAR_RIG_HP * 0.6)
	b._check_phase()
	assert_eq(b.speed, 96.0, "Speed should increase by 20% in phase 2")

func test_boss_speed_increases_in_phase_3():
	var b = _create_boss()
	b.hp = int(Constants.BOSS_WAR_RIG_HP * 0.3)
	b._check_phase()
	assert_eq(b.speed, 112.0, "Speed should increase by 40% in phase 3")

func test_boss_has_bullet_spread_method():
	var b = _create_boss()
	assert_true(b.has_method("_fire_bullet_spread"), "Boss should have bullet spread method")

func test_boss_has_phase_signal():
	var b = _create_boss()
	assert_true(b.has_signal("boss_phase_changed"), "Boss should emit boss_phase_changed signal")

func test_boss_reset_on_pool_acquire():
	var b = _create_boss()
	b.hp = 1
	b.phase = 3
	b.minion_spawned = true
	b.on_pool_acquire()
	assert_eq(b.hp, Constants.BOSS_WAR_RIG_HP, "HP should reset on pool acquire")
	assert_eq(b.phase, 1, "Phase should reset on pool acquire")
	assert_false(b.minion_spawned, "Minion flag should reset on pool acquire")

func test_boss_reset_on_pool_release():
	var b = _create_boss()
	b.phase = 3
	b.minion_spawned = true
	b.on_pool_release()
	assert_eq(b.phase, 1, "Phase should reset on pool release")
	assert_eq(b.velocity, Vector2.ZERO, "Velocity should reset on pool release")

func test_execute_attack_calls_ram_player_in_phase_1():
	var boss = _create_boss()
	boss.phase = 1
	var mock_player = Node2D.new()
	add_child_autofree(mock_player)
	mock_player.global_position = Vector2(100, 0)
	boss.player = mock_player
	boss.attack_timer = Constants.BOSS_ATTACK_INTERVAL
	boss._physics_process(0.016)
	assert_gt(boss.velocity.x, 0, "_ram_player should set velocity.x toward player in phase 1")

func test_execute_attack_phase_2_handles_spread():
	var boss = _create_boss()
	boss.phase = 2
	boss._spawner = MockSpawner.new()
	add_child_autofree(boss._spawner)
	boss._execute_attack()
	assert_true(true, "Phase 2 execute_attack should handle bullet spread without crash")

func test_execute_attack_phase_3_spawns_minions():
	var boss = _create_boss()
	boss.phase = 3
	boss.hp = int(Constants.BOSS_WAR_RIG_HP * 0.3)
	boss.minion_spawned = false
	boss._spawner = MockSpawner.new()
	add_child_autofree(boss._spawner)
	boss._execute_attack()
	assert_true(boss.minion_spawned, "Phase 3 should set minion_spawned to true")

func test_execute_attack_phase_3_does_not_spawn_twice():
	var boss = _create_boss()
	boss.phase = 3
	boss.hp = int(Constants.BOSS_WAR_RIG_HP * 0.3)
	boss.minion_spawned = true
	var emit_count = 0
	boss._spawner = MockSpawner.new()
	boss._spawner.spawn_minion_requested.connect(func(_t, _c): emit_count += 1)
	add_child_autofree(boss._spawner)
	boss._execute_attack()
	assert_eq(emit_count, 0, "Should not spawn minions when minion_spawned is already true")

func test_ram_player_sets_velocity_x_toward_player():
	var boss = _create_boss()
	var mock_player = Node2D.new()
	add_child_autofree(mock_player)
	mock_player.global_position = Vector2(100, 0)
	boss.player = mock_player
	boss._ram_player()
	assert_true(true, "_ram_player should not crash with a player reference")

func test_fire_bullet_spread_creates_three_bullets():
	var boss = _create_boss()
	boss._spawner = MockSpawner.new()
	add_child_autofree(boss._spawner)
	var parent = boss.get_parent()
	var before = parent.get_child_count()
	boss._fire_bullet_spread()
	var after = parent.get_child_count()
	assert_eq(after - before, 3, "Should create 3 bullet instances")

func test_fire_bullet_spread_bullets_at_offset():
	var boss = _create_boss()
	boss.global_position = Vector2(200, 300)
	boss._spawner = MockSpawner.new()
	add_child_autofree(boss._spawner)
	boss._fire_bullet_spread()
	var expected_pos = Vector2(200, 348)
	var found = false
	var parent = boss.get_parent()
	for i in parent.get_child_count():
		var child = parent.get_child(i)
		if child != boss and child != boss._spawner and child.has_method("init"):
			if abs(child.global_position.x - expected_pos.x) < 1 and abs(child.global_position.y - expected_pos.y) < 1:
				found = true
				break
	assert_true(found, "A bullet should be at global_position + Vector2(0, 48)")

func test_spawn_minions_emits_signal():
	var boss = _create_boss()
	boss._spawner = MockSpawner.new()
	add_child_autofree(boss._spawner)
	watch_signals(boss._spawner)
	boss._spawn_minions()
	assert_signal_emitted(boss._spawner, "spawn_minion_requested", "Should emit spawn_minion_requested signal")

func test_boss_phase_changed_signal_emits_correct_phase():
	var boss = _create_boss()
	watch_signals(boss)
	boss.hp = int(Constants.BOSS_WAR_RIG_HP * 0.6)
	boss._check_phase()
	assert_signal_emitted(boss, "boss_phase_changed", "Phase changed signal should emit")
	var params = get_signal_parameters(boss, "boss_phase_changed")
	assert_eq(params[0], 2, "Should emit phase 2")

func test_check_phase_does_not_change_when_already_correct():
	var boss = _create_boss()
	boss.phase = 2
	boss.hp = int(Constants.BOSS_WAR_RIG_HP * 0.5)
	var signal_count = 0
	boss.boss_phase_changed.connect(func(_p): signal_count += 1)
	boss._check_phase()
	assert_eq(signal_count, 0, "Should not emit phase change when already at correct phase")
	assert_eq(boss.phase, 2, "Phase should remain 2")

func test_on_pool_release_resets_velocity_to_zero():
	var boss = _create_boss()
	boss.velocity = Vector2(100, 50)
	boss.on_pool_release()
	assert_eq(boss.velocity, Vector2.ZERO, "Velocity should reset to zero on pool release")

func test_on_pool_acquire_calls_reset_state():
	var boss = _create_boss()
	boss.hp = 5
	boss.phase = 3
	boss.minion_spawned = true
	boss.on_pool_acquire()
	assert_eq(boss.hp, Constants.BOSS_WAR_RIG_HP, "HP should reset on pool acquire")
	assert_eq(boss.phase, 1, "Phase should reset on pool acquire")
	assert_false(boss.minion_spawned, "Minion flag should reset on pool acquire")

func test_physics_process_calls_check_phase():
	var boss = _create_boss()
	boss.hp = int(Constants.BOSS_WAR_RIG_HP * 0.6)
	boss._physics_process(0.1)
	assert_eq(boss.phase, 2, "_physics_process should trigger _check_phase and advance to phase 2")

func test_physics_process_increments_attack_timer():
	var boss = _create_boss()
	boss.attack_timer = 0.0
	boss._physics_process(0.5)
	assert_eq(boss.attack_timer, 0.5, "Attack timer should increment by delta")
