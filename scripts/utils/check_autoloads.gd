extends SceneTree
func _init():
	var root = get_root()
	for c in root.get_children():
		print("  Child: ", c.name, " ", c)
	for name in ["GameManager", "ObjectPool", "AudioManager", "Constants"]:
		var s = Engine.get_singleton(name)
		print("Singleton ", name, ": ", s)
	quit()
