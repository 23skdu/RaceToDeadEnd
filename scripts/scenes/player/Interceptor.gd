extends CharacterBody2D

const HelpersUtil = preload("res://scripts/utils/Helpers.gd")
const RoadmapFx = preload("res://scripts/utils/RoadmapFx.gd")
const TRAIL_LENGTH: int = 12
const TRAIL_SPACING: float = 8.0
const EXPLOSION_POOL_SIZE: int = 6


signal weapon_fired(weapon_type: String, position: Vector2, direction: Vector2)
signal boost_activated
signal boost_depleted
signal boost_charge_updated(charges: int)
signal weapon_switched(weapon_index: int)
signal damage_taken(amount: int)

var current_lane: int = 1
var target_x: float = 0.0
var speed: float = Constants.BASE_SPEED
var boost_charges: int = 3
var max_boost_charges: int = 3
var boost_active: bool = false
var boost_timer: float = 0.0
var boost_recharge_timer: float = 0.0
var can_weave: bool = true
var weave_timer: float = 0.0
var primary_fire_timer: float = 0.0
var current_weapon: int = 0
var secondary_ammo: Array[int] = [3, 2, 1]
var invincible: bool = false
var invincible_timer: float = 0.0
var slippery: bool = false
var speed_input: float = 0.0
var wheel_tread_offset: float = 0.0
var _camera_y: float = 0.0

var last_left_tap_time: float = 0.0
var last_right_tap_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_mount: Marker2D = $WeaponMount
@onready var collision: CollisionShape2D = $CollisionShape2D

var _trail_line: Line2D
var _trail_gradient: Gradient
var _trail_points: Array[Vector2] = []
var _trail_spacing_counter: float = 0.0
var _default_sprite_texture: Texture2D = null
var _default_sprite_modulate: Color = Color(0.2, 0.6, 1.0, 1.0)

var _headlight: PointLight2D = null
var _underglow: PointLight2D = null

var _boost_exhaust: GPUParticles2D = null
var _muzzle_flash: GPUParticles2D = null
var _boost_trail: GPUParticles2D = null
var _boost_smoke: GPUParticles2D = null

var _shockwave_pool: Array[GPUParticles2D] = []
var _shockwave_cursor: int = 0
var _shockwave_host: Node = null

var _prev_sprite_transform: Transform2D = Transform2D.IDENTITY
var _target_sprite_transform: Transform2D = Transform2D.IDENTITY
var _sprite_interpolation_ready: bool = false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 2
	z_index = 1
	add_to_group("player")
	if sprite:
		if sprite.texture:
			_default_sprite_texture = sprite.texture
		_default_sprite_modulate = sprite.self_modulate
	if PackManager and PackManager.has_signal("skin_loaded") and not PackManager.skin_loaded.is_connected(_on_pack_skin_loaded):
		PackManager.skin_loaded.connect(_on_pack_skin_loaded)
	if SettingsManager and SettingsManager.has_signal("player_skin_changed") and not SettingsManager.player_skin_changed.is_connected(_on_player_skin_changed):
		SettingsManager.player_skin_changed.connect(_on_player_skin_changed)
	_apply_selected_skin()
	_scale_sprite()
	_setup_lights()
	_setup_particles()
	_setup_explosion_pool()
	$Camera2D.position.y = Constants.CAMERA_Y_OFFSET
	$Camera2D.position_smoothing_enabled = false
	var bl = GameManager.upgrade_levels.get("boost_capacity", 1)
	var missile_level = GameManager.upgrade_levels.get("missile_ammo", 1)
	var mine_level = GameManager.upgrade_levels.get("mine_ammo", 1)
	var emp_level = GameManager.upgrade_levels.get("emp_ammo", 1)
	
	max_boost_charges = 2 + bl
	boost_charges = max_boost_charges
	
	secondary_ammo = [
		2 + missile_level,
		1 + mine_level,
		emp_level
	]
	
	speed = GameManager.current_speed
	if not GameManager.speed_changed.is_connected(_on_speed_changed):
		GameManager.speed_changed.connect(_on_speed_changed)
	
	_trail_line = Line2D.new()
	_trail_line.width = 6.0
	_trail_line.default_color = Color(1.0, 0.5, 0.0, 0.8)
	_trail_line.z_index = -1
	_trail_gradient = Gradient.new()
	_trail_gradient.offsets = PackedFloat32Array([0.0, 1.0])
	_trail_gradient.colors = PackedColorArray([Color(1.0, 0.5, 0.0, 0.8), Color(1.0, 0.2, 0.0, 0.0)])
	_trail_line.gradient = _trail_gradient
	add_child(_trail_line)
	
	target_x = _lane_to_x(current_lane)
	position.x = target_x
	_camera_y = position.y
	_update_boost_ui()
	if not get_viewport().size_changed.is_connected(_scale_sprite):
		get_viewport().size_changed.connect(_scale_sprite)

