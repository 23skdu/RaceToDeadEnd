extends Control

signal demo_finished

const BossBunnyScript = preload("res://scripts/scenes/enemies/BossBunny.gd")
const BossGiantBikerScript = preload("res://scripts/scenes/enemies/BossGiantBiker.gd")
const BossVoidDroneScript = preload("res://scripts/scenes/enemies/BossVoidDrone.gd")
const BossWarRigScript = preload("res://scripts/scenes/enemies/BossWarRig.gd")

const BOSS_META: Dictionary = {
	"boss_bunny": {
		"accent": Color(0.2, 1.0, 0.35, 1.0),
		"bg_base": Color(0.05, 0.14, 0.08, 0.92),
		"unlock": "+1,000 PTS  |  ROTOR WAVES & URBAN CAMO SKIN UNLOCKED!",
	},
	"boss_giant_biker": {
		"accent": Color(1.0, 0.3, 0.25, 1.0),
		"bg_base": Color(0.18, 0.04, 0.05, 0.92),
		"unlock": "+1,000 PTS  |  SCAV & SASQUATCH WAVES UNLOCKED!",
	},
	"boss": {
		"accent": Color(1.0, 0.65, 0.1, 1.0),
		"bg_base": Color(0.14, 0.09, 0.03, 0.92),
		"unlock": "+1,000 PTS  |  VOID DRONE WAVES UNLOCKED!",
	},
	"boss_void_drone": {
		"accent": Color(0.0, 0.95, 1.0, 1.0),
		"bg_base": Color(0.08, 0.03, 0.18, 0.92),
		"unlock": "+1,000 PTS  |  SECTOR CLEARED - OVERDRIVE!",
	},
}

@export var duration: float = 2.0
@export var boss_type: String = "boss"

var _timer: float = 0.0
var _flash_interval: float = 0.0
var _finished: bool = false
var _subtitle_label: Label = null
var _portrait_rect: TextureRect = null

@onready var _color_rect: ColorRect = get_node_or_null("ColorRect")
@onready var _label: Label = get_node_or_null("Label")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_overlay_details()
	if AudioManager and AudioManager.has_method("play_demo_music"):
		AudioManager.play_demo_music(boss_type)

func _setup_overlay_details() -> void:
	var meta: Dictionary = BOSS_META.get(boss_type, BOSS_META["boss"])
	var accent: Color = meta.get("accent", Color.CYAN)

	if is_instance_valid(_color_rect):
		_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_color_rect.color = meta.get("bg_base", Color(0.08, 0.08, 0.14, 0.92))

	if is_instance_valid(_label):
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.add_theme_color_override("font_color", accent)

	var tex := _get_boss_portrait(boss_type)
	if tex:
		_portrait_rect = TextureRect.new()
		_portrait_rect.name = "BossPortrait"
		_portrait_rect.texture = tex
		_portrait_rect.custom_minimum_size = Vector2(128, 128)
		_portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_portrait_rect.anchor_left = 0.5
		_portrait_rect.anchor_right = 0.5
		_portrait_rect.anchor_top = 0.5
		_portrait_rect.anchor_bottom = 0.5
		_portrait_rect.offset_left = -64.0
		_portrait_rect.offset_right = 64.0
		_portrait_rect.offset_top = -185.0
		_portrait_rect.offset_bottom = -57.0
		_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_portrait_rect)

	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.text = str(meta.get("unlock", "+1,000 PTS"))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.anchor_left = 0.0
	_subtitle_label.anchor_right = 1.0
	_subtitle_label.anchor_top = 0.5
	_subtitle_label.anchor_bottom = 0.5
	_subtitle_label.offset_top = 56.0
	_subtitle_label.offset_bottom = 96.0
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_label.add_theme_font_size_override("font_size", 20)
	_subtitle_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 0.95))
	add_child(_subtitle_label)

func _get_boss_portrait(b_type: String) -> Texture2D:
	match b_type:
		"boss_bunny":
			return BossBunnyScript._create_boss_bunny_texture()
		"boss_giant_biker":
			return BossGiantBikerScript._create_boss_biker_texture()
		"boss_void_drone":
			return BossVoidDroneScript._create_boss_void_drone_texture()
		"boss":
			return BossWarRigScript._create_boss_war_rig_texture()
	return null

func _finish_demo() -> void:
	if _finished:
		return
	_finished = true
	demo_finished.emit()
	queue_free()

func _process(delta: float) -> void:
	if _finished:
		return
	_timer += delta
	_flash_interval += delta

	if _timer >= 0.4 and Input.is_action_just_pressed("ui_accept"):
		_finish_demo()
		return

	var color_rect := _color_rect
	var label := _label
	if not is_instance_valid(color_rect) or not is_instance_valid(label):
		if _timer >= duration:
			_finish_demo()
		return

	var meta: Dictionary = BOSS_META.get(boss_type, BOSS_META["boss"])
	var accent: Color = meta.get("accent", Color.CYAN)
	var bg_base: Color = meta.get("bg_base", Color(0.08, 0.08, 0.14, 0.92))
	var hue_shift := fmod(_timer * 1.2, 1.0)
	var bg_color := bg_base.lerp(Color.from_hsv(hue_shift, 0.65, 0.22, 0.92), 0.35 + 0.15 * sin(_timer * 3.0))

	if fmod(_flash_interval, 0.35) < 0.06:
		bg_color = bg_color.lerp(accent, 0.25)

	color_rect.color = bg_color

	var pulse := 0.75 + 0.25 * sin(_timer * 6.0)
	var text_col := accent.lerp(Color.WHITE, pulse * 0.45)
	label.add_theme_color_override("font_color", text_col)
	label.pivot_offset = label.size * 0.5
	var s := 1.0 + 0.06 * sin(_timer * 4.0)
	label.scale = Vector2(s, s)

	if is_instance_valid(_portrait_rect):
		_portrait_rect.pivot_offset = _portrait_rect.size * 0.5
		var ps := 1.0 + 0.05 * cos(_timer * 5.0)
		_portrait_rect.scale = Vector2(ps, ps)

	queue_redraw()

	if _timer >= duration:
		_finish_demo()

func _draw() -> void:
	if _finished or _timer >= duration:
		return
	var vp := get_viewport()
	if not vp:
		return
	var rect := vp.get_visible_rect()
	var cx := rect.size.x * 0.5
	var cy := rect.size.y * 0.5
	var meta: Dictionary = BOSS_META.get(boss_type, BOSS_META["boss"])
	var accent: Color = meta.get("accent", Color.CYAN)

	for i in range(3):
		var ring_phase := fmod(_timer * 2.0 + i * 0.7, 2.0)
		var radius := 50.0 + ring_phase * 280.0
		var ring_col := Color(accent.r, accent.g, accent.b, 0.35 * (1.0 - ring_phase / 2.0))
		draw_arc(Vector2(cx, cy), radius, 0.0, TAU, 64, ring_col, 3.0, true)

	for p in range(12):
		var p_angle := _timer * 2.0 + p * TAU / 12.0
		var p_dist := 110.0 + sin(_timer * 1.5 + p) * 60.0
		var px := cx + cos(p_angle) * p_dist
		var py := cy + sin(p_angle * 0.7) * p_dist * 0.5
		var p_hue := fmod(_timer * 0.8 + p * 0.1, 1.0)
		var p_alpha := 0.35 + 0.3 * sin(_timer * 3.0 + p)
		draw_circle(Vector2(px, py), 4.0 + 2.0 * sin(_timer * 2.0 + p), Color.from_hsv(p_hue, 0.9, 1.0, p_alpha))
