extends CanvasLayer

signal back_to_menu_requested

@onready var panel: ColorRect = $Panel
@onready var tab_container: TabContainer = $Panel/TabContainer
@onready var master_slider: HSlider = $Panel/TabContainer/AudioTab/MasterSlider
@onready var music_slider: HSlider = $Panel/TabContainer/AudioTab/MusicSlider
@onready var sfx_slider: HSlider = $Panel/TabContainer/AudioTab/SFXSlider
@onready var fullscreen_check: CheckButton = $Panel/TabContainer/AudioTab/FullscreenCheck
@onready var input_remap = $Panel/TabContainer/InputTab/InputRemap
@onready var back_button: Button = $Panel/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_load_volume_settings()
	_load_fullscreen_setting()
	input_remap.load_bindings()

	if not input_remap.is_inside_tree():
		await input_remap.ready
	input_remap.load_bindings()

func _load_volume_settings() -> void:
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(1))
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(2))

func _load_fullscreen_setting() -> void:
	var mode = DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _on_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value) if value > 0 else -80.0)

func _on_music_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(1, linear_to_db(value) if value > 0 else -80.0)

func _on_sfx_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(2, linear_to_db(value) if value > 0 else -80.0)

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	back_to_menu_requested.emit()
