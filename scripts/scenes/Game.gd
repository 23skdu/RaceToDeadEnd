extends Node

const BULLET_SCENE = preload("res://scenes/weapons/Bullet.tscn")
const MINE_SCENE = preload("res://scenes/weapons/Mine.tscn")
const EMP_SCENE = preload("res://scenes/weapons/EMPBlast.tscn")
const ROTOR_SCENE = preload("res://scenes/enemies/Rotor.tscn")
const SCAV_SCENE = preload("res://scenes/enemies/Scav.tscn")
const DRONE_SCENE = preload("res://scenes/enemies/Drone.tscn")
const DRONE_BOMB_SCENE = preload("res://scenes/weapons/DroneBomb.tscn")
const BOSS_SCENE = preload("res://scenes/enemies/BossWarRig.tscn")
const BOSS_BUNNY_SCENE = preload("res://scenes/enemies/BossBunny.tscn")
const BABY_BUNNY_BOMB_SCENE = preload("res://scenes/weapons/BabyBunnyBomb.tscn")
const BOSS_SASQUATCH_SCENE = preload("res://scenes/enemies/BossSasquatch.tscn")
const POOP_WEAPON_SCENE = preload("res://scenes/weapons/PoopWeapon.tscn")
const BOSS_VOID_DRONE_SCENE = preload("res://scenes/enemies/BossVoidDrone.tscn")
const CIVILIAN_SCENE = preload("res://scenes/enemies/Civilian.tscn")

const DEMO_BUNNY_SCENE = preload("res://demo/DemoBossBunny.tscn")
const DEMO_SASQ_SCENE = preload("res://demo/DemoBossSasquatch.tscn")
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
	_setup_parallax()
	world.scale = Constants.WORLD_SCALE
	world.set_y_sort_enabled(true)

	var env_res = load("res://assets/environments/game_env.tres")
	if env_res:
		var we = WorldEnvironment.new()
		we.environment = env_res
		add_child(we)
		move_child(we, get_child_count() - 1)
	
	ObjectPool.create_pool("bullet", BULLET_SCENE, 50)
	ObjectPool.create_pool("mine", MINE_SCENE, 10)
	ObjectPool.create_pool("emp", EMP_SCENE, 5)
	ObjectPool.create_pool("rotor", ROTOR_SCENE, 8)
	ObjectPool.create_pool("scav", SCAV_SCENE, 6)
	ObjectPool.create_pool("drone", DRONE_SCENE, 4)
	ObjectPool.create_pool("drone_bomb", DRONE_BOMB_SCENE, 6)
	ObjectPool.create_pool("boss", BOSS_SCENE, 2)
	ObjectPool.create_pool("boss_bunny", BOSS_BUNNY_SCENE, 2)
	ObjectPool.create_pool("baby_bunny_bomb", BABY_BUNNY_BOMB_SCENE, 10)
	ObjectPool.create_pool("boss_sasquatch", BOSS_SASQUATCH_SCENE, 2)
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
	if spawner.has_signal("boss_defeated"):
		spawner.boss_defeated.connect(_on_boss_defeated)
	highway.player = player
	
	if weather:
		weather.set_player(player)
		weather.set_highway(highway)
		weather.set_weather(weather.WeatherType.CLEAR)
	
	if player:
		player.weapon_fired.connect(_on_player_weapon_fired)
		player.weapon_switched.connect(func(idx): hud.update_weapon_display(idx, player.secondary_ammo[idx]))
		player.boost_charge_updated.connect(hud.update_boost_charges)
		player.boost_activated.connect(func(): hud.set_boost_active(true))
		player.boost_depleted.connect(func(): hud.set_boost_active(false))
		player.damage_taken.connect(func(amount): _show_floating_text(player.global_position, "-" + str(amount), Color.RED, 18))
		
		highway.ice_entered.connect(player.set_slippery.bind(true))
		highway.ice_exited.connect(player.set_slippery.bind(false))
		highway.bridge_fall.connect(player.on_bridge_fall)
		
		# Initial UI sync
		hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
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
	var tier = GameManager.difficulty_tier
	if tier >= 5 and tier < 8:
		weather.set_weather(weather.WeatherType.LIGHT_RAIN)
	elif tier >= 8 and tier < 12:
		weather.set_weather(weather.WeatherType.ACID_RAIN)
	elif tier >= 12:
		weather.set_weather(weather.WeatherType.STORM)

