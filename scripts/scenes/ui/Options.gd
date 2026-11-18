extends CanvasLayer

signal back_to_menu_requested

const LocalizationUtilScript = preload("res://scripts/utils/LocalizationUtil.gd")
const AccessibilityUtilScript = preload("res://scripts/utils/AccessibilityUtil.gd")
const OnlineLeaderboardScript = preload("res://scripts/utils/OnlineLeaderboard.gd")
const RoadmapWorld = preload("res://scripts/utils/RoadmapWorld.gd")

@onready var panel: NinePatchRect = $Panel
@onready var tab_container: TabContainer = $Panel/TabContainer
@onready var master_slider: HSlider = $Panel/TabContainer/AudioTab/MasterSlider
@onready var music_slider: HSlider = $Panel/TabContainer/AudioTab/MusicSlider
@onready var sfx_slider: HSlider = $Panel/TabContainer/AudioTab/SFXSlider
@onready var fullscreen_check: CheckButton = $Panel/TabContainer/AudioTab/FullscreenCheck
@onready var input_remap = $Panel/TabContainer/InputTab/InputRemap
@onready var back_button: Button = $Panel/BackButton

@onready var title_label: Label = $Panel/Title
@onready var locale_option: OptionButton = $Panel/TabContainer/AccessibilityTab/LocaleOption
@onready var high_contrast_check: CheckButton = $Panel/TabContainer/AccessibilityTab/HighContrastCheck
@onready var colorblind_option: OptionButton = $Panel/TabContainer/AccessibilityTab/ColorblindOption
@onready var reduce_motion_check: CheckButton = $Panel/TabContainer/AccessibilityTab/ReduceMotionCheck
@onready var feature_toggles: VBoxContainer = $Panel/TabContainer/AccessibilityTab/FeatureToggles
@onready var leaderboard_endpoint: LineEdit = $Panel/TabContainer/LeaderboardTab/EndpointInput
@onready var player_name_input: LineEdit = $Panel/TabContainer/LeaderboardTab/PlayerNameInput
@onready var fetch_scores_button: Button = $Panel/TabContainer/LeaderboardTab/FetchScoresButton
@onready var submit_score_button: Button = $Panel/TabContainer/LeaderboardTab/SubmitScoreButton
@onready var leaderboard_status: Label = $Panel/TabContainer/LeaderboardTab/LeaderboardStatus
@onready var leaderboard_list: Label = $Panel/TabContainer/LeaderboardTab/LeaderboardList
@onready var online_leaderboard: Node = $OnlineLeaderboard

var _music_track_option: OptionButton = null
var _resolution_option: OptionButton = null
var _localization = null
var _accessibility = null
var _locale_codes: Array[String] = []
var _colorblind_modes: Array[String] = ["none", "protanopia", "deuteranopia", "tritanopia"]

const RESOLUTION_OPTIONS: Array[Dictionary] = [
	{"label": "1280x720 (HD)", "size": Vector2i(1280, 720)},
	{"label": "1920x1080 (Full HD)", "size": Vector2i(1920, 1080)},
	{"label": "2560x1440 (QHD)", "size": Vector2i(2560, 1440)},
	{"label": "3840x2160 (4K UHD)", "size": Vector2i(3840, 2160)},
]

func _ready() -> void:
	_localization = LocalizationUtilScript.new()
	_accessibility = AccessibilityUtilScript.new()

	back_button.pressed.connect(_on_back_pressed)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_load_volume_settings()
	_load_fullscreen_setting()
	_restore_locale()
	_setup_music_track_selector()
	_setup_resolution_selector()
	_setup_touch_toggle()
	_setup_locale_selector()
	_setup_accessibility_controls()
	_setup_feature_toggles()
	_setup_online_leaderboard()
	_setup_focus_navigation()
	_apply_localized_texts()
	_apply_accessibility_settings()
	_describe_controls()

	if not input_remap.is_inside_tree():
		await input_remap.ready
	input_remap.load_bindings()

