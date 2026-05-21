extends GutTest

var Garage

func before_all():
	Garage = load("res://scenes/ui/Garage.tscn")

func before_each():
	var save_path = "user://save.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	GameManager.credits = 0
	GameManager.high_score = 0
	GameManager.score = 0
	GameManager.state = GameManager.GameState.MENU
	for key in GameManager.upgrade_levels:
		GameManager.upgrade_levels[key] = 1

func test_upgrade_costs_defined():
	var script = load("res://scenes/ui/Garage.gd")
	assert_true(script.UPGRADE_COSTS.has("max_health"), "max_health costs")
	assert_true(script.UPGRADE_COSTS.has("boost_capacity"), "boost_capacity costs")
	assert_true(script.UPGRADE_COSTS.has("fire_rate"), "fire_rate costs")
	assert_true(script.UPGRADE_COSTS.has("missile_ammo"), "missile_ammo costs")
	assert_true(script.UPGRADE_COSTS.has("mine_ammo"), "mine_ammo costs")
	assert_true(script.UPGRADE_COSTS.has("emp_ammo"), "emp_ammo costs")

func test_upgrade_names_defined():
	var script = load("res://scenes/ui/Garage.gd")
	assert_eq(script.UPGRADE_NAMES.max_health, "MAX HEALTH", "max_health name")
	assert_eq(script.UPGRADE_NAMES.boost_capacity, "BOOST CAPACITY", "boost_capacity name")
	assert_eq(script.UPGRADE_NAMES.fire_rate, "FIRE RATE", "fire_rate name")
	assert_eq(script.UPGRADE_NAMES.missile_ammo, "MISSILE AMMO", "missile_ammo name")
	assert_eq(script.UPGRADE_NAMES.mine_ammo, "MINE AMMO", "mine_ammo name")
	assert_eq(script.UPGRADE_NAMES.emp_ammo, "EMP AMMO", "emp_ammo name")

func test_upgrade_cost_progression():
	var script = load("res://scenes/ui/Garage.gd")
	var health_costs = script.UPGRADE_COSTS.max_health
	assert_eq(health_costs[1], 500, "Health level 1 cost")
	assert_eq(health_costs[2], 1500, "Health level 2 cost")
	assert_eq(health_costs[3], 3000, "Health level 3 cost")
	assert_eq(health_costs[4], 5000, "Health level 4 cost")

func test_missile_ammo_costs():
	var script = load("res://scenes/ui/Garage.gd")
	var costs = script.UPGRADE_COSTS.missile_ammo
	assert_eq(costs[1], 150, "Missile level 1 cost")
	assert_eq(costs[2], 400, "Missile level 2 cost")
	assert_eq(costs[3], 1000, "Missile level 3 cost")
	assert_eq(costs[4], 2000, "Missile level 4 cost")

func test_mine_ammo_costs():
	var script = load("res://scenes/ui/Garage.gd")
	var costs = script.UPGRADE_COSTS.mine_ammo
	assert_eq(costs[1], 200, "Mine level 1 cost")
	assert_eq(costs[2], 500, "Mine level 2 cost")
	assert_eq(costs[3], 1200, "Mine level 3 cost")
	assert_eq(costs[4], 2500, "Mine level 4 cost")

func test_emp_ammo_costs():
	var script = load("res://scenes/ui/Garage.gd")
	var costs = script.UPGRADE_COSTS.emp_ammo
	assert_eq(costs[1], 250, "EMP level 1 cost")
	assert_eq(costs[2], 700, "EMP level 2 cost")
	assert_eq(costs[3], 1500, "EMP level 3 cost")
	assert_eq(costs[4], 3000, "EMP level 4 cost")

func test_max_level_is_5():
	var script = load("res://scenes/ui/Garage.gd")
	var costs = script.UPGRADE_COSTS.max_health
	assert_eq(costs.size(), 5, "Should have 5 levels (index 0-4)")

func test_all_upgrades_have_5_levels():
	var script = load("res://scenes/ui/Garage.gd")
	for key in script.UPGRADE_COSTS:
		assert_eq(script.UPGRADE_COSTS[key].size(), 5, key + " should have 5 levels")

func _create_garage():
	var garage = Garage.instantiate()
	add_child_autofree(garage)
	return garage

func test_garage_displays_credits():
	GameManager.credits = 999
	var garage = _create_garage()
	garage.refresh()
	assert_true("999" in garage.credits_label.text, "Should display credits")

