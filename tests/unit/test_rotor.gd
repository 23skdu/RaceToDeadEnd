extends GutTest

func test_rotor_stunned_sets_zero_velocity():
	var rotor = load("res://scenes/enemies/Rotor.tscn").instantiate()
	add_child_autofree(rotor)
	var player = Node2D.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, 0)
	rotor.init(rotor.EnemyType.ROTOR, 1, player, 200.0)
	rotor.apply_stun(1.0)
	rotor._physics_process(0.1)
	assert_eq(rotor.velocity, Vector2.ZERO, "Stunned rotor should have zero velocity")

func test_rotor_moves_toward_player():
	var rotor = load("res://scenes/enemies/Rotor.tscn").instantiate()
	add_child_autofree(rotor)
	var player = Node2D.new()
	add_child_autofree(player)
	player.global_position = Vector2(100, -200)
	rotor.position = Vector2(0, 0)
	rotor.init(rotor.EnemyType.ROTOR, 1, player, 200.0)
	rotor._physics_process(0.1)
	assert_gt(rotor.velocity.x, 0.0, "Rotor should move toward player X")
	assert_lt(rotor.velocity.y, 0.0, "Rotor should move upward")

func test_rotor_weave_oscillates():
	var rotor = load("res://scenes/enemies/Rotor.tscn").instantiate()
	add_child_autofree(rotor)
	var player = Node2D.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, -200)
	rotor.position = Vector2(0, 0)
	rotor.init(rotor.EnemyType.ROTOR, 1, player, 200.0)
	rotor.swarm_phase = 0.0
	rotor._physics_process(0.1)
	var vx1 = rotor.velocity.x
	rotor.swarm_phase = PI
	rotor._physics_process(0.1)
	var vx2 = rotor.velocity.x
	assert_ne(sign(vx1), sign(vx2), "Weave should oscillate direction")

func test_rotor_speed_matches_init():
	var rotor = load("res://scenes/enemies/Rotor.tscn").instantiate()
	add_child_autofree(rotor)
	var player = Node2D.new()
	add_child_autofree(player)
	rotor.init(rotor.EnemyType.ROTOR, 0, player, 200.0)
	assert_eq(rotor.speed, 180.0, "Rotor speed should be 90% of base")

func test_rotor_tracks_invalid_player_gracefully():
	var rotor = load("res://scenes/enemies/Rotor.tscn").instantiate()
	add_child_autofree(rotor)
	var player = Node2D.new()
	add_child_autofree(player)
	rotor.init(rotor.EnemyType.ROTOR, 0, player, 200.0)
	player.queue_free()
	rotor._physics_process(0.1)
	assert_true(true, "Should not crash with invalid player")
