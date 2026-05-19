extends Area2D

var damage: int = 1
var stun_duration: float = 2.0
var expand_speed: float = 400.0
var max_radius: float = 400.0
var current_radius: float = 0.0

func _ready() -> void:
	add_to_group("emp")
	body_entered.connect(_on_body_entered)
	$CollisionShape2D.disabled = false
	scale = Vector2.ZERO

func init(pos: Vector2) -> void:
	global_position = pos

func _process(delta: float) -> void:
	current_radius = move_toward(current_radius, max_radius, expand_speed * delta)
	var s = current_radius / max_radius
	scale = Vector2(s, s)
	if current_radius >= max_radius:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
