extends Node2D

const RoadmapFx = preload("res://scripts/utils/RoadmapFx.gd")

signal weather_changed(weather_type: String)
signal lightning_strike(position: Vector2)

enum WeatherType { CLEAR, LIGHT_RAIN, ACID_RAIN, STORM }

var current_weather: WeatherType = WeatherType.CLEAR
var target_weather: WeatherType = WeatherType.CLEAR
var weather_transition: float = 0.0
var weather_intensity: float = 0.0
var acid_rain_timer: float = 0.0
var lightning_timer: float = 0.0
var player_ref: Node = null
var highway_ref: Node = null

var active_clouds: Array[Node2D] = []
var white_texture: Texture2D

var _rain_particles: GPUParticles2D
var _rain_particle_material: ParticleProcessMaterial
var _splash_particles: GPUParticles2D
var _splash_particle_material: ParticleProcessMaterial
var _wet_reflection_rect: ColorRect
var _wet_reflection_material: ShaderMaterial
var _wetness: float = 0.0
var _prev_overlay_color: Color = Constants.ACID_OVERLAY_CLEAR
var _target_overlay_color: Color = Constants.ACID_OVERLAY_CLEAR

@onready var cloud_container: Node2D = $CloudContainer
@onready var lightning_container: Node2D = $LightningContainer
@onready var acid_overlay: ColorRect = $WeatherCanvas/AcidOverlay

func _ready() -> void:
	white_texture = _create_white_texture()
	_init_gpu_particles()
	_init_wet_reflection()
	_set_weather(WeatherType.CLEAR)

func _init_gpu_particles() -> void:
	_rain_particles = GPUParticles2D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.z_index = 10
	_rain_particles.amount = RoadmapFx.scaled_particle_amount(Constants.RAIN_DROP_COUNT)
	_rain_particles.lifetime = 1.5
	_rain_particles.one_shot = false
	_rain_particles.emitting = false
	_rain_particles.local_coords = false

	var rain_image = Image.create(2, 12, false, Image.FORMAT_RGBA8)
	rain_image.fill(Constants.RAIN_DROPLET_COLOR)
	rain_image.set_pixel(0, 0, Constants.RAIN_DROPLET_ZERO_ALPHA)
	rain_image.set_pixel(1, 0, Constants.RAIN_DROPLET_ZERO_ALPHA)
	rain_image.set_pixel(0, 11, Constants.RAIN_DROPLET_ZERO_ALPHA)
	rain_image.set_pixel(1, 11, Constants.RAIN_DROPLET_ZERO_ALPHA)
	var rain_tex = ImageTexture.create_from_image(rain_image)
	_rain_particles.texture = rain_tex

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 15.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 400.0
	mat.initial_velocity_max = 600.0
	mat.scale_min = 1.0
	mat.scale_max = 1.0
	mat.color = Constants.RAIN_DROPLET_COLOR
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(800.0, 0.0, 0.0)

	_rain_particle_material = mat
	_rain_particles.process_material = mat
	_rain_particles.position = Vector2(0, -600)
	add_child(_rain_particles)

	_splash_particles = GPUParticles2D.new()
	_splash_particles.name = "RainSplashes"
	_splash_particles.z_index = 2
	_splash_particles.amount = RoadmapFx.scaled_particle_amount(64)
	_splash_particles.lifetime = 0.28
	_splash_particles.one_shot = false
	_splash_particles.emitting = false
	_splash_particles.local_coords = false
	var splash_img = Image.create(4, 2, false, Image.FORMAT_RGBA8)
	splash_img.fill(Color(0.75, 0.9, 1.0, 0.65))
	_splash_particles.texture = ImageTexture.create_from_image(splash_img)
	var splash_mat = ParticleProcessMaterial.new()
	splash_mat.direction = Vector3(0, -1, 0)
	splash_mat.spread = 75.0
	splash_mat.gravity = Vector3(0, 120, 0)
	splash_mat.initial_velocity_min = 25.0
	splash_mat.initial_velocity_max = 60.0
	splash_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	splash_mat.emission_box_extents = Vector3(480.0, 260.0, 0.0)
	_splash_particle_material = splash_mat
	_splash_particles.process_material = splash_mat
	add_child(_splash_particles)

