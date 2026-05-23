extends Node

static func scale_sprite_to_viewport(sprite: Sprite2D, base_size: float = 64.0, base_viewport: float = 1280.0) -> void:
	if not sprite or not sprite.texture:
		return
	var viewport = sprite.get_viewport()
	if not viewport:
		return
	var viewport_width = viewport.get_visible_rect().size.x
	var scale_factor = viewport_width / base_viewport
	var target_size = base_size * scale_factor
	var tex_height = sprite.texture.get_height()
	sprite.scale = Vector2(target_size / tex_height, target_size / tex_height)
