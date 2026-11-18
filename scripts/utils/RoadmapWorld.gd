extends RefCounted

## Pure helpers shared by the roadmap rendering features (items 2, 7, 8, 9, 10, 12).
## Kept side-effect free where practical so GUT tests can assert the maths directly.

const FEATURE_TILEMAP_HIGHWAY: String = "tilemap_highway"
const FEATURE_REAR_VIEW: String = "rear_view"
const FEATURE_FSR_UPSCALING: String = "fsr_upscaling"
const FEATURE_RICH_HUD: String = "rich_hud"
const FEATURE_LIGHTING: String = "lighting_enabled"
const FEATURE_HDR: String = "hdr_tonemapping"
const FEATURE_WEATHER_LUT: String = "weather_luts"
const FEATURE_SSAO: String = "ssao_approximation"
const FEATURE_MOTION_INTERPOLATION: String = "motion_interpolation_enabled"

const KEY_RESOLUTION: String = "resolution"
const KEY_HUD_TEXT_SCALE: String = "hud_text_scale"

const DEFAULT_RESOLUTION: Vector2i = Vector2i(1280, 720)
const MIN_RESOLUTION: Vector2i = Vector2i(640, 360)
const MAX_RESOLUTION: Vector2i = Vector2i(3840, 2160)
const CONTENT_ASPECT_16_9: float = 16.0 / 9.0
const ULTRAWIDE_ASPECT: float = 21.0 / 9.0
const SUPER_ULTRAWIDE_ASPECT: float = 32.0 / 9.0
const SUPPORTED_RESOLUTIONS: Array = [
	Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080),
	Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 1080),
	Vector2i(3840, 2160),
]

const FSR_SHADER_CODE: String = "shader_type canvas_item;\nrender_mode unshaded;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;\nuniform float sharpness : hint_range(0.0, 1.0) = 0.35;\nvoid fragment() {\n\tvec2 px = SCREEN_PIXEL_SIZE;\n\tvec3 c = texture(screen_texture, SCREEN_UV).rgb;\n\tvec3 n = texture(screen_texture, SCREEN_UV + vec2(0.0, px.y)).rgb;\n\tvec3 s = texture(screen_texture, SCREEN_UV - vec2(0.0, px.y)).rgb;\n\tvec3 e = texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0)).rgb;\n\tvec3 w = texture(screen_texture, SCREEN_UV - vec2(px.x, 0.0)).rgb;\n\tvec3 blurred = (c * 4.0 + n + s + e + w) / 8.0;\n\tvec3 sharpened = c + (c - blurred) * sharpness;\n\tCOLOR = vec4(clamp(sharpened, 0.0, 1.0), 1.0);\n}"
const LUT_SHADER_CODE: String = "shader_type canvas_item;\nrender_mode unshaded;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;\nuniform sampler2D lut;\nuniform float lut_strength : hint_range(0.0, 1.0) = 0.35;\nvoid fragment() {\n\tvec3 src = texture(screen_texture, SCREEN_UV).rgb;\n\tfloat lum = clamp(dot(src, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);\n\tvec3 graded = texture(lut, vec2(lum, 0.5)).rgb;\n\tCOLOR = vec4(mix(src, src * graded, lut_strength), 1.0);\n}"
const SSAO_SHADER_CODE: String = "shader_type canvas_item;\nrender_mode unshaded;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;\nuniform float strength : hint_range(0.0, 1.0) = 0.25;\nvoid fragment() {\n\tvec2 px = SCREEN_PIXEL_SIZE * 2.0;\n\tvec3 c = texture(screen_texture, SCREEN_UV).rgb;\n\tfloat lc = dot(c, vec3(0.299, 0.587, 0.114));\n\tfloat ln = dot(texture(screen_texture, SCREEN_UV + vec2(0.0, px.y)).rgb, vec3(0.299, 0.587, 0.114));\n\tfloat ls = dot(texture(screen_texture, SCREEN_UV - vec2(0.0, px.y)).rgb, vec3(0.299, 0.587, 0.114));\n\tfloat le = dot(texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));\n\tfloat lw = dot(texture(screen_texture, SCREEN_UV - vec2(px.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));\n\tfloat neighbors = min(min(ln, ls), min(le, lw));\n\tfloat occlusion = clamp(lc - neighbors, 0.0, 1.0);\n\tCOLOR = vec4(c * (1.0 - occlusion * strength), 1.0);\n}"

static var _light_texture: Texture2D = null

# --- Aspect / resolution maths -------------------------------------------------

static func aspect_ratio(width: float, height: float) -> float:
	if width <= 0.0 or height <= 0.0:
		return 0.0
	return width / height

