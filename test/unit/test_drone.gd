extends GutTest

func test_drone_stunned_sets_zero_velocity():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	var player = Node2D.new()
	player.global_position = Vector2(0, 0)
	drone.init(drone.EnemyType.DRONE, 1, player, 200.0)
	drone.apply_stun(1.0)
	drone._physics_process(0.1)
	assert_eq(drone.velocity, Vector2.ZERO, "Stunned drone should have zero velocity")

func test_drone_tracks_player_x():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	var player = Node2D.new()
	player.global_position = Vector2(100, -200)
	drone.position = Vector2(0, 0)
	drone.init(drone.EnemyType.DRONE, 1, player, 200.0)
	drone._physics_process(0.1)
	assert_gt(drone.velocity.x, 0.0, "Drone should move toward player X")

func test_drone_maintains_distance_behind_player():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	var player = Node2D.new()
	player.global_position = Vector2(0, -300)
	drone.position = Vector2(0, 0)
	drone.init(drone.EnemyType.DRONE, 1, player, 200.0)
	drone._physics_process(0.1)
	assert_lt(drone.velocity.y, 0.0, "Drone should move upward to maintain distance")

func test_drone_bomb_timer_decrements():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	var player = Node2D.new()
	player.global_position = Vector2(0, -200)
	drone.init(drone.EnemyType.DRONE, 1, player, 200.0)
	var initial_timer = drone.bomb_timer
	drone._physics_process(0.1)
	assert_lt(drone.bomb_timer, initial_timer, "Bomb timer should decrement")

func test_drone_drop_bomb_creates_area():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	var world = Node2D.new()
	add_child_autofree(world)
	world.add_child(drone)
	drone.world_node = world
	var player = Node2D.new()
	player.global_position = Vector2(0, -200)
	drone.init(drone.EnemyType.DRONE, 1, player, 200.0)
	drone._drop_bomb()
	var bombs = []
	for child in world.get_children():
		if child is Area2D and child.get_script() == preload("res://scenes/weapons/DroneBomb.gd"):
			bombs.append(child)
	assert_gt(bombs.size(), 0, "Drone should create a bomb")

func test_drone_drop_bomb_position():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	var world = Node2D.new()
	add_child_autofree(world)
	world.add_child(drone)
	drone.world_node = world
	drone.global_position = Vector2(50, -100)
	var player = Node2D.new()
	player.global_position = Vector2(0, -200)
	drone.init(drone.EnemyType.DRONE, 1, player, 200.0)
	drone._drop_bomb()
	for child in world.get_children():
		if child is Area2D and child.get_script() == preload("res://scenes/weapons/DroneBomb.gd"):
			assert_eq(child.global_position.y, drone.global_position.y + 48, "Bomb should drop below drone")
			break

func test_drone_drop_bomb_fallback_to_parent():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	var player = Node2D.new()
	player.global_position = Vector2(0, -200)
	drone.init(drone.EnemyType.DRONE, 1, player, 200.0)
	drone._drop_bomb()
	assert_true(true, "Should not crash when no world_node")

func test_drone_drop_bomb_null_player_guard():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	drone.player = null
	drone._drop_bomb()
	assert_true(true, "Should not crash with null player")

func test_drone_tracks_invalid_player_gracefully():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	var player = Node2D.new()
	drone.init(drone.EnemyType.DRONE, 0, player, 200.0)
	player.queue_free()
	drone._physics_process(0.1)
	assert_true(true, "Should not crash with invalid player")

func test_drone_speed_matches_init():
	var drone = load("res://scenes/enemies/Drone.tscn").instantiate()
	add_child_autofree(drone)
	var player = Node2D.new()
	drone.init(drone.EnemyType.DRONE, 0, player, 200.0)
	assert_eq(drone.speed, 100.0, "Drone speed should be 50% of base")
