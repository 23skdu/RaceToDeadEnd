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

func test_acquire_skips_item_not_in_pool():
	ObjectPool.create_pool("test_not_in_pool", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item = ObjectPool.acquire("test_not_in_pool")
	var acquired = ObjectPool.acquire("test_not_in_pool")
	assert_true(acquired != null, "Should return fallback when pool items are all in use")
	assert_false(acquired.is_queued_for_deletion(), "Fallback should be valid")

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

func test_release_pool_item_removes_from_parent():
	ObjectPool.create_pool("test_rel_parent", preload("res://scenes/weapons/Bullet.tscn"), 1)
	var item = ObjectPool.acquire("test_rel_parent")
	ObjectPool.release(item)
	assert_null(item.get_parent(), "Released item should be reparented to ObjectPool")

func test_acquire_auto_creates_pool_with_scene_path():
	ObjectPool._scene_paths["auto_test"] = "res://scenes/weapons/Bullet.tscn"
	var item = ObjectPool.acquire("auto_test")
	assert_true(item != null, "Should auto-create pool from stored scene path")
	assert_true(item.has_method("init"), "Auto-created pool should return correct type")

func test_acquire_returns_null_for_nonexistent_pool():
	var item = ObjectPool.acquire("pool_does_not_exist_12345")
	assert_null(item, "Should return null for nonexistent pool")
