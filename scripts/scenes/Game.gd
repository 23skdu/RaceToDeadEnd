extends Node

const RoadmapWorld = preload("res://scripts/utils/RoadmapWorld.gd")

const BULLET_SCENE = preload("res://scenes/weapons/Bullet.tscn")
const MINE_SCENE = preload("res://scenes/weapons/Mine.tscn")
const EMP_SCENE = preload("res://scenes/weapons/EMPBlast.tscn")
const BUNNY_SCENE = preload("res://scenes/enemies/Bunny.tscn")
const ROTOR_SCENE = preload("res://scenes/enemies/Rotor.tscn")
const SCAV_SCENE = preload("res://scenes/enemies/Scav.tscn")
const DRONE_SCENE = preload("res://scenes/enemies/Drone.tscn")
const DRONE_BOMB_SCENE = preload("res://scenes/weapons/DroneBomb.tscn")
const BOSS_SCENE = preload("res://scenes/enemies/BossWarRig.tscn")
const BOSS_BUNNY_SCENE = preload("res://scenes/enemies/BossBunny.tscn")
const BABY_BUNNY_BOMB_SCENE = preload("res://scenes/weapons/BabyBunnyBomb.tscn")
const BOSS_GIANT_BIKER_SCENE = preload("res://scenes/enemies/BossGiantBiker.tscn")
const SASQUATCH_SCENE = preload("res://scenes/enemies/BossSasquatch.tscn")
const CHAIN_SWING_SCENE = preload("res://scenes/weapons/ChainSwing.tscn")
const POOP_WEAPON_SCENE = preload("res://scenes/weapons/PoopWeapon.tscn")
const BOSS_VOID_DRONE_SCENE = preload("res://scenes/enemies/BossVoidDrone.tscn")
const CIVILIAN_SCENE = preload("res://scenes/enemies/Civilian.tscn")

const DEMO_BUNNY_SCENE = preload("res://demo/DemoBossBunny.tscn")
const DEMO_GIANT_BIKER_SCENE = preload("res://demo/DemoBossGiantBiker.tscn")
const DEMO_VOID_SCENE = preload("res://demo/DemoBossVoidDrone.tscn")
const DEMO_WAR_SCENE = preload("res://demo/DemoBossWarRig.tscn")

const POPUP_POOL_SIZE: int = 10

@onready var world: Node2D = $World
@onready var highway: Node2D = $World/Highway
@onready var spawner: Node = $World/Spawner
@onready var player: CharacterBody2D = $World/Player
@onready var weather: Node2D = $World/WeatherSystem
@onready var hud: CanvasLayer = $UI/HUD
@onready var game_over: CanvasLayer = $UI/GameOver
@onready var score_popup_container: Node2D = $ScorePopups

