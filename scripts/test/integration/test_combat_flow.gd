extends GutTest

func test_bullet_damage_enemy():
	var BulletScene = load("res://scenes/weapons/Bullet.tscn")
	GameManager.state = GameManager.GameState.PLAYING

	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.init(Vector2.ZERO, Vector2.UP, true)

	var EnemyScene = load("res://scenes/enemies/Rotor.tscn")
	var enemy = EnemyScene.instantiate()
	add_child_autofree(enemy)
	enemy.init(Vector2(0, -50), null)

	assert_true(enemy.health > 0, "Enemy should have health before damage")
	bullet.body_entered.emit(enemy)
	await get_tree().process_frame
	assert_lt(enemy.health, enemy.max_health, "Enemy should take damage from bullet")
