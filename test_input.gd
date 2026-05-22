extends SceneTree
func _init():
	print("InputMap has 'accelerate': ", InputMap.has_action("accelerate"))
	Input.action_press("accelerate")
	print("is_action_pressed after press: ", Input.is_action_pressed("accelerate"))
	Input.action_release("accelerate")
	print("is_action_pressed after release: ", Input.is_action_pressed("accelerate"))
	Input.action_press("accelerate")
	print("is_action_pressed after press2: ", Input.is_action_pressed("accelerate"))
	quit()