func _ready() -> void:
	_apply_saved_resolution()
	_setup_parallax()
	world.scale = Constants.WORLD_SCALE
	world.set_y_sort_enabled(true)

	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

	var env_res = load("res://assets/environments/game_env.tres")
	if env_res:
		if env_res is Environment and SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_HDR, true):
			var env: Environment = env_res as Environment
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env_res = env
		var we = WorldEnvironment.new()
		we.environment = env_res
		var cam_attrs = CameraAttributesPhysical.new()
		cam_attrs.exposure_multiplier = 1.1
		cam_attrs.auto_exposure_enabled = true
		cam_attrs.auto_exposure_min_exposure_value = -2.0
		cam_attrs.auto_exposure_max_exposure_value = 2.0
		we.camera_attributes = cam_attrs
		add_child(we)
		move_child(we, get_child_count() - 1)
		_world_environment = we

	# CanvasModulate for per-weather color grading
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "WeatherColorGrading"
	_canvas_modulate.color = Color.WHITE
	add_child(_canvas_modulate)

	_setup_roadmap_overlays()
	_on_viewport_size_changed()

	ObjectPool.create_pool("bullet", BULLET_SCENE, 50)
	ObjectPool.create_pool("mine", MINE_SCENE, 10)
	ObjectPool.create_pool("emp", EMP_SCENE, 5)
	ObjectPool.create_pool("bunny", BUNNY_SCENE, 8)
	ObjectPool.create_pool("rotor", ROTOR_SCENE, 8)
	ObjectPool.create_pool("scav", SCAV_SCENE, 6)
	ObjectPool.create_pool("drone", DRONE_SCENE, 4)
	ObjectPool.create_pool("drone_bomb", DRONE_BOMB_SCENE, 6)
	ObjectPool.create_pool("boss", BOSS_SCENE, 2)
	ObjectPool.create_pool("boss_bunny", BOSS_BUNNY_SCENE, 2)
	ObjectPool.create_pool("baby_bunny_bomb", BABY_BUNNY_BOMB_SCENE, 10)
	ObjectPool.create_pool("boss_giant_biker", BOSS_GIANT_BIKER_SCENE, 2)
	ObjectPool.create_pool("sasquatch", SASQUATCH_SCENE, 3)
	ObjectPool.create_pool("chain_swing", CHAIN_SWING_SCENE, 4)
	ObjectPool.create_pool("poop_weapon", POOP_WEAPON_SCENE, 10)
	ObjectPool.create_pool("boss_void_drone", BOSS_VOID_DRONE_SCENE, 2)
	ObjectPool.create_pool("civilian", CIVILIAN_SCENE, 4)
	ObjectPool.create_pickup_pool(20)

	GameManager.start_game()
	AudioManager.play_game_music()

	spawner.player = player
	spawner.world_node = world
	spawner.enemy_spawned.connect(GameManager.register_enemy_spawned)
	spawner.enemy_destroyed.connect(GameManager.register_enemy_destroyed)
	if spawner.has_signal("enemy_destroyed") and not spawner.enemy_destroyed.is_connected(_on_enemy_destroyed_flash):
		spawner.enemy_destroyed.connect(_on_enemy_destroyed_flash)
	if spawner.has_signal("boss_spawned") and not spawner.boss_spawned.is_connected(_on_boss_spawned_flash):
		spawner.boss_spawned.connect(_on_boss_spawned_flash)
	if hud and hud.has_method("bind_boss") and spawner.has_signal("boss_spawned"):
		spawner.boss_spawned.connect(hud.bind_boss)
	if spawner.has_signal("boss_defeated"):
		spawner.boss_defeated.connect(_on_boss_defeated)
		if hud and hud.has_method("unbind_boss"):
			spawner.boss_defeated.connect(func(_bt): hud.unbind_boss())
	highway.player = player
	if hud and hud.has_method("set_player"):
		hud.set_player(player)

	if weather:
		weather.set_player(player)
		weather.set_highway(highway)
		weather.set_weather(weather.WeatherType.CLEAR)

	_minimap_container = get_node_or_null("MinimapContainer")
	_minimap_camera = get_node_or_null("MinimapContainer/MinimapViewport/MinimapCamera")
	if is_instance_valid(_minimap_camera) and is_instance_valid(player):
		_minimap_camera.position = player.global_position
	_rear_view_container = get_node_or_null("RearViewContainer")
	_rear_view_camera = get_node_or_null("RearViewContainer/RearViewViewport/RearViewCamera")
	if is_instance_valid(_rear_view_camera) and is_instance_valid(player):
		_rear_view_camera.position = player.global_position

	wire_secondary_viewports()
	configure_camera_smoothing()
	rear_view_enabled = SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_REAR_VIEW, true)
	_apply_rear_view_visibility()

	if player:
		player.weapon_fired.connect(_on_player_weapon_fired)
		player.weapon_switched.connect(func(idx): hud.update_weapons(idx, player.secondary_ammo))
		player.boost_charge_updated.connect(hud.update_boost_charges)
		player.boost_activated.connect(func(): hud.set_boost_active(true))
		player.boost_depleted.connect(func(): hud.set_boost_active(false))
		player.damage_taken.connect(func(amount): _show_floating_text(player.global_position, "-" + str(amount), Color.RED, 18))

		highway.ice_entered.connect(player.set_slippery.bind(true))
		highway.ice_exited.connect(player.set_slippery.bind(false))
		highway.bridge_fall.connect(player.on_bridge_fall)

		# Initial UI sync
		hud.update_weapons(player.current_weapon, player.secondary_ammo)
		hud.update_boost_charges(player.boost_charges)

	if game_over and game_over.has_signal("restart_requested"):
		game_over.restart_requested.connect(_restart_game)
	if game_over and game_over.has_signal("menu_requested"):
		game_over.menu_requested.connect(_go_to_menu)
	if game_over and game_over.has_signal("garage_requested"):
		game_over.garage_requested.connect(_go_to_garage)

	if hud and not GameManager.game_over.is_connected(hud._on_game_over):
		GameManager.game_over.connect(hud._on_game_over)

	ScoreManager.score_popped.connect(_on_score_popped)

	highway.segment_completed.connect(_on_segment_completed)

func _on_segment_completed(_segment: int) -> void:
	if not weather:
		return
	_update_color_grading()
	var tier = GameManager.difficulty_tier
	if tier >= 5 and tier < 8:
		weather.set_weather(weather.WeatherType.LIGHT_RAIN)
	elif tier >= 8 and tier < 12:
		weather.set_weather(weather.WeatherType.ACID_RAIN)
	elif tier >= 12:
		weather.set_weather(weather.WeatherType.STORM)

