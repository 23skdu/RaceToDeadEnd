extends Node2D

signal weather_changed(weather_type: String)
signal lightning_strike(position: Vector2)

enum WeatherType { CLEAR, LIGHT_RAIN, ACID_RAIN, STORM }

const RAIN_DROP_COUNT: int = 200
const LIGHTNING_DAMAGE: int = 1
const ACID_RAIN_DAMAGE_INTERVAL: float = 2.0
const ACID_RAIN_DAMAGE: int = 1
const CLOUD_COUNT: int = 5
const LIGHTNING_CHANCE_PER_SECOND: float = 0.15

var current_weather: WeatherType = WeatherType.CLEAR
var target_weather: WeatherType = WeatherType.CLEAR
var weather_transition: float = 0.0
var weather_intensity: float = 0.0
var acid_rain_timer: float = 0.0
var lightning_timer: float = 0.0
var player_ref: Node = null
var highway_ref: Node = null

var rain_particles: Array[Dictionary] = []
var active_clouds: Array[Node2D] = []
var white_texture: Texture2D

@onready var rain_container: Node2D = $RainContainer
@onready var cloud_container: Node2D = $CloudContainer
@onready var lightning_container: Node2D = $LightningContainer
@onready var acid_overlay: ColorRect = $WeatherCanvas/AcidOverlay

func _ready() -> void:
	white_texture = _create_white_texture()
	_init_rain_particles()
	_set_weather(WeatherType.CLEAR)

func _process(delta: float) -> void:
	_update_weather_transition(delta)
	_update_rain(delta)
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

func _update_rain(delta: float) -> void:
	var active_count = 0
	match current_weather:
		WeatherType.LIGHT_RAIN:
			active_count = int(RAIN_DROP_COUNT * 0.5 * weather_intensity)
		WeatherType.ACID_RAIN, WeatherType.STORM:
			active_count = int(RAIN_DROP_COUNT * weather_intensity)
	
	for i in rain_particles.size():
		var p = rain_particles[i]
		if i < active_count:
			if not p["active"]:
				p["active"] = true
				_reset_rain_particle(p)
			
			p["pos"].y += p["speed"] * delta
			p["pos"].x += p["wind"] * delta
			
			if p["pos"].y > 800:
				_reset_rain_particle(p)
			
			p["node"].position = p["pos"]
			p["node"].visible = true
		else:
			p["node"].visible = false
			p["active"] = false

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
	bolt.default_color = Color(0.8, 0.9, 1.0, 1.0)
	
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

func _create_lightning_flash(pos: Vector2) -> Node2D:
	var flash = ColorRect.new()
	flash.size = Vector2(200, 200)
	flash.position = pos - Vector2(100, 100)
	flash.color = Color(0.9, 0.95, 1.0, 0.8)
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
	cloud_body.color = Color(0.15, 0.1, 0.2, 0.7)
	cloud.add_child(cloud_body)
	
	if current_weather == WeatherType.ACID_RAIN or current_weather == WeatherType.STORM:
		var glow = Polygon2D.new()
		glow.polygon = points
		glow.color = Color(0.0, 0.8, 0.2, 0.2)
		cloud.add_child(glow)
	
	cloud_container.add_child(cloud)
	active_clouds.append(cloud)

func _init_rain_particles() -> void:
	for i in RAIN_DROP_COUNT:
		var p = {
			"pos": Vector2(randf_range(-100, 700), randf_range(-200, 800)),
			"speed": randf_range(400, 600),
			"wind": randf_range(-20, 20),
			"active": false,
			"node": null
		}
		
		var drop = Polygon2D.new()
		drop.polygon = PackedVector2Array([
			Vector2(-0.5, -4),
			Vector2(0.5, -4),
			Vector2(0.5, 4),
			Vector2(-0.5, 4)
		])
		drop.visible = false
		rain_container.add_child(drop)
		p["node"] = drop
		
		rain_particles.append(p)

func _reset_rain_particle(p: Dictionary) -> void:
	p["pos"] = Vector2(randf_range(-100, 700), randf_range(-200, -50))
	p["speed"] = randf_range(400, 600)
	p["wind"] = randf_range(-20, 20)
	
	match current_weather:
		WeatherType.LIGHT_RAIN:
			p["node"].color = Color(0.5, 0.6, 0.8, 0.4)
		WeatherType.ACID_RAIN:
			p["node"].color = Color(0.2, 0.9, 0.2, 0.6)
		WeatherType.STORM:
			p["node"].color = Color(0.3, 0.8, 0.3, 0.7)

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
				acid_overlay.color = Color(0, 0, 0, 0)
		WeatherType.LIGHT_RAIN:
			if acid_overlay:
				acid_overlay.color = Color(0, 0, 0, 0)
		WeatherType.ACID_RAIN:
			if acid_overlay:
				acid_overlay.color = Color(0.1, 0.3, 0.1, 0.15)
		WeatherType.STORM:
			if acid_overlay:
				acid_overlay.color = Color(0.15, 0.2, 0.15, 0.25)

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