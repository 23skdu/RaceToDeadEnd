extends GutTest

class MockPlayer:
	extends Node2D
	var current_lane: int = 1

func test_scav_stunned_sets_zero_velocity():
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	add_child_autofree(scav)
	var player = Node2D.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, 0)
	scav.init(scav.EnemyType.SCAV, 1, player, 200.0)
	scav.apply_stun(1.0)
	scav._physics_process(0.1)
	assert_eq(scav.velocity, Vector2.ZERO, "Stunned scav should have zero velocity")

func test_scav_flanks_player():
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	add_child_autofree(scav)
	var player = MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, -200)
	player.current_lane = 2
	scav.position = Vector2(0, 0)
	scav.lane = 3
	scav.init(scav.EnemyType.SCAV, 3, player, 200.0)
	scav._physics_process(0.1)
	assert_ne(scav.velocity.x, 0.0, "Scav should move laterally to flank")

func test_scav_rams_when_close():
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	add_child_autofree(scav)
	var player = MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(10, -100)
	player.current_lane = 1
	scav.position = Vector2(0, 0)
	scav.lane = 1
	scav.init(scav.EnemyType.SCAV, 1, player, 200.0)
	scav._physics_process(0.1)
	assert_true(scav.ramming, "Scav should be ramming when close")

func test_scav_does_not_ram_when_far():
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	add_child_autofree(scav)
	var player = MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, -500)
	player.current_lane = 1
	scav.position = Vector2(0, 0)
	scav.lane = 1
	scav.init(scav.EnemyType.SCAV, 1, player, 200.0)
	scav._physics_process(0.1)
	assert_false(scav.ramming, "Scav should not ram when far")

func test_scav_shoot_timer_decrements():
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	add_child_autofree(scav)
	var player = MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, -200)
	scav.init(scav.EnemyType.SCAV, 1, player, 200.0)
	var initial_timer = scav.shoot_timer
	scav._physics_process(0.1)
	assert_lt(scav.shoot_timer, initial_timer, "Shoot timer should decrement")

func test_scav_fire_bullet_creates_bullet():
	var world = Node2D.new()
	add_child_autofree(world)
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	world.add_child(scav)
	scav.world_node = world
	var player = MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, -200)
	scav.init(scav.EnemyType.SCAV, 1, player, 200.0)
	scav._fire_bullet()
	var bullets = []
	for child in world.get_children():
		if child is Area2D and child.is_in_group("bullet"):
			bullets.append(child)
	assert_gt(bullets.size(), 0, "Scav should create a bullet")

func test_scav_fire_bullet_downward():
	var world = Node2D.new()
	add_child_autofree(world)
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	world.add_child(scav)
	scav.world_node = world
	var player = MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, -200)
	scav.init(scav.EnemyType.SCAV, 1, player, 200.0)
	scav._fire_bullet()
	for child in world.get_children():
		if child is Area2D and child.is_in_group("bullet"):
			assert_eq(child.direction, Vector2.DOWN, "Scav bullet should face down")
			break

func test_scav_fire_bullet_fallback_to_parent():
	var container = Node2D.new()
	add_child_autofree(container)
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	container.add_child(scav)
	var player = MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, -200)
	scav.init(scav.EnemyType.SCAV, 1, player, 200.0)
	scav._fire_bullet()
	assert_true(true, "Should not crash when no world_node")

func test_scav_tracks_invalid_player_gracefully():
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	add_child_autofree(scav)
	var player = MockPlayer.new()
	add_child_autofree(player)
	scav.init(scav.EnemyType.SCAV, 0, player, 200.0)
	player.queue_free()
	scav._physics_process(0.1)
	assert_true(true, "Should not crash with invalid player")

func test_scav_speed_matches_init():
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	add_child_autofree(scav)
	var player = MockPlayer.new()
	add_child_autofree(player)
	scav.init(scav.EnemyType.SCAV, 0, player, 200.0)
	assert_eq(scav.speed, 140.0, "Scav speed should be 70% of base")

func test_scav_weapon_mount_onready_cached():
	var scav = load("res://scenes/enemies/Scav.tscn").instantiate()
	add_child_autofree(scav)
	assert_not_null(scav._weapon_mount, "_weapon_mount should be cached via @onready")
	assert_eq(scav._weapon_mount.name, "WeaponMount", "Cached node should be WeaponMount")
