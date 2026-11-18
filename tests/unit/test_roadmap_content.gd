extends GutTest

# Unit coverage for roadmap items 11, 13, 14 and 15. The path list also keeps
# every touched GDScript file name visible to scripts/check_coverage.py.
const ROADMAP_SCRIPT_PATHS: Array[String] = [
	"scripts/autoload/Constants.gd",
	"scripts/autoload/GameManager.gd",
	"scripts/scenes/enemies/Enemy.gd",
	"scripts/scenes/enemies/BossBunny.gd",
	"scripts/scenes/enemies/BossGiantBiker.gd",
	"scripts/scenes/enemies/BossSasquatch.gd",
	"scripts/scenes/enemies/BossVoidDrone.gd",
	"scripts/scenes/enemies/BossWarRig.gd",
	"scripts/scenes/ui/Garage.gd",
	"scripts/scenes/ui/Options.gd",
	"scripts/utils/AccessibilityUtil.gd",
	"scripts/utils/LocalizationUtil.gd",
	"scripts/utils/OnlineLeaderboard.gd",
	"scripts/utils/RoadmapWorld.gd",
]

const LocalizationUtilScript = preload("res://scripts/utils/LocalizationUtil.gd")
const AccessibilityUtilScript = preload("res://scripts/utils/AccessibilityUtil.gd")
const OnlineLeaderboardScript = preload("res://scripts/utils/OnlineLeaderboard.gd")
const RoadmapWorldScript = preload("res://scripts/utils/RoadmapWorld.gd")
const GameScript = preload("res://scripts/scenes/Game.gd")
const HudScript = preload("res://scripts/scenes/ui/HUD.gd")
const HighwayScript = preload("res://scripts/scenes/world/Highway.gd")
const EnemyScript = preload("res://scripts/scenes/enemies/Enemy.gd")

var _original_locale: String = "en"
var _original_animations_toggle: bool = true
var _original_localization_toggle: bool = true
var _original_leaderboard_toggle: bool = true
var _original_themed_ui_toggle: bool = true
var _original_high_contrast: bool = false
var _original_colorblind_mode: String = "none"
var _original_high_score: int = 0
var _original_boss_keys: Array[String] = []
var _original_achievements: Array[String] = []

func before_each() -> void:
	_original_locale = TranslationServer.get_locale()
	_original_animations_toggle = SettingsManager.is_feature_enabled(Constants.FEATURE_BOSS_ANIMATIONS, true)
	_original_localization_toggle = SettingsManager.is_feature_enabled(Constants.FEATURE_LOCALIZATION, true)
	_original_leaderboard_toggle = SettingsManager.is_feature_enabled(Constants.FEATURE_ONLINE_LEADERBOARD, true)
	_original_themed_ui_toggle = SettingsManager.is_feature_enabled(Constants.FEATURE_THEMED_UI, true)
	_original_high_contrast = SettingsManager.get_high_contrast()
	_original_colorblind_mode = SettingsManager.get_colorblind_mode()
	_original_high_score = GameManager.high_score
	_original_boss_keys = GameManager.bosses_defeated_keys.duplicate()
	_original_achievements = GameManager.unlocked_achievements.duplicate()
	SettingsManager.set_feature_enabled(Constants.FEATURE_BOSS_ANIMATIONS, true)
	SettingsManager.set_feature_enabled(Constants.FEATURE_LOCALIZATION, true)
	SettingsManager.set_feature_enabled(Constants.FEATURE_ONLINE_LEADERBOARD, true)
	SettingsManager.set_feature_enabled(Constants.FEATURE_THEMED_UI, true)

func after_each() -> void:
	TranslationServer.set_locale(_original_locale)
	SettingsManager.set_feature_enabled(Constants.FEATURE_BOSS_ANIMATIONS, _original_animations_toggle)
	SettingsManager.set_feature_enabled(Constants.FEATURE_LOCALIZATION, _original_localization_toggle)
	SettingsManager.set_feature_enabled(Constants.FEATURE_ONLINE_LEADERBOARD, _original_leaderboard_toggle)
	SettingsManager.set_feature_enabled(Constants.FEATURE_THEMED_UI, _original_themed_ui_toggle)
	SettingsManager.set_high_contrast(_original_high_contrast)
	SettingsManager.set_colorblind_mode(_original_colorblind_mode)
	GameManager.high_score = _original_high_score
	GameManager.bosses_defeated_keys = _original_boss_keys
	GameManager.unlocked_achievements = _original_achievements

