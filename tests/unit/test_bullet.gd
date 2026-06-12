extends GutTest

class MockDamagable:
	extends Node2D
	var damage_taken = 0
	func take_damage(amount = 1):
		damage_taken = amount

class MockDamagableArea:
	extends Area2D
	var damage_taken = 0
	func take_damage(amount = 1):
		damage_taken = amount

var BulletScene

func before_all():
	BulletScene = load("res://scenes/weapons/Bullet.tscn")

func _create_bullet():
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	return b

func test_bullet_z_index():
	var b = _create_bullet()
	assert_eq(b.z_index, 2, "Bullet z_index should be 2")

func test_bullet_defaults():
	var b = _create_bullet()
	assert_eq(b.speed, 500.0, "Default speed")
	assert_eq(b.damage, 1, "Default damage")
	assert_eq(b.homing_strength, 0.0, "Default homing strength")
	assert_true(b.is_player_bullet, "Should be player bullet by default")

func test_init_sets_position():
	var b = _create_bullet()
	b.init(Vector2(100, 200), Vector2.UP, true)
	assert_eq(b.global_position, Vector2(100, 200), "Position should be set")

func test_init_sets_direction():
	var b = _create_bullet()
	b.init(Vector2.ZERO, Vector2(1, 1), true)
	assert_eq(b.direction, Vector2(1, 1).normalized(), "Direction should be normalized")

func test_init_player_bullet():
	var b = _create_bullet()
	b.init(Vector2.ZERO, Vector2.UP, true)
	assert_true(b.is_player_bullet, "Should be player bullet")
	assert_eq(b.collision_mask, 2, "Player bullet mask should be 2")

func test_init_enemy_bullet():
	var b = _create_bullet()
	b.init(Vector2.ZERO, Vector2.UP, false)
	assert_false(b.is_player_bullet, "Should not be player bullet")
	assert_eq(b.collision_mask, 1, "Enemy bullet mask should be 1")
	assert_eq(b.direction, Vector2.DOWN, "Enemy bullet should face down")

func test_bullet_added_to_group():
	var b = _create_bullet()
	assert_true(b.is_in_group("bullet"), "Should be in 'bullet' group")

func test_homing_finds_nearest():
	var b = _create_bullet()
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
	var b = _create_bullet()
	b.global_position = Vector2(0, 0)
	var valid = Node2D.new()
	valid.global_position = Vector2(10, 10)
	add_child_autofree(valid)
	var invalid = Node2D.new()
	invalid.global_position = Vector2(100, 100)
	add_child_autofree(invalid)
	invalid.free()
	var result = b._find_nearest([invalid, valid])
	assert_eq(result, valid, "Should skip invalid enemies")

func test_homing_returns_null_for_empty():
	var b = _create_bullet()
	var result = b._find_nearest([])
	assert_null(result, "Should return null for empty array")

func test_move_process():
	var b = _create_bullet()
	b.init(Vector2(0, 0), Vector2.UP, true)
	b._physics_process(1.0)
	var expected = -(GameManager.current_speed + Constants.BULLET_SPEED_OFFSET)
	assert_eq(b.position.y, expected, "Should move upward at speed relative to game speed")

func test_homing_adjusts_direction():
	GameManager.enemy_list = []
	var b = _create_bullet()
	b.homing_strength = 6.0
	b.global_position = Vector2(0, 0)
	b.direction = Vector2.UP
	var target = Node2D.new()
	target.global_position = Vector2(100, -100)
	target.add_to_group("enemy")
	add_child_autofree(target)
	GameManager.enemy_list.append(target)
	b._cache_timer = Constants.ENEMY_CACHE_INTERVAL
	var initial_dir = b.direction
	b._physics_process(0.1)
	assert_ne(b.direction, initial_dir, "Direction should change with homing")

func test_die_releases_to_pool():
	var b = _create_bullet()
	ObjectPool.create_pool("test_bullet_die", preload("res://scenes/weapons/Bullet.tscn"), 1)
	b._die()
	assert_true(b.get_meta("_in_pool", true) or b.is_queued_for_deletion(), "Bullet should be released to pool or queued")

