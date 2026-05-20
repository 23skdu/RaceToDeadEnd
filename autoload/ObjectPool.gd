extends Node

var _pools: Dictionary = {}
var _scene_paths: Dictionary = {}

func create_pool(name: String, scene: PackedScene, initial_size: int) -> void:
	var pool = []
	_scene_paths[name] = scene.resource_path
	for i in initial_size:
		var instance = scene.instantiate()
		instance.set_meta("_pool_name", name)
		instance.set_meta("_in_pool", true)
		instance.visible = false
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(instance)
		pool.append(instance)
	_pools[name] = pool

func get(name: String) -> Node:
	if not _pools.has(name):
		push_warning("Pool '%s' does not exist" % name)
		return null
	var pool: Array = _pools[name]
	for item in pool:
		if item.get_meta("_in_pool", true):
			item.set_meta("_in_pool", false)
			item.visible = true
			item.process_mode = Node.PROCESS_MODE_INHERIT
			return item
	var fallback = load(_scene_paths[name]).instantiate()
	fallback.set_meta("_pool_name", name)
	fallback.set_meta("_in_pool", false)
	add_child(fallback)
	return fallback

func release(node: Node) -> void:
	var name = node.get_meta("_pool_name", null)
	if not name or not _pools.has(name):
		node.queue_free()
		return
	node.set_meta("_in_pool", true)
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.get_parent():
		node.get_parent().remove_child(node)
		_pools[name].append(node)
