extends GutTest

var EMPScene

class MockEnemy:
	extends Node2D
	var was_stunned = false
	var stun_dur = 0.0
	var damage_taken = 0
	func take_damage(amount = 1):
		damage_taken = amount
	func apply_stun(duration):
		was_stunned = true
		stun_dur = duration

func before_all():
	EMPScene = load("res://scenes/weapons/EMPBlast.tscn")

func _create_emp():
	var e = EMPScene.instantiate()
	add_child_autofree(e)
	return e

func test_emp_defaults():
	var e = _create_emp()
	assert_eq(e.damage, 1, "Default damage")
	assert_eq(e.stun_duration, 2.0, "Default stun duration")
	assert_eq(e.expand_speed, 400.0, "Default expand speed")
	assert_eq(e.max_radius, 400.0, "Default max radius")
	assert_eq(e.current_radius, 0.0, "Default current radius")

func test_init_sets_position():
	var e = _create_emp()
	e.init(Vector2(100, 200))
	assert_eq(e.global_position, Vector2(100, 200), "Position should be set")

func test_emp_added_to_group():
	var e = _create_emp()
	assert_true(e.is_in_group("emp"), "Should be in 'emp' group")

func test_emp_collision_mask():
	var e = _create_emp()
	assert_eq(e.collision_mask, 2, "EMP collision mask should be 2")

func test_emp_expands_over_time():
	var e = _create_emp()
	e._process(0.5)
	assert_gt(e.current_radius, 0.0, "Radius should increase")

func test_emp_reaches_max_radius():
	var e = _create_emp()
	for i in range(20):
		e._process(0.1)
	assert_eq(e.current_radius, e.max_radius, "Should reach max radius")

func test_emp_frees_at_max_radius():
	var e = _create_emp()
	e.current_radius = e.max_radius
	e._process(0.1)
	assert_true(e.is_queued_for_deletion(), "Should free at max radius")

func test_emp_damages_on_body_entered():
	var e = _create_emp()
	var mock_enemy = MockEnemy.new()
	add_child_autofree(mock_enemy)
	e._on_body_entered(mock_enemy)
	assert_eq(mock_enemy.damage_taken, 1, "Should deal damage")

func test_emp_updates_collision_shape_radius():
	var e = _create_emp()
	e.current_radius = 200.0
	e._update_collision_radius()
	assert_not_null(e._col_shape, "Collision shape should exist after ready")
	assert_not_null(e._col_shape.shape, "Collision shape should have a shape resource")
	if e._col_shape.shape is CircleShape2D:
		assert_eq(e._col_shape.shape.radius, 200.0, "Collision shape radius should match current_radius")

func test_emp_starts_with_zero_radius():
	var e = _create_emp()
	assert_eq(e.current_radius, 0.0, "Should start at zero radius")

func test_emp_applies_stun_on_hit():
	var e = _create_emp()
	var mock_enemy = MockEnemy.new()
	add_child_autofree(mock_enemy)
	e._on_body_entered(mock_enemy)
	assert_true(mock_enemy.was_stunned, "Enemy should be stunned")
	assert_eq(mock_enemy.stun_dur, 2.0, "Stun duration should be 2 seconds")

func test_emp_ready_sets_collision():
	var e = _create_emp()
	assert_eq(e.collision_layer, 0, "EMP should be on layer 0")
	assert_eq(e.collision_mask, 2, "EMP should mask layer 2")
	assert_true(e.is_in_group("emp"), "EMP should be in emp group")

func test_emp_fallback_does_not_set_pool_name():
	var e = _create_emp()
	assert_false(e.has_meta("_pool_name"), "EMP from fallback should not have _pool_name meta")
