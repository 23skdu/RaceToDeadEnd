extends "res://addons/gut/test.gd"

func test_drone_transparency():
	var tex = load("res://assets/sprites/enemies/drone.png")
	assert_not_null(tex)
	var img = tex.get_image()
	assert_not_null(img)
	
	var w = img.get_width()
	var h = img.get_height()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "Top-left corner of drone must be transparent")
	assert_eq(img.get_pixel(w-1, 0).a, 0.0, "Top-right corner of drone must be transparent")
	assert_eq(img.get_pixel(0, h-1).a, 0.0, "Bottom-left corner of drone must be transparent")
	assert_eq(img.get_pixel(w-1, h-1).a, 0.0, "Bottom-right corner of drone must be transparent")

func test_rotor_transparency():
	var tex = load("res://assets/sprites/enemies/rotor.png")
	assert_not_null(tex)
	var img = tex.get_image()
	assert_not_null(img)
	
	var w = img.get_width()
	var h = img.get_height()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "Top-left corner of rotor must be transparent")
	assert_eq(img.get_pixel(w-1, 0).a, 0.0, "Top-right corner of rotor must be transparent")
	assert_eq(img.get_pixel(0, h-1).a, 0.0, "Bottom-left corner of rotor must be transparent")
	assert_eq(img.get_pixel(w-1, h-1).a, 0.0, "Bottom-right corner of rotor must be transparent")

func test_scav_transparency():
	var tex = load("res://assets/sprites/enemies/scav.png")
	assert_not_null(tex)
	var img = tex.get_image()
	assert_not_null(img)
	
	var w = img.get_width()
	var h = img.get_height()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "Top-left corner of scav must be transparent")
	assert_eq(img.get_pixel(w-1, 0).a, 0.0, "Top-right corner of scav must be transparent")
	assert_eq(img.get_pixel(0, h-1).a, 0.0, "Bottom-left corner of scav must be transparent")
	assert_eq(img.get_pixel(w-1, h-1).a, 0.0, "Bottom-right corner of scav must be transparent")
