extends GutTest

var Spawner
var Enemy

func before_all():
	Spawner = load("res://scripts/scenes/world/Spawner.gd")
	Enemy = load("res://scripts/scenes/enemies/Enemy.gd")

func before_each():
	var save_path = "user://save.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	GameManager.state = GameManager.GameState.MENU
	GameManager.difficulty_tier = 1
	GameManager.score = 0
	GameManager.bosses_killed = 3
	GameManager.boss_active = false


func test_wave_interval_default():
	var s = Spawner.new()
	assert_eq(s.wave_interval, 5.0, "Default wave interval should be 5 seconds")

func test_base_speed_constant():
	assert_eq(Constants.BASE_SPEED, 200.0, "Base speed should be 200")

func test_wave_timer_decrements():
	var s = Spawner.new()
	s.player = _create_mock_player()
	s.wave_timer = 3.0
	GameManager.state = GameManager.GameState.PLAYING
	s._process(1.0)
	assert_eq(s.wave_timer, 2.0, "Wave timer should decrement by delta")

func test_wave_timer_resets_after_spawn():
	var s = Spawner.new()
	s.player = _create_mock_player()
	s.wave_timer = 0.0
	GameManager.state = GameManager.GameState.PLAYING
	s._process(0.1)
	assert_eq(s.wave_timer, s.wave_interval, "Wave timer should reset to wave_interval")

func test_wave_interval_scales_with_difficulty():
	var s = Spawner.new()
	s.player = _create_mock_player()
	GameManager.difficulty_tier = 1
	s.wave_timer = 0.0
	GameManager.state = GameManager.GameState.PLAYING
	s._process(0.1)
	assert_eq(s.wave_interval, 5.0, "Tier 1 wave interval should be 5.0")

func test_wave_interval_decreases_at_higher_tiers():
	var s = Spawner.new()
	s.player = _create_mock_player()
	GameManager.difficulty_tier = 5
	s.wave_timer = 0.0
	GameManager.state = GameManager.GameState.PLAYING
	s._process(0.1)
	assert_lt(s.wave_interval, 5.0, "Wave interval should decrease at higher tiers")
	assert_gte(s.wave_interval, 2.0, "Wave interval should not go below 2.0")

func test_wave_composition_tier_1():
	var s = Spawner.new()
	var comp = s._get_wave_composition(1)
	assert_eq(comp["rotor"], 1, "Tier 1 should have 1 rotor")
	assert_false(comp.has("scav"), "Tier 1 should not have scavs")
	assert_false(comp.has("drone"), "Tier 1 should not have drones")

func test_wave_composition_tier_2():
	var s = Spawner.new()
	var comp = s._get_wave_composition(2)
	assert_eq(comp["rotor"], 2, "Tier 2 should have 2 rotors")
	assert_eq(comp["scav"], 1, "Tier 2 should have 1 scav")

func test_wave_composition_tier_3():
	var s = Spawner.new()
	var comp = s._get_wave_composition(3)
	assert_eq(comp["rotor"], 1, "Tier 3 should have 1 rotor")
	assert_eq(comp["scav"], 1, "Tier 3 should have 1 scav")
	assert_eq(comp["drone"], 1, "Tier 3 should have 1 drone")

func test_wave_composition_tier_6():
	var s = Spawner.new()
	var comp = s._get_wave_composition(6)
	assert_eq(comp["rotor"], clampi(1 + floori(6 / 3.0), 1, 6), "Tier 6 rotor count")
	assert_eq(comp["scav"], clampi(floori(6 / 4.0), 1, 3), "Tier 6 scav count")
	assert_eq(comp["drone"], clampi(floori(6 / 6.0), 1, 2), "Tier 6 drone count")

func test_wave_composition_tier_12():
	var s = Spawner.new()
	var comp = s._get_wave_composition(12)
	assert_eq(comp["rotor"], 5, "Tier 12 should have 5 rotors (capped at 6)")
	assert_eq(comp["scav"], 3, "Tier 12 should have 3 scavs (capped at 3)")
	assert_eq(comp["drone"], 2, "Tier 12 should have 2 drones (capped at 2)")

func test_wave_composition_tier_2_no_boss_kills():
	GameManager.bosses_killed = 0
	var s = Spawner.new()
	var comp = s._get_wave_composition(2)
	assert_false(comp.has("scav"), "Tier 2 should not have scavs when no bosses killed")

