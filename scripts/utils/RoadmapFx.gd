## Shared helpers for roadmap items 1, 2, 3 and 8.
## Every feature is gated through SettingsManager so it can be disabled at runtime.
extends RefCounted

const FEATURE_GPU_EFFECTS: String = "gpu_effects"
const FEATURE_LIGHTING_EFFECTS: String = "lighting_effects"
const FEATURE_MOTION_INTERPOLATION: String = "motion_interpolation"
const FEATURE_HDR_LIGHTING: String = "hdr_lighting"

const PARTICLE_SCALE_SETTING: String = "particle_scale"
const MAX_PARTICLE_AMOUNT: int = 16384
const LUT_SIZE: int = 16

static var _glow_texture_cache: Dictionary = {}
static var _ring_texture_cache: Dictionary = {}
static var _weather_lut_cache: Dictionary = {}


static func gpu_effects_enabled() -> bool:
	if not SettingsManager:
		return false
	return SettingsManager.is_feature_enabled(FEATURE_GPU_EFFECTS, true)


static func lighting_effects_enabled() -> bool:
	if not SettingsManager:
		return false
	return SettingsManager.is_feature_enabled(FEATURE_LIGHTING_EFFECTS, true)


static func motion_interpolation_enabled() -> bool:
	if not SettingsManager:
		return false
	return SettingsManager.is_feature_enabled(FEATURE_MOTION_INTERPOLATION, true)


static func hdr_lighting_enabled() -> bool:
	if not SettingsManager:
		return false
	return SettingsManager.is_feature_enabled(FEATURE_HDR_LIGHTING, true)


static func scaled_particle_amount(base_amount: int, scale_override: float = -1.0) -> int:
	var scale: float = scale_override
	if scale < 0.0:
		scale = 1.0
		if SettingsManager:
			var raw: Variant = SettingsManager.get_roadmap_value(PARTICLE_SCALE_SETTING, 1.0)
			if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
				scale = float(raw)
	if is_nan(scale) or is_inf(scale):
		scale = 1.0
	scale = clampf(scale, 0.05, 4.0)
	var amount: int = roundi(float(maxi(base_amount, 0)) * scale)
	return clampi(amount, 1, MAX_PARTICLE_AMOUNT)


static func make_glow_texture(size: int, tint: Color) -> Texture2D:
	var side: int = clampi(size, 2, 256)
	var cache_key: String = "%d:%s" % [side, tint.to_html(true)]
	if _glow_texture_cache.has(cache_key) and is_instance_valid(_glow_texture_cache[cache_key]):
		return _glow_texture_cache[cache_key]
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var center := Vector2(side * 0.5, side * 0.5)
	var radius: float = maxf(side * 0.5, 1.0)
	for x in side:
		for y in side:
			var dist: float = Vector2(float(x), float(y)).distance_to(center) / radius
			var alpha: float = pow(clampf(1.0 - dist, 0.0, 1.0), 2.0)
			img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, alpha * tint.a))
	var tex := ImageTexture.create_from_image(img)
	if _glow_texture_cache.size() < 32:
		_glow_texture_cache[cache_key] = tex
	return tex


static func make_ring_texture(size: int = 64, thickness: float = 0.16, tint: Color = Color(1.0, 0.55, 0.2, 1.0)) -> Texture2D:
	var side: int = clampi(size, 8, 256)
	var band: float = maxf(thickness, 0.02)
	var cache_key: String = "%d:%.3f:%s" % [side, band, tint.to_html(true)]
	if _ring_texture_cache.has(cache_key) and is_instance_valid(_ring_texture_cache[cache_key]):
		return _ring_texture_cache[cache_key]
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var center := Vector2(side * 0.5, side * 0.5)
	var radius: float = maxf(side * 0.5, 1.0)
	for x in side:
		for y in side:
			var dist: float = Vector2(float(x), float(y)).distance_to(center) / radius
			var alpha: float = clampf(1.0 - absf(dist - 0.42) / band, 0.0, 1.0)
			img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, alpha * tint.a))
	var tex := ImageTexture.create_from_image(img)
	if _ring_texture_cache.size() < 32:
		_ring_texture_cache[cache_key] = tex
	return tex


static func make_explosion_emitter() -> GPUParticles2D:
	var emitter := GPUParticles2D.new()
	emitter.name = "ExplosionShockwave"
	emitter.one_shot = true
	emitter.local_coords = false
	emitter.lifetime = 0.5
	emitter.amount = scaled_particle_amount(32)
	emitter.texture = make_ring_texture()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 180.0
	mat.initial_velocity_max = 280.0
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	mat.color = Color(1.0, 0.5, 0.15, 0.9)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	emitter.process_material = mat
	emitter.emitting = false
	return emitter


