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
	master_slider.value = SettingsManager.get_volume("Master", db_to_linear(AudioServer.get_bus_volume_db(0)))
	if AudioServer.get_bus_count() > 1:
		music_slider.value = SettingsManager.get_volume("Music", db_to_linear(AudioServer.get_bus_volume_db(1)))
		sfx_slider.value = SettingsManager.get_volume("SFX", db_to_linear(AudioServer.get_bus_volume_db(2)))

func _load_fullscreen_setting() -> void:
	var mode = DisplayServer.window_get_mode()
	var saved = SettingsManager.get_fullscreen()
	if saved:
		fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		fullscreen_check.button_pressed = false

func _on_master_changed(value: float) -> void:
	SettingsManager.set_volume("Master", value)

func _on_music_changed(value: float) -> void:
	SettingsManager.set_volume("Music", value)

func _on_sfx_changed(value: float) -> void:
	SettingsManager.set_volume("SFX", value)

func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_fullscreen(pressed)

func _on_back_pressed() -> void:
	back_to_menu_requested.emit()
