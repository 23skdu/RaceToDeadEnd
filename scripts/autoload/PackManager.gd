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
const ALLOWED_IMAGE_EXTS: Array[String] = ["png", "webp", "jpg", "jpeg"]
const ALLOWED_AUDIO_EXTS: Array[String] = ["ogg", "mp3", "wav"]

var discovered_packs: Dictionary = {}
var active_packs: Dictionary = {
	"music": "",
	"skin": "",
	"theme": ""
}
var custom_skins: Dictionary = {}
var custom_theme_colors: Dictionary = {}
var custom_theme_textures: Dictionary = {}

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

func _resolve_safe_pack_path(base: String, rel_path: Variant, allowed_exts: Array[String]) -> String:
	if typeof(rel_path) != TYPE_STRING:
		return ""
	var rel: String = str(rel_path).strip_edges()
	if rel.is_empty() or base.is_empty():
		return ""
	if rel.contains("://") or rel.begins_with("/") or rel.begins_with("\\") or rel.contains("\\") or rel.contains("..") or rel.contains(":"):
		return ""
	var base_clean := base.simplify_path().trim_suffix("/")
	var joined := base_clean.path_join(rel).simplify_path()
	if not joined.begins_with(base_clean + "/"):
		return ""
	if not (joined.get_extension().to_lower() in allowed_exts):
		return ""
	return joined

func _validate_content_section(data: Dictionary, type: String, base: String) -> bool:
	match type:
		"music":
			if data.has("music") and typeof(data.music) == TYPE_DICTIONARY and data.music.has("tracks"):
				if typeof(data.music.tracks) != TYPE_ARRAY:
					pack_validation_failed.emit(data.pack_id, "Invalid tracks array")
					return false
				for track in data.music.tracks:
					var safe_track := _resolve_safe_pack_path(base, track, ALLOWED_AUDIO_EXTS)
					if safe_track.is_empty() or not FileAccess.file_exists(safe_track):
						pack_validation_failed.emit(data.pack_id, "Invalid or missing track: " + str(track))
						return false
		"skin":
			if data.has("skins") and typeof(data.skins) == TYPE_DICTIONARY:
				if data.skins.has("player"):
					var safe_player := _resolve_safe_pack_path(base, data.skins.player, ALLOWED_IMAGE_EXTS)
					if safe_player.is_empty() or not FileAccess.file_exists(safe_player):
						pack_validation_failed.emit(data.pack_id, "Invalid or missing player skin")
						return false
				if data.skins.has("enemies") and typeof(data.skins.enemies) == TYPE_DICTIONARY:
					for enemy in data.skins.enemies:
						var safe_enemy := _resolve_safe_pack_path(base, data.skins.enemies[enemy], ALLOWED_IMAGE_EXTS)
						if safe_enemy.is_empty() or not FileAccess.file_exists(safe_enemy):
							pack_validation_failed.emit(data.pack_id, "Invalid or missing enemy skin: " + str(enemy))
							return false
		"theme":
			if data.has("theme") and typeof(data.theme) == TYPE_DICTIONARY:
				if data.theme.has("palette") and typeof(data.theme.palette) == TYPE_DICTIONARY:
					for color_key in data.theme.palette:
						if typeof(data.theme.palette[color_key]) != TYPE_STRING or not _is_valid_hex_color(data.theme.palette[color_key]):
							pack_validation_failed.emit(data.pack_id, "Invalid color: " + str(color_key))
							return false
				if data.theme.has("highway_lane"):
					var safe_tex := _resolve_safe_pack_path(base, data.theme.highway_lane, ALLOWED_IMAGE_EXTS)
					if safe_tex.is_empty() or not FileAccess.file_exists(safe_tex):
						pack_validation_failed.emit(data.pack_id, "Invalid or missing theme texture")
						return false
	return true

