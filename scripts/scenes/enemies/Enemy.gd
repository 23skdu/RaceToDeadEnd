extends CharacterBody2D

const HelpersUtil = preload("res://scripts/utils/Helpers.gd")


signal destroyed(position: Vector2, enemy_type: String, enemy: Node)
signal animation_event_fired(event: String)

enum EnemyType { BUNNY, ROTOR, SCAV, DRONE, SASQUATCH }

const TYPE_NAMES: Array[String] = ["bunny", "rotor", "scav", "drone", "sasquatch"]
const ANIMATION_STATES: Array[String] = ["idle", "move", "attack", "hit", "enrage", "phase2", "death"]
const ANIMATION_LIBRARY_NAME: String = "roadmap"
const ROTOR_TEXTURE = preload("res://assets/sprites/enemies/rotor.png")
const SCAV_TEXTURE = preload("res://assets/sprites/enemies/scav.png")
const DRONE_TEXTURE = preload("res://assets/sprites/enemies/drone.png")

static var _bunny_texture: Texture2D = null
static var _sasquatch_fallback_texture: Texture2D = null
static var _eye_shader_material: ShaderMaterial = null

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

var animation_state: String = "idle"
var animation_hold_timer: float = 0.0
var animation_player: AnimationPlayer = null
var animation_tree: AnimationTree = null
var _animation_player: AnimationPlayer = null
var _animation_tree: AnimationTree = null
var _animation_library: AnimationLibrary = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hit_flash_timer: Timer = $HitFlashTimer

func _ready() -> void:
	collision_layer = 2
	z_index = 1
	add_to_group("enemy")
	if not get_viewport().size_changed.is_connected(_scale_sprite):
		get_viewport().size_changed.connect(_scale_sprite)
	if PackManager and PackManager.has_signal("skin_loaded") and not PackManager.skin_loaded.is_connected(_on_pack_skin_loaded):
		PackManager.skin_loaded.connect(_on_pack_skin_loaded)
	if hit_flash_timer and not hit_flash_timer.timeout.is_connected(_on_hit_flash_timer_timeout):
		hit_flash_timer.timeout.connect(_on_hit_flash_timer_timeout)
	_setup_animation_rig()

func _on_pack_skin_loaded(entity: String, tex: Texture2D) -> void:
	if entity == TYPE_NAMES[enemy_type] or (boss_key != "" and entity == boss_key):
		if tex:
			sprite.texture = tex
			_scale_sprite()
		else:
			_update_sprite()

func init(type: EnemyType, start_lane: int, player_ref: Node, base_speed: float, spawner: Node = null) -> void:
	enemy_type = type
	lane = start_lane
	player = player_ref
	_spawner = spawner
	stunned = false
	stun_timer = 0.0
	if collision:
		collision.disabled = false
		collision.set_deferred(&"disabled", false)
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.modulate = Color.WHITE
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
	var type_key: String = boss_key if boss_key != "" else TYPE_NAMES[enemy_type]
	if PackManager and PackManager.has_method("get_custom_skin"):
		var custom_tex: Texture2D = PackManager.get_custom_skin(type_key)
		if custom_tex:
			sprite.texture = custom_tex
			_scale_sprite()
			return
	match enemy_type:
		EnemyType.BUNNY:
			if not _bunny_texture:
				_bunny_texture = _create_bunny_texture()
			sprite.texture = _bunny_texture
			apply_pulsating_eyes_shader()
		EnemyType.ROTOR:
			sprite.texture = ROTOR_TEXTURE
		EnemyType.SCAV:
			sprite.texture = SCAV_TEXTURE
		EnemyType.DRONE:
			sprite.texture = DRONE_TEXTURE
		EnemyType.SASQUATCH:
			if not sprite.texture:
				if not _sasquatch_fallback_texture:
					var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
					img.fill(Color(0.5, 0.25, 0.1, 1.0))
					_sasquatch_fallback_texture = ImageTexture.create_from_image(img)
				sprite.texture = _sasquatch_fallback_texture
	_scale_sprite()

func _scale_sprite() -> void:
	HelpersUtil.scale_sprite_to_viewport(sprite, Constants.SPRITE_BASE_SIZE, Constants.SPRITE_BASE_VIEWPORT)

