extends GutTest

class MockEnemy:
	extends Node2D
	var damage_taken = 0
	func take_damage(amount = 1):
		damage_taken = amount

class MockAreaWithDamage extends Area2D:
	var damage_taken = 0
	func take_damage(amount = 1):
		damage_taken = amount

var Mine

func before_all():
	Mine = load("res://scripts/scenes/weapons/Mine.gd")

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
	
	var enemy1 = MockEnemy.new()
	enemy1.global_position = Vector2(30, 30)
	enemy1.add_to_group("enemy")
	add_child_autofree(enemy1)
	
	var enemy2 = MockEnemy.new()
	enemy2.global_position = Vector2(200, 200)
	enemy2.add_to_group("enemy")
	add_child_autofree(enemy2)
	
	GameManager.enemy_list.append_array([enemy1, enemy2])
	m._explode()
	assert_eq(enemy1.damage_taken, 2, "Nearby enemy should take damage")
	assert_eq(enemy2.damage_taken, 0, "Far enemy should not take damage")

func test_mine_aoe_respects_radius():
	var m = Mine.new()
	add_child_autofree(m)
	m.global_position = Vector2(0, 0)
	m.explosion_radius = 50.0
	m.armed = true
	
	var enemy_at_edge = MockEnemy.new()
	enemy_at_edge.global_position = Vector2(49, 0)
	enemy_at_edge.add_to_group("enemy")
	add_child_autofree(enemy_at_edge)
	
	var enemy_outside = MockEnemy.new()
	enemy_outside.global_position = Vector2(51, 0)
	enemy_outside.add_to_group("enemy")
	add_child_autofree(enemy_outside)
	
	GameManager.enemy_list.append_array([enemy_at_edge, enemy_outside])
	m._explode()
	assert_eq(enemy_at_edge.damage_taken, 2, "Enemy within radius should take damage")
	assert_eq(enemy_outside.damage_taken, 0, "Enemy outside radius should not take damage")

func test_mine_aoe_ignores_invalid_enemies():
	var m = Mine.new()
	add_child_autofree(m)
	m.global_position = Vector2(0, 0)
	m.armed = true
	
	var invalid_enemy = MockEnemy.new()
	invalid_enemy.global_position = Vector2(10, 10)
	invalid_enemy.add_to_group("enemy")
	invalid_enemy.queue_free()
	add_child_autofree(invalid_enemy)
	
	m._explode()
	assert_true(m.is_queued_for_deletion(), "Mine should explode without errors")

func test_ready_creates_blast_collision_shape():
	var m = Mine.new()
	add_child_autofree(m)
	assert_not_null(m._blast_col, "_blast_col should be set after _ready")
	assert_true(m._blast_col is CollisionShape2D, "_blast_col should be CollisionShape2D")
	assert_true(m._blast_col.shape is CircleShape2D, "Blast shape should be CircleShape2D")

func test_init_sets_blast_radius():
	var m = Mine.new()
	add_child_autofree(m)
	m.init(Vector2(10, 20))
	assert_eq(m.global_position, Vector2(10, 20), "Position should be set by init")
	assert_eq(m._blast_col.shape.radius, m.explosion_radius, "Blast radius should match explosion_radius")
	assert_true(m._blast_col.disabled, "Blast collision should be disabled after init")

func test_on_body_entered_calls_take_damage():
	var m = Mine.new()
	add_child_autofree(m)
	m.armed = true
	var body = MockEnemy.new()
	m._on_body_entered(body)
	assert_eq(body.damage_taken, 2, "Body should take mine damage")

func test_on_body_entered_no_explode_when_not_armed():
	var m = Mine.new()
	add_child_autofree(m)
	m.armed = false
	var body = MockEnemy.new()
	m._on_body_entered(body)
	assert_eq(body.damage_taken, 0, "Should not damage when not armed")
	assert_false(m.is_queued_for_deletion(), "Should not explode when not armed")

func test_on_area_entered_calls_take_damage():
	var m = Mine.new()
	add_child_autofree(m)
	m.armed = true
	var area = MockAreaWithDamage.new()
	m._on_area_entered(area)
	assert_eq(area.damage_taken, 2, "Area should take mine damage")

func test_explode_creates_polygon_flash():
	var parent = Node2D.new()
	add_child_autofree(parent)
	var m = Mine.new()
	parent.add_child(m)
	m._explode()
	var flash_found = false
	for child in parent.get_children():
		if child is Polygon2D:
			flash_found = true
			break
	assert_true(flash_found, "Explosion should create Polygon2D flash")

func test_explode_calls_object_pool_release():
	var m = Mine.new()
	add_child_autofree(m)
	m._explode()
	assert_true(m.is_queued_for_deletion(), "Mine should be released after explosion")

func test_armed_false_after_instantiation():
	var m = Mine.new()
	assert_false(m.armed, "Mine should not be armed when first created")

func test_armed_becomes_true_after_arm_time():
	var m = Mine.new()
	add_child_autofree(m)
	assert_false(m.armed, "Should not be armed immediately after add_child")
	await get_tree().create_timer(m.arm_time + 0.2).timeout
	assert_true(m.armed, "Should be armed after arm_time elapses")

func test_blast_col_enabled_on_arm():
	var m = Mine.new()
	add_child_autofree(m)
	assert_true(m._blast_col.disabled, "Blast collision should be disabled initially")
	await get_tree().create_timer(m.arm_time + 0.2).timeout
	assert_true(m.armed, "Should be armed after arm_time")
	assert_false(m._blast_col.disabled, "Blast collision should be enabled when armed")
