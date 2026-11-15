extends Node

const BUILD_INFO_PATH: String = "res://build_info.json"

@onready var start_button: Button = $CanvasLayer/StartButton
@onready var garage_button: Button = $CanvasLayer/GarageButton
@onready var info_button: Button = $CanvasLayer/InfoButton
@onready var options_button: Button = $CanvasLayer/OptionsButton
@onready var quit_button: Button = $CanvasLayer/QuitButton
@onready var version_label: Label = get_node_or_null("CanvasLayer/VersionLabel")

func _ready() -> void:
	if version_label:
		var info := _load_build_info()
		var ver := str(info.get("version", ProjectSettings.get_setting("application/config/version", "0.2.0")))
		var sha := str(info.get("commit_sha", ""))
		version_label.text = format_version_text(ver, sha)
	start_button.pressed.connect(_on_start_pressed)
	garage_button.pressed.connect(_on_garage_pressed)
	info_button.pressed.connect(_on_info_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_setup_daily_run_button()
	_setup_about_button()
	GameManager.state = GameManager.GameState.MENU
	AudioManager.play_menu_music()
	
	var bg: TextureRect = $CanvasLayer/Background
	if bg:
		bg.anchor_left = 0.1
		bg.anchor_top = 0.1
		bg.anchor_right = 0.9
		bg.anchor_bottom = 0.9
		bg.offset_left = 0
		bg.offset_top = 0
		bg.offset_right = 0
		bg.offset_bottom = 0
		bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
		bg.grow_vertical = Control.GROW_DIRECTION_BOTH

static func format_version_text(version: String, commit_sha: String = "") -> String:
	var clean_ver := version.strip_edges()
	if clean_ver.begins_with("v"):
		clean_ver = clean_ver.substr(1)
	if clean_ver.is_empty():
		clean_ver = "0.0.0"
	var clean_sha := commit_sha.strip_edges()
	if clean_sha.is_empty() or clean_sha == "unknown":
		return "v" + clean_ver
	return "v%s (%s)" % [clean_ver, clean_sha.substr(0, 7)]

static func _load_build_info() -> Dictionary:
	var info := {
		"version": str(ProjectSettings.get_setting("application/config/version", "0.2.0")),
		"commit_sha": "",
	}
	if FileAccess.file_exists(BUILD_INFO_PATH):
		var f := FileAccess.open(BUILD_INFO_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				if parsed.has("version") and not str(parsed["version"]).is_empty():
					info["version"] = str(parsed["version"])
				if parsed.has("commit_sha"):
					info["commit_sha"] = str(parsed["commit_sha"])
				return info
	var git_sha := _read_local_git_sha()
	if not git_sha.is_empty():
		info["commit_sha"] = git_sha
	return info

static func _read_local_git_sha() -> String:
	var head_path := "res://.git/HEAD"
	if not FileAccess.file_exists(head_path):
		return ""
	var hf := FileAccess.open(head_path, FileAccess.READ)
	if not hf:
		return ""
	var head_content := hf.get_as_text().strip_edges()
	hf.close()
	if head_content.begins_with("ref: "):
		var ref_path := "res://.git/" + head_content.substr(5).strip_edges()
		if FileAccess.file_exists(ref_path):
			var rf := FileAccess.open(ref_path, FileAccess.READ)
			if rf:
				var sha := rf.get_as_text().strip_edges()
				rf.close()
				return sha.substr(0, 7)
		var packed_path := "res://.git/packed-refs"
		if FileAccess.file_exists(packed_path):
			var pf := FileAccess.open(packed_path, FileAccess.READ)
			if pf:
				var target_ref := head_content.substr(5).strip_edges()
				while not pf.eof_reached():
					var line := pf.get_line().strip_edges()
					if line.ends_with(" " + target_ref):
						pf.close()
						return line.split(" ")[0].substr(0, 7)
				pf.close()
		return ""
	return head_content.substr(0, 7) if head_content.length() >= 7 else ""

func _on_info_pressed() -> void:
	var info = preload("res://scenes/ui/InterceptorInfo.tscn").instantiate()
	add_child(info)
	info.back_to_menu_requested.connect(func(): info.queue_free())

var daily_run_button: Button = null
var about_button: Button = null

func _setup_daily_run_button() -> void:
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas:
		return
	daily_run_button = Button.new()
	daily_run_button.name = "DailyRunButton"
	daily_run_button.text = "DAILY RUN"
	daily_run_button.offset_left = 810.0
	daily_run_button.offset_top = 300.0
	daily_run_button.offset_right = 990.0
	daily_run_button.offset_bottom = 360.0
	daily_run_button.pressed.connect(_on_daily_run_pressed)
	canvas.add_child(daily_run_button)

func _setup_about_button() -> void:
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas:
		return
	about_button = Button.new()
	about_button.name = "AboutButton"
	about_button.text = "ABOUT"
	about_button.offset_left = 810.0
	about_button.offset_top = 380.0
	about_button.offset_right = 990.0
	about_button.offset_bottom = 440.0
	about_button.pressed.connect(_on_about_pressed)
	canvas.add_child(about_button)

func _on_about_pressed() -> void:
	var about = preload("res://scenes/ui/About.tscn").instantiate()
	add_child(about)
	about.back_to_menu_requested.connect(func(): about.queue_free())

func _on_daily_run_pressed() -> void:
	GameManager.daily_run_active = true
	GameManager.daily_seed = GameManager.compute_daily_seed()
	TransitionLayer.change_scene("res://scenes/Game.tscn")

func _on_start_pressed() -> void:
	GameManager.daily_run_active = false
	TransitionLayer.change_scene("res://scenes/Game.tscn")

func _on_garage_pressed() -> void:
	var garage = preload("res://scenes/ui/Garage.tscn").instantiate()
	add_child(garage)
	garage.back_to_menu_requested.connect(func(): garage.queue_free())
	garage.start_run_requested.connect(func():
		garage.queue_free()
		TransitionLayer.change_scene("res://scenes/Game.tscn")
	)

func _on_options_pressed() -> void:
	var options = preload("res://scenes/ui/Options.tscn").instantiate()
	add_child(options)
	options.back_to_menu_requested.connect(func(): options.queue_free())

func _on_quit_pressed() -> void:
	get_tree().quit()