func _setup_parallax() -> void:
	_parallax = ParallaxBackground.new()
	_parallax.name = "ParallaxBackground"
	_parallax.scroll_offset = Vector2.ZERO
	add_child(_parallax)
	move_child(_parallax, 0)

	var vs = DisplayServer.window_get_size()
	if vs.x <= 0:
		vs = Vector2i(1280, 720)

	var layers = [
		{ "scale": Vector2(0.02, 0.0), "color_top": Color(0.02, 0.01, 0.05), "color_bot": Color(0.06, 0.04, 0.12), "label": "deep", "height": 1.5 },
		{ "scale": Vector2(0.05, 0.0), "color_top": Color(0.05, 0.03, 0.10), "color_bot": Color(0.10, 0.07, 0.18), "label": "far", "height": 1.2 },
		{ "scale": Vector2(0.1, 0.0), "color_top": Color(0.10, 0.06, 0.18), "color_bot": Color(0.25, 0.18, 0.30), "label": "mid", "height": 1.0 },
		{ "scale": Vector2(0.3, 0.0), "color_top": Color(0.18, 0.12, 0.28), "color_bot": Color(0.40, 0.30, 0.42), "label": "near", "height": 0.7 },
	]

	var textures: Array[Texture2D] = []
	if _parallax_texture_cache.is_empty():
		var rng = RandomNumberGenerator.new()
		rng.seed = 12345

		for li in layers.size():
			var l = layers[li]
			var tex_height = int(256.0 * l.height)
			var img_width = 512
			var img = Image.create(img_width, tex_height, false, Image.FORMAT_RGBA8)

			# Base gradient fill via horizontal scanline fill_rect (much faster than per-pixel set_pixel)
			for y in tex_height:
				var t = float(y) / float(tex_height - 1)
				var c = l.color_top.lerp(l.color_bot, t)
				img.fill_rect(Rect2i(0, y, img_width, 1), c)

			if l.label == "deep":
				# 1. Glowing Synthwave Sun in center
				var cx = 256.0
				var cy = float(tex_height) - 100.0
				var r = 70.0

				# Draw Glow Aura
				for x in img_width:
					for y in tex_height:
						var dx = x - cx
						var dy = y - cy
						var dist = sqrt(dx*dx + dy*dy)
						if dist <= r + 24.0:
							var t = (dist - r) / 24.0
							if dist <= r:
								t = 0.0
							var alpha = clampf((1.0 - t) * 0.45, 0.0, 1.0)
							var current_c = img.get_pixel(x, y)
							var glow_c = Color(1.0, 0.05, 0.65).lerp(current_c, t)
							img.set_pixel(x, y, current_c.lerp(glow_c, alpha))

				# Draw Sun Body with Scanline Cutouts
				for x in img_width:
					for y in tex_height:
						var dx = x - cx
						var dy = y - cy
						var dist = sqrt(dx*dx + dy*dy)
						if dist <= r:
							# Scanline cutout calculations (lines get thicker at bottom)
							var relative_y = y - (cy - r)
							var step_t = relative_y / (r * 2.0)
							var scanline_thickness = lerpf(0.5, 6.5, step_t)
							if y > cy - 10.0 and fmod(y, 14.0) < scanline_thickness:
								continue # Skip drawing to leave transparent gap

							var t_color = float(y - (cy - r)) / (r * 2.0)
							var sun_col = Color(1.0, 0.0, 0.55).lerp(Color(1.0, 0.75, 0.0), t_color)
							img.set_pixel(x, y, sun_col)

				# 2. Sprinkle Glowing Stars in upper sky
				for j in range(75):
					var sx = rng.randi() % img_width
					var sy = rng.randi() % int(cy - 60.0)
					if sy < tex_height and sx < img_width:
						var intensity = rng.randf_range(0.5, 1.0)
						var star_color = Color(0.85, 0.9, 1.0, intensity)
						img.set_pixel(sx, sy, star_color)
						# Add small cross glow for bright stars
						if intensity > 0.85:
							if sx > 0: img.set_pixel(sx - 1, sy, Color(0.85, 0.9, 1.0, intensity * 0.4))
							if sx < img_width - 1: img.set_pixel(sx + 1, sy, Color(0.85, 0.9, 1.0, intensity * 0.4))
							if sy > 0: img.set_pixel(sx, sy - 1, Color(0.85, 0.9, 1.0, intensity * 0.4))
							if sy < tex_height - 1: img.set_pixel(sx, sy + 1, Color(0.85, 0.9, 1.0, intensity * 0.4))

			elif l.label == "far":
				# Distant Mountain Range Silhouette with Neon Outline
				for x in img_width:
					# Complex wave form for organic mountain peaks
					var my = float(tex_height) - 100.0 + sin(x * 0.035) * 25.0 + sin(x * 0.09) * 8.0 + cos(x * 0.015) * 15.0
					var m_height = int(my)
					for y in range(m_height, tex_height):
						if y >= 0 and y < tex_height:
							if y < m_height + 2:
								# Neon Cyan Border
								img.set_pixel(x, y, Color(0.0, 0.9, 1.0, 0.9))
							else:
								# Dark Purple-Gray Mountain Silhouette
								var t = float(y - m_height) / float(tex_height - m_height)
								var col = Color(0.05, 0.04, 0.12).lerp(Color(0.09, 0.07, 0.18), t)
								img.set_pixel(x, y, col)

			elif l.label == "mid":
				# Cyberpunk City Skyline Silhouette with glowing windows & neon roofs
				var bh = 0
				var bw = 0
				var has_windows = false
				var win_color = Color.YELLOW
				for x in img_width:
					if bw <= 0:
						bw = rng.randi_range(16, 32)
						bh = int(float(tex_height) - rng.randf_range(60.0, 160.0))
						has_windows = rng.randf() < 0.65
						win_color = Color(1.0, 0.85, 0.15) if rng.randf() < 0.7 else Color(0.2, 0.95, 1.0)

					for y in range(bh, tex_height):
						if y >= 0 and y < tex_height:
							if y < bh + 2:
								# Neon Pink Glowing Roof edge
								img.set_pixel(x, y, Color(1.0, 0.1, 0.55))
							elif has_windows and x % 6 == 3 and y % 12 == 5 and y > bh + 15 and y < tex_height - 20 and hash(x * 17 + y * 31) % 10 < 3:
								# Glowing window pixel
								img.set_pixel(x, y, win_color)
							else:
								# Dark violet building silhouette
								var t = float(y - bh) / float(tex_height - bh)
								var col = Color(0.1, 0.06, 0.20).lerp(Color(0.2, 0.14, 0.28), t)
								img.set_pixel(x, y, col)
					bw -= 1

			elif l.label == "near":
				# Repeating Closer Highway Trusses & structural grid lines
				for x in img_width:
					for y in tex_height:
						# Draw structural beam outline silhouette
						if fmod(float(x + y), 96.0) < 3.0 or fmod(float(x - y), 96.0) < 3.0:
							if y > float(tex_height) * 0.4:
								var current_c = img.get_pixel(x, y)
								img.set_pixel(x, y, current_c.lerp(Color(0.22, 0.15, 0.32), 0.7))

			_parallax_texture_cache.append(ImageTexture.create_from_image(img))
	textures = _parallax_texture_cache

	for i in textures.size():
		var l = layers[i]
		var layer = ParallaxLayer.new()
		layer.name = "Layer" + l.label.capitalize()
		layer.motion_scale = l.scale
		# Enable seamless horizontal repeating
		layer.motion_mirroring = Vector2(vs.x, 0)

		var sprite = Sprite2D.new()
		sprite.texture = textures[i]
		sprite.centered = false
		sprite.scale = Vector2(float(vs.x) / 512.0, float(vs.y) * l.height / float(textures[i].get_height()))
		sprite.position = Vector2(0, -float(vs.y) * l.height)

		layer.add_child(sprite)
		_parallax.add_child(layer)

