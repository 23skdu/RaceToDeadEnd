extends Node2D

@export_group("Weather Timing")
@export var transition_speed: float = 0.5
@export var lightning_cooldown_min: float = 1.0
@export var lightning_cooldown_max: float = 3.0

@export_group("Weather Effects")
@export var acid_damage_interval: float = Constants.ACID_RAIN_DAMAGE_INTERVAL
@export var acid_damage_amount: int = Constants.ACID_RAIN_DAMAGE
@export var rain_drop_count: int = Constants.RAIN_DROP_COUNT

signal weather_changed(weather_type: String)
signal lightning_strike(position: Vector2)

enum WeatherType { CLEAR, LIGHT_RAIN, ACID_RAIN, STORM }

const RAIN_DROP_COUNT: int = Constants.RAIN_DROP_COUNT
const LIGHTNING_DAMAGE: int = Constants.LIGHTNING_DAMAGE
const ACID_RAIN_DAMAGE_INTERVAL: float = Constants.ACID_RAIN_DAMAGE_INTERVAL
const ACID_RAIN_DAMAGE: int = Constants.ACID_RAIN_DAMAGE
const CLOUD_COUNT: int = Constants.CLOUD_COUNT
const LIGHTNING_CHANCE_PER_SECOND: float = Constants.LIGHTNING_CHANCE_PER_SECOND

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

@onready var cloud_container: Node2D = $CloudContainer
@onready var lightning_container: Node2D = $LightningContainer
@onready var acid_overlay: ColorRect = $WeatherCanvas/AcidOverlay

func _ready() -> void:
	white_texture = _create_white_texture()
	_init_gpu_particles()
	_set_weather(WeatherType.CLEAR)

func _init_gpu_particles() -> void:
	_rain_particles = GPUParticles2D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.z_index = 10
	_rain_particles.amount = RAIN_DROP_COUNT
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
	_rain_particles.position = Vector2(0, -300)
	add_child(_rain_particles)

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
			weather_changed.emit(_weather_name(current_weather))
		
		weather_intensity = weather_transition if target_weather > current_weather else 1.0 - weather_transition
	else:
		weather_intensity = 1.0 if current_weather != WeatherType.CLEAR else 0.0

func _update_rain_particles(_delta: float) -> void:
	match current_weather:
		WeatherType.CLEAR:
			_rain_particles.emitting = false
			return
		WeatherType.LIGHT_RAIN:
			_rain_particles.amount = int(RAIN_DROP_COUNT * 0.5 * weather_intensity)
			var c = Constants.RAIN_PARTICLE_CLEAR
			_rain_particle_material.color = Color(c.r, c.g, c.b, c.a * weather_intensity)
		WeatherType.ACID_RAIN:
			_rain_particles.amount = int(RAIN_DROP_COUNT * weather_intensity)
			var c = Constants.RAIN_PARTICLE_ACID
			_rain_particle_material.color = Color(c.r, c.g, c.b, c.a * weather_intensity)
		WeatherType.STORM:
			_rain_particles.amount = int(RAIN_DROP_COUNT * weather_intensity)
			var c = Constants.RAIN_PARTICLE_STORM
			_rain_particle_material.color = Color(c.r, c.g, c.b, c.a * weather_intensity)
	_rain_particles.emitting = _rain_particles.amount > 0

func _update_clouds(delta: float) -> void:
	if current_weather == WeatherType.ACID_RAIN or current_weather == WeatherType.STORM:
		var target_clouds = CLOUD_COUNT if current_weather == WeatherType.STORM else 3
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
			acid_rain_timer = ACID_RAIN_DAMAGE_INTERVAL
			if player_ref and is_instance_valid(player_ref):
				if player_ref.has_method("take_damage"):
					player_ref.take_damage(ACID_RAIN_DAMAGE)

func _try_spawn_lightning(delta: float) -> void:
	if current_weather != WeatherType.STORM:
		return
	
	lightning_timer -= delta
	if lightning_timer <= 0.0:
		lightning_timer = randf_range(1.0, 3.0)
		if randf() < LIGHTNING_CHANCE_PER_SECOND * 10.0:
			_spawn_lightning_strike()

func _spawn_lightning_strike() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	var strike_x = player_ref.global_position.x + randf_range(-150, 150)
	var strike_y = player_ref.global_position.y - 400
	var strike_pos = Vector2(strike_x, strike_y)
	
	_create_lightning_bolt(strike_pos)
	
	var flash = _create_lightning_flash(strike_pos)
	lightning_container.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)
	
	lightning_strike.emit(strike_pos)
	AudioManager.play_lightning_strike(strike_pos)
	
	if player_ref:
		var dist = strike_pos.distance_to(player_ref.global_position)
		if dist < 80.0:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(LIGHTNING_DAMAGE)

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
	tween.tween_callback(bolt.queue_free)

func _create_lightning_flash(pos: Vector2) -> Node:
	var flash = ColorRect.new()
	flash.size = Vector2(200, 200)
	flash.position = pos - Vector2(100, 100)
	flash.color = Constants.LIGHTNING_FLASH_COLOR
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return flash

func _spawn_cloud() -> void:
	var cloud = Node2D.new()
	cloud.position = Vector2(randf_range(-100, 600), randf_range(-300, -100))
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
		target_weather = type
		weather_transition = 0.0
		weather_changed.emit(_weather_name(type))

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