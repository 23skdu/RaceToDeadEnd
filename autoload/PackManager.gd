extends Node

signal pack_discovered(pack_id: String, name: String)
signal pack_activated(pack_id: String, content_type: String)
signal pack_deactivated(content_type: String)
signal pack_validation_failed(pack_id: String, error: String)
signal skin_loaded(entity: String, texture: Texture2D)
signal theme_color_loaded(key: String, color: Color)
signal theme_texture_loaded(key: String, texture: Texture2D)

const PACKS_DIR: String = "user://packs/"
const MAX_PACK_SIZE_BYTES: int = 50 * 1024 * 1024  # 50 MB

var discovered_packs: Dictionary = {}
var active_packs: Dictionary = {
	"music": "",
	"skin": "",
	"theme": ""
}

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(PACKS_DIR):
		DirAccess.make_dir_recursive_absolute(PACKS_DIR)
	_scan_packs()

func _scan_packs() -> void:
	if not DirAccess.dir_exists_absolute(PACKS_DIR):
		return
	var dir = DirAccess.open(PACKS_DIR)
	if not dir: return
	
	dir.list_dir_begin()
	var folder = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != "." and folder != "..":
			var manifest_path = PACKS_DIR.path_join(folder).path_join("pack.json")
			if FileAccess.file_exists(manifest_path):
				_load_manifest(manifest_path, folder)
		folder = dir.get_next()
	dir.list_dir_end()