func _init_wet_reflection() -> void:
	var canvas = get_node_or_null("WeatherCanvas")
	if not canvas:
		return
	_wet_reflection_rect = ColorRect.new()
	_wet_reflection_rect.name = "WetRoadReflection"
	_wet_reflection_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wet_reflection_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float wetness = 0.0;
uniform vec4 reflection_tint : source_color = vec4(1.0, 0.25, 0.75, 1.0);
void fragment() {
	float band = sin(UV.y * 80.0 + TIME * 5.0) * 0.5 + 0.5;
	float road_mask = smoothstep(0.18, 0.45, UV.x) * (1.0 - smoothstep(0.55, 0.82, UV.x));
	float shimmer = pow(band, 4.0) * road_mask * wetness * 0.14;
	COLOR = vec4(reflection_tint.rgb, shimmer);
}
"""
	_wet_reflection_material = ShaderMaterial.new()
	_wet_reflection_material.shader = shader
	_wet_reflection_material.set_shader_parameter("wetness", 0.0)
	_wet_reflection_rect.material = _wet_reflection_material
	_wet_reflection_rect.visible = false
	canvas.add_child(_wet_reflection_rect)
	canvas.move_child(_wet_reflection_rect, 0)

func _process(delta: float) -> void:
	_update_weather_transition(delta)
	_update_rain_particles(delta)
	_update_clouds(delta)
	_update_acid_rain_damage(delta)
	_try_spawn_lightning(delta)

func _update_weather_transition(delta: float) -> void:
	if current_weather != target_weather:
		weather_transition += delta * 0.5
		if weather_transition >= 1.0:
			weather_transition = 1.0
			current_weather = target_weather
			_update_visuals_for_weather(target_weather)
			weather_changed.emit(_weather_name(current_weather))
		
		weather_intensity = weather_transition if target_weather > current_weather else 1.0 - weather_transition
		if acid_overlay:
			if current_weather == target_weather:
				acid_overlay.color = _target_overlay_color
			else:
				acid_overlay.color = _prev_overlay_color.lerp(_target_overlay_color, weather_intensity)
	else:
		weather_intensity = 1.0 if current_weather != WeatherType.CLEAR else 0.0

func _update_rain_particles(_delta: float) -> void:
	var gpu_on: bool = RoadmapFx.gpu_effects_enabled()
	if not gpu_on:
		_rain_particles.emitting = false
		if _splash_particles:
			_splash_particles.emitting = false
		return
	if _splash_particles and player_ref and is_instance_valid(player_ref):
		_splash_particles.global_position = player_ref.global_position + Vector2(0, -140)
	match current_weather:
		WeatherType.CLEAR:
			_rain_particles.emitting = false
			if _splash_particles:
				_splash_particles.emitting = false
			_set_wetness(0.0, Color(1.0, 0.25, 0.75, 1.0))
			return
		WeatherType.LIGHT_RAIN:
			_rain_particles.amount_ratio = 0.5 * weather_intensity
			var c = Constants.RAIN_PARTICLE_CLEAR
			_rain_particle_material.color = Color(c.r, c.g, c.b, c.a * weather_intensity)
			if _splash_particle_material:
				_splash_particle_material.color = Color(0.7, 0.85, 1.0, 0.55 * weather_intensity)
			_set_wetness(0.35 * weather_intensity, Color(0.3, 0.75, 1.0, 1.0))
		WeatherType.ACID_RAIN:
			_rain_particles.amount_ratio = weather_intensity
			var c = Constants.RAIN_PARTICLE_ACID
			_rain_particle_material.color = Color(c.r, c.g, c.b, c.a * weather_intensity)
			if _splash_particle_material:
				_splash_particle_material.color = Color(0.3, 1.0, 0.3, 0.7 * weather_intensity)
			_set_wetness(0.55 * weather_intensity, Color(0.2, 1.0, 0.35, 1.0))
		WeatherType.STORM:
			_rain_particles.amount_ratio = weather_intensity
			var c = Constants.RAIN_PARTICLE_STORM
			_rain_particle_material.color = Color(c.r, c.g, c.b, c.a * weather_intensity)
			if _splash_particle_material:
				_splash_particle_material.color = Color(0.6, 0.9, 1.0, 0.75 * weather_intensity)
			_set_wetness(0.85 * weather_intensity, Color(1.0, 0.25, 0.75, 1.0))
	_rain_particles.emitting = _rain_particles.amount_ratio > 0.0
	if _splash_particles:
		_splash_particles.amount_ratio = _rain_particles.amount_ratio
		_splash_particles.emitting = _rain_particles.emitting

func _set_wetness(val: float, tint: Color) -> void:
	_wetness = clampf(val, 0.0, 1.0)
	if _wet_reflection_rect and _wet_reflection_material:
		_wet_reflection_rect.visible = _wetness > 0.01
		_wet_reflection_material.set_shader_parameter("wetness", _wetness)
		_wet_reflection_material.set_shader_parameter("reflection_tint", tint)

func _update_clouds(delta: float) -> void:
	if current_weather == WeatherType.ACID_RAIN or current_weather == WeatherType.STORM:
		var target_clouds = Constants.CLOUD_COUNT if current_weather == WeatherType.STORM else 3
		while active_clouds.size() < target_clouds:
			_spawn_cloud()
		
		for cloud in active_clouds:
			var cloud_speed = cloud.get_meta("speed", 20.0)
			cloud.position.x += cloud_speed * delta
			if cloud.position.x > 700:
				cloud.position.x = -100
	else:
		for cloud in active_clouds:
			cloud.queue_free()
		active_clouds.clear()

func _update_acid_rain_damage(delta: float) -> void:
	if current_weather == WeatherType.ACID_RAIN or current_weather == WeatherType.STORM:
		acid_rain_timer -= delta
		if acid_rain_timer <= 0.0:
			acid_rain_timer = Constants.ACID_RAIN_DAMAGE_INTERVAL
			if player_ref and is_instance_valid(player_ref):
				if player_ref.has_method("take_damage"):
					player_ref.take_damage(Constants.ACID_RAIN_DAMAGE)

func _try_spawn_lightning(delta: float) -> void:
	if current_weather != WeatherType.STORM:
		return
	
	lightning_timer -= delta
	if lightning_timer <= 0.0:
		lightning_timer = randf_range(1.0, 3.0)
		if randf() < Constants.LIGHTNING_CHANCE_PER_SECOND * 10.0:
			_spawn_lightning_strike()

func _spawn_lightning_strike() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	var strike_x = player_ref.global_position.x + randf_range(-150, 150)
	var strike_y = player_ref.global_position.y - 700
	var strike_pos = Vector2(strike_x, strike_y)
	
	_create_lightning_bolt(strike_pos)
	
	var flash = _create_lightning_flash(strike_pos)
	lightning_container.add_child(flash)
	RoadmapFx.spawn_explosion_flash(lightning_container, strike_pos, Color(0.8, 0.9, 1.0, 1.0), 0.35, 2.5)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): if is_instance_valid(flash): flash.queue_free())
	
	lightning_strike.emit(strike_pos)
	AudioManager.play_lightning_strike(strike_pos)
	
	if player_ref:
		var dist = strike_pos.distance_to(player_ref.global_position)
		if dist < 80.0:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(Constants.LIGHTNING_DAMAGE)

func _create_lightning_bolt(start_pos: Vector2) -> void:
	var bolt = Line2D.new()
	bolt.width = 3.0
	bolt.default_color = Constants.LIGHTNING_BOLT_COLOR
	
	var points = PackedVector2Array()
	var current = start_pos
	points.append(current)
	
	for i in 8:
		current.y += 50.0
		current.x += randf_range(-30, 30)
		points.append(current)
	
	bolt.points = points
	lightning_container.add_child(bolt)
	
	var tween = create_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): if is_instance_valid(bolt): bolt.queue_free())

func _create_lightning_flash(pos: Vector2) -> Node:
	var flash = ColorRect.new()
	flash.size = Vector2(200, 200)
	flash.position = pos - Vector2(100, 100)
	flash.color = Constants.LIGHTNING_FLASH_COLOR
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return flash

func _spawn_cloud() -> void:
	var cloud = Node2D.new()
	cloud.position = Vector2(randf_range(-100, 600), randf_range(-700, -350))
	cloud.set_meta("speed", randf_range(15.0, 35.0))
	
	var cloud_body = Polygon2D.new()
	var points = PackedVector2Array()
	var radius = randf_range(40, 70)
	for i in 8:
		var angle = (i / 8.0) * TAU
		var r = radius * randf_range(0.6, 1.0)
		points.append(Vector2(cos(angle) * r, sin(angle) * r * 0.5))
	cloud_body.polygon = points
	cloud_body.color = Constants.CLOUD_BODY_COLOR
	cloud.add_child(cloud_body)
	
	if current_weather == WeatherType.ACID_RAIN or current_weather == WeatherType.STORM:
		var glow = Polygon2D.new()
		glow.polygon = points
		glow.color = Constants.CLOUD_GLOW_COLOR
		cloud.add_child(glow)
	
	cloud_container.add_child(cloud)
	active_clouds.append(cloud)

func _set_weather(type: WeatherType) -> void:
	current_weather = type
	target_weather = type
	weather_transition = 1.0
	weather_intensity = 1.0 if type != WeatherType.CLEAR else 0.0
	_prev_overlay_color = _overlay_color_for(type)
	_target_overlay_color = _overlay_color_for(type)
	
	_update_visuals_for_weather(type)
	weather_changed.emit(_weather_name(type))

func _update_visuals_for_weather(type: WeatherType) -> void:
	match type:
		WeatherType.CLEAR:
			if acid_overlay:
				acid_overlay.color = Constants.ACID_OVERLAY_CLEAR
		WeatherType.LIGHT_RAIN:
			if acid_overlay:
				acid_overlay.color = Constants.ACID_OVERLAY_CLEAR
		WeatherType.ACID_RAIN:
			if acid_overlay:
				acid_overlay.color = Constants.ACID_OVERLAY_COLOR_LIGHT
		WeatherType.STORM:
			if acid_overlay:
				acid_overlay.color = Constants.ACID_OVERLAY_COLOR_HEAVY

func set_weather(type: WeatherType) -> void:
	if target_weather != type:
		_prev_overlay_color = _overlay_color_for(target_weather) if acid_overlay else Constants.ACID_OVERLAY_CLEAR
		_target_overlay_color = _overlay_color_for(type)
		target_weather = type
		weather_transition = 0.0
		weather_changed.emit(_weather_name(type))

func get_color_grading_lut(weather_name: String = "") -> Texture2D:
	if not RoadmapFx.hdr_lighting_enabled():
		return null
	var key: String = weather_name if not weather_name.is_empty() else _weather_name(current_weather)
	return RoadmapFx.make_weather_lut(key)

func get_color_grading_tint(type: WeatherType = current_weather) -> Color:
	match type:
		WeatherType.ACID_RAIN:
			return Color(0.7, 1.0, 0.7, 1.0)
		WeatherType.STORM:
			return Color(0.7, 0.75, 0.85, 1.0)
		WeatherType.LIGHT_RAIN:
			return Color(0.9, 0.95, 1.0, 1.0)
		_:
			return Color.WHITE

func _overlay_color_for(type: WeatherType) -> Color:
	match type:
		WeatherType.ACID_RAIN: return Constants.ACID_OVERLAY_COLOR_LIGHT
		WeatherType.STORM: return Constants.ACID_OVERLAY_COLOR_HEAVY
		_: return Constants.ACID_OVERLAY_CLEAR

func set_player(p: Node) -> void:
	player_ref = p

func set_highway(h: Node) -> void:
	highway_ref = h

func _weather_name(type: WeatherType) -> String:
	match type:
		WeatherType.CLEAR: return "clear"
		WeatherType.LIGHT_RAIN: return "light_rain"
		WeatherType.ACID_RAIN: return "acid_rain"
		WeatherType.STORM: return "storm"
		_: return "unknown"

func _create_white_texture() -> Texture2D:
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)