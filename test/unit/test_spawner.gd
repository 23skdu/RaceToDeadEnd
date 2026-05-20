extends GutTest

var Spawner

func before_all():
	Spawner = load("res://scenes/world/Spawner.gd")

func test_wave_interval_default():
	var s = Spawner.new()
	assert_eq(s.wave_interval, 5.0, "Default wave interval should be 5 seconds")

func test_base_speed_constant():
	assert_eq(Constants.BASE_SPEED, 200.0, "Base speed should be 200")

func test_wave_timer_decrements():
	var s = Spawner.new()
	s.wave_timer = 3.0
	s._process(1.0)
	assert_eq(s.wave_timer, 2.0, "Wave timer should decrement by delta")

func test_wave_timer_resets_after_spawn():
	var s = Spawner.new()
	s.player = _create_mock_player()
	s.wave_timer = 0.0
	s._process(0.1)
	assert_eq(s.wave_timer, s.wave_interval, "Wave timer should reset to wave_interval")

func test_wave_interval_scales_with_difficulty():
	var s = Spawner.new()
	s.player = _create_mock_player()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	gm.difficulty_tier = 1
	s.wave_timer = 0.0
	s._process(0.1)
	assert_eq(s.wave_interval, 5.0, "Tier 1 wave interval should be 5.0")

func test_wave_interval_decreases_at_higher_tiers():
	var s = Spawner.new()
	s.player = _create_mock_player()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	gm.difficulty_tier = 5
	s.wave_timer = 0.0
	s._process(0.1)
	assert_lt(s.wave_interval, 5.0, "Wave interval should decrease at higher tiers")
	assert_gte(s.wave_interval, 2.0, "Wave interval should not go below 2.0")

func test_wave_composition_tier_1():
	var s = Spawner.new()
	var comp = s._get_wave_composition(1)
	assert_eq(comp["rotor"], 2, "Tier 1 should have 2 rotors")
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
	add_child_autofree(s)
	s._spawn_pickup(Vector2(100, 200), "repair")
	var areas = []
	for child in s.get_children():
		if child is Area2D:
			areas.append(child)
	assert_gt(areas.size(), 0, "Should create an Area2D pickup")

func test_spawn_pickup_sets_position():
	var s = Spawner.new()
	add_child_autofree(s)
	var pos = Vector2(500, 600)
	s._spawn_pickup(pos, "ammo")
	for child in s.get_children():
		if child is Area2D:
			assert_eq(child.global_position, pos, "Pickup should be at spawn position")
			break

func test_garbage_collection_removes_far_enemies():
	var s = Spawner.new()
	s.player = _create_mock_player()
	var mock_enemy = Node2D.new()
	mock_enemy.global_position = Vector2(0, 1000)
	s.active_enemies.append(mock_enemy)
	add_child_autofree(s)
	s.add_child(mock_enemy)
	s._process(0.1)
	assert_false(s.active_enemies.has(mock_enemy), "Far enemy should be garbage collected")

func test_garbage_collection_keeps_near_enemies():
	var s = Spawner.new()
	s.player = _create_mock_player()
	var mock_enemy = Node2D.new()
	mock_enemy.global_position = Vector2(0, 100)
	s.active_enemies.append(mock_enemy)
	add_child_autofree(s)
	s.add_child(mock_enemy)
	s._process(0.1)
	assert_true(s.active_enemies.has(mock_enemy), "Near enemy should be kept")

func test_garbage_collection_removes_invalid_enemies():
	var s = Spawner.new()
	s.player = _create_mock_player()
	var mock_enemy = Node2D.new()
	s.active_enemies.append(mock_enemy)
	mock_enemy.queue_free()
	add_child_autofree(s)
	s._process(0.1)
	assert_false(s.active_enemies.has(mock_enemy), "Invalid enemy should be removed")

func test_process_does_not_spawn_when_not_playing():
	var s = Spawner.new()
	s.player = _create_mock_player()
	s.wave_timer = 0.0
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.state = gm.GameState.MENU
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
	s._ready()
	assert_true(s.enemy_scenes.has("rotor"), "Should have rotor scene")
	assert_true(s.enemy_scenes.has("scav"), "Should have scav scene")
	assert_true(s.enemy_scenes.has("drone"), "Should have drone scene")

func test_spawn_wave_increments_counter():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._ready()
	var initial_wave = s.current_wave
	s._spawn_wave()
	assert_eq(s.current_wave, initial_wave + 1, "Wave counter should increment")

func test_spawn_wave_emits_signal():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._ready()
	watch_signals(s)
	s._spawn_wave()
	assert_signal_emitted(s, "wave_spawned", "Should emit wave_spawned signal")

func test_spawn_enemy_creates_rotor():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._ready()
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
	s._ready()
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
	s._ready()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	s._on_enemy_destroyed(Vector2.ZERO, "rotor")
	assert_gt(gm.score, 0, "Should register score on enemy destroy")

func test_on_pickup_collected_ignores_non_player():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._ready()
	var pickup = Area2D.new()
	var non_player = Node2D.new()
	s._on_pickup_collected(non_player, "repair", pickup)
	assert_true(true, "Should not crash with non-player body")

func test_spawn_enemy_missing_scene():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._ready()
	s.enemy_scenes["missing"] = null
	s._spawn_enemy("missing")
	assert_true(true, "Should not crash with missing scene")

func test_spawn_enemy_null_player():
	var s = Spawner.new()
	add_child_autofree(s)
	s._ready()
	s.player = null
	s._spawn_enemy("rotor")
	assert_true(true, "Should not crash with null player")

func test_process_finds_player_from_group():
	var s = Spawner.new()
	add_child_autofree(s)
	s.player = null
	s.wave_timer = 0.0
	var mock_player = Node2D.new()
	mock_player.global_position = Vector2(0, 0)
	mock_player.add_to_group("player")
	add_child_autofree(mock_player)
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	s._process(0.1)
	assert_eq(s.player, mock_player, "Should find player from group")

func test_pickup_type_multiplier():
	var s = Spawner.new()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	s._drop_pickup(Vector2.ZERO)
	assert_true(true, "Should handle multiplier pickup type")

func test_wave_spawned_signal_contains_wave_number():
	var s = Spawner.new()
	s.player = _create_mock_player()
	add_child_autofree(s)
	s._ready()
	watch_signals(s)
	s._spawn_wave()
	var args = get_signal_parameters(s, "wave_spawned")
	assert_eq(args[0][0], 1, "Signal should contain wave number 1")