func _restore_locale() -> void:
	if not SettingsManager.is_feature_enabled(Constants.FEATURE_LOCALIZATION, true):
		_localization.apply_locale(LocalizationUtilScript.DEFAULT_LOCALE)
		return
	var saved := str(SettingsManager.get_roadmap_value("locale", LocalizationUtilScript.DEFAULT_LOCALE))
	_localization.apply_locale(saved)

func _t(key: String, fallback: String = "") -> String:
	return LocalizationUtilScript.t(key, fallback)

func _setup_locale_selector() -> void:
	if not is_instance_valid(locale_option):
		return
	_locale_codes.clear()
	locale_option.clear()
	for code in LocalizationUtilScript.SUPPORTED_LOCALES:
		_locale_codes.append(code)
		locale_option.add_item(LocalizationUtilScript.locale_name(code), _locale_codes.size() - 1)
	var current := LocalizationUtilScript.normalized_locale(TranslationServer.get_locale())
	var selected := _locale_codes.find(current)
	locale_option.select(maxi(0, selected))
	if not locale_option.item_selected.is_connected(_on_locale_selected):
		locale_option.item_selected.connect(_on_locale_selected)

func _on_locale_selected(index: int) -> void:
	if index < 0 or index >= _locale_codes.size():
		return
	var code := _locale_codes[index]
	if SettingsManager.is_feature_enabled(Constants.FEATURE_LOCALIZATION, true):
		_localization.apply_locale(code)
	SettingsManager.set_roadmap_value("locale", code)
	_apply_localized_texts()
	if _accessibility:
		_accessibility.refresh_descriptions()
		_accessibility.announce(_t("R2DE_LANGUAGE") + ": " + LocalizationUtilScript.locale_name(code))

func _setup_accessibility_controls() -> void:
	if is_instance_valid(high_contrast_check):
		high_contrast_check.set_pressed_no_signal(SettingsManager.get_high_contrast())
		if not high_contrast_check.toggled.is_connected(_on_high_contrast_toggled):
			high_contrast_check.toggled.connect(_on_high_contrast_toggled)
	if is_instance_valid(colorblind_option):
		colorblind_option.clear()
		for mode in _colorblind_modes:
			colorblind_option.add_item(_t("R2DE_COLORBLIND_" + mode, mode))
		var selected := _colorblind_modes.find(SettingsManager.get_colorblind_mode())
		colorblind_option.select(maxi(0, selected))
		if not colorblind_option.item_selected.is_connected(_on_colorblind_selected):
			colorblind_option.item_selected.connect(_on_colorblind_selected)
	if is_instance_valid(reduce_motion_check):
		var reduce: bool = bool(SettingsManager.get_roadmap_value("reduce_motion", false))
		reduce_motion_check.set_pressed_no_signal(reduce)
		if not reduce_motion_check.toggled.is_connected(_on_reduce_motion_toggled):
			reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)

func _on_high_contrast_toggled(enabled: bool) -> void:
	SettingsManager.set_high_contrast(enabled)
	_apply_accessibility_settings()
	if _accessibility:
		_accessibility.announce(_t("R2DE_HIGH_CONTRAST") + ": " + str(enabled))

func _on_colorblind_selected(index: int) -> void:
	if index < 0 or index >= _colorblind_modes.size():
		return
	var mode := _colorblind_modes[index]
	SettingsManager.set_colorblind_mode(mode)
	_apply_accessibility_settings()
	if _accessibility:
		_accessibility.announce(_t("R2DE_COLORBLIND_MODE") + ": " + _t("R2DE_COLORBLIND_" + mode, mode))

func _on_reduce_motion_toggled(enabled: bool) -> void:
	SettingsManager.set_roadmap_value("reduce_motion", enabled)
	if _accessibility:
		_accessibility.announce(_t("R2DE_REDUCE_MOTION") + ": " + str(enabled))

func _apply_accessibility_settings() -> void:
	if not _accessibility:
		return
	_accessibility.apply_palette(
		self,
		SettingsManager.get_high_contrast(),
		SettingsManager.get_colorblind_mode()
	)

