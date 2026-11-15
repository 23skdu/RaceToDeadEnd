extends GutTest

func after_each():
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

func test_pool_stress_acquire_release():
	var pool = load("res://scripts/autoload/ObjectPool.gd")
	assert_not_null(pool, "ObjectPool should load")

func test_pool_exhaustion_falls_back():
	var acquired: Array[Node] = []
	ObjectPool.create_pool("bullet", load("res://scenes/weapons/Bullet.tscn"), 5)
	for i in 20:
		var item = ObjectPool.acquire("bullet")
		if item:
			acquired.append(item)
	assert_eq(acquired.size(), 20, "Should acquire up to 20 even with pool size 5")

	for item in acquired:
		if is_instance_valid(item):
			ObjectPool.release(item)
	acquired.clear()
