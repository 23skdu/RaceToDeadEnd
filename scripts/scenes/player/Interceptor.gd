extends CharacterBody2D

const HelpersUtil = preload("res://scripts/utils/Helpers.gd")
const TRAIL_LENGTH: int = 12
const TRAIL_SPACING: float = 8.0


@export_group("Movement")
@export var move_speed: float = Constants.BASE_SPEED
@export var weave_dist: float = Constants.WEAVE_DISTANCE
@export var weave_cooldown: float = Constants.WEAVE_COOLDOWN

@export_group("Boost")
@export var boost_speed_mult: float = Constants.BOOST_SPEED_MULTIPLIER
@export var boost_duration: float = Constants.BOOST_DURATION
@export var boost_recharge: float = Constants.BOOST_RECHARGE_TIME
@export var max_boost: int = 3

@export_group("Combat")
@export var primary_cooldown: float = Constants.PRIMARY_FIRE_COOLDOWN
@export var accel_speed: float = Constants.ACCEL_SPEED
@export var reverse_speed: float = Constants.REVERSE_SPEED

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
var max_forward_y: float = 0.0
var wheel_tread_offset: float = 0.0

var last_left_tap_time: float = 0.0
var last_right_tap_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_mount: Marker2D = $WeaponMount
@onready var collision: CollisionShape2D = $CollisionShape2D

var _trail_line: Line2D
var _trail_points: Array[Vector2] = []
var _trail_spacing_counter: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 2
	z_index = 1
	add_to_group("player")
	_scale_sprite()
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
	_trail_line.default_color = Color(1.0, 0.5, 0.0, 0.6)
	_trail_line.z_index = -1
	add_child(_trail_line)
	
	target_x = _lane_to_x(current_lane)
	position.x = target_x
	_update_boost_ui()
	if not get_viewport().size_changed.is_connected(_scale_sprite):
		get_viewport().size_changed.connect(_scale_sprite)

func _on_speed_changed(new_speed: float) -> void:
	speed = new_speed

func _process(delta: float) -> void:
	_update_timers(delta)

func _physics_process(delta: float) -> void:
	_handle_input(delta)
	var effective_speed: float
	if boost_active:
		effective_speed = speed * Constants.BOOST_SPEED_MULTIPLIER
	elif speed_input > 0:
		effective_speed = Constants.ACCEL_SPEED
	elif speed_input < 0:
		effective_speed = Constants.REVERSE_SPEED
	else:
		effective_speed = speed
		
	max_forward_y = minf(max_forward_y, position.y)
	
	velocity.y = -effective_speed
	
	# Restrict reversing tightly (approx 50 pixels) to prevent scrolling backwards past the camera
	if velocity.y > 0 and position.y >= max_forward_y + 50.0:
		velocity.y = 0.0
		position.y = max_forward_y + 50.0
		
	var x_diff = target_x - position.x
	
	if abs(x_diff) > 2.0:
		var lateral_coeff = 2.5 if slippery else 10.0
		velocity.x = move_toward(velocity.x, x_diff * 8.0, abs(effective_speed) * delta * lateral_coeff)
	else:
		velocity.x = 0.0
		position.x = target_x
		
	move_and_slide()
	
	if has_node("Camera2D"):
		$Camera2D.position.x = -position.x
	
	wheel_tread_offset = fmod(wheel_tread_offset + effective_speed * delta, 30.0)
	queue_redraw()
	
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
				if not boost_active:
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

func _deactivate_boost() -> void:
	boost_active = false
	boost_recharge_timer = Constants.BOOST_RECHARGE_TIME
	boost_depleted.emit()

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
	if boost_active:
		_trail_spacing_counter += abs(velocity.length()) * get_physics_process_delta_time()
		if _trail_spacing_counter >= TRAIL_SPACING:
			_trail_spacing_counter = 0.0
			_trail_points.push_front(position + Vector2(0, 16))
			if _trail_points.size() > TRAIL_LENGTH:
				_trail_points.resize(TRAIL_LENGTH)
		_trail_line.points = PackedVector2Array(_trail_points)
		var alpha_step = 0.6 / max(_trail_points.size(), 1)
		var gradient = Gradient.new()
		var colors: PackedColorArray = []
		for j in range(_trail_points.size()):
			var t = float(j) / max(_trail_points.size() - 1, 1)
			colors.append(Color(1.0, 0.5, 0.0, 0.6 * (1.0 - t)))
		_trail_line.gradient = gradient
		_trail_line.default_color = Color(1.0, 0.5, 0.0, 0.0)
	else:
		_trail_points.clear()
		_trail_spacing_counter = 0.0
		_trail_line.points = PackedVector2Array()

func _scale_sprite() -> void:
	HelpersUtil.scale_sprite_to_viewport(sprite, 120.0, Constants.SPRITE_BASE_VIEWPORT)
	if collision and collision.shape:
		collision.shape = collision.shape.duplicate()
		collision.shape.size = Vector2(28, 40) * (sprite.scale.y / 0.875)

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
		position.x = Constants.LANE_POSITIONS[2]
		current_lane = 2
		target_x = _lane_to_x(current_lane)
