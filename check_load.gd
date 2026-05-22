func _init():
	var s = load("res://scripts/test/unit/test_spawner.gd")
	if s:
		var base = s.get_base_script()
		if base:
			print("Loaded: ", s.resource_path, " extends: ", base.resource_path)
		else:
			print("Loaded: ", s.resource_path, " extends: (no base)")
	else:
		print("Failed to load")
	quit()