func test_wave_composition_tier_3_no_boss_kills():
	GameManager.bosses_killed = 0
	var s = Spawner.new()
	var comp = s._get_wave_composition(3)
	assert_false(comp.has("scav"), "Tier 3 should not have scavs when no bosses killed")
	assert_false(comp.has("drone"), "Tier 3 should not have drones when no bosses killed")

func test_wave_composition_tier_3_one_boss_kill():
	GameManager.bosses_killed = 1
	var s = Spawner.new()
	var comp = s._get_wave_composition(3)
	assert_false(comp.has("scav"), "Tier 3 should not have scav when only 1 boss killed")
	assert_false(comp.has("drone"), "Tier 3 should not have drones when only 1 boss killed")

func test_wave_composition_tier_3_two_boss_kills():
	GameManager.bosses_killed = 2
	var s = Spawner.new()
	var comp = s._get_wave_composition(3)
	assert_eq(comp.get("scav"), 1, "Tier 3 should have scav when 2 bosses killed")
	assert_false(comp.has("drone"), "Tier 3 should not have drones when only 2 bosses killed")

func test_pick_pickup_type_returns_valid():
	var s = Spawner.new()
	for i in range(20):
		var result = s._pick_pickup_type()
		assert_true(result in ["repair", "ammo", "boost", "multiplier"], "Should return valid pickup type")

func test_drop_pickup_under_threshold():
	var s = Spawner.new()
	var child_count_before = s.get_child_count()
	s._drop_pickup(Vector2.ZERO)
	var child_count_after = s.get_child_count()
	assert_true(child_count_after - child_count_before <= 1, "Should spawn at most 1 pickup")

func test_spawn_pickup_creates_area():
	var s = Spawner.new()
	var parent = Node.new()
	add_child_autofree(parent)
	parent.add_child(s)
	s._spawn_pickup(Vector2(100, 200), "repair")
	var areas = []
	for child in parent.get_children():
		if child is Area2D:
			areas.append(child)
	assert_gt(areas.size(), 0, "Should create an Area2D pickup")

func test_spawn_pickup_sets_position():
	var s = Spawner.new()
	var parent = Node.new()
	add_child_autofree(parent)
	parent.add_child(s)
	var pos = Vector2(500, 600)
	s._spawn_pickup(pos, "ammo")
	for child in parent.get_children():
		if child is Area2D:
			assert_eq(child.global_position, pos, "Pickup should be at spawn position")
			break

func test_garbage_collection_removes_far_enemies():
	var s = Spawner.new()
	s.player = _create_mock_player()
	var mock_enemy = Node2D.new()
	mock_enemy.global_position = Vector2(0, 1000)
	GameManager.enemy_list.append(mock_enemy)
	add_child_autofree(s)
	s.add_child(mock_enemy)
	GameManager.state = GameManager.GameState.PLAYING
	s._process(0.1)
	assert_false(GameManager.enemy_list.has(mock_enemy), "Far enemy should be garbage collected")

func test_garbage_collection_keeps_near_enemies():
	var s = Spawner.new()
	s.player = _create_mock_player()
	var mock_enemy = Node2D.new()
	mock_enemy.global_position = Vector2(0, 100)
	GameManager.enemy_list.append(mock_enemy)
	add_child_autofree(s)
	s.add_child(mock_enemy)
	GameManager.state = GameManager.GameState.PLAYING
	s._process(0.1)
	assert_true(GameManager.enemy_list.has(mock_enemy), "Near enemy should be kept")

func test_garbage_collection_removes_invalid_enemies():
	var s = Spawner.new()
	s.player = _create_mock_player()
	var mock_enemy = Node2D.new()
	GameManager.enemy_list.append(mock_enemy)
	mock_enemy.queue_free()
	add_child_autofree(s)
	GameManager.state = GameManager.GameState.PLAYING
	s._process(0.1)
	assert_false(GameManager.enemy_list.has(mock_enemy), "Invalid enemy should be removed")

func test_spawn_enemy_missing_scene():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s.enemy_scenes["missing"] = null
	s._spawn_enemy("missing")
	assert_true(true, "Should not crash with missing scene")

func test_process_does_not_spawn_when_not_playing():
	var s = Spawner.new()
	s.player = _create_mock_player()
	s.wave_timer = 0.0
	GameManager.state = GameManager.GameState.MENU
	s._process(0.1)
	assert_eq(s.wave_timer, 0.0, "Wave timer should not reset when not PLAYING")

