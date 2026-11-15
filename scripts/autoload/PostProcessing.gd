extends CanvasLayer

signal post_processing_toggled(enabled: bool)

const SHADER_PATH: String = "res://shaders/post_processing.gdshader"

@export var enabled: bool = true
@export_range(0.0, 1.0) var scanline_intensity: float = 0.12
@export_range(0.0, 1.0) var vignette_intensity: float = 0.32
@export_range(0.0, 0.006) var chromatic_aberration: float = 0.0018
@export_range(0.0, 1.0) var bloom_intensity: float = 0.22
@export_range(0.0, 0.15) var film_grain: float = 0.04

var _rect: ColorRect = null
var _material: ShaderMaterial = null

func _ready() -> void:
	layer = 90
	process_mode = PROCESS_MODE_ALWAYS
	_setup_rect()
	_apply_uniforms()
	_update_visibility()

func _setup_rect() -> void:
	_rect = ColorRect.new()
	_rect.name = "PostProcessingRect"
	_rect.anchor_left = 0.0
	_rect.anchor_top = 0.0
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.offset_left = 0.0
	_rect.offset_top = 0.0
	_rect.offset_right = 0.0
	_rect.offset_bottom = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color.WHITE

	if ResourceLoader.exists(SHADER_PATH):
		var shader := load(SHADER_PATH) as Shader
		if shader:
			_material = ShaderMaterial.new()
			_material.shader = shader
			_rect.material = _material
	add_child(_rect)

func _apply_uniforms() -> void:
	if not _material:
		return
	_material.set_shader_parameter("scanline_intensity", scanline_intensity)
	_material.set_shader_parameter("vignette_intensity", vignette_intensity)
	_material.set_shader_parameter("chromatic_aberration", chromatic_aberration)
	_material.set_shader_parameter("bloom_intensity", bloom_intensity)
	_material.set_shader_parameter("film_grain", film_grain)

func set_enabled(value: bool) -> void:
	enabled = value
	_update_visibility()
	post_processing_toggled.emit(enabled)

func _update_visibility() -> void:
	if is_instance_valid(_rect):
		_rect.visible = enabled

func toggle() -> void:
	set_enabled(not enabled)

func is_enabled() -> bool:
	return enabled and is_instance_valid(_rect) and _rect.visible
