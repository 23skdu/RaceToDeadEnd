extends SceneTree
func _init():
	# Register autoloads so scenes can load
	var autoloads = {
		"GameManager": "res://scripts/autoload/GameManager.gd",
		"ScoreManager": "res://scripts/autoload/ScoreManager.gd",
		"AudioManager": "res://scripts/autoload/AudioManager.gd",
		"Constants": "res://scripts/autoload/Constants.gd",
		"ObjectPool": "res://scripts/autoload/ObjectPool.gd",
		"PackManager": "res://scripts/autoload/PackManager.gd",
	}
	var root = get_root()
	for name in autoloads:
		var script = load(autoloads[name])
		if script:
			var inst = script.new()
			inst.name = name
			root.add_child(inst)
			Engine.register_singleton(name, inst)

	var scenes = [
		"res://scenes/weapons/Bullet.tscn",
		"res://scenes/weapons/Mine.tscn",
		"res://scenes/weapons/EMPBlast.tscn",
	]
	for path in scenes:
		var scene = load(path)
		if scene:
			var packed = scene as PackedScene
			if packed:
				var err = ResourceSaver.save(packed, path)
				if err == OK:
					print("Saved: ", path)
				else:
					print("FAILED to save: ", path, " err=", err)
			else:
				print("Not a PackedScene: ", path)
		else:
			print("Failed to load: ", path)
	quit()