# --- Roadmap item 7: resolution, letterboxing and upscaling --------------------

func _apply_saved_resolution() -> void:
	var saved: Variant = SettingsManager.get_roadmap_value(RoadmapWorld.KEY_RESOLUTION, "")
	if saved == null or (saved is String and (saved as String).is_empty()):
		return
	apply_resolution(RoadmapWorld.sanitize_resolution(saved))

## Persist and (on desktop) apply a resolution, clamped to 3840x2160.
func apply_resolution(resolution: Vector2i) -> void:
	active_resolution = RoadmapWorld.sanitize_resolution(resolution)
	SettingsManager.set_roadmap_value(RoadmapWorld.KEY_RESOLUTION, RoadmapWorld.resolution_to_string(active_resolution))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(active_resolution)

func _setup_roadmap_overlays() -> void:
	_letterbox_layer = get_node_or_null("RoadmapLetterbox") as CanvasLayer
	if not is_instance_valid(_letterbox_layer):
		_letterbox_layer = CanvasLayer.new()
		_letterbox_layer.name = "RoadmapLetterbox"
		_letterbox_layer.layer = 100
		add_child(_letterbox_layer)
	for i in 4:
		var bar := ColorRect.new()
		bar.name = "LetterboxBar%d" % i
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_letterbox_layer.add_child(bar)
		_letterbox_bars.append(bar)
	_effect_layer = get_node_or_null("RoadmapWorldFx") as CanvasLayer
	if not is_instance_valid(_effect_layer):
		_effect_layer = CanvasLayer.new()
		_effect_layer.name = "RoadmapWorldFx"
		_effect_layer.layer = 1
		add_child(_effect_layer)
	_fsr_overlay = get_node_or_null("RoadmapWorldFx/FsrUpscaler") as ColorRect
	if not is_instance_valid(_fsr_overlay):
		_fsr_overlay = ColorRect.new()
		_fsr_overlay.name = "FsrUpscaler"
		_effect_layer.add_child(_fsr_overlay)
	_fsr_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fsr_overlay.visible = false
	_ssao_overlay = get_node_or_null("RoadmapWorldFx/SsaoApproximation") as ColorRect
	if not is_instance_valid(_ssao_overlay):
		_ssao_overlay = ColorRect.new()
		_ssao_overlay.name = "SsaoApproximation"
		_effect_layer.add_child(_ssao_overlay)
	_ssao_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ssao_overlay.visible = false
	_grade_overlay = get_node_or_null("RoadmapWorldFx/WeatherLutGrade") as ColorRect
	if not is_instance_valid(_grade_overlay):
		_grade_overlay = ColorRect.new()
		_grade_overlay.name = "WeatherLutGrade"
		_effect_layer.add_child(_grade_overlay)
	_grade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_overlay.visible = false
	_apply_fsr_toggle()
	_apply_ssao_toggle()

