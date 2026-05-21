extends GutTest

var InterceptorScene

func before_all():
	InterceptorScene = load("res://scenes/player/Interceptor.tscn")

func _create_player():
	var player = InterceptorScene.instantiate()
	add_child_autofree(player)
	return player

func test_constants():
	var script = load("res://scenes/player/Interceptor.gd")
	assert_eq(script.BOOST_SPEED_MULTIPLIER, 2.0, "Boost multiplier")
	assert_eq(script.WEAVE_DISTANCE, 128.0, "Weave distance")
	assert_eq(script.WEAVE_COOLDOWN, 0.5, "Weave cooldown")
	assert_eq(script.BOOST_DURATION, 1.5, "Boost duration")
	assert_eq(script.BOOST_RECHARGE_TIME, 8.0, "Boost recharge time")
	assert_eq(script.DOUBLE_TAP_DELAY, 0.25, "Double tap delay")
	assert_eq(script.SPEED_MODIFIER, 0.5, "Speed modifier")

func test_weapon_types_constant():
	var script = load("res://scenes/player/Interceptor.gd")
	assert_eq(script.WEAPON_TYPES.size(), 3, "Should have 3 weapon types")
	assert_eq(script.WEAPON_TYPES[0], "missile", "First weapon should be missile")
	assert_eq(script.WEAPON_TYPES[1], "mine", "Second weapon should be mine")
	assert_eq(script.WEAPON_TYPES[2], "emp", "Third weapon should be emp")

func test_lane_to_x():
	var player = _create_player()
	assert_eq(player._lane_to_x(0), -96.0, "Lane 0 X position")
	assert_eq(player._lane_to_x(1), -32.0, "Lane 1 X position")
	assert_eq(player._lane_to_x(2), 32.0, "Lane 2 X position")
	assert_eq(player._lane_to_x(3), 96.0, "Lane 3 X position")
	assert_eq(Constants.LANE_POSITIONS[0], -96.0, "Constants lane 0")
	assert_eq(Constants.LANE_POSITIONS[3], 96.0, "Constants lane 3")

func test_initial_state():
	var player = _create_player()
	assert_eq(player.current_lane, 1, "Initial lane")
	assert_eq(player.boost_charges, 3, "Initial boost charges")
	assert_false(player.boost_active, "Boost should not be active")
	assert_false(player.invincible, "Should not be invincible")
	assert_false(player.slippery, "Should not be slippery")

func test_cycle_weapon():
	var player = _create_player()
	assert_eq(player.current_weapon, 0, "Initial weapon index")
	player._cycle_weapon()
	assert_eq(player.current_weapon, 1, "After first cycle")
	player._cycle_weapon()
	assert_eq(player.current_weapon, 2, "After second cycle")
	player._cycle_weapon()
	assert_eq(player.current_weapon, 0, "After third cycle (wraps)")

func test_cycle_weapon_uses_array_size():
	var player = _create_player()
	player.secondary_ammo = [1, 1, 1, 1]
	for i in range(4):
		player._cycle_weapon()
	assert_eq(player.current_weapon, 0, "Should wrap based on array size")

func test_fire_primary_cooldown():
	var player = _create_player()
	player._fire_primary()
	assert_gt(player.primary_fire_timer, 0.0, "Fire timer should be set")

func test_fire_primary_respects_cooldown():
	var player = _create_player()
	var fired_count = 0
	player.weapon_fired.connect(func(_type, _pos, _dir): fired_count += 1)
	player._fire_primary()
	player._fire_primary()
	assert_eq(fired_count, 1, "Should only fire once during cooldown")

func test_fire_secondary_no_ammo():
	var player = _create_player()
	player.secondary_ammo = [0, 0, 0]
	var fired_count = 0
	player.weapon_fired.connect(func(_type, _pos, _dir): fired_count += 1)
	player._fire_secondary()
	assert_eq(fired_count, 0, "Should not fire with no ammo")

func test_fire_secondary_decrements_ammo():
	var player = _create_player()
	player.secondary_ammo = [3, 2, 1]
	player._fire_secondary()
	assert_eq(player.secondary_ammo[0], 2, "Missile ammo should decrease")

func test_fire_secondary_uses_weapon_types():
	var player = _create_player()
	var fired_type = ""
	player.weapon_fired.connect(func(type, _pos, _dir): fired_type = type)
	player._fire_secondary()
	assert_eq(fired_type, "missile", "Should fire missile type")
	player._cycle_weapon()
	player._fire_secondary()
	assert_eq(fired_type, "mine", "Should fire mine type after cycle")

func test_activate_boost_no_charges():
	var player = _create_player()
	player.boost_charges = 0
	player._activate_boost()
	assert_false(player.boost_active, "Should not activate boost with no charges")

