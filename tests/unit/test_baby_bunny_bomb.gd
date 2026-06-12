extends GutTest

func test_bomb_extends_enemy():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	assert_true(bomb is CharacterBody2D, "Bomb should be a CharacterBody2D")

func test_bomb_ready_sets_hp():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	bomb._ready()
	assert_eq(bomb.hp, 1, "HP should be 1")

func test_bomb_ready_sets_score():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	bomb._ready()
	assert_eq(bomb.score_value, 100, "Score value should be 100")

func test_bomb_ready_sets_speed():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	bomb._ready()
	assert_eq(bomb.speed, 150.0, "Speed should be 150")

func test_bomb_texture_generated():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	assert_not_null(bomb.sprite.texture, "Texture should be generated")
	assert_false(bomb.sprite.texture is PlaceholderTexture2D, "Texture should not be placeholder")
	assert_eq(bomb.sprite.texture.get_width(), 32, "Texture width should be 32")

func test_bomb_texture_has_opaque_pixels():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	var img = bomb.sprite.texture.get_image()
	var has_opaque = false
	for x in 32:
		for y in 32:
			if img.get_pixel(x, y).a > 0.0:
				has_opaque = true
				break
		if has_opaque:
			break
	assert_true(has_opaque, "Texture should have non-transparent pixels")

func test_bomb_jump_timer_starts_zero():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	assert_eq(bomb.jump_timer, 0.0, "Jump timer starts at 0")

func test_bomb_physics_process_stunned():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	bomb.stunned = true
	bomb._physics_process(0.1)
	assert_true(true, "Should not crash when stunned")

func test_bomb_physics_process_moves_down():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	var player = Node2D.new()
	player.global_position = Vector2(0, -200)
	bomb.position = Vector2(0, 0)
	bomb.init(bomb.EnemyType.BUNNY, 0, player, 200.0)
	bomb._ready()
	var initial_y = bomb.position.y
	bomb._physics_process(0.1)
	assert_gt(bomb.position.y, initial_y, "Bomb should move downward")

func test_bomb_physics_process_moves_toward_player_x():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	var player = Node2D.new()
	player.global_position = Vector2(100, 0)
	bomb.position = Vector2(0, 0)
	bomb.init(bomb.EnemyType.BUNNY, 0, player, 200.0)
	bomb._ready()
	bomb._physics_process(0.1)
	assert_gt(bomb.velocity.x, 0.0, "Bomb should move toward player X")

func test_bomb_pool_acquire_resets_hp():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	bomb.on_pool_acquire()
	assert_eq(bomb.hp, 1, "HP should reset to 1 on acquire")

func test_bomb_pool_acquire_resets_speed():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	bomb.on_pool_acquire()
	assert_eq(bomb.speed, 150.0, "Speed should reset to 150 on acquire")

func test_bomb_physics_process_no_player_graceful():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	bomb._physics_process(0.1)
	assert_true(true, "Should not crash with null player")

func test_bomb_take_damage():
	var bomb = load("res://scenes/weapons/BabyBunnyBomb.tscn").instantiate()
	add_child_autofree(bomb)
	bomb._ready()
	bomb.take_damage(1)
	assert_eq(bomb.hp, 0, "HP should be 0 after damage")

class MockKinematicCollision2D:
	var _collider = null
	func get_collider():
		return _collider

class MockBabyBunnyBomb extends "res://scripts/scenes/weapons/BabyBunnyBomb.gd":
	var mock_collision = null
	func _ready() -> void:
		pass
	func _perform_movement_collision(_velocity_vec, _delta_val):
		return mock_collision
	func _die() -> void:
		destroyed.emit(global_position, "baby_bunny_bomb", self)

func test_bomb_detonates_on_any_collision():
	var bomb = MockBabyBunnyBomb.new()
	
	var obstacle = StaticBody2D.new()
	obstacle.name = "SomeObstacle"
	add_child_autofree(obstacle)
	
	var col = MockKinematicCollision2D.new()
	col._collider = obstacle
	bomb.mock_collision = col
	
	watch_signals(bomb)
	bomb._physics_process(0.1)
	assert_signal_emitted(bomb, "destroyed", "Bomb should detonate and emit destroyed signal on any collision")
	bomb.free()
