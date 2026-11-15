extends CanvasLayer

signal back_to_menu_requested

const MainScript = preload("res://scripts/scenes/Main.gd")
const AUTHOR_NAME: String = "23skdu"
const GITHUB_URL: String = "https://github.com/23skdu/RaceToDeadEnd"
const AUTHOR_URL: String = "https://github.com/23skdu"

@onready var back_button: Button = $Panel/BackButton
@onready var author_label: Label = $Panel/AuthorLabel
@onready var version_label: Label = $Panel/VersionLabel
@onready var github_button: Button = $Panel/GitHubButton
@onready var author_button: Button = $Panel/AuthorButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	github_button.pressed.connect(_on_github_pressed)
	if author_button:
		author_button.pressed.connect(_on_author_pressed)
	if author_label:
		author_label.text = "AUTHOR: " + AUTHOR_NAME
	if version_label:
		var info := MainScript._load_build_info()
		var ver := str(info.get("version", ProjectSettings.get_setting("application/config/version", "0.2.0")))
		var sha := str(info.get("commit_sha", ""))
		version_label.text = "BUILD: " + MainScript.format_version_text(ver, sha)
	if github_button:
		github_button.text = "GITHUB: " + GITHUB_URL

func _on_github_pressed() -> void:
	OS.shell_open(GITHUB_URL)

func _on_author_pressed() -> void:
	OS.shell_open(AUTHOR_URL)

func _on_back_pressed() -> void:
	back_to_menu_requested.emit()
