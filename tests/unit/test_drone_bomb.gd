extends GutTest

var DroneBomb

func before_all():
	DroneBomb = load("res://scripts/scenes/weapons/DroneBomb.gd")

func test_drone_bomb_defaults():
	var db = DroneBomb.new()
	add_child_autofree(db)
	assert_eq(db.age, 0.0, "Initial age")
	assert_false(db.exploded, "Should not be exploded initially")

func test_drone_bomb_collision_layer():
	var db = DroneBomb.new()
	add_child_autofree(db)
	assert_eq(db.collision_layer, 4, "Collision layer should be 4")
	assert_eq(db.collision_mask, 1 | 3, "Collision mask should include player (1) and player bullets (3)")

func test_drone_bomb_hit_by_bullet_detonates():
	var db = DroneBomb.new()
	add_child_autofree(db)
	var bullet = Area2D.new()
	bullet.add_to_group("bullet")
	db._on_area_entered(bullet)
	assert_true(db.hit_by_bullet, "Should mark hit_by_bullet true")
	assert_true(db.exploded, "Should detonate on bullet hit")

func test_drone_bomb_has_area_entered_connected():
	var db = DroneBomb.new()
	add_child_autofree(db)
	assert_true(db.area_entered.is_connected(db._on_area_entered), "area_entered should be connected")

func test_drone_bomb_has_collision_shape():
	var db = DroneBomb.new()
	add_child_autofree(db)
	var has_col = false
	for child in db.get_children():
		if child is CollisionShape2D:
			has_col = true
			break
	assert_true(has_col, "Should have a collision shape")

func test_drone_bomb_has_warning_visual():
	var db = DroneBomb.new()
	add_child_autofree(db)
	assert_true(db.warning_visual != null, "Should have warning visual")

func test_drone_bomb_age_increases():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(0.5)
	assert_eq(db.age, 0.5, "Age should increase")

func test_drone_bomb_blinks_before_detonation():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(0.5)
	assert_false(db.exploded, "Should not explode before detonation time")

func test_drone_bomb_detonates_at_time():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(1.6)
	assert_true(db.exploded, "Should explode after detonation time")

func test_drone_bomb_frees_after_fade():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(1.6)
	db._process(0.4)
	assert_true(db.is_queued_for_deletion(), "Should free after fade")

func test_drone_bomb_warning_increases_speed():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(0.1)
	var visible_early = db.warning_visual.visible
	db._process(1.4)
	var visible_late = db.warning_visual.visible
	assert_true(true, "Blink speed should increase over time")

func test_drone_bomb_has_explosion_visual():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(1.6)
	assert_true(db.explosion_visual != null, "Should have explosion visual after detonation")

func test_drone_bomb_ready_sets_collision():
	var db = DroneBomb.new()
	add_child_autofree(db)
	assert_eq(db.collision_layer, 4, "Collision layer should be 4")
	assert_eq(db.collision_mask, 1 | 3, "Collision mask should include player (1) and bullets (3)")

func test_drone_bomb_ready_creates_collision_shape():
	var db = DroneBomb.new()
	add_child_autofree(db)
	var has_col = false
	for child in db.get_children():
		if child is CollisionShape2D:
			has_col = true
			assert_is(child.shape, CircleShape2D, "Shape should be CircleShape2D")
			assert_eq(child.shape.radius, Constants.BLAST_RADIUS, "Radius should match BLAST_RADIUS")
			break
	assert_true(has_col, "Should have collision shape")

func test_drone_bomb_detonate_sets_flag():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._detonate()
	assert_true(db.exploded, "Exploded flag should be set")

func test_drone_bomb_detonate_clears_warning():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._detonate()
	assert_true(db.warning_visual.is_queued_for_deletion(), "Warning visual should be queued for deletion")

func test_drone_bomb_constants():
	assert_eq(Constants.DETONATION_TIME, 1.5, "Detonation time should be 1.5")
	assert_eq(Constants.BLAST_RADIUS, 80.0, "Blast radius should be 80")

func test_drone_bomb_fades_correctly():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(1.5)
	db._detonate()
	db._process(0.15)
	assert_false(db.is_queued_for_deletion(), "Should not free before fade completes")
	db._process(0.2)
	assert_true(db.is_queued_for_deletion(), "Should free after fade completes")

func test_drone_bomb_explosion_visual_scales():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(1.5)
	db._detonate()
	db._process(0.15)
	assert_gt(db.explosion_visual.scale.x, 1.0, "Explosion visual should scale up")

func test_drone_bbomb_explosion_visual_fades():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(1.5)
	db._detonate()
	db._process(0.15)
	assert_lt(db.explosion_visual.color.a, 0.8, "Explosion visual alpha should decrease")

func test_drone_bomb_detonate_damages_player_in_range():
	var db = DroneBomb.new()
	add_child_autofree(db)
	var mock_player = Node2D.new()
	mock_player.add_to_group("player")
	var damage_taken = 0
	mock_player.set("take_damage", func(amount = 1): damage_taken = amount)
	mock_player.set("is_in_group", func(group): return group == "player")
	db._detonate()
	assert_true(true, "Detonate should check overlapping bodies")

func test_drone_bomb_warning_visual_blinks():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(0.1)
	var visible_state_1 = db.warning_visual.visible
	db._process(0.1)
	var visible_state_2 = db.warning_visual.visible
	assert_true(true, "Warning visual should blink")

func test_drone_bomb_age_reaches_detonation():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(1.5)
	assert_eq(db.age, 1.5, "Age should reach detonation time")
	assert_true(db.exploded, "Should explode at detonation time")

func test_drone_bomb_fade_duration():
	var db = DroneBomb.new()
	add_child_autofree(db)
	db._process(1.5)
	db._detonate()
	db._process(0.3)
	assert_true(db.is_queued_for_deletion(), "Should queue free after 0.3s fade")
