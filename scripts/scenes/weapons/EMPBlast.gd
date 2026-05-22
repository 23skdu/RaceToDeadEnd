extends Area2D

var damage: int = 1
var stun_duration: float = 2.0
var expand_speed: float = 400.0
var max_radius: float = 400.0
var current_radius: float = 0.0
var _col_shape: CollisionShape2D
var _pooled: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("emp")
	body_entered.connect(_on_body_entered)
	_col_shape = $CollisionShape2D
	_col_shape.disabled = false
	_update_collision_radius()

func init(pos: Vector2) -> void:
	global_position = pos
	_pooled = has_meta("_pool_name")
	current_radius = 0.0

func _process(delta: float) -> void:
	current_radius = move_toward(current_radius, max_radius, expand_speed * delta)
	_update_collision_radius()
	if current_radius >= max_radius:
		if _pooled:
			ObjectPool.release(self)
		else:
			queue_free()

func _update_collision_radius() -> void:
	if _col_shape and _col_shape.shape is CircleShape2D:
		_col_shape.shape.radius = current_radius

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	if body.has_method("apply_stun"):
		body.apply_stun(stun_duration)
