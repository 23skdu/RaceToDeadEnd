extends Area2D

var damage: int = 2
var explosion_radius: float = 64.0
var armed: bool = false
var arm_time: float = 0.5

func _ready() -> void:
	add_to_group("mine")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	await get_tree().create_timer(arm_time).timeout
	armed = true

func init(pos: Vector2) -> void:
	global_position = pos

func _on_body_entered(body: Node) -> void:
	if not armed:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_explode()

func _on_area_entered(area: Area2D) -> void:
	if not armed:
		return
	if area.has_method("take_damage"):
		area.take_damage(damage)
	_explode()

func _explode() -> void:
	queue_free()
