extends GutTest

var EnemyScript

func before_all():
	EnemyScript = load("res://scripts/scenes/enemies/Enemy.gd")

func test_bullet_damage_enemy():
	var BulletScene = load("res://scenes/weapons/Bullet.tscn")
	GameManager.state = GameManager.GameState.PLAYING

	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.init(Vector2.ZERO, Vector2.UP, true)

	var EnemyScene = load("res://scenes/enemies/Rotor.tscn")
	var enemy = EnemyScene.instantiate()
	add_child_autofree(enemy)
	enemy.init(EnemyScript.EnemyType.ROTOR, 0, null, 200.0)

	assert_true(enemy.hp > 0, "Enemy should have health before damage")
	bullet.body_entered.emit(enemy)
	assert_eq(enemy.hp, 0, "Enemy should have 0 hp after damage")

func test_bunny_stays_in_front_and_dies_when_shot_in_scaled_world():
	Engine.physics_interpolation = false
	var game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game)
	Engine.physics_interpolation = true
	var player = game.player
	var spawner = game.spawner
	player.position = Vector2(0, -2000)
	spawner._spawn_enemy("bunny")
	var bunny = spawner.get_children().back()
	bunny.global_position = player.global_position + Vector2(0, -100)
	for _i in range(5):
		bunny._physics_process(0.016)
	assert_lt(bunny.global_position.y, player.global_position.y, "Bunny must stay ahead of player even with WORLD_SCALE")

	watch_signals(bunny)
	bunny.take_damage(1)
	bunny.take_damage(1)
	assert_signal_emit_count(bunny, "destroyed", 1, "Bunny must die once and not double-emit on simultaneous hits")
	assert_true(bunny.get_meta("_in_pool", false), "Dead bunny should return to ObjectPool")

func test_boss_bunny_dies_on_repeat_pool_acquires():
	var BossBunnyScene = load("res://scenes/enemies/BossBunny.tscn")
	ObjectPool.create_pool("test_boss_bunny_reacquire", BossBunnyScene, 1)
	for cycle in range(3):
		var boss = ObjectPool.acquire("test_boss_bunny_reacquire")
		add_child_autofree(boss)
		assert_false(boss.collision.disabled, "BossBunny collision must be enabled on acquire cycle %d" % cycle)
		assert_eq(boss.sprite.scale, Vector2.ONE, "BossBunny sprite scale must be Vector2.ONE on acquire cycle %d" % cycle)
		assert_eq(boss.hp, Constants.BOSS_BUNNY_HP, "BossBunny HP must reset on cycle %d" % cycle)
		boss.take_damage(Constants.BOSS_BUNNY_HP)
		assert_true(boss.get_meta("_in_pool", false), "BossBunny must die and return to pool on cycle %d" % cycle)
	ObjectPool._pools.erase("test_boss_bunny_reacquire")
