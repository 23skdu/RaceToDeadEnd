extends RefCounted

static func scale_sprite_to_viewport(sprite: Sprite2D, base_size: float = 64.0, _base_viewport: float = 1280.0) -> void:
	if not sprite or not sprite.texture:
		return
	var tex_height = sprite.texture.get_height()
	if tex_height <= 0:
		return
	# Set sprite scale to the design size relative to texture height.
	# Viewport-level dynamic scaling is handled perfectly at the parent World level!
	sprite.scale = Vector2(base_size / tex_height, base_size / tex_height)
