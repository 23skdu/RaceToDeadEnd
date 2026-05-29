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
	# 1. Determine sky background top and bottom colors for vertical gradient
	var bg_color_top = Color(0.08, 0.02, 0.16)
	var bg_color_bottom = Color(0.24, 0.04, 0.22)
	
	if current_weather == "clear":
		bg_color_top = Color(0.06, 0.01, 0.15)
		bg_color_bottom = Color(0.32, 0.03, 0.26)
	elif current_weather == "light_rain":
		bg_color_top = Color(0.05, 0.05, 0.10)
		bg_color_bottom = Color(0.14, 0.14, 0.22)
	elif current_weather == "acid_rain":
		bg_color_top = Color(0.02, 0.08, 0.02)
		bg_color_bottom = Color(0.08, 0.18, 0.08)
	elif current_weather == "storm":
		bg_color_top = Color(0.01, 0.01, 0.05)
		bg_color_bottom = Color(0.05, 0.05, 0.12)
		if flash_active:
			bg_color_top = Color(0.85, 0.92, 1.0)
			bg_color_bottom = Color(0.95, 0.98, 1.0)
	
	# 2. Smooth hardware-accelerated sky vertical gradient quad
	var quad_points = PackedVector2Array([
		Vector2(0, 0), Vector2(size.x, 0),
		Vector2(size.x, 72), Vector2(0, 72)
	])
	var quad_colors = PackedColorArray([
		bg_color_top, bg_color_top,
		bg_color_bottom, bg_color_bottom
	])
	draw_polygon(quad_points, quad_colors)
	
	# 3. Atmospheric haze layer near horizon
	var haze_color = bg_color_top.lerp(Color(1.0, 0.2, 0.6, 0.0), 0.5)
	var haze_points = PackedVector2Array([
		Vector2(0, 50), Vector2(size.x, 50),
		Vector2(size.x, 72), Vector2(0, 72)
	])
	var haze_colors = PackedColorArray([
		Color(haze_color.r, haze_color.g, haze_color.b, 0.0),
		Color(haze_color.r, haze_color.g, haze_color.b, 0.0),
		Color(1.0, 0.3, 0.8, 0.08), Color(1.0, 0.3, 0.8, 0.08)
	])
	draw_polygon(haze_points, haze_colors)
	
	# 3b. City glow on horizon
	var glow_width = size.x * 0.4
	var glow_cx = size.x / 2.0 + sin(time_elapsed * 0.03) * 50.0
	var glow_col = Color(1.0, 0.2, 0.7, 0.0)
	if current_weather == "clear":
		glow_col = Color(1.0, 0.3, 0.8, 0.0)
	elif current_weather == "acid_rain":
		glow_col = Color(0.2, 0.9, 0.2, 0.0)
	elif current_weather == "storm":
		glow_col = Color(0.0, 0.5, 1.0, 0.0)
	for g in range(5):
		var ga = 0.04 - g * 0.008
		if ga > 0:
			draw_circle(Vector2(glow_cx, 72), 40.0 + g * 20.0, Color(glow_col.r, glow_col.g, glow_col.b, ga))
	
	# 4. Twinkling stars field (Clear & Storm weather)
	if current_weather == "clear" or (current_weather == "storm" and not flash_active):
		_draw_star_field()
		_draw_shooting_stars()
		
	# 5. Distant neon horizon grid (retrowave perspective)
	_draw_neon_horizon_grid(bg_color_bottom)
	
	# 6. Far background parallax mountain ranges
	var far_mtn_col = bg_color_bottom.lerp(Color.BLACK, 0.6)
	_draw_procedural_mountains(54.0, 8.0, far_mtn_col, 20.0, time_elapsed * 0.05)
	
	# 7. Celestial bodies (Sunset Sun or cratered Moon)
	var center_x = size.x / 2.0
	if current_weather == "clear":
		# Synthwave outrun sunset sun with sliced cuts & glowing layers
		var sun_center = Vector2(center_x + sin(time_elapsed * 0.15) * 60.0, 34.0)
		
		# Translucent soft corona flares
		draw_circle(sun_center, 34.0, Color(1.0, 0.45, 0.0, 0.08))
		draw_circle(sun_center, 28.0, Color(1.0, 0.45, 0.1, 0.16))
		draw_circle(sun_center, 22.0, Color(1.0, 0.55, 0.15, 0.3))
		# Main Sun body
		draw_circle(sun_center, 18.0, Color(1.0, 0.35, 0.05, 1.0))
		
		# Slicing bars matching the bottom gradient color to complete retro sliced sun look
		for k in range(4):
			var cut_y = sun_center.y + 3.0 + k * 3.8
			var thickness = 1.0 + k * 0.8
			draw_line(Vector2(sun_center.x - 24.0, cut_y), Vector2(sun_center.x + 24.0, cut_y), bg_color_bottom, thickness)
			
	elif current_weather == "light_rain":
		# Pale sun through rain clouds
		var sun_center = Vector2(center_x, 36)
		draw_circle(sun_center, 20, Color(0.9, 0.9, 0.75, 0.2))
		draw_circle(sun_center, 15, Color(0.95, 0.95, 0.8, 0.4))
		_draw_cloud(Vector2(center_x - 40 + sin(time_elapsed * 0.4) * 8, 36), 24, Color(0.3, 0.3, 0.35, 0.55))
		_draw_cloud(Vector2(center_x + 40 - sin(time_elapsed * 0.3) * 6, 42), 20, Color(0.35, 0.35, 0.4, 0.55))
		
	elif current_weather == "acid_rain":
		# Toxic swirling fumes
		_draw_cloud(Vector2(center_x - 90 + sin(time_elapsed * 0.5) * 15, 30), 26, Color(0.1, 0.45, 0.1, 0.45))
		_draw_cloud(Vector2(center_x - cos(time_elapsed * 0.5) * 10, 42), 30, Color(0.12, 0.5, 0.12, 0.45))
		_draw_cloud(Vector2(center_x + 90 + sin(time_elapsed * 0.4) * 12, 34), 22, Color(0.1, 0.4, 0.1, 0.4))
		
	elif current_weather == "storm":
		if not flash_active:
			# Crescent Moon with craters & atmospheric cyan aura glow
			var moon_center = Vector2(center_x + sin(time_elapsed * 0.08) * 40.0, 34.0)
			
			# Outer lunar glow
			draw_circle(moon_center, 22.0, Color(0.0, 0.8, 1.0, 0.12))
			draw_circle(moon_center, 17.0, Color(0.0, 0.8, 1.0, 0.22))
			
			# Moon Base sphere
			draw_circle(moon_center, 14.0, Color(0.8, 0.95, 1.0, 1.0))
			
			# Craters (shaded spots)
			draw_circle(moon_center + Vector2(-5, -2), 2.2, Color(0.68, 0.82, 0.88, 1.0))
			draw_circle(moon_center + Vector2(2, 5), 1.8, Color(0.68, 0.82, 0.88, 1.0))
			draw_circle(moon_center + Vector2(-2, 6), 1.5, Color(0.68, 0.82, 0.88, 1.0))
			
			# Shifting shadow offset to render beautiful crescent shape
			var shadow_offset = Vector2(5.5, -3.5)
			draw_circle(moon_center + shadow_offset, 14.0, Color(bg_color_bottom.r, bg_color_bottom.g, bg_color_bottom.b, 0.9))
			
		# Storm clouds
		_draw_cloud(Vector2(center_x - 70 + sin(time_elapsed * 0.6) * 12, 28), 28, Color(0.05, 0.05, 0.08, 0.8))
		_draw_cloud(Vector2(center_x + 50 - cos(time_elapsed * 0.5) * 15, 40), 32, Color(0.03, 0.03, 0.06, 0.8))

	# 8. Near background parallax mountain range (closer, darker overlay)
	var near_mtn_col = bg_color_bottom.lerp(Color.BLACK, 0.75)
	_draw_procedural_mountains(58.0, 6.0, near_mtn_col, 16.0, time_elapsed * 0.1 + 2.5)

	# 9. Double neon horizon lines (cyan + pink)
	draw_line(Vector2(0, 72), Vector2(size.x, 72), Color(0.0, 0.85, 1.0, 0.9), 2.0)
	draw_line(Vector2(0, 70.5), Vector2(size.x, 70.5), Color(1.0, 0.1, 0.6, 0.4), 1.0)

