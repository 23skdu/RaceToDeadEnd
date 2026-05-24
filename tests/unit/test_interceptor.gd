extends GutTest

var InterceptorScene
var _TestHelper

func before_all():
	_TestHelper = load("res://tests/test_helper.gd")
	InterceptorScene = load("res://scenes/player/Interceptor.tscn")

class SignalCapture:
	var count = 0
	var types = []
	func capture(_type, _pos, _dir):
		count += 1
		types.append(_type)

func before_each():
	var save_path = "user://save.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	for key in GameManager.upgrade_levels:
		GameManager.upgrade_levels[key] = 1
	GameManager.state = GameManager.GameState.MENU

func _create_player():
	var player = InterceptorScene.instantiate()
	add_child_autofree(player)
	return player

func test_constants():
	assert_eq(Constants.BOOST_SPEED_MULTIPLIER, 2.0, "Boost multiplier")
	assert_eq(Constants.WEAVE_DISTANCE, 128.0, "Weave distance")
	assert_eq(Constants.WEAVE_COOLDOWN, 0.5, "Weave cooldown")
	assert_eq(Constants.BOOST_DURATION, 1.5, "Boost duration")
	assert_eq(Constants.BOOST_RECHARGE_TIME, 8.0, "Boost recharge time")
	assert_eq(Constants.DOUBLE_TAP_DELAY, 0.25, "Double tap delay")
	assert_eq(Constants.ACCEL_SPEED, 300.0, "Acceleration speed")
	assert_eq(Constants.REVERSE_SPEED, 100.0, "Reverse speed")

func test_weapon_types_from_constants():
	assert_eq(Constants.WEAPON_DATA.size(), 3, "Should have 3 weapon data entries")
	assert_eq(Constants.WEAPON_DATA[0].type_name, "missile", "First weapon should be missile")
	assert_eq(Constants.WEAPON_DATA[1].type_name, "mine", "Second weapon should be mine")
	assert_eq(Constants.WEAPON_DATA[2].type_name, "emp", "Third weapon should be emp")

func test_lane_to_x():
	var player = _create_player()
	assert_eq(player._lane_to_x(0), -168.0, "Lane 0 X position")
	assert_eq(player._lane_to_x(1), -120.0, "Lane 1 X position")
	assert_eq(player._lane_to_x(2), -72.0, "Lane 2 X position")
	assert_eq(player._lane_to_x(3), -24.0, "Lane 3 X position")
	assert_eq(player._lane_to_x(4), 24.0, "Lane 4 X position")
	assert_eq(player._lane_to_x(5), 72.0, "Lane 5 X position")
	assert_eq(player._lane_to_x(6), 120.0, "Lane 6 X position")
	assert_eq(player._lane_to_x(7), 168.0, "Lane 7 X position")
	assert_eq(Constants.LANE_POSITIONS[0], -168.0, "Constants lane 0")
	assert_eq(Constants.LANE_POSITIONS[7], 168.0, "Constants lane 7")

func test_lane_to_x_clamps_negative():
	var player = _create_player()
	assert_eq(player._lane_to_x(-1), -168.0, "Negative lane should clamp to 0")

func test_lane_to_x_clamps_above_max():
	var player = _create_player()
	assert_eq(player._lane_to_x(10), 168.0, "Oversized lane should clamp to max")

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
	player.secondary_ammo.append(1)
	for i in range(4):
		player._cycle_weapon()
	assert_eq(player.current_weapon, 0, "Should wrap based on array size")

func test_fire_primary_cooldown():
	var player = _create_player()
	player._fire_primary()
	assert_gt(player.primary_fire_timer, 0.0, "Fire timer should be set")

func test_fire_primary_respects_cooldown():
	var player = _create_player()
	var capture = SignalCapture.new()
	player.weapon_fired.connect(capture.capture)
	player.primary_fire_timer = 0.0
	player._fire_primary()
	assert_eq(capture.count, 1, "First fire should succeed")
	player._fire_primary()
	assert_eq(capture.count, 1, "Should only fire once during cooldown")