func _setup_feature_toggles() -> void:
	if not is_instance_valid(feature_toggles):
		return
	for child in feature_toggles.get_children():
		feature_toggles.remove_child(child)
		child.queue_free()
	for key in Constants.ROADMAP_FEATURE_KEYS:
		var btn := CheckButton.new()
		btn.name = "FeatureToggle_" + key
		btn.text = _t("R2DE_FEATURE_" + key, key)
		btn.set_pressed_no_signal(SettingsManager.is_feature_enabled(key, true))
		btn.toggled.connect(_on_feature_toggle.bind(key))
		feature_toggles.add_child(btn)

func _on_feature_toggle(enabled: bool, key: String) -> void:
	SettingsManager.set_feature_enabled(key, enabled)
	match key:
		Constants.FEATURE_LOCALIZATION:
			if not enabled:
				_localization.apply_locale(LocalizationUtilScript.DEFAULT_LOCALE)
				_apply_localized_texts()
			else:
				_restore_locale()
				_apply_localized_texts()
		Constants.FEATURE_ONLINE_LEADERBOARD:
			_set_leaderboard_controls_enabled(enabled)
		Constants.FEATURE_THEMED_UI:
			_setup_focus_navigation()
	if _accessibility:
		_accessibility.announce(_t("R2DE_FEATURE_" + key, key) + ": " + str(enabled))

func _setup_online_leaderboard() -> void:
	if not is_instance_valid(online_leaderboard):
		online_leaderboard = OnlineLeaderboardScript.new()
		online_leaderboard.name = "OnlineLeaderboard"
		add_child(online_leaderboard)
	var endpoint := str(SettingsManager.get_roadmap_value("leaderboard_endpoint", OnlineLeaderboardScript.INVALID_ENDPOINT))
	online_leaderboard.configure(endpoint, 3.0)
	if is_instance_valid(leaderboard_endpoint):
		leaderboard_endpoint.text = endpoint
		if not leaderboard_endpoint.text_changed.is_connected(_on_endpoint_changed):
			leaderboard_endpoint.text_changed.connect(_on_endpoint_changed)
	if is_instance_valid(player_name_input) and player_name_input.text.is_empty():
		player_name_input.text = str(SettingsManager.get_roadmap_value("leaderboard_player_name", "PLAYER"))
	if is_instance_valid(fetch_scores_button) and not fetch_scores_button.pressed.is_connected(_on_fetch_scores_pressed):
		fetch_scores_button.pressed.connect(_on_fetch_scores_pressed)
	if is_instance_valid(submit_score_button) and not submit_score_button.pressed.is_connected(_on_submit_score_pressed):
		submit_score_button.pressed.connect(_on_submit_score_pressed)
	if not online_leaderboard.entries_received.is_connected(_on_entries_received):
		online_leaderboard.entries_received.connect(_on_entries_received)
	if not online_leaderboard.submission_completed.is_connected(_on_submission_completed):
		online_leaderboard.submission_completed.connect(_on_submission_completed)
	if not online_leaderboard.request_failed.is_connected(_on_request_failed):
		online_leaderboard.request_failed.connect(_on_request_failed)
	_set_leaderboard_controls_enabled(SettingsManager.is_feature_enabled(Constants.FEATURE_ONLINE_LEADERBOARD, true))

func _on_endpoint_changed(new_text: String) -> void:
	SettingsManager.set_roadmap_value("leaderboard_endpoint", new_text.strip_edges())
	online_leaderboard.configure(new_text, 3.0)

func _set_leaderboard_controls_enabled(enabled: bool) -> void:
	if is_instance_valid(leaderboard_endpoint):
		leaderboard_endpoint.editable = enabled
	if is_instance_valid(player_name_input):
		player_name_input.editable = enabled
	if is_instance_valid(fetch_scores_button):
		fetch_scores_button.disabled = not enabled
	if is_instance_valid(submit_score_button):
		submit_score_button.disabled = not enabled

func _on_fetch_scores_pressed() -> void:
	if not SettingsManager.is_feature_enabled(Constants.FEATURE_ONLINE_LEADERBOARD, true):
		return
	if is_instance_valid(leaderboard_status):
		leaderboard_status.text = _t("R2DE_LOADING_SCORES")
	online_leaderboard.fetch_scores(10)

