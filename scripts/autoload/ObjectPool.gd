extends Node

var _pools: Dictionary = {}
var _scene_paths: Dictionary = {}
var _scene_cache: Dictionary = {}
var _pickup_pool_data: Dictionary = {}
var _pool_max_sizes: Dictionary = {}
var _pending_allocations: Array[Dictionary] = []

func create_pool(pool_name: String, scene: PackedScene, initial_size: int) -> void:
	if _pools.has(pool_name):
		for old_node in _pools[pool_name]:
			if is_instance_valid(old_node) and old_node.get_parent() != self:
				old_node.queue_free()
		for node in get_children():
			if node.has_meta("_pool_name") and node.get_meta("_pool_name") == pool_name:
				node.queue_free()
	
	# Clear pending allocations for this pool
	var i = _pending_allocations.size() - 1
	while i >= 0:
		if _pending_allocations[i].get("pool_name") == pool_name:
			_pending_allocations.remove_at(i)
		i -= 1

	var pool: Array[Node] = []
	_scene_paths[pool_name] = scene.resource_path
	_scene_cache[pool_name] = scene
	for _i in initial_size:
		var instance = scene.instantiate()
		instance.set_meta("_pool_name", pool_name)
		instance.set_meta("_in_pool", true)
		instance.visible = false
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(instance)
		pool.append(instance)
	_pools[pool_name] = pool
	_pool_max_sizes[pool_name] = initial_size

func create_pickup_pool(initial_size: int = 20) -> void:
	if _pools.has("pickup"):
		for old_node in _pools["pickup"]:
			if is_instance_valid(old_node) and old_node.get_parent() != self:
				old_node.queue_free()
		for node in get_children():
			if node.has_meta("_pool_name") and node.get_meta("_pool_name") == "pickup":
				node.queue_free()
	
	# Clear pending allocations for pickup
	var i = _pending_allocations.size() - 1
	while i >= 0:
		if _pending_allocations[i].get("pool_name") == "pickup":
			_pending_allocations.remove_at(i)
		i -= 1

	_scene_paths["pickup"] = ""
	var pool: Array[Node] = []
	for _i in initial_size:
		var pickup = _create_pickup_node()
		pickup.set_meta("_pool_name", "pickup")
		pickup.set_meta("_in_pool", true)
		pickup.visible = false
		pickup.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(pickup)
		pool.append(pickup)
	_pools["pickup"] = pool
	_pool_max_sizes["pickup"] = initial_size

func _create_pickup_node() -> Area2D:
	var pickup = Area2D.new()
	pickup.collision_layer = 0
	pickup.collision_mask = 1
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	col.shape = circle
	pickup.add_child(col)
	var visual = Polygon2D.new()
	var pts = []
	var segments = 8
	for i in segments:
		var angle = i * TAU / segments
		pts.append(Vector2(cos(angle) * 16.0, sin(angle) * 16.0))
	visual.polygon = PackedVector2Array(pts)
	pickup.add_child(visual)
	return pickup

func acquire_pickup(pickup_type: String, position: Vector2, on_collected: Callable) -> Area2D:
	if not _pools.has("pickup"):
		create_pickup_pool()
	var pool: Array[Node] = _pools["pickup"]
	while pool.size() > 0:
		var item = pool.pop_back()
		if not is_instance_valid(item):
			continue
		if not item.get_meta("_in_pool", true):
			continue
		item.set_meta("_in_pool", false)
		item.visible = true
		item.process_mode = Node.PROCESS_MODE_INHERIT
		item.global_position = position
		item.set_meta("_pickup_type", pickup_type)
		if not item.body_entered.is_connected(_on_pickup_body_entered):
			item.body_entered.connect(_on_pickup_body_entered.bind(item))
		_pickup_pool_data[item] = {"type": pickup_type, "callback": on_collected}
		var visual = _get_pickup_visual(item)
		if visual:
			match pickup_type:
				"repair": visual.color = Color(0.2, 1.0, 0.3)
				"ammo": visual.color = Color(1.0, 0.8, 0.2)
				"boost": visual.color = Color(0.2, 0.8, 1.0)
				"multiplier": visual.color = Color(1.0, 0.3, 1.0)
		if item.has_method("on_pool_acquire"):
			item.on_pool_acquire()
		if item.get_parent():
			item.get_parent().remove_child(item)
		_check_and_trigger_expansion("pickup")
		return item
	var fallback = _create_pickup_node()
	fallback.set_meta("_pool_name", "pickup")
	fallback.set_meta("_in_pool", false)
	fallback.global_position = position
	fallback.set_meta("_pickup_type", pickup_type)
	if not fallback.body_entered.is_connected(_on_pickup_body_entered):
		fallback.body_entered.connect(_on_pickup_body_entered.bind(fallback))
	var fb_visual = _get_pickup_visual(fallback)
	if fb_visual:
		match pickup_type:
			"repair": fb_visual.color = Color(0.2, 1.0, 0.3)
			"ammo": fb_visual.color = Color(1.0, 0.8, 0.2)
			"boost": fb_visual.color = Color(0.2, 0.8, 1.0)
			"multiplier": fb_visual.color = Color(1.0, 0.3, 1.0)
	_pickup_pool_data[fallback] = {"type": pickup_type, "callback": on_collected}
	_check_and_trigger_expansion("pickup")
	return fallback

