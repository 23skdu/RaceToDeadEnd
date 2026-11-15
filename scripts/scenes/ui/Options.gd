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

var _music_track_option: OptionButton = null

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_load_volume_settings()
	_load_fullscreen_setting()
	_setup_music_track_selector()
	_setup_touch_toggle()

	if not input_remap.is_inside_tree():
		await input_remap.ready
	input_remap.load_bindings()

func _setup_music_track_selector() -> void:
	var audio_tab = get_node_or_null("Panel/TabContainer/AudioTab")
	if not audio_tab or not AudioManager or not AudioManager.has_method("get_music_options"):
		return
	var row = HBoxContainer.new()
	row.name = "MusicTrackRow"
	row.add_theme_constant_override("separation", 10)

	var lbl = Label.new()
	lbl.text = "MUSIC TRACK"
	row.add_child(lbl)

	_music_track_option = OptionButton.new()
	_music_track_option.name = "MusicTrackOption"
	_music_track_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options := AudioManager.get_music_options()
	var current_id := AudioManager.get_music_track()
	var selected_idx := 0
	for i in options.size():
		var opt := options[i]
		var opt_id := str(opt.get("id", ""))
		_music_track_option.add_item(str(opt.get("name", opt_id)), i)
		_music_track_option.set_item_metadata(i, opt_id)
		if opt_id == current_id:
			selected_idx = i
	_music_track_option.select(selected_idx)
	_music_track_option.item_selected.connect(_on_music_track_selected)
	row.add_child(_music_track_option)
	audio_tab.add_child(row)

func _on_music_track_selected(index: int) -> void:
	if not is_instance_valid(_music_track_option):
		return
	var track_id := str(_music_track_option.get_item_metadata(index))
	if AudioManager and AudioManager.has_method("set_music_track"):
		AudioManager.set_music_track(track_id)

func _setup_touch_toggle() -> void:
	var audio_tab = get_node_or_null("Panel/TabContainer/AudioTab")
	if not audio_tab:
		return
	var btn = Button.new()
	btn.name = "TouchControlsModeButton"
	_update_touch_button_text(btn)
	btn.pressed.connect(func():
		var modes = ["auto", "on", "off"]
		var cur = SettingsManager.get_touch_controls_mode()
		var next_idx = (modes.find(cur) + 1) % modes.size()
		SettingsManager.set_touch_controls_mode(modes[next_idx])
		_update_touch_button_text(btn)
	)
	audio_tab.add_child(btn)

func _update_touch_button_text(btn: Button) -> void:
	btn.text = "Touch Controls: " + SettingsManager.get_touch_controls_mode().to_upper()

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