func _load_manifest(path: String, folder: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json_text = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		pack_validation_failed.emit(folder, "Invalid JSON")
		return
	var data = json.data
	if not _validate_manifest(data, folder):
		return
	discovered_packs[data.pack_id] = {
		"data": data,
		"folder": PACKS_DIR.path_join(folder),
		"size": _get_folder_size(PACKS_DIR.path_join(folder))
	}
	pack_discovered.emit(data.pack_id, data.name)

func _validate_manifest(data: Dictionary, folder: String) -> bool:
	if not data.has("pack_id") or not data.has("name"):
		pack_validation_failed.emit(folder, "Missing pack_id or name")
		return false
	
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	if not regex.search(data.pack_id):
		pack_validation_failed.emit(folder, "Invalid pack_id format")
		return false
		
	if not data.has("content_types") or typeof(data.content_types) != TYPE_ARRAY:
		pack_validation_failed.emit(folder, "Missing content_types")
		return false
		
	var base = PACKS_DIR.path_join(folder)
	for content_type in data.content_types:
		if not _validate_content_section(data, content_type, base):
			return false
	return true

func _validate_content_section(data: Dictionary, type: String, base: String) -> bool:
	match type:
		"music":
			if data.has("music") and data.music.has("tracks"):
				for track in data.music.tracks:
					if not FileAccess.file_exists(base.path_join(track)):
						pack_validation_failed.emit(data.pack_id, "Missing track: " + track)
						return false
		"skin":
			if data.has("skins"):
				if data.skins.has("player"):
					if not FileAccess.file_exists(base.path_join(data.skins.player)):
						pack_validation_failed.emit(data.pack_id, "Missing player skin")
						return false
				if data.skins.has("enemies"):
					for enemy in data.skins.enemies:
						if not FileAccess.file_exists(base.path_join(data.skins.enemies[enemy])):
							pack_validation_failed.emit(data.pack_id, "Missing enemy skin: " + enemy)
							return false
		"theme":
			if data.has("theme"):
				if data.theme.has("palette"):
					for color_key in data.theme.palette:
						if not _is_valid_hex_color(data.theme.palette[color_key]):
							pack_validation_failed.emit(data.pack_id, "Invalid color: " + color_key)
							return false
	return true

func _is_valid_hex_color(s: String) -> bool:
	if not s.begins_with("#"):
		return false
	if s.length() != 7:
		return false
	return true

func _get_folder_size(path: String) -> int:
	var total = 0
	var dir = DirAccess.open(path)
	if not dir:
		return 0
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file != "." and file != "..":
			if dir.current_is_dir():
				total += _get_folder_size(path.path_join(file))
			else:
				var file_access = FileAccess.open(path.path_join(file), FileAccess.READ)
				if file_access:
					total += file_access.get_length()
		file = dir.get_next()
	dir.list_dir_end()
	return total

func activate_pack(pack_id: String, content_type: String) -> bool:
	if not discovered_packs.has(pack_id):
		return false
	var pack = discovered_packs[pack_id]
	if pack.size > MAX_PACK_SIZE_BYTES:
		return false
	active_packs[content_type] = pack_id
	pack_activated.emit(pack_id, content_type)
	_apply_pack_content(pack, content_type)
	return true

func deactivate_pack(content_type: String) -> void:
	active_packs[content_type] = ""
	pack_deactivated.emit(content_type)
	_revert_pack_content(content_type)

func _apply_pack_content(pack: Dictionary, content_type: String) -> void:
	match content_type:
		"music":
			_apply_music_pack(pack.data)
		"skin":
			_apply_skin_pack(pack.data, pack.folder)
		"theme":
			_apply_theme_pack(pack.data, pack.folder)

func _apply_music_pack(data: Dictionary) -> void:
	if data.has("music") and data.music.has("tracks"):
		var base = discovered_packs[data.pack_id].folder
		var tracks: Array[AudioStream] = []
		for track_path in data.music.tracks:
			var full_path = base.path_join(track_path)
			var stream = load(full_path)
			if stream and stream is AudioStream:
				tracks.append(stream)
		if tracks.size() > 0:
			if AudioManager.has_method("set_playlist"):
				AudioManager.set_playlist(tracks, data.music.get("shuffle", true))

func _apply_skin_pack(data: Dictionary, base: String) -> void:
	if data.has("skins"):
		if data.skins.has("player"):
			var path = base.path_join(data.skins.player)
			var tex = load(path) as Texture2D
			if tex:
				skin_loaded.emit("player", tex)
		if data.skins.has("enemies"):
			for enemy in data.skins.enemies:
				var path = base.path_join(data.skins.enemies[enemy])
				var tex = load(path) as Texture2D
				if tex:
					skin_loaded.emit(enemy, tex)

func _apply_theme_pack(data: Dictionary, base: String) -> void:
	if data.has("theme"):
		var theme = data.theme
		if theme.has("palette"):
			for color_key in theme.palette:
				var color = Color(theme.palette[color_key])
				theme_color_loaded.emit(color_key, color)
		if theme.has("highway_lane"):
			var tex = load(base.path_join(theme.highway_lane)) as Texture2D
			if tex:
				theme_texture_loaded.emit("highway_lane", tex)

func _revert_pack_content(content_type: String) -> void:
	match content_type:
		"music":
			if AudioManager.has_method("revert_to_default_music"):
				AudioManager.revert_to_default_music()
		"skin":
			skin_loaded.emit("player", null)
			skin_loaded.emit("rotor", null)
			skin_loaded.emit("scav", null)
			skin_loaded.emit("drone", null)
		"theme":
			theme_color_loaded.emit("lane_color", Color(0.18, 0.18, 0.22))
			theme_color_loaded.emit("shoulder_color", Color(0.76, 0.64, 0.42))
			theme_color_loaded.emit("stripe_color", Color(1.0, 1.0, 0.8))
			theme_color_loaded.emit("guardrail_color", Color(1.0, 1.0, 0.8))

func get_active_pack_id(content_type: String) -> String:
	return active_packs.get(content_type, "")

func get_discovered_pack_ids() -> Array[String]:
	var result: Array[String] = []
	for k in discovered_packs.keys():
		result.append(str(k))
	return result

func get_pack_info(pack_id: String) -> Dictionary:
	if discovered_packs.has(pack_id):
		return discovered_packs[pack_id].data
	return {}