## Enable/disable the FSR-style sharpening pass on the world output.
func set_fsr_upscaling_enabled(enabled: bool) -> void:
	SettingsManager.set_feature_enabled(RoadmapWorld.FEATURE_FSR_UPSCALING, enabled)
	_apply_fsr_toggle()

func _apply_fsr_toggle() -> void:
	if not is_instance_valid(_fsr_overlay):
		return
	var enabled := SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_FSR_UPSCALING, false)
	_fsr_overlay.visible = enabled
	if enabled:
		_fsr_overlay.material = RoadmapWorld.make_fsr_material()

## Enable/disable the lightweight 2D ambient-occlusion approximation.
func set_ssao_enabled(enabled: bool) -> void:
	SettingsManager.set_feature_enabled(RoadmapWorld.FEATURE_SSAO, enabled)
	_apply_ssao_toggle()

func _apply_ssao_toggle() -> void:
	if not is_instance_valid(_ssao_overlay):
		return
	var enabled := SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_SSAO, false)
	_ssao_overlay.visible = enabled
	if enabled:
		_ssao_overlay.material = RoadmapWorld.make_ssao_material()

## Recompute pillarbox/letterbox bars for the current viewport.
func apply_letterbox_for_size(viewport_size: Vector2) -> Rect2:
	var aspect := RoadmapWorld.aspect_ratio(active_resolution.x, active_resolution.y)
	match RoadmapWorld.aspect_category(aspect):
		"super_ultrawide":
			aspect = RoadmapWorld.SUPER_ULTRAWIDE_ASPECT
		"ultrawide":
			aspect = RoadmapWorld.ULTRAWIDE_ASPECT
		_:
			aspect = RoadmapWorld.CONTENT_ASPECT_16_9
	current_content_rect = RoadmapWorld.letterbox_rect(viewport_size, aspect)
	_apply_letterbox_bars(viewport_size)
	return current_content_rect

func _apply_letterbox_bars(viewport_size: Vector2) -> void:
	if _letterbox_bars.size() < 4:
		return
	var left := _letterbox_bars[0]
	var right := _letterbox_bars[1]
	var top := _letterbox_bars[2]
	var bottom := _letterbox_bars[3]
	for bar in _letterbox_bars:
		bar.position = Vector2.ZERO
		bar.size = Vector2.ZERO
	if current_content_rect.size.x <= 0.0 or viewport_size.x <= 0.0:
		return
	var x0 := current_content_rect.position.x
	var y0 := current_content_rect.position.y
	var x1 := current_content_rect.end.x
	var y1 := current_content_rect.end.y
	left.size = Vector2(x0, viewport_size.y)
	right.position = Vector2(x1, 0.0)
	right.size = Vector2(maxf(0.0, viewport_size.x - x1), viewport_size.y)
	top.size = Vector2(viewport_size.x, y0)
	bottom.position = Vector2(0.0, y1)
	bottom.size = Vector2(viewport_size.x, maxf(0.0, viewport_size.y - y1))
	for overlay in [_fsr_overlay, _ssao_overlay, _grade_overlay]:
		if is_instance_valid(overlay):
			overlay.position = Vector2.ZERO
			overlay.size = viewport_size

# --- Roadmap item 10: secondary viewports -------------------------------------

## Share the main World2D with the minimap/rear-view SubViewports.
func wire_secondary_viewports() -> void:
	var shared_world: World2D = null
	if is_instance_valid(world):
		shared_world = world.get_world_2d()
	_minimap_viewport = get_node_or_null("MinimapContainer/MinimapViewport") as SubViewport
	_rear_view_viewport = get_node_or_null("RearViewContainer/RearViewViewport") as SubViewport
	if is_instance_valid(shared_world):
		if is_instance_valid(_minimap_viewport):
			_minimap_viewport.world_2d = shared_world
			_set_cull_mask(_minimap_viewport, 3)
		if is_instance_valid(_rear_view_viewport):
			_rear_view_viewport.world_2d = shared_world
			_set_cull_mask(_rear_view_viewport, 5)
	_configure_secondary_camera(_minimap_camera, 3)
	_configure_secondary_camera(_rear_view_camera, 5)
	_apply_rear_view_visibility()

func _has_property(obj: Object, property: String) -> bool:
	if not is_instance_valid(obj):
		return false
	for prop in obj.get_property_list():
		if str(prop.get("name", "")) == property:
			return true
	return false

func _set_cull_mask(viewport: SubViewport, mask: int) -> void:
	if _has_property(viewport, "canvas_cull_mask"):
		viewport.set("canvas_cull_mask", mask)