func _on_speed_changed(new_speed: float) -> void:
	speed = new_speed

func _process(delta: float) -> void:
	_update_timers(delta)
	_apply_feature_gates()
	_apply_sprite_interpolation()

func _physics_process(delta: float) -> void:
	_handle_input(delta)
	var effective_speed: float
	if boost_active:
		effective_speed = speed * Constants.BOOST_SPEED_MULTIPLIER
	elif speed_input > 0:
		effective_speed = speed + Constants.ACCEL_SPEED
	elif speed_input < 0:
		effective_speed = speed - Constants.REVERSE_SPEED
	else:
		effective_speed = speed
		
	_camera_y -= speed * delta
	
	velocity.y = -effective_speed
		
	var x_diff = target_x - position.x
	
	if abs(x_diff) > 2.0:
		var lateral_coeff = 2.5 if slippery else 10.0
		var lateral_speed = maxf(abs(effective_speed), Constants.BASE_SPEED)
		velocity.x = move_toward(velocity.x, x_diff * 8.0, lateral_speed * delta * lateral_coeff)
	else:
		velocity.x = 0.0
		position.x = target_x
		
	move_and_slide()
	
	# Clamp player's global Y position to keep them on screen relative to camera
	position.y = clampf(position.y, _camera_y - 700.0, _camera_y + 400.0)
	
	# Dampen sideways sliding forces on collision to prevent violent bounces
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			var normal = col.get_normal()
			if abs(normal.x) > 0.3:
				velocity.x = 0.0
				position.x = move_toward(position.x, target_x, 50.0 * delta)
	
	if has_node("Camera2D"):
		$Camera2D.position.x = -position.x
		$Camera2D.position.y = (_camera_y + Constants.CAMERA_Y_OFFSET) - position.y
	
	wheel_tread_offset = fmod(wheel_tread_offset + effective_speed * delta, 30.0)
	queue_redraw()
	
	_capture_sprite_interpolation()
	_update_boost_trail()
	
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and is_instance_valid(collider):
			if collider.is_in_group("deadly_obstacles"):
				if not boost_active:
					if not invincible:
						AudioManager.play_synth_crash(global_position)
					GameManager.take_damage(GameManager.max_health)
			elif collider.is_in_group("obstacles") or collider is StaticBody2D:
				if not boost_active:
					if not invincible:
						AudioManager.play_synth_crash(global_position)
					take_damage(1)
			elif collider.is_in_group("enemy"):
				if boost_active:
					if str(collider.get("boss_key")) == "" and collider.has_method("take_damage"):
						collider.take_damage(999)
				else:
					if not invincible:
						AudioManager.play_synth_crash(global_position)
					take_damage(1)

