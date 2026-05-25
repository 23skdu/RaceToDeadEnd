extends RefCounted

static func scale_sprite_to_viewport(sprite: Sprite2D, base_size: float = 64.0, base_viewport: float = 1280.0) -> void:
	if not sprite or not sprite.texture:
		return
	var viewport = sprite.get_viewport()
	if not viewport:
		return
	var viewport_rect = viewport.get_visible_rect()
	if viewport_rect.size.x <= 0:
		return
	var viewport_width = viewport_rect.size.x
	var scale_factor = viewport_width / base_viewport
	var target_size = base_size * scale_factor
	var tex_height = sprite.texture.get_height()
	if tex_height <= 0:
		return
	sprite.scale = Vector2(target_size / tex_height, target_size / tex_height)
