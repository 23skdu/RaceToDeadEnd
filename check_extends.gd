extends SceneTree

var test_path = "res://addons/gut/test.gd"

func _does_inherit_from_test(thing):
	var base_script = thing.get_base_script()
	var to_return = false
	if base_script != null:
		var base_path = base_script.get_path()
		if base_path == test_path:
			to_return = true
		else:
			to_return = _does_inherit_from_test(base_script)
	return to_return

func _init():
	var path = "scripts/test/unit"
	var prefix = "test_"
	var suffix = ".gd"
	
	var d = DirAccess.open(path)
	d.include_hidden = false
	d.include_navigational = false
	d.list_dir_begin()
	var fs_item = d.get_next()
	while fs_item != "":
		var full_path = path.path_join(fs_item)
		if FileAccess.file_exists(full_path):
			if fs_item.begins_with(prefix) and fs_item.ends_with(suffix):
				var res_path = "res://" + full_path
				var loaded = load(res_path)
				if loaded:
					var inherits = _does_inherit_from_test(loaded)
					print(fs_item, " -> inherits: ", inherits)
				else:
					print(fs_item, " -> FAILED TO LOAD")
		fs_item = d.get_next()
	d.list_dir_end()
	quit()