static var _cached_parallax_textures: Array[Texture2D] = []

func _setup_parallax() -> void:
	_parallax = ParallaxBackground.new()
	_parallax.name = "ParallaxBackground"
	_parallax.scroll_offset = Vector2.ZERO
	add_child(_parallax)
	move_child(_parallax, 0)

	var layers = [
		{ "scale": Vector2(0.1, 0.0), "color": Color(0.08, 0.08, 0.15), "label": "far" },
		{ "scale": Vector2(0.3, 0.0), "color": Color(0.12, 0.1, 0.18), "label": "mid" },
		{ "scale": Vector2(0.6, 0.0), "color": Color(0.18, 0.14, 0.22), "label": "near" },
	]
	if _cached_parallax_textures.is_empty():
		for l in layers:
			var img = Image.create(4, 256, false, Image.FORMAT_RGBA8)
			for y in 256:
				var t = float(y) / 255.0
				var c = l.color.lerp(Color(l.color.r * 0.5, l.color.g * 0.5, l.color.b * 0.5, 1.0), t)
				img.set_pixel(0, y, c)
				img.set_pixel(1, y, c)
				img.set_pixel(2, y, c)
				img.set_pixel(3, y, c)
			_cached_parallax_textures.append(ImageTexture.create_from_image(img))
	for i in _cached_parallax_textures.size():
		var l = layers[i]
		var layer = ParallaxLayer.new()
		layer.name = "Layer" + l.label.capitalize()
		layer.motion_scale = l.scale
		var sprite = Sprite2D.new()
		sprite.texture = _cached_parallax_textures[i]
		sprite.centered = false
		var vs = DisplayServer.window_get_size()
		sprite.scale = Vector2(vs.x / 4.0, 3.0)
		sprite.position = Vector2(0, -vs.y * 0.5)
		layer.add_child(sprite)
		_parallax.add_child(layer)

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

var _parallax: ParallaxBackground = null
var _pause_menu: CanvasLayer = null
var _options_menu: CanvasLayer = null
var _game_over_restart_timer: float = 0.0

func _process(delta: float) -> void:
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
			if not bullet.hit_target.is_connected(_on_bullet_hit):
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
			if not bullet.hit_target.is_connected(_on_bullet_hit):
				bullet.hit_target.connect(_on_bullet_hit)
			hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
			AudioManager.play_synth_laser(pos)
		"mine":
			var mine = ObjectPool.acquire("mine")
			world.add_child(mine)
			mine.init(pos)
			hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
			AudioManager.play_synth_explosion(pos)
		"emp":
			var emp = ObjectPool.acquire("emp")
			world.add_child(emp)
			emp.init(pos)
			hud.update_weapon_display(player.current_weapon, player.secondary_ammo[player.current_weapon])
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
	pop.text = ""
	pop.position = Vector2.ZERO
	pop.modulate = Color.WHITE
	pop.visible = false
	if pop.get_parent():
		pop.get_parent().remove_child(pop)
	_popup_pool.append(pop)

func _show_floating_text(pos: Vector2, text: String, color: Color, size: int = 18) -> void:
	var popup = _get_popup_label()
	popup.text = text
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_font_size_override("font_size", size)
	popup.position = pos
	popup.visible = true
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
	score_popup_container.add_child(popup)
	var tween = create_tween()
	tween.tween_property(popup, "position:y", pos.y - 60.0, 0.8)
	tween.tween_property(popup, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_return_popup_label.bind(popup))

func _on_boss_defeated(boss_type: String) -> void:
	GameManager.bosses_killed += 1
	get_tree().paused = true
	var demo_scene = null
	if boss_type == "boss_bunny":
		demo_scene = DEMO_BUNNY_SCENE.instantiate()
	elif boss_type == "boss_sasquatch":
		demo_scene = DEMO_SASQ_SCENE.instantiate()
	elif boss_type == "boss_void_drone":
		demo_scene = DEMO_VOID_SCENE.instantiate()
	elif boss_type == "boss":
		demo_scene = DEMO_WAR_SCENE.instantiate()
		
	if demo_scene:
		$UI.add_child(demo_scene)
		demo_scene.demo_finished.connect(_on_demo_finished)

func _on_demo_finished() -> void:
	get_tree().paused = false
	AudioManager.play_game_music()
