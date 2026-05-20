extends Node

var _pools: Dictionary = {}
var _scene_paths: Dictionary = {}

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

func acquire(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		push_warning("Pool '%s' does not exist" % pool_name)
		return null
	var pool: Array[Node] = _pools[pool_name]
	for item in pool:
		if item.get_meta("_in_pool", true):
			item.set_meta("_in_pool", false)
			item.visible = true
			item.process_mode = Node.PROCESS_MODE_INHERIT
			return item
	var fallback = load(_scene_paths[pool_name]).instantiate()
	fallback.set_meta("_pool_name", pool_name)
	fallback.set_meta("_in_pool", false)
	add_child(fallback)
	return fallback

func release(node: Node) -> void:
	var pool_name = node.get_meta("_pool_name", null)
	if not pool_name or not _pools.has(pool_name):
		node.queue_free()
		return
	node.set_meta("_in_pool", true)
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.get_parent():
		node.get_parent().remove_child(node)
		_pools[pool_name].append(node)
