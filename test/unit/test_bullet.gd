extends GutTest

var Bullet

func before_all():
	Bullet = load("res://scenes/weapons/Bullet.gd")

func test_bullet_defaults():
	var b = Bullet.new()
	add_child_autofree(b)
	assert_eq(b.speed, 500.0, "Default speed")
	assert_eq(b.damage, 1, "Default damage")
	assert_eq(b.homing_strength, 0.0, "Default homing strength")
	assert_true(b.is_player_bullet, "Should be player bullet by default")

func test_init_sets_position():
	var b = Bullet.new()
	add_child_autofree(b)
	b.init(Vector2(100, 200), Vector2.UP, true)
	assert_eq(b.global_position, Vector2(100, 200), "Position should be set")

func test_init_sets_direction():
	var b = Bullet.new()
	add_child_autofree(b)
	b.init(Vector2.ZERO, Vector2(1, 1), true)
	assert_eq(b.direction, Vector2(1, 1).normalized(), "Direction should be normalized")

func test_init_player_bullet():
	var b = Bullet.new()
	add_child_autofree(b)
	b.init(Vector2.ZERO, Vector2.UP, true)
	assert_true(b.is_player_bullet, "Should be player bullet")
	assert_eq(b.collision_mask, 2, "Player bullet mask should be 2")

func test_init_enemy_bullet():
	var b = Bullet.new()
	add_child_autofree(b)
	b.init(Vector2.ZERO, Vector2.UP, false)
	assert_false(b.is_player_bullet, "Should not be player bullet")
	assert_eq(b.collision_mask, 1, "Enemy bullet mask should be 1")
	assert_eq(b.direction, Vector2.DOWN, "Enemy bullet should face down")

func test_bullet_added_to_group():
	var b = Bullet.new()
	add_child_autofree(b)
	b._ready()
	assert_true(b.is_in_group("bullet"), "Should be in 'bullet' group")

func test_homing_finds_nearest():
	var b = Bullet.new()
	add_child_autofree(b)
	b.global_position = Vector2(0, 0)
	var near = Node2D.new()
	near.global_position = Vector2(10, 10)
	var far = Node2D.new()
	far.global_position = Vector2(100, 100)
	add_child_autofree(near)
	add_child_autofree(far)
	var result = b._find_nearest([near, far])
	assert_eq(result, near, "Should find nearest enemy")

func test_homing_ignores_invalid():
	var b = Bullet.new()
	add_child_autofree(b)
	b.global_position = Vector2(0, 0)
	var valid = Node2D.new()
	valid.global_position = Vector2(10, 10)
	var invalid = Node2D.new()
	invalid.queue_free()
	var result = b._find_nearest([invalid, valid])
	assert_eq(result, valid, "Should skip invalid enemies")

func test_homing_returns_null_for_empty():
	var b = Bullet.new()
	add_child_autofree(b)
	var result = b._find_nearest([])
	assert_null(result, "Should return null for empty array")

func test_move_process():
	var b = Bullet.new()
	add_child_autofree(b)
	b.init(Vector2(0, 0), Vector2.UP, true)
	b._process(1.0)
	assert_eq(b.position.y, -500.0, "Should move upward at speed")

func test_homing_adjusts_direction():
	var b = Bullet.new()
	add_child_autofree(b)
	b.homing_strength = 6.0
	b.global_position = Vector2(0, 0)
	var target = Node2D.new()
	target.global_position = Vector2(100, -100)
	add_child_autofree(target)
	var initial_dir = b.direction
	b._process(0.1)
	assert_ne(b.direction, initial_dir, "Direction should change with homing")

func test_die_releases_to_pool():
	var b = Bullet.new()
	add_child_autofree(b)
	ObjectPool.create_pool("test_bullet_die", preload("res://scenes/weapons/Bullet.tscn"), 1)
	b._die()
	assert_true(b.get_meta("_in_pool", true) or b.is_queued_for_deletion(), "Bullet should be released to pool or queued")

func test_homing_caches_enemies():
	var b = Bullet.new()
	add_child_autofree(b)
	b.homing_strength = 6.0
	b._cache_timer = 0.0
	b._cached_enemies = []
	b._process(0.3)
	assert_gt(b._cache_timer, 0.0, "Cache timer should advance")

func test_homing_does_not_query_every_frame():
	var b = Bullet.new()
	add_child_autofree(b)
	b.homing_strength = 6.0
	b._cache_timer = 0.1
	b._cached_enemies = []
	b._process(0.05)
	assert_lt(b._cache_timer, 0.25, "Should not refresh cache before interval")

func test_homing_refreshes_cache_after_interval():
	var b = Bullet.new()
	add_child_autofree(b)
	b.homing_strength = 6.0
	b._cache_timer = 0.2
	b._cached_enemies = []
	b._process(0.1)
	assert_eq(b._cache_timer, 0.05, "Cache timer should reset after interval")

func test_enemy_cache_interval_constant():
	var b = Bullet.new()
	assert_eq(b.ENEMY_CACHE_INTERVAL, 0.25, "Cache interval should be 0.25s")

func test_on_body_entered_emits_signal():
	var b = Bullet.new()
	add_child_autofree(b)
	watch_signals(b)
	var mock_body = Node2D.new()
	b._on_body_entered(mock_body)
	assert_signal_emitted(b, "hit_target", "Should emit hit_target signal")

func test_on_body_entered_damages_target():
	var b = Bullet.new()
	add_child_autofree(b)
	var damage_taken = 0
	var mock_body = Node2D.new()
	mock_body.set("take_damage", func(amount = 1): damage_taken = amount)
	b._on_body_entered(mock_body)
	assert_eq(damage_taken, 1, "Should deal damage to body")

func test_on_area_entered_emits_signal():
	var b = Bullet.new()
	add_child_autofree(b)
	watch_signals(b)
	var mock_area = Area2D.new()
	b._on_area_entered(mock_area)
	assert_signal_emitted(b, "hit_target", "Should emit hit_target signal")

func test_on_area_entered_damages_target():
	var b = Bullet.new()
	add_child_autofree(b)
	var damage_taken = 0
	var mock_area = Area2D.new()
	mock_area.set("take_damage", func(amount = 1): damage_taken = amount)
	b._on_area_entered(mock_area)
	assert_eq(damage_taken, 1, "Should deal damage to area")

func test_on_pool_release_resets_properties():
	var b = Bullet.new()
	add_child_autofree(b)
	b.homing_strength = 6.0
	b.damage = 3
	b.scale = Vector2(2.0, 2.0)
	b.modulate = Color.RED
	b._cached_enemies = [Node2D.new()]
	b._cache_timer = 0.5
	b.on_pool_release()
	assert_eq(b.homing_strength, 0.0, "Homing should reset")
	assert_eq(b.damage, 1, "Damage should reset")
	assert_eq(b.scale, Vector2.ONE, "Scale should reset")
	assert_eq(b.modulate, Color.WHITE, "Modulate should reset")
	assert_eq(b._cached_enemies.size(), 0, "Cache should clear")
	assert_eq(b._cache_timer, 0.0, "Cache timer should reset")
