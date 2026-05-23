extends GutTest

var BossScene
var EnemyScript

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
