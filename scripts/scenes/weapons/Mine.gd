extends Area2D

var damage: int = Constants.MINE_DAMAGE
var explosion_radius: float = Constants.MINE_EXPLOSION_RADIUS
var armed: bool = false
var arm_time: float = Constants.MINE_ARM_TIME
var _blast_col: CollisionShape2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("mine")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_blast_col = CollisionShape2D.new()
	_blast_col.shape = CircleShape2D.new()
	add_child(_blast_col)
	await get_tree().create_timer(arm_time).timeout
	armed = true

func init(pos: Vector2) -> void:
	global_position = pos
	_blast_col.shape.radius = explosion_radius
	_blast_col.disabled = true

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
	CameraShake.shake(0.6, 0.3, 8.0)
	CameraShake.rumble(0.8, 0.4)
	_blast_col.disabled = false
	var hit = false
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage)
			hit = true
	for area in get_overlapping_areas():
		if area.has_method("take_damage"):
			area.take_damage(damage)
			hit = true
	if not hit:
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius and enemy.has_method("take_damage"):
				enemy.take_damage(damage)
	
	var flash = Polygon2D.new()
	var pts = []
	var segments = 12
	for i in segments:
		var angle = i * TAU / segments
		pts.append(Vector2(cos(angle) * explosion_radius, sin(angle) * explosion_radius))
	flash.polygon = PackedVector2Array(pts)
	flash.color = Color(1.0, 0.6, 0.1, 0.8)
	flash.position = global_position
	if get_parent():
		get_parent().add_child(flash)
		flash.queue_free()
	
	AudioManager.play_synth_explosion(global_position)
	ObjectPool.release(self)
