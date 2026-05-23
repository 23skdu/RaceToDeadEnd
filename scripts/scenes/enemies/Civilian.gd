extends CharacterBody2D

signal exited_safely
signal hit_by_player

var speed: float = 150.0
var direction: float = 1.0
var _protect_bonus_awarded: bool = false
var _lane: int = 0

const BASE_SPRITE_SIZE: float = 48.0
const BASE_VIEWPORT_WIDTH: float = 1280.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 2
	z_index = 0
	_generate_sprite_texture()

func init(start_lane: int, base_speed: float, travel_dir: float) -> void:
	_lane = start_lane
	speed = base_speed * 0.6
	direction = travel_dir
	_protect_bonus_awarded = false

	var lane_x = Constants.LANE_POSITIONS[start_lane] if start_lane < Constants.LANE_POSITIONS.size() else 0.0
	global_position = Vector2(lane_x, 0)

func _generate_sprite_texture() -> void:
	var img = Image.create(8, 16, false, Image.FORMAT_RGBA8)
	var body_color = Color(0.2, 0.6, 0.3)
	for x in 8:
		for y in 16:
			var c = body_color
			if y < 2 or y >= 14:
				c = Color(0.4, 0.3, 0.2)
			elif y >= 6 and y <= 10 and x >= 2 and x <= 5:
				c = Color(0.6, 0.8, 1.0)
			img.set_pixel(x, y, c)
	sprite.texture = ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
	if not _protect_bonus_awarded:
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			var diff = global_position.y - player.global_position.y
			if diff > Constants.CLEANUP_DISTANCE:
				_protect_bonus_awarded = true
				exited_safely.emit()

	velocity.x = direction * speed
	velocity.y = -speed * 0.3
	move_and_slide()

func take_damage(_amount: int = 1) -> void:
	hit_by_player.emit()

func on_pool_acquire() -> void:
	_generate_sprite_texture()
	_protect_bonus_awarded = false
	velocity = Vector2.ZERO
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

func on_pool_release() -> void:
	_protect_bonus_awarded = false
	velocity = Vector2.ZERO
	for conn in exited_safely.get_connections():
		exited_safely.disconnect(conn.callable)
	for conn in hit_by_player.get_connections():
		hit_by_player.disconnect(conn.callable)
