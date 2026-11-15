extends GutTest

const DemoSceneScript = preload("res://demo/DemoScene.gd")
const DemoBunnyScene = preload("res://demo/DemoBossBunny.tscn")
const DemoGiantBikerScene = preload("res://demo/DemoBossGiantBiker.tscn")
const DemoVoidScene = preload("res://demo/DemoBossVoidDrone.tscn")
const DemoWarScene = preload("res://demo/DemoBossWarRig.tscn")

func test_demo_scenes_instantiate_and_set_process_mode() -> void:
	for scene in [DemoBunnyScene, DemoGiantBikerScene, DemoVoidScene, DemoWarScene]:
		var inst = scene.instantiate()
		add_child_autofree(inst)
		assert_eq(inst.process_mode, Node.PROCESS_MODE_ALWAYS, "DemoScene must process while paused")
		assert_true(inst.has_signal("demo_finished"))
		assert_not_null(inst.get_node_or_null("BossPortrait"), "DemoScene should build boss portrait")
		assert_not_null(inst.get_node_or_null("SubtitleLabel"), "DemoScene should build unlock subtitle")

func test_demo_scene_process_updates_visuals_and_emits_finished() -> void:
	var inst = DemoBunnyScene.instantiate()
	add_child_autofree(inst)
	inst.duration = 0.5
	watch_signals(inst)

	inst._process(0.25)
	assert_lt(inst._timer, inst.duration)
	assert_not_null(inst._color_rect.color)
	assert_gt(inst._label.scale.x, 0.5)

	inst._process(0.3)
	assert_signal_emitted(inst, "demo_finished", "Should emit demo_finished once timer >= duration")

func test_demo_scene_draw_runs_cleanly_with_null_children() -> void:
	var inst = DemoSceneScript.new()
	inst.duration = 2.0
	add_child_autofree(inst)
	inst.queue_redraw()
	inst._process(0.5)
	assert_eq(inst._timer, 0.5)
	watch_signals(inst)
	inst._process(2.0)
	assert_signal_emitted(inst, "demo_finished", "Should emit demo_finished even without ColorRect/Label children")
