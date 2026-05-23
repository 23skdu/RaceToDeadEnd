extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
const AUDIO_SECTION: String = "audio"
const VIDEO_SECTION: String = "video"

var _config: ConfigFile = ConfigFile.new()
var _loaded: bool = false
var _save_debounce_timer: float = 0.0

func _ready() -> void:
	load_settings()

func _process(delta: float) -> void:
	if _save_debounce_timer > 0.0:
		_save_debounce_timer -= delta
		if _save_debounce_timer <= 0.0:
			_save_debounce_timer = -1.0
			save_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		_loaded = true
		return
	var err = _config.load(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: Failed to load settings (", err, "), using defaults")
		_config = ConfigFile.new()
	_loaded = true
	_apply_settings()

func save_settings() -> void:
	var err = _config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: Failed to save settings (", err, ")")

func _apply_settings() -> void:
	if _config.has_section(AUDIO_SECTION):
		for bus_name in _config.get_section_keys(AUDIO_SECTION):
			var bus_idx = AudioServer.get_bus_index(bus_name)
			if bus_idx >= 0:
				var val = _config.get_value(AUDIO_SECTION, bus_name, 1.0)
				AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val) if val > 0 else -80.0)
	if _config.has_section(VIDEO_SECTION):
		if _config.has_section_key(VIDEO_SECTION, "fullscreen"):
			var fs = _config.get_value(VIDEO_SECTION, "fullscreen", false)
			if fs:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func set_volume(bus_name: String, linear_value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_value) if linear_value > 0 else -80.0)
	_config.set_value(AUDIO_SECTION, bus_name, linear_value)
	_save_debounce_timer = 0.5

func get_volume(bus_name: String, default: float = 1.0) -> float:
	if _config.has_section_key(AUDIO_SECTION, bus_name):
		return _config.get_value(AUDIO_SECTION, bus_name, default)
	return default

func set_fullscreen(enabled: bool) -> void:
	_config.set_value(VIDEO_SECTION, "fullscreen", enabled)
	save_settings()
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func get_fullscreen(default: bool = false) -> bool:
	if _config.has_section_key(VIDEO_SECTION, "fullscreen"):
		return _config.get_value(VIDEO_SECTION, "fullscreen", default)
	return default
