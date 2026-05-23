extends Node

var _pools: Dictionary = {}
var _scene_paths: Dictionary = {}
var _pickup_pool_data: Dictionary = {}

func create_pool(pool_name: String, scene: PackedScene, initial_size: int) -> void:
	var pool: Array[Node] = []
	_scene_paths[pool_name] = scene.resource_path
	for _i in initial_size:
		var instance = scene.instantiate()
		instance.set_meta("_pool_name", pool_name)
		instance.set_meta("_in_pool", true)
		instance.visible = false
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(instance)
		pool.append(instance)
	_pools[pool_name] = pool

func create_pickup_pool(initial_size: int = 20) -> void:
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
	add_child(fallback)
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

func acquire(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		if _scene_paths.has(pool_name):
			var pscene = load(_scene_paths[pool_name]) as PackedScene
			if pscene:
				create_pool(pool_name, pscene, 4)
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
		return item
	var fallback = load(_scene_paths[pool_name]).instantiate()
	fallback.set_meta("_in_pool", false)
	add_child(fallback)
	return fallback

func release(node: Node) -> void:
	var pool_name = null
	if node.has_meta("_pool_name"):
		pool_name = node.get_meta("_pool_name")
	if not pool_name or not _pools.has(pool_name):
		node.queue_free()
		return
	if node.has_method("on_pool_release"):
		node.on_pool_release()
	_pickup_pool_data.erase(node)
	if node.has_signal("body_entered") and node.body_entered.is_connected(_on_pickup_body_entered):
		node.body_entered.disconnect(_on_pickup_body_entered)
	node.set_meta("_in_pool", true)
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.get_parent():
		node.get_parent().remove_child(node)
	_pools[pool_name].append(node)
