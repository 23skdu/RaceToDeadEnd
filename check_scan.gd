extends SceneTree

func _init():
	var path = "scripts/test/unit"
	var d = DirAccess.open(path)
	if d == null:
		print("DirAccess.open failed")
		quit()
		return
	
	d.include_hidden = false
	d.include_navigational = false
	d.list_dir_begin()
	var fs_item = d.get_next()
	var count = 0
	while fs_item != "":
		var full_path = path.path_join(fs_item)
		if FileAccess.file_exists(full_path):
			if fs_item.begins_with("test_") and fs_item.ends_with(".gd"):
				print("Found: ", full_path)
				count += 1
		fs_item = d.get_next()
	d.list_dir_end()
	print("Total: ", count)
	quit()