func _configure_secondary_camera(camera: Camera2D, mask: int) -> void:
	if not is_instance_valid(camera):
		return
	for property in ["visibility_layer", "layers", "cull_mask", "canvas_cull_mask"]:
		if _has_property(camera, property):
			camera.set(property, mask)
			break

## Toggle the rear-view SubViewportContainer and persist the setting.
func set_rear_view_enabled(enabled: bool) -> void:
	rear_view_enabled = enabled
	SettingsManager.set_feature_enabled(RoadmapWorld.FEATURE_REAR_VIEW, enabled)
	_apply_rear_view_visibility()

func _apply_rear_view_visibility() -> void:
	if is_instance_valid(_rear_view_container):
		_rear_view_container.visible = rear_view_enabled
	if is_instance_valid(_rear_view_camera) and _has_property(_rear_view_camera, "enabled"):
		_rear_view_camera.set("enabled", rear_view_enabled)

# --- Roadmap items 2, 3 and 4: camera, lighting and adaptive music --------------

## Enable position smoothing on the player camera (roadmap item 3).
func configure_camera_smoothing() -> void:
	if not SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_MOTION_INTERPOLATION, true):
		return
	var camera: Camera2D = null
	if is_instance_valid(player):
		camera = player.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(camera) and _has_property(camera, "position_smoothing_enabled"):
		camera.set("position_smoothing_enabled", true)
		if _has_property(camera, "position_smoothing_speed"):
			camera.set("position_smoothing_speed", 12.0)

## [boss_active, difficulty_tier, enemy_density] for adaptive music.
func compute_music_intensity() -> Array:
	var tier := clampi(int(GameManager.difficulty_tier), 0, maxi(1, int(Constants.MAX_TIER)))
	var enemy_count := GameManager.enemy_list.size() if GameManager.enemy_list != null else 0
	return [GameManager.boss_active, tier, RoadmapWorld.enemy_density(enemy_count, 12)]

func _update_music_intensity() -> void:
	if not AudioManager.has_method("set_music_intensity"):
		return
	var values := compute_music_intensity()
	AudioManager.set_music_intensity(bool(values[0]), int(values[1]), float(values[2]))

func _on_boss_spawned_flash(boss: Node) -> void:
	if not is_instance_valid(boss) or not SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_LIGHTING, true):
		return
	if boss.get_node_or_null("BossReactorLight") != null:
		return
	var light := RoadmapWorld.make_reactor_light()
	boss.add_child(light)

func _on_enemy_destroyed_flash(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	spawn_explosion_flash(enemy.global_position, Color(1.0, 0.45, 0.1, 1.0))

## Pooled-style explosion flash light attached to the world.
func spawn_explosion_flash(pos: Vector2, color: Color) -> PointLight2D:
	var light := RoadmapWorld.make_flash_light(color)
	light.position = pos
	world.add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "energy", 0.0, 0.45)
	tween.tween_callback(light.queue_free)
	return light

func _apply_weather_lut() -> void:
	if not is_instance_valid(_grade_overlay):
		return
	if not SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_WEATHER_LUT, true):
		_grade_overlay.visible = false
		return
	var weather_type := int(weather.current_weather) if weather else 0
	_weather_lut = RoadmapWorld.make_weather_lut(RoadmapWorld.weather_name(weather_type))
	_grade_overlay.material = RoadmapWorld.make_lut_material(_weather_lut)
	_grade_overlay.visible = true

# --- Roadmap item 12: pooled BBCode combat text --------------------------------

func bbcode_for_damage(text: String, amount: int) -> String:
	return RoadmapWorld.damage_bbcode(text, amount)

func _get_rich_popup_label() -> RichTextLabel:
	while _rich_popup_pool.size() > 0:
		var pop: RichTextLabel = _rich_popup_pool.pop_back()
		if is_instance_valid(pop):
			return pop
	var fresh := RichTextLabel.new()
	fresh.bbcode_enabled = true
	fresh.fit_content = true
	fresh.scroll_active = false
	fresh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fresh

func _return_rich_popup_label(pop: RichTextLabel) -> void:
	if not is_instance_valid(pop):
		return
	if _rich_popup_pool.size() >= POPUP_POOL_SIZE:
		if pop.get_parent():
			pop.get_parent().remove_child(pop)
		pop.queue_free()
		return
	pop.text = ""
	pop.position = Vector2.ZERO
	pop.modulate = Color.WHITE
	pop.visible = false
	if is_instance_valid(score_popup_container) and pop.get_parent() != score_popup_container:
		if pop.get_parent():
			pop.get_parent().remove_child(pop)
		score_popup_container.add_child(pop)
	if not _rich_popup_pool.has(pop):
		_rich_popup_pool.append(pop)

func _show_rich_floating_text(pos: Vector2, text: String, color: Color, size: int) -> void:
	var popup := _get_rich_popup_label()
	var amount := int(round(float(size) / 8.0))
	popup.text = bbcode_for_damage(text, amount)
	popup.modulate = color
	popup.position = pos
	popup.visible = true
	if popup.get_parent() != score_popup_container:
		if popup.get_parent():
			popup.get_parent().remove_child(popup)
		score_popup_container.add_child(popup)
	var tween := create_tween()
	tween.tween_property(popup, "position:y", pos.y - 40.0, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_return_rich_popup_label.bind(popup))