func test_activate_boost_already_active():
	var player = _create_player()
	player.boost_active = true
	player._activate_boost()
	assert_eq(player.boost_charges, player.max_boost_charges, "Should not consume charge when already active")

func test_activate_boost_success():
	var player = _create_player()
	var initial_charges = player.boost_charges
	player._activate_boost()
	assert_true(player.boost_active, "Boost should be active")
	assert_eq(player.boost_charges, initial_charges - 1, "Should consume one charge")

func test_deactivate_boost():
	var player = _create_player()
	player.boost_active = true
	player._deactivate_boost()
	assert_false(player.boost_active, "Boost should be deactivated")
	assert_gt(player.boost_recharge_timer, 0.0, "Recharge timer should start")

func test_boost_recharge():
	var player = _create_player()
	player.boost_charges = 0
	player.boost_active = false
	player.boost_recharge_timer = 0.1
	player._update_timers(0.2)
	assert_eq(player.boost_charges, 1, "Should recharge one boost")

func test_boost_recharge_stops_at_max():
	var player = _create_player()
	player.boost_charges = player.max_boost_charges
	player.boost_active = false
	player.boost_recharge_timer = 0.0
	player._update_timers(1.0)
	assert_eq(player.boost_charges, player.max_boost_charges, "Should not exceed max charges")

func test_invincibility_timer():
	var player = _create_player()
	player.invincible = true
	player.invincible_timer = 0.5
	player._update_timers(0.6)
	assert_false(player.invincible, "Invincibility should expire")

func test_take_damage_while_invincible():
	var player = _create_player()
	player.invincible = true
	var gm = TestHelper.create_game_manager()
	add_child_autofree(gm)
	gm.start_game()
	var initial_health = gm.health
	player.take_damage(1)
	assert_eq(gm.health, initial_health, "Should not take damage while invincible")

func test_take_damage_sets_invincibility():
	var player = _create_player()
	var gm = TestHelper.create_game_manager()
	add_child_autofree(gm)
	gm.start_game()
	player.take_damage(1)
	assert_true(player.invincible, "Should become invincible after damage")
	assert_eq(player.invincible_timer, 1.0, "Invincibility timer should be 1 second")

func test_take_damage_while_boosting():
	var player = _create_player()
	player.boost_active = true
	var gm = TestHelper.create_game_manager()
	add_child_autofree(gm)
	gm.start_game()
	var initial_health = gm.health
	player.take_damage(1)
	assert_eq(gm.health, initial_health, "Should not take damage while boosting")

func test_set_slippery():
	var player = _create_player()
	player.set_slippery(true)
	assert_true(player.slippery, "Should be slippery")
	player.set_slippery(false)
	assert_false(player.slippery, "Should not be slippery")

func test_weave_cooldown():
	var player = _create_player()
	player.can_weave = false
	player.weave_timer = 0.5
	player._update_timers(0.6)
	assert_true(player.can_weave, "Weave should be available after cooldown")

func test_weave_cooldown_active():
	var player = _create_player()
	player.can_weave = false
	player.weave_timer = 0.5
	player._update_timers(0.3)
	assert_false(player.can_weave, "Weave should still be on cooldown")

func test_add_boost():
	var player = _create_player()
	player.boost_charges = 1
	player.add_boost()
	assert_eq(player.boost_charges, 2, "Should add one boost charge")

func test_add_boost_at_max():
	var player = _create_player()
	player.boost_charges = player.max_boost_charges
	player.add_boost()
	assert_eq(player.boost_charges, player.max_boost_charges, "Should not exceed max charges")

func test_add_ammo():
	var player = _create_player()
	player.secondary_ammo = [1, 1, 1]
	player.add_ammo()
	assert_eq(player.secondary_ammo, [2, 2, 2], "Should add one to each ammo type")

func test_primary_fire_timer_decrements():
	var player = _create_player()
	player.primary_fire_timer = 0.05
	player._update_timers(0.06)
	assert_eq(player.primary_fire_timer, 0.0, "Timer should not go below 0")

func test_fire_rate_upgrade():
	var player = _create_player()
	var gm = TestHelper.create_game_manager()
	add_child_autofree(gm)
	gm.upgrade_levels["fire_rate"] = 3
	player._fire_primary()
	var expected_cooldown = clampf(0.1 - (3 - 1) * 0.01, 0.05, 0.1)
	assert_eq(player.primary_fire_timer, expected_cooldown, "Fire rate should scale with upgrade")

func test_ready_sets_collision_layers():
	var player = _create_player()
	assert_eq(player.collision_layer, 1, "Player should be on layer 1")
	assert_eq(player.collision_mask, 1, "Player should mask layer 1")
	assert_true(player.is_in_group("player"), "Player should be in player group")