func _on_submit_score_pressed() -> void:
	if not SettingsManager.is_feature_enabled(Constants.FEATURE_ONLINE_LEADERBOARD, true):
		return
	var player_name := "PLAYER"
	if is_instance_valid(player_name_input) and not player_name_input.text.strip_edges().is_empty():
		player_name = player_name_input.text.strip_edges()
	SettingsManager.set_roadmap_value("leaderboard_player_name", player_name)
	var score := maxi(GameManager.score, GameManager.high_score)
	online_leaderboard.submit_score(player_name, score, SettingsManager.get_player_skin())

func _on_entries_received(entries: Array) -> void:
	if not is_instance_valid(leaderboard_list):
		return
	if entries.is_empty():
		leaderboard_list.text = _t("R2DE_NO_SCORES")
		return
	var lines: Array[String] = []
	for i in range(mini(entries.size(), 10)):
		var entry: Dictionary = entries[i] if entries[i] is Dictionary else {}
		lines.append("%2d. %-12s %d" % [
			i + 1,
			str(entry.get("player", "PLAYER")),
			int(entry.get("score", 0)),
		])
	leaderboard_list.text = "\n".join(lines)

func _on_submission_completed(success: bool) -> void:
	if not is_instance_valid(leaderboard_status):
		return
	leaderboard_status.text = _t("R2DE_SCORE_SUBMITTED" if success else "R2DE_SCORE_NOT_SUBMITTED")

func _on_request_failed(message: String) -> void:
	if not is_instance_valid(leaderboard_status):
		return
	leaderboard_status.text = _t("R2DE_LEADERBOARD_FAILED") + "\n" + message

func _setup_focus_navigation() -> void:
	var controls: Array = []
	for node in [
		master_slider, music_slider, sfx_slider, fullscreen_check,
		locale_option, high_contrast_check, colorblind_option, reduce_motion_check,
		leaderboard_endpoint, player_name_input, fetch_scores_button, submit_score_button,
		back_button,
	]:
		if is_instance_valid(node):
			controls.append(node)
	var toggle_children: Array = []
	if is_instance_valid(feature_toggles):
		toggle_children = feature_toggles.get_children()
	for child in toggle_children:
		if child is Control:
			controls.append(child)
	if SettingsManager.is_feature_enabled(Constants.FEATURE_THEMED_UI, true):
		AccessibilityUtilScript.link_focus_chain(controls)
	else:
		for control in controls:
			control.focus_neighbor_left = NodePath("")
			control.focus_neighbor_right = NodePath("")
			control.focus_neighbor_top = NodePath("")
			control.focus_neighbor_bottom = NodePath("")

func _describe_controls() -> void:
	if not _accessibility:
		return
	_accessibility.describe_control(master_slider, _t("R2DE_MASTER_VOLUME", "MASTER VOLUME"), "Adjust master bus volume")
	_accessibility.describe_control(music_slider, _t("R2DE_MUSIC_VOLUME", "MUSIC VOLUME"), "Adjust music bus volume")
	_accessibility.describe_control(sfx_slider, _t("R2DE_SFX_VOLUME", "SFX VOLUME"), "Adjust effects bus volume")
	_accessibility.describe_control(locale_option, _t("R2DE_LOCALE_LABEL"), "Select interface language")
	_accessibility.describe_control(high_contrast_check, _t("R2DE_HIGH_CONTRAST"), "Toggle the high contrast palette")
	_accessibility.describe_control(colorblind_option, _t("R2DE_COLORBLIND_MODE"), "Select a colourblind palette")
	_accessibility.describe_control(fetch_scores_button, _t("R2DE_FETCH_SCORES"), "Fetch the online leaderboard")
	_accessibility.describe_control(submit_score_button, _t("R2DE_SUBMIT_SCORE"), "Submit the current high score")
	_accessibility.describe_control(back_button, _t("R2DE_BACK"), "Return to the main menu")

