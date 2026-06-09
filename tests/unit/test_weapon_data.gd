extends GutTest

func test_weapon_data_extends_resource():
	var wd = load("res://scripts/resources/WeaponData.gd").new()
	assert_true(wd is Resource, "Should extend Resource")

func test_weapon_data_defaults():
	var wd = load("res://scripts/resources/WeaponData.gd").new()
	assert_eq(wd.type_name, "", "Default type_name")
	assert_eq(wd.display_name, "", "Default display_name")
	assert_eq(wd.color, Color.WHITE, "Default color")
	assert_eq(wd.icon, null, "Default icon")
	assert_eq(wd.base_ammo, 0, "Default base_ammo")
	assert_eq(wd.description, "", "Default description")

func test_weapon_data_sets_values():
	var wd = load("res://scripts/resources/WeaponData.gd").new()
	wd.type_name = "machine_gun"
	wd.display_name = "Machine Gun"
	wd.color = Color.RED
	wd.base_ammo = 50
	wd.description = "Rapid fire weapon"
	assert_eq(wd.type_name, "machine_gun", "type_name should be settable")
	assert_eq(wd.display_name, "Machine Gun", "display_name should be settable")
	assert_eq(wd.color, Color.RED, "color should be settable")
	assert_eq(wd.base_ammo, 50, "base_ammo should be settable")
	assert_eq(wd.description, "Rapid fire weapon", "description should be settable")

func test_weapon_data_export_vars():
	var wd = load("res://scripts/resources/WeaponData.gd").new()
	var props = wd.get_property_list()
	var prop_names = []
	for p in props:
		prop_names.append(p.name)
	assert_true("type_name" in prop_names, "type_name should be exported")
	assert_true("display_name" in prop_names, "display_name should be exported")
	assert_true("color" in prop_names, "color should be exported")
	assert_true("icon" in prop_names, "icon should be exported")
	assert_true("base_ammo" in prop_names, "base_ammo should be exported")
	assert_true("description" in prop_names, "description should be exported")
