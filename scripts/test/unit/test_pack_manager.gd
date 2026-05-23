extends GutTest

var _pm

func before_each():
	_pm = load("res://scripts/autoload/PackManager.gd").new()
	add_child_autofree(_pm)

func test_signals_exist():
	assert_true(_pm.pack_discovered is Signal)
	assert_true(_pm.pack_activated is Signal)
	assert_true(_pm.pack_deactivated is Signal)
	assert_true(_pm.pack_validation_failed is Signal)
	assert_true(_pm.skin_loaded is Signal)
	assert_true(_pm.theme_color_loaded is Signal)
	assert_true(_pm.theme_texture_loaded is Signal)

func test_custom_signals_exist():
	var names = []
	for s in _pm.get_signal_list():
		names.append(s.name)
	assert_true("pack_discovered" in names)
	assert_true("pack_activated" in names)
	assert_true("pack_deactivated" in names)
	assert_true("pack_validation_failed" in names)
	assert_true("skin_loaded" in names)
	assert_true("theme_color_loaded" in names)
	assert_true("theme_texture_loaded" in names)

func test_get_discovered_pack_ids_empty_initial():
	assert_eq(_pm.get_discovered_pack_ids(), [])

func test_get_pack_info_unknown():
	assert_eq(_pm.get_pack_info("unknown_pack"), {})

func test_get_active_pack_id_returns_empty_for_unknown():
	assert_eq(_pm.get_active_pack_id("music"), "")
	assert_eq(_pm.get_active_pack_id("skin"), "")
	assert_eq(_pm.get_active_pack_id("theme"), "")

func test_activate_pack_returns_false_for_unknown():
	assert_false(_pm.activate_pack("nonexistent", "theme"))

func test_validate_manifest_rejects_missing_pack_id():
	var data = {"name": "Test", "content_types": []}
	assert_false(_pm._validate_manifest(data, "test"))

func test_validate_manifest_rejects_invalid_pack_id_with_spaces():
	var data = {"pack_id": "test pack", "name": "Test", "content_types": []}
	assert_false(_pm._validate_manifest(data, "test_pack"))

func test_validate_manifest_rejects_invalid_pack_id_with_special_chars():
	var data = {"pack_id": "test@pack!", "name": "Test", "content_types": []}
	assert_false(_pm._validate_manifest(data, "test_pack"))

func test_validate_manifest_rejects_missing_name():
	var data = {"pack_id": "valid_pack", "content_types": []}
	assert_false(_pm._validate_manifest(data, "valid_pack"))

func test_validate_manifest_rejects_missing_content_types():
	var data = {"pack_id": "valid_pack", "name": "Test"}
	assert_false(_pm._validate_manifest(data, "valid_pack"))

func test_validate_manifest_rejects_non_array_content_types():
	var data = {"pack_id": "valid_pack", "name": "Test", "content_types": "not_array"}
	assert_false(_pm._validate_manifest(data, "valid_pack"))

func test_is_valid_hex_color_true():
	assert_true(_pm._is_valid_hex_color("#FF0000"))

func test_is_valid_hex_color_false_no_hash():
	assert_false(_pm._is_valid_hex_color("FF0000"))

func test_is_valid_hex_color_false_too_short():
	assert_false(_pm._is_valid_hex_color("#FFF"))

func test_is_valid_hex_color_false_too_long():
	assert_false(_pm._is_valid_hex_color("#FFFFFF00"))

func test_validate_content_section_skin_missing_file_emits_validation_failed():
	watch_signals(_pm)
	var data = {"pack_id": "test_pack", "name": "Test", "content_types": ["skin"], "skins": {"player": "nonexistent.png"}}
	_pm._validate_content_section(data, "skin", "/tmp/fake")
	assert_signal_emitted(_pm, "pack_validation_failed")

func test_validate_content_section_theme_invalid_color_emits_validation_failed():
	watch_signals(_pm)
	var data = {"pack_id": "test_pack", "name": "Test", "content_types": ["theme"], "theme": {"palette": {"bg": "notacolor"}}}
	_pm._validate_content_section(data, "theme", "/tmp/fake")
	assert_signal_emitted(_pm, "pack_validation_failed")

func test_valid_manifest_passes_validation():
	var data = {"pack_id": "valid_pack", "name": "Valid", "content_types": []}
	assert_true(_pm._validate_manifest(data, "valid_pack"))

func test_activate_pack_too_large_returns_false():
	_pm.discovered_packs["big"] = {"data": {"pack_id": "big"}, "folder": "", "size": 999999999}
	assert_false(_pm.activate_pack("big", "theme"))

func test_activate_pack_sets_active():
	_pm.discovered_packs["test_theme"] = {"data": {"pack_id": "test_theme"}, "folder": "", "size": 100}
	assert_true(_pm.activate_pack("test_theme", "theme"))
	assert_eq(_pm.active_packs.theme, "test_theme")

func test_activate_pack_emits_signal():
	watch_signals(_pm)
	_pm.discovered_packs["test_pack"] = {"data": {"pack_id": "test_pack"}, "folder": "", "size": 100}
	_pm.activate_pack("test_pack", "music")
	assert_signal_emitted(_pm, "pack_activated")

func test_deactivate_pack_clears_active():
	_pm.active_packs.theme = "test_theme"
	_pm.deactivate_pack("theme")
	assert_eq(_pm.active_packs.theme, "")

func test_deactivate_pack_emits_signal():
	watch_signals(_pm)
	_pm.active_packs.theme = "test_theme"
	_pm.deactivate_pack("theme")
	assert_signal_emitted(_pm, "pack_deactivated")

func test_discover_pack_adds_to_discovered():
	_pm.discovered_packs = {"existing": {}}
	assert_eq(_pm.get_discovered_pack_ids().size(), 1)