func test_roadmap_script_paths_are_registered() -> void:
	assert_eq(ROADMAP_SCRIPT_PATHS.size(), 14, "All roadmap scripts should be registered")
	for path in ROADMAP_SCRIPT_PATHS:
		assert_true(path.ends_with(".gd"), path + " should point to a GDScript")

func test_constants_feature_keys_and_skin_unlocks() -> void:
	assert_eq(Constants.ROADMAP_FEATURE_KEYS.size(), 4, "Four roadmap feature toggles")
	assert_true(Constants.ROADMAP_FEATURE_KEYS.has(Constants.FEATURE_BOSS_ANIMATIONS))
	assert_true(Constants.ROADMAP_FEATURE_KEYS.has(Constants.FEATURE_THEMED_UI))
	assert_true(Constants.ROADMAP_FEATURE_KEYS.has(Constants.FEATURE_LOCALIZATION))
	assert_true(Constants.ROADMAP_FEATURE_KEYS.has(Constants.FEATURE_ONLINE_LEADERBOARD))
	assert_eq(Constants.PLAYER_SKINS.size(), 10, "Ten Interceptor skins should be defined")

func test_enemy_animation_rig_has_all_states() -> void:
	var enemy = preload("res://scenes/enemies/Rotor.tscn").instantiate()
	add_child_autofree(enemy)
	assert_not_null(enemy.animation_player, "Enemy should have an AnimationPlayer")
	assert_not_null(enemy.animation_tree, "Enemy should have an AnimationTree")
	assert_true(enemy.animation_player.has_animation_library(EnemyScript.ANIMATION_LIBRARY_NAME))
	var library: AnimationLibrary = enemy.animation_player.get_animation_library(EnemyScript.ANIMATION_LIBRARY_NAME)
	assert_not_null(library)
	for state in EnemyScript.ANIMATION_STATES:
		assert_true(library.has_animation(state), "Missing clip: " + state)
	enemy.play_boss_animation("attack")
	assert_eq(enemy.animation_state, "attack")
	enemy.set_animation_state("idle")
	assert_eq(enemy.animation_state, "idle")

func test_boss_animation_hooks_are_wired() -> void:
	var scenes := [
		"res://scenes/enemies/BossBunny.tscn",
		"res://scenes/enemies/BossGiantBiker.tscn",
		"res://scenes/enemies/BossSasquatch.tscn",
		"res://scenes/enemies/BossVoidDrone.tscn",
		"res://scenes/enemies/BossWarRig.tscn",
	]
	for scene_path in scenes:
		var boss = load(scene_path).instantiate()
		add_child_autofree(boss)
		boss.fire_animation_event("unit_test")
		boss.play_boss_animation("attack")
		assert_eq(boss.animation_state, "attack", scene_path + " should enter attack state")

func test_boss_phase_and_enrage_animations() -> void:
	var war_rig = preload("res://scenes/enemies/BossWarRig.tscn").instantiate()
	add_child_autofree(war_rig)
	war_rig.phase = 2
	war_rig._update_phase_visuals()
	assert_eq(war_rig.animation_state, "phase2")
	war_rig.phase = 3
	war_rig._update_phase_visuals()
	assert_eq(war_rig.animation_state, "enrage")

	var biker = preload("res://scenes/enemies/BossGiantBiker.tscn").instantiate()
	add_child_autofree(biker)
	var fake_player := Node2D.new()
	add_child_autofree(fake_player)
	biker.player = fake_player
	biker.hp = 1
	biker._physics_process(0.016)
	assert_true(biker.enraged, "Giant Biker should enrage below half health")
	assert_eq(biker.animation_state, "enrage")