func test_fire_secondary_uses_weapon_types():
	var player = _create_player()
	var capture = SignalCapture.new()
	player.weapon_fired.connect(capture.capture)
	player._fire_secondary()
	player._cycle_weapon()
	player._fire_secondary()
	assert_eq(capture.count, 2, "Should have 2 emissions")
	assert_eq(capture.types[0], "missile", "Should fire missile type")
	assert_eq(capture.types[1], "mine", "Should fire mine type after cycle")

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
	var gm = _TestHelper.create_game_manager()
	add_child_autofree(gm)
	gm.start_game()
	var initial_health = gm.health
	player.take_damage(1)
	assert_eq(gm.health, initial_health, "Should not take damage while invincible")

func test_take_damage_sets_invincibility():
	var player = _create_player()
	var gm = _TestHelper.create_game_manager()
	add_child_autofree(gm)
	gm.start_game()
	player.take_damage(1)
	assert_true(player.invincible, "Should become invincible after damage")
	assert_eq(player.invincible_timer, 1.0, "Invincibility timer should be 1 second")

func test_take_damage_while_boosting():
	var player = _create_player()
	player.boost_active = true
	var gm = _TestHelper.create_game_manager()
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
	player.secondary_ammo[0] = 1
	player.secondary_ammo[1] = 1
	player.secondary_ammo[2] = 1
	player.add_ammo()
	assert_eq(player.secondary_ammo, [2, 2, 2], "Should add one to each ammo type")

func test_primary_fire_timer_decrements():
	var player = _create_player()
	player.primary_fire_timer = 0.05
	player._update_timers(0.06)
	assert_eq(player.primary_fire_timer, 0.0, "Timer should not go below 0")

func test_fire_rate_upgrade():
	var save_path = "user://save.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	GameManager.upgrade_levels["fire_rate"] = 3
	var player = _create_player()
	player._fire_primary()
	var expected_cooldown = clampf(0.1 - (3 - 1) * 0.01, 0.05, 0.1)
	assert_eq(player.primary_fire_timer, expected_cooldown, "Fire rate should scale with upgrade")

func test_ready_sets_collision_layers():
	var player = _create_player()
	assert_eq(player.collision_layer, 1, "Player should be on layer 1")
	assert_eq(player.collision_mask, 1 | 2, "Player should mask layer 1 (obstacles) and layer 2 (enemies)")
	assert_true(player.is_in_group("player"), "Player should be in player group")

func test_ready_sets_z_index():
	var player = _create_player()
	assert_eq(player.z_index, 1, "Player z_index should be 1")

func test_ready_sets_camera_offset():
	var player = _create_player()
	assert_eq(player.get_node("Camera2D").position.y, -100, "Camera should be offset upward")



func test_accelerate_sets_forward_speed():
	var player = _create_player()
	player.speed = 200.0
	Input.action_press("accelerate")
	player._physics_process(0.1)
	Input.action_release("accelerate")
	assert_eq(player.velocity.y, -300.0, "Accelerate should give 300 px/s forward")

func test_reverse_sets_backward_speed():
	var player = _create_player()
	player.speed = 200.0
	Input.action_press("brake")
	player._physics_process(0.1)
	Input.action_release("brake")
	assert_eq(player.velocity.y, -100.0, "Reverse should give -100 px/s forward")

func test_coast_uses_base_speed():
	var player = _create_player()
	player.speed = 200.0
	player._physics_process(0.1)
	assert_eq(player.velocity.y, -200.0, "Coast should use base speed of 200")

func test_boost_overrides_speed_input():
	var player = _create_player()
	player.speed = 200.0
	Input.action_press("brake")
	player.boost_active = true
	player._physics_process(0.1)
	Input.action_release("brake")
	assert_eq(player.velocity.y, -400.0, "Boost should override reverse with 400 px/s")

func test_ready_applies_upgrades():
	var save_path = "user://save.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	GameManager.upgrade_levels["boost_capacity"] = 3
	GameManager.upgrade_levels["missile_ammo"] = 2
	GameManager.upgrade_levels["mine_ammo"] = 2
	GameManager.upgrade_levels["emp_ammo"] = 2
	var player = _create_player()
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
	player.boost_charges = 1
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
	var save_path = "user://save.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	GameManager.upgrade_levels["missile_ammo"] = 3
	GameManager.upgrade_levels["mine_ammo"] = 2
	GameManager.upgrade_levels["emp_ammo"] = 4
	var player = _create_player()
	player._ready()
	assert_eq(player.secondary_ammo[0], 5, "Missile ammo should be 2 + 3")
	assert_eq(player.secondary_ammo[1], 3, "Mine ammo should be 1 + 2")
	assert_eq(player.secondary_ammo[2], 4, "EMP ammo should be 4")

