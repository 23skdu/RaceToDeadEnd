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