func apply_pulsating_eyes_shader() -> void:
	if not _eye_shader_material:
		var eye_shader = Shader.new()
		eye_shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.r > 0.8 && c.g < 0.2 && c.b < 0.2 && c.a > 0.0) {
		float pulse = sin(TIME * 6.0) * 0.5 + 0.5;
		COLOR = vec4(mix(c.rgb, vec3(1.0, 0.6, 0.6), pulse), c.a);
	} else {
		COLOR = c;
	}
}
"""
		_eye_shader_material = ShaderMaterial.new()
		_eye_shader_material.shader = eye_shader
	sprite.material = _eye_shader_material

static func _create_bunny_texture() -> ImageTexture:
	return _create_rabbit_texture(64, false)

# Natural rabbit portrait authored in a 64x64 design space. The same drawing is
# scaled up for the boss so both enemies read as real rabbits, not robots.
static func _create_rabbit_texture(size: int = 64, boss: bool = false) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var s := float(size) / 64.0

	var fur_base := Color(0.96, 0.95, 0.92, 1.0)
	var fur_shadow := Color(0.70, 0.70, 0.69, 1.0)
	var fur_deep := Color(0.47, 0.46, 0.45, 1.0)
	var fur_highlight := Color(1.0, 0.99, 0.97, 0.55)
	var fur_speck := Color(0.60, 0.60, 0.58, 0.10)
	var pink_soft := Color(0.95, 0.62, 0.68, 0.32)
	var pink_inner := Color(0.88, 0.48, 0.55, 1.0)
	var pink_inner_light := Color(0.97, 0.70, 0.74, 1.0)
	var pink_nose := Color(0.86, 0.38, 0.46, 1.0)
	var eye_socket := Color(0.30, 0.18, 0.17, 1.0)
	var eye_ruby := Color(0.86, 0.08, 0.14, 1.0)
	var eye_dark := Color(0.14, 0.02, 0.03, 1.0)
	var eye_glint := Color(1.0, 1.0, 1.0, 1.0)
	var ear_tip := fur_deep

	if boss:
		# A larger wild hare: greyer fur, darker ear tips, heavier brow.
		fur_base = Color(0.82, 0.79, 0.73, 1.0)
		fur_shadow = Color(0.50, 0.48, 0.44, 1.0)
		fur_deep = Color(0.32, 0.30, 0.27, 1.0)
		fur_highlight = Color(0.95, 0.92, 0.86, 0.50)
		fur_speck = Color(0.42, 0.40, 0.37, 0.14)
		pink_soft = Color(0.70, 0.40, 0.42, 0.30)
		pink_inner = Color(0.72, 0.36, 0.40, 1.0)
		pink_inner_light = Color(0.86, 0.52, 0.54, 1.0)
		pink_nose = Color(0.62, 0.28, 0.32, 1.0)
		eye_socket = Color(0.22, 0.13, 0.12, 1.0)
		eye_ruby = Color(0.88, 0.07, 0.10, 1.0)
		eye_dark = Color(0.12, 0.02, 0.03, 1.0)
		ear_tip = Color(0.38, 0.33, 0.30, 1.0)

	var put := func(dx: float, dy: float, col: Color) -> void:
		var px := int(round(dx * s))
		var py := int(round(dy * s))
		if px >= 0 and px < size and py >= 0 and py < size:
			img.set_pixel(px, py, col)

	var blend := func(dx: float, dy: float, col: Color) -> void:
		var px := int(round(dx * s))
		var py := int(round(dy * s))
		if px < 0 or px >= size or py < 0 or py >= size:
			return
		var old := img.get_pixel(px, py)
		if old.a <= 0.0:
			img.set_pixel(px, py, col)
		else:
			img.set_pixel(px, py, old.lerp(Color(col.r, col.g, col.b, 1.0), col.a))

	var ellipse := func(cx: float, cy: float, rx: float, ry: float, col: Color, angle: float, painter: Callable) -> void:
		var ca := cos(angle)
		var sa := sin(angle)
		var reach := maxf(rx, ry) + 1.0
		var min_x := clampi(int((cx - reach) * s), 0, size - 1)
		var max_x := clampi(int((cx + reach) * s), 0, size - 1)
		var min_y := clampi(int((cy - reach) * s), 0, size - 1)
		var max_y := clampi(int((cy + reach) * s), 0, size - 1)
		for px in range(min_x, max_x + 1):
			for py in range(min_y, max_y + 1):
				var x := float(px) / s - cx
				var y := float(py) / s - cy
				var lx := x * ca + y * sa
				var ly := -x * sa + y * ca
				if lx * lx / (rx * rx) + ly * ly / (ry * ry) <= 1.0:
					painter.call(x + cx, y + cy, col)

	var soft_line := func(x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
		var distance := Vector2(x1 - x0, y1 - y0).length()
		var steps := maxi(1, int(distance * 2.0))
		for i in range(steps + 1):
			var t := float(i) / steps
			blend.call(lerpf(x0, x1, t), lerpf(y0, y1, t), col)

	var fur_noise := func(cx: float, cy: float, rx: float, ry: float) -> void:
		for px in range(size):
			for py in range(size):
				var x := float(px) / s - cx
				var y := float(py) / s - cy
				if x * x / (rx * rx) + y * y / (ry * ry) <= 1.0:
					if (px * 7 + py * 11) % 9 == 0:
						blend.call(x + cx, y + cy, fur_speck)

	# Long upright ears with a soft fur rim and pink interior.
	ellipse.call(21.0, 14.0, 6.0, 13.5, fur_deep, -0.12, put)
	ellipse.call(43.0, 14.0, 6.0, 13.5, fur_deep, 0.12, put)
	ellipse.call(21.0, 14.0, 5.2, 12.7, fur_base, -0.12, put)
	ellipse.call(43.0, 14.0, 5.2, 12.7, fur_base, 0.12, put)
	ellipse.call(21.0, 14.5, 3.2, 10.5, pink_inner, -0.12, put)
	ellipse.call(43.0, 14.5, 3.2, 10.5, pink_inner, 0.12, put)
	ellipse.call(21.0, 14.0, 2.0, 8.5, pink_inner_light, -0.12, put)
	ellipse.call(43.0, 14.0, 2.0, 8.5, pink_inner_light, 0.12, put)
	if boss:
		ellipse.call(21.0, 3.0, 4.4, 3.2, ear_tip, -0.12, put)
		ellipse.call(43.0, 3.0, 4.4, 3.2, ear_tip, 0.12, put)

	# Fluffy tail, rounded body and head, each with a shaded rim and fur grain.
	ellipse.call(32.0, 58.5, 5.5, 3.8, fur_base, 0.0, put)
	ellipse.call(32.0, 58.0, 3.5, 2.2, fur_highlight, 0.0, blend)

	ellipse.call(32.0, 51.0, 12.0, 10.0, fur_shadow, 0.0, put)
	ellipse.call(32.0, 50.0, 11.0, 9.2, fur_base, 0.0, put)
	ellipse.call(29.0, 47.0, 6.0, 4.0, fur_highlight, 0.0, blend)
	fur_noise.call(32.0, 50.0, 11.0, 9.0)

	ellipse.call(32.0, 34.0, 16.0, 14.2, fur_shadow, 0.0, put)
	ellipse.call(32.0, 34.0, 15.0, 13.2, fur_base, 0.0, put)
	ellipse.call(28.0, 29.0, 8.0, 5.5, fur_highlight, 0.0, blend)
	ellipse.call(32.0, 39.5, 8.0, 4.5, fur_highlight, 0.0, blend)
	fur_noise.call(32.0, 34.0, 15.0, 13.0)

	# Cheeks, ruby eyes with pupils and catchlights (the shader pulses the red).
	ellipse.call(22.0, 38.0, 3.4, 2.2, pink_soft, 0.0, blend)
	ellipse.call(42.0, 38.0, 3.4, 2.2, pink_soft, 0.0, blend)

	for eye_x in [25.0, 39.0]:
		ellipse.call(eye_x, 30.0, 3.4, 3.8, eye_socket, 0.0, put)
		ellipse.call(eye_x, 30.0, 2.5, 2.9, eye_ruby, 0.0, put)
		ellipse.call(eye_x, 31.7, 1.1, 1.3, eye_dark, 0.0, put)
		ellipse.call(eye_x - 1.0, 28.5, 0.8, 0.9, eye_glint, 0.0, put)
		ellipse.call(eye_x + 1.2, 29.3, 0.4, 0.5, eye_glint, 0.0, put)

	if boss:
		soft_line.call(21.0, 25.5, 28.0, 26.5, Color(fur_deep.r, fur_deep.g, fur_deep.b, 0.55))
		soft_line.call(43.0, 25.5, 36.0, 26.5, Color(fur_deep.r, fur_deep.g, fur_deep.b, 0.55))

	# Pink nose, mouth and fine whiskers.
	ellipse.call(32.0, 37.5, 2.2, 1.5, pink_nose, 0.0, put)
	ellipse.call(31.4, 37.0, 0.7, 0.5, pink_inner_light, 0.0, put)
	soft_line.call(32.0, 39.0, 29.0, 41.0, Color(fur_deep.r, fur_deep.g, fur_deep.b, 0.7))
	soft_line.call(32.0, 39.0, 35.0, 41.0, Color(fur_deep.r, fur_deep.g, fur_deep.b, 0.7))

	var whisker := Color(0.55, 0.54, 0.52, 0.75)
	for side: float in [-1.0, 1.0]:
		var root := 32.0 + side * 5.0
		soft_line.call(root, 38.0, 32.0 + side * 18.0, 35.0, whisker)
		soft_line.call(root, 39.0, 32.0 + side * 19.0, 39.0, whisker)
		soft_line.call(root, 40.0, 32.0 + side * 18.0, 44.0, whisker)

	return ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
	if stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			stunned = false
			sprite.modulate = Color.WHITE
	if animation_hold_timer > 0.0:
		animation_hold_timer -= delta
	_update_animation_state()

func _get_slide_collisions() -> Array:
	var list = []
	for i in get_slide_collision_count():
		list.append(get_slide_collision(i))
	return list

func handle_obstacle_collisions() -> void:
	if boss_key == "":
		return
	for col in _get_slide_collisions():
		var collider = col.get_collider()
		if collider and is_instance_valid(collider):
			if collider.is_in_group("obstacles") or collider.is_in_group("deadly_obstacles"):
				var parent_node = collider.get_parent()
				if parent_node and parent_node.name == "Tiles":
					collider.visible = false
					if collider is CollisionObject2D:
						collider.collision_layer = 0
						collider.collision_mask = 0
				else:
					collider.queue_free()

func apply_stun(duration: float) -> void:
	stunned = true
	stun_timer = duration
	sprite.modulate = Color(0.5, 0.5, 1.0, 0.7)

func take_damage(amount: int = 1) -> void:
	if get_meta("_in_pool", false) or hp <= 0:
		return
	hp -= amount
	_play_hit_flash()
	_play_hit_sound()
	if hp <= 0:
		_die()

func on_pool_acquire() -> void:
	stunned = false
	stun_timer = 0.0
	animation_hold_timer = 0.0
	velocity = Vector2.ZERO
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.modulate = Color.WHITE
	if collision:
		collision.disabled = false
		collision.set_deferred(&"disabled", false)

func on_pool_release() -> void:
	stunned = false
	stun_timer = 0.0
	animation_hold_timer = 0.0
	hp = 1
	speed = 200.0
	if sprite:
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
	set_animation_state("death")
	_death_animation()
	var type_str = boss_key if boss_key else TYPE_NAMES[enemy_type]
	destroyed.emit(global_position, type_str, self)
	if _spawner and destroyed.is_connected(_spawner._on_enemy_destroyed):
		destroyed.disconnect(_spawner._on_enemy_destroyed)
	ObjectPool.release(self)

func _death_animation() -> void:
	sprite.scale = Vector2.ZERO

func _setup_animation_rig() -> void:
	if not has_node("AnimationPlayer"):
		var ap := AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		add_child(ap)
	if not has_node("AnimationTree"):
		var at := AnimationTree.new()
		at.name = "AnimationTree"
		add_child(at)
	_animation_player = get_node_or_null("AnimationPlayer")
	_animation_tree = get_node_or_null("AnimationTree")
	animation_player = _animation_player
	animation_tree = _animation_tree
	if not is_instance_valid(animation_player) or not is_instance_valid(animation_tree):
		return

	_animation_library = AnimationLibrary.new()
	for state in ANIMATION_STATES:
		_animation_library.add_animation(state, _build_animation_clip(state))
	if not animation_player.has_animation_library(ANIMATION_LIBRARY_NAME):
		animation_player.add_animation_library(ANIMATION_LIBRARY_NAME, _animation_library)

	animation_tree.anim_player = animation_player.get_path()
	animation_tree.tree_root = _build_state_machine()
	animation_tree.active = true
	_start_animation_playback()

func _build_animation_clip(state: String) -> Animation:
	var clip := Animation.new()
	var length: float = 0.6
	match state:
		"idle", "move":
			length = 1.0
			clip.loop_mode = Animation.LOOP_LINEAR
		"hit":
			length = 0.25
		"enrage":
			length = 1.2
		"phase2":
			length = 1.0
		"death":
			length = 0.5
	clip.length = length

	var rotations: Array[float] = [0.0, 0.03, 0.0]
	var colors: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE]
	match state:
		"move":
			rotations = [-0.05, 0.05, -0.05]
		"attack":
			rotations = [0.0, 0.25, 0.0]
			colors = [Color.WHITE, Color(1.0, 0.65, 0.2, 1.0), Color.WHITE]
		"hit":
			rotations = [0.0, -0.12, 0.0]
			colors = [Color.WHITE, Color.RED, Color.WHITE]
		"enrage":
			rotations = [0.0, 0.18, 0.0]
			colors = [Color.WHITE, Color(1.0, 0.12, 0.12, 1.0), Color.WHITE]
		"phase2":
			rotations = [0.0, -0.18, 0.0]
			colors = [Color.WHITE, Color(0.7, 0.2, 1.0, 1.0), Color.WHITE]
		"death":
			rotations = [0.0, 0.55, 0.8]
			colors = [Color.WHITE, Color(1.0, 1.0, 1.0, 0.6), Color(1.0, 1.0, 1.0, 0.0)]

	_add_value_track(clip, "Sprite2D:rotation", [0.0, length * 0.5, length], rotations)
	_add_value_track(clip, "Sprite2D:modulate", [0.0, length * 0.5, length], colors)
	if state == "attack":
		_add_event_key(clip, length * 0.25, "attack_strike")
	elif state == "enrage":
		_add_event_key(clip, length * 0.5, "enrage_burst")
	elif state == "phase2":
		_add_event_key(clip, length * 0.5, "phase2_shift")
	return clip

func _add_value_track(clip: Animation, property: String, times: Array, values: Array) -> void:
	var track: int = clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, property)
	for i in range(times.size()):
		clip.track_insert_key(track, float(times[i]), values[i])

func _add_event_key(clip: Animation, time: float, event: String) -> void:
	var track: int = clip.add_track(Animation.TYPE_METHOD)
	clip.track_set_path(track, ".")
	clip.track_insert_key(track, time, {"method": "fire_animation_event", "args": [event]})

func _build_state_machine() -> AnimationNodeStateMachine:
	var machine := AnimationNodeStateMachine.new()
	for i in range(ANIMATION_STATES.size()):
		var state: String = ANIMATION_STATES[i]
		var node := AnimationNodeAnimation.new()
		node.animation = state
		machine.add_node(state, node, Vector2(float(i) * 160.0, 0.0))
	for from in ANIMATION_STATES:
		for to in ANIMATION_STATES:
			if from == to:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
			transition.advance_condition = "to_" + to
			machine.add_transition(from, to, transition)
	return machine

func _start_animation_playback() -> void:
	var playback: Variant = animation_tree.get("parameters/playback")
	if playback != null and playback.has_method("start"):
		playback.call("start", "idle")

func play_animation(state: String) -> void:
	var resolved: String = state if ANIMATION_STATES.has(state) else "idle"
	animation_state = resolved
	if resolved in ["attack", "enrage", "phase2"]:
		animation_hold_timer = 0.6
	if is_instance_valid(animation_player) and animation_player.has_animation(resolved):
		animation_player.play(resolved)
	if is_instance_valid(animation_tree):
		var playback: Variant = animation_tree.get("parameters/playback")
		if playback != null and playback.has_method("travel"):
			playback.call("travel", resolved)
		for other in ANIMATION_STATES:
			animation_tree.set("parameters/conditions/to_" + other, false)
		animation_tree.set("parameters/conditions/to_" + resolved, true)
	fire_animation_event("state:" + resolved)

func set_animation_state(state: String) -> void:
	play_animation(state)

func play_boss_animation(state: String) -> void:
	if SettingsManager and SettingsManager.is_feature_enabled(Constants.FEATURE_BOSS_ANIMATIONS, true):
		set_animation_state(state)

func fire_animation_event(event: String) -> void:
	animation_event_fired.emit(event)
	_sync_demo_overlay(event)

func _sync_demo_overlay(event: String) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	for overlay in get_tree().get_nodes_in_group("boss_animation_demo"):
		if is_instance_valid(overlay) and overlay.has_method("on_enemy_animation_event"):
			overlay.call("on_enemy_animation_event", event, self)

func _update_animation_state() -> void:
	if hp <= 0:
		set_animation_state("death")
		return
	if stunned:
		if animation_state != "hit":
			set_animation_state("hit")
		return
	if animation_hold_timer > 0.0:
		return
	if animation_state != "idle":
		set_animation_state("idle")

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
