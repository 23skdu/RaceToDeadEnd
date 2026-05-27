extends SceneTree

var _gut = null

func _init() -> void:
	var autoloads = {
		"GameManager": "res://scripts/autoload/GameManager.gd",
		"ScoreManager": "res://scripts/autoload/ScoreManager.gd",
		"AudioManager": "res://scripts/autoload/AudioManager.gd",
		"Constants": "res://scripts/autoload/Constants.gd",
		"ObjectPool": "res://scripts/autoload/ObjectPool.gd",
		"PackManager": "res://scripts/autoload/PackManager.gd",
		"CameraShake": "res://scripts/autoload/CameraShake.gd",
		"TransitionLayer": "res://scripts/autoload/TransitionLayer.gd",
		"SettingsManager": "res://scripts/autoload/SettingsManager.gd",
	}
	for name in autoloads:
		var path = autoloads[name]
		var script = load(path)
		var node = Node.new()
		node.set_script(script)
		node.name = name
		root.add_child(node)
	var GUT = load("res://addons/gut/gut.gd")
	_gut = GUT.new()
	_gut.add_directory("res://tests/unit")
	_gut.add_directory("res://tests/integration")
	_gut.pause_before_teardown = false
	_gut.disable_colors = true
	_gut.show_expecteds = true
	_gut.should_exit = true
	_gut.compact_mode = true
	root.add_child(_gut)
	call_deferred("_run")

func _run() -> void:
	await process_frame
	_gut.test_the_scripts()