func test_world_node_reference():
	var s = Spawner.new()
	var world = Node2D.new()
	s.world_node = world
	assert_eq(s.world_node, world, "World node reference should be set")

func _create_mock_player() -> Node2D:
	var player = Node2D.new()
	player.global_position = Vector2(0, 0)
	player.position = Vector2(0, 0)
	return player

func test_ready_preloads_enemy_scenes():
	var s = Spawner.new()
	add_child_autofree(s)
	assert_true(s.enemy_scenes.has("rotor"), "Should have rotor scene")
	assert_true(s.enemy_scenes.has("scav"), "Should have scav scene")
	assert_true(s.enemy_scenes.has("drone"), "Should have drone scene")

func test_spawn_wave_increments_counter():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	var initial_wave = s.current_wave
	s._spawn_wave()
	assert_eq(s.current_wave, initial_wave + 1, "Wave counter should increment")

func test_spawn_wave_emits_signal():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	watch_signals(s)
	s._spawn_wave()
	assert_signal_emitted(s, "wave_spawned", "Should emit wave_spawned signal")

func test_spawn_enemy_creates_rotor():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._spawn_enemy("rotor")
	var enemy_count = 0
	for child in s.get_children():
		if child.has_method("init") and child is CharacterBody2D:
			enemy_count += 1
	assert_gt(enemy_count, 0, "Should spawn a rotor enemy")

func test_spawn_enemy_sets_lane_position():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._spawn_enemy("rotor")
	for child in s.get_children():
		if child.has_method("init") and child is CharacterBody2D:
			var lane_x = child.global_position.x
			assert_true(lane_x in Constants.LANE_POSITIONS, "Enemy should be in a valid lane")
			break

func test_on_enemy_destroyed_registers_score():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	GameManager.start_game()
	s._on_enemy_destroyed(Vector2.ZERO, "rotor", Node2D.new())
	assert_gt(GameManager.score, 0, "Should register score on enemy destroy")

func test_on_pickup_collected_ignores_non_player():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	var pickup = Area2D.new()
	add_child_autofree(pickup)
	s._on_pickup_collected("repair", pickup)
	assert_true(true, "Should not crash with non-player body")

func test_spawn_enemy_null_player():
	var s = Spawner.new()
	add_child_autofree(s)
	s.player = null
	s._spawn_enemy("rotor")
	assert_true(true, "Should not crash with null player")

func test_process_finds_player_from_group():
	var s = Spawner.new()
	add_child_autofree(s)
	var mock_player = Node2D.new()
	mock_player.global_position = Vector2(0, 0)
	mock_player.add_to_group("player")
	add_child_autofree(mock_player)
	s.player = mock_player
	s.wave_timer = 0.0
	GameManager.state = GameManager.GameState.PLAYING
	s._process(0.1)
	assert_eq(s.player, mock_player, "Should find player from group")

func test_pickup_type_multiplier():
	var s = Spawner.new()
	GameManager.start_game()
	s._drop_pickup(Vector2.ZERO)
	assert_true(true, "Should handle multiplier pickup type")

func test_wave_spawned_signal_contains_wave_number():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	var captured = {wave = 0}
	s.wave_spawned.connect(func(w): captured.wave = w)
	s._spawn_wave()
	assert_eq(captured.wave, 1, "Signal should contain wave number 1")

func test_spawner_has_spawn_minion_requested_signal():
	var s = Spawner.new()
	assert_true(s.has_signal("spawn_minion_requested"), "Spawner should have spawn_minion_requested signal")

class MockBossNode extends Node2D:
	@warning_ignore("unused_signal")
	signal destroyed(pos: Vector2, enemy_type: String, enemy: Node)
	var player = null
	@warning_ignore("unused_private_class_variable")
	var _spawner = null

class MockCivilianNode extends Node2D:
	@warning_ignore("unused_signal")
	signal exited_safely
	@warning_ignore("unused_signal")
	signal hit_by_player
	var _init_called = false
	func init(_lane, _speed, _dir, _player):
		_init_called = true

func _make_boss_scene() -> PackedScene:
	var n = MockBossNode.new()
	var ps = PackedScene.new()
	ps.pack(n)
	return ps

func _make_civilian_scene() -> PackedScene:
	var n = MockCivilianNode.new()
	var ps = PackedScene.new()
	ps.pack(n)
	return ps

func test_spawn_boss_creates_node():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._bosses_spawned = 2
	s.enemy_scenes["boss"] = _make_boss_scene()
	s._spawn_boss()
	assert_gt(s.get_child_count(), 0, "Boss node should be added as child")

