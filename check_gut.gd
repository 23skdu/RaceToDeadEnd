extends SceneTree

func _init():
	# Reproduce GUT's _get_files logic exactly
	var path = "scripts/test/unit"
	var prefix = "test_"
	var suffix = ".gd"
	
	var files = []
	var d = DirAccess.open(path)
	if d == null:
		print("DirAccess.open failed")
		quit()
		return
	
	d.include_hidden = false
	d.include_navigational = false
	d.list_dir_begin()
	var fs_item = d.get_next()
	while fs_item != "":
		var full_path = path.path_join(fs_item)
		if FileAccess.file_exists(full_path):
			if fs_item.begins_with(prefix) and fs_item.ends_with(suffix):
				files.append(full_path)
		fs_item = d.get_next()
	d.list_dir_end()
	
	files.sort()
	
	print("Found ", files.size(), " files:")
	for f in files:
		print("  ", f)
	quit()
