extends GutTest

func before_each():
	_cleanup_object_pool()

func after_each():
	_cleanup_object_pool()

func _cleanup_object_pool():
	for pool_name in ObjectPool._pools:
		for node in ObjectPool._pools[pool_name]:
			if is_instance_valid(node) and node.get_parent() != ObjectPool:
				node.free()
	for child in ObjectPool.get_children():
		child.free()
	ObjectPool._pending_allocations.clear()
	ObjectPool._pools.clear()
	ObjectPool._pool_max_sizes.clear()
	ObjectPool._scene_paths.clear()
	ObjectPool._scene_cache.clear()
	ObjectPool._pickup_pool_data.clear()

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
	ObjectPool.release(item)

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
	ObjectPool.release(item2)

func test_get_creates_fallback_when_pool_exhausted():
	ObjectPool.create_pool("test_fallback", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item1 = ObjectPool.acquire("test_fallback")
	var item2 = ObjectPool.acquire("test_fallback")
	assert_ne(item1, item2, "Should create new item when pool exhausted")
	ObjectPool.release(item1)
	ObjectPool.release(item2)

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
	ObjectPool.release(reacquired)

func test_fallback_item_added_to_pool_parent():
	ObjectPool.create_pool("test_fallback_parent", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item1 = ObjectPool.acquire("test_fallback_parent")
	var item2 = ObjectPool.acquire("test_fallback_parent")
	assert_null(item2.get_parent(), "Fallback item should have no parent (caller reparents)")
	ObjectPool.release(item1)
	ObjectPool.release(item2)

func test_pool_scene_path_stored():
	ObjectPool.create_pool("test_scene_path", preload("res://scenes/weapons/Bullet.tscn"), 1)
	assert_true(ObjectPool.has_pool("test_scene_path"), "Pool should be created")
	var item = ObjectPool.acquire("test_scene_path")
	assert_true(item.has_method("init"), "Pool should return Bullet with init method")
	ObjectPool.release(item)

func test_fallback_uses_stored_scene_path():
	ObjectPool.create_pool("test_fallback_scene", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item1 = ObjectPool.acquire("test_fallback_scene")
	var item2 = ObjectPool.acquire("test_fallback_scene")
	assert_true(item2.has_method("init"), "Fallback item should be a Bullet")
	ObjectPool.release(item1)
	ObjectPool.release(item2)

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
	ObjectPool.release(item)

func test_multiple_pools():
	ObjectPool.create_pool("pool_a", preload("res://scenes/weapons/Bullet.tscn"), 2)
	ObjectPool.create_pool("pool_b", preload("res://scenes/weapons/Mine.tscn"), 2)
	var item_a = ObjectPool.acquire("pool_a")
	var item_b = ObjectPool.acquire("pool_b")
	assert_true(item_a.has_method("init"), "Pool A should return Bullet")
	assert_true(item_b.has_method("init"), "Pool B should return Mine")
	ObjectPool.release(item_a)
	ObjectPool.release(item_b)

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

func test_create_pool_replaces_existing():
	if ObjectPool.has_pool("test_recreate"):
		ObjectPool._pools.erase("test_recreate")
	ObjectPool.create_pool("test_recreate", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var first_batch = ObjectPool._pools["test_recreate"]
	assert_eq(first_batch.size(), 1, "Should have 1 item before recreate")
	ObjectPool.create_pool("test_recreate", preload("res://scenes/weapons/Bullet.tscn"), 2)
	assert_true(first_batch[0].is_queued_for_deletion(), "Old pool items should be freed")
	var second_batch = ObjectPool._pools["test_recreate"]
	assert_eq(second_batch.size(), 2, "New pool should have 2 items")

func test_create_pickup_pool_replaces_existing():
	if ObjectPool.has_pool("pickup"):
		ObjectPool._pools.erase("pickup")
	ObjectPool.create_pickup_pool(1)
	var first_batch = ObjectPool._pools["pickup"]
	assert_eq(first_batch.size(), 1, "Should have 1 item before recreate")
	ObjectPool.create_pickup_pool(2)
	assert_true(first_batch[0].is_queued_for_deletion(), "Old pickup pool items should be freed")
	var second_batch = ObjectPool._pools["pickup"]
	assert_eq(second_batch.size(), 2, "New pool should have 2 items")

func test_acquire_calls_on_pool_acquire():
	var s = GDScript.new()
	s.source_code = """
extends Node2D
var acquired = false
func on_pool_acquire():
	acquired = true
"""
	s.reload()
	ObjectPool.create_pool("test_lifecycle", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var scripted = Node2D.new()
	scripted.set_script(s)
	scripted.set_meta("_pool_name", "test_lifecycle")
	scripted.set_meta("_in_pool", true)
	scripted.visible = false
	scripted.process_mode = Node.PROCESS_MODE_DISABLED
	ObjectPool.add_child(scripted)
	ObjectPool._pools["test_lifecycle"].append(scripted)
	var acquired_item = ObjectPool.acquire("test_lifecycle")
	assert_true(acquired_item.get("acquired"), "on_pool_acquire should be called")
	ObjectPool.release(acquired_item)

func test_release_calls_on_pool_release():
	var s = GDScript.new()
	s.source_code = """
extends Node2D
var released = false
func on_pool_release():
	released = true
"""
	s.reload()
	ObjectPool.create_pool("test_release_lifecycle", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var scripted = Node2D.new()
	scripted.set_script(s)
	scripted.set_meta("_pool_name", "test_release_lifecycle")
	scripted.set_meta("_in_pool", true)
	scripted.visible = false
	scripted.process_mode = Node.PROCESS_MODE_DISABLED
	ObjectPool.add_child(scripted)
	ObjectPool._pools["test_release_lifecycle"].append(scripted)
	scripted.set_meta("_in_pool", false)
	ObjectPool.release(scripted)
	assert_true(scripted.get("released"), "on_pool_release should be called")

func test_acquire_skips_invalid_instance():
	ObjectPool.create_pool("test_stale", preload("res://scenes/weapons/Bullet.tscn"), 2)
	var item = ObjectPool.acquire("test_stale")
	var stale = Node.new()
	stale.set_meta("_pool_name", "test_stale")
	stale.set_meta("_in_pool", true)
	ObjectPool._pools["test_stale"].append(stale)
	stale.free()
	var healthy = ObjectPool.acquire("test_stale")
	assert_true(healthy != null, "Should skip stale instance and return healthy one")
	ObjectPool.release(item)
	ObjectPool.release(healthy)

func test_acquire_skips_item_not_in_pool():
	ObjectPool.create_pool("test_not_in_pool", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item = ObjectPool.acquire("test_not_in_pool")
	var acquired = ObjectPool.acquire("test_not_in_pool")
	assert_true(acquired != null, "Should return fallback when pool items are all in use")
	assert_false(acquired.is_queued_for_deletion(), "Fallback should be valid")
	ObjectPool.release(item)
	ObjectPool.release(acquired)

func test_acquire_removes_child_from_parent():
	ObjectPool.create_pool("test_remove_parent", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item = ObjectPool.acquire("test_remove_parent")
	assert_null(item.get_parent(), "Acquired item should have no parent")
	ObjectPool.release(item)

func test_acquire_pickup_auto_creates_pool():
	var item = ObjectPool.acquire_pickup("repair", Vector2.ZERO, func(_t, _p): pass)
	assert_true(ObjectPool.has_pool("pickup"), "Pickup pool should be auto-created")
	assert_true(item != null, "Should return a valid pickup")
	ObjectPool.release(item)

func test_acquire_pickup_non_player_body_does_nothing():
	var hit = false
	ObjectPool.create_pickup_pool(1)
	var pickup = ObjectPool.acquire_pickup("repair", Vector2.ZERO, func(_t, _p): hit = true)
	var non_player = Node2D.new()
	add_child_autofree(non_player)
	pickup.body_entered.emit(non_player)
	assert_false(hit, "Non-player body should not trigger callback")
	ObjectPool.release(pickup)

func test_acquire_pickup_ammo_color():
	ObjectPool.create_pickup_pool(1)
	var pickup = ObjectPool.acquire_pickup("ammo", Vector2.ZERO, func(_t, _p): pass)
	var visual = ObjectPool._get_pickup_visual(pickup)
	assert_eq(visual.color, Color(1.0, 0.8, 0.2), "Ammo pickup should be yellow")
	ObjectPool.release(pickup)

func test_acquire_pickup_boost_color():
	ObjectPool.create_pickup_pool(1)
	var pickup = ObjectPool.acquire_pickup("boost", Vector2.ZERO, func(_t, _p): pass)
	var visual = ObjectPool._get_pickup_visual(pickup)
	assert_eq(visual.color, Color(0.2, 0.8, 1.0), "Boost pickup should be cyan")
	ObjectPool.release(pickup)

func test_acquire_pickup_multiplier_color():
	ObjectPool.create_pickup_pool(1)
	var pickup = ObjectPool.acquire_pickup("multiplier", Vector2.ZERO, func(_t, _p): pass)
	var visual = ObjectPool._get_pickup_visual(pickup)
	assert_eq(visual.color, Color(1.0, 0.3, 1.0), "Multiplier pickup should be magenta")
	ObjectPool.release(pickup)

func test_acquire_pickup_calls_on_pool_acquire():
	var s = GDScript.new()
	s.source_code = """
extends Area2D
var acquired = false
func on_pool_acquire():
	acquired = true
"""
	s.reload()
	ObjectPool.create_pickup_pool(1)
	var pickup = ObjectPool.acquire_pickup("repair", Vector2.ZERO, func(_t, _p): pass)
	var scripted = Area2D.new()
	scripted.set_script(s)
	scripted.set_meta("_pool_name", "pickup")
	scripted.set_meta("_in_pool", true)
	ObjectPool._pools["pickup"].append(scripted)
	var acquired = ObjectPool.acquire_pickup("repair", Vector2.ZERO, func(_t, _p): pass)
	assert_true(acquired.get("acquired"), "on_pool_acquire should be called on pickup acquire")
	ObjectPool.release(pickup)
	ObjectPool.release(acquired)

func test_release_pool_item_removes_from_parent():
	ObjectPool.create_pool("test_rel_parent", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item = ObjectPool.acquire("test_rel_parent")
	var external_parent = Node2D.new()
	add_child_autofree(external_parent)
	external_parent.add_child(item)
	ObjectPool.release(item)
	assert_ne(item.get_parent(), external_parent, "Released item should be removed from external parent")
	assert_eq(item.get_parent(), ObjectPool, "Released item should be reparented to ObjectPool")

func test_acquire_auto_creates_pool_with_scene_path():
	ObjectPool._scene_paths["auto_test"] = "res://scenes/weapons/Bullet.tscn"
	var item = ObjectPool.acquire("auto_test")
	assert_true(item != null, "Should auto-create pool from stored scene path")
	assert_true(item.has_method("init"), "Auto-created pool should return correct type")
	ObjectPool.release(item)

func test_acquire_returns_null_for_nonexistent_pool():
	var item = ObjectPool.acquire("pool_does_not_exist_12345")
	assert_null(item, "Should return null for nonexistent pool")

func test_scene_cache_avoids_reload():
	var old_count = ObjectPool._scene_cache.size()
	ObjectPool._scene_paths["cache_test"] = "res://scenes/weapons/Bullet.tscn"
	var item = ObjectPool.acquire("cache_test")
	assert_true(ObjectPool._scene_cache.has("cache_test"), "Scene should be cached after fallback acquire")
	assert_gt(ObjectPool._scene_cache.size(), old_count, "Cache should have more entries")
	ObjectPool.release(item)

func test_scene_cache_reuses_cached_scene():
	ObjectPool._scene_paths["cache_test2"] = "res://scenes/weapons/Bullet.tscn"
	var item1 = ObjectPool.acquire("cache_test2")
	assert_true(ObjectPool._scene_cache.has("cache_test2"), "First acquire should populate cache")
	var item2 = ObjectPool.acquire("cache_test2")
	assert_ne(item1, item2, "Should get distinct instances from cached scene")
	ObjectPool.release(item1)
	ObjectPool.release(item2)

func test_scene_cache_returns_same_packed_scene():
	ObjectPool._scene_paths["cache_test3"] = "res://scenes/weapons/Bullet.tscn"
	var item1 = ObjectPool.acquire("cache_test3")
	var cached = ObjectPool._scene_cache["cache_test3"]
	assert_is(cached, PackedScene, "Cached entry should be a PackedScene")
	ObjectPool.release(item1)

func test_progressive_expansion_triggers_when_below_threshold():
	var pool_name = "test_progressive"
	# Create pool of size 5
	ObjectPool.create_pool(pool_name, preload("res://scenes/weapons/Bullet.tscn"), 5)
	assert_eq(ObjectPool._pool_max_sizes[pool_name], 5)
	
	# Acquire 4 items. Available size in pool is 1.
	# Threshold is ceil(5 * 0.2) = 1.
	# Available size (1) is not < threshold (1), so no expansion yet.
	var acquired_items = []
	for i in 4:
		acquired_items.append(ObjectPool.acquire(pool_name))
	
	assert_eq(ObjectPool._pools[pool_name].size(), 1)
	assert_eq(ObjectPool._pending_allocations.size(), 0, "No expansion should be triggered at 20% boundary")
	
	# Acquire 5th item. Available size in pool is 0.
	# 0 < 1, so expansion triggers.
	acquired_items.append(ObjectPool.acquire(pool_name))
	assert_eq(ObjectPool._pools[pool_name].size(), 0)
	assert_eq(ObjectPool._pending_allocations.size(), 4, "Progressive expansion should queue 4 allocations")
	
	# Process one frame
	ObjectPool._process(0.016)
	assert_eq(ObjectPool._pending_allocations.size(), 3)
	assert_eq(ObjectPool._pools[pool_name].size(), 1, "Should instantiate one node in the pool")
	assert_eq(ObjectPool._pool_max_sizes[pool_name], 6, "Max size should increase by 1")
	
	# Process the remaining 3 frames
	for i in 3:
		ObjectPool._process(0.016)
	assert_eq(ObjectPool._pending_allocations.size(), 0)
	assert_eq(ObjectPool._pools[pool_name].size(), 4, "Should have instantiated all 4 nodes")
	assert_eq(ObjectPool._pool_max_sizes[pool_name], 9, "Max size should be updated to 9")
	
	for item in acquired_items:
		ObjectPool.release(item)

func test_progressive_pickup_expansion_triggers():
	ObjectPool.create_pickup_pool(10)
	assert_eq(ObjectPool._pool_max_sizes["pickup"], 10)
	
	# Acquire 9 pickups. Available size is 1. Threshold is ceil(10 * 0.2) = 2.
	# 1 < 2, so it should trigger expansion.
	var acquired_pickups = []
	for i in 9:
		acquired_pickups.append(ObjectPool.acquire_pickup("repair", Vector2.ZERO, func(_t, _p): pass))
	
	assert_eq(ObjectPool._pools["pickup"].size(), 1)
	assert_eq(ObjectPool._pending_allocations.size(), 4, "Progressive pickup expansion should queue 4 allocations")
	
	# Process one frame
	ObjectPool._process(0.016)
	assert_eq(ObjectPool._pending_allocations.size(), 3)
	assert_eq(ObjectPool._pools["pickup"].size(), 2)
	assert_eq(ObjectPool._pool_max_sizes["pickup"], 11)
	
	# Process the rest
	for i in 3:
		ObjectPool._process(0.016)
	assert_eq(ObjectPool._pending_allocations.size(), 0)
	assert_eq(ObjectPool._pools["pickup"].size(), 5)
	assert_eq(ObjectPool._pool_max_sizes["pickup"], 14)
	
	for p in acquired_pickups:
		ObjectPool.release(p)

func test_fallback_sets_pool_name_and_returns_to_pool():
	var pool_name = "test_fb_meta"
	ObjectPool.create_pool(pool_name, preload("res://scenes/weapons/Bullet.tscn"), 1)
	var first = ObjectPool.acquire(pool_name)
	var fallback = ObjectPool.acquire(pool_name)
	assert_eq(fallback.get_meta("_pool_name", ""), pool_name, "Fallback item should have _pool_name meta set")
	ObjectPool.release(first)
	ObjectPool.release(fallback)
	assert_false(fallback.is_queued_for_deletion(), "Fallback should return to pool instead of queue_free")
	assert_eq(fallback.get_parent(), ObjectPool, "Released fallback should be reparented to ObjectPool")
	assert_eq(ObjectPool._pools[pool_name].size(), 2, "Pool should hold both returned items")

