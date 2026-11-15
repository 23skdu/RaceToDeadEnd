extends Area2D

var damage: int = 1
var stun_duration: float = 2.0
var expand_speed: float = 400.0
var max_radius: float = 400.0
var current_radius: float = 0.0
var _col_shape: CollisionShape2D
var _pooled: bool = false
var _stunned_bodies: Array[Node] = []
var _shockwave_rect: ColorRect
var _shockwave_material: ShaderMaterial
static var _shared_shockwave_shader: Shader = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("emp")
	body_entered.connect(_on_body_entered)
	_col_shape = $CollisionShape2D
	_col_shape.disabled = false
	_setup_shockwave_distortion()
	_update_collision_radius()

func _setup_shockwave_distortion() -> void:
	if not _shared_shockwave_shader:
		_shared_shockwave_shader = Shader.new()
		_shared_shockwave_shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float ring_progress : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_strength = 0.035;
void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;
	float ring_radius = clamp(ring_progress, 0.0, 1.0);
	float band = smoothstep(ring_radius - 0.12, ring_radius, dist) * (1.0 - smoothstep(ring_radius, ring_radius + 0.08, dist));
	vec2 dir = dist > 0.0001 ? centered / (dist * 0.5) : vec2(0.0);
	vec2 offset = dir * band * distortion_strength * (1.0 - ring_progress * 0.7);
	vec4 col = texture(screen_texture, SCREEN_UV - offset);
	vec3 ring_glow = vec3(0.2, 0.9, 1.0) * band * (1.0 - ring_progress) * 0.65;
	COLOR = vec4(col.rgb + ring_glow, band * (1.0 - ring_progress * 0.85));
}
"""
	_shockwave_material = ShaderMaterial.new()
	_shockwave_material.shader = _shared_shockwave_shader
	_shockwave_material.set_shader_parameter("ring_progress", 0.0)
	_shockwave_rect = ColorRect.new()
	_shockwave_rect.name = "ShockwaveDistortion"
	_shockwave_rect.size = Vector2(max_radius * 2.0, max_radius * 2.0)
	_shockwave_rect.position = Vector2(-max_radius, -max_radius)
	_shockwave_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shockwave_rect.material = _shockwave_material
	add_child(_shockwave_rect)

func init(pos: Vector2) -> void:
	global_position = pos
	_pooled = has_meta("_pool_name")
	current_radius = 0.0
	_stunned_bodies.clear()
	if _col_shape and _col_shape.shape is CircleShape2D:
		_col_shape.shape.radius = 0.0
	_update_shockwave_uniforms()

func on_pool_acquire() -> void:
	current_radius = 0.0
	_stunned_bodies.clear()
	_update_shockwave_uniforms()

func on_pool_release() -> void:
	current_radius = 0.0
	_stunned_bodies.clear()
	_update_shockwave_uniforms()

func _process(delta: float) -> void:
	current_radius = move_toward(current_radius, max_radius, expand_speed * delta)
	_update_collision_radius()
	if current_radius >= max_radius:
		if _pooled:
			ObjectPool.release(self)
		else:
			queue_free()

func _update_collision_radius() -> void:
	if _col_shape and _col_shape.shape is CircleShape2D:
		_col_shape.shape.radius = current_radius
	_update_shockwave_uniforms()

func _update_shockwave_uniforms() -> void:
	if _shockwave_material:
		var progress := clampf(current_radius / maxf(max_radius, 1.0), 0.0, 1.0)
		_shockwave_material.set_shader_parameter("ring_progress", progress)
	var visual := get_node_or_null("Visual")
	if visual:
		var vis_scale := maxf(0.5, current_radius / 16.0)
		visual.scale = Vector2(vis_scale, vis_scale)
		visual.modulate.a = clampf(1.0 - (current_radius / maxf(max_radius, 1.0)), 0.0, 1.0)

func _on_body_entered(body: Node) -> void:
	if body in _stunned_bodies:
		return
	_stunned_bodies.append(body)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	if is_instance_valid(body) and not body.get_meta("_in_pool", false) and body.has_method("apply_stun"):
		body.apply_stun(stun_duration)
