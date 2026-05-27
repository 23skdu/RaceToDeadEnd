extends GutTest

func _create_hud():
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	return hud

func test_hud_score_update():
	var hud = _create_hud()
	hud._on_score_updated(1234)
	assert_eq(hud.score_label.text, "1234", "Score label should update")

func test_hud_health_update():
	var hud = _create_hud()
	hud._on_health_updated(3)
	assert_eq(hud.health_bar.value, 3, "Health bar should update")

func test_hud_multiplier_update():
	var hud = _create_hud()
	hud._on_multiplier_updated(4)
	assert_eq(hud.multiplier_label.text, "x4", "Multiplier label should update")

func test_hud_tier_update():
	var hud = _create_hud()
	hud._on_tier_changed(5)
	assert_eq(hud.tier_label.text, "TIER 5", "Tier label should update")

func test_hud_boost_charges_update():
	var hud = _create_hud()
	hud.update_boost_charges(2)
	var visible_count = 0
	for indicator in hud.boost_indicators:
		if indicator.visible:
			visible_count += 1
	assert_eq(visible_count, 2, "Should show 2 boost indicators")

func test_hud_boost_charges_zero():
	var hud = _create_hud()
	hud.update_boost_charges(0)
	var visible_count = 0
	for indicator in hud.boost_indicators:
		if indicator.visible:
			visible_count += 1
	assert_eq(visible_count, 0, "Should show 0 boost indicators")

func test_hud_weapon_display_missile():
	var hud = _create_hud()
	hud.update_weapon_display(0, 3)
	assert_eq(hud.weapon_icon.modulate, Color.RED, "Missile icon should be red")
	assert_eq(hud.ammo_label.text, "3", "Ammo label should show 3")

func test_hud_weapon_display_mine():
	var hud = _create_hud()
	hud.update_weapon_display(1, 2)
	assert_eq(hud.weapon_icon.modulate, Color.YELLOW, "Mine icon should be yellow")
	assert_eq(hud.ammo_label.text, "2", "Ammo label should show 2")

func test_hud_weapon_display_emp():
	var hud = _create_hud()
	hud.update_weapon_display(2, 1)
	assert_eq(hud.weapon_icon.modulate, Color.CYAN, "EMP icon should be cyan")
	assert_eq(hud.ammo_label.text, "1", "Ammo label should show 1")

func test_hud_game_over_hides():
	var hud = _create_hud()
	hud.visible = true
	hud._on_game_over()
	assert_false(hud.visible, "HUD should hide on game over")

func test_hud_ready_connects_signals():
	var hud = _create_hud()
	assert_true(GameManager.score_updated.is_connected(hud._on_score_updated), "Should connect score signal")
	assert_true(GameManager.health_updated.is_connected(hud._on_health_updated), "Should connect health signal")
	assert_true(GameManager.multiplier_updated.is_connected(hud._on_multiplier_updated), "Should connect multiplier signal")
	assert_true(GameManager.difficulty_tier_changed.is_connected(hud._on_tier_changed), "Should connect tier signal")
	assert_true(GameManager.multiplier_timer_updated.is_connected(hud._on_multiplier_timer_updated), "Should connect multiplier timer signal")

func test_hud_multiplier_timer_bar_hidden_by_default():
	var hud = _create_hud()
	assert_false(hud.multiplier_timer_bar.visible, "Multiplier timer bar should be hidden initially")

func test_hud_multiplier_timer_updates_bar():
	var hud = _create_hud()
	hud._on_multiplier_timer_updated(5.0)
	assert_true(hud.multiplier_timer_bar.visible, "Bar should be visible when timer active")
	assert_eq(hud.multiplier_timer_bar.value, 50.0, "Bar should show 50% at 5s remaining")

func test_hud_weapon_display_bounds_check():
	var hud = _create_hud()
	hud.update_weapon_display(5, 3)
	assert_eq(hud.ammo_label.text, "3", "Ammo should still update with out-of-bounds index")

func test_hud_weapon_display_negative_index():
	var hud = _create_hud()
	hud.update_weapon_display(-1, 0)
	assert_eq(hud.ammo_label.text, "0", "Ammo should still update with negative index")

func test_hud_weapon_colors_from_constants():
	assert_eq(Constants.WEAPON_DATA.size(), 3, "Should have 3 weapon data entries")
	assert_eq(Constants.WEAPON_DATA[0].type_name, "missile", "First weapon should be missile")
	assert_eq(Constants.WEAPON_DATA[1].type_name, "mine", "Second weapon should be mine")
	assert_eq(Constants.WEAPON_DATA[2].type_name, "emp", "Third weapon should be emp")

func test_hud_set_boost_active_changes_modulate():
	var hud = _create_hud()
	for indicator in hud.boost_indicators:
		indicator.modulate = Color.WHITE
	hud.set_boost_active(true)
	assert_true(hud._boost_active, "Boost active flag should be set")
	hud.set_boost_active(false)
	assert_false(hud._boost_active, "Boost active flag should be cleared")
	for indicator in hud.boost_indicators:
		assert_eq(indicator.modulate, Color.WHITE, "Indicators should return to white after boost deactivates")

# --- Lives Label Tests ---

func test_hud_lives_label_exists():
	var hud = _create_hud()
	assert_not_null(hud.lives_label, "HUD should have a lives_label node")

func test_hud_lives_update():
	var hud = _create_hud()
	hud._on_lives_updated(2)
	assert_true(hud.lives_label.text.contains("2"), "Lives label should show the current lives count")

func test_hud_lives_update_zero():
	var hud = _create_hud()
	hud._on_lives_updated(0)
	assert_true(hud.lives_label.text.contains("0"), "Lives label should show 0 when no lives remain")

func test_hud_ready_connects_lives_signal():
	var hud = _create_hud()
	assert_true(GameManager.lives_updated.is_connected(hud._on_lives_updated), "Should connect lives_updated signal on ready")

func test_hud_update_weapons_shows_only_available():
	var hud = _create_hud()
	hud.update_weapons(0, [3, 0, 1])
	assert_true(hud.missile_panel.visible, "Missile panel should be visible since ammo > 0")
	assert_false(hud.mine_panel.visible, "Mine panel should be hidden since ammo == 0")
	assert_true(hud.emp_panel.visible, "EMP panel should be visible since ammo > 0")
	assert_eq(hud.missile_panel.modulate.a, 1.0, "Active weapon panel should have full opacity")
	assert_almost_eq(hud.emp_panel.modulate.a, 0.4, 0.01, "Inactive weapon panel should be translucent")
	assert_true(hud.missile_label.text.contains("3"), "Missile label should show count 3")
	assert_true(hud.emp_label.text.contains("1"), "EMP label should show count 1")

func test_hud_top_weather_border_instantiated():
	var hud = _create_hud()
	var wb = hud.get_node_or_null("TopWeatherBorder")
	assert_not_null(wb, "TopWeatherBorder node should be dynamically instantiated in HUD")
	assert_true(wb is Control, "TopWeatherBorder should be a Control node")
	assert_eq(wb.current_weather, "clear", "Default weather should be clear")