func _apply_localized_texts() -> void:
	if is_instance_valid(title_label):
		title_label.text = _t("R2DE_OPTIONS_TITLE")
	back_button.text = _t("R2DE_BACK")
	var labels := {
		"MasterLabel": "R2DE_MASTER_VOLUME",
		"MusicLabel": "R2DE_MUSIC_VOLUME",
		"SFXLabel": "R2DE_SFX_VOLUME",
		"LocaleLabel": "R2DE_LOCALE_LABEL",
		"ColorblindLabel": "R2DE_COLORBLIND_MODE",
		"FeaturesHeaderLabel": "R2DE_FEATURES_HEADER",
		"LeaderboardEndpointLabel": "R2DE_LEADERBOARD_ENDPOINT",
		"PlayerNameLabel": "R2DE_PLAYER_NAME",
		"ScoresHeaderLabel": "R2DE_SCORES_HEADER",
	}
	for name in labels:
		var node := get_node_or_null("Panel/TabContainer/AccessibilityTab/" + name)
		if not node:
			node = get_node_or_null("Panel/TabContainer/LeaderboardTab/" + name)
		if node is Label:
			(node as Label).text = _t(String(labels[name]), name)
	fullscreen_check.text = _t("R2DE_FULLSCREEN", "FULLSCREEN")
	high_contrast_check.text = _t("R2DE_HIGH_CONTRAST")
	reduce_motion_check.text = _t("R2DE_REDUCE_MOTION")
	fetch_scores_button.text = _t("R2DE_FETCH_SCORES")
	submit_score_button.text = _t("R2DE_SUBMIT_SCORE")
	if is_instance_valid(colorblind_option):
		for i in _colorblind_modes.size():
			colorblind_option.set_item_text(i, _t("R2DE_COLORBLIND_" + _colorblind_modes[i], _colorblind_modes[i]))
	_tab_container_titles()

func _tab_container_titles() -> void:
	if not is_instance_valid(tab_container):
		return
	var keys := ["R2DE_AUDIO_TAB", "R2DE_INPUT_TAB", "R2DE_ACCESSIBILITY_TAB", "R2DE_LEADERBOARD_TAB"]
	for i in mini(tab_container.get_tab_count(), keys.size()):
		tab_container.set_tab_title(i, _t(keys[i]))

func _setup_music_track_selector() -> void:
	var audio_tab = get_node_or_null("Panel/TabContainer/AudioTab")
	if not audio_tab or not AudioManager or not AudioManager.has_method("get_music_options"):
		return
	var row = HBoxContainer.new()
	row.name = "MusicTrackRow"
	row.add_theme_constant_override("separation", 10)

	var lbl = Label.new()
	lbl.text = _t("R2DE_MUSIC_TRACK", "MUSIC TRACK")
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

func _setup_resolution_selector() -> void:
	var audio_tab = get_node_or_null("Panel/TabContainer/AudioTab")
	if not audio_tab:
		return
	var row = HBoxContainer.new()
	row.name = "ResolutionRow"
	row.add_theme_constant_override("separation", 10)

	var lbl = Label.new()
	lbl.text = _t("R2DE_RESOLUTION", "RESOLUTION")
	row.add_child(lbl)

	_resolution_option = OptionButton.new()
	_resolution_option.name = "ResolutionOption"
	_resolution_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resolution_option.tooltip_text = "Supported display modes: " + str(RoadmapWorld.SUPPORTED_RESOLUTIONS.size())
	var current_size := DisplayServer.window_get_size()
	var selected_idx := 0
	for i in RESOLUTION_OPTIONS.size():
		var opt := RESOLUTION_OPTIONS[i]
		_resolution_option.add_item(str(opt["label"]), i)
		_resolution_option.set_item_metadata(i, opt["size"])
		var sz: Vector2i = opt["size"]
		if sz == current_size:
			selected_idx = i
	_resolution_option.select(selected_idx)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	row.add_child(_resolution_option)
	audio_tab.add_child(row)

func _on_resolution_selected(index: int) -> void:
	if not is_instance_valid(_resolution_option):
		return
	var sz: Vector2i = _resolution_option.get_item_metadata(index)
	if sz.x > 0 and sz.y > 0:
		DisplayServer.window_set_size(sz)

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
	btn.text = _t("R2DE_TOUCH_CONTROLS", "Touch Controls") + ": " + SettingsManager.get_touch_controls_mode().to_upper()

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