func test_ready_with_default_ammo_upgrades():
	var save_path = "user://save.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	for key in GameManager.upgrade_levels:
		GameManager.upgrade_levels[key] = 1
	var player = _create_player()
	player._ready()
	assert_eq(player.secondary_ammo[0], 3, "Default missile ammo should be 2 + 1")
	assert_eq(player.secondary_ammo[1], 2, "Default mine ammo should be 1 + 1")
	assert_eq(player.secondary_ammo[2], 1, "Default EMP ammo should be 1")

func test_on_bridge_fall_reduces_health():
	var player = _create_player()
	GameManager.start_game()
	var initial_health = GameManager.health
	player.on_bridge_fall(player)
	assert_eq(GameManager.health, initial_health - 2, "Health should reduce by 2 on bridge fall")

func test_on_bridge_fall_emits_damage_taken():
	var player = _create_player()
	GameManager.start_game()
	watch_signals(player)
	player.on_bridge_fall(player)
	assert_signal_emitted(player, "damage_taken", "Should emit damage_taken on bridge fall")

func test_on_speed_changed_updates_speed():
	var player = _create_player()
	player.speed = 10.0
	player._on_speed_changed(777.0)
	assert_eq(player.speed, 777.0, "Speed should update to new value")

func test_fire_specific_weapon_mine():
	var player = _create_player()
	player.secondary_ammo[1] = 2
	watch_signals(player)
	player._fire_specific_weapon("mine")
	assert_eq(player.secondary_ammo[1], 1, "Mine ammo should decrement")
	assert_signal_emitted(player, "weapon_fired", "Should emit weapon_fired signal for mine")

func test_fire_specific_weapon_emp():
	var player = _create_player()
	player.secondary_ammo[2] = 1
	watch_signals(player)
	player._fire_specific_weapon("emp")
	assert_eq(player.secondary_ammo[2], 0, "EMP ammo should decrement")
	assert_signal_emitted(player, "weapon_fired", "Should emit weapon_fired signal for emp")

func test_collision_with_enemy_calls_take_damage():
	var player = _create_player()
	GameManager.start_game()
	watch_signals(player)
	var health_before = GameManager.health
	player.take_damage(1)
	assert_eq(GameManager.health, health_before - 1, "Health should decrease by 1 on damage")
	assert_signal_emitted(player, "damage_taken", "Should emit damage_taken on collision")

func test_set_slippery_changes_steering():
	var player = _create_player()
	player.target_x = 96.0
	player.slippery = true
	player._physics_process(0.1)
	var slippery_vx = player.velocity.x
	player.velocity.x = 0.0
	player.slippery = false
	player._physics_process(0.1)
	var normal_vx = player.velocity.x
	assert_lt(abs(slippery_vx), abs(normal_vx), "Slippery steering should produce slower lateral velocity")

func test_boost_trail_line_exists():
	var player = _create_player()
	assert_not_null(player._trail_line, "Boost trail Line2D should exist")
	assert_true(player._trail_line is Line2D, "Trail should be a Line2D node")

func test_boost_trail_records_points_during_boost():
	var player = _create_player()
	player._trail_points.clear()
	player.boost_active = true
	player.velocity = Vector2(0, -200)
	player._trail_spacing_counter = player.TRAIL_SPACING
	player._update_boost_trail()
	assert_gt(player._trail_points.size(), 0, "Trail points should be recorded during boost")
	assert_gt(player._trail_line.points.size(), 0, "Trail line should have points during boost")

func test_boost_trail_clears_when_not_boosting():
	var player = _create_player()
	player._trail_points.push_front(Vector2(100, 100))
	player.boost_active = false
	player._update_boost_trail()
	assert_eq(player._trail_points.size(), 0, "Trail points should be cleared when not boosting")
	assert_eq(player._trail_line.points.size(), 0, "Trail line should be empty when not boosting")