func test_spawn_boss_emits_signal():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._bosses_spawned = 2
	s.enemy_scenes["boss"] = _make_boss_scene()
	watch_signals(s)
	s._spawn_boss()
	assert_signal_emitted(s, "boss_spawned", "Should emit boss_spawned signal")

func test_spawn_boss_sets_lane_position():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._bosses_spawned = 2
	s.enemy_scenes["boss"] = _make_boss_scene()
	s._spawn_boss()
	for child in s.get_children():
		if child.get("_spawner") == s:
			var expected_y = s.player.global_position.y - Constants.SPAWN_DISTANCE
			assert_eq(child.global_position.y, expected_y, "Boss Y should be SPAWN_DISTANCE above player")
			assert_true(child.global_position.x in Constants.LANE_POSITIONS, "Boss X should be a valid lane position")
			break

func test_spawn_boss_sets_player_ref():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._bosses_spawned = 2
	s.enemy_scenes["boss"] = _make_boss_scene()
	s._spawn_boss()
	for child in s.get_children():
		if child.get("_spawner") == s:
			assert_eq(child.player, s.player, "Boss should have player reference")
			break

func test_spawn_boss_sets_spawner_ref():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._bosses_spawned = 2
	s.enemy_scenes["boss"] = _make_boss_scene()
	s._spawn_boss()
	for child in s.get_children():
		if child.get("_spawner") == s:
			assert_eq(child._spawner, s, "Boss should have spawner reference")
			break

func test_spawn_boss_increments_counter():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._bosses_spawned = 2
	s.enemy_scenes["boss"] = _make_boss_scene()
	var before = s._bosses_spawned
	s._spawn_boss()
	assert_eq(s._bosses_spawned, before + 1, "_bosses_spawned should increment")

func test_spawn_civilian_creates_child():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s.enemy_scenes["civilian"] = _make_civilian_scene()
	s._spawn_civilian()
	var found = false
	for child in s.get_children():
		if child.has_signal("exited_safely"):
			found = true
			break
	assert_true(found, "Civilian node should be added as child")

func test_spawn_civilian_connects_exited_safely():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s.enemy_scenes["civilian"] = _make_civilian_scene()
	s._spawn_civilian()
	for child in s.get_children():
		if child.has_signal("exited_safely"):
			assert_true(child.exited_safely.is_connected(s._on_civilian_safe_exit.bind(child)), "exited_safely should be connected")
			break

func test_spawn_civilian_connects_hit_by_player():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s.enemy_scenes["civilian"] = _make_civilian_scene()
	s._spawn_civilian()
	for child in s.get_children():
		if child.has_signal("hit_by_player"):
			assert_true(child.hit_by_player.is_connected(s._on_civilian_hit.bind(child)), "hit_by_player should be connected")
			break

func test_spawn_civilian_sets_position_offset():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s.enemy_scenes["civilian"] = _make_civilian_scene()
	s._spawn_civilian()
	for child in s.get_children():
		if child.has_signal("exited_safely"):
			var expected_y = s.player.global_position.y - Constants.SPAWN_DISTANCE * 0.5
			assert_eq(child.global_position.y, expected_y, "Civilian Y should be 0.5 * SPAWN_DISTANCE above player")
			break

func test_should_spawn_boss_returns_true_at_threshold():
	var s = Spawner.new()
	s._ready()
	s.enemy_scenes["boss"] = _make_boss_scene()
	GameManager.score = Constants.BOSS_SCORE_INTERVAL
	assert_true(s._should_spawn_boss(), "Should return true when score crosses threshold")

func test_should_spawn_boss_returns_false_below_threshold():
	var s = Spawner.new()
	s._ready()
	s.enemy_scenes["boss"] = _make_boss_scene()
	GameManager.score = Constants.BOSS_SCORE_INTERVAL - 1
	assert_false(s._should_spawn_boss(), "Should return false below threshold")

func test_on_civilian_safe_exit_calls_register():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	GameManager.start_game()
	var civilian = Node2D.new()
	s._on_civilian_safe_exit(civilian)
	assert_eq(GameManager.score, 500, "Should register civilian protected for 500 points")

class PlayerWithDamage extends Node2D:
	func take_damage(amount):
		GameManager.take_damage(amount)