func _restart_game() -> void:
	TransitionLayer.reload_scene()

func _go_to_menu() -> void:
	TransitionLayer.change_scene("res://scenes/Main.tscn")

func _go_to_garage() -> void:
	var garage = preload("res://scenes/ui/Garage.tscn").instantiate()
	add_child(garage)
	garage.back_to_menu_requested.connect(func():
		garage.queue_free()
		_go_to_menu()
	)
	garage.start_run_requested.connect(func():
		garage.queue_free()
		_restart_game()
	)
static var _parallax_texture_cache: Array[Texture2D] = []

var _parallax: ParallaxBackground = null
var _pause_menu: CanvasLayer = null
var _options_menu: CanvasLayer = null
var _game_over_restart_timer: float = 0.0
var _canvas_modulate: CanvasModulate = null
var _minimap_camera: Camera2D = null
var _minimap_container: SubViewportContainer = null
var _rear_view_camera: Camera2D = null
var _rear_view_container: SubViewportContainer = null

var rear_view_enabled: bool = true
var active_resolution: Vector2i = RoadmapWorld.DEFAULT_RESOLUTION
var current_content_rect: Rect2 = Rect2()
var _minimap_viewport: SubViewport = null
var _rear_view_viewport: SubViewport = null
var _world_environment: WorldEnvironment = null
var _letterbox_layer: CanvasLayer = null
var _letterbox_bars: Array[ColorRect] = []
var _effect_layer: CanvasLayer = null
var _fsr_overlay: ColorRect = null
var _ssao_overlay: ColorRect = null
var _grade_overlay: ColorRect = null
var _weather_lut: Texture2D = null
var _rich_popup_pool: Array[RichTextLabel] = []

func _process(delta: float) -> void:
	_sync_minimap()
	_sync_rear_view()
	_update_music_intensity()
	if GameManager.state == GameManager.GameState.GAME_OVER:
		_game_over_restart_timer += delta
		if _game_over_restart_timer >= 1.5 and Input.is_action_just_pressed("ui_accept"):
			_restart_game()
	elif GameManager.state == GameManager.GameState.PLAYING:
		if Input.is_action_just_pressed("pause"):
			_show_pause_menu()

func _show_pause_menu() -> void:
	if _pause_menu:
		return
	GameManager.state = GameManager.GameState.PAUSED
	get_tree().paused = true
	_pause_menu = preload("res://scenes/ui/PauseMenu.tscn").instantiate()
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_hide_pause_menu)
	_pause_menu.options_requested.connect(_show_pause_options)
	_pause_menu.quit_requested.connect(_on_pause_quit)

func _hide_pause_menu() -> void:
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null
	GameManager.state = GameManager.GameState.PLAYING
	get_tree().paused = false

func _show_pause_options() -> void:
	_hide_pause_menu()
	get_tree().paused = true
	_options_menu = preload("res://scenes/ui/Options.tscn").instantiate()
	add_child(_options_menu)
	_options_menu.back_to_menu_requested.connect(func():
		if _options_menu:
			_options_menu.queue_free()
			_options_menu = null
		_show_pause_menu()
	)

func _on_pause_quit() -> void:
	_hide_pause_menu()
	get_tree().paused = false
	_go_to_menu()

func _on_player_weapon_fired(type: String, pos: Vector2, dir: Vector2) -> void:
	match type:
		"machine_gun":
			var bullet = ObjectPool.acquire("bullet")
			world.add_child(bullet)
			bullet.init(pos, dir, true)
			bullet.hit_target.connect(_on_bullet_hit)
			AudioManager.play_synth_laser(pos)
		"missile":
			var bullet = ObjectPool.acquire("bullet")
			world.add_child(bullet)
			bullet.init(pos, dir, true)
			bullet.homing_strength = 6.0
			bullet.damage = 3
			bullet.scale = Vector2(1.8, 1.8)
			bullet.modulate = Color(1.0, 0.25, 0.25)
			bullet.hit_target.connect(_on_bullet_hit)
			hud.update_weapons(player.current_weapon, player.secondary_ammo)
			AudioManager.play_synth_laser(pos)
		"mine":
			var mine = ObjectPool.acquire("mine")
			world.add_child(mine)
			mine.init(pos)
			hud.update_weapons(player.current_weapon, player.secondary_ammo)
			AudioManager.play_synth_explosion(pos)
		"emp":
			var emp = ObjectPool.acquire("emp")
			world.add_child(emp)
			emp.init(pos)
			hud.update_weapons(player.current_weapon, player.secondary_ammo)
			AudioManager.play_synth_emp(pos)

