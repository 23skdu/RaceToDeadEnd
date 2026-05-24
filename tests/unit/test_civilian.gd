extends GutTest

var civilian_scene = preload("res://scenes/enemies/Civilian.tscn")

func _create_civilian():
	var c = civilian_scene.instantiate()
	add_child_autofree(c)
	return c

func test_ready_sets_collision_layer():
	var c = _create_civilian()
	c._ready()
	assert_eq(c.collision_layer, 2)

func test_ready_sets_z_index():
	var c = _create_civilian()
	c._ready()
	assert_eq(c.z_index, 0)

func test_ready_generates_sprite_texture():
	var c = _create_civilian()
	c._ready()
	assert_not_null(c.sprite.texture)

func test_init_sets_speed_to_60_percent():
	var c = _create_civilian()
	c.init(0, 200.0, 1.0)
	assert_eq(c.speed, 120.0)

func test_init_sets_direction():
	var c = _create_civilian()
	c.init(0, 200.0, -1.0)
	assert_eq(c.direction, -1.0)

func test_init_sets_position():
	var c = _create_civilian()
	c.init(0, 200.0, 1.0)
	assert_eq(c.global_position.x, Constants.LANE_POSITIONS[0])
	assert_eq(c.global_position.y, 0.0)

func test_init_sets_protect_bonus_not_awarded():
	var c = _create_civilian()
	c._protect_bonus_awarded = true
	c.init(0, 200.0, 1.0)
	assert_false(c._protect_bonus_awarded)

func test_take_damage_emits_hit_by_player():
	var c = _create_civilian()
	watch_signals(c)
	c.take_damage(1)
	assert_signal_emitted(c, "hit_by_player")

func test_on_pool_acquire_resets_velocity():
	var c = _create_civilian()
	c.velocity = Vector2(100, 50)
	c.on_pool_acquire()
	assert_eq(c.velocity, Vector2.ZERO)

func test_on_pool_acquire_makes_visible():
	var c = _create_civilian()
	c.visible = false
	c.on_pool_acquire()
	assert_true(c.visible)

func test_on_pool_acquire_resets_protect_bonus():
	var c = _create_civilian()
	c._protect_bonus_awarded = true
	c.on_pool_acquire()
	assert_false(c._protect_bonus_awarded)

func test_on_pool_acquire_sets_process_mode():
	var c = _create_civilian()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.on_pool_acquire()
	assert_eq(c.process_mode, Node.PROCESS_MODE_INHERIT)

func test_on_pool_acquire_regenerates_sprite():
	var c = _create_civilian()
	c.sprite.texture = null
	c.on_pool_acquire()
	assert_not_null(c.sprite.texture)

func test_on_pool_release_resets_velocity():
	var c = _create_civilian()
	c.velocity = Vector2(50, 75)
	c.on_pool_release()
	assert_eq(c.velocity, Vector2.ZERO)

func test_on_pool_release_disconnects_exited_safely():
	var c = _create_civilian()
	c.exited_safely.connect(func(): pass)
	c.hit_by_player.connect(func(): pass)
	assert_eq(c.exited_safely.get_connections().size(), 1)
	assert_eq(c.hit_by_player.get_connections().size(), 1)
	c.on_pool_release()
	assert_eq(c.exited_safely.get_connections().size(), 0)
	assert_eq(c.hit_by_player.get_connections().size(), 0)

func test_generate_sprite_texture_creates_texture():
	var c = _create_civilian()
	c.sprite.texture = null
	c._generate_sprite_texture()
	assert_not_null(c.sprite.texture)

func test_exited_safely_emits_when_past_cleanup_distance():
	var c = _create_civilian()
	var player = Node2D.new()
	player.global_position = Vector2(0, 0)
	add_child_autofree(player)
	c.init(0, 100.0, 1.0, player)
	c.global_position = Vector2(-120, 500)
	watch_signals(c)
	c._physics_process(0.1)
	assert_signal_emitted(c, "exited_safely")

func test_physics_process_moves_civilian():
	var c = _create_civilian()
	c.init(0, 100.0, 1.0)
	var start = c.global_position
	c._physics_process(0.1)
	assert_ne(c.global_position, start)

func test_on_pool_acquire_nulls_player():
	var c = _create_civilian()
	var p = Node2D.new()
	add_child_autofree(p)
	c._player = p
	c.on_pool_acquire()
	assert_null(c._player)

func test_init_out_of_bounds_lane_defaults_to_zero():
	var c = _create_civilian()
	c.init(99, 200.0, 1.0)
	assert_eq(c.global_position.x, 0.0)

func test_civilian_caches_player_ref():
	var c = _create_civilian()
	assert_null(c._player, "Player should be null initially")
	var p = Node2D.new()
	add_child_autofree(p)
	c._player = p
	assert_eq(c._player, p, "Player ref should be cached")

func test_on_pool_acquire_does_not_regenerate_texture():
	var c = _create_civilian()
	c._ready()
	var texture = c.sprite.texture
	c.on_pool_acquire()
	assert_eq(c.sprite.texture, texture, "Texture should be preserved across pool acquire")

func test_on_pool_acquire_regenerates_texture_when_missing():
	var c = _create_civilian()
	c._ready()
	c.sprite.texture = null
	c.on_pool_acquire()
	assert_not_null(c.sprite.texture, "Texture should be regenerated when missing")