static func aspect_category(aspect: float) -> String:
	if aspect <= 0.0 or is_nan(aspect) or is_inf(aspect):
		return "invalid"
	if aspect >= SUPER_ULTRAWIDE_ASPECT - 0.15:
		return "super_ultrawide"
	if aspect >= ULTRAWIDE_ASPECT - 0.15:
		return "ultrawide"
	return "standard"

static func is_ultrawide(aspect: float) -> bool:
	var category := aspect_category(aspect)
	return category == "ultrawide" or category == "super_ultrawide"

static func letterbox_rect(viewport_size: Vector2, content_aspect: float) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var target_aspect := content_aspect
	if target_aspect <= 0.0 or is_nan(target_aspect) or is_inf(target_aspect):
		target_aspect = CONTENT_ASPECT_16_9
	var viewport_aspect := aspect_ratio(viewport_size.x, viewport_size.y)
	if viewport_aspect <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var width := viewport_size.x
	var height := viewport_size.y
	if viewport_aspect > target_aspect:
		width = height * target_aspect
	else:
		height = width / target_aspect
	return Rect2(
		Vector2((viewport_size.x - width) * 0.5, (viewport_size.y - height) * 0.5),
		Vector2(width, height)
	)

static func viewport_scale_factor(viewport_size: Vector2) -> float:
	var content := letterbox_rect(viewport_size, CONTENT_ASPECT_16_9)
	if content.size.x <= 0.0:
		return 1.0
	return clampf(content.size.x / float(DEFAULT_RESOLUTION.x), 0.25, 4.0)

static func parse_resolution(text: String) -> Vector2i:
	var parts: PackedStringArray = text.strip_edges().replace("x", " ").replace("X", " ").replace(",", " ").replace(":", " ").split(" ", false)
	if parts.size() < 2:
		return Vector2i.ZERO
	var width := parts[0].to_int()
	var height := parts[1].to_int()
	if width <= 0 or height <= 0:
		return Vector2i.ZERO
	return Vector2i(width, height)

static func sanitize_resolution(value: Variant) -> Vector2i:
	var parsed := Vector2i.ZERO
	if value is Vector2i:
		parsed = value as Vector2i
	elif value is Vector2:
		var vec := value as Vector2
		parsed = Vector2i(int(vec.x), int(vec.y))
	elif value is String:
		parsed = parse_resolution(value as String)
	elif value is Array:
		var arr := value as Array
		if arr.size() >= 2:
			parsed = Vector2i(int(arr[0]), int(arr[1]))
	if parsed.x <= 0 or parsed.y <= 0:
		return DEFAULT_RESOLUTION
	if parsed.x > MAX_RESOLUTION.x or parsed.y > MAX_RESOLUTION.y:
		return MAX_RESOLUTION
	return Vector2i(
		clampi(parsed.x, MIN_RESOLUTION.x, MAX_RESOLUTION.x),
		clampi(parsed.y, MIN_RESOLUTION.y, MAX_RESOLUTION.y)
	)

static func resolution_to_string(resolution: Vector2i) -> String:
	return "%dx%d" % [maxi(0, resolution.x), maxi(0, resolution.y)]

# --- HUD / BBCode helpers ------------------------------------------------------

static func clamp_text_scale(value: Variant) -> float:
	var scale_value := 1.0
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		scale_value = float(value)
	elif typeof(value) == TYPE_STRING:
		scale_value = (value as String).to_float()
	if scale_value <= 0.0 or is_nan(scale_value) or is_inf(scale_value):
		return 1.0
	return clampf(scale_value, 0.5, 3.0)

static func scaled_font_size(base_size: int, scale: float) -> int:
	if base_size <= 0:
		return 1
	return clampi(int(round(float(base_size) * clamp_text_scale(scale))), 1, 128)

static func bbcode_text(text: String, color: String, bold: bool = true) -> String:
	var clean := color if color.begins_with("#") else "#ffffff"
	var inner := text
	if bold:
		inner = "[b]%s[/b]" % text
	return "[color=%s]%s[/color]" % [clean, inner]

static func bbcode_color(tier: int) -> String:
	if tier >= 12:
		return "#ff3366"
	if tier >= 8:
		return "#ff8800"
	if tier >= 5:
		return "#00f0ff"
	if tier >= 3:
		return "#a0ff60"
	return "#ffffff"

static func damage_tier(amount: int) -> int:
	if amount >= 5:
		return 3
	if amount >= 3:
		return 2
	if amount >= 2:
		return 1
	return 0

