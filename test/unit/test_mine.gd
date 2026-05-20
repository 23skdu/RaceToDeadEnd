extends GutTest

var Mine

func before_all():
	Mine = load("res://scenes/weapons/Mine.gd")

func test_mine_defaults():
	var m = Mine.new()
	add_child_autofree(m)
	assert_eq(m.damage, 2, "Default damage")
	assert_eq(m.explosion_radius, 64.0, "Default radius")
	assert_false(m.armed, "Should not be armed initially")
	assert_eq(m.arm_time, 0.5, "Default arm time")

func test_init_sets_position():
	var m = Mine.new()
	add_child_autofree(m)
	m.init(Vector2(50, 100))
	assert_eq(m.global_position, Vector2(50, 100), "Position should be set")

func test_mine_added_to_group():
	var m = Mine.new()
	add_child_autofree(m)
	assert_true(m.is_in_group("mine"), "Should be in 'mine' group")

func test_mine_collision_mask():
	var m = Mine.new()
	add_child_autofree(m)
	assert_eq(m.collision_mask, 2, "Mine collision mask should be 2")

func test_mine_explodes_on_body_entered():
	var m = Mine.new()
	add_child_autofree(m)
	m.armed = true
	var mock_body = Node2D.new()
	m._on_body_entered(mock_body)
	assert_true(m.is_queued_for_deletion(), "Mine should explode")

func test_mine_ignores_when_not_armed():
	var m = Mine.new()
	add_child_autofree(m)
	m.armed = false
	var mock_body = Node2D.new()
	m._on_body_entered(mock_body)
	assert_false(m.is_queued_for_deletion(), "Mine should not explode when not armed")

func test_mine_area_entered():
	var m = Mine.new()
	add_child_autofree(m)
	m.armed = true
	var mock_area = Area2D.new()
	m._on_area_entered(mock_area)
	assert_true(m.is_queued_for_deletion(), "Mine should explode on area entered")

func test_mine_aoe_damages_nearby_enemies():
	var m = Mine.new()
	add_child_autofree(m)
	m.global_position = Vector2(0, 0)
	m.armed = true
	
	var enemy1 = Node2D.new()
	enemy1.global_position = Vector2(30, 30)
	var damage1 = 0
	enemy1.set("take_damage", func(amount = 1): damage1 = amount)
	enemy1.add_to_group("enemy")
	add_child_autofree(enemy1)
	
	var enemy2 = Node2D.new()
	enemy2.global_position = Vector2(200, 200)
	var damage2 = 0
	enemy2.set("take_damage", func(amount = 1): damage2 = amount)
	enemy2.add_to_group("enemy")
	add_child_autofree(enemy2)
	
	m._explode()
	assert_eq(damage1, 2, "Nearby enemy should take damage")
	assert_eq(damage2, 0, "Far enemy should not take damage")

func test_mine_aoe_respects_radius():
	var m = Mine.new()
	add_child_autofree(m)
	m.global_position = Vector2(0, 0)
	m.explosion_radius = 50.0
	m.armed = true
	
	var enemy_at_edge = Node2D.new()
	enemy_at_edge.global_position = Vector2(49, 0)
	var damage_edge = 0
	enemy_at_edge.set("take_damage", func(amount = 1): damage_edge = amount)
	enemy_at_edge.add_to_group("enemy")
	add_child_autofree(enemy_at_edge)
	
	var enemy_outside = Node2D.new()
	enemy_outside.global_position = Vector2(51, 0)
	var damage_outside = 0
	enemy_outside.set("take_damage", func(amount = 1): damage_outside = amount)
	enemy_outside.add_to_group("enemy")
	add_child_autofree(enemy_outside)
	
	m._explode()
	assert_eq(damage_edge, 2, "Enemy within radius should take damage")
	assert_eq(damage_outside, 0, "Enemy outside radius should not take damage")

func test_mine_aoe_ignores_invalid_enemies():
	var m = Mine.new()
	add_child_autofree(m)
	m.global_position = Vector2(0, 0)
	m.armed = true
	
	var invalid_enemy = Node2D.new()
	invalid_enemy.global_position = Vector2(10, 10)
	invalid_enemy.queue_free()
	invalid_enemy.add_to_group("enemy")
	add_child_autofree(invalid_enemy)
	
	m._explode()
	assert_true(m.is_queued_for_deletion(), "Mine should explode without errors")

func test_mine_ready_arms_after_delay():
	var m = Mine.new()
	add_child_autofree(m)
	assert_false(m.armed, "Mine should not be armed initially")
	await get_tree().create_timer(0.6).timeout
	assert_true(m.armed, "Mine should be armed after delay")
