extends Node

signal player_skin_changed(skin_id: String)
signal music_track_changed(track_id: String)

const InputRemapUtil = preload("res://scripts/scenes/ui/InputRemap.gd")

const SETTINGS_PATH: String = "user://settings.cfg"
const AUDIO_SECTION: String = "audio"
const VIDEO_SECTION: String = "video"
const PACKS_SECTION: String = "packs"
const CONTROLS_SECTION: String = "controls"
const APPEARANCE_SECTION: String = "appearance"

var _config: ConfigFile = ConfigFile.new()
var _loaded: bool = false
var _save_debounce_timer: float = 0.0

func _ready() -> void:
	load_settings()
	InputRemapUtil.load_saved_bindings()
	_restore_active_packs()

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

func _sanitize_volume(val: Variant, default: float = 1.0) -> float:
	if typeof(val) != TYPE_FLOAT and typeof(val) != TYPE_INT:
		return clampf(default, 0.0, 1.0)
	var f := float(val)
	if is_nan(f) or is_inf(f):
		return clampf(default, 0.0, 1.0)
	return clampf(f, 0.0, 1.0)

func _apply_settings() -> void:
	if _config.has_section(AUDIO_SECTION):
		for bus_name in _config.get_section_keys(AUDIO_SECTION):
			var bus_idx = AudioServer.get_bus_index(bus_name)
			if bus_idx >= 0:
				var val = _sanitize_volume(_config.get_value(AUDIO_SECTION, bus_name, 1.0), 1.0)
				AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val) if val > 0.0 else -80.0)
	if _config.has_section(VIDEO_SECTION):
		if _config.has_section_key(VIDEO_SECTION, "fullscreen"):
			var fs = bool(_config.get_value(VIDEO_SECTION, "fullscreen", false))
			if fs:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func set_volume(bus_name: String, linear_value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	var clamped = _sanitize_volume(linear_value, 1.0)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamped) if clamped > 0.0 else -80.0)
	_config.set_value(AUDIO_SECTION, bus_name, clamped)
	_save_debounce_timer = 0.5

func get_volume(bus_name: String, default: float = 1.0) -> float:
	if _config.has_section_key(AUDIO_SECTION, bus_name):
		return _sanitize_volume(_config.get_value(AUDIO_SECTION, bus_name, default), default)
	return _sanitize_volume(default, 1.0)

func set_active_pack(content_type: String, pack_id: String) -> void:
	if not (content_type in ["music", "skin", "theme"]):
		return
	_config.set_value(PACKS_SECTION, content_type, pack_id)
	save_settings()

func get_active_pack(content_type: String) -> String:
	if _config.has_section_key(PACKS_SECTION, content_type):
		return str(_config.get_value(PACKS_SECTION, content_type, ""))
	return ""

func _restore_active_packs() -> void:
	if not PackManager:
		return
	for ctype in ["music", "skin", "theme"]:
		var pack_id := get_active_pack(ctype)
		if not pack_id.is_empty() and PackManager.discovered_packs.has(pack_id):
			if PackManager.get_active_pack_id(ctype) != pack_id:
				PackManager.activate_pack(pack_id, ctype)

func set_touch_controls_mode(mode: String) -> void:
	if mode in ["auto", "on", "off"]:
		_config.set_value(CONTROLS_SECTION, "touch_controls", mode)
		save_settings()

func get_touch_controls_mode() -> String:
	var mode = str(_config.get_value(CONTROLS_SECTION, "touch_controls", "auto"))
	return mode if mode in ["auto", "on", "off"] else "auto"

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

func set_player_skin(skin_id: String) -> void:
	var clean_id := skin_id.strip_edges()
	if clean_id.is_empty():
		clean_id = "default"
	_config.set_value(APPEARANCE_SECTION, "player_skin", clean_id)
	save_settings()
	player_skin_changed.emit(clean_id)

func get_player_skin() -> String:
	if _config.has_section_key(APPEARANCE_SECTION, "player_skin"):
		var val := str(_config.get_value(APPEARANCE_SECTION, "player_skin", "default")).strip_edges()
		return val if not val.is_empty() else "default"
	return "default"

func set_music_track(track_id: String) -> void:
	var clean_id := track_id.strip_edges()
	if clean_id.is_empty():
		clean_id = "dynamic"
	_config.set_value(AUDIO_SECTION, "music_track", clean_id)
	save_settings()
	music_track_changed.emit(clean_id)

func get_music_track() -> String:
	if _config.has_section_key(AUDIO_SECTION, "music_track"):
		var val := str(_config.get_value(AUDIO_SECTION, "music_track", "dynamic")).strip_edges()
		return val if not val.is_empty() else "dynamic"
	return "dynamic"
