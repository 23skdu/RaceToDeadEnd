extends GutTest

var Garage

func before_all():
	Garage = load("res://scenes/ui/Garage.gd")

func test_upgrade_costs_defined():
	var script = Garage
	assert_true(script.UPGRADE_COSTS.has("max_health"), "max_health costs")
	assert_true(script.UPGRADE_COSTS.has("boost_capacity"), "boost_capacity costs")
	assert_true(script.UPGRADE_COSTS.has("starting_ammo"), "starting_ammo costs")
	assert_true(script.UPGRADE_COSTS.has("fire_rate"), "fire_rate costs")

func test_upgrade_names_defined():
	var script = Garage
	assert_eq(script.UPGRADE_NAMES.max_health, "MAX HEALTH", "max_health name")
	assert_eq(script.UPGRADE_NAMES.boost_capacity, "BOOST CAPACITY", "boost_capacity name")
	assert_eq(script.UPGRADE_NAMES.starting_ammo, "STARTING AMMO", "starting_ammo name")
	assert_eq(script.UPGRADE_NAMES.fire_rate, "FIRE RATE", "fire_rate name")

func test_upgrade_cost_progression():
	var script = Garage
	var health_costs = script.UPGRADE_COSTS.max_health
	assert_eq(health_costs[1], 500, "Health level 1 cost")
	assert_eq(health_costs[2], 1500, "Health level 2 cost")
	assert_eq(health_costs[3], 3000, "Health level 3 cost")
	assert_eq(health_costs[4], 5000, "Health level 4 cost")

func test_max_level_is_5():
	var script = Garage
	var costs = script.UPGRADE_COSTS.max_health
	assert_eq(costs.size(), 5, "Should have 5 levels (index 0-4)")

func test_garage_displays_credits():
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.credits = 999
	var garage = Garage.new()
	add_child_autofree(garage)
	garage.refresh()
	assert_true("999" in garage.credits_label.text, "Should display credits")

func test_garage_upgrade_at_max_level():
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.upgrade_levels["max_health"] = 4
	var garage = Garage.new()
	add_child_autofree(garage)
	garage.refresh()
	var max_found = false
	for child in garage.upgrade_container.get_children():
		if child is Button and "[MAX]" in child.text:
			max_found = true
			assert_true(child.disabled, "Max level button should be disabled")
	assert_true(max_found, "Should show MAX level indicator")

func test_garage_upgrade_insufficient_credits():
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.credits = 10
	gm.upgrade_levels["max_health"] = 1
	var garage = Garage.new()
	add_child_autofree(garage)
	garage.refresh()
	var disabled_found = false
	for child in garage.upgrade_container.get_children():
		if child is Button and "MAX HEALTH" in child.text and "[MAX]" not in child.text:
			if child.disabled:
				disabled_found = true
	assert_true(disabled_found, "Should disable button when insufficient credits")

func test_garage_back_emits_signal():
	var garage = Garage.new()
	add_child_autofree(garage)
	watch_signals(garage)
	garage._on_back_pressed()
	assert_signal_emitted(garage, "back_to_menu_requested", "Should emit back signal")

func test_garage_start_emits_signal():
	var garage = Garage.new()
	add_child_autofree(garage)
	watch_signals(garage)
	garage._on_start_pressed()
	assert_signal_emitted(garage, "start_run_requested", "Should emit start signal")

func test_garage_spend_credits():
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.credits = 1000
	gm.upgrade_levels["max_health"] = 1
	var garage = Garage.new()
	add_child_autofree(garage)
	garage._on_upgrade_pressed("max_health", 500)
	assert_eq(gm.upgrade_levels["max_health"], 2, "Upgrade level should increase")
	assert_eq(gm.credits, 500, "Credits should decrease")

func test_garage_ready_connects_buttons():
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	var garage = Garage.new()
	add_child_autofree(garage)
	assert_true(garage.back_button.pressed.is_connected(garage._on_back_pressed), "Back button should be connected")
	assert_true(garage.start_button.pressed.is_connected(garage._on_start_pressed), "Start button should be connected")
