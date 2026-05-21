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

func test_hud_weapon_display_bounds_check():
	var hud = _create_hud()
	hud.update_weapon_display(5, 3)
	assert_eq(hud.ammo_label.text, "3", "Ammo should still update with out-of-bounds index")

func test_hud_weapon_display_negative_index():
	var hud = _create_hud()
	hud.update_weapon_display(-1, 0)
	assert_eq(hud.ammo_label.text, "0", "Ammo should still update with negative index")

func test_hud_weapon_colors_constant():
	var hud_script = load("res://scripts/scenes/ui/HUD.gd")
	assert_eq(hud_script.WEAPON_COLORS.size(), 3, "Should have 3 weapon colors")
	assert_eq(hud_script.WEAPON_COLORS[0], Color.RED, "Missile color should be red")
	assert_eq(hud_script.WEAPON_COLORS[1], Color.YELLOW, "Mine color should be yellow")
	assert_eq(hud_script.WEAPON_COLORS[2], Color.CYAN, "EMP color should be cyan")