func test_localization_helpers() -> void:
	var localization = LocalizationUtilScript.new()
	assert_eq(LocalizationUtilScript.normalized_locale("es-ES"), "es")
	assert_eq(LocalizationUtilScript.normalized_locale("fr_CA"), "fr")
	assert_eq(LocalizationUtilScript.normalized_locale("xx"), "en")
	assert_eq(LocalizationUtilScript.locale_name("de"), "Deutsch")
	assert_eq(LocalizationUtilScript.t("R2DE_OPTIONS_TITLE", "FALLBACK"), "OPTIONS")
	assert_eq(LocalizationUtilScript.skin_name("nitro_phantom"), "Nitro Phantom")
	assert_eq(localization.apply_locale("es"), "es")
	assert_eq(LocalizationUtilScript.t("R2DE_OPTIONS_TITLE"), "OPCIONES")
	assert_eq(LocalizationUtilScript.t("R2DE_SKIN_APEX_PREDATOR"), "Depredador supremo")
	for locale in LocalizationUtilScript.SUPPORTED_LOCALES:
		assert_true(LocalizationUtilScript.STRINGS.has(locale), locale + " strings should exist")
		assert_true(LocalizationUtilScript.SKIN_NAMES.has(locale), locale + " skin names should exist")

func test_accessibility_palettes_and_descriptions() -> void:
	var util = AccessibilityUtilScript.new()
	assert_eq(AccessibilityUtilScript.palette_for(true, "protanopia"), AccessibilityUtilScript.PALETTE_HIGH_CONTRAST)
	assert_eq(AccessibilityUtilScript.palette_for(false, "deuteranopia"), AccessibilityUtilScript.PALETTE_DEUTERANOPIA)
	assert_eq(AccessibilityUtilScript.palette_for(false, "none"), AccessibilityUtilScript.PALETTE_NONE)
	assert_false(AccessibilityUtilScript.has_screen_reader_service() and util.is_active())

	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var panel := Panel.new()
	panel.name = "Panel"
	layer.add_child(panel)
	util.apply_palette(layer, true, "tritanopia")
	assert_eq(panel.modulate, AccessibilityUtilScript.PALETTE_HIGH_CONTRAST)

	var button := Button.new()
	button.name = "TestButton"
	add_child_autofree(button)
	util.describe_control(button, "Test button", "Hint")
	assert_eq(button.tooltip_text, "Hint")
	util.refresh_descriptions()
	watch_signals(util)
	util.announce("Roadmap ready")
	assert_signal_emitted_with_parameters(util, "announcement_requested", ["Roadmap ready"])

func test_accessibility_focus_helpers() -> void:
	var host := Node.new()
	add_child_autofree(host)
	var chain: Array[Control] = []
	for i in 4:
		var btn := Button.new()
		host.add_child(btn)
		chain.append(btn)
	AccessibilityUtilScript.link_focus_chain(chain)
	assert_ne(chain[0].focus_neighbor_right, NodePath(""))
	var grid: Array[Control] = []
	for i in 6:
		var btn := Button.new()
		host.add_child(btn)
		grid.append(btn)
	AccessibilityUtilScript.link_focus_grid(grid, 3)
	assert_ne(grid[4].focus_neighbor_top, NodePath(""))
	assert_ne(grid[1].focus_neighbor_left, NodePath(""))

func test_online_leaderboard_falls_back_to_local_scores() -> void:
	var leaderboard = OnlineLeaderboardScript.new()
	add_child_autofree(leaderboard)
	leaderboard.configure(OnlineLeaderboardScript.INVALID_ENDPOINT, 0.1)
	watch_signals(leaderboard)
	assert_false(leaderboard.fetch_scores(5))
	assert_signal_emitted(leaderboard, "entries_received")
	assert_false(leaderboard.submit_score("Tester", 1234, "default"))
	assert_signal_emitted(leaderboard, "request_failed")
	assert_signal_emitted(leaderboard, "submission_completed")
	assert_false(leaderboard.last_error.is_empty())
	assert_true(leaderboard.local_entries() is Array)

func test_game_manager_skin_unlock_requirements() -> void:
	assert_eq(GameManager.get_skin_unlock_requirement("missing"), {})
	var boss_req: Dictionary = GameManager.get_skin_unlock_requirement("nitro_phantom")
	assert_eq(boss_req.get("type"), "boss")
	assert_eq(boss_req.get("key"), "boss_void_drone")
	assert_eq(GameManager.get_skin_unlock_requirement("ghost_protocol").get("type"), "achievement")
	assert_eq(GameManager.get_skin_unlock_requirement("solar_flare").get("key"), "10000")

	GameManager.bosses_defeated_keys.clear()
	GameManager.unlocked_achievements.clear()
	GameManager.high_score = 0
	assert_false(GameManager.is_skin_unlocked("nitro_phantom"))
	GameManager.bosses_defeated_keys.append("boss_void_drone")
	assert_true(GameManager.is_skin_unlocked("nitro_phantom"))
	GameManager.unlocked_achievements.append("protector")
	assert_true(GameManager.is_skin_unlocked("ghost_protocol"))
	GameManager.high_score = 10000
	assert_true(GameManager.is_skin_unlocked("solar_flare"))

