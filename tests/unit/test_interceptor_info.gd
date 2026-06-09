extends GutTest

func test_interceptor_info_scene_exists():
	assert_true(ResourceLoader.exists("res://scenes/ui/InterceptorInfo.tscn"), "InterceptorInfo scene should exist")

func test_interceptor_info_script_exists():
	assert_true(ResourceLoader.exists("res://scripts/scenes/ui/InterceptorInfo.gd"), "InterceptorInfo script should exist")

func test_interceptor_info_has_back_signal():
	var scene = load("res://scenes/ui/InterceptorInfo.tscn").instantiate()
	add_child_autofree(scene)
	assert_true(scene.has_signal("back_to_menu_requested"), "Should have back_to_menu_requested signal")

func test_interceptor_info_back_emits_signal():
	var scene = load("res://scenes/ui/InterceptorInfo.tscn").instantiate()
	add_child_autofree(scene)
	watch_signals(scene)
	scene._on_back_pressed()
	assert_signal_emitted(scene, "back_to_menu_requested", "Back should emit signal")

func test_interceptor_info_has_back_button():
	var scene = load("res://scenes/ui/InterceptorInfo.tscn").instantiate()
	add_child_autofree(scene)
	assert_not_null(scene.get_node_or_null("Panel/BackButton"), "Should have BackButton")

func test_interceptor_info_back_button_connected():
	var scene = load("res://scenes/ui/InterceptorInfo.tscn").instantiate()
	add_child_autofree(scene)
	var btn = scene.get_node_or_null("Panel/BackButton")
	assert_not_null(btn, "BackButton should exist")
	if btn:
		assert_true(btn.pressed.is_connected(scene._on_back_pressed), "BackButton pressed should be connected")

func test_interceptor_info_instantiates_without_error():
	var scene = load("res://scenes/ui/InterceptorInfo.tscn").instantiate()
	add_child_autofree(scene)
	assert_not_null(scene, "Scene should instantiate without error")
