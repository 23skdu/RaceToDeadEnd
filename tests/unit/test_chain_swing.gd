extends GutTest

class MockPlayerWithDamage:
	extends Node2D
	var damage_taken = 0
	func take_damage(amount):
		damage_taken = amount

func _create_chain_swing():
	var swing = load("res://scenes/weapons/ChainSwing.tscn").instantiate()
	add_child_autofree(swing)
	return swing

func test_swing_defaults():
	var s = _create_chain_swing()
	assert_eq(s.swing_duration, 0.6, "Swing duration")
	assert_eq(s.age, 0.0, "Age starts at 0")
	assert_false(s.swung, "Not swung initially")

func test_swing_ready_creates_children():
	var s = _create_chain_swing()
	assert_not_null(s.get_node_or_null("ChainLine"), "Should have ChainLine")
	assert_not_null(s.get_node_or_null("ChainTip"), "Should have ChainTip")
	assert_not_null(s.get_node_or_null("ChainGlow"), "Should have ChainGlow")

func test_swing_ready_sets_collision_layers():
	var s = _create_chain_swing()
	assert_eq(s.collision_layer, 4, "Collision layer 4")
	assert_eq(s.collision_mask, 1, "Collision mask 1")

func test_swing_sets_swung_flag():
	var s = _create_chain_swing()
	s.swing()
	assert_true(s.swung, "Swung flag should be true after swing")

func test_swing_does_not_swing_twice():
	var s = _create_chain_swing()
	s.swing()
	s.swing()
	assert_true(s.swung, "Should not reset from second call")

func test_swing_rotation_animates():
	var s = _create_chain_swing()
	assert_eq(s.rotation, 0.0, "Rotation starts at 0")
	s.swing()
	assert_gt(s.rotation, deg_to_rad(-60.0), "Rotation should start from -60 degrees")

func test_swing_body_entered_calls_take_damage():
	var s = _create_chain_swing()
	var player = MockPlayerWithDamage.new()
	player.add_to_group("player")
	add_child_autofree(player)
	s._on_body_entered(player)
	assert_eq(player.damage_taken, 1, "Player should take 1 damage")

func test_swing_body_entered_non_player_ignored():
	var s = _create_chain_swing()
	var non_player = Node2D.new()
	add_child_autofree(non_player)
	s._on_body_entered(non_player)
	assert_true(true, "Should not crash with non-player")

func test_swing_body_entered_not_in_group_ignored():
	var s = _create_chain_swing()
	var mock = Node2D.new()
	mock.add_to_group("enemy")
	add_child_autofree(mock)
	s._on_body_entered(mock)
	assert_true(true, "Should not crash with non-player group body")

func test_swing_pool_acquire_resets():
	var s = _create_chain_swing()
	s.swung = true
	s.rotation = deg_to_rad(130.0)
	s.on_pool_acquire()
	assert_false(s.swung, "Swung should reset on acquire")
	assert_eq(s.rotation, 0.0, "Rotation should reset on acquire")
	assert_eq(s.age, 0.0, "Age should reset on acquire")

func test_swing_has_collision_shape():
	var s = _create_chain_swing()
	var shapes = []
	for child in s.get_children():
		if child is CollisionShape2D:
			shapes.append(child)
	assert_eq(shapes.size(), 1, "Should have one CollisionShape2D")

func test_swing_body_entered_player_requires_group():
	var s = _create_chain_swing()
	var player = MockPlayerWithDamage.new()
	add_child_autofree(player)
	s._on_body_entered(player)
	assert_eq(player.damage_taken, 0, "Non-group player should not take damage")

func test_swing_pool_release_kills_active_tween():
	var s = _create_chain_swing()
	s.swing()
	assert_not_null(s._tween, "Active tween should exist after swing()")
	assert_true(s._tween.is_valid(), "Tween should be valid while swinging")
	s.on_pool_release()
	assert_null(s._tween, "Tween should be cleared on pool release")
	assert_false(s.swung, "Swung flag should reset on pool release")