static func spawn_explosion_flash(parent: Node, world_position: Vector2, tint: Color = Color(1.0, 0.55, 0.25, 1.0), duration: float = 0.3, energy: float = 3.0) -> PointLight2D:
	if not lighting_effects_enabled() or not parent or not parent.is_inside_tree():
		return null
	var light := PointLight2D.new()
	light.name = "ExplosionFlash"
	light.texture = make_glow_texture(64, Color.WHITE)
	light.texture_scale = 3.0
	light.color = tint
	light.energy = maxf(energy, 0.0)
	parent.add_child(light)
	light.global_position = world_position
	var tween := parent.create_tween()
	tween.tween_property(light, "energy", 0.0, clampf(duration, 0.02, 2.0))
	tween.tween_callback(func():
		if is_instance_valid(light):
			light.queue_free()
	)
	return light


static func make_occluder_polygon(points: PackedVector2Array, closed: bool = true) -> OccluderPolygon2D:
	var polygon := OccluderPolygon2D.new()
	var clean := PackedVector2Array()
	for point in points:
		if is_finite(point.x) and is_finite(point.y):
			clean.append(point)
	if clean.size() >= 3:
		polygon.polygon = clean
	polygon.closed = closed
	polygon.cull_mode = OccluderPolygon2D.CULL_DISABLED
	return polygon


static func create_light_occluder(points: PackedVector2Array, closed: bool = true) -> LightOccluder2D:
	var occluder := LightOccluder2D.new()
	occluder.occluder = make_occluder_polygon(points, closed)
	# A disabled lighting feature keeps the geometry but stops it casting shadows.
	occluder.occluder_light_mask = 1 if lighting_effects_enabled() else 0
	return occluder


static func interpolate_transform(from: Transform2D, to: Transform2D, alpha: float) -> Transform2D:
	var weight: float = alpha
	if is_nan(weight) or is_inf(weight):
		weight = 0.0
	weight = clampf(weight, 0.0, 1.0)
	var start: Transform2D = from if from.is_finite() else Transform2D.IDENTITY
	var end: Transform2D = to if to.is_finite() else Transform2D.IDENTITY
	var rotation: float = lerp_angle(start.get_rotation(), end.get_rotation(), weight)
	var scale: Vector2 = start.get_scale().lerp(end.get_scale(), weight)
	var skew: float = lerpf(start.get_skew(), end.get_skew(), weight)
	var origin: Vector2 = start.origin.lerp(end.origin, weight)
	return Transform2D(rotation, scale, skew, origin)


static func make_weather_lut(weather: String) -> Texture2D:
	var key: String = weather.strip_edges().to_lower()
	var canonical_key: String = "clear"
	match key:
		"rain", "light_rain":
			canonical_key = "light_rain"
		"acid_rain":
			canonical_key = "acid_rain"
		"storm":
			canonical_key = "storm"
	if _weather_lut_cache.has(canonical_key) and is_instance_valid(_weather_lut_cache[canonical_key]):
		return _weather_lut_cache[canonical_key]
	var stops := PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
	])
	match canonical_key:
		"light_rain":
			stops = PackedColorArray([
				Color(0.78, 0.88, 1.0, 1.0),
				Color(0.9, 0.95, 1.0, 1.0),
				Color(1.0, 1.0, 1.0, 1.0),
			])
		"acid_rain":
			stops = PackedColorArray([
				Color(0.55, 0.9, 0.5, 1.0),
				Color(0.85, 1.0, 0.75, 1.0),
				Color(1.0, 1.0, 0.95, 1.0),
			])
		"storm":
			stops = PackedColorArray([
				Color(0.35, 0.4, 0.55, 1.0),
				Color(0.7, 0.75, 0.85, 1.0),
				Color(0.95, 0.95, 1.0, 1.0),
			])
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = stops
	var lut := GradientTexture1D.new()
	lut.gradient = gradient
	lut.width = LUT_SIZE
	_weather_lut_cache[canonical_key] = lut
	return lut


static func apply_weather_lut(environment: Environment, weather: String) -> void:
	if not hdr_lighting_enabled() or not environment:
		return
	environment.adjustment_enabled = true
	environment.adjustment_color_correction = make_weather_lut(weather)
