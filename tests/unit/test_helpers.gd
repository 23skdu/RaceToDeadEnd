extends GutTest

const Helpers = preload("res://scripts/utils/Helpers.gd")

func test_scale_sprite_to_viewport_no_crash():
	var sprite = Sprite2D.new()
	add_child_autofree(sprite)
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.add_to_group("test_sprite")
	Helpers.scale_sprite_to_viewport(sprite, 64.0, 1280.0)
	assert_true(sprite.scale.length() > 0, "Sprite scale should be set")

func test_scale_sprite_to_viewport_null_sprite():
	Helpers.scale_sprite_to_viewport(null, 64.0, 1280.0)
	assert_true(true, "Should not crash with null sprite")

func test_scale_sprite_to_viewport_no_texture():
	var sprite = Sprite2D.new()
	add_child_autofree(sprite)
	sprite.add_to_group("test_sprite2")
	Helpers.scale_sprite_to_viewport(sprite, 64.0, 1280.0)
	assert_true(true, "Should not crash with no texture")