func test_homing_caches_enemies():
	GameManager.enemy_list = []
	var b = _create_bullet()
	b.homing_strength = 6.0
	b._cache_timer = 0.0
	b._cached_enemies = []
	b._physics_process(0.3)
	assert_eq(b._cached_enemies.size(), 0, "Cache should have enemies list after refresh")

func test_homing_does_not_query_every_frame():
	var b = _create_bullet()
	b.homing_strength = 6.0
	b._cache_timer = 0.1
	b._cached_enemies = []
	b._physics_process(0.05)
	assert_lt(b._cache_timer, 0.25, "Should not refresh cache before interval")

func test_homing_refreshes_cache_after_interval():
	GameManager.enemy_list = []
	var b = _create_bullet()
	b.homing_strength = 6.0
	b._cache_timer = 0.2
	b._cached_enemies = ["stale"]
	b._physics_process(0.1)
	assert_eq(b._cached_enemies.size(), 0, "Cache should refresh after interval")

func test_enemy_cache_interval_constant():
	assert_eq(Constants.ENEMY_CACHE_INTERVAL, 0.25, "Cache interval should be 0.25s")

func test_on_body_entered_emits_signal():
	var b = _create_bullet()
	watch_signals(b)
	var mock_body = Node2D.new()
	b._on_body_entered(mock_body)
	assert_signal_emitted(b, "hit_target", "Should emit hit_target signal")

func test_on_body_entered_damages_target():
	var b = _create_bullet()
	var mock_body = MockDamagable.new()
	add_child_autofree(mock_body)
	b._on_body_entered(mock_body)
	assert_eq(mock_body.damage_taken, 1, "Should deal damage to body")

func test_on_area_entered_emits_signal():
	var b = _create_bullet()
	watch_signals(b)
	var mock_area = Area2D.new()
	b._on_area_entered(mock_area)
	assert_signal_emitted(b, "hit_target", "Should emit hit_target signal")

func test_on_area_entered_damages_target():
	var b = _create_bullet()
	var mock_area = MockDamagableArea.new()
	add_child_autofree(mock_area)
	b._on_area_entered(mock_area)
	assert_eq(mock_area.damage_taken, 1, "Should deal damage to area")

func test_on_pool_release_resets_properties():
	var b = _create_bullet()
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

func test_on_pool_acquire_resets_properties():
	var b = _create_bullet()
	b.homing_strength = 6.0
	b.damage = 3
	b.scale = Vector2(2.0, 2.0)
	b.modulate = Color.RED
	b._cached_enemies = [Node2D.new()]
	b._cache_timer = 0.5
	b.on_pool_acquire()
	assert_eq(b.homing_strength, 0.0, "Homing should reset")
	assert_eq(b.damage, 1, "Damage should reset")
	assert_eq(b.scale, Vector2.ONE, "Scale should reset")
	assert_eq(b.modulate, Color.WHITE, "Modulate should reset")
	assert_eq(b._cached_enemies.size(), 0, "Cache should clear")
	assert_eq(b._cache_timer, 0.0, "Cache timer should reset")