func _is_valid_hex_color(s: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^#[0-9a-fA-F]{6}$")
	return regex.search(s) != null

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
	if SettingsManager and SettingsManager.has_method("set_active_pack"):
		SettingsManager.set_active_pack(content_type, pack_id)
	return true

func deactivate_pack(content_type: String) -> void:
	active_packs[content_type] = ""
	pack_deactivated.emit(content_type)
	_revert_pack_content(content_type)
	if SettingsManager and SettingsManager.has_method("set_active_pack"):
		SettingsManager.set_active_pack(content_type, "")

func _apply_pack_content(pack: Dictionary, content_type: String) -> void:
	match content_type:
		"music":
			_apply_music_pack(pack.data, pack.get("folder", ""))
		"skin":
			_apply_skin_pack(pack.data, pack.get("folder", ""))
		"theme":
			_apply_theme_pack(pack.data, pack.get("folder", ""))

func _load_image_texture(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)

func _load_audio_stream(path: String) -> AudioStream:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var ext := path.get_extension().to_lower()
	match ext:
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null

func _apply_music_pack(data: Dictionary, base: String = "") -> void:
	if data.has("music") and typeof(data.music) == TYPE_DICTIONARY and data.music.has("tracks"):
		if base.is_empty() and discovered_packs.has(data.pack_id):
			base = discovered_packs[data.pack_id].folder
		var tracks: Array[AudioStream] = []
		for track_path in data.music.tracks:
			var safe_path := _resolve_safe_pack_path(base, track_path, ALLOWED_AUDIO_EXTS)
			var stream := _load_audio_stream(safe_path)
			if stream and stream is AudioStream:
				tracks.append(stream)
		if tracks.size() > 0:
			if AudioManager.has_method("set_playlist"):
				AudioManager.set_playlist(tracks, data.music.get("shuffle", true))

func _apply_skin_pack(data: Dictionary, base: String) -> void:
	if data.has("skins") and typeof(data.skins) == TYPE_DICTIONARY:
		if data.skins.has("player"):
			var safe_path := _resolve_safe_pack_path(base, data.skins.player, ALLOWED_IMAGE_EXTS)
			var tex := _load_image_texture(safe_path)
			if tex:
				custom_skins["player"] = tex
				skin_loaded.emit("player", tex)
		if data.skins.has("enemies") and typeof(data.skins.enemies) == TYPE_DICTIONARY:
			for enemy in data.skins.enemies:
				var safe_path := _resolve_safe_pack_path(base, data.skins.enemies[enemy], ALLOWED_IMAGE_EXTS)
				var tex := _load_image_texture(safe_path)
				if tex:
					custom_skins[enemy] = tex
					skin_loaded.emit(enemy, tex)

func _apply_theme_pack(data: Dictionary, base: String) -> void:
	if data.has("theme") and typeof(data.theme) == TYPE_DICTIONARY:
		var theme = data.theme
		if theme.has("palette") and typeof(theme.palette) == TYPE_DICTIONARY:
			for color_key in theme.palette:
				if typeof(theme.palette[color_key]) == TYPE_STRING and _is_valid_hex_color(theme.palette[color_key]):
					var color = Color(theme.palette[color_key])
					custom_theme_colors[color_key] = color
					theme_color_loaded.emit(color_key, color)
		if theme.has("highway_lane"):
			var safe_path := _resolve_safe_pack_path(base, theme.highway_lane, ALLOWED_IMAGE_EXTS)
			var tex := _load_image_texture(safe_path)
			if tex:
				custom_theme_textures["highway_lane"] = tex
				theme_texture_loaded.emit("highway_lane", tex)

func _revert_pack_content(content_type: String) -> void:
	match content_type:
		"music":
			if AudioManager.has_method("revert_to_default_music"):
				AudioManager.revert_to_default_music()
		"skin":
			custom_skins.clear()
			skin_loaded.emit("player", null)
			skin_loaded.emit("bunny", null)
			skin_loaded.emit("rotor", null)
			skin_loaded.emit("scav", null)
			skin_loaded.emit("drone", null)
		"theme":
			custom_theme_colors.clear()
			custom_theme_textures.clear()
			theme_color_loaded.emit("lane_color", Color(0.18, 0.18, 0.22))
			theme_color_loaded.emit("shoulder_color", Color(0.76, 0.64, 0.42))
			theme_color_loaded.emit("stripe_color", Color(1.0, 1.0, 0.8))
			theme_color_loaded.emit("guardrail_color", Color(1.0, 1.0, 0.8))
			theme_texture_loaded.emit("highway_lane", null)

func get_custom_skin(entity: String) -> Texture2D:
	return custom_skins.get(entity, null)

func get_custom_theme_color(key: String) -> Variant:
	return custom_theme_colors.get(key, null)

func get_custom_theme_texture(key: String) -> Texture2D:
	return custom_theme_textures.get(key, null)

func load_pack_preview_texture(pack_id: String, rel_path: String) -> Texture2D:
	if not discovered_packs.has(pack_id):
		return null
	var base: String = discovered_packs[pack_id].get("folder", "")
	var safe_path := _resolve_safe_pack_path(base, rel_path, ALLOWED_IMAGE_EXTS)
	return _load_image_texture(safe_path)

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