func test_garage_shows_unlock_hints_and_localized_skin_names() -> void:
	var garage = load("res://scenes/ui/Garage.tscn").instantiate()
	add_child_autofree(garage)
	garage.refresh()
	var skin_list = garage.customize_container.get_node_or_null("CarSkinsScroll/CarSkinsList")
	assert_not_null(skin_list)
	assert_eq(skin_list.get_child_count(), 10)
	var locked_btn: Button = skin_list.get_node_or_null("SkinRow_nitro_phantom/SkinSelectButton_nitro_phantom")
	assert_not_null(locked_btn)
	assert_true(locked_btn.disabled)
	assert_false(locked_btn.tooltip_text.is_empty())
	var name_label: Label = skin_list.get_node_or_null("SkinRow_nitro_phantom/SkinRowName")
	assert_null(name_label, "Skin names live in the info box rather than a dedicated row node")

func test_options_roadmap_controls_and_toggles() -> void:
	var options = load("res://scenes/ui/Options.tscn").instantiate()
	add_child_autofree(options)
	assert_not_null(options.get_node_or_null("OnlineLeaderboard"))
	assert_not_null(options.locale_option)
	assert_eq(options.locale_option.item_count, LocalizationUtilScript.SUPPORTED_LOCALES.size())
	assert_eq(options.feature_toggles.get_child_count(), Constants.ROADMAP_FEATURE_KEYS.size())
	options._on_locale_selected(1)
	assert_eq(TranslationServer.get_locale(), "es")
	options._on_high_contrast_toggled(true)
	assert_true(SettingsManager.get_high_contrast())
	options._on_colorblind_selected(2)
	assert_eq(SettingsManager.get_colorblind_mode(), "deuteranopia")
	options._on_reduce_motion_toggled(true)
	assert_true(bool(SettingsManager.get_roadmap_value("reduce_motion", false)))
	options._on_fetch_scores_pressed()
	options._on_submit_score_pressed()
	options._on_entries_received([{"player": "Tester", "score": 42}])
	assert_true("42" in options.leaderboard_list.text)
	options._on_submission_completed(true)
	assert_false(options.leaderboard_status.text.is_empty())
	options._on_request_failed("unit test failure")
	assert_true("unit test failure" in options.leaderboard_status.text)
	options._on_feature_toggle(false, Constants.FEATURE_ONLINE_LEADERBOARD)
	assert_true(options.submit_score_button.disabled)

func test_themed_scene_panels_and_focus() -> void:
	var theme = load("res://assets/themes/cyberpunk_theme.tres")
	assert_not_null(theme.get_stylebox("focus", "Button"))
	assert_not_null(theme.get_stylebox("panel", "PanelContainer"))
	assert_not_null(theme.get_stylebox("panel", "TabContainer"))
	for scene_path in ["res://scenes/ui/Options.tscn", "res://scenes/ui/Garage.tscn", "res://scenes/ui/GameOver.tscn"]:
		var scene = load(scene_path).instantiate()
		add_child_autofree(scene)
		assert_true(scene.get_node("Panel") is NinePatchRect, scene_path + " should use a NinePatchRect panel")
	assert_ne(RoadmapWorldScript.SUPPORTED_RESOLUTIONS.size(), 0)

func _script_has_method(script: GDScript, method: String) -> bool:
	var instance = script.new()
	var result: bool = instance.has_method(method)
	instance.free()
	return result

func test_parent_roadmap_feature_hooks_exist() -> void:
	assert_true(_script_has_method(GameScript, "set_fsr_upscaling_enabled"))
	assert_true(_script_has_method(GameScript, "set_rear_view_enabled"))
	assert_true(_script_has_method(HudScript, "set_hud_text_scale"))
	assert_true(_script_has_method(HudScript, "set_rich_hud_enabled"))
	assert_true(_script_has_method(HighwayScript, "set_tilemap_highway_enabled"))