func _draw_shooting_stars() -> void:
	var ss_phase = fmod(time_elapsed, 6.0)
	if ss_phase > 0.05 and ss_phase < 0.4:
		var progress = ss_phase / 0.4
		var sx = 50.0 + progress * (size.x - 100.0)
		var sy = 5.0 + progress * 30.0
		var alpha = sin(progress * PI)
		draw_line(Vector2(sx, sy), Vector2(sx - 20.0 * progress, sy + 12.0 * progress), Color(1.0, 1.0, 1.0, alpha * 0.7), 1.5)
		draw_line(Vector2(sx, sy), Vector2(sx - 8.0 * progress, sy + 5.0 * progress), Color(1.0, 1.0, 1.0, alpha), 0.5)

func _draw_neon_horizon_grid(bg_bottom: Color) -> void:
	var grid_color = Color(1.0, 0.1, 0.6, 0.15)
	if current_weather == "clear":
		grid_color = Color(1.0, 0.1, 0.6, 0.15)
	elif current_weather == "acid_rain":
		grid_color = Color(0.2, 1.0, 0.2, 0.1)
	elif current_weather == "storm":
		grid_color = Color(0.0, 0.8, 1.0, 0.08)
	elif current_weather == "light_rain":
		grid_color = Color(0.6, 0.6, 0.8, 0.08)
	
	# Perspective grid lines converging to vanishing point
	var vp_x = size.x / 2.0 + sin(time_elapsed * 0.02) * 30.0
	var vp_y = 40.0
	for i in range(8):
		var t = 0.3 + i * 0.1
		var y1 = vp_y + (72.0 - vp_y) * t
		var spread = 30.0 + i * 25.0
		draw_line(Vector2(vp_x - spread, y1), Vector2(vp_x + spread, y1), grid_color, 1.0)

