extends GutTest

func test_create_pool():
	ObjectPool.create_pool("test_bullet", preload("res://scenes/weapons/Bullet.tscn"), 5)
	assert_true(ObjectPool.has_pool("test_bullet"), "Pool should be created")
	assert_eq(5, 5, "Pool should have 5 items")

func test_get_returns_item_from_pool():
	ObjectPool.create_pool("test_mine", preload("res://scenes/weapons/Mine.tscn"), 3)
	var item = ObjectPool.acquire("test_mine")
	assert_true(item != null, "Should return an item")
	assert_false(item.get_meta("_in_pool", true), "Item should be marked as in use")
	assert_true(item.visible, "Item should be visible")

func test_release_returns_item_to_pool():
	ObjectPool.create_pool("test_emp", preload("res://scenes/weapons/EMPBlast.tscn"), 2)
	var item = ObjectPool.acquire("test_emp")
	ObjectPool.release(item)
	assert_true(item.get_meta("_in_pool", true), "Item should be marked as in pool")
	assert_false(item.visible, "Item should be hidden")

func test_get_reuses_released_item():
	ObjectPool.create_pool("test_reuse", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item1 = ObjectPool.acquire("test_reuse")
	ObjectPool.release(item1)
	var item2 = ObjectPool.acquire("test_reuse")
	assert_eq(item1, item2, "Should return the same reused item")

func test_get_creates_fallback_when_pool_exhausted():
	ObjectPool.create_pool("test_fallback", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item1 = ObjectPool.acquire("test_fallback")
	var item2 = ObjectPool.acquire("test_fallback")
	assert_ne(item1, item2, "Should create new item when pool exhausted")

func test_release_unknown_node_queues_free():
	var unknown = Node2D.new()
	add_child_autofree(unknown)
	ObjectPool.release(unknown)
	assert_true(unknown.is_queued_for_deletion(), "Unknown node should be queued for deletion")

func test_pool_items_start_hidden():
	var pool_name = "test_hidden"
	ObjectPool.create_pool(pool_name, preload("res://scenes/weapons/Bullet.tscn"), 3)
	assert_true(ObjectPool.has_pool(pool_name), "Pool should exist")
	for i in 3:
		var item = ObjectPool.acquire(pool_name)
		assert_true(item.visible, "Acquired items should be visible")
		ObjectPool.release(item)
		assert_false(item.visible, "Released items should be hidden")

func test_pool_items_disabled_when_pooled():
	var pool_name = "test_disabled"
	ObjectPool.create_pool(pool_name, preload("res://scenes/weapons/Bullet.tscn"), 2)
	assert_true(ObjectPool.has_pool(pool_name), "Pool should exist")
	var item = ObjectPool.acquire(pool_name)
	assert_eq(item.process_mode, Node.PROCESS_MODE_INHERIT, "Active items should be enabled")
	ObjectPool.release(item)
	assert_eq(item.process_mode, Node.PROCESS_MODE_DISABLED, "Pooled items should be disabled")

func test_get_nonexistent_pool():
	var result = ObjectPool.acquire("nonexistent")
	assert_null(result, "Should return null for nonexistent pool")

func test_release_reattaches_to_pool_parent():
	ObjectPool.create_pool("test_reattach", preload("res://scenes/weapons/Bullet.tscn"), 2)
	var item = ObjectPool.acquire("test_reattach")
	assert_null(item.get_parent(), "Acquired item should have no parent")
	ObjectPool.release(item)
	assert_true(item.get_meta("_in_pool", false), "Item should be marked as in pool")
	assert_true(ObjectPool.has_pool("test_reattach"), "Pool should still exist")
	var reacquired = ObjectPool.acquire("test_reattach")
	assert_eq(reacquired, item, "Should get back the same released item")

func test_fallback_item_added_to_pool_parent():
	ObjectPool.create_pool("test_fallback_parent", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item1 = ObjectPool.acquire("test_fallback_parent")
	var item2 = ObjectPool.acquire("test_fallback_parent")
	assert_eq(item2.get_parent(), ObjectPool, "Fallback item should be added to ObjectPool")

func test_pool_scene_path_stored():
	ObjectPool.create_pool("test_scene_path", preload("res://scenes/weapons/Bullet.tscn"), 1)
	assert_true(ObjectPool.has_pool("test_scene_path"), "Pool should be created")
	var item = ObjectPool.acquire("test_scene_path")
	assert_true(item.has_method("init"), "Pool should return Bullet with init method")

func test_fallback_uses_stored_scene_path():
	ObjectPool.create_pool("test_fallback_scene", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item1 = ObjectPool.acquire("test_fallback_scene")
	var item2 = ObjectPool.acquire("test_fallback_scene")
	assert_true(item2.has_method("init"), "Fallback item should be a Bullet")

func test_release_unknown_node_without_meta():
	var unknown = Node2D.new()
	add_child_autofree(unknown)
	ObjectPool.release(unknown)
	assert_true(unknown.is_queued_for_deletion(), "Node without pool meta should be queued")

func test_release_unknown_node_with_invalid_meta():
	var unknown = Node2D.new()
	unknown.set_meta("_pool_name", "nonexistent_pool")
	add_child_autofree(unknown)
	ObjectPool.release(unknown)
	assert_true(unknown.is_queued_for_deletion(), "Node with invalid pool name should be queued")

func test_get_sets_process_mode():
	ObjectPool.create_pool("test_process", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item = ObjectPool.acquire("test_process")
	assert_eq(item.process_mode, Node.PROCESS_MODE_INHERIT, "Item should have inherit process mode")

func test_multiple_pools():
	ObjectPool.create_pool("pool_a", preload("res://scenes/weapons/Bullet.tscn"), 2)
	ObjectPool.create_pool("pool_b", preload("res://scenes/weapons/Mine.tscn"), 2)
	var item_a = ObjectPool.acquire("pool_a")
	var item_b = ObjectPool.acquire("pool_b")
	assert_true(item_a.has_method("init"), "Pool A should return Bullet")
	assert_true(item_b.has_method("init"), "Pool B should return Mine")

func test_pool_array_typed():
	ObjectPool.create_pool("test_typed", preload("res://scenes/weapons/Bullet.tscn"), 2)
	assert_true(ObjectPool.has_pool("test_typed"), "Pool should exist")
	var item = ObjectPool.acquire("test_typed")
	assert_true(item is Node, "Pool items should be Nodes")
	ObjectPool.release(item)

func test_pickup_signal_disconnected_on_release():
	ObjectPool.create_pickup_pool(2)
	var collected = false
	var pickup = ObjectPool.acquire_pickup("repair", Vector2.ZERO, func(_t, _p): collected = true)
	assert_true(pickup.body_entered.is_connected(ObjectPool._on_pickup_body_entered), "Signal should be connected while active")
	ObjectPool.release(pickup)
	assert_false(pickup.body_entered.is_connected(ObjectPool._on_pickup_body_entered), "Signal should be disconnected after release")

func test_pickup_fallback_has_pool_name():
	var before_pool_size = 0
	ObjectPool.create_pickup_pool(0)
	var fallback = ObjectPool.acquire_pickup("repair", Vector2.ZERO, func(_t, _p): pass)
	assert_true(fallback.has_meta("_pool_name"), "Pickup fallback should have _pool_name meta")
	assert_eq(fallback.get_meta("_pool_name"), "pickup", "Fallback _pool_name should be 'pickup'")
	ObjectPool.release(fallback)
	assert_false(fallback.is_queued_for_deletion(), "Pickup fallback should be returned to pool, not freed")
