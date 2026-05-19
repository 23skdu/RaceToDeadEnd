extends CharacterBody2D

signal weapon_fired(weapon_type: String, position: Vector2, direction: Vector2)
signal boost_activated
signal boost_depleted
signal boost_charge_updated(charges: int)
signal weapon_switched(weapon_index: int)

const BASE_SPEED: float = 200.0
const BOOST_SPEED_MULTIPLIER: float = 2.0
const LANE_WIDTH: float = 64.0
const LANE_COUNT: int = 4
const WEAVE_DISTANCE: float = 128.0
const WEAVE_COOLDOWN: float = 0.5
const BOOST_DURATION: float = 1.5
const BOOST_RECHARGE_TIME: float = 8.0
const PRIMARY_FIRE_COOLDOWN: float = 0.1
const DOUBLE_TAP_DELAY: float = 0.25

var current_lane: int = 1
var target_x: float = 0.0
var speed: float = BASE_SPEED
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

var last_left_tap_time: float = 0.0
var last_right_tap_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_mount: Marker2D = $WeaponMount
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	var bl = GameManager.upgrade_levels.get("boost_capacity", 1)
	var al = GameManager.upgrade_levels.get("starting_ammo", 1)
	
	max_boost_charges = 2 + bl
	boost_charges = max_boost_charges
	
	secondary_ammo = [
		2 + al, # Missiles
		1 + al, # Mines
		al      # EMP
	]
	
	target_x = _lane_to_x(current_lane)
	position.x = target_x
	_update_boost_ui()

func _process(delta: float) -> void:
	_handle_input()
	_update_timers(delta)

func _physics_process(delta: float) -> void:
	var current_speed = speed * (BOOST_SPEED_MULTIPLIER if boost_active else 1.0)
	velocity.y = -current_speed
	var x_diff = target_x - position.x
	
	if abs(x_diff) > 2.0:
		# Slower slidey steering on ice
		var lateral_coeff = 2.5 if slippery else 10.0
		velocity.x = move_toward(velocity.x, x_diff * 8.0, current_speed * delta * lateral_coeff)
	else:
		velocity.x = 0.0
		position.x = target_x
		
	move_and_slide()
	
	# Obstacle static collision check
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider.is_in_group("obstacles") or collider is StaticBody2D:
			take_damage(1)

func _handle_input() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	
	if Input.is_action_just_pressed("move_left"):
		if now - last_left_tap_time < DOUBLE_TAP_DELAY and can_weave:
			# Weave Weave! (Dodge left)
			current_lane = maxi(current_lane - 2, 0)
			target_x = _lane_to_x(current_lane)
			position.x = move_toward(position.x, target_x, WEAVE_DISTANCE)
			can_weave = false
			weave_timer = WEAVE_COOLDOWN
		else:
			current_lane = maxi(current_lane - 1, 0)
			target_x = _lane_to_x(current_lane)
		last_left_tap_time = now

	if Input.is_action_just_pressed("move_right"):
		if now - last_right_tap_time < DOUBLE_TAP_DELAY and can_weave:
			# Weave Weave! (Dodge right)
			current_lane = mini(current_lane + 2, LANE_COUNT - 1)
			target_x = _lane_to_x(current_lane)
			position.x = move_toward(position.x, target_x, WEAVE_DISTANCE)
			can_weave = false
			weave_timer = WEAVE_COOLDOWN
		else:
			current_lane = mini(current_lane + 1, LANE_COUNT - 1)
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

func _lane_to_x(lane: int) -> float:
	var total_width = LANE_WIDTH * (LANE_COUNT - 1)
	return -total_width / 2.0 + lane * LANE_WIDTH

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
				boost_recharge_timer = BOOST_RECHARGE_TIME
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
	var cooldown = clampf(0.1 - (fr_level - 1) * 0.01, 0.05, 0.1)
	primary_fire_timer = cooldown
	weapon_fired.emit("machine_gun", weapon_mount.global_position, Vector2.UP)

func _fire_secondary() -> void:
	if secondary_ammo[current_weapon] <= 0:
		return
	var weapon_types = ["missile", "mine", "emp"]
	secondary_ammo[current_weapon] -= 1
	weapon_fired.emit(weapon_types[current_weapon], weapon_mount.global_position, Vector2.UP)

func _cycle_weapon() -> void:
	current_weapon = (current_weapon + 1) % 3
	weapon_switched.emit(current_weapon)

func _activate_boost() -> void:
	if boost_charges <= 0 or boost_active:
		return
	boost_charges -= 1
	boost_active = true
	boost_timer = BOOST_DURATION
	boost_charge_updated.emit(boost_charges)
	boost_activated.emit()
	AudioManager.play_synth_boost()

func _deactivate_boost() -> void:
	boost_active = false
	boost_recharge_timer = BOOST_RECHARGE_TIME
	boost_depleted.emit()

func take_damage(amount: int = 1) -> void:
	if invincible:
		return
	GameManager.take_damage(amount)
	invincible = true
	invincible_timer = 1.0
	modulate = Color(1, 0.3, 0.3, 0.7)
	AudioManager.play_synth_hurt()

func _update_boost_ui() -> void:
	boost_charge_updated.emit(boost_charges)
