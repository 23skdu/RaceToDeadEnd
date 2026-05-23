extends GutTest

func test_transition_layer_exists():
	assert_true(TransitionLayer != null, "TransitionLayer autoload should exist")
	assert_true(TransitionLayer.has_method("fade_to_black"), "TransitionLayer should have fade_to_black")
	assert_true(TransitionLayer.has_method("fade_from_black"), "TransitionLayer should have fade_from_black")
	assert_true(TransitionLayer.has_method("change_scene"), "TransitionLayer should have change_scene")
	assert_true(TransitionLayer.has_method("reload_scene"), "TransitionLayer should have reload_scene")

func test_transition_layer_has_overlay():
	assert_gt(TransitionLayer.get_child_count(), 0, "Should have overlay child")