static func damage_bbcode(text: String, amount: int) -> String:
	var colors: Array[String] = ["#ffffff", "#a0ff60", "#ffcc00", "#ff3366"]
	var tier := clampi(damage_tier(amount), 0, colors.size() - 1)
	return bbcode_text(text, colors[tier], true)

static func enemy_density(active_count: int, reference_count: int) -> float:
	if active_count <= 0 or reference_count <= 0:
		return 0.0
	return clampf(float(active_count) / float(reference_count), 0.0, 1.0)

# --- Weather / lighting helpers ------------------------------------------------

static func weather_name(weather_type: int) -> String:
	match weather_type:
		1:
			return "light_rain"
		2:
			return "acid_rain"
		3:
			return "storm"
		_:
			return "clear"

static func weather_grade_color(weather: String, tier: int) -> Color:
	var target := Color.WHITE
	if tier >= 12:
		target = Color(0.85, 0.9, 1.0, 1.0)
	elif tier >= 8:
		target = Color(0.9, 0.95, 1.0, 1.0)
	elif tier >= 5:
		target = Color(0.95, 0.98, 1.0, 1.0)
	match weather:
		"acid_rain":
			return target.lerp(Color(0.7, 1.0, 0.7, 1.0), 0.35)
		"storm":
			return target.lerp(Color(0.7, 0.75, 0.85, 1.0), 0.45)
		"light_rain":
			return target.lerp(Color(0.85, 0.92, 1.0, 1.0), 0.2)
		_:
			return target

static func make_weather_lut(weather: String) -> Texture2D:
	var fx_path := "res://scripts/utils/RoadmapFx.gd"
	if ResourceLoader.exists(fx_path):
		var fx = load(fx_path)
		if fx != null and fx.has_method("make_weather_lut"):
			var tex = fx.make_weather_lut(weather)
			if tex is Texture2D:
				return tex as Texture2D
	return _make_gradient_lut(weather)

static func _make_gradient_lut(weather: String) -> Texture2D:
	var img := Image.create(16, 1, false, Image.FORMAT_RGBA8)
	var bottom := Color.WHITE
	match weather:
		"acid_rain":
			bottom = Color(0.55, 1.0, 0.55, 1.0)
		"storm":
			bottom = Color(0.5, 0.6, 0.85, 1.0)
		"light_rain":
			bottom = Color(0.8, 0.9, 1.0, 1.0)
	for i in 16:
		img.set_pixel(i, 0, Color.WHITE.lerp(bottom, float(i) / 15.0))
	return ImageTexture.create_from_image(img)

static func make_lut_material(lut: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = LUT_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	if lut != null:
		material.set_shader_parameter("lut", lut)
	return material

static func make_fsr_material(sharpness: float = 0.35) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = FSR_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("sharpness", clampf(sharpness, 0.0, 1.0))
	return material

static func make_ssao_material(strength: float = 0.25) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SSAO_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("strength", clampf(strength, 0.0, 1.0))
	return material

static func occluder_polygon(kind: String, size: Vector2) -> PackedVector2Array:
	var half_w := maxf(2.0, size.x) * 0.5
	var half_h := maxf(2.0, size.y) * 0.5
	if kind == "circle":
		var points := PackedVector2Array()
		for i in 12:
			var angle := TAU * float(i) / 12.0
			points.append(Vector2(cos(angle) * half_w, sin(angle) * half_h))
		return points
	return PackedVector2Array([
		Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
		Vector2(half_w, half_h), Vector2(-half_w, half_h),
	])

static func make_light_occluder(kind: String, size: Vector2) -> LightOccluder2D:
	var polygon := occluder_polygon(kind, size)
	var shape := OccluderPolygon2D.new()
	shape.polygon = polygon
	shape.closed = true
	var occluder := LightOccluder2D.new()
	occluder.name = "RoadmapOccluder"
	occluder.occluder = shape
	return occluder

static func make_light_texture() -> Texture2D:
	if _light_texture != null:
		return _light_texture
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var dist := Vector2(float(x) - float(size) * 0.5, float(y) - float(size) * 0.5).length() / (float(size) * 0.5)
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))
	_light_texture = ImageTexture.create_from_image(img)
	return _light_texture

static func make_flash_light(color: Color = Color.WHITE) -> PointLight2D:
	var light := PointLight2D.new()
	light.name = "ExplosionFlash"
	light.texture = make_light_texture()
	light.texture_scale = 2.0
	light.color = color
	light.energy = 3.0
	return light

static func make_reactor_light(color: Color = Color(0.2, 0.9, 1.0, 1.0)) -> PointLight2D:
	var light := PointLight2D.new()
	light.name = "BossReactorLight"
	light.texture = make_light_texture()
	light.texture_scale = 1.5
	light.color = color
	light.energy = 1.8
	return light