func _on_bullet_hit(body: Node) -> void:
	if is_instance_valid(body):
		var color = Color.YELLOW
		var size = 18
		var text = "HIT"
		if body.has_method("take_damage"):
			var dmg = 1
			if body.has_method("get_damage"):
				dmg = body.get_damage()
			text = str(dmg)
			if dmg >= 3:
				color = Color.WHITE
				size = 24
				_show_floating_text(body.global_position, "CRIT!", Color(1.0, 0.5, 0.0), 24)
		_show_floating_text(body.global_position, text, color, size)

var _popup_pool: Array[Label] = []

func _get_popup_label() -> Label:
	while _popup_pool.size() > 0:
		var pop = _popup_pool.pop_back()
		if is_instance_valid(pop):
			return pop
	return Label.new()

func _return_popup_label(pop: Label) -> void:
	if not is_instance_valid(pop):
		return
	if _popup_pool.size() >= POPUP_POOL_SIZE:
		if pop.get_parent():
			pop.get_parent().remove_child(pop)
		pop.queue_free()
		return
	pop.text = ""
	pop.position = Vector2.ZERO
	pop.modulate = Color.WHITE
	pop.visible = false
	if is_instance_valid(score_popup_container) and pop.get_parent() != score_popup_container:
		if pop.get_parent():
			pop.get_parent().remove_child(pop)
		score_popup_container.add_child(pop)
	if not _popup_pool.has(pop):
		_popup_pool.append(pop)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for pop in _popup_pool:
			if is_instance_valid(pop) and pop.get_parent() == null:
				pop.free()
		_popup_pool.clear()
		for pop in _rich_popup_pool:
			if is_instance_valid(pop) and pop.get_parent() == null:
				pop.free()
		_rich_popup_pool.clear()

func _show_floating_text(pos: Vector2, text: String, color: Color, size: int = 18) -> void:
	if SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_RICH_HUD, true):
		_show_rich_floating_text(pos, text, color, size)
		return
	var popup = _get_popup_label()
	popup.text = text
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_font_size_override("font_size", size)
	popup.position = pos
	popup.visible = true
	if popup.get_parent() != score_popup_container:
		if popup.get_parent():
			popup.get_parent().remove_child(popup)
		score_popup_container.add_child(popup)
	var tween = create_tween()
	tween.tween_property(popup, "position:y", pos.y - 40.0, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_return_popup_label.bind(popup))

func _on_score_popped(pos: Vector2, _points: int, label: String) -> void:
	var popup = _get_popup_label()
	popup.text = label
	popup.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	popup.add_theme_font_size_override("font_size", 18)
	popup.position = pos
	popup.visible = true
	if popup.get_parent() != score_popup_container:
		if popup.get_parent():
			popup.get_parent().remove_child(popup)
		score_popup_container.add_child(popup)
	var tween = create_tween()
	tween.tween_property(popup, "position:y", pos.y - 60.0, 0.8)
	tween.tween_property(popup, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_return_popup_label.bind(popup))

func _update_color_grading() -> void:
	if not is_instance_valid(_canvas_modulate):
		return
	var tier := GameManager.difficulty_tier
	var weather_type := int(weather.current_weather) if weather else 0
	var target_color := RoadmapWorld.weather_grade_color(RoadmapWorld.weather_name(weather_type), tier)
	_apply_weather_lut()
	var tween := create_tween()
	tween.tween_property(_canvas_modulate, "color", target_color, 1.2)

func _on_boss_defeated(boss_type: String) -> void:
	GameManager.record_boss_defeated(boss_type)
	var demo_scene = null
	if boss_type == "boss_bunny":
		demo_scene = DEMO_BUNNY_SCENE.instantiate()
	elif boss_type == "boss_giant_biker":
		demo_scene = DEMO_GIANT_BIKER_SCENE.instantiate()
	elif boss_type == "boss_void_drone":
		demo_scene = DEMO_VOID_SCENE.instantiate()
	elif boss_type == "boss":
		demo_scene = DEMO_WAR_SCENE.instantiate()

	if demo_scene:
		get_tree().paused = true
		$UI.add_child(demo_scene)
		demo_scene.demo_finished.connect(_on_demo_finished)
	else:
		get_tree().paused = false

func _on_demo_finished() -> void:
	get_tree().paused = false
	AudioManager.play_game_music()

func _sync_minimap() -> void:
	if not is_instance_valid(_minimap_camera) or not is_instance_valid(player):
		return
	_minimap_camera.position = player.global_position

func _sync_rear_view() -> void:
	if not is_instance_valid(_rear_view_camera) or not is_instance_valid(player):
		return
	_rear_view_camera.position = player.global_position + Vector2(0, 200)
	_rear_view_camera.rotation = PI

func _on_viewport_size_changed() -> void:
	var viewport_rect = get_viewport().get_visible_rect()
	if viewport_rect.size.x <= 0:
		return
	apply_letterbox_for_size(viewport_rect.size)
	var scale_factor := RoadmapWorld.viewport_scale_factor(viewport_rect.size)
	world.scale = Constants.WORLD_SCALE * scale_factor
