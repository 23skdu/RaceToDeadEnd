extends CanvasLayer

signal back_to_menu_requested

@onready var master_slider: HSlider = $Panel/MasterSlider
@onready var music_slider: HSlider = $Panel/MusicSlider
@onready var sfx_slider: HSlider = $Panel/SFXSlider
@onready var fullscreen_check: CheckButton = $Panel/FullscreenCheck
@onready var back_button: Button = $Panel/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(1))
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(2))
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _on_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_music_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(1, linear_to_db(value))

func _on_sfx_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(2, linear_to_db(value))

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	back_to_menu_requested.emit()