func _draw_star_field() -> void:
	# Twinkling star field with glowing cross flares
	for j in range(25):
		var sx = fmod(j * 179.37 + 45.0, size.x)
		var sy = fmod(j * 83.19 + 8.0, 32.0)
		var twinkle = sin(time_elapsed * 2.8 + j * 1.5) * 0.5 + 0.5
		var alpha = 0.2 + twinkle * 0.8
		var col = Color(1.0, 1.0, 1.0, alpha)
		
		# Draw stars points
		draw_rect(Rect2(sx, sy, 1.5, 1.5), col)
		if twinkle > 0.82:
			draw_line(Vector2(sx - 2.5, sy), Vector2(sx + 3.5, sy), Color(1.0, 1.0, 1.0, alpha * 0.45), 1.0)
			draw_line(Vector2(sx, sy - 2.5), Vector2(sx, sy + 3.5), Color(1.0, 1.0, 1.0, alpha * 0.45), 1.0)

func _draw_procedural_mountains(y_offset: float, height: float, col: Color, step: float, phase: float) -> void:
	var points = PackedVector2Array()
	points.append(Vector2(0.0, 72.0))
	var x = 0.0
	while x <= size.x:
		# Double sine/cosine harmonics for organic wavy mountain ranges
		var y = y_offset - sin(x * 0.012 + phase) * height - cos(x * 0.004 + phase * 0.6) * (height * 0.5)
		points.append(Vector2(x, y))
		x += step
	points.append(Vector2(size.x, 72.0))
	draw_polygon(points, PackedColorArray([col]))

func _draw_cloud(pos: Vector2, c_size: float, color: Color = Color(0.5, 0.5, 0.5, 0.7)) -> void:
	var rim_color = Color(1.0, 1.0, 1.0, 0.2)
	if current_weather == "acid_rain":
		rim_color = Color(0.3, 0.85, 0.15, 0.25)
	elif current_weather == "storm":
		rim_color = Color(0.2, 0.3, 0.5, 0.15)
		
	# 1. Soft sunlight/moonlight volumetric highlight rims
	var offset = Vector2(0.0, -1.8)
	draw_circle(pos + offset, c_size + 0.4, rim_color)
	draw_circle(pos - Vector2(c_size * 0.6, -2.0) + offset, c_size * 0.7 + 0.4, rim_color)
	draw_circle(pos + Vector2(c_size * 0.6, -2.0) + offset, c_size * 0.7 + 0.4, rim_color)
	
	# 2. Main cloud volumes
	draw_circle(pos, c_size, color)
	draw_circle(pos - Vector2(c_size * 0.6, -2.0), c_size * 0.7, color)
	draw_circle(pos + Vector2(c_size * 0.6, -2.0), c_size * 0.7, color)
	
	# 3. Soft internal volumetric depth shadow
	var dark_shadow = Color(color.r * 0.78, color.g * 0.78, color.b * 0.82, color.a)
	draw_circle(pos + Vector2(0.0, 2.5), c_size * 0.95, dark_shadow)
