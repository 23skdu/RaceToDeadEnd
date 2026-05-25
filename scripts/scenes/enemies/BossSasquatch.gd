extends "res://scripts/scenes/enemies/Enemy.gd"

var attack_timer: float = 0.0
var dodge_timer: float = 0.0
var target_lane_x: float = 0.0

func _ready() -> void:
	super._ready()
	if not sprite.texture:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.25, 0.1, 1.0))
		sprite.texture = ImageTexture.create_from_image(img)

func on_pool_acquire() -> void:
	attack_timer = 0.0
	dodge_timer = 0.0
	target_lane_x = global_position.x

func on_pool_release() -> void:
	attack_timer = 0.0
	dodge_timer = 0.0
	target_lane_x = 0.0
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not player or not is_instance_valid(player):
		velocity.y = speed
		move_and_slide()
		return

	var target_y = player.global_position.y - 300.0
	velocity.y = (target_y - global_position.y) * 2.0

	dodge_timer += delta
	if dodge_timer >= 1.5:
		dodge_timer = 0.0
		_dodge()

	velocity.x = (target_lane_x - global_position.x) * 5.0

	attack_timer += delta
	if attack_timer >= Constants.BOSS_ATTACK_INTERVAL * 1.5:
		attack_timer = 0.0
		_throw_poop()

	move_and_slide()

func _dodge() -> void:
	var new_lane = randi_range(0, Constants.LANE_COUNT - 1)
	target_lane_x = Constants.LANE_POSITIONS[new_lane]

func _throw_poop() -> void:
	var poop = ObjectPool.acquire("poop_weapon")
	if not poop:
		poop = preload("res://scenes/weapons/PoopWeapon.tscn").instantiate()
	var parent = get_parent()
	if parent:
		parent.add_child(poop)
	poop.global_position = global_position + Vector2(0, 64)
	var dir = Vector2.DOWN
	if player:
		dir = (player.global_position - poop.global_position).normalized()
	poop.init(poop.global_position, dir, false)
