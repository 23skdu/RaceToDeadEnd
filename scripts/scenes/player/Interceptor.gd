extends CharacterBody2D

signal weapon_fired(weapon_type: String, position: Vector2, direction: Vector2)
signal boost_activated
signal boost_depleted
signal boost_charge_updated(charges: int)
signal weapon_switched(weapon_index: int)

const WEAPON_TYPES: Array[String] = ["missile", "mine", "emp"]

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

var last_left_tap_time: float = 0.0
var last_right_tap_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_mount: Marker2D = $WeaponMount
@onready var collision: CollisionShape2D = $CollisionShape2D

const BASE_SPRITE_SIZE: float = 64.0
const BASE_VIEWPORT_WIDTH: float = 1280.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	z_index = 1
	add_to_group("player")
	_scale_sprite()
	$Camera2D.position.y = -100
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
	
	target_x = _lane_to_x(current_lane)
	position.x = target_x
	_update_boost_ui()

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
	velocity.y = -effective_speed
	var x_diff = target_x - position.x
	
	if abs(x_diff) > 2.0:
		var lateral_coeff = 2.5 if slippery else 10.0
		velocity.x = move_toward(velocity.x, x_diff * 8.0, abs(effective_speed) * delta * lateral_coeff)
	else:
		velocity.x = 0.0
		position.x = target_x
		
	move_and_slide()
	
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and is_instance_valid(collider):
			if collider.is_in_group("deadly_obstacles"):
				if not boost_active:
					GameManager.take_damage(GameManager.max_health)
			elif collider.is_in_group("obstacles") or collider is StaticBody2D:
				if not boost_active:
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
	return Constants.LANE_POSITIONS[lane] if lane < Constants.LANE_POSITIONS.size() else 0.0

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
	var cooldown = clampf(Constants.PRIMARY_FIRE_COOLDOWN - (fr_level - 1) * 0.01, 0.05, 0.1)
	primary_fire_timer = cooldown
	weapon_fired.emit("machine_gun", weapon_mount.global_position, Vector2.UP)

func _fire_secondary() -> void:
	if secondary_ammo[current_weapon] <= 0:
		return
	secondary_ammo[current_weapon] -= 1
	weapon_fired.emit(WEAPON_TYPES[current_weapon], weapon_mount.global_position, Vector2.UP)

func _fire_specific_weapon(type: String) -> void:
	var idx = WEAPON_TYPES.find(type)
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

func _deactivate_boost() -> void:
	boost_active = false
	boost_recharge_timer = Constants.BOOST_RECHARGE_TIME
	boost_depleted.emit()

func take_damage(amount: int = 1) -> void:
	if invincible or boost_active:
		return
	GameManager.take_damage(amount)
	invincible = true
	invincible_timer = 1.0
	modulate = Color(1, 0.3, 0.3, 0.7)
	AudioManager.play_synth_hurt()
	CameraShake.shake(0.4, 0.2, 5.0)

func _update_boost_ui() -> void:
	boost_charge_updated.emit(boost_charges)

func _scale_sprite() -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	var viewport_width = viewport.get_visible_rect().size.x
	var scale_factor = viewport_width / BASE_VIEWPORT_WIDTH
	var target_size = BASE_SPRITE_SIZE * scale_factor
	if sprite.texture:
		var tex_height = sprite.texture.get_height()
		var current_scale = target_size / tex_height
		sprite.scale = Vector2(current_scale, current_scale)

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
		position.x = -32
		current_lane = 1
		target_x = _lane_to_x(current_lane)
	else:
		position.x = 32
		current_lane = 2
		target_x = _lane_to_x(current_lane)
