extends Control

var current_weather: String = "clear"
var time_elapsed: float = 0.0
var flash_active: bool = false
var flash_timer: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 72)
	anchors_preset = Control.PRESET_TOP_WIDE
	offset_bottom = 72
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	# Attempt to locate the WeatherSystem in the scene tree and connect signals
	var weather = get_node_or_null("/root/Game/World/WeatherSystem")
	if weather:
		weather.weather_changed.connect(_on_weather_changed)
		weather.lightning_strike.connect(_on_lightning_strike)
		current_weather = weather._weather_name(weather.current_weather)

func _on_weather_changed(weather_type: String) -> void:
	current_weather = weather_type
	queue_redraw()

func _on_lightning_strike(_pos: Vector2) -> void:
	flash_active = true
	flash_timer = 0.15
	queue_redraw()

func _process(delta: float) -> void:
	time_elapsed += delta
	if flash_active:
		flash_timer -= delta
		if flash_timer <= 0.0:
			flash_active = false
		queue_redraw()
	else:
		# Slowly redraw to animate drift
		queue_redraw()

func _draw() -> void:
	# Draw sky background gradient
	var bg_color_left = Color(0.1, 0.02, 0.2)
	var bg_color_right = Color(0.25, 0.05, 0.3)
	
	if current_weather == "clear":
		bg_color_left = Color(0.12, 0.03, 0.22)
		bg_color_right = Color(0.35, 0.05, 0.4)
	elif current_weather == "light_rain":
		bg_color_left = Color(0.08, 0.08, 0.15)
		bg_color_right = Color(0.15, 0.15, 0.25)
	elif current_weather == "acid_rain":
		bg_color_left = Color(0.04, 0.12, 0.04)
		bg_color_right = Color(0.08, 0.2, 0.08)
	elif current_weather == "storm":
		bg_color_left = Color(0.02, 0.02, 0.08)
		bg_color_right = Color(0.05, 0.05, 0.15)
		if flash_active:
			bg_color_left = Color(0.8, 0.9, 1.0)
			bg_color_right = Color(0.9, 0.95, 1.0)
	
	# Draw vertical slices to simulate a nice horizontal gradient
	var slice_count = 16
	var slice_width = 1280.0 / slice_count
	for i in range(slice_count):
		var t = float(i) / float(slice_count - 1)
		var c = bg_color_left.lerp(bg_color_right, t)
		draw_rect(Rect2(i * slice_width, 0, slice_width + 1.0, 72), c)
		
	# Draw neon bottom divider line
	draw_line(Vector2(0, 72), Vector2(1280, 72), Color(0.0, 0.8, 1.0, 0.8), 2.0)
	
	# Draw celestial elements
	if current_weather == "clear":
		# Glowing retro sun
		var sun_center = Vector2(640 + sin(time_elapsed * 0.2) * 50, 36)
		draw_circle(sun_center, 22, Color(1.0, 0.45, 0.15, 1.0))
		draw_circle(sun_center, 26, Color(1.0, 0.6, 0.2, 0.25))
	elif current_weather == "light_rain":
		# Pale sun
		var sun_center = Vector2(640, 36)
		draw_circle(sun_center, 16, Color(0.9, 0.9, 0.7, 0.5))
		_draw_cloud(Vector2(610 + sin(time_elapsed * 0.4) * 8, 36), 24, Color(0.4, 0.4, 0.45, 0.6))
		_draw_cloud(Vector2(670 - sin(time_elapsed * 0.3) * 6, 42), 20, Color(0.45, 0.45, 0.5, 0.6))
	elif current_weather == "acid_rain":
		# Toxic clouds
		_draw_cloud(Vector2(560 + sin(time_elapsed * 0.5) * 15, 30), 26, Color(0.15, 0.6, 0.15, 0.5))
		_draw_cloud(Vector2(650 - cos(time_elapsed * 0.5) * 10, 42), 30, Color(0.2, 0.7, 0.2, 0.5))
		_draw_cloud(Vector2(740 + sin(time_elapsed * 0.4) * 12, 34), 22, Color(0.15, 0.5, 0.15, 0.4))
	elif current_weather == "storm":
		if not flash_active:
			# Crescent moon
			var moon_center = Vector2(640 + sin(time_elapsed * 0.1) * 30, 36)
			draw_circle(moon_center, 18, Color(0.0, 0.9, 1.0, 0.8))
			draw_circle(moon_center + Vector2(6, -4), 18, bg_color_right)
		# Storm clouds
		_draw_cloud(Vector2(580 + sin(time_elapsed * 0.6) * 10, 26), 28, Color(0.08, 0.08, 0.12, 0.85))
		_draw_cloud(Vector2(680 - cos(time_elapsed * 0.5) * 12, 38), 32, Color(0.05, 0.05, 0.1, 0.85))

func _draw_cloud(pos: Vector2, size: float, color: Color = Color(0.5, 0.5, 0.5, 0.7)) -> void:
	draw_circle(pos, size, color)
	draw_circle(pos - Vector2(size * 0.6, -2.0), size * 0.7, color)
	draw_circle(pos + Vector2(size * 0.6, -2.0), size * 0.7, color)