func test_ready_applies_upgrades():
	var player = _create_player()
	var gm = TestHelper.create_game_manager()
	add_child_autofree(gm)
	gm.upgrade_levels["boost_capacity"] = 3
	gm.upgrade_levels["missile_ammo"] = 2
	gm.upgrade_levels["mine_ammo"] = 2
	gm.upgrade_levels["emp_ammo"] = 2
	player._ready()
	assert_eq(player.max_boost_charges, 5, "Boost capacity should be 2 + upgrade level")
	assert_eq(player.secondary_ammo[0], 4, "Missile ammo should be 2 + upgrade level")
	assert_eq(player.secondary_ammo[1], 3, "Mine ammo should be 1 + upgrade level")
	assert_eq(player.secondary_ammo[2], 2, "EMP ammo should be upgrade level")

func test_update_boost_ui_emits_signal():
	var player = _create_player()
	watch_signals(player)
	player._update_boost_ui()
	assert_signal_emitted(player, "boost_charge_updated", "Should emit boost charge signal")

func test_physics_process_moves_upward():
	var player = _create_player()
	player._physics_process(0.1)
	assert_lt(player.velocity.y, 0.0, "Player should move upward")

func test_physics_process_slippery_steering():
	var player = _create_player()
	player.target_x = 96.0
	player.slippery = true
	player._physics_process(0.1)
	var slippery_vx = player.velocity.x
	player.slippery = false
	player.velocity.x = 0.0
	player._physics_process(0.1)
	var normal_vx = player.velocity.x
	assert_lt(abs(slippery_vx), abs(normal_vx), "Slippery steering should be slower")

func test_weapon_switched_emits_signal():
	var player = _create_player()
	watch_signals(player)
	player._cycle_weapon()
	assert_signal_emitted(player, "weapon_switched", "Should emit weapon_switched signal")

func test_boost_activated_emits_signal():
	var player = _create_player()
	watch_signals(player)
	player._activate_boost()
	assert_signal_emitted(player, "boost_activated", "Should emit boost_activated signal")

func test_boost_depleted_emits_signal():
	var player = _create_player()
	player.boost_active = true
	watch_signals(player)
	player._deactivate_boost()
	assert_signal_emitted(player, "boost_depleted", "Should emit boost_depleted signal")

func test_weapon_fired_emits_signal():
	var player = _create_player()
	watch_signals(player)
	player._fire_primary()
	assert_signal_emitted(player, "weapon_fired", "Should emit weapon_fired signal")

func test_boost_charge_updated_emits_on_add_boost():
	var player = _create_player()
	watch_signals(player)
	player.add_boost()
	assert_signal_emitted(player, "boost_charge_updated", "Should emit boost_charge_updated signal")

func test_weapon_switched_emits_on_add_ammo():
	var player = _create_player()
	watch_signals(player)
	player.add_ammo()
	assert_signal_emitted(player, "weapon_switched", "Should emit weapon_switched on ammo add")

func test_invincibility_visual_resets():
	var player = _create_player()
	player.invincible = true
	player.invincible_timer = 0.5
	player.modulate = Color(1, 0.3, 0.3, 0.7)
	player._update_timers(0.6)
	assert_eq(player.modulate, Color.WHITE, "Visual should reset after invincibility")

func test_boost_timer_decrements():
	var player = _create_player()
	player.boost_active = true
	player.boost_timer = 0.5
	player._update_timers(0.6)
	assert_false(player.boost_active, "Boost should deactivate after timer")

func test_fire_secondary_emits_correct_weapon_type():
	var player = _create_player()
	var types_fired = []
	player.weapon_fired.connect(func(type, _pos, _dir): types_fired.append(type))
	player._fire_secondary()
	player.current_weapon = 1
	player._fire_secondary()
	player.current_weapon = 2
	player._fire_secondary()
	assert_eq(types_fired, ["missile", "mine", "emp"], "Should emit correct weapon types")

func test_ready_uses_per_weapon_ammo_upgrades():
	var player = _create_player()
	var gm = TestHelper.create_game_manager()
	add_child_autofree(gm)
	gm.upgrade_levels["missile_ammo"] = 3
	gm.upgrade_levels["mine_ammo"] = 2
	gm.upgrade_levels["emp_ammo"] = 4
	player._ready()
	assert_eq(player.secondary_ammo[0], 5, "Missile ammo should be 2 + 3")
	assert_eq(player.secondary_ammo[1], 3, "Mine ammo should be 1 + 2")
	assert_eq(player.secondary_ammo[2], 4, "EMP ammo should be 4")

func test_ready_with_default_ammo_upgrades():
	var player = _create_player()
	var gm = TestHelper.create_game_manager()
	add_child_autofree(gm)
	player._ready()
	assert_eq(player.secondary_ammo[0], 3, "Default missile ammo should be 2 + 1")
	assert_eq(player.secondary_ammo[1], 2, "Default mine ammo should be 1 + 1")
	assert_eq(player.secondary_ammo[2], 1, "Default EMP ammo should be 1")
