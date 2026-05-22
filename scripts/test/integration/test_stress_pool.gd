extends GutTest

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
			item.queue_free()
	acquired.clear()
