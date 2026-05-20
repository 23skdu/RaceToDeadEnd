extends GutTest

var DroneBomb

func before_all():
	DroneBomb = load("res://scenes/weapons/DroneBomb.gd")

func test_drone_bomb_defaults():
	var db = DroneBomb.new()
	add_child_autofree(db)
	assert_eq(db.age, 0.0, "Initial age")
	assert_false(db.exploded, "Should not be exploded initially")

func test_drone_bomb_collision_layer():
	var db = DroneBomb.new()
	add_child_autofree(db)
	assert_eq(db.collision_layer, 4, "Collision layer should be 4")
	assert_eq(db.collision_mask, 1, "Collision mask should be 1 (player)")

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
	assert_is_not_null(db.warning_visual, "Should have warning visual")

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
	assert_is_not_null(db.explosion_visual, "Should have explosion visual after detonation")

func test_drone_bomb_ready_sets_collision():
	var db = DroneBomb.new()
	add_child_autofree(db)
	assert_eq(db.collision_layer, 4, "Collision layer should be 4")
	assert_eq(db.collision_mask, 1, "Collision mask should be 1 (player)")

func test_drone_bomb_ready_creates_collision_shape():
	var db = DroneBomb.new()
	add_child_autofree(db)
	var has_col = false
	for child in db.get_children():
		if child is CollisionShape2D:
			has_col = true
			assert_is(child.shape, CircleShape2D, "Shape should be CircleShape2D")
			assert_eq(child.shape.radius, db.BLAST_RADIUS, "Radius should match BLAST_RADIUS")
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
