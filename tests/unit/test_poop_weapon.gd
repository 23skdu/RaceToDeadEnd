extends GutTest

class MockPlayerDamageable:
	extends Node2D
	var damage_taken = 0
	var is_slippery = false
	func take_damage(amount):
		damage_taken = amount
	func set_slippery(val):
		is_slippery = val

func _create_poop():
	var poop = load("res://scenes/weapons/PoopWeapon.tscn").instantiate()
	add_child_autofree(poop)
	return poop

func test_poop_defaults():
	var p = _create_poop()
	assert_eq(p.speed, Constants.BULLET_SPEED * 0.6, "Default speed")
	assert_eq(p.direction, Vector2.DOWN, "Default direction")
	assert_eq(p.damage, 1, "Default damage")

func test_poop_ready_sets_z_index():
	var p = _create_poop()
	assert_eq(p.z_index, 2, "Z index should be 2")

func test_poop_added_to_group():
	var p = _create_poop()
	assert_true(p.is_in_group("enemy_projectile"), "Should be in enemy_projectile group")

func test_poop_ready_connects_signals():
	var p = _create_poop()
	assert_true(p.body_entered.is_connected(p._on_body_entered), "body_entered should be connected")

func test_poop_init_sets_position():
	var p = _create_poop()
	p.init(Vector2(100, 200), Vector2.DOWN)
	assert_eq(p.global_position, Vector2(100, 200), "Position should be set")
	assert_eq(p.direction, Vector2.DOWN, "Direction should be set")

func test_poop_init_sets_collision():
	var p = _create_poop()
	p.init(Vector2.ZERO, Vector2.DOWN)
	assert_eq(p.collision_layer, 4, "Collision layer should be 4")
	assert_eq(p.collision_mask, 1, "Collision mask should be 1")

func test_poop_moves_down():
	var p = _create_poop()
	p.init(Vector2(100, 0), Vector2.DOWN)
	var initial_y = p.position.y
	p._physics_process(0.1)
	assert_gt(p.position.y, initial_y, "Poop should move downward")

func test_poop_moves_in_direction():
	var p = _create_poop()
	p.init(Vector2(0, 0), Vector2.RIGHT)
	var initial_x = p.position.x
	p._physics_process(0.1)
	assert_gt(p.position.x, initial_x, "Poop should move right")

func test_poop_body_entered_applies_damage():
	var p = _create_poop()
	p.init(Vector2.ZERO, Vector2.DOWN)
	var player = MockPlayerDamageable.new()
	player.name = "Player"
	add_child_autofree(player)
	p._on_body_entered(player)
	assert_eq(player.damage_taken, 1, "Player should take 1 damage")

func test_poop_body_entered_applies_slippery():
	var p = _create_poop()
	p.init(Vector2.ZERO, Vector2.DOWN)
	var player = MockPlayerDamageable.new()
	player.name = "Player"
	add_child_autofree(player)
	p._on_body_entered(player)
	assert_true(player.is_slippery, "Player should become slippery")

func test_poop_texture_generated():
	var p = _create_poop()
	var sprite = p.get_node("Sprite2D")
	assert_not_null(sprite.texture, "Texture should be generated")
	assert_false(sprite.texture is PlaceholderTexture2D, "Texture should not be placeholder")
	assert_eq(sprite.texture.get_width(), 16, "Texture width")
	assert_eq(sprite.texture.get_height(), 16, "Texture height")

func test_poop_texture_has_content():
	var p = _create_poop()
	var sprite = p.get_node("Sprite2D")
	var img = sprite.texture.get_image()
	var has_opaque = false
	for x in 16:
		for y in 16:
			if img.get_pixel(x, y).a > 0.0:
				has_opaque = true
				break
		if has_opaque:
			break
	assert_true(has_opaque, "Texture should have non-transparent pixels")

func test_poop_speed_constant():
	var p = _create_poop()
	assert_eq(p.speed, Constants.BULLET_SPEED * 0.6, "Speed should be 60% of bullet speed")
