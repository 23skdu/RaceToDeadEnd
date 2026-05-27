extends CharacterBody2D

const HelpersUtil = preload("res://scripts/utils/Helpers.gd")


signal destroyed(position: Vector2, enemy_type: String, enemy: Node)

enum EnemyType { BUNNY, ROTOR, SCAV, DRONE, SASQUATCH }

const TYPE_NAMES: Array[String] = ["bunny", "rotor", "scav", "drone", "sasquatch"]
const ROTOR_TEXTURE = preload("res://assets/sprites/enemies/rotor.png")
const SCAV_TEXTURE = preload("res://assets/sprites/enemies/scav.png")
const DRONE_TEXTURE = preload("res://assets/sprites/enemies/drone.png")

static var _bunny_texture: Texture2D = null

var enemy_type: EnemyType = EnemyType.ROTOR
var boss_key: String = ""
var hp: int = 1
var speed: float = 200.0
var lane: int = 0
var score_value: int = 50
var can_damage_player: bool = true
var player: Node = null
var stunned: bool = false
var stun_timer: float = 0.0
var _spawner: Node = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hit_flash_timer: Timer = $HitFlashTimer

func _ready() -> void:
	collision_layer = 2
	z_index = 1
	add_to_group("enemy")
	if not get_viewport().size_changed.is_connected(_scale_sprite):
		get_viewport().size_changed.connect(_scale_sprite)

func init(type: EnemyType, start_lane: int, player_ref: Node, base_speed: float, spawner: Node = null) -> void:
	enemy_type = type
	lane = start_lane
	player = player_ref
	_spawner = spawner
	match type:
		EnemyType.BUNNY:
			hp = 1
			speed = base_speed * Constants.BUNNY_SPEED_MULTIPLIER
			score_value = 50
		EnemyType.ROTOR:
			hp = 1
			speed = base_speed * Constants.ROTOR_SPEED_MULTIPLIER
			score_value = 50
		EnemyType.SCAV:
			hp = 3
			speed = base_speed * Constants.SCAV_SPEED_MULTIPLIER
			score_value = 100
		EnemyType.DRONE:
			hp = 2
			speed = base_speed * Constants.DRONE_SPEED_MULTIPLIER
			score_value = 200
		EnemyType.SASQUATCH:
			hp = Constants.BOSS_SASQUATCH_HP
			speed = base_speed * 0.6
			score_value = 300
	_update_sprite()

func _update_sprite() -> void:
	match enemy_type:
		EnemyType.BUNNY:
			if not _bunny_texture:
				_bunny_texture = _create_bunny_texture()
			sprite.texture = _bunny_texture
		EnemyType.ROTOR:
			sprite.texture = ROTOR_TEXTURE
		EnemyType.SCAV:
			sprite.texture = SCAV_TEXTURE
		EnemyType.DRONE:
			sprite.texture = DRONE_TEXTURE
		EnemyType.SASQUATCH:
			if not sprite.texture:
				var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
				img.fill(Color(0.5, 0.25, 0.1, 1.0))
				sprite.texture = ImageTexture.create_from_image(img)
	_scale_sprite()

func _scale_sprite() -> void:
	HelpersUtil.scale_sprite_to_viewport(sprite, Constants.SPRITE_BASE_SIZE, Constants.SPRITE_BASE_VIEWPORT)