func _get_pickup_visual(pickup: Area2D) -> Polygon2D:
	for child in pickup.get_children():
		if child is Polygon2D:
			return child as Polygon2D
	return null

func _on_pickup_body_entered(body: Node, pickup: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var data = _pickup_pool_data.get(pickup)
	if data:
		if data.has("callback") and data["callback"].is_valid():
			data["callback"].call(data["type"], pickup)
		_pickup_pool_data.erase(pickup)
	release(pickup)

func has_pool(pool_name: String) -> bool:
	return _pools.has(pool_name)

func acquire(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		if _scene_paths.has(pool_name):
			var pscene = load(_scene_paths[pool_name]) as PackedScene
			if pscene:
				create_pool(pool_name, pscene, 4)
				_scene_cache[pool_name] = pscene
			else:
				push_warning("Pool '%s' scene not found" % pool_name)
				return null
		else:
			push_warning("Pool '%s' does not exist" % pool_name)
			return null
	var pool: Array[Node] = _pools[pool_name]
	while pool.size() > 0:
		var item = pool.pop_back()
		if not is_instance_valid(item):
			continue
		if not item.get_meta("_in_pool", true):
			continue
		item.set_meta("_in_pool", false)
		item.visible = true
		item.process_mode = Node.PROCESS_MODE_INHERIT
		if item.has_method("on_pool_acquire"):
			item.on_pool_acquire()
		if item.get_parent():
			item.get_parent().remove_child(item)
		_check_and_trigger_expansion(pool_name)
		return item
	if not _scene_cache.has(pool_name):
		_scene_cache[pool_name] = load(_scene_paths[pool_name])
	var fallback = _scene_cache[pool_name].instantiate()
	fallback.set_meta("_pool_name", pool_name)
	fallback.set_meta("_in_pool", false)
	if fallback.has_method("on_pool_acquire"):
		fallback.on_pool_acquire()
	_check_and_trigger_expansion(pool_name)
	return fallback

func release(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var pool_name = null
	if node.has_meta("_pool_name"):
		pool_name = node.get_meta("_pool_name")
	if not pool_name or not _pools.has(pool_name):
		node.queue_free()
		return
	if node.get_meta("_in_pool", false):
		return
	if node.has_method("on_pool_release"):
		node.on_pool_release()
	_pickup_pool_data.erase(node)
	if node.has_signal("body_entered") and node.body_entered.is_connected(_on_pickup_body_entered):
		node.body_entered.disconnect(_on_pickup_body_entered)
	node.set_meta("_in_pool", true)
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.get_parent() and node.get_parent() != self:
		node.get_parent().remove_child(node)
	if node.get_parent() != self:
		add_child(node)
	_pools[pool_name].append(node)

func _check_and_trigger_expansion(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return
	var max_size = _pool_max_sizes.get(pool_name, 0)
	if max_size <= 0:
		return
	
	var pending_count = 0
	for alloc in _pending_allocations:
		if alloc.get("pool_name") == pool_name:
			pending_count += 1
			
	var current_available = _pools[pool_name].size() + pending_count
	var threshold = ceil(max_size * 0.2)
	if current_available < threshold:
		for i in 4:
			_pending_allocations.append({
				"pool_name": pool_name,
				"is_pickup": (pool_name == "pickup")
			})

func _process(_delta: float) -> void:
	if _pending_allocations.size() > 0:
		var alloc = _pending_allocations.pop_front()
		var pool_name = alloc.get("pool_name")
		var is_pickup = alloc.get("is_pickup", false)
		
		var node: Node = null
		if is_pickup:
			node = _create_pickup_node()
		else:
			if not _scene_cache.has(pool_name):
				if _scene_paths.has(pool_name) and _scene_paths[pool_name] != "":
					_scene_cache[pool_name] = load(_scene_paths[pool_name])
			if _scene_cache.has(pool_name) and _scene_cache[pool_name]:
				node = _scene_cache[pool_name].instantiate()
		
		if node:
			node.set_meta("_pool_name", pool_name)
			node.set_meta("_in_pool", true)
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
			add_child(node)
			if not _pools.has(pool_name):
				_pools[pool_name] = []
			_pools[pool_name].append(node)
			_pool_max_sizes[pool_name] = _pool_max_sizes.get(pool_name, 0) + 1

func _exit_tree() -> void:
	for pool_name in _pools:
		for node in _pools[pool_name]:
			if is_instance_valid(node) and node.get_parent() != self:
				node.queue_free()
	_pools.clear()
	_pickup_pool_data.clear()
	_pending_allocations.clear()

