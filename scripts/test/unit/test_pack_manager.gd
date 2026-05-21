extends GutTest

var _pm

func before_all():
	pass

func before_each():
	_pm = load("res://scripts/autoload/PackManager.gd").new()
	add_child_autofree(_pm)

func test_initial_state():
	assert_true(typeof(_pm.discovered_packs) == TYPE_DICTIONARY, "discovered_packs is a dictionary")
	assert_eq(_pm.active_packs.music, "", "music pack initially empty")
	assert_eq(_pm.active_packs.skin, "", "skin pack initially empty")
	assert_eq(_pm.active_packs.theme, "", "theme pack initially empty")

func test_valid_hex_color():
	assert_true(_pm._is_valid_hex_color("#123456"), "Valid hex color")
	assert_false(_pm._is_valid_hex_color("123456"), "Missing #")
	assert_false(_pm._is_valid_hex_color("#123"), "Too short")
	assert_false(_pm._is_valid_hex_color("#1234567"), "Too long")

func test_validate_manifest_missing_fields():
	var valid_data = {
		"pack_id": "test_pack",
		"name": "Test Pack",
		"content_types": ["theme"]
	}
	var folder = "test_pack"
	
	assert_true(_pm._validate_manifest(valid_data, folder), "Valid manifest")
	
	var no_id = valid_data.duplicate()
	no_id.erase("pack_id")
	assert_false(_pm._validate_manifest(no_id, folder), "Missing pack_id")
	
	var no_name = valid_data.duplicate()
	no_name.erase("name")
	assert_false(_pm._validate_manifest(no_name, folder), "Missing name")
	
	var no_types = valid_data.duplicate()
	no_types.erase("content_types")
	assert_false(_pm._validate_manifest(no_types, folder), "Missing content_types")

func test_validate_manifest_invalid_id():
	var valid_data = {
		"pack_id": "test pack", # Invalid format (spaces)
		"name": "Test Pack",
		"content_types": []
	}
	assert_false(_pm._validate_manifest(valid_data, "test_pack"), "Invalid pack_id format")

func test_activate_pack_not_found():
	assert_false(_pm.activate_pack("nonexistent", "theme"), "Cannot activate non-existent pack")

func test_activate_and_deactivate():
	_pm.discovered_packs["test_theme"] = {
		"data": { "pack_id": "test_theme", "name": "Test", "content_types": ["theme"] },
		"folder": "user://packs/test_theme",
		"size": 100
	}
	assert_true(_pm.activate_pack("test_theme", "theme"), "Should activate pack")
	assert_eq(_pm.get_active_pack_id("theme"), "test_theme", "Pack should be active")
	
	_pm.deactivate_pack("theme")
	assert_eq(_pm.get_active_pack_id("theme"), "", "Pack should be deactivated")