static func _create_bunny_texture() -> ImageTexture:
	# 64x64 pixel-art bunny, transparent background
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var fur       = Color(0.95, 0.95, 0.97, 1.0)   # near-white fur
	var inner_ear = Color(1.00, 0.60, 0.70, 1.0)   # pink inner ear
	var eye_red   = Color(0.90, 0.10, 0.10, 1.0)   # menacing red eyes
	var nose_pink = Color(1.00, 0.45, 0.60, 1.0)   # pink nose
	var outline   = Color(0.35, 0.30, 0.35, 1.0)   # dark outline

	# Helper: filled ellipse
	var fill_ellipse = func(cx: int, cy: int, rx: float, ry: float, col: Color) -> void:
		for px in range(int(cx - rx - 1), int(cx + rx + 2)):
			for py in range(int(cy - ry - 1), int(cy + ry + 2)):
				if px < 0 or px >= 64 or py < 0 or py >= 64:
					continue
				var nx = (px - cx) / rx
				var ny = (py - cy) / ry
				if nx * nx + ny * ny <= 1.0:
					img.set_pixel(px, py, col)

	# Helper: outline ellipse (1px border)
	var outline_ellipse = func(cx: int, cy: int, rx: float, ry: float, col: Color) -> void:
		for px in range(int(cx - rx - 2), int(cx + rx + 3)):
			for py in range(int(cy - ry - 2), int(cy + ry + 3)):
				if px < 0 or px >= 64 or py < 0 or py >= 64:
					continue
				var nx = (px - cx) / (rx + 1.0)
				var ny = (py - cy) / (ry + 1.0)
				if nx * nx + ny * ny <= 1.0:
					if img.get_pixel(px, py).a < 0.5:
						img.set_pixel(px, py, col)

	# --- Left ear (tall oval) ---
	fill_ellipse.call(22, 16, 5.0, 13.0, outline)
	fill_ellipse.call(22, 16, 3.5, 11.0, fur)
	fill_ellipse.call(22, 17, 2.0, 8.0, inner_ear)

	# --- Right ear (tall oval) ---
	fill_ellipse.call(42, 16, 5.0, 13.0, outline)
	fill_ellipse.call(42, 16, 3.5, 11.0, fur)
	fill_ellipse.call(42, 17, 2.0, 8.0, inner_ear)

	# --- Body (oval, below head) ---
	outline_ellipse.call(32, 50, 11.0, 9.0, outline)
	fill_ellipse.call(32, 50, 10.0, 8.0, fur)

	# --- Head (round) ---
	outline_ellipse.call(32, 34, 14.0, 13.0, outline)
	fill_ellipse.call(32, 34, 13.0, 12.0, fur)

	# --- Eyes: 2x2 red pixels each ---
	for dx in [0, 1]:
		for dy in [0, 1]:
			img.set_pixel(25 + dx, 30 + dy, eye_red)
			img.set_pixel(38 + dx, 30 + dy, eye_red)

	# --- Nose (small pink oval) ---
	fill_ellipse.call(32, 38, 2.5, 1.8, nose_pink)

	# --- Mouth: small V shape ---
	img.set_pixel(30, 41, outline)
	img.set_pixel(31, 42, outline)
	img.set_pixel(32, 41, outline)
	img.set_pixel(33, 42, outline)
	img.set_pixel(34, 41, outline)

	# --- Whisker dots (subtle) ---
	var whisker_col = Color(0.70, 0.70, 0.72, 0.8)
	for wd in [0, 1, 2]:
		img.set_pixel(16 + wd * 2, 38, whisker_col)
		img.set_pixel(46 - wd * 2, 38, whisker_col)

	return ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
	if stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			stunned = false
			sprite.modulate = Color.WHITE

func apply_stun(duration: float) -> void:
	stunned = true
	stun_timer = duration
	sprite.modulate = Color(0.5, 0.5, 1.0, 0.7)

func take_damage(amount: int = 1) -> void:
	hp -= amount
	_play_hit_flash()
	_play_hit_sound()
	if hp <= 0:
		_die()

func on_pool_release() -> void:
	stunned = false
	stun_timer = 0.0
	hp = 1
	speed = 200.0
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	velocity = Vector2.ZERO
	# Re-enable collision so pooled enemies are not immune after first death
	if collision:
		collision.set_deferred(&"disabled", false)
	if _spawner and destroyed.is_connected(_spawner._on_enemy_destroyed):
		destroyed.disconnect(_spawner._on_enemy_destroyed)

func _play_hit_sound() -> void:
	match enemy_type:
		EnemyType.BUNNY:
			AudioManager.play_bunny_hit(global_position)
		EnemyType.ROTOR:
			AudioManager.play_rotor_hit(global_position)
		EnemyType.SCAV:
			AudioManager.play_scav_hit(global_position)
		EnemyType.DRONE:
			AudioManager.play_drone_hit(global_position)
		EnemyType.SASQUATCH:
			AudioManager.play_scav_hit(global_position)

func _play_hit_flash() -> void:
	if not stunned:
		sprite.modulate = Color.RED
	hit_flash_timer.start()

func _on_hit_flash_timer_timeout() -> void:
	if not stunned:
		sprite.modulate = Color.WHITE

func _die() -> void:
	_play_death_sound()
	CameraShake.shake(0.3, 0.2, 4.0)
	CameraShake.rumble(0.3, 0.2)
	collision.set_deferred(&"disabled", true)
	_death_animation()
	var type_str = boss_key if boss_key else TYPE_NAMES[enemy_type]
	destroyed.emit(global_position, type_str, self)
	if _spawner and destroyed.is_connected(_spawner._on_enemy_destroyed):
		destroyed.disconnect(_spawner._on_enemy_destroyed)
	ObjectPool.release(self)

func _death_animation() -> void:
	sprite.scale = Vector2.ZERO

func _play_death_sound() -> void:
	match enemy_type:
		EnemyType.BUNNY:
			AudioManager.play_bunny_death(global_position)
		EnemyType.ROTOR:
			AudioManager.play_rotor_death(global_position)
		EnemyType.SCAV:
			AudioManager.play_scav_death(global_position)
		EnemyType.DRONE:
			AudioManager.play_drone_death(global_position)
		EnemyType.SASQUATCH:
			AudioManager.play_scav_death(global_position)