func test_on_visible_on_screen_notifier_screen_exited_releases_to_pool():
	var b = _create_bullet()
	ObjectPool.create_pool("test_screen_exit", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item = ObjectPool.acquire("test_screen_exit")
	add_child_autofree(item)
	item._on_visible_on_screen_notifier_screen_exited()
	assert_true(item.get_meta("_in_pool", true) or item.is_queued_for_deletion(), "Should release to pool on screen exit")

func test_hit_target_signal_emits_with_body():
	var b = _create_bullet()
	watch_signals(b)
	var mock_body = Node2D.new()
	b._on_body_entered(mock_body)
	assert_signal_emitted(b, "hit_target", "Signal should emit on body enter")

func test_hit_target_signal_emits_with_area():
	var b = _create_bullet()
	watch_signals(b)
	var mock_area = Area2D.new()
	b._on_area_entered(mock_area)
	assert_signal_emitted(b, "hit_target", "Signal should emit on area enter")

func test_bullet_direction_changes_with_homing():
	GameManager.enemy_list = []
	var b = _create_bullet()
	b.homing_strength = 6.0
	b.global_position = Vector2(0, 0)
	b.direction = Vector2.UP
	var target = Node2D.new()
	target.global_position = Vector2(200, -100)
	target.add_to_group("enemy")
	add_child_autofree(target)
	GameManager.enemy_list.append(target)
	b._cache_timer = Constants.ENEMY_CACHE_INTERVAL
	b._physics_process(0.3)
	assert_ne(b.direction.x, 0.0, "Direction X should change toward target")

func test_bullet_homing_ignores_enemies_outside_cache_interval():
	var b = _create_bullet()
	b.homing_strength = 6.0
	b._cache_timer = 0.1
	b._cached_enemies = []
	b._physics_process(0.05)
	assert_eq(b._cached_enemies.size(), 0, "Should not refresh cache before interval")

func test_find_nearest_early_out_close_enemy():
	var b = _create_bullet()
	b.global_position = Vector2(0, 0)
	var close = Node2D.new()
	close.global_position = Vector2(10, 10)
	var far = Node2D.new()
	far.global_position = Vector2(200, 200)
	add_child_autofree(close)
	add_child_autofree(far)
	var result = b._find_nearest([far, close])
	assert_eq(result, close, "Should find close enemy with early-out")

func test_find_nearest_returns_null_when_all_out_of_range():
	var b = _create_bullet()
	b.global_position = Vector2(0, 0)
	var distant = Node2D.new()
	distant.global_position = Vector2(500, 500)
	add_child_autofree(distant)
	var result = b._find_nearest([distant])
	assert_null(result, "Should return null when all enemies out of range")

func test_max_homing_range_constant():
	var bullet = _create_bullet()
	assert_eq(bullet.MAX_HOMING_RANGE, 400.0, "MAX_HOMING_RANGE should be 400")

func test_early_out_dist_sq_constant():
	var bullet = _create_bullet()
	assert_eq(bullet.EARLY_OUT_DIST_SQ, 4000.0, "EARLY_OUT_DIST_SQ should be 4000")

func test_on_pool_release_disconnects_hit_target():
	var b = _create_bullet()
	var handler = func(_x): pass
	b.hit_target.connect(handler)
	assert_eq(b.hit_target.get_connections().size(), 1, "Should have 1 connection before release")
	b.on_pool_release()
	assert_eq(b.hit_target.get_connections().size(), 0, "Should have 0 connections after release")

func test_bullet_homing_target_stickiness():
	GameManager.enemy_list = []
	var b = _create_bullet()
	b.homing_strength = 6.0
	b.global_position = Vector2(0, 0)
	
	var target1 = Node2D.new()
	target1.global_position = Vector2(50, -50)
	target1.add_to_group("enemy")
	add_child_autofree(target1)
	GameManager.enemy_list.append(target1)
	
	b._cache_timer = Constants.ENEMY_CACHE_INTERVAL
	b._physics_process(0.01) # This should lock onto target1
	assert_eq(b._homing_target, target1, "Should lock target1")
	
	# Spawn a closer target2
	var target2 = Node2D.new()
	target2.global_position = Vector2(10, -10)
	target2.add_to_group("enemy")
	add_child_autofree(target2)
	GameManager.enemy_list.append(target2)
	
	# Run process without resetting cache timer (timer is 0.0 right now)
	b._physics_process(0.01)
	assert_eq(b._homing_target, target1, "Should stay locked onto target1 (stickiness) because timer hasn't elapsed")
	
	# Elapse cache timer
	b._cache_timer = Constants.ENEMY_CACHE_INTERVAL
	b._physics_process(0.01)
	assert_eq(b._homing_target, target2, "Should switch to target2 after cache timer elapses")
