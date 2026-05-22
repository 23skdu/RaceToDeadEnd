extends SceneTree
func _init():
	var classes = ClassDB.get_class_list()
	for c in classes:
		if "log" in c.to_lower():
			print("Found: ", c)
	# Also check specific names
	for name in ["Logger", "FileLogger", "EditorLogger", "EngineLogger"]:
		print(name, " exists: ", ClassDB.class_exists(name))
	quit()
