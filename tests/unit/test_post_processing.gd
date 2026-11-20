extends GutTest

const PostProcessingScript = preload("res://scripts/autoload/PostProcessing.gd")

var _pp

func before_each() -> void:
	_pp = PostProcessingScript.new()
	_pp.enabled = false
	add_child_autofree(_pp)

func test_post_processing_autoload_exists() -> void:
	assert_not_null(PostProcessing, "PostProcessing autoload should be registered")
	assert_eq(_pp.layer, 5, "PostProcessing should render above the world but below UI overlays")

func test_post_processing_ready_creates_rect_and_material() -> void:
	_pp._ready()
	assert_not_null(_pp._rect, "PostProcessing should create a ColorRect")
	assert_not_null(_pp._material, "PostProcessing should load the shader material")
	assert_true(_pp._rect.mouse_filter == Control.MOUSE_FILTER_IGNORE)

func test_post_processing_toggle_updates_visibility() -> void:
	_pp._ready()
	_pp.set_enabled(true)
	assert_true(_pp.is_enabled(), "PostProcessing should be enabled after set_enabled(true)")
	_pp.toggle()
	assert_false(_pp.is_enabled(), "PostProcessing should toggle off")
	_pp.toggle()
	assert_true(_pp.is_enabled(), "PostProcessing should toggle back on")

func test_post_processing_uniforms_apply() -> void:
	_pp._ready()
	_pp.scanline_intensity = 0.25
	_pp.vignette_intensity = 0.5
	_pp.chromatic_aberration = 0.003
	_pp.bloom_intensity = 0.4
	_pp.film_grain = 0.08
	_pp._apply_uniforms()
	assert_eq(_pp._material.get_shader_parameter("scanline_intensity"), 0.25)
	assert_eq(_pp._material.get_shader_parameter("vignette_intensity"), 0.5)
	assert_eq(_pp._material.get_shader_parameter("chromatic_aberration"), 0.003)
	assert_eq(_pp._material.get_shader_parameter("bloom_intensity"), 0.4)
	assert_eq(_pp._material.get_shader_parameter("film_grain"), 0.08)