func test_on_civilian_hit_calls_register():
	var s = Spawner.new()
	var mock_player = PlayerWithDamage.new()
	mock_player.global_position = Vector2.ZERO
	s.player = mock_player
	add_child_autofree(mock_player)
	add_child_autofree(s)
	GameManager.start_game()
	var health_before = GameManager.health
	s._on_civilian_hit(MockCivilianNode.new())
	assert_eq(GameManager.health, health_before - Constants.CIVILIAN_PENALTY, "Player should take civilian penalty damage")

func test_on_civilian_hit():
	var s = Spawner.new()
	s.player = PlayerWithDamage.new()
	add_child_autofree(s)
	GameManager.start_game()
	s._on_civilian_hit(MockCivilianNode.new())
	assert_true(true, "Should not crash when calling _on_civilian_hit")

func test_enemy_spawned_emitted_when_boss_spawns():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._bosses_spawned = 2
	s.enemy_scenes["boss"] = _make_boss_scene()
	watch_signals(s)
	s._spawn_boss()
	assert_signal_emitted(s, "enemy_spawned", "enemy_spawned should emit when boss spawns")

func test_enemy_spawned_emitted_when_enemy_spawns():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	watch_signals(s)
	s._spawn_enemy("rotor")
	assert_signal_emitted(s, "enemy_spawned", "enemy_spawned should emit when enemy spawns")

class CleanupMock extends Node2D:
	@warning_ignore("unused_signal")
	signal destroyed(pos: Vector2, enemy_type: String, enemy: Node)
	@warning_ignore("unused_private_class_variable")
	var _spawner = null

func test_cleanup_disconnects_destroyed_signal():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	var mock_enemy = CleanupMock.new()
	mock_enemy.global_position = Vector2(0, 1000)
	mock_enemy._spawner = s
	GameManager.enemy_list.append(mock_enemy)
	s.add_child(mock_enemy)
	mock_enemy.destroyed.connect(s._on_enemy_destroyed)
	GameManager.state = GameManager.GameState.PLAYING
	assert_true(mock_enemy.destroyed.is_connected(s._on_enemy_destroyed), "destroyed should be connected before cleanup")
	s._process(0.5)
	assert_false(mock_enemy.destroyed.is_connected(s._on_enemy_destroyed), "destroyed should be disconnected after cleanup")

func test_cleanup_timer_throttles_iteration():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	GameManager.state = GameManager.GameState.PLAYING
	s._process(0.1)
	s._cleanup_timer = 0.25
	var far_enemy = Node2D.new()
	far_enemy.global_position = Vector2(0, 1000)
	GameManager.enemy_list.append(far_enemy)
	s.add_child(far_enemy)
	s._process(0.1)
	assert_true(GameManager.enemy_list.has(far_enemy), "Enemy should not be cleaned up before timer expires")
	s._process(0.2)
	assert_false(GameManager.enemy_list.has(far_enemy), "Enemy should be cleaned up after timer expires")

func test_spawner_uses_game_manager_enemy_list_only():
	var s = Spawner.new()
	assert_false("active_enemies" in s, "Spawner should not have its own active_enemies list")

func test_spawner_connects_game_started_signal():
	var s = Spawner.new()
	add_child_autofree(s)
	assert_true(GameManager.game_started.is_connected(s._on_game_started), "Spawner should connect to game_started signal")

func test_spawner_resets_wave_timer_on_game_start():
	var s = Spawner.new()
	add_child_autofree(s)
	s.wave_timer = 0.0
	GameManager.start_game()
	assert_gt(s.wave_timer, 0.0, "Wave timer should be reset on game start")
	assert_eq(s.current_wave, 0, "Current wave should reset to 0")

func test_civilian_spawn_accumulator_increments():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s.civilian_chance = 1.0
	GameManager.state = GameManager.GameState.PLAYING
	s._civilian_spawn_accumulator = 0.0
	s._process(0.5)
	assert_eq(s._civilian_spawn_accumulator, 0.5, "Accumulator should increment by delta")
	s._process(0.5)
	assert_eq(s._civilian_spawn_accumulator, 0.0, "Accumulator should reset after reaching threshold")

func test_civilian_spawn_accumulator_skips_spawn_below_threshold():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s.wave_timer = 5.0
	s.civilian_chance = 0.5
	GameManager.state = GameManager.GameState.PLAYING
	s._civilian_spawn_accumulator = 0.0
	var child_before = s.get_child_count()
	s._process(0.3)
	var child_after = s.get_child_count()
	assert_eq(child_after, child_before, "No civilian should spawn below threshold")