func test_garage_upgrade_at_max_level():
	GameManager.upgrade_levels["max_health"] = 4
	var garage = _create_garage()
	garage.refresh()
	var max_found = false
	for child in garage.upgrade_container.get_children():
		if child is Button and "[MAX]" in child.text:
			max_found = true
			assert_true(child.disabled, "Max level button should be disabled")
	assert_true(max_found, "Should show MAX level indicator")

func test_garage_upgrade_insufficient_credits():
	GameManager.credits = 10
	GameManager.upgrade_levels["max_health"] = 1
	var garage = _create_garage()
	garage.refresh()
	var disabled_found = false
	for child in garage.upgrade_container.get_children():
		if child is Button and "MAX HEALTH" in child.text and "[MAX]" not in child.text:
			if child.disabled:
				disabled_found = true
	assert_true(disabled_found, "Should disable button when insufficient credits")

func test_garage_back_emits_signal():
	var garage = _create_garage()
	watch_signals(garage)
	garage._on_back_pressed()
	assert_signal_emitted(garage, "back_to_menu_requested", "Should emit back signal")

func test_garage_start_emits_signal():
	var garage = _create_garage()
	watch_signals(garage)
	garage._on_start_pressed()
	assert_signal_emitted(garage, "start_run_requested", "Should emit start signal")

func test_garage_spend_credits():
	GameManager.credits = 1000
	GameManager.upgrade_levels["max_health"] = 1
	var garage = _create_garage()
	garage._on_upgrade_pressed("max_health", 500)
	assert_eq(GameManager.upgrade_levels["max_health"], 2, "Upgrade level should increase")
	assert_eq(GameManager.credits, 500, "Credits should decrease")

func test_garage_ready_connects_buttons():
	var garage = _create_garage()
	assert_true(garage.back_button.pressed.is_connected(garage._on_back_pressed), "Back button should be connected")
	assert_true(garage.start_button.pressed.is_connected(garage._on_start_pressed), "Start button should be connected")

func test_garage_shows_all_weapon_upgrades():
	GameManager.credits = 99999
	var garage = _create_garage()
	garage.refresh()
	var found_missile = false
	var found_mine = false
	var found_emp = false
	for child in garage.upgrade_container.get_children():
		if child is Button:
			if "MISSILE AMMO" in child.text:
				found_missile = true
			if "MINE AMMO" in child.text:
				found_mine = true
			if "EMP AMMO" in child.text:
				found_emp = true
	assert_true(found_missile, "Should show missile ammo upgrade")
	assert_true(found_mine, "Should show mine ammo upgrade")
	assert_true(found_emp, "Should show emp ammo upgrade")

func test_garage_upgrade_missile_ammo():
	GameManager.credits = 1000
	GameManager.upgrade_levels["missile_ammo"] = 1
	var garage = _create_garage()
	garage._on_upgrade_pressed("missile_ammo", 150)
	assert_eq(GameManager.upgrade_levels["missile_ammo"], 2, "Missile ammo level should increase")
	assert_eq(GameManager.credits, 850, "Credits should decrease by missile cost")

func test_garage_upgrade_mine_ammo():
	GameManager.credits = 1000
	GameManager.upgrade_levels["mine_ammo"] = 1
	var garage = _create_garage()
	garage._on_upgrade_pressed("mine_ammo", 200)
	assert_eq(GameManager.upgrade_levels["mine_ammo"], 2, "Mine ammo level should increase")
	assert_eq(GameManager.credits, 800, "Credits should decrease by mine cost")

func test_garage_upgrade_emp_ammo():
	GameManager.credits = 1000
	GameManager.upgrade_levels["emp_ammo"] = 1
	var garage = _create_garage()
	garage._on_upgrade_pressed("emp_ammo", 250)
	assert_eq(GameManager.upgrade_levels["emp_ammo"], 2, "EMP ammo level should increase")
	assert_eq(GameManager.credits, 750, "Credits should decrease by emp cost")

func test_garage_six_upgrades_displayed():
	GameManager.credits = 99999
	var garage = _create_garage()
	garage.refresh()
	var button_count = 0
	for child in garage.upgrade_container.get_children():
		if child is Button:
			button_count += 1
	assert_eq(button_count, 6, "Should display 6 upgrade buttons")
