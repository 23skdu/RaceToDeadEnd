extends Area2D

var speed: float = 500.0
var direction: Vector2 = Vector2.UP
var damage: int = 1
var homing_strength: float = 0.0
var is_player_bullet: bool = true

signal hit_target(target: Node)

func _ready() -> void:
	add_to_group("bullet")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func init(pos: Vector2, dir: Vector2, player_owned: bool = true) -> void:
	global_position = pos
	direction = dir.normalized()
	is_player_bullet = player_owned
	if not is_player_bullet:
		direction = Vector2.DOWN
		collision_mask = 1
	else:
		collision_mask = 2

func _process(delta: float) -> void:
	if homing_strength > 0.0:
		var enemies = get_tree().get_nodes_in_group("enemy")
		var nearest = _find_nearest(enemies)
		if nearest:
			var target_dir = (nearest.global_position - global_position).normalized()
			direction = direction.lerp(target_dir, homing_strength * delta).normalized()
	position += direction * speed * delta

func _find_nearest(enemies: Array) -> Node:
	var nearest: Node = null
	var min_dist: float = INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_squared_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
	return nearest

func _on_body_entered(body: Node) -> void:
	hit_target.emit(body)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_die()

func _on_area_entered(area: Area2D) -> void:
	hit_target.emit(area)
	if area.has_method("take_damage"):
		area.take_damage(damage)
	_die()

func _die() -> void:
	queue_free()

func _on_visible_on_screen_notifier_screen_exited() -> void:
	queue_free()
