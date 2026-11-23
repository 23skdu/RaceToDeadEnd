#!/usr/bin/env godot
## GUT post-run hook that turns any orphaned node into a failed test run.
##
## GUT reports orphans but does not fail the command by default. This hook is
## attached to every Makefile GUT invocation via `-gpost_run_script` so orphan
## regressions are caught locally and in the pre-commit gate.

extends GutHookScript

const MAX_ORPHANS: int = 0


static func orphan_counts(gut: Object) -> Dictionary:
	var counter = gut.get_orphan_counter()
	# GUT records orphan IDs at script end without pruning entries that were
	# freed afterwards. Drop stale entries so only real orphans fail the gate.
	if counter.orphanage != null:
		counter.orphanage.clean()
	return {
		"live": int(counter.orphan_count()),
		"recorded": int(counter.get_orphan_ids().size()),
	}


static func release_static_caches() -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		var audio_mgr = tree.root.get_node_or_null("AudioManager")
		if audio_mgr and audio_mgr.has_method("stop_all_audio"):
			audio_mgr.stop_all_audio()
		var obj_pool = tree.root.get_node_or_null("ObjectPool")
		if obj_pool and obj_pool.has_method("clear_all_pools"):
			obj_pool.clear_all_pools()
	var game_script = load("res://scripts/scenes/Game.gd")
	if game_script:
		game_script._parallax_texture_cache.clear()
	var highway_script = load("res://scripts/scenes/world/Highway.gd")
	if highway_script:
		highway_script._diamond_mesh_cache = null
		highway_script._diamond_mesh_lane_cache = null
		highway_script._diamond_mesh_shoulder_cache = null
		highway_script._bridge_structure_mesh_cache = null
		highway_script._rect_mesh_cache.clear()
		highway_script._decor_mesh_cache.clear()
		highway_script._obstacle_mesh_cache.clear()
	var emp_script = load("res://scripts/scenes/weapons/EMPBlast.gd")
	if emp_script:
		emp_script._shared_shockwave_shader = null
	var baby_bomb_script = load("res://scripts/scenes/weapons/BabyBunnyBomb.gd")
	if baby_bomb_script:
		baby_bomb_script._baby_bunny_bomb_texture = null
	var poop_script = load("res://scripts/scenes/weapons/PoopWeapon.gd")
	if poop_script:
		poop_script._poop_texture = null
	var enemy_script = load("res://scripts/scenes/enemies/Enemy.gd")
	if enemy_script:
		enemy_script._bunny_texture = null
		enemy_script._sasquatch_fallback_texture = null
		enemy_script._eye_shader_material = null
	var boss_bunny_script = load("res://scripts/scenes/enemies/BossBunny.gd")
	if boss_bunny_script:
		boss_bunny_script._boss_bunny_texture = null
	var boss_biker_script = load("res://scripts/scenes/enemies/BossGiantBiker.gd")
	if boss_biker_script:
		boss_biker_script._boss_biker_texture = null
	var boss_sasquatch_script = load("res://scripts/scenes/enemies/BossSasquatch.gd")
	if boss_sasquatch_script:
		boss_sasquatch_script._boss_sasquatch_texture = null
	var boss_void_script = load("res://scripts/scenes/enemies/BossVoidDrone.gd")
	if boss_void_script:
		boss_void_script._boss_void_drone_texture = null
	var boss_warrig_script = load("res://scripts/scenes/enemies/BossWarRig.gd")
	if boss_warrig_script:
		boss_warrig_script._boss_war_rig_texture = null
	var loc_script = load("res://scripts/utils/LocalizationUtil.gd")
	if loc_script:
		for tr in loc_script._translations.values():
			if tr is Translation:
				TranslationServer.remove_translation(tr)
		loc_script._translations.clear()
	var rw_script = load("res://scripts/utils/RoadmapWorld.gd")
	if rw_script:
		rw_script._light_texture = null
		rw_script._lut_shader = null
		rw_script._fsr_shader = null
		rw_script._ssao_shader = null
	var rfx_script = load("res://scripts/utils/RoadmapFx.gd")
	if rfx_script:
		rfx_script._glow_texture_cache.clear()
		rfx_script._ring_texture_cache.clear()
		rfx_script._weather_lut_cache.clear()


func run() -> void:
	var counts: Dictionary = orphan_counts(gut)
	var live: int = int(counts.get("live", 0))
	var recorded: int = int(counts.get("recorded", 0))
	if live > MAX_ORPHANS or recorded > MAX_ORPHANS:
		gut.logger.error(
			"Orphan guard failed: %d live orphan(s), %d recorded orphan(s)." % [live, recorded]
		)
		set_exit_code(1)
	else:
		gut.logger.log("Orphan guard passed: 0 live and 0 recorded orphans.")
	if gut != null and gut is Node:
		release_static_caches()
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			await (loop as SceneTree).create_timer(0.1).timeout
			await (loop as SceneTree).process_frame
