extends Control

signal demo_finished

@export var duration: float = 2.0
@export var boss_type: String = "boss"

var _timer: float = 0.0
var _flash_interval: float = 0.0

@onready var _color_rect: ColorRect = $ColorRect
@onready var _label: Label = $Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.play_demo_music(boss_type)

func _process(delta: float) -> void:
	_timer += delta
	_flash_interval += delta

	var color_rect = _color_rect
	var label = _label
	if not color_rect or not label:
		if _timer >= duration:
			demo_finished.emit()
			queue_free()
		return

	var hue_shift = fmod(_timer * 1.5, 1.0)
	var bg_color = Color.from_hsv(hue_shift, 0.7, 0.2 + 0.15 * sin(_timer * 3.0))

	# Flash white every 0.3s
	if fmod(_flash_interval, 0.3) < 0.07:
		bg_color = Color(1.0, 1.0, 1.0, 0.9)

	color_rect.color = bg_color

	# Pulse the label
	var pulse = 0.7 + 0.3 * sin(_timer * 6.0)
	var text_hue = fmod(hue_shift + 0.5, 1.0)
	label.theme_override_colors.font_color = Color.from_hsv(text_hue, 0.8, 0.6 + 0.4 * pulse)
	var scale = 1.0 + 0.08 * sin(_timer * 4.0)
	label.scale = Vector2(scale, scale)

	# Draw expanding ring geometric patterns
	queue_redraw()

	if _timer >= duration:
		demo_finished.emit()
		queue_free()

func _draw() -> void:
	if _timer >= duration:
		return
	var rect = get_viewport().get_visible_rect()
	var cx = rect.size.x / 2.0
	var cy = rect.size.y / 2.0

	# Expanding rings
	for i in range(3):
		var ring_phase = fmod(_timer * 2.0 + i * 0.7, 2.0)
		var radius = 50.0 + ring_phase * 300.0
		var ring_hue = fmod(_timer * 1.0 + i * 0.3, 1.0)
		var ring_color = Color.from_hsv(ring_hue, 0.8, 1.0, 0.3 * (1.0 - ring_phase / 2.0))
		draw_arc(Vector2(cx, cy), radius, 0.0, TAU, 64, ring_color, 3.0, true)

	# Floating geometric particles
	for p in range(12):
		var p_angle = _timer * 2.0 + p * TAU / 12.0
		var p_dist = 80.0 + sin(_timer * 1.5 + p) * 60.0
		var px = cx + cos(p_angle) * p_dist
		var py = cy + sin(p_angle * 0.7) * p_dist * 0.5
		var p_hue = fmod(_timer * 0.8 + p * 0.1, 1.0)
		var p_alpha = 0.3 + 0.3 * sin(_timer * 3.0 + p)
		draw_circle(Vector2(px, py), 4.0 + 2.0 * sin(_timer * 2.0 + p), Color.from_hsv(p_hue, 0.9, 1.0, p_alpha))
