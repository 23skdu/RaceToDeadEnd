extends SceneTree
func _init():
	var r = ResourceLoader.load("res://scenes/weapons/Bullet.tscn")
	if r:
		print("Bullet.tscn loaded OK")
	else:
		print("Bullet.tscn FAILED to load")
	var r2 = ResourceLoader.load("res://scenes/weapons/Mine.tscn")
	if r2:
		print("Mine.tscn loaded OK")
	else:
		print("Mine.tscn FAILED to load")
	var r3 = ResourceLoader.load("res://scenes/weapons/EMPBlast.tscn")
	if r3:
		print("EMPBlast.tscn loaded OK")
	else:
		print("EMPBlast.tscn FAILED to load")
	quit()