func _handle_input(_delta: float) -> void:
	speed_input = 0.0
	if Input.is_action_pressed("accelerate"):
		speed_input = 1.0
	if Input.is_action_pressed("brake"):
		speed_input = -1.0
		
	if Input.is_action_just_pressed("move_left"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_left_tap_time < Constants.DOUBLE_TAP_DELAY and can_weave:
			current_lane = maxi(current_lane - 2, 0)
			target_x = _lane_to_x(current_lane)
			position.x = move_toward(position.x, target_x, Constants.WEAVE_DISTANCE)
			can_weave = false
			weave_timer = Constants.WEAVE_COOLDOWN
		else:
			current_lane = maxi(current_lane - 1, 0)
			target_x = _lane_to_x(current_lane)
		last_left_tap_time = now

	if Input.is_action_just_pressed("move_right"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_right_tap_time < Constants.DOUBLE_TAP_DELAY and can_weave:
			current_lane = mini(current_lane + 2, Constants.LANE_COUNT - 1)
			target_x = _lane_to_x(current_lane)
			position.x = move_toward(position.x, target_x, Constants.WEAVE_DISTANCE)
			can_weave = false
			weave_timer = Constants.WEAVE_COOLDOWN
		else:
			current_lane = mini(current_lane + 1, Constants.LANE_COUNT - 1)
			target_x = _lane_to_x(current_lane)
		last_right_tap_time = now

	if Input.is_action_just_pressed("primary_fire"):
		_fire_primary()
	if Input.is_action_just_pressed("secondary_fire"):
		_fire_secondary()
	if Input.is_action_just_pressed("boost"):
		_activate_boost()
	if Input.is_action_just_pressed("cycle_weapon"):
		_cycle_weapon()
		
	if Input.is_action_just_pressed("fire_emp"):
		_fire_specific_weapon("emp")
	if Input.is_action_just_pressed("drop_mine"):
		_fire_specific_weapon("mine")

func _lane_to_x(lane: int) -> float:
	var clamped = clampi(lane, 0, Constants.LANE_POSITIONS.size() - 1)
	return Constants.LANE_POSITIONS[clamped]

func set_slippery(val: bool) -> void:
	slippery = val

func _update_timers(delta: float) -> void:
	primary_fire_timer = maxf(primary_fire_timer - delta, 0.0)
	if not can_weave:
		weave_timer -= delta
		if weave_timer <= 0.0:
			can_weave = true
	if boost_active:
		boost_timer -= delta
		if boost_timer <= 0.0:
			_deactivate_boost()
	else:
		if boost_charges < max_boost_charges:
			boost_recharge_timer -= delta
			if boost_recharge_timer <= 0.0:
				boost_charges += 1
				boost_recharge_timer = Constants.BOOST_RECHARGE_TIME
				boost_charge_updated.emit(boost_charges)
	if invincible:
		invincible_timer -= delta
		if invincible_timer <= 0.0:
			invincible = false
			modulate = Color.WHITE

func _fire_primary() -> void:
	if primary_fire_timer > 0.0:
		return
	var fr_level = GameManager.upgrade_levels.get("fire_rate", 1)
	var cooldown = clampf(Constants.PRIMARY_FIRE_COOLDOWN - (fr_level - 1) * Constants.FIRE_RATE_STEP, Constants.FIRE_RATE_MIN, Constants.FIRE_RATE_MAX)
	primary_fire_timer = cooldown
	weapon_fired.emit("machine_gun", weapon_mount.global_position, Vector2.UP)
	if is_instance_valid(_muzzle_flash) and RoadmapFx.gpu_effects_enabled():
		_muzzle_flash.restart()
		_muzzle_flash.emitting = true

func _fire_secondary() -> void:
	if secondary_ammo[current_weapon] <= 0:
		return
	secondary_ammo[current_weapon] -= 1
	weapon_fired.emit(Constants.WEAPON_DATA[current_weapon].type_name, weapon_mount.global_position, Vector2.UP)

func _fire_specific_weapon(type: String) -> void:
	var idx = -1
	for i in Constants.WEAPON_DATA.size():
		if Constants.WEAPON_DATA[i].type_name == type:
			idx = i
			break
	if idx != -1:
		if secondary_ammo[idx] > 0:
			secondary_ammo[idx] -= 1
			weapon_fired.emit(type, weapon_mount.global_position, Vector2.UP)

func _cycle_weapon() -> void:
	current_weapon = (current_weapon + 1) % secondary_ammo.size()
	weapon_switched.emit(current_weapon)

func _activate_boost() -> void:
	if boost_charges <= 0 or boost_active:
		return
	boost_charges -= 1
	boost_active = true
	boost_timer = Constants.BOOST_DURATION
	boost_charge_updated.emit(boost_charges)
	boost_activated.emit()
	AudioManager.play_synth_boost()
	CameraShake.shake(0.2, 0.15, 3.0)
	CameraShake.rumble(0.2, 0.15)
	if is_instance_valid(_boost_exhaust):
		_boost_exhaust.emitting = RoadmapFx.gpu_effects_enabled()

func _deactivate_boost() -> void:
	boost_active = false
	boost_recharge_timer = Constants.BOOST_RECHARGE_TIME
	boost_depleted.emit()
	if is_instance_valid(_boost_exhaust):
		_boost_exhaust.emitting = false

func take_damage(amount: int = 1) -> void:
	if invincible or boost_active:
		return
	GameManager.take_damage(amount)
	damage_taken.emit(amount)
	invincible = true
	invincible_timer = 1.0
	modulate = Color(1, 0.3, 0.3, 0.7)
	AudioManager.play_synth_hurt()
	CameraShake.shake(0.4, 0.2, 5.0)
	CameraShake.rumble(0.5, 0.3)

func _update_boost_ui() -> void:
	boost_charge_updated.emit(boost_charges)

func _update_boost_trail() -> void:
	var gpu_on: bool = RoadmapFx.gpu_effects_enabled()
	if is_instance_valid(_boost_trail):
		_boost_trail.emitting = boost_active and gpu_on
	if is_instance_valid(_boost_smoke):
		_boost_smoke.emitting = boost_active and gpu_on
		if boost_active and gpu_on:
			var top_speed: float = maxf(speed * Constants.BOOST_SPEED_MULTIPLIER, 1.0)
			_boost_smoke.amount_ratio = clampf(abs(velocity.length()) / top_speed, 0.25, 1.0)
	# Keep the legacy Line2D data for compatibility, but only draw it when GPU FX are off.
	_trail_line.visible = not gpu_on
	if boost_active:
		_trail_spacing_counter += abs(velocity.length()) * get_physics_process_delta_time()
		if _trail_spacing_counter >= TRAIL_SPACING:
			_trail_spacing_counter = 0.0
			_trail_points.push_front(position + Vector2(0, 16))
			if _trail_points.size() > TRAIL_LENGTH:
				_trail_points.resize(TRAIL_LENGTH)
			_trail_line.points = PackedVector2Array(_trail_points)
	elif not _trail_points.is_empty() or _trail_line.points.size() > 0:
		_trail_points.clear()
		_trail_spacing_counter = 0.0
		_trail_line.points = PackedVector2Array()

func _on_player_skin_changed(_skin_id: String) -> void:
	_apply_selected_skin()
	_scale_sprite()
	if is_instance_valid(_underglow):
		var tint: Color = sprite.self_modulate if sprite and sprite.self_modulate != Color.WHITE else Color.WHITE
		_underglow.color = Color(minf(0.2 * tint.r, 0.8), 0.6 * tint.g, 1.0 * tint.b, tint.a)

func _apply_selected_skin() -> void:
	if not sprite:
		return
	if PackManager and PackManager.has_method("get_custom_skin"):
		var custom_tex: Texture2D = PackManager.get_custom_skin("player")
		if custom_tex:
			sprite.texture = custom_tex
			sprite.self_modulate = Color.WHITE
			return
	var skin_id := "default"
	if SettingsManager and SettingsManager.has_method("get_player_skin"):
		skin_id = SettingsManager.get_player_skin()
	if GameManager and GameManager.has_method("is_skin_unlocked") and not GameManager.is_skin_unlocked(skin_id):
		skin_id = "default"
	for skin_info in Constants.PLAYER_SKINS:
		if str(skin_info.get("id", "")) == skin_id:
			var tex_path := str(skin_info.get("texture_path", ""))
			if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
				var tex: Texture2D = load(tex_path)
				if tex:
					sprite.texture = tex
					sprite.self_modulate = _default_sprite_modulate if bool(skin_info.get("use_default_modulate", false)) else Color.WHITE
					return
	if _default_sprite_texture:
		sprite.texture = _default_sprite_texture
		sprite.self_modulate = _default_sprite_modulate

func _on_pack_skin_loaded(entity: String, tex: Texture2D) -> void:
	if entity != "player" or not sprite:
		return
	if tex:
		sprite.texture = tex
		sprite.self_modulate = Color.WHITE
	else:
		_apply_selected_skin()
	_scale_sprite()
	if is_instance_valid(_underglow):
		var tint: Color = sprite.self_modulate if sprite and sprite.self_modulate != Color.WHITE else Color.WHITE
		_underglow.color = Color(minf(0.2 * tint.r, 0.8), 0.6 * tint.g, 1.0 * tint.b, tint.a)

func _scale_sprite() -> void:
	HelpersUtil.scale_sprite_to_viewport(sprite, 108.0, Constants.SPRITE_BASE_VIEWPORT)
	if collision and collision.shape:
		collision.shape = collision.shape.duplicate()
		collision.shape.size = Vector2(28, 40) * (sprite.scale.y / 0.875)

func _setup_lights() -> void:
	if not is_instance_valid(sprite) or not RoadmapFx.lighting_effects_enabled():
		return
	# Headlight cone pointing upward
	_headlight = PointLight2D.new()
	_headlight.name = "Headlight"
	_headlight.texture = _create_light_texture(128, Color(0.4, 0.85, 1.0, 1.0))
	_headlight.energy = 1.8
	_headlight.texture_scale = 2.6
	_headlight.shadow_enabled = true
	_headlight.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_headlight.position = Vector2(0.0, -20.0)
	add_child(_headlight)

	# Neon underglow
	_underglow = PointLight2D.new()
	_underglow.name = "Underglow"
	_underglow.texture = _create_light_texture(96, Color(0.2, 0.6, 1.0, 0.85))
	_underglow.color = Color(0.2, 0.6, 1.0, 1.0)
	_underglow.energy = 1.1
	_underglow.texture_scale = 2.2
	_underglow.shadow_enabled = false
	_underglow.position = Vector2(0.0, 8.0)
	add_child(_underglow)

func _create_light_texture(size: int, tint: Color) -> Texture2D:
	return RoadmapFx.make_glow_texture(size, tint)

func _apply_feature_gates() -> void:
	var gpu_on: bool = RoadmapFx.gpu_effects_enabled()
	_trail_line.visible = not gpu_on
	if is_instance_valid(_boost_exhaust):
		_boost_exhaust.visible = gpu_on
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = gpu_on
	var lights_on: bool = RoadmapFx.lighting_effects_enabled()
	if is_instance_valid(_headlight):
		_headlight.visible = lights_on
	if is_instance_valid(_underglow):
		_underglow.visible = lights_on

func _capture_sprite_interpolation() -> void:
	if not is_instance_valid(sprite):
		return
	_prev_sprite_transform = _target_sprite_transform if _sprite_interpolation_ready else sprite.transform
	_sprite_interpolation_ready = true
	var lean: float = clampf(velocity.x * 0.0006, -0.06, 0.06)
	_target_sprite_transform = Transform2D(lean, sprite.scale, 0.0, Vector2.ZERO)

func _apply_sprite_interpolation() -> void:
	if not RoadmapFx.motion_interpolation_enabled() or not _sprite_interpolation_ready or not is_instance_valid(sprite):
		return
	var alpha: float = Engine.get_physics_interpolation_fraction()
	sprite.transform = RoadmapFx.interpolate_transform(_prev_sprite_transform, _target_sprite_transform, alpha)

func _setup_particles() -> void:
	# Boost exhaust trail
	_boost_exhaust = GPUParticles2D.new()
	_boost_exhaust.name = "BoostExhaust"
	_boost_exhaust.z_index = -1
	_boost_exhaust.amount = RoadmapFx.scaled_particle_amount(64)
	_boost_exhaust.lifetime = 0.6
	_boost_exhaust.one_shot = false
	_boost_exhaust.emitting = false
	_boost_exhaust.local_coords = false
	_boost_exhaust.texture = RoadmapFx.make_glow_texture(4, Color(1.0, 0.5, 0.1, 0.8))
	var exhaust_mat := ParticleProcessMaterial.new()
	exhaust_mat.direction = Vector3(0, 1, 0)
	exhaust_mat.spread = 25.0
	exhaust_mat.gravity = Vector3.ZERO
	exhaust_mat.initial_velocity_min = 80.0
	exhaust_mat.initial_velocity_max = 140.0
	exhaust_mat.scale_min = 0.6
	exhaust_mat.scale_max = 1.2
	exhaust_mat.color = Color(1.0, 0.5, 0.1, 0.7)
	exhaust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	_boost_exhaust.process_material = exhaust_mat
	_boost_exhaust.position = Vector2(0.0, 24.0)
	add_child(_boost_exhaust)

	# Muzzle flash
	_muzzle_flash = GPUParticles2D.new()
	_muzzle_flash.name = "MuzzleFlash"
	_muzzle_flash.z_index = 2
	_muzzle_flash.amount = RoadmapFx.scaled_particle_amount(12)
	_muzzle_flash.lifetime = 0.12
	_muzzle_flash.one_shot = true
	_muzzle_flash.emitting = false
	_muzzle_flash.local_coords = false
	_muzzle_flash.texture = RoadmapFx.make_glow_texture(6, Color(1.0, 0.9, 0.4, 1.0))
	var flash_mat := ParticleProcessMaterial.new()
	flash_mat.direction = Vector3(0, -1, 0)
	flash_mat.spread = 60.0
	flash_mat.gravity = Vector3.ZERO
	flash_mat.initial_velocity_min = 120.0
	flash_mat.initial_velocity_max = 200.0
	flash_mat.scale_min = 0.4
	flash_mat.scale_max = 0.9
	flash_mat.color = Color(1.0, 0.9, 0.4, 1.0)
	flash_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	_muzzle_flash.process_material = flash_mat
	_muzzle_flash.position = Vector2(0.0, -30.0)
	add_child(_muzzle_flash)

	# GPU boost trail replaces the CPU-drawn Line2D as the visible trail.
	_boost_trail = GPUParticles2D.new()
	_boost_trail.name = "BoostTrail"
	_boost_trail.z_index = -1
	_boost_trail.amount = RoadmapFx.scaled_particle_amount(96)
	_boost_trail.lifetime = 0.9
	_boost_trail.one_shot = false
	_boost_trail.emitting = false
	_boost_trail.local_coords = false
	_boost_trail.texture = RoadmapFx.make_glow_texture(8, Color(1.0, 0.45, 0.05, 0.9))
	var trail_mat := ParticleProcessMaterial.new()
	trail_mat.direction = Vector3(0, 1, 0)
	trail_mat.spread = 35.0
	trail_mat.gravity = Vector3.ZERO
	trail_mat.initial_velocity_min = 120.0
	trail_mat.initial_velocity_max = 220.0
	trail_mat.scale_min = 0.7
	trail_mat.scale_max = 1.6
	trail_mat.color = Color(1.0, 0.45, 0.05, 0.8)
	trail_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	trail_mat.emission_box_extents = Vector3(12.0, 0.0, 0.0)
	_boost_trail.process_material = trail_mat
	_boost_trail.position = Vector2(0.0, 22.0)
	add_child(_boost_trail)

	# Boost tire smoke, positioned across both rear wheels.
	_boost_smoke = GPUParticles2D.new()
	_boost_smoke.name = "BoostSmoke"
	_boost_smoke.z_index = 0
	_boost_smoke.amount = RoadmapFx.scaled_particle_amount(48)
	_boost_smoke.lifetime = 0.75
	_boost_smoke.one_shot = false
	_boost_smoke.emitting = false
	_boost_smoke.local_coords = false
	_boost_smoke.texture = RoadmapFx.make_glow_texture(12, Color(0.65, 0.68, 0.72, 0.45))
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0, 1, 0)
	smoke_mat.spread = 50.0
	smoke_mat.gravity = Vector3(0, -20, 0)
	smoke_mat.initial_velocity_min = 40.0
	smoke_mat.initial_velocity_max = 90.0
	smoke_mat.scale_min = 0.8
	smoke_mat.scale_max = 2.0
	smoke_mat.color = Color(0.65, 0.68, 0.72, 0.4)
	smoke_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	smoke_mat.emission_box_extents = Vector3(22.0, 0.0, 0.0)
	_boost_smoke.process_material = smoke_mat
	_boost_smoke.position = Vector2(0.0, 24.0)
	add_child(_boost_smoke)

func _setup_explosion_pool() -> void:
	# Keep FX in world space without adding children to a parent that is still
	# setting up its own children (common during scene instantiation in tests).
	_shockwave_host = Node2D.new()
	_shockwave_host.name = "ExplosionShockwaveHost"
	_shockwave_host.set_as_top_level(true)
	add_child(_shockwave_host)
	for i in EXPLOSION_POOL_SIZE:
		var emitter: GPUParticles2D = RoadmapFx.make_explosion_emitter()
		emitter.name = "ExplosionShockwave_%d" % i
		_shockwave_host.add_child(emitter)
		_shockwave_pool.append(emitter)

func spawn_explosion_fx(world_position: Vector2) -> void:
	if RoadmapFx.gpu_effects_enabled() and not _shockwave_pool.is_empty():
		var emitter: GPUParticles2D = _shockwave_pool[_shockwave_cursor % _shockwave_pool.size()]
		_shockwave_cursor += 1
		if is_instance_valid(emitter):
			emitter.global_position = world_position
			emitter.restart()
			emitter.emitting = true
	if RoadmapFx.lighting_effects_enabled():
		var host: Node = _shockwave_host if is_instance_valid(_shockwave_host) else self
		RoadmapFx.spawn_explosion_flash(host, world_position)

func _exit_tree() -> void:
	for emitter in _shockwave_pool:
		if is_instance_valid(emitter):
			emitter.queue_free()
	_shockwave_pool.clear()

func _draw() -> void:
	var wheel_color = Color(0.12, 0.12, 0.15, 1.0)
	var tread_color = Color(0.35, 0.35, 0.4, 1.0)
	var rim_color = Color(0.7, 0.7, 0.7, 1.0)
	
	var w_width = 16.0
	var w_height = 30.0
	var x_offset = 20.0 * sprite.scale.x
	var y_front = -24.0 * sprite.scale.y
	var y_rear = 24.0 * sprite.scale.y
	
	var wheel_positions = [
		Vector2(-x_offset - w_width/2.0, y_front - w_height/2.0),
		Vector2(x_offset - w_width/2.0, y_front - w_height/2.0),
		Vector2(-x_offset - w_width/2.0, y_rear - w_height/2.0),
		Vector2(x_offset - w_width/2.0, y_rear - w_height/2.0)
	]
	
	for pos in wheel_positions:
		draw_rect(Rect2(pos, Vector2(w_width, w_height)), wheel_color, true)
		draw_rect(Rect2(pos + Vector2(2, 4), Vector2(w_width - 4, w_height - 8)), rim_color, true)
		for j in range(4):
			var tread_y = pos.y + fmod(wheel_tread_offset + j * (w_height / 4.0), w_height)
			draw_line(Vector2(pos.x, tread_y), Vector2(pos.x + w_width, tread_y), tread_color, 2.5)

func add_boost() -> void:
	if boost_charges < max_boost_charges:
		boost_charges += 1
		boost_charge_updated.emit(boost_charges)

func add_ammo() -> void:
	for i in secondary_ammo.size():
		secondary_ammo[i] += 1
	weapon_switched.emit(current_weapon)

func on_bridge_fall(_body: Node) -> void:
	if _body != self:
		return
	take_damage(2)
	if position.x < 0:
		position.x = Constants.LANE_POSITIONS[1]
		current_lane = 1
		target_x = _lane_to_x(current_lane)
	else:
		position.x = Constants.LANE_POSITIONS[3]
		current_lane = 3
		target_x = _lane_to_x(current_lane)
