extends Area2D

const DETONATION_TIME: float = 1.5
const BLAST_RADIUS: float = 80.0

var age: float = 0.0
var exploded: bool = false
var warning_visual: Polygon2D
var explosion_visual: Polygon2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 # player layer
	
	# Collision shape
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = BLAST_RADIUS
	col.shape = circle
	add_child(col)
	
	# Spawn warning circle diamond look
	warning_visual = Polygon2D.new()
	var pts = []
	var segments = 16
	for i in segments:
		var angle = i * TAU / segments
		pts.append(Vector2(cos(angle) * BLAST_RADIUS, sin(angle) * BLAST_RADIUS * 0.5)) # Isometric squashed circle
	warning_visual.polygon = PackedVector2Array(pts)
	warning_visual.color = Color(1.0, 0.1, 0.1, 0.25)
	add_child(warning_visual)

func _process(delta: float) -> void:
	age += delta
	
	if not exploded:
		# Blinking effect increases in speed as detonation approaches
		var speed_factor = 1.0 + (age / DETONATION_TIME) * 8.0
		var blink = int(age * speed_factor * 10.0) % 2 == 0
		warning_visual.visible = blink
		
		if age >= DETONATION_TIME:
			_detonate()
	else:
		# Exploding fading visual
		var t = (age - DETONATION_TIME) / 0.3
		if t >= 1.0:
			queue_free()
		else:
			explosion_visual.scale = Vector2.ONE * (1.0 + t * 0.5)
			explosion_visual.color = Color(1.0, 0.7, 0.1, 1.0 - t)

func _detonate() -> void:
	exploded = true
	warning_visual.queue_free()
	
	# Explosion visual circle
	explosion_visual = Polygon2D.new()
	var pts = []
	var segments = 16
	for i in segments:
		var angle = i * TAU / segments
		pts.append(Vector2(cos(angle) * BLAST_RADIUS, sin(angle) * BLAST_RADIUS * 0.5))
	explosion_visual.polygon = PackedVector2Array(pts)
	explosion_visual.color = Color(1.0, 0.8, 0.2, 0.8)
	add_child(explosion_visual)
	
	# Check collision with player
	for body in get_overlapping_bodies():
		if body.has_method("take_damage") and body.is_in_group("player"):
			body.take_damage(2)
